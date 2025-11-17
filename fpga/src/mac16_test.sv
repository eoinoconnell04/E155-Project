module mac16_test;

    // Signals
    reg CLK;
    reg CE;
    reg [15:0] A, B, C, D;
    reg AHOLD, BHOLD, CHOLD, DHOLD;
    reg IRSTTOP, IRSTBOT, ORSTTOP, ORSTBOT;
    reg OLOADTOP, OLOADBOT;
    reg ADDSUBTOP, ADDSUBBOT;
    reg OHOLDTOP, OHOLDBOT;
    reg CI, ACCUMCI, SIGNEXTIN;

    wire [31:0] O;
    wire CO, ACCUMCO, SIGNEXTOUT;

    // Instantiate MAC16
    MAC16 dut (
        .CLK(CLK),
        .CE(CE),
        .C15(C[15]), .C14(C[14]), .C13(C[13]), .C12(C[12]),
        .C11(C[11]), .C10(C[10]), .C9(C[9]), .C8(C[8]),
        .C7(C[7]), .C6(C[6]), .C5(C[5]), .C4(C[4]),
        .C3(C[3]), .C2(C[2]), .C1(C[1]), .C0(C[0]),
        .A15(A[15]), .A14(A[14]), .A13(A[13]), .A12(A[12]),
        .A11(A[11]), .A10(A[10]), .A9(A[9]), .A8(A[8]),
        .A7(A[7]), .A6(A[6]), .A5(A[5]), .A4(A[4]),
        .A3(A[3]), .A2(A[2]), .A1(A[1]), .A0(A[0]),
        .B15(B[15]), .B14(B[14]), .B13(B[13]), .B12(B[12]),
        .B11(B[11]), .B10(B[10]), .B9(B[9]), .B8(B[8]),
        .B7(B[7]), .B6(B[6]), .B5(B[5]), .B4(B[4]),
        .B3(B[3]), .B2(B[2]), .B1(B[1]), .B0(B[0]),
        .D15(D[15]), .D14(D[14]), .D13(D[13]), .D12(D[12]),
        .D11(D[11]), .D10(D[10]), .D9(D[9]), .D8(D[8]),
        .D7(D[7]), .D6(D[6]), .D5(D[5]), .D4(D[4]),
        .D3(D[3]), .D2(D[2]), .D1(D[1]), .D0(D[0]),
        .AHOLD(AHOLD), .BHOLD(BHOLD), .CHOLD(CHOLD), .DHOLD(DHOLD),
        .IRSTTOP(IRSTTOP), .IRSTBOT(IRSTBOT), .ORSTTOP(ORSTTOP), .ORSTBOT(ORSTBOT),
        .OLOADTOP(OLOADTOP), .OLOADBOT(OLOADBOT),
        .ADDSUBTOP(ADDSUBTOP), .ADDSUBBOT(ADDSUBBOT),
        .OHOLDTOP(OHOLDTOP), .OHOLDBOT(OHOLDBOT),
        .CI(CI), .ACCUMCI(ACCUMCI), .SIGNEXTIN(SIGNEXTIN),
        .O31(O[31]), .O30(O[30]), .O29(O[29]), .O28(O[28]),
        .O27(O[27]), .O26(O[26]), .O25(O[25]), .O24(O[24]),
        .O23(O[23]), .O22(O[22]), .O21(O[21]), .O20(O[20]),
        .O19(O[19]), .O18(O[18]), .O17(O[17]), .O16(O[16]),
        .O15(O[15]), .O14(O[14]), .O13(O[13]), .O12(O[12]),
        .O11(O[11]), .O10(O[10]), .O9(O[9]), .O8(O[8]),
        .O7(O[7]), .O6(O[6]), .O5(O[5]), .O4(O[4]),
        .O3(O[3]), .O2(O[2]), .O1(O[1]), .O0(O[0]),
        .CO(CO), .ACCUMCO(ACCUMCO), .SIGNEXTOUT(SIGNEXTOUT)
    );

endmodule
