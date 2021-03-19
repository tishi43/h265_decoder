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

module inter_pred_chroma
(
 input wire                          clk                      ,
 input wire                          rst                      ,
 input wire                          rst_luma                 ,
 input wire                          global_rst               ,
 input wire                          i_rst_slice              ,
 input wire                          en                       ,
 input wire             [15:0]       i_slice_num              ,
 input wire  [`max_x_bits-1:0]       i_x0                     , //亮度坐标
 input wire  [`max_y_bits-1:0]       i_y0                     ,
 input wire             [ 5:0]       i_xPb                    ,
 input wire             [ 5:0]       i_yPb                    ,
 input wire  [`max_x_bits-1:0]       i_PicWidthInSamplesY     , //luma宽高
 input wire  [`max_y_bits-1:0]       i_PicHeightInSamplesY    ,

 input wire             [ 6:0]       i_nPbW                   , //luma的pu宽度
 input wire             [ 6:0]       i_nPbH                   ,
 input wire             [ 6:0]       i_CbSize                 , //luma的CbSize

 input wire signed      [14:0]       i_mvx                    ,
 input wire signed      [14:0]       i_mvy                    ,
 input wire                          i_component              , //0=cb,1=cr

 output wire                         o_fifo_rd_en             ,
 input wire             [63:0]       i_fifo_data              ,
 input wire                          i_fifo_empty             ,

 output reg             [31:0]       dram_pred_we             ,
 output reg       [31:0][ 4:0]       dram_pred_addrd          ,
 output reg       [31:0][ 7:0]       dram_pred_did            ,

 input wire             [31:0]       fd_log,
 output reg             [ 5:0]       o_pred_done_y            ,
 output reg  [`max_y_bits-2:0]       o_ref_start_y            ,
 output reg  [`max_y_bits-2:0]       o_ref_end_y              ,
 output reg  [`max_x_bits-2:0]       o_ref_start_x            ,
 output reg  [`max_x_bits-2:0]       o_ref_end_x              ,
 output reg                          o_inter_pred_done

);


parameter inter_pred_type_full = 2'b00;
parameter inter_pred_type_hor  = 2'b01; //利用横向7/8点插值
parameter inter_pred_type_ver  = 2'b10;
parameter inter_pred_type_hv   = 2'b11;

reg                   [ 5:0]        x0                      ;
reg                   [ 5:0]        y0                      ;
reg                   [ 4:0]        xPb                     ;
reg                   [ 4:0]        yPb                     ;
reg  signed           [15:0]        x_tmp                   ;
reg  signed           [15:0]        y_tmp                   ;
reg                   [ 4:0]        y                       ;
reg                   [ 4:0]        y_fetch_save            ;

reg signed [`max_x_bits-1:0]        ref_start_x_tmp         ;
reg signed [`max_y_bits-1:0]        ref_start_y_tmp         ;
reg signed [`max_x_bits-1:0]        ref_end_x_tmp           ;
reg signed [`max_y_bits-1:0]        ref_end_y_tmp           ;

reg                   [ 6:0]        nPbW                    ;
reg                   [ 6:0]        nPbH                    ;
reg                   [ 6:0]        CbSize                  ;


reg                   [ 5:0]        fetch_w                 ;
reg                   [ 5:0]        fetch_h                 ;
reg                   [ 5:0]        fetch_h_minus1          ;

reg                   [ 5:0]        fetched_rows          ;

reg                   [ 5:0]        in_bound_w              ;
reg                   [ 5:0]        in_bound_h              ;
reg                   [ 5:0]        in_bound_w_cur          ;
reg                   [ 5:0]        in_bound_h_cur          ;
reg                   [ 5:0]        pre_bound_w             ;//超出图像左边宽度
reg                   [ 5:0]        pre_bound_h             ;//超出图像上边高度
reg                   [ 5:0]        exd_bound_w             ;//超出图像右边宽度
reg                   [ 5:0]        exd_bound_h             ;//超出图像下边高度
reg                   [ 5:0]        pre_bound_w_cur         ;
reg                   [ 5:0]        pre_bound_h_cur         ;
reg                   [ 5:0]        exd_bound_w_cur         ;
reg                   [ 5:0]        exd_bound_h_cur         ;

reg                   [ 2:0]        x_frac                  ;
reg                   [ 2:0]        y_frac                  ;


reg                   [ 3:0]        stage                   ;
reg                                 first_cycle_stg2        ;

wire signed [`max_x_bits-1:0]       pic_width_signed        ;
wire signed [`max_y_bits-1:0]       pic_height_signed       ;
reg         [`max_x_bits-2:0]       pic_width_minus1        ;
reg         [`max_y_bits-2:0]       pic_height_minus1       ;

