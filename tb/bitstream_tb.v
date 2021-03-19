//--------------------------------------------------------------------------------------------------
// Design    : bvp
// Author(s) : qiu bin, shi tian qi
// Email     : chat1@126.com, tishi1@126.com
// Copyright (C) 2013-2017 qiu bin, shi tian qi
// All rights reserved
// Phone 15957074161
// QQ:1517642772
//-------------------------------------------------------------------------------------------------

`timescale 1ns / 1ns // timescale time_unit/time_presicion

module bitstream_tb;
reg rst;
reg dec_clk;

wire                                       m_axi_arready;
wire                                       m_axi_arvalid;
wire[3:0]                                  m_axi_arlen;
wire[31:0]                                 m_axi_araddr;
wire                                       m_axi_rready;
wire [63:0]                                m_axi_rdata;
wire                                       m_axi_rvalid;
wire                                       m_axi_rlast;
wire [5:0]                                 m_axi_arid;
wire [2:0]                                 m_axi_arsize;
wire [1:0]                                 m_axi_arburst;
wire [2:0]                                 m_axi_arprot;
wire [3:0]                                 m_axi_arcache;
wire [1:0]                                 m_axi_arlock;
wire [3:0]                                 m_axi_arqos;


wire                                       m_axi_awready;
wire [5:0]                                 m_axi_awid;
wire [31:0]                                m_axi_awaddr;
wire [3:0]                                 m_axi_awlen;
wire [2:0]                                 m_axi_awsize;
wire [1:0]                                 m_axi_awburst;
wire [1:0]                                 m_axi_awlock;
wire [3:0]                                 m_axi_awcache;
wire [2:0]                                 m_axi_awprot;
wire                                       m_axi_awvalid;

wire                                       m_axi_wready;
wire [5:0]                                 m_axi_wid;
wire [63:0]                                m_axi_wdata;
wire [7:0]                                 m_axi_wstrb;
wire                                       m_axi_wlast;
wire                                       m_axi_wvalid;

wire [5:0]                                 m_axi_bid;
wire [1:0]                                 m_axi_bresp;
wire                                       m_axi_bvalid;
wire                                       m_axi_bready;

wire [5:0]                                 m_axi_rrid;
wire [1:0]                                 m_axi_rresp;

integer fp_log;
integer fp_pred;
integer fp_intra_pred_chroma;
integer fp_tq_luma;
integer fp_tq_cb;
integer fp_tq_cr;
integer fp_filter;
integer fp_deblock;


initial begin
    rst = 0;
    #100 rst = 1;
    #100 rst = 0;
    #1000000000 $fclose(fp_log);
    #100       $fclose(fp_pred);
    #100       $fclose(fp_intra_pred_chroma);
    #100       $fclose(fp_tq_luma);
    #100       $fclose(fp_tq_cb);
    #100       $fclose(fp_tq_cr);
    #100       $fclose(fp_filter);
    #100       $fclose(fp_deblock);
end



always
begin
    #1 dec_clk = 0;
    #1 dec_clk = 1;
end

reg [7:0] stream_mem[2**28-1:0];

// read stream file
integer ch,fp_265,addr_265;
initial
begin
    addr_265 = 0;
    fp_265                = $fopen("in.265", "rb");
    fp_log                = $fopen("trace.log", "w");
    fp_pred               = $fopen("trace_pred.log","w");
    fp_intra_pred_chroma  = $fopen("trace_intra_pred_chroma.log","w");
    fp_tq_luma            = $fopen("trace_tq_luma.log","w");
    fp_tq_cb              = $fopen("trace_tq_cb.log","w");
    fp_tq_cr              = $fopen("trace_tq_cr.log","w");
    fp_filter             = $fopen("trace_sao.log","w");
    fp_deblock            = $fopen("trace_deblock.log","w");

    while(addr_265 < 200000000) begin
        ch = $fgetc(fp_265);
        if (ch >= 0 && ch <256) begin
            stream_mem[addr_265] = ch;
            addr_265 = addr_265 + 1;
        end
        else begin
            forever
                @(ch);
            end
    end


end

reg [1:0]  random_val;
always @ (posedge dec_clk)
begin
    random_val  <= $random()%4;
end

wire   [31:0]     stream_mem_addr;
wire   [ 7:0]     stream_data;
wire              stream_mem_rd;
wire              start_of_frame;
wire              end_of_frame;
wire   [63:0]     pic_num;
wire   [11:0]     pic_height;
wire   [12:0]     pic_width;
wire              write_yuv;
wire   [ 3:0]     cur_pic_dpb_slot;

assign stream_data = stream_mem[stream_mem_addr]; //async read

decode_stream decode_stream_inst(
    .clk                             (dec_clk),

    .rst                             (rst),
    .en                              (1'b1),

    .stream_mem_data_in              (stream_data),
    .stream_mem_valid                (random_val==0),
    .stream_mem_addr_out             (stream_mem_addr),
    .stream_mem_rd                   (stream_mem_rd),
    .stream_mem_end                  (1'b0),

    .pic_width_in_luma_samples       (pic_width), //max 4096
    .pic_height_in_luma_samples      (pic_height), //max 2160
    .pic_num                         (pic_num),
    .write_yuv                       (write_yuv),
    .cur_pic_dpb_slot                (cur_pic_dpb_slot),


    .ext_mem_init_done               (1'b1),
    .fd_log                          (fp_log),
    .fd_pred                         (fp_pred),
    .fd_intra_pred_chroma            (fp_intra_pred_chroma),
    .fd_tq_luma                      (fp_tq_luma),
    .fd_tq_cb                        (fp_tq_cb),
    .fd_tq_cr                        (fp_tq_cr),
    .fd_filter                       (fp_filter),
    .fd_deblock                      (fp_deblock),

    .m_axi_awready                   (m_axi_awready),
    .m_axi_awid                      (m_axi_awid),
    .m_axi_awaddr                    (m_axi_awaddr),
    .m_axi_awlen                     (m_axi_awlen),
    .m_axi_awsize                    (m_axi_awsize),
    .m_axi_awburst                   (m_axi_awburst),
    .m_axi_awlock                    (m_axi_awlock),
    .m_axi_awcache                   (m_axi_awcache),
    .m_axi_awprot                    (m_axi_awprot),
    .m_axi_awvalid                   (m_axi_awvalid),
   
    .m_axi_wready                    (m_axi_wready),
    .m_axi_wid                       (m_axi_wid),
    .m_axi_wdata                     (m_axi_wdata),
    .m_axi_wstrb                     (m_axi_wstrb),
    .m_axi_wlast                     (m_axi_wlast),
    .m_axi_wvalid                    (m_axi_wvalid),

    .m_axi_bid                       (m_axi_bid),
    .m_axi_bresp                     (m_axi_bresp),
    .m_axi_bvalid                    (m_axi_bvalid),
    .m_axi_bready                    (m_axi_bready),

    .m_axi_arready                   (m_axi_arready),
    .m_axi_arvalid                   (m_axi_arvalid), 
    .m_axi_arlen                     (m_axi_arlen),
    .m_axi_araddr                    (m_axi_araddr),
    .m_axi_rready                    (m_axi_rready),
    .m_axi_rdata                     (m_axi_rdata),
    .m_axi_rvalid                    (m_axi_rvalid),
    .m_axi_rlast                     (m_axi_rlast),
    .m_axi_arid                      (m_axi_arid),
    .m_axi_arsize                    (m_axi_arsize),
    .m_axi_arburst                   (m_axi_arburst),
    .m_axi_arprot                    (m_axi_arprot),
    .m_axi_arcache                   (m_axi_arcache),
    .m_axi_arlock                    (m_axi_arlock),
    .m_axi_arqos                     (m_axi_arqos),
    .m_axi_rrid                      (m_axi_rrid),
    .m_axi_rresp                     (m_axi_rresp)

);

ext_ram_32 ext_ram_32
(
    .m_axi_wclk                          (dec_clk),
    .m_axi_awready                       (m_axi_awready),
    .m_axi_awid                          (m_axi_awid),
    .m_axi_awaddr                        (m_axi_awaddr),
    .m_axi_awlen                         (m_axi_awlen),
    .m_axi_awsize                        (m_axi_awsize),
    .m_axi_awburst                       (m_axi_awburst),
    .m_axi_awlock                        (m_axi_awlock),
    .m_axi_awcache                       (m_axi_awcache),
    .m_axi_awprot                        (m_axi_awprot),
    .m_axi_awvalid                       (m_axi_awvalid),
   
    .m_axi_wready                        (m_axi_wready),
    .m_axi_wid                           (m_axi_wid),
    .m_axi_wdata                         (m_axi_wdata),
    .m_axi_wstrb                         (m_axi_wstrb),
    .m_axi_wlast                         (m_axi_wlast),
    .m_axi_wvalid                        (m_axi_wvalid),
   
    .m_axi_bid                           (m_axi_bid),
    .m_axi_bresp                         (m_axi_bresp),
    .m_axi_bvalid                        (m_axi_bvalid),
    .m_axi_bready                        (m_axi_bready),

    .m_axi_clk                           (dec_clk),
    .m_axi_rst                           (rst),
    .m_axi_arready                       (m_axi_arready),
    .m_axi_arvalid                       (m_axi_arvalid),
    .m_axi_arlen                         (m_axi_arlen),
    .m_axi_araddr                        (m_axi_araddr),
    .m_axi_rready                        (m_axi_rready),
    .m_axi_rdata                         (m_axi_rdata),
    .m_axi_rvalid                        (m_axi_rvalid),
    .m_axi_rlast                         (m_axi_rlast),
    .m_axi_arid                          (m_axi_arid),
    .m_axi_arsize                        (m_axi_arsize),
    .m_axi_arburst                       (m_axi_arburst),
    .m_axi_arprot                        (m_axi_arprot),
    .m_axi_arcache                       (m_axi_arcache),
    .m_axi_arlock                        (m_axi_arlock),
    .m_axi_arqos                         (m_axi_arqos),
    .m_axi_rrid                          (m_axi_rrid),
    .m_axi_rresp                         (m_axi_rresp),

    .write_to_file_start                 (write_yuv),
    .pic_num                             (pic_num),
    .pic_height                          (pic_height),
    .pic_width                           (pic_width),
    .cur_pic_dpb_slot                    (cur_pic_dpb_slot)
);


endmodule


