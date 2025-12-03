/*
Author: Eoin O'Connell
Email: eoconnell@hmc.edu
Date: Nov. 19, 2025
Module Function: 3-band equalizer using parallel biquad IIR filters
- Low band: Low-pass filter ~500Hz
- Mid band: Band-pass filter ~500Hz-5kHz  
- High band: High-pass filter ~5kHz
Coefficients: Q2.14 format
Inputs/outputs: 16-bit signed audio samples
*/
module three_band_eq(
    input  logic        clk,         // High speed system clock
    input  logic        l_r_clk,     // Left right select (new sample on every edge)
    input  logic        reset,
    input  logic signed [15:0] audio_in,      // Input audio sample
    output logic signed [15:0] audio_out,
output logic mac_a // Output audio sample
);

logic mac_a2, mac_a3;

    // Outputs from each parallel filter
    logic signed [15:0] low_band_out;
    logic signed [15:0] mid_band_out;
    logic signed [15:0] high_band_out;


    // UNITY GAIN COEFFICIENTS (for testing - pass-through)
/*
    localparam logic signed [15:0] LOW_B0 = 16'sh4000;  // 1.0 in Q2.14
    localparam logic signed [15:0] LOW_B1 = 16'sh0000;  // 0.0 in Q2.14
    localparam logic signed [15:0] LOW_B2 = 16'sh0000;  // 0.0 in Q2.14
    localparam logic signed [15:0] LOW_A1 = 16'sh0000;  // 0.0 in Q2.14
    localparam logic signed [15:0] LOW_A2 = 16'sh0000;  // 0.0 in Q2.14
    
    localparam logic signed [15:0] MID_B0 = 16'sh0000;  // 0.0 in Q2.14
    localparam logic signed [15:0] MID_B1 = 16'sh0000;  // 0.0 in Q2.14
    localparam logic signed [15:0] MID_B2 = 16'sh0000;  // 0.0 in Q2.14
    localparam logic signed [15:0] MID_A1 = 16'sh0000;  // 0.0 in Q2.14
    localparam logic signed [15:0] MID_A2 = 16'sh0000;  // 0.0 in Q2.14
    
    localparam logic signed [15:0] HIGH_B0 = 16'sh0000;  // 0.0 in Q2.14
    localparam logic signed [15:0] HIGH_B1 = 16'sh0000;  // 0.0 in Q2.14
    localparam logic signed [15:0] HIGH_B2 = 16'sh0000;  // 0.0 in Q2.14
    localparam logic signed [15:0] HIGH_A1 = 16'sh0000;  // 0.0 in Q2.14
    localparam logic signed [15:0] HIGH_A2 = 16'sh0000;  // 0.0 in Q2.14
 */ 
    

    // Low-pass filter coefficients (500Hz cutoff, Fs=48kHz, Q=0.707 Butterworth)
// STABLE Low-pass filter (500Hz)
// Better low-pass (500Hz Butterworth)
// Simple 1st-order low-pass (500Hz) - STABLE and good gain

localparam logic signed [15:0] LOW_B0 = 16'sh4000;  // 0.061
localparam logic signed [15:0] LOW_B1 = 16'sh0000;  // 0.061
localparam logic signed [15:0] LOW_B2 = 16'sh0000;  // 0.0
localparam logic signed [15:0] LOW_A1 = 16'sh0000;  // 0.877 (negated to -0.877)
localparam logic signed [15:0] LOW_A2 = 16'sh0000;  // 0.0

// MID-PASS: 500Hz-5kHz bandpass (2nd order Butterworth)
// Passes midrange, cuts bass and treble
/*
localparam logic signed [15:0] MID_B0 = 16'sh03EE;  // 0.061
localparam logic signed [15:0] MID_B1 = 16'sh03EE;  // 0.061
localparam logic signed [15:0] MID_B2 = 16'sh0000;  // 0.0
localparam logic signed [15:0] MID_A1 = 16'sh3823;  // 0.877 (negated to -0.877)
localparam logic signed [15:0] MID_A2 = 16'sh0000;  // 0.0
*/

localparam logic signed [15:0] MID_B0 = 16'sh4000;  // 1.0
localparam logic signed [15:0] MID_B1 = 16'sh0000;  // 0.0
localparam logic signed [15:0] MID_B2 = 16'sh0000;  // 0.0
localparam logic signed [15:0] MID_A1 = 16'sh0000;  // 0.0
localparam logic signed [15:0] MID_A2 = 16'sh0000;  // 0.0


