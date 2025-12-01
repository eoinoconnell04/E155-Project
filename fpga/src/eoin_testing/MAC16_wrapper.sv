module MAC16_wrapper (
    input wire clk,
    input wire signed [15:0] a_in,  // Signed 16-bit input A
    input wire signed [15:0] b_in,  // Signed 16-bit input B
    input wire signed [15:0] c_in,  // Signed 16-bit input C
    output wire signed [31:0] result  // Signed 32-bit output
);

    // Register inputs
    reg [15:0] a_reg, b_reg, c_reg;
    reg ce_reg;
    
    // Tie off unused D input
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
    wire addsubtop = 1'b0;  // 0 = add (for MAC: A*B + C)
    wire addsubbot = 1'b0;
    wire oholdtop = 1'b0;
    wire oholdbot = 1'b0;
    wire ci = 1'b0;
    wire accumci = 1'b0;
    wire signextin = 1'b0;
    
    // Output wires
    wire [31:0] o_wire;
    wire co_internal, accumco_internal, signextout_internal;
    
    // Register inputs on clock edge
    always @(posedge clk) begin
        ce_reg <= 1'b1;
        a_reg <= a_in;
        b_reg <= b_in;
        c_reg <= c_in;
    end
    
    MAC16 #(
        .NEG_TRIGGER("0b0"),
        .A_REG("0b0"),      // DISABLE - we're registering externally
        .B_REG("0b0"),      // DISABLE - we're registering externally
        .C_REG("0b0"),      // DISABLE - we're registering externally
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
        .MODE_8x8("0b0"),   // Set to 1 for power save (no pipeline regs used)
        .A_SIGNED("0b1"),   // SIGNED mode for A
        .B_SIGNED("0b1")    // SIGNED mode for B
    ) mac_inst (
        .CLK(clk), .CE(ce_reg),
        // C input bits
        .C15(c_reg[15]), .C14(c_reg[14]), .C13(c_reg[13]), .C12(c_reg[12]),
        .C11(c_reg[11]), .C10(c_reg[10]), .C9(c_reg[9]), .C8(c_reg[8]),
        .C7(c_reg[7]), .C6(c_reg[6]), .C5(c_reg[5]), .C4(c_reg[4]),
        .C3(c_reg[3]), .C2(c_reg[2]), .C1(c_reg[1]), .C0(c_reg[0]),
        // A input bits
        .A15(a_reg[15]), .A14(a_reg[14]), .A13(a_reg[13]), .A12(a_reg[12]),
        .A11(a_reg[11]), .A10(a_reg[10]), .A9(a_reg[9]), .A8(a_reg[8]),
        .A7(a_reg[7]), .A6(a_reg[6]), .A5(a_reg[5]), .A4(a_reg[4]),
        .A3(a_reg[3]), .A2(a_reg[2]), .A1(a_reg[1]), .A0(a_reg[0]),
        // B input bits
        .B15(b_reg[15]), .B14(b_reg[14]), .B13(b_reg[13]), .B12(b_reg[12]),
        .B11(b_reg[11]), .B10(b_reg[10]), .B9(b_reg[9]), .B8(b_reg[8]),
        .B7(b_reg[7]), .B6(b_reg[6]), .B5(b_reg[5]), .B4(b_reg[4]),
        .B3(b_reg[3]), .B2(b_reg[2]), .B1(b_reg[1]), .B0(b_reg[0]),
        // D input bits (tied off)
        .D15(d_tied[15]), .D14(d_tied[14]), .D13(d_tied[13]), .D12(d_tied[12]),
        .D11(d_tied[11]), .D10(d_tied[10]), .D9(d_tied[9]), .D8(d_tied[8]),
        .D7(d_tied[7]), .D6(d_tied[6]), .D5(d_tied[5]), .D4(d_tied[4]),
        .D3(d_tied[3]), .D2(d_tied[2]), .D1(d_tied[1]), .D0(d_tied[0]),
        // Control signals
        .AHOLD(ahold), .BHOLD(bhold), .CHOLD(chold), .DHOLD(dhold),
        .IRSTTOP(irsttop), .IRSTBOT(irstbot),
        .ORSTTOP(orsttop), .ORSTBOT(orstbot),
        .OLOADTOP(oloadtop), .OLOADBOT(oloadbot),
        .ADDSUBTOP(addsubtop), .ADDSUBBOT(addsubbot),
        .OHOLDTOP(oholdtop), .OHOLDBOT(oholdbot),
        .CI(ci), .ACCUMCI(accumci), .SIGNEXTIN(signextin),
        // Output bits
        .O31(o_wire[31]), .O30(o_wire[30]), .O29(o_wire[29]), .O28(o_wire[28]),
        .O27(o_wire[27]), .O26(o_wire[26]), .O25(o_wire[25]), .O24(o_wire[24]),
        .O23(o_wire[23]), .O22(o_wire[22]), .O21(o_wire[21]), .O20(o_wire[20]),
        .O19(o_wire[19]), .O18(o_wire[18]), .O17(o_wire[17]), .O16(o_wire[16]),
        .O15(o_wire[15]), .O14(o_wire[14]), .O13(o_wire[13]), .O12(o_wire[12]),
        .O11(o_wire[11]), .O10(o_wire[10]), .O9(o_wire[9]), .O8(o_wire[8]),
        .O7(o_wire[7]), .O6(o_wire[6]), .O5(o_wire[5]), .O4(o_wire[4]),
        .O3(o_wire[3]), .O2(o_wire[2]), .O1(o_wire[1]), .O0(o_wire[0]),
        // Carry/sign outputs (kept internal)
        .CO(co_internal), .ACCUMCO(accumco_internal), .SIGNEXTOUT(signextout_internal)
    );
    
    // Full 32-bit signed output (A * B + C)
    assign result = o_wire;

endmodule