module math_test (input logic signed [3:0] tap,
                  input logic signed [3:0] data,
                  output logic signed [3:0] out);

    // unsigned
    // let tap = 1.125 in binary that would be 1.001.
    // shifting left by 3, *2^3 = 8, we get 1001 = 9

    // let data = 1011 = 11

    // 11 * 9 = 99 = 01100011

    // shifting right by 3 we get 1100 = 12


    // signed
    // tap = 1.5 * 8 = 12, we get 

    logic signed [7:0] inter;
    assign inter = tap * data;
    assign out = inter >>> 3;


endmodule