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
// ----------------------------
// AXI to SRAM Adapter
// ----------------------------
// Author: Florian Zaruba (zarubaf@iis.ee.ethz.ch)
//
// Description: Manages AXI transactions
//              Supports all burst accesses but only on aligned addresses and with full data width.
//              Assertions should guide you if there is something unsupported happening.
//
module spixip #(
    parameter int unsigned AXI_ID_WIDTH      = 5,
    parameter int unsigned AXI_ADDR_WIDTH    = 64,
    parameter int unsigned AXI_DATA_WIDTH    = 64,
    parameter int unsigned AXI_USER_WIDTH    = 1
)(
    input logic                         clk_i,    // Clock
    input logic                         rst_ni,  // Asynchronous reset active low
    AXI_BUS.Slave                       slave,
    // Quad-SPI flash
    inout  wire                         flash_ss,
    inout  wire  [3:0]                  flash_io    
);

    // ---------------
    // SPI execute in place converter
    // ---------------
   
    assign slave.b_user = 1'b0;
    assign slave.r_user = 1'b0;

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
        logic [4:0]  s_axi_spi_awid;
        logic [4:0]  s_axi_spi_bid;
        logic [4:0]  s_axi_spi_arid;
        logic [4:0]  s_axi_spi_rid;
       
        wire          flash_ss_i,  flash_ss_o,  flash_ss_t;
        wire [3:0]    flash_io_i,  flash_io_o,  flash_io_t;
        // tri-state gates for Quad-SPI flash
        for(genvar i=0; i<4; i++) begin
           assign flash_io[i] = !flash_io_t[i] ? flash_io_o[i] : 1'bz;
           assign flash_io_i[i] = flash_io[i];
        end

        assign flash_ss = !flash_ss_t ? flash_ss_o : 1'bz;
        assign flash_ss_i = flash_ss;

        xlnx_axi_dwidth_converter i_xlnx_axi_dwidth_converter_spi (
            .s_axi_aclk     ( clk_i              ),
            .s_axi_aresetn  ( rst_ni             ),

            .s_axi_awid     ( slave.aw_id          ),
            .s_axi_awaddr   ( slave.aw_addr[31:0]  ),
            .s_axi_awlen    ( slave.aw_len         ),
            .s_axi_awsize   ( slave.aw_size        ),
            .s_axi_awburst  ( slave.aw_burst       ),
            .s_axi_awlock   ( slave.aw_lock        ),
            .s_axi_awcache  ( slave.aw_cache       ),
            .s_axi_awprot   ( slave.aw_prot        ),
            .s_axi_awregion ( slave.aw_region      ),
            .s_axi_awqos    ( slave.aw_qos         ),
            .s_axi_awvalid  ( slave.aw_valid       ),
            .s_axi_awready  ( slave.aw_ready       ),
            .s_axi_wdata    ( slave.w_data         ),
            .s_axi_wstrb    ( slave.w_strb         ),
            .s_axi_wlast    ( slave.w_last         ),
            .s_axi_wvalid   ( slave.w_valid        ),
            .s_axi_wready   ( slave.w_ready        ),
            .s_axi_bid      ( slave.b_id           ),
            .s_axi_bresp    ( slave.b_resp         ),
            .s_axi_bvalid   ( slave.b_valid        ),
            .s_axi_bready   ( slave.b_ready        ),
            .s_axi_arid     ( slave.ar_id          ),
            .s_axi_araddr   ( slave.ar_addr[31:0]  ),
            .s_axi_arlen    ( slave.ar_len         ),
            .s_axi_arsize   ( slave.ar_size        ),
            .s_axi_arburst  ( slave.ar_burst       ),
            .s_axi_arlock   ( slave.ar_lock        ),
            .s_axi_arcache  ( slave.ar_cache       ),
            .s_axi_arprot   ( slave.ar_prot        ),
            .s_axi_arregion ( slave.ar_region      ),
            .s_axi_arqos    ( slave.ar_qos         ),
            .s_axi_arvalid  ( slave.ar_valid       ),
            .s_axi_arready  ( slave.ar_ready       ),
            .s_axi_rid      ( slave.r_id           ),
            .s_axi_rdata    ( slave.r_data         ),
            .s_axi_rresp    ( slave.r_resp         ),
            .s_axi_rlast    ( slave.r_last         ),
            .s_axi_rvalid   ( slave.r_valid        ),
            .s_axi_rready   ( slave.r_ready        ),

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

       assign s_axi_spi_awid =  slave.aw_id;
       assign s_axi_spi_arid =  slave.ar_id;
       
        xlnx_axi_xip_spi i_xlnx_axi_quad_spi (
            .ext_spi_clk    ( clk_i                  ),
            .s_axi4_aclk    ( clk_i                  ),
            .s_axi4_aresetn ( rst_ni                 ),
            .s_axi4_awid    ( s_axi_spi_awid         ),
            .s_axi4_bid     ( s_axi_spi_bid          ),
            .s_axi4_arid    ( s_axi_spi_arid         ),
            .s_axi4_rid     ( s_axi_spi_rid          ),
            .s_axi4_awaddr  ( s_axi_spi_awaddr[31:0] ),
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
            .s_axi4_araddr  ( s_axi_spi_araddr[31:0] ),
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
            /* Only the XIP interface is needed till we get a working interrupt controller */
            .s_axi_aclk(clk_i),         // input wire s_axi_aclk
            .s_axi_aresetn(rst_ni),    // input wire s_axi_aresetn
            .s_axi_awaddr(7'b0),      // input wire [6 : 0] s_axi_awaddr
            .s_axi_awvalid(1'b0),    // input wire s_axi_awvalid
            .s_axi_awready(),       // output wire s_axi_awready
            .s_axi_wdata(32'b0),        // input wire [31 : 0] s_axi_wdata
            .s_axi_wstrb(4'b0),        // input wire [3 : 0] s_axi_wstrb
            .s_axi_wvalid(1'b0),      // input wire s_axi_wvalid
            .s_axi_wready(),         // output wire s_axi_wready
            .s_axi_bresp(),         // output wire [1 : 0] s_axi_bresp
            .s_axi_bvalid(),       // output wire s_axi_bvalid
            .s_axi_bready(1'b0),        // input wire s_axi_bready
            .s_axi_araddr(7'b0),       // input wire [6 : 0] s_axi_araddr
            .s_axi_arvalid(1'b0),     // input wire s_axi_arvalid
            .s_axi_arready(),        // output wire s_axi_arready
            .s_axi_rdata(),         // output wire [31 : 0] s_axi_rdata
            .s_axi_rresp(),        // output wire [1 : 0] s_axi_rresp
            .s_axi_rvalid(),      // output wire s_axi_rvalid
            .s_axi_rready(1'b0), // input wire s_axi_rready
            .io0_i            ( flash_io_i[0]                 ),
            .io0_o            ( flash_io_o[0]                 ),
            .io0_t            ( flash_io_t[0]                 ),
            .io1_i            ( flash_io_i[1]                 ),
            .io1_o            ( flash_io_o[1]                 ),
            .io1_t            ( flash_io_t[1]                 ),
            .io2_i            ( flash_io_i[2]                 ),
            .io2_o            ( flash_io_o[2]                 ),
            .io2_t            ( flash_io_t[2]                 ),
            .io3_i            ( flash_io_i[3]                 ),
            .io3_o            ( flash_io_o[3]                 ),
            .io3_t            ( flash_io_t[3]                 ),
            .ss_i             ( flash_ss_i                    ),
            .ss_o             ( flash_ss_o                    ),
            .ss_t             ( flash_ss_t                    ),
            .cfgclk(),                  // output wire cfgclk
            .cfgmclk(),                // output wire cfgmclk
            .eos(),                   // output wire eos
            .preq(),                 // output wire preq
            .ip2intc_irpt()
        );

endmodule
