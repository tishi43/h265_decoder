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

module rbsp_buffer
(
    input wire           clk                  , //global clock and reset
    input wire           rst,
    input wire           en,
    input wire           valid_data_of_nalu_in, //enable this module, valid data of nalu 
                                                //valid data is the data except for start_code, nalu_head, competition_prevent_code
    input wire  [ 7:0]   rbsp_in,               //data from read nalu
    input wire           next_nalu_detected_nalu,
    output wire          next_nalu_detected,
    input wire  [ 3:0]   forward_len_in,        //length of bits to forward
    input wire           i_pass_buffer,
    input wire  [15:0]   i_buffer,
    input wire  [ 1:0]   i_new_nalu_bytes,


    output wire          rd_req_to_nalu_out,    //read one byte request to read nalu 
    output reg  [ 7:0]   rbsp_out,              //bits output 
    output reg           is_last_bit_of_rbsp,
    output reg  [ 3:0]   num_zero_bits,
    output wire          buffer_valid_out,
    output reg  [15:0]   buffer,

    input wire           next_nalu_detected_clr,
    input wire           forward_to_next_nalu
);

integer  seed;
initial  begin seed = $get_initial_random_seed(); end

reg     [ 2:0]     bits_offset;
reg     [ 3:0]     next_bits_offset;
reg     [ 1:0]     new_nalu_bytes;

//read_nalu next_nalu_detected过来，输出新nalu的第一个有效字节，
//再接收一字节，buffer里的2字节都是新nalu才能输给slice header/sps/pps
always @(posedge clk)
if (rst|next_nalu_detected_clr) begin
    new_nalu_bytes     <= 0;
end else if (i_pass_buffer) begin
    new_nalu_bytes     <= i_new_nalu_bytes;
end else if (next_nalu_detected_nalu&&
             valid_data_of_nalu_in &&
             rd_req_to_nalu_out && en) begin
    if (new_nalu_bytes<2)
        new_nalu_bytes <= new_nalu_bytes+1;
end

assign next_nalu_detected = new_nalu_bytes==2;

always @(*)
if (~buffer_valid_out)
    next_bits_offset     <= bits_offset;
else begin
    if ( forward_len_in == 'hf ) begin // forward_len_in 5'b11111 used to clear rbsp_trailing_bits
        next_bits_offset     <= 8;
    end else if(forward_to_next_nalu) begin
        if (new_nalu_bytes!=2)
            next_bits_offset <= 8;
        else
            next_bits_offset <= 0;
    end else begin
        next_bits_offset     <= bits_offset + forward_len_in;
    end
end

//bits_offset
always @(posedge clk)
if (rst) begin
    bits_offset     <= 3'b0;
end else if ( buffer_valid_out ) begin
    bits_offset     <= next_bits_offset[2:0];
end

reg     [1:0]     num_of_byte_to_fill;
reg               buffer_valid_out_int;

always @ (posedge clk)
if (rst) begin
    num_of_byte_to_fill      <= 2;
    buffer_valid_out_int     <= 0;
end else if (i_pass_buffer) begin
    num_of_byte_to_fill      <= 0;
    buffer_valid_out_int     <= 1;
end else if ( num_of_byte_to_fill == 0 && buffer_valid_out ) begin
    num_of_byte_to_fill      <= next_bits_offset[3];
    buffer_valid_out_int     <= (next_bits_offset[3] == 0);
end else if ( en && valid_data_of_nalu_in  && rd_req_to_nalu_out) begin
    num_of_byte_to_fill      <= num_of_byte_to_fill - 1'b1;
    buffer_valid_out_int     <= (num_of_byte_to_fill == 1);
end

assign buffer_valid_out = buffer_valid_out_int;
//equest data from nalu
assign rd_req_to_nalu_out = valid_data_of_nalu_in? (num_of_byte_to_fill > 0) : 1'b1; 
// if nalu output is invalid, request data from nalu again

//buffer
wire     [15:0]     next_buffer;
wire                buffer_refresh_wire;
assign buffer_refresh_wire = en && valid_data_of_nalu_in  && rd_req_to_nalu_out;
assign next_buffer = buffer_refresh_wire ? {buffer[7:0], rbsp_in[7:0]} : buffer;

always @ (posedge clk) 
if (rst)begin
    buffer           <= 16'b0;
end else if (i_pass_buffer) begin
    buffer           <= i_buffer;
end else if(buffer_refresh_wire)begin
    buffer           <= next_buffer;
end


reg     [7:0]     next_rbsp_out;
always@(*)
    case (next_bits_offset[2:0])
    0  :next_rbsp_out <= next_buffer[15:8];
    1  :next_rbsp_out <= next_buffer[14:7];
    2  :next_rbsp_out <= next_buffer[13:6];
    3  :next_rbsp_out <= next_buffer[12:5];
    4  :next_rbsp_out <= next_buffer[11:4];
    5  :next_rbsp_out <= next_buffer[10:3];
    6  :next_rbsp_out <= next_buffer[9:2];
    default  :next_rbsp_out <= next_buffer[8:1];
    endcase

always@(posedge clk)
`ifdef RANDOM_INIT
    if (rst)
        rbsp_out <= $random(seed);
    else
`endif
    rbsp_out <= next_rbsp_out;

//未加delay1周期之前，
//#0 state=state1，forward_len跟着state变，请求1bit，forward_len_in=1,next_bits_offset=bits_offset+forward_len_in跟着变，next_rbsp_out跟着变
//#1 state跳为state2，rbsp_out <= next_rbsp_out, num_zero_bits跟着rbsp_out变，forward_len=num_zero_bits*2+1跟着变（假定ue，se）
//往复
//加delay1周期
//#0 state=state1，forward_len=0
//#1 state=delay1cycle,forward_len=1，请求1bit，next_bits_offset=bits_offset+forward_len_in跟着变，next_rbsp_out跟着变
//#2 state跳为state2，rbsp_out <= next_rbsp_out, num_zero_bits跟着rbsp_out变，forward_len=num_zero_bits*2+1跟着变（假定ue，se）
//always @(posedge clk) forward_len <=xx; 相当于forward_len也是寄存器 


always @(*)
    case ( 1'b1 )
    rbsp_out[7] : num_zero_bits <= 0;
    rbsp_out[6] : num_zero_bits <= 1;
    rbsp_out[5] : num_zero_bits <= 2;
    rbsp_out[4] : num_zero_bits <= 3;
    rbsp_out[3] : num_zero_bits <= 4;
    rbsp_out[2] : num_zero_bits <= 5;
    rbsp_out[1] : num_zero_bits <= 6;
    rbsp_out[0] : num_zero_bits <= 7;
    default     : num_zero_bits <= 8;
    endcase


endmodule
