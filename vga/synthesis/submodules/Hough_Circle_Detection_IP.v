module Hough_Circle_Detection_IP (
    input               clk,
    input               reset,

    input               edge_pixel,       // single-bit edge pixel from Canny detector

    output reg          circle_pixel      // single-bit circle detection output 
);

reg [15:0] edge_counter;

always @(posedge clk or posedge reset) begin
    if(reset) begin
        edge_counter <= 16'd0;
        circle_pixel <= 1'b0;
    end else begin
        if(edge_pixel)
            edge_counter <= edge_counter + 16'd1;
        else 
            edge_counter <= 16'd0;

        circle_pixel <= (edge_counter >= 16'd5000); // threshold-based detection placeholder
    end 
end

endmodule
