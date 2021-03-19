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

module mv
(
 input wire                                  clk                                ,
 input wire                                  rst                                ,
 input wire                                  global_rst                         ,
 input wire                                  i_rst_ctb                          ,
 input wire                                  en                                 ,

 input wire           [`max_x_bits-1:0]      i_x0                               ,
 input wire           [`max_y_bits-1:0]      i_y0                               ,
 input wire                      [ 5:0]      i_xPb                              ,
 input wire                      [ 5:0]      i_yPb                              ,
 input wire                                  i_last_col                         ,
 input wire                                  i_last_row                         ,
 input wire                                  i_first_col                        ,
 input wire                                  i_first_row                        ,
 input wire                      [ 6:0]      i_last_col_width                   ,
 input wire                      [ 6:0]      i_last_row_height                  ,
 input wire                      [31:0]      fd_log                             ,
 input wire                      [ 6:0]      i_nPbW                             ,
 input wire                      [ 6:0]      i_nPbH                             ,
 input wire                      [ 2:0]      i_log2_parallel_merge_level        ,
 input wire                      [ 1:0]      i_partIdx                          ,
 input wire                      [ 2:0]      i_part_mode                        ,
 input wire                                  i_slice_temporal_mvp_enabled_flag  ,
 input wire                      [ 3:0]      i_num_ref_idx                      , //slice_header

 input wire                      [15:0]      i_slice_num                        ,
 input wire                      [ 1:0]      i_slice_type                       ,

 input wire  [15:0][$bits(MvField)-1:0]      i_left_mvf                         ,
 input wire  [16:0][$bits(MvField)-1:0]      i_up_mvf                           ,
 input wire  [15:0][$bits(MvField)-1:0]      i_left_up_mvf                      ,

 input wire                      [ 7:0]      i_predmode_leftup                  ,
 input wire                                  i_predmode                         , //当前cu的cu_predmode
 input wire                      [ 7:0]      i_predmode_left                    ,
 input wire                      [15:0]      i_predmode_up                      ,
 input wire                      [ 3:0]      i_col_pic_dpb_slot                 ,
 input wire                      [14:0]      i_cur_poc_diff                     ,
 input wire                      [15:0]      i_col_pic_poc                      ,
 input wire                      [ 3:0]      i_ref_idx                          ,
 input wire        [0:`max_ref-1][14:0]      i_delta_poc                        ,
 input wire                                  i_merge_flag                       ,
 input wire                                  i_mvp_l0_flag                      ,
 input wire                      [ 2:0]      i_merge_idx                        ,

 input  wire                                 m_axi_arready                      ,
 output reg                                  m_axi_arvalid                      ,
 output reg                      [ 3:0]      m_axi_arlen                        ,
 output reg                      [31:0]      m_axi_araddr                       ,
 output reg                                  m_axi_rready                       ,
 input  wire                     [63:0]      m_axi_rdata                        ,
 input  wire                                 m_axi_rvalid                       ,
 input  wire                                 m_axi_rlast                        ,

 output reg        [$bits(MvField)-1:0]      o_mvf                              ,
 output reg                                  o_col_param_fetch_done             ,
 output reg                                  o_mv_done                   

);


reg              [2:0]        col_stage              ;
reg                           col_done               ;

reg                           last_col               ;
reg                           last_row               ;
reg                           first_col              ;
reg                           first_row              ;
reg              [6:0]        last_col_width         ;
reg              [6:0]        last_row_height        ;
reg              [3:0]        ref_idx                ;
reg                           reset_scale_col        ;

reg              [1:0]        cIdx                   ;
reg              [1:0]        partIdx                ;
reg              [2:0]        part_mode              ;

reg       [0:255][7:0]        R2Z                    ;
reg              [2:0]        MaxNumMergeCand        ;
reg              [2:0]        max_merge_cand_minus1  ;

reg              [2:0]        merge_idx              ;
reg                           mvp_l0_flag            ;

reg  [`max_x_bits-1:0]        x0                     ;
reg  [`max_y_bits-1:0]        y0                     ;
reg              [5:0]        xPb                    ;
reg              [5:0]        yPb                    ;
reg              [6:0]        nPbW                   ;
reg              [6:0]        nPbH                   ;
reg              [5:0]        xNbA0                  ;
reg              [5:0]        yNbA0                  ;
reg              [5:0]        xNbA1                  ;
reg              [5:0]        yNbA1                  ;
reg              [6:0]        xNbB0                  ;
reg              [5:0]        yNbB0                  ;
reg              [5:0]        xNbB1                  ;
reg              [5:0]        yNbB1                  ;
reg              [5:0]        xNbB2                  ;
reg              [5:0]        yNbB2                  ;
reg              [5:0]        xColCtr                ;
reg              [5:0]        yColCtr                ;
reg  [`max_x_bits-1:0]        xColBr                 ;
reg  [`max_y_bits-1:0]        yColBr                 ;
reg              [5:0]        x_left_bottom_most     ;
reg              [5:0]        y_left_bottom_most     ;
reg              [5:0]        x_up_right_most        ;
reg              [5:0]        y_up_right_most        ;


reg              [3:0]        xPb_par                ;
reg              [3:0]        yPb_par                ;
reg              [3:0]        xNbA0_par              ;
reg              [3:0]        yNbA0_par              ;
reg              [3:0]        xNbA1_par              ;
reg              [3:0]        yNbA1_par              ;
reg              [3:0]        xNbB0_par              ;
reg              [3:0]        yNbB0_par              ;
reg              [3:0]        xNbB1_par              ;
reg              [3:0]        yNbB1_par              ;
reg              [3:0]        xNbB2_par              ;
reg              [3:0]        yNbB2_par              ;


reg              [31:0]       param_ddr_base         ;
//clock 0
always @(posedge clk)
begin
    case (i_col_pic_dpb_slot)
        0: param_ddr_base          <= `DDR_BASE_PARAM0;
        1: param_ddr_base          <= `DDR_BASE_PARAM1;
        2: param_ddr_base          <= `DDR_BASE_PARAM2;
        3: param_ddr_base          <= `DDR_BASE_PARAM3;
        4: param_ddr_base          <= `DDR_BASE_PARAM4;
        default: param_ddr_base    <= `DDR_BASE_PARAM5;
    endcase
end



reg  [`max_x_bits-1:0]        x_fetch_col            ;
reg  [`max_y_bits-1:0]        y_fetch_col            ;
reg             [15:0]        pred_mode_col_pic      ;
reg             [15:0]        pred_mode_col_pic_right;
reg       [15:0][15:0]        ref_poc_col_pic        ;
reg       [15:0][15:0]        ref_poc_col_pic_right  ;
MvField         [15:0]        mvf_col_pic            ;
MvField         [15:0]        mvf_col_pic_right      ;
reg             [ 1:0]        col_param_fetch_stage  ;

wire            [19:0]        param_addr_off         ;
reg             [ 3:0]        fetch_col_i            ;
reg             [ 1:0]        fetch_col_j            ;

assign param_addr_off = {1'b0,y_fetch_col[`max_y_bits-1:4],x_fetch_col[`max_x_bits-1:4],3'd0};

//fix
//xColPb = xColBr & ~15;
//yColPb = yColBr & ~15;


always @ (posedge clk)
begin
    if (global_rst) begin
        o_col_param_fetch_done       <= 1;
        col_param_fetch_stage        <= 0;
        m_axi_arvalid                <= 0;
        m_axi_rready                 <= 0;
    end else if (i_rst_ctb&&i_slice_type != `I_SLICE) begin
        col_param_fetch_stage        <= 1;
        o_col_param_fetch_done       <= 0;
        m_axi_rready                 <= 1;
        x_fetch_col                  <= i_first_col?i_x0:i_x0+64;
        y_fetch_col                  <= i_y0;
        fetch_col_i                  <= 0;
        fetch_col_j                  <= 0;
        pred_mode_col_pic            <= pred_mode_col_pic_right;
        ref_poc_col_pic              <= ref_poc_col_pic_right;
        mvf_col_pic                  <= mvf_col_pic_right;
    end else if (~o_col_param_fetch_done) begin
        if (col_param_fetch_stage==1) begin
            m_axi_araddr             <= {param_ddr_base[31:20],param_addr_off};
            m_axi_arvalid            <= 1;
            if (i_first_col)
                m_axi_arlen          <= 7;
            else
                m_axi_arlen          <= 3;
            fetch_col_i              <= 0;
            col_param_fetch_stage    <= 2;
        end

        if (col_param_fetch_stage==2&&
            m_axi_arready) begin
            m_axi_arvalid            <= 0;
        end

        if (col_param_fetch_stage==2&&
            m_axi_rvalid) begin
            if (i_first_col&&~fetch_col_i[2]) begin
                pred_mode_col_pic          <= {m_axi_rdata[13],pred_mode_col_pic[15:1]};
                ref_poc_col_pic            <= {m_axi_rdata[29:14],ref_poc_col_pic[15:1]};
                mvf_col_pic                <= {m_axi_rdata[63:30],mvf_col_pic[15:1]};
            end else begin
                pred_mode_col_pic_right    <= {m_axi_rdata[13],pred_mode_col_pic_right[15:1]};
                ref_poc_col_pic_right      <= {m_axi_rdata[29:14],ref_poc_col_pic_right[15:1]};
                mvf_col_pic_right          <= {m_axi_rdata[63:30],mvf_col_pic_right[15:1]};

            end
            fetch_col_i                    <= fetch_col_i+1;
            if (m_axi_rlast) begin
                y_fetch_col                <= y_fetch_col+16;
                fetch_col_j                <= fetch_col_j+1;
                fetch_col_i                <= 0;
                col_param_fetch_stage      <= 1;
                if (fetch_col_j==3) begin
                    o_col_param_fetch_done <= 1;
                    col_param_fetch_stage  <= 0;
                end
            end
        end

    end else begin
        m_axi_rready             <= 0;
    end

end
//     B2 |               B1 |B0
//     ___|__________________|___
//        |                  |
//        |                  |
//        |                  |
//        |                  |
//        |                  |
//        |                  |
//        |                  |
//     A1 |                  |
//    ---- ------------------
//     A0 |

//clock 0，reset时
always @ (posedge clk)
begin
    xPb                 <= i_xPb;
    yPb                 <= i_yPb;
    x0                  <= i_x0;
    y0                  <= i_y0;
    nPbW                <= i_nPbW;
    nPbH                <= i_nPbH;
    xNbA0               <= i_xPb - 1;
    yNbA0               <= i_yPb + i_nPbH;
    xNbA1               <= i_xPb - 1;
    yNbA1               <= i_yPb + i_nPbH - 1;
    xNbB1               <= i_xPb + i_nPbW - 1;
    yNbB1               <= i_yPb - 1;
    xNbB0               <= i_xPb + i_nPbW;
    yNbB0               <= i_yPb - 1;
    xNbB2               <= i_xPb - 1;
    yNbB2               <= i_yPb - 1;
    xColBr              <= {x0[`max_x_bits-1:6],i_xPb} + i_nPbW;
    yColBr              <= {y0[`max_y_bits-1:6],i_yPb} + i_nPbH;
    xColCtr             <= i_xPb + i_nPbW[6:1];
    yColCtr             <= i_yPb + i_nPbH[6:1];

    x_left_bottom_most  <= i_xPb;
    y_left_bottom_most  <= i_yPb+nPbH-1;
    x_up_right_most     <= i_xPb+nPbW-1;
    y_up_right_most     <= i_yPb;


end


reg                 avail_col               ;
reg                 predmode_col            ;
reg      [15:0]     ref_poc_col             ;
MvField             mvf_col                 ;
Mv                  mv_col_scaled           ;
wire                col_scale_done          ;



always @ (posedge clk)
if (global_rst) begin
    col_stage                     <= 6;
    col_done                      <= 0;
end else if (rst) begin
    col_stage                     <= 0;
    col_done                      <= 0;
    avail_col                     <= 0;
end else begin
    if (col_stage == 0) begin
        if (xColBr[5:0]==0) begin
            case (yColBr[5:4])
                0: begin
                    mvf_col       <= mvf_col_pic_right[0];
                    ref_poc_col   <= ref_poc_col_pic_right[0];
                    predmode_col  <= pred_mode_col_pic_right[0];
                end
                1: begin
                    mvf_col       <= mvf_col_pic_right[4];
                    ref_poc_col   <= ref_poc_col_pic_right[4];
                    predmode_col  <= pred_mode_col_pic_right[4];
                end
                2: begin
                    mvf_col       <= mvf_col_pic_right[8];
                    ref_poc_col   <= ref_poc_col_pic_right[8];
                    predmode_col  <= pred_mode_col_pic_right[8];
                end
                3: begin
                    mvf_col       <= mvf_col_pic_right[12];
                    ref_poc_col   <= ref_poc_col_pic_right[12];
                    predmode_col  <= pred_mode_col_pic_right[12];
                end
            endcase
        end else begin
            mvf_col               <= mvf_col_pic[{yColBr[5:4],xColBr[5:4]}];
            ref_poc_col           <= ref_poc_col_pic[{yColBr[5:4],xColBr[5:4]}];
            predmode_col          <= pred_mode_col_pic[{yColBr[5:4],xColBr[5:4]}];
        end

        col_stage                 <= 1;
    end
    if (col_stage == 1) begin

        if (yPb[5:2] + nPbH[6:2]==16 ||
            (last_col && xPb[5:2] + nPbW[6:2]==last_col_width[6:2]) ||
            (last_row && yPb[5:2] + nPbH[6:2]==last_row_height[6:2]) ||
            predmode_col==`MODE_INTRA) begin
            col_stage             <= 2;
        end else begin
            avail_col             <= 1;
            if (i_cur_poc_diff==i_col_pic_poc-ref_poc_col) begin
                col_stage         <= 6; //finish and available
                col_done          <= 1;
            end else begin
                reset_scale_col   <= 1;
                col_stage         <= 4;
            end
        end
    end

    if (col_stage == 2) begin
        mvf_col                   <= mvf_col_pic[{yColCtr[5:4],xColCtr[5:4]}];
        ref_poc_col               <= ref_poc_col_pic[{yColCtr[5:4],xColCtr[5:4]}];
        predmode_col              <= pred_mode_col_pic[{yColCtr[5:4],xColCtr[5:4]}];
        col_stage                 <= 3;
    end

    if (col_stage == 3) begin
        if (predmode_col==`MODE_INTRA) begin
            col_stage             <= 6; ////finish and unavailable
            col_done              <= 1;
        end else begin
            avail_col             <= 1;
            if (i_cur_poc_diff==i_col_pic_poc-ref_poc_col) begin
                col_stage         <= 6;
                col_done          <= 1;
            end else begin
                reset_scale_col   <= 1;
                col_stage         <= 4;
            end
        end

    end

    if (col_stage == 4) begin
        reset_scale_col      <= 0;
        col_stage            <= 5;
    end
    if (col_stage == 5 && col_scale_done) begin
        col_done             <= 1;
        mvf_col.mv           <= mv_col_scaled;
        col_stage            <= 6;
    end

    //mv完成，col进行一半也结束退出,
    //col是一reset就开始，不是需要才进行
    if (o_mv_done) begin
        col_stage            <= 6;
    end


end

scale scale_col
(
    .clk         (clk),
    .rst         (reset_scale_col),

    .poc_diff1   (i_col_pic_poc-ref_poc_col),
    .poc_diff2   (i_cur_poc_diff),
    .mv0         (mvf_col.mv.mv[0]),
    .mv1         (mvf_col.mv.mv[1]),

    .mv0_scaled  (mv_col_scaled.mv[0]),
    .mv1_scaled  (mv_col_scaled.mv[1]),
    .scale_done  (col_scale_done)
);

//clock 0 reset
always @(*)
begin
    case (i_log2_parallel_merge_level)
        2: begin
            xPb_par     <= xPb[5:2];
            yPb_par     <= yPb[5:2];
            xNbA0_par   <= xNbA0[5:2];
            yNbA0_par   <= yNbA0[5:2];
            xNbA1_par   <= xNbA1[5:2];
            yNbA1_par   <= yNbA1[5:2];
            xNbB0_par   <= xNbB0[5:2];
            yNbB0_par   <= yNbB0[5:2];
            xNbB1_par   <= xNbB1[5:2];
            yNbB1_par   <= yNbB1[5:2];
            xNbB2_par   <= xNbB2[5:2];
            yNbB2_par   <= yNbB2[5:2];
        end
        3: begin
            xPb_par     <= xPb[5:3];
            yPb_par     <= yPb[5:3];
            xNbA0_par   <= xNbA0[5:3];
            yNbA0_par   <= yNbA0[5:3];
            xNbA1_par   <= xNbA1[5:3];
            yNbA1_par   <= yNbA1[5:3];
            xNbB0_par   <= xNbB0[5:3];
            yNbB0_par   <= yNbB0[5:3];
            xNbB1_par   <= xNbB1[5:3];
            yNbB1_par   <= yNbB1[5:3];
            xNbB2_par   <= xNbB2[5:3];
            yNbB2_par   <= yNbB2[5:3];
        end
        4: begin
            xPb_par     <= xPb[5:4];
            yPb_par     <= yPb[5:4];
            xNbA0_par   <= xNbA0[5:4];
            yNbA0_par   <= yNbA0[5:4];
            xNbA1_par   <= xNbA1[5:4];
            yNbA1_par   <= yNbA1[5:4];
            xNbB0_par   <= xNbB0[5:4];
            yNbB0_par   <= yNbB0[5:4];
            xNbB1_par   <= xNbB1[5:4];
            yNbB1_par   <= yNbB1[5:4];
            xNbB2_par   <= xNbB2[5:4];
            yNbB2_par   <= yNbB2[5:4];
        end
        5: begin
            xPb_par     <= xPb[5];
            yPb_par     <= yPb[5];
            xNbA0_par   <= xNbA0[5];
            yNbA0_par   <= yNbA0[5];
            xNbA1_par   <= xNbA1[5];
            yNbA1_par   <= yNbA1[5];
            xNbB0_par   <= xNbB0[5];
            yNbB0_par   <= yNbB0[5];
            xNbB1_par   <= xNbB1[5];
            yNbB1_par   <= yNbB1[5];
            xNbB2_par   <= xNbB2[5];
            yNbB2_par   <= yNbB2[5];
        end
        default: begin
            xPb_par     <= xPb[5:2];
            yPb_par     <= yPb[5:2];
            xNbA0_par   <= xNbA0[5:2];
            yNbA0_par   <= yNbA0[5:2];
            xNbA1_par   <= xNbA1[5:2];
            yNbA1_par   <= yNbA1[5:2];
            xNbB0_par   <= xNbB0[5:2];
            yNbB0_par   <= yNbB0[5:2];
            xNbB1_par   <= xNbB1[5:2];
            yNbB1_par   <= yNbB1[5:2];
            xNbB2_par   <= xNbB2[5:2];
            yNbB2_par   <= yNbB2[5:2];
        end
    endcase
end

MvField                       mvf_a0;
MvField                       mvf_b0;
MvField                       mvf_a1;
MvField                       mvf_b2;
MvField                       mvf_b1;
reg         [14:0]     delta_poc_ref ;

//clock 1
always @ (posedge clk)
begin
    mvf_a0              <= i_left_mvf[yNbA0[5:2]];
    mvf_a1              <= i_left_mvf[yNbA1[5:2]];
    mvf_b0              <= i_up_mvf[xNbB0[6:2]];
    mvf_b1              <= i_up_mvf[xNbB1[5:2]];
    mvf_b2              <= i_left_up_mvf[yPb[5:2]]; //fix,看笔记的定义，是yPb,不是yNbB2
end

reg                           cond_dpoc0_a1; //DiffPicOrderCnt
reg                           cond_dpoc0_a0;
reg                           cond_dpoc0_b0;
reg                           cond_dpoc0_b1;
reg                           cond_dpoc0_b2;

//clock 2
always @ (posedge clk)
begin
    cond_dpoc0_a1        <= delta_poc_ref==i_delta_poc[mvf_a1.refIdx];
    cond_dpoc0_a0        <= delta_poc_ref==i_delta_poc[mvf_a0.refIdx];
    cond_dpoc0_b0        <= delta_poc_ref==i_delta_poc[mvf_b0.refIdx];
    cond_dpoc0_b1        <= delta_poc_ref==i_delta_poc[mvf_b1.refIdx];
    cond_dpoc0_b2        <= delta_poc_ref==i_delta_poc[mvf_b2.refIdx];
end

reg                           cond_mvf_a1_eq_b1;
reg                           cond_mvf_b0_eq_b1;
reg                           cond_mvf_a0_eq_a1;
reg                           cond_mvf_a1_eq_b2;
reg                           cond_mvf_b1_eq_b2;

//clock 2
always @ (posedge clk)
begin
    cond_mvf_a1_eq_b1   <= mvf_a1==mvf_b1;
    cond_mvf_b0_eq_b1   <= mvf_b0==mvf_b1;
    cond_mvf_a0_eq_a1   <= mvf_a0==mvf_a1;
    cond_mvf_a1_eq_b2   <= mvf_a1==mvf_b2;
    cond_mvf_b1_eq_b2   <= mvf_b1==mvf_b2;
end


reg                           predmode_nb_a0;
reg                           predmode_nb_a1;
reg                           predmode_nb_b0;
reg                           predmode_nb_b1;
reg                           predmode_nb_b2;

//clock 1
always @ (posedge clk)
begin
    if (first_col&&xPb[5:2] == 0 || first_row&&yPb[5:2] == 0) begin
        predmode_nb_b2        <= `MODE_INTER;
    end else if (x0[5:2] == xPb[5:2] && y0[5:2] == yPb[5:2]) begin
        predmode_nb_b2        <= i_predmode_leftup[yPb[5:3]];
    end else if (x0[5:2] == xPb[5:2]) begin
        predmode_nb_b2        <= i_predmode_left[yNbB2[5:3]]; //fix,yPb[5:3]-1,yPb在4边界
    end else if (y0[5:2] == yPb[5:2]) begin
        predmode_nb_b2        <= i_predmode_up[xNbB2[5:3]]; //fix,xPb[5:3]-1
    end else begin
        predmode_nb_b2        <= i_predmode;
    end

    if (x0[5:2] == xPb[5:2]) begin
        predmode_nb_a0        <= i_predmode_left[yNbA0[5:3]];
        predmode_nb_a1        <= i_predmode_left[yNbA1[5:3]];
    end else begin
        predmode_nb_a0        <= i_predmode;
        predmode_nb_a1        <= i_predmode;
    end

    if (y0[5:2] == yPb[5:2]) begin
        predmode_nb_b0        <= i_predmode_up[xNbB0[6:3]];
        predmode_nb_b1        <= i_predmode_up[xNbB1[5:3]];
    end else begin
        predmode_nb_b0        <= i_predmode;
        predmode_nb_b1        <= i_predmode;
    end
end

reg                           avail_a0;
reg                           avail_a1;
reg                           avail_b0;
reg                           avail_b1;
reg                           avail_b2;
reg                           avail_m_a0; //merging
reg                           avail_m_a1;
reg                           avail_m_b0;
reg                           avail_m_b1;
reg                           avail_m_b2;
reg                           avail_flag_a0;
reg                           avail_flag_a1;
reg                           avail_flag_b0;
reg                           avail_flag_b1;
reg                           avail_flag_b2;
wire                          avail_flag_a0_w;
wire                          avail_flag_a1_w;
wire                          avail_flag_b0_w;
wire                          avail_flag_b1_w;
wire                          avail_flag_b2_w;

assign avail_flag_a0_w = avail_a0&cond_dpoc0_a0;
assign avail_flag_a1_w = avail_a1&cond_dpoc0_a1;
assign avail_flag_b0_w = avail_b0&cond_dpoc0_b0;
assign avail_flag_b1_w = avail_b1&cond_dpoc0_b1;
assign avail_flag_b2_w = avail_b2&cond_dpoc0_b2;

reg                           avail_a;
reg                           avail_b;
MvField                       mvf_a;
MvField                       mvf_b;
MvField                       mvf_b_to_scale;

reg                           left_bottom_avail;
reg                           up_right_avail;
reg  [ 7:0]                   zorder_left_bottom;
reg  [ 7:0]                   zorder_a0;
reg  [ 7:0]                   zorder_up_right;
reg  [ 7:0]                   zorder_b0;

reg [2:0]                     numMvpCand;



//clock 1
always @ (posedge clk)
begin
    zorder_left_bottom        <= R2Z[{y_left_bottom_most[5:2],x_left_bottom_most[5:2]}];
    zorder_a0                 <= R2Z[{yNbA0[5:2],xNbA0[5:2]}];
    zorder_up_right           <= R2Z[{y_up_right_most[5:2],x_up_right_most[5:2]}];
    zorder_b0                 <= R2Z[{yNbB0[5:2],xNbB0[5:2]}];
end


//clock 2
always @(posedge clk)
begin
    if (first_col && xPb[5:2] == 0 ||
        (last_row && yPb[5:2] + nPbH[6:2] >= last_row_height[6:2]))
        left_bottom_avail <= 0;
    else if (yPb[5:2] + nPbH[6:2] >= 16)//处于上下2个CTB
        left_bottom_avail <= 0;
    else if (xPb[5:2] == 0)
        left_bottom_avail <= 1;
    else if (zorder_left_bottom < zorder_a0)
        left_bottom_avail <= 0;
    else
        left_bottom_avail <= 1;
end

//clock 3
always @(posedge clk)
begin
    if (left_bottom_avail == 0) begin
        avail_a0      <=  0;
    end else if (predmode_nb_a0 == `MODE_INTRA) begin
        avail_a0      <=  0;
    end else begin
        avail_a0      <=  1;
    end
