// A tick generator: one pulse every DIV enabled clock cycles.
`default_nettype none

module ip_tick #(
    parameter DIV = 4
) (
    input  wire clk,
    input  wire rst_n,
    input  wire en,
    output wire tick
);
    // only as many bits as DIV needs, so a DIV of 2 costs one flop, not twenty
    localparam CW = (DIV > 1) ? $clog2(DIV) : 1;
    reg [CW-1:0] count;

    assign tick = en && (count == DIV - 1);

    always @(posedge clk) begin
        if (!rst_n) begin
            count <= {CW{1'b0}};
        end else if (en) begin
            if (count == DIV - 1) count <= {CW{1'b0}};
            else                  count <= count + 1'b1;
        end
    end
endmodule
