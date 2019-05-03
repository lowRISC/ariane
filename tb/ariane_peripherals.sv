// Copyright 2018 ETH Zurich and University of Bologna.
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the "License"); you may not use this file except in
// compliance with the License.  You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.

// Xilinx Peripehrals
module ariane_peripherals #(
    parameter int AxiAddrWidth = -1,
    parameter int AxiDataWidth = -1,
    parameter int AxiIdWidth   = -1,
    parameter int AxiUserWidth = 1,
    parameter bit InclUART     = 1,
    parameter bit InclSPI      = 0,
    parameter bit InclEthernet = 0,
    parameter bit InclGPIO     = 0
) (
    input  logic       clk_i           , // Clock
    input  logic       rst_ni          , // Asynchronous reset active low
    AXI_BUS.Slave      iobus           ,
    output logic [ariane_soc::NumSources-1:0] irq_sources,
    // UART
    input  logic       rx_i            ,
    output logic       tx_o            ,
    // Ethernet
    input  wire        eth_txck        ,
    input  wire        eth_rxck        ,
    input  wire        eth_rxctl       ,
    input  wire [3:0]  eth_rxd         ,
    output wire        eth_rst_n       ,
    output wire        eth_tx_en       ,
    output wire [3:0]  eth_txd         ,
    inout  wire        phy_mdio        ,
    output logic       eth_mdc         ,
    // MDIO Interface
    inout              mdio            ,
    output             mdc             ,
    // SPI
    output logic       spi_clk_o       ,
    output logic       spi_mosi        ,
    input  logic       spi_miso        ,
    output logic       spi_ss
);
AXI_BUS #(
    .AXI_ADDR_WIDTH ( AxiAddrWidth     ),
    .AXI_DATA_WIDTH ( AxiDataWidth     ),
    .AXI_ID_WIDTH   ( AxiIdWidth       ),
    .AXI_USER_WIDTH ( AxiUserWidth     )
) master[3:0]();

logic [3:0][AxiAddrWidth-1:0] BASE;
logic [3:0][AxiAddrWidth-1:0] MASK;

assign BASE = {
        ariane_soc::UARTBase,
        ariane_soc::SPIBase,
        ariane_soc::EthernetBase,
        ariane_soc::GPIOBase
      };
      
assign MASK = {
              ariane_soc::UARTBase     + ariane_soc::UARTLength - 1,
              ariane_soc::SPIBase      + ariane_soc::SPILength - 1,
              ariane_soc::EthernetBase + ariane_soc::EthernetLength -1,
              ariane_soc::GPIOBase     + ariane_soc::GPIOLength - 1
            };

