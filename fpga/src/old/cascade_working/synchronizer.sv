/*
Author: Eoin O'Connell
Email: eoconnell@hmc.edu
Date: Sep. 15, 2025
Module Function: This module is a syncronizer that takes async inputs and uses two flip flops to syncronize it.
Parameter: NUM_BITS: width of syncronizer
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