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

module inter_pred_luma
(
 input wire                          clk                      ,
 input wire                          rst                      ,
 input wire                          global_rst               ,
 input wire                          i_rst_slice              ,
 input wire                          en                       ,
 input wire             [15:0]       i_slice_num              ,
 input wire  [`max_x_bits-1:0]       i_x0                     ,
 input wire  [`max_y_bits-1:0]       i_y0                     ,
 input wire             [ 5:0]       i_xPb                    ,
 input wire             [ 5:0]       i_yPb                    ,
 input wire  [`max_x_bits-1:0]       i_PicWidthInSamplesY     ,
 input wire  [`max_y_bits-1:0]       i_PicHeightInSamplesY    ,

 input wire             [ 6:0]       i_nPbW                   ,
 input wire             [ 6:0]       i_nPbH                   ,
 input wire             [ 6:0]       i_CbSize                 ,

 input wire signed      [14:0]       i_mvx                    ,
 input wire signed      [14:0]       i_mvy                    ,
 input wire                          i_component              , //0=cb,1=cr

 output reg             [63:0]       dram_pred_we             ,
 output reg       [63:0][ 5:0]       dram_pred_addrd          ,
 output reg       [63:0][ 7:0]       dram_pred_did            ,

 output wire                         o_fifo_rd_en             ,
 input wire             [63:0]       i_fifo_data              ,
 input wire                          i_fifo_empty             ,

 input wire             [31:0]       fd_log                   ,

 output reg             [ 6:0]       o_pred_done_y            ,
 output reg  [`max_y_bits-1:0]       o_ref_start_y            ,
 output reg  [`max_y_bits-1:0]       o_ref_end_y              ,
 output reg  [`max_x_bits-1:0]       o_ref_start_x            ,
 output reg  [`max_x_bits-1:0]       o_ref_end_x              ,
 output reg                          o_inter_pred_done

);

parameter inter_pred_type_full = 2'b00;
parameter inter_pred_type_hor  = 2'b01; //利用横向7/8点插值
parameter inter_pred_type_ver  = 2'b10;
parameter inter_pred_type_hv   = 2'b11;


reg                    [ 5:0]        x0                    ;
reg                    [ 5:0]        y0                    ;
reg                    [ 5:0]        xPb                   ;
reg                    [ 5:0]        yPb                   ;
reg  signed            [15:0]        x_tmp                 ;
reg  signed            [15:0]        y_tmp                 ;
reg                    [ 5:0]        y                     ;


reg signed    [`max_x_bits:0]        ref_start_x_tmp       ;
reg signed    [`max_y_bits:0]        ref_start_y_tmp       ;
reg signed    [`max_x_bits:0]        ref_end_x_tmp         ;
reg signed    [`max_y_bits:0]        ref_end_y_tmp         ;

reg                    [ 6:0]        nPbW                  ;
reg                    [ 6:0]        nPbH                  ;
reg                    [ 6:0]        CbSize                ;

reg                    [ 6:0]        fetch_w               ;
reg                    [ 6:0]        fetch_h               ;
reg                    [ 6:0]        fetch_h_minus1        ;

reg                    [ 6:0]        fetched_rows          ;

reg                    [ 6:0]        in_bound_w            ;
reg                    [ 6:0]        in_bound_h            ;
reg                    [ 6:0]        pre_bound_w           ;//超出图像左边宽度
reg                    [ 6:0]        pre_bound_h           ;//超出图像上边高度
reg                    [ 6:0]        exd_bound_w           ;//超出图像右边宽度
reg                    [ 6:0]        exd_bound_h           ;//超出图像下边高度
reg                    [ 6:0]        in_bound_w_cur        ;
reg                    [ 6:0]        in_bound_h_cur        ;
reg                    [ 6:0]        pre_bound_w_cur       ;
reg                    [ 6:0]        pre_bound_h_cur       ;
reg                    [ 6:0]        exd_bound_w_cur       ;
reg                    [ 6:0]        exd_bound_h_cur       ;

reg                    [ 1:0]        x_frac                ;
reg                    [ 1:0]        y_frac                ;


reg                    [ 3:0]        stage                 ;
reg                                  first_cycle_stg2      ;

//          8行
reg        [ 7:0][63:0][ 7:0]        ver_buf               ;
reg        [ 7:0][63:0][ 7:0]        ver_buf_bk            ;

reg                    [ 3:0]        i                     ;
reg        [10:0][ 7:0][ 7:0]        hor_buf               ; //64+7=71,71+16
reg              [71:0][ 7:0]        hor_buf_bk            ;
reg                    [ 1:0]        inter_pred_type       ;
reg                    [ 7:0]        first_byte            ;
reg                    [ 7:0]        last_byte             ;
wire             [87:0][ 7:0]        hor_buf_w             ;
assign hor_buf_w = hor_buf;

reg                                  interp_hor_done       ;
reg                                  interp_hor_pre_done   ;
reg                                  interp_ver_done       ;
reg                                  interp_ver_pre_done   ;
reg                                  interp_hv_done        ; //inter_pred_type_hv先v再h的h interpolate完
reg                                  interp_hv_pre_done    ;
reg                                  store_done            ;
reg                                  store_pre_done        ;
reg                                  rst_store_full        ;
reg                                  rst_store_hor         ;
reg                                  rst_store_ver         ;
reg                                  rst_store_hv          ;
reg                                  rst_interp_hor        ;
reg                                  rst_interp_ver        ;
reg                                  rst_interp_hv         ;


wire signed   [`max_x_bits:0]        pic_width_signed      ;
wire signed   [`max_y_bits:0]        pic_height_signed     ;
reg         [`max_x_bits-1:0]        pic_width_minus1      ;
reg         [`max_y_bits-1:0]        pic_height_minus1     ;

