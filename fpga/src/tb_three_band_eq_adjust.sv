`timescale 1ns / 1ps

/*
Testbench for three_band_eq_adjust module
Tests the 3-band equalizer with various input signals and coefficient settings
*/

module tb_three_band_eq_adjust();

    // Testbench parameters
    parameter CLK_PERIOD = 10;      // 100 MHz system clock
    parameter LR_CLK_PERIOD = 2083; // ~48 kHz audio sample rate
    parameter PI = 3.14159265359;
    
    // DUT signals
    logic clk;
    logic l_r_clk;
    logic reset;
    logic signed [15:0] audio_in;
    
    // Low-pass filter coefficients
    logic signed [15:0] low_b0, low_b1, low_b2, low_a1, low_a2;
    
    // Band-pass filter coefficients
    logic signed [15:0] mid_b0, mid_b1, mid_b2, mid_a1, mid_a2;
    
    // High-pass filter coefficients
    logic signed [15:0] high_b0, high_b1, high_b2, high_a1, high_a2;
    
    // Outputs
    logic signed [15:0] audio_out;
    logic signed [15:0] low_band_out;
    logic signed [15:0] mid_band_out;
    logic signed [15:0] high_band_out;
    
    // Testbench variables
    integer sample_count;
    integer test_num;
    real freq_hz;
    real amplitude;
    
    // Instantiate DUT
    three_band_eq_adjust dut (
        .clk(clk),
        .l_r_clk(l_r_clk),
        .reset(reset),
        .audio_in(audio_in),
        .low_b0(low_b0), .low_b1(low_b1), .low_b2(low_b2), .low_a1(low_a1), .low_a2(low_a2),
        .mid_b0(mid_b0), .mid_b1(mid_b1), .mid_b2(mid_b2), .mid_a1(mid_a1), .mid_a2(mid_a2),
        .high_b0(high_b0), .high_b1(high_b1), .high_b2(high_b2), .high_a1(high_a1), .high_a2(high_a2),
        .audio_out(audio_out),
        .low_band_out(low_band_out),
        .mid_band_out(mid_band_out),
        .high_band_out(high_band_out)
    );
    
    // Clock generation
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end
    
    // L/R clock generation
    initial begin
        l_r_clk = 0;
        forever #(LR_CLK_PERIOD/2) l_r_clk = ~l_r_clk;
    end
    
    // Helper function to convert real to Q2.14 fixed point
    function logic [15:0] real_to_q2_14(input real value);
        real scaled;
        int scaled_int;
        scaled = value * (2.0 ** 14);
        scaled_int = int'(scaled);
        return scaled_int[15:0];
    endfunction
    
    // Helper function to convert Q2.14 to real
    function real q2_14_to_real(input logic signed [15:0] value);
        real result;
        result = real'(value) / (2.0 ** 14);
        return result;
    endfunction
    
    // Task to wait for one sample period
    task wait_sample_period();
        @(posedge l_r_clk or negedge l_r_clk);
    endtask
    
    // Task to apply a sample and wait for processing
    task apply_sample(input logic signed [15:0] sample);
        audio_in = sample;
        wait_sample_period();
        repeat(20) @(posedge clk);  // Wait for processing
        sample_count++;
    endtask
    
    // Task to generate and apply a sinusoidal sample
    task apply_sine_sample(input real frequency, input real amplitude, input integer sample_num);
        real sample_rate = 48000.0;
        real phase = 2.0 * PI * frequency * sample_num / sample_rate;
        real sine_value = amplitude * $sin(phase);
        logic signed [15:0] sample_q2_14;
        
        sample_q2_14 = real_to_q2_14(sine_value);
        apply_sample(sample_q2_14);
    endtask
    
    // Task to set unity gain on low band, zero on others
    task set_low_band_only();
        // Low-pass: unity gain
        low_b0 = real_to_q2_14(1.0);
        low_b1 = real_to_q2_14(0.0);
        low_b2 = real_to_q2_14(0.0);
        low_a1 = real_to_q2_14(0.0);
        low_a2 = real_to_q2_14(0.0);
        
        // Mid: zero
        mid_b0 = real_to_q2_14(0.0);
        mid_b1 = real_to_q2_14(0.0);
        mid_b2 = real_to_q2_14(0.0);
        mid_a1 = real_to_q2_14(0.0);
        mid_a2 = real_to_q2_14(0.0);
        
        // High: zero
        high_b0 = real_to_q2_14(0.0);
        high_b1 = real_to_q2_14(0.0);
        high_b2 = real_to_q2_14(0.0);
        high_a1 = real_to_q2_14(0.0);
        high_a2 = real_to_q2_14(0.0);
    endtask
    
    // Task to set unity gain on mid band, zero on others
    task set_mid_band_only();
        // Low: zero
        low_b0 = real_to_q2_14(0.0);
        low_b1 = real_to_q2_14(0.0);
        low_b2 = real_to_q2_14(0.0);
        low_a1 = real_to_q2_14(0.0);
        low_a2 = real_to_q2_14(0.0);
        
        // Mid: unity gain
        mid_b0 = real_to_q2_14(1.0);
        mid_b1 = real_to_q2_14(0.0);
        mid_b2 = real_to_q2_14(0.0);
        mid_a1 = real_to_q2_14(0.0);
        mid_a2 = real_to_q2_14(0.0);
        
        // High: zero
        high_b0 = real_to_q2_14(0.0);
        high_b1 = real_to_q2_14(0.0);
        high_b2 = real_to_q2_14(0.0);
        high_a1 = real_to_q2_14(0.0);
        high_a2 = real_to_q2_14(0.0);
    endtask
    
    // Task to set unity gain on high band, zero on others
    task set_high_band_only();
        // Low: zero
        low_b0 = real_to_q2_14(0.0);
        low_b1 = real_to_q2_14(0.0);
        low_b2 = real_to_q2_14(0.0);
        low_a1 = real_to_q2_14(0.0);
        low_a2 = real_to_q2_14(0.0);
        
        // Mid: zero
        mid_b0 = real_to_q2_14(0.0);
        mid_b1 = real_to_q2_14(0.0);
        mid_b2 = real_to_q2_14(0.0);
        mid_a1 = real_to_q2_14(0.0);
        mid_a2 = real_to_q2_14(0.0);
        
        // High: unity gain
        high_b0 = real_to_q2_14(1.0);
        high_b1 = real_to_q2_14(0.0);
        high_b2 = real_to_q2_14(0.0);
        high_a1 = real_to_q2_14(0.0);
        high_a2 = real_to_q2_14(0.0);
    endtask
    
    // Task to set all bands to unity gain (full passthrough)
    task set_all_bands_unity();
        // Low: unity
        low_b0 = real_to_q2_14(1.0);
        low_b1 = real_to_q2_14(0.0);
        low_b2 = real_to_q2_14(0.0);
        low_a1 = real_to_q2_14(0.0);
        low_a2 = real_to_q2_14(0.0);
        
        // Mid: unity
        mid_b0 = real_to_q2_14(1.0);
        mid_b1 = real_to_q2_14(0.0);
        mid_b2 = real_to_q2_14(0.0);
        mid_a1 = real_to_q2_14(0.0);
        mid_a2 = real_to_q2_14(0.0);
        
        // High: unity
        high_b0 = real_to_q2_14(1.0);
        high_b1 = real_to_q2_14(0.0);
        high_b2 = real_to_q2_14(0.0);
        high_a1 = real_to_q2_14(0.0);
        high_a2 = real_to_q2_14(0.0);
    endtask
    
    // Task to set actual filter coefficients
    task set_actual_filter_coefficients();
        // Low-pass filter coefficients (500Hz cutoff, Fs=48kHz)
        low_b0 = 16'sh0147;  // ~0.020 in Q2.14
        low_b1 = 16'sh028E;  // ~0.040 in Q2.14
        low_b2 = 16'sh0147;  // ~0.020 in Q2.14
        low_a1 = 16'sh6A3D;  // ~1.659 in Q2.14
        low_a2 = 16'shD89F;  // ~-0.618 in Q2.14
        
        // Band-pass filter coefficients (500Hz-5kHz)
        mid_b0 = 16'sh0CCC;  // ~0.200 in Q2.14
        mid_b1 = 16'sh0000;  // 0.0 in Q2.14
        mid_b2 = 16'shF334;  // ~-0.200 in Q2.14
        mid_a1 = 16'sh5A82;  // ~1.414 in Q2.14
        mid_a2 = 16'shE666;  // ~-0.400 in Q2.14
        
        // High-pass filter coefficients (5kHz cutoff)
        high_b0 = 16'sh2E8B;  // ~0.728 in Q2.14
        high_b1 = 16'shA2EA;  // ~-1.456 in Q2.14
        high_b2 = 16'sh2E8B;  // ~0.728 in Q2.14
        high_a1 = 16'shA5C3;  // ~-1.407 in Q2.14
        high_a2 = 16'sh1F5C;  // ~0.490 in Q2.14
    endtask
    
    // Main test sequence
    initial begin
        $display("========================================");
        $display("3-Band Equalizer Testbench");
        $display("========================================\n");
        
        // Initialize signals
        reset = 0;
        audio_in = 0;
        sample_count = 0;
        test_num = 1;
        
        // Initialize all coefficients to zero
        low_b0 = 0; low_b1 = 0; low_b2 = 0; low_a1 = 0; low_a2 = 0;
        mid_b0 = 0; mid_b1 = 0; mid_b2 = 0; mid_a1 = 0; mid_a2 = 0;
        high_b0 = 0; high_b1 = 0; high_b2 = 0; high_a1 = 0; high_a2 = 0;
        
        // Reset sequence
        repeat(5) @(posedge clk);
        reset = 1;
        repeat(5) @(posedge clk);
        
        $display("Reset complete. Starting tests...\n");
        
        // ====================================================================
        // TEST 1: Low band only (unity gain) - verify isolation
        // ====================================================================
        $display("TEST %0d: Low Band Only (Unity Gain)", test_num++);
        set_low_band_only();
        sample_count = 0;
        repeat(3) @(posedge clk);
        
        apply_sample(real_to_q2_14(0.5));
        $display("Sample %0d: In=0.5, Low=%f, Mid=%f, High=%f, Out=%f", 
                 sample_count, q2_14_to_real(low_band_out), q2_14_to_real(mid_band_out),
                 q2_14_to_real(high_band_out), q2_14_to_real(audio_out));
        
        apply_sample(real_to_q2_14(-0.25));
        $display("Sample %0d: In=-0.25, Low=%f, Mid=%f, High=%f, Out=%f", 
                 sample_count, q2_14_to_real(low_band_out), q2_14_to_real(mid_band_out),
                 q2_14_to_real(high_band_out), q2_14_to_real(audio_out));
        
        $display("");
        
        // ====================================================================
        // TEST 2: Mid band only (unity gain) - verify isolation
        // ====================================================================
        $display("TEST %0d: Mid Band Only (Unity Gain)", test_num++);
        set_mid_band_only();
        sample_count = 0;
        repeat(3) @(posedge clk);
        
        apply_sample(real_to_q2_14(0.5));
        $display("Sample %0d: In=0.5, Low=%f, Mid=%f, High=%f, Out=%f", 
                 sample_count, q2_14_to_real(low_band_out), q2_14_to_real(mid_band_out),
                 q2_14_to_real(high_band_out), q2_14_to_real(audio_out));
        
        apply_sample(real_to_q2_14(-0.25));
        $display("Sample %0d: In=-0.25, Low=%f, Mid=%f, High=%f, Out=%f", 
                 sample_count, q2_14_to_real(low_band_out), q2_14_to_real(mid_band_out),
                 q2_14_to_real(high_band_out), q2_14_to_real(audio_out));
        
        $display("");
        
        // ====================================================================
        // TEST 3: High band only (unity gain) - verify isolation
        // ====================================================================
        $display("TEST %0d: High Band Only (Unity Gain)", test_num++);
        set_high_band_only();
        sample_count = 0;
        repeat(3) @(posedge clk);
        
        apply_sample(real_to_q2_14(0.5));
        $display("Sample %0d: In=0.5, Low=%f, Mid=%f, High=%f, Out=%f", 
                 sample_count, q2_14_to_real(low_band_out), q2_14_to_real(mid_band_out),
                 q2_14_to_real(high_band_out), q2_14_to_real(audio_out));
        
        apply_sample(real_to_q2_14(-0.25));
        $display("Sample %0d: In=-0.25, Low=%f, Mid=%f, High=%f, Out=%f", 
                 sample_count, q2_14_to_real(low_band_out), q2_14_to_real(mid_band_out),
                 q2_14_to_real(high_band_out), q2_14_to_real(audio_out));
        
        $display("");
        
        // ====================================================================
        // TEST 4: All bands unity gain - should output 3x input
        // ====================================================================
        $display("TEST %0d: All Bands Unity Gain (3x gain)", test_num++);
        set_all_bands_unity();
        sample_count = 0;
        repeat(3) @(posedge clk);
        
        apply_sample(real_to_q2_14(0.25));
        $display("Sample %0d: In=0.25, Low=%f, Mid=%f, High=%f, Out=%f (expect ~0.75)", 
                 sample_count, q2_14_to_real(low_band_out), q2_14_to_real(mid_band_out),
                 q2_14_to_real(high_band_out), q2_14_to_real(audio_out));
        
        apply_sample(real_to_q2_14(0.1));
        $display("Sample %0d: In=0.1, Low=%f, Mid=%f, High=%f, Out=%f (expect ~0.3)", 
                 sample_count, q2_14_to_real(low_band_out), q2_14_to_real(mid_band_out),
                 q2_14_to_real(high_band_out), q2_14_to_real(audio_out));
        
        $display("");
        
        // ====================================================================
        // TEST 5: Impulse response with actual filter coefficients
        // ====================================================================
        $display("TEST %0d: Impulse Response with Real Filter Coefficients", test_num++);
        set_actual_filter_coefficients();
        sample_count = 0;
        repeat(3) @(posedge clk);
        
        // Apply impulse
        apply_sample(real_to_q2_14(1.0));
        $display("Sample %0d: IMPULSE, Low=%f, Mid=%f, High=%f, Out=%f", 
                 sample_count, q2_14_to_real(low_band_out), q2_14_to_real(mid_band_out),
                 q2_14_to_real(high_band_out), q2_14_to_real(audio_out));
        
        // Watch response decay
        repeat(10) begin
            apply_sample(real_to_q2_14(0.0));
            $display("Sample %0d: Zero, Low=%f, Mid=%f, High=%f, Out=%f", 
                     sample_count, q2_14_to_real(low_band_out), q2_14_to_real(mid_band_out),
                     q2_14_to_real(high_band_out), q2_14_to_real(audio_out));
        end
        
        $display("");
        
        // ====================================================================
        // TEST 6: Low frequency sine wave (100 Hz) with real coefficients
        // ====================================================================
        $display("TEST %0d: Low Frequency Sine Wave (100 Hz)", test_num++);
        $display("Expected: Strong low band response, weak mid/high");
        set_actual_filter_coefficients();
        sample_count = 0;
        repeat(3) @(posedge clk);
        
        // Generate 20 samples of 100 Hz sine
        freq_hz = 100.0;
        amplitude = 0.5;
        repeat(20) begin
            apply_sine_sample(freq_hz, amplitude, sample_count);
            if (sample_count % 5 == 0) begin
                $display("Sample %0d: Low=%f, Mid=%f, High=%f, Out=%f", 
                         sample_count, q2_14_to_real(low_band_out), q2_14_to_real(mid_band_out),
                         q2_14_to_real(high_band_out), q2_14_to_real(audio_out));
            end
        end
        
        $display("");
        
        // ====================================================================
        // TEST 7: Mid frequency sine wave (1 kHz) with real coefficients
        // ====================================================================
        $display("TEST %0d: Mid Frequency Sine Wave (1 kHz)", test_num++);
        $display("Expected: Strong mid band response");
        set_actual_filter_coefficients();
        sample_count = 0;
        repeat(3) @(posedge clk);
        
        // Generate 20 samples of 1 kHz sine
        freq_hz = 1000.0;
        amplitude = 0.5;
        repeat(20) begin
            apply_sine_sample(freq_hz, amplitude, sample_count);
            if (sample_count % 5 == 0) begin
                $display("Sample %0d: Low=%f, Mid=%f, High=%f, Out=%f", 
                         sample_count, q2_14_to_real(low_band_out), q2_14_to_real(mid_band_out),
                         q2_14_to_real(high_band_out), q2_14_to_real(audio_out));
            end
        end
        
        $display("");
        
        // ====================================================================
        // TEST 8: High frequency sine wave (8 kHz) with real coefficients
        // ====================================================================
        $display("TEST %0d: High Frequency Sine Wave (8 kHz)", test_num++);
        $display("Expected: Strong high band response, weak low/mid");
        set_actual_filter_coefficients();
        sample_count = 0;
        repeat(3) @(posedge clk);
        
        // Generate 20 samples of 8 kHz sine
        freq_hz = 8000.0;
        amplitude = 0.5;
        repeat(20) begin
            apply_sine_sample(freq_hz, amplitude, sample_count);
            if (sample_count % 5 == 0) begin
                $display("Sample %0d: Low=%f, Mid=%f, High=%f, Out=%f", 
                         sample_count, q2_14_to_real(low_band_out), q2_14_to_real(mid_band_out),
                         q2_14_to_real(high_band_out), q2_14_to_real(audio_out));
            end
        end
        
        $display("");
        
        // ====================================================================
        // End of tests
        // ====================================================================
        $display("========================================");
        $display("All tests completed successfully!");
        $display("========================================");
        
        repeat(10) @(posedge clk);
        $finish;
    end
    
    // Timeout watchdog
    initial begin
        #20ms;
        $display("ERROR: Testbench timeout!");
        $finish;
    end

endmodule