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

module sps
(
 input wire                 clk                                      ,
 input wire                 rst                                      ,
 input wire                 en                                       ,
 input wire      [ 7:0]     i_rbsp_in                                ,
 input wire      [ 3:0]     i_num_zero_bits                          ,
 input wire      [ 4:0]     i_rps_state                              ,

 output reg      [ 1:0]     o_chroma_format_idc                      ,
 output reg      [12:0]     o_pic_width_in_luma_samples              ,
 output reg      [11:0]     o_pic_height_in_luma_samples             ,
 output reg      [ 3:0]     o_log2_max_pic_order_cnt_lsb_minus4      ,
 output reg      [ 4:0]     o_sps_max_dec_pic_buffering_minus1       ,
 output reg      [ 1:0]     o_log2_min_coding_block_size_minus3      ,
 output reg      [ 1:0]     o_log2_diff_max_min_coding_block_size    ,
 output reg      [ 1:0]     o_log2_min_transform_block_size_minus2   ,
 output reg      [ 1:0]     o_log2_diff_max_min_transform_block_size ,
 output reg      [ 2:0]     o_max_transform_hierarchy_depth_inter    ,
 output reg      [ 2:0]     o_max_transform_hierarchy_depth_intra    ,
 output reg                 o_sample_adaptive_offset_enabled_flag    ,
 output reg                 o_amp_enabled_flag                       ,
 output reg      [ 3:0]     o_num_short_term_ref_pic_sets            ,
 output reg                 o_long_term_ref_pics_present_flag        ,
 output reg      [ 3:0]     o_rps_idx                                ,
 output reg                 o_rst_rps_module                         ,
 output reg                 o_strong_intra_smoothing_enabled_flag    ,
 output reg                 o_sps_temporal_mvp_enabled_flag          ,

 output reg      [ 5:0]     o_sps_state                              ,
 output reg      [ 3:0]     o_forward_len
);


reg[6:0] bits_skipped;
reg[4:0] sps_state_save;

reg [ 4:0] state_after_exp;
reg [15:0] ue;
reg [15:0] se;
reg [ 3:0] leadingZerobits;
reg [ 3:0] bits_total;
reg [ 3:0] bits_left;

always @ (posedge clk)
if (rst)
begin
    o_chroma_format_idc                        <= 0;
    o_pic_width_in_luma_samples                <= 0;
    o_pic_height_in_luma_samples               <= 0;
    o_log2_max_pic_order_cnt_lsb_minus4        <= 0;
    o_sps_max_dec_pic_buffering_minus1         <= 0;
    o_log2_min_coding_block_size_minus3        <= 0;
    o_log2_diff_max_min_coding_block_size      <= 0;
    o_log2_min_transform_block_size_minus2     <= 0;
    o_log2_diff_max_min_transform_block_size   <= 0;
    o_max_transform_hierarchy_depth_inter      <= 0;
    o_max_transform_hierarchy_depth_intra      <= 0;
    o_sample_adaptive_offset_enabled_flag      <= 0;
    o_amp_enabled_flag                         <= 0;
    o_num_short_term_ref_pic_sets              <= 0;
    o_long_term_ref_pics_present_flag          <= 0;
    o_strong_intra_smoothing_enabled_flag      <= 0;
    o_sps_state                                <= 0;
    o_forward_len                              <= 0;
    leadingZerobits                            <= 0;
    ue                                         <= 0;
    se                                         <= 0;
