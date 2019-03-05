module fpu_normalise(
    input             clk,
    input [63:0]      int_in,
    input [4:0]       fpu_op,
    input [1:0]       int_fmt,
    output reg [6:0]  norm_shift,
    output reg [63:0] unsigned_opa);
   
always @(posedge clk)
  begin
     casez(int_fmt)
       2'b10: unsigned_opa <= fpu_op[4] || !int_in[31] ? int_in[31:0] : 31'HFFFFFFFF & (-int_in);
       2'b11: unsigned_opa <= fpu_op[4] || !int_in[63] ? int_in : -int_in;
       default: unsigned_opa <= 'hDEADBEEF;
     endcase
     casez(unsigned_opa)	
       64'b1???????????????????????????????????????????????????????????????: norm_shift = 12;
       64'b01??????????????????????????????????????????????????????????????: norm_shift = 11;
       64'b001?????????????????????????????????????????????????????????????: norm_shift = 10;
       64'b0001????????????????????????????????????????????????????????????: norm_shift = 9;
       64'b00001???????????????????????????????????????????????????????????: norm_shift = 8;
       64'b000001??????????????????????????????????????????????????????????: norm_shift = 7;
       64'b0000001?????????????????????????????????????????????????????????: norm_shift = 6;
       64'b00000001????????????????????????????????????????????????????????: norm_shift = 5;
       64'b000000001???????????????????????????????????????????????????????: norm_shift = 4;
       64'b0000000001??????????????????????????????????????????????????????: norm_shift = 3;
       64'b00000000001?????????????????????????????????????????????????????: norm_shift = 2;
       64'b000000000001????????????????????????????????????????????????????: norm_shift = 1;
       default: norm_shift = 0;     
     endcase // casez (unsigned_opa)
  end
/*
    64'b0000000000001???????????????????????????????????????????????????: norm_shift =  12;
    64'b00000000000001??????????????????????????????????????????????????: norm_shift =  13;
    64'b000000000000001?????????????????????????????????????????????????: norm_shift =  14;
    64'b0000000000000001????????????????????????????????????????????????: norm_shift =  15;
    64'b00000000000000001???????????????????????????????????????????????: norm_shift =  16;
    64'b000000000000000001??????????????????????????????????????????????: norm_shift =  17;
    64'b0000000000000000001?????????????????????????????????????????????: norm_shift =  18;
    64'b00000000000000000001????????????????????????????????????????????: norm_shift =  19;
    64'b000000000000000000001???????????????????????????????????????????: norm_shift =  20;
    64'b0000000000000000000001??????????????????????????????????????????: norm_shift =  21;
    64'b00000000000000000000001?????????????????????????????????????????: norm_shift =  22;
    64'b000000000000000000000001????????????????????????????????????????: norm_shift =  23;
    64'b0000000000000000000000001???????????????????????????????????????: norm_shift =  24;
    64'b00000000000000000000000001??????????????????????????????????????: norm_shift =  25;
    64'b000000000000000000000000001?????????????????????????????????????: norm_shift =  26;
    64'b0000000000000000000000000001????????????????????????????????????: norm_shift =  27;
    64'b00000000000000000000000000001???????????????????????????????????: norm_shift =  28;
    64'b000000000000000000000000000001??????????????????????????????????: norm_shift =  29;
    64'b0000000000000000000000000000001?????????????????????????????????: norm_shift =  30;
    64'b00000000000000000000000000000001????????????????????????????????: norm_shift =  31;
    64'b000000000000000000000000000000001???????????????????????????????: norm_shift =  32;
    64'b0000000000000000000000000000000001??????????????????????????????: norm_shift =  33;
    64'b00000000000000000000000000000000001?????????????????????????????: norm_shift =  34;
    64'b000000000000000000000000000000000001????????????????????????????: norm_shift =  35;
    64'b0000000000000000000000000000000000001???????????????????????????: norm_shift =  36;
    64'b00000000000000000000000000000000000001??????????????????????????: norm_shift =  37;
    64'b000000000000000000000000000000000000001?????????????????????????: norm_shift =  38;
    64'b0000000000000000000000000000000000000001????????????????????????: norm_shift =  39;
    64'b00000000000000000000000000000000000000001???????????????????????: norm_shift =  40;
    64'b000000000000000000000000000000000000000001??????????????????????: norm_shift =  41;
    64'b0000000000000000000000000000000000000000001?????????????????????: norm_shift =  42;
    64'b00000000000000000000000000000000000000000001????????????????????: norm_shift =  43;
    64'b000000000000000000000000000000000000000000001???????????????????: norm_shift =  44;
    64'b0000000000000000000000000000000000000000000001??????????????????: norm_shift =  45;
    64'b00000000000000000000000000000000000000000000001?????????????????: norm_shift =  46;
    64'b000000000000000000000000000000000000000000000001????????????????: norm_shift =  47;
    64'b0000000000000000000000000000000000000000000000001???????????????: norm_shift =  48;
    64'b00000000000000000000000000000000000000000000000001??????????????: norm_shift =  49;
    64'b000000000000000000000000000000000000000000000000001?????????????: norm_shift =  50;
    64'b0000000000000000000000000000000000000000000000000001????????????: norm_shift =  51;
    64'b00000000000000000000000000000000000000000000000000001???????????: norm_shift =  52;
    64'b000000000000000000000000000000000000000000000000000000??????????: norm_shift =  53;
    64'b000000000000000000000000000000000000000000000000000000??????????: norm_shift =  54;
    64'b0000000000000000000000000000000000000000000000000000000?????????: norm_shift =  55;
    64'b00000000000000000000000000000000000000000000000000000000????????: norm_shift =  56;
    64'b000000000000000000000000000000000000000000000000000000000???????: norm_shift =  57;
    64'b0000000000000000000000000000000000000000000000000000000000??????: norm_shift =  58;
    64'b00000000000000000000000000000000000000000000000000000000000?????: norm_shift =  59;
    64'b000000000000000000000000000000000000000000000000000000000000????: norm_shift =  60;
    64'b0000000000000000000000000000000000000000000000000000000000000???: norm_shift =  61;
    64'b00000000000000000000000000000000000000000000000000000000000000??: norm_shift =  62;
    64'b000000000000000000000000000000000000000000000000000000000000000?: norm_shift =  63;
    64'b0000000000000000000000000000000000000000000000000000000000000000: norm_shift =  64;
*/

endmodule // fpu_normalise
