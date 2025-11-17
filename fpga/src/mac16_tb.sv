`timescale 1ns/1ps

module mac16_tb;

    // Signals
    reg CLK = 0;
    reg CE = 1;
    reg [15:0] A, B, C, D;
    reg AHOLD = 0, BHOLD = 0, CHOLD = 0, DHOLD = 0;
    reg IRSTTOP = 0, IRSTBOT = 0, ORSTTOP = 0, ORSTBOT = 0;
    reg OLOADTOP = 0, OLOADBOT = 0;
    reg ADDSUBTOP = 0, ADDSUBBOT = 0;
    reg OHOLDTOP = 0, OHOLDBOT = 0;
    reg CI = 0, ACCUMCI = 0, SIGNEXTIN = 0;

    wire [31:0] O;
    wire CO, ACCUMCO, SIGNEXTOUT;

    // Instantiate the mac16_test module
    mac16_test dut (
        .CLK(CLK),
        .CE(CE),
        .A(A), .B(B), .C(C), .D(D),
        .AHOLD(AHOLD), .BHOLD(BHOLD), .CHOLD(CHOLD), .DHOLD(DHOLD),
        .IRSTTOP(IRSTTOP), .IRSTBOT(IRSTBOT), .ORSTTOP(ORSTTOP), .ORSTBOT(ORSTBOT),
        .OLOADTOP(OLOADTOP), .OLOADBOT(OLOADBOT),
        .ADDSUBTOP(ADDSUBTOP), .ADDSUBBOT(ADDSUBBOT),
        .OHOLDTOP(OHOLDTOP), .OHOLDBOT(OHOLDBOT),
        .CI(CI), .ACCUMCI(ACCUMCI), .SIGNEXTIN(SIGNEXTIN),
        .O(O),
        .CO(CO), .ACCUMCO(ACCUMCO), .SIGNEXTOUT(SIGNEXTOUT)
    );

    // Clock generation
    always #5 CLK = ~CLK;

    initial begin
        // Test vector 1
        A = 16'd1234;
        B = 16'd5678;
        C = 16'd0;
        D = 16'd0;
        #20; // wait 2 clock cycles
        $display("A=%d, B=%d, O=%d", A, B, O);

        // Test vector 2
        A = 16'd1000;
        B = 16'd2000;
        #20;
        $display("A=%d, B=%d, O=%d", A, B, O);

        // Test vector 3
        A = 16'd65535; // max 16-bit unsigned
        B = 16'd2;
        #20;
        $display("A=%d, B=%d, O=%d", A, B, O);

        $finish;
    end

endmodule
