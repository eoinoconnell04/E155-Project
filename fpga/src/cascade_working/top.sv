module top(//input logic int_osc,
			input  logic reset_n_i, 
            //input  logic filter_bypass,     
			input  logic i2s_sd_i,
			//output logic adc_is2_value,
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

// Filter coefficient parameters
// Low-pass filter coefficients (500Hz cutoff)
localparam logic signed [15:0] LOW_B0 = 16'sh4000;  // 0.061
localparam logic signed [15:0] LOW_B1 = 16'sh0000;  // 0.061
localparam logic signed [15:0] LOW_B2 = 16'sh0000;  // 0.0
localparam logic signed [15:0] LOW_A1 = 16'sh0000;  // 0.877 (negated to -0.877)
localparam logic signed [15:0] LOW_A2 = 16'sh0000;  // 0.0

// Mid-pass filter coefficients (500Hz-5kHz bandpass)
localparam logic signed [15:0] MID_B0 = 16'sh4000;  // 1.0
localparam logic signed [15:0] MID_B1 = 16'sh0000;  // 0.0
localparam logic signed [15:0] MID_B2 = 16'sh0000;  // 0.0
localparam logic signed [15:0] MID_A1 = 16'sh0000;  // 0.0
localparam logic signed [15:0] MID_A2 = 16'sh0000;  // 0.0

// High-pass filter coefficients (5kHz cutoff)
localparam logic signed [15:0] HIGH_B0 = 16'sh4000;  // 0.750
localparam logic signed [15:0] HIGH_B1 = 16'sh0000;  // -0.750
localparam logic signed [15:0] HIGH_B2 = 16'sh0000;  // 0.0
localparam logic signed [15:0] HIGH_A1 = 16'sh0000;  // 0.500 (negated to -0.500)
localparam logic signed [15:0] HIGH_A2 = 16'sh0000;  // 0.0

HSOSC #(.CLKHF_DIV ("0b10")) hf_osc (
.CLKHFPU(1'b1),
    .CLKHFEN(1'b1),
    .CLKHF(lmmi_clk_i));
	
//assign lmmi_clk_i = int_osc;
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
	
//logic signed [23:0] s_adc;
//logic signed [23:0] s_proc;

//assign s_adc  = latch_data[23:0];     // signed interpretation
//assign s_proc = s_adc >>> 3;          // arithmetic divide by two

//assign dac_data = {8'd0, s_proc};     // repack for the 32-bit I2S interface
	
//audio_filter_top_24bit filter(lmmi_clk_i, ~reset_n_i, s_proc, dac_data); 
//audio_filter_top filter(lmmi_clk_i, ~reset_n_i, s_proc, dac_data); 
//assign dac_data = $signed(latch_data) >>> 1;
//assign dac_data = latch_data; 
assign adc_test = adc_valid;

//assign dac_data = {8'b0, latch_data[23:8], 8'b0};

//assign dac_data = counter;
//assign adc_i2s_value = i2s_sd_i;
logic signed [15:0] audio_out;
assign dac_data = {8'b0, audio_out, 8'b0};

//assign dac_data = filter_bypass ? {8'b0, audio_out, 8'b0} : {8'b0, latch_data[23:8], 8'b0};

three_band_eq filter(
    .clk(lmmi_clk_i),
    .l_r_clk(i2s_ws_o), // check this is actually l_r_clk
    .reset(reset_n_i),
    //.filter_bypass(filter_bypass),
    .audio_in(latch_data[23:8]),
    // Low-pass filter coefficients
    .low_b0(LOW_B0),
    .low_b1(LOW_B1),
    .low_b2(LOW_B2),
    .low_a1(LOW_A1),
    .low_a2(LOW_A2),
    // Mid-pass filter coefficients
    .mid_b0(MID_B0),
    .mid_b1(MID_B1),
    .mid_b2(MID_B2),
    .mid_a1(MID_A1),
    .mid_a2(MID_A2),
    // High-pass filter coefficients
    .high_b0(HIGH_B0),
    .high_b1(HIGH_B1),
    .high_b2(HIGH_B2),
    .high_a1(HIGH_A1),
    .high_a2(HIGH_A2),
    .audio_out(audio_out),
	.mac_a(mac_a)
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