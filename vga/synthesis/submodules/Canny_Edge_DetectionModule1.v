module Canny_Edge_DetectionModule (
    input clk,
    input reset,
    input clk_en,
    input [23:0] iPixel,
    input stream_in_startofpacket,
    input stream_in_endofpacket,
    input [1:0] stream_in_empty,
    input stream_in_valid,
    output reg [23:0] oPixel,
    output reg stream_out_startofpacket,
    output reg stream_out_endofpacket,
    output reg [1:0] stream_out_empty,
    output reg stream_out_valid
);

parameter HIGH_THRESH = 150;
parameter LOW_THRESH = 50;

//--------------------------------------------------------------
// Pipeline Registers
//--------------------------------------------------------------
reg [7:0] stage0_buffer [0:2][0:2];  // 3x3 window buffer
reg [9:0] stage1_gaussian;           // Gaussian blur output
reg signed [10:0] stage2_gx;         // X gradient
reg signed [10:0] stage2_gy;         // Y gradient
reg [7:0] stage3_mag;                // Gradient magnitude
reg [1:0] stage3_dir;                // Gradient direction
reg [7:0] stage4_suppressed;         // Non-max suppression
reg [1:0] stage5_edge;               // Threshold result

//--------------------------------------------------------------
// Control Signal Pipeline
//--------------------------------------------------------------
reg [4:0] sop_pipe, eop_pipe, valid_pipe;
reg [1:0] empty_pipe [0:4];
integer i;

//--------------------------------------------------------------
// Kernel Initialization (Reset-Based)
//--------------------------------------------------------------
reg [7:0] gaussian_kernel [0:8];
reg signed [3:0] sobel_x [0:8];
reg signed [3:0] sobel_y [0:8];

always @(posedge clk) begin
    if (reset) begin
        // Gaussian Kernel
        gaussian_kernel[0] <= 1; gaussian_kernel[1] <= 2; gaussian_kernel[2] <= 1;
        gaussian_kernel[3] <= 2; gaussian_kernel[4] <= 4; gaussian_kernel[5] <= 2;
        gaussian_kernel[6] <= 1; gaussian_kernel[7] <= 2; gaussian_kernel[8] <= 1;

        // Sobel X
        sobel_x[0] <= -1; sobel_x[1] <= 0; sobel_x[2] <= 1;
        sobel_x[3] <= -2; sobel_x[4] <= 0; sobel_x[5] <= 2;
        sobel_x[6] <= -1; sobel_x[7] <= 0; sobel_x[8] <= 1;

        // Sobel Y
        sobel_y[0] <= -1; sobel_y[1] <= -2; sobel_y[2] <= -1;
        sobel_y[3] <= 0;  sobel_y[4] <= 0;  sobel_y[5] <= 0;
        sobel_y[6] <= 1;  sobel_y[7] <= 2;  sobel_y[8] <= 1;
    end
end

//--------------------------------------------------------------
// Stage 0: 3x3 Window Buffer
//--------------------------------------------------------------
always @(posedge clk) begin
    if (reset) begin
        for (i = 0; i < 3; i = i+1) begin
            stage0_buffer[0][i] <= 0;
            stage0_buffer[1][i] <= 0;
            stage0_buffer[2][i] <= 0;
        end
    end
    else if (clk_en) begin
        // Shift columns
        for (i = 0; i < 2; i = i+1) begin
            stage0_buffer[0][i] <= stage0_buffer[0][i+1];
            stage0_buffer[1][i] <= stage0_buffer[1][i+1];
            stage0_buffer[2][i] <= stage0_buffer[2][i+1];
        end
        
        // Insert new pixel
        stage0_buffer[2][2] <= iPixel[7:0];  // Y component
        stage0_buffer[1][2] <= stage0_buffer[2][2];
        stage0_buffer[0][2] <= stage0_buffer[1][2];
    end
end

//--------------------------------------------------------------
// Stage 1: Gaussian Blur
//--------------------------------------------------------------
always @(posedge clk) begin
    if (clk_en) begin
        stage1_gaussian <= 
            (stage0_buffer[0][0] * gaussian_kernel[0]) +
            (stage0_buffer[0][1] * gaussian_kernel[1]) +
            (stage0_buffer[0][2] * gaussian_kernel[2]) +
            (stage0_buffer[1][0] * gaussian_kernel[3]) +
            (stage0_buffer[1][1] * gaussian_kernel[4]) +
            (stage0_buffer[1][2] * gaussian_kernel[5]) +
            (stage0_buffer[2][0] * gaussian_kernel[6]) +
            (stage0_buffer[2][1] * gaussian_kernel[7]) +
            (stage0_buffer[2][2] * gaussian_kernel[8]);
    end
end

