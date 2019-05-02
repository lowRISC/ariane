// Copyright 2018 ETH Zurich and University of Bologna.
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the "License"); you may not use this file except in
// compliance with the License.  You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.

// Description: Xilinx FPGA top-level
// Author: Florian Zaruba <zarubaf@iis.ee.ethz.ch>

module ariane_xilinx (
  input  logic        clk_p       ,
  input  logic        cpu_resetn  ,
  inout  wire  [15:0] ddr2_dq     ,
  inout  wire  [ 1:0] ddr2_dqs_n  ,
  inout  wire  [ 1:0] ddr2_dqs_p  ,
  output logic [12:0] ddr2_addr   ,
  output logic [ 2:0] ddr2_ba     ,
  output logic        ddr2_ras_n  ,
  output logic        ddr2_cas_n  ,
  output logic        ddr2_we_n   ,
  output logic [ 0:0] ddr2_ck_p   ,
  output logic [ 0:0] ddr2_ck_n   ,
  output logic [ 0:0] ddr2_cke    ,
  output logic [ 1:0] ddr2_dm     ,
  output logic [ 0:0] ddr2_odt    ,
  //! Ethernet MAC PHY interface signals
  input wire [1:0]    i_erxd, // RMII receive data
  input wire          i_erx_dv, // PHY data valid
  input wire          i_erx_er, // PHY coding error
  input wire          i_emdint, // PHY interrupt in active low
  output reg          o_erefclk, // RMII clock out
  output reg [1:0]    o_etxd, // RMII transmit data
  output reg          o_etx_en, // RMII transmit enable
  output wire         o_emdc, // MDIO clock
  inout wire          io_emdio, // MDIO inout
  output wire         o_erstn, // PHY reset active low 
  output logic [ 7:0]  led         ,
  input  logic [ 7:0]  sw          ,
  output logic         fan_pwm     ,
  // SD (shared with SPI)
  output wire        sd_sclk,
  input wire         sd_detect,
  inout wire [3:0]   sd_dat,
  inout wire         sd_cmd,
  output reg         sd_reset,
  // common part
  input  logic        tck         ,
  input  logic        tms         ,
  input  logic        trst_n      ,
  input  logic        tdi         ,
  output logic        tdo         ,
  input  logic        rx          ,
  output logic        tx          ,
  // Quad-SPI
  inout wire          QSPI_CSN    ,
  inout wire [3:0]    QSPI_D
);
// 24 MByte in 8 byte words
localparam NumWords = (24 * 1024 * 1024) / 8;
localparam NBSlave = 2; // debug, ariane
localparam AxiAddrWidth = 64;
localparam AxiDataWidth = 64;
localparam AxiIdWidthMaster = 4;
localparam AxiIdWidthSlaves = AxiIdWidthMaster + $clog2(NBSlave); // 5
localparam AxiUserWidth = 1;

// MIG clock
logic mig_sys_clk, mig_ui_clk, mig_ui_rst, mig_ui_rstn, sys_rst,
      clk, clk_rmii, clk_rmii_quad, clk_pixel, clk_locked_wiz;
logic ndmreset_n;
logic rst_n;

assign mig_ui_rstn = !mig_ui_rst;
assign clk = mig_ui_clk;

xlnx_clk_nexys i_xlnx_clk_gen (
  .clk_out1 ( mig_sys_clk    ), // 200 MHz
  .clk_out2 ( clk_rmii       ), // 50 MHz (for RGMII PHY)
  .clk_out3 ( clk_rmii_quad  ), // 50 MHz quadrature (90 deg phase shift)
  .clk_out4 ( clk_pixel      ), // 120 MHz clock
  .resetn   ( cpu_resetn     ),
  .locked   ( clk_locked_wiz ),
  .clk_in1  ( clk_p          )
);

logic rst_done;   
logic [5:0] rst_count;
   
always @(posedge clk_p or negedge cpu_resetn)
  if (!cpu_resetn)
    begin
       rst_count <= '0;
       rst_done = '0;
       rst_n = '0;
    end
  else
    begin
       rst_done = &rst_count;
       rst_count <= rst_count + !rst_done;
       if (rst_done && clk_locked_wiz)
         rst_n = '1;
    end

// ---------------
// DDR
// ---------------

AXI_BUS #(
    .AXI_ADDR_WIDTH ( AxiAddrWidth     ),
    .AXI_DATA_WIDTH ( AxiDataWidth     ),
    .AXI_ID_WIDTH   ( AxiIdWidthSlaves ),
    .AXI_USER_WIDTH ( AxiUserWidth     )
) dram();
   
