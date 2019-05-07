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
// Date: 19.03.2017
// Description: Test-harness for Ariane
//              Instantiates an AXI-Bus and memories

module ariane_testharness #(
  parameter int unsigned AXI_USER_WIDTH    = 1,
  parameter int unsigned AXI_ADDRESS_WIDTH = 64,
  parameter int unsigned AXI_DATA_WIDTH    = 64,
  parameter bit          InclSimDTM        = 1'b1,
  parameter int unsigned NUM_WORDS         = 2**25,         // memory size
  parameter bit          StallRandomOutput = 1'b0,
  parameter bit          StallRandomInput  = 1'b0
) (
  input  logic                           clk_i,
  input  logic                           rtc_i,
  input  logic                           rst_ni,
  output logic [31:0]                    exit_o
);

  // disable test-enable
  logic        test_en;
  logic        ndmreset_n;
  logic        debug_req_core;

  int          jtag_enable;
  logic        init_done;
  logic [31:0] jtag_exit, dmi_exit;

  logic        jtag_TCK;
  logic        jtag_TMS;
  logic        jtag_TDI;
  logic        jtag_TRSTn;
  logic        jtag_TDO_data;
  logic        jtag_TDO_driven;

  logic        debug_req_valid;
  logic        debug_req_ready;
  logic        debug_resp_valid;
  logic        debug_resp_ready;

  logic        jtag_req_valid;
  logic [6:0]  jtag_req_bits_addr;
  logic [1:0]  jtag_req_bits_op;
  logic [31:0] jtag_req_bits_data;
  logic        jtag_resp_ready;
  logic        jtag_resp_valid;

  logic        dmi_req_valid;
  logic        dmi_resp_ready;
  logic        dmi_resp_valid;

  dm::dmi_req_t  jtag_dmi_req;
  dm::dmi_req_t  dmi_req;

  dm::dmi_req_t  debug_req;
  dm::dmi_resp_t debug_resp;

  assign test_en = 1'b0;

  AXI_BUS #(
    .AXI_ADDR_WIDTH ( AXI_ADDRESS_WIDTH   ),
    .AXI_DATA_WIDTH ( AXI_DATA_WIDTH      ),
    .AXI_ID_WIDTH   ( ariane_soc::IdWidth ),
    .AXI_USER_WIDTH ( AXI_USER_WIDTH      )
  ) slave[ariane_soc::NrSlaves-1:0]();

  AXI_BUS #(
    .AXI_ADDR_WIDTH ( AXI_ADDRESS_WIDTH        ),
    .AXI_DATA_WIDTH ( AXI_DATA_WIDTH           ),
    .AXI_ID_WIDTH   ( ariane_soc::IdWidthSlave ),
    .AXI_USER_WIDTH ( AXI_USER_WIDTH           )
  ) master[ariane_soc::NB_PERIPHERALS-1:0]();

  // ---------------
  // Debug
  // ---------------
  assign init_done = rst_ni;

  initial begin
    if (!$value$plusargs("jtag_rbb_enable=%b", jtag_enable)) jtag_enable = 'h0;
  end

  // debug if MUX
  assign debug_req_valid     = (jtag_enable[0]) ? jtag_req_valid     : dmi_req_valid;
  assign debug_resp_ready    = (jtag_enable[0]) ? jtag_resp_ready    : dmi_resp_ready;
  assign debug_req           = (jtag_enable[0]) ? jtag_dmi_req       : dmi_req;
  assign exit_o              = (jtag_enable[0]) ? jtag_exit          : dmi_exit;
  assign jtag_resp_valid     = (jtag_enable[0]) ? debug_resp_valid   : 1'b0;
  assign dmi_resp_valid      = (jtag_enable[0]) ? 1'b0               : debug_resp_valid;

  // SiFive's SimJTAG Module
  // Converts to DPI calls
  SimJTAG i_SimJTAG (
    .clock                ( clk_i                ),
    .reset                ( ~rst_ni              ),
    .enable               ( jtag_enable[0]       ),
    .init_done            ( init_done            ),
    .jtag_TCK             ( jtag_TCK             ),
    .jtag_TMS             ( jtag_TMS             ),
    .jtag_TDI             ( jtag_TDI             ),
    .jtag_TRSTn           ( jtag_TRSTn           ),
    .jtag_TDO_data        ( jtag_TDO_data        ),
    .jtag_TDO_driven      ( jtag_TDO_driven      ),
    .exit                 ( jtag_exit            )
  );

  // SiFive's SimDTM Module
  // Converts to DPI calls
  logic [1:0] debug_req_bits_op;
  assign dmi_req.op = dm::dtm_op_e'(debug_req_bits_op);

  if (InclSimDTM) begin
    SimDTM i_SimDTM (
      .clk                  ( clk_i                 ),
      .reset                ( ~rst_ni               ),
      .debug_req_valid      ( dmi_req_valid         ),
      .debug_req_ready      ( debug_req_ready       ),
      .debug_req_bits_addr  ( dmi_req.addr          ),
      .debug_req_bits_op    ( debug_req_bits_op     ),
      .debug_req_bits_data  ( dmi_req.data          ),
      .debug_resp_valid     ( dmi_resp_valid        ),
      .debug_resp_ready     ( dmi_resp_ready        ),
      .debug_resp_bits_resp ( debug_resp.resp       ),
      .debug_resp_bits_data ( debug_resp.data       ),
      .exit                 ( dmi_exit              )
    );
  end else begin
    assign dmi_req_valid = '0;
    assign debug_req_bits_op = '0;
    assign dmi_exit = 1'b0;
  end

  // this delay window allows the core to read and execute init code
  // from the bootrom before the first debug request can interrupt
  // core. this is needed in cases where an fsbl is involved that
  // expects a0 and a1 to be initialized with the hart id and a
  // pointer to the dev tree, respectively.
  localparam int unsigned DmiDelCycles = 500;

  logic debug_req_core_ungtd;
  int dmi_del_cnt_d, dmi_del_cnt_q;

  assign dmi_del_cnt_d  = (dmi_del_cnt_q) ? dmi_del_cnt_q - 1 : 0;
  assign debug_req_core = (dmi_del_cnt_q) ? 1'b0 : debug_req_core_ungtd;

  always_ff @(posedge clk_i or negedge rst_ni) begin : p_dmi_del_cnt
    if(!rst_ni) begin
      dmi_del_cnt_q <= DmiDelCycles;
    end else begin
      dmi_del_cnt_q <= dmi_del_cnt_d;
    end
  end

  AXI_BUS #(
    .AXI_ADDR_WIDTH ( AXI_ADDRESS_WIDTH        ),
    .AXI_DATA_WIDTH ( AXI_DATA_WIDTH           ),
    .AXI_ID_WIDTH   ( ariane_soc::IdWidthSlave ),
    .AXI_USER_WIDTH ( AXI_USER_WIDTH           )
  ) dram(), iobus(), dram_delayed();

  logic                         req;
  logic                         we;
  logic [AXI_ADDRESS_WIDTH-1:0] addr;
  logic [AXI_DATA_WIDTH/8-1:0]  be;
  logic [AXI_DATA_WIDTH-1:0]    wdata;
  logic [AXI_DATA_WIDTH-1:0]    rdata;

  ariane_axi::aw_chan_slv_t aw_chan_i;
  ariane_axi::w_chan_t      w_chan_i;
  ariane_axi::b_chan_slv_t  b_chan_o;
  ariane_axi::ar_chan_slv_t ar_chan_i;
  ariane_axi::r_chan_slv_t  r_chan_o;
  ariane_axi::aw_chan_slv_t aw_chan_o;
  ariane_axi::w_chan_t      w_chan_o;
  ariane_axi::b_chan_slv_t  b_chan_i;
  ariane_axi::ar_chan_slv_t ar_chan_o;
  ariane_axi::r_chan_slv_t  r_chan_i;

  axi_delayer #(
    .aw_t              ( ariane_axi::aw_chan_slv_t ),
    .w_t               ( ariane_axi::w_chan_t      ),
    .b_t               ( ariane_axi::b_chan_slv_t  ),
    .ar_t              ( ariane_axi::ar_chan_slv_t ),
    .r_t               ( ariane_axi::r_chan_slv_t  ),
    .StallRandomOutput ( StallRandomOutput         ),
    .StallRandomInput  ( StallRandomInput          ),
    .FixedDelayInput   ( 0                         ),
    .FixedDelayOutput  ( 0                         )
  ) i_axi_delayer (
    .clk_i      ( clk_i                 ),
    .rst_ni     ( ndmreset_n            ),
    .aw_valid_i ( dram.aw_valid         ),
    .aw_chan_i  ( aw_chan_i             ),
    .aw_ready_o ( dram.aw_ready         ),
    .w_valid_i  ( dram.w_valid          ),
    .w_chan_i   ( w_chan_i              ),
    .w_ready_o  ( dram.w_ready          ),
    .b_valid_o  ( dram.b_valid          ),
    .b_chan_o   ( b_chan_o              ),
    .b_ready_i  ( dram.b_ready          ),
    .ar_valid_i ( dram.ar_valid         ),
    .ar_chan_i  ( ar_chan_i             ),
    .ar_ready_o ( dram.ar_ready         ),
    .r_valid_o  ( dram.r_valid          ),
    .r_chan_o   ( r_chan_o              ),
    .r_ready_i  ( dram.r_ready          ),
    .aw_valid_o ( dram_delayed.aw_valid ),
    .aw_chan_o  ( aw_chan_o             ),
    .aw_ready_i ( dram_delayed.aw_ready ),
    .w_valid_o  ( dram_delayed.w_valid  ),
    .w_chan_o   ( w_chan_o              ),
    .w_ready_i  ( dram_delayed.w_ready  ),
    .b_valid_i  ( dram_delayed.b_valid  ),
    .b_chan_i   ( b_chan_i              ),
    .b_ready_o  ( dram_delayed.b_ready  ),
    .ar_valid_o ( dram_delayed.ar_valid ),
    .ar_chan_o  ( ar_chan_o             ),
    .ar_ready_i ( dram_delayed.ar_ready ),
    .r_valid_i  ( dram_delayed.r_valid  ),
    .r_chan_i   ( r_chan_i              ),
    .r_ready_o  ( dram_delayed.r_ready  )
  );

  assign aw_chan_i.atop = dram.aw_atop;
  assign aw_chan_i.id = dram.aw_id;
  assign aw_chan_i.addr = dram.aw_addr;
  assign aw_chan_i.len = dram.aw_len;
  assign aw_chan_i.size = dram.aw_size;
  assign aw_chan_i.burst = dram.aw_burst;
  assign aw_chan_i.lock = dram.aw_lock;
  assign aw_chan_i.cache = dram.aw_cache;
  assign aw_chan_i.prot = dram.aw_prot;
  assign aw_chan_i.qos = dram.aw_qos;
  assign aw_chan_i.region = dram.aw_region;

  assign ar_chan_i.id = dram.ar_id;
  assign ar_chan_i.addr = dram.ar_addr;
  assign ar_chan_i.len = dram.ar_len;
  assign ar_chan_i.size = dram.ar_size;
  assign ar_chan_i.burst = dram.ar_burst;
  assign ar_chan_i.lock = dram.ar_lock;
  assign ar_chan_i.cache = dram.ar_cache;
  assign ar_chan_i.prot = dram.ar_prot;
  assign ar_chan_i.qos = dram.ar_qos;
  assign ar_chan_i.region = dram.ar_region;

  assign w_chan_i.data = dram.w_data;
  assign w_chan_i.strb = dram.w_strb;
  assign w_chan_i.last = dram.w_last;

  assign dram.r_id = r_chan_o.id;
  assign dram.r_data = r_chan_o.data;
  assign dram.r_resp = r_chan_o.resp;
  assign dram.r_last = r_chan_o.last;

  assign dram.b_id = b_chan_o.id;
  assign dram.b_resp = b_chan_o.resp;

  assign dram_delayed.aw_id = aw_chan_o.id;
  assign dram_delayed.aw_addr = aw_chan_o.addr;
  assign dram_delayed.aw_len = aw_chan_o.len;
  assign dram_delayed.aw_size = aw_chan_o.size;
  assign dram_delayed.aw_burst = aw_chan_o.burst;
  assign dram_delayed.aw_lock = aw_chan_o.lock;
  assign dram_delayed.aw_cache = aw_chan_o.cache;
  assign dram_delayed.aw_prot = aw_chan_o.prot;
  assign dram_delayed.aw_qos = aw_chan_o.qos;
  assign dram_delayed.aw_atop = aw_chan_o.atop;
  assign dram_delayed.aw_region = aw_chan_o.region;
  assign dram_delayed.aw_user = '0;

  assign dram_delayed.ar_id = ar_chan_o.id;
  assign dram_delayed.ar_addr = ar_chan_o.addr;
  assign dram_delayed.ar_len = ar_chan_o.len;
  assign dram_delayed.ar_size = ar_chan_o.size;
  assign dram_delayed.ar_burst = ar_chan_o.burst;
  assign dram_delayed.ar_lock = ar_chan_o.lock;
  assign dram_delayed.ar_cache = ar_chan_o.cache;
  assign dram_delayed.ar_prot = ar_chan_o.prot;
  assign dram_delayed.ar_qos = ar_chan_o.qos;
  assign dram_delayed.ar_region = ar_chan_o.region;
  assign dram_delayed.ar_user = '0;

  assign dram_delayed.w_data = w_chan_o.data;
  assign dram_delayed.w_strb = w_chan_o.strb;
  assign dram_delayed.w_last = w_chan_o.last;
  assign dram_delayed.w_user = '0;

  assign r_chan_i.id = dram_delayed.r_id;
  assign r_chan_i.data = dram_delayed.r_data;
  assign r_chan_i.resp = dram_delayed.r_resp;
  assign r_chan_i.last = dram_delayed.r_last;
  assign dram.r_user = '0;

  assign b_chan_i.id = dram_delayed.b_id;
  assign b_chan_i.resp = dram_delayed.b_resp;
  assign dram.b_user = '0;

  axi2mem #(
    .AXI_ID_WIDTH   ( ariane_soc::IdWidthSlave ),
    .AXI_ADDR_WIDTH ( AXI_ADDRESS_WIDTH        ),
    .AXI_DATA_WIDTH ( AXI_DATA_WIDTH           ),
    .AXI_USER_WIDTH ( AXI_USER_WIDTH           )
  ) i_axi2mem (
    .clk_i  ( clk_i        ),
    .rst_ni ( ndmreset_n   ),
    .slave  ( dram_delayed ),
    .req_o  ( req          ),
    .we_o   ( we           ),
    .addr_o ( addr         ),
    .be_o   ( be           ),
    .data_o ( wdata        ),
    .data_i ( rdata        )
  );

  sram #(
    .DATA_WIDTH ( AXI_DATA_WIDTH ),
    .NUM_WORDS  ( NUM_WORDS      )
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

  // ---------------
  // Peripherals
  // ---------------
  logic tx, rx;
  logic [1:0] irqs;
  logic [ariane_soc::NumSources-1:0] irq_sources;
   
  ariane_peripherals #(
    .AxiAddrWidth ( AXI_ADDRESS_WIDTH        ),
    .AxiDataWidth ( AXI_DATA_WIDTH           ),
    .AxiIdWidth   ( ariane_soc::IdWidthSlave ),
