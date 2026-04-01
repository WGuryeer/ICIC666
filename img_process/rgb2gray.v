`timescale 1ns/1ps
// ============================================================================
// 功能：RGB565 → 灰度，心理学公式近似：Gray = (38*R + 75*G + 15*B) >> 7
// 时序：输入同步信号与像素在 clk 上升沿采样，内部两级运算流水，输出整体延迟 3 拍
// 端口说明：
// clk      : 像素时钟，与输入数据同域
// rst_n    : 同步低有效复位
// vs_in    : 场同步输入
// hs_in    : 行同步输入
// de_in    : 数据有效（Data Enable）输入
// rgb565_in: 打包好的 RGB565 输入（如 hdmi_data_in）
// vs_out/hs_out/de_out : 输出同步信号，较输入延迟 3 拍，与灰度数据对齐
// gray_out : 灰度输出，8bit，(38*R+75*G+15*B)>>7 截断
// ============================================================================
module rgb2gray #(
    parameter OUT_WIDTH = 8
)(
    input  wire                 clk,
    input  wire                 rst_n,
    input  wire                 vs_in,
    input  wire                 hs_in,
    input  wire                 de_in,
    input  wire [15:0]          rgb565_in,

    output reg                  vs_out,
    output reg                  hs_out,
    output reg                  de_out,
    output reg  [OUT_WIDTH-1:0] gray_out
);
    // ---------- RGB565→RGB888 量化补偿 ----------
    // 高位补齐，低位重复高位的 MSB，减少阶梯感
    wire [7:0] r = {rgb565_in[15:11], rgb565_in[13:11]};
    wire [7:0] g = {rgb565_in[10:5],  rgb565_in[6:5]};
    wire [7:0] b = {rgb565_in[4:0],   rgb565_in[2:0]};

    // ---------- 有效与同步信号打拍（3 拍，与灰度流水对齐） ----------
    reg [2:0] vs_r, hs_r, de_r;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            vs_r <= 3'b0;
            hs_r <= 3'b0;
            de_r <= 3'b0;
        end else begin
            vs_r <= {vs_r[1:0], vs_in};
            hs_r <= {hs_r[1:0], hs_in};
            de_r <= {de_r[1:0], de_in};
        end
    end

    // ---------- 7 位精度灰度运算，流水 2 拍 ----------
    // 第 1 拍：常数乘法
    reg [14:0] r_u, g_u, b_u;   // 38*R, 75*G, 15*B
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            r_u <= 15'd0; g_u <= 15'd0; b_u <= 15'd0;
        end else if (de_r[0]) begin
            r_u <= r * 7'd38;
            g_u <= g * 7'd75;
            b_u <= b * 7'd15;
        end
    end

    // 第 2 拍：加法求和
    reg [14:0] sum_u;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sum_u <= 15'd0;
        end else if (de_r[1]) begin
            sum_u <= r_u + g_u + b_u;   // 最大约 32640，15 位足够
        end
    end

    // ---------- 第 3 拍：输出寄存，对齐同步 ----------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            gray_out <= {OUT_WIDTH{1'b0}};
            vs_out   <= 1'b0;
            hs_out   <= 1'b0;
            de_out   <= 1'b0;
        end else begin
            gray_out <= sum_u[7 +: 8]; // (sum >> 7) 截断；若要四舍五入，可改为 (sum_u + 15'd64)[7+:8]
            vs_out   <= vs_r[2];
            hs_out   <= hs_r[2];
            de_out   <= de_r[2];
        end
    end
endmodule