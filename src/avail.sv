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

module avail_nb
(
 input wire                       clk                               ,
 input wire                       rst                               ,
 input wire                       global_rst                        ,

 input wire                       en                                ,
 input wire  [15:0]               i_slice_num                       ,
 input wire  [`max_x_bits-1:0]    i_x0                              ,
 input wire  [`max_y_bits-1:0]    i_y0                              ,
 input wire  [ 5:0]               i_xTu                             ,
 input wire  [ 5:0]               i_yTu                             ,

 input wire  [ 2:0]               i_log2TrafoSize                   ,
 input wire  [ 5:0]               i_trafoSize                       ,

 input wire                       i_constrained_intra_pred_flag     ,
 input wire  [ 7:0]               i_predmode_leftup                 ,
 input wire                       i_predmode                        , //当前cu的cu_predmode
 input wire  [ 7:0]               i_predmode_left                   ,
 input wire  [15:0]               i_predmode_up                     ,

 input wire                       i_last_col                        ,
 input wire                       i_last_row                        ,
 input wire                       i_first_col                       ,
 input wire                       i_first_row                       ,
 input wire  [ 6:0]               i_last_col_width                  ,
 input wire  [ 6:0]               i_last_row_height                 ,

 input wire  [31: 0]              fd_log                            ,

 output reg  [ 8: 0]              o_left_avail                      , //包括leftup
 output reg  [ 7: 0]              o_up_avail                        ,
 output reg  [ 8: 0]              o_left_avail_sz8x8                , //chroma blk3,求avail时，是以8x8大小来求的，而求luma blk0是以4x4大小来求
 output reg  [ 7 :0]              o_up_avail_sz8x8                  ,
 output reg                       o_avail_done

);


reg  [`max_x_bits-1:0]     x0                   ;
reg  [`max_y_bits-1:0]     y0                   ;
reg  [`max_x_bits-1:0]     xTu                  ;
reg  [`max_y_bits-1:0]     yTu                  ;


reg  [  2:0]               log2TrafoSize        ;
reg  [  5:0]               trafoSize            ;
reg  [  1:0]               cIdx                 ;


reg                        left_bottom_avail    ;
reg                        up_right_avail       ;
reg                        leftup_avail         ;
reg                        left_bottom_avail_r  ;
reg                        up_right_avail_r     ;

reg                        predmode_leftup      ;
reg                        predmode_up0         ;
reg                        predmode_up1         ;
reg                        predmode_up2         ;
reg                        predmode_up3         ;
reg                        predmode_up4         ;
reg                        predmode_up5         ;
reg                        predmode_up6         ;
reg                        predmode_up7         ;
reg                        predmode_left0       ;
reg                        predmode_left1       ;
reg                        predmode_left2       ;
reg                        predmode_left3       ;
reg                        predmode_left4       ;
reg                        predmode_left5       ;
reg                        predmode_left6       ;
reg                        predmode_left7       ;


reg  [ 1:0]                stage                ;


