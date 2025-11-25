`timescale 1ns / 1ps

module MAC16_wrapper_tb;

    // Testbench signals
    reg clk;
    reg signed [15:0] a_in;
    reg signed [15:0] b_in;
    reg signed [15:0] c_in;
    wire signed [31:0] result;
    
    reg signed [31:0] expected_result;
    
    integer test_count;
    integer pass_count;
    integer fail_count;
    
    // Instantiate the DUT (Device Under Test)
    MAC16_wrapper dut (
        .clk(clk),
        .a_in(a_in),
        .b_in(b_in),
        .c_in(c_in),
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
        
        // Initialize inputs
        a_in = 0;
        b_in = 0;
        c_in = 0;
        
        // Wait for initial settling
        #20;
        
        // Test Case 1: Negative * Positive + Positive
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
        
        // Test Case 16: Positive * Positive + Positive
        test_case(16'sd15, 16'sd20, 16'sd100, "15 * 20 + 100 = 400");
        
        // Test Case 17: All negative
        test_case(-16'sd10, -16'sd5, -16'sd20, "(-10) * (-5) + (-20) = 30");
        
        // Test Case 18: Small negative * large positive
        test_case(-16'sd2, 16'sd1000, 16'sd500, "(-2) * 1000 + 500 = -1500");
        
        // Test Case 19: Testing overflow handling (large result)
        test_case(16'sd10000, 16'sd10000, 16'sd0, "10000 * 10000 + 0 = 100000000");
        
        // Test Case 20: Near maximum negative
        test_case(-16'sd32768, 16'sd2, 16'sd0, "(-32768) * 2 + 0 = -65536");
        
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
            
            // Apply inputs
            a_in = a;
            b_in = b;
            c_in = c;
            
            // Calculate expected result
            calc_expected = (a * b) + c;
            expected_result = calc_expected;
            
            // Wait for one clock cycle to register inputs
            @(posedge clk);
            
            // Wait for MAC16 pipeline (account for registered inputs)
            repeat(3) @(posedge clk);  // Allow time for pipelined operation
            
            // Check result
            if (result === expected_result) begin
                $display("[PASS] Test %0d: %s", test_count, description);
                $display("       A=%0d, B=%0d, C=%0d => Result=%0d (0x%08h)", 
                         a, b, c, result, result);
                pass_count = pass_count + 1;
            end else begin
                $display("[FAIL] Test %0d: %s", test_count, description);
                $display("       A=%0d, B=%0d, C=%0d", a, b, c);
                $display("       Expected: %0d (0x%08h)", expected_result, expected_result);
                $display("       Got:      %0d (0x%08h)", result, result);
                fail_count = fail_count + 1;
            end
            $display("");
            
            // Small delay between tests
            #10;
        end
    endtask
    
    // Optional: Generate VCD waveform file
    initial begin
        $dumpfile("MAC16_wrapper_tb.vcd");
        $dumpvars(0, MAC16_wrapper_tb);
    end

endmodule