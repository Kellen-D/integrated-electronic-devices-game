// The game core
// Two paddles, one vertical bar per player, slide up and down along the left and right walls.
// The ball is a classic-Pong ball: it bounces off the top and bottom edges and is returned by
// whichever paddle lines up with it. If neither paddle is there, that side scores.
`default_nettype none

module game_core #(
    parameter DB = 65535     // debounce time in clocks, ~2.6 ms at 25 MHz (16-bit counter)
) (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       up1,       // player 1 raw button, bounces: slide the paddle up
    input  wire       down1,     // player 1 raw button, bounces: slide the paddle down
    input  wire       up2,       // player 2 raw button, bounces: slide the right paddle up
    input  wire       down2,     // player 2 raw button, bounces: slide the right paddle down
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
    localparam [9:0] PADDLE_X_R = 10'd640 - PADDLE_X - PADDLE_W;  // player 2, mirrored on the right
    localparam [9:0] BALL     = 10'd8;
    localparam [5:0] BLACK    = 6'b00_00_00;
    localparam [5:0] WHITE    = 6'b11_11_11;
    localparam [5:0] GREEN    = 6'b00_11_00;
    localparam [5:0] RED      = 6'b11_00_00;

    // 1. clean up the four buttons
    wire up1_c, down1_c, up2_c, down2_c;
    ip_debounce #(.N(DB)) db_up1   (.clk(clk), .rst_n(rst_n), .noisy(up1),   .clean(up1_c));
    ip_debounce #(.N(DB)) db_down1 (.clk(clk), .rst_n(rst_n), .noisy(down1), .clean(down1_c));
    ip_debounce #(.N(DB)) db_up2   (.clk(clk), .rst_n(rst_n), .noisy(up2),   .clean(up2_c));
    ip_debounce #(.N(DB)) db_down2 (.clk(clk), .rst_n(rst_n), .noisy(down2), .clean(down2_c));

    // 2. ball moves every second picture
    wire ball_step;
    ip_tick #(.DIV(2)) ball_tick (.clk(clk), .rst_n(rst_n), .en(frame), .tick(ball_step));

    // 3. both paddles slide along their wall: ip_paddle's "left" lowers pos (up the screen), "right"
    //    raises pos (down the screen). MAX = 480 - PADDLE_H so each one stops at the screen edges.
    //    The two instances are independent, so the players never fight over one register.
    wire [9:0] paddle_y, paddle_y_r;
    ip_paddle #(.MAX(480 - 64), .STEP(4)) paddle1 (
        .clk(clk), .rst_n(rst_n), .step(frame), .left(up1_c), .right(down1_c), .pos(paddle_y)
    );
    ip_paddle #(.MAX(480 - 64), .STEP(4)) paddle2 (
        .clk(clk), .rst_n(rst_n), .step(frame), .left(up2_c), .right(down2_c), .pos(paddle_y_r)
    );

    // 4. the ball: classic Pong. The paddles are vertical, so the ball bounces off the top and
    //    bottom edges and is returned when a paddle lines up with it. PADDLE_FACE is the left
    //    paddle's front face; the right paddle's face is its mirror image across the screen.
    localparam [9:0] PADDLE_FACE   = PADDLE_X + PADDLE_W;             // 24
    localparam [9:0] PADDLE_FACE_R = 10'd640 - PADDLE_FACE;           // 616
    wire [9:0] ball_x, ball_y;
    wire       miss_l, miss_r;
    ip_ball_v #(.W(640), .H(480), .SIZE(8), .SPEED_Y(2), .SPEED_X(4),
                .PX_L(PADDLE_FACE), .PX_R(PADDLE_FACE_R), .PH(PADDLE_H)) ball (
        .clk(clk), .rst_n(rst_n), .step(ball_step),
        .paddle_y_l(paddle_y), .paddle_y_r(paddle_y_r),
        .x(ball_x), .y(ball_y), .miss_l(miss_l), .miss_r(miss_r)
    );
    wire miss = miss_l | miss_r;

    // 5. is the pixel being drawn inside either paddle, or inside the ball?
    wire paddle_hit, paddle2_hit, ball_hit;
    ip_rect paddle_rect  (.x(x), .y(y), .rx(PADDLE_X),   .ry(paddle_y),   .rw(PADDLE_W), .rh(PADDLE_H), .hit(paddle_hit));
    ip_rect paddle2_rect (.x(x), .y(y), .rx(PADDLE_X_R), .ry(paddle_y_r), .rw(PADDLE_W), .rh(PADDLE_H), .hit(paddle2_hit));
    ip_rect ball_rect    (.x(x), .y(y), .rx(ball_x),     .ry(ball_y),     .rw(BALL),     .rh(BALL),     .hit(ball_hit));

    // 6. count the misses, and show them as a brighter background
    reg [1:0] misses;
    always @(posedge clk) begin
        if (!rst_n)    misses <= 2'd0;
        else if (miss) misses <= misses + 2'd1;
    end

    // 7. colour: ball white, player 1 green, player 2 red, otherwise blue that gets brighter with
    //    every miss. Ball first so it is never hidden behind a paddle.
    assign rgb = !active      ? BLACK :
                 ball_hit     ? WHITE :
                 paddle_hit   ? GREEN :
                 paddle2_hit  ? RED   :
                                {4'b0000, misses};
endmodule