end

//clock 3
//merging candidates
always @(posedge clk)
begin
    if (left_bottom_avail == 0) begin
        avail_m_a0      <= 0;
    end else if (xPb_par==xNbA0_par&& yPb_par==yNbA0_par) begin
        avail_m_a0      <= 0;
    end else if (predmode_nb_a0 == `MODE_INTRA) begin
        avail_m_a0      <= 0;
    end else begin
        avail_m_a0      <= 1;
    end

    if (left_bottom_avail == 0) begin
        avail_flag_a0   <=  0;
    end else if (xPb_par==xNbA0_par&& yPb_par==yNbA0_par) begin
        avail_flag_a0   <= 0;
    end else if (predmode_nb_a0 == `MODE_INTRA) begin
        avail_flag_a0   <= 0;
    end else if (avail_m_a1&&cond_mvf_a0_eq_a1)begin
        avail_flag_a0   <= 0;
    end else begin
        avail_flag_a0   <= 1;
    end

end

//clock 2
always @(posedge clk)
begin
    if (first_col && xPb == 0) begin
        avail_a1      <=  0;
    end else if (predmode_nb_a1 == `MODE_INTRA) begin
        avail_a1      <=  0;
    end else begin
        avail_a1      <=  1;
    end
end


//clock 2
//merging candidates
always @(posedge clk)
begin
    if (xPb == 0&&first_col) begin
        avail_m_a1      <=  0;
    end else if (xPb_par==xNbA1_par&&yPb_par==yNbA1_par) begin
        avail_m_a1      <=  0;
    end else if ((part_mode == `PART_nLx2N || part_mode == `PART_nRx2N || part_mode == `PART_Nx2N) &&
        partIdx == 1) begin
        avail_m_a1      <=  0;
    end else if (predmode_nb_a1 == `MODE_INTRA) begin
        avail_m_a1      <=  0;
    end else begin
        avail_m_a1      <=  1;
    end
end

//clock 3
always @ (posedge clk)
    avail_flag_a1       <= avail_m_a1;


//clock 2
always @(posedge clk)
begin
    if (first_row && yPb[5:2] == 0 ||
        (last_col && xPb[5:2] + nPbW[6:2] >= last_col_width[6:2]))
        up_right_avail = 0;
    else if (yPb[5:2]==0)
        up_right_avail = 1;
    else if (xPb[5:2] + nPbW[6:2] >= 16&&yPb[5:2]!=0)//处于左右2个CTB
        up_right_avail = 0;
    else if (zorder_up_right < zorder_b0)
        up_right_avail = 0;
    else
        up_right_avail = 1;
end

//clock 3
always @(posedge clk)
begin
    if (up_right_avail == 0) begin
        avail_b0      <=  0;
    end else if (predmode_nb_b0 == `MODE_INTRA) begin
        avail_b0      <=  0;
    end else begin
        avail_b0      <=  1;
    end
