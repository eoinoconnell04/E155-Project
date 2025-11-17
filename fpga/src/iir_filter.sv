/*
Author: Eoin O'Connell
Email: eoconnell@hmc.edu
Date: Nov. 13, 2025
Module Function: This is a module that implements a single biquad IIR filter. This will be instantiated 3 times in the final design to support low, mid, and high independent filtering.
*/
module iir_filter(
    input  logic        clk,
    input  logic        reset,
    input  logic signed [15:0] latest_sample,   // x[n]
    input  logic signed [15:0] b0, b1, b2, a1, a2,
    output logic signed [15:0] filtered_output  // y[n]
);

    // Store previous input samples (x[n-1], x[n-2])
    logic signed [15:0] x1, x2;

    // Store previous output samples (y[n-1], y[n-2])
    logic signed [31:0] y1, y2; // wider to prevent overflow

    // Intermediate result (use wider width for accumulation)
    logic signed [31:0] acc;

    // Compute filter output
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            x1 <= 16'sd0;
            x2 <= 16'sd0;
            y1 <= 32'sd0;
            y2 <= 32'sd0;
            filtered_output <= 16'sd0;
        end else begin
            // Perform the biquad calculation with signed math
            acc = ($signed(b0) * $signed(latest_sample))
                + ($signed(b1) * $signed(x1))
                + ($signed(b2) * $signed(x2))
                - ($signed(a1) * $signed(y1[31:16]))
                - ($signed(a2) * $signed(y2[31:16]));


            // Update output
            filtered_output <= acc[31:16]; // take high 16 bits as output

            // Shift for next sample
            x2 <= x1;
            x1 <= latest_sample;
            y2 <= y1;
            y1 <= acc;
        end
    end

endmodule
