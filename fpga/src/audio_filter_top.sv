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
    input  logic signed [23:0] adc_data,    // 24-bit signed audio input
    output logic [31:0] dac_data            // DAC data (24-bit audio + 8-bit padding)
);
    logic signed [23:0] temp;
    
    always_ff @(posedge clk) begin
        temp <= adc_data;
    end 
    
    // Convert 24-bit to 16-bit by taking the top 16 bits (arithmetic right shift by 8)
    logic signed [15:0] audio_in;
    assign audio_in = temp[23:8];  // Take top 16 bits of 24-bit sample
    
    // Filtered audio output (16-bit)
    logic signed [15:0] audio_out;
    
    // Convert 16-bit output back to 24-bit by left-shifting 8 bits, then pack into 32-bit DAC format
    logic signed [23:0] audio_out_24;
    assign audio_out_24 = {audio_out, 8'h00};  // Shift left by 8 bits
    
    // Pack filtered audio into bottom 24 bits of DAC data, zero-pad top 8 bits
    assign dac_data = {8'd0, audio_out_24};
    
    // Filter coefficients in Q2.14 format
    logic signed [15:0] b0, b1, b2, a1, a2;
    
    // Active filter coefficients (Bandpass or similar)
    // b = [0.9676, -1.8868, 0.9221]
    // a = [1.0000, -1.8861, 0.8922]
    // Note: a0 is always 1.0 and not used in the biquad implementation
	/*
    assign b0 = 16'sd15871;   // 0.9676 * 16384 â‰ˆ 15871
    assign b1 = -16'sd30917;  // -1.8868 * 16384 â‰ˆ -30917
    assign b2 = 16'sd15106;   // 0.9221 * 16384 â‰ˆ 15106
    assign a1 = -16'sd30906;  // -1.8861 * 16384 â‰ˆ -30906
    assign a2 = 16'sd14618;   // 0.8922 * 16384 â‰ˆ 14618
	*/
    
    // Unity gain passthrough for testing (uncomment to use)
    
    assign b0 = 16'sd16384;   // 1.0
    assign b1 = 16'sd0;       // 0.0
    assign b2 = 16'sd0;       // 0.0
    assign a1 = 16'sd0;       // 0.0
    assign a2 = 16'sd0;       // 0.0
    
    
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