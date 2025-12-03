// SPI Wrapper Module
// Synchronizes inputs, instantiates SPI and SPI reader
// Registers coefficient values when valid is asserted

module spi_wrapper(
    input  logic clk,           // System clock for synchronization
    input  logic reset,         // Reset signal (active high to match synchronizer)
    input  logic sck,           // SPI clock (async)
    input  logic sdi,           // SPI data in (async)
    input  logic cs,            // SPI chip select (async)
    
    // Low filter coefficients
    output logic signed [15:0] low_b0, low_b1, low_b2, low_a1, low_a2,
    // Mid filter coefficients
    output logic signed [15:0] mid_b0, mid_b1, mid_b2, mid_a1, mid_a2,
    // High filter coefficients
    output logic signed [15:0] high_b0, high_b1, high_b2, high_a1, high_a2,
    
    output logic valid_out      // Valid signal output
);

    // Synchronized inputs
    logic sck_sync;
    logic sdi_sync;
    logic cs_sync;
    
    // Synchronize sck
    synchronizer #(.NUM_BITS(1)) sck_synchronizer (
        .clk(clk),
        .reset(reset),
        .async_input(sck),
        .sync_output(sck_sync)
    );
    
    // Synchronize sdi
    synchronizer #(.NUM_BITS(1)) sdi_synchronizer (
        .clk(clk),
        .reset(reset),
        .async_input(sdi),
        .sync_output(sdi_sync)
    );
    
    // Synchronize cs
    synchronizer #(.NUM_BITS(1)) cs_synchronizer (
        .clk(clk),
        .reset(reset),
        .async_input(cs),
        .sync_output(cs_sync)
    );
    
    // SPI module outputs
    logic [335:0] spi_data;
    logic spi_valid;
    
    // Instantiate SPI module with synchronized inputs
    spi spi_inst (
        .sck(sck_sync),
        .sdi(sdi_sync),
        .cs(cs_sync),
        .data(spi_data),
        .valid(spi_valid)
    );
    
    // Registered data for reader
    logic [335:0] registered_data;
    
    // Register SPI data when valid is asserted
    always_ff @(posedge clk) begin
        if (!reset) begin
            registered_data <= 336'b0;
            valid_out <= 1'b0;
        end else if (spi_valid) begin
            registered_data <= spi_data;
            valid_out <= 1'b1;
        end else begin
            valid_out <= 1'b0;
        end
    end
    
    // Instantiate SPI reader with registered data
    spi_reader reader_inst (
        .data(registered_data),
        .low_b0(low_b0), .low_b1(low_b1), .low_b2(low_b2), .low_a1(low_a1), .low_a2(low_a2),
        .mid_b0(mid_b0), .mid_b1(mid_b1), .mid_b2(mid_b2), .mid_a1(mid_a1), .mid_a2(mid_a2),
        .high_b0(high_b0), .high_b1(high_b1), .high_b2(high_b2), .high_a1(high_a1), .high_a2(high_a2)
    );

endmodule