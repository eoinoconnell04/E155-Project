/*
Author: Eoin O'Connell
Email: eoconnell@hmc.edu
Date: Nov. 13, 2025
Module Function: Time-multiplexed biquad IIR filter
              Designed for DSP inference on iCE40UP5K
              Uses 1 DSP slice per instance (3 total for 3 filters)
              Processes one sample every 7 clock cycles
*/
module iir_filter_implicit(
    input  logic        clk,
    input  logic        reset,
    input  logic        sample_valid,    // strobe when new sample arrives
    input  logic [15:0] latest_sample,   // x[n]
    input  logic [15:0] b0, b1, b2, a1, a2,
    output logic [15:0] filtered_output, // y[n]
    output logic        output_valid     // strobe when output ready
);

    // State machine for time-multiplexed MAC
    typedef enum logic [2:0] {
        IDLE  = 3'd0,
        MULT0 = 3'd1,  // b0 * x[n]
        MULT1 = 3'd2,  // b1 * x[n-1]
        MULT2 = 3'd3,  // b2 * x[n-2]
        MULT3 = 3'd4,  // a1 * y[n-1]
        MULT4 = 3'd5,  // a2 * y[n-2]
        ACCUM = 3'd6,  // Final accumulation
        DONE  = 3'd7
    } state_t;
    
    state_t state;
    
    // Delay line for input samples
    logic signed [15:0] x_n, x_n1, x_n2;
    
    // Delay line for output samples (feedback)
    logic signed [31:0] y_n1, y_n2;
    
    // Multiplier inputs and output (helps DSP inference)
    logic signed [15:0] mult_a;
    logic signed [15:0] mult_b;
    
    // Synthesis attribute to force DSP usage for multiplication
    (* syn_multstyle = "dsp" *)
    logic signed [31:0] mult_out;
    
    // Accumulator
    logic signed [31:0] accumulator;
    
    // Partial products storage
    logic signed [31:0] prod0, prod1, prod2, prod3, prod4;
    
    // Register the multiplication (helps DSP inference)
    always_ff @(posedge clk) begin
        mult_out <= mult_a * mult_b;
    end
    
    // State machine and datapath
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            state <= IDLE;
            x_n <= 16'd0;
            x_n1 <= 16'd0;
            x_n2 <= 16'd0;
            y_n1 <= 32'd0;
            y_n2 <= 32'd0;
            mult_a <= 16'd0;
            mult_b <= 16'd0;
            prod0 <= 32'd0;
            prod1 <= 32'd0;
            prod2 <= 32'd0;
            prod3 <= 32'd0;
            prod4 <= 32'd0;
            accumulator <= 32'd0;
            filtered_output <= 16'd0;
            output_valid <= 1'b0;
        end else begin
            output_valid <= 1'b0;
            
            case (state)
                IDLE: begin
                    if (sample_valid) begin
                        x_n <= latest_sample;
                        // Start first multiplication
                        mult_a <= b0;
                        mult_b <= latest_sample;
                        state <= MULT0;
                    end
                end
                
                MULT0: begin
                    // Capture b0 * x[n], start next multiply
                    prod0 <= mult_out;
                    mult_a <= b1;
                    mult_b <= x_n1;
                    state <= MULT1;
                end
                
                MULT1: begin
                    // Capture b1 * x[n-1], start next multiply
                    prod1 <= mult_out;
                    mult_a <= b2;
                    mult_b <= x_n2;
                    state <= MULT2;
                end
                
                MULT2: begin
                    // Capture b2 * x[n-2], start next multiply
                    prod2 <= mult_out;
                    mult_a <= a1;
                    mult_b <= y_n1[31:16];  // Use upper 16 bits for feedback
                    state <= MULT3;
                end
                
                MULT3: begin
                    // Capture a1 * y[n-1], start next multiply
                    prod3 <= mult_out;
                    mult_a <= a2;
                    mult_b <= y_n2[31:16];  // Use upper 16 bits for feedback
                    state <= MULT4;
                end
                
                MULT4: begin
                    // Capture a2 * y[n-2]
                    prod4 <= mult_out;
                    state <= ACCUM;
                end
                
                ACCUM: begin
                    // Compute: y[n] = b0*x[n] + b1*x[n-1] + b2*x[n-2] - a1*y[n-1] - a2*y[n-2]
                    accumulator <= prod0 + prod1 + prod2 - prod3 - prod4;
                    state <= DONE;
                end
                
                DONE: begin
                    // Update outputs and shift delay lines
                    filtered_output <= accumulator[31:16];
                    
                    // Update delay lines
                    x_n2 <= x_n1;
                    x_n1 <= x_n;
                    y_n2 <= y_n1;
                    y_n1 <= accumulator;
                    
                    output_valid <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule