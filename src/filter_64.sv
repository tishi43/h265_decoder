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

module filter_64
(
 input wire                                 clk                        ,
 input wire                                 rst                        ,
 input wire                                 global_rst                 ,
 input wire                                 i_rst_slice                ,
 input wire                                 i_rst_ctb                  ,
 input wire                                 en                         ,
 input wire                    [15:0]       i_slice_num                ,

 input wire         [`max_x_bits-1:0]       i_x0                       ,
 input wire         [`max_y_bits-1:0]       i_y0                       ,

 input wire                                 i_first_row                ,
 input wire                                 i_first_col                ,
 input wire                                 i_last_row                 ,
 input wire                                 i_last_col                 ,
 input wire                    [ 6:0]       i_last_col_width           ,
 input wire                    [ 6:0]       i_last_row_height          ,

 input wire                    [ 3:0]       i_slice_beta_offset_div2   ,
 input wire                    [ 3:0]       i_slice_tc_offset_div2     ,
 input wire [$bits(sao_params_t)-1:0]       i_sao_param                ,
 input wire [$bits(sao_params_t)-1:0]       i_sao_param_left           ,
 input wire [$bits(sao_params_t)-1:0]       i_sao_param_up             ,
 input wire [$bits(sao_params_t)-1:0]       i_sao_param_leftup         ,

 input wire         [7:0][15:0][ 1:0]       i_bs_ver                   ,
 input wire         [7:0][15:0][ 1:0]       i_bs_hor                   ,

 input wire              [ 7:0][ 7:0]       i_nf                       ,
 input wire         [7:0][ 7:0][ 5:0]       i_qpy                      ,

 output reg              [63:0]             dram_rec_we                ,
 output reg              [63:0][ 5:0]       dram_rec_addra             ,
 output reg              [63:0][ 5:0]       dram_rec_addrb             ,
 output reg              [63:0][ 5:0]       dram_rec_addrd             ,
 output reg              [63:0][ 7:0]       dram_rec_did               ,
 input wire              [63:0][ 7:0]       dram_rec_doa               ,
 input wire              [63:0][ 7:0]       dram_rec_dob               ,
 input wire              [63:0][ 7:0]       dram_rec_dod               ,

 input wire              [ 7:0][ 7:0]       i_cu_predmode              ,

 input wire [15:0][$bits(MvField)-1:0]      i_cur_ctb_mvf              ,
 input wire [15:0][`max_poc_bits-1:0]       i_cur_ctb_ref_poc          ,

 input wire                    [47:0]       bram_up_ctb_qpy_dout       ,
 output reg     [`max_ctb_x_bits-1:0]       bram_up_ctb_qpy_addr       ,
 input wire                     [ 7:0]      bram_up_ctb_nf_dout        ,
 output reg     [`max_ctb_x_bits-1:0]       bram_up_ctb_nf_addr        ,

 input wire                    [31:0]       i_param_base_ddr           ,
 input wire                    [31:0]       i_pic_base_ddr             ,
 input wire                                 m_axi_awready              ,
 output reg                    [31:0]       m_axi_awaddr               ,
 output reg                    [ 3:0]       m_axi_awlen                ,
 output reg                                 m_axi_awvalid              ,

 input  wire                                m_axi_wready               ,
 output reg                    [63:0]       m_axi_wdata                ,
 output reg                    [ 7:0]       m_axi_wstrb                ,
 output reg                                 m_axi_wlast                ,
 output reg                                 m_axi_wvalid               ,


 input wire                    [31:0]       fd_filter                  ,
 input wire                    [31:0]       fd_deblock                 ,
 output reg                    [ 2:0]       o_filter_state

);

//when -label when1 "/bitstream_tb/decode_stream_inst/slice_data_inst/cu_inst/filter_64_inst/x0 == 12'h180 && /bitstream_tb/decode_stream_inst/slice_data_inst/cu_inst/filter_64_inst/y0 ==12'h80" {echo $now}

//                       x48 52 x56 60 x64
//       CTB0             |  |  a| b | c|            CTB1
//---------------------------------------  y56 
//                        |  |  d| e | f|
//---------------------------------------  y60
//                        |  |  g| h | i| 
//---------------------------------------  y64
//      CTB2                 |  j| k | l|            CTB3

//垂直滤波，可以滤到x56这条线，左右两边，a-b,d-e,g-h,
//水平滤波，可以滤到y56这条线，上下两边，a-d,b-e. c-f不行，因为c，f垂直滤波没滤完,c-f在CTB1水平滤波时滤
//g-j,h-k在CTB2水平滤波时滤，i-l在CTB3水平滤波时滤

reg             [ 3:0]          stage                    ;
reg             [ 4:0]          phase                    ;

reg  [`max_x_bits-1:0]          x0                       ;
reg  [`max_x_bits-1:0]          y0                       ;
reg             [ 5:0]          x                        ;
reg             [ 5:0]          y                        ;
reg             [ 5:0]          y_pls1                   ;
reg             [ 2:0]          y_minus58                ;
reg             [ 4:0]          i                        ;
reg  [`max_x_bits-1:0]          x0_minus8                ;
reg                             first_row                ;
reg                             first_col                ;
reg                             last_row                 ;
reg                             last_col                 ;
reg             [ 5:0]          last_row_height_minus1   ;
reg             [ 5:0]          last_col_width_minus1    ;
reg             [ 3:0]          prefetch_stage           ;
reg             [ 5:0]          fetch_x                  ;
reg             [ 5:0]          fetch_y                  ;
wire            [ 5:0]          fetch_y_pls1             ;
reg             [ 4:0]          fetch_i                  ; //0~16
wire            [ 5:0]          fetch_y_plsi             ;
wire            [ 4:0]          fetch_i_pls1             ;
reg             [ 3:0]          fetch_j                  ;
wire            [ 5:0]          fetch_y_plsj             ;
assign fetch_i_pls1 = fetch_i+1;
assign fetch_y_pls1 = fetch_y+1;
assign fetch_y_plsi = fetch_y+fetch_i;
assign fetch_y_plsj = fetch_y+fetch_j;

sao_params_t                    sao_param                ;
sao_params_t                    sao_param_left           ;
sao_params_t                    sao_param_up             ;
sao_params_t                    sao_param_leftup         ;


reg             [ 5:0]          last_fetch_x             ;
reg             [ 5:0]          last_fetch_y             ;
reg                             kick_deblock             ;
reg             [ 5:0]          x_to_deblock             ;
reg             [ 5:0]          y_to_deblock             ;
reg             [ 4:0]          i_to_deblock             ;

reg             [ 5:0]          store_x                  ;
reg             [ 5:0]          store_y                  ;
reg             [ 5:0]          x_to_store               ;
reg             [ 5:0]          y_to_store               ;
reg             [ 4:0]          i_to_store               ;

reg       [15:0][ 1:0]          bs_a_row                 ;
reg       [15:0][ 1:0]          bs_a_col                 ;

reg             [ 7:0]          nf_up_row                ;
reg             [ 7:0]          nf_down_row              ;
reg             [ 7:0]          nf_left_col              ;
reg             [ 7:0]          nf_right_col             ;
reg             [ 7:0]          nf_left_ctb_last_col     ;
reg       [ 7:0][ 5:0]          qpy_up_row               ;
reg       [ 7:0][ 5:0]          qpy_down_row             ;
reg       [ 7:0][ 5:0]          qpy_up_ctb               ;
reg       [ 7:0][ 5:0]          qpy_left_col             ;
reg       [ 7:0][ 5:0]          qpy_right_col            ;
reg       [ 7:0][ 5:0]          qpy_left_ctb_last_col    ;

reg             [ 6:0]          hor_deblock_done_y       ;
reg                             hor_deblock_done         ; //水平滤波完成，包括store

reg             [ 1:0]          bs                       ;


reg             [ 5:0]          QpP                      ;
reg             [ 5:0]          QpQ                      ;
reg                             bypass_p                 ;
reg                             bypass_q                 ;

reg       [ 7:0][ 7:0]          fetch_ver_a_row          ; //wire
reg       [ 3:0][ 7:0]          fetch_hor_a_row          ; //wire
reg             [ 1:0]          wait_cycle               ;

reg             [ 7:0]          p00                      ;
reg             [ 7:0]          p10                      ;
reg             [ 7:0]          p20                      ;
reg             [ 7:0]          p30                      ;
reg             [ 7:0]          p03                      ;
reg             [ 7:0]          p13                      ;
reg             [ 7:0]          p23                      ;
reg             [ 7:0]          p33                      ;
reg             [ 7:0]          q00                      ;
reg             [ 7:0]          q10                      ;
reg             [ 7:0]          q20                      ;
reg             [ 7:0]          q30                      ;
reg             [ 7:0]          q03                      ;
reg             [ 7:0]          q13                      ;
reg             [ 7:0]          q23                      ;
reg             [ 7:0]          q33                      ;

reg    [3:0][7:0][7:0]          pq_buf                   ;
reg    [3:0][7:0][7:0]          pq_buf_bk                ;

reg    [3:0][7:0][7:0]          deblock_buf              ;
reg    [3:0][7:0][7:0]          deblock_buf_bk           ;

reg       [71:0][ 7:0]          row_up0                  ;



reg             [ 7:0]          nf_up_ctb                ;


reg       [ 7:0][ 1:0]          bs_hor_left_ctb_last_col ;
reg             [ 1:0]          bs_hor_left_ctb_cur_row  ;
reg                             nf_leftup                ;
reg             [ 5:0]          qpy_leftup               ;
reg             [ 5:0]          qpy_leftup_bk            ; //下一ctb的备份
reg                             nf_leftup_bk             ;

wire            [ 2:0]          left_idx                 ;
wire            [ 2:0]          right_idx                ;
wire            [ 2:0]          up_idx                   ;
assign left_idx = fetch_x[5:3]-1;
assign right_idx = fetch_x[5:3];
assign up_idx    = fetch_y[5:3]-1;

//位宽32，存4像素，在`filter_fetch_up从bram取当前ctb的左上ctb和上ctb到dram，因为需要用到3口，bram只有2口
reg  [ 5:0]                   bram_up_6row_we;
reg  [ 5:0][`max_x_bits-3:0]  bram_up_6row_addra;
reg  [ 5:0][`max_x_bits-3:0]  bram_up_6row_addrb;
reg  [ 5:0][31:0]             bram_up_6row_dia;
wire [ 5:0][31:0]             bram_up_6row_doa;
wire [ 5:0][31:0]             bram_up_6row_dob;

//x=404对应bram地址404/4=101,dram地址404-384=20,20/4+2=7

always @ (*)
begin

    if (bram_up_6row_addra[2]==350&&bram_up_6row_dia[2][31:24]==56&&bram_up_6row_we[2]==1) begin
        $display("%t bram 56 x0 %d y0 %d",$time,x0,y0);
    end


    if (bram_up_6row_addra[2]==350&&bram_up_6row_dia[2][31:24]==57&&bram_up_6row_we[2]==1) begin
        $display("%t bram 57 x0 %d y0 %d",$time,x0,y0);
    end

end


always @ (*)
begin

    if (dram_rec_addrd[59]==61&&dram_rec_did[59]==56&&dram_rec_we[59]==1) begin
        $display("%t fil64 dram 56 x0 %d y0 %d",$time,x0,y0);
    end


    if (dram_rec_addrd[59]==61&&dram_rec_did[59]==57&&dram_rec_we[59]==1) begin
        $display("%t fil64 dram 57 x0 %d y0 %d",$time,x0,y0);
    end

end


always @ (*)
begin
    if (m_axi_awaddr==32'h2013d578&&m_axi_awvalid==1) begin
        $display("%t write ddr h2013d578",$time);
    end
end

genvar I;
generate
    for (I=0;I<6;I++)
    begin: bram_up_6rows_label
        ram_d #(`max_x_bits-2, 32) bram_up_6row
        (
            .clk(clk),
            .en(1'b1),
            .we(bram_up_6row_we[I]),
            .addra(bram_up_6row_addra[I]),
            .addrb(bram_up_6row_addrb[I]),
            .dia(bram_up_6row_dia[I]),
            .doa(bram_up_6row_doa[I]),
            .dob(bram_up_6row_dob[I])
        );
    end
endgenerate

reg          [ 7:0][ 7:0]       dram_right_8col_did;
reg          [ 7:0][ 5:0]       dram_right_8col_addra;
reg          [ 7:0][ 5:0]       dram_right_8col_addrb;
reg          [ 7:0][ 5:0]       dram_right_8col_addrd;
reg          [ 7:0]             dram_right_8col_we;
wire         [ 7:0][ 7:0]       dram_right_8col_doa;
wire         [ 7:0][ 7:0]       dram_right_8col_dob;
wire         [ 7:0][ 7:0]       dram_right_8col_dod;


reg   debug_flag5;
reg   debug_flag6;
always @ (posedge clk)
if (rst) begin
    debug_flag5          <= 1;
    debug_flag6          <= 1;
end else begin
    if (debug_flag5==1) begin
        //x=59,y=62        56  57  58  59  60  61  62  63
        //                [7] [6] [5] [4] [3] [2] [1] [0]
        if (dram_right_8col_addrd[4]==61&&dram_right_8col_did[4]==56&&dram_right_8col_we[4]==1) begin
            $display("%t dram_right_8col 56 x0 %d y0 %d",$time,x0,y0);
            debug_flag5  <= 0;
        end
    end
    if (debug_flag6==1) begin
        if (dram_right_8col_addrd[4]==61&&dram_right_8col_did[4]==57&&dram_right_8col_we[4]==1) begin
            $display("%t dram_right_8col 57 x0 %d y0 %d",$time,x0,y0);
            debug_flag6  <= 0;
        end
    end
end


// right_6col               pred        
// 5  4  3   2  1  0    0,...... 58 59 60 61 62 63
generate
    for (I=0;I<8;I++)
    begin: dram_right_8col_label
        dram_m #(6, 8) dram_right_8col
        (
            .clk(clk),
            .en(1'b1),
            .we(dram_right_8col_we[I]),
            .addrd(dram_right_8col_addrd[I]),
            .addra(dram_right_8col_addra[I]),
            .addrb(dram_right_8col_addrb[I]),
            .did(dram_right_8col_did[I]),
            .doa(dram_right_8col_doa[I]),
            .dob(dram_right_8col_dob[I]),
            .dod(dram_right_8col_dod[I])
        );
    end
endgenerate



reg                           fetch_up_6row_done;
reg                           sao_done;

reg  [ 5:0]                   dram_up_6row_we;
reg  [ 5:0][ 4:0]             dram_up_6row_addrd; //深度32只存18,18*4=72byte
reg  [ 5:0][ 4:0]             dram_up_6row_addra;
reg  [ 5:0][ 4:0]             dram_up_6row_addrb;
reg  [ 5:0][31:0]             dram_up_6row_did;
wire [ 5:0][31:0]             dram_up_6row_doa;
wire [ 5:0][31:0]             dram_up_6row_dob;
wire [ 5:0][31:0]             dram_up_6row_dod;

//                    56 57 58 59    60 61 62 63
// dram_up_6row[i]     addr=0         addr=1 
//           data    [31:24] [23:16] [15:8] [7:0]
//                     59     58       57    56
reg   debug_flag3;
reg   debug_flag4;
always @ (posedge clk)
if (rst) begin
    debug_flag3          <= 1;
    debug_flag4          <= 1;
end else begin
    if (debug_flag3==1) begin
        if (dram_up_6row_addrd[2]==0&&dram_up_6row_did[2][31:24]==56&&dram_up_6row_we[2]==1) begin
            $display("%t dram 56 x0 %d y0 %d",$time,x0,y0);
            debug_flag3  <= 0;
        end
    end
    if (debug_flag4==1) begin
        if (dram_up_6row_addrd[2]==0&&dram_up_6row_did[2][31:24]==57&&dram_up_6row_we[2]==1) begin
            $display("%t dram 57 x0 %d y0 %d",$time,x0,y0);
            debug_flag4  <= 0;
        end
    end
end


generate
    for (I=0;I<6;I++)
    begin: dram_up_6rows_label
        dram_m #(5, 32) dram_up_6row //深度32只存18
        (
            .clk(clk),
            .en(1'b1),
            .we(dram_up_6row_we[I]),
            .addra(dram_up_6row_addra[I]),
            .addrb(dram_up_6row_addrb[I]),
            .addrd(dram_up_6row_addrd[I]),
            .did(dram_up_6row_did[I]),
            .doa(dram_up_6row_doa[I]),
            .dob(dram_up_6row_dob[I]),
            .dod(dram_up_6row_dod[I])
        );
    end
endgenerate



reg signed [ 6:0]         qPL               ;
reg        [ 5:0]         Q1                ;
reg        [ 5:0]         Q0                ;

reg  [ 4:0]               tC                ;
reg  [ 6:0]               beta              ;
reg  [0:53][ 4:0]         tc_tab            ;
reg  [0:51][ 6:0]         beta_tab          ;
reg                       bs_minus1         ;
reg  [ 7:0]               abs_p30_minus_p00 ;
reg  [ 7:0]               abs_q30_minus_q00 ;
reg  [ 7:0]               abs_p00_minus_q00 ;
reg  [ 7:0]               abs_p33_minus_p03 ;
reg  [ 7:0]               abs_q33_minus_q03 ;
reg  [ 7:0]               abs_p03_minus_q03 ;
wire                      cond_sam0_eq1_0   ;
wire                      cond_sam0_eq1_1   ;
wire                      cond_sam0_eq1_2   ;
wire                      cond_sam3_eq1_0   ;
wire                      cond_sam3_eq1_1   ;
wire                      cond_sam3_eq1_2   ;

reg  signed [ 6:0]         neg_tc           ;
reg  signed [ 5:0]         neg_tc_div2      ;
reg  signed [ 5:0]         tc_div2          ;
reg         [ 8:0]         tc_mult10        ;

reg  [ 8:0]               dp0               ;
reg  [ 8:0]               dp3               ;
reg  [ 8:0]               dq0               ;
reg  [ 8:0]               dq3               ;

wire [ 9:0]               dp                ;
wire [ 9:0]               dq                ;

reg                       dEp               ;
reg                       dEq               ;
reg                       dSam0             ;
reg                       dSam3             ;
reg                       cond_filter       ; //d<beta

initial begin
    tc_tab = {
        5'd0, 5'd0, 5'd0, 5'd0, 5'd0, 5'd0, 5'd0, 5'd0, 5'd0, 5'd0, 5'd0, 5'd0, 5'd0, 5'd0, 5'd0, 5'd0,
        5'd0, 5'd0, 5'd1, 5'd1, 5'd1, 5'd1, 5'd1, 5'd1, 5'd1, 5'd1, 5'd1, 5'd2, 5'd2, 5'd2, 5'd2, 5'd3,
        5'd3, 5'd3, 5'd3, 5'd4, 5'd4, 5'd4, 5'd5, 5'd5, 5'd6, 5'd6, 5'd7, 5'd8, 5'd9, 5'd10, 5'd11, 5'd13,
        5'd14, 5'd16, 5'd18, 5'd20, 5'd22, 5'd24};

    beta_tab = {7'd0, 7'd0, 7'd0, 7'd0, 7'd0, 7'd0, 7'd0, 7'd0, 7'd0, 7'd0, 7'd0, 7'd0, 7'd0, 7'd0, 7'd0, 7'd0,
                7'd6, 7'd7, 7'd8, 7'd9, 7'd10, 7'd11, 7'd12, 7'd13, 7'd14, 7'd15, 7'd16, 7'd17,7'd18, 7'd20, 7'd22, 7'd24,
                7'd26, 7'd28, 7'd30, 7'd32, 7'd34, 7'd36, 7'd38, 7'd40, 7'd42, 7'd44, 7'd46, 7'd48, 7'd50, 7'd52, 7'd54, 7'd56,
                7'd58, 7'd60, 7'd62, 7'd64};

end

always @ (posedge clk)
begin
    case (bs)
    2'b01:bs_minus1       <= 0;
    2'b10:bs_minus1       <= 1;
    default:bs_minus1     <= 0;
    endcase
end

//这路和prefetch平行
//clock 0
always @ (posedge clk)
begin
    qPL <= (QpP+QpQ+1)>>1;
end

//clock 1
always @ (posedge clk)
begin
    if (qPL+(i_slice_beta_offset_div2<<<1)>51) //暂不考虑小于0的情况
        Q0  <= 51;
    else
        Q0  <= qPL+(i_slice_beta_offset_div2<<<1);
    if (qPL+(i_slice_tc_offset_div2<<<1)+(bs_minus1<<<1)>53)
        Q1  <= 53;
    else
        Q1  <= qPL+(i_slice_tc_offset_div2<<<1)+(bs_minus1<<<1);

end

//clock 2
always @ (posedge clk)
begin
    beta  <= beta_tab[Q0];
    tC    <= tc_tab[Q1];
end


//clock 0,{q30,q20,q10,q00,p00,p10,p20,p30}出来之后的第0周期
always @ (posedge clk)
begin
    dp0  <= p20+p00>{p10,1'b0}?p20+p00-{p10,1'b0}:{p10,1'b0}-p20-p00;
    dp3  <= p23+p03>{p13,1'b0}?p23+p03-{p13,1'b0}:{p13,1'b0}-p23-p03;
    dq0  <= q20+q00>{q10,1'b0}?q20+q00-{q10,1'b0}:{q10,1'b0}-q20-q00;
    dq3  <= q23+q03>{q13,1'b0}?q23+q03-{q13,1'b0}:{q13,1'b0}-q23-q03;
end

//clock 0
always @ (posedge clk)
begin
    abs_p30_minus_p00     <= p30>p00?p30-p00:p00-p30;
    abs_q30_minus_q00     <= q30>q00?q30-q00:q00-q30;
    abs_p00_minus_q00     <= p00>q00?p00-q00:q00-p00;
    abs_p33_minus_p03     <= p33>p03?p33-p03:p03-p33;
    abs_q33_minus_q03     <= q33>q03?q33-q03:q03-q33;
    abs_p03_minus_q03     <= p03>q03?p03-q03:q03-p03;
end

//clock 1
always @ (posedge clk)
begin
    cond_filter <= dp0+dq0+dp3+dq3 < beta?1:0;
end

assign cond_sam0_eq1_0 = (dp0+dq0)<<1 < beta[6:2] ? 1:0;
assign cond_sam3_eq1_0 = (dp3+dq3)<<1 < beta[6:2] ? 1:0;

assign cond_sam0_eq1_1 = abs_p30_minus_p00+abs_q30_minus_q00<beta[6:3] ? 1:0;
assign cond_sam3_eq1_1 = abs_p33_minus_p03+abs_q33_minus_q03<beta[6:3] ? 1:0;

assign cond_sam0_eq1_2 = abs_p00_minus_q00 < (tC+{tC,2'd0}+1)>>1 ? 1:0;
assign cond_sam3_eq1_2 = abs_p03_minus_q03 < (tC+{tC,2'd0}+1)>>1 ? 1:0;

assign    dp  = dp0+dp3;
assign    dq  = dq0+dq3;

//clock 1
always @ (posedge clk)
begin
    dSam0 <= cond_sam0_eq1_0&&cond_sam0_eq1_1&&cond_sam0_eq1_2;
    dSam3 <= cond_sam3_eq1_0&&cond_sam3_eq1_1&&cond_sam3_eq1_2;
    dEp   <= dp < (beta+beta[6:1])>>3?1:0;
    dEq   <= dq < (beta+beta[6:1])>>3?1:0;
end


always @ (fetch_x or dram_rec_doa or dram_right_8col_doa)
begin
    case (fetch_x[5:3])
    0: fetch_ver_a_row <= {dram_rec_doa[3:0],
                           dram_right_8col_doa[0],
                           dram_right_8col_doa[1],
                           dram_right_8col_doa[2],
                           dram_right_8col_doa[3]};
    1: fetch_ver_a_row <= dram_rec_doa[11:4];
    2: fetch_ver_a_row <= dram_rec_doa[19:12];
    3: fetch_ver_a_row <= dram_rec_doa[27:20];
    4: fetch_ver_a_row <= dram_rec_doa[35:28];
    5: fetch_ver_a_row <= dram_rec_doa[43:36];
    6: fetch_ver_a_row <= dram_rec_doa[51:44];
    7: fetch_ver_a_row <= dram_rec_doa[59:52];
    endcase
end

always @ (fetch_i or dram_rec_doa or dram_right_8col_doa)
begin
    case (fetch_i)
    0: fetch_hor_a_row <= {dram_right_8col_doa[0],
                           dram_right_8col_doa[1],
                           dram_right_8col_doa[2],
                           dram_right_8col_doa[3]};
    1: fetch_hor_a_row <= dram_rec_doa[3:0];
    2: fetch_hor_a_row <= dram_rec_doa[7:4];
    3: fetch_hor_a_row <= dram_rec_doa[11:8];
    4: fetch_hor_a_row <= dram_rec_doa[15:12];
    5: fetch_hor_a_row <= dram_rec_doa[19:16];
    6: fetch_hor_a_row <= dram_rec_doa[23:20];
    7: fetch_hor_a_row <= dram_rec_doa[27:24];
    8: fetch_hor_a_row <= dram_rec_doa[31:28];
    9: fetch_hor_a_row <= dram_rec_doa[35:32];
    10: fetch_hor_a_row <= dram_rec_doa[39:36];
    11: fetch_hor_a_row <= dram_rec_doa[43:40];
    12: fetch_hor_a_row <= dram_rec_doa[47:44];
    13: fetch_hor_a_row <= dram_rec_doa[51:48];
    14: fetch_hor_a_row <= dram_rec_doa[55:52];
    15: fetch_hor_a_row <= dram_rec_doa[59:56];
    default: fetch_hor_a_row <= dram_rec_doa[63:60];
    endcase
end

reg             [ 5:0]          store_right_y_d1         ;

reg       [71:0][ 7:0]          store_buf                ;
reg             [ 4:0]          store_up_i               ; //0~16
reg  [`max_x_bits-3:0]          store_up_addr            ;

always @ (posedge clk)
if (global_rst||i_rst_slice) begin
    o_filter_state           <= `filter_end;
    kick_deblock             <= 0;
end else if (i_rst_ctb) begin
    x0                       <= i_x0;
    y0                       <= i_y0;
    first_row                <= i_first_row;
    first_col                <= i_first_col;
    last_row                 <= i_last_row;
    last_col                 <= i_last_col;
    last_row_height_minus1   <= i_last_row_height-1;
    last_col_width_minus1    <= i_last_col_width-1;
    sao_param                <= i_sao_param;
    sao_param_left           <= i_sao_param_left;
    sao_param_up             <= i_sao_param_up;
    sao_param_leftup         <= i_sao_param_leftup;
    qpy_left_ctb_last_col    <= qpy_right_col;
    nf_left_ctb_last_col     <= nf_right_col;
    kick_deblock             <= 0;

end else if (rst) begin
    x                        <= 0;
    y                        <= 0;
    if (first_col)
        fetch_x              <= 8;
    else
        fetch_x              <= 0;
    fetch_y                  <= 0;
    last_fetch_x             <= 0;
    last_fetch_y             <= 0;
    fetch_i                  <= 0;
    fetch_j                  <= 0;
    stage                    <= 0;
    x0_minus8                <= i_x0-8;
    prefetch_stage           <= 0;
    hor_deblock_done         <= 0;

    if (first_col) begin
        nf_leftup            <= 1;
        //fix,first_col从x=8开始滤，最左边qpy没有取
        qpy_right_col        <= {i_qpy[7][0],
                                 i_qpy[6][0],
                                 i_qpy[5][0],
                                 i_qpy[4][0],
                                 i_qpy[3][0],
                                 i_qpy[2][0],
                                 i_qpy[1][0],
                                 i_qpy[0][0]};
        nf_right_col          <= {i_nf[7][0],
                                  i_nf[6][0],
                                  i_nf[5][0],
                                  i_nf[4][0],
                                  i_nf[3][0],
                                  i_nf[2][0],
                                  i_nf[1][0],
                                  i_nf[0][0]};
    end
    if (first_row)
        o_filter_state       <= `deblocking_ver;
    else
        o_filter_state       <= `filter_fetch_up;

    if (`log_f && i_slice_num>=`slice_begin && i_slice_num<=`slice_end) begin
        $fdisplay(fd_filter, "filter_ctb x0 %0d y0 %0d slice_num %0d",i_x0,i_y0,i_slice_num);
        $fdisplay(fd_deblock, "filter_ctb x0 %0d y0 %0d slice_num %0d",i_x0,i_y0,i_slice_num);
    end

end else if (en && o_filter_state == `filter_fetch_up) begin
    if (fetch_up_6row_done)
        o_filter_state       <= `deblocking_ver;


end else if (en && o_filter_state == `deblocking_ver) begin

    //prefetch
    if (prefetch_stage == 0) begin
        //qpy_right_col,reset filter时也不会reset，下一个ctb用，
        //这个qpy_right_col可以同样用于左边ctb最右4列的水平滤波
        //最左边的ctb，第一列时不用滤波，qpy_left_col设错无所谓
        //水平滤波时qpy_right_col已被覆盖，qpy_left_ctb_last_col来保存

       //垂直
       //p30 p20 p10 p00   q00 q10 q20 q30
       //p31 p21 p11 p01   q01 q11 q21 q31
       //p32 p22 p12 p02   q02 q12 q22 q32
       //p33 p23 p13 p03   q03 q13 q23 q33

        bs_a_col             <= i_bs_ver[fetch_x[5:3]];

        qpy_left_col         <= qpy_right_col;
        qpy_right_col        <= {i_qpy[7][fetch_x[5:3]],
                                 i_qpy[6][fetch_x[5:3]],
                                 i_qpy[5][fetch_x[5:3]],
                                 i_qpy[4][fetch_x[5:3]],
                                 i_qpy[3][fetch_x[5:3]],
                                 i_qpy[2][fetch_x[5:3]],
                                 i_qpy[1][fetch_x[5:3]],
                                 i_qpy[0][fetch_x[5:3]]};
        nf_left_col           <= nf_right_col;
        nf_right_col          <= {i_nf[7][fetch_x[5:3]],
                                  i_nf[6][fetch_x[5:3]],
                                  i_nf[5][fetch_x[5:3]],
                                  i_nf[4][fetch_x[5:3]],
                                  i_nf[3][fetch_x[5:3]],
                                  i_nf[2][fetch_x[5:3]],
                                  i_nf[1][fetch_x[5:3]],
                                  i_nf[0][fetch_x[5:3]]};


        prefetch_stage        <= 1;
    end


    if (prefetch_stage == 1) begin
        bs_a_col                   <= {2'd0,bs_a_col[15:1]};
        bs                         <= bs_a_col[0];
        qpy_down_row               <= first_row?i_qpy[0]:48'd0;
        nf_down_row                <= first_row?i_nf[0]:8'd0;
        if (bs_a_col == 32'd0) begin
            if (fetch_x[5:3] == 7) begin //last_col,最后几列bs=0
                prefetch_stage     <= 6; //原地等待store完成，转到`deblock_hor状态
            end else begin
                fetch_x            <= fetch_x+8;
                fetch_y            <= 0;
                prefetch_stage     <= 0;
            end
        end else if (bs_a_col[0]) begin
            prefetch_stage         <= 2;
        end else begin
            fetch_y                <= fetch_y+4;
        end

        kick_deblock               <= 0;
    end

    if (prefetch_stage == 2) begin

        QpP                       <= qpy_left_col[fetch_y[5:3]];
        QpQ                       <= qpy_right_col[fetch_y[5:3]];
        bypass_p                  <= nf_left_col[fetch_y[5:3]];
        bypass_q                  <= nf_right_col[fetch_y[5:3]];

        dram_rec_addra            <= {64{fetch_y}};
        dram_right_8col_addra     <= {8{fetch_y}};
        fetch_j                   <= 3;

        prefetch_stage            <= 3;
    end

    if (prefetch_stage == 3) begin
        
    end

    if (prefetch_stage == 3) begin
        case (fetch_j[1:0])
            3: pq_buf             <= {192'd0,fetch_ver_a_row};
            2: pq_buf             <= {pq_buf[3:2],fetch_ver_a_row,pq_buf[0]};
            0: pq_buf             <= {pq_buf[3],fetch_ver_a_row,pq_buf[1:0]};
            1: pq_buf             <= {fetch_ver_a_row,pq_buf[2:0]};
        endcase

        //0,3,1,2,垂直一次取4行，0行取完先取第3行，要求dp3，dq3
        fetch_j                   <= fetch_j==3?1:(fetch_j==1?2:0);
        if (fetch_j==3)
            {q30,q20,q10,q00,
             p00,p10,p20,p30}     <= fetch_ver_a_row;
        if (fetch_j==1)
            {q33,q23,q13,q03,
             p03,p13,p23,p33}     <= fetch_ver_a_row;
        dram_rec_addra            <= {64{fetch_y_plsj}};
        dram_right_8col_addra     <= {8{fetch_y_plsj}};
        if (fetch_j==0) begin
            prefetch_stage        <= 4;
            wait_cycle            <= 0;
        end
    end

    if (prefetch_stage == 4) begin
        //等待2周期，到dSam0,dSam3,cond_filter就绪
        wait_cycle                <= wait_cycle+1;
        last_fetch_x              <= fetch_x;
        last_fetch_y              <= fetch_y+3;

        if (wait_cycle==3) begin //连续bs非0，取的速度快于deblock，要多等些周期
            prefetch_stage        <= 1;
            //2个进程，先判断好谁慢，慢的那个结束，通知快的那个接着工作
            x_to_deblock          <= fetch_x;
            y_to_deblock          <= fetch_y;
            fetch_y               <= fetch_y+4;
            kick_deblock          <= 1;
        end
    end

    if (prefetch_stage == 6) begin
        if (store_y == last_fetch_y &&
            store_x == last_fetch_x) begin
            fetch_y               <= first_row?8:0;

            fetch_x               <= first_col?0:60;
            fetch_i               <= first_col?1:0;
            prefetch_stage        <= first_row?4:0;
            o_filter_state        <= `deblocking_hor;
        end
    end

end else if (en && o_filter_state == `deblocking_hor) begin
    if (sao_done == 1) begin
        //存，为下一个ctb(右边ctb)用
        bs_hor_left_ctb_last_col  <= {i_bs_hor[7][15],
                                      i_bs_hor[6][15],
                                      i_bs_hor[5][15],
                                      i_bs_hor[4][15],
                                      i_bs_hor[3][15],
                                      i_bs_hor[2][15],
                                      i_bs_hor[1][15],
                                      i_bs_hor[0][15]};
        o_filter_state            <= `filter_store_up_right;
    end

    //stage0~3取qpy,nf的leftup和up
    if (prefetch_stage == 0) begin
        nf_leftup                 <= nf_leftup_bk;
        qpy_leftup                <= qpy_leftup_bk;
        bram_up_ctb_qpy_addr      <= x0[`max_x_bits-1:6];
        bram_up_ctb_nf_addr       <= x0[`max_x_bits-1:6];
        prefetch_stage            <= 1;
    end

    if (prefetch_stage == 1) begin //delay 1cycle
        prefetch_stage            <= 2;
    end
    if (prefetch_stage == 2) begin
        nf_up_ctb                 <= bram_up_ctb_nf_dout;
        qpy_up_ctb                <= bram_up_ctb_qpy_dout;
        nf_leftup_bk              <= bram_up_ctb_nf_dout[7];
        qpy_leftup_bk             <= bram_up_ctb_qpy_dout[47:42];
        fetch_y                   <= 0;
        prefetch_stage            <= 3;

    end
    if (prefetch_stage==3) begin
        nf_down_row               <= nf_up_ctb; //减少来自bram_up_ctb_nf_dout的路径
        qpy_down_row              <= qpy_up_ctb;
        prefetch_stage            <= 4;
    end


    //stage=4,新的一行开始，垂直滤波，一列一列来，水平滤波，一行一行来
    if (prefetch_stage == 4) begin
        //这里fetch_y=0,8,16,..., bs_a_row不需要up ctb
        if (last_col)
            bs_a_row                     <= i_bs_hor[fetch_y[5:3]];
        else
            bs_a_row                     <= {2'b00,i_bs_hor[fetch_y[5:3]][14:0]};

        qpy_up_row                       <= qpy_down_row;
        qpy_down_row                     <= i_qpy[fetch_y[5:3]];
        nf_up_row                        <= nf_down_row;
        nf_down_row                      <= i_nf[fetch_y[5:3]];

        bs_hor_left_ctb_cur_row          <= bs_hor_left_ctb_last_col[fetch_y[5:3]];
        prefetch_stage                   <= 5;
    end

    //fetch_i,一行17份其中一份，
    //fetch_j,一份4x8中8行之一行
    if (prefetch_stage == 5) begin
        fetch_j                          <= 0;
        bs                               <= fetch_i == 0?bs_hor_left_ctb_cur_row:bs_a_row[0];

        if (fetch_i) begin
            bs_a_row                     <= {2'd0,bs_a_row[15:1]};
            if (bs_a_row==32'd0) begin
                if (fetch_y[5:3] == 7) begin //last_row,最后几行bs=0
                    prefetch_stage       <= 5; //取到了最后一行,结束,原地等待
                    if (store_y==last_fetch_y&&
                        store_x==last_fetch_x)
                        hor_deblock_done <= 1;
                end else begin
                    prefetch_stage       <= 4;
                    fetch_x              <= first_col?0:60;
                    fetch_i              <= first_col?1:0;
                    fetch_y              <= fetch_y+8;
                end
            end else if (bs_a_row[0]==0) begin
                prefetch_stage           <= 5;
                fetch_x                  <= fetch_x+4;
                fetch_i                  <= fetch_i+1;
            end else begin
                if (fetch_y == 0) begin
                    prefetch_stage       <= 6;
                end else begin
                    prefetch_stage       <= 8;
                    fetch_y              <= fetch_y-4; //y=8,实际从4开始取
                end
            end
        end else begin
            if (bs_hor_left_ctb_cur_row==0) begin
                prefetch_stage           <= 5;
                fetch_x                  <= fetch_x+4;
                fetch_i                  <= fetch_i+1;
            end else begin
                if (fetch_y == 0) begin
                    prefetch_stage       <= 6;
                end else begin
                    prefetch_stage       <= 8;
                    fetch_y              <= fetch_y-4; //y=8,实际从4开始取
                end
            end
        end

        kick_deblock          <= 0;
    end

    if (prefetch_stage == 6) begin
        //这里fetch_y=0,8,16,...
        QpP                   <= fetch_i==0 ? qpy_leftup:qpy_up_row[fetch_x[5:3]];
        QpQ                   <= fetch_i==0 ? qpy_left_ctb_last_col[fetch_y[5:3]]:qpy_down_row[fetch_x[5:3]];

        bypass_p              <= fetch_i==0 ? nf_leftup:nf_up_row[fetch_x[5:3]];
        bypass_q              <= fetch_i==0 ? nf_left_ctb_last_col[fetch_y[5:3]]:nf_down_row[fetch_x[5:3]];

        dram_up_6row_addra    <= {6{fetch_i_pls1}}; //fetch_i=0,从dram_up_6row[n][1]取，0=56,57,58,59，1=60,61,62,63
        prefetch_stage        <= 7;
    end


    if (prefetch_stage == 7) begin
        //to debug,这里仅1周期，可能fetch比deblock快了，下面wait_cycle不够
        //取上/左上ctb,移入4行
        pq_buf[0]             <= {dram_up_6row_doa[0][7:0],dram_up_6row_doa[1][7:0],
                                  dram_up_6row_doa[2][7:0],dram_up_6row_doa[3][7:0],32'd0};
        pq_buf[1]             <= {dram_up_6row_doa[0][15:8],dram_up_6row_doa[1][15:8],
                                  dram_up_6row_doa[2][15:8],dram_up_6row_doa[3][15:8],32'd0};
        pq_buf[2]             <= {dram_up_6row_doa[0][23:16],dram_up_6row_doa[1][23:16],
                                  dram_up_6row_doa[2][23:16],dram_up_6row_doa[3][23:16],32'd0};
        pq_buf[3]             <= {dram_up_6row_doa[0][31:24],dram_up_6row_doa[1][31:24],
                                  dram_up_6row_doa[2][31:24],dram_up_6row_doa[3][31:24],32'd0};

        p30 <= dram_up_6row_doa[3][7:0];
        p20 <= dram_up_6row_doa[2][7:0];
        p10 <= dram_up_6row_doa[1][7:0];
        p00 <= dram_up_6row_doa[0][7:0];
        p33 <= dram_up_6row_doa[3][31:24];
        p23 <= dram_up_6row_doa[2][31:24];
        p13 <= dram_up_6row_doa[1][31:24];
        p03 <= dram_up_6row_doa[0][31:24];

//pq_buf [0] [1] [2] [3]
       //28  29  30  31  32 33 34 35
       //水平
       //p30 p31 p32 p33 bram_up_6row_doa[3] 60 28   pq_buf[0][0],pq_buf[1][0],pq_buf[2][0],pq_buf[3][0],
       //p20 p21 p22 p23 bram_up_6row_doa[2] 61 29   pq_buf[0][1],pq_buf[1][1],pq_buf[2][1],pq_buf[3][1],
       //p10 p11 p12 p13 bram_up_6row_doa[1] 62 30
       //p00 p01 p02 p03 bram_up_6row_doa[0] 63 31

       //q00 q01 q02 q03
       //q10 q11 q12 q13
       //q20 q21 q22 q23
       //q30 q31 q32 q33

        fetch_j               <= 4;
        prefetch_stage        <= 9;
        dram_rec_addra        <= {64{fetch_y}};
        dram_right_8col_addra <= {8{fetch_y}};
        fetch_y               <= fetch_y+1;
    end


    if (prefetch_stage == 8) begin
        //这里y已经减4,y=4,12,18,...
        QpP                   <= fetch_i==0 ? qpy_left_ctb_last_col[fetch_y[5:3]]:qpy_up_row[fetch_x[5:3]];
        QpQ                   <= fetch_i==0 ? qpy_left_ctb_last_col[fetch_y[5:3]+1]:qpy_down_row[fetch_x[5:3]];
        bypass_p              <= fetch_i==0 ? nf_left_ctb_last_col[fetch_y[5:3]]:nf_up_row[fetch_x[5:3]];
        bypass_q              <= fetch_i==0 ? nf_left_ctb_last_col[fetch_y[5:3]+1]:nf_down_row[fetch_x[5:3]];

        dram_rec_addra        <= {64{fetch_y}};
        dram_right_8col_addra <= {8{fetch_y}};
        fetch_y               <= fetch_y+1;
        fetch_j               <= 0;
        prefetch_stage        <= 9;
    end

    if (prefetch_stage == 9) begin

        pq_buf[0]            <= {fetch_hor_a_row[0],pq_buf[0][7:1]};
        pq_buf[1]            <= {fetch_hor_a_row[1],pq_buf[1][7:1]};
        pq_buf[2]            <= {fetch_hor_a_row[2],pq_buf[2][7:1]};
        pq_buf[3]            <= {fetch_hor_a_row[3],pq_buf[3][7:1]};

        case (fetch_j)
            0: begin
                p30 <= fetch_hor_a_row[0];
                p33 <= fetch_hor_a_row[3];
            end
            1: begin
                p20 <= fetch_hor_a_row[0];
                p23 <= fetch_hor_a_row[3];
            end
            2: begin
                p10 <= fetch_hor_a_row[0];
                p13 <= fetch_hor_a_row[3];
            end
            3: begin
                p00 <= fetch_hor_a_row[0];
                p03 <= fetch_hor_a_row[3];
            end
            4: begin
                q00 <= fetch_hor_a_row[0];
                q03 <= fetch_hor_a_row[3];
            end
            5: begin
                q10 <= fetch_hor_a_row[0];
                q13 <= fetch_hor_a_row[3];
            end
            6: begin
                q20 <= fetch_hor_a_row[0];
                q23 <= fetch_hor_a_row[3];
            end
            7: begin
                q30 <= fetch_hor_a_row[0];
                q33 <= fetch_hor_a_row[3];
            end

        endcase

        dram_rec_addra        <= {64{fetch_y}};
        dram_right_8col_addra <= {8{fetch_y}};

        if (fetch_j == 7) begin
            i_to_deblock      <= fetch_i;
            x_to_deblock      <= fetch_x;
            y_to_deblock      <= fetch_y-4; //4x8块x左边，y中线
            wait_cycle        <= 0;
            prefetch_stage    <= 10;
        end else begin
            fetch_y           <= fetch_y+1;
            fetch_j           <= fetch_j+1;
        end
    end

    if (prefetch_stage == 10) begin
        wait_cycle            <= wait_cycle+1;
        last_fetch_x          <= fetch_x;
        last_fetch_y          <= fetch_y;
        if (wait_cycle==2) begin
            fetch_x           <= fetch_x+4;
            fetch_i           <= fetch_i+1;
            fetch_y           <= fetch_y-4;//回到中线
            prefetch_stage    <= 5;
            kick_deblock      <= 1;
        end
    end


//`filter_store_up_right     right存到57行,up存完
//`filter_store_up_right_2   right存58~63行
//`filter_store_up_right_3   update h

end else if (en && o_filter_state == `filter_store_up_right) begin

//      CTB0             x48 52 x56 60 x64
//                        |  |  a| b | c|
//---------------------------------------  y56 
//                        |  |  d| e | f|
//---------------------------------------  y60
//                        |  |  g| h | i| 
//---------------------------------------  y64
//...  CTB1                                        CTB2
//
//
//                        |  |   | j | k|
//---------------------------------------  y120
//                        |  |   | l | m| 
//---------------------------------------  y128
//解完CTB1存up，不能把l,m替换h，i到bram_up_6_row,因为CTB2取leftup是h,i
//但是要更新h到bram_up_row,因为解CTB1时对h进行水平滤波了
//同理色度滤波，解完ctb1，要更新bram_up_3row最左边的2个像素值的，h4,h5这两个点，ctb1水平滤波到这两个点


    if (stage == 0) begin
        dram_rec_addra               <= {64{6'd58}};
        dram_right_8col_addra        <= {8{6'd58}};
        y                            <= 58;
        y_pls1                       <= 59;
        y_minus58                    <= 0;
        stage                        <= 1;
    end
    if (stage == 1) begin
        store_buf                    <= {dram_rec_doa,
                                         dram_right_8col_doa[0],
                                         dram_right_8col_doa[1],
                                         dram_right_8col_doa[2],
                                         dram_right_8col_doa[3],
                                         dram_right_8col_doa[4],
                                         dram_right_8col_doa[5],
                                         dram_right_8col_doa[6],
                                         dram_right_8col_doa[7]};
        store_up_i                   <= 0;
        store_up_addr                <= x0[`max_x_bits-1:2]-2;
        stage                        <= 2;
    end
    //存1行64字节要存16次，6行6*16=96周期
    if (stage == 2) begin
        bram_up_6row_we              <= {6{1'b0}};
        bram_up_6row_addra           <= {6{store_up_addr}};
        bram_up_6row_dia             <= {6{store_buf[3:0]}};
        store_buf                    <= {32'd0,store_buf[71:4]};
        store_up_i                   <= store_up_i+1;
        store_up_addr                <= store_up_addr+1;
        case (y_minus58)
        0: bram_up_6row_we[5]       <= 1'b1;
        1: bram_up_6row_we[4]       <= 1'b1;
        2: bram_up_6row_we[3]       <= 1'b1;
        3: bram_up_6row_we[2]       <= 1'b1;
        4: bram_up_6row_we[1]       <= 1'b1;
        default:bram_up_6row_we[0]   <= 1'b1;
        endcase

        if (store_up_i == (last_col?17:15)) begin
            y                        <= y+1;
            y_pls1                   <= y_pls1+1;
            y_minus58                <= y_minus58+1;
            dram_rec_addra           <= {64{y_pls1}};
            dram_right_8col_addra    <= {8{y_pls1}};
            stage                    <= 1;
            if (y==63) begin
                stage                <= 3;

            end
        end
    end
    if (stage==3) begin
        bram_up_6row_we              <= {6{1'b0}};
    end
    if (stage==3&&store_right_y_d1 == 57) begin
        o_filter_state               <= `filter_store_up_right_2;
        stage                        <= 0;
    end
end else if (en && o_filter_state == `filter_store_up_right_2) begin
    if (store_right_y_d1 == 63) begin
        o_filter_state               <= (first_row||last_col)?`filter_end:`filter_store_up_right_3;
    end
end else if (en && o_filter_state == `filter_store_up_right_3) begin //update h
    if (stage == 0) begin
        dram_up_6row_addra           <= {6{5'd16}};
        stage                        <= 1;
    end
    if (stage == 1) begin
        bram_up_6row_we[0]           <= 1;
        bram_up_6row_we[1]           <= 1;
        bram_up_6row_we[2]           <= 1;
        bram_up_6row_addra[0]        <= store_up_addr;
        bram_up_6row_addra[1]        <= store_up_addr;
        bram_up_6row_addra[2]        <= store_up_addr;
        bram_up_6row_dia[0]          <= dram_up_6row_doa[0];
        bram_up_6row_dia[1]          <= dram_up_6row_doa[1];
        bram_up_6row_dia[2]          <= dram_up_6row_doa[2];
        stage                        <= 2;
    end
    if (stage == 2) begin
        bram_up_6row_we[0]           <= 0;
        bram_up_6row_we[1]           <= 0;
        bram_up_6row_we[2]           <= 0;
        o_filter_state               <= `filter_end;
    end
end

reg           [7:0]        p0                ;
reg           [7:0]        p1                ;
reg           [7:0]        p2                ;
reg           [7:0]        p3                ;
reg           [7:0]        q0                ;
reg           [7:0]        q1                ;
reg           [7:0]        q2                ;
reg           [7:0]        q3                ;
reg           [7:0]        p0_d1             ;
reg           [7:0]        p1_d1             ;
reg           [7:0]        p2_d1             ;
reg           [7:0]        p3_d1             ;
reg           [7:0]        q0_d1             ;
reg           [7:0]        q1_d1             ;
reg           [7:0]        q2_d1             ;
reg           [7:0]        q3_d1             ;
reg           [7:0]        p0_d2             ;
reg           [7:0]        p1_d2             ;
reg           [7:0]        p2_d2             ;
reg           [7:0]        p3_d2             ;
reg           [7:0]        q0_d2             ;
reg           [7:0]        q1_d2             ;
reg           [7:0]        q2_d2             ;
reg           [7:0]        q3_d2             ;
reg           [7:0]        p0_d3             ;
reg           [7:0]        p1_d3             ;
reg           [7:0]        p2_d3             ;
reg           [7:0]        p3_d3             ;
reg           [7:0]        q0_d3             ;
reg           [7:0]        q1_d3             ;
reg           [7:0]        q2_d3             ;
reg           [7:0]        q3_d3             ;
reg           [7:0]        p0_result         ;
reg           [7:0]        p1_result         ;
reg           [7:0]        p2_result         ;
reg           [7:0]        p3_result         ;
reg           [7:0]        q0_result         ;
reg           [7:0]        q1_result         ;
reg           [7:0]        q2_result         ;
reg           [7:0]        q3_result         ;

reg                        valid             ;
reg                        valid_d1          ;
reg                        valid_d2          ;
reg                        valid_d3          ;
reg                        valid_d4          ;
reg                        valid_d5          ;
reg           [5:0]        deblock_x         ;
reg           [5:0]        deblock_y         ;
reg                        bs_minus1_deblk   ;

reg           [4:0]        deblock_i         ;
reg           [1:0]        deblock_j         ;
reg                        deblock_stage     ;
reg                        kick_store        ;
reg                        deblock_done      ;

reg           [4:0]        tc_deblk          ;
wire signed   [5:0]        tc_deblk_s        ;
assign tc_deblk_s = {1'b0,tc_deblk};

reg                        dSam0_deblk       ;
reg                        dSam3_deblk       ;
reg                        dEp_deblk         ;
reg                        dEq_deblk         ;
reg                        bypass_p_deblk    ;
reg                        bypass_q_deblk    ;
reg                        cond_filter_deblk ;

reg           [7:0]        p0_filter       ;
reg           [7:0]        p1_filter       ;
reg           [7:0]        p2_filter       ;
reg           [7:0]        q0_filter       ;
reg           [7:0]        q1_filter       ;
reg           [7:0]        q2_filter       ;

wire signed   [9:0]        p0_filter_s     ;
wire signed   [9:0]        p1_filter_s     ;
wire signed   [9:0]        p2_filter_s     ;
wire signed   [9:0]        q0_filter_s     ;
wire signed   [9:0]        q1_filter_s     ;
wire signed   [9:0]        q2_filter_s     ;

assign p0_filter_s = {2'b00,p0_filter};
assign p1_filter_s = {2'b00,p1_filter};
assign p2_filter_s = {2'b00,p2_filter};
assign q0_filter_s = {2'b00,q0_filter};
assign q1_filter_s = {2'b00,q1_filter};
assign q2_filter_s = {2'b00,q2_filter};


wire  signed  [9:0]        p0_filter_max   ;
wire  signed  [9:0]        p0_filter_min   ;
wire  signed  [9:0]        p1_filter_max   ;
wire  signed  [9:0]        p1_filter_min   ;
wire  signed  [9:0]        p2_filter_max   ;
wire  signed  [9:0]        p2_filter_min   ;

wire  signed  [9:0]        q0_filter_max   ;
wire  signed  [9:0]        q0_filter_min   ;
wire  signed  [9:0]        q1_filter_max   ;
wire  signed  [9:0]        q1_filter_min   ;
wire  signed  [9:0]        q2_filter_max   ;
wire  signed  [9:0]        q2_filter_min   ;

wire  signed  [9:0]        p0_d2_s         ;
wire  signed  [9:0]        p1_d2_s         ;
wire  signed  [9:0]        p2_d2_s         ;
wire  signed  [9:0]        q0_d2_s         ;
wire  signed  [9:0]        q1_d2_s         ;
wire  signed  [9:0]        q2_d2_s         ;
assign p0_d2_s = {2'b00,p0_d2};
assign p1_d2_s = {2'b00,p1_d2};
assign p2_d2_s = {2'b00,p2_d2};
assign q0_d2_s = {2'b00,q0_d2};
assign q1_d2_s = {2'b00,q1_d2};
assign q2_d2_s = {2'b00,q2_d2};

assign p0_filter_max = p0_d2_s+{tc_deblk,1'b0};
assign p1_filter_max = p1_d2_s+{tc_deblk,1'b0};
assign p2_filter_max = p2_d2_s+{tc_deblk,1'b0};
assign p0_filter_min = p0_d2_s-{tc_deblk,1'b0}; //fix,p0_d2-{tc_deblk,1'b0},位宽
assign p1_filter_min = p1_d2_s-{tc_deblk,1'b0};
assign p2_filter_min = p2_d2_s-{tc_deblk,1'b0};
assign q0_filter_max = q0_d2_s+{tc_deblk,1'b0};
assign q1_filter_max = q1_d2_s+{tc_deblk,1'b0};
assign q2_filter_max = q2_d2_s+{tc_deblk,1'b0};
assign q0_filter_min = q0_d2_s-{tc_deblk,1'b0};
assign q1_filter_min = q1_d2_s-{tc_deblk,1'b0};
assign q2_filter_min = q2_d2_s-{tc_deblk,1'b0};





reg           [7:0]        p0_filter_clip  ;
reg           [7:0]        p1_filter_clip  ;
reg           [7:0]        p2_filter_clip  ;
reg           [7:0]        q0_filter_clip  ;
reg           [7:0]        q1_filter_clip  ;
reg           [7:0]        q2_filter_clip  ;

wire signed   [8:0]        p0s             ;
wire signed   [8:0]        q0s             ;
wire signed   [8:0]        p1s             ;
wire signed   [8:0]        q1s             ;
wire signed   [8:0]        p2s             ;
wire signed   [8:0]        q2s             ;
wire signed   [8:0]        p0s_d3          ;
wire signed   [8:0]        q0s_d3          ;
wire signed   [8:0]        p1s_d3          ;
wire signed   [8:0]        q1s_d3          ;
wire signed   [8:0]        dpq0            ;
wire signed   [8:0]        dpq1            ;
assign p0s      = {1'b0,p0};
assign q0s      = {1'b0,q0};
assign p1s      = {1'b0,p1};
assign q1s      = {1'b0,q1};
assign p2s      = {1'b0,p2};
assign q2s      = {1'b0,q2};
assign p0s_d3   = {1'b0,p0_d3};
assign p1s_d3   = {1'b0,p1_d3};
assign q0s_d3   = {1'b0,q0_d3};
assign q1s_d3   = {1'b0,q1_d3};
assign dpq0     = q0s-p0s;
assign dpq1     = q1s-p1s;

//todo位宽
reg  signed [12:0]         dqp0_mult9      ;
reg  signed [12:0]         dqp1_mult3      ;
wire signed [8:0]         delta           ;
reg  signed [8:0]         delta_clip_tc   ;
reg  signed [8:0]         delta_clip_tc_d1;

reg                       cond_norm_filter;


reg         [7:0]         abs_delta       ;
reg  signed [7:0]         deltap          ;
reg  signed [7:0]         deltaq          ;
reg  signed [7:0]         deltap_tmp      ; //((p2+p0+1)>>1)-p1
reg  signed [7:0]         deltaq_tmp      ;
reg  signed [7:0]         deltap_tmp_d1   ;
reg  signed [7:0]         deltaq_tmp_d1   ;

wire signed [9:0]         p0_norm         ;
wire signed [9:0]         q0_norm         ;
wire signed [9:0]         p1_norm         ;
wire signed [9:0]         q1_norm         ;

assign p0_norm = p0s_d3+delta_clip_tc_d1;
assign q0_norm = q0s_d3-delta_clip_tc_d1;
assign p1_norm = p1s_d3+deltap;
assign q1_norm = q1s_d3+deltaq;


reg         [10:0]         p0_strong_tmp0  ;
reg         [10:0]         p1_strong_tmp0  ;
reg         [10:0]         p2_strong_tmp0  ;
reg         [10:0]         p0_strong_tmp1  ;
reg         [10:0]         p1_strong_tmp1  ;
reg         [10:0]         p2_strong_tmp1  ;
reg         [10:0]         q0_strong_tmp0  ;
reg         [10:0]         q1_strong_tmp0  ;
reg         [10:0]         q2_strong_tmp0  ;
reg         [10:0]         q0_strong_tmp1  ;
reg         [10:0]         q1_strong_tmp1  ;
reg         [10:0]         q2_strong_tmp1  ;



assign delta = (dqp0_mult9-dqp1_mult3+8)>>>4;

wire signed [ 7:0]         deltap_tmp_w     ;
wire signed [ 7:0]         deltaq_tmp_w     ;

assign deltap_tmp_w = (deltap_tmp_d1+delta_clip_tc)>>>1;
assign deltaq_tmp_w = (deltaq_tmp_d1-delta_clip_tc)>>>1;

reg         [ 2:0]         debug_j;


always @ (posedge clk)
if (i_rst_slice||global_rst) begin
    kick_store                 <= 0;
end else if (rst) begin
    tc_deblk                   <= 0;
    deblock_i                  <= 0;
    deblock_stage              <= 0;
    deblock_done               <= 0;
    kick_store                 <= 0;
end else if (en) begin
    if (deblock_stage == 0)
        kick_store             <= 0;
    if (deblock_stage == 0 && kick_deblock) begin
        pq_buf_bk              <= pq_buf;
        tc_deblk               <= tC;
        deblock_stage          <= 1;
        dSam0_deblk            <= dSam0;
        dSam3_deblk            <= dSam3;
        dEp_deblk              <= dEp;
        dEq_deblk              <= dEq;
        bs_minus1_deblk        <= bs_minus1;
        bypass_p_deblk         <= bypass_p;
        bypass_q_deblk         <= bypass_q;
        cond_filter_deblk      <= cond_filter;
        valid                  <= 0;
        valid_d1               <= 0;
        valid_d2               <= 0;
        valid_d3               <= 0;
        valid_d4               <= 0;
        valid_d5               <= 0;
        deblock_i              <= i_to_deblock;
        deblock_j              <= 0;
        debug_j                <= 0;
        deblock_x              <= x_to_deblock;
        deblock_y              <= y_to_deblock;

    end

    if (deblock_stage == 1) begin
        //pipeline stage 0
        {q3,q2,q1,q0,
         p0,p1,p2,p3}         <= pq_buf_bk;
        pq_buf_bk             <= {64'd0,pq_buf_bk[3:1]};
        valid                 <= 1;

        //pipeline stage 1
        valid_d1              <= valid;
        p0_d1                 <= p0;
        p1_d1                 <= p1;
        p2_d1                 <= p2;
        p3_d1                 <= p3;
        q0_d1                 <= q0;
        q1_d1                 <= q1;
        q2_d1                 <= q2;
        q3_d1                 <= q3;
        neg_tc                <= ~tc_deblk+1;
        neg_tc_div2           <= ~tc_deblk[4:1]+1;
        tc_div2               <= tc_deblk>>1;
        tc_mult10             <= {tc_deblk,3'd0}+{tc_deblk,1'b0};

        //delta = (9*(q0-p0)-3*(q1-p1)+8) >> 4; 求9*(q0-p0),3*(q1-p1)
        dqp0_mult9           <= (dpq0<<<3)+dpq0;
        dqp1_mult3           <= (dpq1<<<1)+dpq1;

        deltap_tmp           <= ((p2s+p0s+1)>>>1)-p1s;
        deltaq_tmp           <= ((q2s+q0s+1)>>>1)-q1s;

        p0_strong_tmp0       <= p2+{p1,1'b0}+{p0,1'b0};
        p1_strong_tmp0       <= p2+p1;
        p2_strong_tmp0       <= {p3,1'b0}+{p2,1'b0}+p2;
        p0_strong_tmp1       <= {q0,1'b0}+q1+4;
        p1_strong_tmp1       <= p0+q0+2;
        p2_strong_tmp1       <= p1+p0+q0+4;

        q0_strong_tmp0       <= p1+{p0,1'b0}+{q0,1'b0};
        q1_strong_tmp0       <= p0+q0;
        q2_strong_tmp0       <= p0+q0+q1;
        q0_strong_tmp1       <= {q1,1'b0}+q2+4;
        q1_strong_tmp1       <= q1+q2+2;
        q2_strong_tmp1       <= {q2,1'b0}+q2+{q3,1'b0}+4;

        //pipeline stage 2
        valid_d2             <= valid_d1;
        p0_d2                <= p0_d1;
        p1_d2                <= p1_d1;
        p2_d2                <= p2_d1;
        p3_d2                <= p3_d1;
        q0_d2                <= q0_d1;
        q1_d2                <= q1_d1;
        q2_d2                <= q2_d1;
        q3_d2                <= q3_d1;

        delta_clip_tc        <= delta>tc_deblk_s?tc_deblk_s:(delta<neg_tc?neg_tc:delta);
        abs_delta            <= delta>0?delta:(~delta+1);
        deltap_tmp_d1        <= deltap_tmp;
        deltaq_tmp_d1        <= deltaq_tmp;


        p0_filter            <= (p0_strong_tmp0+p0_strong_tmp1)>>3;
        p1_filter            <= (p1_strong_tmp0+p1_strong_tmp1)>>2;
        p2_filter            <= (p2_strong_tmp0+p2_strong_tmp1)>>3;

        q0_filter            <= (q0_strong_tmp0+q0_strong_tmp1)>>3;
        q1_filter            <= (q1_strong_tmp0+q1_strong_tmp1)>>2;
        q2_filter            <= (q2_strong_tmp0+q2_strong_tmp1)>>3;



        //deltap = Clip3(-(tC >> 1), tC >> 1, (((p2 + p0 + 1) >> 1) - p1 + delta) >> 1); delta是这里的delta_clip_tc
        //pipeline stage 3
        valid_d3             <= valid_d2;
        p0_d3                <= p0_d2;
        p1_d3                <= p1_d2;
        p2_d3                <= p2_d2;
        p3_d3                <= p3_d2;
        q0_d3                <= q0_d2;
        q1_d3                <= q1_d2;
        q2_d3                <= q2_d2;
        q3_d3                <= q3_d2;
        deltap               <= deltap_tmp_w < neg_tc_div2 ?
                              neg_tc_div2:(deltap_tmp_w > tc_div2?
                              tc_div2:deltap_tmp_w);


        deltaq               <= deltaq_tmp_w < neg_tc_div2 ?
                              neg_tc_div2:(deltaq_tmp_w > tc_div2?
                              tc_div2:deltaq_tmp_w);
        delta_clip_tc_d1     <= delta_clip_tc;
        cond_norm_filter     <= abs_delta < tc_mult10?1:0;

        p0_filter_clip       <= p0_filter_s>p0_filter_max?p0_filter_max[7:0]:
                               (p0_filter_s<p0_filter_min?p0_filter_min[7:0]:p0_filter);
        p1_filter_clip       <= p1_filter_s>p1_filter_max?p1_filter_max[7:0]:
                               (p1_filter_s<p1_filter_min?p1_filter_min[7:0]:p1_filter);
        p2_filter_clip       <= p2_filter_s>p2_filter_max?p2_filter_max[7:0]:
                               (p2_filter_s<p2_filter_min?p2_filter_min[7:0]:p2_filter);

        q0_filter_clip       <= q0_filter_s>q0_filter_max?q0_filter_max[7:0]:
                               (q0_filter_s<q0_filter_min?q0_filter_min[7:0]:q0_filter);
        q1_filter_clip       <= q1_filter_s>q1_filter_max?q1_filter_max[7:0]:
                               (q1_filter_s<q1_filter_min?q1_filter_min[7:0]:q1_filter);
        q2_filter_clip       <= q2_filter_s>q2_filter_max?q2_filter_max[7:0]:
                               (q2_filter_s<q2_filter_min?q2_filter_min[7:0]:q2_filter);

        //pipeline stage 4
        valid_d4             <= valid_d3;
        p0_result            <= p0_d3;
        p1_result            <= p1_d3;
        p2_result            <= p2_d3;
        p3_result            <= p3_d3;
        q0_result            <= q0_d3;
        q1_result            <= q1_d3;
        q2_result            <= q2_d3;
        q3_result            <= q3_d3;
        if (valid_d3)
            debug_j          <= debug_j+1;
        if (cond_filter_deblk) begin
            if (dSam0_deblk && dSam3_deblk) begin
                if (~bypass_p_deblk) begin
                    p0_result <= p0_filter_clip;
                    p1_result <= p1_filter_clip;
                    p2_result <= p2_filter_clip;
                    if (`log_f && i_slice_num>=`slice_begin && i_slice_num<=`slice_end && valid_d3&&debug_j<4) begin
                        $fdisplay(fd_deblock, "luma %s bs %0d x %0d y %0d strong p0 %0d to %0d p1 %0d to %0d p2 %0d to %0d",
                                  o_filter_state == `deblocking_ver ? "ver" : "hor",
                                  bs_minus1_deblk?2:1,
                                  o_filter_state == `deblocking_ver?x0+deblock_x:
                                                    (deblock_i==0?x0+deblock_x+debug_j-64:x0+deblock_x+debug_j),
                                  o_filter_state == `deblocking_ver?y0+deblock_y+debug_j:y0+deblock_y,
                                  p0_d3,p0_filter_clip, p1_d3,p1_filter_clip, p2_d3,p2_filter_clip);
                    end
               end
                if (~bypass_q_deblk) begin
                    q0_result <= q0_filter_clip;
                    q1_result <= q1_filter_clip;
                    q2_result <= q2_filter_clip;
                    if (`log_f && i_slice_num>=`slice_begin && i_slice_num<=`slice_end && valid_d3&&debug_j<4) begin
                        $fdisplay(fd_deblock, "luma %s bs %0d x %0d y %0d strong q0 %0d to %0d q1 %0d to %0d q2 %0d to %0d",
                                  o_filter_state == `deblocking_ver ? "ver" : "hor",
                                  bs_minus1_deblk?2:1,
                                  o_filter_state == `deblocking_ver?x0+deblock_x:
                                                    (deblock_i==0?x0+deblock_x+debug_j-64:x0+deblock_x+debug_j),
                                  o_filter_state == `deblocking_ver?y0+deblock_y+debug_j:y0+deblock_y,
                                  q0_d3,q0_filter_clip, q1_d3,q1_filter_clip, q2_d3,q2_filter_clip);
                    end
                end
            end else begin
                if (cond_norm_filter) begin
                    if (~bypass_p_deblk) begin
                        p0_result <= p0_norm[9]?0:(p0_norm[8]?255:p0_norm[7:0]);
                        if (`log_f && i_slice_num>=`slice_begin && i_slice_num<=`slice_end && valid_d3&&debug_j<4) begin
                            $fdisplay(fd_deblock, "luma %s bs %0d x %0d y %0d normal p0 %0d to %0d",
                                      o_filter_state == `deblocking_ver ? "ver" : "hor",
                                      bs_minus1_deblk?2:1,
                                      o_filter_state == `deblocking_ver?x0+deblock_x:
                                                        (deblock_i==0?x0+deblock_x+debug_j-64:x0+deblock_x+debug_j),
                                      o_filter_state == `deblocking_ver?y0+deblock_y+debug_j:y0+deblock_y,
                                      p0_d3,p0_norm[9]?0:(p0_norm[8]?255:p0_norm[7:0]));
                        end
                    end
                    if (~bypass_q_deblk) begin
                        q0_result <= q0_norm[9]?0:(q0_norm[8]?255:q0_norm[7:0]);
                        if (`log_f && i_slice_num>=`slice_begin && i_slice_num<=`slice_end && valid_d3&&debug_j<4) begin
                            $fdisplay(fd_deblock, "luma %s bs %0d x %0d y %0d normal q0 %0d to %0d",
                                      o_filter_state == `deblocking_ver ? "ver" : "hor",
                                      bs_minus1_deblk?2:1,
                                      o_filter_state == `deblocking_ver?x0+deblock_x:
                                                        (deblock_i==0?x0+deblock_x+debug_j-64:x0+deblock_x+debug_j),
                                      o_filter_state == `deblocking_ver?y0+deblock_y+debug_j:y0+deblock_y,
                                      q0_d3,q0_norm[9]?0:(q0_norm[8]?255:q0_norm[7:0]));
                        end
                    end
                    if (dEp_deblk && ~bypass_p_deblk) begin
                        p1_result <= p1_norm[9]?0:(p1_norm[8]?255:p1_norm[7:0]);
                        if (`log_f && i_slice_num>=`slice_begin && i_slice_num<=`slice_end && valid_d3&&debug_j<4) begin
                            $fdisplay(fd_deblock, "luma %s bs %0d x %0d y %0d normal p1 %0d to %0d",
                                      o_filter_state == `deblocking_ver ? "ver" : "hor",
                                      bs_minus1_deblk?2:1,
                                      o_filter_state == `deblocking_ver?x0+deblock_x:
                                                        (deblock_i==0?x0+deblock_x+debug_j-64:x0+deblock_x+debug_j),
                                      o_filter_state == `deblocking_ver?y0+deblock_y+debug_j:y0+deblock_y,
                                      p1_d3,p1_norm[9]?0:(p1_norm[8]?255:p1_norm[7:0]));
                        end
                    end
                    if (dEq_deblk && ~bypass_q_deblk) begin
                        q1_result <= q1_norm[9]?0:(q1_norm[8]?255:q1_norm[7:0]);
                        if (`log_f && i_slice_num>=`slice_begin && i_slice_num<=`slice_end && valid_d3&&debug_j<4) begin
                            $fdisplay(fd_deblock, "luma %s bs %0d x %0d y %0d normal q1 %0d to %0d",
                                      o_filter_state == `deblocking_ver ? "ver" : "hor",
                                      bs_minus1_deblk?2:1,
                                      o_filter_state == `deblocking_ver?x0+deblock_x:
                                                        (deblock_i==0?x0+deblock_x+debug_j-64:x0+deblock_x+debug_j),
                                      o_filter_state == `deblocking_ver?y0+deblock_y+debug_j:y0+deblock_y,
                                      q1_d3,q1_norm[9]?0:(q1_norm[8]?255:q1_norm[7:0]));
                        end
                    end
                end
            end
        end

        //解码8x4一块，9周期
        //pipeline stage 5
        valid_d5               <= valid_d4;
        deblock_buf            <= {q3_result,q2_result,q1_result,q0_result,
                                   p0_result,p1_result,p2_result,p3_result,
                                   deblock_buf[3:1]};
        if (valid_d4) begin
            deblock_j          <= deblock_j+1;
            if (deblock_j == 3) begin
                y_to_store     <= deblock_y;
                i_to_store     <= deblock_i;
                x_to_store     <= deblock_x;
                kick_store     <= 1;
                deblock_stage  <= 0;
            end
        end
    end

end

reg      [ 4:0]            fetch_up_i            ; //0~17
reg                        store_done            ;
reg      [ 4:0]            store_i               ;
wire     [ 4:0]            store_i_pls1          ;
assign store_i_pls1 = store_i+1;

reg      [ 3:0]            store_j               ;
reg      [ 1:0]            store_stage           ;
reg      [ 1:0]            fetch_up_stage        ;
reg      [`max_x_bits-3:0] fetch_addr            ;
reg      [ 6:0]            store_right_y         ;
reg                        do_store_right        ;
wire     [ 5:0]            store_right_y_end     ;
assign store_right_y_end = o_filter_state==`filter_store_up_right?57:63;

always @ (posedge clk)
if (rst||i_rst_slice) begin
    store_x                       <= 0;
    store_y                       <= 0;
    store_stage                   <= 0;
    fetch_up_stage                <= 0;
    fetch_addr                    <= x0[`max_x_bits-1:2]-2;
    hor_deblock_done_y            <= 0;

    fetch_up_6row_done            <= 0;
    fetch_up_i                    <= 0;
    do_store_right                <= 0;
    store_right_y                 <= 0;
    store_right_y_d1              <= 0;
    dram_rec_we                   <= 64'd0;
    dram_up_6row_we               <= {6{1'b0}};
    dram_right_8col_we            <= 8'd0;
end else if (en && o_filter_state == `filter_fetch_up) begin
    if (fetch_up_stage == 0) begin
        bram_up_6row_addrb        <= {6{fetch_addr}};
        fetch_addr                <= fetch_addr+1;
        fetch_up_stage            <= 1;
    end

    if (fetch_up_stage == 1) begin
        bram_up_6row_addrb        <= {6{fetch_addr}};
        fetch_addr                <= fetch_addr+1;
        //delay 1 cycle
        fetch_up_stage            <= 2;
    end

    if (fetch_up_stage == 2) begin
        bram_up_6row_addrb        <= {6{fetch_addr}};
        fetch_addr                <= fetch_addr+1;
        fetch_up_i                <= fetch_up_i+1;
        dram_up_6row_we           <= {6{1'b1}};
        dram_up_6row_addrd        <= {6{fetch_up_i}};
        dram_up_6row_did          <= bram_up_6row_dob;
        if (fetch_up_i == 18) begin
            fetch_up_i            <= 0;
            fetch_up_6row_done    <= 1;
            dram_up_6row_we       <= {6{1'b0}};
            fetch_up_stage        <= 3;
        end
    end
end else if (en &&(o_filter_state==`filter_store_up_right||
             o_filter_state==`filter_store_up_right_2)) begin
    do_store_right                <= 1;
    dram_rec_we                   <= 64'd0;
    dram_rec_addrd                <= {64{store_right_y[5:0]}};
    dram_right_8col_we            <= do_store_right?8'b11111111:8'd0;
    dram_right_8col_addrd         <= {8{store_right_y_d1}};;
    dram_right_8col_did           <= {dram_rec_dod[56],dram_rec_dod[57],
                                      dram_rec_dod[58],dram_rec_dod[59],
                                      dram_rec_dod[60],dram_rec_dod[61],
                                      dram_rec_dod[62],dram_rec_dod[63]};
    if (store_right_y!=store_right_y_end+1)
        store_right_y             <= store_right_y+1;
    if (store_right_y!=0&&store_right_y_d1!=store_right_y_end)
        store_right_y_d1          <= store_right_y_d1+1;
    if (store_right_y_d1 == store_right_y_end) begin
        do_store_right            <= 0;
    end
    
end else if (en&&o_filter_state == `deblocking_ver) begin

    if (store_stage == 0 && kick_store) begin
        deblock_buf_bk            <= deblock_buf;
        store_x                   <= x_to_store;
        store_y                   <= y_to_store;
        store_j                   <= 0;
        store_stage               <= 1;
    end

    if (store_stage == 1) begin

        deblock_buf_bk                     <= {64'd0,deblock_buf_bk[3:1]};
        case (store_x[5:3])
            0: begin
                dram_right_8col_did[3:0]   <= {deblock_buf_bk[0][0],
                                               deblock_buf_bk[0][1],
                                               deblock_buf_bk[0][2],
                                               deblock_buf_bk[0][3]};
                dram_rec_did[3:0]          <= deblock_buf_bk[0][7:4];
                dram_rec_we[3:0]           <= {4{1'b1}};
                dram_rec_addrd[3:0]        <= {4{store_y}};
                dram_right_8col_we[3:0]    <= {4{1'b1}};
                dram_right_8col_addrd[3:0] <= {4{store_y}};
            end
            1: begin
                dram_rec_did[11:4]         <= deblock_buf_bk[0];
                dram_rec_we[11:4]          <= {8{1'b1}};
                dram_rec_addrd[11:4]       <= {8{store_y}};
            end
            2: begin
                dram_rec_did[19:12]        <= deblock_buf_bk[0];
                dram_rec_we[19:12]         <= {8{1'b1}};
                dram_rec_addrd[19:12]      <= {8{store_y}};
            end
            3: begin
                dram_rec_did[27:20]        <= deblock_buf_bk[0];
                dram_rec_we[27:20]         <= {8{1'b1}};
                dram_rec_addrd[27:20]      <= {8{store_y}};
            end
            4: begin
                dram_rec_did[35:28]        <= deblock_buf_bk[0];
                dram_rec_we[35:28]         <= {8{1'b1}};
                dram_rec_addrd[35:28]      <= {8{store_y}};
            end
            5: begin
                dram_rec_did[43:36]        <= deblock_buf_bk[0];
                dram_rec_we[43:36]         <= {8{1'b1}};
                dram_rec_addrd[43:36]      <= {8{store_y}};
            end
            6: begin
                dram_rec_did[51:44]        <= deblock_buf_bk[0];
                dram_rec_we[51:44]         <= {8{1'b1}};
                dram_rec_addrd[51:44]      <= {8{store_y}};
            end
            7: begin
                dram_rec_did[59:52]        <= deblock_buf_bk[0];
                dram_rec_we[59:52]         <= {8{1'b1}};
                dram_rec_addrd[59:52]      <= {8{store_y}};
            end
        endcase

        if (store_j == 3) begin //垂直，存4行一个deblock块结束
            store_stage                    <= 0;
        end else begin
            store_y                        <= store_y+1;
            store_j                        <= store_j+1;
        end

    end

end else if (en&&o_filter_state == `deblocking_hor) begin
    if (hor_deblock_done) begin //全部结束，再更新一次
        //水平滤波滤到59行，sao只能进行到58行,最后一行所有都可以滤波，
        //所以hor_deblock_done_y设为i_last_row_height,不是i_last_row_height-1
        hor_deblock_done_y        <= last_row?i_last_row_height:59;
    end
    if (store_stage == 0 && kick_store) begin
        deblock_buf_bk            <= deblock_buf;
        store_i                   <= i_to_store;
        store_x                   <= x_to_store;
        store_j                   <= 0;
        hor_deblock_done_y        <= y_to_store-5;//新的一行开始store，老的一行才算完成,0-5=123
        if (y_to_store == 0) begin
            store_stage           <= 1;
            store_y               <= 0; //fix,存完up4行就要从y=0开始再存4行
        end else begin
            store_stage           <= 2;
            store_y               <= y_to_store-4;
        end
    end

    if (store_stage == 1) begin
        //从fetch_i传过来，0表示左边ctb
        dram_up_6row_addrd[3:0]   <= {4{store_i_pls1}}; //store_i=0,x=60,61,62,63,存到dram_up_6row第二个slot,第一个是56,57,58,59
        dram_up_6row_we[3:0]      <= {4{1'b1}};
        dram_up_6row_did[0]       <= {deblock_buf_bk[3][3],
                                      deblock_buf_bk[2][3],
                                      deblock_buf_bk[1][3],
                                      deblock_buf_bk[0][3]};
        dram_up_6row_did[1]       <= {deblock_buf_bk[3][2],
                                      deblock_buf_bk[2][2],
                                      deblock_buf_bk[1][2],
                                      deblock_buf_bk[0][2]};
        dram_up_6row_did[2]       <= {deblock_buf_bk[3][1],
                                      deblock_buf_bk[2][1],
                                      deblock_buf_bk[1][1],
                                      deblock_buf_bk[0][1]};
        dram_up_6row_did[3]       <= {deblock_buf_bk[3][0],
                                      deblock_buf_bk[2][0],
                                      deblock_buf_bk[1][0],
                                      deblock_buf_bk[0][0]};
        deblock_buf_bk[0]         <= {32'd0,deblock_buf_bk[0][7:4]};
        deblock_buf_bk[1]         <= {32'd0,deblock_buf_bk[1][7:4]};
        deblock_buf_bk[2]         <= {32'd0,deblock_buf_bk[2][7:4]};
        deblock_buf_bk[3]         <= {32'd0,deblock_buf_bk[3][7:4]};

        store_j                   <= 4; //水平滤波，一个deblock块4x8，存8行，dram up一次存了4行，接下来从第4行开始存
        store_stage               <= 2;
    end

    if (store_stage == 2) begin
        deblock_buf_bk[0]         <= {8'd0,deblock_buf_bk[0][7:1]};
        deblock_buf_bk[1]         <= {8'd0,deblock_buf_bk[1][7:1]};
        deblock_buf_bk[2]         <= {8'd0,deblock_buf_bk[2][7:1]};
        deblock_buf_bk[3]         <= {8'd0,deblock_buf_bk[3][7:1]};
        //store_i,一行17份4x8其中之一，store_j一个4x8的8行之一
        case (store_i)
            0: begin
                dram_right_8col_we[3:0]     <= {4{1'b1}};
                dram_right_8col_addrd[3:0]  <= {4{store_y}};
                dram_right_8col_did[3:0]    <= {deblock_buf_bk[0][0],
                                                deblock_buf_bk[1][0],
                                                deblock_buf_bk[2][0],
                                                deblock_buf_bk[3][0]};
            end
            1: begin
                dram_rec_did[3:0]          <= {deblock_buf_bk[3][0],
                                                deblock_buf_bk[2][0],
                                                deblock_buf_bk[1][0],
                                                deblock_buf_bk[0][0]};
                dram_rec_we[3:0]           <= {4{1'b1}};
                dram_rec_addrd[3:0]        <= {4{store_y}};
            end
            2: begin
                dram_rec_did[7:4]          <= {deblock_buf_bk[3][0],
                                                deblock_buf_bk[2][0],
                                                deblock_buf_bk[1][0],
                                                deblock_buf_bk[0][0]};
                dram_rec_we[7:4]           <= {4{1'b1}};
                dram_rec_addrd[7:4]        <= {4{store_y}};
            end
            3: begin
                dram_rec_did[11:8]         <= {deblock_buf_bk[3][0],
                                                deblock_buf_bk[2][0],
                                                deblock_buf_bk[1][0],
                                                deblock_buf_bk[0][0]};
                dram_rec_we[11:8]          <= {4{1'b1}};
                dram_rec_addrd[11:8]       <= {4{store_y}};
            end
            4: begin
                dram_rec_did[15:12]        <= {deblock_buf_bk[3][0],
                                                deblock_buf_bk[2][0],
                                                deblock_buf_bk[1][0],
                                                deblock_buf_bk[0][0]};
                dram_rec_we[15:12]         <= {4{1'b1}};
                dram_rec_addrd[15:12]      <= {4{store_y}};
            end
            5: begin
                dram_rec_did[19:16]        <= {deblock_buf_bk[3][0],
                                                deblock_buf_bk[2][0],
                                                deblock_buf_bk[1][0],
                                                deblock_buf_bk[0][0]};
                dram_rec_we[19:16]         <= {4{1'b1}};
                dram_rec_addrd[19:16]      <= {4{store_y}};
            end
            6: begin
                dram_rec_did[23:20]        <= {deblock_buf_bk[3][0],
                                                deblock_buf_bk[2][0],
                                                deblock_buf_bk[1][0],
                                                deblock_buf_bk[0][0]};
                dram_rec_we[23:20]         <= {4{1'b1}};
                dram_rec_addrd[23:20]      <= {4{store_y}};
            end
            7: begin
                dram_rec_did[27:24]        <= {deblock_buf_bk[3][0],
                                                deblock_buf_bk[2][0],
                                                deblock_buf_bk[1][0],
                                                deblock_buf_bk[0][0]};
                dram_rec_we[27:24]         <= {4{1'b1}};
                dram_rec_addrd[27:24]      <= {4{store_y}};
            end
            8: begin
                dram_rec_did[31:28]        <= {deblock_buf_bk[3][0],
                                                deblock_buf_bk[2][0],
                                                deblock_buf_bk[1][0],
                                                deblock_buf_bk[0][0]};
                dram_rec_we[31:28]         <= {4{1'b1}};
                dram_rec_addrd[31:28]      <= {4{store_y}};
            end
            9: begin
                dram_rec_did[35:32]        <= {deblock_buf_bk[3][0],
                                                deblock_buf_bk[2][0],
                                                deblock_buf_bk[1][0],
                                                deblock_buf_bk[0][0]};
                dram_rec_we[35:32]         <= {4{1'b1}};
                dram_rec_addrd[35:32]      <= {4{store_y}};
            end
            10: begin
                dram_rec_did[39:36]        <= {deblock_buf_bk[3][0],
                                                deblock_buf_bk[2][0],
                                                deblock_buf_bk[1][0],
                                                deblock_buf_bk[0][0]};
                dram_rec_we[39:36]         <= {4{1'b1}};
                dram_rec_addrd[39:36]      <= {4{store_y}};
            end
            11: begin
                dram_rec_did[43:40]        <= {deblock_buf_bk[3][0],
                                                deblock_buf_bk[2][0],
                                                deblock_buf_bk[1][0],
                                                deblock_buf_bk[0][0]};
                dram_rec_we[43:40]         <= {4{1'b1}};
                dram_rec_addrd[43:40]      <= {4{store_y}};
            end
            12: begin
                dram_rec_did[47:44]        <= {deblock_buf_bk[3][0],
                                                deblock_buf_bk[2][0],
                                                deblock_buf_bk[1][0],
                                                deblock_buf_bk[0][0]};
                dram_rec_we[47:44]         <= {4{1'b1}};
                dram_rec_addrd[47:44]      <= {4{store_y}};
            end
            13: begin
                dram_rec_did[51:48]        <= {deblock_buf_bk[3][0],
                                                deblock_buf_bk[2][0],
                                                deblock_buf_bk[1][0],
                                                deblock_buf_bk[0][0]};
                dram_rec_we[51:48]         <= {4{1'b1}};
                dram_rec_addrd[51:48]      <= {4{store_y}};
            end
            14: begin
                dram_rec_did[55:52]        <= {deblock_buf_bk[3][0],
                                                deblock_buf_bk[2][0],
                                                deblock_buf_bk[1][0],
                                                deblock_buf_bk[0][0]};
                dram_rec_we[55:52]         <= {4{1'b1}};
                dram_rec_addrd[55:52]      <= {4{store_y}};
            end
            15: begin
                dram_rec_did[59:56]        <= {deblock_buf_bk[3][0],
                                                deblock_buf_bk[2][0],
                                                deblock_buf_bk[1][0],
                                                deblock_buf_bk[0][0]};
                dram_rec_we[59:56]         <= {4{1'b1}};
                dram_rec_addrd[59:56]      <= {4{store_y}};

            end
            16: begin
                dram_rec_did[63:60]        <= {deblock_buf_bk[3][0],
                                                deblock_buf_bk[2][0],
                                                deblock_buf_bk[1][0],
                                                deblock_buf_bk[0][0]};
                dram_rec_we[63:60]         <= {4{1'b1}};
                dram_rec_addrd[63:60]      <= {4{store_y}};

            end
        endcase
        store_j                            <= store_j+1;
        store_y                            <= store_y+1;
        if (store_j == 7) begin //水平滤波，一个deblock块4x8，存8行
            store_stage                    <= 0;
        end
    end

end else begin

end



reg     [ 3:0][ 4:0]     band                         ;
reg     [ 3:0][ 4:0]     band_up                      ;
reg     [ 3:0][ 4:0]     band_left                    ;
reg     [ 3:0][ 4:0]     band_leftup                  ;

reg           [ 5:0]     sao_left_class_plus_k        ;
reg           [ 5:0]     sao_left_class_plus_k_up     ;
reg           [ 5:0]     sao_left_class_plus_k_left   ;
reg           [ 5:0]     sao_left_class_plus_k_leftup ;
reg           [ 2:0]     n                            ;
always @ (posedge clk)
if (rst) begin
    n                                 <= 0;
    sao_left_class_plus_k             <= sao_param.sao_band_position[0];
    sao_left_class_plus_k_up          <= sao_param_up.sao_band_position[0];
    sao_left_class_plus_k_left        <= sao_param_left.sao_band_position[0];
    sao_left_class_plus_k_leftup      <= sao_param_leftup.sao_band_position[0];
end else begin
    //for (k = 0; k < 4; k++)
    //    bandTable[(k + saoLeftClass) & 31] = k + 1;
    //不同于上面的bandTable 32项，这里band只有4项，存4个(k+saoLeftClass)&31
    if (n < 4) begin
        band[n]                       <= sao_left_class_plus_k[4:0];
        band_up[n]                    <= sao_left_class_plus_k_up[4:0];
        band_left[n]                  <= sao_left_class_plus_k_left[4:0];
        band_leftup[n]                <= sao_left_class_plus_k_leftup[4:0];

        sao_left_class_plus_k         <= sao_left_class_plus_k+1;
        sao_left_class_plus_k_up      <= sao_left_class_plus_k_up+1;
        sao_left_class_plus_k_left    <= sao_left_class_plus_k_left+1;
        sao_left_class_plus_k_leftup  <= sao_left_class_plus_k_leftup+1;
        n                             <= n+1;
    end

end


reg             [ 6:0]              sao_y                   ;
wire            [ 5:0]              sao_y_pls1              ;
wire            [ 5:0]              sao_y_pls2              ;
assign sao_y_pls1 = sao_y+1;
assign sao_y_pls2 = sao_y+2;

reg             [ 1:0]              sao_type_left           ;
reg             [ 1:0]              sao_type_right          ;
reg             [ 1:0]              sao_eo_class_left       ;
reg             [ 1:0]              sao_eo_class_right      ;

reg             [68:0][ 2:0]        edge_idx                ;
reg             [68:0][ 2:0]        edge_idx_w              ;

reg             [71:0][ 7:0]        sao_buf_up              ;
reg             [71:0][ 7:0]        sao_buf                 ;
wire signed           [ 9:0]        sao_buf_s[71:0]         ;

reg             [71:0][ 7:0]        sao_buf_down            ;
reg             [71:0][ 7:0]        sao_result              ;

reg  signed           [ 3:0]        sao_offset_band[68:0]   ;
reg  signed           [ 3:0]        sao_offset_edge[68:0]   ;
reg                   [ 8:0]        sao_nf_a_row            ;

wire signed           [ 3:0]        sao_offset_band_w[68:0] ;
wire signed           [ 3:0]        sao_offset_edge_w[68:0] ;


reg  signed           [ 1:0]        sign0[68:0]             ;
wire signed           [ 1:0]        sign0_w[68:0]           ;
reg  signed           [ 1:0]        sign1[68:0]             ;
wire signed           [ 1:0]        sign1_w[68:0]           ;
wire signed           [ 3:0]        sign_temp[68:0]         ;
wire            [68:0][ 7:0]        sao_result_band_w       ;
wire            [68:0][ 7:0]        sao_result_edge_w       ;
wire signed     [68:0][ 9:0]        sao_result_band_s       ;
wire signed     [68:0][ 9:0]        sao_result_edge_s       ;
reg             [68:0][ 7:0]        sao_result_band         ;
reg             [68:0][ 7:0]        sao_result_edge         ;
reg             [68:0][ 7:0]        sao_result_select_w     ;


reg                                 sao_up_ctb_done         ;
reg                                 sao_valid               ;
reg                                 cond_last_sao_y         ;
reg                                 cond_sao_y_eq63         ;

always @ (posedge clk)
begin
    if (sao_y < hor_deblock_done_y)
        sao_valid   <= 1;
    else
        sao_valid   <= 0;
end

//I=5,x=0对应sao_buf[8],sign0[5]

function [1:0] f_get_sign;
 input              [ 7: 0]   a;
 input              [ 7: 0]   b;
    begin
        if (a>b)
            f_get_sign = 2'b01;
        else if (a==b)
            f_get_sign = 2'b00;
        else
            f_get_sign = 2'b11;
    end
endfunction

parameter sao_pos_leftup   = 2'b00;
parameter sao_pos_left     = 2'b01;
parameter sao_pos_up       = 2'b10;
parameter sao_pos_center   = 2'b11;

parameter sao_none         = 2'b00;
parameter sao_band         = 2'b01;
parameter sao_edge         = 2'b10;


generate
    for (I=0;I<5;I++)
    begin: band_idx_label_0_to_4

        assign sao_offset_band_w[I] = sao_up_ctb_done?(sao_buf[I+3][7:3]==band_left[0]?sao_param_left.sao_offset[0][1]:
                                                       (sao_buf[I+3][7:3]==band_left[1]?sao_param_left.sao_offset[0][2]:
                                                       (sao_buf[I+3][7:3]==band_left[2]?sao_param_left.sao_offset[0][3]:
                                                       (sao_buf[I+3][7:3]==band_left[3]?sao_param_left.sao_offset[0][4]:0)))):
                                                      (sao_buf[I+3][7:3]==band_leftup[0]?sao_param_leftup.sao_offset[0][1]:
                                                       (sao_buf[I+3][7:3]==band_leftup[1]?sao_param_leftup.sao_offset[0][2]:
                                                       (sao_buf[I+3][7:3]==band_leftup[2]?sao_param_leftup.sao_offset[0][3]:
                                                       (sao_buf[I+3][7:3]==band_leftup[3]?sao_param_leftup.sao_offset[0][4]:0))));
        assign sao_offset_edge_w[I] = sao_up_ctb_done?sao_param_left.sao_offset[0][edge_idx[I]]:
                                                      sao_param_leftup.sao_offset[0][edge_idx[I]];
    end
endgenerate

generate
    for (I=5;I<69;I++)
    begin: band_idx_label_5_to_68

        assign sao_offset_band_w[I] = sao_up_ctb_done?(sao_buf[I+3][7:3]==band[0]?sao_param.sao_offset[0][1]:
                                                       (sao_buf[I+3][7:3]==band[1]?sao_param.sao_offset[0][2]:
                                                       (sao_buf[I+3][7:3]==band[2]?sao_param.sao_offset[0][3]:
                                                       (sao_buf[I+3][7:3]==band[3]?sao_param.sao_offset[0][4]:0)))):
                                                      (sao_buf[I+3][7:3]==band_up[0]?sao_param_up.sao_offset[0][1]:
                                                       (sao_buf[I+3][7:3]==band_up[1]?sao_param_up.sao_offset[0][2]:
                                                       (sao_buf[I+3][7:3]==band_up[2]?sao_param_up.sao_offset[0][3]:
                                                       (sao_buf[I+3][7:3]==band_up[3]?sao_param_up.sao_offset[0][4]:0))));
        assign sao_offset_edge_w[I] = sao_up_ctb_done?sao_param.sao_offset[0][edge_idx[I]]:
                                                      sao_param_up.sao_offset[0][edge_idx[I]];
    end
endgenerate

//sao_eo_class   0        1       2            3
//                        n0   n0               n0
//            n0 p n1     p       p           p
//                        n1        n1      n1


generate
    for (I=0;I<5;I++)
    begin: sign_label_0_to_4
        assign sign0_w[I] = sao_eo_class_left==0?f_get_sign(sao_buf[I+3],sao_buf[I+2]):
                             (sao_eo_class_left==1?f_get_sign(sao_buf[I+3],sao_buf_up[I+3]):
                             (sao_eo_class_left==2?f_get_sign(sao_buf[I+3],sao_buf_up[I+2]):
                              f_get_sign(sao_buf[I+3],sao_buf_up[I+4])));


        assign sign1_w[I] = sao_eo_class_left==0?f_get_sign(sao_buf[I+3],sao_buf[I+4]):
                             (sao_eo_class_left==1?f_get_sign(sao_buf[I+3],sao_buf_down[I+3]):
                             (sao_eo_class_left==2?f_get_sign(sao_buf[I+3],sao_buf_down[I+4]):
                              f_get_sign(sao_buf[I+3],sao_buf_down[I+2])));


    end
endgenerate


generate
    for (I=5;I<68;I++)
    begin: sign_label_5_to_67
        assign sign0_w[I] = sao_eo_class_right==0?f_get_sign(sao_buf[I+3],sao_buf[I+2]):
                             (sao_eo_class_right==1?f_get_sign(sao_buf[I+3],sao_buf_up[I+3]):
                             (sao_eo_class_right==2?f_get_sign(sao_buf[I+3],sao_buf_up[I+2]):
                              f_get_sign(sao_buf[I+3],sao_buf_up[(I+4)%72])));

        assign sign1_w[I] = sao_eo_class_right==0?f_get_sign(sao_buf[I+3],sao_buf[I+4]):
                             (sao_eo_class_right==1?f_get_sign(sao_buf[I+3],sao_buf_down[I+3]):
                             (sao_eo_class_right==2?f_get_sign(sao_buf[I+3],sao_buf_down[(I+4)%72]):
                              f_get_sign(sao_buf[I+3],sao_buf_down[I+2])));


    end
endgenerate

        assign sign0_w[68] = sao_eo_class_right==0?f_get_sign(sao_buf[71],sao_buf[70]):
                             (sao_eo_class_right==1?f_get_sign(sao_buf[71],sao_buf_up[71]):
                             (sao_eo_class_right==2?f_get_sign(sao_buf[71],sao_buf_up[70]):
                              f_get_sign(sao_buf[71],sao_buf_up[71])));

        assign sign1_w[68] = sao_eo_class_right==0?f_get_sign(sao_buf[71],sao_buf[71]):
                             (sao_eo_class_right==1?f_get_sign(sao_buf[71],sao_buf_down[71]):
                             (sao_eo_class_right==2?f_get_sign(sao_buf[71],sao_buf_down[71]):
                              f_get_sign(sao_buf[71],sao_buf_down[70])));

generate
    for (I=0;I<69;I++)
    begin: sign_temp_label
        assign sign_temp[I] = sign0[I]+sign1[I]+2;
    end
endgenerate

generate
    for (I=0;I<69;I++)
    begin: edge_idx_label
        assign edge_idx_w[I] = sign_temp[I]==0?1:
                              (sign_temp[I]==1?2:
                              (sign_temp[I]==2?0:
                              (sign_temp[I]==3?3:
                              (sign_temp[I]==4?4:0))));

    end
endgenerate


generate
    for (I=0;I<72;I++)
    begin: sao_buf_s_label
        assign sao_buf_s[I] = {2'b00,sao_buf[I]};
    end
endgenerate

generate
    for (I=0;I<69;I++)
    begin: sao_result_band_s_label
        assign sao_result_band_s[I] = sao_buf_s[I+3]+sao_offset_band[I];
    end
endgenerate

generate
    for (I=0;I<69;I++)
    begin: sao_result_edge_s_label
        assign sao_result_edge_s[I] = sao_buf_s[I+3]+sao_offset_edge[I];
    end
endgenerate

generate
    for (I=0;I<69;I++)
    begin: sao_result_band_label
        assign sao_result_band_w[I] = sao_result_band_s[I][9]?0:(sao_result_band_s[I][8]?255:sao_result_band_s[I][7:0]);
    end
endgenerate

generate
    for (I=0;I<69;I++)
    begin: sao_result_edge_label
        assign sao_result_edge_w[I] = sao_result_edge_s[I][9]?0:(sao_result_edge_s[I][8]?255:sao_result_edge_s[I][7:0]);
    end
endgenerate

generate
    for (I=0;I<5;I++)
    begin: sao_result_select_0_to_4_label
        always @(*)
        begin
            if (sao_type_left==sao_none) begin
                sao_result_select_w[I] = sao_buf[I+3];
                if (`log_v_sao&&~first_col)
                    $fdisplay(fd_filter,"%t select sao_none %d result %d",$time,I,sao_buf[I+3]);
            end else if (sao_nf_a_row[0]) begin
                sao_result_select_w[I] = sao_buf[I+3];
                if (`log_v_sao&&~first_col)
                    $fdisplay(fd_filter,"%t select nf %d result %d",$time,I,sao_buf[I+3]);
            end else if (sao_type_left==sao_band) begin
                sao_result_select_w[I] = sao_result_band[I];
                if (`log_v_sao&&~first_col)
                    $fdisplay(fd_filter,"%t select band %d result %d",$time,I,sao_result_band[I]);
            end else if (first_row && sao_y == 0 &&
                         sao_eo_class_left != 0 && sao_up_ctb_done) begin
                sao_result_select_w[I] = sao_buf[I+3];
                if (`log_v_sao&&~first_col)
                    $fdisplay(fd_filter,"%t select first row %d result %d",$time,I,sao_buf[I+3]);
            end else if (last_row && sao_y==last_row_height_minus1 &&
                         sao_eo_class_left != 0 && sao_up_ctb_done) begin
                sao_result_select_w[I] = sao_buf[I+3];
                if (`log_v_sao&&~first_col)
                    $fdisplay(fd_filter,"%t select last row %d result %d",$time,I,sao_buf[I+3]);
            end else if (sao_type_left) begin
                sao_result_select_w[I] = sao_result_edge[I];
                if (`log_v_sao&&~first_col)
                    $fdisplay(fd_filter,"%t select edge %d result %d",$time,I,sao_result_edge[I]);
            end else begin
                sao_result_select_w[I] = 0;
                if (`log_v_sao)
                    $fdisplay(fd_filter,"%t possible? sao %d select 0",$time,I);
            end
        end
    end
endgenerate

generate
    for (I=5;I<69;I++)
    begin: sao_result_select_5_to_68_label
        always @(*)
        begin
            if (sao_type_right==sao_none) begin
                sao_result_select_w[I] = sao_buf[I+3];
                if (`log_v_sao)
                    $fdisplay(fd_filter,"%t select sao_none %d result %d",$time,I,sao_buf[I+3]);
            end else if (sao_nf_a_row[(I-5)/8+1]) begin
                sao_result_select_w[I] = sao_buf[I+3];
                if (`log_v_sao)
                    $fdisplay(fd_filter,"%t select nf %d result %d",$time,I,sao_buf[I+3]);
            end else if (sao_type_right==sao_band) begin
                sao_result_select_w[I] = sao_result_band[I];
                if (`log_v_sao)
                    $fdisplay(fd_filter,"%t select band %d result %d",$time,I,sao_result_band[I]);
            end else if (first_col && I==5 && sao_eo_class_right != 1) begin
                sao_result_select_w[I] = sao_buf[I+3];
                if (`log_v_sao)
                    $fdisplay(fd_filter,"%t select first col %d result %d",$time,I,sao_buf[I+3]);
            end else if (first_row && sao_y == 0 &&
                         sao_eo_class_right != 0 && sao_up_ctb_done) begin
                sao_result_select_w[I] = sao_buf[I+3];
                if (`log_v_sao)
                    $fdisplay(fd_filter,"%t select first row %d result %d",$time,I,sao_buf[I+3]);
            end else if (last_col && (I-5)==last_col_width_minus1 &&
                         sao_eo_class_right != 1) begin
                sao_result_select_w[I] = sao_buf[I+3];
                if (`log_v_sao)
                    $fdisplay(fd_filter,"%t select last col %d result %d",$time,I,sao_buf[I+3]);
            end else if (last_row && sao_y==last_row_height_minus1 &&
                         sao_eo_class_right != 0 && sao_up_ctb_done) begin
                sao_result_select_w[I] = sao_buf[I+3];
                if (`log_v_sao)
                    $fdisplay(fd_filter,"%t select last row %d result %d",$time,I,sao_buf[I+3]);
            end else if (sao_type_right) begin
                sao_result_select_w[I] = sao_result_edge[I];
                if (`log_v_sao)
                    $fdisplay(fd_filter,"%t select edge %d result %d",$time,I,sao_result_edge[I]);
            end else begin
                sao_result_select_w[I] = 0;
                if (`log_v_sao)
                    $fdisplay(fd_filter,"%t possible? sao %d select 0",$time,I);
            end
        end
    end
endgenerate


generate
    for (I=0;I<5;I++)
    begin: sao_result_select_0_to_4_log_label
        always @(posedge clk)
        if (phase==10) begin
            if (sao_type_left==sao_none) begin

            end else if (sao_nf_a_row[0]) begin

            end else if (sao_type_left==sao_band) begin
                if (`log_f && i_slice_num>=`slice_begin &&
                    i_slice_num<=`slice_end&&~first_col)
                    $fdisplay(fd_filter, "luma x %0d y %0d band %0d+%0d=%0d",
                          x0-5+I, sao_up_ctb_done?y0+sao_y:y0+sao_y-64,
                          sao_buf[I+3],sao_offset_band[I],
                          sao_result_band[I]);
            end else if (first_row && sao_y == 0 &&
                         sao_eo_class_left != 0 && sao_up_ctb_done) begin

            end else if (last_row && sao_y==last_row_height_minus1 &&
                         sao_eo_class_left != 0 && sao_up_ctb_done) begin

            end else if (sao_type_left) begin
                if (`log_f && i_slice_num>=`slice_begin &&
                    i_slice_num<=`slice_end&&~first_col)
                    $fdisplay(fd_filter, "luma x %0d y %0d edge %0d+%0d=%0d edgeIdx %0d",
                          x0-5+I, sao_up_ctb_done?y0+sao_y:y0+sao_y-64,
                          sao_buf[I+3],sao_offset_edge[I],
                          sao_result_edge[I],
                          edge_idx[I]);
            end
        end
    end
endgenerate

generate
    for (I=5;I<69;I++)
    begin: sao_result_select_5_to_68_log_label
        always @(posedge clk)
        if (phase==10) begin
            if (sao_type_right==sao_none) begin

            end else if (sao_nf_a_row[(I-5)/8+1]) begin

            end else if (sao_type_right==sao_band) begin
                if (`log_f && i_slice_num>=`slice_begin && i_slice_num<=`slice_end&&
                    ((~last_col&&I<64)||(last_col&&I-5<i_last_col_width)))
                    $fdisplay(fd_filter, "luma x %0d y %0d band %0d+%0d=%0d",
                          x0-5+I, sao_up_ctb_done?y0+sao_y:y0+sao_y-64,
                          sao_buf[I+3],sao_offset_band[I],sao_result_band[I]);
            end else if (first_col && I==5 && sao_eo_class_right != 1) begin

            end else if (first_row && sao_y == 0 &&
                         sao_eo_class_right != 0 && sao_up_ctb_done) begin

            end else if (last_col && (I-5)==last_col_width_minus1 &&
                         sao_eo_class_right != 1) begin

            end else if (last_row && sao_y==last_row_height_minus1 &&
                         sao_eo_class_right != 0 && sao_up_ctb_done) begin

            end else if (sao_type_right) begin
                if (`log_f && i_slice_num>=`slice_begin && i_slice_num<=`slice_end&&
                    ((~last_col&&I<64)||(last_col&&I-5<i_last_col_width)))
                    $fdisplay(fd_filter, "luma x %0d y %0d edge %0d+%0d=%0d edgeIdx %0d",
                          x0-5+I, sao_up_ctb_done?y0+sao_y:y0+sao_y-64,
                          sao_buf[I+3],sao_offset_edge[I],
                          sao_result_edge[I],
                          edge_idx[I]);
            end
        end
    end
endgenerate


MvField                 [15:0]          cur_ctb_mvf             ;
reg  [15:0][`max_poc_bits-1:0]          cur_ctb_ref_poc         ;
reg                     [ 3:0]          store_mv_param_i        ;
reg                [7:0][ 7:0]          cu_predmode             ;
reg                     [31:0]          param_base_ddr          ;
reg                     [31:0]          pic_base_ddr            ;
wire                    [19:0]          param_addr_off          ;
reg                     [23:0]          pic_addr_off            ;
wire         [`max_y_bits-1:0]          y0_up_row               ;
wire         [`max_x_bits-1:0]          x_off                   ;
assign y0_up_row = y0[`max_y_bits-1:0]-64;
assign x_off = first_col?0:x0_minus8;

//6+2+6+5=19bit
assign param_addr_off   = {1'b0,y0[`max_y_bits-1:6],store_mv_param_i[3:2],x0[`max_x_bits-1:6],5'd0};


always @ (posedge clk)
if (global_rst||i_rst_slice) begin
    phase                     <= 19;
    m_axi_wvalid              <= 0;
    m_axi_awvalid             <= 0;
end else if (rst) begin
    sao_y                     <= first_row?0:59;
    sao_up_ctb_done           <= first_row?1:0;
    sao_done                  <= 0;
    m_axi_awvalid             <= 0;
    m_axi_wvalid              <= 0;
    cu_predmode               <= i_cu_predmode;
    param_base_ddr            <= i_param_base_ddr;
    pic_base_ddr              <= i_pic_base_ddr;
    cur_ctb_mvf               <= i_cur_ctb_mvf;
    cur_ctb_ref_poc           <= i_cur_ctb_ref_poc;


    //I_SLICE也要存，存入cu_predmode
    store_mv_param_i          <= 0;
    i                         <= 0;
    phase                     <= 16;
end else if (en) begin
    //store mv和垂直滤波是并行的，store完phase才到0，才会开始sao滤波和存像素到ddr

    if (phase == 16) begin
        m_axi_awaddr          <= {param_base_ddr[31:20],param_addr_off};
        m_axi_awvalid         <= 1;
        m_axi_wstrb           <= 16'hffff;
        m_axi_awlen           <= 3;
        phase                 <= 17;
        m_axi_wlast           <= 0;
    end

    if (phase==17&&m_axi_awready) begin
        phase                 <= 18;
        m_axi_awvalid         <= 0;
    end

    if ((phase == 18&&m_axi_wready)||
        (phase==17&&m_axi_awready)) begin

        m_axi_wdata           <= {cur_ctb_mvf[0],cur_ctb_ref_poc[0],
                                  cu_predmode[{store_mv_param_i[3:2],1'b0}][{store_mv_param_i[1:0],1'b0}],13'd0};
        m_axi_wvalid          <= 1;
        if (store_mv_param_i[1:0]==2'b11) //m_axi_wlast之后还要一次handshake，即还要一次m_axi_wready
            m_axi_wlast       <= 1;


        if (store_mv_param_i[1:0]!=2'b11||m_axi_wlast) begin
            store_mv_param_i  <= store_mv_param_i+1;
            cur_ctb_mvf       <= {`BitsMvf'd0,cur_ctb_mvf[15:1]};
            cur_ctb_ref_poc   <= {`max_poc_bits'd0,cur_ctb_ref_poc[15:1]};
        end
    end

    if (phase == 18&&m_axi_wready&&m_axi_wlast) begin

        phase                 <= 16;
        m_axi_wlast           <= 0;
        m_axi_wvalid          <= 0;
        if (store_mv_param_i[3:2]==2'b11) begin
            phase             <= 0;
        end

    end

    //phase0，刚开始sao滤波，滤完up ctb(下面mark1处)两个地方会进来
    //hor_deblock_done_y=0表示一行也没deblock完成，此后3,11,19,...
    if (phase == 0 &&
        hor_deblock_done_y>0&&hor_deblock_done_y!=123&& //0-5=123
       (~sao_up_ctb_done ||
       sao_valid )) begin //sao_y=63,hor_deblock_done_y=64,也要往下走,sao_y=64才停
        if (sao_up_ctb_done) begin
            dram_right_8col_addrb <= {8{sao_y[5:0]}};
            dram_rec_addrb        <= {64{sao_y[5:0]}};
            sao_nf_a_row          <= {i_nf[sao_y[5:3]], nf_right_col[sao_y[5:3]]};
            sao_type_left         <= sao_param_left.sao_type_idx[0];
            sao_type_right        <= sao_param.sao_type_idx[0];
            sao_eo_class_left     <= sao_param_left.sao_eo_class[0];
            sao_eo_class_right    <= sao_param.sao_eo_class[0];
            phase                 <= 1;
        end else begin
            dram_up_6row_addrb    <= {6{i}};
            dram_right_8col_addrb <= {8{6'd0}}; //求up ctb第0行即当前ctb紧接着的上一行的sao时，要用到当前ctb第0行
            dram_rec_addrb        <= {64{6'd0}}; //所以要取dram_right_8col和dram_rec
            sao_nf_a_row          <= {nf_up_ctb, nf_leftup};
            sao_type_left         <= sao_param_leftup.sao_type_idx[0];
            sao_type_right        <= sao_param_up.sao_type_idx[0];
            sao_eo_class_left     <= sao_param_leftup.sao_eo_class[0];
            sao_eo_class_right    <= sao_param_up.sao_eo_class[0];
            i                     <= i+1;
            phase                 <= 4;
        end

    end


    //sao_y=0,需要预取2行
    if (phase==1) begin
        sao_buf_up                <= row_up0;
        sao_buf                   <= {dram_rec_dob,dram_right_8col_dob[0],
                                                   dram_right_8col_dob[1],
                                                   dram_right_8col_dob[2],
                                                   dram_right_8col_dob[3],
                                                   dram_right_8col_dob[4],
                                                   dram_right_8col_dob[5],
                                                   8'd0,8'd0};
        dram_right_8col_addrb     <= {8{sao_y_pls1}};
        dram_rec_addrb            <= {64{sao_y_pls1}};
        phase                     <= 2;
    end
    if (phase==2) begin
        sao_buf_down              <= {dram_rec_dob,dram_right_8col_dob[0],
                                                   dram_right_8col_dob[1],
                                                   dram_right_8col_dob[2],
                                                   dram_right_8col_dob[3],
                                                   dram_right_8col_dob[4],
                                                   dram_right_8col_dob[5],
                                                   8'd0,8'd0};
        phase                     <= 5;
    end
    if (phase == 3&&sao_valid) begin
        sao_buf_up                <= sao_buf;
        sao_buf                   <= sao_buf_down;
        sao_buf_down              <= {dram_rec_dob,dram_right_8col_dob[0],
                                                   dram_right_8col_dob[1],
                                                   dram_right_8col_dob[2],
                                                   dram_right_8col_dob[3],
                                                   dram_right_8col_dob[4],
                                                   dram_right_8col_dob[5],
                                                   8'd0,8'd0};
        phase                     <= 5;
    end


    if (phase==4) begin
        //row_up0,64+8,当前ctb的上一行，求当前ctb第0行sao时用，这里预先移好
        row_up0                   <= {dram_up_6row_dob[0],row_up0[71:4]};
        case (sao_y)
        59: begin
                sao_buf_up        <= {dram_up_6row_dob[5],sao_buf_up[71:4]};
                sao_buf           <= {dram_up_6row_dob[4],sao_buf[71:4]};
                sao_buf_down      <= {dram_up_6row_dob[3],sao_buf_down[71:4]};
            end

        60: begin
                sao_buf_up        <= {dram_up_6row_dob[4],sao_buf_up[71:4]};
                sao_buf           <= {dram_up_6row_dob[3],sao_buf[71:4]};
                sao_buf_down      <= {dram_up_6row_dob[2],sao_buf_down[71:4]};
            end

        61: begin
                sao_buf_up        <= {dram_up_6row_dob[3],sao_buf_up[71:4]};
                sao_buf           <= {dram_up_6row_dob[2],sao_buf[71:4]};
                sao_buf_down      <= {dram_up_6row_dob[1],sao_buf_down[71:4]};
            end
        62: begin
                sao_buf_up        <= {dram_up_6row_dob[2],sao_buf_up[71:4]};
                sao_buf           <= {dram_up_6row_dob[1],sao_buf[71:4]};
                sao_buf_down      <= {dram_up_6row_dob[0],sao_buf_down[71:4]};
            end

        default: begin
                sao_buf_up        <= {dram_up_6row_dob[1],sao_buf_up[71:4]};
                sao_buf           <= {dram_up_6row_dob[0],sao_buf[71:4]};
                sao_buf_down      <= {dram_rec_dob,
                                         dram_right_8col_dob[0],
                                         dram_right_8col_dob[1],
                                         dram_right_8col_dob[2],
                                         dram_right_8col_dob[3],
                                         dram_right_8col_dob[4],
                                         dram_right_8col_dob[5],
                                         8'd0,8'd0};

            end
        endcase
        dram_up_6row_addrb        <= {6{i}};
        i                         <= i+1;
        if (i==18) begin
            phase                 <= 5;
            i                     <= 0;
        end

    end

    if (phase == 5) begin
        sign0                     <= sign0_w;
        sign1                     <= sign1_w;

        pic_addr_off              <= sao_up_ctb_done?{y0[`max_y_bits-1:6],sao_y[5:0],x_off}:
                                                     {y0_up_row[`max_y_bits-1:6],sao_y[5:0],x_off};

        if (sao_type_left == sao_none&&
            sao_type_right == sao_none) begin
            phase                 <= 10;
        end else begin
            phase                 <= 6;
        end
    end

    //从下面计算sao完跳上来，一行9次滤波第二次开始
    if (phase == 6) begin
        sao_offset_band           <= sao_offset_band_w;
        edge_idx                  <= edge_idx_w;
        phase                     <= 7;

    end

    if (phase == 7) begin
        sao_result_band           <= sao_result_band_w;
        sao_offset_edge           <= sao_offset_edge_w;

        if (sao_type_left != sao_band||
            sao_type_right != sao_band)
            phase                 <= 8;
        else
            phase                 <= 10;
    end
    if (phase == 8) begin
        sao_offset_band           <= sao_offset_band_w;
        edge_idx                  <= edge_idx_w;
        phase                     <= 9;
    end
    if (phase == 9) begin
        sao_result_edge           <= sao_result_edge_w;
        phase                     <= 10;
    end
    if (phase == 10) begin

        if (first_col)
            sao_result            <= {64'd0,sao_result_select_w[68:5]};
        else
            sao_result            <= {sao_result_select_w,24'd0};

        m_axi_awaddr              <= {pic_base_ddr[31:24],pic_addr_off};

        m_axi_awvalid             <= 1;
        if (last_col)
            m_axi_awlen           <= i_last_col_width[6:3]; //i_last_col_width=16,m_axi_len=16/8+1-1
        else if (first_col)
            m_axi_awlen           <= 7;
        else
            m_axi_awlen           <= 8;

        i                         <= 0;
        phase                     <= 11;

        cond_last_sao_y           <= (~last_row && sao_y == 58) || //59上面一行
                                     (last_row && sao_y == last_row_height_minus1);
        cond_sao_y_eq63          <= sao_y == 63;
    end


    if (phase == 11&&m_axi_awready) begin

        phase                     <= 12;
        m_axi_awvalid             <= 0;


    end

    if (phase == 12) begin
        m_axi_wdata               <= sao_result[7:0];
        m_axi_wvalid              <= 1;

        if (i == m_axi_awlen)
            m_axi_wlast           <= 1;

        if (~first_col && i == 0)
            m_axi_wstrb           <= 8'b11111000;
        else if (last_col && i == m_axi_awlen)
            m_axi_wstrb           <= 8'b11111111;
        else if (i == m_axi_awlen)
            m_axi_wstrb           <= 8'b00000111;
        else
            m_axi_wstrb           <= 8'b11111111;


        sao_result                <= {64'd0,sao_result[71:8]};
        i                         <= i+1;
        phase                     <= 13;
    end

    if (phase == 13&&m_axi_wready) begin
        phase                            <= 12;
        m_axi_wvalid                     <= 0;
        if (m_axi_wlast)
            phase                        <= 14;
    end

    if (phase == 14) begin

        i                         <= 0;
        sao_y                     <= sao_y==63?0:sao_y+1;
        m_axi_wlast               <= 0;
        m_axi_wvalid              <= 0;
        if (sao_up_ctb_done) begin
            if (cond_last_sao_y) begin
                phase                 <= 19; //结束
                sao_done              <= 1;
            end else begin
                phase                 <= 3;
                dram_right_8col_addrb <= {8{sao_y_pls2}};
                dram_rec_addrb        <= {64{sao_y_pls2}};
            end
        end else begin
            if (cond_sao_y_eq63) begin
                sao_up_ctb_done       <= 1;
                phase                 <= 0; //mark1
            end else begin
                phase                 <= 4;
            end
        end


    end





end


`ifdef RANDOM_INIT
integer  seed;
integer random_val;
initial  begin
    seed                               = $get_initial_random_seed(); 
    random_val                         = $random(seed);
    dram_rec_we                        = {random_val,random_val};
    dram_rec_addra                     = {random_val[1:0],random_val[31:2],random_val[1:0],random_val[31:2]};
    dram_rec_addrb                     = {random_val[2:0],random_val[31:3],random_val[2:0],random_val[31:3]};
    dram_rec_addrd                     = {random_val[3:0],random_val[31:4],random_val[3:0],random_val[31:4]};
    dram_rec_did                       = {random_val[4:0],random_val[31:5],random_val[4:0],random_val[31:5]};
    bram_up_ctb_qpy_addr               = {random_val[5:0],random_val[31:6],random_val[5:0],random_val[31:6]};
    bram_up_ctb_nf_addr                = {random_val[6:0],random_val[31:7],random_val[6:0],random_val[31:7]};
    m_axi_awaddr                       = {random_val[7:0],random_val[31:8],random_val[7:0],random_val[31:8]};
    m_axi_awlen                        = {random_val[8:0],random_val[31:9],random_val[8:0],random_val[31:9]};
    m_axi_awvalid                      = {random_val[9:0],random_val[31:10],random_val[9:0],random_val[31:10]};
    m_axi_wdata                        = {random_val[10:0],random_val[31:11],random_val[10:0],random_val[31:11]};
    m_axi_wstrb                        = {random_val[11:0],random_val[31:12],random_val[11:0],random_val[31:12]};
    m_axi_wlast                        = {random_val[12:0],random_val[31:13],random_val[12:0],random_val[31:13]};
    m_axi_wvalid                       = {random_val[13:0],random_val[31:14],random_val[13:0],random_val[31:14]};
    o_filter_state                     = {random_val[14:0],random_val[31:15],random_val[14:0],random_val[31:15]};
    stage                              = {random_val[15:0],random_val[31:16],random_val[15:0],random_val[31:16]};
    phase                              = {random_val[16:0],random_val[31:17],random_val[16:0],random_val[31:17]};
    x0                                 = {random_val[17:0],random_val[31:18],random_val[17:0],random_val[31:18]};
    y0                                 = {random_val[18:0],random_val[31:19],random_val[18:0],random_val[31:19]};
    x                                  = {random_val[19:0],random_val[31:20],random_val[19:0],random_val[31:20]};
    y                                  = {random_val[20:0],random_val[31:21],random_val[20:0],random_val[31:21]};
    y_pls1                             = {random_val[21:0],random_val[31:22],random_val[21:0],random_val[31:22]};
    y_minus58                          = {random_val[22:0],random_val[31:23],random_val[22:0],random_val[31:23]};
    i                                  = {random_val[23:0],random_val[31:24],random_val[23:0],random_val[31:24]};
    x0_minus8                          = {random_val[24:0],random_val[31:25],random_val[24:0],random_val[31:25]};
    first_row                          = {random_val[25:0],random_val[31:26],random_val[25:0],random_val[31:26]};
    first_col                          = {random_val[26:0],random_val[31:27],random_val[26:0],random_val[31:27]};
    last_row                           = {random_val[27:0],random_val[31:28],random_val[27:0],random_val[31:28]};
    last_col                           = {random_val[28:0],random_val[31:29],random_val[28:0],random_val[31:29]};
    last_row_height_minus1             = {random_val[29:0],random_val[31:30],random_val[29:0],random_val[31:30]};
    last_col_width_minus1              = {random_val[30:0],random_val[31],random_val[30:0],random_val[31]};
    prefetch_stage                     = {random_val[31:0],random_val[31:0]};
    fetch_x                            = {random_val,random_val};
    fetch_y                            = {random_val[1:0],random_val[31:2],random_val[1:0],random_val[31:2]};
    fetch_i                            = {random_val[2:0],random_val[31:3],random_val[2:0],random_val[31:3]};
    fetch_j                            = {random_val[3:0],random_val[31:4],random_val[3:0],random_val[31:4]};
    last_fetch_x                       = {random_val[4:0],random_val[31:5],random_val[4:0],random_val[31:5]};
    last_fetch_y                       = {random_val[5:0],random_val[31:6],random_val[5:0],random_val[31:6]};
    kick_deblock                       = {random_val[6:0],random_val[31:7],random_val[6:0],random_val[31:7]};
    x_to_deblock                       = {random_val[7:0],random_val[31:8],random_val[7:0],random_val[31:8]};
    y_to_deblock                       = {random_val[8:0],random_val[31:9],random_val[8:0],random_val[31:9]};
    i_to_deblock                       = {random_val[9:0],random_val[31:10],random_val[9:0],random_val[31:10]};
    store_x                            = {random_val[10:0],random_val[31:11],random_val[10:0],random_val[31:11]};
    store_y                            = {random_val[11:0],random_val[31:12],random_val[11:0],random_val[31:12]};
    x_to_store                         = {random_val[12:0],random_val[31:13],random_val[12:0],random_val[31:13]};
    y_to_store                         = {random_val[13:0],random_val[31:14],random_val[13:0],random_val[31:14]};
    i_to_store                         = {random_val[14:0],random_val[31:15],random_val[14:0],random_val[31:15]};
    bs_a_row                           = {random_val[15:0],random_val[31:16],random_val[15:0],random_val[31:16]};
    bs_a_col                           = {random_val[16:0],random_val[31:17],random_val[16:0],random_val[31:17]};
    nf_up_row                          = {random_val[17:0],random_val[31:18],random_val[17:0],random_val[31:18]};
    nf_down_row                        = {random_val[18:0],random_val[31:19],random_val[18:0],random_val[31:19]};
    nf_left_col                        = {random_val[19:0],random_val[31:20],random_val[19:0],random_val[31:20]};
    nf_right_col                       = {random_val[20:0],random_val[31:21],random_val[20:0],random_val[31:21]};
    nf_left_ctb_last_col               = {random_val[21:0],random_val[31:22],random_val[21:0],random_val[31:22]};
    qpy_up_row                         = {random_val[22:0],random_val[31:23],random_val[22:0],random_val[31:23]};
    qpy_down_row                       = {random_val[23:0],random_val[31:24],random_val[23:0],random_val[31:24]};
    qpy_up_ctb                         = {random_val[24:0],random_val[31:25],random_val[24:0],random_val[31:25]};
    qpy_left_col                       = {random_val[25:0],random_val[31:26],random_val[25:0],random_val[31:26]};
    qpy_right_col                      = {random_val[26:0],random_val[31:27],random_val[26:0],random_val[31:27]};
    qpy_left_ctb_last_col              = {random_val[27:0],random_val[31:28],random_val[27:0],random_val[31:28]};
    hor_deblock_done_y                 = {random_val[28:0],random_val[31:29],random_val[28:0],random_val[31:29]};
    hor_deblock_done                   = {random_val[29:0],random_val[31:30],random_val[29:0],random_val[31:30]};
    bs                                 = {random_val[30:0],random_val[31],random_val[30:0],random_val[31]};
    QpP                                = {random_val[31:0],random_val[31:0]};
    QpQ                                = {random_val,random_val};
    bypass_p                           = {random_val[1:0],random_val[31:2],random_val[1:0],random_val[31:2]};
    bypass_q                           = {random_val[2:0],random_val[31:3],random_val[2:0],random_val[31:3]};
    fetch_ver_a_row                    = {random_val[3:0],random_val[31:4],random_val[3:0],random_val[31:4]};
    fetch_hor_a_row                    = {random_val[4:0],random_val[31:5],random_val[4:0],random_val[31:5]};
    wait_cycle                         = {random_val[5:0],random_val[31:6],random_val[5:0],random_val[31:6]};
    p00                                = {random_val[6:0],random_val[31:7],random_val[6:0],random_val[31:7]};
    p10                                = {random_val[7:0],random_val[31:8],random_val[7:0],random_val[31:8]};
    p20                                = {random_val[8:0],random_val[31:9],random_val[8:0],random_val[31:9]};
    p30                                = {random_val[9:0],random_val[31:10],random_val[9:0],random_val[31:10]};
    p03                                = {random_val[10:0],random_val[31:11],random_val[10:0],random_val[31:11]};
    p13                                = {random_val[11:0],random_val[31:12],random_val[11:0],random_val[31:12]};
    p23                                = {random_val[12:0],random_val[31:13],random_val[12:0],random_val[31:13]};
    p33                                = {random_val[13:0],random_val[31:14],random_val[13:0],random_val[31:14]};
    q00                                = {random_val[14:0],random_val[31:15],random_val[14:0],random_val[31:15]};
    q10                                = {random_val[15:0],random_val[31:16],random_val[15:0],random_val[31:16]};
    q20                                = {random_val[16:0],random_val[31:17],random_val[16:0],random_val[31:17]};
    q30                                = {random_val[17:0],random_val[31:18],random_val[17:0],random_val[31:18]};
    q03                                = {random_val[18:0],random_val[31:19],random_val[18:0],random_val[31:19]};
    q13                                = {random_val[19:0],random_val[31:20],random_val[19:0],random_val[31:20]};
    q23                                = {random_val[20:0],random_val[31:21],random_val[20:0],random_val[31:21]};
    q33                                = {random_val[21:0],random_val[31:22],random_val[21:0],random_val[31:22]};
    pq_buf                             = {random_val[22:0],random_val[31:23],random_val[22:0],random_val[31:23]};
    pq_buf_bk                          = {random_val[23:0],random_val[31:24],random_val[23:0],random_val[31:24]};
    deblock_buf                        = {random_val[24:0],random_val[31:25],random_val[24:0],random_val[31:25]};
    deblock_buf_bk                     = {random_val[25:0],random_val[31:26],random_val[25:0],random_val[31:26]};
    row_up0                            = {random_val[26:0],random_val[31:27],random_val[26:0],random_val[31:27]};
    nf_up_ctb                          = {random_val[27:0],random_val[31:28],random_val[27:0],random_val[31:28]};
    bs_hor_left_ctb_last_col           = {random_val[28:0],random_val[31:29],random_val[28:0],random_val[31:29]};
    bs_hor_left_ctb_cur_row            = {random_val[29:0],random_val[31:30],random_val[29:0],random_val[31:30]};
    nf_leftup                          = {random_val[30:0],random_val[31],random_val[30:0],random_val[31]};
    qpy_leftup                         = {random_val[31:0],random_val[31:0]};
    qpy_leftup_bk                      = {random_val,random_val};
    nf_leftup_bk                       = {random_val[1:0],random_val[31:2],random_val[1:0],random_val[31:2]};
    bram_up_6row_we                    = {random_val[2:0],random_val[31:3],random_val[2:0],random_val[31:3]};
    bram_up_6row_addra                 = {random_val[3:0],random_val[31:4],random_val[3:0],random_val[31:4]};
    bram_up_6row_addrb                 = {random_val[4:0],random_val[31:5],random_val[4:0],random_val[31:5]};
    bram_up_6row_dia                   = {random_val[5:0],random_val[31:6],random_val[5:0],random_val[31:6]};
    dram_right_8col_did                = {random_val[6:0],random_val[31:7],random_val[6:0],random_val[31:7]};
    dram_right_8col_addra              = {random_val[7:0],random_val[31:8],random_val[7:0],random_val[31:8]};
    dram_right_8col_addrb              = {random_val[8:0],random_val[31:9],random_val[8:0],random_val[31:9]};
    dram_right_8col_addrd              = {random_val[9:0],random_val[31:10],random_val[9:0],random_val[31:10]};
    dram_right_8col_we                 = {random_val[10:0],random_val[31:11],random_val[10:0],random_val[31:11]};
    debug_flag5                        = {random_val[11:0],random_val[31:12],random_val[11:0],random_val[31:12]};
    debug_flag6                        = {random_val[12:0],random_val[31:13],random_val[12:0],random_val[31:13]};
    fetch_up_6row_done                 = {random_val[13:0],random_val[31:14],random_val[13:0],random_val[31:14]};
    sao_done                           = {random_val[14:0],random_val[31:15],random_val[14:0],random_val[31:15]};
    dram_up_6row_we                    = {random_val[15:0],random_val[31:16],random_val[15:0],random_val[31:16]};
    dram_up_6row_addrd                 = {random_val[16:0],random_val[31:17],random_val[16:0],random_val[31:17]};
    dram_up_6row_addra                 = {random_val[17:0],random_val[31:18],random_val[17:0],random_val[31:18]};
    dram_up_6row_addrb                 = {random_val[18:0],random_val[31:19],random_val[18:0],random_val[31:19]};
    dram_up_6row_did                   = {random_val[19:0],random_val[31:20],random_val[19:0],random_val[31:20]};
    debug_flag3                        = {random_val[20:0],random_val[31:21],random_val[20:0],random_val[31:21]};
    debug_flag4                        = {random_val[21:0],random_val[31:22],random_val[21:0],random_val[31:22]};
    qPL                                = {random_val[22:0],random_val[31:23],random_val[22:0],random_val[31:23]};
    Q1                                 = {random_val[23:0],random_val[31:24],random_val[23:0],random_val[31:24]};
    Q0                                 = {random_val[24:0],random_val[31:25],random_val[24:0],random_val[31:25]};
    tC                                 = {random_val[25:0],random_val[31:26],random_val[25:0],random_val[31:26]};
    beta                               = {random_val[26:0],random_val[31:27],random_val[26:0],random_val[31:27]};
    bs_minus1                          = {random_val[29:0],random_val[31:30],random_val[29:0],random_val[31:30]};
    abs_p30_minus_p00                  = {random_val[30:0],random_val[31],random_val[30:0],random_val[31]};
    abs_q30_minus_q00                  = {random_val[31:0],random_val[31:0]};
    abs_p00_minus_q00                  = {random_val,random_val};
    abs_p33_minus_p03                  = {random_val[1:0],random_val[31:2],random_val[1:0],random_val[31:2]};
    abs_q33_minus_q03                  = {random_val[2:0],random_val[31:3],random_val[2:0],random_val[31:3]};
    abs_p03_minus_q03                  = {random_val[3:0],random_val[31:4],random_val[3:0],random_val[31:4]};
    neg_tc                             = {random_val[4:0],random_val[31:5],random_val[4:0],random_val[31:5]};
    neg_tc_div2                        = {random_val[5:0],random_val[31:6],random_val[5:0],random_val[31:6]};
    tc_div2                            = {random_val[6:0],random_val[31:7],random_val[6:0],random_val[31:7]};
    tc_mult10                          = {random_val[7:0],random_val[31:8],random_val[7:0],random_val[31:8]};
    dp0                                = {random_val[8:0],random_val[31:9],random_val[8:0],random_val[31:9]};
    dp3                                = {random_val[9:0],random_val[31:10],random_val[9:0],random_val[31:10]};
    dq0                                = {random_val[10:0],random_val[31:11],random_val[10:0],random_val[31:11]};
    dq3                                = {random_val[11:0],random_val[31:12],random_val[11:0],random_val[31:12]};
    dEp                                = {random_val[12:0],random_val[31:13],random_val[12:0],random_val[31:13]};
    dEq                                = {random_val[13:0],random_val[31:14],random_val[13:0],random_val[31:14]};
    dSam0                              = {random_val[14:0],random_val[31:15],random_val[14:0],random_val[31:15]};
    dSam3                              = {random_val[15:0],random_val[31:16],random_val[15:0],random_val[31:16]};
    cond_filter                        = {random_val[16:0],random_val[31:17],random_val[16:0],random_val[31:17]};
    store_right_y_d1                   = {random_val[17:0],random_val[31:18],random_val[17:0],random_val[31:18]};
    store_buf                          = {random_val[18:0],random_val[31:19],random_val[18:0],random_val[31:19]};
    store_up_i                         = {random_val[19:0],random_val[31:20],random_val[19:0],random_val[31:20]};
    store_up_addr                      = {random_val[20:0],random_val[31:21],random_val[20:0],random_val[31:21]};
    p0                                 = {random_val[21:0],random_val[31:22],random_val[21:0],random_val[31:22]};
    p1                                 = {random_val[22:0],random_val[31:23],random_val[22:0],random_val[31:23]};
    p2                                 = {random_val[23:0],random_val[31:24],random_val[23:0],random_val[31:24]};
    p3                                 = {random_val[24:0],random_val[31:25],random_val[24:0],random_val[31:25]};
    q0                                 = {random_val[25:0],random_val[31:26],random_val[25:0],random_val[31:26]};
    q1                                 = {random_val[26:0],random_val[31:27],random_val[26:0],random_val[31:27]};
    q2                                 = {random_val[27:0],random_val[31:28],random_val[27:0],random_val[31:28]};
    q3                                 = {random_val[28:0],random_val[31:29],random_val[28:0],random_val[31:29]};
    p0_d1                              = {random_val[29:0],random_val[31:30],random_val[29:0],random_val[31:30]};
    p1_d1                              = {random_val[30:0],random_val[31],random_val[30:0],random_val[31]};
    p2_d1                              = {random_val[31:0],random_val[31:0]};
    p3_d1                              = {random_val,random_val};
    q0_d1                              = {random_val[1:0],random_val[31:2],random_val[1:0],random_val[31:2]};
    q1_d1                              = {random_val[2:0],random_val[31:3],random_val[2:0],random_val[31:3]};
    q2_d1                              = {random_val[3:0],random_val[31:4],random_val[3:0],random_val[31:4]};
    q3_d1                              = {random_val[4:0],random_val[31:5],random_val[4:0],random_val[31:5]};
    p0_d2                              = {random_val[5:0],random_val[31:6],random_val[5:0],random_val[31:6]};
    p1_d2                              = {random_val[6:0],random_val[31:7],random_val[6:0],random_val[31:7]};
    p2_d2                              = {random_val[7:0],random_val[31:8],random_val[7:0],random_val[31:8]};
    p3_d2                              = {random_val[8:0],random_val[31:9],random_val[8:0],random_val[31:9]};
    q0_d2                              = {random_val[9:0],random_val[31:10],random_val[9:0],random_val[31:10]};
    q1_d2                              = {random_val[10:0],random_val[31:11],random_val[10:0],random_val[31:11]};
    q2_d2                              = {random_val[11:0],random_val[31:12],random_val[11:0],random_val[31:12]};
    q3_d2                              = {random_val[12:0],random_val[31:13],random_val[12:0],random_val[31:13]};
    p0_d3                              = {random_val[13:0],random_val[31:14],random_val[13:0],random_val[31:14]};
    p1_d3                              = {random_val[14:0],random_val[31:15],random_val[14:0],random_val[31:15]};
    p2_d3                              = {random_val[15:0],random_val[31:16],random_val[15:0],random_val[31:16]};
    p3_d3                              = {random_val[16:0],random_val[31:17],random_val[16:0],random_val[31:17]};
    q0_d3                              = {random_val[17:0],random_val[31:18],random_val[17:0],random_val[31:18]};
    q1_d3                              = {random_val[18:0],random_val[31:19],random_val[18:0],random_val[31:19]};
    q2_d3                              = {random_val[19:0],random_val[31:20],random_val[19:0],random_val[31:20]};
    q3_d3                              = {random_val[20:0],random_val[31:21],random_val[20:0],random_val[31:21]};
    p0_result                          = {random_val[21:0],random_val[31:22],random_val[21:0],random_val[31:22]};
    p1_result                          = {random_val[22:0],random_val[31:23],random_val[22:0],random_val[31:23]};
    p2_result                          = {random_val[23:0],random_val[31:24],random_val[23:0],random_val[31:24]};
    p3_result                          = {random_val[24:0],random_val[31:25],random_val[24:0],random_val[31:25]};
    q0_result                          = {random_val[25:0],random_val[31:26],random_val[25:0],random_val[31:26]};
    q1_result                          = {random_val[26:0],random_val[31:27],random_val[26:0],random_val[31:27]};
    q2_result                          = {random_val[27:0],random_val[31:28],random_val[27:0],random_val[31:28]};
    q3_result                          = {random_val[28:0],random_val[31:29],random_val[28:0],random_val[31:29]};
    valid                              = {random_val[29:0],random_val[31:30],random_val[29:0],random_val[31:30]};
    valid_d1                           = {random_val[30:0],random_val[31],random_val[30:0],random_val[31]};
    valid_d2                           = {random_val[31:0],random_val[31:0]};
    valid_d3                           = {random_val,random_val};
    valid_d4                           = {random_val[1:0],random_val[31:2],random_val[1:0],random_val[31:2]};
    valid_d5                           = {random_val[2:0],random_val[31:3],random_val[2:0],random_val[31:3]};
    deblock_x                          = {random_val[3:0],random_val[31:4],random_val[3:0],random_val[31:4]};
    deblock_y                          = {random_val[4:0],random_val[31:5],random_val[4:0],random_val[31:5]};
    bs_minus1_deblk                    = {random_val[5:0],random_val[31:6],random_val[5:0],random_val[31:6]};
    deblock_i                          = {random_val[6:0],random_val[31:7],random_val[6:0],random_val[31:7]};
    deblock_j                          = {random_val[7:0],random_val[31:8],random_val[7:0],random_val[31:8]};
    deblock_stage                      = {random_val[8:0],random_val[31:9],random_val[8:0],random_val[31:9]};
    kick_store                         = {random_val[9:0],random_val[31:10],random_val[9:0],random_val[31:10]};
    deblock_done                       = {random_val[10:0],random_val[31:11],random_val[10:0],random_val[31:11]};
    tc_deblk                           = {random_val[11:0],random_val[31:12],random_val[11:0],random_val[31:12]};
    dSam0_deblk                        = {random_val[12:0],random_val[31:13],random_val[12:0],random_val[31:13]};
    dSam3_deblk                        = {random_val[13:0],random_val[31:14],random_val[13:0],random_val[31:14]};
    dEp_deblk                          = {random_val[14:0],random_val[31:15],random_val[14:0],random_val[31:15]};
    dEq_deblk                          = {random_val[15:0],random_val[31:16],random_val[15:0],random_val[31:16]};
    bypass_p_deblk                     = {random_val[16:0],random_val[31:17],random_val[16:0],random_val[31:17]};
    bypass_q_deblk                     = {random_val[17:0],random_val[31:18],random_val[17:0],random_val[31:18]};
    cond_filter_deblk                  = {random_val[18:0],random_val[31:19],random_val[18:0],random_val[31:19]};
    p0_filter                          = {random_val[19:0],random_val[31:20],random_val[19:0],random_val[31:20]};
    p1_filter                          = {random_val[20:0],random_val[31:21],random_val[20:0],random_val[31:21]};
    p2_filter                          = {random_val[21:0],random_val[31:22],random_val[21:0],random_val[31:22]};
    q0_filter                          = {random_val[22:0],random_val[31:23],random_val[22:0],random_val[31:23]};
    q1_filter                          = {random_val[23:0],random_val[31:24],random_val[23:0],random_val[31:24]};
    q2_filter                          = {random_val[24:0],random_val[31:25],random_val[24:0],random_val[31:25]};
    p0_filter_clip                     = {random_val[25:0],random_val[31:26],random_val[25:0],random_val[31:26]};
    p1_filter_clip                     = {random_val[26:0],random_val[31:27],random_val[26:0],random_val[31:27]};
    p2_filter_clip                     = {random_val[27:0],random_val[31:28],random_val[27:0],random_val[31:28]};
    q0_filter_clip                     = {random_val[28:0],random_val[31:29],random_val[28:0],random_val[31:29]};
    q1_filter_clip                     = {random_val[29:0],random_val[31:30],random_val[29:0],random_val[31:30]};
    q2_filter_clip                     = {random_val[30:0],random_val[31],random_val[30:0],random_val[31]};
    dqp0_mult9                         = {random_val[31:0],random_val[31:0]};
    dqp1_mult3                         = {random_val,random_val};
    delta_clip_tc                      = {random_val[1:0],random_val[31:2],random_val[1:0],random_val[31:2]};
    delta_clip_tc_d1                   = {random_val[2:0],random_val[31:3],random_val[2:0],random_val[31:3]};
    cond_norm_filter                   = {random_val[3:0],random_val[31:4],random_val[3:0],random_val[31:4]};
    abs_delta                          = {random_val[4:0],random_val[31:5],random_val[4:0],random_val[31:5]};
    deltap                             = {random_val[5:0],random_val[31:6],random_val[5:0],random_val[31:6]};
    deltaq                             = {random_val[6:0],random_val[31:7],random_val[6:0],random_val[31:7]};
    deltap_tmp                         = {random_val[7:0],random_val[31:8],random_val[7:0],random_val[31:8]};
    deltaq_tmp                         = {random_val[8:0],random_val[31:9],random_val[8:0],random_val[31:9]};
    deltap_tmp_d1                      = {random_val[9:0],random_val[31:10],random_val[9:0],random_val[31:10]};
    deltaq_tmp_d1                      = {random_val[10:0],random_val[31:11],random_val[10:0],random_val[31:11]};
    p0_strong_tmp0                     = {random_val[11:0],random_val[31:12],random_val[11:0],random_val[31:12]};
    p1_strong_tmp0                     = {random_val[12:0],random_val[31:13],random_val[12:0],random_val[31:13]};
    p2_strong_tmp0                     = {random_val[13:0],random_val[31:14],random_val[13:0],random_val[31:14]};
    p0_strong_tmp1                     = {random_val[14:0],random_val[31:15],random_val[14:0],random_val[31:15]};
    p1_strong_tmp1                     = {random_val[15:0],random_val[31:16],random_val[15:0],random_val[31:16]};
    p2_strong_tmp1                     = {random_val[16:0],random_val[31:17],random_val[16:0],random_val[31:17]};
    q0_strong_tmp0                     = {random_val[17:0],random_val[31:18],random_val[17:0],random_val[31:18]};
    q1_strong_tmp0                     = {random_val[18:0],random_val[31:19],random_val[18:0],random_val[31:19]};
    q2_strong_tmp0                     = {random_val[19:0],random_val[31:20],random_val[19:0],random_val[31:20]};
    q0_strong_tmp1                     = {random_val[20:0],random_val[31:21],random_val[20:0],random_val[31:21]};
    q1_strong_tmp1                     = {random_val[21:0],random_val[31:22],random_val[21:0],random_val[31:22]};
    q2_strong_tmp1                     = {random_val[22:0],random_val[31:23],random_val[22:0],random_val[31:23]};
    debug_j                            = {random_val[23:0],random_val[31:24],random_val[23:0],random_val[31:24]};
    fetch_up_i                         = {random_val[24:0],random_val[31:25],random_val[24:0],random_val[31:25]};
    store_done                         = {random_val[25:0],random_val[31:26],random_val[25:0],random_val[31:26]};
    store_i                            = {random_val[26:0],random_val[31:27],random_val[26:0],random_val[31:27]};
    store_j                            = {random_val[27:0],random_val[31:28],random_val[27:0],random_val[31:28]};
    store_stage                        = {random_val[28:0],random_val[31:29],random_val[28:0],random_val[31:29]};
    fetch_up_stage                     = {random_val[29:0],random_val[31:30],random_val[29:0],random_val[31:30]};
    fetch_addr                         = {random_val[30:0],random_val[31],random_val[30:0],random_val[31]};
    store_right_y                      = {random_val[31:0],random_val[31:0]};
    do_store_right                     = {random_val,random_val};
    band                               = {random_val[1:0],random_val[31:2],random_val[1:0],random_val[31:2]};
    band_up                            = {random_val[2:0],random_val[31:3],random_val[2:0],random_val[31:3]};
    band_left                          = {random_val[3:0],random_val[31:4],random_val[3:0],random_val[31:4]};
    band_leftup                        = {random_val[4:0],random_val[31:5],random_val[4:0],random_val[31:5]};
    sao_left_class_plus_k              = {random_val[5:0],random_val[31:6],random_val[5:0],random_val[31:6]};
    sao_left_class_plus_k_up           = {random_val[6:0],random_val[31:7],random_val[6:0],random_val[31:7]};
    sao_left_class_plus_k_left         = {random_val[7:0],random_val[31:8],random_val[7:0],random_val[31:8]};
    sao_left_class_plus_k_leftup       = {random_val[8:0],random_val[31:9],random_val[8:0],random_val[31:9]};
    n                                  = {random_val[9:0],random_val[31:10],random_val[9:0],random_val[31:10]};
    sao_y                              = {random_val[10:0],random_val[31:11],random_val[10:0],random_val[31:11]};
    sao_type_left                      = {random_val[11:0],random_val[31:12],random_val[11:0],random_val[31:12]};
    sao_type_right                     = {random_val[12:0],random_val[31:13],random_val[12:0],random_val[31:13]};
    sao_eo_class_left                  = {random_val[13:0],random_val[31:14],random_val[13:0],random_val[31:14]};
    sao_eo_class_right                 = {random_val[14:0],random_val[31:15],random_val[14:0],random_val[31:15]};
    edge_idx                           = {random_val[15:0],random_val[31:16],random_val[15:0],random_val[31:16]};
    sao_buf_up                         = {random_val[16:0],random_val[31:17],random_val[16:0],random_val[31:17]};
    sao_buf                            = {random_val[17:0],random_val[31:18],random_val[17:0],random_val[31:18]};
    sao_buf_down                       = {random_val[18:0],random_val[31:19],random_val[18:0],random_val[31:19]};
    sao_result                         = {random_val[19:0],random_val[31:20],random_val[19:0],random_val[31:20]};
    sao_offset_band                    = '{69{random_val[3:0]}};
    sao_offset_edge                    = '{69{random_val[3:0]}};
    sao_nf_a_row                       = {random_val[22:0],random_val[31:23],random_val[22:0],random_val[31:23]};
    sign0                              = '{69{random_val[1:0]}};
    sign1                              = '{69{random_val[1:0]}};
    sao_result_band                    = {random_val[25:0],random_val[31:26],random_val[25:0],random_val[31:26]};
    sao_result_edge                    = {random_val[26:0],random_val[31:27],random_val[26:0],random_val[31:27]};
    sao_up_ctb_done                    = {random_val[27:0],random_val[31:28],random_val[27:0],random_val[31:28]};
    sao_valid                          = {random_val[28:0],random_val[31:29],random_val[28:0],random_val[31:29]};
    cond_last_sao_y                    = {random_val[29:0],random_val[31:30],random_val[29:0],random_val[31:30]};
    cond_sao_y_eq63                    = {random_val[30:0],random_val[31],random_val[30:0],random_val[31]};
    cur_ctb_ref_poc                    = {random_val[31:0],random_val[31:0]};
    store_mv_param_i                   = {random_val,random_val};
    cu_predmode                        = {random_val[1:0],random_val[31:2],random_val[1:0],random_val[31:2]};
    param_base_ddr                     = {random_val[2:0],random_val[31:3],random_val[2:0],random_val[31:3]};
    pic_base_ddr                       = {random_val[3:0],random_val[31:4],random_val[3:0],random_val[31:4]};
    pic_addr_off                       = {random_val[4:0],random_val[31:5],random_val[4:0],random_val[31:5]};
end
`endif



endmodule
