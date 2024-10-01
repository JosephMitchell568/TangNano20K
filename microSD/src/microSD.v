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

 reg start_bit = 1'b0; // From FPGA to microSD card target
 reg transmission_bit = 1'b1; // Direction '0' card -> host '1' host -> card
 reg [5:0] cmd_index = 6'b000101; // Start with CMD5
 reg [31:0] arg = {8'b0,24'b0010_0000_0000_0000_0000_0000}; // For CMD5 this is broken up into 8 stuff bits + 24 OCR bits
 reg [6:0] crc7 = 7'b0000000; // Does this matter???
 reg end_bit = 1'b1; // Always 1 for host to card

 // Design an SDIO FSM to drive the cmd/response system

 always@(posedge clk)
 begin
 
 end


 assign sdio_cmd_in = {start_bit,transmission_bit,cmd_index,arg,crc7,end_bit};
endmodule