-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.sp5_power_pkg.all;
use work.sequencer_io_pkg.all;
use work.sequencer_regs_pkg.all;

-- A0HP sequencing and boot supervision for the AMD Versal Premium VP1202 that
-- serves as Metro's NIC. This is the metro-specific counterpart to cosmo_seq's
-- nic_seq: same shape and the same register-driven override story, but a
-- Versal wants a staged rail bring-up followed by a strapped boot rather than
-- the T6's cld_rst/perst dance.
--
-- The rails come up in the seven groups the board's Versal power sequence
-- calls for. Each group is enabled GROUP_DELAY_MS after the one before it
-- reports power good, and they are taken down in the reverse order with the
-- same spacing, whether that is software asking or a fault:
--
--   1. V3P3, V1P8
--   2. V0P88
--   3. V0P8 VCCINT
--   4. V1P5 VCCAUX
--   5. V0P92 GTM/GTY AVCC
--   6. V1P5 AVCCAUX
--   7. V1P2 GTM/GTY AVTT
--
-- The settle and strap delays are conservative placeholders and MUST be
-- confirmed against the VP1202 datasheet before hardware bring-up; they are
-- gathered into the constants below so that is a one-line change.
entity versal_seq is
    generic(
        CNTS_P_MS: integer;
        -- Spacing between rail groups, both on the way up and on the way down
        GROUP_DELAY_MS : integer := 4
    );
    port(
        clk : in std_logic;
        reset : in std_logic;

        sw_enable : in std_logic;
        upstream_ok : in std_logic;
        versal_idle : out std_logic;
        versal_faulted : out std_logic;
        debug_enables : in debug_enables_type;
        versal_overrides_reg : in versal_overrides_type;
        -- Self-clearing test MAPO, shared with the T6 flavour's register
        nic_test_mapo : in std_logic;
        boot_ctrl : in versal_boot_ctrl_type;

        raw_state : out nic_raw_status_type;
        api_state : out nic_api_status_type;

        versal_dbg_pins : view nic_debug_seq_ss;

        -- From SP5 hotplug, one per PCIe channel. Each follows its slot's
        -- power enable exactly, as the T6's did on cosmo: perst_l <= power_en.
        -- The Versal is one device behind two slots, so power itself is not
        -- per channel; only the resets are.
        sp5_versal_cha_perst_l : in std_logic;
        sp5_versal_chb_perst_l : in std_logic;

        -- True while the Versal is held in reset and not about to be let out
        -- of it, i.e. while it is safe for the SP to take the Versal's boot
        -- flash away from it through the mux.
        versal_held_in_reset : out std_logic;
        -- True while the sequencer itself wants the boot flash on the FPGA
        -- side of the mux: for the pre-boot measurement, and once the Versal
        -- has booted so the SP5 can reach the flash over eSPI.
        flash_owned_by_seq : out std_logic;

        -- Hash engine hardware request, see hash_engine_top. Held until
        -- acknowledged; hash_err is valid with the acknowledge.
        hash_req : out std_logic;
        hash_ack : in std_logic;
        hash_err : in std_logic;
        -- Outcome of the measurement for the current or last boot
        hash_done : out std_logic;
        hash_failed : out std_logic;

        versal_rails : view versal_power_at_fpga;
        versal_boot : view versal_boot_at_fpga;
        versal_pcie : view versal_pcie_at_fpga
    );
end entity;

