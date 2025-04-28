module GaussianSobelModule (
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

    // Gaussian Kernel (3x3)
    wire [3:0] gauss[0:2][0:2];
    assign gauss[0][0] = 1; assign gauss[0][1] = 2; assign gauss[0][2] = 1;
    assign gauss[1][0] = 2; assign gauss[1][1] = 4; assign gauss[1][2] = 2;
    assign gauss[2][0] = 1; assign gauss[2][1] = 2; assign gauss[2][2] = 1;

    // Line buffers for 3x3 window
    reg [7:0] line_buffer[0:2][0:2];
    integer i, j;
    reg [11:0] gauss_sum;

    // Sobel variables
    reg signed [10:0] Gx, Gy;
    reg [10:0] absGx, absGy, gradient_mag;
    reg [1:0] gradient_dir; // 00: 0°, 01: 45°, 10: 90°, 11: 135°
    parameter HIGH_THRESHOLD = 150;
    parameter LOW_THRESHOLD = 80;

    // Buffer for NMS neighborhood comparison (3×3 window of gradient magnitudes)
    reg [10:0] grad_buffer[0:2][0:2];

    // NMS and edge variables
    reg nms_result;

    // Double Thresholding variables
    reg is_strong_edge, is_weak_edge;
    reg [7:0] edge_output;

    // Hysteresis buffers
    parameter IMAGE_WIDTH = 640; // Adjust based on your image width
    reg [15:0] column_counter;
    reg [7:0] prev_row_edge[0:IMAGE_WIDTH-1];
    reg [7:0] current_row_edge[0:IMAGE_WIDTH-1];

    // Pipeline stages
    reg [2:0] stage;

    // Control signals pipeline
    reg [3:0] sop_pipeline, eop_pipeline;
    reg [1:0] empty_pipeline[0:3];
    reg [3:0] valid_pipeline;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            // Reset all registers
            for (i = 0; i < 3; i = i + 1)
                for (j = 0; j < 3; j = j + 1) begin
                    line_buffer[i][j] <= 8'd0;
                    grad_buffer[i][j] <= 11'd0;
                end

            oY <= 8'd16;
            oCr <= 8'd128;
            oCb <= 8'd128;
            stream_out_startofpacket <= 0;
            stream_out_endofpacket <= 0;
            stream_out_empty <= 0;
            stream_out_valid <= 0;

            gradient_dir <= 2'b00;
            nms_result <= 1'b0;
            is_strong_edge <= 1'b0;
            is_weak_edge <= 1'b0;
            edge_output <= 8'd0;

            column_counter <= 16'd0;
            for (i = 0; i < IMAGE_WIDTH; i = i + 1) begin
                prev_row_edge[i] <= 8'd0;
                current_row_edge[i] <= 8'd0;
            end

            // Reset pipeline registers
            for (i = 0; i < 4; i = i + 1) begin
                sop_pipeline[i] <= 1'b0;
                eop_pipeline[i] <= 1'b0;
                valid_pipeline[i] <= 1'b0;
                empty_pipeline[i] <= 2'b00;
            end
            stage <= 3'b000;

        end else if (clk_en) begin
            // Update control signals pipeline
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

            // Update column counter
            if (stream_in_startofpacket) begin
                column_counter <= 16'd0;
            end else begin
                column_counter <= (column_counter + 1) % IMAGE_WIDTH;
            end

            // Stage 0: Shift line buffer and apply Gaussian blur
            for (i = 0; i < 3; i = i + 1) begin
                for (j = 0; j < 2; j = j + 1) begin
                    line_buffer[i][j] <= line_buffer[i][j+1];
                end
            end
            line_buffer[0][2] <= line_buffer[1][0];
            line_buffer[1][2] <= line_buffer[2][0];
            line_buffer[2][2] <= iY;

            // Gaussian convolution
            gauss_sum <= (gauss[0][0] * line_buffer[0][0]) + (gauss[0][1] * line_buffer[0][1]) + (gauss[0][2] * line_buffer[0][2]) +
                         (gauss[1][0] * line_buffer[1][0]) + (gauss[1][1] * line_buffer[1][1]) + (gauss[1][2] * line_buffer[1][2]) +
                         (gauss[2][0] * line_buffer[2][0]) + (gauss[2][1] * line_buffer[2][1]) + (gauss[2][2] * line_buffer[2][2]);

            // Stage 1: Sobel Gradient Calculation and Direction
            Gx <= ((line_buffer[0][2] - line_buffer[0][0]) + ((line_buffer[1][2] - line_buffer[1][0]) << 1) + (line_buffer[2][2] - line_buffer[2][0]));
            Gy <= ((line_buffer[0][0] - line_buffer[2][0]) + ((line_buffer[0][1] - line_buffer[2][1]) << 1) + (line_buffer[0][2] - line_buffer[2][2]));

            absGx <= (Gx < 0) ? -Gx : Gx;
            absGy <= (Gy < 0) ? -Gy : Gy;
            gradient_mag <= absGx + absGy;

            // Determine gradient direction
            if (absGx <= absGy >> 2) begin
                gradient_dir <= 2'b10; // Vertical (90°)
            end else if (absGy <= absGx >> 2) begin
                gradient_dir <= 2'b00; // Horizontal (0°)
            end else if ((Gx > 0 && Gy > 0) || (Gx < 0 && Gy < 0)) begin
                gradient_dir <= 2'b01; // 45° diagonal
            end else begin
                gradient_dir <= 2'b11; // 135° diagonal
            end

            // Shift the gradient buffer for NMS
            for (i = 0; i < 3; i = i + 1) begin
                for (j = 0; j < 2; j = j + 1) begin
                    grad_buffer[i][j] <= grad_buffer[i][j+1];
                end
            end
            for (i = 0; i < 2; i = i + 1) begin
                grad_buffer[i][2] <= grad_buffer[i+1][0];
            end
            grad_buffer[2][2] <= gradient_mag;

            // Stage 2: Non-Maximum Suppression
            case (gradient_dir)
                2'b00: // Horizontal (0°)
                    nms_result <= (grad_buffer[1][1] > grad_buffer[1][0]) && (grad_buffer[1][1] > grad_buffer[1][2]);
                2'b01: // Diagonal (45°)
                    nms_result <= (grad_buffer[1][1] > grad_buffer[0][2]) && (grad_buffer[1][1] > grad_buffer[2][0]);
                2'b10: // Vertical (90°)
                    nms_result <= (grad_buffer[1][1] > grad_buffer[0][1]) && (grad_buffer[1][1] > grad_buffer[2][1]);
                2'b11: // Diagonal (135°)
                    nms_result <= (grad_buffer[1][1] > grad_buffer[0][0]) && (grad_buffer[1][1] > grad_buffer[2][2]);
            endcase

            // Double Thresholding after NMS
            is_strong_edge <= nms_result && (grad_buffer[1][1] >= HIGH_THRESHOLD);
            is_weak_edge <= nms_result && (grad_buffer[1][1] >= LOW_THRESHOLD) && (grad_buffer[1][1] < HIGH_THRESHOLD);

            // Stage 3: Hysteresis thresholding with connectivity check
            if (is_strong_edge) begin
                edge_output <= 8'hFF; // Strong edge
            end else if (is_weak_edge) begin
                // Check past neighbors for connectivity
                if ((column_counter > 0 && current_row_edge[column_counter - 1] == 8'hFF) || // Left
                    (column_counter > 0 && prev_row_edge[column_counter - 1] == 8'hFF) ||    // Top-left
                    (prev_row_edge[column_counter] == 8'hFF) ||                             // Top
                    (column_counter < IMAGE_WIDTH - 1 && prev_row_edge[column_counter + 1] == 8'hFF)) begin // Top-right
                    edge_output <= 8'hFF; // Weak edge connected to an edge
                end else begin
                    edge_output <= 8'h00; // Isolated weak edge
                end
            end else begin
                edge_output <= 8'h00; // Non-edge
            end

            // Store edge decision
            current_row_edge[column_counter] <= edge_output;

            // Update previous row buffer at end of row
            if (column_counter == IMAGE_WIDTH - 1) begin
                for (i = 0; i < IMAGE_WIDTH; i = i + 1) begin
                    prev_row_edge[i] <= current_row_edge[i];
                end
            end

            // Final output
            oY <= edge_output;
            oCr <= iCr;
            oCb <= iCb;

            // Output streaming signals
            stream_out_startofpacket <= sop_pipeline[3];
            stream_out_endofpacket <= eop_pipeline[3];
            stream_out_empty <= empty_pipeline[3];
            stream_out_valid <= valid_pipeline[3];
        end
    end

endmodule