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

// used for storing intra4x4_pred_mode, ref_idx, mvp etc
// 
module ram_simple_dual
(
clk,
en,
we,
addra,
addrb,
dia,
dob
);

parameter addr_bits = 8;
parameter data_bits = 16;
input     clk;
input     en;
input     we;
input     [addr_bits-1:0]  addra;
input     [addr_bits-1:0]  addrb;
input     [data_bits-1:0]  dia;
output    [data_bits-1:0]  dob;

wire      clk;
wire      en;
wire      we;
wire      [addr_bits-1:0]  addra;
wire      [addr_bits-1:0]  addrb;
wire      [data_bits-1:0]  dia;
reg       [data_bits-1:0]  dob;

(* ram_style = "block" *)
reg       [data_bits-1:0]  ram[0:(1 << addr_bits) -1];


`ifdef RANDOM_INIT
integer  seed;
integer random_val;
integer i;
initial  begin
    seed                               = $get_initial_random_seed(); 
    random_val                         = $random(seed);
    for (i=0;i<(1 << addr_bits);i=i+1)
        ram[i] = random_val;
end
`endif


//read
always @ ( posedge clk )
begin
    if (en)
        dob <= ram[addrb];
end


//write
always @ (posedge clk)
begin
    if (we && en)
        ram[addra] <= dia;
end

endmodule
