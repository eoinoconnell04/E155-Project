// ============================================================================
// DSP Multiply-Add Module for Lattice MAC16
// Operation: c = a * b + din
// Optimized for DSP inference with proper bit widths
// ============================================================================

module multaddsub #(
    parameter A_WIDTH = 16,  // Multiplier input A width
    parameter B_WIDTH = 16,  // Multiplier input B width
    parameter ACC_WIDTH = 32 // Accumulator/din width (must match output)
) (
    input  signed [A_WIDTH-1:0]   a,    // Multiplier input A (16-bit)
    input  signed [B_WIDTH-1:0]   b,    // Multiplier input B (16-bit)
    input  signed [ACC_WIDTH-1:0] din,  // Accumulator input (32-bit)
    output signed [ACC_WIDTH-1:0] c     // Result (32-bit)
);

    // Direct assignment - synthesis should infer MAC16
    // This matches the pattern: 16x16 multiply + 32-bit accumulate
    assign c = a * b + din;

endmodule