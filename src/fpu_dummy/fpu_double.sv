/////////////////////////////////////////////////////////////////////
////                                                             ////
////  FPU                                                        ////
////  Floating Point Unit (Double precision)                     ////
////                                                             ////
////  Author: David Lundgren                                     ////
////          davidklun@gmail.com                                ////
////                                                             ////
/////////////////////////////////////////////////////////////////////
////                                                             ////
//// Copyright (C) 2009 David Lundgren                           ////
////                  davidklun@gmail.com                        ////
////                                                             ////
//// This source file may be used and distributed without        ////
//// restriction provided that this copyright statement is not   ////
//// removed from the file and that any derivative work contains ////
//// the original copyright notice and the associated disclaimer.////
////                                                             ////
////     THIS SOFTWARE IS PROVIDED ``AS IS'' AND WITHOUT ANY     ////
//// EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED   ////
//// TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS   ////
//// FOR A PARTICULAR PURPOSE. IN NO EVENT SHALL THE AUTHOR      ////
//// OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,         ////
//// INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES    ////
//// (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE   ////
//// GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR        ////
//// BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF  ////
//// LIABILITY, WHETHER IN  CONTRACT, STRICT LIABILITY, OR TORT  ////
//// (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT  ////
//// OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE         ////
//// POSSIBILITY OF SUCH DAMAGE.                                 ////
////                                                             ////
/////////////////////////////////////////////////////////////////////


