//--------------------------------------------------------------------------------------------------
// Design    : bvp
// Author(s) : qiu bin, shi tian qi
// Email     : chat1@126.com, tishi1@126.com
// Copyright (C) 2013-2017 qiu bin, shi tian qi
// All rights reserved
// Phone 15957074161
// QQ:1517642772
//-------------------------------------------------------------------------------------------------

`timescale 1ns / 1ns // timescale time_unit/time_presicion

`default_nettype none
//4K 4096x2160

//nalu type
`define nalu_type_vps     6'b100000
`define nalu_type_sps     6'b100001
`define nalu_type_pps     6'b100010
`define nalu_type_idr     6'b000101
`define nalu_type_other   6'b000001

//vps_state
`define rst_vps                                     3'b000
`define vps_end                                     3'b001

`define vps_sub_layer_ordering_info_present_flag_s  3'b010
//`define vps_max_nuh_reserved_zero_layer_id_s        4'b0011
//`define vps_timing_info_present_flag_s              4'b0100
//`define vps_extension_flag_s                        4'b0101

`define vps_skip_128bits                        3'b011
//vps_video_parameter_set_id          4bits
//vps_reserved_three_2bits            2bits
//vps_max_layers_minus1               6bits
//vps_max_sub_layers_minus1           3bits
//vps_temporal_id_nesting_flag        1bit
//vps_reserved_ffff_16bits            16bits
//profile tier
//general_profile_space               2bits
//general_tier_flag                   1bit
//general_profile_idc                 5bits
//general_profile_compatibility_j     32bits
//general_progressive_source_flag
//general_interlaced_source_flag
//general_non_packed_constraint_flag
//general_frame_only_constraint_flag
//general_reserved_zero_44bits       44bits
//general_level_idc                  8bits

`define vps_max_dec_pic_buffering_minus1_i_s        3'b100
//`define vps_max_num_reorder_pics_i_s                4'b1000
//`define vps_max_latency_increase_plus1_i_s          4'b1001
//`define vps_num_layer_set_minus1_s                  4'b1010
`define vps_delay_1_cycle                             3'b101



//sps_state
`define rst_sps                                       6'b000000
`define sps_end                                       6'b000001
`define sps_parse_short_term_ref_pic_set_s            6'b000010

`define sps_skip_104bits                              6'b000011
//sps_video_parameter_set_id                    4bits
//sps_max_sub_layers_minus1                     3bits
//sps_temporal_id_nesting_flag                  1bit
//profile tier
//general_profile_space               2bits
//general_tier_flag                   1bit
//general_profile_idc                 5bits
//total 8bits
//general_profile_compatibility_j     32bits
//general_progressive_source_flag
//general_interlaced_source_flag
//general_non_packed_constraint_flag
//general_frame_only_constraint_flag
//total 4bits
//general_reserved_zero_44bits       44bits
//general_level_idc                  8bits

`define sps_skip_4bits                                6'b000100
//scaling_list_enabled_flag         1bit
//amp_enabled_flag                  1bit
//sample_adaptive_offset_enabled_flag 1bit
//pcm_enabled_flag                  1bit
//total 4bits

`define conformance_window_flag_s                     6'b000101
`define sps_sub_layer_ordering_info_present_flag_s    6'b000110

`define sps_seq_parameter_set_id_s                    6'b000111
`define chroma_format_idc_s                           6'b001000
`define pic_width_in_luma_samples_s                   6'b001001
`define pic_height_in_luma_samples_s                  6'b001010
`define conf_win_left_offset_s                        6'b001011
`define conf_win_right_offset_s                       6'b001100
//`define conf_win_top_offset_s                     5'b001110 (vlog-2600) [RDGN] - Redundant digits in numeric literal.
`define conf_win_top_offset_s                         6'b001101
`define conf_win_bottom_offset_s                      6'b001110
`define bit_depth_luma_minus8_s                       6'b001111
`define bit_depth_chroma_minus8_s                     6'b010000
`define log2_max_pic_order_cnt_lsb_minus4_s           6'b010001
`define sps_max_dec_pic_buffering_minus1_s            6'b010010
`define sps_num_reorder_pics_s                        6'b010011
`define sps_max_latency_increase_plus1_s              6'b010100
`define log2_min_coding_block_size_minus3_s           6'b010101
`define log2_diff_max_min_coding_block_size_s         6'b010110
`define log2_min_transform_block_size_minus2_s        6'b010111
`define log2_diff_max_min_transform_block_size_s      6'b011000
`define max_transform_hierarchy_depth_inter_s         6'b011001
`define max_transform_hierarchy_depth_intra_s         6'b011010



