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

module decode_stream (
 //global signals
 input  wire                              clk,
 input  wire                              rst,
 input  wire                              en,

 //interface to bitstream memory or fifo
 input  wire [ 7:0]                       stream_mem_data_in,
 input  wire                              stream_mem_valid,
 output wire [31:0]                       stream_mem_addr_out,
 output wire                              stream_mem_rd, // request stream read by read_nalu
 input  wire                              stream_mem_end, // end of stream reached

 output wire [12:0]                       pic_width_in_luma_samples, //max 4096
 output wire [11:0]                       pic_height_in_luma_samples, //max 2160
 output wire [63:0]                       pic_num,
 output wire [ 3:0]                       cur_pic_dpb_slot,
 output wire                              write_yuv,

 input  wire                              ext_mem_init_done,
 input  wire [31:0]                       fd_log,
 input  wire [31:0]                       fd_pred,
 input  wire [31:0]                       fd_intra_pred_chroma,
 input  wire [31:0]                       fd_tq_luma,
 input  wire [31:0]                       fd_tq_cb,
 input  wire [31:0]                       fd_tq_cr,
 input  wire [31:0]                       fd_filter,
 input  wire [31:0]                       fd_deblock,

 //axi bus read if
 input  wire                              m_axi_arready,
 output wire                              m_axi_arvalid,
 output wire [ 3:0]                       m_axi_arlen,
 output wire [31:0]                       m_axi_araddr,
 output wire [ 5:0]                       m_axi_arid,
 output wire [ 2:0]                       m_axi_arsize,
 output wire [ 1:0]                       m_axi_arburst,
 output wire [ 2:0]                       m_axi_arprot,
 output wire [ 3:0]                       m_axi_arcache,
 output wire [ 1:0]                       m_axi_arlock,
 output wire [ 3:0]                       m_axi_arqos,

 output wire                              m_axi_rready,
 input  wire [63:0]                       m_axi_rdata,
 input  wire                              m_axi_rvalid,
 input  wire                              m_axi_rlast,
 //axi bus write if
 input  wire                              m_axi_awready, // Indicates slave is ready to accept a
 output wire [ 5:0]                       m_axi_awid,    // Write ID
 output wire [31:0]                       m_axi_awaddr,  // Write address
 output wire [ 3:0]                       m_axi_awlen,   // Write Burst Length
 output wire [ 2:0]                       m_axi_awsize,  // Write Burst size
 output wire [ 1:0]                       m_axi_awburst, // Write Burst type
 output wire [ 1:0]                       m_axi_awlock,  // Write lock type
 output wire [ 3:0]                       m_axi_awcache, // Write Cache type
 output wire [ 2:0]                       m_axi_awprot,  // Write Protection type
 output wire                              m_axi_awvalid, // Write address valid

 input  wire                              m_axi_wready,  // Write data ready
 output wire [ 5:0]                       m_axi_wid,     // Write ID tag
 output wire [63:0]                       m_axi_wdata,    // Write data
 output wire [ 7:0]                       m_axi_wstrb,    // Write strobes
 output wire                              m_axi_wlast,    // Last write transaction
 output wire                              m_axi_wvalid,   // Write valid

 input  wire [ 5:0]                       m_axi_bid,     // Response ID
 input  wire [ 1:0]                       m_axi_bresp,   // Write response
 input  wire                              m_axi_bvalid,  // Write reponse valid
 output wire                              m_axi_bready,  // Response ready
 output wire [ 5:0]                       m_axi_rrid,
 input  wire [ 1:0]                       m_axi_rresp

);

wire     [ 5:0]     cu_state;
wire     [ 5:0]     tu_state;

assign m_axi_awid = 0;
assign m_axi_awsize = 3;
assign m_axi_awburst = 1;
assign m_axi_awlock = 0;
assign m_axi_awcache = 0;
assign m_axi_awprot = 0;

assign m_axi_wid = 0;

