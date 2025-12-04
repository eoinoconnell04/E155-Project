`timescale 1ns/1ps

module top_tb();

    // Signals
    logic sck, sdi, cs;
    logic reset_n_i;
    logic i2s_sd_i;
    logic lmmi_clk_i;
    logic i2s_sd_o;
    logic i2s_sck_o;
    logic i2s_ws_o;
    logic adc_test;
    logic conf_en_i;
    logic mac_a;
    
    // DUT
    top dut (
        .sck(sck),
        .sdi(sdi),
        .cs(cs),
        .reset_n_i(reset_n_i),
        .i2s_sd_i(i2s_sd_i),
        .lmmi_clk_i(lmmi_clk_i),
        .i2s_sd_o(i2s_sd_o),
        .i2s_sck_o(i2s_sck_o),
        .i2s_ws_o(i2s_ws_o),
        .adc_test(adc_test),
        .conf_en_i(conf_en_i),
        .mac_a(mac_a)
    );
    
    // SPI clock - 1 MHz
    initial begin
        sck = 0;
        forever #500 sck = ~sck;
    end
    
    // Simple I2S input - just toggle a pattern
    initial begin
        i2s_sd_i = 0;
        forever #1000 i2s_sd_i = ~i2s_sd_i;
    end
    
    // Task to send SPI data
    task send_spi(input logic [335:0] data);
        begin
            cs = 0;
            #1000;
            for (int i = 335; i >= 0; i--) begin
                @(negedge sck);
                sdi = data[i];
            end
            @(posedge sck);
            #1000;
            cs = 1;
        end
    endtask
    
    // Main test
    initial begin
        // Initialize
        reset_n_i = 1;
        cs = 1;
        sdi = 0;
        #20
        // Reset
        reset_n_i = 0;
        #10000;
        reset_n_i = 1;
        #50000;
        
        // Test 1: Send unity gain coefficients
        $display("Test 1: Unity gain");
        send_spi({
            96'h0,
            16'h4000, 16'h0000, 16'h0000, 16'h0000, 16'h0000,  // low
            16'h4000, 16'h0000, 16'h0000, 16'h0000, 16'h0000,  // mid
            16'h4000, 16'h0000, 16'h0000, 16'h0000, 16'h0000   // high
        });
        #200000;
        
        // Test 2: Send half gain coefficients
        $display("Test 2: Half gain");
        send_spi({
            96'h0,
            16'h2000, 16'h0000, 16'h0000, 16'h0000, 16'h0000,  // low
            16'h2000, 16'h0000, 16'h0000, 16'h0000, 16'h0000,  // mid
            16'h2000, 16'h0000, 16'h0000, 16'h0000, 16'h0000   // high
        });
        #200000;
        
        $display("Done");
        $finish;
    end

endmodule