assign pic_width_signed  = {1'b0,i_PicWidthInSamplesY[`max_x_bits-1:1]};
assign pic_height_signed = {1'b0,i_PicHeightInSamplesY[`max_y_bits-1:1]};


reg       [ 3:0][31:0][ 7:0]        ver_buf                 ;
reg       [ 3:0][31:0][ 7:0]        ver_buf_bk              ;

reg                   [ 2:0]        i                       ;
reg       [ 6:0][ 7:0][ 7:0]        hor_buf                 ; //32+3=35,35+16
reg             [39:0][ 7:0]        hor_buf_bk              ;

reg             [ 1:0]              inter_pred_type         ;
reg                    [ 7:0]        first_byte            ;
reg                    [ 7:0]        last_byte             ;
wire             [55:0][ 7:0]        hor_buf_w             ;
assign hor_buf_w = hor_buf;

reg                                 interp_hor_done         ;
reg                                 interp_hor_pre_done     ;
reg                                 interp_ver_done         ;
reg                                 interp_ver_pre_done     ;
reg                                 interp_hv_done          ; //inter_pred_type_hv先v再h的h interpolate完
reg                                 interp_hv_pre_done      ;
reg                                 store_done              ;
reg                                 store_pre_done          ;

reg                                  rst_store_full        ;
reg                                  rst_store_hor         ;
reg                                  rst_store_ver         ;
reg                                  rst_store_hv          ;
reg                                  rst_interp_hor        ;
reg                                  rst_interp_ver        ;
reg                                  rst_interp_hv         ;


reg                  [ 4:0]         store_y                ;
reg                  [ 4:0]         y_interp_hor           ;
reg                  [ 4:0]         y_interp_ver           ;
reg                  [ 4:0]         y_interp_hv            ;

reg                  [ 2:0]         m_axi_arlen            ;

assign o_fifo_rd_en = ~i_fifo_empty && ((stage==2&&i!=m_axi_arlen)||stage==1||stage==10);


always @ (posedge clk)
if (global_rst||i_rst_slice) begin
    stage                       <= 8;
    rst_store_full              <= 0;
    rst_interp_hor              <= 0;
    rst_interp_ver              <= 0;
end else if (rst_luma) begin
    x0                          <= i_x0[5:0];
    y0                          <= i_y0[5:0];
    xPb                         <= i_xPb[5:1];
    yPb                         <= i_yPb[5:1];
    nPbW                        <= i_nPbW;
    nPbH                        <= i_nPbH;
    CbSize                      <= i_CbSize;

    pic_width_minus1            <= i_PicWidthInSamplesY[`max_x_bits-1:1]-1;
    pic_height_minus1           <= i_PicHeightInSamplesY[`max_y_bits-1:1]-1;

    x_frac                    <= i_mvx[2:0];
    y_frac                    <= i_mvy[2:0];

    if (i_mvx[2:0] && i_mvy[2:0]) begin
        inter_pred_type       <= inter_pred_type_hv;
    end else if (i_mvx[2:0]) begin
        inter_pred_type       <= inter_pred_type_hor;
    end else if (i_mvy[2:0]) begin
        inter_pred_type       <= inter_pred_type_ver;
    end else begin
        inter_pred_type       <= inter_pred_type_full;
    end

    if (i_mvx[2:0]) begin
        ref_start_x_tmp       <= {i_x0[`max_x_bits-1:6],i_xPb[5:1]}+(i_mvx>>>3)-1;
        ref_end_x_tmp         <= {i_x0[`max_x_bits-1:6],i_xPb[5:1]}+(i_mvx>>>3)+i_nPbW[6:1]+1;
        fetch_w               <= i_nPbW[6:1]+3;
    end else begin
        ref_start_x_tmp       <= {i_x0[`max_x_bits-1:6],i_xPb[5:1]}+(i_mvx>>>3);
        ref_end_x_tmp         <= {i_x0[`max_x_bits-1:6],i_xPb[5:1]}+(i_mvx>>>3)+i_nPbW[6:1]-1;
        fetch_w               <= i_nPbW[6:1];
    end
    if (i_mvy[2:0]) begin
        ref_start_y_tmp       <= {i_y0[`max_y_bits-1:6],i_yPb[5:1]}+(i_mvy>>>3)-1;
        ref_end_y_tmp         <= {i_y0[`max_y_bits-1:6],i_yPb[5:1]}+(i_mvy>>>3)+i_nPbH[6:1]+1;
        fetch_h               <= i_nPbH[6:1]+3;
        fetch_h_minus1        <= i_nPbH[6:1]+2;
    end else begin
        ref_start_y_tmp       <= {i_y0[`max_y_bits-1:6],i_yPb[5:1]}+(i_mvy>>>3);
        ref_end_y_tmp         <= {i_y0[`max_y_bits-1:6],i_yPb[5:1]}+(i_mvy>>>3)+i_nPbH[6:1]-1;
        fetch_h               <= i_nPbH[6:1];
        fetch_h_minus1        <= i_nPbH[6:1]-1;
    end

    stage                     <= 0;


end else if (rst) begin
    y_fetch_save              <= i_yPb[5:1];
    y                         <= i_yPb[5:1];
    if (`log_p && i_slice_num>=`slice_begin && i_slice_num<=`slice_end) begin

        if (i_mvx[2:0]&&i_mvy[2:0])
            $fdisplay(fd_log, "epel hv");
        else if (i_mvx[2:0])
            $fdisplay(fd_log, "epel h");
        else if (i_mvy[2:0])
            $fdisplay(fd_log, "epel v");
        else
            $fdisplay(fd_log, "pel full sample");
    end
    pre_bound_w_cur     <= pre_bound_w;
    in_bound_w_cur      <= in_bound_w;
    exd_bound_w_cur     <= exd_bound_w;
    pre_bound_h_cur     <= pre_bound_h;
    in_bound_h_cur      <= in_bound_h;
    exd_bound_h_cur     <= exd_bound_h;
    m_axi_arlen         <= o_ref_end_x[`max_x_bits-2:3]-o_ref_start_x[`max_x_bits-2:3];

    i                   <= 0;
    first_cycle_stg2    <= 1;
    fetched_rows        <= 0;

    rst_interp_hor      <= 0;
    rst_store_full      <= 0;
    rst_interp_ver      <= 0;
    stage               <= 1;


end else if (stage == 0) begin
    if (ref_start_x_tmp >= pic_width_signed)
        o_ref_start_x   <= pic_width_minus1;
    else if (ref_start_x_tmp < 0)
        o_ref_start_x   <= 0;
    else
        o_ref_start_x   <= ref_start_x_tmp;

    if (ref_start_y_tmp >= pic_height_signed) begin
        o_ref_start_y   <= pic_height_minus1;
    end else if (ref_start_y_tmp < 0) begin
        o_ref_start_y   <= 0;
    end else begin
        o_ref_start_y   <= ref_start_y_tmp;
    end

    if (ref_end_x_tmp >= pic_width_signed)
        o_ref_end_x     <= pic_width_minus1;
    else if (ref_end_x_tmp < 0)
        o_ref_end_x     <= 0;
    else
        o_ref_end_x     <= ref_end_x_tmp;

    if (ref_end_y_tmp >= pic_height_signed)
        o_ref_end_y     <= pic_height_minus1;
    else if (ref_end_y_tmp < 0)
        o_ref_end_y     <= 0;
    else
        o_ref_end_y     <= ref_end_y_tmp;

    //不考虑ref_start_x<0,ref_end_x>pic_width_minus1
    if (ref_start_x_tmp<0&&ref_end_x_tmp<0) begin
        pre_bound_w     <= fetch_w;
        in_bound_w      <= 0;
        exd_bound_w     <= 0;
    end else if (ref_start_x_tmp<0) begin
        pre_bound_w     <= ~ref_start_x_tmp+1;
        in_bound_w      <= ref_end_x_tmp+1;
        exd_bound_w     <= 0;
    end else if (ref_start_x_tmp >= pic_width_signed &&
                 ref_end_x_tmp >= pic_width_signed) begin
        pre_bound_w     <= 0;
        in_bound_w      <= 0;
        exd_bound_w     <= fetch_w;
    end else if (ref_end_x_tmp >= pic_width_signed) begin //width=480,end=480,in width=0
        pre_bound_w     <= 0;
        in_bound_w      <= pic_width_signed-ref_start_x_tmp;
        exd_bound_w     <= ref_end_x_tmp-pic_width_signed+1;
    end else begin
        pre_bound_w     <= 0;
        in_bound_w      <= fetch_w;
        exd_bound_w     <= 0;
    end

    if (ref_start_y_tmp<0&&ref_end_y_tmp<0) begin
        pre_bound_h     <= fetch_h;
        in_bound_h      <= 0;
        exd_bound_h     <= 0;
    end else if (ref_start_y_tmp<0) begin
        pre_bound_h     <= ~ref_start_y_tmp+1;
        in_bound_h      <= ref_end_y_tmp+1;
        exd_bound_h     <= 0;
    end else if (ref_start_y_tmp >= pic_height_signed &&
                 ref_end_y_tmp >= pic_height_signed) begin
        pre_bound_h     <= 0;
        in_bound_h      <= 0;
        exd_bound_h     <= fetch_h;
    end else if (ref_end_y_tmp >= pic_height_signed) begin
        pre_bound_h     <= 0;
        in_bound_h      <= pic_height_signed-ref_start_y_tmp;
        exd_bound_h     <= ref_end_y_tmp-pic_height_signed+1;
    end else begin
        pre_bound_h     <= 0;
        in_bound_h      <= fetch_h;
        exd_bound_h     <= 0;
    end

end else if (en) begin
    if (stage==1&&~i_fifo_empty)
        stage                 <= 2;

    if (stage==1) begin
        rst_store_full        <= 0;
        rst_interp_hor        <= 0;
        rst_interp_ver        <= 0;
    end

    if (stage==2&&first_cycle_stg2) begin

        first_cycle_stg2      <= 0;
    end

    if (stage == 2) begin
        hor_buf[i]            <= i_fifo_data;
        i                     <= i+1;

        if (i == 0)
            first_byte        <= i_fifo_data[7:0];
        last_byte             <= i_fifo_data[63:56];
        if (i==m_axi_arlen) begin
            if (pre_bound_w) begin
                stage         <= 3;
            end else if (exd_bound_w) begin
                stage         <= 5;
            end else if (in_bound_w) begin
                stage         <= 4;
            end
        end else if (i_fifo_empty)
            stage             <= 10;
    end

    if (stage==10&&~i_fifo_empty)
        stage                 <= 2;

    if (stage==3) begin
        case (pre_bound_w_cur)
            1:hor_buf         <= {hor_buf_w[54:0],first_byte};
            2:hor_buf         <= {hor_buf_w[53:0],{2{first_byte}}};
            3:hor_buf         <= {hor_buf_w[52:0],{3{first_byte}}};
            4:hor_buf         <= {hor_buf_w[51:0],{4{first_byte}}};
            5:hor_buf         <= {hor_buf_w[50:0],{5{first_byte}}};
            6:hor_buf         <= {hor_buf_w[49:0],{6{first_byte}}};
            7:hor_buf         <= {hor_buf_w[48:0],{7{first_byte}}};
            default:hor_buf   <= {hor_buf_w[47:0],{8{first_byte}}};
        endcase
        i                     <= i+1;
        pre_bound_w_cur       <= pre_bound_w_cur-8;
        if (pre_bound_w_cur<=8) begin

        end
    end

    if (stage==4) begin
        case (o_ref_start_x[2:0])
            0:hor_buf         <= hor_buf;
            1:hor_buf         <= {8'd0,hor_buf_w[55:1]};
            2:hor_buf         <= {16'd0,hor_buf_w[55:2]};
            3:hor_buf         <= {24'd0,hor_buf_w[55:3]};
            4:hor_buf         <= {32'd0,hor_buf_w[55:4]};
            5:hor_buf         <= {40'd0,hor_buf_w[55:5]};
            6:hor_buf         <= {48'd0,hor_buf_w[55:6]};
            7:hor_buf         <= {56'd0,hor_buf_w[55:7]};
        endcase
        i                     <= i+1;
    end

    if (stage==5) begin
        hor_buf[i]            <= {8{last_byte}};
        i                     <= i+1;
        exd_bound_w_cur       <= exd_bound_w_cur-8;
        if (exd_bound_w_cur<=8) begin
            if (in_bound_w) begin
                stage         <= 4;
            end else begin

            end
        end
    end

    if ((stage==3&&pre_bound_w_cur<=8)||
         stage==4||
         (stage==5&&exd_bound_w_cur<=8&&in_bound_w==0)) begin

            pre_bound_w_cur             <= pre_bound_w;
            in_bound_w_cur              <= in_bound_w;
            exd_bound_w_cur             <= exd_bound_w;

            if (inter_pred_type==inter_pred_type_full||
                inter_pred_type==inter_pred_type_hor||
                fetched_rows>=3)
                y                       <= y+1;
            y_fetch_save                <= y;

            if (inter_pred_type==inter_pred_type_ver)
                stage                   <= 6;
            else begin
                if (((inter_pred_type==inter_pred_type_hor||
                      inter_pred_type==inter_pred_type_hv)&& ~interp_hor_pre_done)||
                     (inter_pred_type==inter_pred_type_full&&
                      ~store_pre_done)) begin
                    stage               <= 7;
                end else begin
                    fetched_rows        <= fetched_rows+1;

                    rst_store_full      <= inter_pred_type == inter_pred_type_full?1:0;
                    rst_interp_hor      <= inter_pred_type==inter_pred_type_hor||
                                       inter_pred_type==inter_pred_type_hv?1:0;
                    first_cycle_stg2    <= 1;

                    stage               <= fetched_rows==fetch_h_minus1?8:
                                            (pre_bound_h_cur ||(exd_bound_h_cur&&in_bound_h_cur<=1)?9:1);

                    i                    <= 0;

                    if (pre_bound_h_cur) begin
                        pre_bound_h_cur <= pre_bound_h_cur-1;
                    end else if (in_bound_h_cur) begin
                       in_bound_h_cur   <= in_bound_h_cur-1;
                    end else if (exd_bound_h_cur) begin
                        exd_bound_h_cur <= exd_bound_h_cur-1;
                    end

                end
            end

    end

    if (stage==6) begin
        if (~interp_ver_pre_done) begin
            stage                   <= 7;
        end else begin
            fetched_rows            <= fetched_rows+1;
            rst_interp_ver          <= fetched_rows>=3?1:0;

            first_cycle_stg2        <= 1;
            stage                   <= fetched_rows==fetch_h_minus1?8:
                                       (pre_bound_h_cur ||(exd_bound_h_cur&&in_bound_h_cur<=1)?9:1);

            i                        <= 0;

            if (pre_bound_h_cur) begin
                pre_bound_h_cur     <= pre_bound_h_cur-1;
            end else if (in_bound_h_cur) begin
               in_bound_h_cur       <= in_bound_h_cur-1;
            end else if (exd_bound_h_cur) begin
                exd_bound_h_cur     <= exd_bound_h_cur-1;
            end

        end
        ver_buf                     <= {hor_buf[3:0],ver_buf[3:1]};
    end

    if (stage==7) begin
        if (((inter_pred_type==inter_pred_type_hor||
              inter_pred_type==inter_pred_type_hv)&&
              interp_hor_pre_done)||
             (inter_pred_type==inter_pred_type_ver&&
              interp_ver_pre_done)||
              (inter_pred_type==inter_pred_type_full&&
               store_pre_done)) begin
            rst_interp_hor          <= inter_pred_type==inter_pred_type_hor||
                                       inter_pred_type==inter_pred_type_hv ?1:0;
            rst_interp_ver          <= inter_pred_type==inter_pred_type_ver&&
                                       fetched_rows>=3 ? 1:0;
            rst_store_full          <= inter_pred_type==inter_pred_type_full&&
                                       store_pre_done;
            fetched_rows            <= fetched_rows+1;
            first_cycle_stg2        <= 1;
            stage                   <= fetched_rows==fetch_h_minus1?8:
                                       (pre_bound_h_cur ||(exd_bound_h_cur&&in_bound_h_cur<=1)?9:1);

            i                        <= 0;

            if (pre_bound_h_cur) begin
                pre_bound_h_cur     <= pre_bound_h_cur-1;
            end else if (in_bound_h_cur) begin
               in_bound_h_cur       <= in_bound_h_cur-1;
            end else if (exd_bound_h_cur) begin
                exd_bound_h_cur     <= exd_bound_h_cur-1;
            end

        end

    end

    if (stage == 8) begin
        rst_store_full              <= 0;
        rst_interp_hor              <= 0;
        rst_interp_ver              <= 0;
    end

    //pre_bound_h_cur>0,exd_bound_h_cur>0复用已取的行
    if (stage ==9) begin
        rst_store_full              <= 0;
        rst_interp_hor              <= 0;
        rst_interp_ver              <= 0;
        stage                       <= inter_pred_type==inter_pred_type_ver?6:7;

        if (inter_pred_type==inter_pred_type_full||
            inter_pred_type==inter_pred_type_hor||
            fetched_rows>=3)
            y                       <= y+1;
        y_fetch_save                <= y;

    end

end

reg         [ 2:0]          interp_hor_i                 ;
reg         [ 2:0]          interp_hor_i_max             ;
reg         [ 2:0]          interp_hor_i_d1              ;
reg         [ 2:0]          interp_hor_i_d2              ;

reg                         interp_hor_valid             ;
reg                         interp_hor_valid_d1          ;
reg                         interp_hor_valid_d2          ;
reg                         interp_hor_stage             ;

reg               [ 5:0]    interpolated_rows              ;

wire signed [ 9:0]          interp_hor_weighted_w[7:0]     ;

wire signed [7:0][7:0]      interp_hor_clip_w              ;
reg signed  [3:0][7:0][7:0] interp_hor_clip                ; //最宽32=4x8

wire signed [7:0][15:0]     interp_hor_w                   ;
reg  signed [7:0][15:0]     interp_hor                     ;

reg signed [3:0][3:0][7:0][15:0] intermediate             ;
reg signed     [3:0][31:0][15:0] intermediate_bk          ;

wire signed [ 9:0]          interp_hor_tmp_b0_w[7:0]      ;
wire signed [14:0]          interp_hor_tmp_b1_w[7:0]      ;
wire signed [ 9:0]          interp_hor_tmp_b2_w[7:0]      ;
wire signed [ 9:0]          interp_hor_tmp_b3_w[7:0]      ;
wire signed [14:0]          interp_hor_tmp_b4_w[7:0]      ;
wire signed [ 9:0]          interp_hor_tmp_b5_w[7:0]      ;

wire signed [14:0]          interp_hor_tmp_c0_w[7:0]      ;
wire signed [15:0]          interp_hor_tmp_c1_w[7:0]      ;
wire signed [10:0]          interp_hor_tmp_c2_w[7:0]      ;
wire signed [15:0]          interp_hor_tmp_c3_w[7:0]      ;
wire signed [14:0]          interp_hor_tmp_c4_w[7:0]      ;
wire signed [15:0]          interp_hor_tmp_c5_w[7:0]      ;
wire signed [15:0]          interp_hor_tmp_c6_w[7:0]      ;
wire signed [14:0]          interp_hor_tmp_c7_w[7:0]      ;
wire signed [15:0]          interp_hor_tmp_c8_w[7:0]      ;
wire signed [10:0]          interp_hor_tmp_c9_w[7:0]      ;
wire signed [15:0]          interp_hor_tmp_c10_w[7:0]     ;
wire signed [15:0]          interp_hor_tmp_c11_w[7:0]     ;
wire signed [12:0]          interp_hor_tmp_c12_w[7:0]     ;

reg  signed [14:0]          interp_hor_tmp_c0[7:0]        ;
reg  signed [15:0]          interp_hor_tmp_c1[7:0]        ;
reg  signed [10:0]          interp_hor_tmp_c2[7:0]        ;
reg  signed [15:0]          interp_hor_tmp_c3[7:0]        ;
reg  signed [14:0]          interp_hor_tmp_c4[7:0]        ;
reg  signed [15:0]          interp_hor_tmp_c5[7:0]        ;
reg  signed [15:0]          interp_hor_tmp_c6[7:0]        ;
reg  signed [14:0]          interp_hor_tmp_c7[7:0]        ;
reg  signed [15:0]          interp_hor_tmp_c8[7:0]        ;
reg  signed [10:0]          interp_hor_tmp_c9[7:0]        ;
reg  signed [15:0]          interp_hor_tmp_c10[7:0]       ;
reg  signed [15:0]          interp_hor_tmp_c11[7:0]       ;
reg  signed [12:0]          interp_hor_tmp_c12[7:0]       ;

genvar I;


//{ -2, 58, 10, -2},//58=64-4-2
//{ -4, 54, 16, -2},//54=64-8-2
//{ -6, 46, 28, -4},//46=64-16-2,28=32-4
//{ -4, 36, 36, -4},
//{ -4, 28, 46, -6},
//{ -2, 16, 54, -4},
//{ -2, 10, 58, -2},

//a0           a1              a2             a3
//-2,          64-4-2,         8+2,           -2          a0+a3=b0 5个地方用到,(64-2)a1=b1 3个地方用到,-a1+2a2=b2,这里-4a1+8a2,下面-8a1+16a2,再下面-16a1+32a2
//-4,          64-8-2,         16,            -2
//-4-2,        64-16-2,        32-4,          -4
//-4,          32+4,           32+4,          -4          a1+a2=b3, 2个地方用到,
//-4,          32-4,           64-16-2,       -4-2        (64-2)a2=b4, 3个地方用到
//-2,          16,             64-8-2,        -4            2a1-a2=b5,3个地方用到
//-2,          8+2,            64-4-2,        -2           


generate
    for (I=0;I<8;I++)
    begin: interp_hor_tmp_label
        assign interp_hor_tmp_b0_w[I] = hor_buf_bk[I]+hor_buf_bk[I+3];//15,18
        assign interp_hor_tmp_b1_w[I] = {hor_buf_bk[I+1],6'd0}-{hor_buf_bk[I+1],1'd0};
        assign interp_hor_tmp_b2_w[I] = {hor_buf_bk[I+2],1'd0}-hor_buf_bk[I+1];
        assign interp_hor_tmp_b3_w[I] = hor_buf_bk[I+1]+hor_buf_bk[I+2];//16,17
        assign interp_hor_tmp_b4_w[I] = {hor_buf_bk[I+2],6'd0}-{hor_buf_bk[I+2],1'd0};
        assign interp_hor_tmp_b5_w[I] = {hor_buf_bk[I+1],1'd0}-hor_buf_bk[I+2];
        assign interp_hor_tmp_c0_w[I] = (interp_hor_tmp_b2_w[I]<<<2)-(interp_hor_tmp_b0_w[I]<<<1);
        assign interp_hor_tmp_c1_w[I] = interp_hor_tmp_b1_w[I]+{hor_buf_bk[I+2],1'd0};
        assign interp_hor_tmp_c2_w[I] = {hor_buf_bk[I],2'd0}+{hor_buf_bk[I+3],1'd0};
        assign interp_hor_tmp_c3_w[I] = interp_hor_tmp_b1_w[I]+(interp_hor_tmp_b2_w[I]<<<3);
        assign interp_hor_tmp_c4_w[I] = (interp_hor_tmp_b2_w[I]<<<4)-{hor_buf_bk[I+2],2'd0}-{hor_buf_bk[I],1'd0};
        assign interp_hor_tmp_c5_w[I] = interp_hor_tmp_b1_w[I]-(interp_hor_tmp_b0_w[I]<<<2);
        assign interp_hor_tmp_c6_w[I] = (interp_hor_tmp_b3_w[I]<<<5)+(interp_hor_tmp_b3_w[I]<<<2)-(interp_hor_tmp_b0_w[I]<<<2);
        assign interp_hor_tmp_c7_w[I] = (interp_hor_tmp_b5_w[I]<<<4)-{hor_buf_bk[I+1],2'd0}-{hor_buf_bk[I+3],1'd0};
        assign interp_hor_tmp_c8_w[I] = interp_hor_tmp_b4_w[I]-(interp_hor_tmp_b0_w[I]<<<2);
        assign interp_hor_tmp_c9_w[I] = {hor_buf_bk[I],1'd0}+{hor_buf_bk[I+3],2'd0};
        assign interp_hor_tmp_c10_w[I] = interp_hor_tmp_b4_w[I]+(interp_hor_tmp_b5_w[I]<<<3);
        assign interp_hor_tmp_c11_w[I] = interp_hor_tmp_b4_w[I]-(interp_hor_tmp_b0_w[I]<<<1);
        assign interp_hor_tmp_c12_w[I] = (interp_hor_tmp_b5_w[I]<<<2)+{hor_buf_bk[I+1],1'd0};
    end
endgenerate

generate
    for (I=0;I<8;I++)
    begin: interpolate_hor_label
        assign interp_hor_w[I] = x_frac==1?interp_hor_tmp_c0[I]+interp_hor_tmp_c1[I]:(
                                    x_frac==2?interp_hor_tmp_c3[I]-interp_hor_tmp_c2[I]:(
                                    x_frac==3?interp_hor_tmp_c4[I]+interp_hor_tmp_c5[I]:(
                                    x_frac==4?interp_hor_tmp_c6[I]:(
                                    x_frac==5?interp_hor_tmp_c7[I]+interp_hor_tmp_c8[I]:(
                                    x_frac==6?interp_hor_tmp_c10[I]-interp_hor_tmp_c9[I]:
                                              interp_hor_tmp_c11[I]+interp_hor_tmp_c12[I]
                                    )))));

    end
endgenerate

generate
    for (I=0;I<8;I++)
    begin: interpolate_hor_weight_label
        assign interp_hor_weighted_w[I] = (interp_hor[I]+32)>>>6;

    end
endgenerate

generate
    for (I=0;I<8;I++)
    begin: interpolate_hor_clip_label
        assign interp_hor_clip_w[I] = interp_hor_weighted_w[I][9]?0:(interp_hor_weighted_w[I][8]?255:interp_hor_weighted_w[I][7:0]);

    end
endgenerate


always @(posedge clk)
if (global_rst||i_rst_slice) begin
    interp_hor_done            <= 1;
    rst_store_hor              <= 0;
    rst_interp_hv              <= 0;
end else if (rst) begin
    interp_hor_done            <= 1;
    interp_hor_pre_done        <= 1;
    interpolated_rows          <= 0;
    interp_hor_stage           <= 0;
    //4的倍数，8的倍数
    if (i_nPbW[3]||i_nPbW[2])
        interp_hor_i_max       <= i_nPbW[6:4];
    else
        interp_hor_i_max       <= i_nPbW[6:4]-1;
end else if (rst_interp_hor) begin
    interp_hor_done            <= 0;
    interp_hor_pre_done        <= 0;
    rst_store_hor              <= 0;
    rst_interp_hv              <= 0;
    interpolated_rows          <= interpolated_rows+1;
    y_interp_hor               <= y_fetch_save;
    hor_buf_bk                 <= hor_buf[4:0];
    intermediate               <= {512'd0,intermediate[3:1]};

    interp_hor_i               <= 0;
    interp_hor_i_d1            <= 3'b111;
    interp_hor_i_d2            <= 3'b111;
    interp_hor_valid           <= 0;
    interp_hor_valid_d1        <= 0;
    interp_hor_valid_d2        <= 0;

end else if (interp_hor_done==0)begin
    //pipeline stage 0
    hor_buf_bk                 <= {64'd0,hor_buf_bk[39:8]};
    interp_hor_i               <= interp_hor_i+1;
    interp_hor_valid           <= 1;

    interp_hor_tmp_c0          <= interp_hor_tmp_c0_w;
    interp_hor_tmp_c1          <= interp_hor_tmp_c1_w;
    interp_hor_tmp_c2          <= interp_hor_tmp_c2_w;
    interp_hor_tmp_c3          <= interp_hor_tmp_c3_w;
    interp_hor_tmp_c4          <= interp_hor_tmp_c4_w;
    interp_hor_tmp_c5          <= interp_hor_tmp_c5_w;
    interp_hor_tmp_c6          <= interp_hor_tmp_c6_w;
    interp_hor_tmp_c7          <= interp_hor_tmp_c7_w;
    interp_hor_tmp_c8          <= interp_hor_tmp_c8_w;
    interp_hor_tmp_c9          <= interp_hor_tmp_c9_w;
    interp_hor_tmp_c10         <= interp_hor_tmp_c10_w;
    interp_hor_tmp_c11         <= interp_hor_tmp_c11_w;
    interp_hor_tmp_c12         <= interp_hor_tmp_c12_w;


    //pipeline stage 1
    interp_hor_i_d1            <= interp_hor_i;
    interp_hor_valid_d1        <= interp_hor_valid;
    interp_hor                 <= interp_hor_w;

    //pipeline stage 2
    interp_hor_i_d2            <= interp_hor_i_d1;
    interp_hor_valid_d2        <= interp_hor_valid_d1;
    if (interp_hor_valid_d1) begin
        interp_hor_clip        <= {interp_hor_clip_w,interp_hor_clip[3:1]};

        intermediate[3][interp_hor_i_d2]        <= interp_hor;
    end

    if (interp_hor_i_d1==interp_hor_i_max)
        interp_hor_pre_done    <= 1;

    if (interp_hor_i_d2==interp_hor_i_max) begin
        interp_hor_done        <= 1;
        if (inter_pred_type==inter_pred_type_hor) begin
            if (~store_pre_done)
                $display("%t possible? chroma interp hor need wait store_pred_done", $time);
            rst_store_hor      <= 1;
            interp_hor_stage   <= 0;
        end else if (inter_pred_type==inter_pred_type_hv&&
                 interpolated_rows>=4) begin
            rst_interp_hv      <= interp_hv_pre_done?1:0;
            interp_hor_stage   <= interp_hv_pre_done?0:1;
        end
    end

end else begin
    if (interp_hor_stage==0) begin
        rst_store_hor          <= 0;
        rst_interp_hv          <= 0;
    end

    if (interp_hor_stage==1) begin
        if (inter_pred_type==inter_pred_type_hv&&
                 interpolated_rows>=4&&interp_hv_pre_done) begin
            rst_interp_hv      <= 1;
            interp_hor_stage   <= 0;
        end
    end


end

reg             [ 2:0]      interp_ver_i                 ;
reg             [ 2:0]      interp_ver_i_max             ;
reg             [ 2:0]      interp_ver_i_d1              ;
reg             [ 2:0]      interp_ver_i_d2              ;

reg                         interp_ver_valid             ;
reg                         interp_ver_valid_d1          ;
reg                         interp_ver_valid_d2          ;


wire signed [ 9:0]         interp_ver_weighted_w[7:0]    ;

wire signed [ 7:0][7:0]    interp_ver_clip_w              ;
reg  signed [31:0][7:0]    interp_ver_clip                ;

wire signed [15:0]         interp_ver_w[7:0]             ;
reg  signed [15:0]         interp_ver[7:0]               ;

wire signed [ 9:0]         interp_ver_tmp_b0_w[7:0]      ;
wire signed [14:0]         interp_ver_tmp_b1_w[7:0]      ;
wire signed [ 9:0]         interp_ver_tmp_b2_w[7:0]      ;
wire signed [ 9:0]         interp_ver_tmp_b3_w[7:0]      ;
wire signed [14:0]         interp_ver_tmp_b4_w[7:0]      ;
wire signed [ 9:0]         interp_ver_tmp_b5_w[7:0]      ;

wire signed [14:0]         interp_ver_tmp_c0_w[7:0]      ;
wire signed [15:0]         interp_ver_tmp_c1_w[7:0]      ;
wire signed [10:0]         interp_ver_tmp_c2_w[7:0]      ;
wire signed [15:0]         interp_ver_tmp_c3_w[7:0]      ;
wire signed [14:0]         interp_ver_tmp_c4_w[7:0]      ;
wire signed [15:0]         interp_ver_tmp_c5_w[7:0]      ;
wire signed [15:0]         interp_ver_tmp_c6_w[7:0]      ;
wire signed [14:0]         interp_ver_tmp_c7_w[7:0]      ;
wire signed [15:0]         interp_ver_tmp_c8_w[7:0]      ;
wire signed [10:0]         interp_ver_tmp_c9_w[7:0]      ;
wire signed [15:0]         interp_ver_tmp_c10_w[7:0]     ;
wire signed [15:0]         interp_ver_tmp_c11_w[7:0]     ;
wire signed [12:0]         interp_ver_tmp_c12_w[7:0]     ;

reg  signed [14:0]         interp_ver_tmp_c0[7:0]        ;
reg  signed [15:0]         interp_ver_tmp_c1[7:0]        ;
reg  signed [10:0]         interp_ver_tmp_c2[7:0]        ;
reg  signed [15:0]         interp_ver_tmp_c3[7:0]        ;
reg  signed [14:0]         interp_ver_tmp_c4[7:0]        ;
reg  signed [15:0]         interp_ver_tmp_c5[7:0]        ;
reg  signed [15:0]         interp_ver_tmp_c6[7:0]        ;
reg  signed [14:0]         interp_ver_tmp_c7[7:0]        ;
reg  signed [15:0]         interp_ver_tmp_c8[7:0]        ;
reg  signed [10:0]         interp_ver_tmp_c9[7:0]        ;
reg  signed [15:0]         interp_ver_tmp_c10[7:0]       ;
reg  signed [15:0]         interp_ver_tmp_c11[7:0]       ;
reg  signed [12:0]         interp_ver_tmp_c12[7:0]       ;
generate
    for (I=0;I<8;I++)
    begin: interp_ver_tmp_label
        assign interp_ver_tmp_b0_w[I] = ver_buf_bk[0][I]+ver_buf_bk[3][I];
        assign interp_ver_tmp_b1_w[I] = {ver_buf_bk[1][I],6'd0}-{ver_buf_bk[1][I],1'd0};
        assign interp_ver_tmp_b2_w[I] = {ver_buf_bk[2][I],1'd0}-ver_buf_bk[1][I];
        assign interp_ver_tmp_b3_w[I] = ver_buf_bk[1][I]+ver_buf_bk[2][I];
        assign interp_ver_tmp_b4_w[I] = {ver_buf_bk[2][I],6'd0}-{ver_buf_bk[2][I],1'd0};
        assign interp_ver_tmp_b5_w[I] = {ver_buf_bk[1][I],1'd0}-ver_buf_bk[2][I];
        assign interp_ver_tmp_c0_w[I] = (interp_ver_tmp_b2_w[I]<<<2)-(interp_ver_tmp_b0_w[I]<<<1);
        assign interp_ver_tmp_c1_w[I] = interp_ver_tmp_b1_w[I]+{ver_buf_bk[2][I],1'd0};
        assign interp_ver_tmp_c2_w[I] = {ver_buf_bk[0][I],2'd0}+{ver_buf_bk[3][I],1'd0};
        assign interp_ver_tmp_c3_w[I] = interp_ver_tmp_b1_w[I]+(interp_ver_tmp_b2_w[I]<<<3);
        assign interp_ver_tmp_c4_w[I] = (interp_ver_tmp_b2_w[I]<<<4)-{ver_buf_bk[2][I],2'd0}-{ver_buf_bk[0][I],1'd0};
        assign interp_ver_tmp_c5_w[I] = interp_ver_tmp_b1_w[I]-(interp_ver_tmp_b0_w[I]<<<2);
        assign interp_ver_tmp_c6_w[I] = (interp_ver_tmp_b3_w[I]<<<5)+(interp_ver_tmp_b3_w[I]<<<2)-(interp_ver_tmp_b0_w[I]<<<2);
        assign interp_ver_tmp_c7_w[I] = (interp_ver_tmp_b5_w[I]<<<4)-{ver_buf_bk[1][I],2'd0}-{ver_buf_bk[3][I],1'd0};
        assign interp_ver_tmp_c8_w[I] = interp_ver_tmp_b4_w[I]-(interp_ver_tmp_b0_w[I]<<<2);
        assign interp_ver_tmp_c9_w[I] = {ver_buf_bk[0][I],1'd0}+{ver_buf_bk[3][I],2'd0};
        assign interp_ver_tmp_c10_w[I] = interp_ver_tmp_b4_w[I]+(interp_ver_tmp_b5_w[I]<<<3);
        assign interp_ver_tmp_c11_w[I] = interp_ver_tmp_b4_w[I]-(interp_ver_tmp_b0_w[I]<<<1);
        assign interp_ver_tmp_c12_w[I] = (interp_ver_tmp_b5_w[I]<<<2)+{ver_buf_bk[1][I],1'd0};

    end
endgenerate

generate
    for (I=0;I<8;I++)
    begin: interpolate_ver_label
        assign interp_ver_w[I] = y_frac==1?interp_ver_tmp_c0[I]+interp_ver_tmp_c1[I]:(
                                    y_frac==2?interp_ver_tmp_c3[I]-interp_ver_tmp_c2[I]:(
                                    y_frac==3?interp_ver_tmp_c4[I]+interp_ver_tmp_c5[I]:(
                                    y_frac==4?interp_ver_tmp_c6[I]:(
                                    y_frac==5?interp_ver_tmp_c7[I]+interp_ver_tmp_c8[I]:(
                                    y_frac==6?interp_ver_tmp_c10[I]-interp_ver_tmp_c9[I]:
                                              interp_ver_tmp_c11[I]+interp_ver_tmp_c12[I]
                                    )))));
    end
endgenerate


generate
    for (I=0;I<8;I++)
    begin: interpolate_ver_weight_label
        assign interp_ver_weighted_w[I] = (interp_ver[I]+32)>>>6;
    end
endgenerate

generate
    for (I=0;I<8;I++)
    begin: interpolate_ver_clip_label
        assign interp_ver_clip_w[I] = interp_ver_weighted_w[I][9]?
            0:(interp_ver_weighted_w[I][8]?255:interp_ver_weighted_w[I][7:0]);
    end
endgenerate


always @(posedge clk)
if (global_rst||i_rst_slice) begin
    interp_ver_done            <= 1;
    rst_store_ver              <= 0;
end else if (rst) begin
    interp_ver_done            <= 1;
    interp_ver_pre_done        <= 1;
    if (i_nPbW[3]||i_nPbW[2])
        interp_ver_i_max       <= i_nPbW[6:4];
    else
        interp_ver_i_max       <= i_nPbW[6:4]-1;
end else if (rst_interp_ver) begin
    interp_ver_done            <= 0;
    interp_ver_pre_done        <= 0;
    rst_store_ver              <= 0;
    y_interp_ver               <= y_fetch_save;
    ver_buf_bk                 <= ver_buf;

    interp_ver_i               <= 0;
    interp_ver_i_d1            <= 3'b111;
    interp_ver_i_d2            <= 3'b111;
    interp_ver_valid           <= 0;
    interp_ver_valid_d1        <= 0;
    interp_ver_valid_d2        <= 0;
end else if (~interp_ver_done) begin

    //pipeline stage 0
    ver_buf_bk[0]              <= {64'd0,ver_buf_bk[0][31:8]};
    ver_buf_bk[1]              <= {64'd0,ver_buf_bk[1][31:8]};
    ver_buf_bk[2]              <= {64'd0,ver_buf_bk[2][31:8]};
    ver_buf_bk[3]              <= {64'd0,ver_buf_bk[3][31:8]};
    interp_ver_i               <= interp_ver_i+1;
    interp_ver_valid           <= 1;

    interp_ver_tmp_c0          <= interp_ver_tmp_c0_w;
    interp_ver_tmp_c1          <= interp_ver_tmp_c1_w;
    interp_ver_tmp_c2          <= interp_ver_tmp_c2_w;
    interp_ver_tmp_c3          <= interp_ver_tmp_c3_w;
    interp_ver_tmp_c4          <= interp_ver_tmp_c4_w;
    interp_ver_tmp_c5          <= interp_ver_tmp_c5_w;
    interp_ver_tmp_c6          <= interp_ver_tmp_c6_w;
    interp_ver_tmp_c7          <= interp_ver_tmp_c7_w;
    interp_ver_tmp_c8          <= interp_ver_tmp_c8_w;
    interp_ver_tmp_c9          <= interp_ver_tmp_c9_w;
    interp_ver_tmp_c10         <= interp_ver_tmp_c10_w;
    interp_ver_tmp_c11         <= interp_ver_tmp_c11_w;
    interp_ver_tmp_c12         <= interp_ver_tmp_c12_w;

    //pipeline stage 1
    interp_ver_i_d1            <= interp_ver_i;
    interp_ver_valid_d1        <= interp_ver_valid;
    interp_ver                 <= interp_ver_w;

    //pipeline stage 2
    interp_ver_i_d2            <= interp_ver_i_d1;
    interp_ver_valid_d2        <= interp_ver_valid_d1;
    if (interp_ver_valid_d1) begin
        interp_ver_clip        <= {interp_ver_clip_w,interp_ver_clip[31:8]};
    end

    if (interp_ver_i_d1==interp_ver_i_max)
        interp_ver_pre_done    <= 1;

    if (interp_ver_i_d2==interp_ver_i_max) begin
        interp_ver_done        <= 1;
        if (~store_pre_done)
            $display("%t possible?chroma interp ver need wait store_pred_done",$time);
        rst_store_ver          <= 1;
    end

end else begin
    rst_store_ver              <= 0;
end


reg             [ 2:0]      interp_hv_i                 ;
reg             [ 2:0]      interp_hv_i_max             ;
reg             [ 2:0]      interp_hv_i_d1              ;
reg             [ 2:0]      interp_hv_i_d2              ;

reg                         interp_hv_valid             ;
reg                         interp_hv_valid_d1          ;
reg                         interp_hv_valid_d2          ;

wire signed [9:0]          interp_hv_weighted_w[7:0]    ;

wire signed [ 7:0][7:0]    interp_hv_clip_w              ;
reg  signed [31:0][7:0]    interp_hv_clip                ;

wire signed [21:0]         interp_hv_w[7:0]             ;
reg  signed [21:0]         interp_hv[7:0]               ;


wire signed [15:0]         interp_hv_tmp_b0_w[7:0]      ;
wire signed [20:0]         interp_hv_tmp_b1_w[7:0]      ;
wire signed [15:0]         interp_hv_tmp_b2_w[7:0]      ;
wire signed [15:0]         interp_hv_tmp_b3_w[7:0]      ;
wire signed [20:0]         interp_hv_tmp_b4_w[7:0]      ;
wire signed [15:0]         interp_hv_tmp_b5_w[7:0]      ;

wire signed [20:0]         interp_hv_tmp_c0_w[7:0]      ;
wire signed [21:0]         interp_hv_tmp_c1_w[7:0]      ;
wire signed [16:0]         interp_hv_tmp_c2_w[7:0]      ;
wire signed [21:0]         interp_hv_tmp_c3_w[7:0]      ;
wire signed [20:0]         interp_hv_tmp_c4_w[7:0]      ;
wire signed [21:0]         interp_hv_tmp_c5_w[7:0]      ;
wire signed [21:0]         interp_hv_tmp_c6_w[7:0]      ;
wire signed [20:0]         interp_hv_tmp_c7_w[7:0]      ;
wire signed [21:0]         interp_hv_tmp_c8_w[7:0]      ;
wire signed [16:0]         interp_hv_tmp_c9_w[7:0]      ;
wire signed [21:0]         interp_hv_tmp_c10_w[7:0]     ;
wire signed [21:0]         interp_hv_tmp_c11_w[7:0]     ;
wire signed [18:0]         interp_hv_tmp_c12_w[7:0]     ;

reg  signed [20:0]         interp_hv_tmp_c0[7:0]        ;
reg  signed [21:0]         interp_hv_tmp_c1[7:0]        ;
reg  signed [16:0]         interp_hv_tmp_c2[7:0]        ;
reg  signed [21:0]         interp_hv_tmp_c3[7:0]        ;
reg  signed [20:0]         interp_hv_tmp_c4[7:0]        ;
reg  signed [21:0]         interp_hv_tmp_c5[7:0]        ;
reg  signed [21:0]         interp_hv_tmp_c6[7:0]        ;
reg  signed [20:0]         interp_hv_tmp_c7[7:0]        ;
reg  signed [21:0]         interp_hv_tmp_c8[7:0]        ;
reg  signed [16:0]         interp_hv_tmp_c9[7:0]        ;
reg  signed [21:0]         interp_hv_tmp_c10[7:0]       ;
reg  signed [21:0]         interp_hv_tmp_c11[7:0]       ;
reg  signed [18:0]         interp_hv_tmp_c12[7:0]       ;
generate
    for (I=0;I<8;I++)
    begin: interp_hv_tmp_label
        assign interp_hv_tmp_b0_w[I] = intermediate_bk[0][I]+intermediate_bk[3][I];
        assign interp_hv_tmp_b1_w[I] = (intermediate_bk[1][I]<<<6)-(intermediate_bk[1][I]<<<1);
        assign interp_hv_tmp_b2_w[I] = (intermediate_bk[2][I]<<<1)-intermediate_bk[1][I];
        assign interp_hv_tmp_b3_w[I] = intermediate_bk[1][I]+intermediate_bk[2][I];
        assign interp_hv_tmp_b4_w[I] = (intermediate_bk[2][I]<<<6)-(intermediate_bk[2][I]<<<1);
        assign interp_hv_tmp_b5_w[I] = (intermediate_bk[1][I]<<<1)-intermediate_bk[2][I];
        assign interp_hv_tmp_c0_w[I] = (interp_hv_tmp_b2_w[I]<<<2)-(interp_hv_tmp_b0_w[I]<<<1);
        assign interp_hv_tmp_c1_w[I] = interp_hv_tmp_b1_w[I]+(intermediate_bk[2][I]<<<1);
        assign interp_hv_tmp_c2_w[I] = (intermediate_bk[0][I]<<<2)+(intermediate_bk[3][I]<<<1);
        assign interp_hv_tmp_c3_w[I] = interp_hv_tmp_b1_w[I]+(interp_hv_tmp_b2_w[I]<<<3);
        assign interp_hv_tmp_c4_w[I] = (interp_hv_tmp_b2_w[I]<<<4)-(intermediate_bk[2][I]<<<2)-(intermediate_bk[0][I]<<<1);
        assign interp_hv_tmp_c5_w[I] = interp_hv_tmp_b1_w[I]-(interp_hv_tmp_b0_w[I]<<<2);
        assign interp_hv_tmp_c6_w[I] = (interp_hv_tmp_b3_w[I]<<<5)+(interp_hv_tmp_b3_w[I]<<<2)-(interp_hv_tmp_b0_w[I]<<<2);
        assign interp_hv_tmp_c7_w[I] = (interp_hv_tmp_b5_w[I]<<<4)-(intermediate_bk[1][I]<<<2)-(intermediate_bk[3][I]<<<1);
        assign interp_hv_tmp_c8_w[I] = interp_hv_tmp_b4_w[I]-(interp_hv_tmp_b0_w[I]<<<2);
        assign interp_hv_tmp_c9_w[I] = (intermediate_bk[0][I]<<<1)+(intermediate_bk[3][I]<<<2);
        assign interp_hv_tmp_c10_w[I] = interp_hv_tmp_b4_w[I]+(interp_hv_tmp_b5_w[I]<<<3);
        assign interp_hv_tmp_c11_w[I] = interp_hv_tmp_b4_w[I]-(interp_hv_tmp_b0_w[I]<<<1);
        assign interp_hv_tmp_c12_w[I] = (interp_hv_tmp_b5_w[I]<<<2)+(intermediate_bk[1][I]<<<1);

    end
endgenerate

generate
    for (I=0;I<8;I++)
    begin: interpolate_hv_label
        assign interp_hv_w[I] = y_frac==1?interp_hv_tmp_c0[I]+interp_hv_tmp_c1[I]:(
                                    y_frac==2?interp_hv_tmp_c3[I]-interp_hv_tmp_c2[I]:(
                                    y_frac==3?interp_hv_tmp_c4[I]+interp_hv_tmp_c5[I]:(
                                    y_frac==4?interp_hv_tmp_c6[I]:(
                                    y_frac==5?interp_hv_tmp_c7[I]+interp_hv_tmp_c8[I]:(
                                    y_frac==6?interp_hv_tmp_c10[I]-interp_hv_tmp_c9[I]:
                                              interp_hv_tmp_c11[I]+interp_hv_tmp_c12[I]
                                    )))));
    end
endgenerate


generate
    for (I=0;I<8;I++)
    begin: interpolate_hv_weight_label
        assign interp_hv_weighted_w[I] = ((interp_hv[I]>>>6)+32)>>>6;

    end
endgenerate

generate
    for (I=0;I<8;I++)
    begin: interpolate_hv_clip_label
        assign interp_hv_clip_w[I] = interp_hv_weighted_w[I][9]?0:
                                     (interp_hv_weighted_w[I][8]?255:
                                       interp_hv_weighted_w[I][7:0]);

    end
endgenerate




always @(posedge clk)
if (global_rst||i_rst_slice) begin
    interp_hv_done            <= 1;
    rst_store_hv              <= 0;
end else if (rst) begin
    interp_hv_done            <= 1;
    interp_hv_pre_done        <= 1;

    if (i_nPbW[3]||i_nPbW[2])
        interp_hv_i_max       <= i_nPbW[6:4];
    else
        interp_hv_i_max       <= i_nPbW[6:4]-1;
end else if (rst_interp_hv) begin
    interp_hv_done            <= 0;
    interp_hv_pre_done        <= 0;
    rst_store_hv              <= 0;
    y_interp_hv               <= y_interp_hor;
    intermediate_bk           <= intermediate;

    interp_hv_i               <= 0;
    interp_hv_i_d1            <= 3'b111;
    interp_hv_i_d2            <= 3'b111;
    interp_hv_valid           <= 0;
    interp_hv_valid_d1        <= 0;
    interp_hv_valid_d2        <= 0;
end else if (~interp_hv_done) begin


    //pipeline stage 0
    intermediate_bk[0]        <= {64'd0,intermediate_bk[0][31:8]};
    intermediate_bk[1]        <= {64'd0,intermediate_bk[1][31:8]};
    intermediate_bk[2]        <= {64'd0,intermediate_bk[2][31:8]};
    intermediate_bk[3]        <= {64'd0,intermediate_bk[3][31:8]};
    interp_hv_i               <= interp_hv_i+1;
    interp_hv_valid           <= 1;

    interp_hv_tmp_c0          <= interp_hv_tmp_c0_w;
    interp_hv_tmp_c1          <= interp_hv_tmp_c1_w;
    interp_hv_tmp_c2          <= interp_hv_tmp_c2_w;
    interp_hv_tmp_c3          <= interp_hv_tmp_c3_w;
    interp_hv_tmp_c4          <= interp_hv_tmp_c4_w;
    interp_hv_tmp_c5          <= interp_hv_tmp_c5_w;
    interp_hv_tmp_c6          <= interp_hv_tmp_c6_w;
    interp_hv_tmp_c7          <= interp_hv_tmp_c7_w;
    interp_hv_tmp_c8          <= interp_hv_tmp_c8_w;
    interp_hv_tmp_c9          <= interp_hv_tmp_c9_w;
    interp_hv_tmp_c10         <= interp_hv_tmp_c10_w;
    interp_hv_tmp_c11         <= interp_hv_tmp_c11_w;
    interp_hv_tmp_c12         <= interp_hv_tmp_c12_w;

    //pipeline stage 1
    interp_hv_i_d1            <= interp_hv_i;
    interp_hv_valid_d1        <= interp_hv_valid;
    interp_hv                 <= interp_hv_w;

    //pipeline stage 2
    interp_hv_i_d2            <= interp_hv_i_d1;
    interp_hv_valid_d2        <= interp_hv_valid_d1;
    if (interp_hv_valid_d1) begin
        interp_hv_clip        <= {interp_hv_clip_w,interp_hv_clip[31:8]};
    end

    if (interp_hv_i_d1==interp_hv_i_max)
        interp_hv_pre_done    <= 1;

    if (interp_hv_i_d2==interp_hv_i_max) begin
        interp_hv_done        <= 1;
        if (~store_pre_done)
            $display("%t possible? chroma interp hv need wait store_pred_done",$time);
        rst_store_hv          <= 1;
    end

end else begin
    rst_store_hv              <= 0;

end



reg  [31:0][ 7:0]             store_buf;
reg  [31:0][ 7:0]             store_buf_tmp;
reg        [ 1:0]             store_stage;
reg                           cond_one_row_done;

always @ (posedge clk)
if (global_rst||i_rst_slice) begin
    o_pred_done_y                   <= 6'b111111;
    dram_pred_we                    <= {32{1'b0}};
    o_inter_pred_done               <= 1;
    store_done                      <= 1;
end else if (rst) begin
    store_stage                     <= 0;
    store_done                      <= 1;
    store_pre_done                  <= 1;
    store_y                         <= i_yPb[5:1];
    o_pred_done_y                   <= 6'b111111;
    o_inter_pred_done               <= 0;
    dram_pred_we                    <= {32{1'b0}};
end else if (rst_store_full||rst_store_ver||
             rst_store_hor||rst_store_hv) begin
    store_stage                     <= 0;
    store_done                      <= 0;
    store_pre_done                  <= 0;

    if (inter_pred_type == inter_pred_type_full) begin
        store_y                     <= y_fetch_save;
        store_buf_tmp               <= hor_buf[3:0];
    end else if (inter_pred_type == inter_pred_type_hor) begin
        store_y                     <= y_interp_hor;
        store_buf_tmp               <= interp_hor_clip;
    end else if (inter_pred_type == inter_pred_type_ver) begin
        store_y                     <= y_interp_ver;
        store_buf_tmp               <= interp_ver_clip;
    end else if (inter_pred_type == inter_pred_type_hv) begin
        store_y                     <= y_interp_hv;
        store_buf_tmp               <= interp_hv_clip;
    end

end else if (~store_done) begin
    //CU 64x64:64,32,16,48, chroma:32,16,8,24
    //CU 32x32:32,16,8,24,  chroma:16,8,4,12
    //CU 16x16:16,8,4,12    chroma:8,4,2,6
    if (store_stage == 0) begin
        if (inter_pred_type == inter_pred_type_full) begin
            store_buf               <= store_buf_tmp;
        end else begin
            //nPbW=2,interploate时移入了8字节
            //high                                          low
            //| 6无效字节 | 2有效字节|     24                  |
            //nPbW=12,
            //high                                          low
            //| 4无效字节 | 12有效字节|     16                  |
            case (nPbW[6:1])
                2:store_buf         <= {{30{8'd0}},store_buf_tmp[25:24]};
                4:store_buf         <= {{28{8'd0}},store_buf_tmp[27:24]};
                6:store_buf         <= {{26{8'd0}},store_buf_tmp[29:24]};
                8:store_buf         <= {{24{8'd0}},store_buf_tmp[31:24]};
                12:store_buf        <= {{20{8'd0}},store_buf_tmp[27:16]};
                16:store_buf        <= {{16{8'd0}},store_buf_tmp[31:16]};
                24:store_buf        <= {{8{8'd0}},store_buf_tmp[31:8]};
                default:store_buf   <= store_buf_tmp; //32
            endcase
        end

        cond_one_row_done           <= xPb+nPbW[6:1] == x0[5:1]+CbSize[6:1];
        store_pre_done              <= 1;
        store_stage                 <= 1;
    end

    if (store_stage==1) begin
        case (xPb[4:1])
            0: dram_pred_did        <= store_buf;
            1: dram_pred_did        <= {store_buf[29:0],{2{8'd0}}};
            2: dram_pred_did        <= {store_buf[27:0],{4{8'd0}}};
            3: dram_pred_did        <= {store_buf[25:0],{6{8'd0}}};
            4: dram_pred_did        <= {store_buf[23:0],{8{8'd0}}};
            5: dram_pred_did        <= {store_buf[21:0],{10{8'd0}}};
            6: dram_pred_did        <= {store_buf[19:0],{12{8'd0}}};
            7: dram_pred_did        <= {store_buf[17:0],{14{8'd0}}};
            8: dram_pred_did        <= {store_buf[15:0],{16{8'd0}}};
            9: dram_pred_did        <= {store_buf[13:0],{18{8'd0}}};
            10:dram_pred_did        <= {store_buf[11:0],{20{8'd0}}};
            11:dram_pred_did        <= {store_buf[9:0],{22{8'd0}}};
            12:dram_pred_did        <= {store_buf[7:0],{24{8'd0}}};
            13:dram_pred_did        <= {store_buf[5:0],{26{8'd0}}};
            14:dram_pred_did        <= {store_buf[3:0],{28{8'd0}}};
            15:dram_pred_did        <= {store_buf[1:0],{30{8'd0}}};
        endcase
        case (xPb[4:1])
            0: dram_pred_we         <= {32{1'b1}};
            1: dram_pred_we         <= {{30{1'b1}},2'd0};
            2: dram_pred_we         <= {{28{1'b1}},4'd0};
            3: dram_pred_we         <= {{26{1'b1}},6'd0};
            4: dram_pred_we         <= {{24{1'b1}},8'd0};
            5: dram_pred_we         <= {{22{1'b1}},10'd0};
            6: dram_pred_we         <= {{20{1'b1}},12'd0};
            7: dram_pred_we         <= {{18{1'b1}},14'd0};
            8: dram_pred_we         <= {{16{1'b1}},16'd0};
            9: dram_pred_we         <= {{14{1'b1}},18'd0};
            10:dram_pred_we         <= {{12{1'b1}},20'd0};
            11:dram_pred_we         <= {{10{1'b1}},22'd0};
            12:dram_pred_we         <= {{8{1'b1}},24'd0};
            13:dram_pred_we         <= {{6{1'b1}},26'd0};
            14:dram_pred_we         <= {{4{1'b1}},28'd0};
            15:dram_pred_we         <= {{2{1'b1}},30'd0};
        endcase


        if (`log_p && i_slice_num>=`slice_begin && i_slice_num<=`slice_end) begin
            if (nPbW[6:1]==2)
                $fdisplay(fd_log, "yc %0d xc %0d:%0d %0d",
                    store_y,xPb,
                    store_buf[0],store_buf[1]);
            else if (nPbW[6:1]==4)
                $fdisplay(fd_log, "yc %0d xc %0d:%0d %0d %0d %0d",
                    store_y,xPb,
                    store_buf[0],store_buf[1],
                    store_buf[2],store_buf[3]);
            else if (nPbW[6:1]==6)
                $fdisplay(fd_log, "yc %0d xc %0d:%0d %0d %0d %0d %0d %0d",
                    store_y,xPb,
                    store_buf[0],store_buf[1],
                    store_buf[2],store_buf[3],
                    store_buf[4],store_buf[5]);
            else if (nPbW[6:1]==8)
                $fdisplay(fd_log, "yc %0d xc %0d:%0d %0d %0d %0d %0d %0d %0d %0d",
                    store_y,xPb,
                    store_buf[0],store_buf[1],
                    store_buf[2],store_buf[3],
                    store_buf[4],store_buf[5],
                    store_buf[6],store_buf[7]);
            else if (nPbW[6:1]==10)
                $fdisplay(fd_log, "yc %0d xc %0d:%0d %0d %0d %0d %0d %0d %0d %0d %0d %0d",
                    store_y,xPb,
                    store_buf[0],store_buf[1],
                    store_buf[2],store_buf[3],
                    store_buf[4],store_buf[5],
                    store_buf[6],store_buf[7],
                    store_buf[8],store_buf[9]);
            else if (nPbW[6:1]==12)
                $fdisplay(fd_log, "yc %0d xc %0d:%0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d",
                    store_y,xPb,
                    store_buf[0],store_buf[1],
                    store_buf[2],store_buf[3],
                    store_buf[4],store_buf[5],
                    store_buf[6],store_buf[7],
                    store_buf[8],store_buf[9],
                    store_buf[10],store_buf[11]);
            else if (nPbW[6:1]==14)
                $fdisplay(fd_log, "yc %0d xc %0d:%0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d",
                    store_y,xPb,
                    store_buf[0],store_buf[1],
                    store_buf[2],store_buf[3],
                    store_buf[4],store_buf[5],
                    store_buf[6],store_buf[7],
                    store_buf[8],store_buf[9],
                    store_buf[10],store_buf[11],
                    store_buf[12],store_buf[13]);
            else if (nPbW[6:1]==16)
                $fdisplay(fd_log, "yc %0d xc %0d:%0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d",
                    store_y,xPb,
                    store_buf[0],store_buf[1],
                    store_buf[2],store_buf[3],
                    store_buf[4],store_buf[5],
                    store_buf[6],store_buf[7],
                    store_buf[8],store_buf[9],
                    store_buf[10],store_buf[11],
                    store_buf[12],store_buf[13],
                    store_buf[14],store_buf[15]);
            else if (nPbW[6:1]==24) begin
                $fdisplay(fd_log, "yc %0d xc %0d:%0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d",
                    store_y,xPb,
                    store_buf[0],store_buf[1],
                    store_buf[2],store_buf[3],
                    store_buf[4],store_buf[5],
                    store_buf[6],store_buf[7],
                    store_buf[8],store_buf[9],
                    store_buf[10],store_buf[11],
                    store_buf[12],store_buf[13],
                    store_buf[14],store_buf[15]);
                $fdisplay(fd_log, "yc %0d xc %0d:%0d %0d %0d %0d %0d %0d %0d %0d",
                    store_y,xPb+16,
                    store_buf[16],store_buf[17],
                    store_buf[18],store_buf[19],
                    store_buf[20],store_buf[21],
                    store_buf[22],store_buf[23]);
            end else if (nPbW[6:1]==32) begin
                $fdisplay(fd_log, "yc %0d xc %0d:%0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d",
                    store_y,xPb,
                    store_buf[0],store_buf[1],
                    store_buf[2],store_buf[3],
                    store_buf[4],store_buf[5],
                    store_buf[6],store_buf[7],
                    store_buf[8],store_buf[9],
                    store_buf[10],store_buf[11],
                    store_buf[12],store_buf[13],
                    store_buf[14],store_buf[15]);
                $fdisplay(fd_log, "yc %0d xc %0d:%0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d",
                    store_y,xPb+16,
                    store_buf[16],store_buf[17],
                    store_buf[18],store_buf[19],
                    store_buf[20],store_buf[21],
                    store_buf[22],store_buf[23],
                    store_buf[24],store_buf[25],
                    store_buf[26],store_buf[27],
                    store_buf[28],store_buf[29],
                    store_buf[30],store_buf[31]);
            end



        end
        dram_pred_addrd             <= {32{store_y}};
        if (cond_one_row_done)
            o_pred_done_y           <= {1'b0,store_y};
        store_done                  <= 1;
        store_stage                 <= 2;
        if (store_y==yPb+nPbH[6:1]-1)
            o_inter_pred_done       <= 1;
    end

end else begin
    dram_pred_we                    <= 32'd0;
end


`ifdef RANDOM_INIT
integer  seed;
integer random_val;
initial  begin
    seed                               = $get_initial_random_seed(); 
    random_val                         = $random(seed);
    dram_pred_we                       = {random_val,random_val};
    dram_pred_addrd                    = {random_val[1:0],random_val[31:2],random_val[1:0],random_val[31:2]};
    dram_pred_did                      = {random_val[2:0],random_val[31:3],random_val[2:0],random_val[31:3]};
    o_pred_done_y                      = {random_val[3:0],random_val[31:4],random_val[3:0],random_val[31:4]};
    o_ref_start_y                      = {random_val[4:0],random_val[31:5],random_val[4:0],random_val[31:5]};
    o_ref_end_y                        = {random_val[5:0],random_val[31:6],random_val[5:0],random_val[31:6]};
    o_ref_start_x                      = {random_val[6:0],random_val[31:7],random_val[6:0],random_val[31:7]};
    o_ref_end_x                        = {random_val[7:0],random_val[31:8],random_val[7:0],random_val[31:8]};
    o_inter_pred_done                  = {random_val[8:0],random_val[31:9],random_val[8:0],random_val[31:9]};
    x0                                 = {random_val[9:0],random_val[31:10],random_val[9:0],random_val[31:10]};
    y0                                 = {random_val[10:0],random_val[31:11],random_val[10:0],random_val[31:11]};
    xPb                                = {random_val[11:0],random_val[31:12],random_val[11:0],random_val[31:12]};
    yPb                                = {random_val[12:0],random_val[31:13],random_val[12:0],random_val[31:13]};
    x_tmp                              = {random_val[13:0],random_val[31:14],random_val[13:0],random_val[31:14]};
    y_tmp                              = {random_val[14:0],random_val[31:15],random_val[14:0],random_val[31:15]};
    y                                  = {random_val[15:0],random_val[31:16],random_val[15:0],random_val[31:16]};
    y_fetch_save                       = {random_val[16:0],random_val[31:17],random_val[16:0],random_val[31:17]};
    ref_start_x_tmp                    = {random_val[17:0],random_val[31:18],random_val[17:0],random_val[31:18]};
    ref_start_y_tmp                    = {random_val[18:0],random_val[31:19],random_val[18:0],random_val[31:19]};
    ref_end_x_tmp                      = {random_val[19:0],random_val[31:20],random_val[19:0],random_val[31:20]};
    ref_end_y_tmp                      = {random_val[20:0],random_val[31:21],random_val[20:0],random_val[31:21]};
    nPbW                               = {random_val[21:0],random_val[31:22],random_val[21:0],random_val[31:22]};
    nPbH                               = {random_val[22:0],random_val[31:23],random_val[22:0],random_val[31:23]};
    CbSize                             = {random_val[23:0],random_val[31:24],random_val[23:0],random_val[31:24]};
    fetch_h                            = {random_val[24:0],random_val[31:25],random_val[24:0],random_val[31:25]};
    fetch_h_minus1                     = {random_val[25:0],random_val[31:26],random_val[25:0],random_val[31:26]};
    fetched_rows                       = {random_val[26:0],random_val[31:27],random_val[26:0],random_val[31:27]};
    in_bound_h                         = {random_val[27:0],random_val[31:28],random_val[27:0],random_val[31:28]};
    in_bound_w_cur                     = {random_val[28:0],random_val[31:29],random_val[28:0],random_val[31:29]};
    in_bound_h_cur                     = {random_val[29:0],random_val[31:30],random_val[29:0],random_val[31:30]};
    in_bound_h_cur                     = {random_val[30:0],random_val[31],random_val[30:0],random_val[31]};
    in_bound_h_cur                     = {random_val[31:0],random_val[31:0]};
    in_bound_h_cur                     = {random_val,random_val};
    in_bound_h_cur                     = {random_val[1:0],random_val[31:2],random_val[1:0],random_val[31:2]};
    pre_bound_w_cur                    = {random_val[2:0],random_val[31:3],random_val[2:0],random_val[31:3]};
    pre_bound_h_cur                    = {random_val[3:0],random_val[31:4],random_val[3:0],random_val[31:4]};
    exd_bound_w_cur                    = {random_val[4:0],random_val[31:5],random_val[4:0],random_val[31:5]};
    exd_bound_h_cur                    = {random_val[5:0],random_val[31:6],random_val[5:0],random_val[31:6]};
    x_frac                             = {random_val[6:0],random_val[31:7],random_val[6:0],random_val[31:7]};
    y_frac                             = {random_val[7:0],random_val[31:8],random_val[7:0],random_val[31:8]};
    stage                              = {random_val[8:0],random_val[31:9],random_val[8:0],random_val[31:9]};
    first_cycle_stg2                   = {random_val[9:0],random_val[31:10],random_val[9:0],random_val[31:10]};
    pic_width_minus1                   = {random_val[10:0],random_val[31:11],random_val[10:0],random_val[31:11]};
    pic_height_minus1                  = {random_val[11:0],random_val[31:12],random_val[11:0],random_val[31:12]};
    ver_buf                            = {random_val[12:0],random_val[31:13],random_val[12:0],random_val[31:13]};
    ver_buf_bk                         = {random_val[13:0],random_val[31:14],random_val[13:0],random_val[31:14]};
    i                                  = {random_val[14:0],random_val[31:15],random_val[14:0],random_val[31:15]};
    hor_buf                            = {random_val[15:0],random_val[31:16],random_val[15:0],random_val[31:16]};
    hor_buf_bk                         = {random_val[16:0],random_val[31:17],random_val[16:0],random_val[31:17]};
    inter_pred_type                    = {random_val[17:0],random_val[31:18],random_val[17:0],random_val[31:18]};
    first_byte                         = {random_val[18:0],random_val[31:19],random_val[18:0],random_val[31:19]};
    last_byte                          = {random_val[19:0],random_val[31:20],random_val[19:0],random_val[31:20]};
    interp_hor_done                    = {random_val[20:0],random_val[31:21],random_val[20:0],random_val[31:21]};
    interp_hor_pre_done                = {random_val[21:0],random_val[31:22],random_val[21:0],random_val[31:22]};
    interp_ver_done                    = {random_val[22:0],random_val[31:23],random_val[22:0],random_val[31:23]};
    interp_ver_pre_done                = {random_val[23:0],random_val[31:24],random_val[23:0],random_val[31:24]};
    interp_hv_done                     = {random_val[24:0],random_val[31:25],random_val[24:0],random_val[31:25]};
    interp_hv_pre_done                 = {random_val[25:0],random_val[31:26],random_val[25:0],random_val[31:26]};
    store_done                         = {random_val[26:0],random_val[31:27],random_val[26:0],random_val[31:27]};
    store_pre_done                     = {random_val[27:0],random_val[31:28],random_val[27:0],random_val[31:28]};
    rst_store_full                     = {random_val[28:0],random_val[31:29],random_val[28:0],random_val[31:29]};
    rst_store_hor                      = {random_val[29:0],random_val[31:30],random_val[29:0],random_val[31:30]};
    rst_store_ver                      = {random_val[30:0],random_val[31],random_val[30:0],random_val[31]};
    rst_store_hv                       = {random_val[31:0],random_val[31:0]};
    rst_interp_hor                     = {random_val,random_val};
    rst_interp_ver                     = {random_val[1:0],random_val[31:2],random_val[1:0],random_val[31:2]};
    rst_interp_hv                      = {random_val[2:0],random_val[31:3],random_val[2:0],random_val[31:3]};
    store_y                            = {random_val[3:0],random_val[31:4],random_val[3:0],random_val[31:4]};
    y_interp_hor                       = {random_val[4:0],random_val[31:5],random_val[4:0],random_val[31:5]};
    y_interp_ver                       = {random_val[5:0],random_val[31:6],random_val[5:0],random_val[31:6]};
    y_interp_hv                        = {random_val[6:0],random_val[31:7],random_val[6:0],random_val[31:7]};
    m_axi_arlen                        = {random_val[7:0],random_val[31:8],random_val[7:0],random_val[31:8]};
    interp_hor_i                       = {random_val[8:0],random_val[31:9],random_val[8:0],random_val[31:9]};
    interp_hor_i_max                   = {random_val[9:0],random_val[31:10],random_val[9:0],random_val[31:10]};
    interp_hor_i_d1                    = {random_val[10:0],random_val[31:11],random_val[10:0],random_val[31:11]};
    interp_hor_i_d2                    = {random_val[11:0],random_val[31:12],random_val[11:0],random_val[31:12]};
    interp_hor_valid                   = {random_val[12:0],random_val[31:13],random_val[12:0],random_val[31:13]};
    interp_hor_valid_d1                = {random_val[13:0],random_val[31:14],random_val[13:0],random_val[31:14]};
    interp_hor_valid_d2                = {random_val[14:0],random_val[31:15],random_val[14:0],random_val[31:15]};
    interp_hor_stage                   = {random_val[15:0],random_val[31:16],random_val[15:0],random_val[31:16]};
    interpolated_rows                  = {random_val[16:0],random_val[31:17],random_val[16:0],random_val[31:17]};
    interp_hor_clip                    = {random_val[17:0],random_val[31:18],random_val[17:0],random_val[31:18]};
    interp_hor                         = {random_val[18:0],random_val[31:19],random_val[18:0],random_val[31:19]};
    intermediate                       = {random_val[19:0],random_val[31:20],random_val[19:0],random_val[31:20]};
    intermediate_bk                    = {random_val[20:0],random_val[31:21],random_val[20:0],random_val[31:21]};
    interp_ver_i                       = {random_val[2:0],random_val[31:3],random_val[2:0],random_val[31:3]};
    interp_ver_i_max                   = {random_val[3:0],random_val[31:4],random_val[3:0],random_val[31:4]};
    interp_ver_i_d1                    = {random_val[4:0],random_val[31:5],random_val[4:0],random_val[31:5]};
    interp_ver_i_d2                    = {random_val[5:0],random_val[31:6],random_val[5:0],random_val[31:6]};
    interp_ver_valid                   = {random_val[6:0],random_val[31:7],random_val[6:0],random_val[31:7]};
    interp_ver_valid_d1                = {random_val[7:0],random_val[31:8],random_val[7:0],random_val[31:8]};
    interp_ver_valid_d2                = {random_val[8:0],random_val[31:9],random_val[8:0],random_val[31:9]};
    interp_ver_clip                    = {random_val[9:0],random_val[31:10],random_val[9:0],random_val[31:10]};
    interp_hv_i                        = {random_val[24:0],random_val[31:25],random_val[24:0],random_val[31:25]};
    interp_hv_i_max                    = {random_val[25:0],random_val[31:26],random_val[25:0],random_val[31:26]};
    interp_hv_i_d1                     = {random_val[26:0],random_val[31:27],random_val[26:0],random_val[31:27]};
    interp_hv_i_d2                     = {random_val[27:0],random_val[31:28],random_val[27:0],random_val[31:28]};
    interp_hv_valid                    = {random_val[28:0],random_val[31:29],random_val[28:0],random_val[31:29]};
    interp_hv_valid_d1                 = {random_val[29:0],random_val[31:30],random_val[29:0],random_val[31:30]};
    interp_hv_valid_d2                 = {random_val[30:0],random_val[31],random_val[30:0],random_val[31]};
    interp_hv_clip                     = {random_val[31:0],random_val[31:0]};
    store_buf                          = {random_val[14:0],random_val[31:15],random_val[14:0],random_val[31:15]};
    store_buf_tmp                      = {random_val[15:0],random_val[31:16],random_val[15:0],random_val[31:16]};
    store_stage                        = {random_val[16:0],random_val[31:17],random_val[16:0],random_val[31:17]};
    cond_one_row_done                  = {random_val[17:0],random_val[31:18],random_val[17:0],random_val[31:18]};
end
`endif


endmodule
