//--------------------------------------------------------------------------------------------------
// Design    : bvp
// Author(s) : qiu bin, shi tian qi
// Email     : chat1@126.com, tishi1@126.com
// Copyright (C) 2013-2017 qiu bin, shi tian qi
// All rights reserved
// Phone 15957074161
// QQ:1517642772
//-------------------------------------------------------------------------------------------------

module shift_registers_0 (
    clk,
    clken,
    SI,
    SO
);

parameter WIDTH = 32;
parameter data_bits = 8;
input  clk;
input  clken;
input  SI;
output SO;

wire  clk;
wire  clken;
wire  [data_bits-1:0] SI;
wire  [data_bits-1:0] SO;

reg  [WIDTH-1:0][data_bits-1:0] shreg;

//reg  [data_bits-1:0] shreg[WIDTH-1:0];
//** (vlog-2251) Illegal concatenation of unpacked value.
//** Cannot assign a packed type 'concat' to an unpacked type 'reg[data_bits-1:0] $[WIDTH-1:0]'.

always @(posedge clk)
begin
    if (clken)
        shreg <= {SI,shreg[WIDTH-1:1]};
end



assign    SO = shreg[0];

endmodule