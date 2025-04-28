module YCbCr_ThresholdModule (
	// Inputs
	clk,
	clk_en,
	reset,

	iY,
	iCr,
	iCb,
	stream_in_startofpacket,
	stream_in_endofpacket,
	stream_in_empty,
	stream_in_valid,

	// Bidirectionals

	// Outputs
	oY,
	oCr,
	oCb,
	stream_out_startofpacket,
	stream_out_endofpacket,
	stream_out_empty,
	stream_out_valid
);

/*****************************************************************************
 *                           Parameter Declarations                          *
 *****************************************************************************/


/*****************************************************************************
 *                             Port Declarations                             *
 *****************************************************************************/
// Inputs
input						clk;
input						clk_en;
input						reset;

input			[ 7: 0]	iY;
input			[ 7: 0]	iCr;
input			[ 7: 0]	iCb;
input						stream_in_startofpacket;
input						stream_in_endofpacket;
input						stream_in_empty;
input						stream_in_valid;

// Bidirectionals

// Outputs
output reg	[ 7: 0]	oY;
output reg	[ 7: 0]	oCr;
output reg	[ 7: 0]	oCb;
output reg				stream_out_startofpacket;
output reg				stream_out_endofpacket;
output reg				stream_out_empty;
output reg				stream_out_valid;

// Internal Registers

reg			[7: 0]	oY_sub; //This group is meant to store the required values to give black or white based on the i/p sub values
reg			[7: 0]	oCb_sub;
reg			[7: 0]	oCr_sub;

reg			[7: 0]	iY_sub; //This group is meant to store the input values and use them for thresholding
reg			[7: 0]	iCr_sub;
reg			[7: 0]	iCb_sub;

reg	 		[ 1: 0]	startofpacket_shift_reg; //This is a group of shift registers for Avalon Interfacing
reg	 		[ 1: 0]	endofpacket_shift_reg;
reg	 		[ 1: 0]	empty_shift_reg;
reg	 		[ 1: 0]	valid_shift_reg;

/*****************************************************************************
 *                             Sequential Logic                              *
 *****************************************************************************/

// Output Registers
always @ (posedge clk) // This always block is used to assign the output sub values to the outputs of the module
begin
	if (reset)
	begin
		oY <= 8'b00010000;//According to docs, RGB becomes black if Y = 16, Cr and Cb = 128
		oCb <= 8'b10000000;
		oCr <= 8'b10000000;
	end
	else if (clk_en)
	begin
		oY <= oY_sub;
		oCb <= oCb_sub;
		oCr <= oCr_sub;
	end
end

always @ (posedge clk) // This always block is used to assign the Avalon Stream Out from the shift registers defined for this purpose
begin
	if (clk_en)
	begin
		stream_out_startofpacket	<= startofpacket_shift_reg[1];
		stream_out_endofpacket		<= endofpacket_shift_reg[1];
		stream_out_empty				<= empty_shift_reg[1];
		stream_out_valid				<= valid_shift_reg[1];
	end
end

// Internal Registers

always @ (posedge clk) //This always block is used to store incoming YCbCr into the input sub variables
begin
	if (reset)
	begin
		iY_sub		<= 8'b00010000;
		iCr_sub	<= 8'b10000000;
		iCb_sub	<= 8'b10000000;
	end
	else if (clk_en)
	begin
		iY_sub		<= iY;
		iCr_sub	<=  iCr;
		iCb_sub	<=  iCb;
	end
end

always @ (posedge clk) //This always block is used to do the thresholding to set the output sub values that are later passed on to the module output
begin
	if (iCb_sub<130)
	begin
		oY_sub <= 8'b00010000;//This set of values gives RGB black
		oCb_sub <= 8'b10000000;
		oCr_sub <= 8'b10000000;
	end
	else if (iY_sub>200)
	begin
		oY_sub <= 8'b00010000;
		oCb_sub <= 8'b10000000;
		oCr_sub <= 8'b10000000;
	end
	else
	begin
		oY_sub <= iY_sub;//This assignment gives RGB to be white
		oCb_sub <= iCb_sub;
		oCr_sub <= iCr_sub;
	end
end

always @(posedge clk) // This always block is used to set the values of the shift registers defined for the Avalon Straming Interface
begin
	if (reset)
	begin
		startofpacket_shift_reg	<= 2'h0;
		endofpacket_shift_reg	<= 2'h0;
		empty_shift_reg			<= 2'h0;
		valid_shift_reg			<= 2'h0;
	end
	else if (clk_en)
	begin
		startofpacket_shift_reg[1]	<= startofpacket_shift_reg[0];
		endofpacket_shift_reg[1]	<= endofpacket_shift_reg[0];
		empty_shift_reg[1]			<= empty_shift_reg[0];
		valid_shift_reg[1]			<= valid_shift_reg[0];

		startofpacket_shift_reg[0]	<= stream_in_startofpacket;
		endofpacket_shift_reg[0]	<= stream_in_endofpacket;
		empty_shift_reg[0]			<= stream_in_empty;
		valid_shift_reg[0]			<= stream_in_valid;
	end
end
endmodule
