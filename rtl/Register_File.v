module Register_File(
    input  wire        clk,
    input  wire        rst,
    input  wire        WE3,
    input  wire [4:0]  A1,
    input  wire [4:0]  A2,
    input  wire [4:0]  A3,
    input  wire [31:0] WD3,
    output wire [31:0] RD1,
    output wire [31:0] RD2
);

    reg [31:0] Register [31:0];

    integer i;

    // Synchronous write, x0 hardwired to 0
    always @(posedge clk) begin
        if (rst) begin
            for (i = 0; i < 32; i = i + 1)
                Register[i] <= 32'd0;
        end
        else if (WE3 && A3 != 5'b0) begin
            Register[A3] <= WD3;
        end
    end

    // Asynchronous read, x0 always 0
    assign RD1 = (A1 == 5'b0) ? 32'd0 : Register[A1];
    assign RD2 = (A2 == 5'b0) ? 32'd0 : Register[A2];

endmodule