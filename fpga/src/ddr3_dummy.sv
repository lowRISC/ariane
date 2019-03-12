//*****************************************************************************
// (c) Copyright 2009 - 2012 Xilinx, Inc. All rights reserved.
//
// This file contains confidential and proprietary information
// of Xilinx, Inc. and is protected under U.S. and
// international copyright and other intellectual property
// laws.
//
// DISCLAIMER
// This disclaimer is not a license and does not grant any
// rights to the materials distributed herewith. Except as
// otherwise provided in a valid license issued to you by
// Xilinx, and to the maximum extent permitted by applicable
// law: (1) THESE MATERIALS ARE MADE AVAILABLE "AS IS" AND
// WITH ALL FAULTS, AND XILINX HEREBY DISCLAIMS ALL WARRANTIES
// AND CONDITIONS, EXPRESS, IMPLIED, OR STATUTORY, INCLUDING
// BUT NOT LIMITED TO WARRANTIES OF MERCHANTABILITY, NON-
// INFRINGEMENT, OR FITNESS FOR ANY PARTICULAR PURPOSE; and
// (2) Xilinx shall not be liable (whether in contract or tort,
// including negligence, or under any other theory of
// liability) for any loss or damage of any kind or nature
// related to, arising under or in connection with these
// materials, including for any direct, or any indirect,
// special, incidental, or consequential loss or damage
// (including loss of data, profits, goodwill, or any type of
// loss or damage suffered as a result of any action brought
// by a third party) even if such damage or loss was
// reasonably foreseeable or Xilinx had been advised of the
// possibility of the same.
//
// CRITICAL APPLICATIONS
// Xilinx products are not designed or intended to be fail-
// safe, or for use in any application requiring fail-safe
// performance, such as life-support or safety devices or
// systems, Class III medical devices, nuclear facilities,
// applications related to the deployment of airbags, or any
// other applications that could lead to death, personal
// injury, or severe property or environmental damage
// (individually and collectively, "Critical
// Applications"). Customer assumes the sole risk and
// liability of any use of Xilinx products in Critical
// Applications, subject only to applicable laws and
// regulations governing limitations on product liability.
//
// THIS COPYRIGHT NOTICE AND DISCLAIMER MUST BE RETAINED AS
// PART OF THIS FILE AT ALL TIMES.
//
//*****************************************************************************
//   ____  ____
//  /   /\/   /
// /___/  \  /    Vendor             : Xilinx
// \   \   \/     Version            : 4.1
//  \   \         Application        : MIG
//  /   /         Filename           : xlnx_mig_7_ddr3.v
// /___/   /\     Date Last Modified : $Date: 2011/06/02 08:35:03 $
// \   \  /  \    Date Created       : Wed Feb 01 2012
//  \___\/\___\
//
// Device           : 7 Series
// Design Name      : DDR3 SDRAM
// Purpose          :
//   Wrapper module for the user design top level file. This module can be 
//   instantiated in the system and interconnect as shown in example design 
//   (example_top module).
// Revision History :
//*****************************************************************************
//`define SKIP_CALIB
`timescale 1ps/1ps

module xlnx_mig_7_ddr3 (
  // Inouts
  inout [31:0]       ddr3_dq,
  inout [3:0]        ddr3_dqs_n,
  inout [3:0]        ddr3_dqs_p,
  // Outputs
  output [14:0]     ddr3_addr,
  output [2:0]        ddr3_ba,
  output            ddr3_ras_n,
  output            ddr3_cas_n,
  output            ddr3_we_n,
  output            ddr3_reset_n,
  output [0:0]       ddr3_ck_p,
  output [0:0]       ddr3_ck_n,
  output [0:0]       ddr3_cke,
  output [0:0]        ddr3_cs_n,
  output [3:0]     ddr3_dm,
  output [0:0]       ddr3_odt,
  // Inputs
  // Differential system clocks
  input             sys_clk_p,
  input             sys_clk_n,
  // user interface signals
  output            ui_clk,
  output            ui_clk_sync_rst,
  output            mmcm_locked,
  input         aresetn,
  input         app_sr_req,
  input         app_ref_req,
  input         app_zq_req,
  output            app_sr_active,
  output            app_ref_ack,
  output            app_zq_ack,
  // Slave Interface Write Address Ports
  input [4:0]           s_axi_awid,
  input [29:0]         s_axi_awaddr,
  input [7:0]           s_axi_awlen,
  input [2:0]           s_axi_awsize,
  input [1:0]           s_axi_awburst,
  input [0:0]           s_axi_awlock,
  input [3:0]           s_axi_awcache,
  input [2:0]           s_axi_awprot,
  input [3:0]           s_axi_awqos,
  input         s_axi_awvalid,
  output            s_axi_awready,
  // Slave Interface Write Data Ports
  input [63:0]         s_axi_wdata,
  input [7:0]         s_axi_wstrb,
  input         s_axi_wlast,
  input         s_axi_wvalid,
  output            s_axi_wready,
  // Slave Interface Write Response Ports
  input         s_axi_bready,
  output [4:0]          s_axi_bid,
  output [1:0]          s_axi_bresp,
  output            s_axi_bvalid,
  // Slave Interface Read Address Ports
  input [4:0]           s_axi_arid,
  input [29:0]         s_axi_araddr,
  input [7:0]           s_axi_arlen,
  input [2:0]           s_axi_arsize,
  input [1:0]           s_axi_arburst,
  input [0:0]           s_axi_arlock,
  input [3:0]           s_axi_arcache,
  input [2:0]           s_axi_arprot,
  input [3:0]           s_axi_arqos,
  input         s_axi_arvalid,
  output            s_axi_arready,
  // Slave Interface Read Data Ports
  input         s_axi_rready,
  output [4:0]          s_axi_rid,
  output [63:0]            s_axi_rdata,
  output [1:0]          s_axi_rresp,
  output            s_axi_rlast,
  output            s_axi_rvalid,
  output            init_calib_complete,
  output [11:0]                                device_temp,
`ifdef SKIP_CALIB
   output                                      calib_tap_req,
   input                                       calib_tap_load,
   input [6:0]                                 calib_tap_addr,
   input [7:0]                                 calib_tap_val,
   input                                       calib_tap_load_done,
