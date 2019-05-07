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
) master[4:0]();

logic [4:0][AxiAddrWidth-1:0] BASE;
logic [4:0][AxiAddrWidth-1:0] MASK;

assign BASE = {
        ariane_soc::BOOTBase,
        ariane_soc::UARTBase,
        ariane_soc::SPIBase,
        ariane_soc::EthernetBase,
        ariane_soc::GPIOBase
      };
      
assign MASK = {
              ariane_soc::BOOTLength - 1,
              ariane_soc::UARTLength - 1,
              ariane_soc::SPILength - 1,
              ariane_soc::EthernetLength -1,
              ariane_soc::GPIOLength - 1
            };

axi_demux_raw #(
    .SLAVE_NUM  ( 5                ),
    .ADDR_WIDTH ( AxiAddrWidth     ),
    .ID_WIDTH   ( AxiIdWidth       )
) demux (.clk(clk_i), .rstn(rst_ni), .master(iobus), .slave(master), .BASE, .MASK);

// ---------------
// BOOTRAM
// ---------------

logic                    ram_req, ram_we;
logic [AxiAddrWidth-1:0] ram_addr;
logic [AxiDataWidth-1:0] ram_rdata, ram_wdata;
logic [AxiDataWidth/8-1:0] ram_be;

axi2mem #(
    .AXI_ID_WIDTH   ( AxiIdWidth       ),
    .AXI_ADDR_WIDTH ( AxiAddrWidth     ),
    .AXI_DATA_WIDTH ( AxiDataWidth     ),
    .AXI_USER_WIDTH ( AxiUserWidth     )
) i_axi2rom (
    .clk_i  ( clk_i                    ),
    .rst_ni ( rst_ni                   ),
    .slave  ( master[ariane_soc::BOOT] ),
    .req_o  ( ram_req                  ),
    .we_o   ( ram_we                   ),
    .addr_o ( ram_addr                 ),
    .be_o   ( ram_be                   ),
    .data_o ( ram_wdata                ),
    .data_i ( ram_rdata                )
);

bootram i_bootram (
    .clk_i   ( clk_i     ),
    .req_i   ( ram_req   ),
    .we_i    ( ram_we    ),
    .addr_i  ( ram_addr  ),
    .be_i    ( ram_be    ),
    .wdata_i ( ram_wdata ),
    .rdata_o ( ram_rdata )
);
   
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

logic                    spi_en, spi_we, spi_int_n, spi_pme_n, spi_mdio_i, spi_mdio_o, spi_mdio_oe;
logic [AxiAddrWidth-1:0] spi_addr;
logic [AxiDataWidth-1:0] spi_wrdata, spi_rdata;
logic [AxiDataWidth/8-1:0] spi_be;

axi2mem #(
    .AXI_ID_WIDTH   ( AxiIdWidth       ),
    .AXI_ADDR_WIDTH ( AxiAddrWidth     ),
    .AXI_DATA_WIDTH ( AxiDataWidth     ),
    .AXI_USER_WIDTH ( AxiUserWidth     )
) i_axi2spi (
    .clk_i  ( clk_i                   ),
    .rst_ni ( rst_ni                  ),
    .slave  ( master[ariane_soc::SPI] ),
    .req_o  ( spi_en                  ),
    .we_o   ( spi_we                  ),
    .addr_o ( spi_addr                ),
    .be_o   ( spi_be                  ),
    .data_o ( spi_wrdata              ),
    .data_i ( spi_rdata               )
);

sd_bus sd1
  (
   .spisd_en     ( spi_en                  ),
   .spisd_we     ( spi_we                  ),
   .spisd_addr   ( spi_addr                ),
   .spisd_be     ( spi_be                  ),
   .spisd_wrdata ( spi_wrdata              ),
   .spisd_rddata ( spi_rdata               ),
   .clk_200MHz   ( clk_200MHz_i            ),
   .msoc_clk     ( clk_i                   ),
   .rstn         ( rst_ni                  ),
   .sd_sclk,
   .sd_detect,
   .sd_dat,
   .sd_cmd,
   .sd_reset,
   .sd_irq       ( irq_sources[1]          )
   );
       
    end else begin
        assign sd_sclk = 1'b0;
        assign sd_dat = 4'bzzzz;
        assign sd_cmd = 1'bz;

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

    // 5. GPIO

    if (InclGPIO) begin : gen_gpio

logic                    gpio_en, gpio_we, gpio_int_n, gpio_pme_n, gpio_mdio_i, gpio_mdio_o, gpio_mdio_oe;
logic [AxiAddrWidth-1:0] gpio_addr, gpio_addr_prev;
logic [AxiDataWidth-1:0] gpio_wrdata, gpio_rdata;
logic [AxiDataWidth/8-1:0] gpio_be;

axi2mem #(
    .AXI_ID_WIDTH   ( AxiIdWidth       ),
    .AXI_ADDR_WIDTH ( AxiAddrWidth     ),
    .AXI_DATA_WIDTH ( AxiDataWidth     ),
    .AXI_USER_WIDTH ( AxiUserWidth     )
) i_axi2gpio (
    .clk_i  ( clk_i                    ),
    .rst_ni ( rst_ni                   ),
    .slave  ( master[ariane_soc::GPIO] ),
    .req_o  ( gpio_en                  ),
    .we_o   ( gpio_we                  ),
    .addr_o ( gpio_addr                ),
    .be_o   ( gpio_be                  ),
    .data_o ( gpio_wrdata              ),
    .data_i ( gpio_rdata               )
);

    end // block: gen_gpio
    else
      begin
        assign master[ariane_soc::GPIO].aw_ready = 1'b1;
        assign master[ariane_soc::GPIO].ar_ready = 1'b1;
        assign master[ariane_soc::GPIO].w_ready = 1'b1;

        assign master[ariane_soc::GPIO].b_valid = master[ariane_soc::GPIO].aw_valid;
        assign master[ariane_soc::GPIO].b_id = master[ariane_soc::GPIO].aw_id;
        assign master[ariane_soc::GPIO].b_resp = axi_pkg::RESP_SLVERR;
        assign master[ariane_soc::GPIO].b_user = '0;

        assign master[ariane_soc::GPIO].r_valid = master[ariane_soc::GPIO].ar_valid;
        assign master[ariane_soc::GPIO].r_resp = axi_pkg::RESP_SLVERR;
        assign master[ariane_soc::GPIO].r_data = 'hdeadbeef;
        assign master[ariane_soc::GPIO].r_last = 1'b1;
    end
     
endmodule
