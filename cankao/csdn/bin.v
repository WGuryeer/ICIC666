/**************************************功能介绍***********************************
Copyright:			
Date     :			
Author   :厉长川			
Version  :2022.10.14 v2	简化算法
          2022.10.13 v1			
Description:二值化模块		
*********************************************************************************/

`include "param.v"

module bin( 
    input				clk		  ,//pclk
    input				rst_n	  ,//复位信号
    input		[7:0]	gus_din	  ,//高斯滤波输入
    input		        gus_valid ,//高斯滤波输入有效标志

    output	     	    bin_dout  ,//二值化输出
    output	        	bin_valid  //二值化输出有效标志
);		

    //bin_dout:二值化输出
    assign bin_dout = (gus_din > `BIN)?1'b1:1'b0;

    //bin_valid:二值化输出有效标志
    assign bin_valid = gus_valid;
                        
endmodule
