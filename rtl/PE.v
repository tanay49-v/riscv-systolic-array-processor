module PE (
    input  wire        clk,
    input  wire        rst,
    input  wire        clear,      // clears C_out to 0 at start of new computation
    input  wire [31:0] A_in,       // operand from the left
    input  wire [31:0] B_in,       // operand from above
    input  wire [31:0] C_in,       // partial sum from upstream
    output reg  [31:0] A_out,      // pass A rightward
    output reg  [31:0] B_out,      // pass B downward
    output reg  [31:0] C_out       // updated partial sum
);

    wire [63:0] product;
    wire [31:0] product_lo;

    // Full 32x32 multiply - keep lower 32 bits
    // Upper 32 bits would matter for large values;
    // for a demo with small matrix values this is exact
    assign product    = A_in * B_in;
    assign product_lo = product[31:0];

    always @(posedge clk) begin
        if (rst) begin
            A_out <= 32'd0;
            B_out <= 32'd0;
            C_out <= 32'd0;
        end
        else if (clear) begin
            // Zero accumulator, but still forward A and B
            A_out <= A_in;
            B_out <= B_in;
            C_out <= 32'd0;
        end
        else begin
            A_out <= A_in;                  // forward A rightward
            B_out <= B_in;                  // forward B downward
            C_out <= product_lo + C_in;     // MAC: accumulate
        end
    end

endmodule