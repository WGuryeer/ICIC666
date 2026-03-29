`timescale 1ns/1ps
// -----------------------------------------------------------------------------
// 行缓冲 + 3 列窗口输出，用于 3×3 卷积
// - 输入：逐像素串行流 (shiftin)，clken 高时有效
// - 输出：同一列的当前行、上一行、上两行像素 taps0x/taps1x/taps2x
// - 参数化图像宽度 1920
//---------------------------------------------------------------------------
module shift_gus #(
    parameter DATA_W    = 8,
    parameter IMG_WIDTH = 1920    // 图像一行像素数
)(
    input                   clock,
    input                   clken,      // 像素有效使能
    input      [DATA_W-1:0] shiftin,    // 当前行当前列像素

    output reg [DATA_W-1:0] shiftout,   // 可选：输出上两行同列像素（便于调试/级联）
    output reg [DATA_W-1:0] taps0x,     // 当前行
    output reg [DATA_W-1:0] taps1x,     // 上一行
    output reg [DATA_W-1:0] taps2x      // 上两行
);
    // 两级行缓冲，深度为行宽
    reg [DATA_W-1:0] line1 [0:IMG_WIDTH-1]; // 存上一行
    reg [DATA_W-1:0] line2 [0:IMG_WIDTH-1]; // 存上两行

    // 列指针
    reg [$clog2(IMG_WIDTH)-1:0] col = 0;

    integer i;
    initial begin
        for (i = 0; i < IMG_WIDTH; i = i + 1) begin
            line1[i] = {DATA_W{1'b0}};
            line2[i] = {DATA_W{1'b0}};
        end
    end

    always @(posedge clock) begin
        if (clken) begin
            // 读出历史像素
            taps0x   <= shiftin;
            taps1x   <= line1[col];
            taps2x   <= line2[col];
            shiftout <= line2[col];

            // 写回：把上一行推到上两行，本行写入上一行
            line2[col] <= line1[col];
            line1[col] <= shiftin;

            // 列地址递增
            if (col == IMG_WIDTH-1)
                col <= {($clog2(IMG_WIDTH)){1'b0}};
            else
                col <= col + 1'b1;
        end
    end
endmodule