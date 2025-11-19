/*
Author: Eoin O'Connell
Email: eoconnell@hmc.edu
Date: Nov. 19, 2025
Module Function: Testbench for audio_filter_top module (16-bit IIR filter)
Tests unity gain passthrough with various audio input patterns
*/

`timescale 1ns/1ps

module audio_filter_top_tb;

    // Clock and reset
    logic clk;
    logic reset;
    
    // Audio signals
    logic signed [23:0] adc_data;
    logic [31:0] dac_data;
    
    // Expected output for comparison
    logic signed [23:0] expected_output;
    
    // Instantiate DUT (Device Under Test)
    audio_filter_top dut (
        .clk(clk),
        .reset(reset),
        .adc_data(adc_data),
        .dac_data(dac_data)
    );
    
    // Clock generation: 100 MHz (10ns period)
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end
    
    // Test stimulus
    initial begin
        // Initialize waveform dump
        $dumpfile("audio_filter_top_tb.vcd");
        $dumpvars(0, audio_filter_top_tb);
        
        // Initialize signals
        reset = 1;
        adc_data = 24'sd0;
        
        // Hold reset for a few cycles
        repeat(5) @(posedge clk);
        reset = 0;
        @(posedge clk);
        
        $display("=== Unity Gain Filter Test ===");
        $display("Time\t\tADC Input\tDAC Output\tExpected\tMatch");
        $display("----\t\t---------\t----------\t--------\t-----");
        
        // Wait a few cycles for filter to stabilize
        repeat(3) @(posedge clk);
        
        // Test 1: Zero input
        test_sample(24'sd0, "Zero");
        
        // Test 2: Small positive value
        test_sample(24'sd1000, "Small Positive");
        
        // Test 3: Small negative value
        test_sample(-24'sd1000, "Small Negative");
        
        // Test 4: Mid-range positive
        test_sample(24'sd1000000, "Mid Positive");
        
        // Test 5: Mid-range negative
        test_sample(-24'sd1000000, "Mid Negative");
        
        // Test 6: Large positive (near max)
        test_sample(24'sd8000000, "Large Positive");
        
        // Test 7: Large negative
        test_sample(-24'sd8000000, "Large Negative");
        
        // Test 8: Maximum positive value
        test_sample(24'sd8388607, "Max Positive");
        
        // Test 9: Maximum negative value
        test_sample(-24'sd8388608, "Max Negative");
        
        // Test 10: Alternating pattern
        $display("\n=== Alternating Pattern Test ===");
        repeat(10) begin
            test_sample(24'sd5000000, "High");
            test_sample(-24'sd5000000, "Low");
        end
        
        // Test 11: Sine-like pattern
        $display("\n=== Sine-like Pattern Test ===");
        for (int i = 0; i < 32; i++) begin
            real angle;
            real sine_val;
            logic signed [23:0] sample;
            
            angle = (i * 3.14159 * 2.0) / 32.0;
            sine_val = $sin(angle);
            sample = $rtoi(sine_val * 8000000);
            test_sample(sample, "Sine");
        end
        
        // Test 12: Step response
        $display("\n=== Step Response Test ===");
        test_sample(24'sd0, "Before Step");
        test_sample(24'sd4000000, "Step Up");
        repeat(5) test_sample(24'sd4000000, "Hold High");
        test_sample(24'sd0, "Step Down");
        repeat(5) test_sample(24'sd0, "Hold Low");
        
        // Finish simulation
        repeat(10) @(posedge clk);
        $display("\n=== Test Complete ===");
        $finish;
    end
    
    // Task to test a single sample
    task test_sample(input logic signed [23:0] input_val, input string description);
        logic signed [23:0] actual_output;
        logic signed [15:0] input_16bit;
        logic signed [23:0] expected_24bit;
        logic match;
        
        // Apply input
        adc_data = input_val;
        
        // Wait for two clock cycles (account for pipeline delay)
        @(posedge clk);
        @(posedge clk);
        
        // Extract actual 24-bit output from DAC data (bottom 24 bits)
        actual_output = dac_data[23:0];
        
        // Calculate expected output:
        // 1. Convert 24-bit input to 16-bit (top 16 bits)
        input_16bit = input_val[23:8];
        // 2. Unity gain means output should equal input (in 16-bit domain)
        // 3. Convert back to 24-bit (shift left 8 bits)
        expected_24bit = {input_16bit, 8'h00};
        
        // Check if outputs match (allow small tolerance due to pipeline delays)
        match = (actual_output == expected_24bit);
        
        // Display results
        $display("%0t\t%d\t%d\t%d\t%s - %s", 
                 $time, input_val, actual_output, expected_24bit, 
                 match ? "PASS" : "FAIL", description);
        
        // Assert on failure
        if (!match) begin
            $display("ERROR: Mismatch detected!");
            $display("  Input (24-bit): %d (0x%06h)", input_val, input_val);
            $display("  Input (16-bit): %d (0x%04h)", input_16bit, input_16bit);
            $display("  Expected: %d (0x%06h)", expected_24bit, expected_24bit);
            $display("  Actual:   %d (0x%06h)", actual_output, actual_output);
        end
    endtask
    
    // Monitor for continuous observation
    initial begin
        // Wait for reset to complete
        @(negedge reset);
        
        // Monitor signals continuously
        $monitor("Time=%0t | ADC=%d | DAC[23:0]=%d | Top8bits=%h", 
                 $time, adc_data, dac_data[23:0], dac_data[31:24]);
    end
    
    // Timeout watchdog
    initial begin
        #100000; // 100 microseconds
        $display("ERROR: Simulation timeout!");
        $finish;
    end

endmodule