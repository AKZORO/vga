module GaussianSobel_AvalonInterface (
    input clk,
    input reset,
    // Avalon Streaming Sink (Input Interface)
    input [23:0] avalon_streaming_sink_data,
    input avalon_streaming_sink_startofpacket,
    input avalon_streaming_sink_endofpacket,
    input [1:0] avalon_streaming_sink_empty,
    input avalon_streaming_sink_valid,
    // Avalon Streaming Source (Output Interface)
    input avalon_streaming_source_ready,
    output reg avalon_streaming_source_valid,
    output reg [23:0] avalon_streaming_source_data,
    output reg avalon_streaming_source_startofpacket,
    output reg avalon_streaming_source_endofpacket,
    output reg [1:0] avalon_streaming_source_empty,
    output wire avalon_streaming_sink_ready
);

    // Internal Registers for Input Data buffering
    reg [23:0] data;
    reg startofpacket, endofpacket;
    reg [1:0] empty;
    reg valid;

    wire transfer_data;

    wire [23:0] processed_data;
    wire processed_startofpacket, processed_endofpacket;
    wire [1:0] processed_empty;
    wire processed_valid;

    // Control Logic for Data Transfer
    assign avalon_streaming_sink_ready = avalon_streaming_sink_valid & (~valid | transfer_data);
    assign transfer_data = ~avalon_streaming_source_valid | 
                          (avalon_streaming_source_ready & avalon_streaming_source_valid);

    // Input Data buffering
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            data <= 24'd0;
            startofpacket <= 1'b0;
            endofpacket <= 1'b0;
            empty <= 2'd0;
            valid <= 1'b0;
        end else if (avalon_streaming_sink_ready) begin
            data <= avalon_streaming_sink_data;
            startofpacket <= avalon_streaming_sink_startofpacket;
            endofpacket <= avalon_streaming_sink_endofpacket;
            empty <= avalon_streaming_sink_empty;
            valid <= avalon_streaming_sink_valid;
        end else if (transfer_data) begin
            valid <= 1'b0;
        end
    end

    // Output Data buffering
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            avalon_streaming_source_data <= 24'd0;
            avalon_streaming_source_startofpacket <= 1'b0;
            avalon_streaming_source_endofpacket <= 1'b0;
            avalon_streaming_source_empty <= 2'd0;
            avalon_streaming_source_valid <= 1'b0;
        end else if (transfer_data) begin
            avalon_streaming_source_data <= processed_data;
            avalon_streaming_source_startofpacket <= processed_startofpacket;
            avalon_streaming_source_endofpacket <= processed_endofpacket;
            avalon_streaming_source_empty <= processed_empty;
            avalon_streaming_source_valid <= processed_valid;
        end
    end

    // Instantiate Red Color Detection Module
    YCbCr_RedThresholdModule red_inst (
        .clk(clk), .clk_en(transfer_data), .reset(reset),
        .iY(data[7:0]), .iCb(data[15:8]), .iCr(data[23:16]),
        .stream_in_startofpacket(startofpacket), .stream_in_endofpacket(endofpacket),
        .stream_in_empty(empty), .stream_in_valid(valid),
        .oY(processed_data[7:0]), .oCb(processed_data[15:8]), .oCr(processed_data[23:16]),
        .stream_out_startofpacket(processed_startofpacket), .stream_out_endofpacket(processed_endofpacket),
        .stream_out_empty(processed_empty), .stream_out_valid(processed_valid)
    );

endmodule