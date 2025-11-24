/*
Author: Eoin O'Connell
Email: eoconnell@hmc.edu
Date: Nov. 13, 2025
Module Function: Time-multiplexed biquad IIR filter using explicit MAC16
              Guarantees 1 DSP slice usage per instance
*/

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
    
    // Instantiate MAC16 for guaranteed DSP usage (corrected for Lattice iCE40)
    MAC16 #(
        .NEG_TRIGGER(1'b0),
        .C_REG(1'b0),
        .A_REG(1'b0),
        .B_REG(1'b0),
        .D_REG(1'b0),
        .TOP_8x8_MULT_REG(1'b0),
        .BOT_8x8_MULT_REG(1'b0),
        .PIPELINE_16x16_MULT_REG1(1'b0),
        .PIPELINE_16x16_MULT_REG2(1'b0),
        .TOPOUTPUT_SELECT(2'b11),
        .TOPADDSUB_LOWERINPUT(2'b00),
        .TOPADDSUB_UPPERINPUT(1'b0),
        .TOPADDSUB_CARRYSELECT(2'b00),
        .BOTOUTPUT_SELECT(2'b11),
        .BOTADDSUB_LOWERINPUT(2'b00),
        .BOTADDSUB_UPPERINPUT(1'b0),
        .BOTADDSUB_CARRYSELECT(2'b00),
        .MODE_8x8(1'b0),
        .A_SIGNED(1'b1),
        .B_SIGNED(1'b1)
    ) mac_inst (
        .CLK(clk),
        .CE(dsp_ce),
        .A0(dsp_a[0]),
        .A1(dsp_a[1]),
        .A2(dsp_a[2]),
        .A3(dsp_a[3]),
        .A4(dsp_a[4]),
        .A5(dsp_a[5]),
        .A6(dsp_a[6]),
        .A7(dsp_a[7]),
        .A8(dsp_a[8]),
        .A9(dsp_a[9]),
        .A10(dsp_a[10]),
        .A11(dsp_a[11]),
        .A12(dsp_a[12]),
        .A13(dsp_a[13]),
        .A14(dsp_a[14]),
        .A15(dsp_a[15]),
        .B0(dsp_b[0]),
        .B1(dsp_b[1]),
        .B2(dsp_b[2]),
        .B3(dsp_b[3]),
        .B4(dsp_b[4]),
        .B5(dsp_b[5]),
        .B6(dsp_b[6]),
        .B7(dsp_b[7]),
        .B8(dsp_b[8]),
        .B9(dsp_b[9]),
        .B10(dsp_b[10]),
        .B11(dsp_b[11]),
        .B12(dsp_b[12]),
        .B13(dsp_b[13]),
        .B14(dsp_b[14]),
        .B15(dsp_b[15]),
        .D0(1'b0),
        .D1(1'b0),
        .D2(1'b0),
        .D3(1'b0),
        .D4(1'b0),
        .D5(1'b0),
        .D6(1'b0),
        .D7(1'b0),
        .D8(1'b0),
        .D9(1'b0),
        .D10(1'b0),
        .D11(1'b0),
        .D12(1'b0),
        .D13(1'b0),
        .D14(1'b0),
        .D15(1'b0),
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
        .O0(dsp_o[0]),
        .O1(dsp_o[1]),
        .O2(dsp_o[2]),
        .O3(dsp_o[3]),
        .O4(dsp_o[4]),
        .O5(dsp_o[5]),
        .O6(dsp_o[6]),
        .O7(dsp_o[7]),
        .O8(dsp_o[8]),
        .O9(dsp_o[9]),
        .O10(dsp_o[10]),
        .O11(dsp_o[11]),
        .O12(dsp_o[12]),
        .O13(dsp_o[13]),
        .O14(dsp_o[14]),
        .O15(dsp_o[15]),
        .O16(dsp_o[16]),
        .O17(dsp_o[17]),
        .O18(dsp_o[18]),
        .O19(dsp_o[19]),
        .O20(dsp_o[20]),
        .O21(dsp_o[21]),
        .O22(dsp_o[22]),
        .O23(dsp_o[23]),
        .O24(dsp_o[24]),
        .O25(dsp_o[25]),
        .O26(dsp_o[26]),
        .O27(dsp_o[27]),
        .O28(dsp_o[28]),
        .O29(dsp_o[29]),
        .O30(dsp_o[30]),
        .O31(dsp_o[31]),
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