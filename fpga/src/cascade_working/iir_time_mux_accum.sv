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
    output logic signed [15:0] filtered_output,
    output logic test // y[n]
);

logic output_ready;

    // FSM States - expanded to 4 bits to add DONE state
    typedef enum logic [3:0] {
        IDLE      = 4'd0,
        WAIT1     = 4'd1,
        WAIT2     = 4'd2,
        MULT_B0   = 4'd3,
        MULT_B1   = 4'd4,
        MULT_B2   = 4'd5,
        MULT_A1   = 4'd6,
        MULT_A2   = 4'd7,
       DONE      = 4'd8
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
 
// Shift into pipeline in WAIT1 state (after edge settles)
logic signed [15:0] x_n, x_n1, x_n2;
logic signed [15:0] x_processing;  // â† NEW: latched sample being processed

always_ff @(posedge clk) begin
    if (!reset) begin
        x_n  <= 16'd0;
        x_n1 <= 16'd0;
        x_n2 <= 16'd0;
        x_processing <= 16'd0;  // â† NEW
    end else if (l_r_edge) begin
        x_n  <= latest_sample;
        x_n1 <= x_n;
        x_n2 <= x_n1;
        x_processing <= x_n;  // â† NEW: Latch the sample we're about to process
    end
end
    
    // Output history
    logic signed [15:0] y_n1, y_n2;
    
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
// Coefficient input
logic signed [15:0] mac_a;
    logic signed [15:0] mac_b;  // Data input
    logic signed [31:0] mac_result; // MAC result
    
    // MAC control signals
    logic mac_rst;    // Reset accumulator
    logic mac_ce;     // Clock enable for MAC
    
    // MAC reset control: reset accumulator only when truly idle
    //assign mac_rst = !reset || (state == IDLE && !l_r_edge);
    //assign mac_rst = reset && !(state == IDLE);
assign mac_rst = reset && (state != WAIT1) && (state != WAIT2);
    // MAC clock enable: enable during multiply states
    assign mac_ce = (state == MULT_B0) || (state == MULT_B1) || (state == MULT_B2) || 
                    (state == MULT_A1) || (state == MULT_A2);
    
    // Coefficient and data multiplexing for DSP slice
    always_comb begin
        case (state)
            MULT_B0: begin
                mac_a = b0;
                mac_b = x_n;
            end
            MULT_B1: begin
                mac_a = b1;
                mac_b = x_n1;
            end
            MULT_B2: begin
                mac_a = b2;
                mac_b = x_n2;
            end
            MULT_A1: begin
                mac_a = -a1;  // Negative for IIR feedback
                mac_b = y_n1;
            end
            MULT_A2: begin
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
                next_state = DONE;  // Added DONE state for pipeline delay
            end
            
            DONE: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end
    
logic signed [31:0] mac_result_latched;

always_ff @(posedge clk) begin
    if (!reset) begin
        mac_result_latched <= 32'd0;
    end else if (state == DONE) begin
        mac_result_latched <= mac_result;  
    end
end
always_ff @(posedge clk) begin
    if (!reset) begin
        filtered_output <= 16'd0;
        output_ready <= 1'b0;
    end else if (l_r_edge) begin  
        filtered_output <= mac_result_latched[29:14];
        output_ready <= 1'b1;
    end else begin
        output_ready <= 1'b0;
    end
end
    // Instantiate DSP slice with accumulator
    MAC16_wrapper_accum mac_inst(
        .clk(clk),
        .reset(reset),
        .mac_rst(mac_rst),
        .ce(mac_ce),
        .a_in(mac_a), 
        .b_in(mac_b), 
        .result(mac_result)
    );

assign test = mac_rst;

endmodule 