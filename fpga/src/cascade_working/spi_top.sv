module spi_top(
    input  clk_in,
    input  rst_in,
    input  sck,
    input  sdi,
    input  cs,
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

    // Latch the data when valid is detected
    always_ff @(posedge clk_in) begin
        if (rst_in ==0) begin
            data_latched <= 0;
        end else begin
            if (spi_valid_sync) begin
                data_latched <= spi_data;  // Latch data when valid
            end
        end
    end

    // Controller instance to unpack the data
    control ctrl_inst (
        .data(data_latched),
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