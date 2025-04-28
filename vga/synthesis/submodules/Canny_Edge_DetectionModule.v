module YCbCr_RedThresholdModule (
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
    // Outputs
    oY,
    oCr,
    oCb,
    stream_out_startofpacket,
    stream_out_endofpacket,
    stream_out_empty,
    stream_out_valid
);

// Inputs
input                        clk;
input                        clk_en;
input                        reset;
input            [ 7: 0]    iY;
input            [ 7: 0]    iCr;
input            [ 7: 0]    iCb;
input                        stream_in_startofpacket;
input                        stream_in_endofpacket;
input                        stream_in_empty;
input                        stream_in_valid;

// Outputs
output reg    [ 7: 0]    oY;
output reg    [ 7: 0]    oCr;
output reg    [ 7: 0]    oCb;
output reg                stream_out_startofpacket;
output reg                stream_out_endofpacket;
output reg                stream_out_empty;
output reg                stream_out_valid;

// Internal Registers
reg            [7: 0]    oY_sub;
reg            [7: 0]    oCb_sub;
reg            [7: 0]    oCr_sub;
reg            [7: 0]    iY_sub;
reg            [7: 0]    iCr_sub;
reg            [7: 0]    iCb_sub;
reg             [1: 0]    startofpacket_shift_reg;
reg             [1: 0]    endofpacket_shift_reg;
reg             [1: 0]    empty_shift_reg;
reg             [1: 0]    valid_shift_reg;

// Thresholds for red detection
parameter CR_THRESHOLD = 160;  // High Cr for red
parameter CB_THRESHOLD = 120;  // Low Cb to exclude blue
parameter Y_MIN = 50;          // Minimum Y to exclude dark pixels

// Output Registers
always @ (posedge clk)
begin
    if (reset)
    begin
        oY <= 8'b00010000;    // Y=16 (black)
        oCb <= 8'b10000000;   // Cb=128 (neutral)
        oCr <= 8'b10000000;   // Cr=128 (neutral)
    end
    else if (clk_en)
    begin
        oY <= oY_sub;
        oCb <= oCb_sub;
        oCr <= oCr_sub;
    end
end

// Avalon Streaming Outputs
always @ (posedge clk)
begin
    if (clk_en)
    begin
        stream_out_startofpacket <= startofpacket_shift_reg[1];
        stream_out_endofpacket   <= endofpacket_shift_reg[1];
        stream_out_empty         <= empty_shift_reg[1];
        stream_out_valid         <= valid_shift_reg[1];
    end
end

// Input Sub-Registers
always @ (posedge clk)
begin
    if (reset)
    begin
        iY_sub  <= 8'b00010000;
        iCr_sub <= 8'b10000000;
        iCb_sub <= 8'b10000000;
    end
    else if (clk_en)
    begin
        iY_sub  <= iY;
        iCr_sub <= iCr;
        iCb_sub <= iCb;
    end
end

// Thresholding Logic for Red Detection
always @ (posedge clk)
begin
    if (iCr_sub > CR_THRESHOLD && iCb_sub < CB_THRESHOLD && iY_sub > Y_MIN)
    begin
        oY_sub  <= 8'b11111111;  // Y=255 (white)
        oCb_sub <= 8'b10000000;  // Cb=128
        oCr_sub <= 8'b10000000;  // Cr=128
    end
    else
    begin
        oY_sub  <= 8'b00010000;  // Y=16 (black)
        oCb_sub <= 8'b10000000;  // Cb=128
        oCr_sub <= 8'b10000000;  // Cr=128
    end
end

// Avalon Signal Shift Registers (2-cycle delay)
always @ (posedge clk)
begin
    if (reset)
    begin
        startofpacket_shift_reg <= 2'h0;
        endofpacket_shift_reg   <= 2'h0;
        empty_shift_reg         <= 2'h0;
        valid_shift_reg         <= 2'h0;
    end
    else if (clk_en)
    begin
        startofpacket_shift_reg[1] <= startofpacket_shift_reg[0];
        endofpacket_shift_reg[1]   <= endofpacket_shift_reg[0];
        empty_shift_reg[1]         <= empty_shift_reg[0];
        valid_shift_reg[1]         <= valid_shift_reg[0];

        startofpacket_shift_reg[0] <= stream_in_startofpacket;
        endofpacket_shift_reg[0]   <= stream_in_endofpacket;
        empty_shift_reg[0]         <= stream_in_empty;
        valid_shift_reg[0]         <= stream_in_valid;
    end
end

endmodule