assign m_axi_bready = 1;

assign m_axi_arid = 0;
assign m_axi_arsize = 3;
assign m_axi_arburst = 1;//0=fixed adress burst 1=incrementing 2=wrap 
assign m_axi_arprot = 0;
assign m_axi_arcache = 0;
assign m_axi_arlock = 0;
assign m_axi_arqos = 0;


(*mark_debug="true"*)  wire                rps_en;
(*mark_debug="true"*)  wire                read_nalu_en;
(*mark_debug="true"*)  wire                rbsp_buffer_en;
(*mark_debug="true"*)  wire                rbsp_buf_sd_en;



(*mark_debug="true"*)  wire                vps_en;
(*mark_debug="true"*)  wire                sps_en;
(*mark_debug="true"*)  wire                pps_en;
(*mark_debug="true"*)  wire                slice_header_en;
(*mark_debug="true"*)  wire                cu_en;
(*mark_debug="true"*)  wire                tu_en;
wire                rst_slice_header;
wire                rst_slice_data;


wire                pass_buffer2norm;
wire                pass_buffer2sd;

wire     [15:0]     buffer_norm;
wire     [15:0]     buffer_sd;
wire     [ 1:0]     new_nalu_bytes;


//read_nalu
//
wire               rd_req_by_norm;
wire               rd_req_by_sd;

wire               rd_req_nalu;
assign rd_req_nalu = rbsp_buffer_en ? rd_req_by_norm : rd_req_by_sd;

wire     [5:0]     nal_unit_type;
wire     [7:0]     rbsp_data;
wire               rbsp_valid;
wire               is_last_bit_of_rbsp;
wire               next_nalu_detected_nalu;
wire               next_nalu_detected;
wire               next_nalu_detected_clr;

(* KEEP_HIERARCHY  = "TRUE" *)
read_nalu read_nalu_inst
(
    .clk                          (clk),
    .rst                          (rst),
    .en                           (read_nalu_en),
    .rd_req_by_rbsp_buffer_in     (rd_req_nalu),
    .mem_data_in                  (stream_mem_data_in),
    .nal_unit_type                (nal_unit_type),
    .stream_mem_addr              (stream_mem_addr_out),
    .mem_rd_req_out               (stream_mem_rd),
    .rbsp_data_out                (rbsp_data),
    .rbsp_valid_out               (rbsp_valid),
    .next_nalu_detected           (next_nalu_detected_nalu),
    .next_nalu_detected_clr       (next_nalu_detected_clr)
);



wire [ 3:0]   forward_len;
wire [ 7:0]   rbsp_out;
wire [ 3:0]   num_zero_bits;
wire          rbsp_buffer_valid;

wire          forward_to_next_nalu;


rbsp_buffer rbsp_buffer_inst
(
    .clk                             (clk),
    .rst                             (rst),
    .en                              (rbsp_buffer_en),
    .rbsp_in                         (rbsp_data),
    .next_nalu_detected_nalu         (next_nalu_detected_nalu),
    .next_nalu_detected              (next_nalu_detected),
    .next_nalu_detected_clr          (next_nalu_detected_clr),
    .valid_data_of_nalu_in           (rbsp_valid),
    .forward_len_in                  (forward_len),

    .rd_req_to_nalu_out              (rd_req_by_norm),
    .rbsp_out                        (rbsp_out),
    .buffer_valid_out                (rbsp_buffer_valid),
    .num_zero_bits                   (num_zero_bits),
    .is_last_bit_of_rbsp             (is_last_bit_of_rbsp),
    .forward_to_next_nalu            (forward_to_next_nalu),

    .i_pass_buffer                   (pass_buffer2norm),
    .i_buffer                        (buffer_sd),
    .buffer                          (buffer_norm),
    .i_new_nalu_bytes                (new_nalu_bytes)
);

wire [2:0]  forward_len_sd;
wire [7:0]  rbsp_out_sd;
wire        rbsp_valid_sd;
wire [8:0]  leading9bits;

