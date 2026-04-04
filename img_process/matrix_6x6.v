// 6x6 矩阵生成（基于 matrix_3x3 改写）
module matrix_6x6
#(
    parameter IMG_WIDTH  = 11'd1920,
    parameter IMG_HEIGHT = 11'd1080
)
(
    input  wire        video_clk,
    input  wire        rst_n,
        
    input  wire        video_vs,
    input  wire        video_de,
    input  wire        video_data,

    // 6x6 矩阵输出
    output wire        matrix_de,			
    output reg         matrix11, matrix12, matrix13, matrix14, matrix15, matrix16,
    output reg         matrix21, matrix22, matrix23, matrix24, matrix25, matrix26,
    output reg         matrix31, matrix32, matrix33, matrix34, matrix35, matrix36,
    output reg         matrix41, matrix42, matrix43, matrix44, matrix45, matrix46,
    output reg         matrix51, matrix52, matrix53, matrix54, matrix55, matrix56,
    output reg         matrix61, matrix62, matrix63, matrix64, matrix65, matrix66
);

// 行列计数
reg [10:0] x_cnt;
reg [10:0] y_cnt;

always@(posedge video_clk or negedge rst_n) begin
    if(!rst_n)
        x_cnt <= 11'd0;
    else if(x_cnt == IMG_WIDTH - 1)
        x_cnt <= 11'd0;
    else if(video_de)
        x_cnt <= x_cnt + 1'b1;
	else
		x_cnt	<=	x_cnt;
end

always@(posedge video_clk or negedge rst_n) begin
    if(!rst_n)
        y_cnt <= 11'd0;
    else if(y_cnt == IMG_HEIGHT - 1 && x_cnt == IMG_WIDTH - 1)
        y_cnt <= 11'd0;
    else if(x_cnt == IMG_WIDTH - 1)
        y_cnt <= y_cnt + 1'b1;
	else
		y_cnt	<=	y_cnt;
	
end

// 6x6 窗口：首尾 5 行无法构成
wire wr_fifo_en = video_de && (y_cnt < IMG_HEIGHT-1);
wire rd_fifo_en = video_de && (y_cnt > 4);   // 至少已有 5 行历史

// 数据打一拍，与 de_d0 对齐
reg [7:0] video_data_1d;
reg wr_fifo_en_1d, wr_fifo_en_2d, wr_fifo_en_3d, wr_fifo_en_4d;

always@(posedge video_clk or negedge rst_n) begin
    if(!rst_n) begin
        video_data_1d  <= 8'd0;
        wr_fifo_en_1d  <= 1'b0;
        wr_fifo_en_2d  <= 1'b0;
        wr_fifo_en_3d  <= 1'b0;
        wr_fifo_en_4d  <= 1'b0;
    end else begin
        video_data_1d  <= video_data;
        wr_fifo_en_1d  <= wr_fifo_en;
        wr_fifo_en_2d  <= wr_fifo_en_1d;
        wr_fifo_en_3d  <= wr_fifo_en_2d;
        wr_fifo_en_4d  <= wr_fifo_en_3d;
    end
end

// 行缓：5 条 FIFO，配合当前行组成 6 行
wire [7:0] line6_data;
wire [7:0] line5_data;
wire [7:0] line4_data;
wire [7:0] line3_data;
wire [7:0] line2_data;
wire [7:0] line1_data;

assign line6_data = video_data_1d;

fifo_line_buf fifo1 (
  .wr_clk(video_clk), .wr_rst(~rst_n),
  .wr_en(wr_fifo_en),      .wr_data(video_data),
  .wr_full(), .almost_full(),
  .rd_clk(video_clk), .rd_rst(~rst_n),
  .rd_en(rd_fifo_en),      .rd_data(line5_data),
  .rd_empty(), .almost_empty()
);

fifo_line_buf fifo2 (
  .wr_clk(video_clk), .wr_rst(~rst_n),
  .wr_en(wr_fifo_en_1d),   .wr_data(line5_data),
  .wr_full(), .almost_full(),
  .rd_clk(video_clk), .rd_rst(~rst_n),
  .rd_en(rd_fifo_en),      .rd_data(line4_data),
  .rd_empty(), .almost_empty()
);