`endif  
  input			sys_rst
  );

   assign ui_clk_sync_rst = sys_rst;

`ifdef verilator
   assign ui_clk = sys_clk_p;
`else
IBUFDS #(
      .DIFF_TERM("FALSE"),       // Differential Termination
      .IBUF_LOW_PWR("TRUE"),     // Low power="TRUE", Highest performance="FALSE" 
      .IOSTANDARD("DEFAULT")     // Specify the input I/O standard
   ) IBUFDS_inst (
      .O(ui_clk),  // Buffer output
      .I(sys_clk_p),  // Diff_p buffer input (connect directly to top-level port)
      .IB(sys_clk_n) // Diff_n buffer input (connect directly to top-level port)
   );
`endif // !`ifdef verilator

   localparam ID_WIDTH = 5;
   localparam ADDR_WIDTH = 30;
   localparam DATA_WIDTH = 64;
   localparam USER_WIDTH = 1;
   
AXI_BUS #(
    .AXI_ID_WIDTH(ID_WIDTH),             // id width
    .AXI_ADDR_WIDTH(ADDR_WIDTH),         // address width
    .AXI_DATA_WIDTH(DATA_WIDTH),         // width of data
    .AXI_USER_WIDTH(USER_WIDTH)          // width of user field, must > 0, let synthesizer trim it if not in use
    )
   outgoing_if ();

