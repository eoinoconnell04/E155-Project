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
    
    // Coefficient variables (can be changed during test)
    logic signed [15:0] b0, b1, b2, a1, a2;
    
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
        integer temp;
        scaled = value * (2.0 ** 14.0);  // Scale by 2^14
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
    task send_sine_wave(input real freq, input real amp, input integer num_samples);
        integer i;
        begin
            $display("\n=== Sending %0d samples of %0.1f Hz sine wave, amplitude %0.2f ===", 
                     num_samples, freq, amp);
            
            for (i = 0; i < num_samples; i++) begin
                @(posedge l_r_clk);
                time_sec = real'(i) / SAMPLE_RATE;
                sample_value = amp * $sin(2.0 * 3.14159265359 * freq * time_sec);
                audio_in = real_to_q2_14(sample_value);
                
                if (i % 100 == 0) begin
                    $display("Sample %0d: Input=%0.4f, Output=%0.4f", 
                             i, q2_14_to_real(audio_in), q2_14_to_real(audio_out));
                end
            end
        end
    endtask
    
    // Task to send impulse
    task send_impulse(input real amp, input integer num_samples);
        integer i;
        begin
            $display("\n=== Sending impulse response test ===");
            
            for (i = 0; i < num_samples; i++) begin
                @(posedge l_r_clk);
                if (i == 0)
                    audio_in = real_to_q2_14(amp);
                else
                    audio_in = 16'd0;
                
                if (i < 20 || i % 100 == 0) begin
                    $display("Sample %0d: Input=%0.4f, Output=%0.4f", 
                             i, q2_14_to_real(audio_in), q2_14_to_real(audio_out));
                end
            end
        end
    endtask
    
    // Task to send constant DC value
    task send_dc(input real dc_value, input integer num_samples);
        integer i;
        begin
            $display("\n=== Sending DC value %0.4f for %0d samples ===", dc_value, num_samples);
            
            for (i = 0; i < num_samples; i++) begin
                @(posedge l_r_clk);
                audio_in = real_to_q2_14(dc_value);
                
                if (i % 50 == 0) begin
                    $display("Sample %0d: Input=%0.4f, Output=%0.4f", 
                             i, q2_14_to_real(audio_in), q2_14_to_real(audio_out));
                end
            end
        end
    endtask
    
    // Task to set coefficients
    task set_coefficients(input real b0_val, input real b1_val, input real b2_val, 
                          input real a1_val, input real a2_val);
        begin
            b0 = real_to_q2_14(b0_val);
            b1 = real_to_q2_14(b1_val);
            b2 = real_to_q2_14(b2_val);
            a1 = real_to_q2_14(a1_val);
            a2 = real_to_q2_14(a2_val);
            $display("\nCoefficients set:");
            $display("  b0=%0.4f (0x%h)", b0_val, b0);
            $display("  b1=%0.4f (0x%h)", b1_val, b1);
            $display("  b2=%0.4f (0x%h)", b2_val, b2);
            $display("  a1=%0.4f (0x%h)", a1_val, a1);
            $display("  a2=%0.4f (0x%h)", a2_val, a2);
        end
    endtask
    
    // Main test sequence
    initial begin
        $display("=== IIR Time-Multiplexed Filter Hardware Verification ===");
        $display("System Clock: %0.1f MHz", 1000.0/CLK_PERIOD);
        $display("Sample Rate: %0.1f kHz", SAMPLE_RATE/1000.0);
        $display("");
        
        // Initialize
        reset = 0;
        audio_in = 16'd0;
        b0 = 16'd0;
        b1 = 16'd0;
        b2 = 16'd0;
        a1 = 16'd0;
        a2 = 16'd0;
        
        // Reset pulse
        #100;
        reset = 1;
        #100;
        
        // Wait for L/R clock to settle
        repeat(10) @(posedge l_r_clk);
        
        //========================================
        // TEST 1: Unity Gain Passthrough
        //========================================
        $display("\n****************************************");
        $display("TEST 1: Unity Gain Passthrough");
        $display("Expected: Output = Input");
        $display("****************************************");
        set_coefficients(1.0, 0.0, 0.0, 0.0, 0.0);
        send_impulse(1.0, 50);
        send_sine_wave(1000.0, 0.5, 200);
        
        //========================================
        // TEST 2: Half Gain
        //========================================
        $display("\n****************************************");
        $display("TEST 2: Half Gain");
        $display("Expected: Output = 0.5 * Input");
        $display("****************************************");
        set_coefficients(0.5, 0.0, 0.0, 0.0, 0.0);
        send_impulse(1.0, 50);
        send_dc(0.5, 100);
        
        //========================================
        // TEST 3: Simple 2-tap FIR (Moving Average)
        //========================================
        $display("\n****************************************");
        $display("TEST 3: 2-tap FIR Moving Average");
        $display("Expected: Output = 0.5*x[n] + 0.5*x[n-1]");
        $display("****************************************");
        set_coefficients(0.5, 0.5, 0.0, 0.0, 0.0);
        send_impulse(1.0, 50);
        send_dc(1.0, 100);
        
        //========================================
        // TEST 4: All b coefficients
        //========================================
        $display("\n****************************************");
        $display("TEST 4: All b coefficients (FIR)");
        $display("Expected: Output = 0.25*x[n] + 0.5*x[n-1] + 0.25*x[n-2]");
        $display("****************************************");
        set_coefficients(0.25, 0.5, 0.25, 0.0, 0.0);
        send_impulse(1.0, 50);
        send_dc(1.0, 100);
        
        //========================================
        // TEST 5: Simple IIR with feedback
        //========================================
        $display("\n****************************************");
        $display("TEST 5: Simple IIR with single feedback");
        $display("Expected: Output = 0.5*x[n] + 0.5*y[n-1]");
        $display("****************************************");
        set_coefficients(0.5, 0.0, 0.0, 0.5, 0.0);
        send_impulse(1.0, 100);
        send_dc(1.0, 100);
        
        //========================================
        // TEST 6: Actual Low-Pass Filter
        //========================================
        $display("\n****************************************");
        $display("TEST 6: Actual Low-Pass Filter (500 Hz)");
        $display("****************************************");
        // Low-pass filter coefficients (from your original)
        b0 = 16'sh0147;  // ~0.020
        b1 = 16'sh028E;  // ~0.040
        b2 = 16'sh0147;  // ~0.020
        a1 = 16'sh6A3D;  // ~1.659
        a2 = 16'shD89F;  // ~-0.618
        $display("Using actual filter coefficients");
        
        send_impulse(1.0, 100);
        send_sine_wave(100.0, 0.5, 300);   // Should pass
        send_sine_wave(2000.0, 0.5, 300);  // Should attenuate
        
        // Finish
        repeat(100) @(posedge l_r_clk);
        $display("\n=== All Tests Complete ===");
        $finish;
    end
    
    // Timeout watchdog
    initial begin
        #100_000_000;  // 100 ms timeout
        $display("ERROR: Test timeout!");
        $finish;
    end
    
    // Optional: Dump waveforms
    initial begin
        $dumpfile("iir_time_mux_accum_tb.vcd");
        $dumpvars(0, iir_time_mux_accum_tb);
    end

endmodule