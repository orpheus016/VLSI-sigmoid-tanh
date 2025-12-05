module sigmoid5slices (
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
    
    // Breakpoints (5 Slices: [-6, -4], [-4, -2], [-2, 2], [2, 4], [4, 6])
    localparam signed [15:0] BP_N6 = -16'sd12288; // -6.0 (0xD000)
    localparam signed [15:0] BP_N4 = -16'sd8192;  // -4.0 (0xE000)
    localparam signed [15:0] BP_N2 = -16'sd4096;  // -2.0 (0xF000)
    localparam signed [15:0] BP_P2 =  16'sd4096;  //  2.0 (0x1000)
    localparam signed [15:0] BP_P4 =  16'sd8192;  //  4.0 (0x2000)
    localparam signed [15:0] BP_P6 =  16'sd12288; //  6.0 (0x3000)

    // Slopes (m) derived from Python for 5 segments
    localparam signed [15:0] M_OUTER = 16'sd60;   // 0.0292 (Segments 1 & 5: |x| in [4, 6])
    localparam signed [15:0] M_MID   = 16'sd250;  // 0.1221 (Segments 2 & 4: |x| in [2, 4])
    localparam signed [15:0] M_INNER = 16'sd390;  // 0.1904 (Segment 3: |x| in [0, 2])

    // Intercepts (c) derived from Python for 5 segments
    localparam signed [15:0] C_SEG1  = 16'sd286;  // 0.1396
    localparam signed [15:0] C_SEG2  = 16'sd584;  // 0.2852
    localparam signed [15:0] C_SEG3  = 16'sd1024; // 0.5000
    localparam signed [15:0] C_SEG4  = 16'sd1464; // 0.7150
    localparam signed [15:0] C_SEG5  = 16'sd1762; // 0.8603

    // Saturation Values (Outside of [-6, 6])
    localparam signed [15:0] SAT_LOW  = 16'sd5;   // 0.0025
    localparam signed [15:0] SAT_HIGH = 16'sd2043; // 0.9975

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

            // --- LANE 0 DECODE (5 Slices) ---
            if (x0_in < BP_N6) begin
                s1_sat_low0 <= 1; s1_sat_high0 <= 0; // Saturation Low
                s1_m0 <= 0; s1_c0 <= 0;              // Don't care
            end else if (x0_in > BP_P6) begin
                s1_sat_low0 <= 0; s1_sat_high0 <= 1; // Saturation High
                s1_m0 <= 0; s1_c0 <= 0;              // Don't care
            end else begin
                s1_sat_low0 <= 0; s1_sat_high0 <= 0;
                if (x0_in < BP_N4) begin             // Segment 1: [-6, -4]
                    s1_m0 <= M_OUTER;
                    s1_c0 <= C_SEG1;
                end else if (x0_in < BP_N2) begin    // Segment 2: [-4, -2]
                    s1_m0 <= M_MID;
                    s1_c0 <= C_SEG2;
                end else if (x0_in < BP_P2) begin    // Segment 3: [-2, 2]
                    s1_m0 <= M_INNER;
                    s1_c0 <= C_SEG3;
                end else if (x0_in < BP_P4) begin    // Segment 4: [2, 4]
                    s1_m0 <= M_MID;
                    s1_c0 <= C_SEG4;
                end else begin                       // Segment 5: [4, 6]
                    s1_m0 <= M_OUTER;
                    s1_c0 <= C_SEG5;
                end
            end

            // --- LANE 1 DECODE (5 Slices) ---
            if (x1_in < BP_N6) begin
                s1_sat_low1 <= 1; s1_sat_high1 <= 0;
                s1_m1 <= 0; s1_c1 <= 0;
            end else if (x1_in > BP_P6) begin
                s1_sat_low1 <= 0; s1_sat_high1 <= 1;
                s1_m1 <= 0; s1_c1 <= 0;
            end else begin
                s1_sat_low1 <= 0; s1_sat_high1 <= 0;
                if (x1_in < BP_N4) begin
                    s1_m1 <= M_OUTER;
                    s1_c1 <= C_SEG1;
                end else if (x1_in < BP_N2) begin
                    s1_m1 <= M_MID;
                    s1_c1 <= C_SEG2;
                end else if (x1_in < BP_P2) begin
                    s1_m1 <= M_INNER;
                    s1_c1 <= C_SEG3;
                end else if (x1_in < BP_P4) begin
                    s1_m1 <= M_MID;
                    s1_c1 <= C_SEG4;
                end else begin
                    s1_m1 <= M_OUTER;
                    s1_c1 <= C_SEG5;
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
    reg signed [31:0] mult_res0, mult_res1;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s2_valid <= 0;
            s2_y0 <= 0; s2_y1 <= 0;
            s2_sat_low0 <= 0; s2_sat_high0 <= 0;
            s2_sat_low1 <= 0; s2_sat_high1 <= 0;
        end else begin
            s2_valid <= s1_valid;
            s2_sat_low0 <= s1_sat_low0;
            s2_sat_high0 <= s1_sat_high0;
            s2_sat_low1 <= s1_sat_low1; s2_sat_high1 <= s1_sat_high1;

            // Lane 0: Q5.11 * Q5.11 = Q10.22. Shift >> 11 to get Q5.11.
            mult_res0 = s1_m0 * s1_x0;
            s2_y0 <= (mult_res0 >>> 11) + s1_c0;
            
            // Lane 1
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