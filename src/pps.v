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

module pps
(
 input wire                        clk                                        ,
 input wire                        rst                                        ,
 input wire                        en                                         ,
 input wire              [ 7: 0]   i_rbsp_in                                  ,
 input wire              [ 3: 0]   i_num_zero_bits                            ,

 output reg                   o_sign_data_hiding_enabled_flag            ,
 output reg                   o_cabac_init_present_flag                  ,
 output reg         [ 3: 0]   o_num_ref_idx_l0_default_active_minus1     , //max 15
 output reg signed  [ 5: 0]   o_init_qp_minus26                          , //-26~25
 output reg                   o_transform_skip_enabled_flag              ,
 output reg                   o_cu_qp_delta_enabled_flag                 ,
 output reg         [ 1: 0]   o_diff_cu_qp_delta_depth                   ,
 output reg signed  [ 4: 0]   o_pps_cb_qp_offset                         , //-12~12
 output reg signed  [ 4: 0]   o_pps_cr_qp_offset                         ,
 output reg                   o_transquant_bypass_enabled_flag           ,
 output reg                   o_loop_filter_across_slices_enabled_flag   ,
 output reg                   o_pps_deblocking_filter_disabled_flag      ,
 output reg                   o_deblocking_filter_control_present_flag   ,
 output reg                   o_deblocking_filter_override_enabled_flag  ,
 output reg signed  [ 3: 0]   o_pps_beta_offset_div2                     , //-6~6
 output reg signed  [ 3: 0]   o_pps_tc_offset_div2                       ,
 output reg                   o_constrained_intra_pred_flag              ,
 output reg signed  [ 1:0]    o_log2_parallel_merge_level_minus2         ,

 output reg         [ 4: 0]   o_pps_state                                ,
 output reg         [ 3: 0]   o_forward_len
);


reg        [ 3:0]  bits_skipped                        ;
reg        [ 4:0]  pps_state_save                      ;

reg        [ 4:0]  state_after_exp                     ;
reg        [15:0]  ue                                  ;
reg        [15:0]  se                                  ;
reg        [ 3:0]  leadingZerobits                     ;
reg        [ 3:0]  bits_total                          ;
reg        [ 3:0]  bits_left                           ;

always @ (posedge clk)
if (rst)
begin
    o_sign_data_hiding_enabled_flag             <= 0;
    o_cabac_init_present_flag                   <= 0;
    o_num_ref_idx_l0_default_active_minus1      <= 0;
    o_init_qp_minus26                           <= 0;
    o_transform_skip_enabled_flag               <= 0;
    o_cu_qp_delta_enabled_flag                  <= 0;
    o_diff_cu_qp_delta_depth                    <= 0;
    o_pps_cb_qp_offset                          <= 0;
    o_pps_cr_qp_offset                          <= 0;
    o_transquant_bypass_enabled_flag            <= 0;
    o_deblocking_filter_control_present_flag    <= 0;
    o_deblocking_filter_override_enabled_flag   <= 0;
    o_pps_deblocking_filter_disabled_flag       <= 0;
    o_pps_beta_offset_div2                      <= 0;
    o_pps_tc_offset_div2                        <= 0;
    o_transquant_bypass_enabled_flag            <= 0;
    o_loop_filter_across_slices_enabled_flag    <= 0;
    o_constrained_intra_pred_flag               <= 0;
    o_log2_parallel_merge_level_minus2          <= 0;
    o_forward_len                               <= 0;
    leadingZerobits                             <= 0;
    ue                                          <= 0;
    se                                          <= 0;
