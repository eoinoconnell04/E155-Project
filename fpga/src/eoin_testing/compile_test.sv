module multaddsub_add_sign_7_6(a,b,c,din); 
    parameter A_WIDTH = 3; 
    parameter B_WIDTH = 3;
 
    input signed [(A_WIDTH - 1):0] a; 
    input signed [(B_WIDTH - 1):0] b;
    input signed [(A_WIDTH + B_WIDTH - 1):0] din; 
    output signed [(A_WIDTH + B_WIDTH - 1):0] c;
 
    assign c = a * b + din; 
endmodule