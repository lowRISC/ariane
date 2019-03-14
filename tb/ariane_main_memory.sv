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
// Original Author: Florian Zaruba, ETH Zurich
// This version adapted by Jonathan Kimmitt
// Date: 14.03.2019
// Description: Main memory simulation for Ariane
//              Instantiates an AXI-Bus and memories (originally part of ariane_testharness)


module ariane_main_memory #(
    parameter int unsigned AXI_ID_WIDTH_SLAVES = 5,
    parameter int unsigned AXI_USER_WIDTH      = 1,
    parameter int unsigned AXI_ADDRESS_WIDTH   = 64,
    parameter int unsigned AXI_DATA_WIDTH      = 64,
    parameter int unsigned NUM_WORDS           = 2**25,         // memory size
    parameter bit          StallRandomOutput   = 1'b0,
    parameter bit          StallRandomInput    = 1'b0
) (
   input logic clk_i,
   input logic rst_ni,
   input logic ndmreset_n,
   AXI_BUS.in master);
   
  
    AXI_BUS #(
        .AXI_ADDR_WIDTH ( AXI_ADDRESS_WIDTH   ),
        .AXI_DATA_WIDTH ( AXI_DATA_WIDTH      ),
        .AXI_ID_WIDTH   ( AXI_ID_WIDTH_SLAVES ),
        .AXI_USER_WIDTH ( AXI_USER_WIDTH      )
    ) dram();

    logic                         req;
    logic                         we;
    logic [AXI_ADDRESS_WIDTH-1:0] addr;
    logic [AXI_DATA_WIDTH/8-1:0]  be;
    logic [AXI_DATA_WIDTH-1:0]    wdata;
    logic [AXI_DATA_WIDTH-1:0]    rdata;

    axi_pkg::aw_chan_t aw_chan_i;
    axi_pkg::w_chan_t  w_chan_i;
    axi_pkg::b_chan_t  b_chan_o;
    axi_pkg::ar_chan_t ar_chan_i;
    axi_pkg::r_chan_t  r_chan_o;
    axi_pkg::aw_chan_t aw_chan_o;
    axi_pkg::w_chan_t  w_chan_o;
    axi_pkg::b_chan_t  b_chan_i;
    axi_pkg::ar_chan_t ar_chan_o;
    axi_pkg::r_chan_t  r_chan_i;

    axi_delayer #(
        .aw_t              ( axi_pkg::aw_chan_t ),
        .w_t               ( axi_pkg::w_chan_t  ),
        .b_t               ( axi_pkg::b_chan_t  ),
        .ar_t              ( axi_pkg::ar_chan_t ),
        .r_t               ( axi_pkg::r_chan_t  ),
        .StallRandomOutput ( StallRandomOutput  ),
        .StallRandomInput  ( StallRandomInput   ),
        .FixedDelayInput   ( 0                  ),
        .FixedDelayOutput  ( 0                  )
    ) i_axi_delayer (
        .clk_i      ( clk_i                             ),
        .rst_ni     ( ndmreset_n                        ),
        .aw_valid_i ( master.aw_valid ),
        .aw_chan_i  ( aw_chan_i                         ),
        .aw_ready_o ( master.aw_ready ),
        .w_valid_i  ( master.w_valid  ),
        .w_chan_i   ( w_chan_i                          ),
        .w_ready_o  ( master.w_ready  ),
        .b_valid_o  ( master.b_valid  ),
        .b_chan_o   ( b_chan_o                          ),
        .b_ready_i  ( master.b_ready  ),
        .ar_valid_i ( master.ar_valid ),
        .ar_chan_i  ( ar_chan_i                         ),
        .ar_ready_o ( master.ar_ready ),
        .r_valid_o  ( master.r_valid  ),
        .r_chan_o   ( r_chan_o                          ),
        .r_ready_i  ( master.r_ready  ),
        .aw_valid_o ( dram.aw_valid                     ),
        .aw_chan_o  ( aw_chan_o                         ),
        .aw_ready_i ( dram.aw_ready                     ),
        .w_valid_o  ( dram.w_valid                      ),
        .w_chan_o   ( w_chan_o                          ),
        .w_ready_i  ( dram.w_ready                      ),
        .b_valid_i  ( dram.b_valid                      ),
        .b_chan_i   ( b_chan_i                          ),
        .b_ready_o  ( dram.b_ready                      ),
        .ar_valid_o ( dram.ar_valid                     ),
        .ar_chan_o  ( ar_chan_o                         ),
        .ar_ready_i ( dram.ar_ready                     ),
        .r_valid_i  ( dram.r_valid                      ),
        .r_chan_i   ( r_chan_i                          ),
        .r_ready_o  ( dram.r_ready                      )
    );

    assign aw_chan_i.atop = '0;
    assign aw_chan_i.id = master.aw_id;
    assign aw_chan_i.addr = master.aw_addr;
    assign aw_chan_i.len = master.aw_len;
    assign aw_chan_i.size = master.aw_size;
    assign aw_chan_i.burst = master.aw_burst;
    assign aw_chan_i.lock = master.aw_lock;
    assign aw_chan_i.cache = master.aw_cache;
    assign aw_chan_i.prot = master.aw_prot;
    assign aw_chan_i.qos = master.aw_qos;
    assign aw_chan_i.region = master.aw_region;

    assign ar_chan_i.id = master.ar_id;
    assign ar_chan_i.addr = master.ar_addr;
    assign ar_chan_i.len = master.ar_len;
    assign ar_chan_i.size = master.ar_size;
    assign ar_chan_i.burst = master.ar_burst;
    assign ar_chan_i.lock = master.ar_lock;
    assign ar_chan_i.cache = master.ar_cache;
    assign ar_chan_i.prot = master.ar_prot;
    assign ar_chan_i.qos = master.ar_qos;
    assign ar_chan_i.region = master.ar_region;

    assign w_chan_i.data = master.w_data;
    assign w_chan_i.strb = master.w_strb;
    assign w_chan_i.last = master.w_last;

    assign master.r_id = r_chan_o.id;
    assign master.r_data = r_chan_o.data;
    assign master.r_resp = r_chan_o.resp;
    assign master.r_last = r_chan_o.last;

    assign master.b_id = b_chan_o.id;
    assign master.b_resp = b_chan_o.resp;


    assign dram.aw_id = aw_chan_o.id;
    assign dram.aw_addr = aw_chan_o.addr;
    assign dram.aw_len = aw_chan_o.len;
    assign dram.aw_size = aw_chan_o.size;
    assign dram.aw_burst = aw_chan_o.burst;
    assign dram.aw_lock = aw_chan_o.lock;
    assign dram.aw_cache = aw_chan_o.cache;
    assign dram.aw_prot = aw_chan_o.prot;
    assign dram.aw_qos = aw_chan_o.qos;
    assign dram.aw_region = aw_chan_o.region;
    assign dram.aw_user = master.aw_user;

    assign dram.ar_id = ar_chan_o.id;
    assign dram.ar_addr = ar_chan_o.addr;
    assign dram.ar_len = ar_chan_o.len;
    assign dram.ar_size = ar_chan_o.size;
    assign dram.ar_burst = ar_chan_o.burst;
    assign dram.ar_lock = ar_chan_o.lock;
    assign dram.ar_cache = ar_chan_o.cache;
    assign dram.ar_prot = ar_chan_o.prot;
    assign dram.ar_qos = ar_chan_o.qos;
    assign dram.ar_region = ar_chan_o.region;
    assign dram.ar_user = master.ar_user;

    assign dram.w_data = w_chan_o.data;
    assign dram.w_strb = w_chan_o.strb;
    assign dram.w_last = w_chan_o.last;
    assign dram.w_user = master.w_user;

    assign r_chan_i.id = dram.r_id;
    assign r_chan_i.data = dram.r_data;
    assign r_chan_i.resp = dram.r_resp;
    assign r_chan_i.last = dram.r_last;
    assign master.r_user = dram.r_user;

    assign b_chan_i.id = dram.b_id;
    assign b_chan_i.resp = dram.b_resp;
    assign master.b_user = dram.b_user;


    axi2mem #(
        .AXI_ID_WIDTH   ( AXI_ID_WIDTH_SLAVES ),
        .AXI_ADDR_WIDTH ( AXI_ADDRESS_WIDTH   ),
        .AXI_DATA_WIDTH ( AXI_DATA_WIDTH      ),
        .AXI_USER_WIDTH ( AXI_USER_WIDTH      )
    ) i_axi2mem (
        .clk_i  ( clk_i      ),
        .rst_ni ( ndmreset_n ),
        .slave  ( dram       ),
        .req_o  ( req        ),
        .we_o   ( we         ),
        .addr_o ( addr       ),
        .be_o   ( be         ),
        .data_o ( wdata      ),
        .data_i ( rdata      )
    );

    sram #(
        .DATA_WIDTH ( AXI_DATA_WIDTH ),
        .NUM_WORDS  ( NUM_WORDS      )
//        .PRELOAD    ( 1 ) // use readmemh (only if `define PRELOAD)
    ) i_sram (
        .clk_i      ( clk_i                                                                       ),
        .rst_ni     ( rst_ni                                                                      ),
        .req_i      ( req                                                                         ),
        .we_i       ( we                                                                          ),
        .addr_i     ( addr[$clog2(NUM_WORDS)-1+$clog2(AXI_DATA_WIDTH/8):$clog2(AXI_DATA_WIDTH/8)] ),
        .wdata_i    ( wdata                                                                       ),
        .be_i       ( be                                                                          ),
        .rdata_o    ( rdata                                                                       )
    );

endmodule
