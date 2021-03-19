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

module slice_header
(
 input wire                        clk                                        ,
 input wire                        rst                                        ,
 input wire                        global_rst                                 ,
 input wire                        en                                         ,
 input wire              [ 7: 0]   i_rbsp_in                                  ,
 input wire              [ 3: 0]   i_num_zero_bits                            ,

 input wire              [ 3: 0]   i_log2_max_pic_order_cnt_lsb_minus4        ,
 input wire              [ 5: 0]   i_nal_unit_type                            ,
 input wire              [ 3: 0]   i_num_short_term_ref_pic_sets              ,
 input wire              [ 4: 0]   i_rps_state                                ,
 input wire                        i_sps_temporal_mvp_enabled_flag            ,
 input wire                        i_sample_adaptive_offset_enabled_flag      , //sps
 input wire              [ 3: 0]   i_num_ref_idx_l0_default_active_minus1     ,//pps
 input wire                        i_cabac_init_present_flag                  ,//pps
 input wire signed       [ 4: 0]   i_pps_cb_qp_offset                         , //-12~12
 input wire signed       [ 4: 0]   i_pps_cr_qp_offset                         , //-12~12
 input wire                        i_deblocking_filter_override_enabled_flag  , //pps
 input wire signed       [ 3: 0]   i_pps_beta_offset_div2                     , //-6~6
 input wire signed       [ 3: 0]   i_pps_tc_offset_div2                       ,
 input wire                        i_pps_deblocking_filter_disabled_flag      , //pps
 input wire                        i_loop_filter_across_slices_enabled_flag   , //pps
 input wire              [ 4: 0]   i_vps_max_dec_pic_buffering                , //vps

 output reg              [ 1: 0]   o_slice_type                               ,
 output reg [`max_poc_bits-1: 0]   o_poc                                      , //todo位宽
 output reg                        o_slice_temporal_mvp_enabled_flag          ,
 output reg                        o_slice_sao_luma_flag                      ,
 output reg                        o_slice_sao_chroma_flag                    ,
 output reg              [ 3: 0]   o_num_ref_idx                              ,
 output reg                        o_cabac_init_flag                          ,
 output reg              [ 3: 0]   o_collocated_ref_idx                       ,
 output reg              [ 2: 0]   o_five_minus_max_num_merge_cand            , //The value of MaxNumMergeCand shall be in the range of 1 to 5, inclusive
 output reg signed       [ 6: 0]   o_slice_qp_delta                           , //SliceQpY shall be in the range of -QpBdOffsetY to +51, inclusive
 output reg signed       [ 4: 0]   o_slice_cb_qp_offset                       ,//The value of pps_cb_qp_offset+slice_cb_qp_offset shall be in the range of -12 to +12, inclusive
 output reg signed       [ 4: 0]   o_slice_cr_qp_offset                       ,
 output reg signed       [ 3: 0]   o_slice_beta_offset_div2                   , //The values of slice_beta_offset_div2 and slice_tc_offset_div2 shall both be in the range of -6 to 6, inclusive.
 output reg signed       [ 3: 0]   o_slice_tc_offset_div2                     ,


 output reg              [ 3: 0]   o_rps_idx                                  ,
 output reg                        o_rst_rps_module                           ,

 output reg              [ 5: 0]   o_slice_header_state                       ,
 output reg              [ 3: 0]   o_forward_len                              ,

 output reg                        o_bram_rps_we                              ,
 output reg              [ 7: 0]   o_bram_rps_addr                            ,
 input  wire             [31: 0]   i_bram_rps_dout                            ,
 output rps_t                      o_slice_local_rps                          ,
 output reg[`max_ref-1:0][ 3: 0]   o_ref_dpb_slots                            ,
 output reg              [ 3: 0]   o_cur_pic_dpb_slot                         

);



reg                       short_term_ref_pic_set_sps_flag;
reg                       num_ref_idx_active_override_flag;
reg                       is_sao_enabled;
reg                       is_dbf_enabled;
reg                       deblocking_filter_override_flag;
reg                       slice_deblocking_filter_disabled_flag;
reg      [ 3:0]           short_term_ref_pic_set_idx;
reg                       slice_loop_filter_across_slices_enabled_flag;

