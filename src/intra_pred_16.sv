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

module intra_pred_16
(
 input wire                          clk                ,
 input wire                          rst                ,
 input wire                          global_rst         ,
 input wire                          en                 ,
 input wire             [15:0]       i_slice_num        ,
 input wire  [`max_x_bits-1:0]       i_x0               ,
 input wire  [`max_y_bits-1:0]       i_y0               ,
 input wire             [ 4:0]       i_xTu              , //色度坐标
 input wire             [ 4:0]       i_yTu              ,

 input wire             [ 2:0]       i_log2TrafoSize    ,
 input wire             [ 4:0]       i_trafoSize        ,
 input wire             [ 1:0]       i_cIdx             ,

 input wire       [31:0][ 7:0]       i_line_buf_left    ,
 input wire       [47:0][ 7:0]       i_line_buf_top     ,
 input wire       [ 7:0][ 7:0]       i_leftup           ,
 input wire                          i_sz4x4_blk3       ,

 input wire             [ 5:0]       i_intra_predmode   , //0~34

 output reg             [31:0]       dram_pred_we       ,
 output reg       [31:0][ 4:0]       dram_pred_addr     ,
 output reg       [31:0][ 7:0]       dram_pred_din      ,


 input wire             [31:0]       fd_log             ,

 input wire             [ 8:0]       i_left_avail       , //包括leftup
 input wire             [ 7:0]       i_up_avail         ,
 input wire                          i_avail_done       ,
 output reg             [ 5:0]       o_pred_done_y      ,
 output reg             [ 3:0]       o_intra_pred_state

);

parameter ref_pick_top           = 2'b00; //上+右上
parameter ref_pick_left          = 2'b01;
parameter ref_pick_partial_left  = 2'b10; //左一部分+上
parameter ref_pick_partial_top   = 2'b11;

reg     [`max_x_bits-1:0]     x0                      ;
reg     [`max_y_bits-1:0]     y0                      ;
reg     [ 4:0]                xTu                     ;
reg     [ 4:0]                yTu                     ;
reg     [ 3:0]                x                       ;
reg     [ 3:0]                y                       ;

reg     [  5:0]               intra_predmode          ;

reg     [  2:0]               log2TrafoSize           ;
reg     [  4:0]               trafoSize               ;
reg     [  1:0]               trafoSize_bit4to2_minus1;
reg     [  1:0]               cIdx                    ;
reg     [  8:0]               left_avail              ;
reg     [  7:0]               up_avail                ;
reg     [  8:0]               left_avail_bk           ;
reg     [  7:0]               up_avail_bk             ;

reg     [ 31:0][ 7:0]         pleft                ;
reg     [ 31:0][ 7:0]         ptop                 ;
reg     [ 15:0][ 7:0]         pleft_copy           ;
reg     [ 15:0][ 7:0]         ptop_copy            ;
reg     [ 15:0][ 7:0]         ptop_bk              ;

reg     [ 7:0]                leftup               ;
reg     [ 31:0][ 7:0]         pleft_w              ;
reg     [ 31:0][ 7:0]         ptop_w               ;
reg     [ 7:0]                leftup_w             ;
reg     [13:0]                pleft_tmp            ;
reg     [13:0]                ptop_tmp             ;


reg     [ 2:0]                sub_i                ;
reg     [ 4:0]                filter_i             ;

reg     [ 3:0]                phase                ;
reg     [ 2:0]                stage                ;
reg                           valid                ;
wire    [16:0]                avail_sz_16x16       ;
wire    [ 8:0]                avail_sz_8x8         ;
wire    [ 4:0]                avail_sz_4x4         ;

assign avail_sz_16x16 = {left_avail[8],left_avail[7],left_avail[6],left_avail[5],
                          left_avail[4],left_avail[3],left_avail[2],left_avail[1],left_avail[0],
                          up_avail[0],up_avail[1],up_avail[2],up_avail[3],
                          up_avail[4],up_avail[5],up_avail[6],up_avail[7]};
                          
assign avail_sz_8x8 = {left_avail[4],left_avail[3],left_avail[2],left_avail[1],left_avail[0],
                          up_avail[0],up_avail[1],up_avail[2],up_avail[3]};
assign avail_sz_4x4 = {left_avail[2],left_avail[1],left_avail[0],
                          up_avail[0],up_avail[1]};


genvar i;
generate
    for (i=1;i<=7;i++)
    begin: left_label
        always @(*)
        begin
            if (~left_avail[i])
                pleft_w[4*i-1:4*(i-1)]  = {4{pleft[4*i]}};
            else
                pleft_w[4*i-1:4*(i-1)]  = pleft[4*i-1:4*(i-1)];
        end
    end
endgenerate

generate
    for (i=1;i<8;i++)
    begin: up_label
        always @(*)
        begin
            if (~up_avail[i])
                ptop_w[4*i+3:4*i]  = {4{ptop[4*i-1]}};
            else
                ptop_w[4*i+3:4*i]  = ptop[4*i+3:4*i];
        end
    end
endgenerate

always @(*)
begin
    if (~up_avail[0])
        ptop_w[3:0]        = {4{leftup}};
    else
        ptop_w[3:0]        = ptop[3:0];
end

always @(*)
begin
    if (left_avail[0])
        leftup_w         = leftup;
    else
        leftup_w         = pleft[0];
end


reg         [15:0][ 5:0]             accum_a;
reg         [15:0][ 7:0]             accum_b;
wire        [15:0][23:0]             accum_p;

reg                                  accum_rst;
reg                                  accum_en;
reg         [15:0][ 7:0]             result4x4;
reg         [15:0][ 7:0]             result4x4_copy;
reg         [15:0][ 7:0]             result4x4_planar_w;
wire        [15:0][ 7:0]             result4x4_angular_w;

//planar
generate
    for (i=0;i<16;i++)
    begin: result_planar_label
        always @(accum_p[i] or log2TrafoSize)
        begin
            case (log2TrafoSize)
                2: result4x4_planar_w[i]  = (accum_p[i]+4)>>3;
                3: result4x4_planar_w[i]  = (accum_p[i]+8)>>4;
                default: result4x4_planar_w[i]  = (accum_p[i]+16)>>5;
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