`define num_short_term_ref_pic_sets_s                 6'b011011
`define sps_delay_1_cycle                             6'b011100
`define sps_exp_count_zero                            6'b011101
`define sps_exp_golomb_calc                           6'b011110
`define sps_exp_golomb_end                            6'b011111


`define sps_skip_5bits                                6'b100000
//long_term_ref_pics_present_flag          1bit
//sps_temporal_mvp_enabled_flag            1bit
//strong_intra_smoothing_enabled_flag      1bit
//vui_parameters_present_flag              1bit
//sps_extension_flag                       1bit
//total 5bits



//rps state
`define rst_rps                                      5'b00000
`define rps_end                                      5'b00001
`define calc_rps_1                                   5'b00010
`define calc_rps_2                                   5'b00011

`define used_by_curr_pic_flag_inter_s                5'b00100
`define use_delta_flag_s                             5'b00101
`define used_by_curr_pic_flag_intra_s                5'b00110
`define inter_ref_pic_set_prediction_flag_s          5'b00111

`define delta_idx_minus1_s                           5'b01000
`define delta_rps_sign_s                             5'b01001
`define abs_delta_rps_minus1_s                       5'b01010
`define num_negative_pics_s                          5'b01011
`define num_positive_pics_s                          5'b01100
`define delta_poc_s0_minus1_s                        5'b01101
`define rps_delay_1_cycle                            5'b01110
`define rps_end_2                                    5'b01111
`define rps_exp_count_zero                           5'b10000
`define rps_exp_golomb_calc                          5'b10001
`define rps_exp_golomb_end                           5'b10010
`define calc_rps_3                                   5'b10011
`define calc_rps_4                                   5'b10100
`define rps_fetch_ref_1                              5'b10101
`define rps_fetch_ref_2                              5'b10110
`define rps_fetch_ref_3                              5'b10111
`define rps_store                                    5'b11000


//pps
`define rst_pps                                      5'b00000
`define pps_end                                      5'b00001

`define pps_skip_7bits                               5'b00010
//dependent_slice_segments_enabled_flag       1bit
//output_flag_present_flag                    1bit
//num_extra_slice_header_bits                 3bits
//sign_data_hiding_enabled_flag               1bit
//cabac_init_present_flag                     1bit
//total   7bits

`define pps_skip_3bits                               5'b00011
//constrained_intra_pred_flag         1bit
//transform_skip_enabled_flag         1bit
//cu_qp_delta_enabled_flag            1bit
//total 3bits

`define pps_skip_8bits                               5'b00100
//pps_slice_chroma_qp_offsets_present_flag        1bit
//weighted_pred_flag                              1bit
//weighted_bypred_flag                            1bit
//transquant_bypass_enabled_flag                  1bit
//tiles_enabled_flag                              1bit
//entropy_coding_sync_enabled_flag                1bit
//loop_filter_across_slices_enabled_flag          1bit
//deblocking_filter_control_present_flag          1bit
//total 8bits

`define deblocking_filter_override_enabled_flag_s    5'b00101
`define pps_deblocking_filter_disabled_flag_s        5'b00110


`define pps_pic_parameter_set_id_s                   5'b00111
`define pps_seq_parameter_set_id_s                   5'b01000

`define num_ref_idx_l0_default_active_minus1_s       5'b01001
`define num_ref_idx_l1_default_active_minus1_s       5'b01010
`define init_qp_minus26_s                            5'b01011

`define diff_cu_qp_delta_depth_s                     5'b01100
`define pps_cb_qp_offset_s                           5'b01101
`define pps_cr_qp_offset_s                           5'b01110

`define pps_beta_offset_div2_s                       5'b01111
`define pps_tc_offset_div2_s                         5'b10000
`define pps_delay_1_cycle                            5'b10001

`define pps_exp_count_zero                           5'b10010
`define pps_exp_golomb_calc                          5'b10011
`define pps_exp_golomb_end                           5'b10100

