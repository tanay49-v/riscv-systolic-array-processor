module Main_Decoder(
    Op,
    RegWrite, ImmSrc, ALUSrc, MemWrite,
    ResultSrc, Branch, ALUOp
);
    input  [6:0] Op;
    output       RegWrite, ALUSrc, MemWrite, Branch;
    output [1:0] ResultSrc;
    output [1:0] ImmSrc, ALUOp;

    // matmul uses Op=0110011 (R-type) with funct7=0000010
    // Detection here is by Op only - funct7 checked in Control_Unit_Top
    // For matmul: suppress normal RegWrite (done override handles write-back)
    // All other signals same as standard R-type

    assign RegWrite =
        (Op == 7'b0000011) ? 1'b1 :   // load
        (Op == 7'b0110011) ? 1'b1 :   // R-type (includes acc + matmul)
        (Op == 7'b0010011) ? 1'b1 :   // I-type (addi)
        1'b0;

    assign ALUSrc =
        (Op == 7'b0000011) ? 1'b1 :   // load
        (Op == 7'b0010011) ? 1'b1 :   // I-type
        (Op == 7'b0100011) ? 1'b1 :   // store
        1'b0;

    assign MemWrite  = (Op == 7'b0100011) ? 1'b1 : 1'b0;

    assign ResultSrc = (Op == 7'b0000011) ? 2'b01 :  // lw → memory
                       2'b00;                          // default → ALU

    assign Branch    = (Op == 7'b1100011) ? 1'b1 : 1'b0;

    assign ImmSrc =
        (Op == 7'b0100011) ? 2'b01 :  // S-type
        (Op == 7'b1100011) ? 2'b10 :  // B-type
        2'b00;                         // I-type / default

    assign ALUOp =
        (Op == 7'b0110011) ? 2'b10 :  // R-type
        (Op == 7'b1100011) ? 2'b01 :  // branch
        2'b00;                         // load/store

endmodule