reg               [ 1: 0]     pick_ref              ;
reg               [13: 0]     dc_sum                ;
reg               [ 3: 0]     sum_i                 ;
reg               [ 7: 0]     dcVal                 ;

reg  [ 0: 7][15: 0][ 4: 0]    ref_partial_pick_tab   ;
reg         [15: 0][ 4: 0]    ref_pick_idx           ;
reg         [32: 0][ 7: 0]    ref_r                  ;
reg  [ 3: 0][16: 0][ 7: 0]    ref4                   ;
reg         [32: 0][ 7: 0]    ref_bk                 ;

wire        [32: 0][ 7: 0]    ref_w                  ;

reg  [ 0:16][ 0:15][ 4: 0]    iFact_tab              ;
reg         [ 0:15][ 4: 0]    iFact_idx              ;
reg         [ 0:16][ 0:15]    iIdx_delta_tab         ; //当前iIdx和上个iIdx差
reg                [ 0:15]    iIdx_delta_idx         ;

//这里只是partial_left,partial_top的情况，ref_pick_top和ref_pick_left全部用上面和左边
assign ref_w[16] = leftup;
generate
    for (i=0;i<16;i++)
    begin: ref_pick_label1
        assign ref_w[i] = pick_ref == ref_pick_partial_left?pleft[ref_pick_idx[15-i]]:ptop[ref_pick_idx[15-i]];
    end
endgenerate

generate
    for (i=17;i<=32;i++)
    begin: ref_pick_label2
        assign ref_w[i] = pick_ref == ref_pick_partial_left?ptop[i-17]:pleft[i-17];
    end
endgenerate

