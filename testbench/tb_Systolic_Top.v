`timescale 1ns/1ps
module tb_Systolic_Top;

    reg         clk, rst, start;
    reg  [31:0] base_A, base_B;
    wire [31:0] mem_addr;
    reg  [31:0] mem_rdata;
    wire        busy, done;
    wire [31:0] C_00, C_01, C_10, C_11;

    Systolic_Top #(.N(2)) dut(
        .clk      (clk),
        .rst      (rst),
        .start    (start),
        .base_A   (base_A),
        .base_B   (base_B),
        .mem_addr (mem_addr),
        .mem_rdata(mem_rdata),
        .busy     (busy),
        .done     (done),
        .C_00     (C_00), .C_01(C_01),
        .C_10     (C_10), .C_11(C_11)
    );

    always #5 clk = ~clk;
    integer errors = 0;

    // Model memory - 64 words
    reg [31:0] mem [0:63];
    always @(*) mem_rdata = mem[mem_addr[7:2]];

    task check;
        input [31:0] got, exp;
        input [127:0] name;
        begin
            if (got !== exp) begin
                $display("FAIL %-12s got=%0d expected=%0d", name, got, exp);
                errors = errors + 1;
            end else
                $display("PASS %-12s = %0d", name, got);
        end
    endtask

    task init_mem;
        integer i;
        begin
            for (i=0; i<64; i=i+1) mem[i] = 32'd0;
        end
    endtask

    // Run one full matmul and wait for done
    task run_and_wait;
        integer timeout;
        begin
            // Fire start pulse
            @(posedge clk); #1;
            start = 1;
            @(posedge clk); #1;
            start = 0;

            // Wait for done with timeout
            timeout = 0;
            while (!done && timeout < 200) begin
                @(posedge clk); #1;
                timeout = timeout + 1;
            end
            if (timeout >= 200)
                $display("TIMEOUT waiting for done");
        end
    endtask

    integer i;
    initial begin
        clk=0; rst=1; start=0;
        base_A=32'd0; base_B=32'd16;
        init_mem;

        @(posedge clk); #1; rst=0;

        // ==============================================
        // TEST 1: A=[[1,2],[3,4]] x B=[[5,6],[7,8]]
        // Expected: C=[[19,22],[43,50]]
        // ==============================================
        // A stored row-major at byte addr 0
        mem[0]=1; mem[1]=2; mem[2]=3; mem[3]=4;
        // B stored row-major at byte addr 16
        mem[4]=5; mem[5]=6; mem[6]=7; mem[7]=8;

        run_and_wait;
        $display("--- Test 1: [[1,2],[3,4]] x [[5,6],[7,8]] ---");
        check(C_00, 32'd19, "C[0][0]");
        check(C_01, 32'd22, "C[0][1]");
        check(C_10, 32'd43, "C[1][0]");
        check(C_11, 32'd50, "C[1][1]");

        // Check busy went low after done
        @(posedge clk); #1;
        if (busy !== 0) begin
            $display("FAIL busy should be 0 after done");
            errors = errors + 1;
        end else
            $display("PASS busy=0 after done");

        // ==============================================
        // TEST 2: Identity x B = B
        // A=[[1,0],[0,1]] x B=[[5,6],[7,8]]
        // Expected: C=[[5,6],[7,8]]
        // ==============================================
        rst=1; @(posedge clk); #1; rst=0;
        init_mem;
        mem[0]=1; mem[1]=0; mem[2]=0; mem[3]=1;
        mem[4]=5; mem[5]=6; mem[6]=7; mem[7]=8;
        base_A=32'd0; base_B=32'd16;

        run_and_wait;
        $display("--- Test 2: identity x B ---");
        check(C_00, 32'd5,  "C[0][0]");
        check(C_01, 32'd6,  "C[0][1]");
        check(C_10, 32'd7,  "C[1][0]");
        check(C_11, 32'd8,  "C[1][1]");

        // ==============================================
        // TEST 3: Zero matrix - all outputs must be 0
        // ==============================================
        rst=1; @(posedge clk); #1; rst=0;
        init_mem;
        // A=[[0,0],[0,0]], B=[[5,6],[7,8]]
        mem[4]=5; mem[5]=6; mem[6]=7; mem[7]=8;
        base_A=32'd0; base_B=32'd16;

        run_and_wait;
        $display("--- Test 3: zero A ---");
        check(C_00, 32'd0, "C[0][0]");
        check(C_01, 32'd0, "C[0][1]");
        check(C_10, 32'd0, "C[1][0]");
        check(C_11, 32'd0, "C[1][1]");

        // ==============================================
        // TEST 4: Back-to-back - verify reuse
        // ==============================================
        rst=1; @(posedge clk); #1; rst=0;
        init_mem;
        mem[0]=2; mem[1]=2; mem[2]=2; mem[3]=2;
        mem[4]=2; mem[5]=2; mem[6]=2; mem[7]=2;
        base_A=32'd0; base_B=32'd16;

        run_and_wait;
        $display("--- Test 4: all-twos (first run) ---");
        check(C_00, 32'd8, "C[0][0]");
        check(C_11, 32'd8, "C[1][1]");

        // Immediately fire second run without reset
        run_and_wait;
        $display("--- Test 4: all-twos (second run, no reset) ---");
        check(C_00, 32'd8, "C[0][0]");
        check(C_11, 32'd8, "C[1][1]");

        $display("-----------------------------");
        if (errors == 0)
            $display("ALL TESTS PASSED - Systolic_Top verified");
        else
            $display("%0d TEST(S) FAILED", errors);
        $finish;
    end

endmodule