// ============================================================================
// 模块名：v_projection（垂直投影）
// 功  能：对二值图像逐列统计白色像素（video_data=1）数量，实现垂直投影。
//         帧期间（video_vs 高电平）通过读-改-写（RMW）流水对列 RAM 进行累加；
//         帧结束（vs 下降沿）后依次输出所有列的累计值，输出完毕后清零 RAM，
//         等待下一帧。
//
// 综合说明：
//   col_ram 为 IMG_WIDTH × ACC_WIDTH 的寄存器阵列，综合工具可推断为 BRAM 或
//   分布式 RAM。RMW 流水为 2 级（读→写），列连续扫描时无 RAW 冒险。
//   帧消隐期（vs=0）先输出（1920 拍）再清零（1920 拍），共 3840 拍，
//   远小于 1080p@60Hz 消隐周期（约 40 万拍），无溢出风险。
//
// 典型连接：将 dilate/binarization 输出的 1-bit 二值流接入；
//           将 proj_col_* 送至 boundary_detect 计算左右边界。
// ============================================================================
`timescale 1ns / 1ps

module v_projection #(
    parameter IMG_WIDTH  = 11'd1920,
    parameter IMG_HEIGHT = 11'd1080,
    parameter ACC_WIDTH  = 11           // ceil(log2(IMG_HEIGHT))，1080 需要 11 位
)(
    input  wire                  video_clk,
    input  wire                  rst_n,

    input  wire                  video_vs,   // 场同步（高电平=帧有效期间）
    input  wire                  video_de,   // 数据有效（高电平=像素有效）
    input  wire                  video_data, // 二值像素（1=白，0=黑）

    // ---- 帧结束后逐列输出（顺序，列索引 0 → IMG_WIDTH-1）----
    output reg  [10:0]           proj_col_idx,   // 列索引
    output reg  [ACC_WIDTH-1:0]  proj_col_val,   // 本列白像素累计值 N(x)
    output reg                   proj_col_valid, // 列结果有效脉冲

    // ---- 所有列输出完毕（单拍）----
    output reg                   proj_frame_done
);

    // ──── 列累加 RAM ────
    // 大小：IMG_WIDTH × ACC_WIDTH，综合工具通常推断为 BRAM 或分布式 RAM
    reg [ACC_WIDTH-1:0] col_ram [0:IMG_WIDTH-1];

    // ──── 帧内列计数与 RMW 流水 ────
    reg [10:0]          x_cnt;    // 当前列（帧内像素 x 坐标）
    reg [10:0]          x_d1;     // 延迟 1 拍（作为 RMW 写回地址）
    reg                 de_d1;
    reg                 de_d2;    // 延迟 2 拍（写使能对齐 rdata）
    reg                 data_d1;  // 延迟 1 拍（与 rdata 对齐）
    reg [ACC_WIDTH-1:0] rdata;    // col_ram 读出值（1 拍延迟）

    reg vs_d1;
    wire vs_fall = vs_d1 & ~video_vs;  // vs 下降沿 = 帧结束

    // ──── 列计数与流水寄存器 ────
    always @(posedge video_clk or negedge rst_n) begin
        if (!rst_n) begin
            x_cnt   <= 11'd0;
            x_d1    <= 11'd0;
            de_d1   <= 1'b0;
            de_d2   <= 1'b0;
            data_d1 <= 1'b0;
            vs_d1   <= 1'b0;
        end else begin
            vs_d1   <= video_vs;
            de_d1   <= video_de;
            de_d2   <= de_d1;
            x_d1    <= x_cnt;
            data_d1 <= video_data;

            if (!video_vs) begin
                x_cnt <= 11'd0;             // 消隐期归零
            end else if (video_de) begin
                x_cnt <= (x_cnt == IMG_WIDTH - 1) ? 11'd0 : x_cnt + 1'b1;
            end
        end
    end

    // ──── RAM 读（同步，1 拍延迟）用于 RMW ────
    always @(posedge video_clk) begin
        rdata <= col_ram[x_cnt];
    end

    // ──── RAM 写：RMW 累加 或 清零 ────
    // 帧内 de_d2 有效时写回累加值；清零阶段写 0
    localparam S_IDLE  = 2'd0;
    localparam S_OUT   = 2'd1;
    localparam S_CLR   = 2'd2;

    reg [1:0]  state;
    reg [10:0] proc_cnt;           // 输出/清零阶段的列计数器
    reg [ACC_WIDTH-1:0] rd_data_q; // 预取缓存

    always @(posedge video_clk) begin
        if (de_d2)
            col_ram[x_d1] <= rdata + {{(ACC_WIDTH-1){1'b0}}, data_d1};
        else if (state == S_CLR)
            col_ram[proc_cnt] <= {ACC_WIDTH{1'b0}};
    end

    // ──── 帧结束后输出 + 清零状态机 ────
    always @(posedge video_clk or negedge rst_n) begin
        if (!rst_n) begin
            state           <= S_IDLE;
            proc_cnt        <= 11'd0;
            rd_data_q       <= {ACC_WIDTH{1'b0}};
            proj_col_idx    <= 11'd0;
            proj_col_val    <= {ACC_WIDTH{1'b0}};
            proj_col_valid  <= 1'b0;
            proj_frame_done <= 1'b0;
        end else begin
            proj_col_valid  <= 1'b0;
            proj_frame_done <= 1'b0;

            case (state)
                // ── 等待帧结束 ──
                S_IDLE: begin
                    if (vs_fall) begin
                        state    <= S_OUT;
                        proc_cnt <= 11'd0;
                        // 预取第 0 列
                        rd_data_q <= col_ram[11'd0];
                    end
                end

                // ── 逐列输出（输出 col_ram[proc_cnt]，已预取至 rd_data_q）──
                S_OUT: begin
                    proj_col_val   <= rd_data_q;
                    proj_col_idx   <= proc_cnt;
                    proj_col_valid <= 1'b1;

                    if (proc_cnt == IMG_WIDTH - 1) begin
                        // 最后一列输出完毕，转入清零
                        state           <= S_CLR;
                        proc_cnt        <= 11'd0;
                        proj_frame_done <= 1'b1;
                    end else begin
                        proc_cnt  <= proc_cnt + 1'b1;
                        // 预取下一列
                        rd_data_q <= col_ram[proc_cnt + 1'b1];
                    end
                end

                // ── 清零 RAM，为下一帧做准备 ──
                // 实际清零写操作在 RAM 写 always 块执行（state == S_CLR）
                S_CLR: begin
                    if (proc_cnt == IMG_WIDTH - 1)
                        state <= S_IDLE;
                    else
                        proc_cnt <= proc_cnt + 1'b1;
                end

                default: state <= S_IDLE;
            endcase
        end
    end

endmodule
