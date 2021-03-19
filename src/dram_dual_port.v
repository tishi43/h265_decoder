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
module dram_dual
(
clk,
en,
we,
dpra,
a,
d,
spo,
dpo,
);
parameter addr_bits = 6;
parameter data_bits = 8;
input     clk;
input     en;
input     we;
input     [addr_bits-1:0]  a;
input     [addr_bits-1:0]  dpra;
input     [data_bits-1:0]  d;
output    [data_bits-1:0]  spo;
output    [data_bits-1:0]  dpo;

wire      clk;
wire      en;
wire      we;
wire      [addr_bits-1:0]  a;
wire      [addr_bits-1:0]  dpra;
wire      [data_bits-1:0]  d;
wire      [data_bits-1:0]  spo;
wire      [data_bits-1:0]  dpo;

(* ram_style = "distributed" *)
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


assign    spo = ram[a];
assign    dpo = ram[dpra];

//write
always @ (posedge clk)
begin
    if (we && en)
        ram[dpra] <= d;
end

endmodule

