
module gus_filter( 
    input				clk		  ,
    input				rst_n	  ,
    input		[7:0]   gray_din  ,
    input		        gray_valid,

    output	reg	[7:0]	gus_dout  ,
    output		        gus_valid	
);			
    //中间信号定义
    wire        [7:0]   taps0     ;//shift输出数据
    wire        [7:0]   taps1     ;//shift输出数据
    wire        [7:0]   taps2     ;//shift输出数据
    reg         [7:0]   taps0_1   ;//第一拍数据
    reg         [7:0]   taps1_1   ;//第一拍数据
    reg         [7:0]   taps2_1   ;//第一拍数据
    reg         [7:0]   taps0_2   ;//第二拍数据
    reg         [7:0]   taps1_2   ;//第二拍数据
    reg         [7:0]   taps2_2   ;//第二拍数据
    reg         [10:0]  sum_1     ;//第一行加权和
    reg         [11:0]  sum_2     ;//第二行加权和
    reg         [10:0]  sum_3     ;//第三行加权和
    reg         [3:0]   valid_r   ;//输入数据有效标志打四拍

    //valid_r:输入数据有效标志打四拍
    always @(posedge clk or negedge rst_n)begin 
        if(!rst_n)begin
            valid_r <= 4'b0;
        end 
        else begin 
            valid_r <= {valid_r[2:0], gray_valid};
        end 
    end

    //shift输出数据打拍
    always @(posedge clk or negedge rst_n)begin 
        if(!rst_n)begin
            taps0_1 <= 8'b0; 
            taps1_1 <= 8'b0;
            taps2_1 <= 8'b0;
            taps0_2 <= 8'b0;
            taps1_2 <= 8'b0;
            taps2_2 <= 8'b0;
        end 
        else begin 
            taps0_1 <= taps0; 
            taps1_1 <= taps1;
            taps2_1 <= taps2;
            taps0_2 <= taps0_1;
            taps1_2 <= taps1_1;
            taps2_2 <= taps2_1;
        end 
    end

    //三行数据加权和计算
    always @(posedge clk or negedge rst_n)begin 
        if(!rst_n)begin
            sum_1 <= 11'b0;
            sum_2 <= 12'b0;
            sum_3 <= 11'b0;
        end 
        else if(valid_r[1])begin 
            sum_1 <= taps0 + {taps0_1,1'b1} + taps0_2;
            sum_2 <= {taps1,1'b1} + {taps1_1,2'b11} + {taps1_2,1'b1};
            sum_3 <= taps2 + {taps2_1,1'b1} + taps2_2;
        end 
    end

    //最后结果输出
    always @(posedge clk or negedge rst_n)begin 
        if(!rst_n)begin
            gus_dout <= 8'b0;
        end 
        else if(valid_r[2])begin 
            gus_dout <= (sum_1 + sum_2 + sum_3) >> 3'd4;
        end 
    end

    //高斯滤波数据有效标志
    assign gus_valid = valid_r[3];

    shift_gus	shift_gus_inst (
        .clken    (gray_valid),
        .clock    (clk       ),
        .shiftin  (gray_din  ),
        .shiftout (          ),
        .taps0x   (taps0     ),
        .taps1x   (taps1     ),
        .taps2x   (taps2     )
    );
                        
endmodule
