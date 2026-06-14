`timescale 1ns/1ps
module tb_Matrix_Loader;

    reg        clk, rst;
    reg        load_en;
    reg [31:0] base_A, base_B;
    wire[31:0] mem_addr;
    reg [31:0] mem_rdata;
    wire[31:0] A_row0, A_row1, B_col0, B_col1;

    Matrix_Loader #(.N(2)) dut(
        .clk(clk), .rst(rst),
        .load_en(load_en),
        .base_A(base_A), .base_B(base_B),
        .mem_addr(mem_addr), .mem_rdata(mem_rdata),
        .A_row0(A_row0), .A_row1(A_row1),
        .B_col0(B_col0), .B_col1(B_col1)
    );

    always #5 clk = ~clk;
    integer errors = 0;

    // Small model memory - 32 words
    reg [31:0] mem [0:31];

    // Combinational read - matches Data_Memory behaviour
    always @(*) mem_rdata = mem[mem_addr[6:2]];

    task check;
        input [31:0] got, exp;
        input [127:0] name;
        begin
            if (got !== exp) begin
                $display("FAIL %-20s got=%0d expected=%0d", name, got, exp);
                errors = errors + 1;
            end else
                $display("PASS %-20s = %0d", name, got);
        end
    endtask

    integer i;
    initial begin
        clk=0; rst=1; load_en=0;
        base_A=32'd0; base_B=32'd16;

        // Initialise memory to zero
        for (i=0; i<32; i=i+1) mem[i] = 32'd0;

        // Matrix A = [[1,2],[3,4]] stored row-major at byte address 0
        // A[0][0]=1 @ addr 0, A[0][1]=2 @ addr 4
        // A[1][0]=3 @ addr 8, A[1][1]=4 @ addr 12
        mem[0] = 32'd1;   // A[0][0]
        mem[1] = 32'd2;   // A[0][1]
        mem[2] = 32'd3;   // A[1][0]
        mem[3] = 32'd4;   // A[1][1]

        // Matrix B = [[5,6],[7,8]] stored row-major at byte address 16
        // B[0][0]=5 @ addr 16, B[0][1]=6 @ addr 20
        // B[1][0]=7 @ addr 24, B[1][1]=8 @ addr 28
        mem[4] = 32'd5;   // B[0][0]
        mem[5] = 32'd6;   // B[0][1]
        mem[6] = 32'd7;   // B[1][0]
        mem[7] = 32'd8;   // B[1][1]

        @(posedge clk); #1; rst=0;

        // -----------------------------------------------
        // TEST 1: Pre-load phase
        // Assert load_en for 8 cycles - loader reads all
        // 8 elements from memory into internal registers
        // -----------------------------------------------
        load_en = 1;
        repeat(8) @(posedge clk);
        #1;

        // After 8 read cycles the loaded flag should be set
        // and the loader should start streaming col=0
        // col=0: A_row0=a00=1, A_row1=a10=3, B_col0=b00=5, B_col1=b01=6
        $display("--- Test 1: col=0 stream (compute cycle 1) ---");
        check(A_row0, 32'd1, "A_row0 col0");
        check(A_row1, 32'd3, "A_row1 col0");
        check(B_col0, 32'd5, "B_col0 col0");
        check(B_col1, 32'd6, "B_col1 col0");

        // -----------------------------------------------
        // TEST 2: Next compute cycle - col advances to 1
        // col=1: A_row0=a01=2, A_row1=a11=4, B_col0=b10=7, B_col1=b11=8
        // -----------------------------------------------
        @(posedge clk); #1;
        $display("--- Test 2: col=1 stream (compute cycle 2) ---");
        check(A_row0, 32'd2, "A_row0 col1");
        check(A_row1, 32'd4, "A_row1 col1");
        check(B_col0, 32'd7, "B_col0 col1");
        check(B_col1, 32'd8, "B_col1 col1");

        // -----------------------------------------------
        // TEST 3: load_en drops (DRAIN state) - outputs go to zero
        // -----------------------------------------------
        load_en = 0;
        @(posedge clk); #1;
        $display("--- Test 3: load_en=0 outputs zero ---");
        check(A_row0, 32'd0, "A_row0 drain");
        check(A_row1, 32'd0, "A_row1 drain");
        check(B_col0, 32'd0, "B_col0 drain");
        check(B_col1, 32'd0, "B_col1 drain");

        // -----------------------------------------------
        // TEST 4: Reset during operation clears everything
        // -----------------------------------------------
        load_en=1;
        repeat(4) @(posedge clk);
        rst=1; @(posedge clk); #1; rst=0;
        load_en=0;
        check(A_row0, 32'd0, "A_row0 after rst");
        check(A_row1, 32'd0, "A_row1 after rst");
        check(B_col0, 32'd0, "B_col0 after rst");
        check(B_col1, 32'd0, "B_col1 after rst");

        // -----------------------------------------------
        // TEST 5: Second complete run - verifies rd_cnt
        // resets correctly and loader can be reused
        // -----------------------------------------------
        load_en=1;
        repeat(8) @(posedge clk); #1;
        $display("--- Test 5: second run col=0 ---");
        check(A_row0, 32'd1, "A_row0 run2 col0");
        check(A_row1, 32'd3, "A_row1 run2 col0");
        check(B_col0, 32'd5, "B_col0 run2 col0");
        check(B_col1, 32'd6, "B_col1 run2 col0");
        @(posedge clk); #1;
        $display("--- Test 5: second run col=1 ---");
        check(A_row0, 32'd2, "A_row0 run2 col1");
        check(A_row1, 32'd4, "A_row1 run2 col1");
        check(B_col0, 32'd7, "B_col0 run2 col1");
        check(B_col1, 32'd8, "B_col1 run2 col1");
        load_en=0;

        $display("-----------------------------");
        if (errors == 0)
            $display("ALL TESTS PASSED - Matrix Loader verified");
        else
            $display("%0d TEST(S) FAILED", errors);
        $finish;
    end

endmodule