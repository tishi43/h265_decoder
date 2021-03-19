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


module ext_ram_32
(
    input  wire                       m_axi_wclk, 
    output wire                       m_axi_awready, // Indicates slave is ready to accept a 
    input  wire  [ 5:0]               m_axi_awid,    // Write ID
    input  wire  [31:0]               m_axi_awaddr,  // Write address
    input  wire  [ 3:0]               m_axi_awlen,   // Write Burst Length
    input  wire  [ 2:0]               m_axi_awsize,  // Write Burst size
    input  wire  [ 1:0]               m_axi_awburst, // Write Burst type
    input  wire  [ 1:0]               m_axi_awlock,  // Write lock type
    input  wire  [ 3:0]               m_axi_awcache, // Write Cache type
    input  wire  [ 2:0]               m_axi_awprot,  // Write Protection type
    input  wire                       m_axi_awvalid, // Write address valid

    output wire                       m_axi_wready,  // Write data ready
    input  wire  [ 5:0]               m_axi_wid,     // Write ID tag
    input  wire  [63:0]               m_axi_wdata,    // Write data
    input  wire  [ 7:0]               m_axi_wstrb,    // Write strobes
    input  wire                       m_axi_wlast,    // Last write transaction   
    input  wire                       m_axi_wvalid,   // Write valid

    output wire  [ 5:0]               m_axi_bid,     // Response ID
    output wire  [ 1:0]               m_axi_bresp,   // Write response
    input  wire                       m_axi_bvalid,  // Write reponse valid
    input  wire                       m_axi_bready,  // Response ready

    input  wire                       m_axi_clk,
    input  wire                       m_axi_rst,
    output wire                       m_axi_arready,
    input  wire                       m_axi_arvalid, 
    input  wire  [ 3:0]               m_axi_arlen,
    input  wire  [31:0]               m_axi_araddr,
    input  wire                       m_axi_rready,
    output reg   [63:0]               m_axi_rdata,
    output wire                       m_axi_rvalid,
    output wire                       m_axi_rlast,
    input  wire  [ 5:0]               m_axi_arid,
    input  wire  [ 2:0]               m_axi_arsize,
    input  wire  [ 1:0]               m_axi_arburst,
    input  wire  [ 2:0]               m_axi_arprot,
    input  wire  [ 3:0]               m_axi_arcache,
    input  wire  [ 1:0]               m_axi_arlock,
    input  wire  [ 3:0]               m_axi_arqos,
    input  wire  [ 5:0]               m_axi_rrid,
    output wire  [ 1:0]               m_axi_rresp,

    input  wire                       write_to_file_start,
    input  wire  [63:0]               pic_num,
    input  wire  [11:0]               pic_height,
    input  wire  [12:0]               pic_width,
    input  wire  [ 3:0]               cur_pic_dpb_slot

);


reg[31:0] ram[2**28-1:0];

//integer addr_265;
//initial begin
//  #13940 $display("%x %x %x %x",ram[166199296],ram[166199297],ram[166199298],ram[166199299]);
//  #0 $display("%x %x %x %x",ram[166199300],ram[166199301],ram[166199302],ram[166199303]);
//  #0 $display("%x %x %x %x",ram[166199304],ram[166199305],ram[166199306],ram[166199307]);
//  #0 $display("%x %x %x %x",ram[166199308],ram[166199309],ram[166199310],ram[166199311]);
//  #0 $display("%x %x %x %x",ram[166199312],ram[166199313],ram[166199314],ram[166199315]);
//  #0 $display("%x %x %x %x",ram[166199316],ram[166199317],ram[166199318],ram[166199319]);
//  #0 $display("%x %x %x %x",ram[166199320],ram[166199321],ram[166199322],ram[166199323]);
//  #0 $display("%x %x %x %x",ram[166199324],ram[166199325],ram[166199326],ram[166199327]);
//  #0 $display("%x %x %x %x",ram[166201344],ram[166201345],ram[166201346],ram[166201347]);
//end
//27a02000/4=
//4096/4*8=8192=0x2000

//initial begin
//  addr_265=32'h09400000;
//  #16000     while(addr_265 < 32'h09400010) begin
//        $display("%d %d %d %d",ram[addr_265][7:0],ram[addr_265][15:8],
//                               ram[addr_265][23:16],ram[addr_265][31:24]);
//        addr_265=addr_265+1;
//    end
//end


