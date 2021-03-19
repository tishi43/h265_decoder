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

module filter_32
(
 input wire                                clk                        ,
 input wire                                rst                        ,
 input wire                                global_rst                 ,
 input wire                                i_rst_slice                ,
 input wire                                i_rst_ctb                  ,
 input wire                                en                         ,
 input wire                   [15:0]       i_slice_num                ,

 input wire        [`max_x_bits-1:0]       i_x0                       ,
 input wire        [`max_y_bits-1:0]       i_y0                       ,
 input wire signed            [ 5:0]       i_qp_cb_offset             , //-12~12
 input wire signed            [ 5:0]       i_qp_cr_offset             ,
 input wire                                i_component                , //0=cb,1=cr
 input wire                                i_first_row                ,
 input wire                                i_first_col                ,
 input wire                                i_last_row                 ,
 input wire                                i_last_col                 ,
 input wire                  [ 6:0]        i_last_col_width           ,
 input wire                  [ 6:0]        i_last_row_height          ,

 input wire                  [ 3:0]        i_slice_beta_offset_div2   ,
 input wire                  [ 3:0]        i_slice_tc_offset_div2     ,
 input wire [$bits(sao_params_t)-1:0]      i_sao_param                ,
 input wire [$bits(sao_params_t)-1:0]      i_sao_param_left           ,
 input wire [$bits(sao_params_t)-1:0]      i_sao_param_up             ,
 input wire [$bits(sao_params_t)-1:0]      i_sao_param_leftup         ,

 input wire      [ 7:0][15:0][ 1:0]        i_bs_ver                   ,
 input wire      [ 7:0][15:0][ 1:0]        i_bs_hor                   ,

 input wire            [ 7:0][ 7:0]        i_nf                       ,
 input wire      [ 7:0][ 7:0][ 5:0]        i_qpy                      ,

 output reg            [31:0]              dram_rec_we                ,
 output reg            [31:0][ 4:0]        dram_rec_addra             ,
 output reg            [31:0][ 4:0]        dram_rec_addrb             ,
 output reg            [31:0][ 4:0]        dram_rec_addrd             ,
 output reg            [31:0][ 7:0]        dram_rec_did               ,
 input wire            [31:0][ 7:0]        dram_rec_doa               ,
 input wire            [31:0][ 7:0]        dram_rec_dob               ,
 input wire            [31:0][ 7:0]        dram_rec_dod               ,

 input wire                  [47:0]        bram_up_ctb_qpy_dout       ,
 input wire                  [ 7:0]        bram_up_ctb_nf_dout        ,
 output reg   [`max_ctb_x_bits-1:0]        bram_up_ctb_qpy_addr       ,
 output reg   [`max_ctb_x_bits-1:0]        bram_up_ctb_nf_addr        ,

 input wire                  [31:0]        i_pic_base_ddr             ,
 input wire                                m_axi_awready              ,
 output reg                  [31:0]        m_axi_awaddr               ,
 output reg                  [ 3:0]        m_axi_awlen                ,
 output reg                                m_axi_awvalid              ,

 input  wire                               m_axi_wready               ,
 output reg                  [63:0]        m_axi_wdata                ,
 output reg                  [ 7:0]        m_axi_wstrb                ,
 output reg                                m_axi_wlast                ,
 output reg                                m_axi_wvalid               ,


 input wire                  [31:0]        fd_filter                  ,
 input wire                  [31:0]        fd_deblock                 ,
 output reg                  [ 2:0]        o_filter_state

);

//色度，左边保留4列，上边保留3行，

//deblock垂直滤波，以x=24为例，一直滤到底，到h0，h1，h2，h3这行，
//deblock水平滤波，以y=24为例，滤到a5，b5，c5，d5这列。a6在下一ctb垂直滤波时不会变，但是会用到a6，a7，所以a6不能水平滤波，滤波的话下一ctb垂直滤波时a6值就变了
//a5 sao滤波要用到a6，所以a5不能sao滤波，要保留a4这列，因为a5 sao滤波要用到，
//sao滤波，滤到a4这列，f0这行。g0这行用到h0，h0水平滤波未完成，

//保留3行都放到下一行ctb垂直滤波？不行，这样sao滤波只能滤到d0这行，要保留到c0这行，up要保留6行了，
//同理水平滤波必须滤到a5这列，

//  x        24  25 26 27  28  29  30  31   32 下一ctb    
//             |  |  |    |  |   |   |  |          y23
//---------------------------------------         
//           a0|a1|a2|a3  |a4| a5|a6 |a7|   a8      y24
//---------------------------------------        
//           b0|b1|b2|b3  |b4| b5|b6 |b7|   b8      y25
//---------------------------------------        
//           c0|c1|c2|c3  |c4| c5|c6 |c7|   c8      y26
//---------------------------------------         
//           d0|d1|d2| d3 |d4| d5|d6 |d7|   d8      y27
//---------------------------------------        
//           e0|e1|e2|e3  |e4| e5|e6 |e7|   e8      y28
//---------------------------------------        
//           f0|f1|f2|f3  |f4| f5|f6 |f7|   f8      y29
//---------------------------------------         
//           g0|g1|g2|g3  |g4| g5|g6 |g7|   g8      y30
//---------------------------------------        
//          h0 |h1|h2| h3 |h4| h5|h6 |h7|   h8      y31
//---------------------------------------        


reg     [ 3:0]               stage                   ;
reg     [ 4:0]               phase                   ;

