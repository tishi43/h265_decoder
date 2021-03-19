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

module trans_quant_32
(
 input wire                       clk                      ,
 input wire                       rst                      ,
 input wire                       global_rst               ,
 input wire                       en                       ,
 input wire  [15:0]               i_slice_num              ,
 input wire  [`max_x_bits-1:0]    i_x0                     ,
 input wire  [`max_y_bits-1:0]    i_y0                     ,
 input wire  [ 5:0]               i_xTu                    ,
 input wire  [ 5:0]               i_yTu                    ,

 input wire  [ 2:0]               i_log2TrafoSize          ,
 input wire  [ 6:0]               i_trafoSize              , //整个ctb无残差，rqt_root_cbf=0时，trafoSize=64
 input wire  [ 1:0]               i_cIdx                   ,
 input wire  [ 5:0]               i_qp                     ,
 input wire                       i_type                   ,
 input wire                       i_cbf                    ,
 input wire                       i_predmode               ,
 input wire  [ 6:0]               i_cu_end_x               ,

 input wire  [4:0]                i_x_lmt                  ,
 input wire  [31:0][5:0]          i_y_lmt                  ,

 output reg  [ 9:0]               bram_coeff_addr          ,
 input wire  [ 7:0]               bram_coeff_dout          ,

 input wire                       i_transform_skip_flag    ,
 input wire                       i_transquant_bypass      ,

 output reg  [63:0]               dram_tq_we               ,
 output reg  [63:0][ 5:0]         dram_tq_addrd            ,
 output reg  [63:0][ 9:0]         dram_tq_did              ,
 output reg        [ 6:0]         o_tq_done_y              ,


 input wire              [31: 0]  fd_log                   ,

 output reg              [ 2: 0]  o_trans_quant_state

);


reg  [ 5:0]               x0                  ;
reg  [ 5:0]               y0                  ;
reg  [ 5:0]               xTu                 ;
reg  [ 5:0]               yTu                 ;
reg  [ 2:0]               log2TrafoSize       ;
reg  [ 6:0]               trafoSize           ;
reg  [ 1:0]               cIdx                ;
reg  [ 5:0]               qp                  ;
reg  [ 3:0]               bdShift             ;
reg  [ 3:0]               qpdiv6_r            ;
reg  [ 6:0]               level_scale_r       ;
reg                       cbf                 ;
reg                       predmode            ;
reg  [ 6:0]               cu_end_x            ;
reg  [ 4:0]               x_lmt               ;
reg  [31:0][5:0]          y_lmt               ;
reg                       transform_skip_flag ;
reg                       type_r              ;

reg  [ 5:0]               y_clr_zero          ;
reg  [ 5:0]               y_clr_zero_end      ;

function [10:0] f_get_qp_div6_level_scale;
 input              [ 5: 0]   qp;
 reg                [ 3: 0]   qpdiv6;
 reg                [ 6: 0]   level_scale;
    begin
         case (qp)
          0: begin qpdiv6=0; level_scale=40; end
          1: begin qpdiv6=0; level_scale=45; end
          2: begin qpdiv6=0; level_scale=51; end
          3: begin qpdiv6=0; level_scale=57; end
          4: begin qpdiv6=0; level_scale=64; end
          5: begin qpdiv6=0; level_scale=72; end
          6: begin qpdiv6=1; level_scale=40; end
          7: begin qpdiv6=1; level_scale=45; end
          8: begin qpdiv6=1; level_scale=51; end
          9: begin qpdiv6=1; level_scale=57; end
         10: begin qpdiv6=1; level_scale=64; end
         11: begin qpdiv6=1; level_scale=72; end
         12: begin qpdiv6=2; level_scale=40; end
         13: begin qpdiv6=2; level_scale=45; end
         14: begin qpdiv6=2; level_scale=51; end
         15: begin qpdiv6=2; level_scale=57; end
         16: begin qpdiv6=2; level_scale=64; end
         17: begin qpdiv6=2; level_scale=72; end
         18: begin qpdiv6=3; level_scale=40; end
         19: begin qpdiv6=3; level_scale=45; end
         20: begin qpdiv6=3; level_scale=51; end
         21: begin qpdiv6=3; level_scale=57; end
         22: begin qpdiv6=3; level_scale=64; end
         23: begin qpdiv6=3; level_scale=72; end
         24: begin qpdiv6=4; level_scale=40; end
         25: begin qpdiv6=4; level_scale=45; end
         26: begin qpdiv6=4; level_scale=51; end
         27: begin qpdiv6=4; level_scale=57; end
         28: begin qpdiv6=4; level_scale=64; end
         29: begin qpdiv6=4; level_scale=72; end
         30: begin qpdiv6=5; level_scale=40; end
         31: begin qpdiv6=5; level_scale=45; end
         32: begin qpdiv6=5; level_scale=51; end
         33: begin qpdiv6=5; level_scale=57; end
         34: begin qpdiv6=5; level_scale=64; end
         35: begin qpdiv6=5; level_scale=72; end
         36: begin qpdiv6=6; level_scale=40; end
         37: begin qpdiv6=6; level_scale=45; end
         38: begin qpdiv6=6; level_scale=51; end
         39: begin qpdiv6=6; level_scale=57; end
         40: begin qpdiv6=6; level_scale=64; end
         41: begin qpdiv6=6; level_scale=72; end
         42: begin qpdiv6=7; level_scale=40; end
         43: begin qpdiv6=7; level_scale=45; end
         44: begin qpdiv6=7; level_scale=51; end
         45: begin qpdiv6=7; level_scale=57; end
         46: begin qpdiv6=7; level_scale=64; end
         47: begin qpdiv6=7; level_scale=72; end
         48: begin qpdiv6=8; level_scale=40; end
         49: begin qpdiv6=8; level_scale=45; end
         50: begin qpdiv6=8; level_scale=51; end
         51: begin qpdiv6=8; level_scale=57; end
         52: begin qpdiv6=8; level_scale=64; end
         default : begin qpdiv6 = 0; level_scale = 0; end
        endcase
        f_get_qp_div6_level_scale = {qpdiv6,level_scale};
    end

endfunction

always @ (posedge clk)
begin
    {qpdiv6_r,level_scale_r}             <= f_get_qp_div6_level_scale(qp);
end

//decode 32x32=1024
reg                               dram_intermediate_we; //32个只用1个

reg  [31:0][ 4:0]                 dram_intermediate_addr;
reg  [31:0][16:0]                 dram_intermediate_din;
wire [31:0][16:0]                 dram_intermediate_dout;


reg  signed [8:0]                 trans_matrix_32[0:31][0:31];
reg  signed [8:0]                 trans_matrix_16[0:15][0:15];
reg  signed [8:0]                 trans_matrix_8[0: 7][0: 7];
reg  signed [8:0]                 trans_matrix_4[0: 3][0: 3];
reg  signed [8:0]                 trans_matrix_type1[0: 3][0: 3];

reg  signed [8:0]                 dequant_iadd;

