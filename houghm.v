module HoughTransformModule(
    input  wire         clk,
    input  wire         clk_en,
    input  wire         reset,

    // Streaming input signals
    input  wire [7:0]   iY,
    input  wire [7:0]   iCr,
    input  wire [7:0]   iCb,
    input  wire         stream_in_startofpacket,
    input  wire         stream_in_endofpacket,
    input  wire [1:0]   stream_in_empty,
    input  wire         stream_in_valid,

    // Streaming output signals
    output reg  [7:0]   oY,
    output reg  [7:0]   oCr,
    output reg  [7:0]   oCb,
    output reg          stream_out_startofpacket,
    output reg          stream_out_endofpacket,
    output reg  [1:0]   stream_out_empty,
    output reg          stream_out_valid
);

  //-------------------------------------------------------------------------
  // Parameters and Derived Constants
  //-------------------------------------------------------------------------
  parameter IMAGE_WIDTH  = 640;
  parameter IMAGE_HEIGHT = 480;
  
  // For accumulator scaled dimensions (e.g., quarter resolution)
  parameter ACC_WIDTH    = 160; // IMAGE_WIDTH/4
  parameter ACC_HEIGHT   = 120; // IMAGE_HEIGHT/4
  
  parameter MIN_RADIUS            = 10;
  parameter MAX_RADIUS            = 30;
  parameter NUM_RADII             = 3;
  parameter ANGLE_SAMPLES         = 16;
  parameter ACCUMULATOR_THRESHOLD = 15;
  
  // Precompute the step size (using integer math)
  localparam RADIUS_STEP = (MAX_RADIUS - MIN_RADIUS) / (NUM_RADII - 1);

  //-------------------------------------------------------------------------
  // FSM State Definitions
  //-------------------------------------------------------------------------
  localparam STATE_IDLE   = 2'd0,
             STATE_ACCUM  = 2'd1,
             STATE_OUTPUT = 2'd2;
  
  reg [1:0] state;

  //-------------------------------------------------------------------------
  // Internal Counters and Registers
  //-------------------------------------------------------------------------
  // Pixel coordinates (for the input/frame)
  reg [9:0] x_pos, y_pos;
  
  // Current radius index and angle index for accumulation
  reg [1:0] r_idx;
  reg [3:0] angle_idx;
  
  // Current radius value for accumulation, updated using RADIUS_STEP
  reg [7:0] current_radius;
  
  // Temporary registers for multiplication results (16 bits to avoid truncation)
  reg signed [15:0] mult_cos, mult_sin;
  
  // Temporary registers for computed accumulator indices
  reg [9:0] calc_a, calc_b;
  
  //-------------------------------------------------------------------------
  // Accumulator Memory (For Voting)
  //-------------------------------------------------------------------------
  // Infer block RAM. Note: dimensions are based on ACC_WIDTH and ACC_HEIGHT.
  (* ram_style = "block" *) reg [7:0] accumulator [0:NUM_RADII-1][0:ACC_HEIGHT-1][0:ACC_WIDTH-1];
  
  //-------------------------------------------------------------------------
  // Sine and Cosine Lookup Functions (Fixed-point, 8-bit signed)
  //-------------------------------------------------------------------------
  function automatic signed [7:0] cos_lookup;
    input [3:0] idx;
    begin
      case(idx)
        4'd0:  cos_lookup = 8'sd127;
        4'd1:  cos_lookup = 8'sd118;
        4'd2:  cos_lookup = 8'sd90;
        4'd3:  cos_lookup = 8'sd46;
        4'd4:  cos_lookup = 8'sd0;
        4'd5:  cos_lookup = -8'sd46;
        4'd6:  cos_lookup = -8'sd90;
        4'd7:  cos_lookup = -8'sd118;
        4'd8:  cos_lookup = -8'sd127;
        4'd9:  cos_lookup = -8'sd118;
        4'd10: cos_lookup = -8'sd90;
        4'd11: cos_lookup = -8'sd46;
        4'd12: cos_lookup = 8'sd0;
        4'd13: cos_lookup = 8'sd46;
        4'd14: cos_lookup = 8'sd90;
        4'd15: cos_lookup = 8'sd118;
        default: cos_lookup = 8'sd127;
      endcase
    end
  endfunction

  function automatic signed [7:0] sin_lookup;
    input [3:0] idx;
    begin
      case(idx)
        4'd0:  sin_lookup = 8'sd0;
        4'd1:  sin_lookup = 8'sd46;
        4'd2:  sin_lookup = 8'sd90;
        4'd3:  sin_lookup = 8'sd118;
        4'd4:  sin_lookup = 8'sd127;
        4'd5:  sin_lookup = 8'sd118;
        4'd6:  sin_lookup = 8'sd90;
        4'd7:  sin_lookup = 8'sd46;
        4'd8:  sin_lookup = 8'sd0;
        4'd9:  sin_lookup = -8'sd46;
        4'd10: sin_lookup = -8'sd90;
        4'd11: sin_lookup = -8'sd118;
        4'd12: sin_lookup = -8'sd127;
        4'd13: sin_lookup = -8'sd118;
        4'd14: sin_lookup = -8'sd90;
        4'd15: sin_lookup = -8'sd46;
        default: sin_lookup = 8'sd0;
      endcase
    end
  endfunction

  //-------------------------------------------------------------------------
  // Main FSM Process
  //-------------------------------------------------------------------------
  always @(posedge clk or posedge reset) begin
    if (reset) begin
      state                    <= STATE_IDLE;
      x_pos                    <= 10'd0;
      y_pos                    <= 10'd0;
      r_idx                    <= 2'd0;
      angle_idx                <= 4'd0;
      current_radius           <= MIN_RADIUS[7:0];
      oY                       <= 8'd0;
      oCr                      <= 8'd128;
      oCb                      <= 8'd128;
      stream_out_valid         <= 1'b0;
      stream_out_startofpacket <= 1'b0;
      stream_out_endofpacket   <= 1'b0;
      stream_out_empty         <= 2'd0;
    end
    else if (clk_en) begin
      case(state)
        //---------------------------------------------------------------
        // STATE_IDLE: Wait for the start-of-frame.
        //---------------------------------------------------------------
        STATE_IDLE: begin
          // Pass-through input signals
          oY  <= iY;
          oCr <= iCr;
          oCb <= iCb;
          stream_out_startofpacket <= stream_in_startofpacket;
          stream_out_endofpacket   <= stream_in_endofpacket;
          stream_out_empty         <= stream_in_empty;
          stream_out_valid         <= stream_in_valid;
          // When a new frame starts, reset pixel counters and indices.
          if (stream_in_startofpacket && stream_in_valid) begin
            x_pos          <= 10'd0;
            y_pos          <= 10'd0;
            r_idx          <= 2'd0;
            angle_idx      <= 4'd0;
            current_radius <= MIN_RADIUS[7:0];
            state          <= STATE_ACCUM;
          end
        end

        //---------------------------------------------------------------
        // STATE_ACCUM: Process each pixel; if an edge is detected (iY > 200),
        // perform an angle sweep to update the accumulator.
        // Always pass through the pixel data.
        //---------------------------------------------------------------
        STATE_ACCUM: begin
          // Pass through signals
          oY  <= iY;
          oCr <= iCr;
          oCb <= iCb;
          stream_out_startofpacket <= stream_in_startofpacket;
          stream_out_endofpacket   <= stream_in_endofpacket;
          stream_out_empty         <= stream_in_empty;
          stream_out_valid         <= stream_in_valid;

          if (stream_in_valid) begin
            if (iY > 8'd200) begin  // Edge detected
              if (angle_idx < ANGLE_SAMPLES) begin
                mult_cos = $signed({1'b0, current_radius}) * $signed(cos_lookup(angle_idx));
                mult_sin = $signed({1'b0, current_radius}) * $signed(sin_lookup(angle_idx));
                // Calculate potential accumulator indices.
                // The first ">>>" accounts for the fixed-point multiplication scale,
                // and the final ">>2" scales coordinates down by 4.
                calc_a = (x_pos - (mult_cos >>> 7)) >>> 2;
                calc_b = (y_pos - (mult_sin >>> 7)) >>> 2;
                // Update accumulator if indices are within bounds.
                if ((calc_a < ACC_WIDTH) && (calc_b < ACC_HEIGHT)) begin
                  accumulator[r_idx][calc_b][calc_a] <= accumulator[r_idx][calc_b][calc_a] + 8'd1;
                end
                angle_idx <= angle_idx + 4'd1;
              end
              else begin
                // Reset angle index; update radius or move to next pixel.
                angle_idx <= 4'd0;
                if (r_idx < NUM_RADII - 1) begin
                  r_idx          <= r_idx + 2'd1;
                  current_radius <= MIN_RADIUS[7:0] + ((r_idx + 1) * RADIUS_STEP);
                end
                else begin
                  r_idx          <= 2'd0;
                  current_radius <= MIN_RADIUS[7:0];
                  // Advance pixel counters.
                  if (x_pos == IMAGE_WIDTH - 1) begin
                    x_pos <= 10'd0;
                    if (y_pos == IMAGE_HEIGHT - 1)
                      y_pos <= 10'd0;
                    else
                      y_pos <= y_pos + 1;
                  end
                  else begin
                    x_pos <= x_pos + 1;
                  end
                end
              end
            end
            else begin
              // For non-edge pixels, simply update pixel counters.
              if (x_pos == IMAGE_WIDTH - 1) begin
                x_pos <= 10'd0;
                if (y_pos == IMAGE_HEIGHT - 1)
                  y_pos <= 10'd0;
                else
                  y_pos <= y_pos + 1;
              end
              else begin
                x_pos <= x_pos + 1;
              end
            end

            // If end-of-frame is detected, move to OUTPUT state.
            if (stream_in_endofpacket && stream_in_valid)
              state <= STATE_OUTPUT;
          end
        end

        //---------------------------------------------------------------
        // STATE_OUTPUT: Output the processed frame.
        // For now, this state simply passes the input signals to output.
        //---------------------------------------------------------------
        STATE_OUTPUT: begin
          // Output pixel values are passed through. In a complete design, this is
          // where you'd overlay detected circles onto the image.
          oY  <= iY;
          oCr <= iCr;
          oCb <= iCb;
          stream_out_startofpacket <= (x_pos == 10'd0 && y_pos == 10'd0);
          stream_out_endofpacket   <= (x_pos == IMAGE_WIDTH - 10'd1 && y_pos == IMAGE_HEIGHT - 10'd1);
          stream_out_empty         <= stream_in_empty;
          stream_out_valid         <= 1'b1;
          // Update pixel counters for output.
          if (x_pos == IMAGE_WIDTH - 1) begin
            x_pos <= 10'd0;
            if (y_pos == IMAGE_HEIGHT - 1)
              y_pos <= 10'd0;
            else
              y_pos <= y_pos + 1;
          end
          else begin
            x_pos <= x_pos + 1;
          end
          // Optionally return to STATE_IDLE at the end of the frame.
          if ((x_pos == IMAGE_WIDTH - 1) && (y_pos == IMAGE_HEIGHT - 1))
            state <= STATE_IDLE;
        end

        default: state <= STATE_IDLE;
      endcase
    end
  end

endmodule
