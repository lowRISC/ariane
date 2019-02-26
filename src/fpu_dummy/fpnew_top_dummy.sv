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
  parameter fpnew_pkg::fpu_implementation_t Implementaion = fpnew_pkg::DEFAULT_2REGS,
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
   logic [1:0]    rmode;
   logic [3:0]    fpu_op;
   logic [63:0]   opa, opb;

   always @(posedge clk_i)
     if (!rst_ni)
       begin
          opa = 0;
          opb = 0;
          rmode = 0;
          fpu_op = 0;
          tag_o = 0;
       end
     else if (in_valid_i)
       begin
          opa = operands_i[1];
          opb = operands_i[2];
          case (rnd_mode_i)
            fpnew_pkg::RNE: rmode = 0;
            fpnew_pkg::RTZ: rmode = 1;
            fpnew_pkg::RDN: rmode = 3;
            fpnew_pkg::RUP: rmode = 2;
            fpnew_pkg::RMM: rmode = 0;
            fpnew_pkg::DYN: rmode = 0;
          endcase; // case (rnd_mode_i)
          tag_o = tag_i;
          case (op_i)
            fpnew_pkg::FMADD: fpu_op = 0;
            fpnew_pkg::FNMSUB: fpu_op = 1;
            fpnew_pkg::ADD: fpu_op = 0;
            fpnew_pkg::MUL: fpu_op = 2;
            // ADDMUL operation group
            fpnew_pkg::DIV: fpu_op = 3;
            fpnew_pkg::SQRT: fpu_op = 4;
            // DIVSQRT operation group
            fpnew_pkg::SGNJ: fpu_op = 5;
            fpnew_pkg::MINMAX: fpu_op = 6;
            fpnew_pkg::CMP: fpu_op = 7;
            fpnew_pkg::CLASSIFY: fpu_op = 8;
            // NONCOMP operation group
            fpnew_pkg::F2F: fpu_op = 9;
            fpnew_pkg::F2I: fpu_op = 10;
            fpnew_pkg::I2F: fpu_op = 11;
            fpnew_pkg::CPKAB: fpu_op = 12;
            fpnew_pkg::CPKCD: fpu_op = 13;
          endcase // case (op_i)
       end
   
   logic         ready0;
   wire          ready;
   wire          underflow;
   wire          overflow;
   wire          inexact;
   wire          exception;
   wire          invalid;  
   
   fpu_double UUT (
            .clk(clk_i),
            .rst(!rst_ni),
            .enable(enable),
            .rmode(rmode),
            .fpu_op(fpu_op),
            .opa(opa),
            .opb(opb),
            .out(result_o),
            .ready(ready),
            .underflow(underflow),
            .overflow(overflow),
            .inexact(inexact),
            .exception(exception),
            .invalid(invalid));  

   assign status_o.NV = invalid; // Invalid
   assign status_o.DZ = exception; // Divide by zero
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
   
endmodule
