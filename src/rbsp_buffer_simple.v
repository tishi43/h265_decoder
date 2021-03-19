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

module rbsp_buffer_simple
(
    input wire                 clk                            , //global clock and reset
    input wire                 rst                            ,
    input wire                 en                             ,
    input wire                 valid_data_of_nalu_in          , //enable this module, valid data of nalu 
                                                                //valid data is the data except for start_code, nalu_head,
                                                                //competition_prevent_code
    input wire      [ 7:0]     rbsp_in                        , //data from read nalu
    input wire      [ 2:0]     forward_len_in                 , //length of bits to forward
    input wire                 next_nalu_detected_nalu        ,
    input  wire                next_nalu_detected_clr         ,
    output wire                rd_req_to_nalu_out             , //read one byte request to read nalu 
(*mark_debug="true"*)
    output reg      [ 7:0]     rbsp_out                       , //bits output
(*mark_debug="true"*)
    output reg      [15:0]     buffer                         ,
    output reg      [ 8:0]     leading9bits                   ,
    output wire                buffer_valid_out               ,
    input  wire                i_pass_buffer                  ,
    input  wire     [15:0]     i_buffer                       ,
    output reg      [ 1:0]     o_new_nalu_bytes               
);

integer  seed;
initial  begin seed = $get_initial_random_seed(); end

always @(posedge clk)
if (rst|next_nalu_detected_clr) begin
    o_new_nalu_bytes     <= 0;
end else if (next_nalu_detected_nalu&&
             valid_data_of_nalu_in &&
             rd_req_to_nalu_out && en) begin
    if (o_new_nalu_bytes<2)
        o_new_nalu_bytes <= o_new_nalu_bytes+1;
end

reg     [1:0]    is_last_byte_of_rbsp;
reg     [2:0]    bits_offset;
reg     [3:0]    next_bits_offset;

always @(*)
if (~buffer_valid_out)
    next_bits_offset <= bits_offset;
else begin
    next_bits_offset <= bits_offset + forward_len_in;
end


//a4 19 aa
//bits_offset
always @(posedge clk)
if (rst) begin
    bits_offset <= 3'b0;
end else if (i_pass_buffer) begin
    bits_offset <= 1;
end else if ( buffer_valid_out ) begin
    bits_offset <= next_bits_offset[2:0];
end

reg  num_of_byte_to_fill;
reg buffer_valid_out_int;
//num_of_byte_to_fill
always @ (posedge clk)
if (rst) begin
    num_of_byte_to_fill          <= 0;
    buffer_valid_out_int         <= 0;
end else if (i_pass_buffer) begin
    num_of_byte_to_fill          <= 1;
    buffer_valid_out_int         <= 0;
end else begin
    //rbsp buffer en=0之后,等现有的buffer耗光buffer_valid_out才置0,不是立刻置0
    if ( num_of_byte_to_fill == 0 && buffer_valid_out ) begin
        num_of_byte_to_fill     <= next_bits_offset[3];
        buffer_valid_out_int    <= (next_bits_offset[3] == 0);
    end else if ( en && valid_data_of_nalu_in  && rd_req_to_nalu_out) begin
        num_of_byte_to_fill     <= num_of_byte_to_fill - 1'b1;
        buffer_valid_out_int    <= (num_of_byte_to_fill == 1);
    end
end

assign buffer_valid_out = buffer_valid_out_int;
//equest data from nalu
assign rd_req_to_nalu_out = valid_data_of_nalu_in? (num_of_byte_to_fill > 0) : 1'b1; 
// if nalu output is invalid, request data from nalu again

//buffer

wire [15:0] next_buffer;
wire buffer_refresh_wire;
assign buffer_refresh_wire = en && valid_data_of_nalu_in  && rd_req_to_nalu_out;
assign next_buffer = buffer_refresh_wire ? {buffer[7:0], rbsp_in[7:0]} : buffer;


always @ (posedge clk) 
if (rst)begin
    buffer       <= 16'b0;
    leading9bits <= 0;
end
else if (i_pass_buffer) begin
    buffer       <= i_buffer;
    leading9bits <= i_buffer[15:7];
end
else if(buffer_refresh_wire)begin
    buffer[15:0]  <= next_buffer;
end


reg [7:0] next_rbsp_out;
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

endmodule