architecture rtl of versal_seq is
    constant ONE_MS : integer := 1 * CNTS_P_MS;
    constant TEN_MS : integer := 10 * ONE_MS;
    constant TWENTY_MS : integer := 20 * ONE_MS;
    constant GROUP_DELAY : integer := GROUP_DELAY_MS * ONE_MS;
    -- How long the rails must be stable before POR_B is released.
    constant RAIL_SETTLE_MS : integer := 20 * ONE_MS;
    -- How long MODE[3:0] must be stable before POR_B is released.
    constant MODE_SETUP_MS : integer := 1 * ONE_MS;
    -- How long to wait for DONE before calling the boot failed. Versal images
    -- are large and come off QSPI, so this is generous on purpose.
    constant DONE_TIMEOUT_MS : integer := 5000 * ONE_MS;

    constant NUM_GROUPS : integer := 7;
    subtype group_t is integer range 1 to NUM_GROUPS;

    -- The transceiver rails have no enable of their own, only a power good
    -- shared between the GTM and GTY supplies. They are taken to be regulated
    -- down from the rails that have an enable and no power good: V0P92 AVCC
    -- from V1P1 and V1P2 AVTT from V1P4. So a transceiver group is its
    -- upstream rail's enable and the transceiver rail's power good.
    function group_good(rails : versal_power_t; grp : group_t) return boolean is
    begin
        case grp is
            when 1 => return (rails.v3p3.pg and rails.v1p8.pg) = '1';
            when 2 => return rails.v0p88.pg = '1';
            when 3 => return rails.v0p8_vccint.pg = '1';
            when 4 => return rails.v1p5.pg = '1';
            when 5 => return (rails.v1p1.pg and rails.v0p92_avcc.pg) = '1';
            when 6 => return rails.v1p5_avccaux.pg = '1';
            when 7 => return (rails.v1p4.pg and rails.v1p2_avtt.pg) = '1';
        end case;
    end function;

    type versal_r_t is record
        state : nic_raw_status_hw_sm;
        enable_last : std_logic;
        enable_pend : std_logic;
        cnts : unsigned(31 downto 0);
        cha_perst_l_last : std_logic;
        chb_perst_l_last : std_logic;
        hsc_en : std_logic;
        group_en : std_logic_vector(1 to NUM_GROUPS);
        por_b : std_logic;
        mode : std_logic_vector(3 downto 0);
        mode_buffer_en_l : std_logic;
        err_done_buff_en : std_logic;
        clk_buff_oe_l : std_logic;
        rails_expected : std_logic;
        faulted : std_logic;
        boot_failed : std_logic;
        hash_req : std_logic;
        hash_done : std_logic;
        hash_failed : std_logic;
    end record;

    constant versal_r_reset : versal_r_t := (
        state => IDLE,
        enable_last => '0',
        enable_pend => '0',
        cnts => (others => '0'),
        cha_perst_l_last => '0',
        chb_perst_l_last => '0',
        hsc_en => '0',
        group_en => (others => '0'),
        por_b => '0',
        mode => (others => '0'),
        mode_buffer_en_l => '1',
        err_done_buff_en => '0',
        clk_buff_oe_l => '1',
        rails_expected => '0',
        faulted => '0',
        boot_failed => '0',
        hash_req => '0',
        hash_done => '0',
        hash_failed => '0'
    );
    signal r, rin : versal_r_t;

    -- PCIe resets follow the SP5's slot power enables once the Versal has
    -- booted, exactly as the T6's did on cosmo, one per channel.
    signal cha_perst_l : std_logic;
    signal chb_perst_l : std_logic;
    signal final_outs : versal_overrides_type;

