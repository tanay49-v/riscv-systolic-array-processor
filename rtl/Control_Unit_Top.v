module Control_Unit_Top(
    Op, RegWrite, ImmSrc, ALUSrc, MemWrite, ResultSrc, Branch,
    funct3, funct7, ALUControl,
    done,   // from Systolic_Top - 1-cycle pulse when result ready
    busy    // from Systolic_Top - PC stall signal
);

    input  [6:0] Op, funct7;
    input  [2:0] funct3;
    input        done;
    input        busy;

    output       RegWrite, ALUSrc, MemWrite, Branch;
    output [1:0] ResultSrc;
    output [1:0] ImmSrc;
    output [2:0] ALUControl;

    wire [1:0] ALUOp;
    wire       RegWrite_d, MemWrite_d, ALUSrc_d;
    wire [1:0] ResultSrc_d;

    // --------------------------------------------------
    // Main Decoder
    // --------------------------------------------------
    Main_Decoder Main_Decoder(
        .Op       (Op),
        .RegWrite (RegWrite_d),
        .ImmSrc   (ImmSrc),
        .MemWrite (MemWrite_d),
        .ResultSrc(ResultSrc_d),
        .Branch   (Branch),
        .ALUSrc   (ALUSrc_d),
        .ALUOp    (ALUOp)
    );

    // --------------------------------------------------
    // ALU Decoder
    // --------------------------------------------------
    ALU_Decoder ALU_Decoder(
        .ALUOp     (ALUOp),
        .funct3    (funct3),
        .funct7    (funct7),
        .ALUControl(ALUControl)
    );

    // --------------------------------------------------
    // matmul instruction detection
    // Op=0110011, funct7=0000010 - distinct from scalar
    // acc which used funct7=0000001
    // --------------------------------------------------
    wire is_matmul;
    assign is_matmul = (Op == 7'b0110011) &&
                       (funct7 == 7'b0000010);

    // --------------------------------------------------
    // Final control signal overrides
    //
    // During normal execution: pass decoder outputs through
    // When matmul is in flight (busy=1): suppress writes
    //   so no normal instruction corrupts registers
    // When done=1: force write-back of systolic result
    // --------------------------------------------------

    // RegWrite: suppress during busy, force on done
    assign RegWrite  = done   ? 1'b1      :
                       busy   ? 1'b0      :
                       RegWrite_d;

    // MemWrite: never write memory during matmul
    assign MemWrite  = (busy || done) ? 1'b0 : MemWrite_d;

    // ALUSrc: not used during matmul
    assign ALUSrc    = (busy || done) ? 1'b0 : ALUSrc_d;

    // ResultSrc: select systolic result on done
    assign ResultSrc = done ? 2'b10 : ResultSrc_d;

endmodule