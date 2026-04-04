module ero_dil_top (
    input  wire video_clk,
    input  wire rst_n,

    // 来自前级二值化的流（1bit）
    input  wire vsync_out,   // vs
    input  wire de_out,      // de
    input  wire pix_data,    // 1bit 二值像素

    // 输出 6×6 腐蚀结果
    output wire erosion_vs,
    output wire erosion_de,
    output wire erosion_data
);

    //------------------------------------------------------------
    // 4×4 窗口生成
    //------------------------------------------------------------
    wire        m4_de;
    wire        m4_11, m4_12, m4_13, m4_14;
    wire        m4_21, m4_22, m4_23, m4_24;
    wire        m4_31, m4_32, m4_33, m4_34;
    wire        m4_41, m4_42, m4_43, m4_44;

    matrix_4x4 u_matrix_4x4 (
        .video_clk  (video_clk),
        .rst_n      (rst_n),
        .video_vs   (vsync_out),
        .video_de   (de_out),
        .video_data (pix_data),
        .matrix_de  (m4_de),
        .matrix11(m4_11), .matrix12(m4_12), .matrix13(m4_13), .matrix14(m4_14),
        .matrix21(m4_21), .matrix22(m4_22), .matrix23(m4_23), .matrix24(m4_24),
        .matrix31(m4_31), .matrix32(m4_32), .matrix33(m4_33), .matrix34(m4_34),
        .matrix41(m4_41), .matrix42(m4_42), .matrix43(m4_43), .matrix44(m4_44)
    );

    //------------------------------------------------------------
    // 4×4 膨胀
    //------------------------------------------------------------
    wire dilate_vs, dilate_de, dilate_data;

    dilate u_dilate (
        .video_clk   (video_clk),
        .rst_n       (rst_n),
        .bin_vs      (vsync_out),   // VS 保持原始路径
        .bin_de      (m4_de),
        .bin_data_11 (m4_11), .bin_data_12 (m4_12), .bin_data_13 (m4_13), .bin_data_14 (m4_14),
        .bin_data_21 (m4_21), .bin_data_22 (m4_22), .bin_data_23 (m4_23), .bin_data_24 (m4_24),
        .bin_data_31 (m4_31), .bin_data_32 (m4_32), .bin_data_33 (m4_33), .bin_data_34 (m4_34),
        .bin_data_41 (m4_41), .bin_data_42 (m4_42), .bin_data_43 (m4_43), .bin_data_44 (m4_44),
        .dilate_vs   (dilate_vs),
        .dilate_de   (dilate_de),
        .dilate_data (dilate_data)  // 1bit
    );

    //------------------------------------------------------------
    // 6×6 窗口生成
    //------------------------------------------------------------
    wire        m6_de;
    wire        m6_11,m6_12,m6_13,m6_14,m6_15,m6_16;
    wire        m6_21,m6_22,m6_23,m6_24,m6_25,m6_26;
    wire        m6_31,m6_32,m6_33,m6_34,m6_35,m6_36;
    wire        m6_41,m6_42,m6_43,m6_44,m6_45,m6_46;
    wire        m6_51,m6_52,m6_53,m6_54,m6_55,m6_56;
    wire        m6_61,m6_62,m6_63,m6_64,m6_65,m6_66;

    matrix_6x6 u_matrix_6x6 (
        .video_clk  (video_clk),
        .rst_n      (rst_n),
        .video_vs   (dilate_vs),
        .video_de   (dilate_de),
        .video_data (dilate_data), 
        .matrix_de  (m6_de),
        .matrix11(m6_11), .matrix12(m6_12), .matrix13(m6_13), .matrix14(m6_14), .matrix15(m6_15), .matrix16(m6_16),
        .matrix21(m6_21), .matrix22(m6_22), .matrix23(m6_23), .matrix24(m6_24), .matrix25(m6_25), .matrix26(m6_26),
        .matrix31(m6_31), .matrix32(m6_32), .matrix33(m6_33), .matrix34(m6_34), .matrix35(m6_35), .matrix36(m6_36),
        .matrix41(m6_41), .matrix42(m6_42), .matrix43(m6_43), .matrix44(m6_44), .matrix45(m6_45), .matrix46(m6_46),
        .matrix51(m6_51), .matrix52(m6_52), .matrix53(m6_53), .matrix54(m6_54), .matrix55(m6_55), .matrix56(m6_56),
        .matrix61(m6_61), .matrix62(m6_62), .matrix63(m6_63), .matrix64(m6_64), .matrix65(m6_65), .matrix66(m6_66)
    );

    //------------------------------------------------------------
    // 6×6 腐蚀
    //------------------------------------------------------------
    erosion u_erosion (
        .video_clk   (video_clk),
        .rst_n       (rst_n),
        .bin_vs      (dilate_vs),
        .bin_de      (m6_de),
        .bin_data_11 (m6_11), .bin_data_12 (m6_12), .bin_data_13 (m6_13),
        .bin_data_14 (m6_14), .bin_data_15 (m6_15), .bin_data_16 (m6_16),
        .bin_data_21 (m6_21), .bin_data_22 (m6_22), .bin_data_23 (m6_23),
        .bin_data_24 (m6_24), .bin_data_25 (m6_25), .bin_data_26 (m6_26),
        .bin_data_31 (m6_31), .bin_data_32 (m6_32), .bin_data_33 (m6_33),
        .bin_data_34 (m6_34), .bin_data_35 (m6_35), .bin_data_36 (m6_36),
        .bin_data_41 (m6_41), .bin_data_42 (m6_42), .bin_data_43 (m6_43),
        .bin_data_44 (m6_44), .bin_data_45 (m6_45), .bin_data_46 (m6_46),
        .bin_data_51 (m6_51), .bin_data_52 (m6_52), .bin_data_53 (m6_53),
        .bin_data_54 (m6_54), .bin_data_55 (m6_55), .bin_data_56 (m6_56),
        .bin_data_61 (m6_61), .bin_data_62 (m6_62), .bin_data_63 (m6_63),
        .bin_data_64 (m6_64), .bin_data_65 (m6_65), .bin_data_66 (m6_66),
        .erosion_vs  (erosion_vs),
        .erosion_de  (erosion_de),
        .erosion_data(erosion_data)
    );

endmodule