slave_adapter  #(
    .ID_WIDTH(ID_WIDTH),                 // id width
    .ADDR_WIDTH(ADDR_WIDTH),             // address width
    .DATA_WIDTH(DATA_WIDTH),             // width of data
    .USER_WIDTH(USER_WIDTH)              // width of user field, must > 0, let synthesizer trim it if not in use
    )
 sadapt(
  .clk(ui_clk),
  .rstn(aresetn),
  .s_axi_awid(s_axi_awid),        // input wire [4 : 0] s_axi_awid
  .s_axi_awaddr(s_axi_awaddr),    // input wire [31 : 0] s_axi_awaddr
  .s_axi_awlen(s_axi_awlen),      // input wire [7 : 0] s_axi_awlen
  .s_axi_awsize(s_axi_awsize),    // input wire [2 : 0] s_axi_awsize
  .s_axi_awburst(s_axi_awburst),  // input wire [1 : 0] s_axi_awburst
  .s_axi_awvalid(s_axi_awvalid),  // input wire s_axi_awvalid
  .s_axi_awready(s_axi_awready),  // output wire s_axi_awready
  .s_axi_wdata(s_axi_wdata),      // input wire [63 : 0] s_axi_wdata
  .s_axi_wstrb(s_axi_wstrb),      // input wire [7 : 0] s_axi_wstrb
  .s_axi_wlast(s_axi_wlast),      // input wire s_axi_wlast
  .s_axi_wvalid(s_axi_wvalid),    // input wire s_axi_wvalid
  .s_axi_wready(s_axi_wready),    // output wire s_axi_wready
  .s_axi_bid(s_axi_bid),          // output wire [4 : 0] s_axi_bid
  .s_axi_bresp(s_axi_bresp),      // output wire [1 : 0] s_axi_bresp
  .s_axi_bvalid(s_axi_bvalid),    // output wire s_axi_bvalid
  .s_axi_bready(s_axi_bready),    // input wire s_axi_bready
  .s_axi_arid(s_axi_arid),        // input wire [4 : 0] s_axi_arid
  .s_axi_araddr(s_axi_araddr),    // input wire [31 : 0] s_axi_araddr
  .s_axi_arlen(s_axi_arlen),      // input wire [7 : 0] s_axi_arlen
  .s_axi_arsize(s_axi_arsize),    // input wire [2 : 0] s_axi_arsize
  .s_axi_arburst(s_axi_arburst),  // input wire [1 : 0] s_axi_arburst
  .s_axi_arvalid(s_axi_arvalid),  // input wire s_axi_arvalid
  .s_axi_arready(s_axi_arready),  // output wire s_axi_arready
  .s_axi_rid(s_axi_rid),          // output wire [4 : 0] s_axi_rid
  .s_axi_rdata(s_axi_rdata),      // output wire [63 : 0] s_axi_rdata
  .s_axi_rresp(s_axi_rresp),      // output wire [1 : 0] s_axi_rresp
  .s_axi_rlast(s_axi_rlast),      // output wire s_axi_rlast
  .s_axi_rvalid(s_axi_rvalid),    // output wire s_axi_rvalid
  .s_axi_rready(s_axi_rready),    // input wire s_axi_rready

      .m_axi_awid           ( outgoing_if.aw_id      ),
      .m_axi_awaddr         ( outgoing_if.aw_addr    ),
      .m_axi_awlen          ( outgoing_if.aw_len     ),
      .m_axi_awsize         ( outgoing_if.aw_size    ),
      .m_axi_awburst        ( outgoing_if.aw_burst   ),
      .m_axi_awlock         ( outgoing_if.aw_lock    ),
      .m_axi_awcache        ( outgoing_if.aw_cache   ),
      .m_axi_awprot         ( outgoing_if.aw_prot    ),
      .m_axi_awqos          ( outgoing_if.aw_qos     ),
      .m_axi_awuser         ( outgoing_if.aw_user    ),
      .m_axi_awregion       ( outgoing_if.aw_region  ),
      .m_axi_awvalid        ( outgoing_if.aw_valid   ),
      .m_axi_awready        ( outgoing_if.aw_ready   ),
      .m_axi_wdata          ( outgoing_if.w_data     ),
      .m_axi_wstrb          ( outgoing_if.w_strb     ),
      .m_axi_wlast          ( outgoing_if.w_last     ),
      .m_axi_wuser          ( outgoing_if.w_user     ),
      .m_axi_wvalid         ( outgoing_if.w_valid    ),
      .m_axi_wready         ( outgoing_if.w_ready    ),
      .m_axi_bid            ( outgoing_if.b_id       ),
      .m_axi_bresp          ( outgoing_if.b_resp     ),
      .m_axi_buser          ( outgoing_if.b_user     ),
      .m_axi_bvalid         ( outgoing_if.b_valid    ),
      .m_axi_bready         ( outgoing_if.b_ready    ),
      .m_axi_arid           ( outgoing_if.ar_id      ),
      .m_axi_araddr         ( outgoing_if.ar_addr    ),
      .m_axi_arlen          ( outgoing_if.ar_len     ),
      .m_axi_arsize         ( outgoing_if.ar_size    ),
      .m_axi_arburst        ( outgoing_if.ar_burst   ),
      .m_axi_arlock         ( outgoing_if.ar_lock    ),
      .m_axi_arcache        ( outgoing_if.ar_cache   ),
      .m_axi_arprot         ( outgoing_if.ar_prot    ),
      .m_axi_arqos          ( outgoing_if.ar_qos     ),
      .m_axi_aruser         ( outgoing_if.ar_user    ),
      .m_axi_arregion       ( outgoing_if.ar_region  ),
      .m_axi_arvalid        ( outgoing_if.ar_valid   ),
      .m_axi_arready        ( outgoing_if.ar_ready   ),
      .m_axi_rid            ( outgoing_if.r_id       ),
      .m_axi_rdata          ( outgoing_if.r_data     ),
      .m_axi_rresp          ( outgoing_if.r_resp     ),
      .m_axi_rlast          ( outgoing_if.r_last     ),
      .m_axi_ruser          ( outgoing_if.r_user     ),
      .m_axi_rvalid         ( outgoing_if.r_valid    ),
      .m_axi_rready         ( outgoing_if.r_ready    )
                      );
   
