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

module xilinx_tb;
    localparam int unsigned CLOCK_PERIOD = 10ns;
    longint unsigned cycles;
    longint unsigned max_cycles;

    logic        clk_p       ;
    logic        cpu_resetn  ;
    wire  [15:0] ddr2_dq     ;
    wire  [ 1:0] ddr2_dqs_n  ;
    wire  [ 1:0] ddr2_dqs_p  ;
    logic [12:0] ddr2_addr   ;
    logic [ 2:0] ddr2_ba     ;
    logic        ddr2_ras_n  ;
    logic        ddr2_cas_n  ;
    logic        ddr2_we_n   ;
    logic [ 0:0] ddr2_ck_p   ;
    logic [ 0:0] ddr2_ck_n   ;
    logic [ 0:0] ddr2_cke    ;
    logic [ 1:0] ddr2_dm     ;
    logic [ 0:0] ddr2_odt    ;
    //! Ethernet MAC PHY interface signals
    logic [1:0]    i_erxd; // RMII receive data
    logic         i_erx_dv; // PHY data valid
    logic         i_erx_er; // PHY coding error
    logic         i_emdint; // PHY interrupt in active low
    wire          o_erefclk; // RMII clock out
    wire [1:0]    o_etxd; // RMII transmit data
    wire          o_etx_en; // RMII transmit enable
    wire          o_emdc; // MDIO clock
    tri1          io_emdio; // MDIO inout
    wire          o_erstn; // PHY reset active low 
    logic [ 7:0]  led         ;
    logic [ 7:0]  sw          ;
    logic         fan_pwm     ;
    // SD (shared with SPI)
    wire         sd_sclk;
    logic        sd_detect;
    tri1 [3:0]   sd_dat;
    tri1         sd_cmd;
    wire         sd_reset;
    // common part
    logic        tck         ;
    logic        tms         ;
    logic        trst_n      ;
    logic        tdi         ;
    wire         tdo         ;
    logic        rx          ;
    logic        tx          ;
    // Quad-SPI
    tri1         QSPI_CSN   ;
    tri1 [3:0]   QSPI_D    ;

    ariane_xilinx dut (.*);

    // Clock process
    initial begin
       i_erxd = 0;
       i_erx_dv = 0;
       i_erx_er = 0;
       i_emdint = 0;
       sw = 0;
       sd_detect = 0;
       tck = 0;
       tms = 0;
       trst_n = 0;
       tdi = 0;
       rx = 1'b1;
       
        clk_p = 1'b0;
        cpu_resetn = 1'b0;
        repeat(8)
            #(CLOCK_PERIOD/2)
                 begin
                    clk_p = ~clk_p;
                    tck = ~tck;
                 end
        cpu_resetn = 1'b1;
        trst_n = 1'b1;
       
        forever begin
            #(CLOCK_PERIOD/2) clk_p = 1'b1;
            #(CLOCK_PERIOD/2) clk_p = 1'b0;

            //if (cycles > max_cycles)
            //    $fatal(1, "Simulation reached maximum cycle count of %d", max_cycles);

            cycles++;
        end
    end

    initial begin
        automatic logic [7:0][7:0] mem_row;
        longint address, len;
        byte buffer[];
        int unsigned rand_value;
        rand_value = $urandom;
        rand_value = $random(rand_value);
        $display("testing $random %0x seed %d", rand_value, unsigned'($get_initial_random_seed));
        $vcdpluson();
     end

`ifdef VCS
// tediously connect unused module interfaces at the top level   
   AXI_BUS  #(
    .AXI_ADDR_WIDTH ( 64     ),
    .AXI_DATA_WIDTH ( 64     ),
    .AXI_ID_WIDTH   ( 5      ),
    .AXI_USER_WIDTH ( 1      )
) axi_dummy[17:0] (), axi_master[3:0] (), axi_slave[3:0] (), axi_master4[3:0] ();
   AXI_LITE #(
    .AXI_ADDR_WIDTH ( 64     ),
    .AXI_DATA_WIDTH ( 64     ),
    .AXI_ID_WIDTH   ( 5      ),
    .AXI_USER_WIDTH ( 1      )
) axi_dummy_lite[1:0] ();
   REG_BUS reg_dummy[1:0] ();
   
   axi_riscv_lrsc_wrap #(.ADDR_BEGIN(0),
                         .ADDR_END(1),
                         .AXI_ADDR_WIDTH(64),
                         .AXI_DATA_WIDTH(64),
                         .AXI_ID_WIDTH(5)) dummy1 (.mst(axi_dummy[0]), .slv(axi_dummy[8]));
   axi_riscv_atomics_wrap dummy2 (.mst(axi_dummy[1]), .slv(axi_dummy[2]));
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
   ) dummy11 (.clk(clk_p),
              .rstn(cpu_resetn),
              .master(axi_dummy[14]),
              .slave(axi_master4),
              .BASE(0),
              .MASK(0));
   stream_mux #(.N_INP(2)) dummy12 ();
   ariane_shell dummy13(.dram(axi_dummy[15]), .iobus(axi_dummy[16]));
   
`endif   
   
endmodule
