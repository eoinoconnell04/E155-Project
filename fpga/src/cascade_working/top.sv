module top(input logic sck, sdi, cs,
			input  logic reset_n_i, 
			input  logic i2s_sd_i,
			output logic lmmi_clk_i,    
			output logic i2s_sd_o,          
			output logic i2s_sck_o,        
			output logic i2s_ws_o,
			output logic adc_test,
			output logic conf_en_i,
			output logic mac_a);


logic [5:0]  conf_res_i    = 6'd24;
logic [9:0]  conf_ratio_i  = 10'd4;
logic        conf_swap_i   = 1'b0;

logic [31:0] adc_data;           
logic [31:0] dac_data;

logic        adc_valid;         
logic        dac_request;       

logic [31:0] latch_data;

HSOSC #(.CLKHF_DIV ("0b10")) hf_osc (
    .CLKHFPU(1'b1),
    .CLKHFEN(1'b1),
    .CLKHF(lmmi_clk_i)
);

always_ff @(posedge lmmi_clk_i) begin
	if (reset_n_i == 0) begin
		conf_en_i  <= 1'b0;
		latch_data <= 32'd0; 
	end 
	else begin 
		conf_en_i  <= 1'b1;
		if (adc_valid) begin 
			latch_data <= adc_data;
		end
	end 
end

assign adc_test = adc_valid;

logic signed [15:0] audio_out;
assign dac_data = {8'b0, audio_out, 8'b0};
logic signed [15:0] low_b0, low_b1, low_b2, low_a1, low_a2, mid_b0, mid_b1, mid_b2, mid_a1, mid_a2, high_b0, high_b1, high_b2, high_a1, high_a2;
// ============================================================================
// TEST CONFIGURATION - Change these values to test different coefficients
// ============================================================================
// Current: All stages at 0.5 gain = 0.125 total (should be audible but quieter)
// Try changing these values and re-synthesizing to test different configs

three_band_eq filter(
    .clk(lmmi_clk_i),
    .l_r_clk(i2s_ws_o),
    .reset(reset_n_i),
    .audio_in(latch_data[23:8]),
    
    // Low-pass filter coefficients - 0.5 gain
    .low_b0(low_b0),  // 0.5 in Q2.14
    .low_b1(low_b1),  // 0.0
    .low_b2(low_b2),  // 0.0
    .low_a1(low_a1),  // 0.0
    .low_a2(low_a2),  // 0.0
    
    // Mid-pass filter coefficients - 0.5 gain
    .mid_b0(mid_b0),  // 0.5 in Q2.14
    .mid_b1(mid_b1),  // 0.0
    .mid_b2(mid_b2),  // 0.0
    .mid_a1(mid_a1),  // 0.0
    .mid_a2(mid_a2),  // 0.0
    
    // High-pass filter coefficients - 0.5 gain
    .high_b0(high_b0), // 0.5 in Q2.14
    .high_b1(high_b1), // 0.0
    .high_b2(high_b2), // 0.0
    .high_a1(high_a1), // 0.0
    .high_a2(high_a2), // 0.0
    
    .audio_out(audio_out),
    .mac_a()
);

lscc_i2s_codec #(
    .DATA_WIDTH       (24),
    .TRANSCEIVER_MODE (1)         
) I2S_RX (
    .reset_n_i(reset_n_i),
    .lmmi_clk_i(lmmi_clk_i),
    .conf_res_i(conf_res_i),
    .conf_ratio_i(conf_ratio_i),
    .conf_swap_i(conf_swap_i),
    .conf_en_i(conf_en_i),
    .i2s_sd_i(i2s_sd_i),           
    .sample_dat_i(32'h0),           
    .sample_dat_o(adc_data),       
    .mem_rdwr_o(adc_valid),         
    .i2s_sd_o(),                    
    .i2s_sck_o(),                   
    .i2s_ws_o()                     
);

lscc_i2s_codec #(
    .DATA_WIDTH       (24),
    .TRANSCEIVER_MODE (0)          
) I2S_TX (
    .reset_n_i(reset_n_i),
    .lmmi_clk_i(lmmi_clk_i),
    .conf_res_i(conf_res_i),
    .conf_ratio_i(conf_ratio_i),
    .conf_swap_i(conf_swap_i),
    .conf_en_i(conf_en_i),
    .i2s_sd_i(1'b0),                
    .sample_dat_i(dac_data),        
    .sample_dat_o(),               
    .mem_rdwr_o(dac_request),       
    .i2s_sd_o(i2s_sd_o),            
    .i2s_sck_o(i2s_sck_o),          
    .i2s_ws_o(i2s_ws_o)            
);


spi_top dutspitop(
	.sck(sck),
	.sdi(sdi),
	.cs(cs),
	.clk_in(lmmi_clk_i),
	.rst_in(reset_n_i),
    // Low-pass filter coefficients - 0.5 gain
    .low_b0(low_b0),  // 0.5 in Q2.14
    .low_b1(low_b1),  // 0.0
    .low_b2(low_b2),  // 0.0
    .low_a1(low_a1),  // 0.0
    .low_a2(low_a2),  // 0.0
    
    // Mid-pass filter coefficients - 0.5 gain
    .mid_b0(mid_b0),  // 0.5 in Q2.14
    .mid_b1(mid_b1),  // 0.0
    .mid_b2(mid_b2),  // 0.0
    .mid_a1(mid_a1),  // 0.0
    .mid_a2(mid_a2),  // 0.0
    
    // High-pass filter coefficients - 0.5 gain
    .high_b0(high_b0), // 0.5 in Q2.14
    .high_b1(high_b1), // 0.0
    .high_b2(high_b2), // 0.0
    .high_a1(high_a1), // 0.0
    .high_a2(high_a2), // 0.0
	.spi_valid(mac_a));

//assign mac_a = cs; 

endmodule

