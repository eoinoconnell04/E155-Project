/*
Simple MAC16 Gain Test Module
Author: Test module for MAC16 verification
Date: Dec 1, 2024

This module simply multiplies the input by a fixed gain coefficient (0.5 in Q2.14)
to test if the MAC16 wrapper is working at all.

Pipeline stages:
- Cycle 0: Input arrives
- Cycle 1: Input registered in MAC16 (A_REG, B_REG)
- Cycle 2: Multiplication happens
- Cycle 3: Result available (accumulator registered)
Total latency: ~3 cycles

Expected behavior: output = input × 0.5 (approximately)
*/

module simple_mac_gain_test(
    input  logic        clk,
    input  logic        l_r_clk,      // Sample clock (not used, but kept for interface compatibility)
    input  logic        reset,         // Active HIGH reset
    input  logic signed [15:0] audio_in,
    output logic signed [15:0] audio_out
);

    // Fixed gain coefficient: 0.5 in Q2.14 format
    // 0.5 * 2^14 = 8192 = 0x2000
    localparam logic signed [15:0] GAIN = 16'sh2000;  // 0.5 gain
    
    // MAC control signals
    logic mac_reset;
    logic mac_ce;
    logic signed [31:0] mac_result;
    
    // Pipeline registers to match MAC latency
    logic signed [15:0] audio_in_pipe1;
    logic signed [15:0] audio_in_pipe2;
    logic signed [15:0] audio_in_pipe3;
    
    // Sample clock edge detection for resetting accumulator
    logic l_r_clk_prev;
    logic l_r_clk_edge;
    
    always_ff @(posedge clk) begin
        if (reset) begin
            l_r_clk_prev <= 1'b0;
        end else begin
            l_r_clk_prev <= l_r_clk;
        end
    end
    
    assign l_r_clk_edge = l_r_clk ^ l_r_clk_prev;  // Any edge
    
    // MAC reset: reset accumulator on new sample
    // Active LOW for MAC16 (inverted inside wrapper)
    assign mac_reset = ~l_r_clk_edge;  
    
    // MAC clock enable: always enabled
    assign mac_ce = 1'b1;
    
    // Pipeline input to align with MAC output
    // MAC has ~3 cycle latency, so we don't need much pipeline for simple passthrough
    always_ff @(posedge clk) begin
        if (reset) begin
            audio_in_pipe1 <= 16'd0;
            audio_in_pipe2 <= 16'd0;
            audio_in_pipe3 <= 16'd0;
        end else begin
            audio_in_pipe1 <= audio_in;
            audio_in_pipe2 <= audio_in_pipe1;
            audio_in_pipe3 <= audio_in_pipe2;
        end
    end
    
    // Instantiate MAC16 wrapper
    // This performs: result = audio_in × GAIN
    // With accumulation reset on each new sample
    MAC16_wrapper_accum_drake mac_mult (
        .clk(clk),
        .reset(reset),
        .mac_rst(mac_reset),
        .ce(mac_ce),
        .a_in(audio_in),
        .b_in(GAIN),
        .result(mac_result)
    );
    
    // Extract Q2.14 result from Q4.28 MAC output
    // Q2.14 × Q2.14 = Q4.28, so we take bits [29:14] to get back to Q2.14
    // But the MAC output might be in a different format, so let's try [29:14]
    logic signed [15:0] mac_out_scaled;
    assign mac_out_scaled = mac_result[29:14];
    
    // Output assignment with simple passthrough initially to verify pipeline
    // Comment/uncomment to test different stages:
    
    // Option 1: Direct MAC output (use this for final operation)
    assign audio_out = mac_out_scaled;
    
    // Option 2: Bypass for comparison (uncomment to verify input is reaching this module)
    // assign audio_out = audio_in;
    
    // Option 3: Half the input without MAC (uncomment to verify arithmetic shift works)
    // assign audio_out = audio_in >>> 1;

endmodule