reg      [ 3:0]           bits_read;
reg      [ 5:0]           slice_header_state_save;
reg      [ 2:0]           i;
wire     [ 2:0]           iplus2;
reg                       cond_ref_dpb_slot0;
reg                       cond_ref_dpb_slot1;
reg                       cond_ref_dpb_slot2;
reg                       cond_ref_dpb_slot3;
reg                       cond_ref_dpb_slot4;
reg                       cond_ref_dpb_slot5;

wire [`max_poc_bits-1:0]  max_poc_lsb;
reg  [`max_poc_bits-1:0]  poc_msb;
reg  [`max_poc_bits-1:0]  pic_order_cnt_lsb;
reg  [`max_poc_bits-1:0]  prev_poc_lsb;
reg  [ 4:0]               max_short_term_ref_pic_set_idx;

reg  [ `max_dpb:0][`max_poc_bits-1:0]  dpb_poc; //DPB暂只5个
reg  [ `max_dpb:0]                     use_for_ref;
reg  [ 2:0]                            min_poc_dpb_slot;
reg  [`max_poc_bits-1:0]               min_poc;

assign max_poc_lsb = 1 << (i_log2_max_pic_order_cnt_lsb_minus4+4);
assign iplus2 = i+2;

reg     [ 4:0]     state_after_exp;
reg     [15:0]     ue;
reg     [15:0]     se;
reg     [ 3:0]     leadingZerobits;
reg     [ 3:0]     bits_total;
reg     [ 3:0]     bits_left;

always @ (posedge clk)
if (global_rst) begin
    o_forward_len                            <= 0;
end else if (rst) begin
    o_slice_header_state                     <= 0;
    o_forward_len                            <= 0;
    leadingZerobits                          <= 0;
    ue                                       <= 0;
    se                                       <= 0;
    use_for_ref                              <= 6'd0;
