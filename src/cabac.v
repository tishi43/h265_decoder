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

module cabac
(
 input wire                      clk,
 input wire                      en,
 input wire                      rst,
 input wire             [ 7: 0]  i_rbsp_in,
 input wire             [ 5: 0]  i_SliceQpY,
 input wire             [ 1: 0]  i_slice_type,
 input wire                      i_cabac_init_present_flag,
 input wire                      i_cabac_init_flag,
 input wire             [ 8: 0]  i_leading9bits,
 input wire                      i_init,
 input wire             [ 4: 0]  i_cm_idx_cu,
 input wire             [ 2: 0]  i_cm_idx_sd,
 input wire             [ 5: 0]  i_cm_idx_xy_pref,
 input wire             [ 5: 0]  i_cm_idx_sig,
 input wire             [ 5: 0]  i_cm_idx_gt1_etc,

 input wire                      i_dec_en_cu,
 input wire                      i_dec_en_sd,
 input wire                      i_dec_en_xy_pref,
 input wire                      i_dec_en_sig,
 input wire                      i_dec_en_gt1_etc,

 input wire                      i_byp_en,
 input wire                      i_term_en,      //terminate_decode_bin
 output wire                     o_init_done,

(*mark_debug="true"*)
 output wire                     o_bin_cu,
(*mark_debug="true"*)
 output wire                     o_bin_sd,
(*mark_debug="true"*)
 output wire                     o_bin_xy_pref,
(*mark_debug="true"*)
 output wire                     o_bin_sig,
(*mark_debug="true"*)
 output wire                     o_bin_gt1_etc,

 output wire                     o_bin_byp,
 output wire                     o_bin_term,
(*mark_debug="true"*)
 output reg                      o_valid, //o_valid只对cabac_decode_bin有用
(*mark_debug="true"*)
 output reg             [ 2: 0]  o_output_len, //wire
(*mark_debug="true"*)
 output reg             [ 8:0]   o_ivlCurrRange_r,
(*mark_debug="true"*)
 output reg             [ 8:0]   o_ivlOffset_r
);

wire init_done_sd;
wire init_done_cu;
wire init_done_xy_pref;
wire init_done_sig;
wire init_done_gt1_etc;

assign o_init_done = init_done_sd && init_done_cu && init_done_xy_pref && init_done_sig && init_done_gt1_etc;

(*mark_debug="true"*)
wire [2:0] len_dec_sd;
(*mark_debug="true"*)
wire [2:0] len_dec_cu;
(*mark_debug="true"*)
wire [2:0] len_dec_xy_pref;
(*mark_debug="true"*)
wire [2:0] len_dec_sig;
(*mark_debug="true"*)
wire [2:0] len_dec_gt1_etc;

wire [8:0] range_dec_o_sd;
wire [8:0] range_dec_o_cu;
wire [8:0] range_dec_o_xy_pref;
wire [8:0] range_dec_o_sig;
wire [8:0] range_dec_o_gt1_etc;

wire [8:0] offset_dec_o_sd;
wire [8:0] offset_dec_o_cu;
wire [8:0] offset_dec_o_xy_pref;
wire [8:0] offset_dec_o_sig;
wire [8:0] offset_dec_o_gt1_etc;


wire [8:0] offset_byp_o;

wire [8:0] range_term_o;
wire [8:0] offset_term_o;
wire       len_term_o;

(* KEEP_HIERARCHY  = "TRUE" *)
dec_bin_sd dec_bin_sd_inst
(
 .clk(clk),
 .rst(rst),

 .i_rbsp_in(i_rbsp_in),
 .i_SliceQpY(i_SliceQpY),
 .i_slice_type(i_slice_type),
 .i_cabac_init_present_flag(i_cabac_init_present_flag),
 .i_cabac_init_flag(i_cabac_init_flag),
 .i_cm_idx(i_cm_idx_sd),

 .i_dec_en(i_dec_en_sd),
 .i_valid(o_valid),
 .i_ivlCurrRange(o_ivlCurrRange_r),
 .i_ivlOffset(o_ivlOffset_r),

 .o_init_done(init_done_sd),
 .o_binVal(o_bin_sd),
 .o_output_len(len_dec_sd),
 .o_ivlCurrRange(range_dec_o_sd),
 .o_ivlOffset(offset_dec_o_sd)
);


