//--------------------------------------------------------------------------------------------------
// Design    : bvp
// Author(s) : qiu bin, shi tian qi
// Email     : chat1@126.com, tishi1@126.com
// Copyright (C) 2013-2017 qiu bin, shi tian qi
// All rights reserved
// Phone 15957074161
// QQ:1517642772
//-------------------------------------------------------------------------------------------------
module dp_fifo
(
	aclr,

	clk,
	wr,
	wr_data,
	wr_full,
		
	rd,
	rd_data,
	words_avail,
	rd_empty
);
parameter data_bits = 64;
parameter addr_bits = 10;
input  wire aclr;
input  wire clk;
input  wire wr;
input  [data_bits-1:0] wr_data;

(*mark_debug="true"*)
output reg wr_full;

input  wire rd;
output wire [data_bits-1:0] rd_data;
output wire [addr_bits-1:0] words_avail;
(*mark_debug="true"*)
output reg rd_empty;

(*mark_debug="true"*)
reg [data_bits-1:0] rd_data;

(*mark_debug="true"*)
reg [addr_bits-1:0] wr_addr;
(* ram_style = "block" *)
reg [data_bits-1:0] mem[0: (1 << addr_bits) - 1];

(*mark_debug="true"*)
reg [addr_bits-1:0] rd_addr;

assign words_avail = rd_addr <= wr_addr ? wr_addr - rd_addr : wr_addr + (1 << addr_bits) - rd_addr;

always @(posedge clk)
if (aclr) 
	wr_addr <= 0;
else if (wr) begin
	wr_addr <= wr_addr + 1;
	mem[wr_addr] <= wr_data;
end

always @(posedge clk)
if(~rd && wr && words_avail == (1 << addr_bits) - 2)
	wr_full <= 1;
else if (rd && ~wr)
	wr_full <= 0;
else
	wr_full <= words_avail == (1 << addr_bits) - 1;


always @(posedge clk or posedge aclr)
if (aclr) begin
	rd_data <= 0;
	rd_addr <= 0;
end
else if (rd) begin
	rd_addr <= rd_addr + 1'b1;
	rd_data <= mem[rd_addr];
end


always @(posedge clk)
if(rd && ~wr && words_avail == 1)
	rd_empty <= 1;
else if (~rd && wr)
	rd_empty <= 0;
else
	rd_empty <= words_avail == 0;


//synopsys translate_off
always @(posedge clk)
	if (wr && (wr_addr == rd_addr - 1))begin
	$display("%t : %m, write while fifo is full", $time);
	$stop();
end

always @(posedge clk)
if (rd && wr_addr == rd_addr) begin
	$display("%t : %m, read while fifo is empty", $time);
	$stop();
end
//synopsys translate_on

endmodule
