// 仅水平 (GX) 边缘，延迟为 3clk
module sobelx
#(
    parameter SOBEL_THRESHOLD = 40
)
(
    input  wire        video_clk,
    input  wire        rst_n,

    // 矩阵数据输入
    input  wire        matrix_de,
    input  wire        matrix_vs,
    input  wire [7:0]  matrix11, matrix12, matrix13,
    input  wire [7:0]  matrix21, matrix22, matrix23,
    input  wire [7:0]  matrix31, matrix32, matrix33,

    // sobel 数据输出（保持原接口/阈值二值化）
    output wire        sobel_vs,
    output wire        sobel_de,
    output wire [7:0]  sobel_data
);

/****************************************************************
Sobel X 卷积核
-1  0  +1
-2  0  +2
-1  0  +1
****************************************************************/

//---------------- step1 计算卷积（仅 X 方向） ----------------
reg [9:0] gx_temp1, gx_temp2;

always @(posedge video_clk or negedge rst_n) begin
    if (!rst_n) begin
        gx_temp1 <= 10'd0;
        gx_temp2 <= 10'd0;
    end else if (matrix_de) begin
        gx_temp1 <= matrix13 + (matrix23 << 1) + matrix33; // 右列 +2*中右 +下右
        gx_temp2 <= matrix11 + (matrix21 << 1) + matrix31; // 左列 +2*中左 +下左
    end else begin
        gx_temp1 <= 10'd0;
        gx_temp2 <= 10'd0;
    end
end

// gy 路径移除，固定为 0，保持时序寄存器结构不变
reg [9:0] gy_data;
always @(posedge video_clk or negedge rst_n) begin
    if (!rst_n)
        gy_data <= 10'd0;
    else
        gy_data <= 10'd0;
end

//---------------- step2 取绝对值 ----------------
reg [9:0] gx_data;
always @(posedge video_clk or negedge rst_n) begin
    if (!rst_n)
        gx_data <= 10'd0;
    else if (gx_temp1 >= gx_temp2)
        gx_data <= gx_temp1 - gx_temp2;
    else
        gx_data <= gx_temp2 - gx_temp1;
end

//---------------- step3 绝对值相加（这里只有 GX） ----------------
reg [10:0] sobel_data_reg;
always @(posedge video_clk or negedge rst_n) begin
    if (!rst_n)
        sobel_data_reg <= 11'd0;
    else
        sobel_data_reg <= gx_data; // 仅 GX，保持时序
end

/************************************************************
时钟延迟 一共延迟 3clk（保持原流水）
************************************************************/
reg [2:0] video_de_reg;
reg [2:0] video_vs_reg;
always @(posedge video_clk or negedge rst_n) begin
    if (!rst_n) begin
        video_de_reg <= 3'd0;
        video_vs_reg <= 3'd0;
    end else begin
        video_de_reg <= {video_de_reg[1:0], matrix_de};
        video_vs_reg <= {video_vs_reg[1:0], matrix_vs};
    end
end

assign sobel_vs   = video_vs_reg[2];
assign sobel_de   = video_de_reg[2];
assign sobel_data = (sobel_data_reg >= SOBEL_THRESHOLD) ? 8'd255 : 8'd0;

endmodule