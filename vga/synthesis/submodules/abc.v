//--------------------------------------------------------------
// Canny Edge Detector with Avalon Interface
//--------------------------------------------------------------
module Canny_Edge_Detector (
    // Inputs
    input clk,
    input reset,
    input [23:0] avalon_streaming_sink_data,
    input avalon_streaming_sink_startofpacket,
    input avalon_streaming_sink_endofpacket,
    input [1:0] avalon_streaming_sink_empty, // 2-bit empty
    input avalon_streaming_sink_valid,
    input avalon_streaming_source_ready,

    // Outputs
    output avalon_streaming_sink_ready,
    output reg [23:0] avalon_streaming_source_data,
    output reg avalon_streaming_source_startofpacket,
    output reg avalon_streaming_source_endofpacket,
    output reg [1:0] avalon_streaming_source_empty, // 2-bit empty
    output reg avalon_streaming_source_valid
);

    // Internal wires and registers
    wire transfer_data;
    wire [7:0] edge_out;
    reg [23:0] pixel_reg;
    reg sop_reg, eop_reg, valid_reg;
    reg [1:0] empty_reg;

    // Control logic
    assign avalon_streaming_sink_ready = ~valid_reg | transfer_data;
    assign transfer_data = avalon_streaming_source_ready | ~avalon_streaming_source_valid;

    // Pipeline registers
    always @(posedge clk) begin
        if (reset) begin
            pixel_reg <= 24'b0;
            sop_reg <= 1'b0;
            eop_reg <= 1'b0;
            empty_reg <= 2'b0;
            valid_reg <= 1'b0;
            avalon_streaming_source_data <= 24'b0;
            avalon_streaming_source_startofpacket <= 1'b0;
            avalon_streaming_source_endofpacket <= 1'b0;
            avalon_streaming_source_empty <= 2'b0;
            avalon_streaming_source_valid <= 1'b0;
        end
        else begin
            if (avalon_streaming_sink_valid && avalon_streaming_sink_ready) begin
                pixel_reg <= avalon_streaming_sink_data;
                sop_reg <= avalon_streaming_sink_startofpacket;
                eop_reg <= avalon_streaming_sink_endofpacket;
                empty_reg <= avalon_streaming_sink_empty;
                valid_reg <= 1'b1;
            end

            if (transfer_data) begin
                avalon_streaming_source_data <= {edge_out, edge_out, edge_out}; // Grayscale output
                avalon_streaming_source_startofpacket <= sop_reg;
                avalon_streaming_source_endofpacket <= eop_reg;
                avalon_streaming_source_empty <= empty_reg;
                avalon_streaming_source_valid <= valid_reg;
            end
        end
    end

    // Instantiate the core module
    Canny_Core processing_core (
        .clk(clk),
        .reset(reset),
        .rgb_in(pixel_reg),
        .data_en(valid_reg),
        .edge_out(edge_out)
    );

endmodule

//--------------------------------------------------------------
// Parameterized Line Buffer
//--------------------------------------------------------------
module line #(
    parameter WD = 8,
    parameter SIZE = 720
)(
    input clken,
    input clock,
    input [WD-1:0] shiftin,
    output [WD-1:0] shiftout
);
    reg [WD-1:0] buffer [SIZE-1:0];
    integer i;

    always @(posedge clock) begin
        if (clken) begin
            for (i = SIZE-1; i > 0; i = i-1)
                buffer[i] <= buffer[i-1];
            buffer[0] <= shiftin;
        end
    end
    assign shiftout = buffer[SIZE-1];
endmodule

