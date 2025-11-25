module working_mac16_test (
    input wire clk,
    output wire signed [31:0] result
);

    // Hardcoded signed test values
    wire signed [15:0] a_val = 16'shFFFB;  // -5 in 2's complement
    wire signed [15:0] b_val = 16'sh0003;  // 3
    wire signed [15:0] c_val = 16'sh000A;  // 10
    
    // Instantiate the MAC16 wrapper
    MAC16_wrapper mac_wrapper_inst (
        .clk(clk),
        .a_in(a_val),
        .b_in(b_val),
        .c_in(c_val),
        .result(result)
    );
    
    // Expected result: (-5) * 3 + 10 = -15 + 10 = -5 = 0xFFFFFFFB

endmodule