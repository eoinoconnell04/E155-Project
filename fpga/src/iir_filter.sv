/*
Author: Eoin O'Connell
Email: eoconnell@hmc.edu
Date: Nov. 13, 2025
Module Function: This is a module that implements a single biquad IIR filter. 
This will be instantiated 3 times in the final design to support low, mid, 
and high independent filtering.

Coefficients are in Q2.14 format (2 integer bits, 14 fractional bits).
Range: -2 to ~+2, Resolution: 2^-14 ≈ 0.000061
*/
module iir_filter(
    input  logic        clk,
    input  logic        reset,
    input  logic signed [15:0] latest_sample,   // x[n] 16 bit signed input
    input  logic signed [15:0] b0, b1, b2, a1, a2, // coefficients, Q2.14 format
    output logic signed [15:0] filtered_output  // y[n] 16 bit signed output
);

    // Store previous input samples (x[n-1], x[n-2])
    logic signed [15:0] x1, x2;
    
    // Store previous output samples (y[n-1], y[n-2])
    logic signed [15:0] y1, y2;
    
    // Multiplication results (16-bit × 16-bit = 32-bit)
    logic signed [31:0] b0_x0, b1_x1, b2_x2, a1_y1, a2_y2;
    
    // Accumulator for final result
    logic signed [31:0] acc;
    
    // Compute multiplication products
    assign b0_x0 = b0 * latest_sample;
    assign b1_x1 = b1 * x1;
    assign b2_x2 = b2 * x2;
    assign a1_y1 = a1 * y1;
    assign a2_y2 = a2 * y2;
    
    // Accumulate: sum the products, then shift right by 14 bits for Q2.14
    assign acc = (b0_x0 + b1_x1 + b2_x2 - a1_y1 - a2_y2);
    
    // Sequential logic for state updates
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            x1 <= 16'sd0;
            x2 <= 16'sd0;
            y1 <= 16'sd0;
            y2 <= 16'sd0;
            filtered_output <= 16'sd0;
        end else begin
            // Extract result with proper Q2.14 scaling (shift right 14 bits)
            filtered_output <= acc[29:14];
            
            // Shift input history
            x2 <= x1;
            x1 <= latest_sample;
            
            // Shift output history
            y2 <= y1;
            y1 <= acc[29:14];  // Use the new output value
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