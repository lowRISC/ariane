// Copyright (c) 2018 ETH Zurich, University of Bologna
// All rights reserved.
//
// This code is under development and not yet released to the public.
// Until it is released, the code is under the copyright of ETH Zurich and
// the University of Bologna, and may contain confidential and/or unpublished
// work. Any reuse/redistribution is strictly forbidden without written
// permission from ETH Zurich.
//
// Bug fixes and contributions will eventually be released under the
// SolderPad open hardware license in the context of the PULP platform
// (http://www.pulp-platform.org), under the copyright of ETH Zurich and the
// University of Bologna.

// Author: Stefan Mach <smach@iis.ee.ethz.ch>

module fpnew_top #(
  // FPU configuration
  parameter fpnew_pkg::fpu_features_t       Features      = fpnew_pkg::RV64D_Xsflt,
  parameter fpnew_pkg::fpu_implementation_t Implementaion = fpnew_pkg::DEFAULT_NOREGS,
  parameter type                            TagType       = logic,
  // Do not change
  localparam int unsigned WIDTH        = Features.Width,
  localparam int unsigned NUM_OPERANDS = 3
) (
  input logic                               clk_i,
  input logic                               rst_ni,
  // Input signals
  input logic [NUM_OPERANDS-1:0][WIDTH-1:0] operands_i,
  input fpnew_pkg::roundmode_e              rnd_mode_i,
  input fpnew_pkg::operation_e              op_i,
  input logic                               op_mod_i,
  input fpnew_pkg::fp_format_e              src_fmt_i,
  input fpnew_pkg::fp_format_e              dst_fmt_i,
  input fpnew_pkg::int_format_e             int_fmt_i,
  input logic                               vectorial_op_i,
  input TagType                             tag_i,
  // Input Handshake
  input  logic                              in_valid_i,
  output logic                              in_ready_o,
  input  logic                              flush_i,
  // Output signals
  output logic [WIDTH-1:0]                  result_o,
  output fpnew_pkg::status_t                status_o,
  output TagType                            tag_o,
  // Output handshake
  output logic                              out_valid_o,
  input  logic                              out_ready_i,
  // Indication of valid data in flight
  output logic                              busy_o
);

   localparam int unsigned NUM_OPGROUPS = fpnew_pkg::NUM_OPGROUPS;
   localparam int unsigned NUM_FORMATS  = fpnew_pkg::NUM_FP_FORMATS;

   logic          enable;
   logic [2:0]    rnd_mode;
   logic [2:0]    src_fmt, dst_fmt;
   logic [4:0]    fpu_op;
   logic [63:0]   opa, opb, opc;

   always @(posedge clk_i)
     if (!rst_ni)
       begin
          opa = 0;
          opb = 0;
          opc = 0;
          src_fmt = 0;
          dst_fmt = 0;
          rnd_mode = 0;
          fpu_op = 0;
          tag_o = 0;
       end
     else if (in_valid_i)
       begin
          opa = operands_i[0];
          opb = operands_i[1];
          opc = operands_i[2];
          src_fmt = src_fmt_i;
          dst_fmt = dst_fmt_i;
          rnd_mode = rnd_mode_i;
          tag_o = tag_i;
          case (op_i)
            fpnew_pkg::FMADD: fpu_op = op_mod_i ? 5 : 4;
            fpnew_pkg::FNMSUB: fpu_op = op_mod_i ? 4 : 13;
            fpnew_pkg::ADD: fpu_op = op_mod_i ? 1 : 0;
            fpnew_pkg::MUL: fpu_op = 6;
            fpnew_pkg::DIV: fpu_op = 3;
            fpnew_pkg::SQRT: fpu_op = 11;
            fpnew_pkg::SGNJ: fpu_op = 7;
            fpnew_pkg::MINMAX: fpu_op = 6;
            fpnew_pkg::CMP: fpu_op = 15;
            fpnew_pkg::CLASSIFY: fpu_op = 8;
            fpnew_pkg::F2F: fpu_op = 9;
            fpnew_pkg::F2I: fpu_op = 15;
            fpnew_pkg::I2F: fpu_op = 2;
            fpnew_pkg::CPKAB: fpu_op = 13;
            fpnew_pkg::CPKCD: fpu_op = 14;
          endcase // case (op_i)
          fpu_op[4] = op_mod_i;
       end
   
   logic         ready0;
   wire          ready;
   wire          underflow;
   wire          overflow;
   wire          inexact;
   wire          exception;
   wire          invalid;  
   wire          divbyzero;  
   wire [6:0]    count_cycles;
   wire [6:0]    count_ready;
   
   fpu_double UUT (
            .clk(clk_i),
            .rst(!rst_ni),
            .enable,
            .rnd_mode,
            .fpu_op,
            .src_fmt,
            .dst_fmt,
            .opa,
            .opb,
            .opc,
            .out(result_o),
            .ready,
            .underflow,
            .overflow,
            .inexact,
            .exception,
            .invalid,
            .divbyzero,
            .count_cycles,
            .count_ready);  

   assign status_o.NV = invalid; // Invalid
   assign status_o.DZ = divbyzero; // Divide by zero
   assign status_o.OF = overflow; // Overflow
   assign status_o.UF = underflow; // Underflow
   assign status_o.NX = inexact; // Inexact

   always @(posedge clk_i)
     if (!rst_ni)
       begin
          out_valid_o <= 0;
          in_ready_o <= 0;
          enable <= 0;
       end
     else
       begin
          ready0 <= ready;
          if (enable && ready && !ready0)
            begin
               out_valid_o <= 1;
               enable <= 0;               
            end
          else if (out_valid_o)
            begin
               out_valid_o <= 0;               
            end
          if (in_valid_i)
            begin
               enable <= 1;
               out_valid_o <= 0;
               in_ready_o <= 1;               
            end
          else
               in_ready_o <= 0;
          if (flush_i)
            enable <= 0;
          
       end
   
   assign busy_o = !ready;

`ifndef VERILATOR
   
   wire trig_in_ack;
   
   xlnx_ila_4 fpu_ila (
        .clk(clk_i), // input wire clk
        .trig_in(in_valid_i), // input wire trig_in 
        .trig_in_ack(trig_in_ack), // output wire trig_in_ack 
        .probe0(opa),
        .probe1(opb),
        .probe2(opc),
        .probe3(rnd_mode),
        .probe4(op_i),              
        .probe5(tag_i),              
        .probe6(enable),              
        .probe7(src_fmt),              
        .probe8(fpu_op),              
        .probe9(result_o),              
        .probe10(ready),              
        .probe11(status_o),
        .probe12(out_valid_o),
        .probe13(count_cycles),
        .probe14(count_ready),
        .probe15(dst_fmt)
);

`endif
   
endmodule