(* KEEP_HIERARCHY  = "TRUE" *)
rbsp_buffer_simple rbsp_buffer_slice_data
(
    .clk                             (clk),
    .rst                             (rst),
    .en                              (rbsp_buf_sd_en),
    .rbsp_in                         (rbsp_data),
    .valid_data_of_nalu_in           (rbsp_valid),
    .forward_len_in                  (forward_len_sd),
    .rd_req_to_nalu_out              (rd_req_by_sd),
    .rbsp_out                        (rbsp_out_sd),
    .buffer_valid_out                (rbsp_valid_sd),
    .buffer                          (buffer_sd),
    .leading9bits                    (leading9bits),
    .i_pass_buffer                   (pass_buffer2sd),
    .i_buffer                        (buffer_norm),
    .next_nalu_detected_nalu         (next_nalu_detected_nalu),
    .next_nalu_detected_clr          (next_nalu_detected_clr),
    .o_new_nalu_bytes                (new_nalu_bytes)
);


wire [2:0] vps_state;
wire [3:0] forward_len_vps;
wire [4:0] vps_max_dec_pic_buffering;
vps vps_inst
(
    .clk                          (clk),
    .rst                          (rst),
    .en                           (vps_en),
    .i_rbsp_in                    (rbsp_out[7:0]),
    .i_num_zero_bits              (num_zero_bits),
    .o_vps_max_dec_pic_buffering  (vps_max_dec_pic_buffering),
    .o_vps_state                  (vps_state),
    .o_forward_len                (forward_len_vps)
);


wire        bram_rps_we_rps;
wire        bram_rps_we;
wire        bram_rps_we_slice_header;
wire [ 7:0] bram_rps_addr_rps;
wire [ 7:0] bram_rps_addr_slice_header;
wire [ 7:0] bram_rps_addr;

wire        bram_rps_en;
assign bram_rps_en = rps_en | slice_header_en;

assign bram_rps_we = rps_en ? bram_rps_we_rps : bram_rps_we_slice_header;
assign bram_rps_addr = rps_en ? bram_rps_addr_rps : bram_rps_addr_slice_header;

wire [31:0] bram_rps_din;
wire [31:0] bram_rps_dout;

ram #(8, 32) bram_rps
(
     .clk(clk),
     .en(bram_rps_en),
     .we(bram_rps_we),
     .addr(bram_rps_addr),
     .data_in(bram_rps_din),
     .data_out(bram_rps_dout)
 );




wire     [3:0]     sps_rps_idx;
wire     [3:0]     slice_header_rps_idx;
wire     [3:0]     rps_idx;
assign rps_idx = sps_en ? sps_rps_idx:slice_header_rps_idx; //解析sps里的的rps时，rps_enable=1，sps也是enable的


wire rst_rps_module;
wire sps_rst_rps;
wire slice_header_rst_rps;
assign rst_rps_module = sps_en ? sps_rst_rps:slice_header_rst_rps;


wire     [3:0]     num_short_term_ref_pic_sets;
wire     [4:0]     rps_state;
wire     [3:0]     forward_len_rps;

rps rps_inst
(
    .clk(clk),
    .rst(rst_rps_module),
    .en(rps_en),
    .i_num_zero_bits(num_zero_bits),

    .i_rbsp_in(rbsp_out[7:0]),
    .i_rps_idx(rps_idx),
    .i_num_short_term_ref_pic_sets(num_short_term_ref_pic_sets),

    .o_rps_state(rps_state),
    .o_forward_len(forward_len_rps),
    .o_bram_rps_we(bram_rps_we_rps),
    .o_bram_rps_addr(bram_rps_addr_rps),
    .o_bram_rps_din(bram_rps_din),
    .i_bram_rps_dout(bram_rps_dout)
);