axi_demux_raw #(
    .SLAVE_NUM  ( 4                ),
    .ADDR_WIDTH ( AxiAddrWidth     ),
    .ID_WIDTH   ( AxiIdWidth       )
) demux (.clk(clk_i), .rstn(rst_ni), .master(iobus), .slave(master), .BASE, .MASK);

    // ---------------
    // 2. UART
    // ---------------
    logic         uart_penable;
    logic         uart_pwrite;
    logic [31:0]  uart_paddr;
    logic         uart_psel;
    logic [31:0]  uart_pwdata;
    logic [31:0]  uart_prdata;
    logic         uart_pready;
    logic         uart_pslverr;

    axi2apb_64_32 #(
        .AXI4_ADDRESS_WIDTH ( AxiAddrWidth ),
        .AXI4_RDATA_WIDTH   ( AxiDataWidth ),
        .AXI4_WDATA_WIDTH   ( AxiDataWidth ),
        .AXI4_ID_WIDTH      ( AxiIdWidth   ),
        .AXI4_USER_WIDTH    ( AxiUserWidth ),
        .BUFF_DEPTH_SLAVE   ( 2            ),
        .APB_ADDR_WIDTH     ( 32           )
    ) i_axi2apb_64_32_uart (
        .ACLK      ( clk_i          ),
        .ARESETn   ( rst_ni         ),
        .test_en_i ( 1'b0           ),
        .AWID_i    ( master[ariane_soc::UART].aw_id     ),
        .AWADDR_i  ( master[ariane_soc::UART].aw_addr   ),
        .AWLEN_i   ( master[ariane_soc::UART].aw_len    ),
        .AWSIZE_i  ( master[ariane_soc::UART].aw_size   ),
        .AWBURST_i ( master[ariane_soc::UART].aw_burst  ),
        .AWLOCK_i  ( master[ariane_soc::UART].aw_lock   ),
        .AWCACHE_i ( master[ariane_soc::UART].aw_cache  ),
        .AWPROT_i  ( master[ariane_soc::UART].aw_prot   ),
        .AWREGION_i( master[ariane_soc::UART].aw_region ),
        .AWUSER_i  ( master[ariane_soc::UART].aw_user   ),
        .AWQOS_i   ( master[ariane_soc::UART].aw_qos    ),
        .AWVALID_i ( master[ariane_soc::UART].aw_valid  ),
        .AWREADY_o ( master[ariane_soc::UART].aw_ready  ),
        .WDATA_i   ( master[ariane_soc::UART].w_data    ),
        .WSTRB_i   ( master[ariane_soc::UART].w_strb    ),
        .WLAST_i   ( master[ariane_soc::UART].w_last    ),
        .WUSER_i   ( master[ariane_soc::UART].w_user    ),
        .WVALID_i  ( master[ariane_soc::UART].w_valid   ),
        .WREADY_o  ( master[ariane_soc::UART].w_ready   ),
        .BID_o     ( master[ariane_soc::UART].b_id      ),
        .BRESP_o   ( master[ariane_soc::UART].b_resp    ),
        .BVALID_o  ( master[ariane_soc::UART].b_valid   ),
        .BUSER_o   ( master[ariane_soc::UART].b_user    ),
        .BREADY_i  ( master[ariane_soc::UART].b_ready   ),
        .ARID_i    ( master[ariane_soc::UART].ar_id     ),
        .ARADDR_i  ( master[ariane_soc::UART].ar_addr   ),
        .ARLEN_i   ( master[ariane_soc::UART].ar_len    ),
        .ARSIZE_i  ( master[ariane_soc::UART].ar_size   ),
        .ARBURST_i ( master[ariane_soc::UART].ar_burst  ),
        .ARLOCK_i  ( master[ariane_soc::UART].ar_lock   ),
        .ARCACHE_i ( master[ariane_soc::UART].ar_cache  ),
        .ARPROT_i  ( master[ariane_soc::UART].ar_prot   ),
        .ARREGION_i( master[ariane_soc::UART].ar_region ),
        .ARUSER_i  ( master[ariane_soc::UART].ar_user   ),
        .ARQOS_i   ( master[ariane_soc::UART].ar_qos    ),
        .ARVALID_i ( master[ariane_soc::UART].ar_valid  ),
        .ARREADY_o ( master[ariane_soc::UART].ar_ready  ),
        .RID_o     ( master[ariane_soc::UART].r_id      ),
        .RDATA_o   ( master[ariane_soc::UART].r_data    ),
        .RRESP_o   ( master[ariane_soc::UART].r_resp    ),
        .RLAST_o   ( master[ariane_soc::UART].r_last    ),
        .RUSER_o   ( master[ariane_soc::UART].r_user    ),
        .RVALID_o  ( master[ariane_soc::UART].r_valid   ),
        .RREADY_i  ( master[ariane_soc::UART].r_ready   ),
        .PENABLE   ( uart_penable   ),
        .PWRITE    ( uart_pwrite    ),
        .PADDR     ( uart_paddr     ),
        .PSEL      ( uart_psel      ),
        .PWDATA    ( uart_pwdata    ),
        .PRDATA    ( uart_prdata    ),
        .PREADY    ( uart_pready    ),
        .PSLVERR   ( uart_pslverr   )
    );

    if (InclUART) begin : gen_uart
        apb_uart i_apb_uart (
            .CLK     ( clk_i           ),
            .RSTN    ( rst_ni          ),
            .PSEL    ( uart_psel       ),
            .PENABLE ( uart_penable    ),
            .PWRITE  ( uart_pwrite     ),
            .PADDR   ( uart_paddr[4:2] ),
            .PWDATA  ( uart_pwdata     ),
            .PRDATA  ( uart_prdata     ),
            .PREADY  ( uart_pready     ),
            .PSLVERR ( uart_pslverr    ),
            .INT     ( irq_sources[0]  ),
            .OUT1N   (                 ), // keep open
            .OUT2N   (                 ), // keep open
            .RTSN    (                 ), // no flow control
            .DTRN    (                 ), // no flow control
            .CTSN    ( 1'b0            ),
            .DSRN    ( 1'b0            ),
            .DCDN    ( 1'b0            ),
            .RIN     ( 1'b0            ),
            .SIN     ( rx_i            ),
            .SOUT    ( tx_o            )
        );
    end else begin
        assign irq_sources[0] = 1'b0;
        /* pragma translate_off */
        `ifndef VERILATOR
        mock_uart i_mock_uart (
            .clk_i     ( clk_i        ),
            .rst_ni    ( rst_ni       ),
            .penable_i ( uart_penable ),
            .pwrite_i  ( uart_pwrite  ),
            .paddr_i   ( uart_paddr   ),
            .psel_i    ( uart_psel    ),
            .pwdata_i  ( uart_pwdata  ),
            .prdata_o  ( uart_prdata  ),
            .pready_o  ( uart_pready  ),
            .pslverr_o ( uart_pslverr )
        );
        `endif
        /* pragma translate_on */
    end

    // ---------------
    // 3. SPI
    // ---------------
    if (InclSPI) begin : gen_spi
        logic [31:0] s_axi_spi_awaddr;
        logic [7:0]  s_axi_spi_awlen;
        logic [2:0]  s_axi_spi_awsize;
        logic [1:0]  s_axi_spi_awburst;
        logic [0:0]  s_axi_spi_awlock;
        logic [3:0]  s_axi_spi_awcache;
        logic [2:0]  s_axi_spi_awprot;
        logic [3:0]  s_axi_spi_awregion;
        logic [3:0]  s_axi_spi_awqos;
        logic        s_axi_spi_awvalid;
        logic        s_axi_spi_awready;
        logic [31:0] s_axi_spi_wdata;
        logic [3:0]  s_axi_spi_wstrb;
        logic        s_axi_spi_wlast;
        logic        s_axi_spi_wvalid;
        logic        s_axi_spi_wready;
        logic [1:0]  s_axi_spi_bresp;
        logic        s_axi_spi_bvalid;
        logic        s_axi_spi_bready;
        logic [31:0] s_axi_spi_araddr;
        logic [7:0]  s_axi_spi_arlen;
        logic [2:0]  s_axi_spi_arsize;
        logic [1:0]  s_axi_spi_arburst;
        logic [0:0]  s_axi_spi_arlock;
        logic [3:0]  s_axi_spi_arcache;
        logic [2:0]  s_axi_spi_arprot;
        logic [3:0]  s_axi_spi_arregion;
        logic [3:0]  s_axi_spi_arqos;
        logic        s_axi_spi_arvalid;
        logic        s_axi_spi_arready;
        logic [31:0] s_axi_spi_rdata;
        logic [1:0]  s_axi_spi_rresp;
        logic        s_axi_spi_rlast;
        logic        s_axi_spi_rvalid;
        logic        s_axi_spi_rready;

        xlnx_axi_clock_converter i_xlnx_axi_clock_converter_spi (
            .s_axi_aclk     ( clk_i              ),
            .s_axi_aresetn  ( rst_ni             ),

            .s_axi_awid     ( master[ariane_soc::SPI].aw_id          ),
            .s_axi_awaddr   ( master[ariane_soc::SPI].aw_addr[31:0]  ),
            .s_axi_awlen    ( master[ariane_soc::SPI].aw_len         ),
            .s_axi_awsize   ( master[ariane_soc::SPI].aw_size        ),
            .s_axi_awburst  ( master[ariane_soc::SPI].aw_burst       ),
            .s_axi_awlock   ( master[ariane_soc::SPI].aw_lock        ),
            .s_axi_awcache  ( master[ariane_soc::SPI].aw_cache       ),
            .s_axi_awprot   ( master[ariane_soc::SPI].aw_prot        ),
            .s_axi_awregion ( master[ariane_soc::SPI].aw_region      ),
            .s_axi_awqos    ( master[ariane_soc::SPI].aw_qos         ),
            .s_axi_awvalid  ( master[ariane_soc::SPI].aw_valid       ),
            .s_axi_awready  ( master[ariane_soc::SPI].aw_ready       ),
            .s_axi_wdata    ( master[ariane_soc::SPI].w_data         ),
            .s_axi_wstrb    ( master[ariane_soc::SPI].w_strb         ),
            .s_axi_wlast    ( master[ariane_soc::SPI].w_last         ),
            .s_axi_wvalid   ( master[ariane_soc::SPI].w_valid        ),
            .s_axi_wready   ( master[ariane_soc::SPI].w_ready        ),
            .s_axi_bid      ( master[ariane_soc::SPI].b_id           ),
            .s_axi_bresp    ( master[ariane_soc::SPI].b_resp         ),
            .s_axi_bvalid   ( master[ariane_soc::SPI].b_valid        ),
            .s_axi_bready   ( master[ariane_soc::SPI].b_ready        ),
            .s_axi_arid     ( master[ariane_soc::SPI].ar_id          ),
            .s_axi_araddr   ( master[ariane_soc::SPI].ar_addr[31:0]  ),
            .s_axi_arlen    ( master[ariane_soc::SPI].ar_len         ),
            .s_axi_arsize   ( master[ariane_soc::SPI].ar_size        ),
            .s_axi_arburst  ( master[ariane_soc::SPI].ar_burst       ),
            .s_axi_arlock   ( master[ariane_soc::SPI].ar_lock        ),
            .s_axi_arcache  ( master[ariane_soc::SPI].ar_cache       ),
            .s_axi_arprot   ( master[ariane_soc::SPI].ar_prot        ),
            .s_axi_arregion ( master[ariane_soc::SPI].ar_region      ),
            .s_axi_arqos    ( master[ariane_soc::SPI].ar_qos         ),
            .s_axi_arvalid  ( master[ariane_soc::SPI].ar_valid       ),
            .s_axi_arready  ( master[ariane_soc::SPI].ar_ready       ),
            .s_axi_rid      ( master[ariane_soc::SPI].r_id           ),
            .s_axi_rdata    ( master[ariane_soc::SPI].r_data         ),
            .s_axi_rresp    ( master[ariane_soc::SPI].r_resp         ),
            .s_axi_rlast    ( master[ariane_soc::SPI].r_last         ),
            .s_axi_rvalid   ( master[ariane_soc::SPI].r_valid        ),
            .s_axi_rready   ( master[ariane_soc::SPI].r_ready        ),

            .m_axi_awaddr   ( s_axi_spi_awaddr   ),
            .m_axi_awlen    ( s_axi_spi_awlen    ),
            .m_axi_awsize   ( s_axi_spi_awsize   ),
            .m_axi_awburst  ( s_axi_spi_awburst  ),
            .m_axi_awlock   ( s_axi_spi_awlock   ),
            .m_axi_awcache  ( s_axi_spi_awcache  ),
            .m_axi_awprot   ( s_axi_spi_awprot   ),
            .m_axi_awregion ( s_axi_spi_awregion ),
            .m_axi_awqos    ( s_axi_spi_awqos    ),
            .m_axi_awvalid  ( s_axi_spi_awvalid  ),
            .m_axi_awready  ( s_axi_spi_awready  ),
            .m_axi_wdata    ( s_axi_spi_wdata    ),
            .m_axi_wstrb    ( s_axi_spi_wstrb    ),
            .m_axi_wlast    ( s_axi_spi_wlast    ),
            .m_axi_wvalid   ( s_axi_spi_wvalid   ),
            .m_axi_wready   ( s_axi_spi_wready   ),
            .m_axi_bresp    ( s_axi_spi_bresp    ),
            .m_axi_bvalid   ( s_axi_spi_bvalid   ),
            .m_axi_bready   ( s_axi_spi_bready   ),
            .m_axi_araddr   ( s_axi_spi_araddr   ),
            .m_axi_arlen    ( s_axi_spi_arlen    ),
            .m_axi_arsize   ( s_axi_spi_arsize   ),
            .m_axi_arburst  ( s_axi_spi_arburst  ),
            .m_axi_arlock   ( s_axi_spi_arlock   ),
            .m_axi_arcache  ( s_axi_spi_arcache  ),
            .m_axi_arprot   ( s_axi_spi_arprot   ),
            .m_axi_arregion ( s_axi_spi_arregion ),
            .m_axi_arqos    ( s_axi_spi_arqos    ),
            .m_axi_arvalid  ( s_axi_spi_arvalid  ),
            .m_axi_arready  ( s_axi_spi_arready  ),
            .m_axi_rdata    ( s_axi_spi_rdata    ),
            .m_axi_rresp    ( s_axi_spi_rresp    ),
            .m_axi_rlast    ( s_axi_spi_rlast    ),
            .m_axi_rvalid   ( s_axi_spi_rvalid   ),
            .m_axi_rready   ( s_axi_spi_rready   )
        );

        xlnx_axi_quad_spi i_xlnx_axi_quad_spi (
            .ext_spi_clk    ( clk_i                  ),
            .s_axi4_aclk    ( clk_i                  ),
            .s_axi4_aresetn ( rst_ni                 ),
            .s_axi4_awaddr  ( s_axi_spi_awaddr[23:0] ),
            .s_axi4_awlen   ( s_axi_spi_awlen        ),
            .s_axi4_awsize  ( s_axi_spi_awsize       ),
            .s_axi4_awburst ( s_axi_spi_awburst      ),
            .s_axi4_awlock  ( s_axi_spi_awlock       ),
            .s_axi4_awcache ( s_axi_spi_awcache      ),
            .s_axi4_awprot  ( s_axi_spi_awprot       ),
            .s_axi4_awvalid ( s_axi_spi_awvalid      ),
            .s_axi4_awready ( s_axi_spi_awready      ),
            .s_axi4_wdata   ( s_axi_spi_wdata        ),
            .s_axi4_wstrb   ( s_axi_spi_wstrb        ),
            .s_axi4_wlast   ( s_axi_spi_wlast        ),
            .s_axi4_wvalid  ( s_axi_spi_wvalid       ),
            .s_axi4_wready  ( s_axi_spi_wready       ),
            .s_axi4_bresp   ( s_axi_spi_bresp        ),
            .s_axi4_bvalid  ( s_axi_spi_bvalid       ),
            .s_axi4_bready  ( s_axi_spi_bready       ),
            .s_axi4_araddr  ( s_axi_spi_araddr[23:0] ),
            .s_axi4_arlen   ( s_axi_spi_arlen        ),
            .s_axi4_arsize  ( s_axi_spi_arsize       ),
            .s_axi4_arburst ( s_axi_spi_arburst      ),
            .s_axi4_arlock  ( s_axi_spi_arlock       ),
            .s_axi4_arcache ( s_axi_spi_arcache      ),
            .s_axi4_arprot  ( s_axi_spi_arprot       ),
            .s_axi4_arvalid ( s_axi_spi_arvalid      ),
            .s_axi4_arready ( s_axi_spi_arready      ),
            .s_axi4_rdata   ( s_axi_spi_rdata        ),
            .s_axi4_rresp   ( s_axi_spi_rresp        ),
            .s_axi4_rlast   ( s_axi_spi_rlast        ),
            .s_axi4_rvalid  ( s_axi_spi_rvalid       ),
            .s_axi4_rready  ( s_axi_spi_rready       ),

            .io0_i          ( '0                     ),
            .io0_o          ( spi_mosi               ),
            .io0_t          ( '0                     ),
            .io1_i          ( spi_miso               ),
            .io1_o          (                        ),
            .io1_t          ( '0                     ),
            .ss_i           ( '0                     ),
            .ss_o           ( spi_ss                 ),
            .ss_t           ( '0                     ),
            .sck_o          ( spi_clk_o              ),
            .sck_i          ( '0                     ),
            .sck_t          (                        ),
            .ip2intc_irpt   ( irq_sources[1]         )
            // .ip2intc_irpt   ( irq_sources[1]         )
        );
        // assign irq_sources [1] = 1'b0;
    end else begin
        assign spi_clk_o = 1'b0;
        assign spi_mosi = 1'b0;
        assign spi_ss = 1'b0;

        assign irq_sources [1] = 1'b0;
        assign master[ariane_soc::SPI].aw_ready = 1'b1;
        assign master[ariane_soc::SPI].ar_ready = 1'b1;
        assign master[ariane_soc::SPI].w_ready = 1'b1;

        assign master[ariane_soc::SPI].b_valid = master[ariane_soc::SPI].aw_valid;
        assign master[ariane_soc::SPI].b_id = master[ariane_soc::SPI].aw_id;
        assign master[ariane_soc::SPI].b_resp = axi_pkg::RESP_SLVERR;
        assign master[ariane_soc::SPI].b_user = '0;

        assign master[ariane_soc::SPI].r_valid = master[ariane_soc::SPI].ar_valid;
        assign master[ariane_soc::SPI].r_resp = axi_pkg::RESP_SLVERR;
        assign master[ariane_soc::SPI].r_data = 'hdeadbeef;
        assign master[ariane_soc::SPI].r_last = 1'b1;
    end


    // ---------------
    // 4. Ethernet
    // ---------------
    if (0)
      begin
      end
    else
      begin
        assign irq_sources [2] = 1'b0;
        assign master[ariane_soc::Ethernet].aw_ready = 1'b1;
        assign master[ariane_soc::Ethernet].ar_ready = 1'b1;
        assign master[ariane_soc::Ethernet].w_ready = 1'b1;

        assign master[ariane_soc::Ethernet].b_valid = master[ariane_soc::Ethernet].aw_valid;
        assign master[ariane_soc::Ethernet].b_id = master[ariane_soc::Ethernet].aw_id;
        assign master[ariane_soc::Ethernet].b_resp = axi_pkg::RESP_SLVERR;
        assign master[ariane_soc::Ethernet].b_user = '0;

        assign master[ariane_soc::Ethernet].r_valid = master[ariane_soc::Ethernet].ar_valid;
        assign master[ariane_soc::Ethernet].r_resp = axi_pkg::RESP_SLVERR;
        assign master[ariane_soc::Ethernet].r_data = 'hdeadbeef;
        assign master[ariane_soc::Ethernet].r_last = 1'b1;
    end
endmodule
