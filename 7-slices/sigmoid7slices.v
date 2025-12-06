`timescale 1ns / 1ps

module sigmoid7slices (
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
    
    // Breakpoints
    localparam signed [15:0] BP_N6 = -16'sd12288; // -6.0
    localparam signed [15:0] BP_N4 = -16'sd8192;  // -4.0
    localparam signed [15:0] BP_N2 = -16'sd4096;  // -2.0
    localparam signed [15:0] BP_N1 = -16'sd2048;  // -1.0
    
    localparam signed [15:0] BP_P1 =  16'sd2048;  //  1.0
    localparam signed [15:0] BP_P2 =  16'sd4096;  //  2.0
    localparam signed [15:0] BP_P4 =  16'sd8192;  //  4.0
    localparam signed [15:0] BP_P6 =  16'sd12288; //  6.0

    // Slopes (m) derived from python
    localparam signed [15:0] M_CENTER = 16'sd473; // Seg 4 (Center): ~0.231
    localparam signed [15:0] M_MID    = 16'sd307; // Seg 3 & 5:      ~0.149
    localparam signed [15:0] M_OUTER  = 16'sd104; // Seg 2 & 6:      ~0.051
    localparam signed [15:0] M_TAIL   = 16'sd16;  // Seg 1 & 7:      ~0.011

    // Intercepts (c) derived from python
    // c values for Negative segments (1, 2, 3)
    localparam signed [15:0] C_SEG1   = 16'sd100; 
    localparam signed [15:0] C_SEG2   = 16'sd451; 
    localparam signed [15:0] C_SEG3   = 16'sd857; 
    
    // c value for Center segment (4)
    localparam signed [15:0] C_SEG4   = 16'sd1024; // 0.5
    
    // c values for Positive segments (5, 6, 7)
    localparam signed [15:0] C_SEG5   = 16'sd1191; 
    localparam signed [15:0] C_SEG6   = 16'sd1597; 
    localparam signed [15:0] C_SEG7   = 16'sd1948; 

    // --- Saturation Values ---
    localparam signed [15:0] SAT_LOW  = 16'sd5;    // ~0.0025
    localparam signed [15:0] SAT_HIGH = 16'sd2043; // ~0.9975

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
            if (x0_in < BP_N6) begin
                s1_sat_low0 <= 1; s1_sat_high0 <= 0; // Saturation Low
                s1_m0 <= 0; s1_c0 <= 0;
            end else if (x0_in > BP_P6) begin
                s1_sat_low0 <= 0; s1_sat_high0 <= 1; // Saturation High
                s1_m0 <= 0; s1_c0 <= 0;
            end else begin
                s1_sat_low0 <= 0; s1_sat_high0 <= 0;
                // 7-Slice Selection Logic
                if (x0_in < BP_N4) begin           // Seg 1: [-6, -4]
                    s1_m0 <= M_TAIL;   s1_c0 <= C_SEG1;
                end else if (x0_in < BP_N2) begin  // Seg 2: [-4, -2]
                    s1_m0 <= M_OUTER;  s1_c0 <= C_SEG2;
                end else if (x0_in < BP_N1) begin  // Seg 3: [-2, -1]
                    s1_m0 <= M_MID;    s1_c0 <= C_SEG3;
                end else if (x0_in < BP_P1) begin  // Seg 4: [-1, 1] (Center)
                    s1_m0 <= M_CENTER; s1_c0 <= C_SEG4;
                end else if (x0_in < BP_P2) begin  // Seg 5: [1, 2]
                    s1_m0 <= M_MID;    s1_c0 <= C_SEG5;
                end else if (x0_in < BP_P4) begin  // Seg 6: [2, 4]
                    s1_m0 <= M_OUTER;  s1_c0 <= C_SEG6;
                end else begin                     // Seg 7: [4, 6]
                    s1_m0 <= M_TAIL;   s1_c0 <= C_SEG7;
                end
            end

            // --- LANE 1 DECODE ---
            if (x1_in < BP_N6) begin
                s1_sat_low1 <= 1; s1_sat_high1 <= 0;
                s1_m1 <= 0; s1_c1 <= 0;
            end else if (x1_in > BP_P6) begin
                s1_sat_low1 <= 0; s1_sat_high1 <= 1;
                s1_m1 <= 0; s1_c1 <= 0;
            end else begin
                s1_sat_low1 <= 0; s1_sat_high1 <= 0;
                // 7-Slice Selection Logic
                if (x1_in < BP_N4) begin
                    s1_m1 <= M_TAIL;   s1_c1 <= C_SEG1;
                end else if (x1_in < BP_N2) begin
                    s1_m1 <= M_OUTER;  s1_c1 <= C_SEG2;
                end else if (x1_in < BP_N1) begin
                    s1_m1 <= M_MID;    s1_c1 <= C_SEG3;
                end else if (x1_in < BP_P1) begin
                    s1_m1 <= M_CENTER; s1_c1 <= C_SEG4;
                end else if (x1_in < BP_P2) begin
                    s1_m1 <= M_MID;    s1_c1 <= C_SEG5;
                end else if (x1_in < BP_P4) begin
                    s1_m1 <= M_OUTER;  s1_c1 <= C_SEG6;
                end else begin
                    s1_m1 <= M_TAIL;   s1_c1 <= C_SEG7;
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

            // --- LANE 0 CALCULATION ---
            // 1. Multiply: Q5.11 * Q5.11 = Q10.22
            mult_res0 = s1_m0 * s1_x0;
            // 2. Shift Right by 11 to get Q5.11 back
            // 3. Add Intercept
            s2_y0 <= (mult_res0 >>> 11) + s1_c0;

            // --- LANE 1 CALCULATION ---
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