wire     [3:0]     forward_len_sps;
wire     [5:0]     sps_state;
wire     [1:0]     chroma_format_idc;

wire     [3:0]     log2_max_pic_order_cnt_lsb_minus4;
wire     [4:0]     sps_max_dec_pic_buffering_minus1;
wire     [1:0]     log2_min_coding_block_size_minus3;
wire     [1:0]     log2_diff_max_min_coding_block_size;
wire     [1:0]     log2_min_transform_block_size_minus2;
wire     [1:0]     log2_diff_max_min_transform_block_size;
wire               sample_adaptive_offset_enabled_flag;
wire               amp_enabled_flag;
wire               long_term_ref_pics_present_flag;
wire     [2:0]     max_transform_hierarchy_depth_inter;
wire     [2:0]     max_transform_hierarchy_depth_intra;
wire               sps_temporal_mvp_enabled_flag;
wire               strong_intra_smoothing_enabled_flag;
sps sps_inst
(
    .clk                                       (clk),
    .rst                                       (rst),
    .en                                        (sps_en),
    .i_rbsp_in                                 (rbsp_out[7:0]),
    .i_num_zero_bits                           (num_zero_bits),

    .o_chroma_format_idc                       (chroma_format_idc),
    .o_pic_width_in_luma_samples               (pic_width_in_luma_samples),
    .o_pic_height_in_luma_samples              (pic_height_in_luma_samples),
    .o_log2_max_pic_order_cnt_lsb_minus4       (log2_max_pic_order_cnt_lsb_minus4),
    .o_sps_max_dec_pic_buffering_minus1        (sps_max_dec_pic_buffering_minus1),
    .o_log2_min_coding_block_size_minus3       (log2_min_coding_block_size_minus3),
    .o_log2_diff_max_min_coding_block_size     (log2_diff_max_min_coding_block_size),
    .o_log2_min_transform_block_size_minus2    (log2_min_transform_block_size_minus2),
    .o_log2_diff_max_min_transform_block_size  (log2_diff_max_min_transform_block_size),
    .o_max_transform_hierarchy_depth_inter     (max_transform_hierarchy_depth_inter),
    .o_max_transform_hierarchy_depth_intra     (max_transform_hierarchy_depth_intra),
    .o_sample_adaptive_offset_enabled_flag     (sample_adaptive_offset_enabled_flag),
    .o_amp_enabled_flag                        (amp_enabled_flag),
    .o_num_short_term_ref_pic_sets             (num_short_term_ref_pic_sets),
    .o_long_term_ref_pics_present_flag         (long_term_ref_pics_present_flag),
    .o_strong_intra_smoothing_enabled_flag     (strong_intra_smoothing_enabled_flag),
    .o_sps_temporal_mvp_enabled_flag           (sps_temporal_mvp_enabled_flag),
    .o_rps_idx                                 (sps_rps_idx),
    .o_rst_rps_module                          (sps_rst_rps),
    .i_rps_state                               (rps_state),

    .o_sps_state                               (sps_state),
    .o_forward_len                             (forward_len_sps)
);



wire          [4:0]     pps_state;
wire          [3:0]     forward_len_pps;

wire                    sign_data_hiding_enabled_flag;
wire                    cabac_init_present_flag;
wire          [3:0]     num_ref_idx_l0_default_active_minus1;
wire signed   [5:0]     init_qp_minus26;
wire                    transform_skip_enabled_flag;
wire                    cu_qp_delta_enabled_flag;
wire          [1:0]     diff_cu_qp_delta_depth;
wire signed   [4:0]     pps_cb_qp_offset;
wire signed   [4:0]     pps_cr_qp_offset;
wire                    transquant_bypass_enabled_flag;
wire                    loop_filter_across_slices_enabled_flag;
wire                    pps_deblocking_filter_disabled_flag;
wire                    deblocking_filter_control_present_flag;
wire                    deblocking_filter_override_enabled_flag;
wire signed   [3:0]     pps_beta_offset_div2;
wire signed   [3:0]     pps_tc_offset_div2;
wire                    constrained_intra_pred_flag;
wire signed   [1:0]     log2_parallel_merge_level_minus2;
reg           [2:0]     log2_parallel_merge_level;

