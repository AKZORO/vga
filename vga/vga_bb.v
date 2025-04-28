
module vga (
	av_config_SDAT,
	av_config_SCLK,
	clk_clk,
	reset_reset_n,
	sram_DQ,
	sram_ADDR,
	sram_LB_N,
	sram_UB_N,
	sram_CE_N,
	sram_OE_N,
	sram_WE_N,
	vga_controller_CLK,
	vga_controller_HS,
	vga_controller_VS,
	vga_controller_BLANK,
	vga_controller_SYNC,
	vga_controller_R,
	vga_controller_G,
	vga_controller_B,
	video_decoder_TD_CLK27,
	video_decoder_TD_DATA,
	video_decoder_TD_HS,
	video_decoder_TD_VS,
	video_decoder_clk27_reset,
	video_decoder_TD_RESET,
	video_decoder_overflow_flag);	

	inout		av_config_SDAT;
	output		av_config_SCLK;
	input		clk_clk;
	input		reset_reset_n;
	inout	[15:0]	sram_DQ;
	output	[19:0]	sram_ADDR;
	output		sram_LB_N;
	output		sram_UB_N;
	output		sram_CE_N;
	output		sram_OE_N;
	output		sram_WE_N;
	output		vga_controller_CLK;
	output		vga_controller_HS;
	output		vga_controller_VS;
	output		vga_controller_BLANK;
	output		vga_controller_SYNC;
	output	[7:0]	vga_controller_R;
	output	[7:0]	vga_controller_G;
	output	[7:0]	vga_controller_B;
	input		video_decoder_TD_CLK27;
	input	[7:0]	video_decoder_TD_DATA;
	input		video_decoder_TD_HS;
	input		video_decoder_TD_VS;
	input		video_decoder_clk27_reset;
	output		video_decoder_TD_RESET;
	output		video_decoder_overflow_flag;
endmodule