`ifndef VERILATOR
  // disable UART when using Spike, as we need to rely on the mockuart
  `ifdef SPIKE_TANDEM
    .InclUART     ( 1'b0                     ),
  `else
    .InclUART     ( 1'b1                     ),
  `endif
`else
    .InclUART     ( 1'b0                     ),
`endif
    .InclSPI      ( 1'b0                     ),
    .InclEthernet ( 1'b0                     )
  ) i_ariane_peripherals (
    .clk_i     ( clk_i                        ),
    .rst_ni    ( ndmreset_n                   ),
    .iobus     ( iobus                        ),
    .irq_sources,
    .rx_i      ( rx                           ),
    .tx_o      ( tx                           ),
    .eth_txck  ( ),
    .eth_rxck  ( ),
    .eth_rxctl ( ),
    .eth_rxd   ( ),
    .eth_rst_n ( ),
    .eth_tx_en ( ),
    .eth_txd   ( ),
    .phy_mdio  ( ),
    .eth_mdc   ( ),
    .mdio      ( ),
    .mdc       ( ),
    .spi_clk_o ( ),
    .spi_mosi  ( ),
    .spi_miso  ( ),
    .spi_ss    ( )
  );

  uart_bus #(.BAUD_RATE(115200), .PARITY_EN(0)) i_uart_bus (.rx(tx), .tx(rx), .rx_en(1'b1));

  // ---------------
  // Shell
  // ---------------

`ifdef ARIANE_SHELL   
  ariane_shell i_shell
`else
  rocket_shell i_shell
`endif
    (
    .clk             ( clk_i                ),
    .rst_n           ( rst_ni               ),
    .irq_sources,
    .dram,
    .iobus,
    .test_en,
    .ndmreset_n,
    .tck             ( jtag_TCK             ),
    .tms             ( jtag_TMS             ),
    .tdi             ( jtag_TDI             ),
    .trst_n          ( jtag_TRSTn           ),
    .tdo_data        ( jtag_TDO_data        ),
    .tdo_oe          ( jtag_TDO_driven      )
  );

`ifdef AXI_SVA
  // AXI 4 Assertion IP integration - You will need to get your own copy of this IP if you want
  // to use it
  Axi4PC #(
    .DATA_WIDTH(ariane_axi::DataWidth),
    .WID_WIDTH(ariane_soc::IdWidthSlave),
    .RID_WIDTH(ariane_soc::IdWidthSlave),
    .AWUSER_WIDTH(ariane_axi::UserWidth),
    .WUSER_WIDTH(ariane_axi::UserWidth),
    .BUSER_WIDTH(ariane_axi::UserWidth),
    .ARUSER_WIDTH(ariane_axi::UserWidth),
    .RUSER_WIDTH(ariane_axi::UserWidth),
    .ADDR_WIDTH(ariane_axi::AddrWidth)
  ) i_Axi4PC (
    .ACLK(clk_i),
    .ARESETn(ndmreset_n),
    .AWID(dram.aw_id),
    .AWADDR(dram.aw_addr),
    .AWLEN(dram.aw_len),
    .AWSIZE(dram.aw_size),
    .AWBURST(dram.aw_burst),
    .AWLOCK(dram.aw_lock),
    .AWCACHE(dram.aw_cache),
    .AWPROT(dram.aw_prot),
    .AWQOS(dram.aw_qos),
    .AWREGION(dram.aw_region),
    .AWUSER(dram.aw_user),
    .AWVALID(dram.aw_valid),
    .AWREADY(dram.aw_ready),
    .WLAST(dram.w_last),
    .WDATA(dram.w_data),
    .WSTRB(dram.w_strb),
    .WUSER(dram.w_user),
    .WVALID(dram.w_valid),
    .WREADY(dram.w_ready),
    .BID(dram.b_id),
    .BRESP(dram.b_resp),
    .BUSER(dram.b_user),
    .BVALID(dram.b_valid),
    .BREADY(dram.b_ready),
    .ARID(dram.ar_id),
    .ARADDR(dram.ar_addr),
    .ARLEN(dram.ar_len),
    .ARSIZE(dram.ar_size),
    .ARBURST(dram.ar_burst),
    .ARLOCK(dram.ar_lock),
    .ARCACHE(dram.ar_cache),
    .ARPROT(dram.ar_prot),
    .ARQOS(dram.ar_qos),
    .ARREGION(dram.ar_region),
    .ARUSER(dram.ar_user),
    .ARVALID(dram.ar_valid),
    .ARREADY(dram.ar_ready),
    .RID(dram.r_id),
    .RLAST(dram.r_last),
    .RDATA(dram.r_data),
    .RRESP(dram.r_resp),
    .RUSER(dram.r_user),
    .RVALID(dram.r_valid),
    .RREADY(dram.r_ready),
    .CACTIVE('0),
    .CSYSREQ('0),
    .CSYSACK('0)
  );
`endif
endmodule
