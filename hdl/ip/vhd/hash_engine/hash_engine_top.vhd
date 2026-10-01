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
--
-- Besides the register interface there is a hardware request: a sequencer can
-- raise hw_req to have a flash range (HW_FLASH_ADDR/HW_LENGTH, on the flash
-- HW_FLASH_SEL names) hashed without software in the loop, and gets hw_ack
-- back once the run is over, with hw_err saying whether it produced a digest.
-- The digest is kept in its own registers so that a later software run does
-- not overwrite it. A request that lands while a software run is in flight is
-- refused rather than restarting the run; software starts that land while a
-- hardware run is in flight are dropped. Four-phase: the requester holds
-- hw_req until it sees hw_ack, and hw_ack drops once hw_req does.
entity hash_engine_top is
    generic (
        -- How many spi_nor flash clients hang off this engine. CONFIG.source
        -- picks between them for a run; AUX_QSPI is a configuration error
        -- when there is only one.
        NUM_FLASHES : natural range 1 to 2 := 1;
        -- Which flash a hardware request reads: 0 the host flash, 1 the aux
        -- flash (which needs NUM_FLASHES = 2).
        HW_FLASH_SEL : natural range 0 to 1 := 0
    );
    port (
        clk   : in    std_logic;
        reset : in    std_logic;

        -- Axilite interface
        axi_if : view axil_target;

        -- Hardware request, see above. Leave hw_req unconnected on a design
        -- without a requester.
        hw_req : in    std_logic := '0';
        hw_ack : out   std_logic;
        hw_err : out   std_logic;

        -- The spi_nor side of the engine's own command and response FIFOs, one
        -- pair per flash. These match spi_nor_top's hash client port shape:
        -- the flash pops commands (word 0 a byte address, word 1 a byte count)
        -- and pushes response bytes. Only the flash selected for the run in
        -- flight ever sees a non-empty command FIFO, so the others sit idle.
        flash_cmd_rdata  : out   std_logic_vector(31 downto 0);
        flash_cmd_rdack  : in    std_logic_vector(NUM_FLASHES - 1 downto 0);
        flash_cmd_rempty : out   std_logic_vector(NUM_FLASHES - 1 downto 0);
        flash_rsp_wdata  : in    std_logic_vector(NUM_FLASHES * 8 - 1 downto 0);
        flash_rsp_write  : in    std_logic_vector(NUM_FLASHES - 1 downto 0);
        -- Backpressure for clients that honour it. spi_nor_top does not (its
        -- raw_flash_txn_mgr paces itself off the SPI link), but a behavioural
        -- responder in simulation can push a byte a cycle and needs it.
        flash_rsp_wfull  : out   std_logic_vector(NUM_FLASHES - 1 downto 0)
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

    -- What the feeder actually sees: the software registers, or the hardware
    -- request's configuration while one of those is in flight.
    signal feeder_start      : std_logic;
    signal feeder_cfg        : config_type;
    signal feeder_prepend    : prepend_type;
    signal feeder_flash_addr : flash_addr_type;
    signal feeder_length     : length_type;

    signal hw_flash_addr : hw_flash_addr_type;
    signal hw_length     : hw_length_type;
    signal hw_status     : hw_status_type;
    signal hw_digest     : std_logic_vector(255 downto 0);

    type hw_state_t is (idle, starting, running, acked);
    type hw_reg_t is record
        state   : hw_state_t;
        start   : std_logic;
        active  : std_logic;
        ack     : std_logic;
        err     : std_logic;
        settle  : natural range 0 to 3;
        status  : hw_status_type;
        digest  : std_logic_vector(255 downto 0);
    end record;
    constant hw_reg_reset : hw_reg_t := (
        state => idle, start => '0', active => '0', ack => '0', err => '0',
        settle => 0, status => rec_reset, digest => (others => '0')
    );
    signal hw_r : hw_reg_t;

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

    -- Feeder side of the flash client FIFOs
    signal cmd_fifo_wdata  : std_logic_vector(31 downto 0);
    signal cmd_fifo_write  : std_logic;
    signal cmd_fifo_rdack  : std_logic;
    signal cmd_fifo_rempty : std_logic;
    signal rsp_fifo_wdata  : std_logic_vector(7 downto 0);
    signal rsp_fifo_write  : std_logic;
    signal rsp_fifo_rdata  : std_logic_vector(7 downto 0);
    signal rsp_fifo_rdack  : std_logic;
    signal rsp_fifo_rempty : std_logic;
    signal rsp_fifo_wfull  : std_logic;
    -- Which flash the run in flight is reading, latched by the feeder at start
    signal flash_sel : natural range 0 to NUM_FLASHES - 1;

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
            hw_flash_addr    => hw_flash_addr,
            hw_length        => hw_length,
            hw_status        => hw_status,
            hw_digest        => hw_digest,
            wdata_fifo_wdata => sw_fifo_wdata,
            wdata_fifo_write => sw_fifo_write
        );

    -- Hardware request sequencing. The feeder latches its configuration on the
    -- cycle it accepts a start, so the mux below only has to hold for as long as
    -- the request is active, which it does.
    feeder_start <= hw_r.start when hw_r.active = '1' else start_strobe;
    feeder_cfg <= (source => AUX_QSPI) when hw_r.active = '1' and HW_FLASH_SEL = 1 else
                  (source => HOST_QSPI) when hw_r.active = '1' else
                  cfg;
    feeder_prepend <= (count => (others => '0')) when hw_r.active = '1' else prepend;
    feeder_flash_addr <= (addr => hw_flash_addr.addr) when hw_r.active = '1' else flash_addr;
    feeder_length <= (count => hw_length.count) when hw_r.active = '1' else msg_length;

    hw_ack <= hw_r.ack;
    hw_err <= hw_r.err;
    hw_status <= hw_r.status;
    hw_digest <= hw_r.digest;

    hw_request: process(clk, reset)
    begin
        if reset then
            hw_r <= hw_reg_reset;
        elsif rising_edge(clk) then
            hw_r.start <= '0';
            case hw_r.state is
                when idle =>
                    if hw_req = '1' then
                        hw_r.status <= rec_reset;
                        hw_r.err <= '0';
                        if status.busy = '1' then
                            -- A software run owns the engine; do not restart
                            -- it out from under whoever started it.
                            hw_r.status.engine_busy <= '1';
                            hw_r.err <= '1';
                            hw_r.ack <= '1';
                            hw_r.state <= acked;
                        else
                            hw_r.active <= '1';
                            hw_r.start <= '1';
                            hw_r.status.busy <= '1';
                            hw_r.settle <= 0;
                            hw_r.state <= starting;
                        end if;
                    end if;
                when starting =>
                    -- The feeder answers a start two cycles later, with either
                    -- busy or cfg_err. Neither is ours to look at before then.
                    if hw_r.settle = 2 then
                        hw_r.state <= running;
                    else
                        hw_r.settle <= hw_r.settle + 1;
                    end if;
                when running =>
                    if status.cfg_err = '1' or status.aborted = '1' or
                       (status.busy = '0' and status.done = '1') then
                        hw_r.status.busy <= '0';
                        hw_r.status.cfg_err <= status.cfg_err;
                        hw_r.status.aborted <= status.aborted;
                        hw_r.status.done <= status.done and not status.aborted;
                        hw_r.err <= status.cfg_err or status.aborted;
                        if status.done = '1' and status.aborted = '0' then
                            hw_r.digest <= digest;
                        end if;
                        hw_r.active <= '0';
                        hw_r.ack <= '1';
                        hw_r.state <= acked;
                    end if;
                when acked =>
                    if hw_req = '0' then
                        hw_r.ack <= '0';
                        hw_r.state <= idle;
                    end if;
            end case;
        end if;
    end process;

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
        generic map (
            NUM_FLASHES => NUM_FLASHES
        )
        port map (
            clk             => clk,
            reset           => reset,
            start_strobe    => feeder_start,
            abort_strobe    => abort_strobe,
            cfg             => feeder_cfg,
            prepend         => feeder_prepend,
            flash_addr      => feeder_flash_addr,
            msg_length      => feeder_length,
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
            flash_sel       => flash_sel,
            cmd_fifo_wdata  => cmd_fifo_wdata,
            cmd_fifo_write  => cmd_fifo_write,
            rsp_fifo_rdata  => rsp_fifo_rdata,
            rsp_fifo_rdack  => rsp_fifo_rdack,
            rsp_fifo_rempty => rsp_fifo_rempty
        );

    -- Flash client FIFOs. One pair serves every flash: the selected flash is
    -- the only one shown a non-empty command FIFO and the only one whose
    -- response writes are taken, so the FIFOs never see two clients at once.
    -- flash_sel holds still for the whole run, which is what lets this be a
    -- plain mux rather than an arbiter.
    cmd_fifo: entity work.dcfifo_xpm
        generic map (
            fifo_write_depth => 256,
            data_width       => 32,
            showahead_mode   => true
        )
        port map (
            wclk     => clk,
            reset    => reset,
            write_en => cmd_fifo_write,
            wdata    => cmd_fifo_wdata,
            wfull    => open,
            wusedwds => open,
            rclk     => clk,
            rdata    => flash_cmd_rdata,
            rdreq    => cmd_fifo_rdack,
            rempty   => cmd_fifo_rempty,
            rusedwds => open
        );

    rsp_fifo: entity work.dcfifo_xpm
        generic map (
            fifo_write_depth => 256,
            data_width       => 8,
            showahead_mode   => true
        )
        port map (
            wclk     => clk,
            reset    => reset,
            write_en => rsp_fifo_write,
            wdata    => rsp_fifo_wdata,
            wfull    => rsp_fifo_wfull,
            wusedwds => open,
            rclk     => clk,
            rdata    => rsp_fifo_rdata,
            rdreq    => rsp_fifo_rdack,
            rempty   => rsp_fifo_rempty,
            rusedwds => open
        );

    flash_mux: process(all)
    begin
        cmd_fifo_rdack <= flash_cmd_rdack(flash_sel);
        rsp_fifo_wdata <= flash_rsp_wdata(flash_sel * 8 + 7 downto flash_sel * 8);
        rsp_fifo_write <= flash_rsp_write(flash_sel);
        flash_rsp_wfull <= (others => rsp_fifo_wfull);
        for i in 0 to NUM_FLASHES - 1 loop
            if i = flash_sel then
                flash_cmd_rempty(i) <= cmd_fifo_rempty;
            else
                flash_cmd_rempty(i) <= '1';
            end if;
        end loop;
    end process;

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
