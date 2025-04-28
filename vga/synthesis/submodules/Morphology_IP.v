module Morphology_IP (
    input               clk,
    input               reset,
    input               pixel_in,
    output reg          pixel_out
);

// Line buffers for 3x3 kernel
reg line_buffer_1[639:0];
reg line_buffer_2[639:0];

integer i;

// Shift registers for current pixels
reg [2:0] window_row_1, window_row_2, window_row_3;

// Coordinates counters
integer col_count = 0;

// Morphological operation pipeline
always @(posedge clk or posedge reset) begin
    if(reset) begin
        for(i=0;i<640;i=i+1) begin
            line_buffer_1[i]<=0;
            line_buffer_2[i]<=0;
        end
        window_row_1<=3'b000;window_row_2<=3'b000;window_row_3<=3'b000;
        pixel_out<=1'b0;col_count<=0;
    end else begin
        // Shift pixels into window rows
        window_row_1<={window_row_1[1:0],line_buffer_2[col_count]};
        window_row_2<={window_row_2[1:0],line_buffer_1[col_count]};
        window_row_3<={window_row_3[1:0],pixel_in};

        // Update line buffers
        line_buffer_2[col_count]<=line_buffer_1[col_count];
        line_buffer_1[col_count]<=pixel_in;

        // Increment column counter for each pixel clock cycle
        col_count<=(col_count==639)?0:(col_count+1);

        // Perform dilation followed by erosion (closing)
        pixel_out<=(|{window_row_1,window_row_2,window_row_3})&&(&{window_row_1,window_row_2,window_row_3});
    end 
end

endmodule
