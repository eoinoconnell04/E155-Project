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
    integer error_count;
    
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
        $display("Enhanced Testbench - Continuous I2S Stream");
        $display("=================================================================");
        sample_count = 0;
        tx_sample_count = 0;
        error_count = 0;
    end
    
    // Monitor ADC with detailed analysis
    always @(posedge dut.adc_valid) begin
        sample_count++;
        
        if (sample_count <= 5 || dut.adc_data != 32'h0) begin
            $display("\n***** ADC Sample #%0d at %0t ns *****", sample_count, $time);
            $display("  Raw ADC Data:       0x%08h (%d)", dut.adc_data, $signed(dut.adc_data));
            $display("  Latched Data:       0x%08h", dut.latch_data);
            $display("  s_adc [23:0]:       0x%06h (%d)", dut.s_adc, $signed(dut.s_adc));
            $display("  s_proc (>>3):       0x%06h (%d)", dut.s_proc, $signed(dut.s_proc));
            
            if (dut.adc_data != 32'h0) begin
                $display("  ✓ NON-ZERO DATA!");
            end
        end
    end
    
    // Monitor DAC with detailed filter output
    always @(posedge dut.dac_request) begin
        if (dut.dac_data != 32'h0) begin
            $display("\n----- DAC Output at %0t ns -----", $time);
            $display("  DAC Data:           0x%08h", dut.dac_data);
            $display("  Audio Out:          0x%04h (%d)", dut.audio_out, $signed(dut.audio_out));
            $display("  Low Band Out:       0x%04h (%d)", dut.low_band_out, $signed(dut.low_band_out));
            $display("  Mid Band Out:       0x%04h (%d)", dut.mid_band_out, $signed(dut.mid_band_out));
            $display("  High Band Out:      0x%04h (%d)", dut.high_band_out, $signed(dut.high_band_out));
            $display("  Channel:            %s", i2s_ws_o ? "RIGHT" : "LEFT");
        end
    end
    
    // Task to send continuous I2S with proper timing
    task automatic send_continuous_i2s();
        logic [23:0] left_data, right_data;
        integer phase;
        real sample_value;
        
        phase = 0;
        
        forever begin
            // Generate sine wave test pattern
            sample_value = $sin(phase * 3.14159 / 16.0);  // Low frequency sine
            left_data = $rtoi(sample_value * 1000000.0);  // Scale to 24-bit range
            right_data = $rtoi(sample_value * 800000.0);   // Slightly different amplitude
            
            // Wait for word select edge (new frame)
            @(negedge i2s_ws_o);
            tx_sample_count++;
            
            // Send left channel (24 bits MSB first)
            for (int i = 23; i >= 0; i--) begin
                @(negedge i2s_sck_o);
                i2s_sd_i = left_data[i];
            end
            
            // Wait for right channel
            @(posedge i2s_ws_o);
            
            // Send right channel (24 bits MSB first)
            for (int i = 23; i >= 0; i--) begin
                @(negedge i2s_sck_o);
                i2s_sd_i = right_data[i];
            end
            
            phase = (phase + 1) % 32;
            
            // Periodic status
            if (tx_sample_count % 10 == 0) begin
                $display("\n[TX] Sent %0d complete frames (L+R pairs)", tx_sample_count);
            end
        end
    endtask
    
    // Alternative: Send stepped test tones
    task automatic send_stepped_tones();
        logic [23:0] test_value;
        integer step;
        
        step = 0;
        test_value = 24'h010000;  // Start with small value
        
        forever begin
            // Wait for frame start
            @(negedge i2s_ws_o);
            tx_sample_count++;
            
            // Send same value for both channels
            // Left channel
            for (int i = 23; i >= 0; i--) begin
                @(negedge i2s_sck_o);
                i2s_sd_i = test_value[i];
            end
            
            // Right channel
            @(posedge i2s_ws_o);
            for (int i = 23; i >= 0; i--) begin
                @(negedge i2s_sck_o);
                i2s_sd_i = test_value[i];
            end
            
            // Change test value every 20 samples
            if (tx_sample_count % 20 == 0) begin
                step++;
                case (step % 6)
                    0: test_value = 24'h010000;  // +65536
                    1: test_value = 24'h100000;  // +1048576
                    2: test_value = 24'h400000;  // +4194304
                    3: test_value = 24'hFF0000;  // -65536
                    4: test_value = 24'hF00000;  // -1048576
                    5: test_value = 24'h000000;  // 0
                endcase
                $display("\n[STIMULUS] Changing to test value: 0x%06h (%d)", 
                         test_value, $signed(test_value));
            end
        end
    endtask
    
    // Main test sequence
    initial begin
        reset_n_i = 0;
        i2s_sd_i = 0;
        
        $display("\n--- RESET PHASE ---");
        #200;
        reset_n_i = 1;
        $display("Time: %0t ns - Reset released", $time);
        
        // Wait for I2S clock
        $display("\n--- WAITING FOR I2S CLOCK ---");
        wait(i2s_sck_o !== 1'bx);
        repeat(100) @(posedge i2s_sck_o);
        $display("Time: %0t ns - I2S system ready\n", $time);
        
        $display("--- STARTING CONTINUOUS I2S TRANSMISSION ---\n");
        
        // Choose one:
        // fork
        //     send_continuous_i2s();  // Sine wave
        // join_none
        
        fork
            send_stepped_tones();     // Stepped test tones (easier to track)
        join_none
    end
    
    // Comprehensive periodic report
    initial begin
        forever begin
            #100000;  // Every 100μs
            $display("\n╔══════════════════════════════════════════════════════════════╗");
            $display("║ STATUS at %0t ns", $time);
            $display("╠══════════════════════════════════════════════════════════════╣");
            $display("║ TX Frames Sent:       %6d", tx_sample_count);
            $display("║ RX Samples Received:  %6d", sample_count);
            $display("║ Current Latch:        0x%08h (%d)", 
                     dut.latch_data, $signed(dut.latch_data));
            $display("║ Current Audio Out:    0x%04h (%d)", 
                     dut.audio_out, $signed(dut.audio_out));
            $display("║ Filter Band Outputs:");
            $display("║   Low:  %6d   Mid:  %6d   High: %6d",
                     $signed(dut.low_band_out), $signed(dut.mid_band_out), 
                     $signed(dut.high_band_out));
            $display("╚══════════════════════════════════════════════════════════════╝\n");
        end
    end
    
    // VCD dump
    initial begin
        $dumpfile("top_tb.vcd");
        $dumpvars(0, top_tb);
    end
    
    // Simulation end
    initial begin
        #2000000;  // 2ms simulation
        $display("\n╔══════════════════════════════════════════════════════════════╗");
        $display("║ SIMULATION COMPLETE");
        $display("╠══════════════════════════════════════════════════════════════╣");
        $display("║ Total Frames Sent:    %6d", tx_sample_count);
        $display("║ Total Samples RX:     %6d", sample_count);
        $display("║ Data throughput:      %0d%%", (sample_count * 100) / tx_sample_count);
        $display("╚══════════════════════════════════════════════════════════════╝");
        $finish;
    end
    
endmodule