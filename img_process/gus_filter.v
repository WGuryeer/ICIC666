module gus_filter( 
    input               clk       ,   // 时钟
    input               rst_n     ,   // 低有效同步复位
    input       [7:0]   gray_din  ,   // 输入灰度像素
    input               gray_valid,   // 输入像素有效

    output  reg [7:0]   gus_dout  ,   // 输出高斯滤波结果
    output              gus_valid     // 输出数据有效
);          
    // 中间信号定义（来自行移位寄存器（行缓冲） shift_gus 的 3 行当前列像素）
    wire        [7:0]   taps0     ;   // 第 0 行（当前行）
    wire        [7:0]   taps1     ;   // 第 1 行（上一行）
    wire        [7:0]   taps2     ;   // 第 2 行（上两行）

    // 两级列方向打拍，用于卷积核 1-2-1 的列窗口
    reg         [7:0]   taps0_1   , taps1_1   , taps2_1   ; // 第 1 拍
    reg         [7:0]   taps0_2   , taps1_2   , taps2_2   ; // 第 2 拍

    // 行方向加权求和寄存
    reg         [10:0]  sum_1     ;   // 行1：1*L0 + 2*L0(延迟1) + 1*L0(延迟2)
    reg         [11:0]  sum_2     ;   // 行2：2*L1 + 4*L1(延迟1) + 2*L1(延迟2)
    reg         [10:0]  sum_3     ;   // 行3：1*L2 + 2*L2(延迟1) + 1*L2(延迟2)

    reg         [3:0]   valid_r   ;   // 输入有效信号打 4 拍，跟流水线对齐

    // valid_r：输入有效信号打拍
    always @(posedge clk or negedge rst_n) begin 
        if(!rst_n)
            valid_r <= 4'b0;
        else
            valid_r <= {valid_r[2:0], gray_valid};
    end

    // shift_gus 输出数据打两拍，实现 3 列窗口 (taps?, taps?_1, taps?_2)
    always @(posedge clk or negedge rst_n) begin 
        if(!rst_n) begin
            taps0_1 <= 8'b0; taps1_1 <= 8'b0; taps2_1 <= 8'b0;
            taps0_2 <= 8'b0; taps1_2 <= 8'b0; taps2_2 <= 8'b0;
        end else begin 
            taps0_1 <= taps0;  taps1_1 <= taps1;  taps2_1 <= taps2;
            taps0_2 <= taps0_1; taps1_2 <= taps1_1; taps2_2 <= taps2_1;
        end 
    end

    // 三行数据按 1-2-1 权重加权求和（行方向卷积）
    always @(posedge clk or negedge rst_n) begin 
        if(!rst_n) begin
            sum_1 <= 11'b0;
            sum_2 <= 12'b0;
            sum_3 <= 11'b0;
        end else if(valid_r[1]) begin 
            sum_1 <= taps0 + {taps0_1,1'b1} + taps0_2;             // 1,2,1
            sum_2 <= {taps1,1'b1} + {taps1_1,2'b11} + {taps1_2,1'b1}; // 2,4,2
            sum_3 <= taps2 + {taps2_1,1'b1} + taps2_2;             // 1,2,1
        end 
    end

    // 输出：行和再叠加后右移 4 位，相当于 1/16 归一化
    always @(posedge clk or negedge rst_n) begin 
        if(!rst_n)
            gus_dout <= 8'b0;
        else if(valid_r[2])
            gus_dout <= (sum_1 + sum_2 + sum_3) >> 4; // (1 2 1; 2 4 2; 1 2 1)/16
    end

    // 高斯滤波数据有效标志（对齐输出拍次）
    assign gus_valid = valid_r[3];

    // 行缓冲：产生 3 行同列像素 taps0/1/2
    shift_gus shift_gus_inst (
        .clken    (gray_valid),
        .clock    (clk       ),
        .shiftin  (gray_din  ),
        .shiftout (          ),
        .taps0x   (taps0     ),
        .taps1x   (taps1     ),
        .taps2x   (taps2     )
    );
endmodule