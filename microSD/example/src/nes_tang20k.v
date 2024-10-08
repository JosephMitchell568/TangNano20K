//
// NES top level for Sipeed Tang Nano 20K
// nand2mario
//

// Joseph Mitchell; 10/7/2024
// Restructured the code to my standard
// Goal: To learn everything I can about SD card reading from this project
// Steps:
//   - Isolate all non-sdcard related content from top level module and all subsequent modules if possible...
//   - Run the example to ensure no synthesis errors
//   - Utilize UART to display meaningful messages for SD card interface throughout emulation
//   - Add SDcard write functionality to this so that I can write data to the microSD card



module NES_Tang20k(
 input sys_clk,
 input sys_resetn,
 // Button S1
 input s1,

 // UART
 input UART_RXD,
 output UART_TXD,


 // MicroSD
 output sd_clk,
 inout sd_cmd,      // MOSI
 input  sd_dat0,     // MISO
 output sd_dat1,     // 1
 output sd_dat2,     // 1
 output sd_dat3     // 1
);

 reg sys_resetn = 0;
 always @(posedge clk) 
 begin
  sys_resetn <= ~s1;
 end

 wire [4:0] sd_active, sd_total;
 wire [23:0] sd_rsector, sd_last_sector;
 SDLoader #(.FREQ(FREQ)) sd_loader (
  .clk(clk), .resetn(sys_resetn),
  .overlay(menu_overlay), .color(menu_color), .scanline(menu_scanline),
  .cycle(menu_cycle),
  .nes_btn(loader_btn | nes_btn | loader_btn_2 | nes_btn2), 
  .dout(sd_dout), .dout_valid(sd_dout_valid),
  .sd_clk(sd_clk), .sd_cmd(sd_cmd), .sd_dat0(sd_dat0), .sd_dat1(sd_dat1),
  .sd_dat2(sd_dat2), .sd_dat3(sd_dat3),

  .debug_active(sd_active), .debug_total(sd_total),
  .debug_sd_rsector(sd_rsector), .debug_sd_last_sector(sd_last_sector)
 );

endmodule