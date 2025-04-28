//--------------------------------------------------------------
// Parameterized Line Buffer
//--------------------------------------------------------------
module line #(
    parameter WD = 8,
    parameter SIZE = 720
)(
    input clken,
    input clock,
    input [WD-1:0] shiftin,
    output [WD-1:0] shiftout
);
    reg [WD-1:0] buffer [SIZE-1:0];
    integer i;
    always @(posedge clock) begin
        if (clken) begin
            for (i = SIZE-1; i > 0; i = i-1)
                buffer[i] <= buffer[i-1];
            buffer[0] <= shiftin;
        end
    end
    assign shiftout = buffer[SIZE-1];
endmodule

//--------------------------------------------------------------
// RGB to Grayscale Conversion
//--------------------------------------------------------------
module rgb2grey   
(   
    input clk,   
    input rst,   

    input data_en,       
    input [23:0] in_data,            

    output [7:0] out_data   
);   

wire [7:0] R;   
wire [7:0] G;   
wire [7:0] B;   

reg [15:0] R_r;   
reg [15:0] G_r;   
reg [15:0] B_r;   

assign B = in_data[7:0];   
assign G = in_data[15:8];   
assign R = in_data[23:16];   

// Calculate results   
reg [31:0] grey;   
reg [7:0] grey_result;   

