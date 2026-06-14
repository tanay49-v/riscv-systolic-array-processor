module Matrix_Loader #(
    parameter N = 2
)(
    input  wire        clk,
    input  wire        rst,
    input  wire        load_en,
    input  wire [31:0] base_A,
    input  wire [31:0] base_B,

    output reg  [31:0] mem_addr,
    input  wire [31:0] mem_rdata,

    output reg  [31:0] A_row0,
    output reg  [31:0] A_row1,
    output reg  [31:0] B_col0,
    output reg  [31:0] B_col1
);

    // Internal element registers - filled during LOAD pre-load phase
    reg [31:0] a00, a01, a10, a11;
    reg [31:0] b00, b01, b10, b11;

    // rd_cnt: 0..7, steps through 8 memory reads (4 for A, 4 for B)
    reg [3:0] rd_cnt;
    reg       loaded;   // high once all 8 elements are captured

    // col: 0..N-1, advances each COMPUTE cycle
    reg [3:0] col;

    // --------------------------------------------------
    // Address generation - combinational
    // --------------------------------------------------
    always @(*) begin
        case (rd_cnt)
            4'd0: mem_addr = base_A + 32'd0;
            4'd1: mem_addr = base_A + 32'd4;
            4'd2: mem_addr = base_A + 32'd8;
            4'd3: mem_addr = base_A + 32'd12;
            4'd4: mem_addr = base_B + 32'd0;
            4'd5: mem_addr = base_B + 32'd4;
            4'd6: mem_addr = base_B + 32'd8;
            4'd7: mem_addr = base_B + 32'd12;
            default: mem_addr = base_A;
        endcase
    end

    // --------------------------------------------------
    // Pre-load: capture one element per clock during LOAD
    // --------------------------------------------------
    always @(posedge clk) begin
        if (rst) begin
            rd_cnt <= 4'd0;
            loaded <= 1'b0;
            a00<=0; a01<=0; a10<=0; a11<=0;
            b00<=0; b01<=0; b10<=0; b11<=0;
        end
        else if (!load_en) begin
            rd_cnt <= 4'd0;
            loaded <= 1'b0;
        end
        else if (load_en && !loaded) begin
            case (rd_cnt)
                4'd0: a00 <= mem_rdata;
                4'd1: a01 <= mem_rdata;
                4'd2: a10 <= mem_rdata;
                4'd3: a11 <= mem_rdata;
                4'd4: b00 <= mem_rdata;
                4'd5: b01 <= mem_rdata;
                4'd6: b10 <= mem_rdata;
                4'd7: begin
                    b11    <= mem_rdata;
                    loaded <= 1'b1;
                end
            endcase
            rd_cnt <= rd_cnt + 4'd1;
        end
    end

    // --------------------------------------------------
    // Column counter - advances each COMPUTE cycle
    // (load_en=1 AND loaded=1 means COMPUTE is active)
    // --------------------------------------------------
    always @(posedge clk) begin
        if (rst)
            col <= 4'd0;
        else if (!load_en)
            col <= 4'd0;
        else if (load_en && loaded) begin
            if (col < N - 1)
                col <= col + 4'd1;
        end
    end

    // --------------------------------------------------
    // Output mux - COMBINATIONAL so outputs are valid
    // in the same cycle that loaded goes high
    // Feed schedule:
    //   col=0: A_row0=a00, A_row1=a10, B_col0=b00, B_col1=b01
    //   col=1: A_row0=a01, A_row1=a11, B_col0=b10, B_col1=b11
    // --------------------------------------------------
    always @(*) begin
        if (!load_en || !loaded) begin
            A_row0 = 32'd0;
            A_row1 = 32'd0;
            B_col0 = 32'd0;
            B_col1 = 32'd0;
        end
        else begin
            case (col)
                4'd0: begin
                    A_row0 = a00;
                    A_row1 = a10;
                    B_col0 = b00;
                    B_col1 = b01;
                end
                4'd1: begin
                    A_row0 = a01;
                    A_row1 = a11;
                    B_col0 = b10;
                    B_col1 = b11;
                end
                default: begin
                    A_row0 = 32'd0;
                    A_row1 = 32'd0;
                    B_col0 = 32'd0;
                    B_col1 = 32'd0;
                end
            endcase
        end
    end

endmodule