`timescale 1ns / 1ps

module tanh3slices (
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
    
    // Breakpoints for Tanh 3-Slice (-3 to 3)
    localparam signed [15:0] BP_N3 = -16'sd6144; // -3.0 (0xE800)
    localparam signed [15:0] BP_N1 = -16'sd2048; // -1.0 (0xF800)
    localparam signed [15:0] BP_P1 =  16'sd2048; //  1.0 (0x0800)
    localparam signed [15:0] BP_P3 =  16'sd6144; //  3.0 (0x1800)

    // Slopes (m)
    // Segment 1 & 3 (Outer): m = 0.11673
    localparam signed [15:0] M_OUTER = 16'sd239; 
    // Segment 2 (Inner): m = 0.76159
    localparam signed [15:0] M_INNER = 16'sd1560;

    // Intercepts (c)
    localparam signed [15:0] C_SEG1  = -16'sd1321; // -0.64486
    localparam signed [15:0] C_SEG2  =  16'sd0;    //  0.0
    localparam signed [15:0] C_SEG3  =  16'sd1321; //  0.64486

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
            end else if (x0_in > BP_P3) begin
                s1_sat_low0 <= 0; s1_sat_high0 <= 1; // Saturation High
                s1_m0 <= 0; s1_c0 <= 0;              // Don't care
            end else begin
                s1_sat_low0 <= 0; s1_sat_high0 <= 0;
                if (x0_in < BP_N1) begin             // Segment 1: [-3, -1]
                    s1_m0 <= M_OUTER; s1_c0 <= C_SEG1;
                end else if (x0_in < BP_P1) begin    // Segment 2: [-1, 1]
                    s1_m0 <= M_INNER; s1_c0 <= C_SEG2;
                end else begin                       // Segment 3: [1, 3]
                    s1_m0 <= M_OUTER; s1_c0 <= C_SEG3;
                end
            end

            // --- LANE 1 DECODE ---
            if (x1_in < BP_N3) begin
                s1_sat_low1 <= 1; s1_sat_high1 <= 0;
                s1_m1 <= 0; s1_c1 <= 0;
            end else if (x1_in > BP_P3) begin
                s1_sat_low1 <= 0; s1_sat_high1 <= 1;
                s1_m1 <= 0; s1_c1 <= 0;
            end else begin
                s1_sat_low1 <= 0; s1_sat_high1 <= 0;
                if (x1_in < BP_N1) begin
                    s1_m1 <= M_OUTER; s1_c1 <= C_SEG1;
                end else if (x1_in < BP_P1) begin
                    s1_m1 <= M_INNER; s1_c1 <= C_SEG2;
                end else begin
                    s1_m1 <= M_OUTER; s1_c1 <= C_SEG3;
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