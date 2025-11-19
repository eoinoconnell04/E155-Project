/*
Author: Eoin O'Connell
Email: eoconnell@hmc.edu
Date: Nov. 19, 2025
Module Function: 16-bit biquad IIR filter rewritten to match 24-bit style

Coefficients: Q2.14 format
Inputs/outputs: 16-bit signed audio samples
*/
module iir_filter(
    input  logic        clk,
    input  logic        reset,
    input  logic signed [15:0] latest_sample,   // x[n]
    input  logic signed [15:0] b0, b1, b2, a1, a2,
    output logic signed [15:0] filtered_output  // y[n]
);

//    // ================================================================
//    // ===== SIMPLE UNITY GAIN TEST SECTION (copy of 24-bit style) =====
//    // ================================================================
//    /*
//    logic signed [31:0] unity_mult;
//    logic signed [15:0] unity_result;
//
//    // Multiply input by 1.0 in Q2.14 (1.0 = 16384 = 0x4000)
//    assign unity_mult = 16'sd16384 * latest_sample;
//
//    // 16Ãƒâ€”16 = 32-bit Ã¢â€ â€™ shift right by 14 bits to get back to 16-bit
//    // Bits [29:14] correspond to full-precision Q2.14 scaling
//    assign unity_result = unity_mult[29:14];
//
//    assign filtered_output = unity_result;
//    */
//    // ================================================================
//    // ====================== END UNITY GAIN TEST ======================
//    // ================================================================
//
///*
//    // ===== State registers =====
//    logic signed [15:0] x1, x2;
//    logic signed [15:0] y1, y2;
//
//    // ===== Multiply results (16Ãƒâ€”16=32 bits) =====
//    logic signed [31:0] b0_x0, b1_x1, b2_x2;
//    logic signed [31:0] a1_y1, a2_y2;
//
//    // ===== Accumulator =====
//    logic signed [31:0] acc, acc_next;
//
//    // ===== Compute products =====
//    assign b0_x0 = b0 * latest_sample;
//    assign b1_x1 = b1 * x1;
//    assign b2_x2 = b2 * x2;
//    assign a1_y1 = a1 * y1;
//    assign a2_y2 = a2 * y2; 
//	*/
//
//    // ===== Full accumulation =====
//    /*assign acc =  b0_x0
//                + b1_x1
//                + b2_x2
//                - a1_y1
//                - a2_y2;*/
//	assign acc = b0_x0 + b1_x1 + b2_x2 - a1_y1 - a2_y2;
//
//	
//	always_ff @(posedge clk) begin
//		b0_x0 <= b0 * latest_sample;
//		b1_x1 <= b1 * x1;
//		b2_x2 <= b2 * x2;
//		a1_y1 <= a1 * y1;
//		a2_y2 <= a2 * y2;
//		//acc <= b0_x0;// + b1_x1 + b2_x2 - a1_y1 - a2_y2;
//	end
//
//    // ===== Sequential state update =====
//    always_ff @(posedge clk or posedge reset) begin
//        if (reset) begin
//            x1 <= 16'sd0;
//            x2 <= 16'sd0;
//            y1 <= 16'sd0;
//            y2 <= 16'sd0;
//            filtered_output <= 16'sd0;
//
//        end else begin
//            // 32-bit accumulator Ã¢â€ â€™ Q2.14 output Ã¢â€ â€™ 16 bits
//            filtered_output <= acc[29:14];
//
//            // Shift input history
//            x2 <= x1;
//            x1 <= latest_sample;
//
//            // Shift output history
//            y2 <= y1;
//            y1 <= acc[29:14];
//        end
//    end
//
//
//
    logic signed [15:0] x1, x2, y1, y2;
    logic signed [31:0] b0_x0, b1_x1, b2_x2, a1_y1, a2_y2;
    logic signed [31:0] acc;

    // Stage 1: Register the products
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            b0_x0 <= 32'sd0;
            b1_x1 <= 32'sd0;
            b2_x2 <= 32'sd0;
            a1_y1 <= 32'sd0;
            a2_y2 <= 32'sd0;
        end else begin
            b0_x0 <= b0 * latest_sample;
            b1_x1 <= b1 * x1;
            b2_x2 <= b2 * x2;
            a1_y1 <= a1 * y1;
            a2_y2 <= a2 * y2;
        end
    end

    // Compute sum combinationally
    assign acc = b0_x0 + b1_x1 + b2_x2 - a1_y1 - a2_y2;

    // Stage 2: Register the result
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            x1 <= 16'sd0;
            x2 <= 16'sd0;
            y1 <= 16'sd0;
            y2 <= 16'sd0;
            filtered_output <= 16'sd0;
        end else begin
            filtered_output <= acc[29:14];
            x2 <= x1;
            x1 <= latest_sample;
            y2 <= y1;
            y1 <= acc[29:14];
        end
    end

endmodule



// Example MCU-side coefficient conversion (C code)
/*
#include <stdint.h>

// Convert floating-point coefficient to Q2.14 format
int16_t float_to_q2_14(float coeff) {
    // Clamp to valid range
    if (coeff > 1.9999) coeff = 1.9999;
    if (coeff < -2.0) coeff = -2.0;
    
    // Convert: multiply by 2^14 and round
    int32_t scaled = (int32_t)(coeff * 16384.0f + (coeff >= 0 ? 0.5f : -0.5f));
    return (int16_t)scaled;
}

// Example usage:
// float b0_float = 0.5;
// int16_t b0_q2_14 = float_to_q2_14(b0_float);  // Result: 0x2000 (8192)
// Send b0_q2_14 via SPI to FPGA

// Common coefficient examples in Q2.14:
//  1.0  -> 0x4000 (16384)
//  0.5  -> 0x2000 (8192)
// -1.0  -> 0xC000 (-16384)
//  2.0  -> 0x7FFF (32767, slightly less than 2.0)
// -2.0  -> 0x8000 (-32768)
*/