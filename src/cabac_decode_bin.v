//--------------------------------------------------------------------------------------------------
// Design    : bvp
// Author(s) : qiu bin, shi tian qi
// Email     : chat1@126.com, tishi1@126.com
// Copyright (C) 2013-2017 qiu bin, shi tian qi
// All rights reserved
// Phone 15957074161
// QQ:1517642772
//-------------------------------------------------------------------------------------------------

module cabac_decode_bin
(
    input wire               clk,
    //todo 加上en，电平少跳一点，省点功耗，试试加上后关键路径会不会增加
    input wire      [ 8: 0]  i_ivlCurrRange,
    input wire      [ 8: 0]  i_ivlOffset,
    input wire      [ 5: 0]  i_pStateIdx, //cm->pStateIdx
    input wire               i_valMps, //cm->valMps
    input wire      [ 7: 2]  i_rbsp_in,

    output reg [ 8: 0]  o_ivlCurrRange, //always块必须用reg,实际综合成wire
    output reg [ 8: 0]  o_ivlOffset,
    output reg [ 5: 0]  o_pStateIdx, //cm->pStateIdx
    output reg          o_valMps, //cm->valMps
    output reg          o_binVal,
    output reg [ 2: 0]  o_output_len
);


wire [ 1:0] qRangeIdx;
reg  [ 7:0] ivlLpsRange_r;
reg  [ 7:0] ivlLpsRange;
reg  [ 5:0] transIdxMps;
reg  [ 5:0] transIdxLps;
reg  [ 5:0] transIdxMps_r;
reg  [ 5:0] transIdxLps_r;


reg  [ 8:0] ivlCurrRange;
reg  [ 8:0] ivlOffset;
wire [ 8:0] ivlCurrRange_temp;
wire signed [ 9:0] ivlOffset_temp;


reg  signed [ 9:0] ivlOffset_temp_r;
reg  [ 8:0] ivlCurrRange_temp_r;

reg         valMps_r;

assign qRangeIdx = i_ivlCurrRange[7:6];

assign ivlCurrRange_temp = i_ivlCurrRange - ivlLpsRange;
assign ivlOffset_temp    = i_ivlOffset + ivlLpsRange - i_ivlCurrRange;

always @(posedge clk)
begin
    ivlCurrRange_temp_r <= ivlCurrRange_temp;
    ivlOffset_temp_r    <= ivlOffset_temp;

    valMps_r            <= i_valMps;

    ivlLpsRange_r       <= ivlLpsRange;
    transIdxMps_r       <= transIdxMps;
    transIdxLps_r       <= transIdxLps;

end

always @(*)
begin
    if (~ivlOffset_temp_r[9]) begin
        o_binVal = ~valMps_r;
    end else begin
        o_binVal = valMps_r;
    end
end

always @(*)
begin
    if (~ivlOffset_temp_r[9]) begin
        ivlCurrRange = ivlLpsRange_r;
    end else begin
        ivlCurrRange = ivlCurrRange_temp_r;
    end
end

always @(*)
begin

    if (~ivlOffset_temp_r[9]) begin
        ivlOffset   = ivlOffset_temp_r;
        o_valMps    = i_pStateIdx == 0 ? ~valMps_r:valMps_r;
        o_pStateIdx = transIdxLps_r;
    end else begin
        ivlOffset   = i_ivlOffset;
        o_pStateIdx = transIdxMps_r;
        o_valMps    = valMps_r;
    end
end


always  @ (ivlCurrRange)
begin
    casez (ivlCurrRange[8:2])
        7'b1??_???? : o_output_len = 3'd0;
        7'b01?_???? : o_output_len = 3'd1;
        7'b001_???? : o_output_len = 3'd2;
        7'b000_1??? : o_output_len = 3'd3;
        7'b000_01?? : o_output_len = 3'd4;
        7'b000_001? : o_output_len = 3'd5;
        7'b000_0001 : o_output_len = 3'd6;
        default     : o_output_len = 3'd0;
    endcase
end