// HIGH-PASS: 5kHz cutoff (1st order Butterworth)
/*
localparam logic signed [15:0] HIGH_B0 = 16'sh03EE;  // 0.061
localparam logic signed [15:0] HIGH_B1 = 16'sh03EE;  // 0.061
localparam logic signed [15:0] HIGH_B2 = 16'sh0000;  // 0.0
localparam logic signed [15:0] HIGH_A1 = 16'sh3823;  // 0.877 (negated to -0.877)
localparam logic signed [15:0] HIGH_A2 = 16'sh0000;  // 0.0
*/

localparam logic signed [15:0] HIGH_B0 = 16'sh4000;  // 0.750
localparam logic signed [15:0] HIGH_B1 = 16'sh0000;  // -0.750
localparam logic signed [15:0] HIGH_B2 = 16'sh0000;  // 0.0
localparam logic signed [15:0] HIGH_A1 = 16'sh0000;  // 0.500 (negated to -0.500)
localparam logic signed [15:0] HIGH_A2 = 16'sh0000;  // 0.0

     // Edge detection for l_r_clk (detects any edge)
    logic l_r_clk_d1, l_r_clk_d2;
    logic l_r_edge;
    
    always_ff @(posedge clk) begin
        if (!reset) begin
            l_r_clk_d1 <= 1'b0;
            l_r_clk_d2 <= 1'b0;
        end else begin
            l_r_clk_d1 <= l_r_clk;
            l_r_clk_d2 <= l_r_clk_d1;
            l_r_edge <= l_r_clk_d1 ^ l_r_clk_d2;
        end
    end

    // Instantiate low-pass filter (processes bass frequencies)
    iir_time_mux_accum low_band_filter (
        .clk(clk),
        .l_r_edge(l_r_edge),
        .reset(reset),
        .latest_sample(audio_in),
        .b0(LOW_B0),
        .b1(LOW_B1),
        .b2(LOW_B2),
        .a1(LOW_A1),
        .a2(LOW_A2),
        .filtered_output(low_band_out),
.test(mac_a)
    );
    
    // Instantiate band-pass filter (processes midrange frequencies)
    iir_time_mux_accum mid_band_filter (
        .clk(clk),
        .l_r_edge(l_r_edge),
        .reset(reset),
        .latest_sample(audio_in),  // All filters get same input in parallel
        .b0(MID_B0),
        .b1(MID_B1),
        .b2(MID_B2),
        .a1(MID_A1),
        .a2(MID_A2),
        .filtered_output(mid_band_out),
.test()
    );
    
    // Instantiate high-pass filter (processes treble frequencies)
    iir_time_mux_accum high_band_filter (
        .clk(clk),
        .l_r_edge(l_r_edge),
        .reset(reset),
        .latest_sample(audio_in),  // All filters get same input in parallel
        .b0(HIGH_B0),
        .b1(HIGH_B1),
        .b2(HIGH_B2),
        .a1(HIGH_A1),
        .a2(HIGH_A2),
        .filtered_output(high_band_out),
.test()
    );
    
logic signed [15:0] low_reg, mid_reg, high_reg, audio_reg;
logic l_r_clk_prev;

always_ff @(posedge clk) begin
if (!reset) begin
low_reg <= 16'sh0000;
mid_reg <= 16'sh0000;
high_reg <= 16'sh0000;
l_r_clk_prev <= 1'b0;
end else begin
l_r_clk_prev <= l_r_clk;

// Detect any edge of l_r_clk (rising or falling)
if (l_r_edge) begin
low_reg <= low_band_out;
mid_reg <= mid_band_out;
high_reg <= high_band_out;
//audio_reg <= (mid_reg >>> 1);// + (mid_reg >>> 1);
end
// Sum in the NEXT cycle after registers are updated
audio_out <= (low_reg >>> 2) + (mid_reg >>> 2) + (high_reg >>> 2);
end
end

/*
always_comb begin
audio_out = audio_reg;//(low_reg >>> 1) + (mid_reg >>> 1);
end

    // Sum all three bands (no scaling)
    // Note: Design filter coefficients to prevent 
always_comb begin
audio_out = (low_band_out >>> 1);// + (mid_band_out >>> 1) ;  // No division needed
end 
*/


endmodule