//--------------------------------------------------------------
// RGB to Grayscale Conversion
//--------------------------------------------------------------
module rgb2grey (
    input clk,
    input rst,
    input data_en,
    input [23:0] in_data,
    output reg [7:0] out_data
);
    wire [7:0] R = in_data[23:16];
    wire [7:0] G = in_data[15:8];
    wire [7:0] B = in_data[7:0];
    reg [15:0] R_r, G_r, B_r;
    reg [31:0] grey;

    always @(posedge clk) begin
        if (rst) begin
            R_r <= 16'b0;
            G_r <= 16'b0;
            B_r <= 16'b0;
            grey <= 32'b0;
            out_data <= 8'b0;
        end
        else if (data_en) begin
            R_r <= {2'b0, R, 6'b0} + {5'b0, R, 3'b0} + {7'b0, R, 1'b0}; // R * 0.299
            G_r <= {1'b0, G, 7'b0} + {4'b0, G, 4'b0} + {6'b0, G, 2'b0} + {7'b0, G, 1'b0}; // G * 0.587
            B_r <= {3'b0, B, 5'b0} + {8'b0, B} - {6'b0, B, 2'b0}; // B * 0.114
            grey <= R_r + G_r + B_r;
            out_data <= grey[15:8]; // Extract upper 8 bits
        end
    end
endmodule

//--------------------------------------------------------------
// Gaussian Filter (5x5 Kernel)
//--------------------------------------------------------------
module gaussian_filter (
    input clk,
    input reset,
    input [7:0] data_in,
    input data_en,
    output reg [8:0] data_out
);
    parameter WIDTH = 720;
    wire [7:0] line2, line3, line4, line5;
    reg [7:0] oline_1[4:0], oline_2[4:0], oline_3[4:0], oline_4[4:0], oline_5[4:0];
    reg [15:0] level_1[6:0], level_2[4:0], level_3;
    integer i;

    always @(posedge clk) begin
        if (reset) begin
            for (i = 0; i < 5; i = i+1) begin
                oline_1[i] <= 8'b0;
                oline_2[i] <= 8'b0;
                oline_3[i] <= 8'b0;
                oline_4[i] <= 8'b0;
                oline_5[i] <= 8'b0;
            end
            for (i = 0; i < 7; i = i+1) level_1[i] <= 16'b0;
            for (i = 0; i < 5; i = i+1) level_2[i] <= 16'b0;
            level_3 <= 16'b0;
            data_out <= 9'b0;
        end
        else if (data_en) begin
            for (i = 4; i > 0; i = i-1) begin
                oline_1[i] <= oline_1[i-1];
                oline_2[i] <= oline_2[i-1];
                oline_3[i] <= oline_3[i-1];
                oline_4[i] <= oline_4[i-1];
                oline_5[i] <= oline_5[i-1];
            end
            oline_1[0] <= data_in;
            oline_2[0] <= line2;
            oline_3[0] <= line3;
            oline_4[0] <= line4;
            oline_5[0] <= line5;

            level_1[0] = (oline_1[0] << 1) + (oline_1[4] << 1) + (oline_5[0] << 1) + (oline_5[4] << 1); // Corners * 2
            level_1[1] = (oline_1[1] << 2) + (oline_1[3] << 2) + (oline_2[0] << 2) + (oline_2[4] << 2); // Outer edges * 4
            level_1[2] = (oline_4[0] << 2) + (oline_4[4] << 2) + (oline_5[1] << 2) + (oline_5[3] << 2); // Outer edges * 4
            level_1[3] = oline_1[2] + oline_5[2] + oline_3[0] + oline_3[4]; // Mid edges * 1
            level_1[4] = oline_2[1] + oline_2[3] + oline_4[1] + oline_4[3]; // Inner edges * 1
            level_1[5] = oline_2[2] + oline_4[2] + oline_3[1] + oline_3[3]; // Inner mid * 1
            level_1[6] = (oline_3[2] << 4) - oline_3[2]; // Center * 15

            level_2[0] = level_1[0] + level_1[6];
            level_2[1] = level_1[1] + level_1[2];
            level_2[2] = (level_1[3] << 2) + level_1[3]; // *5
            level_2[3] = (level_1[4] << 3) + level_1[4]; // *9
            level_2[4] = (level_1[5] << 3) + (level_1[5] << 2); // *12

            level_3 = level_2[0] + level_2[1] + level_2[2] + level_2[3] + level_2[4];
            data_out <= level_3 / 159; // Normalize
        end
    end

    line #(.WD(8), .SIZE(WIDTH)) line_buffer1 (.clock(clk), .clken(data_en), .shiftin(data_in), .shiftout(line2));
    line #(.WD(8), .SIZE(WIDTH)) line_buffer2 (.clock(clk), .clken(data_en), .shiftin(line2), .shiftout(line3));
    line #(.WD(8), .SIZE(WIDTH)) line_buffer3 (.clock(clk), .clken(data_en), .shiftin(line3), .shiftout(line4));
    line #(.WD(8), .SIZE(WIDTH)) line_buffer4 (.clock(clk), .clken(data_en), .shiftin(line4), .shiftout(line5));
endmodule

//--------------------------------------------------------------
// Sobel Filter
//--------------------------------------------------------------
module sobel (
    input clk,
    input rst,
    input [8:0] in_data,
    input data_en,
    output reg [11:0] out_data
);
    parameter WIDTH = 720;
    wire [8:0] line1, line2;
    reg [8:0] oline0[2:0], oline1[2:0], oline2[2:0];
    reg [11:0] gx, gy;
    integer i;

    always @(posedge clk) begin
        if (rst) begin
            for (i = 0; i < 3; i = i+1) begin
                oline0[i] <= 9'b0;
                oline1[i] <= 9'b0;
                oline2[i] <= 9'b0;
            end
            gx <= 12'b0;
            gy <= 12'b0;
            out_data <= 12'b0;
        end
        else if (data_en) begin
            for (i = 2; i > 0; i = i-1) begin
                oline0[i] <= oline0[i-1];
                oline1[i] <= oline1[i-1];
                oline2[i] <= oline2[i-1];
            end
            oline0[0] <= in_data;
            oline1[0] <= line1;
            oline2[0] <= line2;

            gx <= (oline0[0] + (oline1[0] << 1) + oline2[0]) - 
                  (oline0[2] + (oline1[2] << 1) + oline2[2]); // Horizontal gradient
            gy <= (oline0[0] + (oline0[1] << 1) + oline0[2]) - 
                  (oline2[0] + (oline2[1] << 1) + oline2[2]); // Vertical gradient

            out_data[11:8] <= (gy > gx) ? 4'b0010 : 4'b0001; // Direction
            out_data[7:0] <= (|gx[11:10] || |gy[11:10]) ? 8'hFF : 
                             ({gx[9:2]} + {gy[9:2]}) >> 1; // Magnitude
        end
    end

    line #(.WD(9), .SIZE(WIDTH)) u0 (.clken(data_en), .clock(clk), .shiftin(in_data), .shiftout(line1));
    line #(.WD(9), .SIZE(WIDTH)) u1 (.clken(data_en), .clock(clk), .shiftin(line1), .shiftout(line2));
endmodule

//--------------------------------------------------------------
// Non-Maximum Suppression
//--------------------------------------------------------------
module nms (
    input clk,
    input rst,
    input [11:0] data_in,
    input data_en,
    output reg [11:0] data_out
);
    parameter WIDTH = 720;
    wire [11:0] line1, line2;
    reg [11:0] oline0[2:0], oline1[2:0], oline2[2:0];
    integer i;

    always @(posedge clk) begin
        if (rst) begin
            for (i = 0; i < 3; i = i+1) begin
                oline0[i] <= 12'b0;
                oline1[i] <= 12'b0;
                oline2[i] <= 12'b0;
            end
            data_out <= 12'b0;
        end
        else if (data_en) begin
            for (i = 2; i > 0; i = i-1) begin
                oline0[i] <= oline0[i-1];
                oline1[i] <= oline1[i-1];
                oline2[i] <= oline2[i-1];
            end
            oline0[0] <= data_in;
            oline1[0] <= line1;
            oline2[0] <= line2;

            case (oline1[1][11:8])
                4'b0001: // Horizontal
                    data_out <= (oline1[1][7:0] > oline1[0][7:0] && 
                                 oline1[1][7:0] > oline1[2][7:0]) ? oline1[1] : 12'b0;
                4'b0010: // Vertical
                    data_out <= (oline1[1][7:0] > oline0[0][7:0] && 
                                 oline1[1][7:0] > oline2[2][7:0]) ? oline1[1] : 12'b0;
                default: 
                    data_out <= 12'b0;
            endcase
        end
    end

    line #(.WD(12), .SIZE(WIDTH)) buffer_1 (.clock(clk), .clken(data_en), .shiftin(data_in), .shiftout(line1));
    line #(.WD(12), .SIZE(WIDTH)) buffer_2 (.clock(clk), .clken(data_en), .shiftin(line1), .shiftout(line2));
endmodule

//--------------------------------------------------------------
// Double Thresholding with Hysteresis
//--------------------------------------------------------------
module double_threshold_filtering #(
    parameter WIDTH = 720,
    parameter HIGH_THRESHOLD = 40, // Configurable high threshold
    parameter LOW_THRESHOLD = 20   // Configurable low threshold
)(
    input clk,
    input rst,
    input [11:0] in_data,
    input data_en,
    output reg [7:0] out_data
);
    wire [11:0] line1, line2;
    reg [11:0] oline0[2:0], oline1[2:0], oline2[2:0];
    integer i;

    always @(posedge clk) begin
        if (rst) begin
            for (i = 0; i < 3; i = i+1) begin
                oline0[i] <= 12'b0;
                oline1[i] <= 12'b0;
                oline2[i] <= 12'b0;
            end
            out_data <= 8'b0;
        end
        else if (data_en) begin
            for (i = 2; i > 0; i = i-1) begin
                oline0[i] <= oline0[i-1];
                oline1[i] <= oline1[i-1];
                oline2[i] <= oline2[i-1];
            end
            oline0[0] <= in_data;
            oline1[0] <= line1;
            oline2[0] <= line2;

            if (oline1[1][7:0] < LOW_THRESHOLD)
                out_data <= 8'h00;
            else if (oline1[1][7:0] > HIGH_THRESHOLD)
                out_data <= 8'hFF;
            else
                out_data <= (|oline0[0][7:0] || |oline0[2][7:0] || 
                             |oline2[0][7:0] || |oline2[2][7:0]) ? 8'hFF : 8'h00;
        end
    end

    line #(.WD(12), .SIZE(WIDTH)) u0 (.clken(data_en), .clock(clk), .shiftin(in_data), .shiftout(line1));
    line #(.WD(12), .SIZE(WIDTH)) u1 (.clken(data_en), .clock(clk), .shiftin(line1), .shiftout(line2));
