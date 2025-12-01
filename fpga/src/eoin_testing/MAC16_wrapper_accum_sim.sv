module MAC16_wrapper_accum_sim (
    input logic clk,
    input logic rst,                    // Active-low reset
    input logic ce,                       // Clock enable
    input logic signed [15:0] a_in,       // Signed 16-bit input A
    input logic signed [15:0] b_in,       // Signed 16-bit input B
    output logic signed [31:0] result     // Signed 32-bit accumulated output
);

    // Internal accumulator
    logic signed [31:0] accumulator;
    
    // Registered inputs
    logic signed [15:0] a_reg, b_reg;
    logic ce_reg;
    
    // Register inputs
    always_ff @(posedge clk) begin
        if (!rst) begin
            a_reg <= 16'd0;
            b_reg <= 16'd0;
            ce_reg <= 1'b0;
        end else begin
            a_reg <= a_in;
            b_reg <= b_in;
            ce_reg <= ce;
        end
    end
    
    // MAC operation: result = a * b + previous_result
    always_ff @(posedge clk) begin
        if (!rst) begin
            accumulator <= 32'd0;
        end else if (ce_reg) begin
            // Multiply and accumulate
            accumulator <= (a_reg * b_reg) + accumulator;
        end
    end
    
    assign result = accumulator;

endmodule