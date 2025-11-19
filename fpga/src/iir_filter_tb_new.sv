/*
Testbench for IIR Biquad Filter
Tests basic functionality with simple coefficients and impulse/step responses
*/

module iir_filter_tb_new();

    // Clock and reset
    logic clk;
    logic reset;
    
    // DUT signals
    logic signed [15:0] latest_sample;
    logic signed [15:0] b0, b1, b2, a1, a2;
    logic signed [15:0] filtered_output;
    
    // Testbench variables
    integer i;
    real output_real;
    
    // Instantiate DUT
    iir_filter dut (
        .clk(clk),
        .reset(reset),
        .latest_sample(latest_sample),
        .b0(b0),
        .b1(b1),
        .b2(b2),
        .a1(a1),
        .a2(a2),
        .filtered_output(filtered_output)
    );
    
    // Clock generation (48 kHz sample rate = ~20.8 us period)
    initial begin
        clk = 0;
        forever #10 clk = ~clk;  // 50 MHz clock for simplicity
    end
    
    // Helper function to convert float to Q2.14
    function signed [15:0] float_to_q2_14(real value);
        real clamped;
        clamped = (value > 1.9999) ? 1.9999 : value;
        clamped = (clamped < -2.0) ? -2.0 : clamped;
        float_to_q2_14 = $rtoi(clamped * 16384.0);
    endfunction
    
    // Helper function to convert Q2.14 to float for display
    function real q2_14_to_float(logic signed [15:0] value);
        q2_14_to_float = $itor(value) / 16384.0;
    endfunction
    
    // Test stimulus
    initial begin
        // Initialize
        reset = 1;
        latest_sample = 0;
        b0 = 0;
        b1 = 0;
        b2 = 0;
        a1 = 0;
        a2 = 0;
        
        // Hold reset
        repeat(5) @(posedge clk);
        reset = 0;
        @(posedge clk);
        
        $display("\n=== IIR Filter Testbench ===\n");
        
        // Test 1: Unity gain passthrough (b0=1.0, all others=0)
        $display("Test 1: Unity Gain Passthrough");
        $display("Coefficients: b0=1.0, b1=0, b2=0, a1=0, a2=0");
        b0 = float_to_q2_14(1.0);
        b1 = 16'sd0;
        b2 = 16'sd0;
        a1 = 16'sd0;
        a2 = 16'sd0;
        
        // Send a few samples
        latest_sample = 16'sd1000;
        @(posedge clk);
        @(posedge clk);
        output_real = q2_14_to_float(filtered_output);
        $display("Input: 1000, Output: %d (%.3f expected ~1000)", filtered_output, output_real);
        
        latest_sample = 16'sd5000;
        @(posedge clk);
        @(posedge clk);
        output_real = q2_14_to_float(filtered_output);
        $display("Input: 5000, Output: %d (%.3f expected ~5000)", filtered_output, output_real);
        
        latest_sample = -16'sd2000;
        @(posedge clk);
        @(posedge clk);
        output_real = q2_14_to_float(filtered_output);
        $display("Input: -2000, Output: %d (%.3f expected ~-2000)\n", filtered_output, output_real);
        
        // Reset for next test
        reset = 1;
        @(posedge clk);
        reset = 0;
        @(posedge clk);
        
        // Test 2: Simple averaging filter (b0=0.5, b1=0.5)
        $display("Test 2: Simple Averaging Filter");
        $display("Coefficients: b0=0.5, b1=0.5, b2=0, a1=0, a2=0");
        b0 = float_to_q2_14(0.5);
        b1 = float_to_q2_14(0.5);
        b2 = 16'sd0;
        a1 = 16'sd0;
        a2 = 16'sd0;
        
        latest_sample = 16'sd1000;
        @(posedge clk);
        @(posedge clk);
        $display("Sample 1 - Input: 1000, Output: %d (expected ~500)", filtered_output);
        
        latest_sample = 16'sd1000;
        @(posedge clk);
        @(posedge clk);
        $display("Sample 2 - Input: 1000, Output: %d (expected ~1000)", filtered_output);
        
        latest_sample = 16'sd2000;
        @(posedge clk);
        @(posedge clk);
        $display("Sample 3 - Input: 2000, Output: %d (expected ~1500)\n", filtered_output);
        
        // Reset for next test
        reset = 1;
        @(posedge clk);
        reset = 0;
        @(posedge clk);
        
        // Test 3: Impulse response test
        $display("Test 3: Impulse Response");
        $display("Coefficients: b0=1.0, b1=0, b2=0, a1=0, a2=0");
        b0 = float_to_q2_14(1.0);
        b1 = 16'sd0;
        b2 = 16'sd0;
        a1 = 16'sd0;
        a2 = 16'sd0;
        
        // Send impulse (single non-zero sample)
        latest_sample = 16'sd10000;
        @(posedge clk);
        @(posedge clk);
        $display("Impulse: Input: 10000, Output: %d", filtered_output);
        
        // Send zeros
        for (i = 0; i < 5; i = i + 1) begin
            latest_sample = 16'sd0;
            @(posedge clk);
            @(posedge clk);
            $display("After impulse [%0d]: Input: 0, Output: %d", i, filtered_output);
        end
        
        $display("\n");
        
        // Reset for next test
        reset = 1;
        @(posedge clk);
        reset = 0;
        @(posedge clk);
        
        // Test 4: Simple lowpass with feedback (resonant filter example)
        $display("Test 4: Simple IIR with Feedback");
        $display("Coefficients: b0=0.1, b1=0, b2=0, a1=-0.9, a2=0");
        b0 = float_to_q2_14(0.1);
        b1 = 16'sd0;
        b2 = 16'sd0;
        a1 = float_to_q2_14(-0.9);  // Note: negative a1 in equation becomes positive feedback
        a2 = 16'sd0;
        
        // Step input
        latest_sample = 16'sd10000;
        for (i = 0; i < 10; i = i + 1) begin
            @(posedge clk);
            @(posedge clk);
            $display("Step response [%0d]: Output: %d", i, filtered_output);
        end
        
        $display("\n");
        
        // Test 5: Coefficient range test
        $display("Test 5: Coefficient Range Test");
        reset = 1;
        @(posedge clk);
        reset = 0;
        @(posedge clk);
        
        // Test with coefficient = 2.0 (max positive)
        b0 = float_to_q2_14(1.9999);
        b1 = 16'sd0;
        b2 = 16'sd0;
        a1 = 16'sd0;
        a2 = 16'sd0;
        
        latest_sample = 16'sd1000;
        @(posedge clk);
        @(posedge clk);
        $display("Max coefficient (~2.0): Input: 1000, Output: %d (expected ~2000)", filtered_output);
        
        // Test with coefficient = -2.0 (max negative)
        b0 = float_to_q2_14(-2.0);
        reset = 1;
        @(posedge clk);
        reset = 0;
        @(posedge clk);
        
        latest_sample = 16'sd1000;
        @(posedge clk);
        @(posedge clk);
        $display("Min coefficient (-2.0): Input: 1000, Output: %d (expected ~-2000)\n", filtered_output);
        
        // Finish simulation
        $display("=== All Tests Complete ===\n");
        $finish;
    end
    
    // Optional: Dump waveforms
    initial begin
        $dumpfile("iir_filter_tb.vcd");
        $dumpvars(0, iir_filter_tb);
    end

endmodule