assign pic_width_signed  = {1'b0,i_PicWidthInSamplesY};
assign pic_height_signed = {1'b0,i_PicHeightInSamplesY};

reg                    [ 5:0]        store_y               ;
reg                    [ 5:0]        y_interp_hor          ;
reg                    [ 5:0]        y_interp_ver          ;
reg                    [ 5:0]        y_interp_hv           ;
reg                    [ 5:0]        y_fetch_save          ;

reg                    [ 3:0]        m_axi_arlen           ;


assign o_fifo_rd_en = ~i_fifo_empty && (stage==1||(stage==2&&i!=m_axi_arlen)||stage==10||stage==11);


always @ (posedge clk)
if (global_rst||i_rst_slice) begin
    stage                       <= 8;
    rst_store_full              <= 0;
    rst_interp_hor              <= 0;
    rst_interp_ver              <= 0;
end else if (rst) begin
    y                           <= i_yPb;
    xPb                         <= i_xPb;
    yPb                         <= i_yPb;
    nPbW                        <= i_nPbW;
    nPbH                        <= i_nPbH;
    x0                          <= i_x0[5:0];
    y0                          <= i_y0[5:0];
    CbSize                      <= i_CbSize;

    y_fetch_save                <= i_yPb;
    pic_width_minus1            <= i_PicWidthInSamplesY-1;
    pic_height_minus1           <= i_PicHeightInSamplesY-1;


    rst_store_full              <= 0;
    rst_interp_hor              <= 0;
    rst_interp_ver              <= 0;

    fetched_rows                <= 0;


    x_frac                      <= i_mvx[1:0];
    y_frac                      <= i_mvy[1:0];

    if (i_mvx[1:0] && i_mvy[1:0]) begin
        inter_pred_type         <= inter_pred_type_hv;
    end else if (i_mvx[1:0]) begin
        inter_pred_type         <= inter_pred_type_hor;
    end else if (i_mvy[1:0]) begin
        inter_pred_type         <= inter_pred_type_ver;
    end else begin
        inter_pred_type         <= inter_pred_type_full;
    end

    if (i_mvx[1:0]) begin
        fetch_w                 <= i_nPbW+7;
    end else begin
        fetch_w                 <= i_nPbW;
    end

    if (i_mvx[1:0]) begin
        ref_start_x_tmp         <= {i_x0[`max_x_bits-1:6],i_xPb}+(i_mvx>>>2)-3;
        ref_end_x_tmp           <= {i_x0[`max_x_bits-1:6],i_xPb}+(i_mvx>>>2)+i_nPbW+3;
    end else begin
        ref_start_x_tmp         <= {i_x0[`max_x_bits-1:6],i_xPb}+(i_mvx>>>2);
        ref_end_x_tmp           <= {i_x0[`max_x_bits-1:6],i_xPb}+(i_mvx>>>2)+i_nPbW-1;
    end
    if (i_mvy[1:0]) begin
        ref_start_y_tmp         <= {i_y0[`max_y_bits-1:6],i_yPb}+(i_mvy>>>2)-3;
        ref_end_y_tmp           <= {i_y0[`max_y_bits-1:6],i_yPb}+(i_mvy>>>2)+i_nPbH+3;
        fetch_h                 <= i_nPbH+7;
        fetch_h_minus1          <= i_nPbH+6;
    end else begin
        ref_start_y_tmp         <= {i_y0[`max_y_bits-1:6],i_yPb}+(i_mvy>>>2);
        ref_end_y_tmp           <= {i_y0[`max_y_bits-1:6],i_yPb}+(i_mvy>>>2)+i_nPbH-1;
        fetch_h                 <= i_nPbH;
        fetch_h_minus1          <= i_nPbH-1;
    end

    stage                       <= 0;

    if (`log_p && i_slice_num>=`slice_begin && i_slice_num<=`slice_end) begin
        $fdisplay(fd_log, "luma_mc_uni x0 %0d y0 %0d width %0d height %0d mv %0d %0d slice_num %0d",
            {i_x0[`max_x_bits-1:6],i_xPb},{i_y0[`max_y_bits-1:6],i_yPb},
            i_nPbW, i_nPbH, i_mvx, i_mvy, i_slice_num);
        if (i_mvx[1:0]&&i_mvy[1:0])
            $fdisplay(fd_log, "qpel hv");
        else if (i_mvx[1:0])
            $fdisplay(fd_log, "qpel h");
        else if (i_mvy[1:0])
            $fdisplay(fd_log, "qpel v");
        else
            $fdisplay(fd_log, "pel full sample");
    end

end else if (en) begin
    if (stage == 0) begin
        if (ref_start_x_tmp >= pic_width_signed)
            o_ref_start_x       <= pic_width_minus1;
        else if (ref_start_x_tmp < 0)
            o_ref_start_x       <= 0;
        else
            o_ref_start_x       <= ref_start_x_tmp;

        if (ref_start_y_tmp >= pic_height_signed) begin
            o_ref_start_y       <= pic_height_minus1;
        end else if (ref_start_y_tmp < 0) begin
            o_ref_start_y       <= 0;
        end else begin
            o_ref_start_y       <= ref_start_y_tmp;
        end

        if (ref_end_x_tmp >= pic_width_signed)
            o_ref_end_x         <= pic_width_minus1;
        else if (ref_end_x_tmp < 0)
            o_ref_end_x         <= 0;
        else
            o_ref_end_x         <= ref_end_x_tmp;

        if (ref_end_y_tmp >= pic_height_signed)
            o_ref_end_y         <= pic_height_minus1;
        else if (ref_end_y_tmp < 0)
            o_ref_end_y         <= 0;
        else
            o_ref_end_y         <= ref_end_y_tmp;

        //不考虑ref_start_x<0,ref_end_x>pic_width_minus1
        if (ref_start_x_tmp<0&&ref_end_x_tmp<0) begin
            pre_bound_w         <= fetch_w;
            in_bound_w          <= 0;
            exd_bound_w         <= 0;
        end else if (ref_start_x_tmp<0) begin
            pre_bound_w         <= ~ref_start_x_tmp+1;
            in_bound_w          <= ref_end_x_tmp+1;
            exd_bound_w         <= 0;
        end else if (ref_start_x_tmp >= pic_width_signed &&
                     ref_end_x_tmp >= pic_width_signed) begin
            pre_bound_w         <= 0;
            in_bound_w          <= 0;
            exd_bound_w         <= fetch_w;
        end else if (ref_end_x_tmp >= pic_width_signed) begin //width=480,end=480,in width=0
            pre_bound_w         <= 0;
            in_bound_w          <= pic_width_signed-ref_start_x_tmp;
            exd_bound_w         <= ref_end_x_tmp-pic_width_signed+1;
        end else begin
            pre_bound_w         <= 0;
            in_bound_w          <= fetch_w;
            exd_bound_w         <= 0;
        end

        if (ref_start_y_tmp<0&&ref_end_y_tmp<0) begin
            pre_bound_h         <= fetch_h;
            in_bound_h          <= 0;
            exd_bound_h         <= 0;
        end else if (ref_start_y_tmp<0) begin
            pre_bound_h         <= ~ref_start_y_tmp+1;
            in_bound_h          <= ref_end_y_tmp+1;
            exd_bound_h         <= 0;
        end else if (ref_start_y_tmp >= pic_height_signed &&
                     ref_end_y_tmp >= pic_height_signed) begin
            pre_bound_h         <= 0;
            in_bound_h          <= 0;
            exd_bound_h         <= fetch_h;
        end else if (ref_end_y_tmp >= pic_height_signed) begin
            pre_bound_h         <= 0;
            in_bound_h          <= pic_height_signed-ref_start_y_tmp;
            exd_bound_h         <= ref_end_y_tmp-pic_height_signed+1;
        end else begin
            pre_bound_h         <= 0;
            in_bound_h          <= fetch_h;
            exd_bound_h         <= 0;
        end

        stage                   <= 1;

    end

    if (stage == 1 && ~i_fifo_empty) begin
        in_bound_h_cur          <= in_bound_h;
        exd_bound_h_cur         <= exd_bound_h;
        pre_bound_h_cur         <= pre_bound_h;
        in_bound_w_cur          <= in_bound_w;
        exd_bound_w_cur         <= exd_bound_w;
        pre_bound_w_cur         <= pre_bound_w;
        i                       <= 0;
        first_cycle_stg2        <= 1;

        rst_interp_hor          <= 0;
        rst_store_full          <= 0;
        rst_interp_ver          <= 0;
        m_axi_arlen             <= o_ref_end_x[`max_x_bits-1:3]-o_ref_start_x[`max_x_bits-1:3];
        stage                   <= 2;
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
            stage             <= 11;

    end

    if (stage==10) begin
        rst_store_full        <= 0;
        rst_interp_hor        <= 0;
        rst_interp_ver        <= 0;
    end
    if (stage==10&&~i_fifo_empty)
        stage                 <= 2;
    if (stage==11&&~i_fifo_empty)
        stage                 <= 2;


    if (stage==3) begin
        case (pre_bound_w_cur)
            1:hor_buf         <= {hor_buf_w[86:0],first_byte};
            2:hor_buf         <= {hor_buf_w[85:0],{2{first_byte}}};
            3:hor_buf         <= {hor_buf_w[84:0],{3{first_byte}}};
            4:hor_buf         <= {hor_buf_w[83:0],{4{first_byte}}};
            5:hor_buf         <= {hor_buf_w[82:0],{5{first_byte}}};
            6:hor_buf         <= {hor_buf_w[81:0],{6{first_byte}}};
            7:hor_buf         <= {hor_buf_w[80:0],{7{first_byte}}};
            default:hor_buf   <= {hor_buf_w[79:0],{8{first_byte}}};
        endcase

        pre_bound_w_cur       <= pre_bound_w_cur-8;
        if (pre_bound_w_cur<=8) begin

        end
        i                     <= i+1;
    end

    if (stage==4) begin
        case (o_ref_start_x[2:0])
            0:hor_buf         <= hor_buf;
            1:hor_buf         <= {8'd0,hor_buf_w[87:1]};
            2:hor_buf         <= {16'd0,hor_buf_w[87:2]};
            3:hor_buf         <= {24'd0,hor_buf_w[87:3]};
            4:hor_buf         <= {32'd0,hor_buf_w[87:4]};
            5:hor_buf         <= {40'd0,hor_buf_w[87:5]};
            6:hor_buf         <= {48'd0,hor_buf_w[87:6]};
            7:hor_buf         <= {56'd0,hor_buf_w[87:7]};
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

            pre_bound_w_cur              <= pre_bound_w;
            in_bound_w_cur               <= in_bound_w;
            exd_bound_w_cur              <= exd_bound_w;

            if (inter_pred_type==inter_pred_type_full||
                inter_pred_type==inter_pred_type_hor||
                fetched_rows>=7)
                y                        <= y+1;
            y_fetch_save                 <= y;

            if (inter_pred_type==inter_pred_type_ver)
                stage                    <= 6;
            else begin
                if (((inter_pred_type==inter_pred_type_hor||
                      inter_pred_type==inter_pred_type_hv)&& ~interp_hor_pre_done)||
                    (inter_pred_type==inter_pred_type_full&&
                     ~store_pre_done)) begin
                    stage                <= 7;
                end else begin
                    fetched_rows         <= fetched_rows+1;
                    stage                <= fetched_rows==fetch_h_minus1?8:
                                            (pre_bound_h_cur ||(exd_bound_h_cur&&in_bound_h_cur<=1)?9:10);

                    rst_store_full       <= inter_pred_type == inter_pred_type_full?1:0;
                    rst_interp_hor       <= inter_pred_type==inter_pred_type_hor||
                                       inter_pred_type==inter_pred_type_hv?1:0;
                    first_cycle_stg2     <= 1;

                    i                    <= 0;


                    if (pre_bound_h_cur) begin
                        pre_bound_h_cur  <= pre_bound_h_cur-1;
                    end else if (in_bound_h_cur) begin
                       in_bound_h_cur    <= in_bound_h_cur-1;
                    end else if (exd_bound_h_cur) begin
                        exd_bound_h_cur  <= exd_bound_h_cur-1;
                    end


                end
            end

    end

    if (stage==6) begin
        if (~interp_ver_pre_done) begin
            stage                    <= 7;
        end else begin
            rst_interp_ver           <= fetched_rows>=7?1:0; //走到这fetched_rows上面已经加1了
            first_cycle_stg2         <= 1;
            i                        <= 0;

            fetched_rows             <= fetched_rows+1;
            stage                    <= fetched_rows==fetch_h_minus1?8:
                                         (pre_bound_h_cur ||(exd_bound_h_cur&&in_bound_h_cur<=1)?9:10);

            if (pre_bound_h_cur) begin
                pre_bound_h_cur      <= pre_bound_h_cur-1;
            end else if (in_bound_h_cur) begin
               in_bound_h_cur        <= in_bound_h_cur-1;
            end else if (exd_bound_h_cur) begin
                exd_bound_h_cur      <= exd_bound_h_cur-1;
            end

        end
        ver_buf                      <= {hor_buf[7:0],ver_buf[7:1]};
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
                                       fetched_rows>=7 ? 1:0;
            rst_store_full          <= inter_pred_type==inter_pred_type_full&&
                                       store_pre_done;
            fetched_rows            <= fetched_rows+1;
            stage                   <= fetched_rows==fetch_h_minus1?8:
                                         (pre_bound_h_cur ||(exd_bound_h_cur&&in_bound_h_cur<=1)?9:10);
            first_cycle_stg2        <= 1;

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

    if (stage == 8) begin //end
        rst_store_full              <= 0;
        rst_interp_hor              <= 0;
        rst_interp_ver              <= 0;
    end

    //pre_bound_h_cur>0,exd_bound_h_cur>0复用已取的行
    if (stage ==9) begin
        rst_store_full              <= 0;
        rst_interp_hor              <= 0;
        rst_interp_ver              <= 0;

        if (inter_pred_type==inter_pred_type_full||
            inter_pred_type==inter_pred_type_hor||
            fetched_rows>=7)
            y                       <= y+1;
        y_fetch_save                <= y;

        stage                       <= inter_pred_type==inter_pred_type_ver?6:7;

    end




end

reg         [ 3:0]          interp_hor_i                 ;
reg         [ 3:0]          interp_hor_i_max             ;
reg         [ 3:0]          interp_hor_i_d1              ;
reg         [ 3:0]          interp_hor_i_d2              ;

reg                         interp_hor_valid             ;
reg                         interp_hor_valid_d1          ;
reg                         interp_hor_valid_d2          ;
reg                         interp_hor_stage             ;

reg         [ 6:0]          interpolated_rows            ;
wire signed [ 9:0]          interp_hor_weighted_w[7:0]   ;

wire signed [7:0][7:0]      interp_hor_clip_w            ;
reg  signed [7:0][7:0][7:0] interp_hor_clip              ;

wire signed [7:0][15:0]      interp_hor_w                ;
//Cannot assign an unpacked type 'wire signed[15:0] $[7:0]' to a packed type 'reg[15:0][7:0]'.
reg  signed [7:0][15:0]      interp_hor                  ;

//Illegal unpacked array concatenation. The number of elements (57) doesn't match with the type's width (64).
reg signed [7:0][7:0][7:0][15:0] intermediate            ;
reg signed     [7:0][63:0][15:0] intermediate_bk         ;

reg  signed      [12:0]     interp_hor_tmp_b0[7:0]       ;
wire signed      [12:0]     interp_hor_tmp_b0_w[7:0]     ;
reg  signed      [14:0]     interp_hor_tmp_b1[7:0]       ;
wire signed      [14:0]     interp_hor_tmp_b1_w[7:0]     ;
reg  signed      [13:0]     interp_hor_tmp_b2[7:0]       ;
wire signed      [13:0]     interp_hor_tmp_b2_w[7:0]     ;
reg  signed      [15:0]     interp_hor_tmp_c0[7:0]       ;
wire signed      [15:0]     interp_hor_tmp_c0_w[7:0]     ;
reg  signed      [13:0]     interp_hor_tmp_d0[7:0]       ;
wire signed      [13:0]     interp_hor_tmp_d0_w[7:0]     ;
reg  signed      [14:0]     interp_hor_tmp_d1[7:0]       ;
wire signed      [14:0]     interp_hor_tmp_d1_w[7:0]     ;
reg  signed      [12:0]     interp_hor_tmp_d2[7:0]       ;
wire signed      [12:0]     interp_hor_tmp_d2_w[7:0]     ;
//a3+a4
wire signed      [ 9:0]     interp_hor_tmp_e_w[7:0]      ;


genvar I;

// a0  a1  a2  a3  a4  a5  a6  a7
//{-1,  4,-10, 58, 17, -5,  1,  0, }, 58=64-4-2
//{-1,  4,-11, 40, 40,-11,  4, -1, },
//{ 0,  1, -5, 17, 58,-10,  4, -1, }
//-a0 +4*a1-10*a2 = b0 4个加, 58*a3+a6 =b1  3个加, 17*a4-5*a5=b2 3个加,   第二步 b0+b1+b2 2个加
//(a3+a4)*32+(a3+a4)*8 -a2-a5 =c0   4个加                                 第二步  b0+c0+d2 2个加
//17*a3-5*a2 =d0 3个加，58*a4+a1=d1 3个加，   -10*a5+4*a6-a7=d2 3个加     第二步 d0+d1+d2 2个加

generate
    for (I=0;I<8;I++)
    begin: interp_hor_tmp_label
        assign interp_hor_tmp_b0_w[I] = {hor_buf_bk[I+1],2'd0}- hor_buf_bk[I]-{hor_buf_bk[I+2],3'd0}-{hor_buf_bk[I+2],1'd0};
        assign interp_hor_tmp_b1_w[I] = {hor_buf_bk[I+3],6'd0}-{hor_buf_bk[I+3],2'd0}-{hor_buf_bk[I+3],1'd0}+{hor_buf_bk[I+6]};
        assign interp_hor_tmp_b2_w[I] = {hor_buf_bk[I+4],4'd0}+hor_buf_bk[I+4]-{hor_buf_bk[I+5],2'd0}-hor_buf_bk[I+5];
        assign interp_hor_tmp_e_w[I]  = hor_buf_bk[I+3]+hor_buf_bk[I+4];
        assign interp_hor_tmp_c0_w[I] = (interp_hor_tmp_e_w[I]<<<5)+(interp_hor_tmp_e_w[I]<<<3)-hor_buf_bk[I+2]-hor_buf_bk[I+5];
        assign interp_hor_tmp_d0_w[I] = {hor_buf_bk[I+3],4'd0}+hor_buf_bk[I+3]-{hor_buf_bk[I+2],2'd0}-hor_buf_bk[I+2];
        assign interp_hor_tmp_d1_w[I] = {hor_buf_bk[I+4],6'd0}-{hor_buf_bk[I+4],2'd0}-{hor_buf_bk[I+4],1'd0}+hor_buf_bk[I+1];
        assign interp_hor_tmp_d2_w[I] = {hor_buf_bk[I+6],2'd0}- hor_buf_bk[I+7]-{hor_buf_bk[I+5],3'd0}-{hor_buf_bk[I+5],1'd0};
    end
endgenerate

generate
    for (I=0;I<8;I++)
    begin: interpolate_hor_label
        assign interp_hor_w[I] = x_frac==1?interp_hor_tmp_b0[I]+interp_hor_tmp_b1[I]+interp_hor_tmp_b2[I]:
                                  (x_frac==2?interp_hor_tmp_b0[I]+interp_hor_tmp_c0[I]+interp_hor_tmp_d2[I]:
                                             interp_hor_tmp_d0[I]+interp_hor_tmp_d1[I]+interp_hor_tmp_d2[I]);

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
    if (i_nPbW[2])
        interp_hor_i_max       <= i_nPbW[6:3];
    else
        interp_hor_i_max       <= i_nPbW[6:3]-1;
end else if (rst_interp_hor) begin
    interp_hor_done            <= 0;
    interp_hor_pre_done        <= 0;
    rst_store_hor              <= 0;
    rst_interp_hv              <= 0;
    interpolated_rows          <= interpolated_rows+1;
    y_interp_hor               <= y_fetch_save;
    hor_buf_bk                 <= hor_buf[8:0];
    intermediate               <= {1024'd0,intermediate[7:1]};

    interp_hor_i               <= 0;
    interp_hor_i_d1            <= 4'b1111;
    interp_hor_i_d2            <= 4'b1111;
    interp_hor_valid           <= 0;
    interp_hor_valid_d1        <= 0;
    interp_hor_valid_d2        <= 0;

end else if (interp_hor_done==0)begin
    //pipeline stage 0
    hor_buf_bk                 <= {64'd0,hor_buf_bk[71:8]};
    interp_hor_i               <= interp_hor_i+1;
    interp_hor_valid           <= 1;

    interp_hor_tmp_b0          <= interp_hor_tmp_b0_w;
    interp_hor_tmp_b1          <= interp_hor_tmp_b1_w;
    interp_hor_tmp_b2          <= interp_hor_tmp_b2_w;
    interp_hor_tmp_c0          <= interp_hor_tmp_c0_w;
    interp_hor_tmp_d0          <= interp_hor_tmp_d0_w;
    interp_hor_tmp_d1          <= interp_hor_tmp_d1_w;
    interp_hor_tmp_d2          <= interp_hor_tmp_d2_w;


    //pipeline stage 1
    interp_hor_i_d1            <= interp_hor_i;
    interp_hor_valid_d1        <= interp_hor_valid;
    interp_hor                 <= interp_hor_w;

    //pipeline stage 2
    interp_hor_i_d2            <= interp_hor_i_d1;
    interp_hor_valid_d2        <= interp_hor_valid_d1;
    if (interp_hor_valid_d1) begin
        interp_hor_clip        <= {interp_hor_clip_w,interp_hor_clip[7:1]};

        //Cannot assign an unpacked type 'concat' to a packed type 'reg[15:0][63:0]'.
        intermediate[7][interp_hor_i_d2]   <= interp_hor;
    end

    if (interp_hor_i_d1==interp_hor_i_max)
        interp_hor_pre_done    <= 1;

    if (interp_hor_i_d2==interp_hor_i_max) begin
        interp_hor_done        <= 1;
        if (inter_pred_type==inter_pred_type_hor) begin
            rst_store_hor      <= 1;
            interp_hor_stage   <= 0;
            if (~store_pre_done)
                  $display("%t possible?interp hor need wait store_pred_done",$time);
        end else if (inter_pred_type==inter_pred_type_hv&&
                 interpolated_rows>=8) begin
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
            interpolated_rows>=8&&interp_hv_pre_done) begin
            rst_interp_hv      <= 1;
            interp_hor_stage   <= 0;
        end
    end


end


reg             [ 3:0]      interp_ver_i                 ;
reg             [ 3:0]      interp_ver_i_max             ;
reg             [ 3:0]      interp_ver_i_d1              ;
reg             [ 3:0]      interp_ver_i_d2              ;

reg                         interp_ver_valid             ;
reg                         interp_ver_valid_d1          ;
reg                         interp_ver_valid_d2          ;


wire signed      [ 9:0]     interp_ver_weighted_w[7:0]   ;
wire signed [ 7:0][7:0]     interp_ver_clip_w            ;
reg  signed [63:0][7:0]     interp_ver_clip              ;

wire signed      [15:0]     interp_ver_w[7:0]            ;
reg  signed      [15:0]     interp_ver[7:0]              ;

reg  signed      [12:0]     interp_ver_tmp_b0[7:0]       ;
wire signed      [12:0]     interp_ver_tmp_b0_w[7:0]     ;
reg  signed      [14:0]     interp_ver_tmp_b1[7:0]       ;
wire signed      [14:0]     interp_ver_tmp_b1_w[7:0]     ;
reg  signed      [13:0]     interp_ver_tmp_b2[7:0]       ;
wire signed      [13:0]     interp_ver_tmp_b2_w[7:0]     ;
reg  signed      [15:0]     interp_ver_tmp_c0[7:0]       ;
wire signed      [15:0]     interp_ver_tmp_c0_w[7:0]     ;
reg  signed      [13:0]     interp_ver_tmp_d0[7:0]       ;
wire signed      [13:0]     interp_ver_tmp_d0_w[7:0]     ;
reg  signed      [14:0]     interp_ver_tmp_d1[7:0]       ;
wire signed      [14:0]     interp_ver_tmp_d1_w[7:0]     ;
reg  signed      [12:0]     interp_ver_tmp_d2[7:0]       ;
wire signed      [12:0]     interp_ver_tmp_d2_w[7:0]     ;
//a3+a4
wire signed      [9:0]      interp_ver_tmp_e_w[7:0]      ;
generate
    for (I=0;I<8;I++)
    begin: interp_ver_tmp_label
        assign interp_ver_tmp_b0_w[I] = {ver_buf_bk[1][I],2'd0}- ver_buf_bk[0][I]-{ver_buf_bk[2][I],3'd0}-{ver_buf_bk[2][I],1'd0};
        assign interp_ver_tmp_b1_w[I] = {ver_buf_bk[3][I],6'd0}-{ver_buf_bk[3][I],2'd0}-{ver_buf_bk[3][I],1'd0}+{ver_buf_bk[6][I]};
        assign interp_ver_tmp_b2_w[I] = {ver_buf_bk[4][I],4'd0}+ver_buf_bk[4][I]-{ver_buf_bk[5][I],2'd0}-ver_buf_bk[5][I];
        assign interp_ver_tmp_e_w[I]  = ver_buf_bk[3][I]+ver_buf_bk[4][I];
        assign interp_ver_tmp_c0_w[I] = (interp_ver_tmp_e_w[I]<<<5)+(interp_ver_tmp_e_w[I]<<<3)-ver_buf_bk[2][I]-ver_buf_bk[5][I];
        assign interp_ver_tmp_d0_w[I] = {ver_buf_bk[3][I],4'd0}+ver_buf_bk[3][I]-{ver_buf_bk[2][I],2'd0}-ver_buf_bk[2][I];
        assign interp_ver_tmp_d1_w[I] = {ver_buf_bk[4][I],6'd0}-{ver_buf_bk[4][I],2'd0}-{ver_buf_bk[4][I],1'd0}+{ver_buf_bk[1][I]};
        assign interp_ver_tmp_d2_w[I] = {ver_buf_bk[6][I],2'd0}- ver_buf_bk[7][I]-{ver_buf_bk[5][I],3'd0}-{ver_buf_bk[5][I],1'd0};

    end
endgenerate

generate
    for (I=0;I<8;I++)
    begin: interpolate_ver_label
        assign interp_ver_w[I] = y_frac==1?interp_ver_tmp_b0[I]+interp_ver_tmp_b1[I]+interp_ver_tmp_b2[I]:
                                  (y_frac==2?interp_ver_tmp_b0[I]+interp_ver_tmp_c0[I]+interp_ver_tmp_d2[I]:
                                             interp_ver_tmp_d0[I]+interp_ver_tmp_d1[I]+interp_ver_tmp_d2[I]);


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
    if (i_nPbW[2])
        interp_ver_i_max       <= i_nPbW[6:3];
    else
        interp_ver_i_max       <= i_nPbW[6:3]-1;
end else if (rst_interp_ver) begin
    interp_ver_done            <= 0;
    interp_ver_pre_done        <= 0;
    rst_store_ver              <= 0;
    y_interp_ver               <= y_fetch_save;
    ver_buf_bk                 <= ver_buf;

    interp_ver_i               <= 0;
    interp_ver_i_d1            <= 4'b1111;
    interp_ver_i_d2            <= 4'b1111;
    interp_ver_valid           <= 0;
    interp_ver_valid_d1        <= 0;
    interp_ver_valid_d2        <= 0;
end else if (~interp_ver_done) begin

    //pipeline stage 0
    ver_buf_bk[0]              <= {64'd0,ver_buf_bk[0][63:8]};
    ver_buf_bk[1]              <= {64'd0,ver_buf_bk[1][63:8]};
    ver_buf_bk[2]              <= {64'd0,ver_buf_bk[2][63:8]};
    ver_buf_bk[3]              <= {64'd0,ver_buf_bk[3][63:8]};
    ver_buf_bk[4]              <= {64'd0,ver_buf_bk[4][63:8]};
    ver_buf_bk[5]              <= {64'd0,ver_buf_bk[5][63:8]};
    ver_buf_bk[6]              <= {64'd0,ver_buf_bk[6][63:8]};
    ver_buf_bk[7]              <= {64'd0,ver_buf_bk[7][63:8]};
    interp_ver_i               <= interp_ver_i+1;
    interp_ver_valid           <= 1;

    interp_ver_tmp_b0          <= interp_ver_tmp_b0_w;
    interp_ver_tmp_b1          <= interp_ver_tmp_b1_w;
    interp_ver_tmp_b2          <= interp_ver_tmp_b2_w;
    interp_ver_tmp_c0          <= interp_ver_tmp_c0_w;
    interp_ver_tmp_d0          <= interp_ver_tmp_d0_w;
    interp_ver_tmp_d1          <= interp_ver_tmp_d1_w;
    interp_ver_tmp_d2          <= interp_ver_tmp_d2_w;

    //pipeline stage 1
    interp_ver_i_d1            <= interp_ver_i;
    interp_ver_valid_d1        <= interp_ver_valid;
    interp_ver                 <= interp_ver_w;

    //pipeline stage 2
    interp_ver_i_d2            <= interp_ver_i_d1;
    interp_ver_valid_d2        <= interp_ver_valid_d1;
    if (interp_ver_valid_d1) begin
        interp_ver_clip        <= {interp_ver_clip_w,interp_ver_clip[63:8]};
    end

    if (interp_ver_i_d1==interp_ver_i_max)
        interp_ver_pre_done    <= 1;

    if (interp_ver_i_d2==interp_ver_i_max) begin
        interp_ver_done        <= 1;
        rst_store_ver          <= 1;
        if (~store_pre_done)
            $display("%t possible? interp ver need wait store_pred_done",$time);
    end

end else begin
    rst_store_ver              <= 0;
end


reg             [ 3:0]      interp_hv_i                 ;
reg             [ 3:0]      interp_hv_i_max             ;
reg             [ 3:0]      interp_hv_i_d1              ;
reg             [ 3:0]      interp_hv_i_d2              ;

reg                         interp_hv_valid             ;
reg                         interp_hv_valid_d1          ;
reg                         interp_hv_valid_d2          ;

wire signed      [ 9:0]     interp_hv_weighted_w[7:0]   ;

wire signed      [ 7:0][ 7:0]     interp_hv_clip_w       ;
reg  signed      [63:0][ 7:0]     interp_hv_clip         ;


wire signed      [21:0]     interp_hv_w[7:0]            ;
reg  signed      [21:0]     interp_hv[7:0]              ;

reg  signed      [19:0]     interp_hv_tmp_b0[7:0]       ;
wire signed      [19:0]     interp_hv_tmp_b0_w[7:0]     ;
reg  signed      [21:0]     interp_hv_tmp_b1[7:0]       ;
wire signed      [21:0]     interp_hv_tmp_b1_w[7:0]     ;
reg  signed      [20:0]     interp_hv_tmp_b2[7:0]       ;
wire signed      [20:0]     interp_hv_tmp_b2_w[7:0]     ;
reg  signed      [22:0]     interp_hv_tmp_c0[7:0]       ;
wire signed      [22:0]     interp_hv_tmp_c0_w[7:0]     ;
reg  signed      [20:0]     interp_hv_tmp_d0[7:0]       ;
wire signed      [20:0]     interp_hv_tmp_d0_w[7:0]     ;
reg  signed      [21:0]     interp_hv_tmp_d1[7:0]       ;
wire signed      [21:0]     interp_hv_tmp_d1_w[7:0]     ;
reg  signed      [19:0]     interp_hv_tmp_d2[7:0]       ;
wire signed      [19:0]     interp_hv_tmp_d2_w[7:0]     ;
//a3+a4
wire signed      [17:0]      interp_hv_tmp_e_w[7:0]      ;
generate
    for (I=0;I<8;I++)
    begin: interp_hv_tmp_label
        assign interp_hv_tmp_b0_w[I] = (intermediate_bk[1][I]<<<2)- intermediate_bk[0][I]-(intermediate_bk[2][I]<<<3)-(intermediate_bk[2][I]<<<1);
        assign interp_hv_tmp_b1_w[I] = (intermediate_bk[3][I]<<<6)-(intermediate_bk[3][I]<<<2)-(intermediate_bk[3][I]<<<1)+intermediate_bk[6][I];
        assign interp_hv_tmp_b2_w[I] = (intermediate_bk[4][I]<<<4)+intermediate_bk[4][I]-(intermediate_bk[5][I]<<<2)-intermediate_bk[5][I];
        assign interp_hv_tmp_e_w[I]  = intermediate_bk[3][I]+intermediate_bk[4][I];
        assign interp_hv_tmp_c0_w[I] = (interp_hv_tmp_e_w[I]<<<5)+(interp_hv_tmp_e_w[I]<<<3)-intermediate_bk[2][I]-intermediate_bk[5][I];
        assign interp_hv_tmp_d0_w[I] = (intermediate_bk[3][I]<<<4)+intermediate_bk[3][I]-(intermediate_bk[2][I]<<<2)-intermediate_bk[2][I];
        assign interp_hv_tmp_d1_w[I] = (intermediate_bk[4][I]<<<6)-(intermediate_bk[4][I]<<<2)-(intermediate_bk[4][I]<<<1)+intermediate_bk[1][I];
        assign interp_hv_tmp_d2_w[I] = (intermediate_bk[6][I]<<<2)- intermediate_bk[7][I]-(intermediate_bk[5][I]<<<3)-(intermediate_bk[5][I]<<<1);
    end
endgenerate

generate
    for (I=0;I<8;I++)
    begin: interpolate_hv_label
        assign interp_hv_w[I] = y_frac==1?interp_hv_tmp_b0[I]+interp_hv_tmp_b1[I]+interp_hv_tmp_b2[I]:
                                  (y_frac==2?interp_hv_tmp_b0[I]+interp_hv_tmp_c0[I]+interp_hv_tmp_d2[I]:
                                             interp_hv_tmp_d0[I]+interp_hv_tmp_d1[I]+interp_hv_tmp_d2[I]);


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
                                      (interp_hv_weighted_w[I][8]?255:interp_hv_weighted_w[I][7:0]);

    end
endgenerate


always @(posedge clk)
if (global_rst||i_rst_slice) begin
    interp_hv_done            <= 1;
    rst_store_hv              <= 0;
end else if (rst) begin
    interp_hv_done            <= 1;
    interp_hv_pre_done        <= 1;
    if (i_nPbW[2])
        interp_hv_i_max       <= i_nPbW[6:3];
    else
        interp_hv_i_max       <= i_nPbW[6:3]-1;
end else if (rst_interp_hv) begin
    interp_hv_done            <= 0;
    interp_hv_pre_done        <= 0;
    rst_store_hv              <= 0;
    y_interp_hv               <= y_interp_hor;
    intermediate_bk           <= intermediate;

    interp_hv_i               <= 0;
    interp_hv_i_d1            <= 4'b1111;
    interp_hv_i_d2            <= 4'b1111;
    interp_hv_valid           <= 0;
    interp_hv_valid_d1        <= 0;
    interp_hv_valid_d2        <= 0;
end else if (~interp_hv_done) begin


    //pipeline stage 0
    intermediate_bk[0]        <= {128'd0,intermediate_bk[0][63:8]};
    intermediate_bk[1]        <= {128'd0,intermediate_bk[1][63:8]};
    intermediate_bk[2]        <= {128'd0,intermediate_bk[2][63:8]};
    intermediate_bk[3]        <= {128'd0,intermediate_bk[3][63:8]};
    intermediate_bk[4]        <= {128'd0,intermediate_bk[4][63:8]};
    intermediate_bk[5]        <= {128'd0,intermediate_bk[5][63:8]};
    intermediate_bk[6]        <= {128'd0,intermediate_bk[6][63:8]};
    intermediate_bk[7]        <= {128'd0,intermediate_bk[7][63:8]};
    interp_hv_i               <= interp_hv_i+1;
    interp_hv_valid           <= 1;

    interp_hv_tmp_b0          <= interp_hv_tmp_b0_w;
    interp_hv_tmp_b1          <= interp_hv_tmp_b1_w;
    interp_hv_tmp_b2          <= interp_hv_tmp_b2_w;
    interp_hv_tmp_c0          <= interp_hv_tmp_c0_w;
    interp_hv_tmp_d0          <= interp_hv_tmp_d0_w;
    interp_hv_tmp_d1          <= interp_hv_tmp_d1_w;
    interp_hv_tmp_d2          <= interp_hv_tmp_d2_w;

    //pipeline stage 1
    interp_hv_i_d1            <= interp_hv_i;
    interp_hv_valid_d1        <= interp_hv_valid;
    interp_hv                 <= interp_hv_w;

    //pipeline stage 2
    interp_hv_i_d2            <= interp_hv_i_d1;
    interp_hv_valid_d2        <= interp_hv_valid_d1;
    if (interp_hv_valid_d1) begin
        interp_hv_clip        <= {interp_hv_clip_w,interp_hv_clip[63:8]};
    end

    if (interp_hv_i_d1==interp_hv_i_max)
       interp_hv_pre_done     <= 1;

    if (interp_hv_i_d2==interp_hv_i_max) begin
        if (~store_pre_done)
            $display("%t possible? interp hv need wait store_pred_done",$time);
        interp_hv_done        <= 1;
        rst_store_hv          <= 1;
    end

end else begin
    rst_store_hv              <= 0;
end



reg    [63:0][ 7:0]     store_buf;
reg    [63:0][ 7:0]     store_buf_tmp;
reg          [ 1:0]     store_stage;
reg                     cond_one_row_done; //1个cu左右2个pu，右边pu完成o_pred_done_y才更新

always @ (posedge clk)
if (global_rst||i_rst_slice) begin
    o_pred_done_y                   <= 7'b1111111;
    dram_pred_we                    <= {64{1'b0}};
    o_inter_pred_done               <= 1;
    store_done                      <= 1;
end else if (rst) begin
    store_done                      <= 1;
    store_pre_done                  <= 1;
    store_y                         <= i_yPb;
    o_pred_done_y                   <= 7'b1111111;
    o_inter_pred_done               <= 0;
    dram_pred_we                    <= {64{1'b0}};
end else if (rst_store_full||rst_store_ver||
             rst_store_hor||rst_store_hv) begin
    store_stage                     <= 0;
    store_done                      <= 0;
    store_pre_done                  <= 0;

    if (inter_pred_type == inter_pred_type_full) begin
        store_y                     <= y_fetch_save;
        store_buf_tmp               <= hor_buf[7:0];
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
    //CU 64x64:64,32,16,48
    //CU 32x32:32,16,8,24
    //CU 16x16:16,8,4,12
    if (store_stage == 0) begin
        if (inter_pred_type == inter_pred_type_full) begin
            store_buf               <= store_buf_tmp;
        end else begin
            //nPbW=4,interploate时移入了8字节
            //high                                          low
            //| 4无效字节 | 4有效字节|     56                  |
            case (nPbW)
                4:store_buf         <= {{60{8'd0}},store_buf_tmp[59:56]};
                8:store_buf         <= {{56{8'd0}},store_buf_tmp[63:56]};
                12:store_buf        <= {{52{8'd0}},store_buf_tmp[59:48]};
                16:store_buf        <= {{48{8'd0}},store_buf_tmp[63:48]};
                24:store_buf        <= {{40{8'd0}},store_buf_tmp[63:40]};
                32:store_buf        <= {{32{8'd0}},store_buf_tmp[63:32]};
                48:store_buf        <= {{16{8'd0}},store_buf_tmp[63:16]};
                default:store_buf   <= store_buf_tmp; //64
            endcase
        end

        cond_one_row_done           <= xPb+nPbW == x0+CbSize;
        store_pre_done              <= 1;
        store_stage                 <= 1;
    end

    if (store_stage==1) begin
        case (xPb[5:2])
            0: dram_pred_did        <= store_buf;
            1: dram_pred_did        <= {store_buf[59:0],{4{8'd0}}};
            2: dram_pred_did        <= {store_buf[55:0],{8{8'd0}}};
            3: dram_pred_did        <= {store_buf[51:0],{12{8'd0}}};
            4: dram_pred_did        <= {store_buf[47:0],{16{8'd0}}};
            5: dram_pred_did        <= {store_buf[43:0],{20{8'd0}}};
            6: dram_pred_did        <= {store_buf[39:0],{24{8'd0}}};
            7: dram_pred_did        <= {store_buf[35:0],{28{8'd0}}};
            8: dram_pred_did        <= {store_buf[31:0],{32{8'd0}}};
            9: dram_pred_did        <= {store_buf[27:0],{36{8'd0}}};
            10:dram_pred_did        <= {store_buf[23:0],{40{8'd0}}};
            11:dram_pred_did        <= {store_buf[19:0],{44{8'd0}}};
            12:dram_pred_did        <= {store_buf[15:0],{48{8'd0}}};
            13:dram_pred_did        <= {store_buf[11:0],{52{8'd0}}};
            14:dram_pred_did        <= {store_buf[7:0],{56{8'd0}}};
            15:dram_pred_did        <= {store_buf[3:0],{60{8'd0}}};
        endcase
        case (xPb[5:2])
            0: dram_pred_we         <= {64{1'b1}};
            1: dram_pred_we         <= {{60{1'b1}},4'd0};
            2: dram_pred_we         <= {{56{1'b1}},8'd0};
            3: dram_pred_we         <= {{52{1'b1}},12'd0};
            4: dram_pred_we         <= {{48{1'b1}},16'd0};
            5: dram_pred_we         <= {{44{1'b1}},20'd0};
            6: dram_pred_we         <= {{40{1'b1}},24'd0};
            7: dram_pred_we         <= {{36{1'b1}},28'd0};
            8: dram_pred_we         <= {{32{1'b1}},32'd0};
            9: dram_pred_we         <= {{28{1'b1}},36'd0};
            10:dram_pred_we         <= {{24{1'b1}},40'd0};
            11:dram_pred_we         <= {{20{1'b1}},44'd0};
            12:dram_pred_we         <= {{16{1'b1}},48'd0};
            13:dram_pred_we         <= {{12{1'b1}},52'd0};
            14:dram_pred_we         <= {{8{1'b1}},56'd0};
            15:dram_pred_we         <= {{4{1'b1}},60'd0};
        endcase

        if (`log_p && i_slice_num>=`slice_begin && i_slice_num<=`slice_end) begin

            if (nPbW==4)
                $fdisplay(fd_log, "yL %0d xL %0d:%0d %0d %0d %0d",
                    store_y,xPb,
                    store_buf[0],store_buf[1],
                    store_buf[2],store_buf[3]);
            else if (nPbW==8)
                $fdisplay(fd_log, "yL %0d xL %0d:%0d %0d %0d %0d %0d %0d %0d %0d",
                    store_y,xPb,
                    store_buf[0],store_buf[1],
                    store_buf[2],store_buf[3],
                    store_buf[4],store_buf[5],
                    store_buf[6],store_buf[7]);
            else if (nPbW==12)
                $fdisplay(fd_log, "yL %0d xL %0d:%0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d",
                    store_y,xPb,
                    store_buf[0],store_buf[1],
                    store_buf[2],store_buf[3],
                    store_buf[4],store_buf[5],
                    store_buf[6],store_buf[7],
                    store_buf[8],store_buf[9],
                    store_buf[10],store_buf[11]);
            else if (nPbW==16)
                $fdisplay(fd_log, "yL %0d xL %0d:%0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d",
                    store_y,xPb,
                    store_buf[0],store_buf[1],
                    store_buf[2],store_buf[3],
                    store_buf[4],store_buf[5],
                    store_buf[6],store_buf[7],
                    store_buf[8],store_buf[9],
                    store_buf[10],store_buf[11],
                    store_buf[12],store_buf[13],
                    store_buf[14],store_buf[15]);
            else if (nPbW==24) begin
                $fdisplay(fd_log, "yL %0d xL %0d:%0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d",
                    store_y,xPb,
                    store_buf[0],store_buf[1],
                    store_buf[2],store_buf[3],
                    store_buf[4],store_buf[5],
                    store_buf[6],store_buf[7],
                    store_buf[8],store_buf[9],
                    store_buf[10],store_buf[11],
                    store_buf[12],store_buf[13],
                    store_buf[14],store_buf[15]);
                $fdisplay(fd_log, "yL %0d xL %0d:%0d %0d %0d %0d %0d %0d %0d %0d",
                    store_y,xPb+16,
                    store_buf[16],store_buf[17],
                    store_buf[18],store_buf[19],
                    store_buf[20],store_buf[21],
                    store_buf[22],store_buf[23]);
            end else if (nPbW==32) begin
                $fdisplay(fd_log, "yL %0d xL %0d:%0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d",
                    store_y,xPb,
                    store_buf[0],store_buf[1],
                    store_buf[2],store_buf[3],
                    store_buf[4],store_buf[5],
                    store_buf[6],store_buf[7],
                    store_buf[8],store_buf[9],
                    store_buf[10],store_buf[11],
                    store_buf[12],store_buf[13],
                    store_buf[14],store_buf[15]);
                $fdisplay(fd_log, "yL %0d xL %0d:%0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d",
                    store_y,xPb+16,
                    store_buf[16],store_buf[17],
                    store_buf[18],store_buf[19],
                    store_buf[20],store_buf[21],
                    store_buf[22],store_buf[23],
                    store_buf[24],store_buf[25],
                    store_buf[26],store_buf[27],
                    store_buf[28],store_buf[29],
                    store_buf[30],store_buf[31]);
            end else if (nPbW==48) begin
                $fdisplay(fd_log, "yL %0d xL %0d:%0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d",
                    store_y,xPb,
                    store_buf[0],store_buf[1],
                    store_buf[2],store_buf[3],
                    store_buf[4],store_buf[5],
                    store_buf[6],store_buf[7],
                    store_buf[8],store_buf[9],
                    store_buf[10],store_buf[11],
                    store_buf[12],store_buf[13],
                    store_buf[14],store_buf[15]);
                $fdisplay(fd_log, "yL %0d xL %0d:%0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d",
                    store_y,xPb+16,
                    store_buf[16],store_buf[17],
                    store_buf[18],store_buf[19],
                    store_buf[20],store_buf[21],
                    store_buf[22],store_buf[23],
                    store_buf[24],store_buf[25],
                    store_buf[26],store_buf[27],
                    store_buf[28],store_buf[29],
                    store_buf[30],store_buf[31]);
                $fdisplay(fd_log, "yL %0d xL %0d:%0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d",
                    store_y,xPb+32,
                    store_buf[32],store_buf[33],
                    store_buf[34],store_buf[35],
                    store_buf[36],store_buf[37],
                    store_buf[38],store_buf[39],
                    store_buf[40],store_buf[41],
                    store_buf[42],store_buf[43],
                    store_buf[44],store_buf[45],
                    store_buf[46],store_buf[47]);
            end else begin
                $fdisplay(fd_log, "yL %0d xL %0d:%0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d",
                    store_y,xPb,
                    store_buf[0],store_buf[1],
                    store_buf[2],store_buf[3],
                    store_buf[4],store_buf[5],
                    store_buf[6],store_buf[7],
                    store_buf[8],store_buf[9],
                    store_buf[10],store_buf[11],
                    store_buf[12],store_buf[13],
                    store_buf[14],store_buf[15]);
                $fdisplay(fd_log, "yL %0d xL %0d:%0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d",
                    store_y,xPb+16,
                    store_buf[16],store_buf[17],
                    store_buf[18],store_buf[19],
                    store_buf[20],store_buf[21],
                    store_buf[22],store_buf[23],
                    store_buf[24],store_buf[25],
                    store_buf[26],store_buf[27],
                    store_buf[28],store_buf[29],
                    store_buf[30],store_buf[31]);
                $fdisplay(fd_log, "yL %0d xL %0d:%0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d",
                    store_y,xPb+32,
                    store_buf[32],store_buf[33],
                    store_buf[34],store_buf[35],
                    store_buf[36],store_buf[37],
                    store_buf[38],store_buf[39],
                    store_buf[40],store_buf[41],
                    store_buf[42],store_buf[43],
                    store_buf[44],store_buf[45],
                    store_buf[46],store_buf[47]);
                $fdisplay(fd_log, "yL %0d xL %0d:%0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d",
                    store_y,xPb+48,
                    store_buf[48],store_buf[49],
                    store_buf[50],store_buf[51],
                    store_buf[52],store_buf[53],
                    store_buf[54],store_buf[55],
                    store_buf[56],store_buf[57],
                    store_buf[58],store_buf[59],
                    store_buf[60],store_buf[61],
                    store_buf[62],store_buf[63]);
            end

        end


        dram_pred_addrd             <= {64{store_y}};
        store_done                  <= 1;
        store_stage                 <= 2;
        if (cond_one_row_done)
            o_pred_done_y           <= {1'b0,store_y};
        if (store_y==yPb+nPbH-1)
            o_inter_pred_done       <= 1;
    end

end else begin
    dram_pred_we                    <= 64'd0;
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
    ref_start_x_tmp                    = {random_val[16:0],random_val[31:17],random_val[16:0],random_val[31:17]};
    ref_start_y_tmp                    = {random_val[17:0],random_val[31:18],random_val[17:0],random_val[31:18]};
    ref_end_x_tmp                      = {random_val[18:0],random_val[31:19],random_val[18:0],random_val[31:19]};
    ref_end_y_tmp                      = {random_val[19:0],random_val[31:20],random_val[19:0],random_val[31:20]};
    nPbW                               = {random_val[20:0],random_val[31:21],random_val[20:0],random_val[31:21]};
    nPbH                               = {random_val[21:0],random_val[31:22],random_val[21:0],random_val[31:22]};
    CbSize                             = {random_val[22:0],random_val[31:23],random_val[22:0],random_val[31:23]};
    fetch_h                            = {random_val[23:0],random_val[31:24],random_val[23:0],random_val[31:24]};
    fetch_h_minus1                     = {random_val[24:0],random_val[31:25],random_val[24:0],random_val[31:25]};
    fetched_rows                       = {random_val[25:0],random_val[31:26],random_val[25:0],random_val[31:26]};
    in_bound_h                         = {random_val[26:0],random_val[31:27],random_val[26:0],random_val[31:27]};
    in_bound_h                         = {random_val[27:0],random_val[31:28],random_val[27:0],random_val[31:28]};
    in_bound_h                         = {random_val[28:0],random_val[31:29],random_val[28:0],random_val[31:29]};
    in_bound_h                         = {random_val[29:0],random_val[31:30],random_val[29:0],random_val[31:30]};
    in_bound_h                         = {random_val[30:0],random_val[31],random_val[30:0],random_val[31]};
    in_bound_w_cur                     = {random_val[31:0],random_val[31:0]};
    in_bound_h_cur                     = {random_val,random_val};
    pre_bound_w_cur                    = {random_val[1:0],random_val[31:2],random_val[1:0],random_val[31:2]};
    pre_bound_h_cur                    = {random_val[2:0],random_val[31:3],random_val[2:0],random_val[31:3]};
    exd_bound_w_cur                    = {random_val[3:0],random_val[31:4],random_val[3:0],random_val[31:4]};
    exd_bound_h_cur                    = {random_val[4:0],random_val[31:5],random_val[4:0],random_val[31:5]};
    x_frac                             = {random_val[5:0],random_val[31:6],random_val[5:0],random_val[31:6]};
    y_frac                             = {random_val[6:0],random_val[31:7],random_val[6:0],random_val[31:7]};
    stage                              = {random_val[7:0],random_val[31:8],random_val[7:0],random_val[31:8]};
    first_cycle_stg2                   = {random_val[8:0],random_val[31:9],random_val[8:0],random_val[31:9]};
    ver_buf                            = {random_val[9:0],random_val[31:10],random_val[9:0],random_val[31:10]};
    ver_buf_bk                         = {random_val[10:0],random_val[31:11],random_val[10:0],random_val[31:11]};
    i                                  = {random_val[11:0],random_val[31:12],random_val[11:0],random_val[31:12]};
    hor_buf                            = {random_val[12:0],random_val[31:13],random_val[12:0],random_val[31:13]};
    hor_buf_bk                         = {random_val[13:0],random_val[31:14],random_val[13:0],random_val[31:14]};
    inter_pred_type                    = {random_val[14:0],random_val[31:15],random_val[14:0],random_val[31:15]};
    first_byte                         = {random_val[15:0],random_val[31:16],random_val[15:0],random_val[31:16]};
    last_byte                          = {random_val[16:0],random_val[31:17],random_val[16:0],random_val[31:17]};
    interp_hor_done                    = {random_val[17:0],random_val[31:18],random_val[17:0],random_val[31:18]};
    interp_hor_pre_done                = {random_val[18:0],random_val[31:19],random_val[18:0],random_val[31:19]};
    interp_ver_done                    = {random_val[19:0],random_val[31:20],random_val[19:0],random_val[31:20]};
    interp_ver_pre_done                = {random_val[20:0],random_val[31:21],random_val[20:0],random_val[31:21]};
    interp_hv_done                     = {random_val[21:0],random_val[31:22],random_val[21:0],random_val[31:22]};
    interp_hv_pre_done                 = {random_val[22:0],random_val[31:23],random_val[22:0],random_val[31:23]};
    store_done                         = {random_val[23:0],random_val[31:24],random_val[23:0],random_val[31:24]};
    store_pre_done                     = {random_val[24:0],random_val[31:25],random_val[24:0],random_val[31:25]};
    rst_store_full                     = {random_val[25:0],random_val[31:26],random_val[25:0],random_val[31:26]};
    rst_store_hor                      = {random_val[26:0],random_val[31:27],random_val[26:0],random_val[31:27]};
    rst_store_ver                      = {random_val[27:0],random_val[31:28],random_val[27:0],random_val[31:28]};
    rst_store_hv                       = {random_val[28:0],random_val[31:29],random_val[28:0],random_val[31:29]};
    rst_interp_hor                     = {random_val[29:0],random_val[31:30],random_val[29:0],random_val[31:30]};
    rst_interp_ver                     = {random_val[30:0],random_val[31],random_val[30:0],random_val[31]};
    rst_interp_hv                      = {random_val[31:0],random_val[31:0]};
    pic_width_minus1                   = {random_val,random_val};
    pic_height_minus1                  = {random_val[1:0],random_val[31:2],random_val[1:0],random_val[31:2]};
    store_y                            = {random_val[2:0],random_val[31:3],random_val[2:0],random_val[31:3]};
    y_interp_hor                       = {random_val[3:0],random_val[31:4],random_val[3:0],random_val[31:4]};
    y_interp_ver                       = {random_val[4:0],random_val[31:5],random_val[4:0],random_val[31:5]};
    y_interp_hv                        = {random_val[5:0],random_val[31:6],random_val[5:0],random_val[31:6]};
    y_fetch_save                       = {random_val[6:0],random_val[31:7],random_val[6:0],random_val[31:7]};
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
    interp_ver_i                       = {random_val[28:0],random_val[31:29],random_val[28:0],random_val[31:29]};
    interp_ver_i_max                   = {random_val[29:0],random_val[31:30],random_val[29:0],random_val[31:30]};
    interp_ver_i_d1                    = {random_val[30:0],random_val[31],random_val[30:0],random_val[31]};
    interp_ver_i_d2                    = {random_val[31:0],random_val[31:0]};
    interp_ver_valid                   = {random_val,random_val};
    interp_ver_valid_d1                = {random_val[1:0],random_val[31:2],random_val[1:0],random_val[31:2]};
    interp_ver_valid_d2                = {random_val[2:0],random_val[31:3],random_val[2:0],random_val[31:3]};
    interp_ver_clip                    = {random_val[3:0],random_val[31:4],random_val[3:0],random_val[31:4]};
    interp_hv_i                        = {random_val[12:0],random_val[31:13],random_val[12:0],random_val[31:13]};
    interp_hv_i_max                    = {random_val[13:0],random_val[31:14],random_val[13:0],random_val[31:14]};
    interp_hv_i_d1                     = {random_val[14:0],random_val[31:15],random_val[14:0],random_val[31:15]};
    interp_hv_i_d2                     = {random_val[15:0],random_val[31:16],random_val[15:0],random_val[31:16]};
    interp_hv_valid                    = {random_val[16:0],random_val[31:17],random_val[16:0],random_val[31:17]};
    interp_hv_valid_d1                 = {random_val[17:0],random_val[31:18],random_val[17:0],random_val[31:18]};
    interp_hv_valid_d2                 = {random_val[18:0],random_val[31:19],random_val[18:0],random_val[31:19]};
    interp_hv_clip                     = {random_val[19:0],random_val[31:20],random_val[19:0],random_val[31:20]};
    store_buf                          = {random_val[28:0],random_val[31:29],random_val[28:0],random_val[31:29]};
    store_buf_tmp                      = {random_val[29:0],random_val[31:30],random_val[29:0],random_val[31:30]};
    store_stage                        = {random_val[30:0],random_val[31],random_val[30:0],random_val[31]};
    cond_one_row_done                  = {random_val[31:0],random_val[31:0]};
end
`endif




endmodule
