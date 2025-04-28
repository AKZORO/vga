module cannyModule (
    input clk,
    input clk_en,
    input reset,
    input [7:0] iY,
    input [7:0] iCr,
    input [7:0] iCb,
    input stream_in_startofpacket,
    input stream_in_endofpacket,
    input [1:0] stream_in_empty,
    input stream_in_valid,
    output reg [7:0] oY,
    output reg [7:0] oCr,
    output reg [7:0] oCb,
    output reg stream_out_startofpacket,
    output reg stream_out_endofpacket,
    output reg [1:0] stream_out_empty,
    output reg stream_out_valid
);

    // Parameters
    parameter IMAGE_WIDTH = 640;
    parameter HIGH_THRESHOLD = 120;  // Adjusted from 150 to include more strong edges
    parameter LOW_THRESHOLD = 100;   // Adjusted from 80 to reduce noise

    // Gaussian Kernel (3x3, sum = 16 for division by right shift)
    wire [3:0] gauss[0:2][0:2];
    assign gauss[0][0] = 1; assign gauss[0][1] = 2; assign gauss[0][2] = 1;
    assign gauss[1][0] = 2; assign gauss[1][1] = 4; assign gauss[1][2] = 2;
    assign gauss[2][0] = 1; assign gauss[2][1] = 2; assign gauss[2][2] = 1;

    // Line buffers for 3x3 window (original and smoothed)
    reg [7:0] line_buffer[0:2][0:2];  // Original pixels
    reg [7:0] smoothed_buffer[0:2][0:2];  // Smoothed pixels
    integer i, j;

    // Pipeline registers
    reg [11:0] gauss_sum_stage0;
    reg signed [10:0] Gx_stage1, Gy_stage1;
    reg [10:0] gradient_mag_stage2;
    reg [1:0] gradient_dir_stage2;
    reg [10:0] grad_buffer[0:2][0:2];  // For NMS
    reg nms_result_stage2;
    reg is_strong_edge_stage3, is_weak_edge_stage3;
    reg [7:0] edge_output_stage3;

    // Hysteresis buffers
    reg [15:0] column_counter;
    reg [7:0] prev_row_edge[0:IMAGE_WIDTH-1];
    reg [7:0] current_row_edge[0:IMAGE_WIDTH-1];

    // Control signals pipeline (4 stages: 0,1,2,3)
    reg [3:0] sop_pipeline, eop_pipeline;
    reg [1:0] empty_pipeline[0:3];
    reg [3:0] valid_pipeline;
    reg [7:0] iCr_pipeline[0:2], iCb_pipeline[0:2];  // Pipeline Cr, Cb to match latency

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            // Reset buffers
            for (i = 0; i < 3; i = i + 1)
                for (j = 0; j < 3; j = j + 1) begin
                    line_buffer[i][j] <= 8'd0;
                    smoothed_buffer[i][j] <= 8'd0;
                    grad_buffer[i][j] <= 11'd0;
                end

            // Reset outputs
            oY <= 8'd16;
            oCr <= 8'd128;
            oCb <= 8'd128;
            stream_out_startofpacket <= 0;
            stream_out_endofpacket <= 0;
            stream_out_empty <= 0;
            stream_out_valid <= 0;

            // Reset pipeline registers
            gauss_sum_stage0 <= 12'd0;
            Gx_stage1 <= 11'd0;
            Gy_stage1 <= 11'd0;
            gradient_mag_stage2 <= 11'd0;
            gradient_dir_stage2 <= 2'b00;
            nms_result_stage2 <= 1'b0;
            is_strong_edge_stage3 <= 1'b0;
            is_weak_edge_stage3 <= 1'b0;
            edge_output_stage3 <= 8'd0;

            // Reset control signals
            for (i = 0; i < 4; i = i + 1) begin
                sop_pipeline[i] <= 1'b0;
                eop_pipeline[i] <= 1'b0;
                valid_pipeline[i] <= 1'b0;
                empty_pipeline[i] <= 2'b00;
            end
            for (i = 0; i < 3; i = i + 1) begin
                iCr_pipeline[i] <= 8'd128;
                iCb_pipeline[i] <= 8'd128;
            end

            // Reset counters and edge buffers
            column_counter <= 16'd0;
            for (i = 0; i < IMAGE_WIDTH; i = i + 1) begin
                prev_row_edge[i] <= 8'd0;
                current_row_edge[i] <= 8'd0;
            end
        end else if (clk_en) begin
            // Control signals pipeline
            sop_pipeline[0] <= stream_in_startofpacket;
            eop_pipeline[0] <= stream_in_endofpacket;
            empty_pipeline[0] <= stream_in_empty;
            valid_pipeline[0] <= stream_in_valid;
            for (i = 0; i < 3; i = i + 1) begin
                sop_pipeline[i+1] <= sop_pipeline[i];
                eop_pipeline[i+1] <= eop_pipeline[i];
                empty_pipeline[i+1] <= empty_pipeline[i];
                valid_pipeline[i+1] <= valid_pipeline[i];
            end

            // Pipeline Cr, Cb
            iCr_pipeline[0] <= iCr;
            iCb_pipeline[0] <= iCb;
            for (i = 0; i < 2; i = i + 1) begin
                iCr_pipeline[i+1] <= iCr_pipeline[i];
                iCb_pipeline[i+1] <= iCb_pipeline[i];
            end

            // Update column counter
            if (stream_in_startofpacket) begin
                column_counter <= 16'd0;
            end else begin
                column_counter <= (column_counter + 1) % IMAGE_WIDTH;
            end

            // Stage 0: Gaussian Smoothing
            // Shift line_buffer (original pixels)
            for (i = 0; i < 3; i = i + 1) begin
                for (j = 0; j < 2; j = j + 1) begin
                    line_buffer[i][j] <= line_buffer[i][j+1];
                end
            end
            line_buffer[0][2] <= line_buffer[1][0];
            line_buffer[1][2] <= line_buffer[2][0];
            line_buffer[2][2] <= iY;

            // Compute Gaussian sum
            gauss_sum_stage0 <= (gauss[0][0] * line_buffer[0][0]) + (gauss[0][1] * line_buffer[0][1]) + (gauss[0][2] * line_buffer[0][2]) +
                               (gauss[1][0] * line_buffer[1][0]) + (gauss[1][1] * line_buffer[1][1]) + (gauss[1][2] * line_buffer[1][2]) +
                               (gauss[2][0] * line_buffer[2][0]) + (gauss[2][1] * line_buffer[2][1]) + (gauss[2][2] * line_buffer[2][2]);

            // Update smoothed_buffer (shift and store new smoothed value)
            for (i = 0; i < 3; i = i + 1) begin
                for (j = 0; j < 2; j = j + 1) begin
                    smoothed_buffer[i][j] <= smoothed_buffer[i][j+1];
                end
            end
            smoothed_buffer[0][2] <= smoothed_buffer[1][0];
            smoothed_buffer[1][2] <= smoothed_buffer[2][0];
            smoothed_buffer[2][2] <= gauss_sum_stage0[11:4];  // Divide by 16 (sum of weights)

            // Stage 1: Sobel Gradient Calculation (on smoothed values)
            Gx_stage1 <= ((smoothed_buffer[0][2] - smoothed_buffer[0][0]) + 
                          ((smoothed_buffer[1][2] - smoothed_buffer[1][0]) << 1) + 
                          (smoothed_buffer[2][2] - smoothed_buffer[2][0]));
            Gy_stage1 <= ((smoothed_buffer[0][0] - smoothed_buffer[2][0]) + 
                          ((smoothed_buffer[0][1] - smoothed_buffer[2][1]) << 1) + 
                          (smoothed_buffer[0][2] - smoothed_buffer[2][2]));

            // Stage 2: Gradient Magnitude, Direction, and NMS
            gradient_mag_stage2 <= (Gx_stage1 < 0 ? -Gx_stage1 : Gx_stage1) + 
                                   (Gy_stage1 < 0 ? -Gy_stage1 : Gy_stage1);
            if ((Gx_stage1 < 0 ? -Gx_stage1 : Gx_stage1) <= (Gy_stage1 < 0 ? -Gy_stage1 : Gy_stage1) >> 2) begin
                gradient_dir_stage2 <= 2'b10; // 90°
            end else if ((Gy_stage1 < 0 ? -Gy_stage1 : Gy_stage1) <= (Gx_stage1 < 0 ? -Gx_stage1 : Gx_stage1) >> 2) begin
                gradient_dir_stage2 <= 2'b00; // 0°
            end else if ((Gx_stage1 > 0 && Gy_stage1 > 0) || (Gx_stage1 < 0 && Gy_stage1 < 0)) begin
                gradient_dir_stage2 <= 2'b01; // 45°
            end else begin
                gradient_dir_stage2 <= 2'b11; // 135°
            end

            // Update grad_buffer
            for (i = 0; i < 3; i = i + 1) begin
                for (j = 0; j < 2; j = j + 1) begin
                    grad_buffer[i][j] <= grad_buffer[i][j+1];
                end
            end
            for (i = 0; i < 2; i = i + 1) begin
                grad_buffer[i][2] <= grad_buffer[i+1][0];
            end
            grad_buffer[2][2] <= gradient_mag_stage2;

            // NMS
            case (gradient_dir_stage2)
                2'b00: nms_result_stage2 <= (grad_buffer[1][1] > grad_buffer[1][0]) && (grad_buffer[1][1] > grad_buffer[1][2]);
                2'b01: nms_result_stage2 <= (grad_buffer[1][1] > grad_buffer[0][2]) && (grad_buffer[1][1] > grad_buffer[2][0]);
                2'b10: nms_result_stage2 <= (grad_buffer[1][1] > grad_buffer[0][1]) && (grad_buffer[1][1] > grad_buffer[2][1]);
                2'b11: nms_result_stage2 <= (grad_buffer[1][1] > grad_buffer[0][0]) && (grad_buffer[1][1] > grad_buffer[2][2]);
            endcase

            // Stage 3: Double Thresholding and Hysteresis
            is_strong_edge_stage3 <= nms_result_stage2 && (grad_buffer[1][1] >= HIGH_THRESHOLD);
            is_weak_edge_stage3 <= nms_result_stage2 && (grad_buffer[1][1] >= LOW_THRESHOLD) && 
                                  (grad_buffer[1][1] < HIGH_THRESHOLD);

            if (is_strong_edge_stage3) begin
                edge_output_stage3 <= 8'hFF;
            end else if (is_weak_edge_stage3) begin
                if ((column_counter > 0 && current_row_edge[column_counter - 1] == 8'hFF) || 
                    (column_counter > 0 && prev_row_edge[column_counter - 1] == 8'hFF) || 
                    (prev_row_edge[column_counter] == 8'hFF) || 
                    (column_counter < IMAGE_WIDTH - 1 && prev_row_edge[column_counter + 1] == 8'hFF)) begin
                    edge_output_stage3 <= 8'hFF;
                end else begin
                    edge_output_stage3 <= 8'h00;
                end
            end else begin
                edge_output_stage3 <= 8'h00;
            end

            // Update edge buffers
            current_row_edge[column_counter] <= edge_output_stage3;
            if (column_counter == IMAGE_WIDTH - 1) begin
                for (i = 0; i < IMAGE_WIDTH; i = i + 1) begin
                    prev_row_edge[i] <= current_row_edge[i];
                end
            end

            // Output assignment
            oY <= edge_output_stage3;
            oCr <= iCr_pipeline[2];
            oCb <= iCb_pipeline[2];
            stream_out_startofpacket <= sop_pipeline[3];
            stream_out_endofpacket <= eop_pipeline[3];
            stream_out_empty <= empty_pipeline[3];
            stream_out_valid <= valid_pipeline[3];
        end
    end

endmodule