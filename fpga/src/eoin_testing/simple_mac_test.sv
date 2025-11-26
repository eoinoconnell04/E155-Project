`timescale 1ns/1ps

module simple_mac_test;
    reg clk;
    reg rst;
    reg [15:0] a, b, c, d;
    wire [31:0] o;
    wire co, accumco, signextout;
    
    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end
    
    // Reset generation
    initial begin
        rst = 1;
        #25 rst = 0;
    end
    
    // Simple instantiation of MAC16
    MAC16 #(
        .A_SIGNED("0b1"),
        .B_SIGNED("0b1"),
        .MODE_8x8("0b1"),
        .A_REG("0b0"),
        .B_REG("0b0"),
        .C_REG("0b0"),
        .D_REG("0b0")
    ) dut (
        .CLK(clk),
        .CE(~rst),  // Don't enable until after reset
        .A15(a[15]), .A14(a[14]), .A13(a[13]), .A12(a[12]),
        .A11(a[11]), .A10(a[10]), .A9(a[9]), .A8(a[8]),
        .A7(a[7]), .A6(a[6]), .A5(a[5]), .A4(a[4]),
        .A3(a[3]), .A2(a[2]), .A1(a[1]), .A0(a[0]),
        .B15(b[15]), .B14(b[14]), .B13(b[13]), .B12(b[12]),
        .B11(b[11]), .B10(b[10]), .B9(b[9]), .B8(b[8]),
        .B7(b[7]), .B6(b[6]), .B5(b[5]), .B4(b[4]),
        .B3(b[3]), .B2(b[2]), .B1(b[1]), .B0(b[0]),
        .C15(c[15]), .C14(c[14]), .C13(c[13]), .C12(c[12]),
        .C11(c[11]), .C10(c[10]), .C9(c[9]), .C8(c[8]),
        .C7(c[7]), .C6(c[6]), .C5(c[5]), .C4(c[4]),
        .C3(c[3]), .C2(c[2]), .C1(c[1]), .C0(c[0]),
        .D15(d[15]), .D14(d[14]), .D13(d[13]), .D12(d[12]),
        .D11(d[11]), .D10(d[10]), .D9(d[9]), .D8(d[8]),
        .D7(d[7]), .D6(d[6]), .D5(d[5]), .D4(d[4]),
        .D3(d[3]), .D2(d[2]), .D1(d[1]), .D0(d[0]),
        .AHOLD(1'b0), .BHOLD(1'b0), .CHOLD(1'b0), .DHOLD(1'b0),
        .IRSTTOP(rst), .IRSTBOT(rst),  // Use reset signals
        .ORSTTOP(rst), .ORSTBOT(rst),
        .OLOADTOP(1'b0), .OLOADBOT(1'b0),
        .ADDSUBTOP(1'b0), .ADDSUBBOT(1'b0),
        .OHOLDTOP(1'b0), .OHOLDBOT(1'b0),
        .CI(1'b0), .ACCUMCI(1'b0), .SIGNEXTIN(1'b0),
        .O31(o[31]), .O30(o[30]), .O29(o[29]), .O28(o[28]),
        .O27(o[27]), .O26(o[26]), .O25(o[25]), .O24(o[24]),
        .O23(o[23]), .O22(o[22]), .O21(o[21]), .O20(o[20]),
        .O19(o[19]), .O18(o[18]), .O17(o[17]), .O16(o[16]),
        .O15(o[15]), .O14(o[14]), .O13(o[13]), .O12(o[12]),
        .O11(o[11]), .O10(o[10]), .O9(o[9]), .O8(o[8]),
        .O7(o[7]), .O6(o[6]), .O5(o[5]), .O4(o[4]),
        .O3(o[3]), .O2(o[2]), .O1(o[1]), .O0(o[0]),
        .CO(co), .ACCUMCO(accumco), .SIGNEXTOUT(signextout)
    );
    
    initial begin
        $display("Simple MAC16 Test with Reset");
        a = 0; b = 0; c = 0; d = 0;
        
        // Wait for reset to complete
        wait(rst == 0);
        
        repeat(5) @(posedge clk);
        
        // Test: 5 * 3 + 10 = 25
        @(posedge clk);
        a = 16'd5;
        b = 16'd3;
        c = 16'd10;
        
        repeat(5) @(posedge clk);
        
        $display("Time=%0t: A=%0d, B=%0d, C=%0d => O=%0d (hex=0x%h)", 
                 $time, $signed(a), $signed(b), $signed(c), $signed(o), o);
        
        if (o === 32'bx) begin
            $display("ERROR: Output is still X!");
            $display("The precompiled MAC16_SIM library may have issues");
            $display("Check Lattice documentation for simulation models");
        end else if (o == 32'd25) begin
            $display("PASS!");
        end else begin
            $display("FAIL: Expected 25, got %0d", $signed(o));
        end
        
        $finish;
    end
    
endmodule