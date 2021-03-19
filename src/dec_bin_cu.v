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

`define CM_COUNT 31

module dec_bin_cu
(
 input wire                      clk,
 input wire                      rst,
 input wire             [ 7: 0]  i_rbsp_in,
 input wire             [ 5: 0]  i_SliceQpY,
 input wire             [ 1: 0]  i_slice_type,
 input wire                      i_cabac_init_present_flag,
 input wire                      i_cabac_init_flag,
 input wire             [ 4: 0]  i_cm_idx,

 input wire                      i_dec_en,       //cabac_decode_bin
 input wire                      i_valid,
 input wire             [ 8:0]   i_ivlCurrRange,
 input wire             [ 8:0]   i_ivlOffset,

 output reg                      o_init_done,
 output wire                     o_binVal,

 output wire            [ 2: 0]  o_output_len,

 output wire            [ 8:0]   o_ivlCurrRange,
 output wire            [ 8:0]   o_ivlOffset
);

reg   [4:0] init_cm_idx;
reg   [4:0] init_cm_idx_minus1;

//pStateIdx 6bit+valMps 1bit
wire  [6:0] cur_cm /* synthesis syn_romstyle = "select_rom" */;

wire [5:0] pst_dec_i; // pst = pStateIdx
reg  [5:0] pst_init_o; //cabac_cm output
wire [5:0] pst_dec_o; //cabac_decode_bin output
wire       mps_dec_i;
reg        mps_init_o;
wire       mps_dec_o;


(* ram_style = "distributed" *) reg  [6:0] cm[0:30];



assign cur_cm = cm[i_cm_idx];


assign mps_dec_i =  cur_cm[0];
assign pst_dec_i =  cur_cm[6:1];



cabac_decode_bin cabac_decode_bin_inst
(
    .clk(clk),
    .i_ivlCurrRange(i_ivlCurrRange),
    .i_ivlOffset(i_ivlOffset),
    .i_pStateIdx(pst_dec_i),
    .i_valMps(mps_dec_i),
    .i_rbsp_in(i_rbsp_in[7:2]),

    .o_ivlCurrRange(o_ivlCurrRange),
    .o_ivlOffset(o_ivlOffset),
    .o_pStateIdx(pst_dec_o),
    .o_valMps(mps_dec_o),
    .o_binVal(o_binVal),
    .o_output_len(o_output_len)
);


always @(posedge clk)
    if (~o_init_done) begin
        cm[init_cm_idx_minus1] <= {pst_init_o, mps_init_o};

    end else if (i_dec_en && i_valid) begin
        cm[i_cm_idx] <= {pst_dec_o, mps_dec_o};
    end


reg         [ 1:0]  initType;

reg  signed [ 8:0]  m;
reg  signed [ 8:0]  n;
reg         [ 6:0]  preCtxState;

reg  signed [ 9:0]  add_n;
wire signed [ 6:0]  slice_qpy_signed;
reg         [ 2:0]  stage;
reg signed [13:0] mult_qp1;

assign slice_qpy_signed = {1'b0,i_SliceQpY};

(* use_dsp48 = "yes" *)
reg signed [13:0] mult_qp;
always @ (posedge clk)
    mult_qp <= slice_qpy_signed*m;


always @(*)
    if (i_slice_type == `I_SLICE)
        initType <= 0;
    else begin
        if (i_cabac_init_present_flag && i_cabac_init_flag)
            initType <= 2;
        else
            initType <= 1;
    end

