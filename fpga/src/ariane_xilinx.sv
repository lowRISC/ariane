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


AXI_BUS #(
    .AXI_ADDR_WIDTH ( AxiAddrWidth     ),
    .AXI_DATA_WIDTH ( AxiDataWidth     ),
    .AXI_ID_WIDTH   ( AxiIdWidthMaster ),
    .AXI_USER_WIDTH ( AxiUserWidth     )
) slave[NBSlave-1:0]();

AXI_BUS #(
    .AXI_ADDR_WIDTH ( AxiAddrWidth     ),
    .AXI_DATA_WIDTH ( AxiDataWidth     ),
    .AXI_ID_WIDTH   ( AxiIdWidthSlaves ),
    .AXI_USER_WIDTH ( AxiUserWidth     )
) master[ariane_soc::NB_PERIPHERALS-1:0]();

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

// ROM
logic                    rom_req, rom_we;
logic [AxiAddrWidth-1:0] rom_addr;
logic [AxiDataWidth-1:0] rom_rdata, rom_wdata;
logic [AxiDataWidth/8-1:0] rom_be;
// Debug
logic          debug_req_valid;
logic          debug_req_ready;
dm::dmi_req_t  debug_req;
logic          debug_resp_valid;
logic          debug_resp_ready;
dm::dmi_resp_t debug_resp;

logic dmactive;

// IRQ
logic [1:0] irq;
logic    timer_irq;
assign test_en    = 1'b0;

logic [NBSlave-1:0] pc_asserted;

rstgen i_rstgen_main (
    .clk_i        ( clk                      ),
    .rst_ni       ( rst_n & (~ndmreset)      ),
    .test_mode_i  ( test_en                  ),
    .rst_no       ( ndmreset_n               ),
    .init_no      (                          ) // keep open
);

// ---------------
// AXI Xbar
// ---------------
axi_node_wrap_with_slices #(
    // three ports from Ariane (instruction, data and bypass)
    .NB_SLAVE           ( NBSlave                    ),
    .NB_MASTER          ( ariane_soc::NB_PERIPHERALS ),
    .NB_REGION          ( ariane_soc::NrRegion       ),
    .AXI_ADDR_WIDTH     ( AxiAddrWidth               ),
    .AXI_DATA_WIDTH     ( AxiDataWidth               ),
    .AXI_USER_WIDTH     ( AxiUserWidth               ),
    .AXI_ID_WIDTH       ( AxiIdWidthMaster           ),
    .MASTER_SLICE_DEPTH ( 2                          ),
    .SLAVE_SLICE_DEPTH  ( 2                          )
) i_axi_xbar (
    .clk          ( clk        ),
    .rst_n        ( ndmreset_n ),
    .test_en_i    ( test_en    ),
    .slave        ( slave      ),
    .master       ( master     ),
    .start_addr_i ({
        ariane_soc::DebugBase,
        ariane_soc::ROMBase,
        ariane_soc::CLINTBase,
        ariane_soc::PLICBase,
        ariane_soc::UARTBase,
        ariane_soc::SPIBase,
        ariane_soc::EthernetBase,
        ariane_soc::GPIOBase,
        ariane_soc::DRAMBase
    }),
    .end_addr_i   ({
        ariane_soc::DebugBase    + ariane_soc::DebugLength - 1,
        ariane_soc::ROMBase      + ariane_soc::ROMLength - 1,
        ariane_soc::CLINTBase    + ariane_soc::CLINTLength - 1,
        ariane_soc::PLICBase     + ariane_soc::PLICLength - 1,
        ariane_soc::UARTBase     + ariane_soc::UARTLength - 1,
        ariane_soc::SPIBase      + ariane_soc::SPILength - 1,
        ariane_soc::EthernetBase + ariane_soc::EthernetLength -1,
        ariane_soc::GPIOBase     + ariane_soc::GPIOLength - 1,
        ariane_soc::DRAMBase     + ariane_soc::DRAMLength - 1
    }),
    .valid_rule_i (ariane_soc::ValidRule)
);

// ---------------
// Debug Module
// ---------------
dmi_jtag i_dmi_jtag (
    .clk_i                ( clk                  ),
    .rst_ni               ( rst_n                ),
    .dmi_rst_no           (                      ), // keep open
    .testmode_i           ( test_en              ),
    .dmi_req_valid_o      ( debug_req_valid      ),
    .dmi_req_ready_i      ( debug_req_ready      ),
    .dmi_req_o            ( debug_req            ),
    .dmi_resp_valid_i     ( debug_resp_valid     ),
    .dmi_resp_ready_o     ( debug_resp_ready     ),
    .dmi_resp_i           ( debug_resp           ),
    .tck_i                ( tck    ),
    .tms_i                ( tms    ),
    .trst_ni              ( trst_n ),
    .td_i                 ( tdi    ),
    .td_o                 ( tdo    ),
    .tdo_oe_o             (        )
);

