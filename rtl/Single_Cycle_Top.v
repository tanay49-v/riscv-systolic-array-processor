module Single_Cycle_Top(clk, rst, debug_out);

    input  wire        clk, rst;
    output wire [31:0] debug_out;

    wire [31:0] PC_Top, PC_Next, PCPlus4;
    wire [31:0] RD_Instr;
    wire [31:0] RD1_Top, RD2_Top;
    wire [31:0] Imm_Ext_Top;
    wire [31:0] SrcB;
    wire [31:0] ALUResult;
    wire [31:0] ReadData;
    wire [31:0] Result;

    wire        RegWrite, MemWrite, ALUSrc, Branch;
    wire [1:0]  ResultSrc, ImmSrc;
    wire [2:0]  ALUControl_Top;
    wire        Zero;

    wire        busy, done;
    wire        start_pulse;
    wire [31:0] mem_addr_sys;
    wire        mem_we_sys;
    wire [31:0] mem_wdata_sys;
    wire [31:0] mem_rdata_sys;
    wire [31:0] C_00, C_01, C_10, C_11;

    reg  [4:0]  rd_reg;
    reg  [31:0] base_A_reg;
    reg  [31:0] base_B_reg;

    // --------------------------------------------------
    // matmul detection
    // --------------------------------------------------
    reg [31:0] instr_d;
    always @(posedge clk) begin
        if (rst) instr_d <= 32'd0;
        else     instr_d <= RD_Instr;
    end

    wire is_matmul   = (RD_Instr[6:0]  == 7'b0110011) &&
                       (RD_Instr[31:25] == 7'b0000010);
    wire is_matmul_d = (instr_d[6:0]   == 7'b0110011) &&
                       (instr_d[31:25]  == 7'b0000010);

    assign start_pulse = is_matmul & ~is_matmul_d;

    always @(posedge clk) begin
        if (rst) begin
            rd_reg     <= 5'd0;
            base_A_reg <= 32'd0;
            base_B_reg <= 32'd0;
        end
        else if (start_pulse) begin
            rd_reg     <= RD_Instr[11:7];
            base_A_reg <= RD1_Top;
            base_B_reg <= RD2_Top;
        end
    end

    // --------------------------------------------------
    // PC - with branch and stall support
    // Priority: stall > branch > normal
    // Branch: PC_Next = PC + Imm_Ext when Branch & Zero
    // --------------------------------------------------
    wire        PCSrc;
    wire [31:0] PCBranch;

    assign PCBranch = PC_Top + Imm_Ext_Top;
    assign PCSrc    = Branch & Zero;

    assign PC_Next = busy    ? PC_Top   :
                     PCSrc   ? PCBranch :
                                PCPlus4;

    PC_Module PC(
        .clk(clk), .rst(rst),
        .PC(PC_Top), .PC_Next(PC_Next)
    );

    PC_Adder PC_Adder(.a(PC_Top), .b(32'd4), .c(PCPlus4));

    Instruction_Memory Instruction_Memory(
        .rst(rst), .A(PC_Top), .RD(RD_Instr)
    );

    Register_File Register_File(
        .clk(clk), .rst(rst),
        .WE3(RegWrite),
        .WD3(Result),
        .A1(RD_Instr[19:15]),
        .A2(RD_Instr[24:20]),
        .A3(done ? rd_reg : RD_Instr[11:7]),
        .RD1(RD1_Top),
        .RD2(RD2_Top)
    );

    Sign_Extend Sign_Extend(
        .In(RD_Instr), .ImmSrc(ImmSrc), .Imm_Ext(Imm_Ext_Top)
    );

    Mux Mux_Register_to_ALU(
        .a(RD2_Top), .b(Imm_Ext_Top), .s(ALUSrc), .c(SrcB)
    );

    ALU ALU(
        .A(RD1_Top), .B(SrcB),
        .Result(ALUResult),
        .ALUControl(ALUControl_Top),
        .OverFlow(), .Carry(),
        .Zero(Zero),
        .Negative()
    );

    Control_Unit_Top Control_Unit_Top(
        .Op(RD_Instr[6:0]),
        .funct3(RD_Instr[14:12]),
        .funct7(RD_Instr[31:25]),
        .done(done), .busy(busy),
        .RegWrite(RegWrite),
        .ImmSrc(ImmSrc),
        .ALUSrc(ALUSrc),
        .MemWrite(MemWrite),
        .ResultSrc(ResultSrc),
        .Branch(Branch),
        .ALUControl(ALUControl_Top)
    );

    Systolic_Top #(.N(2)) Systolic_Top(
        .clk        (clk), .rst(rst),
        .start      (start_pulse),
        .base_A     (base_A_reg),
        .base_B     (base_B_reg),
        .result_base(base_A_reg + 32'd32),
        .mem_addr   (mem_addr_sys),
        .mem_we     (mem_we_sys),
        .mem_wdata  (mem_wdata_sys),
        .mem_rdata  (mem_rdata_sys),
        .busy       (busy),
        .done       (done),
        .C_00(C_00), .C_01(C_01),
        .C_10(C_10), .C_11(C_11)
    );

    wire        dm_we;
    wire [31:0] dm_addr, dm_wdata;

    assign dm_we    = mem_we_sys ? 1'b1    : MemWrite;
    assign dm_addr  = (busy | mem_we_sys) ? mem_addr_sys : ALUResult;
    assign dm_wdata = mem_we_sys ? mem_wdata_sys : RD2_Top;

    Data_Memory Data_Memory(
        .clk(clk), .rst(rst),
        .WE(dm_we), .WD(dm_wdata),
        .A(dm_addr), .RD(ReadData)
    );

    assign mem_rdata_sys = ReadData;

    assign Result = (ResultSrc == 2'b00) ? ALUResult :
                    (ResultSrc == 2'b01) ? ReadData   :
                                           C_00;

    assign debug_out = Result;

endmodule