reg  [0:255][ 7:0]          R2Z                 ;
initial begin
    R2Z                    = {
        8'h00, 8'h01, 8'h04, 8'h05, 8'h10, 8'h11, 8'h14, 8'h15, 8'h40, 8'h41, 8'h44, 8'h45, 8'h50, 8'h51, 8'h54, 8'h55,
        8'h02, 8'h03, 8'h06, 8'h07, 8'h12, 8'h13, 8'h16, 8'h17, 8'h42, 8'h43, 8'h46, 8'h47, 8'h52, 8'h53, 8'h56, 8'h57,
        8'h08, 8'h09, 8'h0c, 8'h0d, 8'h18, 8'h19, 8'h1c, 8'h1d, 8'h48, 8'h49, 8'h4c, 8'h4d, 8'h58, 8'h59, 8'h5c, 8'h5d,
        8'h0a, 8'h0b, 8'h0e, 8'h0f, 8'h1a, 8'h1b, 8'h1e, 8'h1f, 8'h4a, 8'h4b, 8'h4e, 8'h4f, 8'h5a, 8'h5b, 8'h5e, 8'h5f,
        8'h20, 8'h21, 8'h24, 8'h25, 8'h30, 8'h31, 8'h34, 8'h35, 8'h60, 8'h61, 8'h64, 8'h65, 8'h70, 8'h71, 8'h74, 8'h75,
        8'h22, 8'h23, 8'h26, 8'h27, 8'h32, 8'h33, 8'h36, 8'h37, 8'h62, 8'h63, 8'h66, 8'h67, 8'h72, 8'h73, 8'h76, 8'h77,
        8'h28, 8'h29, 8'h2c, 8'h2d, 8'h38, 8'h39, 8'h3c, 8'h3d, 8'h68, 8'h69, 8'h6c, 8'h6d, 8'h78, 8'h79, 8'h7c, 8'h7d,
        8'h2a, 8'h2b, 8'h2e, 8'h2f, 8'h3a, 8'h3b, 8'h3e, 8'h3f, 8'h6a, 8'h6b, 8'h6e, 8'h6f, 8'h7a, 8'h7b, 8'h7e, 8'h7f,
        8'h80, 8'h81, 8'h84, 8'h85, 8'h90, 8'h91, 8'h94, 8'h95, 8'hc0, 8'hc1, 8'hc4, 8'hc5, 8'hd0, 8'hd1, 8'hd4, 8'hd5,
        8'h82, 8'h83, 8'h86, 8'h87, 8'h92, 8'h93, 8'h96, 8'h97, 8'hc2, 8'hc3, 8'hc6, 8'hc7, 8'hd2, 8'hd3, 8'hd6, 8'hd7,
        8'h88, 8'h89, 8'h8c, 8'h8d, 8'h98, 8'h99, 8'h9c, 8'h9d, 8'hc8, 8'hc9, 8'hcc, 8'hcd, 8'hd8, 8'hd9, 8'hdc, 8'hdd,
        8'h8a, 8'h8b, 8'h8e, 8'h8f, 8'h9a, 8'h9b, 8'h9e, 8'h9f, 8'hca, 8'hcb, 8'hce, 8'hcf, 8'hda, 8'hdb, 8'hde, 8'hdf,
        8'ha0, 8'ha1, 8'ha4, 8'ha5, 8'hb0, 8'hb1, 8'hb4, 8'hb5, 8'he0, 8'he1, 8'he4, 8'he5, 8'hf0, 8'hf1, 8'hf4, 8'hf5,
        8'ha2, 8'ha3, 8'ha6, 8'ha7, 8'hb2, 8'hb3, 8'hb6, 8'hb7, 8'he2, 8'he3, 8'he6, 8'he7, 8'hf2, 8'hf3, 8'hf6, 8'hf7,
        8'ha8, 8'ha9, 8'hac, 8'had, 8'hb8, 8'hb9, 8'hbc, 8'hbd, 8'he8, 8'he9, 8'hec, 8'hed, 8'hf8, 8'hf9, 8'hfc, 8'hfd,
        8'haa, 8'hab, 8'hae, 8'haf, 8'hba, 8'hbb, 8'hbe, 8'hbf, 8'hea, 8'heb, 8'hee, 8'hef, 8'hfa, 8'hfb, 8'hfe, 8'hff
                                };
end

reg  [ 5:0]               x_left_bottom_most         ; //块的最左下的坐标
reg  [ 5:0]               y_left_bottom_most         ;
reg  [ 5:0]               x_left_bottom_nb           ;
reg  [ 5:0]               y_left_bottom_nb           ;
reg  [ 5:0]               x_up_right_most            ;
reg  [ 5:0]               y_up_right_most            ;
reg  [ 5:0]               x_up_right_nb              ;
reg  [ 5:0]               y_up_right_nb              ;
reg  [ 7:0]               zorder_left_bottom         ;
reg  [ 7:0]               zorder_left_bottom_nb      ;
reg  [ 7:0]               zorder_up_right            ;
reg  [ 7:0]               zorder_up_right_nb         ;