always @ (posedge clk)
begin
    log2_parallel_merge_level <= log2_parallel_merge_level_minus2+2;
end

pps pps_inst
(
    .clk                                         (clk),
    .rst                                         (rst),
    .en                                          (pps_en),
    .i_rbsp_in                                   (rbsp_out[7:0]),
    .i_num_zero_bits                             (num_zero_bits),

    .o_sign_data_hiding_enabled_flag             (sign_data_hiding_enabled_flag),
    .o_cabac_init_present_flag                   (cabac_init_present_flag),
    .o_num_ref_idx_l0_default_active_minus1      (num_ref_idx_l0_default_active_minus1), //max 15
    .o_init_qp_minus26                           (init_qp_minus26), //-26~25
    .o_transform_skip_enabled_flag               (transform_skip_enabled_flag),
    .o_cu_qp_delta_enabled_flag                  (cu_qp_delta_enabled_flag),
    .o_diff_cu_qp_delta_depth                    (diff_cu_qp_delta_depth),
    .o_pps_cb_qp_offset                          (pps_cb_qp_offset), //-12~12
    .o_pps_cr_qp_offset                          (pps_cr_qp_offset),
    .o_transquant_bypass_enabled_flag            (transquant_bypass_enabled_flag),
    .o_loop_filter_across_slices_enabled_flag    (loop_filter_across_slices_enabled_flag),
    .o_pps_deblocking_filter_disabled_flag       (pps_deblocking_filter_disabled_flag),
    .o_deblocking_filter_control_present_flag    (deblocking_filter_control_present_flag),
    .o_deblocking_filter_override_enabled_flag   (deblocking_filter_override_enabled_flag),
    .o_pps_beta_offset_div2                      (pps_beta_offset_div2), //-6~6
    .o_pps_tc_offset_div2                        (pps_tc_offset_div2),
    .o_constrained_intra_pred_flag               (constrained_intra_pred_flag),
    .o_log2_parallel_merge_level_minus2          (log2_parallel_merge_level_minus2),

    .o_pps_state                                 (pps_state),
    .o_forward_len                               (forward_len_pps)
);


wire               [1:0]         slice_type;
wire [`max_poc_bits-1:0]         cur_poc;
wire                             slice_temporal_mvp_enabled_flag;
wire                             slice_sao_luma_flag;
wire                             slice_sao_chroma_flag;
wire               [3:0]         num_ref_idx;
wire                             cabac_init_flag;
wire               [3:0]         collocated_ref_idx;
wire               [2:0]         five_minus_max_num_merge_cand;
wire signed        [6:0]         slice_qp_delta;
wire signed        [4:0]         slice_cb_qp_offset;
wire signed        [4:0]         slice_cr_qp_offset;
wire signed        [3:0]         slice_beta_offset_div2;
wire signed        [3:0]         slice_tc_offset_div2;

wire               [5:0]         slice_header_state;
wire               [3:0]         forward_len_slice_header;
wire [`max_ref-1:0][3:0]         ref_dpb_slots;
rps_t                            slice_local_rps;


