-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- GTY transceiver wrapper for the SGMII line side. Drives the Vivado GT wizard
-- core (gtwizard_sgmii) and presents the soft PCS a clean interface: comma-
-- aligned 10-bit code groups in a single 125 MHz user-clock domain.
--
-- The generated core (see xilinx_ip_gen/gtwizard_sgmii_ip.tcl) is a 2-channel,
-- QPLL0, raw 20-bit core with an in-core reset controller and an EXTERNAL user
-- clocking network. This wrapper therefore:
--   * buffers the GT refclk (IBUFDS_GTE4) to both commons, and derives an
--     always-on 62.5 MHz free-run clock (ODIV2 + BUFG_GT) for the reset FSM and
--     the project MMCM,
--   * builds the GT user clock from txoutclk (BUFG_GT) and feeds it to tx/rx
--     usrclk(2) -- the RX buffer lets rx run in the tx user-clock domain (valid
--     with a shared refclk, e.g. loopback / a same-refclk partner; add clock
--     correction for an independent-ppm partner),
--   * doubles that 62.5 MHz to the 125 MHz PCS clock (usrclk_mmcm) and gears
--     20b@62.5 <-> 10b@125 with comma bit-slip (sgmii_gearbox).
--
-- Data uses channel 0; the second enabled channel is tied off. Confirm channel 0
-- is the SMA lane on this device/package (else swap the channel indices below).

library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

entity sgmii_gt is
    port (
        -- GT reference clock (differential); onboard 125 MHz, MGTREFCLK0_226
        mgtrefclk_p : in    std_logic;
        mgtrefclk_n : in    std_logic;

        -- serial line side
        gt_rxp : in    std_logic;
        gt_rxn : in    std_logic;
        gt_txp : out   std_logic;
        gt_txn : out   std_logic;

        reset : in    std_logic;

        -- serial polarity inversion controls (P/N swap correction); live over VIO
        invert_rx : in    std_logic;
        invert_tx : in    std_logic;

        -- GTY TX driver equalization (swept live over VIO): differential swing +
        -- pre/post-cursor de-emphasis, driven to the GT's txdiffctrl/txprecursor/
        -- txpostcursor ports.
        tx_diffctrl   : in    std_logic_vector(4 downto 0);
        tx_precursor  : in    std_logic_vector(4 downto 0);
        tx_postcursor : in    std_logic_vector(4 downto 0);

        -- always-on clock derived from the refclk (for the project MMCM)
        freerun_clk : out   std_logic;

        -- user-domain interface to the soft PCS
        usrclk        : out   std_logic;
        rx_code       : out   std_logic_vector(9 downto 0);
        rx_code_valid : out   std_logic;
        tx_code       : in    std_logic_vector(9 downto 0);

        gt_ready : out   std_logic;

        -- GT RX status (for debug): GT byte-aligned, gearbox aligned, elastic-
        -- buffer status, clock-correction count
        rx_byteisaligned : out   std_logic;
        gb_aligned       : out   std_logic;
        rx_bufstatus     : out   std_logic_vector(2 downto 0);
        rx_clkcorcnt     : out   std_logic_vector(1 downto 0);
        dbg_gt_word      : out   std_logic_vector(19 downto 0)  -- raw GT word
    );
end entity;

architecture rtl of sgmii_gt is

    -- No generic map is used, so the component declares no generics (Vivado binds
    -- to the UNISIM defaults). ODIV2 provides the refclk-derived free-run clock.
    component ibufds_gte4 is
        port (
            o     : out   std_ulogic;
            odiv2 : out   std_ulogic;
            ceb   : in    std_ulogic;
            i     : in    std_ulogic;
            ib    : in    std_ulogic
        );
    end component;

    component bufg_gt is
        port (
            o       : out   std_ulogic;
            ce      : in    std_ulogic;
            cemask  : in    std_ulogic;
            clr     : in    std_ulogic;
            clrmask : in    std_ulogic;
            div     : in    std_logic_vector(2 downto 0);
            i       : in    std_ulogic
        );
    end component;

    signal gtrefclk    : std_logic;
    signal gtrefclk_d2 : std_logic;
    signal freerun_i   : std_logic;

    signal gtclk       : std_logic;    -- 62.5 MHz GT user clock
    signal clk125      : std_logic;    -- 125 MHz PCS clock
    signal mmcm_locked : std_logic;

    -- GT reset controller status
    signal tx_done_v : std_logic_vector(0 downto 0);
    signal rx_done_v : std_logic_vector(0 downto 0);
    signal tx_done   : std_logic;
    signal rx_done   : std_logic;

    -- user-clock network
    signal txoutclk_v   : std_logic_vector(0 downto 0);
    signal uclk_active  : std_logic := '0';
    signal uclk_meta    : std_logic := '0';

    -- 20-bit raw datapath (single channel)
    signal gt_rx20 : std_logic_vector(19 downto 0);   -- straight from the GT
    signal gt_tx20 : std_logic_vector(19 downto 0);   -- from the gearbox
    signal gt_rx20_corr : std_logic_vector(19 downto 0);   -- polarity-corrected RX
    signal gt_tx20_corr : std_logic_vector(19 downto 0);   -- polarity-corrected TX

    -- gearbox
    signal word_stb : std_logic;
    signal gb_align : std_logic;
    signal gb_reset : std_logic;

    signal rxaligned_v : std_logic_vector(0 downto 0);

    -- gtclk-domain toggle -> word strobe in the clk125 domain
    signal tog   : std_logic := '0';
    signal tog_m : std_logic := '0';
    signal tog_s : std_logic := '0';

    signal ready : std_logic;