end

//clock 3
//merging candidates
always @(posedge clk)
begin
    if (up_right_avail == 0) begin
        avail_m_b0      <=  0;
    end else if (xPb_par==xNbB0_par&&yPb_par ==yNbB0_par) begin
        avail_m_b0      <=  0;
    end else if (predmode_nb_b0 == `MODE_INTRA) begin
        avail_m_b0      <=  0;
    end else begin
        avail_m_b0      <=  1;
    end

    if (up_right_avail == 0) begin
        avail_flag_b0   <=  0;
    end else if (xPb_par==xNbB0_par&&yPb_par ==yNbB0_par) begin
        avail_flag_b0   <=  0;
    end else if (predmode_nb_b0 == `MODE_INTRA) begin
        avail_flag_b0   <=  0;
    end else if (avail_m_b1&&cond_mvf_b0_eq_b1)begin
        avail_flag_b0   <=  0;
    end else begin
        avail_flag_b0   <= 1;
    end

end



//clock 2
always @(posedge clk)
begin
    if (yPb == 0&&first_row) begin
        avail_b1        <=  0;
    end else if (predmode_nb_b1 == `MODE_INTRA) begin
        avail_b1        <=  0;
    end else begin
        avail_b1        <=  1;
    end
end



//clock 2
//merging candidates
always @(posedge clk)
begin
    if (yPb == 0&&first_row) begin
        avail_m_b1      <=  0;
    end else if (xPb_par==xNbB1_par&&yPb_par==yNbB1_par) begin
        avail_m_b1      <=  0;
    end else if ((part_mode == `PART_2NxnU || part_mode == `PART_2NxnD || part_mode == `PART_2NxN) &&
        partIdx == 1) begin
        avail_m_b1      <=  0;
    end else if (predmode_nb_b1 == `MODE_INTRA) begin
        avail_m_b1      <=  0;
    end else begin
        avail_m_b1      <=  1;
    end
end


//clock 3
always @ (posedge clk)
begin
    if (avail_m_b1==0)
        avail_flag_b1   <= 0;
    else if (avail_m_a1&&cond_mvf_a1_eq_b1)
        avail_flag_b1   <= 0;
    else
        avail_flag_b1   <= 1;
end

//clock 2
always @(posedge clk)
begin
    if (xPb == 0&&first_col || yPb == 0&&first_row) begin
        avail_b2      <=  0;
    end else if (predmode_nb_b2 == `MODE_INTRA) begin
        avail_b2      <=  0;
    end else begin
        avail_b2      <=  1;
    end
