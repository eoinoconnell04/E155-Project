`timescale 1ns/1ps

module iir_time_mux_accum_tb;

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
    
    // Low-pass filter coefficients (500Hz cutoff, Fs=48kHz, Q=0.707 Butterworth)
    logic signed [15:0] b0 = 16'sh0147;  // ~0.020 in Q2.14
    logic signed [15:0] b1 = 16'sh028E;  // ~0.040 in Q2.14
    logic signed [15:0] b2 = 16'sh0147;  // ~0.020 in Q2.14
    logic signed [15:0] a1 = 16'sh6A3D;  // ~1.659 in Q2.14
    logic signed [15:0] a2 = 16'shD89F;  // ~-0.618 in Q2.14
    
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
    iir_time_mux_accum dut (
        .clk(clk),
        .l_r_clk(l_r_clk),
        .reset(reset),
        .latest_sample(audio_in),
        .b0(b0),
        .b1(b1),
        .b2(b2),
        .a1(a1),
        .a2(a2),
        .filtered_output(audio_out)
    );
    
    // Test signals
    integer sample_count;
    real frequency;
    real amplitude;
    real time_sec;
    real sample_value;
    
    // Function to convert real to Q2.14 fixed point
    function signed [15:0] real_to_q2_14(real value);
        real scaled;
        scaled = value * (2.0 ** 14.0);  // Scale by 2^14
        if (scaled > 32767.0) scaled = 32767.0;
        if (scaled < -32768.0) scaled = -32768.0;
        return signed'(16'(scaled));
    endfunction
    
    // Function to convert Q2.14 to real
    function real q2_14_to_real(logic signed [15:0] value);
        return real'(value) / (2.0 ** 14.0);
    endfunction
    
    // Task to generate a sine wave at given frequency
    task send_sine_wave(input real freq, input real amp, input integer num_samples);
        integer i;
        begin
            $display("\n=== Sending %0d samples of %0.1f Hz sine wave, amplitude %0.2f ===", 
                     num_samples, freq, amp);
            
            for (i = 0; i < num_samples; i++) begin
                @(posedge l_r_clk);  // Wait for L/R clock edge (new sample time)
                time_sec = real'(i) / SAMPLE_RATE;
                sample_value = amp * $sin(2.0 * 3.14159265359 * freq * time_sec);
                audio_in = real_to_q2_14(sample_value);
                
                // Display every 100th sample
                if (i % 100 == 0) begin
                    $display("Sample %0d: Input=%0.4f, Output=%0.4f", 
                             i, q2_14_to_real(audio_in), q2_14_to_real(audio_out));
                end
            end
        end
    endtask
    
    // Task to send impulse (for impulse response testing)
    task send_impulse(input real amp, input integer num_samples);
        integer i;
        begin
            $display("\n=== Sending impulse response test ===");
            
            for (i = 0; i < num_samples; i++) begin
                @(posedge l_r_clk);
                if (i == 0)
                    audio_in = real_to_q2_14(amp);  // Impulse
                else
                    audio_in = 16'd0;  // Zero for rest
                
                if (i < 20 || i % 100 == 0) begin
                    $display("Sample %0d: Input=%0.4f, Output=%0.4f", 
                             i, q2_14_to_real(audio_in), q2_14_to_real(audio_out));
                end
            end
        end
    endtask
    
    // Task to send DC offset
    task send_dc(input real dc_value, input integer num_samples);
        integer i;
        begin
            $display("\n=== Sending DC value %0.4f for %0d samples ===", dc_value, num_samples);
            
            for (i = 0; i < num_samples; i++) begin
                @(posedge l_r_clk);
                audio_in = real_to_q2_14(dc_value);
                
                if (i % 100 == 0) begin
                    $display("Sample %0d: Input=%0.4f, Output=%0.4f", 
                             i, q2_14_to_real(audio_in), q2_14_to_real(audio_out));
                end
            end
        end
    endtask
    
    // Main test sequence
    initial begin
        $display("=== IIR Time-Multiplexed Filter Testbench ===");
        $display("System Clock: %0.1f MHz", 1000.0/CLK_PERIOD);
        $display("Sample Rate: %0.1f kHz", SAMPLE_RATE/1000.0);
        $display("Filter Type: Low-pass, 500Hz cutoff");
        $display("");
        
        // Initialize
        reset = 0;
        audio_in = 16'd0;
        sample_count = 0;
        
        // Reset pulse
        #100;
        reset = 1;
        #100;
        
        // Wait for L/R clock to settle
        repeat(10) @(posedge l_r_clk);
        
        // Test 1: Impulse response
        send_impulse(1.0, 200);
        
        // Test 2: Low frequency sine (should pass through filter)
        send_sine_wave(100.0, 0.5, 500);  // 100 Hz
        
        // Test 3: Cutoff frequency
        send_sine_wave(500.0, 0.5, 500);  // 500 Hz (cutoff)
        
        // Test 4: High frequency sine (should be attenuated)
        send_sine_wave(2000.0, 0.5, 500);  // 2 kHz
        
        // Test 5: Very high frequency (should be heavily attenuated)
        send_sine_wave(5000.0, 0.5, 500);  // 5 kHz
        
        // Test 6: DC offset test
        send_dc(0.25, 300);
        
        // Test 7: Mixed frequency test
        $display("\n=== Sending mixed frequency signal ===");
        for (int i = 0; i < 1000; i++) begin
            @(posedge l_r_clk);
            time_sec = real'(i) / SAMPLE_RATE;
            // Mix 100 Hz + 3000 Hz
            sample_value = 0.3 * $sin(2.0 * 3.14159265359 * 100.0 * time_sec) +
                          0.3 * $sin(2.0 * 3.14159265359 * 3000.0 * time_sec);
            audio_in = real_to_q2_14(sample_value);
            
            if (i % 100 == 0) begin
                $display("Sample %0d: Input=%0.4f, Output=%0.4f", 
                         i, q2_14_to_real(audio_in), q2_14_to_real(audio_out));
            end
        end
        
        // Finish
        repeat(100) @(posedge l_r_clk);
        $display("\n=== Test Complete ===");
        $finish;
    end
    
    // Timeout watchdog
    initial begin
        #50_000_000;  // 50 ms timeout
        $display("ERROR: Test timeout!");
        $finish;
    end
    
    // Optional: Dump waveforms
    initial begin
        $dumpfile("iir_time_mux_accum_tb.vcd");
        $dumpvars(0, iir_time_mux_accum_tb);
    end

endmodule