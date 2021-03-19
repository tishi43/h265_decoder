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

module tu
(
 input wire                          clk                               ,
 input wire                          rst                               ,
 input wire                          global_rst                        ,
 input wire                          i_rst_slice                       ,
 input wire                          en                                ,

 input wire              [ 1: 0]     i_slice_type                      ,

 input wire                          i_cu_transquant_bypass_flag       , //cu
 input wire                          i_cu_qp_delta_enabled_flag        ,
 input wire                          i_transform_skip_enabled_flag     ,

 input wire                          i_sign_data_hiding_enabled_flag   , //pps

 input wire   [`max_x_bits-1: 0]     i_x0                              ,
 input wire   [`max_y_bits-1: 0]     i_y0                              ,
 input wire              [15 :0]     i_slice_num                       ,
 input wire              [ 5: 0]     i_xTu                             ,
 input wire              [ 5: 0]     i_yTu                             ,
 input wire              [ 6: 0]     i_CbSize                          ,

 input wire              [ 2: 0]     i_trafoDepth                      ,
 input wire              [ 2: 0]     i_log2TrafoSize                   ,
 input wire              [ 6: 0]     i_trafoSize                       ,
 input wire                          i_cbf_cb                          ,
 input wire                          i_cbf_cr                          ,
 input wire              [ 5: 0]     i_IntraPredModeY                  ,
 input wire              [ 5: 0]     i_intra_pred_mode_chroma          ,
 input wire              [ 2: 0]     i_part_mode                       ,
 input wire                          i_pred_mode                       ,
 input wire                          i_rqt_root_cbf                    ,
 input wire                          i_cu_skip_flag                    ,
 input wire                          i_IsCuQpDeltaCoded                ,
 input wire              [ 1: 0]     i_blkIdx                          ,
 input wire              [ 5: 0]     i_qPY_PRED                        ,
 input wire              [ 5: 0]     i_qPY                             ,
 input wire signed       [ 5: 0]     i_qp_cb_offset                    ,
 input wire signed       [ 5: 0]     i_qp_cr_offset                    ,

 output reg                          o_IsCuQpDeltaCoded                ,
 output reg              [ 5: 0]     o_QpY                             ,
(*mark_debug="true"*)
 output reg              [ 5: 0]     o_tu_state                        ,

 output reg              [ 5: 0]     o_cm_idx_xy_pref                  ,
 output reg              [ 5: 0]     o_cm_idx_sig                      ,
 output reg              [ 5: 0]     o_cm_idx_gt1_etc                  ,
 output reg                          o_dec_bin_en_xy_pref              ,
 output reg                          o_dec_bin_en_sig                  ,
 output reg                          o_dec_bin_en_gt1_etc              ,
 output reg                          o_byp_dec_en_tu                   ,
 output wire             [ 2: 0]     o_tq_luma_state                   ,
 output wire             [ 2: 0]     o_tq_cb_state                     ,
 output wire             [ 2: 0]     o_tq_cr_state                     ,
 output reg              [ 5: 0]     o_tq_luma_end_x                   ,
 output reg              [ 4: 0]     o_tq_cb_end_x                     ,
 output reg              [ 4: 0]     o_tq_cr_end_x                     ,
 output wire             [ 4: 0]     o_tq_cb_x                         ,
 output wire             [ 4: 0]     o_tq_cb_y                         ,
 output wire             [ 4: 0]     o_tq_cr_x                         ,
 output wire             [ 4: 0]     o_tq_cr_y                         ,
 output reg                          o_cbf_luma                        ,
 output reg              [ 1:0]      o_cIdx                            ,
 input wire                          i_bin_xy_pref                     ,
 input wire                          i_bin_sig                         ,
 input wire                          i_bin_gt1_etc                     ,
 input wire                          i_dec_bin_valid                   ,
 input wire                          i_bin_byp                         ,
 input wire              [31: 0]     fd_log                            ,
 input wire              [31: 0]     fd_tq_luma                        ,
 input wire              [31: 0]     fd_tq_cb                          ,
 input wire              [31: 0]     fd_tq_cr                          ,

 output wire      [63: 0]            dram_tq_we                        ,
 output wire      [63: 0][ 5: 0]     dram_tq_addrd                     ,
 output wire      [63: 0][ 9: 0]     dram_tq_did                       ,
 output wire      [31: 0]            dram_tq_cb_we                     ,
 output wire      [31: 0][ 4: 0]     dram_tq_cb_addrd                  ,
 output wire      [31: 0][ 9: 0]     dram_tq_cb_did                    ,
 output wire      [31: 0]            dram_tq_cr_we                     ,
 output wire      [31: 0][ 4: 0]     dram_tq_cr_addrd                  ,
 output wire      [31: 0][ 9: 0]     dram_tq_cr_did                    ,

 output wire             [ 6: 0]     o_tq_luma_done_y                  ,
 output wire             [ 5: 0]     o_tq_cb_done_y                    ,
 output wire             [ 5: 0]     o_tq_cr_done_y                    ,


 input wire              [ 8: 0]     i_ivlCurrRange                    ,
 input wire              [ 8: 0]     i_ivlOffset                 
);

reg                 [15:0]     slice_num      ;
reg      [`max_x_bits-1:0]     x0             ;
reg      [`max_y_bits-1:0]     y0             ;


wire [`max_ctb_x_bits-1:0]     xCtb           ;
wire [`max_ctb_y_bits-1:0]     yCtb           ;
wire                [ 5:0]     x              ;
wire                [ 5:0]     y              ;

reg                 [ 5:0]     xTu            ;
reg                 [ 5:0]     yTu            ;
reg                 [ 6:0]     CbSize         ;

assign xCtb = x0[`max_x_bits-1:6];
assign yCtb = y0[`max_y_bits-1:6];
assign x    = x0[5:0]; //CTB 64x64内部坐标
assign y    = y0[5:0];

reg                 [ 5:0]     i              ; //32x32TU最多含64个4x4 sub block
reg                 [ 3:0]     j              ;
reg                 [ 3:0]     clr_i          ;


reg                            cbf_cb         ;
reg                            cbf_cr         ;


reg                 [ 2:0]     trafoDepth     ;
reg                 [ 2:0]     log2TrafoSize  ;
reg                 [ 6:0]     trafoSize      ;

reg                 [ 1:0]     blkIdx         ;


reg                  cu_transquant_bypass_flag;
reg                  inferSbDcSigCoeffFlag    ;
(* ram_style = "block" *)
reg        [5:0]     lastSubBlock             ;
(* ram_style = "block" *)
reg        [3:0]     lastScanPos              ;
reg        [3:0]     sig_coeff_indices[0:15]  ;
reg        [4:0]     sig_coeff_cnt            ; //最大16
reg        [3:0]     sig_coeff_cnt_minus1     ;
reg        [4:0]     sig_coeff_cnt_pls1       ;

reg                  coeff_sign_flag[0:15]    ;
reg        [3:0]     lvl_rem_indices[0:15]    ;
reg        [3:0]     lvl_rem_cnt              ;
reg        [3:0]     lvl_rem_cnt_minus1       ;

reg                  cond_chroma_no_residual  ;

wire       [5:0]     qp_cu                    ;
reg signed [5:0]     CuQpDeltaVal             ;
reg        [3:0]     prefixVal                ; //todo位宽
reg        [3:0]     suffixVal                ;

assign qp_cu = i_qPY_PRED + CuQpDeltaVal;

reg                  transform_skip_flag      ;

reg        [3:0]     ctxOffset                ;
reg        [1:0]     ctxShift                 ;
wire       [3:0]     ctxOffset_cIdx0          ;

always @(*)
    if (o_cIdx == 0) begin
        case (log2TrafoSize)
            2: begin ctxOffset=0; ctxShift=0;end
            3: begin ctxOffset=3; ctxShift=1;end
            4: begin ctxOffset=6; ctxShift=1;end
            5: begin ctxOffset=10; ctxShift=1;end
            default: begin ctxOffset=10; ctxShift=1;end
        endcase
    end else begin
        ctxOffset=15;
        case (log2TrafoSize)
            2:ctxShift=0;
            3:ctxShift=1;
            4:ctxShift=2;
            5:ctxShift=3;
            default:ctxShift=0;
        endcase
    end

assign ctxOffset_cIdx0 = log2TrafoSize == 2?0:(log2TrafoSize == 3?3:(log2TrafoSize==4?6:10));

reg        [4:0]     k                                ;
reg        [4:0]     last_sig_coeff_x_prefix          ;
reg        [4:0]     last_sig_coeff_y_prefix          ;
reg        [4:0]     last_sig_coeff_x_suffix          ;
reg        [4:0]     last_sig_coeff_y_suffix          ;
reg        [4:0]     LastSignificantCoeffX            ;
reg        [4:0]     LastSignificantCoeffY            ;
reg        [1:0]     scanIdxY                         ;
reg        [1:0]     scanIdxC                         ;
reg        [1:0]     scanIdx                          ;
reg        [3:0]     n                                ; //4x4最多16点
reg        [3:0]     m                                ;
reg        [3:0]     m1                               ;


reg        [4:0]     last_scx_pre_max_bins_minus1     ;
reg        [4:0]     last_scy_pre_max_bins_minus1     ;
reg        [4:0]     last_scx_suf_max_bins_minus1     ;
reg        [4:0]     last_scy_suf_max_bins_minus1     ;

reg        [4:0]     last_scx_pre_ctx_inc             ;
reg        [4:0]     last_scy_pre_ctx_inc             ;
reg        [5:0]     cm_idx_gt1                       ;
reg        [5:0]     cm_idx_gt1_pred_bin0             ;
reg        [5:0]     cm_idx_gt1_pred_bin1             ;
reg        [5:0]     cm_idx_gt2                       ;

//搞一个binIdx用来遍历last_sig_coeff prefix,suffix，最大(5<<1)-1=9,todo suffix会大于15？
//i只用来遍历sub block
reg        [3:0]     binIdx                           ;

reg                  cond_last_scy_pre_gt3            ;
reg                  cond_last_scy_pre_gt2            ;
reg                  cond_last_scx_pre_gt3            ;

reg        [4:0]     last_scy_pre_pls1                ;
reg        [4:0]     last_scx_pre_pls1                ;

reg                  coded_sub_block_flag             ;
reg                  coded_sub_block_flag_right[0:7]  ;
reg                  coded_sub_block_flag_down[0:7]   ;

reg        [2:0]     xS                               ; //8x8
reg        [2:0]     yS                               ;
reg        [2:0]     xS_r                             ;
reg        [2:0]     yS_r                             ;
wire       [4:0]     xC                               ; //32x32
wire       [4:0]     yC                               ;
reg        [1:0]     xP                               ; //32x32
reg        [1:0]     yP                               ;
reg        [1:0]     xP_nxt                           ; //next n(n-1)'s xP
reg        [1:0]     yP_nxt                           ;
reg        [1:0]     xP_r                             ;
reg        [1:0]     yP_r                             ;

assign xC     = {xS,xP};
assign yC     = {yS,yP};


always @(i or scanIdx or log2TrafoSize)
    if (scanIdx == `SCAN_DIAG) begin
        if (log2TrafoSize <= 3) begin
            case (i[1:0])
            0: begin xS = 0; yS = 0; end //综合工具会优化,用不着你
            1: begin xS = 0; yS = 1; end
            2: begin xS = 1; yS = 0; end
            3: begin xS = 1; yS = 1; end
            endcase

        end else if (log2TrafoSize == 4) begin
            case (i[3:0])
             0: begin xS = 0; yS = 0; end
             1: begin xS = 0; yS = 1; end
             2: begin xS = 1; yS = 0; end
             3: begin xS = 0; yS = 2; end
             4: begin xS = 1; yS = 1; end
             5: begin xS = 2; yS = 0; end
             6: begin xS = 0; yS = 3; end
             7: begin xS = 1; yS = 2; end
             8: begin xS = 2; yS = 1; end
             9: begin xS = 3; yS = 0; end
            10: begin xS = 1; yS = 3; end
            11: begin xS = 2; yS = 2; end
            12: begin xS = 3; yS = 1; end
            13: begin xS = 2; yS = 3; end
            14: begin xS = 3; yS = 2; end
            15: begin xS = 3; yS = 3; end
            endcase
        end else if (log2TrafoSize == 5) begin
            case (i[5:0])
             0: begin xS = 0; yS = 0; end
             1: begin xS = 0; yS = 1; end
             2: begin xS = 1; yS = 0; end
             3: begin xS = 0; yS = 2; end
             4: begin xS = 1; yS = 1; end
             5: begin xS = 2; yS = 0; end
             6: begin xS = 0; yS = 3; end
             7: begin xS = 1; yS = 2; end
             8: begin xS = 2; yS = 1; end
             9: begin xS = 3; yS = 0; end
            10: begin xS = 0; yS = 4; end
            11: begin xS = 1; yS = 3; end
            12: begin xS = 2; yS = 2; end
            13: begin xS = 3; yS = 1; end
            14: begin xS = 4; yS = 0; end
            15: begin xS = 0; yS = 5; end
            16: begin xS = 1; yS = 4; end
            17: begin xS = 2; yS = 3; end
            18: begin xS = 3; yS = 2; end
            19: begin xS = 4; yS = 1; end
            20: begin xS = 5; yS = 0; end
            21: begin xS = 0; yS = 6; end
            22: begin xS = 1; yS = 5; end
            23: begin xS = 2; yS = 4; end
            24: begin xS = 3; yS = 3; end
            25: begin xS = 4; yS = 2; end
            26: begin xS = 5; yS = 1; end
            27: begin xS = 6; yS = 0; end
            28: begin xS = 0; yS = 7; end
            29: begin xS = 1; yS = 6; end
            30: begin xS = 2; yS = 5; end
            31: begin xS = 3; yS = 4; end
            32: begin xS = 4; yS = 3; end
            33: begin xS = 5; yS = 2; end
            34: begin xS = 6; yS = 1; end
            35: begin xS = 7; yS = 0; end
            36: begin xS = 1; yS = 7; end
            37: begin xS = 2; yS = 6; end
            38: begin xS = 3; yS = 5; end
            39: begin xS = 4; yS = 4; end
            40: begin xS = 5; yS = 3; end
            41: begin xS = 6; yS = 2; end
            42: begin xS = 7; yS = 1; end
            43: begin xS = 2; yS = 7; end
            44: begin xS = 3; yS = 6; end
            45: begin xS = 4; yS = 5; end
            46: begin xS = 5; yS = 4; end
            47: begin xS = 6; yS = 3; end
            48: begin xS = 7; yS = 2; end
            49: begin xS = 3; yS = 7; end
            50: begin xS = 4; yS = 6; end
            51: begin xS = 5; yS = 5; end
            52: begin xS = 6; yS = 4; end
            53: begin xS = 7; yS = 3; end
            54: begin xS = 4; yS = 7; end
            55: begin xS = 5; yS = 6; end
            56: begin xS = 6; yS = 5; end
            57: begin xS = 7; yS = 4; end
            58: begin xS = 5; yS = 7; end
            59: begin xS = 6; yS = 6; end
            60: begin xS = 7; yS = 5; end
            61: begin xS = 6; yS = 7; end
            62: begin xS = 7; yS = 6; end
            63: begin xS = 7; yS = 7; end
            endcase
        end else begin
            xS          = 0;
            yS          = 0;
        end
    end else if (scanIdx == `SCAN_HORIZ) begin
        case (i[1:0])
             0: begin xS = 0; yS = 0; end
             1: begin xS = 1; yS = 0; end
             2: begin xS = 0; yS = 1; end
             3: begin xS = 1; yS = 1; end
         endcase
    end else begin //scanIdx == `SCAN_VERT
        case (i[1:0])
             0: begin xS = 0; yS = 0; end
             1: begin xS = 0; yS = 1; end
             2: begin xS = 1; yS = 0; end
             3: begin xS = 1; yS = 1; end
         endcase
    end



always @(n or scanIdx)
    if (scanIdx == `SCAN_DIAG) begin
            case (n)
             0: begin xP = 0; yP = 0; end
             1: begin xP = 0; yP = 1; end
             2: begin xP = 1; yP = 0; end
             3: begin xP = 0; yP = 2; end
             4: begin xP = 1; yP = 1; end
             5: begin xP = 2; yP = 0; end
             6: begin xP = 0; yP = 3; end
             7: begin xP = 1; yP = 2; end
             8: begin xP = 2; yP = 1; end
             9: begin xP = 3; yP = 0; end
            10: begin xP = 1; yP = 3; end
            11: begin xP = 2; yP = 2; end
            12: begin xP = 3; yP = 1; end
            13: begin xP = 2; yP = 3; end
            14: begin xP = 3; yP = 2; end
            15: begin xP = 3; yP = 3; end
            endcase
    end else if (scanIdx == `SCAN_HORIZ) begin
            case (n)
             0: begin xP = 0; yP = 0; end
             1: begin xP = 1; yP = 0; end
             2: begin xP = 2; yP = 0; end
             3: begin xP = 3; yP = 0; end
             4: begin xP = 0; yP = 1; end
             5: begin xP = 1; yP = 1; end
             6: begin xP = 2; yP = 1; end
             7: begin xP = 3; yP = 1; end
             8: begin xP = 0; yP = 2; end
             9: begin xP = 1; yP = 2; end
            10: begin xP = 2; yP = 2; end
            11: begin xP = 3; yP = 2; end
            12: begin xP = 0; yP = 3; end
            13: begin xP = 1; yP = 3; end
            14: begin xP = 2; yP = 3; end
            15: begin xP = 3; yP = 3; end
            endcase
    end else begin //scanIdx == `SCAN_VERT
            case (n)
             0: begin xP = 0; yP = 0; end
             1: begin xP = 0; yP = 1; end
             2: begin xP = 0; yP = 2; end
             3: begin xP = 0; yP = 3; end
             4: begin xP = 1; yP = 0; end
             5: begin xP = 1; yP = 1; end
             6: begin xP = 1; yP = 2; end
             7: begin xP = 1; yP = 3; end
             8: begin xP = 2; yP = 0; end
             9: begin xP = 2; yP = 1; end
            10: begin xP = 2; yP = 2; end
            11: begin xP = 2; yP = 3; end
            12: begin xP = 3; yP = 0; end
            13: begin xP = 3; yP = 1; end
            14: begin xP = 3; yP = 2; end
            15: begin xP = 3; yP = 3; end
            endcase
    end

always @(n or scanIdx)
    if (scanIdx == `SCAN_DIAG) begin
            case (n)
             0: begin xP_nxt = 3; yP_nxt = 3; end
             1: begin xP_nxt = 0; yP_nxt = 0; end
             2: begin xP_nxt = 0; yP_nxt = 1; end
             3: begin xP_nxt = 1; yP_nxt = 0; end
             4: begin xP_nxt = 0; yP_nxt = 2; end
             5: begin xP_nxt = 1; yP_nxt = 1; end
             6: begin xP_nxt = 2; yP_nxt = 0; end
             7: begin xP_nxt = 0; yP_nxt = 3; end
             8: begin xP_nxt = 1; yP_nxt = 2; end
             9: begin xP_nxt = 2; yP_nxt = 1; end
            10: begin xP_nxt = 3; yP_nxt = 0; end
            11: begin xP_nxt = 1; yP_nxt = 3; end
            12: begin xP_nxt = 2; yP_nxt = 2; end
            13: begin xP_nxt = 3; yP_nxt = 1; end
            14: begin xP_nxt = 2; yP_nxt = 3; end
            15: begin xP_nxt = 3; yP_nxt = 2; end
            endcase
    end else if (scanIdx == `SCAN_HORIZ) begin
            case (n)
             0: begin xP_nxt = 3; yP_nxt = 3; end
             1: begin xP_nxt = 0; yP_nxt = 0; end
             2: begin xP_nxt = 1; yP_nxt = 0; end
             3: begin xP_nxt = 2; yP_nxt = 0; end
             4: begin xP_nxt = 3; yP_nxt = 0; end
             5: begin xP_nxt = 0; yP_nxt = 1; end
             6: begin xP_nxt = 1; yP_nxt = 1; end
             7: begin xP_nxt = 2; yP_nxt = 1; end
             8: begin xP_nxt = 3; yP_nxt = 1; end
             9: begin xP_nxt = 0; yP_nxt = 2; end
            10: begin xP_nxt = 1; yP_nxt = 2; end
            11: begin xP_nxt = 2; yP_nxt = 2; end
            12: begin xP_nxt = 3; yP_nxt = 2; end
            13: begin xP_nxt = 0; yP_nxt = 3; end
            14: begin xP_nxt = 1; yP_nxt = 3; end
            15: begin xP_nxt = 2; yP_nxt = 3; end

            endcase
    end else begin //scanIdx == `SCAN_VERT
            case (n)
             0: begin xP_nxt = 3; yP_nxt = 3; end
             1: begin xP_nxt = 0; yP_nxt = 0; end
             2: begin xP_nxt = 0; yP_nxt = 1; end
             3: begin xP_nxt = 0; yP_nxt = 2; end
             4: begin xP_nxt = 0; yP_nxt = 3; end
             5: begin xP_nxt = 1; yP_nxt = 0; end
             6: begin xP_nxt = 1; yP_nxt = 1; end
             7: begin xP_nxt = 1; yP_nxt = 2; end
             8: begin xP_nxt = 1; yP_nxt = 3; end
             9: begin xP_nxt = 2; yP_nxt = 0; end
            10: begin xP_nxt = 2; yP_nxt = 1; end
            11: begin xP_nxt = 2; yP_nxt = 2; end
            12: begin xP_nxt = 2; yP_nxt = 3; end
            13: begin xP_nxt = 3; yP_nxt = 0; end
            14: begin xP_nxt = 3; yP_nxt = 1; end
            15: begin xP_nxt = 3; yP_nxt = 2; end

            endcase
    end

reg    [5:0]       sig_flag_ctx_inc     ;
reg    [5:0]       sigCtx               ;
reg    [5:0]       sigCtx_r             ;
reg    [1:0]       prevCsbf             ;


//prevCsbf用于sig_coeff_flag
//CsbfCtx用于coded_sub_block_flag

//log2TrafoSize=3
// -------
//| x | * |
// --- ---
//| * |   |
// --- ---
//log2TraofoSize=4
// ------- -------
//|   |   |   |   |
// --- --- --- ---
//|   |   |   |   |
// --- --- --- ---
//|   |   | x | * |
// --- --- --- ---
//|   |   | * |   |
// --- --- --- ---



