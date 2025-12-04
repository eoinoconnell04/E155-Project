/*
Author: Eoin O'Connell
Email: eoconnell@hmc.edu
Date: Nov. 19, 2025
Module Function: 3-band equalizer with adjustable coefficients
- Low band: Low-pass filter (adjustable)
- Mid band: Band-pass filter (adjustable)
- High band: High-pass filter (adjustable)
Coefficients: Q2.14 format
Inputs/outputs: 16-bit signed audio samples
*/
module three_band_eq_adjust(
    input  logic        clk,         // High speed system clock
    input  logic        l_r_clk,     // Left right select (new sample on every edge)
    input  logic        reset,
    input  logic signed [15:0] audio_in,      // Input audio sample
    
    // Low-pass filter coefficients
    input  logic signed [15:0] low_b0,
    input  logic signed [15:0] low_b1,
    input  logic signed [15:0] low_b2,
    input  logic signed [15:0] low_a1,
    input  logic signed [15:0] low_a2,
    
    // Band-pass filter coefficients
    input  logic signed [15:0] mid_b0,
    input  logic signed [15:0] mid_b1,
    input  logic signed [15:0] mid_b2,
    input  logic signed [15:0] mid_a1,
    input  logic signed [15:0] mid_a2,
    
    // High-pass filter coefficients
    input  logic signed [15:0] high_b0,
    input  logic signed [15:0] high_b1,
    input  logic signed [15:0] high_b2,
    input  logic signed [15:0] high_a1,
    input  logic signed [15:0] high_a2,
    
    output logic signed [15:0] audio_out,     // Output audio sample
    
    // Individual band outputs (for monitoring/testing)
    output logic signed [15:0] low_band_out,
    output logic signed [15:0] mid_band_out,
    output logic signed [15:0] high_band_out
);

    // Instantiate low-pass filter (processes bass frequencies)
    iir_time_mux_accum low_band_filter (
        .clk(clk),
        .l_r_clk(l_r_clk),
        .reset(reset),
        .latest_sample(audio_in),
        .b0(low_b0),
        .b1(low_b1),
        .b2(low_b2),
        .a1(low_a1),
        .a2(low_a2),
        .filtered_output(low_band_out)
    );
    
    // Instantiate band-pass filter (processes midrange frequencies)
    iir_time_mux_accum mid_band_filter (
        .clk(clk),
        .l_r_clk(l_r_clk),
        .reset(reset),
        .latest_sample(audio_in),
        .b0(mid_b0),
        .b1(mid_b1),
        .b2(mid_b2),
        .a1(mid_a1),
        .a2(mid_a2),
        .filtered_output(mid_band_out)
    );
    
    // Instantiate high-pass filter (processes treble frequencies)
    iir_time_mux_accum high_band_filter (
        .clk(clk),
        .l_r_clk(l_r_clk),
        .reset(reset),
        .latest_sample(audio_in),
        .b0(high_b0),
        .b1(high_b1),
        .b2(high_b2),
        .a1(high_a1),
        .a2(high_a2),
        .filtered_output(high_band_out)
    );
    
    // Sum all three bands
    always_comb begin
        audio_out = low_band_out + mid_band_out + high_band_out;
    end

endmodule