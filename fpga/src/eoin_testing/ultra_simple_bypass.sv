/*
Ultra-Simple Bypass Test Module
This module does NOTHING except pass through the input with a small delay.
Use this to verify that:
1. Audio data is reaching the filter module
2. The l_r_clk is working
3. The basic pipeline structure is correct
*/

module ultra_simple_bypass(
    input  logic        clk,
    input  logic        l_r_clk,
    input  logic        reset,
    input  logic signed [15:0] audio_in,
    output logic signed [15:0] audio_out
);

    // Just pass through with 3 cycle delay to match MAC latency
    logic signed [15:0] pipe1, pipe2, pipe3;
    
    always_ff @(posedge clk) begin
        if (reset) begin
            pipe1 <= 16'd0;
            pipe2 <= 16'd0;
            pipe3 <= 16'd0;
        end else begin
            pipe1 <= audio_in;
            pipe2 <= pipe1;
            pipe3 <= pipe2;
        end
    end
    
    // Choose your test:
    
    // Test 1: Direct passthrough (0 delay) - should work if wiring is correct
    assign audio_out = audio_in;
    
    // Test 2: Half volume (proves arithmetic works)
    // assign audio_out = audio_in >>> 1;
    
    // Test 3: With pipeline delay (matches MAC latency)
    // assign audio_out = pipe3;
    
endmodule