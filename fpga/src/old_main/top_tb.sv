`timescale 1ns/1ps

module top_tb();
    logic reset_n_i;
    logic i2s_sd_i;
    logic lmmi_clk_i;
    logic i2s_sd_o;
    logic i2s_sck_o;
    logic i2s_ws_o;
    logic adc_test;
    logic conf_en_i;
    
    integer sample_count;
    integer tx_sample_count;
    integer nonzero_count;
    
    // Instantiate DUT
    top_new dut(
        .reset_n_i(reset_n_i),
        .i2s_sd_i(i2s_sd_i),
        .lmmi_clk_i(lmmi_clk_i),
        .i2s_sd_o(i2s_sd_o),
        .i2s_sck_o(i2s_sck_o),
        .i2s_ws_o(i2s_ws_o),
        .adc_test(adc_test),
        .conf_en_i(conf_en_i)
    );
    
    initial begin
        $display("=================================================================");
        $display("Three-Band EQ Filter Testbench - Continuous I2S");
        $display("=================================================================");
        sample_count = 0;
        tx_sample_count = 0;
        nonzero_count = 0;
    end
    
    // Monitor ADC samples
    always @(posedge dut.adc_valid) begin
        sample_count++;
        
        if (dut.adc_data != 32'h0) begin
            nonzero_count++;
            if (nonzero_count <= 10 || nonzero_count % 10 == 0) begin
                $display("\n***** RX Sample #%0d (nonzero #%0d) at %0t ns *****", 
                         sample_count, nonzero_count, $time);
                $display("  ADC Data:     0x%08h (%d)", dut.adc_data, $signed(dut.adc_data));
                $display("  Latched:      0x%08h", dut.latch_data);
            end
        end
    end
    
    // Monitor DAC output with filter details
    always @(posedge dut.dac_request) begin
        if (dut.dac_data != 32'h0 && nonzero_count > 0 && nonzero_count <= 50) begin
            $display("\n>>> DAC Output at %0t ns <<<", $time);
            $display("  Combined Audio: 0x%04h (%6d)", dut.audio_out, $signed(dut.audio_out));
            $display("  ├─ Low  Band:   0x%04h (%6d)", dut.low_band_out, $signed(dut.low_band_out));
            $display("  ├─ Mid  Band:   0x%04h (%6d)", dut.mid_band_out, $signed(dut.mid_band_out));
            $display("  └─ High Band:   0x%04h (%6d)", dut.high_band_out, $signed(dut.high_band_out));
            
            // Verify sum
            int sum = $signed(dut.low_band_out) + $signed(dut.mid_band_out) + $signed(dut.high_band_out);
            if (sum != $signed(dut.audio_out)) begin
                $display("  ⚠ SUM MISMATCH! Expected: %d, Got: %d", sum, $signed(dut.audio_out));
            end
        end
    end
    
    // Continuous I2S transmitter - synchronized to DUT's I2S clock
    initial begin
        logic [23:0] test_amplitude;
        integer phase;
        real sine_val;
        
        reset_n_i = 0;
        i2s_sd_i = 0;
        
        #200;
        reset_n_i = 1;
        $display("\nReset released at %0t ns", $time);
        
        // Wait for I2S clocks to start
        wait(i2s_sck_o !== 1'bx);
        repeat(100) @(posedge i2s_sck_o);
        $display("I2S clock detected at %0t ns\n", $time);
        
        $display("Starting continuous I2S transmission...\n");
        
        phase = 0;
        test_amplitude = 24'h100000;  // Start with this amplitude
        
        forever begin
            // Generate test pattern (stepped values that change periodically)
            if (tx_sample_count > 0 && tx_sample_count % 40 == 0) begin
                // Change amplitude every 40 samples
                case ((tx_sample_count / 40) % 6)
                    0: test_amplitude = 24'h100000;  // +1048576
                    1: test_amplitude = 24'h200000;  // +2097152
                    2: test_amplitude = 24'h400000;  // +4194304
                    3: test_amplitude = 24'hFF0000;  // -65536
                    4: test_amplitude = 24'hF00000;  // -1048576
                    5: test_amplitude = 24'h080000;  // +524288
                endcase
                $display("[TX] Amplitude changed to 0x%06h (%d) at sample %0d", 
                         test_amplitude, $signed(test_amplitude), tx_sample_count);
            end
            
            // Alternatively, generate sine wave
            // sine_val = $sin(phase * 3.14159 / 32.0);
            // test_amplitude = $rtoi(sine_val * 2000000.0);
            
            // Wait for LEFT channel (WS low)
            @(negedge i2s_ws_o);
            
            // Transmit left channel (24 bits, MSB first)
            for (int i = 23; i >= 0; i--) begin
                @(negedge i2s_sck_o);
                i2s_sd_i = test_amplitude[i];
            end
            
            // Wait for RIGHT channel (WS high)
            @(posedge i2s_ws_o);
            
            // Transmit right channel (same value for simplicity)
            for (int i = 23; i >= 0; i--) begin
                @(negedge i2s_sck_o);
                i2s_sd_i = test_amplitude[i];
            end
            
            tx_sample_count++;
            phase = (phase + 1) % 64;
        end
    end
    
    // Comprehensive status reports
    initial begin
        forever begin
            #200000;  // Every 200μs
            $display("\n╔══════════════════════════════════════════════════════════════╗");
            $display("║ STATUS REPORT at %0t ns (%.1f ms)", $time, $time/1000000.0);
            $display("╠══════════════════════════════════════════════════════════════╣");
            $display("║ TX Frames Sent:       %6d", tx_sample_count);
            $display("║ RX Samples Total:     %6d", sample_count);
            $display("║ RX Nonzero Samples:   %6d", nonzero_count);
            $display("║ Throughput:           %6.1f%%", (sample_count * 100.0) / tx_sample_count);
            $display("║ Current Latch:        0x%08h (%d)", 
                     dut.latch_data, $signed(dut.latch_data));
            $display("║ Current Audio Out:    0x%04h (%6d)", 
                     dut.audio_out, $signed(dut.audio_out));
            $display("║ Filter Bands:");
            $display("║   Low:  %6d   Mid:  %6d   High: %6d",
                     $signed(dut.low_band_out), $signed(dut.mid_band_out), 
                     $signed(dut.high_band_out));
            $display("╚══════════════════════════════════════════════════════════════╝\n");
        end
    end
    
    // VCD dump for waveform viewing
    initial begin
        $dumpfile("top_tb.vcd");
        $dumpvars(0, top_tb);
        $dumpvars(0, dut.filter);  // Include filter internals
    end
    
    // End simulation
    initial begin
        #3000000;  // 3ms
        $display("\n╔══════════════════════════════════════════════════════════════╗");
        $display("║ FINAL RESULTS");
        $display("╠══════════════════════════════════════════════════════════════╣");
        $display("║ Total TX Frames:      %6d", tx_sample_count);
        $display("║ Total RX Samples:     %6d", sample_count);
        $display("║ Nonzero RX Samples:   %6d", nonzero_count);
        $display("║ Expected Throughput:  ~100%%");
        $display("║ Actual Throughput:    %6.1f%%", (sample_count * 100.0) / tx_sample_count);
        $display("╚══════════════════════════════════════════════════════════════╝");
        $finish;
    end
    
endmodule