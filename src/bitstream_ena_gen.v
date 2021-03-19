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

//synchoronous enable signals generator
module bitstream_ena_gen
(
	input wire en,
	input wire i_stream_mem_valid,
	input wire i_rbsp_buffer_valid,
	input wire i_rbsp_buf_valid_sd,

	input wire i_bc_vps_en,
	input wire i_bc_pps_en,
	input wire i_bc_sps_en,
	input wire i_bc_slice_header_en,
	input wire i_bc_slice_data_en,
	input wire i_bc_cu_en,
	input wire i_bc_tu_en,
	input wire i_bc_rps_en,
	input wire i_bc_rbsp_buffer_en,
	input wire i_bc_rbsp_buf_sd_en,


	output wire o_bc_en,
	output wire o_read_nalu_en,
	output wire o_rbsp_buffer_en,
	output wire o_rbsp_buf_sd_en,

	output wire o_vps_en,
	output wire o_pps_en,
	output wire o_sps_en,
	output wire o_slice_header_en,
	output wire o_slice_data_en,
	output wire o_cu_en,
	output wire o_tu_en,
	output wire o_rps_en,
	output wire o_residual_en,
	output wire o_intra_pred_en,
	output wire o_inter_pred_en,
	output wire o_sum_en,
	output wire o_ext_mem_writer_en,
	output wire o_ext_mem_hub_en
);

assign o_read_nalu_en       = en && i_stream_mem_valid;
assign o_rbsp_buffer_en     = en && i_stream_mem_valid && i_bc_rbsp_buffer_en;
assign o_rbsp_buf_sd_en     = en && i_stream_mem_valid && i_bc_rbsp_buf_sd_en;


assign o_bc_en              = en && i_rbsp_buffer_valid;
assign o_vps_en             = en && i_rbsp_buffer_valid && i_bc_vps_en;
assign o_sps_en             = en && i_rbsp_buffer_valid && i_bc_sps_en;
assign o_pps_en             = en && i_rbsp_buffer_valid && i_bc_pps_en;
assign o_slice_header_en    = en && i_rbsp_buffer_valid && i_bc_slice_header_en;
assign o_slice_data_en      = en && i_rbsp_buf_valid_sd && i_bc_slice_data_en;
assign o_cu_en              = en && i_rbsp_buf_valid_sd && i_bc_cu_en;
assign o_tu_en              = en && i_rbsp_buf_valid_sd && i_bc_tu_en;


assign o_rps_en             = en && i_rbsp_buffer_valid && i_bc_rps_en;
assign o_residual_en        = en && i_rbsp_buffer_valid;
assign o_intra_pred_en      = en;
assign o_inter_pred_en      = en;
assign o_sum_en             = en;
assign o_ext_mem_writer_en  = en;
assign o_ext_mem_hub_en     = en;

endmodule
