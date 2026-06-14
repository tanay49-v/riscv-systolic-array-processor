`timescale 1ns/1ps
module Single_Cycle_Top_Tb();

    reg clk, rst;
    wire [31:0] debug_out;

    Single_Cycle_Top uut(
        .clk(clk),
        .rst(rst),
        .debug_out(debug_out)
    );

    // --------------------------------------------------
    // Waveform dump
    // --------------------------------------------------
    initial begin
        $dumpfile("Single_Cycle.vcd");
        $dumpvars(0, Single_Cycle_Top_Tb);
    end

    // --------------------------------------------------
    // Clock - 10ns period
    // --------------------------------------------------
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // --------------------------------------------------
    // Reset
    // --------------------------------------------------
    initial begin
        rst = 1;
        #50;
        rst = 0;
    end

    // --------------------------------------------------
    // Pre-load Data_Memory after reset releases
    // Matrix A = [[1,2],[3,4]] at base_A = 0
    // Matrix B = [[5,6],[7,8]] at base_B = 16
    // --------------------------------------------------
    initial begin
        #50;
        @(posedge clk); #1;
        uut.Data_Memory.mem[0]  = 32'd1;
        uut.Data_Memory.mem[1]  = 32'd2;
        uut.Data_Memory.mem[2]  = 32'd3;
        uut.Data_Memory.mem[3]  = 32'd4;
        uut.Data_Memory.mem[4]  = 32'd5;
        uut.Data_Memory.mem[5]  = 32'd6;
        uut.Data_Memory.mem[6]  = 32'd7;
        uut.Data_Memory.mem[7]  = 32'd8;
    end

    // --------------------------------------------------
    // Convenience wires - tap key internal signals
    // These appear as named signals in the waveform
    // --------------------------------------------------

    // --- Program Counter ---
    wire [31:0] PC          = uut.PC_Top;
    wire [31:0] PC_Next     = uut.PC_Next;
    wire [31:0] Instr       = uut.RD_Instr;

    // --- Register File reads ---
    wire [31:0] RF_RD1      = uut.RD1_Top;
    wire [31:0] RF_RD2      = uut.RD2_Top;

    // --- ALU ---
    wire [31:0] ALU_Result  = uut.ALUResult;
    wire [2:0]  ALU_Ctrl    = uut.ALUControl_Top;

    // --- Control signals ---
    wire        RegWrite    = uut.RegWrite;
    wire        MemWrite    = uut.MemWrite;
    wire        ALUSrc      = uut.ALUSrc;
    wire [1:0]  ResultSrc   = uut.ResultSrc;

    // --- Data Memory ---
    wire [31:0] DM_Addr     = uut.dm_addr;
    wire        DM_WE       = uut.dm_we;
    wire [31:0] DM_RData    = uut.ReadData;

    // --- Systolic accelerator ---
    wire        Busy        = uut.busy;
    wire        Done        = uut.done;
    wire        Start_Pulse = uut.start_pulse;
    wire [31:0] Base_A      = uut.base_A_reg;
    wire [31:0] Base_B      = uut.base_B_reg;
    wire [31:0] C_00        = uut.C_00;
    wire [31:0] C_01        = uut.C_01;
    wire [31:0] C_10        = uut.C_10;
    wire [31:0] C_11        = uut.C_11;

    // --- Key result registers ---
    wire [31:0] x1          = uut.Register_File.Register[1];
    wire [31:0] x2          = uut.Register_File.Register[2];
    wire [31:0] x3          = uut.Register_File.Register[3];
    wire [31:0] x4          = uut.Register_File.Register[4];
    wire [31:0] x5          = uut.Register_File.Register[5];
    wire [31:0] x6          = uut.Register_File.Register[6];
    wire [31:0] x7          = uut.Register_File.Register[7];
    wire [31:0] x8          = uut.Register_File.Register[8];
    wire [31:0] x9          = uut.Register_File.Register[9];
    wire [31:0] x10         = uut.Register_File.Register[10];
    wire [31:0] x17         = uut.Register_File.Register[17];
    wire [31:0] x18         = uut.Register_File.Register[18];
    wire [31:0] x19         = uut.Register_File.Register[19];
    wire [31:0] x20         = uut.Register_File.Register[20];
    wire [31:0] x21         = uut.Register_File.Register[21];

    // --------------------------------------------------
    // Tcl console result checking
    // --------------------------------------------------
    integer errors = 0;

    task check;
        input [31:0] got, exp;
        input [127:0] name;
        begin
            if (got !== exp) begin
                $display("FAIL  %-20s got=%0d  expected=%0d",
                    name, got, exp);
                errors = errors + 1;
            end else
                $display("PASS  %-20s = %0d", name, got);
        end
    endtask

    initial begin
        // Program has 31 instructions
        // Stall = ~13 cycles for matmul
        // Total: 50ns reset + 31*10 + 13*10 = ~490ns
        // Generous margin: 1200ns
        #1200;

        $display("");
        $display("============================================");
        $display("  RISC-V + Systolic Array - Full Test");
        $display("============================================");

        // ---- addi ----
        $display("");
        $display("--- I-type: addi ---");
        check(uut.Register_File.Register[1],  32'd10,  "x1  = addi(x0,10)");
        check(uut.Register_File.Register[2],  32'd3,   "x2  = addi(x0,3)");

        // ---- R-type ----
        $display("");
        $display("--- R-type: add, sub, and, or, slt ---");
        check(uut.Register_File.Register[3],  32'd13,  "x3  = add  x1+x2");
        check(uut.Register_File.Register[4],  32'd7,   "x4  = sub  x1-x2");
        check(uut.Register_File.Register[5],  32'd2,   "x5  = and  x1&x2");
        check(uut.Register_File.Register[6],  32'd11,  "x6  = or   x1|x2");
        check(uut.Register_File.Register[7],  32'd0,   "x7  = slt  10<3=0");
        check(uut.Register_File.Register[8],  32'd1,   "x8  = slt  3<10=1");

        // ---- sw/lw ----
        $display("");
        $display("--- S-type/I-type: sw + lw ---");
        check(uut.Register_File.Register[9],  32'd99,  "x9  = lw(mem[100])");

        // ---- beq ----
        $display("");
        $display("--- B-type: beq (branch taken) ---");
        check(uut.Register_File.Register[10], 32'd99,  "x10 = 99 (not overwritten, branch taken)");
        check(uut.Register_File.Register[21], 32'd99,  "x21 = 99 (branch landed correctly)");

        // ---- matmul ----
        $display("");
        $display("--- Custom: matmul [[1,2],[3,4]] x [[5,6],[7,8]] ---");
        check(uut.Register_File.Register[17], 32'd19,  "x17 = C[0][0]");
        check(uut.Register_File.Register[18], 32'd22,  "x18 = C[0][1]");
        check(uut.Register_File.Register[19], 32'd43,  "x19 = C[1][0]");
        check(uut.Register_File.Register[20], 32'd50,  "x20 = C[1][1]");

        $display("");
        $display("============================================");
        if (errors == 0)
            $display("  ALL TESTS PASSED - %0d checks", 14);
        else
            $display("  %0d TEST(S) FAILED", errors);
        $display("============================================");

        #100;
        $finish;
    end

endmodule