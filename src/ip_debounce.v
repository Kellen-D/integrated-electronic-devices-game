// Synchronises a noisy input and only changes the output when the input has held steady for N clocks.
`default_nettype none

module ip_debounce #(
    parameter N = 16
) (
    input  wire clk,
    input  wire rst_n,
    input  wire noisy,
    output reg  clean
);
    // the hold counter only needs as many bits as N: 16 bits for DB=65535, not 20
    localparam CW = (N > 1) ? $clog2(N) : 1;
    reg          sync1, sync2;
    reg [CW-1:0] count;

    always @(posedge clk) begin
        if (!rst_n) begin
            sync1 <= 1'b0;
            sync2 <= 1'b0;
            count <= {CW{1'b0}};
            clean <= 1'b0;
        end else begin
            sync1 <= noisy;
            sync2 <= sync1;
            if (sync2 == clean) begin
                count <= {CW{1'b0}};
            end else if (count == N - 1) begin
                clean <= sync2;
                count <= {CW{1'b0}};
            end else begin
                count <= count + 1'b1;
            end
        end
    end
endmodule