initial
begin
trans_matrix_32 = '{
                     {9'd64, 9'd90, 9'd90, 9'd90,
                     9'd89, 9'd88, 9'd87, 9'd85,
                     9'd83, 9'd82, 9'd80, 9'd78,
                     9'd75, 9'd73, 9'd70, 9'd67,
                     9'd64, 9'd61, 9'd57, 9'd54,
                     9'd50, 9'd46, 9'd43, 9'd38,
                     9'd36, 9'd31, 9'd25, 9'd22,
                     9'd18, 9'd13, 9'd9, 9'd4},

                     {9'd64, 9'd90, 9'd87, 9'd82,
                     9'd75, 9'd67, 9'd57, 9'd46,
                     9'd36, 9'd22, 9'd9, 9'd508,
                     9'd494, 9'd481, 9'd469, 9'd458,
                     9'd448, 9'd439, 9'd432, 9'd427,
                     9'd423, 9'd422, 9'd422, 9'd424,
                     9'd429, 9'd434, 9'd442, 9'd451,
                     9'd462, 9'd474, 9'd487, 9'd499},

                     {9'd64, 9'd88, 9'd80, 9'd67,
                     9'd50, 9'd31, 9'd9, 9'd499,
                     9'd476, 9'd458, 9'd442, 9'd430,
                     9'd423, 9'd422, 9'd425, 9'd434,
                     9'd448, 9'd466, 9'd487, 9'd508,
                     9'd18, 9'd38, 9'd57, 9'd73,
                     9'd83, 9'd90, 9'd90, 9'd85,
                     9'd75, 9'd61, 9'd43, 9'd22},

                     {9'd64, 9'd85, 9'd70, 9'd46,
                     9'd18, 9'd499, 9'd469, 9'd445,
                     9'd429, 9'd422, 9'd425, 9'd439,
                     9'd462, 9'd490, 9'd9, 9'd38,
                     9'd64, 9'd82, 9'd90, 9'd88,
                     9'd75, 9'd54, 9'd25, 9'd508,
                     9'd476, 9'd451, 9'd432, 9'd422,
                     9'd423, 9'd434, 9'd455, 9'd481},

                     {9'd64, 9'd82, 9'd57, 9'd22,
                     9'd494, 9'd458, 9'd432, 9'd422,
                     9'd429, 9'd451, 9'd487, 9'd13,
                     9'd50, 9'd78, 9'd90, 9'd85,
                     9'd64, 9'd31, 9'd503, 9'd466,
                     9'd437, 9'd422, 9'd425, 9'd445,
                     9'd476, 9'd4, 9'd43, 9'd73,
                     9'd89, 9'd88, 9'd70, 9'd38},

                     {9'd64, 9'd78, 9'd43, 9'd508,
                     9'd462, 9'd430, 9'd422, 9'd439,
                     9'd476, 9'd13, 9'd57, 9'd85,
                     9'd89, 9'd67, 9'd25, 9'd490,
                     9'd448, 9'd424, 9'd425, 9'd451,
                     9'd494, 9'd31, 9'd70, 9'd90,
                     9'd83, 9'd54, 9'd9, 9'd474,
                     9'd437, 9'd422, 9'd432, 9'd466},

                     {9'd64, 9'd73, 9'd25, 9'd481,
                     9'd437, 9'd422, 9'd442, 9'd490,
                     9'd36, 9'd78, 9'd90, 9'd67,
                     9'd18, 9'd474, 9'd432, 9'd422,
                     9'd448, 9'd499, 9'd43, 9'd82,
                     9'd89, 9'd61, 9'd9, 9'd466,
                     9'd429, 9'd424, 9'd455, 9'd508,
                     9'd50, 9'd85, 9'd87, 9'd54},

                     {9'd64, 9'd67, 9'd9, 9'd458,
                     9'd423, 9'd434, 9'd487, 9'd38,
                     9'd83, 9'd85, 9'd43, 9'd490,
                     9'd437, 9'd422, 9'd455, 9'd4,
                     9'd64, 9'd90, 9'd70, 9'd13,
                     9'd462, 9'd424, 9'd432, 9'd481,
                     9'd36, 9'd82, 9'd87, 9'd46,
                     9'd494, 9'd439, 9'd422, 9'd451},

                     {9'd64, 9'd61, 9'd503, 9'd439,
                     9'd423, 9'd466, 9'd25, 9'd82,
                     9'd83, 9'd31, 9'd469, 9'd424,
                     9'd437, 9'd499, 9'd57, 9'd90,
                     9'd64, 9'd508, 9'd442, 9'd422,
                     9'd462, 9'd22, 9'd80, 9'd85,
                     9'd36, 9'd474, 9'd425, 9'd434,
                     9'd494, 9'd54, 9'd90, 9'd67},

                     {9'd64, 9'd54, 9'd487, 9'd427,
                     9'd437, 9'd508, 9'd70, 9'd88,
                     9'd36, 9'd466, 9'd422, 9'd451,
                     9'd18, 9'd82, 9'd80, 9'd13,
                     9'd448, 9'd422, 9'd469, 9'd38,
                     9'd89, 9'd67, 9'd503, 9'd434,
                     9'd429, 9'd490, 9'd57, 9'd90,
                     9'd50, 9'd481, 9'd425, 9'd439},

                     {9'd64, 9'd46, 9'd469, 9'd422,
                     9'd462, 9'd38, 9'd90, 9'd54,
                     9'd476, 9'd422, 9'd455, 9'd31,
                     9'd89, 9'd61, 9'd487, 9'd424,
                     9'd448, 9'd22, 9'd87, 9'd67,
                     9'd494, 9'd427, 9'd442, 9'd13,
                     9'd83, 9'd73, 9'd503, 9'd430,
                     9'd437, 9'd4, 9'd80, 9'd78},

                     {9'd64, 9'd38, 9'd455, 9'd424,
                     9'd494, 9'd73, 9'd80, 9'd508,
                     9'd429, 9'd445, 9'd25, 9'd90,
                     9'd50, 9'd466, 9'd422, 9'd481,
                     9'd64, 9'd85, 9'd9, 9'd434,
                     9'd437, 9'd13, 9'd87, 9'd61,
                     9'd476, 9'd422, 9'd469, 9'd54,
                     9'd89, 9'd22, 9'd442, 9'd430},

                     {9'd64, 9'd31, 9'd442, 9'd434,
                     9'd18, 9'd90, 9'd43, 9'd451,
                     9'd429, 9'd4, 9'd87, 9'd54,
                     9'd462, 9'd424, 9'd503, 9'd82,
                     9'd64, 9'd474, 9'd422, 9'd490,
                     9'd75, 9'd73, 9'd487, 9'd422,
                     9'd476, 9'd67, 9'd80, 9'd499,
                     9'd423, 9'd466, 9'd57, 9'd85},

                     {9'd64, 9'd22, 9'd432, 9'd451,
                     9'd50, 9'd85, 9'd503, 9'd422,
                     9'd476, 9'd73, 9'd70, 9'd474,
                     9'd423, 9'd508, 9'd87, 9'd46,
                     9'd448, 9'd434, 9'd25, 9'd90,
                     9'd18, 9'd430, 9'd455, 9'd54,
                     9'd83, 9'd499, 9'd422, 9'd481,
                     9'd75, 9'd67, 9'd469, 9'd424},

                     {9'd64, 9'd13, 9'd425, 9'd474,
                     9'd75, 9'd61, 9'd455, 9'd434,
                     9'd36, 9'd88, 9'd503, 9'd422,
                     9'd494, 9'd85, 9'd43, 9'd439,
                     9'd448, 9'd54, 9'd80, 9'd481,
                     9'd423, 9'd4, 9'd90, 9'd22,
                     9'd429, 9'd466, 9'd70, 9'd67,
                     9'd462, 9'd430, 9'd25, 9'd90},

                     {9'd64, 9'd4, 9'd422, 9'd499,
                     9'd89, 9'd22, 9'd425, 9'd481,
                     9'd83, 9'd38, 9'd432, 9'd466,
                     9'd75, 9'd54, 9'd442, 9'd451,
                     9'd64, 9'd67, 9'd455, 9'd439,
                     9'd50, 9'd78, 9'd469, 9'd430,
                     9'd36, 9'd85, 9'd487, 9'd424,
                     9'd18, 9'd90, 9'd503, 9'd422},

                     {9'd64, 9'd508, 9'd422, 9'd13,
                     9'd89, 9'd490, 9'd425, 9'd31,
                     9'd83, 9'd474, 9'd432, 9'd46,
                     9'd75, 9'd458, 9'd442, 9'd61,
                     9'd64, 9'd445, 9'd455, 9'd73,
                     9'd50, 9'd434, 9'd469, 9'd82,
                     9'd36, 9'd427, 9'd487, 9'd88,
                     9'd18, 9'd422, 9'd503, 9'd90},

                     {9'd64, 9'd499, 9'd425, 9'd38,
                     9'd75, 9'd451, 9'd455, 9'd78,
                     9'd36, 9'd424, 9'd503, 9'd90,
                     9'd494, 9'd427, 9'd43, 9'd73,
                     9'd448, 9'd458, 9'd80, 9'd31,
                     9'd423, 9'd508, 9'd90, 9'd490,
                     9'd429, 9'd46, 9'd70, 9'd445,
                     9'd462, 9'd82, 9'd25, 9'd422},

                     {9'd64, 9'd490, 9'd432, 9'd61,
                     9'd50, 9'd427, 9'd503, 9'd90,
                     9'd476, 9'd439, 9'd70, 9'd38,
                     9'd423, 9'd4, 9'd87, 9'd466,
                     9'd448, 9'd78, 9'd25, 9'd422,
                     9'd18, 9'd82, 9'd455, 9'd458,
                     9'd83, 9'd13, 9'd422, 9'd31,
                     9'd75, 9'd445, 9'd469, 9'd88},

                     {9'd64, 9'd481, 9'd442, 9'd78,
                     9'd18, 9'd422, 9'd43, 9'd61,
                     9'd429, 9'd508, 9'd87, 9'd458,
                     9'd462, 9'd88, 9'd503, 9'd430,
                     9'd64, 9'd38, 9'd422, 9'd22,
                     9'd75, 9'd439, 9'd487, 9'd90,
                     9'd476, 9'd445, 9'd80, 9'd13,
                     9'd423, 9'd46, 9'd57, 9'd427},

                     {9'd64, 9'd474, 9'd455, 9'd88,
                     9'd494, 9'd439, 9'd80, 9'd4,
                     9'd429, 9'd67, 9'd25, 9'd422,
                     9'd50, 9'd46, 9'd422, 9'd31,
                     9'd64, 9'd427, 9'd9, 9'd78,
                     9'd437, 9'd499, 9'd87, 9'd451,
                     9'd476, 9'd90, 9'd469, 9'd458,
                     9'd89, 9'd490, 9'd442, 9'd82},

                     {9'd64, 9'd466, 9'd469, 9'd90,
                     9'd462, 9'd474, 9'd90, 9'd458,
                     9'd476, 9'd90, 9'd455, 9'd481,
                     9'd89, 9'd451, 9'd487, 9'd88,
                     9'd448, 9'd490, 9'd87, 9'd445,
                     9'd494, 9'd85, 9'd442, 9'd499,
                     9'd83, 9'd439, 9'd503, 9'd82,
                     9'd437, 9'd508, 9'd80, 9'd434},

                     {9'd64, 9'd458, 9'd487, 9'd85,
                     9'd437, 9'd4, 9'd70, 9'd424,
                     9'd36, 9'd46, 9'd422, 9'd61,
                     9'd18, 9'd430, 9'd80, 9'd499,
                     9'd448, 9'd90, 9'd469, 9'd474,
                     9'd89, 9'd445, 9'd503, 9'd78,
                     9'd429, 9'd22, 9'd57, 9'd422,
                     9'd50, 9'd31, 9'd425, 9'd73},

                     {9'd64, 9'd451, 9'd503, 9'd73,
                     9'd423, 9'd46, 9'd25, 9'd430,
                     9'd83, 9'd481, 9'd469, 9'd88,
                     9'd437, 9'd13, 9'd57, 9'd422,
                     9'd64, 9'd4, 9'd442, 9'd90,
                     9'd462, 9'd490, 9'd80, 9'd427,
                     9'd36, 9'd38, 9'd425, 9'd78,
                     9'd494, 9'd458, 9'd90, 9'd445},

                     {9'd64, 9'd445, 9'd9, 9'd54,
                     9'd423, 9'd78, 9'd487, 9'd474,
                     9'd83, 9'd427, 9'd43, 9'd22,
                     9'd437, 9'd90, 9'd455, 9'd508,
                     9'd64, 9'd422, 9'd70, 9'd499,
                     9'd462, 9'd88, 9'd432, 9'd31,
                     9'd36, 9'd430, 9'd87, 9'd466,
                     9'd494, 9'd73, 9'd422, 9'd61},

                     {9'd64, 9'd439, 9'd25, 9'd31,
                     9'd437, 9'd90, 9'd442, 9'd22,
                     9'd36, 9'd434, 9'd90, 9'd445,
                     9'd18, 9'd38, 9'd432, 9'd90,
                     9'd448, 9'd13, 9'd43, 9'd430,
                     9'd89, 9'd451, 9'd9, 9'd46,
                     9'd429, 9'd88, 9'd455, 9'd4,
                     9'd50, 9'd427, 9'd87, 9'd458},

                     {9'd64, 9'd434, 9'd43, 9'd4,
                     9'd462, 9'd82, 9'd422, 9'd73,
                     9'd476, 9'd499, 9'd57, 9'd427,
                     9'd89, 9'd445, 9'd25, 9'd22,
                     9'd448, 9'd88, 9'd425, 9'd61,
                     9'd494, 9'd481, 9'd70, 9'd422,
                     9'd83, 9'd458, 9'd9, 9'd38,
                     9'd437, 9'd90, 9'd432, 9'd46},

                     {9'd64, 9'd430, 9'd57, 9'd490,
                     9'd494, 9'd54, 9'd432, 9'd90,
                     9'd429, 9'd61, 9'd487, 9'd499,
                     9'd50, 9'd434, 9'd90, 9'd427,
                     9'd64, 9'd481, 9'd503, 9'd46,
                     9'd437, 9'd90, 9'd425, 9'd67,
                     9'd476, 9'd508, 9'd43, 9'd439,
                     9'd89, 9'd424, 9'd70, 9'd474},

                     {9'd64, 9'd427, 9'd70, 9'd466,
                     9'd18, 9'd13, 9'd469, 9'd67,
                     9'd429, 9'd90, 9'd425, 9'd73,
                     9'd462, 9'd22, 9'd9, 9'd474,
                     9'd64, 9'd430, 9'd90, 9'd424,
                     9'd75, 9'd458, 9'd25, 9'd4,
                     9'd476, 9'd61, 9'd432, 9'd90,
                     9'd423, 9'd78, 9'd455, 9'd31},

                     {9'd64, 9'd424, 9'd80, 9'd445,
                     9'd50, 9'd481, 9'd9, 9'd13,
                     9'd476, 9'd54, 9'd442, 9'd82,
                     9'd423, 9'd90, 9'd425, 9'd78,
                     9'd448, 9'd46, 9'd487, 9'd4,
                     9'd18, 9'd474, 9'd57, 9'd439,
                     9'd83, 9'd422, 9'd90, 9'd427,
                     9'd75, 9'd451, 9'd43, 9'd490},

                     {9'd64, 9'd422, 9'd87, 9'd430,
                     9'd75, 9'd445, 9'd57, 9'd466,
                     9'd36, 9'd490, 9'd9, 9'd4,
                     9'd494, 9'd31, 9'd469, 9'd54,
                     9'd448, 9'd73, 9'd432, 9'd85,
                     9'd423, 9'd90, 9'd422, 9'd88,
                     9'd429, 9'd78, 9'd442, 9'd61,
                     9'd462, 9'd38, 9'd487, 9'd13},

                     {9'd64, 9'd422, 9'd90, 9'd422,
                     9'd89, 9'd424, 9'd87, 9'd427,
                     9'd83, 9'd430, 9'd80, 9'd434,
                     9'd75, 9'd439, 9'd70, 9'd445,
                     9'd64, 9'd451, 9'd57, 9'd458,
                     9'd50, 9'd466, 9'd43, 9'd474,
                     9'd36, 9'd481, 9'd25, 9'd490,
                     9'd18, 9'd499, 9'd9, 9'd508}

                  };
