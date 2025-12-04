`timescale 1ns / 1ps

module sigmoid9slices_tb;

    // --- DUT Signals ---
    reg clk;
    reg rst_n;
    reg signed [15:0] x0_in, x1_in; // Q5.11
    reg valid_in;
    wire signed [15:0] y0_out, y1_out; // Q5.11
    wire valid_out;

    // --- Python Data Arrays ---
    // 40 points from -10 to 10
    real x_py [0:39]; 
    integer i;

    // --- Instantiate the PIPELINED SIMD DUT ---
    sigmoid9slices uut (
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
        $dumpfile("sigmoid9slices_tb.vcd");
        $dumpvars(0, sigmoid9slices_tb);
        // 1. Initialize Python Input Array (Copied from your data)
        x_py[0] = -10.0;          x_py[1] = -9.48717949;
        x_py[2] = -8.97435897;    x_py[3] = -8.46153846;
        x_py[4] = -7.94871795;    x_py[5] = -7.43589744;
        x_py[6] = -6.92307692;    x_py[7] = -6.41025641;
        x_py[8] = -5.8974359;     x_py[9] = -5.38461538;
        x_py[10] = -4.87179487;   x_py[11] = -4.35897436;
        x_py[12] = -3.84615385;   x_py[13] = -3.33333333;
        x_py[14] = -2.82051282;   x_py[15] = -2.30769231;
        x_py[16] = -1.79487179;   x_py[17] = -1.28205128;
        x_py[18] = -0.76923077;   x_py[19] = -0.25641026;
        x_py[20] = 0.25641026;    x_py[21] = 0.76923077;
        x_py[22] = 1.28205128;    x_py[23] = 1.79487179;
        x_py[24] = 2.30769231;    x_py[25] = 2.82051282;
        x_py[26] = 3.33333333;    x_py[27] = 3.84615385;
        x_py[28] = 4.35897436;    x_py[29] = 4.87179487;
        x_py[30] = 5.38461538;    x_py[31] = 5.8974359;
        x_py[32] = 6.41025641;    x_py[33] = 6.92307692;
        x_py[34] = 7.43589744;    x_py[35] = 7.94871795;
        x_py[36] = 8.46153846;    x_py[37] = 8.97435897;
        x_py[38] = 9.48717949;    x_py[39] = 10.0;

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
        // Since we have 40 inputs, we loop 20 times.
        for (i = 0; i < 40; i = i + 2) begin
            @(posedge clk);
            valid_in = 1;
            
            // Lane 0 gets even indices (0, 2, 4...)
            x0_in = to_fixed(x_py[i]);
            
            // Lane 1 gets odd indices (1, 3, 5...)
            // Check boundary to avoid out of bounds on last element
            if (i+1 < 40)
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