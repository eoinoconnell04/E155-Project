module top(input logic sck, sdi, cs,
			input  logic reset_n_i, 
			input  logic i2s_sd_i,
			output logic lmmi_clk_i,    
			output logic i2s_sd_o,          
			output logic i2s_sck_o,        
			output logic i2s_ws_o,
			output logic adc_test,
			output logic output_ready);

// Internal signals
logic [31:0] adc_data;           
logic [31:0] dac_data;
logic        adc_valid;         
logic        dac_request;
logic signed [15:0] audio_in;

HSOSC #(.CLKHF_DIV ("0b10")) hf_osc (
    .CLKHFPU(1'b1),
    .CLKHFEN(1'b1),
    .CLKHF(lmmi_clk_i)
);

assign adc_test = adc_valid;

logic signed [15:0] audio_out;
assign dac_data = {8'b0, audio_out, 8'b0};

// I2S Package - handles ADC data latching
I2S_package i2s_pkg (
    .clk(lmmi_clk_i),
    .reset_n(reset_n_i),
    .adc_data(adc_data),
    .adc_valid(adc_valid),
    .audio_in(audio_in)
);

logic signed [15:0] low_b0, low_b1, low_b2, low_a1, low_a2, mid_b0, mid_b1, mid_b2, mid_a1, mid_a2, high_b0, high_b1, high_b2, high_a1, high_a2;

// Three-band equalizer
three_band_eq filter(
    .clk(lmmi_clk_i),
    .l_r_clk(i2s_ws_o),
    .reset(reset_n_i),
    .audio_in(audio_in),
    
    // Low-pass filter coefficients
    .low_b0(low_b0),
    .low_b1(low_b1),
    .low_b2(low_b2),
    .low_a1(low_a1),
    .low_a2(low_a2),
    
    // Mid-pass filter coefficients
    .mid_b0(mid_b0),
    .mid_b1(mid_b1),
    .mid_b2(mid_b2),
    .mid_a1(mid_a1),
    .mid_a2(mid_a2),
    
    // High-pass filter coefficients
    .high_b0(high_b0),
    .high_b1(high_b1),
    .high_b2(high_b2),
    .high_a1(high_a1),
    .high_a2(high_a2),
    
    .audio_out(audio_out),
    .mac_a(output_ready)
);

// I2S Receiver
lscc_i2s_codec #(
    .DATA_WIDTH       (24),
    .TRANSCEIVER_MODE (1)         
) I2S_RX (
    .reset_n_i(reset_n_i),
    .lmmi_clk_i(lmmi_clk_i),
    .conf_res_i(6'd24),
    .conf_ratio_i(10'd4),
    .conf_swap_i(1'b0),
    .conf_en_i(reset_n_i),
    .i2s_sd_i(i2s_sd_i),           
    .sample_dat_i(32'h0),           
    .sample_dat_o(adc_data),       
    .mem_rdwr_o(adc_valid),         
    .i2s_sd_o(),                    
    .i2s_sck_o(),                   
    .i2s_ws_o()                     
);

// I2S Transmitter
lscc_i2s_codec #(
    .DATA_WIDTH       (24),
    .TRANSCEIVER_MODE (0)          
) I2S_TX (
    .reset_n_i(reset_n_i),
    .lmmi_clk_i(lmmi_clk_i),
    .conf_res_i(6'd24),
    .conf_ratio_i(10'd4),
    .conf_swap_i(1'b0),
    .conf_en_i(reset_n_i),
    .i2s_sd_i(1'b0),                
    .sample_dat_i(dac_data),        
    .sample_dat_o(),               
    .mem_rdwr_o(dac_request),       
    .i2s_sd_o(i2s_sd_o),            
    .i2s_sck_o(i2s_sck_o),          
    .i2s_ws_o(i2s_ws_o)            
);

// SPI interface for filter coefficient updates
spi_top dutspitop(
	.sck(sck),
	.sdi(sdi),
	.cs(cs),
	.clk_in(lmmi_clk_i),
	.rst_in(reset_n_i),
	.output_ready(output_ready),
    
    // Low-pass filter coefficients
    .low_b0(low_b0),
    .low_b1(low_b1),
    .low_b2(low_b2),
    .low_a1(low_a1),
    .low_a2(low_a2),
    
    // Mid-pass filter coefficients
    .mid_b0(mid_b0),
    .mid_b1(mid_b1),
    .mid_b2(mid_b2),
    .mid_a1(mid_a1),
    .mid_a2(mid_a2),
    
    // High-pass filter coefficients
    .high_b0(high_b0),
    .high_b1(high_b1),
    .high_b2(high_b2),
    .high_a1(high_a1),
    .high_a2(high_a2),
    
	.spi_valid()
);

endmodule