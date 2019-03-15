// Copyright 2018 ETH Zurich and University of Bologna.
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the "License"); you may not use this file except in
// compliance with the License.  You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.
//
// Author: Florian Zaruba, ETH Zurich
// Date: 15/04/2017
// Description: Top level testbench module. Instantiates the top level DUT, configures
//              the virtual interfaces and starts the test passed by +UVM_TEST+

`timescale 1ps/100fs

import ariane_pkg::*;
`ifndef VCS
import uvm_pkg::*;

`include "uvm_macros.svh"
`endif

`define MAIN_MEM(P) dut.i_sram.genblk1[0].i_ram.Mem_DP[(``P``)]

`ifndef VCS
import "DPI-C" function read_elf(input string filename);
import "DPI-C" function byte get_section(output longint address, output longint len);
import "DPI-C" context function byte read_section(input longint address, inout byte buffer[]);
`endif

module ariane_tb;

`ifndef VCS
    static uvm_cmdline_processor uvcl = uvm_cmdline_processor::get_inst();
`endif

    localparam int unsigned CLOCK_PERIOD = 20ns;
    // toggle with RTC period
    localparam int unsigned RTC_CLOCK_PERIOD = 30.517us;

    localparam NUM_WORDS = 2**25;

    wire  sys_clk_p;
    wire  sys_clk_n;
    reg   sys_rst_n;
    reg   sys_clk_i;
    reg   clk_ref_i;

    logic clk_i;
    logic rst_ni;
    logic rtc_i;

    longint unsigned cycles;
    longint unsigned max_cycles;

    logic [31:0] exit_o;

    ariane_testharness #(
        .NUM_WORDS         ( NUM_WORDS ),
        .InclSimDTM        ( 1'b1      ),
        .StallRandomOutput ( 1'b1      ),
        .StallRandomInput  ( 1'b1      )
    ) dut (
           .sys_clk_p,
           .sys_clk_n,
           .sys_rst_n,
           .clk_i,
           .rst_ni,
           .rtc_i,
           .exit_o
    );

    // Clock process
    initial begin
`ifdef VCDPLUS       
       $vcdpluson(0, dut.i_ariane_peripherals.gen_uart.i_apb_uart);
       $vcdpluson(0, dut.i_main_mem.u_ip_top.i_xlnx_axi_clock_converter_ddr);       
`endif       
        clk_i = 1'b0;
        rst_ni = 1'b0;
        repeat(8)
            #(CLOCK_PERIOD/2) clk_i = ~clk_i;
        rst_ni = 1'b1;
        forever begin
            #(CLOCK_PERIOD/2) clk_i = 1'b1;
            #(CLOCK_PERIOD/2) clk_i = 1'b0;

            //if (cycles > max_cycles)
            //    $fatal(1, "Simulation reached maximum cycle count of %d", max_cycles);

            cycles++;
            if (cycles % 1000 == 0) $vcdplusflush();
        end
    end

    initial begin
        forever begin
            rtc_i = 1'b0;
            #(RTC_CLOCK_PERIOD/2) rtc_i = 1'b1;
            #(RTC_CLOCK_PERIOD/2) rtc_i = 1'b0;
        end
    end

    initial begin
        forever begin

            wait (exit_o[0]);
`ifndef VCS
            if ((exit_o >> 1)) begin
                `uvm_error( "Core Test",  $sformatf("*** FAILED *** (tohost = %0d)", (exit_o >> 1)))
            end else begin
                `uvm_info( "Core Test",  $sformatf("*** SUCCESS *** (tohost = %0d)", (exit_o >> 1)), UVM_LOW)
            end
`endif
            $finish();
        end
    end

//**************************************************************************//
   //***************************************************************************
   // The following parameters are multiplier and divisor factors for PLLE2.
   // Based on the selected design frequency these parameters vary.
   //***************************************************************************
   parameter CLKIN_PERIOD          = 5000;
                                     // Input Clock Period

   //***************************************************************************
   // Referece clock frequency parameters
   //***************************************************************************
   parameter REFCLK_FREQ           = 200.0;
                                     // IODELAYCTRL reference clock frequency
  localparam real REFCLK_PERIOD = (1000000.0/(2*REFCLK_FREQ));
  localparam RESET_PERIOD = 200000; //in pSec  

  //**************************************************************************//
  // DDR3 Reset Generation
  //**************************************************************************//
  initial begin
    sys_rst_n = 1'b0;
    #RESET_PERIOD
      sys_rst_n = 1'b1;
   end

   assign sys_rst = sys_rst_n;

  //**************************************************************************//
  // DDR3 Clock Generation
  //**************************************************************************//

  initial
    sys_clk_i = 1'b0;
  always
    sys_clk_i = #(CLKIN_PERIOD/2.0) ~sys_clk_i;

  assign sys_clk_p = sys_clk_i;
  assign sys_clk_n = ~sys_clk_i;

  initial
    clk_ref_i = 1'b0;
  always
    clk_ref_i = #REFCLK_PERIOD ~clk_ref_i;

endmodule
