`timescale 1ns/1ps

module MAC16_wrapper_accum_sim_tb;

    // Testbench signals
    logic clk;
    logic rst;
    logic ce;
    logic signed [15:0] a_in;
    logic signed [15:0] b_in;
    logic signed [31:0] result;
    
    // Clock generation (100 MHz)
    localparam CLK_PERIOD = 10.0;
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end
    
    // DUT instantiation
    MAC16_wrapper_accum_sim dut (
        .clk(clk),
        .rst(rst),
        .ce(ce),
        .a_in(a_in),
        .b_in(b_in),
        .result(result)
    );
    
    // Function to convert real to Q2.14 fixed point
    function signed [15:0] real_to_q2_14(real value);
        real scaled;
        integer temp;
        scaled = value * (2.0 ** 14.0);
        if (scaled > 32767.0) scaled = 32767.0;
        if (scaled < -32768.0) scaled = -32768.0;
        temp = integer'(scaled);
        return temp[15:0];
    endfunction
    
    // Function to convert Q2.14 to real
    function real q2_14_to_real(logic signed [15:0] value);
        return real'(value) / (2.0 ** 14.0);
    endfunction
    
    // Function to convert 32-bit result to real (Q4.28 format)
    function real q4_28_to_real(logic signed [31:0] value);
        return real'(value) / (2.0 ** 28.0);
    endfunction
    
    // Task to perform a single multiply-accumulate
    task mac_operation(input real a_val, input real b_val, input string description);
        begin
            @(posedge clk);
            a_in = real_to_q2_14(a_val);
            b_in = real_to_q2_14(b_val);
            ce = 1'b1;
            
            @(posedge clk);
            // Keep CE high! Don't turn it off yet!
            
            @(posedge clk);
            ce = 1'b0;  // ← Turn OFF CE AFTER the result is computed
            #1;
            
            $display("%s: a=%0.4f, b=%0.4f, result=%0.4f (0x%h)", 
                    description, a_val, b_val, q4_28_to_real(result), result);
        end
    endtask
    
    // Task to reset the MAC
    task reset_mac();
        begin
            $display("\n--- Resetting MAC ---");
            @(posedge clk);
            rst = 1'b1;
            ce = 1'b0;
            a_in = 16'd0;
            b_in = 16'd0;
            @(posedge clk);
            @(posedge clk);
            rst = 1'b0;
            $display("Result after reset: %0d (0x%h)\n", result, result);
        end
    endtask
    
    // Main test sequence
    initial begin
        // Declare all variables at the top of the initial block
        automatic real b0_val, b1_val, b2_val, a1_val, a2_val;
        automatic real x_n_val, x_n1_val, x_n2_val, y_n1_val, y_n2_val;
        automatic real expected_val;
        
        $display("=== MAC16 Wrapper Accumulator Testbench ===");
        $display("Clock Period: %0.1f ns", CLK_PERIOD);
        $display("Testing Q2.14 fixed-point arithmetic\n");
        
        // Initialize
        rst = 1'b1;
        ce = 1'b0;
        a_in = 16'd0;
        b_in = 16'd0;
        
        // Wait and release reset
        repeat(5) @(posedge clk);
        rst = 1'b0;
        repeat(2) @(posedge clk);
        
        //========================================
        // TEST 1: Simple Multiply (No Accumulation)
        //========================================
        $display("\n****************************************");
        $display("TEST 1: Simple Multiply");
        $display("Expected: result = a * b (no accumulation yet)");
        $display("****************************************");
        
        mac_operation(1.0, 1.0, "1.0 * 1.0");
        mac_operation(2.0, 3.0, "2.0 * 3.0");
        mac_operation(0.5, 0.5, "0.5 * 0.5");
        mac_operation(-1.0, 1.0, "-1.0 * 1.0");
        
        //========================================
        // TEST 2: Accumulation (Simple Sum)
        //========================================
        reset_mac();
        $display("****************************************");
        $display("TEST 2: Accumulation");
        $display("Expected: result accumulates (a*b + previous)");
        $display("****************************************");
        
        mac_operation(1.0, 1.0, "Step 1: 1.0 * 1.0");
        mac_operation(1.0, 1.0, "Step 2: 1.0 * 1.0 + previous");
        mac_operation(1.0, 1.0, "Step 3: 1.0 * 1.0 + previous");
        $display("Expected final: ~3.0");
        
        //========================================
        // TEST 3: MAC with Different Values
        //========================================
        reset_mac();
        $display("****************************************");
        $display("TEST 3: MAC with Different Values");
        $display("Simulating: (2*3) + (4*5) + (1*2) = 6 + 20 + 2 = 28");
        $display("****************************************");
        
        mac_operation(2.0, 3.0, "Step 1: 2.0 * 3.0");
        mac_operation(4.0, 5.0, "Step 2: 4.0 * 5.0 + previous");
        mac_operation(1.0, 2.0, "Step 3: 1.0 * 2.0 + previous");
        $display("Expected final: ~28.0");
        
        //========================================
        // TEST 4: Negative Numbers
        //========================================
        reset_mac();
        $display("****************************************");
        $display("TEST 4: Negative Numbers");
        $display("Simulating: (5*3) + (-2*4) = 15 + (-8) = 7");
        $display("****************************************");
        
        mac_operation(5.0, 3.0, "Step 1: 5.0 * 3.0");
        mac_operation(-2.0, 4.0, "Step 2: -2.0 * 4.0 + previous");
        $display("Expected final: ~7.0");
        
        //========================================
        // TEST 5: Fractional Values
        //========================================
        reset_mac();
        $display("****************************************");
        $display("TEST 5: Fractional Values");
        $display("Simulating: (0.5*0.5) + (0.25*0.5) = 0.25 + 0.125 = 0.375");
        $display("****************************************");
        
        mac_operation(0.5, 0.5, "Step 1: 0.5 * 0.5");
        mac_operation(0.25, 0.5, "Step 2: 0.25 * 0.5 + previous");
        $display("Expected final: ~0.375");
        
        //========================================
        // TEST 6: Clock Enable Control
        //========================================
        reset_mac();
        $display("****************************************");
        $display("TEST 6: Clock Enable Control");
        $display("Testing CE signal - accumulation should pause when CE=0");
        $display("****************************************");
        
        mac_operation(1.0, 1.0, "Step 1: 1.0 * 1.0");
        
        // Disable CE - result should hold
        @(posedge clk);
        ce = 1'b0;
        a_in = real_to_q2_14(5.0);
        b_in = real_to_q2_14(5.0);
        repeat(3) @(posedge clk);
        $display("CE disabled: a=5.0, b=5.0, result=%0.4f (should still be ~1.0)", 
                 q4_28_to_real(result));
        
        // Re-enable CE
        mac_operation(2.0, 2.0, "CE re-enabled: 2.0 * 2.0 + previous");
        $display("Expected: ~5.0 (1.0 from step 1 + 4.0 from this step)");
        
        //========================================
        // TEST 7: Pipeline Timing Test
        //========================================
        reset_mac();
        $display("****************************************");
        $display("TEST 7: Pipeline Timing");
        $display("Verifying 2-cycle pipeline delay");
        $display("****************************************");
        
        @(posedge clk);
        a_in = real_to_q2_14(3.0);
        b_in = real_to_q2_14(4.0);
        ce = 1'b1;
        $display("Cycle 0: Inputs loaded (a=3.0, b=4.0), result=%0.4f", q4_28_to_real(result));
        
        @(posedge clk);
        $display("Cycle 1: Inputs registered, result=%0.4f", q4_28_to_real(result));
        
        @(posedge clk);
        $display("Cycle 2: Result available, result=%0.4f (expected ~12.0)", q4_28_to_real(result));
        
        //========================================
        // TEST 8: Biquad IIR Simulation
        //========================================
        reset_mac();
        $display("****************************************");
        $display("TEST 8: Biquad IIR Filter Simulation");
        $display("Simulating: y = b0*x[n] + b1*x[n-1] + b2*x[n-2] - a1*y[n-1] - a2*y[n-2]");
        $display("****************************************");
        
        // Example coefficients (simplified)
        b0_val = 0.5; b1_val = 0.3; b2_val = 0.2;
        a1_val = 0.4; a2_val = 0.1;
        x_n_val = 1.0; x_n1_val = 0.5; x_n2_val = 0.2;
        y_n1_val = 0.3; y_n2_val = 0.1;
        
        $display("Coefficients: b0=%0.2f, b1=%0.2f, b2=%0.2f, a1=%0.2f, a2=%0.2f", 
                 b0_val, b1_val, b2_val, a1_val, a2_val);
        $display("Inputs: x[n]=%0.2f, x[n-1]=%0.2f, x[n-2]=%0.2f", x_n_val, x_n1_val, x_n2_val);
        $display("Previous outputs: y[n-1]=%0.2f, y[n-2]=%0.2f", y_n1_val, y_n2_val);
        
        mac_operation(b0_val, x_n_val, "b0 * x[n]");
        mac_operation(b1_val, x_n1_val, "b1 * x[n-1] + acc");
        mac_operation(b2_val, x_n2_val, "b2 * x[n-2] + acc");
        mac_operation(-a1_val, y_n1_val, "-a1 * y[n-1] + acc");
        mac_operation(-a2_val, y_n2_val, "-a2 * y[n-2] + acc");
        
        expected_val = b0_val*x_n_val + b1_val*x_n1_val + b2_val*x_n2_val - a1_val*y_n1_val - a2_val*y_n2_val;
        $display("Expected result: %0.4f", expected_val);
        
        //========================================
        // TEST 9: Reset During Operation
        //========================================
        $display("\n****************************************");
        $display("TEST 9: Reset During Operation");
        $display("****************************************");
        
        mac_operation(5.0, 5.0, "Start: 5.0 * 5.0");
        
        @(posedge clk);
        rst = 1'b1;
        $display("Reset asserted mid-operation");
        @(posedge clk);
        rst = 1'b0;
        @(posedge clk);
        $display("After reset: result=%0.4f (should be 0.0)", q4_28_to_real(result));
        
        // Finish
        repeat(10) @(posedge clk);
        $display("\n=== All Tests Complete ===");
        $display("If all results match expected values, MAC is working correctly!");
        $finish;
    end
    
    // Timeout watchdog
    initial begin
        #100000;  // 100 us timeout
        $display("ERROR: Test timeout!");
        $finish;
    end

endmodule