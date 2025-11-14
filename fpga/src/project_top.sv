/*
Author: Eoin O'Connell & Drake Gonzales
Email: eoconnell@hmc.edu
Date: Nov. 13, 2025
Module Function: Top level function for our real-time IIR Filtering project. 
- Communicates to ADC & DAC via I2S
- Communicates to MCU via SPI
- Filters incomming samples with 3 cascading IIR filters.
*/

module project_top(
);
	// Instantiate 6 MHz Clock
    HSOSC #(.CLKHF_DIV ("0b11")) hf_osc (.CLKHFPU(1'b1), .CLKHFEN(1'b1), .CLKHF(clk));

    //adc i2s();
    //dac i2s();
    //mcu spi();

    iir_filter_DSP_slice low_filter(clk, reset, latest_sample, b0, b1, b2, a1, a2);
    iir_filter_DSP_slice mid_filter(clk, reset, latest_sample, b0, b1, b2, a1, a2);
    iir_filter_DSP_slice high_filter(clk, reset, latest_sample, b0, b1, b2, a1, a2);

endmodule