always @(add_n)
    begin
        if (add_n[9] == 1'b1 || add_n == 10'd0)
            preCtxState <= 7'd1;
        else if (add_n > 10'd125)
            preCtxState <= 7'd126;
        else
            preCtxState <= add_n[6:0];
    end

always @(preCtxState)
    begin
        if (preCtxState[6] == 1'b0) begin
            pst_init_o <= 6'd63 - preCtxState[5:0];
            mps_init_o <= 1'b0;
        end else begin
            pst_init_o <= preCtxState[5:0];
            mps_init_o <= 1'b1;
        end
    end

always @(posedge clk)
    if (rst) begin //reset¼´init
        o_init_done        <= 0;
        stage              <= 0;
        init_cm_idx        <= 0;
        init_cm_idx_minus1 <= 5'b11111;
    end else begin
        if (o_init_done != 1) begin
            if (stage == 0) begin
                case({initType[1:0], init_cm_idx[4:0]})

                {2'd0, 5'd0} : {m,n} = {9'd0, 9'd64}; //cu_transquant_bypass_flag 0
                {2'd1, 5'd0} : {m,n} = {9'd0, 9'd64}; //
                {2'd2, 5'd0} : {m,n} = {9'd0, 9'd64}; //
                {2'd0, 5'd1} : {m,n} = {9'd0, 9'd64}; //cu_skip_flag 1
                {2'd1, 5'd1} : {m,n} = {9'd15, 9'd24}; //
                {2'd2, 5'd1} : {m,n} = {9'd15, 9'd24}; //
                {2'd0, 5'd2} : {m,n} = {9'd0, 9'd64}; //
                {2'd1, 5'd2} : {m,n} = {9'd10, 9'd56}; //
                {2'd2, 5'd2} : {m,n} = {9'd10, 9'd56}; //
                {2'd0, 5'd3} : {m,n} = {9'd0, 9'd64}; //
                {2'd1, 5'd3} : {m,n} = {9'd15, 9'd56}; //
                {2'd2, 5'd3} : {m,n} = {9'd15, 9'd56}; //
                {2'd0, 5'd4} : {m,n} = {9'd0, 9'd64}; //merge_flag 4
                {2'd1, 5'd4} : {m,n} = {9'd497, 9'd96}; //
                {2'd2, 5'd4} : {m,n} = {9'd0, 9'd64}; //
                {2'd0, 5'd5} : {m,n} = {9'd0, 9'd64}; //merge_idx_ext 5
                {2'd1, 5'd5} : {m,n} = {9'd502, 9'd64}; //
                {2'd2, 5'd5} : {m,n} = {9'd507, 9'd56}; //
                {2'd0, 5'd6} : {m,n} = {9'd10, 9'd48}; //part_mode 6
                {2'd1, 5'd6} : {m,n} = {9'd0, 9'd64}; //
                {2'd2, 5'd6} : {m,n} = {9'd0, 9'd64}; //
                {2'd0, 5'd7} : {m,n} = {9'd0, 9'd64}; //
                {2'd1, 5'd7} : {m,n} = {9'd507, 9'd72}; //
                {2'd2, 5'd7} : {m,n} = {9'd507, 9'd72}; //
                {2'd0, 5'd8} : {m,n} = {9'd0, 9'd64}; //
                {2'd1, 5'd8} : {m,n} = {9'd0, 9'd64}; //
                {2'd2, 5'd8} : {m,n} = {9'd0, 9'd64}; //
                {2'd0, 5'd9} : {m,n} = {9'd0, 9'd64}; //
                {2'd1, 5'd9} : {m,n} = {9'd0, 9'd64}; //
                {2'd2, 5'd9} : {m,n} = {9'd0, 9'd64}; //
                {2'd0, 5'd10} : {m,n} = {9'd0, 9'd64}; //pred_mode 10
                {2'd1, 5'd10} : {m,n} = {9'd0, 9'd24}; //
                {2'd2, 5'd10} : {m,n} = {9'd507, 9'd32}; //
                {2'd0, 5'd11} : {m,n} = {9'd10, 9'd48}; //prev_intra_luma_pred_flag 11
                {2'd1, 5'd11} : {m,n} = {9'd0, 9'd64}; //
                {2'd2, 5'd11} : {m,n} = {9'd10, 9'd40}; //
                {2'd0, 5'd12} : {m,n} = {9'd482, 9'd104}; //intra_chroma_pred_mode 12
                {2'd1, 5'd12} : {m,n} = {9'd0, 9'd48}; //
                {2'd2, 5'd12} : {m,n} = {9'd0, 9'd48}; //
                {2'd0, 5'd13} : {m,n} = {9'd0, 9'd64}; //inter_dir 13
                {2'd1, 5'd13} : {m,n} = {9'd492, 9'd104}; // 
                {2'd2, 5'd13} : {m,n} = {9'd492, 9'd104}; //
                {2'd0, 5'd14} : {m,n} = {9'd0, 9'd64}; //
                {2'd1, 5'd14} : {m,n} = {9'd487, 9'd104}; //
                {2'd2, 5'd14} : {m,n} = {9'd487, 9'd104}; //
                {2'd0, 5'd15} : {m,n} = {9'd0, 9'd64}; //
                {2'd1, 5'd15} : {m,n} = {9'd482, 9'd104}; //
                {2'd2, 5'd15} : {m,n} = {9'd482, 9'd104}; //
                {2'd0, 5'd16} : {m,n} = {9'd0, 9'd64}; //
                {2'd1, 5'd16} : {m,n} = {9'd472, 9'd104}; //
                {2'd2, 5'd16} : {m,n} = {9'd472, 9'd104}; //
                {2'd0, 5'd17} : {m,n} = {9'd0, 9'd64}; //
                {2'd1, 5'd17} : {m,n} = {9'd472, 9'd104}; //
                {2'd2, 5'd17} : {m,n} = {9'd472, 9'd104}; //
                {2'd0, 5'd18} : {m,n} = {9'd0, 9'd64}; //mvd 18
                {2'd1, 5'd18} : {m,n} = {9'd507, 9'd80}; //
                {2'd2, 5'd18} : {m,n} = {9'd5, 9'd56}; //
                {2'd0, 5'd19} : {m,n} = {9'd0, 9'd64}; //
                {2'd1, 5'd19} : {m,n} = {9'd15, 9'd32}; //
                {2'd2, 5'd19} : {m,n} = {9'd15, 9'd32}; //
                {2'd0, 5'd20} : {m,n} = {9'd0, 9'd64}; //ref_pic 20
                {2'd1, 5'd20} : {m,n} = {9'd0, 9'd56}; //
                {2'd2, 5'd20} : {m,n} = {9'd0, 9'd56}; //
                {2'd0, 5'd21} : {m,n} = {9'd0, 9'd64}; //
                {2'd1, 5'd21} : {m,n} = {9'd0, 9'd56}; //
                {2'd2, 5'd21} : {m,n} = {9'd0, 9'd56}; //
                {2'd0, 5'd22} : {m,n} = {9'd492, 9'd96}; //qt_cbf_cb_cr 22
                {2'd1, 5'd22} : {m,n} = {9'd0, 9'd24}; //
                {2'd2, 5'd22} : {m,n} = {9'd0, 9'd24}; //
                {2'd0, 5'd23} : {m,n} = {9'd507, 9'd64}; //
                {2'd1, 5'd23} : {m,n} = {9'd497, 9'd72}; //
                {2'd2, 5'd23} : {m,n} = {9'd492, 9'd80}; //
                {2'd0, 5'd24} : {m,n} = {9'd10, 9'd32}; //
                {2'd1, 5'd24} : {m,n} = {9'd5, 9'd40}; //
                {2'd2, 5'd24} : {m,n} = {9'd5, 9'd40}; //
                {2'd0, 5'd25} : {m,n} = {9'd0, 9'd64}; //
                {2'd1, 5'd25} : {m,n} = {9'd0, 9'd64}; //
                {2'd2, 5'd25} : {m,n} = {9'd0, 9'd64}; //
                {2'd0, 5'd26} : {m,n} = {9'd0, 9'd64}; //qt_root_cbf 26
                {2'd1, 5'd26} : {m,n} = {9'd487, 9'd104}; //
                {2'd2, 5'd26} : {m,n} = {9'd487, 9'd104}; //
                {2'd0, 5'd27} : {m,n} = {9'd0, 9'd64}; //mvp_idx 27
                {2'd1, 5'd27} : {m,n} = {9'd5, 9'd48}; //
                {2'd2, 5'd27} : {m,n} = {9'd5, 9'd48}; //
                {2'd0, 5'd28} : {m,n} = {9'd0, 9'd56}; //trans_subdiv_flag 28
                {2'd1, 5'd28} : {m,n} = {9'd502, 9'd80}; //
                {2'd2, 5'd28} : {m,n} = {9'd25, 9'd496}; //
                {2'd0, 5'd29} : {m,n} = {9'd507, 9'd64}; //
                {2'd1, 5'd29} : {m,n} = {9'd507, 9'd64}; //
                {2'd2, 5'd29} : {m,n} = {9'd5, 9'd40}; //
                {2'd0, 5'd30} : {m,n} = {9'd507, 9'd64}; //
                {2'd1, 5'd30} : {m,n} = {9'd492, 9'd96}; //
                {2'd2, 5'd30} : {m,n} = {9'd502, 9'd64}; //
                    default:{m,n} = {9'd0, 9'd0};
                endcase
                stage <= 1;
            end
            if (stage == 1) begin
                stage <= 2;
            end
            if (stage == 2) begin
                mult_qp1             <= mult_qp;
                stage                <= 3;
            end
            if (stage == 3) begin
                add_n                <= (mult_qp1>>>4) + n;
                init_cm_idx          <= init_cm_idx+1;
                init_cm_idx_minus1   <= init_cm_idx_minus1+1;
                stage <= 0;
                if (init_cm_idx == `CM_COUNT)
                    o_init_done      <= 1;
                else
                    o_init_done      <= 0;
            end
        end
    end


`ifdef RANDOM_INIT
integer  seed;
integer random_val;
initial  begin
    seed                               = $get_initial_random_seed(); 
    random_val                         = $random(seed);
    o_init_done                        = {random_val,random_val};
    init_cm_idx                        = {random_val[1:0],random_val[31:2],random_val[1:0],random_val[31:2]};
    init_cm_idx_minus1                 = {random_val[2:0],random_val[31:3],random_val[2:0],random_val[31:3]};
    pst_init_o                         = {random_val[3:0],random_val[31:4],random_val[3:0],random_val[31:4]};
    mps_init_o                         = {random_val[4:0],random_val[31:5],random_val[4:0],random_val[31:5]};
    initType                           = {random_val[5:0],random_val[31:6],random_val[5:0],random_val[31:6]};
    m                                  = {random_val[6:0],random_val[31:7],random_val[6:0],random_val[31:7]};
    n                                  = {random_val[7:0],random_val[31:8],random_val[7:0],random_val[31:8]};
    preCtxState                        = {random_val[8:0],random_val[31:9],random_val[8:0],random_val[31:9]};
    add_n                              = {random_val[9:0],random_val[31:10],random_val[9:0],random_val[31:10]};
    stage                              = {random_val[10:0],random_val[31:11],random_val[10:0],random_val[31:11]};
    mult_qp1                           = {random_val[11:0],random_val[31:12],random_val[11:0],random_val[31:12]};
    mult_qp                            = {random_val[12:0],random_val[31:13],random_val[12:0],random_val[31:13]};
end
`endif


endmodule
