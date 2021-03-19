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

module slice_data
(
 input wire                          clk                                 ,
 input wire                          rst                                 ,
 input wire                          global_rst                          ,
 input wire                          en                                  ,
 input wire              [ 7: 0]     i_rbsp_in_sd                        ,
 input wire                          i_cu_en                             ,
 input wire                          i_tu_en                             ,

 input wire              [ 5: 0]     i_SliceQpY                          ,
 input wire              [ 1: 0]     i_slice_type                        ,
 input wire                          i_slice_sao_luma_flag               ,
 input wire                          i_slice_sao_chroma_flag             ,
 input wire                          i_cabac_init_present_flag           ,
 input wire                          i_cabac_init_flag                   ,
 input wire                          i_transquant_bypass_enabled_flag    ,
 input wire    [`max_x_bits-1:0]     i_PicWidthInSamplesY                ,
 input wire    [`max_y_bits-1:0]     i_PicHeightInSamplesY               ,
 input wire              [ 2: 0]     i_five_minus_max_num_merge_cand     ,
 input wire                          i_amp_enabled_flag                  , //sps
 input wire              [ 2: 0]     i_max_transform_hierarchy_depth_intra,
 input wire              [ 2: 0]     i_max_transform_hierarchy_depth_inter,
 input wire                          i_cu_qp_delta_enabled_flag           , //pps
 input wire signed       [ 5: 0]     i_qp_cb_offset                       ,
 input wire signed       [ 5: 0]     i_qp_cr_offset                       ,

 input wire              [ 1: 0]     i_diff_cu_qp_delta_depth             , //pps

 input wire                          i_transform_skip_enabled_flag        , //pps
 input wire                          i_sign_data_hiding_enabled_flag      , //pps
 input wire                          i_constrained_intra_pred_flag        , //pps
 input wire                          i_strong_intra_smoothing_enabled_flag, //sps
 input wire signed       [ 3: 0]     i_slice_beta_offset_div2             ,
 input wire signed       [ 3: 0]     i_slice_tc_offset_div2               ,
 input wire              [ 3: 0]     i_num_ref_idx                        ,
 input wire              [ 2: 0]     i_log2_parallel_merge_level          ,
 input wire                          i_slice_temporal_mvp_enabled_flag    ,

 input wire              [ 8: 0]     i_leading9bits                       , //rbsp_buffer_simple

 input wire [`max_poc_bits-1:0]      i_cur_poc                            ,
 input rps_t                         i_slice_local_rps                    ,
 input wire[`max_ref-1:0][ 3: 0]     i_ref_dpb_slots                      ,
 input wire              [ 3: 0]     i_cur_pic_dpb_slot                   ,
 input wire              [ 3: 0]     i_col_ref_idx                        ,

 input wire              [31: 0]     fd_log                               ,
 input wire              [31: 0]     fd_pred                              ,
 input wire              [31: 0]     fd_intra_pred_chroma                 ,
 input wire              [31: 0]     fd_tq_luma                           ,
 input wire              [31: 0]     fd_tq_cb                             ,
 input wire              [31: 0]     fd_tq_cr                             ,
 input wire              [31: 0]     fd_filter                            ,
 input wire              [31: 0]     fd_deblock                           ,
 input wire              [63: 0]     i_pic_num                            ,

 input  wire                         m_axi_arready                        ,
 output wire                         m_axi_arvalid                        ,
 output wire             [ 3:0]      m_axi_arlen                          ,
 output wire             [31:0]      m_axi_araddr                         ,

 output wire                         m_axi_rready                         ,
 input  wire             [63:0]      m_axi_rdata                          ,
 input  wire                         m_axi_rvalid                         ,
 input  wire                         m_axi_rlast                          ,

 input  wire                         m_axi_awready                        ,
 output wire             [31:0]      m_axi_awaddr                         ,
 output wire             [ 3:0]      m_axi_awlen                          ,
 output wire                         m_axi_awvalid                        ,

 input  wire                         m_axi_wready                         ,
 output wire             [63:0]      m_axi_wdata                          ,
 output wire             [ 7:0]      m_axi_wstrb                          ,
 output wire                         m_axi_wlast                          ,
 output wire                         m_axi_wvalid                         ,

(*mark_debug="true"*)
 output reg              [ 4: 0]     o_slice_data_state                   ,
(*mark_debug="true"*)
 output wire             [ 2: 0]     o_forward_len_sd                     ,
 output wire             [ 5: 0]     o_cu_state                           ,
 output wire             [ 5: 0]     o_tu_state                           ,
(*mark_debug="true"*)
 output reg                          write_yuv                            


);

(*mark_debug="true"*)
reg                [ 3: 0]   sao_state                 ;
(*mark_debug="true"*)
reg                          cabac_rst                 ;
reg                          init_context_model        ;
(*mark_debug="true"*)
reg                          rst_cu                    ;
(*mark_debug="true"*)
reg                          rst_ctb                   ;
(*mark_debug="true"*)
reg                          rst_filter                ;

wire               [ 1: 0]   filter_stage              ;
wire                         ctb_rec_done              ;

reg                [ 2: 0]   cm_idx_sd                 ;
wire               [ 4: 0]   cm_idx_cu                 ;
wire               [ 5: 0]   cm_idx_xy_pref            ;
wire               [ 5: 0]   cm_idx_sig                ;
wire               [ 5: 0]   cm_idx_gt1_etc            ;


(*mark_debug="true"*)
reg                          dec_bin_en_sd             ;
(*mark_debug="true"*)
wire                         dec_bin_en_cu             ;
(*mark_debug="true"*)
wire                         dec_bin_en_xy_pref        ;
(*mark_debug="true"*)
wire                         dec_bin_en_sig            ;
(*mark_debug="true"*)
wire                         dec_bin_en_gt1_etc        ;
(*mark_debug="true"*)
reg                          byp_dec_en_sd             ;
(*mark_debug="true"*)
wire                         byp_dec_en_cu             ;
(*mark_debug="true"*)
wire                         byp_dec_en_tu             ;

(*mark_debug="true"*)
reg                          term_dec_en               ;
wire                         init_done                 ;

wire                         bin_sd                    ;
(*mark_debug="true"*)
wire                         bin_cu                    ;
wire                         bin_xy_pref               ;
wire                         bin_sig                   ;
wire                         bin_gt1_etc               ;
wire                         bin_byp                   ;
wire                         bin_term                  ;
wire                         dec_bin_valid             ;

(*mark_debug="true"*)
wire              [ 8: 0]    range                     ;
(*mark_debug="true"*)
wire              [ 8: 0]    offset                    ;

reg  [`max_ctb_x_bits-1:0]   xCtb                      ;
reg  [`max_ctb_y_bits-1:0]   yCtb                      ;
wire              [ 5: 0]    x                         ;
wire              [ 5: 0]    y                         ;

(*mark_debug="true"*)
reg               [15: 0]    slice_num                 ; //debug
reg               [ 2: 0]    cu_dec_stage              ;
reg               [ 2: 0]    Log2MinCuQpDeltaSize      ;
(*mark_debug="true"*)
reg               [ 2: 0]    log2CbSize                ;
(*mark_debug="true"*)
reg               [ 6: 0]    CbSize                    ;

(*mark_debug="true"*)
reg  [`max_x_bits-1:0]        x0                       ;
(*mark_debug="true"*)
reg  [`max_y_bits-1:0]        y0                       ;
reg  [`max_ctb_x_bits-1:0]    last_col_x_ctb           ;
reg  [`max_ctb_x_bits-1:0]    last_col_x_ctb_minus1    ;
reg  [`max_ctb_y_bits-1:0]    last_row_y_ctb           ;
reg  [`max_ctb_y_bits-1:0]    last_row_y_ctb_minus1    ;
reg                           last_col                 ;
reg                           last_row                 ;
reg                           first_col                ;
reg                           first_row                ;
reg                [ 6: 0]    last_col_width           ;
reg                [ 6: 0]    last_row_height          ;
wire               [ 5: 0]    x_end                    ;
wire               [ 5: 0]    y_end                    ;
reg                [ 5: 0]    x_qg                     ;
reg                [ 5: 0]    y_qg                     ;
reg                [ 5: 0]    x_qg_minus1              ;
reg                [ 5: 0]    y_qg_minus1              ;

