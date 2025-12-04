module control(
    input  logic [335:0] data, 
    // Low-pass filter coefficients
    output logic signed [15:0] low_b0, low_b1, low_b2, low_a1, low_a2,
    // Mid-pass filter coefficients
    output logic signed [15:0] mid_b0, mid_b1, mid_b2, mid_a1, mid_a2,
    // High-pass filter coefficients
    output logic signed [15:0] high_b0, high_b1, high_b2, high_a1, high_a2
);

// data[335:320] = 0xAA55 (sync bytes)
// data[319:240] = 5 ADC values (not used)

// Extract Low-pass coefficients (10 bytes = 80 bits)
assign low_b0 = data[239:224];  // 0x4000
assign low_b1 = data[223:208];  // 0x0000
assign low_b2 = data[207:192];  // 0x0000
assign low_a1 = data[191:176];  // 0x0000
assign low_a2 = data[175:160];  // 0x0000

// Extract Mid-pass coefficients (10 bytes = 80 bits)
assign mid_b0 = data[159:144];  // 0x4000
assign mid_b1 = data[143:128];  // 0x0000
assign mid_b2 = data[127:112];  // 0x0000
assign mid_a1 = data[111:96];   // 0x0000
assign mid_a2 = data[95:80];    // 0x0000

// Extract High-pass coefficients (10 bytes = 80 bits)
assign high_b0 = data[79:64];   // 0x4000
assign high_b1 = data[63:48];   // 0x0000
assign high_b2 = data[47:32];   // 0x0000
assign high_a1 = data[31:16];   // 0x0000
assign high_a2 = data[15:0];    // 0x0000

endmodule