xlnx_mig_7_ddr3 i_ddr (
    .sys_clk_i          ( mig_sys_clk ),
    .sys_rst            ( rst_n  ),
    .ui_addn_clk_0      (             ),
    .ui_addn_clk_1      (             ),  // output                                       ui_addn_clk_1
    .ui_addn_clk_2      (             ),  // output                                       ui_addn_clk_2
    .ui_addn_clk_3      (             ),  // output                                       ui_addn_clk_3
    .ui_addn_clk_4      (             ),  // output                                       ui_addn_clk_4    
    .device_temp_i      ( 0           ),
    .ddr2_dq,
    .ddr2_dqs_n,
    .ddr2_dqs_p,
    .ddr2_addr,
    .ddr2_ba,
    .ddr2_ras_n,
    .ddr2_cas_n,
    .ddr2_we_n,
    .ddr2_ck_p,
    .ddr2_ck_n,
    .ddr2_cke,
    .ddr2_dm,
    .ddr2_odt,
    .ui_clk          ( mig_ui_clk     ),
    .ui_clk_sync_rst ( mig_ui_rst     ),
    .mmcm_locked     (                ), // keep open
    .aresetn         ( ndmreset_n     ),
    .app_sr_req      ( '0             ),
    .app_ref_req     ( '0             ),
    .app_zq_req      ( '0             ),
    .app_sr_active   (                ), // keep open
    .app_ref_ack     (                ), // keep open
    .app_zq_ack      (                ), // keep open
    .s_axi_awid      ( dram.aw_id     ),
    .s_axi_awaddr    ( dram.aw_addr   ),
    .s_axi_awlen     ( dram.aw_len    ),
    .s_axi_awsize    ( dram.aw_size   ),
    .s_axi_awburst   ( dram.aw_burst  ),
    .s_axi_awlock    ( dram.aw_lock   ),
    .s_axi_awcache   ( dram.aw_cache  ),
    .s_axi_awprot    ( dram.aw_prot   ),
    .s_axi_awqos     ( dram.aw_qos    ),
    .s_axi_awvalid   ( dram.aw_valid  ),
    .s_axi_awready   ( dram.aw_ready  ),
    .s_axi_wdata     ( dram.w_data    ),
    .s_axi_wstrb     ( dram.w_strb    ),
    .s_axi_wlast     ( dram.w_last    ),
    .s_axi_wvalid    ( dram.w_valid   ),
    .s_axi_wready    ( dram.w_ready   ),
    .s_axi_bid       ( dram.b_id      ),
    .s_axi_bresp     ( dram.b_resp    ),
    .s_axi_bvalid    ( dram.b_valid   ),
    .s_axi_bready    ( dram.b_ready   ),
    .s_axi_arid      ( dram.ar_id     ),
    .s_axi_araddr    ( dram.ar_addr   ),
    .s_axi_arlen     ( dram.ar_len    ),
    .s_axi_arsize    ( dram.ar_size   ),
    .s_axi_arburst   ( dram.ar_burst  ),
    .s_axi_arlock    ( dram.ar_lock   ),
    .s_axi_arcache   ( dram.ar_cache  ),
    .s_axi_arprot    ( dram.ar_prot   ),
    .s_axi_arqos     ( dram.ar_qos    ),
    .s_axi_arvalid   ( dram.ar_valid  ),
    .s_axi_arready   ( dram.ar_ready  ),
    .s_axi_rid       ( dram.r_id      ),
    .s_axi_rdata     ( dram.r_data    ),
    .s_axi_rresp     ( dram.r_resp    ),
    .s_axi_rlast     ( dram.r_last    ),
    .s_axi_rvalid    ( dram.r_valid   ),
    .s_axi_rready    ( dram.r_ready   ),
    .init_calib_complete (            ) // keep open
);

// disable test-enable
logic test_en;
logic ndmreset;
logic debug_req_irq;
logic time_irq;
logic ipi;

logic eth_clk;
logic spi_clk_i;
logic phy_tx_clk;
logic sd_clk_sys;

logic rtc;

logic cpu_reset;

assign cpu_reset  = ~cpu_resetn;
assign sys_rst = ~rst_n;

// ---------------
// Peripherals
// ---------------
ariane_peripherals #(
    .AxiAddrWidth ( AxiAddrWidth     ),
    .AxiDataWidth ( AxiDataWidth     ),
    .AxiIdWidth   ( AxiIdWidthSlaves ),
    .AxiUserWidth ( AxiUserWidth     ),
    .InclUART     ( 1'b1             ),
    .InclGPIO     ( 1'b1             ),
    .InclSPI      ( 1'b1         ),
    .InclEthernet ( 1'b1         )
) i_ariane_peripherals (
    .clk_i         ( clk                          ),
    .clk_200MHz_i  ( mig_sys_clk                  ),
    .rst_ni        ( ndmreset_n                   ),
    .plic          ( master[ariane_soc::PLIC]     ),
    .uart          ( master[ariane_soc::UART]     ),
    .spi           ( master[ariane_soc::SPI]      ),
    .gpio          ( master[ariane_soc::GPIO]     ),
    .ethernet      ( master[ariane_soc::Ethernet] ),
    .irq_o         ( irq                          ),
    .rx_i          ( rx                           ),
    .tx_o          ( tx                           ),
    .clk_rmii      ( clk_rmii                     ),
    .clk_rmii_quad ( clk_rmii_quad                ),
    .i_erxd, // RMII receive data
    .i_erx_dv, // PHY data valid
    .i_erx_er, // PHY coding error
    .i_emdint, // PHY interrupt in active low
    .o_erefclk, // RMII clock out
    .o_etxd, // RMII transmit data
    .o_etx_en, // RMII transmit enable
    .o_emdc, // MDIO clock
    .io_emdio, // MDIO inout
    .o_erstn, // PHY reset active low 
    .sd_sclk,
    .sd_detect,
    .sd_dat,
    .sd_cmd,
    .sd_reset,
    .leds_o         ( led                         ),
    .dip_switches_i ( sw                          ),
    .QSPI_CSN,
    .QSPI_D
);


// ---------------------
// Board peripherals
// ---------------------

fan_ctrl i_fan_ctrl (
    .clk_i         ( clk        ),
    .rst_ni        ( ndmreset_n ),
    .pwm_setting_i ( 'd8        ),
    .fan_pwm_o     ( fan_pwm    )
);

endmodule
