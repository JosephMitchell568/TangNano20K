module microSD(
  input clk,
        rst,

  output reg sdio_clk,
             sdio_cmd,
             sdio_d0,
             sdio_d1,
             sdio_d2,
             sdio_d3
 );


 wire [47:0] sdio_cmd_in;
 reg [5:0] cmd_bit_counter = 48;

 reg start_bit = 1'b0; // From FPGA to microSD card target
 reg transmission_bit = 1'b1; // Direction '0' card -> host '1' host -> card
 reg [5:0] cmd_index = 6'b000101; // Start with CMD5
 reg [31:0] arg = {8'b0,24'b0010_0000_0000_0000_0000_0000}; // For CMD5 this is broken up into 8 stuff bits + 24 OCR bits
 reg [6:0] crc7 = 7'b0000000; // Does this matter???
 reg end_bit = 1'b1; // Always 1 for host to card

 reg sdio_cmd_en = 1'b1; // Remember enable line for tristate buffer!

 //Initialize all output registers:
 sdio_clk = 1'b1;
 sdio_cmd = 1'b0;
 sdio_d0 = 1'b0;
 sdio_d1 = 1'b0;
 sdio_d2 = 1'b0;
 sdio_d3 = 1'b0;

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
 parameter WAIT_RESPONSE = 2;

 reg [31:0] sdio_state = SET_CMD_BIT;

 always@(posedge clk)
 begin
  case(sdio_state)
   SET_CMD_BIT:
   begin
    if(sdio_clk)
    begin
     
    end
   end
  endcase
  sdio_clk <= ~sdio_clk; //toggle sdio_clk each rising edge of clk
 end


 assign sdio_cmd_in = {start_bit,transmission_bit,cmd_index,arg,crc7,end_bit};
endmodule