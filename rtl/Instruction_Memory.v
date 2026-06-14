module Instruction_Memory(rst,A,RD);

  input rst;
  input [31:0] A;
  output [31:0] RD;

  reg [31:0] mem [1023:0];

  assign RD = mem[A[11:2]];

  integer i;

initial begin
    // Initialize entire memory with NOP (ADD x0, x0, x0)
    for (i = 0; i < 1024; i = i + 1)
        mem[i] = 32'h00000033;

    // Load your program on top
    $readmemh("memfile.hex", mem);

    // Debug print
    $display("Memory[0] = %h", mem[0]);
end

endmodule