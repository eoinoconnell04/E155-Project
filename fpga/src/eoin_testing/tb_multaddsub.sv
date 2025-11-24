// ============================================================================
// TESTBENCH
// ============================================================================

module tb_multaddsub;
    parameter A_WIDTH = 16;
    parameter B_WIDTH = 16;
    parameter ACC_WIDTH = 32;
    parameter CLK_PERIOD = 10;
    
    // Test signals
    reg clk, rst;
    reg signed [A_WIDTH-1:0] a;
    reg signed [B_WIDTH-1:0] b;
    reg signed [ACC_WIDTH-1:0] din;
    
    wire signed [ACC_WIDTH-1:0] c_comb;
    wire signed [ACC_WIDTH-1:0] c_reg;
    wire signed [ACC_WIDTH-1:0] c_full;
    
    reg signed [ACC_WIDTH-1:0] expected;
    integer test_num, errors;
    
    // Instantiate all variants
    multaddsub #(
        .A_WIDTH(A_WIDTH),
        .B_WIDTH(B_WIDTH),
        .ACC_WIDTH(ACC_WIDTH)
    ) dut_comb (
        .a(a), .b(b), .din(din), .c(c_comb)
    );
    
    multaddsub_reg #(
        .A_WIDTH(A_WIDTH),
        .B_WIDTH(B_WIDTH),
        .ACC_WIDTH(ACC_WIDTH)
    ) dut_reg (
        .clk(clk), .rst(rst),
        .a(a), .b(b), .din(din), .c(c_reg)
    );
    
    multaddsub_reg_full #(
        .A_WIDTH(A_WIDTH),
        .B_WIDTH(B_WIDTH),
        .ACC_WIDTH(ACC_WIDTH)
    ) dut_full (
        .clk(clk), .rst(rst),
        .a(a), .b(b), .din(din), .c(c_full)
    );
    
    // Clock generation
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end
    
    // Test
    initial begin
        test_num = 0;
        errors = 0;
        rst = 1;
        a = 0; b = 0; din = 0;
        
        $display("========================================");
        $display("Testing 16x16+32 DSP Multiply-Add");
        $display("========================================\n");
        
        // Release reset
        repeat(2) @(posedge clk);
        rst = 0;
        @(posedge clk);
        
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
        
        // Summary
        $display("\n========================================");
        $display("Tests completed: %0d", test_num);
        $display("Errors: %0d", errors);
        if (errors == 0)
            $display("*** ALL TESTS PASSED ***");
        else
            $display("*** SOME TESTS FAILED ***");
        $display("========================================");
        
        #100;
        $finish;
    end
    
    // Test task
    task test_calc;
        input signed [A_WIDTH-1:0] test_a;
        input signed [B_WIDTH-1:0] test_b;
        input signed [ACC_WIDTH-1:0] test_din;
        reg signed [ACC_WIDTH-1:0] exp;
        begin
            test_num = test_num + 1;
            
            a = test_a;
            b = test_b;
            din = test_din;
            exp = test_a * test_b + test_din;
            
            #1; // Combinatorial settling
            
            // Check combinatorial version
            if (c_comb !== exp) begin
                $display("  Test %0d FAIL (comb): a=%0d b=%0d din=%0d => %0d (exp %0d)",
                         test_num, test_a, test_b, test_din, c_comb, exp);
                errors = errors + 1;
            end
            
            // Wait for registered versions
            @(posedge clk);
            @(posedge clk);
            
            // Check registered version (1 cycle delay)
            if (c_reg !== exp) begin
                $display("  Test %0d FAIL (reg): a=%0d b=%0d din=%0d => %0d (exp %0d)",
                         test_num, test_a, test_b, test_din, c_reg, exp);
                errors = errors + 1;
            end
            
            // Check fully pipelined version (2 cycle delay)
            @(posedge clk);
            if (c_full !== exp) begin
                $display("  Test %0d FAIL (full): a=%0d b=%0d din=%0d => %0d (exp %0d)",
                         test_num, test_a, test_b, test_din, c_full, exp);
                errors = errors + 1;
            end else begin
                $display("  Test %0d PASS: a=%0d * b=%0d + din=%0d = %0d",
                         test_num, test_a, test_b, test_din, exp);
            end
        end
    endtask
    
endmodule