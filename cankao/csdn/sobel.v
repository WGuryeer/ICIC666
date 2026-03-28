/**************************************功能介绍***********************************
Copyright:			
Date     :			
Author   :厉长川			
Version  :2022.10.13 v1			
Description:边缘检测模块
     -1 0 +1      +1 +2 +1
Gx = -2 0 +2 Gy =  0  0  0
     -1 0 +1      -1 -2 -1
G = |Gx| + |Gy|;
*********************************************************************************/

`include "param.v"

module sobel( 
    input				clk		    ,//pclk
    input				rst_n	    ,//复位信号
    input				bin_din	    ,//二值化输入
    input	            bin_valid   ,//二值化输入有效标志

    output			    sobel_dout	,//边缘检测输出
    output		     	sobel_valid	 //边缘检测输出有效标志
);								 		                       
    //中间信号定义
    wire                taps0       ;//shift输出数据
    wire                taps1       ;//shift输出数据
    wire                taps2       ;//shift输出数据
    reg                 taps0_1     ;//第一拍数据
    reg                 taps1_1     ;//第一拍数据
    reg                 taps2_1     ;//第一拍数据
    reg                 taps0_2     ;//第二拍数据
    reg                 taps1_2     ;//第二拍数据
    reg                 taps2_2     ;//第二拍数据
    reg         [2:0]   sumx_1      ;//x方向第一列
    reg         [2:0]   sumx_3      ;//x方向第三列
    reg         [2:0]   sumy_1      ;//y方向第一行
    reg         [2:0]   sumy_3      ;//y方向第三行
    reg         [2:0]   g_x         ;//x方向梯度
    reg         [2:0]   g_y         ;//y方向梯度
    reg         [3:0]   g           ;//总梯度和
    reg         [4:0]   valid_r     ;//输入数据有效标志打四拍

    //valid_r:输入数据有效标志打四拍
    always @(posedge clk or negedge rst_n)begin 
        if(!rst_n)begin
            valid_r <= 5'b0;
        end 
        else begin 
            valid_r <= {valid_r[3:0], bin_valid};
        end 
    end

    //shift输出数据打拍
    always @(posedge clk or negedge rst_n)begin 
        if(!rst_n)begin
            taps0_1 <= 1'b0; 
            taps1_1 <= 1'b0;
            taps2_1 <= 1'b0;
            taps0_2 <= 1'b0;
            taps1_2 <= 1'b0;
            taps2_2 <= 1'b0;
        end 
        else begin 
            taps0_1 <= taps0  ; 
            taps1_1 <= taps1  ;
            taps2_1 <= taps2  ;
            taps0_2 <= taps0_1;
            taps1_2 <= taps1_1;
            taps2_2 <= taps2_1;
        end 
    end

    //加权和
    always @(posedge clk or negedge rst_n)begin 
        if(!rst_n)begin
            sumx_1 <= 3'b0;
            sumx_3 <= 3'b0;
            sumy_1 <= 3'b0;
            sumy_3 <= 3'b0;
        end 
        else if(valid_r[1])begin 
            sumx_1 <= taps0 + {taps1  ,1'b1} + taps2;
            sumx_3 <= taps0_2 + {taps1_2,1'b1} + taps2_2;
            sumy_1 <= taps0 + {taps0_1,1'b1} + taps0_2;
            sumy_3 <= taps2 + {taps2_1,1'b1} + taps2_2;
        end 
    end

    //x和y方向梯度
    always @(posedge clk or negedge rst_n)begin 
        if(!rst_n)begin
            g_x <= 3'b0;
            g_y <= 3'b0;
        end 
        else if(valid_r[2])begin 
            g_x <= (sumx_1 > sumx_3)?sumx_1 - sumx_3:sumx_3 - sumx_1;
            g_y <= (sumy_1 > sumy_3)?sumy_1 - sumy_3:sumy_3 - sumy_1;
        end 
    end

    //g:总梯度和
    always @(posedge clk or negedge rst_n)begin 
        if(!rst_n)begin
            g <= 4'b0;
        end 
        else if(valid_r[3])begin 
            g <= g_x + g_y;
        end 
    end

    //边缘检测结果
    assign sobel_dout = (g > `SOBEL)?1'b1:1'b0;

    //边缘检测数据有效标志
    assign sobel_valid = valid_r[4];

    shift_sobel	shift_sobel_inst (
        .clken    ( bin_valid ),
        .clock    ( clk       ),
        .shiftin  ( bin_din   ),
        .shiftout (           ),
        .taps0x   ( taps0     ),
        .taps1x   ( taps1     ),
        .taps2x   ( taps2     )
    );

endmodule
