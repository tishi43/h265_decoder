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


//所有都延迟1周期,
//byp之后延迟1周期,如果dec,刚好, 如果再byp,要延迟1周期,
//有非dec,byp的中间状态,也刚好,
//也就是byp和dec一样,也要2周期1bit
//2个cabac_bypass_decode_bin
//第一周期,bypass1开始解码1bit,
//第二周期,如果继续bypass,bypass1解ivlOffset = {i_ivlOffset[8:0],0} bypass2解vlOffset = {i_ivlOffset[8:0],1}
//                 如果中间状态,啥也不用干
//                 如果norm dec,开始解norm,

//第3周期,此时由第二周期继续bypass过来,根据rbsp[7],选择byp_bin, 也就是3周期解2bit
//               如果继续bypass, bypass1继续 {i_ivlOffset[8:0],0} bypass2解vlOffset = {i_ivlOffset[8:0],1}, 这时的i_ivlOffset[8:0]是根据bin选择的那个
//              如果norm dec, 开始


//第0周期，输入同时输出，并且forward_len=1
//第1周期，rbsp已forward好，上一周期的输出存入cabac的ivlCurrRange_r, ivlOffset_r,输入同时输出
module cabac_bypass_decode_bin
(
    input wire      [ 8: 0]  i_ivlCurrRange,
    input wire      [ 8: 0]  i_ivlOffset,
    input wire      [ 7: 7]  i_rbsp_in,

    output reg [ 8: 0]  o_ivlOffset,
    output reg          o_binVal
);

wire [ 9:0] ivlOffset;
assign ivlOffset = {i_ivlOffset[8:0], i_rbsp_in[7]};

always @(*)
begin
    if (ivlOffset >= i_ivlCurrRange) begin
        o_binVal = 1;
        o_ivlOffset = ivlOffset - i_ivlCurrRange;
    end else begin
        o_binVal = 0;
        o_ivlOffset = ivlOffset;
    end
end

endmodule