`define pps_scaling_list_data_present_flag_s         5'b10101
`define lists_modification_present_flag_s            5'b10110
`define log2_parallel_merge_level_minus2_s           5'b10111
//`define slice_segment_header_extension_present_flag  5'b10011
//`define pps_extension_flag_s                         5'b10100



`define rst_slice_header                                               6'b000000
`define slice_header_end                                               6'b000001
`define slice_header_parse_short_term_ref_pic_set                      6'b000010
`define calc_poc_1                                                     6'b000011
`define is_slice_sao_luma_chroma_flag_present                          6'b000100
`define is_cabac_init_flag_present                                     6'b000101
`define is_collocated_ref_idx_present                                  6'b000110
`define is_deblocking_filter_override_flag_present                     6'b000111
`define fetch_slice_local_rps                                          6'b001000
`define is_slice_loop_filter_across_slices_enabled_flag_present        6'b001001

`define first_slice_segment_in_pic_flag_s                              6'b001010
`define no_output_of_prior_pics_flag_s                                 6'b001011
`define pic_order_cnt_lsb_s                                            6'b001100
`define short_term_ref_pic_set_sps_flag_s                              6'b001101
`define short_term_ref_pic_set_idx_s                                   6'b001110
`define slice_temporal_mvp_enabled_flag_s                              6'b001111
`define slice_sao_luma_flag_s                                          6'b010000
`define slice_sao_chroma_flag_s                                        6'b010001
`define num_ref_idx_active_override_flag_s                             6'b010010
`define cabac_init_flag_s                                              6'b010011
`define deblocking_filter_override_flag_s                              6'b010100
`define slice_deblocking_filter_disabled_flag_s                        6'b010101
`define slice_loop_filter_across_slices_enabled_flag_s                 6'b010110

`define slice_pic_parameter_set_id_s                                   6'b010111
`define slice_type_s                                                   6'b011000
`define num_ref_idx_s                                                  6'b011001
`define collocated_ref_idx_s                                           6'b011010
`define five_minus_max_num_merge_cand_s                                6'b011011
`define slice_qp_delta_s                                               6'b011100
`define slice_qp_delta_cb_s                                            6'b011101
`define slice_qp_delta_cr_s                                            6'b011110
`define slice_beta_offset_div2_s                                       6'b011111
`define slice_tc_offset_div2_s                                         6'b100000

`define slice_header_byte_alignment                                    6'b100001
`define slice_header_delay_1_cycle                                     6'b100010
`define sh_exp_count_zero                                              6'b100011
`define sh_exp_golomb_calc                                             6'b100100
`define sh_exp_golomb_end                                              6'b100101
`define calc_poc_2                                                     6'b100110
`define fetch_slice_local_rps_1                                        6'b100111
`define fetch_slice_local_rps_2                                        6'b101000
`define fetch_slice_local_rps_3                                        6'b101001
`define calc_dpb_slot_1                                                6'b101010
`define calc_dpb_slot_2                                                6'b101011
`define remove_min_poc_unref_dpb_1                                     6'b101100
`define remove_min_poc_unref_dpb_2                                     6'b101101



//bitstream_state
`define rst_bitstream                      3'b000
`define bitstream_vps                      3'b001
`define bitstream_sps                      3'b010
`define bitstream_pps                      3'b011
`define bitstream_slice_header             3'b100
`define bitstream_slice_data               3'b101
`define bitstream_forward_to_next_nalu     3'b110
`define bitstream_next_nalu                3'b111

//slice_data_state
`define rst_slice_data                     5'b00000
`define init_cabac_context                 5'b00001
`define parse_sao_ctb                      5'b00010
`define split_cu_flag_ctx                  5'b00011
`define split_cu_flag_s                    5'b00100
`define slice_parse_cu                     5'b00101
`define slice_data_delay_1cycle            5'b00110
`define slice_data_pass2cu                 5'b00111
`define ctb_end                            5'b01000
`define ctb_end_2                          5'b01001

