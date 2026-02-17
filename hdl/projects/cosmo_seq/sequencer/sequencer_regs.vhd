-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2025 Oxide Computer Company

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.numeric_std_unsigned.all;

use work.axil_common_pkg.all;
use work.axil8x32_pkg;

use work.sequencer_io_pkg.all;
use work.sequencer_regs_pkg.all;

entity sequencer_regs is
    port(
        clk : in std_logic;
        reset : in std_logic;

        irq_l_out : out std_logic;
        allow_backplane_pcie_clk : out std_logic;
        axi_if : view axil8x32_pkg.axil_target;
        -- from early block
        early_power_ctrl: out early_power_ctrl_type;
        early_power_rdbks : in early_power_rdbks_type;
        power_ctrl : out power_ctrl_type;
        -- from a1/a0 blocks
        seq_api_status : in seq_api_status_type;
        seq_raw_status : in seq_raw_status_type;
        therm_trip : in std_logic;
        smerr_assert : in std_logic;
        a0_faulted : in std_logic;
        -- from nic block
        nic_api_status : in nic_api_status_type;
        nic_raw_status : in nic_raw_status_type;
        nic_faulted : in std_logic;
        rails_en_rdbk : in rails_type;
        rails_pg_rdbk : in rails_type;
        debug_enables : out debug_enables_type;
        nic_overrides : out nic_overrides_type;
        -- misc readbacks
        sp5_readbacks : in sp5_readbacks_type;
        nic_readbacks : in nic_readbacks_type;
        -- Ignition mux and reconfig control
        ignition_mux_sel : out std_logic;
        ignition_creset : out std_logic;
        -- regulator alerts
        reg_alert_l : in seq_power_alert_pins_t


    );
end entity;

architecture rtl of sequencer_regs is
    signal irq_raw : irq_type;
    signal irq_clear : irq_type;
    signal igr : irq_type;
    signal ifr : irq_type;
    signal ier : irq_type;
    signal irq_out : std_logic_vector(sizeof(ier) - 1 downto 0);

    signal status : status_type;

    signal seq_api_status_max : seq_api_status_type;
    signal seq_raw_status_max : seq_raw_status_type;
    signal nic_api_status_max : nic_api_status_type;
    signal nic_raw_status_max : nic_raw_status_type;
    signal ignition_control : ignition_control_type;

    signal amd_reset_fedges : amd_reset_fedges_type;
    signal amd_pwrok_fedges : amd_pwrok_fedges_type;
    signal amd_pwrgd_out_fedges : amd_pwgdout_fedges_type;
    signal amd_reset_l_last : std_logic;
    signal amd_reset_l_fedge : std_logic;
    signal amd_pwrok_last : std_logic;
    signal amd_pwrok_fedge : std_logic;
    signal amd_pwrgd_out_last : std_logic;
    signal amd_pwrgd_out_fedge : std_logic;

    signal a0_en_redge : std_logic;
    signal a0_en_last : std_logic;

    signal rails_pg_max : rails_type;
   
    signal rdata : std_logic_vector(31 downto 0);
    signal active_read : std_logic;
    signal active_write : std_logic;
    signal therm_trip_last : std_logic;
    signal smerr_assert_last : std_logic;

    signal pcie_clk_ctrl : pcie_clk_ctrl_type;
    constant  EDGE : std_logic := '0';
    constant LEVEL : std_logic := '1';
    -- Set up IRQ expected trigger types here, we pass this into the 
    -- irq block so it will handle things correctly.
    constant level_edge_n : irq_type := 
        (
            pwr_cont3_to_fpga1_alert => LEVEL,
            pwr_cont2_to_fpga1_alert => LEVEL,
            pwr_cont1_to_fpga1_alert => LEVEL,
            v0p96_nic_to_fpga1_alert => LEVEL,
            vr_v5p0_sys_to_fpga1_alert => LEVEL,
            vr_v3p3_sys_to_fpga1_alert => LEVEL,
            vr_v1p8_sys_to_fpga1_alert => LEVEL,
            main_hsc_alert => LEVEL,
            v12_mcio_a0hp_hsc_alert => LEVEL,
            v12_ddr5_ghijkl_hsc_alert => LEVEL,
            v12_ddr5_abcdef_hsc_alert => LEVEL,
            nic_hsc_alert => LEVEL,
            m2_hsc_alert => LEVEL,
            ibc_alert => LEVEL,
            fan_west_hsc_alert => LEVEL,
            fan_east_hsc_alert => LEVEL,
            fan_central_hsc_alert => LEVEL,
            amd_rstn_fedge => EDGE,
            amd_pwrok_fedge => EDGE,
            nicmapo => EDGE,
            a0mapo => EDGE,
            smerr_assert => EDGE,
            thermtrip => EDGE,
            fanfault => EDGE
        );

