// 二阶高斯滤波小顶层：输入原始灰度流，输出二次高斯结果
module gauss_two_stage #(
    parameter IMG_WIDTH  = 11'd1920,
    parameter IMG_HEIGHT = 11'd1080,
    parameter WIN_LAT    = 2          // matrix_3x3 的窗口延迟拍数
)(
    input  wire        pixclk_in,
    input  wire        rstn_out,
    input  wire        vs_in,
    input  wire        de_in,
    input  wire [7:0]  data_in,

    output wire        gauss2_vs,   // 二次高斯后的 VS（与数据对齐）
    output wire        gauss2_de,   // 二次高斯后的 DE（与数据对齐）
    output wire [7:0]  gauss2_data  // 二次高斯数据
);

//==================== 第一次 3×3 窗口 ====================
wire [7:0] m11_s1, m12_s1, m13_s1;
wire [7:0] m21_s1, m22_s1, m23_s1;
wire [7:0] m31_s1, m32_s1, m33_s1;
wire       m_de_s1;

matrix_3x3 #(
    .IMG_WIDTH  (IMG_WIDTH ),
    .IMG_HEIGHT (IMG_HEIGHT)
) u_matrix_3x3_1 (
    .video_clk  (pixclk_in ),
    .rst_n      (rstn_out  ),
    .video_vs   (vs_in     ),
    .video_de   (de_in     ),
    .video_data (data_in   ),
    .matrix_de  (m_de_s1   ),
    .matrix11   (m11_s1    ),
    .matrix12   (m12_s1    ),
    .matrix13   (m13_s1    ),
    .matrix21   (m21_s1    ),
    .matrix22   (m22_s1    ),
    .matrix23   (m23_s1    ),
    .matrix31   (m31_s1    ),
    .matrix32   (m32_s1    ),
    .matrix33   (m33_s1    )
);

// VS 对齐第 1 次窗口
reg [WIN_LAT:0] vs_pipe_s1;
always @(posedge pixclk_in or negedge rstn_out) begin
    if (!rstn_out)
        vs_pipe_s1 <= 'd0;
    else
        vs_pipe_s1 <= {vs_pipe_s1[WIN_LAT-1:0], vs_in};
end
wire vs_s1 = vs_pipe_s1[WIN_LAT];

//==================== 第一次高斯 ====================
wire [7:0] g1_data;
wire       g1_de, g1_vs;

gauss_filter u_gauss_filter_1 (
    .video_clk         (pixclk_in ),
    .rst_n             (rstn_out  ),
    .matrix_de         (m_de_s1   ),
    .matrix_vs         (vs_s1     ),
    .matrix11          (m11_s1    ),
    .matrix12          (m12_s1    ),
    .matrix13          (m13_s1    ),
    .matrix21          (m21_s1    ),
    .matrix22          (m22_s1    ),
    .matrix23          (m23_s1    ),
    .matrix31          (m31_s1    ),
    .matrix32          (m32_s1    ),
    .matrix33          (m33_s1    ),
    .gauss_filter_vs   (g1_vs     ),
    .gauss_filter_de   (g1_de     ),
    .gauss_filter_data (g1_data   )
);

//==================== 第二次 3×3 窗口 ====================
wire [7:0] m11_s2, m12_s2, m13_s2;
wire [7:0] m21_s2, m22_s2, m23_s2;
wire [7:0] m31_s2, m32_s2, m33_s2;
wire       m_de_s2;

matrix_3x3 #(
    .IMG_WIDTH  (IMG_WIDTH ),
    .IMG_HEIGHT (IMG_HEIGHT)
) u_matrix_3x3_2 (
    .video_clk  (pixclk_in ),
    .rst_n      (rstn_out  ),
    .video_vs   (g1_vs     ),
    .video_de   (g1_de     ),
    .video_data (g1_data   ),
    .matrix_de  (m_de_s2   ),
    .matrix11   (m11_s2    ),
    .matrix12   (m12_s2    ),
    .matrix13   (m13_s2    ),
    .matrix21   (m21_s2    ),
    .matrix22   (m22_s2    ),
    .matrix23   (m23_s2    ),
    .matrix31   (m31_s2    ),
    .matrix32   (m32_s2    ),
    .matrix33   (m33_s2    )
);

// VS 对齐第 2 次窗口
reg [WIN_LAT:0] vs_pipe_s2;
always @(posedge pixclk_in or negedge rstn_out) begin
    if (!rstn_out)
        vs_pipe_s2 <= 'd0;
    else
        vs_pipe_s2 <= {vs_pipe_s2[WIN_LAT-1:0], g1_vs};
end
wire vs_s2 = vs_pipe_s2[WIN_LAT];

//==================== 第二次高斯 ====================
gauss_filter u_gauss_filter_2 (
    .video_clk         (pixclk_in ),
    .rst_n             (rstn_out  ),
    .matrix_de         (m_de_s2   ),
    .matrix_vs         (vs_s2     ),
    .matrix11          (m11_s2    ),
    .matrix12          (m12_s2    ),
    .matrix13          (m13_s2    ),
    .matrix21          (m21_s2    ),
    .matrix22          (m22_s2    ),
    .matrix23          (m23_s2    ),
    .matrix31          (m31_s2    ),
    .matrix32          (m32_s2    ),
    .matrix33          (m33_s2    ),
    .gauss_filter_vs   (gauss2_vs    ),
    .gauss_filter_de   (gauss2_de    ),
    .gauss_filter_data (gauss2_data  )
);

endmodule