`timescale 1ns / 1ps
`define UD #1

module top(
    input  wire        sys_clk,     // 50MHz 系统时钟
    output             rstn_out,

    // I2C 接口
    output             iic_scl,
    inout              iic_sda,
    output             iic_tx_scl,
    inout              iic_tx_sda,

    // HDMI→MS7200 并口输入（RGB888，随 pixclk_in）
    input              pixclk_in,
    input              vs_in,
    input              hs_in,
    input              de_in,
    input      [7:0]   r_in,
    input      [7:0]   g_in,
    input      [7:0]   b_in,

    // 灰度透传输出（同域）
    output             pixclk_out,
    output reg         vs_out,
    output reg         hs_out,
    output reg         de_out,
    output reg  [7:0]  r_out,
    output reg  [7:0]  g_out,
    output reg  [7:0]  b_out,

    // 灰度化输出供算法使用
    output             vs_gray,
    output             hs_gray,
    output             de_gray,
    output      [7:0]  gray_out,

    output             led_int
);
    // === RGB888 打包成 RGB565（中间信号） ===
    wire [15:0] hdmi_data_in = {r_in[7:3], g_in[7:2], b_in[7:3]};

    // === cfg_pll：生成 I2C 配置时钟 ===
    wire cfg_clk;
    wire cfg_lock;
    cfg_pll cfg_pll_inst (
        .clkin1 (sys_clk),
        .clkout0(cfg_clk),
        .lock   (cfg_lock)
    );

    // === pll_gen_clk：预留的本地像素时钟（当前未用） ===
    wire pix_clk;
    wire pix_lock;
    pll pll_gen_clk (
        .clkin1 (sys_clk),
        .clkout0(pix_clk),   // 例如 148.5MHz
        .lock   (pix_lock)
    );

    // rstn_out：等待 cfg_pll 锁定 + 1ms
    reg [15:0] rstn_1ms;
    always @(posedge cfg_clk) begin
        if(!cfg_lock)
            rstn_1ms <= 16'd0;
        else if(rstn_1ms != 16'h2710)
            rstn_1ms <= rstn_1ms + 1'b1;
    end
    assign rstn_out = (rstn_1ms == 16'h2710);

    // MS72xx 初始化（cfg_clk 域）
    wire init_over_cfg;
    ms72xx_ctl u_ms72xx_ctl (
        .clk        (cfg_clk),
        .rst_n      (rstn_out),
        .init_over  (init_over_cfg),
        .iic_tx_scl (iic_tx_scl),
        .iic_tx_sda (iic_tx_sda),
        .iic_scl    (iic_scl),
        .iic_sda    (iic_sda)
    );
    assign led_int = init_over_cfg;

    // === 像素域采用输入时钟，避免跨域复杂性 ===
    assign pixclk_out = pixclk_in;
    reg init_sync1, init_sync2;
    always @(posedge pixclk_in) begin
        init_sync1 <= init_over_cfg;
        init_sync2 <= init_sync1;
    end
    wire init_over = init_sync2;

    // === 灰度化：RGB565 → Gray（pixclk_in 域） ===
    rgb2gray #(
        .IN_WIDTH (8),
        .OUT_WIDTH(8),
        .RGB565_EN(1)
    ) u_rgb2gray (
        .clk      (pixclk_in),
        .rst_n    (init_over),
        .vs_in    (vs_in),
        .hs_in    (hs_in),
        .de_in    (de_in),
        .r_in     (8'd0),
        .g_in     (8'd0),
        .b_in     (8'd0),
        .rgb565_in(hdmi_data_in),
        .vs_out   (vs_gray),
        .hs_out   (hs_gray),
        .de_out   (de_gray),
        .gray_out (gray_out)
    );

    // 灰度透传到输出口（pixclk_in 域）
    always @(posedge pixclk_in) begin
        if(!init_over) begin
            vs_out <= 1'b0;
            hs_out <= 1'b0;
            de_out <= 1'b0;
            r_out  <= 8'd0;
            g_out  <= 8'd0;
            b_out  <= 8'd0;
        end else begin
            vs_out <= vs_gray;
            hs_out <= hs_gray;
            de_out <= de_gray;
            r_out  <= gray_out;
            g_out  <= gray_out;
            b_out  <= gray_out;
        end
    end

endmodule