reg                           end_of_slice_segment_flag;
reg                           cond_next_cu_new_qg      ; //next cu is new quantization group
reg                           first_cycle_cu_end       ;

assign x     = x0[5:0]; //CTB 64x64内部坐标
assign y     = y0[5:0];
assign x_end = x0[5:0]+CbSize[6:0];
assign y_end = y0[5:0]+CbSize[6:0];
//Log2MinCuQpDeltaSize只考虑4,5,6
always @ (posedge clk)
begin
    x_qg        <= Log2MinCuQpDeltaSize == 6?0:
                   (Log2MinCuQpDeltaSize==5?{x0[5],5'd0}:{x0[5:4],4'd0});
    y_qg        <= Log2MinCuQpDeltaSize == 6?0:
                   (Log2MinCuQpDeltaSize==5?{y0[5],5'd0}:{y0[5:4],4'd0});
    x_qg_minus1 <= Log2MinCuQpDeltaSize == 6?0:
                   (Log2MinCuQpDeltaSize==5?{x0[5],5'd0}-1:{x0[5:4],4'd0}-1);
    y_qg_minus1 <= Log2MinCuQpDeltaSize == 6?0:
                   (Log2MinCuQpDeltaSize==5?{y0[5],5'd0}-1:{y0[5:4],4'd0}-1);

end

(*mark_debug="true"*)
reg                [ 1: 0]    dep_partIdx[0:3]         ; //正在解析的cu在当前depth的index,64,32,16,8 4层,第0层用不到,浪费2bit reg无所谓了




reg                [ 1: 0]   cIdx                      ;
reg                [ 2: 0]   i                         ; //32x32TU最多含64个4x4 sub block
reg                [ 3: 0]   j                         ;
reg                [ 1: 0]   partIdx                   ;



