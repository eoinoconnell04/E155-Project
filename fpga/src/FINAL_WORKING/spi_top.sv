/*
Authors: Eoin O'Connell (eoconnell@hmc.edu)
         Drake Gonzales (drgonzales@g.hmc.edu)
Date: Dec. 4, 2025
Module Function: SPI top-level integration module
- Clock domain crossing from SPI to system clock
- Synchronizes valid signal and coefficient data
- Interfaces with control module for safe coefficient updates
*/

module spi_top(
    input  logic clk_in,
    input  logic rst_in,
	input logic output_ready,
    input  logic sck,
    input  logic sdi,
    input  logic cs,
    // Low-pass filter coefficients
    output logic signed [15:0] low_b0, low_b1, low_b2, low_a1, low_a2,
    // Mid-pass filter coefficients
    output logic signed [15:0] mid_b0, mid_b1, mid_b2, mid_a1, mid_a2,
    // High-pass filter coefficients
    output logic signed [15:0] high_b0, high_b1, high_b2, high_a1, high_a2,
	output logic spi_valid
);

    logic [335:0] spi_data;
    logic spi_valid_sync;
    logic [335:0] data_latched;

    // SPI module (runs on sck domain)
    aes_spi spi_inst (
        .sck(sck),
		.reset_n(rst_in),
        .sdi(sdi),
        .cs(cs),
        .data(spi_data),
        .valid(spi_valid)
    );

    // Synchronize valid signal
    synchronizer sync_valid (
        .clk(clk_in),
        .reset(rst_in),

        .async_input(spi_valid),
        .sync_output(spi_valid_sync)
    );

logic [335:0] spi_data_sync1, spi_data_sync2;

always_ff @(posedge clk_in) begin
    spi_data_sync1 <= spi_data;
    spi_data_sync2 <= spi_data_sync1;
end

always_ff @(posedge clk_in) begin
    if (spi_valid_sync)
        data_latched <= spi_data_sync2;
end

    // Controller instance to unpack the data
    control ctrl_inst (
		.clk(clk_in),
		.reset(rst_in),
		.output_ready(output_ready),
        .data(data_latched),
		.update_en(spi_valid_sync),
        .low_b0(low_b0),
        .low_b1(low_b1),
        .low_b2(low_b2),
        .low_a1(low_a1),
        .low_a2(low_a2),
        .mid_b0(mid_b0),
        .mid_b1(mid_b1),
        .mid_b2(mid_b2),
        .mid_a1(mid_a1),
        .mid_a2(mid_a2),
        .high_b0(high_b0),
        .high_b1(high_b1),
        .high_b2(high_b2),
        .high_a1(high_a1),
        .high_a2(high_a2)
    );

endmodule