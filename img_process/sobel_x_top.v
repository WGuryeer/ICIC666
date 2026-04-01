// 小顶层：3x3 窗口 + Sobel X（灰度梯度输出）
// 参数：IMG_WIDTH/IMG_HEIGHT 用于 matrix_3x3，WIN_LAT 为窗口延迟（默认 2clk）
module sobel_x_top #(
    parameter IMG_WIDTH  = 11'd1920,
    parameter IMG_HEIGHT = 11'd1080,
    parameter WIN_LAT    = 2,          // matrix_3x3 内部窗口延迟
    
)(
    input  wire       pixclk_in,
    input  wire       rstn_in,
    input  wire       vs_in,
    input  wire       de_in,
    input  wire [7:0] data_in,         // 高斯输入

    output wire       vs_out,          // 与 sobel 数据对齐
    output wire       de_out,          // 与 sobel 数据对齐
    output wire [7:0] sobel_x_data     // Sobel X 灰度梯度
);

//---------------- 3×3 窗口 ----------------
wire [7:0] m11, m12, m13;
wire [7:0] m21, m22, m23;
wire [7:0] m31, m32, m33;
wire       matrix_de;

matrix_3x3 #(
    .IMG_WIDTH  (IMG_WIDTH ),
    .IMG_HEIGHT (IMG_HEIGHT)
) u_matrix_3x3 (
    .video_clk  (pixclk_in ),
    .rst_n      (rstn_in   ),
    .video_vs   (vs_in     ),
    .video_de   (de_in     ),
    .video_data (data_in   ),
    .matrix_de  (matrix_de ),
    .matrix11   (m11       ),
    .matrix12   (m12       ),
    .matrix13   (m13       ),
    .matrix21   (m21       ),
    .matrix22   (m22       ),
    .matrix23   (m23       ),
    .matrix31   (m31       ),
    .matrix32   (m32       ),
    .matrix33   (m33       )
);

// VS 打拍以对齐窗口延迟
reg [WIN_LAT:0] vs_pipe;
always @(posedge pixclk_in or negedge rstn_in) begin
    if (!rstn_in)
        vs_pipe <= 'd0;
    else
        vs_pipe <= {vs_pipe[WIN_LAT-1:0], vs_in};
end
wire vs_win = vs_pipe[WIN_LAT];

//---------------- Sobel X ----------------
sobel_x #(
    .SOBEL_THRESHOLD ( 40 )
) u_sobel_x (
    .video_clk  (pixclk_in ),
    .rst_n      (rstn_in   ),
    .matrix_de  (matrix_de ),
    .matrix_vs  (vs_win    ),
    .matrix11   (m11       ),
    .matrix12   (m12       ),
    .matrix13   (m13       ),
    .matrix21   (m21       ),
    .matrix22   (m22       ),
    .matrix23   (m23       ),
    .matrix31   (m31       ),
    .matrix32   (m32       ),
    .matrix33   (m33       ),
    .sobel_vs   (vs_out    ),
    .sobel_de   (de_out    ),
    .sobel_data (sobel_x_data)
);

endmodule