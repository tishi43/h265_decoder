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

module bitstream_controller
(
 input wire            clk,
 input wire            rst,
 input wire            en,
 input wire            i_ext_mem_init_done,
 input wire [ 2:0]     i_vps_state,
 input wire [ 5:0]     i_sps_state,
 input wire [ 4:0]     i_pps_state,
 input wire [ 5:0]     i_slice_header_state,
 input wire [ 4:0]     i_slice_data_state,
 input wire [ 5:0]     i_cu_state,
 input wire [ 5:0]     i_tu_state,

 input wire [ 3:0]     i_forward_len_vps,
 input wire [ 3:0]     i_forward_len_pps,
 input wire [ 3:0]     i_forward_len_sps,
 input wire [ 3:0]     i_forward_len_slice_header,
 input wire [ 3:0]     i_forward_len_rps,
 input wire            i_end_of_stream,
 input wire [ 5:0]     i_nal_unit_type,
 input wire            i_next_nalu_detected,

 output reg            o_vps_en,
 output reg            o_sps_en,
 output reg            o_pps_en,
 output reg            o_slice_header_en,
 output reg            o_slice_data_en,
 output reg            o_rst_slice_data,
 output reg            o_rst_slice_header,
 output reg            o_cu_en,
 output reg            o_tu_en,
 output reg            o_rps_en,
 output reg            o_pass_buffer2sd,
 output reg            o_pass_buffer2norm,

 output reg            o_rbsp_buffer_en,
 output reg            o_rbsp_buf_sd_en,

 output wire [ 3:0]    o_forward_len,
 output reg  [63:0]    o_pic_num,
 output reg            o_next_nalu_detected_clr,
 output wire           o_forward_to_next_nalu,
 output reg  [ 2:0]    o_bitstream_state
);

reg forward_to_next_nalu;

assign o_forward_to_next_nalu = forward_to_next_nalu;


