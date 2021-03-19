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

module rps
(
 input wire             clk                              ,
 input wire             rst                              ,
 input wire             en                               ,
 input wire  [ 7:0]     i_rbsp_in                        ,
 input wire  [ 3:0]     i_num_zero_bits                  ,

 input wire  [ 3:0]     i_rps_idx                        , //max 15
 input wire  [ 3:0]     i_num_short_term_ref_pic_sets    ,

 output reg  [ 4:0]     o_rps_state                      ,
 output reg  [ 3:0]     o_forward_len                    ,
 output reg             o_bram_rps_we                    ,
 output reg  [ 7:0]     o_bram_rps_addr                  ,

 output reg  [31:0]     o_bram_rps_din                   ,
 input wire  [31:0]     i_bram_rps_dout
);


reg                     inter_ref_pic_set_prediction_flag   ;
reg          [ 3:0]     delta_idx_minus1                    ; //0~stRpsIdx-1
reg          [ 3:0]     RefRpsIdx                           ;
reg signed   [15:0]     deltaRps                            ;
reg          [ 3:0]     j                                   ;
reg          [ 2:0]     i                                   ;
wire         [ 2:0]     iplus2                              ;
reg  [`max_ref-1:0]     use_delta_flag                      ;

assign iplus2 = i+2;

//todo The value of abs_delta_rps_minus1 shall be in the range of 0 to 2^15-1
//这里用5bit, deltaPoc占5*16=80bit

reg        [14:0]      prev_poc                            ;

rps_t                  rps                                 ;
rps_t                  rps_ref                             ;

reg                    delta_rps_sign                      ;
reg signed [15:0]      delta_poc_s0_minus1                 ;

reg        [ 3:0]      num_negative_pics                   ;

reg        [ 4:0]      rps_state_save                      ;

reg        [ 4:0]      state_after_exp                     ;
reg        [15:0]      ue                                  ;
reg        [15:0]      se                                  ;
reg        [ 3:0]      leadingZerobits                     ;
reg        [ 3:0]      bits_total                          ;
reg        [ 3:0]      bits_left                           ;

reg        [14:0]      delta                               ;


always @ (posedge clk)
if (rst)
begin
    o_rps_state                            <= 0;
    inter_ref_pic_set_prediction_flag      <= 0;
    delta_idx_minus1                       <= 0;
    o_forward_len                          <= 0;
    rps                                    <= 0;

    use_delta_flag                         <= `max_ref'd0;
    leadingZerobits                        <= 0;
    ue                                     <= 0;
    se                                     <= 0;

end
else if (en)
    case (o_rps_state)
        `rst_rps:
            begin
                inter_ref_pic_set_prediction_flag   <= 0;
                delta_idx_minus1                    <= 0;
                j                                   <= 0;

                use_delta_flag                      <= {`max_ref{1'b1}};
                if (i_rps_idx != 0) begin
                    o_rps_state                     <= `inter_ref_pic_set_prediction_flag_s;
                end else begin
                    o_rps_state                     <= `rps_exp_count_zero;
                    state_after_exp                 <= `num_negative_pics_s;
                end
            end
        `rps_delay_1_cycle://e
            begin
                o_forward_len                       <= 0;
                o_rps_state                         <= rps_state_save;
            end
        `rps_exp_count_zero://0x10
            begin
                leadingZerobits      <= leadingZerobits+i_num_zero_bits;
                o_forward_len        <= i_num_zero_bits;
                o_rps_state          <= `rps_delay_1_cycle;
                rps_state_save       <= `rps_exp_count_zero;
                if (~i_num_zero_bits[3]) begin //<8
                    rps_state_save   <= `rps_exp_golomb_calc;
                    bits_left        <= leadingZerobits+i_num_zero_bits+1;
                    bits_total       <= leadingZerobits+i_num_zero_bits+1;
                end
            end

        `rps_exp_golomb_calc: begin//0x11
            if (bits_left>8) begin
                bits_left        <= bits_left - 8;
                o_forward_len    <= 8;
                ue               <= i_rbsp_in[7:0];
                rps_state_save   <= `rps_exp_golomb_calc;
            end else begin
                case (bits_left)
                1:ue      <= {24'd0,ue[7:0],i_rbsp_in[7]} - 1; //          1
                2:ue      <= {24'd0,ue[7:0],i_rbsp_in[7:6]} - 1; //       01x
                3:ue      <= {24'd0,ue[7:0],i_rbsp_in[7:5]} - 1; //      001xx
                4:ue      <= {24'd0,ue[7:0],i_rbsp_in[7:4]} - 1; //     0001xxx
                5:ue      <= {24'd0,ue[7:0],i_rbsp_in[7:3]} - 1; //    00001xxxx
                6:ue      <= {24'd0,ue[7:0],i_rbsp_in[7:2]} - 1; //   000001xxxxx
                7:ue      <= {24'd0,ue[7:0],i_rbsp_in[7:1]} - 1; //  0000001xxxxxx
                8:ue      <= {24'd0,ue[7:0],i_rbsp_in[7:0]} - 1; // 00000001xxxxxxx
                default:ue      <= 0;
                endcase
//a0 0f 08  1010 0000, 0000,{1111,0000,1}000,  1e1-1=1e0
                case (bits_total)
                1:se        <= 0;
                2:se        <= i_rbsp_in[6]? -i_rbsp_in[7] : i_rbsp_in[7];  //10 11 00111  111>>1 = 11
                3:se        <= i_rbsp_in[5]? -i_rbsp_in[7:6]: i_rbsp_in[7:6];
                4:se        <= i_rbsp_in[4]? -i_rbsp_in[7:5]: i_rbsp_in[7:5];
                5:se        <= i_rbsp_in[3]? -i_rbsp_in[7:4]: i_rbsp_in[7:4];
                6:se        <= i_rbsp_in[2]? -i_rbsp_in[7:3]: i_rbsp_in[7:3];
                7:se        <= i_rbsp_in[1]? -i_rbsp_in[7:2]: i_rbsp_in[7:2];
                8:se        <= i_rbsp_in[0]? -i_rbsp_in[7:1]: i_rbsp_in[7:1];
                9:se        <= i_rbsp_in[7]? -i_rbsp_in[7:0] : i_rbsp_in[7:0];
                10:se       <= i_rbsp_in[6]? -{ue[7:0],i_rbsp_in[7]} : {ue[7:0],i_rbsp_in[7]};
                11:se       <= i_rbsp_in[5]? -{ue[7:0],i_rbsp_in[7:6]} : {ue[7:0],i_rbsp_in[7:6]};
                12:se       <= i_rbsp_in[4]? -{ue[7:0],i_rbsp_in[7:5]} : {ue[7:0],i_rbsp_in[7:5]};
                13:se       <= i_rbsp_in[3]? -{ue[7:0],i_rbsp_in[7:4]} : {ue[7:0],i_rbsp_in[7:4]};
                14:se       <= i_rbsp_in[2]? -{ue[7:0],i_rbsp_in[7:3]} : {ue[7:0],i_rbsp_in[7:3]};
                default:se      <= 0;
                endcase
                o_forward_len   <= bits_left;
                rps_state_save   <= `rps_exp_golomb_end;
            end

            o_rps_state      <= `rps_delay_1_cycle;
        end

        `rps_exp_golomb_end://0x12
            begin
                leadingZerobits                     <= 0; //reinit
                ue                                  <= 0;
                se                                  <= 0;
                case (state_after_exp)
                    `delta_idx_minus1_s:
                        begin
                            delta_idx_minus1        <= ue;
                            RefRpsIdx               <= i_rps_idx - ue - 1;
                            o_rps_state             <= `rps_fetch_ref_1;
                        end
                    `abs_delta_rps_minus1_s://a
                        begin
                            //deltaRps = (1 - 2 * delta_rps_sign) * (abs_delta_rps_minus1 + 1);
                            if (delta_rps_sign)
                                deltaRps            <= -(ue+1);
                            else
                                deltaRps            <=  (ue+1);
                            o_rps_state             <= `used_by_curr_pic_flag_inter_s;
                        end
                    `num_negative_pics_s://b
                        begin
                            num_negative_pics        <= ue;
                            rps.num_of_pics          <= ue;
                            state_after_exp          <= `num_positive_pics_s;
                            o_rps_state              <= `rps_exp_count_zero;
                        end
                    `num_positive_pics_s://c
                        begin
                            j                        <= 0;
                            prev_poc                 <= 0;
                            if (rps.num_of_pics == 0) begin
                                i                    <= 0;
                                o_rps_state          <= `rps_store;
                            end else begin
                                o_rps_state          <= `rps_exp_count_zero;
                                state_after_exp      <= `delta_poc_s0_minus1_s;
                            end

                        end
                    `delta_poc_s0_minus1_s://d
                        begin
                            delta_poc_s0_minus1      <= ue;
                            o_rps_state              <= `used_by_curr_pic_flag_intra_s;
                        end
                    endcase
            end

        `inter_ref_pic_set_prediction_flag_s ://7
            begin
                inter_ref_pic_set_prediction_flag   <= i_rbsp_in[7];
                if (i_rbsp_in[7]) begin
                    //parse_slice_header ref idx由delta_idx_minus1决定，sps进来的，参考前一个rps
                    if (i_rps_idx == i_num_short_term_ref_pic_sets) begin //call from parse slice_header
                        state_after_exp             <= `delta_idx_minus1_s;
                    end else begin
                        delta_idx_minus1            <= 0;
                        RefRpsIdx                   <= i_rps_idx - 1;
                        rps_state_save              <= `rps_fetch_ref_1;
                    end
                end else begin
                    state_after_exp                 <= `num_negative_pics_s;
                    rps_state_save                  <= `rps_exp_count_zero;
                end
                o_forward_len                       <= 1;
                o_rps_state                         <= `rps_delay_1_cycle;
            end

        `rps_fetch_ref_1://0x15
            begin
                o_bram_rps_addr               <= {1'b0,RefRpsIdx,3'd0};
                o_bram_rps_we                 <= 0;
                o_rps_state                   <= `rps_fetch_ref_2;
            end
        `rps_fetch_ref_2://0x16
            begin
                i                             <= 0;
                o_bram_rps_addr               <= {1'b0,RefRpsIdx,3'd1};
                o_rps_state                   <= `rps_fetch_ref_3;
            end

        `rps_fetch_ref_3://0x17
            begin
                i                             <= i+1;
                o_bram_rps_addr               <= {1'b0,RefRpsIdx,iplus2};
                rps_ref                       <= {i_bram_rps_dout,rps_ref[255:32]};
                if (i == 7) begin
                    o_rps_state               <= `delta_rps_sign_s;
                end
            end

        `delta_rps_sign_s://9
            begin 
                delta_rps_sign                <= i_rbsp_in[7];

                o_forward_len                 <= 1;
                state_after_exp               <= `abs_delta_rps_minus1_s;
                rps_state_save                <= `rps_exp_count_zero;
                o_rps_state                   <= `rps_delay_1_cycle;
            end



        `used_by_curr_pic_flag_inter_s://4
            begin
                //used_by_curr_pic_flag[j]    <= i_rbsp_in[7];
                if (i_rbsp_in[7])
                    begin
                        if ((j+1) <= rps_ref.num_of_pics)
                            rps_state_save    <= `used_by_curr_pic_flag_inter_s;
                        else
                            rps_state_save    <= `calc_rps_1;
                        j                     <= j + 1;
                    end
                else
                    rps_state_save            <= `use_delta_flag_s;
                o_forward_len                 <= 1;
                o_rps_state                   <= `rps_delay_1_cycle;
            end
        `use_delta_flag_s://0x5
            begin
                use_delta_flag[j]             <= i_rbsp_in[7];
                if ((j+1) <= rps_ref.num_of_pics)
                    rps_state_save            <= `used_by_curr_pic_flag_inter_s;
                else
                    rps_state_save            <= `calc_rps_1;
                j                             <= j + 1;

                o_forward_len                 <= 1;
                o_rps_state                   <= `rps_delay_1_cycle;
            end

        `calc_rps_1://0x2
            begin

                if (deltaRps < 0 && use_delta_flag[rps_ref.num_of_pics])
                    o_rps_state               <=  `calc_rps_2;
                else
                    o_rps_state               <=  `calc_rps_3;

                j <= 0;

            end


        `calc_rps_2://0x3
            begin
                rps.deltaPoc[0]               <=  -deltaRps;
                rps.num_of_pics               <=  1;
                o_rps_state                   <=  `calc_rps_3;
            end

        `calc_rps_3://0x13
            begin
                delta                              <= rps_ref.deltaPoc[j] + (-deltaRps);
                o_rps_state                        <= `calc_rps_4;
            end

        `calc_rps_4://0x14
            begin
                if (use_delta_flag[j]) begin
                    rps.deltaPoc[rps.num_of_pics]  <=  delta;
                    rps.num_of_pics                <=  rps.num_of_pics + 1;
                end
                j <= j + 1;
                if (j + 1 < rps_ref.num_of_pics) begin
                    o_rps_state                    <=  `calc_rps_3; //`calc_rps_3,`calc_rps_4循环
                end else begin
                    i                              <= 0;
                    o_rps_state                    <=  `rps_store;
                end
            end


        `used_by_curr_pic_flag_intra_s://6
            begin
                //used_by_curr_pic_flag没有存起来,只存了inter的use_delta_flag
                rps.deltaPoc[j]                    <= delta_poc_s0_minus1+1+prev_poc;
                prev_poc                           <= delta_poc_s0_minus1+1+prev_poc;
                if (j + 1 < num_negative_pics) begin
                    rps_state_save                 <= `rps_exp_count_zero;
                    state_after_exp                <= `delta_poc_s0_minus1_s;
                end else begin
                    i                              <= 0;
                    rps_state_save                 <= `rps_store;
                end
                j                                  <= j+1;
                o_forward_len                      <= 1;
                o_rps_state                        <= `rps_delay_1_cycle;
            end
        `rps_store://0x18
            begin
                i                                   <= i+1;
                o_bram_rps_din                      <= rps[31:0];
                rps                                 <= {32'd0,rps[255:32]};
                o_bram_rps_we                       <= 1;
                o_bram_rps_addr                     <= {1'b0,i_rps_idx,i};
                if (i == 7)
                    o_rps_state                     <= `rps_end;
            end

        `rps_end://1
            begin
                o_rps_state                         <= `rps_end_2;
            end
        `rps_end_2: //f 为什么要2个end，看sps.v的if (i_rps_state == `rps_end)部分,
                    //如果只有1个`rps_end,o_rst_rps_module <= 1的下一个周期读到rps状态的还是`rps_end,恒reset
            begin
            end
        default: o_rps_state <= `rst_rps;
    endcase

`ifdef RANDOM_INIT
integer  seed;
integer random_val;
initial  begin
    seed                               = $get_initial_random_seed(); 
    random_val                         = $random(seed);
    o_rps_state                        = {random_val,random_val};
    o_forward_len                      = {random_val[1:0],random_val[31:2],random_val[1:0],random_val[31:2]};
    o_bram_rps_we                      = {random_val[2:0],random_val[31:3],random_val[2:0],random_val[31:3]};
    o_bram_rps_addr                    = {random_val[3:0],random_val[31:4],random_val[3:0],random_val[31:4]};
    o_bram_rps_din                     = {random_val[4:0],random_val[31:5],random_val[4:0],random_val[31:5]};
    inter_ref_pic_set_prediction_flag  = {random_val[5:0],random_val[31:6],random_val[5:0],random_val[31:6]};
    delta_idx_minus1                   = {random_val[6:0],random_val[31:7],random_val[6:0],random_val[31:7]};
    RefRpsIdx                          = {random_val[7:0],random_val[31:8],random_val[7:0],random_val[31:8]};
    deltaRps                           = {random_val[8:0],random_val[31:9],random_val[8:0],random_val[31:9]};
    j                                  = {random_val[9:0],random_val[31:10],random_val[9:0],random_val[31:10]};
    i                                  = {random_val[10:0],random_val[31:11],random_val[10:0],random_val[31:11]};
    use_delta_flag                     = {random_val[11:0],random_val[31:12],random_val[11:0],random_val[31:12]};
    prev_poc                           = {random_val[12:0],random_val[31:13],random_val[12:0],random_val[31:13]};
    delta_rps_sign                     = {random_val[13:0],random_val[31:14],random_val[13:0],random_val[31:14]};
    delta_poc_s0_minus1                = {random_val[14:0],random_val[31:15],random_val[14:0],random_val[31:15]};
    num_negative_pics                  = {random_val[15:0],random_val[31:16],random_val[15:0],random_val[31:16]};
    rps_state_save                     = {random_val[16:0],random_val[31:17],random_val[16:0],random_val[31:17]};
    state_after_exp                    = {random_val[17:0],random_val[31:18],random_val[17:0],random_val[31:18]};
    ue                                 = {random_val[18:0],random_val[31:19],random_val[18:0],random_val[31:19]};
    se                                 = {random_val[19:0],random_val[31:20],random_val[19:0],random_val[31:20]};
    leadingZerobits                    = {random_val[20:0],random_val[31:21],random_val[20:0],random_val[31:21]};
    bits_total                         = {random_val[21:0],random_val[31:22],random_val[21:0],random_val[31:22]};
    bits_left                          = {random_val[22:0],random_val[31:23],random_val[22:0],random_val[31:23]};
    delta                              = {random_val[23:0],random_val[31:24],random_val[23:0],random_val[31:24]};
end
`endif

endmodule
