`timescale 1ns / 1ps
`include "tanh7slices.v"

module tanh7slices_tb;

    // --- DUT Signals ---
    reg clk;
    reg rst_n;
    reg signed [15:0] x0_in, x1_in; // Q5.11
    reg valid_in;
    wire signed [15:0] y0_out, y1_out; // Q5.11
    wire valid_out;

    // --- Python Data Arrays ---
    // 20 points from -5 to 5 (generated from np.linspace)
    real x_py [0:100]; 
    integer i;

    // --- Instantiate the PIPELINED SIMD DUT ---
    tanh7slices uut (
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
        $dumpfile("tanh7slices_tb.vcd");
        $dumpvars(0, tanh7slices_tb);
        // 1. Initialize Input Array (from Python np.linspace(-5, 5, 20))
        x_py[0] = -5.00000000;   x_py[1] = -4.89898990;   
        x_py[2] = -4.79797980;   x_py[3] = -4.69696970;   
        x_py[4] = -4.59595960;   x_py[5] = -4.49494949;   
        x_py[6] = -4.39393939;   x_py[7] = -4.29292929;   
        x_py[8] = -4.19191919;   x_py[9] = -4.09090909;   
        x_py[10] = -3.98989899;  x_py[11] = -3.88888889;  
        x_py[12] = -3.78787879;  x_py[13] = -3.68686869;  
        x_py[14] = -3.58585859;  x_py[15] = -3.48484848;  
        x_py[16] = -3.38383838;  x_py[17] = -3.28282828;  
        x_py[18] = -3.18181818;  x_py[19] = -3.08080808;  
        x_py[20] = -2.97979798;  x_py[21] = -2.87878788;  
        x_py[22] = -2.77777778;  x_py[23] = -2.67676768;  
        x_py[24] = -2.57575758;  x_py[25] = -2.47474747;  
        x_py[26] = -2.37373737;  x_py[27] = -2.27272727;  
        x_py[28] = -2.17171717;  x_py[29] = -2.07070707;  
        x_py[30] = -1.96969697;  x_py[31] = -1.86868687;  
        x_py[32] = -1.76767677;  x_py[33] = -1.66666667;  
        x_py[34] = -1.56565657;  x_py[35] = -1.46464646;  
        x_py[36] = -1.36363636;  x_py[37] = -1.26262626;  
        x_py[38] = -1.16161616;  x_py[39] = -1.06060606;  
        x_py[40] = -0.95959596;  x_py[41] = -0.85858586;  
        x_py[42] = -0.75757576;  x_py[43] = -0.65656566;  
        x_py[44] = -0.55555556;  x_py[45] = -0.45454545;  
        x_py[46] = -0.35353535;  x_py[47] = -0.25252525;  
        x_py[48] = -0.15151515;  x_py[49] = -0.05050505;  
        x_py[50] = 0.05050505;   x_py[51] = 0.15151515;   
        x_py[52] = 0.25252525;   x_py[53] = 0.35353535;   
        x_py[54] = 0.45454545;   x_py[55] = 0.55555556;   
        x_py[56] = 0.65656566;   x_py[57] = 0.75757576;   
        x_py[58] = 0.85858586;   x_py[59] = 0.95959596;   
        x_py[60] = 1.06060606;   x_py[61] = 1.16161616;   
        x_py[62] = 1.26262626;   x_py[63] = 1.36363636;   
        x_py[64] = 1.46464646;   x_py[65] = 1.56565657;   
        x_py[66] = 1.66666667;   x_py[67] = 1.76767677;   
        x_py[68] = 1.86868687;   x_py[69] = 1.96969697;   
        x_py[70] = 2.07070707;   x_py[71] = 2.17171717;   
        x_py[72] = 2.27272727;   x_py[73] = 2.37373737;   
        x_py[74] = 2.47474747;   x_py[75] = 2.57575758;   
        x_py[76] = 2.67676768;   x_py[77] = 2.77777778;   
        x_py[78] = 2.87878788;   x_py[79] = 2.97979798;   
        x_py[80] = 3.08080808;   x_py[81] = 3.18181818;   
        x_py[82] = 3.28282828;   x_py[83] = 3.38383838;   
        x_py[84] = 3.48484848;   x_py[85] = 3.58585859;   
        x_py[86] = 3.68686869;   x_py[87] = 3.78787879;   
        x_py[88] = 3.88888889;   x_py[89] = 3.98989899;   
        x_py[90] = 4.09090909;   x_py[91] = 4.19191919;   
        x_py[92] = 4.29292929;   x_py[93] = 4.39393939;   
        x_py[94] = 4.49494949;   x_py[95] = 4.59595960;   
        x_py[96] = 4.69696970;   x_py[97] = 4.79797980;   
        x_py[98] = 4.89898990;   x_py[99] = 5.00000000;

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
        for (i = 0; i < 100; i = i + 2) begin
            @(posedge clk);
            valid_in = 1;
            
            // Lane 0 gets even indices
            x0_in = to_fixed(x_py[i]);
            
            // Lane 1 gets odd indices
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
    integer out_cnt = 0;
    
    always @(posedge clk) begin
        if (valid_out) begin
            // Display Lane 0 Data
            if (out_cnt < 100)
                $display("| %17.8f |  0   | %19.8f |     %h  |", 
                         x_py[out_cnt], to_real(y0_out), y0_out);
            
            // Display Lane 1 Data
            if (out_cnt + 1 < 100)
                $display("| %17.8f |  1   | %19.8f |     %h  |", 
                         x_py[out_cnt+1], to_real(y1_out), y1_out);
            
            out_cnt = out_cnt + 2;
        end
    end

endmodule