module ALU_Decoder(
    input  [1:0] ALUOp,
    input  [2:0] funct3,
    input  [6:0] funct7,
    output reg [2:0] ALUControl
);

always @(*) begin
    case (ALUOp)
        2'b00: ALUControl = 3'b000; // ADD (LW, SW)
        2'b01: ALUControl = 3'b001; // SUB (BEQ)
        2'b10: begin
            case (funct3)
                3'b000: begin
                    if (funct7[5] == 1'b1)
                        ALUControl = 3'b001; // SUB
                    else
                        ALUControl = 3'b000; // ADD
                end
                3'b010: ALUControl = 3'b101; // SLT
                3'b110: ALUControl = 3'b011; // OR
                3'b111: ALUControl = 3'b010; // AND
                default: ALUControl = 3'b000;
            endcase
        end
        default: ALUControl = 3'b000;
    endcase
end

endmodule