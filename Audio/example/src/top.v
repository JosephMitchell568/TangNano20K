module top(
    input        clk      ,
    input        rst    , //S1 button
    
    //audio interface
    output       HP_BCK   , //Same as clk_1p536m
    output       HP_WS    , //Left and right channel switching signal, low level corresponds to the left channel
    output       HP_DIN   , //dac serial data input signal
    output       PA_EN    , //Audio power amplifier is enabled, active at high level

    output reg   led
);
wire clk_6m_w;//6MHz, to generate 1.5MHz
wire clk_1p5m_w;//1.536MHz approximate clock

wire req_w;//read request
wire [15:0] q_w;//Data read from rom
reg [9:0] addr_r;//rom address

assign PA_EN = 1'b1;//PA is always on

assign rst_n = !rst ;

always@(posedge clk_1p5m_w or negedge rst_n)
if(!rst_n)
    addr_r <= 10'd0;
else if(addr_r <= 'd255)
    addr_r <= req_w?addr_r+1'b1:addr_r;
else
    addr_r <= 10'd0;
    
Gowin_rPLL pll_27m_6m (
    .clkout(clk_6m_w), 
    .reset(~rst_n), 
    .clkin(clk)
    );

Gowin_CLKDIV clk_div4(
        .clkout(clk_1p5m_w), //output clkout
        .hclkin(clk_6m_w), //input hclkin
        .resetn(rst_n) //input resetn
    );

rom_save_sin rom_save_sin_inst(
.clk(clk),
.rst_n(rst_n),
.addr(addr_r),
.data(q_w)
);

//Audio DAC driver
audio_drive u_audio_drive_0(
    .clk_1p536m(clk_1p5m_w),//bit clock, each sampling point occupies 32 clk_1p536m (16 for left and right channels)
    .rst_n     (rst_n),//Active low asynchronous reset signal
    //user data interface
    .idata     (q_w),
    .req       (req_w),//The data request signal can be connected to the read request of the external FIFO (to avoid empty reading, try to combine it with !fifo_empty and then use it as fifo_rd)
    //audio interface
    .HP_BCK   (HP_BCK),//Same as clk_1p536m
    .HP_WS    (HP_WS),//Left and right channel switching signal, low level corresponds to the left channel
    .HP_DIN   (HP_DIN)//dac serial data input signal
);

reg [23:0] counter;        //Define a variable to count

always @(posedge clk or negedge rst_n) begin // Counter block
    if (!rst_n)
        counter <= 24'd0;
    else if (counter < 24'd1349_9999)       // 0.5s delay
        counter <= counter + 1'b1;
    else
        counter <= 24'd0;
end

always @(posedge clk or negedge rst_n) begin // Toggle LED
    if (!rst_n)
        led <= 1'b1;
    else if (counter == 24'd1349_9999)       // 0.5s delay
        led <= ~led;                         // ToggleLED
end

endmodule