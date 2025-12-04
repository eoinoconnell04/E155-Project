/*
Authors: Eoin O'Connell (eoconnell@hmc.edu)
         Drake Gonzales (drgonzales@g.hmc.edu)
Date: Dec. 4, 2025
Module Function: Multi-bit synchronizer for clock domain crossing
- Two-stage flip-flop synchronizer
- Parameterizable width (default 4 bits)
- Reduces metastability risk for asynchronous signals
*/

module synchronizer 
    #(parameter NUM_BITS=4)

(
    input logic clk, reset,
    input logic [NUM_BITS-1:0] async_input, 
    output logic [NUM_BITS-1:0] sync_output
);

    logic [NUM_BITS-1:0] intermediate_value;

    always_ff @(posedge clk) begin
        if (reset == 0) begin
            intermediate_value     <= 0;
            sync_output     <= 0;
        end 
        else begin
            sync_output <= intermediate_value;
            intermediate_value <= async_input;
        end 
    end

endmodule