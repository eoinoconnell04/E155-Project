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
    logic [31:0] captured_i2s_output;
    
    // Instantiate DUT - FIXED: Using top_new module name from provided file
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
    
    // Clock is generated internally by HSOSC in the DUT
    // Monitor the generated clock
    initial begin
        $display("=================================================================");
        $display("Starting top_new Testbench");
        $display("=================================================================");
        $display("Time: %0t ns - Waiting for internal oscillator to start...", $time);
    end
    
    // Monitor clock generation
    always @(posedge lmmi_clk_i) begin
        // Clock is running
    end
    
    initial begin
        sample_count = 0;
        bit_count = 0;
    end
    
    // Monitor ADC valid signal
    always @(posedge dut.adc_valid) begin
        sample_count++;
        $display("Time: %0t ns - ADC Sample #%0d received", $time, sample_count);
        $display("  ADC Data: 0x%08h (%d decimal)", dut.adc_data, $signed(dut.adc_data));
        $display("  Latched Data: 0x%08h", dut.latch_data);
        $display("  Signed ADC (24-bit): 0x%06h (%d)", dut.s_adc, $signed(dut.s_adc));
        $display("  Processed (>>3): 0x%06h (%d)", dut.s_proc, $signed(dut.s_proc));
    end
    
    // Monitor DAC requests
    always @(posedge dut.dac_request) begin
        $display("Time: %0t ns - DAC Request", $time);
        $display("  DAC Data: 0x%08h", dut.dac_data);
        $display("  Audio Out: 0x%04h (%d)", dut.audio_out, $signed(dut.audio_out));
    end
    
    // Monitor I2S output transitions
    always @(posedge i2s_sck_o) begin
        bit_count++;
        if (bit_count % 32 == 0) begin
            $display("Time: %0t ns - I2S Output Frame Complete (32 bits transmitted)", $time);
        end
    end
    
    // Monitor word select (L/R channel) transitions
    always @(posedge i2s_ws_o or negedge i2s_ws_o) begin
        if (i2s_ws_o)
            $display("Time: %0t ns - I2S WS: Right Channel", $time);
        else
            $display("Time: %0t ns - I2S WS: Left Channel", $time);
    end
    
    // Monitor configuration enable
    always @(posedge conf_en_i) begin
        $display("Time: %0t ns - Configuration Enabled", $time);
        $display("  Resolution: %0d bits", dut.conf_res_i);
        $display("  Clock Ratio: %0d", dut.conf_ratio_i);
        $display("  Swap: %0b", dut.conf_swap_i);
    end
    
    // Test stimulus
    initial begin
        // Initialize
        reset_n_i = 0;
        i2s_sd_i = 0;
        
        $display("\n--- RESET PHASE ---");
        $display("Time: %0t ns - Asserting reset", $time);
        
        // Hold reset for adequate time
        #200;
        
        // Release reset
        reset_n_i = 1;
        $display("Time: %0t ns - Releasing reset", $time);
        
        // Wait for system to stabilize
        #500;
        $display("\n--- STARTING I2S INPUT STIMULUS ---");
        
        // Generate a test pattern on I2S input
        // Simulate actual I2S data stream
        repeat(10) begin
            // Generate 32-bit word (16 bits per channel)
            repeat(32) begin
                #83.33; // ~12MHz I2S bit clock period
                i2s_sd_i = $random;
            end
            $display("Time: %0t ns - Generated 32-bit I2S input word", $time);
        end
        
        // Continue with periodic toggling
        $display("\n--- CONTINUOUS OPERATION ---");
        #5000;
    end
    
    // Periodic status report
    initial begin
        forever begin
            #10000;
            $display("\n=== STATUS REPORT at %0t ns ===", $time);
            $display("  Samples Received: %0d", sample_count);
            $display("  Current latch_data: 0x%08h", dut.latch_data);
            $display("  Current dac_data: 0x%08h", dut.dac_data);
            $display("  ADC Valid: %0b", dut.adc_valid);
            $display("  Config Enable: %0b", conf_en_i);
            $display("================================\n");
        end
    end
    
    // Waveform dump for viewing in GTKWave or similar
    initial begin
        $dumpfile("top_tb.vcd");
        $dumpvars(0, top_tb);
        $dumpvars(0, dut);
    end
    
    // Stop simulation after some time
    initial begin
        #500000;
        $display("\n=================================================================");
        $display("SIMULATION COMPLETE at %0t ns", $time);
        $display("=================================================================");
        $display("Total ADC Samples: %0d", sample_count);
        $display("Total I2S Bits: %0d", bit_count);
        $finish;
    end
    
endmodule