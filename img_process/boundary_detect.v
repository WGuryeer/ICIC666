// ============================================================================
// 模块名：boundary_detect（三阶矩阵法边界检测）
// 功  能：接收来自 h_projection（水平投影）或 v_projection（垂直投影）
//         的逐行/列累计值流，采用论文中提出的"三阶矩阵法"定位车牌边界。
//
// 算法原理（参见论文 Section III-C）：
//   1. 接收所有投影值 N(y) 或 N(x)，存入内部 RAM；同时统计：
//        sum_acc = Σ Nk（非零值之和）
//        nz_cnt  = M（非零值行/列数）
//   2. 阈值：Threshold = sum_acc / nz_cnt
//   3. 以 9 拍滑动窗口遍历投影数据，构造 3×3 矩阵 F 并与算子
//        F1 = [[1,1,0],[1,1,0],[1,0,0]]
//      相乘，取第 1 行之和 T1 = 2·N(y1)+2·N(y2)+N(y3)，
//      取第 3 行之和 T2 = 2·N(y7)+2·N(y8)+N(y9)。
//   4. 判据：
//        T1 <  Threshold  && T2 > 5·Threshold → 有效上升沿（first → Ydown）
//        T1 > 5·Threshold && T2 <  Threshold  → 有效下降沿（last  → Yup  ）
//   5. 下边界 Ydown = 第一个有效上升沿时 y5 的坐标（窗口中心）。
//      上边界 Yup   = 最后一个有效下降沿时 y5 的坐标（窗口中心）。
//      同理，垂直投影可获得左右边界 Xleft / Xright。
//
// 综合注意：
//   S_CALC_TH 状态使用 Verilog 除法运算符（/），综合工具将生成组合逻辑除法器。
//   实际工程中建议替换为 IP 核除法器以优化面积与时序。
//
// 接口说明：
//   proj_val   / proj_idx / proj_valid：投影值输入（来自 h/v_projection）
//   frame_end  ：一帧所有投影值接收完毕（proj_frame_done 信号）
//   boundary_lo：Ydown 或 Xleft（第一个有效上升沿对应的中心坐标）
//   boundary_hi：Yup   或 Xright（最后一个有效下降沿对应的中心坐标）
//   boundary_valid：边界结果有效（单拍脉冲）
// ============================================================================
`timescale 1ns / 1ps

module boundary_detect #(
    parameter PROJ_LEN  = 11'd1080, // 投影长度（水平投影 = 行数；垂直投影 = 列数）
    parameter ACC_WIDTH = 11,       // 投影值位宽，需与 h/v_projection 的 ACC_WIDTH 一致
    parameter IDX_WIDTH = 11        // 索引位宽
)(
    input  wire                   clk,
    input  wire                   rst_n,

    // ---- 投影值输入（来自 h_projection 的 proj_row_* 或 v_projection 的 proj_col_*）----
    input  wire [ACC_WIDTH-1:0]   proj_val,   // N(y) 或 N(x)
    input  wire [IDX_WIDTH-1:0]   proj_idx,   // 行 / 列索引
    input  wire                   proj_valid, // 单拍有效脉冲

    // ---- 帧结束触发（连接 proj_frame_done）----
    input  wire                   frame_end,

    // ---- 边界坐标输出 ----
    output reg  [IDX_WIDTH-1:0]   boundary_lo,    // Ydown / Xleft
    output reg  [IDX_WIDTH-1:0]   boundary_hi,    // Yup   / Xright
    output reg                    boundary_valid   // 结果有效（单拍）
);

    // ──── 投影值存储 RAM ────
    reg [ACC_WIDTH-1:0] proj_ram [0:PROJ_LEN-1];

    // ──── 阈值计算累加器 ────
    reg [31:0]          sum_acc;  // Σ Nk（仅非零项）
    reg [15:0]          nz_cnt;   // M（非零行/列数）
    reg [ACC_WIDTH-1:0] threshold;

    // ──── 状态机 ────
    localparam S_IDLE    = 3'd0;
    localparam S_ACCUM   = 3'd1;  // 接收并存储投影值
    localparam S_CALC_TH = 3'd2;  // 计算阈值
    localparam S_DETECT  = 3'd3;  // 边界检测（9 拍滑动窗口）
    localparam S_DONE    = 3'd4;  // 输出边界坐标

    reg [2:0] state;

    // ──── 9 拍滑动窗口（win[0]=最新，win[8]=最旧）────
    // 对应论文 F 矩阵行序：N(y1)=win[8], N(y2)=win[7], N(y3)=win[6]
    //                       N(y7)=win[2], N(y8)=win[1], N(y9)=win[0]
    reg [ACC_WIDTH-1:0] win [0:8];
    integer k;

    // ──── T1 / T2 计算（三阶矩阵 F×F1 的第 1、3 行之和）────
    // T1 = 2·N(y1)+2·N(y2)+N(y3) = 2·win[8]+2·win[7]+win[6]
    // T2 = 2·N(y7)+2·N(y8)+N(y9) = 2·win[2]+2·win[1]+win[0]
    // 最大值：5·(2^ACC_WIDTH-1)，需要 ACC_WIDTH+3 位才不溢出
    wire [ACC_WIDTH+3:0] T1  = ({3'b0, win[8]} << 1) + ({3'b0, win[7]} << 1) + {3'b0, win[6]};
    wire [ACC_WIDTH+3:0] T2  = ({3'b0, win[2]} << 1) + ({3'b0, win[1]} << 1) + {3'b0, win[0]};
    wire [ACC_WIDTH+3:0] TH1 = {3'b0, threshold};           // 1×Threshold
    wire [ACC_WIDTH+3:0] TH5 = ({3'b0, threshold} << 2) + {3'b0, threshold}; // 5×Threshold

    // ──── 检测状态变量 ────
    reg [IDX_WIDTH-1:0] rd_cnt;     // 检测阶段读取计数器
    reg                 lo_found;   // 下边界（Ydown）已找到
    reg [IDX_WIDTH-1:0] lo_cand;    // 下边界候选坐标
    reg [IDX_WIDTH-1:0] hi_cand;    // 上边界候选坐标（保持最后一次有效下降沿）

    // ──── 主状态机 ────
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state          <= S_IDLE;
            sum_acc        <= 32'd0;
            nz_cnt         <= 16'd0;
            threshold      <= {ACC_WIDTH{1'b0}};
            rd_cnt         <= {IDX_WIDTH{1'b0}};
            lo_found       <= 1'b0;
            lo_cand        <= {IDX_WIDTH{1'b0}};
            hi_cand        <= {IDX_WIDTH{1'b0}};
            boundary_lo    <= {IDX_WIDTH{1'b0}};
            boundary_hi    <= {IDX_WIDTH{1'b0}};
            boundary_valid <= 1'b0;
            for (k = 0; k <= 8; k = k + 1)
                win[k] <= {ACC_WIDTH{1'b0}};
        end else begin
            boundary_valid <= 1'b0; // 默认低

            case (state)

                // ── 等待首个投影值到来 ──
                S_IDLE: begin
                    if (proj_valid) begin
                        // 存储首个投影值并开始累加
                        proj_ram[proj_idx] <= proj_val;
                        sum_acc  <= (proj_val != 0) ? {21'd0, proj_val} : 32'd0;
                        nz_cnt   <= (proj_val != 0) ? 16'd1 : 16'd0;
                        state    <= S_ACCUM;
                    end
                end

                // ── 接收并存储所有投影值，同时统计非零值的和与个数 ──
                S_ACCUM: begin
                    if (proj_valid) begin
                        proj_ram[proj_idx] <= proj_val;
                        if (proj_val != 0) begin
                            sum_acc <= sum_acc + {21'd0, proj_val};
                            nz_cnt  <= nz_cnt  + 16'd1;
                        end
                    end
                    if (frame_end)
                        state <= S_CALC_TH;
                end

                // ── 计算阈值 Threshold = sum_acc / nz_cnt ──
                // 注意：此处使用 Verilog 除法，综合器生成组合逻辑除法器；
                //       实际工程可改用 IP 核除法器以优化资源。
                // threshold ≤ IMG_WIDTH < 2^ACC_WIDTH，直接截断赋值安全。
                S_CALC_TH: begin
                    if (nz_cnt != 16'd0)
                        threshold <= sum_acc / nz_cnt;
                    else
                        threshold <= {ACC_WIDTH{1'b0}};

                    // 初始化检测窗口
                    for (k = 0; k <= 8; k = k + 1)
                        win[k] <= {ACC_WIDTH{1'b0}};
                    rd_cnt   <= {IDX_WIDTH{1'b0}};
                    lo_found <= 1'b0;
                    lo_cand  <= {IDX_WIDTH{1'b0}};
                    hi_cand  <= {IDX_WIDTH{1'b0}};
                    state    <= S_DETECT;
                end

                // ── 9 拍滑动窗口遍历，三阶矩阵法判断边界 ──
                S_DETECT: begin
                    // 移位：将新投影值移入窗口（win[0]=最新）
                    win[8] <= win[7];
                    win[7] <= win[6];
                    win[6] <= win[5];
                    win[5] <= win[4];
                    win[4] <= win[3];
                    win[3] <= win[2];
                    win[2] <= win[1];
                    win[1] <= win[0];
                    win[0] <= proj_ram[rd_cnt];

                    // 窗口填充满（已读入 ≥ 9 个值）后开始判断
                    // 窗口中心 y5 对应 rd_cnt - 4（rd_cnt=8 时窗口首次填满，rd_cnt=9 时首次有效）
                    if (rd_cnt >= 9) begin
                        // 有效上升沿：T1 < Threshold 且 T2 > 5·Threshold
                        // → 第一次出现时，窗口中心 y5 = rd_cnt-4 为 Ydown
                        if (!lo_found && (T1 < TH1) && (T2 > TH5)) begin
                            lo_cand  <= rd_cnt - 4'd4;
                            lo_found <= 1'b1;
                        end

                        // 有效下降沿：T1 > 5·Threshold 且 T2 < Threshold
                        // → 最后一次出现时，窗口中心 y5 = rd_cnt-4 为 Yup
                        if ((T1 > TH5) && (T2 < TH1)) begin
                            hi_cand <= rd_cnt - 4'd4;
                        end
                    end

                    if (rd_cnt == PROJ_LEN - 1)
                        state <= S_DONE;
                    else
                        rd_cnt <= rd_cnt + 1'b1;
                end

                // ── 输出边界坐标 ──
                S_DONE: begin
                    boundary_lo    <= lo_cand;
                    boundary_hi    <= hi_cand;
                    boundary_valid <= 1'b1;
                    // 复位，等待下一帧
                    sum_acc        <= 32'd0;
                    nz_cnt         <= 16'd0;
                    state          <= S_IDLE;
                end

                default: state <= S_IDLE;

            endcase
        end
    end

endmodule
