module Data_Memory(
    input  wire        clk,
    input  wire        rst,
    input  wire        WE,
    input  wire [31:0] A,
    input  wire [31:0] WD,
    output reg  [31:0] RD
);

    reg [31:0] mem [0:1023];

    integer i;

    // Synchronous write
    always @(posedge clk) begin
        if (rst) begin
            for (i = 0; i < 1024; i = i + 1)
                mem[i] <= 32'd0;
        end
        else if (WE) begin
            mem[A[11:2]] <= WD;
        end
    end

    // Asynchronous read (matches original single-cycle design intent)
    always @(*) begin
        RD = mem[A[11:2]];
    end

endmodule