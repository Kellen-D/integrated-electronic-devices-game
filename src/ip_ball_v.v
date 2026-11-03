// A classic-Pong ball: the paddles are VERTICAL bars on the left and right, so the ball
// bounces off the top and bottom edges and is returned by a paddle when that paddle's length
// lines up with the ball. If the ball reaches a paddle plane and the paddle is not there, that
// side's miss pulses and the ball restarts from the centre, heading back towards the left paddle.
// A brick can sit in the playing field: when the ball's next position would enter it, the ball
// bounces back horizontally and hit_brick pulses, telling the core to drop the brick.
`default_nettype none

module ip_ball_v #(
    parameter W       = 640,
    parameter H       = 480,
    parameter SIZE    = 8,
    parameter SPEED_Y = 2,     // pixels up or down on each step
    parameter SPEED_X = 4,     // pixels left or right on each step
    parameter PX_L    = 24,    // x of the left paddle's front (right) face
    parameter PX_R    = 616,   // x of the right paddle's front (left) face
    parameter PH      = 64,    // paddle length
    parameter BKW     = 32,    // brick width
    parameter BKH     = 32     // brick height
) (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       step,
    input  wire [9:0] paddle_y_l,   // top y of the left paddle
    input  wire [9:0] paddle_y_r,   // top y of the right paddle
    input  wire [9:0] brick_x,      // top left corner of the brick
    input  wire [9:0] brick_y,
    input  wire       brick_alive,  // the brick is still there
    output reg  [9:0] x,
    output reg  [9:0] y,
    output reg        miss_l,       // ball got past the left paddle
    output reg        miss_r,       // ball got past the right paddle
    output reg        hit_brick     // the ball reached a live brick on this step
);
    reg right;   // 1 = moving right
    reg down;    // 1 = moving down

    // 10-bit images of the parameters, so the arithmetic stays at pos's width
    localparam [9:0] SZ  = SIZE[9:0];
    localparam [9:0] SY  = SPEED_Y[9:0];
    localparam [9:0] SX  = SPEED_X[9:0];
    localparam [9:0] PHW = PH[9:0];
    localparam [9:0] W_W = W[9:0];
    localparam [9:0] H_W = H[9:0];
    localparam [9:0] PXL = PX_L[9:0];
    localparam [9:0] PXR = PX_R[9:0];
    localparam [9:0] BXW = BKW[9:0];
    localparam [9:0] BXH = BKH[9:0];

    // does the ball's vertical extent overlap the paddle's?
    wire hit_l = (y + SZ > paddle_y_l) && (y < paddle_y_l + PHW);
    wire hit_r = (y + SZ > paddle_y_r) && (y < paddle_y_r + PHW);

    // where the ball would go on this step, and whether that would put it inside the brick
    wire [9:0] nx = right ? (x + SX) : (x - SX);
    wire [9:0] ny = down  ? (y + SY) : (y - SY);
    wire brick_block = brick_alive && step &&
                       (nx + SZ > brick_x) && (nx < brick_x + BXW) &&
                       (ny + SZ > brick_y) && (ny < brick_y + BXH);

    always @(posedge clk) begin
        miss_l    <= 1'b0;
        miss_r    <= 1'b0;
        hit_brick <= 1'b0;
        if (!rst_n) begin
            x     <= (W_W - SZ) / 10'd2;
            y     <= (H_W - SZ) / 10'd2;
            right <= 1'b0;    // start moving left, towards player 1
            down  <= 1'b1;
        end else if (brick_block) begin
            // a live brick is in the way: turn round and hold both axes for this step, so the ball
            // never enters the brick and can never get stuck inside it
            right     <= ~right;
            hit_brick <= 1'b1;
        end else if (step) begin
            // up and down: bounce off the top and bottom edges
            if (down) begin
                if (y + SY + SZ >= H_W) down <= 1'b0;
                else                    y    <= y + SY;
            end else begin
                if (y <= SY) down <= 1'b1;
                else         y    <= y - SY;
            end
            // left and right: a paddle returns the ball, otherwise that side scores
            if (right) begin
                if (x + SX + SZ >= PXR) begin
                    if (hit_r) begin
                        right <= 1'b0;
                    end else begin
                        miss_r <= 1'b1;
                        x     <= (W_W - SZ) / 10'd2;
                        y     <= (H_W - SZ) / 10'd2;
                        right <= 1'b0;
                        down  <= 1'b1;
                    end
                end else begin
                    x <= x + SX;
                end
            end else begin
                if (x <= PXL + SX) begin
                    if (hit_l) begin
                        right <= 1'b1;
                    end else begin
                        miss_l <= 1'b1;
                        x     <= (W_W - SZ) / 10'd2;
                        y     <= (H_W - SZ) / 10'd2;
                        right <= 1'b0;
                        down  <= 1'b1;
                    end
                end else begin
                    x <= x - SX;
                end
            end
        end
    end
endmodule
