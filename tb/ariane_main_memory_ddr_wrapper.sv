//*****************************************************************************
// (c) Copyright 2009 - 2013 Xilinx, Inc. All rights reserved.
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
//  /   /         Filename           : example_top.v
// /___/   /\     Date Last Modified : $Date: 2011/06/02 08:35:03 $
// \   \  /  \    Date Created       : Tue Sept 21 2010
//  \___\/\___\
//
// Device           : 7 Series
// Design Name      : DDR3 SDRAM
// Purpose          :
//   Top-level  module. This module serves as an example,
//   and allows the user to synthesize a self-contained design,
//   which they can be used to test their hardware.
//   In addition to the memory controller, the module instantiates:
//     1. Synthesizable testbench - used to model user's backend logic
//        and generate different traffic patterns
// Reference        :
// Revision History :
//*****************************************************************************

//`define SKIP_CALIB
`timescale 1ps/1ps

module ariane_main_memory_ddr_wrapper #
  (

   //***************************************************************************
   // Traffic Gen related parameters
   //***************************************************************************
   parameter BEGIN_ADDRESS         = 32'h00000000,
   parameter END_ADDRESS           = 32'h00ffffff,
   parameter PRBS_EADDR_MASK_POS   = 32'hff000000,
   parameter ENFORCE_RD_WR         = 0,
   parameter ENFORCE_RD_WR_CMD     = 8'h11,
   parameter ENFORCE_RD_WR_PATTERN = 3'b000,
   parameter C_EN_WRAP_TRANS       = 0,
   parameter C_AXI_NBURST_TEST     = 0,

   //***************************************************************************
   // The following parameters refer to width of various ports
   //***************************************************************************
   parameter CK_WIDTH              = 1,
                                     // # of CK/CK# outputs to memory.
   parameter nCS_PER_RANK          = 1,
                                     // # of unique CS outputs per rank for phy
   parameter CKE_WIDTH             = 1,
                                     // # of CKE outputs to memory.
   parameter DM_WIDTH              = 4,
                                     // # of DM (data mask)
   parameter ODT_WIDTH             = 1,
                                     // # of ODT outputs to memory.
   parameter BANK_WIDTH            = 3,
                                     // # of memory Bank Address bits.
   parameter COL_WIDTH             = 10,
                                     // # of memory Column Address bits.
   parameter CS_WIDTH              = 1,
                                     // # of unique CS outputs to memory.
   parameter DQ_WIDTH              = 32,
                                     // # of DQ (data)
   parameter DQS_WIDTH             = 4,
   parameter DQS_CNT_WIDTH         = 2,
                                     // = ceil(log2(DQS_WIDTH))
   parameter DRAM_WIDTH            = 8,
                                     // # of DQ per DQS
   parameter ECC                   = "OFF",
   parameter ECC_TEST              = "OFF",
   //parameter nBANK_MACHS           = 4,
   parameter nBANK_MACHS           = 4,
   parameter RANKS                 = 1,
                                     // # of Ranks.
   parameter ROW_WIDTH             = 15,
                                     // # of memory Row Address bits.
   parameter ADDR_WIDTH            = 29,
                                     // # = RANK_WIDTH + BANK_WIDTH
                                     //     + ROW_WIDTH + COL_WIDTH;
                                     // Chip Select is always tied to low for
                                     // single rank devices

   //***************************************************************************
   // The following parameters are mode register settings
   //***************************************************************************
   parameter BURST_MODE            = "8",
                                     // DDR3 SDRAM:
                                     // Burst Length (Mode Register 0).
                                     // # = "8", "4", "OTF".
                                     // DDR2 SDRAM:
                                     // Burst Length (Mode Register).
                                     // # = "8", "4".

   
   //***************************************************************************
   // The following parameters are multiplier and divisor factors for PLLE2.
   // Based on the selected design frequency these parameters vary.
   //***************************************************************************
   parameter CLKIN_PERIOD          = 5000,
                                     // Input Clock Period
   parameter CLKFBOUT_MULT         = 8,
                                     // write PLL VCO multiplier
   parameter DIVCLK_DIVIDE         = 1,
                                     // write PLL VCO divisor
   parameter CLKOUT0_PHASE         = 337.5,
                                     // Phase for PLL output clock (CLKOUT0)
   parameter CLKOUT0_DIVIDE        = 2,
                                     // VCO output divisor for PLL output clock (CLKOUT0)
   parameter CLKOUT1_DIVIDE        = 2,
                                     // VCO output divisor for PLL output clock (CLKOUT1)
   parameter CLKOUT2_DIVIDE        = 32,
                                     // VCO output divisor for PLL output clock (CLKOUT2)
   parameter CLKOUT3_DIVIDE        = 8,
                                     // VCO output divisor for PLL output clock (CLKOUT3)
   parameter MMCM_VCO              = 800,
                                     // Max Freq (MHz) of MMCM VCO
   parameter MMCM_MULT_F           = 4,
                                     // write MMCM VCO multiplier
   parameter MMCM_DIVCLK_DIVIDE    = 1,
                                     // write MMCM VCO divisor

   //***************************************************************************
   // Simulation parameters
   //***************************************************************************
   parameter SIMULATION            = "FALSE",
                                     // Should be TRUE during design simulations and
                                     // FALSE during implementations

   //***************************************************************************
   // IODELAY and PHY related parameters
   //***************************************************************************
   parameter TCQ                   = 100,
   
   parameter DRAM_TYPE             = "DDR3",

   
   //***************************************************************************
   // System clock frequency parameters
   //***************************************************************************
   parameter nCK_PER_CLK           = 4,
                                     // # of memory CKs per fabric CLK

   
   //***************************************************************************
   // AXI4 Shim parameters
   //***************************************************************************
   parameter C_S_AXI_ID_WIDTH              = 5,
                                             // Width of all master and slave ID signals.
                                             // # = >= 1.
   parameter C_S_AXI_ADDR_WIDTH            = 30,
                                             // Width of S_AXI_AWADDR, S_AXI_ARADDR, M_AXI_AWADDR and
                                             // M_AXI_ARADDR for all SI/MI slots.
                                             // # = 32.
   parameter C_S_AXI_DATA_WIDTH            = 64,
                                             // Width of WDATA and RDATA on SI slot.
                                             // Must be <= APP_DATA_WIDTH.
                                             // # = 32, 64, 128, 256.
   parameter C_S_AXI_SUPPORTS_NARROW_BURST = 0,
                                             // Indicates whether to instatiate upsizer
                                             // Range: 0, 1
      

   //***************************************************************************
   // Debug parameters
   //***************************************************************************
   parameter DEBUG_PORT            = "OFF",
                                     // # = "ON" Enable debug signals/controls.
                                     //   = "OFF" Disable debug signals/controls.
      
   parameter RST_ACT_LOW           = 1
                                     // =1 for active low reset,
                                     // =0 for active high.
   )
  (

   // Inouts
   inout [31:0]  ddr3_dq,
   inout [3:0]   ddr3_dqs_n,
   inout [3:0]   ddr3_dqs_p,

   // Outputs
   output [14:0] ddr3_addr,
   output [2:0]  ddr3_ba,
   output        ddr3_ras_n,
   output        ddr3_cas_n,
   output        ddr3_we_n,
   output        ddr3_reset_n,
   output [0:0]  ddr3_ck_p,
   output [0:0]  ddr3_ck_n,
   output [0:0]  ddr3_cke,
   
   output [0:0]  ddr3_cs_n,
   
   output [3:0]  ddr3_dm,
   
   output [0:0]  ddr3_odt,
   

   // Inputs
   
   // Differential system clocks
   input         sys_clk_p,
   input         sys_clk_n,
   

   output        init_calib_complete,
   
      

   // System reset - Default polarity of sys_rst pin is Active Low.
   // System reset polarity will change based on the option 
   // selected in GUI.
   input         sys_rst,
   input         clk_i,
   input         ndmreset_n,
                 
   AXI_BUS.in    incoming_if   
   );

function integer clogb2 (input integer size);
    begin
      size = size - 1;
      for (clogb2=1; size>1; clogb2=clogb2+1)
        size = size >> 1;
    end
  endfunction // clogb2

  function integer STR_TO_INT;
    input [7:0] in;
    begin
      if(in == "8")
        STR_TO_INT = 8;
      else if(in == "4")
        STR_TO_INT = 4;
      else
        STR_TO_INT = 0;
    end
  endfunction


  localparam DATA_WIDTH            = 32;
  localparam RANK_WIDTH = clogb2(RANKS);
  localparam PAYLOAD_WIDTH         = (ECC_TEST == "OFF") ? DATA_WIDTH : DQ_WIDTH;
  localparam BURST_LENGTH          = STR_TO_INT(BURST_MODE);
  localparam APP_DATA_WIDTH        = 2 * nCK_PER_CLK * PAYLOAD_WIDTH;
  localparam APP_MASK_WIDTH        = APP_DATA_WIDTH / 8;

  //***************************************************************************
  // Traffic Gen related parameters (derived)
  //***************************************************************************
  localparam  TG_ADDR_WIDTH = ((CS_WIDTH == 1) ? 0 : RANK_WIDTH)
                                 + BANK_WIDTH + ROW_WIDTH + COL_WIDTH;
  localparam MASK_SIZE             = DATA_WIDTH/8;
  localparam DBG_WR_STS_WIDTH      = 40;
  localparam DBG_RD_STS_WIDTH      = 40;
      

  // Wire declarations
      
  wire                              clk;
  wire                              rst;
  wire                              mmcm_locked;
  reg                               aresetn;
  wire                              app_sr_active;
  wire                              app_ref_ack;
  wire                              app_zq_ack;
  wire                              app_rd_data_valid;
  wire [APP_DATA_WIDTH-1:0]         app_rd_data;

  wire                              mem_pattern_init_done;

  // Slave Interface Write Address Ports
  wire [C_S_AXI_ID_WIDTH-1:0]       s_axi_awid;
  wire [C_S_AXI_ADDR_WIDTH-1:0]     s_axi_awaddr;
  wire [7:0]                        s_axi_awlen;
  wire [2:0]                        s_axi_awsize;
  wire [1:0]                        s_axi_awburst;
  wire [0:0]                        s_axi_awlock;
  wire [3:0]                        s_axi_awcache;
  wire [2:0]                        s_axi_awprot;
  wire                              s_axi_awvalid;
  wire                              s_axi_awready;
  wire [3:0]                        s_axi_awqos;
  wire [3:0]                        s_axi_awregion;
   
   // Slave Interface Write Data Ports
  wire [C_S_AXI_DATA_WIDTH-1:0]     s_axi_wdata;
  wire [(C_S_AXI_DATA_WIDTH/8)-1:0] s_axi_wstrb;
  wire                              s_axi_wlast;
  wire                              s_axi_wvalid;
  wire                              s_axi_wready;
   // Slave Interface Write Response Ports
  wire                              s_axi_bready;
  wire [C_S_AXI_ID_WIDTH-1:0]       s_axi_bid;
  wire [1:0]                        s_axi_bresp;
  wire                              s_axi_bvalid;
   // Slave Interface Read Address Ports
  wire [C_S_AXI_ID_WIDTH-1:0]       s_axi_arid;
  wire [C_S_AXI_ADDR_WIDTH-1:0]     s_axi_araddr;
  wire [7:0]                        s_axi_arlen;
  wire [2:0]                        s_axi_arsize;
  wire [1:0]                        s_axi_arburst;
  wire [0:0]                        s_axi_arlock;
  wire [3:0]                        s_axi_arcache;
  wire [2:0]                        s_axi_arprot;
  wire                              s_axi_arvalid;
  wire                              s_axi_arready;
  wire [3:0]                        s_axi_arqos;
  wire [3:0]                        s_axi_arregion;
   // Slave Interface Read Data Ports
  wire                              s_axi_rready;
  wire [C_S_AXI_ID_WIDTH-1:0]       s_axi_rid;
  wire [C_S_AXI_DATA_WIDTH-1:0]     s_axi_rdata;
  wire [1:0]                        s_axi_rresp;
  wire                              s_axi_rlast;
  wire                              s_axi_rvalid;

  wire [11:0]                           device_temp;
  
`ifdef SKIP_CALIB
  // skip calibration wires
  wire                          calib_tap_req;
  reg                           calib_tap_load;
  reg [6:0]                     calib_tap_addr;
  reg [7:0]                     calib_tap_val;
  reg                           calib_tap_load_done;
