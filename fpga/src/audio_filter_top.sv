/*
Author: Eoin O'Connell
Email: eoconnell@hmc.edu
Date: Nov. 19, 2025
Module Function: Audio processing top module with IIR filter
Currently uses static coefficients for testing
*/

module audio_filter_top(
    input  logic clk,
    input  logic reset,
    input  logic [31:0] adc_data,    // ADC data (use top 16 bits as signed audio)
    output logic [31:0] dac_data     // DAC data (top 16 bits = filtered audio, bottom 16 = 0)
);

    // Extract top 16 bits from ADC as signed audio sample
    logic signed [15:0] audio_in;
    assign audio_in = $signed(adc_data[31:16]);
    
    // Filtered audio output
    logic signed [15:0] audio_out;
    
    // Pack filtered audio into top 16 bits of DAC data, zero-pad bottom 16 bits
    assign dac_data = {audio_out, 16'h0000};
    
    // Filter coefficients in Q2.14 format
    logic signed [15:0] b0, b1, b2, a1, a2;
    
    // Active filter coefficients (Bandpass or similar)
    // b = [0.9676, -1.8868, 0.9221]
    // a = [1.0000, -1.8861, 0.8922]
    // Note: a0 is always 1.0 and not used in the biquad implementation
    assign b0 = 16'sd15871;   // 0.9676 * 16384 ≈ 15871
    assign b1 = -16'sd30917;  // -1.8868 * 16384 ≈ -30917
    assign b2 = 16'sd15106;   // 0.9221 * 16384 ≈ 15106
    assign a1 = -16'sd30906;  // -1.8861 * 16384 ≈ -30906
    assign a2 = 16'sd14618;   // 0.8922 * 16384 ≈ 14618
    
    // Unity gain passthrough for testing (uncomment to use)
    // assign b0 = 16'sd16384;   // 1.0
    // assign b1 = 16'sd0;       // 0.0
    // assign b2 = 16'sd0;       // 0.0
    // assign a1 = 16'sd0;       // 0.0
    // assign a2 = 16'sd0;       // 0.0
    
    // Instantiate IIR filter
    iir_filter filter_inst (
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