dec_bin_cu dec_bin_cu_inst
(
 .clk(clk),
 .rst(rst),
 .i_rbsp_in(i_rbsp_in),
 .i_SliceQpY(i_SliceQpY),
 .i_slice_type(i_slice_type),
 .i_cabac_init_present_flag(i_cabac_init_present_flag),
 .i_cabac_init_flag(i_cabac_init_flag),
 .i_cm_idx(i_cm_idx_cu),

 .i_dec_en(i_dec_en_cu),
 .i_valid(o_valid),
 .i_ivlCurrRange(o_ivlCurrRange_r),
 .i_ivlOffset(o_ivlOffset_r),

 .o_init_done(init_done_cu),
 .o_binVal(o_bin_cu),
 .o_output_len(len_dec_cu),
 .o_ivlCurrRange(range_dec_o_cu),
 .o_ivlOffset(offset_dec_o_cu)
);


dec_bin_xy_pref dec_bin_xy_pref_inst
(
 .clk(clk),
 .rst(rst),
 .i_rbsp_in(i_rbsp_in),
 .i_SliceQpY(i_SliceQpY),
 .i_slice_type(i_slice_type),
 .i_cabac_init_present_flag(i_cabac_init_present_flag),
 .i_cabac_init_flag(i_cabac_init_flag),
 .i_cm_idx(i_cm_idx_xy_pref),

 .i_dec_en(i_dec_en_xy_pref),
 .i_valid(o_valid),
 .i_ivlCurrRange(o_ivlCurrRange_r),
 .i_ivlOffset(o_ivlOffset_r),

 .o_init_done(init_done_xy_pref),
 .o_binVal(o_bin_xy_pref),
 .o_output_len(len_dec_xy_pref),
 .o_ivlCurrRange(range_dec_o_xy_pref),
 .o_ivlOffset(offset_dec_o_xy_pref)
);


dec_bin_sig dec_bin_sig_inst
(
 .clk(clk),
 .rst(rst),
 .i_rbsp_in(i_rbsp_in),
 .i_SliceQpY(i_SliceQpY),
 .i_slice_type(i_slice_type),
 .i_cabac_init_present_flag(i_cabac_init_present_flag),
 .i_cabac_init_flag(i_cabac_init_flag),
 .i_cm_idx(i_cm_idx_sig),

 .i_dec_en(i_dec_en_sig),
 .i_valid(o_valid),
 .i_ivlCurrRange(o_ivlCurrRange_r),
 .i_ivlOffset(o_ivlOffset_r),

 .o_init_done(init_done_sig),
 .o_binVal(o_bin_sig),
 .o_output_len(len_dec_sig),
 .o_ivlCurrRange(range_dec_o_sig),
 .o_ivlOffset(offset_dec_o_sig)
);


dec_bin_gt1_etc dec_bin_gt1_etc_inst
(
 .clk(clk),
 .rst(rst),
 .i_rbsp_in(i_rbsp_in),
 .i_SliceQpY(i_SliceQpY),
 .i_slice_type(i_slice_type),
 .i_cabac_init_present_flag(i_cabac_init_present_flag),
 .i_cabac_init_flag(i_cabac_init_flag),
 .i_cm_idx(i_cm_idx_gt1_etc),

 .i_dec_en(i_dec_en_gt1_etc),
 .i_valid(o_valid),
 .i_ivlCurrRange(o_ivlCurrRange_r),
 .i_ivlOffset(o_ivlOffset_r),

 .o_init_done(init_done_gt1_etc),
 .o_binVal(o_bin_gt1_etc),
 .o_output_len(len_dec_gt1_etc),
 .o_ivlCurrRange(range_dec_o_gt1_etc),
 .o_ivlOffset(offset_dec_o_gt1_etc)
);

