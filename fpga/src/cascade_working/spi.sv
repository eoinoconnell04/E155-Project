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
    logic done;     // fpag for complete transfer

    always_ff @(posedge sck or posedge cs) begin
        if (cs) begin
            bit_count <= 0;
            valid <= 0;
            done <= 0;
        end else begin
            if (!done) begin
                sreg <= {sreg[334:0], sdi};

                if (bit_count == 335) begin 
                    valid <= 1;
                    done <= 1;
                end else begin 
                    bit_count <= bit_count + 1;
                    valid <= 0;
                end
            end else begin
                valid <= 0;
            end
        end
    end

    assign data = sreg;
endmodule