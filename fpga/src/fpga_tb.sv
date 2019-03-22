`timescale 1ns/1ps

module fpga_tb;
   
   logic         sys_clk_p   ;
   logic         sys_clk_n   ;
   logic         cpu_resetn  ;
   wire [31:0]   ddr3_dq     ;
   wire [ 3:0]   ddr3_dqs_n  ;
   wire [ 3:0]   ddr3_dqs_p  ;
   logic [14:0]  ddr3_addr   ;
   logic [ 2:0]  ddr3_ba     ;
   logic         ddr3_ras_n  ;
   logic         ddr3_cas_n  ;
   logic         ddr3_we_n   ;
   logic         ddr3_reset_n;
   logic [ 0:0]  ddr3_ck_p   ;
   logic [ 0:0]  ddr3_ck_n   ;
   logic [ 0:0]  ddr3_cke    ;
   logic [ 0:0]  ddr3_cs_n   ;
   logic [ 3:0]  ddr3_dm     ;
   logic [ 0:0]  ddr3_odt    ;
   wire          eth_rst_n   ;
   wire          eth_rxck    ;
   wire          eth_rxctl   ;
   wire [3:0]    eth_rxd     ;
   wire          eth_txck    ;
   wire          eth_txctl   ;
   wire [3:0]    eth_txd     ;
   wire          eth_mdio    ;
   logic         eth_mdc     ;
   logic [ 7:0]  led         ;
   logic [ 7:0]  sw          ;
   logic         fan_pwm     ;
   // SD (shared with SPI)
   wire          sd_sclk     ;
   wire          sd_detect   ;
   wire [3:0]    sd_dat      ;
   wire          sd_cmd      ;
   reg           sd_reset    ;
   // common part
   logic         tck         ;
   logic         tms         ;
   logic         trst_n      ;
   logic         tdi         ;
   logic         tdo         ;
   logic         rx          ;
   logic         tx          ;

   initial
     begin
        $vcdpluson;
          sw = 0;
          sys_clk_p = 0;
          cpu_resetn = 0;
        forever
          begin
             #2.5
               sys_clk_p = 1;
             #2.5
               sys_clk_p = 0;
             #2.5
               sys_clk_p = 1;
             #2.5
               sys_clk_p = 0;
             cpu_resetn = 1;
          end
     end

   assign sys_clk_n = ~sys_clk_p;
   assign rx = tx;
   assign tck = 0;
   assign tms = 0;
   assign tdi = 0;
   assign trst_n = 1;
   assign sd_detect = 0;
   
ariane_xilinx dut (
 .sys_clk_p,
 .sys_clk_n,
 .cpu_resetn,
 .ddr3_dq,
 .ddr3_dqs_n,
 .ddr3_dqs_p,
 .ddr3_addr,
 .ddr3_ba,
 .ddr3_ras_n,
 .ddr3_cas_n,
 .ddr3_we_n,
 .ddr3_reset_n,
 .ddr3_ck_p,
 .ddr3_ck_n,
 .ddr3_cke,
 .ddr3_cs_n,
 .ddr3_dm,
 .ddr3_odt,
 .eth_rst_n,
 .eth_rxck,
 .eth_rxctl,
 .eth_rxd,
 .eth_txck,
 .eth_txctl,
 .eth_txd,
 .eth_mdio,
 .eth_mdc,
 .led,
 .sw,
 .fan_pwm,
  // SD (shared with SPI)
 .sd_sclk,
 .sd_detect,
 .sd_dat,
 .sd_cmd,
 .sd_reset,
  // common part
 .tck,
 .tms,
 .trst_n,
 .tdi,
 .tdo,
 .rx,
 .tx
);

endmodule // fpga_tb
