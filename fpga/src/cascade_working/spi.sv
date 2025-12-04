module aes_spi(
    input  logic sck,
    input  logic reset_n,
    input  logic sdi,
    input  logic cs,
    output logic [335:0] data,  // 42 bytes = 336 bits
    output logic valid);
    
    logic [335:0] sreg;
    logic [8:0] bit_count;
    
always_ff @(posedge sck) begin
    if (reset_n == 0) begin
        bit_count <= 0;
        valid <= 0;
        sreg <= 0;
        data <= 0;
    end else if (cs) begin
        bit_count <= 0;
        valid <= 0;
    end else begin

        // Last bit is arriving now
        if (bit_count == 335) begin
            sreg <= {sreg[334:0], sdi};   // shift last bit
            data <= {sreg[334:0], sdi};   // capture the complete frame
            valid <= 1;
            bit_count <= 0;
        end else begin
            sreg <= {sreg[334:0], sdi};   // normal shifting
            bit_count <= bit_count + 1;
            valid <= 0;
        end
    end
end
endmodule