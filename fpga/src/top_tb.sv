`timescale 1ns/1ps

module top_tb();
    // Inputs
    logic reset_n_i;
    logic i2s_sd_i;
    
    // Outputs
    logic lmmi_clk_i;
    logic i2s_sd_o;
    logic i2s_sck_o;
    logic i2s_ws_o;
    logic adc_test;
    logic conf_en_i;
    
    // Test monitoring variables
    integer sample_count;
    integer bit_count;
    integer frame_count;
    
    // I2S stimulus generation
    logic [31:0] test_audio_sample;
    logic [23:0] left_channel;
    logic [23:0] right_channel;
    
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
        $display("Starting top_new Testbench with Realistic I2S Input");
        $display("=================================================================");
        sample_count = 0;
        bit_count = 0;
        frame_count = 0;
    end
    
    // Monitor ADC valid signal with enhanced output
    always @(posedge dut.adc_valid) begin
        sample_count++;
        $display("\n***** ADC Sample #%0d at %0t ns *****", sample_count, $time);
        $display("  ADC Data (hex):     0x%08h", dut.adc_data);
        $display("  ADC Data (signed):  %d", $signed(dut.adc_data));
        $display("  Latched Data:       0x%08h", dut.latch_data);
        $display("  s_adc [23:0]:       0x%06h (%d)", dut.s_adc, $signed(dut.s_adc));
        $display("  s_proc (>>3):       0x%06h (%d)", dut.s_proc, $signed(dut.s_proc));
        
        // Check if data is non-zero (indicates proper reception)
        if (dut.adc_data != 32'h0) begin
            $display("  ✓ NON-ZERO DATA RECEIVED!");
        end else begin
            $display("  ⚠ WARNING: Zero data received");
        end
    end
    
    // Monitor DAC requests with more detail
    always @(posedge dut.dac_request) begin
        $display("\n----- DAC Request at %0t ns -----", $time);
        $display("  DAC Data:           0x%08h", dut.dac_data);
        $display("  Audio Out [15:0]:   0x%04h (%d)", dut.audio_out, $signed(dut.audio_out));
        $display("  Channel: %s", i2s_ws_o ? "RIGHT" : "LEFT");
    end
    
    // Monitor I2S word select with frame counting
    always @(posedge i2s_ws_o or negedge i2s_ws_o) begin
        if (!i2s_ws_o) begin
            frame_count++;
            $display("\n===== I2S Frame #%0d at %0t ns =====", frame_count, $time);
        end
    end
    
    // Task to generate realistic I2S input stream
    task automatic send_i2s_sample(input logic [23:0] left_data, input logic [23:0] right_data);
        integer i;
        logic [47:0] i2s_frame;
        
        // Pack left and right channels (MSB first in I2S)
        i2s_frame = {left_data, right_data};
        
        $display("\n>>> Sending I2S Sample at %0t ns <<<", $time);
        $display("    Left:  0x%06h (%d)", left_data, $signed(left_data));
        $display("    Right: 0x%06h (%d)", right_data, $signed(right_data));
        
        // Send 48 bits (24 per channel) synchronized with I2S clock
        for (i = 47; i >= 0; i--) begin
            @(negedge i2s_sck_o);  // Change on falling edge (typical I2S)
            i2s_sd_i = i2s_frame[i];
        end
    endtask
    
    // Main test stimulus
    initial begin
        // Initialize
        reset_n_i = 0;
        i2s_sd_i = 0;
        
        $display("\n--- RESET PHASE ---");
        $display("Time: %0t ns - Asserting reset", $time);
        
        #200;
        reset_n_i = 1;
        $display("Time: %0t ns - Reset released", $time);
        
        // Wait for I2S to start
        $display("\n--- WAITING FOR I2S CLOCK ---");
        wait(i2s_sck_o !== 1'bx);
        repeat(10) @(posedge i2s_sck_o);
        $display("Time: %0t ns - I2S clock detected", $time);
        
        $display("\n--- SENDING TEST PATTERNS ---");
        
        // Test Pattern 1: Small amplitude sine-like values
        $display("\nPattern 1: Low amplitude test");
        left_channel = 24'h001000;   // +4096
        right_channel = 24'h001000;
        send_i2s_sample(left_channel, right_channel);
        
        repeat(5) @(posedge i2s_ws_o);
        
        // Test Pattern 2: Medium amplitude
        $display("\nPattern 2: Medium amplitude test");
        left_channel = 24'h100000;   // Larger positive
        right_channel = 24'h0F0000;
        send_i2s_sample(left_channel, right_channel);
        
        repeat(5) @(posedge i2s_ws_o);
        
        // Test Pattern 3: Negative values
        $display("\nPattern 3: Negative values");
        left_channel = 24'hFF0000;   // Negative
        right_channel = 24'hFE0000;
        send_i2s_sample(left_channel, right_channel);
        
        repeat(5) @(posedge i2s_ws_o);
        
        // Test Pattern 4: Maximum positive
        $display("\nPattern 4: Maximum positive");
        left_channel = 24'h7FFFFF;   // Max positive
        right_channel = 24'h7FFFFF;
        send_i2s_sample(left_channel, right_channel);
        
        repeat(5) @(posedge i2s_ws_o);
        
        // Test Pattern 5: Maximum negative
        $display("\nPattern 5: Maximum negative");
        left_channel = 24'h800000;   // Max negative
        right_channel = 24'h800000;
        send_i2s_sample(left_channel, right_channel);
        
        repeat(5) @(posedge i2s_ws_o);
        
        // Test Pattern 6: Alternating
        $display("\nPattern 6: Alternating pattern");
        for (int j = 0; j < 5; j++) begin
            left_channel = (j % 2) ? 24'h200000 : 24'hE00000;
            right_channel = (j % 2) ? 24'hE00000 : 24'h200000;
            send_i2s_sample(left_channel, right_channel);
            repeat(3) @(posedge i2s_ws_o);
        end
        
        $display("\n--- TEST PATTERNS COMPLETE ---");
        
        // Continue for observation
        #100000;
    end
    
    // Periodic comprehensive status report
    initial begin
        forever begin
            #50000;
            $display("\n╔════════════════════════════════════════════════════════════╗");
            $display("║ STATUS REPORT at %0t ns", $time);
            $display("╠════════════════════════════════════════════════════════════╣");
            $display("║ Samples Received:     %0d", sample_count);
            $display("║ Frames Sent:          %0d", frame_count);
            $display("║ Current latch_data:   0x%08h", dut.latch_data);
            $display("║ Current dac_data:     0x%08h", dut.dac_data);
            $display("║ Current audio_out:    0x%04h (%d)", dut.audio_out, $signed(dut.audio_out));
            $display("║ Config Enable:        %0b", conf_en_i);
            $display("╚════════════════════════════════════════════════════════════╝\n");
        end
    end
    
    // Waveform dump
    initial begin
        $dumpfile("top_tb.vcd");
        $dumpvars(0, top_tb);
    end
    
    // Simulation timeout
    initial begin
        #500000;
        $display("\n╔════════════════════════════════════════════════════════════╗");
        $display("║ SIMULATION COMPLETE at %0t ns", $time);
        $display("╠════════════════════════════════════════════════════════════╣");
        $display("║ Total ADC Samples:    %0d", sample_count);
        $display("║ Total Frames Sent:    %0d", frame_count);
        $display("╚════════════════════════════════════════════════════════════╝");
        $finish;
    end
    
endmodule