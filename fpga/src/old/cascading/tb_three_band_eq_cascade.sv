/*
Testbench for cascaded three_band_eq
Tests:
1. Reset behavior
2. Sample-by-sample processing with cascaded filters
3. Timing verification (trigger propagation)
4. Filter output validation
5. Unity gain pass-through test
*/

`timescale 1ns / 1ps

module tb_three_band_eq_cascade();

    // Clock and reset
    logic clk;
    logic reset;
    logic l_r_clk;
    
    // Audio signals
    logic signed [15:0] audio_in;
    logic signed [15:0] audio_out;
    logic mac_a;
    
    // Test variables
    integer i;
    logic signed [15:0] test_samples [0:15];
    logic signed [15:0] expected_out;
    
    // Timing measurement variables (declare at top)
    integer error;
    integer start_time;
    integer low_time;
    integer mid_time;
    integer high_time;
    
    // Instantiate DUT
    three_band_eq dut (
        .clk(clk),
        .l_r_clk(l_r_clk),
        .reset(reset),
        .audio_in(audio_in),
        .audio_out(audio_out),
        .mac_a(mac_a)
    );
    
    // Clock generation: 48MHz system clock
    initial begin
        clk = 0;
        forever #10.416 clk = ~clk; // 48MHz (period = 20.833ns)
    end
    
    // L/R clock generation: 48kHz sample rate
    // Period = 1/48kHz = 20.833us = 20833ns
    // Toggle every half period = 10416.5ns
    initial begin
        l_r_clk = 0;
        forever #10416.5 l_r_clk = ~l_r_clk;
    end
    
    // Initialize test samples
    initial begin
        // Test pattern: impulse, step, ramp, sine-like pattern
        test_samples[0]  = 16'sh4000;  // +1.0 in Q2.14 (impulse)
        test_samples[1]  = 16'sh0000;  // 0.0
        test_samples[2]  = 16'sh0000;  // 0.0
        test_samples[3]  = 16'sh2000;  // +0.5
        test_samples[4]  = 16'sh2000;  // +0.5
        test_samples[5]  = 16'sh2000;  // +0.5
        test_samples[6]  = 16'sh1000;  // +0.25
        test_samples[7]  = 16'sh0800;  // +0.125
        test_samples[8]  = 16'shF800;  // -0.125 (negative values)
        test_samples[9]  = 16'shF000;  // -0.25
        test_samples[10] = 16'shE000;  // -0.5
        test_samples[11] = 16'shE000;  // -0.5
        test_samples[12] = 16'sh0000;  // 0.0
        test_samples[13] = 16'sh1000;  // +0.25
        test_samples[14] = 16'sh2000;  // +0.5
        test_samples[15] = 16'sh0000;  // 0.0
    end
    
    // Main test sequence
    initial begin
        $display("=== Three-Band EQ Cascaded Filter Testbench ===");
        $display("Time: %0t", $time);
        
        // Initialize signals
        reset = 0;
        audio_in = 16'sh0000;
        
        // Apply reset
        $display("\n[%0t] TEST 1: Reset", $time);
        repeat(5) @(posedge clk);
        reset = 1;
        repeat(5) @(posedge clk);
        $display("[%0t] Reset released", $time);
        
        // Wait for first l_r_clk edge
        @(posedge l_r_clk);
        repeat(2) @(posedge clk);
        
        // TEST 2: Send test samples
        $display("\n[%0t] TEST 2: Processing test samples", $time);
        $display("Each sample should take ~30 clock cycles to propagate through cascade");
        $display("Sample rate: 48kHz, Clock: 48MHz, Cycles available: 1000");
        
        for (i = 0; i < 16; i = i + 1) begin
            // Wait for l_r_clk edge (either rising or falling)
            @(posedge l_r_clk or negedge l_r_clk);
            @(posedge clk);
            
            // Apply new sample
            audio_in = test_samples[i];
            $display("\n[%0t] Sample %0d: Input = 0x%h (%d)", 
                     $time, i, test_samples[i], test_samples[i]);
            
            // Wait for processing to complete
            // Monitor the cascade: wait for all three filters to complete
            wait_for_cascade_complete();
            
            // Sample output
            @(posedge clk);
            $display("[%0t]          Output = 0x%h (%d)", 
                     $time, audio_out, audio_out);
            
            // For unity gain coefficients (mid and high), output should equal input
            // (assuming low filter coefficients are also near unity)
            // Allow for some quantization error
            if (i > 2) begin // Skip first few samples (transient)
                error = audio_out - test_samples[i-2]; // Account for pipeline delay
                if (error < -100 || error > 100) begin
                    $display("WARNING: Large deviation detected!");
                end
            end
        end
        
        // TEST 3: Verify timing
        $display("\n[%0t] TEST 3: Timing verification", $time);
        @(posedge l_r_clk or negedge l_r_clk);
        @(posedge clk);
        audio_in = 16'sh3000; // Test value
        
        start_time = $time;
        $display("[%0t] Sample applied, monitoring cascade...", $time);
        
        // Monitor low filter completion
        @(posedge mac_a);
        low_time = $time - start_time;
        $display("[%0t] Low filter complete (took %0d ns, ~%0d cycles)", 
                 $time, low_time, low_time/20.833);
        
        // Monitor mid filter completion (look for mid_valid in DUT)
        // This is internal, so we'll just wait and observe
        repeat(15) @(posedge clk);
        mid_time = $time - start_time;
        $display("[%0t] Mid filter should be complete (took %0d ns, ~%0d cycles)", 
                 $time, mid_time, mid_time/20.833);
        
        // Monitor high filter completion
        repeat(15) @(posedge clk);
        high_time = $time - start_time;
        $display("[%0t] High filter should be complete (took %0d ns, ~%0d cycles)", 
                 $time, high_time, high_time/20.833);
        
        // TEST 4: Stress test - rapid samples
        $display("\n[%0t] TEST 4: Continuous sample processing", $time);
        for (i = 0; i < 8; i = i + 1) begin
            @(posedge l_r_clk or negedge l_r_clk);
            @(posedge clk);
            audio_in = $random;
            wait_for_cascade_complete();
            $display("[%0t] Sample %0d processed: in=0x%h, out=0x%h", 
                     $time, i, audio_in, audio_out);
        end
        
        // TEST 5: DC offset test
        $display("\n[%0t] TEST 5: DC offset test", $time);
        for (i = 0; i < 10; i = i + 1) begin
            @(posedge l_r_clk or negedge l_r_clk);
            @(posedge clk);
            audio_in = 16'sh1000; // Constant DC value
            wait_for_cascade_complete();
        end
        $display("[%0t] After 10 samples of DC input (0x1000):", $time);
        $display("          Output = 0x%h (should stabilize near input for unity gain)", 
                 audio_out);
        
        // TEST 6: Zero input test
        $display("\n[%0t] TEST 6: Zero input settling", $time);
        for (i = 0; i < 10; i = i + 1) begin
            @(posedge l_r_clk or negedge l_r_clk);
            @(posedge clk);
            audio_in = 16'sh0000;
            wait_for_cascade_complete();
        end
        $display("[%0t] After 10 samples of zero input:", $time);
        $display("          Output = 0x%h (should be near zero)", audio_out);
        
        if (audio_out < 16'sh0100 && audio_out > 16'shFF00) begin
            $display("PASS: Output properly settled to zero");
        end else begin
            $display("WARNING: Output did not settle to zero");
        end
        
        // Finish simulation
        $display("\n=== Testbench Complete ===");
        $display("Total simulation time: %0t", $time);
        repeat(10) @(posedge clk);
        $finish;
    end
    
    // Task to wait for cascade to complete
    // Waits approximately 35 clock cycles (conservative estimate)
    task wait_for_cascade_complete();
        repeat(35) @(posedge clk);
    endtask
    
    // Monitor for debugging
    initial begin
        $monitor("[MON %0t] reset=%b, l_r_clk=%b, audio_in=%h, audio_out=%h, mac_a=%b",
                 $time, reset, l_r_clk, audio_in, audio_out, mac_a);
    end
    
    // Waveform dump
    initial begin
        $dumpfile("tb_three_band_eq_cascade.vcd");
        $dumpvars(0, tb_three_band_eq_cascade);
        
        // Also dump internal signals for debugging
        $dumpvars(0, dut.low_filter.state);
        $dumpvars(0, dut.mid_filter.state);
        $dumpvars(0, dut.high_filter.state);
        $dumpvars(0, dut.low_valid);
        $dumpvars(0, dut.mid_valid);
        $dumpvars(0, dut.high_valid);
        $dumpvars(0, dut.low_out);
        $dumpvars(0, dut.mid_out);
        $dumpvars(0, dut.high_out);
    end
    
    // Timeout watchdog
    initial begin
        #50_000_000; // 50ms timeout
        $display("\nERROR: Simulation timeout!");
        $finish;
    end

endmodule