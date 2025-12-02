/*
Simple MAC16 Gain Test - CORRECTED
Key insight: In the wrapper, mac_rst is inverted before going to MAC16
  assign orsttop = !mac_rst;
  assign orstbot = !mac_rst;
  
So: mac_rst HIGH = accumulator reset
    mac_rst LOW = accumulator active

For multiply-only (no accumulation), we want the accumulator constantly reset.
Therefore: mac_rst should be HIGH
*/

module simple_mac_gain_test(
    input  logic        clk,
    input  logic        l_r_clk,
    input  logic        reset,
    input  logic [15:0] audio_in,
    output logic [15:0] audio_out
);

    // Fixed gain: 0.5 in Q2.14 format
    localparam logic [15:0] GAIN = 16'h2000;  // 0.5 × 2^14 = 8192
    
    logic [31:0] mac_result;
    
    // MAC control
    logic mac_ce;
    logic mac_rst;
    
    assign mac_ce = 1'b1;      // Always enabled
    assign mac_rst = 1'b1;     // Always HIGH = always reset (wrapper inverts it)
    
    // Instantiate MAC
    MAC16_wrapper_accum_drake mac_mult (
        .clk(clk),
        .reset(reset),
        .mac_rst(mac_rst),     // HIGH = reset active (inverted in wrapper)
        .ce(mac_ce),
        .a_in(audio_in),
        .b_in(GAIN),
        .result(mac_result)
    );
    
    // Extract Q2.14 from Q4.28 result
    logic [15:0] mac_out_scaled;
    assign mac_out_scaled = mac_result[29:14];
    
    // Register output
    always_ff @(posedge clk) begin
        if (reset) begin
            audio_out <= 16'd0;
        end else begin
            audio_out <= mac_out_scaled;
        end
    end

endmodule