`timescale 1ns / 100ps
/* FPU Operations (fpu_op):
========================
0 = add
1 = sub
3 = div
4 = mul(add)
5 = mul(sub)
6 = mul(plain)
7 = sgnj

Rounding Modes (rmode):
=======================
0 = round_nearest_even
1 = round_to_zero
2 = round_up
3 = round_down  */

module fpu_double(
 input             clk,
 input             rst,
 input             enable,
 input [2:0]       rnd_mode,
 input [4:0]       fpu_op,
 input [2:0]       src_fmt,
 input [2:0]       dst_fmt,
 input [63:0]      opa, opb, opc,
 output reg [63:0] out,
 output reg        ready,
 output reg        underflow,
 output reg        overflow,
 output reg        inexact,
 output reg        exception,
 output reg        invalid,
 output reg        divbyzero,
 output reg [6:0]  count_cycles,
 output reg [6:0]  count_ready);
   
reg [63:0]	opa_reg, opb_reg, opc_reg, sqrt0;
reg [2:0]	fpu_op_reg;
reg [1:0]	rmode_reg;
reg			enable_reg;
reg			enable_strt;
reg			enable_reg_0; // high for one clock cycle (first time)
reg			enable_reg_1; // high for one clock cycle (first and any iterations)
reg			enable_reg_2; // high for one clock cycle		 
reg			enable_reg_3; // high for two clock cycles
reg			op_enable;	  
wire		count_busy = (count_ready <= count_cycles);
reg			ready_0;
reg			ready_1;
wire		underflow_0;
wire		overflow_0;
wire		inexact_0;
wire		exception_0;
wire		invalid_0;
reg		add_enable; 
reg		sub_enable; 
reg		mul_enable; 
reg		div_enable; 
reg [63:0] adda_reg, addb_reg, diva_reg, divb_reg;

wire    mul_accum = (!fpu_op_reg[2]) || (mul_enable && (count_ready >= 24) && (fpu_op_reg[2:0] != 3'b110));
   
wire	add_enable_0 = ((fpu_op_reg[1:0] == 2'b00) && mul_accum) & !(adda_reg[63] ^ addb_reg[63]);
wire	add_enable_1 = ((fpu_op_reg[1:0] == 2'b01) && mul_accum) & (adda_reg[63] ^ addb_reg[63]);
wire	sub_enable_0 = ((fpu_op_reg[1:0] == 2'b00) && mul_accum) & (adda_reg[63] ^ addb_reg[63]);
wire	sub_enable_1 = ((fpu_op_reg[1:0] == 2'b01) && mul_accum) & !(adda_reg[63] ^ addb_reg[63]);
wire	[55:0]	sum_out;
wire	[55:0]	diff_out;
reg	[55:0]	addsub_out;
wire	[55:0]	mul_out;
wire	[55:0]	div_out;
reg	[55:0]	mantissa_round;
wire	[10:0] 	exp_add_out;
wire	[10:0] 	exp_sub_out;
wire	[11:0] 	exp_mul_out;
wire	[11:0] 	exp_div_out;
reg     [11:0]  exponent_round;
reg	[11:0] 	exp_addsub;
wire	[11:0]	exponent_post_round, exponent_mul_post_round;
wire	add_sign;
wire	sub_sign;
wire	mul_sign;
wire	div_sign;
wire	except_enable_0, except_enable_1;
reg	addsub_sign;
reg	sign_round;
reg     shift_inexact, prev_inexact, invalid_sqrt;
reg [7:0] mantissa_sq;
   
   wire [63:0] out_round, mul_round;
   wire [63:0] out_except_0, out_except_1;
   wire        shift_add_inexact, shift_sub_inexact, shift_mul_inexact, shift_div_inexact;
   wire        underflow_1, overflow_1, inexact_1, exception_1, invalid_1;
   
   function [51:44] sqlookup;
      input [8:0] idx;

      begin
         case(idx)
           0: sqlookup = 0;
           1: sqlookup = 0;
           2: sqlookup = 1;
           3: sqlookup = 1;
           4: sqlookup = 2;
           5: sqlookup = 2;
           6: sqlookup = 3;
           7: sqlookup = 3;
           8: sqlookup = 4;
           9: sqlookup = 4;
           10: sqlookup = 5;
           11: sqlookup = 5;
           12: sqlookup = 6;
           13: sqlookup = 6;
           14: sqlookup = 7;
           15: sqlookup = 7;
           16: sqlookup = 8;
           17: sqlookup = 8;
           18: sqlookup = 9;
           19: sqlookup = 9;
           20: sqlookup = 10;
           21: sqlookup = 10;
           22: sqlookup = 11;
           23: sqlookup = 11;
           24: sqlookup = 12;
           25: sqlookup = 12;
           26: sqlookup = 13;
           27: sqlookup = 13;
           28: sqlookup = 14;
           29: sqlookup = 14;
           30: sqlookup = 15;
           31: sqlookup = 15;
           32: sqlookup = 16;
           33: sqlookup = 16;
           34: sqlookup = 16;
           35: sqlookup = 17;
           36: sqlookup = 17;
           37: sqlookup = 18;
           38: sqlookup = 18;
           39: sqlookup = 19;
           40: sqlookup = 19;
           41: sqlookup = 20;
           42: sqlookup = 20;
           43: sqlookup = 21;
           44: sqlookup = 21;
           45: sqlookup = 22;
           46: sqlookup = 22;
           47: sqlookup = 23;
           48: sqlookup = 23;
           49: sqlookup = 23;
           50: sqlookup = 24;
           51: sqlookup = 24;
           52: sqlookup = 25;
           53: sqlookup = 25;
           54: sqlookup = 26;
           55: sqlookup = 26;
           56: sqlookup = 27;
           57: sqlookup = 27;
           58: sqlookup = 28;
           59: sqlookup = 28;
           60: sqlookup = 28;
           61: sqlookup = 29;
           62: sqlookup = 29;
           63: sqlookup = 30;
           64: sqlookup = 30;
           65: sqlookup = 31;
           66: sqlookup = 31;
           67: sqlookup = 32;
           68: sqlookup = 32;
           69: sqlookup = 32;
           70: sqlookup = 33;
           71: sqlookup = 33;
           72: sqlookup = 34;
           73: sqlookup = 34;
           74: sqlookup = 35;
           75: sqlookup = 35;
           76: sqlookup = 36;
           77: sqlookup = 36;
           78: sqlookup = 36;
           79: sqlookup = 37;
           80: sqlookup = 37;
           81: sqlookup = 38;
           82: sqlookup = 38;
           83: sqlookup = 39;
           84: sqlookup = 39;
           85: sqlookup = 39;
           86: sqlookup = 40;
           87: sqlookup = 40;
           88: sqlookup = 41;
           89: sqlookup = 41;
           90: sqlookup = 42;
           91: sqlookup = 42;
           92: sqlookup = 42;
           93: sqlookup = 43;
           94: sqlookup = 43;
           95: sqlookup = 44;
           96: sqlookup = 44;
           97: sqlookup = 45;
           98: sqlookup = 45;
           99: sqlookup = 45;
           100: sqlookup = 46;
           101: sqlookup = 46;
           102: sqlookup = 47;
           103: sqlookup = 47;
           104: sqlookup = 48;
           105: sqlookup = 48;
           106: sqlookup = 48;
           107: sqlookup = 49;
           108: sqlookup = 49;
           109: sqlookup = 50;
           110: sqlookup = 50;
           111: sqlookup = 51;
           112: sqlookup = 51;
           113: sqlookup = 51;
           114: sqlookup = 52;
           115: sqlookup = 52;
           116: sqlookup = 53;
           117: sqlookup = 53;
           118: sqlookup = 53;
           119: sqlookup = 54;
           120: sqlookup = 54;
           121: sqlookup = 55;
           122: sqlookup = 55;
           123: sqlookup = 55;
           124: sqlookup = 56;
           125: sqlookup = 56;
           126: sqlookup = 57;
           127: sqlookup = 57;
           128: sqlookup = 58;
           129: sqlookup = 58;
           130: sqlookup = 58;
           131: sqlookup = 59;
           132: sqlookup = 59;
           133: sqlookup = 60;
           134: sqlookup = 60;
           135: sqlookup = 60;
           136: sqlookup = 61;
           137: sqlookup = 61;
           138: sqlookup = 62;
           139: sqlookup = 62;
           140: sqlookup = 62;
           141: sqlookup = 63;
           142: sqlookup = 63;
           143: sqlookup = 64;
           144: sqlookup = 64;
           145: sqlookup = 64;
           146: sqlookup = 65;
           147: sqlookup = 65;
           148: sqlookup = 66;
           149: sqlookup = 66;
           150: sqlookup = 66;
           151: sqlookup = 67;
           152: sqlookup = 67;
           153: sqlookup = 68;
           154: sqlookup = 68;
           155: sqlookup = 68;
           156: sqlookup = 69;
           157: sqlookup = 69;
           158: sqlookup = 70;
           159: sqlookup = 70;
           160: sqlookup = 70;
           161: sqlookup = 71;
           162: sqlookup = 71;
           163: sqlookup = 72;
           164: sqlookup = 72;
           165: sqlookup = 72;
           166: sqlookup = 73;
           167: sqlookup = 73;
           168: sqlookup = 73;
           169: sqlookup = 74;
           170: sqlookup = 74;
           171: sqlookup = 75;
           172: sqlookup = 75;
           173: sqlookup = 75;
           174: sqlookup = 76;
           175: sqlookup = 76;
           176: sqlookup = 77;
           177: sqlookup = 77;
           178: sqlookup = 77;
           179: sqlookup = 78;
           180: sqlookup = 78;
           181: sqlookup = 78;
           182: sqlookup = 79;
           183: sqlookup = 79;
           184: sqlookup = 80;
           185: sqlookup = 80;
           186: sqlookup = 80;
           187: sqlookup = 81;
           188: sqlookup = 81;
           189: sqlookup = 82;
           190: sqlookup = 82;
           191: sqlookup = 82;
           192: sqlookup = 83;
           193: sqlookup = 83;
           194: sqlookup = 83;
           195: sqlookup = 84;
           196: sqlookup = 84;
           197: sqlookup = 85;
           198: sqlookup = 85;
           199: sqlookup = 85;
           200: sqlookup = 86;
           201: sqlookup = 86;
           202: sqlookup = 86;
           203: sqlookup = 87;
           204: sqlookup = 87;
           205: sqlookup = 88;
           206: sqlookup = 88;
           207: sqlookup = 88;
           208: sqlookup = 89;
           209: sqlookup = 89;
           210: sqlookup = 89;
           211: sqlookup = 90;
           212: sqlookup = 90;
           213: sqlookup = 91;
           214: sqlookup = 91;
           215: sqlookup = 91;
           216: sqlookup = 92;
           217: sqlookup = 92;
           218: sqlookup = 92;
           219: sqlookup = 93;
           220: sqlookup = 93;
           221: sqlookup = 93;
           222: sqlookup = 94;
           223: sqlookup = 94;
           224: sqlookup = 95;
           225: sqlookup = 95;
           226: sqlookup = 95;
           227: sqlookup = 96;
           228: sqlookup = 96;
           229: sqlookup = 96;
           230: sqlookup = 97;
           231: sqlookup = 97;
           232: sqlookup = 97;
           233: sqlookup = 98;
           234: sqlookup = 98;
           235: sqlookup = 99;
           236: sqlookup = 99;
           237: sqlookup = 99;
           238: sqlookup = 100;
           239: sqlookup = 100;
           240: sqlookup = 100;
           241: sqlookup = 101;
           242: sqlookup = 101;
           243: sqlookup = 101;
           244: sqlookup = 102;
           245: sqlookup = 102;
           246: sqlookup = 102;
           247: sqlookup = 103;
           248: sqlookup = 103;
           249: sqlookup = 104;
           250: sqlookup = 104;
           251: sqlookup = 104;
           252: sqlookup = 105;
           253: sqlookup = 105;
           254: sqlookup = 105;
           255: sqlookup = 106;
           256: sqlookup = 106;
           257: sqlookup = 107;
           258: sqlookup = 107;
           259: sqlookup = 108;
           260: sqlookup = 109;
           261: sqlookup = 110;
           262: sqlookup = 110;
           263: sqlookup = 111;
           264: sqlookup = 112;
           265: sqlookup = 112;
           266: sqlookup = 113;
           267: sqlookup = 114;
           268: sqlookup = 114;
           269: sqlookup = 115;
           270: sqlookup = 116;
           271: sqlookup = 116;
           272: sqlookup = 117;
           273: sqlookup = 118;
           274: sqlookup = 119;
           275: sqlookup = 119;
           276: sqlookup = 120;
           277: sqlookup = 121;
           278: sqlookup = 121;
           279: sqlookup = 122;
           280: sqlookup = 123;
           281: sqlookup = 123;
           282: sqlookup = 124;
           283: sqlookup = 125;
           284: sqlookup = 125;
           285: sqlookup = 126;
           286: sqlookup = 127;
           287: sqlookup = 127;
           288: sqlookup = 128;
           289: sqlookup = 129;
           290: sqlookup = 129;
           291: sqlookup = 130;
           292: sqlookup = 131;
           293: sqlookup = 131;
           294: sqlookup = 132;
           295: sqlookup = 133;
           296: sqlookup = 133;
           297: sqlookup = 134;
           298: sqlookup = 135;
           299: sqlookup = 135;
           300: sqlookup = 136;
           301: sqlookup = 137;
           302: sqlookup = 137;
           303: sqlookup = 138;
           304: sqlookup = 139;
           305: sqlookup = 139;
           306: sqlookup = 140;
           307: sqlookup = 140;
           308: sqlookup = 141;
           309: sqlookup = 142;
           310: sqlookup = 142;
           311: sqlookup = 143;
           312: sqlookup = 144;
           313: sqlookup = 144;
           314: sqlookup = 145;
           315: sqlookup = 146;
           316: sqlookup = 146;
           317: sqlookup = 147;
           318: sqlookup = 148;
           319: sqlookup = 148;
           320: sqlookup = 149;
           321: sqlookup = 149;
           322: sqlookup = 150;
           323: sqlookup = 151;
           324: sqlookup = 151;
           325: sqlookup = 152;
           326: sqlookup = 153;
           327: sqlookup = 153;
           328: sqlookup = 154;
           329: sqlookup = 154;
           330: sqlookup = 155;
           331: sqlookup = 156;
           332: sqlookup = 156;
           333: sqlookup = 157;
           334: sqlookup = 158;
           335: sqlookup = 158;
           336: sqlookup = 159;
           337: sqlookup = 159;
           338: sqlookup = 160;
           339: sqlookup = 161;
           340: sqlookup = 161;
           341: sqlookup = 162;
           342: sqlookup = 162;
           343: sqlookup = 163;
           344: sqlookup = 164;
           345: sqlookup = 164;
           346: sqlookup = 165;
           347: sqlookup = 166;
           348: sqlookup = 166;
           349: sqlookup = 167;
           350: sqlookup = 167;
           351: sqlookup = 168;
           352: sqlookup = 169;
           353: sqlookup = 169;
           354: sqlookup = 170;
           355: sqlookup = 170;
           356: sqlookup = 171;
           357: sqlookup = 172;
           358: sqlookup = 172;
           359: sqlookup = 173;
           360: sqlookup = 173;
           361: sqlookup = 174;
           362: sqlookup = 175;
           363: sqlookup = 175;
           364: sqlookup = 176;
           365: sqlookup = 176;
           366: sqlookup = 177;
           367: sqlookup = 177;
           368: sqlookup = 178;
           369: sqlookup = 179;
           370: sqlookup = 179;
           371: sqlookup = 180;
           372: sqlookup = 180;
           373: sqlookup = 181;
           374: sqlookup = 182;
           375: sqlookup = 182;
           376: sqlookup = 183;
           377: sqlookup = 183;
           378: sqlookup = 184;
           379: sqlookup = 185;
           380: sqlookup = 185;
           381: sqlookup = 186;
           382: sqlookup = 186;
           383: sqlookup = 187;
           384: sqlookup = 187;
           385: sqlookup = 188;
           386: sqlookup = 189;
           387: sqlookup = 189;
           388: sqlookup = 190;
           389: sqlookup = 190;
           390: sqlookup = 191;
           391: sqlookup = 191;
           392: sqlookup = 192;
           393: sqlookup = 193;
           394: sqlookup = 193;
           395: sqlookup = 194;
           396: sqlookup = 194;
           397: sqlookup = 195;
           398: sqlookup = 195;
           399: sqlookup = 196;
           400: sqlookup = 197;
           401: sqlookup = 197;
           402: sqlookup = 198;
           403: sqlookup = 198;
           404: sqlookup = 199;
           405: sqlookup = 199;
           406: sqlookup = 200;
           407: sqlookup = 200;
           408: sqlookup = 201;
           409: sqlookup = 202;
           410: sqlookup = 202;
           411: sqlookup = 203;
           412: sqlookup = 203;
           413: sqlookup = 204;
           414: sqlookup = 204;
           415: sqlookup = 205;
           416: sqlookup = 206;
           417: sqlookup = 206;
           418: sqlookup = 207;
           419: sqlookup = 207;
           420: sqlookup = 208;
           421: sqlookup = 208;
           422: sqlookup = 209;
           423: sqlookup = 209;
           424: sqlookup = 210;
           425: sqlookup = 210;
           426: sqlookup = 211;
           427: sqlookup = 212;
           428: sqlookup = 212;
           429: sqlookup = 213;
           430: sqlookup = 213;
           431: sqlookup = 214;
           432: sqlookup = 214;
           433: sqlookup = 215;
           434: sqlookup = 215;
           435: sqlookup = 216;
           436: sqlookup = 216;
           437: sqlookup = 217;
           438: sqlookup = 218;
           439: sqlookup = 218;
           440: sqlookup = 219;
           441: sqlookup = 219;
           442: sqlookup = 220;
           443: sqlookup = 220;
           444: sqlookup = 221;
           445: sqlookup = 221;
           446: sqlookup = 222;
           447: sqlookup = 222;
           448: sqlookup = 223;
           449: sqlookup = 223;
           450: sqlookup = 224;
           451: sqlookup = 225;
           452: sqlookup = 225;
           453: sqlookup = 226;
           454: sqlookup = 226;
           455: sqlookup = 227;
           456: sqlookup = 227;
           457: sqlookup = 228;
           458: sqlookup = 228;
           459: sqlookup = 229;
           460: sqlookup = 229;
           461: sqlookup = 230;
           462: sqlookup = 230;
           463: sqlookup = 231;
           464: sqlookup = 231;
           465: sqlookup = 232;
           466: sqlookup = 232;
           467: sqlookup = 233;
           468: sqlookup = 234;
           469: sqlookup = 234;
           470: sqlookup = 235;
           471: sqlookup = 235;
           472: sqlookup = 236;
           473: sqlookup = 236;
           474: sqlookup = 237;
           475: sqlookup = 237;
           476: sqlookup = 238;
           477: sqlookup = 238;
           478: sqlookup = 239;
           479: sqlookup = 239;
           480: sqlookup = 240;
           481: sqlookup = 240;
           482: sqlookup = 241;
           483: sqlookup = 241;
           484: sqlookup = 242;
           485: sqlookup = 242;
           486: sqlookup = 243;
           487: sqlookup = 243;
           488: sqlookup = 244;
           489: sqlookup = 244;
           490: sqlookup = 245;
           491: sqlookup = 245;
           492: sqlookup = 246;
           493: sqlookup = 246;
           494: sqlookup = 247;
           495: sqlookup = 247;
           496: sqlookup = 248;
           497: sqlookup = 248;
           498: sqlookup = 249;
           499: sqlookup = 249;
           500: sqlookup = 250;
           501: sqlookup = 250;
           502: sqlookup = 251;
           503: sqlookup = 251;
           504: sqlookup = 252;
           505: sqlookup = 252;
           506: sqlookup = 253;
           507: sqlookup = 253;
           508: sqlookup = 254;
           509: sqlookup = 254;
           510: sqlookup = 255;
           511: sqlookup = 255;
         endcase
      end

   endfunction
   
fpu_add u1(
	   .clk(clk), .rst(rst), .enable(add_enable), .opa(adda_reg), .opb(addb_reg),
	   .sign(add_sign), .sum_2(sum_out), .exponent_2(exp_add_out),
           .shift_inexact(shift_add_inexact));

fpu_sub u2(
	   .clk(clk), .rst(rst), .enable(sub_enable), .opa(adda_reg), .opb(addb_reg),
	   .fpu_op(fpu_op_reg), .sign(sub_sign), .diff_2(diff_out),
	   .exponent_2(exp_sub_out), .shift_inexact(shift_sub_inexact));

fpu_mul u3(
	   .clk(clk), .rst(rst), .enable(mul_enable), .opa(opa), .opb(opb),
	   .sign(mul_sign), .product_7(mul_out), .exponent_5(exp_mul_out), .shift_inexact(shift_mul_inexact));	

fpu_round u3a(.clk(clk), .rst(rst), .enable(op_enable), .round_mode(rmode_reg),
	      .sign_term(mul_enable?mul_sign:div_sign),
              .mantissa_term(mul_enable?mul_out:div_out),
              .exponent_term(mul_enable?exp_mul_out:exp_div_out),
	      .round_out(mul_round), .exponent_final(exponent_mul_post_round));		
	
fpu_exceptions u3b(.clk(clk), .rst(rst), .enable(mul_enable), .rmode(rmode_reg),
	          .opa(opa), .opb(opb),
	          .in_except(mul_round), .exponent_in(exponent_mul_post_round),
	          .mantissa_in(mantissa_round[1:0]),
                  .add(1'b0), .subtract(1'b0),
                  .multiply(mul_enable), .divide(1'b0),
                  .out(out_except_1),
	          .ex_enable(except_enable_1), .underflow(underflow_1), .overflow(overflow_1),
	          .inexact(inexact_1), .exception(exception_1), .invalid(invalid_1));
		
fpu_div u4(
	   .clk(clk), .rst(rst), .enable(div_enable), .opa(diva_reg), .opb(divb_reg),
	   .sign(div_sign), .mantissa_7(div_out), .exponent_out(exp_div_out),
	   .shift_inexact(shift_div_inexact));	

fpu_round u5(.clk(clk), .rst(rst), .enable(op_enable),	.round_mode(rmode_reg),
	     .sign_term(sign_round), .mantissa_term(mantissa_round), .exponent_term(exponent_round),
	     .round_out(out_round), .exponent_final(exponent_post_round));		
	
fpu_exceptions u6(.clk(clk), .rst(rst), .enable(op_enable), .rmode(rmode_reg),
	          .opa(adda_reg), .opb(addb_reg),
	          .in_except(out_round), .exponent_in(exponent_post_round),
	          .mantissa_in(mantissa_round[1:0]),
                  .add(add_enable), .subtract(sub_enable),
                  .multiply(mul_enable), .divide(div_enable),
                  .out(out_except_0),
	          .ex_enable(except_enable_0), .underflow(underflow_0), .overflow(overflow_0),
	          .inexact(inexact_0), .exception(exception_0), .invalid(invalid_0));
		
always @(posedge clk)
begin
	case (fpu_op_reg)
	3'b011:
	  begin
	     mantissa_round <= fpu_op[3] ? addsub_out : div_out;
	     exponent_round <= fpu_op[3] ? exp_addsub-1 : exp_div_out;
	     sign_round <= fpu_op[3] ? 1'b0 : div_sign;
	  end
	default:
	  begin
	     mantissa_round <= addsub_out;
	     exponent_round <= exp_addsub;
	     sign_round <= addsub_sign;
	  end
	endcase
end

always @(posedge clk)
begin
	case (fpu_op_reg)
	3'b000:		count_cycles <= 20;
	3'b001:		count_cycles <= 21;
	3'b011:		count_cycles <= fpu_op[3] ? 92 : 71;
	3'b10?:		count_cycles <= 45; // multiply accum
	3'b110:		count_cycles <= 24;
	3'b111:		count_cycles <= 10; 
	default:	count_cycles <= 100;
	endcase
end

always @(posedge clk)
begin
	if (rst) begin
		add_enable <= 0;
		sub_enable <= 0;
		mul_enable <= 0;
		div_enable <= 0;
		addsub_out <= 0;
		addsub_sign <= 0;
		exp_addsub <= 0;
		end
	else begin
		add_enable <= (add_enable_0 | add_enable_1 | count_ready >= 72) & op_enable;
		sub_enable <= (sub_enable_0 | sub_enable_1) & op_enable;
		mul_enable <= fpu_op_reg[2] & op_enable & (0 == &fpu_op_reg[1:0]);
		div_enable <= (fpu_op_reg == 3'b011) & op_enable & enable_reg_3;
			// div_enable needs to be high for two clock cycles
		addsub_out <= add_enable ? sum_out : diff_out;
		addsub_sign <= add_enable ? add_sign : sub_sign;
		exp_addsub <= add_enable ? { 1'b0, exp_add_out} : { 1'b0, exp_sub_out};
	        shift_inexact <= shift_add_inexact | shift_sub_inexact | shift_mul_inexact | shift_div_inexact;
		end
end 

always @(posedge clk)
begin
	if (rst)
          begin
	     ready_0 <= 0;
	     ready_1 <= 0;
	     ready <= 0;	   
	     underflow <= 0;
	     overflow <= 0;
	     inexact <= 0;
	     exception <= 0;
	     invalid <= 0;	   	 
	     divbyzero <= 0;	   	 
	     out <= 0;
             count_ready <= 0;
	     enable_reg <= 0;
	     enable_strt <= 0;
	     enable_reg_0 <= 0;
	     enable_reg_1 <= 0;
	     enable_reg_2 <= 0;	   
	     enable_reg_3 <= 0;
	     opa_reg <= 0;
	     opb_reg <= 0;
	     opc_reg <= 0;
	     fpu_op_reg <= 0; 
	     rmode_reg <= 0;
	     op_enable <= 0;
	     sqrt0 <= 0;
	     mantissa_sq <= 0;
	     adda_reg <= 0;
	     addb_reg <= 0;
	     diva_reg <= 0;
	     divb_reg <= 0;
	     prev_inexact <= 0;
	     invalid_sqrt <= 0;
	  end
	else
          begin
	     casez(fpu_op)
	       5'b00011: begin diva_reg <= opa; divb_reg <= opb; end
	       5'b01011: begin diva_reg <= opa; divb_reg <= sqrt0; adda_reg <= mul_round; addb_reg <= sqrt0; end
	       5'b10101: begin adda_reg <= mul_round; addb_reg <= opc; end
	       5'b10111: begin adda_reg <= opa; addb_reg <= opb; end
	       5'b??0??: begin adda_reg <= opb; addb_reg <= opc; end
	       5'b??1??: begin adda_reg <= opc; addb_reg <= mul_round; end
	       endcase
	     if (enable_reg_0)
	       begin
		  opa_reg <= opa;
		  opb_reg <= opb;
		  opc_reg <= opc;
		  fpu_op_reg <= fpu_op;
		  prev_inexact <= 0;
		  if (fpu_op != 23)
		    invalid_sqrt <= 0;
		  sqrt0 <= opa[63] ? 64'h7ff8000000000000: {opa[62:53]+511,sqlookup({~opa[52],opa[51:44]}),44'b0};
		  case (rnd_mode)
		    fpnew_pkg::RNE: rmode_reg <= 0;
		    fpnew_pkg::RTZ: rmode_reg <= 1;
		    fpnew_pkg::RDN: rmode_reg <= 3;
		    fpnew_pkg::RUP: rmode_reg <= 2;
		    fpnew_pkg::RMM: rmode_reg <= 0;
		    fpnew_pkg::DYN: rmode_reg <= 0;
		    default: rmode_reg <= 0;
		  endcase; // case (rnd_mode)
		  op_enable <= 1;
	       end
	     enable_reg <= enable;
	     enable_strt <= enable;
	     enable_reg_0 <= enable & !enable_strt;
	     enable_reg_1 <= enable & !enable_reg;
	     enable_reg_2 <= enable_reg_1;  
	     enable_reg_3 <= enable_reg_1 | enable_reg_2;
	     if (enable_reg_1)
               begin
		  ready_0 <= 0;
		  ready_1 <= 0;
		  ready <= 0;
	          count_ready <= 0;
	       end
	     else
               begin
                  if (count_busy)
                    count_ready <= count_ready + 1;
                  else
                    begin
                       if (fpu_op == 11)
                         begin
                            sqrt0 <= out_round;
                            if ((sqrt0 == out_round) || opa[63])
			      begin
				 ready_0 <= 1;
				 invalid_sqrt <= opa[63];
			      end
                            else
			      begin
				 prev_inexact <= shift_div_inexact;
				 count_ready <= 0;
				 enable_reg <= 0;
				 enable_reg_1 <= 0;
				 enable_reg_2 <= 0;	   
				 enable_reg_3 <= 0;
			      end
                         end
                       else
		         ready_0 <= 1;
                    end
		  ready_1 <= ready_0;
		  ready <= ready_1;  
	       end
             if (ready_1) begin
		underflow <= underflow_0;
		overflow <= overflow_0;
		inexact <= (shift_inexact | inexact_0 | prev_inexact) & ~invalid_sqrt;
		exception <= exception_0;
		invalid <= invalid_0 | invalid_sqrt;
		divbyzero <= div_enable && !opb_reg;	   	 
                case(fpu_op)
                  0, 1, 3, 4, 5, 11, 13, 17, 21: out <= except_enable_0 ? out_except_0 : out_round;
                  6: out <= mul_round;
                  18, 20, 26: out <= /*except_enable ? out_except :*/ {(~out_round[63]),out_round[62:0]};
                  23: casez (rnd_mode) /* meaning overloaded, see fpu_wrap.sv */
                        3'b00?: out <= {opb[63],opa[62:0]};
                        3'b011: out <= opa;
                        default: out <= 'HDEADBEEF;
                      endcase // casez ({dst_fmt,rmode_reg})
                  default: out <= 'HDEADBEEF;
                  endcase
	     end // if (ready_1)
          end
end 
endmodule
