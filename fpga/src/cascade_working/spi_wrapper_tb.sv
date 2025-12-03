// Testbench for SPI Wrapper Module
// Tests SPI transmission, synchronization, and coefficient extraction

`timescale 1ns/1ps

module spi_wrapper_tb();

    // Clock and reset
    logic clk;
    logic reset;
    
    // SPI signals
    logic sck;
    logic sdi;
    logic cs;
    
    // Output coefficients
    logic signed [15:0] low_b0, low_b1, low_b2, low_a1, low_a2;
    logic signed [15:0] mid_b0, mid_b1, mid_b2, mid_a1, mid_a2;
    logic signed [15:0] high_b0, high_b1, high_b2, high_a1, high_a2;
    logic valid_out;
    
    // Test data
    logic [335:0] test_data;
    
    // Instantiate DUT
    spi_wrapper dut (
        .clk(clk),
        .reset(reset),
        .sck(sck),
        .sdi(sdi),
        .cs(cs),
        .low_b0(low_b0), .low_b1(low_b1), .low_b2(low_b2), .low_a1(low_a1), .low_a2(low_a2),
        .mid_b0(mid_b0), .mid_b1(mid_b1), .mid_b2(mid_b2), .mid_a1(mid_a1), .mid_a2(mid_a2),
        .high_b0(high_b0), .high_b1(high_b1), .high_b2(high_b2), .high_a1(high_a1), .high_a2(high_a2),
        .valid_out(valid_out)
    );
    
    // Clock generation - 100 MHz system clock
    initial begin
        clk = 0;
        forever #5 clk = ~clk;  // 10ns period = 100 MHz
    end
    
    // SPI clock generation - slower than system clock
    initial begin
        sck = 0;
        forever #50 sck = ~sck;  // 100ns period = 10 MHz
    end
    
    // Task to send SPI data
    task send_spi_data(input logic [335:0] data);
        integer i;
        begin
            cs = 1;  // Start with CS high (reset)
            #200;
            cs = 0;  // Lower CS to start transmission
            #100;
            
            // Send data MSB first
            for (i = 335; i >= 0; i--) begin
                @(negedge sck);  // Change data on falling edge
                sdi = data[i];
            end
            
            @(posedge sck);  // Wait for last bit to be clocked in
            #200;
        end
    endtask
    
    // Task to display coefficients
    task display_coefficients();
        begin
            $display("\n--- Filter Coefficients ---");
            $display("LOW PASS:");
            $display("  b0 = 0x%04h (%d)", low_b0, low_b0);
            $display("  b1 = 0x%04h (%d)", low_b1, low_b1);
            $display("  b2 = 0x%04h (%d)", low_b2, low_b2);
            $display("  a1 = 0x%04h (%d)", low_a1, low_a1);
            $display("  a2 = 0x%04h (%d)", low_a2, low_a2);
            
            $display("MID PASS:");
            $display("  b0 = 0x%04h (%d)", mid_b0, mid_b0);
            $display("  b1 = 0x%04h (%d)", mid_b1, mid_b1);
            $display("  b2 = 0x%04h (%d)", mid_b2, mid_b2);
            $display("  a1 = 0x%04h (%d)", mid_a1, mid_a1);
            $display("  a2 = 0x%04h (%d)", mid_a2, mid_a2);
            
            $display("HIGH PASS:");
            $display("  b0 = 0x%04h (%d)", high_b0, high_b0);
            $display("  b1 = 0x%04h (%d)", high_b1, high_b1);
            $display("  b2 = 0x%04h (%d)", high_b2, high_b2);
            $display("  a1 = 0x%04h (%d)", high_a1, high_a1);
            $display("  a2 = 0x%04h (%d)", high_a2, high_a2);
        end
    endtask
    
    // Task to check expected values
    task check_coefficients(
        input logic signed [15:0] exp_low_b0, exp_low_b1, exp_low_b2, exp_low_a1, exp_low_a2,
        input logic signed [15:0] exp_mid_b0, exp_mid_b1, exp_mid_b2, exp_mid_a1, exp_mid_a2,
        input logic signed [15:0] exp_high_b0, exp_high_b1, exp_high_b2, exp_high_a1, exp_high_a2
    );
        begin
            if (low_b0 !== exp_low_b0) $display("ERROR: low_b0 = 0x%04h, expected 0x%04h", low_b0, exp_low_b0);
            if (low_b1 !== exp_low_b1) $display("ERROR: low_b1 = 0x%04h, expected 0x%04h", low_b1, exp_low_b1);
            if (low_b2 !== exp_low_b2) $display("ERROR: low_b2 = 0x%04h, expected 0x%04h", low_b2, exp_low_b2);
            if (low_a1 !== exp_low_a1) $display("ERROR: low_a1 = 0x%04h, expected 0x%04h", low_a1, exp_low_a1);
            if (low_a2 !== exp_low_a2) $display("ERROR: low_a2 = 0x%04h, expected 0x%04h", low_a2, exp_low_a2);
            
            if (mid_b0 !== exp_mid_b0) $display("ERROR: mid_b0 = 0x%04h, expected 0x%04h", mid_b0, exp_mid_b0);
            if (mid_b1 !== exp_mid_b1) $display("ERROR: mid_b1 = 0x%04h, expected 0x%04h", mid_b1, exp_mid_b1);
            if (mid_b2 !== exp_mid_b2) $display("ERROR: mid_b2 = 0x%04h, expected 0x%04h", mid_b2, exp_mid_b2);
            if (mid_a1 !== exp_mid_a1) $display("ERROR: mid_a1 = 0x%04h, expected 0x%04h", mid_a1, exp_mid_a1);
            if (mid_a2 !== exp_mid_a2) $display("ERROR: mid_a2 = 0x%04h, expected 0x%04h", mid_a2, exp_mid_a2);
            
            if (high_b0 !== exp_high_b0) $display("ERROR: high_b0 = 0x%04h, expected 0x%04h", high_b0, exp_high_b0);
            if (high_b1 !== exp_high_b1) $display("ERROR: high_b1 = 0x%04h, expected 0x%04h", high_b1, exp_high_b1);
            if (high_b2 !== exp_high_b2) $display("ERROR: high_b2 = 0x%04h, expected 0x%04h", high_b2, exp_high_b2);
            if (high_a1 !== exp_high_a1) $display("ERROR: high_a1 = 0x%04h, expected 0x%04h", high_a1, exp_high_a1);
            if (high_a2 !== exp_high_a2) $display("ERROR: high_a2 = 0x%04h, expected 0x%04h", high_a2, exp_high_a2);
        end
    endtask
    
    // Main test sequence
    initial begin
        $display("=== SPI Wrapper Testbench Start ===\n");
        
        // Initialize signals
        reset = 0;
        cs = 1;
        sdi = 0;
        
        // Apply reset
        $display("TEST 1: Reset");
        #100;
        reset = 1;
        #200;
        
        // Test 1: Send default test pattern (matching spi_reader comments)
        $display("\nTEST 2: Default coefficients (0x4000, 0x0000, ...)");
        test_data = {
            16'hAA55,  // Sync bytes [335:320]
            80'h0,     // 5 ADC values (not used) [319:240]
            // Low-pass coefficients [239:160]
            16'h4000, 16'h0000, 16'h0000, 16'h0000, 16'h0000,
            // Mid-pass coefficients [159:80]
            16'h4000, 16'h0000, 16'h0000, 16'h0000, 16'h0000,
            // High-pass coefficients [79:0]
            16'h4000, 16'h0000, 16'h0000, 16'h0000, 16'h0000
        };
        
        send_spi_data(test_data);
        
        // Wait for valid signal
        wait(valid_out);
        @(posedge clk);
        @(posedge clk);
        
        display_coefficients();
        check_coefficients(
            16'h4000, 16'h0000, 16'h0000, 16'h0000, 16'h0000,  // low
            16'h4000, 16'h0000, 16'h0000, 16'h0000, 16'h0000,  // mid
            16'h4000, 16'h0000, 16'h0000, 16'h0000, 16'h0000   // high
        );
        
        #1000;
        
        // Test 2: Send different coefficients
        $display("\nTEST 3: Custom coefficients");
        test_data = {
            16'hAA55,  // Sync bytes [335:320]
            80'h0,     // 5 ADC values [319:240]
            // Low-pass coefficients [239:160]
            16'h1234, 16'h5678, 16'h9ABC, 16'hDEF0, 16'h1111,
            // Mid-pass coefficients [159:80]
            16'h2222, 16'h3333, 16'h4444, 16'h5555, 16'h6666,
            // High-pass coefficients [79:0]
            16'h7777, 16'h8888, 16'h9999, 16'hAAAA, 16'hBBBB
        };
        
        send_spi_data(test_data);
        
        // Wait for valid signal
        wait(valid_out);
        @(posedge clk);
        @(posedge clk);
        
        display_coefficients();
        check_coefficients(
            16'h1234, 16'h5678, 16'h9ABC, 16'hDEF0, 16'h1111,  // low
            16'h2222, 16'h3333, 16'h4444, 16'h5555, 16'h6666,  // mid
            16'h7777, 16'h8888, 16'h9999, 16'hAAAA, 16'hBBBB   // high
        );
        
        #1000;
        
        // Test 3: Test with signed values (negative numbers)
        $display("\nTEST 4: Signed (negative) coefficients");
        test_data = {
            16'hAA55,  // Sync bytes
            80'h0,     // ADC values
            // Low-pass coefficients (mix of positive and negative)
            16'h8000, 16'hFFFF, 16'h7FFF, 16'hC000, 16'h4000,
            // Mid-pass coefficients
            16'hF000, 16'h0FFF, 16'hF0F0, 16'h0F0F, 16'h5A5A,
            // High-pass coefficients
            16'hA5A5, 16'h1234, 16'hEDCB, 16'h0001, 16'hFFFE
        };
        
        send_spi_data(test_data);
        
        // Wait for valid signal
        wait(valid_out);
        @(posedge clk);
        @(posedge clk);
        
        display_coefficients();
        check_coefficients(
            16'h8000, 16'hFFFF, 16'h7FFF, 16'hC000, 16'h4000,  // low
            16'hF000, 16'h0FFF, 16'hF0F0, 16'h0F0F, 16'h5A5A,  // mid
            16'hA5A5, 16'h1234, 16'hEDCB, 16'h0001, 16'hFFFE   // high
        );
        
        #1000;
        
        // Test 4: Test CS reset functionality
        $display("\nTEST 5: CS reset during transmission");
        cs = 1;  // Start with CS high
        #200;
        cs = 0;  // Lower CS
        
        // Send partial data
        repeat(100) begin
            @(negedge sck);
            sdi = $random;
        end
        
        // Assert CS in middle of transmission (should reset)
        cs = 1;
        #500;
        
        // Now send complete valid data
        test_data = {
            16'hAA55,
            80'h0,
            16'hCAFE, 16'hBABE, 16'hDEAD, 16'hBEEF, 16'hFEED,
            16'h1111, 16'h2222, 16'h3333, 16'h4444, 16'h5555,
            16'h6666, 16'h7777, 16'h8888, 16'h9999, 16'hAAAA
        };
        
        send_spi_data(test_data);
        
        wait(valid_out);
        @(posedge clk);
        @(posedge clk);
        
        display_coefficients();
        check_coefficients(
            16'hCAFE, 16'hBABE, 16'hDEAD, 16'hBEEF, 16'hFEED,
            16'h1111, 16'h2222, 16'h3333, 16'h4444, 16'h5555,
            16'h6666, 16'h7777, 16'h8888, 16'h9999, 16'hAAAA
        );
        
        #1000;
        
        // Test 5: Back-to-back transmissions
        $display("\nTEST 6: Back-to-back SPI transmissions");
        test_data = {
            16'hAA55, 80'h0,
            16'h0001, 16'h0002, 16'h0003, 16'h0004, 16'h0005,
            16'h0006, 16'h0007, 16'h0008, 16'h0009, 16'h000A,
            16'h000B, 16'h000C, 16'h000D, 16'h000E, 16'h000F
        };
        send_spi_data(test_data);
        wait(valid_out);
        @(posedge clk);
        display_coefficients();
        
        #500;
        
        test_data = {
            16'hAA55, 80'h0,
            16'hF001, 16'hF002, 16'hF003, 16'hF004, 16'hF005,
            16'hF006, 16'hF007, 16'hF008, 16'hF009, 16'hF00A,
            16'hF00B, 16'hF00C, 16'hF00D, 16'hF00E, 16'hF00F
        };
        send_spi_data(test_data);
        wait(valid_out);
        @(posedge clk);
        display_coefficients();
        
        #1000;
        
        $display("\n=== All Tests Complete ===");
        $finish;
    end
    
    // Monitor for debugging
    initial begin
        $monitor("Time=%0t | CS=%b | Valid=%b | low_b0=0x%04h | mid_b0=0x%04h | high_b0=0x%04h", 
                 $time, cs, valid_out, low_b0, mid_b0, high_b0);
    end
    
    // Timeout watchdog
    initial begin
        #500000;  // 500 microseconds
        $display("\nERROR: Testbench timeout!");
        $finish;
    end

endmodule