reg  [ 5:0]               x_left_bottom_most_sz8x8   ;
reg  [ 5:0]               y_left_bottom_most_sz8x8   ;
reg  [ 5:0]               x_left_bottom_nb_sz8x8     ;
reg  [ 5:0]               y_left_bottom_nb_sz8x8     ;
reg  [ 5:0]               x_up_right_most_sz8x8      ;
reg  [ 5:0]               y_up_right_most_sz8x8      ;
reg  [ 5:0]               x_up_right_nb_sz8x8        ;
reg  [ 5:0]               y_up_right_nb_sz8x8        ;
reg  [ 7:0]               zorder_left_bottom_sz8x8   ;
reg  [ 7:0]               zorder_left_bottom_nb_sz8x8;
reg  [ 7:0]               zorder_up_right_sz8x8      ;
reg  [ 7:0]               zorder_up_right_nb_sz8x8   ;

always @(*)
begin
    if (i_first_col && xTu[5:2] == 0 ||
        (i_last_row && yTu[5:2] + trafoSize[5:2] >= i_last_row_height[6:2]))
        left_bottom_avail = 0;
    else if (yTu[5:2] + trafoSize[5:2] >= 16)//处于上下2个CTB
        left_bottom_avail = 0;
    else if (xTu[5:2] == 0)
        left_bottom_avail = 1;
    else if (zorder_left_bottom < zorder_left_bottom_nb)
        left_bottom_avail = 0;
    else
        left_bottom_avail = 1;
end

always @(*)
begin
    if (i_first_row && yTu[5:2] == 0 ||
        (i_last_col &&xTu[5:2] + trafoSize[5:2] >= i_last_col_width[6:2]))
        up_right_avail = 0;
    else if (yTu[5:2] == 0) //上下两个ctb
        up_right_avail = 1;
    else if (xTu[5:2] + trafoSize[5:2] >= 16&&yTu[5:2]!=0)//处于左右2个CTB
        up_right_avail = 0;
    else if (zorder_up_right < zorder_up_right_nb)
        up_right_avail = 0;
    else
        up_right_avail = 1;
end

reg                        left_bottom_avail_sz8x8    ;
reg                        up_right_avail_sz8x8       ;
reg                        left_bottom_avail_sz8x8_r  ;
reg                        up_right_avail_sz8x8_r     ;

always @(*)
begin
    if (i_first_col && xTu[5:2] == 0 ||
        (i_last_row && yTu[5:2] + 2 >= i_last_row_height[6:2]))
        left_bottom_avail_sz8x8 = 0;
    else if (yTu[5:2] + 2 >= 16)//处于上下2个CTB
        left_bottom_avail_sz8x8 = 0;
    else if (xTu[5:2] == 0)
        left_bottom_avail_sz8x8 = 1;
    else if (zorder_left_bottom_sz8x8 < zorder_left_bottom_nb_sz8x8)
        left_bottom_avail_sz8x8 = 0;
    else
        left_bottom_avail_sz8x8 = 1;
end

always @(*)
begin
    if (i_first_row && yTu[5:2] == 0 ||
        (i_last_col &&xTu[5:2] + 2 >= i_last_col_width[6:2]))
        up_right_avail_sz8x8 = 0;
    else if (yTu[5:2] == 0) //上下两个ctb
        up_right_avail_sz8x8 = 1;
    else if (xTu[5:2] + 2 >= 16)//处于左右2个CTB
        up_right_avail_sz8x8 = 0;
    else if (zorder_up_right_sz8x8 < zorder_up_right_nb_sz8x8)
        up_right_avail_sz8x8 = 0;
    else
        up_right_avail_sz8x8 = 1;
end



always @ (posedge clk)
if (global_rst) begin
    stage                         <= 3;
    o_avail_done                  <= 0;