ariane_axi::req_t    dm_axi_m_req;
ariane_axi::resp_t   dm_axi_m_resp;

logic                dm_slave_req;
logic                dm_slave_we;
logic [64-1:0]       dm_slave_addr;
logic [64/8-1:0]     dm_slave_be;
logic [64-1:0]       dm_slave_wdata;
logic [64-1:0]       dm_slave_rdata;

logic                dm_master_req;
logic [64-1:0]       dm_master_add;
logic                dm_master_we;
logic [64-1:0]       dm_master_wdata;
logic [64/8-1:0]     dm_master_be;
logic                dm_master_gnt;
logic                dm_master_r_valid;
logic [64-1:0]       dm_master_r_rdata;

// debug module
dm_top #(
    .NrHarts          ( 1                 ),
    .BusWidth         ( AxiDataWidth      ),
    .SelectableHarts  ( 1'b1              )
) i_dm_top (
    .clk_i            ( clk               ),
    .rst_ni           ( rst_n             ), // PoR
    .testmode_i       ( test_en           ),
    .ndmreset_o       ( ndmreset          ),
    .dmactive_o       ( dmactive          ), // active debug session
    .debug_req_o      ( debug_req_irq     ),
    .unavailable_i    ( '0                ),
    .hartinfo_i       ( {ariane_pkg::DebugHartInfo} ),
    .slave_req_i      ( dm_slave_req      ),
    .slave_we_i       ( dm_slave_we       ),
    .slave_addr_i     ( dm_slave_addr     ),
    .slave_be_i       ( dm_slave_be       ),
    .slave_wdata_i    ( dm_slave_wdata    ),
    .slave_rdata_o    ( dm_slave_rdata    ),
    .master_req_o     ( dm_master_req     ),
    .master_add_o     ( dm_master_add     ),
    .master_we_o      ( dm_master_we      ),
    .master_wdata_o   ( dm_master_wdata   ),
    .master_be_o      ( dm_master_be      ),
    .master_gnt_i     ( dm_master_gnt     ),
    .master_r_valid_i ( dm_master_r_valid ),
    .master_r_rdata_i ( dm_master_r_rdata ),
    .dmi_rst_ni       ( rst_n             ),
    .dmi_req_valid_i  ( debug_req_valid   ),
    .dmi_req_ready_o  ( debug_req_ready   ),
    .dmi_req_i        ( debug_req         ),
    .dmi_resp_valid_o ( debug_resp_valid  ),
    .dmi_resp_ready_i ( debug_resp_ready  ),
    .dmi_resp_o       ( debug_resp        )
);

axi2mem #(
    .AXI_ID_WIDTH   ( AxiIdWidthSlaves    ),
    .AXI_ADDR_WIDTH ( AxiAddrWidth        ),
    .AXI_DATA_WIDTH ( AxiDataWidth        ),
    .AXI_USER_WIDTH ( AxiUserWidth        )
) i_dm_axi2mem (
    .clk_i      ( clk                       ),
    .rst_ni     ( rst_n                     ),
    .slave      ( master[ariane_soc::Debug] ),
    .req_o      ( dm_slave_req              ),
    .we_o       ( dm_slave_we               ),
    .addr_o     ( dm_slave_addr             ),
    .be_o       ( dm_slave_be               ),
    .data_o     ( dm_slave_wdata            ),
    .data_i     ( dm_slave_rdata            )
);

axi_master_connect i_dm_axi_master_connect (
  .axi_req_i(dm_axi_m_req),
  .axi_resp_o(dm_axi_m_resp),
  .master(slave[1])
);

