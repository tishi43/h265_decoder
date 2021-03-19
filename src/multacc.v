//--------------------------------------------------------------------------------------------------
// Design    : bvp
// Author(s) : qiu bin, shi tian qi
// Email     : chat1@126.com, tishi1@126.com
// Copyright (C) 2013-2017 qiu bin, shi tian qi
// All rights reserved
// Phone 15957074161
// QQ:1517642772
//-------------------------------------------------------------------------------------------------

module multacc(
    clk    ,
    rst    ,
    en     ,
    a      ,
    b      ,
    p
);
//ALUMODE = subadd
//OPMODE = 0100101
//preg=1
//rst->RSTP en->CEP

parameter a_bits = 6'd16;
parameter b_bits = 6'd8;
parameter p_bits = 6'd26;

input  clk    ;
input  rst    ;
input  en     ;
input  a      ;
input  b      ;
(* use_dsp48 = "yes" *) 
output p      ;

wire clk;
wire rst;
wire en;
wire signed  [a_bits-1:0]  a      ;
wire signed  [b_bits-1:0]  b      ;
(* use_dsp48 = "yes" *)
reg  signed  [p_bits-1:0]  p      ;

always @(posedge clk)
if (rst) begin
    p      <= 0;
end else if (en) begin
        p <= a*b+p;
end

endmodule