`define slice_data_end                     5'b11101
`define sd_forward_to_next_frame           5'b11110
`define rbsp_trailing_bits_slice_data      5'b11111

`define rst_exp_golomb                     2'b00
`define exp_golomb_count_zero              2'b01
`define exp_golomb_calc                    2'b10
`define exp_golomb_end                     2'b11


//CU state
`define rst_cu                                   6'b000000
`define cu_transquant_bypass_flag_s              6'b000001
`define cu_skip_flag_s                           6'b000010
`define cu_intra_or_inter                        6'b000011
`define merge_idx_s_1                            6'b000100
`define merge_idx_s_2                            6'b000101
`define pred_mode_flag_s                         6'b000110
`define parse_part_mode_intra                    6'b000111
`define parse_part_mode_inter_1                  6'b001000
`define parse_part_mode_inter_2                  6'b001001
`define parse_part_mode_inter_3                  6'b001010
`define parse_part_mode_inter_4                  6'b001011
`define prev_intra_luma_pred_flag_s              6'b001100
`define parse_mpm_idx                            6'b001101
`define get_cand_mode_list_1                     6'b001110
`define get_cand_mode_list_2                     6'b001111
`define store_intra_luma_pred_mode               6'b010000
`define parse_rem_intra_luma_pred_mode           6'b010001
`define parse_intra_chroma_pred_mode_1           6'b010010
`define parse_intra_chroma_pred_mode_2           6'b010011
`define parse_tu                                 6'b010100
`define split_transform_flag_s                   6'b010101
`define split_tu_or_not                          6'b010110
`define cbf_cb_s                                 6'b010111
`define cbf_cr_s                                 6'b011000
`define parse_cb_cr_or_not                       6'b011001

`define cu_pass2tu                               6'b011010
`define merge_flag_s                             6'b011011
`define ref_idx_s_1                              6'b011100
`define ref_idx_s_2                              6'b011101
`define abs_mvd_greater0                         6'b011110
`define abs_mvd_greater1                         6'b011111
`define mvd_phase3                               6'b100000
`define abs_mvd_minus2_1                         6'b100001
`define abs_mvd_minus2_2                         6'b100010
`define mvd_sign_flag_s                          6'b100011
`define mvp_l0_flag_s                            6'b100100
`define wait_mv_done_1                           6'b100101
`define wait_mv_done_2                           6'b100110
`define update_mvf_nb                            6'b100111
`define rqt_root_cbf_s                           6'b101000

`define cu_end                                   6'b111111


//TU state
`define rst_tu                             6'b000000
`define cbf_luma_s                         6'b000001
`define get_last_sub_block_scan_pos_3      6'b000010
`define cu_qp_delta_abs_s_1                6'b000011
`define cu_qp_delta_abs_s_2                6'b000100
`define cu_qp_delta_abs_s_3                6'b000101
`define cu_qp_delta_sign_flag_s            6'b000110
`define parse_residual_coding              6'b000111
`define transform_skip_flag_s              6'b001000
`define last_sig_coeff_x_prefix_s          6'b001001
`define last_sig_coeff_y_prefix_s          6'b001010
`define last_sig_coeff_x_suffix_s          6'b001011
`define last_sig_coeff_y_suffix_s          6'b001100
`define get_last_sub_block_scan_pos_1      6'b001101
`define get_last_sub_block_scan_pos_2      6'b001110
`define coded_sub_block_flag_s             6'b001111
`define sig_coeff_flag_s                   6'b010000
`define sig_coeff_flag_ctx                 6'b010001
`define coeff_abs_level_greater1_flag_s    6'b010010
`define coeff_abs_level_greater2_flag_s    6'b010011
`define coeff_abs_level_remaining_s_1      6'b010100
`define coeff_abs_level_remaining_s_2      6'b010101
`define coeff_abs_level_remaining_s_3      6'b010110
`define next_sub_block                     6'b010111
`define coeff_sign_flag_s                  6'b011000
`define last_sig_coeff_y_prefix_ctx        6'b011001

`define next_sub_block_1                   6'b011010
`define sig_coeff_flag_ctx_2               6'b011011
`define next_sub_block_2                   6'b011100
`define parse_residual_coding_2            6'b011101
`define store_coeff_first_sig              6'b011110
`define clr_sub_block_bram                 6'b011111

`define tu_end                             6'b111111

