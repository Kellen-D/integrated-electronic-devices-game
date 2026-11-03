// The game core
// Player 1's paddle is a vertical bar that slides up and down along the left wall, and a free ball bounces around the screen. Player 2 and the centre dividing wall have been deleted.
`default_nettype none

module game_core #(
    parameter DB = 65535     // debounce time in clocks, ~2.6 ms at 25 MHz (16-bit counter)
) (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       up1,       // player 1 raw button, bounces: slide the paddle up
    input  wire       down1,     // player 1 raw button, bounces: slide the paddle down
    input  wire [9:0] x,         // column of the pixel being drawn
    input  wire [9:0] y,         // row of the pixel being drawn
    input  wire       active,    // high inside the picture
    input  wire       frame,     // one clock pulse per picture
    output wire [5:0] rgb        // {R[1:0], G[1:0], B[1:0]}
);
    // the paddle is a vertical bar sitting near the left wall
    localparam [9:0] PADDLE_X = 10'd16;      // distance from left edge
    localparam [9:0] PADDLE_W = 10'd8;       // thickness
    localparam [9:0] PADDLE_H = 10'd64;      // length
    localparam [9:0] BALL     = 10'd8;
    localparam [5:0] BLACK    = 6'b00_00_00;
    localparam [5:0] WHITE    = 6'b11_11_11;
    localparam [5:0] GREEN    = 6'b00_11_00;

    // 1. clean up the two buttons
    wire up1_c, down1_c;
    ip_debounce #(.N(DB)) db_up1   (.clk(clk), .rst_n(rst_n), .noisy(up1),   .clean(up1_c));
    ip_debounce #(.N(DB)) db_down1 (.clk(clk), .rst_n(rst_n), .noisy(down1), .clean(down1_c));

    // 2. ball moves every second picture
    wire ball_step;
    ip_tick #(.DIV(2)) ball_tick (.clk(clk), .rst_n(rst_n), .en(frame), .tick(ball_step));

    // 3. paddle slides along the wall: ip_paddle's "left" lowers pos (up the screen), "right" raises pos (down the screen). MAX = 480 - PADDLE_H so it stops at the edges
    wire [9:0] paddle_y;
    ip_paddle #(.MAX(480 - 64), .STEP(4)) paddle (
        .clk(clk), .rst_n(rst_n), .step(frame), .left(up1_c), .right(down1_c), .pos(paddle_y)
    );

    // 4. ball (currently bounces off all four edges and doesn't react to paddle)
    wire [9:0] ball_x, ball_y;
    wire       miss;
    ip_ball #(.W(640), .SIZE(8), .SPEED(4), .XSPEED(2), .PY(480), .PW(640)) ball (
        .clk(clk), .rst_n(rst_n), .step(ball_step), .paddle_x(10'd0), .x(ball_x), .y(ball_y), .miss(miss)
    );

    // 5. is the pixel being drawn inside the paddle, or inside the ball?
    wire paddle_hit, ball_hit;
    ip_rect paddle_rect (.x(x), .y(y), .rx(PADDLE_X), .ry(paddle_y), .rw(PADDLE_W), .rh(PADDLE_H), .hit(paddle_hit));
    ip_rect ball_rect   (.x(x), .y(y), .rx(ball_x),   .ry(ball_y),   .rw(BALL),     .rh(BALL),    .hit(ball_hit));

    // 6. count the misses, and show them as a brighter background
    reg [1:0] misses;
    always @(posedge clk) begin
        if (!rst_n)    misses <= 2'd0;
        else if (miss) misses <= misses + 2'd1;
    end

    // 7. colour: ball white, paddle green, otherwise blue that gets brighter with every miss
    assign rgb = !active    ? BLACK :
                 ball_hit   ? WHITE :
                 paddle_hit ? GREEN :
                              {4'b0000, misses};
endmodule
