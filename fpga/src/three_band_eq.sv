/*
Authors: Eoin O'Connell (eoconnell@hmc.edu)
         Drake Gonzales (drgonzales@g.hmc.edu)
Date: Dec. 4, 2025
Module Function: 3-band equalizer using cascaded biquad IIR filters
- Processes audio through three sequential filter stages
- Coefficients in Q2.14 fixed-point format
- 16-bit signed audio samples
*/

module three_band_eq(
    input  logic               clk,
    input  logic               l_r_clk,
    input  logic               reset,
    input  logic signed [15:0] audio_in,
    
    // Low-pass filter coefficients
    input  logic signed [15:0] low_b0,
    input  logic signed [15:0] low_b1,
    input  logic signed [15:0] low_b2,
    input  logic signed [15:0] low_a1,
    input  logic signed [15:0] low_a2,
    
    // Mid-pass filter coefficients
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
    
    output logic signed [15:0] audio_out,
    output logic               mac_a
);

    // Outputs from each cascaded filter stage
    logic signed [15:0] low_band_out;
    logic signed [15:0] mid_band_out;
    logic signed [15:0] high_band_out;

    // First stage: Low-pass filter
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
        .filtered_output(low_band_out),
        .test(mac_a)
    );
    
    // Second stage: Mid-pass filter (cascaded from low-pass output)
    iir_time_mux_accum mid_band_filter (
        .clk(clk),
        .l_r_clk(l_r_clk),
        .reset(reset),
        .latest_sample(low_band_out),
        .b0(mid_b0),
        .b1(mid_b1),
        .b2(mid_b2),
        .a1(mid_a1),
        .a2(mid_a2),
        .filtered_output(mid_band_out),
        .test(mac_a)
    );
    
    // Third stage: High-pass filter (cascaded from mid-pass output)
    iir_time_mux_accum high_band_filter (
        .clk(clk),
        .l_r_clk(l_r_clk),
        .reset(reset),
        .latest_sample(mid_band_out),
        .b0(high_b0),
        .b1(high_b1),
        .b2(high_b2),
        .a1(high_a1),
        .a2(high_a2),
        .filtered_output(high_band_out),
        .test(mac_a)
    );
    
    // Output is the final cascaded result
    assign audio_out = high_band_out;

endmodule