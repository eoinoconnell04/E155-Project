`timescale 1ns/1ps

module three_band_eq_tb;

    // Clock and reset
    logic clk;
    logic l_r_clk;
    logic reset;
    
    // Audio signals
    logic signed [15:0] audio_in;
    logic signed [15:0] audio_out;
    
    // Test parameters
    localparam real CLK_PERIOD = 10.0;  // 100 MHz system clock
    localparam real SAMPLE_RATE = 48000.0;  // 48 kHz audio
    localparam real L_R_PERIOD = 1_000_000_000.0 / SAMPLE_RATE;  // ~20.83 us
    
    // System clock generation (100 MHz)
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end
    
    // L/R clock generation (48 kHz)
    initial begin
        l_r_clk = 0;
        forever #(L_R_PERIOD/2) l_r_clk = ~l_r_clk;
    end
    
    // DUT instantiation
    three_band_eq dut (
        .clk(clk),
        .l_r_clk(l_r_clk),
        .reset(reset),
        .audio_in(audio_in),
        .audio_out(audio_out)
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
    
    // Task to send a sine wave at given frequency
    task send_sine_wave(input real freq, input real amp, input integer num_samples, input string description);
        integer i;
        real time_sec, sample_value;
        begin
            $display("\n=== %s ===", description);
            $display("Frequency: %0.1f Hz, Amplitude: %0.2f, Samples: %0d", freq, amp, num_samples);
            
            for (i = 0; i < num_samples; i++) begin
                @(posedge l_r_clk);
                time_sec = real'(i) / SAMPLE_RATE;
                sample_value = amp * $sin(2.0 * 3.14159265359 * freq * time_sec);
                audio_in = real_to_q2_14(sample_value);
                
                // Show output every 50 samples
                if (i % 50 == 0) begin
                    $display("Sample %4d: In=%0.4f, Out=%0.4f, Low=%0.4f, Mid=%0.4f, High=%0.4f", 
                             i, 
                             q2_14_to_real(audio_in), 
                             q2_14_to_real(audio_out),
                             q2_14_to_real(dut.low_band_out),
                             q2_14_to_real(dut.mid_band_out),
                             q2_14_to_real(dut.high_band_out));
                end
            end
            
            // Show final values
            $display("Final: In=%0.4f, Out=%0.4f, Low=%0.4f, Mid=%0.4f, High=%0.4f", 
                     q2_14_to_real(audio_in), 
                     q2_14_to_real(audio_out),
                     q2_14_to_real(dut.low_band_out),
                     q2_14_to_real(dut.mid_band_out),
                     q2_14_to_real(dut.high_band_out));
        end
    endtask
    
    // Task to send impulse
    task send_impulse(input real amp, input integer num_samples);
        integer i;
        begin
            $display("\n=== Impulse Response Test ===");
            $display("Amplitude: %0.2f", amp);
            
            for (i = 0; i < num_samples; i++) begin
                @(posedge l_r_clk);
                if (i == 0)
                    audio_in = real_to_q2_14(amp);
                else
                    audio_in = 16'd0;
                
                if (i < 30 || i % 50 == 0) begin
                    $display("Sample %4d: In=%0.4f, Out=%0.4f, Low=%0.4f, Mid=%0.4f, High=%0.4f", 
                             i,
                             q2_14_to_real(audio_in), 
                             q2_14_to_real(audio_out),
                             q2_14_to_real(dut.low_band_out),
                             q2_14_to_real(dut.mid_band_out),
                             q2_14_to_real(dut.high_band_out));
                end
            end
        end
    endtask
    
    // Task to send DC value
    task send_dc(input real dc_value, input integer num_samples);
        integer i;
        begin
            $display("\n=== DC Test ===");
            $display("DC Value: %0.4f for %0d samples", dc_value, num_samples);
            
            for (i = 0; i < num_samples; i++) begin
                @(posedge l_r_clk);
                audio_in = real_to_q2_14(dc_value);
                
                if (i % 50 == 0) begin
                    $display("Sample %4d: In=%0.4f, Out=%0.4f, Low=%0.4f, Mid=%0.4f, High=%0.4f", 
                             i,
                             q2_14_to_real(audio_in), 
                             q2_14_to_real(audio_out),
                             q2_14_to_real(dut.low_band_out),
                             q2_14_to_real(dut.mid_band_out),
                             q2_14_to_real(dut.high_band_out));
                end
            end
        end
    endtask
    
    // Main test sequence
    initial begin
        $display("=== Three-Band Equalizer Testbench ===");
        $display("System Clock: %0.1f MHz", 1000.0/CLK_PERIOD);
        $display("Sample Rate: %0.1f kHz", SAMPLE_RATE/1000.0);
        $display("Low Band: Low-pass <500 Hz");
        $display("Mid Band: Band-pass 500Hz-5kHz");
        $display("High Band: High-pass >5kHz");
        $display("");
        
        // Initialize
        reset = 0;
        audio_in = 16'd0;
        
        // Reset pulse
        #100;
        reset = 1;
        #100;
        
        // Wait for L/R clock to settle
        repeat(20) @(posedge l_r_clk);
        
        // Test 1: Impulse response
        send_impulse(1.0, 200);
        
        // Test 2: Low frequency (should pass through low-pass)
        send_sine_wave(100.0, 0.5, 300, "Low Frequency Test (100 Hz)");
        
        // Test 3: Mid-low frequency (transition between low and mid)
        send_sine_wave(500.0, 0.5, 300, "Cutoff Frequency Test (500 Hz)");
        
        // Test 4: Mid frequency (should pass through band-pass)
        send_sine_wave(1000.0, 0.5, 300, "Mid Frequency Test (1 kHz)");
        
        // Test 5: Mid-high frequency (should pass through band-pass)
        send_sine_wave(3000.0, 0.5, 300, "Upper Mid Frequency Test (3 kHz)");
        
        // Test 6: High frequency transition
        send_sine_wave(5000.0, 0.5, 300, "High Cutoff Frequency Test (5 kHz)");
        
        // Test 7: Very high frequency (should pass through high-pass)
        send_sine_wave(10000.0, 0.5, 300, "High Frequency Test (10 kHz)");
        
        // Test 8: DC (should be filtered out by band-pass and high-pass)
        send_dc(0.5, 200);
        
        // Test 9: Sweep test - mixed frequencies
        $display("\n=== Mixed Frequency Test ===");
        $display("100 Hz + 1000 Hz + 10000 Hz combined");
        for (int i = 0; i < 500; i++) begin
            real time_sec, sample_value;
            @(posedge l_r_clk);
            time_sec = real'(i) / SAMPLE_RATE;
            sample_value = 0.2 * $sin(2.0 * 3.14159265359 * 100.0 * time_sec) +
                          0.2 * $sin(2.0 * 3.14159265359 * 1000.0 * time_sec) +
                          0.2 * $sin(2.0 * 3.14159265359 * 10000.0 * time_sec);
            audio_in = real_to_q2_14(sample_value);
            
            if (i % 100 == 0) begin
                $display("Sample %4d: In=%0.4f, Out=%0.4f, Low=%0.4f, Mid=%0.4f, High=%0.4f", 
                         i,
                         q2_14_to_real(audio_in), 
                         q2_14_to_real(audio_out),
                         q2_14_to_real(dut.low_band_out),
                         q2_14_to_real(dut.mid_band_out),
                         q2_14_to_real(dut.high_band_out));
            end
        end
        
        // Finish
        repeat(100) @(posedge l_r_clk);
        
        $display("\n=== Test Summary ===");
        $display("If you see non-zero outputs for each band, the filters are working!");
        $display("Expected behavior:");
        $display("  - Low band: High output at 100 Hz, low at high frequencies");
        $display("  - Mid band: High output at 1-3 kHz, low at extremes");
        $display("  - High band: High output at 10 kHz, low at low frequencies");
        $display("\n=== Test Complete ===");
        $finish;
    end
    
    // Timeout watchdog
    initial begin
        #200_000_000;  // 200 ms timeout
        $display("ERROR: Test timeout!");
        $finish;
    end
    
    // Optional: Dump waveforms
    initial begin
        $dumpfile("three_band_eq_tb.vcd");
        $dumpvars(0, three_band_eq_tb);
    end

endmodule