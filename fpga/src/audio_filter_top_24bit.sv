/*
Author: Eoin O'Connell
Email: eoconnell@hmc.edu
Date: Nov. 19, 2025
Module Function: Audio processing top module with 24-bit IIR filter
*/
module audio_filter_top_24bit(
    input  logic clk,
    input  logic reset,
    input  logic signed [23:0] adc_data,    // 24-bit signed audio input
    output logic [31:0] dac_data            // DAC data (24-bit audio + 8-bit padding)
);
    logic signed [23:0] temp;
    
    always_ff @(posedge clk) begin
        temp <= adc_data;
    end 
    
    // Use full 24-bit signed audio sample
    logic signed [23:0] audio_in;
    assign audio_in = temp;
    
    // Filtered audio output (24-bit)
    logic signed [23:0] audio_out;
    
    // Pack filtered audio into bottom 24 bits of DAC data, zero-pad top 8 bits
    assign dac_data = {8'h00, audio_out};
    
    // Filter coefficients in Q2.14 format
    logic signed [15:0] b0, b1, b2, a1, a2;
    
    // Unity gain passthrough for testing - USE THIS FIRST TO DEBUG
    assign b0 = 16'sd16384;   // 1.0
    assign b1 = 16'sd0;       // 0.0
    assign b2 = 16'sd0;       // 0.0
    assign a1 = 16'sd0;       // 0.0
    assign a2 = 16'sd0;       // 0.0
    
    // Active filter coefficients (Bandpass or similar) - COMMENTED OUT FOR NOW
    // b = [0.9676, -1.8868, 0.9221]
    // a = [1.0000, -1.8861, 0.8922]
    // Note: a0 is always 1.0 and not used in the biquad implementation
    /*
    assign b0 = 16'sd15871;   // 0.9676 * 16384 ≈ 15871
    assign b1 = -16'sd30917;  // -1.8868 * 16384 ≈ -30917
    assign b2 = 16'sd15106;   // 0.9221 * 16384 ≈ 15106
    assign a1 = -16'sd30906;  // -1.8861 * 16384 ≈ -30906
    assign a2 = 16'sd14618;   // 0.8922 * 16384 ≈ 14618
    */
    
    // Instantiate 24-bit IIR filter
    iir_filter_24bit filter_inst (
        .clk(clk),
        .reset(reset),
        .latest_sample(audio_in),
        .b0(b0),
        .b1(b1),
        .b2(b2),
        .a1(a1),
        .a2(a2),
        .filtered_output(audio_out)
    );
endmodule