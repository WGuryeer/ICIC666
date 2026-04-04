module binarization(

    input               clk             ,   
    input               rst_n           ,   

    input               vsync_in     ,   // vs in
    input               de_in        ,   // de i
    input   [7:0]       data_in       ,


    output              vsync_out      ,   // vs o
    output              de_out         ,   // de o
    output   reg        pix_data            
);

//reg define
reg    vsync_in_d;
reg    hsync_in_d;
reg    de_in_d   ;

parameter Binar_THRESHOLD = 40;

assign  vsync_out = vsync_in_d  ;
assign  hsync_out = hsync_in_d  ;
assign  de_out    = de_in_d     ;

//二值化
always @(posedge clk or negedge rst_n) begin
    if(!rst_n)
        pix_data <= 1'b0;
    else if(data_in > Binar_THRESHOLD)  //阈值
        pix_data <= 1'b1;
    else
        pix_data <= 1'b0;
end

//延时1拍以同步时钟信号
always@(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        vsync_in_d <= 1'd0;
        de_in_d    <= 1'd0;
    end
    else begin
        vsync_in_d <= vsync_in;
        de_in_d    <= de_in   ;
    end
end

endmodule 