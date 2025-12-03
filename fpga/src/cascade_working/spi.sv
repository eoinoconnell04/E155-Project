// Drake Gonzales
// drgonzales@g.hmc.edu
// This Module holds logic to configure SPI
// 11/03/25

module aes_spi(
    input  logic sck,
    input  logic sdi,
    output logic [47:0] data);

    logic [47:0] sreg;

    always_ff @(posedge sck) begin
        sreg <= {sreg[46:0], sdi};
    end

    assign data = sreg;

endmodule
