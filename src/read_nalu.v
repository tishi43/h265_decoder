//--------------------------------------------------------------------------------------------------
// Design    : bvp
// Author(s) : qiu bin, shi tian qi
// Email     : chat1@126.com, tishi1@126.com
// Copyright (C) 2013-2017 qiu bin, shi tian qi
// All rights reserved
// Phone 15957074161
// QQ:1517642772
//-------------------------------------------------------------------------------------------------

module read_nalu
(
 input  wire            clk,
 input  wire            rst,
 input  wire            en ,
 input  wire            rd_req_by_rbsp_buffer_in,
(*mark_debug="true"*)
 input  wire [ 7:0]     mem_data_in,

 output wire [ 5:0]     nal_unit_type,
(*mark_debug="true"*)
 output reg  [31:0]     stream_mem_addr,
 output wire            mem_rd_req_out,
 output wire [ 7:0]     rbsp_data_out,
 output wire            rbsp_valid_out,
 input  wire            next_nalu_detected_clr,
 output reg             next_nalu_detected
);

integer  seed;
initial  begin seed = $get_initial_random_seed(); end


//nslu
parameter NaluStartBytes = 24'h000001;
//ebsp to rbsp
parameter emulation_prevention_three_byte = 24'h000003;

reg    [7:0]      nalu_head;
reg               nalu_valid;
reg               skip_nalu_head;

reg    [7:0]      last_byte3;
reg    [7:0]      last_byte2;
reg    [7:0]      last_byte1;
reg    [7:0]      current_byte;
reg    [7:0]      next_byte1;
reg    [7:0]      next_byte2;
reg    [7:0]      next_byte3;
reg    [7:0]      next_byte4;

reg               start_bytes_detect;
wire              next_start_bytes_detect;
reg               vps_found;


assign next_start_bytes_detect =  {next_byte1,next_byte2,next_byte3} == NaluStartBytes ||
                                  {next_byte1,next_byte2,next_byte3,next_byte4} == {8'h00,NaluStartBytes} ;


always @(posedge clk)
if (rst)
   stream_mem_addr  <=  0;
else if (en && mem_rd_req_out == 1'b1)
   stream_mem_addr  <= stream_mem_addr + 1;


always @(posedge clk)
if (rst)
begin

   last_byte1             <= 8'b0;
   last_byte2             <= 8'b0;
   last_byte3             <= 8'b0;
   current_byte           <= 8'b0;
   next_byte1             <= 8'b0;
   next_byte2             <= 8'b0;
   next_byte3             <= 8'b0;
   next_byte4             <= 8'b0;
end
else if (en && mem_rd_req_out)
begin
   next_byte4             <= mem_data_in;
   next_byte3             <= next_byte4;
   next_byte2             <= next_byte3;
   next_byte1             <= next_byte2;
   current_byte           <= next_byte1;
   last_byte1             <= current_byte;
   last_byte2             <= last_byte1;
   last_byte3             <= last_byte2; 
end

//detect nalu start bytes
always @(posedge clk)
if (rst)
`ifdef RANDOM_INIT
    skip_nalu_head         <= random(seed);
`endif
    start_bytes_detect     <= 1'b0;
else if(en) begin
    if (rd_req_by_rbsp_buffer_in && {last_byte2,last_byte1,current_byte}
        == NaluStartBytes)
        start_bytes_detect <= 1'b1;
    else if (rd_req_by_rbsp_buffer_in)
        start_bytes_detect <= 1'b0;
    if (start_bytes_detect)
        skip_nalu_head     <= 1;
    else if (rd_req_by_rbsp_buffer_in)
        skip_nalu_head     <= 0;
end
//nalu head

always @(posedge clk)
if (rst) begin
   nalu_head               <= 'b0;
   vps_found               <= 'b0;
end
else if (en && start_bytes_detect)begin
    nalu_head              <= current_byte;
    if (current_byte[6:1] == 32)
        vps_found          <= 1'b1;
end

//从next_start_bytes_detect跳过NaluStartBytes 3/4字节，到start_bytes_detect,
//再跳过2字节nalu head，此期间nalu_valid=0
always @(posedge clk)
if (rst)
   nalu_valid              <= 1'b0;
else if (en) begin
    if(rd_req_by_rbsp_buffer_in && next_start_bytes_detect)//只有read req才会有消耗，静止不动状态不发生变化
       nalu_valid          <= 1'b0;
    else if (rd_req_by_rbsp_buffer_in && skip_nalu_head) //start_bytes_detect下一周期skip_nalu_head,再下一周期nalu_valid置起，跳过2字节的nalu head
       nalu_valid          <= 1'b1;
end

always @(posedge clk)
if (rst||next_nalu_detected_clr) begin
    next_nalu_detected      <= 0;
end else begin
    if(rd_req_by_rbsp_buffer_in && next_start_bytes_detect)
       next_nalu_detected   <= 1'b0;
    else if (rd_req_by_rbsp_buffer_in && skip_nalu_head)
       next_nalu_detected   <= 1'b1;
end

//nalu head struct
assign nal_unit_type = nalu_head[6:1];


reg competition_bytes_detect;

always @(posedge clk)
if (rst)
    competition_bytes_detect <= 1'b0;
else if (en)begin
    if (rd_req_by_rbsp_buffer_in && {last_byte1,current_byte,next_byte1}
        == emulation_prevention_three_byte)
        competition_bytes_detect <= 1'b1;
    else if (rd_req_by_rbsp_buffer_in)
        competition_bytes_detect <= 1'b0;
end

assign rbsp_data_out = current_byte;
assign rbsp_valid_out = nalu_valid && !competition_bytes_detect && vps_found && (
			nal_unit_type == 32 || nal_unit_type == 33 || nal_unit_type == 34 || nal_unit_type == 1|| nal_unit_type == 19);

//mem read
assign mem_rd_req_out = vps_found ? (rd_req_by_rbsp_buffer_in && en):en;

endmodule
