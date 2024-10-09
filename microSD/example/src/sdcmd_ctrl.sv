
//--------------------------------------------------------------------------------------------------------
// Module  : sdcmd_ctrl
// Type    : synthesizable, IP's sub module
// Standard: SystemVerilog 2005 (IEEE1800-2005)
// Function: sdcmd signal control,
//           instantiated by sd_reader
//--------------------------------------------------------------------------------------------------------

//Joseph Mitchell; 10/7/2024
// Restructured code to fit my standard
//10/8/2024
// Need to add sd commands for writing data to microSD card
// Goal is to write a block of data to UART,
//  then to the microSD card,
//  Read that same block from the microSD card,
//  and send read block to UART
//  Verify that both data are the same!
// Something important to note:
//  The response to your command is only determined when the 
//   cyclical redundancy check of 7 bits matches the SD command!
// For CMD0 the response should be in R1 format described below:
//  {start,transmission,cmdIndex,cardStat,CRC7,end}
//    0        0           6'bx     32'bx  crc7 1
// Keep reading responses untill CRC7 matches.
//  Timeout at 200ms...


module sdcmd_ctrl (
 input  wire         rstn,
 input  wire         clk,
 // SDcard signals (sdclk and sdcmd)
 output reg          sdclk,
 inout               sdcmd,
 // config clk freq
 input  wire  [15:0] clkdiv,
 // user input signal
 input  wire         start,
 input  wire  [15:0] precnt,
 input  wire  [ 5:0] cmd,
 input  wire  [31:0] arg,
 // user output signal
 output reg          busy,
 output reg          done,
 output reg          timeout,
 output reg          syntaxe,
 output wire  [31:0] resparg
);

 initial {busy, done, timeout, syntaxe} = '0;
 initial sdclk = '0;

 localparam [7:0] TIMEOUT = 8'd250;

 reg sdcmdoe  = 1'b0;
 reg sdcmdout = 1'b1;

 // sdcmd tri-state driver
 assign sdcmd = sdcmdoe ? sdcmdout : 1'bz;
 wire sdcmdin = sdcmdoe ? 1'b1 : sdcmd;

 function automatic logic [6:0] CalcCrc7(input logic [6:0] crc, input logic inbit);
     return {crc[5:0],crc[6]^inbit} ^ {3'b0,crc[6]^inbit,3'b0};
 endfunction

 reg  [ 5:0] req_cmd = '0;    // request[45:40]
 reg  [31:0] req_arg = '0;    // request[39: 8]
 reg  [ 6:0] req_crc = '0;    // request[ 7: 1]
 wire [51:0] request = {6'b111101, req_cmd, req_arg, req_crc, 1'b1};

 struct packed {
  logic        st;
  logic [ 5:0] cmd;
  logic [31:0] arg;
 } response = '0;

 assign resparg = response.arg;

 reg  [17:0] clkdivr = '1;
 reg  [17:0] clkcnt  = '0;
 reg  [15:0] cnt1 = '0;
 reg  [ 5:0] cnt2 = '1;
 reg  [ 7:0] cnt3 = '0;
 reg  [ 7:0] cnt4 = '1;


 always @ (posedge clk or negedge rstn)
 begin
  if(~rstn) 
  begin
   {busy, done, timeout, syntaxe} <= '0;
   sdclk <= 1'b0;
   {sdcmdoe, sdcmdout} <= 2'b01;
   {req_cmd, req_arg, req_crc} <= '0;
   response <= '0;
   clkdivr <= '1;
   clkcnt  <= '0;
   cnt1 <= '0;
   cnt2 <= '1;
   cnt3 <= '0;
   cnt4 <= '1;
  end 
  else 
  begin
   {done, timeout, syntaxe} <= '0;     
   clkcnt <= ( clkcnt < {clkdivr[16:0],1'b1} ) ? clkcnt+18'd1 : '0;
        
   if(clkcnt == '0)
   begin
    clkdivr <= {2'h0, clkdiv} + 18'd1;
   end
        
   if(clkcnt == clkdivr)
   begin
    sdclk <= 1'b0;
   end
   else if(clkcnt == {clkdivr[16:0],1'b1} )
   begin
    sdclk <= 1'b1;
   end
        
   if(~busy) 
   begin
    if(start) busy <= '1;
    req_cmd <= cmd;
    req_arg <= arg;
    req_crc <= '0;
    cnt1 <= precnt;
    cnt2 <= 6'd51;
    cnt3 <= TIMEOUT;
    cnt4 <= 8'd134;
   end 
   else if(done) 
   begin
    busy <= '0;
   end 
   else if( clkcnt == clkdivr) 
   begin
    {sdcmdoe, sdcmdout} <= 2'b01;
    if(cnt1 != '0) 
    begin
     cnt1 <= cnt1 - 16'd1;
    end 
    else if(cnt2 != '1) 
    begin
     cnt2 <= cnt2 - 6'd1;
     {sdcmdoe, sdcmdout} <= {1'b1, request[cnt2]};
     if(cnt2>=8 && cnt2<48) req_crc <= CalcCrc7(req_crc, request[cnt2]);
    end
   end 
   else if( clkcnt == {clkdivr[16:0],1'b1} && cnt1=='0 && cnt2=='1 ) 
   begin
    if(cnt3 != '0) 
    begin
     cnt3 <= cnt3 - 8'd1;
     if(~sdcmdin)
      cnt3 <= '0;
     else if(cnt3 == 8'd1)
      {done, timeout, syntaxe} <= 3'b110;
     end 
     else if(cnt4 != '1) 
     begin
      cnt4 <= cnt4 - 8'd1;
      if(cnt4 >= 8'd96)
      begin
       response <= {response[37:0], sdcmdin};
      end
      if(cnt4 == '0) 
      begin
       {done, timeout} <= 2'b10;
       syntaxe <= response.st || ((response.cmd!=req_cmd) && (response.cmd!='1) && (response.cmd!='0));
      end
     end
    end
   end
  end
 end

endmodule
