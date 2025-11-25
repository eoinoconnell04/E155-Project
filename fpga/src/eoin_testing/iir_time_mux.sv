/*
Author: Eoin O'Connell
Email: eoconnell@hmc.edu
Date: Nov. 19, 2025
Module Function: 16-bit biquad IIR filter with time-multiplexed DSP slice
Coefficients: Q2.14 format
Inputs/outputs: 16-bit signed audio samples
*/
module iir_time_mux(
    input  logic        clk,         // High speed system clock
    input  logic        l_r_clk,     // Left right select (new sample on every edge)
    input  logic        reset,
    input  logic signed [15:0] latest_sample,   // x[n]
    input  logic signed [15:0] b0, b1, b2, a1, a2,
    output logic signed [15:0] filtered_output  // y[n]
);

    // FSM States
    typedef enum logic [2:0] {
        IDLE      = 3'd0,
        WAIT1     = 3'd1,
        WAIT2     = 3'd2,
        MULT_B0   = 3'd3,
        MULT_B1   = 3'd4,
        MULT_B2   = 3'd5,
        MULT_A1   = 3'd6,
        MULT_A2   = 3'd7
    } state_t;
    
    state_t state, next_state;
    
    // Edge detection for l_r_clk (detects any edge)
    logic l_r_clk_d1, l_r_clk_d2;
    logic l_r_edge;
    
    always_ff @(posedge clk or negedge reset) begin
        if (!reset) begin
            l_r_clk_d1 <= 1'b0;
            l_r_clk_d2 <= 1'b0;
        end else begin
            l_r_clk_d1 <= l_r_clk;
            l_r_clk_d2 <= l_r_clk_d1;
        end
    end
    
    assign l_r_edge = l_r_clk_d1 ^ l_r_clk_d2;  // Any edge detection
    
    // Sample shift registers (x[n], x[n-1], x[n-2])
    logic signed [15:0] x_n, x_n1, x_n2;
    
    always_ff @(posedge clk or negedge reset) begin
        if (!reset) begin
            x_n  <= 16'd0;
            x_n1 <= 16'd0;
            x_n2 <= 16'd0;
        end else if (l_r_edge) begin
            x_n  <= latest_sample;
            x_n1 <= x_n;
            x_n2 <= x_n1;
        end
    end
    
    // Output history shift registers (y[n-1], y[n-2])
    logic signed [15:0] y_n1, y_n2;
    logic output_ready;
    
    always_ff @(posedge clk or negedge reset) begin
        if (!reset) begin
            y_n1 <= 16'd0;
            y_n2 <= 16'd0;
        end else if (output_ready) begin
            y_n1 <= filtered_output;
            y_n2 <= y_n1;
        end
    end
    
    // DSP slice inputs
    logic signed [15:0] a_in;  // Coefficient input
    logic signed [15:0] b_in;  // Data input
    logic signed [47:0] c_in;  // Accumulator input
    logic signed [47:0] result; // MAC result
    
    // Accumulator register
    logic signed [47:0] accumulator;
    
    always_ff @(posedge clk or negedge reset) begin
        if (!reset) begin
            accumulator <= 48'd0;
        end else begin
            case (state)
                IDLE, WAIT1, WAIT2: begin
                    accumulator <= 48'd0;
                end
                MULT_B0, MULT_B1, MULT_B2, MULT_A1, MULT_A2: begin
                    accumulator <= result;
                end
                default: accumulator <= accumulator;
            endcase
        end
    end
    
    // Connect accumulator to DSP slice c input
    assign c_in = accumulator;
    
    // Coefficient and data multiplexing for DSP slice
    always_comb begin
        case (state)
            MULT_B0: begin
                a_in = b0;
                b_in = x_n;
            end
            MULT_B1: begin
                a_in = b1;
                b_in = x_n1;
            end
            MULT_B2: begin
                a_in = b2;
                b_in = x_n2;
            end
            MULT_A1: begin
                a_in = -a1;  // Negative for IIR feedback
                b_in = y_n1;
            end
            MULT_A2: begin
                a_in = -a2;  // Negative for IIR feedback
                b_in = y_n2;
            end
            default: begin
                a_in = 16'd0;
                b_in = 16'd0;
            end
        endcase
    end
    
    // FSM state register
    always_ff @(posedge clk or negedge reset) begin
        if (!reset)
            state <= IDLE;
        else
            state <= next_state;
    end
    
    // FSM next state logic
    always_comb begin
        next_state = state;
        
        case (state)
            IDLE: begin
                if (l_r_edge)
                    next_state = WAIT1;
            end
            
            WAIT1: begin
                next_state = WAIT2;
            end
            
            WAIT2: begin
                next_state = MULT_B0;
            end
            
            MULT_B0: begin
                next_state = MULT_B1;
            end
            
            MULT_B1: begin
                next_state = MULT_B2;
            end
            
            MULT_B2: begin
                next_state = MULT_A1;
            end
            
            MULT_A1: begin
                next_state = MULT_A2;
            end
            
            MULT_A2: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end
    
    // Output logic - extract Q2.14 result from Q4.28 accumulator
    // result[47:0] contains (a*b + c) where a,b are Q2.14, so product is Q4.28
    // To get Q2.14 output, take bits [29:14] with rounding
    always_ff @(posedge clk or negedge reset) begin
        if (!reset) begin
            filtered_output <= 16'd0;
            output_ready <= 1'b0;
        end else if (state == MULT_A2) begin
            // Round and truncate from Q4.28 to Q2.14
            // Add 0.5 LSB for rounding: add 2^13 to bit position 14
            filtered_output <= result[29:14] + result[13];
            output_ready <= 1'b1;
        end else begin
            output_ready <= 1'b0;
        end
    end
    
    // Instantiate DSP slice
    MAC16_wrapper m1(
        .a_in(a_in), 
        .b_in(b_in), 
        .c_in(c_in), 
        .result(result)
    );

endmodule