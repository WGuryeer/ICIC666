//dilate 膨胀，适配 4×4 窗口
module	dilate
(
	input	wire			video_clk	,	//像素时钟
	input	wire			rst_n		,
	
	//输入二值化数据（4×4 窗口）
	input	wire			bin_vs		,
	input	wire			bin_de		,
	input	wire			bin_data_11	,
	input	wire			bin_data_12	,
	input	wire			bin_data_13	,
	input	wire			bin_data_14	,
	input	wire			bin_data_21	,
	input	wire			bin_data_22	,
	input	wire			bin_data_23	,
	input	wire			bin_data_24	,
	input	wire			bin_data_31	,
	input	wire			bin_data_32	,
	input	wire			bin_data_33	,
	input	wire			bin_data_34	,
	input	wire			bin_data_41	,
	input	wire			bin_data_42	,
	input	wire			bin_data_43	,
	input	wire			bin_data_44	,

	output	wire			dilate_vs	,
	output	wire			dilate_de	,
	output	wire			dilate_data	

);

/**********************************************************
reg define
**********************************************************/
reg	dilate_vs_d	;	
reg	dilate_vs_d1;	
reg	dilate_de_d	;
reg	dilate_de_d1;
reg	dilate_data_d;
reg dilate_line0;
reg dilate_line1;
reg dilate_line2;
reg dilate_line3;

// 1clk  行膨胀 相或（每行 4 个像素）
always@(posedge video_clk or negedge rst_n)	begin
	if(!rst_n) begin
         dilate_line0    <= 1'd0;
         dilate_line1    <= 1'd0;
         dilate_line2    <= 1'd0;
         dilate_line3    <= 1'd0;
    end
    else if(bin_de) begin
        dilate_line0    <= bin_data_11 || bin_data_12 || bin_data_13 || bin_data_14;
        dilate_line1    <= bin_data_21 || bin_data_22 || bin_data_23 || bin_data_24;
        dilate_line2    <= bin_data_31 || bin_data_32 || bin_data_33 || bin_data_34;
        dilate_line3    <= bin_data_41 || bin_data_42 || bin_data_43 || bin_data_44;
    end
end

// 1clk  膨胀 相或（4 行合并）
always@(posedge video_clk or negedge rst_n)	begin
	if(!rst_n)
		dilate_data_d	<=	1'd0;
    else
		dilate_data_d	<=	dilate_line0 || dilate_line1 || dilate_line2 || dilate_line3;
end

// 延迟2clk（保持原时序）
always@(posedge video_clk or negedge rst_n)	begin
	if(!rst_n) begin	
		dilate_vs_d	 <= 1'd0;
        dilate_vs_d1 <= 1'd0;  
        dilate_de_d	 <= 1'd0;
        dilate_de_d1 <= 1'd0;       
	end
	else begin	
		dilate_vs_d	 <= bin_vs;
        dilate_vs_d1 <= dilate_vs_d; 
        dilate_de_d	 <= bin_de;
        dilate_de_d1 <= dilate_de_d;    
	end
end

assign dilate_data = dilate_data_d;					  
assign	dilate_vs  = dilate_vs_d1;	
assign  dilate_de  = dilate_de_d1;

endmodule