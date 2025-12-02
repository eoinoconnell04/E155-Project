`timescale 1ns/1ps

/*
Testbench for Simple MAC Gain Test
Tests the MAC16 wrapper with a simple 0.5x gain operation
*/

module tb_simple_mac_gain_test;

    logic clk;
    logic l_r_clk;
    logic reset;
    logic signed [15:0] audio_in;
    logic signed [15:0] audio_out;
    
    // Clock periods
    localparam CLK_PERIOD = 10;  // 100 MHz
    localparam L_R_PERIOD = 2083;  // ~48 kHz (20.83 us)
    
    // DUT instantiation
    simple_mac_gain_test dut (
        .clk(clk),
        .l_r_clk(l_r_clk),
        .reset(reset),
        .audio_in(audio_in),
        .audio_out(audio_out)
    );
    
    // Clock generation
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end
    
    initial begin
        l_r_clk = 0;
        forever #(L_R_PERIOD/2) l_r_clk = ~l_r_clk;
    end
    
    // Convert real to Q2.14
    function signed [15:0] real_to_q2_14(real value);
        real scaled;
        integer temp;
        scaled = value * (2.0 ** 14.0);
        if (scaled > 32767.0) scaled = 32767.0;
        if (scaled < -32768.0) scaled = -32768.0;
        temp = integer'(scaled);
        return temp[15:0];
    endfunction
    
    // Convert Q2.14 to real
    function real q2_14_to_real(logic signed [15:0] value);
        return real'(value) / (2.0 ** 14.0);
    endfunction
    
    // Test sequence
    initial begin
        $display("========================================");
        $display("Simple MAC Gain Test (0.5x gain)");
        $display("========================================");
        
        // Initialize
        reset = 1;
        audio_in = 16'd0;
        
        // Reset pulse
        #100;
        repeat(10) @(posedge clk);
        reset = 0;
        
        // Wait for l_r_clk to settle
        repeat(5) @(posedge l_r_clk);
        
        $display("\nTEST 1: Constant inputs");
        $display("Expected: output = input × 0.5");
        
        // Test with various constant values
        test_value(1.0, "Max positive");
        test_value(0.5, "Half positive");
        test_value(0.25, "Quarter positive");
        test_value(0.0, "Zero");
        test_value(-0.25, "Quarter negative");
        test_value(-0.5, "Half negative");
        test_value(-1.0, "Max negative");
        
        $display("\nTEST 2: Step response");
        test_step();
        
        $display("\nTEST 3: Simple sine wave (100 Hz)");
        test_sine(100.0, 0.5, 200);
        
        $display("\n========================================");
        $display("Test Complete!");
        $display("========================================");
        $display("If output = input × 0.5, MAC16 is working!");
        
        #10000;
        $finish;
    end
    
    // Task to test a single value
    task test_value(input real value, input string description);
        real expected, actual, error;
        begin
            expected = value * 0.5;
            
            // Set input
            @(posedge l_r_clk);
            audio_in = real_to_q2_14(value);
            
            // Wait for MAC pipeline to settle (at least 5 cycles)
            repeat(10) @(posedge l_r_clk);
            
            actual = q2_14_to_real(audio_out);
            error = actual - expected;
            
            $display("%s: In=%0.4f, Out=%0.4f, Expected=%0.4f, Error=%0.4f", 
                     description, value, actual, expected, error);
            
            // Check if close enough (allow 1 LSB error in Q2.14 = ~0.00006)
            if (error > 0.001 || error < -0.001) begin
                $display("  WARNING: Large error detected!");
            end
        end
    endtask
    
    // Task to test step response
    task test_step();
        integer i;
        real actual;
        begin
            $display("Step from 0 to 0.5...");
            audio_in = 16'd0;
            repeat(5) @(posedge l_r_clk);
            
            audio_in = real_to_q2_14(0.5);
            
            for (i = 0; i < 10; i++) begin
                @(posedge l_r_clk);
                actual = q2_14_to_real(audio_out);
                $display("  Cycle %0d: Out=%0.4f", i, actual);
            end
        end
    endtask
    
    // Task to test sine wave
    task test_sine(input real freq, input real amp, input integer samples);
        integer i;
        real time_sec, in_val, out_val;
        begin
            $display("Testing %0.0f Hz sine wave, amplitude %0.2f", freq, amp);
            
            for (i = 0; i < samples; i++) begin
                @(posedge l_r_clk);
                time_sec = real'(i) / 48000.0;
                in_val = amp * $sin(2.0 * 3.14159265359 * freq * time_sec);
                audio_in = real_to_q2_14(in_val);
                
                if (i % 20 == 0 && i > 40) begin  // Skip initial transient
                    out_val = q2_14_to_real(audio_out);
                    $display("  Sample %3d: In=%0.4f, Out=%0.4f (expect %0.4f)", 
                             i, in_val, out_val, in_val * 0.5);
                end
            end
        end
    endtask
    
    // Timeout
    initial begin
        #50_000_000;
        $display("ERROR: Timeout!");
        $finish;
    end

endmodule