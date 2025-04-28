module YCbCr_Thresholder (
	// Inputs
	clk,
	reset,

	avalon_streaming_sink_data,
	avalon_streaming_sink_startofpacket,
	avalon_streaming_sink_endofpacket,
	avalon_streaming_sink_empty,
	avalon_streaming_sink_valid,

	avalon_streaming_source_ready,
	
	// Bidirectional

	// Outputs
	avalon_streaming_sink_ready,


	avalon_streaming_source_data,
	avalon_streaming_source_startofpacket,
	avalon_streaming_source_endofpacket,
	avalon_streaming_source_empty,
	avalon_streaming_source_valid
);

/*****************************************************************************
 *                           Parameter Declarations                          *
 *****************************************************************************/

parameter IW 	= 23;
parameter OW 	= 23;

parameter EIW 	= 1;
parameter EOW 	= 1;

/*****************************************************************************
 *                             Port Declarations                             *
 *****************************************************************************/

// Inputs
input						clk;
input						reset;

input			[IW: 0]	avalon_streaming_sink_data;
input						avalon_streaming_sink_startofpacket;
input						avalon_streaming_sink_endofpacket;
input			[EIW:0]	avalon_streaming_sink_empty;
input						avalon_streaming_sink_valid;

input						avalon_streaming_source_ready;

// Bidirectional

// Outputs
output					avalon_streaming_sink_ready;

output reg	[OW: 0]	avalon_streaming_source_data;
output reg				avalon_streaming_source_startofpacket;
output reg				avalon_streaming_source_endofpacket;
output reg	[EOW:0]	avalon_streaming_source_empty;
output reg				avalon_streaming_source_valid;

/*****************************************************************************
 *                           Constant Declarations                           *
 *****************************************************************************/


/*****************************************************************************
 *                 Internal Wires and Registers Declarations                 *
 *****************************************************************************/

// Internal Wires
wire						transfer_data;

wire			[OW: 0]	converted_data;

wire						converted_startofpacket;
wire						converted_endofpacket;
wire			[EOW:0]	converted_empty;
wire						converted_valid;

// Internal Registers
reg			[IW: 0]	data;
reg						startofpacket;
reg						endofpacket;
reg			[EIW:0]	empty;
reg						valid;

// State Machine Registers

// Integers

/*****************************************************************************
 *                         Finite State Machine(s)                           *
 *****************************************************************************/


/*****************************************************************************
 *                             Sequential Logic                              *
 *****************************************************************************/

// Output Registers
always @(posedge clk)
begin
	if (reset)
	begin
		avalon_streaming_source_data				<=  'h0;
		avalon_streaming_source_startofpacket	<= 1'b0;
		avalon_streaming_source_endofpacket		<= 1'b0;
		avalon_streaming_source_empty				<= 2'h0;
		avalon_streaming_source_valid				<= 1'b0;
	end
	else if (transfer_data)
	begin
		avalon_streaming_source_data				<= converted_data;
		avalon_streaming_source_startofpacket	<= converted_startofpacket;
		avalon_streaming_source_endofpacket		<= converted_endofpacket;
		avalon_streaming_source_empty				<= converted_empty;
		avalon_streaming_source_valid				<= converted_valid;
	end
end

// Internal Registers
always @(posedge clk)
begin
	if (reset)
	begin
		data								<=	'h0;
		startofpacket					<= 1'b0;
		endofpacket						<= 1'b0;
		empty								<=  'h0;
		valid								<= 1'b0;
	end
	else if (avalon_streaming_sink_ready)
	begin
		data								<= avalon_streaming_sink_data;
		startofpacket					<= avalon_streaming_sink_startofpacket;
		endofpacket						<= avalon_streaming_sink_endofpacket;
		empty								<= avalon_streaming_sink_empty;
		valid								<= avalon_streaming_sink_valid;
	end
	else if (transfer_data)
	begin
		data								<=  'b0;
		startofpacket					<= 1'b0;
		endofpacket						<= 1'b0;
		empty								<=  'h0;
		valid								<= 1'b0;
	end
end

/*****************************************************************************
 *                            Combinational Logic                            *
 *****************************************************************************/

// Output Assignments
assign avalon_streaming_sink_ready 				= avalon_streaming_sink_valid & (~valid | transfer_data);

// Internal Assignments
assign transfer_data					= ~avalon_streaming_source_valid | 
												(avalon_streaming_source_ready & avalon_streaming_source_valid);

/*****************************************************************************
 *                              Internal Modules                             *
 *****************************************************************************/

YCbCr_ThresholdModule YCbCr_ThresholdModule1 (
	// Inputs
	.clk								(clk),
	.clk_en							(transfer_data),
	.reset							(reset),

	.iY									(data[ 7: 0]),
	.iCr								(data[23:16]),
	.iCb								(data[15: 8]),
	.stream_in_startofpacket	(startofpacket),
	.stream_in_endofpacket		(endofpacket),
	.stream_in_empty				(empty),
	.stream_in_valid				(valid),

	// Bidirectionals

	// Outputs
	.oY									(converted_data[7:0]),
	.oCr									(converted_data[23: 16]),
	.oCb									(converted_data[ 15: 8]),
	.stream_out_startofpacket	(converted_startofpacket),
	.stream_out_endofpacket		(converted_endofpacket),
	.stream_out_empty				(converted_empty),
	.stream_out_valid				(converted_valid)
);

endmodule