trans_matrix_16 = '{
                     {9'd64, 9'd90, 9'd89, 9'd87,
                     9'd83, 9'd80, 9'd75, 9'd70,
                     9'd64, 9'd57, 9'd50, 9'd43,
                     9'd36, 9'd25, 9'd18, 9'd9},

                     {9'd64, 9'd87, 9'd75, 9'd57,
                     9'd36, 9'd9, 9'd494, 9'd469,
                     9'd448, 9'd432, 9'd423, 9'd422,
                     9'd429, 9'd442, 9'd462, 9'd487},

                     {9'd64, 9'd80, 9'd50, 9'd9,
                     9'd476, 9'd442, 9'd423, 9'd425,
                     9'd448, 9'd487, 9'd18, 9'd57,
                     9'd83, 9'd90, 9'd75, 9'd43},

                     {9'd64, 9'd70, 9'd18, 9'd469,
                     9'd429, 9'd425, 9'd462, 9'd9,
                     9'd64, 9'd90, 9'd75, 9'd25,
                     9'd476, 9'd432, 9'd423, 9'd455},

                     {9'd64, 9'd57, 9'd494, 9'd432,
                     9'd429, 9'd487, 9'd50, 9'd90,
                     9'd64, 9'd503, 9'd437, 9'd425,
                     9'd476, 9'd43, 9'd89, 9'd70},

                     {9'd64, 9'd43, 9'd462, 9'd422,
                     9'd476, 9'd57, 9'd89, 9'd25,
                     9'd448, 9'd425, 9'd494, 9'd70,
                     9'd83, 9'd9, 9'd437, 9'd432},

                     {9'd64, 9'd25, 9'd437, 9'd442,
                     9'd36, 9'd90, 9'd18, 9'd432,
                     9'd448, 9'd43, 9'd89, 9'd9,
                     9'd429, 9'd455, 9'd50, 9'd87},

                     {9'd64, 9'd9, 9'd423, 9'd487,
                     9'd83, 9'd43, 9'd437, 9'd455,
                     9'd64, 9'd70, 9'd462, 9'd432,
                     9'd36, 9'd87, 9'd494, 9'd422},

                     {9'd64, 9'd503, 9'd423, 9'd25,
                     9'd83, 9'd469, 9'd437, 9'd57,
                     9'd64, 9'd442, 9'd462, 9'd80,
                     9'd36, 9'd425, 9'd494, 9'd90},

                     {9'd64, 9'd487, 9'd437, 9'd70,
                     9'd36, 9'd422, 9'd18, 9'd80,
                     9'd448, 9'd469, 9'd89, 9'd503,
                     9'd429, 9'd57, 9'd50, 9'd425},

                     {9'd64, 9'd469, 9'd462, 9'd90,
                     9'd476, 9'd455, 9'd89, 9'd487,
                     9'd448, 9'd87, 9'd494, 9'd442,
                     9'd83, 9'd503, 9'd437, 9'd80},

                     {9'd64, 9'd455, 9'd494, 9'd80,
                     9'd429, 9'd25, 9'd50, 9'd422,
                     9'd64, 9'd9, 9'd437, 9'd87,
                     9'd476, 9'd469, 9'd89, 9'd442},

                     {9'd64, 9'd442, 9'd18, 9'd43,
                     9'd429, 9'd87, 9'd462, 9'd503,
                     9'd64, 9'd422, 9'd75, 9'd487,
                     9'd476, 9'd80, 9'd423, 9'd57},

                     {9'd64, 9'd432, 9'd50, 9'd503,
                     9'd476, 9'd70, 9'd423, 9'd87,
                     9'd448, 9'd25, 9'd18, 9'd455,
                     9'd83, 9'd422, 9'd75, 9'd469},

                     {9'd64, 9'd425, 9'd75, 9'd455,
                     9'd36, 9'd503, 9'd494, 9'd43,
                     9'd448, 9'd80, 9'd423, 9'd90,
                     9'd429, 9'd70, 9'd462, 9'd25},

                     {9'd64, 9'd422, 9'd89, 9'd425,
                     9'd83, 9'd432, 9'd75, 9'd442,
                     9'd64, 9'd455, 9'd50, 9'd469,
                     9'd36, 9'd487, 9'd18, 9'd503}

                  };
