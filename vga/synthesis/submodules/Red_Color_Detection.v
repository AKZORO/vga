module Red_Color_Detection (
    input               clk,
    input               reset,
    input       [23:0]  pixel_rgb,
    output reg          red_detect
);

// Extract RGB channels
wire [7:0] R = pixel_rgb[23:16];
wire [7:0] G = pixel_rgb[15:8];
wire [7:0] B = pixel_rgb[7:0];

// Intermediate signals
reg [7:0] max_rgb, min_rgb, delta;
reg [7:0] hue;
reg [7:0] saturation, value;

// RGB to HSV Conversion (fixed-point arithmetic)
always @(posedge clk or posedge reset) begin
    if (reset) begin
        hue <= 8'd0; saturation <= 8'd0; value <= 8'd0;
        red_detect <= 1'b0;
    end else begin
        // Find max and min RGB values
        max_rgb <= (R>=G && R>=B)? R : (G>=B)? G : B;
        min_rgb <= (R<=G && R<=B)? R : (G<=B)? G : B;
        delta   <= max_rgb - min_rgb;

        // Compute Hue (simplified)
        if(delta == 0)
            hue <= 8'd0;
        else if(max_rgb == R)
            hue <= ((60*(G-B))/delta)%360;
        else if(max_rgb == G)
            hue <= ((60*(B-R))/delta)+120;
        else
            hue <= ((60*(R-G))/delta)+240;

        // Compute Saturation and Value
        saturation <= (max_rgb==0)? 8'd0 : ((delta*255)/max_rgb);
        value      <= max_rgb;

        // Detect Red Hue Range (approx. 0-10 or 350-360 degrees)
        if(((hue<=10)||(hue>=170)) && (saturation>100) && (value>100))
            red_detect <= 1'b1;
        else
            red_detect <= 1'b0;
    end
end

endmodule