slice_header slice_header_inst
(
    .clk                                       (clk),
    .rst                                       (rst_slice_header),
    .global_rst                                (rst),
    .en                                        (slice_header_en),
    .i_rbsp_in                                 (rbsp_out[7:0]),
    .i_num_zero_bits                           (num_zero_bits),

    .i_log2_max_pic_order_cnt_lsb_minus4       (log2_max_pic_order_cnt_lsb_minus4),
    .i_nal_unit_type                           (nal_unit_type),
    .i_num_short_term_ref_pic_sets             (num_short_term_ref_pic_sets),
    .i_rps_state                               (rps_state),
    .i_sps_temporal_mvp_enabled_flag           (sps_temporal_mvp_enabled_flag),
    .i_sample_adaptive_offset_enabled_flag     (sample_adaptive_offset_enabled_flag),
    .i_num_ref_idx_l0_default_active_minus1    (num_ref_idx_l0_default_active_minus1),
    .i_cabac_init_present_flag                 (cabac_init_present_flag),
    .i_pps_cb_qp_offset                        (pps_cb_qp_offset),
    .i_pps_cr_qp_offset                        (pps_cr_qp_offset),
    .i_deblocking_filter_override_enabled_flag (deblocking_filter_override_enabled_flag),
    .i_pps_beta_offset_div2                    (pps_beta_offset_div2),
    .i_pps_tc_offset_div2                      (pps_tc_offset_div2),
    .i_pps_deblocking_filter_disabled_flag     (pps_deblocking_filter_disabled_flag),
    .i_loop_filter_across_slices_enabled_flag  (loop_filter_across_slices_enabled_flag),
    .i_vps_max_dec_pic_buffering               (vps_max_dec_pic_buffering),

    .o_slice_type                              (slice_type),
    .o_poc                                     (cur_poc),
    .o_slice_temporal_mvp_enabled_flag         (slice_temporal_mvp_enabled_flag),
    .o_slice_sao_luma_flag                     (slice_sao_luma_flag),
    .o_slice_sao_chroma_flag                   (slice_sao_chroma_flag),
    .o_num_ref_idx                             (num_ref_idx),
    .o_cabac_init_flag                         (cabac_init_flag),
    .o_collocated_ref_idx                      (collocated_ref_idx),
    .o_five_minus_max_num_merge_cand           (five_minus_max_num_merge_cand),
    .o_slice_qp_delta                          (slice_qp_delta),
    .o_slice_cb_qp_offset                      (slice_cb_qp_offset),
    .o_slice_cr_qp_offset                      (slice_cr_qp_offset),
    .o_slice_beta_offset_div2                  (slice_beta_offset_div2),
    .o_slice_tc_offset_div2                    (slice_tc_offset_div2),


    .o_rps_idx                                 (slice_header_rps_idx),
    .o_rst_rps_module                          (slice_header_rst_rps),

    .o_slice_header_state                      (slice_header_state),
    .o_forward_len                             (forward_len_slice_header),

    .o_bram_rps_we                             (bram_rps_we_slice_header),
    .o_bram_rps_addr                           (bram_rps_addr_slice_header),
    .i_bram_rps_dout                           (bram_rps_dout),

    .o_slice_local_rps                         (slice_local_rps),
    .o_ref_dpb_slots                           (ref_dpb_slots),
    .o_cur_pic_dpb_slot                        (cur_pic_dpb_slot)

);

wire [5:0] SliceQpY;
assign SliceQpY = 26 + init_qp_minus26 + slice_qp_delta;

wire signed [5:0] qp_cb_offset;
wire signed [5:0] qp_cr_offset;
assign qp_cb_offset = pps_cb_qp_offset + slice_cb_qp_offset;
assign qp_cr_offset = pps_cr_qp_offset + slice_cr_qp_offset;

wire [`max_x_bits-1:0]     PicWidthInSamplesY;
wire [`max_y_bits-1:0]     PicHeightInSamplesY;
wire [`max_ctb_x_bits-1:0] PicWidthInCtbsY;
assign  PicWidthInSamplesY    = pic_width_in_luma_samples;
assign  PicHeightInSamplesY   = pic_height_in_luma_samples;
assign  PicWidthInCtbsY       = pic_width_in_luma_samples[`max_x_bits-1:6];


wire [4:0] slice_data_state;
wire       slice_data_en;