initial begin
    ref_partial_pick_tab = {
        {5'd0, 5'd0, 5'd0, 5'd0, 5'd0, 5'd0, 5'd0, 5'd0, 5'd0, 5'd0, 5'd0, 5'd0, 5'd0, 5'd0, 5'd0, 5'd15},
        {5'd0, 5'd0, 5'd0, 5'd0, 5'd0, 5'd0, 5'd0, 5'd0, 5'd0, 5'd0, 5'd0, 5'd0, 5'd0, 5'd0, 5'd12, 5'd5},
        {5'd0, 5'd0, 5'd0, 5'd0, 5'd0, 5'd0, 5'd0, 5'd0, 5'd0, 5'd0, 5'd0, 5'd0, 5'd13, 5'd10, 5'd6, 5'd3},
        {5'd0, 5'd0, 5'd0, 5'd0, 5'd0, 5'd0, 5'd0, 5'd0, 5'd0, 5'd16, 5'd14, 5'd11, 5'd9, 5'd6, 5'd4, 5'd1},
        {5'd0, 5'd0, 5'd0, 5'd0, 5'd0, 5'd0, 5'd0, 5'd16, 5'd14, 5'd12, 5'd10, 5'd8, 5'd7, 5'd5, 5'd3, 5'd1},
        {5'd0, 5'd0, 5'd0, 5'd0, 5'd0, 5'd16, 5'd14, 5'd13, 5'd11, 5'd10, 5'd8, 5'd7, 5'd5, 5'd4, 5'd2, 5'd1},
        {5'd0, 5'd0, 5'd16, 5'd15, 5'd14, 5'd13, 5'd11, 5'd10, 5'd9, 5'd8, 5'd6, 5'd5, 5'd4, 5'd3, 5'd1, 5'd0},
        {5'd15, 5'd14, 5'd13, 5'd12, 5'd11, 5'd10, 5'd9, 5'd8, 5'd7, 5'd6, 5'd5, 5'd4, 5'd3, 5'd2, 5'd1, 5'd0}
    };
    iFact_tab = {
        {5'd0, 5'd0, 5'd0, 5'd0, 5'd0, 5'd0, 5'd0, 5'd0, 5'd0, 5'd0, 5'd0, 5'd0, 5'd0, 5'd0, 5'd0, 5'd0},
        {5'd26, 5'd20, 5'd14, 5'd8, 5'd2, 5'd28, 5'd22, 5'd16, 5'd10, 5'd4, 5'd30, 5'd24, 5'd18, 5'd12, 5'd6, 5'd0},
        {5'd21, 5'd10, 5'd31, 5'd20, 5'd9, 5'd30, 5'd19, 5'd8, 5'd29, 5'd18, 5'd7, 5'd28, 5'd17, 5'd6, 5'd27, 5'd16},
        {5'd17, 5'd2, 5'd19, 5'd4, 5'd21, 5'd6, 5'd23, 5'd8, 5'd25, 5'd10, 5'd27, 5'd12, 5'd29, 5'd14, 5'd31, 5'd16},
        {5'd13, 5'd26, 5'd7, 5'd20, 5'd1, 5'd14, 5'd27, 5'd8, 5'd21, 5'd2, 5'd15, 5'd28, 5'd9, 5'd22, 5'd3, 5'd16},
        {5'd9, 5'd18, 5'd27, 5'd4, 5'd13, 5'd22, 5'd31, 5'd8, 5'd17, 5'd26, 5'd3, 5'd12, 5'd21, 5'd30, 5'd7, 5'd16},
        {5'd5, 5'd10, 5'd15, 5'd20, 5'd25, 5'd30, 5'd3, 5'd8, 5'd13, 5'd18, 5'd23, 5'd28, 5'd1, 5'd6, 5'd11, 5'd16},
        {5'd2, 5'd4, 5'd6, 5'd8, 5'd10, 5'd12, 5'd14, 5'd16, 5'd18, 5'd20, 5'd22, 5'd24, 5'd26, 5'd28, 5'd30, 5'd0},
        {5'd0, 5'd0, 5'd0, 5'd0, 5'd0, 5'd0, 5'd0, 5'd0, 5'd0, 5'd0, 5'd0, 5'd0, 5'd0, 5'd0, 5'd0, 5'd0},
        {5'd30, 5'd28, 5'd26, 5'd24, 5'd22, 5'd20, 5'd18, 5'd16, 5'd14, 5'd12, 5'd10, 5'd8, 5'd6, 5'd4, 5'd2, 5'd0},
        {5'd27, 5'd22, 5'd17, 5'd12, 5'd7, 5'd2, 5'd29, 5'd24, 5'd19, 5'd14, 5'd9, 5'd4, 5'd31, 5'd26, 5'd21, 5'd16},
        {5'd23, 5'd14, 5'd5, 5'd28, 5'd19, 5'd10, 5'd1, 5'd24, 5'd15, 5'd6, 5'd29, 5'd20, 5'd11, 5'd2, 5'd25, 5'd16},
        {5'd19, 5'd6, 5'd25, 5'd12, 5'd31, 5'd18, 5'd5, 5'd24, 5'd11, 5'd30, 5'd17, 5'd4, 5'd23, 5'd10, 5'd29, 5'd16},
        {5'd15, 5'd30, 5'd13, 5'd28, 5'd11, 5'd26, 5'd9, 5'd24, 5'd7, 5'd22, 5'd5, 5'd20, 5'd3, 5'd18, 5'd1, 5'd16},
        {5'd11, 5'd22, 5'd1, 5'd12, 5'd23, 5'd2, 5'd13, 5'd24, 5'd3, 5'd14, 5'd25, 5'd4, 5'd15, 5'd26, 5'd5, 5'd16},
        {5'd6, 5'd12, 5'd18, 5'd24, 5'd30, 5'd4, 5'd10, 5'd16, 5'd22, 5'd28, 5'd2, 5'd8, 5'd14, 5'd20, 5'd26, 5'd0},
        {5'd0, 5'd0, 5'd0, 5'd0, 5'd0, 5'd0, 5'd0, 5'd0, 5'd0, 5'd0, 5'd0, 5'd0, 5'd0, 5'd0, 5'd0, 5'd0}
    };

    iIdx_delta_tab = {
        {1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1}, //[0]
        {1'b0, 1'b1, 1'b1, 1'b1, 1'b1, 1'b0, 1'b1, 1'b1, 1'b1, 1'b1, 1'b0, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1}, //[1]
        {1'b0, 1'b1, 1'b0, 1'b1, 1'b1, 1'b0, 1'b1, 1'b1, 1'b0, 1'b1, 1'b1, 1'b0, 1'b1, 1'b1, 1'b0, 1'b1}, //[2]
        {1'b0, 1'b1, 1'b0, 1'b1, 1'b0, 1'b1, 1'b0, 1'b1, 1'b0, 1'b1, 1'b0, 1'b1, 1'b0, 1'b1, 1'b0, 1'b1}, //[3]
        {1'b0, 1'b0, 1'b1, 1'b0, 1'b1, 1'b0, 1'b0, 1'b1, 1'b0, 1'b1, 1'b0, 1'b0, 1'b1, 1'b0, 1'b1, 1'b0}, //[4]
        {1'b0, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 1'b0, 1'b1, 1'b0}, //[5]
        {1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 1'b0}, //[6]
        {1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b1}, //[7]
        {1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0}, //[8]

        {1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0}, //[9]
        {1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 1'b0}, //[10]
        {1'b0, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 1'b0, 1'b1, 1'b0}, //[11]
        {1'b0, 1'b0, 1'b1, 1'b0, 1'b1, 1'b0, 1'b0, 1'b1, 1'b0, 1'b1, 1'b0, 1'b0, 1'b1, 1'b0, 1'b1, 1'b0}, //[12]
        {1'b0, 1'b1, 1'b0, 1'b1, 1'b0, 1'b1, 1'b0, 1'b1, 1'b0, 1'b1, 1'b0, 1'b1, 1'b0, 1'b1, 1'b0, 1'b1}, //[13]
        {1'b0, 1'b1, 1'b0, 1'b1, 1'b1, 1'b0, 1'b1, 1'b1, 1'b0, 1'b1, 1'b1, 1'b0, 1'b1, 1'b1, 1'b0, 1'b1}, //[14]
        {1'b0, 1'b1, 1'b1, 1'b1, 1'b1, 1'b0, 1'b1, 1'b1, 1'b1, 1'b1, 1'b0, 1'b1, 1'b1, 1'b1, 1'b1, 1'b0}, //[15]
        {1'b0, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1} //[16]
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
                    accum_a[4*i  ]  <= y+i+1;
                    accum_b[4*i  ]  <= pleft_ntbs;
                    accum_a[4*i+1]  <= y+i+1;
                    accum_b[4*i+1]  <= pleft_ntbs;
                    accum_a[4*i+2]  <= y+i+1;
                    accum_b[4*i+2]  <= pleft_ntbs;
                    accum_a[4*i+3]  <= y+i+1;
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
                    if (pick_ref==ref_pick_partial_top||
                        pick_ref==ref_pick_left) begin
                        accum_a[4*i  ]  <= 32-iFact_idx[0];
                        accum_a[4*i+1]  <= 32-iFact_idx[1];
                        accum_a[4*i+2]  <= 32-iFact_idx[2];
                        accum_a[4*i+3]  <= 32-iFact_idx[3];

                        accum_b[4*i  ]  <= ref4[0][i];
                        accum_b[4*i+1]  <= ref4[1][i];
                        accum_b[4*i+2]  <= ref4[2][i];
                        accum_b[4*i+3]  <= ref4[3][i];
                    end else begin
                        accum_a[4*i  ]  <= 32-iFact_idx[i];
                        accum_a[4*i+1]  <= 32-iFact_idx[i];
                        accum_a[4*i+2]  <= 32-iFact_idx[i];
                        accum_a[4*i+3]  <= 32-iFact_idx[i];

                        accum_b[4*i  ]  <= ref4[i][0];
                        accum_b[4*i+1]  <= ref4[i][1];
                        accum_b[4*i+2]  <= ref4[i][2];
                        accum_b[4*i+3]  <= ref4[i][3];
                    end

                end else if (stage==3)begin
                    if (pick_ref==ref_pick_partial_top||
                        pick_ref==ref_pick_left) begin
                        accum_a[4*i  ]  <= iFact_idx[0];
                        accum_a[4*i+1]  <= iFact_idx[1];
                        accum_a[4*i+2]  <= iFact_idx[2];
                        accum_a[4*i+3]  <= iFact_idx[3];

                        accum_b[4*i  ]  <= intra_predmode==2?0:ref4[0][i+1]; //越界取x,0*x=x
                        accum_b[4*i+1]  <= intra_predmode==2?0:ref4[1][i+1];
                        accum_b[4*i+2]  <= intra_predmode==2?0:ref4[2][i+1];
                        accum_b[4*i+3]  <= intra_predmode==2?0:ref4[3][i+1];
                    end else begin
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
reg  [ 3:0]    x_to_store;
reg  [ 3:0]    y_to_store;
reg  [ 4:0]    store_x;
reg  [ 4:0]    store_y;
reg  [ 1:0]    store_i;
reg            last4x4_in_row;

always @ (posedge clk)
if (global_rst) begin
    o_pred_done_y         <= 6'b111111;
    dram_pred_we          <= 32'd0;
end else if (rst) begin
    store_stage           <= 0;
    dram_pred_we          <= 32'd0;
    o_pred_done_y         <= 6'b111111;
end else begin
    if (store_stage == 0 && kick_store) begin
        store_x           <= x_to_store+xTu;
        store_y           <= y_to_store+yTu;
        store_i           <= 0;
        store_stage       <= 1;
        store_done        <= 0;
        result4x4_copy    <= result4x4;
        last4x4_in_row    <= x_to_store[3:2] == trafoSize_bit4to2_minus1;
        if (`log_p &&i_slice_num>=`slice_begin && i_slice_num<=`slice_end) begin
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

        case (store_x[4:2])
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
                dram_pred_din[19:16]          <= result4x4_copy[3:0];
                dram_pred_we[19:16]           <= {4{1'b1}};
                dram_pred_addr[19:16]         <= {4{store_y}};
            end
            5: begin
                dram_pred_din[23:20]          <= result4x4_copy[3:0];
                dram_pred_we[23:20]           <= {4{1'b1}};
                dram_pred_addr[23:20]         <= {4{store_y}};
            end
            6: begin
                dram_pred_din[27:24]         <= result4x4_copy[3:0];
                dram_pred_we[27:24]          <= {4{1'b1}};
                dram_pred_addr[27:24]        <= {4{store_y}};
            end
            7: begin
                dram_pred_din[31:28]        <= result4x4_copy[3:0];
                dram_pred_we[31:28]         <= {4{1'b1}};
                dram_pred_addr[31:28]       <= {4{store_y}};
            end
        endcase
        if (last4x4_in_row)
            o_pred_done_y                   <= {1'b0,store_y};

        if (store_i == 3) begin
            store_done         <= 1;
            store_i            <= 0;
            store_stage        <= 0;
        end
    end
end


wire     [4:0]     x_tu_tmp            ;
wire     [4:0]     y_tu_tmp            ;
//cr沿用cb保存的
assign x_tu_tmp = i_cIdx==1?i_xTu:xTu;
assign y_tu_tmp = i_cIdx==1?i_yTu:yTu;

wire     [5:0]     intra_predmode_tmp  ;

assign intra_predmode_tmp = i_cIdx==1?i_intra_predmode:intra_predmode;

always @ (posedge clk)
if (global_rst) begin
    o_intra_pred_state           <= `intra_pred_end;
    kick_store                   <= 0;
end else if (rst) begin
    //cr延用cb的
    if (i_cIdx==1) begin
        x0                       <= i_x0;
        y0                       <= i_y0;
        xTu                      <= i_xTu;
        yTu                      <= i_yTu;
        intra_predmode           <= i_intra_predmode;
        log2TrafoSize            <= i_log2TrafoSize;
        trafoSize                <= i_trafoSize;
        trafoSize_bit4to2_minus1 <= i_trafoSize[4:2]-1;
    end
    if (i_cIdx==1) begin
        operand1                 <= i_trafoSize-1;
        operand2                 <= i_trafoSize-1;
    end else begin
        operand1                 <= trafoSize-1;
        operand2                 <= trafoSize-1;
    end

    x                            <= 0;
    y                            <= 0;
    dc_sum                       <= i_cIdx==1?i_trafoSize:trafoSize;


    cIdx                         <= i_cIdx;
    case (y_tu_tmp[4:2])
    0: pleft   <= i_line_buf_left;
    1: pleft   <= {{4{8'd0}},i_line_buf_left[31:4]};
    2: pleft   <= {{8{8'd0}},i_line_buf_left[31:8]};
    3: pleft   <= {{12{8'd0}},i_line_buf_left[31:12]};
    4: pleft   <= {{16{8'd0}},i_line_buf_left[31:16]};
    5: pleft   <= {{20{8'd0}},i_line_buf_left[31:20]};
    6: pleft   <= {{24{8'd0}},i_line_buf_left[31:24]};
    7: pleft   <= {{28{8'd0}},i_line_buf_left[31:28]};
    endcase

    case (x_tu_tmp[4:2])
    0: ptop   <= i_line_buf_top[31:0];
    1: ptop   <= i_line_buf_top[35:4];
    2: ptop   <= i_line_buf_top[39:8];
    3: ptop   <= i_line_buf_top[43:12];
    4: ptop   <= i_line_buf_top[47:16];
    5: ptop   <= {{4{8'd0}},i_line_buf_top[47:20]};
    6: ptop   <= {{8{8'd0}},i_line_buf_top[47:24]};
    7: ptop   <= {{12{8'd0}},i_line_buf_top[47:28]};
    endcase

    leftup                   <= i_cIdx==1?i_leftup[i_yTu[4:2]]:i_leftup[yTu[4:2]];
    pleft_tmp                <= 14'd0;
    ptop_tmp                 <= 14'd0;

    phase                    <= 0;
    stage                    <= 0;

    case (intra_predmode_tmp)
    11,12,13,14,15,16,17          : ref_pick_idx  <= ref_partial_pick_tab[intra_predmode_tmp-11];
    18,19,20,21,22,23,24,25       : ref_pick_idx  <= ref_partial_pick_tab[25-intra_predmode_tmp];
    default                       : ref_pick_idx  <= ref_partial_pick_tab[7];
    endcase

    case (intra_predmode_tmp)
    2,3,4,5,6,7,8,9,10            : pick_ref  <= ref_pick_left;
    11,12,13,14,15,16,17          : pick_ref  <= ref_pick_partial_top;
    18,19,20,21,22,23,24,25       : pick_ref  <= ref_pick_partial_left;
    26,27,28,29,30,31,32,33,34    : pick_ref  <= ref_pick_top;
    default                       : pick_ref  <= ref_pick_top;
    endcase

    if (intra_predmode_tmp<=18)
        iIdx_delta_idx   <= iIdx_delta_tab[intra_predmode_tmp-2];
    else
        iIdx_delta_idx   <= iIdx_delta_tab[34-intra_predmode_tmp];

    if (intra_predmode_tmp <= 18)
        iFact_idx        <= iFact_tab[intra_predmode_tmp-2];
    else
        iFact_idx        <= iFact_tab[34-intra_predmode_tmp];

    if (`log_p && i_slice_num>=`slice_begin && i_slice_num<=`slice_end) begin
        if (i_cIdx==1)
            $fdisplay(fd_log, "intrapred xTbY %0d yTbY %0d cIdx %0d log2TrafoSize %0d slice_num %0d",
                   {i_x0[`max_x_bits-1:6],i_xTu,1'b0},
                   {i_y0[`max_y_bits-1:6],i_yTu,1'b0},i_cIdx,i_log2TrafoSize,i_slice_num);
        else
            $fdisplay(fd_log, "intrapred xTbY %0d yTbY %0d cIdx %0d log2TrafoSize %0d slice_num %0d",
                   {x0[`max_x_bits-1:6],xTu,1'b0},
                   {y0[`max_y_bits-1:6],yTu,1'b0},i_cIdx,log2TrafoSize,i_slice_num);
    end
    if (i_cIdx==1&&i_sz4x4_blk3) begin
        left_avail                      <= i_left_avail;
        left_avail_bk                   <= i_left_avail;
        up_avail                        <= i_up_avail;
        up_avail_bk                     <= i_up_avail;
        o_intra_pred_state              <= `intra_pred_substitute1;
    end else if (i_cIdx==2) begin
        left_avail                      <= left_avail_bk;
        up_avail                        <= up_avail_bk;
        o_intra_pred_state              <= `intra_pred_substitute1;
    end else begin
        o_intra_pred_state              <= `intra_pred_wait_nb;
    end
end else if (en) begin
    case (o_intra_pred_state)
    `intra_pred_wait_nb:
        if (i_avail_done) begin
            left_avail                   <= i_left_avail; //left_avail,up_avail在substitute过程中会修改
            left_avail_bk                <= i_left_avail;
            up_avail                     <= i_up_avail;
            up_avail_bk                  <= i_up_avail;
            o_intra_pred_state           <= `intra_pred_substitute1;
        end
    `intra_pred_substitute1://3
        begin
            if (left_avail == 0&&up_avail == 0) begin
                leftup                    <= 8'd128;
                pleft                     <= {32{8'd128}};
                ptop                      <= {32{8'd128}};
                if (intra_predmode == `INTRA_DC)
                    o_intra_pred_state    <= `intra_pred_dc;
                else if (intra_predmode == `INTRA_PLANAR)
                    o_intra_pred_state    <= `intra_pred_planar;
                else
                    o_intra_pred_state    <= `intra_pred_angular;
            end else begin
                //pleft,ptop已在reset时拷贝好,只需处理unavail
                if (trafoSize[4] == 1) begin
                    casez (avail_sz_16x16)
                        17'b0_1???_????_????_???? : pleft[31:28] <= {4{pleft[27]}};
                        17'b0_01??_????_????_???? : pleft[31:28] <= {4{pleft[23]}};
                        17'b0_001?_????_????_???? : pleft[31:28] <= {4{pleft[19]}};
                        17'b0_0001_????_????_???? : pleft[31:28] <= {4{pleft[15]}};
                        17'b0_0000_1???_????_???? : pleft[31:28] <= {4{pleft[11]}};
                        17'b0_0000_01??_????_???? : pleft[31:28] <= {4{pleft[7]}};
                        17'b0_0000_001?_????_???? : pleft[31:28] <= {4{pleft[3]}};
                        17'b0_0000_0001_????_???? : pleft[31:28] <= {4{leftup}};
                        17'b0_0000_0000_1???_???? : pleft[31:28] <= {4{ptop[0]}};
                        17'b0_0000_0000_01??_???? : pleft[31:28] <= {4{ptop[4]}};
                        17'b0_0000_0000_001?_???? : pleft[31:28] <= {4{ptop[8]}};
                        17'b0_0000_0000_0001_???? : pleft[31:28] <= {4{ptop[12]}};
                        17'b0_0000_0000_0000_1??? : pleft[31:28] <= {4{ptop[16]}};
                        17'b0_0000_0000_0000_01?? : pleft[31:28] <= {4{ptop[20]}};
                        17'b0_0000_0000_0000_001? : pleft[31:28] <= {4{ptop[24]}};
                        17'b0_0000_0000_0000_0001 : pleft[31:28] <= {4{ptop[28]}};
                        default                   : pleft[31:28] <= pleft[31:28];
                    endcase
                    left_avail[8]                                <= 1;
                end else if (trafoSize[3] == 1) begin
                    casez (avail_sz_8x8)
                        9'b0_1???_???? : pleft[15:12] <= {4{pleft[11]}};
                        9'b0_01??_???? : pleft[15:12] <= {4{pleft[7]}};
                        9'b0_001?_???? : pleft[15:12] <= {4{pleft[3]}};
                        9'b0_0001_???? : pleft[15:12] <= {4{leftup}};
                        9'b0_0000_1??? : pleft[15:12] <= {4{ptop[0]}};
                        9'b0_0000_01?? : pleft[15:12] <= {4{ptop[4]}};
                        9'b0_0000_001? : pleft[15:12] <= {4{ptop[8]}};
                        9'b0_0000_0001 : pleft[15:12] <= {4{ptop[12]}};
                        default        : pleft[15:12] <= pleft[15:12];
                   endcase
                   left_avail[4]                      <= 1;
                end else begin
                    casez (avail_sz_4x4)
                        5'b0_1??? : pleft[7:4] <= {4{pleft[3]}};
                        5'b0_01?? : pleft[7:4] <= {4{leftup}};
                        5'b0_001? : pleft[7:4] <= {4{ptop[0]}};
                        5'b0_0001 : pleft[7:4] <= {4{ptop[4]}};
                        default   : pleft[7:4] <= pleft[7:4];
                   endcase
                end
            o_intra_pred_state                 <= `intra_pred_substitute2;
            end
            sub_i                              <= trafoSize[4]?7:3;

        end

    //substitute第二步
    //avail: 0001111001111111,可以左移3个0，再左移4个1，代码太复杂
    //8x8,4x4省不了多少时间，32x32,16x16也无所谓省这点时间
    `intra_pred_substitute2://left左移0
        begin
            if (trafoSize[4] == 1||trafoSize[3] == 1) begin
                if (sub_i == 0) begin
                    leftup                      <= leftup_w;
                    o_intra_pred_state          <= `intra_pred_substitute3;
                end else begin
                    pleft[27:0]                 <= pleft_w[27:0];
                    sub_i                       <= sub_i-1;
                    left_avail[sub_i]           <= 1;
                end
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

    `intra_pred_substitute3:
        begin

            if (trafoSize[4]==1||trafoSize[3]==1) begin
                if (sub_i == (trafoSize[4]?7:3)) begin
                    ptop                        <= ptop_w;
                    accum_rst                   <= 1;
                    if (intra_predmode == `INTRA_DC)
                        o_intra_pred_state      <= `intra_pred_dc;
                    else if (intra_predmode == `INTRA_PLANAR)
                        o_intra_pred_state      <= `intra_pred_planar;
                    else
                        o_intra_pred_state      <= `intra_pred_angular;
                end else begin
                    ptop                        <= ptop_w;
                    sub_i                       <= sub_i+1;
                    up_avail[sub_i]             <= 1;
                end
            end else begin
                case (up_avail[1:0])
                    2'b00: begin ptop[7:0]      <= {8{leftup}};  end
                    2'b01: begin ptop[7:4]      <= {4{ptop[3]}}; end
                    2'b10: begin ptop[3:0]      <= {4{leftup}};  end
                    2'b11: begin                             end
                endcase
                accum_rst                       <= 1;
                if (intra_predmode == `INTRA_DC)
                    o_intra_pred_state          <= `intra_pred_dc;
                else if (intra_predmode == `INTRA_PLANAR)
                    o_intra_pred_state          <= `intra_pred_planar;
                else
                    o_intra_pred_state          <= `intra_pred_angular;
            end
        end

    `intra_pred_planar://9
        begin
            //每行5个周期(phase)
            phase                                 <= phase+1;
            if (phase == 0) begin
                accum_rst                         <= 1;
                ptop_bk                           <= ptop[15:0];
                valid                             <= 0;
                case (log2TrafoSize)
                    2: begin pleft_ntbs <= pleft[4]; ptop_ntbs <= ptop[4]; end
                    3: begin pleft_ntbs <= pleft[8]; ptop_ntbs <= ptop[8]; end
                    default: begin pleft_ntbs <= pleft[16]; ptop_ntbs <= ptop[16]; end
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
                ptop[15:0]                        <= {32'd0,ptop[15:4]};
                accum_rst                         <= 1;
                if (x[3:2] == trafoSize_bit4to2_minus1) begin
                    y                             <= y+4;
                    x                             <= 0;
                    operand1                      <= trafoSize-1;
                    operand2                      <= operand2-4;
                    ptop[15:0]                    <= ptop_bk;
                    pleft[15:0]                   <= {32'd0,pleft[15:4]};
                    if (y[3:2] == trafoSize_bit4to2_minus1) begin
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
            if (phase == 8) begin
                phase                             <= 8;
                if (store_done) begin
                    o_intra_pred_state            <= `intra_pred_end;
                end
            end
        end
    `intra_pred_dc:
        begin
            if (stage == 0) begin//stage0计算dcVal
                dc_sum                            <= dc_sum + pleft[0]+pleft[1]+ptop[0]+ptop[1];
                sum_i                             <= 0;
                pleft_copy                        <= {16'd0,pleft[15:2]};
                ptop_copy                         <= {16'd0,ptop[15:2]};
                ptop_bk                           <= ptop[15:0];
                stage                             <= 1;

            end

            if (stage == 1) begin
                dc_sum                            <= dc_sum + pleft_copy[0]+pleft_copy[1]+ptop_copy[0]+ptop_copy[1];
                pleft_copy                        <= {16'd0,pleft_copy[15:2]};
                ptop_copy                         <= {16'd0,ptop_copy[15:2]};
                sum_i                             <= sum_i+1;
                if (sum_i == trafoSize[4:1]-2)
                    stage                         <= 2;
            end
            if (stage == 2) begin
                case (log2TrafoSize)
                    2: dcVal                      <= dc_sum[10:3];
                    3: dcVal                      <= dc_sum[11:4];
                    default: dcVal                <= dc_sum[12:5];
                endcase
                stage                             <= 3;
            end
            if (stage == 3) begin //stage=1
                result4x4                         <= {16{dcVal}};
                kick_store                        <= 1;
                x                                 <= x+4;
                x_to_store                        <= x;
                y_to_store                        <= y;
                ptop[15:0]                        <= {32'd0,ptop[15:4]};
                stage                             <= 4;
                if (x[3:2] == trafoSize_bit4to2_minus1) begin
                    ptop[15:0]                    <= ptop_bk;
                    pleft[15:0]                   <= {32'd0,pleft[15:4]};
                    y                             <= y+4;
                    x                             <= 0;
                    if (y[3:2] == trafoSize_bit4to2_minus1) begin
                        stage                     <= 5;
                    end
                end

            end
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

    `intra_pred_angular:
        begin
            if (stage == 0) begin //第一阶段填好ref
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

            if ((stage == 1)||
                ((stage==6)&&
                ((pick_ref == ref_pick_top||pick_ref == ref_pick_partial_left)&&(x[3:2] == trafoSize_bit4to2_minus1)||
                (pick_ref == ref_pick_left||pick_ref == ref_pick_partial_top)&&(y[3:2] == trafoSize_bit4to2_minus1)))) begin
                if (pick_ref==ref_pick_partial_top||
                    pick_ref==ref_pick_partial_left) begin
                    ref4[0]                   <= iIdx_delta_idx[0]?ref_bk[31:15]:ref_bk[32:16];
                    case (iIdx_delta_idx[0]+iIdx_delta_idx[1])
                        0: ref4[1]            <= ref_bk[32:16];
                        1: ref4[1]            <= ref_bk[31:15];
                        default: ref4[1]      <= ref_bk[30:14];
                    endcase
                    case (iIdx_delta_idx[0]+iIdx_delta_idx[1]+iIdx_delta_idx[2])
                        0: ref4[2]            <= ref_bk[32:16];
                        1: ref4[2]            <= ref_bk[31:15];
                        2: ref4[2]            <= ref_bk[30:14];
                        default: ref4[2]      <= ref_bk[29:13];
                    endcase
                    case (iIdx_delta_idx[0]+iIdx_delta_idx[1]+iIdx_delta_idx[2]+iIdx_delta_idx[3])
                        0: ref4[3]            <= ref_bk[32:16];
                        1: ref4[3]            <= ref_bk[31:15];
                        2: ref4[3]            <= ref_bk[30:14];
                        3: ref4[3]            <= ref_bk[29:13];
                        default: ref4[3]      <= ref_bk[28:12];
                    endcase
                    case (iIdx_delta_idx[0]+iIdx_delta_idx[1]+iIdx_delta_idx[2]+iIdx_delta_idx[3])
                        0: ref_bk             <= ref_bk;
                        1: ref_bk             <= {ref_bk[31:0],8'd0};
                        2: ref_bk             <= {ref_bk[30:0],16'd0};
                        3: ref_bk             <= {ref_bk[29:0],24'd0};
                        default: ref_bk       <= {ref_bk[28:0],32'd0};
                    endcase
                end else begin
                    ref4[0]                   <= iIdx_delta_idx[0]?ref_bk[17:1]:ref_bk[16:0];
                    case (iIdx_delta_idx[0]+iIdx_delta_idx[1])
                        0: ref4[1]            <= ref_bk[16:0];
                        1: ref4[1]            <= ref_bk[17:1];
                        default: ref4[1]      <= ref_bk[18:2];
                    endcase
                    case (iIdx_delta_idx[0]+iIdx_delta_idx[1]+iIdx_delta_idx[2])
                        0: ref4[2]            <= ref_bk[16:0];
                        1: ref4[2]            <= ref_bk[17:1];
                        2: ref4[2]            <= ref_bk[18:2];
                        default: ref4[2]      <= ref_bk[19:3];
                    endcase
                    case (iIdx_delta_idx[0]+iIdx_delta_idx[1]+iIdx_delta_idx[2]+iIdx_delta_idx[3])
                        0: ref4[3]            <= ref_bk[16:0];
                        1: ref4[3]            <= ref_bk[17:1];
                        2: ref4[3]            <= ref_bk[18:2];
                        3: ref4[3]            <= ref_bk[19:3];
                        default: ref4[3]      <= ref_bk[20:4];
                    endcase
                    case (iIdx_delta_idx[0]+iIdx_delta_idx[1]+iIdx_delta_idx[2]+iIdx_delta_idx[3])
                        0: ref_bk             <= ref_bk;
                        1: ref_bk             <= {8'd0,ref_bk[32:1]};
                        2: ref_bk             <= {16'd0,ref_bk[32:2]};
                        3: ref_bk             <= {24'd0,ref_bk[32:3]};
                        default: ref_bk       <= {32'd0,ref_bk[32:4]};
                    endcase
                end

            end else if (stage == 6) begin
                ref4[3]                       <= {32'd0,ref4[3][16:4]};
                ref4[2]                       <= {32'd0,ref4[2][16:4]};
                ref4[1]                       <= {32'd0,ref4[1][16:4]};
                ref4[0]                       <= {32'd0,ref4[0][16:4]};
            end

            if (stage == 1)
                stage                         <= 2;
            if (stage == 2) begin
                accum_rst                     <= 0;
                kick_store                    <= 0;
                stage                         <= 3;
            end
            if (stage == 3) begin
                stage                         <= 4;
            end
            if (stage == 4) begin
                stage                         <= 5;
                accum_rst                     <= 1;
            end
            if (stage == 5) begin
                result4x4                     <= result4x4_angular_w;
                x_to_store                    <= x;
                y_to_store                    <= y;
                stage                         <= 6;

                if ((pick_ref == ref_pick_top||pick_ref == ref_pick_partial_left)&&(x[3:2] == trafoSize_bit4to2_minus1)||
                    (pick_ref == ref_pick_left||pick_ref == ref_pick_partial_top)&&(y[3:2] == trafoSize_bit4to2_minus1)) begin
                    //iFact,iIdx每列相同，不是每个点1个，stage=5这里更新完iIdx_delta_idx,stage=6上面更新ref4
                    iIdx_delta_idx            <= {iIdx_delta_idx[4:15],4'd0};
                    iFact_idx                 <= {iFact_idx[4:15],20'd0};
                end
            end
            if (stage == 6) begin
                kick_store                    <= 1;
                stage                         <= 2;
                if (pick_ref == ref_pick_top||pick_ref == ref_pick_partial_left) begin
                    x                         <= x+4;
                    if (x[3:2] == trafoSize_bit4to2_minus1) begin
                        y                     <= y+4;
                        x                     <= 0;
                        if (y[3:2] == trafoSize_bit4to2_minus1) begin
                            stage             <= 7;
                        end
                    end
                end else begin
                    //竖着来，求完4xH，再求下一个4xH
                    y                         <= y+4;
                    if (y[3:2] == trafoSize_bit4to2_minus1) begin
                        x                     <= x+4;
                        y                     <= 0;
                        if (x[3:2] == trafoSize_bit4to2_minus1) begin
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

    if (`log_p && i_slice_num>=`slice_begin && i_slice_num<=`slice_end) begin
        $fdisplay(fd_log, "leftup:          %0d", leftup);
        if (log2TrafoSize==4) begin
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
    intra_predmode                     = {random_val[11:0],random_val[31:12],random_val[11:0],random_val[31:12]};
    log2TrafoSize                      = {random_val[12:0],random_val[31:13],random_val[12:0],random_val[31:13]};
    trafoSize                          = {random_val[13:0],random_val[31:14],random_val[13:0],random_val[31:14]};
    trafoSize_bit4to2_minus1           = {random_val[14:0],random_val[31:15],random_val[14:0],random_val[31:15]};
    cIdx                               = {random_val[15:0],random_val[31:16],random_val[15:0],random_val[31:16]};
    left_avail                         = {random_val[16:0],random_val[31:17],random_val[16:0],random_val[31:17]};
    up_avail                           = {random_val[17:0],random_val[31:18],random_val[17:0],random_val[31:18]};
    left_avail_bk                      = {random_val[18:0],random_val[31:19],random_val[18:0],random_val[31:19]};
    up_avail_bk                        = {random_val[19:0],random_val[31:20],random_val[19:0],random_val[31:20]};
    pleft                              = {random_val[20:0],random_val[31:21],random_val[20:0],random_val[31:21]};
    ptop                               = {random_val[21:0],random_val[31:22],random_val[21:0],random_val[31:22]};
    pleft_copy                         = {random_val[22:0],random_val[31:23],random_val[22:0],random_val[31:23]};
    ptop_copy                          = {random_val[23:0],random_val[31:24],random_val[23:0],random_val[31:24]};
    ptop_bk                            = {random_val[24:0],random_val[31:25],random_val[24:0],random_val[31:25]};
    leftup                             = {random_val[25:0],random_val[31:26],random_val[25:0],random_val[31:26]};
    pleft_tmp                          = {random_val[26:0],random_val[31:27],random_val[26:0],random_val[31:27]};
    ptop_tmp                           = {random_val[27:0],random_val[31:28],random_val[27:0],random_val[31:28]};
    sub_i                              = {random_val[28:0],random_val[31:29],random_val[28:0],random_val[31:29]};
    filter_i                           = {random_val[29:0],random_val[31:30],random_val[29:0],random_val[31:30]};
    phase                              = {random_val[30:0],random_val[31],random_val[30:0],random_val[31]};
    stage                              = {random_val[31:0],random_val[31:0]};
    valid                              = {random_val,random_val};
    accum_a                            = {random_val[1:0],random_val[31:2],random_val[1:0],random_val[31:2]};
    accum_b                            = {random_val[2:0],random_val[31:3],random_val[2:0],random_val[31:3]};
    accum_rst                          = {random_val[3:0],random_val[31:4],random_val[3:0],random_val[31:4]};
    accum_en                           = {random_val[4:0],random_val[31:5],random_val[4:0],random_val[31:5]};
    result4x4                          = {random_val[5:0],random_val[31:6],random_val[5:0],random_val[31:6]};
    result4x4_copy                     = {random_val[6:0],random_val[31:7],random_val[6:0],random_val[31:7]};
    pick_ref                           = {random_val[7:0],random_val[31:8],random_val[7:0],random_val[31:8]};
    dc_sum                             = {random_val[8:0],random_val[31:9],random_val[8:0],random_val[31:9]};
    sum_i                              = {random_val[9:0],random_val[31:10],random_val[9:0],random_val[31:10]};
    dcVal                              = {random_val[10:0],random_val[31:11],random_val[10:0],random_val[31:11]};
    ref_pick_idx                       = {random_val[12:0],random_val[31:13],random_val[12:0],random_val[31:13]};
    ref_r                              = {random_val[13:0],random_val[31:14],random_val[13:0],random_val[31:14]};
    ref4                               = {random_val[14:0],random_val[31:15],random_val[14:0],random_val[31:15]};
    ref_bk                             = {random_val[15:0],random_val[31:16],random_val[15:0],random_val[31:16]};
    iFact_idx                          = {random_val[17:0],random_val[31:18],random_val[17:0],random_val[31:18]};
    iIdx_delta_idx                     = {random_val[19:0],random_val[31:20],random_val[19:0],random_val[31:20]};
    operand1                           = {random_val[20:0],random_val[31:21],random_val[20:0],random_val[31:21]};
    operand2                           = {random_val[21:0],random_val[31:22],random_val[21:0],random_val[31:22]};
    ptop_ntbs                          = {random_val[22:0],random_val[31:23],random_val[22:0],random_val[31:23]};
    pleft_ntbs                         = {random_val[23:0],random_val[31:24],random_val[23:0],random_val[31:24]};
    store_stage                        = {random_val[24:0],random_val[31:25],random_val[24:0],random_val[31:25]};
    kick_store                         = {random_val[25:0],random_val[31:26],random_val[25:0],random_val[31:26]};
    store_done                         = {random_val[26:0],random_val[31:27],random_val[26:0],random_val[31:27]};
    x_to_store                         = {random_val[27:0],random_val[31:28],random_val[27:0],random_val[31:28]};
    y_to_store                         = {random_val[28:0],random_val[31:29],random_val[28:0],random_val[31:29]};
    store_x                            = {random_val[29:0],random_val[31:30],random_val[29:0],random_val[31:30]};
    store_y                            = {random_val[30:0],random_val[31],random_val[30:0],random_val[31]};
    store_i                            = {random_val[31:0],random_val[31:0]};
    last4x4_in_row                     = {random_val,random_val};
end
`endif

endmodule