trans_matrix_8 = '{
                     {9'd64, 9'd89, 9'd83, 9'd75,
                     9'd64, 9'd50, 9'd36, 9'd18},

                     {9'd64, 9'd75, 9'd36, 9'd494,
                     9'd448, 9'd423, 9'd429, 9'd462},

                     {9'd64, 9'd50, 9'd476, 9'd423,
                     9'd448, 9'd18, 9'd83, 9'd75},

                     {9'd64, 9'd18, 9'd429, 9'd462,
                     9'd64, 9'd75, 9'd476, 9'd423},

                     {9'd64, 9'd494, 9'd429, 9'd50,
                     9'd64, 9'd437, 9'd476, 9'd89},

                     {9'd64, 9'd462, 9'd476, 9'd89,
                     9'd448, 9'd494, 9'd83, 9'd437},

                     {9'd64, 9'd437, 9'd36, 9'd18,
                     9'd448, 9'd89, 9'd429, 9'd50},

                     {9'd64, 9'd423, 9'd83, 9'd437,
                     9'd64, 9'd462, 9'd36, 9'd494}

                  };
trans_matrix_4 = '{
                     {9'd64, 9'd83, 9'd64, 9'd36},
                     {9'd64, 9'd36, 9'd448, 9'd429},
                     {9'd64, 9'd476, 9'd448, 9'd83},
                     {9'd64, 9'd429, 9'd64, 9'd476}
                  };

trans_matrix_type1 = '{
                     {9'd29, 9'd74, 9'd84, 9'd55},
                     {9'd55, 9'd74, 9'd483, 9'd428},
                     {9'd74, 9'd0, 9'd438, 9'd74},
                     {9'd84, 9'd438, 9'd55, 9'd483}
                  };

end


wire signed       [31:0][16:0]       intermediates_1col;
wire signed       [31:0][16:0]       intermediates_1col_scaled;
reg  signed       [31:0][16:0]       intermediates_1col_r;
reg  signed             [16:0]       intermediate;

reg  signed             [ 8:0]       trans_coeff_level;
wire signed       [31:0][ 8:0]       trans_o;
reg  signed       [31:0][ 8:0]       trans_o_r;

reg  signed             [16:0]       accum_a; //{0,32768}
reg  signed       [31:0][ 8:0]       accum_b;
wire signed       [31:0][23:0]       accum_p;
reg                                  accum_rst;
reg                                  accum_en;


reg  signed             [ 9:0]       res_sample_1px;
reg  signed       [31:0][ 9:0]       res_samples_1row;//wire
reg  signed       [31:0][ 9:0]       res_samples_1row_r;
reg  signed       [31:0][ 9:0]       res_samples_1row_blk32;
reg  signed       [31:0][ 9:0]       res_samples_1row_debug; //wire
reg               [31:0]             res_we_blk32;

wire signed       [12:0]             trans_coeff_level_left_shift4;
assign trans_coeff_level_left_shift4 = trans_coeff_level<<<4;

wire signed       [ 7:0]             level_scale_signed;
assign level_scale_signed = {1'b0,level_scale_r};

(* use_dsp48 = "yes" *) 
reg  signed       [20:0]             mult_o;
always @ (posedge clk)
    mult_o <= trans_coeff_level_left_shift4*level_scale_signed;

reg  signed       [27:0]             mult_tmp;
reg  signed       [22:0]             scale_o;

always @(*)
begin
    case (bdShift)
    5:       scale_o <= mult_tmp >>> 5;
    6:       scale_o <= mult_tmp >>> 6;
    7:       scale_o <= mult_tmp >>> 7;
    8:       scale_o <= mult_tmp >>> 8;
    default: scale_o <= mult_tmp >>> 5;
    endcase
end

reg  signed       [16:0]             scaled_trans_coeff;


reg               [ 5:0]             x;
reg               [ 5:0]             y;
reg               [ 4:0]             x_d1;
reg               [ 4:0]             x_d2;
reg               [ 4:0]             x_d3;
reg               [ 4:0]             x_d4;
reg               [ 4:0]             x_d5;
reg               [ 4:0]             x_d6;
reg               [ 4:0]             x_d7;
reg               [ 4:0]             x_d8;
reg               [ 4:0]             x_d9;
reg               [ 4:0]             x_d10;
reg               [ 4:0]             y_d1;
reg               [ 4:0]             y_d2;
reg               [ 4:0]             y_d3;
reg               [ 4:0]             y_d4;
reg               [ 4:0]             y_d5;
reg               [ 4:0]             y_d6;
reg               [ 4:0]             y_d7;
reg               [ 4:0]             y_d8;
reg               [ 4:0]             y_d9;
reg               [ 4:0]             y_d10;
reg                                  valid;
reg                                  valid_d1;
reg                                  valid_d2;
reg                                  valid_d3;
reg                                  valid_d4;
reg                                  valid_d5;
reg                                  valid_d6;
reg                                  valid_d7;
reg                                  valid_d8;
reg                                  valid_d9;
reg                                  valid_d10;

reg               [ 5:0]             y_lmt_cur_col;
reg               [ 5:0]             y_lmt_cur_col_pls1;

reg               [ 4:0]             xplus1;


reg               [ 5:0]             donecols;   //最大32
reg               [ 5:0]             donecols_d1;
reg               [ 5:0]             donecols_d2;
reg               [ 5:0]             donecols_d3;
reg               [ 5:0]             donecols_d4;
reg               [ 5:0]             donecols_d5;
reg               [ 5:0]             donecols_d6;
reg               [ 5:0]             donecols_d7;
reg               [ 5:0]             donecols_d8;
reg               [ 5:0]             donecols_d9;
reg               [ 5:0]             donecols_d10;

wire              [ 5:0]             tq_done_y_w;
wire              [ 5:0]             tq_done_y_w1;
wire              [ 5:0]             tq_done_y_w2;
assign tq_done_y_w = yTu+y_d5;
assign tq_done_y_w1 = i_yTu+i_trafoSize-1;
assign tq_done_y_w2 = yTu+trafoSize-1;

always @ (posedge clk)
begin
    accum_a <= o_trans_quant_state == `trans_quant_stg0 ?
               scaled_trans_coeff:intermediate;

end


genvar I;

generate
    for (I=0;I<4;I++)
    begin:accum_0_3
        always @ (posedge clk)
        begin
            if (type_r == 1) begin
                if(o_trans_quant_state==`trans_quant_stg0) begin
                    accum_b[I]   <= trans_matrix_type1[I][y_d6];
                end else begin
                    accum_b[I]   <= trans_matrix_type1[I][x_d2];
                end
            end else if (log2TrafoSize == 2) begin
                if(o_trans_quant_state==`trans_quant_stg0) begin
                    accum_b[I]   <= trans_matrix_4[I][y_d6];
                end else begin
                    accum_b[I]   <= trans_matrix_4[I][x_d2];
                end
            end else if (log2TrafoSize == 3) begin
                if(o_trans_quant_state==`trans_quant_stg0) begin
                    accum_b[I]   <= trans_matrix_8[I][y_d6];
                end else begin
                    accum_b[I]   <= trans_matrix_8[I][x_d2];
                end
            end else if (log2TrafoSize == 4) begin
                if(o_trans_quant_state==`trans_quant_stg0) begin
                    accum_b[I]   <= trans_matrix_16[I][y_d6];
                end else begin
                    accum_b[I]   <= trans_matrix_16[I][x_d2];
                end
            end else begin
                if(o_trans_quant_state==`trans_quant_stg0) begin
                    accum_b[I]   <= trans_matrix_32[I][y_d6];
                end else begin
                    accum_b[I]   <= trans_matrix_32[I][x_d2];
                end
            end
        end
    end
endgenerate

generate
    for (I=4;I<8;I++)
    begin:accum_4_7
        always @ (posedge clk)
        begin
            if (log2TrafoSize == 3) begin
                if(o_trans_quant_state==`trans_quant_stg0) begin
                    accum_b[I]   <= trans_matrix_8[I][y_d6];
                end else begin
                    accum_b[I]   <= trans_matrix_8[I][x_d2];
                end
            end else if (log2TrafoSize == 4) begin
                if(o_trans_quant_state==`trans_quant_stg0) begin
                    accum_b[I]   <= trans_matrix_16[I][y_d6];
                end else begin
                    accum_b[I]   <= trans_matrix_16[I][x_d2];
                end
            end else begin
                if(o_trans_quant_state==`trans_quant_stg0) begin
                    accum_b[I]   <= trans_matrix_32[I][y_d6];
                end else begin
                    accum_b[I]   <= trans_matrix_32[I][x_d2];
                end
            end
        end
    end
endgenerate


generate
    for (I=8;I<16;I++)
    begin:accum_8_15
        always @ (posedge clk)
        begin
            if (log2TrafoSize == 4) begin
                if(o_trans_quant_state==`trans_quant_stg0) begin
                    accum_b[I]   <= trans_matrix_16[I][y_d6];
                end else begin
                    accum_b[I]   <= trans_matrix_16[I][x_d2];
                end
            end else begin
                if(o_trans_quant_state==`trans_quant_stg0) begin
                    accum_b[I]   <= trans_matrix_32[I][y_d6];
                end else begin
                    accum_b[I]   <= trans_matrix_32[I][x_d2];
                end
            end
        end
    end
endgenerate


generate
    for (I=16;I<32;I++)
    begin:accum_16_31
        always @ (posedge clk)
        begin
            if(o_trans_quant_state==`trans_quant_stg0) begin
                accum_b[I]   <= trans_matrix_32[I][y_d6];
            end else begin
                accum_b[I]   <= trans_matrix_32[I][x_d2];
            end
        end
    end