slice_data slice_data_inst
(
 .clk                                    (clk),
 .rst                                    (rst_slice_data),
 .global_rst                             (rst),
 .en                                     (slice_data_en),
 .i_rbsp_in_sd                           (rbsp_out_sd),

 .i_cu_en                                (cu_en),
 .i_tu_en                                (tu_en),

 .i_SliceQpY                             (SliceQpY),
 .i_slice_type                           (slice_type),
 .i_slice_sao_luma_flag                  (slice_sao_luma_flag),
 .i_slice_sao_chroma_flag                (slice_sao_chroma_flag),
 .i_cabac_init_present_flag              (cabac_init_present_flag),
 .i_cabac_init_flag                      (cabac_init_flag),
 .i_transquant_bypass_enabled_flag       (transquant_bypass_enabled_flag),
 .i_PicWidthInSamplesY                   (PicWidthInSamplesY),
 .i_PicHeightInSamplesY                  (PicHeightInSamplesY),
 .i_amp_enabled_flag                     (amp_enabled_flag),
 .i_max_transform_hierarchy_depth_inter  (max_transform_hierarchy_depth_inter),
 .i_max_transform_hierarchy_depth_intra  (max_transform_hierarchy_depth_intra),
 .i_cu_qp_delta_enabled_flag             (cu_qp_delta_enabled_flag),
 .i_qp_cb_offset                         (qp_cb_offset),
 .i_qp_cr_offset                         (qp_cr_offset),
 .i_diff_cu_qp_delta_depth               (diff_cu_qp_delta_depth),
 .i_transform_skip_enabled_flag          (transform_skip_enabled_flag),
 .i_sign_data_hiding_enabled_flag        (sign_data_hiding_enabled_flag),
 .i_five_minus_max_num_merge_cand        (five_minus_max_num_merge_cand),
 .i_constrained_intra_pred_flag          (constrained_intra_pred_flag),
 .i_strong_intra_smoothing_enabled_flag  (strong_intra_smoothing_enabled_flag),
 .i_slice_beta_offset_div2               (slice_beta_offset_div2),
 .i_slice_tc_offset_div2                 (slice_tc_offset_div2),
 .i_leading9bits                         (leading9bits),
 .i_num_ref_idx                          (num_ref_idx),
 .i_log2_parallel_merge_level            (log2_parallel_merge_level),
 .i_slice_temporal_mvp_enabled_flag      (slice_temporal_mvp_enabled_flag),

 .i_cur_poc                              (cur_poc),
 .i_slice_local_rps                      (slice_local_rps),
 .i_ref_dpb_slots                        (ref_dpb_slots),
 .i_cur_pic_dpb_slot                     (cur_pic_dpb_slot),
 .i_col_ref_idx                          (collocated_ref_idx),

 .fd_log                                 (fd_log),
 .fd_pred                                (fd_pred),
 .fd_intra_pred_chroma                   (fd_intra_pred_chroma),
 .fd_tq_luma                             (fd_tq_luma),
 .fd_tq_cb                               (fd_tq_cb),
 .fd_tq_cr                               (fd_tq_cr),
 .fd_filter                              (fd_filter),
 .fd_deblock                             (fd_deblock),
 .i_pic_num                              (pic_num),

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

 .o_slice_data_state                     (slice_data_state),
 .o_forward_len_sd                       (forward_len_sd),
 .o_cu_state                             (cu_state),
 .o_tu_state                             (tu_state),
 .write_yuv                              (write_yuv)

);


wire               bc_en;
wire               bc_vps_en;
wire               bc_sps_en;
wire               bc_pps_en;
wire               bc_slice_header_en;
wire               bc_slice_data_en;
wire               bc_cu_en;
wire               bc_tu_en;
wire               bc_rps_en;
wire               bc_rbsp_buffer_en;
wire               bc_rbsp_buf_sd_en;
wire               bc_rbsp_buf_cu_en;
wire               bc_rbsp_buf_tu_en;

wire     [2:0]     bitstream_state;

