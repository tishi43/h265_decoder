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


//���ж��ӳ�1����,
//byp֮���ӳ�1����,���dec,�պ�, �����byp,Ҫ�ӳ�1����,
//�з�dec,byp���м�״̬,Ҳ�պ�,
//Ҳ����byp��decһ��,ҲҪ2����1bit
//2��cabac_bypass_decode_bin
//��һ����,bypass1��ʼ����1bit,
//�ڶ�����,�������bypass,bypass1��ivlOffset = {i_ivlOffset[8:0],0} bypass2��vlOffset = {i_ivlOffset[8:0],1}
//                 ����м�״̬,ɶҲ���ø�
//                 ���norm dec,��ʼ��norm,

//��3����,��ʱ�ɵڶ����ڼ���bypass����,����rbsp[7],ѡ��byp_bin, Ҳ����3���ڽ�2bit
//               �������bypass, bypass1���� {i_ivlOffset[8:0],0} bypass2��vlOffset = {i_ivlOffset[8:0],1}, ��ʱ��i_ivlOffset[8:0]�Ǹ���binѡ����Ǹ�
//              ���norm dec, ��ʼ


//��0���ڣ�����ͬʱ���������forward_len=1
//��1���ڣ�rbsp��forward�ã���һ���ڵ��������cabac��ivlCurrRange_r, ivlOffset_r,����ͬʱ���
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
