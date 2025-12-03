module spi_reader(input logic [47:0] data, 
			   output logic [11:0] p1,
			   output logic [11:0] p2, 
			   output logic [11:0] p3);
			   
			   
assign p1 = data[47:36]; 
assign p2 = data[35:24]; 
assign p3 = data[23:12]; 

endmodule