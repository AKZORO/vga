module Speed_Sign_DetectionCore (
    input               clk,
    input               reset,

    input       [23:0]  pixel_in,
    input               valid_in,
    input               sop_in,
    input               eop_in,

    output reg  [23:0]  pixel_out,
    output reg          valid_out,
    output reg          sop_out,
    output reg          eop_out
);

// Internal signals for pipeline stages
wire red_mask_pixel, morph_pixel, canny_pixel, circle_pixel;

// Pipeline registers for synchronization
reg [4:0] valid_pipe, sop_pipe, eop_pipe;

// Stage-1: RGB to HSV & Red Mask Detection Module
Red_Color_Detection red_detect_inst (
    .clk(clk), .reset(reset), .pixel_rgb(pixel_in), 
    .red_detect(red_mask_pixel)
);

// Stage-2: Morphological Operations Module (Closing & Filling)
Morphology_IP morphology_inst (
    .clk(clk), .reset(reset), 
    .pixel_in(red_mask_pixel), 
    .pixel_out(morph_pixel)
);

// Stage-3: Canny Edge Detection Module (Your existing module unchanged)
Canny_Edge_DetectionModule canny_inst (
    .clk(clk), .clk_en(valid_pipe[1]), .reset(reset),
    
    .iPixel({24{morph_pixel}}),
    
    .stream_in_startofpacket(sop_pipe[1]),
    .stream_in_endofpacket(eop_pipe[1]),
    
    .stream_out_startofpacket(),
    
    .stream_out_endofpacket(),
    
    .oPixel({canny_pixel,canny_pixel,canny_pixel}),
    
    .stream_out_valid()
);

// Stage-4: Hough Circle Detection Module (Your existing module unchanged)
Hough_Circle_Detection_IP hough_inst (
   .clk(clk),.reset(reset),.edge_pixel(canny_pixel),
   .circle_pixel(circle_pixel)
);

// Pipeline synchronization logic for control signals
always @(posedge clk or posedge reset) begin
   if (reset) begin
       valid_pipe <= 5'b0; sop_pipe <= 5'b0; eop_pipe <= 5'b0;
   end else begin
       valid_pipe <= {valid_pipe[3:0], valid_in};
       sop_pipe   <= {sop_pipe[3:0], sop_in};
       eop_pipe   <= {eop_pipe[3:0], eop_in};
   end
end

// Output assignment with highlighted detected circles in blue color.
always @(posedge clk or posedge reset) begin
   if (reset) begin
       pixel_out<=24'h0; valid_out<=1'b0; sop_out<=1'b0; eop_out<=1'b0;
   end else begin
       pixel_out<= circle_pixel ? {8'h00,8'h00,8'hFF}:pixel_in; // Blue highlight circles.
       valid_out<=valid_pipe[4];
       sop_out<=sop_pipe[4];
       eop_out<=eop_pipe[4];
   end 
end

endmodule