axi_adapter #(
    .DATA_WIDTH            ( AxiDataWidth              )
) i_dm_axi_master (
    .clk_i                 ( clk                       ),
    .rst_ni                ( rst_n                     ),
    .req_i                 ( dm_master_req             ),
    .type_i                ( ariane_axi::SINGLE_REQ    ),
    .gnt_o                 ( dm_master_gnt             ),
    .gnt_id_o              (                           ),
    .addr_i                ( dm_master_add             ),
    .we_i                  ( dm_master_we              ),
    .wdata_i               ( dm_master_wdata           ),
    .be_i                  ( dm_master_be              ),
    .size_i                ( 2'b11                     ), // always do 64bit here and use byte enables to gate
    .id_i                  ( '0                        ),
    .valid_o               ( dm_master_r_valid         ),
    .rdata_o               ( dm_master_r_rdata         ),
    .id_o                  (                           ),
    .critical_word_o       (                           ),
    .critical_word_valid_o (                           ),
    .axi_req_o             ( dm_axi_m_req              ),
    .axi_resp_i            ( dm_axi_m_resp             )
);

// ---------------
// Core
// ---------------
ariane_axi::req_t    axi_ariane_req;
ariane_axi::resp_t   axi_ariane_resp;

// For cross-triggering ILA
   
ariane #(
    .ArianeCfg ( ariane_soc::ArianeSocCfg )
) i_ariane (
    .clk_i        ( clk                 ),
    .rst_ni       ( ndmreset_n          ),
    .boot_addr_i  ( ariane_soc::ROMBase ), // start fetching from ROM
    .hart_id_i    ( '0                  ),
    .irq_i        ( irq                 ),
    .ipi_i        ( ipi                 ),
    .time_irq_i   ( timer_irq           ),
    .debug_req_i  ( debug_req_irq       ),
    .axi_req_o    ( axi_ariane_req      ),
    .axi_resp_i   ( axi_ariane_resp     )
);

axi_master_connect i_axi_master_connect_ariane (.axi_req_i(axi_ariane_req), .axi_resp_o(axi_ariane_resp), .master(slave[0]));

// ---------------
// CLINT
// ---------------
// divide clock by two
always_ff @(posedge clk or negedge ndmreset_n) begin
  if (~ndmreset_n) begin
    rtc <= 0;
  end else begin
    rtc <= rtc ^ 1'b1;
  end
end

ariane_axi::req_t    axi_clint_req;
ariane_axi::resp_t   axi_clint_resp;

clint #(
    .AXI_ADDR_WIDTH ( AxiAddrWidth     ),
    .AXI_DATA_WIDTH ( AxiDataWidth     ),
    .AXI_ID_WIDTH   ( AxiIdWidthSlaves ),
    .NR_CORES       ( 1                )
) i_clint (
    .clk_i       ( clk            ),
    .rst_ni      ( ndmreset_n     ),
    .testmode_i  ( test_en        ),
    .axi_req_i   ( axi_clint_req  ),
    .axi_resp_o  ( axi_clint_resp ),
    .rtc_i       ( rtc            ),
    .timer_irq_o ( timer_irq      ),
    .ipi_o       ( ipi            )
);

axi_slave_connect i_axi_slave_connect_clint (.axi_req_o(axi_clint_req), .axi_resp_i(axi_clint_resp), .slave(master[ariane_soc::CLINT]));

// ---------------
// ROM
// ---------------
axi2mem #(
    .AXI_ID_WIDTH   ( AxiIdWidthSlaves ),
    .AXI_ADDR_WIDTH ( AxiAddrWidth     ),
    .AXI_DATA_WIDTH ( AxiDataWidth     ),
    .AXI_USER_WIDTH ( AxiUserWidth     )
) i_axi2rom (
    .clk_i  ( clk                     ),
    .rst_ni ( ndmreset_n              ),
    .slave  ( master[ariane_soc::ROM] ),
    .req_o  ( rom_req                 ),
    .we_o   ( rom_we                  ),
    .addr_o ( rom_addr                ),
    .be_o   ( rom_be                  ),
    .data_o ( rom_wdata               ),
    .data_i ( rom_rdata               )
);

bootram i_bootram (
    .clk_i   ( clk       ),
    .req_i   ( rom_req   ),
    .we_i    ( rom_we    ),
    .addr_i  ( rom_addr  ),
    .be_i    ( rom_be    ),
    .wdata_i ( rom_wdata ),
    .rdata_o ( rom_rdata )
);

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
// ---------------
// DDR
// ---------------
logic [AxiIdWidthSlaves-1:0] s_axi_awid;
logic [AxiAddrWidth-1:0]     s_axi_awaddr;
logic [7:0]                  s_axi_awlen;
logic [2:0]                  s_axi_awsize;
logic [1:0]                  s_axi_awburst;
logic [0:0]                  s_axi_awlock;
logic [3:0]                  s_axi_awcache;
logic [2:0]                  s_axi_awprot;
logic [3:0]                  s_axi_awregion;
logic [3:0]                  s_axi_awqos;
logic                        s_axi_awvalid;
logic                        s_axi_awready;
logic [AxiDataWidth-1:0]     s_axi_wdata;
logic [AxiDataWidth/8-1:0]   s_axi_wstrb;
logic                        s_axi_wlast;
logic                        s_axi_wvalid;
logic                        s_axi_wready;
logic [AxiIdWidthSlaves-1:0] s_axi_bid;
logic [1:0]                  s_axi_bresp;
logic                        s_axi_bvalid;
logic                        s_axi_bready;
logic [AxiIdWidthSlaves-1:0] s_axi_arid;
logic [AxiAddrWidth-1:0]     s_axi_araddr;
logic [7:0]                  s_axi_arlen;
logic [2:0]                  s_axi_arsize;
logic [1:0]                  s_axi_arburst;
logic [0:0]                  s_axi_arlock;
logic [3:0]                  s_axi_arcache;
logic [2:0]                  s_axi_arprot;
logic [3:0]                  s_axi_arregion;
logic [3:0]                  s_axi_arqos;
logic                        s_axi_arvalid;
logic                        s_axi_arready;
logic [AxiIdWidthSlaves-1:0] s_axi_rid;
logic [AxiDataWidth-1:0]     s_axi_rdata;
logic [1:0]                  s_axi_rresp;
logic                        s_axi_rlast;
logic                        s_axi_rvalid;
logic                        s_axi_rready;

