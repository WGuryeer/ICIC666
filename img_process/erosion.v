//erosion 腐蚀（6x6 输入，保持原逻辑：先行相与，再行间相与，延迟2clk）
module	erosion
(
	input	wire			video_clk	,	//像素时钟
	input	wire			rst_n		,
	
	//输入二值化数据（6x6）
	input	wire			bin_vs		,
	input	wire			bin_de		,
	input	wire			bin_data_11	, input wire bin_data_12, input wire bin_data_13, input wire bin_data_14, input wire bin_data_15, input wire bin_data_16,
	input	wire			bin_data_21	, input wire bin_data_22, input wire bin_data_23, input wire bin_data_24, input wire bin_data_25, input wire bin_data_26,
	input	wire			bin_data_31	, input wire bin_data_32, input wire bin_data_33, input wire bin_data_34, input wire bin_data_35, input wire bin_data_36,
	input	wire			bin_data_41	, input wire bin_data_42, input wire bin_data_43, input wire bin_data_44, input wire bin_data_45, input wire bin_data_46,
	input	wire			bin_data_51	, input wire bin_data_52, input wire bin_data_53, input wire bin_data_54, input wire bin_data_55, input wire bin_data_56,
	input	wire			bin_data_61	, input wire bin_data_62, input wire bin_data_63, input wire bin_data_64, input wire bin_data_65, input wire bin_data_66,

	output	wire			erosion_vs	,
	output	wire			erosion_de	,
	output	wire			erosion_data
);

/**********************************************************
reg define
**********************************************************/
reg	erosion_vs_d	;	
reg	erosion_vs_d1	;	
reg	erosion_de_d	;
reg	erosion_de_d1	;
reg	erosion_data_d	;
reg erosion_line0   ;
reg erosion_line1   ;
reg erosion_line2   ;
reg erosion_line3   ;
reg erosion_line4   ;
reg erosion_line5   ;

// 1clk  行腐蚀 相与
always@(posedge video_clk or negedge rst_n)	begin
	if(!rst_n) begin
         erosion_line0 <= 1'd0;
         erosion_line1 <= 1'd0;
         erosion_line2 <= 1'd0;
         erosion_line3 <= 1'd0;
         erosion_line4 <= 1'd0;
         erosion_line5 <= 1'd0;
    end
    else if(bin_de) begin
         erosion_line0 <= bin_data_11 && bin_data_12 && bin_data_13 && bin_data_14 && bin_data_15 && bin_data_16;
         erosion_line1 <= bin_data_21 && bin_data_22 && bin_data_23 && bin_data_24 && bin_data_25 && bin_data_26;
         erosion_line2 <= bin_data_31 && bin_data_32 && bin_data_33 && bin_data_34 && bin_data_35 && bin_data_36;
         erosion_line3 <= bin_data_41 && bin_data_42 && bin_data_43 && bin_data_44 && bin_data_45 && bin_data_46;
         erosion_line4 <= bin_data_51 && bin_data_52 && bin_data_53 && bin_data_54 && bin_data_55 && bin_data_56;
         erosion_line5 <= bin_data_61 && bin_data_62 && bin_data_63 && bin_data_64 && bin_data_65 && bin_data_66;
    end
end

// 1clk  腐蚀 相与
always@(posedge video_clk or negedge rst_n)	begin
	if(!rst_n)
		erosion_data_d <= 1'd0;
    else
		erosion_data_d <= erosion_line0 && erosion_line1 && erosion_line2 && erosion_line3 && erosion_line4 && erosion_line5;
end

// 延迟2clk（保持原逻辑不变）
always@(posedge video_clk or negedge rst_n)	begin
	if(!rst_n) begin	
		erosion_vs_d  <= 1'd0;
        erosion_vs_d1 <= 1'd0;  
        erosion_de_d  <= 1'd0;
        erosion_de_d1 <= 1'd0;         
	end
	else begin	
		erosion_vs_d  <= bin_vs;
        erosion_vs_d1 <= erosion_vs_d; 
        erosion_de_d  <= bin_de;
        erosion_de_d1 <= erosion_de_d;    
	end
end

assign erosion_data = erosion_data_d;
assign erosion_vs   = erosion_vs_d1;	
assign erosion_de   = erosion_de_d1;

endmodule