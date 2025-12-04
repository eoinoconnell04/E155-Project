/*
Authors: Eoin O'Connell (eoconnell@hmc.edu)
         Drake Gonzales (drgonzales@g.hmc.edu)
Date: Dec. 4, 2025
Module Function: I2S data latching wrapper
- Latches incoming 32-bit ADC data when valid
- Extracts 16-bit audio sample from bits [23:8]
*/
module I2S_package(
    input  logic        clk,
    input  logic        reset_n,
    input  logic [31:0] adc_data,
    input  logic        adc_valid,
    output logic [15:0] audio_in
);

    logic [31:0] latch_data;
    
    always_ff @(posedge clk) begin
        if (reset_n == 0) begin
            latch_data <= 32'd0;
        end 
        else begin 
            if (adc_valid) begin 
                latch_data <= adc_data;
            end
        end 
    end
    
    // Extract the 16-bit audio data from bits [23:8]
    assign audio_in = latch_data[23:8];

endmodule