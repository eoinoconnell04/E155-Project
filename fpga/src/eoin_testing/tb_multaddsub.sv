// ============================================================================
// TESTBENCH - Combinatorial multaddsub only
// ============================================================================

module tb_multaddsub;
    parameter A_WIDTH = 16;
    parameter B_WIDTH = 16;
    parameter ACC_WIDTH = 32;
    
    // Test signals
    reg signed [A_WIDTH-1:0] a;
    reg signed [B_WIDTH-1:0] b;
    reg signed [ACC_WIDTH-1:0] din;
    wire signed [ACC_WIDTH-1:0] c;
    
    reg signed [ACC_WIDTH-1:0] expected;
    integer test_num, errors;
    
    // Instantiate combinatorial multaddsub
    multaddsub #(
        .A_WIDTH(A_WIDTH),
        .B_WIDTH(B_WIDTH),
        .ACC_WIDTH(ACC_WIDTH)
    ) dut (
        .a(a), 
        .b(b), 
        .din(din), 
        .c(c)
    );
    
    // Test
    initial begin
        test_num = 0;
        errors = 0;
        a = 0; 
        b = 0; 
        din = 0;
        
        $display("========================================");
        $display("Testing 16x16+32 DSP Multiply-Add");
        $display("Operation: c = a * b + din");
        $display("Combinatorial (no registers)");
        $display("========================================\n");
        
        // Wait for initial settling
        #1;
        
        // Test 1: Basic operations
        $display("Test 1: Basic signed multiply-add");
        test_calc(100, 200, 5000);     // 100*200 + 5000 = 25000
        test_calc(-100, 200, 5000);    // -100*200 + 5000 = -15000
        test_calc(100, -200, 5000);    // 100*-200 + 5000 = -15000
        test_calc(-100, -200, 5000);   // -100*-200 + 5000 = 25000
        
        // Test 2: Large values
        $display("\nTest 2: Large values (16-bit range)");
        test_calc(32767, 2, 0);        // Max positive * 2
        test_calc(-32768, 2, 0);       // Min negative * 2
        test_calc(32767, 32767, 0);    // Max * Max
        test_calc(-32768, -32768, 0);  // Min * Min
        
        // Test 3: Accumulator patterns (IIR filter)
        $display("\nTest 3: IIR accumulator simulation");
        test_calc(1000, 500, 0);       // acc = 0 + 1000*500
        test_calc(800, 300, 500000);   // acc = 500000 + 800*300
        test_calc(-600, 400, 740000);  // acc = 740000 + (-600)*400
        test_calc(200, -100, 500000);  // acc = 500000 + 200*(-100)
        
        // Test 4: Zero cases
        $display("\nTest 4: Zero cases");
        test_calc(0, 1000, 12345);
        test_calc(1000, 0, 12345);
        test_calc(0, 0, 0);
        
        // Test 5: Powers of 2
        $display("\nTest 5: Powers of 2");
        test_calc(256, 128, 0);
        test_calc(1024, 1024, 1000000);
        test_calc(-2048, 512, -500000);
        
        // Test 6: Negative din
        $display("\nTest 6: Negative accumulator");
        test_calc(100, 50, -1000);
        test_calc(-200, -30, -5000);
        test_calc(500, 100, -60000);
        
        // Test 7: Sequential pattern (manual pipeline simulation)
        $display("\nTest 7: Sequential operations");
        test_calc(10, 10, 0);          // 100
        test_calc(5, 5, 100);          // 125
        test_calc(3, 3, 125);          // 134
        test_calc(2, 2, 134);          // 138
        
        // Summary
        $display("\n========================================");
        $display("Tests completed: %0d", test_num);
        $display("Errors: %0d", errors);
        if (errors == 0)
            $display("*** ALL TESTS PASSED ***");
        else
            $display("*** SOME TESTS FAILED ***");
        $display("========================================");
        
        #10;
        $finish;
    end
    
    // Test task
    task test_calc;
        input signed [A_WIDTH-1:0] test_a;
        input signed [B_WIDTH-1:0] test_b;
        input signed [ACC_WIDTH-1:0] test_din;
        begin
            test_num = test_num + 1;
            
            a = test_a;
            b = test_b;
            din = test_din;
            expected = test_a * test_b + test_din;
            
            #1; // Combinatorial settling time
            
            // Check result
            if (c !== expected) begin
                $display("  Test %0d FAIL: a=%0d b=%0d din=%0d => %0d (expected %0d)",
                         test_num, test_a, test_b, test_din, c, expected);
                errors = errors + 1;
            end else begin
                $display("  Test %0d PASS: a=%0d * b=%0d + din=%0d = %0d",
                         test_num, test_a, test_b, test_din, c);
            end
        end
    endtask
    
endmodule