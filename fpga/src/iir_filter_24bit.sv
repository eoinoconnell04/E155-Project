/*
Author: Eoin O'Connell
Email: eoconnell@hmc.edu
Date: Nov. 19, 2025
Module Function: 24-bit biquad IIR filter

Coefficients are in Q2.14 format (2 integer bits, 14 fractional bits).
Input/output are 24-bit signed audio samples.
*/
module iir_filter_24bit(
    input  logic        clk,
    input  logic        reset,
    input  logic signed [23:0] latest_sample,   // x[n] 24-bit signed input
    input  logic signed [15:0] b0, b1, b2, a1, a2, // coefficients, Q2.14 format
    output logic signed [23:0] filtered_output  // y[n] 24-bit signed output
);

	// ===== SIMPLE UNITY GAIN TEST SECTION =====
    // Uncomment this section to test basic Q2.14 multiplication
    /*
    logic signed [39:0] unity_mult;
    logic signed [23:0] unity_result;
    
    // Multiply by 1.0 in Q2.14 format (16384 = 0x4000 = 1.0)
    assign unity_mult = 16'sd16384 * latest_sample;
    
    // Shift right by 14 bits to account for Q2.14 format
    // 24-bit input × 16-bit coeff = 40-bit result
    // We want bits [37:14] to get back to 24-bit output
    assign unity_result = unity_mult[37:14];
    
    assign filtered_output = unity_result;
	
    */
    // ===== END SIMPLE UNITY GAIN TEST SECTION =====
	

    // Store previous input samples (x[n-1], x[n-2])
    logic signed [23:0] x1, x2;
    
    // Store previous output samples (y[n-1], y[n-2])
    logic signed [23:0] y1, y2;
    
    // Multiplication results (24-bit Ã— 16-bit = 40-bit)
    logic signed [39:0] b0_x0, b1_x1, b2_x2, a1_y1, a2_y2;
    
    // Accumulator for final result (needs to handle sum of 5 40-bit values)
    //logic signed [41:0] acc;
	logic signed [39:0] acc;
    
    // Compute multiplication products
    assign b0_x0 = b0 * latest_sample;
    assign b1_x1 = b1 * x1;
    assign b2_x2 = b2 * x2;
    assign a1_y1 = a1 * y1;
    assign a2_y2 = a2 * y2;
    
    // Accumulate: sum the products, then shift right by 14 bits for Q2.14
    // Cast to 42-bit for accumulation to prevent overflow
	/*
    assign acc = $signed({b0_x0[39], b0_x0}) + 
                 $signed({b1_x1[39], b1_x1}) + 
                 $signed({b2_x2[39], b2_x2}) - 
                 $signed({a1_y1[39], a1_y1}) - 
                 $signed({a2_y2[39], a2_y2});
				 */
	assign acc = b0_x0 + b1_x1 + b2_x2 - a1_y1 - a2_y2;
				 
    
    // Sequential logic for state updates
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            x1 <= 24'sd0;
            x2 <= 24'sd0;
            y1 <= 24'sd0;
            y2 <= 24'sd0;
            filtered_output <= 24'sd0;
        end else begin
            // Extract result with proper Q2.14 scaling (shift right 14 bits)
            // Take bits [37:14] from the 42-bit accumulator
            
			//filtered_output <= acc[39:16];
			filtered_output <= acc[37:14];
			//filtered_output <= b0_x0[37:14];
            
            // Shift input history
            x2 <= x1;
            x1 <= latest_sample;
            
            // Shift output history
            y2 <= y1;
            y1 <= acc[37:14];  // Use the new output value
        end
    end
	

endmodule