(* KEEP_HIERARCHY  = "TURE" *)
bitstream_controller bc_inst
(
    .clk                              (clk),
    .rst                              (rst),
    .en                               (bc_en),
    .i_ext_mem_init_done              (ext_mem_init_done),
    .i_vps_state                      (vps_state),
    .i_sps_state                      (sps_state),
    .i_pps_state                      (pps_state),
    .i_slice_header_state             (slice_header_state),
    .i_slice_data_state               (slice_data_state),
    .i_cu_state                       (cu_state),
    .i_tu_state                       (tu_state),

    .i_forward_len_vps                (forward_len_vps),
    .i_forward_len_pps                (forward_len_pps),
    .i_forward_len_sps                (forward_len_sps),
    .i_forward_len_slice_header       (forward_len_slice_header),

    .i_forward_len_rps                (forward_len_rps),
    .i_end_of_stream                  (stream_mem_end),
    .i_nal_unit_type                  (nal_unit_type),
    .i_next_nalu_detected             (next_nalu_detected),

    .o_vps_en                         (bc_vps_en),
    .o_sps_en                         (bc_sps_en),
    .o_pps_en                         (bc_pps_en),
    .o_slice_header_en                (bc_slice_header_en),
    .o_slice_data_en                  (bc_slice_data_en),
    .o_rst_slice_header               (rst_slice_header),
    .o_rst_slice_data                 (rst_slice_data),
    .o_cu_en                          (bc_cu_en),
    .o_tu_en                          (bc_tu_en),
    .o_rps_en                         (bc_rps_en),
    .o_rbsp_buffer_en                 (bc_rbsp_buffer_en),
    .o_rbsp_buf_sd_en                 (bc_rbsp_buf_sd_en),

    .o_pass_buffer2sd                 (pass_buffer2sd),
    .o_pass_buffer2norm               (pass_buffer2norm),

    .o_forward_len                    (forward_len),
    .o_pic_num                        (pic_num),
    .o_bitstream_state                (bitstream_state),
    .o_forward_to_next_nalu           (forward_to_next_nalu),
    .o_next_nalu_detected_clr         (next_nalu_detected_clr)
);



bitstream_ena_gen bitstream_ena_gen
(
    .en                          (en),
    .i_stream_mem_valid          (stream_mem_valid),
    .i_rbsp_buffer_valid         (rbsp_buffer_valid),
    .i_rbsp_buf_valid_sd         (rbsp_valid_sd),

    .i_bc_vps_en                 (bc_vps_en),
    .i_bc_pps_en                 (bc_pps_en),
    .i_bc_sps_en                 (bc_sps_en),
    .i_bc_slice_header_en        (bc_slice_header_en),
    .i_bc_slice_data_en          (bc_slice_data_en),
    .i_bc_cu_en                  (bc_cu_en),
    .i_bc_tu_en                  (bc_tu_en),
    .i_bc_rps_en                 (bc_rps_en),
    .i_bc_rbsp_buffer_en         (bc_rbsp_buffer_en),
    .i_bc_rbsp_buf_sd_en         (bc_rbsp_buf_sd_en),


    .o_read_nalu_en              (read_nalu_en),
    .o_rbsp_buffer_en            (rbsp_buffer_en),
    .o_rbsp_buf_sd_en            (rbsp_buf_sd_en),

    .o_bc_en                     (bc_en),
    .o_vps_en                    (vps_en),
    .o_pps_en                    (pps_en),
    .o_sps_en                    (sps_en),
    .o_slice_header_en           (slice_header_en),
    .o_slice_data_en             (slice_data_en),
    .o_cu_en                     (cu_en),
    .o_tu_en                     (tu_en),
    .o_rps_en                    (rps_en),
    .o_residual_en               (),
    .o_intra_pred_en             (),
    .o_inter_pred_en             (),
    .o_sum_en                    (),
    .o_ext_mem_writer_en         (),
    .o_ext_mem_hub_en            ()
);


endmodule


