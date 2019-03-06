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
   logic [1:0]    int_fmt;
   logic [2:0]    src_fmt, dst_fmt;
   logic [4:0]    fpu_op;
   logic [63:0]   opa, opb, opc;
   TagType        tag_int;
   fpnew_pkg::operation_e op_int;
   logic          op_mod, guard;

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
            .int_fmt,
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

   localparam FIFO_DATA_WIDTH = 212;
   
   wire          testmode_i = 1'b0;       // test_mode to bypass clock gating
   // status flags
   logic         full_o;           // queue is full
   logic         empty_o;          // queue is empty
   // as long as the queue is not full we can push new data
   logic [FIFO_DATA_WIDTH-1:0] data_i;           // data to push into the queue
   logic                       push_i;           // data is valid and can be pushed to the queue
   // as long as the queue is not empty we can pop new elements
   logic [FIFO_DATA_WIDTH-1:0] data_o;           // output data
   logic                       pop_i;            // pop head from queue
   
fifo_v2 #(
    .FALL_THROUGH(1'b0), // fifo is in fall-through mode
    .DATA_WIDTH(FIFO_DATA_WIDTH),     // default data width if the fifo is of type logic
    .DEPTH(8)            // depth can be arbitrary from 0 to 2**32
) fpu_in_queue (
    .clk_i,            // Clock
    .rst_ni,           // Asynchronous reset active low
    .flush_i,          // flush the queue
    .testmode_i,       // test_mode to bypass clock gating
    .full_o,           // queue is full
    .empty_o,          // queue is empty
    .data_i,           // data to push into the queue
    .push_i,           // data is valid and can be pushed to the queue
    .data_o,           // output data
    .pop_i             // pop head from queue
);
   
   always @(posedge clk_i)
     begin
        case (op_int)
          fpnew_pkg::FMADD: fpu_op <= op_mod ? 5 : 4;
          fpnew_pkg::FNMSUB: fpu_op <= op_mod ? 4 : 13;
          fpnew_pkg::ADD: fpu_op <= op_mod ? 1 : 0;
          fpnew_pkg::MUL: fpu_op <= 6;
          fpnew_pkg::DIV: fpu_op <= 3;
          fpnew_pkg::SQRT: fpu_op <= 11;
          fpnew_pkg::SGNJ: fpu_op <= 7;
          fpnew_pkg::MINMAX: fpu_op <= 6;
          fpnew_pkg::CMP: fpu_op <= 15;
          fpnew_pkg::CLASSIFY: fpu_op <= 8;
          fpnew_pkg::F2F: fpu_op <= 9;
          fpnew_pkg::F2I: fpu_op <= 10;
          fpnew_pkg::I2F: fpu_op <= 2;
          fpnew_pkg::CPKAB: fpu_op <= 13;
          fpnew_pkg::CPKCD: fpu_op <= 14;
        endcase // case (op_int)
        fpu_op[4] <= op_mod;
     end
   
   always @(posedge clk_i)
     if (!rst_ni)
       begin
          out_valid_o <= 0;
          enable <= 0;
          pop_i <= 0;
          tag_o <= 0;
          {guard, opa, opb, opc, int_fmt, src_fmt, dst_fmt, rnd_mode, tag_int, op_int, op_mod} <= 0;
       end
     else
       begin
          pop_i <= 1'b0;
          ready0 <= ready;
          if (enable && ready && !ready0)
            begin
               out_valid_o <= 1;
               tag_o <= tag_int;
               enable <= 0;               
            end
          else if (out_valid_o)
            begin
               out_valid_o <= 0;               
            end
          else if (~enable)
            begin
               if (~empty_o)
                 begin
                    pop_i <= 1'b1;
                    enable <= 1;
                    {guard, opc, opb, opa, int_fmt, src_fmt, dst_fmt, rnd_mode, tag_int, op_int, op_mod} <= data_o;
                 end
            end
          if (flush_i)
            enable <= 0;
       end
   
   assign busy_o = !ready;
   assign in_ready_o = ~full_o;
   assign push_i = in_valid_i & ~full_o;
   assign data_i = {in_ready_o, operands_i, int_fmt_i, src_fmt_i, dst_fmt_i, rnd_mode_i, tag_i, op_i, op_mod_i};
   
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