logic                    mem_req, mem_we;
logic [ADDR_WIDTH-1:0]   mem_addr;
logic [DATA_WIDTH-1:0]   mem_rdata, mem_wdata;
logic [DATA_WIDTH/8-1:0] mem_be;

axi2mem #(
    .AXI_ID_WIDTH   ( ID_WIDTH       ),
    .AXI_ADDR_WIDTH ( ADDR_WIDTH     ),
    .AXI_DATA_WIDTH ( DATA_WIDTH     ),
    .AXI_USER_WIDTH ( USER_WIDTH     )
) i_axi2mem (
    .clk_i  ( ui_clk                  ),
    .rst_ni ( aresetn                 ),
    .slave  ( outgoing_if             ),
    .req_o  ( mem_req                 ),
    .we_o   ( mem_we                  ),
    .addr_o ( mem_addr                ),
    .be_o   ( mem_be                  ),
    .data_o ( mem_wdata               ),
    .data_i ( mem_rdata               )
);

   sram #(
        .DATA_WIDTH ( DATA_WIDTH ),
        .NUM_WORDS  ( 1 << (ADDR_WIDTH - 3) ),
        .SIM_INIT   ( 4 ) // use readmemh
    ) i_sram (
        .clk_i      ( ui_clk                                                                  ),
        .rst_ni     ( aresetn                                                                 ),
        .req_i      ( mem_req                                                                 ),
        .we_i       ( mem_we                                                                  ),
        .addr_i     ( mem_addr[ADDR_WIDTH-1+$clog2(DATA_WIDTH/8):$clog2(DATA_WIDTH/8)]        ),
        .wdata_i    ( mem_wdata                                                               ),
        .be_i       ( mem_be                                                                  ),
        .rdata_o    ( mem_rdata                                                               )
    );

endmodule
