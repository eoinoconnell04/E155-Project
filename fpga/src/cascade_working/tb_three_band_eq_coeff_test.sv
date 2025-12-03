`timescale 1ns / 1ps

module tb_three_band_eq_coeff_test;

    // Parameters
    parameter CLK_PERIOD = 20;  // 50MHz clock
    parameter SAMPLE_RATE = 48000;
    parameter CLK_PER_SAMPLE = 50000000 / SAMPLE_RATE;  // ~1042 clocks per sample
    
    // Testbench signals
    reg clk;
    reg rst_n;
    reg signed [23:0] audio_in;
    reg audio_valid;
    wire signed [23:0] audio_out;
    wire audio_out_valid;
    
    // Coefficient registers (adjust bit widths to match your design)
    reg signed [17:0] b0_low, b1_low, b2_low;
    reg signed [17:0] a1_low, a2_low;
    reg signed [17:0] b0_mid, b1_mid, b2_mid;
    reg signed [17:0] a1_mid, a2_mid;
    reg signed [17:0] b0_high, b1_high, b2_high;
    reg signed [17:0] a1_high, a2_high;
    reg signed [7:0] gain_low, gain_mid, gain_high;
    
    // Test tracking
    integer test_num;
    integer sample_count;
    integer error_count;
    real max_output;
    real min_output;
    real avg_output;
    real sum_output;
    integer silent_samples;
    integer clipped_samples;
    
    // DUT instantiation (adjust port names to match your design)
    three_band_eq dut (
        .clk(clk),
        .rst_n(rst_n),
        .audio_in(audio_in),
        .audio_valid(audio_valid),
        .audio_out(audio_out),
        .audio_out_valid(audio_out_valid),
        // Low band coefficients
        .b0_low(b0_low),
        .b1_low(b1_low),
        .b2_low(b2_low),
        .a1_low(a1_low),
        .a2_low(a2_low),
        // Mid band coefficients
        .b0_mid(b0_mid),
        .b1_mid(b1_mid),
        .b2_mid(b2_mid),
        .a1_mid(a1_mid),
        .a2_mid(a2_mid),
        // High band coefficients
        .b0_high(b0_high),
        .b1_high(b1_high),
        .b2_high(b2_high),
        .a1_high(a1_high),
        .a2_high(a2_high),
        // Gains
        .gain_low(gain_low),
        .gain_mid(gain_mid),
        .gain_high(gain_high)
    );
    
    // Clock generation
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end
    
    // Convert fixed-point output to real for analysis
    function real fixed_to_real;
        input signed [23:0] fixed_val;
        begin
            fixed_to_real = $itor(fixed_val) / (2.0**23);
        end
    endfunction
    
    // Task to reset statistics
    task reset_stats;
        begin
            sample_count = 0;
            max_output = -2.0;
            min_output = 2.0;
            sum_output = 0.0;
            silent_samples = 0;
            clipped_samples = 0;
        end
    endtask
    
    // Task to update statistics
    task update_stats;
        input signed [23:0] sample;
        real sample_real;
        begin
            sample_real = fixed_to_real(sample);
            sample_count = sample_count + 1;
            sum_output = sum_output + sample_real;
            
            if (sample_real > max_output) max_output = sample_real;
            if (sample_real < min_output) min_output = sample_real;
            
            // Check for silence (< -60dB)
            if (sample > -8388 && sample < 8388) silent_samples = silent_samples + 1;
            
            // Check for clipping (> 0.9 or < -0.9)
            if (sample_real > 0.9 || sample_real < -0.9) clipped_samples = clipped_samples + 1;
        end
    endtask
    
    // Task to print test results
    task print_results;
        input [200*8:1] test_name;
        begin
            avg_output = sum_output / sample_count;
            
            $display("========================================");
            $display("Test %0d: %s", test_num, test_name);
            $display("Samples processed: %0d", sample_count);
            $display("Max output: %f (%.1f dB)", max_output, 20.0*$log10($abs(max_output)+1e-10));
            $display("Min output: %f (%.1f dB)", min_output, 20.0*$log10($abs(min_output)+1e-10));
            $display("Avg output: %f", avg_output);
            $display("Silent samples (< -60dB): %0d (%.1f%%)", silent_samples, 100.0*silent_samples/sample_count);
            $display("Clipped samples (> 0.9): %0d (%.1f%%)", clipped_samples, 100.0*clipped_samples/sample_count);
            
            // Analyze results
            if (silent_samples == sample_count) begin
                $display("FAILURE: All output is silent!");
                error_count = error_count + 1;
            end else if (clipped_samples > sample_count/10) begin
                $display("WARNING: High clipping rate (>10%%)");
            end else if (max_output < 0.01 && min_output > -0.01) begin
                $display("WARNING: Very low output level");
            end else begin
                $display("PASS: Output appears normal");
            end
            $display("========================================\n");
        end
    endtask
    
    // Task to apply coefficients
    task set_coefficients;
        input signed [17:0] b0_l, b1_l, b2_l, a1_l, a2_l;
        input signed [17:0] b0_m, b1_m, b2_m, a1_m, a2_m;
        input signed [17:0] b0_h, b1_h, b2_h, a1_h, a2_h;
        input signed [7:0] g_l, g_m, g_h;
        begin
            b0_low = b0_l; b1_low = b1_l; b2_low = b2_l;
            a1_low = a1_l; a2_low = a2_l;
            
            b0_mid = b0_m; b1_mid = b1_m; b2_mid = b2_m;
            a1_mid = a1_m; a2_mid = a2_m;
            
            b0_high = b0_h; b1_high = b1_h; b2_high = b2_h;
            a1_high = a1_h; a2_high = a2_h;
            
            gain_low = g_l;
            gain_mid = g_m;
            gain_high = g_h;
            
            $display("Coefficients set:");
            $display("  Low:  b0=%h b1=%h b2=%h a1=%h a2=%h gain=%h", b0_l, b1_l, b2_l, a1_l, a2_l, g_l);
            $display("  Mid:  b0=%h b1=%h b2=%h a1=%h a2=%h gain=%h", b0_m, b1_m, b2_m, a1_m, a2_m, g_m);
            $display("  High: b0=%h b1=%h b2=%h a1=%h a2=%h gain=%h", b0_h, b1_h, b2_h, a1_h, a2_h, g_h);
        end
    endtask
    
    // Task to send test signal
    task send_test_signal;
        input integer num_samples;
        input [200*8:1] signal_type;
        integer i, j;
        real sample_val;
        begin
            reset_stats();
            
            for (i = 0; i < num_samples; i = i + 1) begin
                // Generate different test signals
                if (signal_type == "IMPULSE") begin
                    if (i == 100) audio_in = 24'h400000;  // 0.5 amplitude
                    else audio_in = 24'h000000;
                end else if (signal_type == "SINE_100HZ") begin
                    sample_val = 0.5 * $sin(2.0 * 3.14159 * 100.0 * i / SAMPLE_RATE);
                    audio_in = $rtoi(sample_val * (2.0**23));
                end else if (signal_type == "SINE_1KHZ") begin
                    sample_val = 0.5 * $sin(2.0 * 3.14159 * 1000.0 * i / SAMPLE_RATE);
                    audio_in = $rtoi(sample_val * (2.0**23));
                end else if (signal_type == "SINE_10KHZ") begin
                    sample_val = 0.5 * $sin(2.0 * 3.14159 * 10000.0 * i / SAMPLE_RATE);
                    audio_in = $rtoi(sample_val * (2.0**23));
                end else if (signal_type == "SWEEP") begin
                    sample_val = 0.5 * $sin(2.0 * 3.14159 * (20.0 + 19980.0*i/num_samples) * i / SAMPLE_RATE);
                    audio_in = $rtoi(sample_val * (2.0**23));
                end else begin  // DC or default
                    audio_in = 24'h100000;  // 0.125 amplitude DC
                end
                
                audio_valid = 1;
                @(posedge clk);
                audio_valid = 0;
                
                // Wait for output
                for (j = 0; j < CLK_PER_SAMPLE*2; j = j + 1) begin
                    @(posedge clk);
                    if (audio_out_valid) begin
                        update_stats(audio_out);
                        j = CLK_PER_SAMPLE*2;  // Exit wait loop
                    end
                end
            end
            
            // Wait for pipeline to flush
            repeat(1000) @(posedge clk);
        end
    endtask
    
    // Main test sequence
    initial begin
        $display("\n========================================");
        $display("THREE BAND EQ COEFFICIENT TEST");
        $display("========================================\n");
        
        // Initialize
        rst_n = 0;
        audio_in = 0;
        audio_valid = 0;
        test_num = 0;
        error_count = 0;
        
        // Set default "safe" coefficients (unity gain allpass)
        b0_low = 18'h10000;  b1_low = 18'h00000;  b2_low = 18'h00000;
        a1_low = 18'h00000;  a2_low = 18'h00000;
        b0_mid = 18'h10000;  b1_mid = 18'h00000;  b2_mid = 18'h00000;
        a1_mid = 18'h00000;  a2_mid = 18'h00000;
        b0_high = 18'h10000; b1_high = 18'h00000; b2_high = 18'h00000;
        a1_high = 18'h00000; a2_high = 18'h00000;
        gain_low = 8'h40;   // 0.25 * 256 = 64
        gain_mid = 8'h40;
        gain_high = 8'h40;
        
        repeat(10) @(posedge clk);
        rst_n = 1;
        repeat(10) @(posedge clk);
        
        // TEST 1: Unity gain passthrough (your known working coefficients)
        // REPLACE THESE WITH YOUR ACTUAL WORKING COEFFICIENTS!
        test_num = 1;
        set_coefficients(
            18'h10000, 18'h00000, 18'h00000, 18'h00000, 18'h00000,  // Low
            18'h10000, 18'h00000, 18'h00000, 18'h00000, 18'h00000,  // Mid
            18'h10000, 18'h00000, 18'h00000, 18'h00000, 18'h00000,  // High
            8'h40, 8'h40, 8'h40  // Gains
        );
        send_test_signal(480, "SINE_1KHZ");
        print_results("Unity gain with 1kHz sine");
        
        // TEST 2: Test with impulse
        test_num = 2;
        send_test_signal(1000, "IMPULSE");
        print_results("Unity gain with impulse");
        
        // TEST 3: Low frequency (100Hz)
        test_num = 3;
        send_test_signal(480, "SINE_100HZ");
        print_results("Unity gain with 100Hz sine");
        
        // TEST 4: High frequency (10kHz)
        test_num = 4;
        send_test_signal(480, "SINE_10KHZ");
        print_results("Unity gain with 10kHz sine");
        
        // TEST 5: Frequency sweep
        test_num = 5;
        send_test_signal(4800, "SWEEP");
        print_results("Unity gain with frequency sweep");
        
        // TEST 6: Zero coefficients (should cause silence)
        test_num = 6;
        set_coefficients(
            18'h00000, 18'h00000, 18'h00000, 18'h00000, 18'h00000,
            18'h00000, 18'h00000, 18'h00000, 18'h00000, 18'h00000,
            18'h00000, 18'h00000, 18'h00000, 18'h00000, 18'h00000,
            8'h40, 8'h40, 8'h40
        );
        send_test_signal(480, "SINE_1KHZ");
        print_results("Zero coefficients (expect silence)");
        
        // TEST 7: High gain coefficients
        test_num = 7;
        set_coefficients(
            18'h20000, 18'h00000, 18'h00000, 18'h00000, 18'h00000,
            18'h20000, 18'h00000, 18'h00000, 18'h00000, 18'h00000,
            18'h20000, 18'h00000, 18'h00000, 18'h00000, 18'h00000,
            8'h40, 8'h40, 8'h40
        );
        send_test_signal(480, "SINE_1KHZ");
        print_results("2x gain coefficients");
        
        // TEST 8: Negative b0 coefficients
        test_num = 8;
        set_coefficients(
            -18'h10000, 18'h00000, 18'h00000, 18'h00000, 18'h00000,
            -18'h10000, 18'h00000, 18'h00000, 18'h00000, 18'h00000,
            -18'h10000, 18'h00000, 18'h00000, 18'h00000, 18'h00000,
            8'h40, 8'h40, 8'h40
        );
        send_test_signal(480, "SINE_1KHZ");
        print_results("Negative b0 (phase inversion)");
        
        // TEST 9: Non-zero feedback coefficients (potential instability)
        test_num = 9;
        set_coefficients(
            18'h10000, 18'h00000, 18'h00000, 18'h08000, 18'h00000,
            18'h10000, 18'h00000, 18'h00000, 18'h08000, 18'h00000,
            18'h10000, 18'h00000, 18'h00000, 18'h08000, 18'h00000,
            8'h40, 8'h40, 8'h40
        );
        send_test_signal(480, "SINE_1KHZ");
        print_results("With feedback a1=0.5");
        
        // TEST 10: Typical lowpass filter coefficients
        test_num = 10;
        set_coefficients(
            18'h02000, 18'h04000, 18'h02000, -18'h0F000, 18'h08000,  // Low pass
            18'h10000, 18'h00000, 18'h00000, 18'h00000, 18'h00000,   // Unity mid
            18'h10000, 18'h00000, 18'h00000, 18'h00000, 18'h00000,   // Unity high
            8'h40, 8'h40, 8'h40
        );
        send_test_signal(480, "SINE_100HZ");
        print_results("Lowpass filter with 100Hz (should pass)");
        
        test_num = 11;
        send_test_signal(480, "SINE_10KHZ");
        print_results("Lowpass filter with 10kHz (should attenuate)");
        
        // Summary
        $display("\n========================================");
        $display("TEST SUMMARY");
        $display("========================================");
        $display("Total tests: %0d", test_num);
        $display("Failed tests: %0d", error_count);
        $display("========================================\n");
        
        if (error_count == 0)
            $display("ALL TESTS PASSED!\n");
        else
            $display("SOME TESTS FAILED - Review results above\n");
        
        $finish;
    end
    
    // Timeout watchdog
    initial begin
        #(CLK_PERIOD * 1000000);  // 20ms timeout
        $display("ERROR: Test timeout!");
        $finish;
    end

endmodule