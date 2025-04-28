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
    reg [1:0] empty_reg; // 2-bit

    // Control logic
    assign avalon_streaming_sink_ready = ~valid_reg | transfer_data;
    assign transfer_data = avalon_streaming_source_ready | ~avalon_streaming_source_valid;

    // Pipeline registers
    always @(posedge clk) begin
        if (reset) begin
            pixel_reg <= 0;
            sop_reg <= 0;
            eop_reg <= 0;
            empty_reg <= 0;
            valid_reg <= 0;
            avalon_streaming_source_data <= 0;
            avalon_streaming_source_startofpacket <= 0;
            avalon_streaming_source_endofpacket <= 0;
            avalon_streaming_source_empty <= 0;
            avalon_streaming_source_valid <= 0;
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
                avalon_streaming_source_data <= {edge_out, edge_out, edge_out}; // Replicate 8-bit edge to RGB channels
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