// ============================================================================
// Top-level test module for DSP Multiply-Add
// Instantiates multaddsub with external pipeline registers
// Suitable for synthesis and FPGA implementation testing
// ============================================================================

module test_multaddsub_top (
    input  wire        clk,
    input  wire        rst,
    
    // Control signals
    input  wire        enable,
    input  wire        load_acc,  // Load new accumulator value
    
    // Data inputs
    input  wire signed [15:0] a_in,
    input  wire signed [15:0] b_in,
    input  wire signed [31:0] din_in,
    
    // Data output
    output reg signed [31:0] result_out,
    
    // Status
    output reg        valid_out
);

    // Internal signals
    wire signed [31:0] dsp_result;
    reg signed [15:0]  a_reg;
    reg signed [15:0]  b_reg;
    reg signed [31:0]  accumulator;
    
    // Pipeline control
    reg [1:0] pipeline_valid;
    
    // Instantiate the combinatorial DSP multiply-add
    multaddsub #(
        .A_WIDTH(16),
        .B_WIDTH(16),
        .ACC_WIDTH(32)
    ) dsp_core (
        .a(a_reg),
        .b(b_reg),
        .din(accumulator),
        .c(dsp_result)
    );
    
    // Input stage: Register inputs
    always_ff @(posedge clk) begin
        if (rst) begin
            a_reg <= 16'sd0;
            b_reg <= 16'sd0;
        end else if (enable) begin
            a_reg <= a_in;
            b_reg <= b_in;
        end
    end
    
    // Accumulator logic
    always_ff @(posedge clk) begin
        if (rst) begin
            accumulator <= 32'sd0;
        end else if (load_acc) begin
            // Load new accumulator value from input
            accumulator <= din_in;
        end else if (enable) begin
            // Feedback: accumulator gets previous result
            accumulator <= dsp_result;
        end
    end
    
    // Output stage: Register result
    always_ff @(posedge clk) begin
        if (rst) begin
            result_out <= 32'sd0;
        end else if (enable) begin
            result_out <= dsp_result;
        end
    end
    
    // Valid signal pipeline (tracks when output is valid)
    always_ff @(posedge clk) begin
        if (rst) begin
            pipeline_valid <= 2'b00;
        end else begin
            pipeline_valid <= {pipeline_valid[0], enable};
        end
    end
    
    assign valid_out = pipeline_valid[1];

endmodule