//enum SliceType
`define B_SLICE                            2'b00
`define P_SLICE                            2'b01
`define I_SLICE                            2'b10


//5+31+118=154
//slice data,sao
`define CM_IDX_SAO_MERGE                           0
`define CM_IDX_SAO_TYPE                            1
`define CM_IDX_SPLIT_CU_FLAG                       2 //3


//cu
`define CM_IDX_CU_TRANSQUANT_BYPASS_FLAG           0
`define CM_IDX_CU_SKIP_FLAG                        1 //3
`define CM_IDX_MERGE_FLAG                          4
`define CM_IDX_MERGE_IDX_EXT                       5
`define CM_IDX_PART_MODE                           6 //4
`define CM_IDX_PRED_MODE                           10
`define CM_IDX_PREV_INTRA_LUMA_PRED_FLAG           11
`define CM_IDX_INTRA_CHROMA_PRED_MODE              12
`define CM_IDX_INTER_DIR                           13 //5
`define CM_IDX_MVD                                 18 //2
`define CM_IDX_REF_PIC                             20 //2
`define CM_IDX_QT_CBF_CB_CR                        22 //4
`define CM_IDX_QT_ROOT_CBF                         26 //parse_rqt_root_cbf
`define CM_IDX_MVP_IDX                             27
`define CM_IDX_TRANS_SUBDIV_FLAG                   28 //3 parse_split_transform_flag

//tu
`define CM_IDX_LAST_SIG_COEFF_X_PREFIX             0 //18
`define CM_IDX_LAST_SIG_COEFF_Y_PREFIX             18 //18

`define CM_IDX_SIG_FLAG                            0 //42

`define CM_IDX_COEFF_ABS_LEVEL_GREAT1_FLAG         0 //24
`define CM_IDX_COEFF_ABS_LEVEL_GREAT2_FLAG         24 //6
`define CM_IDX_TRANSFORM_SKIP_FLAG                 30 //2
`define CM_IDX_QT_CBF_LUMA                         32 //2
`define CM_IDX_DQP                                 34 //2
`define CM_IDX_CODED_SUB_BLOCK_FLAG                36 //4

//sao state
`define rst_sao                            4'b0000
`define sao_merge_left_flag_s              4'b0001
`define sao_merge_up_flag_s                4'b0010
`define merge_or_parse                     4'b0011
`define merge_fetch_up                     4'b0100
`define merge_fetch_left                   4'b0101
`define parse_sao_type_idx1                4'b0110
`define parse_sao_type_idx2                4'b0111
`define parse_sao_tr                       4'b1000
`define band_or_edge                       4'b1001
`define sao_offset_sign_s                  4'b1010
`define sao_band_position_s                4'b1011
`define sao_eo_class_s                     4'b1100
`define sao_store                          4'b1101
`define done_one_tr                        4'b1110

`define sao_end                            4'b1111


`define trans_quant_stg0                   3'b000
`define trans_quant_stg1                   3'b001
`define trans_quant_stg2                   3'b010
`define trans_quant_delay_1cycle           3'b011
`define trans_quant_end                    3'b111

`define intra_pred_calc_avail1             4'b0000
`define intra_pred_calc_avail2             4'b0001
`define intra_pred_wait_nb                 4'b0010
`define intra_pred_substitute1             4'b0011
`define intra_pred_substitute2             4'b0100
`define intra_pred_substitute3             4'b0101
`define intra_pred_smooth_or_not           4'b0110
`define intra_pred_strong_smooth           4'b0111
`define intra_pred_normal_smooth           4'b1000
`define intra_pred_planar                  4'b1001
`define intra_pred_dc                      4'b1010
`define intra_pred_angular                 4'b1011
`define intra_pred_end                     4'b1111

`define deblocking_ver                     3'b000
`define deblocking_hor                     3'b001
`define filtering_sao_and_wait             3'b010
`define filter_store_up_right              3'b011
`define filter_fetch_up                    3'b100
`define filter_store_up_right_2            3'b101
`define filter_store_up_right_3            3'b110

`define filter_end                         3'b111


`define reset_filtering                    2'b00
`define filtering_luma                     2'b01
`define filtering_cb                       2'b10
`define filtering_cr                       2'b11


