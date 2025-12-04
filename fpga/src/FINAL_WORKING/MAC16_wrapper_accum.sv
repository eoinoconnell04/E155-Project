/*
Authors: Eoin O'Connell (eoconnell@hmc.edu)
         Drake Gonzales (drgonzales@g.hmc.edu)
Date: Dec. 4, 2025
Module Function: Wrapper for Lattice MAC16 DSP primitive
- 16x16 signed multiply with accumulation
- Input registers enabled on A and B ports
- Q2.14 fixed-point arithmetic support
*/

module MAC16_wrapper_accum (
    input  logic               clk,
    input  logic               reset,
    input  logic               mac_rst,
    input  logic               ce,
    input  logic signed [15:0] a_in,
    input  logic signed [15:0] b_in,
    output logic signed [31:0] result
);

    // Unused inputs (tied to zero)
    logic [15:0] c_tied = 16'h0000;
    logic [15:0] d_tied = 16'h0000;
    
    // Reset signals (active-high for MAC16 primitive)
    logic irsttop, irstbot, orsttop, orstbot;
    assign irsttop = !mac_rst;
    assign irstbot = !mac_rst;
    assign orsttop = !mac_rst;
    assign orstbot = !mac_rst;

    // Control signals (all disabled)
    logic ahold, bhold, chold, dhold;
    logic oloadtop, oloadbot;
    logic addsubtop, addsubbot;
    logic oholdtop, oholdbot;
    logic ci, accumci, signextin;

    assign ahold      = 1'b0;
    assign bhold      = 1'b0;
    assign chold      = 1'b0;
    assign dhold      = 1'b0;
    assign oholdtop   = 1'b0;
    assign oholdbot   = 1'b0;
    assign addsubtop  = 1'b0;
    assign addsubbot  = 1'b0;
    assign oloadtop   = 1'b0;
    assign oloadbot   = 1'b0;
    assign signextin  = 1'b0;
    assign ci         = 1'b0;
    assign accumci    = 1'b0;

    // Internal signals
    logic [31:0] o_wire;
    logic        co_internal, accumco_internal, signextout_internal;
    
    // MAC16 Configuration:
    // - 16x16 signed multiply with accumulation
    // - Input registers enabled on A and B
    // - Accumulator mode for continuous sum of products
    MAC16 #(
        .A_REG("0b1"),
        .B_REG("0b1"),
        .C_REG("0b0"),
        .D_REG("0b0"),
        .MODE_8x8("0b0"),
        .A_SIGNED("0b1"),
        .B_SIGNED("0b1"),
        .TOPADDSUB_LOWERINPUT("0b10"),
        .BOTADDSUB_LOWERINPUT("0b10"),
        .TOPADDSUB_UPPERINPUT("0b0"),
        .BOTADDSUB_UPPERINPUT("0b0"),
        .TOPOUTPUT_SELECT("0b00"),
        .BOTOUTPUT_SELECT("0b00"),
        .TOPADDSUB_CARRYSELECT("0b10"),
        .BOTADDSUB_CARRYSELECT("0b00")
    ) mac_inst (
        .CLK(clk), 
        .CE(ce),
        
        .A15(a_in[15]), .A14(a_in[14]), .A13(a_in[13]), .A12(a_in[12]),
        .A11(a_in[11]), .A10(a_in[10]), .A9(a_in[9]),   .A8(a_in[8]),
        .A7(a_in[7]),   .A6(a_in[6]),   .A5(a_in[5]),   .A4(a_in[4]),
        .A3(a_in[3]),   .A2(a_in[2]),   .A1(a_in[1]),   .A0(a_in[0]),
        
        .B15(b_in[15]), .B14(b_in[14]), .B13(b_in[13]), .B12(b_in[12]),
        .B11(b_in[11]), .B10(b_in[10]), .B9(b_in[9]),   .B8(b_in[8]),
        .B7(b_in[7]),   .B6(b_in[6]),   .B5(b_in[5]),   .B4(b_in[4]),
        .B3(b_in[3]),   .B2(b_in[2]),   .B1(b_in[1]),   .B0(b_in[0]),
        
        .C15(c_tied[15]), .C14(c_tied[14]), .C13(c_tied[13]), .C12(c_tied[12]),
        .C11(c_tied[11]), .C10(c_tied[10]), .C9(c_tied[9]),   .C8(c_tied[8]),
        .C7(c_tied[7]),   .C6(c_tied[6]),   .C5(c_tied[5]),   .C4(c_tied[4]),
        .C3(c_tied[3]),   .C2(c_tied[2]),   .C1(c_tied[1]),   .C0(c_tied[0]),
        
        .D15(d_tied[15]), .D14(d_tied[14]), .D13(d_tied[13]), .D12(d_tied[12]),
        .D11(d_tied[11]), .D10(d_tied[10]), .D9(d_tied[9]),   .D8(d_tied[8]),
        .D7(d_tied[7]),   .D6(d_tied[6]),   .D5(d_tied[5]),   .D4(d_tied[4]),
        .D3(d_tied[3]),   .D2(d_tied[2]),   .D1(d_tied[1]),   .D0(d_tied[0]),
        
        .AHOLD(ahold), .BHOLD(bhold), .CHOLD(chold), .DHOLD(dhold),
        .IRSTTOP(irsttop), .IRSTBOT(irstbot),
        .ORSTTOP(orsttop), .ORSTBOT(orstbot),
        .OLOADTOP(oloadtop), .OLOADBOT(oloadbot),
        .ADDSUBTOP(addsubtop), .ADDSUBBOT(addsubbot),
        .OHOLDTOP(oholdtop), .OHOLDBOT(oholdbot),
        .CI(ci), .ACCUMCI(accumci), .SIGNEXTIN(signextin),
        
        .O31(o_wire[31]), .O30(o_wire[30]), .O29(o_wire[29]), .O28(o_wire[28]),
        .O27(o_wire[27]), .O26(o_wire[26]), .O25(o_wire[25]), .O24(o_wire[24]),
        .O23(o_wire[23]), .O22(o_wire[22]), .O21(o_wire[21]), .O20(o_wire[20]),
        .O19(o_wire[19]), .O18(o_wire[18]), .O17(o_wire[17]), .O16(o_wire[16]),
        .O15(o_wire[15]), .O14(o_wire[14]), .O13(o_wire[13]), .O12(o_wire[12]),
        .O11(o_wire[11]), .O10(o_wire[10]), .O9(o_wire[9]),   .O8(o_wire[8]),
        .O7(o_wire[7]),   .O6(o_wire[6]),   .O5(o_wire[5]),   .O4(o_wire[4]),
        .O3(o_wire[3]),   .O2(o_wire[2]),   .O1(o_wire[1]),   .O0(o_wire[0]),
        
        .CO(co_internal), 
        .ACCUMCO(accumco_internal), 
        .SIGNEXTOUT(signextout_internal)
    );
    
    assign result = o_wire;

endmodule