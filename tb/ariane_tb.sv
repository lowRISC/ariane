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


import ariane_pkg::*;
`ifdef VCS
 `define uvm_error(a,b,c)
 `define uvm_info(a,b,c)
`else
import uvm_pkg::*;
`include "uvm_macros.svh"
`endif

`define MAIN_MEM(P) dut.i_sram.genblk1[0].i_ram.Mem_DP[(``P``)]

import "DPI-C" function read_elf(input string filename);
import "DPI-C" function byte get_section(output longint address, output longint len);
import "DPI-C" context function byte read_section(input longint address, inout byte buffer[]);

module ariane_tb;
`ifndef VCS
    static uvm_cmdline_processor uvcl = uvm_cmdline_processor::get_inst();
`endif
    localparam int unsigned CLOCK_PERIOD = 20ns;
    // toggle with RTC period
    localparam int unsigned RTC_CLOCK_PERIOD = 30.517us;

    localparam NUM_WORDS = 2**25;
    logic clk_i;
    logic rst_ni;
    logic rtc_i;

    longint unsigned cycles;
    longint unsigned max_cycles;

    logic [31:0] exit_o;

    string binary = "";

    ariane_testharness #(
        .NUM_WORDS         ( NUM_WORDS ),
        .InclSimDTM        ( 1'b1      ),
        .StallRandomOutput ( 1'b1      ),
        .StallRandomInput  ( 1'b1      )
    ) dut (
        .clk_i,
        .rst_ni,
        .rtc_i,
        .exit_o
    );

`ifdef SPIKE_TANDEM
    spike #(
        .Size ( NUM_WORDS * 8 )
    ) i_spike (
        .clk_i,
        .rst_ni,
        .clint_tick_i   ( rtc_i                               ),
        .commit_instr_i ( dut.i_ariane.commit_instr_id_commit ),
        .commit_ack_i   ( dut.i_ariane.commit_ack             ),
        .exception_i    ( dut.i_ariane.ex_commit              ),
        .waddr_i        ( dut.i_ariane.waddr_commit_id        ),
        .wdata_i        ( dut.i_ariane.wdata_commit_id        ),
        .priv_lvl_i     ( dut.i_ariane.priv_lvl               )
    );
    initial begin
        $display("Running binary in tandem mode");
    end
`endif

    // Clock process
    initial begin
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

            if ((exit_o >> 1)) begin
                `uvm_error( "Core Test",  $sformatf("*** FAILED *** (tohost = %0d)", (exit_o >> 1)))
            end else begin
                `uvm_info( "Core Test",  $sformatf("*** SUCCESS *** (tohost = %0d)", (exit_o >> 1)), UVM_LOW)
            end

            $finish();
        end
    end

    // for faster simulation we can directly preload the ELF
    // Note that we are loosing the capabilities to use risc-fesvr though
    initial begin
        automatic logic [7:0][7:0] mem_row;
        longint address, len;
        byte buffer[];
`ifdef VCS
        $value$plusargs("+PRELOAD=", binary);
`else       
        void'(uvcl.get_arg_value("+PRELOAD=", binary));
`endif
        if (binary != "") begin
            `uvm_info( "Core Test", $sformatf("Preloading ELF: %s", binary), UVM_LOW)

            void'(read_elf(binary));
            // wait with preloading, otherwise randomization will overwrite the existing value
            wait(rst_ni);

            // while there are more sections to process
            while (get_section(address, len)) begin
                automatic int num_words = (len+7)/8;
                `uvm_info( "Core Test", $sformatf("Loading Address: %x, Length: %x", address, len),
UVM_LOW)
                buffer = new [num_words*8];
                void'(read_section(address, buffer));
                // preload memories
                // 64-bit
                for (int i = 0; i < num_words; i++) begin
                    mem_row = '0;
                    for (int j = 0; j < 8; j++) begin
                        mem_row[j] = buffer[i*8 + j];
                    end
                    `MAIN_MEM((address[28:0] >> 3) + i) = mem_row;
                end
            end
        end
    end

`ifdef VCS
// tediously connect unused module interfaces at the top level   
   AXI_BUS  #(
    .AXI_ADDR_WIDTH ( 64     ),
    .AXI_DATA_WIDTH ( 64     ),
    .AXI_ID_WIDTH   ( 5      ),
    .AXI_USER_WIDTH ( 1      )
) axi_dummy[14:0] (), axi_master[3:0] (), axi_slave[3:0] (), axi_master4[3:0] ();
   AXI_LITE axi_dummy_lite[1:0] ();
   REG_BUS reg_dummy[1:0] ();
   
   axi_riscv_lrsc_wrap dummy1 (.mst(axi_dummy[0]), .slv(axi_dummy[8]));
   axi_riscv_atomics_wrap #(.ADDR_END(0)) dummy2 (.mst(axi_dummy[1]), .slv(axi_dummy[2]));
   axi_master_connect_rev dummy3 (.master(axi_dummy[3]));
   axi_slave_connect_rev dummy4 (.slave(axi_dummy[4]));
   axi_node_wrap_with_slices dummy5 (.master(axi_master), .slave(axi_slave));
   axi_to_axi_lite dummy6 (.in(axi_dummy[6]), .out(axi_dummy_lite[0]));
   axi_slave_connect dummy7 (.slave(axi_dummy[10]));
   axi_slice_wrap dummy8 (.axi_master(axi_dummy[11]), .axi_slave(axi_dummy[12]));
   apb_to_reg dummy9 (.reg_o(reg_dummy[0]));
   axi_master_connect dummy10 (.master(axi_dummy[13]));
   axi_demux #(
    .SLAVE_NUM  ( 4      ),
    .ADDR_WIDTH ( 64     ),
    .DATA_WIDTH ( 64     ),
    .USER_WIDTH ( 1      ),
    .ID_WIDTH   ( 5      )
   ) dummy11 (.clk(clk_i),
              .rstn(rst_ni),
              .master(axi_dummy[14]),
              .slave(axi_master4),
              .BASE(0),
              .MASK(0));
  
`endif   
   
endmodule
