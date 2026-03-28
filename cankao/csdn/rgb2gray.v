/**************************************功能介绍***********************************
Copyright:			
Date     :			
Author   :厉长川			
Version  :2022.10.12 v1			
Description:灰度转换模块
心理学公式:Gray = R*0.299 + G*0.587 + B*0.114, Gray = R*38 + G*75 + B*15 >> 7
*********************************************************************************/

module rgb2gray( 
    input				clk		  ,//pclk
    input				rst_n	  ,//复位信号
    input               rgb_valid ,//rgb数据有效标志
    input		[15:0]	rgb_din   ,//rgb数据输入

    output		[7:0]	gray_dout ,//灰度转换输出
    output	         	gray_valid //灰度转换数据有效标志
);								                  
    //中间信号定义		 
    wire	    [7:0]	r         ;//rgb888
    wire	    [7:0]	g         ;//rgb888
    wire        [7:0]   b         ;//rgb888
    reg         [2:0]   valid_r   ;//rgb数据有效标志打拍
    reg         [14:0]  r_u       ;//灰度转换运算寄存
    reg         [14:0]  g_u       ;//灰度转换运算寄存
    reg         [14:0]  b_u       ;//灰度转换运算寄存
    reg         [14:0]  u_out     ;//运算和寄存

    //RGB565转RGB888:采用量化补偿的方式
    assign r = {rgb_din[15:11], rgb_din[13:11]};
    assign g = {rgb_din[10:5], rgb_din[6:5]};
    assign b = {rgb_din[4:0], rgb_din[2:0]};

    //valid_r:rgb数据有效标志打拍
    always @(posedge clk or negedge rst_n)begin 
        if(!rst_n)begin
            valid_r <= 2'b0;
        end 
        else begin 
            valid_r <= {valid_r[1:0], rgb_valid};
        end 
    end

    //7位精度的灰度转换运算
    always @(posedge clk or negedge rst_n)begin 
        if(!rst_n)begin
            r_u <= 15'b0; 
            g_u <= 15'b0; 
            b_u <= 15'b0;
        end 
        else if(valid_r[0])begin 
            r_u <= r*7'd38; 
            g_u <= g*7'd75; 
            b_u <= b*7'd15;
        end 
    end

    //u_out:运算和
    always @(posedge clk or negedge rst_n)begin 
        if(!rst_n)begin
            u_out <= 15'b0;
        end 
        else if(valid_r[1])begin 
            u_out <= r_u + g_u + b_u;
        end 
    end

    //gray_dout:灰度转换结果
    assign gray_dout = u_out[7 +:8];

    //gray_valid:灰度转换完成标志
    assign gray_valid = valid_r[2];
                        
endmodule
