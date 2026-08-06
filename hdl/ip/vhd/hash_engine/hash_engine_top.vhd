-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.axi_st8_pkg;
use work.axil8x32_pkg.all;
use work.hash_engine_regs_pkg.all;
use work.keccak_pkg.all;

-- SHA3-256 hashing engine with an AXI-Lite register interface.
--
-- Hashes either a range of the host QSPI flash or data written in through a
-- register, optionally prefixed with a run of 0xFF bytes. The result appears in
-- eight read-only digest registers.
--
-- Flash bytes are fetched over a command/response FIFO channel in the same shape
-- as the eSPI flash channel: a 32-bit command FIFO taking an address word then a
-- length word, and an 8-bit response FIFO of data bytes. Those FIFOs live in the
-- integrating design, as they do for eSPI, and the far end is a second client
-- port on spi_nor_top. Unlike the eSPI path these addresses are raw: no SP5 image
-- or APOB translation is applied.
--
-- The integrator should hold the response FIFO in reset only from the global
-- reset. This block never asks for it to be flushed: an abandoned read is dealt
-- with by consuming the bytes still owed, see hash_feeder.
entity hash_engine_top is
    port (
        clk   : in    std_logic;
        reset : in    std_logic;

        -- Axilite interface
        axi_if : view axil_target;

        -- Flash read command FIFO: word 0 is a byte address, word 1 a byte count
        cmd_fifo_wdata : out   std_logic_vector(31 downto 0);
        cmd_fifo_write : out   std_logic;

        -- Flash read response FIFO, showahead so rdack is a read acknowledge
        rsp_fifo_rdata  : in    std_logic_vector(7 downto 0);
        rsp_fifo_rdack  : out   std_logic;
        rsp_fifo_rempty : in    std_logic
    );
end entity;

architecture rtl of hash_engine_top is

    -- 64 words of 32 bits, ie 256 bytes, matching the spi_nor TX FIFO
    constant SW_FIFO_DEPTH : integer := 64;

    signal start_strobe : std_logic;
    signal abort_strobe : std_logic;

    signal cfg        : config_type;
    signal prepend    : prepend_type;
    signal flash_addr : flash_addr_type;
    signal msg_length : length_type;

    signal status   : status_type;
    signal progress : progress_type;

    signal sw_fifo_wdata  : std_logic_vector(31 downto 0);
    signal sw_fifo_write  : std_logic;
    signal sw_fifo_rdata  : std_logic_vector(7 downto 0);
    signal sw_fifo_rdack  : std_logic;
    signal sw_fifo_rempty : std_logic;
    signal sw_fifo_wfull  : std_logic;
    signal sw_fifo_reset  : std_logic;

    signal sw_clear : std_logic;

    signal sha3_init    : std_logic;
    signal msg_stream   : axi_st8_pkg.axi_st_pkt_t;
    signal digest       : digest_t;
    signal digest_valid : std_logic;

begin

    hash_engine_regs_inst: entity work.hash_engine_regs
        port map (
            clk              => clk,
            reset            => reset,
            axi_if           => axi_if,
            start_strobe     => start_strobe,
            abort_strobe     => abort_strobe,
            cfg              => cfg,
            prepend          => prepend,
            flash_addr       => flash_addr,
            msg_length       => msg_length,
            status           => status,
            progress         => progress,
            digest           => digest,
            wdata_fifo_wdata => sw_fifo_wdata,
            wdata_fifo_write => sw_fifo_write
        );

    -- Software data path. Written 32 bits at a time by the processor and read a
    -- byte at a time by the feeder, least significant byte first.
    sw_fifo_reset <= reset or sw_clear;

    sw_data_fifo: entity work.dcfifo_mixed_xpm
        generic map (
            wfifo_write_depth => SW_FIFO_DEPTH,
            wdata_width       => 32,
            rdata_width       => 8,
            showahead_mode    => true
        )
        port map (
            wclk     => clk,
            reset    => sw_fifo_reset,
            write_en => sw_fifo_write,
            wdata    => sw_fifo_wdata,
            wfull    => sw_fifo_wfull,
            wusedwds => open,
            rclk     => clk,
            rdata    => sw_fifo_rdata,
            rdreq    => sw_fifo_rdack,
            rempty   => sw_fifo_rempty,
            rusedwds => open
        );

    hash_feeder_inst: entity work.hash_feeder
        port map (
            clk             => clk,
            reset           => reset,
            start_strobe    => start_strobe,
            abort_strobe    => abort_strobe,
            cfg             => cfg,
            prepend         => prepend,
            flash_addr      => flash_addr,
            msg_length      => msg_length,
            busy            => status.busy,
            done            => status.done,
            aborted         => status.aborted,
            cfg_err         => status.cfg_err,
            bytes_fed       => progress.bytes,
            sha3_init       => sha3_init,
            msg_if          => msg_stream,
            digest_valid    => digest_valid,
            sw_fifo_rdata   => sw_fifo_rdata,
            sw_fifo_rdack   => sw_fifo_rdack,
            sw_fifo_rempty  => sw_fifo_rempty,
            sw_fifo_clear   => sw_clear,
            cmd_fifo_wdata  => cmd_fifo_wdata,
            cmd_fifo_write  => cmd_fifo_write,
            rsp_fifo_rdata  => rsp_fifo_rdata,
            rsp_fifo_rdack  => rsp_fifo_rdack,
            rsp_fifo_rempty => rsp_fifo_rempty
        );

    -- Also report full while the FIFO is being flushed at the tail of a run, so a
    -- processor that polls before writing cannot push bytes into a FIFO that is in
    -- reset. The flush only happens when a run ends, never as one starts, which is
    -- what keeps this from racing with software. See hash_feeder.
    status.wfifo_full  <= sw_fifo_wfull or sw_clear;
    status.wfifo_empty <= sw_fifo_rempty;

    -- Single buffered on purpose. Quad rate flash delivers roughly a byte every
    -- eight clocks and the register path is slower still, so the core's 25 cycle
    -- permutation always hides inside the gap between bytes. The second 1088 bit
    -- block register would be dead area here.
    sha3_256_inst: entity work.sha3_256
        generic map (
            DOUBLE_BUFFER => false
        )
        port map (
            clk          => clk,
            reset        => reset,
            init         => sha3_init,
            busy         => open,
            msg_if       => msg_stream,
            digest       => digest,
            digest_valid => digest_valid
        );

end rtl;