end else if (rst) begin
    x0                            <= i_x0;
    y0                            <= i_y0;
    xTu                           <= {i_x0[`max_x_bits-1:6],i_xTu};
    yTu                           <= {i_y0[`max_y_bits-1:6],i_yTu};

    log2TrafoSize                 <= i_log2TrafoSize;
    trafoSize                     <= i_trafoSize;

    o_left_avail                  <= 9'd0;
    o_up_avail                    <= 8'd0;
    o_left_avail_sz8x8            <= 9'd0;
    o_up_avail_sz8x8              <= 8'd0;
    x_left_bottom_most            <= i_xTu[5:0];
    y_left_bottom_most            <= i_yTu[5:0]+i_trafoSize-1;
    x_left_bottom_nb              <= i_xTu[5:0]-1;
    y_left_bottom_nb              <= i_yTu[5:0]+i_trafoSize;
    x_up_right_most               <= i_xTu[5:0]+i_trafoSize-1;
    y_up_right_most               <= i_yTu[5:0];
    x_up_right_nb                 <= i_xTu[5:0]+i_trafoSize;
    y_up_right_nb                 <= i_yTu[5:0]-1;

    x_left_bottom_most_sz8x8      <= i_xTu[5:0];
    y_left_bottom_most_sz8x8      <= i_yTu[5:0]+7;
    x_left_bottom_nb_sz8x8        <= i_xTu[5:0]-1;
    y_left_bottom_nb_sz8x8        <= i_yTu[5:0]+8;
    x_up_right_most_sz8x8         <= i_xTu[5:0]+7;
    y_up_right_most_sz8x8         <= i_yTu[5:0];
    x_up_right_nb_sz8x8           <= i_xTu[5:0]+8;
    y_up_right_nb_sz8x8           <= i_yTu[5:0]-1;

    o_avail_done                  <= 0;
    stage                         <= 0;