begin

    ignition_mux_sel <= ignition_control.mux_to_ignition;
    ignition_creset <= ignition_control.ignition_creset;
    allow_backplane_pcie_clk <= pcie_clk_ctrl.clk_en;

    -- Map a bunch of discrete signals into the irq_raw vector.
    irq_raw <= (
        pwr_cont3_to_fpga1_alert => not reg_alert_l.pwr_cont3_to_fpga1_alert_l,
        pwr_cont2_to_fpga1_alert => not reg_alert_l.pwr_cont2_to_fpga1_alert_l,
        pwr_cont1_to_fpga1_alert => not reg_alert_l.pwr_cont1_to_fpga1_alert_l,
        v0p96_nic_to_fpga1_alert => not reg_alert_l.v0p96_nic_to_fpga1_alert_l,
        vr_v5p0_sys_to_fpga1_alert => not reg_alert_l.vr_v5p0_sys_to_fpga1_alert_l,
        vr_v3p3_sys_to_fpga1_alert => not reg_alert_l.vr_v3p3_sys_to_fpga1_alert_l,
        vr_v1p8_sys_to_fpga1_alert => not reg_alert_l.vr_v1p8_sys_to_fpga1_alert_l,
        main_hsc_alert => not reg_alert_l.main_hsc_to_fpga1_alert_l,
        v12_mcio_a0hp_hsc_alert => not reg_alert_l.smbus_v12_mcio_a0hp_hsc_to_fpga1_alert_l,
        v12_ddr5_ghijkl_hsc_alert => not reg_alert_l.smbus_v12_ddr5_ghijkl_hsc_to_fpga1_alert,
        v12_ddr5_abcdef_hsc_alert => not reg_alert_l.smbus_v12_ddr5_abcdef_hsc_to_fpga1_alert,
        nic_hsc_alert => not reg_alert_l.smbus_nic_hsc_to_fpga1_alert_l,
        m2_hsc_alert => not reg_alert_l.smbus_m2_hsc_to_fpga1_alert_l,
        ibc_alert =>  not reg_alert_l.smbus_ibc_to_fpga1_alert_l,
        fan_west_hsc_alert => not reg_alert_l.smbus_fan_west_hsc_to_fpga1_alert_l,
        fan_east_hsc_alert => not reg_alert_l.smbus_fan_east_hsc_to_fpga1_alert_l,
        fan_central_hsc_alert => not reg_alert_l.smbus_fan_central_hsc_to_fpga1_alert_l,
        amd_rstn_fedge => amd_reset_l_fedge,
        amd_pwrok_fedge => amd_pwrok_fedge,
        nicmapo => nic_faulted,
        a0mapo => a0_faulted,
        smerr_assert => smerr_assert,
        thermtrip => therm_trip,
        -- TODO: not implemented yet
        fanfault => '0'
    );

    irq_block_inst: entity work.irq_block
    generic map(
        IRQ_OUT_ACTIVE_HIGH => false,
        NUM_IRQS => sizeof(irq_raw)
    )
     port map(
        clk => clk,
        reset => reset,
        irq_in => compress(irq_raw),
        irq_en => compress(ier),
        level_edge_n => compress(level_edge_n),
        irq_out => irq_out,
        irq_clear => compress(irq_clear),
        irq_force => compress(igr),
        irq_pin => irq_l_out
    );
    ifr <= uncompress(irq_out);


    -- non-axi-specific logic
    seq_regs_specific: process(clk, reset)
    begin
        if reset then
            therm_trip_last <= '0';
            smerr_assert_last <= '0';
            a0_en_last <= '0';
            amd_reset_l_last <= '0';
            amd_pwrok_last <= '0';
            amd_pwrgd_out_last <= '0';
            seq_api_status_max <= (a0_sm => IDLE);
            seq_raw_status_max <= (hw_sm => IDLE);
            nic_api_status_max <= (nic_sm => IDLE);
            nic_raw_status_max <= (hw_sm => IDLE);
            amd_reset_fedges <= (counts => (others => '0'));
            amd_pwrok_fedges <= (counts => (others => '0'));
            amd_pwrgd_out_fedges <= (counts => (others => '0'));
            
        elsif rising_edge(clk) then

            therm_trip_last <= therm_trip;
            smerr_assert_last <= smerr_assert;
            a0_en_last <= power_ctrl.a0_en;
            amd_reset_l_last <= sp5_readbacks.reset_l;
            amd_pwrok_last <= sp5_readbacks.pwr_ok;
            amd_pwrgd_out_last <= sp5_readbacks.pwrgd_out;

            -- Max hold for seq API status.  Clear on rising edge of enable
            if a0_en_redge then
                seq_api_status_max <= (a0_sm => IDLE);
            elsif decode(seq_api_status_max.a0_sm) <= decode(seq_api_status.a0_sm) then
                seq_api_status_max <= seq_api_status;
            end if;

             -- Max hold for seq raw status.  Clear on rising edge of enable
             if a0_en_redge then
                seq_raw_status_max <= (hw_sm => IDLE);
            elsif seq_raw_status_max.hw_sm <= seq_raw_status.hw_sm then
                seq_raw_status_max <= seq_raw_status;
            end if;

            -- Max hold for nic API status.  Clear on rising edge of enable
            if a0_en_redge then
                nic_api_status_max <= (nic_sm => IDLE);
            elsif decode(nic_api_status_max.nic_sm) <= decode(nic_api_status.nic_sm) then
                nic_api_status_max <= nic_api_status;
            end if;

             -- Max hold for nic raw status.  Clear on rising edge of enable
             if a0_en_redge then
                nic_raw_status_max <= (hw_sm => IDLE);
            elsif nic_raw_status_max.hw_sm <= nic_raw_status.hw_sm then
                nic_raw_status_max <= nic_raw_status;
            end if;

            -- Debug counters,  Cleared on rising edge of enable
            if a0_en_redge then
              amd_reset_fedges <= (counts => (others => '0'));
            elsif amd_reset_l_fedge = '1' and amd_reset_fedges.counts < 255 then
              amd_reset_fedges.counts <= amd_reset_fedges.counts + 1;
            end if;
            if a0_en_redge then
              amd_pwrok_fedges <= (counts => (others => '0'));
            elsif amd_pwrok_fedge = '1' and amd_pwrok_fedges.counts < 255 then
              amd_pwrok_fedges.counts <= amd_pwrok_fedges.counts + 1;
            end if;

            if a0_en_redge then
              amd_pwrgd_out_fedges <= (counts => (others => '0'));
            elsif amd_pwrgd_out_fedge = '1' and amd_pwrgd_out_fedges.counts < 255 then
              amd_pwrgd_out_fedges.counts <= amd_pwrgd_out_fedges.counts + 1;
            end if;

        end if;
    end process;
    a0_en_redge <= power_ctrl.a0_en and (not a0_en_last);
    amd_reset_l_fedge <= not sp5_readbacks.reset_l and amd_reset_l_last;
    amd_pwrok_fedge <= not sp5_readbacks.pwr_ok and amd_pwrok_last;
    amd_pwrgd_out_fedge <= not sp5_readbacks.pwrgd_out and amd_pwrgd_out_last;

    axil_target_txn_inst: entity work.axil_target_txn
     port map(
        clk => clk,
        reset => reset,
        arvalid => axi_if.read_address.valid,
        arready => axi_if.read_address.ready,
        awvalid => axi_if.write_address.valid,
        awready => axi_if.write_address.ready,
        wvalid => axi_if.write_data.valid,
        wready => axi_if.write_data.ready,
        bvalid => axi_if.write_response.valid,
        bready => axi_if.write_response.ready,
        bresp => axi_if.write_response.resp,
        rvalid => axi_if.read_data.valid,
        rready => axi_if.read_data.ready,
        rresp => axi_if.read_data.resp,
        active_read => active_read,
        active_write => active_write
    );
    axi_if.read_data.data <= rdata;
    



    write_logic: process(clk, reset)
    begin
        if reset then
            irq_clear <= reset_0s;
            ier <= reset_0s;
            igr <= reset_0s;

            early_power_ctrl <= rec_reset;
            power_ctrl <= rec_reset;
            rails_pg_max <= reset_0s;
            debug_enables <= rec_reset;
            nic_overrides <= rec_reset;
            ignition_control <= rec_reset;
            pcie_clk_ctrl <= rec_reset;

        elsif rising_edge(clk) then
           irq_clear <= reset_0s;  -- clear single-cycle flags.
           igr <= reset_0s;
           nic_overrides.nic_test_mapo <= '0'; -- Clear test MAPO bit every cycle, so it's a single-cycle pulse when set.

            if active_write then
                case to_integer(axi_if.write_address.addr) is
                    -- This is a W1C register, so we write the incoming data directly to the clear signal, and let the irq block handle clearing the ifr bits.
                    when IFR_OFFSET => irq_clear <= unpack(axi_if.write_data.data);
                    when IER_OFFSET => ier <= unpack(axi_if.write_data.data);
                    when IGR_OFFSET => igr <= unpack(axi_if.write_data.data);
                    when EARLY_POWER_CTRL_OFFSET => early_power_ctrl <= unpack(axi_if.write_data.data);
                    when POWER_CTRL_OFFSET => power_ctrl <= unpack(axi_if.write_data.data);
                    when RAIL_PGS_MAX_HOLD_OFFSET => rails_pg_max <= reset_0s;
                    when DEBUG_ENABLES_OFFSET => debug_enables <= unpack(axi_if.write_data.data);
                    when NIC_OVERRIDES_OFFSET => nic_overrides <= unpack(axi_if.write_data.data);
                    when IGNITION_CONTROL_OFFSET => ignition_control <= unpack(axi_if.write_data.data);
                    when PCIE_CLK_CTRL_OFFSET => pcie_clk_ctrl <= unpack(axi_if.write_data.data);
                    when others => null;
                end case;
            end if;
          

        end if;
    end process;

    

    read_logic: process(clk, reset)
    begin
        if reset then
            rdata <= (others => '0');
        elsif rising_edge(clk) then
            if active_read then
                case to_integer(axi_if.read_address.addr) is
                    when IFR_OFFSET => rdata <= pack(ifr);
                    when IER_OFFSET => rdata <= pack(ier);
                    when IGR_OFFSET => rdata <= pack(igr);
                    when ILR_OFFSET => rdata <= pack(irq_raw);
                    when STATUS_OFFSET => rdata <= pack(status);
                    when EARLY_POWER_CTRL_OFFSET => rdata <= pack(early_power_ctrl);
                    when EARLY_POWER_RDBKS_OFFSET => rdata <= pack(early_power_rdbks);
                    when POWER_CTRL_OFFSET => rdata <= pack(power_ctrl);
                    when SEQ_API_STATUS_OFFSET => rdata <= pack(seq_api_status);
                    when SEQ_RAW_STATUS_OFFSET => rdata <= pack(seq_raw_status);
                    when NIC_API_STATUS_OFFSET => rdata <= pack(nic_api_status);
                    when NIC_RAW_STATUS_OFFSET => rdata <= pack(nic_raw_status);
                    when AMD_RESET_FEDGES_OFFSET => rdata <= pack(amd_reset_fedges);
                    when AMD_PWROK_FEDGES_OFFSET => rdata <= pack(amd_pwrok_fedges);
                    when AMD_PWGDOUT_FEDGES_OFFSET => rdata <= pack(amd_pwrgd_out_fedges);
                    when RAIL_ENABLES_OFFSET => rdata <= pack(rails_en_rdbk);
                    when RAIL_PGS_OFFSET => rdata <= pack(rails_pg_rdbk);
                    when RAIL_PGS_MAX_HOLD_OFFSET => rdata <= pack(rails_pg_max);
                    when SP5_READBACKS_OFFSET => rdata <= pack(sp5_readbacks);
                    when NIC_READBACKS_OFFSET => rdata <= pack(nic_readbacks);
                    when DEBUG_ENABLES_OFFSET => rdata <= pack(debug_enables);
                    when NIC_OVERRIDES_OFFSET => rdata <= pack(nic_overrides);
                    when IGNITION_CONTROL_OFFSET => rdata <= pack(ignition_control);
                    when PCIE_CLK_CTRL_OFFSET => rdata <= pack(pcie_clk_ctrl);
                    when others => rdata <= (others => '0');
                end case;
            end if;

        end if;
    end process;



end architecture;