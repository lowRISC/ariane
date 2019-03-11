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
// Date: 28/09/2018
// Description: Mock replacement for UART in testbench (not synthesiesable!)

module apb_uart (
    input  logic          CLK,
    input  logic          RSTN,
    input  logic          PENABLE,
    input  logic          PWRITE,
    input  logic [31:0]   PADDR,
    input  logic          PSEL,
    input  logic [31:0]   PWDATA,
    output logic [31:0]   PRDATA,
    output logic          PREADY,
    output logic          PSLVERR,
    output logic          INT, OUT1N, OUT2N, RTSN, DTRN, SOUT,
    input  logic          CTSN, DSRN, DCDN, RIN, SIN
);
    localparam RBR = 0;
    localparam THR = 0;
    localparam IER = 1;
    localparam IIR = 2;
    localparam FCR = 2;
    localparam LCR = 3;
    localparam MCR = 4;
    localparam LSR = 5;
    localparam MSR = 6;
    localparam SCR = 7;
    localparam DLL = 0;
    localparam DLM = 1;

    localparam THRE = 5; // transmit holding register empty
    localparam TEMT = 6; // transmit holding register empty

    byte lcr = 0;
    byte dlm = 0;
    byte dll = 0;
    byte mcr = 0;
    byte lsr = 0;
    byte ier = 0;
    byte msr = 0;
    byte scr = 0;
    logic fifo_enabled = 1'b0;

    assign PREADY = 1'b1;
    assign PSLVERR = 1'b0;

    // put a char into the buffer
    function void append(byte ch);

        // wait for the new line
        if (ch == 8'hA)
            $display("");
        else
            $write("%c", ch);

    endfunction : append

    always_ff @(posedge CLK or negedge RSTN) begin
        if (RSTN) begin
            if (PSEL & PENABLE & PWRITE) begin
                case ((PADDR >> 'h2) & 'h7)
                    THR: begin
                        if (lcr & 'h80) dll <= byte'(PWDATA[7:0]);
                        else append(byte'(PWDATA[7:0]));
                    end
                    IER: begin
                        if (lcr & 'h80) dlm <= byte'(PWDATA[7:0]);
                        else ier <= byte'(PWDATA[7:0] & 'hF);
                    end
                    FCR: begin
                        if (PWDATA[0]) fifo_enabled <= 1'b1;
                        else fifo_enabled <= 1'b0;
                    end
                    LCR: lcr <= byte'(PWDATA[7:0]);
                    MCR: mcr <= byte'(PWDATA[7:0] & 'h1F);
                    LSR: lsr <= byte'(PWDATA[7:0]);
                    MSR: msr <= byte'(PWDATA[7:0]);
                    SCR: scr <= byte'(PWDATA[7:0]);
                    default:;
                endcase
            end
        end
    end

    always_comb begin
        PRDATA = '0;
        if (PSEL & PENABLE & ~PWRITE) begin
            case ((PADDR >> 'h2) & 'h7)
                THR: begin
                    if (lcr & 'h80) PRDATA = {24'b0, dll};
                end
                IER: begin
                    if (lcr & 'h80) PRDATA = {24'b0, dlm};
                    else PRDATA = {24'b0, ier};
                end
                IIR: begin
                    if (fifo_enabled) PRDATA = {24'b0, 8'hc0};
                    else PRDATA = {24'b0, 8'b0};
                end
                LCR: PRDATA = {24'b0, lcr};
                MCR: PRDATA = {24'b0, mcr};
                LSR: PRDATA = {24'b0, (lsr | (1 << THRE) | (1 << TEMT))};
                MSR: PRDATA = {24'b0, msr};
                SCR: PRDATA = {24'b0, scr};
                default:;
            endcase
        end
    end
endmodule
