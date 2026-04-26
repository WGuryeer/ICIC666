// ============================================================================
// 模块名：h_projection（水平投影）
// 功  能：对二值图像逐行统计白色像素（video_data=1）数量，实现水平投影。
//         每行结束（de 下降沿后 1 拍）输出行索引（proj_row_idx）和
//         本行白像素累计值（proj_row_val），同时产生单拍高脉冲 proj_row_valid。
//         一帧所有行处理完毕后产生单拍 proj_frame_done 脉冲。
//
// 典型连接：将 dilate/binarization 输出的 1-bit 二值流接到此模块，
//           再将 proj_row_* 送至 boundary_detect 计算上下边界。
//
// 时序说明：
//   video_vs 高电平期间为有效帧，vs 上升沿清零行计数；
//   video_de 高电平期间为有效像素；
//   de 下降沿后第 1 拍输出本行结果，且 proj_row_valid=1（单拍）；
//   vs 下降沿后第 1 拍输出 proj_frame_done=1（单拍）。
// ============================================================================
`timescale 1ns / 1ps

module h_projection #(
    parameter IMG_WIDTH  = 11'd1920,
    parameter IMG_HEIGHT = 11'd1080,
    parameter ACC_WIDTH  = 11           // ceil(log2(IMG_WIDTH))，1920 需要 11 位
)(
    input  wire                  video_clk,
    input  wire                  rst_n,

    input  wire                  video_vs,   // 场同步（高电平=帧有效期间）
    input  wire                  video_de,   // 数据有效（高电平=像素有效）
    input  wire                  video_data, // 二值像素（1=白，0=黑）

    // ---- 每行结束输出 ----
    output reg  [10:0]           proj_row_idx,   // 行索引（0 ~ IMG_HEIGHT-1）
    output reg  [ACC_WIDTH-1:0]  proj_row_val,   // 本行白像素累计值 N(y)
    output reg                   proj_row_valid, // 行结果有效脉冲（单拍）

    // ---- 帧结束脉冲 ----
    output reg                   proj_frame_done  // 本帧所有行处理完毕（单拍）
);

    reg [ACC_WIDTH-1:0] acc;      // 当前行累加器
    reg [10:0]          row_cnt;  // 当前行索引计数
    reg                 de_d1;
    reg                 vs_d1;

    wire de_fall = de_d1  & ~video_de;  // de 下降沿 = 当前行像素结束
    wire vs_rise = ~vs_d1 & video_vs;   // vs 上升沿 = 新帧开始
    wire vs_fall = vs_d1  & ~video_vs;  // vs 下降沿 = 帧结束

    always @(posedge video_clk or negedge rst_n) begin
        if (!rst_n) begin
            acc             <= {ACC_WIDTH{1'b0}};
            row_cnt         <= 11'd0;
            proj_row_idx    <= 11'd0;
            proj_row_val    <= {ACC_WIDTH{1'b0}};
            proj_row_valid  <= 1'b0;
            proj_frame_done <= 1'b0;
            de_d1           <= 1'b0;
            vs_d1           <= 1'b0;
        end else begin
            de_d1           <= video_de;
            vs_d1           <= video_vs;
            proj_row_valid  <= 1'b0;    // 默认低，仅在行结束时置高一拍
            proj_frame_done <= 1'b0;    // 默认低，仅在帧结束时置高一拍

            if (vs_rise) begin
                // 新帧开始：复位行计数和累加器
                acc     <= {ACC_WIDTH{1'b0}};
                row_cnt <= 11'd0;
            end else if (video_de) begin
                // 行有效期间：累加白像素
                acc <= acc + {{(ACC_WIDTH-1){1'b0}}, video_data};
            end else if (de_fall) begin
                // 行结束：锁存并输出本行结果
                proj_row_val   <= acc;
                proj_row_idx   <= row_cnt;
                proj_row_valid <= 1'b1;
                acc            <= {ACC_WIDTH{1'b0}};
                row_cnt        <= row_cnt + 1'b1;
            end

            if (vs_fall)
                proj_frame_done <= 1'b1;
        end
    end

endmodule
