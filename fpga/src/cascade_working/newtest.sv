// Drake Gonzales
// drgonzales@g.hmc.edu
// This module was made for the purpose of testing our state machine by throwing in input rows
// 9/20/25
`timescale 1ns/1ps

module test1();
logic clk, reset, l_r_clk, mac_a, filter_bypass;
logic signed [15:0] audio_in, audio_out;
logic signed [15:0] LOW_B0, LOW_B1, LOW_B2, LOW_A1, LOW_A2, MID_B0, MID_B1, MID_B2, MID_A1, MID_A2, HIGH_B0, HIGH_B1, HIGH_B2, HIGH_A1, HIGH_A2;

three_band_eq three(clk, l_r_clk, reset, filter_bypass, audio_in, LOW_B0, LOW_B1, LOW_B2, LOW_A1, LOW_A2, MID_B0, MID_B1, MID_B2, MID_A1, MID_A2, HIGH_B0, HIGH_B1, HIGH_B2, HIGH_A1, HIGH_A2,audio_out, mac_a);


always begin
clk = 0;
clk=1; #5; 
clk=0; #5;
end

always begin
l_r_clk = 0;
l_r_clk=1; #10; 
l_r_clk=0; #10;
end

initial begin 
reset=0; #22; 
reset=1;

audio_in = 16'h2000;  // ~0.020 in Q2.14
 LOW_B0 = 16'sh4000;  // 0.061
LOW_B1 = 16'sh0000;  // 0.061
LOW_B2 = 16'sh0000;  // 0.0
LOW_A1 = 16'sh0000;  // 0.877 (negated to -0.877)
LOW_A2 = 16'sh0000;  // 0.0

// Mid-pass filter coefficients (500Hz-5kHz bandpass)
MID_B0 = 16'sh4000;  // 1.0
MID_B1 = 16'sh0000;  // 0.0
MID_B2 = 16'sh0000;  // 0.0
MID_A1 = 16'sh0000;  // 0.0
MID_A2 = 16'sh0000;  // 0.0

// High-pass filter coefficients (5kHz cutoff)
HIGH_B0 = 16'sh4000;  // 0.750
HIGH_B1 = 16'sh0000;  // -0.750
HIGH_B2 = 16'sh0000;  // 0.0
HIGH_A1 = 16'sh0000;  // 0.500 (negated to -0.500)
HIGH_A2 = 16'sh0000;  // 0.0
#50;

audio_in = 16'h4000;
    
#50;

audio_in = 16'h7FFF;
	
end

endmodule