reg   debug_flag1;
reg   debug_flag2;
always @ (posedge m_axi_clk)
if (m_axi_rst) begin
    debug_flag1          <= 1;
    debug_flag2          <= 1;
end else begin
    if (debug_flag1==1) begin
        //0x20900000+ y*1024+x = 0x20900000+16*2048+189=546,341,053/4=136585263
        if (ram[136585263][15:8]==8'h7e) begin
            $display("%t ddr 7e",$time);
            debug_flag1  <= 0;
        end
    end
    if (debug_flag2==1) begin
        if (ram[136585263][15:8]==8'h7f) begin
            $display("%t ddr 7f",$time);
            debug_flag2  <= 0;
        end
    end
end

reg       [31:0]  rvalid_cycles;
always @ (posedge m_axi_clk)
if (m_axi_rst) begin
    rvalid_cycles     <= 0;
end else begin
    if (m_axi_rvalid)
        rvalid_cycles <= rvalid_cycles+1;
end


integer           fp_w;
reg       [7:0]   data;
integer           i,j,idx;
integer           frame_size;
integer           y_addr;
integer           u_addr;
integer           v_addr;

initial
begin

    $fputc(0,0);
    //fp_w = $fopen("out.txt","w");

    while(1) begin
        @ (posedge write_to_file_start);
        y_addr = cur_pic_dpb_slot==0?`DDR_BASE_DPB0:
                 (cur_pic_dpb_slot==1?`DDR_BASE_DPB1:(
                  cur_pic_dpb_slot==2?`DDR_BASE_DPB2:(
                  cur_pic_dpb_slot==3?`DDR_BASE_DPB3:(
                  cur_pic_dpb_slot==4?`DDR_BASE_DPB4:
                  `DDR_BASE_DPB5))));
        u_addr = cur_pic_dpb_slot==0?`DDR_BASE_DPB0+`CB_OFFSET:
                 (cur_pic_dpb_slot==1?`DDR_BASE_DPB1+`CB_OFFSET:(
                  cur_pic_dpb_slot==2?`DDR_BASE_DPB2+`CB_OFFSET:(
                  cur_pic_dpb_slot==3?`DDR_BASE_DPB3+`CB_OFFSET:(
                  cur_pic_dpb_slot==4?`DDR_BASE_DPB4+`CB_OFFSET:
                  `DDR_BASE_DPB5+`CB_OFFSET))));
        v_addr = cur_pic_dpb_slot==0?`DDR_BASE_DPB0+`CR_OFFSET:
                 (cur_pic_dpb_slot==1?`DDR_BASE_DPB1+`CR_OFFSET:(
                  cur_pic_dpb_slot==2?`DDR_BASE_DPB2+`CR_OFFSET:(
                  cur_pic_dpb_slot==3?`DDR_BASE_DPB3+`CR_OFFSET:(
                  cur_pic_dpb_slot==4?`DDR_BASE_DPB4+`CR_OFFSET:
                  `DDR_BASE_DPB5+`CR_OFFSET))));
        for (i=0; i< pic_height; i=i+1) begin
            for (j= 0; j < pic_width; j= j + 1) begin
                idx = y_addr + (i<<`max_x_bits)+j;
                if (idx[1:0] == 0)
                    data = ram[idx/4][7:0];
                else if (idx[1:0] == 1)
                    data = ram[idx/4][15:8];
                else if (idx[1:0] == 2)
                    data = ram[idx/4][23:16];
                else
                    data = ram[idx/4][31:24];

                $fputc(data,1);
                //$fwrite(fp_w,"%02x",data);
            end
        end

        for (i=0; i< pic_height/2; i=i+1) begin
            for (j= 0; j < pic_width/2; j= j + 1) begin
                idx = u_addr + (i<<(`max_x_bits-1))+j;
                if (idx[1:0] == 0)
                    data = ram[idx/4][7:0];
                else if (idx[1:0] == 1)
                    data = ram[idx/4][15:8];
                else if (idx[1:0] == 2)
                    data = ram[idx/4][23:16];
                else
                    data = ram[idx/4][31:24];

                $fputc(data,1);
                //$fwrite(fp_w,"%02x",data);
            end
        end

        for (i=0; i< pic_height/2; i=i+1) begin
            for (j= 0; j < pic_width/2; j= j + 1) begin
                idx = v_addr + (i<<(`max_x_bits-1))+j;
                if (idx[1:0] == 0)
                    data = ram[idx/4][7:0];
                else if (idx[1:0] == 1)
                    data = ram[idx/4][15:8];
                else if (idx[1:0] == 2)
                    data = ram[idx/4][23:16];
                else
                    data = ram[idx/4][31:24];

                $fputc(data,1);
                //$fwrite(fp_w,"%02x",data);
            end
        end

        $fputc(0,2);
        //$fflush(fp_w);
        $display("%t frame write done picnum%d",$time,pic_num[31:0]);
    end
end


wire [31:0] wr_addr_int;
reg [31:0] wr_addr_int_reg;
wire [31:0] rd_addr_int;


wire aw_handshake = m_axi_awready && m_axi_awvalid;
wire w_handshake = m_axi_wready && m_axi_wvalid;

always @(posedge m_axi_wclk)
if (w_handshake)
    wr_addr_int_reg <= wr_addr_int;


/*
assign debug_addr =  'hDB0B0;
reg [63:0] debug_data;

always @* begin
    debug_data = {ram[debug_addr/4+1], ram[debug_addr/4]};
end
*/
always @ (*)
     m_axi_rdata <= {ram[rd_addr_int/4+1], ram[rd_addr_int/4]};


/////////////////////////////////////////////////
//read
reg             rd_empty;
wire            rvalid;
reg             rvalid_and_reg;
wire    [31:0]  m_axi_araddr_q;
wire    [ 3:0]  m_axi_arlen_q;
reg     [15:0]  prep_data_ready; //ar_handshake之后ddr至少延迟1周期准备好数据

wire ar_handshake = m_axi_arready && m_axi_arvalid;
wire r_handshake = m_axi_rready && m_axi_rvalid;

reg   [3:0]  ar_ram_wr_addr;
reg   [3:0]  ar_ram_wr_addr_save;
reg   [3:0]  ar_ram_rd_addr;
wire         inc_ar_ram_rd_addr;
reg   [7:0]  rd_addr_offset;

always @(posedge m_axi_clk or posedge m_axi_rst)
if (m_axi_rst) begin
    ar_ram_wr_addr                       <= 0;
    prep_data_ready                      <= 16'd0;
end else if (ar_handshake) begin
    ar_ram_wr_addr                       <= ar_ram_wr_addr + 1'b1;
    prep_data_ready[ar_ram_wr_addr]      <= 0;
    ar_ram_wr_addr_save                  <= ar_ram_wr_addr;
end else begin
    prep_data_ready[ar_ram_wr_addr_save] <= 1;
end

always @(posedge m_axi_clk or posedge m_axi_rst)
if (m_axi_rst)
    ar_ram_rd_addr <= 0;
else if (inc_ar_ram_rd_addr)
    ar_ram_rd_addr <= ar_ram_rd_addr + 1'b1;


reg [1:0]  random_val;
always @ (posedge m_axi_clk)
begin
    random_val  <= $random()%4;
end

reg   random_val0;
always @ (posedge m_axi_clk)
begin
    random_val0  <= $random()%2;
end



assign m_axi_rvalid = rvalid_and_reg & rvalid;
assign m_axi_arready = ~(ar_ram_rd_addr[3] != ar_ram_wr_addr[3] && ar_ram_rd_addr[2:0] == ar_ram_wr_addr[2:0]) && (random_val0==1);

reg rd_empty_reg;
always @(*)
    rd_empty <= ar_ram_rd_addr[3] == ar_ram_wr_addr[3] && ar_ram_rd_addr[2:0] == ar_ram_wr_addr[2:0];

always @(posedge m_axi_clk)
    rd_empty_reg <= ar_ram_rd_addr[3] == ar_ram_wr_addr[3] && ar_ram_rd_addr[2:0] == ar_ram_wr_addr[2:0];

assign rvalid = ~rd_empty && ~rd_empty_reg;


//always @ (*)
//begin
//    rvalid_and_reg = prep_data_ready[ar_ram_rd_addr];
//end

always @ (*)
begin
    rvalid_and_reg = /*prep_data_ready[ar_ram_rd_addr]&&*/(random_val==0);
end

//always @(posedge m_axi_clk)
//    rvalid_and_reg <= 1;//$random() % 16;    //binq



dp_ram_async_read #(32+4, 4) ar_ram(
    .aclr(m_axi_rst),
    .data({m_axi_araddr,m_axi_arlen}),
    .rdaddress(ar_ram_rd_addr ), 
    .wraddress(ar_ram_wr_addr),
    .wren(ar_handshake), 
    .rdclock(m_axi_clk), 
    .wrclock(m_axi_clk),
    .q({m_axi_araddr_q,m_axi_arlen_q})
);

assign rd_addr_int = m_axi_araddr_q + rd_addr_offset*8;
assign m_axi_rlast = rd_addr_offset == m_axi_arlen_q && ~rd_empty;
assign inc_ar_ram_rd_addr = m_axi_rlast && r_handshake;

always @(posedge m_axi_clk or posedge m_axi_rst)
if (m_axi_rst) begin
    rd_addr_offset <= 0;
end
else begin
    if (r_handshake && rd_addr_offset < m_axi_arlen_q) begin
        rd_addr_offset <= rd_addr_offset + 1;
    end
    else if (r_handshake)
        rd_addr_offset <= 0;
end

/////////////////////////////////////////////////
//write, assume that addr always comes first
reg rd_empty1;
wire [31:0] m_axi_awaddr_q;
wire [3:0] m_axi_awlen_q;




reg [5:0] aw_ram_wr_addr;
reg [5:0] aw_ram_rd_addr;
wire inc_aw_ram_rd_addr;
reg [7:0] wr_addr_offset;
reg wr_full;

always @(posedge m_axi_wclk)
if (m_axi_rst)
    aw_ram_wr_addr <= 0;
else if (aw_handshake) //aw_handshake之后，ram地址+1，ddr地址已存到未+1的那个ram地址
    aw_ram_wr_addr <= aw_ram_wr_addr + 1'b1;

always @(posedge m_axi_wclk)
if (m_axi_rst)
    aw_ram_rd_addr <= 0;
else if (inc_aw_ram_rd_addr)
    aw_ram_rd_addr <= aw_ram_rd_addr + 1'b1;

always @(*)
    wr_full <= aw_ram_rd_addr[3] != aw_ram_wr_addr[3] && aw_ram_rd_addr[2:0] == aw_ram_wr_addr[2:0];
reg awready_and_reg;
reg wready_and_reg;

always @(posedge m_axi_wclk)begin
    awready_and_reg <= 1/*$random() % 3 == 0*/;
    wready_and_reg <= 1/*$random() % 3 == 0*/;
end

assign m_axi_wready = wready_and_reg;
assign m_axi_awready = ~wr_full&&awready_and_reg;

dp_ram_async_read #(32+4, 6) aw_ram(
    .aclr(m_axi_rst),
    .data({m_axi_awaddr,m_axi_awlen}),
    .rdaddress(aw_ram_rd_addr ), 
    .wraddress(aw_ram_wr_addr),
    .wren(aw_handshake), 
    .rdclock(m_axi_wclk), 
    .wrclock(m_axi_wclk),
    .q({m_axi_awaddr_q,m_axi_awlen_q})
);

assign wr_addr_int = m_axi_awaddr_q + wr_addr_offset*8;
assign inc_aw_ram_rd_addr = m_axi_wlast && w_handshake;

always @(posedge m_axi_wclk)
if (m_axi_rst) begin
    wr_addr_offset <= 0;
end
else begin
    if (w_handshake && wr_addr_offset < m_axi_awlen_q) begin
        wr_addr_offset <= wr_addr_offset + 1;
    end
    else if (w_handshake)
        wr_addr_offset <= 0;
end

//write
always @ (posedge m_axi_wclk)
if (w_handshake) begin
    if (m_axi_wstrb[0])
        ram[wr_addr_int/4][7:0] <= m_axi_wdata[7:0];
    if (m_axi_wstrb[1])
        ram[wr_addr_int/4][15:8] <= m_axi_wdata[15:8];
    if (m_axi_wstrb[2])
        ram[wr_addr_int/4][23:16] <= m_axi_wdata[23:16];
    if (m_axi_wstrb[3])
        ram[wr_addr_int/4][31:24] <= m_axi_wdata[31:24];
    if (m_axi_wstrb[4])
        ram[wr_addr_int/4+1][7:0] <= m_axi_wdata[39:32];
    if (m_axi_wstrb[5])
        ram[wr_addr_int/4+1][15:8] <= m_axi_wdata[47:40];
    if (m_axi_wstrb[6])
        ram[wr_addr_int/4+1][23:16] <= m_axi_wdata[55:48];
    if (m_axi_wstrb[7])
        ram[wr_addr_int/4+1][31:24] <= m_axi_wdata[63:56];
end

endmodule

    
