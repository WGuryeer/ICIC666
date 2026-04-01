/**************************************功能介绍***********************************
Description : 二值化模块，把 8-bit 灰度输入与阈值 `BIN` 比较，输出 1/0
Version     : 2022.10.14 v2 简化算法
Author      : 厉长川
Note        : `BIN` 在 param.v 中定义，需根据画面对比度调整
*********************************************************************************/

`include "param.v"

module bin( 
    input         clk,        // 像素时钟 pclk（本模块内部未用，但保留接口以便同步设计）
    input         rst_n,      // 低有效复位（本模块未用）
    input  [7:0]  gus_din,    // 高斯滤波后的 8 位灰度输入
    input         gus_valid,  // 输入数据有效标志

    output        bin_dout,   // 二值化输出：1=前景/边缘，0=背景
    output        bin_valid   // 二值化输出有效标志，与输入有效保持对齐
);		
    // 主逻辑：比较阈值 `BIN`，大于即输出 1，否则 0
    assign bin_dout  = (gus_din > `BIN) ? 1'b1 : 1'b0;

    // 有效信号直接透传，对齐数据
    assign bin_valid = gus_valid;               
endmodule