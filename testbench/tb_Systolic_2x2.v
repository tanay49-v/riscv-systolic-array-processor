`timescale 1ns/1ps
module tb_Systolic_2x2;

    reg        clk, rst, clear;
    reg [31:0] A_row0, A_row1;
    reg [31:0] B_col0, B_col1;
    wire[31:0] C_00, C_01, C_10, C_11;

    Systolic_Array_2x2 dut(
        .clk(clk), .rst(rst), .clear(clear),
        .A_row0(A_row0), .A_row1(A_row1),
        .B_col0(B_col0), .B_col1(B_col1),
        .C_00(C_00), .C_01(C_01),
        .C_10(C_10), .C_11(C_11)
    );

    always #5 clk = ~clk;
    integer errors = 0;

    task check;
        input [31:0] got, exp;
        input [127:0] name;
        begin
            if (got !== exp) begin
                $display("FAIL %-12s got=%0d  expected=%0d", name, got, exp);
                errors = errors + 1;
            end else
                $display("PASS %-12s = %0d", name, got);
        end
    endtask

    task reset_all;
        begin
            rst=1; clear=0;
            A_row0=0; A_row1=0;
            B_col0=0; B_col1=0;
            @(posedge clk); #1;
            rst=0;
        end
    endtask

    // Feed a 2x2 matmul and wait for all results to stabilise.
    // Feed schedule (verified by waveform trace):
    //   Cycle 1: A[][0] col, B[0][] row  - skew regs load
    //   Cycle 2: A[][1] col, B[1][] row  - skew regs release
    //   Cycles 3-6: zeros, outputs propagate and latch
    task feed_and_wait;
        input [31:0] a00, a01, a10, a11;
        input [31:0] b00, b01, b10, b11;
        begin
            A_row0=a00; A_row1=a10;
            B_col0=b00; B_col1=b01;
            @(posedge clk); #1;
            A_row0=a01; A_row1=a11;
            B_col0=b10; B_col1=b11;
            @(posedge clk); #1;
            A_row0=0; A_row1=0;
            B_col0=0; B_col1=0;
            repeat(4) @(posedge clk);
            #1;
        end
    endtask

    initial begin
        clk=0;

        // ------------------------------------------------
        // TEST 1: [[1,2],[3,4]] x [[5,6],[7,8]]
        // Expected: C = [[19,22],[43,50]]
        // ------------------------------------------------
        reset_all;
        feed_and_wait(1,2,3,4, 5,6,7,8);
        $display("--- Test 1: standard 2x2 ---");
        check(C_00, 32'd19, "C[0][0]");
        check(C_01, 32'd22, "C[0][1]");
        check(C_10, 32'd43, "C[1][0]");
        check(C_11, 32'd50, "C[1][1]");

        // ------------------------------------------------
        // TEST 2: identity x B = B
        // [[1,0],[0,1]] x [[5,6],[7,8]] = [[5,6],[7,8]]
        // ------------------------------------------------
        reset_all;
        feed_and_wait(1,0,0,1, 5,6,7,8);
        $display("--- Test 2: identity x B ---");
        check(C_00, 32'd5,  "C[0][0]");
        check(C_01, 32'd6,  "C[0][1]");
        check(C_10, 32'd7,  "C[1][0]");
        check(C_11, 32'd8,  "C[1][1]");

        // ------------------------------------------------
        // TEST 3: all-twos x all-twos = all-eights
        // [[2,2],[2,2]] x [[2,2],[2,2]] = [[8,8],[8,8]]
        // ------------------------------------------------
        reset_all;
        feed_and_wait(2,2,2,2, 2,2,2,2);
        $display("--- Test 3: all-twos ---");
        check(C_00, 32'd8, "C[0][0]");
        check(C_01, 32'd8, "C[0][1]");
        check(C_10, 32'd8, "C[1][0]");
        check(C_11, 32'd8, "C[1][1]");

        // ------------------------------------------------
        // TEST 4: zero A x anything = zero
        // [[0,0],[0,0]] x [[5,6],[7,8]] = [[0,0],[0,0]]
        // ------------------------------------------------
        reset_all;
        feed_and_wait(0,0,0,0, 5,6,7,8);
        $display("--- Test 4: zero A ---");
        check(C_00, 32'd0, "C[0][0]");
        check(C_01, 32'd0, "C[0][1]");
        check(C_10, 32'd0, "C[1][0]");
        check(C_11, 32'd0, "C[1][1]");

        // ------------------------------------------------
        // TEST 5: larger values
        // [[100,200],[0,0]] x [[100,0],[200,0]]
        // C[0][0]=100*100+200*200=50000, rest=0
        // ------------------------------------------------
        reset_all;
        feed_and_wait(100,200,0,0, 100,0,200,0);
        $display("--- Test 5: larger values ---");
        check(C_00, 32'd50000, "C[0][0]");
        check(C_01, 32'd0,     "C[0][1]");
        check(C_10, 32'd0,     "C[1][0]");
        check(C_11, 32'd0,     "C[1][1]");

        $display("-----------------------------");
        if (errors == 0)
            $display("ALL TESTS PASSED - 2x2 systolic array verified");
        else
            $display("%0d TEST(S) FAILED", errors);
        $finish;
    end

endmodule