`define SZ_4K
`define max_poc_bits 16
`define BASE_DDR_ADDR 32'h20000000
`define max_ref 16
`define max_dpb 5

//mv 4096x4 = 16384  spec -2^15~2^15   16bit,mvx+mvy 32bit
//4096x2160/4/4 = 1024*540
//1920x1080/4/4 = 480*270 = 518400B
//7020 4.9Mb
//7030 9.3Mb
//7035 17.6Mb

//PicWidthInCtbsY 4096/64=64 6bits  1920/64=30 5bits 4096=13bits 2160=12bits 1920=11bits 1280=11bits
//4096/8=512 10bits 1920/8=240 8bits

`define max_ctb_x_bits 6
`define max_ctb_y_bits 6
`define max_cu_x_bits 9
`define max_tu_x_bits 10 //tu min 4x4
`define max_x_bits 12
`define max_y_bits 12
 //1920/8=240 8bits
`define max_cus_one_row_bits  9
//1920/8*8=1920
`define max_cus_one_ctb_row_bits 12

//4096/8 * 2160/8 = 138240
`define max_cus_one_frame_bits 18

//3840/64*16=960 10bits
//1920/64*16=480 9bits
`define max_x_div4_bits 10




//MvField +ref poc+cu_predmode 64bits
//4096x2160/4/4*8
`define DDR_BASE_DPB0          32'h20000000
`define DDR_BASE_DPB1          32'h21000000
`define DDR_BASE_DPB2          32'h22000000
`define DDR_BASE_DPB3          32'h23000000
`define DDR_BASE_DPB4          32'h24000000
`define DDR_BASE_DPB5          32'h25000000

`define DDR_BASE_PARAM0        32'h26000000 //1M实际用512K
`define DDR_BASE_PARAM1        32'h26100000
`define DDR_BASE_PARAM2        32'h26200000
`define DDR_BASE_PARAM3        32'h26300000
`define DDR_BASE_PARAM4        32'h26400000
`define DDR_BASE_PARAM5        32'h26500000

//16M,实际用13M
`define DDR_SIZE_EACH_DPB      25'h1000000

//4096/16 * 4096/16 * 8 = 256*256*8 = 512K
`define DDR_SIZE_EACH_PARAM    16'h80000

`define CB_OFFSET              24'h900000
`define CR_OFFSET              24'hC00000


`define BAND 2'b01
`define EDGE 2'b10
`define NONE 2'b00

`define MinCbLog2SizeY 3
`define Log2MinTrafoSize 2
`define Log2MaxTrafoSize 5

`define Log2ParMrgLevel  2

`define LOG

`define  PART_2Nx2N   3'b000           ///< symmetric motion partition,  2Nx2N
`define  PART_2NxN    3'b001           ///< symmetric motion partition,  2Nx N
`define  PART_Nx2N    3'b010           ///< symmetric motion partition,   Nx2N
`define  PART_NxN     3'b011           ///< symmetric motion partition,   Nx N
`define  PART_2NxnU   3'b100           ///< asymmetric motion partition, 2Nx( N/2) + 2Nx(3N/2)
`define  PART_2NxnD   3'b101           ///< asymmetric motion partition, 2Nx(3N/2) + 2Nx( N/2)
`define  PART_nLx2N   3'b110           ///< asymmetric motion partition, ( N/2)x2N + (3N/2)x2N
`define  PART_nRx2N   3'b111           ///< asymmetric motion partition, (3N/2)x2N + ( N/2)x2N

`define INTRA_PLANAR             0
`define INTRA_VER                26                    // index for intra VERTICAL   mode
`define INTRA_HOR                10                    // index for intra HORIZONTAL mode
`define INTRA_DC                 1                     // index for intra DC mode
`define DM_CHROMA_IDX            36
`define INTRA_ANGULAR26          26

`define CABAC_MAX_BIN            31
`define SCAN_DIAG 0
`define SCAN_HORIZ 1
`define SCAN_VERT 2

`define MODE_INTRA 1
`define MODE_INTER 0

`define MAX_DEC_BUF 32
`define MAX_DEC_BUF_BITS 5

`define log_v 0
`define slice_begin 0
`define slice_end 250
`define log_i 1
`define log_t 1  //log transquant
`define log_p 1   //log pred
`define log_f 1  //log filter
`define log_v_sao 0
`define log_t_c_idx 0
`define log_p_c_idx 1

`define RANDOM_INIT

