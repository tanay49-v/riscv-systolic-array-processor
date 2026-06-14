module Systolic_Top #(
    parameter N = 2
)(
    input  wire        clk,
    input  wire        rst,
    input  wire        start,

    input  wire [31:0] base_A,
    input  wire [31:0] base_B,
    input  wire [31:0] result_base,

    output reg  [31:0] mem_addr,
    output reg         mem_we,
    output reg  [31:0] mem_wdata,
    input  wire [31:0] mem_rdata,

    output wire        busy,
    output wire        done,

    output wire [31:0] C_00, C_01, C_10, C_11
);

    wire        clear, load_en;
    wire [31:0] A_row0, A_row1, B_col0, B_col1;
    wire [31:0] loader_mem_addr;

    Systolic_Controller #(.N(N)) ctrl(
        .clk(clk), .rst(rst), .start(start),
        .clear(clear), .load_en(load_en),
        .busy(busy), .done(done)
    );

    Matrix_Loader #(.N(N)) loader(
        .clk(clk), .rst(rst),
        .load_en(load_en),
        .base_A(base_A), .base_B(base_B),
        .mem_addr(loader_mem_addr),
        .mem_rdata(mem_rdata),
        .A_row0(A_row0), .A_row1(A_row1),
        .B_col0(B_col0), .B_col1(B_col1)
    );

    Systolic_Array_2x2 array(
        .clk(clk), .rst(rst), .clear(clear),
        .A_row0(A_row0), .A_row1(A_row1),
        .B_col0(B_col0), .B_col1(B_col1),
        .C_00(C_00), .C_01(C_01),
        .C_10(C_10), .C_11(C_11)
    );

    // --------------------------------------------------
    // Result capture registers
    // Capture all C values when done fires
    // Write from these captured values - NOT live C wires
    // which get cleared by IDLE state immediately after done
    // --------------------------------------------------
    reg [31:0] c00_reg, c01_reg, c10_reg, c11_reg;

    always @(posedge clk) begin
        if (rst) begin
            c00_reg <= 32'd0; c01_reg <= 32'd0;
            c10_reg <= 32'd0; c11_reg <= 32'd0;
        end
        else if (done) begin
            c00_reg <= C_00;
            c01_reg <= C_01;
            c10_reg <= C_10;
            c11_reg <= C_11;
        end
    end

    // --------------------------------------------------
    // Write-back state machine
    // Triggers on done, writes 4 captured values over
    // 4 cycles to result_base .. result_base+12
    // --------------------------------------------------
    reg [2:0] wr_cnt;

    always @(posedge clk) begin
        if (rst)
            wr_cnt <= 3'd0;
        else if (done)
            wr_cnt <= 3'd1;
        else if (wr_cnt == 3'd4)
            wr_cnt <= 3'd0;
        else if (wr_cnt != 3'd0)
            wr_cnt <= wr_cnt + 3'd1;
    end

    // Memory interface mux
    always @(*) begin
        mem_addr  = loader_mem_addr;
        mem_we    = 1'b0;
        mem_wdata = 32'd0;

        if (wr_cnt != 3'd0) begin
            mem_we = 1'b1;
            case (wr_cnt)
                3'd1: begin mem_addr = result_base;         mem_wdata = c00_reg; end
                3'd2: begin mem_addr = result_base + 32'd4;  mem_wdata = c01_reg; end
                3'd3: begin mem_addr = result_base + 32'd8;  mem_wdata = c10_reg; end
                3'd4: begin mem_addr = result_base + 32'd12; mem_wdata = c11_reg; end
                default: begin mem_addr = result_base; mem_wdata = 32'd0; end
            endcase
        end
    end

endmodule