# Copyright (c) 2017 Micah Elizabeth Scott
# Copyright (c) 2020 Florent Kermarrec <florent@enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause

import os

from migen import *


def _sdemulator_pads():
    pads = Record([
        ("clk",   1),
        ("cmd_i", 1), # Where does this connect to?
                      #  Input to SD_PHY
        ("cmd_o", 1), # Where does this connect to?
                      #  Output of SD_PHY
        ("cmd_t", 1), # Where does this connect to?
                      #  Output of SD_PHY
        ("dat_i", 4), # Where does this connect to?
                      #  Input to SD_PHY
        ("dat_o", 4), # Where does this connect to?
                      #  Output of SD_PHY
        ("dat_t", 4), # Where does this connect to?
                      #  Output of SD_PHY
    ])
    return pads


class SDEmulator(Module):
    """This is a Migen wrapper around the lower-level parts of the SD card emulator
       from Google Project Vault's Open Reference Platform. This core still does all
       SD card command processing in hardware, integrating a 512-bytes block buffer.
       """
    def  __init__(self, platform):
        self.pads = pads = _sdemulator_pads()

        # The external SD clock drives a separate clock domain
        self.clock_domains.cd_sd_ll = ClockDomain(reset_less=True)
        self.comb += self.cd_sd_ll.clk.eq(pads.clk)

        self.specials.buffer = Memory(32, 512//4, init=[i for i in range(512//4)])
        self.specials.internal_rd_port = self.buffer.get_port(clock_domain="sd_ll")
        self.specials.internal_wr_port = self.buffer.get_port(write_capable=True, clock_domain="sd_ll")

        # Communication between PHY and Link layers
        self.card_state       = Signal(4) # Where does this connect to?
                                          #  Input to SD_PHY
                                          #  Output of SD_LINK
        self.mode_4bit        = Signal()  # Where does this connect to?
                                          #  Input to SD_PHY
                                          #  Output of SD_LINK
        self.mode_spi         = Signal()  # Where does this connect to?
                                          #  Input to SD_PHY
                                          #  Output of SD_LINK
        self.mode_crc_disable = Signal()  # Where does this connect to?
                                          #  Input to SD_PHY
                                          #  Output of SD_LINK
        self.spi_sel          = Signal()  # Where does this connect to?
                                          #  Output of SD_PHY  
                                          #  Input to SD_LINK
        self.cmd_in           = Signal(48)# Where does this connect to?
                                          #  Output of SD_PHY
                                          #  Input to SD_LINK
        self.cmd_in_last      = Signal(6) # Where does this connect to?
                                          #  Output of SD_LINK
        self.cmd_in_crc_good  = Signal()  # Where does this connect to?
                                          #  Output of SD_PHY
                                          #  Input to SD_LINK
        self.cmd_in_act       = Signal()  # Where does this connect to?
                                          #  Output of SD_PHY
                                          #  Input to SD_LINK
        self.data_in_act      = Signal()  # Where does this connect to?
                                          #  Input to SD_PHY
                                          #  Output of SD_LINK
        self.data_in_busy     = Signal()  # Where does this connect to?
                                          #  Output of SD_PHY
                                          #  Input to SD_LINK
        self.data_in_another  = Signal()  # Where does this connect to?
                                          #  Input to SD_PHY
                                          #  Output of SD_LINK
        self.data_in_stop     = Signal()  # Where does this connect to?
                                          #  Input to SD_PHY
                                          #  Output to SD_LINK
        self.data_in_done     = Signal()  # Where does this connect to?
                                          #  Output of SD_PHY
                                          #  Input to SD_LINK
        self.data_in_crc_good = Signal()  # Where does this connect to?
                                          #  Output of SD_PHY
                                          #  Input to SD_LINK
        self.resp_out         = Signal(136) # Where does this connect to?
                                            #  Input to SD_PHY
                                            #  Output of SD_LINK
        self.resp_type        = Signal(4) # Where does this connect to?
                                          #  Input to SD_PHY
                                          #  Output to SD_LINK
        self.resp_busy        = Signal()  # Where does this connect to?
                                          #  Input to SD_PHY
                                          #  Output to SD_LINK
        self.resp_act         = Signal()  # Where does this connect to?
                                          #  Input to SD_PHY
                                          #  Output to SD_LINK
        self.resp_done        = Signal()  # Where does this connect to?
                                          #  Output of SD_PHY
                                          #  Input to SD_LINK
        self.data_out_reg     = Signal(512) # Where does this connect to?
                                            #  Input to SD_PHY
                                            #  Output of SD_LINK
        self.data_out_src     = Signal() # Where does this connect to?
                                         #  Input to SD_PHY
                                         #  Output of SD_LINK
        self.data_out_len     = Signal(10) # Where does this connect to?
                                           #  Input to SD_PHY
                                           #  Output of SD_LINK
        self.data_out_busy    = Signal() # Where does this connect to?
                                         #  Output of SD_PHY
                                         #  Input to SD_LINK
        self.data_out_act     = Signal() # Where does this connect to?
                                         #  Input to SD_PHY
                                         #  Output to SD_LINK
        self.data_out_stop    = Signal() # Where does this connect to?
                                         #  Input to SD_PHY
                                         #  Output to SD_LINK
        self.data_out_done    = Signal() # Where does this connect to?
                                         #  Output of SD_PHY
                                         #  Input to SD_LINK

        # Status outputs
        self.info_card_desel   = Signal() # Where does this connect to?
                                          #  Output of SD_LINK
        self.err_op_out_range  = Signal() # Where does this connect to?
                                          #  ???
        self.err_unhandled_cmd = Signal() # Where does this connect to?
                                          #  Output of SD_LINK
        self.err_cmd_crc       = Signal() # Where does this connect to?
                                          #  Output of SD_LINK
        self.host_hc_support   = Signal() # Where does this connect to?
                                          #  Output of SD_LINK

        # Debug signals
        self.cmd_in_cmd  = Signal(6) # Where does this connect to?
                                     #  Output of SD_LINK
        self.card_status = Signal(32) # Where does this connect to?
                                      #  Output of SD_LINK
        self.phy_idc     = Signal(11) # Where does this connect to?
                                      #  Output of SD_PHY
        self.phy_odc     = Signal(11) # Where does this connect to?
                                      #  Output of SD_PHY
        self.phy_istate  = Signal(7) # Where does this connect to?
                                     #  Output of SD_PHY
        self.phy_ostate  = Signal(7) # Where does this connect to?
                                     #  Output of SD_PHY
        self.phy_spi_cnt = Signal(8) # Where does this connect to?
                                     #  Output of SD_PHY
        self.link_state  = Signal(7) # Where does this connect to?
                                     #  Output of SD_LINK
        self.link_ddc    = Signal(16) # Where does this connect to?
                                      #  Output of SD_LINK
        self.link_dc     = Signal(16) # Where does this connect to?
                                      #  Output of SD_LINK

        # I/O request outputs
        self.block_read_act       = Signal() # Where does this connect to?
                                             #  Output of SD_LINK
        self.block_read_addr      = Signal(32) # Where does this connect to?
                                               #  Output of SD_LINK
        self.block_read_byteaddr  = Signal(32) # Where does this connect to?
                                               #  Output of SD_LINK 
        self.block_read_num       = Signal(32) # Where does this connect to?
                                               #  Output of SD_LINK
        self.block_read_stop      = Signal() # Where does this connect to?
                                             #  Output of SD_LINK
        self.block_write_act      = Signal() # Where does this connect to?
                                             #  Output of SD_LINK
        self.block_write_addr     = Signal(32) # Where does this connect to?
                                               #  Output of SD_LINK
        self.block_write_byteaddr = Signal(32) # Where does this connect to?
                                               #  Output of SD_LINK
        self.block_write_num      = Signal(32) # Where does this connect to?
                                               #  Output of SD_LINK
        self.block_preerase_num   = Signal(23) # Where does this connect to?
                                               #  Output of SD_LINK
        self.block_erase_start    = Signal(32) # Where does this connect to?
                                               #  Output of SD_LINK
        self.block_erase_end      = Signal(32) # Where does this connect to?
                                               #  Output of SD_LINK

        # I/O completion inputs
        self.block_read_go    = Signal() # Where does this connect to?
                                         #  Input to SD_LINK
                                         # Also some combinational
        self.block_write_done = Signal() # Where does this connect to?
                                         #  Input to SD_LINK
                                         # Also some combinational

        self.specials += Instance("sd_phy",
            i_clk_50           = ClockSignal(),
            i_reset_n          = ~ResetSignal(),
            i_sd_clk           = ClockSignal("sd_ll"),
            i_sd_cmd_i         = pads.cmd_i, # cmd_i is input to PHY
            o_sd_cmd_o         = pads.cmd_o, # cmd_o is output of PHY
            o_sd_cmd_t         = pads.cmd_t, # cmd_t is output of PHY
            i_sd_dat_i         = pads.dat_i, # dat_i is input to PHY
            o_sd_dat_o         = pads.dat_o, # dat_o is output of PHY
            o_sd_dat_t         = pads.dat_t, # dat_t is output of PHY
            i_card_state       = self.card_state, # Card state is here as input to PHY
            o_cmd_in           = self.cmd_in, # cmd_in is an output of PHY
            o_cmd_in_crc_good  = self.cmd_in_crc_good, # cmd_in_crc_good is output of PHY
            o_cmd_in_act       = self.cmd_in_act, # cmd_in_act is output of PHY
            i_data_in_act      = self.data_in_act, # data_in_act is input to PHY
            o_data_in_busy     = self.data_in_busy, # data_in_busy is output of PHY
            i_data_in_another  = self.data_in_another, # data_in_another is input to PHY
            i_data_in_stop     = self.data_in_stop, # data_in_stop is input to PHY
            o_data_in_done     = self.data_in_done, # data_in_done is output of PHY
            o_data_in_crc_good = self.data_in_crc_good, # data_in_crc_good is output of PHY
            i_resp_out         = self.resp_out, # resp_out is input to PHY
            i_resp_type        = self.resp_type, # resp_type is input to PHY
            i_resp_busy        = self.resp_busy, # resp_busy is input to PHY
            i_resp_act         = self.resp_act, # resp_act is input to PHY
            o_resp_done        = self.resp_done, # resp_done is output of PHY
            i_mode_4bit        = self.mode_4bit,  # Mode 4 bit is input to PHY
            i_mode_spi         = self.mode_spi,   # Mode spi is input to PHY
            i_mode_crc_disable = self.mode_crc_disable, # Mode CRC Disable is input to PHY
            o_spi_sel          = self.spi_sel,    # spi_sel is output of PHY
            i_data_out_reg     = self.data_out_reg, # data_out_reg is input to PHY
            i_data_out_src     = self.data_out_src, # data_out_src is input to PHY
            i_data_out_len     = self.data_out_len, # data_out_len is input to PHY
            o_data_out_busy    = self.data_out_busy, # data_out_busy is output of PHY
            i_data_out_act     = self.data_out_act, # data_out_act is input to PHY
            i_data_out_stop    = self.data_out_stop, # data_out_stop is input to PHY
            o_data_out_done    = self.data_out_done, # data_out_done is output of PHY
            o_bram_rd_sd_addr  = self.internal_rd_port.adr,
            i_bram_rd_sd_q     = self.internal_rd_port.dat_r,
            o_bram_wr_sd_addr  = self.internal_wr_port.adr,
            o_bram_wr_sd_wren  = self.internal_wr_port.we,
            o_bram_wr_sd_data  = self.internal_wr_port.dat_w,
            i_bram_wr_sd_q     = self.internal_wr_port.dat_r,
            o_idc              = self.phy_idc, # phy_idc is output of PHY
            o_odc              = self.phy_odc, # phy_odc is output of PHY
            o_istate           = self.phy_istate, # phy_istate is output of PHY
            o_ostate           = self.phy_ostate, # phy_ostate is output of PHY
            o_spi_cnt          = self.phy_spi_cnt # phy_spi_cnt is output of PHY
        )

        self.specials += Instance("sd_link",
            i_clk_50               = ClockSignal(),
            i_reset_n              = ~ResetSignal(),
            o_link_card_state      = self.card_state, # Card State is also output of SD_LINK
            i_phy_cmd_in           = self.cmd_in, # cmd_in is input to SD_LINK
            i_phy_cmd_in_crc_good  = self.cmd_in_crc_good, # cmd_in_crc_good is input to SD_LINK
            i_phy_cmd_in_act       = self.cmd_in_act, # cmd_in_act is input to SD_LINK
            i_phy_spi_sel          = self.spi_sel, # spi_sel is input to SD_LINK
            o_phy_data_in_act      = self.data_in_act, # data_in_act is output of SD_LINK
            i_phy_data_in_busy     = self.data_in_busy, # data_in_busy is input to SD_LINK
            o_phy_data_in_stop     = self.data_in_stop, # data_in_stop is output of SD_LINK
            o_phy_data_in_another  = self.data_in_another, # data_in_another is output of SD_LINK
            i_phy_data_in_done     = self.data_in_done, # data_in_done is input to SD_LINK
            i_phy_data_in_crc_good = self.data_in_crc_good, # data_in_crc_good is input to SD_LINK
            o_phy_resp_out         = self.resp_out, # resp_out is output of SD_LINK
            o_phy_resp_type        = self.resp_type, # resp_type is output of SD_LINK
            o_phy_resp_busy        = self.resp_busy, # resp_busy is output of SD_LINK
            o_phy_resp_act         = self.resp_act, # resp_act is output of SD_LINK
            i_phy_resp_done        = self.resp_done, # resp_done is input to SD_LINK
            o_phy_mode_4bit        = self.mode_4bit,  # Mode 4 bit is output of SD_LINK
            o_phy_mode_spi         = self.mode_spi,   # Mode spi is output of SD_LINK
            o_phy_mode_crc_disable = self.mode_crc_disable, # Mode CRC Disable is output of SD_LINK
            o_phy_data_out_reg     = self.data_out_reg, # data_out_reg is output of SD_LINK
            o_phy_data_out_src     = self.data_out_src, # data_out_src is output of SD_LINK
            o_phy_data_out_len     = self.data_out_len, # data_out_len is output of SD_LINK
            i_phy_data_out_busy    = self.data_out_busy, # data_out_busy is input to SD_LINK
            o_phy_data_out_act     = self.data_out_act, # data_out_act is output of SD_LINK
            o_phy_data_out_stop    = self.data_out_stop, # data_out_stop is output of SD_LINK
            i_phy_data_out_done    = self.data_out_done, # data_out_done is input to SD_LINK
            o_block_read_act       = self.block_read_act, # block_read_act is output of SD_LINK
            i_block_read_go        = self.block_read_go, # block_read_go is input to SD_LINK
            o_block_read_addr      = self.block_read_addr, # block_read_addr is output of SD_LINK
            o_block_read_byteaddr  = self.block_read_byteaddr, # block_read_byteaddr is output of SD_LINK
            o_block_read_num       = self.block_read_num, # block_read_num is output of SD_LINK
            o_block_read_stop      = self.block_read_stop, # block_read_stop is output of SD_LINK
            o_block_write_act      = self.block_write_act, # block_write_act is output of SD_LINK
            i_block_write_done     = self.block_write_done, # block_write_done is input to SD_LINK
            o_block_write_addr     = self.block_write_addr, # block_write_addr is output of SD_LINK
            o_block_write_byteaddr = self.block_write_byteaddr, # block_write_byteaddr is output of SD_LINK
            o_block_write_num      = self.block_write_num, # block_write_num is output of SD_LINK
            o_block_preerase_num   = self.block_preerase_num, # block_preerase_num is output of SD_LINK
            o_block_erase_start    = self.block_erase_start, # block_erase_start is output of SD_LINK
            o_block_erase_end      = self.block_erase_end, # block_erase_end is output of SD_LINK
            i_opt_enable_hs        = 1,
            o_cmd_in_last          = self.cmd_in_last, # cmd_in_last is output of SD_LINK
            o_info_card_desel      = self.info_card_desel, # info_card_desel is output of SD_LINK
            o_err_unhandled_cmd    = self.err_unhandled_cmd, # err_unhandled_cmd is output of SD_LINK
            o_err_cmd_crc          = self.err_cmd_crc, # err_cmd_crc is output of SD_LINK 
            o_cmd_in_cmd           = self.cmd_in_cmd, # cmd_in_cmd is output of SD_LINK
            o_host_hc_support      = self.host_hc_support, # host_hc_support is output of SD_LINK
            o_card_status          = self.card_status, # card_status is output of SD_LINK
            o_state                = self.link_state, # link_state is output of SD_LINK
            o_dc                   = self.link_dc, # link_dc is output of SD_LINK
            o_ddc                  = self.link_ddc # link_ddc is output of SD_LINK
        )

        # Send block data when receiving read_act.
        self.comb += self.block_read_go.eq(self.block_read_act) # block_read_act is also comb.

        # Ack block write when receiving write_act.
        self.comb += self.block_write_done.eq(self.block_write_act) 

        # Verilog sources from ProjectVault ORP
        vdir = os.path.join(os.path.abspath(os.path.dirname(__file__)), "verilog")
        platform.add_verilog_include_path(vdir)
        platform.add_sources(vdir, "sd_common.v", "sd_link.v", "sd_phy.v")
