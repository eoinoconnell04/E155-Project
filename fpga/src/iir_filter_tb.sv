`timescale 1ns/1ps

module iir_filter_tb;

    // Clock & reset
    logic clk;
    logic reset;

    // DUT I/O
    logic signed [15:0] latest_sample;
    logic signed [15:0] b0, b1, b2, a1, a2;
    logic signed [15:0] dut_out;

    // Instantiate Device Under Test
    iir_filter dut (
        .clk(clk),
        .reset(reset),
        .latest_sample(latest_sample),
        .b0(b0), .b1(b1), .b2(b2),
        .a1(a1), .a2(a2),
        .filtered_output(dut_out)
    );

    // Clock generation: 100 MHz
    always #5 clk = ~clk;

    // Reference model states (32-bit for accumulation)
    int signed x1, x2;    // previous inputs
    int signed y1, y2;    // previous outputs
    int signed acc;        // accumulator
    logic signed [15:0] expected_out;

    // Count test failures
    int fail_count;

    initial begin
        $display("Starting biquad IIR filter testbench...");

        clk = 0;
        reset = 1;
        fail_count = 0;

        // simple test coefficients
        b0 = 16'sd32768;  // 1.0
        b1 = 16'sd0;      // 0.0
        b2 = 16'sd0;      // 0.0
        a1 = 16'sd0;      // 0.0
        a2 = 16'sd0;      // 0.0

        // Example low-pass coefficients in Q1.15 format
        /*
        b0 = 16'sd1638;  // 0.05
        b1 = 16'sd3276;  // 0.10
        b2 = 16'sd1638;  // 0.05
        a1 = -16'sd29491; // -0.9
        a2 = 16'sd8192;   // 0.25
        */

        // Hold reset for a few cycles
        repeat (4) @(posedge clk);
        reset = 0;

        // Initialize reference model
        x1 = 0; x2 = 0;
        y1 = 0; y2 = 0;

        // Run test samples
        for (int n = 0; n < 1000; n++) begin
            // Generate random input in Q1.15 range
            latest_sample = $urandom_range(-20000, 20000);

            @(posedge clk); // DUT consumes input

            // --- Reference model calculation ---
            // Q1.15 fixed-point math:
            // multiply: 16-bit * 16-bit = 32-bit
            // sum: 32-bit accumulator
            // divide by 2^16 (>>16) to get Q1.15 output
            acc = (b0 * latest_sample)
                + (b1 * x1)
                + (b2 * x2)
                - (a1 * (y1 >>> 16))
                - (a2 * (y2 >>> 16));

            // Take high 16 bits as Q1.15 output
            expected_out = acc >>> 16;

            // Compare DUT output
            if (dut_out !== expected_out) begin
                fail_count++;
                $error("Sample %0d mismatch: Latest Sample: %0d DUT=%0d Expected=%0d Acc=%0d",
                       n, latest_sample, dut_out, expected_out, acc);
            end

            // Update reference states
            x2 = x1;
            x1 = latest_sample;
            y2 = y1;
            y1 = acc;
        end

        $display("Simulation completed!");
        $display("Failed tests: %0d / 1000", fail_count);
        $finish;
    end

endmodule