always @(posedge clk)   
begin   
    if (rst == 1'b1)   
    begin   
        R_r <= 16'b0;   
        G_r <= 16'b0;   
        B_r <= 16'b0;   
        grey <= 32'b0;   
        grey_result <= 8'b0;   
    end    
    else if (data_en)   
    begin      
        R_r <= {2'b0,R,6'b0} + {5'b0,R,3'b0} + {7'b0,R,1'b0};   
        G_r <= {1'b0,G,7'b0} + {4'b0,G,4'b0} + {6'b0,G,2'b0} + {7'b0,G,1'b0};   
        B_r <= {3'b0,B,5'b0} + {8'b0,B} - {6'b0,B,2'b0};   
        grey <= R_r + G_r + B_r;   
        grey_result <= grey[15:8];   
    end   
end   

assign out_data = grey_result;   

endmodule


//--------------------------------------------------------------
// Gaussian Filter (5x5 Kernel)
//--------------------------------------------------------------
module gaussian_filter (
    clk,
    reset,
    
    data_in,
    data_en,
    
    // Outputs
    data_out
);

parameter WIDTH = 720; // Image width in pixels

// Inputs
input clk;
input reset;

input [7:0] data_in;
input data_en;

// Outputs
output [8:0] data_out;

// Internal Wires
wire [7:0] iline2;
wire [7:0] iline3;
wire [7:0] iline4;
wire [7:0] iline5;

// Internal Registers
reg [7:0] oline_1[4:0];
reg [7:0] oline_2[4:0];
reg [7:0] oline_3[4:0];
reg [7:0] oline_4[4:0];
reg [7:0] oline_5[4:0];

reg [15:0] level_1[6:0];
reg [15:0] level_2[4:0];
reg [15:0] level_3;
reg [15:0] level_4;
reg [8:0] final_result;

// Integers
integer i;

// Gaussian Smoothing Filter
//  [ 2  4  5  4  2 ]
//  [ 4  9 12  9  4 ]
// 1 / 159 [ 5 12 15 12  5 ]
//  [ 4  9 12  9  4 ]
//  [ 2  4  5  4  2 ]

always @(posedge clk)
begin
    if (reset == 1'b1)
    begin
        for (i = 4; i >= 0; i = i-1)
        begin
            oline_1[i] <= 8'h00;
            oline_2[i] <= 8'h00;
            oline_3[i] <= 8'h00;
            oline_4[i] <= 8'h00;
            oline_5[i] <= 8'h00;
            level_1[i] <= 12'h000;
        end
    end
    else if (data_en)
    begin
        for (i = 4; i > 0; i = i-1)
        begin
            oline_1[i] <= oline_1[i-1];
            oline_2[i] <= oline_2[i-1];
            oline_3[i] <= oline_3[i-1];
            oline_4[i] <= oline_4[i-1];
            oline_5[i] <= oline_5[i-1];
        end
        oline_1[0] <= data_in;
        oline_2[0] <= iline2;
        oline_3[0] <= iline3;
        oline_4[0] <= iline4;
        oline_5[0] <= iline5;

        level_1[0] <= {7'b0,oline_1[0], 1'b0} + {7'b0,oline_1[4], 1'b0} + {7'b0,oline_5[0], 1'b0} + {7'b0,oline_5[4], 1'b0};
        level_1[1] <= {6'b0,oline_1[1], 2'b0} + {6'b0,oline_1[3], 2'b0} + {6'b0,oline_2[0], 2'b0} + {6'b0,oline_2[4], 2'b0};
        level_1[2] <= {6'b0,oline_4[0], 2'b0} + {6'b0,oline_4[4], 2'b0} + {6'b0,oline_5[1], 2'b0} + {6'b0,oline_5[3], 2'b0};

        // 5
        level_1[3] <= {8'b0,oline_1[2]} + {8'b0,oline_5[2]} + {8'b0,oline_3[0]} + {8'b0,oline_3[4]};
        // 9
        level_1[4] <= {8'b0,oline_2[1]} + {8'b0,oline_2[3]} + {8'b0,oline_4[1]} + {8'b0,oline_4[3]};
        // 12
        level_1[5] <= {8'b0,oline_2[2]} + {8'b0,oline_4[2]} + {8'b0,oline_3[1]} + {8'b0,oline_3[3]};
        // 15
        level_1[6] <= {4'b0,oline_3[2], 4'b0} - oline_3[2];

        level_2[0] <= level_1[0]+ level_1[6];
        level_2[1] <= level_1[1]+ level_1[2];

        // Multiplied by 5
        level_2[2] <= {level_1[3], 2'b0} + level_1[3];
        // Multiplied by 9
        level_2[3] <= {level_1[4], 3'b0} + level_1[4];
        // Multiplied by 12
        level_2[4] <= {level_1[5], 3'b0} + {level_1[5], 2'b0};
        level_3 <= level_2[0] + level_2[1]+ level_2[2]+ level_2[3]+ level_2[4];

        final_result <= level_3/159;
    end
end

assign data_out = final_result;

line line_buffer1 (
    .clock (clk),
    .clken (data_en),
    .shiftin (data_in),
    .shiftout (iline2),
    .taps ()
);
defparam line_buffer1.WD = 8,
         line_buffer1.SIZE = WIDTH;

line line_buffer2 (
    .clock (clk),
    .clken (data_en),
    .shiftin (iline2),
    .shiftout (iline3),
    .taps ()
);
defparam line_buffer2.WD = 8,
         line_buffer2.SIZE = WIDTH;

line line_buffer3 (
    .clock (clk),
    .clken (data_en),
    .shiftin (iline3),
    .shiftout (iline4),
    .taps ()
);
defparam line_buffer3.WD = 8,
         line_buffer3.SIZE = WIDTH;

line line_buffer4 (
    .clock (clk),
    .clken (data_en),
    .shiftin (iline4),
    .shiftout (iline5),
    .taps ()
);
defparam line_buffer4.WD = 8,
         line_buffer4.SIZE = WIDTH;

endmodule


//--------------------------------------------------------------
// Sobel Filter
//--------------------------------------------------------------
module sobel 
(   
    input       clk,   
    input       rst,   
    input       [8:0] in_data,         
    input       data_en,   
    output      [11:0] out_data   
);   
         
parameter WIDTH = 720;        

wire [8:0] iline1;   
wire [8:0] iline2;   

reg  [8:0] oline0[2:0];   
reg  [8:0] oline1[2:0];   
reg  [8:0] oline2[2:0];   

reg  [11: 0] gx;   
reg  [11: 0] gy;   
reg  [11: 0] gx_level_1[2:0];   
reg  [11: 0] gy_level_1[2:0];    
reg  [11: 0] gx_magnitude;   
reg  [11: 0] gy_magnitude;   
reg  [11: 0] gx_m;   
reg  [11: 0] gy_m;   
reg  [11: 0] g_magnitude;   
reg  [11: 0] g_m;   

reg  [15:0] gy_100;   
reg  [15:0] gx_41;   
reg  [15:0] gx_241;   

reg         neg, neg1;   
reg  [3:0]  direction;   
reg  [11: 0] fresult;   

integer i;   

always @(posedge clk or posedge rst)   
begin   
    if (rst)   
    begin   
        for (i = 2; i >= 0; i = i-1)   
        begin   
            oline0[i] <= 9'b0;   
            oline1[i] <= 9'b0;   
            oline2[i] <= 9'b0;   
            gx_level_1[i] <= 12'h0;   
            gy_level_1[i] <= 12'h0;   
        end   
        gx              <= 12'h000;   
        gy              <= 12'h000;   
        fresult         <= 12'h000;   
        gx_magnitude    <= 12'h000;   
        gy_magnitude    <= 12'h000;   
        g_magnitude     <= 12'h000;   
        gx_m            <= 12'h000;   
        gy_m            <= 12'h000;   
        g_m             <= 12'h000;   
        gy_100          <= 16'h000;   
        gx_41           <= 16'h000;   
        gx_241          <= 16'h000;   
        neg             <= 1'b0;   
        direction       <= 4'h0;   
    end   
    else if (data_en)   
    begin      
        oline0[2] <= oline0[1];   
        oline1[2] <= oline1[1];   
        oline2[2] <= oline2[1];    
        oline0[1] <= oline0[0];   
        oline1[1] <= oline1[0];   
        oline2[1] <= oline2[0];   
        oline0[0]   <= in_data;   
        oline1[0]   <= iline1;   
        oline2[0]   <= iline2;   
        gx_level_1[0]   <=   oline0[0] + {oline1[0],1'b0} + oline2[0];   
        gx_level_1[1]   <=   oline0[2] + {oline1[2],1'b0} + oline2[2];   
        gx <= gx_level_1[0] - gx_level_1[1];   

        gy_level_1[0]   <=   oline0[0] + {oline0[1],1'b0} + oline0[2];   
        gy_level_1[1]   <=   oline2[0] + {oline2[1],1'b0} + oline2[2];   
        gy <= gy_level_1[0] - gy_level_1[1];   

        gx_magnitude    <= (gx[11]) ? (~gx) + 12'h001 : gx;   
        gy_magnitude    <= (gy[11]) ? (~gy) + 12'h001 : gy;   
        neg             <= gx[11] ^ gy[11];   

        gy_100      <= {gy_magnitude,6'b0} + {gy_magnitude,5'b0} + {gy_magnitude,2'b0};   
        gx_41       <= {gx_magnitude,5'b0} + {gx_magnitude,3'b0} + gx_magnitude;   
        gx_241      <= {gx_magnitude,8'b0} - {gx_magnitude,4'b0} + gx_magnitude;   
        g_magnitude <= gx_magnitude + gy_magnitude;   
        neg1        <= neg;   

        if(gy_100 <= gx_41)   
        begin   
            direction   <= 4'b0001;   
            g_m         <= g_magnitude;   
        end   
        else if((gy_100 > gx_41) && (gy_100 < gx_241) && (neg1 == 1'b0))   
        begin   
            direction   <= 4'b0010;   
            g_m         <= g_magnitude;   
        end   
        else if((gy_100 > gx_41) && (gy_100 < gx_241) && (neg1 == 1'b1))   
        begin   
            direction   <= 4'b0100;   
            g_m         <= g_magnitude;   
        end   
        else   
        begin   
            direction   <= 4'b1000;   
            g_m         <= g_magnitude;   
        end   

        fresult[11:8]   <= direction;   
        fresult[7:0]    <= (g_m[11:10] == 2'b0) ? g_m[9:2] : 8'hFF;   
    end   
end   

assign out_data = fresult;    

line u0 (   
    .clken(data_en),   
    .clock(clk),   
    .shiftin(in_data),   
    .shiftout(iline1)   
);   

defparam    
    u0.WD       = 9,   
    u0.SIZE = WIDTH;      

line u1 (   
    .clken(data_en),   
    .clock(clk),   
    .shiftin(iline1),   
    .shiftout(iline2)   
);   

defparam    
    u1.WD       = 9,   
    u1.SIZE = WIDTH;   

endmodule


//--------------------------------------------------------------
// Non-Maximum Suppression
//--------------------------------------------------------------
module nm_s (   
    // Inputs   
    input       clk,   
    input       rst,   
    input   [11:0] data_in,            
    input   data_en,   
    output [11:0] data_out   
);   

parameter WIDTH = 720; // Image width in pixels   

wire [11:0] iline1;   
wire [11:0] iline2;   

reg  [11:0] oline0[2:0];   
reg  [11:0] oline1[2:0];   
reg  [11:0] oline2[2:0];   

reg  [11:0] r_line0[2:0];   
reg  [11:0] r_line1[2:0];   
reg  [11:0] r_line2[2:0];   

reg  [7:0] sobel_result;   
reg  [3:0] direction;   
reg  [11:0] fresult;   
integer i;   

always @(posedge clk)   
begin   
    if (rst)   
    begin   
        for (i = 2; i >= 0; i = i-1)   
        begin   
            oline0[i] <= 12'h0;   
            oline1[i] <= 12'h0;   
            oline2[i] <= 12'h0;   
        end   
    end   
    else if (data_en)   
    begin      
        oline0[2] <= oline0[1];   
        oline1[2] <= oline1[1];   
        oline2[2] <= oline2[1];   

        oline0[1] <= oline0[0];   
        oline1[1] <= oline1[0];   
        oline2[1] <= oline2[0];   

        oline0[0]   <= data_in;
        oline1[0]   <= iline1;
        oline2[0]   <= iline2;

        case (oline1[1][11:8])
            4'b0001 :   
            begin   
                if((oline1[1][7:0] > oline1[2][7:0]) && (oline1[1][7:0] > oline1[0][7:0]))   
                begin   
                    direction <= 4'b0001;   
                    sobel_result <= oline1[1][7:0];   
                end   
                else   
                begin   
                    direction <= 4'b0;   
                    sobel_result <= 0;   
                end   
            end   
            4'b0010 :   
            begin   
                if((oline1[1][7:0] > oline2[2][7:0]) && (oline1[1][7:0] > oline0[0][7:0]))   
                begin   
                    direction <= 4'b0010;   
                    sobel_result <= oline1[1][7:0];   
                end   
                else   
                begin   
                    direction <= 4'b0;   
                    sobel_result <= 0;   
                end   
            end   
            4'b0100 :   
            begin   
                if((oline1[1][7:0] > oline2[0][7:0]) && (oline1[1][7:0] > oline0[2][7:0]))   
                begin   
                    direction <= 4'b0100;   
                    sobel_result <= oline1[1][7:0];   
                end   
                else   
                begin   
                    direction <= 4'b0;   
                    sobel_result <= 0;   
                end   
            end   
            4'b1000 :   
            begin   
                if((oline1[1][7:0] > oline0[1][7:0]) && (oline1[1][7:0] > oline2[1][7:0]))   
                begin   
                    direction <= 4'b1000;   
                    sobel_result <= oline1[1][7:0];   
                end   
                else   
                begin   
                    direction <= 4'b0;   
                    sobel_result <= 0;   
                end   
            end   
            default :   
            begin   
                direction <= 4'b0;   
                sobel_result <= 0;   
            end   
        endcase   

        fresult[11:8] <= direction;   
        fresult[7:0]  <= sobel_result;   
    end   
end   

assign data_out = fresult;    

line buffer_1 (   
    .clock (clk),   
    .clken (data_en),   
    .shiftin (data_in),   
    .shiftout (iline1),   
    .taps ()   
);   
defparam buffer_1.WD = 12,   
         buffer_1.SIZE = WIDTH;    

line buffer_2 (   
    .clock (clk),   
    .clken (data_en),   
    .shiftin (iline1),   
    .shiftout (iline2),   
    .taps ()   
);   
defparam buffer_2.WD = 12,   
         buffer_2.SIZE = WIDTH;    

endmodule


//--------------------------------------------------------------
// Double Thresholding with Hysteresis
//--------------------------------------------------------------
module double_threshold_filtering (   
    input       clk,   
    input       rst,   
    input   [11:0] in_data,            
    input   data_en,   
    output [7:0] out_data   
);   

parameter WIDTH = 720; // Image width in pixels   

wire [11:0] iline1;   
wire [11:0] iline2;   

reg  [11:0] oline0[2:0];   
reg  [11:0] oline1[2:0];   
reg  [11:0] oline2[2:0];   

reg [7:0]   T_in;   
reg [7:0]   H_T;   
reg [7:0]   L_T;   

reg [7:0] result;   

integer i;   

always @(posedge clk)   
begin   
    if (rst)   
    begin   
        H_T         <=   8'h00;   
        L_T         <=   8'h00;   
        T_in        <=   8'h00;   
        result      <=   8'h00;   
        for (i = 2; i >= 0; i = i-1)   
        begin   
            oline0[i] <= 12'b0;   
            oline1[i] <= 12'b0;   
            oline2[i] <= 12'b0;   
        end   
    end   
    else if (data_en)   
    begin   
        oline0[2] <= oline0[1];   
        oline1[2] <= oline1[1];   
        oline2[2] <= oline2[1];   

        oline0[1] <= oline0[0];   
        oline1[1] <= oline1[0];   
        oline2[1] <= oline2[0];   

        oline0[0] <= in_data;   
        oline1[0] <= iline1;   
        oline2[0] <= iline2;   

        T_in <= (in_data[7:0] > T_in) ? in_data[7:0] : T_in;   
        H_T  <= T_in / 6;   
        L_T  <= {1'b0, H_T[7:1]};   

        if (oline1[1][7:0] < L_T)   
            result <= 8'h00;   
        else if (oline1[1][7:0] > H_T)   
            result <= 8'hFF;   
        else if ((oline0[1][11:8] != 0) || (oline2[1][11:8] != 0) ||   
                 (oline0[2][11:8] != 0) || (oline2[0][11:8] != 0) ||   
                 (oline0[0][11:8] != 0) || (oline2[2][11:8] != 0) ||   
                 (oline1[0][11:8] != 0) || (oline1[2][11:8] != 0))   
            result <= 8'hFF;   
        else   
            result <= 8'h00;   
    end   
end   

assign out_data = result;   

line u0 (   
    .clken(data_en),   
    .clock(clk),   
    .shiftin(in_data),   
    .shiftout(iline1)   
);   
defparam    
    u0.WD   = 12,   
    u0.SIZE = WIDTH;   

line u1 (   
    .clken(data_en),   
    .clock(clk),   
    .shiftin(iline1),   
    .shiftout(iline2)   
);   
defparam    
    u1.WD   = 12,   
    u1.SIZE = WIDTH;   

endmodule


//--------------------------------------------------------------
// Canny Core Module
//--------------------------------------------------------------
module Canny_Core (
    input clk,
    input reset,
    input [23:0] rgb_in,
    input data_en,
    output [7:0] edge_out
);
    wire [7:0] gray_out;
    wire [8:0] gaussian_out;
    wire [11:0] sobel_out;
    wire [11:0] nms_out;

    rgb2grey rgb2gray (
        .clk(clk),
        .rst(reset),
        .data_en(data_en),
        .in_data(rgb_in),
        .out_data(gray_out)
    );

    gaussian_filter gauss_filter (
        .clk(clk),
        .reset(reset),
        .data_in(gray_out),
        .data_en(data_en),
        .data_out(gaussian_out)
    );

    sobel sobel_filter (
        .clk(clk),
        .rst(reset),
        .in_data(gaussian_out),
        .data_en(data_en),
        .out_data(sobel_out)
    );

    nm_s non_max_suppress (
        .clk(clk),
        .rst(reset),
        .data_in(sobel_out),
        .data_en(data_en),
        .data_out(nm_s_out)
    );

    double_threshold_filtering thresholding (
        .clk(clk),
        .rst(reset),
        .in_data(nm_s_out),
        .data_en(data_en),
        .out_data(edge_out)
    );
endmodule