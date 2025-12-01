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
    output logic signed [15:0] audio_out      // Output audio sample
);

    // Outputs from each parallel filter
    logic signed [15:0] low_band_out;
    logic signed [15:0] mid_band_out;
    logic signed [15:0] high_band_out;
    
    // Low-pass filter coefficients (500Hz cutoff, Fs=48kHz, Q=0.707 Butterworth)
    localparam logic signed [15:0] LOW_B0 = 16'sh0147;  // ~0.020 in Q2.14
    localparam logic signed [15:0] LOW_B1 = 16'sh028E;  // ~0.040 in Q2.14
    localparam logic signed [15:0] LOW_B2 = 16'sh0147;  // ~0.020 in Q2.14
    localparam logic signed [15:0] LOW_A1 = 16'sh6A3D;  // ~1.659 in Q2.14
    localparam logic signed [15:0] LOW_A2 = 16'shD89F;  // ~-0.618 in Q2.14
    
    // Band-pass filter coefficients (500Hz-5kHz, Fs=48kHz, Q=1.0)
    localparam logic signed [15:0] MID_B0 = 16'sh0CCC;  // ~0.200 in Q2.14
    localparam logic signed [15:0] MID_B1 = 16'sh0000;  // 0.0 in Q2.14
    localparam logic signed [15:0] MID_B2 = 16'shF334;  // ~-0.200 in Q2.14
    localparam logic signed [15:0] MID_A1 = 16'sh5A82;  // ~1.414 in Q2.14
    localparam logic signed [15:0] MID_A2 = 16'shE666;  // ~-0.400 in Q2.14
    
    // High-pass filter coefficients (5kHz cutoff, Fs=48kHz, Q=0.707 Butterworth)
    localparam logic signed [15:0] HIGH_B0 = 16'sh2E8B;  // ~0.728 in Q2.14
    localparam logic signed [15:0] HIGH_B1 = 16'shA2EA;  // ~-1.456 in Q2.14
    localparam logic signed [15:0] HIGH_B2 = 16'sh2E8B;  // ~0.728 in Q2.14
    localparam logic signed [15:0] HIGH_A1 = 16'shA5C3;  // ~-1.407 in Q2.14
    localparam logic signed [15:0] HIGH_A2 = 16'sh1F5C;  // ~0.490 in Q2.14
    
    // Instantiate low-pass filter (processes bass frequencies)
    iir_time_mux_accum low_band_filter (
        .clk(clk),
        .l_r_clk(l_r_clk),
        .reset(reset),
        .latest_sample(audio_in),
        .b0(LOW_B0),
        .b1(LOW_B1),
        .b2(LOW_B2),
        .a1(LOW_A1),
        .a2(LOW_A2),
        .filtered_output(low_band_out)
    );
    
    // Instantiate band-pass filter (processes midrange frequencies)
    iir_time_mux_accum mid_band_filter (
        .clk(clk),
        .l_r_clk(l_r_clk),
        .reset(reset),
        .latest_sample(audio_in),  // All filters get same input in parallel
        .b0(MID_B0),
        .b1(MID_B1),
        .b2(MID_B2),
        .a1(MID_A1),
        .a2(MID_A2),
        .filtered_output(mid_band_out)
    );
    
    // Instantiate high-pass filter (processes treble frequencies)
    iir_time_mux_accum high_band_filter (
        .clk(clk),
        .l_r_clk(l_r_clk),
        .reset(reset),
        .latest_sample(audio_in),  // All filters get same input in parallel
        .b0(HIGH_B0),
        .b1(HIGH_B1),
        .b2(HIGH_B2),
        .a1(HIGH_A1),
        .a2(HIGH_A2),
        .filtered_output(high_band_out)
    );
    
    // Sum all three bands (no scaling)
    // Note: Design filter coefficients to prevent overflow
    always_comb begin
        audio_out = low_band_out + mid_band_out + high_band_out;
    end

endmodule