endmodule

//--------------------------------------------------------------
// Canny Core Module
//--------------------------------------------------------------
module Canny_Core (
    input clk,
    input reset,
    input [23:0] rgb_in,
    input data_en,
    output [7:0] edge_out
);
    wire [7:0] gray_out;
    wire [8:0] gaussian_out;
    wire [11:0] sobel_out;
    wire [11:0] nms_out;

    rgb2grey rgb2gray (
        .clk(clk),
        .rst(reset),
        .data_en(data_en),
        .in_data(rgb_in),
        .out_data(gray_out)
    );

    gaussian_filter gauss_filter (
        .clk(clk),
        .reset(reset),
        .data_in(gray_out),
        .data_en(data_en),
        .data_out(gaussian_out)
    );

    sobel sobel_filter (
        .clk(clk),
        .rst(reset),
        .in_data(gaussian_out),
        .data_en(data_en),
        .out_data(sobel_out)
    );

    nms non_max_suppress (
        .clk(clk),
        .rst(reset),
        .data_in(sobel_out),
        .data_en(data_en),
        .data_out(nms_out)
    );

    double_threshold_filtering #(
        .HIGH_THRESHOLD(40),
        .LOW_THRESHOLD(20)
    ) thresholding (
        .clk(clk),
        .rst(reset),
        .in_data(nms_out),
        .data_en(data_en),
        .out_data(edge_out)
    );
endmodule