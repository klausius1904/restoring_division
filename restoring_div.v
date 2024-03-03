module add #(parameter w = 4)
(
input [w-1:0] x, y, //N-bit adder inputs
input cin, //carry input
output [w-1:0] z, //N-bit adder output
output cout //carry output
);
wire temp; //temp bit 0
// Cout = bit N+1, Sum = bits N:1, Cin+1 = carry into bit 1 if Cin=1
assign {cout,z,temp} = {1'b0, x, cin} + {1'b0, y, 1'b1};
endmodule

module sub #(parameter w = 4)
(
input [w-1:0] x, y, //N-bit adder inputs 
output [w-1:0] z //N-bit adder output
 //carry output
);

// Cout = bit N+1, Sum = bits N:1, Cin+1 = carry into bit 1 if Cin=1
assign z=x-y;
endmodule

module rgst1 #(parameter w = 8)
(
input [w-1:0] d, 
output reg [w-1:0] q,
input clk, 
input clr,
input in, 
input sh, 
input ld,
input assignq
);
always @(posedge clk) 
begin
if (clr == 1)
q <= 0;
else if (ld == 1)
q <= d; 
else if (sh == 1)
q <= {q[w-2:0], 1'bz};
else if (assignq==1)
q[0]<=in;  
else begin
q <= q;
end 
end
endmodule 

module rgst2 #(parameter w = 8)
(
input [w-1:0] d, 
output reg [w-1:0] q, 
input sh_in, 
input clk, 
input clr, 
input sh, 
input ld 
);
always @(posedge clk) 
begin
if (clr == 1)
q <= 0;
else if (ld == 1)
q <= d; 
else if (sh == 1)
q <= {q[w-2:0], sh_in}; 
else
q <= q; 
end
endmodule

module MUX_2_la_1 #(parameter w = 8)(
    input [w-1:0]a,
    input [w-1:0]b,
    input s,
    output [w-1:0]z
    );
 
  generate
	genvar i;
	for(i = 0; i < w; i = i + 1) begin: vect
		assign z[i] = (a[i] & ~s) | (b[i] & s);
	end
  endgenerate
 
 
endmodule

module div_control #(parameter w = 8) 
(
input clk, start, A8,
output operate, shift, subtract, add, assignq, stop, in
);
reg [6:0] st_nxt, state;
reg reg_q; 
parameter StartS=7'b0000001, ShiftS=7'b0000010, SubtractS=7'b0000100, TestS=7'b0001000, AddS=7'b0010000, AssignQS=7'b0100000, StopS=7'b1000000;
reg [w-1:0] count; 
wire N0; 
always @(posedge clk)
if (operate == 1) count = 0;
else if (shift == 1) count=  count + 1;

  
  
assign N0 = (count == w) ? 1 : 0;
 
always @(*)begin
case (state)
  StartS:st_nxt=ShiftS;
  ShiftS:st_nxt=SubtractS;
  SubtractS:st_nxt=TestS;
  TestS:if(A8){reg_q,st_nxt}={1'b0,AddS};
      else {reg_q,st_nxt}={1'b1,AssignQS};
  AddS:st_nxt=AssignQS;
  AssignQS:if(N0) st_nxt=StopS;
           else st_nxt=ShiftS;
  StopS: st_nxt=StopS;
endcase
end 
always @(posedge clk) begin
    if(start) state<=StartS;
    else state<=st_nxt;
    end


assign operate = state[0]; 
assign shift = state[1]; 
assign subtract = state[2]; 
assign add = state[4];
assign assignq = state[5];
assign in=reg_q;
assign stop = state[6];
endmodule

module divide_8_bit #(parameter w = 8)
(
input clk,start,
input [w-1:0] divizor,
input [w-1:0] dividend,
output [w-1:0] quotient,
output [w-1:0] remainder,
output stop
);
wire [w-1:0] RegA, RegM, Sum;
wire [w-1:0] RegQ;
wire [w-1:0] add_output, subtract_output, mux_output;
wire operate, shift, subtract, add, assignq, in; //controller wires
wire cout; 

assign quotient = RegQ;
assign remainder= RegA; 
div_control #(w) controller(.clk(clk), .start(start), .A8(RegA[w-1]), .operate(operate), .shift(shift), .add(add), .assignq(assignq), .stop(stop), .in(in), .subtract(subtract));
rgst1 #(w) M_Reg (.d(divizor), .q(RegM), .assignq(1'b0),.in(1'b0), .clk(clk), .clr(1'b0), .sh(1'b0), .ld(start));
rgst1 #(w) Q_Reg (.d(dividend), .q(RegQ), .assignq(assignq),.in(in), .clk(clk), .clr(1'b0), .sh(shift), .ld(start));
rgst2 #(w) A_Reg (.d(mux_output), .q(RegA), .sh_in(RegQ[w-1]), .clk(clk), .clr(operate), .sh(shift), .ld(add|subtract));

//adder_subtractor Add(.x(RegA), .y(RegM), .sel(~add|subtract), .z(Sum));
sub #(w) this_subtracter(.x(RegA), .y(RegM), .z(subtract_output));//a -m
add #(w) this_adder(.x(RegA), .y(RegM), .z(add_output), .cin(1'b0), .cout(cout)); //a+m

MUX_2_la_1 #(w)MUX(.a(add_output), .b(subtract_output), .z(mux_output), .s(subtract));




endmodule

module divide_tb;
  
  reg clk, start; 
  reg [7:0] divizor, dividend;
  wire [7:0] remainder, quotient;
  wire stop;
  
  divide_8_bit #(8) uut(.clk(clk), .start(start), .divizor(divizor), .dividend(dividend), .quotient(quotient), .remainder(remainder), .stop(stop));
  
  initial begin
  clk<=1'b0;
  divizor<=8'd15;
  dividend<=8'd123;
  start<=1'b1;
    #4;
  start<=1'b0;
  
  end
  
  
  initial begin
    
    repeat(100) #2 clk<=~clk;
    
  end
  initial begin
    
    $display("DIVIZOR\tDIVIDEND\tREMAINDER\t\QUOTIENT\tstart\tstop\t");
    $monitor("%d\t\t%d\t\t%b\t%b\t%b\t%b\t%b",divizor, dividend, remainder, quotient,start, stop,clk );
    
  end
  
endmodule
