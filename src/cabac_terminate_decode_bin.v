//--------------------------------------------------------------------------------------------------
// Design    : bvp
// Author(s) : qiu bin, shi tian qi
// Email     : chat1@126.com, tishi1@126.com
// Copyright (C) 2013-2017 qiu bin, shi tian qi
// All rights reserved
// Phone 15957074161
// QQ:1517642772
//-------------------------------------------------------------------------------------------------

`include "defines.v"

module cabac_terminate_decode_bin
(
    input wire      [ 8: 0]  i_ivlCurrRange,
    input wire      [ 8: 0]  i_ivlOffset,
    input wire      [ 7: 7]  i_rbsp_in,

    output reg [ 8: 0]  o_ivlCurrRange,
    output reg [ 8: 0]  o_ivlOffset,
    output reg          o_binVal,
    output reg          o_output_len
);

wire [ 8:0] range_minus2;
assign range_minus2 = i_ivlCurrRange - 2;

always @(*)
begin
    if (i_ivlOffset >= range_minus2) begin
        o_binVal       = 1;
        o_ivlOffset    = i_ivlOffset;
        o_ivlCurrRange = range_minus2;
        o_output_len   = 0;
    end else begin
        o_binVal       = 0;
        o_output_len    = (range_minus2[8:7] == 2'b01);
        o_ivlCurrRange = (range_minus2[8:7] == 2'b01)?{range_minus2[7:0],1'b0}:range_minus2;
        o_ivlOffset    = (range_minus2[8:7] == 2'b01)?{i_ivlOffset[7:0],i_rbsp_in[7]}:i_ivlOffset;
    end
end

endmodule
