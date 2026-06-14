`timescale 1ns/1ps
module tb_Systolic_Controller;

    reg  clk, rst, start;
    wire clear, load_en, busy, done;

    // Instantiate with N=2 (2x2 matrix)
    Systolic_Controller #(.N(2)) dut(
        .clk(clk), .rst(rst), .start(start),
        .clear(clear), .load_en(load_en),
        .busy(busy), .done(done)
    );

    always #5 clk = ~clk;
    integer errors = 0;
    integer cycle;

    task check;
        input exp_clear, exp_load_en, exp_busy, exp_done;
        input [127:0] label;
        begin
            if ({clear,load_en,busy,done} !== {exp_clear,exp_load_en,exp_busy,exp_done}) begin
                $display("FAIL [%0t] %-30s | clear=%b load_en=%b busy=%b done=%b | exp: %b %b %b %b",
                    $time, label, clear, load_en, busy, done,
                    exp_clear, exp_load_en, exp_busy, exp_done);
                errors = errors + 1;
            end else
                $display("PASS [%0t] %s", $time, label);
        end
    endtask

    initial begin
        clk=0; rst=1; start=0;
        @(posedge clk); #1;

        // -------------------------------------------
        // T1: after reset - should be in IDLE
        // clear=1, busy=0, done=0, load_en=0
        // -------------------------------------------
        rst=0; @(posedge clk); #1;
        check(1,0,0,0, "T1 IDLE after reset");

        // -------------------------------------------
        // T2: start=0 - must stay in IDLE
        // -------------------------------------------
        start=0; @(posedge clk); #1;
        check(1,0,0,0, "T2 IDLE no start pulse");

        // -------------------------------------------
        // T3: assert start=1 for one cycle → LOAD
        // LOAD: clear=1, busy=1, load_en=1, done=0
        // -------------------------------------------
        start=1; @(posedge clk); #1;
        start=0;
        check(1,1,1,0, "T3 LOAD state");

        // -------------------------------------------
        // T4: after LOAD (1 cycle) → COMPUTE
        // COMPUTE: clear=0, busy=1, load_en=1
        // -------------------------------------------
        @(posedge clk); #1;
        check(0,1,1,0, "T4 COMPUTE cycle 0");

        // -------------------------------------------
        // T5: COMPUTE cycle 1 (N=2, so stays 2 cycles: 0 and 1)
        // -------------------------------------------
        @(posedge clk); #1;
        check(0,1,1,0, "T5 COMPUTE cycle 1");

        // -------------------------------------------
        // T6: after N=2 compute cycles → DRAIN
        // DRAIN: clear=0, busy=1, load_en=0
        // -------------------------------------------
        @(posedge clk); #1;
        check(0,0,1,0, "T6 DRAIN state");

        // -------------------------------------------
        // T7: after N-1=1 drain cycle → DONE
        // DONE: done=1, busy=0
        // -------------------------------------------
        @(posedge clk); #1;
        check(0,0,0,1, "T7 DONE state done=1");

        // -------------------------------------------
        // T8: after DONE (1 cycle) → back to IDLE
        // -------------------------------------------
        @(posedge clk); #1;
        check(1,0,0,0, "T8 back to IDLE after DONE");

        // -------------------------------------------
        // T9: done must be 0 in IDLE (not sticky)
        // -------------------------------------------
        @(posedge clk); #1;
        check(1,0,0,0, "T9 done=0 in IDLE not sticky");

        // -------------------------------------------
        // T10: second back-to-back computation
        // Verifies counter resets correctly for reuse
        // -------------------------------------------
        start=1; @(posedge clk); #1; start=0;
        check(1,1,1,0, "T10 second run LOAD");
        @(posedge clk); #1;
        check(0,1,1,0, "T10 second run COMPUTE 0");
        @(posedge clk); #1;
        check(0,1,1,0, "T10 second run COMPUTE 1");
        @(posedge clk); #1;
        check(0,0,1,0, "T10 second run DRAIN");
        @(posedge clk); #1;
        check(0,0,0,1, "T10 second run DONE");
        @(posedge clk); #1;
        check(1,0,0,0, "T10 second run back to IDLE");

        // -------------------------------------------
        // T11: rst mid-computation forces back to IDLE
        // -------------------------------------------
        start=1; @(posedge clk); #1; start=0;
        @(posedge clk); #1;   // now in COMPUTE
        rst=1; @(posedge clk); #1; rst=0;
        check(1,0,0,0, "T11 rst mid-compute returns IDLE");

        // -------------------------------------------
        // T12: busy must be 0 in IDLE and DONE only
        // Check full sequence busy timeline
        // -------------------------------------------
        start=1; @(posedge clk); #1; start=0;
        if (busy !== 1) begin
            $display("FAIL T12 busy not asserted in LOAD");
            errors = errors + 1;
        end else $display("PASS T12 busy=1 in LOAD");

        @(posedge clk); #1;
        if (busy !== 1) begin
            $display("FAIL T12 busy not asserted in COMPUTE");
            errors = errors + 1;
        end else $display("PASS T12 busy=1 in COMPUTE");

        repeat(3) @(posedge clk);   // through remaining COMPUTE+DRAIN+DONE
        #1;
        if (busy !== 0) begin
            $display("FAIL T12 busy not deasserted in IDLE");
            errors = errors + 1;
        end else $display("PASS T12 busy=0 back in IDLE");

        $display("-----------------------------");
        if (errors == 0)
            $display("ALL TESTS PASSED - Controller verified");
        else
            $display("%0d TEST(S) FAILED", errors);
        $finish;
    end

endmodule