begin

    usrclk        <= clk125;
    freerun_clk   <= freerun_i;
    tx_done       <= tx_done_v(0);
    rx_done       <= rx_done_v(0);
    ready         <= tx_done and rx_done and mmcm_locked and gb_align;
    gt_ready      <= ready;
    rx_code_valid <= ready;
    rx_byteisaligned <= rxaligned_v(0);
    gb_aligned       <= gb_align;

    gb_reset <= not (mmcm_locked and tx_done and rx_done);

    -- optional serial polarity inversion (P/N swap correction), done in fabric
    gt_rx20_corr <= not gt_rx20 when invert_rx = '1' else gt_rx20;
    gt_tx20_corr <= not gt_tx20 when invert_tx = '1' else gt_tx20;

    -- refclk input buffer: O drives the GT commons, ODIV2 the free-run path
    refclk_ibuf: component ibufds_gte4
        port map (
            o     => gtrefclk,
            odiv2 => gtrefclk_d2,
            ceb   => '0',
            i     => mgtrefclk_p,
            ib    => mgtrefclk_n
        );

    freerun_bufg: component bufg_gt
        port map (
            o       => freerun_i,
            ce      => '1',
            cemask  => '0',
            clr     => '0',
            clrmask => '0',
            div     => "000",
            i       => gtrefclk_d2
        );

    -- GT user clock from txoutclk (62.5 MHz)
    usrclk_bufg: component bufg_gt
        port map (
            o       => gtclk,
            ce      => '1',
            cemask  => '0',
            clr     => '0',
            clrmask => '0',
            div     => "000",
            i       => txoutclk_v(0)
        );

    -- user-clock-active: high once the GT user clock is running
    active_gen: process (gtclk, reset) is
    begin
        if reset = '1' then
            uclk_meta   <= '0';
            uclk_active <= '0';
        elsif rising_edge(gtclk) then
            uclk_meta   <= '1';
            uclk_active <= uclk_meta;
        end if;
    end process;

    gt_i: entity work.gtwizard_sgmii
        port map (
            gtwiz_userclk_tx_active_in         => (0 => uclk_active),
            gtwiz_userclk_rx_active_in         => (0 => uclk_active),
            gtwiz_reset_clk_freerun_in         => (0 => freerun_i),
            gtwiz_reset_all_in                 => (0 => reset),
            gtwiz_reset_tx_pll_and_datapath_in => (0 => '0'),
            gtwiz_reset_tx_datapath_in         => (0 => '0'),
            gtwiz_reset_rx_pll_and_datapath_in => (0 => '0'),
            gtwiz_reset_rx_datapath_in         => (0 => '0'),
            gtwiz_reset_rx_cdr_stable_out      => open,
            gtwiz_reset_tx_done_out            => tx_done_v,
            gtwiz_reset_rx_done_out            => rx_done_v,
            gtwiz_userdata_tx_in               => gt_tx20_corr,
            gtwiz_userdata_rx_out              => gt_rx20,
            txdiffctrl_in                      => tx_diffctrl,
            txprecursor_in                     => tx_precursor,
            txpostcursor_in                    => tx_postcursor,
            gtrefclk00_in                      => (0 => gtrefclk),
            qpll0outclk_out                    => open,
            qpll0outrefclk_out                 => open,
            gtyrxn_in                          => (0 => gt_rxn),
            gtyrxp_in                          => (0 => gt_rxp),
            rxbufreset_in                      => (0 => '0'),
            rxcommadeten_in                    => (0 => '1'),   -- comma detect on
            rxmcommaalignen_in                 => (0 => '1'),   -- align on K28.5-
            rxpcommaalignen_in                 => (0 => '1'),   -- align on K28.5+
            rxusrclk_in                        => (0 => gtclk),
            rxusrclk2_in                       => (0 => gtclk),
            txusrclk_in                        => (0 => gtclk),
            txusrclk2_in                       => (0 => gtclk),
            gtpowergood_out                    => open,
            gtytxn_out(0)                      => gt_txn,
            gtytxp_out(0)                      => gt_txp,
            rxbufstatus_out                    => rx_bufstatus,
            rxbyteisaligned_out                => rxaligned_v,
            rxbyterealign_out                  => open,
            rxclkcorcnt_out                    => rx_clkcorcnt,
            rxcommadet_out                     => open,
            rxoutclk_out                       => open,
            rxpmaresetdone_out                 => open,
            txoutclk_out                       => txoutclk_v,
            txpmaresetdone_out                 => open
        );

    -- 62.5 MHz GT user clock -> 125 MHz PCS clock (phase-aligned)
    mmcm_i: entity work.usrclk_mmcm
        port map (
            clk_in   => gtclk,
            clk_125m => clk125,
            reset    => not tx_done,
            locked   => mmcm_locked
        );

    -- word strobe: the GT clock toggles `tog`; edge-detect it in the 125 MHz
    -- domain to mark the start of each 20-bit word (once every two clk125).
    tog_gt: process (gtclk) is
    begin
        if rising_edge(gtclk) then
            tog <= not tog;
        end if;
    end process;

    word_gen: process (clk125) is
    begin
        if rising_edge(clk125) then
            tog_m    <= tog;
            tog_s    <= tog_m;
            word_stb <= tog_m xor tog_s;
        end if;
    end process;

    gearbox_i: entity work.sgmii_gearbox
        port map (
            clk        => clk125,
            reset      => gb_reset,
            word_stb   => word_stb,
            gt_rx_data => gt_rx20_corr,
            gt_tx_data => gt_tx20,
            rx_code    => rx_code,
            rx_aligned => gb_align,
            tx_code    => tx_code,
            dbg_word   => dbg_gt_word
        );

end architecture;