always @ (*)
begin
    case (o_output_len)
        3'd1: begin
            o_ivlCurrRange    = {ivlCurrRange[7:0], 1'b0};
            o_ivlOffset       = {ivlOffset[7:0], i_rbsp_in[7]};
        end
        3'd2: begin
            o_ivlCurrRange    = {ivlCurrRange[6:0], 2'b0};
            o_ivlOffset       = {ivlOffset[6:0], i_rbsp_in[7:6]};
        end
        3'd3: begin
            o_ivlCurrRange    = {ivlCurrRange[5:0], 3'b0};
            o_ivlOffset       = {ivlOffset[5:0], i_rbsp_in[7:5]};
        end
        3'd4: begin
            o_ivlCurrRange    = {ivlCurrRange[4:0], 4'b0};
            o_ivlOffset       = {ivlOffset[4:0], i_rbsp_in[7:4]};
        end
        3'd5: begin
            o_ivlCurrRange    = {ivlCurrRange[3:0], 5'b0};
            o_ivlOffset       = {ivlOffset[3:0], i_rbsp_in[7:3]};
        end
        3'd6: begin
            o_ivlCurrRange    = {ivlCurrRange[2:0], 6'b0};
            o_ivlOffset       = {ivlOffset[2:0], i_rbsp_in[7:2]};
        end
        default : begin
            o_ivlCurrRange    = ivlCurrRange;
            o_ivlOffset       = ivlOffset;
        end
    endcase
end

always @(i_pStateIdx)
    case (i_pStateIdx)
        6'd00 : transIdxLps = 00;
        6'd01 : transIdxLps = 00;
        6'd02 : transIdxLps = 01;
        6'd03 : transIdxLps = 02;
        6'd04 : transIdxLps = 02;
        6'd05 : transIdxLps = 04;
        6'd06 : transIdxLps = 04;
        6'd07 : transIdxLps = 05;
        6'd08 : transIdxLps = 06;
        6'd09 : transIdxLps = 07;
        6'd10 : transIdxLps = 08;
        6'd11 : transIdxLps = 09;
        6'd12 : transIdxLps = 09;
        6'd13 : transIdxLps = 11;
        6'd14 : transIdxLps = 11;
        6'd15 : transIdxLps = 12;
        6'd16 : transIdxLps = 13;
        6'd17 : transIdxLps = 13;
        6'd18 : transIdxLps = 15;
        6'd19 : transIdxLps = 15;
        6'd20 : transIdxLps = 16;
        6'd21 : transIdxLps = 16;
        6'd22 : transIdxLps = 18;
        6'd23 : transIdxLps = 18;
        6'd24 : transIdxLps = 19;
        6'd25 : transIdxLps = 19;
        6'd26 : transIdxLps = 21;
        6'd27 : transIdxLps = 21;
        6'd28 : transIdxLps = 22;
        6'd29 : transIdxLps = 22;
        6'd30 : transIdxLps = 23;
        6'd31 : transIdxLps = 24;
        6'd32 : transIdxLps = 24;
        6'd33 : transIdxLps = 25;
        6'd34 : transIdxLps = 26;
        6'd35 : transIdxLps = 26;
        6'd36 : transIdxLps = 27;
        6'd37 : transIdxLps = 27;
        6'd38 : transIdxLps = 28;
        6'd39 : transIdxLps = 29;
        6'd40 : transIdxLps = 29;
        6'd41 : transIdxLps = 30;
        6'd42 : transIdxLps = 30;
        6'd43 : transIdxLps = 30;
        6'd44 : transIdxLps = 31;
        6'd45 : transIdxLps = 32;
        6'd46 : transIdxLps = 32;
        6'd47 : transIdxLps = 33;
        6'd48 : transIdxLps = 33;
        6'd49 : transIdxLps = 33;
        6'd50 : transIdxLps = 34;
        6'd51 : transIdxLps = 34;
        6'd52 : transIdxLps = 35;
        6'd53 : transIdxLps = 35;
        6'd54 : transIdxLps = 35;
        6'd55 : transIdxLps = 36;
        6'd56 : transIdxLps = 36;
        6'd57 : transIdxLps = 36;
        6'd58 : transIdxLps = 37;
        6'd59 : transIdxLps = 37;
        6'd60 : transIdxLps = 37;
        6'd61 : transIdxLps = 38;
        6'd62 : transIdxLps = 38;
        6'd63 : transIdxLps = 63;
    endcase

//这个被优化掉了
always @(i_pStateIdx)
    case (i_pStateIdx)
        6'd00 : transIdxMps = 01;
        6'd01 : transIdxMps = 02;
        6'd02 : transIdxMps = 03;
        6'd03 : transIdxMps = 04;
        6'd04 : transIdxMps = 05;
        6'd05 : transIdxMps = 06;
        6'd06 : transIdxMps = 07;
        6'd07 : transIdxMps = 08;
        6'd08 : transIdxMps = 09;
        6'd09 : transIdxMps = 10;
        6'd10 : transIdxMps = 11;
        6'd11 : transIdxMps = 12;
        6'd12 : transIdxMps = 13;
        6'd13 : transIdxMps = 14;
        6'd14 : transIdxMps = 15;
        6'd15 : transIdxMps = 16;
        6'd16 : transIdxMps = 17;
        6'd17 : transIdxMps = 18;
        6'd18 : transIdxMps = 19;
        6'd19 : transIdxMps = 20;
        6'd20 : transIdxMps = 21;
        6'd21 : transIdxMps = 22;
        6'd22 : transIdxMps = 23;
        6'd23 : transIdxMps = 24;
        6'd24 : transIdxMps = 25;
        6'd25 : transIdxMps = 26;
        6'd26 : transIdxMps = 27;
        6'd27 : transIdxMps = 28;
        6'd28 : transIdxMps = 29;
        6'd29 : transIdxMps = 30;
        6'd30 : transIdxMps = 31;
        6'd31 : transIdxMps = 32;
        6'd32 : transIdxMps = 33;
        6'd33 : transIdxMps = 34;
        6'd34 : transIdxMps = 35;
        6'd35 : transIdxMps = 36;
        6'd36 : transIdxMps = 37;
        6'd37 : transIdxMps = 38;
        6'd38 : transIdxMps = 39;
        6'd39 : transIdxMps = 40;
        6'd40 : transIdxMps = 41;
        6'd41 : transIdxMps = 42;
        6'd42 : transIdxMps = 43;
        6'd43 : transIdxMps = 44;
        6'd44 : transIdxMps = 45;
        6'd45 : transIdxMps = 46;
        6'd46 : transIdxMps = 47;
        6'd47 : transIdxMps = 48;
        6'd48 : transIdxMps = 49;
        6'd49 : transIdxMps = 50;
        6'd50 : transIdxMps = 51;
        6'd51 : transIdxMps = 52;
        6'd52 : transIdxMps = 53;
        6'd53 : transIdxMps = 54;
        6'd54 : transIdxMps = 55;
        6'd55 : transIdxMps = 56;
        6'd56 : transIdxMps = 57;
        6'd57 : transIdxMps = 58;
        6'd58 : transIdxMps = 59;
        6'd59 : transIdxMps = 60;
        6'd60 : transIdxMps = 61;
        6'd61 : transIdxMps = 62;
        6'd62 : transIdxMps = 62; //here
        6'd63 : transIdxMps = 63;
    endcase

always @(*)
    case ({i_pStateIdx[5:0],qRangeIdx[1:0]})
        8'h00 : ivlLpsRange = 128;
        8'h01 : ivlLpsRange = 176;
        8'h02 : ivlLpsRange = 208;
        8'h03 : ivlLpsRange = 240;
        8'h04 : ivlLpsRange = 128;
        8'h05 : ivlLpsRange = 167;
        8'h06 : ivlLpsRange = 197;
        8'h07 : ivlLpsRange = 227;
        8'h08 : ivlLpsRange = 128;
        8'h09 : ivlLpsRange = 158;
        8'h0a : ivlLpsRange = 187;
        8'h0b : ivlLpsRange = 216;
        8'h0c : ivlLpsRange = 123;
        8'h0d : ivlLpsRange = 150;
        8'h0e : ivlLpsRange = 178;
        8'h0f : ivlLpsRange = 205;
        8'h10 : ivlLpsRange = 116;
        8'h11 : ivlLpsRange = 142;
        8'h12 : ivlLpsRange = 169;
        8'h13 : ivlLpsRange = 195;
        8'h14 : ivlLpsRange = 111;
        8'h15 : ivlLpsRange = 135;
        8'h16 : ivlLpsRange = 160;
        8'h17 : ivlLpsRange = 185;
        8'h18 : ivlLpsRange = 105;
        8'h19 : ivlLpsRange = 128;
        8'h1a : ivlLpsRange = 152;
        8'h1b : ivlLpsRange = 175;
        8'h1c : ivlLpsRange = 100;
        8'h1d : ivlLpsRange = 122;
        8'h1e : ivlLpsRange = 144;
        8'h1f : ivlLpsRange = 166;
        8'h20 : ivlLpsRange = 95;
        8'h21 : ivlLpsRange = 116;
        8'h22 : ivlLpsRange = 137;
        8'h23 : ivlLpsRange = 158;
        8'h24 : ivlLpsRange = 90;
        8'h25 : ivlLpsRange = 110;
        8'h26 : ivlLpsRange = 130;
        8'h27 : ivlLpsRange = 150;
        8'h28 : ivlLpsRange = 85;
        8'h29 : ivlLpsRange = 104;
        8'h2a : ivlLpsRange = 123;
        8'h2b : ivlLpsRange = 142;
        8'h2c : ivlLpsRange = 81;
        8'h2d : ivlLpsRange = 99;
        8'h2e : ivlLpsRange = 117;
        8'h2f : ivlLpsRange = 135;
        8'h30 : ivlLpsRange = 77;
        8'h31 : ivlLpsRange = 94;
        8'h32 : ivlLpsRange = 111;
        8'h33 : ivlLpsRange = 128;
        8'h34 : ivlLpsRange = 73;
        8'h35 : ivlLpsRange = 89;
        8'h36 : ivlLpsRange = 105;
        8'h37 : ivlLpsRange = 122;
        8'h38 : ivlLpsRange = 69;
        8'h39 : ivlLpsRange = 85;
        8'h3a : ivlLpsRange = 100;
        8'h3b : ivlLpsRange = 116;
        8'h3c : ivlLpsRange = 66;
        8'h3d : ivlLpsRange = 80;
        8'h3e : ivlLpsRange = 95;
        8'h3f : ivlLpsRange = 110;
        8'h40 : ivlLpsRange = 62;
        8'h41 : ivlLpsRange = 76;
        8'h42 : ivlLpsRange = 90;
        8'h43 : ivlLpsRange = 104;
        8'h44 : ivlLpsRange = 59;
        8'h45 : ivlLpsRange = 72;
        8'h46 : ivlLpsRange = 86;
        8'h47 : ivlLpsRange = 99;
        8'h48 : ivlLpsRange = 56;
        8'h49 : ivlLpsRange = 69;
        8'h4a : ivlLpsRange = 81;
        8'h4b : ivlLpsRange = 94;
        8'h4c : ivlLpsRange = 53;
        8'h4d : ivlLpsRange = 65;
        8'h4e : ivlLpsRange = 77;
        8'h4f : ivlLpsRange = 89;
        8'h50 : ivlLpsRange = 51;
        8'h51 : ivlLpsRange = 62;
        8'h52 : ivlLpsRange = 73;
        8'h53 : ivlLpsRange = 85;
        8'h54 : ivlLpsRange = 48;
        8'h55 : ivlLpsRange = 59;
        8'h56 : ivlLpsRange = 69;
        8'h57 : ivlLpsRange = 80;
        8'h58 : ivlLpsRange = 46;
        8'h59 : ivlLpsRange = 56;
        8'h5a : ivlLpsRange = 66;
        8'h5b : ivlLpsRange = 76;
        8'h5c : ivlLpsRange = 43;
        8'h5d : ivlLpsRange = 53;
        8'h5e : ivlLpsRange = 63;
        8'h5f : ivlLpsRange = 72;
        8'h60 : ivlLpsRange = 41;
        8'h61 : ivlLpsRange = 50;
        8'h62 : ivlLpsRange = 59;
        8'h63 : ivlLpsRange = 69;
        8'h64 : ivlLpsRange = 39;
        8'h65 : ivlLpsRange = 48;
        8'h66 : ivlLpsRange = 56;
        8'h67 : ivlLpsRange = 65;
        8'h68 : ivlLpsRange = 37;
        8'h69 : ivlLpsRange = 45;
        8'h6a : ivlLpsRange = 54;
        8'h6b : ivlLpsRange = 62;
        8'h6c : ivlLpsRange = 35;
        8'h6d : ivlLpsRange = 43;
        8'h6e : ivlLpsRange = 51;
        8'h6f : ivlLpsRange = 59;
        8'h70 : ivlLpsRange = 33;
        8'h71 : ivlLpsRange = 41;
        8'h72 : ivlLpsRange = 48;
        8'h73 : ivlLpsRange = 56;
        8'h74 : ivlLpsRange = 32;
        8'h75 : ivlLpsRange = 39;
        8'h76 : ivlLpsRange = 46;
        8'h77 : ivlLpsRange = 53;
        8'h78 : ivlLpsRange = 30;
        8'h79 : ivlLpsRange = 37;
        8'h7a : ivlLpsRange = 43;
        8'h7b : ivlLpsRange = 50;
        8'h7c : ivlLpsRange = 29;
        8'h7d : ivlLpsRange = 35;
        8'h7e : ivlLpsRange = 41;
        8'h7f : ivlLpsRange = 48;
        8'h80 : ivlLpsRange = 27;
        8'h81 : ivlLpsRange = 33;
        8'h82 : ivlLpsRange = 39;
        8'h83 : ivlLpsRange = 45;
        8'h84 : ivlLpsRange = 26;
        8'h85 : ivlLpsRange = 31;
        8'h86 : ivlLpsRange = 37;
        8'h87 : ivlLpsRange = 43;
        8'h88 : ivlLpsRange = 24;
        8'h89 : ivlLpsRange = 30;
        8'h8a : ivlLpsRange = 35;
        8'h8b : ivlLpsRange = 41;
        8'h8c : ivlLpsRange = 23;
        8'h8d : ivlLpsRange = 28;
        8'h8e : ivlLpsRange = 33;
        8'h8f : ivlLpsRange = 39;
        8'h90 : ivlLpsRange = 22;
        8'h91 : ivlLpsRange = 27;
        8'h92 : ivlLpsRange = 32;
        8'h93 : ivlLpsRange = 37;
        8'h94 : ivlLpsRange = 21;
        8'h95 : ivlLpsRange = 26;
        8'h96 : ivlLpsRange = 30;
        8'h97 : ivlLpsRange = 35;
        8'h98 : ivlLpsRange = 20;
        8'h99 : ivlLpsRange = 24;
        8'h9a : ivlLpsRange = 29;
        8'h9b : ivlLpsRange = 33;
        8'h9c : ivlLpsRange = 19;
        8'h9d : ivlLpsRange = 23;
        8'h9e : ivlLpsRange = 27;
        8'h9f : ivlLpsRange = 31;
        8'ha0 : ivlLpsRange = 18;
        8'ha1 : ivlLpsRange = 22;
        8'ha2 : ivlLpsRange = 26;
        8'ha3 : ivlLpsRange = 30;
        8'ha4 : ivlLpsRange = 17;
        8'ha5 : ivlLpsRange = 21;
        8'ha6 : ivlLpsRange = 25;
        8'ha7 : ivlLpsRange = 28;
        8'ha8 : ivlLpsRange = 16;
        8'ha9 : ivlLpsRange = 20;
        8'haa : ivlLpsRange = 23;
        8'hab : ivlLpsRange = 27;
        8'hac : ivlLpsRange = 15;
        8'had : ivlLpsRange = 19;
        8'hae : ivlLpsRange = 22;
        8'haf : ivlLpsRange = 25;
        8'hb0 : ivlLpsRange = 14;
        8'hb1 : ivlLpsRange = 18;
        8'hb2 : ivlLpsRange = 21;
        8'hb3 : ivlLpsRange = 24;
        8'hb4 : ivlLpsRange = 14;
        8'hb5 : ivlLpsRange = 17;
        8'hb6 : ivlLpsRange = 20;
        8'hb7 : ivlLpsRange = 23;
        8'hb8 : ivlLpsRange = 13;
        8'hb9 : ivlLpsRange = 16;
        8'hba : ivlLpsRange = 19;
        8'hbb : ivlLpsRange = 22;
        8'hbc : ivlLpsRange = 12;
        8'hbd : ivlLpsRange = 15;
        8'hbe : ivlLpsRange = 18;
        8'hbf : ivlLpsRange = 21;
        8'hc0 : ivlLpsRange = 12;
        8'hc1 : ivlLpsRange = 14;
        8'hc2 : ivlLpsRange = 17;
        8'hc3 : ivlLpsRange = 20;
        8'hc4 : ivlLpsRange = 11;
        8'hc5 : ivlLpsRange = 14;
        8'hc6 : ivlLpsRange = 16;
        8'hc7 : ivlLpsRange = 19;
        8'hc8 : ivlLpsRange = 11;
        8'hc9 : ivlLpsRange = 13;
        8'hca : ivlLpsRange = 15;
        8'hcb : ivlLpsRange = 18;
        8'hcc : ivlLpsRange = 10;
        8'hcd : ivlLpsRange = 12;
        8'hce : ivlLpsRange = 15;
        8'hcf : ivlLpsRange = 17;
        8'hd0 : ivlLpsRange = 10;
        8'hd1 : ivlLpsRange = 12;
        8'hd2 : ivlLpsRange = 14;
        8'hd3 : ivlLpsRange = 16;
        8'hd4 : ivlLpsRange = 09;
        8'hd5 : ivlLpsRange = 11;
        8'hd6 : ivlLpsRange = 13;
        8'hd7 : ivlLpsRange = 15;
        8'hd8 : ivlLpsRange = 09;
        8'hd9 : ivlLpsRange = 11;
        8'hda : ivlLpsRange = 12;
        8'hdb : ivlLpsRange = 14;
        8'hdc : ivlLpsRange = 08;
        8'hdd : ivlLpsRange = 10;
        8'hde : ivlLpsRange = 12;
        8'hdf : ivlLpsRange = 14;
        8'he0 : ivlLpsRange = 08;
        8'he1 : ivlLpsRange = 09;
        8'he2 : ivlLpsRange = 11;
        8'he3 : ivlLpsRange = 13;
        8'he4 : ivlLpsRange = 07;
        8'he5 : ivlLpsRange = 09;
        8'he6 : ivlLpsRange = 11;
        8'he7 : ivlLpsRange = 12;
        8'he8 : ivlLpsRange = 07;
        8'he9 : ivlLpsRange = 09;
        8'hea : ivlLpsRange = 10;
        8'heb : ivlLpsRange = 12;
        8'hec : ivlLpsRange = 07;
        8'hed : ivlLpsRange = 08;
        8'hee : ivlLpsRange = 10;
        8'hef : ivlLpsRange = 11;
        8'hf0 : ivlLpsRange = 06;
        8'hf1 : ivlLpsRange = 08;
        8'hf2 : ivlLpsRange = 09;
        8'hf3 : ivlLpsRange = 11;
        8'hf4 : ivlLpsRange = 06;
        8'hf5 : ivlLpsRange = 07;
        8'hf6 : ivlLpsRange = 09;
        8'hf7 : ivlLpsRange = 10;
        8'hf8 : ivlLpsRange = 06;
        8'hf9 : ivlLpsRange = 07;
        8'hfa : ivlLpsRange = 08;
        8'hfb : ivlLpsRange = 09;
        8'hfc : ivlLpsRange = 02;
        8'hfd : ivlLpsRange = 02;
        8'hfe : ivlLpsRange = 02;
        8'hff : ivlLpsRange = 02;
    endcase

`ifdef RANDOM_INIT
integer  seed;
integer random_val;
initial  begin
    seed                               = $get_initial_random_seed(); 
    random_val                         = $random(seed);
    ivlOffset_temp_r                   = {random_val[1:0],random_val[31:2],random_val[1:0],random_val[31:2]};
    ivlCurrRange_temp_r                = {random_val[3:0],random_val[31:4],random_val[3:0],random_val[31:4]};
end
`endif

endmodule

