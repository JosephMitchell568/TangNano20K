// Joseph Mitchell
// 1) Restructured Verilog HDL code
// 2) Draw the FSM on paper
// 3) Make changes to FSM and evaluate FPGA response


module top (
 input clk,  // input clock source

 output reg WS2812 // output to the interface of WS2812
);

parameter WS2812_NUM 	= 0; // LED number of WS2812 (starts from 0)
parameter WS2812_WIDTH 	= 24; // WS2812 data bit width
parameter CLK_FRE 	= 27000000; // CLK frequency (mHZ)
// Make sure you know how below calculations are analyzed... PEMDAS...?
parameter DELAY_1_HIGH 	= 22; //≈850ns±150ns     1 high level time   (21.95)
parameter DELAY_1_LOW 	= 10; //≈400ns±150ns 	 1 low level time  (9.8)
parameter DELAY_0_HIGH 	= 10; //≈400ns±150ns 	 0 high level time  (9.8)
parameter DELAY_0_LOW 	= 22; //≈850ns±150ns     0 low level time (21.95)
parameter DELAY_RESET 	= 2700000; //0.1s reset time ＞50us ; Should be 1348 clock cycles...

parameter RESET 	 	= 0; //state machine statement
parameter DATA_SEND  		= 1;
parameter BIT_SEND_HIGH   	= 2;
parameter BIT_SEND_LOW   	= 3;

parameter RED = 24'b00000000_11111111_00000000; // BRG
parameter ORANGE = 24'b00000000_11111111_00011111; // BRG
parameter YELLOW = 24'b00000000_11111111_11111111; // BRG
parameter LIMEGREEN = 24'b00000000_00011111_11111111; // BRG
parameter GREEN = 24'b00000000_00000000_11111111; // BRG
parameter TEALGREEN = 24'b00011111_00000000_11111111; // BRG
parameter TEAL = 24'b11111111_00000000_11111111; // BRG
parameter LIGHTBLUE = 24'b11111111_00000000_00011111; // BRG
parameter BLUE = 24'b11111111_00000000_00000000; // BRG
parameter PURPLE = 24'b11111111_00011111_00000000; // BRG
parameter PINK = 24'b11111111_11111111_00000000; // BRG
parameter LIGHTRED = 24'b00011111_11111111_00000000; // BRG

parameter INIT_DATA = 24'b00000000_00000000_00000000; // BRG

reg [ 1:0] state       = 0; // synthesis preserve  - main state machine control
reg [ 8:0] bit_send    = 0; // number of bits sent - increase for larger led strips/matrix
reg [ 8:0] data_send   = 0; // number of data sent - increase for larger led strips/matrix
reg [31:0] clk_count   = 0; // delay control
reg [23:0] WS2812_data = 0; // WS2812 color data

always@(posedge clk)
begin
 case (state)
  RESET:
  begin
   WS2812 <= 0;
   if (clk_count < DELAY_RESET) 
   begin
    clk_count <= clk_count + 1;
   end
   else 
   begin
    clk_count <= 0;
    case(WS2812_data)
     INIT_DATA:
     begin
      WS2812_data <= RED;
     end
     RED:
     begin
      WS2812_data <= ORANGE;
     end
     ORANGE:
     begin
      WS2812_data <= YELLOW;
     end
     YELLOW:
     begin
      WS2812_data <= LIMEGREEN;
     end
     LIMEGREEN:
     begin
      WS2812_data <= GREEN;
     end
     GREEN:
     begin
      WS2812_data <= TEALGREEN;
     end
     TEALGREEN:
     begin
      WS2812_data <= TEAL;
     end
     TEAL:
     begin
      WS2812_data <= LIGHTBLUE;
     end
     LIGHTBLUE:
     begin
      WS2812_data <= BLUE;
     end
     BLUE:
     begin
      WS2812_data <= PURPLE;
     end
     PURPLE:
     begin
      WS2812_data <= PINK;
     end
     PINK:
     begin
      WS2812_data <= LIGHTRED;
     end
     LIGHTRED:
     begin
      WS2812_data <= RED;
     end
    endcase
    state <= DATA_SEND;

    /*
    if (WS2812_data == 0)
    begin
     WS2812_data <= INIT_DATA;
    end
    else
    begin
     //WS2812_data <= {WS2812_data[22:0],WS2812_data[23]}; //color shift cycle display
     state <= DATA_SEND;
    end
    */
   end
  end

  DATA_SEND:
  begin
   if (data_send > WS2812_NUM && bit_send == WS2812_WIDTH)
   begin 
    clk_count <= 0;
    data_send <= 0;
    bit_send  <= 0;
    state <= RESET;
   end 
   else if (bit_send < WS2812_WIDTH) 
   begin
    state    <= BIT_SEND_HIGH;
   end
   else 
   begin
    data_send <= data_send + 1;
    bit_send  <= 0;
    state    <= BIT_SEND_HIGH;
   end
  end		
	
  BIT_SEND_HIGH:
  begin
   WS2812 <= 1;
   if (WS2812_data[bit_send])
   begin 
    if (clk_count < DELAY_1_HIGH)
    begin
     clk_count <= clk_count + 1;
    end
    else 
    begin
     clk_count <= 0;
     state    <= BIT_SEND_LOW;
    end
   end
   else
   begin 
    if (clk_count < DELAY_0_HIGH)
    begin
     clk_count <= clk_count + 1;
    end
    else 
    begin
     clk_count <= 0;
     state    <= BIT_SEND_LOW;
    end
   end
  end
 

  BIT_SEND_LOW:
  begin
   WS2812 <= 0;
   if (WS2812_data[bit_send])
   begin 
    if (clk_count < DELAY_1_LOW)
    begin 
     clk_count <= clk_count + 1;
    end
    else 
    begin
     clk_count <= 0;
     bit_send <= bit_send + 1;
     state    <= DATA_SEND;
    end
   end
   else
   begin 
    if (clk_count < DELAY_0_LOW)
    begin 
     clk_count <= clk_count + 1;
    end
    else 
    begin
     clk_count <= 0;			
     bit_send <= bit_send + 1;
     state    <= DATA_SEND;
    end
   end
  end
  
 endcase
end

endmodule