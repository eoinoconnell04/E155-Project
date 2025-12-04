/*
Author: Eoin O'Connell
Email: eoconnell@hmc.edu
Date: Nov. 19, 2025
Module Function: 16-bit biquad IIR filter with time-multiplexed DSP slice
Coefficients: Q2.14 format
Inputs/outputs: 16-bit signed audio samples
*/
module iir_time_mux_accum(
    input  logic        clk,         // High speed system clock
    input  logic        l_r_clk,     // Left right select (new sample on every edge)
    input  logic        reset,
    input  logic signed [15:0] latest_sample,   // x[n]
    input  logic signed [15:0] b0, b1, b2, a1, a2,
    output logic signed [15:0] filtered_output  // y[n]
);

    // FSM States - need wait states between MAC operations
    typedef enum logic [4:0] {
        IDLE       = 5'd0,
        WAIT1      = 5'd1,
        WAIT2      = 5'd2,
        MULT_B0    = 5'd3,
        WAIT_B0    = 5'd4,   // Wait for b0*x[n] to complete
        MULT_B1    = 5'd5,
        WAIT_B1    = 5'd6,   // Wait for b1*x[n-1] to complete
        MULT_B2    = 5'd7,
        WAIT_B2    = 5'd8,   // Wait for b2*x[n-2] to complete
        MULT_A1    = 5'd9,
        WAIT_A1    = 5'd10,  // Wait for -a1*y[n-1] to complete
        MULT_A2    = 5'd11,
        WAIT_A2    = 5'd12,  // Wait for -a2*y[n-2] to complete
        DONE       = 5'd13
    } state_t;
    
    state_t state, next_state;
    
    // Edge detection for l_r_clk (detects any edge)
    logic l_r_clk_d1, l_r_clk_d2;
    logic l_r_edge;
    
    always_ff @(posedge clk) begin
        if (!reset) begin
            l_r_clk_d1 <= 1'b0;
            l_r_clk_d2 <= 1'b0;
        end else begin
            l_r_clk_d1 <= l_r_clk;
            l_r_clk_d2 <= l_r_clk_d1;
            l_r_edge <= l_r_clk_d1 ^ l_r_clk_d2;
        end
    end
    
    // Sample shift registers (x[n], x[n-1], x[n-2])
    logic signed [15:0] x_n, x_n1, x_n2;
    
    always_ff @(posedge clk) begin
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
    
    always_ff @(posedge clk) begin
        if (!reset) begin
            y_n1 <= 16'd0;
            y_n2 <= 16'd0;
        end else if (output_ready) begin
            y_n1 <= filtered_output;
            y_n2 <= y_n1;
        end
    end
    
    // DSP slice inputs
    logic signed [15:0] mac_a;  // Coefficient input
    logic signed [15:0] mac_b;  // Data input
    logic signed [31:0] mac_result; // MAC result
    
    // MAC control signals
    logic mac_rst;    // Reset accumulator
    logic mac_ce;     // Clock enable for MAC
    
    // MAC reset control: reset accumulator when entering computation
    assign mac_rst = reset && !(state == IDLE && l_r_edge);

    // MAC clock enable: ONLY assert for ONE cycle per operation
    // This ensures each MAC operation completes before the next starts
    assign mac_ce = (state == MULT_B0) || (state == MULT_B1) || (state == MULT_B2) || 
                    (state == MULT_A1) || (state == MULT_A2);
    
    // Coefficient and data multiplexing for DSP slice
    always_comb begin
        case (state)
            MULT_B0, WAIT_B0: begin
                mac_a = b0;
                mac_b = x_n;
            end
            MULT_B1, WAIT_B1: begin
                mac_a = b1;
                mac_b = x_n1;
            end
            MULT_B2, WAIT_B2: begin
                mac_a = b2;
                mac_b = x_n2;
            end
            MULT_A1, WAIT_A1: begin
                mac_a = -a1;  // Negative for IIR feedback
                mac_b = y_n1;
            end
            MULT_A2, WAIT_A2: begin
                mac_a = -a2;  // Negative for IIR feedback
                mac_b = y_n2;
            end
            default: begin
                mac_a = 16'd0;
                mac_b = 16'd0;
            end
        endcase
    end
    
    // FSM state register
    always_ff @(posedge clk) begin
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
                next_state = WAIT_B0;
            end
            
            WAIT_B0: begin
                next_state = MULT_B1;
            end
            
            MULT_B1: begin
                next_state = WAIT_B1;
            end
            
            WAIT_B1: begin
                next_state = MULT_B2;
            end
            
            MULT_B2: begin
                next_state = WAIT_B2;
            end
            
            WAIT_B2: begin
                next_state = MULT_A1;
            end
            
            MULT_A1: begin
                next_state = WAIT_A1;
            end
            
            WAIT_A1: begin
                next_state = MULT_A2;
            end
            
            MULT_A2: begin
                next_state = WAIT_A2;
            end
            
            WAIT_A2: begin
                next_state = DONE;
            end
            
            DONE: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end
    
    // Output logic - extract Q2.14 result from Q4.28 accumulator
    // mac_result[31:0] contains accumulated (a*b) where a,b are Q2.14, so product is Q4.28
    // Sample result in DONE state (after pipeline completes)
    always_ff @(posedge clk) begin
        if (!reset) begin
            filtered_output <= 16'd0;
            output_ready <= 1'b0;
        end else if (state == DONE) begin
            // Truncate from Q4.28 to Q2.14
            filtered_output <= mac_result[29:14];
            output_ready <= 1'b1;
        end else begin
            output_ready <= 1'b0;
        end
    end
    
    // Instantiate DSP slice with accumulator
    MAC16_wrapper_accum_drake mac_inst(
        .clk(clk),
        .reset(reset),
        .mac_rst(mac_rst),
        .ce(mac_ce),
        .a_in(mac_a), 
        .b_in(mac_b), 
        .result(mac_result)
    );

endmodule