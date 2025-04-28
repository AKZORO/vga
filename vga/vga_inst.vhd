	component vga is
		port (
			av_config_SDAT              : inout std_logic                     := 'X';             -- SDAT
			av_config_SCLK              : out   std_logic;                                        -- SCLK
			clk_clk                     : in    std_logic                     := 'X';             -- clk
			reset_reset_n               : in    std_logic                     := 'X';             -- reset_n
			sram_DQ                     : inout std_logic_vector(15 downto 0) := (others => 'X'); -- DQ
			sram_ADDR                   : out   std_logic_vector(19 downto 0);                    -- ADDR
			sram_LB_N                   : out   std_logic;                                        -- LB_N
			sram_UB_N                   : out   std_logic;                                        -- UB_N
			sram_CE_N                   : out   std_logic;                                        -- CE_N
			sram_OE_N                   : out   std_logic;                                        -- OE_N
			sram_WE_N                   : out   std_logic;                                        -- WE_N
			vga_controller_CLK          : out   std_logic;                                        -- CLK
			vga_controller_HS           : out   std_logic;                                        -- HS
			vga_controller_VS           : out   std_logic;                                        -- VS
			vga_controller_BLANK        : out   std_logic;                                        -- BLANK
			vga_controller_SYNC         : out   std_logic;                                        -- SYNC
			vga_controller_R            : out   std_logic_vector(7 downto 0);                     -- R
			vga_controller_G            : out   std_logic_vector(7 downto 0);                     -- G
			vga_controller_B            : out   std_logic_vector(7 downto 0);                     -- B
			video_decoder_TD_CLK27      : in    std_logic                     := 'X';             -- TD_CLK27
			video_decoder_TD_DATA       : in    std_logic_vector(7 downto 0)  := (others => 'X'); -- TD_DATA
			video_decoder_TD_HS         : in    std_logic                     := 'X';             -- TD_HS
			video_decoder_TD_VS         : in    std_logic                     := 'X';             -- TD_VS
			video_decoder_clk27_reset   : in    std_logic                     := 'X';             -- clk27_reset
			video_decoder_TD_RESET      : out   std_logic;                                        -- TD_RESET
			video_decoder_overflow_flag : out   std_logic                                         -- overflow_flag
		);
	end component vga;

	u0 : component vga
		port map (
			av_config_SDAT              => CONNECTED_TO_av_config_SDAT,              --      av_config.SDAT
			av_config_SCLK              => CONNECTED_TO_av_config_SCLK,              --               .SCLK
			clk_clk                     => CONNECTED_TO_clk_clk,                     --            clk.clk
			reset_reset_n               => CONNECTED_TO_reset_reset_n,               --          reset.reset_n
			sram_DQ                     => CONNECTED_TO_sram_DQ,                     --           sram.DQ
			sram_ADDR                   => CONNECTED_TO_sram_ADDR,                   --               .ADDR
			sram_LB_N                   => CONNECTED_TO_sram_LB_N,                   --               .LB_N
			sram_UB_N                   => CONNECTED_TO_sram_UB_N,                   --               .UB_N
			sram_CE_N                   => CONNECTED_TO_sram_CE_N,                   --               .CE_N
			sram_OE_N                   => CONNECTED_TO_sram_OE_N,                   --               .OE_N
			sram_WE_N                   => CONNECTED_TO_sram_WE_N,                   --               .WE_N
			vga_controller_CLK          => CONNECTED_TO_vga_controller_CLK,          -- vga_controller.CLK
			vga_controller_HS           => CONNECTED_TO_vga_controller_HS,           --               .HS
			vga_controller_VS           => CONNECTED_TO_vga_controller_VS,           --               .VS
			vga_controller_BLANK        => CONNECTED_TO_vga_controller_BLANK,        --               .BLANK
			vga_controller_SYNC         => CONNECTED_TO_vga_controller_SYNC,         --               .SYNC
			vga_controller_R            => CONNECTED_TO_vga_controller_R,            --               .R
			vga_controller_G            => CONNECTED_TO_vga_controller_G,            --               .G
			vga_controller_B            => CONNECTED_TO_vga_controller_B,            --               .B
			video_decoder_TD_CLK27      => CONNECTED_TO_video_decoder_TD_CLK27,      --  video_decoder.TD_CLK27
			video_decoder_TD_DATA       => CONNECTED_TO_video_decoder_TD_DATA,       --               .TD_DATA
			video_decoder_TD_HS         => CONNECTED_TO_video_decoder_TD_HS,         --               .TD_HS
			video_decoder_TD_VS         => CONNECTED_TO_video_decoder_TD_VS,         --               .TD_VS
			video_decoder_clk27_reset   => CONNECTED_TO_video_decoder_clk27_reset,   --               .clk27_reset
			video_decoder_TD_RESET      => CONNECTED_TO_video_decoder_TD_RESET,      --               .TD_RESET
			video_decoder_overflow_flag => CONNECTED_TO_video_decoder_overflow_flag  --               .overflow_flag
		);

