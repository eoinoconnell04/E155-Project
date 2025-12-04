/*
Author: Eoin O'Connell
Email: eoconnell@hmc.edu
Date: Nov. 19, 2025
Module Function: Audio processing top module with 16-bit IIR filter
Structure matches 24-bit version
*/
module audio_filter_top(
    input  logic clk,
    input  logic reset,
    input  logic signed [23:0] adc_data,    // 24-bit signed audio input
    output logic [31:0] dac_data            // DAC data (24-bit audio + 8-bit padding)
);

    // ===== Convert 24-bit input to 16-bit (top 16 bits) =====
    logic signed [15:0] audio_in;
    assign audio_in = adc_data[23:8];

    // ===== Filtered audio output (16-bit) =====
    logic signed [15:0] audio_out;

    // ===== Convert 16-bit output back to 24-bit for DAC =====
    logic signed [23:0] audio_out_24;
    assign audio_out_24 = {audio_out, 8'h00};  // shift left 8 bits

    // ===== Pack into DAC data: top 8 bits zero, bottom 24 bits audio =====
    assign dac_data = {8'd0, audio_out_24};

    // ===== Filter coefficients in Q2.14 format =====
    logic signed [15:0] b0, b1, b2, a1, a2;
/*
    // ===== Unity gain passthrough (1.0) for testing =====
    assign b0 = 16'sd16384;   // 1.0
    assign b1 = 16'sd0;       // 0.0
    assign b2 = 16'sd0;       // 0.0
    assign a1 = 16'sd0;       // 0.0
    assign a2 = 16'sd0;       // 0.0 
	*/
	/*
	// ===== 2 nonzero =====
    assign b0 = 16'sd16384;   // 1.0
    assign a1 = -16'sd8192;       // -0.5
    assign b2 = 16'sd0;       // 0.0
    assign b1 = 16'sd0;       // 0.0
    assign a2 = 16'sd0;       // 0.0 
*/
    // ===== Active filter coefficients (example) =====
    
    assign b0 = 16'sd15871;   // 0.9676 * 16384 â‰ˆ 15871
    assign b1 = -16'sd30917;  // -1.8868 * 16384 â‰ˆ -30917
    assign b2 = 16'sd15106;   // 0.9221 * 16384 â‰ˆ 15106
    assign a1 = -16'sd30906;  // -1.8861 * 16384 â‰ˆ -30906
    assign a2 = 16'sd14618;   // 0.8922 * 16384 â‰ˆ 14618
    

    // ===== Instantiate 16-bit IIR filter =====
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
