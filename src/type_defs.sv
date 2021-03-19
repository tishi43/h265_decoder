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

`ifndef INCLUDED_types_def
`define INCLUDED_types_def

typedef struct packed {
    logic                               sao_merge_left_flag  ;
    logic                               sao_merge_up_flag    ;
    logic             [0:2][1:0]        sao_type_idx         ; //0 none,1,2
    logic signed [0:2][0:4][3:0]        sao_offset           ; //sao_offset[3][5] 最后[7:0]是位宽

    logic             [0:2][4:0]        sao_band_position    ; //sao_band_position[3]
    logic             [0:2][1:0]        sao_eo_class         ; //sao_eo_class[3]

} sao_params_t;


typedef struct packed {
    logic               [11:0]       reserved;
    logic               [ 3:0]       num_of_pics;
    logic [0:`max_ref-1][14:0]       deltaPoc; //P帧，恒为负，这里存正的
} rps_t;

//256 位宽32，存8次

typedef struct packed {
    logic signed [1: 0][14:0]         mv     ; //mv[0] mv[1] spec -2^15 to 2^15 (-32768~32767) 3840*4=15360,实际-15360~15359足够
} Mv;

typedef struct packed {
    Mv                                 mv         ;
    logic               [ 3:0]         refIdx     ; //0~15

} MvField;

`define BitsMvf 34

typedef struct packed {
    logic  [`max_x_bits-1:0]   x0;
    logic  [`max_y_bits-1:0]   y0;
    logic              [6:0]   CbSize;
    logic         [3:0][6:0]   nPbW;
    logic         [3:0][6:0]   nPbH;
    logic         [3:0][5:0]   xPb;
    logic         [3:0][5:0]   yPb;
    MvField       [3:0]        mvf;
    logic         [3:0]        parse_done;
} PuInfo;


`endif



