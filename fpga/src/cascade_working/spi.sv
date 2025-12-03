// Drake Gonzales
// drgonzales@g.hmc.edu
// This Module holds logic to configure SPI
// 11/03/25

module spi(
    input  logic sck,
    input  logic sdi,
    input  logic cs,
    output logic [335:0] data,  // 42 bytes = 336 bits
    output logic valid
);

    logic [335:0] sreg;
    logic [8:0] bit_count;

    always_ff @(posedge sck or posedge cs) begin
        if (cs) begin
            bit_count <= 0;
            valid <= 0;
        end else begin
            sreg <= {sreg[334:0], sdi};
            bit_count <= bit_count + 1;
            if (bit_count == 335) begin 
                valid <= 1;
            end else begin
                valid <= 0;
            end
        end
    end

    assign data = sreg;
endmodule