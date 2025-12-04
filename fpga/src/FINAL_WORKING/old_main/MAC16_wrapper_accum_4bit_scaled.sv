module MAC16_wrapper_accum_4bit_scaled (
    input logic clk,
    input logic reset,              // system level reset
    input logic mac_rst,                    // Reset signal for accumulator
    input logic ce,                       // Clock enable
    input logic signed [15:0] a_in,       // Signed 16-bit input A (only top 4 bits used)
    input logic signed [15:0] b_in,       // Signed 16-bit input B (only top 4 bits used)
    output logic signed [31:0] result     // Signed 32-bit output (scaled back up)
);

    // Extract top 4 bits
    logic signed [3:0] a_reduced, b_reduced;
    assign a_reduced = a_in[15:12];
    assign b_reduced = b_in[15:12];
    
    // Internal 12-bit accumulator (gives headroom for accumulation)
    logic signed [11:0] accumulator_small;
    
    // Registered inputs
    logic signed [3:0] a_reg, b_reg;
    logic ce_reg;
    
    // Register inputs
    always_ff @(posedge clk) begin
        if (!reset) begin
            a_reg <= 4'd0;
            b_reg <= 4'd0;
            ce_reg <= 1'b0;
        end else begin
            a_reg <= a_reduced;
            b_reg <= b_reduced;
            ce_reg <= ce;
        end
    end
    
    // MAC operation
    always_ff @(posedge clk) begin
        if (!mac_rst) begin
            accumulator_small <= 12'd0;
        end else if (ce_reg) begin
            accumulator_small <= (a_reg * b_reg) + accumulator_small;
        end
    end
    
    // Scale result back up: shift left by 12 to restore magnitude
    // This puts the 4-bit result back in the position of the original 16-bit MSBs
    assign result = {{20{accumulator_small[11]}}, accumulator_small};

endmodule