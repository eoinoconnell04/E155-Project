`timescale 1ns/1ps

module iir_filter_tb;

    // Clock & reset
    logic clk;
    logic reset;

    // DUT I/O
    logic [15:0] latest_sample;
    logic [15:0] b0, b1, b2, a1, a2;
    logic [15:0] dut_out;

    // Instantiate Device Under Test
    iir_filter dut (
        .clk(clk),
        .reset(reset),
        .latest_sample(latest_sample),
        .b0(b0), .b1(b1), .b2(b2),
        .a1(a1), .a2(a2),
        .filtered_output(dut_out)
    );

    // Clock generation
    always #5 clk = ~clk;   // 100 MHz

    // Reference model states
    int signed x1, x2;
    int signed y1, y2;

    // Expected output
    int signed acc;
    logic signed [15:0] expected_out;

    initial begin
        $display("Starting biquad IIR filter testbench...");

        clk = 0;
        reset = 1;

        // Low-pass example
        b0 = 16'sd1638; // 0.05 in Q15
        b1 = 16'sd3276; // 0.10
        b2 = 16'sd1638; // 0.05
        a1 = -16'sd29491; // -0.9 in Q15
        a2 = 16'sd8192;   // 0.25 in Q15

        // Hold reset for a few cycles
        repeat (4) @(posedge clk);
        reset = 0;

        // Initialize reference model states
        x1 = 0;  x2 = 0;
        y1 = 0;  y2 = 0;

        // Run 1000 test samples
        for (int n = 0; n < 1000; n++) begin
            // Generate a random input sample
            latest_sample = $urandom_range(-20000, 20000);

            // Wait for rising edge so DUT consumes latest_sample
            @(posedge clk);

            //
            // --- Reference biquad computation ---
            //
            acc = (b0 * $signed(latest_sample))
                + (b1 * x1)
                + (b2 * x2)
                - (a1 * (y1 >>> 16))   // feedback uses upper 16 bits
                - (a2 * (y2 >>> 16));

            expected_out = acc >>> 16;

            // Check result
            if (dut_out !== expected_out) begin
                $error("Mismatch at sample %0d: DUT=%0d Expected=%0d  acc=%0d",
                       n, dut_out, expected_out, acc);
            end

            //
            // --- Update software model history ---
            //
            x2 = x1;
            x1 = $signed(latest_sample);
            y2 = y1;
            y1 = acc;

        end

        $display("Simulation completed!");
        $finish;
    end

endmodule
