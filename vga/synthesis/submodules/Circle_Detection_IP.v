module Circle_Detection_IP (
    input       clk,
    input       reset,
    input       edge_pixel,
    output reg  circle_pixel
);

reg [9:0] edge_counter; // Count consecutive edge pixels

always @(posedge clk) begin
    if (reset) begin
        edge_counter <= 10'h0;
        circle_pixel <= 1'b0;
    end else begin
        if (edge_pixel) begin
            edge_counter <= (edge_counter == 10'd500) ? 10'h0 : edge_counter + 1;
        end else begin
            edge_counter <= 10'h0;
        end
        
        // Detect circle if 500+ edges counted (adjust threshold)
        circle_pixel <= (edge_counter >= 10'd500);
    end
end

endmodule
