module Systolic_Controller #(
    parameter N = 2
)(
    input  wire clk,
    input  wire rst,
    input  wire start,
    output reg  clear,
    output reg  load_en,
    output reg  busy,
    output reg  done
);

    localparam IDLE    = 3'd0;
    localparam LOAD    = 3'd1;
    localparam COMPUTE = 3'd2;
    localparam DRAIN   = 3'd3;
    localparam DONE    = 3'd4;

    // LOAD lasts 2*N*N cycles (pre-load all elements)
    // For N=2: 8 cycles
    localparam LOAD_CYCLES    = 2 * N * N;
    // COMPUTE lasts N cycles
    localparam COMPUTE_CYCLES = N;
    // DRAIN lasts N-1 cycles
    localparam DRAIN_CYCLES   = N;

    reg [2:0] state, next_state;
    reg [3:0] cycle_cnt;    // 4-bit: handles up to N=7

    // State register
    always @(posedge clk) begin
        if (rst) state <= IDLE;
        else     state <= next_state;
    end

    // Cycle counter
    always @(posedge clk) begin
        if (rst)
            cycle_cnt <= 4'd0;
        else begin
            case (state)
                IDLE:    cycle_cnt <= 4'd0;
                LOAD:    cycle_cnt <= cycle_cnt + 4'd1;
                COMPUTE: cycle_cnt <= cycle_cnt + 4'd1;
                DRAIN:   cycle_cnt <= cycle_cnt + 4'd1;
                DONE:    cycle_cnt <= 4'd0;
                default: cycle_cnt <= 4'd0;
            endcase
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE:
                if (start) next_state = LOAD;

            LOAD:
                // stay for 2*N*N cycles to pre-load all elements
                if (cycle_cnt == LOAD_CYCLES - 1)
                    next_state = COMPUTE;

            COMPUTE:
                if (cycle_cnt == LOAD_CYCLES + COMPUTE_CYCLES - 1)
                    next_state = (DRAIN_CYCLES > 0) ? DRAIN : DONE;

            DRAIN:
                if (cycle_cnt == LOAD_CYCLES + COMPUTE_CYCLES + DRAIN_CYCLES - 1)
                    next_state = DONE;

            DONE:
                next_state = IDLE;

            default:
                next_state = IDLE;
        endcase
    end

    // Output logic (Moore)
    always @(*) begin
        clear   = 1'b0;
        load_en = 1'b0;
        busy    = 1'b0;
        done    = 1'b0;

        case (state)
            IDLE: begin
                clear   = 1'b1;
                busy    = 1'b0;
            end
            LOAD: begin
                clear   = 1'b1;     // keep accumulators zeroed during pre-load
                busy    = 1'b1;
                load_en = 1'b1;     // loader reads from memory
            end
            COMPUTE: begin
                clear   = 1'b0;     // accumulators active
                busy    = 1'b1;
                load_en = 1'b1;     // loader streams from registers to array
            end
            DRAIN: begin
                clear   = 1'b0;
                busy    = 1'b1;
                load_en = 1'b0;
            end
            DONE: begin
                busy    = 1'b0;
                done    = 1'b1;
            end
            default: begin
                clear   = 1'b1;
            end
        endcase
    end

endmodule