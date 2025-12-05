
module tanh5slices (
    input wire clk,
    input wire rst_n,
    
    // --- SIMD INPUTS (2 Lanes) ---
    input wire signed [15:0] x0_in, // Q5.11 Format
    input wire signed [15:0] x1_in, // Q5.11 Format
    input wire valid_in,
    
    // --- SIMD OUTPUTS ---
    output reg signed [15:0] y0_out, // Q5.11 Format
    output reg signed [15:0] y1_out, // Q5.11 Format
    output reg valid_out
);

    // ============================================================
    // CONSTANTS (Q5.11 FORMAT)
    // 1.0 = 2048 (0x0800)
    // ============================================================
    
    // Breakpoints for Tanh 5-Slice (-3 to 3)
    localparam signed [15:0] BP_N3  = -16'sd6144; // -3.0 (0xE800)
    localparam signed [15:0] BP_N2  = -16'sd4096; // -2.0 (0xF000)
    localparam signed [15:0] BP_N05 = -16'sd1024; // -0.5 (0xFC00)
    localparam signed [15:0] BP_P05 =  16'sd1024; //  0.5 (0x0400)
    localparam signed [15:0] BP_P2  =  16'sd4096; //  2.0 (0x1000)
    localparam signed [15:0] BP_P3  =  16'sd6144; //  3.0 (0x1800)

    // Slopes (m)
    // Segment 2 & 6: m = 0.049 
    localparam signed [15:0] M_OUTER = 16'sd100;  // 0.049 * 2048 = 100
    // Segment 3 & 5: m = 0.35 
    localparam signed [15:0] M_MID   = 16'sd717;  // 0.35 * 2048 = 716.8 -> 717
    // Segment 4 (Center): m = 0.76 
    localparam signed [15:0] M_INNER = 16'sd1556; // 0.76 * 2048 = 1556.48 -> 1556

    // Intercepts (c)
    // Segment 2: c = -0.84
    localparam signed [15:0] C_SEG2  = -16'sd1720; // -0.84 * 2048 = -1719.9 -> -1720
    // Segment 3: c = -0.32
    localparam signed [15:0] C_SEG3  = -16'sd655;  // -0.32 * 2048 = -655.36 -> -655
    // Segment 4: c = 0.0
    localparam signed [15:0] C_SEG4  =  16'sd0;    //  0.0
    // Segment 5: c = 0.32
    localparam signed [15:0] C_SEG5  =  16'sd655;  //  0.32 * 2048 = 655.36 -> 655
    // Segment 6: c = 0.84
    localparam signed [15:0] C_SEG6  =  16'sd1720; //  0.84 * 2048 = 1719.9 -> 1720

    // Saturation Values
    localparam signed [15:0] SAT_LOW  = -16'sd2038; // -0.995
    localparam signed [15:0] SAT_HIGH =  16'sd2038; //  0.995

    // ============================================================
    // STAGE 1: DECODE & PARAMETER SELECTION
    // ============================================================
    reg s1_valid;
    reg signed [15:0] s1_x0, s1_x1;
    reg signed [15:0] s1_m0, s1_c0;
    reg signed [15:0] s1_m1, s1_c1;
    reg s1_sat_low0, s1_sat_high0;
    reg s1_sat_low1, s1_sat_high1;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s1_valid <= 0;
            s1_x0 <= 0; s1_x1 <= 0;
            s1_m0 <= 0; s1_c0 <= 0; s1_sat_low0 <= 0; s1_sat_high0 <= 0;
            s1_m1 <= 0; s1_c1 <= 0; s1_sat_low1 <= 0; s1_sat_high1 <= 0;
        end else begin
            s1_valid <= valid_in;
            s1_x0 <= x0_in;
            s1_x1 <= x1_in;

            // --- LANE 0 DECODE ---
            if (x0_in < BP_N3) begin
                s1_sat_low0 <= 1; s1_sat_high0 <= 0; // Saturation Low
                s1_m0 <= 0; s1_c0 <= 0;              // Don't care
            end else if (x0_in >= BP_P3) begin
                s1_sat_low0 <= 0; s1_sat_high0 <= 1; // Saturation High
                s1_m0 <= 0; s1_c0 <= 0;              // Don't care
            end else begin
                s1_sat_low0 <= 0; s1_sat_high0 <= 0;
                if (x0_in < BP_N2) begin             // Segment 2: [-3.0, -2.0)
                    s1_m0 <= M_OUTER; s1_c0 <= C_SEG2;
                end else if (x0_in < BP_N05) begin   // Segment 3: [-2.0, -0.5)
                    s1_m0 <= M_MID; s1_c0 <= C_SEG3;
                end else if (x0_in < BP_P05) begin   // Segment 4: [-0.5, 0.5)
                    s1_m0 <= M_INNER; s1_c0 <= C_SEG4;
                end else if (x0_in < BP_P2) begin    // Segment 5: [0.5, 2.0)
                    s1_m0 <= M_MID; s1_c0 <= C_SEG5;
                end else begin                       // Segment 6: [2.0, 3.0)
                    s1_m0 <= M_OUTER; s1_c0 <= C_SEG6;
                end
            end

            // --- LANE 1 DECODE ---
            if (x1_in < BP_N3) begin
                s1_sat_low1 <= 1; s1_sat_high1 <= 0;
                s1_m1 <= 0; s1_c1 <= 0;
            end else if (x1_in >= BP_P3) begin
                s1_sat_low1 <= 0; s1_sat_high1 <= 1;
                s1_m1 <= 0; s1_c1 <= 0;
            end else begin
                s1_sat_low1 <= 0; s1_sat_high1 <= 0;
                if (x1_in < BP_N2) begin
                    s1_m1 <= M_OUTER; s1_c1 <= C_SEG2;
                end else if (x1_in < BP_N05) begin
                    s1_m1 <= M_MID; s1_c1 <= C_SEG3;
                end else if (x1_in < BP_P05) begin
                    s1_m1 <= M_INNER; s1_c1 <= C_SEG4;
                end else if (x1_in < BP_P2) begin
                    s1_m1 <= M_MID; s1_c1 <= C_SEG5;
                end else begin
                    s1_m1 <= M_OUTER; s1_c1 <= C_SEG6;
                end
            end
        end
    end

    // ============================================================
    // STAGE 2: EXECUTE (y = mx + c)
    // ============================================================
    reg s2_valid;
    reg signed [15:0] s2_y0, s2_y1;
    reg s2_sat_low0, s2_sat_high0;
    reg s2_sat_low1, s2_sat_high1;

    // Temporary 32-bit registers for multiplication
    reg signed [31:0] mult_res0, mult_res1;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s2_valid <= 0;
            s2_y0 <= 0; s2_y1 <= 0;
            s2_sat_low0 <= 0; s2_sat_high0 <= 0;
            s2_sat_low1 <= 0; s2_sat_high1 <= 0;
        end else begin
            s2_valid <= s1_valid;
            
            // Pass through flags
            s2_sat_low0 <= s1_sat_low0; s2_sat_high0 <= s1_sat_high0;
            s2_sat_low1 <= s1_sat_low1; s2_sat_high1 <= s1_sat_high1;

            // --- LANE 0 CALCULATION (y = mx + c) ---
            // 1. Multiply: Q5.11 * Q5.11 = Q10.22
            mult_res0 = s1_m0 * s1_x0;
            // 2. Shift Right by 11 to get Q5.11 back (multiplication by 2^-11)
            // 3. Add Intercept
            s2_y0 <= (mult_res0 >>> 11) + s1_c0;

            // --- LANE 1 CALCULATION (y = mx + c) ---
            mult_res1 = s1_m1 * s1_x1;
            s2_y1 <= (mult_res1 >>> 11) + s1_c1;
        end
    end

    // ============================================================
    // STAGE 3: OUTPUT SELECTION
    // ============================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            valid_out <= 0;
            y0_out <= 0; y1_out <= 0;
        end else begin
            valid_out <= s2_valid;

            // Lane 0 Output Mux
            if (s2_sat_low0)       y0_out <= SAT_LOW;
            else if (s2_sat_high0) y0_out <= SAT_HIGH;
            else                   y0_out <= s2_y0;

            // Lane 1 Output Mux
            if (s2_sat_low1)       y1_out <= SAT_LOW;
            else if (s2_sat_high1) y1_out <= SAT_HIGH;
            else                   y1_out <= s2_y1;
        end
    end

endmodule