reg     [`max_x_bits-1:0]    x0                      ;
reg     [`max_x_bits-1:0]    y0                      ;
reg     [ 4:0]               x                       ;
reg     [ 4:0]               y                       ;
reg     [ 4:0]               y_pls1                  ;
reg     [ 3:0]               i                       ;
reg     [`max_x_bits-1:0]    x0_minus4               ;
reg                          first_col               ;
reg                          first_row               ;
reg                          last_col                ;
reg                          last_row                ;
reg     [ 4:0]               last_row_height_minus1  ;
reg     [ 4:0]               last_col_width_minus1   ;
reg     [ 3:0]               prefetch_stage          ;
reg     [ 5:0]               fetch_x                 ; //亮度坐标
reg     [ 5:0]               fetch_y                 ;

sao_params_t                 sao_param               ;
sao_params_t                 sao_param_left          ;
sao_params_t                 sao_param_up            ;
sao_params_t                 sao_param_leftup        ;

reg     [ 3:0]               fetch_i                 ; //0~8
wire    [ 3:0]               fetch_i_pls1            ;
reg     [ 3:0]               fetch_j                 ;
reg     [ 5:0]               last_fetch_x            ;
reg     [ 5:0]               last_fetch_y            ;
reg                          kick_deblock            ;
reg     [ 5:0]               x_to_deblock            ; //亮度坐标
reg     [ 5:0]               y_to_deblock            ;
reg     [ 3:0]               i_to_deblock            ;
assign fetch_i_pls1 = fetch_i+1;

reg     [ 4:0]               store_x                 ;
reg     [ 4:0]               store_y                 ;
reg     [ 4:0]               x_to_store              ;
reg     [ 4:0]               y_to_store              ;
reg     [ 3:0]               i_to_store              ;
reg                          component               ;

reg     [ 7:0]               bs_a_row                ; //只有bs=2才滤波，取1bit就够
reg     [ 7:0]               bs_a_col                ;

reg     [ 7:0]               nf_up_row               ;
reg     [ 7:0]               nf_down_row             ;
reg     [ 7:0]               nf_left_col             ;
reg     [ 7:0]               nf_right_col            ;
reg     [ 7:0]               nf_left_ctb_last_col    ;
reg     [35:0][ 7:0]         row_up0                 ;//32+4
reg     [ 7:0]               nf_up_ctb               ;
reg     [ 7:0]               nf_up_ctb_copy          ; //减少bram出来的路径

reg     [ 7:0][ 5:0]         qpy_up_row              ;
reg     [ 7:0][ 5:0]         qpy_down_row            ;
reg     [ 7:0][ 5:0]         qpy_up_ctb              ;
reg     [ 7:0][ 5:0]         qpy_up_ctb_copy         ;
reg     [ 7:0][ 5:0]         qpy_left_col            ;
reg     [ 7:0][ 5:0]         qpy_right_col           ;
reg     [ 7:0][ 5:0]         qpy_left_ctb_last_col   ;


reg     [ 5:0]               hor_deblock_done_y      ;
reg                          hor_deblock_done        ;
reg                          bs                      ;

wire    [ 2:0]               left_idx                ;
wire    [ 2:0]               right_idx               ;
wire    [ 2:0]               up_idx                  ;
wire    [ 2:0]               down_idx                ;

assign left_idx   = fetch_x[5:3]-1;
assign right_idx  = fetch_x[5:3];
assign up_idx     = fetch_y[5:3]-1;
assign down_idx   = fetch_y[5:3];

reg     [ 5:0]               QpP                     ;
reg     [ 5:0]               QpQ                     ;
reg                          bypass_p                ;
reg                          bypass_q                ;

reg     [ 3:0][ 7:0]         fetch_ver_a_row         ; //wire
reg     [ 3:0][ 7:0]         fetch_hor_a_row         ;
reg     [ 1:0]               wait_cycle              ;

reg     [ 3:0][ 3:0][ 7:0]   pq_buf                  ;
reg     [ 3:0][ 3:0][ 7:0]   pq_buf_bk               ;

reg     [ 3:0][ 1:0][ 7:0]   deblock_buf             ;
reg     [ 3:0][ 1:0][ 7:0]   deblock_buf_bk          ;




reg     [ 3:0]               bs_hor_left_ctb_last_col;
reg                          bs_hor_left_ctb_cur_row ;
reg                          nf_leftup               ;
reg                          nf_leftup_bk            ;
reg     [ 5:0]               qpy_leftup              ;
reg     [ 5:0]               qpy_leftup_bk           ;

reg     [ 2:0]                   bram_cb_up_3row_we;
reg     [ 2:0][`max_x_bits-4:0]  bram_cb_up_3row_addra;
reg     [ 2:0][`max_x_bits-4:0]  bram_cb_up_3row_addrb;
reg     [ 2:0][31:0]             bram_cb_up_3row_dia;
wire    [ 2:0][31:0]             bram_cb_up_3row_doa;
wire    [ 2:0][31:0]             bram_cb_up_3row_dob;

reg           [ 7:0]             h6;
reg           [ 7:0]             h7;
reg           [ 7:0]             h4;
reg           [ 7:0]             h5;

genvar I;
generate
    for (I=0;I<3;I++)
    begin: bram_cb_up_3rows_label
        ram_d #(`max_x_bits-3, 32) bram_cb_up_3row
        (
            .clk(clk),
            .en(1'b1),
            .we(bram_cb_up_3row_we[I]),
            .addra(bram_cb_up_3row_addra[I]),
            .addrb(bram_cb_up_3row_addrb[I]),
            .dia(bram_cb_up_3row_dia[I]),
            .doa(bram_cb_up_3row_doa[I]),
            .dob(bram_cb_up_3row_dob[I])
        );
    end
endgenerate

reg  [ 2:0]                   bram_cr_up_3row_we;
reg  [ 2:0][`max_x_bits-4:0]  bram_cr_up_3row_addra;
reg  [ 2:0][`max_x_bits-4:0]  bram_cr_up_3row_addrb;
reg  [ 2:0][31:0]             bram_cr_up_3row_dia;
wire [ 2:0][31:0]             bram_cr_up_3row_doa;
wire [ 2:0][31:0]             bram_cr_up_3row_dob;

generate
    for (I=0;I<3;I++)
    begin: bram_cr_up_3rows_label
        ram_d #(`max_x_bits-3, 32) bram_cr_up_3row
        (
            .clk(clk),
            .en(1'b1),
            .we(bram_cr_up_3row_we[I]),
            .addra(bram_cr_up_3row_addra[I]),
            .addrb(bram_cr_up_3row_addrb[I]),
            .dia(bram_cr_up_3row_dia[I]),
            .doa(bram_cr_up_3row_doa[I]),
            .dob(bram_cr_up_3row_dob[I])
        );
    end
endgenerate


reg    [3:0]              dram_cb_right_4col_we          ;
reg    [3:0][4:0]         dram_cb_right_4col_addra       ;
reg    [3:0][4:0]         dram_cb_right_4col_addrb       ;
reg    [3:0][4:0]         dram_cb_right_4col_addrd       ;
reg    [3:0][7:0]         dram_cb_right_4col_did         ;
wire   [3:0][7:0]         dram_cb_right_4col_doa         ;
wire   [3:0][7:0]         dram_cb_right_4col_dob         ;
wire   [3:0][7:0]         dram_cb_right_4col_dod         ;


reg    [3:0]              dram_cr_right_4col_we          ;
reg    [3:0][4:0]         dram_cr_right_4col_addra       ;
reg    [3:0][4:0]         dram_cr_right_4col_addrb       ;
reg    [3:0][4:0]         dram_cr_right_4col_addrd       ;
reg    [3:0][7:0]         dram_cr_right_4col_did         ;
wire   [3:0][7:0]         dram_cr_right_4col_doa         ;
wire   [3:0][7:0]         dram_cr_right_4col_dob         ;
wire   [3:0][7:0]         dram_cr_right_4col_dod         ;

wire   [3:0][7:0]         dram_right_4col_doa            ;
wire   [3:0][7:0]         dram_right_4col_dob            ;
wire   [3:0][7:0]         dram_right_4col_dod            ;

assign dram_right_4col_doa = component?dram_cr_right_4col_doa:dram_cb_right_4col_doa;
assign dram_right_4col_dob = component?dram_cr_right_4col_dob:dram_cb_right_4col_dob;
assign dram_right_4col_dod = component?dram_cr_right_4col_dod:dram_cb_right_4col_dod;


always @ (*)
begin
    if (dram_cb_right_4col_addrd[1]==7&&dram_cb_right_4col_we[1]==1&&o_filter_state == `deblocking_hor) begin
        $display("%t hor dram_cb_right_4col[1]=%d x0 %d y0 %d",$time,dram_cb_right_4col_did[1],x0,y0);
    end

    if (dram_cb_right_4col_addrd[1]==7&&dram_cb_right_4col_we[1]==1&&o_filter_state == `deblocking_ver) begin
        $display("%t ver dram_cb_right_4col[1]=%d x0 %d y0 %d",$time,dram_cb_right_4col_did[1],x0,y0);
    end

end

generate
    for (I=0;I<4;I++)
    begin: dram_cb_right_4col_label
        dram_m #(5, 8) dram_cb_right_4col
        (
            .clk(clk),
            .en(1'b1),
            .we(dram_cb_right_4col_we[I]),
            .addrd(dram_cb_right_4col_addrd[I]),
            .addra(dram_cb_right_4col_addra[I]),
            .addrb(dram_cb_right_4col_addrb[I]),
            .did(dram_cb_right_4col_did[I]),
            .doa(dram_cb_right_4col_doa[I]),
            .dob(dram_cb_right_4col_dob[I]),
            .dod(dram_cb_right_4col_dod[I])
        );
    end
endgenerate

generate
    for (I=0;I<4;I++)
    begin: dram_cr_right_4col_label
        dram_m #(5, 8) dram_cr_right_4col
        (
            .clk(clk),
            .en(1'b1),
            .we(dram_cr_right_4col_we[I]),
            .addrd(dram_cr_right_4col_addrd[I]),
            .addra(dram_cr_right_4col_addra[I]),
            .addrb(dram_cr_right_4col_addrb[I]),
            .did(dram_cr_right_4col_did[I]),
            .doa(dram_cr_right_4col_doa[I]),
            .dob(dram_cr_right_4col_dob[I]),
            .dod(dram_cr_right_4col_dod[I])
        );
    end
endgenerate


reg                           fetch_up_3row_done;
reg                           sao_done;

reg  [ 2:0]                   dram_up_3row_we;
reg  [ 2:0][ 3:0]             dram_up_3row_addrd; //位宽32，4字节，深度16只存9,4x9=36,right 4 column存一个slot
reg  [ 2:0][ 3:0]             dram_up_3row_addra;
reg  [ 2:0][ 3:0]             dram_up_3row_addrb;
reg  [ 2:0][31:0]             dram_up_3row_did;
wire [ 2:0][31:0]             dram_up_3row_doa;
wire [ 2:0][31:0]             dram_up_3row_dob;
wire [ 2:0][31:0]             dram_up_3row_dod;

//                    28 29 30 31   0  1  2  3
// dram_up_3row[i]     addr=0         addr=1 
//           data    [31:24] [23:16] [15:8] [7:0]
//                     31     30       29    28

always @ (*)
begin

    if (dram_up_3row_addrd[0]==0&&dram_up_3row_did[0][15:8]==109&&dram_up_3row_we[0]==1) begin
        $display("%t filter32 dram 109 x0 %d y0 %d",$time,x0,y0);
    end


    if (dram_up_3row_addrd[0]==0&&dram_up_3row_did[0][15:8]==110&&dram_up_3row_we[0]==1) begin
        $display("%t filter32 dram 110 x0 %d y0 %d",$time,x0,y0);
    end

end


generate
    for (I=0;I<3;I++)
    begin: dram_up_3rows_label
        dram_m #(4, 32) dram_up_3row
        (
            .clk(clk),
            .en(1'b1),
            .we(dram_up_3row_we[I]),
            .addra(dram_up_3row_addra[I]),
            .addrb(dram_up_3row_addrb[I]),
            .addrd(dram_up_3row_addrd[I]),
            .did(dram_up_3row_did[I]),
            .doa(dram_up_3row_doa[I]),
            .dob(dram_up_3row_dob[I]),
            .dod(dram_up_3row_dod[I])
        );
    end
endgenerate


wire signed           [ 6:0]         qPL               ;
reg  signed           [ 6:0]         qPi               ;
reg  signed           [ 5:0]         c_qp_pic_offset   ;
reg             [0:13][ 6:0]         qpc_tab           ;
reg  signed           [ 6:0]         QpC               ;
initial begin
    qpc_tab = {7'd29, 7'd30, 7'd31, 7'd32, 7'd33, 7'd33, 7'd34, 7'd34, 7'd35, 7'd35, 7'd36, 7'd36, 7'd37, 7'd37};
end

reg                  [ 5:0]          Q                 ;
reg                  [ 4:0]          tC                ;
wire                 [ 3:0]          qpc_idx           ;
wire signed          [ 6:0]          q_temp            ;


reg            [0:53][ 4:0]          tc_tab            ;
reg  signed          [ 7:0]          neg_tc            ;

initial begin
    tc_tab = {
        5'd0, 5'd0, 5'd0, 5'd0, 5'd0, 5'd0, 5'd0, 5'd0, 5'd0, 5'd0, 5'd0, 5'd0, 5'd0, 5'd0, 5'd0, 5'd0,
        5'd0, 5'd0, 5'd1, 5'd1, 5'd1, 5'd1, 5'd1, 5'd1, 5'd1, 5'd1, 5'd1, 5'd2, 5'd2, 5'd2, 5'd2, 5'd3,
        5'd3, 5'd3, 5'd3, 5'd4, 5'd4, 5'd4, 5'd5, 5'd5, 5'd6, 5'd6, 5'd7, 5'd8, 5'd9, 5'd10, 5'd11, 5'd13,
        5'd14, 5'd16, 5'd18, 5'd20, 5'd22, 5'd24};


end

assign qPL = (QpP+QpQ+1)>>1;
//clock 0
always @ (posedge clk)
begin
    qPi <= qPL+c_qp_pic_offset;
end

assign qpc_idx=qPi-30;

//clock 1
always @ (posedge clk)
begin
    if (qPi<30) begin //暂不考虑小于0的情况
        QpC  <= qPi;
    end else if (qPi>43) begin
        QpC  <= qPi-6;
    end else begin
        QpC  <= qpc_tab[qpc_idx];
    end

end

assign q_temp = QpC+2+(i_slice_tc_offset_div2<<<1);
//clock 2
always @ (posedge clk)
begin
    if (q_temp<53)
        Q  <= q_temp;
    else
        Q  <= 53;
end

//clock 3
always @ (posedge clk)
begin
    tC    <= tc_tab[Q];
end

always @ (fetch_x or dram_rec_doa or dram_right_4col_doa)
begin
    case (fetch_x[5:4])
    0: fetch_ver_a_row <= {dram_rec_doa[1:0],
                           dram_right_4col_doa[0],
                           dram_right_4col_doa[1]};
    1: fetch_ver_a_row <= dram_rec_doa[9:6];
    2: fetch_ver_a_row <= dram_rec_doa[17:14];
    3: fetch_ver_a_row <= dram_rec_doa[25:22];
    endcase
end

always @ (fetch_i or dram_rec_doa or dram_right_4col_doa)
begin
    case (fetch_i)
    0: fetch_hor_a_row <= {dram_right_4col_doa[0],
                           dram_right_4col_doa[1],
                           16'd0};
    1: fetch_hor_a_row <= dram_rec_doa[3:0];
    2: fetch_hor_a_row <= dram_rec_doa[7:4];
    3: fetch_hor_a_row <= dram_rec_doa[11:8];
    4: fetch_hor_a_row <= dram_rec_doa[15:12];
    5: fetch_hor_a_row <= dram_rec_doa[19:16];
    6: fetch_hor_a_row <= dram_rec_doa[23:20];
    7: fetch_hor_a_row <= dram_rec_doa[27:24];
    default: fetch_hor_a_row <= dram_rec_doa[31:28];
    endcase
end

reg             [ 4:0]          store_right_y_d1         ;
reg       [35:0][ 7:0]          store_buf                ;
reg             [ 3:0]          store_up_i               ; //0~8
reg  [`max_x_bits-4:0]          store_up_addr            ;


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
    last_row_height_minus1   <= i_last_row_height[6:1]-1;
    last_col_width_minus1    <= i_last_col_width[6:1]-1;
    sao_param                <= i_sao_param;
    sao_param_left           <= i_sao_param_left;
    sao_param_up             <= i_sao_param_up;
    sao_param_leftup         <= i_sao_param_leftup;
    kick_deblock             <= 0;

end else if (rst) begin
    x                        <= 0;
    y                        <= 0;

    if (first_col)
        fetch_x              <= 16;
    else
        fetch_x              <= 0;
    fetch_y                  <= 0;
    last_fetch_x             <= 0;
    last_fetch_y             <= 0;
    fetch_i                  <= 0;
    fetch_j                  <= 0;
    stage                    <= 0;
    x0_minus4                <= i_x0-4;
    prefetch_stage           <= 0;
    hor_deblock_done         <= 0;
    component                <= i_component;
    if (component)
        c_qp_pic_offset      <= i_qp_cr_offset;
    else
        c_qp_pic_offset      <= i_qp_cb_offset;

    if (first_col) begin
        nf_leftup            <= 1;
    end
    if (first_row)
        o_filter_state       <= `deblocking_ver;
    else
        o_filter_state       <= `filter_fetch_up;

end else if (en && o_filter_state == `filter_fetch_up) begin
    if (fetch_up_3row_done)
        o_filter_state       <= `deblocking_ver;


end else if (en && o_filter_state == `deblocking_ver) begin

    //prefetch
    if (prefetch_stage == 0) begin
        //qpy_right_col,reset filter时也不会reset，下一个ctb用，
        //这个qpy_right_col可以同样用于左边ctb最右4列的水平滤波
        //最左边的ctb，第一列时不用滤波，qpy_left_col设错无所谓

       //垂直
       //p30 p20 p10 p00   q00 q10 q20 q30
       //p31 p21 p11 p01   q01 q11 q21 q31
       //p32 p22 p12 p02   q02 q12 q22 q32
       //p33 p23 p13 p03   q03 q13 q23 q33

        bs_a_col             <= {i_bs_ver[fetch_x[5:3]][14][1],
                                 i_bs_ver[fetch_x[5:3]][12][1],
                                 i_bs_ver[fetch_x[5:3]][10][1],
                                 i_bs_ver[fetch_x[5:3]][8][1],
                                 i_bs_ver[fetch_x[5:3]][6][1],
                                 i_bs_ver[fetch_x[5:3]][4][1],
                                 i_bs_ver[fetch_x[5:3]][2][1],
                                 i_bs_ver[fetch_x[5:3]][0][1]};

        //fix,色度滤波是x=0，16，32，48，最后保存的right_col是x=48，不是x=56
        qpy_left_col         <= fetch_x[5:3]==0?qpy_left_ctb_last_col:
                                {i_qpy[7][left_idx],
                                 i_qpy[6][left_idx],
                                 i_qpy[5][left_idx],
                                 i_qpy[4][left_idx],
                                 i_qpy[3][left_idx],
                                 i_qpy[2][left_idx],
                                 i_qpy[1][left_idx],
                                 i_qpy[0][left_idx]};
        qpy_right_col        <= {i_qpy[7][fetch_x[5:3]],
                                 i_qpy[6][fetch_x[5:3]],
                                 i_qpy[5][fetch_x[5:3]],
                                 i_qpy[4][fetch_x[5:3]],
                                 i_qpy[3][fetch_x[5:3]],
                                 i_qpy[2][fetch_x[5:3]],
                                 i_qpy[1][fetch_x[5:3]],
                                 i_qpy[0][fetch_x[5:3]]};
        nf_left_col           <= fetch_x[5:3]==0?nf_left_ctb_last_col:
                                 {i_nf[7][left_idx],
                                  i_nf[6][left_idx],
                                  i_nf[5][left_idx],
                                  i_nf[4][left_idx],
                                  i_nf[3][left_idx],
                                  i_nf[2][left_idx],
                                  i_nf[1][left_idx],
                                  i_nf[0][left_idx]};
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
    //28,29,[30,31,0,1,2,3, ... 28,29,]30,31
    //最左边28,29，最右边30,31可以不deblock，保持统一也deblock
    if (prefetch_stage == 1) begin
        bs_a_col                       <= {1'b0,bs_a_col[7:1]};
        bs                             <= bs_a_col[0];
        if (bs_a_col == 8'd0) begin
            if (fetch_x[5:4] == 3) begin
                prefetch_stage         <= 5; //原地等待
            end else begin
                prefetch_stage         <= 0;
                fetch_x                <= fetch_x+16;
                fetch_y                <= 0;
            end

        end else if (bs_a_col[0]) begin
            prefetch_stage             <= 2;
        end else begin
            fetch_y                    <= fetch_y+8;

        end

        kick_deblock                   <= 0;
    end

    if (prefetch_stage == 2) begin

        QpP                            <= qpy_left_col[fetch_y[5:3]];
        QpQ                            <= qpy_right_col[fetch_y[5:3]];
        bypass_p                       <= nf_left_col[fetch_y[5:3]];
        bypass_q                       <= nf_right_col[fetch_y[5:3]];
        dram_rec_addra                 <= {32{fetch_y[5:1]}};
        if (component)
            dram_cr_right_4col_addra   <= {4{fetch_y[5:1]}};
        else
            dram_cb_right_4col_addra   <= {4{fetch_y[5:1]}};

        fetch_j                        <= 0;
        fetch_y                        <= fetch_y+2;

        prefetch_stage                 <= 3;
    end

    //fetch_j,8x4,4行之一
    if (prefetch_stage == 3) begin
        pq_buf                         <= {fetch_ver_a_row,pq_buf[3:1]};
        dram_rec_addra                 <= {32{fetch_y[5:1]}};
        if (component)
            dram_cr_right_4col_addra   <= {4{fetch_y[5:1]}};
        else
            dram_cb_right_4col_addra   <= {4{fetch_y[5:1]}};

        if (fetch_j==3) begin
            prefetch_stage             <= 4;
            wait_cycle                 <= 0; //fetch比deblock快了
        end else begin
            fetch_y                    <= fetch_y+2;
            fetch_j                    <= fetch_j+1;
        end
    end

    if (prefetch_stage == 4) begin
        //等待2周期，到dSam0,dSam3,cond_filter就绪
        wait_cycle                     <= wait_cycle+1;
        last_fetch_x                   <= fetch_x;
        last_fetch_y                   <= fetch_y-2;

        if (wait_cycle==3) begin
            x_to_deblock               <= fetch_x;
            y_to_deblock               <= fetch_y-8;//to debug
            prefetch_stage             <= 1;
            kick_deblock               <= 1;
        end
    end

    if (prefetch_stage == 5) begin
        if (store_y == last_fetch_y[5:1] &&
            store_x == last_fetch_x[5:1]) begin
            fetch_x                    <= first_col?0:56;
            fetch_i                    <= first_col?1:0;
            fetch_y                    <= first_row?16:0;
            prefetch_stage             <= first_row?4:0;
            o_filter_state             <= `deblocking_hor;
        end
    end

end else if (en && o_filter_state == `deblocking_hor) begin
    if (sao_done == 1) begin
        //存，为下一个ctb(右边ctb)用,cb之后cr还要用，cr之后才能覆盖
        if (component) begin
            bs_hor_left_ctb_last_col   <= {i_bs_hor[6][14][1],
                                           i_bs_hor[4][14][1],
                                           i_bs_hor[2][14][1],
                                           i_bs_hor[0][14][1]}; //to debug

            qpy_left_ctb_last_col      <= {i_qpy[7][7],
                                           i_qpy[6][7],
                                           i_qpy[5][7],
                                           i_qpy[4][7],
                                           i_qpy[3][7],
                                           i_qpy[2][7],
                                           i_qpy[1][7],
                                           i_qpy[0][7]};
            nf_left_ctb_last_col       <= {i_nf[7][7],
                                           i_nf[6][7],
                                           i_nf[5][7],
                                           i_nf[4][7],
                                           i_nf[3][7],
                                           i_nf[2][7],
                                           i_nf[1][7],
                                           i_nf[0][7]};
        end
        o_filter_state                 <= `filter_store_up_right;
    end

    if (prefetch_stage == 0) begin
        nf_leftup                      <= nf_leftup_bk;
        qpy_leftup                     <= qpy_leftup_bk;
        bram_up_ctb_qpy_addr           <= x0[`max_x_bits-1:6];
        bram_up_ctb_nf_addr            <= x0[`max_x_bits-1:6];
        prefetch_stage                 <= 1;
    end

    if (prefetch_stage == 1) begin
        prefetch_stage                 <= 2;
    end
    if (prefetch_stage == 2) begin
        nf_up_ctb                      <= bram_up_ctb_nf_dout;
        qpy_up_ctb                     <= bram_up_ctb_qpy_dout;
        if (component)
            nf_leftup_bk               <= bram_up_ctb_nf_dout[7];
        if (component)
            qpy_leftup_bk              <= bram_up_ctb_qpy_dout[47:42];

        fetch_y                        <= 0;
        prefetch_stage                 <= 3;
    end
    if (prefetch_stage == 3) begin
        qpy_up_ctb_copy                <= qpy_up_ctb;
        nf_up_ctb_copy                 <= nf_up_ctb;
        prefetch_stage                 <= 4;
    end

    if (prefetch_stage == 4) begin
        //这里fetch_y=0,8,16,..., bs_a_row不需要up ctb
        bs_a_row                        <= {i_bs_hor[fetch_y[5:3]][14][1],
                                            i_bs_hor[fetch_y[5:3]][12][1],
                                            i_bs_hor[fetch_y[5:3]][10][1],
                                            i_bs_hor[fetch_y[5:3]][8][1],
                                            i_bs_hor[fetch_y[5:3]][6][1],
                                            i_bs_hor[fetch_y[5:3]][4][1],
                                            i_bs_hor[fetch_y[5:3]][2][1],
                                            i_bs_hor[fetch_y[5:3]][0][1]};
        qpy_up_row                       <= fetch_y[5:3]==0?qpy_up_ctb_copy:i_qpy[up_idx];
        qpy_down_row                     <= i_qpy[fetch_y[5:3]];
        nf_up_row                        <= fetch_y[5:3]==0?nf_up_ctb_copy:i_nf[up_idx];
        nf_down_row                      <= i_nf[fetch_y[5:3]];

        bs_hor_left_ctb_cur_row          <= bs_hor_left_ctb_last_col[fetch_y[5:4]]; //to debug
        prefetch_stage                   <= 5;
    end

    if (prefetch_stage == 5) begin

        fetch_j                          <= 0;
        bs                               <= fetch_i == 0?bs_hor_left_ctb_cur_row:bs_a_row[0];

        if (fetch_i) begin
            bs_a_row                     <= {1'b0,bs_a_row[7:1]};
            if (bs_a_row==8'd0) begin
                if (fetch_y[5:4] == 3) begin
                    prefetch_stage       <= 5; //取到了最后一行,结束,原地等待
                    if (store_y==last_fetch_y[5:1]&&
                        store_x==last_fetch_x[5:1])
                        hor_deblock_done <= 1;
                end else begin
                    prefetch_stage       <= 4;
                    fetch_x              <= first_col?0:56;
                    fetch_i              <= first_col?1:0;
                    fetch_y              <= fetch_y+16;
                end
            end else if (bs_a_row[0]==0) begin
                prefetch_stage           <= 5;
                fetch_x                  <= fetch_x+8;
                fetch_i                  <= fetch_i+1;
            end else begin
                if (fetch_y == 0) begin
                    prefetch_stage       <= 6;
                end else begin
                    prefetch_stage       <= 8;
                    fetch_y              <= fetch_y-4;
                end
            end
        end else begin
            if (bs_hor_left_ctb_cur_row==0) begin
                prefetch_stage           <= 5;
                fetch_x                  <= fetch_x+8;
                fetch_i                  <= fetch_i+1;
            end else begin
                if (fetch_y == 0) begin
                    prefetch_stage       <= 6;
                end else begin
                    prefetch_stage       <= 8;
                    fetch_y              <= fetch_y-4;
                end
            end
        end

        kick_deblock <= 0;
    end

    //stage 6,7,leftup,up
    if (prefetch_stage == 6) begin
        //这里fetch_y=0,8,16,...
        QpP                              <= fetch_i==0 ? qpy_leftup:qpy_up_row[fetch_x[5:3]];
        QpQ                              <= fetch_i==0 ? qpy_left_ctb_last_col[fetch_y[5:3]]:qpy_down_row[fetch_x[5:3]];

        bypass_p                         <= fetch_i==0 ? nf_leftup:nf_up_row[fetch_x[5:3]];
        bypass_q                         <= fetch_i==0 ? nf_left_ctb_last_col[fetch_y[5:3]]:nf_down_row[fetch_x[5:3]];

        dram_up_3row_addra               <= {3{fetch_i}};
        prefetch_stage                   <= 7;
    end


    if (prefetch_stage == 7) begin
        //取上/左上ctb
        pq_buf[0]                        <= {dram_up_3row_doa[0][7:0],dram_up_3row_doa[1][7:0],16'd0};
        pq_buf[1]                        <= {dram_up_3row_doa[0][15:8],dram_up_3row_doa[1][15:8],16'd0};
        pq_buf[2]                        <= {dram_up_3row_doa[0][23:16],dram_up_3row_doa[1][23:16],16'd0};
        pq_buf[3]                        <= {dram_up_3row_doa[0][31:24],dram_up_3row_doa[1][31:24],16'd0};

       //水平 [7:0][15:8][23:16][31:24] dram_up_3row_doa[i]
        //       28  29    30    31
        //pq_buf[0]  [1]   [2]   [3]
        //      p10  p11   p12   p13 dram_up_3row_doa[1] 30
        //      p00  p01   p02   p03 dram_up_3row_doa[0] 31

        //      q00  q01   q02   q03
        //      q10  q11   q12   q13

        fetch_j                         <= 2; //fetch_j,色度取4行就够了,已取2行
        prefetch_stage                  <= 9;
        dram_rec_addra                  <= {32{fetch_y[5:1]}}; //前2行不需要取，仅需p0,p1,q0,q1
        if (component)
            dram_cr_right_4col_addra    <= {4{fetch_y[5:1]}};
        else
            dram_cb_right_4col_addra    <= {4{fetch_y[5:1]}};
        fetch_y                         <= fetch_y+2;
    end

    //left,center
    if (prefetch_stage == 8) begin
        //这里y已经减4,y=4,12,18,...
        QpP                             <= fetch_i==0 ? qpy_left_ctb_last_col[fetch_y[5:3]]:qpy_up_row[fetch_x[5:3]];
        QpQ                             <= fetch_i==0 ? qpy_left_ctb_last_col[fetch_y[5:3]+1]:qpy_down_row[fetch_x[5:3]];
        bypass_p                        <= fetch_i==0 ? nf_left_ctb_last_col[fetch_y[5:3]]:nf_up_row[fetch_x[5:3]];
        bypass_q                        <= fetch_i==0 ? nf_left_ctb_last_col[fetch_y[5:3]+1]:nf_down_row[fetch_x[5:3]];

        dram_rec_addra                  <= {32{fetch_y[5:1]}}; //前2行不需要取，仅需p0,p1,q0,q1
        if (component)
            dram_cr_right_4col_addra    <= {4{fetch_y[5:1]}};
        else
            dram_cb_right_4col_addra    <= {4{fetch_y[5:1]}};
        fetch_y                         <= fetch_y+2;
        fetch_j                         <= 0;
        prefetch_stage                  <= 9;
    end

    if (prefetch_stage == 9) begin
        pq_buf[0]                       <= {fetch_hor_a_row[0],pq_buf[0][3:1]};
        pq_buf[1]                       <= {fetch_hor_a_row[1],pq_buf[1][3:1]};
        pq_buf[2]                       <= {fetch_hor_a_row[2],pq_buf[2][3:1]};
        pq_buf[3]                       <= {fetch_hor_a_row[3],pq_buf[3][3:1]};

        dram_rec_addra                  <= {32{fetch_y[5:1]}};
        if (component)
            dram_cr_right_4col_addra    <= {4{fetch_y[5:1]}};
        else
            dram_cb_right_4col_addra    <= {4{fetch_y[5:1]}};

        if (fetch_j == 3) begin //fetch_j,色度取4行就够了
            prefetch_stage              <= 10;
            i_to_deblock                <= fetch_i;
            x_to_deblock                <= fetch_x;
            y_to_deblock                <= fetch_y-4;//回到中线
            wait_cycle                  <= 0;
        end else begin
            fetch_y                     <= fetch_y+2;
            fetch_j                     <= fetch_j+1;
        end
    end

    if (prefetch_stage == 10) begin
        wait_cycle                     <= wait_cycle+1;
        last_fetch_x                   <= fetch_x;
        last_fetch_y                   <= fetch_y-2;

        if (wait_cycle==3) begin //to debug,需等待的最大周期，取up
            fetch_i                     <= fetch_i+1;
            fetch_x                     <= fetch_x+8;
            fetch_y                     <= fetch_y-4;//回到中线
            kick_deblock                <= 1;
            prefetch_stage              <= 5;
        end
    end

end else if (en&&o_filter_state == `filter_store_up_right) begin
    //这里x，y用色度坐标
    if (stage == 0) begin
        y                               <= 29;
        y_pls1                          <= 30;
        dram_rec_addra                  <= {32{5'd29}};
        dram_cb_right_4col_addra        <= {4{5'd29}};
        dram_cr_right_4col_addra        <= {4{5'd29}};
        stage                           <= 1;
    end
    if (stage == 1) begin
        if (component)
            store_buf                   <= {dram_rec_doa,
                                            dram_cr_right_4col_doa[0],
                                            dram_cr_right_4col_doa[1],
                                            dram_cr_right_4col_doa[2],
                                            dram_cr_right_4col_doa[3]};
        else
            store_buf                   <= {dram_rec_doa,
                                            dram_cb_right_4col_doa[0],
                                            dram_cb_right_4col_doa[1],
                                            dram_cb_right_4col_doa[2],
                                            dram_cb_right_4col_doa[3]};
        store_up_i                      <= 0;
        store_up_addr                   <= x0[`max_x_bits-1:3]-1;
        stage                           <= 2;
    end
    if (stage == 2) begin
        if (component==1) begin
            bram_cr_up_3row_we          <= {3{1'b0}};
            bram_cr_up_3row_addra       <= {3{store_up_addr}};
            bram_cr_up_3row_dia         <= {3{store_buf[3:0]}};
        end else begin
            bram_cb_up_3row_we          <= {3{1'b0}};
            bram_cb_up_3row_addra       <= {3{store_up_addr}};
            bram_cb_up_3row_dia         <= {3{store_buf[3:0]}};
        end

        store_buf                       <= {32'd0,store_buf[35:4]};
        store_up_i                      <= store_up_i+1;
        store_up_addr                   <= store_up_addr+1;
        case (y)
        29: if (component==1)
                bram_cr_up_3row_we[2]   <= 1'b1;
            else
                bram_cb_up_3row_we[2]   <= 1'b1;
        30: if (component==1)
                bram_cr_up_3row_we[1]   <= 1'b1;
            else
                bram_cb_up_3row_we[1]   <= 1'b1;
        default:if (component==1)
                bram_cr_up_3row_we[0]   <= 1'b1;
            else
                bram_cb_up_3row_we[0]   <= 1'b1;
        endcase
        if (store_up_i == (last_col?8:7)) begin
            y                           <= y+1;
            y_pls1                      <= y_pls1+1;
            dram_rec_addra              <= {32{y_pls1}};
            dram_cb_right_4col_addra    <= {4{y_pls1}};
            dram_cr_right_4col_addra    <= {4{y_pls1}};
            stage                       <= 1;
            if (y==31) begin
                stage                   <= 3;
                //mark1
            end
        end
    end

    if (stage==3) begin
        //fix,从上面mark1处拿下来，y=31,x=28没存进去
        bram_cb_up_3row_we              <= {3{1'b0}};
        bram_cr_up_3row_we              <= {3{1'b0}};
    end

    if (stage==3&&store_right_y_d1==28) begin
        o_filter_state                  <= `filter_store_up_right_2;
        stage                           <= 0;
    end
end else if (en && o_filter_state == `filter_store_up_right_2) begin
    if (store_right_y_d1 == 31) begin
        o_filter_state               <= (first_row||last_col)?`filter_end:`filter_store_up_right_3;
    end
end else if (en&&o_filter_state == `filter_store_up_right_3) begin //update h4,h5
    if (stage == 0) begin
        dram_up_3row_addra              <= {3{4'd8}};
        stage                           <= 1;
    end
    if (stage == 1) begin
        if (component) begin
            bram_cr_up_3row_we[0]       <= 1;
            bram_cr_up_3row_addra[0]    <= store_up_addr;
            bram_cr_up_3row_dia[0]      <= {h7,h6,dram_up_3row_doa[0][15:0]};
        end else begin
            bram_cb_up_3row_we[0]       <= 1;
            bram_cb_up_3row_addra[0]    <= store_up_addr;
            bram_cb_up_3row_dia[0]      <= {h7,h6,dram_up_3row_doa[0][15:0]};
        end
        stage                           <= 2;
    end

    if (stage == 2) begin
        if (component) begin
            bram_cr_up_3row_we[0]       <= 0;
        end else begin
            bram_cb_up_3row_we[0]       <= 0;
        end

        o_filter_state                  <= `filter_end;
    end
end


reg           [7:0]      p0                ;
reg           [7:0]      p1                ;
reg           [7:0]      q0                ;
reg           [7:0]      q1                ;
wire signed   [8:0]      p0s               ;
wire signed   [8:0]      q0s               ;
wire signed   [8:0]      p1s               ;
wire signed   [8:0]      q1s               ;
reg           [7:0]      p0_d1             ;
wire signed   [8:0]      p0s_d2            ;
wire signed   [8:0]      q0s_d2            ;
reg           [7:0]      q0_d1             ;
reg           [7:0]      p0_d2             ;
reg           [7:0]      q0_d2             ;
reg           [7:0]      p0_result         ;
reg           [7:0]      q0_result         ;
wire signed   [9:0]      p0_filter         ;
wire signed   [9:0]      q0_filter         ;
assign p0s       = {1'b0,p0};
assign q0s       = {1'b0,q0};
assign p1s       = {1'b0,p1};
assign q1s       = {1'b0,q1};
assign p0s_d2    = {1'b0,p0_d2};
assign q0s_d2    = {1'b0,q0_d2};


reg                      valid             ;
reg                      valid_d1          ;
reg                      valid_d2          ;
reg                      valid_d3          ;
reg                      valid_d4          ;
reg           [5:0]      deblock_x         ;
reg           [5:0]      deblock_y         ;

reg           [4:0]      deblock_i         ;
reg           [1:0]      deblock_j         ;
reg           [2:0]      debug_j           ;
reg                      deblock_stage     ;
reg                      kick_store        ;
reg                      deblock_done      ;

reg           [4:0]      tc_deblk          ;
wire signed   [5:0]      tc_deblk_s        ;
assign tc_deblk_s = {1'b0,tc_deblk};

reg                      bypass_p_deblk    ;
reg                      bypass_q_deblk    ;

reg  signed   [9:0]      delta             ;
reg  signed   [5:0]      delta_clip_tc     ;

assign p0_filter = p0s_d2+delta_clip_tc;
assign q0_filter = q0s_d2-delta_clip_tc;


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

        bypass_p_deblk         <= bypass_p;
        bypass_q_deblk         <= bypass_q;

        valid                  <= 0;
        valid_d1               <= 0;
        valid_d2               <= 0;
        valid_d3               <= 0;
        valid_d4               <= 0;

        deblock_i              <= i_to_deblock;
        deblock_j              <= 0;
        debug_j                <= 0;
        deblock_x              <= x_to_deblock;
        deblock_y              <= y_to_deblock;
    end

    if (deblock_stage == 1) begin
        //pipeline stage 0
        {q1,q0,p0,p1}          <= pq_buf_bk;
        pq_buf_bk              <= {32'd0,pq_buf_bk[3:1]};
        valid                  <= 1;

        //pipeline stage 1
        valid_d1               <= valid;
        neg_tc                 <= ~tc_deblk+1;
        delta                  <= (((q0s-p0s)<<<2)+p1s-q1s+4)>>>3;
        p0_d1                  <= p0;
        q0_d1                  <= q0;

        //pipeline stage 2
        valid_d2               <= valid_d1;
        p0_d2                  <= p0_d1;
        q0_d2                  <= q0_d1;
        if (delta<neg_tc)
            delta_clip_tc      <= neg_tc;
        else if (delta>tc_deblk_s)
            delta_clip_tc      <= tc_deblk;
        else
            delta_clip_tc      <= delta;

        //pipeline stage 3
        if (valid_d2)
            debug_j            <= debug_j+1;
        valid_d3               <= valid_d2;
        p0_result              <= p0_d2;
        q0_result              <= q0_d2;
        if (~bypass_p_deblk) begin
            p0_result          <= p0_filter[9]?0:(p0_filter[8]?255:p0_filter[7:0]);
            if (`log_f && i_slice_num>=`slice_begin && i_slice_num<=`slice_end && valid_d2&&
                debug_j<(o_filter_state == `deblocking_hor&&deblock_i==8&&~last_col?2:4)&&
                ~(o_filter_state == `deblocking_hor&&deblock_i==0&&debug_j<2)) begin
                $fdisplay(fd_deblock, "%s %s x %0d y %0d p0 %0d to %0d",
                          component?"Cr":"Cb",
                          o_filter_state == `deblocking_ver ? "ver" : "hor",
                          o_filter_state == `deblocking_ver ?(x0>>1)+(deblock_x>>1):
                                            (deblock_i==0?(x0>>1)+(deblock_x>>1)+debug_j-32:
                                                          (x0>>1)+(deblock_x>>1)+debug_j),
                          o_filter_state == `deblocking_ver ?(y0>>1)+(deblock_y>>1)+debug_j:(y0>>1)+(deblock_y>>1),
                          p0_d2,p0_filter[9]?0:(p0_filter[8]?255:p0_filter[7:0]));
            end
        end

        if (~bypass_q_deblk) begin
            q0_result        <= q0_filter[9]?0:(q0_filter[8]?255:q0_filter[7:0]);
            if (`log_f && i_slice_num>=`slice_begin && i_slice_num<=`slice_end && valid_d2&&
                debug_j<(o_filter_state == `deblocking_hor&&deblock_i==8&&~last_col?2:4)&&
                ~(o_filter_state == `deblocking_hor&&deblock_i==0&&debug_j<2)) begin
                $fdisplay(fd_deblock, "%s %s x %0d y %0d q0 %0d to %0d",
                          component?"Cr":"Cb",
                          o_filter_state == `deblocking_ver ? "ver" : "hor",
                          o_filter_state == `deblocking_ver ?(x0>>1)+(deblock_x>>1):
                                             (deblock_i==0?(x0>>1)+(deblock_x>>1)+debug_j-32:
                                                          (x0>>1)+(deblock_x>>1)+debug_j),
                          o_filter_state == `deblocking_ver ?(y0>>1)+(deblock_y>>1)+debug_j:(y0>>1)+(deblock_y>>1),
                          q0_d2,q0_filter[9]?0:(q0_filter[8]?255:q0_filter[7:0]));
            end
        end


        //pipeline stage 4
        valid_d4               <= valid_d3;
        deblock_buf            <= {q0_result,p0_result,deblock_buf[3:1]};
        if (valid_d3) begin
            deblock_j          <= deblock_j+1;
            if (deblock_j == 3) begin
                kick_store     <= 1;
                x_to_store     <= deblock_x[5:1];
                y_to_store     <= deblock_y[5:1];
                i_to_store     <= deblock_i;
                deblock_stage  <= 0;
            end
        end
    end

end

reg      [ 3:0]            fetch_up_i        ;//0~8
reg                        store_done        ;
reg      [ 4:0]            store_i           ;
reg      [ 3:0]            store_j           ;
reg      [ 1:0]            store_stage       ;
reg      [ 1:0]            fetch_up_stage    ;
reg      [`max_x_bits-4:0] fetch_addr        ;
reg      [ 5:0]            store_right_y     ;
reg                        do_store_right    ;
wire     [ 4:0]            store_right_y_end ;
assign store_right_y_end = o_filter_state==`filter_store_up_right?28:31;

always @ (posedge clk)
if (rst||i_rst_slice) begin
    store_x                       <= 0;
    store_y                       <= 0;
    store_stage                   <= 0;
    fetch_up_stage                <= 0;
    hor_deblock_done_y            <= 0;
    fetch_up_3row_done            <= 0;
    fetch_up_i                    <= 0;
    do_store_right                <= 0;
    store_right_y                 <= 0;
    store_right_y_d1              <= 0;
    fetch_addr                    <= x0[`max_x_bits-1:3]-1;
    dram_rec_we                   <= 32'd0;
    dram_up_3row_we               <= 3'b000;
    dram_cb_right_4col_we         <= 4'd0;
    dram_cr_right_4col_we         <= 4'd0;
end else if (en&&o_filter_state == `filter_fetch_up) begin
    if (fetch_up_stage == 0) begin
        bram_cb_up_3row_addrb     <= {3{fetch_addr}};
        bram_cr_up_3row_addrb     <= {3{fetch_addr}};
        fetch_addr                <= fetch_addr+1;
        fetch_up_stage            <= 1;
    end

    if (fetch_up_stage == 1) begin
        bram_cb_up_3row_addrb     <= {3{fetch_addr}};
        bram_cr_up_3row_addrb     <= {3{fetch_addr}};
        fetch_addr                <= fetch_addr+1;
        //delay 1 cycle
        fetch_up_stage            <= 2;
    end

    if (fetch_up_stage == 2) begin
        bram_cb_up_3row_addrb     <= {3{fetch_addr}};
        bram_cr_up_3row_addrb     <= {3{fetch_addr}};
        fetch_addr                <= fetch_addr+1;

        fetch_up_i                <= fetch_up_i+1;
        dram_up_3row_addrd        <= {3{fetch_up_i}};
        dram_up_3row_did          <= component==0?bram_cb_up_3row_dob:bram_cr_up_3row_dob;
        dram_up_3row_we           <= 3'b111;
        if (fetch_up_i==0) begin
            //这个h4,h5和下面h6,h7不一样，这里h4,h5是左上的
            h4                    <= component==0?bram_cb_up_3row_dob[0][7:0]:bram_cr_up_3row_dob[0][7:0];
            h5                    <= component==0?bram_cb_up_3row_dob[0][15:8]:bram_cr_up_3row_dob[0][15:8];
        end
        if (fetch_up_i==8) begin
            h6                    <= component==0?bram_cb_up_3row_dob[0][23:16]:bram_cr_up_3row_dob[0][23:16];
            h7                    <= component==0?bram_cb_up_3row_dob[0][31:24]:bram_cr_up_3row_dob[0][31:24];
        end
        if (fetch_up_i == 9) begin
            fetch_up_i            <= 0;
            fetch_up_3row_done    <= 1;
            dram_up_3row_we       <= 3'b000;
            fetch_up_stage        <= 3;
        end
    end
end else if (en&&(o_filter_state==`filter_store_up_right||
             o_filter_state==`filter_store_up_right_2)) begin
    do_store_right                <= 1;
    dram_rec_we                   <= 32'd0;
    dram_rec_addrd                <= {32{store_right_y[4:0]}};
    if (component) begin
        dram_cr_right_4col_we     <= do_store_right?4'b1111:4'd0;
        dram_cr_right_4col_addrd  <= {6{store_right_y_d1}};;
        dram_cr_right_4col_did    <= {dram_rec_dod[28],dram_rec_dod[29],
                                      dram_rec_dod[30],dram_rec_dod[31]};
    end else begin
        dram_cb_right_4col_we     <= do_store_right?4'b1111:4'd0;
        dram_cb_right_4col_addrd  <= {6{store_right_y_d1}};;
        dram_cb_right_4col_did    <= {dram_rec_dod[28],dram_rec_dod[29],
                                      dram_rec_dod[30],dram_rec_dod[31]};
    end
    if (store_right_y!=store_right_y_end+1)
        store_right_y             <= store_right_y+1;
    if (store_right_y!=0&&store_right_y_d1!=store_right_y_end)
        store_right_y_d1          <= store_right_y_d1+1;
    if (store_right_y_d1 == store_right_y_end) begin
        do_store_right            <= 0;
    end

end else if (en &&o_filter_state == `deblocking_ver) begin

    if (store_stage == 0 && kick_store) begin
        deblock_buf_bk            <= deblock_buf;
        store_x                   <= x_to_store; //store_x,store_y使用色度坐标
        store_y                   <= y_to_store;
        store_j                   <= 0;
        store_stage               <= 1;
    end

    if (store_stage == 1) begin
        deblock_buf_bk                          <= {16'd0,deblock_buf_bk[3:1]};
        case (store_x[4:3])
            0: begin
                if (component) begin
                    dram_cr_right_4col_did[0]   <= deblock_buf_bk[0][0];
                    dram_cr_right_4col_we[0]    <= 1'b1;
                    dram_cr_right_4col_addrd[0] <= store_y;
                end else begin
                    dram_cb_right_4col_did[0]   <= deblock_buf_bk[0][0];
                    dram_cb_right_4col_we[0]    <= 1'b1;
                    dram_cb_right_4col_addrd[0] <= store_y;
                end

                dram_rec_did[0]                 <= deblock_buf_bk[0][1];
                dram_rec_we[0]                  <= 1'b1;
                dram_rec_addrd[0]               <= store_y;

            end
            1: begin
                dram_rec_did[8:7]               <= deblock_buf_bk[0];
                dram_rec_we[8:7]                <= {2{1'b1}};
                dram_rec_addrd[8:7]             <= {2{store_y}};
            end
            2: begin
                dram_rec_did[16:15]             <= deblock_buf_bk[0];
                dram_rec_we[16:15]              <= {2{1'b1}};
                dram_rec_addrd[16:15]           <= {2{store_y}};
            end
            3: begin
                dram_rec_did[24:23]             <= deblock_buf_bk[0];
                dram_rec_we[24:23]              <= {2{1'b1}};
                dram_rec_addrd[24:23]           <= {2{store_y}};
            end

        endcase

        if (store_j == 3) begin
            store_stage                         <= 0;
        end else begin
            store_y                             <= store_y+1;
            store_j                             <= store_j+1;
        end

    end

end else if (en && o_filter_state == `deblocking_hor) begin
    if (hor_deblock_done) begin //全部结束，再更新一次
        hor_deblock_done_y        <= last_row?i_last_row_height[6:1]:30;
    end
    if (store_stage == 0 && kick_store) begin
        deblock_buf_bk            <= deblock_buf;
        store_x                   <= x_to_store;
        store_i                   <= i_to_store;
        store_j                   <= 0;
        hor_deblock_done_y        <= y_to_store-3;
        if (y_to_store == 0) begin
            store_stage           <= 1;
            store_y               <= 0;
        end else begin
            store_y               <= y_to_store-1;
            store_stage           <= 2;
        end
    end

    //reg  [ 3:0][ 1:0][ 7:0] deblock_buf_bk      ;
    //deblock_buf[0] [1] [2] [3]
    //           p00 p01 p02 p03
    //           q00 q01 q02 q03

    if (store_stage == 1) begin
        //从fetch_i传过来，0表示左边ctb
        dram_up_3row_addrd[0]     <= store_i;
        dram_up_3row_we[0]        <= 1'b1;
        if (store_i==0)
            dram_up_3row_did[0]   <= {deblock_buf_bk[3][0],
                                      deblock_buf_bk[2][0],
                                      h5,
                                      h4}; //fix,水平滤波只滤了两点不是4点
        else
            dram_up_3row_did[0]   <= {deblock_buf_bk[3][0],
                                      deblock_buf_bk[2][0],
                                      deblock_buf_bk[1][0],
                                      deblock_buf_bk[0][0]}; //fix,水平滤波只滤了两点不是4点

        deblock_buf_bk[0]         <= {8'd0,deblock_buf_bk[0][1]};
        deblock_buf_bk[1]         <= {8'd0,deblock_buf_bk[1][1]};
        deblock_buf_bk[2]         <= {8'd0,deblock_buf_bk[2][1]};
        deblock_buf_bk[3]         <= {8'd0,deblock_buf_bk[3][1]};

        store_j                   <= 1;
        store_stage               <= 2;
    end

    if (store_stage == 2) begin
        deblock_buf_bk[0]         <= {8'd0,deblock_buf_bk[0][1]};
        deblock_buf_bk[1]         <= {8'd0,deblock_buf_bk[1][1]};
        deblock_buf_bk[2]         <= {8'd0,deblock_buf_bk[2][1]};
        deblock_buf_bk[3]         <= {8'd0,deblock_buf_bk[3][1]};

        case (store_i)
            0: begin
                if (component) begin
                    dram_cr_right_4col_we[1:0]     <= 2'b11;
                    dram_cr_right_4col_addrd[1:0]  <= {2{store_y}};
                    dram_cr_right_4col_did[1:0]    <= {deblock_buf_bk[2][0],
                                                       deblock_buf_bk[3][0]};
                end else begin
                    dram_cb_right_4col_we[1:0]     <= 2'b11;
                    dram_cb_right_4col_addrd[1:0]  <= {2{store_y}};
                    dram_cb_right_4col_did[1:0]    <= {deblock_buf_bk[2][0],
                                                       deblock_buf_bk[3][0]};
                end
            end
            1: begin
                dram_rec_did[3:0]                <= {deblock_buf_bk[3][0],
                                                     deblock_buf_bk[2][0],
                                                     deblock_buf_bk[1][0],
                                                     deblock_buf_bk[0][0]};
                dram_rec_we[3:0]                 <= {4{1'b1}};
                dram_rec_addrd[3:0]              <= {4{store_y}};
            end
            2: begin
                dram_rec_did[7:4]                <= {deblock_buf_bk[3][0],
                                                     deblock_buf_bk[2][0],
                                                     deblock_buf_bk[1][0],
                                                     deblock_buf_bk[0][0]};
                dram_rec_we[7:4]                 <= {4{1'b1}};
                dram_rec_addrd[7:4]              <= {4{store_y}};
            end
            3: begin
                dram_rec_did[11:8]               <= {deblock_buf_bk[3][0],
                                                     deblock_buf_bk[2][0],
                                                     deblock_buf_bk[1][0],
                                                     deblock_buf_bk[0][0]};
                dram_rec_we[11:8]                <= {4{1'b1}};
                dram_rec_addrd[11:8]             <= {4{store_y}};
            end
            4: begin
                dram_rec_did[15:12]              <= {deblock_buf_bk[3][0],
                                                     deblock_buf_bk[2][0],
                                                     deblock_buf_bk[1][0],
                                                     deblock_buf_bk[0][0]};
                dram_rec_we[15:12]               <= {4{1'b1}};
                dram_rec_addrd[15:12]            <= {4{store_y}};
            end
            5: begin
                dram_rec_did[19:16]              <= {deblock_buf_bk[3][0],
                                                     deblock_buf_bk[2][0],
                                                     deblock_buf_bk[1][0],
                                                     deblock_buf_bk[0][0]};
                dram_rec_we[19:16]               <= {4{1'b1}};
                dram_rec_addrd[19:16]            <= {4{store_y}};
            end
            6: begin
                dram_rec_did[23:20]              <= {deblock_buf_bk[3][0],
                                                     deblock_buf_bk[2][0],
                                                     deblock_buf_bk[1][0],
                                                     deblock_buf_bk[0][0]};
                dram_rec_we[23:20]               <= {4{1'b1}};
                dram_rec_addrd[23:20]            <= {4{store_y}};
            end
            7: begin
                dram_rec_did[27:24]              <= {deblock_buf_bk[3][0],
                                                     deblock_buf_bk[2][0],
                                                     deblock_buf_bk[1][0],
                                                     deblock_buf_bk[0][0]};
                dram_rec_we[27:24]               <= {4{1'b1}};
                dram_rec_addrd[27:24]            <= {4{store_y}};
            end
            8: begin
                dram_rec_did[31:28]              <= {deblock_buf_bk[3][0],
                                                     deblock_buf_bk[2][0],
                                                     deblock_buf_bk[1][0],
                                                     deblock_buf_bk[0][0]};
                dram_rec_we[31:28]               <= last_col?4'b1111:4'b0011;
                dram_rec_addrd[31:28]            <= {4{store_y}};
            end
        endcase
        store_j                 <= store_j+1;
        store_y                 <= store_y+1;
        if (store_j == 1) begin//仅2行就可以
            store_stage         <= 0;
        end
    end

end else begin

end



reg     [ 3:0][ 4:0]     band;
reg     [ 3:0][ 4:0]     band_up;
reg     [ 3:0][ 4:0]     band_left;
reg     [ 3:0][ 4:0]     band_leftup;

reg           [ 5:0]     sao_left_class_plus_k;
reg           [ 5:0]     sao_left_class_plus_k_up;
reg           [ 5:0]     sao_left_class_plus_k_left;
reg           [ 5:0]     sao_left_class_plus_k_leftup;
reg           [ 2:0]     n;
always @ (posedge clk)
if (rst) begin
    n                             <= 0;
    sao_left_class_plus_k         <= i_component?sao_param.sao_band_position[2]:
                                               sao_param.sao_band_position[1];
    sao_left_class_plus_k_up      <= i_component?sao_param_up.sao_band_position[2]:
                                               sao_param_up.sao_band_position[1];
    sao_left_class_plus_k_left    <= i_component?sao_param_left.sao_band_position[2]:
                                               sao_param_left.sao_band_position[1];
    sao_left_class_plus_k_leftup  <= i_component?sao_param_leftup.sao_band_position[2]:
                                               sao_param_leftup.sao_band_position[1];
end else begin
    if (n < 4) begin
        band[n]                   <= sao_left_class_plus_k[4:0];
        band_up[n]                <= sao_left_class_plus_k_up[4:0];
        band_left[n]              <= sao_left_class_plus_k_left[4:0];
        band_leftup[n]            <= sao_left_class_plus_k_leftup[4:0];

        sao_left_class_plus_k         <= sao_left_class_plus_k+1;
        sao_left_class_plus_k_up      <= sao_left_class_plus_k_up+1;
        sao_left_class_plus_k_left    <= sao_left_class_plus_k_left+1;
        sao_left_class_plus_k_leftup  <= sao_left_class_plus_k_leftup+1;
        n <= n+1;
    end

end


reg                  [ 5:0]       sao_y                     ;
wire                 [ 4:0]       sao_y_pls1                ;
wire                 [ 4:0]       sao_y_pls2                ;
assign sao_y_pls1 = sao_y+1;
assign sao_y_pls2 = sao_y+2;

reg                  [ 1:0]       sao_type_left             ;
reg                  [ 1:0]       sao_type_right            ;
reg                  [ 1:0]       sao_eo_class_left         ;
reg                  [ 1:0]       sao_eo_class_right        ;

reg            [34:0][ 2:0]       edge_idx                  ;
reg            [34:0][ 2:0]       edge_idx_w                ;

reg            [35:0][ 7:0]       sao_buf_up                ;
reg            [35:0][ 7:0]       sao_buf                   ;
wire signed          [ 9:0]       sao_buf_s[35:0]           ;
reg            [35:0][ 7:0]       sao_buf_down              ;
reg            [39:0][ 7:0]       sao_result                ; //8的倍数

reg  signed          [ 3:0]       sao_offset_band[34:0]     ;
reg  signed          [ 3:0]       sao_offset_edge[34:0]     ;
reg                  [ 8:0]       sao_nf_a_row              ;

wire signed          [ 3:0]       sao_offset_band_w[34:0]   ;
wire signed          [ 3:0]       sao_offset_edge_w[34:0]   ;


reg  signed          [ 1:0]       sign0[34:0]               ;
wire signed          [ 1:0]       sign0_w[34:0]             ;
reg  signed          [ 1:0]       sign1[34:0]               ;
wire signed          [ 1:0]       sign1_w[34:0]             ;
wire signed          [ 3:0]       sign_temp[34:0]         ;
wire           [34:0][ 7:0]       sao_result_band_w         ;
wire           [34:0][ 7:0]       sao_result_edge_w         ;
wire signed    [34:0][ 9:0]       sao_result_band_s         ;
wire signed    [34:0][ 9:0]       sao_result_edge_s         ;
reg            [34:0][ 7:0]       sao_result_band           ;
reg            [34:0][ 7:0]       sao_result_edge           ;
reg            [34:0][ 7:0]       sao_result_select_w       ;

reg                               sao_up_ctb_done           ;
reg                               sao_valid                 ;
reg                               cond_last_sao_y           ;
reg                               cond_sao_y_eq31           ;

always @ (posedge clk)
begin
    if (sao_y < hor_deblock_done_y)
        sao_valid   <= 1;
    else
        sao_valid   <= 0;
end

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
    for (I=0;I<3;I++)
    begin: band_idx_label_0_to_2

        assign sao_offset_band_w[I] = sao_up_ctb_done?(component?(sao_buf[I+1][7:3]==band_left[0]?sao_param_left.sao_offset[2][1]:
                                                                 (sao_buf[I+1][7:3]==band_left[1]?sao_param_left.sao_offset[2][2]:
                                                                 (sao_buf[I+1][7:3]==band_left[2]?sao_param_left.sao_offset[2][3]:
                                                                 (sao_buf[I+1][7:3]==band_left[3]?sao_param_left.sao_offset[2][4]:0)))):
                                                                 (sao_buf[I+1][7:3]==band_left[0]?sao_param_left.sao_offset[1][1]:
                                                                 (sao_buf[I+1][7:3]==band_left[1]?sao_param_left.sao_offset[1][2]:
                                                                 (sao_buf[I+1][7:3]==band_left[2]?sao_param_left.sao_offset[1][3]:
                                                                 (sao_buf[I+1][7:3]==band_left[3]?sao_param_left.sao_offset[1][4]:0))))):
                                                      (component?(sao_buf[I+1][7:3]==band_leftup[0]?sao_param_leftup.sao_offset[2][1]:
                                                                 (sao_buf[I+1][7:3]==band_leftup[1]?sao_param_leftup.sao_offset[2][2]:
                                                                 (sao_buf[I+1][7:3]==band_leftup[2]?sao_param_leftup.sao_offset[2][3]:
                                                                 (sao_buf[I+1][7:3]==band_leftup[3]?sao_param_leftup.sao_offset[2][4]:0)))):
                                                                 (sao_buf[I+1][7:3]==band_leftup[0]?sao_param_leftup.sao_offset[1][1]:
                                                                 (sao_buf[I+1][7:3]==band_leftup[1]?sao_param_leftup.sao_offset[1][2]:
                                                                 (sao_buf[I+1][7:3]==band_leftup[2]?sao_param_leftup.sao_offset[1][3]:
                                                                 (sao_buf[I+1][7:3]==band_leftup[3]?sao_param_leftup.sao_offset[1][4]:0)))));
        assign sao_offset_edge_w[I] = sao_up_ctb_done?(component?sao_param_left.sao_offset[2][edge_idx[I]]:
                                                                 sao_param_left.sao_offset[1][edge_idx[I]]):
                                                      (component?sao_param_leftup.sao_offset[2][edge_idx[I]]:
                                                                 sao_param_leftup.sao_offset[1][edge_idx[I]]);
    end
endgenerate

generate
    for (I=3;I<35;I++)
    begin: band_idx_label_3_to_34

        assign sao_offset_band_w[I] = sao_up_ctb_done?(component?(sao_buf[I+1][7:3]==band[0]?sao_param.sao_offset[2][1]:
                                                                 (sao_buf[I+1][7:3]==band[1]?sao_param.sao_offset[2][2]:
                                                                 (sao_buf[I+1][7:3]==band[2]?sao_param.sao_offset[2][3]:
                                                                 (sao_buf[I+1][7:3]==band[3]?sao_param.sao_offset[2][4]:0)))):
                                                                 (sao_buf[I+1][7:3]==band[0]?sao_param.sao_offset[1][1]:
                                                                 (sao_buf[I+1][7:3]==band[1]?sao_param.sao_offset[1][2]:
                                                                 (sao_buf[I+1][7:3]==band[2]?sao_param.sao_offset[1][3]:
                                                                 (sao_buf[I+1][7:3]==band[3]?sao_param.sao_offset[1][4]:0))))):
                                                      (component?(sao_buf[I+1][7:3]==band_up[0]?sao_param_up.sao_offset[2][1]:
                                                                 (sao_buf[I+1][7:3]==band_up[1]?sao_param_up.sao_offset[2][2]:
                                                                 (sao_buf[I+1][7:3]==band_up[2]?sao_param_up.sao_offset[2][3]:
                                                                 (sao_buf[I+1][7:3]==band_up[3]?sao_param_up.sao_offset[2][4]:0)))):
                                                                 (sao_buf[I+1][7:3]==band_up[0]?sao_param_up.sao_offset[1][1]:
                                                                 (sao_buf[I+1][7:3]==band_up[1]?sao_param_up.sao_offset[1][2]:
                                                                 (sao_buf[I+1][7:3]==band_up[2]?sao_param_up.sao_offset[1][3]:
                                                                 (sao_buf[I+1][7:3]==band_up[3]?sao_param_up.sao_offset[1][4]:0)))));
        assign sao_offset_edge_w[I] = sao_up_ctb_done?(component?sao_param.sao_offset[2][edge_idx[I]]:
                                                                 sao_param.sao_offset[1][edge_idx[I]]):
                                                      (component?sao_param_up.sao_offset[2][edge_idx[I]]:
                                                                 sao_param_up.sao_offset[1][edge_idx[I]]);
    end
endgenerate

//sao_eo_class   0        1       2            3
//                        n0   n0               n0
//            n0 p n1     p       p           p
//                        n1        n1      n1



generate
    for (I=0;I<3;I++)
    begin: sign_label_0_to_2
         assign sign0_w[I] = sao_eo_class_left==0?f_get_sign(sao_buf[I+1],sao_buf[I]):
                             (sao_eo_class_left==1?f_get_sign(sao_buf[I+1],sao_buf_up[I+1]):
                             (sao_eo_class_left==2?f_get_sign(sao_buf[I+1],sao_buf_up[I]):
                              f_get_sign(sao_buf[I+1],sao_buf_up[I+2])));


        assign sign1_w[I] = sao_eo_class_left==0?f_get_sign(sao_buf[I+1],sao_buf[I+2]):
                             (sao_eo_class_left==1?f_get_sign(sao_buf[I+1],sao_buf_down[I+1]):
                             (sao_eo_class_left==2?f_get_sign(sao_buf[I+1],sao_buf_down[I+2]):
                              f_get_sign(sao_buf[I+1],sao_buf_down[I])));
    end
endgenerate

generate
    for (I=3;I<34;I++)
    begin: sign_label_3_to_33
        assign sign0_w[I] = sao_eo_class_right==0?f_get_sign(sao_buf[I+1],sao_buf[I]):
                             (sao_eo_class_right==1?f_get_sign(sao_buf[I+1],sao_buf_up[I+1]):
                             (sao_eo_class_right==2?f_get_sign(sao_buf[I+1],sao_buf_up[I]):
                              f_get_sign(sao_buf[I+1],sao_buf_up[I+2])));

        assign sign1_w[I] = sao_eo_class_right==0?f_get_sign(sao_buf[I+1],sao_buf[I+2]):
                             (sao_eo_class_right==1?f_get_sign(sao_buf[I+1],sao_buf_down[I+1]):
                             (sao_eo_class_right==2?f_get_sign(sao_buf[I+1],sao_buf_down[I+2]):
                              f_get_sign(sao_buf[I+1],sao_buf_down[I])));


    end
endgenerate

        assign sign0_w[34] = sao_eo_class_right==0?f_get_sign(sao_buf[35],sao_buf[34]):
                             (sao_eo_class_right==1?f_get_sign(sao_buf[35],sao_buf_up[35]):
                             (sao_eo_class_right==2?f_get_sign(sao_buf[35],sao_buf_up[34]):
                              f_get_sign(sao_buf[35],sao_buf_up[35])));

        assign sign1_w[34] = sao_eo_class_right==0?f_get_sign(sao_buf[35],sao_buf[35]):
                             (sao_eo_class_right==1?f_get_sign(sao_buf[35],sao_buf_down[35]):
                             (sao_eo_class_right==2?f_get_sign(sao_buf[35],sao_buf_down[35]):
                              f_get_sign(sao_buf[35],sao_buf_down[34])));


generate
    for (I=0;I<35;I++)
    begin: sign_temp_label
        assign sign_temp[I] = sign0[I]+sign1[I]+2;
    end
endgenerate

generate
    for (I=0;I<35;I++)
    begin: edge_idx_label
        assign edge_idx_w[I] = sign_temp[I]==0?1:
                              (sign_temp[I]==1?2:
                              (sign_temp[I]==2?0:
                              (sign_temp[I]==3?3:
                              (sign_temp[I]==4?4:0))));

    end
endgenerate


generate
    for (I=0;I<36;I++)
    begin: sao_buf_s_label
        assign sao_buf_s[I] = {2'b00,sao_buf[I]};
    end
endgenerate

generate
    for (I=0;I<35;I++)
    begin: sao_result_band_s_label
        assign sao_result_band_s[I] = sao_buf_s[I+1]+sao_offset_band[I];
    end
endgenerate

generate
    for (I=0;I<35;I++)
    begin: sao_result_edge_s_label
        assign sao_result_edge_s[I] = sao_buf_s[I+1]+sao_offset_edge[I];
    end
endgenerate


generate
    for (I=0;I<35;I++)
    begin: sao_result_band_label
        assign sao_result_band_w[I] = sao_result_band_s[I][9]?0:(sao_result_band_s[I][8]?255:sao_result_band_s[I][7:0]);
    end
endgenerate

generate
    for (I=0;I<35;I++)
    begin: sao_result_edge_label
        assign sao_result_edge_w[I] = sao_result_edge_s[I][9]?0:(sao_result_edge_s[I][8]?255:sao_result_edge_s[I][7:0]);
    end
endgenerate

generate
    for (I=0;I<3;I++)
    begin: sao_result_select_0_to_2_label
        always @(*)
        begin
            if (sao_type_left==sao_none) begin
                sao_result_select_w[I] = sao_buf[I+1];
            end else if (sao_nf_a_row[0]) begin
                sao_result_select_w[I] = sao_buf[I+1];
            end else if (sao_type_left==sao_band) begin
                sao_result_select_w[I] = sao_result_band[I];
            end else if (first_row && sao_y == 0 &&
                     sao_eo_class_left != 0&& sao_up_ctb_done) begin
                sao_result_select_w[I] = sao_buf[I+1];
            end else if (last_row && sao_y==last_row_height_minus1 &&
                     sao_eo_class_left != 0&& sao_up_ctb_done) begin
                sao_result_select_w[I] = sao_buf[I+1];
            end else if (sao_type_left) begin
                sao_result_select_w[I] = sao_result_edge[I];
            end else begin
                sao_result_select_w[I] = 0;
            end

        end
    end
endgenerate

generate
    for (I=3;I<35;I++)
    begin: sao_result_select_3_to_34_label
        always @(*)
        begin
            if (sao_type_right==sao_none) begin
                sao_result_select_w[I] = sao_buf[I+1];
            end else if (sao_nf_a_row[(I-3)/8+1]) begin
                sao_result_select_w[I] = sao_buf[I+1];
            end else if (sao_type_right==sao_band) begin
                sao_result_select_w[I] = sao_result_band[I];
            end else if (first_col && I==3 && sao_eo_class_right != 1) begin
                sao_result_select_w[I] = sao_buf[I+1];
            end else if (first_row && sao_y == 0 &&
                     sao_eo_class_right != 0&& sao_up_ctb_done) begin
                sao_result_select_w[I] = sao_buf[I+1];
            end else if (last_col && (I-3)==last_col_width_minus1 &&
                     sao_eo_class_right != 1) begin
                sao_result_select_w[I] = sao_buf[I+1];
            end else if (last_row && sao_y==last_row_height_minus1 &&
                     sao_eo_class_right != 0&& sao_up_ctb_done) begin
                sao_result_select_w[I] = sao_buf[I+1];
            end else if (sao_type_right) begin
                sao_result_select_w[I] = sao_result_edge[I];
            end else begin
                sao_result_select_w[I] = 0;
            end
        end
    end
endgenerate



generate
    for (I=0;I<3;I++)
    begin: sao_result_select_0_to_2_log_label
        always @(posedge clk)
        if (phase==10) begin
            if (sao_type_left==sao_none) begin

            end else if (sao_nf_a_row[0]) begin

            end else if (sao_type_left==sao_band) begin
                if (`log_f && i_slice_num>=`slice_begin &&
                     i_slice_num<=`slice_end&&~first_col)
                    $fdisplay(fd_filter, "%s x %0d y %0d band %0d+%0d=%0d",
                          component?"Cr":"Cb",
                          (x0>>1)-3+I, sao_up_ctb_done?(y0>>1)+sao_y:(y0>>1)+sao_y-32,
                          sao_buf[I+1],sao_offset_band[I],sao_result_band[I]);
            end else if (first_row && sao_y == 0 &&
                         sao_eo_class_left != 0&& sao_up_ctb_done) begin

            end else if (last_row && sao_y==last_row_height_minus1 &&
                         sao_eo_class_left != 0&& sao_up_ctb_done) begin

            end else if (sao_type_left) begin
                if (`log_f && i_slice_num>=`slice_begin && 
                     i_slice_num<=`slice_end&&~first_col)
                    $fdisplay(fd_filter, "%s x %0d y %0d edge %0d+%0d=%0d edgeIdx %0d",
                          component?"Cr":"Cb",
                          (x0>>1)-3+I, sao_up_ctb_done?(y0>>1)+sao_y:(y0>>1)+sao_y-32,
                          sao_buf[I+1],sao_offset_edge[I],sao_result_edge[I],
                          edge_idx[I]);
            end
        end
    end
endgenerate

generate
    for (I=3;I<35;I++)
    begin: sao_result_select_3_to_34_log_label
        always @(posedge clk)
        if (phase==10) begin
            if (sao_type_right==sao_none) begin

            end else if (sao_nf_a_row[(I-3)/8+1]) begin

            end else if (sao_type_right==sao_band) begin
                if (`log_f && i_slice_num>=`slice_begin && i_slice_num<=`slice_end&&
                    ((~last_col&&I<32)||(last_col&&I-3<i_last_col_width[6:1])))
                    $fdisplay(fd_filter, "%s x %0d y %0d band %0d+%0d=%0d",
                          component?"Cr":"Cb",
                          (x0>>1)+I-3, sao_up_ctb_done?(y0>>1)+sao_y:(y0>>1)+sao_y-32,
                          sao_buf[I+1],sao_offset_band[I],sao_result_band[I]);
            end else if (first_col && I==3 && sao_eo_class_right != 1) begin

            end else if (first_row && sao_y == 0 &&
                         sao_eo_class_right != 0&& sao_up_ctb_done) begin

            end else if (last_col && (I-3)==last_col_width_minus1 &&
                         sao_eo_class_right != 1) begin

            end else if (last_row && sao_y==last_row_height_minus1 &&
                         sao_eo_class_right != 0&& sao_up_ctb_done) begin

            end else if (sao_type_right) begin
                if (`log_f && i_slice_num>=`slice_begin && i_slice_num<=`slice_end&&
                    ((~last_col&&I<32)||(last_col&&I-3<i_last_col_width[6:1])))
                    $fdisplay(fd_filter, "%s x %0d y %0d edge %0d+%0d=%0d edgeIdx %0d",
                          component?"Cr":"Cb",
                          (x0>>1)+I-3, sao_up_ctb_done?(y0>>1)+sao_y:(y0>>1)+sao_y-32,
                          sao_buf[I+1],sao_offset_edge[I],sao_result_edge[I],
                          edge_idx[I]);
            end 
        end
    end
endgenerate




reg             [31:0]         pic_base_ddr  ;
reg             [23:0]         pic_addr_off  ;
wire            [ 3:0]         pic_addr_mid  ;
wire [`max_y_bits-2:0]         y0_up_row     ;
wire [`max_x_bits-2:0]         x_off         ;
assign y0_up_row = y0[`max_y_bits-1:1]-32;
assign pic_addr_mid = pic_base_ddr[23:20]+pic_addr_off[23:20];
assign x_off = first_col?0:x0[`max_x_bits-1:1]-8;

always @ (posedge clk)
if (global_rst||i_rst_slice) begin
    phase                     <= 19;
    m_axi_wvalid              <= 0;
    m_axi_awvalid             <= 0;
end else if (rst) begin
    sao_y                     <= first_row?0:30;
    sao_up_ctb_done           <= first_row?1:0;
    sao_done                  <= 0;
    m_axi_awvalid             <= 0;
    m_axi_wvalid              <= 0;
    m_axi_wlast               <= 0;

    pic_base_ddr              <= i_pic_base_ddr;

    phase                     <= 0;
    i                         <= 0;

    //hor_deblock_done_y来自store_y，都是色度坐标，sao_x,sao_y也为色度坐标
end else if (en) begin

    if (phase == 0 && hor_deblock_done_y > 0 &&
        hor_deblock_done_y!=61&& //0-3=61
       (~sao_up_ctb_done ||
       sao_valid )) begin  //y_d1=0,8,16,...56,hor_deblock_done_y=4,8,12,...60
        if (sao_up_ctb_done) begin
            if (component)
                dram_cr_right_4col_addrb <= {4{sao_y[4:0]}};
            else
                dram_cb_right_4col_addrb <= {4{sao_y[4:0]}};
            dram_rec_addrb               <= {32{sao_y[4:0]}};
            sao_nf_a_row                 <= {i_nf[sao_y[4:2]], nf_right_col[sao_y[4:2]]};
            sao_type_left                <= component?sao_param_left.sao_type_idx[2]:
                                                      sao_param_left.sao_type_idx[1];
            sao_type_right               <= component?sao_param.sao_type_idx[2]:
                                                      sao_param.sao_type_idx[1];
            sao_eo_class_left            <= component?sao_param_left.sao_eo_class[2]:
                                                      sao_param_left.sao_eo_class[1];
            sao_eo_class_right           <= component?sao_param.sao_eo_class[2]:
                                                      sao_param.sao_eo_class[1];
            phase                        <= 1;
        end else begin
            dram_up_3row_addrb           <= {3{i}};
            if (component)
                dram_cr_right_4col_addrb <= {4{5'd0}}; //求up ctb第0行即当前ctb紧接着的上一行的sao时，要用到当前ctb第0行
            else
                dram_cb_right_4col_addrb <= {4{5'd0}};
            dram_rec_addrb               <= {32{5'd0}}; //所以要取dram_right_6col和dram_rec
            sao_nf_a_row                 <= {nf_up_ctb, nf_leftup};
            sao_type_left                <= component?sao_param_leftup.sao_type_idx[2]:
                                                      sao_param_leftup.sao_type_idx[1];
            sao_type_right               <= component?sao_param_up.sao_type_idx[2]:
                                                      sao_param_up.sao_type_idx[1];
            sao_eo_class_left            <= component?sao_param_leftup.sao_eo_class[2]:
                                                      sao_param_leftup.sao_eo_class[1];
            sao_eo_class_right           <= component?sao_param_up.sao_eo_class[2]:
                                                      sao_param_up.sao_eo_class[1];
            i                            <= i+1;
            phase                        <= 4;
        end

    end

    if (phase == 1) begin
        sao_buf_up                       <= row_up0;
        sao_buf                          <= {dram_rec_dob,dram_right_4col_dob[0],
                                                          dram_right_4col_dob[1],
                                                          dram_right_4col_dob[2],
                                                          dram_right_4col_dob[3]};
        if (component) begin
            dram_cr_right_4col_addrb     <= {4{sao_y_pls1}};
        end else begin
            dram_cb_right_4col_addrb     <= {4{sao_y_pls1}};
        end
        dram_rec_addrb                   <= {32{sao_y_pls1}};
        phase                            <= 2;
    end
    if (phase==2) begin
        sao_buf_down                     <= {dram_rec_dob,dram_right_4col_dob[0],
                                                          dram_right_4col_dob[1],
                                                          dram_right_4col_dob[2],
                                                          dram_right_4col_dob[3]};
        phase                            <= 5;
    end
    if (phase==3&&sao_valid) begin
        sao_buf_up                       <= sao_buf;
        sao_buf                          <= sao_buf_down;
        sao_buf_down                     <= {dram_rec_dob,dram_right_4col_dob[0],
                                                          dram_right_4col_dob[1],
                                                          dram_right_4col_dob[2],
                                                          dram_right_4col_dob[3]};
        phase                            <= 5;
    end
    if (phase == 4) begin
        row_up0                          <= {dram_up_3row_dob[0],row_up0[35:4]}; //移入
        case (sao_y)
        30: begin
                sao_buf_up               <= {dram_up_3row_dob[2],sao_buf_up[35:4]};
                sao_buf                  <= {dram_up_3row_dob[1],sao_buf[35:4]};
                sao_buf_down             <= {dram_up_3row_dob[0],sao_buf_down[35:4]};
            end

        default: begin
                sao_buf_up               <= {dram_up_3row_dob[1],sao_buf_up[35:4]};
                sao_buf                  <= {dram_up_3row_dob[0],sao_buf[35:4]};
                sao_buf_down             <= {dram_rec_dob,
                                            dram_right_4col_dob[0],
                                            dram_right_4col_dob[1],
                                            dram_right_4col_dob[2],
                                            dram_right_4col_dob[3]};
            end
        endcase
        i                                <= i+1;
        dram_up_3row_addrb               <= {3{i}};
        if (i==9) begin
            phase                        <= 5;
            i                            <= 0;
        end
    end
    if (phase == 5) begin

        sign0                            <= sign0_w;
        sign1                            <= sign1_w;

        pic_addr_off                     <= sao_up_ctb_done?{y0[`max_y_bits-1:6],sao_y[4:0],x_off}:
                                                            {y0_up_row[`max_y_bits-2:5],sao_y[4:0],x_off};

        if (sao_type_left == sao_none&&
            sao_type_right == sao_none) begin
            phase                        <= 10;
        end else begin
            phase                        <= 6;
        end
    end
    //从下面计算sao完跳上来，一行9次滤波第二次开始
    if (phase == 6) begin
        sao_offset_band                  <= sao_offset_band_w;
        edge_idx                         <= edge_idx_w;
        phase                            <= 7;

    end

    if (phase == 7) begin
        sao_result_band                  <= sao_result_band_w;
        sao_offset_edge                  <= sao_offset_edge_w;

        if (sao_type_left != sao_band||
            sao_type_right != sao_band)
            phase                        <= 8;
        else
            phase                        <= 10;
    end
    if (phase == 8) begin
        sao_offset_band                  <= sao_offset_band_w;
        edge_idx                         <= edge_idx_w;
        phase                            <= 9;
    end
    if (phase == 9) begin
        sao_result_edge                  <= sao_result_edge_w;
        phase                            <= 10;
    end
    if (phase == 10) begin

        if (first_col)
            sao_result                   <= {64'd0,sao_result_select_w[34:3]};
        else
            sao_result                   <= {sao_result_select_w,40'd0};

        m_axi_awaddr                     <= {pic_base_ddr[31:24],pic_addr_mid,pic_addr_off[19:0]};
        m_axi_awvalid                    <= 1;
        if (last_col)
            m_axi_awlen                  <= i_last_col_width[6:4];
        else if (first_col)
            m_axi_awlen                  <= 3;
        else
            m_axi_awlen                  <= 4;
        i                                <= 0;
        cond_last_sao_y                  <= (~last_row && sao_y == 29) || 
                                            (last_row && sao_y == last_row_height_minus1);
        cond_sao_y_eq31                  <= sao_y == 31;
        phase                            <= 11;
    end


    if (phase == 11&&m_axi_awready) begin
        m_axi_awvalid                    <= 0;
        phase                            <= 12;


    end

    if (phase==12) begin

        m_axi_wdata                      <= sao_result[7:0];
        m_axi_wvalid                     <= 1;


        if (~first_col && i == 0)
            m_axi_wstrb                  <= 8'b11100000;
        else if (last_col && i == m_axi_awlen)
            m_axi_wstrb                  <= 8'b11111111;
        else if (i == m_axi_awlen)
            m_axi_wstrb                  <= 8'b00011111;
        else
            m_axi_wstrb                  <= 8'b11111111;
        if (i == m_axi_awlen)
            m_axi_wlast                  <= 1;

        sao_result                       <= {64'd0,sao_result[39:8]};
        i                                <= i+1;
        phase                            <= 13;
    end

    if (phase == 13&&m_axi_wready) begin
        phase                            <= 12;
        m_axi_wvalid                     <= 0;
        if (m_axi_wlast)
            phase                        <= 14;
    end


    if (phase == 14) begin

        i                                <= 0;
        sao_y                            <= sao_y==31?0:sao_y+1;
        m_axi_wlast                      <= 0;
        m_axi_wvalid                     <= 0;
        if (sao_up_ctb_done) begin
            if (cond_last_sao_y) begin
                phase                    <= 19;
                sao_done                 <= 1;
            end else begin
                dram_cr_right_4col_addrb <= component?{4{sao_y_pls2}}:20'd0;
                dram_cb_right_4col_addrb <= ~component?{4{sao_y_pls2}}:20'd0;
                dram_rec_addrb           <= {32{sao_y_pls2}};
                phase                    <= 3;
            end
        end else begin
            if (cond_sao_y_eq31) begin
                sao_up_ctb_done          <= 1;
                phase                    <= 0;
            end else begin
                phase                    <= 4;
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
    i                                  = {random_val[22:0],random_val[31:23],random_val[22:0],random_val[31:23]};
    x0_minus4                          = {random_val[23:0],random_val[31:24],random_val[23:0],random_val[31:24]};
    first_col                          = {random_val[24:0],random_val[31:25],random_val[24:0],random_val[31:25]};
    first_row                          = {random_val[25:0],random_val[31:26],random_val[25:0],random_val[31:26]};
    last_col                           = {random_val[26:0],random_val[31:27],random_val[26:0],random_val[31:27]};
    last_row                           = {random_val[27:0],random_val[31:28],random_val[27:0],random_val[31:28]};
    last_row_height_minus1             = {random_val[28:0],random_val[31:29],random_val[28:0],random_val[31:29]};
    last_col_width_minus1              = {random_val[29:0],random_val[31:30],random_val[29:0],random_val[31:30]};
    prefetch_stage                     = {random_val[30:0],random_val[31],random_val[30:0],random_val[31]};
    fetch_x                            = {random_val[31:0],random_val[31:0]};
    fetch_y                            = {random_val,random_val};
    fetch_i                            = {random_val[1:0],random_val[31:2],random_val[1:0],random_val[31:2]};
    fetch_j                            = {random_val[2:0],random_val[31:3],random_val[2:0],random_val[31:3]};
    last_fetch_x                       = {random_val[3:0],random_val[31:4],random_val[3:0],random_val[31:4]};
    last_fetch_y                       = {random_val[4:0],random_val[31:5],random_val[4:0],random_val[31:5]};
    kick_deblock                       = {random_val[5:0],random_val[31:6],random_val[5:0],random_val[31:6]};
    x_to_deblock                       = {random_val[6:0],random_val[31:7],random_val[6:0],random_val[31:7]};
    y_to_deblock                       = {random_val[7:0],random_val[31:8],random_val[7:0],random_val[31:8]};
    i_to_deblock                       = {random_val[8:0],random_val[31:9],random_val[8:0],random_val[31:9]};
    store_x                            = {random_val[9:0],random_val[31:10],random_val[9:0],random_val[31:10]};
    store_y                            = {random_val[10:0],random_val[31:11],random_val[10:0],random_val[31:11]};
    x_to_store                         = {random_val[11:0],random_val[31:12],random_val[11:0],random_val[31:12]};
    y_to_store                         = {random_val[12:0],random_val[31:13],random_val[12:0],random_val[31:13]};
    i_to_store                         = {random_val[13:0],random_val[31:14],random_val[13:0],random_val[31:14]};
    component                          = {random_val[14:0],random_val[31:15],random_val[14:0],random_val[31:15]};
    bs_a_row                           = {random_val[15:0],random_val[31:16],random_val[15:0],random_val[31:16]};
    bs_a_col                           = {random_val[16:0],random_val[31:17],random_val[16:0],random_val[31:17]};
    nf_up_row                          = {random_val[17:0],random_val[31:18],random_val[17:0],random_val[31:18]};
    nf_down_row                        = {random_val[18:0],random_val[31:19],random_val[18:0],random_val[31:19]};
    nf_left_col                        = {random_val[19:0],random_val[31:20],random_val[19:0],random_val[31:20]};
    nf_right_col                       = {random_val[20:0],random_val[31:21],random_val[20:0],random_val[31:21]};
    nf_left_ctb_last_col               = {random_val[21:0],random_val[31:22],random_val[21:0],random_val[31:22]};
    nf_left_ctb_last_col               = {random_val[22:0],random_val[31:23],random_val[22:0],random_val[31:23]};
    nf_up_ctb                          = {random_val[23:0],random_val[31:24],random_val[23:0],random_val[31:24]};
    nf_up_ctb_copy                     = {random_val[24:0],random_val[31:25],random_val[24:0],random_val[31:25]};
    qpy_up_row                         = {random_val[25:0],random_val[31:26],random_val[25:0],random_val[31:26]};
    qpy_down_row                       = {random_val[26:0],random_val[31:27],random_val[26:0],random_val[31:27]};
    qpy_up_ctb                         = {random_val[27:0],random_val[31:28],random_val[27:0],random_val[31:28]};
    qpy_up_ctb_copy                    = {random_val[28:0],random_val[31:29],random_val[28:0],random_val[31:29]};
    qpy_left_col                       = {random_val[29:0],random_val[31:30],random_val[29:0],random_val[31:30]};
    qpy_right_col                      = {random_val[30:0],random_val[31],random_val[30:0],random_val[31]};
    qpy_left_ctb_last_col              = {random_val[31:0],random_val[31:0]};
    hor_deblock_done_y                 = {random_val,random_val};
    hor_deblock_done                   = {random_val[1:0],random_val[31:2],random_val[1:0],random_val[31:2]};
    bs                                 = {random_val[2:0],random_val[31:3],random_val[2:0],random_val[31:3]};
    QpP                                = {random_val[3:0],random_val[31:4],random_val[3:0],random_val[31:4]};
    QpQ                                = {random_val[4:0],random_val[31:5],random_val[4:0],random_val[31:5]};
    bypass_p                           = {random_val[5:0],random_val[31:6],random_val[5:0],random_val[31:6]};
    bypass_q                           = {random_val[6:0],random_val[31:7],random_val[6:0],random_val[31:7]};
    fetch_ver_a_row                    = {random_val[7:0],random_val[31:8],random_val[7:0],random_val[31:8]};
    fetch_hor_a_row                    = {random_val[8:0],random_val[31:9],random_val[8:0],random_val[31:9]};
    wait_cycle                         = {random_val[9:0],random_val[31:10],random_val[9:0],random_val[31:10]};
    pq_buf                             = {random_val[10:0],random_val[31:11],random_val[10:0],random_val[31:11]};
    pq_buf_bk                          = {random_val[11:0],random_val[31:12],random_val[11:0],random_val[31:12]};
    deblock_buf                        = {random_val[12:0],random_val[31:13],random_val[12:0],random_val[31:13]};
    deblock_buf_bk                     = {random_val[13:0],random_val[31:14],random_val[13:0],random_val[31:14]};
    bs_hor_left_ctb_last_col           = {random_val[14:0],random_val[31:15],random_val[14:0],random_val[31:15]};
    bs_hor_left_ctb_cur_row            = {random_val[15:0],random_val[31:16],random_val[15:0],random_val[31:16]};
    nf_leftup                          = {random_val[16:0],random_val[31:17],random_val[16:0],random_val[31:17]};
    nf_leftup_bk                       = {random_val[17:0],random_val[31:18],random_val[17:0],random_val[31:18]};
    qpy_leftup                         = {random_val[18:0],random_val[31:19],random_val[18:0],random_val[31:19]};
    qpy_leftup_bk                      = {random_val[19:0],random_val[31:20],random_val[19:0],random_val[31:20]};
    bram_cb_up_3row_we                 = {random_val[20:0],random_val[31:21],random_val[20:0],random_val[31:21]};
    bram_cb_up_3row_addra              = {random_val[21:0],random_val[31:22],random_val[21:0],random_val[31:22]};
    bram_cb_up_3row_addrb              = {random_val[22:0],random_val[31:23],random_val[22:0],random_val[31:23]};
    bram_cb_up_3row_dia                = {random_val[23:0],random_val[31:24],random_val[23:0],random_val[31:24]};
    h6                                 = {random_val[24:0],random_val[31:25],random_val[24:0],random_val[31:25]};
    h7                                 = {random_val[25:0],random_val[31:26],random_val[25:0],random_val[31:26]};
    h4                                 = {random_val[26:0],random_val[31:27],random_val[26:0],random_val[31:27]};
    h5                                 = {random_val[27:0],random_val[31:28],random_val[27:0],random_val[31:28]};
    bram_cr_up_3row_we                 = {random_val[28:0],random_val[31:29],random_val[28:0],random_val[31:29]};
    bram_cr_up_3row_addra              = {random_val[29:0],random_val[31:30],random_val[29:0],random_val[31:30]};
    bram_cr_up_3row_addrb              = {random_val[30:0],random_val[31],random_val[30:0],random_val[31]};
    bram_cr_up_3row_dia                = {random_val[31:0],random_val[31:0]};
    dram_cb_right_4col_we              = {random_val,random_val};
    dram_cb_right_4col_addra           = {random_val[1:0],random_val[31:2],random_val[1:0],random_val[31:2]};
    dram_cb_right_4col_addrb           = {random_val[2:0],random_val[31:3],random_val[2:0],random_val[31:3]};
    dram_cb_right_4col_addrd           = {random_val[3:0],random_val[31:4],random_val[3:0],random_val[31:4]};
    dram_cb_right_4col_did             = {random_val[4:0],random_val[31:5],random_val[4:0],random_val[31:5]};
    dram_cr_right_4col_we              = {random_val[5:0],random_val[31:6],random_val[5:0],random_val[31:6]};
    dram_cr_right_4col_addra           = {random_val[6:0],random_val[31:7],random_val[6:0],random_val[31:7]};
    dram_cr_right_4col_addrb           = {random_val[7:0],random_val[31:8],random_val[7:0],random_val[31:8]};
    dram_cr_right_4col_addrd           = {random_val[8:0],random_val[31:9],random_val[8:0],random_val[31:9]};
    dram_cr_right_4col_did             = {random_val[9:0],random_val[31:10],random_val[9:0],random_val[31:10]};
    fetch_up_3row_done                 = {random_val[10:0],random_val[31:11],random_val[10:0],random_val[31:11]};
    sao_done                           = {random_val[11:0],random_val[31:12],random_val[11:0],random_val[31:12]};
    dram_up_3row_we                    = {random_val[12:0],random_val[31:13],random_val[12:0],random_val[31:13]};
    dram_up_3row_addrd                 = {random_val[13:0],random_val[31:14],random_val[13:0],random_val[31:14]};
    dram_up_3row_addra                 = {random_val[14:0],random_val[31:15],random_val[14:0],random_val[31:15]};
    dram_up_3row_addrb                 = {random_val[15:0],random_val[31:16],random_val[15:0],random_val[31:16]};
    dram_up_3row_did                   = {random_val[16:0],random_val[31:17],random_val[16:0],random_val[31:17]};
    qPi                                = {random_val[17:0],random_val[31:18],random_val[17:0],random_val[31:18]};
    c_qp_pic_offset                    = {random_val[18:0],random_val[31:19],random_val[18:0],random_val[31:19]};
    QpC                                = {random_val[20:0],random_val[31:21],random_val[20:0],random_val[31:21]};
    Q                                  = {random_val[21:0],random_val[31:22],random_val[21:0],random_val[31:22]};
    tC                                 = {random_val[22:0],random_val[31:23],random_val[22:0],random_val[31:23]};
    neg_tc                             = {random_val[24:0],random_val[31:25],random_val[24:0],random_val[31:25]};
    store_right_y_d1                   = {random_val[25:0],random_val[31:26],random_val[25:0],random_val[31:26]};
    store_buf                          = {random_val[26:0],random_val[31:27],random_val[26:0],random_val[31:27]};
    store_up_i                         = {random_val[27:0],random_val[31:28],random_val[27:0],random_val[31:28]};
    store_up_addr                      = {random_val[28:0],random_val[31:29],random_val[28:0],random_val[31:29]};
    p0                                 = {random_val[29:0],random_val[31:30],random_val[29:0],random_val[31:30]};
    p1                                 = {random_val[30:0],random_val[31],random_val[30:0],random_val[31]};
    q0                                 = {random_val[31:0],random_val[31:0]};
    q1                                 = {random_val,random_val};
    p0_d1                              = {random_val[1:0],random_val[31:2],random_val[1:0],random_val[31:2]};
    q0_d1                              = {random_val[2:0],random_val[31:3],random_val[2:0],random_val[31:3]};
    p0_d2                              = {random_val[3:0],random_val[31:4],random_val[3:0],random_val[31:4]};
    q0_d2                              = {random_val[4:0],random_val[31:5],random_val[4:0],random_val[31:5]};
    p0_result                          = {random_val[5:0],random_val[31:6],random_val[5:0],random_val[31:6]};
    q0_result                          = {random_val[6:0],random_val[31:7],random_val[6:0],random_val[31:7]};
    valid                              = {random_val[7:0],random_val[31:8],random_val[7:0],random_val[31:8]};
    valid_d1                           = {random_val[8:0],random_val[31:9],random_val[8:0],random_val[31:9]};
    valid_d2                           = {random_val[9:0],random_val[31:10],random_val[9:0],random_val[31:10]};
    valid_d3                           = {random_val[10:0],random_val[31:11],random_val[10:0],random_val[31:11]};
    valid_d4                           = {random_val[11:0],random_val[31:12],random_val[11:0],random_val[31:12]};
    deblock_x                          = {random_val[12:0],random_val[31:13],random_val[12:0],random_val[31:13]};
    deblock_y                          = {random_val[13:0],random_val[31:14],random_val[13:0],random_val[31:14]};
    deblock_i                          = {random_val[14:0],random_val[31:15],random_val[14:0],random_val[31:15]};
    deblock_j                          = {random_val[15:0],random_val[31:16],random_val[15:0],random_val[31:16]};
    debug_j                            = {random_val[16:0],random_val[31:17],random_val[16:0],random_val[31:17]};
    deblock_stage                      = {random_val[17:0],random_val[31:18],random_val[17:0],random_val[31:18]};
    kick_store                         = {random_val[18:0],random_val[31:19],random_val[18:0],random_val[31:19]};
    deblock_done                       = {random_val[19:0],random_val[31:20],random_val[19:0],random_val[31:20]};
    tc_deblk                           = {random_val[20:0],random_val[31:21],random_val[20:0],random_val[31:21]};
    bypass_p_deblk                     = {random_val[21:0],random_val[31:22],random_val[21:0],random_val[31:22]};
    bypass_q_deblk                     = {random_val[22:0],random_val[31:23],random_val[22:0],random_val[31:23]};
    delta                              = {random_val[23:0],random_val[31:24],random_val[23:0],random_val[31:24]};
    delta_clip_tc                      = {random_val[24:0],random_val[31:25],random_val[24:0],random_val[31:25]};
    store_done                         = {random_val[26:0],random_val[31:27],random_val[26:0],random_val[31:27]};
    store_i                            = {random_val[27:0],random_val[31:28],random_val[27:0],random_val[31:28]};
    store_j                            = {random_val[28:0],random_val[31:29],random_val[28:0],random_val[31:29]};
    store_stage                        = {random_val[29:0],random_val[31:30],random_val[29:0],random_val[31:30]};
    fetch_up_stage                     = {random_val[30:0],random_val[31],random_val[30:0],random_val[31]};
    fetch_addr                         = {random_val[31:0],random_val[31:0]};
    store_right_y                      = {random_val,random_val};
    do_store_right                     = {random_val[1:0],random_val[31:2],random_val[1:0],random_val[31:2]};
    band                               = {random_val[2:0],random_val[31:3],random_val[2:0],random_val[31:3]};
    band_up                            = {random_val[3:0],random_val[31:4],random_val[3:0],random_val[31:4]};
    band_left                          = {random_val[4:0],random_val[31:5],random_val[4:0],random_val[31:5]};
    band_leftup                        = {random_val[5:0],random_val[31:6],random_val[5:0],random_val[31:6]};
    sao_left_class_plus_k              = {random_val[6:0],random_val[31:7],random_val[6:0],random_val[31:7]};
    sao_left_class_plus_k_up           = {random_val[7:0],random_val[31:8],random_val[7:0],random_val[31:8]};
    sao_left_class_plus_k_left         = {random_val[8:0],random_val[31:9],random_val[8:0],random_val[31:9]};
    sao_left_class_plus_k_leftup       = {random_val[9:0],random_val[31:10],random_val[9:0],random_val[31:10]};
    n                                  = {random_val[10:0],random_val[31:11],random_val[10:0],random_val[31:11]};
    sao_y                              = {random_val[11:0],random_val[31:12],random_val[11:0],random_val[31:12]};
    sao_type_left                      = {random_val[12:0],random_val[31:13],random_val[12:0],random_val[31:13]};
    sao_type_right                     = {random_val[13:0],random_val[31:14],random_val[13:0],random_val[31:14]};
    sao_eo_class_left                  = {random_val[14:0],random_val[31:15],random_val[14:0],random_val[31:15]};
    sao_eo_class_right                 = {random_val[15:0],random_val[31:16],random_val[15:0],random_val[31:16]};
    edge_idx                           = {random_val[16:0],random_val[31:17],random_val[16:0],random_val[31:17]};
    sao_buf_up                         = {random_val[17:0],random_val[31:18],random_val[17:0],random_val[31:18]};
    sao_buf                            = {random_val[18:0],random_val[31:19],random_val[18:0],random_val[31:19]};
    sao_buf_down                       = {random_val[19:0],random_val[31:20],random_val[19:0],random_val[31:20]};
    sao_result                         = {random_val[20:0],random_val[31:21],random_val[20:0],random_val[31:21]};
    sao_offset_band[34:0]              = '{35{random_val[3:0]}};
    sao_offset_edge[34:0]              = '{35{random_val[3:0]}};
    sao_nf_a_row                       = {random_val[23:0],random_val[31:24],random_val[23:0],random_val[31:24]};
    sign0                              = '{35{random_val[1:0]}};
    sign1                              = '{35{random_val[1:0]}};
    sao_result_band                    = {random_val[26:0],random_val[31:27],random_val[26:0],random_val[31:27]};
    sao_result_edge                    = {random_val[27:0],random_val[31:28],random_val[27:0],random_val[31:28]};
    sao_up_ctb_done                    = {random_val[28:0],random_val[31:29],random_val[28:0],random_val[31:29]};
    sao_valid                          = {random_val[29:0],random_val[31:30],random_val[29:0],random_val[31:30]};
    cond_last_sao_y                    = {random_val[30:0],random_val[31],random_val[30:0],random_val[31]};
    cond_sao_y_eq31                    = {random_val[31:0],random_val[31:0]};
    pic_base_ddr                       = {random_val,random_val};
    pic_addr_off                       = {random_val[1:0],random_val[31:2],random_val[1:0],random_val[31:2]};
end
`endif




endmodule
