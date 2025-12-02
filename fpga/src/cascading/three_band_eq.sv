/*
Author: Eoin O'Connell
Email: eoconnell@hmc.edu
Date: Nov. 19, 2025
Module Function: 3-band equalizer using cascaded biquad IIR filters
- Low band: Low-shelf filter ~400Hz
- Mid band: Peaking filter ~1kHz  
- High band: High-shelf filter ~2kHz
Coefficients: Q2.14 format
Inputs/outputs: 16-bit signed audio samples
Architecture: Cascaded (serial) processing
*/
module three_band_eq(
    input  logic        clk,         // High speed system clock
    input  logic        l_r_clk,     // Left right select (new sample on every edge)
    input  logic        reset,
    input  logic signed [15:0] audio_in,      // Input audio sample
    output logic signed [15:0] audio_out,     // Output audio sample
    output logic        mac_a                 // Debug output
);

    // Filter outputs and valid signals
    logic signed [15:0] low_out, mid_out, high_out;
    logic low_valid, mid_valid, high_valid;
    
    // Trigger signals for each stage
    logic low_trigger, mid_trigger, high_trigger;
    
    // Edge detection for l_r_clk (detects any edge)
    logic l_r_clk_d1, l_r_clk_d2;
    logic l_r_edge;
    
    always_ff @(posedge clk) begin
        if (!reset) begin
            l_r_clk_d1 <= 1'b0;
            l_r_clk_d2 <= 1'b0;
            l_r_edge <= 1'b0;
        end else begin
            l_r_clk_d1 <= l_r_clk;
            l_r_clk_d2 <= l_r_clk_d1;
            l_r_edge <= l_r_clk_d1 ^ l_r_clk_d2;
        end
    end
    
    // Stage 1: Low filter starts on l_r_clk edge
    assign low_trigger = l_r_edge;
    
    // LOW-SHELF FILTER COEFFICIENTS (400Hz, Q=0.707)
    // These are placeholder values - replace with actual calculated coefficients
    localparam logic signed [15:0] LOW_B0 = 16'sh03EE;  // 0.061
    localparam logic signed [15:0] LOW_B1 = 16'sh03EE;  // 0.061
    localparam logic signed [15:0] LOW_B2 = 16'sh0000;  // 0.0
    localparam logic signed [15:0] LOW_A1 = 16'sh3823;  // -0.877 (negated)
    localparam logic signed [15:0] LOW_A2 = 16'sh0000;  // 0.0

    // MID-PEAKING FILTER COEFFICIENTS (1kHz, Q=0.707)
    localparam logic signed [15:0] MID_B0 = 16'sh4000;  // 1.0 (unity gain for now)
    localparam logic signed [15:0] MID_B1 = 16'sh0000;  // 0.0
    localparam logic signed [15:0] MID_B2 = 16'sh0000;  // 0.0
    localparam logic signed [15:0] MID_A1 = 16'sh0000;  // 0.0
    localparam logic signed [15:0] MID_A2 = 16'sh0000;  // 0.0

    // HIGH-SHELF FILTER COEFFICIENTS (2kHz, Q=0.707)
    localparam logic signed [15:0] HIGH_B0 = 16'sh4000;  // 1.0 (unity gain for now)
    localparam logic signed [15:0] HIGH_B1 = 16'sh0000;  // 0.0
    localparam logic signed [15:0] HIGH_B2 = 16'sh0000;  // 0.0
    localparam logic signed [15:0] HIGH_A1 = 16'sh0000;  // 0.0
    localparam logic signed [15:0] HIGH_A2 = 16'sh0000;  // 0.0
    
    // Stage 1: Low-shelf filter (processes bass frequencies)
    iir_time_mux_accum low_filter (
        .clk(clk),
        .trigger(low_trigger),
        .reset(reset),
        .latest_sample(audio_in),
        .b0(LOW_B0),
        .b1(LOW_B1),
        .b2(LOW_B2),
        .a1(LOW_A1),
        .a2(LOW_A2),
        .filtered_output(low_out),
        .output_ready(low_valid)
    );
    
    // Stage 2: Mid filter starts when low filter completes
    assign mid_trigger = low_valid;
    
    // Stage 2: Mid-peaking filter (processes midrange frequencies)
    iir_time_mux_accum mid_filter (
        .clk(clk),
        .trigger(mid_trigger),
        .reset(reset),
        .latest_sample(low_out),  // Cascaded: input is output of previous stage
        .b0(MID_B0),
        .b1(MID_B1),
        .b2(MID_B2),
        .a1(MID_A1),
        .a2(MID_A2),
        .filtered_output(mid_out),
        .output_ready(mid_valid)
    );
    
    // Stage 3: High filter starts when mid filter completes
    assign high_trigger = mid_valid;
    
    // Stage 3: High-shelf filter (processes treble frequencies)
    iir_time_mux_accum high_filter (
        .clk(clk),
        .trigger(high_trigger),
        .reset(reset),
        .latest_sample(mid_out),  // Cascaded: input is output of previous stage
        .b0(HIGH_B0),
        .b1(HIGH_B1),
        .b2(HIGH_B2),
        .a1(HIGH_A1),
        .a2(HIGH_A2),
        .filtered_output(high_out),
        .output_ready(high_valid)
    );
    
    // Final output: high_out is the result of all three cascaded filters
    assign audio_out = high_out;
    
    // Debug output
    assign mac_a = low_valid;

endmodule