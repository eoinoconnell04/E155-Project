// Combinatorial Multiply-Add Module - SIGNED version
// Multiply/add without register example, corresponding to the following parameter settings of
// MAC16:
//      A_REG = "0b0"
//      B_REG = "0b0"
//      TOP_8x8_MULT_REG = "0b0"
//      BOT_8x8_MULT_REG = "0b0"
//      PIPELINE_16x16_MULT_REG1 = "0b0"
//      PIPELINE_16x16_MULT_REG0 = "0b0"
//      TOPOUTPUT_SELECT = "0b00"
//      BOTOUTPUT_SELECT = "0b00"
//      TOPADDSUB_LOWERINPUT = "0b01"
//      BOTADDSUB_LOWERINPUT = "0b01"
module multaddsub_add_sign_7_6(a,b,c,din); 
    parameter A_WIDTH = 7; 
    parameter B_WIDTH = 6;
 
    input signed [(A_WIDTH - 1):0] a; 
    input signed [(B_WIDTH - 1):0] b;
    input signed [(A_WIDTH + B_WIDTH - 1):0] din; 
    output signed [(A_WIDTH + B_WIDTH - 1):0] c;
 
    assign c = a * b + din; 
endmodule