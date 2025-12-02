module top_new(input  logic reset_n_i,      
			input  logic i2s_sd_i,
			//output logic adc_is2_value,
			output logic lmmi_clk_i,    
			output logic i2s_sd_o,          
			output logic i2s_sck_o,        
			output logic i2s_ws_o,
			output logic adc_test,
			output logic conf_en_i);


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
    .CLKHF(lmmi_clk_i));
	
//assign dac_data = 32'h00010001;
//assign dac_data = adc_data;


//logic [31:0] counter = 0;
always_ff @(posedge lmmi_clk_i)
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
	
logic signed [23:0] s_adc;
logic signed [23:0] s_proc;

assign s_adc  = latch_data[23:0];     // signed interpretation
assign s_proc = s_adc >>> 3;          // arithmetic divide by two

//assign dac_data = {8'd0, s_proc};     // repack for the 32-bit I2S interface
	
//audio_filter_top_24bit filter(lmmi_clk_i, ~reset_n_i, s_proc, dac_data); 
//audio_filter_top filter(lmmi_clk_i, ~reset_n_i, s_proc, dac_data); 
//assign dac_data = $signed(latch_data) >>> 1;
//assign dac_data = latch_data; 
assign adc_test = adc_valid;

//assign dac_data = {8'b0, latch_data[23:8], 8'b0};

//assign dac_data = counter;
//assign adc_i2s_value = i2s_sd_i;

// Filter coefficient parameters (Q2.14 format)
// Low-pass filter coefficients (500Hz cutoff, Fs=48kHz, Q=0.707 Butterworth)
logic signed [15:0] low_b0 = 16'sh0147;  // ~0.020 in Q2.14
logic signed [15:0] low_b1 = 16'sh028E;  // ~0.040 in Q2.14
logic signed [15:0] low_b2 = 16'sh0147;  // ~0.020 in Q2.14
logic signed [15:0] low_a1 = 16'sh6A3D;  // ~1.659 in Q2.14
logic signed [15:0] low_a2 = 16'shD89F;  // ~-0.618 in Q2.14

// Band-pass filter coefficients (500Hz-5kHz, Fs=48kHz, Q=1.0)
logic signed [15:0] mid_b0 = 16'sh0CCC;  // ~0.200 in Q2.14
logic signed [15:0] mid_b1 = 16'sh0000;  // 0.0 in Q2.14
logic signed [15:0] mid_b2 = 16'shF334;  // ~-0.200 in Q2.14
logic signed [15:0] mid_a1 = 16'sh5A82;  // ~1.414 in Q2.14
logic signed [15:0] mid_a2 = 16'shE666;  // ~-0.400 in Q2.14

// High-pass filter coefficients (5kHz cutoff, Fs=48kHz, Q=0.707 Butterworth)
logic signed [15:0] high_b0 = 16'sh2E8B;  // ~0.728 in Q2.14
logic signed [15:0] high_b1 = 16'shA2EA;  // ~-1.456 in Q2.14
logic signed [15:0] high_b2 = 16'sh2E8B;  // ~0.728 in Q2.14
logic signed [15:0] high_a1 = 16'shA5C3;  // ~-1.407 in Q2.14
logic signed [15:0] high_a2 = 16'sh1F5C;  // ~0.490 in Q2.14

logic [15:0] audio_out;
logic signed [15:0] low_band_out;   // Individual band outputs for monitoring
logic signed [15:0] mid_band_out;
logic signed [15:0] high_band_out;

assign dac_data = {8'b0, audio_out, 8'b0};

three_band_eq_adjust filter(
    .clk(lmmi_clk_i),
    .l_r_clk(i2s_ws_o), // check this is actually l_r_clk
    .reset(reset_n_i),
    .audio_in(latch_data[23:8]),
    
    // Low-pass filter coefficients
    .low_b0(low_b0),
    .low_b1(low_b1),
    .low_b2(low_b2),
    .low_a1(low_a1),
    .low_a2(low_a2),
    
    // Band-pass filter coefficients
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
    .low_band_out(low_band_out),
    .mid_band_out(mid_band_out),
    .high_band_out(high_band_out)
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



//input                      reset_n_i;     //-- Reset
//input                      lmmi_clk_i;    //-- sys clock
//input              [5 : 0] conf_res_i;    //-- sample resolution
//input              [9 : 0] conf_ratio_i;  //-- clock divider ratio
//input                      conf_swap_i;   //-- left/right sample order
//input                      conf_en_i;     //-- transmitter/recevier enable
//input                      i2s_sd_i;      //-- I2S serial data input -- din
//input             [31 : 0] sample_dat_i;  //-- audio data --  i2din
//output            [31 : 0] sample_dat_o;  //-- audio data -- i2dout
//output                     mem_rdwr_o;    //-- sample buffer read/write
//output                     i2s_sd_o;      //-- I2S serial data output -- dout
//output                     i2s_sck_o;     //-- I2S clock output --bclk
//output                     i2s_ws_o;      //-- I2S word select output -- lrclk

endmodule