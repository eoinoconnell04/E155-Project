`timescale 1ns / 1ps

module tb_three_band_eq_cascade;

    // Parameters
    parameter CLK_PERIOD = 20;  // 50MHz clock (matches your HSOSC)
    parameter SAMPLE_RATE = 48000;
    parameter real PI = 3.14159265359;
    
    // Testbench signals
    logic clk;
    logic l_r_clk;
    logic reset;
    logic signed [15:0] audio_in;
    logic signed [15:0] audio_out;
    logic mac_a;
    
    // Coefficient registers (Q2.14 format)
    logic signed [15:0] low_b0, low_b1, low_b2, low_a1, low_a2;
    logic signed [15:0] mid_b0, mid_b1, mid_b2, mid_a1, mid_a2;
    logic signed [15:0] high_b0, high_b1, high_b2, high_a1, high_a2;
    
    // Test tracking
    integer test_num;
    integer sample_count;
    integer error_count;
    real max_output, min_output, sum_output, avg_output;
    integer silent_samples, clipped_samples;
    
    // L/R clock generation (48kHz sample rate from 50MHz clock)
    integer lr_clk_counter;
    localparam LR_CLK_DIV = 521;  // 50MHz / 48kHz / 2 ≈ 520.8
    
    always_ff @(posedge clk) begin
        if (!reset) begin
            lr_clk_counter <= 0;
            l_r_clk <= 0;
        end else begin
            lr_clk_counter <= lr_clk_counter + 1;
            if (lr_clk_counter >= LR_CLK_DIV) begin
                lr_clk_counter <= 0;
                l_r_clk <= ~l_r_clk;  // Toggle every 521 clocks
            end
        end
    end
    
    // DUT instantiation
    three_band_eq dut (
        .clk(clk),
        .l_r_clk(l_r_clk),
        .reset(reset),
        .audio_in(audio_in),
        // Low-pass filter coefficients
        .low_b0(low_b0),
        .low_b1(low_b1),
        .low_b2(low_b2),
        .low_a1(low_a1),
        .low_a2(low_a2),
        // Mid-pass filter coefficients
        .mid_b0(mid_b0),
        .mid_b1(mid_b1),
        .mid_b2(mid_b2),
        .mid_a1(mid_a1),
        .mid_a2(mid_a2),
        // High-pass filter coefficients
        .high_b0(high_b0),
        .high_b1(high_b1),
        .high_b2(high_b2),
        .high_a1(high_a1),
        .high_a2(high_a2),
        .audio_out(audio_out),
        .mac_a(mac_a)
    );
    
    // Clock generation
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end
    
    // Convert Q2.14 to real
    function real q214_to_real;
        input signed [15:0] fixed_val;
        begin
            q214_to_real = $itor(fixed_val) / 16384.0;  // 2^14
        end
    endfunction
    
    // Convert real to Q2.14
    function logic signed [15:0] real_to_q214;
        input real val;
        begin
            real_to_q214 = $rtoi(val * 16384.0);
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
        input signed [15:0] sample;
        real sample_real;
        begin
            sample_real = q214_to_real(sample);
            sample_count = sample_count + 1;
            sum_output = sum_output + sample_real;
            
            if (sample_real > max_output) max_output = sample_real;
            if (sample_real < min_output) min_output = sample_real;
            
            // Check for silence (< -60dB, approx < 0.001)
            if (sample > -33 && sample < 33) silent_samples = silent_samples + 1;
            
            // Check for clipping/overflow
            if (sample_real > 1.8 || sample_real < -1.8) clipped_samples = clipped_samples + 1;
        end
    endtask
    
    // Task to print coefficient values
    task print_coeffs;
        input [200*8:1] band_name;
        input signed [15:0] b0, b1, b2, a1, a2;
        begin
            $display("  %s: b0=%f(%h) b1=%f(%h) b2=%f(%h) a1=%f(%h) a2=%f(%h)",
                band_name,
                q214_to_real(b0), b0,
                q214_to_real(b1), b1,
                q214_to_real(b2), b2,
                q214_to_real(a1), a1,
                q214_to_real(a2), a2);
        end
    endtask
    
    // Task to print test results
    task print_results;
        input [200*8:1] test_name;
        real theoretical_cascade_gain;
        begin
            avg_output = sum_output / sample_count;
            
            // Calculate theoretical cascade gain
            theoretical_cascade_gain = q214_to_real(low_b0) * q214_to_real(mid_b0) * q214_to_real(high_b0);
            
            $display("========================================");
            $display("Test %0d: %s", test_num, test_name);
            print_coeffs("Low ", low_b0, low_b1, low_b2, low_a1, low_a2);
            print_coeffs("Mid ", mid_b0, mid_b1, mid_b2, mid_a1, mid_a2);
            print_coeffs("High", high_b0, high_b1, high_b2, high_a1, high_a2);
            $display("  Theoretical cascade gain (b0*b0*b0): %f (%.1f dB)", 
                theoretical_cascade_gain, 
                20.0*$log10(theoretical_cascade_gain + 1e-10));
            $display("----------------------------------------");
            $display("Samples processed: %0d", sample_count);
            $display("Max output: %f (%.1f dB)", max_output, 20.0*$log10($abs(max_output)+1e-10));
            $display("Min output: %f (%.1f dB)", min_output, 20.0*$log10($abs(min_output)+1e-10));
            $display("Avg output: %f", avg_output);
            $display("Silent samples (< 0.002): %0d (%.1f%%)", silent_samples, 100.0*silent_samples/sample_count);
            $display("Overflow samples (> 1.8): %0d (%.1f%%)", clipped_samples, 100.0*clipped_samples/sample_count);
            
            // Analyze results
            if (silent_samples == sample_count) begin
                $display("*** FAILURE: All output is SILENT! ***");
                error_count = error_count + 1;
            end else if (silent_samples > sample_count * 0.9) begin
                $display("*** WARNING: Output extremely weak (>90%% near-silent) ***");
            end else if (clipped_samples > sample_count/10) begin
                $display("*** WARNING: High overflow rate (>10%%) ***");
            end else if (max_output < 0.01 && min_output > -0.01) begin
                $display("*** WARNING: Very low output level ***");
            end else begin
                $display("PASS: Output appears normal");
            end
            $display("========================================\n");
        end
    endtask
    
    // Task to set coefficients
    task set_coefficients;
        input signed [15:0] l_b0, l_b1, l_b2, l_a1, l_a2;
        input signed [15:0] m_b0, m_b1, m_b2, m_a1, m_a2;
        input signed [15:0] h_b0, h_b1, h_b2, h_a1, h_a2;
        begin
            low_b0 = l_b0; low_b1 = l_b1; low_b2 = l_b2;
            low_a1 = l_a1; low_a2 = l_a2;
            mid_b0 = m_b0; mid_b1 = m_b1; mid_b2 = m_b2;
            mid_a1 = m_a1; mid_a2 = m_a2;
            high_b0 = h_b0; high_b1 = h_b1; high_b2 = h_b2;
            high_a1 = h_a1; high_a2 = h_a2;
        end
    endtask
    
    // Task to send test signal and wait for l_r_clk edges
    task send_test_signal;
        input integer num_samples;
        input real frequency_hz;
        input real amplitude;
        integer i;
        real phase;
        real sample_val;
        logic last_l_r_clk;
        begin
            reset_stats();
            phase = 0.0;
            last_l_r_clk = l_r_clk;
            
            for (i = 0; i < num_samples; i = i + 1) begin
                // Generate test signal
                if (frequency_hz == 0.0) begin
                    // DC signal
                    audio_in = real_to_q214(amplitude);
                end else if (frequency_hz < 0.0) begin
                    // Impulse
                    if (i == 10)
                        audio_in = real_to_q214(amplitude);
                    else
                        audio_in = 16'h0000;
                end else begin
                    // Sine wave
                    sample_val = amplitude * $sin(2.0 * PI * frequency_hz * i / SAMPLE_RATE);
                    audio_in = real_to_q214(sample_val);
                end
                
                // Wait for l_r_clk edge (new sample)
                @(posedge clk);
                while (l_r_clk == last_l_r_clk) begin
                    @(posedge clk);
                end
                last_l_r_clk = l_r_clk;
                
                // Collect output sample (with small delay to allow filter to settle)
                repeat(10) @(posedge clk);
                update_stats(audio_out);
            end
        end
    endtask
    
    // Main test sequence
    initial begin
        $display("\n========================================");
        $display("THREE BAND EQ CASCADE COEFFICIENT TEST");
        $display("Testing with Q2.14 format coefficients");
        $display("========================================\n");
        
        // Initialize
        reset = 0;
        audio_in = 0;
        test_num = 0;
        error_count = 0;
        
        // Initialize with zero coefficients
        low_b0 = 0; low_b1 = 0; low_b2 = 0; low_a1 = 0; low_a2 = 0;
        mid_b0 = 0; mid_b1 = 0; mid_b2 = 0; mid_a1 = 0; mid_a2 = 0;
        high_b0 = 0; high_b1 = 0; high_b2 = 0; high_a1 = 0; high_a2 = 0;
        
        repeat(10) @(posedge clk);
        reset = 1;
        repeat(100) @(posedge clk);
        
        // TEST 1: Your current coefficients (all b0 = 0x4000 = 1.0)
        test_num = 1;
        set_coefficients(
            16'sh4000, 16'sh0000, 16'sh0000, 16'sh0000, 16'sh0000,  // Low
            16'sh4000, 16'sh0000, 16'sh0000, 16'sh0000, 16'sh0000,  // Mid
            16'sh4000, 16'sh0000, 16'sh0000, 16'sh0000, 16'sh0000   // High
        );
        send_test_signal(100, 1000.0, 0.5);  // 1kHz sine, 0.5 amplitude
        print_results("Current coefficients (0x4000) with 1kHz sine");
        
        // TEST 2: Check if 0x4000 is really 1.0 or 0.25
        test_num = 2;
        $display("Checking Q2.14 interpretation:");
        $display("  0x4000 decimal = %0d", 16'sh4000);
        $display("  As Q2.14: %0d / 16384 = %f", 16'sh4000, q214_to_real(16'sh4000));
        $display("  Cascade gain: %f^3 = %f", q214_to_real(16'sh4000), 
            q214_to_real(16'sh4000) * q214_to_real(16'sh4000) * q214_to_real(16'sh4000));
        
        // TEST 3: True unity gain (if 0x4000 was 0.25, try compensating)
        test_num = 3;
        set_coefficients(
            16'sh4000, 16'sh0000, 16'sh0000, 16'sh0000, 16'sh0000,  // Low: 1.0
            16'sh4000, 16'sh0000, 16'sh0000, 16'sh0000, 16'sh0000,  // Mid: 1.0
            16'sh7FFF, 16'sh0000, 16'sh0000, 16'sh0000, 16'sh0000   // High: ~2.0 (compensate)
        );
        send_test_signal(100, 1000.0, 0.5);
        print_results("Compensated high band (0x7FFF)");
        
        // TEST 4: All unity - try 0x4000 for all
        test_num = 4;
        set_coefficients(
            16'h4000, 16'h0000, 16'h0000, 16'h0000, 16'h0000,
            16'h4000, 16'h0000, 16'h0000, 16'h0000, 16'h0000,
            16'h4000, 16'h0000, 16'h0000, 16'h0000, 16'h0000
        );
        send_test_signal(100, 1000.0, 0.5);
        print_results("All 0x4000 unsigned");
        
        // TEST 5: Impulse response
        test_num = 5;
        set_coefficients(
            16'sh4000, 16'sh0000, 16'sh0000, 16'sh0000, 16'sh0000,
            16'sh4000, 16'sh0000, 16'sh0000, 16'sh0000, 16'sh0000,
            16'sh4000, 16'sh0000, 16'sh0000, 16'sh0000, 16'sh0000
        );
        send_test_signal(50, -1.0, 0.5);  // Impulse
        print_results("Impulse response");
        
        // TEST 6: DC response
        test_num = 6;
        send_test_signal(50, 0.0, 0.5);  // DC
        print_results("DC response");
        
        // TEST 7: Low frequency (100Hz)
        test_num = 7;
        send_test_signal(100, 100.0, 0.5);
        print_results("100Hz sine");
        
        // TEST 8: High frequency (10kHz)
        test_num = 8;
        send_test_signal(100, 10000.0, 0.5);
        print_results("10kHz sine");
        
        // TEST 9: Try bypassing cascade - only high band active
        test_num = 9;
        set_coefficients(
            16'sh4000, 16'sh0000, 16'sh0000, 16'sh0000, 16'sh0000,  // Low: passthrough
            16'sh4000, 16'sh0000, 16'sh0000, 16'sh0000, 16'sh0000,  // Mid: passthrough
            16'sh4000, 16'sh0000, 16'sh0000, 16'sh0000, 16'sh0000   // High: passthrough
        );
        send_test_signal(100, 1000.0, 0.5);
        print_results("All stages 1.0 gain");
        
        // Summary
        $display("\n========================================");
        $display("TEST SUMMARY");
        $display("========================================");
        $display("Total tests: %0d", test_num);
        $display("Failed tests: %0d", error_count);
        if (error_count == 0)
            $display("ALL TESTS PASSED!");
        else
            $display("SOME TESTS FAILED - Review results above");
        $display("========================================\n");
        
        $finish;
    end
    
    // Timeout watchdog
    initial begin
        #100ms;
        $display("ERROR: Test timeout!");
        $finish;
    end

endmodule