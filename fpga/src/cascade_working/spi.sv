module aes_spi(
    input  logic sck,
    input  logic reset_n,
    input  logic sdi,
    input  logic cs,
    output logic [335:0] data,     // safe, stable output
    output logic valid
);

    logic [335:0] sreg;
    logic [8:0]   bit_count;
	logic [335:0] next_sreg;
    // NEW: stable, cross-domain-safe data buffer
    logic [335:0] data_stable;

always_ff @(posedge sck) begin
    if (!reset_n) begin
        bit_count   <= 0;
        sreg        <= 0;
        data_stable <= 0;
        valid       <= 0;
    end else if (cs) begin
        bit_count   <= 0;
        sreg        <= 0;
        valid       <= 0;
    end else begin
        // shift in new bit
        sreg <= {sreg[334:0], sdi};

        if (bit_count == 335) begin
            data_stable <= {sreg[334:0], sdi};  // latch full frame
            valid       <= 1;
            bit_count   <= 0;                     // ready for next frame
            sreg        <= 0;                     // clear shift register
        end else begin
            bit_count <= bit_count + 1;
            valid     <= 0;
        end
    end
end

assign data = data_stable;


endmodule