fifo_line_buf fifo3 (
  .wr_clk(video_clk), .wr_rst(~rst_n),
  .wr_en(wr_fifo_en_2d),   .wr_data(line4_data),
  .wr_full(), .almost_full(),
  .rd_clk(video_clk), .rd_rst(~rst_n),
  .rd_en(rd_fifo_en),      .rd_data(line3_data),
  .rd_empty(), .almost_empty()
);

fifo_line_buf fifo4 (
  .wr_clk(video_clk), .wr_rst(~rst_n),
  .wr_en(wr_fifo_en_3d),   .wr_data(line3_data),
  .wr_full(), .almost_full(),
  .rd_clk(video_clk), .rd_rst(~rst_n),
  .rd_en(rd_fifo_en),      .rd_data(line2_data),
  .rd_empty(), .almost_empty()
);

fifo_line_buf fifo5 (
  .wr_clk(video_clk), .wr_rst(~rst_n),
  .wr_en(wr_fifo_en_4d),   .wr_data(line2_data),
  .wr_full(), .almost_full(),
  .rd_clk(video_clk), .rd_rst(~rst_n),
  .rd_en(rd_fifo_en),      .rd_data(line1_data),
  .rd_empty(), .almost_empty()
);

// DE 延迟 5clk（6 列移位需延迟 N-1）
reg video_de_d0, video_de_d1, video_de_d2, video_de_d3, video_de_d4;
always @(posedge video_clk or negedge rst_n) begin
    if (!rst_n) begin
        video_de_d0 <= 1'b0;
        video_de_d1 <= 1'b0;
        video_de_d2 <= 1'b0;
        video_de_d3 <= 1'b0;
        video_de_d4 <= 1'b0;
        
    end else begin
        video_de_d0 <= video_de;      // 第 1 拍
        video_de_d1 <= video_de_d0;   // 第 2 拍
        video_de_d2 <= video_de_d1;   // 第 3 拍
        video_de_d3 <= video_de_d2;   // 第 4 拍
        video_de_d4 <= video_de_d3;   // 第 5 拍
        
    end
end
assign matrix_de = video_de_d4;

// 矩阵数据生成（每行 6 级移位）
always@(posedge video_clk or negedge rst_n) begin
	if(!rst_n) begin
		{matrix11,matrix12,matrix13,matrix14,matrix15,matrix16} <= 6'd0;
		{matrix21,matrix22,matrix23,matrix24,matrix25,matrix26} <= 6'd0;
		{matrix31,matrix32,matrix33,matrix34,matrix35,matrix36} <= 6'd0;
		{matrix41,matrix42,matrix43,matrix44,matrix45,matrix46} <= 6'd0;
		{matrix51,matrix52,matrix53,matrix54,matrix55,matrix56} <= 6'd0;
		{matrix61,matrix62,matrix63,matrix64,matrix65,matrix66} <= 6'd0;
	end
	else if(video_de_d0) begin
		{matrix11,matrix12,matrix13,matrix14,matrix15,matrix16} <= {matrix12,matrix13,matrix14,matrix15,matrix16,line1_data};
		{matrix21,matrix22,matrix23,matrix24,matrix25,matrix26} <= {matrix22,matrix23,matrix24,matrix25,matrix26,line2_data};
		{matrix31,matrix32,matrix33,matrix34,matrix35,matrix36} <= {matrix32,matrix33,matrix34,matrix35,matrix36,line3_data};
		{matrix41,matrix42,matrix43,matrix44,matrix45,matrix46} <= {matrix42,matrix43,matrix44,matrix45,matrix46,line4_data};
		{matrix51,matrix52,matrix53,matrix54,matrix55,matrix56} <= {matrix52,matrix53,matrix54,matrix55,matrix56,line5_data};
		{matrix61,matrix62,matrix63,matrix64,matrix65,matrix66} <= {matrix62,matrix63,matrix64,matrix65,matrix66,line6_data};
	end
	else begin
		{matrix11,matrix12,matrix13,matrix14,matrix15,matrix16} <= 6'd0;
		{matrix21,matrix22,matrix23,matrix24,matrix25,matrix26} <= 6'd0;
		{matrix31,matrix32,matrix33,matrix34,matrix35,matrix36} <= 6'd0;
		{matrix41,matrix42,matrix43,matrix44,matrix45,matrix46} <= 6'd0;
		{matrix51,matrix52,matrix53,matrix54,matrix55,matrix56} <= 6'd0;
		{matrix61,matrix62,matrix63,matrix64,matrix65,matrix66} <= 6'd0;
	end
end

endmodule