`endif
      
  

//***************************************************************************



      
// Start of User Design top instance
//***************************************************************************
// The User design is instantiated below. The memory interface ports are
// connected to the top-level and the application interface ports are
// connected to the traffic generator module. This provides a reference
// for connecting the memory controller to system.
//***************************************************************************

  xlnx_mig_7_ddr3 u_xlnx_mig_7_ddr3
      (
       
       
// Memory interface ports
       .ddr3_addr                      (ddr3_addr),
       .ddr3_ba                        (ddr3_ba),
       .ddr3_cas_n                     (ddr3_cas_n),
       .ddr3_ck_n                      (ddr3_ck_n),
       .ddr3_ck_p                      (ddr3_ck_p),
       .ddr3_cke                       (ddr3_cke),
       .ddr3_ras_n                     (ddr3_ras_n),
       .ddr3_we_n                      (ddr3_we_n),
       .ddr3_dq                        (ddr3_dq),
       .ddr3_dqs_n                     (ddr3_dqs_n),
       .ddr3_dqs_p                     (ddr3_dqs_p),
       .ddr3_reset_n                   (ddr3_reset_n),
       .init_calib_complete            (init_calib_complete),
      
       .ddr3_cs_n                      (ddr3_cs_n),
       .ddr3_dm                        (ddr3_dm),
       .ddr3_odt                       (ddr3_odt),
// Application interface ports
       .ui_clk                         (clk),
       .ui_clk_sync_rst                (rst),

       .mmcm_locked                    (mmcm_locked),
       .aresetn                        (aresetn),
       .app_sr_req                     (1'b0),
       .app_ref_req                    (1'b0),
       .app_zq_req                     (1'b0),
       .app_sr_active                  (app_sr_active),
       .app_ref_ack                    (app_ref_ack),
       .app_zq_ack                     (app_zq_ack),

// Slave Interface Write Address Ports
       .s_axi_awid                     (s_axi_awid),
       .s_axi_awaddr                   (s_axi_awaddr),
       .s_axi_awlen                    (s_axi_awlen),
       .s_axi_awsize                   (s_axi_awsize),
       .s_axi_awburst                  (s_axi_awburst),
       .s_axi_awlock                   (s_axi_awlock),
       .s_axi_awcache                  (s_axi_awcache),
       .s_axi_awprot                   (s_axi_awprot),
       .s_axi_awqos                    (s_axi_awqos),
       .s_axi_awvalid                  (s_axi_awvalid),
       .s_axi_awready                  (s_axi_awready),
// Slave Interface Write Data Ports
       .s_axi_wdata                    (s_axi_wdata),
       .s_axi_wstrb                    (s_axi_wstrb),
       .s_axi_wlast                    (s_axi_wlast),
       .s_axi_wvalid                   (s_axi_wvalid),
       .s_axi_wready                   (s_axi_wready),
// Slave Interface Write Response Ports
       .s_axi_bid                      (s_axi_bid),
       .s_axi_bresp                    (s_axi_bresp),
       .s_axi_bvalid                   (s_axi_bvalid),
       .s_axi_bready                   (s_axi_bready),
// Slave Interface Read Address Ports
       .s_axi_arid                     (s_axi_arid),
       .s_axi_araddr                   (s_axi_araddr),
       .s_axi_arlen                    (s_axi_arlen),
       .s_axi_arsize                   (s_axi_arsize),
       .s_axi_arburst                  (s_axi_arburst),
       .s_axi_arlock                   (s_axi_arlock),
       .s_axi_arcache                  (s_axi_arcache),
       .s_axi_arprot                   (s_axi_arprot),
       .s_axi_arqos                    (s_axi_arqos),
       .s_axi_arvalid                  (s_axi_arvalid),
       .s_axi_arready                  (s_axi_arready),
// Slave Interface Read Data Ports
       .s_axi_rid                      (s_axi_rid),
       .s_axi_rdata                    (s_axi_rdata),
       .s_axi_rresp                    (s_axi_rresp),
       .s_axi_rlast                    (s_axi_rlast),
       .s_axi_rvalid                   (s_axi_rvalid),
       .s_axi_rready                   (s_axi_rready),

      
       
// System Clock Ports
       .sys_clk_p                       (sys_clk_p),
       .sys_clk_n                       (sys_clk_n),
       .device_temp            (device_temp),
       `ifdef SKIP_CALIB
       .calib_tap_req                    (calib_tap_req),
       .calib_tap_load                   (calib_tap_load),
       .calib_tap_addr                   (calib_tap_addr),
       .calib_tap_val                    (calib_tap_val),
       .calib_tap_load_done              (calib_tap_load_done),
       `endif
      
       .sys_rst                        (sys_rst)
       );
// End of User Design top instance


//***************************************************************************
// The traffic generation module instantiated below drives traffic (patterns)
// on the application interface of the memory controller
//***************************************************************************

   always @(posedge clk) begin
     aresetn <= ~rst;
   end

xlnx_axi_clock_converter i_xlnx_axi_clock_converter_ddr (
  .s_axi_aclk(clk_i),
  .s_axi_aresetn(ndmreset_n),
  .s_axi_awid(incoming_if.aw_id),
  .s_axi_awaddr(incoming_if.aw_addr),
  .s_axi_awlen(incoming_if.aw_len),
  .s_axi_awsize(incoming_if.aw_size),
  .s_axi_awburst(incoming_if.aw_burst),
  .s_axi_awlock(incoming_if.aw_lock),
  .s_axi_awcache(incoming_if.aw_cache),
  .s_axi_awprot(incoming_if.aw_prot),
  .s_axi_awregion(incoming_if.aw_region),
  .s_axi_awqos(incoming_if.aw_qos),
//  .s_axi_awuser(incoming_if.aw_user),
  .s_axi_awvalid(incoming_if.aw_valid),
  .s_axi_awready(incoming_if.aw_ready),
  .s_axi_wdata(incoming_if.w_data),
  .s_axi_wstrb(incoming_if.w_strb),
  .s_axi_wlast(incoming_if.w_last),
//  .s_axi_wuser(incoming_if.w_user),
  .s_axi_wvalid(incoming_if.w_valid),
  .s_axi_wready(incoming_if.w_ready),
  .s_axi_bid(incoming_if.b_id),
  .s_axi_bresp(incoming_if.b_resp),
//  .s_axi_buser(incoming_if.b_user),
  .s_axi_bvalid(incoming_if.b_valid),
  .s_axi_bready(incoming_if.b_ready),
  .s_axi_arid(incoming_if.ar_id),
  .s_axi_araddr(incoming_if.ar_addr),
  .s_axi_arlen(incoming_if.ar_len),
  .s_axi_arsize(incoming_if.ar_size),
  .s_axi_arburst(incoming_if.ar_burst),
  .s_axi_arlock(incoming_if.ar_lock),
  .s_axi_arcache(incoming_if.ar_cache),
  .s_axi_arprot(incoming_if.ar_prot),
  .s_axi_arregion(incoming_if.ar_region),
  .s_axi_arqos(incoming_if.ar_qos),
//  .s_axi_aruser(incoming_if.ar_user),
  .s_axi_arvalid(incoming_if.ar_valid),
  .s_axi_arready(incoming_if.ar_ready),
  .s_axi_rid(incoming_if.r_id),
  .s_axi_rdata(incoming_if.r_data),
  .s_axi_rresp(incoming_if.r_resp),
  .s_axi_rlast(incoming_if.r_last),
//  .s_axi_ruser(incoming_if.r_user),
  .s_axi_rvalid(incoming_if.r_valid),
  .s_axi_rready(incoming_if.r_ready),
   
  .m_axi_aclk     ( clk                                ),
  .m_axi_aresetn  ( ndmreset_n                         ),
// AXI write address channel signals
     .m_axi_awready                       (s_axi_awready),
     .m_axi_awid                          (s_axi_awid),
     .m_axi_awaddr                        (s_axi_awaddr),
     .m_axi_awlen                         (s_axi_awlen),
     .m_axi_awsize                        (s_axi_awsize),
     .m_axi_awburst                       (s_axi_awburst),
     .m_axi_awlock                        (s_axi_awlock),
     .m_axi_awcache                       (s_axi_awcache),
     .m_axi_awprot                        (s_axi_awprot),
     .m_axi_awvalid                       (s_axi_awvalid),
     .m_axi_awregion                      (s_axi_awregion),
     .m_axi_awqos                         (s_axi_awqos),
// AXI write data channel signals
     .m_axi_wready                     (s_axi_wready),
     .m_axi_wdata                      (s_axi_wdata),
     .m_axi_wstrb                      (s_axi_wstrb),
     .m_axi_wlast                      (s_axi_wlast),
     .m_axi_wvalid                     (s_axi_wvalid),

// AXI write response channel signals
     .m_axi_bid                       (s_axi_bid),
     .m_axi_bresp                     (s_axi_bresp),
     .m_axi_bvalid                    (s_axi_bvalid),
     .m_axi_bready                    (s_axi_bready),

// AXI read address channel signals
     .m_axi_arready                       (s_axi_arready),
     .m_axi_arid                          (s_axi_arid),
     .m_axi_araddr                        (s_axi_araddr),
     .m_axi_arlen                         (s_axi_arlen),
     .m_axi_arsize                        (s_axi_arsize),
     .m_axi_arburst                       (s_axi_arburst),
     .m_axi_arlock                        (s_axi_arlock),
     .m_axi_arcache                       (s_axi_arcache),
     .m_axi_arprot                        (s_axi_arprot),
     .m_axi_arvalid                       (s_axi_arvalid),
     .m_axi_arregion                      (s_axi_arregion),
     .m_axi_arqos                         (s_axi_arqos),

// AXI read data channel signals
     .m_axi_rid                       (s_axi_rid),
     .m_axi_rresp                     (s_axi_rresp),
     .m_axi_rvalid                    (s_axi_rvalid),
     .m_axi_rdata                      (s_axi_rdata),
     .m_axi_rlast                      (s_axi_rlast),
     .m_axi_rready                    (s_axi_rready)
);

      


   //*****************************************************************
   // Default values are assigned to the debug inputs
   //*****************************************************************
   assign dbg_sel_pi_incdec       = 'b0;
   assign dbg_sel_po_incdec       = 'b0;
   assign dbg_pi_f_inc            = 'b0;
   assign dbg_pi_f_dec            = 'b0;
   assign dbg_po_f_inc            = 'b0;
   assign dbg_po_f_dec            = 'b0;
   assign dbg_po_f_stg23_sel      = 'b0;
   assign po_win_tg_rst           = 'b0;
   assign vio_tg_rst              = 'b0;
`ifdef SKIP_CALIB
  //***************************************************************************
  // Skip calib test logic
  //***************************************************************************

  reg[3*DQS_WIDTH-1:0]        po_coarse_tap;
  reg[6*DQS_WIDTH-1:0]        po_stg3_taps;
  reg[6*DQS_WIDTH-1:0]        po_stg2_taps;
  reg[6*DQS_WIDTH-1:0]        pi_stg2_taps;
  reg[5*DQS_WIDTH-1:0]        idelay_taps;
  reg[11:0]                   cal_device_temp;


  always @(posedge clk) begin
    // tap values from golden run (factory)
    po_coarse_tap   <= #TCQ 'h2;
    po_stg3_taps    <= #TCQ 'h0D;
    po_stg2_taps    <= #TCQ 'h1D;
    pi_stg2_taps    <= #TCQ 'h1E;
    idelay_taps     <= #TCQ 'h08;
        cal_device_temp <= #TCQ 'h000;
  end

  always @(posedge clk) begin
    if (rst)
      calib_tap_load <= #TCQ 1'b0;
    else if (calib_tap_req)
      calib_tap_load <= #TCQ 1'b1;
  end

  always @(posedge clk) begin
    if (rst) begin
      calib_tap_addr      <= #TCQ 'd0;
      calib_tap_val       <= #TCQ po_coarse_tap[3*calib_tap_addr[6:3]+:3]; //'d1;
      calib_tap_load_done <= #TCQ 1'b0;
    end else if (calib_tap_load) begin
      case (calib_tap_addr[2:0])
        3'b000: begin
          calib_tap_addr[2:0] <= #TCQ 3'b001;
          calib_tap_val       <= #TCQ po_stg3_taps[6*calib_tap_addr[6:3]+:6]; //'d19;
        end
        3'b001: begin
          calib_tap_addr[2:0] <= #TCQ 3'b010;
          calib_tap_val       <= #TCQ po_stg2_taps[6*calib_tap_addr[6:3]+:6]; //'d45;
        end
        3'b010: begin
          calib_tap_addr[2:0] <= #TCQ 3'b011;
          calib_tap_val       <= #TCQ pi_stg2_taps[6*calib_tap_addr[6:3]+:6]; //'d20;
        end
        3'b011: begin
          calib_tap_addr[2:0] <= #TCQ 3'b100;
          calib_tap_val       <= #TCQ idelay_taps[5*calib_tap_addr[6:3]+:5]; //'d1;
        end
        3'b100: begin
          if (calib_tap_addr[6:3] < DQS_WIDTH-1) begin
            calib_tap_addr[2:0] <= #TCQ 3'b000;
            calib_tap_val       <= #TCQ po_coarse_tap[3*(calib_tap_addr[6:3]+1)+:3]; //'d1;
            calib_tap_addr[6:3] <= #TCQ calib_tap_addr[6:3] + 1;
          end else begin
            calib_tap_addr[2:0] <= #TCQ 3'b110;
            calib_tap_val       <= #TCQ cal_device_temp[7:0];
            calib_tap_addr[6:3] <= #TCQ 4'b1111;
          end
        end
        3'b110: begin
            calib_tap_addr[2:0] <= #TCQ 3'b111;
            calib_tap_val       <= #TCQ {4'h0,cal_device_temp[11:8]};
            calib_tap_addr[6:3] <= #TCQ 4'b1111;
        end
        3'b111: begin
            calib_tap_load_done <= #TCQ 1'b1;
        end
      endcase
    end
  end


//****************skip calib test logic end**********************************
`endif    

endmodule