begin

    raw_state.hw_sm <= r.state;
    versal_idle <= '1' when r.state = IDLE else '0';
    versal_faulted <= r.faulted;
    -- POR_B low means the Versal is held off its boot flash, so the SP may
    -- safely steal the QSPI mux. Not during MODE_STRAP though: that is the
    -- last stop before POR_B releases, and a grant given there would still be
    -- in force when it does.
    versal_held_in_reset <= '1' when r.por_b = '0' and r.state /= MODE_STRAP else '0';
    -- The sequencer's own claims on the flash: measuring it, and after boot,
    -- when the Versal has finished with it and the SP5 gets it over eSPI.
    flash_owned_by_seq <= '1' when r.state = HASH_IMAGE or r.state = HASH_RELEASE or
                                   r.state = DONE else '0';
    hash_req <= r.hash_req;
    hash_done <= r.hash_done;
    hash_failed <= r.hash_failed;

    -- Debug header taps, on header pins 5..0 in this order
    versal_dbg_pins.rails_en <= r.group_en(NUM_GROUPS);
    versal_dbg_pins.rails_pg <= '1' when is_power_good(versal_rails) else '0';
    versal_dbg_pins.taps(5) <= final_outs.por_b;
    versal_dbg_pins.taps(4) <= final_outs.cha_perst_l;
    versal_dbg_pins.taps(3) <= versal_boot.done;
    versal_dbg_pins.taps(2) <= versal_boot.error_out;
    versal_dbg_pins.taps(1) <= r.mode(0);
    versal_dbg_pins.taps(0) <= final_outs.chb_perst_l;

    api_state_proc: process(clk, reset)
    begin
        if reset then
            api_state.nic_sm <= IDLE;
        elsif rising_edge(clk) then
            case r.state is
                when IDLE =>
                    api_state.nic_sm <= IDLE;
                when HSC_EN | IO_EN | V0P88_EN | VCCINT_EN | VCCAUX_EN |
                     GT_AVCC_EN | AVCCAUX_EN | GT_AVTT_EN =>
                    api_state.nic_sm <= ENABLE_POWER;
                when POWER_DOWN =>
                    api_state.nic_sm <= DISABLE_POWER;
                when RAILS_SETTLE | MODE_STRAP =>
                    api_state.nic_sm <= NIC_RESET;
                when HASH_IMAGE | HASH_RELEASE =>
                    api_state.nic_sm <= MEASURING;
                when POR_RELEASE | WAIT_DONE =>
                    api_state.nic_sm <= BOOTING;
                when DONE =>
                    api_state.nic_sm <= DONE;
                            -- the T6 states; this NIC never has them
                when others => null;
            end case;
        end if;
    end process;

    versal_sm: process(all)
        variable v : versal_r_t;
        variable rails_faulted : std_logic;
        variable enable : std_logic;
    begin
        v := r;
        -- The inhibit takes the enable away from this sequencer only, so A0
        -- can be brought up and held without A0HP following it.
        enable := sw_enable and not debug_enables.a0hp_inhibit;
        v.cha_perst_l_last := sp5_versal_cha_perst_l;
        v.chb_perst_l_last := sp5_versal_chb_perst_l;

        -- Once we expect the rails to be up, any of them dropping is a fault.
        rails_faulted := '1' when r.rails_expected = '1' and
                                  (not is_power_good(versal_rails)) else '0';

        v.enable_last := enable;
        if (enable and not r.enable_last) = '1' or
           (r.faulted = '1' and debug_enables.a0hp_inhibit = '0' and
            r.cha_perst_l_last = '0' and sp5_versal_cha_perst_l = '1') or
           (r.faulted = '1' and debug_enables.a0hp_inhibit = '0' and
            r.chb_perst_l_last = '0' and sp5_versal_chb_perst_l = '1') then
            -- Same two re-enable paths cosmo's nic_seq has: software toggling
            -- the enable, or -- after a MAPO, where the SP5 owns slot power --
            -- the SP5 de-asserting PERST for a fresh attempt. Either slot
            -- coming back is enough; there is only the one device to bring up.
            v.enable_pend := '1';
            v.faulted := '0';
            v.boot_failed := '0';
        end if;
        -- An enable that was taken but not yet acted on, waiting in IDLE for
        -- upstream, must not outlive the inhibit being set.
        if debug_enables.a0hp_inhibit then
            v.enable_pend := '0';
        end if;

        case r.state is
            when IDLE =>
                v.hsc_en := '0';
                v.group_en := (others => '0');
                v.por_b := '0';
                v.mode_buffer_en_l := '1';
                v.err_done_buff_en := '0';
                v.clk_buff_oe_l := '1';
                v.rails_expected := '0';
                v.hash_req := '0';
                v.cnts := (others => '0');
                if r.enable_pend and upstream_ok then
                    v.state := HSC_EN;
                    v.enable_pend := '0';
                    v.hash_done := '0';
                    v.hash_failed := '0';
                end if;

            when HSC_EN =>
                -- Nothing downstream reports a valid power good until the
                -- hotswaps are on, so this stage waits on them alone.
                v.hsc_en := '1';
                v.cnts := (others => '0');
                if (versal_rails.hsc_12v.pg and versal_rails.hsc_5v.pg) = '1' then
                    v.state := IO_EN;
                end if;

            when IO_EN =>
                v.group_en(1) := '1';
                v.cnts := (others => '0');
                if group_good(versal_rails, 1) then
                    v.cnts := r.cnts + 1;
                end if;
                if r.cnts = GROUP_DELAY then
                    v.cnts := (others => '0');
                    v.state := V0P88_EN;
                end if;

            when V0P88_EN =>
                v.group_en(2) := '1';
                v.cnts := (others => '0');
                if group_good(versal_rails, 2) then
                    v.cnts := r.cnts + 1;
                end if;
                if r.cnts = GROUP_DELAY then
                    v.cnts := (others => '0');
                    v.state := VCCINT_EN;
                end if;

            when VCCINT_EN =>
                v.group_en(3) := '1';
                v.cnts := (others => '0');
                if group_good(versal_rails, 3) then
                    v.cnts := r.cnts + 1;
                end if;
                if r.cnts = GROUP_DELAY then
                    v.cnts := (others => '0');
                    v.state := VCCAUX_EN;
                end if;

            when VCCAUX_EN =>
                v.group_en(4) := '1';
                v.cnts := (others => '0');
                if group_good(versal_rails, 4) then
                    v.cnts := r.cnts + 1;
                end if;
                if r.cnts = GROUP_DELAY then
                    v.cnts := (others => '0');
                    v.state := GT_AVCC_EN;
                end if;

            when GT_AVCC_EN =>
                v.group_en(5) := '1';
                v.cnts := (others => '0');
                if group_good(versal_rails, 5) then
                    v.cnts := r.cnts + 1;
                end if;
                if r.cnts = GROUP_DELAY then
                    v.cnts := (others => '0');
                    v.state := AVCCAUX_EN;
                end if;

            when AVCCAUX_EN =>
                v.group_en(6) := '1';
                v.cnts := (others => '0');
                if group_good(versal_rails, 6) then
                    v.cnts := r.cnts + 1;
                end if;
                if r.cnts = GROUP_DELAY then
                    v.cnts := (others => '0');
                    v.state := GT_AVTT_EN;
                end if;

            when GT_AVTT_EN =>
                v.group_en(7) := '1';
                v.cnts := (others => '0');
                if group_good(versal_rails, 7) then
                    v.cnts := r.cnts + 1;
                end if;
                if r.cnts = GROUP_DELAY then
                    v.cnts := (others => '0');
                    v.state := RAILS_SETTLE;
                    -- Every rail is up now, so hold the whole tree to account.
                    v.rails_expected := '1';
                end if;

            when RAILS_SETTLE =>
                v.cnts := r.cnts + 1;
                if r.cnts = RAIL_SETTLE_MS then
                    -- Latch the boot mode here so a register write mid-boot
                    -- cannot move the straps out from under the Versal.
                    v.mode := boot_ctrl.mode;
                    v.cnts := (others => '0');
                    if boot_ctrl.hash_image = '1' then
                        v.state := HASH_IMAGE;
                    else
                        v.state := MODE_STRAP;
                    end if;
                end if;

            -- Measure the boot image while the Versal is still in POR and the
            -- flash is ours. The hash engine owns the timing: a large image
            -- takes seconds, and software can abort a run that is going
            -- nowhere, which comes back as an error here. Either way the
            -- Versal boots; whether a bad measurement matters is for the SP.
            when HASH_IMAGE =>
                v.hash_req := '1';
                if hash_ack = '1' then
                    v.hash_req := '0';
                    v.hash_done := not hash_err;
                    v.hash_failed := hash_err;
                    v.state := HASH_RELEASE;
                end if;

            when HASH_RELEASE =>
                -- Let the handshake finish before anything else can start one
                if hash_ack = '0' then
                    v.state := MODE_STRAP;
                end if;

            when MODE_STRAP =>
                v.mode_buffer_en_l := '0';
                v.err_done_buff_en := '1';
                v.cnts := r.cnts + 1;
                if r.cnts = MODE_SETUP_MS then
                    v.state := POR_RELEASE;
                    v.cnts := (others => '0');
                end if;

            when POR_RELEASE =>
                v.por_b := '1';
                v.clk_buff_oe_l := '0';
                v.state := WAIT_DONE;
                v.cnts := (others => '0');

            when WAIT_DONE =>
                v.cnts := r.cnts + 1;
                if versal_boot.done = '1' then
                    v.state := DONE;
                    v.cnts := (others => '0');
                elsif versal_boot.error_out = '1' or r.cnts = DONE_TIMEOUT_MS then
                    -- A boot failure is not a power fault: the rails are fine
                    -- and there is a device to talk to over JTAG, so stay here
                    -- and let software decide rather than dropping power.
                    v.boot_failed := '1';
                    v.cnts := r.cnts;
                end if;

            when DONE =>
                if enable = '0' then
                    v.state := POWER_DOWN;
                    v.por_b := '0';
                    v.cnts := to_unsigned(1, v.cnts'length);
                end if;

            -- Take the groups down last-up-first-down, one every
            -- GROUP_DELAY. Whoever sends us here asserts POR_B and starts the
            -- count at one rather than zero, so the Versal has been in reset
            -- for a full delay before the first group leaves.
            -- This is on a timer alone: a power good going away
            -- says the rail has left regulation, not that it has discharged,
            -- and after a fault the rail at issue may never have had one.
            -- Groups that never came up are passed over, so a power-up that
            -- faulted part way only unwinds what it had enabled. The hotswap
            -- goes last, a delay after group 1.
            when POWER_DOWN =>
                v.por_b := '0';
                v.mode_buffer_en_l := '1';
                v.err_done_buff_en := '0';
                v.clk_buff_oe_l := '1';
                v.rails_expected := '0';
                v.hash_req := '0';
                if r.cnts = 0 then
                    v.cnts := r.cnts + 1;
                    if or r.group_en = '0' then
                        v.hsc_en := '0';
                        v.state := IDLE;
                    else
                        for i in NUM_GROUPS downto 1 loop
                            if r.group_en(i) = '1' then
                                v.group_en(i) := '0';
                                exit;
                            end if;
                        end loop;
                    end if;
                elsif r.cnts = GROUP_DELAY then
                    v.cnts := (others => '0');
                else
                    v.cnts := r.cnts + 1;
                end if;
                    -- the T6 states; this NIC never has them
            when others => null;
        end case;

        -- MAPO handling, monitored in every state that has power on or
        -- coming on. A measurement in flight is simply abandoned: the request
        -- drops on the way down and the engine's acknowledge, whenever it
        -- comes, is ignored.
        if r.state /= IDLE and r.state /= POWER_DOWN then
            if rails_faulted = '1' or upstream_ok = '0' or
               nic_test_mapo = '1' then
                v.faulted := '1';
                v.state := POWER_DOWN;
                v.por_b := '0';
                v.cnts := to_unsigned(1, v.cnts'length);
                v.rails_expected := '0';
            end if;
        end if;

        rin <= v;
    end process;

    -- PCIe resets follow the SP5 hotplug slot power once the Versal is up.
    cha_perst_l <= '1' when r.state = DONE and sp5_versal_cha_perst_l = '1' and
                            debug_enables.force_nic_reset = '0' else '0';
    chb_perst_l <= '1' when r.state = DONE and sp5_versal_chb_perst_l = '1' and
                            debug_enables.force_nic_reset = '0' else '0';

    reg_proc: process(clk, reset)
    begin
        if reset then
            r <= versal_r_reset;
        elsif rising_edge(clk) then
            r <= rin;
        end if;
    end process;

    -- Register and mux the Versal outputs, letting the debug registers take
    -- them over wholesale when asked.
    out_reg: process(clk, reset)
    begin
        if reset then
            final_outs <= (others => '0');
            final_outs.mode_buffer_en_l <= '1';
            final_outs.cha_clk_buff_oe_l <= '1';
            final_outs.chb_clk_buff_oe_l <= '1';
        elsif rising_edge(clk) then
            if debug_enables.nic_override then
                final_outs <= versal_overrides_reg;
            else
                final_outs.por_b <= r.por_b and not debug_enables.force_nic_reset;
                final_outs.mode_buffer_en_l <= r.mode_buffer_en_l;
                final_outs.err_done_buff_en <= r.err_done_buff_en;
                final_outs.cha_perst_l <= cha_perst_l;
                final_outs.chb_perst_l <= chb_perst_l;
                final_outs.cha_clk_buff_oe_l <= r.clk_buff_oe_l;
                final_outs.chb_clk_buff_oe_l <= r.clk_buff_oe_l;
            end if;
        end if;
    end process;

    versal_boot.por_b <= final_outs.por_b;
    versal_boot.mode <= r.mode;
    versal_boot.mode_buffer_en_l <= final_outs.mode_buffer_en_l;
    versal_boot.err_done_buff_en <= final_outs.err_done_buff_en;

    versal_pcie.cha.perst_l <= final_outs.cha_perst_l;
    versal_pcie.cha.clk_buff_oe_l <= final_outs.cha_clk_buff_oe_l;
    versal_pcie.chb.perst_l <= final_outs.chb_perst_l;
    versal_pcie.chb.clk_buff_oe_l <= final_outs.chb_clk_buff_oe_l;

    -- One enable per rail, staged by the state machine above.
    versal_rails.hsc_12v.enable <= r.hsc_en;
    versal_rails.v3p3.enable <= r.group_en(1);
    versal_rails.v1p8.enable <= r.group_en(1);
    versal_rails.v0p88.enable <= r.group_en(2);
    versal_rails.v0p8_vccint.enable <= r.group_en(3);
    versal_rails.v1p5.enable <= r.group_en(4);
    versal_rails.v1p1.enable <= r.group_en(5);
    versal_rails.v1p5_avccaux.enable <= r.group_en(6);
    versal_rails.v1p4.enable <= r.group_en(7);

end rtl;
