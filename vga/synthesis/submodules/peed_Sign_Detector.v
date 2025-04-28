module Speed_Sign_Detector (
    input                   clk,
    input                   reset,

    // Avalon-ST Sink Interface (Input)
    input       [23:0]      avalon_streaming_sink_data,
    input                   avalon_streaming_sink_valid,
    input                   avalon_streaming_sink_startofpacket,
    input                   avalon_streaming_sink_endofpacket,
    output                  avalon_streaming_sink_ready,

    // Avalon-ST Source Interface (Output)
    output reg  [23:0]      avalon_streaming_source_data,
    output reg              avalon_streaming_source_valid,
    output reg              avalon_streaming_source_startofpacket,
    output reg              avalon_streaming_source_endofpacket,
    input                   avalon_streaming_source_ready
);

// Internal signals
wire [23:0] processed_pixel;
wire processed_valid, processed_sop, processed_eop;
wire transfer_data;

// Input registers
reg [23:0] data_in;
reg valid_in, sop_in, eop_in;

// Data transfer control logic
assign transfer_data = ~avalon_streaming_source_valid | 
                       (avalon_streaming_source_ready & avalon_streaming_source_valid);
assign avalon_streaming_sink_ready = ~valid_in | transfer_data;

// Input data pipeline stage
always @(posedge clk or posedge reset) begin
    if (reset) begin
        data_in <= 24'h0;
        valid_in <= 1'b0;
        sop_in <= 1'b0;
        eop_in <= 1'b0;
    end else if (avalon_streaming_sink_ready) begin
        data_in <= avalon_streaming_sink_data;
        valid_in <= avalon_streaming_sink_valid;
        sop_in <= avalon_streaming_sink_startofpacket;
        eop_in <= avalon_streaming_sink_endofpacket;
    end
end

// Output data pipeline stage
always @(posedge clk or posedge reset) begin
    if (reset) begin
        avalon_streaming_source_data <= 24'h0;
        avalon_streaming_source_valid <= 1'b0;
        avalon_streaming_source_startofpacket <= 1'b0;
        avalon_streaming_source_endofpacket <= 1'b0;
    end else if (transfer_data) begin
        avalon_streaming_source_data <= processed_pixel;
        avalon_streaming_source_valid <= processed_valid;
        avalon_streaming_source_startofpacket <= processed_sop;
        avalon_streaming_source_endofpacket <= processed_eop;
    end
end

// Instantiate Processing Module (Core Algorithm)
Speed_Sign_DetectionCore detection_core (
    .clk(clk),
    .reset(reset),
    
    .pixel_in(data_in),
    .valid_in(valid_in),
    .sop_in(sop_in),
    .eop_in(eop_in),

    .pixel_out(processed_pixel),
    .valid_out(processed_valid),
    .sop_out(processed_sop),
    .eop_out(processed_eop)
);

endmodule
