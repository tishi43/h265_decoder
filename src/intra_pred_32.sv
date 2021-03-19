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
`include "type_defs.sv"

module intra_pred_32
(
 input wire                       clk                                   ,
 input wire                       rst                                   ,
 input wire                       global_rst                            ,
 input wire                       en                                    ,
 input wire  [15:0]               i_slice_num                           ,
 input wire  [`max_x_bits-1:0]    i_x0                                  ,
 input wire  [`max_y_bits-1:0]    i_y0                                  ,
 input wire  [ 5:0]               i_xTu                                 ,
 input wire  [ 5:0]               i_yTu                                 ,

 input wire  [ 2:0]               i_log2TrafoSize                       ,
 input wire  [ 5:0]               i_trafoSize                           ,
 input wire  [ 1:0]               i_cIdx                                ,

 input wire  [63:0][ 7:0]         i_line_buf_left                       ,
 input wire  [95:0][ 7:0]         i_line_buf_top                        ,
 input wire  [15:0][ 7:0]         i_leftup                              ,

 input wire                       i_strong_intra_smoothing_enabled_flag ,
 input wire  [ 5:0]               i_intra_predmode                      , //0~34

 output reg  [63:0]               dram_pred_we                          ,
 output reg  [63:0][ 5:0]         dram_pred_addr                        ,
 output reg  [63:0][ 7:0]         dram_pred_din                         ,


 input wire  [31: 0]              fd_log                                ,

 input wire  [ 8: 0]              i_left_avail                          , //包括leftup
 input wire  [ 7: 0]              i_up_avail                            ,
 input wire                       i_avail_done                          ,
 output reg  [ 6: 0]              o_pred_done_y                         ,
 output reg  [ 3: 0]              o_intra_pred_state

);

parameter ref_pick_top           = 2'b00; //上+右上
parameter ref_pick_left          = 2'b01;
parameter ref_pick_partial_left  = 2'b10; //左一部分+上
parameter ref_pick_partial_top   = 2'b11;

reg  [`max_x_bits-1:0]     x0                      ;
reg  [`max_y_bits-1:0]     y0                      ;
reg  [ 5:0]                xTu                     ;
reg  [ 5:0]                yTu                     ;
reg  [ 4:0]                x                       ;
reg  [ 4:0]                y                       ;
reg  [ 8:0]                left_avail              ;
reg  [ 7:0]                up_avail                ;

reg  [  5:0]               intra_predmode          ;

reg  [  2:0]               log2TrafoSize           ;
reg  [  5:0]               trafoSize               ;
reg  [  2:0]               trafoSize_bit5to2_minus1;
reg  [  1:0]               cIdx                    ;
reg  [  2:0]               intraHorVerDisThres     ;
reg  [  4:0]               minDistVerHor           ;
reg  [  4:0]               abs_intramode_minus26   ;
reg  [  4:0]               abs_intramode_minus10   ;
reg                        strong_smooth_cond0     ;
reg                        strong_smooth_cond1     ;
reg                        filtered                ;

reg  [ 63:0][ 7:0]         pleft                   ;
reg  [ 63:0][ 7:0]         ptop                    ;
reg  [ 31:0][ 7:0]         pleft_bk                ;
reg  [ 31:0][ 7:0]         ptop_bk                 ;
reg  [ 31:0][ 7:0]         pleft_copy              ;
reg  [ 31:0][ 7:0]         ptop_copy               ;

reg         [ 7:0]         leftup                  ;
reg  [ 63:0][ 7:0]         pleft_w                 ;
reg  [ 63:0][ 7:0]         ptop_w                  ;
reg  [ 63:0][ 7:0]         pFleft_w                ;
reg  [ 63:0][ 7:0]         pFtop_w                 ;
reg         [ 7:0]         leftup_w                ;
reg         [13:0]         pleft_tmp               ;
reg         [13:0]         ptop_tmp                ;
reg         [13:0]         pleft_tmp_init          ;
reg         [13:0]         ptop_tmp_init           ;
reg         [ 7:0]         pleft_63                ;
reg         [ 7:0]         ptop_63                 ;


reg  [ 2:0]                sub_i              ;
reg  [ 5:0]                filter_i           ;

reg  [ 3:0]                phase              ;
reg  [ 2:0]                stage              ;
reg  [ 1:0]                tier               ;
reg                        valid              ; //至少一个4x4预测完成,可以存储了
wire [16:0]                avail_sz_32x32     ;
wire [ 8:0]                avail_sz_16x16     ;
wire [ 4:0]                avail_sz_8x8_4x4   ;

assign avail_sz_32x32 = {left_avail[8],left_avail[7],left_avail[6],left_avail[5],
                          left_avail[4],left_avail[3],left_avail[2],left_avail[1],left_avail[0],
                          up_avail[0],up_avail[1],up_avail[2],up_avail[3],
                          up_avail[4],up_avail[5],up_avail[6],up_avail[7]};
assign avail_sz_16x16 = {left_avail[4],left_avail[3],left_avail[2],left_avail[1],left_avail[0],
                          up_avail[0],up_avail[1],up_avail[2],up_avail[3]};
assign avail_sz_8x8_4x4 = {left_avail[2],left_avail[1],left_avail[0],
                          up_avail[0],up_avail[1]};

always @ (intra_predmode)
begin
    if (intra_predmode > 26)
        abs_intramode_minus26  = intra_predmode-26;
    else
        abs_intramode_minus26  = 26-intra_predmode;
    if (intra_predmode > 10)
        abs_intramode_minus10  = intra_predmode-10;
    else
        abs_intramode_minus10  = 10-intra_predmode;
end

always @(leftup or ptop[63] or ptop[31])
begin
    if ((leftup+ptop[63]>={ptop[31],1'b0} &&
        leftup+ptop[63]-{ptop[31],1'b0}<8) ||
        (leftup+ptop[63]<{ptop[31],1'b0} &&
        {ptop[31],1'b0}-leftup-ptop[63]<8))
        strong_smooth_cond0    = 1;
    else
        strong_smooth_cond0    = 0;
end

always @(leftup or pleft[63] or pleft[31])
begin
    if ((leftup+pleft[63]>={pleft[31],1'b0} &&
        leftup+pleft[63]-{pleft[31],1'b0}<8) ||
        (leftup+pleft[63]<{pleft[31],1'b0} &&
        {pleft[31],1'b0}-leftup-pleft[63]<8))
        strong_smooth_cond1    = 1;
    else
        strong_smooth_cond1    = 0;
end

genvar i;
generate
    for (i=1;i<=7;i++)
    begin: left_label
        always @(*)
        begin
            if (~left_avail[i])
                pleft_w[8*i-1:8*(i-1)]  = {8{pleft[8*i]}};
            else
                pleft_w[8*i-1:8*(i-1)]  = pleft[8*i-1:8*(i-1)]; //[63:56],[55:48]<=56,[7:0]<=8
        end
    end
endgenerate

generate
    for (i=1;i<8;i++)
    begin: up_label
        always @(*)
        begin
            if (~up_avail[i])
                ptop_w[8*i+7:8*i]  = {8{ptop[8*i-1]}};
            else
                ptop_w[8*i+7:8*i]  = ptop[8*i+7:8*i]; //[15:8]<=7,...[63:56]<=55
        end
    end
endgenerate

always @(*)
begin
    if (~up_avail[0])
        ptop_w[7:0]        = {8{leftup}};
    else
        ptop_w[7:0]        = ptop[7:0];
end

always @(left_avail[0] or leftup or pleft[0])
begin
    if (left_avail[0])
        leftup_w         = leftup;
    else
        leftup_w         = pleft[0];
end

generate
    for (i=1;i<63;i++)
    begin: filter_left_label
        always @(pleft[i] or pleft[i+1] or pleft[i-1])
        begin
            pFleft_w[i]    = (pleft[i+1]+{pleft[i],1'b0}+pleft[i-1]+2)>>2;
        end
    end
endgenerate

generate
    for (i=1;i<63;i++)
    begin: filter_up_label
        always @(ptop[i] or ptop[i+1] or ptop[i-1])
        begin
            pFtop_w[i]    = (ptop[i+1]+{ptop[i],1'b0}+ptop[i-1]+2)>>2;
        end
    end
endgenerate

reg         [15:0][ 5:0]             accum_a;
reg         [15:0][ 7:0]             accum_b;
wire        [15:0][23:0]             accum_p;

reg                                  accum_rst;
reg                                  accum_en;
reg         [15:0][ 7:0]             result4x4;
reg signed  [ 3:0][ 9:0]             result_posx0_tmp;
reg signed  [ 3:0][ 9:0]             result_pos0y_tmp;
reg         [ 3:0][ 7:0]             result_posx0; //y=0
reg         [ 3:0][ 7:0]             result_pos0y; //x=0
reg         [15:0][ 7:0]             result4x4_copy;
reg         [15:0][ 7:0]             result4x4_planar_w;
wire        [15:0][ 7:0]             result4x4_angular_w;

reg signed        [ 9:0]             posx0_tmp[3:0];
reg signed        [ 9:0]             pos0y_tmp[3:0];
reg signed        [ 9:0]             pleft0;
reg signed        [ 9:0]             ptop0;

//planar
generate
    for (i=0;i<16;i++)
    begin: result_planar_label
        always @(accum_p[i] or log2TrafoSize)
        begin
            case (log2TrafoSize)
                2: result4x4_planar_w[i]  = (accum_p[i]+4)>>3;
                3: result4x4_planar_w[i]  = (accum_p[i]+8)>>4;
                4: result4x4_planar_w[i]  = (accum_p[i]+16)>>5;
                default: result4x4_planar_w[i]  = (accum_p[i]+32)>>6;
            endcase
        end
    end
endgenerate

generate
    for (i=0;i<16;i++)
    begin: result_angular_label
        assign result4x4_angular_w[i] = (accum_p[i]+16)>>5;
    end
endgenerate

reg                [13: 0]     dc_sum                 ;
reg                [ 3: 0]     sum_i                  ;
reg                [ 7: 0]     dcVal                  ;

reg  [ 0: 7][31: 0][ 5: 0]     ref_partial_pick_tab   ;
reg         [31: 0][ 5: 0]     ref_pick_idx           ;
reg         [64: 0][ 7: 0]     ref_r                  ;
reg  [ 3: 0][32: 0][ 7: 0]     ref4                   ;
reg         [64: 0][ 7: 0]     ref_bk                 ;
reg                [ 1: 0]     pick_ref               ;
wire        [64: 0][ 7: 0]     ref_w                  ;

reg  [ 0:16][ 0:31][ 4: 0]     iFact_tab              ;
reg         [ 0:31][ 4: 0]     iFact_idx              ;
reg         [ 0:16][ 0:31]     iIdx_delta_tab         ; //当前iIdx和上个iIdx差
reg                [ 0:31]     iIdx_delta_idx         ;

//这里只是partial_left,partial_top的情况，ref_pick_top和ref_pick_left全部用上面和左边
assign ref_w[32] = leftup;
generate
    for (i=0;i<32;i++)
    begin: ref_pick_label1
        assign ref_w[i] = pick_ref == ref_pick_partial_left?pleft[ref_pick_idx[31-i]]:ptop[ref_pick_idx[31-i]];
    end
endgenerate

generate
    for (i=33;i<=64;i++)
    begin: ref_pick_label2
        assign ref_w[i] = pick_ref == ref_pick_partial_left?ptop[i-33]:pleft[i-33];
    end
endgenerate

//箭头朝上左半部份,ref_pick_partial_left,用到ptop全部和pleft一部分,ref[0~31]放partial left，ref[33~64]放top,
//memcpy(ref, p_top - 1, (nTbS + 1) * sizeof(int));
//for (x = -1; x > (nTbS * intraPredAngle) >> 5; x--)
//    ref[x] = p_left[-1+((x*invAngle+128)>>8)];
//ref index有负数，这里转成全部正数，ref_w[0]对应c代码里的ref[-32],ref_w[32]对应c代码的ref[0]
//ref_pick_idx=ref_partial_pick_tab[angle]
//ref_pick_idx[0]对应上面x=-32时的-1+((x*invAngle+128)>>8)值

//箭头朝左上半部分，ref_pick_partial_top,用到pleft全部和ptop一部分,ref[0~31]放partial top，ref[33~64]放left
//memcpy(ref, p_left - 1, (nTbS + 1) * sizeof(int));
//for (x = -1; x > (nTbS * intraPredAngle) >> 5; x--)
//    ref[x] = p_top[-1+((x*invAngle+128)>>8)];
//同样这里ref_w[0]对应ref[-32]

initial begin
    ref_partial_pick_tab = {
        {6'd0, 6'd0, 6'd0, 6'd0, 6'd0, 6'd0, 6'd0, 6'd0, 6'd0, 6'd0, 6'd0, 6'd0, 6'd0, 6'd0, 6'd0, 6'd0,
         6'd0, 6'd0, 6'd0, 6'd0, 6'd0, 6'd0, 6'd0, 6'd0, 6'd0, 6'd0, 6'd0, 6'd0, 6'd0, 6'd0, 6'd31, 6'd15},
        {6'd0, 6'd0, 6'd0, 6'd0, 6'd0, 6'd0, 6'd0, 6'd0, 6'd0, 6'd0, 6'd0, 6'd0, 6'd0, 6'd0, 6'd0, 6'd0,
         6'd0, 6'd0, 6'd0, 6'd0, 6'd0, 6'd0, 6'd0, 6'd0, 6'd0, 6'd0, 6'd0, 6'd31, 6'd25, 6'd18, 6'd12, 6'd5},
        {6'd0, 6'd0, 6'd0, 6'd0, 6'd0, 6'd0, 6'd0, 6'd0, 6'd0, 6'd0, 6'd0, 6'd0, 6'd0, 6'd0, 6'd0, 6'd0,
         6'd0, 6'd0, 6'd0, 6'd0, 6'd0, 6'd0, 6'd0, 6'd31, 6'd27, 6'd24, 6'd20, 6'd17, 6'd13, 6'd10, 6'd6, 6'd3},
        {6'd0, 6'd0, 6'd0, 6'd0, 6'd0, 6'd0, 6'd0, 6'd0, 6'd0, 6'd0, 6'd0, 6'd0, 6'd0, 6'd0, 6'd0, 6'd0,
         6'd0, 6'd0, 6'd0, 6'd31, 6'd29, 6'd26, 6'd24, 6'd21, 6'd19, 6'd16, 6'd14, 6'd11, 6'd9, 6'd6, 6'd4, 6'd1},
        {6'd0, 6'd0, 6'd0, 6'd0, 6'd0, 6'd0, 6'd0, 6'd0, 6'd0, 6'd0, 6'd0, 6'd0, 6'd0, 6'd0, 6'd0, 6'd31, 6'd29,
         6'd27, 6'd25, 6'd23, 6'd22, 6'd20, 6'd18, 6'd16, 6'd14, 6'd12, 6'd10, 6'd8, 6'd7, 6'd5, 6'd3, 6'd1},
        {6'd0, 6'd0, 6'd0, 6'd0, 6'd0, 6'd0, 6'd0, 6'd0, 6'd0, 6'd0, 6'd0, 6'd31, 6'd29, 6'd28, 6'd26, 6'd25,
         6'd23, 6'd22, 6'd20, 6'd19, 6'd17, 6'd16, 6'd14, 6'd13, 6'd11, 6'd10, 6'd8, 6'd7, 6'd5, 6'd4, 6'd2, 6'd1},
        {6'd0, 6'd0, 6'd0, 6'd0, 6'd0, 6'd32, 6'd31, 6'd30, 6'd29, 6'd27, 6'd26, 6'd25, 6'd24, 6'd22, 6'd21, 6'd20,
         6'd19, 6'd17, 6'd16, 6'd15, 6'd14, 6'd13, 6'd11, 6'd10, 6'd9, 6'd8, 6'd6, 6'd5, 6'd4, 6'd3, 6'd1, 6'd0},
        {6'd31, 6'd30, 6'd29, 6'd28, 6'd27, 6'd26, 6'd25, 6'd24, 6'd23, 6'd22, 6'd21, 6'd20, 6'd19, 6'd18, 6'd17,
         6'd16, 6'd15, 6'd14, 6'd13, 6'd12, 6'd11, 6'd10, 6'd9, 6'd8, 6'd7, 6'd6, 6'd5, 6'd4, 6'd3, 6'd2, 6'd1, 6'd0}

    };
    iFact_tab = {
        {5'd0, 5'd0, 5'd0, 5'd0, 5'd0, 5'd0, 5'd0, 5'd0, 5'd0, 5'd0, 5'd0, 5'd0, 5'd0, 5'd0, 5'd0, 5'd0, 5'd0, 5'd0,
         5'd0, 5'd0, 5'd0, 5'd0, 5'd0, 5'd0, 5'd0, 5'd0, 5'd0, 5'd0, 5'd0, 5'd0, 5'd0, 5'd0},
        {5'd26, 5'd20, 5'd14, 5'd8, 5'd2, 5'd28, 5'd22, 5'd16, 5'd10, 5'd4, 5'd30, 5'd24, 5'd18, 5'd12, 5'd6, 5'd0,
         5'd26, 5'd20, 5'd14, 5'd8, 5'd2, 5'd28, 5'd22, 5'd16, 5'd10, 5'd4, 5'd30, 5'd24, 5'd18, 5'd12, 5'd6, 5'd0},
        {5'd21, 5'd10, 5'd31, 5'd20, 5'd9, 5'd30, 5'd19, 5'd8, 5'd29, 5'd18, 5'd7, 5'd28, 5'd17, 5'd6, 5'd27, 5'd16,
         5'd5, 5'd26, 5'd15, 5'd4, 5'd25, 5'd14, 5'd3, 5'd24, 5'd13, 5'd2, 5'd23, 5'd12, 5'd1, 5'd22, 5'd11, 5'd0},
        {5'd17, 5'd2, 5'd19, 5'd4, 5'd21, 5'd6, 5'd23, 5'd8, 5'd25, 5'd10, 5'd27, 5'd12, 5'd29, 5'd14, 5'd31, 5'd16,
         5'd1, 5'd18, 5'd3, 5'd20, 5'd5, 5'd22, 5'd7, 5'd24, 5'd9, 5'd26, 5'd11, 5'd28, 5'd13, 5'd30, 5'd15, 5'd0},
        {5'd13, 5'd26, 5'd7, 5'd20, 5'd1, 5'd14, 5'd27, 5'd8, 5'd21, 5'd2, 5'd15, 5'd28, 5'd9, 5'd22, 5'd3, 5'd16,
         5'd29, 5'd10, 5'd23, 5'd4, 5'd17, 5'd30, 5'd11, 5'd24, 5'd5, 5'd18, 5'd31, 5'd12, 5'd25, 5'd6, 5'd19, 5'd0},
        {5'd9, 5'd18, 5'd27, 5'd4, 5'd13, 5'd22, 5'd31, 5'd8, 5'd17, 5'd26, 5'd3, 5'd12, 5'd21, 5'd30, 5'd7, 5'd16,
         5'd25, 5'd2, 5'd11, 5'd20, 5'd29, 5'd6, 5'd15, 5'd24, 5'd1, 5'd10, 5'd19, 5'd28, 5'd5, 5'd14, 5'd23, 5'd0},
        {5'd5, 5'd10, 5'd15, 5'd20, 5'd25, 5'd30, 5'd3, 5'd8, 5'd13, 5'd18, 5'd23, 5'd28, 5'd1, 5'd6, 5'd11, 5'd16,
         5'd21, 5'd26, 5'd31, 5'd4, 5'd9, 5'd14, 5'd19, 5'd24, 5'd29, 5'd2, 5'd7, 5'd12, 5'd17, 5'd22, 5'd27, 5'd0},
        {5'd2, 5'd4, 5'd6, 5'd8, 5'd10, 5'd12, 5'd14, 5'd16, 5'd18, 5'd20, 5'd22, 5'd24, 5'd26, 5'd28, 5'd30, 5'd0,
         5'd2, 5'd4, 5'd6, 5'd8, 5'd10, 5'd12, 5'd14, 5'd16, 5'd18, 5'd20, 5'd22, 5'd24, 5'd26, 5'd28, 5'd30, 5'd0},
        {5'd0, 5'd0, 5'd0, 5'd0, 5'd0, 5'd0, 5'd0, 5'd0, 5'd0, 5'd0, 5'd0, 5'd0, 5'd0, 5'd0, 5'd0, 5'd0, 5'd0, 5'd0,
         5'd0, 5'd0, 5'd0, 5'd0, 5'd0, 5'd0, 5'd0, 5'd0, 5'd0, 5'd0, 5'd0, 5'd0, 5'd0, 5'd0},
        {5'd30, 5'd28, 5'd26, 5'd24, 5'd22, 5'd20, 5'd18, 5'd16, 5'd14, 5'd12, 5'd10, 5'd8, 5'd6, 5'd4, 5'd2, 5'd0,
         5'd30, 5'd28, 5'd26, 5'd24, 5'd22, 5'd20, 5'd18, 5'd16, 5'd14, 5'd12, 5'd10, 5'd8, 5'd6, 5'd4, 5'd2, 5'd0},
        {5'd27, 5'd22, 5'd17, 5'd12, 5'd7, 5'd2, 5'd29, 5'd24, 5'd19, 5'd14, 5'd9, 5'd4, 5'd31, 5'd26, 5'd21, 5'd16,
         5'd11, 5'd6, 5'd1, 5'd28, 5'd23, 5'd18, 5'd13, 5'd8, 5'd3, 5'd30, 5'd25, 5'd20, 5'd15, 5'd10, 5'd5, 5'd0},
        {5'd23, 5'd14, 5'd5, 5'd28, 5'd19, 5'd10, 5'd1, 5'd24, 5'd15, 5'd6, 5'd29, 5'd20, 5'd11, 5'd2, 5'd25, 5'd16,
         5'd7, 5'd30, 5'd21, 5'd12, 5'd3, 5'd26, 5'd17, 5'd8, 5'd31, 5'd22, 5'd13, 5'd4, 5'd27, 5'd18, 5'd9, 5'd0},
        {5'd19, 5'd6, 5'd25, 5'd12, 5'd31, 5'd18, 5'd5, 5'd24, 5'd11, 5'd30, 5'd17, 5'd4, 5'd23, 5'd10, 5'd29, 5'd16,
         5'd3, 5'd22, 5'd9, 5'd28, 5'd15, 5'd2, 5'd21, 5'd8, 5'd27, 5'd14, 5'd1, 5'd20, 5'd7, 5'd26, 5'd13, 5'd0},
        {5'd15, 5'd30, 5'd13, 5'd28, 5'd11, 5'd26, 5'd9, 5'd24, 5'd7, 5'd22, 5'd5, 5'd20, 5'd3, 5'd18, 5'd1, 5'd16,
         5'd31, 5'd14, 5'd29, 5'd12, 5'd27, 5'd10, 5'd25, 5'd8, 5'd23, 5'd6, 5'd21, 5'd4, 5'd19, 5'd2, 5'd17, 5'd0},
        {5'd11, 5'd22, 5'd1, 5'd12, 5'd23, 5'd2, 5'd13, 5'd24, 5'd3, 5'd14, 5'd25, 5'd4, 5'd15, 5'd26, 5'd5, 5'd16,
         5'd27, 5'd6, 5'd17, 5'd28, 5'd7, 5'd18, 5'd29, 5'd8, 5'd19, 5'd30, 5'd9, 5'd20, 5'd31, 5'd10, 5'd21, 5'd0},
        {5'd6, 5'd12, 5'd18, 5'd24, 5'd30, 5'd4, 5'd10, 5'd16, 5'd22, 5'd28, 5'd2, 5'd8, 5'd14, 5'd20, 5'd26, 5'd0,
         5'd6, 5'd12, 5'd18, 5'd24, 5'd30, 5'd4, 5'd10, 5'd16, 5'd22, 5'd28, 5'd2, 5'd8, 5'd14, 5'd20, 5'd26, 5'd0},
        {5'd0, 5'd0, 5'd0, 5'd0, 5'd0, 5'd0, 5'd0, 5'd0, 5'd0, 5'd0, 5'd0, 5'd0, 5'd0, 5'd0, 5'd0, 5'd0, 5'd0, 5'd0,
         5'd0, 5'd0, 5'd0, 5'd0, 5'd0, 5'd0, 5'd0, 5'd0, 5'd0, 5'd0, 5'd0, 5'd0, 5'd0, 5'd0}

    };

    iIdx_delta_tab = {
        {1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1, //[0]
         1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1},
        {1'b0, 1'b1, 1'b1, 1'b1, 1'b1, 1'b0, 1'b1, 1'b1, 1'b1, 1'b1, 1'b0, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1, //[1]
         1'b0, 1'b1, 1'b1, 1'b1, 1'b1, 1'b0, 1'b1, 1'b1, 1'b1, 1'b1, 1'b0, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1},
        {1'b0, 1'b1, 1'b0, 1'b1, 1'b1, 1'b0, 1'b1, 1'b1, 1'b0, 1'b1, 1'b1, 1'b0, 1'b1, 1'b1, 1'b0, 1'b1, //[2]
         1'b1, 1'b0, 1'b1, 1'b1, 1'b0, 1'b1, 1'b1, 1'b0, 1'b1, 1'b1, 1'b0, 1'b1, 1'b1, 1'b0, 1'b1, 1'b1},
        {1'b0, 1'b1, 1'b0, 1'b1, 1'b0, 1'b1, 1'b0, 1'b1, 1'b0, 1'b1, 1'b0, 1'b1, 1'b0, 1'b1, 1'b0, 1'b1, //[3]
         1'b1, 1'b0, 1'b1, 1'b0, 1'b1, 1'b0, 1'b1, 1'b0, 1'b1, 1'b0, 1'b1, 1'b0, 1'b1, 1'b0, 1'b1, 1'b1},
        {1'b0, 1'b0, 1'b1, 1'b0, 1'b1, 1'b0, 1'b0, 1'b1, 1'b0, 1'b1, 1'b0, 1'b0, 1'b1, 1'b0, 1'b1, 1'b0, //[4]
         1'b0, 1'b1, 1'b0, 1'b1, 1'b0, 1'b0, 1'b1, 1'b0, 1'b1, 1'b0, 1'b0, 1'b1, 1'b0, 1'b1, 1'b0, 1'b1},
        {1'b0, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 1'b0, 1'b1, 1'b0, //[5]
         1'b0, 1'b1, 1'b0, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 1'b1},
        {1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 1'b0,//[6]
         1'b0, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b1},
        {1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b1,//[7]
         1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b1},
        {1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0,//[8]
         1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0},
        {1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0,//[9]
        1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0},
        {1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 1'b0,//[10]
         1'b0, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0},
        {1'b0, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 1'b0, 1'b1, 1'b0,//[11]
         1'b0, 1'b1, 1'b0, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 1'b0},
        {1'b0, 1'b0, 1'b1, 1'b0, 1'b1, 1'b0, 1'b0, 1'b1, 1'b0, 1'b1, 1'b0, 1'b0, 1'b1, 1'b0, 1'b1, 1'b0,//[12]
         1'b0, 1'b1, 1'b0, 1'b1, 1'b0, 1'b0, 1'b1, 1'b0, 1'b1, 1'b0, 1'b0, 1'b1, 1'b0, 1'b1, 1'b0, 1'b0},
        {1'b0, 1'b1, 1'b0, 1'b1, 1'b0, 1'b1, 1'b0, 1'b1, 1'b0, 1'b1, 1'b0, 1'b1, 1'b0, 1'b1, 1'b0, 1'b1,//[13]
         1'b1, 1'b0, 1'b1, 1'b0, 1'b1, 1'b0, 1'b1, 1'b0, 1'b1, 1'b0, 1'b1, 1'b0, 1'b1, 1'b0, 1'b1, 1'b0},
        {1'b0, 1'b1, 1'b0, 1'b1, 1'b1, 1'b0, 1'b1, 1'b1, 1'b0, 1'b1, 1'b1, 1'b0, 1'b1, 1'b1, 1'b0, 1'b1,//[14]
         1'b1, 1'b0, 1'b1, 1'b1, 1'b0, 1'b1, 1'b1, 1'b0, 1'b1, 1'b1, 1'b0, 1'b1, 1'b1, 1'b0, 1'b1, 1'b0},
        {1'b0, 1'b1, 1'b1, 1'b1, 1'b1, 1'b0, 1'b1, 1'b1, 1'b1, 1'b1, 1'b0, 1'b1, 1'b1, 1'b1, 1'b1, 1'b0,//[15]
         1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 1'b0, 1'b1, 1'b1, 1'b1, 1'b1, 1'b0, 1'b1, 1'b1, 1'b1, 1'b1, 1'b0},
        {1'b0, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1,//[16]
         1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1}


    };

end

generate
    for (i=0;i<16;i++)
    begin: accum_label
        multacc #(7, 9, 24) accum_pred
        (
            .clk(clk),
            .rst(accum_rst),
            .en(1'b1),
            .a( {1'b0,accum_a[i]}),
            .b({1'b0,accum_b[i]}),
            .p(accum_p[i])
        );
    end
endgenerate

reg  [ 4:0]         operand1; //nTbS-1-x
reg  [ 4:0]         operand2; //nTbS-1-y
reg  [ 7:0]         ptop_ntbs;
reg  [ 7:0]         pleft_ntbs;

generate
    for (i=0;i<4;i++)
    begin: accum_io_label
        always @(posedge clk)
        begin
            if (intra_predmode == `INTRA_PLANAR) begin
                if (phase == 1) begin
                    accum_a[4*i  ]  <= operand1;
                    accum_b[4*i  ]  <= pleft[i];
                    accum_a[4*i+1]  <= operand1-1;
                    accum_b[4*i+1]  <= pleft[i];
                    accum_a[4*i+2]  <= operand1-2;
                    accum_b[4*i+2]  <= pleft[i];
                    accum_a[4*i+3]  <= operand1-3;
                    accum_b[4*i+3]  <= pleft[i];
                end else if (phase == 2) begin
                    accum_a[4*i  ]  <= x+1;
                    accum_b[4*i  ]  <= ptop_ntbs;
                    accum_a[4*i+1]  <= x+2;
                    accum_b[4*i+1]  <= ptop_ntbs;
                    accum_a[4*i+2]  <= x+3;
                    accum_b[4*i+2]  <= ptop_ntbs;
                    accum_a[4*i+3]  <= x+4;
                    accum_b[4*i+3]  <= ptop_ntbs;

                end else if (phase == 3) begin
                    accum_a[4*i  ]  <= operand2-i;
                    accum_b[4*i  ]  <= ptop[0];
                    accum_a[4*i+1]  <= operand2-i;
                    accum_b[4*i+1]  <= ptop[1];
                    accum_a[4*i+2]  <= operand2-i;
                    accum_b[4*i+2]  <= ptop[2];
                    accum_a[4*i+3]  <= operand2-i;
                    accum_b[4*i+3]  <= ptop[3];


                end else if (phase == 4)  begin
                    accum_a[4*i  ]  <= y+1+i;
                    accum_b[4*i  ]  <= pleft_ntbs;
                    accum_a[4*i+1]  <= y+1+i;
                    accum_b[4*i+1]  <= pleft_ntbs;
                    accum_a[4*i+2]  <= y+1+i;
                    accum_b[4*i+2]  <= pleft_ntbs;
                    accum_a[4*i+3]  <= y+1+i;
                    accum_b[4*i+3]  <= pleft_ntbs;
                end else begin

                    accum_a[4*i  ]  <= 0;
                    accum_b[4*i  ]  <= 0;
                    accum_a[4*i+1]  <= 0;
                    accum_b[4*i+1]  <= 0;
                    accum_a[4*i+2]  <= 0;
                    accum_b[4*i+2]  <= 0;
                    accum_a[4*i+3]  <= 0;
                    accum_b[4*i+3]  <= 0;
                end
            end else if (intra_predmode != `INTRA_DC) begin //angular

                if (stage == 2) begin
                    if (pick_ref==ref_pick_partial_top||pick_ref==ref_pick_left) begin //纵向
                        accum_a[4*i  ]  <= 32-iFact_idx[0];
                        accum_a[4*i+1]  <= 32-iFact_idx[1];
                        accum_a[4*i+2]  <= 32-iFact_idx[2];
                        accum_a[4*i+3]  <= 32-iFact_idx[3];

                        accum_b[4*i  ]  <= ref4[0][i];
                        accum_b[4*i+1]  <= ref4[1][i];
                        accum_b[4*i+2]  <= ref4[2][i];
                        accum_b[4*i+3]  <= ref4[3][i];
                    end else begin //横向
                        accum_a[4*i  ]  <= 32-iFact_idx[i];
                        accum_a[4*i+1]  <= 32-iFact_idx[i];
                        accum_a[4*i+2]  <= 32-iFact_idx[i];
                        accum_a[4*i+3]  <= 32-iFact_idx[i];

                        accum_b[4*i  ]  <= ref4[i][0];
                        accum_b[4*i+1]  <= ref4[i][1];
                        accum_b[4*i+2]  <= ref4[i][2];
                        accum_b[4*i+3]  <= ref4[i][3];
                    end
                end else if (stage == 3) begin
                    if (pick_ref==ref_pick_partial_top||pick_ref==ref_pick_left) begin //纵向
                        accum_a[4*i  ]  <= iFact_idx[0];
                        accum_a[4*i+1]  <= iFact_idx[1];
                        accum_a[4*i+2]  <= iFact_idx[2];
                        accum_a[4*i+3]  <= iFact_idx[3];

                        accum_b[4*i  ]  <= intra_predmode==2?0:ref4[0][i+1];
                        accum_b[4*i+1]  <= intra_predmode==2?0:ref4[1][i+1];
                        accum_b[4*i+2]  <= intra_predmode==2?0:ref4[2][i+1];
                        accum_b[4*i+3]  <= intra_predmode==2?0:ref4[3][i+1];
                    end else begin //横向
                        accum_a[4*i  ]  <= iFact_idx[i];
                        accum_a[4*i+1]  <= iFact_idx[i];
                        accum_a[4*i+2]  <= iFact_idx[i];
                        accum_a[4*i+3]  <= iFact_idx[i];

                        accum_b[4*i  ]  <= intra_predmode==34?0:ref4[i][1];
                        accum_b[4*i+1]  <= intra_predmode==34?0:ref4[i][2];
                        accum_b[4*i+2]  <= intra_predmode==34?0:ref4[i][3];
                        accum_b[4*i+3]  <= intra_predmode==34?0:ref4[i][4];
                    end
                end


            end else begin
                    accum_a[4*i  ]  <= 0;
                    accum_b[4*i  ]  <= 0;
                    accum_a[4*i+1]  <= 0;
                    accum_b[4*i+1]  <= 0;
                    accum_a[4*i+2]  <= 0;
                    accum_b[4*i+2]  <= 0;
                    accum_a[4*i+3]  <= 0;
                    accum_b[4*i+3]  <= 0;
            end
        end
    end
endgenerate

reg            store_stage;
reg            kick_store;
reg            store_done;
reg  [ 5:0]    store_x;
reg  [ 5:0]    store_y;
reg  [ 4:0]    x_to_store;
reg  [ 4:0]    y_to_store;
reg  [ 1:0]    store_i;
reg            last4x4_in_row;

always @ (posedge clk)
if (global_rst) begin
    o_pred_done_y         <= 7'b1111111;
    dram_pred_we          <= {64{1'b0}};
end else if (rst) begin
    store_stage           <= 0;
    store_done            <= 1;
    dram_pred_we          <= {64{1'b0}};
    o_pred_done_y         <= 7'b1111111;
end else begin
    if (store_stage == 0 && kick_store) begin
        store_x           <= x_to_store+xTu;
        store_y           <= y_to_store+yTu;
        store_i           <= 0;
        store_stage       <= 1;
        store_done        <= 0;
        result4x4_copy    <= result4x4;
        last4x4_in_row    <= x_to_store[4:2] == trafoSize_bit5to2_minus1;
        if (`log_p && i_slice_num>=`slice_begin && i_slice_num<=`slice_end) begin
            $fdisplay(fd_log, "x %0d y %0d:%0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d",
                x_to_store,y_to_store,
                result4x4[0],result4x4[1],result4x4[2],result4x4[3],
                result4x4[4],result4x4[5],result4x4[6],result4x4[7],
                result4x4[8],result4x4[9],result4x4[10],result4x4[11],
                result4x4[12],result4x4[13],result4x4[14],result4x4[15]);
        end
    end
    if (store_stage == 1) begin
        store_i           <= store_i+1;
        store_y           <= store_y+1;
        result4x4_copy    <= {32'd0,result4x4_copy[15:4]};

        case (store_x[5:2])
            0: begin
                dram_pred_din[3:0]          <= result4x4_copy[3:0];
                dram_pred_we[3:0]           <= {4{1'b1}};
                dram_pred_addr[3:0]         <= {4{store_y}};
            end
            1: begin
                dram_pred_din[7:4]          <= result4x4_copy[3:0];
                dram_pred_we[7:4]           <= {4{1'b1}};
                dram_pred_addr[7:4]         <= {4{store_y}};
            end
            2: begin
                dram_pred_din[11:8]         <= result4x4_copy[3:0];
                dram_pred_we[11:8]          <= {4{1'b1}};
                dram_pred_addr[11:8]        <= {4{store_y}};
            end
            3: begin
                dram_pred_din[15:12]        <= result4x4_copy[3:0];
                dram_pred_we[15:12]         <= {4{1'b1}};
                dram_pred_addr[15:12]       <= {4{store_y}};
            end
            4: begin
                dram_pred_din[19:16]        <= result4x4_copy[3:0];
                dram_pred_we[19:16]         <= {4{1'b1}};
                dram_pred_addr[19:16]       <= {4{store_y}};
            end
            5: begin
                dram_pred_din[23:20]        <= result4x4_copy[3:0];
                dram_pred_we[23:20]         <= {4{1'b1}};
                dram_pred_addr[23:20]       <= {4{store_y}};
            end
            6: begin
                dram_pred_din[27:24]        <= result4x4_copy[3:0];
                dram_pred_we[27:24]         <= {4{1'b1}};
                dram_pred_addr[27:24]       <= {4{store_y}};
            end
            7: begin
                dram_pred_din[31:28]        <= result4x4_copy[3:0];
                dram_pred_we[31:28]         <= {4{1'b1}};
                dram_pred_addr[31:28]       <= {4{store_y}};
            end
            8: begin
                dram_pred_din[35:32]          <= result4x4_copy[3:0];
                dram_pred_we[35:32]           <= {4{1'b1}};
                dram_pred_addr[35:32]         <= {4{store_y}};
            end
            9: begin
                dram_pred_din[39:36]          <= result4x4_copy[3:0];
                dram_pred_we[39:36]           <= {4{1'b1}};
                dram_pred_addr[39:36]         <= {4{store_y}};
            end
            10: begin
                dram_pred_din[43:40]         <= result4x4_copy[3:0];
                dram_pred_we[43:40]          <= {4{1'b1}};
                dram_pred_addr[43:40]        <= {4{store_y}};
            end
            11: begin
                dram_pred_din[47:44]        <= result4x4_copy[3:0];
                dram_pred_we[47:44]         <= {4{1'b1}};
                dram_pred_addr[47:44]       <= {4{store_y}};
            end
            12: begin
                dram_pred_din[51:48]        <= result4x4_copy[3:0];
                dram_pred_we[51:48]         <= {4{1'b1}};
                dram_pred_addr[51:48]       <= {4{store_y}};
            end
            13: begin
                dram_pred_din[55:52]        <= result4x4_copy[3:0];
                dram_pred_we[55:52]         <= {4{1'b1}};
                dram_pred_addr[55:52]       <= {4{store_y}};
            end
            14: begin
                dram_pred_din[59:56]        <= result4x4_copy[3:0];
                dram_pred_we[59:56]         <= {4{1'b1}};
                dram_pred_addr[59:56]       <= {4{store_y}};
            end
            15: begin
                dram_pred_din[63:60]        <= result4x4_copy[3:0];
                dram_pred_we[63:60]         <= {4{1'b1}};
                dram_pred_addr[63:60]       <= {4{store_y}};
            end
        endcase
        if (last4x4_in_row)
            o_pred_done_y                   <= {1'b0,store_y};

        if (store_i == 3) begin
            store_done    <= 1;
            store_stage   <= 0;
            store_i       <= 0;
        end
    end
end

always @ (posedge clk)
if (global_rst) begin
    o_intra_pred_state       <= `intra_pred_end;
    kick_store               <= 0;
end else if (rst) begin
    x0                       <= i_x0;
    y0                       <= i_y0;
    xTu                      <= i_xTu;
    yTu                      <= i_yTu;
    x                        <= 0;
    y                        <= 0;

    dc_sum                   <= i_trafoSize;
    intra_predmode           <= i_intra_predmode;
    log2TrafoSize            <= i_log2TrafoSize;
    trafoSize                <= i_trafoSize;
    trafoSize_bit5to2_minus1 <= i_trafoSize[5:2]-1;
    operand1                 <= i_trafoSize-1;
    operand2                 <= i_trafoSize-1;

    cIdx                     <= i_cIdx;
    case (i_yTu[5:2])
    0: pleft   <= i_line_buf_left;
    1: pleft   <= {{4{8'd0}},i_line_buf_left[63:4]};
    2: pleft   <= {{8{8'd0}},i_line_buf_left[63:8]};
    3: pleft   <= {{12{8'd0}},i_line_buf_left[63:12]};
    4: pleft   <= {{16{8'd0}},i_line_buf_left[63:16]};
    5: pleft   <= {{20{8'd0}},i_line_buf_left[63:20]};
    6: pleft   <= {{24{8'd0}},i_line_buf_left[63:24]};
    7: pleft   <= {{28{8'd0}},i_line_buf_left[63:28]};
    8: pleft   <= {{32{8'd0}},i_line_buf_left[63:32]};
    9: pleft   <= {{36{8'd0}},i_line_buf_left[63:36]};
    10: pleft   <= {{40{8'd0}},i_line_buf_left[63:40]};
    11: pleft   <= {{44{8'd0}},i_line_buf_left[63:44]};
    12: pleft   <= {{48{8'd0}},i_line_buf_left[63:48]};
    13: pleft   <= {{52{8'd0}},i_line_buf_left[63:52]};
    14: pleft   <= {{56{8'd0}},i_line_buf_left[63:56]};
    15: pleft   <= {{60{8'd0}},i_line_buf_left[63:60]};
    endcase

    case (i_xTu[5:2])
    0: ptop   <= i_line_buf_top[63:0];
    1: ptop   <= i_line_buf_top[67:4];
    2: ptop   <= i_line_buf_top[71:8];
    3: ptop   <= i_line_buf_top[75:12];
    4: ptop   <= i_line_buf_top[79:16];
    5: ptop   <= i_line_buf_top[83:20];
    6: ptop   <= i_line_buf_top[87:24];
    7: ptop   <= i_line_buf_top[91:28];
    8: ptop   <= i_line_buf_top[95:32];
    9: ptop   <= {{4{8'd0}},i_line_buf_top[95:36]};
    10: ptop   <= {{8{8'd0}},i_line_buf_top[95:40]};
    11: ptop   <= {{12{8'd0}},i_line_buf_top[95:44]};
    12: ptop   <= {{16{8'd0}},i_line_buf_top[95:48]};
    13: ptop   <= {{20{8'd0}},i_line_buf_top[95:52]};
    14: ptop   <= {{24{8'd0}},i_line_buf_top[95:56]};
    15: ptop   <= {{28{8'd0}},i_line_buf_top[95:60]};
    endcase

    leftup                   <= i_leftup[i_yTu[5:2]];
    pleft_tmp                <= 14'd0;
    ptop_tmp                 <= 14'd0;
    pleft_63                 <= 8'd0;
    ptop_63                  <= 8'd0;

    if (i_log2TrafoSize==5)
        intraHorVerDisThres  <= 0;
    else if (i_log2TrafoSize==4)
        intraHorVerDisThres  <= 1;
    else
        intraHorVerDisThres  <= 7;
    phase                    <= 0;
    tier                     <= 0;
    filtered                 <= 0;
    stage                    <= 0;

    case (i_intra_predmode)
    11,12,13,14,15,16,17       : ref_pick_idx  <= ref_partial_pick_tab[i_intra_predmode-11];
    18,19,20,21,22,23,24,25    : ref_pick_idx  <= ref_partial_pick_tab[25-i_intra_predmode];
    default                    : ref_pick_idx  <= ref_partial_pick_tab[7];
    endcase

    case (i_intra_predmode)
    2,3,4,5,6,7,8,9,10         : pick_ref  <= ref_pick_left;
    11,12,13,14,15,16,17       : pick_ref  <= ref_pick_partial_top;
    18,19,20,21,22,23,24,25    : pick_ref  <= ref_pick_partial_left;
    26,27,28,29,30,31,32,33,34 : pick_ref  <= ref_pick_top;
    default                    : pick_ref  <= ref_pick_top;
    endcase

    if (i_intra_predmode<=18)
        iIdx_delta_idx  <= iIdx_delta_tab[i_intra_predmode-2];
    else
        iIdx_delta_idx  <= iIdx_delta_tab[34-i_intra_predmode];

    if (i_intra_predmode <= 18)
        iFact_idx            <= iFact_tab[i_intra_predmode-2];
    else
        iFact_idx            <= iFact_tab[34-i_intra_predmode];

    if (`log_p &&i_slice_num>=`slice_begin && i_slice_num<=`slice_end)
        $fdisplay(fd_log, "intrapred xTbY %0d yTbY %0d cIdx 0 log2TrafoSize %0d slice_num %0d",
                   {i_x0[`max_x_bits-1:6],i_xTu},{i_y0[`max_y_bits-1:6],i_yTu},i_log2TrafoSize,i_slice_num);

    o_intra_pred_state       <= `intra_pred_wait_nb;
end else if (en) begin
    case (o_intra_pred_state)
    `intra_pred_wait_nb:
        if (i_avail_done) begin
            left_avail               <= i_left_avail;
            up_avail                 <= i_up_avail;
            o_intra_pred_state       <= `intra_pred_substitute1;
        end
    `intra_pred_substitute1://0x3
        begin
            if (left_avail == 0&&up_avail == 0) begin
                leftup               <= 8'd128;
                pleft                <= {64{8'd128}};
                ptop                 <= {64{8'd128}};
                pleft_tmp_init       <= 8224;
                ptop_tmp_init        <= 8096;
                o_intra_pred_state   <= `intra_pred_smooth_or_not;
            end else begin
                //pleft,ptop已在reset时拷贝好,只需处理unavail
                if (trafoSize[5] == 1) begin
                    casez (avail_sz_32x32)
                        17'b0_1???_????_????_???? : pleft[63:56] <= {8{pleft[55]}};
                        17'b0_01??_????_????_???? : pleft[63:56] <= {8{pleft[47]}};
                        17'b0_001?_????_????_???? : pleft[63:56] <= {8{pleft[39]}};
                        17'b0_0001_????_????_???? : pleft[63:56] <= {8{pleft[31]}};
                        17'b0_0000_1???_????_???? : pleft[63:56] <= {8{pleft[23]}};
                        17'b0_0000_01??_????_???? : pleft[63:56] <= {8{pleft[15]}};
                        17'b0_0000_001?_????_???? : pleft[63:56] <= {8{pleft[7]}};
                        17'b0_0000_0001_????_???? : pleft[63:56] <= {8{leftup}};
                        17'b0_0000_0000_1???_???? : pleft[63:56] <= {8{ptop[0]}};
                        17'b0_0000_0000_01??_???? : pleft[63:56] <= {8{ptop[8]}};
                        17'b0_0000_0000_001?_???? : pleft[63:56] <= {8{ptop[16]}};
                        17'b0_0000_0000_0001_???? : pleft[63:56] <= {8{ptop[24]}};
                        17'b0_0000_0000_0000_1??? : pleft[63:56] <= {8{ptop[32]}};
                        17'b0_0000_0000_0000_01?? : pleft[63:56] <= {8{ptop[40]}};
                        17'b0_0000_0000_0000_001? : pleft[63:56] <= {8{ptop[48]}};
                        17'b0_0000_0000_0000_0001 : pleft[63:56] <= {8{ptop[56]}};
                        default                   : pleft[63:56] <= pleft[63:56];
                    endcase
                    left_avail[8]                                <= 1;
                end else if (trafoSize[4] == 1) begin
                    casez (avail_sz_16x16)
                        9'b0_1???_???? : pleft[31:24] <= {8{pleft[23]}};
                        9'b0_01??_???? : pleft[31:24] <= {8{pleft[15]}};
                        9'b0_001?_???? : pleft[31:24] <= {8{pleft[7]}};
                        9'b0_0001_???? : pleft[31:24] <= {8{leftup}};
                        9'b0_0000_1??? : pleft[31:24] <= {8{ptop[0]}};
                        9'b0_0000_01?? : pleft[31:24] <= {8{ptop[8]}};
                        9'b0_0000_001? : pleft[31:24] <= {8{ptop[16]}};
                        9'b0_0000_0001 : pleft[31:24] <= {8{ptop[24]}};
                        default        : pleft[31:24] <= pleft[31:24];
                   endcase
                   left_avail[4]               <= 1;
                end else if (trafoSize[3] == 1) begin
                    casez (avail_sz_8x8_4x4)
                        5'b0_1??? : pleft[15:8] <= {8{pleft[7]}};
                        5'b0_01?? : pleft[15:8] <= {8{leftup}};
                        5'b0_001? : pleft[15:8] <= {8{ptop[0]}};
                        5'b0_0001 : pleft[15:8] <= {8{ptop[8]}};
                        default   : pleft[15:8] <= pleft[15:8];
                   endcase
                end else begin
                    casez (avail_sz_8x8_4x4)
                        5'b0_1??? : pleft[7:4] <= {4{pleft[3]}};
                        5'b0_01?? : pleft[7:4] <= {4{leftup}};
                        5'b0_001? : pleft[7:4] <= {4{ptop[0]}};
                        5'b0_0001 : pleft[7:4] <= {4{ptop[4]}};
                        default   : pleft[7:4] <= pleft[7:4];
                   endcase
                end
            o_intra_pred_state           <= `intra_pred_substitute2;
            end
            sub_i                        <= trafoSize[5]?7:3;
            minDistVerHor                <= abs_intramode_minus26<abs_intramode_minus10?
                                             abs_intramode_minus26:abs_intramode_minus10;


        end

    //substitute第二步
    //avail: 0001111001111111,可以左移3个0，再左移4个1，代码太复杂
    //8x8,4x4省不了多少时间，32x32,16x16也无所谓省这点时间
    `intra_pred_substitute2://0x4 left左移0
        begin
            if (trafoSize[5] == 1||trafoSize[4] == 1) begin
                if (sub_i == 0) begin
                    leftup                      <= leftup_w;
                    o_intra_pred_state          <= `intra_pred_substitute3;
                end else begin
                    pleft[55:0]                 <= pleft_w[55:0];
                    sub_i                       <= sub_i-1;
                    left_avail[sub_i]           <= 1;
                end
            end else if (trafoSize[3] == 1) begin
                case (left_avail[1:0])
                    2'b00: begin leftup         <= pleft[8]; pleft[7:0]  <= {8{pleft[8]}}; end
                    2'b01: begin pleft[7:0]     <= {8{pleft[8]}}; end
                    2'b10: begin leftup         <= pleft[0];       end
                    2'b11: begin                                   end
                endcase
                o_intra_pred_state              <= `intra_pred_substitute3;
            end else begin
                case (left_avail[1:0])
                    2'b00: begin leftup         <= pleft[4]; pleft[3:0]  <= {4{pleft[4]}}; end
                    2'b01: begin pleft[3:0]     <= {4{pleft[4]}}; end
                    2'b10: begin leftup         <= pleft[0];       end
                    2'b11: begin                                   end
                endcase
                o_intra_pred_state              <= `intra_pred_substitute3;
            end
        end

    `intra_pred_substitute3://0x5
        begin
            pleft_tmp_init                      <= {leftup,6'd0}-leftup+pleft[63]+32;
            ptop_tmp_init                       <= {leftup,6'd0}-leftup+32; //ptop[63]还未确定
            if (trafoSize[5] == 1||trafoSize[4] == 1) begin
                if (sub_i == (trafoSize[5]?7:3)) begin
                    ptop                        <= ptop_w;
                    o_intra_pred_state          <= `intra_pred_smooth_or_not;
                end else begin
                    ptop                        <= ptop_w;
                    up_avail[sub_i]             <= 1;
                    sub_i                       <= sub_i+1;
                end
            end else if (trafoSize[3] == 1) begin
                case (up_avail[1:0])
                    2'b00: begin ptop[7:0]      <= {8{leftup}}; ptop[15:8]  <= {8{leftup}};  end
                    2'b01: begin ptop[15:8]     <= {8{ptop[7]}}; end
                    2'b10: begin ptop[7:0]      <= {8{leftup}};  end
                    2'b11: begin                               end
                endcase
                o_intra_pred_state              <= `intra_pred_smooth_or_not;
            end else begin
                case (up_avail[1:0])
                    2'b00: begin ptop[7:0]      <= {8{leftup}};  end
                    2'b01: begin ptop[7:4]      <= {4{ptop[3]}}; end
                    2'b10: begin ptop[3:0]      <= {4{leftup}};  end
                    2'b11: begin                             end
                endcase
                o_intra_pred_state              <= `intra_pred_smooth_or_not;
            end
        end

     `intra_pred_smooth_or_not: begin//6
        if (`log_p &&i_slice_num>=`slice_begin && i_slice_num<=`slice_end) begin
            $fdisplay(fd_log, "leftup:          %0d", leftup);
            if (log2TrafoSize==5) begin
                $fdisplay(fd_log, "left:            %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d",
                          pleft[0],pleft[1],pleft[2],pleft[3],pleft[4],pleft[5],pleft[6],pleft[7],
                          pleft[8],pleft[9],pleft[10],pleft[11],pleft[12],pleft[13],pleft[14],pleft[15],
                          pleft[16],pleft[17],pleft[18],pleft[19],pleft[20],pleft[21],pleft[22],pleft[23],
                          pleft[24],pleft[25],pleft[26],pleft[27],pleft[28],pleft[29],pleft[30],pleft[31]);
                $fdisplay(fd_log, "%0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d",
                          pleft[32],pleft[33],pleft[34],pleft[35],pleft[36],pleft[37],pleft[38],pleft[39],
                          pleft[40],pleft[41],pleft[42],pleft[43],pleft[44],pleft[45],pleft[46],pleft[47],
                          pleft[48],pleft[49],pleft[50],pleft[51],pleft[52],pleft[53],pleft[54],pleft[55],
                          pleft[56],pleft[57],pleft[58],pleft[59],pleft[60],pleft[61],pleft[62],pleft[63]);
                $fdisplay(fd_log, "top:             %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d",
                          ptop[0],ptop[1],ptop[2],ptop[3],ptop[4],ptop[5],ptop[6],ptop[7],
                          ptop[8],ptop[9],ptop[10],ptop[11],ptop[12],ptop[13],ptop[14],ptop[15],
                          ptop[16],ptop[17],ptop[18],ptop[19],ptop[20],ptop[21],ptop[22],ptop[23],
                          ptop[24],ptop[25],ptop[26],ptop[27],ptop[28],ptop[29],ptop[30],ptop[31]);
                $fdisplay(fd_log, "%0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d",
                          ptop[32],ptop[33],ptop[34],ptop[35],ptop[36],ptop[37],ptop[38],ptop[39],
                          ptop[40],ptop[41],ptop[42],ptop[43],ptop[44],ptop[45],ptop[46],ptop[47],
                          ptop[48],ptop[49],ptop[50],ptop[51],ptop[52],ptop[53],ptop[54],ptop[55],
                          ptop[56],ptop[57],ptop[58],ptop[59],ptop[60],ptop[61],ptop[62],ptop[63]);
            end else if (log2TrafoSize==4) begin
                $fdisplay(fd_log, "left:            %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d",
                          pleft[0],pleft[1],pleft[2],pleft[3],pleft[4],pleft[5],pleft[6],pleft[7],
                          pleft[8],pleft[9],pleft[10],pleft[11],pleft[12],pleft[13],pleft[14],pleft[15],
                          pleft[16],pleft[17],pleft[18],pleft[19],pleft[20],pleft[21],pleft[22],pleft[23],
                          pleft[24],pleft[25],pleft[26],pleft[27],pleft[28],pleft[29],pleft[30],pleft[31]);
                $fdisplay(fd_log, "top:             %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d",
                          ptop[0],ptop[1],ptop[2],ptop[3],ptop[4],ptop[5],ptop[6],ptop[7],
                          ptop[8],ptop[9],ptop[10],ptop[11],ptop[12],ptop[13],ptop[14],ptop[15],
                          ptop[16],ptop[17],ptop[18],ptop[19],ptop[20],ptop[21],ptop[22],ptop[23],
                          ptop[24],ptop[25],ptop[26],ptop[27],ptop[28],ptop[29],ptop[30],ptop[31]);
            end else if (log2TrafoSize==3) begin
                $fdisplay(fd_log, "left:            %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d",
                          pleft[0],pleft[1],pleft[2],pleft[3],pleft[4],pleft[5],pleft[6],pleft[7],
                          pleft[8],pleft[9],pleft[10],pleft[11],pleft[12],pleft[13],pleft[14],pleft[15]);
                $fdisplay(fd_log, "top:             %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d",
                          ptop[0],ptop[1],ptop[2],ptop[3],ptop[4],ptop[5],ptop[6],ptop[7],
                          ptop[8],ptop[9],ptop[10],ptop[11],ptop[12],ptop[13],ptop[14],ptop[15]);
            end else begin
                $fdisplay(fd_log, "left:            %0d %0d %0d %0d %0d %0d %0d %0d",
                          pleft[0],pleft[1],pleft[2],pleft[3],pleft[4],pleft[5],pleft[6],pleft[7]);
                $fdisplay(fd_log, "top:             %0d %0d %0d %0d %0d %0d %0d %0d",
                          ptop[0],ptop[1],ptop[2],ptop[3],ptop[4],ptop[5],ptop[6],ptop[7]);
            end
        end

         //从mark5提上来
         pleft_tmp                        <= pleft_tmp_init;
         ptop_tmp                         <= ptop_tmp_init+ptop[63];
         ptop_63                          <= ptop[63];
         pleft_63                         <= pleft[63];

         if (log2TrafoSize != 2 && intra_predmode != `INTRA_DC &&
             minDistVerHor > intraHorVerDisThres) begin
             filter_i                     <= 0;
             filtered                     <= 1;

             if (i_strong_intra_smoothing_enabled_flag && log2TrafoSize == 5 &&
                 strong_smooth_cond0 && strong_smooth_cond1) begin
                 //mark5
                 o_intra_pred_state       <= `intra_pred_strong_smooth;
             end else begin
                 o_intra_pred_state       <= `intra_pred_normal_smooth;
             end
         end else begin
            accum_rst                     <= 1;
            if (intra_predmode == `INTRA_DC)
                o_intra_pred_state        <= `intra_pred_dc;
            else if (intra_predmode == `INTRA_PLANAR)
                o_intra_pred_state        <= `intra_pred_planar;
            else
                o_intra_pred_state        <= `intra_pred_angular;
         end
     end

    `intra_pred_strong_smooth://7
        begin
            filter_i                      <= filter_i+1;

            pleft_tmp                     <= pleft_tmp-leftup+pleft_63;
            ptop_tmp                      <= ptop_tmp-leftup+ptop_63;

            if (filter_i==62) begin
                pleft                     <= {pleft_63,pleft_tmp[13:6],pleft[63:2]};
                ptop                      <= {ptop_63,ptop_tmp[13:6],ptop[63:2]};
                accum_rst                 <= 1;
                if (intra_predmode == `INTRA_DC)
                    o_intra_pred_state    <= `intra_pred_dc;
                else if (intra_predmode == `INTRA_PLANAR)
                    o_intra_pred_state    <= `intra_pred_planar;
                else
                    o_intra_pred_state    <= `intra_pred_angular;

            end else begin
                pleft                     <= {pleft_tmp[13:6],pleft[63:1]};
                ptop                      <= {ptop_tmp[13:6],ptop[63:1]};
            end
        end

    `intra_pred_normal_smooth://8
        begin
            leftup                        <= (pleft[0]+{leftup,1'b0}+ptop[0]+2)>>2;
            pleft[0]                      <= (pleft[1]+{pleft[0],1'b0}+leftup+2)>>2;
            ptop[0]                       <= (ptop[1]+{ptop[0],1'b0}+leftup+2)>>2;
            pleft[62:1]                   <= pFleft_w[62:1];
            ptop[62:1]                    <= pFtop_w[62:1];
            //pleft[2*nTbS-1],ptop[2*nTbS-1]保持不变
            if (trafoSize[4] == 1) begin
                pleft[31]                 <= pleft[31];
                ptop[31]                  <= ptop[31];
            end else if (trafoSize[3] == 1) begin
                pleft[15]                 <= pleft[15];
                ptop[15]                  <= ptop[15];
            end
            accum_rst                     <= 1;
            if (intra_predmode == `INTRA_DC)
                o_intra_pred_state        <= `intra_pred_dc;
            else if (intra_predmode == `INTRA_PLANAR)
                o_intra_pred_state        <= `intra_pred_planar;
            else
                o_intra_pred_state        <= `intra_pred_angular;
        end

    `intra_pred_planar://9
        begin
            //每行5个周期(phase)
            phase                                 <= phase+1;
            if (phase == 0) begin
                accum_rst                         <= 1;
                pleft_bk                          <= pleft[31:0];
                ptop_bk                           <= ptop[31:0];
                valid                             <= 0;
                case (log2TrafoSize)
                    2: begin pleft_ntbs <= pleft[4]; ptop_ntbs <= ptop[4]; end
                    3: begin pleft_ntbs <= pleft[8]; ptop_ntbs <= ptop[8]; end
                    4: begin pleft_ntbs <= pleft[16]; ptop_ntbs <= ptop[16]; end
                    default: begin pleft_ntbs <= pleft[32]; ptop_ntbs <= ptop[32]; end
                endcase

                kick_store                        <= 0;

            end
            if (phase == 1) begin
                accum_rst                         <= 0;
            end
            if (phase == 5) begin
                result4x4                         <= result4x4_planar_w;
                phase                             <= 1;
                kick_store                        <= 1;
                x                                 <= x+4;
                x_to_store                        <= x;
                y_to_store                        <= y;
                valid                             <= 1;
                operand1                          <= operand1-4;
                ptop[31:0]                        <= {32'd0,ptop[31:4]};
                accum_rst                         <= 1;
                if (x[4:2] == trafoSize_bit5to2_minus1) begin
                    y                             <= y+4;
                    x                             <= 0;
                    operand1                      <= trafoSize-1;
                    operand2                      <= operand2-4;
                    ptop[31:0]                    <= ptop_bk;
                    pleft[31:0]                   <= {32'd0,pleft[31:4]};
                    if (y[4:2] == trafoSize_bit5to2_minus1) begin
                        phase                     <= 6;
                    end
                end
            end
            if ((phase == 1&&valid)||phase==6) begin
                result4x4                         <= result4x4_planar_w;
                kick_store                        <= 1;
            end else begin
                kick_store                        <= 0;
            end
            if (phase == 8) begin //phase=7刚好赶上上一个store_done
                phase                             <= 8;
                if (store_done) begin
                    o_intra_pred_state            <= `intra_pred_end;
                end
            end

        end
    `intra_pred_dc://0xa
        begin
            if (stage == 0) begin//stage0计算dcVal
                dc_sum                            <= dc_sum + pleft[0]+pleft[1]+ptop[0]+ptop[1];
                sum_i                             <= 0;
                pleft_copy                        <= {16'd0,pleft[31:2]};
                ptop_copy                         <= {16'd0,ptop[31:2]};
                ptop_bk                           <= ptop[31:0];
                stage                             <= 1;
            end

            if (stage == 1) begin
                dc_sum                            <= dc_sum + pleft_copy[0]+pleft_copy[1]+ptop_copy[0]+ptop_copy[1];
                pleft_copy                        <= {16'd0,pleft_copy[31:2]};
                ptop_copy                         <= {16'd0,ptop_copy[31:2]};
                sum_i                             <= sum_i+1;
                if (sum_i == trafoSize[5:1]-2)
                    stage                         <= 2;
            end
            if (stage == 2) begin
                case (log2TrafoSize)
                    2: dcVal                      <= dc_sum[10:3];
                    3: dcVal                      <= dc_sum[11:4];
                    4: dcVal                      <= dc_sum[12:5];
                    default: dcVal                <= dc_sum[13:6];
                endcase
                stage                             <= 3;
            end
            if (stage == 3) begin //stage=1
                result4x4                         <= {16{dcVal}};
                if (x==0&&y==0&&log2TrafoSize != 5) begin
                    result4x4[0]                  <= (pleft[0]+ptop[0]+{dcVal,1'b0}+2)>>2;
                end else if (x==0&&log2TrafoSize != 5) begin
                    result4x4[0]                  <= (pleft[0]+dcVal+{dcVal,1'b0}+2)>>2;
                end else if (y==0&&log2TrafoSize != 5) begin
                    result4x4[0]                  <= (ptop[0]+dcVal+{dcVal,1'b0}+2)>>2;
                end else begin
                    result4x4[0]                  <= dcVal;
                end

                if (x==0&&log2TrafoSize != 5) begin
                    result4x4[4]                  <= (pleft[1]+dcVal+{dcVal,1'b0}+2)>>2;
                    result4x4[8]                  <= (pleft[2]+dcVal+{dcVal,1'b0}+2)>>2;
                    result4x4[12]                 <= (pleft[3]+dcVal+{dcVal,1'b0}+2)>>2;
                end else begin
                    result4x4[4]                  <= dcVal;
                    result4x4[8]                  <= dcVal;
                    result4x4[12]                 <= dcVal;
                end

                if (y==0&&log2TrafoSize != 5) begin
                    result4x4[1]                  <= (ptop[1]+dcVal+{dcVal,1'b0}+2)>>2;
                    result4x4[2]                  <= (ptop[2]+dcVal+{dcVal,1'b0}+2)>>2;
                    result4x4[3]                  <= (ptop[3]+dcVal+{dcVal,1'b0}+2)>>2;
                end else begin
                    result4x4[1]                  <= dcVal;
                    result4x4[2]                  <= dcVal;
                    result4x4[3]                  <= dcVal;
                end

                kick_store                        <= 1;
                x                                 <= x+4;
                x_to_store                        <= x;
                y_to_store                        <= y;
                ptop[31:0]                        <= {32'd0,ptop[31:4]};
                stage                             <= 4;
                if (x[4:2] == trafoSize_bit5to2_minus1) begin
                    ptop[31:0]                    <= ptop_bk;
                    pleft[31:0]                   <= {32'd0,pleft[31:4]};
                    y                             <= y+4;
                    x                             <= 0;
                    if (y[4:2] == trafoSize_bit5to2_minus1) begin
                        stage                     <= 5;
                    end
                end

            end
            //stage3 1周期就出result4x4，没必要和store并行,直接等待store结束
            if (stage == 4) begin
                kick_store                        <= 0;
                if (~kick_store&&store_done)
                    stage                         <= 3;
            end
            if (stage == 5) begin
                kick_store                        <= 0;
                if (~kick_store&&store_done)
                    o_intra_pred_state            <= `intra_pred_end;
            end
        end

    `intra_pred_angular://0xb
        begin
            if (stage == 0) begin //第一阶段填好ref
                pleft_bk                      <= pleft[31:0];
                ptop_bk                       <= ptop[31:0];
                pleft0                        <= {2'b00,pleft[0]};
                ptop0                         <= {2'b00,ptop[0]};
                if (pick_ref == ref_pick_top) begin
                    ref_r                     <= {8'd0,ptop};
                    ref_bk                    <= {8'd0,ptop};
                end else if (pick_ref == ref_pick_left) begin
                    ref_r                     <= {8'd0,pleft};
                    ref_bk                    <= {8'd0,pleft};
                end else begin
                    ref_r                     <= ref_w;
                    ref_bk                    <= ref_w;
                end
                accum_rst                     <= 1;
                stage                         <= 1;


            end

            //结果
            //a0 a1 a2 a3 a4 a5 a6 a7
            //b0 b1 b2 b3 b4 b5 b6 b7
            //c0 c1 c2 c3 c4 c5 c6 c7
            //d0 d1 d2 d3 d4 d5 d6 d7
            //e0 e1 e2 e3 e4 e5 e6 e7
            //f0 f1 f2 f3 f4 f5 f6 f7
            //g0 g1 g2 g3 g4 g5 g6 g7
            //h0 h1 h2 h3 h4 h5 h6 h7
            //横向
            //iIdx = ((y + 1) * intraPredAngle) >> 5;
            //iFact = ((y + 1) * intraPredAngle) & 31;
            //predSamples[y][x] =((32 - iFact) * ref[x + iIdx + 1] + iFact * ref[x + iIdx + 2] + 16) >> 5;
            //第一轮出a0,a1,a2,a3,b0,b1,b2,b3,c0,c1,c2,c3,d0,d1,d2,d3
            //第二轮出a4,a5,a6,a7,b4,b5,b6,b7,c4,c5,c6,c7,d4,d5,d6,d7
            //第三轮出e0,e1,e2,e3,f0,f1,f2,f3,g0,g1,g2,g3,h0,h1,h2,h3
            //第四轮出e4,e5,e6,e7,f4,f5,f6,f7,g4,g5,g6,g7,h4,h5,h6,h7
            //每向右推进4x4格，iFact是不变的，ref要右移4，因为x+iIdx+1,x前进了4
            //完成一个W*4,向下推进4格，iFact右移4，ref_bk移动delta iIdx
            //a0 a1 a2 a3 iFact[0]  4*i   4*i+1  4*i+2  4*i+3
            //b0 b1 b2 b3 iFact[1]
            //c0 c1 c2 c3 iFact[2]
            //d0 d1 d2 d3 iFact[3]
            //每个点仅需2个乘法，而不是nTbS个，

            //纵向
            //iFact[0] iFact[1] iFact[2] iFact[3]
            //a0        a1        a2       a3  
            //b0       b1        b2       b3
            //c0        c1         c2       c3
            //d0       d1        d2       d3

            //纵向
            //iIdx = ((x + 1) * intraPredAngle) >> 5;
            //iFact = ((x + 1) * intraPredAngle) & 31;
            //predSamples[y][x] =((32 - iFact) * ref[y + iIdx + 1] + iFact * ref[y + iIdx + 2] + 16) >> 5
            //第一轮出a0,a1,a2,a3,b0,b1,b2,b3,c0,c1,c2,c3,d0,d1,d2,d3
            //第二轮出e0,e1,e2,e3,f0,f1,f2,f3,g0,g1,g2,g3,h0,h1,h2,h3
            //第三轮出a4,a5,a6,a7,b4,b5,b6,b7,c4,c5,c6,c7,d4,d5,d6,d7
            //第四轮出e4,e5,e6,e7,f4,f5,f6,f7,g4,g5,g6,g7,h4,h5,h6,h7
            //每次向下推进4x4格，iFact是不变的，ref要右移4，
            //完成一个4*H,向右推进4格，iFact右移4，ref_bk移动delta iIdx


            //ref4,横向求4行时用到的4个ref，纵向求4列时用到的4个ref
            //调试，ref:
            //[27]  [28]  [29]  [30] [31]  [32]  [33]  [34]  [35]  [36]  [37]  [38]  [39]  [40]
            //146   145   145   145  144   144   151   139   130   122   115   112   111   110 
            //ref4[0]取ref[32~40] 144   151   139   130   122   115   112   111   110,用来求a0,b0,c0,d0
            //ref4[1]取ref[31~39] 144   144   151   139   130   122   115   112   111,用来求a1,b1,c1,d1,相对ref4[0],delta iIdx=1
            //ref4[2]取ref[31~39] 144   144   151   139   130   122   115   112   111,用来求a2,b2,c2,d2,相对ref4[1],delta iIdx=0
            //ref4[3]取ref[30~38] 145   144   144   151   139   130   122   115   112,用来求a3,b3,c3,d3,相对ref4[2],delta iIdx=1
            //ref_bk =ref左移3，要加上下一个ref4[0]对本ref4[3]的delta iIdx
            //[27]  [28]  [29]  [30] [31]  [32]  [33]  [34]  [35]  [36]  [37]  [38]  [39]  [40]
            //                  146  145   145   145   144   144   151   139   130   122   115   112   111   110 
            //第二轮ref4右移4
            //ref4[0]  122   115   112   111   110,用来求e0,f0,g0,h0
            //ref4[1]  130   122   115   112   111,用来求e1,f1,g1,h1,
            //ref4[2]  130   122   115   112   111,用来求e2,f2,g2,h2,
            //ref4[3]  139   130   122   115   112,用来求e3,f3,g3,h3,
            //第三轮
            //ref4[0] 145   145   144   144   151   139   130   122   115,用来求a4,b4,c4,d4
            //ref4[1] 145   145   144   144   151   139   130   122   115,用来求a5,b5,c5,d5,相对ref4[0],delta iIdx=0
            //ref4[2] 145   145   145   144   144   151   139   130   122,用来求a6,b6,c6,d6,相对ref4[1],delta iIdx=1
            //ref4[3] 146   145   145   145   144   144   151   139   130,用来求a7,b7,c7,d7,相对ref4[2],delta iIdx=1

            //W*4或4*H结束
            if ((stage == 1)||
                ((stage==6)&&
                ((pick_ref == ref_pick_top||pick_ref == ref_pick_partial_left)&&(x[4:2] == trafoSize_bit5to2_minus1)||
                (pick_ref == ref_pick_left||pick_ref == ref_pick_partial_top)&&(y[4:2] == trafoSize_bit5to2_minus1)))) begin

                //ref_pick_partial_left和ref_pick_partial_top,ref4先取ref[64:32],然后慢慢根据delta idx左移ref[63:31],ref[62:30],...
                //ref_pick_left和ref_pick_top，ref4先取ref[32:0],然后慢慢右移，ref[33:1],ref[34:2],...
                if (pick_ref==ref_pick_partial_top||
                    pick_ref==ref_pick_partial_left) begin
                    ref4[0]                   <= iIdx_delta_idx[0]?ref_bk[63:31]:ref_bk[64:32];
                    case (iIdx_delta_idx[0]+iIdx_delta_idx[1])
                        0: ref4[1]            <= ref_bk[64:32];
                        1: ref4[1]            <= ref_bk[63:31];
                        default: ref4[1]      <= ref_bk[62:30];
                    endcase
                    case (iIdx_delta_idx[0]+iIdx_delta_idx[1]+iIdx_delta_idx[2])
                        0: ref4[2]            <= ref_bk[64:32];
                        1: ref4[2]            <= ref_bk[63:31];
                        2: ref4[2]            <= ref_bk[62:30];
                        default: ref4[2]      <= ref_bk[61:29];
                    endcase
                    case (iIdx_delta_idx[0]+iIdx_delta_idx[1]+iIdx_delta_idx[2]+iIdx_delta_idx[3])
                        0: ref4[3]            <= ref_bk[64:32];
                        1: ref4[3]            <= ref_bk[63:31];
                        2: ref4[3]            <= ref_bk[62:30];
                        3: ref4[3]            <= ref_bk[61:29];
                        default: ref4[3]      <= ref_bk[60:28];
                    endcase
                    //ref_bk就是ref4[3]?no,no,no,ref_bk比ref4[3]长一倍
                    case (iIdx_delta_idx[0]+iIdx_delta_idx[1]+iIdx_delta_idx[2]+iIdx_delta_idx[3])
                        0: ref_bk             <= ref_bk;
                        1: ref_bk             <= {ref_bk[63:0],8'd0};
                        2: ref_bk             <= {ref_bk[62:0],16'd0};
                        3: ref_bk             <= {ref_bk[61:0],24'd0};
                        default: ref_bk       <= {ref_bk[60:0],32'd0};
                    endcase
                end else begin
                    ref4[0]                   <= iIdx_delta_idx[0]?ref_bk[33:1]:ref_bk[32:0];
                    case (iIdx_delta_idx[0]+iIdx_delta_idx[1])
                        0: ref4[1]            <= ref_bk[32:0];
                        1: ref4[1]            <= ref_bk[33:1];
                        default: ref4[1]      <= ref_bk[34:2];
                    endcase
                    case (iIdx_delta_idx[0]+iIdx_delta_idx[1]+iIdx_delta_idx[2])
                        0: ref4[2]            <= ref_bk[32:0];
                        1: ref4[2]            <= ref_bk[33:1];
                        2: ref4[2]            <= ref_bk[34:2];
                        default: ref4[2]      <= ref_bk[35:3];
                    endcase
                    case (iIdx_delta_idx[0]+iIdx_delta_idx[1]+iIdx_delta_idx[2]+iIdx_delta_idx[3])
                        0: ref4[3]            <= ref_bk[32:0];
                        1: ref4[3]            <= ref_bk[33:1];
                        2: ref4[3]            <= ref_bk[34:2];
                        3: ref4[3]            <= ref_bk[35:3];
                        default: ref4[3]      <= ref_bk[36:4];
                    endcase
                    case (iIdx_delta_idx[0]+iIdx_delta_idx[1]+iIdx_delta_idx[2]+iIdx_delta_idx[3])
                        0: ref_bk             <= ref_bk;
                        1: ref_bk             <= {8'd0,ref_bk[64:1]};
                        2: ref_bk             <= {16'd0,ref_bk[64:2]};
                        3: ref_bk             <= {24'd0,ref_bk[64:3]};
                        default: ref_bk       <= {32'd0,ref_bk[64:4]};
                    endcase
                end

            end else if (stage == 6) begin
                ref4[3]                       <= {32'd0,ref4[3][32:4]};
                ref4[2]                       <= {32'd0,ref4[2][32:4]};
                ref4[1]                       <= {32'd0,ref4[1][32:4]};
                ref4[0]                       <= {32'd0,ref4[0][32:4]};
            end

            if (stage == 1) begin
                stage                         <= 2;
            end

            if (stage == 2) begin
                accum_rst                     <= 0;
                kick_store                    <= 0;
                posx0_tmp[0]                  <= ptop[0]-leftup;
                posx0_tmp[1]                  <= ptop[1]-leftup;
                posx0_tmp[2]                  <= ptop[2]-leftup;
                posx0_tmp[3]                  <= ptop[3]-leftup;
                pos0y_tmp[0]                  <= pleft[0]-leftup;
                pos0y_tmp[1]                  <= pleft[1]-leftup;
                pos0y_tmp[2]                  <= pleft[2]-leftup;
                pos0y_tmp[3]                  <= pleft[3]-leftup;
                stage                         <= 3;
            end
            if (stage == 3) begin
                result_posx0_tmp[0]           <= pleft0+(posx0_tmp[0]>>>1);
                result_posx0_tmp[1]           <= pleft0+(posx0_tmp[1]>>>1);
                result_posx0_tmp[2]           <= pleft0+(posx0_tmp[2]>>>1);
                result_posx0_tmp[3]           <= pleft0+(posx0_tmp[3]>>>1);
                result_pos0y_tmp[0]           <= ptop0+(pos0y_tmp[0]>>>1);
                result_pos0y_tmp[1]           <= ptop0+(pos0y_tmp[1]>>>1);
                result_pos0y_tmp[2]           <= ptop0+(pos0y_tmp[2]>>>1);
                result_pos0y_tmp[3]           <= ptop0+(pos0y_tmp[3]>>>1);
                stage                         <= 4;
            end

            if (stage == 4) begin
                result_posx0[0]               <= result_posx0_tmp[0][9]?0:(result_posx0_tmp[0][8]?255:result_posx0_tmp[0][7:0]);
                result_posx0[1]               <= result_posx0_tmp[1][9]?0:(result_posx0_tmp[1][8]?255:result_posx0_tmp[1][7:0]);
                result_posx0[2]               <= result_posx0_tmp[2][9]?0:(result_posx0_tmp[2][8]?255:result_posx0_tmp[2][7:0]);
                result_posx0[3]               <= result_posx0_tmp[3][9]?0:(result_posx0_tmp[3][8]?255:result_posx0_tmp[3][7:0]);
                result_pos0y[0]               <= result_pos0y_tmp[0][9]?0:(result_pos0y_tmp[0][8]?255:result_pos0y_tmp[0][7:0]);
                result_pos0y[1]               <= result_pos0y_tmp[1][9]?0:(result_pos0y_tmp[1][8]?255:result_pos0y_tmp[1][7:0]);
                result_pos0y[2]               <= result_pos0y_tmp[2][9]?0:(result_pos0y_tmp[2][8]?255:result_pos0y_tmp[2][7:0]);
                result_pos0y[3]               <= result_pos0y_tmp[3][9]?0:(result_pos0y_tmp[3][8]?255:result_pos0y_tmp[3][7:0]);
                stage                         <= 5;
                accum_rst                     <= 1;
            end
            if (stage == 5) begin
                result4x4                     <= result4x4_angular_w;
                if (x==0&&log2TrafoSize != 5&&intra_predmode==26) begin
                    result4x4[0]              <= result_pos0y[0];
                    result4x4[4]              <= result_pos0y[1];
                    result4x4[8]              <= result_pos0y[2];
                    result4x4[12]             <= result_pos0y[3];
                end

                if (y==0&&log2TrafoSize != 5&&intra_predmode==10) begin
                    result4x4[3:0]            <= result_posx0;
                end
                x_to_store                    <= x;
                y_to_store                    <= y;
                stage                         <= 6;
                if ((pick_ref == ref_pick_top||pick_ref == ref_pick_partial_left)&&(x[4:2] == trafoSize_bit5to2_minus1)||
                    (pick_ref == ref_pick_left||pick_ref == ref_pick_partial_top)&&(y[4:2] == trafoSize_bit5to2_minus1)) begin
                    //iFact,iIdx每列相同，不是每个点1个，stage=5这里更新完iIdx_delta_idx,stage=6上面更新ref4
                    iIdx_delta_idx            <= {iIdx_delta_idx[4:31],4'd0};
                    iFact_idx                 <= {iFact_idx[4:31],20'd0};
                end
            end

            //固定周期，不需要用store_done来同步，只要调整store周期和anguluar周期一样就可以，
            //实际store_done置1的那个周期就可以置kick store了
            if (stage == 6) begin
                kick_store                    <= 1;
                stage                         <= 2;
                if (pick_ref == ref_pick_top||pick_ref == ref_pick_partial_left) begin
                    x                         <= x+4;
                    ptop[31:0]                <= {32'd0,ptop[31:4]};
                    if (x[4:2] == trafoSize_bit5to2_minus1) begin
                        y                     <= y+4;
                        x                     <= 0;
                        pleft[31:0]           <= {32'd0,pleft[31:4]};//求result_posx0,result_pos0y用
                        ptop[31:0]            <= ptop_bk;

                        if (y[4:2] == trafoSize_bit5to2_minus1) begin
                            stage             <= 7;
                        end
                    end
                end else begin
                    //竖着来，求完4xH，再求下一个4xH
                    y                         <= y+4;
                    pleft[31:0]               <= {32'd0,pleft[31:4]};
                    if (y[4:2] == trafoSize_bit5to2_minus1) begin
                        x                     <= x+4;
                        y                     <= 0;
                        ptop[31:0]            <= {32'd0,ptop[31:4]};
                        pleft[31:0]           <= pleft_bk;
                        if (x[4:2] == trafoSize_bit5to2_minus1) begin
                            stage             <= 7;
                        end
                    end
                end
            end
            if (stage == 7) begin
                kick_store                    <= 0;
                if (~kick_store&&store_done)
                    o_intra_pred_state        <= `intra_pred_end;
            end

        end
    default:
        begin
        end
    endcase
end else begin

end

always @(posedge clk)
if ((o_intra_pred_state==`intra_pred_dc&&stage==0)||
    (o_intra_pred_state==`intra_pred_angular&&stage==0)||
    (o_intra_pred_state==`intra_pred_planar&&phase==0)) begin
    if (`log_p && filtered && i_slice_num>=`slice_begin && i_slice_num<=`slice_end) begin
        $fdisplay(fd_log, "filtered leftup: %0d", leftup);
        if (log2TrafoSize==5) begin
            $fdisplay(fd_log, "filtered left:   %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d",
                      pleft[0],pleft[1],pleft[2],pleft[3],pleft[4],pleft[5],pleft[6],pleft[7],
                      pleft[8],pleft[9],pleft[10],pleft[11],pleft[12],pleft[13],pleft[14],pleft[15],
                      pleft[16],pleft[17],pleft[18],pleft[19],pleft[20],pleft[21],pleft[22],pleft[23],
                      pleft[24],pleft[25],pleft[26],pleft[27],pleft[28],pleft[29],pleft[30],pleft[31]);
            $fdisplay(fd_log, "%0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d",
                      pleft[32],pleft[33],pleft[34],pleft[35],pleft[36],pleft[37],pleft[38],pleft[39],
                      pleft[40],pleft[41],pleft[42],pleft[43],pleft[44],pleft[45],pleft[46],pleft[47],
                      pleft[48],pleft[49],pleft[50],pleft[51],pleft[52],pleft[53],pleft[54],pleft[55],
                      pleft[56],pleft[57],pleft[58],pleft[59],pleft[60],pleft[61],pleft[62],pleft[63]);
            $fdisplay(fd_log, "filtered top:    %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d",
                      ptop[0],ptop[1],ptop[2],ptop[3],ptop[4],ptop[5],ptop[6],ptop[7],
                      ptop[8],ptop[9],ptop[10],ptop[11],ptop[12],ptop[13],ptop[14],ptop[15],
                      ptop[16],ptop[17],ptop[18],ptop[19],ptop[20],ptop[21],ptop[22],ptop[23],
                      ptop[24],ptop[25],ptop[26],ptop[27],ptop[28],ptop[29],ptop[30],ptop[31]);
            $fdisplay(fd_log, "%0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d",
                      ptop[32],ptop[33],ptop[34],ptop[35],ptop[36],ptop[37],ptop[38],ptop[39],
                      ptop[40],ptop[41],ptop[42],ptop[43],ptop[44],ptop[45],ptop[46],ptop[47],
                      ptop[48],ptop[49],ptop[50],ptop[51],ptop[52],ptop[53],ptop[54],ptop[55],
                      ptop[56],ptop[57],ptop[58],ptop[59],ptop[60],ptop[61],ptop[62],ptop[63]);
        end else if (log2TrafoSize==4) begin
            $fdisplay(fd_log, "filtered left:   %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d",
                      pleft[0],pleft[1],pleft[2],pleft[3],pleft[4],pleft[5],pleft[6],pleft[7],
                      pleft[8],pleft[9],pleft[10],pleft[11],pleft[12],pleft[13],pleft[14],pleft[15],
                      pleft[16],pleft[17],pleft[18],pleft[19],pleft[20],pleft[21],pleft[22],pleft[23],
                      pleft[24],pleft[25],pleft[26],pleft[27],pleft[28],pleft[29],pleft[30],pleft[31]);
            $fdisplay(fd_log, "filtered top:    %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d",
                      ptop[0],ptop[1],ptop[2],ptop[3],ptop[4],ptop[5],ptop[6],ptop[7],
                      ptop[8],ptop[9],ptop[10],ptop[11],ptop[12],ptop[13],ptop[14],ptop[15],
                      ptop[16],ptop[17],ptop[18],ptop[19],ptop[20],ptop[21],ptop[22],ptop[23],
                      ptop[24],ptop[25],ptop[26],ptop[27],ptop[28],ptop[29],ptop[30],ptop[31]);
        end else if (log2TrafoSize==3) begin
            $fdisplay(fd_log, "filtered left:   %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d",
                      pleft[0],pleft[1],pleft[2],pleft[3],pleft[4],pleft[5],pleft[6],pleft[7],
                      pleft[8],pleft[9],pleft[10],pleft[11],pleft[12],pleft[13],pleft[14],pleft[15]);
            $fdisplay(fd_log, "filtered top:    %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d",
                      ptop[0],ptop[1],ptop[2],ptop[3],ptop[4],ptop[5],ptop[6],ptop[7],
                      ptop[8],ptop[9],ptop[10],ptop[11],ptop[12],ptop[13],ptop[14],ptop[15]);
        end else begin
            $fdisplay(fd_log, "filtered left:   %0d %0d %0d %0d %0d %0d %0d %0d",
                      pleft[0],pleft[1],pleft[2],pleft[3],pleft[4],pleft[5],pleft[6],pleft[7]);
            $fdisplay(fd_log, "filtered top:    %0d %0d %0d %0d %0d %0d %0d %0d",
                      ptop[0],ptop[1],ptop[2],ptop[3],ptop[4],ptop[5],ptop[6],ptop[7]);
        end

    end

    if (`log_p && i_slice_num>=`slice_begin && i_slice_num<=`slice_end) begin
        if (o_intra_pred_state==`intra_pred_dc)
            $fdisplay(fd_log, "DC");
        else if (o_intra_pred_state==`intra_pred_planar)
            $fdisplay(fd_log, "PLANAR");
        else
            $fdisplay(fd_log, "ANGULAR");
    end

end

`ifdef RANDOM_INIT
integer  seed;
integer random_val;
initial  begin
    seed                               = $get_initial_random_seed(); 
    random_val                         = $random(seed);
    dram_pred_we                       = {random_val,random_val};
    dram_pred_addr                     = {random_val[1:0],random_val[31:2],random_val[1:0],random_val[31:2]};
    dram_pred_din                      = {random_val[2:0],random_val[31:3],random_val[2:0],random_val[31:3]};
    o_pred_done_y                      = {random_val[3:0],random_val[31:4],random_val[3:0],random_val[31:4]};
    o_intra_pred_state                 = {random_val[4:0],random_val[31:5],random_val[4:0],random_val[31:5]};
    x0                                 = {random_val[5:0],random_val[31:6],random_val[5:0],random_val[31:6]};
    y0                                 = {random_val[6:0],random_val[31:7],random_val[6:0],random_val[31:7]};
    xTu                                = {random_val[7:0],random_val[31:8],random_val[7:0],random_val[31:8]};
    yTu                                = {random_val[8:0],random_val[31:9],random_val[8:0],random_val[31:9]};
    x                                  = {random_val[9:0],random_val[31:10],random_val[9:0],random_val[31:10]};
    y                                  = {random_val[10:0],random_val[31:11],random_val[10:0],random_val[31:11]};
    left_avail                         = {random_val[11:0],random_val[31:12],random_val[11:0],random_val[31:12]};
    up_avail                           = {random_val[12:0],random_val[31:13],random_val[12:0],random_val[31:13]};
    intra_predmode                     = {random_val[13:0],random_val[31:14],random_val[13:0],random_val[31:14]};
    log2TrafoSize                      = {random_val[14:0],random_val[31:15],random_val[14:0],random_val[31:15]};
    trafoSize                          = {random_val[15:0],random_val[31:16],random_val[15:0],random_val[31:16]};
    trafoSize_bit5to2_minus1           = {random_val[16:0],random_val[31:17],random_val[16:0],random_val[31:17]};
    cIdx                               = {random_val[17:0],random_val[31:18],random_val[17:0],random_val[31:18]};
    intraHorVerDisThres                = {random_val[18:0],random_val[31:19],random_val[18:0],random_val[31:19]};
    minDistVerHor                      = {random_val[19:0],random_val[31:20],random_val[19:0],random_val[31:20]};
    abs_intramode_minus26              = {random_val[20:0],random_val[31:21],random_val[20:0],random_val[31:21]};
    abs_intramode_minus10              = {random_val[21:0],random_val[31:22],random_val[21:0],random_val[31:22]};
    strong_smooth_cond0                = {random_val[22:0],random_val[31:23],random_val[22:0],random_val[31:23]};
    strong_smooth_cond1                = {random_val[23:0],random_val[31:24],random_val[23:0],random_val[31:24]};
    filtered                           = {random_val[24:0],random_val[31:25],random_val[24:0],random_val[31:25]};
    pleft                              = {random_val[25:0],random_val[31:26],random_val[25:0],random_val[31:26]};
    ptop                               = {random_val[26:0],random_val[31:27],random_val[26:0],random_val[31:27]};
    pleft_bk                           = {random_val[27:0],random_val[31:28],random_val[27:0],random_val[31:28]};
    ptop_bk                            = {random_val[28:0],random_val[31:29],random_val[28:0],random_val[31:29]};
    pleft_copy                         = {random_val[29:0],random_val[31:30],random_val[29:0],random_val[31:30]};
    ptop_copy                          = {random_val[30:0],random_val[31],random_val[30:0],random_val[31]};
    leftup                             = {random_val[31:0],random_val[31:0]};
    pleft_tmp                          = {random_val,random_val};
    ptop_tmp                           = {random_val[1:0],random_val[31:2],random_val[1:0],random_val[31:2]};
    pleft_tmp_init                     = {random_val[2:0],random_val[31:3],random_val[2:0],random_val[31:3]};
    ptop_tmp_init                      = {random_val[3:0],random_val[31:4],random_val[3:0],random_val[31:4]};
    pleft_63                           = {random_val[4:0],random_val[31:5],random_val[4:0],random_val[31:5]};
    ptop_63                            = {random_val[5:0],random_val[31:6],random_val[5:0],random_val[31:6]};
    sub_i                              = {random_val[6:0],random_val[31:7],random_val[6:0],random_val[31:7]};
    filter_i                           = {random_val[7:0],random_val[31:8],random_val[7:0],random_val[31:8]};
    phase                              = {random_val[8:0],random_val[31:9],random_val[8:0],random_val[31:9]};
    stage                              = {random_val[9:0],random_val[31:10],random_val[9:0],random_val[31:10]};
    tier                               = {random_val[10:0],random_val[31:11],random_val[10:0],random_val[31:11]};
    valid                              = {random_val[11:0],random_val[31:12],random_val[11:0],random_val[31:12]};
    accum_a                            = {random_val[12:0],random_val[31:13],random_val[12:0],random_val[31:13]};
    accum_b                            = {random_val[13:0],random_val[31:14],random_val[13:0],random_val[31:14]};
    accum_rst                          = {random_val[14:0],random_val[31:15],random_val[14:0],random_val[31:15]};
    accum_en                           = {random_val[15:0],random_val[31:16],random_val[15:0],random_val[31:16]};
    result4x4                          = {random_val[16:0],random_val[31:17],random_val[16:0],random_val[31:17]};
    result_posx0_tmp                   = {random_val[17:0],random_val[31:18],random_val[17:0],random_val[31:18]};
    result_pos0y_tmp                   = {random_val[18:0],random_val[31:19],random_val[18:0],random_val[31:19]};
    result_posx0                       = {random_val[19:0],random_val[31:20],random_val[19:0],random_val[31:20]};
    result_pos0y                       = {random_val[20:0],random_val[31:21],random_val[20:0],random_val[31:21]};
    result4x4_copy                     = {random_val[21:0],random_val[31:22],random_val[21:0],random_val[31:22]};
    posx0_tmp[3:0]                     = {random_val[22:0],random_val[31:23],random_val[22:0],random_val[31:23]};
    pos0y_tmp[3:0]                     = {random_val[23:0],random_val[31:24],random_val[23:0],random_val[31:24]};
    pleft0                             = {random_val[24:0],random_val[31:25],random_val[24:0],random_val[31:25]};
    ptop0                              = {random_val[25:0],random_val[31:26],random_val[25:0],random_val[31:26]};
    dc_sum                             = {random_val[26:0],random_val[31:27],random_val[26:0],random_val[31:27]};
    sum_i                              = {random_val[27:0],random_val[31:28],random_val[27:0],random_val[31:28]};
    dcVal                              = {random_val[28:0],random_val[31:29],random_val[28:0],random_val[31:29]};
    ref_pick_idx                       = {random_val[30:0],random_val[31],random_val[30:0],random_val[31]};
    ref_r                              = {random_val[31:0],random_val[31:0]};
    ref4                               = {random_val,random_val};
    ref_bk                             = {random_val[1:0],random_val[31:2],random_val[1:0],random_val[31:2]};
    pick_ref                           = {random_val[2:0],random_val[31:3],random_val[2:0],random_val[31:3]};
    iFact_idx                          = {random_val[4:0],random_val[31:5],random_val[4:0],random_val[31:5]};
    iIdx_delta_idx                     = {random_val[6:0],random_val[31:7],random_val[6:0],random_val[31:7]};
    operand1                           = {random_val[7:0],random_val[31:8],random_val[7:0],random_val[31:8]};
    operand2                           = {random_val[8:0],random_val[31:9],random_val[8:0],random_val[31:9]};
    ptop_ntbs                          = {random_val[9:0],random_val[31:10],random_val[9:0],random_val[31:10]};
    pleft_ntbs                         = {random_val[10:0],random_val[31:11],random_val[10:0],random_val[31:11]};
    store_stage                        = {random_val[11:0],random_val[31:12],random_val[11:0],random_val[31:12]};
    kick_store                         = {random_val[12:0],random_val[31:13],random_val[12:0],random_val[31:13]};
    store_done                         = {random_val[13:0],random_val[31:14],random_val[13:0],random_val[31:14]};
    store_x                            = {random_val[14:0],random_val[31:15],random_val[14:0],random_val[31:15]};
    store_y                            = {random_val[15:0],random_val[31:16],random_val[15:0],random_val[31:16]};
    x_to_store                         = {random_val[16:0],random_val[31:17],random_val[16:0],random_val[31:17]};
    y_to_store                         = {random_val[17:0],random_val[31:18],random_val[17:0],random_val[31:18]};
    store_i                            = {random_val[18:0],random_val[31:19],random_val[18:0],random_val[31:19]};
    last4x4_in_row                     = {random_val[19:0],random_val[31:20],random_val[19:0],random_val[31:20]};
end
`endif


endmodule
