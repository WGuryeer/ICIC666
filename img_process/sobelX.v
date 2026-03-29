`timescale 1ns/1ps
/* -----------------------------------------------------------------------------
// Module: sobel_x_gray
// Function: 8-bit 灰度图的 X 方向 Sobel 边缘检测，只输出 |Gx|>THRESH 的二值边缘。
//           卷积核 Description:边缘检测模块
						 -1 0 +1 
					Gx = -2 0 +2 
						 -1 0 +1 
//           适用于高斯滤波后直接检测水平梯度（垂直边缘），无需预二值化。
// Inputs:
//   - clk        : 像素时钟
//   - rst_n      : 低有效同步复位
//   - gray_din   : 8-bit 灰度像素，建议接二阶高斯输出 gauss2_dout
//   - gray_valid : 灰度像素有效标志，高时推进行缓
// Parameters:
//   - IMG_WIDTH  : 行宽（像素数），需与行缓一致，默认 1920
//   - THRESH     : 梯度阈值 (0~1020)，|Gx| 大于该值输出边缘为 1
// Outputs:
//   - sobel_x_out   : X 方向二值边缘（1 表示检测到垂直边缘）
//   - sobel_x_valid : 输出有效，对齐 sobel_x_out
// -----------------------------------------------------------------------------*/
module sobel_x_gray #(
    parameter IMG_WIDTH = 1920,
    parameter THRESH    = 10'd200
)(
    input               clk,
    input               rst_n,
    input       [7:0]   gray_din,
    input               gray_valid,

    output              sobel_x_out,
    output              sobel_x_valid
);
    // 行缓输出三行同列像素
    wire [7:0] taps0, taps1, taps2;
	
    // 列方向两级打拍，形成三列窗口
    reg  [7:0] taps0_1, taps1_1, taps2_1;
    reg  [7:0] taps0_2, taps1_2, taps2_2;
	
	// 左/右列 1-2-1 加权和，最大 4*255=1020（10 位）
    reg  [9:0] sumx_1, sumx_3;
	
    // |Gx| 0..1020
    reg  [9:0] g_x;

    reg  [3:0] valid_r; // 打拍对齐

    // valid 打3拍，经历 3 级运算（列打拍、加权、求 |Gx|）
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) valid_r <= 4'd0;
        else       valid_r <= {valid_r[2:0], gray_valid};
    end

    // 列方向移位
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            taps0_1 <= 0; 
			taps1_1 <= 0; 
			taps2_1 <= 0;
            taps0_2 <= 0; 
			taps1_2 <= 0; 
			taps2_2 <= 0;
        end else begin
            taps0_1 <= taps0;   
			taps1_1 <= taps1;   
			taps2_1 <= taps2;
            taps0_2 <= taps0_1; 
			taps1_2 <= taps1_1; 
			taps2_2 <= taps2_1;
        end
    end

    // 左/右列加权和（1-2-1）
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            sumx_1 <= 0; 
			sumx_3 <= 0;
        end else if(valid_r[1]) begin
            sumx_1 <= taps0   + (taps1   << 1) + taps2;      // 左列
            sumx_3 <= taps0_2 + (taps1_2 << 1) + taps2_2;    // 右列
        end
    end

    // |Gx|
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) 
			g_x <= 0;
        else if(valid_r[2])
            g_x <= (sumx_1 > sumx_3) ? (sumx_1 - sumx_3) : (sumx_3 - sumx_1);
    end

    assign sobel_x_out   = (g_x > THRESH);
    assign sobel_x_valid = valid_r[3];


    // 行缓冲：复用 shift_sobel_gray/shift_gus 结构，8bit 宽，行深 IMG_WIDTH
    shift_sobel_x shift_sobel_x_inst (
        .clock    (clk			),
        .clken    (gray_valid	),
        .shiftin  (gray_din		),
        .shiftout (				),
        .taps0x   (taps0		),
        .taps1x   (taps1		),
        .taps2x   (taps2		)
    );
endmodule