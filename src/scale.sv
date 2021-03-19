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
`include "type_defs.sv"

module scale
(
 input wire                       clk         ,
 input wire                       rst         ,

 input wire        [14:0]         poc_diff1   ,
 input wire        [14:0]         poc_diff2   ,
 input wire signed [14:0]         mv0         ,
 input wire signed [14:0]         mv1         ,

 output reg signed [14:0]         mv0_scaled  ,
 output reg signed [14:0]         mv1_scaled  ,
 output reg                       scale_done  

);

reg         [ 2:0]          stage           ;
reg         [ 7:0]          td              ;
reg         [ 7:0]          tb              ;
reg         [16:0]          tx              ;
reg         [16:0]          tx1             ;
reg         [11:0]          distScaleFactor ;
reg         [18:0]          factor_tmp      ;
reg         [13:0]          abs_mv0         ;
reg         [13:0]          abs_mv1         ;
reg         [17:0]          mv0_tmp         ;
reg         [17:0]          mv1_tmp         ;

wire signed [25:0]          mult1_p         ;
wire signed [26:0]          mult2_p         ;
wire signed [26:0]          mult3_p         ;


(* ram_style = "block" *)
reg  [0:127][16:0]  tx_tab      ;

initial begin
    tx_tab = {
        17'd0, 17'd16384, 17'd8192, 17'd5461, 17'd4096, 17'd3277, 17'd2731, 17'd2341,
        17'd2048, 17'd1820, 17'd1638, 17'd1489, 17'd1365, 17'd1260, 17'd1170, 17'd1092,
        17'd1024, 17'd964, 17'd910, 17'd862, 17'd819, 17'd780, 17'd745, 17'd712,
        17'd683, 17'd655, 17'd630, 17'd607, 17'd585, 17'd565, 17'd546, 17'd529,
        17'd512, 17'd496, 17'd482, 17'd468, 17'd455, 17'd443, 17'd431, 17'd420,
        17'd410, 17'd400, 17'd390, 17'd381, 17'd372, 17'd364, 17'd356, 17'd349,
        17'd341, 17'd334, 17'd328, 17'd321, 17'd315, 17'd309, 17'd303, 17'd298,
        17'd293, 17'd287, 17'd282, 17'd278, 17'd273, 17'd269, 17'd264, 17'd260,
        17'd256, 17'd252, 17'd248, 17'd245, 17'd241, 17'd237, 17'd234, 17'd231,
        17'd228, 17'd224, 17'd221, 17'd218, 17'd216, 17'd213, 17'd210, 17'd207,
        17'd205, 17'd202, 17'd200, 17'd197, 17'd195, 17'd193, 17'd191, 17'd188,
        17'd186, 17'd184, 17'd182, 17'd180, 17'd178, 17'd176, 17'd174, 17'd172,
        17'd171, 17'd169, 17'd167, 17'd165, 17'd164, 17'd162, 17'd161, 17'd159,
        17'd158, 17'd156, 17'd155, 17'd153, 17'd152, 17'd150, 17'd149, 17'd148,
        17'd146, 17'd145, 17'd144, 17'd142, 17'd141, 17'd140, 17'd139, 17'd138,
        17'd137, 17'd135, 17'd134, 17'd133, 17'd132, 17'd131, 17'd130, 17'd129
    };
end
//distScaleFactor = Clip3(-4096, 4095, (tb * tx + 32) >> 6);
//tb*tx+32
multadd #(9, 18, 7, 26) multadd_inst1
(
    .clk    (clk),
    .a      ({1'b0,tb}),
    .b      ({1'b0,tx1}),
    .c      (7'd32),
    .p      (mult1_p)
);

//Clip3(-32768, 32767, Sign(distScaleFactor * mv->mv[0]) * ((abs(distScaleFactor * mv->mv[0]) + 127) >> 8))
//
multadd #(13, 15, 8, 27) multadd_inst2
(
    .clk    (clk),
    .a      ({1'b0,distScaleFactor}),
    .b      ({1'b0,abs_mv0}),
    .c      (8'd127),
    .p      (mult2_p)
);

multadd #(13, 15, 8, 27) multadd_inst3
(
    .clk    (clk),
    .a      ({1'b0,distScaleFactor}),
    .b      ({1'b0,abs_mv1}),
    .c      (8'd127),
    .p      (mult3_p)
);

always @ (posedge clk)
if (rst) begin
    scale_done           <= 0;
    td                   <= poc_diff1>127?127:poc_diff1;
    tb                   <= poc_diff2>127?127:poc_diff2;
    abs_mv0              <= mv0>=0?mv0:(~mv0+1);
    abs_mv1              <= mv1>=0?mv1:(~mv1+1);
    stage                <= 0;
end else if (~scale_done) begin
    stage                <= stage+1;
    if (stage == 0) begin
        tx               <= tx_tab[td];
    end
    if (stage == 1) begin
        tx1              <= tx;
    end

    //distScaleFactor = Clip3(-4096, 4095, (tb*tx+32)>>6);
    //factor_tmp=(tb * tx + 32) >> 6
    if (stage == 3) begin
        factor_tmp       <= mult1_p[24:6];
    end
    if (stage == 4) begin
        distScaleFactor  <= factor_tmp[18:12]?4095:factor_tmp[11:0];
    end

    if (stage == 6) begin
        mv0_tmp          <= mult2_p[25:8];
        mv1_tmp          <= mult3_p[25:8];
    end
    if (stage == 7) begin
        mv0_scaled       <= mv0[14]?(mv0_tmp>16383?-16383:(~mv0_tmp+1)):
                                    (mv0_tmp>16383?16383:mv0_tmp[14:0]);
        mv1_scaled       <= mv1[14]?(mv1_tmp>16383?-16383:(~mv1_tmp+1)):
                                    (mv1_tmp>16383?16383:mv1_tmp[14:0]);
        scale_done       <= 1;
    end

end

endmodule
