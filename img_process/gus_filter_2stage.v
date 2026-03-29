`timescale 1ns/1ps
// 二阶 3×3 高斯：串联两个 gus_filter 实例
module gus_filter_2stage #(
    parameter IMG_WIDTH = 1920  // 仅作为向下传参占位，如需在 gus_filter/shift_gus 内使用请增加该参数
)(
    input        clk,
    input        rst_n,
    input  [7:0] gray_din,
    input        gray_valid,
    output [7:0] gauss2_dout,
    output       gauss2_valid
);
    // 第 1 阶
    wire [7:0] g1_dout;
    wire       g1_valid;

    gus_filter u_gus_filter_stage1 (
        .clk       (clk),
        .rst_n     (rst_n),
        .gray_din  (gray_din),
        .gray_valid(gray_valid),
        .gus_dout  (g1_dout),
        .gus_valid (g1_valid)
    );

    // 第 2 阶（直接串联第 1 阶输出）
    gus_filter u_gus_filter_stage2 (
        .clk       (clk),
        .rst_n     (rst_n),
        .gray_din  (g1_dout),
        .gray_valid(g1_valid),
        .gus_dout  (gauss2_dout),
        .gus_valid (gauss2_valid)
    );

endmodule