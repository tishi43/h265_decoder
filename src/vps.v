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


module vps
(
 input wire            clk,
 input wire            rst,
 input wire            en ,
 input wire [7:0]      i_rbsp_in,
 input wire [3:0]      i_num_zero_bits,
 output reg [4:0]      o_vps_max_dec_pic_buffering,
 output reg [2:0]      o_vps_state,
 output reg [3:0]      o_forward_len
);


reg [ 7:0] bits_skipped;
reg [ 3:0] vps_state_save;

reg [ 1:0] exp_state;
reg [ 1:0] exp_state_save;
reg [ 7:0] ue;
reg [ 3:0] leadingZerobits;


always @ (posedge clk)
if (rst) begin
    o_vps_max_dec_pic_buffering              <= 0;
    o_vps_state                              <= 0;
    o_forward_len                            <= 0;
end else if (en) begin

    case (o_vps_state)
        `rst_vps:
            begin
                bits_skipped <= 0;
                o_forward_len <= 8;
                o_vps_state <= `vps_skip_128bits;
            end
        `vps_skip_128bits:
            begin
                bits_skipped <= bits_skipped + o_forward_len;
                if (bits_skipped == 120) begin
                    o_forward_len <= 0;
                    o_vps_state <= `vps_sub_layer_ordering_info_present_flag_s;
                end
            end

        `vps_sub_layer_ordering_info_present_flag_s://2
            begin
                o_forward_len     <= 1;
                vps_state_save    <= `vps_max_dec_pic_buffering_minus1_i_s;
                exp_state_save    <= `exp_golomb_count_zero;
                leadingZerobits   <= 0;
                ue                <= 0;
                o_vps_state       <= `vps_delay_1_cycle;
            end
        `vps_max_dec_pic_buffering_minus1_i_s://4
            case (exp_state)
                `exp_golomb_count_zero: begin
                    leadingZerobits  <= i_num_zero_bits;
                    o_forward_len    <= i_num_zero_bits;
                    o_vps_state      <= `vps_delay_1_cycle;
                    exp_state_save   <= `exp_golomb_calc;
                end
                `exp_golomb_calc: begin
                    case (leadingZerobits)
                    0: ue            <= 0;
                    1: ue            <= i_rbsp_in[7:6] - 1;
                    2: ue            <= i_rbsp_in[7:5] - 1;
                    3: ue            <= i_rbsp_in[7:4] - 1;
                    4: ue            <= i_rbsp_in[7:3] - 1;
                    5: ue            <= i_rbsp_in[7:2] - 1;
                    6: ue            <= i_rbsp_in[7:1] - 1;
                    7: ue            <= i_rbsp_in[7:0] - 1;
                    default: ue      <= 0; //假定不可能到8
                    endcase
                    o_forward_len    <= leadingZerobits+1;
                    exp_state_save   <= `exp_golomb_end;
                    o_vps_state      <= `vps_delay_1_cycle;
                end
                `exp_golomb_end: begin
                    o_vps_max_dec_pic_buffering   <= ue + 1;
                    o_vps_state                   <= `vps_end;
                end
            endcase

        `vps_delay_1_cycle:
            begin
                o_forward_len     <= 0;
                o_vps_state       <= vps_state_save;
                exp_state         <= exp_state_save;
            end
        `vps_end:
            begin
            
            end
        default: o_vps_state <= `rst_vps;
    endcase
end
endmodule
