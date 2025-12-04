`timescale 1ns / 1ps

module sigmoid9slices (
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
// SIGMOID 9-SLICE CONSTANTS (Q5.11 FORMAT)
// Input range: [-6, 6]
// Scale factor: 1.0 = 2048
// ============================================================

// Breakpoints
localparam signed [15:0] BP_0 = -16'sd12288; // -6.0000
localparam signed [15:0] BP_1 = -16'sd9557; // -4.6667
localparam signed [15:0] BP_2 = -16'sd6827; // -3.3333
localparam signed [15:0] BP_3 = -16'sd4096; // -2.0000
localparam signed [15:0] BP_4 = -16'sd1365; // -0.6667
localparam signed [15:0] BP_5 = 16'sd1365; // 0.6667
localparam signed [15:0] BP_6 = 16'sd4096; // 2.0000
localparam signed [15:0] BP_7 = 16'sd6827; // 3.3333
localparam signed [15:0] BP_8 = 16'sd9557; // 4.6667
localparam signed [15:0] BP_9 = 16'sd12288; // 6.0000

// Slopes (m)
localparam signed [15:0] M_0 = 16'sd11; // 0.005133
localparam signed [15:0] M_1 = 16'sd39; // 0.018847
localparam signed [15:0] M_2 = 16'sd130; // 0.063568
localparam signed [15:0] M_3 = 16'sd338; // 0.165031
localparam signed [15:0] M_4 = 16'sd494; // 0.241135
localparam signed [15:0] M_5 = 16'sd338; // 0.165031
localparam signed [15:0] M_6 = 16'sd130; // 0.063568
localparam signed [15:0] M_7 = 16'sd39; // 0.018847
localparam signed [15:0] M_8 = 16'sd11; // 0.005133

// Intercepts (c)
localparam signed [15:0] C_0 = 16'sd68; // 0.033268
localparam signed [15:0] C_1 = 16'sd199; // 0.097268
localparam signed [15:0] C_2 = 16'sd505; // 0.246340
localparam signed [15:0] C_3 = 16'sd920; // 0.449264
localparam signed [15:0] C_4 = 16'sd1024; // 0.500000
localparam signed [15:0] C_5 = 16'sd1128; // 0.550736
localparam signed [15:0] C_6 = 16'sd1543; // 0.753660
localparam signed [15:0] C_7 = 16'sd1849; // 0.902732
localparam signed [15:0] C_8 = 16'sd1980; // 0.966732

// Saturation Values
localparam signed [15:0] SAT_LOW  = 16'sd5; // 0.002473
localparam signed [15:0] SAT_HIGH = 16'sd2043; // 0.997527

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
            if (x0_in < BP_0) begin
                s1_sat_low0 <= 1; s1_sat_high0 <= 0; // Saturation Low
                s1_m0 <= 0; s1_c0 <= 0;              // Don't care
            end else if (x0_in >= BP_9) begin
                s1_sat_low0 <= 0; s1_sat_high0 <= 1; // Saturation High
                s1_m0 <= 0; s1_c0 <= 0;              // Don't care
            end else begin
                s1_sat_low0 <= 0; s1_sat_high0 <= 0;
                if (x0_in < BP_1) begin             // Segment 1: [-6, -2]
                    s1_m0 <= M_0; s1_c0 <= C_0;
                end else if (x0_in < BP_2) begin    // Segment 2: [-2, 2]
                    s1_m0 <= M_1; s1_c0 <= C_1;
                end else if (x0_in < BP_3) begin                       
                    s1_m0 <= M_2; s1_c0 <= C_2;
                end else if (x0_in < BP_4) begin
                    s1_m0 <= M_3; s1_c0 <= C_3;
                end else if (x0_in < BP_5) begin
                    s1_m0 <= M_4; s1_c0 <= C_4;
                end else if (x0_in < BP_6) begin
                    s1_m0 <= M_5; s1_c0 <= C_5;
                end else if (x0_in < BP_7) begin
                    s1_m0 <= M_6; s1_c0 <= C_6;
                end else if (x0_in < BP_8) begin
                    s1_m0 <= M_7; s1_c0 <= C_7;
                end else begin
                    s1_m0 <= M_8; s1_c0 <= C_8;
                end
            end

            // --- LANE 1 DECODE ---
            if (x1_in < BP_0) begin
                s1_sat_low1 <= 1; s1_sat_high1 <= 0;
                s1_m1 <= 0; s1_c1 <= 0;
            end else if (x1_in >= BP_9) begin
                s1_sat_low1 <= 0; s1_sat_high1 <= 1;
                s1_m1 <= 0; s1_c1 <= 0;
            end else begin
                s1_sat_low1 <= 0; s1_sat_high1 <= 0;
                if (x1_in < BP_1) begin
                    s1_m1 <= M_0; s1_c1 <= C_0;
                end else if (x1_in < BP_2) begin
                    s1_m1 <= M_1; s1_c1 <= C_1;
                end else if (x1_in < BP_3) begin
                    s1_m1 <= M_2; s1_c1 <= C_2;
                end else if (x1_in < BP_4) begin
                    s1_m1 <= M_3; s1_c1 <= C_3;
                end else if (x1_in < BP_5) begin 
                    s1_m1 <= M_4; s1_c1 <= C_4;
                end else if (x1_in < BP_6) begin
                    s1_m1 <= M_5; s1_c1 <= C_5;
                end else if (x1_in < BP_7) begin
                    s1_m1 <= M_6; s1_c1 <= C_6;
                end else if (x1_in < BP_8) begin
                    s1_m1 <= M_7; s1_c1 <= C_7;
                end else begin
                    s1_m1 <= M_8; s1_c1 <= C_8;
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