always @(*)
begin
    if (log2TrafoSize == 2) begin
        case ({yP_nxt[1:0],xP_nxt[1:0]})
         0: sigCtx        = 0;
         1: sigCtx        = 1;
         2: sigCtx        = 4;
         3: sigCtx        = 5;
         4: sigCtx        = 2;
         5: sigCtx        = 3;
         6: sigCtx        = 4;
         7: sigCtx        = 5;
         8: sigCtx        = 6;
         9: sigCtx        = 6;
        10: sigCtx        = 8;
        11: sigCtx        = 8;
        12: sigCtx        = 7;
        13: sigCtx        = 7;
        14: sigCtx        = 8;
        15: sigCtx        = 0;
        endcase

    end else if (i == 0 && n == 1) begin //todo xC+yC==0,只有xC==0&&yC==0,xS,xP,yS,yP都为0，只有i=0,n=0

        sigCtx           = 0;
    end else begin
        if (prevCsbf == 0) begin
            sigCtx       = (n == 1) ? 2 : (xP_nxt+yP_nxt < 3 ? 1:0); //xP_nxt==0&&yP_nxt==0 -> n==1
        end else if (prevCsbf == 1) begin
            sigCtx       = (yP_nxt == 0) ? 2 : (yP_nxt == 1 ? 1:0);
        end else if (prevCsbf == 2) begin
            sigCtx       = (xP_nxt == 0) ? 2 : (xP_nxt == 1 ? 1:0);
        end else begin
            sigCtx       = 2;
        end

        if (o_cIdx == 0) begin
            if (i > 0) //xS+yS>0
                sigCtx   = sigCtx + 3;
            if (log2TrafoSize == 3)
                sigCtx   = sigCtx + (scanIdx == `SCAN_DIAG ? 9:15);
            else
                sigCtx   = sigCtx + 21;
        end else begin
            if (log2TrafoSize == 3)
                sigCtx   = sigCtx + 9;
            else
                sigCtx   = sigCtx + 12;
        end
    end

end


reg    [1:0]       csbf_ctx_inc            ;
reg    [1:0]       csbfCtx                 ;


//只有4个context，0，1用于luma，2，3用于chroma
//if (cIdx == 0)
//    ctxIdx = min(csbfCtx, 1);
//else
//    ctxIdx = 2 + min(csbfCtx, 1);

always @(*)
begin
    if (o_cIdx == 0) begin
        if (csbfCtx > 0) begin
            csbf_ctx_inc = 1;
        end else begin
            csbf_ctx_inc = 0;
        end
    end else begin
        if (csbfCtx > 0) begin
            csbf_ctx_inc = 3;
        end else begin
            csbf_ctx_inc = 2;
        end
    end

end


(* ram_style = "block" *) reg  [9:0] scan_order_sz32x32[0:1023];
(* ram_style = "block" *) reg  [9:0] scan_order_sz16x16[0:255];
(* ram_style = "block" *) reg  [9:0] scan_order_sz8x8_4x4[0:383];


//log2TrafoSize=5，深度LastSignificantCoeffX[4:0],LastSignificantCoeffY[4:0] 5，5=10bit，1024深度，宽度16，只用到10
//log2TrafoSize=4, 深度bit  4，4=8bit，
//log2TrafoSize=3，2的hor，ver，深度比特 1，2，3，3=9bit，

initial begin
    scan_order_sz32x32 = {10'd0, 10'd2, 10'd5, 10'd9, 10'd32, 10'd34, 10'd37, 10'd41, 10'd80, 10'd82, 10'd85, 10'd89, 10'd144, 10'd146, 10'd149, 10'd153,
        10'd224, 10'd226, 10'd229, 10'd233, 10'd320, 10'd322, 10'd325, 10'd329, 10'd432, 10'd434, 10'd437, 10'd441, 10'd560, 10'd562, 10'd565, 10'd569,
        10'd1, 10'd4, 10'd8, 10'd12, 10'd33, 10'd36, 10'd40, 10'd44, 10'd81, 10'd84, 10'd88, 10'd92, 10'd145, 10'd148, 10'd152, 10'd156,
        10'd225, 10'd228, 10'd232, 10'd236, 10'd321, 10'd324, 10'd328, 10'd332, 10'd433, 10'd436, 10'd440, 10'd444, 10'd561, 10'd564, 10'd568, 10'd572,
        10'd3, 10'd7, 10'd11, 10'd14, 10'd35, 10'd39, 10'd43, 10'd46, 10'd83, 10'd87, 10'd91, 10'd94, 10'd147, 10'd151, 10'd155, 10'd158,
        10'd227, 10'd231, 10'd235, 10'd238, 10'd323, 10'd327, 10'd331, 10'd334, 10'd435, 10'd439, 10'd443, 10'd446, 10'd563, 10'd567, 10'd571, 10'd574,
        10'd6, 10'd10, 10'd13, 10'd15, 10'd38, 10'd42, 10'd45, 10'd47, 10'd86, 10'd90, 10'd93, 10'd95, 10'd150, 10'd154, 10'd157, 10'd159,
        10'd230, 10'd234, 10'd237, 10'd239, 10'd326, 10'd330, 10'd333, 10'd335, 10'd438, 10'd442, 10'd445, 10'd447, 10'd566, 10'd570, 10'd573, 10'd575,
        10'd16, 10'd18, 10'd21, 10'd25, 10'd64, 10'd66, 10'd69, 10'd73, 10'd128, 10'd130, 10'd133, 10'd137, 10'd208, 10'd210, 10'd213, 10'd217,
        10'd304, 10'd306, 10'd309, 10'd313, 10'd416, 10'd418, 10'd421, 10'd425, 10'd544, 10'd546, 10'd549, 10'd553, 10'd672, 10'd674, 10'd677, 10'd681,
        10'd17, 10'd20, 10'd24, 10'd28, 10'd65, 10'd68, 10'd72, 10'd76, 10'd129, 10'd132, 10'd136, 10'd140, 10'd209, 10'd212, 10'd216, 10'd220,
        10'd305, 10'd308, 10'd312, 10'd316, 10'd417, 10'd420, 10'd424, 10'd428, 10'd545, 10'd548, 10'd552, 10'd556, 10'd673, 10'd676, 10'd680, 10'd684,
        10'd19, 10'd23, 10'd27, 10'd30, 10'd67, 10'd71, 10'd75, 10'd78, 10'd131, 10'd135, 10'd139, 10'd142, 10'd211, 10'd215, 10'd219, 10'd222,
        10'd307, 10'd311, 10'd315, 10'd318, 10'd419, 10'd423, 10'd427, 10'd430, 10'd547, 10'd551, 10'd555, 10'd558, 10'd675, 10'd679, 10'd683, 10'd686,
        10'd22, 10'd26, 10'd29, 10'd31, 10'd70, 10'd74, 10'd77, 10'd79, 10'd134, 10'd138, 10'd141, 10'd143, 10'd214, 10'd218, 10'd221, 10'd223,
        10'd310, 10'd314, 10'd317, 10'd319, 10'd422, 10'd426, 10'd429, 10'd431, 10'd550, 10'd554, 10'd557, 10'd559, 10'd678, 10'd682, 10'd685, 10'd687,
        10'd48, 10'd50, 10'd53, 10'd57, 10'd112, 10'd114, 10'd117, 10'd121, 10'd192, 10'd194, 10'd197, 10'd201, 10'd288, 10'd290, 10'd293, 10'd297,
        10'd400, 10'd402, 10'd405, 10'd409, 10'd528, 10'd530, 10'd533, 10'd537, 10'd656, 10'd658, 10'd661, 10'd665, 10'd768, 10'd770, 10'd773, 10'd777,
        10'd49, 10'd52, 10'd56, 10'd60, 10'd113, 10'd116, 10'd120, 10'd124, 10'd193, 10'd196, 10'd200, 10'd204, 10'd289, 10'd292, 10'd296, 10'd300,
        10'd401, 10'd404, 10'd408, 10'd412, 10'd529, 10'd532, 10'd536, 10'd540, 10'd657, 10'd660, 10'd664, 10'd668, 10'd769, 10'd772, 10'd776, 10'd780,
        10'd51, 10'd55, 10'd59, 10'd62, 10'd115, 10'd119, 10'd123, 10'd126, 10'd195, 10'd199, 10'd203, 10'd206, 10'd291, 10'd295, 10'd299, 10'd302,
        10'd403, 10'd407, 10'd411, 10'd414, 10'd531, 10'd535, 10'd539, 10'd542, 10'd659, 10'd663, 10'd667, 10'd670, 10'd771, 10'd775, 10'd779, 10'd782,
        10'd54, 10'd58, 10'd61, 10'd63, 10'd118, 10'd122, 10'd125, 10'd127, 10'd198, 10'd202, 10'd205, 10'd207, 10'd294, 10'd298, 10'd301, 10'd303,
        10'd406, 10'd410, 10'd413, 10'd415, 10'd534, 10'd538, 10'd541, 10'd543, 10'd662, 10'd666, 10'd669, 10'd671, 10'd774, 10'd778, 10'd781, 10'd783,
        10'd96, 10'd98, 10'd101, 10'd105, 10'd176, 10'd178, 10'd181, 10'd185, 10'd272, 10'd274, 10'd277, 10'd281, 10'd384, 10'd386, 10'd389, 10'd393,
        10'd512, 10'd514, 10'd517, 10'd521, 10'd640, 10'd642, 10'd645, 10'd649, 10'd752, 10'd754, 10'd757, 10'd761, 10'd848, 10'd850, 10'd853, 10'd857,
        10'd97, 10'd100, 10'd104, 10'd108, 10'd177, 10'd180, 10'd184, 10'd188, 10'd273, 10'd276, 10'd280, 10'd284, 10'd385, 10'd388, 10'd392, 10'd396,
        10'd513, 10'd516, 10'd520, 10'd524, 10'd641, 10'd644, 10'd648, 10'd652, 10'd753, 10'd756, 10'd760, 10'd764, 10'd849, 10'd852, 10'd856, 10'd860,
        10'd99, 10'd103, 10'd107, 10'd110, 10'd179, 10'd183, 10'd187, 10'd190, 10'd275, 10'd279, 10'd283, 10'd286, 10'd387, 10'd391, 10'd395, 10'd398,
        10'd515, 10'd519, 10'd523, 10'd526, 10'd643, 10'd647, 10'd651, 10'd654, 10'd755, 10'd759, 10'd763, 10'd766, 10'd851, 10'd855, 10'd859, 10'd862,
        10'd102, 10'd106, 10'd109, 10'd111, 10'd182, 10'd186, 10'd189, 10'd191, 10'd278, 10'd282, 10'd285, 10'd287, 10'd390, 10'd394, 10'd397, 10'd399,
        10'd518, 10'd522, 10'd525, 10'd527, 10'd646, 10'd650, 10'd653, 10'd655, 10'd758, 10'd762, 10'd765, 10'd767, 10'd854, 10'd858, 10'd861, 10'd863,
        10'd160, 10'd162, 10'd165, 10'd169, 10'd256, 10'd258, 10'd261, 10'd265, 10'd368, 10'd370, 10'd373, 10'd377, 10'd496, 10'd498, 10'd501, 10'd505,
        10'd624, 10'd626, 10'd629, 10'd633, 10'd736, 10'd738, 10'd741, 10'd745, 10'd832, 10'd834, 10'd837, 10'd841, 10'd912, 10'd914, 10'd917, 10'd921,
        10'd161, 10'd164, 10'd168, 10'd172, 10'd257, 10'd260, 10'd264, 10'd268, 10'd369, 10'd372, 10'd376, 10'd380, 10'd497, 10'd500, 10'd504, 10'd508,
        10'd625, 10'd628, 10'd632, 10'd636, 10'd737, 10'd740, 10'd744, 10'd748, 10'd833, 10'd836, 10'd840, 10'd844, 10'd913, 10'd916, 10'd920, 10'd924,
        10'd163, 10'd167, 10'd171, 10'd174, 10'd259, 10'd263, 10'd267, 10'd270, 10'd371, 10'd375, 10'd379, 10'd382, 10'd499, 10'd503, 10'd507, 10'd510,
        10'd627, 10'd631, 10'd635, 10'd638, 10'd739, 10'd743, 10'd747, 10'd750, 10'd835, 10'd839, 10'd843, 10'd846, 10'd915, 10'd919, 10'd923, 10'd926,
        10'd166, 10'd170, 10'd173, 10'd175, 10'd262, 10'd266, 10'd269, 10'd271, 10'd374, 10'd378, 10'd381, 10'd383, 10'd502, 10'd506, 10'd509, 10'd511,
        10'd630, 10'd634, 10'd637, 10'd639, 10'd742, 10'd746, 10'd749, 10'd751, 10'd838, 10'd842, 10'd845, 10'd847, 10'd918, 10'd922, 10'd925, 10'd927,
        10'd240, 10'd242, 10'd245, 10'd249, 10'd352, 10'd354, 10'd357, 10'd361, 10'd480, 10'd482, 10'd485, 10'd489, 10'd608, 10'd610, 10'd613, 10'd617,
        10'd720, 10'd722, 10'd725, 10'd729, 10'd816, 10'd818, 10'd821, 10'd825, 10'd896, 10'd898, 10'd901, 10'd905, 10'd960, 10'd962, 10'd965, 10'd969,
        10'd241, 10'd244, 10'd248, 10'd252, 10'd353, 10'd356, 10'd360, 10'd364, 10'd481, 10'd484, 10'd488, 10'd492, 10'd609, 10'd612, 10'd616, 10'd620,
        10'd721, 10'd724, 10'd728, 10'd732, 10'd817, 10'd820, 10'd824, 10'd828, 10'd897, 10'd900, 10'd904, 10'd908, 10'd961, 10'd964, 10'd968, 10'd972,
        10'd243, 10'd247, 10'd251, 10'd254, 10'd355, 10'd359, 10'd363, 10'd366, 10'd483, 10'd487, 10'd491, 10'd494, 10'd611, 10'd615, 10'd619, 10'd622,
        10'd723, 10'd727, 10'd731, 10'd734, 10'd819, 10'd823, 10'd827, 10'd830, 10'd899, 10'd903, 10'd907, 10'd910, 10'd963, 10'd967, 10'd971, 10'd974,
        10'd246, 10'd250, 10'd253, 10'd255, 10'd358, 10'd362, 10'd365, 10'd367, 10'd486, 10'd490, 10'd493, 10'd495, 10'd614, 10'd618, 10'd621, 10'd623,
        10'd726, 10'd730, 10'd733, 10'd735, 10'd822, 10'd826, 10'd829, 10'd831, 10'd902, 10'd906, 10'd909, 10'd911, 10'd966, 10'd970, 10'd973, 10'd975,
        10'd336, 10'd338, 10'd341, 10'd345, 10'd464, 10'd466, 10'd469, 10'd473, 10'd592, 10'd594, 10'd597, 10'd601, 10'd704, 10'd706, 10'd709, 10'd713,
        10'd800, 10'd802, 10'd805, 10'd809, 10'd880, 10'd882, 10'd885, 10'd889, 10'd944, 10'd946, 10'd949, 10'd953, 10'd992, 10'd994, 10'd997, 10'd1001,
        10'd337, 10'd340, 10'd344, 10'd348, 10'd465, 10'd468, 10'd472, 10'd476, 10'd593, 10'd596, 10'd600, 10'd604, 10'd705, 10'd708, 10'd712, 10'd716,
        10'd801, 10'd804, 10'd808, 10'd812, 10'd881, 10'd884, 10'd888, 10'd892, 10'd945, 10'd948, 10'd952, 10'd956, 10'd993, 10'd996, 10'd1000, 10'd1004,
        10'd339, 10'd343, 10'd347, 10'd350, 10'd467, 10'd471, 10'd475, 10'd478, 10'd595, 10'd599, 10'd603, 10'd606, 10'd707, 10'd711, 10'd715, 10'd718,
        10'd803, 10'd807, 10'd811, 10'd814, 10'd883, 10'd887, 10'd891, 10'd894, 10'd947, 10'd951, 10'd955, 10'd958, 10'd995, 10'd999, 10'd1003, 10'd1006,
        10'd342, 10'd346, 10'd349, 10'd351, 10'd470, 10'd474, 10'd477, 10'd479, 10'd598, 10'd602, 10'd605, 10'd607, 10'd710, 10'd714, 10'd717, 10'd719,
        10'd806, 10'd810, 10'd813, 10'd815, 10'd886, 10'd890, 10'd893, 10'd895, 10'd950, 10'd954, 10'd957, 10'd959, 10'd998, 10'd1002, 10'd1005, 10'd1007,
        10'd448, 10'd450, 10'd453, 10'd457, 10'd576, 10'd578, 10'd581, 10'd585, 10'd688, 10'd690, 10'd693, 10'd697, 10'd784, 10'd786, 10'd789, 10'd793,
        10'd864, 10'd866, 10'd869, 10'd873, 10'd928, 10'd930, 10'd933, 10'd937, 10'd976, 10'd978, 10'd981, 10'd985, 10'd1008, 10'd1010, 10'd1013, 10'd1017,
        10'd449, 10'd452, 10'd456, 10'd460, 10'd577, 10'd580, 10'd584, 10'd588, 10'd689, 10'd692, 10'd696, 10'd700, 10'd785, 10'd788, 10'd792, 10'd796,
        10'd865, 10'd868, 10'd872, 10'd876, 10'd929, 10'd932, 10'd936, 10'd940, 10'd977, 10'd980, 10'd984, 10'd988, 10'd1009, 10'd1012, 10'd1016, 10'd1020,
        10'd451, 10'd455, 10'd459, 10'd462, 10'd579, 10'd583, 10'd587, 10'd590, 10'd691, 10'd695, 10'd699, 10'd702, 10'd787, 10'd791, 10'd795, 10'd798,
        10'd867, 10'd871, 10'd875, 10'd878, 10'd931, 10'd935, 10'd939, 10'd942, 10'd979, 10'd983, 10'd987, 10'd990, 10'd1011, 10'd1015, 10'd1019, 10'd1022,
        10'd454, 10'd458, 10'd461, 10'd463, 10'd582, 10'd586, 10'd589, 10'd591, 10'd694, 10'd698, 10'd701, 10'd703, 10'd790, 10'd794, 10'd797, 10'd799,
        10'd870, 10'd874, 10'd877, 10'd879, 10'd934, 10'd938, 10'd941, 10'd943, 10'd982, 10'd986, 10'd989, 10'd991, 10'd1014, 10'd1018, 10'd1021, 10'd1023};

    scan_order_sz16x16 = {10'd0, 10'd2, 10'd5, 10'd9, 10'd32, 10'd34, 10'd37, 10'd41, 10'd80, 10'd82, 10'd85, 10'd89, 10'd144, 10'd146, 10'd149, 10'd153,
        10'd1, 10'd4, 10'd8, 10'd12, 10'd33, 10'd36, 10'd40, 10'd44, 10'd81, 10'd84, 10'd88, 10'd92, 10'd145, 10'd148, 10'd152, 10'd156,
        10'd3, 10'd7, 10'd11, 10'd14, 10'd35, 10'd39, 10'd43, 10'd46, 10'd83, 10'd87, 10'd91, 10'd94, 10'd147, 10'd151, 10'd155, 10'd158,
        10'd6, 10'd10, 10'd13, 10'd15, 10'd38, 10'd42, 10'd45, 10'd47, 10'd86, 10'd90, 10'd93, 10'd95, 10'd150, 10'd154, 10'd157, 10'd159,
        10'd16, 10'd18, 10'd21, 10'd25, 10'd64, 10'd66, 10'd69, 10'd73, 10'd128, 10'd130, 10'd133, 10'd137, 10'd192, 10'd194, 10'd197, 10'd201,
        10'd17, 10'd20, 10'd24, 10'd28, 10'd65, 10'd68, 10'd72, 10'd76, 10'd129, 10'd132, 10'd136, 10'd140, 10'd193, 10'd196, 10'd200, 10'd204,
        10'd19, 10'd23, 10'd27, 10'd30, 10'd67, 10'd71, 10'd75, 10'd78, 10'd131, 10'd135, 10'd139, 10'd142, 10'd195, 10'd199, 10'd203, 10'd206,
        10'd22, 10'd26, 10'd29, 10'd31, 10'd70, 10'd74, 10'd77, 10'd79, 10'd134, 10'd138, 10'd141, 10'd143, 10'd198, 10'd202, 10'd205, 10'd207,
        10'd48, 10'd50, 10'd53, 10'd57, 10'd112, 10'd114, 10'd117, 10'd121, 10'd176, 10'd178, 10'd181, 10'd185, 10'd224, 10'd226, 10'd229, 10'd233,
        10'd49, 10'd52, 10'd56, 10'd60, 10'd113, 10'd116, 10'd120, 10'd124, 10'd177, 10'd180, 10'd184, 10'd188, 10'd225, 10'd228, 10'd232, 10'd236,
        10'd51, 10'd55, 10'd59, 10'd62, 10'd115, 10'd119, 10'd123, 10'd126, 10'd179, 10'd183, 10'd187, 10'd190, 10'd227, 10'd231, 10'd235, 10'd238,
        10'd54, 10'd58, 10'd61, 10'd63, 10'd118, 10'd122, 10'd125, 10'd127, 10'd182, 10'd186, 10'd189, 10'd191, 10'd230, 10'd234, 10'd237, 10'd239,
        10'd96, 10'd98, 10'd101, 10'd105, 10'd160, 10'd162, 10'd165, 10'd169, 10'd208, 10'd210, 10'd213, 10'd217, 10'd240, 10'd242, 10'd245, 10'd249,
        10'd97, 10'd100, 10'd104, 10'd108, 10'd161, 10'd164, 10'd168, 10'd172, 10'd209, 10'd212, 10'd216, 10'd220, 10'd241, 10'd244, 10'd248, 10'd252,
        10'd99, 10'd103, 10'd107, 10'd110, 10'd163, 10'd167, 10'd171, 10'd174, 10'd211, 10'd215, 10'd219, 10'd222, 10'd243, 10'd247, 10'd251, 10'd254,
        10'd102, 10'd106, 10'd109, 10'd111, 10'd166, 10'd170, 10'd173, 10'd175, 10'd214, 10'd218, 10'd221, 10'd223, 10'd246, 10'd250, 10'd253, 10'd255};

    scan_order_sz8x8_4x4 = {10'd0, 10'd2, 10'd5, 10'd9, 10'd0, 10'd0, 10'd0, 10'd0, 10'd1, 10'd4, 10'd8, 10'd12, 10'd0, 10'd0, 10'd0, 10'd0,
        10'd3, 10'd7, 10'd11, 10'd14, 10'd0, 10'd0, 10'd0, 10'd0, 10'd6, 10'd10, 10'd13, 10'd15, 10'd0, 10'd0, 10'd0, 10'd0,
        10'd0, 10'd0, 10'd0, 10'd0, 10'd0, 10'd0, 10'd0, 10'd0, 10'd0, 10'd0, 10'd0, 10'd0, 10'd0, 10'd0, 10'd0, 10'd0,
        10'd0, 10'd0, 10'd0, 10'd0, 10'd0, 10'd0, 10'd0, 10'd0, 10'd0, 10'd0, 10'd0, 10'd0, 10'd0, 10'd0, 10'd0, 10'd0,
        10'd0, 10'd2, 10'd5, 10'd9, 10'd32, 10'd34, 10'd37, 10'd41, 10'd1, 10'd4, 10'd8, 10'd12, 10'd33, 10'd36, 10'd40, 10'd44,
        10'd3, 10'd7, 10'd11, 10'd14, 10'd35, 10'd39, 10'd43, 10'd46, 10'd6, 10'd10, 10'd13, 10'd15, 10'd38, 10'd42, 10'd45, 10'd47,
        10'd16, 10'd18, 10'd21, 10'd25, 10'd48, 10'd50, 10'd53, 10'd57, 10'd17, 10'd20, 10'd24, 10'd28, 10'd49, 10'd52, 10'd56, 10'd60,
        10'd19, 10'd23, 10'd27, 10'd30, 10'd51, 10'd55, 10'd59, 10'd62, 10'd22, 10'd26, 10'd29, 10'd31, 10'd54, 10'd58, 10'd61, 10'd63,
        10'd0, 10'd1, 10'd2, 10'd3, 10'd0, 10'd0, 10'd0, 10'd0, 10'd4, 10'd5, 10'd6, 10'd7, 10'd0, 10'd0, 10'd0, 10'd0,
        10'd8, 10'd9, 10'd10, 10'd11, 10'd0, 10'd0, 10'd0, 10'd0, 10'd12, 10'd13, 10'd14, 10'd15, 10'd0, 10'd0, 10'd0, 10'd0,
        10'd0, 10'd0, 10'd0, 10'd0, 10'd0, 10'd0, 10'd0, 10'd0, 10'd0, 10'd0, 10'd0, 10'd0, 10'd0, 10'd0, 10'd0, 10'd0,
        10'd0, 10'd0, 10'd0, 10'd0, 10'd0, 10'd0, 10'd0, 10'd0, 10'd0, 10'd0, 10'd0, 10'd0, 10'd0, 10'd0, 10'd0, 10'd0,
        10'd0, 10'd1, 10'd2, 10'd3, 10'd16, 10'd17, 10'd18, 10'd19, 10'd4, 10'd5, 10'd6, 10'd7, 10'd20, 10'd21, 10'd22, 10'd23,
        10'd8, 10'd9, 10'd10, 10'd11, 10'd24, 10'd25, 10'd26, 10'd27, 10'd12, 10'd13, 10'd14, 10'd15, 10'd28, 10'd29, 10'd30, 10'd31,
        10'd32, 10'd33, 10'd34, 10'd35, 10'd48, 10'd49, 10'd50, 10'd51, 10'd36, 10'd37, 10'd38, 10'd39, 10'd52, 10'd53, 10'd54, 10'd55,
        10'd40, 10'd41, 10'd42, 10'd43, 10'd56, 10'd57, 10'd58, 10'd59, 10'd44, 10'd45, 10'd46, 10'd47, 10'd60, 10'd61, 10'd62, 10'd63,
        10'd0, 10'd1, 10'd2, 10'd3, 10'd0, 10'd0, 10'd0, 10'd0, 10'd4, 10'd5, 10'd6, 10'd7, 10'd0, 10'd0, 10'd0, 10'd0,
        10'd8, 10'd9, 10'd10, 10'd11, 10'd0, 10'd0, 10'd0, 10'd0, 10'd12, 10'd13, 10'd14, 10'd15, 10'd0, 10'd0, 10'd0, 10'd0,
        10'd0, 10'd0, 10'd0, 10'd0, 10'd0, 10'd0, 10'd0, 10'd0, 10'd0, 10'd0, 10'd0, 10'd0, 10'd0, 10'd0, 10'd0, 10'd0,
        10'd0, 10'd0, 10'd0, 10'd0, 10'd0, 10'd0, 10'd0, 10'd0, 10'd0, 10'd0, 10'd0, 10'd0, 10'd0, 10'd0, 10'd0, 10'd0,
        10'd0, 10'd1, 10'd2, 10'd3, 10'd16, 10'd17, 10'd18, 10'd19, 10'd4, 10'd5, 10'd6, 10'd7, 10'd20, 10'd21, 10'd22, 10'd23,
        10'd8, 10'd9, 10'd10, 10'd11, 10'd24, 10'd25, 10'd26, 10'd27, 10'd12, 10'd13, 10'd14, 10'd15, 10'd28, 10'd29, 10'd30, 10'd31,
        10'd32, 10'd33, 10'd34, 10'd35, 10'd48, 10'd49, 10'd50, 10'd51, 10'd36, 10'd37, 10'd38, 10'd39, 10'd52, 10'd53, 10'd54, 10'd55,
        10'd40, 10'd41, 10'd42, 10'd43, 10'd56, 10'd57, 10'd58, 10'd59, 10'd44, 10'd45, 10'd46, 10'd47, 10'd60, 10'd61, 10'd62, 10'd63};
end


reg     [3:0]       numGreater1Flag         ;
reg     [4:0]       firstSigScanPos         ;
reg     [4:0]       lastSigScanPos          ;
reg     [4:0]       lastGreater1ScanPos     ; //顾名思义，最后1个大于1的系数所在的位置，也就是从后开始扫，最先扫到的第一个大于1的系数
reg     [3:0]       lastGreater1ScanPos_1   ; //在sig_coeff_indices[]中的index

reg     [1:0]       ctxSet                  ;
reg     [1:0]       ctxSet_r                ;
reg     [1:0]       greater1Ctx             ;

wire                signHidden              ;
reg                 sign_hidden_r           ;
reg     [7:0]       sumAbsLevel             ; //仅仅需要用到是否奇偶1bit足够
reg     [2:0]       cRiceParam              ;
reg     [6:0]       abs_lvl_first_sig       ;
reg     [1:0]       first_sig_xp            ;
reg     [1:0]       first_sig_yp            ;

reg     [2:0]       c_rice_param_nxt                       ;
reg     [2:0]       lvl_rem_suf_max_bins_minus1            ;

reg     [7:0]       abs_lvl_thresh                         ; //cAbsLevel大于此值cRiceParam加1,3<<cRiceParam
reg     [7:0]       abs_lvl_thresh_minus1                  ;
reg     [7:0]       abs_lvl_thresh_minus2                  ;
reg     [7:0]       abs_lvl_thresh_minus3                  ;
reg                 cond_abs_lvl_gt_thresh_prev_bin0       ;
reg                 cond_abs_lvl_gt_thresh_minus1_prev_bin0;
reg                 cond_abs_lvl_gt_thresh_prev_bin1       ;
reg                 cond_abs_lvl_gt_thresh_minus1_prev_bin1;
reg                 lvl_rem_suf_prev_bin                   ;

reg     [1:0]       baseLevel[0:15]         ; //每个sig coeff一个
reg     [1:0]       sig_coeff_xp[0:15]      ;
reg     [1:0]       sig_coeff_yp[0:15]      ;
reg     [1:0]       sig_coeff_sign[0:15]    ;

reg     [7:0]       cAbsLevel               ;
reg     [7:0]       base_lvl                ;
reg     [7:0]       abs_lvl_pre_lt3         ;
reg     [7:0]       abs_lvl_pre_ge3         ;
reg     [7:0]       abs_lvl_pre             ;

reg     [3:0]       prefix_lvl_rem          ; //todo位宽
reg     [3:0]       prefix_lvl_rem_pls1     ;
reg     [3:0]       prefix_lvl_rem_minus2   ;
reg     [5:0]       suffix_lvl_rem          ; //todo位宽
wire    [7:0]       abs_lvl                 ;

assign abs_lvl = abs_lvl_pre + (suffix_lvl_rem<<1)+i_bin_byp;


reg                  coeff_luma_sel         ;
reg                  coeff_cb_sel           ;
reg                  coeff_cr_sel           ;
reg                  component              ; //0=cb,1=cr


reg     [5:0]        qp_cb                  ;
reg     [5:0]        qp_cr                  ;


function [5:0] f_get_qpc;
 input              [ 5: 0]   qpY;
 input signed       [ 5: 0]   offset;
 reg                [ 5: 0]   qpi;
    begin
        qpi = qpY + offset;
        if (qpi > 57)
            qpi = 57;
         case (qpi)
          0: f_get_qpc = 0;
          1: f_get_qpc = 1;
          2: f_get_qpc = 2;
          3: f_get_qpc = 3;
          4: f_get_qpc = 4;
          5: f_get_qpc = 5;
          6: f_get_qpc = 6;
          7: f_get_qpc = 7;
          8: f_get_qpc = 8;
          9: f_get_qpc = 9;
          10: f_get_qpc = 10;
          11: f_get_qpc = 11;
          12: f_get_qpc = 12;
          13: f_get_qpc = 13;
          14: f_get_qpc = 14;
          15: f_get_qpc = 15;
          16: f_get_qpc = 16;
          17: f_get_qpc = 17;
          18: f_get_qpc = 18;
          19: f_get_qpc = 19;
          20: f_get_qpc = 20;
          21: f_get_qpc = 21;
          22: f_get_qpc = 22;
          23: f_get_qpc = 23;
          24: f_get_qpc = 24;
          25: f_get_qpc = 25;
          26: f_get_qpc = 26;
          27: f_get_qpc = 27;
          28: f_get_qpc = 28;
          29: f_get_qpc = 29;
          30: f_get_qpc = 29;
          31: f_get_qpc = 30;
          32: f_get_qpc = 31;
          33: f_get_qpc = 32;
          34: f_get_qpc = 33;
          35: f_get_qpc = 33;
          36: f_get_qpc = 34;
          37: f_get_qpc = 34;
          38: f_get_qpc = 35;
          39: f_get_qpc = 35;
          40: f_get_qpc = 36;
          41: f_get_qpc = 36;
          42: f_get_qpc = 37;
          43: f_get_qpc = 37;
          44: f_get_qpc = 38;
          45: f_get_qpc = 39;
          46: f_get_qpc = 40;
          47: f_get_qpc = 41;
          48: f_get_qpc = 42;
          49: f_get_qpc = 43;
          50: f_get_qpc = 44;
          51: f_get_qpc = 45;
          52: f_get_qpc = 46;
          53: f_get_qpc = 47;
          54: f_get_qpc = 48;
          55: f_get_qpc = 49;
          56: f_get_qpc = 50;
          57: f_get_qpc = 51;
         endcase
    end
endfunction

always @ (posedge clk)
begin
    qp_cb  <= f_get_qpc(o_QpY, i_qp_cb_offset);
    qp_cr  <= f_get_qpc(o_QpY, i_qp_cr_offset);
end

//decode 32x32=1024
reg                  bram_coeff_luma_dec_we;
reg      [ 9:0]      bram_coeff_luma_dec_addr;
reg      [ 7:0]      bram_coeff_luma_dec_din;
wire     [ 7:0]      bram_coeff_luma_0_dout;

//transform
wire     [ 9:0]      bram_coeff_luma_trafo_addr;
wire     [ 7:0]      bram_coeff_luma_1_dout;

wire     [ 7:0]      bram_coeff_luma_trafo_dout;

assign bram_coeff_luma_trafo_dout = coeff_luma_sel ? bram_coeff_luma_0_dout : bram_coeff_luma_1_dout;

ram #(10, 8) bram_coeff_luma_0
(
     .clk(clk),
     .en(1'b1),
     .we(coeff_luma_sel?1'b0:bram_coeff_luma_dec_we),
     .addr(coeff_luma_sel?bram_coeff_luma_trafo_addr:bram_coeff_luma_dec_addr),
     .data_in(bram_coeff_luma_dec_din),
     .data_out(bram_coeff_luma_0_dout)
);


ram #(10, 8) bram_coeff_luma_1
(
     .clk(clk),
     .en(1'b1),
     .we(coeff_luma_sel?bram_coeff_luma_dec_we:1'b0),
     .addr(coeff_luma_sel?bram_coeff_luma_dec_addr:bram_coeff_luma_trafo_addr),
     .data_in(bram_coeff_luma_dec_din),
     .data_out(bram_coeff_luma_1_dout)
);


reg   debug_flag1;

always @ (posedge clk)
if (rst) begin
    debug_flag1          <= 1;

end else begin
    if (debug_flag1==1) begin
        if (bram_coeff_luma_dec_addr==384&&bram_coeff_luma_dec_we==1&&
            x0==0&&y0==128) begin
            $display("%t found",$time);
            debug_flag1  <= 0;
        end

    end

end


//decode
reg                    bram_coeff_cb_dec_we;
reg      [ 7:0]        bram_coeff_cb_dec_addr;
reg      [ 7:0]        bram_coeff_cb_dec_din;
wire     [ 7:0]        bram_coeff_cb_0_dout;

//transform
wire     [ 7:0]        bram_coeff_cb_trafo_addr;
wire     [ 7:0]        bram_coeff_cb_1_dout;

wire     [ 7:0]        bram_coeff_cb_trafo_dout;
assign bram_coeff_cb_trafo_dout = coeff_cb_sel ? bram_coeff_cb_0_dout : bram_coeff_cb_1_dout;

//16x16=256, 8bit
ram #(8, 8) bram_coeff_cb_0
(
     .clk(clk),
     .en(1'b1),
     .we(coeff_cb_sel?1'b0:bram_coeff_cb_dec_we),
     .addr(coeff_cb_sel?bram_coeff_cb_trafo_addr:bram_coeff_cb_dec_addr),
     .data_in(bram_coeff_cb_dec_din),
     .data_out(bram_coeff_cb_0_dout)
);


ram #(8, 8) bram_coeff_cb_1
(
     .clk(clk),
     .en(1'b1),
     .we(coeff_cb_sel?bram_coeff_cb_dec_we:1'b0),
     .addr(coeff_cb_sel?bram_coeff_cb_dec_addr:bram_coeff_cb_trafo_addr),
     .data_in(bram_coeff_cb_dec_din),
     .data_out(bram_coeff_cb_1_dout)
);

//decode
reg                     bram_coeff_cr_dec_we;
reg      [ 7:0]         bram_coeff_cr_dec_addr;
reg      [ 7:0]         bram_coeff_cr_dec_din;
wire     [ 7:0]         bram_coeff_cr_0_dout;

//transform
wire     [ 7:0]         bram_coeff_cr_trafo_addr;
wire     [ 7:0]         bram_coeff_cr_1_dout;

wire     [ 7:0]         bram_coeff_cr_trafo_dout;
assign bram_coeff_cr_trafo_dout = coeff_cr_sel ? bram_coeff_cr_0_dout : bram_coeff_cr_1_dout;

ram #(8, 8) bram_coeff_cr_0
(
     .clk(clk),
     .en(1'b1),
     .we(coeff_cr_sel?1'b0:bram_coeff_cr_dec_we),
     .addr(coeff_cr_sel?bram_coeff_cr_trafo_addr:bram_coeff_cr_dec_addr),
     .data_in(bram_coeff_cr_dec_din),
     .data_out(bram_coeff_cr_0_dout)
);


ram #(8, 8) bram_coeff_cr_1
(
     .clk(clk),
     .en(1'b1),
     .we(coeff_cr_sel?bram_coeff_cr_dec_we:1'b0),
     .addr(coeff_cr_sel?bram_coeff_cr_dec_addr:bram_coeff_cr_trafo_addr),
     .data_in(bram_coeff_cr_dec_din),
     .data_out(bram_coeff_cr_1_dout)
);



//初始lastSigScanPos=-1,firstSigScanPos=16,(lastSigScanPos - firstSigScanPos) > 3结果成立
assign signHidden = (lastSigScanPos - firstSigScanPos) > 3 && firstSigScanPos!=16 && !cu_transquant_bypass_flag;

always @(*)
begin
    //ctxSet gt1_flag,gt2_flag用到
    if ((i != lastSubBlock) && greater1Ctx == 0) begin
        ctxSet        = (i > 0 && o_cIdx == 0) ? 3 : 1;
    end else begin
        ctxSet        = (i > 0 && o_cIdx == 0) ? 2 : 0;
    end

end

reg                               set_qpy                ;

reg                               tq_luma_en             ;
reg                               tq_luma_rst            ;
reg                               tq_cb_en               ;
reg                               tq_cb_rst              ;
reg                               tq_cr_en               ;
reg                               tq_cr_rst              ;


reg signed        [31:0][5:0]     luma_y_lmt             ;
reg signed        [15:0][4:0]     cb_y_lmt               ;
reg signed        [15:0][4:0]     cr_y_lmt               ;

reg                     [4:0]     luma_x_lmt             ; //不可能为-1
reg                     [3:0]     cb_x_lmt               ;
reg                     [3:0]     cr_x_lmt               ;

reg signed              [5:0]     luma_y_lmt_tmp         ;
reg signed              [4:0]     chroma_y_lmt_tmp       ;
reg signed              [5:0]     luma_y_lmt_pos00_tmp   ;
reg signed              [4:0]     chroma_y_lmt_pos00_tmp ;

wire signed             [5:0]     luma_y_pos_signed      ;
wire signed             [4:0]     chroma_y_pos_signed    ;
wire signed             [5:0]     luma_y_pos00_signed    ;
wire signed             [4:0]     chroma_y_pos00_signed  ;

assign luma_y_pos_signed     = {1'b0,yS_r,yP_r};
assign luma_y_pos00_signed   = {1'b0,yS_r,2'b00};
assign chroma_y_pos_signed   = {1'b0,yS_r[1:0],yP_r};
assign chroma_y_pos00_signed = {1'b0,yS_r[1:0],2'b00};

always @ (posedge clk)
if (global_rst) begin
    o_tu_state                                  <= `tu_end;
    tq_luma_rst                                 <= 0;
    tq_cb_rst                                   <= 0;
    tq_cr_rst                                   <= 0;
    coeff_luma_sel                              <= 0;
    coeff_cb_sel                                <= 0;
    coeff_cr_sel                                <= 0;
    component                                   <= 0;
end else if (i_rst_slice) begin
    o_tu_state                                  <= `tu_end;
    tq_luma_rst                                 <= 0;
    tq_cb_rst                                   <= 0;
    tq_cr_rst                                   <= 0;
    o_dec_bin_en_xy_pref                        <= 0;
    o_byp_dec_en_tu                             <= 0;
    o_dec_bin_en_sig                            <= 0;
    o_dec_bin_en_gt1_etc                        <= 0;
    o_cm_idx_xy_pref                            <= 255; //invalid idx
    o_cm_idx_sig                                <= 255; //invalid idx
    o_cm_idx_gt1_etc                            <= 255; //invalid idx
end else if (rst) begin
    o_tu_state                                  <= 0;
    o_dec_bin_en_xy_pref                        <= 0;
    o_byp_dec_en_tu                             <= 0;
    o_dec_bin_en_sig                            <= 0;
    o_dec_bin_en_gt1_etc                        <= 0;
    o_cm_idx_xy_pref                            <= 255; //invalid idx
    o_cm_idx_sig                                <= 255; //invalid idx
    o_cm_idx_gt1_etc                            <= 255; //invalid idx

    o_cIdx                                      <= 3;
    i                                           <= 0;
    binIdx                                      <= 0;
    x0                                          <= i_x0;
    y0                                          <= i_y0;
    xTu                                         <= i_xTu;
    yTu                                         <= i_yTu;
    CbSize                                      <= i_CbSize;
    trafoDepth                                  <= i_trafoDepth;
    log2TrafoSize                               <= i_log2TrafoSize;
    last_scx_pre_max_bins_minus1                <= (i_log2TrafoSize<<1)-2;
    last_scy_pre_max_bins_minus1                <= (i_log2TrafoSize<<1)-2;
    slice_num                                   <= i_slice_num;

    trafoSize                                   <= i_trafoSize;
    blkIdx                                      <= i_blkIdx;
    if (i_rqt_root_cbf==0||i_cu_skip_flag==1) begin
        cbf_cb                                  <= 0;
        cbf_cr                                  <= 0;
        o_cbf_luma                              <= 0;
    end else begin
        cbf_cb                                  <= i_cbf_cb;
        cbf_cr                                  <= i_cbf_cr;
    end

    cu_transquant_bypass_flag                   <= i_cu_transquant_bypass_flag;
    o_IsCuQpDeltaCoded                          <= i_IsCuQpDeltaCoded;

    coded_sub_block_flag                        <= 1'b0;
    coded_sub_block_flag_right                  <= '{8{1'b0}};
    coded_sub_block_flag_down                   <= '{8{1'b0}};
    set_qpy                                     <= 0;
    //没有编码，QpY也不会用到，也不需要更新，
    //有编码，cu为qg第一个cu，解完CuQpDelta之后QpY不需要再更新，cu为qg第二个以上cu，沿用第一个cu的QpY
    o_QpY                                       <= i_qPY;

    luma_x_lmt                                  <= 5'd0;
    luma_y_lmt                                  <= {32{6'b111111}};
    cb_x_lmt                                    <= 4'd0;
    cb_y_lmt                                    <= {16{5'b11111}};
    cr_x_lmt                                    <= 4'd0;
    cr_y_lmt                                    <= {16{5'b11111}};

end else begin
    if (en) begin
        case (o_tu_state)
            `cbf_luma_s://1
                if (i_dec_bin_valid) begin
                    o_cbf_luma                      <= i_bin_gt1_etc;
                    if (`log_i && slice_num>=`slice_begin && slice_num<=`slice_end)
                        $fdisplay(fd_log, "parse_cbf_luma ret %d ivlCurrRange %x ivlOffset %x",
                         i_bin_gt1_etc, i_ivlCurrRange, i_ivlOffset);

                    o_cm_idx_gt1_etc                <= `CM_IDX_DQP;
                    if (i_bin_gt1_etc || cbf_cb || cbf_cr) begin
                        if (i_cu_qp_delta_enabled_flag && ~i_IsCuQpDeltaCoded) begin
                            prefixVal               <= 0;
                            suffixVal               <= 0;

                            o_tu_state              <= `cu_qp_delta_abs_s_1;
                            o_IsCuQpDeltaCoded      <= 1;
                            set_qpy                 <= 1;
                        end else begin
                            o_dec_bin_en_gt1_etc    <= 0;
                            o_tu_state              <= `parse_residual_coding;
                        end
                    end else begin
                        //todo
                        o_dec_bin_en_gt1_etc        <= 0;
                        o_tu_state                  <= `parse_residual_coding; //cbf_luma,cbf_cb,cbf_cr三个都为0，也走parse_residual_coding
                    end
                end

            `cu_qp_delta_abs_s_1://3
                if (i_dec_bin_valid) begin
                    if (`log_i && slice_num>=`slice_begin && slice_num<=`slice_end)
                        $fdisplay(fd_log, "binVal %d ivlCurrRange %x ivlOffset %x",
                         i_bin_gt1_etc, i_ivlCurrRange, i_ivlOffset);

                    o_cm_idx_gt1_etc                <= `CM_IDX_DQP+1;
                    if (i_bin_gt1_etc)
                        prefixVal                   <= prefixVal + 1;

                    if (~i_bin_gt1_etc) begin
                        CuQpDeltaVal                <= prefixVal;
                        o_dec_bin_en_gt1_etc        <= 0;
                        if (prefixVal) begin
                            o_byp_dec_en_tu         <= 1;
                            o_tu_state              <= `cu_qp_delta_sign_flag_s;
                        end else begin
                            o_tu_state              <= `parse_residual_coding;
                        end
                        if (`log_i && slice_num>=`slice_begin && slice_num<=`slice_end)
                            $fdisplay(fd_log, "parse_cu_qp_delta_abs prefix %0d suffix %0d",
                             prefixVal, suffixVal);
                    end else if (prefixVal==4) begin
                        CuQpDeltaVal                <= 5;
                        k                           <= 0;
                        o_byp_dec_en_tu             <= 1;
                        o_dec_bin_en_gt1_etc        <= 0;
                        o_tu_state                  <= `cu_qp_delta_abs_s_2;
                    end

                end
            `cu_qp_delta_abs_s_2://4
                begin
                    if (`log_i && slice_num>=`slice_begin && slice_num<=`slice_end)
                        $fdisplay(fd_log, "bypass binVal %d ivlCurrRange %x ivlOffset %x",
                         i_bin_byp, i_ivlCurrRange, i_ivlOffset);

                    if (i_bin_byp) begin
                        suffixVal                   <= suffixVal + (1<<k);
                        k                           <= k+1;
                    end else begin
                        CuQpDeltaVal                <= CuQpDeltaVal + suffixVal;
                        if (k==0) begin
                            o_tu_state              <= `cu_qp_delta_sign_flag_s;
                            if (`log_i && slice_num>=`slice_begin && slice_num<=`slice_end)
                                $fdisplay(fd_log, "parse_cu_qp_delta_abs prefix %0d suffix %0d",
                                    prefixVal, suffixVal + (i_bin_byp<<k));
                        end else
                            o_tu_state              <= `cu_qp_delta_abs_s_3;
                    end
                end
            `cu_qp_delta_abs_s_3://5
                begin
                    if (`log_i && slice_num>=`slice_begin && slice_num<=`slice_end)
                        $fdisplay(fd_log, "bypass binVal %d ivlCurrRange %x ivlOffset %x",
                         i_bin_byp, i_ivlCurrRange, i_ivlOffset);

                    CuQpDeltaVal                    <= CuQpDeltaVal + (i_bin_byp<<k);
                    if (k > 0) begin
                        suffixVal                   <= suffixVal + (i_bin_byp<<k);
                        k                           <= k-1;
                    end else begin
                        if (`log_i && slice_num>=`slice_begin && slice_num<=`slice_end)
                            $fdisplay(fd_log, "parse_cu_qp_delta_abs prefix %0d suffix %0d",
                            prefixVal, suffixVal + (i_bin_byp<<k));

                        o_tu_state                  <= `cu_qp_delta_sign_flag_s;
                    end
                end

            `cu_qp_delta_sign_flag_s://6
                begin
                    o_byp_dec_en_tu                 <= 0;
                    if (i_bin_byp)
                        CuQpDeltaVal                <= ~CuQpDeltaVal+1;
                    o_tu_state                      <= `parse_residual_coding;
                end

            `transform_skip_flag_s:
                if (i_dec_bin_valid) begin
                    o_dec_bin_en_gt1_etc        <= 0;
                    o_dec_bin_en_xy_pref        <= 1;
                    transform_skip_flag         <= i_bin_gt1_etc;
                    if (`log_i && slice_num>=`slice_begin && slice_num<=`slice_end)
                        $fdisplay(fd_log, "parse_transform_skip_flag ret %d cIdx %d ivlCurrRange %x ivlOffset %x",
                         i_bin_gt1_etc,o_cIdx, i_ivlCurrRange,i_ivlOffset);

                    o_cm_idx_xy_pref            <= `CM_IDX_LAST_SIG_COEFF_X_PREFIX+ctxOffset;
                    o_tu_state                  <= `last_sig_coeff_x_prefix_s;
                    last_sig_coeff_x_prefix     <= 0;
                end

            `last_sig_coeff_x_prefix_s://9
                if (i_dec_bin_valid) begin

                    o_cm_idx_xy_pref                     <= `CM_IDX_LAST_SIG_COEFF_X_PREFIX+last_scx_pre_ctx_inc;
                    if (binIdx==0) begin
                        if (`log_i&& slice_num>=`slice_begin && slice_num<=`slice_end) begin
                            $fdisplay(fd_log, "+parse_residual_coding cIdx %0d log2TrafoSize %0d x0 %0d y0 %0d blkIdx %0d scanIdx %0d",
                             o_cIdx, log2TrafoSize, {x0[`max_x_bits-1:6],xTu}, {y0[`max_x_bits-1:6],yTu}, blkIdx, scanIdx);
                        end
                        firstSigScanPos                  <= 16;
                        lastSigScanPos                   <= -1;
                        numGreater1Flag                  <= 0;
                        lastGreater1ScanPos              <= -1;
                        greater1Ctx                      <= 1; //parse_residual_coding函数初始为1
                        inferSbDcSigCoeffFlag            <= 0;
                    end
                    if (`log_i && slice_num>=`slice_begin && slice_num<=`slice_end)
                        $fdisplay(fd_log, "ctxInc %0d ivlCurrRange %x ivlOffset %x",
                         o_cm_idx_xy_pref-`CM_IDX_LAST_SIG_COEFF_X_PREFIX, i_ivlCurrRange, i_ivlOffset);

                    binIdx                               <= binIdx+1;
                    if (i_bin_xy_pref) begin
                        last_sig_coeff_x_prefix          <= last_scx_pre_pls1;

                        if (binIdx == last_scx_pre_max_bins_minus1) begin
                            last_sig_coeff_y_prefix      <= 0;
                            binIdx                       <= 0;
                            o_tu_state                   <= `last_sig_coeff_y_prefix_ctx;
                            o_dec_bin_en_xy_pref         <= 0;
                        end
                    end else begin
                        last_sig_coeff_y_prefix          <= 0;
                        binIdx                           <= 0;
                        o_tu_state                       <= `last_sig_coeff_y_prefix_ctx;
                        o_dec_bin_en_xy_pref             <= 0;
                    end
                end else begin
                    last_scx_pre_ctx_inc                 <= ((binIdx+1)>>ctxShift)+ctxOffset;
                    last_scx_pre_pls1                    <= last_sig_coeff_x_prefix + 1;
                end

            `last_sig_coeff_y_prefix_ctx://0x19
                begin
                    o_cm_idx_xy_pref                     <= `CM_IDX_LAST_SIG_COEFF_Y_PREFIX+ctxOffset;
                    o_tu_state                           <= `last_sig_coeff_y_prefix_s;
                    cond_last_scx_pre_gt3                <= last_sig_coeff_x_prefix > 3 ? 1 : 0;
                    last_scx_suf_max_bins_minus1         <= last_sig_coeff_x_prefix[4:1] - 2;
                    o_dec_bin_en_xy_pref                 <= 1;
                end

            `last_sig_coeff_y_prefix_s://0xa
                if (i_dec_bin_valid) begin
                    if (`log_i && slice_num>=`slice_begin && slice_num<=`slice_end) begin
                        if (binIdx == 0)
                            $fdisplay(fd_log, "parse_last_sig_coeff_x_prefix %0d", last_sig_coeff_x_prefix);

                        $fdisplay(fd_log, "ctxInc %0d ivlCurrRange %x ivlOffset %x",
                        o_cm_idx_xy_pref-`CM_IDX_LAST_SIG_COEFF_Y_PREFIX, i_ivlCurrRange, i_ivlOffset);
                    end

                    binIdx                               <= binIdx+1;
                    o_cm_idx_xy_pref                     <= `CM_IDX_LAST_SIG_COEFF_Y_PREFIX+last_scy_pre_ctx_inc;
                    if (i_bin_xy_pref) begin
                        last_sig_coeff_y_prefix          <= last_scy_pre_pls1;
                        last_scy_suf_max_bins_minus1     <= last_scy_pre_pls1[4:1] - 2;
                        //这2个可以提到外面,如果状态走到解suffix，解suffix时会修正这2个值
                        LastSignificantCoeffX            <= last_sig_coeff_x_prefix;
                        LastSignificantCoeffY            <= last_scy_pre_pls1;

                        if (binIdx == last_scy_pre_max_bins_minus1) begin
                            if (`log_i && slice_num>=`slice_begin && slice_num<=`slice_end)
                                $fdisplay(fd_log, "parse_last_sig_coeff_y_prefix %0d",
                                 last_sig_coeff_y_prefix+1);

                            binIdx                       <= 0;
                            o_dec_bin_en_xy_pref         <= 0;
                            if (cond_last_scx_pre_gt3) begin
                                o_byp_dec_en_tu          <= 1;
                                last_sig_coeff_x_suffix  <= 0;
                                o_tu_state               <= `last_sig_coeff_x_suffix_s;
                            end else if (cond_last_scy_pre_gt2) begin

                                o_byp_dec_en_tu          <= 1;
                                last_sig_coeff_y_suffix  <= 0;
                                o_tu_state               <= `last_sig_coeff_y_suffix_s;
                            end else begin

                                o_tu_state               <= `get_last_sub_block_scan_pos_1;
                            end
                        end
                    end else begin
                        if (`log_i && slice_num>=`slice_begin && slice_num<=`slice_end)
                            $fdisplay(fd_log, "parse_last_sig_coeff_y_prefix %0d",
                             last_sig_coeff_y_prefix);
                        LastSignificantCoeffX            <= last_sig_coeff_x_prefix;
                        LastSignificantCoeffY            <= last_sig_coeff_y_prefix;
                        binIdx                           <= 0;
                        o_dec_bin_en_xy_pref             <= 0;
                        if (cond_last_scx_pre_gt3) begin
                            o_byp_dec_en_tu              <= 1;
                            last_sig_coeff_x_suffix      <= 0;
                            o_tu_state                   <= `last_sig_coeff_x_suffix_s;
                        end else if (cond_last_scy_pre_gt3) begin
                            o_byp_dec_en_tu              <= 1;
                            last_sig_coeff_y_suffix      <= 0;
                            o_tu_state                   <= `last_sig_coeff_y_suffix_s;
                        end else begin
                            o_tu_state                   <= `get_last_sub_block_scan_pos_1;
                        end
                    end
                end else begin
                   last_scy_pre_ctx_inc                  <= ((binIdx+1)>>ctxShift)+ctxOffset;
                   cond_last_scy_pre_gt3                 <= last_sig_coeff_y_prefix > 3 ? 1:0;
                   cond_last_scy_pre_gt2                 <= last_sig_coeff_y_prefix > 2 ? 1:0;

                   last_scy_pre_pls1                     <= last_sig_coeff_y_prefix+1;
                end

            `last_sig_coeff_x_suffix_s://b
                begin
                    if (`log_i && slice_num>=`slice_begin && slice_num<=`slice_end)
                        $fdisplay(fd_log, "bypass binVal %d ivlCurrRange %x ivlOffset %x",
                         i_bin_byp, i_ivlCurrRange, i_ivlOffset);

                    binIdx                               <= binIdx+1;
                    last_sig_coeff_x_suffix              <= {last_sig_coeff_x_suffix[3:0],i_bin_byp};

                    if (last_sig_coeff_x_prefix[0]) begin

                        LastSignificantCoeffX            <= ((1<<(last_sig_coeff_x_prefix[4:1]-1))<<1)+
                                                              (1<<(last_sig_coeff_x_prefix[4:1]-1))+
                                                              {last_sig_coeff_x_suffix[3:0],i_bin_byp};

                    end else begin
                        LastSignificantCoeffX            <= ((1<<(last_sig_coeff_x_prefix[4:1]-1))<<1)+
                                                              {last_sig_coeff_x_suffix[3:0],i_bin_byp};

                    end

                    if (binIdx == last_scx_suf_max_bins_minus1) begin

                        if (`log_i && slice_num>=`slice_begin && slice_num<=`slice_end)
                            $fdisplay(fd_log, "parse_last_sig_coeff_suffix %0d",
                             {last_sig_coeff_x_suffix[3:0],i_bin_byp});

                        binIdx                              <= 0;
                        if (cond_last_scy_pre_gt3) begin
                            o_byp_dec_en_tu                 <= 1;
                            last_sig_coeff_y_suffix         <= 0;
                            o_tu_state                      <= `last_sig_coeff_y_suffix_s;
                        end else begin
                            LastSignificantCoeffY           <= last_sig_coeff_y_prefix;
                            o_byp_dec_en_tu                 <= 0;
                            o_tu_state                      <= `get_last_sub_block_scan_pos_1;
                        end
                    end
                end

            `last_sig_coeff_y_suffix_s://c
                begin
                    if (`log_i && slice_num>=`slice_begin && slice_num<=`slice_end)
                        $fdisplay(fd_log, "bypass binVal %d ivlCurrRange %x ivlOffset %x",
                         i_bin_byp, i_ivlCurrRange, i_ivlOffset);

                    binIdx                                  <= binIdx+1;
                    last_sig_coeff_y_suffix                 <= {last_sig_coeff_y_suffix[3:0],i_bin_byp};
                    if (~last_sig_coeff_y_prefix[0]) begin
                        LastSignificantCoeffY               <= ((1<<(last_sig_coeff_y_prefix[4:1]-1))<<1)+
                                                               {last_sig_coeff_y_suffix[3:0],i_bin_byp};
                    end else begin
                        LastSignificantCoeffY               <= ((1<<(last_sig_coeff_y_prefix[4:1]-1))<<1)+
                                                                (1<<(last_sig_coeff_y_prefix[4:1]-1))+
                                                                {last_sig_coeff_y_suffix[3:0],i_bin_byp};

                    end
                    if (binIdx == last_scy_suf_max_bins_minus1) begin

                        if (`log_i && slice_num>=`slice_begin && slice_num<=`slice_end)
                            $fdisplay(fd_log, "parse_last_sig_coeff_suffix %0d",
                             {last_sig_coeff_y_suffix[3:0],i_bin_byp});

                        o_byp_dec_en_tu                     <= 0;
                        o_tu_state                          <= `get_last_sub_block_scan_pos_1;
                    end
                end

            `coded_sub_block_flag_s://f
                if (i_dec_bin_valid) begin
                    if (`log_i && slice_num>=`slice_begin && slice_num<=`slice_end)
                        $fdisplay(fd_log, "parse_coded_sub_block_flag %0d cIdx %0d ctxIdx %0d ivlCurrRange %x ivlOffset %x",
                         i_bin_gt1_etc,o_cIdx, o_cm_idx_gt1_etc-`CM_IDX_CODED_SUB_BLOCK_FLAG,i_ivlCurrRange,i_ivlOffset);

                    //sigCtx_r在next_sub_block里存的
                    if (o_cIdx == 0)
                        o_cm_idx_sig                       <= `CM_IDX_SIG_FLAG + sigCtx_r;
                    else
                        o_cm_idx_sig                       <= `CM_IDX_SIG_FLAG + sigCtx_r + 27;
                    o_dec_bin_en_gt1_etc                   <= 0;
                    if (i_bin_gt1_etc) begin
                        coded_sub_block_flag_down[xS]      <= 1;
                        coded_sub_block_flag_right[yS]     <= 1;
                        n                                  <= 15;
                        sig_coeff_cnt                      <= 0;
                        sig_coeff_cnt_pls1                 <= 1;
                        o_dec_bin_en_sig                   <= 1;
                        ctxSet_r                           <= ctxSet;
                        greater1Ctx                        <= 1;
                        o_tu_state                         <= `sig_coeff_flag_s;

                    end else begin
                        coded_sub_block_flag_down[xS]      <= 0;
                        coded_sub_block_flag_right[yS]     <= 0;
                        clr_i                              <= 0;
                        o_tu_state                         <= `clr_sub_block_bram;
                    end
                end else begin
                    
                end

            `sig_coeff_flag_s://0x10
                if (i_dec_bin_valid) begin
                    if (`log_i && slice_num>=`slice_begin && slice_num<=`slice_end)
                        $fdisplay(fd_log, "parse_sig_coeff_flag ret %0d ctxInc %0d n %0d ivlCurrRange %x ivlOffset %x",
                         i_bin_sig,
                         o_cm_idx_sig-`CM_IDX_SIG_FLAG,n, i_ivlCurrRange, i_ivlOffset);

                    n                                      <= n-1;
                    if (i_bin_sig) begin
                        sig_coeff_indices[sig_coeff_cnt]   <= n; //n在`coded_sub_block_flag_s和!dec_bin_valid已减1,todo 15+1=0
                        baseLevel[sig_coeff_cnt]           <= 1;

                        sig_coeff_xp[sig_coeff_cnt]        <= xP_r;
                        sig_coeff_yp[sig_coeff_cnt]        <= yP_r;
                        sig_coeff_cnt                      <= sig_coeff_cnt_pls1;
                        sig_coeff_cnt_pls1                 <= sig_coeff_cnt_pls1 + 1;
                        sig_coeff_cnt_minus1               <= sig_coeff_cnt;
                        inferSbDcSigCoeffFlag              <= 0;
                        firstSigScanPos                    <= n; //不断更新，最后一次更新的为正确的
                        abs_lvl_first_sig                  <= 1;
                        first_sig_xp                       <= xP_r;
                        first_sig_yp                       <= yP_r;
                        if (o_cIdx == 0) begin
                            if ({xS_r,xP_r} > luma_x_lmt)
                                luma_x_lmt                 <= {xS_r,xP_r};
                            if (luma_y_lmt_tmp<luma_y_pos_signed )
                                luma_y_lmt[{xS_r,xP_r}]    <= luma_y_pos_signed;
                        end else if (o_cIdx == 1) begin
                            if ({xS_r[1:0],xP_r} > cb_x_lmt)
                                cb_x_lmt                   <= {xS_r[1:0],xP_r};
                            if (chroma_y_lmt_tmp<chroma_y_pos_signed)
                                cb_y_lmt[{xS_r[1:0],xP_r}] <= chroma_y_pos_signed;
                        end else begin
                            if ({xS_r[1:0],xP_r} > cr_x_lmt)
                                cr_x_lmt                   <= {xS_r[1:0],xP_r};
                            if (chroma_y_lmt_tmp<chroma_y_pos_signed)
                                cr_y_lmt[{xS_r[1:0],xP_r}] <= chroma_y_pos_signed;
                        end

                    end
                    //只要有1个sig coeff，就会经过`coeff_abs_level_greater1_flag_s,
                    //只有1个sig coeff，并且signHidden,这是不可能的，
                    //signHidden必须lastSigScanPos-firstSigScanPos>3，所以肯定有两个以上sig coeff，mark7
                    //所以只要有1个sig coeff，必定经过`coeff_sign_flag_s
                    if (~i_bin_sig) begin //可以去掉减少路径，非0在`coeff_sign_flag_s里存
                        if (o_cIdx == 0) begin
                            bram_coeff_luma_dec_we            <= 1;
                            bram_coeff_luma_dec_addr          <= {yS_r,yP_r,xS_r,xP_r};
                            bram_coeff_luma_dec_din           <= 0;
                        end else if (o_cIdx == 1) begin
                            bram_coeff_cb_dec_we              <= 1;
                            bram_coeff_cb_dec_addr            <= {yS_r[1:0],yP_r,xS_r[1:0],xP_r};
                            bram_coeff_cb_dec_din             <= 0;
                        end else begin
                            bram_coeff_cr_dec_we              <= 1;
                            bram_coeff_cr_dec_addr            <= {yS_r[1:0],yP_r,xS_r[1:0],xP_r};
                            bram_coeff_cr_dec_din             <= 0;
                        end
                    end

                    if (n == 1 && inferSbDcSigCoeffFlag && i_bin_sig == 0) begin //n=1时上面if (i_bin_sig) inferSbDcSigCoeffFlag <=0来不及反映
                        //n=0,xP=0,yP=0
                        if (o_cIdx == 0) begin
                            if ({xS_r,2'b00} > luma_x_lmt)
                                luma_x_lmt                    <= {xS_r,2'b00};
                            if (luma_y_lmt_pos00_tmp<luma_y_pos00_signed)
                                luma_y_lmt[{xS_r,2'b00}]      <= luma_y_pos00_signed;
                        end else if (o_cIdx == 1) begin
                            if ({xS_r[1:0],2'b00} > cb_x_lmt)
                                cb_x_lmt[coeff_cb_sel]        <= {xS_r[1:0],2'b00};
                            if ( chroma_y_lmt_pos00_tmp<chroma_y_pos00_signed)
                                cb_y_lmt[{xS_r[1:0],2'b00}]   <= chroma_y_pos00_signed;
                        end else begin
                            if ({xS_r[1:0],2'b00} > cr_x_lmt)
                                cr_x_lmt                      <= {xS_r[1:0],2'b00};
                            if (chroma_y_lmt_pos00_tmp<chroma_y_pos00_signed)
                                cr_y_lmt[{xS_r[1:0],2'b00}]   <= chroma_y_pos00_signed;
                        end

                        sig_coeff_indices[sig_coeff_cnt]   <= 0;
                        baseLevel[sig_coeff_cnt]           <= 1;

                        sig_coeff_xp[sig_coeff_cnt]        <= 0;
                        sig_coeff_yp[sig_coeff_cnt]        <= 0;
                        sig_coeff_cnt                      <= sig_coeff_cnt_pls1;
                        sig_coeff_cnt_minus1               <= sig_coeff_cnt;

                        o_dec_bin_en_sig                   <= 0;
                        o_dec_bin_en_gt1_etc               <= 1;
                        o_cm_idx_gt1_etc                   <= cm_idx_gt1;
                        o_tu_state                         <= `coeff_abs_level_greater1_flag_s;
                        m                                  <= 0;

                        //firstSigScanPos,lastSigScanPos即为sig_coeff_indices的最后一个和第一个
                        lastSigScanPos                     <= sig_coeff_cnt==0?0:sig_coeff_indices[0];
                        firstSigScanPos                    <= 0;
                        abs_lvl_first_sig                  <= 1;
                        first_sig_xp                       <= 0;
                        first_sig_yp                       <= 0;
                        if (`log_v && slice_num>=`slice_begin && slice_num<=`slice_end)
                            $fdisplay(fd_log, "inferSbDcSigCoeffFlag=1 lastSigScanPos %d firstSigScanPos 0",
                             sig_coeff_indices[0]);
                    end
                    if (n == 0) begin //15=-1
                        if (sig_coeff_cnt > 0 || i_bin_sig) begin
                            o_dec_bin_en_sig               <= 0;
                            o_dec_bin_en_gt1_etc           <= 1;
                            o_cm_idx_gt1_etc               <= cm_idx_gt1;
                            o_tu_state                     <= `coeff_abs_level_greater1_flag_s;
                            m                              <= 0;

                            numGreater1Flag                <= 0;
                            lastSigScanPos                 <= sig_coeff_cnt==0?0:sig_coeff_indices[0];

                            if (`log_v && slice_num>=`slice_begin && slice_num<=`slice_end)
                                $fdisplay(fd_log, "lastSigScanPos %d firstSigScanPos 0",sig_coeff_indices[0]);

                        end else begin
                            o_dec_bin_en_sig               <= 0;
                            //一个sig coeff也没有
                            if (i == 0) begin
                                o_tu_state                 <= `parse_residual_coding;
                            end else begin
                                i                          <= i-1;
                                o_tu_state                 <= `next_sub_block;
                            end
                        end
                    end else begin
                        if (o_cIdx == 0)
                            o_cm_idx_sig                   <= `CM_IDX_SIG_FLAG + sigCtx_r;
                        else
                            o_cm_idx_sig                   <= `CM_IDX_SIG_FLAG + sigCtx_r + 27;
                    end
                end else begin
                    //n遍历lastScanPos, i遍历lastSubBlock
                    sigCtx_r                               <= sigCtx;
                    //假定要解n=1,0这两个位置sig coeff,第一次走到这里n应该等于1，
                    //sigCtx为xP_nxt,yP_nxt,n-1=0位置，即n=1时这里预先求得n=0的sigCtx存入reg

                    //(ctxSet << 2) + min(3, greater1Ctx) greater1Ctx=1
                    xP_r                                   <= xP;
                    yP_r                                   <= yP;
                    if (o_cIdx == 0) begin
                        luma_y_lmt_tmp                     <= luma_y_lmt[{xS_r,xP}];
                        luma_y_lmt_pos00_tmp               <= luma_y_lmt[{xS_r,2'b00}];
                    end else if (o_cIdx == 1) begin
                        chroma_y_lmt_tmp                   <= cb_y_lmt[{xS_r[1:0],xP}];
                        chroma_y_lmt_pos00_tmp             <= cb_y_lmt[{xS_r[1:0],2'b00}];
                    end else begin
                        chroma_y_lmt_tmp                   <= cr_y_lmt[{xS_r[1:0],xP}];
                        chroma_y_lmt_pos00_tmp             <= cr_y_lmt[{xS_r[1:0],2'b00}];
                    end

                    if (o_cIdx == 0)
                        cm_idx_gt1                         <= `CM_IDX_COEFF_ABS_LEVEL_GREAT1_FLAG+
                                                               {ctxSet_r[1:0],2'b00}+1;
                    else
                        cm_idx_gt1                         <= `CM_IDX_COEFF_ABS_LEVEL_GREAT1_FLAG+
                                                               {ctxSet_r[1:0],2'b00}+17;
                end

            `coeff_abs_level_greater1_flag_s://0x12
                if (i_dec_bin_valid) begin
                    //coded_sub_block_flag[yS][xS]           <= 1; //从上面`get_last_sub_block_scan_pos_2直接跳到这里需要存这个
                    coded_sub_block_flag_down[xS]          <= 1;
                    coded_sub_block_flag_right[yS]         <= 1;

                    sign_hidden_r                          <= signHidden;

                    if (`log_i && slice_num>=`slice_begin && slice_num<=`slice_end)
                        $fdisplay(fd_log, "parse_coeff_abs_level_greater1_flag ret %d ctxInc %0d cIdx %d ivlCurrRange %x ivlOffset %x",
                         i_bin_gt1_etc, o_cm_idx_gt1_etc-`CM_IDX_COEFF_ABS_LEVEL_GREAT1_FLAG, o_cIdx, i_ivlCurrRange, i_ivlOffset);

                    if (i_bin_gt1_etc)
                        greater1Ctx                        <= 0;
                    else if (greater1Ctx > 0 && greater1Ctx < 3) //greater1Ctx=0,bin=0时不会前进的，greater1Ctx=3也不会，维持在最大3不变了
                        greater1Ctx                        <= greater1Ctx+1;
                    numGreater1Flag                        <= numGreater1Flag+1;
                    m                                      <= m+1;
                    if (i_bin_gt1_etc) begin
                        baseLevel[m]                       <= 2;
                        if (lastGreater1ScanPos == 5'h1f) begin
                            lastGreater1ScanPos            <= sig_coeff_indices[m];
                            lastGreater1ScanPos_1          <= m;
                        end
                        if (sig_coeff_indices[m]==firstSigScanPos)
                            abs_lvl_first_sig              <= 2;
                    end
                    if (numGreater1Flag < 7 && numGreater1Flag < sig_coeff_cnt_minus1) begin
                        if (i_bin_gt1_etc) begin
                            o_cm_idx_gt1_etc               <= cm_idx_gt1_pred_bin1;
                        end else begin
                            o_cm_idx_gt1_etc               <= cm_idx_gt1_pred_bin0;
                        end
                    end else begin
                        if (`log_v && slice_num>=`slice_begin && slice_num<=`slice_end)
                            $fdisplay(fd_log, "lastGreater1ScanPos %d",lastGreater1ScanPos);

                        if (lastGreater1ScanPos != 5'h1f || i_bin_gt1_etc) begin //赋值-1可以，判断不行
                            o_cm_idx_gt1_etc               <= cm_idx_gt2;
                            o_tu_state                     <= `coeff_abs_level_greater2_flag_s;

                        end else begin

                            m                              <= 0;
                            o_dec_bin_en_gt1_etc           <= 0;
                            o_byp_dec_en_tu                <= 1;
                            lvl_rem_cnt                    <= 0;
                            o_tu_state                     <= `coeff_sign_flag_s;

                        end
                    end
                end else begin

                    //greater1Ctx=0

                    if (o_cIdx != 0) begin
                        cm_idx_gt1_pred_bin1              <= `CM_IDX_COEFF_ABS_LEVEL_GREAT1_FLAG+
                                                             {ctxSet_r[1:0],2'b00} + 16;
                    end else begin
                        cm_idx_gt1_pred_bin1              <= `CM_IDX_COEFF_ABS_LEVEL_GREAT1_FLAG+
                                                             {ctxSet_r[1:0],2'b00};
                    end

                    //greater1Ctx=greater1Ctx+1
                    //int ctxInc = (ctxSet << 2) + min(3, greater1Ctx);
                    if (o_cIdx == 0) begin
                        if (greater1Ctx < 3 && greater1Ctx > 0) begin
                            cm_idx_gt1_pred_bin0          <= `CM_IDX_COEFF_ABS_LEVEL_GREAT1_FLAG+
                                                             {ctxSet_r[1:0],2'b00} + greater1Ctx+1;
                        end else begin
                            cm_idx_gt1_pred_bin0          <= `CM_IDX_COEFF_ABS_LEVEL_GREAT1_FLAG+
                                                             {ctxSet_r[1:0],2'b00} + greater1Ctx;
                        end
                    end else begin
                        if (greater1Ctx < 3 && greater1Ctx > 0) begin
                            cm_idx_gt1_pred_bin0          <= `CM_IDX_COEFF_ABS_LEVEL_GREAT1_FLAG+
                                                             {ctxSet_r[1:0],2'b00} + greater1Ctx+17;
                        end else begin
                            cm_idx_gt1_pred_bin0          <= `CM_IDX_COEFF_ABS_LEVEL_GREAT1_FLAG+
                                                             {ctxSet_r[1:0],2'b00}+greater1Ctx+16;
                        end
                    end

                    if (o_cIdx > 0) begin
                        cm_idx_gt2                    <= `CM_IDX_COEFF_ABS_LEVEL_GREAT2_FLAG+ctxSet_r + 4;
                    end else begin
                        cm_idx_gt2                    <= `CM_IDX_COEFF_ABS_LEVEL_GREAT2_FLAG+ctxSet_r;
                    end
                end

            `coeff_abs_level_greater2_flag_s://0x13
                if (i_dec_bin_valid) begin
                    if (i_bin_gt1_etc) begin
                        baseLevel[lastGreater1ScanPos_1]    <= baseLevel[lastGreater1ScanPos_1]+1;
                        if (sig_coeff_indices[lastGreater1ScanPos_1]==firstSigScanPos)
                            abs_lvl_first_sig               <= baseLevel[lastGreater1ScanPos_1]+1;
                    end

                    if (`log_i && slice_num>=`slice_begin && slice_num<=`slice_end)
                         $fdisplay(fd_log, "parse_coeff_abs_level_greater2_flag ret %d ctxInc %0d cIdx %d ivlCurrRange %x ivlOffset %x",
                         i_bin_gt1_etc, o_cm_idx_gt1_etc - `CM_IDX_COEFF_ABS_LEVEL_GREAT2_FLAG,
                         o_cIdx, i_ivlCurrRange, i_ivlOffset);

                    m                              <= 0;
                    o_dec_bin_en_gt1_etc           <= 0;
                    o_byp_dec_en_tu                <= 1;
                    lvl_rem_cnt                    <= 0;
                    o_tu_state                     <= `coeff_sign_flag_s; //只有1个系数，是第0个系数，signHidden=1不可能的见mark7,所以必经过`coeff_sign_flag_s

                end

            //baseLevel = 1 + coeff_abs_level_greater1_flag[n] + coeff_abs_level_greater2_flag[n];
            //if (baseLevel == ((numSigCoeff < 8) ? ((n == lastGreater1ScanPos) ? 3 : 2) : 1))
            //    parse_coeff_abs_level_remaining(rbsp, &coeff_abs_level_remaining[n], cRiceParam);
            //只有lastGreater1ScanPos这个位置解过greater2_flag,这个位置解出来的greater2_flag=1,也就是baseLevel=3,才需要解level remain
            //其余位置小于8的地方,解过greater1_flag,解出来greater1_flag=1,才需要解level remain
            //大于8个的地方,greater1_flag,greater2_flag都没有解过,直接解level remain

            `coeff_sign_flag_s://0x18
                begin
                    m                                       <= m+1;
                    if (~(m == sig_coeff_cnt_minus1 && signHidden&&
                        i_sign_data_hiding_enabled_flag))
                        coeff_sign_flag[m]                  <= i_bin_byp;
                    if (`log_v && slice_num>=`slice_begin && slice_num<=`slice_end)
                        $fdisplay(fd_log, "m %d baseLevel[m] %d lastGreater1ScanPos %d lastGreater1ScanPos_1 %d signHidden %d",
                         m,baseLevel[m],lastGreater1ScanPos,lastGreater1ScanPos_1,signHidden);

                    if (`log_i && slice_num>=`slice_begin && slice_num<=`slice_end) begin
                        if (m == sig_coeff_cnt_minus1 && signHidden) begin

                        end else begin
                            $fdisplay(fd_log, "coeff_sign_flag[%0d] %0d ivlCurrRange %x ivlOffset %x",
                             sig_coeff_indices[m], i_bin_byp, i_ivlCurrRange, i_ivlOffset);
                        end
                    end

                    //提出来减少路径,需要解码level remain的这里多存一次无所谓
                    //最高位放符号，低7位放abs_lvl，假定abs_lvl不会大于128
                    if (o_cIdx == 0) begin
                        bram_coeff_luma_dec_we            <= 1;
                        bram_coeff_luma_dec_addr          <= {yS_r,sig_coeff_yp[m],xS_r,sig_coeff_xp[m]};
                        bram_coeff_luma_dec_din           <= {i_bin_byp,5'd0,baseLevel[m]};
                    end else if (o_cIdx == 1) begin
                        bram_coeff_cb_dec_we              <= 1;
                        bram_coeff_cb_dec_addr            <= {yS_r[1:0],sig_coeff_yp[m],xS_r[1:0],sig_coeff_xp[m]};
                        bram_coeff_cb_dec_din             <= {i_bin_byp,5'd0,baseLevel[m]};
                    end else begin
                        bram_coeff_cr_dec_we              <= 1;
                        bram_coeff_cr_dec_addr            <= {yS_r[1:0],sig_coeff_yp[m],xS_r[1:0],sig_coeff_xp[m]};
                        bram_coeff_cr_dec_din             <= {i_bin_byp,5'd0,baseLevel[m]};
                    end

                    //解coeff_sign_flag同时计算哪些点需要解level remain
                    if (m < 8) begin
                        if (lastGreater1ScanPos != 5'h1f && m == lastGreater1ScanPos_1) begin
                            if (baseLevel[m] == 3) begin
                                lvl_rem_indices[lvl_rem_cnt] <= m;
                                lvl_rem_cnt                  <= lvl_rem_cnt+1;
                                lvl_rem_cnt_minus1           <= lvl_rem_cnt;
                                if (`log_v && slice_num>=`slice_begin && slice_num<=`slice_end)
                                    $fdisplay(fd_log, "lastGreater1ScanPos need decode level remain");

                            end else begin
                                sumAbsLevel                  <= sumAbsLevel+baseLevel[m]; //need decode level remain在解level remain时加
                                if (`log_v && slice_num>=`slice_begin && slice_num<=`slice_end)
                                    $fdisplay(fd_log, "coeff_sign_flag_s 1 %t TransCoeffLevel[%0d][%0d] = %s%0d",$time,
                                     {yS_r,sig_coeff_yp[m]},{xS_r,sig_coeff_xp[m]},i_bin_byp?"-":"",baseLevel[m]);
                            end
                        end else begin
                            if (baseLevel[m] == 2) begin
                                lvl_rem_indices[lvl_rem_cnt] <= m;
                                lvl_rem_cnt                  <= lvl_rem_cnt+1;
                                lvl_rem_cnt_minus1           <= lvl_rem_cnt;
                                if (`log_v && slice_num>=`slice_begin && slice_num<=`slice_end)
                                    $fdisplay(fd_log, "<8 need decode level remain");

                            end else begin
                                sumAbsLevel                  <= sumAbsLevel+baseLevel[m];
                                if (`log_v && slice_num>=`slice_begin && slice_num<=`slice_end)
                                    $fdisplay(fd_log, "coeff_sign_flag_s 2 %t TransCoeffLevel[%0d][%0d] = %s%0d",$time,
                                     {yS_r,sig_coeff_yp[m]},{xS_r,sig_coeff_xp[m]},i_bin_byp?"-":"",baseLevel[m]);
                            end
                        end
                    end else begin
                        if (baseLevel[m] == 1) begin
                            lvl_rem_indices[lvl_rem_cnt] <= m;
                            lvl_rem_cnt                  <= lvl_rem_cnt+1;
                            lvl_rem_cnt_minus1           <= lvl_rem_cnt;
                            if (`log_v && slice_num>=`slice_begin && slice_num<=`slice_end)
                                $fdisplay(fd_log, ">=8 need decode level remain");

                        end else begin
                            sumAbsLevel                  <= sumAbsLevel+baseLevel[m];
                        end
                    end
                    //需要计算是否需要解码level remain,不能提前退出
                    if (m == sig_coeff_cnt - 2) begin
                        if (i_sign_data_hiding_enabled_flag && signHidden) begin
                            o_byp_dec_en_tu                 <= 0;
                        end
                        if (`log_v && slice_num>=`slice_begin && slice_num<=`slice_end)
                            $fdisplay(fd_log, "m=%d,signHidden=%d",m,signHidden);

                    end
                    if (m == sig_coeff_cnt_minus1) begin
                        o_byp_dec_en_tu                     <= 0;
                        prefix_lvl_rem                      <= 0;
                        prefix_lvl_rem_pls1                 <= 1;
                        prefix_lvl_rem_minus2               <= -2;
                        suffix_lvl_rem                      <= 0;
                        cRiceParam                          <= 0;
                        m                                   <= 0;
                        //提到外面，减少路径
                        if (lvl_rem_cnt == 0) begin //有且仅有1个需要解level remain，即本次index=my
                            base_lvl                        <= baseLevel[m];
                            xP_r                            <= sig_coeff_xp[m];
                            yP_r                            <= sig_coeff_yp[m];
                        end else begin
                            base_lvl                        <= baseLevel[lvl_rem_indices[0]];
                            xP_r                            <= sig_coeff_xp[lvl_rem_indices[0]];
                            yP_r                            <= sig_coeff_yp[lvl_rem_indices[0]];
                        end
                        if (m < 8) begin
                            if (lastGreater1ScanPos != 5'h1f && m == lastGreater1ScanPos_1) begin

                                if (baseLevel[m] == 3 || lvl_rem_cnt > 0) begin
                                    m                       <= 0;
                                    m1                      <= 1;
                                    o_byp_dec_en_tu         <= 1;
                                    o_tu_state              <= `coeff_abs_level_remaining_s_1;
                                end else begin
                                    if (i == 0) begin
                                        if (sign_hidden_r&&abs_lvl_first_sig)
                                            o_tu_state      <= `store_coeff_first_sig;
                                        else
                                            o_tu_state      <= `parse_residual_coding;
                                    end else begin
                                        i                   <= i-1;
                                        n                   <= 0;
                                        o_tu_state          <= `next_sub_block;
                                    end
                                end
                            end else begin
    
                                if (baseLevel[m] == 2 || lvl_rem_cnt > 0) begin
                                    m                       <= 0;
                                    m1                      <= 1;
                                    o_byp_dec_en_tu         <= 1;
                                    o_tu_state              <= `coeff_abs_level_remaining_s_1;
                                end else begin
                                    if (i == 0) begin
                                        if (sign_hidden_r&&abs_lvl_first_sig)
                                            o_tu_state      <= `store_coeff_first_sig;
                                        else
                                            o_tu_state      <= `parse_residual_coding;
                                    end else begin
                                        i                   <= i-1;
                                        n                   <= 0;
                                        o_tu_state          <= `next_sub_block;
                                    end
                                end
                            end
                        end else begin

                            if (baseLevel[m] == 1 || lvl_rem_cnt > 0) begin
                                m                           <= 0;
                                m1                          <= 1;
                                o_byp_dec_en_tu             <= 1;
                                o_tu_state                  <= `coeff_abs_level_remaining_s_1;
                            end else begin
                                if (i == 0) begin
                                    if (sign_hidden_r&&abs_lvl_first_sig)
                                        o_tu_state          <= `store_coeff_first_sig;
                                    else
                                        o_tu_state          <= `parse_residual_coding;
                                end else begin
                                    i                       <= i-1;
                                    n                       <= 0;
                                    o_tu_state              <= `next_sub_block;
                                end
                            end
                        end
                    end
                end

            `coeff_abs_level_remaining_s_1://0x14
                begin
                    if (`log_i && slice_num>=`slice_begin && slice_num<=`slice_end)
                        $fdisplay(fd_log, "bypass prefix binVal %d ivlCurrRange %x ivlOffset %x",
                         i_bin_byp, i_ivlCurrRange, i_ivlOffset);

                    c_rice_param_nxt                        <= cRiceParam > 3 ? 4:cRiceParam+1;
                    abs_lvl_thresh                          <= 3<<cRiceParam;
                    abs_lvl_thresh_minus1                   <= (3<<cRiceParam)-1;
                    abs_lvl_thresh_minus2                   <= (3<<cRiceParam)-2;
                    abs_lvl_thresh_minus3                   <= (3<<cRiceParam)-3;

                    abs_lvl_pre_lt3                         <= base_lvl+(prefix_lvl_rem_pls1 << cRiceParam);
                    abs_lvl_pre_ge3                         <= base_lvl+(((1 << (prefix_lvl_rem_minus2))+3-1) << cRiceParam);

                    if (i_bin_byp) begin
                        prefix_lvl_rem                      <= prefix_lvl_rem+1;
                        prefix_lvl_rem_pls1                 <= prefix_lvl_rem_pls1+1;
                        prefix_lvl_rem_minus2               <= prefix_lvl_rem_minus2+1;
                    end else begin
                        j                                   <= 0;
                        if (prefix_lvl_rem < 3) begin
                            if (cRiceParam == 0) begin
                                if (`log_i && slice_num>=`slice_begin && slice_num<=`slice_end)
                                    $fdisplay(fd_log, "parse_coeff_abs_level_remaining ret %0d prefixVal %0d suffixVal 0 cRiceParam 0",
                                     prefix_lvl_rem, prefix_lvl_rem);

                                if (`log_v && slice_num>=`slice_begin && slice_num<=`slice_end)
                                    $fdisplay(fd_log, "coeff_abs_level_remaining_s_1 1 %t TransCoeffLevel[%0d][%0d] = %s%0d",$time,
                                     {yS_r,yP_r},{xS_r,xP_r},
                                     coeff_sign_flag[lvl_rem_indices[m]]?"-":"",
                                     prefix_lvl_rem==0?base_lvl:abs_lvl_pre_lt3);

                                //需要解level remain，结果一上来bin解出来就是0，prefix_lvl_rem=0是有可能的
                                if (o_cIdx == 0) begin
                                    bram_coeff_luma_dec_we      <= 1;
                                    bram_coeff_luma_dec_addr    <= {yS_r,yP_r,xS_r,xP_r};
                                    bram_coeff_luma_dec_din     <= prefix_lvl_rem==0?
                                                                    {coeff_sign_flag[lvl_rem_indices[m]],base_lvl[6:0]}:
                                                                    {coeff_sign_flag[lvl_rem_indices[m]],abs_lvl_pre_lt3[6:0]};
                                end else if (o_cIdx == 1) begin
                                    bram_coeff_cb_dec_we        <= 1;
                                    bram_coeff_cb_dec_addr      <= {yS_r[1:0],yP_r,xS_r[1:0],xP_r};
                                    bram_coeff_cb_dec_din       <= prefix_lvl_rem==0?
                                                                    {coeff_sign_flag[lvl_rem_indices[m]],base_lvl[6:0]}:
                                                                    {coeff_sign_flag[lvl_rem_indices[m]],abs_lvl_pre_lt3[6:0]};
                                end else begin
                                    bram_coeff_cr_dec_we        <= 1;
                                    bram_coeff_cr_dec_addr      <= {yS_r[1:0],yP_r,xS_r[1:0],xP_r};
                                    bram_coeff_cr_dec_din       <= prefix_lvl_rem==0?
                                                                    {coeff_sign_flag[lvl_rem_indices[m]],base_lvl[6:0]}:
                                                                    {coeff_sign_flag[lvl_rem_indices[m]],abs_lvl_pre_lt3[6:0]};
                                end
                                if (prefix_lvl_rem==0)
                                    sumAbsLevel                 <= sumAbsLevel+base_lvl;
                                else
                                    sumAbsLevel                 <= sumAbsLevel+abs_lvl_pre_lt3;
                                if (sig_coeff_indices[lvl_rem_indices[m]]==firstSigScanPos)
                                    abs_lvl_first_sig           <= prefix_lvl_rem==0?base_lvl[6:0]:abs_lvl_pre_lt3[6:0];
                                m                               <= m+1;
                                m1                              <= m1+1;
                                if (m == lvl_rem_cnt_minus1) begin
                                    o_byp_dec_en_tu             <= 0;
                                    if (i == 0) begin
                                        if (sign_hidden_r&&abs_lvl_first_sig)
                                            o_tu_state          <= `store_coeff_first_sig;
                                        else
                                            o_tu_state          <= `parse_residual_coding;
                                    end else begin
                                        i                       <= i-1;
                                        n                       <= 0;
                                        o_tu_state              <= `next_sub_block;
                                    end
                                end else begin
                                    prefix_lvl_rem              <= 0;
                                    prefix_lvl_rem_pls1         <= 1;
                                    prefix_lvl_rem_minus2       <= -2;
                                    suffix_lvl_rem              <= 0;
    
                                    //prefix_lvl_rem=0,0<<cRiceParam=0,cRiceParam最小0,3<<cRiceParam也等于3,base_lvl+0<<cRiceParam不可能大于3<<cRiceParam
                                    //至少第二bit为0，才能用abs_lvl_pre_lt3 <= abs_lvl_thresh,因为上面abs_lvl_thresh <= 3<<cRiceParam至少第2周期能用
                                    cRiceParam                           <= (prefix_lvl_rem == 0 || abs_lvl_pre_lt3 <= abs_lvl_thresh) ? cRiceParam:c_rice_param_nxt;
                                    base_lvl                             <= baseLevel[lvl_rem_indices[m1]];
                                    xP_r                                 <= sig_coeff_xp[lvl_rem_indices[m1]];
                                    yP_r                                 <= sig_coeff_yp[lvl_rem_indices[m1]];
                                    o_tu_state                           <= `coeff_abs_level_remaining_s_1;
                                end
                            end else begin
                                lvl_rem_suf_max_bins_minus1              <= cRiceParam - 1;
                                abs_lvl_pre                              <= prefix_lvl_rem == 0 ? base_lvl:abs_lvl_pre_lt3;

                                //prefix=0,但有suffix的情况，abs_lvl_thresh <= 3<<cRiceParam,abs_lvl_thresh来不及更新
                                //不能拿abs_lvl_pre_lt3比abs_lvl_thresh
                                cond_abs_lvl_gt_thresh_prev_bin0         <= (prefix_lvl_rem == 0 || abs_lvl_pre_lt3 <= abs_lvl_thresh) ? 0:1;
                                cond_abs_lvl_gt_thresh_minus1_prev_bin0  <= (prefix_lvl_rem == 0 || abs_lvl_pre_lt3 <= abs_lvl_thresh_minus1) ? 0:1;

                                lvl_rem_suf_prev_bin                     <= 0;
                                o_tu_state                               <= `coeff_abs_level_remaining_s_2;
                            end
                        end else begin
                            if ((prefix_lvl_rem -3 + cRiceParam) == 0) begin
                                if (`log_i && slice_num>=`slice_begin && slice_num<=`slice_end)
                                    $fdisplay(fd_log, "parse_coeff_abs_level_remaining ret %0d prefixVal %0d suffixVal 0 cRiceParam %0d",
                                     prefix_lvl_rem, prefix_lvl_rem,0);

                                if (`log_v && slice_num>=`slice_begin && slice_num<=`slice_end)
                                    $fdisplay(fd_log, "coeff_abs_level_remaining_s_1 2 %t TransCoeffLevel[%0d][%0d] = %s%0d",$time,
                                     {yS_r,yP_r},{xS_r,xP_r},
                                     coeff_sign_flag[lvl_rem_indices[m]]?"-":"",abs_lvl_pre_ge3);

                                if (o_cIdx == 0) begin
                                    bram_coeff_luma_dec_we               <= 1;
                                    bram_coeff_luma_dec_addr             <= {yS_r,yP_r,xS_r,xP_r};
                                    bram_coeff_luma_dec_din              <= {coeff_sign_flag[lvl_rem_indices[m]],abs_lvl_pre_ge3[6:0]};
                                end else if (o_cIdx == 1) begin
                                    bram_coeff_cb_dec_we                 <= 1;
                                    bram_coeff_cb_dec_addr               <= {yS_r[1:0],yP_r,xS_r[1:0],xP_r};
                                    bram_coeff_cb_dec_din                <= {coeff_sign_flag[lvl_rem_indices[m]],abs_lvl_pre_ge3[6:0]};
                                end else begin
                                    bram_coeff_cr_dec_we                 <= 1;
                                    bram_coeff_cr_dec_addr               <= {yS_r[1:0],yP_r,xS_r[1:0],xP_r};
                                    bram_coeff_cr_dec_din                <= {coeff_sign_flag[lvl_rem_indices[m]],abs_lvl_pre_ge3[6:0]};
                                end
                                sumAbsLevel                              <= sumAbsLevel+abs_lvl_pre_ge3;
                                if (sig_coeff_indices[lvl_rem_indices[m]]==firstSigScanPos)
                                    abs_lvl_first_sig                    <= abs_lvl_pre_ge3[6:0];

                                m                                        <= m+1;
                                m1                                       <= m1+1;

                                if (m == lvl_rem_cnt_minus1) begin
                                    o_byp_dec_en_tu                      <= 0;
                                    if (i == 0) begin
                                        if (sign_hidden_r&&abs_lvl_first_sig)
                                            o_tu_state                   <= `store_coeff_first_sig;
                                        else
                                            o_tu_state                   <= `parse_residual_coding;
                                    end else begin
                                        i                                <= i-1;
                                        n                                <= 0;
                                        o_tu_state                       <= `next_sub_block;
                                    end
                                end else begin
                                    prefix_lvl_rem                       <= 0;
                                    prefix_lvl_rem_pls1                  <= 1;
                                    prefix_lvl_rem_minus2                <= -2;
                                    suffix_lvl_rem                       <= 0;
                                    cRiceParam                           <= abs_lvl_pre_ge3 > abs_lvl_thresh ?
                                                                             c_rice_param_nxt:cRiceParam;
                                    base_lvl                             <= baseLevel[lvl_rem_indices[m1]];
                                    xP_r                                 <= sig_coeff_xp[lvl_rem_indices[m1]];
                                    yP_r                                 <= sig_coeff_yp[lvl_rem_indices[m1]];
                                    o_tu_state                           <= `coeff_abs_level_remaining_s_1;
                                end
                            end else begin
                                cond_abs_lvl_gt_thresh_prev_bin0         <= abs_lvl_pre_ge3 > abs_lvl_thresh?1:0;
                                cond_abs_lvl_gt_thresh_minus1_prev_bin0  <= abs_lvl_pre_ge3 > abs_lvl_thresh_minus1?1:0;
                                lvl_rem_suf_prev_bin                     <= 0;

                                lvl_rem_suf_max_bins_minus1              <= prefix_lvl_rem + cRiceParam - 4;
                                abs_lvl_pre                              <= abs_lvl_pre_ge3;
                                o_tu_state                               <= `coeff_abs_level_remaining_s_3;
                            end
                        end

                    end
                end
            `coeff_abs_level_remaining_s_2://0x15 prefix val less than 3
                begin
                    if (`log_i && slice_num>=`slice_begin && slice_num<=`slice_end)
                        $fdisplay(fd_log, "bypass suffix binVal %d ivlCurrRange %x ivlOffset %x",
                         i_bin_byp, i_ivlCurrRange, i_ivlOffset);

                    j                                       <= j+1;
                    suffix_lvl_rem                          <= (suffix_lvl_rem << 1)|i_bin_byp;

                    cond_abs_lvl_gt_thresh_prev_bin0        <= (abs_lvl_pre + (suffix_lvl_rem<<2)) > abs_lvl_thresh ? 1:0;
                    cond_abs_lvl_gt_thresh_minus1_prev_bin0 <= (abs_lvl_pre + (suffix_lvl_rem<<2)) > abs_lvl_thresh_minus1 ? 1:0;
                    cond_abs_lvl_gt_thresh_prev_bin1        <= (abs_lvl_pre + (suffix_lvl_rem<<2)) > abs_lvl_thresh_minus2 ? 1:0;
                    cond_abs_lvl_gt_thresh_minus1_prev_bin1 <= (abs_lvl_pre + (suffix_lvl_rem<<2)) > abs_lvl_thresh_minus3 ? 1:0;

                    lvl_rem_suf_prev_bin                    <= i_bin_byp;

                    if (j == lvl_rem_suf_max_bins_minus1) begin
                        if (`log_i && slice_num>=`slice_begin && slice_num<=`slice_end)
                            $fdisplay(fd_log, "parse_coeff_abs_level_remaining ret %0d prefixVal %0d suffixVal %0d cRiceParam %0d",
                             (prefix_lvl_rem << cRiceParam)+(suffix_lvl_rem << 1)|i_bin_byp,
                             prefix_lvl_rem, (suffix_lvl_rem << 1)|i_bin_byp, cRiceParam);

                        if (`log_v && slice_num>=`slice_begin && slice_num<=`slice_end) begin
                            $fdisplay(fd_log, "coeff_abs_level_remaining_s_2 %t TransCoeffLevel[%0d][%0d] = %s%0d",$time,
                                 {yS_r,yP_r},{xS_r,xP_r},coeff_sign_flag[lvl_rem_indices[m]]?"-":"",abs_lvl);
                        end

                        if (o_cIdx == 0) begin
                            bram_coeff_luma_dec_we            <= 1;
                            bram_coeff_luma_dec_addr          <= {yS_r,yP_r,xS_r,xP_r};
                            bram_coeff_luma_dec_din           <= {coeff_sign_flag[lvl_rem_indices[m]],abs_lvl[6:0]};
                        end else if (o_cIdx == 1) begin
                            bram_coeff_cb_dec_we              <= 1;
                            bram_coeff_cb_dec_addr            <= {yS_r[1:0],yP_r,xS_r[1:0],xP_r};
                            bram_coeff_cb_dec_din             <= {coeff_sign_flag[lvl_rem_indices[m]],abs_lvl[6:0]};
                        end else begin
                            bram_coeff_cr_dec_we              <= 1;
                            bram_coeff_cr_dec_addr            <= {yS_r[1:0],yP_r,xS_r[1:0],xP_r};
                            bram_coeff_cr_dec_din             <= {coeff_sign_flag[lvl_rem_indices[m]],abs_lvl[6:0]};
                        end
                        sumAbsLevel                           <= sumAbsLevel+abs_lvl;
                        if (sig_coeff_indices[lvl_rem_indices[m]]==firstSigScanPos)
                            abs_lvl_first_sig                 <= abs_lvl[6:0];

                        m                                   <= m+1;
                        m1                                  <= m1+1;

                        if (lvl_rem_suf_prev_bin)
                            cRiceParam                      <= cond_abs_lvl_gt_thresh_prev_bin1 ||
                                                               (i_bin_byp && cond_abs_lvl_gt_thresh_minus1_prev_bin1) ?
                                                                c_rice_param_nxt:cRiceParam;
                        else
                            cRiceParam                      <= cond_abs_lvl_gt_thresh_prev_bin0 ||
                                                               (i_bin_byp && cond_abs_lvl_gt_thresh_minus1_prev_bin0) ?
                                                                c_rice_param_nxt:cRiceParam;

                        base_lvl                            <= baseLevel[lvl_rem_indices[m1]];
                        xP_r                                <= sig_coeff_xp[lvl_rem_indices[m1]];
                        yP_r                                <= sig_coeff_yp[lvl_rem_indices[m1]];
                        if (m == lvl_rem_cnt_minus1) begin
                            o_byp_dec_en_tu                 <= 0;
                            if (i == 0) begin
                                if (sign_hidden_r&&abs_lvl_first_sig)
                                    o_tu_state              <= `store_coeff_first_sig;
                                else
                                    o_tu_state              <= `parse_residual_coding;
                            end else begin
                                i                           <= i-1;
                                n                           <= 0;
                                o_tu_state                  <= `next_sub_block;
                            end
                        end else begin
                            prefix_lvl_rem                  <= 0;
                            prefix_lvl_rem_pls1             <= 1;
                            prefix_lvl_rem_minus2           <= -2;
                            suffix_lvl_rem                  <= 0;
                            o_tu_state                      <= `coeff_abs_level_remaining_s_1;
                        end
                    end
                end
            `coeff_abs_level_remaining_s_3://0x16 prefix val ge 3
                begin
                    if (`log_i && slice_num>=`slice_begin && slice_num<=`slice_end)
                        $fdisplay(fd_log, "bypass suffix binVal %d ivlCurrRange %x ivlOffset %x",
                         i_bin_byp, i_ivlCurrRange, i_ivlOffset);

                    j                                       <= j+1;
                    suffix_lvl_rem                          <= (suffix_lvl_rem << 1)|i_bin_byp;

                    cond_abs_lvl_gt_thresh_prev_bin0        <= (abs_lvl_pre + (suffix_lvl_rem<<2)) > abs_lvl_thresh ? 1:0;
                    cond_abs_lvl_gt_thresh_minus1_prev_bin0 <= (abs_lvl_pre + (suffix_lvl_rem<<2)) > abs_lvl_thresh_minus1 ? 1:0;
                    cond_abs_lvl_gt_thresh_prev_bin1        <= (abs_lvl_pre + (suffix_lvl_rem<<2)) > abs_lvl_thresh_minus2 ? 1:0;
                    cond_abs_lvl_gt_thresh_minus1_prev_bin1 <= (abs_lvl_pre + (suffix_lvl_rem<<2)) > abs_lvl_thresh_minus3 ? 1:0;

                    lvl_rem_suf_prev_bin                    <= i_bin_byp;
    
                    if (j == lvl_rem_suf_max_bins_minus1) begin
                        if (`log_i && slice_num>=`slice_begin && slice_num<=`slice_end)
                            $fdisplay(fd_log, "parse_coeff_abs_level_remaining ret %0d prefixVal %0d suffixVal %0d cRiceParam %0d",
                             (((1 << (prefix_lvl_rem-3)) + 3 - 1) << cRiceParam)+(suffix_lvl_rem<<1)|i_bin_byp,
                             prefix_lvl_rem, (suffix_lvl_rem<<1)|i_bin_byp, cRiceParam);

                        if (`log_v && slice_num>=`slice_begin && slice_num<=`slice_end)
                            $fdisplay(fd_log, "coeff_abs_level_remaining_s_3 %t TransCoeffLevel[%0d][%0d] = %s%0d",$time,
                             {yS_r,yP_r},{xS_r,xP_r},
                             coeff_sign_flag[lvl_rem_indices[m]]?"-":"",abs_lvl);

                        if (o_cIdx == 0) begin
                            bram_coeff_luma_dec_we          <= 1;
                            bram_coeff_luma_dec_addr        <= {yS_r,yP_r,xS_r,xP_r};
                            bram_coeff_luma_dec_din         <= {coeff_sign_flag[lvl_rem_indices[m]],abs_lvl[6:0]};
                        end else if (o_cIdx == 1) begin
                            bram_coeff_cb_dec_we            <= 1;
                            bram_coeff_cb_dec_addr          <= {yS_r[1:0],yP_r,xS_r[1:0],xP_r};
                            bram_coeff_cb_dec_din           <= {coeff_sign_flag[lvl_rem_indices[m]],abs_lvl[6:0]};
                        end else begin
                            bram_coeff_cr_dec_we            <= 1;
                            bram_coeff_cr_dec_addr          <= {yS_r[1:0],yP_r,xS_r[1:0],xP_r};
                            bram_coeff_cr_dec_din           <= {coeff_sign_flag[lvl_rem_indices[m]],abs_lvl[6:0]};
                        end
                        sumAbsLevel                         <= sumAbsLevel+abs_lvl;
                        if (sig_coeff_indices[lvl_rem_indices[m]]==firstSigScanPos)
                            abs_lvl_first_sig               <= abs_lvl[6:0];

                        m                                   <= m+1;
                        m1                                  <= m1+1;

                        base_lvl                            <= baseLevel[lvl_rem_indices[m1]];
                        xP_r                                <= sig_coeff_xp[lvl_rem_indices[m1]];
                        yP_r                                <= sig_coeff_yp[lvl_rem_indices[m1]];
                        if (lvl_rem_suf_prev_bin)
                            cRiceParam                      <= cond_abs_lvl_gt_thresh_prev_bin1 ||
                                                               (i_bin_byp && cond_abs_lvl_gt_thresh_minus1_prev_bin1) ?
                                                                c_rice_param_nxt:cRiceParam;
                        else
                            cRiceParam                      <= cond_abs_lvl_gt_thresh_prev_bin0 ||
                                                               (i_bin_byp && cond_abs_lvl_gt_thresh_minus1_prev_bin0) ?
                                                                c_rice_param_nxt:cRiceParam;

                        if (m == lvl_rem_cnt_minus1) begin
                            o_byp_dec_en_tu                 <= 0;
                            if (i == 0) begin
                                if (sign_hidden_r&&abs_lvl_first_sig)
                                    o_tu_state              <= `store_coeff_first_sig;
                                else
                                    o_tu_state              <= `parse_residual_coding;
                            end else begin
                                i                           <= i-1;
                                n                           <= 0;
                                o_tu_state                  <= `next_sub_block;
                            end
                        end else begin
                            prefix_lvl_rem                  <= 0;
                            prefix_lvl_rem_pls1             <= 1;
                            prefix_lvl_rem_minus2           <= -2;
                            suffix_lvl_rem                  <= 0;
                            o_tu_state                      <= `coeff_abs_level_remaining_s_1;
                        end
                    end
                end

        endcase
    end

    case (o_tu_state)
        `rst_tu://这个状态持续了3周期，因为在等en，en在bitstream_controller延迟了
            begin
                //从这里开始
                //if (cu->pred_mode == MODE_INTRA || trafoDepth != 0 || cbf_cb || cbf_cr)
                //    parse_cbf_luma(rbsp, &cbf_luma, trafoDepth);
                //parse_transform_unit(..);

                o_byp_dec_en_tu                 <= 0;
                o_cIdx                          <= 3;
                scanIdxY                        <= `SCAN_DIAG;
                scanIdxC                        <= `SCAN_DIAG;

                if (i_pred_mode == `MODE_INTRA && log2TrafoSize < 4) begin
                    if (i_IntraPredModeY >= 6 && //todo 可代替intra_luma_pred_mode[yTu[5:2]]xTu[5:2]]?
                        i_IntraPredModeY <= 14)
                        scanIdxY                <= `SCAN_VERT;
                    else if (i_IntraPredModeY >= 22 && i_IntraPredModeY <= 30)
                        scanIdxY                <= `SCAN_HORIZ;
                    if (i_intra_pred_mode_chroma >= 6 && i_intra_pred_mode_chroma <= 14)
                        scanIdxC                <= `SCAN_VERT;
                    else if (i_intra_pred_mode_chroma >= 22 && i_intra_pred_mode_chroma <= 30)
                        scanIdxC                <= `SCAN_HORIZ;
                end

                if (i_rqt_root_cbf==0||i_cu_skip_flag==1) begin
                    cbf_cb                      <= 0;
                    cbf_cr                      <= 0;
                    o_cbf_luma                  <= 0;
                    o_tu_state                  <= `parse_residual_coding;
                end else if (i_pred_mode == `MODE_INTRA || trafoDepth != 0 || i_cbf_cb || i_cbf_cr) begin
                    if (trafoDepth == 0)
                        o_cm_idx_gt1_etc        <= `CM_IDX_QT_CBF_LUMA+1;
                    else
                        o_cm_idx_gt1_etc        <= `CM_IDX_QT_CBF_LUMA;
                    o_dec_bin_en_gt1_etc        <= 1;
                    o_tu_state                  <= `cbf_luma_s;//1
                end else begin
                    o_cbf_luma                  <= 1;
                    if (i_cu_qp_delta_enabled_flag && ~i_IsCuQpDeltaCoded) begin
                        prefixVal               <= 0;
                        suffixVal               <= 0;
                        o_dec_bin_en_gt1_etc    <= 1;
                        set_qpy                 <= 1;
                        o_cm_idx_gt1_etc        <= `CM_IDX_DQP;
                        o_tu_state              <= `cu_qp_delta_abs_s_1;
                        o_IsCuQpDeltaCoded      <= 1;
                    end else begin
                        o_tu_state              <= `parse_residual_coding;
                    end
                end
            end



        //signHidden只有在求完所有系数才能知道sign，
        //如果非最后一个子块，在`next_sub_block里存first sig,
        //如果最后一个子块，在走`parse_residual_coding之前先经过这里，存first_sig
        `store_coeff_first_sig:
            begin
                if (`log_v && slice_num>=`slice_begin && slice_num<=`slice_end)
                    $fdisplay(fd_log, "store coeff first sig %s%0d",sumAbsLevel[0]?"-":"",abs_lvl_first_sig);

                if (o_cIdx == 0) begin
                    bram_coeff_luma_dec_we      <= 1;
                    bram_coeff_luma_dec_addr    <= {yS_r,first_sig_yp,xS_r,first_sig_xp};
                    bram_coeff_luma_dec_din     <= {sumAbsLevel[0],abs_lvl_first_sig};
                end else if (o_cIdx == 1) begin
                    bram_coeff_cb_dec_we        <= 1;
                    bram_coeff_cb_dec_addr      <= {yS_r[1:0],first_sig_yp,xS_r[1:0],first_sig_xp};
                    bram_coeff_cb_dec_din       <= {sumAbsLevel[0],abs_lvl_first_sig};
                end else begin
                    bram_coeff_cr_dec_we        <= 1;
                    bram_coeff_cr_dec_addr      <= {yS_r[1:0],first_sig_yp,xS_r[1:0],first_sig_xp};
                    bram_coeff_cr_dec_din       <= {sumAbsLevel[0],abs_lvl_first_sig};
                end
                o_tu_state                      <= `parse_residual_coding;
            end

        `parse_residual_coding://0x7
            begin
                //等待上一个transquant结束，
                //intra pred在`cu_pass2tu时等完了，inter pred在这里还需要等
                //modelsim,o_tq_luma_state=x(不确定状态),o_tq_luma_state != `trans_quant_end不成立
                if ((o_cIdx == 0 && o_tq_luma_state != `trans_quant_end) ||
                    (o_cIdx == 1 && o_tq_cb_state != `trans_quant_end) ||
                    (o_cIdx == 2 && o_tq_cr_state != `trans_quant_end)) begin

                end else begin
                    coeff_luma_sel              <= o_cIdx == 0?~coeff_luma_sel:coeff_luma_sel;
                    coeff_cb_sel                <= o_cIdx == 1?~coeff_cb_sel:coeff_cb_sel;
                    coeff_cr_sel                <= o_cIdx == 2?~coeff_cr_sel:coeff_cr_sel;

                    //cbf=0,也rst进入tq，仅仅为了输出o_tq_done_y
                    //chroma log2TrafoSize=2,blk0,1,2不能进入tq
                    tq_luma_rst                 <= o_cIdx == 0;
                    tq_cb_rst                   <= o_cIdx == 1&&(~cond_chroma_no_residual);
                    tq_cr_rst                   <= o_cIdx == 2&&(~cond_chroma_no_residual);
                    o_tu_state                  <= `parse_residual_coding_2;

                    sign_hidden_r               <= 0;
                    abs_lvl_first_sig           <= 0;
                    first_sig_xp                <= 0;
                    first_sig_yp                <= 0;
                    sumAbsLevel                 <= 0;
                end

            end

        `parse_residual_coding_2://0x1d
            begin
                o_cIdx                          <= o_cIdx + 1;
                transform_skip_flag             <= 0;
                prevCsbf                        <= 0;
                csbfCtx                         <= 0;
                binIdx                          <= 0;
                scanIdx                         <= o_cIdx==3?scanIdxY:scanIdxC; //cIdx reset置3
                component                       <= o_cIdx==1?1:0;
                tq_luma_rst                     <= 0;
                tq_cb_rst                       <= 0;
                tq_cr_rst                       <= 0;

                if (tq_luma_rst) begin
                    o_tq_luma_end_x             <= xTu[5:0]+trafoSize-1;
                end
                if (tq_cb_rst) begin
                    o_tq_cb_end_x               <= trafoSize[2]?{xTu[5:3],2'b11}:
                                                                {xTu[5:3],2'b00}+trafoSize[6:1]-1;
                end
                if (tq_cr_rst) begin
                    o_tq_cr_end_x               <= trafoSize[2]?{xTu[5:3],2'b11}:
                                                                {xTu[5:3],2'b00}+trafoSize[6:1]-1;
                end



                if (set_qpy) begin
                    if (qp_cu > 52)//fix,if(i_qPY_PRED+CuQpDeltaVal>52), i_qPY_PRED+CuQpDeltaVal按reg signed，52也按reg signed为负数
                        o_QpY                   <= qp_cu - 52;
                    else
                        o_QpY                   <= qp_cu;
                    if (`log_i && slice_num>=`slice_begin && slice_num<=`slice_end)
                        $fdisplay(fd_log, "xBase %0d yBase %0d qPy_pred %0d qPy %0d",
                                   x0,y0,i_qPY_PRED,qp_cu > 52?qp_cu - 52:qp_cu);

                    set_qpy                     <= 0;
                end

                if (o_cIdx == 0 && log2TrafoSize > 2) begin
                    log2TrafoSize                <= log2TrafoSize-1;
                    trafoSize                    <= trafoSize[6:1];
                    last_scx_pre_max_bins_minus1 <= ((log2TrafoSize-1)<<1)-2;
                    last_scy_pre_max_bins_minus1 <= ((log2TrafoSize-1)<<1)-2;

                end
                if (o_cIdx == 0 && log2TrafoSize == 2 && blkIdx == 3) begin
                    xTu                          <= xTu - 4;
                    yTu                          <= yTu - 4;
                end

                if (o_cIdx == 2) begin
                    o_tu_state                   <= `tu_end;
                end else begin
                    //做这个判断时,色度Cb log2TrafoSize还未减, Cr已经减了
                    //需要一个reg cond_chroma_no_residual保存状态
                    if (o_cIdx == 0)
                        if (log2TrafoSize > 2 || (log2TrafoSize == 2 && blkIdx == 3))
                            cond_chroma_no_residual      <= 0;
                        else
                            cond_chroma_no_residual      <= 1;
                    if ((o_cIdx == 3 && o_cbf_luma) ||
                        (o_cIdx == 0 && cbf_cb && (log2TrafoSize > 2 || (log2TrafoSize == 2 && blkIdx == 3))) ||
                        (o_cIdx == 1 && cbf_cr && cond_chroma_no_residual == 0)) begin
                        coded_sub_block_flag             <= 1'b0;
                        coded_sub_block_flag_right       <= '{8{1'b0}};
                        coded_sub_block_flag_down        <= '{8{1'b0}};

                        if (i_transform_skip_enabled_flag &&
                            ~cu_transquant_bypass_flag &&
                            (log2TrafoSize == 2||(log2TrafoSize == 3 && o_cIdx == 0))) begin
                            o_dec_bin_en_gt1_etc         <= 1;
                            if (o_cIdx == 3)
                                o_cm_idx_gt1_etc         <= `CM_IDX_TRANSFORM_SKIP_FLAG;
                            else
                                o_cm_idx_gt1_etc         <= `CM_IDX_TRANSFORM_SKIP_FLAG+1;

                            o_tu_state                   <= `transform_skip_flag_s;
                        end else begin
                            o_dec_bin_en_xy_pref         <= 1;
                            if (o_cIdx == 3)
                                o_cm_idx_xy_pref         <= `CM_IDX_LAST_SIG_COEFF_X_PREFIX+ctxOffset_cIdx0;
                            else
                                o_cm_idx_xy_pref         <= `CM_IDX_LAST_SIG_COEFF_X_PREFIX+15;
                            o_tu_state                   <= `last_sig_coeff_x_prefix_s;
                            last_sig_coeff_x_prefix      <= 0;
                        end
                    end else begin
                        o_tu_state                       <= `parse_residual_coding;

                        if (`log_i && slice_num>=`slice_begin && slice_num<=`slice_end &&
                             (o_cbf_luma || cbf_cb || cbf_cr)) begin
                            if (o_cIdx == 0 && log2TrafoSize == 2 && blkIdx == 3)
                                $fdisplay(fd_log, "+parse_residual_coding cIdx %0d x0 %0d y0 %0d blkIdx %0d no residual",
                                           o_cIdx==3?0:o_cIdx+1,
                                           {x0[`max_x_bits-1:6],xTu}-4,
                                           {y0[`max_y_bits-1:6],yTu}-4,blkIdx);
                            else if (o_cIdx == 3)
                                $fdisplay(fd_log, "+parse_residual_coding cIdx %0d x0 %0d y0 %0d log2TrafoSize %0d blkIdx %0d no residual",
                                           o_cIdx==3?0:o_cIdx+1,
                                           {x0[`max_x_bits-1:6],xTu},
                                           {y0[`max_y_bits-1:6],yTu},
                                           log2TrafoSize,blkIdx);
                            else
                                $fdisplay(fd_log, "+parse_residual_coding cIdx %0d x0 %0d y0 %0d blkIdx %0d no residual",
                                           o_cIdx==3?0:o_cIdx+1,
                                           {x0[`max_x_bits-1:6],xTu},
                                           {y0[`max_y_bits-1:6],yTu},blkIdx);
                        end

                    end
                end
            end



        `get_last_sub_block_scan_pos_1://d
            begin
                //这个周期LastSignificantCoeffX,LastSignificantCoeffY准备好,
                //下个周期lastScanPos,lastSubBlock才从ram出来
                if (`log_i && slice_num>=`slice_begin && slice_num<=`slice_end) begin
                    $fdisplay(fd_log, "LastSignificantCoeffX %0d LastSignificantCoeffY %0d",
                     scanIdx == `SCAN_VERT?LastSignificantCoeffY:LastSignificantCoeffX,
                     scanIdx == `SCAN_VERT?LastSignificantCoeffX:LastSignificantCoeffY);
                 end
                if (log2TrafoSize==5)
                    {lastSubBlock,lastScanPos}          <= scan_order_sz32x32[{LastSignificantCoeffY,
                                                                              LastSignificantCoeffX}];
                else if (log2TrafoSize==4)
                    {lastSubBlock,lastScanPos}          <= scan_order_sz16x16[{LastSignificantCoeffY[3:0],
                                                                               LastSignificantCoeffX[3:0]}];
                else
                    {lastSubBlock,lastScanPos}          <= scan_order_sz8x8_4x4[{scanIdx,log2TrafoSize[1],
                                                                                 LastSignificantCoeffY[2:0],
                                                                                 LastSignificantCoeffX[2:0]}];
                o_tu_state                              <= `get_last_sub_block_scan_pos_2;

            end
        `get_last_sub_block_scan_pos_2://e
            begin
                i                                       <= lastSubBlock;
                n                                       <= lastScanPos; //sig_coeff_ctx_inc是n-1来求的，求完再减1
                o_tu_state                              <= `get_last_sub_block_scan_pos_3;

            end
        `get_last_sub_block_scan_pos_3://2
            begin
                xS_r                                    <= xS;
                yS_r                                    <= yS;
                xP_r                                    <= xP; //xP_r,yP_r这两个赋了暂时没啥用
                yP_r                                    <= yP;
                sig_coeff_xp[0]                         <= xP;
                sig_coeff_yp[0]                         <= yP;
                if (o_cIdx == 0) begin
                    luma_x_lmt                          <= {xS,xP};
                    luma_y_lmt[{xS,xP}]                 <= {1'b0,yS,yP};
                end else if (o_cIdx == 1) begin
                    cb_x_lmt                            <= {xS[1:0],xP};
                    cb_y_lmt[{xS[1:0],xP}]              <= {1'b0,yS[1:0],yP};
                end else begin
                    cr_x_lmt                            <= {xS[1:0],xP};
                    cr_y_lmt[{xS[1:0],xP}]              <= {1'b0,yS[1:0],yP};
                end

                sig_coeff_cnt                       <= 1;
                sig_coeff_cnt_minus1                <= 0;
                sig_coeff_cnt_pls1                  <= 2;
                sig_coeff_indices[0]                <= lastScanPos;
                baseLevel[0]                        <= 1;
                //第lastSubBlock个子块inferSbcDcSigCoeffFlag初始为0,DC也需解码

                //进到这里greater1Ctx是最开始初始化的1,i=lastSubBlock, i>0&&cIdx==0即lastSubBlock>0&&cIdx==0
                ctxSet_r                            <= (lastSubBlock > 0 && o_cIdx == 0) ? 2 : 0;

                if (lastScanPos == 0) begin
                    if (o_cIdx == 0)
                        o_cm_idx_gt1_etc               <= `CM_IDX_COEFF_ABS_LEVEL_GREAT1_FLAG+
                                                               ((lastSubBlock > 0)?9:1);
                    else
                        o_cm_idx_gt1_etc               <= `CM_IDX_COEFF_ABS_LEVEL_GREAT1_FLAG+17;
                    o_dec_bin_en_gt1_etc               <= 1;
                    o_tu_state                         <= `coeff_abs_level_greater1_flag_s;
                    m                                  <= 0;

                    lastSigScanPos                     <= 0;
                    firstSigScanPos                    <= 0;
                end else begin
                    //sig_flag_ctx_inc依赖的xC,yC等依赖i,n还没准备好
                    o_tu_state                          <= `sig_coeff_flag_ctx;
                end
            end

        `sig_coeff_flag_ctx://0x11
            begin
                coded_sub_block_flag_down[xS]         <= 1;
                coded_sub_block_flag_right[yS]        <= 1;
                sigCtx_r                              <= sigCtx;
                n                                     <= n-1;
                //路径太长，分割开
                o_tu_state                            <= `sig_coeff_flag_ctx_2;
            end

        `sig_coeff_flag_ctx_2://0x1b
            begin
                //此时prevCsbf必是0，因为上下左右coded_sub_block_flag都还没解过都是0
                if (o_cIdx == 0)
                    o_cm_idx_sig                    <= `CM_IDX_SIG_FLAG + sigCtx_r;
                else
                    o_cm_idx_sig                    <= `CM_IDX_SIG_FLAG + sigCtx_r + 27;

                o_dec_bin_en_sig                    <= 1;
                o_tu_state                          <= `sig_coeff_flag_s;
            end

        `next_sub_block://0x17
            begin
                yS_r                           <= yS;
                xS_r                           <= xS;
                //sigCtx,csbf_ctx_inc依赖这2个东西，只为等这两就位
                csbfCtx                        <= coded_sub_block_flag_down[xS] + coded_sub_block_flag_right[yS];
                prevCsbf                       <= (coded_sub_block_flag_down[xS]<<1) + coded_sub_block_flag_right[yS];
                inferSbDcSigCoeffFlag          <= 0;
                o_tu_state                     <= `next_sub_block_1;

                if (sign_hidden_r && abs_lvl_first_sig) begin
                    if (`log_v && slice_num>=`slice_begin && slice_num<=`slice_end)
                        $fdisplay(fd_log, "store coeff first sig %s%0d",sumAbsLevel[0]?"-":"",abs_lvl_first_sig);
                    if (o_cIdx == 0) begin
                        bram_coeff_luma_dec_we   <= 1;
                        bram_coeff_luma_dec_addr <= {yS_r,first_sig_yp,xS_r,first_sig_xp};
                        bram_coeff_luma_dec_din  <= {sumAbsLevel[0],abs_lvl_first_sig};
                    end else if (o_cIdx == 1) begin
                        bram_coeff_cb_dec_we     <= 1;
                        bram_coeff_cb_dec_addr   <= {yS_r[1:0],first_sig_yp,xS_r[1:0],first_sig_xp};
                        bram_coeff_cb_dec_din    <= {sumAbsLevel[0],abs_lvl_first_sig};
                    end else begin
                        bram_coeff_cr_dec_we     <= 1;
                        bram_coeff_cr_dec_addr   <= {yS_r[1:0],first_sig_yp,xS_r[1:0],first_sig_xp};
                        bram_coeff_cr_dec_din    <= {sumAbsLevel[0],abs_lvl_first_sig};
                    end
                end
                sign_hidden_r                   <= 0;
                abs_lvl_first_sig               <= 0;
                first_sig_xp                    <= 0;
                first_sig_yp                    <= 0;
                sumAbsLevel                     <= 0;

            end

        `next_sub_block_1://0x1a
            begin
                numGreater1Flag                <= 0;

                firstSigScanPos                <= 16;
                lastSigScanPos                 <= -1;
                numGreater1Flag                <= 0;
                lastGreater1ScanPos            <= -1;

                if (`log_i && slice_num>=`slice_begin && slice_num<=`slice_end)
                    $fdisplay(fd_log, "prevCsbf %0d csbfCtx %0d csbf right %0d down %0d xS %0d yS %0d",
                        prevCsbf,
                        csbfCtx,
                        coded_sub_block_flag_right[yS],coded_sub_block_flag_down[xS],
                        xS,yS);

                //n什么时候置0的，`coeff_abs_level_remaining_s_2等其他状态跳到`next_sub_block的时候，
                //这里sigCtx_r存入的是n=0,xP_nxt=3,yP_nxt=3时的sigCtx
                sigCtx_r                       <= sigCtx;
                n                              <= n-1;//0-1=15

                if (i == 0) begin
                    o_tu_state                 <= `next_sub_block_2;
                end else begin
                    o_cm_idx_gt1_etc           <= `CM_IDX_CODED_SUB_BLOCK_FLAG+csbf_ctx_inc;
                    o_dec_bin_en_gt1_etc       <= 1;
                    inferSbDcSigCoeffFlag      <= 1;
                    o_tu_state                 <= `coded_sub_block_flag_s;
                end

                if (`log_v && slice_num>=`slice_begin && slice_num<=`slice_end)
                    $fdisplay(fd_log, "next_sub_block i %d", i);

            end

        `next_sub_block_2:
            begin

                if (o_cIdx == 0)
                    o_cm_idx_sig               <= `CM_IDX_SIG_FLAG + sigCtx_r;
                else
                    o_cm_idx_sig               <= `CM_IDX_SIG_FLAG + sigCtx_r + 27;
                o_dec_bin_en_sig               <= 1;
                sig_coeff_cnt                  <= 0;
                sig_coeff_cnt_pls1             <= 1;
                o_tu_state                     <= `sig_coeff_flag_s;

                ctxSet_r                       <= ctxSet;
                greater1Ctx                    <= 1;
            end

        `clr_sub_block_bram:
            begin
                clr_i                          <= clr_i+1;
                if (o_cIdx == 0) begin
                    bram_coeff_luma_dec_we     <= 1;
                    bram_coeff_luma_dec_addr   <= {yS_r,clr_i[3:2],xS_r,clr_i[1:0]};
                    bram_coeff_luma_dec_din    <= 0;
                end else if (o_cIdx == 1) begin
                    bram_coeff_cb_dec_we       <= 1;
                    bram_coeff_cb_dec_addr     <= {yS_r[1:0],clr_i[3:2],xS_r[1:0],clr_i[1:0]};
                    bram_coeff_cb_dec_din      <= 0;
                end else begin
                    bram_coeff_cr_dec_we       <= 1;
                    bram_coeff_cr_dec_addr     <= {yS_r[1:0],clr_i[3:2],xS_r[1:0],clr_i[1:0]};
                    bram_coeff_cr_dec_din      <= 0;
                end
                if (clr_i==15) begin
                    //跳到下一个subblock
                    if (i == 0) begin
                        o_tu_state             <= `parse_residual_coding;
                    end else begin
                        i                      <= i-1;
                        n                      <= 0;
                        o_tu_state             <= `next_sub_block;
                    end
                end

            end


        `tu_end:
            begin

            end

        //default: o_cu_state              <= `rst_cu;
    endcase
end


wire     [6:0]     cu_end_x_luma;
wire     [5:0]     cu_end_x_chroma;
assign cu_end_x_luma = x0[5:0]+CbSize;
assign cu_end_x_chroma = x0[5:1]+CbSize[6:1];

trans_quant_32 trans_quant_luma
(
    .clk                        (clk),
    .rst                        (tq_luma_rst),
    .global_rst                 (global_rst),
    .en                         (1'b1),
    .i_slice_num                (i_slice_num),
    .i_x0                       (x0),
    .i_y0                       (y0),
    .i_xTu                      (xTu),
    .i_yTu                      (yTu),

    .i_log2TrafoSize            (log2TrafoSize),
    .i_trafoSize                (trafoSize),
    .i_cIdx                     (o_cIdx),
    .i_qp                       (o_QpY),
    .i_cbf                      (o_cbf_luma), //这3个在tq rst的时候传入，是在`parse_residual_coding,起码要等到`tu_end之后才会变，肯定是本次的
    .i_predmode                 (i_pred_mode),
    .i_cu_end_x                 (cu_end_x_luma),
    .i_type                     (o_cIdx==0 && trafoSize==4 &&
                                 i_pred_mode == `MODE_INTRA),

    .i_x_lmt                    (luma_x_lmt),
    .i_y_lmt                    (luma_y_lmt),

    .bram_coeff_addr            (bram_coeff_luma_trafo_addr),
    .bram_coeff_dout            (bram_coeff_luma_trafo_dout),

    .i_transform_skip_flag      (transform_skip_flag),
    .i_transquant_bypass        (cu_transquant_bypass_flag),

    .dram_tq_we                 (dram_tq_we),
    .dram_tq_addrd              (dram_tq_addrd),
    .dram_tq_did                (dram_tq_did),
    .o_tq_done_y                (o_tq_luma_done_y),


    .fd_log                     (fd_tq_luma),

    .o_trans_quant_state        (o_tq_luma_state)

);


trans_quant_16 trans_quant_cb
(
    .clk                        (clk),
    .rst                        (tq_cb_rst),
    .global_rst                 (global_rst),
    .en                         (1'b1),
    .i_slice_num                (i_slice_num),
    .i_x0                       (x0[`max_x_bits-1:1]),
    .i_y0                       (y0[`max_y_bits-1:1]),
    .i_xTu                      (xTu[5:1]),//为什么不是{xTu[5:3],2'b00}，在`parse_residual_coding_2里xTu,yTu减过4了
    .i_yTu                      (yTu[5:1]),

    .i_log2TrafoSize            (log2TrafoSize),
    .i_trafoSize                (trafoSize[5:0]),//不是trafoSize[6:1],在cIdx变为1时更新过了
    .i_cIdx                     (o_cIdx),
    .i_cbf                      (cbf_cb),
    .i_predmode                 (i_pred_mode),
    .i_cu_end_x                 (cu_end_x_chroma),
    .i_qp                       (qp_cb),

    .i_x_lmt                    (cb_x_lmt),
    .i_y_lmt                    (cb_y_lmt),

    .bram_coeff_addr            (bram_coeff_cb_trafo_addr),
    .bram_coeff_dout            (bram_coeff_cb_trafo_dout),

    .i_transform_skip_flag      (transform_skip_flag),
    .i_transquant_bypass        (cu_transquant_bypass_flag),

    .dram_tq_we                 (dram_tq_cb_we),
    .dram_tq_addrd              (dram_tq_cb_addrd),
    .dram_tq_did                (dram_tq_cb_did),
    .o_tq_done_y                (o_tq_cb_done_y),
    .o_tq_tu_x                  (o_tq_cb_x),
    .o_tq_tu_y                  (o_tq_cb_y),

    .fd_log                     (fd_tq_cb),

    .o_trans_quant_state        (o_tq_cb_state)

);

trans_quant_16 trans_quant_cr
(
    .clk                        (clk),
    .rst                        (tq_cr_rst),
    .global_rst                 (global_rst),
    .en                         (1'b1),
    .i_slice_num                (i_slice_num),
    .i_x0                       (x0[`max_x_bits-1:1]),
    .i_y0                       (y0[`max_y_bits-1:1]),
    .i_xTu                      (xTu[5:1]),
    .i_yTu                      (yTu[5:1]),

    .i_log2TrafoSize            (log2TrafoSize),
    .i_trafoSize                (trafoSize[5:0]),
    .i_cIdx                     (o_cIdx),
    .i_qp                       (qp_cr),
    .i_cbf                      (cbf_cr),
    .i_predmode                 (i_pred_mode),
    .i_cu_end_x                 (cu_end_x_chroma),
    .i_x_lmt                    (cr_x_lmt),
    .i_y_lmt                    (cr_y_lmt),

    .bram_coeff_addr            (bram_coeff_cr_trafo_addr),
    .bram_coeff_dout            (bram_coeff_cr_trafo_dout),

    .i_transform_skip_flag      (transform_skip_flag),
    .i_transquant_bypass        (cu_transquant_bypass_flag),

    .dram_tq_we                 (dram_tq_cr_we),
    .dram_tq_addrd              (dram_tq_cr_addrd),
    .dram_tq_did                (dram_tq_cr_did),
    .o_tq_done_y                (o_tq_cr_done_y),
    .o_tq_tu_x                  (o_tq_cr_x),
    .o_tq_tu_y                  (o_tq_cr_y),

    .fd_log                     (fd_tq_cr),
    .o_trans_quant_state        (o_tq_cr_state)

);


`ifdef RANDOM_INIT
integer  seed;
integer random_val;
initial  begin
    seed                                         = $get_initial_random_seed(); 
    random_val                                   = $random(seed);
    o_IsCuQpDeltaCoded                           = {random_val,random_val};
    o_QpY                                        = {random_val[1:0],random_val[31:2],random_val[1:0],random_val[31:2]};
    o_tu_state                                   = {random_val[2:0],random_val[31:3],random_val[2:0],random_val[31:3]};
    o_cm_idx_xy_pref                             = {random_val[3:0],random_val[31:4],random_val[3:0],random_val[31:4]};
    o_cm_idx_sig                                 = {random_val[4:0],random_val[31:5],random_val[4:0],random_val[31:5]};
    o_cm_idx_gt1_etc                             = {random_val[5:0],random_val[31:6],random_val[5:0],random_val[31:6]};
    o_dec_bin_en_xy_pref                         = {random_val[6:0],random_val[31:7],random_val[6:0],random_val[31:7]};
    o_dec_bin_en_sig                             = {random_val[7:0],random_val[31:8],random_val[7:0],random_val[31:8]};
    o_dec_bin_en_gt1_etc                         = {random_val[8:0],random_val[31:9],random_val[8:0],random_val[31:9]};
    o_byp_dec_en_tu                              = {random_val[9:0],random_val[31:10],random_val[9:0],random_val[31:10]};
    o_tq_luma_end_x                              = {random_val[10:0],random_val[31:11],random_val[10:0],random_val[31:11]};
    o_tq_cb_end_x                                = {random_val[11:0],random_val[31:12],random_val[11:0],random_val[31:12]};
    o_tq_cr_end_x                                = {random_val[12:0],random_val[31:13],random_val[12:0],random_val[31:13]};
    o_cbf_luma                                   = {random_val[13:0],random_val[31:14],random_val[13:0],random_val[31:14]};
    o_cIdx                                       = {random_val[14:0],random_val[31:15],random_val[14:0],random_val[31:15]};
    slice_num                                    = {random_val[15:0],random_val[31:16],random_val[15:0],random_val[31:16]};
    x0                                           = {random_val[16:0],random_val[31:17],random_val[16:0],random_val[31:17]};
    y0                                           = {random_val[17:0],random_val[31:18],random_val[17:0],random_val[31:18]};
    xTu                                          = {random_val[18:0],random_val[31:19],random_val[18:0],random_val[31:19]};
    yTu                                          = {random_val[19:0],random_val[31:20],random_val[19:0],random_val[31:20]};
    CbSize                                       = {random_val[20:0],random_val[31:21],random_val[20:0],random_val[31:21]};
    i                                            = {random_val[21:0],random_val[31:22],random_val[21:0],random_val[31:22]};
    j                                            = {random_val[22:0],random_val[31:23],random_val[22:0],random_val[31:23]};
    clr_i                                        = {random_val[23:0],random_val[31:24],random_val[23:0],random_val[31:24]};
    cbf_cb                                       = {random_val[24:0],random_val[31:25],random_val[24:0],random_val[31:25]};
    cbf_cr                                       = {random_val[25:0],random_val[31:26],random_val[25:0],random_val[31:26]};
    trafoDepth                                   = {random_val[26:0],random_val[31:27],random_val[26:0],random_val[31:27]};
    log2TrafoSize                                = {random_val[27:0],random_val[31:28],random_val[27:0],random_val[31:28]};
    trafoSize                                    = {random_val[28:0],random_val[31:29],random_val[28:0],random_val[31:29]};
    blkIdx                                       = {random_val[29:0],random_val[31:30],random_val[29:0],random_val[31:30]};
    cu_transquant_bypass_flag                    = {random_val[30:0],random_val[31],random_val[30:0],random_val[31]};
    inferSbDcSigCoeffFlag                        = {random_val[31:0],random_val[31:0]};
    lastSubBlock                                 = {random_val,random_val};
    lastScanPos                                  = {random_val[1:0],random_val[31:2],random_val[1:0],random_val[31:2]};
    sig_coeff_indices                            = {random_val[3:0],random_val[3:0],random_val[3:0],random_val[3:0],
                                                    random_val[3:0],random_val[3:0],random_val[3:0],random_val[3:0],
                                                    random_val[3:0],random_val[3:0],random_val[3:0],random_val[3:0],
                                                    random_val[3:0],random_val[3:0],random_val[3:0],random_val[3:0]};
    sig_coeff_cnt                                = {random_val[3:0],random_val[31:4],random_val[3:0],random_val[31:4]};
    sig_coeff_cnt_minus1                         = {random_val[4:0],random_val[31:5],random_val[4:0],random_val[31:5]};
    sig_coeff_cnt_pls1                           = {random_val[5:0],random_val[31:6],random_val[5:0],random_val[31:6]};
    coeff_sign_flag                              = {random_val[0],random_val[0],random_val[0],random_val[0],
                                                    random_val[0],random_val[0],random_val[0],random_val[0],
                                                    random_val[0],random_val[0],random_val[0],random_val[0],
                                                    random_val[0],random_val[0],random_val[0],random_val[0]};
    lvl_rem_indices                              = {random_val[3:0],random_val[3:0],random_val[3:0],random_val[3:0],
                                                    random_val[3:0],random_val[3:0],random_val[3:0],random_val[3:0],
                                                    random_val[3:0],random_val[3:0],random_val[3:0],random_val[3:0],
                                                    random_val[3:0],random_val[3:0],random_val[3:0],random_val[3:0]};
    lvl_rem_cnt                                  = {random_val[8:0],random_val[31:9],random_val[8:0],random_val[31:9]};
    lvl_rem_cnt_minus1                           = {random_val[9:0],random_val[31:10],random_val[9:0],random_val[31:10]};
    cond_chroma_no_residual                      = {random_val[10:0],random_val[31:11],random_val[10:0],random_val[31:11]};
    CuQpDeltaVal                                 = {random_val[12:0],random_val[31:13],random_val[12:0],random_val[31:13]};
    prefixVal                                    = {random_val[13:0],random_val[31:14],random_val[13:0],random_val[31:14]};
    suffixVal                                    = {random_val[14:0],random_val[31:15],random_val[14:0],random_val[31:15]};
    transform_skip_flag                          = {random_val[15:0],random_val[31:16],random_val[15:0],random_val[31:16]};
    ctxOffset                                    = {random_val[16:0],random_val[31:17],random_val[16:0],random_val[31:17]};
    ctxShift                                     = {random_val[17:0],random_val[31:18],random_val[17:0],random_val[31:18]};
    k                                            = {random_val[18:0],random_val[31:19],random_val[18:0],random_val[31:19]};
    last_sig_coeff_x_prefix                      = {random_val[19:0],random_val[31:20],random_val[19:0],random_val[31:20]};
    last_sig_coeff_y_prefix                      = {random_val[20:0],random_val[31:21],random_val[20:0],random_val[31:21]};
    last_sig_coeff_x_suffix                      = {random_val[21:0],random_val[31:22],random_val[21:0],random_val[31:22]};
    last_sig_coeff_y_suffix                      = {random_val[22:0],random_val[31:23],random_val[22:0],random_val[31:23]};
    LastSignificantCoeffX                        = {random_val[23:0],random_val[31:24],random_val[23:0],random_val[31:24]};
    LastSignificantCoeffY                        = {random_val[24:0],random_val[31:25],random_val[24:0],random_val[31:25]};
    scanIdxY                                     = {random_val[25:0],random_val[31:26],random_val[25:0],random_val[31:26]};
    scanIdxC                                     = {random_val[26:0],random_val[31:27],random_val[26:0],random_val[31:27]};
    scanIdx                                      = {random_val[27:0],random_val[31:28],random_val[27:0],random_val[31:28]};
    n                                            = {random_val[28:0],random_val[31:29],random_val[28:0],random_val[31:29]};
    m                                            = {random_val[29:0],random_val[31:30],random_val[29:0],random_val[31:30]};
    m1                                           = {random_val[30:0],random_val[31],random_val[30:0],random_val[31]};
    last_scx_pre_max_bins_minus1                 = {random_val[31:0],random_val[31:0]};
    last_scy_pre_max_bins_minus1                 = {random_val,random_val};
    last_scx_suf_max_bins_minus1                 = {random_val[1:0],random_val[31:2],random_val[1:0],random_val[31:2]};
    last_scy_suf_max_bins_minus1                 = {random_val[2:0],random_val[31:3],random_val[2:0],random_val[31:3]};
    last_scx_pre_ctx_inc                         = {random_val[3:0],random_val[31:4],random_val[3:0],random_val[31:4]};
    last_scy_pre_ctx_inc                         = {random_val[4:0],random_val[31:5],random_val[4:0],random_val[31:5]};
    cm_idx_gt1                                   = {random_val[5:0],random_val[31:6],random_val[5:0],random_val[31:6]};
    cm_idx_gt1_pred_bin0                         = {random_val[6:0],random_val[31:7],random_val[6:0],random_val[31:7]};
    cm_idx_gt1_pred_bin1                         = {random_val[7:0],random_val[31:8],random_val[7:0],random_val[31:8]};
    cm_idx_gt2                                   = {random_val[8:0],random_val[31:9],random_val[8:0],random_val[31:9]};
    binIdx                                       = {random_val[9:0],random_val[31:10],random_val[9:0],random_val[31:10]};
    cond_last_scy_pre_gt3                        = {random_val[10:0],random_val[31:11],random_val[10:0],random_val[31:11]};
    cond_last_scy_pre_gt2                        = {random_val[11:0],random_val[31:12],random_val[11:0],random_val[31:12]};
    cond_last_scx_pre_gt3                        = {random_val[12:0],random_val[31:13],random_val[12:0],random_val[31:13]};
    last_scy_pre_pls1                            = {random_val[13:0],random_val[31:14],random_val[13:0],random_val[31:14]};
    last_scx_pre_pls1                            = {random_val[14:0],random_val[31:15],random_val[14:0],random_val[31:15]};
    coded_sub_block_flag                         = {random_val[15:0],random_val[31:16],random_val[15:0],random_val[31:16]};
    coded_sub_block_flag_right                   = {random_val[0],random_val[0],random_val[0],random_val[0],
                                                    random_val[0],random_val[0],random_val[0],random_val[0]};
    coded_sub_block_flag_down                    = {random_val[0],random_val[0],random_val[0],random_val[0],
                                                    random_val[0],random_val[0],random_val[0],random_val[0]};
    xS                                           = {random_val[18:0],random_val[31:19],random_val[18:0],random_val[31:19]};
    yS                                           = {random_val[19:0],random_val[31:20],random_val[19:0],random_val[31:20]};
    xS_r                                         = {random_val[20:0],random_val[31:21],random_val[20:0],random_val[31:21]};
    yS_r                                         = {random_val[21:0],random_val[31:22],random_val[21:0],random_val[31:22]};
    xP                                           = {random_val[22:0],random_val[31:23],random_val[22:0],random_val[31:23]};
    yP                                           = {random_val[23:0],random_val[31:24],random_val[23:0],random_val[31:24]};
    xP_nxt                                       = {random_val[24:0],random_val[31:25],random_val[24:0],random_val[31:25]};
    yP_nxt                                       = {random_val[25:0],random_val[31:26],random_val[25:0],random_val[31:26]};
    xP_r                                         = {random_val[26:0],random_val[31:27],random_val[26:0],random_val[31:27]};
    yP_r                                         = {random_val[27:0],random_val[31:28],random_val[27:0],random_val[31:28]};
    sig_flag_ctx_inc                             = {random_val[28:0],random_val[31:29],random_val[28:0],random_val[31:29]};
    sigCtx                                       = {random_val[29:0],random_val[31:30],random_val[29:0],random_val[31:30]};
    sigCtx_r                                     = {random_val[30:0],random_val[31],random_val[30:0],random_val[31]};
    prevCsbf                                     = {random_val[31:0],random_val[31:0]};
    csbf_ctx_inc                                 = {random_val,random_val};
    csbfCtx                                      = {random_val[1:0],random_val[31:2],random_val[1:0],random_val[31:2]};
    numGreater1Flag                              = {random_val[2:0],random_val[31:3],random_val[2:0],random_val[31:3]};
    firstSigScanPos                              = {random_val[3:0],random_val[31:4],random_val[3:0],random_val[31:4]};
    lastSigScanPos                               = {random_val[4:0],random_val[31:5],random_val[4:0],random_val[31:5]};
    lastGreater1ScanPos                          = {random_val[5:0],random_val[31:6],random_val[5:0],random_val[31:6]};
    lastGreater1ScanPos_1                        = {random_val[6:0],random_val[31:7],random_val[6:0],random_val[31:7]};
    ctxSet                                       = {random_val[7:0],random_val[31:8],random_val[7:0],random_val[31:8]};
    ctxSet_r                                     = {random_val[8:0],random_val[31:9],random_val[8:0],random_val[31:9]};
    greater1Ctx                                  = {random_val[9:0],random_val[31:10],random_val[9:0],random_val[31:10]};
    sign_hidden_r                                = {random_val[10:0],random_val[31:11],random_val[10:0],random_val[31:11]};
    sumAbsLevel                                  = {random_val[11:0],random_val[31:12],random_val[11:0],random_val[31:12]};
    cRiceParam                                   = {random_val[12:0],random_val[31:13],random_val[12:0],random_val[31:13]};
    abs_lvl_first_sig                            = {random_val[13:0],random_val[31:14],random_val[13:0],random_val[31:14]};
    first_sig_xp                                 = {random_val[14:0],random_val[31:15],random_val[14:0],random_val[31:15]};
    first_sig_yp                                 = {random_val[15:0],random_val[31:16],random_val[15:0],random_val[31:16]};
    c_rice_param_nxt                             = {random_val[16:0],random_val[31:17],random_val[16:0],random_val[31:17]};
    lvl_rem_suf_max_bins_minus1                  = {random_val[17:0],random_val[31:18],random_val[17:0],random_val[31:18]};
    abs_lvl_thresh                               = {random_val[18:0],random_val[31:19],random_val[18:0],random_val[31:19]};
    abs_lvl_thresh_minus1                        = {random_val[19:0],random_val[31:20],random_val[19:0],random_val[31:20]};
    abs_lvl_thresh_minus2                        = {random_val[20:0],random_val[31:21],random_val[20:0],random_val[31:21]};
    abs_lvl_thresh_minus3                        = {random_val[21:0],random_val[31:22],random_val[21:0],random_val[31:22]};
    cond_abs_lvl_gt_thresh_prev_bin0             = {random_val[22:0],random_val[31:23],random_val[22:0],random_val[31:23]};
    cond_abs_lvl_gt_thresh_minus1_prev_bin0      = {random_val[23:0],random_val[31:24],random_val[23:0],random_val[31:24]};
    cond_abs_lvl_gt_thresh_prev_bin1             = {random_val[24:0],random_val[31:25],random_val[24:0],random_val[31:25]};
    cond_abs_lvl_gt_thresh_minus1_prev_bin1      = {random_val[25:0],random_val[31:26],random_val[25:0],random_val[31:26]};
    lvl_rem_suf_prev_bin                         = {random_val[26:0],random_val[31:27],random_val[26:0],random_val[31:27]};
    baseLevel                                    = {random_val[1:0],random_val[1:0],random_val[1:0],random_val[1:0],
                                                    random_val[1:0],random_val[1:0],random_val[1:0],random_val[1:0],
                                                    random_val[1:0],random_val[1:0],random_val[1:0],random_val[1:0],
                                                    random_val[1:0],random_val[1:0],random_val[1:0],random_val[1:0]};
    sig_coeff_xp                                 = {random_val[1:0],random_val[1:0],random_val[1:0],random_val[1:0],
                                                    random_val[1:0],random_val[1:0],random_val[1:0],random_val[1:0],
                                                    random_val[1:0],random_val[1:0],random_val[1:0],random_val[1:0],
                                                    random_val[1:0],random_val[1:0],random_val[1:0],random_val[1:0]};
    sig_coeff_yp                                 = {random_val[1:0],random_val[1:0],random_val[1:0],random_val[1:0],
                                                    random_val[1:0],random_val[1:0],random_val[1:0],random_val[1:0],
                                                    random_val[1:0],random_val[1:0],random_val[1:0],random_val[1:0],
                                                    random_val[1:0],random_val[1:0],random_val[1:0],random_val[1:0]};
    sig_coeff_sign                               = {random_val[0],random_val[0],random_val[0],random_val[0],
                                                    random_val[0],random_val[0],random_val[0],random_val[0],
                                                    random_val[0],random_val[0],random_val[0],random_val[0],
                                                    random_val[0],random_val[0],random_val[0],random_val[0]};
    cAbsLevel                                    = {random_val[31:0],random_val[31:0]};
    base_lvl                                     = {random_val,random_val};
    abs_lvl_pre_lt3                              = {random_val[1:0],random_val[31:2],random_val[1:0],random_val[31:2]};
    abs_lvl_pre_ge3                              = {random_val[2:0],random_val[31:3],random_val[2:0],random_val[31:3]};
    abs_lvl_pre                                  = {random_val[3:0],random_val[31:4],random_val[3:0],random_val[31:4]};
    prefix_lvl_rem                               = {random_val[4:0],random_val[31:5],random_val[4:0],random_val[31:5]};
    prefix_lvl_rem_pls1                          = {random_val[5:0],random_val[31:6],random_val[5:0],random_val[31:6]};
    prefix_lvl_rem_minus2                        = {random_val[6:0],random_val[31:7],random_val[6:0],random_val[31:7]};
    suffix_lvl_rem                               = {random_val[7:0],random_val[31:8],random_val[7:0],random_val[31:8]};
    coeff_luma_sel                               = {random_val[8:0],random_val[31:9],random_val[8:0],random_val[31:9]};
    coeff_cb_sel                                 = {random_val[9:0],random_val[31:10],random_val[9:0],random_val[31:10]};
    coeff_cr_sel                                 = {random_val[10:0],random_val[31:11],random_val[10:0],random_val[31:11]};
    component                                    = {random_val[11:0],random_val[31:12],random_val[11:0],random_val[31:12]};
    qp_cb                                        = {random_val[12:0],random_val[31:13],random_val[12:0],random_val[31:13]};
    qp_cr                                        = {random_val[13:0],random_val[31:14],random_val[13:0],random_val[31:14]};
    bram_coeff_luma_dec_we                       = {random_val[14:0],random_val[31:15],random_val[14:0],random_val[31:15]};
    bram_coeff_luma_dec_addr                     = {random_val[15:0],random_val[31:16],random_val[15:0],random_val[31:16]};
    bram_coeff_luma_dec_din                      = {random_val[16:0],random_val[31:17],random_val[16:0],random_val[31:17]};
    debug_flag1                                  = {random_val[17:0],random_val[31:18],random_val[17:0],random_val[31:18]};
    bram_coeff_cb_dec_we                         = {random_val[18:0],random_val[31:19],random_val[18:0],random_val[31:19]};
    bram_coeff_cb_dec_addr                       = {random_val[19:0],random_val[31:20],random_val[19:0],random_val[31:20]};
    bram_coeff_cb_dec_din                        = {random_val[20:0],random_val[31:21],random_val[20:0],random_val[31:21]};
    bram_coeff_cr_dec_we                         = {random_val[21:0],random_val[31:22],random_val[21:0],random_val[31:22]};
    bram_coeff_cr_dec_addr                       = {random_val[22:0],random_val[31:23],random_val[22:0],random_val[31:23]};
    bram_coeff_cr_dec_din                        = {random_val[23:0],random_val[31:24],random_val[23:0],random_val[31:24]};
    set_qpy                                      = {random_val[24:0],random_val[31:25],random_val[24:0],random_val[31:25]};
    tq_luma_en                                   = {random_val[25:0],random_val[31:26],random_val[25:0],random_val[31:26]};
    tq_luma_rst                                  = {random_val[26:0],random_val[31:27],random_val[26:0],random_val[31:27]};
    tq_cb_en                                     = {random_val[27:0],random_val[31:28],random_val[27:0],random_val[31:28]};
    tq_cb_rst                                    = {random_val[28:0],random_val[31:29],random_val[28:0],random_val[31:29]};
    tq_cr_en                                     = {random_val[29:0],random_val[31:30],random_val[29:0],random_val[31:30]};
    tq_cr_rst                                    = {random_val[30:0],random_val[31],random_val[30:0],random_val[31]};
    luma_y_lmt                                   = {random_val[31:0],random_val[31:0]};
    cb_y_lmt                                     = {random_val,random_val};
    cr_y_lmt                                     = {random_val[1:0],random_val[31:2],random_val[1:0],random_val[31:2]};
    luma_x_lmt                                   = {random_val[2:0],random_val[31:3],random_val[2:0],random_val[31:3]};
    cb_x_lmt                                     = {random_val[3:0],random_val[31:4],random_val[3:0],random_val[31:4]};
    cr_x_lmt                                     = {random_val[4:0],random_val[31:5],random_val[4:0],random_val[31:5]};
    luma_y_lmt_tmp                               = {random_val[5:0],random_val[31:6],random_val[5:0],random_val[31:6]};
    chroma_y_lmt_tmp                             = {random_val[6:0],random_val[31:7],random_val[6:0],random_val[31:7]};
    luma_y_lmt_pos00_tmp                         = {random_val[7:0],random_val[31:8],random_val[7:0],random_val[31:8]};
    chroma_y_lmt_pos00_tmp                       = {random_val[8:0],random_val[31:9],random_val[8:0],random_val[31:9]};
end
`endif



endmodule
