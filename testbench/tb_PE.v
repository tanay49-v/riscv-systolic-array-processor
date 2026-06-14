`timescale 1ns/1ps
module tb_PE;

    reg        clk, rst, clear;
    reg [31:0] A_in, B_in, C_in;
    wire[31:0] A_out, B_out, C_out;

    PE dut(
        .clk(clk), .rst(rst), .clear(clear),
        .A_in(A_in), .B_in(B_in), .C_in(C_in),
        .A_out(A_out), .B_out(B_out), .C_out(C_out)
    );

    always #5 clk = ~clk;

    integer errors = 0;

    task check;
        input [31:0] got;
        input [31:0] exp;
        input [127:0] name;
        begin
            if (got !== exp) begin
                $display("FAIL %-30s got=%0d  expected=%0d", name, got, exp);
                errors = errors + 1;
            end else
                $display("PASS %-30s = %0d", name, got);
        end
    endtask

    initial begin
        clk=0; rst=1; clear=0;
        A_in=0; B_in=0; C_in=0;

        // T1: reset zeroes all outputs
        @(posedge clk); #1;
        rst=0;
        check(A_out, 0, "T1 reset A_out=0");
        check(B_out, 0, "T1 reset B_out=0");
        check(C_out, 0, "T1 reset C_out=0");

        // T2: basic MAC - 3*4+0 = 12
        A_in=3; B_in=4; C_in=0; clear=0;
        @(posedge clk); #1;
        check(A_out, 3,  "T2 A_out passthrough");
        check(B_out, 4,  "T2 B_out passthrough");
        check(C_out, 12, "T2 C_out 3*4+0=12");

        // T3: accumulation - 3*4+12 = 24
        A_in=3; B_in=4; C_in=12; clear=0;
        @(posedge clk); #1;
        check(C_out, 24, "T3 accumulate 3*4+12=24");

        // T4: clear zeroes C_out, A/B still forward
        A_in=5; B_in=7; C_in=99; clear=1;
        @(posedge clk); #1;
        check(A_out, 5,  "T4 clear A_out still forwards");
        check(B_out, 7,  "T4 clear B_out still forwards");
        check(C_out, 0,  "T4 clear resets C_out to 0");

        // T5: after clear, normal MAC resumes
        clear=0; A_in=5; B_in=7; C_in=0;
        @(posedge clk); #1;
        check(C_out, 35, "T5 post-clear MAC 5*7+0=35");

        // T6: A=0 means no contribution regardless of B
        A_in=0; B_in=99; C_in=10; clear=0;
        @(posedge clk); #1;
        check(C_out, 10, "T6 A=0 no contribution");

        // T7: simulate two systolic steps - what PE[0][0] does in a 2x2 matmul
        // Cycle 1: A=2, B=3, C_in=0  -> C_out=6
        // Cycle 2: A=4, B=5, C_in=6  -> C_out=26
        A_in=2; B_in=3; C_in=0;
        @(posedge clk); #1;
        check(C_out, 6,  "T7 step1 2*3+0=6");
        A_in=4; B_in=5; C_in=C_out;
        @(posedge clk); #1;
        check(C_out, 26, "T7 step2 4*5+6=26");

        // T8: rst mid-operation clears everything
        A_in=10; B_in=10; C_in=100; clear=0;
        @(posedge clk); #1;
        rst=1;
        @(posedge clk); #1;
        check(A_out, 0, "T8 mid-op rst clears A_out");
        check(B_out, 0, "T8 mid-op rst clears B_out");
        check(C_out, 0, "T8 mid-op rst clears C_out");
        rst=0;

        $display("-----------------------------");
        if (errors == 0)
            $display("ALL TESTS PASSED - PE verified");
        else
            $display("%0d TEST(S) FAILED", errors);
        $finish;
    end

endmodule