module microSD(
  input clk,
        rst,
        uart_rx,
  

  output uart_tx,
  output sdio_cmd,

  output reg sdio_clk,
  output reg sdio_d0,
  output reg sdio_d1,
  output reg sdio_d2,
  output reg sdio_d3
 );

 //********************** UART Content ***************************//


 // If I want to send a register's content through UART, I would need to take each individual bit of the register
 //   and add its proper ASCII decimal offset to it which I think is 48 for decimal numbers...
 
 parameter                        CLK_FRE  = 27;//Mhz
 parameter                        UART_FRE = 115200;//Mhz
 localparam                       IDLE =  0;
 localparam                       SEND =  1;   //send 
 localparam                       WAIT =  2;   //wait 1 second and send uart received data
 localparam                       SET_DATA = 3; //change the tx data for next FSM cycle
 localparam			  WAIT_DATA = 4; //wait for the tx data
 reg[7:0]                         tx_data;
 reg[7:0]                         tx_str;
 reg[7:0]                         tx_str_data;
 reg                              tx_data_valid;
 wire                             tx_data_ready;
 reg[7:0]                         tx_cnt;
 wire[7:0]                        rx_data;
 wire                             rx_data_valid;
 wire                             rx_data_ready;
 reg[31:0]                        wait_cnt;
 reg[3:0]                         state;


 reg [7:0] cmd_bit_counter_uart = 8'd49; //Decimal 49 

 wire rst_n = !rst;

 assign rx_data_ready = 1'b1;//always can receive data,

 always@(posedge clk or negedge rst_n)
 begin
  if(rst_n == 1'b0)
  begin
   wait_cnt <= 32'd0;
   tx_data <= 8'd0;
   state <= IDLE;
   tx_cnt <= 8'd0;
   tx_data_valid <= 1'b0;
  end
  else
   case(state)
    IDLE:
    begin
     state <= SEND;
    end
    SEND:
    begin
     wait_cnt <= 32'd0; // Reset wait timer
     if(tx_cnt <= 47)
     begin
      tx_data <= sdio_cmd_in[47 - tx_cnt] + 8'd48; // Take the bytecode 'char' of string and store it in the transmissioin data register
     end
     else
     begin
      if(tx_cnt == 48)
      begin
       tx_data <= 16'h0d;
      end
      else
      begin
       tx_data <= 16'h0a;
      end
     end

     if(tx_data_valid == 1'b1 && tx_data_ready == 1'b1 && tx_cnt < DATA_NUM - 1) // Send transmission byte
     begin
      tx_cnt <= tx_cnt + 8'd1; //Send data counter
     end
     else if(tx_data_valid && tx_data_ready)//last byte sent is complete
     begin
      tx_cnt <= 8'd0;
      tx_data_valid <= 1'b0;
      state <= WAIT;             // This is the part we want to change...
     end
     else if(~tx_data_valid)
     begin
      tx_data_valid <= 1'b1;
     end
    end

    WAIT:
    begin
     wait_cnt <= wait_cnt + 32'd1;

     if(rx_data_valid == 1'b1)
     begin
      tx_data_valid <= 1'b1;
      tx_data <= rx_data;   // send uart received data
     end
     else if(tx_data_valid && tx_data_ready)
     begin
      tx_data_valid <= 1'b0;
     end
     else if(wait_cnt >= CLK_FRE * 1000_000) // wait for 1 second
     begin
      state <= WAIT; // Used to be (SEND) Instead stay in wait state...
     end // Now go to another state to change the message...
     
    end
/*
    SET_DATA:
    begin
     wait_cnt <= 32'd0; // Reset wait timer
     if(cmd_bit_counter_uart >= 2)
     begin
      tx_data <= {7{sdio_cmd_in[cmd_bit_counter_uart - 2]}} + 8'd48; // Take the bytecode 'char' of string and store it in the transmissioin data register
     end
     else if(cmd_bit_counter_uart == 1)
     begin
      tx_data <= 16'h0d; 
     end
     else
     begin
      tx_data <= 16'h0a;
     end

     if(cmd_bit_counter_uart != 0)
     begin
      cmd_bit_counter_uart <= cmd_bit_counter_uart - 8'd1;
     end

     if(tx_data_valid == 1'b1 && tx_data_ready == 1'b1 && tx_cnt < DATA_NUM2 - 1) // Send transmission byte
     begin
      tx_cnt <= tx_cnt + 8'd1; //Send data counter
     end
     else if(tx_data_valid && tx_data_ready)//last byte sent is complete
     begin
      tx_cnt <= 8'd0;
      tx_data_valid <= 1'b0;
      cmd_bit_counter_uart <= 8'd49;
      state <= WAIT_DATA;             // This is the part we want to change...
     end
     else if(~tx_data_valid)
     begin
      tx_data_valid <= 1'b1;
     end
    end

    WAIT_DATA:
    begin
     wait_cnt <= wait_cnt + 32'd1;

     if(rx_data_valid == 1'b1)
     begin
      tx_data_valid <= 1'b1;
      tx_data <= rx_data;   // send uart received data
     end
     else if(tx_data_valid && tx_data_ready)
     begin
      tx_data_valid <= 1'b0;
     end
     else if(wait_cnt >= CLK_FRE * 1000_000) // wait for 1 second
     begin
      state <= WAIT_DATA; // Used to be (SEND) Instead stay in wait state...
     end // Now go to another state to change the message...
    end
*/
    default:
    begin
     state <= IDLE;
    end
   endcase
 end

 //parameter 	ENG_NUM  = 8; // Number of characters
  
 //wire [ DATA_NUM * 8 - 1:0] send_data = {"SDIO CMD",16'h0d0a};

 //parameter	DATA_NUM2 = 50;
 //wire [ DATA_NUM2 * 8 - 1:0] send_data2 = {"SDIO CMD DATA",16'h0d0a}; 

 //parameter 	DATA_NUM = 10 + 2; // 10 for the 10 bits as ASCII and 2 for the carrage return and null char
 //wire [9:0] test_data = 10'b00101_01100; // Test data works... Yay!

 //Now instead of test_data use real data!
 parameter	DATA_NUM = 48 + 2; // 48 bits for SDIO CMD + 2 for carrige return and null char

 always@(*)
 begin
  //tx_str <= send_data[(DATA_NUM - 1 - tx_cnt) * 8 +: 8];
  //tx_str_data <= send_data2[(DATA_NUM2 - 1 - tx_cnt) * 8 +: 8];
 end


 uart_rx#
 (
  .CLK_FRE(CLK_FRE),
  .BAUD_RATE(UART_FRE)
 ) uart_rx_inst
 (
  .clk                        (clk                      ),
  .rst_n                      (rst_n                    ),
  .rx_data                    (rx_data                  ),
  .rx_data_valid              (rx_data_valid            ),
  .rx_data_ready              (rx_data_ready            ),
  .rx_pin                     (uart_rx                  )
 );

 uart_tx#
 (
  .CLK_FRE(CLK_FRE),
  .BAUD_RATE(UART_FRE)
 ) uart_tx_inst
 (
  .clk                        (clk                      ),
  .rst_n                      (rst_n                    ),
  .tx_data                    (tx_data                  ),
  .tx_data_valid              (tx_data_valid            ),
  .tx_data_ready              (tx_data_ready            ),
  .tx_pin                     (uart_tx                  )
 );


 reg sdio_cmd_reg = 1'b0;

 wire [47:0] sdio_cmd_in;
 reg [5:0] cmd_bit_counter = 48;
 reg [5:0] response_bit_counter = 48;

 reg start_bit = 1'b0; // From FPGA to microSD card target
 reg transmission_bit = 1'b1; // Direction '0' card -> host '1' host->card
 reg [5:0] cmd_index = 6'b000101; // Start with CMD5
 reg [31:0] arg = {8'b0,24'b0010_0000_0000_0000_0000_0000}; // For CMD5 this is broken up into 8 stuff bits + 24 OCR bits
 reg [6:0] crc7 = 7'b0000000; // Does this matter???
 reg end_bit = 1'b1; // Always 1 for host to card

 reg sdio_cmd_en = 1'b1; // Remember enable line for tristate buffer!

 //Initialize all output registers:

 //sdio_clk = 1'b1;
 

 // Design an SDIO FSM to drive the cmd/response system
 // Starting states:
 // - SET_CMD_BIT: sets next sdio command bit to sdio_cmd output register
 // - SEND_CMD_BIT: provides rising edge of sdio_clk to send the command bit
 //                 decrements the sdio command bit counter
 //                 if the bit counter was 1, transition to wait state to poll response
 //                   also lower the sdio command enable line
 // - WAIT_RESPONSE: Continues to check sdio command line for the start bit
 //                  Once the start bit is found store it in a register... TBD

 parameter SET_CMD_BIT = 0;
 parameter SEND_CMD_BIT = 1;
 parameter LOAD_RESPONSE_BIT = 2;
 parameter READ_RESPONSE_BIT = 3;
 parameter FINISH = 4;

 reg [31:0] sdio_state = SET_CMD_BIT;

 always@(posedge clk)
 begin
  sdio_d0 <= 0;
  sdio_d1 <= 0;
  sdio_d2 <= 0;
  sdio_d3 <= 0;
  case(sdio_state)

   SET_CMD_BIT:
   begin
    if(sdio_clk)
    begin
     sdio_cmd_reg <= sdio_cmd_in[cmd_bit_counter - 1];
    end
    sdio_state <= SEND_CMD_BIT;
   end

   SEND_CMD_BIT:
   begin
    if(cmd_bit_counter == 1)
    begin
     sdio_state <= LOAD_RESPONSE_BIT;
     sdio_cmd_en <= 1'b0; // Disable cmd enable line!
     cmd_bit_counter <= 48; // Reset command bit counter
    end
    else
    begin
     sdio_state <= SET_CMD_BIT; // Transition to set next cmd bit state
     cmd_bit_counter <= cmd_bit_counter - 1;
    end
   end

   LOAD_RESPONSE_BIT:
   begin
    sdio_state <= READ_RESPONSE_BIT;
    response_bit_counter <= response_bit_counter - 1;
    if(response_bit_counter == 1)
    begin
     sdio_state <= FINISH; // Check cyclical redundancy checksum here!
    end
   end

   READ_RESPONSE_BIT:
   begin

   end

   FINISH:
   begin
    sdio_state <= FINISH;
   end

  endcase
  sdio_clk <= ~sdio_clk; //toggle sdio_clk each rising edge of clk
 end

 assign sdio_cmd = sdio_cmd_en ? sdio_cmd_reg : 1'bz;
 assign sdio_cmd_in = {start_bit,transmission_bit,cmd_index,arg,crc7,end_bit};
endmodule