cabac_bypass_decode_bin cabac_bypass_decode_bin_inst
(
    .i_ivlCurrRange(o_ivlCurrRange_r),
    .i_ivlOffset(o_ivlOffset_r),
    .i_rbsp_in(i_rbsp_in[7]),

    .o_ivlOffset(offset_byp_o),
    .o_binVal(o_bin_byp)
);


cabac_terminate_decode_bin cabac_terminate_decode_bin_inst
(
    .i_ivlCurrRange(o_ivlCurrRange_r),
    .i_ivlOffset(o_ivlOffset_r),
    .i_rbsp_in(i_rbsp_in[7]),

    .o_ivlCurrRange(range_term_o),
    .o_ivlOffset(offset_term_o),
    .o_binVal(o_bin_term),
    .o_output_len(len_term_o)
);

always @(*)
begin
    if (en == 0)
        o_output_len = 0;
    else if (i_dec_en_sd && o_valid)
        o_output_len = len_dec_sd;
    else if (i_dec_en_cu && o_valid)
        o_output_len = len_dec_cu;
    else if (i_dec_en_xy_pref && o_valid)
        o_output_len = len_dec_xy_pref;
    else if (i_dec_en_sig && o_valid)
        o_output_len = len_dec_sig;
    else if (i_dec_en_gt1_etc && o_valid)
        o_output_len = len_dec_gt1_etc;
    else if (i_term_en)
        o_output_len = len_term_o;
    else if (i_byp_en)
        o_output_len = 1;
    else
        o_output_len = 0;
end



always @(posedge clk)
    if (i_init) begin
        o_ivlCurrRange_r    <= 510               ;
        o_ivlOffset_r       <= i_leading9bits    ;
    end else if (en) begin
        if (i_dec_en_sd && o_valid) begin
            o_ivlCurrRange_r  <= range_dec_o_sd   ;
            o_ivlOffset_r     <= offset_dec_o_sd  ;
        end
        if (i_dec_en_cu && o_valid) begin
            o_ivlCurrRange_r  <= range_dec_o_cu   ;
            o_ivlOffset_r     <= offset_dec_o_cu  ;
        end
        if (i_dec_en_xy_pref && o_valid) begin
            o_ivlCurrRange_r  <= range_dec_o_xy_pref   ;
            o_ivlOffset_r     <= offset_dec_o_xy_pref  ;
        end
        if (i_dec_en_sig && o_valid) begin
            o_ivlCurrRange_r  <= range_dec_o_sig   ;
            o_ivlOffset_r     <= offset_dec_o_sig  ;
        end
        if (i_dec_en_gt1_etc && o_valid) begin
            o_ivlCurrRange_r  <= range_dec_o_gt1_etc   ;
            o_ivlOffset_r     <= offset_dec_o_gt1_etc  ;
        end
        if (i_byp_en) begin
            o_ivlOffset_r     <= offset_byp_o      ;
        end
        if (i_term_en) begin
            o_ivlCurrRange_r  <= range_term_o   ;
            o_ivlOffset_r     <= offset_term_o     ;
        end
    end

reg        stage_dec_bin;

always @(posedge clk)
    if (rst) begin
        stage_dec_bin <= 0;
    end else if (en) begin
        if (i_dec_en_sd||i_dec_en_cu||i_dec_en_xy_pref||i_dec_en_sig||i_dec_en_gt1_etc) begin
            stage_dec_bin <= ~stage_dec_bin;
            if (stage_dec_bin == 0)
                o_valid <= 1;
            else
                o_valid <= 0;
        end else
            o_valid <= 0;
    end



`ifdef RANDOM_INIT
integer  seed;
integer random_val;
initial  begin
    seed                               = $get_initial_random_seed(); 
    random_val                         = $random(seed);
    stage_dec_bin                      = {random_val[1:0],random_val[31:2],random_val[1:0],random_val[31:2]};
    o_ivlCurrRange_r                   = {random_val[2:0],random_val[31:3],random_val[2:0],random_val[31:3]};
    o_ivlOffset_r                      = {random_val[3:0],random_val[31:4],random_val[3:0],random_val[31:4]};
end
`endif

endmodule