//--------------------------------------------------------------
// Stage 2: Sobel Gradients (Manual Absolute Value)
//--------------------------------------------------------------
always @(posedge clk) begin
    if (clk_en) begin
        // X Gradient
        stage2_gx <= 
            $signed(stage0_buffer[0][0]) * sobel_x[0] +
            $signed(stage0_buffer[0][1]) * sobel_x[1] +
            $signed(stage0_buffer[0][2]) * sobel_x[2] +
            $signed(stage0_buffer[1][0]) * sobel_x[3] +
            $signed(stage0_buffer[1][1]) * sobel_x[4] +
            $signed(stage0_buffer[1][2]) * sobel_x[5] +
            $signed(stage0_buffer[2][0]) * sobel_x[6] +
            $signed(stage0_buffer[2][1]) * sobel_x[7] +
            $signed(stage0_buffer[2][2]) * sobel_x[8];

        // Y Gradient
        stage2_gy <= 
            $signed(stage0_buffer[0][0]) * sobel_y[0] +
            $signed(stage0_buffer[0][1]) * sobel_y[1] +
            $signed(stage0_buffer[0][2]) * sobel_y[2] +
            $signed(stage0_buffer[1][0]) * sobel_y[3] +
            $signed(stage0_buffer[1][1]) * sobel_y[4] +
            $signed(stage0_buffer[1][2]) * sobel_y[5] +
            $signed(stage0_buffer[2][0]) * sobel_y[6] +
            $signed(stage0_buffer[2][1]) * sobel_y[7] +
            $signed(stage0_buffer[2][2]) * sobel_y[8];
    end
end

//--------------------------------------------------------------
// Stage 3: Gradient Magnitude & Direction (Fixed abs)
//--------------------------------------------------------------
always @(posedge clk) begin
    if (clk_en) begin
        // Manual absolute value calculation
        stage3_mag <= ((stage2_gx[10] ? -stage2_gx : stage2_gx) + 
                      (stage2_gy[10] ? -stage2_gy : stage2_gy)) >> 1;

        // Direction calculation
        stage3_dir <= (stage2_gy == 0) ? 2'b00 : 
                     (stage2_gx == 0) ? 2'b01 : 
                     (stage2_gy/stage2_gx > 2) ? 2'b01 :
                     (stage2_gy/stage2_gx < -2) ? 2'b01 : 2'b10;
    end
end

//--------------------------------------------------------------
// Stage 4: Non-Maximum Suppression
//--------------------------------------------------------------
always @(posedge clk) begin
    if (clk_en) begin
        case(stage3_dir)
            2'b00: stage4_suppressed <= (stage3_mag > stage0_buffer[1][0] && 
                                       stage3_mag > stage0_buffer[1][2]) ? stage3_mag : 0;
            2'b01: stage4_suppressed <= (stage3_mag > stage0_buffer[0][1] && 
                                       stage3_mag > stage0_buffer[2][1]) ? stage3_mag : 0;
            default: stage4_suppressed <= (stage3_mag > stage0_buffer[0][0] && 
                                         stage3_mag > stage0_buffer[2][2]) ? stage3_mag : 0;
        endcase
    end
end

//--------------------------------------------------------------
// Stage 5: Double Thresholding
//--------------------------------------------------------------
always @(posedge clk) begin
    if (clk_en) begin
        stage5_edge <= (stage4_suppressed >= HIGH_THRESH) ? 2'b11 :
                      (stage4_suppressed >= LOW_THRESH) ? 2'b01 : 
                                                        2'b00;
        oPixel <= (stage5_edge[1]) ? 24'hFFFFFF : 
                 (stage5_edge[0]) ? 24'h7F7F7F : 
                                   24'h000000;
    end
end

//--------------------------------------------------------------
// Control Signal Pipeline
//--------------------------------------------------------------
always @(posedge clk) begin
    if (reset) begin
        sop_pipe <= 0;
        eop_pipe <= 0;
        valid_pipe <= 0;
        for (i = 0; i < 5; i = i+1)
            empty_pipe[i] <= 0;
    end
    else if (clk_en) begin
        sop_pipe <= {sop_pipe[3:0], stream_in_startofpacket};
        eop_pipe <= {eop_pipe[3:0], stream_in_endofpacket};
        valid_pipe <= {valid_pipe[3:0], stream_in_valid};
        
        empty_pipe[0] <= stream_in_empty;
        for (i = 1; i < 5; i = i+1)
            empty_pipe[i] <= empty_pipe[i-1];
    end
end

//--------------------------------------------------------------
// Output Assignments
//--------------------------------------------------------------
always @(posedge clk) begin
    if (reset) begin
        stream_out_startofpacket <= 0;
        stream_out_endofpacket <= 0;
        stream_out_valid <= 0;
        stream_out_empty <= 0;
    end
    else if (clk_en) begin
        stream_out_startofpacket <= sop_pipe[4];
        stream_out_endofpacket <= eop_pipe[4];
        stream_out_valid <= valid_pipe[4];
        stream_out_empty <= empty_pipe[4];
    end
end

endmodule