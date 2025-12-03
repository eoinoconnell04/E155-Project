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
    //input logic        filter_bypass,
    input  logic signed [15:0] audio_in,      // Input audio sample
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
    output logic mac_a // Output audio sample
);

logic mac_a2, mac_a3;

    // Outputs from each parallel filter
    logic signed [15:0] low_band_out;
    logic signed [15:0] mid_band_out;
    logic signed [15:0] high_band_out;

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
        .filtered_output(low_band_out),
        .test(mac_a)
    );
    
    // Instantiate band-pass filter (processes midrange frequencies)
    iir_time_mux_accum mid_band_filter (
        .clk(clk),
        .l_r_clk(l_r_clk),
        .reset(reset),
        .latest_sample(low_band_out),  // All filters get same input in parallel
        .b0(mid_b0),
        .b1(mid_b1),
        .b2(mid_b2),
        .a1(mid_a1),
        .a2(mid_a2),
        .filtered_output(mid_band_out),
        .test()
    );
    
    // Instantiate high-pass filter (processes treble frequencies)
    iir_time_mux_accum high_band_filter (
        .clk(clk),
        .l_r_clk(l_r_clk),
        .reset(reset),
        .latest_sample(mid_band_out),  // All filters get same input in parallel
        .b0(high_b0),
        .b1(high_b1),
        .b2(high_b2),
        .a1(high_a1),
        .a2(high_a2),
        .filtered_output(high_band_out),
        .test()
    );
    
logic signed [15:0] low_reg, mid_reg, high_reg, audio_reg, prev_audio_in;
logic l_r_clk_prev;

always_ff @(posedge clk) begin
    if (!reset) begin
        low_reg <= 16'sh0000;
        mid_reg <= 16'sh0000;
        high_reg <= 16'sh0000;
        l_r_clk_prev <= 1'b0;
        //audio_out <= 16'sh0000;
    end else begin
        l_r_clk_prev <= l_r_clk;

        // Detect any edge of l_r_clk (rising or falling)
        if (l_r_clk != l_r_clk_prev) begin
            low_reg <= low_band_out;
            mid_reg <= mid_band_out;
            high_reg <= high_band_out;
            prev_audio_in <= audio_in;
            //audio_reg <= (mid_reg >>> 1);// + (mid_reg >>> 1);
        end
        // Sum in the NEXT cycle after registers are updated
        //audio_out <= (low_reg >>> 2) + (mid_reg >>> 2) + (high_reg >>> 2);
        //audio_out <= filter_bypass ? high_band_out : audio_in;
        audio_out <= high_band_out;
    end
end
/*
always_comb begin
audio_out = audio_reg;//(low_reg >>> 1) + (mid_reg >>> 1);
end
/*
    // Sum all three bands (no scaling)
    // Note: Design filter coefficients to prevent 
always_comb begin
audio_out = (low_band_out >>> 1);// + (mid_band_out >>> 1) ;  // No division needed
end 
*/


endmodule