end else if (en)
    case (o_slice_header_state)
        `rst_slice_header:
            begin
                is_dbf_enabled               <= ~i_pps_deblocking_filter_disabled_flag;
                o_slice_header_state         <= `first_slice_segment_in_pic_flag_s;//a
            end
        `slice_header_delay_1_cycle://0x22
            begin
                o_forward_len                <= 0;
                o_slice_header_state         <= slice_header_state_save;
            end

        `sh_exp_count_zero://0x23
            begin
                leadingZerobits              <= leadingZerobits+i_num_zero_bits;
                o_forward_len                <= i_num_zero_bits;
                o_slice_header_state         <= `slice_header_delay_1_cycle;
                slice_header_state_save      <= `sh_exp_count_zero;
                if (~i_num_zero_bits[3]) begin //<8
                    slice_header_state_save  <= `sh_exp_golomb_calc;
                    bits_left                <= leadingZerobits+i_num_zero_bits+1;
                    bits_total               <= leadingZerobits+i_num_zero_bits+1;
                end
            end

        `sh_exp_golomb_calc: begin//0x24
            if (bits_left>8) begin
                bits_left                 <= bits_left - 8;
                o_forward_len             <= 8;
                ue                        <= i_rbsp_in[7:0];
                slice_header_state_save   <= `sh_exp_golomb_calc;
            end else begin
                case (bits_left)
                1:ue      <= {24'd0,ue[7:0],i_rbsp_in[7]} - 1; //          1
                2:ue      <= {24'd0,ue[7:0],i_rbsp_in[7:6]} - 1; //       01x
                3:ue      <= {24'd0,ue[7:0],i_rbsp_in[7:5]} - 1; //      001xx
                4:ue      <= {24'd0,ue[7:0],i_rbsp_in[7:4]} - 1; //     0001xxx
                5:ue      <= {24'd0,ue[7:0],i_rbsp_in[7:3]} - 1; //    00001xxxx
                6:ue      <= {24'd0,ue[7:0],i_rbsp_in[7:2]} - 1; //   000001xxxxx
                7:ue      <= {24'd0,ue[7:0],i_rbsp_in[7:1]} - 1; //  0000001xxxxxx
                //8:ue      <= {24'd0,ue[7:0],i_rbsp_in[7:0]} - 1; // 00000001xxxxxxx
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
                //不可能有,省点路径
                //8:se        <= i_rbsp_in[0]? -i_rbsp_in[7:1]: i_rbsp_in[7:1];
                //9:se        <= i_rbsp_in[7]? -i_rbsp_in[7:0] : i_rbsp_in[7:0];
                //10:se       <= i_rbsp_in[6]? -{ue[7:0],i_rbsp_in[7]} : {ue[7:0],i_rbsp_in[7]};
                //11:se       <= i_rbsp_in[5]? -{ue[7:0],i_rbsp_in[7:6]} : {ue[7:0],i_rbsp_in[7:6]};
                //12:se       <= i_rbsp_in[4]? -{ue[7:0],i_rbsp_in[7:5]} : {ue[7:0],i_rbsp_in[7:5]};
                //13:se       <= i_rbsp_in[3]? -{ue[7:0],i_rbsp_in[7:4]} : {ue[7:0],i_rbsp_in[7:4]};
                //14:se       <= i_rbsp_in[2]? -{ue[7:0],i_rbsp_in[7:3]} : {ue[7:0],i_rbsp_in[7:3]};
                default:se      <= 0;
                endcase
                o_forward_len             <= bits_left;
                slice_header_state_save   <= `sh_exp_golomb_end;
            end

            o_slice_header_state          <= `slice_header_delay_1_cycle;
        end

        `sh_exp_golomb_end://0x25
            begin
                leadingZerobits                     <= 0; //reinit
                ue                                  <= 0;
                se                                  <= 0;
                case (state_after_exp)
                `slice_pic_parameter_set_id_s://0x17
                    begin
                        o_slice_header_state                  <= `sh_exp_count_zero;
                        state_after_exp                       <= `slice_type_s;
                    end

                `slice_type_s://0x18
                    begin
                        o_slice_type                          <= ue;
                        if (i_nal_unit_type == 19 ||
                            i_nal_unit_type == 20) begin
                            o_poc                             <= 0;
                            prev_poc_lsb                      <= 0;
                            poc_msb                           <= 0;
                            dpb_poc[`max_dpb:1]               <= {`max_dpb{16'hffff}};
                            dpb_poc[0]                        <= 0;
                            o_cur_pic_dpb_slot                <= 0;
                            o_slice_temporal_mvp_enabled_flag <= 0;
                            o_slice_header_state              <= `is_slice_sao_luma_chroma_flag_present;
                        end else begin
                            o_slice_header_state              <= `pic_order_cnt_lsb_s;
                            bits_read                         <= 0;
                            pic_order_cnt_lsb                 <= 0;
                        end
                    end

                `num_ref_idx_s://0x19
                    begin
                        o_num_ref_idx                         <= ue+1;
                        o_slice_header_state                  <= `is_cabac_init_flag_present;
                    end
                `collocated_ref_idx_s://0x1a
                    begin
                        o_collocated_ref_idx                  <= ue;
                        state_after_exp                       <= `five_minus_max_num_merge_cand_s;
                        o_slice_header_state                  <= `sh_exp_count_zero;
                    end
                `five_minus_max_num_merge_cand_s://0x1b
                    begin
                        o_five_minus_max_num_merge_cand       <= ue;
                        state_after_exp                       <= `slice_qp_delta_s;
                        o_slice_header_state                  <= `sh_exp_count_zero;
                    end
                `slice_qp_delta_s://0x1c
                    begin
                        o_slice_qp_delta                      <= se;
                        if (i_pps_cb_qp_offset) begin
                            state_after_exp                   <= `slice_qp_delta_cb_s;
                            o_slice_header_state              <= `sh_exp_count_zero;
                        end else begin
                            o_slice_cb_qp_offset              <= 0;
                            if (i_pps_cr_qp_offset) begin
                                state_after_exp               <= `slice_qp_delta_cr_s;
                                o_slice_header_state          <= `sh_exp_count_zero;
                            end else begin
                                o_slice_cr_qp_offset          <= 0;
                                o_slice_header_state          <= `is_deblocking_filter_override_flag_present;//7
                            end
                        end
                    end
                `slice_qp_delta_cb_s://0x1d
                    begin
                        o_slice_cb_qp_offset                  <= se;
                        if (i_pps_cr_qp_offset) begin
                            state_after_exp                   <= `slice_qp_delta_cr_s;
                            o_slice_header_state              <= `sh_exp_count_zero;
                        end else begin
                            o_slice_cr_qp_offset              <= 0;
                            o_slice_header_state              <= `is_deblocking_filter_override_flag_present;
                        end
                    end
                `slice_qp_delta_cr_s://0x1e
                    begin
                        o_slice_cr_qp_offset                  <= se;
                        o_slice_header_state                  <= `is_deblocking_filter_override_flag_present;
                    end
                `slice_beta_offset_div2_s://0x1f
                    begin
                        o_slice_beta_offset_div2              <= se;
                        state_after_exp                       <= `slice_tc_offset_div2_s;
                        o_slice_header_state                  <= `sh_exp_count_zero;
                    end
                `slice_tc_offset_div2_s://0x20
                    begin
                        o_slice_tc_offset_div2                <= se;
                        o_slice_header_state                  <= `is_slice_loop_filter_across_slices_enabled_flag_present;
                    end
                endcase
            end


        `first_slice_segment_in_pic_flag_s :
            begin
                if (i_nal_unit_type == 19 ||
                    i_nal_unit_type == 20 ||
                    i_nal_unit_type == 18 ||
                    i_nal_unit_type == 17 ||
                    i_nal_unit_type == 16 ||
                    i_nal_unit_type == 21)
                    slice_header_state_save           <= `no_output_of_prior_pics_flag_s;
                else begin
                    state_after_exp                   <= `slice_pic_parameter_set_id_s;
                    slice_header_state_save           <= `sh_exp_count_zero;
                end
                o_forward_len                         <= 1;
                o_slice_header_state                  <= `slice_header_delay_1_cycle;
            end
        `no_output_of_prior_pics_flag_s://0xb
            begin
                slice_header_state_save               <= `sh_exp_count_zero;
                state_after_exp                       <= `slice_pic_parameter_set_id_s;
                o_forward_len                         <= 1;
                o_slice_header_state                  <= `slice_header_delay_1_cycle;
            end
        `pic_order_cnt_lsb_s://0xc
            begin
                bits_read                             <= bits_read + 1;
                pic_order_cnt_lsb                     <= (pic_order_cnt_lsb << 1) + i_rbsp_in[7];
                o_forward_len                         <= 1;
                if (bits_read == i_log2_max_pic_order_cnt_lsb_minus4 + 3) begin
                    slice_header_state_save           <= `calc_poc_1;
                end else begin
                    slice_header_state_save           <= `pic_order_cnt_lsb_s;
                end
                o_slice_header_state                  <= `slice_header_delay_1_cycle;
            end

        `calc_poc_1://0x3
            begin
                if (pic_order_cnt_lsb < prev_poc_lsb) begin
                    poc_msb                           <= poc_msb + max_poc_lsb;
                end
                o_slice_header_state                  <= `calc_poc_2;
            end
        `calc_poc_2://0x26
            begin
                o_poc                                 <= poc_msb + pic_order_cnt_lsb;
                prev_poc_lsb                          <= pic_order_cnt_lsb;
                o_slice_header_state                  <= `short_term_ref_pic_set_sps_flag_s;
            end
        `short_term_ref_pic_set_sps_flag_s://0xd
            begin
                short_term_ref_pic_set_sps_flag       <= i_rbsp_in[7];
                if (i_rbsp_in[7] == 0) begin
                    o_rps_idx                         <= i_num_short_term_ref_pic_sets;
                    o_rst_rps_module                  <= 1;
                    slice_header_state_save           <= `slice_header_parse_short_term_ref_pic_set;
                end else begin
                    max_short_term_ref_pic_set_idx    <= 2;
                    short_term_ref_pic_set_idx        <= 0;
                    slice_header_state_save           <= `short_term_ref_pic_set_idx_s;
                end
                o_forward_len                         <= 1;
                o_slice_header_state                  <= `slice_header_delay_1_cycle;
            end

        `short_term_ref_pic_set_idx_s://0xe
            begin
                //i_num_short_term_ref_pic_sets=16, 2,4,8,16,进4次
                //i_num_short_term_ref_pic_sets=17, 2,4,8,16,32
                short_term_ref_pic_set_idx            <= (short_term_ref_pic_set_idx << 1) + i_rbsp_in[7];
                max_short_term_ref_pic_set_idx        <= max_short_term_ref_pic_set_idx<<1;
                if (max_short_term_ref_pic_set_idx>=i_num_short_term_ref_pic_sets) begin
                    slice_header_state_save           <= `fetch_slice_local_rps_1;
                end else begin
                    slice_header_state_save           <= `short_term_ref_pic_set_idx_s;
                end

                o_forward_len                         <= 1;
                o_slice_header_state                  <= `slice_header_delay_1_cycle;
            end

        `slice_header_parse_short_term_ref_pic_set:
            begin
                o_rst_rps_module                      <= 0;
                if (i_rps_state == `rps_end) begin
                    short_term_ref_pic_set_idx        <= i_num_short_term_ref_pic_sets;
                    o_slice_header_state              <= `fetch_slice_local_rps_1;
                end
            end

        `fetch_slice_local_rps_1://0x27
            begin
                o_bram_rps_we                         <= 0;
                o_bram_rps_addr                       <= {1'b0,short_term_ref_pic_set_idx,3'd0};
                o_slice_header_state                  <= `fetch_slice_local_rps_2;
            end

        `fetch_slice_local_rps_2://0x28
            begin
                o_bram_rps_addr                       <= {1'b0,short_term_ref_pic_set_idx,3'd1};
                o_slice_header_state                  <= `fetch_slice_local_rps_3;
                i                                     <= 0;
            end

        `fetch_slice_local_rps_3://0x29
            begin
                i                                     <= i+1;
                o_bram_rps_addr                       <= {1'b0,short_term_ref_pic_set_idx,iplus2};
                o_slice_local_rps                     <= {i_bram_rps_dout,o_slice_local_rps[255:32]};
                if (i == 7) begin
                    o_slice_header_state              <= `calc_dpb_slot_1;
                end
            end
        `calc_dpb_slot_1://0x2a
            begin
                if (i_nal_unit_type == 19 ||
                    i_nal_unit_type == 20) begin
                    use_for_ref                      <= 6'd0;
                    o_cur_pic_dpb_slot               <= 0;
                end else begin
                    cond_ref_dpb_slot0               <= o_poc-o_slice_local_rps.deltaPoc[i]==dpb_poc[0];
                    cond_ref_dpb_slot1               <= o_poc-o_slice_local_rps.deltaPoc[i]==dpb_poc[1];
                    cond_ref_dpb_slot2               <= o_poc-o_slice_local_rps.deltaPoc[i]==dpb_poc[2];
                    cond_ref_dpb_slot3               <= o_poc-o_slice_local_rps.deltaPoc[i]==dpb_poc[3];
                    cond_ref_dpb_slot4               <= o_poc-o_slice_local_rps.deltaPoc[i]==dpb_poc[4];
                    cond_ref_dpb_slot5               <= o_poc-o_slice_local_rps.deltaPoc[i]==dpb_poc[5];
                    o_slice_header_state             <= `calc_dpb_slot_2;
                end
            end
        `calc_dpb_slot_2://0x2b
            begin
                i                                    <= i+1;
                if (cond_ref_dpb_slot0) begin
                    o_ref_dpb_slots[i]               <= 0;
                    use_for_ref[0]                   <= 1;
                end else if (cond_ref_dpb_slot1) begin
                    o_ref_dpb_slots[i]               <= 1;
                    use_for_ref[1]                   <= 1;
                end else if (cond_ref_dpb_slot2) begin
                    o_ref_dpb_slots[i]               <= 2;
                    use_for_ref[2]                   <= 1;
                end else if (cond_ref_dpb_slot3) begin
                    o_ref_dpb_slots[i]               <= 3;
                    use_for_ref[3]                   <= 1;
                end else if (cond_ref_dpb_slot4) begin
                    o_ref_dpb_slots[i]               <= 4;
                    use_for_ref[4]                   <= 1;
                end else if (cond_ref_dpb_slot5) begin
                    o_ref_dpb_slots[i]               <= 5;
                    use_for_ref[5]                   <= 1;
                end
                min_poc                              <= 16'hffff;
                if (i==o_slice_local_rps.num_of_pics-1) begin
                    o_slice_header_state             <= `remove_min_poc_unref_dpb_1;
                    i                                <= 0;
                end else begin
                    o_slice_header_state             <= `calc_dpb_slot_1;
                end
            end

        `remove_min_poc_unref_dpb_1://0x2c
            begin
                i                                    <= i+1;
                if (use_for_ref[i] == 0 && (min_poc > dpb_poc[i]||dpb_poc[i]==16'hffff)) begin
                    min_poc                          <= dpb_poc[i];
                    min_poc_dpb_slot                 <= i;
                end
                if (i == `max_dpb||dpb_poc[i]==16'hffff) begin
                    o_slice_header_state             <= `remove_min_poc_unref_dpb_2;
                end
            end

        `remove_min_poc_unref_dpb_2://0x2d
            begin
                o_cur_pic_dpb_slot                    <= min_poc_dpb_slot;
                dpb_poc[min_poc_dpb_slot]             <= o_poc;
                if (i_sps_temporal_mvp_enabled_flag) begin
                    o_slice_header_state              <= `slice_temporal_mvp_enabled_flag_s;
                end else begin
                    o_slice_temporal_mvp_enabled_flag <= 0;
                    o_slice_header_state              <= `is_slice_sao_luma_chroma_flag_present;
                end
            end

        `slice_temporal_mvp_enabled_flag_s://0xf
            begin
                o_slice_temporal_mvp_enabled_flag     <= i_rbsp_in[7];
                o_forward_len                         <= 1;
                slice_header_state_save               <= `is_slice_sao_luma_chroma_flag_present;
                o_slice_header_state                  <= `slice_header_delay_1_cycle;
            end

        `is_slice_sao_luma_chroma_flag_present://4
            begin
                if (i_sample_adaptive_offset_enabled_flag)
                    o_slice_header_state              <= `slice_sao_luma_flag_s;//0x10
                else begin
                    o_slice_sao_luma_flag             <= 0;
                    o_slice_sao_chroma_flag           <= 0;
                    if (o_slice_type != `I_SLICE)
                        o_slice_header_state          <= `num_ref_idx_active_override_flag_s;
                    else
                        o_slice_header_state          <= `is_cabac_init_flag_present;
                end
            end
        `slice_sao_luma_flag_s://0x10
            begin
                o_slice_sao_luma_flag                 <= i_rbsp_in[7];
                slice_header_state_save               <= `slice_sao_chroma_flag_s;
                o_forward_len                         <= 1;
                o_slice_header_state                  <= `slice_header_delay_1_cycle;
            end
        `slice_sao_chroma_flag_s://0x11
            begin
                o_slice_sao_chroma_flag               <= i_rbsp_in[7];
                if (o_slice_type != `I_SLICE)
                    slice_header_state_save           <= `num_ref_idx_active_override_flag_s;
                else
                    slice_header_state_save           <= `is_cabac_init_flag_present;//5
                o_forward_len                         <= 1;
                o_slice_header_state                  <= `slice_header_delay_1_cycle;
            end
        `num_ref_idx_active_override_flag_s://0x12
            begin
                num_ref_idx_active_override_flag      <= i_rbsp_in[7];
                if (i_rbsp_in[7]) begin
                    slice_header_state_save           <= `sh_exp_count_zero;
                    state_after_exp                   <= `num_ref_idx_s;
                end else begin
                    o_num_ref_idx                     <= i_num_ref_idx_l0_default_active_minus1 + 1;
                    slice_header_state_save           <= `is_cabac_init_flag_present;
                end
                o_forward_len                         <= 1;
                o_slice_header_state                  <= `slice_header_delay_1_cycle;
            end

        `is_cabac_init_flag_present://5
            begin
                if (i_cabac_init_present_flag && o_slice_type != `I_SLICE)
                    o_slice_header_state              <= `cabac_init_flag_s;
                else begin
                    o_cabac_init_flag                 <= 0;
                    o_slice_header_state              <= `is_collocated_ref_idx_present;//6
                end

            end
        `cabac_init_flag_s://0x13
            begin
                o_cabac_init_flag                     <= i_rbsp_in[7];
                slice_header_state_save               <= `is_collocated_ref_idx_present;
                o_forward_len                         <= 1;
                o_slice_header_state                  <= `slice_header_delay_1_cycle;
            end
        `is_collocated_ref_idx_present://0x6
            begin
                if (o_slice_type != `I_SLICE) begin
                    if (o_slice_temporal_mvp_enabled_flag) begin
                        if (o_num_ref_idx > 1) begin
                            o_slice_header_state      <= `sh_exp_count_zero;
                            state_after_exp           <= `collocated_ref_idx_s;//0x1a
                        end else begin
                            o_collocated_ref_idx      <= 0;
                            o_slice_header_state      <= `sh_exp_count_zero;
                            state_after_exp           <= `five_minus_max_num_merge_cand_s;//0x1b
                        end
                    end else begin
                        o_slice_header_state          <= `sh_exp_count_zero;
                        state_after_exp               <= `five_minus_max_num_merge_cand_s;
                    end

                end else begin
                    o_slice_header_state              <= `sh_exp_count_zero;
                    state_after_exp                   <= `slice_qp_delta_s;//0x1c
                end
            end


        `is_deblocking_filter_override_flag_present://7
            begin
                if (i_sample_adaptive_offset_enabled_flag)
                    if (o_slice_sao_luma_flag || o_slice_sao_chroma_flag)
                        is_sao_enabled                <= 1;
                    else
                        is_sao_enabled                <= 0;
                else
                    is_sao_enabled                    <= 0;
                o_slice_beta_offset_div2              <= i_pps_beta_offset_div2;
                o_slice_tc_offset_div2                <= i_pps_tc_offset_div2;
                deblocking_filter_override_flag       <= 0;
                slice_deblocking_filter_disabled_flag <= i_pps_deblocking_filter_disabled_flag;
                if (i_deblocking_filter_override_enabled_flag)
                    o_slice_header_state              <= `deblocking_filter_override_flag_s;//0x14
                else
                    o_slice_header_state              <= `is_slice_loop_filter_across_slices_enabled_flag_present;//0x9

            end
        `deblocking_filter_override_flag_s:
            begin
                deblocking_filter_override_flag       <= i_rbsp_in[7];
                if (i_rbsp_in[7])
                    slice_header_state_save           <= `slice_deblocking_filter_disabled_flag_s;
                else
                    slice_header_state_save           <= `is_slice_loop_filter_across_slices_enabled_flag_present;
                o_forward_len                         <= 1;
                o_slice_header_state                  <= `slice_header_delay_1_cycle;
            end
        `slice_deblocking_filter_disabled_flag_s:
            begin
                slice_deblocking_filter_disabled_flag <= i_rbsp_in[7];
                if (!i_rbsp_in[7]) begin
                    slice_header_state_save           <= `sh_exp_count_zero;
                    state_after_exp                   <= `slice_beta_offset_div2_s;
                end else begin
                    slice_header_state_save           <= `is_slice_loop_filter_across_slices_enabled_flag_present;
                end
                o_forward_len                         <= 1;
                o_slice_header_state                  <= `slice_header_delay_1_cycle;
            end

        `is_slice_loop_filter_across_slices_enabled_flag_present://0x9
            begin
                if (i_loop_filter_across_slices_enabled_flag && (is_dbf_enabled || is_sao_enabled))
                    o_slice_header_state              <= `slice_loop_filter_across_slices_enabled_flag_s;//0x16
                else begin
                    slice_loop_filter_across_slices_enabled_flag <=  0;
                    o_slice_header_state              <= `slice_header_byte_alignment;
                end
            end
        `slice_loop_filter_across_slices_enabled_flag_s://0x16
            begin
                slice_loop_filter_across_slices_enabled_flag <= i_rbsp_in[7];
                slice_header_state_save               <= `slice_header_byte_alignment;//0x21
                o_forward_len                         <= 1;
                o_slice_header_state                  <= `slice_header_delay_1_cycle;
            end
        `slice_header_byte_alignment://0x21
            begin
                slice_header_state_save               <= `slice_header_end;
                o_forward_len                         <= -1;
                o_slice_header_state                  <= `slice_header_delay_1_cycle;
            end
        `slice_header_end://0x1
            begin

            end

        default: o_slice_header_state <= `rst_slice_header;
    endcase



endmodule
