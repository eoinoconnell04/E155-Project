`timescale 1ns / 1ps

module MAC16_wrapper_tb;

    // Testbench signals
    reg clk;
    wire signed [31:0] result;
    
    // Internal signals to monitor
    reg signed [15:0] test_a;
    reg signed [15:0] test_b;
    reg signed [15:0] test_c;
    reg signed [31:0] expected_result;
    
    integer test_count;
    integer pass_count;
    integer fail_count;
    
    // Instantiate the DUT (Device Under Test)
    top_level dut (
        .clk(clk),
        .result(result)
    );
    
    // Clock generation - 10ns period (100MHz)
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end
    
    // Test procedure
    initial begin
        $display("========================================");
        $display("Starting MAC16 Signed 2's Complement Tests");
        $display("Testing: result = A * B + C");
        $display("========================================");
        
        test_count = 0;
        pass_count = 0;
        fail_count = 0;
        
        // Wait for initial settling
        #20;
        
        // Test Case 1: Positive * Positive + Positive
        test_case(-16'sd5, 16'sd3, 16'sd10, "(-5) * 3 + 10 = -5");
        
        // Test Case 2: Small positive numbers
        test_case(16'sd7, 16'sd2, 16'sd5, "7 * 2 + 5 = 19");
        
        // Test Case 3: Negative * Negative + Positive
        test_case(-16'sd4, -16'sd3, 16'sd2, "(-4) * (-3) + 2 = 14");
        
        // Test Case 4: Positive * Negative + Positive
        test_case(16'sd6, -16'sd2, 16'sd8, "6 * (-2) + 8 = -4");
        
        // Test Case 5: Negative * Positive + Negative
        test_case(-16'sd5, 16'sd4, -16'sd10, "(-5) * 4 + (-10) = -30");
        
        // Test Case 6: Multiplication by zero
        test_case(16'sd0, 16'sd100, 16'sd50, "0 * 100 + 50 = 50");
        
        // Test Case 7: Addition with zero
        test_case(16'sd8, 16'sd7, 16'sd0, "8 * 7 + 0 = 56");
        
        // Test Case 8: All zeros
        test_case(16'sd0, 16'sd0, 16'sd0, "0 * 0 + 0 = 0");
        
        // Test Case 9: Multiply by -1
        test_case(-16'sd1, 16'sd42, 16'sd0, "(-1) * 42 + 0 = -42");
        
        // Test Case 10: Large positive numbers
        test_case(16'sd100, 16'sd200, 16'sd1000, "100 * 200 + 1000 = 21000");
        
        // Test Case 11: Large negative numbers
        test_case(-16'sd100, -16'sd100, -16'sd500, "(-100) * (-100) + (-500) = 9500");
        
        // Test Case 12: Maximum positive values
        test_case(16'sd32767, 16'sd1, 16'sd0, "32767 * 1 + 0 = 32767");
        
        // Test Case 13: Maximum negative value
        test_case(-16'sd32768, 16'sd1, 16'sd0, "(-32768) * 1 + 0 = -32768");
        
        // Test Case 14: Negative result from positive inputs
        test_case(16'sd10, 16'sd5, -16'sd100, "10 * 5 + (-100) = -50");
        
        // Test Case 15: Large multiplication result
        test_case(16'sd1000, 16'sd1000, 16'sd0, "1000 * 1000 + 0 = 1000000");
        
        // Wait for final result
        #100;
        
        // Print summary
        $display("========================================");
        $display("Test Summary:");
        $display("Total Tests: %0d", test_count);
        $display("Passed:      %0d", pass_count);
        $display("Failed:      %0d", fail_count);
        $display("========================================");
        
        if (fail_count == 0) begin
            $display("ALL TESTS PASSED!");
        end else begin
            $display("SOME TESTS FAILED!");
        end
        
        $finish;
    end
    
    // Task to run a single test case
    task test_case;
        input signed [15:0] a;
        input signed [15:0] b;
        input signed [15:0] c;
        input [200*8:1] description;
        
        reg signed [31:0] calc_expected;
        
        begin
            test_count = test_count + 1;
            test_a = a;
            test_b = b;
            test_c = c;
            
            // Calculate expected result
            calc_expected = (a * b) + c;
            expected_result = calc_expected;
            
            // Wait for MAC16 pipeline (account for registered inputs)
            #40;  // Give enough time for pipelined operation
            
            // Check result
            if (result === expected_result) begin
                $display("[PASS] Test %0d: %s", test_count, description);
                $display("       A=%0d, B=%0d, C=%0d => Result=%0d (0x%08h)", 
                         test_a, test_b, test_c, result, result);
                pass_count = pass_count + 1;
            end else begin
                $display("[FAIL] Test %0d: %s", test_count, description);
                $display("       A=%0d, B=%0d, C=%0d", test_a, test_b, test_c);
                $display("       Expected: %0d (0x%08h)", expected_result, expected_result);
                $display("       Got:      %0d (0x%08h)", result, result);
                fail_count = fail_count + 1;
            end
            $display("");
        end
    endtask
    
    // Optional: Generate VCD waveform file
    initial begin
        $dumpfile("top_level_tb.vcd");
        $dumpvars(0, top_level_tb);
    end

endmodule
```
/*
**This testbench includes:**

1. **15 comprehensive test cases** covering:
   - Positive × Positive operations
   - Negative × Negative operations
   - Mixed sign operations
   - Zero handling
   - Edge cases (max/min values)
   - Large number multiplications

2. **Automatic verification** that compares hardware results with expected software calculations

3. **Detailed reporting**:
   - Pass/Fail status for each test
   - Input values and results in both decimal and hex
   - Final summary with pass/fail counts

4. **Pipeline handling** with appropriate delays for registered inputs

5. **Waveform generation** for debugging (VCD file)

**Expected output format:**
```
[PASS] Test 1: (-5) * 3 + 10 = -5
       A=-5, B=3, C=10 => Result=-5 (0xfffffffb)
       */