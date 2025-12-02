`timescale 1ns / 1ps

module tanh3slices_tb;

    // --- DUT Signals ---
    reg clk;
    reg rst_n;
    reg signed [15:0] x0_in, x1_in; // Q5.11
    reg valid_in;
    wire signed [15:0] y0_out, y1_out; // Q5.11
    wire valid_out;

    // --- Python Data Arrays ---
    // 20 points from -5 to 5 (generated from np.linspace)
    real x_py [0:19]; 
    integer i;

    // --- Instantiate the PIPELINED SIMD DUT ---
    tanh3slices uut (
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
        $dumpfile("tanh3slices_tb.vcd");
        $dumpvars(0, tanh3slices_tb);
        // 1. Initialize Input Array (from Python np.linspace(-5, 5, 20))
        x_py[0]  = -5.0;
        x_py[1]  = -4.47368421;
        x_py[2]  = -3.94736842;
        x_py[3]  = -3.42105263;
        x_py[4]  = -2.89473684;
        x_py[5]  = -2.36842105;
        x_py[6]  = -1.84210526;
        x_py[7]  = -1.31578947;
        x_py[8]  = -0.78947368;
        x_py[9]  = -0.26315789;
        x_py[10] = 0.26315789;
        x_py[11] = 0.78947368;
        x_py[12] = 1.31578947;
        x_py[13] = 1.84210526;
        x_py[14] = 2.36842105;
        x_py[15] = 2.89473684;
        x_py[16] = 3.42105263;
        x_py[17] = 3.94736842;
        x_py[18] = 4.47368421;
        x_py[19] = 5.0;

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
        // We have 20 inputs, loop increments by 2
        for (i = 0; i < 20; i = i + 2) begin
            @(posedge clk);
            valid_in = 1;
            
            // Lane 0 gets even indices
            x0_in = to_fixed(x_py[i]);
            
            // Lane 1 gets odd indices
            if (i+1 < 20)
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
    integer out_cnt = 0;
    
    always @(posedge clk) begin
        if (valid_out) begin
            // Display Lane 0 Data
            if (out_cnt < 20)
                $display("| %17.8f |  0   | %19.8f |     %h  |", 
                         x_py[out_cnt], to_real(y0_out), y0_out);
            
            // Display Lane 1 Data
            if (out_cnt + 1 < 20)
                $display("| %17.8f |  1   | %19.8f |     %h  |", 
                         x_py[out_cnt+1], to_real(y1_out), y1_out);
            
            out_cnt = out_cnt + 2;
        end
    end

endmodule