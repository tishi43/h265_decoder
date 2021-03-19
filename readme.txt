H265 decoder

Write in verilog and system verilog, verified on FPGA board with Xilinx ZYNQ7035, running up to 225MHZ.

1. Content
Folder "src" contains all decode source file.
Folder "tb" contains test bench file, ext_ram_32.v emulate ddr with axi3 interface.
Folder "pli_fputc" is verilog pli used to write output bin to file when run simulation.

2. How to use
Simulation: add all test bench and source code file to your simulation project source, for example, modelsim.
put the test file, in.265 to your simulation project folder.
then run, for example, for modelsim, run "vsim -pli pli_fputc.dll bitstream_tb".
The output is out.yuv, and some log files.

Run on FPGA board: add the source file in "src" folder to your FPGA project.
The top file is decode_stream.sv.
Two interfaces, the stream_mem_xxx is for you to feed H265 bitstream to decoder, typically use a fifo or axi3/4 stream.
The m_axi_xxx is axi3 master interface, connect it to your axi3 slave with a memory.


module decode_stream (
 //global signals
 input  wire                              clk,
 input  wire                              rst,
 input  wire                              en,

 //interface to bitstream memory or fifo
 input  wire [ 7:0]                       stream_mem_data_in,
 input  wire                              stream_mem_valid,
 output wire [31:0]                       stream_mem_addr_out,
 output wire                              stream_mem_rd, // request stream read by read_nalu
 input  wire                              stream_mem_end, // end of stream reached

 output wire [12:0]                       pic_width_in_luma_samples, //max 4096
 output wire [11:0]                       pic_height_in_luma_samples, //max 2160
 output wire [63:0]                       pic_num,
 output wire [ 3:0]                       cur_pic_dpb_slot,
 output wire                              write_yuv,

 input  wire                              ext_mem_init_done,
 input  wire [31:0]                       fd_log,
 input  wire [31:0]                       fd_pred,
 input  wire [31:0]                       fd_intra_pred_chroma,
 input  wire [31:0]                       fd_tq_luma,
 input  wire [31:0]                       fd_tq_cb,
 input  wire [31:0]                       fd_tq_cr,
 input  wire [31:0]                       fd_filter,
 input  wire [31:0]                       fd_deblock,

 //axi bus read if
 input  wire                              m_axi_arready,
 output wire                              m_axi_arvalid,
 output wire [ 3:0]                       m_axi_arlen,
 output wire [31:0]                       m_axi_araddr,
 output wire [ 5:0]                       m_axi_arid,
 output wire [ 2:0]                       m_axi_arsize,
 output wire [ 1:0]                       m_axi_arburst,
 output wire [ 2:0]                       m_axi_arprot,
 output wire [ 3:0]                       m_axi_arcache,
 output wire [ 1:0]                       m_axi_arlock,
 output wire [ 3:0]                       m_axi_arqos,

 output wire                              m_axi_rready,
 input  wire [63:0]                       m_axi_rdata,
 input  wire                              m_axi_rvalid,
 input  wire                              m_axi_rlast,
 //axi bus write if
 input  wire                              m_axi_awready, // Indicates slave is ready to accept a
 output wire [ 5:0]                       m_axi_awid,    // Write ID
 output wire [31:0]                       m_axi_awaddr,  // Write address
 output wire [ 3:0]                       m_axi_awlen,   // Write Burst Length
 output wire [ 2:0]                       m_axi_awsize,  // Write Burst size
 output wire [ 1:0]                       m_axi_awburst, // Write Burst type
 output wire [ 1:0]                       m_axi_awlock,  // Write lock type
 output wire [ 3:0]                       m_axi_awcache, // Write Cache type
 output wire [ 2:0]                       m_axi_awprot,  // Write Protection type
 output wire                              m_axi_awvalid, // Write address valid

 input  wire                              m_axi_wready,  // Write data ready
 output wire [ 5:0]                       m_axi_wid,     // Write ID tag
 output wire [63:0]                       m_axi_wdata,    // Write data
 output wire [ 7:0]                       m_axi_wstrb,    // Write strobes
 output wire                              m_axi_wlast,    // Last write transaction
 output wire                              m_axi_wvalid,   // Write valid

 input  wire [ 5:0]                       m_axi_bid,     // Response ID
 input  wire [ 1:0]                       m_axi_bresp,   // Write response
 input  wire                              m_axi_bvalid,  // Write reponse valid
 output wire                              m_axi_bready,  // Response ready
 output wire [ 5:0]                       m_axi_rrid,
 input  wire [ 1:0]                       m_axi_rresp

);






