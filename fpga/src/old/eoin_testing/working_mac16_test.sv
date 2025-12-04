module working_mac16_test (
    input wire clk,
    output wire [15:0] result
);

    // Hardcoded SIGNED test values (2's complement)
    reg [15:0] a_reg = 16'hFFFB;  // A = -5 in 2's complement
    reg [15:0] b_reg = 16'h0003;  // B = 3
    reg ce_reg = 1'b1;
    
    // Tie off unused inputs
    wire [15:0] c_tied = 16'h0000;
    wire [15:0] d_tied = 16'h0000;
    
    // Control signal defaults
    wire ahold = 1'b0;
    wire bhold = 1'b0;
    wire chold = 1'b0;
    wire dhold = 1'b0;
    wire irsttop = 1'b0;
    wire irstbot = 1'b0;
    wire orsttop = 1'b0;
    wire orstbot = 1'b0;
    wire oloadtop = 1'b0;
    wire oloadbot = 1'b0;
    wire addsubtop = 1'b0;
    wire addsubbot = 1'b0;
    wire oholdtop = 1'b0;
    wire oholdbot = 1'b0;
    wire ci = 1'b0;
    wire accumci = 1'b0;
    wire signextin = 1'b0;
    
    // Output wires
    wire [31:0] o_wire;
    wire co_internal, accumco_internal, signextout_internal;
    
    MAC16 #(
        .NEG_TRIGGER("0b0"),
        .A_REG("0b0"),
        .B_REG("0b0"),
        .C_REG("0b0"),
        .D_REG("0b0"),
        .TOP_8x8_MULT_REG("0b0"),
        .BOT_8x8_MULT_REG("0b0"),
        .PIPELINE_16x16_MULT_REG1("0b0"),
        .PIPELINE_16x16_MULT_REG2("0b0"),
        .TOPOUTPUT_SELECT("0b00"),
        .TOPADDSUB_LOWERINPUT("0b00"),
        .TOPADDSUB_UPPERINPUT("0b0"),
        .TOPADDSUB_CARRYSELECT("0b00"),
        .BOTOUTPUT_SELECT("0b00"),
        .BOTADDSUB_LOWERINPUT("0b00"),
        .BOTADDSUB_UPPERINPUT("0b0"),
        .BOTADDSUB_CARRYSELECT("0b00"),
        .MODE_8x8("0b0"),
        .A_SIGNED("0b1"),  // ENABLE signed mode for A
        .B_SIGNED("0b1")   // ENABLE signed mode for B
    ) mac_inst (
        .CLK(clk), .CE(ce_reg),
        .C15(c_tied[15]), .C14(c_tied[14]), .C13(c_tied[13]), .C12(c_tied[12]),
        .C11(c_tied[11]), .C10(c_tied[10]), .C9(c_tied[9]), .C8(c_tied[8]),
        .C7(c_tied[7]), .C6(c_tied[6]), .C5(c_tied[5]), .C4(c_tied[4]),
        .C3(c_tied[3]), .C2(c_tied[2]), .C1(c_tied[1]), .C0(c_tied[0]),
        .A15(a_reg[15]), .A14(a_reg[14]), .A13(a_reg[13]), .A12(a_reg[12]),
        .A11(a_reg[11]), .A10(a_reg[10]), .A9(a_reg[9]), .A8(a_reg[8]),
        .A7(a_reg[7]), .A6(a_reg[6]), .A5(a_reg[5]), .A4(a_reg[4]),
        .A3(a_reg[3]), .A2(a_reg[2]), .A1(a_reg[1]), .A0(a_reg[0]),
        .B15(b_reg[15]), .B14(b_reg[14]), .B13(b_reg[13]), .B12(b_reg[12]),
        .B11(b_reg[11]), .B10(b_reg[10]), .B9(b_reg[9]), .B8(b_reg[8]),
        .B7(b_reg[7]), .B6(b_reg[6]), .B5(b_reg[5]), .B4(b_reg[4]),
        .B3(b_reg[3]), .B2(b_reg[2]), .B1(b_reg[1]), .B0(b_reg[0]),
        .D15(d_tied[15]), .D14(d_tied[14]), .D13(d_tied[13]), .D12(d_tied[12]),
        .D11(d_tied[11]), .D10(d_tied[10]), .D9(d_tied[9]), .D8(d_tied[8]),
        .D7(d_tied[7]), .D6(d_tied[6]), .D5(d_tied[5]), .D4(d_tied[4]),
        .D3(d_tied[3]), .D2(d_tied[2]), .D1(d_tied[1]), .D0(d_tied[0]),
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
        .O11(o_wire[11]), .O10(o_wire[10]), .O9(o_wire[9]), .O8(o_wire[8]),
        .O7(o_wire[7]), .O6(o_wire[6]), .O5(o_wire[5]), .O4(o_wire[4]),
        .O3(o_wire[3]), .O2(o_wire[2]), .O1(o_wire[1]), .O0(o_wire[0]),
        .CO(co_internal), .ACCUMCO(accumco_internal), .SIGNEXTOUT(signextout_internal)
    );
    
    // Output lower 16 bits: (-5) * 3 = -15 = 0xFFF1 in 16-bit 2's complement
    assign result = o_wire[15:0];

endmodule