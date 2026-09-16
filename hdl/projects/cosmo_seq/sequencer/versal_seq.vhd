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
-- Rail grouping and timing below follow the Versal power-up requirements in
-- three stages -- core (VCCINT), then auxiliary (VCCAUX), then I/O (VCCO) --
-- with the transceiver rails riding along in whichever group enables them.
-- The exact inter-group delays are conservative placeholders and MUST be
-- confirmed against the VP1202 datasheet before hardware bring-up; they are
-- gathered into the constants below so that is a one-line change.
entity versal_seq is
    generic(
        CNTS_P_MS: integer
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
    -- How long the rails must be stable before POR_B is released.
    constant RAIL_SETTLE_MS : integer := 20 * ONE_MS;
    -- How long MODE[3:0] must be stable before POR_B is released.
    constant MODE_SETUP_MS : integer := 1 * ONE_MS;
    -- How long to wait for DONE before calling the boot failed. Versal images
    -- are large and come off QSPI, so this is generous on purpose.
    constant DONE_TIMEOUT_MS : integer := 5000 * ONE_MS;

    -- Rail groups. The Versal wants VCCINT up before VCCAUX before VCCO.
    -- v0p92_avcc and v1p2_avtt have no enable of their own; they cascade, so
    -- they are checked in the group whose enable brings them up.
    function core_group_good(rails : versal_power_t) return boolean is
    begin
        return (rails.v0p8_vccint.pg and rails.v0p88.pg and
                rails.v0p92_avcc.pg) = '1';
    end function;

    function aux_group_good(rails : versal_power_t) return boolean is
    begin
        return (rails.v1p5.pg and rails.v1p5_avccaux.pg and rails.v1p4.pg and
                rails.v1p1.pg and rails.v1p2_avtt.pg) = '1';
    end function;

    function io_group_good(rails : versal_power_t) return boolean is
    begin
        return (rails.v1p8.pg and rails.v3p3.pg) = '1';
    end function;

    type versal_r_t is record
        state : nic_raw_status_hw_sm;
        enable_last : std_logic;
        enable_pend : std_logic;
        cnts : unsigned(31 downto 0);
        cha_perst_l_last : std_logic;
        chb_perst_l_last : std_logic;
        hsc_en : std_logic;
        core_en : std_logic;
        aux_en : std_logic;
        io_en : std_logic;
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
        core_en => '0',
        aux_en => '0',
        io_en => '0',
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
    versal_dbg_pins.rails_en <= r.io_en;
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
                when HSC_EN | CORE_EN | AUX_EN | IO_EN =>
                    api_state.nic_sm <= ENABLE_POWER;
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
    begin
        v := r;
        v.cha_perst_l_last := sp5_versal_cha_perst_l;
        v.chb_perst_l_last := sp5_versal_chb_perst_l;

        -- Once we expect the rails to be up, any of them dropping is a fault.
        rails_faulted := '1' when r.rails_expected = '1' and
                                  (not is_power_good(versal_rails)) else '0';

        v.enable_last := sw_enable;
        if (sw_enable and not r.enable_last) = '1' or
           (r.faulted = '1' and r.cha_perst_l_last = '0' and sp5_versal_cha_perst_l = '1') or
           (r.faulted = '1' and r.chb_perst_l_last = '0' and sp5_versal_chb_perst_l = '1') then
            -- Same two re-enable paths cosmo's nic_seq has: software toggling
            -- the enable, or -- after a MAPO, where the SP5 owns slot power --
            -- the SP5 de-asserting PERST for a fresh attempt. Either slot
            -- coming back is enough; there is only the one device to bring up.
            v.enable_pend := '1';
            v.faulted := '0';
            v.boot_failed := '0';
        end if;

        case r.state is
            when IDLE =>
                v.hsc_en := '0';
                v.core_en := '0';
                v.aux_en := '0';
                v.io_en := '0';
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
                    v.state := CORE_EN;
                end if;

            when CORE_EN =>
                v.core_en := '1';
                v.cnts := (others => '0');
                if core_group_good(versal_rails) then
                    v.state := AUX_EN;
                end if;

            when AUX_EN =>
                v.aux_en := '1';
                v.cnts := (others => '0');
                if aux_group_good(versal_rails) then
                    v.state := IO_EN;
                end if;

            when IO_EN =>
                v.io_en := '1';
                v.cnts := (others => '0');
                if io_group_good(versal_rails) then
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
                if sw_enable = '0' then
                    v.state := IDLE;
                end if;
                    -- the T6 states; this NIC never has them
            when others => null;
        end case;

        -- MAPO handling, monitored in every non-IDLE state. A measurement
        -- in flight is simply abandoned: the request drops in IDLE and the
        -- engine's acknowledge, whenever it comes, is ignored there.
        if r.state /= IDLE then
            if rails_faulted = '1' or upstream_ok = '0' or
               nic_test_mapo = '1' then
                v.faulted := '1';
                v.state := IDLE;
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
    versal_rails.v0p8_vccint.enable <= r.core_en;
    versal_rails.v0p88.enable <= r.core_en;
    versal_rails.v1p5.enable <= r.aux_en;
    versal_rails.v1p5_avccaux.enable <= r.aux_en;
    versal_rails.v1p4.enable <= r.aux_en;
    versal_rails.v1p1.enable <= r.aux_en;
    versal_rails.v1p8.enable <= r.io_en;
    versal_rails.v3p3.enable <= r.io_en;

end rtl;