end

//clock 2
//merging candidates
always @(posedge clk)
begin
    if (xPb == 0&&first_col || yPb == 0&&first_row) begin
        avail_m_b2      <=  0;
    end else if (xPb_par==xNbB2_par&&yPb_par==yNbB2_par) begin
        avail_m_b2      <=  0;
    end else if (predmode_nb_b2 == `MODE_INTRA) begin
        avail_m_b2      <=  0;
    end else begin
        avail_m_b2      <=  1;
    end
end

//clock 3
always @ (posedge clk)
begin
    if (avail_m_b2==0)
        avail_flag_b2   <= 0;
    else if ((avail_m_a1&&cond_mvf_a1_eq_b2)||
             (avail_m_b1&&cond_mvf_b1_eq_b2))
        avail_flag_b2   <= 0;
    else
        avail_flag_b2   <= 1; //availableFlagA0 + availableFlagA1 + availableFlagB0 + availableFlagB1 == 4放到下面考虑
end


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



reg                reset_scale_a     ;
reg                reset_scale_b     ;
wire               a_scale_done      ;
wire               b_scale_done      ;
Mv                 mva_scaled        ;
Mv                 mvb_scaled        ;
reg                isScaledFlag      ;
reg     [ 1:0]     mvp_cand          ;
MvField [ 1:0]     mvpList           ;
reg                avail_flag_a      ;
reg                avail_flag_b      ;
reg                avail_flag_b0_mvp ; //和merging的区分
reg                avail_flag_b1_mvp ;
reg                avail_flag_b2_mvp ;


reg     [ 3:0]     stage             ;
reg                mvp_done          ;

reg                two_b_cand_possible;

always @ (posedge clk)
if (global_rst) begin
    stage                <= 11;
    mvp_done             <= 0;
end else if (rst) begin
    last_col             <= i_last_col;
    last_row             <= i_last_row;
    first_col            <= i_first_col;
    first_row            <= i_first_row;
    last_col_width       <= i_last_col_width;
    last_row_height      <= i_last_row_height;

    ref_idx              <= i_ref_idx;
    stage                <= 0;
    mvp_cand             <= 0;
    mvp_l0_flag          <= i_mvp_l0_flag;

    partIdx              <= i_partIdx;
    part_mode            <= i_part_mode;
    avail_flag_a         <= 0;
    avail_flag_b         <= 0;
    isScaledFlag         <= 0;
    delta_poc_ref        <= i_delta_poc[i_ref_idx];
    mvpList[0].refIdx    <= i_ref_idx;
    mvpList[1].refIdx    <= i_ref_idx;
    mvp_done             <= 0;
end else if (en) begin
    if (stage < 4)
        stage            <= stage+1;

    if (stage == 3) begin //fix，并不只是prefer a0 over a1，而且prefer DiffPicOrderCnt=0的
        casez ({avail_flag_a0_w,avail_flag_a1_w})
            2'b00: begin avail_a  <= 0; mvf_a <= 34'd0; end
            2'b1?: begin avail_a  <= 1; mvf_a <= mvf_a0; end
            2'b01: begin avail_a  <= 1; mvf_a <= mvf_a1; end
        endcase
        casez ({avail_flag_b0_w,avail_flag_b1_w,avail_flag_b2_w})
            3'b000: begin avail_b <= 0; mvf_b <= 34'd0; end
            3'b1??: begin avail_b <= 1; mvf_b <= mvf_b0; end
            3'b01?: begin avail_b <= 1; mvf_b <= mvf_b1; end
            3'b001: begin avail_b <= 1; mvf_b <= mvf_b2; end
        endcase
        avail_flag_a              <= avail_flag_a1_w|avail_flag_a0_w;
        avail_flag_b              <= avail_flag_b0_w|avail_flag_b1_w|avail_flag_b2_w;
        avail_flag_b0_mvp         <= avail_flag_b0_w;
        avail_flag_b1_mvp         <= avail_flag_b1_w;
        avail_flag_b2_mvp         <= avail_flag_b2_w;
        stage                     <= 4;
    end

    if (stage == 4) begin
        if (avail_a == 0) begin //即stage=3时avail_flag_a=0
            casez ({avail_a0,avail_a1})
                2'b00: begin avail_a  <= 0; mvf_a <= 34'd0; end
                2'b1?: begin avail_a  <= 1; mvf_a <= mvf_a0; end
                2'b01: begin avail_a  <= 1; mvf_a <= mvf_a1; end
            endcase
        end
        two_b_cand_possible           <= 0;
        if (avail_b == 0) begin ////即stage=3时avail_flag_b=0
            casez ({avail_b0,avail_b1,avail_b2})
                3'b000: begin avail_b <= 0; mvf_b <= 34'd0; end
                3'b1??: begin avail_b <= 1; mvf_b <= mvf_b0; mvf_b_to_scale <= mvf_b0; end
                3'b01?: begin avail_b <= 1; mvf_b <= mvf_b1; mvf_b_to_scale <= mvf_b1; end
                3'b001: begin avail_b <= 1; mvf_b <= mvf_b2; mvf_b_to_scale <= mvf_b2; end
            endcase
        end else if (avail_flag_b0_mvp) begin
            two_b_cand_possible       <= 0;
        end else if (avail_flag_b1_mvp) begin
            if (avail_b0) begin
                mvf_b_to_scale        <= mvf_b0;
                two_b_cand_possible   <= 1;
            end
        end else if (avail_flag_b2_mvp) begin
            if (avail_b0) begin
                mvf_b_to_scale        <= mvf_b0;
                two_b_cand_possible   <= 1;
            end else if (avail_b1) begin
                mvf_b_to_scale        <= mvf_b1;
                two_b_cand_possible   <= 1;
            end
        end
        reset_scale_a              <= 1;
        reset_scale_b              <= 1;
        stage                      <= 5;
    end

    if (stage == 5) begin
        isScaledFlag               <= avail_a;
        if (avail_a) begin
            if (avail_flag_a) begin
                mvpList[0].mv      <= mvf_a.mv;
                stage              <= mvp_l0_flag==0?11:7;
                mvp_done           <= mvp_l0_flag==0?1:0;
                mvp_cand           <= 1;
            end else begin
                stage              <= 6; //a需要scale
            end
            avail_flag_a           <= 1; //avail_flag_a stage=4前区分是否要scale，最终只要A avail，avail_flag_a就是1,不过置了也没啥用
        end else begin
            stage                  <= 7;
        end
        reset_scale_a              <= 0;
        reset_scale_b              <= 0;
    end

    if (stage == 6 && a_scale_done) begin
        mvpList[mvp_cand].mv       <= mva_scaled;
        mvf_a.mv                   <= mva_scaled;
        mvp_cand                   <= 1;
        stage                      <= mvp_l0_flag==0?11:7;
        mvp_done                   <= mvp_l0_flag==0?1:0;
    end

    if (stage == 7) begin
        if (isScaledFlag) begin
            //如果A0,A1 avail,isScaledFlag就为1，B的DiffPicOrderCnt不为0的就不会作为候选
            //A unavail,B DiffPicOrderCnt不为0的才可以scale后作为候选
            //isScaledFlag=1,A必已经作为candidate，mvpList[0]已经有了
            if (avail_flag_b&&mvf_a.mv!=mvf_b.mv) begin
                mvpList[1].mv      <= mvf_b.mv;
                mvp_cand           <= 2;
                mvp_done           <= 1;
                stage              <= 11;
            end else begin

                stage              <= 9;
            end
        end else begin
            if (avail_b) begin
                if (avail_flag_b) begin
                    mvpList[0].mv  <= mvf_b.mv;//参考C代码的注释，效果等于mvpList[0]=mvB
                    mvp_cand       <= 1;
                    stage          <= mvp_l0_flag==0?11:(two_b_cand_possible?12:9);
                    mvp_done       <= mvp_l0_flag==0?1:0;
                end else begin
                    stage          <= 8;
                end
            end else begin
                stage              <= 9; //A,B都不可用
            end

        end
    end

    if (stage == 8 && b_scale_done) begin
        mvpList[0].mv              <= mvb_scaled; //b需要scale，必a不可用，必mvp_cand只有1个
        mvp_cand                   <= 1;
        stage                      <= 9;
    end

    //mv col and zero
    if (stage == 9) begin
        if (mvp_cand == 0) begin
            mvpList[0].mv          <= 30'd0;
            mvpList[1].mv          <= 30'd0;
        end else begin
            mvpList[1].mv          <= 30'd0;
        end
        if (mvp_cand != 2) begin
            if (i_slice_temporal_mvp_enabled_flag) begin
                stage              <= 10;
            end else begin
                mvp_done           <= 1;
                stage              <= 11;
            end
        end else begin
            mvp_done               <= 1;
            stage                  <= 11;
        end
    end

    if (stage == 10 && col_done) begin
        if (avail_col) begin
            if (mvp_cand == 0) begin
                mvpList[0].mv      <= mvf_col.mv;
                mvpList[1].mv      <= 30'd0;
            end else begin
                mvpList[1].mv      <= mvf_col.mv;
            end

        end
        mvp_done                   <= 1;
        stage                      <= 11;
    end

    //finish stage
    if (stage == 11) begin

    end

    if (stage == 12 &&b_scale_done) begin
        if (mvb_scaled.mv[0] != mvf_b.mv.mv[0]||
            mvb_scaled.mv[1] != mvf_b.mv.mv[1]) begin
            mvp_done               <= 1;
            mvp_cand               <= 2;
            mvpList[1].mv          <= mvb_scaled.mv;
            stage                  <= 11;
        end else begin
            stage                  <= 9;
        end
    end

end

reg     [2:0] merge_stage;
reg     [2:0] merge_cand;  //merge candidates count
MvField [4:0] merge_cand_list;
reg           merge_done;

always @ (posedge clk)
if (global_rst) begin
    merge_stage                    <= 6;
    merge_done                     <= 0;
end else if (rst) begin
    merge_stage                    <= 0;
    merge_cand                     <= 0;
    merge_cand_list                <= {5{34'd0}};
    merge_done                     <= 0;
    merge_idx                      <= i_merge_idx;
end else if (en) begin
    if (merge_stage < 4)
        merge_stage                <= merge_stage+1;
    if (merge_stage == 3) begin
        case ({avail_flag_a1,avail_flag_b1,avail_flag_b0,avail_flag_a0,avail_flag_b2})
            5'b00000: begin
                merge_cand         <= 0;
            end
            5'b00001: begin
                merge_cand         <= 1;
                merge_cand_list[0] <= mvf_b2;
            end
            5'b00010: begin
                merge_cand         <= 1;
                merge_cand_list[0] <= mvf_a0;
            end
            5'b00011: begin
                merge_cand         <= 2;
                merge_cand_list[0] <= mvf_a0;
                merge_cand_list[1] <= mvf_b2;
            end
            5'b00100: begin
                merge_cand         <= 1;
                merge_cand_list[0] <= mvf_b0;
            end
            5'b00101: begin
                merge_cand         <= 2;
                merge_cand_list[0] <= mvf_b0;
                merge_cand_list[1] <= mvf_b2;
            end
            5'b00110: begin
                merge_cand         <= 2;
                merge_cand_list[0] <= mvf_b0;
                merge_cand_list[1] <= mvf_a0;
            end
            5'b00111: begin
                merge_cand         <= 3;
                merge_cand_list[0] <= mvf_b0;
                merge_cand_list[1] <= mvf_a0;
                merge_cand_list[2] <= mvf_b2;
            end
            5'b01000: begin
                merge_cand         <= 1;
                merge_cand_list[0] <= mvf_b1;
            end
            5'b01001: begin
                merge_cand         <= 2;
                merge_cand_list[0] <= mvf_b1;
                merge_cand_list[1] <= mvf_b2;
            end
            5'b01010: begin
                merge_cand         <= 2;
                merge_cand_list[0] <= mvf_b1;
                merge_cand_list[1] <= mvf_a0;
            end
            5'b01011: begin
                merge_cand         <= 3;
                merge_cand_list[0] <= mvf_b1;
                merge_cand_list[1] <= mvf_a0;
                merge_cand_list[2] <= mvf_b2;
            end
            5'b01100: begin
                merge_cand         <= 2;
                merge_cand_list[0] <= mvf_b1;
                merge_cand_list[1] <= mvf_b0;
            end
            5'b01101: begin
                merge_cand         <= 3;
                merge_cand_list[0] <= mvf_b1;
                merge_cand_list[1] <= mvf_b0;
                merge_cand_list[2] <= mvf_b2;
            end
            5'b01110: begin
                merge_cand         <= 3;
                merge_cand_list[0] <= mvf_b1;
                merge_cand_list[1] <= mvf_b0;
                merge_cand_list[2] <= mvf_a0;
            end
            5'b01111: begin
                merge_cand         <= 4;
                merge_cand_list[0] <= mvf_b1;
                merge_cand_list[1] <= mvf_b0;
                merge_cand_list[2] <= mvf_a0;
                merge_cand_list[3] <= mvf_b2;
            end
            5'b10000: begin
                merge_cand         <= 1;
                merge_cand_list[0] <= mvf_a1;
            end
            5'b10001: begin
                merge_cand         <= 2;
                merge_cand_list[0] <= mvf_a1;
                merge_cand_list[1] <= mvf_b2;
            end
            5'b10010: begin
                merge_cand         <= 2;
                merge_cand_list[0] <= mvf_a1;
                merge_cand_list[1] <= mvf_a0;
            end
            5'b10011: begin
                merge_cand         <= 3;
                merge_cand_list[0] <= mvf_a1;
                merge_cand_list[1] <= mvf_a0;
                merge_cand_list[2] <= mvf_b2;
            end
            5'b10100: begin
                merge_cand         <= 2;
                merge_cand_list[0] <= mvf_a1;
                merge_cand_list[1] <= mvf_b0;
            end
            5'b10101: begin
                merge_cand         <= 3;
                merge_cand_list[0] <= mvf_a1;
                merge_cand_list[1] <= mvf_b0;
                merge_cand_list[2] <= mvf_b2;
            end
            5'b10110: begin
                merge_cand         <= 3;
                merge_cand_list[0] <= mvf_a1;
                merge_cand_list[1] <= mvf_b0;
                merge_cand_list[2] <= mvf_a0;
            end
            5'b10111: begin
                merge_cand         <= 4;
                merge_cand_list[0] <= mvf_a1;
                merge_cand_list[1] <= mvf_b0;
                merge_cand_list[2] <= mvf_a0;
                merge_cand_list[3] <= mvf_b2;
            end
            5'b11000: begin
                merge_cand         <= 2;
                merge_cand_list[0] <= mvf_a1;
                merge_cand_list[1] <= mvf_b1;
            end
            5'b11001: begin
                merge_cand         <= 3;
                merge_cand_list[0] <= mvf_a1;
                merge_cand_list[1] <= mvf_b1;
                merge_cand_list[2] <= mvf_b2;
            end
            5'b11010: begin
                merge_cand         <= 3;
                merge_cand_list[0] <= mvf_a1;
                merge_cand_list[1] <= mvf_b1;
                merge_cand_list[2] <= mvf_a0;
            end
            5'b11011: begin
                merge_cand         <= 4;
                merge_cand_list[0] <= mvf_a1;
                merge_cand_list[1] <= mvf_b1;
                merge_cand_list[2] <= mvf_a0;
                merge_cand_list[3] <= mvf_b2;
            end
            5'b11100: begin
                merge_cand         <= 3;
                merge_cand_list[0] <= mvf_a1;
                merge_cand_list[1] <= mvf_b1;
                merge_cand_list[2] <= mvf_b0;
            end
            5'b11101: begin
                merge_cand         <= 4;
                merge_cand_list[0] <= mvf_a1;
                merge_cand_list[1] <= mvf_b1;
                merge_cand_list[2] <= mvf_b0;
                merge_cand_list[3] <= mvf_b2;
            end
            5'b11110: begin
                merge_cand         <= 4;
                merge_cand_list[0] <= mvf_a1;
                merge_cand_list[1] <= mvf_b1;
                merge_cand_list[2] <= mvf_b0;
                merge_cand_list[3] <= mvf_a0;
            end
            5'b11111: begin //availableFlagA0 + availableFlagA1 + availableFlagB0 + availableFlagB1 == 4,availableFlagB1=0
                merge_cand         <= 4;
                merge_cand_list[0] <= mvf_a1;
                merge_cand_list[1] <= mvf_b1;
                merge_cand_list[2] <= mvf_b0;
                merge_cand_list[3] <= mvf_a0;
            end

        endcase
    end

    if (merge_stage == 4) begin
        if (merge_idx < merge_cand) begin
            merge_done                             <= 1;
            merge_stage                            <= 6;
        end else if (i_slice_temporal_mvp_enabled_flag) begin
            if (col_done&&avail_col) begin
                merge_cand_list[merge_cand].refIdx <= 0;
                merge_cand_list[merge_cand].mv     <= mvf_col.mv;
                merge_cand                         <= merge_cand+1;
            end
            if (col_done) begin
                merge_stage                        <= 5;
            end

        end else begin
            merge_stage                            <= 5;
        end
    end

    if (merge_stage == 5) begin
        merge_stage                                <= 6;
        merge_done                                 <= 1;
        if (merge_idx >= merge_cand) begin
            case (merge_cand)
                0: begin
                    merge_cand_list[0].refIdx      <= 0;
                    merge_cand_list[1].refIdx      <= 1<i_num_ref_idx?1:0;
                    merge_cand_list[2].refIdx      <= 2<i_num_ref_idx?2:0;
                    merge_cand_list[3].refIdx      <= 3<i_num_ref_idx?3:0;
                    merge_cand_list[4].refIdx      <= 4<i_num_ref_idx?4:0;
                end
                1: begin
                    merge_cand_list[1].refIdx      <= 0;
                    merge_cand_list[2].refIdx      <= 1<i_num_ref_idx?1:0;
                    merge_cand_list[3].refIdx      <= 2<i_num_ref_idx?2:0;
                    merge_cand_list[4].refIdx      <= 3<i_num_ref_idx?3:0;
                end
                2: begin
                    merge_cand_list[2].refIdx      <= 0;
                    merge_cand_list[3].refIdx      <= 1<i_num_ref_idx?1:0;
                    merge_cand_list[4].refIdx      <= 2<i_num_ref_idx?2:0;
                end
                3: begin
                    merge_cand_list[3].refIdx      <= 0;
                    merge_cand_list[4].refIdx      <= 1<i_num_ref_idx?1:0;
                end
                default: begin
                    merge_cand_list[4].refIdx      <= 0;
                end
            endcase
        end
    end

    if (merge_stage == 6) begin
        
    end

end

always @ (posedge clk)
if (rst||global_rst) begin
    o_mv_done         <= 0;
end else begin
    if (i_merge_flag) begin
        if (merge_done) begin
            o_mvf     <= merge_cand_list[merge_idx];
            o_mv_done <= 1;
        end
    end else begin
        if (mvp_done) begin
            o_mvf     <= mvpList[mvp_l0_flag];
            o_mv_done <= 1;
        end
    end
end

scale scale_a
(
    .clk         (clk),
    .rst         (reset_scale_a),

    .poc_diff1   (i_delta_poc[mvf_a.refIdx]),
    .poc_diff2   (i_delta_poc[ref_idx]),
    .mv0         (mvf_a.mv.mv[0]),
    .mv1         (mvf_a.mv.mv[1]),

    .mv0_scaled  (mva_scaled.mv[0]),
    .mv1_scaled  (mva_scaled.mv[1]),
    .scale_done  (a_scale_done)
);



scale scale_b
(
    .clk         (clk),
    .rst         (reset_scale_b),

    .poc_diff1   (i_delta_poc[mvf_b_to_scale.refIdx]),
    .poc_diff2   (i_delta_poc[ref_idx]),
    .mv0         (mvf_b_to_scale.mv.mv[0]),
    .mv1         (mvf_b_to_scale.mv.mv[1]),

    .mv0_scaled  (mvb_scaled.mv[0]),
    .mv1_scaled  (mvb_scaled.mv[1]),
    .scale_done  (b_scale_done)
);

`ifdef RANDOM_INIT
integer  seed;
integer random_val;
initial  begin
    seed                               = $get_initial_random_seed(); 
    random_val                         = $random(seed);
    m_axi_arvalid                      = {random_val,random_val};
    m_axi_arlen                        = {random_val[1:0],random_val[31:2],random_val[1:0],random_val[31:2]};
    m_axi_araddr                       = {random_val[2:0],random_val[31:3],random_val[2:0],random_val[31:3]};
    m_axi_rready                       = {random_val[3:0],random_val[31:4],random_val[3:0],random_val[31:4]};
    o_mvf                              = {random_val[4:0],random_val[31:5],random_val[4:0],random_val[31:5]};
    o_col_param_fetch_done             = {random_val[5:0],random_val[31:6],random_val[5:0],random_val[31:6]};
    o_mv_done                          = {random_val[6:0],random_val[31:7],random_val[6:0],random_val[31:7]};
    col_stage                          = {random_val[7:0],random_val[31:8],random_val[7:0],random_val[31:8]};
    col_done                           = {random_val[8:0],random_val[31:9],random_val[8:0],random_val[31:9]};
    last_col                           = {random_val[9:0],random_val[31:10],random_val[9:0],random_val[31:10]};
    last_row                           = {random_val[10:0],random_val[31:11],random_val[10:0],random_val[31:11]};
    first_col                          = {random_val[11:0],random_val[31:12],random_val[11:0],random_val[31:12]};
    first_row                          = {random_val[12:0],random_val[31:13],random_val[12:0],random_val[31:13]};
    last_col_width                     = {random_val[13:0],random_val[31:14],random_val[13:0],random_val[31:14]};
    last_row_height                    = {random_val[14:0],random_val[31:15],random_val[14:0],random_val[31:15]};
    ref_idx                            = {random_val[15:0],random_val[31:16],random_val[15:0],random_val[31:16]};
    reset_scale_col                    = {random_val[16:0],random_val[31:17],random_val[16:0],random_val[31:17]};
    cIdx                               = {random_val[17:0],random_val[31:18],random_val[17:0],random_val[31:18]};
    partIdx                            = {random_val[18:0],random_val[31:19],random_val[18:0],random_val[31:19]};
    part_mode                          = {random_val[19:0],random_val[31:20],random_val[19:0],random_val[31:20]};
    MaxNumMergeCand                    = {random_val[21:0],random_val[31:22],random_val[21:0],random_val[31:22]};
    max_merge_cand_minus1              = {random_val[22:0],random_val[31:23],random_val[22:0],random_val[31:23]};
    merge_idx                          = {random_val[23:0],random_val[31:24],random_val[23:0],random_val[31:24]};
    mvp_l0_flag                        = {random_val[24:0],random_val[31:25],random_val[24:0],random_val[31:25]};
    x0                                 = {random_val[25:0],random_val[31:26],random_val[25:0],random_val[31:26]};
    y0                                 = {random_val[26:0],random_val[31:27],random_val[26:0],random_val[31:27]};
    xPb                                = {random_val[27:0],random_val[31:28],random_val[27:0],random_val[31:28]};
    yPb                                = {random_val[28:0],random_val[31:29],random_val[28:0],random_val[31:29]};
    nPbW                               = {random_val[29:0],random_val[31:30],random_val[29:0],random_val[31:30]};
    nPbH                               = {random_val[30:0],random_val[31],random_val[30:0],random_val[31]};
    xNbA0                              = {random_val[31:0],random_val[31:0]};
    yNbA0                              = {random_val,random_val};
    xNbA1                              = {random_val[1:0],random_val[31:2],random_val[1:0],random_val[31:2]};
    yNbA1                              = {random_val[2:0],random_val[31:3],random_val[2:0],random_val[31:3]};
    xNbB0                              = {random_val[3:0],random_val[31:4],random_val[3:0],random_val[31:4]};
    yNbB0                              = {random_val[4:0],random_val[31:5],random_val[4:0],random_val[31:5]};
    xNbB1                              = {random_val[5:0],random_val[31:6],random_val[5:0],random_val[31:6]};
    yNbB1                              = {random_val[6:0],random_val[31:7],random_val[6:0],random_val[31:7]};
    xNbB2                              = {random_val[7:0],random_val[31:8],random_val[7:0],random_val[31:8]};
    yNbB2                              = {random_val[8:0],random_val[31:9],random_val[8:0],random_val[31:9]};
    xColCtr                            = {random_val[9:0],random_val[31:10],random_val[9:0],random_val[31:10]};
    yColCtr                            = {random_val[10:0],random_val[31:11],random_val[10:0],random_val[31:11]};
    xColBr                             = {random_val[11:0],random_val[31:12],random_val[11:0],random_val[31:12]};
    yColBr                             = {random_val[12:0],random_val[31:13],random_val[12:0],random_val[31:13]};
    x_left_bottom_most                 = {random_val[13:0],random_val[31:14],random_val[13:0],random_val[31:14]};
    y_left_bottom_most                 = {random_val[14:0],random_val[31:15],random_val[14:0],random_val[31:15]};
    x_up_right_most                    = {random_val[15:0],random_val[31:16],random_val[15:0],random_val[31:16]};
    y_up_right_most                    = {random_val[16:0],random_val[31:17],random_val[16:0],random_val[31:17]};
    xPb_par                            = {random_val[17:0],random_val[31:18],random_val[17:0],random_val[31:18]};
    yPb_par                            = {random_val[18:0],random_val[31:19],random_val[18:0],random_val[31:19]};
    xNbA0_par                          = {random_val[19:0],random_val[31:20],random_val[19:0],random_val[31:20]};
    yNbA0_par                          = {random_val[20:0],random_val[31:21],random_val[20:0],random_val[31:21]};
    xNbA1_par                          = {random_val[21:0],random_val[31:22],random_val[21:0],random_val[31:22]};
    yNbA1_par                          = {random_val[22:0],random_val[31:23],random_val[22:0],random_val[31:23]};
    xNbB0_par                          = {random_val[23:0],random_val[31:24],random_val[23:0],random_val[31:24]};
    yNbB0_par                          = {random_val[24:0],random_val[31:25],random_val[24:0],random_val[31:25]};
    xNbB1_par                          = {random_val[25:0],random_val[31:26],random_val[25:0],random_val[31:26]};
    yNbB1_par                          = {random_val[26:0],random_val[31:27],random_val[26:0],random_val[31:27]};
    xNbB2_par                          = {random_val[27:0],random_val[31:28],random_val[27:0],random_val[31:28]};
    yNbB2_par                          = {random_val[28:0],random_val[31:29],random_val[28:0],random_val[31:29]};
    param_ddr_base                     = {random_val[29:0],random_val[31:30],random_val[29:0],random_val[31:30]};
    x_fetch_col                        = {random_val[30:0],random_val[31],random_val[30:0],random_val[31]};
    y_fetch_col                        = {random_val[31:0],random_val[31:0]};
    pred_mode_col_pic                  = {random_val,random_val};
    pred_mode_col_pic_right            = {random_val[1:0],random_val[31:2],random_val[1:0],random_val[31:2]};
    ref_poc_col_pic                    = {random_val[2:0],random_val[31:3],random_val[2:0],random_val[31:3]};
    ref_poc_col_pic_right              = {random_val[3:0],random_val[31:4],random_val[3:0],random_val[31:4]};
    col_param_fetch_stage              = {random_val[4:0],random_val[31:5],random_val[4:0],random_val[31:5]};
    fetch_col_i                        = {random_val[5:0],random_val[31:6],random_val[5:0],random_val[31:6]};
    fetch_col_j                        = {random_val[6:0],random_val[31:7],random_val[6:0],random_val[31:7]};
    avail_col                          = {random_val[7:0],random_val[31:8],random_val[7:0],random_val[31:8]};
    predmode_col                       = {random_val[8:0],random_val[31:9],random_val[8:0],random_val[31:9]};
    ref_poc_col                        = {random_val[9:0],random_val[31:10],random_val[9:0],random_val[31:10]};
    delta_poc_ref                      = {random_val[10:0],random_val[31:11],random_val[10:0],random_val[31:11]};
    cond_dpoc0_a1                      = {random_val[11:0],random_val[31:12],random_val[11:0],random_val[31:12]};
    cond_dpoc0_a0                      = {random_val[12:0],random_val[31:13],random_val[12:0],random_val[31:13]};
    cond_dpoc0_b0                      = {random_val[13:0],random_val[31:14],random_val[13:0],random_val[31:14]};
    cond_dpoc0_b1                      = {random_val[14:0],random_val[31:15],random_val[14:0],random_val[31:15]};
    cond_dpoc0_b2                      = {random_val[15:0],random_val[31:16],random_val[15:0],random_val[31:16]};
    cond_mvf_a1_eq_b1                  = {random_val[16:0],random_val[31:17],random_val[16:0],random_val[31:17]};
    cond_mvf_b0_eq_b1                  = {random_val[17:0],random_val[31:18],random_val[17:0],random_val[31:18]};
    cond_mvf_a0_eq_a1                  = {random_val[18:0],random_val[31:19],random_val[18:0],random_val[31:19]};
    cond_mvf_a1_eq_b2                  = {random_val[19:0],random_val[31:20],random_val[19:0],random_val[31:20]};
    cond_mvf_b1_eq_b2                  = {random_val[20:0],random_val[31:21],random_val[20:0],random_val[31:21]};
    predmode_nb_a0                     = {random_val[21:0],random_val[31:22],random_val[21:0],random_val[31:22]};
    predmode_nb_a1                     = {random_val[22:0],random_val[31:23],random_val[22:0],random_val[31:23]};
    predmode_nb_b0                     = {random_val[23:0],random_val[31:24],random_val[23:0],random_val[31:24]};
    predmode_nb_b1                     = {random_val[24:0],random_val[31:25],random_val[24:0],random_val[31:25]};
    predmode_nb_b2                     = {random_val[25:0],random_val[31:26],random_val[25:0],random_val[31:26]};
    avail_a0                           = {random_val[26:0],random_val[31:27],random_val[26:0],random_val[31:27]};
    avail_a1                           = {random_val[27:0],random_val[31:28],random_val[27:0],random_val[31:28]};
    avail_b0                           = {random_val[28:0],random_val[31:29],random_val[28:0],random_val[31:29]};
    avail_b1                           = {random_val[29:0],random_val[31:30],random_val[29:0],random_val[31:30]};
    avail_b2                           = {random_val[30:0],random_val[31],random_val[30:0],random_val[31]};
    avail_m_a0                         = {random_val[31:0],random_val[31:0]};
    avail_m_a1                         = {random_val,random_val};
    avail_m_b0                         = {random_val[1:0],random_val[31:2],random_val[1:0],random_val[31:2]};
    avail_m_b1                         = {random_val[2:0],random_val[31:3],random_val[2:0],random_val[31:3]};
    avail_m_b2                         = {random_val[3:0],random_val[31:4],random_val[3:0],random_val[31:4]};
    avail_flag_a0                      = {random_val[4:0],random_val[31:5],random_val[4:0],random_val[31:5]};
    avail_flag_a1                      = {random_val[5:0],random_val[31:6],random_val[5:0],random_val[31:6]};
    avail_flag_b0                      = {random_val[6:0],random_val[31:7],random_val[6:0],random_val[31:7]};
    avail_flag_b1                      = {random_val[7:0],random_val[31:8],random_val[7:0],random_val[31:8]};
    avail_flag_b2                      = {random_val[8:0],random_val[31:9],random_val[8:0],random_val[31:9]};
    avail_a                            = {random_val[9:0],random_val[31:10],random_val[9:0],random_val[31:10]};
    avail_b                            = {random_val[10:0],random_val[31:11],random_val[10:0],random_val[31:11]};
    left_bottom_avail                  = {random_val[11:0],random_val[31:12],random_val[11:0],random_val[31:12]};
    up_right_avail                     = {random_val[12:0],random_val[31:13],random_val[12:0],random_val[31:13]};
    zorder_left_bottom                 = {random_val[13:0],random_val[31:14],random_val[13:0],random_val[31:14]};
    zorder_a0                          = {random_val[14:0],random_val[31:15],random_val[14:0],random_val[31:15]};
    zorder_up_right                    = {random_val[15:0],random_val[31:16],random_val[15:0],random_val[31:16]};
    zorder_b0                          = {random_val[16:0],random_val[31:17],random_val[16:0],random_val[31:17]};
    numMvpCand                         = {random_val[17:0],random_val[31:18],random_val[17:0],random_val[31:18]};
    reset_scale_a                      = {random_val[18:0],random_val[31:19],random_val[18:0],random_val[31:19]};
    reset_scale_b                      = {random_val[19:0],random_val[31:20],random_val[19:0],random_val[31:20]};
    isScaledFlag                       = {random_val[20:0],random_val[31:21],random_val[20:0],random_val[31:21]};
    mvp_cand                           = {random_val[21:0],random_val[31:22],random_val[21:0],random_val[31:22]};
    avail_flag_a                       = {random_val[22:0],random_val[31:23],random_val[22:0],random_val[31:23]};
    avail_flag_b                       = {random_val[23:0],random_val[31:24],random_val[23:0],random_val[31:24]};
    avail_flag_b0_mvp                  = {random_val[24:0],random_val[31:25],random_val[24:0],random_val[31:25]};
    avail_flag_b1_mvp                  = {random_val[25:0],random_val[31:26],random_val[25:0],random_val[31:26]};
    avail_flag_b2_mvp                  = {random_val[26:0],random_val[31:27],random_val[26:0],random_val[31:27]};
    stage                              = {random_val[27:0],random_val[31:28],random_val[27:0],random_val[31:28]};
    mvp_done                           = {random_val[28:0],random_val[31:29],random_val[28:0],random_val[31:29]};
    two_b_cand_possible                = {random_val[29:0],random_val[31:30],random_val[29:0],random_val[31:30]};
    merge_stage                        = {random_val[30:0],random_val[31],random_val[30:0],random_val[31]};
    merge_cand                         = {random_val[31:0],random_val[31:0]};
    merge_done                         = {random_val,random_val};
end
`endif


endmodule
