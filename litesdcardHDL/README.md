This is the HDL core for the LiteX microSD card reader/writer

I need to make some changes to the port list in order to properly load this to the TangNano20K FPGA

I recently discovered that litesdcard uses Migen which is a python top level module to interface to verilog
 I will translate this to top level verilog and synthesize, pnr, and upload to TangNano20K as next steps...