end
else
begin
    if(en)
        case (o_sps_state)
            `rst_sps:
                begin
                    o_rps_idx        <= 0;
                    bits_skipped     <= 0;
                    o_sps_state      <= `sps_skip_104bits;
                    o_forward_len    <= 8;
                    o_rst_rps_module <= 0;
                end
            `sps_skip_104bits://3
                begin
                    bits_skipped <= bits_skipped + o_forward_len;
                    if (bits_skipped == 96) begin
                        o_forward_len    <= 0;
                        sps_state_save   <= `sps_exp_count_zero;
                        o_sps_state      <= `sps_delay_1_cycle;
                        state_after_exp  <= `sps_seq_parameter_set_id_s;
                    end
                end

            `sps_delay_1_cycle://0x1c
                begin
                    o_forward_len <= 0;
                    o_sps_state   <= sps_state_save;
                end
            `sps_exp_count_zero://0x1d
                begin
                    leadingZerobits      <= leadingZerobits+i_num_zero_bits;
                    o_forward_len        <= i_num_zero_bits;
                    o_sps_state          <= `sps_delay_1_cycle;
                    sps_state_save       <= `sps_exp_count_zero;
                    if (~i_num_zero_bits[3]) begin //<8
                        sps_state_save   <= `sps_exp_golomb_calc;
                        bits_left        <= leadingZerobits+i_num_zero_bits+1;
                        bits_total       <= leadingZerobits+i_num_zero_bits+1;
                    end
                end

            `sps_exp_golomb_calc: begin//0x1e
                if (bits_left>8) begin
                    bits_left        <= bits_left - 8;
                    o_forward_len    <= 8;
                    ue               <= i_rbsp_in[7:0];
                    sps_state_save   <= `sps_exp_golomb_calc;
                end else begin
                    case (bits_left)
                    1:ue      <= {24'd0,ue[7:0],i_rbsp_in[7]} - 1; //          1
                    2:ue      <= {24'd0,ue[7:0],i_rbsp_in[7:6]} - 1; //       01x
                    3:ue      <= {24'd0,ue[7:0],i_rbsp_in[7:5]} - 1; //      001xx
                    4:ue      <= {24'd0,ue[7:0],i_rbsp_in[7:4]} - 1; //     0001xxx
                    5:ue      <= {24'd0,ue[7:0],i_rbsp_in[7:3]} - 1; //    00001xxxx
                    6:ue      <= {24'd0,ue[7:0],i_rbsp_in[7:2]} - 1; //   000001xxxxx
                    7:ue      <= {24'd0,ue[7:0],i_rbsp_in[7:1]} - 1; //  0000001xxxxxx
                    8:ue      <= {24'd0,ue[7:0],i_rbsp_in[7:0]} - 1; // 00000001xxxxxxx
                    default:ue      <= 0;
                    endcase
//a0 0f 08  1010 0000, 0000,{1111,0000,1}000,  1e1-1=1e0
                    case (bits_total)
                    1:se        <= 0;
                    2:se        <= i_rbsp_in[6]? -i_rbsp_in[7] : i_rbsp_in[7];  //10 11 00111  111>>1 = 11
                    3:se        <= i_rbsp_in[5]? -i_rbsp_in[7:6]: i_rbsp_in[7:6];
                    4:se        <= i_rbsp_in[4]? -i_rbsp_in[7:5]: i_rbsp_in[7:5];
                    5:se        <= i_rbsp_in[3]? -i_rbsp_in[7:4]: i_rbsp_in[7:4];
                    6:se        <= i_rbsp_in[2]? -i_rbsp_in[7:3]: i_rbsp_in[7:3];
                    7:se        <= i_rbsp_in[1]? -i_rbsp_in[7:2]: i_rbsp_in[7:2];
                    8:se        <= i_rbsp_in[0]? -i_rbsp_in[7:1]: i_rbsp_in[7:1];
                    9:se        <= i_rbsp_in[7]? -i_rbsp_in[7:0] : i_rbsp_in[7:0];
                    10:se       <= i_rbsp_in[6]? -{ue[7:0],i_rbsp_in[7]} : {ue[7:0],i_rbsp_in[7]};
                    11:se       <= i_rbsp_in[5]? -{ue[7:0],i_rbsp_in[7:6]} : {ue[7:0],i_rbsp_in[7:6]};
                    12:se       <= i_rbsp_in[4]? -{ue[7:0],i_rbsp_in[7:5]} : {ue[7:0],i_rbsp_in[7:5]};
                    13:se       <= i_rbsp_in[3]? -{ue[7:0],i_rbsp_in[7:4]} : {ue[7:0],i_rbsp_in[7:4]};
                    14:se       <= i_rbsp_in[2]? -{ue[7:0],i_rbsp_in[7:3]} : {ue[7:0],i_rbsp_in[7:3]};
                    default:se      <= 0;
                    endcase
                    o_forward_len   <= bits_left;
                    sps_state_save   <= `sps_exp_golomb_end;
                end

                o_sps_state      <= `sps_delay_1_cycle;
            end

            `sps_exp_golomb_end://0x1f
                begin
                    leadingZerobits                     <= 0; //reinit
                    ue                                  <= 0;
                    se                                  <= 0;
                    case (state_after_exp)
                    `sps_seq_parameter_set_id_s   :
                        begin
                            state_after_exp             <= `chroma_format_idc_s;
                            o_sps_state                 <= `sps_exp_count_zero;
                        end
                    `chroma_format_idc_s          :
                        begin 
                            o_chroma_format_idc         <= ue;
                            o_sps_state                 <= `sps_exp_count_zero;
                            state_after_exp             <= `pic_width_in_luma_samples_s;
                        end
                    `pic_width_in_luma_samples_s  :
                        begin 
                            o_pic_width_in_luma_samples <= ue;
                            o_sps_state                 <= `sps_exp_count_zero;
                            state_after_exp             <= `pic_height_in_luma_samples_s;
                        end
                    `pic_height_in_luma_samples_s :
                        begin 
                            o_pic_height_in_luma_samples    <= ue;
                            o_sps_state                     <= `conformance_window_flag_s;
                        end
                    `conf_win_left_offset_s       : //b
                        begin
                            state_after_exp                 <= `conf_win_right_offset_s;
                            o_sps_state                     <= `sps_exp_count_zero;
                        end
                    `conf_win_right_offset_s      : //c
                        begin
                            state_after_exp                 <= `conf_win_top_offset_s;
                            o_sps_state                     <= `sps_exp_count_zero;
                        end
                    `conf_win_top_offset_s        : //d
                        begin
                            state_after_exp                 <= `conf_win_bottom_offset_s;
                            o_sps_state                     <= `sps_exp_count_zero;
                        end
                    `conf_win_bottom_offset_s     : //e
                        begin
                            state_after_exp                 <= `bit_depth_luma_minus8_s;
                            o_sps_state                     <= `sps_exp_count_zero;
                        end
                    `bit_depth_luma_minus8_s      : //f
                        begin
                            state_after_exp                 <= `bit_depth_chroma_minus8_s;
                            o_sps_state                     <= `sps_exp_count_zero;
                        end
                    `bit_depth_chroma_minus8_s    : //0x10
                        begin
                            state_after_exp                 <= `log2_max_pic_order_cnt_lsb_minus4_s;
                            o_sps_state                     <= `sps_exp_count_zero;
                        end

                    `log2_max_pic_order_cnt_lsb_minus4_s: //0x11
                        begin
                            o_log2_max_pic_order_cnt_lsb_minus4   <= ue;
                            o_sps_state                           <= `sps_sub_layer_ordering_info_present_flag_s;
                        end
                    `sps_max_dec_pic_buffering_minus1_s : //0x12
                        begin
                            o_sps_max_dec_pic_buffering_minus1    <= ue;
                            state_after_exp                       <= `sps_num_reorder_pics_s;
                            o_sps_state                           <= `sps_exp_count_zero;
                        end
                    `sps_num_reorder_pics_s             : //0x13
                        begin
                            o_sps_state                        <= `sps_exp_count_zero;
                            state_after_exp                    <= `sps_max_latency_increase_plus1_s;
                        end

                    `sps_max_latency_increase_plus1_s: //0x14
                        begin
                            o_sps_state                        <= `sps_exp_count_zero;
                            state_after_exp                    <= `log2_min_coding_block_size_minus3_s;
                        end

                    `log2_min_coding_block_size_minus3_s: //0x15
                        begin
                            o_log2_min_coding_block_size_minus3    <= ue;
                            o_sps_state                            <= `sps_exp_count_zero;
                            state_after_exp                        <= `log2_diff_max_min_coding_block_size_s;
                        end
                    `log2_diff_max_min_coding_block_size_s: //0x16
                        begin
                            o_log2_diff_max_min_coding_block_size  <= ue;
                            o_sps_state                            <= `sps_exp_count_zero;
                            state_after_exp                        <= `log2_min_transform_block_size_minus2_s;
                        end
                    `log2_min_transform_block_size_minus2_s: //0x17
                        begin
                            o_log2_min_transform_block_size_minus2 <= ue;
                            o_sps_state                            <= `sps_exp_count_zero;
                            state_after_exp                        <= `log2_diff_max_min_transform_block_size_s;
                        end
                    `log2_diff_max_min_transform_block_size_s://0x18
                        begin
                            o_log2_diff_max_min_transform_block_size  <= ue;
                            o_sps_state                               <= `sps_exp_count_zero;
                            state_after_exp                           <= `max_transform_hierarchy_depth_inter_s;
                        end
                    `max_transform_hierarchy_depth_inter_s://0x19
                        begin
                            o_max_transform_hierarchy_depth_inter    <= ue;
                            o_sps_state                              <= `sps_exp_count_zero;
                            state_after_exp                          <= `max_transform_hierarchy_depth_intra_s;
                        end
                    `max_transform_hierarchy_depth_intra_s://0x1a
                        begin
                            o_max_transform_hierarchy_depth_intra    <= ue;
                            o_sps_state                              <= `sps_skip_4bits;
                        end
                    `num_short_term_ref_pic_sets_s: //0x1b
                        begin
                            o_num_short_term_ref_pic_sets      <= ue;
                            o_sps_state                        <= `sps_parse_short_term_ref_pic_set_s;
                            o_rst_rps_module                   <= 1;
                        end
                    endcase
                end


            `conformance_window_flag_s://5
                begin
                    o_forward_len       <= 1;
                    sps_state_save      <= `sps_exp_count_zero;
                    o_sps_state         <= `sps_delay_1_cycle;
                    if (i_rbsp_in[7] == 1) begin
                        state_after_exp <= `conf_win_left_offset_s;//b
                    end else begin
                        state_after_exp <= `bit_depth_luma_minus8_s;//f
                    end
                end


            `sps_sub_layer_ordering_info_present_flag_s:
                begin
                    o_forward_len    <= 1;
                    sps_state_save   <= `sps_exp_count_zero;
                    o_sps_state      <= `sps_delay_1_cycle;
                    state_after_exp  <= `sps_max_dec_pic_buffering_minus1_s;
                end

            `sps_skip_4bits:
                begin
                    o_forward_len                         <= 4;
                    o_amp_enabled_flag                    <= i_rbsp_in[6];
                    o_sample_adaptive_offset_enabled_flag <= i_rbsp_in[5];
                    sps_state_save                        <= `sps_exp_count_zero;
                    state_after_exp                       <= `num_short_term_ref_pic_sets_s;
                    o_sps_state                           <= `sps_delay_1_cycle;
                end

            `sps_parse_short_term_ref_pic_set_s://2
                begin
                    o_rst_rps_module                      <= 0;
                    if (i_rps_state == `rps_end) begin
                        if (o_rps_idx == o_num_short_term_ref_pic_sets - 1) begin
                            o_sps_state                   <= `sps_skip_5bits;
                        end else begin
                            o_rps_idx                     <= o_rps_idx + 1;
                            o_rst_rps_module              <= 1;
                        end

                    end
                end
            `sps_skip_5bits:
                begin
                    o_strong_intra_smoothing_enabled_flag <= i_rbsp_in[5];
                    o_sps_temporal_mvp_enabled_flag       <= i_rbsp_in[6];
                    o_sps_state                           <= `sps_end;
                end
            `sps_end:
                begin
                
                end
            default: o_sps_state <= `rst_sps;
        endcase
end

endmodule
