	vga u0 (
		.av_config_SDAT              (<connected-to-av_config_SDAT>),              //      av_config.SDAT
		.av_config_SCLK              (<connected-to-av_config_SCLK>),              //               .SCLK
		.clk_clk                     (<connected-to-clk_clk>),                     //            clk.clk
		.reset_reset_n               (<connected-to-reset_reset_n>),               //          reset.reset_n
		.sram_DQ                     (<connected-to-sram_DQ>),                     //           sram.DQ
		.sram_ADDR                   (<connected-to-sram_ADDR>),                   //               .ADDR
		.sram_LB_N                   (<connected-to-sram_LB_N>),                   //               .LB_N
		.sram_UB_N                   (<connected-to-sram_UB_N>),                   //               .UB_N
		.sram_CE_N                   (<connected-to-sram_CE_N>),                   //               .CE_N
		.sram_OE_N                   (<connected-to-sram_OE_N>),                   //               .OE_N
		.sram_WE_N                   (<connected-to-sram_WE_N>),                   //               .WE_N
		.vga_controller_CLK          (<connected-to-vga_controller_CLK>),          // vga_controller.CLK
		.vga_controller_HS           (<connected-to-vga_controller_HS>),           //               .HS
		.vga_controller_VS           (<connected-to-vga_controller_VS>),           //               .VS
		.vga_controller_BLANK        (<connected-to-vga_controller_BLANK>),        //               .BLANK
		.vga_controller_SYNC         (<connected-to-vga_controller_SYNC>),         //               .SYNC
		.vga_controller_R            (<connected-to-vga_controller_R>),            //               .R
		.vga_controller_G            (<connected-to-vga_controller_G>),            //               .G
		.vga_controller_B            (<connected-to-vga_controller_B>),            //               .B
		.video_decoder_TD_CLK27      (<connected-to-video_decoder_TD_CLK27>),      //  video_decoder.TD_CLK27
		.video_decoder_TD_DATA       (<connected-to-video_decoder_TD_DATA>),       //               .TD_DATA
		.video_decoder_TD_HS         (<connected-to-video_decoder_TD_HS>),         //               .TD_HS
		.video_decoder_TD_VS         (<connected-to-video_decoder_TD_VS>),         //               .TD_VS
		.video_decoder_clk27_reset   (<connected-to-video_decoder_clk27_reset>),   //               .clk27_reset
		.video_decoder_TD_RESET      (<connected-to-video_decoder_TD_RESET>),      //               .TD_RESET
		.video_decoder_overflow_flag (<connected-to-video_decoder_overflow_flag>)  //               .overflow_flag
	);