endgenerate

always @ (*)
begin
    case (xTu[4:2])
        0:res_samples_1row_debug      <= res_samples_1row_blk32;
        1:res_samples_1row_debug      <= {{4{10'd0}},res_samples_1row_blk32[31:4]};
        2:res_samples_1row_debug      <= {{8{10'd0}},res_samples_1row_blk32[31:8]};
        3:res_samples_1row_debug      <= {{12{10'd0}},res_samples_1row_blk32[31:12]};
        4:res_samples_1row_debug      <= {{16{10'd0}},res_samples_1row_blk32[31:16]};
        5:res_samples_1row_debug      <= {{20{10'd0}},res_samples_1row_blk32[31:20]};
        6:res_samples_1row_debug      <= {{24{10'd0}},res_samples_1row_blk32[31:24]};
        7:res_samples_1row_debug      <= {{28{10'd0}},res_samples_1row_blk32[31:28]};
    endcase
end

always @ (posedge clk)
if (rst || (o_trans_quant_state==`trans_quant_stg0 &&
           donecols_d8 == x_lmt+1)) begin
    donecols_d1              <= 0;
    donecols_d2              <= 0;
    donecols_d3              <= 0;
    donecols_d4              <= 0;
    donecols_d5              <= 0;
    donecols_d6              <= 0;
    donecols_d7              <= 0;
    donecols_d8              <= 0;
    donecols_d9              <= 0;
    valid_d1                 <= 0;
    valid_d2                 <= 0;
    valid_d3                 <= 0;
    valid_d4                 <= 0;
    valid_d5                 <= 0;
    valid_d6                 <= 0;
    valid_d7                 <= 0;
    valid_d8                 <= 0;
    valid_d9                 <= 0;
    valid_d10                <= 0;

    x_d1                     <= 0;
    x_d2                     <= 0;
    x_d3                     <= 0;
    x_d4                     <= 0;
    x_d5                     <= 0;
    x_d6                     <= 0;
    x_d7                     <= 0;
    x_d8                     <= 0;
    x_d9                     <= 0;
    x_d10                    <= 0;

    y_d1                     <= 0;
    y_d2                     <= 0;
    y_d3                     <= 0;
    y_d4                     <= 0;
    y_d5                     <= 0;
    y_d6                     <= 0;
    y_d7                     <= 0;
    y_d8                     <= 0;
    y_d9                     <= 0;
    y_d10                    <= 0;

end else if (en && o_trans_quant_state!=`trans_quant_end) begin
    donecols_d1              <= donecols;
    donecols_d2              <= donecols_d1;
    donecols_d3              <= donecols_d2;
    donecols_d4              <= donecols_d3;
    donecols_d5              <= donecols_d4;
    donecols_d6              <= donecols_d5;
    donecols_d7              <= donecols_d6;
    donecols_d8              <= donecols_d7;
    donecols_d9              <= donecols_d8;
    donecols_d10             <= donecols_d9;

    x_d1                     <= x[4:0];
    x_d2                     <= x_d1;
    x_d3                     <= x_d2;
    x_d4                     <= x_d3;
    x_d5                     <= x_d4;
    x_d6                     <= x_d5;
    x_d7                     <= x_d6;
    x_d8                     <= x_d7;
    x_d9                     <= x_d8;
    x_d10                    <= x_d9;

    y_d1                     <= y[4:0];
    y_d2                     <= y_d1;
    y_d3                     <= y_d2;
    y_d4                     <= y_d3;
    y_d5                     <= y_d4;
    y_d6                     <= y_d5;
    y_d7                     <= y_d6;
    y_d8                     <= y_d7;
    y_d9                     <= y_d8;
    y_d10                    <= y_d9;

    valid_d1                 <= valid;
    valid_d2                 <= valid_d1;
    valid_d3                 <= valid_d2;
    valid_d4                 <= valid_d3;
    valid_d5                 <= valid_d4;
    valid_d6                 <= valid_d5;
    valid_d7                 <= valid_d6;
    valid_d8                 <= valid_d7;
    valid_d9                 <= valid_d8;
    valid_d10                <= valid_d9;

end

always @ (posedge clk)
if (global_rst) begin
    o_tq_done_y              <= 7'b1111111;
    o_trans_quant_state      <= `trans_quant_end;
    dram_tq_we               <= {64{1'b0}};
end else if (rst) begin
    x0                       <= i_x0[5:0];
    y0                       <= i_y0[5:0];
    xTu                      <= i_xTu;
    yTu                      <= i_yTu;
    y_clr_zero               <= i_yTu;
    y_clr_zero_end           <= i_yTu+i_trafoSize-1;
    o_tq_done_y              <= 7'b1111111; //未完成一行，初始化为-1，cu里rec_y<=tq_done_y就不会成立，不会往下rec,省去o_tq_done_y<=i_tq_done_y的麻烦

    log2TrafoSize            <= i_log2TrafoSize;
    trafoSize                <= i_trafoSize;
    cIdx                     <= i_cIdx;
    qp                       <= i_qp;
    type_r                   <= i_type;
    bdShift                  <= 3+i_log2TrafoSize;
    case (i_log2TrafoSize)
        2: dequant_iadd      <= 16;
        3: dequant_iadd      <= 32;
        4: dequant_iadd      <= 64;
        5: dequant_iadd      <= 128;
        default:dequant_iadd <= 0;
    endcase


    donecols                 <= 0;
    valid                    <= 0;

    x                        <= 0;
    y                        <= 0;
    xplus1                   <= 1;
    cbf                      <= i_cbf;
    predmode                 <= i_predmode;
    cu_end_x                 <= i_cu_end_x;
    transform_skip_flag      <= i_transform_skip_flag;
    x_lmt                    <= i_x_lmt;
    y_lmt                    <= i_y_lmt;

    bram_coeff_addr          <= 10'd0;
    y_lmt_cur_col            <= i_y_lmt[0];
    y_lmt_cur_col_pls1       <= i_y_lmt[0]+1;
    accum_rst                <= 1;
    accum_en                 <= 0;

    trans_coeff_level        <= 0;
    scaled_trans_coeff       <= 0;
    intermediate             <= 0;

    res_samples_1row_r       <= {32{10'd0}};
    dram_tq_we               <= {64{1'b0}};

    //解码从左往右解，覆盖右边没关系
    case (i_xTu[4:2])
        0:res_we_blk32       <= {32{1'b1}};
        1:res_we_blk32       <= {{28{1'b1}},4'd0};
        2:res_we_blk32       <= {{24{1'b1}},8'd0};
        3:res_we_blk32       <= {{20{1'b1}},12'd0};
        4:res_we_blk32       <= {{16{1'b1}},16'd0};
        5:res_we_blk32       <= {{12{1'b1}},20'd0};
        6:res_we_blk32       <= {{8{1'b1}},24'd0};
        7:res_we_blk32       <= {{4{1'b1}},28'd0};
    endcase

    if (i_transform_skip_flag||
        i_transquant_bypass||~i_cbf) begin
        o_trans_quant_state  <= `trans_quant_stg2;
    end else begin
        o_trans_quant_state  <= `trans_quant_stg0;
    end

    if (~i_transquant_bypass&&i_cbf&&`log_t&&
        i_slice_num>=`slice_begin && i_slice_num<=`slice_end)
        $fdisplay(fd_log, "transform xTu %0d yTu %0d nTbS %0d slice_num %0d",
                   {i_x0[`max_x_bits-1:6],i_xTu},{i_y0[`max_y_bits-1:6],i_yTu},i_trafoSize,i_slice_num);

end else if (en && o_trans_quant_state == `trans_quant_stg0) begin

    //todo,像素值为0的点也需要量化，否则破坏pipeline，如何优化
    //pipeline stage 1
    bram_coeff_addr                   <= {y[4:0], x[4:0]};
    y                                 <= y+1;
    valid                             <= 1;

    //调试结果，需要多取一无效值，用于reset accum，y=y_lmt+1，所以y需要6bit
    if (y == y_lmt_cur_col_pls1) begin
        y                             <= 0;
        x                             <= xplus1;
        xplus1                        <= xplus1+1;
        y_lmt_cur_col                 <= y_lmt[xplus1];
        y_lmt_cur_col_pls1            <= y_lmt[xplus1]+1;
        if (donecols<=x_lmt)
            donecols                  <= donecols+1;
    end


    //pipeline stage 2
    //coeff还要等一个周期才出来


    //pipeline stage 3
    trans_coeff_level                 <= bram_coeff_dout[7]?~bram_coeff_dout[6:0]+1:{1'b0,bram_coeff_dout};

    //pipeline stage 4 乘和移位放一起

    //Clip3(-32768, 32767, ((TransCoeffLevel[y][x] * m *levelScale[qP % 6] << (qP / 6)) + (1 << (bdShift - 1))) >> bdShift);
    //m=16
    //mult_tmp=(mult_o << qpdiv6_r) + dequant_iadd = (TransCoeffLevel[y][x] * m *levelScale[qP % 6] << (qP / 6)) + (1 << (bdShift - 1))
    //pipeline stage 5

    case(qpdiv6_r)
        0: mult_tmp       <= mult_o+dequant_iadd; //mult_o必大于0
        1: mult_tmp       <= (mult_o<<<1)+dequant_iadd;
        2: mult_tmp       <= (mult_o<<<2)+dequant_iadd;
        3: mult_tmp       <= (mult_o<<<3)+dequant_iadd;
        4: mult_tmp       <= (mult_o<<<4)+dequant_iadd;
        5: mult_tmp       <= (mult_o<<<5)+dequant_iadd;
        6: mult_tmp       <= (mult_o<<<6)+dequant_iadd;
        7: mult_tmp       <= (mult_o<<<7)+dequant_iadd;
        default: mult_tmp <= (mult_o<<<8)+dequant_iadd; //8
    endcase

    //pipeline stage 6
    if (scale_o > 32767)
        scaled_trans_coeff        <= 32767;
    else if (scale_o < -32768)
        scaled_trans_coeff        <= -32768;
    else
        scaled_trans_coeff        <= scale_o;


    if (transform_skip_flag) begin
        //pipeline stage 7
        res_sample_1px                <= (scaled_trans_coeff <<<7)+2048>>>12;

        //pipeline stage 8
        dram_tq_we                    <= {64{1'b0}};
        if (valid_d6&&donecols_d6==donecols_d7) begin
            dram_tq_we[xTu+x_d7]      <= 1'b1;
            dram_tq_addrd[xTu+x_d7]   <= y_d7+yTu;
            dram_tq_did[xTu+x_d7]     <= res_sample_1px;
            if (`log_t&&res_sample_1px&&
                i_slice_num>=`slice_begin && i_slice_num<=`slice_end)
                $fdisplay(fd_log, "dequant [%0d][%0d] %0d",y_d7,x_d7,$signed(res_sample_1px));
        end

        if (donecols_d6!=donecols_d7 &&
            donecols_d6 == x_lmt+1) begin
            if (predmode == `MODE_INTRA||
                xTu+trafoSize==cu_end_x) begin
                o_tq_done_y           <= {1'b0,tq_done_y_w2};
            end
            dram_tq_we                <= 64'd0;
            o_trans_quant_state       <= `trans_quant_delay_1cycle; //o_tq_done_y在`trans_quant_end前必须准备好，参cu.sv mark3
        end


    end else begin
        //pipeline stage 7 开始和trans_matrix系数相乘
        //这个周期scaled_trans_coeff就位
        if (valid_d6) begin
            if (`log_v&&accum_a&&
                x_d7<=x_lmt&&~accum_rst&&
                i_slice_num>=`slice_begin && i_slice_num<=`slice_end)
                $fdisplay(fd_log, "Scale [%0d][%0d] %0d",y_d7,x_d7,accum_a);
        end

        //pipeline stage 8 这个周期accum_a,accum_b就位
        if (valid_d5==1'b1&&valid_d6==1'b0) begin
            accum_en                  <= 1;
            accum_rst                 <= 0;
        end
        else if (donecols_d5!=donecols_d6) begin
            accum_rst                 <= 1;
        end

        //pipeline stage 9 saturate,这个周期乘法出结果,一列未完成，也需要
        else if (donecols_d6!=donecols_d7) begin  //连续来2列全零，连续2个reset,不能清0
            accum_rst                 <= 0;
        end

        if (donecols_d6!=donecols_d7)
            intermediates_1col_r      <= intermediates_1col_scaled;

        //pipeline stage 10 存
        if (donecols_d7!=donecols_d8) begin
            dram_intermediate_we      <= 1'b1;
            dram_intermediate_addr    <= {32{x_d8}};
            dram_intermediate_din     <= intermediates_1col_r;
            if (`log_t&&
                i_slice_num>=`slice_begin && i_slice_num<=`slice_end) begin
                if (log2TrafoSize==5)
                    $fdisplay(fd_log, "intermediate col %0d: %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d",x_d8,
                        $signed(intermediates_1col_r[0]),$signed(intermediates_1col_r[1]),
                        $signed(intermediates_1col_r[2]),$signed(intermediates_1col_r[3]),
                        $signed(intermediates_1col_r[4]),$signed(intermediates_1col_r[5]),
                        $signed(intermediates_1col_r[6]),$signed(intermediates_1col_r[7]),
                        $signed(intermediates_1col_r[8]),$signed(intermediates_1col_r[9]),
                        $signed(intermediates_1col_r[10]),$signed(intermediates_1col_r[11]),
                        $signed(intermediates_1col_r[12]),$signed(intermediates_1col_r[13]),
                        $signed(intermediates_1col_r[14]),$signed(intermediates_1col_r[15]),
                        $signed(intermediates_1col_r[16]),$signed(intermediates_1col_r[17]),
                        $signed(intermediates_1col_r[18]),$signed(intermediates_1col_r[19]),
                        $signed(intermediates_1col_r[20]),$signed(intermediates_1col_r[21]),
                        $signed(intermediates_1col_r[22]),$signed(intermediates_1col_r[23]),
                        $signed(intermediates_1col_r[24]),$signed(intermediates_1col_r[25]),
                        $signed(intermediates_1col_r[26]),$signed(intermediates_1col_r[27]),
                        $signed(intermediates_1col_r[28]),$signed(intermediates_1col_r[29]),
                        $signed(intermediates_1col_r[30]),$signed(intermediates_1col_r[31]));
                else if (log2TrafoSize==4)
                    $fdisplay(fd_log, "intermediate col %0d: %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d",x_d8,
                        $signed(intermediates_1col_r[0]),$signed(intermediates_1col_r[1]),
                        $signed(intermediates_1col_r[2]),$signed(intermediates_1col_r[3]),
                        $signed(intermediates_1col_r[4]),$signed(intermediates_1col_r[5]),
                        $signed(intermediates_1col_r[6]),$signed(intermediates_1col_r[7]),
                        $signed(intermediates_1col_r[8]),$signed(intermediates_1col_r[9]),
                        $signed(intermediates_1col_r[10]),$signed(intermediates_1col_r[11]),
                        $signed(intermediates_1col_r[12]),$signed(intermediates_1col_r[13]),
                        $signed(intermediates_1col_r[14]),$signed(intermediates_1col_r[15]));
                else if (log2TrafoSize==3)
                    $fdisplay(fd_log, "intermediate col %0d: %0d %0d %0d %0d %0d %0d %0d %0d",x_d8,
                        $signed(intermediates_1col_r[0]),$signed(intermediates_1col_r[1]),
                        $signed(intermediates_1col_r[2]),$signed(intermediates_1col_r[3]),
                        $signed(intermediates_1col_r[4]),$signed(intermediates_1col_r[5]),
                        $signed(intermediates_1col_r[6]),$signed(intermediates_1col_r[7]));
                else
                    $fdisplay(fd_log, "intermediate col %0d: %0d %0d %0d %0d",x_d8,
                        $signed(intermediates_1col_r[0]),$signed(intermediates_1col_r[1]),
                        $signed(intermediates_1col_r[2]),$signed(intermediates_1col_r[3]));

            end

        end else begin
            dram_intermediate_we      <= 1'b0;
        end

        if (donecols_d8 == x_lmt+1) begin
            o_trans_quant_state   <= `trans_quant_stg1;
            x                     <= 0;
            y                     <= 0;
            accum_en              <= 0;
            accum_rst             <= 1;
            dram_intermediate_we  <= 1'b0;
        end

    end


end else if (en && o_trans_quant_state == `trans_quant_stg1) begin

    //pipeline stage 1
    dram_intermediate_addr            <= {32{x[4:0]}};
    dram_intermediate_we              <= 1'b0;
    x                                 <= x+1;
    valid                             <= 1;
    //同样多取一无效值，此周期用于reset accum,todo优化，x_lmt=1，直接用乘法而不用乘累加，省掉reset
    if (x==x_lmt+1) begin
        y                             <= y+1;
        x                             <= 0;
    end

    //pipeline stage 2
    intermediate                      <= dram_intermediate_dout[y_d1]; //为了不至于乘法输入太复杂，这里缓存一下

    //pipeline stage 3 这个周期intermediate就位

    //pipeline stage 4 这个周期accum_a,accum_b就位

    if (valid_d2==1'b1&&valid_d3==1'b0) begin
        accum_en                      <= 1;
        accum_rst                     <= 0;
    end
    if (valid_d3&&x_d3==x_lmt) begin
        accum_rst                     <= 1;
    end
    //pipeline stage 5 这个周期乘法出结果
    if (valid_d4&&x_d4==x_lmt) begin
        accum_rst                     <= 0;
        res_samples_1row_r            <= res_samples_1row;
    end

    //pipeline stage 6
    case (xTu[4:2])
        0:res_samples_1row_blk32      <= res_samples_1row_r;
        1:res_samples_1row_blk32      <= {res_samples_1row_r[27:0],{4{10'd0}}};
        2:res_samples_1row_blk32      <= {res_samples_1row_r[23:0],{8{10'd0}}};
        3:res_samples_1row_blk32      <= {res_samples_1row_r[19:0],{12{10'd0}}};
        4:res_samples_1row_blk32      <= {res_samples_1row_r[15:0],{16{10'd0}}};
        5:res_samples_1row_blk32      <= {res_samples_1row_r[11:0],{20{10'd0}}};
        6:res_samples_1row_blk32      <= {res_samples_1row_r[ 7:0],{24{10'd0}}};
        7:res_samples_1row_blk32      <= {res_samples_1row_r[ 3:0],{28{10'd0}}};
    endcase


    //pipeline stage 7
    if (valid_d6) begin
        dram_tq_we                    <= xTu[5]?{res_we_blk32,32'd0}:{32'd0,res_we_blk32};
        dram_tq_addrd                 <= {64{tq_done_y_w}};
        dram_tq_did                   <= xTu[5]?{res_samples_1row_blk32,{32{10'd0}}}:
                                                {{32{10'd0}},res_samples_1row_blk32};

        if (`log_t&& x_d6==x_lmt&&
            i_slice_num>=`slice_begin && i_slice_num<=`slice_end) begin
            if (log2TrafoSize==5) begin
                $fdisplay(fd_log, "r %0d: %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d",
                    tq_done_y_w,
                    $signed(res_samples_1row_debug[0]),$signed(res_samples_1row_debug[1]),
                    $signed(res_samples_1row_debug[2]),$signed(res_samples_1row_debug[3]),
                    $signed(res_samples_1row_debug[4]),$signed(res_samples_1row_debug[5]),
                    $signed(res_samples_1row_debug[6]),$signed(res_samples_1row_debug[7]),
                    $signed(res_samples_1row_debug[8]),$signed(res_samples_1row_debug[9]),
                    $signed(res_samples_1row_debug[10]),$signed(res_samples_1row_debug[11]),
                    $signed(res_samples_1row_debug[12]),$signed(res_samples_1row_debug[13]),
                    $signed(res_samples_1row_debug[14]),$signed(res_samples_1row_debug[15]),
                    $signed(res_samples_1row_debug[16]),$signed(res_samples_1row_debug[17]),
                    $signed(res_samples_1row_debug[18]),$signed(res_samples_1row_debug[19]),
                    $signed(res_samples_1row_debug[20]),$signed(res_samples_1row_debug[21]),
                    $signed(res_samples_1row_debug[22]),$signed(res_samples_1row_debug[23]),
                    $signed(res_samples_1row_debug[24]),$signed(res_samples_1row_debug[25]),
                    $signed(res_samples_1row_debug[26]),$signed(res_samples_1row_debug[27]),
                    $signed(res_samples_1row_debug[28]),$signed(res_samples_1row_debug[29]),
                    $signed(res_samples_1row_debug[30]),$signed(res_samples_1row_debug[31]));
            end else if (log2TrafoSize==4) begin
                $fdisplay(fd_log, "r %0d: %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d",
                    tq_done_y_w,
                    $signed(res_samples_1row_debug[0]),$signed(res_samples_1row_debug[1]),
                    $signed(res_samples_1row_debug[2]),$signed(res_samples_1row_debug[3]),
                    $signed(res_samples_1row_debug[4]),$signed(res_samples_1row_debug[5]),
                    $signed(res_samples_1row_debug[6]),$signed(res_samples_1row_debug[7]),
                    $signed(res_samples_1row_debug[8]),$signed(res_samples_1row_debug[9]),
                    $signed(res_samples_1row_debug[10]),$signed(res_samples_1row_debug[11]),
                    $signed(res_samples_1row_debug[12]),$signed(res_samples_1row_debug[13]),
                    $signed(res_samples_1row_debug[14]),$signed(res_samples_1row_debug[15]));
            end else if (log2TrafoSize==3) begin
                $fdisplay(fd_log, "r %0d: %0d %0d %0d %0d %0d %0d %0d %0d",
                    tq_done_y_w,
                    $signed(res_samples_1row_debug[0]),$signed(res_samples_1row_debug[1]),
                    $signed(res_samples_1row_debug[2]),$signed(res_samples_1row_debug[3]),
                    $signed(res_samples_1row_debug[4]),$signed(res_samples_1row_debug[5]),
                    $signed(res_samples_1row_debug[6]),$signed(res_samples_1row_debug[7]));
            end else begin
                $fdisplay(fd_log, "r %0d: %0d %0d %0d %0d",
                    tq_done_y_w,
                    $signed(res_samples_1row_debug[0]),$signed(res_samples_1row_debug[1]),
                    $signed(res_samples_1row_debug[2]),$signed(res_samples_1row_debug[3]));
            end
        end


        //dram_tq_did到pipeline stage 8才生效，到stage 9才真正写入dram
        //tq_done_y同样需要在stage 8赋值，stage 9生效
        //tq_done_y在cu缓存了一个寄存器，这步可以拿到stage 7
        if (x_d6==x_lmt) begin
            if (predmode == `MODE_INTRA||
                xTu+trafoSize==cu_end_x) begin
                o_tq_done_y           <= {1'b0,tq_done_y_w};
            end
        end
    end else begin
        dram_tq_we                    <= 64'd0;
    end

    //pipeline stage 8
    if (y_d7 == trafoSize-1 && valid_d7&&x_d7 == x_lmt) begin
        dram_tq_we                    <= 64'd0;
        o_trans_quant_state           <= `trans_quant_end;
    end


end else if (o_trans_quant_state==`trans_quant_stg2)begin

    dram_tq_we                        <= xTu[5]?{res_we_blk32,32'd0}:{32'hffffffff,res_we_blk32};
    dram_tq_addrd                     <= {64{y_clr_zero}};
    dram_tq_did                       <= {64{10'd0}};
    y_clr_zero                        <= y_clr_zero+1;
    if (y_clr_zero==y_clr_zero_end) begin
        if (~transform_skip_flag)
            o_trans_quant_state       <= `trans_quant_delay_1cycle; //delay 1cycle,让cu接收tq_done_y
        else
            o_trans_quant_state       <= `trans_quant_stg0;
    end
    if ((predmode == `MODE_INTRA||
        xTu+trafoSize==cu_end_x)&&
        ~transform_skip_flag) begin
        o_tq_done_y                   <= {1'b0,y_clr_zero};
    end

end else if (o_trans_quant_state==`trans_quant_delay_1cycle) begin
    o_trans_quant_state               <= `trans_quant_end;
end

genvar i;
generate
    for (i=0;i<32;i++)
    begin: intermediates_label
        assign intermediates_1col[i] = accum_p[i] + 64 >> 7;
    end
endgenerate

generate
    for (i=0;i<32;i++)
    begin: intermediates_scale_label
        assign intermediates_1col_scaled[i] = ~intermediates_1col[i][16]&&intermediates_1col[i][15]?32767:
                                               (intermediates_1col[i][16]&&~intermediates_1col[i][15]?-32768:intermediates_1col[i]);
    end
endgenerate

generate
    for (i=0;i<32;i++)
    begin: res_samples_label
        always @(accum_p[i])
        begin
            res_samples_1row[i]  = accum_p[i]+2048>>12;
        end
    end
endgenerate


generate
    for (i=0;i<32;i++)
    begin: accum_label
        multacc #(17, 9, 24) accum_idct
        (
            .clk(clk),
            .rst(accum_rst),
            .en(accum_en),
            .a( accum_a),
            .b(accum_b[i]),
            .p(accum_p[i])
        );
    end
endgenerate

generate
    for (i=0;i<32;i++)
    begin: dram_label
        dram #(5, 17) dram_intermediate
        (
            .clk(clk),
            .en(en),
            .we(dram_intermediate_we),
            .addr(dram_intermediate_addr[i]),
            .data_in(dram_intermediate_din[i]),
            .data_out(dram_intermediate_dout[i])
        );
    end
endgenerate


`ifdef RANDOM_INIT
integer  seed;
integer random_val;
initial  begin
    seed                               = $get_initial_random_seed(); 
    random_val                         = $random(seed);
    bram_coeff_addr                    = {random_val,random_val};
    dram_tq_we                         = {random_val[1:0],random_val[31:2],random_val[1:0],random_val[31:2]};
    dram_tq_addrd                      = {random_val[2:0],random_val[31:3],random_val[2:0],random_val[31:3]};
    dram_tq_did                        = {random_val[3:0],random_val[31:4],random_val[3:0],random_val[31:4]};
    o_tq_done_y                        = {random_val[4:0],random_val[31:5],random_val[4:0],random_val[31:5]};
    o_trans_quant_state                = {random_val[5:0],random_val[31:6],random_val[5:0],random_val[31:6]};
    x0                                 = {random_val[6:0],random_val[31:7],random_val[6:0],random_val[31:7]};
    y0                                 = {random_val[7:0],random_val[31:8],random_val[7:0],random_val[31:8]};
    xTu                                = {random_val[8:0],random_val[31:9],random_val[8:0],random_val[31:9]};
    yTu                                = {random_val[9:0],random_val[31:10],random_val[9:0],random_val[31:10]};
    log2TrafoSize                      = {random_val[10:0],random_val[31:11],random_val[10:0],random_val[31:11]};
    trafoSize                          = {random_val[11:0],random_val[31:12],random_val[11:0],random_val[31:12]};
    cIdx                               = {random_val[12:0],random_val[31:13],random_val[12:0],random_val[31:13]};
    qp                                 = {random_val[13:0],random_val[31:14],random_val[13:0],random_val[31:14]};
    bdShift                            = {random_val[14:0],random_val[31:15],random_val[14:0],random_val[31:15]};
    qpdiv6_r                           = {random_val[15:0],random_val[31:16],random_val[15:0],random_val[31:16]};
    level_scale_r                      = {random_val[16:0],random_val[31:17],random_val[16:0],random_val[31:17]};
    cbf                                = {random_val[17:0],random_val[31:18],random_val[17:0],random_val[31:18]};
    predmode                           = {random_val[18:0],random_val[31:19],random_val[18:0],random_val[31:19]};
    cu_end_x                           = {random_val[19:0],random_val[31:20],random_val[19:0],random_val[31:20]};
    x_lmt                              = {random_val[20:0],random_val[31:21],random_val[20:0],random_val[31:21]};
    y_lmt                              = {random_val[21:0],random_val[31:22],random_val[21:0],random_val[31:22]};
    transform_skip_flag                = {random_val[22:0],random_val[31:23],random_val[22:0],random_val[31:23]};
    type_r                             = {random_val[23:0],random_val[31:24],random_val[23:0],random_val[31:24]};
    y_clr_zero                         = {random_val[24:0],random_val[31:25],random_val[24:0],random_val[31:25]};
    y_clr_zero_end                     = {random_val[25:0],random_val[31:26],random_val[25:0],random_val[31:26]};
    dram_intermediate_we               = {random_val[26:0],random_val[31:27],random_val[26:0],random_val[31:27]};
    dram_intermediate_addr             = {random_val[27:0],random_val[31:28],random_val[27:0],random_val[31:28]};
    dram_intermediate_din              = {random_val[28:0],random_val[31:29],random_val[28:0],random_val[31:29]};
    dequant_iadd                       = {random_val[2:0],random_val[31:3],random_val[2:0],random_val[31:3]};
    intermediates_1col_r               = {random_val[3:0],random_val[31:4],random_val[3:0],random_val[31:4]};
    intermediate                       = {random_val[4:0],random_val[31:5],random_val[4:0],random_val[31:5]};
    trans_coeff_level                  = {random_val[5:0],random_val[31:6],random_val[5:0],random_val[31:6]};
    trans_o_r                          = {random_val[6:0],random_val[31:7],random_val[6:0],random_val[31:7]};
    accum_a                            = {random_val[7:0],random_val[31:8],random_val[7:0],random_val[31:8]};
    accum_b                            = {random_val[8:0],random_val[31:9],random_val[8:0],random_val[31:9]};
    accum_rst                          = {random_val[9:0],random_val[31:10],random_val[9:0],random_val[31:10]};
    accum_en                           = {random_val[10:0],random_val[31:11],random_val[10:0],random_val[31:11]};
    res_sample_1px                     = {random_val[11:0],random_val[31:12],random_val[11:0],random_val[31:12]};
    res_sample_1px                     = {random_val[12:0],random_val[31:13],random_val[12:0],random_val[31:13]};
    res_samples_1row_r                 = {random_val[13:0],random_val[31:14],random_val[13:0],random_val[31:14]};
    res_samples_1row_blk32             = {random_val[14:0],random_val[31:15],random_val[14:0],random_val[31:15]};
    res_samples_1row_debug             = {random_val[15:0],random_val[31:16],random_val[15:0],random_val[31:16]};
    res_we_blk32                       = {random_val[16:0],random_val[31:17],random_val[16:0],random_val[31:17]};
    mult_o                             = {random_val[17:0],random_val[31:18],random_val[17:0],random_val[31:18]};
    mult_tmp                           = {random_val[18:0],random_val[31:19],random_val[18:0],random_val[31:19]};
    scale_o                            = {random_val[19:0],random_val[31:20],random_val[19:0],random_val[31:20]};
    scaled_trans_coeff                 = {random_val[20:0],random_val[31:21],random_val[20:0],random_val[31:21]};
    x                                  = {random_val[21:0],random_val[31:22],random_val[21:0],random_val[31:22]};
    y                                  = {random_val[22:0],random_val[31:23],random_val[22:0],random_val[31:23]};
    x_d1                               = {random_val[23:0],random_val[31:24],random_val[23:0],random_val[31:24]};
    x_d2                               = {random_val[24:0],random_val[31:25],random_val[24:0],random_val[31:25]};
    x_d3                               = {random_val[25:0],random_val[31:26],random_val[25:0],random_val[31:26]};
    x_d4                               = {random_val[26:0],random_val[31:27],random_val[26:0],random_val[31:27]};
    x_d5                               = {random_val[27:0],random_val[31:28],random_val[27:0],random_val[31:28]};
    x_d6                               = {random_val[28:0],random_val[31:29],random_val[28:0],random_val[31:29]};
    x_d7                               = {random_val[29:0],random_val[31:30],random_val[29:0],random_val[31:30]};
    x_d8                               = {random_val[30:0],random_val[31],random_val[30:0],random_val[31]};
    x_d9                               = {random_val[31:0],random_val[31:0]};
    x_d10                              = {random_val,random_val};
    y_d1                               = {random_val[1:0],random_val[31:2],random_val[1:0],random_val[31:2]};
    y_d2                               = {random_val[2:0],random_val[31:3],random_val[2:0],random_val[31:3]};
    y_d3                               = {random_val[3:0],random_val[31:4],random_val[3:0],random_val[31:4]};
    y_d4                               = {random_val[4:0],random_val[31:5],random_val[4:0],random_val[31:5]};
    y_d5                               = {random_val[5:0],random_val[31:6],random_val[5:0],random_val[31:6]};
    y_d6                               = {random_val[6:0],random_val[31:7],random_val[6:0],random_val[31:7]};
    y_d7                               = {random_val[7:0],random_val[31:8],random_val[7:0],random_val[31:8]};
    y_d8                               = {random_val[8:0],random_val[31:9],random_val[8:0],random_val[31:9]};
    y_d9                               = {random_val[9:0],random_val[31:10],random_val[9:0],random_val[31:10]};
    y_d10                              = {random_val[10:0],random_val[31:11],random_val[10:0],random_val[31:11]};
    valid                              = {random_val[11:0],random_val[31:12],random_val[11:0],random_val[31:12]};
    valid_d1                           = {random_val[12:0],random_val[31:13],random_val[12:0],random_val[31:13]};
    valid_d2                           = {random_val[13:0],random_val[31:14],random_val[13:0],random_val[31:14]};
    valid_d3                           = {random_val[14:0],random_val[31:15],random_val[14:0],random_val[31:15]};
    valid_d4                           = {random_val[15:0],random_val[31:16],random_val[15:0],random_val[31:16]};
    valid_d5                           = {random_val[16:0],random_val[31:17],random_val[16:0],random_val[31:17]};
    valid_d6                           = {random_val[17:0],random_val[31:18],random_val[17:0],random_val[31:18]};
    valid_d7                           = {random_val[18:0],random_val[31:19],random_val[18:0],random_val[31:19]};
    valid_d8                           = {random_val[19:0],random_val[31:20],random_val[19:0],random_val[31:20]};
    valid_d9                           = {random_val[20:0],random_val[31:21],random_val[20:0],random_val[31:21]};
    valid_d10                          = {random_val[21:0],random_val[31:22],random_val[21:0],random_val[31:22]};
    y_lmt_cur_col                      = {random_val[22:0],random_val[31:23],random_val[22:0],random_val[31:23]};
    y_lmt_cur_col_pls1                 = {random_val[23:0],random_val[31:24],random_val[23:0],random_val[31:24]};
    xplus1                             = {random_val[24:0],random_val[31:25],random_val[24:0],random_val[31:25]};
    donecols                           = {random_val[25:0],random_val[31:26],random_val[25:0],random_val[31:26]};
    donecols_d1                        = {random_val[26:0],random_val[31:27],random_val[26:0],random_val[31:27]};
    donecols_d2                        = {random_val[27:0],random_val[31:28],random_val[27:0],random_val[31:28]};
    donecols_d3                        = {random_val[28:0],random_val[31:29],random_val[28:0],random_val[31:29]};
    donecols_d4                        = {random_val[29:0],random_val[31:30],random_val[29:0],random_val[31:30]};
    donecols_d5                        = {random_val[30:0],random_val[31],random_val[30:0],random_val[31]};
    donecols_d6                        = {random_val[31:0],random_val[31:0]};
    donecols_d7                        = {random_val,random_val};
    donecols_d8                        = {random_val[1:0],random_val[31:2],random_val[1:0],random_val[31:2]};
    donecols_d9                        = {random_val[2:0],random_val[31:3],random_val[2:0],random_val[31:3]};
    donecols_d10                       = {random_val[3:0],random_val[31:4],random_val[3:0],random_val[31:4]};
end
`endif

endmodule
