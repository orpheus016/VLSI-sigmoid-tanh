`timescale 1ns / 1ps
`include "sigmoid7slices.v"

module sigmoid7slices_tb;

    // --- DUT Signals ---
    reg clk;
    reg rst_n;
    reg signed [15:0] x0_in, x1_in; // Q5.11
    reg valid_in;
    wire signed [15:0] y0_out, y1_out; // Q5.11
    wire valid_out;

    // --- Python Data Arrays ---
    // 100 points from -10 to 10
    real x_py [0:99]; 
    integer i;

    // --- Instantiate the PIPELINED SIMD DUT ---
    sigmoid7slices uut (
        .clk(clk),
        .rst_n(rst_n),
        .x0_in(x0_in),
        .x1_in(x1_in),
        .valid_in(valid_in),
        .y0_out(y0_out),
        .y1_out(y1_out),
        .valid_out(valid_out)
    );

    // --- Clock Generation (100MHz) ---
    always #5 clk = ~clk;

    // --- Helper: Convert Real to Q5.11 Fixed Point ---
    function signed [15:0] to_fixed(input real val);
        begin
            // Multiply by 2048 (2^11) and cast to integer
            to_fixed = $rtoi(val * 2048.0);
        end
    endfunction

    // --- Helper: Convert Q5.11 Fixed Point to Real (For Display) ---
    function real to_real(input signed [15:0] val);
        begin
            // Divide by 2048.0
            to_real = $itor(val) / 2048.0;
        end
    endfunction

    // --- Main Stimulus Process ---
    initial begin
        $dumpfile("sigmoid7slices_tb.vcd");
        $dumpvars(0, sigmoid7slices_tb);
        // 1. Initialize Python Input Array (Copied from your data)
        x_py[0] = -10.00000000;  x_py[1] = -9.79797980;   
        x_py[2] = -9.59595960;   x_py[3] = -9.39393939;   
        x_py[4] = -9.19191919;   x_py[5] = -8.98989899;   
        x_py[6] = -8.78787879;   x_py[7] = -8.58585859;   
        x_py[8] = -8.38383838;   x_py[9] = -8.18181818;   
        x_py[10] = -7.97979798;  x_py[11] = -7.77777778;  
        x_py[12] = -7.57575758;  x_py[13] = -7.37373737;  
        x_py[14] = -7.17171717;  x_py[15] = -6.96969697;  
        x_py[16] = -6.76767677;  x_py[17] = -6.56565657;  
        x_py[18] = -6.36363636;  x_py[19] = -6.16161616;  
        x_py[20] = -5.95959596;  x_py[21] = -5.75757576;  
        x_py[22] = -5.55555556;  x_py[23] = -5.35353535;  
        x_py[24] = -5.15151515;  x_py[25] = -4.94949495;  
        x_py[26] = -4.74747475;  x_py[27] = -4.54545455;  
        x_py[28] = -4.34343434;  x_py[29] = -4.14141414;  
        x_py[30] = -3.93939394;  x_py[31] = -3.73737374;  
        x_py[32] = -3.53535354;  x_py[33] = -3.33333333;  
        x_py[34] = -3.13131313;  x_py[35] = -2.92929293;  
        x_py[36] = -2.72727273;  x_py[37] = -2.52525253;  
        x_py[38] = -2.32323232;  x_py[39] = -2.12121212;  
        x_py[40] = -1.91919192;  x_py[41] = -1.71717172;  
        x_py[42] = -1.51515152;  x_py[43] = -1.31313131;  
        x_py[44] = -1.11111111;  x_py[45] = -0.90909091;  
        x_py[46] = -0.70707071;  x_py[47] = -0.50505051;  
        x_py[48] = -0.30303030;  x_py[49] = -0.10101010;  
        x_py[50] = 0.10101010;   x_py[51] = 0.30303030;   
        x_py[52] = 0.50505051;   x_py[53] = 0.70707071;   
        x_py[54] = 0.90909091;   x_py[55] = 1.11111111;   
        x_py[56] = 1.31313131;   x_py[57] = 1.51515152;   
        x_py[58] = 1.71717172;   x_py[59] = 1.91919192;   
        x_py[60] = 2.12121212;   x_py[61] = 2.32323232;   
        x_py[62] = 2.52525253;   x_py[63] = 2.72727273;   
        x_py[64] = 2.92929293;   x_py[65] = 3.13131313;   
        x_py[66] = 3.33333333;   x_py[67] = 3.53535354;   
        x_py[68] = 3.73737374;   x_py[69] = 3.93939394;   
        x_py[70] = 4.14141414;   x_py[71] = 4.34343434;   
        x_py[72] = 4.54545455;   x_py[73] = 4.74747475;   
        x_py[74] = 4.94949495;   x_py[75] = 5.15151515;   
        x_py[76] = 5.35353535;   x_py[77] = 5.55555556;   
        x_py[78] = 5.75757576;   x_py[79] = 5.95959596;   
        x_py[80] = 6.16161616;   x_py[81] = 6.36363636;   
        x_py[82] = 6.56565657;   x_py[83] = 6.76767677;   
        x_py[84] = 6.96969697;   x_py[85] = 7.17171717;   
        x_py[86] = 7.37373737;   x_py[87] = 7.57575758;   
        x_py[88] = 7.77777778;   x_py[89] = 7.97979798;   
        x_py[90] = 8.18181818;   x_py[91] = 8.38383838;   
        x_py[92] = 8.58585859;   x_py[93] = 8.78787879;   
        x_py[94] = 8.98989899;   x_py[95] = 9.19191919;   
        x_py[96] = 9.39393939;   x_py[97] = 9.59595960;   
        x_py[98] = 9.79797980;   x_py[99] = 10.00000000;

        // 2. Initial Reset
        clk = 0;
        rst_n = 0;
        valid_in = 0;
        x0_in = 0;
        x1_in = 0;
        
        #20;
        rst_n = 1;
        
        $display("----------------------------------------------------------------");
        $display("|   Input X (Real)  | Lane |  HW Output Y (Real) |  Hex Output |");
        $display("----------------------------------------------------------------");

        // 3. Feed Data into SIMD Pipelines (2 inputs per clock)
        // Since we have 100 inputs, we loop 50 times.
        for (i = 0; i < 100; i = i + 2) begin
            @(posedge clk);
            valid_in = 1;
            
            // Lane 0 gets even indices (0, 2, 4...)
            x0_in = to_fixed(x_py[i]);
            
            // Lane 1 gets odd indices (1, 3, 5...)
            // Check boundary to avoid out of bounds on last element
            if (i+1 < 100)
                x1_in = to_fixed(x_py[i+1]);
            else
                x1_in = 0;
        end

        // 4. Stop Input
        @(posedge clk);
        valid_in = 0;
        
        // 5. Wait for pipeline to drain
        #100;
        $finish;
    end

    // --- Output Monitor Process ---
    // This runs in parallel to capture outputs as they emerge from the pipeline
    // We reconstruct the input X index based on a counter for display purposes
    integer out_cnt = 0;
    
    always @(posedge clk) begin
        if (valid_out) begin
            // Display Lane 0 Data
            $display("| %17.8f |  0   | %19.8f |     %h  |", 
                     x_py[out_cnt], to_real(y0_out), y0_out);
            
            // Display Lane 1 Data
            $display("| %17.8f |  1   | %19.8f |     %h  |", 
                     x_py[out_cnt+1], to_real(y1_out), y1_out);
            
            out_cnt = out_cnt + 2;
        end
    end

endmodule