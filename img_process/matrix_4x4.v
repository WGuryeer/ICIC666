// 4x4 矩阵生成，接口和计数风格与 matrix_3x3 保持一致
module matrix_4x4 #(
    parameter IMG_WIDTH  = 11'd1920,
    parameter IMG_HEIGHT = 11'd1080
)(
    input  wire       video_clk,
    input  wire       rst_n,
    input  wire       video_vs,
    input  wire       video_de,
    input  wire       video_data,

    output wire       matrix_de,  // 相对 video_de 延迟 3clk
    output reg        matrix11, matrix12, matrix13, matrix14,//1bit
    output reg        matrix21, matrix22, matrix23, matrix24,
    output reg        matrix31, matrix32, matrix33, matrix34,
    output reg        matrix41, matrix42, matrix43, matrix44
);

//---------------- 行列计数（仅用 DE 推进） ----------------
reg	[10:0]	x_cnt;
reg	[10:0]	y_cnt;
//行计数
always@(posedge video_clk or negedge rst_n)	begin
	if(!rst_n)
		x_cnt	<=	11'd0;
	else	if(x_cnt == IMG_WIDTH - 1)//计数一行
		x_cnt	<=	11'd0;
	else	if(video_de)	//数据有效
		x_cnt	<=	x_cnt + 1'b1;
	else
		x_cnt	<=	x_cnt;
end

//列计数
always@(posedge video_clk or negedge rst_n)	begin
	if(!rst_n)
		y_cnt	<=	11'd0;
	else	if(y_cnt == IMG_HEIGHT - 1 && x_cnt == IMG_WIDTH - 1)//计数一帧
		y_cnt	<=	11'd0;
	else	if(x_cnt == IMG_WIDTH - 1)	//数据有效
		y_cnt	<=	y_cnt + 1'b1;
	else
		y_cnt	<=	y_cnt;
end


// 使能：要形成 4 行窗口，需要至少已有 3 行历史
wire wr_fifo_en = video_de && (y_cnt < IMG_HEIGHT-1);
wire rd_fifo_en = video_de && (y_cnt > 1); // 第 3 行开始读

//---------------- 写使能与数据打拍 ----------------
reg wr_en_d1, wr_en_d2;
reg video_data_d1;
always @(posedge video_clk or negedge rst_n) begin
    if (!rst_n) begin
        wr_en_d1      <= 1'b0;
        wr_en_d2      <= 1'b0;
        video_data_d1 <= 8'd0;
    end else begin
        wr_en_d1      <= wr_fifo_en;    // 给 FIFO2
        wr_en_d2      <= wr_en_d1;      // 给 FIFO3
        video_data_d1 <= video_data;    // 当前行同步打拍
    end
end

//---------------- 三条行缓 FIFO ----------------
wire [7:0] line4_data;
wire [7:0] line3_data;
wire [7:0] line2_data;
wire [7:0] line1_data;
//通过3个FIFO与当前的输入一起构成4*4矩阵
assign line4_data = video_data_d1;

fifo_line_buf fifo1 (
    .wr_clk(video_clk), .wr_rst(~rst_n),
    .wr_en (wr_fifo_en),     .wr_data(video_data),
    .rd_clk(video_clk), .rd_rst(~rst_n),
    .rd_en (rd_fifo_en),     .rd_data(line3_data)
);

fifo_line_buf fifo2 (
    .wr_clk(video_clk), .wr_rst(~rst_n),
    .wr_en (wr_en_d1),       .wr_data(line3_data),
    .rd_clk(video_clk), .rd_rst(~rst_n),
    .rd_en (rd_fifo_en),     .rd_data(line2_data)
);

fifo_line_buf fifo3 (
    .wr_clk(video_clk), .wr_rst(~rst_n),
    .wr_en (wr_en_d2),       .wr_data(line2_data),
    .rd_clk(video_clk), .rd_rst(~rst_n),
    .rd_en (rd_fifo_en),     .rd_data(line1_data)
);

//---------------- 数据延迟 de延迟  vs可以不管：3clk 对齐 4 列移位 ----------------
reg video_de_d0;
reg video_de_d1;
reg video_de_d2;

always @(posedge video_clk or negedge rst_n) begin
    if (!rst_n) begin
        video_de_d0 <= 1'b0;
        video_de_d1 <= 1'b0;
        video_de_d2 <= 1'b0;
    end else begin
        video_de_d0 <= video_de;      // 第 1 拍
        video_de_d1 <= video_de_d0;   // 第 2 拍
        video_de_d2 <= video_de_d1;   // 第 3 拍
    end
end

assign matrix_de = video_de_d2; // 延迟 3clk

//---------------- 4×4 矩阵生成（列移位 4 级） ----------------
always @(posedge video_clk or negedge rst_n) begin
    if (!rst_n) begin
        {matrix11,matrix12,matrix13,matrix14} <= 4'd0;
        {matrix21,matrix22,matrix23,matrix24} <= 4'd0;
        {matrix31,matrix32,matrix33,matrix34} <= 4'd0;
        {matrix41,matrix42,matrix43,matrix44} <= 4'd0;
    end else if (video_de_d0) begin
        {matrix11,matrix12,matrix13,matrix14} <= {matrix12,matrix13,matrix14,line1_data};
        {matrix21,matrix22,matrix23,matrix24} <= {matrix22,matrix23,matrix24,line2_data};
        {matrix31,matrix32,matrix33,matrix34} <= {matrix32,matrix33,matrix34,line3_data};
        {matrix41,matrix42,matrix43,matrix44} <= {matrix42,matrix43,matrix44,line4_data};
    end else begin
        {matrix11,matrix12,matrix13,matrix14} <= 4'd0;
        {matrix21,matrix22,matrix23,matrix24} <= 4'd0;
        {matrix31,matrix32,matrix33,matrix34} <= 4'd0;
        {matrix41,matrix42,matrix43,matrix44} <= 4'd0;
    end
end

endmodule
