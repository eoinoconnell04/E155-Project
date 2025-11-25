/*
Author: Eoin O'Connell
Email: eoconnell@hmc.edu
Date: Nov. 19, 2025
Module Function: 3-band equalizer using cascaded biquad IIR filters
- Low band: ~100Hz center
- Mid band: ~1kHz center  
- High band: ~10kHz center
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

    // Internal signals connecting the three filters in series
    logic signed [15:0] low_band_out;
    logic signed [15:0] mid_band_out;
    
    // Low band filter coefficients (100Hz peaking filter, Fs=48kHz, Q=1.0, Gain=0dB)
    // These are example coefficients - adjust based on your filter design
    localparam logic signed [15:0] LOW_B0 = 16'sh4000;  // 1.0 in Q2.14
    localparam logic signed [15:0] LOW_B1 = 16'sh0000;  // 0.0 in Q2.14
    localparam logic signed [15:0] LOW_B2 = 16'shC000;  // -1.0 in Q2.14
    localparam logic signed [15:0] LOW_A1 = 16'sh7F80;  // ~1.998 in Q2.14
    localparam logic signed [15:0] LOW_A2 = 16'shBF00;  // ~-1.004 in Q2.14
    
    // Mid band filter coefficients (1kHz peaking filter, Fs=48kHz, Q=1.0, Gain=0dB)
    localparam logic signed [15:0] MID_B0 = 16'sh4000;  // 1.0 in Q2.14
    localparam logic signed [15:0] MID_B1 = 16'sh0000;  // 0.0 in Q2.14
    localparam logic signed [15:0] MID_B2 = 16'shC000;  // -1.0 in Q2.14
    localparam logic signed [15:0] MID_A1 = 16'sh7800;  // ~1.875 in Q2.14
    localparam logic signed [15:0] MID_A2 = 16'shC800;  // ~-0.875 in Q2.14
    
    // High band filter coefficients (10kHz peaking filter, Fs=48kHz, Q=1.0, Gain=0dB)
    localparam logic signed [15:0] HIGH_B0 = 16'sh4000;  // 1.0 in Q2.14
    localparam logic signed [15:0] HIGH_B1 = 16'sh0000;  // 0.0 in Q2.14
    localparam logic signed [15:0] HIGH_B2 = 16'shC000;  // -1.0 in Q2.14
    localparam logic signed [15:0] HIGH_A1 = 16'sh2000;  // ~0.5 in Q2.14
    localparam logic signed [15:0] HIGH_A2 = 16'shE000;  // ~-0.5 in Q2.14
    
    // Instantiate low band filter
    iir_time_mux low_band_filter (
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
    
    // Instantiate mid band filter (cascaded after low band)
    iir_time_mux mid_band_filter (
        .clk(clk),
        .l_r_clk(l_r_clk),
        .reset(reset),
        .latest_sample(low_band_out),
        .b0(MID_B0),
        .b1(MID_B1),
        .b2(MID_B2),
        .a1(MID_A1),
        .a2(MID_A2),
        .filtered_output(mid_band_out)
    );
    
    // Instantiate high band filter (cascaded after mid band)
    iir_time_mux high_band_filter (
        .clk(clk),
        .l_r_clk(l_r_clk),
        .reset(reset),
        .latest_sample(mid_band_out),
        .b0(HIGH_B0),
        .b1(HIGH_B1),
        .b2(HIGH_B2),
        .a1(HIGH_A1),
        .a2(HIGH_A2),
        .filtered_output(audio_out)
    );

endmodule