always @(posedge clk)
if (rst) begin
    o_vps_en                                    <= 0;
    o_sps_en                                    <= 0;
    o_pps_en                                    <= 0;
    o_slice_header_en                           <= 0;
    o_slice_data_en                             <= 0;
    o_cu_en                                     <= 0;
    o_tu_en                                     <= 0;
    o_rps_en                                    <= 0;
    forward_to_next_nalu                        <= 0;
    o_bitstream_state                           <= `rst_bitstream;
    o_pass_buffer2sd                            <= 0;
    o_pass_buffer2norm                          <= 0;

    o_rbsp_buffer_en                            <= 1; //todo vps,pps,sps多次出现的情况
    o_rbsp_buf_sd_en                            <= 0;
    o_rst_slice_data                            <= 0;
    o_rst_slice_header                          <= 0;
    o_pic_num                                   <= 0;
    o_next_nalu_detected_clr                    <= 0;
end else if (en) begin
    case (o_bitstream_state)
        `rst_bitstream://0
            if (i_nal_unit_type == `nalu_type_vps && i_ext_mem_init_done) begin
                o_vps_en                        <= 1;
                o_next_nalu_detected_clr        <= 1;
                o_bitstream_state               <= `bitstream_vps;
            end

        `bitstream_forward_to_next_nalu:begin//6
            forward_to_next_nalu                <= 1'b1;
            o_pass_buffer2norm                  <= 0;
            if (i_next_nalu_detected) begin
                forward_to_next_nalu            <= 0;
                o_next_nalu_detected_clr        <= 1;
                o_bitstream_state               <= `bitstream_next_nalu;
            end
        end

        `bitstream_next_nalu: begin//7
            o_next_nalu_detected_clr     <= 0;
            if (i_nal_unit_type == `nalu_type_vps) begin
                o_vps_en                        <= 1;
                o_bitstream_state               <= `bitstream_vps;
            end
            if (i_nal_unit_type == `nalu_type_sps) begin
                o_sps_en                        <= 1;
                o_bitstream_state               <= `bitstream_sps;
            end else if (i_nal_unit_type == `nalu_type_pps) begin
                o_pps_en                        <= 1;
                o_bitstream_state               <= `bitstream_pps;
            end else begin
                o_bitstream_state               <= `bitstream_slice_header;
                o_slice_header_en               <= 1;
                o_rst_slice_header              <= 1;
            end
        end
        `bitstream_vps: begin//1
            o_next_nalu_detected_clr            <= 0;
            if (i_vps_state == `vps_end) begin
                o_vps_en                        <= 0;
                o_bitstream_state               <= `bitstream_forward_to_next_nalu;
            end
        end
        `bitstream_sps://2
            begin
                if (i_sps_state == `sps_parse_short_term_ref_pic_set_s)
                    o_rps_en                    <= 1;
                else
                    o_rps_en                    <= 0;
                if (i_sps_state == `sps_end) begin
                    o_sps_en                    <= 0;
                    o_bitstream_state           <= `bitstream_forward_to_next_nalu;
                end
            end

        `bitstream_pps://3
            if (i_pps_state == `pps_end) begin
                o_pps_en                        <= 0;
                o_bitstream_state               <= `bitstream_forward_to_next_nalu;
            end
        `bitstream_slice_header://4
            begin
                o_rst_slice_header              <= 0;
                o_pass_buffer2sd                <= 0;
                if (i_slice_header_state == `slice_header_parse_short_term_ref_pic_set)
                    o_rps_en                    <= 1;
                else
                    o_rps_en                    <= 0;
                if (~o_rst_slice_header&&
                    i_slice_header_state == `slice_header_end) begin
                    o_slice_header_en           <= 0;
                    o_slice_data_en             <= 1;
                    o_bitstream_state           <= `bitstream_slice_data;
                    o_pass_buffer2sd            <= 1;
                    o_rbsp_buffer_en            <= 0;
                    o_rbsp_buf_sd_en            <= 1;
                    o_rst_slice_data            <= 1;
                end
            end
        `bitstream_slice_data://5
            begin
                o_rst_slice_data                <= 0;
                o_pass_buffer2sd                <= 0;
                if (~o_rst_slice_data&&
                    i_slice_data_state == `slice_data_end) begin
                    o_slice_data_en             <= 0;
                    o_bitstream_state           <= `bitstream_forward_to_next_nalu;
                    o_pass_buffer2norm          <= 1; //先传递到rbsp_buffer,在rbsp_buffer前推到next nalu
                    o_rbsp_buffer_en            <= 1;
                    o_rbsp_buf_sd_en            <= 0;
                    o_pic_num                   <= o_pic_num+1;
                end else if (i_slice_data_state == `sd_forward_to_next_frame) begin
                    o_slice_data_en             <= 0;
                    o_bitstream_state           <= `bitstream_forward_to_next_nalu;
                    o_pass_buffer2norm          <= 0; //todo
                    o_rbsp_buffer_en            <= 1;
                    o_rbsp_buf_sd_en            <= 0;
                end else if (i_slice_data_state == `slice_data_pass2cu) begin
                    o_cu_en                     <= 1; //slice_data不能disable，在parse_cu判断cu的状态
                end else if (i_slice_data_state == `slice_parse_cu) begin

                    if (i_cu_state == `cu_pass2tu) begin
                        o_tu_en                 <= 1; //cu不能disable，在`parse_tu判断tu的状态
                    end

                    if (i_cu_state == `parse_tu&&i_tu_state == `tu_end) begin
                            o_tu_en             <= 0;
                    end

                    if (i_cu_state == `cu_end) begin
                        o_cu_en                 <= 0;
                    end
                end


            end
    endcase
end


assign o_forward_len = o_rps_en ? i_forward_len_rps: (
                     o_vps_en ? i_forward_len_vps : (
                     o_pps_en ? i_forward_len_pps : (
                     o_sps_en ? i_forward_len_sps : (
                     o_slice_header_en ? i_forward_len_slice_header : 0))));
endmodule