reg                           bram_CtDepth_up_we       ;
reg [`max_ctb_x_bits-1:0]     bram_CtDepth_up_addr     ;
//1ctb 2bit * 8
reg                [15: 0]    bram_CtDepth_up_din      ;
wire               [15: 0]    bram_CtDepth_up_dout     ;

//CtDepth 0,1,2,3 2bit, 1个ctb 8个cu，16bit一起存取
ram #(`max_ctb_x_bits, 16) bram_CtDepth_up  //可能不需要放到ram,1920/8*2=480bit
(
     .clk(clk),
     .en(1'b1),
     .we(bram_CtDepth_up_we),
     .addr(bram_CtDepth_up_addr),
     .data_in(bram_CtDepth_up_din),
     .data_out(bram_CtDepth_up_dout)
 );

reg                [ 1: 0]    cqtDepth                 ; //current depth
reg                [ 1: 0]    CtDepth_left[0:7]        ;
reg                [ 1: 0]    CtDepth_up[0:7]          ;
wire                          cond_reach_pic_right     ;
wire                          cond_reach_pic_bottom    ;

assign cond_reach_pic_right=last_col&&x0[5:3] + CbSize[6:3] >= last_col_width[6:3];
assign cond_reach_pic_bottom=last_row&&y0[5:3] + CbSize[6:3] >= last_row_height[6:3];

reg                [ 1: 0]    cqt_left                 ;
reg                [ 1: 0]    cqt_up                   ;
reg                           condL                    ;
reg                           condA                    ;



always @(*)
begin
    cqt_left = CtDepth_left[y0[5:3]];
    condL = cqt_left > cqtDepth ? 1 : 0;
end


always @(*)
begin
    cqt_up =  CtDepth_up[x0[5:3]];
    condA = cqt_up > cqtDepth ? 1 : 0;
end


reg                           IsCuQpDeltaCoded        ;
wire                          cu_dqp_dec_in_tu        ;
reg                [ 5:0]     qPY_A                   ;
reg                [ 5:0]     qPY_B                   ;
reg                [ 5:0]     qPY_PRED                ;



reg  signed        [ 5:0]     qp_cb_offset            ;
reg  signed        [ 5:0]     qp_cr_offset            ;
reg                [ 5:0]     QpY_PREV                ;
reg                [ 5:0]     QpY                     ;
wire               [ 5:0]     QpY_tu                  ;


reg                           qpy_sel    ;
reg  [1:0][7:0][7:0][5:0]     qpy        ;


always @(posedge clk)
if (rst) begin
    qpy_sel        <= 0;
end else if (rst_ctb|rst_filter) begin
    qpy_sel        <= ~qpy_sel;
end else begin
    if (o_slice_data_state == `rst_slice_data) begin

    end else if (o_slice_data_state == `slice_parse_cu &&
        o_cu_state == `cu_end&&first_cycle_cu_end) begin

        if (CbSize[6] == 1) begin
            qpy[qpy_sel]                                    <= {64{QpY}};
        end else if (CbSize[5] == 1) begin
            qpy[qpy_sel][{y0[5],2'b00}  ][{x0[5],2'b00}  ]  <=  QpY;
            qpy[qpy_sel][{y0[5],2'b00}  ][{x0[5],2'b00}+1]  <=  QpY;
            qpy[qpy_sel][{y0[5],2'b00}  ][{x0[5],2'b00}+2]  <=  QpY;
            qpy[qpy_sel][{y0[5],2'b00}  ][{x0[5],2'b00}+3]  <=  QpY;
            qpy[qpy_sel][{y0[5],2'b00}+1][{x0[5],2'b00}  ]  <=  QpY;
            qpy[qpy_sel][{y0[5],2'b00}+1][{x0[5],2'b00}+1]  <=  QpY;
            qpy[qpy_sel][{y0[5],2'b00}+1][{x0[5],2'b00}+2]  <=  QpY;
            qpy[qpy_sel][{y0[5],2'b00}+1][{x0[5],2'b00}+3]  <=  QpY;
            qpy[qpy_sel][{y0[5],2'b00}+2][{x0[5],2'b00}  ]  <=  QpY;
            qpy[qpy_sel][{y0[5],2'b00}+2][{x0[5],2'b00}+1]  <=  QpY;
            qpy[qpy_sel][{y0[5],2'b00}+2][{x0[5],2'b00}+2]  <=  QpY;
            qpy[qpy_sel][{y0[5],2'b00}+2][{x0[5],2'b00}+3]  <=  QpY;
            qpy[qpy_sel][{y0[5],2'b00}+3][{x0[5],2'b00}  ]  <=  QpY;
            qpy[qpy_sel][{y0[5],2'b00}+3][{x0[5],2'b00}+1]  <=  QpY;
            qpy[qpy_sel][{y0[5],2'b00}+3][{x0[5],2'b00}+2]  <=  QpY;
            qpy[qpy_sel][{y0[5],2'b00}+3][{x0[5],2'b00}+3]  <=  QpY;

        end else if (CbSize[4] == 1) begin
            qpy[qpy_sel][{y0[5:4],1'b0}  ][{x0[5:4],1'b0}  ] <= QpY;
            qpy[qpy_sel][{y0[5:4],1'b0}+1][{x0[5:4],1'b0}  ] <= QpY;
            qpy[qpy_sel][{y0[5:4],1'b0}  ][{x0[5:4],1'b0}+1] <= QpY;
            qpy[qpy_sel][{y0[5:4],1'b0}+1][{x0[5:4],1'b0}+1] <= QpY;
        end else begin
            qpy[qpy_sel][y0[5:3]  ][x0[5:3]  ]               <= QpY;
        end

    end

end

always @ (posedge clk)
begin
    if (x0[5:0] == 0||x_qg[5:0]==0)
        qPY_A       <= QpY_PREV;
    else
        qPY_A       <= qpy[qpy_sel][y_qg[5:3]][x_qg_minus1[5:3]];
    if (y0[5:0] == 0||y_qg[5:0]==0)
        qPY_B       <= QpY_PREV;
    else
        qPY_B       <= qpy[qpy_sel][y_qg_minus1[5:3]][x_qg[5:3]];
end


sao_params_t                  sao_param               ;
sao_params_t                  sao_param_left          ;
sao_params_t                  sao_param_up            ;
sao_params_t                  sao_param_leftup        ;

reg                [ 2: 0]    sao_offset_r            ;

reg                           bram_sao_up_we          ;
reg [`max_ctb_x_bits-1:0]     bram_sao_up_addr        ;
reg [$bits(sao_params_t)-1:0] bram_sao_up_din         ;
wire[$bits(sao_params_t)-1:0] bram_sao_up_dout        ;

ram #(`max_ctb_x_bits, $bits(sao_params_t)) bram_sao_param_up_ctb
(
     .clk(clk),
     .en(1'b1),
     .we(bram_sao_up_we),
     .addr(bram_sao_up_addr),
     .data_in(bram_sao_up_din),
     .data_out(bram_sao_up_dout)
);




always @ (posedge clk)
if (global_rst) begin
    write_yuv                                    <= 0;
    rst_cu                                       <= 0;
    o_slice_data_state                           <= `slice_data_end;
end else if (rst)
begin
    o_slice_data_state                           <= 0;
    dep_partIdx                                  <= '{2'b00,2'b00,2'b00,2'b00};
    dec_bin_en_sd                                <= 0;
    byp_dec_en_sd                                <= 0;
    term_dec_en                                  <= 0;
    cm_idx_sd                                    <= 255; //invalid idx
    cabac_rst                                    <= 0;
    init_context_model                           <= 0;
    cIdx                                         <= 0;
    sao_param                                    <= 0;
    i                                            <= 0;
    rst_cu                                       <= 0;
    slice_num                                    <= i_pic_num[31:0];
    qp_cb_offset                                 <= i_qp_cb_offset;
    qp_cr_offset                                 <= i_qp_cr_offset;
    rst_filter                                   <= 0;
    CtDepth_up                                   <=  '{8{2'b00}};
    CtDepth_left                                 <=  '{8{2'b00}};
    bram_CtDepth_up_we                           <= 0;

end else begin
    if (en) begin
        case (o_slice_data_state)

            `parse_sao_ctb://2
                case (sao_state)
                    `sao_merge_left_flag_s://1
                        if (dec_bin_valid) begin
                            sao_param.sao_merge_left_flag           <= bin_sd;
                            if (`log_i && slice_num>=`slice_begin && slice_num<=`slice_end)
                                $fdisplay(fd_log, "parse_sao_merge return %0d ivlCurrRange %x ivlOffset %x",
                                    bin_sd, range, offset);

                            if (bin_sd == 0 && y0 > 0) begin
                                cm_idx_sd                           <= 0;
                                sao_state                           <= `sao_merge_up_flag_s;
                            end else begin
                                dec_bin_en_sd                       <= 0;
                                sao_param.sao_merge_up_flag         <= 0;
                                sao_state                           <= `merge_or_parse;
                            end
                        end
                     `sao_merge_up_flag_s://2
                         if (dec_bin_valid) begin
                             sao_param.sao_merge_up_flag            <= bin_sd;
                             if (`log_i && slice_num>=`slice_begin && slice_num<=`slice_end)
                                 $fdisplay(fd_log, "parse_sao_merge return %0d ivlCurrRange %x ivlOffset %x",
                                     bin_sd, range, offset);
                             dec_bin_en_sd                          <= 0;
                             sao_state                              <= `merge_or_parse;
                         end


                     `parse_sao_type_idx1://6
                         if (dec_bin_valid == 1) begin
                             if (`log_i && slice_num>=`slice_begin && slice_num<=`slice_end)
                                 $fdisplay(fd_log, "parse_sao_type_idx bin return %0d ivlCurrRange %x ivlOffset %x",
                                    bin_sd,range, offset);

                             dec_bin_en_sd                     <= 0;
                             if (bin_sd) begin
                                 byp_dec_en_sd                 <= 1;
                                 sao_state                     <= `parse_sao_type_idx2;
                             end else begin
                                 sao_param.sao_type_idx[cIdx]  <= 0;
                                 if (`log_i && slice_num>=`slice_begin && slice_num<=`slice_end)
                                     $fdisplay(fd_log, "parse_sao_type_idx return 0");

                                 sao_state                     <= `merge_or_parse;
                                 cIdx                          <= cIdx+1;
                             end
                         end

                      `parse_sao_type_idx2://7
                          begin
                              if (`log_i && slice_num>=`slice_begin && slice_num<=`slice_end)
                                  $fdisplay(fd_log, "parse_sao_type_idx byp return %0d ivlCurrRange %x ivlOffset %x",
                                    bin_byp,range, offset);

                              if (bin_byp == 0)
                                  sao_param.sao_type_idx[cIdx] <= 1;
                              else
                                  sao_param.sao_type_idx[cIdx] <= 2;
                              if (`log_i && slice_num>=`slice_begin && slice_num<=`slice_end)
                                  $fdisplay(fd_log, "parse_sao_type_idx return %0d",
                                   bin_byp+1);

                              sao_param.sao_offset[cIdx][0]    <= 0;
                              byp_dec_en_sd                    <= 1;
                              i                                <= 1;
                              sao_state                        <= `parse_sao_tr;
                              sao_offset_r                     <= 0;
                          end

                       // for (i = 0; i < 4; i++)
                            //sao_offset_abs spec cMax = (1 << (Min(bitDepth, 10) - 5)) - 1, cRiceParam = 0
                        //    parse_sao_tr(rbsp, &sao->sao_offset[cIdx][i+1], (1 << 3) - 1);
                        //sao->sao_offset[cIdx][0] = 0,从1开始解
                     `parse_sao_tr: begin//8
                         if (`log_i && slice_num>=`slice_begin && slice_num<=`slice_end)
                             $fdisplay(fd_log, "parse_sao_tr byp return %d ivlCurrRange %x ivlOffset %x",
                              bin_byp,range,offset);

                         if (bin_byp == 0) begin
                             sao_state                         <= `done_one_tr;
                             byp_dec_en_sd                     <= 0;
                         end else begin
                             sao_offset_r                      <= sao_offset_r+1;
                             if (sao_offset_r == 6) begin //cMax=7
                                 sao_state                     <= `done_one_tr;
                                 byp_dec_en_sd                 <= 0;
                             end
                         end
                     end

                     `sao_offset_sign_s:
                         begin
                             if (bin_byp == 1)
                                 sao_param.sao_offset[cIdx][i] <= ~sao_param.sao_offset[cIdx][i]+1;
                             if (`log_i && slice_num>=`slice_begin && slice_num<=`slice_end)
                                 $fdisplay(fd_log, "sao_offset_sign %0d ivlCurrRange %x ivlOffset %x",
                                  bin_byp, range, offset);

                             i                                 <= i+1;
                             if (i == 4) begin
                                 i                             <= 0;
                                 sao_state                     <= `sao_band_position_s;
                             end else begin
                                 byp_dec_en_sd                 <= 0;
                                 sao_state                     <= `band_or_edge;
                             end
                         end

                     `sao_band_position_s: //cMax=31,fixedLength=5
                         begin
                             if (`log_i && slice_num>=`slice_begin && slice_num<=`slice_end)
                                 $fdisplay(fd_log, "bypass binVal %d ivlCurrRange %x ivlOffset %x", bin_byp, range, offset);

                             i                                 <= i+1;
                             sao_param.sao_band_position[cIdx] <= {sao_param.sao_band_position[cIdx][3:0],bin_byp};
                             if (i==4) begin
                                 if (`log_i && slice_num>=`slice_begin && slice_num<=`slice_end)
                                     $fdisplay(fd_log, "sao_band_position %0d", {sao_param.sao_band_position[cIdx][3:0],bin_byp});

                                 byp_dec_en_sd                 <= 0;
                                 sao_state                     <= `merge_or_parse; //下一个cIdx
                                 cIdx                          <= cIdx + 1;
                             end
                         end

                     `sao_eo_class_s: //c cMax=3,fixedLength=2
                         begin
                             if (`log_i && slice_num>=`slice_begin && slice_num<=`slice_end)
                                 $fdisplay(fd_log, "bypass binVal %d ivlCurrRange %x ivlOffset %x", bin_byp, range, offset);

                             i                                 <= i+1;
                             sao_param.sao_eo_class[cIdx]      <= {sao_param.sao_eo_class[cIdx][0], bin_byp};
                             if (i == 1) begin
                                 if (`log_i && slice_num>=`slice_begin && slice_num<=`slice_end)
                                     $fdisplay(fd_log, "sao_eo_class %0d", {sao_param.sao_eo_class[cIdx][0], bin_byp});

                                 byp_dec_en_sd           <= 0;
                                 sao_state               <= `merge_or_parse; //下一个cIdx
                                 cIdx                    <= cIdx + 1;
                             end
                         end

                     endcase

            `split_cu_flag_s://4
                begin
                    if (dec_bin_valid) begin
                        dec_bin_en_sd                    <= 0;
                        if (`log_i && slice_num>=`slice_begin && slice_num<=`slice_end)
                            $fdisplay(fd_log, "parse_split_cu_flag return %0d ctxInc %0d ivlCurrRange %x ivlOffset %x",
                             bin_sd, cm_idx_sd-`CM_IDX_SPLIT_CU_FLAG, range, offset);

                        if (bin_sd) begin
                            dep_partIdx[cqtDepth+1]      <= 0;
                            partIdx                      <= 0; //to debug

                            cqtDepth                     <= cqtDepth + 1;
                            CbSize                       <= CbSize >> 1;
                            log2CbSize                   <= log2CbSize-1;

                            o_slice_data_state           <= `split_cu_flag_ctx;
                        end else begin

                            o_slice_data_state           <= `slice_data_pass2cu;
                            rst_cu                       <= 1;
                        end
                    end

                end

            `ctb_end://0x8 fix,`ctb_end需要放在if(en)下，term_dec完成依赖rbsp_valid
                begin
                    if (ctb_rec_done&&filter_stage==`reset_filtering) begin

                        x0[`max_x_bits-1:3]            <= x0[`max_x_bits-1:3]+CbSize[6:3];
                        xCtb                           <= xCtb+1;
                        if (xCtb == last_col_x_ctb_minus1)
                            last_col                   <= 1;
                        else
                            last_col                   <= 0;

                        if (last_col) begin
                            x0                         <= 0;
                            xCtb                       <= 0;
                            first_col                  <= 1;
                            first_row                  <= 0;
                            yCtb                       <= yCtb+1;
                            y0[`max_y_bits-1:3]        <= y0[`max_y_bits-1:3]+CbSize[6:3];
                            if (yCtb == last_row_y_ctb_minus1)
                                last_row               <= 1;

                        end else begin
                            //不是最后一列ctb，y0是要回跳64的
                            y0[5:0]                    <= 0;
                            first_col                  <= 0;
                        end

                        //每个ctb在这里从up预取,在下面merge_or_parse保存
                        bram_CtDepth_up_we             <= 0;
                        bram_CtDepth_up_addr           <= last_col?0:xCtb+1;

                        if (last_col && last_row) begin
                            //不能reset ctb，只要启动最后一块ctb filter
                            o_slice_data_state         <= `ctb_end_2;
                            rst_filter                 <= 1;
                        end else begin
                            o_slice_data_state         <= `parse_sao_ctb;

                            sao_state                  <= `rst_sao;
                            rst_ctb                    <= 1;
                        end

                    end
                    term_dec_en                        <= 0;
                end

            //default: o_slice_data_state                <= `rst_slice_data;
        endcase
    end

    case (o_slice_data_state)

        `parse_sao_ctb://2
            case (sao_state)
                `rst_sao: begin
                    rst_ctb                                <= 0;
                    cIdx                                   <= 0;
                    if ((~i_slice_sao_luma_flag)&&(~i_slice_sao_chroma_flag)) begin
                        sao_param.sao_type_idx             <= 6'd0;
                        sao_state                          <= `sao_store; //fix,0也要存起来
                    end else if (x0 > 0) begin
                        dec_bin_en_sd                      <= 1;
                        cm_idx_sd                          <= 0;
                        sao_state                          <= `sao_merge_left_flag_s;
                    end else begin
                        sao_param.sao_merge_left_flag      <= 0;
                        if (y0 > 0) begin
                            dec_bin_en_sd                  <= 1;
                            cm_idx_sd                      <= 0;
                            sao_state                      <= `sao_merge_up_flag_s;
                        end else begin
                            sao_param.sao_merge_up_flag    <= 0;
                            sao_state                      <= `merge_or_parse;
                        end
                    end
                    if (y0 == 0) begin
                        CtDepth_up                         <=  '{8{2'b00}};
                    end
                    if (x0 == 0) begin
                        CtDepth_left                       <=  '{8{2'b00}};
                    end
                    bram_sao_up_we                         <= 0;
                    bram_sao_up_addr                       <= xCtb;
                    sao_param_left                         <= sao_param; //保存left为上一块ctb，就是刚刚解过的那个ctb的sao

                end

                 `merge_or_parse: begin//3
                     if (sao_param.sao_merge_left_flag == 0) begin
                         if (sao_param.sao_merge_up_flag == 0) begin

                             if (cIdx == 0 && i_slice_sao_luma_flag == 0 ||
                                 cIdx != 0 && i_slice_sao_chroma_flag == 0) begin
                                 sao_param.sao_type_idx[cIdx]   <= 0;
                                 cIdx                           <= cIdx + 1;
                                 if (cIdx == 2)
                                     sao_state                  <= `sao_store;
                             end else if (cIdx==3) begin
                                 sao_state                      <= `sao_store;
                             end else  begin
                                 if (cIdx == 2) begin
                                     sao_param.sao_type_idx[2] <= sao_param.sao_type_idx[1];
                                     if (sao_param.sao_type_idx[1] == 0)
                                         sao_state         <= `sao_store;
                                     else begin
                                         sao_param.sao_offset[cIdx][0]    <= 0;
                                         byp_dec_en_sd                    <= 1;
                                         i                                <= 1;
                                         sao_state                        <= `parse_sao_tr;
                                         sao_offset_r                     <= 0;
                                     end
                                 end else begin
                                     dec_bin_en_sd         <= 1;
                                     cm_idx_sd             <= `CM_IDX_SAO_TYPE;
                                     sao_state             <= `parse_sao_type_idx1;//6
                                 end
                             end
                         end else begin
                             sao_state                     <= `merge_fetch_up;
                         end
                     end else begin
                         sao_state                         <= `merge_fetch_left;
                     end

                 end

                 `merge_fetch_up:
                     begin
                         sao_param                         <= bram_sao_up_dout;
                         sao_state                         <= `sao_store;
                     end

                 `merge_fetch_left:
                     begin
                         //sao_param等于上次解过的那个，也就是维持不变
                         sao_state                         <= `sao_store;
                     end

                 `done_one_tr://e
                     begin
                         sao_param.sao_offset[cIdx][i]     <= sao_offset_r;
                         if (`log_i && slice_num>=`slice_begin && slice_num<=`slice_end)
                             $fdisplay(fd_log, "parse_sao_tr return %d", sao_offset_r);

                         i                                 <= i+1;
                         if (i == 4) begin
                             i                             <= 1; //sao_offset[cIdx][0]=0
                             sao_state                     <= `band_or_edge; //9 break
                         end else begin
                             sao_offset_r                  <= 0;
                             sao_state                     <= `parse_sao_tr;
                             byp_dec_en_sd                 <= 1;
                         end
                     end

                 `band_or_edge://9
                     if (sao_param.sao_type_idx[cIdx] == 1) begin//band
                         sao_param.sao_band_position[cIdx] <= 0;

                         if (sao_param.sao_offset[cIdx][i] != 0) begin
                             byp_dec_en_sd                 <= 1;
                             sao_state                     <= `sao_offset_sign_s;
                         end else begin
                             i                             <= i+1;
                             if (i == 4) begin
                                 i                         <= 0;
                                 byp_dec_en_sd             <= 1;
                                 sao_state                 <= `sao_band_position_s;
                             end
                         end
                     end else if (sao_param.sao_type_idx[cIdx] == 2) begin //edge
                         sao_param.sao_offset[cIdx][3]     <= ~sao_param.sao_offset[cIdx][3]+1;
                         sao_param.sao_offset[cIdx][4]     <= ~sao_param.sao_offset[cIdx][4]+1;
                         if (cIdx == 2) begin
                             sao_param.sao_eo_class[2]     <= sao_param.sao_eo_class[1];
                             byp_dec_en_sd                 <= 0;
                             cIdx                          <= cIdx+1;
                             sao_state                     <= `merge_or_parse;
                         end else begin
                             byp_dec_en_sd                 <= 1;
                             sao_param.sao_eo_class[cIdx]  <= 0;
                             i                             <= 0;
                             sao_state                     <= `sao_eo_class_s;//c
                         end
                     end

                 `sao_store:
                     begin
                         bram_sao_up_we              <= 1;
                         bram_sao_up_addr            <= xCtb;
                         bram_sao_up_din             <= sao_param;
                         sao_param_up                <= bram_sao_up_dout;
                         sao_param_leftup            <= sao_param_up;
                         sao_state                   <= `sao_end;
                     end
                 `sao_end:
                     begin
                         if (y0 > 0) begin

                            CtDepth_up               <= '{bram_CtDepth_up_dout[15:14], //CtDepth_up[0]
                                                                   bram_CtDepth_up_dout[13:12],
                                                                   bram_CtDepth_up_dout[11:10],
                                                                   bram_CtDepth_up_dout[9:8],
                                                                   bram_CtDepth_up_dout[7:6],
                                                                   bram_CtDepth_up_dout[5:4],
                                                                   bram_CtDepth_up_dout[3:2],
                                                                   bram_CtDepth_up_dout[1:0]}; //CtDepth_up[7]
                         end

                        cqtDepth                     <= 0; //必须在split_cu_cm_idx之前准备好
                        CbSize                       <= 64;
                        log2CbSize                   <= 6;
                        dep_partIdx                  <= '{2'b00,2'b00,2'b00,2'b00};
                        o_slice_data_state           <= `split_cu_flag_ctx;
                     end

                 endcase


        `rst_slice_data:
            begin
                init_context_model               <= 1;
                x0                               <= 0;
                y0                               <= 0;
                xCtb                             <= 0;
                yCtb                             <= 0;
                o_slice_data_state               <= `slice_data_delay_1cycle;
                cabac_rst                        <= 1;

                last_col_x_ctb                   <= ((i_PicWidthInSamplesY-1)>>6);
                last_col_x_ctb_minus1            <= ((i_PicWidthInSamplesY-1)>>6)-1;
                last_row_y_ctb                   <= ((i_PicHeightInSamplesY-1)>>6);
                last_row_y_ctb_minus1            <= ((i_PicHeightInSamplesY-1)>>6)-1;
                last_col                         <= 0;
                last_row                         <= 0;
                first_col                        <= 1;
                first_row                        <= 1;
                QpY                              <= i_SliceQpY;
                QpY_PREV                         <= i_SliceQpY;
                Log2MinCuQpDeltaSize             <= 6-i_diff_cu_qp_delta_depth;

            end

        `slice_data_delay_1cycle://6
            begin
                cabac_rst                        <= 0;
                o_slice_data_state               <= `init_cabac_context;
                last_col_width                   <=  i_PicWidthInSamplesY - (last_col_x_ctb<<6);
                last_row_height                  <=  i_PicHeightInSamplesY - (last_row_y_ctb<<6);
            end
        `init_cabac_context://1
            begin

               if (init_done == 1) begin //todo
                    init_context_model                     <= 0;
                    o_slice_data_state                     <= `parse_sao_ctb;
                    rst_ctb                                <= 1;
                    sao_state                              <= `rst_sao;
                end
            end

        `split_cu_flag_ctx://3
            begin
                if (log2CbSize > `MinCbLog2SizeY &&
                    (last_col==0||x0[5:3] + CbSize[6:3] <= last_col_width[6:3]) &&
                    (last_row==0||y0[5:3] + CbSize[6:3] <= last_row_height[6:3])) begin

                    cm_idx_sd                        <= `CM_IDX_SPLIT_CU_FLAG + condA + condL;
                    dec_bin_en_sd                    <= 1;
                    o_slice_data_state               <= `split_cu_flag_s;
                end else begin
                    //split_cu_flag = log2CbSize > MinCbLog2SizeY
                    if (log2CbSize > `MinCbLog2SizeY) begin

                        cqtDepth                     <= cqtDepth + 1;
                        CbSize                       <= CbSize >> 1;
                        log2CbSize                   <= log2CbSize-1;
                        o_slice_data_state           <= `split_cu_flag_ctx;
                        dep_partIdx[cqtDepth+1]      <= 0;
                        partIdx                      <= 0; //to debug
                        // ---------------
                        //|  32x32  |16x32|  走到16x32这块，自动split一次
                        //|         |     |
                        //| --------------
                        //|         |     |
                        //|         |     |
                        // ---------------
                        if (`log_v && slice_num>=`slice_begin && slice_num<=`slice_end) begin
                            if (last_col && x0[5:3] + CbSize[6:3] > last_col_width[6:3])
                                $fdisplay(fd_log, "reach right boundary,right half has nothing,split");
                            else if (last_row && y0[5:3] + CbSize[6:3] > last_row_height[6:3])
                                $fdisplay(fd_log, "reach bottom,bottom half has nothing,split");
                        end
                    end else begin
                        o_slice_data_state           <= `slice_data_pass2cu;
                        rst_cu                       <= 1;

                        //reset cu需要在这里做，到`slice_parse_cu时cu的状态变为0，
                        //在`slice_data_pass2cu做的话，到`slice_parse_cu,cu的状态为上次的`cu_end_2,
                        //一进来就开始走dep_partIdx[cqtDepth]+1的路, 同理reset tu也是如此
                    end
                end
                if (log2CbSize >= Log2MinCuQpDeltaSize)
                    IsCuQpDeltaCoded                 <= 0;

            end
        `slice_data_pass2cu://7
            begin
                //从`split_cu_flag_s移到这里，去掉对bin_sd依赖，减少路径
                if (cqtDepth == 0) begin
                    CtDepth_up                       <=  '{8{2'b00}};
                    CtDepth_left                     <=  '{8{2'b00}};
                end else if (cqtDepth == 1) begin
                    CtDepth_up[{x0[5],2'b00}]        <= 1;
                    CtDepth_up[{x0[5],2'b01}]        <= 1;
                    CtDepth_up[{x0[5],2'b10}]        <= 1;
                    CtDepth_up[{x0[5],2'b11}]        <= 1;
                    CtDepth_left[{y0[5],2'b00}]      <= 1;
                    CtDepth_left[{y0[5],2'b01}]      <= 1;
                    CtDepth_left[{y0[5],2'b10}]      <= 1;
                    CtDepth_left[{y0[5],2'b11}]      <= 1;
                end else if (cqtDepth == 2) begin
                    CtDepth_up[{x0[5:4],1'b0}]       <= 2;
                    CtDepth_up[{x0[5:4],1'b1}]       <= 2;

                    CtDepth_left[{y0[5:4],1'b0}]     <= 2;
                    CtDepth_left[{y0[5:4],1'b1}]     <= 2;

                end else begin//if (cqtDepth == 3) begin
                    CtDepth_up[x0[5:3]]              <= 3;
                    CtDepth_left[y0[5:3]]            <= 3;
                end

                cu_dec_stage                         <= 0;

                cond_next_cu_new_qg                  <= (cond_reach_pic_right||
                                                        (Log2MinCuQpDeltaSize==6 &&x_end[5:0]==0)||
                                                        (Log2MinCuQpDeltaSize==5 &&x_end[4:0]==0)||
                                                        (Log2MinCuQpDeltaSize==4 &&x_end[4:0]==0)) &&
                                                        (cond_reach_pic_bottom||
                                                        (Log2MinCuQpDeltaSize==6 &&y_end[5:0]==0)||
                                                        (Log2MinCuQpDeltaSize==5 &&y_end[4:0]==0)||
                                                        (Log2MinCuQpDeltaSize==4 &&y_end[4:0]==0));
                first_cycle_cu_end                   <= 1;
                o_slice_data_state                   <= `slice_parse_cu;
            end
        `slice_parse_cu://5
            begin
                rst_cu                               <= 0;
                if (cu_dec_stage == 0) begin
                    qPY_PRED                         <= (qPY_A + qPY_B + 1) >> 1;
                    cu_dec_stage                     <= 1;
                end
                if (o_cu_state == `parse_tu&&i_cu_qp_delta_enabled_flag) begin
                    if (o_tu_state == `tu_end) begin
                        IsCuQpDeltaCoded             <= cu_dqp_dec_in_tu;
                        if (cu_dqp_dec_in_tu) begin
                            QpY                      <= QpY_tu;
                        end else begin
                            QpY                      <= qPY_PRED;
                        end
                    end
                end

                if (o_cu_state == `cu_end) begin
                    first_cycle_cu_end               <= 0;
                    if (first_cycle_cu_end&&IsCuQpDeltaCoded==0&&
                        i_cu_qp_delta_enabled_flag) begin
                        if (`log_i && slice_num>=`slice_begin && slice_num<=`slice_end)
                            $fdisplay(fd_log, "xBase %0d yBase %0d qPy_pred %0d qPy %0d",
                             x0,y0,QpY,QpY);
                    end
                    if (IsCuQpDeltaCoded) begin
                        if (cond_next_cu_new_qg)
                            QpY_PREV                 <= QpY_tu;
                    end else begin
                        if (cond_next_cu_new_qg)
                            QpY_PREV                 <= qPY_PRED;
                    end
                    //开始存qpy，store_qpy = 1放到另一个always块

                    if (cqtDepth == 0) begin
                        if (`log_v && slice_num>=`slice_begin && slice_num<=`slice_end)
                            $fdisplay(fd_log, "CTB finish x0 %d y0 %d", x0, y0);

                        o_slice_data_state           <= `ctb_end;
                        term_dec_en                  <= 1;

                        //存入
                        bram_CtDepth_up_we           <= 1;
                        bram_CtDepth_up_addr         <= x0[`max_x_bits-1:6];
                        bram_CtDepth_up_din          <= {CtDepth_up[0],//bram_CtDepth_up_din[15:14]
                                                         CtDepth_up[1],
                                                         CtDepth_up[2],
                                                         CtDepth_up[3],
                                                         CtDepth_up[4],
                                                         CtDepth_up[5],
                                                         CtDepth_up[6],
                                                         CtDepth_up[7]};//bram_CtDepth_up_din[1:0]

                    end else begin

                        if (`log_v && slice_num>=`slice_begin && slice_num<=`slice_end)
                            $fdisplay(fd_log, "%t cqtDepth %d  dep_partIdx[%d] %d x0 %d y0 %d",
                             $time,cqtDepth,cqtDepth,dep_partIdx[cqtDepth], x0,y0);

                        if (cond_reach_pic_bottom &&cond_reach_pic_right) begin
                                if (`log_v && slice_num>=`slice_begin && slice_num<=`slice_end)
                                    $fdisplay(fd_log, "reach right boundary and bottom");
                                cqtDepth               <= 0;
                                x0[5:0]                <= 0;
                                y0[5:0]                <= 0;
                        end else if (dep_partIdx[cqtDepth] == 0) begin
                            if (cond_reach_pic_right) begin
                                if (`log_v && slice_num>=`slice_begin && slice_num<=`slice_end)
                                    $fdisplay(fd_log, "reach right boundary partIdx 0->2");
                                dep_partIdx[cqtDepth]  <= 2;
                                //x0不变
                                y0[`max_y_bits-1:3]    <= y0[`max_y_bits-1:3] + CbSize[6:3];
                            end else begin
                                x0[`max_x_bits-1:3]    <= x0[`max_x_bits-1:3] + CbSize[6:3]; //下一个partIdx=1的坐标
                                dep_partIdx[cqtDepth]  <= 1;
                            end
                            o_slice_data_state         <= `split_cu_flag_ctx;
                        end else if (dep_partIdx[cqtDepth] == 1) begin

                            if (cond_reach_pic_bottom) begin
                                if (`log_v && slice_num>=`slice_begin && slice_num<=`slice_end)
                                    $fdisplay(fd_log, "reach bottom");
                                cqtDepth               <= cqtDepth - 1;
                                log2CbSize             <= log2CbSize+1;
                                CbSize                 <= CbSize << 1;
                                x0[`max_x_bits-1:3]    <= x0[`max_x_bits-1:3] - CbSize[6:3];
                            end else begin
                                dep_partIdx[cqtDepth]  <= 2;
                                x0[`max_x_bits-1:3]    <= x0[`max_x_bits-1:3] - CbSize[6:3];
                                y0[`max_y_bits-1:3]    <= y0[`max_y_bits-1:3] + CbSize[6:3];
                                o_slice_data_state     <= `split_cu_flag_ctx;
                            end

                        end else if (dep_partIdx[cqtDepth] == 2) begin
                            if (cond_reach_pic_right) begin
                                //转到上一层
                                cqtDepth               <= cqtDepth - 1;
                                log2CbSize             <= log2CbSize+1;
                                CbSize                 <= CbSize << 1;
                                y0[`max_y_bits-1:3]    <= y0[`max_y_bits-1:3] - CbSize[6:3];
                            end else begin
                                x0[`max_x_bits-1:3]    <= x0[`max_x_bits-1:3] + CbSize[6:3];
                                dep_partIdx[cqtDepth]  <= 3;
                                o_slice_data_state     <= `split_cu_flag_ctx;
                            end

                        end else if (dep_partIdx[cqtDepth] == 3) begin
                            //转到上一层
                            cqtDepth                   <= cqtDepth - 1;
                            log2CbSize                 <= log2CbSize+1;
                            CbSize                     <= CbSize << 1;
                            x0[`max_x_bits-1:3]        <= x0[`max_x_bits-1:3] - CbSize[6:3];
                            y0[`max_y_bits-1:3]        <= y0[`max_y_bits-1:3] - CbSize[6:3];
                        end

                    end
                end

            end


        `ctb_end_2://0x9
            begin
                rst_filter                         <= 0;
                if (~rst_filter && filter_stage==`reset_filtering) begin
                    o_slice_data_state             <= `slice_data_end;
                    write_yuv                      <= 1;
                end
            end

        `slice_data_end:
            begin
                write_yuv                          <= 0;
            end
        //default: o_slice_data_state                <= `rst_slice_data;
    endcase
end

reg       [5:0]      slice_qpy_clip51;
always @ (posedge clk)
    if (i_SliceQpY>51)
        slice_qpy_clip51  <= 51;
    else
        slice_qpy_clip51  <= i_SliceQpY;

(* KEEP_HIERARCHY  = "TRUE" *)
cabac cabac_inst
(
 .clk                        (clk),
 .en                         (en),
 .rst                        (cabac_rst),
 .i_rbsp_in                  (i_rbsp_in_sd),
 .i_SliceQpY                 (slice_qpy_clip51),
 .i_slice_type               (i_slice_type),
 .i_cabac_init_present_flag  (i_cabac_init_present_flag),
 .i_cabac_init_flag          (i_cabac_init_flag),
 .i_leading9bits             (i_leading9bits),

 .i_init                     (init_context_model),
 .i_cm_idx_cu                (cm_idx_cu),
 .i_cm_idx_sd                (cm_idx_sd),
 .i_cm_idx_xy_pref           (cm_idx_xy_pref),
 .i_cm_idx_sig               (cm_idx_sig),
 .i_cm_idx_gt1_etc           (cm_idx_gt1_etc),

 .i_dec_en_cu                (dec_bin_en_cu),
 .i_dec_en_sd                (dec_bin_en_sd),
 .i_dec_en_xy_pref           (dec_bin_en_xy_pref),
 .i_dec_en_sig               (dec_bin_en_sig),
 .i_dec_en_gt1_etc           (dec_bin_en_gt1_etc),
 .i_byp_en                   (byp_dec_en_sd|byp_dec_en_cu|byp_dec_en_tu), //bypass_decode_bin
 .i_term_en                  (term_dec_en),              //terminate_decode_bin
 .o_init_done                (init_done),
 .o_bin_cu                   (bin_cu),
 .o_bin_sd                   (bin_sd),
 .o_bin_xy_pref              (bin_xy_pref),
 .o_bin_sig                  (bin_sig),
 .o_bin_gt1_etc              (bin_gt1_etc),

 .o_bin_byp                  (bin_byp),
 .o_bin_term                 (bin_term),
 .o_valid                    (dec_bin_valid),
 .o_output_len               (o_forward_len_sd),

 .o_ivlCurrRange_r           (range),
 .o_ivlOffset_r              (offset)
);


cu cu_inst
(
 .clk                                    (clk),
 .rst                                    (rst_cu),
 .global_rst                             (global_rst),
 .i_rst_slice                            (rst),
 .i_rst_ctb                              (rst_ctb),
 .i_rst_filter                           (rst_filter),
 .en                                     (i_cu_en),
 .i_tu_en                                (i_tu_en),

 .i_slice_type                           (i_slice_type),
 .i_transquant_bypass_enabled_flag       (i_transquant_bypass_enabled_flag),
 .i_PicWidthInSamplesY                   (i_PicWidthInSamplesY),
 .i_PicHeightInSamplesY                  (i_PicHeightInSamplesY),
 .i_five_minus_max_num_merge_cand        (i_five_minus_max_num_merge_cand),
 .i_amp_enabled_flag                     (i_amp_enabled_flag), //sps
 .i_max_transform_hierarchy_depth_intra  (i_max_transform_hierarchy_depth_intra),
 .i_max_transform_hierarchy_depth_inter  (i_max_transform_hierarchy_depth_inter),
 .i_cu_qp_delta_enabled_flag             (i_cu_qp_delta_enabled_flag), //pps
 .i_diff_cu_qp_delta_depth               (i_diff_cu_qp_delta_depth), //pps
 .i_transform_skip_enabled_flag          (i_transform_skip_enabled_flag), //pps
 .i_sign_data_hiding_enabled_flag        (i_sign_data_hiding_enabled_flag), //pps
 .i_constrained_intra_pred_flag          (i_constrained_intra_pred_flag), //pps
 .i_strong_intra_smoothing_enabled_flag  (i_strong_intra_smoothing_enabled_flag), //sps
 .i_log2_parallel_merge_level            (i_log2_parallel_merge_level),
 .i_num_ref_idx                          (i_num_ref_idx),
 .i_slice_temporal_mvp_enabled_flag      (i_slice_temporal_mvp_enabled_flag),
 .i_slice_beta_offset_div2               (i_slice_beta_offset_div2),
 .i_slice_tc_offset_div2                 (i_slice_tc_offset_div2),
 .i_IsCuQpDeltaCoded                     (IsCuQpDeltaCoded),
 .i_qp_cb_offset                         (qp_cb_offset),
 .i_qp_cr_offset                         (qp_cr_offset),
 .i_x0                                   (x0),
 .i_y0                                   (y0),
 .i_last_col                             (last_col),
 .i_last_row                             (last_row),
 .i_first_col                            (first_col),
 .i_first_row                            (first_row),
 .i_last_col_width                       (last_col_width),
 .i_last_row_height                      (last_row_height),
 .i_sao_param                            (sao_param),
 .i_sao_param_left                       (sao_param_left),
 .i_sao_param_up                         (sao_param_up),
 .i_sao_param_leftup                     (sao_param_leftup),
 .i_qPY_PRED                             (qPY_PRED),
 .i_qPY                                  (QpY),

 .i_log2CbSize                           (log2CbSize),
 .i_CbSize                               (CbSize),
 .i_slice_num                            (slice_num),

 .i_slice_data_state                     (o_slice_data_state),
 .fd_log                                 (fd_log),
 .fd_pred                                (fd_pred),
 .fd_intra_pred_chroma                   (fd_intra_pred_chroma),
 .fd_tq_luma                             (fd_tq_luma),
 .fd_tq_cb                               (fd_tq_cb),
 .fd_tq_cr                               (fd_tq_cr),
 .fd_filter                              (fd_filter),
 .fd_deblock                             (fd_deblock),

 .o_cu_state                             (o_cu_state),
 .o_tu_state                             (o_tu_state),
 .o_filter_stage                         (filter_stage),
 .o_ctb_rec_done                         (ctb_rec_done),

 .o_cm_idx_cu                            (cm_idx_cu),
 .o_cm_idx_xy_pref                       (cm_idx_xy_pref),
 .o_cm_idx_sig                           (cm_idx_sig),
 .o_cm_idx_gt1_etc                       (cm_idx_gt1_etc),
 .o_dec_bin_en_cu                        (dec_bin_en_cu),
 .o_dec_bin_en_xy_pref                   (dec_bin_en_xy_pref),
 .o_dec_bin_en_sig                       (dec_bin_en_sig),
 .o_dec_bin_en_gt1_etc                   (dec_bin_en_gt1_etc),
 .o_byp_dec_en_cu                        (byp_dec_en_cu),
 .o_byp_dec_en_tu                        (byp_dec_en_tu),

 .o_IsCuQpDeltaCoded                     (cu_dqp_dec_in_tu),
 .o_QpY                                  (QpY_tu),

 .i_cur_poc                              (i_cur_poc),
 .i_delta_poc                            (i_slice_local_rps.deltaPoc),
 .i_ref_dpb_slots                        (i_ref_dpb_slots),
 .i_cur_pic_dpb_slot                     (i_cur_pic_dpb_slot),
 .i_col_ref_idx                          (i_col_ref_idx),
 .i_qpy                                  (qpy[~qpy_sel]),

 .m_axi_arready                          (m_axi_arready),
 .m_axi_arvalid                          (m_axi_arvalid),
 .m_axi_arlen                            (m_axi_arlen),
 .m_axi_araddr                           (m_axi_araddr),

 .m_axi_rready                           (m_axi_rready),
 .m_axi_rdata                            (m_axi_rdata),
 .m_axi_rvalid                           (m_axi_rvalid),
 .m_axi_rlast                            (m_axi_rlast),

 .m_axi_awready                          (m_axi_awready),
 .m_axi_awaddr                           (m_axi_awaddr),
 .m_axi_awlen                            (m_axi_awlen),
 .m_axi_awvalid                          (m_axi_awvalid),

 .m_axi_wready                           (m_axi_wready),
 .m_axi_wdata                            (m_axi_wdata),
 .m_axi_wstrb                            (m_axi_wstrb),
 .m_axi_wlast                            (m_axi_wlast),
 .m_axi_wvalid                           (m_axi_wvalid),

 .i_bin_cu                               (bin_cu),
 .i_bin_xy_pref                          (bin_xy_pref),
 .i_bin_sig                              (bin_sig),
 .i_bin_gt1_etc                          (bin_gt1_etc),
 .i_dec_bin_valid                        (dec_bin_valid),
 .i_bin_byp                              (bin_byp),
 .i_ivlCurrRange                         (range),
 .i_ivlOffset                            (offset)

);

`ifdef RANDOM_INIT
integer  seed;
integer random_val;
initial  begin
    seed                               = $get_initial_random_seed(); 
    random_val                         = $random(seed);
    sao_state                          = {random_val,random_val};
    cabac_rst                          = {random_val[1:0],random_val[31:2],random_val[1:0],random_val[31:2]};
    init_context_model                 = {random_val[2:0],random_val[31:3],random_val[2:0],random_val[31:3]};
    rst_cu                             = {random_val[3:0],random_val[31:4],random_val[3:0],random_val[31:4]};
    rst_ctb                            = {random_val[4:0],random_val[31:5],random_val[4:0],random_val[31:5]};
    rst_filter                         = {random_val[5:0],random_val[31:6],random_val[5:0],random_val[31:6]};
    cm_idx_sd                          = {random_val[6:0],random_val[31:7],random_val[6:0],random_val[31:7]};
    dec_bin_en_sd                      = {random_val[7:0],random_val[31:8],random_val[7:0],random_val[31:8]};
    byp_dec_en_sd                      = {random_val[8:0],random_val[31:9],random_val[8:0],random_val[31:9]};
    term_dec_en                        = {random_val[9:0],random_val[31:10],random_val[9:0],random_val[31:10]};
    xCtb                               = {random_val[10:0],random_val[31:11],random_val[10:0],random_val[31:11]};
    yCtb                               = {random_val[11:0],random_val[31:12],random_val[11:0],random_val[31:12]};
    slice_num                          = {random_val[12:0],random_val[31:13],random_val[12:0],random_val[31:13]};
    cu_dec_stage                       = {random_val[13:0],random_val[31:14],random_val[13:0],random_val[31:14]};
    Log2MinCuQpDeltaSize               = {random_val[14:0],random_val[31:15],random_val[14:0],random_val[31:15]};
    log2CbSize                         = {random_val[16:0],random_val[31:17],random_val[16:0],random_val[31:17]};
    CbSize                             = {random_val[17:0],random_val[31:18],random_val[17:0],random_val[31:18]};
    x0                                 = {random_val[19:0],random_val[31:20],random_val[19:0],random_val[31:20]};
    y0                                 = {random_val[20:0],random_val[31:21],random_val[20:0],random_val[31:21]};
    last_col_x_ctb                     = {random_val[21:0],random_val[31:22],random_val[21:0],random_val[31:22]};
    last_col_x_ctb_minus1              = {random_val[22:0],random_val[31:23],random_val[22:0],random_val[31:23]};
    last_row_y_ctb                     = {random_val[23:0],random_val[31:24],random_val[23:0],random_val[31:24]};
    last_row_y_ctb_minus1              = {random_val[24:0],random_val[31:25],random_val[24:0],random_val[31:25]};
    last_col                           = {random_val[25:0],random_val[31:26],random_val[25:0],random_val[31:26]};
    last_row                           = {random_val[26:0],random_val[31:27],random_val[26:0],random_val[31:27]};
    first_col                          = {random_val[27:0],random_val[31:28],random_val[27:0],random_val[31:28]};
    first_row                          = {random_val[28:0],random_val[31:29],random_val[28:0],random_val[31:29]};
    last_col_width                     = {random_val[29:0],random_val[31:30],random_val[29:0],random_val[31:30]};
    last_row_height                    = {random_val[30:0],random_val[31],random_val[30:0],random_val[31]};
    x_qg                               = {random_val[31:0],random_val[31:0]};
    y_qg                               = {random_val,random_val};
    x_qg_minus1                        = {random_val[1:0],random_val[31:2],random_val[1:0],random_val[31:2]};
    y_qg_minus1                        = {random_val[2:0],random_val[31:3],random_val[2:0],random_val[31:3]};
    end_of_slice_segment_flag          = {random_val[3:0],random_val[31:4],random_val[3:0],random_val[31:4]};
    cond_next_cu_new_qg                = {random_val[4:0],random_val[31:5],random_val[4:0],random_val[31:5]};
    first_cycle_cu_end                 = {random_val[5:0],random_val[31:6],random_val[5:0],random_val[31:6]};
    cIdx                               = {random_val[6:0],random_val[31:7],random_val[6:0],random_val[31:7]};
    i                                  = {random_val[7:0],random_val[31:8],random_val[7:0],random_val[31:8]};
    j                                  = {random_val[8:0],random_val[31:9],random_val[8:0],random_val[31:9]};
    partIdx                            = {random_val[9:0],random_val[31:10],random_val[9:0],random_val[31:10]};
    bram_CtDepth_up_we                 = {random_val[13:0],random_val[31:14],random_val[13:0],random_val[31:14]};
    bram_CtDepth_up_addr               = {random_val[14:0],random_val[31:15],random_val[14:0],random_val[31:15]};
    bram_CtDepth_up_din                = {random_val[16:0],random_val[31:17],random_val[16:0],random_val[31:17]};
    cqtDepth                           = {random_val[17:0],random_val[31:18],random_val[17:0],random_val[31:18]};
    CtDepth_left                       = {random_val[1:0],random_val[3:2],random_val[5:4],random_val[7:6],
                                          random_val[9:8],random_val[11:10],random_val[13:12],random_val[15:14]};
    CtDepth_up                         = {random_val[1:0],random_val[3:2],random_val[5:4],random_val[7:6],
                                          random_val[9:8],random_val[11:10],random_val[13:12],random_val[15:14]};
    cqt_left                           = {random_val[22:0],random_val[31:23],random_val[22:0],random_val[31:23]};
    cqt_up                             = {random_val[23:0],random_val[31:24],random_val[23:0],random_val[31:24]};
    condL                              = {random_val[24:0],random_val[31:25],random_val[24:0],random_val[31:25]};
    condA                              = {random_val[25:0],random_val[31:26],random_val[25:0],random_val[31:26]};
    IsCuQpDeltaCoded                   = {random_val[26:0],random_val[31:27],random_val[26:0],random_val[31:27]};
    qPY_A                              = {random_val[28:0],random_val[31:29],random_val[28:0],random_val[31:29]};
    qPY_B                              = {random_val[29:0],random_val[31:30],random_val[29:0],random_val[31:30]};
    qPY_PRED                           = {random_val[30:0],random_val[31],random_val[30:0],random_val[31]};
    qp_cb_offset                       = {random_val[2:0],random_val[31:3],random_val[2:0],random_val[31:3]};
    qp_cr_offset                       = {random_val[3:0],random_val[31:4],random_val[3:0],random_val[31:4]};
    QpY_PREV                           = {random_val[4:0],random_val[31:5],random_val[4:0],random_val[31:5]};
    QpY                                = {random_val[5:0],random_val[31:6],random_val[5:0],random_val[31:6]};
    qpy_sel                            = {random_val[9:0],random_val[31:10],random_val[9:0],random_val[31:10]};
    qpy                                = {random_val[10:0],random_val[31:11],random_val[10:0],random_val[31:11]};
    sao_param                          = {random_val[11:0],random_val[31:12],random_val[11:0],random_val[31:12]};
    sao_param_left                     = {random_val[12:0],random_val[31:13],random_val[12:0],random_val[31:13]};
    sao_param_up                       = {random_val[13:0],random_val[31:14],random_val[13:0],random_val[31:14]};
    sao_param_leftup                   = {random_val[14:0],random_val[31:15],random_val[14:0],random_val[31:15]};
    sao_offset_r                       = {random_val[16:0],random_val[31:17],random_val[16:0],random_val[31:17]};
    bram_sao_up_we                     = {random_val[18:0],random_val[31:19],random_val[18:0],random_val[31:19]};
    bram_sao_up_addr                   = {random_val[19:0],random_val[31:20],random_val[19:0],random_val[31:20]};
    bram_sao_up_din                    = {random_val[20:0],random_val[31:21],random_val[20:0],random_val[31:21]};
    slice_qpy_clip51                   = {random_val[21:0],random_val[31:22],random_val[21:0],random_val[31:22]};
end
`endif

endmodule
