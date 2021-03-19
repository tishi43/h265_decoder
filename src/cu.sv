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

module cu
(
 input wire                         clk,
 input wire                         rst,
 input wire                         global_rst,
 input wire                         i_rst_slice,
 input wire                         i_rst_ctb,
 input wire                         i_rst_filter,
 input wire                         en,
 input wire                         i_tu_en,

 input wire              [ 1: 0]    i_slice_type,

 input wire                         i_transquant_bypass_enabled_flag,
 input wire    [`max_x_bits-1:0]    i_PicWidthInSamplesY,
 input wire    [`max_y_bits-1:0]    i_PicHeightInSamplesY,
 input wire              [ 2: 0]    i_five_minus_max_num_merge_cand,
 input wire                         i_amp_enabled_flag,                   //sps
 input wire              [ 2: 0]    i_max_transform_hierarchy_depth_intra,
 input wire              [ 2: 0]    i_max_transform_hierarchy_depth_inter,
 input wire                         i_cu_qp_delta_enabled_flag,           //pps
 input wire              [ 1: 0]    i_diff_cu_qp_delta_depth,             //pps
 input wire                         i_transform_skip_enabled_flag,        //pps
 input wire                         i_sign_data_hiding_enabled_flag,      //pps
 input wire                         i_constrained_intra_pred_flag,        //pps
 input wire                         i_strong_intra_smoothing_enabled_flag, //sps
 input wire              [ 3: 0]    i_num_ref_idx,                        //slice header
 input wire signed       [ 5: 0]    i_qp_cb_offset,
 input wire signed       [ 5: 0]    i_qp_cr_offset,
 input wire              [ 2: 0]    i_log2_parallel_merge_level,
 input wire                         i_slice_temporal_mvp_enabled_flag,
 input wire signed       [ 3: 0]    i_slice_beta_offset_div2,
 input wire signed       [ 3: 0]    i_slice_tc_offset_div2,

 output reg              [ 4: 0]    o_cm_idx_cu,
 output wire             [ 5: 0]    o_cm_idx_xy_pref,
 output wire             [ 5: 0]    o_cm_idx_sig,
 output wire             [ 5: 0]    o_cm_idx_gt1_etc,
 output reg                         o_dec_bin_en_cu,
 output wire                        o_dec_bin_en_xy_pref,
 output wire                        o_dec_bin_en_sig,
 output wire                        o_dec_bin_en_gt1_etc,
 output reg                         o_byp_dec_en_cu,
 output wire                        o_byp_dec_en_tu,

(*mark_debug="true"*)
 input  wire                        i_bin_cu,
(*mark_debug="true"*)
 input  wire                        i_bin_xy_pref,
(*mark_debug="true"*)
 input  wire                        i_bin_sig,
(*mark_debug="true"*)
 input  wire                        i_bin_gt1_etc,
(*mark_debug="true"*)
 input  wire                        i_dec_bin_valid,
(*mark_debug="true"*)
 input  wire                        i_bin_byp,

 input wire              [ 5: 0]    i_qPY_PRED,
 input wire              [ 5: 0]    i_qPY,

 input wire    [`max_x_bits-1:0]    i_x0,
 input wire    [`max_y_bits-1:0]    i_y0,
 input wire                         i_last_col,
 input wire                         i_last_row,
 input wire                         i_first_col,
 input wire                         i_first_row,
 input wire              [ 6: 0]    i_last_col_width,
 input wire              [ 6: 0]    i_last_row_height,
 input wire              [31: 0]    fd_log,
 input wire              [31: 0]    fd_pred,
 input wire              [31: 0]    fd_intra_pred_chroma,
 input wire              [31: 0]    fd_tq_luma,
 input wire              [31: 0]    fd_tq_cb,
 input wire              [31: 0]    fd_tq_cr,
 input wire              [31: 0]    fd_filter,
 input wire              [31: 0]    fd_deblock,
 input wire              [ 2: 0]    i_log2CbSize, //64=2^6
 input wire              [ 6: 0]    i_CbSize,
 input wire              [15: 0]    i_slice_num,
 input wire                         i_IsCuQpDeltaCoded,
 input wire              [ 4: 0]    i_slice_data_state,

 input wire              [ 8: 0]    i_ivlCurrRange,
 input wire              [ 8: 0]    i_ivlOffset,

 output reg              [ 1: 0]    o_filter_stage,
(*mark_debug="true"*)
 output reg              [ 5: 0]    o_cu_state,
 output wire             [ 5: 0]    o_tu_state,
 output reg                         o_ctb_rec_done,

 input wire  [`max_poc_bits-1:0]    i_cur_poc,
 input wire [0:`max_ref-1][14:0]    i_delta_poc,
 input wire [`max_ref-1:0][ 3:0]    i_ref_dpb_slots,
 input wire               [ 3:0]    i_cur_pic_dpb_slot,
 input wire               [ 3:0]    i_col_ref_idx,
 input wire     [7:0][7:0][ 5:0]    i_qpy,

 input wire [$bits(sao_params_t)-1:0]      i_sao_param,
 input wire [$bits(sao_params_t)-1:0]      i_sao_param_left,
 input wire [$bits(sao_params_t)-1:0]      i_sao_param_up,
 input wire [$bits(sao_params_t)-1:0]      i_sao_param_leftup,

 input  wire                        m_axi_arready,
 output wire                        m_axi_arvalid,
 output wire              [ 3:0]    m_axi_arlen,
 output wire              [31:0]    m_axi_araddr,

 output wire                        m_axi_rready,
 input  wire              [63:0]    m_axi_rdata,
 input  wire                        m_axi_rvalid,
 input  wire                        m_axi_rlast,

 input  wire                        m_axi_awready,
 output wire              [31:0]    m_axi_awaddr,
 output wire              [ 3:0]    m_axi_awlen,
 output wire                        m_axi_awvalid,

 input  wire                        m_axi_wready,
 output wire              [63:0]    m_axi_wdata,
 output wire              [ 7:0]    m_axi_wstrb,
 output wire                        m_axi_wlast,
 output wire                        m_axi_wvalid,

 output wire                        o_IsCuQpDeltaCoded,
 output wire             [ 5:0]     o_QpY
);

reg                            cu_transquant_bypass_flag  ;
reg                            rst_tu                     ;
reg                 [15:0]     slice_num                  ;

(*mark_debug="true"*)
reg      [`max_x_bits-1:0]     x0                         ;
(*mark_debug="true"*)
reg      [`max_y_bits-1:0]     y0                         ;
(*mark_debug="true"*)
reg                 [ 5:0]     xPb                        ;
(*mark_debug="true"*)
reg                 [ 5:0]     yPb                        ;
(*mark_debug="true"*)
reg                 [ 5:0]     xTu                        ;
reg                 [ 5:0]     yTu                        ;
(*mark_debug="true"*)
reg                 [ 2:0]     log2CbSize                 ; //64=2^6
reg                 [ 6:0]     CbSize                     ;
reg                            first_cycle_parse_tu       ;
reg                            first_tu_in_cu             ;
reg                            first_cycle_cu_end         ;

wire [`max_ctb_x_bits-1:0]     xCtb                       ;
wire [`max_ctb_y_bits-1:0]     yCtb                       ;
wire                 [5:0]     x                          ;
wire                 [5:0]     y                          ;

assign xCtb = x0[`max_x_bits-1:6];
assign yCtb = y0[`max_y_bits-1:6];
assign x    = x0[5:0]; //CTB 64x64内部坐标
assign y    = y0[5:0];

reg                  [5:0]     x0_right_most              ;
always @ (posedge clk)
    x0_right_most  <= x0[5:0]+CbSize-1;

reg                            last_col                        ;
reg                            last_row                        ;
reg                            first_col                       ;
reg                            first_row                       ;
reg                  [6:0]     last_col_width                  ;
reg                  [6:0]     last_row_height                 ;
reg        [7:0][7:0][5:0]     qpy                             ;
wire                 [1:0]     cIdx                            ; //output from tu
reg                  [5:0]     i                               ; //32x32TU最多含64个4x4 sub block
reg                  [3:0]     j                               ;
reg                  [3:0]     k                               ;
reg                  [1:0]     partIdx                         ;

reg                  [2:0]     part_mode                       ;
reg                            pred_mode                       ;
reg                  [1:0]     max_bits                        ;
reg                  [2:0]     part_num                        ;
reg                            prev_intra_luma_pred_flag[0:3]  ;
reg                  [1:0]     mpm_idx                         ;

reg                  [5:0]     intra_pred_mode_chroma          ;
reg                  [5:0]     rem_intra_luma_pred_mode[0:3]   ;
reg                  [5:0]     IntraPredModeY                  ;
reg                  [5:0]     IntraPredModeC                  ;
reg                  [5:0]     cu_intra_luma_pred_mode[0:3]    ; //cu->intra_luma_pred_mode

reg                  [5:0]     cur_rem_intra_luma_pred_mode    ;


reg                  [1:0]     symbol                          ;
wire                 [5:0]     mode_list[0:3]                  ;
assign mode_list = {`INTRA_PLANAR, `INTRA_VER, `INTRA_HOR, `INTRA_DC};
reg                            rqt_root_cbf                    ;

reg                  [5:0]     candIntraPredModeA              ;
reg                  [5:0]     candIntraPredModeB              ;
reg                  [5:0]     candModeList[0:2]               ;

wire                           IntraSplitFlag                  ;
wire                 [2:0]     MaxTrafoDepth                   ;

(*mark_debug="true"*)
reg                  [2:0]     trafoDepth                      ;
(*mark_debug="true"*)
reg                  [2:0]     log2TrafoSize                   ;
(*mark_debug="true"*)
reg                  [6:0]     trafoSize                       ;
(*mark_debug="true"*)
reg                  [1:0]     dep_partIdx_tu[0:4]             ; //正在解析的tu在当前depth的index, 64,32, 16, 8, 4 5层,第0层用不到,浪费2bit reg无所谓了
reg                  [1:0]     blkIdx                          ;
wire                 [4:0]     cMax                            ;
assign cMax = trafoSize-1;

assign IntraSplitFlag = (pred_mode == `MODE_INTRA) && (part_mode == `PART_NxN);
assign MaxTrafoDepth = (pred_mode == `MODE_INTRA)?
    (i_max_transform_hierarchy_depth_intra+IntraSplitFlag):i_max_transform_hierarchy_depth_inter;

wire        interSplitFlag                            ;
assign interSplitFlag = (i_max_transform_hierarchy_depth_inter == 0) && (pred_mode == `MODE_INTER) &&
    (part_mode != `PART_2Nx2N) && (trafoDepth == 0);


wire                            cbf_luma              ;
(*mark_debug="true"*)
reg                             base_cbf_cb[0:4]      ;
(*mark_debug="true"*)
reg                             base_cbf_cr[0:4]      ;
reg                             cbf_cb                ;
reg                             cbf_cr                ;
(*mark_debug="true"*)
reg                             split_tu              ;

reg                             dram_cbf_luma_up_we   ;
reg  [`max_ctb_x_bits-1:0]      dram_cbf_luma_up_addr ;
reg                 [15:0]      dram_cbf_luma_up_din  ;
wire                [15:0]      dram_cbf_luma_up_dout ;

//2bit * 8=16,最多64x16=1024bit,用dram
dram #(`max_ctb_x_bits, 16) dram_cbf_luma_up
(
     .clk(clk),
     .en(1'b1),
     .we(dram_cbf_luma_up_we),
     .addr(dram_cbf_luma_up_addr),
     .data_in(dram_cbf_luma_up_din),
     .data_out(dram_cbf_luma_up_dout)
 );

reg                 [15:0]      cbf_luma_left                   ;
reg                 [15:0]      cbf_luma_up                     ;



reg                 [ 5:0]      intra_luma_pred_mode_left[0:15] ;
reg                 [ 5:0]      intra_luma_pred_mode_up[0:15]   ;
wire                [ 5:0]      intra_luma_left                 ;
wire                [ 5:0]      intra_luma_up                   ;


assign intra_luma_left  = intra_luma_pred_mode_left[y0[5:2]];
assign intra_luma_up = intra_luma_pred_mode_up[x0[5:2]];


//1bit * 8=8,最多64x8=512bit,用dram
reg                             dram_up_ctb_cu_predmode_we   ;
reg  [`max_ctb_x_bits-1:0]      dram_up_ctb_cu_predmode_addr ;
reg                 [ 7:0]      dram_up_ctb_cu_predmode_din  ;
wire                [ 7:0]      dram_up_ctb_cu_predmode_dout ;

dram #(`max_ctb_x_bits, 8) dram_up_ctb_cu_predmode
(
     .clk(clk),
     .en(1'b1),
     .we(dram_up_ctb_cu_predmode_we),
     .addr(dram_up_ctb_cu_predmode_addr),
     .data_in(dram_up_ctb_cu_predmode_din),
     .data_out(dram_up_ctb_cu_predmode_dout)
 );
reg                              phase                         ;
reg             [7:0][ 7:0]      cur_ctb_cu_predmode           ;
reg                  [ 7:0]      cu_predmode_left_init1        ;
reg                  [ 7:0]      cu_predmode_left_init0        ; //默认设0=MODE_INTER
reg                  [15:0]      cu_predmode_up_init0          ;
reg                  [15:0]      cu_predmode_up_init1          ;
reg                  [ 7:0]      cu_predmode_leftup_init1      ;
reg                  [ 7:0]      cu_predmode_leftup_init0      ;

reg                              dram_cu_skip_up_we            ;
reg  [`max_ctb_x_bits-1:0]       dram_cu_skip_up_addr          ;
reg                  [ 7:0]      dram_cu_skip_up_din           ;
wire                 [ 7:0]      dram_cu_skip_up_dout          ;

dram #(`max_ctb_x_bits, 8) dram_cu_skip_up
(
     .clk(clk),
     .en(1'b1),
     .we(dram_cu_skip_up_we),
     .addr(dram_cu_skip_up_addr),
     .data_in(dram_cu_skip_up_din),
     .data_out(dram_cu_skip_up_dout)
 );

reg                             cu_skip_flag      ;
reg                  [7:0]      cu_skip_flag_left ;
reg                  [7:0]      cu_skip_flag_up   ;
wire                            skip_left         ;
wire                            skip_up           ;

assign            skip_left  = cu_skip_flag_left[y0[5:3]];
assign            skip_up = cu_skip_flag_up[x0[5:3]];


function [17:0] f_get_cand_mode_list;
 input              [5:0]   candA  ;
 input              [5:0]   candB  ;

    begin
         if (candB == candA) begin
             if (candA < 2) begin
                 f_get_cand_mode_list[ 5: 0]                =  `INTRA_PLANAR;
                 f_get_cand_mode_list[11: 6]                =  `INTRA_DC;
                 f_get_cand_mode_list[17:12]                =  `INTRA_ANGULAR26;
             end else begin
                 f_get_cand_mode_list[ 5: 0]                =  candA;
                 //((candIntraPredModeA + 29) % 32) + 2;
                 if (candA >= 35)
                     f_get_cand_mode_list[11: 6]            =  candA - 33;
                 else if (candA >= 3)
                     f_get_cand_mode_list[11: 6]            =  candA - 1;
                 else
                     f_get_cand_mode_list[11: 6]            =  candA + 31;
                 //((candIntraPredModeA - 1 ) % 32) + 2;
                 if (candA >= 33)
                     f_get_cand_mode_list[17:12]            =  candA - 31;
                 else
                     f_get_cand_mode_list[17:12]            =  candA + 1;
             end
         end else begin
             f_get_cand_mode_list[ 5: 0]                    =  candA;
             f_get_cand_mode_list[11: 6]                    =  candB;
             if (candA != `INTRA_PLANAR && candB != `INTRA_PLANAR) begin
                 f_get_cand_mode_list[17:12]                =  `INTRA_PLANAR;
             end else if (candA != `INTRA_DC && candB != `INTRA_DC) begin
                 f_get_cand_mode_list[17:12]                =  `INTRA_DC;
             end else begin
                 f_get_cand_mode_list[17:12]                =  `INTRA_ANGULAR26;
             end
         end
    end
endfunction


reg                            merge_flag                     ;
reg                  [2:0]     MaxNumMergeCand                ;
reg                  [2:0]     max_merge_cand_minus2          ;
reg                  [2:0]     merge_idx                      ;

reg                  [1:0]     abs_mvd_greater0_flag          ;
reg                  [1:0]     abs_mvd_greater1_flag          ;
reg                  [1:0]     mvd_sign_flag                  ;
reg                            mvp_l0_flag                    ;
reg                  [3:0]     ref_idx_l0                     ;
reg                  [3:0]     num_ref_idx_l0_active_minus1   ;
reg                  [3:0]     num_ref_idx_l0_active_minus2   ;

reg                 [13:0]     abs_mvd_minus2                 ; //todo位宽
reg                 [13:0]     abs_mvd                        ;
reg signed          [14:0]     mvd[1:0]                       ;
reg                 [13:0]     one_shift_k                    ;

reg                            reset_mv                       ;

reg                  [5:0]     xPb_right_most                 ;
reg                  [6:0]     nPbW                           ;
reg                  [6:0]     nPbH                           ;
reg                  [5:0]     xPb_nxt                        ;
reg                  [5:0]     yPb_nxt                        ;
reg                  [5:0]     xPb_save                       ;
reg                  [5:0]     yPb_save                       ;

always @ (posedge clk)
begin
    if (cu_skip_flag) begin
        part_num          <= 1;
        nPbW              <= CbSize;
        nPbH              <= CbSize;
    end else begin
        case (part_mode)
            `PART_2Nx2N: begin
                part_num  <= 1;
                nPbW      <= CbSize;
                nPbH      <= CbSize;
            end
            `PART_2NxN : begin
                part_num  <= 2;
                nPbW      <= CbSize;
                nPbH      <= CbSize[6:1];
                xPb_nxt   <= x0[5:0];
                yPb_nxt   <= y0[5:0]+ CbSize[6:1];
            end
            `PART_Nx2N : begin
                part_num  <= 2;
                nPbW      <= CbSize[6:1];
                nPbH      <= CbSize;
                xPb_nxt   <= x0[5:0]+ CbSize[6:1];
                yPb_nxt   <= y0[5:0];
            end
            `PART_2NxnU: begin
                part_num  <= 2;
                nPbW      <= CbSize;
                if (partIdx==0)
                    nPbH  <= CbSize[6:2];
                else
                    nPbH  <= CbSize[6:2]+CbSize[6:1];
                xPb_nxt   <= x0[5:0];
                yPb_nxt   <= y0[5:0]+CbSize[6:2];
            end
            `PART_2NxnD: begin
                part_num  <= 2;
                nPbW      <= CbSize;
                if (partIdx==0)
                    nPbH  <= CbSize[6:2]+CbSize[6:1];
                else
                    nPbH  <= CbSize[6:2];
                xPb_nxt   <= x0[5:0];
                yPb_nxt   <= y0[5:0]+CbSize[6:2]+CbSize[6:1];
            end
            `PART_nLx2N: begin
                part_num  <= 2;
                nPbH      <= CbSize;
                if (partIdx==0)
                    nPbW  <= CbSize[6:2];
                else
                    nPbW  <= CbSize[6:2]+CbSize[6:1];
                xPb_nxt   <= x0[5:0]+CbSize[6:2];
                yPb_nxt   <= y0[5:0];
            end
            `PART_nRx2N: begin
                part_num  <= 2;
                nPbH      <= CbSize;
                if (partIdx==0)
                    nPbW  <= CbSize[6:2]+CbSize[6:1];
                else
                    nPbW  <= CbSize[6:2];
                xPb_nxt   <= x0[5:0]+CbSize[6:2]+CbSize[6:1];
                yPb_nxt   <= y0[5:0];
            end
            default    : begin //PART_NxN
                part_num  <= 4;
                nPbW      <= CbSize[6:1];
                nPbH      <= CbSize[6:1];
                xPb_nxt   <= x0[5:0]+CbSize[6:1];
                yPb_nxt   <= y0[5:0];
            end
        endcase
    end

end


PuInfo                            pu_info            ;
wire                              mv_done            ;
MvField                           pu_mvf_w           ;
MvField                           pu_mvf             ;

//  ctb0        |   ctb1
//______________|_2_|___________
//           | 1|
//  ctb2        |
//              |
MvField             [15:0]        left_mvf           ;
//上面1的leftup 2，除了上面的ctb0，还要从ctb1多取一个
MvField             [16:0]        up_mvf             ;
MvField             [15:0]        left_up_mvf        ;
MvField             [15:0]        left_mvf_w         ;
MvField             [15:0]        up_mvf_w           ;
MvField             [15:0]        left_up_mvf_w      ;
reg           [15:0][14:0]        delta_poc_up       ;
reg           [15:0][14:0]        delta_poc_up_w     ;
reg           [15:0][14:0]        delta_poc_left     ;
reg           [15:0][14:0]        delta_poc_left_w   ;
reg                 [14:0]        delta_poc_cur_pu   ;
reg                               store_bs_pu_bound  ;

genvar I;
generate
    for (I=0;I<16;I++)
    begin: mvf_label
        always @(*)
        begin
            if (I>=xPb[5:2] && I<xPb[5:2]+nPbW[6:2]) begin
                up_mvf_w[I]               = pu_mvf;
                delta_poc_up_w[I]         = i_delta_poc[pu_mvf.refIdx];
            end else begin
                up_mvf_w[I]               = up_mvf[I];
                delta_poc_up_w[I]         = delta_poc_up[I];
            end

            if (I>=yPb[5:2] && I<yPb[5:2]+nPbH[6:2]) begin
                left_mvf_w[I]             = pu_mvf;
                delta_poc_left_w[I]       = i_delta_poc[pu_mvf.refIdx];
            end else begin
                left_mvf_w[I]             = left_mvf[I];
                delta_poc_left_w[I]       = delta_poc_left[I];
            end

            if (I==yPb[5:2]) begin
                left_up_mvf_w[I]          = up_mvf[xPb_right_most[5:2]];
            end else if (I>yPb[5:2] && I<yPb[5:2]+nPbH[6:2]) begin //to debug
                left_up_mvf_w[I]          = pu_mvf;
            end else begin
                left_up_mvf_w[I]          = left_up_mvf[I];
            end

        end

    end
endgenerate

reg           rec_done_luma         ;
reg           rec_done_cb           ;
reg           rec_done_cr           ;
reg           intra_pred_luma_done  ;
reg           intra_pred_cb_done    ;
reg           intra_pred_cr_done    ;
reg           inter_pred_done       ; //3个component，最多4个pu全部完成
reg           inter_pred_luma_done  ;
reg           inter_pred_cb_done    ;
reg           inter_pred_cr_done    ;
reg           up_mvf_fetch_done     ;
wire          col_param_fetch_done  ;

//rst_ctb时i_x0,i_y0等已经更新为新的ctb了，x0,y0等还是老的，在rst时才更新进来，中间有sao param的解析
always @ (posedge clk)
if (global_rst) begin
    phase                                            <= 0;
    rst_tu                                           <= 0;
    reset_mv                                         <= 0;
    o_cu_state                                       <= `cu_end;
end else if (i_rst_slice) begin
    o_cu_state                                       <= `cu_end;
    rst_tu                                           <= 0;
    reset_mv                                         <= 0;
    o_dec_bin_en_cu                                  <= 0;
    o_byp_dec_en_cu                                  <= 0;
    o_cm_idx_cu                                      <= 255; //invalid idx
end else if (i_rst_ctb) begin
    phase                                            <= ~phase;
    if (i_x0 == 0) begin
        intra_luma_pred_mode_left                    <= '{16{1'b1}};//INTRA_DC
        cu_skip_flag_left                            <= '{8{1'b0}};
        cu_predmode_left_init0                       <= {8{1'b0}};
        cu_predmode_left_init1                       <= {8{1'b1}};
        cu_predmode_leftup_init0                     <= {8{1'b0}};
        cu_predmode_leftup_init1                     <= {8{1'b1}};
        cbf_luma_left                                <= {16{1'b0}};
        left_mvf                                     <= {16{34'd0}};
    end
    if (i_y0 == 0) begin
        cu_skip_flag_up                              <= '{8{1'b0}};
        cbf_luma_up                                  <= {16{1'b0}};
    end else begin
        dram_cu_skip_up_we                           <= 0;
        dram_cu_skip_up_addr                         <= i_x0[`max_x_bits-1:6];
        dram_cbf_luma_up_we                          <= 0;
        dram_cbf_luma_up_addr                        <= i_x0[`max_x_bits-1:6];

    end
    intra_luma_pred_mode_up                          <= '{16{1}};//INTRA_DC
    last_col                                         <= i_last_col;
    last_row                                         <= i_last_row;
    first_col                                        <= i_first_col;
    first_row                                        <= i_first_row;
    last_col_width                                   <= i_last_col_width;
    last_row_height                                  <= i_last_row_height;
end else if (rst) begin

    o_cu_state                                       <= 0;

    o_dec_bin_en_cu                                  <= 0;
    o_byp_dec_en_cu                                  <= 0;
    o_cm_idx_cu                                      <= 255; //invalid idx
    i                                                <= 0;
    x0                                               <= i_x0;
    y0                                               <= i_y0;
    xTu                                              <= i_x0[5:0];
    yTu                                              <= i_y0[5:0];
    xPb                                              <= i_x0[5:0];
    yPb                                              <= i_y0[5:0];
    log2CbSize                                       <= i_log2CbSize;
    CbSize                                           <= i_CbSize;
    trafoDepth                                       <= 0;
    log2TrafoSize                                    <= i_log2CbSize;
    trafoSize                                        <= i_CbSize;

    slice_num                                        <= i_slice_num;
    MaxNumMergeCand                                  <= 5-i_five_minus_max_num_merge_cand;
    max_merge_cand_minus2                            <= 3-i_five_minus_max_num_merge_cand;
    num_ref_idx_l0_active_minus1                     <= i_num_ref_idx-1;
    num_ref_idx_l0_active_minus2                     <= i_num_ref_idx-2;

    rst_tu                                           <= 0;
    store_bs_pu_bound                                <= 0;

     if (i_y0[`max_y_bits-1:6] > 0 &&i_y0[5:0]==0&&i_x0[5:0]==0) begin
        cu_skip_flag_up                              <= dram_cu_skip_up_dout;
        cbf_luma_up                                  <= dram_cbf_luma_up_dout;
     end

end else begin
    if (en) begin
        case (o_cu_state)
            `cu_transquant_bypass_flag_s://0x1
                begin
                    //提到最外面
                    if (skip_left==1 && skip_up == 1)
                        o_cm_idx_cu                      <= `CM_IDX_CU_SKIP_FLAG+2;
                    else if (skip_left == 1 || skip_up == 1)
                        o_cm_idx_cu                      <= `CM_IDX_CU_SKIP_FLAG+1;
                    else
                        o_cm_idx_cu                      <= `CM_IDX_CU_SKIP_FLAG;

                    if (i_dec_bin_valid) begin
                        o_dec_bin_en_cu                  <= 0;
                        cu_transquant_bypass_flag        <= i_bin_cu;
                        if (`log_i && slice_num>=`slice_begin && slice_num<=`slice_end)
                            $fdisplay(fd_log, "parse_cu_transquant_bypass_flag ret %d ivlCurrRange %x ivlOffset %x",
                             i_bin_cu,i_ivlCurrRange, i_ivlOffset);

                        if (i_slice_type != `I_SLICE) begin
                            o_dec_bin_en_cu             <= 1;
                            o_cu_state                  <= `cu_skip_flag_s;
                        end else if (i_log2CbSize == `MinCbLog2SizeY) begin
                            o_dec_bin_en_cu             <= 1;
                            o_cu_state                  <= `cu_skip_flag_s;
                        end else begin
                            o_cu_state                  <= `cu_intra_or_inter;
                        end

                    end
                end

            `cu_skip_flag_s://0x2
                if (i_dec_bin_valid) begin
                    o_dec_bin_en_cu                     <= 0;
                    if (`log_i && slice_num>=`slice_begin && slice_num<=`slice_end)
                        $fdisplay(fd_log, "parse_cu_skip_flag ret %0d ctxInc %0d ivlCurrRange %x ivlOffset %x",
                         i_bin_cu, o_cm_idx_cu-`CM_IDX_CU_SKIP_FLAG,i_ivlCurrRange, i_ivlOffset);

                    cu_skip_flag                        <= i_bin_cu;
                    mvd[0]                              <= 0;
                    mvd[1]                              <= 0;
                    if (i_bin_cu) begin
                        pred_mode                       <= `MODE_INTER; //MODE_SKIP没啥用

                        //parse_prediction_unit, parse_merge_idx
                        partIdx                         <= 0;
                        i                               <= 0;
                        merge_idx                       <= 0;
                        merge_flag                      <= 1;

                        o_dec_bin_en_cu                 <= 1;
                        o_cm_idx_cu                     <= `CM_IDX_MERGE_IDX_EXT;
                        o_cu_state                      <= `merge_idx_s_1; //假定MaxNumMergeCand > 1恒成立
                    end else begin
                        //不必经过`cu_intra_or_inter,因为这里是inter
                        o_dec_bin_en_cu                 <= 1;
                        o_cm_idx_cu                     <= `CM_IDX_PRED_MODE;
                        o_cu_state                      <= `pred_mode_flag_s;
                    end
                end
            `merge_idx_s_1://0x4
                if (i_dec_bin_valid) begin
                    if (`log_i && slice_num>=`slice_begin && slice_num<=`slice_end)
                        $fdisplay(fd_log, "binVal %d ivlCurrRange %x ivlOffset %x",
                         i_bin_cu, i_ivlCurrRange, i_ivlOffset);

                    i                                   <= i+1;
                    if (i_bin_cu&&i!=max_merge_cand_minus2) begin
                        o_dec_bin_en_cu                 <= 0;

                        o_byp_dec_en_cu                 <= 1;
                        o_cu_state                      <= `merge_idx_s_2;
                    end else begin
                        if (`log_i && slice_num>=`slice_begin && slice_num<=`slice_end)
                            $fdisplay(fd_log, "parse_merge_idx ret %0d",i);
                        o_dec_bin_en_cu                 <= 0;
                        merge_idx                       <= i;
                        o_cu_state                      <= `wait_mv_done_1;
                    end
                end else begin
                
                end
            `merge_idx_s_2://0x5
                begin
                    if (`log_i && slice_num>=`slice_begin && slice_num<=`slice_end)
                        $fdisplay(fd_log, "bypass binVal %d ivlCurrRange %x ivlOffset %x",
                         i_bin_byp, i_ivlCurrRange, i_ivlOffset);

                    i                                   <= i+1;
                    if (i_bin_byp == 0 || i==max_merge_cand_minus2) begin
                        o_byp_dec_en_cu                 <= 0;
                        if (i_bin_byp == 0)
                            merge_idx                   <= i;
                        else
                            merge_idx                   <= i+1;
                        if (`log_i && slice_num>=`slice_begin && slice_num<=`slice_end)
                            $fdisplay(fd_log, "parse_merge_idx ret %0d",i_bin_byp==0?i:i+1);
                        o_cu_state                      <= `wait_mv_done_1;
                    end
                end
            `pred_mode_flag_s://0x6
                if (i_dec_bin_valid) begin
                    if (`log_i && slice_num>=`slice_begin && slice_num<=`slice_end)
                        $fdisplay(fd_log, "parse_pred_mode_flag ret %d ivlCurrRange %x ivlOffset %x",
                         i_bin_cu, i_ivlCurrRange, i_ivlOffset);

                    pred_mode                           <= i_bin_cu;
                    if (i_bin_cu) begin
                        if (i_log2CbSize == `MinCbLog2SizeY) begin
                            o_cm_idx_cu                 <= `CM_IDX_PART_MODE;
                            o_cu_state                  <= `parse_part_mode_intra;
                        end else begin
                            partIdx                      <= 0;
                            o_cm_idx_cu                  <= `CM_IDX_PREV_INTRA_LUMA_PRED_FLAG;
                            o_cu_state                   <= `prev_intra_luma_pred_flag_s;//c
                        end

                    end else begin
                        max_bits                        <= 2;
                        i                               <= 0;
                        part_mode                       <= 0;
                        o_cm_idx_cu                     <= `CM_IDX_PART_MODE;
                        //dec_bin_en维持1
                        o_cu_state                      <= `parse_part_mode_inter_1;
                    end

                end
            `parse_part_mode_intra://0x7
                if (i_dec_bin_valid) begin
                    if (i_bin_cu == 1) begin
                        part_mode                       <= `PART_2Nx2N;
                    end else begin
                        part_mode                       <= `PART_NxN;
                    end
                    partIdx                             <= 0;
                    o_cm_idx_cu                         <= `CM_IDX_PREV_INTRA_LUMA_PRED_FLAG;
                    o_cu_state                          <= `prev_intra_luma_pred_flag_s;

                    if (`log_i && slice_num>=`slice_begin && slice_num<=`slice_end) begin
                        $fdisplay(fd_log, "binVal %d ivlCurrRange %x ivlOffset %x",
                         i_bin_cu, i_ivlCurrRange, i_ivlOffset);

                        $fdisplay(fd_log, "parse_part_mode ret %0d", i_bin_cu?`PART_2Nx2N:`PART_NxN);
                    end

                end

            `parse_part_mode_inter_1://0x8
                if (i_dec_bin_valid) begin
                    if (`log_i && slice_num>=`slice_begin && slice_num<=`slice_end)
                        $fdisplay(fd_log, "binVal %d ivlCurrRange %x ivlOffset %x",
                         i_bin_cu, i_ivlCurrRange, i_ivlOffset);

                    i                                   <= i+1;
                    if (i_bin_cu == 0) begin
                        part_mode                       <= part_mode + 1;
                        if (i == 1) begin //00,part_mode=2
                            if (i_amp_enabled_flag && log2CbSize > `MinCbLog2SizeY) begin
                                o_cm_idx_cu             <= `CM_IDX_PART_MODE+3;
                                o_cu_state              <= `parse_part_mode_inter_2;
                            end else begin
                                o_cm_idx_cu             <= `CM_IDX_MERGE_FLAG;
                                o_cu_state              <= `merge_flag_s;
                                if (`log_i && slice_num>=`slice_begin && slice_num<=`slice_end)
                                    $fdisplay(fd_log, "parse_part_mode ret %0d", part_mode+1);

                            end
                        end else begin
                            o_cm_idx_cu                 <= `CM_IDX_PART_MODE+i+1;
                        end

                    end else begin
                        if (i==0) begin //1,part_mode=0
                            o_cm_idx_cu                 <= `CM_IDX_MERGE_FLAG;
                            if (`log_i && slice_num>=`slice_begin && slice_num<=`slice_end)
                                $fdisplay(fd_log, "parse_part_mode ret %0d", part_mode);

                            o_cu_state                  <= `merge_flag_s;
                        end else if (i_amp_enabled_flag && log2CbSize > `MinCbLog2SizeY) begin //01,part_mode=1
                            o_cm_idx_cu                 <= `CM_IDX_PART_MODE+3;
                            o_cu_state                  <= `parse_part_mode_inter_2;
                        end else begin
                            o_cm_idx_cu                 <= `CM_IDX_MERGE_FLAG;
                            if (`log_i && slice_num>=`slice_begin && slice_num<=`slice_end)
                                $fdisplay(fd_log, "parse_part_mode ret %0d", part_mode);

                            o_cu_state                  <= `merge_flag_s;
                        end
                    end
                end
            `parse_part_mode_inter_2://0x9
                if (i_dec_bin_valid) begin

                    if (`log_i && slice_num>=`slice_begin && slice_num<=`slice_end)
                        $fdisplay(fd_log, "binVal %d ivlCurrRange %x ivlOffset %x",
                         i_bin_cu, i_ivlCurrRange, i_ivlOffset);

                    if (part_mode == 1) begin
                        if (i_bin_cu) begin
                            part_mode                   <= `PART_2NxN; //011
                            o_cm_idx_cu                 <= `CM_IDX_MERGE_FLAG;
                            if (`log_i && slice_num>=`slice_begin && slice_num<=`slice_end)
                                $fdisplay(fd_log, "parse_part_mode ret %0d", `PART_2NxN);

                            o_cu_state                  <= `merge_flag_s;//0x1b
                        end else begin
                            o_dec_bin_en_cu             <= 0;
                            o_byp_dec_en_cu             <= 1;
                            o_cu_state                  <= `parse_part_mode_inter_3; //0100或0101
                        end
                    end else if (part_mode == 2) begin
                        if (i_bin_cu) begin
                            part_mode                   <= `PART_Nx2N; //001
                            o_cm_idx_cu                 <= `CM_IDX_MERGE_FLAG;
                            if (`log_i && slice_num>=`slice_begin && slice_num<=`slice_end)
                                $fdisplay(fd_log, "parse_part_mode ret %0d", `PART_Nx2N);

                            o_cu_state                  <= `merge_flag_s;//0x1b
                        end else begin
                            o_dec_bin_en_cu             <= 0;
                            o_byp_dec_en_cu             <= 1;
                            o_cu_state                  <= `parse_part_mode_inter_4; //0000或0001
                        end
                    end
                end
            `parse_part_mode_inter_3://0xa,0100或0101
                begin

                    if (`log_i && slice_num>=`slice_begin && slice_num<=`slice_end)
                        $fdisplay(fd_log, "bypass binVal %d ivlCurrRange %x ivlOffset %x",
                         i_bin_byp, i_ivlCurrRange, i_ivlOffset);

                    if (i_bin_byp == 0) begin
                        part_mode                       <= `PART_2NxnU;
                    end else begin
                        part_mode                       <= `PART_2NxnD;
                    end
                    o_byp_dec_en_cu                     <= 0;
                    o_dec_bin_en_cu                     <= 1;
                    o_cm_idx_cu                         <= `CM_IDX_MERGE_FLAG;
                    if (`log_i && slice_num>=`slice_begin && slice_num<=`slice_end)
                        $fdisplay(fd_log, "parse_part_mode ret %0d", i_bin_byp == 0?`PART_2NxnU:`PART_2NxnD);

                    o_cu_state                          <= `merge_flag_s;//0x1b
                end

            `parse_part_mode_inter_4://0xb,0000或0001
                begin

                    if (`log_i && slice_num>=`slice_begin && slice_num<=`slice_end)
                        $fdisplay(fd_log, "bypass binVal %d ivlCurrRange %x ivlOffset %x",
                         i_bin_byp, i_ivlCurrRange, i_ivlOffset);

                    if (i_bin_byp == 0) begin
                        part_mode                       <= `PART_nLx2N;
                    end else begin
                        part_mode                       <= `PART_nRx2N;
                    end
                    o_byp_dec_en_cu                     <= 0;
                    o_dec_bin_en_cu                     <= 1;
                    o_cm_idx_cu                         <= `CM_IDX_MERGE_FLAG;
                    if (`log_i && slice_num>=`slice_begin && slice_num<=`slice_end)
                        $fdisplay(fd_log, "parse_part_mode ret %0d", i_bin_byp == 0?`PART_nLx2N:`PART_nRx2N);

                    o_cu_state                          <= `merge_flag_s;//0x1b
                end

             `prev_intra_luma_pred_flag_s://c
                 if (i_dec_bin_valid) begin
                    if (`log_i && slice_num>=`slice_begin && slice_num<=`slice_end)
                        $fdisplay(fd_log, "parse_prev_intra_luma_pred_flag ret %d ivlCurrRange %x ivlOffset %x",
                         i_bin_cu, i_ivlCurrRange, i_ivlOffset);

                     prev_intra_luma_pred_flag[partIdx]     <= i_bin_cu;
                     partIdx                                <= partIdx+1;

                     if (partIdx == part_num-1) begin
                         o_dec_bin_en_cu                    <= 0;
                         partIdx                            <= 0;
                         if ((part_num == 1 && i_bin_cu) ||
                             (part_num == 4 && prev_intra_luma_pred_flag[0] == 1)) begin
                             o_cu_state                         <= `parse_mpm_idx;//d
                             i                                  <= 0;
                             o_byp_dec_en_cu                    <= 1;
                         end else begin
                             o_cu_state                         <= `parse_rem_intra_luma_pred_mode;//0x11
                             rem_intra_luma_pred_mode[0]        <= 0;
                             i                                  <= 0;
                             o_byp_dec_en_cu                    <= 1;
                         end
                     end
                     {candModeList[2],candModeList[1],candModeList[0]} <=
                         f_get_cand_mode_list(candIntraPredModeA,candIntraPredModeB);
                     if (`log_v && slice_num>=`slice_begin && slice_num<=`slice_end)
                        $fdisplay(fd_log, "%t candIntraPredModeA %d candIntraPredModeB %d",
                         $time,candIntraPredModeA,candIntraPredModeB);

                 end else begin
                     candIntraPredModeB                        <= intra_luma_up;
                     candIntraPredModeA                        <= intra_luma_left;
                 end

             //part_num=1,在`prev_intra_luma_pred_flag_s解完了get_cand_mode_list_1和get_cand_mode_list_2,
             //parse_mpm_idx不需要干啥，在`parse_intra_chroma_pred_mode_1的时候存起来
             //part_num=4,第一个part，在`prev_intra_luma_pred_flag_s解完了get_cand_mode_list_1和get_cand_mode_list_2,4个part重复解4遍
             //第二个part，在parse_mpm_idx i=1时get_cand_mode_list_1，i=2时get_cand_mode_list_2，也就是
             //mpm idx只有1bit，也花2周期，第二周期就做get_cand_mode_list_2
             //需要一个单独的状态`store_intra_luma_pred_mode来存，因为下一个part要立刻用到上一个part的结果

             `parse_mpm_idx://d
                 if (i == 0) begin
                     if (`log_i && slice_num>=`slice_begin && slice_num<=`slice_end)
                         $fdisplay(fd_log, "bypass binVal %d ivlCurrRange %x ivlOffset %x",
                         i_bin_byp, i_ivlCurrRange, i_ivlOffset);

                     if (i_bin_byp == 0) begin
                         mpm_idx                            <= 0;

                         o_byp_dec_en_cu                    <= 0;
                         if (part_num == 1) begin
                             o_cu_state                     <= `parse_intra_chroma_pred_mode_1;
                             o_cm_idx_cu                    <= `CM_IDX_INTRA_CHROMA_PRED_MODE;
                             o_dec_bin_en_cu                <= 1;
                             IntraPredModeY                 <= candModeList[0];
                             cu_intra_luma_pred_mode[0]     <= candModeList[0];
                         end else if (partIdx == 0) begin //part_num=4,partIdx=0,不必额外1周期算candModeList,在`prev_intra_luma_pred_mode_s算好了
                             IntraPredModeY                 <= candModeList[0];
                             o_cu_state                     <= `store_intra_luma_pred_mode;
                         end
                         //else mpm idx bypass解1bit或2bit，1bit还需1周期算candModeList
                         if (`log_i && slice_num>=`slice_begin && slice_num<=`slice_end) begin
                             $fdisplay(fd_log, "parse_mpm_idx return 0");
                         end

                     end

                     if (partIdx != 0) begin
                         candIntraPredModeB                    <= intra_luma_up;
                         candIntraPredModeA                    <= intra_luma_left;
                     end

                     i                                      <= 1;

                 end else if (i == 1) begin
                    if (`log_i && slice_num>=`slice_begin && slice_num<=`slice_end) begin
                        if (o_byp_dec_en_cu)
                            $fdisplay(fd_log, "bypass binVal %d ivlCurrRange %x ivlOffset %x",
                             i_bin_byp, i_ivlCurrRange, i_ivlOffset);
                     end

                     if (partIdx != 0)
                         {candModeList[2],candModeList[1],candModeList[0]} <= f_get_cand_mode_list(candIntraPredModeA,candIntraPredModeB);
                     if (o_byp_dec_en_cu) begin
                         if (i_bin_byp == 0) begin
                             mpm_idx                        <= 1;
                         end else begin
                             mpm_idx                        <= 2;
                         end
                         if (`log_i && slice_num>=`slice_begin && slice_num<=`slice_end) begin
                             $fdisplay(fd_log, "parse_mpm_idx return %0d",i_bin_byp == 0?1:2);
                         end

                         o_byp_dec_en_cu                    <= 0;
                         if (part_num == 1) begin
                             cu_intra_luma_pred_mode[0]     <= i_bin_byp == 0?candModeList[1]:candModeList[2];
                             IntraPredModeY                 <= i_bin_byp == 0?candModeList[1]:candModeList[2];
                             o_cu_state                     <= `parse_intra_chroma_pred_mode_1;
                             o_cm_idx_cu                    <= `CM_IDX_INTRA_CHROMA_PRED_MODE;
                             o_dec_bin_en_cu                <= 1;
                         end else begin
                             o_cu_state                     <= `store_intra_luma_pred_mode;
                         end
                     end else begin
                         //只有part_num=4才会走这
                         o_cu_state                         <= `store_intra_luma_pred_mode;
                     end
                end

            `parse_rem_intra_luma_pred_mode://0x11
                begin
                    if (`log_i && slice_num>=`slice_begin && slice_num<=`slice_end) begin
                        if (i != 5)
                            $fdisplay(fd_log, "bypass binVal %d ivlCurrRange %x ivlOffset %x",
                             i_bin_byp, i_ivlCurrRange, i_ivlOffset);
                    end

                    i                                       <= i+1;
                    rem_intra_luma_pred_mode[partIdx]       <= {rem_intra_luma_pred_mode[partIdx][4:0],i_bin_byp};
                    cur_rem_intra_luma_pred_mode            <= {rem_intra_luma_pred_mode[partIdx][4:0],i_bin_byp};
                    if (i == 0) begin
                        candIntraPredModeB                  <= intra_luma_up;
                        candIntraPredModeA                  <= intra_luma_left;

                    end else if (i == 1) begin
                        {candModeList[2],candModeList[1],candModeList[0]} <= 
                            f_get_cand_mode_list(candIntraPredModeA,candIntraPredModeB);
                        if (`log_v && slice_num>=`slice_begin && slice_num<=`slice_end)
                            $fdisplay(fd_log, "%t  candIntraPredModeA %d candIntraPredModeB %d",
                             $time,candIntraPredModeA,candIntraPredModeB);

                    end else if (i == 2) begin
                        if (candModeList[0] > candModeList[1]) begin
                            candModeList[0]                 <= candModeList[1];
                            candModeList[1]                 <= candModeList[0];
                        end

                    end else if (i == 3) begin
                        if (candModeList[0] > candModeList[2]) begin
                            candModeList[0]                 <= candModeList[2];
                            candModeList[2]                 <= candModeList[0];
                        end

                    end else if (i == 4) begin
                        if (candModeList[1] > candModeList[2]) begin
                            candModeList[1]                 <= candModeList[2];
                            candModeList[2]                 <= candModeList[1];
                        end
                        o_byp_dec_en_cu                     <= 0;

                    end else if (i == 5) begin
                        if (`log_v && slice_num>=`slice_begin && slice_num<=`slice_end)
                            $fdisplay(fd_log, "%t candModeList %d %d %d",
                             $time,candModeList[0],candModeList[1],candModeList[2]);

                        //for (j = 0; j < 3; j++)
                        //    IntraPredModeY += (IntraPredModeY >= candModeList[j]);
                        if (cur_rem_intra_luma_pred_mode >= candModeList[0]) begin
                            if (cur_rem_intra_luma_pred_mode+1 >= candModeList[1]) begin
                                if (cur_rem_intra_luma_pred_mode+2 >= candModeList[2]) begin
                                    IntraPredModeY                 <= cur_rem_intra_luma_pred_mode+3;
                                    if (part_num == 1)
                                        cu_intra_luma_pred_mode[0] <= cur_rem_intra_luma_pred_mode+3;
                                end else begin
                                    IntraPredModeY                 <= cur_rem_intra_luma_pred_mode+2;
                                    if (part_num == 1)
                                        cu_intra_luma_pred_mode[0] <= cur_rem_intra_luma_pred_mode+2;
                                end
                            end else begin
                                if (cur_rem_intra_luma_pred_mode+1 >= candModeList[2]) begin
                                    IntraPredModeY                 <= cur_rem_intra_luma_pred_mode+2;
                                    if (part_num == 1)
                                        cu_intra_luma_pred_mode[0] <= cur_rem_intra_luma_pred_mode+2;

                                end else begin
                                    IntraPredModeY                 <= cur_rem_intra_luma_pred_mode+1;
                                    if (part_num == 1)
                                        cu_intra_luma_pred_mode[0] <= cur_rem_intra_luma_pred_mode+1;
                                end
                            end
                        end else begin
                            if (cur_rem_intra_luma_pred_mode >= candModeList[1]) begin
                                if (cur_rem_intra_luma_pred_mode+1 >= candModeList[2]) begin
                                    IntraPredModeY                 <= cur_rem_intra_luma_pred_mode+2;
                                    if (part_num == 1)
                                        cu_intra_luma_pred_mode[0] <= cur_rem_intra_luma_pred_mode+2;
                                end else begin
                                    IntraPredModeY                 <= cur_rem_intra_luma_pred_mode+1;
                                    if (part_num == 1)
                                        cu_intra_luma_pred_mode[0] <= cur_rem_intra_luma_pred_mode+1;
                                end
                            end else begin
                                if (cur_rem_intra_luma_pred_mode >= candModeList[2]) begin
                                    IntraPredModeY                 <= cur_rem_intra_luma_pred_mode+1;
                                    if (part_num == 1)
                                        cu_intra_luma_pred_mode[0] <= cur_rem_intra_luma_pred_mode+1;
                                end else begin
                                    IntraPredModeY                 <= cur_rem_intra_luma_pred_mode;
                                    if (part_num == 1)
                                        cu_intra_luma_pred_mode[0] <= cur_rem_intra_luma_pred_mode;
                                end
                            end
                        end

                        if (part_num == 4)
                            o_cu_state                       <= `store_intra_luma_pred_mode;
                        else begin//part_num==1
                            o_cu_state                       <= `parse_intra_chroma_pred_mode_1;
                            o_cm_idx_cu                      <= `CM_IDX_INTRA_CHROMA_PRED_MODE;
                            o_dec_bin_en_cu                  <= 1;
                        end
                    end

                end
            `split_transform_flag_s://0x15
                if (i_dec_bin_valid) begin
                    o_dec_bin_en_cu                         <= 0;
                    if (i_bin_cu)
                        split_tu                            <= 1;
                    else
                        split_tu                            <= 0;
                    if (`log_i && slice_num>=`slice_begin && slice_num<=`slice_end)
                        $fdisplay(fd_log, "parse_split_transform_flag ret %0d ctxInc %0d ivlCurrRange %x ivlOffset %x",
                         i_bin_cu, o_cm_idx_cu-`CM_IDX_TRANS_SUBDIV_FLAG,i_ivlCurrRange, i_ivlOffset);

                    o_cu_state                              <= `parse_cb_cr_or_not;

                end
            `parse_intra_chroma_pred_mode_1://0x12
                if (i_dec_bin_valid) begin
                    o_dec_bin_en_cu                         <= 0;

                    if (`log_i && slice_num>=`slice_begin && slice_num<=`slice_end) begin
                        if (part_num == 1)
                            $fdisplay(fd_log, "IntraPredModeY %0d", IntraPredModeY);
                        $fdisplay(fd_log, "binVal %d ivlCurrRange %x ivlOffset %x",
                         i_bin_cu, i_ivlCurrRange, i_ivlOffset);
                     end

                    if (i_bin_cu == 0) begin //symbol = 4
                        IntraPredModeC                      <= cu_intra_luma_pred_mode[0];
                        if (`log_i && slice_num>=`slice_begin && slice_num<=`slice_end)
                            $fdisplay(fd_log, "parse_intra_chroma_pred_mode symbol 4 value %0d",
                             cu_intra_luma_pred_mode[0]);

                        if (log2CbSize <= `Log2MaxTrafoSize && log2CbSize > `Log2MinTrafoSize &&
                                 ~IntraSplitFlag) begin
                            o_cm_idx_cu                     <= `CM_IDX_TRANS_SUBDIV_FLAG-log2CbSize+5;

                            o_dec_bin_en_cu                 <= 1;
                            o_cu_state                      <= `split_transform_flag_s;

                        end else begin
                            if (log2CbSize > `Log2MaxTrafoSize || IntraSplitFlag) begin
                                //log2TrafoSize,trafoSize,trafoDepth在parse完cb,cr后才能更新
                                split_tu                    <= 1;
                                o_cu_state                  <= `parse_cb_cr_or_not;
                            end else begin
                                o_cu_state                  <= `cu_pass2tu;
                                rst_tu                      <= 1;
                            end
                        end
                    end else begin
                        i                                   <= 0;
                        symbol                              <= 0;
                        o_byp_dec_en_cu                     <= 1;
                        o_cu_state                          <= `parse_intra_chroma_pred_mode_2;
                    end

                    //if (part_num == 1) begin //不需要，并且part_num fanout很大，
                        if (CbSize[6] == 1) begin
                            intra_luma_pred_mode_left            <= '{16{IntraPredModeY}};
                            intra_luma_pred_mode_up              <= '{16{IntraPredModeY}};
                        end else if (CbSize[5] == 1) begin
                            intra_luma_pred_mode_left[{y0[5],3'b000}]  <= IntraPredModeY;
                            intra_luma_pred_mode_left[{y0[5],3'b001}]  <= IntraPredModeY;
                            intra_luma_pred_mode_left[{y0[5],3'b010}]  <= IntraPredModeY;
                            intra_luma_pred_mode_left[{y0[5],3'b011}]  <= IntraPredModeY;
                            intra_luma_pred_mode_left[{y0[5],3'b100}]  <= IntraPredModeY;
                            intra_luma_pred_mode_left[{y0[5],3'b101}]  <= IntraPredModeY;
                            intra_luma_pred_mode_left[{y0[5],3'b110}]  <= IntraPredModeY;
                            intra_luma_pred_mode_left[{y0[5],3'b111}]  <= IntraPredModeY;

                            intra_luma_pred_mode_up[{x0[5],3'b000}]  <= IntraPredModeY;
                            intra_luma_pred_mode_up[{x0[5],3'b001}]  <= IntraPredModeY;
                            intra_luma_pred_mode_up[{x0[5],3'b010}]  <= IntraPredModeY;
                            intra_luma_pred_mode_up[{x0[5],3'b011}]  <= IntraPredModeY;
                            intra_luma_pred_mode_up[{x0[5],3'b100}]  <= IntraPredModeY;
                            intra_luma_pred_mode_up[{x0[5],3'b101}]  <= IntraPredModeY;
                            intra_luma_pred_mode_up[{x0[5],3'b110}]  <= IntraPredModeY;
                            intra_luma_pred_mode_up[{x0[5],3'b111}]  <= IntraPredModeY;
                        end else if (CbSize[4] == 1) begin
                            intra_luma_pred_mode_left[{y0[5:4],2'b00}]  <= IntraPredModeY;
                            intra_luma_pred_mode_left[{y0[5:4],2'b01}]  <= IntraPredModeY;
                            intra_luma_pred_mode_left[{y0[5:4],2'b10}]  <= IntraPredModeY;
                            intra_luma_pred_mode_left[{y0[5:4],2'b11}]  <= IntraPredModeY;

                            intra_luma_pred_mode_up[{x0[5:4],2'b00}]  <= IntraPredModeY;
                            intra_luma_pred_mode_up[{x0[5:4],2'b01}]  <= IntraPredModeY;
                            intra_luma_pred_mode_up[{x0[5:4],2'b10}]  <= IntraPredModeY;
                            intra_luma_pred_mode_up[{x0[5:4],2'b11}]  <= IntraPredModeY;

                        end else if (CbSize[3] == 1) begin
                            if (part_mode == `PART_2Nx2N) begin //PART_NxN在`store_intra_luma_pred_mode存了
                                intra_luma_pred_mode_left[{y0[5:3],1'b0}]  <= IntraPredModeY;
                                intra_luma_pred_mode_left[{y0[5:3],1'b1}]  <= IntraPredModeY;
                                intra_luma_pred_mode_up[{x0[5:3],1'b0}]    <= IntraPredModeY;
                                intra_luma_pred_mode_up[{x0[5:3],1'b1}]    <= IntraPredModeY;
                            end
                        end
                   //end
                end
            `parse_intra_chroma_pred_mode_2: begin//0x13
                if (`log_i && slice_num>=`slice_begin && slice_num<=`slice_end)
                    $fdisplay(fd_log, "bypass binVal %d ivlCurrRange %x ivlOffset %x",
                     i_bin_byp, i_ivlCurrRange, i_ivlOffset);

                if (i == 0) begin
                    symbol                              <= i_bin_byp;
                    i                                   <= 1;
                end else begin //i==1
                    symbol                              <= {symbol[0], i_bin_byp};
                    o_byp_dec_en_cu                     <= 0;

                    if (cu_intra_luma_pred_mode[0] == mode_list[{symbol[0], i_bin_byp}])
                        IntraPredModeC                  <= 34;
                    else
                        IntraPredModeC                  <= mode_list[{symbol[0], i_bin_byp}];
                    if (`log_i && slice_num>=`slice_begin && slice_num<=`slice_end)
                        $fdisplay(fd_log, "parse_intra_chroma_pred_mode symbol %0d value %0d",
                         {symbol[0], i_bin_byp},
                         cu_intra_luma_pred_mode[0] == mode_list[{symbol[0], i_bin_byp}]?
                          34:mode_list[{symbol[0], i_bin_byp}]);

                    if (log2CbSize <= `Log2MaxTrafoSize && log2CbSize > `Log2MinTrafoSize &&
                             !IntraSplitFlag) begin
                        o_cm_idx_cu                     <= `CM_IDX_TRANS_SUBDIV_FLAG-log2CbSize+5;
                        o_dec_bin_en_cu                 <= 1;
                        o_cu_state                      <= `split_transform_flag_s;

                    end else begin
                        if (log2CbSize > `Log2MaxTrafoSize || IntraSplitFlag) begin
                            split_tu                    <= 1;
                            o_cu_state                  <= `parse_cb_cr_or_not;
                        end else begin
                            o_cu_state                  <= `cu_pass2tu;
                            rst_tu                      <= 1;
                        end
                    end

                end
            end

            `cbf_cb_s://0x17
                if (i_dec_bin_valid) begin
                    o_dec_bin_en_cu                         <= 0;
                    cbf_cb                                  <= i_bin_cu;
                    base_cbf_cb[trafoDepth]                 <= i_bin_cu;
                    if (`log_i && slice_num>=`slice_begin && slice_num<=`slice_end)
                        $fdisplay(fd_log, "parse_cbf_cb_cr ret %d ivlCurrRange %x ivlOffset %x",
                         i_bin_cu, i_ivlCurrRange, i_ivlOffset);

                    if (log2TrafoSize > 2 && (trafoDepth == 0 || base_cbf_cr[trafoDepth-1])) begin
                        o_dec_bin_en_cu                     <= 1;
                        o_cm_idx_cu                         <= `CM_IDX_QT_CBF_CB_CR+trafoDepth;
                        o_cu_state                          <= `cbf_cr_s;
                    end else begin
                        cbf_cr                              <= base_cbf_cr[trafoDepth-1];
                        base_cbf_cr[trafoDepth]             <= base_cbf_cr[trafoDepth-1];
                        if (split_tu) begin //split_tu=1,继续判断下一层是否需要split
                            trafoDepth                      <= trafoDepth+1;
                            dep_partIdx_tu[trafoDepth+1]    <= 0;
                            blkIdx                          <= 0;
                            log2TrafoSize                   <= log2TrafoSize-1;
                            trafoSize                       <= trafoSize >> 1;
                            o_cu_state                      <= `split_tu_or_not;
                        end else begin
                            o_cu_state                      <= `cu_pass2tu;

                            rst_tu                          <= 1;
                        end
                    end
                end
            `cbf_cr_s://0x18
                if (i_dec_bin_valid) begin
                    o_dec_bin_en_cu                         <= 0;
                    cbf_cr                                  <= i_bin_cu;
                    base_cbf_cr[trafoDepth]                 <= i_bin_cu;
                    if (`log_i && slice_num>=`slice_begin && slice_num<=`slice_end)
                        $fdisplay(fd_log, "parse_cbf_cb_cr ret %d ivlCurrRange %x ivlOffset %x",
                         i_bin_cu, i_ivlCurrRange, i_ivlOffset);

                    if (split_tu) begin
                        trafoDepth                          <= trafoDepth+1;
                        dep_partIdx_tu[trafoDepth+1]        <= 0;
                        blkIdx                              <= 0;
                        log2TrafoSize                       <= log2TrafoSize-1;
                        trafoSize                           <= trafoSize >> 1;
                        o_cu_state                          <= `split_tu_or_not;
                    end else begin
                        o_cu_state                          <= `cu_pass2tu;

                        rst_tu                              <= 1;
                    end
                end

        `merge_flag_s: begin//0x1b
            store_bs_pu_bound                    <= 0;
            if (i_dec_bin_valid) begin
                merge_flag                       <= i_bin_cu;

                if (`log_i && slice_num>=`slice_begin && slice_num<=`slice_end)
                    $fdisplay(fd_log, "parse_merge_flag ret %0d ivlCurrRange %x ivlOffset %x",
                     i_bin_cu, i_ivlCurrRange, i_ivlOffset);
                i                                <= 0;
                mvd[0]                           <= 0;
                mvd[1]                           <= 0;
                if (i_bin_cu) begin
                    o_cm_idx_cu                  <= `CM_IDX_MERGE_IDX_EXT;

                    o_cu_state                   <= `merge_idx_s_1;//0x4
                end else begin
                    if (num_ref_idx_l0_active_minus1>0) begin
                        o_cm_idx_cu              <= `CM_IDX_REF_PIC;
                        o_cu_state               <= `ref_idx_s_1;
                    end else begin
                        if (`log_i && slice_num>=`slice_begin && slice_num<=`slice_end)
                            $fdisplay(fd_log, "parse_ref_idx_l0 ret 0");

                        ref_idx_l0               <= 0;
                        o_cm_idx_cu              <= `CM_IDX_MVD;
                        o_cu_state               <= `abs_mvd_greater0;
                    end
                end
            end

        end

        `ref_idx_s_1://0x1c
            if (i_dec_bin_valid) begin
                if (`log_i && slice_num>=`slice_begin && slice_num<=`slice_end)
                    $fdisplay(fd_log, "binVal %0d ivlCurrRange %x ivlOffset %x",
                     i_bin_cu, i_ivlCurrRange, i_ivlOffset);

                i                                <= i+1;
                if (i_bin_cu) begin
                    if (i==num_ref_idx_l0_active_minus2) begin
                        if (`log_i && slice_num>=`slice_begin && slice_num<=`slice_end)
                            $fdisplay(fd_log, "parse_ref_idx_l0 ret %0d",i+1);
                        o_cm_idx_cu              <= `CM_IDX_MVD;
                        o_cu_state               <= `abs_mvd_greater0;
                        ref_idx_l0               <= i+1;
                        i                        <= 0;
                    end else if (i<1) begin
                        o_cm_idx_cu              <= `CM_IDX_REF_PIC+1;
                    end else begin
                        o_byp_dec_en_cu          <= 1;
                        o_dec_bin_en_cu          <= 0;
                        o_cu_state               <= `ref_idx_s_2;
                    end
                end else begin
                    if (`log_i && slice_num>=`slice_begin && slice_num<=`slice_end)
                        $fdisplay(fd_log, "parse_ref_idx_l0 ret %0d",i);
                    ref_idx_l0                   <= i;
                    i                            <= 0;
                    o_cm_idx_cu                  <= `CM_IDX_MVD;
                    o_cu_state                   <= `abs_mvd_greater0;
                end

            end

        `ref_idx_s_2://0x1d
            begin
                if (`log_i && slice_num>=`slice_begin && slice_num<=`slice_end)
                    $fdisplay(fd_log, "bypass binVal %d ivlCurrRange %x ivlOffset %x",
                     i_bin_byp, i_ivlCurrRange, i_ivlOffset);
                i                                <= i+1;
                if (i_bin_byp==0||i==num_ref_idx_l0_active_minus2) begin
                    if (`log_i && slice_num>=`slice_begin && slice_num<=`slice_end)
                        $fdisplay(fd_log, "parse_ref_idx_l0 ret %0d",i_bin_byp==0?i:i+1);

                    o_byp_dec_en_cu              <= 0;
                    o_dec_bin_en_cu              <= 1;
                    o_cm_idx_cu                  <= `CM_IDX_MVD;
                    o_cu_state                   <= `abs_mvd_greater0;
                    ref_idx_l0                   <= i_bin_byp==0?i:i+1;
                    i                            <= 0;
                end
            end

        `abs_mvd_greater0://0x1e
            if (i_dec_bin_valid) begin
                if (`log_i && slice_num>=`slice_begin && slice_num<=`slice_end)
                    $fdisplay(fd_log, "abs_mvd_greater0_flag %0d ivlCurrRange %x ivlOffset %x",
                     i_bin_cu, i_ivlCurrRange, i_ivlOffset);
                i                                    <= i+1;
                abs_mvd_greater0_flag[i]             <= i_bin_cu;

                if (i == 1) begin
                    if (abs_mvd_greater0_flag[0]||i_bin_cu) begin
                        if (abs_mvd_greater0_flag[0]) begin
                            i                        <= 0;
                        end else begin
                            abs_mvd_greater1_flag[0] <= 0;
                            i                        <= 1;
                        end
                        o_cm_idx_cu                  <= `CM_IDX_MVD+1;
                        o_cu_state                   <= `abs_mvd_greater1;
                    end else begin
                        o_cm_idx_cu                  <= `CM_IDX_MVP_IDX;
                        o_cu_state                   <= `mvp_l0_flag_s;
                    end
                end
            end

        `abs_mvd_greater1://0x1f
            if (i_dec_bin_valid) begin
                if (`log_i && slice_num>=`slice_begin && slice_num<=`slice_end)
                    $fdisplay(fd_log, "abs_mvd_greater1_flag %0d ivlCurrRange %x ivlOffset %x",
                     i_bin_cu, i_ivlCurrRange, i_ivlOffset);

                i                                     <= i+1;
                abs_mvd_greater1_flag[i]              <= i_bin_cu;
                if (i==0 && abs_mvd_greater0_flag[1]) begin

                end else begin
                    o_dec_bin_en_cu                  <= 0;
                    i                                <= 0;
                    o_cu_state                       <= `mvd_phase3;
                end
            end

        `mvd_phase3://0x20
            begin
                if (abs_mvd_greater0_flag[i]) begin
                    if (abs_mvd_greater1_flag[i]) begin
                        o_byp_dec_en_cu           <= 1;
                        one_shift_k               <= 2;
                        abs_mvd                   <= 2; //abs_mvd_minus2 <= 0;
                        k                         <= 1;
                        o_cu_state                <= `abs_mvd_minus2_1;
                    end else begin
                        o_byp_dec_en_cu           <= 1;
                        abs_mvd                   <= 1;
                        o_cu_state                <= `mvd_sign_flag_s;
                    end
                end else begin
                    mvd[i]                        <= 0;
                    i                             <= i+1;
                    if (i==1) begin
                        o_byp_dec_en_cu           <= 0;
                        o_dec_bin_en_cu           <= 1;
                        o_cm_idx_cu               <= `CM_IDX_MVP_IDX;
                        o_cu_state                <= `mvp_l0_flag_s;
                    end
                end
            end

        `abs_mvd_minus2_1://0x21
            begin
                if (`log_i && slice_num>=`slice_begin && slice_num<=`slice_end)
                    $fdisplay(fd_log, "phase1 bypass binVal %d ivlCurrRange %x ivlOffset %x",
                     i_bin_byp, i_ivlCurrRange, i_ivlOffset);

                if (i_bin_byp) begin
                    abs_mvd                       <= abs_mvd+one_shift_k;
                    one_shift_k                   <= {one_shift_k[12:0],1'b0};
                    k                             <= k+1;
                end else begin
                    one_shift_k                   <= {1'b0,one_shift_k[13:1]};
                    o_cu_state                    <= `abs_mvd_minus2_2;
                end
            end

        `abs_mvd_minus2_2://0x22
            begin
                if (`log_i && slice_num>=`slice_begin && slice_num<=`slice_end)
                    $fdisplay(fd_log, "phase2 bypass binVal %d ivlCurrRange %x ivlOffset %x",
                     i_bin_byp, i_ivlCurrRange, i_ivlOffset);

                k                                 <= k-1;
                one_shift_k                       <= {1'b0,one_shift_k[13:1]};
                if (i_bin_byp) begin
                    abs_mvd                       <= abs_mvd+one_shift_k;
                end
                if (k == 1) begin
                    o_cu_state                    <= `mvd_sign_flag_s;
                end
            end

        `mvd_sign_flag_s://0x23
            begin
                if (`log_i && slice_num>=`slice_begin && slice_num<=`slice_end&&abs_mvd_greater1_flag[i])
                    $fdisplay(fd_log, "parse_abs_mvd_minus2 ret %0d",abs_mvd-2);
                if (`log_i && slice_num>=`slice_begin && slice_num<=`slice_end)
                    $fdisplay(fd_log, "mvd_sign_flag[%0d] %d ivlCurrRange %x ivlOffset %x",
                     i,i_bin_byp,i_ivlCurrRange, i_ivlOffset);

                if (i_bin_byp) begin
                    mvd[i]                        <= ~abs_mvd+1;
                end else begin
                    mvd[i]                        <= abs_mvd;
                end
                o_byp_dec_en_cu                   <= 0;
                i                                 <= i+1;
                if (i==1) begin
                    o_dec_bin_en_cu               <= 1;
                    o_cm_idx_cu                   <= `CM_IDX_MVP_IDX;
                    o_cu_state                    <= `mvp_l0_flag_s;
                end else begin
                    //i=0,继续mvd[1]
                    o_cu_state                    <= `mvd_phase3;
                end
            end

        `mvp_l0_flag_s://0x24
            if (i_dec_bin_valid) begin
                if (`log_i && slice_num>=`slice_begin && slice_num<=`slice_end)
                    $fdisplay(fd_log, "mvx %0d mvy %0d",$signed(mvd[0]),$signed(mvd[1]));
                if (`log_i && slice_num>=`slice_begin && slice_num<=`slice_end)
                    $fdisplay(fd_log, "parse_mvp_l0_flag ret %0d ivlCurrRange %x ivlOffset %x",
                     i_bin_cu,i_ivlCurrRange, i_ivlOffset);

                mvp_l0_flag                       <= i_bin_cu;
                o_dec_bin_en_cu                   <= 0;
                o_cu_state                        <= `wait_mv_done_1;
            end
        `rqt_root_cbf_s: begin//0x28
            store_bs_pu_bound                     <= 0;
            if (i_dec_bin_valid) begin
                if (`log_i && slice_num>=`slice_begin && slice_num<=`slice_end)
                    $fdisplay(fd_log, "parse_rqt_root_cbf ret %0d ivlCurrRange %x ivlOffset %x",
                     i_bin_cu,i_ivlCurrRange, i_ivlOffset);

                rqt_root_cbf                      <= i_bin_cu;
                o_dec_bin_en_cu                   <= 0;
                 //rqt_root_cbf=0,也进入tu,再进入tq，在tq里清残差dram，
                if (i_bin_cu) begin
                    o_cu_state                    <= `split_tu_or_not;
                end else begin
                    o_cu_state                    <= `cu_pass2tu;
                    rst_tu                        <= 1;
                end
            end
        end

        endcase




    end

    case (o_cu_state)
        `rst_cu://这个状态持续了3周期，因为在等en，en在bitstream_controller延迟了
            begin
                if (`log_i && slice_num>=`slice_begin && slice_num<=`slice_end)
                    $fdisplay(fd_log, "##parse_coding_unit x0 %0d y0 %0d log2CbSize %0d slice_num %0d",
                     i_x0,i_y0,i_log2CbSize,i_slice_num);

                cu_transquant_bypass_flag              <= 0;
                //初始化
                cu_skip_flag                           <= 0;
                part_mode                              <= `PART_2Nx2N;
                merge_flag                             <= 0;
                rqt_root_cbf                           <= 1;
                dep_partIdx_tu                         <= '{2'b00,2'b00,2'b00,2'b00,2'b00};
                blkIdx                                 <= 0;
                partIdx                                <= 0;
                pred_mode                              <= `MODE_INTRA;

                if (i_transquant_bypass_enabled_flag) begin
                    o_dec_bin_en_cu                    <= 1;
                    o_cm_idx_cu                        <= `CM_IDX_CU_TRANSQUANT_BYPASS_FLAG;
                    o_cu_state                         <= `cu_transquant_bypass_flag_s;//1
                end else if (i_slice_type != `I_SLICE) begin
                    o_dec_bin_en_cu                    <= 1;
                    if (skip_left==1 && skip_up == 1)
                        o_cm_idx_cu                    <= `CM_IDX_CU_SKIP_FLAG+2;
                    else if (skip_left == 1 || skip_up == 1)
                        o_cm_idx_cu                    <= `CM_IDX_CU_SKIP_FLAG+1;
                    else
                        o_cm_idx_cu                    <= `CM_IDX_CU_SKIP_FLAG;
                    o_cu_state                         <= `cu_skip_flag_s;//2
                end else if (i_log2CbSize == `MinCbLog2SizeY) begin
                   //进到这里必i_slice_type == `I_SLICE，cu->pred_mode == `MODE_INTRA
                   //if (cu->pred_mode != MODE_INTRA || log2CbSize == MinCbLog2SizeY)
                   //    parse_part_mode(rbsp, (int *)&cu->part_mode, x0, y0, log2CbSize, sps);
                    o_cm_idx_cu                        <= `CM_IDX_PART_MODE;
                    o_dec_bin_en_cu                    <= 1;
                    o_cu_state                         <= `parse_part_mode_intra;
                end else begin
                    o_cu_state                         <= `cu_intra_or_inter;//3
                end
            end

        `cu_intra_or_inter:
            begin
                if (i_slice_type != `I_SLICE) begin
                    //parse_pred_mode_flag
                    o_dec_bin_en_cu                      <= 1;
                    o_cm_idx_cu                          <= `CM_IDX_PRED_MODE;
                    o_cu_state                           <= `pred_mode_flag_s;//6
                end else begin
                    pred_mode                            <= `MODE_INTRA;
                    if (log2CbSize == `MinCbLog2SizeY) begin //MODE_INTRA下，只有8x8才有4等分的PART_NxN，默认是PART_2Nx2N=0，不分割
                        o_cm_idx_cu                      <= `CM_IDX_PART_MODE;
                        o_dec_bin_en_cu                  <= 1;
                        o_cu_state                       <= `parse_part_mode_intra;
                    end else begin
                        partIdx                          <= 0;
                        o_dec_bin_en_cu                  <= 1;
                        o_cm_idx_cu                      <= `CM_IDX_PREV_INTRA_LUMA_PRED_FLAG;
                        o_cu_state                       <= `prev_intra_luma_pred_flag_s;//c

                    end
                    
                end
            end



        //只有part_num=4才走到这个状态
        `store_intra_luma_pred_mode://0x10
            begin


                if (prev_intra_luma_pred_flag[partIdx]) begin
                    IntraPredModeY                              <= candModeList[mpm_idx];
                    cu_intra_luma_pred_mode[partIdx]            <= candModeList[mpm_idx];
                    intra_luma_pred_mode_up[x0[5:2]]            <= candModeList[mpm_idx];
                    intra_luma_pred_mode_left[y0[5:2]]          <= candModeList[mpm_idx];
                    if (`log_i && slice_num>=`slice_begin && slice_num<=`slice_end)
                        $fdisplay(fd_log, "IntraPredModeY %0d", candModeList[mpm_idx]);

                end else begin
                    cu_intra_luma_pred_mode[partIdx]            <= IntraPredModeY;
                    intra_luma_pred_mode_up[x0[5:2]]            <= IntraPredModeY;
                    intra_luma_pred_mode_left[y0[5:2]]          <= IntraPredModeY;
                    if (`log_i && slice_num>=`slice_begin && slice_num<=`slice_end)
                        $fdisplay(fd_log, "IntraPredModeY %0d", IntraPredModeY);
                end


                partIdx                                     <= partIdx + 1;
                if (partIdx == 0) begin
                    x0                                      <= x0+4;
                end else if (partIdx == 1) begin
                    x0                                      <= x0-4;
                    y0                                      <= y0+4;
                end else if (partIdx == 2) begin
                    x0                                      <= x0+4;
                end else if (partIdx == 3) begin
                    x0                                      <= x0-4; //回到partIdx=0的坐标
                    y0                                      <= y0-4;
                end
                
                if (partIdx == part_num-1) begin
                    o_dec_bin_en_cu                         <= 1;
                    o_cm_idx_cu                             <= `CM_IDX_INTRA_CHROMA_PRED_MODE;
                    o_cu_state                              <= `parse_intra_chroma_pred_mode_1;
                end else
                     if (prev_intra_luma_pred_flag[partIdx+1] == 1) begin
                         o_cu_state                         <= `parse_mpm_idx;
                         i                                  <= 0;
                         o_byp_dec_en_cu                    <= 1;
                     end else begin
                         o_cu_state                         <= `parse_rem_intra_luma_pred_mode;
                         rem_intra_luma_pred_mode[partIdx+1]<= 0;
                         i                                  <= 0;
                         o_byp_dec_en_cu                    <= 1;
                     end

            end


        `split_tu_or_not: begin//0x16
            store_bs_pu_bound                           <= 0;
            //到这trafoDepth肯定是1以上,!(IntraSplitFlag && (trafoDepth == 0))不必考虑
            if(log2TrafoSize <= `Log2MaxTrafoSize && log2TrafoSize > `Log2MinTrafoSize &&
               trafoDepth < MaxTrafoDepth) begin
                o_cm_idx_cu                             <= `CM_IDX_TRANS_SUBDIV_FLAG-log2TrafoSize+5;
                o_dec_bin_en_cu                         <= 1;
                o_cu_state                              <= `split_transform_flag_s;
            end else begin
                if (log2TrafoSize > `Log2MaxTrafoSize ||
                            (IntraSplitFlag && trafoDepth == 0) || interSplitFlag)
                    split_tu                            <= 1;
                else
                    split_tu                            <= 0;
                o_cu_state                              <= `parse_cb_cr_or_not;

            end
        end

        //这里用到的log2TrafoSize是没有split之前的size,trafoDepth也是
        `parse_cb_cr_or_not://0x19
            if (log2TrafoSize > 2 && (trafoDepth == 0 || base_cbf_cb[trafoDepth-1])) begin //todo base_cbf_cb[-1]??
                o_dec_bin_en_cu                         <= 1;
                o_cm_idx_cu                             <= `CM_IDX_QT_CBF_CB_CR+trafoDepth;
                o_cu_state                              <= `cbf_cb_s;
            end else begin
                cbf_cb                                  <= base_cbf_cb[trafoDepth-1];
                base_cbf_cb[trafoDepth]                 <= base_cbf_cb[trafoDepth-1];
                if (log2TrafoSize > 2 && (trafoDepth == 0 || base_cbf_cr[trafoDepth-1])) begin
                    o_dec_bin_en_cu                     <= 1;
                    o_cm_idx_cu                         <= `CM_IDX_QT_CBF_CB_CR+trafoDepth;
                    o_cu_state                          <= `cbf_cr_s;
                end else begin
                    cbf_cr                              <= base_cbf_cr[trafoDepth-1];
                    base_cbf_cr[trafoDepth]             <= base_cbf_cr[trafoDepth-1];
                    if (split_tu) begin
                        trafoDepth                      <= trafoDepth+1;
                        log2TrafoSize                   <= log2TrafoSize-1;
                        trafoSize                       <= trafoSize >> 1;
                        dep_partIdx_tu[trafoDepth+1]    <= 0;
                        blkIdx                          <= 0;
                        o_cu_state                      <= `split_tu_or_not;
                    end else begin
                        o_cu_state                      <= `cu_pass2tu;
                        rst_tu                          <= 1;

                    end
                end
            end


    `cu_pass2tu://0x1a
        begin
            store_bs_pu_bound                <= 0;
            if (part_mode == `PART_NxN) begin
                //传给TU
                IntraPredModeY               <= cu_intra_luma_pred_mode[blkIdx];
            end

            if (pred_mode==`MODE_INTRA&&(~rec_done_luma||
                ~rec_done_cb||~intra_pred_cr_done||~inter_pred_done)) begin //mark4

            end else begin
                first_cycle_parse_tu         <= 1;
                first_tu_in_cu               <= 0;
                o_cu_state                   <= `parse_tu;
            end

        end

    `wait_mv_done_1://0x25
        if (up_mvf_fetch_done&&
            col_param_fetch_done)begin
            reset_mv                          <= 1;
            first_tu_in_cu                    <= 1; //fix,应该放这，如果放reset，解下一个cu的时候reset时，本cu inter pred还在进行
            o_cu_state                        <= `wait_mv_done_2;
        end
    `wait_mv_done_2://0x26
        begin
            reset_mv                          <= 0;
            if (~reset_mv&&mv_done&&
                rec_done_luma&&rec_done_cb&&
                rec_done_cr) begin
                pu_mvf.refIdx                 <= pu_mvf_w.refIdx;
                pu_mvf.mv.mv[0]               <= pu_mvf_w.mv.mv[0]+mvd[0];
                pu_mvf.mv.mv[1]               <= pu_mvf_w.mv.mv[1]+mvd[1];
                //来自i_slice_local_rps.deltaPoc
                delta_poc_cur_pu              <= i_delta_poc[pu_mvf_w.refIdx];

                o_cu_state                    <= `update_mvf_nb;
            end
        end
    `update_mvf_nb://0x27
        begin
            pu_info.x0                        <= x0;
            pu_info.y0                        <= y0;
            pu_info.CbSize                    <= CbSize;
            pu_info.mvf[partIdx]              <= pu_mvf;
            pu_info.xPb[partIdx]              <= xPb;
            pu_info.yPb[partIdx]              <= yPb;
            pu_info.nPbW[partIdx]             <= nPbW;
            pu_info.nPbH[partIdx]             <= nPbH;
            partIdx                           <= partIdx+1;
            xPb_save                          <= xPb;
            yPb_save                          <= yPb;
            if (partIdx==0) begin
                xPb                           <= xPb_nxt;
                yPb                           <= yPb_nxt;
            end else if (partIdx==1) begin
                xPb                           <= x0[5:0];
                yPb                           <= y0[5:0]+nPbH;
            end else if (partIdx==2) begin
                xPb                           <= x0[5:0]+nPbW;
                yPb                           <= y0[5:0]+nPbH;
            end
            left_mvf                          <= left_mvf_w;
            delta_poc_left                    <= delta_poc_left_w;
            //x0=0时不初始化delta_poc_left应该也没事，bs用不到，to debug
            //to debug,碰到intra pred cu不需要更新?
            //up_mvf                            <= up_mvf_w; 放到另一个always块，multiple drive了
            left_up_mvf                       <= left_up_mvf_w;

            store_bs_pu_bound                 <= 1;
            if (partIdx == part_num-1) begin
                if (pred_mode==`MODE_INTER&&
                    ~(part_mode==`PART_2Nx2N &&merge_flag)) begin
                    o_dec_bin_en_cu           <= 1;
                    o_cm_idx_cu               <= `CM_IDX_QT_ROOT_CBF;
                    o_cu_state                <= `rqt_root_cbf_s;//0x28
                end else begin
                    if (cu_skip_flag) begin
                        o_cu_state            <= `cu_pass2tu;//0x1a
                        rst_tu                <= 1;
                    end else begin
                        o_cu_state            <= `split_tu_or_not;
                    end

                end

            end else begin
                o_dec_bin_en_cu               <= 1;
                o_cm_idx_cu                   <= `CM_IDX_MERGE_FLAG;
                o_cu_state                    <= `merge_flag_s;//0x1b
            end
        end
    `parse_tu://0x14
        begin
            rst_tu                                     <= 0;
            first_cycle_parse_tu                       <= 0;

            if (o_tu_state == `parse_residual_coding&&cIdx==3) begin //`parse_residual_coding和`parse_residual_coding_2必会走到
                if (trafoSize[6]==1) begin
                    cbf_luma_left                       <= {16{cbf_luma}};
                    cbf_luma_up                         <= {16{cbf_luma}};
                end else if (trafoSize[5] == 1) begin
                    cbf_luma_left[{yTu[5],3'b000}]      <= cbf_luma;
                    cbf_luma_left[{yTu[5],3'b001}]      <= cbf_luma;
                    cbf_luma_left[{yTu[5],3'b010}]      <= cbf_luma;
                    cbf_luma_left[{yTu[5],3'b011}]      <= cbf_luma;
                    cbf_luma_left[{yTu[5],3'b100}]      <= cbf_luma;
                    cbf_luma_left[{yTu[5],3'b101}]      <= cbf_luma;
                    cbf_luma_left[{yTu[5],3'b110}]      <= cbf_luma;
                    cbf_luma_left[{yTu[5],3'b111}]      <= cbf_luma;

                    cbf_luma_up[{xTu[5],3'b000}]        <= cbf_luma;
                    cbf_luma_up[{xTu[5],3'b001}]        <= cbf_luma;
                    cbf_luma_up[{xTu[5],3'b010}]        <= cbf_luma;
                    cbf_luma_up[{xTu[5],3'b011}]        <= cbf_luma;
                    cbf_luma_up[{xTu[5],3'b100}]        <= cbf_luma;
                    cbf_luma_up[{xTu[5],3'b101}]        <= cbf_luma;
                    cbf_luma_up[{xTu[5],3'b110}]        <= cbf_luma;
                    cbf_luma_up[{xTu[5],3'b111}]        <= cbf_luma;
                end else if (trafoSize[4] == 1) begin
                    cbf_luma_left[{yTu[5:4],2'b00}]     <= cbf_luma;
                    cbf_luma_left[{yTu[5:4],2'b01}]     <= cbf_luma;
                    cbf_luma_left[{yTu[5:4],2'b10}]     <= cbf_luma;
                    cbf_luma_left[{yTu[5:4],2'b11}]     <= cbf_luma;

                    cbf_luma_up[{xTu[5:4],2'b00}]       <= cbf_luma;
                    cbf_luma_up[{xTu[5:4],2'b01}]       <= cbf_luma;
                    cbf_luma_up[{xTu[5:4],2'b10}]       <= cbf_luma;
                    cbf_luma_up[{xTu[5:4],2'b11}]       <= cbf_luma;

                end else if (trafoSize[3] == 1) begin
                    cbf_luma_left[{yTu[5:3],1'b0}]      <= cbf_luma;
                    cbf_luma_left[{yTu[5:3],1'b1}]      <= cbf_luma;
                    cbf_luma_up[{xTu[5:3],1'b0}]        <= cbf_luma;
                    cbf_luma_up[{xTu[5:3],1'b1}]        <= cbf_luma;
                end else begin
                    cbf_luma_left[yTu[5:2]]             <= cbf_luma;
                    cbf_luma_up[xTu[5:2]]               <= cbf_luma;
                end
            end

            if (o_tu_state == `tu_end) begin
                dep_partIdx_tu[trafoDepth]             <= dep_partIdx_tu[trafoDepth] + 1;//解完才+1，dep_partIdx[cqtDepth]是正在解的part
                blkIdx                                 <= dep_partIdx_tu[trafoDepth] + 1;
                if (part_mode == `PART_2Nx2N) begin
                
                end
                o_cu_state                             <= `split_tu_or_not; //mark2

                if (`log_v && slice_num>=`slice_begin && slice_num<=`slice_end)
                    $fdisplay(fd_log, "%t tu_end trafoDepth %d blkIdx %d dep_partIdx_tu[%d] %d",
                     $time,trafoDepth,blkIdx,trafoDepth,dep_partIdx_tu[trafoDepth]);

                if (trafoDepth == 0) begin
                    first_cycle_cu_end                 <= 1;
                    o_cu_state                         <= `cu_end;
                end else begin
                    if (dep_partIdx_tu[trafoDepth] == 0) begin
                        xTu                            <= xTu + trafoSize; //下一个partIdx=1的坐标
                    end
                    if (dep_partIdx_tu[trafoDepth] == 1) begin
                        xTu                            <= xTu - trafoSize;
                        yTu                            <= yTu + trafoSize;
                    end
                    if (dep_partIdx_tu[trafoDepth] == 2) begin
                        xTu                            <= xTu + trafoSize;
                    end
                    if (dep_partIdx_tu[trafoDepth] == 3) begin
                        //转到上一层
                        trafoDepth                     <= trafoDepth - 1;
                        log2TrafoSize                  <= log2TrafoSize+1;
                        trafoSize                      <= trafoSize<<1;
                        xTu                            <= xTu - trafoSize;
                        yTu                            <= yTu - trafoSize;
                        if (trafoDepth - 1 == 0) begin
                            first_cycle_cu_end         <= 1;
                            o_cu_state                 <= `cu_end;
                        end else begin
                            o_cu_state                 <= `parse_tu; //这是转到上层，下一次还是走到这里,o_tu_state == `tu_end成立，
                                                                     //不是进入下一tu的解析，进入下一tu解析在上面mark2，经过`split_tu_or_not,
                                                                     //然后必然经过`cu_pass2tu
                        end

                    end
                end
            end
        end

    `cu_end:
        begin
            first_cycle_cu_end                                 <= 0;
            if (pred_mode == `MODE_INTER&&first_cycle_cu_end) begin //inter or skip, intra_luma_pred_mode设为DC
                //这个不着急用，放到`cu_end也无所谓
                if (CbSize[6] == 1) begin
                    intra_luma_pred_mode_left                  <= '{16{1}};
                    intra_luma_pred_mode_up                    <= '{16{1}};
                end else if (CbSize[5] == 1) begin
                    intra_luma_pred_mode_left[{y0[5],3'b000}]  <= 1;
                    intra_luma_pred_mode_left[{y0[5],3'b001}]  <= 1;
                    intra_luma_pred_mode_left[{y0[5],3'b010}]  <= 1;
                    intra_luma_pred_mode_left[{y0[5],3'b011}]  <= 1;
                    intra_luma_pred_mode_left[{y0[5],3'b100}]  <= 1;
                    intra_luma_pred_mode_left[{y0[5],3'b101}]  <= 1;
                    intra_luma_pred_mode_left[{y0[5],3'b110}]  <= 1;
                    intra_luma_pred_mode_left[{y0[5],3'b111}]  <= 1;

                    intra_luma_pred_mode_up[{x0[5],3'b000}]    <= 1;
                    intra_luma_pred_mode_up[{x0[5],3'b001}]    <= 1;
                    intra_luma_pred_mode_up[{x0[5],3'b010}]    <= 1;
                    intra_luma_pred_mode_up[{x0[5],3'b011}]    <= 1;
                    intra_luma_pred_mode_up[{x0[5],3'b100}]    <= 1;
                    intra_luma_pred_mode_up[{x0[5],3'b101}]    <= 1;
                    intra_luma_pred_mode_up[{x0[5],3'b110}]    <= 1;
                    intra_luma_pred_mode_up[{x0[5],3'b111}]    <= 1;
                end else if (CbSize[4] == 1) begin
                    intra_luma_pred_mode_left[{y0[5:4],2'b00}]  <= 1;
                    intra_luma_pred_mode_left[{y0[5:4],2'b01}]  <= 1;
                    intra_luma_pred_mode_left[{y0[5:4],2'b10}]  <= 1;
                    intra_luma_pred_mode_left[{y0[5:4],2'b11}]  <= 1;

                    intra_luma_pred_mode_up[{x0[5:4],2'b00}]    <= 1;
                    intra_luma_pred_mode_up[{x0[5:4],2'b01}]    <= 1;
                    intra_luma_pred_mode_up[{x0[5:4],2'b10}]    <= 1;
                    intra_luma_pred_mode_up[{x0[5:4],2'b11}]    <= 1;

                end else if (CbSize[3] == 1) begin
                    intra_luma_pred_mode_left[{y0[5:3],1'b0}]   <= 1;
                    intra_luma_pred_mode_left[{y0[5:3],1'b1}]   <= 1;
                    intra_luma_pred_mode_up[{x0[5:3],1'b0}]     <= 1;
                    intra_luma_pred_mode_up[{x0[5:3],1'b1}]     <= 1;
                end
            end

            if (first_cycle_cu_end) begin
                if (pred_mode==`MODE_INTRA) begin //fix,也需更新
                    left_up_mvf[y0[5:2]]              <= up_mvf[x0_right_most[5:2]];
                end

                if (CbSize[6] == 1) begin
                    cu_skip_flag_left                 <= '{8{cu_skip_flag}};
                    cu_skip_flag_up                   <= '{8{cu_skip_flag}};
                end else if (CbSize[5] == 1) begin

                    cu_skip_flag_left[{y0[5],2'b00}]  <= cu_skip_flag;
                    cu_skip_flag_left[{y0[5],2'b01}]  <= cu_skip_flag;
                    cu_skip_flag_left[{y0[5],2'b10}]  <= cu_skip_flag;
                    cu_skip_flag_left[{y0[5],2'b11}]  <= cu_skip_flag;
                    cu_skip_flag_up[{x0[5],2'b00}]    <= cu_skip_flag;
                    cu_skip_flag_up[{x0[5],2'b01}]    <= cu_skip_flag;
                    cu_skip_flag_up[{x0[5],2'b10}]    <= cu_skip_flag;
                    cu_skip_flag_up[{x0[5],2'b11}]    <= cu_skip_flag;
                end else if (CbSize[4] == 1) begin
                    cu_skip_flag_left[{y0[5:4],1'b0}] <= cu_skip_flag;
                    cu_skip_flag_left[{y0[5:4],1'b1}] <= cu_skip_flag;
                    cu_skip_flag_up[{x0[5:4],1'b0}]   <= cu_skip_flag;
                    cu_skip_flag_up[{x0[5:4],1'b1}]   <= cu_skip_flag;
                end else if (CbSize[3] == 1) begin
                    cu_skip_flag_left[y0[5:3]]        <= cu_skip_flag;
                    cu_skip_flag_up[x0[5:3]]          <= cu_skip_flag;
                end

                if (CbSize[6] == 1) begin
                    cur_ctb_cu_predmode               <= {64{pred_mode}}; //{8{8{pred_mode}}} illegal
                    cu_predmode_left_init0            <= {8{pred_mode}};
                    cu_predmode_left_init1            <= {8{pred_mode}};
                    cu_predmode_leftup_init0[7:1]     <= {7{pred_mode}};
                    cu_predmode_leftup_init1[7:1]     <= {7{pred_mode}};
                    cu_predmode_leftup_init0[0]       <= cu_predmode_up_init0[x0_right_most[5:3]];
                    cu_predmode_leftup_init1[0]       <= cu_predmode_up_init1[x0_right_most[5:3]];
                end else if (CbSize[5] == 1) begin
                    cur_ctb_cu_predmode[{y0[5],2'b00}][{x0[5],2'b00}]  <= pred_mode;
                    cur_ctb_cu_predmode[{y0[5],2'b00}][{x0[5],2'b01}]  <= pred_mode;
                    cur_ctb_cu_predmode[{y0[5],2'b00}][{x0[5],2'b10}]  <= pred_mode;
                    cur_ctb_cu_predmode[{y0[5],2'b00}][{x0[5],2'b11}]  <= pred_mode;
                    cur_ctb_cu_predmode[{y0[5],2'b01}][{x0[5],2'b00}]  <= pred_mode;
                    cur_ctb_cu_predmode[{y0[5],2'b01}][{x0[5],2'b01}]  <= pred_mode;
                    cur_ctb_cu_predmode[{y0[5],2'b01}][{x0[5],2'b10}]  <= pred_mode;
                    cur_ctb_cu_predmode[{y0[5],2'b01}][{x0[5],2'b11}]  <= pred_mode;
                    cur_ctb_cu_predmode[{y0[5],2'b10}][{x0[5],2'b00}]  <= pred_mode;
                    cur_ctb_cu_predmode[{y0[5],2'b10}][{x0[5],2'b01}]  <= pred_mode;
                    cur_ctb_cu_predmode[{y0[5],2'b10}][{x0[5],2'b10}]  <= pred_mode;
                    cur_ctb_cu_predmode[{y0[5],2'b10}][{x0[5],2'b11}]  <= pred_mode;
                    cur_ctb_cu_predmode[{y0[5],2'b11}][{x0[5],2'b00}]  <= pred_mode;
                    cur_ctb_cu_predmode[{y0[5],2'b11}][{x0[5],2'b01}]  <= pred_mode;
                    cur_ctb_cu_predmode[{y0[5],2'b11}][{x0[5],2'b10}]  <= pred_mode;
                    cur_ctb_cu_predmode[{y0[5],2'b11}][{x0[5],2'b11}]  <= pred_mode;

                    cu_predmode_left_init0[{y0[5],2'b00}]    <= pred_mode;
                    cu_predmode_left_init0[{y0[5],2'b01}]    <= pred_mode;
                    cu_predmode_left_init0[{y0[5],2'b10}]    <= pred_mode;
                    cu_predmode_left_init0[{y0[5],2'b11}]    <= pred_mode;
                    cu_predmode_left_init1[{y0[5],2'b00}]    <= pred_mode;
                    cu_predmode_left_init1[{y0[5],2'b01}]    <= pred_mode;
                    cu_predmode_left_init1[{y0[5],2'b10}]    <= pred_mode;
                    cu_predmode_left_init1[{y0[5],2'b11}]    <= pred_mode;

                    cu_predmode_leftup_init0[{y0[5],2'b00}]  <= cu_predmode_up_init0[x0_right_most[5:3]];
                    cu_predmode_leftup_init0[{y0[5],2'b01}]  <= pred_mode;
                    cu_predmode_leftup_init0[{y0[5],2'b10}]  <= pred_mode;
                    cu_predmode_leftup_init0[{y0[5],2'b11}]  <= pred_mode;

                    cu_predmode_leftup_init1[{y0[5],2'b00}]  <= cu_predmode_up_init1[x0_right_most[5:3]];
                    cu_predmode_leftup_init1[{y0[5],2'b01}]  <= pred_mode;
                    cu_predmode_leftup_init1[{y0[5],2'b10}]  <= pred_mode;
                    cu_predmode_leftup_init1[{y0[5],2'b11}]  <= pred_mode;

                end else if (CbSize[4] == 1) begin

                    cur_ctb_cu_predmode[{y0[5:4],1'b0}][{x0[5:4],1'b0}] <= pred_mode;
                    cur_ctb_cu_predmode[{y0[5:4],1'b1}][{x0[5:4],1'b0}] <= pred_mode;
                    cur_ctb_cu_predmode[{y0[5:4],1'b0}][{x0[5:4],1'b1}] <= pred_mode;
                    cur_ctb_cu_predmode[{y0[5:4],1'b1}][{x0[5:4],1'b1}] <= pred_mode;

                    cu_predmode_left_init0[{y0[5:4],1'b0}]    <= pred_mode;
                    cu_predmode_left_init0[{y0[5:4],1'b1}]    <= pred_mode;
                    cu_predmode_left_init1[{y0[5:4],1'b0}]    <= pred_mode;
                    cu_predmode_left_init1[{y0[5:4],1'b1}]    <= pred_mode;

                    cu_predmode_leftup_init0[{y0[5:4],1'b0}]  <= cu_predmode_up_init0[x0_right_most[5:3]];
                    cu_predmode_leftup_init0[{y0[5:4],1'b1}]  <= pred_mode;

                    cu_predmode_leftup_init1[{y0[5:4],1'b0}]  <= cu_predmode_up_init1[x0_right_most[5:3]];
                    cu_predmode_leftup_init1[{y0[5:4],1'b1}]  <= pred_mode;
                end else if (CbSize[3] == 1) begin

                    cur_ctb_cu_predmode[y0[5:3]][x0[5:3]]    <= pred_mode;

                    cu_predmode_left_init0[y0[5:3]]          <= pred_mode;
                    cu_predmode_left_init1[y0[5:3]]          <= pred_mode;

                    cu_predmode_leftup_init0[y0[5:3]]        <= cu_predmode_up_init0[x0_right_most[5:3]];;
                    cu_predmode_leftup_init1[y0[5:3]]        <= cu_predmode_up_init1[x0_right_most[5:3]];;

                end
            end


            if (i_slice_data_state==`ctb_end) begin

                //一个CTB解完
                dram_cu_skip_up_we                 <= 1;
                dram_cu_skip_up_addr               <= x0[`max_x_bits-1:6];
                dram_cu_skip_up_din                <= cu_skip_flag_up;

                dram_cbf_luma_up_we                <= 1;
                dram_cbf_luma_up_addr              <= i_x0[`max_x_bits-1:6];
                dram_cbf_luma_up_din               <= cbf_luma_up;
            end

        end

    endcase
end



reg   [1:0]     fetch_up_ctb_predmode_i;

always @ (posedge clk)
if (i_rst_ctb) begin
    fetch_up_ctb_predmode_i                <= 0;
    if (i_y0 == 0) begin
        cu_predmode_up_init0               <= {16{1'b0}};
        cu_predmode_up_init1               <= {16{1'b1}};
        fetch_up_ctb_predmode_i            <= 2;
    end else begin
        dram_up_ctb_cu_predmode_we         <= 0;
        dram_up_ctb_cu_predmode_addr       <= i_x0[`max_x_bits-1:6];
        fetch_up_ctb_predmode_i            <= 0;
    end
end else begin
    if (fetch_up_ctb_predmode_i<2) begin //16bit,取两次
        cu_predmode_up_init1               <= {dram_up_ctb_cu_predmode_dout,cu_predmode_up_init1[15:8]};
        cu_predmode_up_init0               <= {dram_up_ctb_cu_predmode_dout,cu_predmode_up_init0[15:8]};
        dram_up_ctb_cu_predmode_addr       <= i_x0[`max_x_bits-1:6]+fetch_up_ctb_predmode_i+1;
        fetch_up_ctb_predmode_i            <= fetch_up_ctb_predmode_i+1;
    end else if (o_cu_state == `cu_end&&first_cycle_cu_end) begin
        if (CbSize[6] == 1) begin
            cu_predmode_up_init0[7:0]              <= {8{pred_mode}};
            cu_predmode_up_init1[7:0]              <= {8{pred_mode}};
        end else if (CbSize[5] == 1) begin
            cu_predmode_up_init0[{x0[5],2'b00}]    <= pred_mode;
            cu_predmode_up_init0[{x0[5],2'b01}]    <= pred_mode;
            cu_predmode_up_init0[{x0[5],2'b10}]    <= pred_mode;
            cu_predmode_up_init0[{x0[5],2'b11}]    <= pred_mode;
            cu_predmode_up_init1[{x0[5],2'b00}]    <= pred_mode;
            cu_predmode_up_init1[{x0[5],2'b01}]    <= pred_mode;
            cu_predmode_up_init1[{x0[5],2'b10}]    <= pred_mode;
            cu_predmode_up_init1[{x0[5],2'b11}]    <= pred_mode;
        end else if (CbSize[4] == 1) begin
            cu_predmode_up_init0[{x0[5:4],1'b0}]   <= pred_mode;
            cu_predmode_up_init0[{x0[5:4],1'b1}]   <= pred_mode;
            cu_predmode_up_init1[{x0[5:4],1'b0}]   <= pred_mode;
            cu_predmode_up_init1[{x0[5:4],1'b1}]   <= pred_mode;
        end else if (CbSize[3] == 1) begin
            cu_predmode_up_init0[x0[5:3]]          <= pred_mode;
            cu_predmode_up_init1[x0[5:3]]          <= pred_mode;
        end

    end else if (i_slice_data_state==`ctb_end) begin

            //一个CTB解完
            dram_up_ctb_cu_predmode_we             <= 1;
            dram_up_ctb_cu_predmode_addr           <= x0[`max_x_bits-1:6];
            dram_up_ctb_cu_predmode_din            <= cu_predmode_up_init1[7:0];

        end
end


always @ (*)
begin
    if (dram_up_ctb_cu_predmode_we==0&&
        dram_up_ctb_cu_predmode_addr==7) begin
        $display("%t read %x",$time,dram_up_ctb_cu_predmode_dout);
    end


    if (dram_up_ctb_cu_predmode_we==1&&
        dram_up_ctb_cu_predmode_addr==0&&slice_num==5) begin
        $display("%t write %x",$time,dram_up_ctb_cu_predmode_din);
    end

end

//============================================= BS =================================================//

reg                               bs_sel;
reg  [ 1:0][ 7:0][15:0][ 1:0]     bs_ver;
reg  [ 1:0][ 7:0][15:0][ 1:0]     bs_hor;

reg  [15:0][ 1:0]                 bs_hor_cur_tu_bound;
reg  [15:0][ 1:0]                 bs_ver_cur_tu_bound;
reg  [15:0][ 1:0]                 bs_hor_cur_pu_bound;
reg  [15:0][ 1:0]                 bs_ver_cur_pu_bound;

reg  [15:0][ 1:0]                 bs_hor_tu_bound;
reg  [15:0][ 1:0]                 bs_ver_tu_bound;
reg  [15:0][ 1:0]                 bs_hor_pu_bound;
reg  [15:0][ 1:0]                 bs_ver_pu_bound;

reg  [15:0][ 1:0]                 bs_hor_pu_bound_w;
reg  [15:0][ 1:0]                 bs_ver_pu_bound_w;

reg        [ 6:0]                 tu_bottom_bound;
reg        [ 6:0]                 tu_right_bound;
reg        [ 6:0]                 pu_bottom_bound;
reg        [ 6:0]                 pu_right_bound;

always @ (posedge clk)
begin
    pu_right_bound  <= xPb+nPbW;
    pu_bottom_bound <= yPb+nPbH;
    tu_right_bound  <= xTu+trafoSize;
    tu_bottom_bound <= yTu+trafoSize;
end

wire signed   [14:0]                up_mv0[15:0];
wire signed   [14:0]                up_mv1[15:0];
wire signed   [14:0]                left_mv0[15:0];
wire signed   [14:0]                left_mv1[15:0];
wire signed   [14:0]                pu_mvf_mv0;
wire signed   [14:0]                pu_mvf_mv1;


assign pu_mvf_mv0 = pu_mvf_w.mv.mv[0];
assign pu_mvf_mv1 = pu_mvf_w.mv.mv[1];

wire signed   [14:0]                diff_up_mv0_w[15:0];
wire signed   [14:0]                diff_up_mv1_w[15:0];
wire signed   [14:0]                diff_left_mv0_w[15:0];
wire signed   [14:0]                diff_left_mv1_w[15:0];
reg  signed   [14:0]                diff_up_mv0[15:0];
reg  signed   [14:0]                diff_up_mv1[15:0];
reg  signed   [14:0]                diff_left_mv0[15:0];
reg  signed   [14:0]                diff_left_mv1[15:0];

generate
    for (I=0;I<16;I++)
    begin: diff_abs_mv_label
        assign up_mv0[I] = up_mvf[I].mv.mv[0];
        assign up_mv1[I] = up_mvf[I].mv.mv[1];
        assign left_mv0[I] = left_mvf[I].mv.mv[0];
        assign left_mv1[I] = left_mvf[I].mv.mv[1];

        assign diff_up_mv0_w[I] = pu_mvf_mv0+mvd[0]-up_mv0[I];
        assign diff_up_mv1_w[I] = pu_mvf_mv1+mvd[1]-up_mv1[I];
        assign diff_left_mv0_w[I] = pu_mvf_mv0+mvd[0]-left_mv0[I];
        assign diff_left_mv1_w[I] = pu_mvf_mv1+mvd[1]-left_mv1[I];
    end
endgenerate

generate
    for (I=0;I<16;I++)
    begin: bs_pu_bound_label
        always @(*)
        begin
            if (I>=xPb[5:2]&& I<pu_right_bound[6:2]) begin
                if (delta_poc_up[I]!=delta_poc_cur_pu)
                    bs_hor_pu_bound_w[I] = 1;
                else if (diff_up_mv0[I]>=4 ||
                         diff_up_mv0[I]<=-4 ||
                         diff_up_mv1[I]>=4 ||
                         diff_up_mv1[I]<=-4)
                    bs_hor_pu_bound_w[I] = 1;
                else
                    bs_hor_pu_bound_w[I] = bs_hor_cur_pu_bound[I];
            end else begin
                bs_hor_pu_bound_w[I] = bs_hor_cur_pu_bound[I];
            end

            if (I>=yPb[5:2]&& I<pu_bottom_bound[6:2]) begin
                if (delta_poc_left[I]!=delta_poc_cur_pu) begin
                    bs_ver_pu_bound_w[I] = 1;
                end else if (diff_left_mv0[I]>=4 ||
                         diff_left_mv0[I]<=-4 ||
                         diff_left_mv1[I]>=4 ||
                         diff_left_mv1[I]<=-4) begin
                    bs_ver_pu_bound_w[I] = 1;
                end else begin
                    bs_ver_pu_bound_w[I] = bs_ver_cur_pu_bound[I];
                end
            end else begin
                bs_ver_pu_bound_w[I] = bs_ver_cur_pu_bound[I];
            end
        end

    end
endgenerate

wire  [15:0]        left_predmode_tu_bound;
wire  [15:0]        up_predmode_tu_bound;


reg   [15:0][ 1:0]  bs_hor_tu_bound_w;
reg   [15:0][ 1:0]  bs_ver_tu_bound_w;

generate
    for (I=0;I<16;I++)
    begin: predmode_label
        assign left_predmode_tu_bound[I] = xTu[5:2]==x0[5:2]?cu_predmode_left_init0[I/2]:pred_mode;
        assign up_predmode_tu_bound[I]   = yTu[5:2]==y0[5:2]?cu_predmode_up_init0[I/2]:pred_mode;
    end
endgenerate

generate
    for (I=0;I<16;I++)
    begin: bs_label
        always @(*)
        begin
            if (I>=yTu[5:2]&& I<tu_bottom_bound[6:2]) begin
                if (left_predmode_tu_bound[I]==`MODE_INTRA||pred_mode==`MODE_INTRA)
                    bs_ver_tu_bound_w[I] = 2;
                else if (cbf_luma_left[I]||cbf_luma)
                    bs_ver_tu_bound_w[I] = 1;
                else
                    bs_ver_tu_bound_w[I] = bs_ver_cur_tu_bound[I]; //为pu得到的bs_ver
            end else begin
                bs_ver_tu_bound_w[I] = bs_ver_cur_tu_bound[I];
            end

            if (I>=xTu[5:2]&& I<tu_right_bound[6:2]) begin

                if (up_predmode_tu_bound[I]==`MODE_INTRA||pred_mode==`MODE_INTRA) begin
                    bs_hor_tu_bound_w[I] = 2;
                end else if (cbf_luma_up[I]||cbf_luma) begin
                    bs_hor_tu_bound_w[I] = 1;
                end else begin
                    bs_hor_tu_bound_w[I] = bs_hor_cur_tu_bound[I];
                end
            end else begin
                bs_hor_tu_bound_w[I] = bs_hor_cur_tu_bound[I];
            end
        end

    end
endgenerate

always @ (posedge clk)
begin
    //to debug,随着xPb,yPb,xTu,yTu而变
    bs_hor_cur_tu_bound  <= bs_hor[bs_sel][yTu[5:3]];
    bs_ver_cur_tu_bound  <= bs_ver[bs_sel][xTu[5:3]];
    bs_hor_cur_pu_bound  <= bs_hor[bs_sel][yPb[5:3]];
    bs_ver_cur_pu_bound  <= bs_ver[bs_sel][xPb[5:3]];
end

always @(posedge clk)
if (global_rst) begin
    bs_sel                               <= 0;
end else if (i_rst_ctb|i_rst_filter) begin
    bs_sel                               <= ~bs_sel;
    bs_ver[~bs_sel]                      <= {128{2'b00}};
    bs_hor[~bs_sel]                      <= {128{2'b00}};
end else begin
    if (o_cu_state == `parse_tu) begin
        if (o_tu_state == `parse_residual_coding&&cIdx==3) begin
            bs_ver_tu_bound             <= bs_ver_tu_bound_w;
            bs_hor_tu_bound             <= bs_hor_tu_bound_w;
        end
        if (o_tu_state == `parse_residual_coding_2&&cIdx==3) begin
            if (~yTu[2])
                bs_hor[bs_sel][yTu[5:3]] <= bs_hor_tu_bound; //第一行第一列不用赋值，赋值也没关系，少个if
            if (~xTu[2])
                bs_ver[bs_sel][xTu[5:3]] <= bs_ver_tu_bound;
        end
    end
    if (o_cu_state==`wait_mv_done_2) begin
 
        if (~reset_mv&&mv_done) begin
            diff_up_mv0                  <= diff_up_mv0_w;
            diff_up_mv1                  <= diff_up_mv1_w;
            diff_left_mv0                <= diff_left_mv0_w;
            diff_left_mv1                <= diff_left_mv1_w;
        end
    end
    if (o_cu_state==`update_mvf_nb) begin
        bs_hor_pu_bound                  <= bs_hor_pu_bound_w;
        bs_ver_pu_bound                  <= bs_ver_pu_bound_w;
    end
    //`update_mvf_nb的下一个周期
    if (store_bs_pu_bound) begin
        if (~yPb_save[2]) //8边界
            bs_hor[bs_sel][yPb_save[5:3]]     <= bs_hor_pu_bound;
        if (~xPb_save[2])
            bs_ver[bs_sel][xPb_save[5:3]]     <= bs_ver_pu_bound;
    end


end

//========================================= TRANSQUANT =============================================//

wire              [ 2:0]         tq_luma_state;
wire              [ 2:0]         tq_cb_state;
wire              [ 2:0]         tq_cr_state;

wire              [63:0]         dram_tq_we;
reg         [63:0][ 5:0]         dram_tq_addra;
wire        [63:0][ 5:0]         dram_tq_addrd;
wire signed [63:0][ 9:0]         dram_tq_doa;
wire        [63:0][ 9:0]         dram_tq_did;

wire              [31:0]         dram_tq_cb_we;
reg         [31:0][ 4:0]         dram_tq_cb_addra;
wire        [31:0][ 4:0]         dram_tq_cb_addrd;
wire signed [31:0][ 9:0]         dram_tq_cb_doa;
wire        [31:0][ 9:0]         dram_tq_cb_did;

wire              [31:0]         dram_tq_cr_we;
reg         [31:0][ 4:0]         dram_tq_cr_addra;
wire        [31:0][ 4:0]         dram_tq_cr_addrd;
wire signed [31:0][ 9:0]         dram_tq_cr_doa;
wire        [31:0][ 9:0]         dram_tq_cr_did;

generate
    for (I=0;I<64;I++)
    begin: dram_tq_label
        dram_simple #(6, 10) dram_tq
        (
            .clk(clk),
            .en(1'b1),
            .we(dram_tq_we[I]),
            .addra(dram_tq_addra[I]),
            .addrd(dram_tq_addrd[I]),
            .doa(dram_tq_doa[I]),
            .did(dram_tq_did[I])
        );
    end
endgenerate

generate
    for (I=0;I<32;I++)
    begin: dram_tq_cb_label
        dram_simple #(5, 10) dram_tq_cb
        (
            .clk(clk),
            .en(1'b1),
            .we(dram_tq_cb_we[I]),
            .addra(dram_tq_cb_addra[I]),
            .addrd(dram_tq_cb_addrd[I]),
            .doa(dram_tq_cb_doa[I]),
            .did(dram_tq_cb_did[I])
        );
    end
endgenerate

generate
    for (I=0;I<32;I++)
    begin: dram_tq_cr_label
        dram_simple #(5, 10) dram_tq_cr
        (
            .clk(clk),
            .en(1'b1),
            .we(dram_tq_cr_we[I]),
            .addra(dram_tq_cr_addra[I]),
            .addrd(dram_tq_cr_addrd[I]),
            .doa(dram_tq_cr_doa[I]),
            .did(dram_tq_cr_did[I])
        );
    end
endgenerate




//============================================ INTRA PRED ================================================//

wire  [63:0]               dram_pred_we          ;
reg   [63:0][ 5:0]         dram_pred_addra       ;
wire  [63:0][ 5:0]         dram_pred_addrd       ;
wire  [63:0][ 7:0]         dram_pred_doa         ;
wire  [63:0][ 7:0]         dram_pred_did         ;

wire  [31:0]               dram_pred_cb_we       ;
reg   [31:0][ 4:0]         dram_pred_cb_addra    ;
wire  [31:0][ 4:0]         dram_pred_cb_addrd    ;
wire  [31:0][ 7:0]         dram_pred_cb_doa      ;
wire  [31:0][ 7:0]         dram_pred_cb_did      ;

wire  [31:0]               dram_pred_cr_we       ;
reg   [31:0][ 4:0]         dram_pred_cr_addra    ;
wire  [31:0][ 4:0]         dram_pred_cr_addrd    ;
wire  [31:0][ 7:0]         dram_pred_cr_doa      ;
wire  [31:0][ 7:0]         dram_pred_cr_did      ;

generate
    for (I=0;I<64;I++)
    begin: dram_pred_label
        dram_simple #(6, 8) dram_pred
        (
            .clk(clk),
            .en(1'b1),
            .we(dram_pred_we[I]),
            .addra(dram_pred_addra[I]),
            .addrd(dram_pred_addrd[I]),
            .doa(dram_pred_doa[I]),
            .did(dram_pred_did[I])
        );
    end
endgenerate

generate
    for (I=0;I<32;I++)
    begin: dram_pred_cb_label
        dram_simple #(5, 8) dram_pred_cb
        (
            .clk(clk),
            .en(1'b1),
            .we(dram_pred_cb_we[I]),
            .addra(dram_pred_cb_addra[I]),
            .addrd(dram_pred_cb_addrd[I]),
            .doa(dram_pred_cb_doa[I]),
            .did(dram_pred_cb_did[I])
        );
    end
endgenerate

generate
    for (I=0;I<32;I++)
    begin: dram_pred_cr_label
        dram_simple #(5, 8) dram_pred_cr
        (
            .clk(clk),
            .en(1'b1),
            .we(dram_pred_cr_we[I]),
            .addra(dram_pred_cr_addra[I]),
            .addrd(dram_pred_cr_addrd[I]),
            .doa(dram_pred_cr_doa[I]),
            .did(dram_pred_cr_did[I])
        );
    end
endgenerate


wire                         avail_done;
wire             [ 8:0]      left_avail;
wire             [ 7:0]      up_avail;
wire             [ 8:0]      left_avail_sz8x8;
wire             [ 7:0]      up_avail_sz8x8;
reg              [ 8:0]      left_avail_sz8x8_r; //chroma坐标36,20,使用的是亮度32,16求出来的avail
                                                 //求avail时，是以8x8大小来求的，而求luma blk0是以4x4大小来求
reg              [ 7:0]      up_avail_sz8x8_r;



reg       [ 95:0][ 7:0]      line_buf_top_luma;
reg       [ 63:0][ 7:0]      line_buf_left_luma;
reg       [ 15:0][ 7:0]      line_buf_leftup_luma;
reg       [ 47:0][ 7:0]      line_buf_top_cb;
reg       [ 31:0][ 7:0]      line_buf_left_cb;
reg       [  7:0][ 7:0]      line_buf_leftup_cb;
reg       [ 47:0][ 7:0]      line_buf_top_cr;
reg       [ 31:0][ 7:0]      line_buf_left_cr;
reg       [  7:0][ 7:0]      line_buf_leftup_cr;
reg                          up_line_fetch_done;
reg                          up_line_cb_fetch_done;
reg                          up_line_cr_fetch_done;

wire             [63:0]      dram_intra_pred_we;
wire      [ 63:0][ 5:0]      dram_intra_pred_addr;
wire      [ 63:0][ 7:0]      dram_intra_pred_din;

wire             [31:0]      dram_intra_pred_chroma_we;
wire      [ 31:0][ 4:0]      dram_intra_pred_chroma_addr;
wire      [ 31:0][ 7:0]      dram_intra_pred_chroma_din;

(*mark_debug="true"*)
reg                          rst_intra_pred_luma;
(*mark_debug="true"*)
reg                          rst_intra_pred_cb;
(*mark_debug="true"*)
reg                          rst_intra_pred_cr;
wire             [ 3:0]      intra_pred_luma_state;
wire             [ 3:0]      intra_pred_chroma_state;
wire             [ 6:0]      intra_pred_luma_done_y;
wire             [ 5:0]      intra_pred_chroma_done_y;
reg                          nb_rst;
reg              [ 1:0]      intra_pred_cidx; //只有intra_pred_chroma用到用于区分cb，cr

reg                          luma_intra_pred_run;
reg                          cb_intra_pred_run;
reg                          cr_intra_pred_run;

reg                          pred_mode_cur_rec;
(*mark_debug="true"*)
reg                          cond_chroma_no_residual;

always @(posedge clk)
if (global_rst||i_rst_slice) begin
    intra_pred_luma_done                 <= 1;
    intra_pred_cb_done                   <= 1;
    intra_pred_cr_done                   <= 1;
    rst_intra_pred_cb                    <= 0;
    rst_intra_pred_cr                    <= 0;
    rst_intra_pred_luma                  <= 0;
    nb_rst                               <= 0;
end else if (i_rst_ctb) begin
    luma_intra_pred_run                  <= 0;
    cb_intra_pred_run                    <= 0;
    cr_intra_pred_run                    <= 0;
end else begin
    if (o_cu_state == `cu_pass2tu && pred_mode==`MODE_INTRA&&
        rec_done_luma&&rec_done_cb&&intra_pred_cr_done&&inter_pred_done&& //log打乱，暂时加上inter_pred_done,去掉mark4~mark9也要同时去掉
        up_line_fetch_done) begin //luma fetch完成，cb，cr必已完成

        rst_intra_pred_luma              <= 1; //luma和cb,cr同时进行，cb，cr顺序执行，共用一个模块
        intra_pred_cidx                  <= 1;
        nb_rst                           <= 1;
        intra_pred_luma_done             <= 0;

        luma_intra_pred_run              <= 1;
        if (~(trafoSize==4&&blkIdx!=3)) begin
            rst_intra_pred_cb            <= 1;
            cb_intra_pred_run            <= 1;
            intra_pred_cb_done           <= 0;
            intra_pred_cr_done           <= 0;
        end

        if (trafoSize==4&&blkIdx!=3)
            cond_chroma_no_residual      <= 1;
        else
            cond_chroma_no_residual      <= 0;

    end else if (pred_mode_cur_rec==`MODE_INTRA) begin
        if (o_cu_state == `parse_tu&&
            first_cycle_parse_tu) begin
            rst_intra_pred_luma          <= 0;
            rst_intra_pred_cb            <= 0;
            nb_rst                       <= 0;
        end
        if (rst_intra_pred_luma==0&&
            intra_pred_luma_state == `intra_pred_end) begin //从上面rst_intra_pred_luma,经过2周期intra_pred_luma_state才由`intra_pred_end转为3
            luma_intra_pred_run          <= 0;
            intra_pred_luma_done         <= 1;
        end

        if (intra_pred_cb_done==0&&
            intra_pred_cr_done==0&&
            intra_pred_chroma_state==`intra_pred_end&&
            rec_done_cr&&
            rst_intra_pred_cb==0&&
            rst_intra_pred_cr==0&&
            ~cond_chroma_no_residual) begin
            intra_pred_cb_done           <= 1;
            cb_intra_pred_run            <= 0;
            cr_intra_pred_run            <= 1;
            rst_intra_pred_cr            <= 1;
            intra_pred_cidx              <= 2;
        end else if (intra_pred_cr_done==0&&
                     intra_pred_cb_done==1&&
                     rst_intra_pred_cr==0 &&
                     rst_intra_pred_cb==0&&
                     intra_pred_chroma_state==`intra_pred_end&&
                     ~cond_chroma_no_residual) begin
            intra_pred_cr_done           <= 1;
            cr_intra_pred_run            <= 0;
        end else begin
            rst_intra_pred_cr            <= 0;
        end
    end


end

always @(posedge clk)
begin
    if (~xTu[2]&&~yTu[2]) begin
       left_avail_sz8x8_r  <= left_avail_sz8x8;
       up_avail_sz8x8_r    <= up_avail_sz8x8;
    end
end

avail_nb avail_inst
(
 .clk                                    (clk),
 .rst                                    (nb_rst),
 .global_rst                             (global_rst),

 .en                                     (1'b1),
 .i_slice_num                            (i_slice_num),
 .i_x0                                   (x0),
 .i_y0                                   (y0),
 .i_xTu                                  (xTu),
 .i_yTu                                  (yTu),

 .i_log2TrafoSize                        (log2TrafoSize),
 .i_trafoSize                            (trafoSize[5:0]),

 .i_constrained_intra_pred_flag          (i_constrained_intra_pred_flag),
 .i_predmode_leftup                      (cu_predmode_leftup_init0),
 .i_predmode                             (pred_mode), //当前cu的cu_predmode
 .i_predmode_left                        (cu_predmode_left_init0),
 .i_predmode_up                          (cu_predmode_up_init0),

 .i_last_col                             (last_col),
 .i_last_row                             (last_row),
 .i_first_col                            (first_col),
 .i_first_row                            (first_row),
 .i_last_col_width                       (last_col_width),
 .i_last_row_height                      (last_row_height),

 .fd_log                                 (fd_log),

 .o_left_avail                           (left_avail), //包括leftup
 .o_up_avail                             (up_avail),
 .o_left_avail_sz8x8                     (left_avail_sz8x8),
 .o_up_avail_sz8x8                       (up_avail_sz8x8),
 .o_avail_done                           (avail_done)

);

intra_pred_32 intra_pred_luma
(
 .clk                                    (clk),
 .global_rst                             (global_rst),
 .rst                                    (rst_intra_pred_luma),
 .en                                     (1'b1),
 .i_slice_num                            (i_slice_num),
 .i_x0                                   (x0),
 .i_y0                                   (y0),
 .i_xTu                                  (xTu),
 .i_yTu                                  (yTu),

 .i_log2TrafoSize                        (log2TrafoSize),
 .i_trafoSize                            (trafoSize[5:0]),
 .i_cIdx                                 (2'b00),

 .i_line_buf_left                        (line_buf_left_luma),
 .i_line_buf_top                         (line_buf_top_luma),
 .i_leftup                               (line_buf_leftup_luma),

 .i_strong_intra_smoothing_enabled_flag  (i_strong_intra_smoothing_enabled_flag),
 .i_intra_predmode                       (IntraPredModeY), //0~34

 .dram_pred_we                           (dram_intra_pred_we),
 .dram_pred_addr                         (dram_intra_pred_addr),
 .dram_pred_din                          (dram_intra_pred_din),

 .fd_log                                 (fd_pred),

 .i_left_avail                           (left_avail), //包括leftup
 .i_up_avail                             (up_avail),
 .i_avail_done                           (avail_done),
 .o_pred_done_y                          (intra_pred_luma_done_y),
 .o_intra_pred_state                     (intra_pred_luma_state)

);


wire   [4:0]    trafo_size_chroma;
wire   [2:0]    log2_trafo_size_chroma;

//传到intra_pred的trafoSize不可能为64
assign        trafo_size_chroma       = trafoSize==32?16:(trafoSize==16?8:4);
assign        log2_trafo_size_chroma  = log2TrafoSize==5?4:(log2TrafoSize==4?3:2);

intra_pred_16 intra_pred_chroma
(
 .clk                                    (clk),
 .global_rst                             (global_rst),
 .rst                                    (rst_intra_pred_cb|rst_intra_pred_cr),
 .en                                     (1'b1),
 .i_slice_num                            (i_slice_num),
 .i_x0                                   (x0), //cr intra pred开始的时候，x0,y0,xTu,yTu会不会不是当前tu的,是有可能的
                                               //cr是在intra_pred_16内部不reset x0,y0,沿用cb的x0,y0的方式，不用单独保存x0到x0_cur_rec
 .i_y0                                   (y0),
 .i_xTu                                  ({xTu[5:3],2'b00}),//坐标(0,0)，宽高8x8，index=3的tu坐标(4,4)->(0,0) 100
 .i_yTu                                  ({yTu[5:3],2'b00}),
 .i_sz4x4_blk3                           (xTu[2]&&yTu[2]),

 .i_log2TrafoSize                        (log2_trafo_size_chroma),
 .i_trafoSize                            (trafo_size_chroma),
 .i_cIdx                                 (intra_pred_cidx),

 .i_line_buf_left                        (intra_pred_cb_done?line_buf_left_cr:
                                                             line_buf_left_cb),
 .i_line_buf_top                         (intra_pred_cb_done?line_buf_top_cr:
                                                             line_buf_top_cb),
 .i_leftup                               (intra_pred_cb_done?line_buf_leftup_cr:
                                                             line_buf_leftup_cb),

 .i_intra_predmode                       (IntraPredModeC), //0~34

 .dram_pred_we                           (dram_intra_pred_chroma_we),
 .dram_pred_addr                         (dram_intra_pred_chroma_addr),
 .dram_pred_din                          (dram_intra_pred_chroma_din),

 .fd_log                                 (fd_intra_pred_chroma),

 .i_left_avail                           (xTu[2]&&yTu[2]?left_avail_sz8x8_r:left_avail), //包括leftup
 .i_up_avail                             (xTu[2]&&yTu[2]?up_avail_sz8x8_r:up_avail),
 .i_avail_done                           (avail_done),
 .o_pred_done_y                          (intra_pred_chroma_done_y),
 .o_intra_pred_state                     (intra_pred_chroma_state)

);


//============================================ INTER PRED ================================================//


//inter_pred_luma输出
wire      [63: 0]            dram_inter_pred_we;
wire      [63: 0][ 5: 0]     dram_inter_pred_addr;
wire      [63: 0][ 7: 0]     dram_inter_pred_din;
//inter_chroma_luma输出
wire      [31: 0]            dram_inter_pred_chroma_we;
wire      [31: 0][ 4: 0]     dram_inter_pred_chroma_addr;
wire      [31: 0][ 7: 0]     dram_inter_pred_chroma_din;

reg                          luma_inter_pred_run; //inter和intra可能同时进行中吗,不可能的，pred和rec同时开始，要等上一rec完成的
reg                          cb_inter_pred_run;
reg                          cr_inter_pred_run;

assign dram_pred_we    = luma_inter_pred_run?dram_inter_pred_we:
                         (luma_intra_pred_run?dram_intra_pred_we:64'd0);
assign dram_pred_addrd = luma_inter_pred_run?dram_inter_pred_addr:dram_intra_pred_addr;
assign dram_pred_did   = luma_inter_pred_run?dram_inter_pred_din:dram_intra_pred_din;


assign dram_pred_cb_we    = cb_inter_pred_run?dram_inter_pred_chroma_we:
                             (cb_intra_pred_run?dram_intra_pred_chroma_we:32'd0);
assign dram_pred_cr_we    = cr_inter_pred_run?dram_inter_pred_chroma_we:
                             (cr_intra_pred_run?dram_intra_pred_chroma_we:32'd0);

assign dram_pred_cb_addrd = cb_inter_pred_run?dram_inter_pred_chroma_addr:dram_intra_pred_chroma_addr;
assign dram_pred_cr_addrd = cr_inter_pred_run?dram_inter_pred_chroma_addr:dram_intra_pred_chroma_addr;

assign dram_pred_cb_did   = cb_inter_pred_run?dram_inter_pred_chroma_din:dram_intra_pred_chroma_din;
assign dram_pred_cr_did   = cr_inter_pred_run?dram_inter_pred_chroma_din:dram_intra_pred_chroma_din;



reg  [3:0]               col_pic_dpb_slot;
reg  [14:0]              cur_poc_diff;
reg  [`max_poc_bits-1:0] col_pic_poc;

always @ (posedge clk)
begin
    col_pic_dpb_slot <= i_ref_dpb_slots[i_col_ref_idx];
    cur_poc_diff     <= merge_flag?i_delta_poc[0]:i_delta_poc[ref_idx_l0];
    col_pic_poc      <= i_cur_poc-i_delta_poc[i_col_ref_idx];
end


reg      [ 1:0]      inter_pred_part_idx;
reg                  rst_inter_pred_luma;
reg                  rst_inter_pred_chroma;
reg      [ 2:0]      part_num_save;
reg                  pred_mode_save; //等于上面的pred_mode_cur_rec
reg      [ 2:0]      inter_pred_stage;
wire                 inter_pred_luma_done_w;
wire                 inter_pred_chroma_done;
reg      [ 1:0]      inter_pred_cidx;
reg      [31:0]      ref_ddr_base_luma;
reg      [31:0]      ref_ddr_base_cb;
reg      [31:0]      ref_ddr_base_cr;

wire                 m_axi_arvalid_mv;
wire     [ 3:0]      m_axi_arlen_mv;
wire     [31:0]      m_axi_araddr_mv;
wire                 m_axi_rready_mv;

wire                 m_axi_arvalid_inter;
wire     [ 3:0]      m_axi_arlen_inter;
wire     [31:0]      m_axi_araddr_inter;
reg                  m_axi_rready_inter;


wire     [6:0]       inter_pred_luma_done_y;
wire     [5:0]       inter_pred_chroma_done_y;

assign m_axi_arvalid = ~col_param_fetch_done?m_axi_arvalid_mv:
                                   m_axi_arvalid_inter;
assign m_axi_arlen   = ~col_param_fetch_done?m_axi_arlen_mv:
                                   m_axi_arlen_inter;
assign m_axi_araddr  = ~col_param_fetch_done?m_axi_araddr_mv:
                                   m_axi_araddr_inter;
assign m_axi_rready  = ~col_param_fetch_done?m_axi_rready_mv:
                                   m_axi_rready_inter;

wire      [1:0]      inter_pred_part_idx_tmp;
assign inter_pred_part_idx_tmp = o_cu_state == `cu_pass2tu&&first_tu_in_cu?0:inter_pred_part_idx;

(*mark_debug="true"*)
reg                                  fifo_wr_en            ;
(*mark_debug="true"*)
wire                                 fifo_full             ;
(*mark_debug="true"*)
reg                    [63:0]        fifo_wr_data          ;
(*mark_debug="true"*)
wire                   [63:0]        fifo_rd_data          ;
(*mark_debug="true"*)
wire                                 fifo_empty            ;
(*mark_debug="true"*)
wire                                 fifo_rd_en_luma       ;
(*mark_debug="true"*)
wire                                 fifo_rd_en_chroma     ;

(* KEEP_HIERARCHY  = "TRUE" *)
dp_fifo inter_ref_fifo_inst
(
    .aclr(rst_inter_pred_luma),

    .clk(clk),
    .wr(fifo_wr_en),
    .wr_data(fifo_wr_data),
    .wr_full(fifo_full),

    .rd(fifo_rd_en_luma|fifo_rd_en_chroma),
    .rd_data(fifo_rd_data),
    .words_avail(),
    .rd_empty(fifo_empty)
);



wire      [`max_y_bits-1:0]      ref_start_y;
wire      [`max_y_bits-1:0]      ref_end_y;
wire      [`max_x_bits-1:0]      ref_start_x;
wire      [`max_x_bits-1:0]      ref_end_x;
reg       [`max_x_bits-1:0]      ref_y;

wire      [`max_y_bits-2:0]      c_ref_start_y;
wire      [`max_y_bits-2:0]      c_ref_end_y;
wire      [`max_x_bits-2:0]      c_ref_start_x;
wire      [`max_x_bits-2:0]      c_ref_end_x;
reg       [`max_x_bits-2:0]      c_ref_y;



reg                   [2:0]      ref_fetch_stage;
reg                              ref_luma_fetch_done;
reg                              ref_cb_fetch_done;
reg                              ref_cr_fetch_done;

wire                 [23:0]      pic_addr_off;
wire                 [ 3:0]      pic_addr_mid;
assign pic_addr_mid = ref_cb_fetch_done?ref_ddr_base_cr[23:20]+pic_addr_off[23:20]:
                                         ref_ddr_base_cb[23:20]+pic_addr_off[23:20];
assign pic_addr_off = {c_ref_y,c_ref_start_x[`max_x_bits-2:3],3'd0};

assign m_axi_arvalid_inter = ref_fetch_stage==2?1:0;
assign m_axi_araddr_inter = ~ref_luma_fetch_done?
                           {ref_ddr_base_luma[31:24],ref_y,ref_start_x[`max_x_bits-1:3],3'd0}:
                           (~ref_cb_fetch_done?{ref_ddr_base_cb[31:24],pic_addr_mid,pic_addr_off[19:0]}:
                           {ref_ddr_base_cr[31:24],pic_addr_mid,pic_addr_off[19:0]});
assign m_axi_arlen_inter = ref_luma_fetch_done?c_ref_end_x[`max_x_bits-2:3]-c_ref_start_x[`max_x_bits-2:3]:
                                               ref_end_x[`max_x_bits-1:3]-ref_start_x[`max_x_bits-1:3];


always @ (posedge clk)
if (global_rst||i_rst_slice) begin
    ref_fetch_stage               <= 3;
end else if (rst_inter_pred_luma) begin
    ref_fetch_stage               <= 0;
    ref_luma_fetch_done           <= 0;
    ref_cb_fetch_done             <= 0;
    ref_cr_fetch_done             <= 0;
end else begin
    if (ref_fetch_stage==0) begin
        ref_fetch_stage           <= 1; //等待ref_start_y等就绪
    end

    if (ref_fetch_stage==1) begin
        ref_y                     <= ref_start_y;
        c_ref_y                   <= c_ref_start_y;
        ref_fetch_stage           <= 2;

    end

    if (ref_fetch_stage==2) begin

        //ref_end_x=24(11,000),ref_start_x=5 (32-0)/8, 2'b11+1-0
        //ref_end_x=23(10,111),ref_start_x=5 (24-0)/8, 2'b10+1-0
        //ref_end_x[`max_x_bits-1:3]-ref_start_x[`max_x_bits-1:3]+1-1

        if (m_axi_arready) begin
            if (~ref_luma_fetch_done) begin
                ref_y                       <= ref_y+1;
                if (ref_y==ref_end_y)
                    ref_luma_fetch_done     <= 1;
            end else begin
                c_ref_y                     <= c_ref_y+1;
                if (c_ref_y==c_ref_end_y) begin
                    c_ref_y                 <= c_ref_start_y;
                    if (~ref_cb_fetch_done) begin
                        ref_cb_fetch_done   <= 1;
                    end else begin
                        ref_cr_fetch_done   <= 1;
                        ref_fetch_stage     <= 3;
                    end
                end
            end

        end
    end

end


always @ (posedge clk)
if (global_rst||i_rst_slice) begin
    m_axi_rready_inter <= 0;
end else if (rst_inter_pred_luma) begin
    m_axi_rready_inter <= 1;
end else begin
    if (m_axi_rvalid) begin
        fifo_wr_data   <= m_axi_rdata;
        fifo_wr_en     <= 1;
    end else begin
        fifo_wr_en     <= 0;
    end
    if (fifo_full)
        $display("%t possible? fifo full", $time);
end


always @ (posedge clk)
if (global_rst||i_rst_slice) begin
    inter_pred_luma_done                <= 1;
    inter_pred_cb_done                  <= 1;
    inter_pred_cr_done                  <= 1;
    inter_pred_done                     <= 1;
    rst_inter_pred_luma                 <= 0;
    rst_inter_pred_chroma               <= 0;
end else if (i_rst_ctb) begin
    inter_pred_part_idx                 <= 0;
    rst_inter_pred_luma                 <= 0;
    rst_inter_pred_chroma               <= 0;
    inter_pred_stage                    <= 0;
    inter_pred_cidx                     <= 0;
    luma_inter_pred_run                 <= 0;
    cb_inter_pred_run                   <= 0;
    cr_inter_pred_run                   <= 0;

end else begin
    //stage=0,拉高reset，
    //stage=1,拉低reset，
    //stage=2，等待inter pred结束
    //o_cu_state == `cu_pass2tu&&first_tu_in_cu第一次触发，可以从inter_pred_stage=3启动

    if (pred_mode==`MODE_INTER&&
        o_cu_state == `cu_pass2tu&&
        first_tu_in_cu) begin
        inter_pred_part_idx             <= 0;
        inter_pred_done                 <= 0;
        inter_pred_luma_done            <= 0;
        inter_pred_cb_done              <= 0;
        inter_pred_cr_done              <= 0;
        part_num_save                   <= part_num;
        pred_mode_save                  <= pred_mode;
    end

    if (inter_pred_cidx==0&&
        ((pred_mode==`MODE_INTER&&o_cu_state == `cu_pass2tu&&first_tu_in_cu)||
        (pred_mode_save==`MODE_INTER&&
         inter_pred_part_idx>0&&
         inter_pred_stage==0&&
         ~rst_inter_pred_luma&&
         ~inter_pred_done))) begin
        rst_inter_pred_luma              <= 1;
        luma_inter_pred_run              <= 1;
        inter_pred_stage                 <= 1;
        //inter_pred_part_idx还没改过来
        case(i_ref_dpb_slots[pu_info.mvf[inter_pred_part_idx_tmp].refIdx])
            0: ref_ddr_base_luma         <= `DDR_BASE_DPB0;
            1: ref_ddr_base_luma         <= `DDR_BASE_DPB1;
            2: ref_ddr_base_luma         <= `DDR_BASE_DPB2;
            3: ref_ddr_base_luma         <= `DDR_BASE_DPB3;
            4: ref_ddr_base_luma         <= `DDR_BASE_DPB4;
            default: ref_ddr_base_luma   <= `DDR_BASE_DPB5;
        endcase
        case(i_ref_dpb_slots[pu_info.mvf[inter_pred_part_idx_tmp].refIdx])
            0: ref_ddr_base_cb           <= `DDR_BASE_DPB0+`CB_OFFSET;
            1: ref_ddr_base_cb           <= `DDR_BASE_DPB1+`CB_OFFSET;
            2: ref_ddr_base_cb           <= `DDR_BASE_DPB2+`CB_OFFSET;
            3: ref_ddr_base_cb           <= `DDR_BASE_DPB3+`CB_OFFSET;
            4: ref_ddr_base_cb           <= `DDR_BASE_DPB4+`CB_OFFSET;
            default: ref_ddr_base_cb     <= `DDR_BASE_DPB5+`CB_OFFSET;
        endcase

        case(i_ref_dpb_slots[pu_info.mvf[inter_pred_part_idx_tmp].refIdx])
            0: ref_ddr_base_cr           <= `DDR_BASE_DPB0+`CR_OFFSET;
            1: ref_ddr_base_cr           <= `DDR_BASE_DPB1+`CR_OFFSET;
            2: ref_ddr_base_cr           <= `DDR_BASE_DPB2+`CR_OFFSET;
            3: ref_ddr_base_cr           <= `DDR_BASE_DPB3+`CR_OFFSET;
            4: ref_ddr_base_cr           <= `DDR_BASE_DPB4+`CR_OFFSET;
            default: ref_ddr_base_cr     <= `DDR_BASE_DPB5+`CR_OFFSET;
        endcase

    end

    //这里不再需要判断pred_mode_cur_rec==`MODE_INTER,
    //第一次启动之后，后面一个一个color component，一个一个partIdx都要完成
    if(inter_pred_stage==0&&
        (inter_pred_cidx==1||inter_pred_cidx==2)) begin
        rst_inter_pred_chroma            <= 1;
        if (inter_pred_cidx==1)
            cb_inter_pred_run            <= 1;
        else
            cr_inter_pred_run            <= 1;
        inter_pred_stage                 <= 1;

    end

    if (inter_pred_stage == 1) begin
        rst_inter_pred_luma              <= 0;
        rst_inter_pred_chroma            <= 0;
        inter_pred_stage                 <= 2;
    end

    if (inter_pred_stage == 2) begin
        if (inter_pred_cidx==0&&inter_pred_luma_done_w) begin
            inter_pred_cidx              <= 1;
            //所有part idx解完才done,
            //inter_pred_luma_done,inter_pred_cb_done,inter_pred_cr_done暂时没有用到
            if (inter_pred_part_idx==part_num_save-1)
                inter_pred_luma_done     <= 1;
            luma_inter_pred_run          <= 0;
            inter_pred_stage             <= 0;
        end else if (inter_pred_cidx==1&&inter_pred_chroma_done) begin
            inter_pred_cidx              <= 2;
            if (inter_pred_part_idx==part_num_save-1)
                inter_pred_cb_done       <= 1;
            cb_inter_pred_run            <= 0;
            inter_pred_stage             <= 0;
        end else if (inter_pred_cidx==2&&inter_pred_chroma_done) begin
            cr_inter_pred_run            <= 0;
            inter_pred_cidx              <= 0;
            if (inter_pred_part_idx==part_num_save-1) begin
                inter_pred_stage         <= 3; //end
                inter_pred_done          <= 1;
                inter_pred_cr_done       <= 1;
            end else begin
                inter_pred_part_idx      <= inter_pred_part_idx+1;
                inter_pred_stage         <= 0;
            end

        end
    end

end



inter_pred_luma inter_pred_luma_inst
(
    .clk                      (clk),
    .rst                      (rst_inter_pred_luma),
    .global_rst               (global_rst),
    .i_rst_slice              (i_rst_slice),
    .en                       (1'b1),
    .i_slice_num              (i_slice_num),
    .i_x0                     (pu_info.x0),
    .i_y0                     (pu_info.y0),
    .i_CbSize                 (pu_info.CbSize),
    .i_xPb                    (pu_info.xPb[inter_pred_part_idx]),
    .i_yPb                    (pu_info.yPb[inter_pred_part_idx]),
    .i_PicWidthInSamplesY     (i_PicWidthInSamplesY),
    .i_PicHeightInSamplesY    (i_PicHeightInSamplesY),

    .i_nPbW                   (pu_info.nPbW[inter_pred_part_idx]),
    .i_nPbH                   (pu_info.nPbH[inter_pred_part_idx]),
    .i_mvx                    (pu_info.mvf[inter_pred_part_idx].mv.mv[0]),
    .i_mvy                    (pu_info.mvf[inter_pred_part_idx].mv.mv[1]),
    .i_component              (1'b0), //0=cb,1=cr

    .o_fifo_rd_en             (fifo_rd_en_luma),
    .i_fifo_data              (fifo_rd_data),
    .i_fifo_empty             (fifo_empty),

    .dram_pred_we             (dram_inter_pred_we),
    .dram_pred_addrd          (dram_inter_pred_addr),
    .dram_pred_did            (dram_inter_pred_din),

    .fd_log                   (fd_pred),
    .o_pred_done_y            (inter_pred_luma_done_y),
    .o_ref_start_y            (ref_start_y),
    .o_ref_end_y              (ref_end_y),
    .o_ref_start_x            (ref_start_x),
    .o_ref_end_x              (ref_end_x),
    .o_inter_pred_done        (inter_pred_luma_done_w)

);

inter_pred_chroma inter_pred_chroma_inst
(
    .clk                      (clk),
    .rst_luma                 (rst_inter_pred_luma),
    .rst                      (rst_inter_pred_chroma),
    .global_rst               (global_rst),
    .i_rst_slice              (i_rst_slice),
    .en                       (1'b1),
    .i_slice_num              (i_slice_num),
    .i_x0                     (pu_info.x0),
    .i_y0                     (pu_info.y0),
    .i_CbSize                 (pu_info.CbSize),
    .i_xPb                    (pu_info.xPb[inter_pred_part_idx]),
    .i_yPb                    (pu_info.yPb[inter_pred_part_idx]),
    .i_PicWidthInSamplesY     (i_PicWidthInSamplesY),
    .i_PicHeightInSamplesY    (i_PicHeightInSamplesY),

    .i_nPbW                   (pu_info.nPbW[inter_pred_part_idx]),
    .i_nPbH                   (pu_info.nPbH[inter_pred_part_idx]),
    .i_mvx                    (pu_info.mvf[inter_pred_part_idx].mv.mv[0]),
    .i_mvy                    (pu_info.mvf[inter_pred_part_idx].mv.mv[1]),
    .i_component              (1'b0), //0=cb,1=cr

    .o_fifo_rd_en             (fifo_rd_en_chroma),
    .i_fifo_data              (fifo_rd_data),
    .i_fifo_empty             (fifo_empty),

    .dram_pred_we             (dram_inter_pred_chroma_we),
    .dram_pred_addrd          (dram_inter_pred_chroma_addr),
    .dram_pred_did            (dram_inter_pred_chroma_din),

    .fd_log                   (fd_pred),
    .o_pred_done_y            (inter_pred_chroma_done_y),
    .o_ref_start_y            (c_ref_start_y),
    .o_ref_end_y              (c_ref_end_y),
    .o_ref_start_x            (c_ref_start_x),
    .o_ref_end_x              (c_ref_end_x),
    .o_inter_pred_done        (inter_pred_chroma_done)

);


mv mv_inst
(
   .clk                               (clk),
   .rst                               (reset_mv),
   .global_rst                        (global_rst),
   .i_rst_ctb                         (i_rst_ctb),
   .en                                (1'b1),

   .i_x0                              (i_x0), //i_rst_ctb用到i_x0而不是x0
   .i_y0                              (i_y0),
   .i_xPb                             (xPb),
   .i_yPb                             (yPb),
   .i_last_col                        (i_last_col),
   .i_last_row                        (i_last_row),
   .i_first_col                       (i_first_col),
   .i_first_row                       (i_first_row),
   .i_last_col_width                  (i_last_col_width),
   .i_last_row_height                 (i_last_row_height),
   .fd_log                            (fd_log),
   .i_nPbW                            (nPbW),
   .i_nPbH                            (nPbH),
   .i_log2_parallel_merge_level       (i_log2_parallel_merge_level),
   .i_partIdx                         (partIdx),
   .i_part_mode                       (part_mode),
   .i_slice_temporal_mvp_enabled_flag (i_slice_temporal_mvp_enabled_flag),
   .i_num_ref_idx                     (i_num_ref_idx), //slice_header

   .i_slice_num                       (i_slice_num),
   .i_slice_type                      (i_slice_type),

   .i_left_mvf                        (left_mvf),
   .i_up_mvf                          (up_mvf),
   .i_left_up_mvf                     (left_up_mvf),

   .i_predmode_leftup                 (cu_predmode_leftup_init1),
   .i_predmode                        (pred_mode), //当前cu的cu_predmode
   .i_predmode_left                   (cu_predmode_left_init1),
   .i_predmode_up                     (cu_predmode_up_init1),
   .i_col_pic_dpb_slot                (col_pic_dpb_slot),
   .i_cur_poc_diff                    (cur_poc_diff),
   .i_col_pic_poc                     (col_pic_poc),
   .i_ref_idx                         (ref_idx_l0),
   .i_delta_poc                       (i_delta_poc),
   .i_merge_flag                      (merge_flag),
   .i_mvp_l0_flag                     (mvp_l0_flag),
   .i_merge_idx                       (merge_idx),

   .m_axi_arready                     (m_axi_arready),
   .m_axi_arvalid                     (m_axi_arvalid_mv),
   .m_axi_arlen                       (m_axi_arlen_mv),
   .m_axi_araddr                      (m_axi_araddr_mv),
   .m_axi_rready                      (m_axi_rready_mv),
   .m_axi_rdata                       (m_axi_rdata),
   .m_axi_rvalid                      (m_axi_rvalid),
   .m_axi_rlast                       (m_axi_rlast),

   .o_mvf                             (pu_mvf_w),
   .o_col_param_fetch_done            (col_param_fetch_done),
   .o_mv_done                         (mv_done)
);




//============================================ RECONSTRUCTION ================================================//
reg               [5:0]     rec_x_right_most;
reg               [5:0]     rec_start_y;
reg               [5:0]     rec_start_x;
reg               [4:0]     rec_cb_x_right_most;
reg               [4:0]     rec_cr_x_right_most;
reg               [4:0]     rec_cb_start_y;
reg               [4:0]     rec_cb_start_x;

wire              [5:0]     tq_luma_end_x;
wire              [4:0]     tq_cb_end_x;
wire              [4:0]     tq_cr_end_x;
wire              [4:0]     tq_cb_start_x; //tq_cb输出
wire              [4:0]     tq_cb_start_y;
wire              [4:0]     tq_cr_start_x; //tq_cr输出
wire              [4:0]     tq_cr_start_y;

wire signed       [6:0]     tq_luma_done_y_w; //transquant output
wire signed       [5:0]     tq_cb_done_y_w;
wire signed       [5:0]     tq_cr_done_y_w;
reg  signed       [6:0]     tq_luma_done_y;
reg  signed       [5:0]     tq_cb_done_y;
reg  signed       [5:0]     tq_cr_done_y;

reg signed        [6:0]     pred_luma_done_y;
reg signed        [5:0]     pred_cb_done_y;
reg signed        [5:0]     pred_cr_done_y;


//intra pred,`cu_pass2tu时，上一tu的luma，cb重建完成，因为下一tu的luma，cb intra pred要开始，要依赖上一tu的rec结果，
//cr的intra pred完成，tq和重建拖到cb intra pred完成，cr intra pred开始时，
//为什么cr的intra pred完成，因为cb，cr的intra pred共用一个instance，
//上一为inter pred，也是一样，等到上一cu的luma，cb rec完成，
//inter pred，顺序：partIdx0的luma，cb，cr，partIdx1的luma，cb，cr，...
//当前cu的第一次`update_mvf_nb时上一cu的luma rec完成，为什么要rec完成，tq不能往后拖，因为启动新的luma rec，rec_start_y等变量要更新，
//cb，cr的inter pred必须完成，rec可以正在进行，tq可以还在进行，

//当前cu启动第一个partIdx的pu的cb的inter pred时，上一cu的cb rec完成，也就是第一个partIdx的luma inter pred完成时，inter pred是一个接一个进行，不能并行的
//cr类似，上一为intra pred也一样

//本播luma rec的pred_mode,如果rec过程中pred或者tq延续到了下一个cu，pred_mode可能不是本次rec的pred_mode,
//因为只需保证下次`cu_pass2tu时，rec完成就可以了，而pred_mode在`tu_end到`cu_pass2tu之间改变，
//需要在luma rec开始时记录本次luma rec的pred_mode,

//上面2条都不需要了，改成当前cu的第一次`update_mvf_nb等待上一cu rec完成

always @(posedge clk)
if (i_rst_ctb||i_rst_slice) begin
    pred_luma_done_y              <= -1;
end else begin
    //rec启动时要清-1
    if (o_cu_state == `cu_pass2tu && pred_mode==`MODE_INTRA&&
         rec_done_luma&&rec_done_cb&&intra_pred_cr_done&&inter_pred_done) //mark5
        pred_luma_done_y          <= -1;
    else if (o_cu_state == `cu_pass2tu && pred_mode==`MODE_INTER&&
             first_tu_in_cu)
        pred_luma_done_y          <= -1;
    else if (luma_intra_pred_run&&~rst_intra_pred_luma)
        pred_luma_done_y          <= intra_pred_luma_done_y;
    else if (luma_inter_pred_run&&~rst_inter_pred_luma)
        pred_luma_done_y          <= inter_pred_luma_done_y;
end

always @(posedge clk)
if (i_rst_ctb||i_rst_slice) begin
    pred_cb_done_y                <= -1;
end else begin
    if (o_cu_state == `cu_pass2tu && pred_mode==`MODE_INTRA&&
         rec_done_luma&&rec_done_cb&&intra_pred_cr_done&&inter_pred_done)//mark6
        pred_cb_done_y            <= -1;
    else if (o_cu_state == `cu_pass2tu && pred_mode==`MODE_INTER&&
             first_tu_in_cu)
        pred_cb_done_y            <= -1;
    else if (cb_inter_pred_run&&~rst_inter_pred_chroma)
        pred_cb_done_y            <= inter_pred_chroma_done_y;
    else if (cb_intra_pred_run&~rst_intra_pred_cb)
        pred_cb_done_y            <= intra_pred_chroma_done_y;
end

always @(posedge clk)
if (i_rst_ctb||i_rst_slice) begin
    pred_cr_done_y                <= -1;
end else begin
    if (o_cu_state == `cu_pass2tu && pred_mode==`MODE_INTER&&
         first_tu_in_cu)
        pred_cr_done_y            <= -1;
    else if (rst_intra_pred_cr)
        pred_cr_done_y            <= -1;
    else if (cr_inter_pred_run&&~rst_inter_pred_chroma)
        pred_cr_done_y            <= inter_pred_chroma_done_y;
    else if (cr_intra_pred_run&&~rst_intra_pred_cr)
        pred_cr_done_y            <= intra_pred_chroma_done_y;
end

always @(posedge clk)
if (i_rst_ctb||i_rst_slice) begin
    tq_luma_done_y              <= -1;
end else begin
    //rec启动时要清-1
    if (o_cu_state == `cu_pass2tu && pred_mode==`MODE_INTRA&&
         rec_done_luma&&rec_done_cb&&intra_pred_cr_done&&inter_pred_done)//mark7
        tq_luma_done_y          <= -1;
    else if (o_cu_state == `cu_pass2tu && pred_mode==`MODE_INTER&&
             first_tu_in_cu)
        tq_luma_done_y          <= -1;
    else if (tq_luma_state != `trans_quant_end) //mark3
        tq_luma_done_y          <= tq_luma_done_y_w;

end

always @(posedge clk)
if (i_rst_ctb||i_rst_slice) begin
    tq_cb_done_y                <= -1;
end else begin
    if (o_cu_state == `cu_pass2tu && pred_mode==`MODE_INTRA&&
         rec_done_luma&&rec_done_cb&&intra_pred_cr_done&&inter_pred_done)//mark8
        tq_cb_done_y            <= -1;
    else if (o_cu_state == `cu_pass2tu && pred_mode==`MODE_INTER&&
             first_tu_in_cu)
        tq_cb_done_y            <= -1;
    else if (tq_cb_state != `trans_quant_end)
        tq_cb_done_y            <= tq_cb_done_y_w;

end

always @(posedge clk)
if (i_rst_ctb||i_rst_slice) begin
    tq_cr_done_y                <= -1;
end else begin
    if (o_cu_state == `cu_pass2tu && pred_mode==`MODE_INTER&&
         first_tu_in_cu)
        tq_cr_done_y            <= -1;
    else if (rst_intra_pred_cr)
        //cr重建开始rst_intra_pred_cr时，cr的transquant在cr intra pred开始前就可能已经完成了，
        //如果tq正在进行的tu是正在rec的tu，而不是上一tu，就不能置tq_cr_done_y为-1
        if (tq_cr_start_x==rec_cb_start_x&&
            tq_cr_start_y==rec_cb_start_y)
            tq_cr_done_y        <= tq_cr_done_y_w;
        else
            tq_cr_done_y        <= -1;
    else if (tq_cr_state != `trans_quant_end)
        tq_cr_done_y            <= tq_cr_done_y_w;

end

reg         [63:0]           dram_rec_dec_we;
reg         [63:0][ 5:0]     dram_rec_dec_addrd;
reg         [63:0][ 7:0]     dram_rec_dec_did;
reg         [31:0]           dram_rec_cb_dec_we;
reg         [31:0][ 4:0]     dram_rec_cb_dec_addrd;
reg         [31:0][ 7:0]     dram_rec_cb_dec_did;
reg         [31:0]           dram_rec_cr_dec_we;
reg         [31:0][ 4:0]     dram_rec_cr_dec_addrd;
reg         [31:0][ 7:0]     dram_rec_cr_dec_did;



reg               [ 5:0]     rec_x;
reg  signed       [ 6:0]     rec_y;
reg  signed       [ 6:0]     rec_y_pls1;
reg               [ 5:0]     rec_end_y;
reg               [ 6:0]     rec_width; //inter=CbSize,intra=trafoSize
reg               [ 3:0]     rec_stage;

wire signed [63:0][ 9:0]     rec_one_row_w;
reg  signed [63:0][ 9:0]     rec_one_row;
wire        [63:0][ 7:0]     rec_one_row_clip_w;
reg         [63:0][ 7:0]     rec_one_row_clip;
reg               [ 7:0]     rec_one_row_right_most;
reg               [ 7:0]     rec_pixel_right_most;
reg         [63:0][ 7:0]     line_buf_top_luma_w;


generate
    for (I=0;I<64;I++)
    begin: rec_one_row_label
        assign rec_one_row_w[I] = dram_tq_doa[I]+dram_pred_doa[I];
    end
endgenerate

generate
    for (I=0;I<64;I++)
    begin: rec_one_row_clip_label
        assign rec_one_row_clip_w[I] = rec_one_row[I][9]?0:(rec_one_row[I][8]?255:rec_one_row[I][7:0]);
    end
endgenerate


generate
    for (I=0;I<16;I++)
    begin: line_buf_top_label
        always @(*)
        begin
            if (I>=rec_x[5:2] && I<rec_x[5:2]+rec_width[6:2]) begin
                line_buf_top_luma_w[4*I+3:4*I]         = rec_one_row_clip[4*I+3:4*I];
            end else begin
                line_buf_top_luma_w[4*I+3:4*I]         = line_buf_top_luma[4*I+3:4*I];
            end
        end
    end
endgenerate

reg   [7:0]         leftup_use_top;        //情况1
reg   [7:0]         leftup_use_right_most; //情况2
//leftup 16个点，不是64个，y方向每4x4一个
//         0,  1,  4,  5,
//         2,  3,  6,  7,
//         8,  9, 12, 13,
//        10, 11, 14, 15,
//        32, 33, 36, 37,
//解当前块8x8，占8，9，10，11这4小块，
//情况1，更新leftup[2]=3,即top[1],
//情况2，更新leftup[3]=9



//这个line buf是不经过filter的
reg                     bram_up_line_we;
reg  [`max_x_bits-3:0]  bram_up_line_addr;
reg  [31:0]             bram_up_line_din;
wire [31:0]             bram_up_line_dout;
reg                     up_line_store_done;
reg  [`max_x_bits-3:0]  up_line_fetch_addr;
reg  [`max_x_bits-3:0]  up_line_store_addr;
reg  [ 4:0]             up_line_fetch_i;
reg  [ 3:0]             up_line_store_i;

ram #(`max_x_bits-2, 32) bram_up_line
(
    .clk(clk),
    .en(1'b1),
    .we(bram_up_line_we),
    .addr(bram_up_line_addr),
    .data_in(bram_up_line_din),
    .data_out(bram_up_line_dout)
);


reg                        bram_cb_up_line_we;
reg     [`max_x_bits-4:0]  bram_cb_up_line_addr;
reg     [31:0]             bram_cb_up_line_din;
wire    [31:0]             bram_cb_up_line_dout;
reg                        up_line_cb_store_done;
reg     [`max_x_bits-4:0]  up_line_cb_fetch_addr;
reg     [`max_x_bits-4:0]  up_line_cb_store_addr;
reg     [ 3:0]             up_line_cb_fetch_i;
reg     [ 2:0]             up_line_cb_store_i;

ram #(`max_x_bits-3, 32) bram_cb_up_line
(
    .clk(clk),
    .en(1'b1),
    .we(bram_cb_up_line_we),
    .addr(bram_cb_up_line_addr),
    .data_in(bram_cb_up_line_din),
    .data_out(bram_cb_up_line_dout)
);


reg                        bram_cr_up_line_we;
reg     [`max_x_bits-4:0]  bram_cr_up_line_addr;
reg     [31:0]             bram_cr_up_line_din;
wire    [31:0]             bram_cr_up_line_dout;
reg                        up_line_cr_store_done;
reg     [`max_x_bits-4:0]  up_line_cr_fetch_addr;
reg     [`max_x_bits-4:0]  up_line_cr_store_addr;
reg     [ 3:0]             up_line_cr_fetch_i;
reg     [ 2:0]             up_line_cr_store_i;
ram #(`max_x_bits-3, 32) bram_cr_up_line
(
    .clk(clk),
    .en(1'b1),
    .we(bram_cr_up_line_we),
    .addr(bram_cr_up_line_addr),
    .data_in(bram_cr_up_line_din),
    .data_out(bram_cr_up_line_dout)
);



reg          ctb_luma_rec_done;
always @(posedge clk)
if (i_rst_ctb||i_rst_slice) begin
    ctb_luma_rec_done       <= 0;
end else begin
    if (rec_done_luma&&
        ((last_row&&rec_y==last_row_height)||rec_y==7'b1000000)&&
        ((last_col&&rec_x_right_most==last_col_width-1)||rec_x_right_most==63))
        ctb_luma_rec_done   <= 1;
end


always @(posedge clk)
if (global_rst) begin
    rec_done_luma                           <= 1;
end else if (i_rst_slice) begin
    rec_x                                   <= 0;
    rec_y                                   <= 0;
    rec_y_pls1                              <= 1;
    dram_rec_dec_we                         <= 64'd0;
end else if (i_rst_ctb) begin
    rec_done_luma                           <= 1;
    rec_x                                   <= 0;
    rec_y                                   <= 0;
    rec_y_pls1                              <= 1;
    up_line_fetch_addr                      <= i_x0[`max_x_bits-1:2];
    up_line_store_addr                      <= i_x0[`max_x_bits-1:2];
    up_line_store_i                         <= 0;
    up_line_fetch_i                         <= 0;
    up_line_store_done                      <= 0;
    if (i_first_row) begin
        up_line_fetch_done                  <= 1;
    end else begin
        rec_stage                           <= 4;
        up_line_fetch_done                  <= 0;
    end
end else begin
    if (rec_stage == 4) begin
        bram_up_line_we                     <= 0;
        bram_up_line_addr                   <= up_line_fetch_addr;
        up_line_fetch_addr                  <= up_line_fetch_addr+1;
        rec_stage                           <= 5;
    end
    if (rec_stage == 5) begin
        bram_up_line_addr                   <= up_line_fetch_addr;
        up_line_fetch_addr                  <= up_line_fetch_addr+1;
        rec_stage                           <= 6;
    end
    if (rec_stage == 6) begin
        bram_up_line_addr                   <= up_line_fetch_addr;
        up_line_fetch_addr                  <= up_line_fetch_addr+1;
        line_buf_top_luma                   <= {bram_up_line_dout,line_buf_top_luma[95:4]};
        up_line_fetch_i                     <= up_line_fetch_i+1;
        if (up_line_fetch_i==23) begin
            rec_stage                       <= 7;
            up_line_fetch_done              <= 1;
        end
    end
    //rec完后启动存储上面一行到bram，
    if (ctb_luma_rec_done&&rec_stage !=9) begin
        if (last_row) begin
            up_line_store_done              <= 1;
        end else begin
            up_line_store_done              <= 0;
            rec_stage                       <= 8;
        end
    end
    if (rec_stage == 8) begin
        bram_up_line_we                     <= 1;
        bram_up_line_addr                   <= up_line_store_addr;
        up_line_store_addr                  <= up_line_store_addr+1;
        bram_up_line_din                    <= line_buf_top_luma[3:0];
        line_buf_top_luma[63:0]             <= {32'd0,line_buf_top_luma[63:4]};
        up_line_store_i                     <= up_line_store_i+1;
        if (up_line_store_i==15) begin
            up_line_store_done              <= 1;
            rec_stage                       <= 9;
        end
    end
    if (rec_stage == 9) begin
        bram_up_line_we                     <= 0;
    end

    if (o_cu_state == `cu_pass2tu && pred_mode==`MODE_INTER&&
        first_tu_in_cu) begin
        rec_x                               <= x0[5:0];
        rec_start_x                         <= x0[5:0];
        rec_y                               <= {1'b0,y0[5:0]};
        rec_y_pls1                          <= y0[5:0]+1;
        dram_tq_addra                       <= {64{y0[5:0]}};
        dram_pred_addra                     <= {64{y0[5:0]}};
        rec_start_y                         <= y0[5:0];
        rec_end_y                           <= y0[5:0]+CbSize-1;
        rec_x_right_most                    <= x0[5:0]+CbSize-1;
        rec_width                           <= CbSize;
        rec_stage                           <= 0;
        rec_done_luma                       <= 0;
        pred_mode_cur_rec                   <= pred_mode;

    end

    if (o_cu_state == `cu_pass2tu && pred_mode==`MODE_INTRA&&
         rec_done_luma&&rec_done_cb&&intra_pred_cr_done&&inter_pred_done) begin//mark9
        rec_x                               <= xTu;
        rec_y                               <= {1'b0,yTu};
        rec_y_pls1                          <= yTu+1;
        dram_tq_addra                       <= {64{yTu}};
        dram_pred_addra                     <= {64{yTu}};
        rec_start_y                         <= yTu;
        rec_end_y                           <= yTu+trafoSize-1;
        rec_x_right_most                    <= xTu+trafoSize-1;
        rec_stage                           <= 0;
        rec_done_luma                       <= 0;
        rec_width                           <= trafoSize;
        pred_mode_cur_rec                   <= pred_mode;
    end

    //从下面mark6提上来
    rec_one_row                              <= rec_one_row_w;
    if (rec_stage==0&&
        rec_y<=pred_luma_done_y&&
        rec_y<=tq_luma_done_y&&rec_y!=7'b1000000) begin //rec_y!=64不成立
        //mark6
        rec_stage                            <= 1;
    end

    if (rec_stage == 1) begin
        rec_one_row_clip                     <= rec_one_row_clip_w;
        rec_stage                            <= 2;
    end

    if (rec_stage == 2) begin
        case(rec_x_right_most[5:2])
            0:rec_pixel_right_most           <= rec_one_row_clip[3];
            1:rec_pixel_right_most           <= rec_one_row_clip[7];
            2:rec_pixel_right_most           <= rec_one_row_clip[11];
            3:rec_pixel_right_most           <= rec_one_row_clip[15];
            4:rec_pixel_right_most           <= rec_one_row_clip[19];
            5:rec_pixel_right_most           <= rec_one_row_clip[23];
            6:rec_pixel_right_most           <= rec_one_row_clip[27];
            7:rec_pixel_right_most           <= rec_one_row_clip[31];
            8:rec_pixel_right_most           <= rec_one_row_clip[35];
            9:rec_pixel_right_most           <= rec_one_row_clip[39];
            10:rec_pixel_right_most          <= rec_one_row_clip[43];
            11:rec_pixel_right_most          <= rec_one_row_clip[47];
            12:rec_pixel_right_most          <= rec_one_row_clip[51];
            13:rec_pixel_right_most          <= rec_one_row_clip[55];
            14:rec_pixel_right_most          <= rec_one_row_clip[59];
            15:rec_pixel_right_most          <= rec_one_row_clip[63];
        endcase
        leftup_use_top                       <= line_buf_top_luma[rec_x_right_most];
        leftup_use_right_most                <= rec_pixel_right_most; //上一次记录的right_most

        rec_stage                            <= 3;

    end

    if (rec_stage==3) begin
        case(rec_x[5:2])
            0:dram_rec_dec_we                <= {64{1'd1}};
            1:dram_rec_dec_we                <= {{60{1'd1}},4'd0};
            2:dram_rec_dec_we                <= {{56{1'd1}},8'd0};
            3:dram_rec_dec_we                <= {{52{1'd1}},12'd0};
            4:dram_rec_dec_we                <= {{48{1'd1}},16'd0};
            5:dram_rec_dec_we                <= {{44{1'd1}},20'd0};
            6:dram_rec_dec_we                <= {{40{1'd1}},24'd0};
            7:dram_rec_dec_we                <= {{36{1'd1}},28'd0};
            8:dram_rec_dec_we                <= {{32{1'd1}},32'd0};
            9:dram_rec_dec_we                <= {{28{1'd1}},36'd0};
            10:dram_rec_dec_we               <= {{24{1'd1}},40'd0};
            11:dram_rec_dec_we               <= {{20{1'd1}},44'd0};
            12:dram_rec_dec_we               <= {{16{1'd1}},48'd0};
            13:dram_rec_dec_we               <= {{12{1'd1}},52'd0};
            14:dram_rec_dec_we               <= {{8{1'd1}},56'd0};
            15:dram_rec_dec_we               <= {{4{1'd1}},60'd0};
        endcase

        dram_rec_dec_addrd                   <= {64{rec_y[5:0]}};
        dram_rec_dec_did                     <= rec_one_row_clip;
        line_buf_top_luma[63:0]              <= line_buf_top_luma_w;

        line_buf_left_luma[rec_y[5:0]]       <= rec_pixel_right_most;
        if (rec_y[1:0]==2'd0)
            line_buf_leftup_luma[rec_y[5:2]] <= rec_y[5:0]==rec_start_y?leftup_use_top:leftup_use_right_most;
        rec_y                                <= rec_y_pls1;
        rec_y_pls1                           <= rec_y_pls1+1;
        dram_tq_addra                        <= {64{rec_y_pls1[5:0]}};
        dram_pred_addra                      <= {64{rec_y_pls1[5:0]}};

        if (rec_y[5:0]==rec_end_y) begin
            rec_done_luma                    <= 1;
        end
        rec_stage                            <= 0;
    end

end



reg               [ 4:0]     rec_cb_x;
reg  signed       [ 5:0]     rec_cb_y;
wire signed       [ 5:0]     rec_cb_y_pls1;
reg               [ 4:0]     rec_cb_end_y;
reg               [ 3:0]     rec_cb_stage;
reg               [ 5:0]     rec_cb_width;

assign rec_cb_y_pls1 = rec_cb_y+1;

wire signed [31:0][ 9:0]     rec_cb_one_row_w;
wire        [31:0][ 7:0]     rec_cb_one_row_clip_w;
reg  signed [31:0][ 9:0]     rec_cb_one_row;
reg         [31:0][ 7:0]     rec_cb_one_row_clip;
reg               [ 7:0]     rec_cb_one_row_right_most;
reg               [ 7:0]     rec_cb_pixel_right_most;
reg         [31:0][ 7:0]     line_buf_top_cb_w;


generate
    for (I=0;I<32;I++)
    begin: rec_cb_one_row_label
        assign rec_cb_one_row_w[I] = dram_tq_cb_doa[I]+dram_pred_cb_doa[I];
    end
endgenerate

generate
    for (I=0;I<32;I++)
    begin: rec_cb_one_row_clip_label
        assign rec_cb_one_row_clip_w[I] = rec_cb_one_row[I][9]?0:
                                          (rec_cb_one_row[I][8]?255:rec_cb_one_row[I][7:0]);
    end
endgenerate


generate
    for (I=0;I<8;I++)
    begin: line_buf_cb_top_label
        always @(*)
        begin
            if (I>=rec_cb_x[4:2] && I<rec_cb_x[4:2]+rec_cb_width[5:2]) begin
                line_buf_top_cb_w[4*I+3:4*I]         = rec_cb_one_row_clip[4*I+3:4*I];
            end else begin
                line_buf_top_cb_w[4*I+3:4*I]         = line_buf_top_cb[4*I+3:4*I];
            end
        end
    end
endgenerate


reg          ctb_cb_rec_done;
always @(posedge clk)
if (i_rst_ctb||i_rst_slice) begin
    ctb_cb_rec_done       <= 0;
end else begin
    if (rec_done_cb&&
        ((last_row&&rec_cb_y==last_row_height[6:1])||rec_cb_y==6'b100000)&&
        ((last_col&&rec_cb_x_right_most==last_col_width[6:1]-1)||rec_cb_x_right_most==31))
        ctb_cb_rec_done   <= 1;
end


reg   [7:0]         cb_leftup_use_top;
reg   [7:0]         cb_leftup_use_right_most;

always @(posedge clk)
if (global_rst) begin
    rec_done_cb                               <= 1;
end else if (i_rst_slice) begin
    rec_cb_x                                  <= 0;
    rec_cb_y                                  <= 0;
    dram_rec_cb_dec_we                        <= 32'd0;
end else if (i_rst_ctb) begin
    rec_done_cb                               <= 1;
    rec_cb_x                                  <= 0;
    rec_cb_y                                  <= 0;
    up_line_cb_fetch_addr                     <= i_x0[`max_x_bits-1:3];
    up_line_cb_store_addr                     <= i_x0[`max_x_bits-1:3];
    up_line_cb_store_i                        <= 0;
    up_line_cb_fetch_i                        <= 0;
    up_line_cb_store_done                     <= 0;
    if (i_first_row) begin
        up_line_cb_fetch_done                 <= 1;
    end else begin
        rec_cb_stage                          <= 4;
        up_line_cb_fetch_done                 <= 0;
    end
end else begin
    if (rec_cb_stage == 4) begin
        bram_cb_up_line_we                    <= 0;
        bram_cb_up_line_addr                  <= up_line_cb_fetch_addr;
        up_line_cb_fetch_addr                 <= up_line_cb_fetch_addr+1;
        rec_cb_stage                          <= 5;
    end
    if (rec_cb_stage == 5) begin
        bram_cb_up_line_addr                  <= up_line_cb_fetch_addr;
        up_line_cb_fetch_addr                 <= up_line_cb_fetch_addr+1;
        rec_cb_stage                          <= 6;
    end
    if (rec_cb_stage == 6) begin
        bram_cb_up_line_addr                  <= up_line_cb_fetch_addr;
        up_line_cb_fetch_addr                 <= up_line_cb_fetch_addr+1;
        line_buf_top_cb                       <= {bram_cb_up_line_dout,line_buf_top_cb[47:4]};
        up_line_cb_fetch_i                    <= up_line_cb_fetch_i+1;
        if (up_line_cb_fetch_i==11) begin
            rec_cb_stage                      <= 7;
            up_line_cb_fetch_done             <= 1;
        end
    end
    if (ctb_cb_rec_done&&rec_cb_stage!=9) begin
        if (last_row) begin
            up_line_cb_store_done             <= 1;
        end else begin
            up_line_cb_store_done             <= 0;
            rec_cb_stage                      <= 8;
        end
    end
    if (rec_cb_stage == 8) begin
        bram_cb_up_line_we                    <= 1;
        bram_cb_up_line_addr                  <= up_line_cb_store_addr;
        up_line_cb_store_addr                 <= up_line_cb_store_addr+1;
        bram_cb_up_line_din                   <= line_buf_top_cb[3:0];
        line_buf_top_cb[31:0]                 <= {32'd0,line_buf_top_cb[31:4]};
        up_line_cb_store_i                    <= up_line_cb_store_i+1;
        if (up_line_cb_store_i==7) begin
            up_line_cb_store_done             <= 1;
            rec_cb_stage                      <= 9;
        end
    end
    if (rec_cb_stage == 9) begin
        bram_cb_up_line_we                    <= 0;
    end

    if (o_cu_state == `cu_pass2tu && pred_mode==`MODE_INTER&&
        first_tu_in_cu) begin
        rec_done_cb                           <= 0;
        rec_cb_stage                          <= 0;
        rec_cb_x                              <= x0[5:1];
        rec_cb_start_x                        <= x0[5:1];
        rec_cb_y                              <= {1'b0,y0[5:1]};
        dram_tq_cb_addra                      <= {32{y0[5:1]}};
        dram_pred_cb_addra                    <= {32{y0[5:1]}};
        rec_cb_start_y                        <= y0[5:1];
        rec_cb_end_y                          <= y0[5:1]+CbSize[6:1]-1; //to debug
        rec_cb_width                          <= CbSize[6:1];
        rec_cb_x_right_most                   <= x0[5:1]+CbSize[6:1]-1;//to debug
    end

    if (rst_intra_pred_cb) begin //更新rec_x,rec_y之前上次rec必须完成,同理tu结束时rec必须结束
        rec_cb_x                              <= {xTu[5:3],2'b00};
        rec_cb_y                              <= {1'b0,yTu[5:3],2'b00};
        dram_tq_cb_addra                      <= {32{{yTu[5:3],2'b00}}};
        dram_pred_cb_addra                    <= {32{{yTu[5:3],2'b00}}};
        rec_cb_start_y                        <= {yTu[5:3],2'b00};
        rec_cb_start_x                        <= {xTu[5:3],2'b00};
        rec_cb_end_y                          <= trafoSize[2]?{yTu[5:3],2'b11}:
                                                          {yTu[5:3],2'b00}+trafoSize[5:1]-1;
        rec_cb_x_right_most                   <= trafoSize[2]?{xTu[5:3],2'b11}:
                                                          {xTu[5:3],2'b00}+trafoSize[5:1]-1;
        rec_cb_width                          <= trafoSize[2]?5'd4:{1'b0,trafoSize[5:1]};
        rec_done_cb                           <= 0;
        rec_cb_stage                          <= 0;
    end

    rec_cb_one_row                            <= rec_cb_one_row_w;
    if (rec_cb_stage==0&&
        rec_cb_y<=pred_cb_done_y&&
        rec_cb_y<=tq_cb_done_y&&
        rec_cb_y!=6'b100000) begin

        rec_cb_stage                          <= 1;
    end

    if (rec_cb_stage == 1) begin
        rec_cb_one_row_clip                   <= rec_cb_one_row_clip_w;
        rec_cb_stage                          <= 2;
    end

    if (rec_cb_stage == 2) begin
        case(rec_cb_x_right_most[4:2])
            0:rec_cb_pixel_right_most         <= rec_cb_one_row_clip[3];
            1:rec_cb_pixel_right_most         <= rec_cb_one_row_clip[7];
            2:rec_cb_pixel_right_most         <= rec_cb_one_row_clip[11];
            3:rec_cb_pixel_right_most         <= rec_cb_one_row_clip[15];
            4:rec_cb_pixel_right_most         <= rec_cb_one_row_clip[19];
            5:rec_cb_pixel_right_most         <= rec_cb_one_row_clip[23];
            6:rec_cb_pixel_right_most         <= rec_cb_one_row_clip[27];
            7:rec_cb_pixel_right_most         <= rec_cb_one_row_clip[31];
        endcase
        cb_leftup_use_top                     <= line_buf_top_cb[rec_cb_x_right_most];
        cb_leftup_use_right_most              <= rec_cb_pixel_right_most; //上一次记录的right_most

        rec_cb_stage                          <= 3;

    end

    if (rec_cb_stage==3) begin
        case(rec_cb_x[4:2])
            0:dram_rec_cb_dec_we              <= {32{1'd1}};
            1:dram_rec_cb_dec_we              <= {{28{1'd1}},4'd0};
            2:dram_rec_cb_dec_we              <= {{24{1'd1}},8'd0};
            3:dram_rec_cb_dec_we              <= {{20{1'd1}},12'd0};
            4:dram_rec_cb_dec_we              <= {{16{1'd1}},16'd0};
            5:dram_rec_cb_dec_we              <= {{12{1'd1}},20'd0};
            6:dram_rec_cb_dec_we              <= {{8{1'd1}},24'd0};
            7:dram_rec_cb_dec_we              <= {{4{1'd1}},28'd0};
        endcase

        dram_rec_cb_dec_addrd                 <= {32{rec_cb_y[4:0]}};
        dram_rec_cb_dec_did                   <= rec_cb_one_row_clip;
        line_buf_top_cb[31:0]                 <= line_buf_top_cb_w;
        line_buf_left_cb[rec_cb_y[4:0]]       <= rec_cb_pixel_right_most;
        if (rec_cb_y[1:0]==2'd0)
            line_buf_leftup_cb[rec_cb_y[4:2]] <= rec_cb_y[4:0]==rec_cb_start_y?cb_leftup_use_top:cb_leftup_use_right_most;
        rec_cb_y                              <= rec_cb_y+1;
        dram_tq_cb_addra                      <= {32{rec_cb_y_pls1[4:0]}};
        dram_pred_cb_addra                    <= {32{rec_cb_y_pls1[4:0]}};

        if (rec_cb_y[4:0]==rec_cb_end_y)
            rec_done_cb                       <= 1;
        rec_cb_stage                          <= 0;
    end

end

reg               [ 4:0]     rec_cr_x;
reg  signed       [ 5:0]     rec_cr_y;
wire signed       [ 5:0]     rec_cr_y_pls1;
reg               [ 4:0]     rec_cr_start_y;
reg               [ 4:0]     rec_cr_end_y;
reg               [ 5:0]     rec_cr_width;
reg               [ 3:0]     rec_cr_stage;

assign rec_cr_y_pls1 = rec_cr_y+1;

wire signed [31:0][ 9:0]     rec_cr_one_row_w;
wire        [31:0][ 7:0]     rec_cr_one_row_clip_w;
reg  signed [31:0][ 9:0]     rec_cr_one_row;
reg         [31:0][ 7:0]     rec_cr_one_row_clip;
reg               [ 7:0]     rec_cr_one_row_right_most;
reg               [ 7:0]     rec_cr_pixel_right_most;
reg         [31:0][ 7:0]     line_buf_top_cr_w;

generate
    for (I=0;I<32;I++)
    begin: rec_cr_one_row_label
        assign rec_cr_one_row_w[I] = dram_tq_cr_doa[I]+dram_pred_cr_doa[I];
    end
endgenerate

generate
    for (I=0;I<32;I++)
    begin: rec_cr_one_row_clip_label
        assign rec_cr_one_row_clip_w[I] = rec_cr_one_row[I][9]?0:
                                          (rec_cr_one_row[I][8]?255:rec_cr_one_row[I][7:0]);
    end
endgenerate


generate
    for (I=0;I<8;I++)
    begin: line_buf_cr_top_label
        always @(*)
        begin
            if (I>=rec_cr_x[4:2] && I<rec_cr_x[4:2]+rec_cr_width[5:2]) begin
                line_buf_top_cr_w[4*I+3:4*I]         = rec_cr_one_row_clip[4*I+3:4*I];
            end else begin
                line_buf_top_cr_w[4*I+3:4*I]         = line_buf_top_cr[4*I+3:4*I];
            end
        end
    end
endgenerate


reg          ctb_cr_rec_done;
always @(posedge clk)
if (i_rst_ctb||i_rst_slice) begin
    ctb_cr_rec_done       <= 0;
end else begin
    if (rec_done_cr&&
        ((last_row&&rec_cr_y==last_row_height[6:1])||rec_cr_y==6'b100000)&&
        ((last_col&&rec_cr_x_right_most==last_col_width[6:1]-1)||rec_cr_x_right_most==31))
        ctb_cr_rec_done   <= 1;
end


reg   [7:0]         cr_leftup_use_top;
reg   [7:0]         cr_leftup_use_right_most;

always @(posedge clk)
if (global_rst) begin
    rec_done_cr                               <= 1;
end else if (i_rst_slice) begin
    rec_cr_x                                  <= 0;
    rec_cr_y                                  <= 0;
    dram_rec_cr_dec_we                        <= 32'd0;
end else if (i_rst_ctb) begin
    rec_done_cr                               <= 1;
    rec_cr_x                                  <= 0;
    rec_cr_y                                  <= 0;
    up_line_cr_fetch_addr                     <= i_x0[`max_x_bits-1:3];
    up_line_cr_store_addr                     <= i_x0[`max_x_bits-1:3];
    up_line_cr_store_i                        <= 0;
    up_line_cr_fetch_i                        <= 0;
    up_line_cr_store_done                     <= 0;
    if (i_first_row) begin
        up_line_cr_fetch_done                 <= 1;
    end else begin
        rec_cr_stage                          <= 4;
        up_line_cr_fetch_done                 <= 0;
    end
end else begin
    if (rec_cr_stage == 4) begin
        bram_cr_up_line_we                    <= 0;
        bram_cr_up_line_addr                  <= up_line_cr_fetch_addr;
        up_line_cr_fetch_addr                 <= up_line_cr_fetch_addr+1;
        rec_cr_stage                          <= 5;
    end
    if (rec_cr_stage == 5) begin
        bram_cr_up_line_addr                  <= up_line_cr_fetch_addr;
        up_line_cr_fetch_addr                 <= up_line_cr_fetch_addr+1;
        rec_cr_stage                          <= 6;
    end
    if (rec_cr_stage == 6) begin
        bram_cr_up_line_addr                  <= up_line_cr_fetch_addr;
        up_line_cr_fetch_addr                 <= up_line_cr_fetch_addr+1;
        line_buf_top_cr                       <= {bram_cr_up_line_dout,line_buf_top_cr[47:4]};
        up_line_cr_fetch_i                    <= up_line_cr_fetch_i+1;
        if (up_line_cr_fetch_i==11) begin
            rec_cr_stage                      <= 7;
            up_line_cr_fetch_done             <= 1;
        end
    end
    if (ctb_cr_rec_done&&rec_cr_stage!=9) begin
        if (i_last_row) begin
            up_line_cr_store_done             <= 1;
        end else begin
            up_line_cr_store_done             <= 0;
            rec_cr_stage                      <= 8;
        end
    end
    if (rec_cr_stage == 8) begin
        bram_cr_up_line_we                    <= 1;
        bram_cr_up_line_addr                  <= up_line_cr_store_addr;
        up_line_cr_store_addr                 <= up_line_cr_store_addr+1;
        bram_cr_up_line_din                   <= line_buf_top_cr[3:0];
        line_buf_top_cr[31:0]                 <= {32'd0,line_buf_top_cr[31:4]};
        up_line_cr_store_i                    <= up_line_cr_store_i+1;
        if (up_line_cr_store_i==7) begin
            up_line_cr_store_done             <= 1;
            rec_cr_stage                      <= 9;
        end
    end
    if (rec_cr_stage == 9) begin
        bram_cr_up_line_we                    <= 0;
    end
    if (o_cu_state == `cu_pass2tu && pred_mode==`MODE_INTER&&
        first_tu_in_cu) begin
        rec_done_cr                           <= 0;
        rec_cr_stage                          <= 0;
        rec_cr_x                              <= x0[5:1];
        rec_cr_y                              <= {1'b0,y0[5:1]};
        dram_tq_cr_addra                      <= {32{y0[5:1]}};
        dram_pred_cr_addra                    <= {32{y0[5:1]}};
        rec_cr_start_y                        <= y0[5:1];
        rec_cr_end_y                          <= y0[5:1]+CbSize[6:1]-1;
        rec_cr_width                          <= CbSize[6:1];
        rec_cr_x_right_most                   <= x0[5:1]+CbSize[6:1]-1;//to debug
    end

    //cr intra pred开始的时候，沿用cb的
    if (rst_intra_pred_cr) begin
        rec_cr_x                              <= rec_cb_start_x;
        rec_cr_y                              <= {1'b0,rec_cb_start_y};
        dram_tq_cr_addra                      <= {32{rec_cb_start_y}};
        dram_pred_cr_addra                    <= {32{rec_cb_start_y}};
        rec_cr_start_y                        <= rec_cb_start_y;
        rec_cr_end_y                          <= rec_cb_end_y;
        rec_cr_x_right_most                   <= rec_cb_x_right_most;
        rec_cr_width                          <= rec_cb_width;
        rec_done_cr                           <= 0;
        rec_cr_stage                          <= 0;

    end

    rec_cr_one_row                           <= rec_cr_one_row_w;
    if (rec_cr_stage==0&&
        rec_cr_y<=pred_cr_done_y&&
        rec_cr_y<=tq_cr_done_y&&
        rec_cr_y!=6'b100000) begin

        rec_cr_stage                          <= 1;
    end

    if (rec_cr_stage == 1) begin
        rec_cr_one_row_clip                   <= rec_cr_one_row_clip_w;
        rec_cr_stage                          <= 2;
    end

    if (rec_cr_stage == 2) begin
        case(rec_cr_x_right_most[4:2])
            0:rec_cr_pixel_right_most         <= rec_cr_one_row_clip[3];
            1:rec_cr_pixel_right_most         <= rec_cr_one_row_clip[7];
            2:rec_cr_pixel_right_most         <= rec_cr_one_row_clip[11];
            3:rec_cr_pixel_right_most         <= rec_cr_one_row_clip[15];
            4:rec_cr_pixel_right_most         <= rec_cr_one_row_clip[19];
            5:rec_cr_pixel_right_most         <= rec_cr_one_row_clip[23];
            6:rec_cr_pixel_right_most         <= rec_cr_one_row_clip[27];
            7:rec_cr_pixel_right_most         <= rec_cr_one_row_clip[31];
        endcase

        cr_leftup_use_top                     <= line_buf_top_cr[rec_cr_x_right_most];
        cr_leftup_use_right_most              <= rec_cr_pixel_right_most; //上一次记录的right_most

        rec_cr_stage                          <= 3;

    end

    if (rec_cr_stage==3) begin
        case(rec_cr_x[4:2])
            0:dram_rec_cr_dec_we              <= {32{1'd1}};
            1:dram_rec_cr_dec_we              <= {{28{1'd1}},4'd0};
            2:dram_rec_cr_dec_we              <= {{24{1'd1}},8'd0};
            3:dram_rec_cr_dec_we              <= {{20{1'd1}},12'd0};
            4:dram_rec_cr_dec_we              <= {{16{1'd1}},16'd0};
            5:dram_rec_cr_dec_we              <= {{12{1'd1}},20'd0};
            6:dram_rec_cr_dec_we              <= {{8{1'd1}},24'd0};
            7:dram_rec_cr_dec_we              <= {{4{1'd1}},28'd0};
        endcase

        dram_rec_cr_dec_addrd                 <= {32{rec_cr_y[4:0]}};
        dram_rec_cr_dec_did                   <= rec_cr_one_row_clip;
        line_buf_top_cr[31:0]                 <= line_buf_top_cr_w;
        line_buf_left_cr[rec_cr_y[4:0]]       <= rec_cr_pixel_right_most;
        if (rec_cr_y[1:0]==2'd0)
            line_buf_leftup_cr[rec_cr_y[4:2]] <= rec_cr_y[4:0]==rec_cr_start_y?cr_leftup_use_top:cr_leftup_use_right_most;
        rec_cr_y                              <= rec_cr_y+1;
        dram_tq_cr_addra                      <= {32{rec_cr_y_pls1[4:0]}};
        dram_pred_cr_addra                    <= {32{rec_cr_y_pls1[4:0]}};

        if (rec_cr_y[4:0]==rec_cr_end_y)
            rec_done_cr                       <= 1;
        rec_cr_stage                          <= 0;
    end

end

//i_rst_slice到i_rst_ctb之间o_ctb_rec_done保持0不变

always @(posedge clk)
if (i_rst_slice) begin
    o_ctb_rec_done       <= 0;
end else if (global_rst||i_rst_ctb) begin
    o_ctb_rec_done       <= 0;
end else begin
    if (ctb_luma_rec_done&&
        ctb_cb_rec_done&&
        ctb_cr_rec_done&&
        up_line_store_done&&
        up_line_cb_store_done&&
        up_line_cr_store_done)
        o_ctb_rec_done   <= 1;
end

//============================================ FILTER ================================================//
reg                               filter_luma_done;
reg                               filter_cb_done;
reg                               filter_cr_done;

reg                               bram_up_ctb_nf_we;
reg    [`max_ctb_x_bits-1:0]      bram_up_ctb_nf_addra;
reg                    [7:0]      bram_up_ctb_nf_dia;
wire   [`max_ctb_x_bits-1:0]      bram_up_ctb_nf_addrb_filter64;
wire   [`max_ctb_x_bits-1:0]      bram_up_ctb_nf_addrb_filter32;
wire   [`max_ctb_x_bits-1:0]      bram_up_ctb_nf_addrb;
wire                   [7:0]      bram_up_ctb_nf_dob;

assign bram_up_ctb_nf_addrb = filter_luma_done?bram_up_ctb_nf_addrb_filter32:bram_up_ctb_nf_addrb_filter64;


ram_d #(`max_ctb_x_bits,8) bram_up_ctb_nf
(
    .clk(clk),
    .en(1'b1),
    .we(bram_up_ctb_nf_we),
    .addra(bram_up_ctb_nf_addra),
    .addrb(bram_up_ctb_nf_addrb),
    .dia(bram_up_ctb_nf_dia),
    .doa(),
    .dob(bram_up_ctb_nf_dob)
);


reg                         bram_up_ctb_qpy_we;
reg  [`max_ctb_x_bits-1:0]  bram_up_ctb_qpy_addra;
reg  [47:0]                 bram_up_ctb_qpy_dia;
wire [`max_ctb_x_bits-1:0]  bram_up_ctb_qpy_addrb_filter64;
wire [`max_ctb_x_bits-1:0]  bram_up_ctb_qpy_addrb_filter32;
wire [`max_ctb_x_bits-1:0]  bram_up_ctb_qpy_addrb;
wire [47:0]                 bram_up_ctb_qpy_dob;
assign bram_up_ctb_qpy_addrb = filter_luma_done?bram_up_ctb_qpy_addrb_filter32:bram_up_ctb_qpy_addrb_filter64;

ram_d #(`max_ctb_x_bits,48) bram_up_ctb_qpy
(
    .clk(clk),
    .en(1'b1),
    .we(bram_up_ctb_qpy_we),
    .addra(bram_up_ctb_qpy_addra),
    .addrb(bram_up_ctb_qpy_addrb),
    .dia(bram_up_ctb_qpy_dia),
    .doa(),
    .dob(bram_up_ctb_qpy_dob)
);



reg                        rec_luma_sel                ;
reg                        rec_cb_sel                  ;
reg                        rec_cr_sel                  ;

wire  [63:0][ 7:0]         dram_rec_doa0               ;
wire  [63:0][ 7:0]         dram_rec_dob0               ;
wire  [63:0][ 7:0]         dram_rec_dod0               ;
wire  [63:0][ 7:0]         dram_rec_doa1               ;
wire  [63:0][ 7:0]         dram_rec_dob1               ;
wire  [63:0][ 7:0]         dram_rec_dod1               ;
wire  [63:0][ 7:0]         dram_rec_doc0               ;
wire  [63:0][ 7:0]         dram_rec_doc1               ;


//filter64输出
wire  [63:0]               dram_rec_fil64_we           ;
wire  [63:0][ 5:0]         dram_rec_fil64_addra        ;
wire  [63:0][ 5:0]         dram_rec_fil64_addrb        ;
wire  [63:0][ 5:0]         dram_rec_fil64_addrd        ;
wire  [63:0][ 7:0]         dram_rec_fil64_did          ;
//filter64输入
wire  [63:0][ 7:0]         dram_rec_fil64_doa          ;
wire  [63:0][ 7:0]         dram_rec_fil64_dob          ;
wire  [63:0][ 7:0]         dram_rec_fil64_dod          ;


assign dram_rec_fil64_doa   = rec_luma_sel?dram_rec_doa1:dram_rec_doa0;
assign dram_rec_fil64_dob   = rec_luma_sel?dram_rec_dob1:dram_rec_dob0;
assign dram_rec_fil64_dod   = rec_luma_sel?dram_rec_dod1:dram_rec_dod0;


wire  [31:0][ 7:0]         dram_rec_cb_doa0            ;
wire  [31:0][ 7:0]         dram_rec_cb_dob0            ;
wire  [31:0][ 7:0]         dram_rec_cb_dod0            ;
wire  [31:0][ 7:0]         dram_rec_cb_doa1            ;
wire  [31:0][ 7:0]         dram_rec_cb_dob1            ;
wire  [31:0][ 7:0]         dram_rec_cb_dod1            ;


wire  [31:0][ 7:0]         dram_rec_cr_doa0            ;
wire  [31:0][ 7:0]         dram_rec_cr_dob0            ;
wire  [31:0][ 7:0]         dram_rec_cr_dod0            ;
wire  [31:0][ 7:0]         dram_rec_cr_doa1            ;
wire  [31:0][ 7:0]         dram_rec_cr_dob1            ;
wire  [31:0][ 7:0]         dram_rec_cr_dod1            ;

//filter32输出
wire  [31:0]               dram_rec_fil32_we          ;
wire  [31:0][ 4:0]         dram_rec_fil32_addra       ;
wire  [31:0][ 4:0]         dram_rec_fil32_addrb       ;
wire  [31:0][ 4:0]         dram_rec_fil32_addrd       ;
wire  [31:0][ 7:0]         dram_rec_fil32_did         ;
//filter32输入
wire  [31:0][ 7:0]         dram_rec_fil32_doa         ;
wire  [31:0][ 7:0]         dram_rec_fil32_dob         ;
wire  [31:0][ 7:0]         dram_rec_fil32_dod         ;

assign dram_rec_fil32_doa   = filter_cb_done?(rec_cr_sel?dram_rec_cr_doa1:dram_rec_cr_doa0):
                                             (rec_cb_sel?dram_rec_cb_doa1:dram_rec_cb_doa0);
assign dram_rec_fil32_dob   = filter_cb_done?(rec_cr_sel?dram_rec_cr_dob1:dram_rec_cr_dob0):
                                             (rec_cb_sel?dram_rec_cb_dob1:dram_rec_cb_dob0);
assign dram_rec_fil32_dod   = filter_cb_done?(rec_cr_sel?dram_rec_cr_dod1:dram_rec_cr_dod0):
                                             (rec_cb_sel?dram_rec_cb_dod1:dram_rec_cb_dod0);

generate
    for (I=0;I<64;I++)
    begin: dram_rec_0_label
        dram_m #(6, 8) dram_rec_0
        (
            .clk(clk),
            .en(1'b1),
            .we(rec_luma_sel?dram_rec_dec_we[I]:dram_rec_fil64_we[I]),
            .addrd(rec_luma_sel?dram_rec_dec_addrd[I]:dram_rec_fil64_addrd[I]),
            .addra(dram_rec_fil64_addra[I]), //a,b口只有filter用
            .addrb(dram_rec_fil64_addrb[I]),
            .did(rec_luma_sel?dram_rec_dec_did[I]:dram_rec_fil64_did[I]),
            .doa(dram_rec_doa0[I]),
            .dob(dram_rec_dob0[I]),
            .dod(dram_rec_dod0[I])
        );
    end
endgenerate


generate
    for (I=0;I<64;I++)
    begin: dram_rec_1_label
        dram_m #(6, 8) dram_rec_1
        (
            .clk(clk),
            .en(1'b1),
            .we(rec_luma_sel?dram_rec_fil64_we[I]:dram_rec_dec_we[I]),
            .addrd(rec_luma_sel?dram_rec_fil64_addrd[I]:dram_rec_dec_addrd[I]),
            .addra(dram_rec_fil64_addra[I]),
            .addrb(dram_rec_fil64_addrb[I]),
            .did(rec_luma_sel?dram_rec_fil64_did[I]:dram_rec_dec_did[I]),
            .doa(dram_rec_doa1[I]),
            .dob(dram_rec_dob1[I]),
            .dod(dram_rec_dod1[I])
        );
    end
endgenerate


always @ (*)
begin
    if (slice_num==0&&dram_rec_fil64_addrd[36]==23&&dram_rec_fil64_did[36]==0&&dram_rec_fil64_we[36]==1) begin
        $display("%t fil64 0 x0 %d y0 %d rec_x %d rec_start_y %d rec_width %d",
            $time,x0,y0,rec_x,rec_start_y,rec_width);
    end
    if (slice_num==0&&dram_rec_dec_addrd[36]==23&&dram_rec_dec_did[36]==0&&dram_rec_dec_we[36]==1) begin
        $display("%t dec 0 x0 %d y0 %d rec_x %d rec_start_y %d rec_width %d",
            $time,x0,y0,rec_x,rec_start_y,rec_width);
    end


    if (slice_num==0&&dram_rec_fil64_addrd[59]==61&&dram_rec_fil64_did[59]==56&&dram_rec_fil64_we[59]==1) begin
        $display("%t fil64 56 x0 %d y0 %d rec_x %d rec_start_y %d rec_width %d",
            $time,x0,y0,rec_x,rec_start_y,rec_width);
    end
    if (slice_num==0&&dram_rec_dec_addrd[59]==61&&dram_rec_dec_did[59]==56&&dram_rec_dec_we[59]==1) begin
        $display("%t dec 56 x0 %d y0 %d rec_x %d rec_start_y %d rec_width %d",
            $time,x0,y0,rec_x,rec_start_y,rec_width);
    end

end

always @ (*)
begin
    if (slice_num==2&&dram_rec_fil32_addrd[8]==3&&dram_rec_fil32_did[8]==114&&dram_rec_fil32_we[8]==1) begin
        $display("%t fil32 114 x0 %d y0 %d rec_x %d rec_start_y %d rec_width %d",
            $time,x0,y0,rec_x,rec_start_y,rec_width);
    end
    if (slice_num==2&&dram_rec_cb_dec_addrd[8]==3&&dram_rec_cb_dec_did[8]==114&&dram_rec_cb_dec_we[8]==1) begin
        $display("%t cb dec 114 x0 %d y0 %d rec_x %d rec_start_y %d rec_width %d",
            $time,x0,y0,rec_x,rec_start_y,rec_width);
    end

    if (slice_num==2&&dram_rec_fil32_addrd[8]==3&&dram_rec_fil32_did[8]==90&&dram_rec_fil32_we[8]==1) begin
        $display("%t fil32 90 x0 %d y0 %d rec_x %d rec_start_y %d rec_width %d",
            $time,x0,y0,rec_x,rec_start_y,rec_width);
    end
    if (slice_num==2&&dram_rec_cb_dec_addrd[8]==3&&dram_rec_cb_dec_did[8]==90&&dram_rec_cb_dec_we[8]==1) begin
        $display("%t cb dec 90 x0 %d y0 %d rec_x %d rec_start_y %d rec_width %d",
            $time,x0,y0,rec_x,rec_start_y,rec_width);
    end


end



generate
    for (I=0;I<32;I++)
    begin: dram_rec_cb_0_label
        dram_m #(5, 8) dram_rec_cb_0
        (
            .clk(clk),
            .en(1'b1),
            .we(rec_cb_sel?dram_rec_cb_dec_we[I]:(filter_cb_done?1'd0:dram_rec_fil32_we[I])),
            .addrd(rec_cb_sel?dram_rec_cb_dec_addrd[I]:dram_rec_fil32_addrd[I]),
            .addra(dram_rec_fil32_addra[I]),
            .addrb(dram_rec_fil32_addrb[I]),
            .did(rec_cb_sel?dram_rec_cb_dec_did[I]:dram_rec_fil32_did[I]),
            .doa(dram_rec_cb_doa0[I]),
            .dob(dram_rec_cb_dob0[I]),
            .dod(dram_rec_cb_dod0[I])
        );
    end
endgenerate


generate
    for (I=0;I<32;I++)
    begin: dram_rec_cb_1_label
        dram_m #(5, 8) dram_rec_cb_1
        (
            .clk(clk),
            .en(1'b1),
            .we(rec_cb_sel?(filter_cb_done?1'd0:dram_rec_fil32_we[I]):dram_rec_cb_dec_we[I]),
            .addrd(rec_cb_sel?dram_rec_fil32_addrd[I]:dram_rec_cb_dec_addrd[I]),
            .addra(dram_rec_fil32_addra[I]),
            .addrb(dram_rec_fil32_addrb[I]),
            .did(rec_cb_sel?dram_rec_fil32_did[I]:dram_rec_cb_dec_did[I]),
            .doa(dram_rec_cb_doa1[I]),
            .dob(dram_rec_cb_dob1[I]),
            .dod(dram_rec_cb_dod1[I])
        );
    end
endgenerate

generate
    for (I=0;I<32;I++)
    begin: dram_rec_cr_0_label
        dram_m #(5, 8) dram_rec_cr_0
        (
            .clk(clk),
            .en(1'b1),
            .we(rec_cr_sel?dram_rec_cr_dec_we[I]:(filter_cb_done?dram_rec_fil32_we[I]:1'd0)),
            .addrd(rec_cr_sel?dram_rec_cr_dec_addrd[I]:dram_rec_fil32_addrd[I]),
            .addra(dram_rec_fil32_addra[I]),
            .addrb(dram_rec_fil32_addrb[I]),
            .did(rec_cr_sel?dram_rec_cr_dec_did[I]:dram_rec_fil32_did[I]),
            .doa(dram_rec_cr_doa0[I]),
            .dob(dram_rec_cr_dob0[I]),
            .dod(dram_rec_cr_dod0[I])
        );
    end
endgenerate


generate
    for (I=0;I<32;I++)
    begin: dram_rec_cr_1_label
        dram_m #(5, 8) dram_rec_cr_1
        (
            .clk(clk),
            .en(1'b1),
            .we(rec_cr_sel?(filter_cb_done?dram_rec_fil32_we[I]:1'd0):dram_rec_cr_dec_we[I]),
            .addrd(rec_cr_sel?dram_rec_fil32_addrd[I]:dram_rec_cr_dec_addrd[I]),
            .addra(dram_rec_fil32_addra[I]),
            .addrb(dram_rec_fil32_addrb[I]),
            .did(rec_cr_sel?dram_rec_fil32_did[I]:dram_rec_cr_dec_did[I]),
            .doa(dram_rec_cr_doa1[I]),
            .dob(dram_rec_cr_dob1[I]),
            .dod(dram_rec_cr_dod1[I])
        );
    end
endgenerate


reg  [31:0] y_ddr_base;
reg  [31:0] cb_ddr_base;
reg  [31:0] cr_ddr_base;
reg  [31:0] param_ddr_base;

always @(posedge clk)
begin
    case (i_cur_pic_dpb_slot)
        0: param_ddr_base          <= `DDR_BASE_PARAM0;
        1: param_ddr_base          <= `DDR_BASE_PARAM1;
        2: param_ddr_base          <= `DDR_BASE_PARAM2;
        3: param_ddr_base          <= `DDR_BASE_PARAM3;
        4: param_ddr_base          <= `DDR_BASE_PARAM4;
        default: param_ddr_base    <= `DDR_BASE_PARAM5;
    endcase
end

always @(posedge clk)
begin
    case (i_cur_pic_dpb_slot)
        0: y_ddr_base          <= `DDR_BASE_DPB0;
        1: y_ddr_base          <= `DDR_BASE_DPB1;
        2: y_ddr_base          <= `DDR_BASE_DPB2;
        3: y_ddr_base          <= `DDR_BASE_DPB3;
        4: y_ddr_base          <= `DDR_BASE_DPB4;
        default: y_ddr_base    <= `DDR_BASE_DPB5;
    endcase
end

always @(posedge clk)
begin
    case (i_cur_pic_dpb_slot)
        0: cb_ddr_base          <= `DDR_BASE_DPB0+`CB_OFFSET;
        1: cb_ddr_base          <= `DDR_BASE_DPB1+`CB_OFFSET;
        2: cb_ddr_base          <= `DDR_BASE_DPB2+`CB_OFFSET;
        3: cb_ddr_base          <= `DDR_BASE_DPB3+`CB_OFFSET;
        4: cb_ddr_base          <= `DDR_BASE_DPB4+`CB_OFFSET;
        default: cb_ddr_base    <= `DDR_BASE_DPB5+`CB_OFFSET;
    endcase
end

always @(posedge clk)
begin
    case (i_cur_pic_dpb_slot)
        0: cr_ddr_base          <= `DDR_BASE_DPB0+`CR_OFFSET;
        1: cr_ddr_base          <= `DDR_BASE_DPB1+`CR_OFFSET;
        2: cr_ddr_base          <= `DDR_BASE_DPB2+`CR_OFFSET;
        3: cr_ddr_base          <= `DDR_BASE_DPB3+`CR_OFFSET;
        4: cr_ddr_base          <= `DDR_BASE_DPB4+`CR_OFFSET;
        default: cr_ddr_base    <= `DDR_BASE_DPB5+`CR_OFFSET;
    endcase
end


//这个只在解码时用
reg                         bram_up_ctb_mvf_we;
reg  [`max_x_bits-3:0]      bram_up_ctb_mvf_addr;
reg     [`BitsMvf-1:0]      bram_up_ctb_mvf_din;
wire    [`BitsMvf-1:0]      bram_up_ctb_mvf_dout;

ram #(`max_x_bits-2, $bits(MvField)) bram_up_ctb_mvf
(
     .clk(clk),
     .en(1'b1),
     .we(bram_up_ctb_mvf_we),
     .addr(bram_up_ctb_mvf_addr),
     .data_in(bram_up_ctb_mvf_din),
     .data_out(bram_up_ctb_mvf_dout)
 );


MvField                 [15:0]  cur_ctb_mvf;
MvField                 [15:0]  cur_ctb_mvf_w;
MvField                 [15:0]  store_up_mvf;

reg  [15:0][`max_poc_bits-1:0]  cur_ctb_ref_poc;
reg  [15:0][`max_poc_bits-1:0]  cur_ctb_ref_poc_w;
reg                      [6:0]  xPb_right_bound;
reg                      [6:0]  yPb_bottom_bound;
reg        [`max_poc_bits-1:0]  store_ref_poc;
generate
    for (I=0;I<16;I++)
    begin: col_pic_variable
        always @(*)
        begin
            if ({I[1:0],2'b00}>=xPb_save[5:2] && {I[1:0],2'b00}<xPb_right_bound[6:2] &&
                {I[3:2],2'b00}>=yPb_save[5:2] && {I[3:2],2'b00}<yPb_bottom_bound[6:2]) begin
                cur_ctb_mvf_w[I]          = pu_mvf;
                cur_ctb_ref_poc_w[I]      = store_ref_poc;
            end else begin
                cur_ctb_mvf_w[I]          = cur_ctb_mvf[I];
                cur_ctb_ref_poc_w[I]      = cur_ctb_ref_poc[I];
            end

        end

    end
endgenerate



reg  [4:0]                      up_mvf_fetch_stage;
reg  [4:0]                      up_mvf_fetch_i;
wire [`max_x_bits-7:0]          up_mvf_fetch_addr_upper;
reg                             store_up_mvf_done;
reg  [3:0]                      store_up_mvf_i;
reg                             cond_kick_store_up_mvf;


assign up_mvf_fetch_addr_upper = i_x0[`max_x_bits-1:6]+up_mvf_fetch_i[4];


always @ (posedge clk)
    xPb_right_most <= xPb+nPbW-1;


always @ (posedge clk)
if (global_rst) begin
    store_up_mvf_done                <= 1;
    bram_up_ctb_mvf_we               <= 0;
end else if (i_rst_ctb) begin
    if (i_y0==0) begin
        up_mvf                       <= {17{34'd0}};
        up_mvf_fetch_done            <= 1;
    end else begin
        bram_up_ctb_mvf_we           <= 0;
        bram_up_ctb_mvf_addr         <= {i_x0[`max_x_bits-1:6],4'd0};
        up_mvf_fetch_done            <= 0;
        up_mvf_fetch_i               <= 1;
        up_mvf_fetch_stage           <= 0;
    end

end else begin
    if (~up_mvf_fetch_done) begin
        up_mvf_fetch_i               <= up_mvf_fetch_i+1;
        up_mvf_fetch_stage           <= up_mvf_fetch_stage+1;
        bram_up_ctb_mvf_addr         <= {up_mvf_fetch_addr_upper,up_mvf_fetch_i[3:0]};
        if (up_mvf_fetch_stage>0)
            up_mvf                   <= {bram_up_ctb_mvf_dout,up_mvf[16:1]};
        if (up_mvf_fetch_stage>0&&up_mvf_fetch_stage<=16)
            delta_poc_up             <= {i_delta_poc[bram_up_ctb_mvf_dout[3:0]],delta_poc_up[15:1]};
        if (up_mvf_fetch_i==18) //to debug
            up_mvf_fetch_done        <= 1;
    end else if (~store_up_mvf_done) begin
        bram_up_ctb_mvf_we           <= 1;
        bram_up_ctb_mvf_addr         <= {i_x0[`max_x_bits-1:6],store_up_mvf_i};
        bram_up_ctb_mvf_din          <= store_up_mvf[0];
        store_up_mvf_i               <= store_up_mvf_i+1;
        store_up_mvf                 <= {`BitsMvf'd0,store_up_mvf[15:1]};
        if (store_up_mvf_i==15) begin
            store_up_mvf_done        <= 1;
        end
    end
    if (store_up_mvf_done)
        bram_up_ctb_mvf_we           <= 0;

    if (o_cu_state == `update_mvf_nb) begin
        xPb_right_bound             <= xPb+nPbW;
        yPb_bottom_bound            <= yPb+nPbH;
        up_mvf[15:0]                <= up_mvf_w;
        delta_poc_up                <= delta_poc_up_w;
        store_ref_poc               <= i_cur_poc-i_delta_poc[pu_mvf.refIdx];
        cond_kick_store_up_mvf      <= (xPb+nPbW==64||(last_col&&xPb+nPbW==last_col_width))&&
                                       (yPb+nPbH==64||(last_row&&yPb+nPbH==last_row_height));
    end
    //fix,cu=intra，一个ctb很多cu inter，最后一个cu是intra，也要store
    if (o_cu_state == `pred_mode_flag_s&&i_bin_cu) begin
        if((x0[5:3]+CbSize[6:3]==8||(last_col&&x0[5:3]+CbSize[6:3]==last_col_width[6:3]))&&
           (y0[5:3]+CbSize[6:3]==8||(last_row&&y0[5:3]+CbSize[6:3]==last_row_height[6:3]))) begin
            store_up_mvf_done       <= 0; //kick store
            store_up_mvf            <= up_mvf[15:0];
            store_up_mvf_i          <= 0;
        end
    end
    if (store_bs_pu_bound==1) begin //`update_mvf_nb下一周期
        cur_ctb_ref_poc             <= cur_ctb_ref_poc_w;
        cur_ctb_mvf                 <= cur_ctb_mvf_w;
        if (cond_kick_store_up_mvf) begin
            store_up_mvf_done       <= 0; //kick store
            store_up_mvf            <= up_mvf[15:0];
            store_up_mvf_i          <= 0;
        end
    end


end


reg                               rst_filter_luma;
reg                               rst_filter_cb;
reg                               rst_filter_cr;
reg                               filter_luma_en;
reg                               filter_cb_en;
reg                               filter_cr_en;
wire  [ 2:0]                      filter_luma_state;
wire  [ 2:0]                      filter_chroma_state;

reg                               nf_sel;
reg   [ 1:0][7:0][7:0]            nf;


wire  [31:0]                      m_axi_awaddr_filter32;
wire  [ 3:0]                      m_axi_awlen_filter32;
wire                              m_axi_awvalid_filter32;
wire  [63:0]                      m_axi_wdata_filter32;
wire  [ 7:0]                      m_axi_wstrb_filter32;
wire                              m_axi_wlast_filter32;
wire                              m_axi_wvalid_filter32;
wire  [31:0]                      m_axi_awaddr_filter64;
wire  [ 3:0]                      m_axi_awlen_filter64;
wire                              m_axi_awvalid_filter64;
wire  [63:0]                      m_axi_wdata_filter64;
wire  [ 7:0]                      m_axi_wstrb_filter64;
wire                              m_axi_wlast_filter64;
wire                              m_axi_wvalid_filter64;

assign m_axi_awaddr   = filter_luma_done?m_axi_awaddr_filter32:m_axi_awaddr_filter64;
assign m_axi_awlen    = filter_luma_done?m_axi_awlen_filter32:m_axi_awlen_filter64;
assign m_axi_awvalid  = filter_luma_done?m_axi_awvalid_filter32:m_axi_awvalid_filter64;
assign m_axi_wdata    = filter_luma_done?m_axi_wdata_filter32:m_axi_wdata_filter64;
assign m_axi_wstrb    = filter_luma_done?m_axi_wstrb_filter32:m_axi_wstrb_filter64;
assign m_axi_wlast    = filter_luma_done?m_axi_wlast_filter32:m_axi_wlast_filter64;
assign m_axi_wvalid   = filter_luma_done?m_axi_wvalid_filter32:m_axi_wvalid_filter64;

always @(posedge clk)
if (global_rst) begin

    nf_sel                   <= 0;
end else if (i_rst_ctb|i_rst_filter) begin
    nf_sel                   <= ~nf_sel;
end else begin
    if (o_cu_state == `cu_end&&first_cycle_cu_end) begin
        if (CbSize[6] == 1) begin
            nf[nf_sel]                                    <= {64{cu_transquant_bypass_flag}};
        end else if (CbSize[5] == 1) begin
            nf[nf_sel][{y0[5],2'b00}  ][{x0[5],2'b00}  ]  <=  cu_transquant_bypass_flag;
            nf[nf_sel][{y0[5],2'b00}  ][{x0[5],2'b00}+1]  <=  cu_transquant_bypass_flag;
            nf[nf_sel][{y0[5],2'b00}  ][{x0[5],2'b00}+2]  <=  cu_transquant_bypass_flag;
            nf[nf_sel][{y0[5],2'b00}  ][{x0[5],2'b00}+3]  <=  cu_transquant_bypass_flag;
            nf[nf_sel][{y0[5],2'b00}+1][{x0[5],2'b00}  ]  <=  cu_transquant_bypass_flag;
            nf[nf_sel][{y0[5],2'b00}+1][{x0[5],2'b00}+1]  <=  cu_transquant_bypass_flag;
            nf[nf_sel][{y0[5],2'b00}+1][{x0[5],2'b00}+2]  <=  cu_transquant_bypass_flag;
            nf[nf_sel][{y0[5],2'b00}+1][{x0[5],2'b00}+3]  <=  cu_transquant_bypass_flag;
            nf[nf_sel][{y0[5],2'b00}+2][{x0[5],2'b00}  ]  <=  cu_transquant_bypass_flag;
            nf[nf_sel][{y0[5],2'b00}+2][{x0[5],2'b00}+1]  <=  cu_transquant_bypass_flag;
            nf[nf_sel][{y0[5],2'b00}+2][{x0[5],2'b00}+2]  <=  cu_transquant_bypass_flag;
            nf[nf_sel][{y0[5],2'b00}+2][{x0[5],2'b00}+3]  <=  cu_transquant_bypass_flag;
            nf[nf_sel][{y0[5],2'b00}+3][{x0[5],2'b00}  ]  <=  cu_transquant_bypass_flag;
            nf[nf_sel][{y0[5],2'b00}+3][{x0[5],2'b00}+1]  <=  cu_transquant_bypass_flag;
            nf[nf_sel][{y0[5],2'b00}+3][{x0[5],2'b00}+2]  <=  cu_transquant_bypass_flag;
            nf[nf_sel][{y0[5],2'b00}+3][{x0[5],2'b00}+3]  <=  cu_transquant_bypass_flag;

        end else if (CbSize[4] == 1) begin
            nf[nf_sel][{y0[5:4],1'b0}  ][{x0[5:4],1'b0}  ] <= cu_transquant_bypass_flag;
            nf[nf_sel][{y0[5:4],1'b0}+1][{x0[5:4],1'b0}  ] <= cu_transquant_bypass_flag;
            nf[nf_sel][{y0[5:4],1'b0}  ][{x0[5:4],1'b0}+1] <= cu_transquant_bypass_flag;
            nf[nf_sel][{y0[5:4],1'b0}+1][{x0[5:4],1'b0}+1] <= cu_transquant_bypass_flag;
        end else begin
            nf[nf_sel][y0[5:3]  ][x0[5:3]  ]               <= cu_transquant_bypass_flag;
        end

    end


end

reg [`max_ctb_x_bits-1:0]     xCtb_filtering;

//第一个ctb前也rst_ctb,最后一个ctb解码完了之后rst_filter
//rst_ctb时，o_ctb_rec_done=0,
//第一个ctb reset时o_filter_stage=`reset_filtering不变，因为o_ctb_rec_done在global_rst时为0，i_rst_slice也设为0
//第二个ctb reset时o_filter_stage=`filtering_luma，因为此时o_ctb_rec_done已完成
//slice_data里，o_ctb_rec_done才从`ctb_end到ctb_end_2,才reset ctb的

always @ (posedge clk)
if (global_rst) begin
    rec_luma_sel                   <= 0;
    rec_cb_sel                     <= 0;
    rec_cr_sel                     <= 0;
    xCtb_filtering                 <= 0;
    rst_filter_cb                  <= 0;
    rst_filter_cr                  <= 0;
    rst_filter_luma                <= 0;
    o_filter_stage                 <= `reset_filtering;
end else if ((i_rst_filter||i_rst_ctb)&&o_ctb_rec_done) begin
    filter_luma_done               <= 0;
    filter_cb_done                 <= 0;
    filter_cr_done                 <= 0;
    rec_luma_sel                   <= ~rec_luma_sel;
    rec_cb_sel                     <= ~rec_cb_sel;
    rec_cr_sel                     <= ~rec_cr_sel;
    rst_filter_cb                  <= 0;
    rst_filter_cr                  <= 0;
    rst_filter_luma                <= 1;
    filter_luma_en                 <= 1;
    xCtb_filtering                 <= xCtb;
    o_filter_stage                 <= `filtering_luma;
end else begin
    if (o_filter_stage == `reset_filtering) begin
        bram_up_ctb_qpy_we         <= 0;
        bram_up_ctb_nf_we          <= 0;
    end

    if (o_filter_stage == `filtering_luma) begin
        if (filter_luma_state == `filter_end&&~rst_filter_luma) begin
            o_filter_stage         <= `filtering_cb;
            rst_filter_cb          <= 1;
            filter_luma_done       <= 1;

        end
        rst_filter_luma            <= 0;
    end

    if (o_filter_stage==`filtering_cb) begin
        if (filter_chroma_state==`filter_end&&~rst_filter_cb) begin
            o_filter_stage         <= `filtering_cr;
            rst_filter_cr          <= 1;
            filter_cb_done         <= 1;

        end
        rst_filter_cb              <= 0;
    end

    if (o_filter_stage == `filtering_cr) begin
        rst_filter_cr              <= 0;
        if (filter_chroma_state==`filter_end&&~rst_filter_cr) begin
            o_filter_stage         <= `reset_filtering;
            filter_cr_done         <= 1;
            bram_up_ctb_qpy_we     <= 1;
            bram_up_ctb_qpy_addra  <= xCtb_filtering;
            bram_up_ctb_qpy_dia    <= i_qpy[7];
            bram_up_ctb_nf_we      <= 1;
            bram_up_ctb_nf_addra   <= xCtb_filtering;
            bram_up_ctb_nf_dia     <= nf[~nf_sel][7];
        end
    end

end




filter_64 filter_64_inst
(
 .clk                        (clk),
 .rst                        (rst_filter_luma),
 .i_rst_ctb                  (i_rst_ctb|i_rst_filter),
 .i_rst_slice                (i_rst_slice),
 .global_rst                 (global_rst),
 .en                         (filter_luma_en),
 .i_slice_num                (slice_num),
 .i_x0                       ({xCtb,6'd0}),
 .i_y0                       ({yCtb,6'd0}),
 .i_first_row                (first_row),
 .i_first_col                (first_col),
 .i_last_row                 (last_row),
 .i_last_col                 (last_col),
 .i_last_col_width           (last_col_width),
 .i_last_row_height          (last_row_height),
 .i_slice_beta_offset_div2   (i_slice_beta_offset_div2),
 .i_slice_tc_offset_div2     (i_slice_tc_offset_div2),
 .i_sao_param                (i_sao_param),
 .i_sao_param_left           (i_sao_param_left),
 .i_sao_param_up             (i_sao_param_up),
 .i_sao_param_leftup         (i_sao_param_leftup),

 .i_bs_ver                   (bs_ver[~bs_sel]),
 .i_bs_hor                   (bs_hor[~bs_sel]),

 .i_nf                       (nf[~nf_sel]),
 .i_qpy                      (i_qpy),

 .bram_up_ctb_qpy_dout       (bram_up_ctb_qpy_dob),
 .bram_up_ctb_qpy_addr       (bram_up_ctb_qpy_addrb_filter64),
 .bram_up_ctb_nf_dout        (bram_up_ctb_nf_dob),
 .bram_up_ctb_nf_addr        (bram_up_ctb_nf_addrb_filter64),

 .dram_rec_we                (dram_rec_fil64_we),
 .dram_rec_addra             (dram_rec_fil64_addra),
 .dram_rec_addrb             (dram_rec_fil64_addrb),
 .dram_rec_addrd             (dram_rec_fil64_addrd),
 .dram_rec_did               (dram_rec_fil64_did),
 .dram_rec_doa               (dram_rec_fil64_doa),
 .dram_rec_dob               (dram_rec_fil64_dob),
 .dram_rec_dod               (dram_rec_fil64_dod),

 .i_cu_predmode              (cur_ctb_cu_predmode),
 .i_cur_ctb_mvf              (cur_ctb_mvf),
 .i_cur_ctb_ref_poc          (cur_ctb_ref_poc),
 .i_param_base_ddr           (param_ddr_base),
 .i_pic_base_ddr             (y_ddr_base),

 .m_axi_awready              (m_axi_awready),
 .m_axi_awaddr               (m_axi_awaddr_filter64),
 .m_axi_awlen                (m_axi_awlen_filter64),
 .m_axi_awvalid              (m_axi_awvalid_filter64),

 .m_axi_wready               (m_axi_wready),
 .m_axi_wdata                (m_axi_wdata_filter64),
 .m_axi_wstrb                (m_axi_wstrb_filter64),
 .m_axi_wlast                (m_axi_wlast_filter64),
 .m_axi_wvalid               (m_axi_wvalid_filter64),


 .fd_filter                  (fd_filter),
 .fd_deblock                 (fd_deblock),

 .o_filter_state             (filter_luma_state)

);



filter_32 filter_32_inst
(
 .clk                        (clk),
 .rst                        (rst_filter_cb|rst_filter_cr),//1|x=1
 .i_rst_ctb                  (i_rst_ctb|i_rst_filter),
 .i_rst_slice                (i_rst_slice),
 .global_rst                 (global_rst),
 .en                         (1'b1),
 .i_slice_num                (slice_num),
 .i_x0                       ({xCtb,6'd0}),
 .i_y0                       ({yCtb,6'd0}),
 .i_first_row                (first_row),
 .i_first_col                (first_col),
 .i_last_row                 (last_row),
 .i_last_col                 (last_col),
 .i_last_col_width           (last_col_width),
 .i_last_row_height          (last_row_height),

 .i_slice_beta_offset_div2   (i_slice_beta_offset_div2),
 .i_slice_tc_offset_div2     (i_slice_tc_offset_div2),
 .i_sao_param                (i_sao_param),
 .i_sao_param_left           (i_sao_param_left),
 .i_sao_param_up             (i_sao_param_up),
 .i_sao_param_leftup         (i_sao_param_leftup),

 .i_qp_cb_offset             (i_qp_cb_offset),
 .i_qp_cr_offset             (i_qp_cr_offset),
 .i_component                (filter_cb_done?1'b1:1'b0),
 .i_bs_ver                   (bs_ver[~bs_sel]),
 .i_bs_hor                   (bs_hor[~bs_sel]),

 .i_nf                       (nf[~nf_sel]),
 .i_qpy                      (i_qpy),

 .bram_up_ctb_qpy_dout       (bram_up_ctb_qpy_dob),
 .bram_up_ctb_qpy_addr       (bram_up_ctb_qpy_addrb_filter32),
 .bram_up_ctb_nf_dout        (bram_up_ctb_nf_dob),
 .bram_up_ctb_nf_addr        (bram_up_ctb_nf_addrb_filter32),

 .dram_rec_we                (dram_rec_fil32_we),
 .dram_rec_addra             (dram_rec_fil32_addra),
 .dram_rec_addrb             (dram_rec_fil32_addrb),
 .dram_rec_addrd             (dram_rec_fil32_addrd),
 .dram_rec_did               (dram_rec_fil32_did),
 .dram_rec_doa               (dram_rec_fil32_doa),
 .dram_rec_dob               (dram_rec_fil32_dob),
 .dram_rec_dod               (dram_rec_fil32_dod),

 .i_pic_base_ddr             (filter_cb_done?cr_ddr_base:cb_ddr_base),

 .m_axi_awready              (m_axi_awready),
 .m_axi_awaddr               (m_axi_awaddr_filter32),
 .m_axi_awlen                (m_axi_awlen_filter32),
 .m_axi_awvalid              (m_axi_awvalid_filter32),

 .m_axi_wready               (m_axi_wready),
 .m_axi_wdata                (m_axi_wdata_filter32),
 .m_axi_wstrb                (m_axi_wstrb_filter32),
 .m_axi_wlast                (m_axi_wlast_filter32),
 .m_axi_wvalid               (m_axi_wvalid_filter32),


 .fd_filter                  (fd_filter),
 .fd_deblock                 (fd_deblock),

 .o_filter_state             (filter_chroma_state)

);


tu tu_inst
(
 .clk                              (clk),
 .rst                              (rst_tu),
 .global_rst                       (global_rst),
 .i_rst_slice                      (i_rst_slice),
 .en                               (i_tu_en),

 .i_slice_type                     (i_slice_type),

 .i_cu_transquant_bypass_flag      (cu_transquant_bypass_flag),
 .i_cu_qp_delta_enabled_flag       (i_cu_qp_delta_enabled_flag),
 .i_transform_skip_enabled_flag    (i_transform_skip_enabled_flag),

 .i_sign_data_hiding_enabled_flag  (i_sign_data_hiding_enabled_flag), //pps
 .i_IsCuQpDeltaCoded               (i_IsCuQpDeltaCoded),
 .i_blkIdx                         (blkIdx),

 .i_x0                             (x0),
 .i_y0                             (y0),
 .i_slice_num                      (i_slice_num),
 .i_xTu                            (xTu),
 .i_yTu                            (yTu),
 .i_CbSize                         (CbSize),
 .i_trafoDepth                     (trafoDepth),
 .i_log2TrafoSize                  (log2TrafoSize),
 .i_trafoSize                      (trafoSize),
 .i_cbf_cb                         (cbf_cb),
 .i_cbf_cr                         (cbf_cr),
 .i_IntraPredModeY                 (IntraPredModeY),
 .i_intra_pred_mode_chroma         (IntraPredModeC),
 .i_part_mode                      (part_mode),
 .i_pred_mode                      (pred_mode),
 .i_rqt_root_cbf                   (rqt_root_cbf),
 .i_cu_skip_flag                   (cu_skip_flag),
 .fd_log                           (fd_log),
 .fd_tq_luma                       (fd_tq_luma),
 .fd_tq_cb                         (fd_tq_cb),
 .fd_tq_cr                         (fd_tq_cr),

 .i_qPY_PRED                       (i_qPY_PRED),
 .i_qPY                            (i_qPY),
 .i_qp_cb_offset                   (i_qp_cb_offset),
 .i_qp_cr_offset                   (i_qp_cr_offset),

 .o_cm_idx_xy_pref                 (o_cm_idx_xy_pref),
 .o_cm_idx_sig                     (o_cm_idx_sig),
 .o_cm_idx_gt1_etc                 (o_cm_idx_gt1_etc),
 .o_dec_bin_en_xy_pref             (o_dec_bin_en_xy_pref),
 .o_dec_bin_en_sig                 (o_dec_bin_en_sig),
 .o_dec_bin_en_gt1_etc             (o_dec_bin_en_gt1_etc),
 .o_byp_dec_en_tu                  (o_byp_dec_en_tu),
 .o_tq_luma_state                  (tq_luma_state), //未done也利用tq_luma_done_y来重建，所以这个状态没啥用
 .o_tq_cb_state                    (tq_cb_state),
 .o_tq_cr_state                    (tq_cr_state),
 .o_cbf_luma                       (cbf_luma),
 .o_cIdx                           (cIdx),
 .o_tq_luma_end_x                  (tq_luma_end_x),
 .o_tq_cb_end_x                    (tq_cb_end_x),
 .o_tq_cr_end_x                    (tq_cr_end_x),
 .o_tq_cb_x                        (tq_cb_start_x),
 .o_tq_cb_y                        (tq_cb_start_y),
 .o_tq_cr_x                        (tq_cr_start_x),
 .o_tq_cr_y                        (tq_cr_start_y),

 .i_bin_xy_pref                    (i_bin_xy_pref),
 .i_bin_sig                        (i_bin_sig),
 .i_bin_gt1_etc                    (i_bin_gt1_etc),
 .i_dec_bin_valid                  (i_dec_bin_valid),
 .i_bin_byp                        (i_bin_byp),

 .i_ivlCurrRange                   (i_ivlCurrRange),
 .i_ivlOffset                      (i_ivlOffset),

 .dram_tq_we                       (dram_tq_we),
 .dram_tq_addrd                    (dram_tq_addrd),
 .dram_tq_did                      (dram_tq_did),

 .dram_tq_cb_we                    (dram_tq_cb_we),
 .dram_tq_cb_addrd                 (dram_tq_cb_addrd),
 .dram_tq_cb_did                   (dram_tq_cb_did),

 .dram_tq_cr_we                    (dram_tq_cr_we),
 .dram_tq_cr_addrd                 (dram_tq_cr_addrd),
 .dram_tq_cr_did                   (dram_tq_cr_did),

 .o_tq_luma_done_y                 (tq_luma_done_y_w),
 .o_tq_cb_done_y                   (tq_cb_done_y_w),
 .o_tq_cr_done_y                   (tq_cr_done_y_w),

 .o_IsCuQpDeltaCoded               (o_IsCuQpDeltaCoded),
 .o_QpY                            (o_QpY),
 .o_tu_state                       (o_tu_state)
);


`ifdef RANDOM_INIT
integer  seed;
integer random_val;
initial  begin
    seed                               = $get_initial_random_seed(); 
    random_val                         = $random(seed);
    o_cm_idx_cu                        = {random_val,random_val};
    o_dec_bin_en_cu                    = {random_val[1:0],random_val[31:2],random_val[1:0],random_val[31:2]};
    o_byp_dec_en_cu                    = {random_val[2:0],random_val[31:3],random_val[2:0],random_val[31:3]};
    o_filter_stage                     = {random_val[3:0],random_val[31:4],random_val[3:0],random_val[31:4]};
    o_cu_state                         = {random_val[4:0],random_val[31:5],random_val[4:0],random_val[31:5]};
    cu_transquant_bypass_flag          = {random_val[8:0],random_val[31:9],random_val[8:0],random_val[31:9]};
    rst_tu                             = {random_val[9:0],random_val[31:10],random_val[9:0],random_val[31:10]};
    slice_num                          = {random_val[10:0],random_val[31:11],random_val[10:0],random_val[31:11]};
    x0                                 = {random_val[11:0],random_val[31:12],random_val[11:0],random_val[31:12]};
    y0                                 = {random_val[12:0],random_val[31:13],random_val[12:0],random_val[31:13]};
    xPb                                = {random_val[13:0],random_val[31:14],random_val[13:0],random_val[31:14]};
    yPb                                = {random_val[14:0],random_val[31:15],random_val[14:0],random_val[31:15]};
    xTu                                = {random_val[15:0],random_val[31:16],random_val[15:0],random_val[31:16]};
    yTu                                = {random_val[16:0],random_val[31:17],random_val[16:0],random_val[31:17]};
    log2CbSize                         = {random_val[17:0],random_val[31:18],random_val[17:0],random_val[31:18]};
    CbSize                             = {random_val[18:0],random_val[31:19],random_val[18:0],random_val[31:19]};
    first_cycle_parse_tu               = {random_val[19:0],random_val[31:20],random_val[19:0],random_val[31:20]};
    first_tu_in_cu                     = {random_val[20:0],random_val[31:21],random_val[20:0],random_val[31:21]};
    first_cycle_cu_end                 = {random_val[21:0],random_val[31:22],random_val[21:0],random_val[31:22]};
    x0_right_most                      = {random_val[22:0],random_val[31:23],random_val[22:0],random_val[31:23]};
    last_col                           = {random_val[23:0],random_val[31:24],random_val[23:0],random_val[31:24]};
    last_row                           = {random_val[24:0],random_val[31:25],random_val[24:0],random_val[31:25]};
    first_col                          = {random_val[25:0],random_val[31:26],random_val[25:0],random_val[31:26]};
    first_row                          = {random_val[26:0],random_val[31:27],random_val[26:0],random_val[31:27]};
    last_col_width                     = {random_val[27:0],random_val[31:28],random_val[27:0],random_val[31:28]};
    last_row_height                    = {random_val[28:0],random_val[31:29],random_val[28:0],random_val[31:29]};
    qpy                                = {random_val[29:0],random_val[31:30],random_val[29:0],random_val[31:30]};
    i                                  = {random_val[30:0],random_val[31],random_val[30:0],random_val[31]};
    j                                  = {random_val[31:0],random_val[31:0]};
    k                                  = {random_val,random_val};
    partIdx                            = {random_val[1:0],random_val[31:2],random_val[1:0],random_val[31:2]};
    part_mode                          = {random_val[2:0],random_val[31:3],random_val[2:0],random_val[31:3]};
    pred_mode                          = {random_val[3:0],random_val[31:4],random_val[3:0],random_val[31:4]};
    max_bits                           = {random_val[4:0],random_val[31:5],random_val[4:0],random_val[31:5]};
    part_num                           = {random_val[5:0],random_val[31:6],random_val[5:0],random_val[31:6]};
    prev_intra_luma_pred_flag[0:3]     = {random_val[6:0],random_val[31:7],random_val[6:0],random_val[31:7]};
    mpm_idx                            = {random_val[7:0],random_val[31:8],random_val[7:0],random_val[31:8]};
    intra_pred_mode_chroma             = {random_val[8:0],random_val[31:9],random_val[8:0],random_val[31:9]};
    rem_intra_luma_pred_mode[0:3]      = {random_val[9:0],random_val[31:10],random_val[9:0],random_val[31:10]};
    IntraPredModeY                     = {random_val[10:0],random_val[31:11],random_val[10:0],random_val[31:11]};
    IntraPredModeC                     = {random_val[11:0],random_val[31:12],random_val[11:0],random_val[31:12]};
    cu_intra_luma_pred_mode[0:3]       = {random_val[12:0],random_val[31:13],random_val[12:0],random_val[31:13]};
    cur_rem_intra_luma_pred_mode       = {random_val[13:0],random_val[31:14],random_val[13:0],random_val[31:14]};
    symbol                             = {random_val[14:0],random_val[31:15],random_val[14:0],random_val[31:15]};
    rqt_root_cbf                       = {random_val[15:0],random_val[31:16],random_val[15:0],random_val[31:16]};
    candIntraPredModeA                 = {random_val[16:0],random_val[31:17],random_val[16:0],random_val[31:17]};
    candIntraPredModeB                 = {random_val[17:0],random_val[31:18],random_val[17:0],random_val[31:18]};
    candModeList                       = {random_val[5:0],random_val[11:6],random_val[17:12]};
    trafoDepth                         = {random_val[19:0],random_val[31:20],random_val[19:0],random_val[31:20]};
    log2TrafoSize                      = {random_val[20:0],random_val[31:21],random_val[20:0],random_val[31:21]};
    trafoSize                          = {random_val[21:0],random_val[31:22],random_val[21:0],random_val[31:22]};
    dep_partIdx_tu                     = {random_val[1:0],random_val[3:2],random_val[5:4],random_val[7:6],random_val[9:8]};
    blkIdx                             = {random_val[23:0],random_val[31:24],random_val[23:0],random_val[31:24]};
    base_cbf_cb                        = {random_val[0],random_val[1],random_val[2],random_val[3],random_val[4]};
    base_cbf_cr                        = {random_val[0],random_val[1],random_val[2],random_val[3],random_val[4]};
    cbf_cb                             = {random_val[27:0],random_val[31:28],random_val[27:0],random_val[31:28]};
    cbf_cr                             = {random_val[28:0],random_val[31:29],random_val[28:0],random_val[31:29]};
    split_tu                           = {random_val[29:0],random_val[31:30],random_val[29:0],random_val[31:30]};
    dram_cbf_luma_up_we                = {random_val[30:0],random_val[31],random_val[30:0],random_val[31]};
    dram_cbf_luma_up_addr              = {random_val[31:0],random_val[31:0]};
    dram_cbf_luma_up_din               = {random_val,random_val};
    cbf_luma_left                      = {random_val[1:0],random_val[31:2],random_val[1:0],random_val[31:2]};
    cbf_luma_up                        = {random_val[2:0],random_val[31:3],random_val[2:0],random_val[31:3]};
    intra_luma_pred_mode_left          = {random_val[5:0],random_val[5:0],random_val[5:0],random_val[5:0],
                                          random_val[5:0],random_val[5:0],random_val[5:0],random_val[5:0],
                                          random_val[5:0],random_val[5:0],random_val[5:0],random_val[5:0],
                                          random_val[5:0],random_val[5:0],random_val[5:0],random_val[5:0]};
    intra_luma_pred_mode_up            = {random_val[5:0],random_val[5:0],random_val[5:0],random_val[5:0],
                                          random_val[5:0],random_val[5:0],random_val[5:0],random_val[5:0],
                                          random_val[5:0],random_val[5:0],random_val[5:0],random_val[5:0],
                                          random_val[5:0],random_val[5:0],random_val[5:0],random_val[5:0]};
    dram_up_ctb_cu_predmode_we         = {random_val[5:0],random_val[31:6],random_val[5:0],random_val[31:6]};
    dram_up_ctb_cu_predmode_addr       = {random_val[6:0],random_val[31:7],random_val[6:0],random_val[31:7]};
    dram_up_ctb_cu_predmode_din        = {random_val[7:0],random_val[31:8],random_val[7:0],random_val[31:8]};
    phase                              = {random_val[8:0],random_val[31:9],random_val[8:0],random_val[31:9]};
    cur_ctb_cu_predmode                = {random_val[9:0],random_val[31:10],random_val[9:0],random_val[31:10]};
    cu_predmode_left_init1             = {random_val[10:0],random_val[31:11],random_val[10:0],random_val[31:11]};
    cu_predmode_left_init0             = {random_val[11:0],random_val[31:12],random_val[11:0],random_val[31:12]};
    cu_predmode_up_init0               = {random_val[12:0],random_val[31:13],random_val[12:0],random_val[31:13]};
    cu_predmode_up_init1               = {random_val[13:0],random_val[31:14],random_val[13:0],random_val[31:14]};
    cu_predmode_leftup_init1           = {random_val[14:0],random_val[31:15],random_val[14:0],random_val[31:15]};
    cu_predmode_leftup_init0           = {random_val[15:0],random_val[31:16],random_val[15:0],random_val[31:16]};
    dram_cu_skip_up_we                 = {random_val[16:0],random_val[31:17],random_val[16:0],random_val[31:17]};
    dram_cu_skip_up_addr               = {random_val[17:0],random_val[31:18],random_val[17:0],random_val[31:18]};
    dram_cu_skip_up_din                = {random_val[18:0],random_val[31:19],random_val[18:0],random_val[31:19]};
    cu_skip_flag                       = {random_val[19:0],random_val[31:20],random_val[19:0],random_val[31:20]};
    cu_skip_flag_left                  = {random_val[20:0],random_val[31:21],random_val[20:0],random_val[31:21]};
    cu_skip_flag_up                    = {random_val[21:0],random_val[31:22],random_val[21:0],random_val[31:22]};
    merge_flag                         = {random_val[22:0],random_val[31:23],random_val[22:0],random_val[31:23]};
    MaxNumMergeCand                    = {random_val[23:0],random_val[31:24],random_val[23:0],random_val[31:24]};
    max_merge_cand_minus2              = {random_val[24:0],random_val[31:25],random_val[24:0],random_val[31:25]};
    merge_idx                          = {random_val[25:0],random_val[31:26],random_val[25:0],random_val[31:26]};
    abs_mvd_greater0_flag              = {random_val[26:0],random_val[31:27],random_val[26:0],random_val[31:27]};
    abs_mvd_greater1_flag              = {random_val[27:0],random_val[31:28],random_val[27:0],random_val[31:28]};
    mvd_sign_flag                      = {random_val[28:0],random_val[31:29],random_val[28:0],random_val[31:29]};
    mvp_l0_flag                        = {random_val[29:0],random_val[31:30],random_val[29:0],random_val[31:30]};
    ref_idx_l0                         = {random_val[30:0],random_val[31],random_val[30:0],random_val[31]};
    num_ref_idx_l0_active_minus1       = {random_val[31:0],random_val[31:0]};
    num_ref_idx_l0_active_minus2       = {random_val,random_val};
    abs_mvd_minus2                     = {random_val[1:0],random_val[31:2],random_val[1:0],random_val[31:2]};
    abs_mvd                            = {random_val[2:0],random_val[31:3],random_val[2:0],random_val[31:3]};
    mvd                                = {random_val[14:0],random_val[29:15]};
    one_shift_k                        = {random_val[4:0],random_val[31:5],random_val[4:0],random_val[31:5]};
    reset_mv                           = {random_val[5:0],random_val[31:6],random_val[5:0],random_val[31:6]};
    xPb_right_most                     = {random_val[6:0],random_val[31:7],random_val[6:0],random_val[31:7]};
    nPbW                               = {random_val[7:0],random_val[31:8],random_val[7:0],random_val[31:8]};
    nPbH                               = {random_val[8:0],random_val[31:9],random_val[8:0],random_val[31:9]};
    xPb_nxt                            = {random_val[9:0],random_val[31:10],random_val[9:0],random_val[31:10]};
    yPb_nxt                            = {random_val[10:0],random_val[31:11],random_val[10:0],random_val[31:11]};
    xPb_save                           = {random_val[11:0],random_val[31:12],random_val[11:0],random_val[31:12]};
    yPb_save                           = {random_val[12:0],random_val[31:13],random_val[12:0],random_val[31:13]};
    delta_poc_up                       = {random_val[13:0],random_val[31:14],random_val[13:0],random_val[31:14]};
    delta_poc_left                     = {random_val[14:0],random_val[31:15],random_val[14:0],random_val[31:15]};
    delta_poc_cur_pu                   = {random_val[15:0],random_val[31:16],random_val[15:0],random_val[31:16]};
    store_bs_pu_bound                  = {random_val[16:0],random_val[31:17],random_val[16:0],random_val[31:17]};
    rec_done_luma                      = {random_val[17:0],random_val[31:18],random_val[17:0],random_val[31:18]};
    rec_done_cb                        = {random_val[18:0],random_val[31:19],random_val[18:0],random_val[31:19]};
    rec_done_cr                        = {random_val[19:0],random_val[31:20],random_val[19:0],random_val[31:20]};
    intra_pred_luma_done               = {random_val[20:0],random_val[31:21],random_val[20:0],random_val[31:21]};
    intra_pred_cb_done                 = {random_val[21:0],random_val[31:22],random_val[21:0],random_val[31:22]};
    intra_pred_cr_done                 = {random_val[22:0],random_val[31:23],random_val[22:0],random_val[31:23]};
    inter_pred_done                    = {random_val[23:0],random_val[31:24],random_val[23:0],random_val[31:24]};
    inter_pred_luma_done               = {random_val[24:0],random_val[31:25],random_val[24:0],random_val[31:25]};
    inter_pred_cb_done                 = {random_val[25:0],random_val[31:26],random_val[25:0],random_val[31:26]};
    inter_pred_cr_done                 = {random_val[26:0],random_val[31:27],random_val[26:0],random_val[31:27]};
    up_mvf_fetch_done                  = {random_val[27:0],random_val[31:28],random_val[27:0],random_val[31:28]};
    fetch_up_ctb_predmode_i            = {random_val[29:0],random_val[31:30],random_val[29:0],random_val[31:30]};
    bs_sel                             = {random_val[30:0],random_val[31],random_val[30:0],random_val[31]};
    bs_ver                             = {random_val[31:0],random_val[31:0]};
    bs_hor                             = {random_val,random_val};
    bs_hor_cur_tu_bound                = {random_val[1:0],random_val[31:2],random_val[1:0],random_val[31:2]};
    bs_ver_cur_tu_bound                = {random_val[2:0],random_val[31:3],random_val[2:0],random_val[31:3]};
    bs_hor_cur_pu_bound                = {random_val[3:0],random_val[31:4],random_val[3:0],random_val[31:4]};
    bs_ver_cur_pu_bound                = {random_val[4:0],random_val[31:5],random_val[4:0],random_val[31:5]};
    bs_hor_tu_bound                    = {random_val[5:0],random_val[31:6],random_val[5:0],random_val[31:6]};
    bs_ver_tu_bound                    = {random_val[6:0],random_val[31:7],random_val[6:0],random_val[31:7]};
    bs_hor_pu_bound                    = {random_val[7:0],random_val[31:8],random_val[7:0],random_val[31:8]};
    bs_ver_pu_bound                    = {random_val[8:0],random_val[31:9],random_val[8:0],random_val[31:9]};
    tu_bottom_bound                    = {random_val[9:0],random_val[31:10],random_val[9:0],random_val[31:10]};
    tu_right_bound                     = {random_val[10:0],random_val[31:11],random_val[10:0],random_val[31:11]};
    pu_bottom_bound                    = {random_val[11:0],random_val[31:12],random_val[11:0],random_val[31:12]};
    pu_right_bound                     = {random_val[12:0],random_val[31:13],random_val[12:0],random_val[31:13]};
    diff_up_mv0[15:0]                  = {random_val[14:0],random_val[14:0],random_val[14:0],random_val[14:0],
                                          random_val[14:0],random_val[14:0],random_val[14:0],random_val[14:0],
                                          random_val[14:0],random_val[14:0],random_val[14:0],random_val[14:0],
                                          random_val[14:0],random_val[14:0],random_val[14:0],random_val[14:0]};
    diff_up_mv1[15:0]                  = {random_val[14:0],random_val[14:0],random_val[14:0],random_val[14:0],
                                          random_val[14:0],random_val[14:0],random_val[14:0],random_val[14:0],
                                          random_val[14:0],random_val[14:0],random_val[14:0],random_val[14:0],
                                          random_val[14:0],random_val[14:0],random_val[14:0],random_val[14:0]};
    diff_left_mv0[15:0]                = {random_val[14:0],random_val[14:0],random_val[14:0],random_val[14:0],
                                          random_val[14:0],random_val[14:0],random_val[14:0],random_val[14:0],
                                          random_val[14:0],random_val[14:0],random_val[14:0],random_val[14:0],
                                          random_val[14:0],random_val[14:0],random_val[14:0],random_val[14:0]};
    diff_left_mv1[15:0]                = {random_val[14:0],random_val[14:0],random_val[14:0],random_val[14:0],
                                          random_val[14:0],random_val[14:0],random_val[14:0],random_val[14:0],
                                          random_val[14:0],random_val[14:0],random_val[14:0],random_val[14:0],
                                          random_val[14:0],random_val[14:0],random_val[14:0],random_val[14:0]};
    dram_tq_addra                      = {random_val[17:0],random_val[31:18],random_val[17:0],random_val[31:18]};
    dram_tq_cb_addra                   = {random_val[18:0],random_val[31:19],random_val[18:0],random_val[31:19]};
    dram_tq_cr_addra                   = {random_val[19:0],random_val[31:20],random_val[19:0],random_val[31:20]};
    dram_pred_addra                    = {random_val[20:0],random_val[31:21],random_val[20:0],random_val[31:21]};
    dram_pred_cb_addra                 = {random_val[21:0],random_val[31:22],random_val[21:0],random_val[31:22]};
    dram_pred_cr_addra                 = {random_val[22:0],random_val[31:23],random_val[22:0],random_val[31:23]};
    left_avail_sz8x8_r                 = {random_val[23:0],random_val[31:24],random_val[23:0],random_val[31:24]};
    up_avail_sz8x8_r                   = {random_val[24:0],random_val[31:25],random_val[24:0],random_val[31:25]};
    line_buf_top_luma                  = {random_val[25:0],random_val[31:26],random_val[25:0],random_val[31:26]};
    line_buf_left_luma                 = {random_val[26:0],random_val[31:27],random_val[26:0],random_val[31:27]};
    line_buf_leftup_luma               = {random_val[27:0],random_val[31:28],random_val[27:0],random_val[31:28]};
    line_buf_top_cb                    = {random_val[28:0],random_val[31:29],random_val[28:0],random_val[31:29]};
    line_buf_left_cb                   = {random_val[29:0],random_val[31:30],random_val[29:0],random_val[31:30]};
    line_buf_leftup_cb                 = {random_val[30:0],random_val[31],random_val[30:0],random_val[31]};
    line_buf_top_cr                    = {random_val[31:0],random_val[31:0]};
    line_buf_left_cr                   = {random_val,random_val};
    line_buf_leftup_cr                 = {random_val[1:0],random_val[31:2],random_val[1:0],random_val[31:2]};
    up_line_fetch_done                 = {random_val[2:0],random_val[31:3],random_val[2:0],random_val[31:3]};
    up_line_cb_fetch_done              = {random_val[3:0],random_val[31:4],random_val[3:0],random_val[31:4]};
    up_line_cr_fetch_done              = {random_val[4:0],random_val[31:5],random_val[4:0],random_val[31:5]};
    rst_intra_pred_luma                = {random_val[5:0],random_val[31:6],random_val[5:0],random_val[31:6]};
    rst_intra_pred_cb                  = {random_val[6:0],random_val[31:7],random_val[6:0],random_val[31:7]};
    rst_intra_pred_cr                  = {random_val[7:0],random_val[31:8],random_val[7:0],random_val[31:8]};
    nb_rst                             = {random_val[10:0],random_val[31:11],random_val[10:0],random_val[31:11]};
    intra_pred_cidx                    = {random_val[11:0],random_val[31:12],random_val[11:0],random_val[31:12]};
    luma_intra_pred_run                = {random_val[12:0],random_val[31:13],random_val[12:0],random_val[31:13]};
    cb_intra_pred_run                  = {random_val[13:0],random_val[31:14],random_val[13:0],random_val[31:14]};
    cr_intra_pred_run                  = {random_val[14:0],random_val[31:15],random_val[14:0],random_val[31:15]};
    pred_mode_cur_rec                  = {random_val[15:0],random_val[31:16],random_val[15:0],random_val[31:16]};
    cond_chroma_no_residual            = {random_val[16:0],random_val[31:17],random_val[16:0],random_val[31:17]};
    luma_inter_pred_run                = {random_val[17:0],random_val[31:18],random_val[17:0],random_val[31:18]};
    cb_inter_pred_run                  = {random_val[18:0],random_val[31:19],random_val[18:0],random_val[31:19]};
    cr_inter_pred_run                  = {random_val[19:0],random_val[31:20],random_val[19:0],random_val[31:20]};
    col_pic_dpb_slot                   = {random_val[20:0],random_val[31:21],random_val[20:0],random_val[31:21]};
    cur_poc_diff                       = {random_val[21:0],random_val[31:22],random_val[21:0],random_val[31:22]};
    col_pic_poc                        = {random_val[22:0],random_val[31:23],random_val[22:0],random_val[31:23]};
    inter_pred_part_idx                = {random_val[23:0],random_val[31:24],random_val[23:0],random_val[31:24]};
    rst_inter_pred_luma                = {random_val[24:0],random_val[31:25],random_val[24:0],random_val[31:25]};
    rst_inter_pred_chroma              = {random_val[25:0],random_val[31:26],random_val[25:0],random_val[31:26]};
    part_num_save                      = {random_val[26:0],random_val[31:27],random_val[26:0],random_val[31:27]};
    pred_mode_save                     = {random_val[27:0],random_val[31:28],random_val[27:0],random_val[31:28]};
    inter_pred_stage                   = {random_val[28:0],random_val[31:29],random_val[28:0],random_val[31:29]};
    inter_pred_cidx                    = {random_val[29:0],random_val[31:30],random_val[29:0],random_val[31:30]};
    ref_ddr_base_luma                  = {random_val[30:0],random_val[31],random_val[30:0],random_val[31]};
    ref_ddr_base_cb                    = {random_val[31:0],random_val[31:0]};
    ref_ddr_base_cr                    = {random_val,random_val};
    m_axi_rready_inter                 = {random_val[1:0],random_val[31:2],random_val[1:0],random_val[31:2]};
    fifo_wr_en                         = {random_val[2:0],random_val[31:3],random_val[2:0],random_val[31:3]};
    fifo_wr_data                       = {random_val[3:0],random_val[31:4],random_val[3:0],random_val[31:4]};
    ref_y                              = {random_val[4:0],random_val[31:5],random_val[4:0],random_val[31:5]};
    c_ref_y                            = {random_val[5:0],random_val[31:6],random_val[5:0],random_val[31:6]};
    ref_fetch_stage                    = {random_val[6:0],random_val[31:7],random_val[6:0],random_val[31:7]};
    ref_luma_fetch_done                = {random_val[7:0],random_val[31:8],random_val[7:0],random_val[31:8]};
    ref_cb_fetch_done                  = {random_val[8:0],random_val[31:9],random_val[8:0],random_val[31:9]};
    ref_cr_fetch_done                  = {random_val[9:0],random_val[31:10],random_val[9:0],random_val[31:10]};
    rec_x_right_most                   = {random_val[10:0],random_val[31:11],random_val[10:0],random_val[31:11]};
    rec_start_y                        = {random_val[11:0],random_val[31:12],random_val[11:0],random_val[31:12]};
    rec_start_x                        = {random_val[12:0],random_val[31:13],random_val[12:0],random_val[31:13]};
    rec_cb_x_right_most                = {random_val[13:0],random_val[31:14],random_val[13:0],random_val[31:14]};
    rec_cr_x_right_most                = {random_val[14:0],random_val[31:15],random_val[14:0],random_val[31:15]};
    rec_cb_start_y                     = {random_val[15:0],random_val[31:16],random_val[15:0],random_val[31:16]};
    rec_cb_start_x                     = {random_val[16:0],random_val[31:17],random_val[16:0],random_val[31:17]};
    tq_luma_done_y                     = {random_val[20:0],random_val[31:21],random_val[20:0],random_val[31:21]};
    tq_cb_done_y                       = {random_val[21:0],random_val[31:22],random_val[21:0],random_val[31:22]};
    tq_cr_done_y                       = {random_val[22:0],random_val[31:23],random_val[22:0],random_val[31:23]};
    pred_luma_done_y                   = {random_val[23:0],random_val[31:24],random_val[23:0],random_val[31:24]};
    pred_cb_done_y                     = {random_val[24:0],random_val[31:25],random_val[24:0],random_val[31:25]};
    pred_cr_done_y                     = {random_val[25:0],random_val[31:26],random_val[25:0],random_val[31:26]};
    dram_rec_dec_we                    = {random_val[26:0],random_val[31:27],random_val[26:0],random_val[31:27]};
    dram_rec_dec_addrd                 = {random_val[27:0],random_val[31:28],random_val[27:0],random_val[31:28]};
    dram_rec_dec_did                   = {random_val[28:0],random_val[31:29],random_val[28:0],random_val[31:29]};
    dram_rec_cb_dec_we                 = {random_val[29:0],random_val[31:30],random_val[29:0],random_val[31:30]};
    dram_rec_cb_dec_addrd              = {random_val[30:0],random_val[31],random_val[30:0],random_val[31]};
    dram_rec_cb_dec_did                = {random_val[31:0],random_val[31:0]};
    dram_rec_cr_dec_we                 = {random_val,random_val};
    dram_rec_cr_dec_addrd              = {random_val[1:0],random_val[31:2],random_val[1:0],random_val[31:2]};
    dram_rec_cr_dec_did                = {random_val[2:0],random_val[31:3],random_val[2:0],random_val[31:3]};
    rec_x                              = {random_val[3:0],random_val[31:4],random_val[3:0],random_val[31:4]};
    rec_y                              = {random_val[4:0],random_val[31:5],random_val[4:0],random_val[31:5]};
    rec_y_pls1                         = {random_val[5:0],random_val[31:6],random_val[5:0],random_val[31:6]};
    rec_end_y                          = {random_val[6:0],random_val[31:7],random_val[6:0],random_val[31:7]};
    rec_width                          = {random_val[7:0],random_val[31:8],random_val[7:0],random_val[31:8]};
    rec_stage                          = {random_val[8:0],random_val[31:9],random_val[8:0],random_val[31:9]};
    rec_one_row                        = {random_val[9:0],random_val[31:10],random_val[9:0],random_val[31:10]};
    rec_one_row_clip                   = {random_val[10:0],random_val[31:11],random_val[10:0],random_val[31:11]};
    rec_one_row_right_most             = {random_val[11:0],random_val[31:12],random_val[11:0],random_val[31:12]};
    rec_pixel_right_most               = {random_val[12:0],random_val[31:13],random_val[12:0],random_val[31:13]};
    leftup_use_top                     = {random_val[13:0],random_val[31:14],random_val[13:0],random_val[31:14]};
    leftup_use_right_most              = {random_val[14:0],random_val[31:15],random_val[14:0],random_val[31:15]};
    bram_up_line_we                    = {random_val[15:0],random_val[31:16],random_val[15:0],random_val[31:16]};
    bram_up_line_addr                  = {random_val[16:0],random_val[31:17],random_val[16:0],random_val[31:17]};
    bram_up_line_din                   = {random_val[17:0],random_val[31:18],random_val[17:0],random_val[31:18]};
    up_line_store_done                 = {random_val[18:0],random_val[31:19],random_val[18:0],random_val[31:19]};
    up_line_fetch_addr                 = {random_val[19:0],random_val[31:20],random_val[19:0],random_val[31:20]};
    up_line_store_addr                 = {random_val[20:0],random_val[31:21],random_val[20:0],random_val[31:21]};
    up_line_fetch_i                    = {random_val[21:0],random_val[31:22],random_val[21:0],random_val[31:22]};
    up_line_store_i                    = {random_val[22:0],random_val[31:23],random_val[22:0],random_val[31:23]};
    bram_cb_up_line_we                 = {random_val[23:0],random_val[31:24],random_val[23:0],random_val[31:24]};
    bram_cb_up_line_addr               = {random_val[24:0],random_val[31:25],random_val[24:0],random_val[31:25]};
    bram_cb_up_line_din                = {random_val[25:0],random_val[31:26],random_val[25:0],random_val[31:26]};
    up_line_cb_store_done              = {random_val[26:0],random_val[31:27],random_val[26:0],random_val[31:27]};
    up_line_cb_fetch_addr              = {random_val[27:0],random_val[31:28],random_val[27:0],random_val[31:28]};
    up_line_cb_store_addr              = {random_val[28:0],random_val[31:29],random_val[28:0],random_val[31:29]};
    up_line_cb_fetch_i                 = {random_val[29:0],random_val[31:30],random_val[29:0],random_val[31:30]};
    up_line_cb_store_i                 = {random_val[30:0],random_val[31],random_val[30:0],random_val[31]};
    bram_cr_up_line_we                 = {random_val[31:0],random_val[31:0]};
    bram_cr_up_line_addr               = {random_val,random_val};
    bram_cr_up_line_din                = {random_val[1:0],random_val[31:2],random_val[1:0],random_val[31:2]};
    up_line_cr_store_done              = {random_val[2:0],random_val[31:3],random_val[2:0],random_val[31:3]};
    up_line_cr_fetch_addr              = {random_val[3:0],random_val[31:4],random_val[3:0],random_val[31:4]};
    up_line_cr_store_addr              = {random_val[4:0],random_val[31:5],random_val[4:0],random_val[31:5]};
    up_line_cr_fetch_i                 = {random_val[5:0],random_val[31:6],random_val[5:0],random_val[31:6]};
    up_line_cr_store_i                 = {random_val[6:0],random_val[31:7],random_val[6:0],random_val[31:7]};
    ctb_luma_rec_done                  = {random_val[7:0],random_val[31:8],random_val[7:0],random_val[31:8]};
    rec_cb_x                           = {random_val[8:0],random_val[31:9],random_val[8:0],random_val[31:9]};
    rec_cb_y                           = {random_val[9:0],random_val[31:10],random_val[9:0],random_val[31:10]};
    rec_cb_end_y                       = {random_val[10:0],random_val[31:11],random_val[10:0],random_val[31:11]};
    rec_cb_stage                       = {random_val[11:0],random_val[31:12],random_val[11:0],random_val[31:12]};
    rec_cb_width                       = {random_val[12:0],random_val[31:13],random_val[12:0],random_val[31:13]};
    rec_cb_one_row                     = {random_val[13:0],random_val[31:14],random_val[13:0],random_val[31:14]};
    rec_cb_one_row_clip                = {random_val[14:0],random_val[31:15],random_val[14:0],random_val[31:15]};
    rec_cb_one_row_right_most          = {random_val[15:0],random_val[31:16],random_val[15:0],random_val[31:16]};
    rec_cb_pixel_right_most            = {random_val[16:0],random_val[31:17],random_val[16:0],random_val[31:17]};
    ctb_cb_rec_done                    = {random_val[17:0],random_val[31:18],random_val[17:0],random_val[31:18]};
    cb_leftup_use_top                  = {random_val[18:0],random_val[31:19],random_val[18:0],random_val[31:19]};
    cb_leftup_use_right_most           = {random_val[19:0],random_val[31:20],random_val[19:0],random_val[31:20]};
    rec_cr_x                           = {random_val[20:0],random_val[31:21],random_val[20:0],random_val[31:21]};
    rec_cr_y                           = {random_val[21:0],random_val[31:22],random_val[21:0],random_val[31:22]};
    rec_cr_start_y                     = {random_val[22:0],random_val[31:23],random_val[22:0],random_val[31:23]};
    rec_cr_end_y                       = {random_val[23:0],random_val[31:24],random_val[23:0],random_val[31:24]};
    rec_cr_width                       = {random_val[24:0],random_val[31:25],random_val[24:0],random_val[31:25]};
    rec_cr_stage                       = {random_val[25:0],random_val[31:26],random_val[25:0],random_val[31:26]};
    rec_cr_one_row                     = {random_val[26:0],random_val[31:27],random_val[26:0],random_val[31:27]};
    rec_cr_one_row_clip                = {random_val[27:0],random_val[31:28],random_val[27:0],random_val[31:28]};
    rec_cr_one_row_right_most          = {random_val[28:0],random_val[31:29],random_val[28:0],random_val[31:29]};
    rec_cr_pixel_right_most            = {random_val[29:0],random_val[31:30],random_val[29:0],random_val[31:30]};
    ctb_cr_rec_done                    = {random_val[30:0],random_val[31],random_val[30:0],random_val[31]};
    cr_leftup_use_top                  = {random_val[31:0],random_val[31:0]};
    cr_leftup_use_right_most           = {random_val,random_val};
    filter_luma_done                   = {random_val[1:0],random_val[31:2],random_val[1:0],random_val[31:2]};
    filter_cb_done                     = {random_val[2:0],random_val[31:3],random_val[2:0],random_val[31:3]};
    filter_cr_done                     = {random_val[3:0],random_val[31:4],random_val[3:0],random_val[31:4]};
    bram_up_ctb_nf_we                  = {random_val[4:0],random_val[31:5],random_val[4:0],random_val[31:5]};
    bram_up_ctb_nf_addra               = {random_val[5:0],random_val[31:6],random_val[5:0],random_val[31:6]};
    bram_up_ctb_nf_dia                 = {random_val[6:0],random_val[31:7],random_val[6:0],random_val[31:7]};
    bram_up_ctb_qpy_we                 = {random_val[7:0],random_val[31:8],random_val[7:0],random_val[31:8]};
    bram_up_ctb_qpy_addra              = {random_val[8:0],random_val[31:9],random_val[8:0],random_val[31:9]};
    bram_up_ctb_qpy_dia                = {random_val[9:0],random_val[31:10],random_val[9:0],random_val[31:10]};
    rec_luma_sel                       = {random_val[10:0],random_val[31:11],random_val[10:0],random_val[31:11]};
    rec_cb_sel                         = {random_val[11:0],random_val[31:12],random_val[11:0],random_val[31:12]};
    rec_cr_sel                         = {random_val[12:0],random_val[31:13],random_val[12:0],random_val[31:13]};
    y_ddr_base                         = {random_val[13:0],random_val[31:14],random_val[13:0],random_val[31:14]};
    cb_ddr_base                        = {random_val[14:0],random_val[31:15],random_val[14:0],random_val[31:15]};
    cr_ddr_base                        = {random_val[15:0],random_val[31:16],random_val[15:0],random_val[31:16]};
    param_ddr_base                     = {random_val[16:0],random_val[31:17],random_val[16:0],random_val[31:17]};
    bram_up_ctb_mvf_we                 = {random_val[17:0],random_val[31:18],random_val[17:0],random_val[31:18]};
    bram_up_ctb_mvf_addr               = {random_val[18:0],random_val[31:19],random_val[18:0],random_val[31:19]};
    bram_up_ctb_mvf_din                = {random_val[19:0],random_val[31:20],random_val[19:0],random_val[31:20]};
    cur_ctb_ref_poc                    = {random_val[20:0],random_val[31:21],random_val[20:0],random_val[31:21]};
    xPb_right_bound                    = {random_val[21:0],random_val[31:22],random_val[21:0],random_val[31:22]};
    yPb_bottom_bound                   = {random_val[22:0],random_val[31:23],random_val[22:0],random_val[31:23]};
    store_ref_poc                      = {random_val[23:0],random_val[31:24],random_val[23:0],random_val[31:24]};
    up_mvf_fetch_stage                 = {random_val[24:0],random_val[31:25],random_val[24:0],random_val[31:25]};
    up_mvf_fetch_i                     = {random_val[25:0],random_val[31:26],random_val[25:0],random_val[31:26]};
    store_up_mvf_done                  = {random_val[26:0],random_val[31:27],random_val[26:0],random_val[31:27]};
    store_up_mvf_i                     = {random_val[27:0],random_val[31:28],random_val[27:0],random_val[31:28]};
    cond_kick_store_up_mvf             = {random_val[28:0],random_val[31:29],random_val[28:0],random_val[31:29]};
    rst_filter_luma                    = {random_val[29:0],random_val[31:30],random_val[29:0],random_val[31:30]};
    rst_filter_cb                      = {random_val[30:0],random_val[31],random_val[30:0],random_val[31]};
    rst_filter_cr                      = {random_val[31:0],random_val[31:0]};
    filter_luma_en                     = {random_val,random_val};
    filter_cb_en                       = {random_val[1:0],random_val[31:2],random_val[1:0],random_val[31:2]};
    filter_cr_en                       = {random_val[2:0],random_val[31:3],random_val[2:0],random_val[31:3]};
    nf_sel                             = {random_val[3:0],random_val[31:4],random_val[3:0],random_val[31:4]};
    nf                                 = {random_val[4:0],random_val[31:5],random_val[4:0],random_val[31:5]};
    xCtb_filtering                     = {random_val[5:0],random_val[31:6],random_val[5:0],random_val[31:6]};
    pu_info                            = {random_val[5:0],random_val[31:6],random_val[5:0],random_val[31:6]};
    pu_mvf                             = {random_val[5:0],random_val[31:6],random_val[5:0],random_val[31:6]};
    left_mvf                           = {random_val[5:0],random_val[31:6],random_val[5:0],random_val[31:6]};
    up_mvf                             = {random_val[5:0],random_val[31:6],random_val[5:0],random_val[31:6]};
    left_up_mvf                        = {random_val[5:0],random_val[31:6],random_val[5:0],random_val[31:6]};

end
`endif



endmodule
