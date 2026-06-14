module PC_Module (clk,rst,PC,PC_Next);
    input clk,rst;
    input [31:0]PC_Next;
    output [31:0]PC;
    reg [31:0]PC;

    always @(posedge clk)
    begin
        if(rst)
            PC <= 32'd0;
        else
            PC <= PC_Next;
    end
endmodule