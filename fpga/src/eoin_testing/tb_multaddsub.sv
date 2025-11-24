module tb_multaddsub;
    // Parameters
    parameter A_WIDTH = 7;
    parameter B_WIDTH = 6;
    parameter CLK_PERIOD = 10;
    
    // Testbench signals
    reg clk;
    reg signed [A_WIDTH-1:0] a;
    reg signed [B_WIDTH-1:0] b;
    reg signed [A_WIDTH+B_WIDTH-1:0] din;
    wire signed [A_WIDTH+B_WIDTH-1:0] c;
    
    // Expected result for verification
    reg signed [A_WIDTH+B_WIDTH-1:0] expected;
    integer test_num;
    integer errors;
    
    // Instantiate the DUT (Device Under Test) - Combinatorial multiply-add SIGNED
    multaddsub_add_sign_7_6 #(
        .A_WIDTH(A_WIDTH),
        .B_WIDTH(B_WIDTH)
    ) dut (
        .a(a),
        .b(b),
        .din(din),
        .c(c)
    );
    
    // Clock generation (for testbench timing only, DUT is combinatorial)
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end
    
    // Test stimulus
    initial begin
        // Initialize
        test_num = 0;
        errors = 0;
        a = 0;
        b = 0;
        din = 0;
        
        $display("===================================================");
        $display("Testing Combinatorial Multiply-Add Module");
        $display("Operation: c = a * b + din (2's complement SIGNED)");
        $display("A_WIDTH = %0d (range: -64 to 63)", A_WIDTH);
        $display("B_WIDTH = %0d (range: -32 to 31)", B_WIDTH);
        $display("NOTE: This is a COMBINATORIAL module (no registers)");
        $display("===================================================\n");
        
        // Wait for initial settling
        #1;
        
        // Test 1: Positive * Positive
        $display("Test 1: Positive * Positive");
        run_test(5, 3, 20);      // 5*3 + 20 = 15 + 20 = 35
        run_test(10, 4, 50);     // 10*4 + 50 = 40 + 50 = 90
        run_test(7, 8, 100);     // 7*8 + 100 = 56 + 100 = 156
        
        // Test 2: Negative * Positive
        $display("\nTest 2: Negative * Positive");
        run_test(-5, 3, 20);     // -5*3 + 20 = -15 + 20 = 5
        run_test(-10, 4, 50);    // -10*4 + 50 = -40 + 50 = 10
        run_test(-7, 8, 100);    // -7*8 + 100 = -56 + 100 = 44
        
        // Test 3: Positive * Negative
        $display("\nTest 3: Positive * Negative");
        run_test(5, -3, 20);     // 5*-3 + 20 = -15 + 20 = 5
        run_test(10, -4, 50);    // 10*-4 + 50 = -40 + 50 = 10
        run_test(7, -8, 100);    // 7*-8 + 100 = -56 + 100 = 44
        
        // Test 4: Negative * Negative
        $display("\nTest 4: Negative * Negative");
        run_test(-5, -3, 20);    // -5*-3 + 20 = 15 + 20 = 35
        run_test(-10, -4, 50);   // -10*-4 + 50 = 40 + 50 = 90
        run_test(-7, -8, 100);   // -7*-8 + 100 = 56 + 100 = 156
        
        // Test 5: Zero cases
        $display("\nTest 5: Zero cases");
        run_test(0, 5, 10);      // 0*5 + 10 = 10
        run_test(5, 0, 10);      // 5*0 + 10 = 10
        run_test(0, 0, 0);       // 0*0 + 0 = 0
        run_test(0, -5, -10);    // 0*-5 + -10 = -10
        run_test(-5, 0, -10);    // -5*0 + -10 = -10
        
        // Test 6: din = 0 (pure multiplication)
        $display("\nTest 6: Pure multiplication (din = 0)");
        run_test(5, 6, 0);       // 5*6 = 30
        run_test(-5, 6, 0);      // -5*6 = -30
        run_test(5, -6, 0);      // 5*-6 = -30
        run_test(-5, -6, 0);     // -5*-6 = 30
        
        // Test 7: Negative din (offset)
        $display("\nTest 7: Negative din");
        run_test(5, 3, -10);     // 5*3 + -10 = 15 - 10 = 5
        run_test(-5, 3, -10);    // -5*3 + -10 = -15 - 10 = -25
        run_test(5, -3, -10);    // 5*-3 + -10 = -15 - 10 = -25
        run_test(-5, -3, -10);   // -5*-3 + -10 = 15 - 10 = 5
        
        // Test 8: Boundary values (signed)
        $display("\nTest 8: Boundary values (2's complement)");
        run_test(63, 31, 0);     // Max positive A * Max positive B
        run_test(-64, 31, 0);    // Min negative A * Max positive B
        run_test(63, -32, 0);    // Max positive A * Min negative B
        run_test(-64, -32, 0);   // Min negative A * Min negative B
        run_test(63, 31, 100);   // Max product + positive offset
        run_test(-64, -32, -100);// Max negative product + negative offset
        
        // Test 9: Accumulator-style operations (IIR filter simulation)
        $display("\nTest 9: Accumulator operations (IIR simulation)");
        run_test(3, 4, 0);       // acc = 0 + 3*4 = 12
        run_test(5, 2, 12);      // acc = 12 + 5*2 = 22
        run_test(-7, 3, 22);     // acc = 22 + (-7)*3 = 1
        run_test(2, -5, 1);      // acc = 1 + 2*(-5) = -9
        run_test(-3, -4, -9);    // acc = -9 + (-3)*(-4) = 3
        
        // Test 10: Powers of 2 and bit patterns
        $display("\nTest 10: Powers of 2");
        run_test(8, 4, 0);       // 32
        run_test(-8, 4, 0);      // -32
        run_test(8, -4, 0);      // -32
        run_test(-8, -4, 0);     // 32
        run_test(16, 2, 64);     // 32 + 64 = 96
        
        // Test 11: Edge cases around zero
        $display("\nTest 11: Near-zero values");
        run_test(1, 1, 0);       // 1
        run_test(-1, 1, 0);      // -1
        run_test(1, -1, 0);      // -1
        run_test(-1, -1, 0);     // 1
        run_test(1, 1, -1);      // 0
        run_test(-1, -1, -1);    // 0
        
        // Test 12: Verify combinatorial behavior (instant response)
        $display("\nTest 12: Combinatorial response check");
        a = -7; b = 9; din = -50;
        #0.1; // Very short delay
        expected = -7 * 9 + (-50);
        test_num = test_num + 1;
        if (c === expected)
            $display("  Test %0d PASS: Instant combinatorial response (c=%0d)", test_num, c);
        else begin
            $display("  Test %0d FAIL: Expected instant response c=%0d (got %0d)", test_num, expected, c);
            errors = errors + 1;
        end
        
        // Test 13: Rapid signed changes
        $display("\nTest 13: Rapid input changes (signed values)");
        run_test(20, -15, 200);
        run_test(-25, 10, -100);
        run_test(30, 20, -500);
        run_test(-40, -20, 1000);
        
        // Test 14: Sign extension verification
        $display("\nTest 14: Sign extension check");
        run_test(-1, 1, 0);      // -1 * 1 = -1 (all bits should be 1's in result)
        run_test(-64, 1, 0);     // Most negative A
        run_test(1, -32, 0);     // Most negative B
        
        // Summary
        $display("\n===================================================");
        $display("Test Summary:");
        $display("Total Tests: %0d", test_num);
        $display("Errors: %0d", errors);
        if (errors == 0)
            $display("*** ALL TESTS PASSED ***");
        else
            $display("*** TESTS FAILED ***");
        $display("2's complement signed arithmetic verified!");
        $display("===================================================");
        
        #100;
        $finish;
    end
    
    // Task to run a test case (combinatorial, no clock wait needed)
    task run_test;
        input signed [A_WIDTH-1:0] test_a;
        input signed [B_WIDTH-1:0] test_b;
        input signed [A_WIDTH+B_WIDTH-1:0] test_din;
        begin
            a = test_a;
            b = test_b;
            din = test_din;
            #1; // Small delay for combinatorial logic to settle
            expected = test_a * test_b + test_din;
            check_result(test_a, test_b, test_din, expected);
        end
    endtask
    
    // Task to check results
    task check_result;
        input signed [A_WIDTH-1:0] chk_a;
        input signed [B_WIDTH-1:0] chk_b;
        input signed [A_WIDTH+B_WIDTH-1:0] chk_din;
        input signed [A_WIDTH+B_WIDTH-1:0] chk_expected;
        begin
            test_num = test_num + 1;
            if (c === chk_expected) begin
                $display("  Test %0d PASS: a=%0d, b=%0d, din=%0d => c=%0d", 
                         test_num, chk_a, chk_b, chk_din, c);
            end else begin
                $display("  Test %0d FAIL: a=%0d, b=%0d, din=%0d => c=%0d (expected %0d)", 
                         test_num, chk_a, chk_b, chk_din, c, chk_expected);
                $display("    Product a*b = %0d", chk_a * chk_b);
                errors = errors + 1;
            end
        end
    endtask
    
    // Continuous monitor for debugging
    initial begin
        $monitor("Time=%0t a=%0d b=%0d din=%0d c=%0d", 
                 $time, a, b, din, c);
    end
    
endmodule