/*
Author: Eoin O'Connell
Email: eoconnell@hmc.edu
Date: Nov. 13, 2025
Module Function: Time-multiplexed biquad IIR filter using explicit SB_MAC16
              Guarantees 1 DSP slice usage per instance
*/

// `include "iCE40UP5K.v"

module iir_filter_DSP_slice(
    input  logic        clk,
    input  logic        reset,
    input  logic        sample_valid,    // strobe when new sample arrives
    input  logic [15:0] latest_sample,   // x[n]
    input  logic [15:0] b0, b1, b2, a1, a2,
    output logic [15:0] filtered_output, // y[n]
    output logic        output_valid     // strobe when output ready
);

    // State machine
    typedef enum logic [2:0] {
        IDLE  = 3'd0,
        MAC0  = 3'd1,  // b0 * x[n], start accumulation
        MAC1  = 3'd2,  // + b1 * x[n-1]
        MAC2  = 3'd3,  // + b2 * x[n-2]
        MAC3  = 3'd4,  // - a1 * y[n-1]
        MAC4  = 3'd5,  // - a2 * y[n-2]
        DONE  = 3'd6
    } state_t;
    
    state_t state, next_state;
    
    // Sample storage
    logic signed [15:0] x0, x1, x2;
    logic signed [15:0] y1_trunc, y2_trunc;
    logic signed [31:0] y1, y2;
    
    // DSP control signals
    logic [15:0] dsp_a, dsp_b;
    logic [31:0] dsp_c;
    logic [31:0] dsp_o;
    logic        dsp_ce, dsp_irsttop, dsp_irstbot;
    logic        dsp_addsubtop, dsp_addsubbot;
    logic        dsp_oholdtop, dsp_oholdbot;
    logic        dsp_oloadtop, dsp_oloadbot;
    
    // Instantiate SB_MAC16 for guaranteed DSP usage
    SB_MAC16 #(
        .NEG_TRIGGER(1'b0),           // Positive edge
        .C_REG(1'b0),                 // No register on C input
        .A_REG(1'b0),                 // No register on A input  
        .B_REG(1'b0),                 // No register on B input
        .D_REG(1'b0),                 // No register on D input
        .TOP_8x8_MULT_REG(1'b0),      // No pipeline register
        .BOT_8x8_MULT_REG(1'b0),
        .PIPELINE_16x16_MULT_REG1(1'b0),
        .PIPELINE_16x16_MULT_REG2(1'b0),
        .TOPOUTPUT_SELECT(2'b11),     // 16x16 MAC output
        .TOPADDSUB_LOWERINPUT(2'b00), // Adder input
        .TOPADDSUB_UPPERINPUT(1'b0),  // MAC mode
        .TOPADDSUB_CARRYSELECT(2'b00),
        .BOTOUTPUT_SELECT(2'b11),
        .BOTADDSUB_LOWERINPUT(2'b00),
        .BOTADDSUB_UPPERINPUT(1'b0),
        .BOTADDSUB_CARRYSELECT(2'b00),
        .MODE_8x8(1'b0),              // 16x16 mode
        .A_SIGNED(1'b1),              // Signed multiplication
        .B_SIGNED(1'b1)
    ) mac_inst (
        .CLK(clk),
        .CE(dsp_ce),
        .A(dsp_a),
        .B(dsp_b),
        .C(dsp_c),
        .D(16'd0),
        .AHOLD(1'b0),
        .BHOLD(1'b0),
        .CHOLD(1'b0),
        .DHOLD(1'b0),
        .IRSTTOP(dsp_irsttop),
        .IRSTBOT(dsp_irstbot),
        .ORSTTOP(1'b0),
        .ORSTBOT(1'b0),
        .OLOADTOP(dsp_oloadtop),
        .OLOADBOT(dsp_oloadbot),
        .ADDSUBTOP(dsp_addsubtop),
        .ADDSUBBOT(dsp_addsubbot),
        .OHOLDTOP(dsp_oholdtop),
        .OHOLDBOT(dsp_oholdbot),
        .CI(1'b0),
        .ACCUMCI(1'b0),
        .SIGNEXTIN(1'b0),
        .O(dsp_o),
        .CO(),
        .ACCUMCO(),
        .SIGNEXTOUT()
    );
    
    // State machine
    always_ff @(posedge clk or posedge reset) begin
        if (reset)
            state <= IDLE;
        else
            state <= next_state;
    end
    
    always_comb begin
        next_state = state;
        case (state)
            IDLE:  if (sample_valid) next_state = MAC0;
            MAC0:  next_state = MAC1;
            MAC1:  next_state = MAC2;
            MAC2:  next_state = MAC3;
            MAC3:  next_state = MAC4;
            MAC4:  next_state = DONE;
            DONE:  next_state = IDLE;
            default: next_state = IDLE;
        endcase
    end
    
    // Control logic
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            x0 <= 16'd0;
            x1 <= 16'd0;
            x2 <= 16'd0;
            y1 <= 32'd0;
            y2 <= 32'd0;
            y1_trunc <= 16'd0;
            y2_trunc <= 16'd0;
            filtered_output <= 16'd0;
            output_valid <= 1'b0;
            
            dsp_a <= 16'd0;
            dsp_b <= 16'd0;
            dsp_c <= 32'd0;
            dsp_ce <= 1'b0;
            dsp_irsttop <= 1'b1;
            dsp_irstbot <= 1'b1;
            dsp_addsubtop <= 1'b0;
            dsp_addsubbot <= 1'b0;
            dsp_oholdtop <= 1'b0;
            dsp_oholdbot <= 1'b0;
            dsp_oloadtop <= 1'b0;
            dsp_oloadbot <= 1'b0;
        end else begin
            output_valid <= 1'b0;
            dsp_ce <= 1'b1;
            dsp_irsttop <= 1'b0;
            dsp_irstbot <= 1'b0;
            dsp_oholdtop <= 1'b0;
            dsp_oholdbot <= 1'b0;
            
            case (state)
                IDLE: begin
                    if (sample_valid) begin
                        x0 <= latest_sample;
                        y1_trunc <= y1[31:16];
                        y2_trunc <= y2[31:16];
                        // Prepare first multiply
                        dsp_a <= b0;
                        dsp_b <= latest_sample;
                        dsp_c <= 32'd0;
                        dsp_addsubtop <= 1'b0;  // Add
                        dsp_addsubbot <= 1'b0;
                        dsp_oloadtop <= 1'b1;   // Load C value
                        dsp_oloadbot <= 1'b1;
                    end else begin
                        dsp_ce <= 1'b0;
                    end
                end
                
                MAC0: begin
                    // Result from b0*x[n] now in dsp_o
                    // Setup for b1*x[n-1]
                    dsp_a <= b1;
                    dsp_b <= x1;
                    dsp_c <= dsp_o;  // Feed back accumulator
                    dsp_addsubtop <= 1'b0;
                    dsp_addsubbot <= 1'b0;
                    dsp_oloadtop <= 1'b0;  // Accumulate mode
                    dsp_oloadbot <= 1'b0;
                end
                
                MAC1: begin
                    // Accumulating b1*x[n-1]
                    dsp_a <= b2;
                    dsp_b <= x2;
                    dsp_c <= dsp_o;
                    dsp_addsubtop <= 1'b0;
                    dsp_addsubbot <= 1'b0;
                    dsp_oloadtop <= 1'b0;
                    dsp_oloadbot <= 1'b0;
                end
                
                MAC2: begin
                    // Accumulating b2*x[n-2]
                    dsp_a <= a1;
                    dsp_b <= y1_trunc;
                    dsp_c <= dsp_o;
                    dsp_addsubtop <= 1'b1;  // Subtract
                    dsp_addsubbot <= 1'b1;
                    dsp_oloadtop <= 1'b0;
                    dsp_oloadbot <= 1'b0;
                end
                
                MAC3: begin
                    // Subtracting a1*y[n-1]
                    dsp_a <= a2;
                    dsp_b <= y2_trunc;
                    dsp_c <= dsp_o;
                    dsp_addsubtop <= 1'b1;  // Subtract
                    dsp_addsubbot <= 1'b1;
                    dsp_oloadtop <= 1'b0;
                    dsp_oloadbot <= 1'b0;
                end
                
                MAC4: begin
                    // Final subtraction happening
                    dsp_ce <= 1'b0;  // Hold output
                end
                
                DONE: begin
                    // Capture final result
                    filtered_output <= dsp_o[31:16];
                    y2 <= y1;
                    y1 <= dsp_o;
                    x2 <= x1;
                    x1 <= x0;
                    output_valid <= 1'b1;
                    dsp_ce <= 1'b0;
                end
                
                default: begin
                    dsp_ce <= 1'b0;
                end
            endcase
        end
    end

endmodule