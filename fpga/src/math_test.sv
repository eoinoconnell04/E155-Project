module math_test (input logic  [3:0] tap,
                  input logic  [3:0] data,
                  output logic  [3:0] out);

    // let tap = 1.125 in binary that would be 1.001.
    // shifting left by 3, *2^3 = 8, we get 1001 = 9

    // let data = 1011 = 11

    logic  [7:0] inter;
    assign inter = tap * data;
    assign out = inter >>> 3;


endmodule