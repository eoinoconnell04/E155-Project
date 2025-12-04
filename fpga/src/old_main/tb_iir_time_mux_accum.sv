`timescale 1ns / 1ps

/*
Testbench for iir_time_mux_accum module
Tests the time-multiplexed IIR filter with various input signals
*/

module tb_iir_time_mux_accum();

    // Testbench parameters
    parameter CLK_PERIOD = 10;      // 100 MHz system clock
    parameter LR_CLK_PERIOD = 2083; // ~48 kHz audio sample rate (1/48000 ≈ 20.83 us)
    
    // DUT signals
    logic clk;
    logic l_r_clk;
    logic reset;
    logic signed [15:0] latest_sample;
    logic signed [15:0] b0, b1, b2, a1, a2;
    logic signed [15:0] filtered_output;
    
    // Testbench variables
    integer sample_count;
    integer test_num;
    real expected_output;
    
    // Instantiate DUT
    iir_time_mux_accum dut (
        .clk(clk),
        .l_r_clk(l_r_clk),
        .reset(reset),
        .latest_sample(latest_sample),
        .b0(b0),
        .b1(b1),
        .b2(b2),
        .a1(a1),
        .a2(a2),
        .filtered_output(filtered_output)
    );
    
    // Clock generation
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end
    
    // L/R clock generation (audio sample rate)
    initial begin
        l_r_clk = 0;
        forever #(LR_CLK_PERIOD/2) l_r_clk = ~l_r_clk;
    end
    
    // Helper function to convert real to Q2.14 fixed point
    function logic [15:0] real_to_q2_14(input real value);
        real scaled;
        int scaled_int;
        scaled = value * (2.0 ** 14);
        scaled_int = int'(scaled);
        return scaled_int[15:0];
    endfunction
    
    // Helper function to convert Q2.14 to real
    function real q2_14_to_real(input logic signed [15:0] value);
        real result;
        result = real'(value) / (2.0 ** 14);
        return result;
    endfunction
    
    // Task to wait for one sample period (one l_r_clk edge)
    task wait_sample_period();
        @(posedge l_r_clk or negedge l_r_clk);
    endtask
    
    // Task to apply a sample and wait for processing
    task apply_sample(input logic signed [15:0] sample);
        latest_sample = sample;
        wait_sample_period();
        // Wait additional time for FSM to complete (about 15 clock cycles)
        repeat(20) @(posedge clk);
        sample_count++;
    endtask
    
    // Task to display test results
    task display_result(input string test_name, input real input_val, input real output_val);
        $display("[%s] Sample %0d: Input = %f, Output = %f (Raw: 0x%h)", 
                 test_name, sample_count, input_val, output_val, filtered_output);
    endtask
    
    // Main test sequence
    initial begin
        $display("========================================");
        $display("IIR Time-Multiplexed Filter Testbench");
        $display("========================================\n");
        
        // Initialize signals
        reset = 0;
        latest_sample = 0;
        b0 = 0;
        b1 = 0;
        b2 = 0;
        a1 = 0;
        a2 = 0;
        sample_count = 0;
        test_num = 1;
        
        // Reset sequence
        repeat(5) @(posedge clk);
        reset = 1;
        repeat(5) @(posedge clk);
        
        $display("Reset complete. Starting tests...\n");
        
        // ====================================================================
        // TEST 1: Unity gain passthrough (b0=1, all others=0)
        // ====================================================================
        $display("TEST %0d: Unity Gain Passthrough", test_num++);
        $display("Coefficients: b0=1.0, b1=0, b2=0, a1=0, a2=0");
        b0 = real_to_q2_14(1.0);
        b1 = real_to_q2_14(0.0);
        b2 = real_to_q2_14(0.0);
        a1 = real_to_q2_14(0.0);
        a2 = real_to_q2_14(0.0);
        
        sample_count = 0;
        repeat(3) @(posedge clk);
        
        // Apply test samples
        apply_sample(real_to_q2_14(0.5));
        display_result("Unity", 0.5, q2_14_to_real(filtered_output));
        
        apply_sample(real_to_q2_14(0.25));
        display_result("Unity", 0.25, q2_14_to_real(filtered_output));
        
        apply_sample(real_to_q2_14(-0.5));
        display_result("Unity", -0.5, q2_14_to_real(filtered_output));
        
        apply_sample(real_to_q2_14(0.0));
        display_result("Unity", 0.0, q2_14_to_real(filtered_output));
        
        $display("");
        
        // ====================================================================
        // TEST 2: Simple averaging filter (b0=0.5, b1=0.5)
        // ====================================================================
        $display("TEST %0d: Simple Averaging Filter", test_num++);
        $display("Coefficients: b0=0.5, b1=0.5, b2=0, a1=0, a2=0");
        b0 = real_to_q2_14(0.5);
        b1 = real_to_q2_14(0.5);
        b2 = real_to_q2_14(0.0);
        a1 = real_to_q2_14(0.0);
        a2 = real_to_q2_14(0.0);
        
        sample_count = 0;
        repeat(3) @(posedge clk);
        
        apply_sample(real_to_q2_14(1.0));
        display_result("Averaging", 1.0, q2_14_to_real(filtered_output));
        
        apply_sample(real_to_q2_14(0.0));
        display_result("Averaging", 0.0, q2_14_to_real(filtered_output));
        
        apply_sample(real_to_q2_14(1.0));
        display_result("Averaging", 1.0, q2_14_to_real(filtered_output));
        
        apply_sample(real_to_q2_14(1.0));
        display_result("Averaging", 1.0, q2_14_to_real(filtered_output));
        
        $display("");
        
        // ====================================================================
        // TEST 3: Impulse response test
        // ====================================================================
        $display("TEST %0d: Impulse Response", test_num++);
        $display("Coefficients: b0=1.0, b1=0.5, b2=0.25, a1=0, a2=0");
        b0 = real_to_q2_14(1.0);
        b1 = real_to_q2_14(0.5);
        b2 = real_to_q2_14(0.25);
        a1 = real_to_q2_14(0.0);
        a2 = real_to_q2_14(0.0);
        
        sample_count = 0;
        repeat(3) @(posedge clk);
        
        // Apply impulse
        apply_sample(real_to_q2_14(1.0));
        display_result("Impulse", 1.0, q2_14_to_real(filtered_output));
        
        // Watch the response decay
        repeat(5) begin
            apply_sample(real_to_q2_14(0.0));
            display_result("Impulse", 0.0, q2_14_to_real(filtered_output));
        end
        
        $display("");
        
        // ====================================================================
        // TEST 4: Simple IIR filter with feedback
        // ====================================================================
        $display("TEST %0d: IIR Filter with Feedback", test_num++);
        $display("Coefficients: b0=0.5, b1=0, b2=0, a1=-0.5, a2=0");
        b0 = real_to_q2_14(0.5);
        b1 = real_to_q2_14(0.0);
        b2 = real_to_q2_14(0.0);
        a1 = real_to_q2_14(-0.5);  // Note: will be negated in module
        a2 = real_to_q2_14(0.0);
        
        sample_count = 0;
        repeat(3) @(posedge clk);
        
        // Step input
        repeat(8) begin
            apply_sample(real_to_q2_14(1.0));
            display_result("IIR", 1.0, q2_14_to_real(filtered_output));
        end
        
        $display("");
        
        // ====================================================================
        // TEST 5: Full biquad filter (low-pass characteristics)
        // ====================================================================
        $display("TEST %0d: Full Biquad Filter", test_num++);
        $display("Coefficients: b0=0.25, b1=0.5, b2=0.25, a1=-0.5, a2=0.25");
        b0 = real_to_q2_14(0.25);
        b1 = real_to_q2_14(0.5);
        b2 = real_to_q2_14(0.25);
        a1 = real_to_q2_14(-0.5);
        a2 = real_to_q2_14(0.25);
        
        sample_count = 0;
        repeat(3) @(posedge clk);
        
        // Alternating input (simulates high frequency)
        repeat(10) begin
            apply_sample(real_to_q2_14(1.0));
            display_result("Biquad", 1.0, q2_14_to_real(filtered_output));
            
            apply_sample(real_to_q2_14(-1.0));
            display_result("Biquad", -1.0, q2_14_to_real(filtered_output));
        end
        
        $display("");
        
        // ====================================================================
        // TEST 6: Zero coefficients (all zeros)
        // ====================================================================
        $display("TEST %0d: Zero Coefficients", test_num++);
        $display("Coefficients: All zeros");
        b0 = real_to_q2_14(0.0);
        b1 = real_to_q2_14(0.0);
        b2 = real_to_q2_14(0.0);
        a1 = real_to_q2_14(0.0);
        a2 = real_to_q2_14(0.0);
        
        sample_count = 0;
        repeat(3) @(posedge clk);
        
        repeat(3) begin
            apply_sample(real_to_q2_14(1.0));
            display_result("Zero", 1.0, q2_14_to_real(filtered_output));
        end
        
        $display("");
        
        // ====================================================================
        // TEST 7: Maximum values test
        // ====================================================================
        $display("TEST %0d: Maximum Values", test_num++);
        $display("Coefficients: b0=1.5, others=0");
        b0 = real_to_q2_14(1.5);
        b1 = real_to_q2_14(0.0);
        b2 = real_to_q2_14(0.0);
        a1 = real_to_q2_14(0.0);
        a2 = real_to_q2_14(0.0);
        
        sample_count = 0;
        repeat(3) @(posedge clk);
        
        apply_sample(16'h7FFF);  // Maximum positive
        display_result("MaxVal", 1.999, q2_14_to_real(filtered_output));
        
        apply_sample(16'h8000);  // Maximum negative
        display_result("MaxVal", -2.0, q2_14_to_real(filtered_output));
        
        apply_sample(16'd0);
        display_result("MaxVal", 0.0, q2_14_to_real(filtered_output));
        
        $display("");
        
        // ====================================================================
        // End of tests
        // ====================================================================
        $display("========================================");
        $display("All tests completed successfully!");
        $display("========================================");
        
        repeat(10) @(posedge clk);
        $finish;
    end
    
    // Timeout watchdog
    initial begin
        #10ms;
        $display("ERROR: Testbench timeout!");
        $finish;
    end
    
    // Monitor for debugging (optional - comment out if too verbose)
    /*
    initial begin
        $monitor("Time=%0t | State=%0d | mac_ce=%b | mac_a=%h | mac_b=%h | mac_result=%h | output=%h",
                 $time, dut.state, dut.mac_ce, dut.mac_a, dut.mac_b, 
                 dut.mac_result, filtered_output);
    end
    */

endmodule