// A paddle position: moves STEP pixels up or down on each step pulse, and stops at the edges.
`default_nettype none

module ip_paddle #(
    parameter MAX  = 576,
    parameter STEP = 4
) (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       step,
    input  wire       left,
    input  wire       right,
    output reg  [9:0] pos
);
    // do the arithmetic at pos's width so nothing is truncated or widened
    localparam [9:0] MAX_W  = MAX[9:0];
    localparam [9:0] STEP_W = STEP[9:0];

    always @(posedge clk) begin
        if (!rst_n) begin
            pos <= MAX_W / 10'd2;
        end else if (step) begin
            if (left && !right) begin
                if (pos < STEP_W) pos <= 10'd0;
                else              pos <= pos - STEP_W;
            end else if (right && !left) begin
                if (pos + STEP_W > MAX_W) pos <= MAX_W;
                else                      pos <= pos + STEP_W;
            end
        end
    end
endmodule
