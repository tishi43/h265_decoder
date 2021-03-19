//--------------------------------------------------------------------------------------------------
// Design    : bvp
// Author(s) : qiu bin, shi tian qi
// Email     : chat1@126.com, tishi1@126.com
// Copyright (C) 2013-2017 qiu bin, shi tian qi
// All rights reserved
// Phone 15957074161
// QQ:1517642772
//-------------------------------------------------------------------------------------------------
`timescale 1ns / 1ns // timescale time_unit/time_presicion

module dp_ram_async_read
#(parameter DATA_WIDTH=8, parameter ADDR_WIDTH=6)
(
	input [(DATA_WIDTH-1):0] data,
	input [(ADDR_WIDTH-1):0] rdaddress, wraddress,
	input wren, rdclock, wrclock,
	output reg [DATA_WIDTH-1:0] q,
	input aclr
);
	
	reg [DATA_WIDTH-1:0] ram[2**ADDR_WIDTH-1:0];
	
	always @ (posedge wrclock)
	begin
		// Write
		if (wren)
			ram[wraddress] <= data;
	end
	
	always @ (*) begin
		// Read 
		q <= ram[rdaddress];
	end
	
endmodule