end else if(en)
    case (o_pps_state)
        `rst_pps:
            begin
                o_pps_state                 <= `pps_exp_count_zero;
                state_after_exp             <= `pps_pic_parameter_set_id_s;
            end
        `pps_delay_1_cycle://0x11
            begin
                o_forward_len               <= 0;
                o_pps_state                 <= pps_state_save;
            end

        `pps_exp_count_zero://0x12
            begin
                leadingZerobits      <= leadingZerobits+i_num_zero_bits;
                o_forward_len        <= i_num_zero_bits;
                o_pps_state          <= `pps_delay_1_cycle;
                pps_state_save       <= `pps_exp_count_zero;
                if (~i_num_zero_bits[3]) begin //<8
                    pps_state_save   <= `pps_exp_golomb_calc;
                    bits_left        <= leadingZerobits+i_num_zero_bits+1;
                    bits_total       <= leadingZerobits+i_num_zero_bits+1;
                end
            end

        `pps_exp_golomb_calc: begin//0x13
            if (bits_left>8) begin
                bits_left        <= bits_left - 8;
                o_forward_len    <= 8;
                ue               <= i_rbsp_in[7:0];
                pps_state_save   <= `pps_exp_golomb_calc;
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
                pps_state_save   <= `pps_exp_golomb_end;
            end

            o_pps_state      <= `pps_delay_1_cycle;
        end

        `pps_exp_golomb_end://0x14
            begin
                leadingZerobits                     <= 0; //reinit
                ue                                  <= 0;
                se                                  <= 0;
                case (state_after_exp)
                `pps_pic_parameter_set_id_s:
                    begin
                        o_pps_state                 <= `pps_exp_count_zero;
                        state_after_exp             <= `pps_seq_parameter_set_id_s;
                    end
                `pps_seq_parameter_set_id_s:
                    begin
                        o_pps_state                 <= `pps_skip_7bits;
                    end
                `num_ref_idx_l0_default_active_minus1_s://9
                    begin
                        o_num_ref_idx_l0_default_active_minus1 <= ue;
                        state_after_exp             <= `num_ref_idx_l1_default_active_minus1_s;
                        o_pps_state                 <= `pps_exp_count_zero;

                    end
                `num_ref_idx_l1_default_active_minus1_s://a
                    begin
                        state_after_exp             <= `init_qp_minus26_s;
                        o_pps_state                 <= `pps_exp_count_zero;

                    end
                `init_qp_minus26_s://b
                    begin
                        o_init_qp_minus26           <= ue;
                        o_pps_state                 <= `pps_skip_3bits;//3

                    end
                `diff_cu_qp_delta_depth_s:
                    begin
                        o_diff_cu_qp_delta_depth    <= ue;
                        state_after_exp             <= `pps_cb_qp_offset_s;
                        o_pps_state                 <= `pps_exp_count_zero;
                    end
                `pps_cb_qp_offset_s://d
                    begin
                        o_pps_cb_qp_offset          <= se;
                        state_after_exp             <= `pps_cr_qp_offset_s;
                        o_pps_state                 <= `pps_exp_count_zero;
                    end
                `pps_cr_qp_offset_s://e
                    begin
                        o_pps_cr_qp_offset          <= se;
                        o_pps_state                 <= `pps_skip_8bits;//4
                    end
                `pps_beta_offset_div2_s:
                    begin
                        o_pps_beta_offset_div2      <= se;
                        state_after_exp             <= `pps_tc_offset_div2_s;
                        o_pps_state                 <= `pps_exp_count_zero;
                    end
                `pps_tc_offset_div2_s:
                    begin
                        o_pps_tc_offset_div2        <= se;
                        o_pps_state                 <= `pps_scaling_list_data_present_flag_s;
                    end
                `log2_parallel_merge_level_minus2_s:
                    begin
                        o_log2_parallel_merge_level_minus2 <= se;
                        o_pps_state                 <= `pps_end;//3

                    end
                 endcase
             end


        `pps_skip_7bits://2
            begin
                o_forward_len                   <= 7;
                state_after_exp                 <= `num_ref_idx_l0_default_active_minus1_s;
                o_sign_data_hiding_enabled_flag <= i_rbsp_in[2];
                pps_state_save                  <= `pps_exp_count_zero;
                o_pps_state                     <= `pps_delay_1_cycle;
                o_cabac_init_present_flag       <= i_rbsp_in[1];

            end


        `pps_skip_3bits:
            begin
                o_forward_len                  <= 3;
                o_pps_state                    <= `pps_delay_1_cycle;
                pps_state_save                 <= `pps_exp_count_zero;
                o_constrained_intra_pred_flag  <= i_rbsp_in[7];
                o_transform_skip_enabled_flag  <= i_rbsp_in[6];
                o_cu_qp_delta_enabled_flag     <= i_rbsp_in[5];
                if (i_rbsp_in[5]) begin
                    state_after_exp            <= `diff_cu_qp_delta_depth_s;
                end else begin
                    o_diff_cu_qp_delta_depth   <= 0;
                    state_after_exp            <= `pps_cb_qp_offset_s;
                end

            end

        `pps_skip_8bits://4
            begin
                o_forward_len                             <= 8;
                o_pps_state                               <= `pps_delay_1_cycle;
                o_transquant_bypass_enabled_flag          <= i_rbsp_in[4];
                o_loop_filter_across_slices_enabled_flag  <= i_rbsp_in[1];
                o_deblocking_filter_control_present_flag  <= i_rbsp_in[0];
                if (i_rbsp_in[0]) begin
                    pps_state_save                        <= `deblocking_filter_override_enabled_flag_s;
                end else begin
                    o_pps_deblocking_filter_disabled_flag <= 0;
                    o_pps_beta_offset_div2                <= 0;
                    o_pps_tc_offset_div2                  <= 0;
                    pps_state_save                        <= `pps_scaling_list_data_present_flag_s;
                end

            end
        `deblocking_filter_override_enabled_flag_s:
            begin
                o_deblocking_filter_override_enabled_flag  <= i_rbsp_in[7];
                pps_state_save                             <= `pps_deblocking_filter_disabled_flag_s;
                o_forward_len                              <= 1;
                o_pps_state                                <= `pps_delay_1_cycle;
            end
        `pps_deblocking_filter_disabled_flag_s:
            begin
                o_pps_deblocking_filter_disabled_flag      <= i_rbsp_in[7];
                if (i_rbsp_in[7] == 0) begin
                    state_after_exp                        <= `pps_beta_offset_div2_s;
                    pps_state_save                         <= `pps_exp_count_zero;
                end else begin
                    pps_state_save                         <= `pps_deblocking_filter_disabled_flag_s;
                end
                o_forward_len                              <= 1;
                o_pps_state                                <= `pps_delay_1_cycle;
            end

        `pps_scaling_list_data_present_flag_s:
            begin
                pps_state_save                             <= `lists_modification_present_flag_s;
                o_forward_len                              <= 1;
                o_pps_state                                <= `pps_delay_1_cycle;
            end
        `lists_modification_present_flag_s:
            begin
                o_forward_len                              <= 1;
                o_pps_state                                <= `pps_delay_1_cycle;
                pps_state_save                             <= `pps_exp_count_zero;
                state_after_exp                            <= `log2_parallel_merge_level_minus2_s;
            end
        `log2_parallel_merge_level_minus2_s:
            begin
            
            end

        `pps_end:
            begin
            
            end
        default: o_pps_state <= `rst_pps;
    endcase

endmodule