AXI_BUS #(
    .AXI_ADDR_WIDTH ( AxiAddrWidth     ),
    .AXI_DATA_WIDTH ( AxiDataWidth     ),
    .AXI_ID_WIDTH   ( AxiIdWidthSlaves ),
    .AXI_USER_WIDTH ( AxiUserWidth     )
) dram();

axi_riscv_atomics_wrap #(
    .AXI_ADDR_WIDTH ( AxiAddrWidth     ),
    .AXI_DATA_WIDTH ( AxiDataWidth     ),
    .AXI_ID_WIDTH   ( AxiIdWidthSlaves ),
    .AXI_USER_WIDTH ( AxiUserWidth     ),
    .AXI_MAX_WRITE_TXNS ( 1  ),
    .RISCV_WORD_WIDTH   ( 64 )
) i_axi_riscv_atomics (
    .clk_i  ( clk                      ),
    .rst_ni ( ndmreset_n               ),
    .slv    ( master[ariane_soc::DRAM] ),
    .mst    ( dram                     )
);

`ifdef PROTOCOL_CHECKER
   wire [159:0]              pc_status;
   wire                      pc_asserted;
   
xlnx_ila_pc your_instance_name (
	                        .clk(clk),           // input wire clk
	                        .probe0(pc_status),  // input wire [159:0]  probe1
	                        .probe1(pc_asserted) // input wire [0:0]  probe0  
);
   

xlnx_protocol_checker i_xlnx_protocol_checker (
  .pc_status,
  .pc_asserted,
  .aclk(clk),
  .aresetn(ndmreset_n),
  .pc_axi_awid     (dram.aw_id),
  .pc_axi_awaddr   (dram.aw_addr),
  .pc_axi_awlen    (dram.aw_len),
  .pc_axi_awsize   (dram.aw_size),
  .pc_axi_awburst  (dram.aw_burst),
  .pc_axi_awlock   (dram.aw_lock),
  .pc_axi_awcache  (dram.aw_cache),
  .pc_axi_awprot   (dram.aw_prot),
  .pc_axi_awqos    (dram.aw_qos),
  .pc_axi_awregion (dram.aw_region),
  .pc_axi_awuser   (dram.aw_user),
  .pc_axi_awvalid  (dram.aw_valid),
  .pc_axi_awready  (dram.aw_ready),
  .pc_axi_wlast    (dram.w_last),
  .pc_axi_wdata    (dram.w_data),
  .pc_axi_wstrb    (dram.w_strb),
  .pc_axi_wuser    (dram.w_user),
  .pc_axi_wvalid   (dram.w_valid),
  .pc_axi_wready   (dram.w_ready),
  .pc_axi_bid      (dram.b_id),
  .pc_axi_bresp    (dram.b_resp),
  .pc_axi_buser    (dram.b_user),
  .pc_axi_bvalid   (dram.b_valid),
  .pc_axi_bready   (dram.b_ready),
  .pc_axi_arid     (dram.ar_id),
  .pc_axi_araddr   (dram.ar_addr),
  .pc_axi_arlen    (dram.ar_len),
  .pc_axi_arsize   (dram.ar_size),
  .pc_axi_arburst  (dram.ar_burst),
  .pc_axi_arlock   (dram.ar_lock),
  .pc_axi_arcache  (dram.ar_cache),
  .pc_axi_arprot   (dram.ar_prot),
  .pc_axi_arqos    (dram.ar_qos),
  .pc_axi_arregion (dram.ar_region),
  .pc_axi_aruser   (dram.ar_user),
  .pc_axi_arvalid  (dram.ar_valid),
  .pc_axi_arready  (dram.ar_ready),
  .pc_axi_rid      (dram.r_id),
  .pc_axi_rlast    (dram.r_last),
  .pc_axi_rdata    (dram.r_data),
  .pc_axi_rresp    (dram.r_resp),
  .pc_axi_ruser    (dram.r_user),
  .pc_axi_rvalid   (dram.r_valid),
  .pc_axi_rready   (dram.r_ready)
);
`endif

fan_ctrl i_fan_ctrl (
    .clk_i         ( clk        ),
    .rst_ni        ( ndmreset_n ),
    .pwm_setting_i ( 'd8        ),
    .fan_pwm_o     ( fan_pwm    )
);

endmodule