end else if (en) begin
    if (stage == 0) begin
        zorder_left_bottom           <= R2Z[{y_left_bottom_most[5:2],x_left_bottom_most[5:2]}];
        zorder_left_bottom_nb        <= R2Z[{y_left_bottom_nb[5:2],x_left_bottom_nb[5:2]}];
        zorder_up_right              <= R2Z[{y_up_right_most[5:2],x_up_right_most[5:2]}];
        zorder_up_right_nb           <= R2Z[{y_up_right_nb[5:2],x_up_right_nb[5:2]}];
        zorder_left_bottom_sz8x8     <= R2Z[{y_left_bottom_most_sz8x8[5:2],x_left_bottom_most_sz8x8[5:2]}];
        zorder_left_bottom_nb_sz8x8  <= R2Z[{y_left_bottom_nb_sz8x8[5:2],x_left_bottom_nb_sz8x8[5:2]}];
        zorder_up_right_sz8x8        <= R2Z[{y_up_right_most_sz8x8[5:2],x_up_right_most_sz8x8[5:2]}];
        zorder_up_right_nb_sz8x8     <= R2Z[{y_up_right_nb_sz8x8[5:2],x_up_right_nb_sz8x8[5:2]}];

        if (xTu == 0 || yTu == 0) begin
            predmode_leftup          <= `MODE_INTER;
        end else if (x0[5:0] == xTu[5:0] && y0[5:0] == yTu[5:0]) begin
            predmode_leftup          <= i_predmode_leftup[yTu[5:3]];
        end else if (x0[5:0] == xTu[5:0]) begin
            predmode_leftup          <= i_predmode_left[y_up_right_nb[5:3]]; //fix,yTu[5:3]-1
        end else if (y0[5:0] == yTu[5:0]) begin
            predmode_leftup          <= i_predmode_up[x_left_bottom_nb[5:3]]; //fix,xTu[5:3]-1
        end else begin
            predmode_leftup          <= i_predmode;
        end

        if (x0[5:0] == xTu[5:0]) begin
            predmode_left0           <= i_predmode_left[yTu[5:3]];
            predmode_left1           <= i_predmode_left[yTu[5:3]+1];
            predmode_left2           <= i_predmode_left[yTu[5:3]+2];
            predmode_left3           <= i_predmode_left[yTu[5:3]+3];
            predmode_left4           <= i_predmode_left[yTu[5:3]+4];
            predmode_left5           <= i_predmode_left[yTu[5:3]+5];
            predmode_left6           <= i_predmode_left[yTu[5:3]+6];
            predmode_left7           <= i_predmode_left[yTu[5:3]+7];
        end else begin
            predmode_left0           <= i_predmode;
            predmode_left1           <= i_predmode;
            predmode_left2           <= i_predmode;
            predmode_left3           <= i_predmode;
            predmode_left4           <= i_predmode;
            predmode_left5           <= i_predmode;
            predmode_left6           <= i_predmode;
            predmode_left7           <= i_predmode;
        end

        if (y0[5:0] == yTu[5:0]) begin
            predmode_up0             <= i_predmode_up[xTu[5:3]];
            predmode_up1             <= i_predmode_up[xTu[5:3]+1];
            predmode_up2             <= i_predmode_up[xTu[5:3]+2]; 
            predmode_up3             <= i_predmode_up[xTu[5:3]+3];
            predmode_up4             <= i_predmode_up[xTu[5:3]+4];
            predmode_up5             <= i_predmode_up[xTu[5:3]+5];
            predmode_up6             <= i_predmode_up[xTu[5:3]+6];
            predmode_up7             <= i_predmode_up[xTu[5:3]+7];
        end else begin
            predmode_up0             <= i_predmode;
            predmode_up1             <= i_predmode;
            predmode_up2             <= i_predmode;
            predmode_up3             <= i_predmode;
            predmode_up4             <= i_predmode;
            predmode_up5             <= i_predmode;
            predmode_up6             <= i_predmode;
            predmode_up7             <= i_predmode;
        end
        stage                        <= 1;
    end

    if (stage==1) begin
        up_right_avail_r             <= up_right_avail;
        left_bottom_avail_r          <= left_bottom_avail;
        up_right_avail_sz8x8_r       <= up_right_avail_sz8x8;
        left_bottom_avail_sz8x8_r    <= left_bottom_avail_sz8x8;
        stage                        <= 2;
    end

    if (stage==2) begin
        //leftup
        o_left_avail[0]              <= xTu !=0 && yTu != 0 && ((~i_constrained_intra_pred_flag)||predmode_leftup);
        o_left_avail_sz8x8[0]        <= xTu !=0 && yTu != 0 && ((~i_constrained_intra_pred_flag)||predmode_leftup);
        if (trafoSize[5] == 1) begin
            o_left_avail[1]          <= xTu !=0 && (~i_constrained_intra_pred_flag||predmode_left0);
            o_left_avail[2]          <= xTu !=0 && (~i_constrained_intra_pred_flag||predmode_left1);
            o_left_avail[3]          <= xTu !=0 && (~i_constrained_intra_pred_flag||predmode_left2);
            o_left_avail[4]          <= xTu !=0 && (~i_constrained_intra_pred_flag||predmode_left3);
            o_left_avail[5]          <= left_bottom_avail_r && (~i_constrained_intra_pred_flag||predmode_left4);
            o_left_avail[6]          <= left_bottom_avail_r && (~i_constrained_intra_pred_flag||predmode_left5) &&
                                        (~i_last_row ||yTu[5:2] + trafoSize[5:2]+ 2 < i_last_row_height[6:2]);
            o_left_avail[7]          <= left_bottom_avail_r && (~i_constrained_intra_pred_flag||predmode_left6) &&
                                        (~i_last_row ||yTu[5:2] + trafoSize[5:2]+ 4 < i_last_row_height[6:2]);
            o_left_avail[8]          <= left_bottom_avail_r && (~i_constrained_intra_pred_flag||predmode_left7) &&
                                        (~i_last_row ||yTu[5:2] + trafoSize[5:2]+ 6 < i_last_row_height[6:2]);
            o_up_avail[0]            <= yTu !=0 && (~i_constrained_intra_pred_flag||predmode_up0);
            o_up_avail[1]            <= yTu !=0 && (~i_constrained_intra_pred_flag||predmode_up1);
            o_up_avail[2]            <= yTu !=0 && (~i_constrained_intra_pred_flag||predmode_up2);
            o_up_avail[3]            <= yTu !=0 && (~i_constrained_intra_pred_flag||predmode_up3);
            o_up_avail[4]            <= up_right_avail_r && (~i_constrained_intra_pred_flag||predmode_up4);
            o_up_avail[5]            <= up_right_avail_r && (~i_constrained_intra_pred_flag||predmode_up5) &&
                                        (~i_last_col ||xTu[5:2] + trafoSize[5:2]+2 < i_last_col_width[6:2]);
            o_up_avail[6]            <= up_right_avail_r && (~i_constrained_intra_pred_flag||predmode_up6) &&
                                        (~i_last_col ||xTu[5:2] + trafoSize[5:2]+ 4 < i_last_col_width[6:2]);
            o_up_avail[7]            <= up_right_avail_r && (~i_constrained_intra_pred_flag||predmode_up7) &&
                                        (~i_last_col ||xTu[5:2] + + trafoSize[5:2]+6 < i_last_col_width[6:2]);

        end else if (trafoSize[4] == 1) begin
            o_left_avail[1]          <= xTu !=0 && (~i_constrained_intra_pred_flag||predmode_left0);
            o_left_avail[2]          <= xTu !=0 && (~i_constrained_intra_pred_flag||predmode_left1);
            o_left_avail[3]          <= left_bottom_avail_r && (~i_constrained_intra_pred_flag||predmode_left2);
            o_left_avail[4]          <= left_bottom_avail_r && (~i_constrained_intra_pred_flag||predmode_left3) &&
                                        (~i_last_row ||yTu[5:2] + trafoSize[5:2]+ 2 < i_last_row_height[6:2]);

            o_up_avail[0]            <= yTu !=0 && (~i_constrained_intra_pred_flag||predmode_up0);
            o_up_avail[1]            <= yTu !=0 && (~i_constrained_intra_pred_flag||predmode_up1);
            o_up_avail[2]            <= up_right_avail_r && (~i_constrained_intra_pred_flag||predmode_up2);
            o_up_avail[3]            <= up_right_avail_r && (~i_constrained_intra_pred_flag||predmode_up3) &&
                                        (~i_last_col ||xTu[5:2] + trafoSize[5:2]+ 2 < i_last_col_width[6:2]);


        end else if (trafoSize[2] == 1) begin
            o_left_avail[1]          <= xTu !=0 && (~i_constrained_intra_pred_flag||predmode_left0);
            o_left_avail[2]          <= left_bottom_avail_r && (~i_constrained_intra_pred_flag||predmode_left1);

            o_up_avail[0]            <= yTu !=0 && (~i_constrained_intra_pred_flag||predmode_up0);
            o_up_avail[1]            <= up_right_avail_r && (~i_constrained_intra_pred_flag||predmode_up1);
        end else begin //trafoSize=4
            o_left_avail[1]          <= xTu !=0 && (~i_constrained_intra_pred_flag||predmode_left0);
            o_left_avail[2]          <= left_bottom_avail_r && (~i_constrained_intra_pred_flag||predmode_left0);

            o_up_avail[0]            <= yTu !=0 && (~i_constrained_intra_pred_flag||predmode_up0);
            o_up_avail[1]            <= up_right_avail_r && (~i_constrained_intra_pred_flag||predmode_up0);
        end

        o_left_avail_sz8x8[1]        <= xTu !=0 && (~i_constrained_intra_pred_flag||predmode_left0);
        o_left_avail_sz8x8[2]        <= left_bottom_avail_sz8x8_r && (~i_constrained_intra_pred_flag||predmode_left1);

        o_up_avail_sz8x8[0]          <= yTu !=0 && (~i_constrained_intra_pred_flag||predmode_up0);
        o_up_avail_sz8x8[1]          <= up_right_avail_sz8x8_r && (~i_constrained_intra_pred_flag||predmode_up1);

        stage                        <= 3;
        o_avail_done                 <= 1;
    end

end else begin

end


`ifdef RANDOM_INIT
integer  seed;
integer random_val;
initial  begin
    seed                               = $get_initial_random_seed(); 
    random_val                         = $random(seed);

    o_left_avail                       = {random_val,random_val};
    o_up_avail                         = {random_val[1:0],random_val[31:2],random_val[1:0],random_val[31:2]};
    o_left_avail_sz8x8                 = {random_val[2:0],random_val[31:3],random_val[2:0],random_val[31:3]};
    o_up_avail_sz8x8                   = {random_val[3:0],random_val[31:4],random_val[3:0],random_val[31:4]};
    o_up_avail_sz8x8                   = {random_val[4:0],random_val[31:5],random_val[4:0],random_val[31:5]};
    x0                                 = {random_val[5:0],random_val[31:6],random_val[5:0],random_val[31:6]};
    y0                                 = {random_val[6:0],random_val[31:7],random_val[6:0],random_val[31:7]};
    xTu                                = {random_val[7:0],random_val[31:8],random_val[7:0],random_val[31:8]};
    yTu                                = {random_val[8:0],random_val[31:9],random_val[8:0],random_val[31:9]};
    log2TrafoSize                      = {random_val[9:0],random_val[31:10],random_val[9:0],random_val[31:10]};
    trafoSize                          = {random_val[10:0],random_val[31:11],random_val[10:0],random_val[31:11]};
    cIdx                               = {random_val[11:0],random_val[31:12],random_val[11:0],random_val[31:12]};
    left_bottom_avail                  = {random_val[12:0],random_val[31:13],random_val[12:0],random_val[31:13]};
    up_right_avail                     = {random_val[13:0],random_val[31:14],random_val[13:0],random_val[31:14]};
    leftup_avail                       = {random_val[14:0],random_val[31:15],random_val[14:0],random_val[31:15]};
    left_bottom_avail_r                = {random_val[15:0],random_val[31:16],random_val[15:0],random_val[31:16]};
    up_right_avail_r                   = {random_val[16:0],random_val[31:17],random_val[16:0],random_val[31:17]};
    predmode_leftup                    = {random_val[17:0],random_val[31:18],random_val[17:0],random_val[31:18]};
    predmode_up0                       = {random_val[18:0],random_val[31:19],random_val[18:0],random_val[31:19]};
    predmode_up1                       = {random_val[19:0],random_val[31:20],random_val[19:0],random_val[31:20]};
    predmode_up2                       = {random_val[20:0],random_val[31:21],random_val[20:0],random_val[31:21]};
    predmode_up3                       = {random_val[21:0],random_val[31:22],random_val[21:0],random_val[31:22]};
    predmode_up4                       = {random_val[22:0],random_val[31:23],random_val[22:0],random_val[31:23]};
    predmode_up5                       = {random_val[23:0],random_val[31:24],random_val[23:0],random_val[31:24]};
    predmode_up6                       = {random_val[24:0],random_val[31:25],random_val[24:0],random_val[31:25]};
    predmode_up7                       = {random_val[25:0],random_val[31:26],random_val[25:0],random_val[31:26]};
    predmode_left0                     = {random_val[26:0],random_val[31:27],random_val[26:0],random_val[31:27]};
    predmode_left1                     = {random_val[27:0],random_val[31:28],random_val[27:0],random_val[31:28]};
    predmode_left2                     = {random_val[28:0],random_val[31:29],random_val[28:0],random_val[31:29]};
    predmode_left3                     = {random_val[29:0],random_val[31:30],random_val[29:0],random_val[31:30]};
    predmode_left4                     = {random_val[30:0],random_val[31],random_val[30:0],random_val[31]};
    predmode_left5                     = {random_val[31:0],random_val[31:0]};
    predmode_left6                     = {random_val,random_val};
    predmode_left7                     = {random_val[1:0],random_val[31:2],random_val[1:0],random_val[31:2]};
    stage                              = {random_val[2:0],random_val[31:3],random_val[2:0],random_val[31:3]};
    x_left_bottom_most                 = {random_val[4:0],random_val[31:5],random_val[4:0],random_val[31:5]};
    y_left_bottom_most                 = {random_val[5:0],random_val[31:6],random_val[5:0],random_val[31:6]};
    x_left_bottom_nb                   = {random_val[6:0],random_val[31:7],random_val[6:0],random_val[31:7]};
    y_left_bottom_nb                   = {random_val[7:0],random_val[31:8],random_val[7:0],random_val[31:8]};
    x_up_right_most                    = {random_val[8:0],random_val[31:9],random_val[8:0],random_val[31:9]};
    y_up_right_most                    = {random_val[9:0],random_val[31:10],random_val[9:0],random_val[31:10]};
    x_up_right_nb                      = {random_val[10:0],random_val[31:11],random_val[10:0],random_val[31:11]};
    y_up_right_nb                      = {random_val[11:0],random_val[31:12],random_val[11:0],random_val[31:12]};
    zorder_left_bottom                 = {random_val[12:0],random_val[31:13],random_val[12:0],random_val[31:13]};
    zorder_left_bottom_nb              = {random_val[13:0],random_val[31:14],random_val[13:0],random_val[31:14]};
    zorder_up_right                    = {random_val[14:0],random_val[31:15],random_val[14:0],random_val[31:15]};
    zorder_up_right_nb                 = {random_val[15:0],random_val[31:16],random_val[15:0],random_val[31:16]};
    x_left_bottom_most_sz8x8           = {random_val[16:0],random_val[31:17],random_val[16:0],random_val[31:17]};
    y_left_bottom_most_sz8x8           = {random_val[17:0],random_val[31:18],random_val[17:0],random_val[31:18]};
    x_left_bottom_nb_sz8x8             = {random_val[18:0],random_val[31:19],random_val[18:0],random_val[31:19]};
    y_left_bottom_nb_sz8x8             = {random_val[19:0],random_val[31:20],random_val[19:0],random_val[31:20]};
    x_up_right_most_sz8x8              = {random_val[20:0],random_val[31:21],random_val[20:0],random_val[31:21]};
    y_up_right_most_sz8x8              = {random_val[21:0],random_val[31:22],random_val[21:0],random_val[31:22]};
    x_up_right_nb_sz8x8                = {random_val[22:0],random_val[31:23],random_val[22:0],random_val[31:23]};
    y_up_right_nb_sz8x8                = {random_val[23:0],random_val[31:24],random_val[23:0],random_val[31:24]};
    zorder_left_bottom_sz8x8           = {random_val[24:0],random_val[31:25],random_val[24:0],random_val[31:25]};
    zorder_left_bottom_nb_sz8x8        = {random_val[25:0],random_val[31:26],random_val[25:0],random_val[31:26]};
    zorder_up_right_sz8x8              = {random_val[26:0],random_val[31:27],random_val[26:0],random_val[31:27]};
    zorder_up_right_nb_sz8x8           = {random_val[27:0],random_val[31:28],random_val[27:0],random_val[31:28]};
    left_bottom_avail_sz8x8            = {random_val[28:0],random_val[31:29],random_val[28:0],random_val[31:29]};
    up_right_avail_sz8x8               = {random_val[29:0],random_val[31:30],random_val[29:0],random_val[31:30]};
    left_bottom_avail_sz8x8_r          = {random_val[30:0],random_val[31],random_val[30:0],random_val[31]};
    up_right_avail_sz8x8_r             = {random_val[31:0],random_val[31:0]};
end
`endif

endmodule
