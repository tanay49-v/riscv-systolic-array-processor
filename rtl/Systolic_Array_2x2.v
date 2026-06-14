module Systolic_Array_2x2 (
    input  wire        clk,
    input  wire        rst,
    input  wire        clear,

    input  wire [31:0] A_row0,   // row 0 of A - no skew
    input  wire [31:0] A_row1,   // row 1 of A - 1-cycle skew applied here

    input  wire [31:0] B_col0,   // col 0 of B - no skew
    input  wire [31:0] B_col1,   // col 1 of B - 1-cycle skew applied here

    output wire [31:0] C_00,
    output wire [31:0] C_01,
    output wire [31:0] C_10,
    output wire [31:0] C_11
);

    // --------------------------------------------------
    // Skew delay registers
    // Row 1 of A and col 1 of B are each delayed 1 cycle
    // so they arrive at their PE at the correct time
    // --------------------------------------------------
    reg [31:0] A_row1_skew;
    reg [31:0] B_col1_skew;

    always @(posedge clk) begin
        if (rst) begin
            A_row1_skew <= 32'd0;
            B_col1_skew <= 32'd0;
        end else begin
            A_row1_skew <= A_row1;
            B_col1_skew <= B_col1;
        end
    end

    // --------------------------------------------------
    // Inter-PE wires
    // A flows right: A_out[r][c] -> A_in[r][c+1]
    // B flows down:  B_out[r][c] -> B_in[r+1][c]
    // C_in of each PE is fed from its own registered C_out
    // (self-accumulation - each PE owns one output element)
    // --------------------------------------------------
    wire [31:0] A_00_to_01, A_10_to_11;
    wire [31:0] B_00_to_10, B_01_to_11;

    // --------------------------------------------------
    // PE[0][0]
    // --------------------------------------------------
    PE pe00 (
        .clk   (clk),
        .rst   (rst),
        .clear (clear),
        .A_in  (A_row0),
        .B_in  (B_col0),
        .C_in  (C_00),        // feed own output back - self-accumulates
        .A_out (A_00_to_01),
        .B_out (B_00_to_10),
        .C_out (C_00)
    );

    // --------------------------------------------------
    // PE[0][1]
    // --------------------------------------------------
    PE pe01 (
        .clk   (clk),
        .rst   (rst),
        .clear (clear),
        .A_in  (A_00_to_01),  // A forwarded from PE[0][0]
        .B_in  (B_col1_skew), // col 1 delayed by 1 cycle
        .C_in  (C_01),
        .A_out (),
        .B_out (B_01_to_11),
        .C_out (C_01)
    );

    // --------------------------------------------------
    // PE[1][0]
    // --------------------------------------------------
    PE pe10 (
        .clk   (clk),
        .rst   (rst),
        .clear (clear),
        .A_in  (A_row1_skew), // row 1 delayed by 1 cycle
        .B_in  (B_00_to_10),  // B forwarded from PE[0][0]
        .C_in  (C_10),
        .A_out (A_10_to_11),
        .B_out (),
        .C_out (C_10)
    );

    // --------------------------------------------------
    // PE[1][1]
    // --------------------------------------------------
    PE pe11 (
        .clk   (clk),
        .rst   (rst),
        .clear (clear),
        .A_in  (A_10_to_11),  // A forwarded from PE[1][0]
        .B_in  (B_01_to_11),  // B forwarded from PE[0][1]
        .C_in  (C_11),
        .A_out (),
        .B_out (),
        .C_out (C_11)
    );

endmodule