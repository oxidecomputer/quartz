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

use work.sequencer_regs_pkg.all;

entity sequencer_regs is
    port(
        clk : in std_logic;
        reset : in std_logic;

        axi_if : view axil8x32_pkg.axil_target;
        -- from early block
        early_power_ctrl: out early_power_ctrl_type;
        early_power_rdbks : in early_power_rdbks_type;
        power_ctrl : out power_ctrl_type;
        -- from a1/a0 blocks
        seq_api_status : in seq_api_status_type;
        seq_raw_status : in seq_raw_status_type;
        -- from nic block
        nic_api_status : in nic_api_status_type;
        nic_raw_status : in nic_raw_status_type;
        rails_en_rdbk : in rails_type;
        rails_pg_rdbk : in rails_type;
        debug_enables : out debug_enables_type;
        nic_overrides : out nic_overrides_type;
        -- misc readbacks
        sp5_readbacks : in sp5_readbacks_type;
        nic_readbacks : in nic_readbacks_type


    );
end entity;

architecture rtl of sequencer_regs is
    signal ifr : irq_type;
    signal ier : irq_type;
    signal int_pend : std_logic;

    signal status : status_type;

    signal seq_api_status_max : seq_api_status_type;
    signal seq_raw_status_max : seq_raw_status_type;
    signal nic_api_status_max : nic_api_status_type;
    signal nic_raw_status_max : nic_raw_status_type;

    signal amd_reset_fedges : amd_reset_fedges_type;
    signal amd_pwrok_fedges : amd_pwrok_fedges_type;
    signal amd_reset_l_last : std_logic;
    signal amd_reset_l_fedge : std_logic;
    signal amd_pwrok_last : std_logic;
    signal amd_pwrok_fedge : std_logic;

    signal a0_en_redge : std_logic;
    signal a0_en_last : std_logic;

    signal rails_pg_max : rails_type;
   
    signal axi_int_read_ready : std_logic;
    signal awready : std_logic;
    signal bvalid : std_logic;
    alias bready is axi_if.write_response.ready;
    signal arready : std_logic;
    signal rvalid : std_logic;
    signal rdata : std_logic_vector(31 downto 0);

begin

    -- non-axi-specific logic
    seq_regs_specific: process(clk, reset)
    begin
        if reset then
            a0_en_last <= '0';
            amd_reset_l_last <= '0';
            amd_pwrok_last <= '0';
            seq_api_status_max <= (a0_sm => IDLE);
            seq_raw_status_max <= (hw_sm => (others => '0'));
            nic_api_status_max <= (nic_sm => IDLE);
            nic_raw_status_max <= (hw_sm => (others => '0'));
            amd_reset_fedges <= (counts => (others => '0'));
            amd_pwrok_fedges <= (counts => (others => '0'));
            
        elsif rising_edge(clk) then
            a0_en_last <= power_ctrl.a0_en;
            amd_reset_l_last <= sp5_readbacks.reset_l;
            amd_pwrok_last <= sp5_readbacks.pwr_ok;

            -- Max hold for seq API status.  Clear on rising edge of enable
            if a0_en_redge then
                seq_api_status_max <= (a0_sm => IDLE);
            elsif decode(seq_api_status_max.a0_sm) <= decode(seq_api_status.a0_sm) then
                seq_api_status_max <= seq_api_status;
            end if;

             -- Max hold for seq raw status.  Clear on rising edge of enable
             if a0_en_redge then
                seq_raw_status_max <= (hw_sm => (others => '0'));
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
                nic_raw_status_max <= (hw_sm => (others => '0'));
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

        end if;
    end process;
    a0_en_redge <= power_ctrl.a0_en and (not a0_en_last);
    amd_reset_l_fedge <= not sp5_readbacks.reset_l and amd_reset_l_last;
    amd_pwrok_fedge <= not sp5_readbacks.pwr_ok and amd_pwrok_last;
    
    -- Assign outputs to the record here
    -- write_address channel
    axi_if.write_address.ready <= awready;
    -- write_data channel
    axi_if.write_data.ready <= awready;

    -- write_response channel
    axi_if.write_response.resp <= OKAY;
    axi_if.write_response.valid <= bvalid;

    -- read_address channel
    axi_if.read_address.ready <= arready;
    -- read_data channel
    axi_if.read_data.resp <= OKAY;
    axi_if.read_data.data <= rdata;
    axi_if.read_data.valid <= rvalid;

    arready <= not rvalid;


    axi_int_read_ready <=  axi_if.read_address.valid and arready;

    -- axi transaction mgmt
    axi_txn: process(clk, reset)
    begin
        if reset then
            awready <= '0';
            bvalid <= '0';
            rvalid <= '0';
        elsif rising_edge(clk) then
            -- bvalid set on every write,
            -- cleared after bvalid && bready
            if awready then
                bvalid <= '1';
            elsif bready then
                bvalid <= '0';
            end if;

            if axi_int_read_ready then
                rvalid <= '1';
            elsif axi_if.read_data.ready then
                rvalid <= '0';
            end if;

            -- can accept a new write if we're not
            -- responding to write already or
            -- the write is not in progress
            awready <= not awready and
                       (axi_if.write_address.valid and axi_if.write_data.valid) and
                       (not bvalid or bready);
        end if;
    end process;

    write_logic: process(clk, reset)
    begin
        if reset then
            ifr <= reset_0s;
            ier <= reset_0s;
            power_ctrl <= rec_reset;
            rails_pg_max <= reset_0s;
            debug_enables <= rec_reset;
            nic_overrides <= rec_reset;

        elsif rising_edge(clk) then
            if axi_if.write_data.ready then
                case to_integer(axi_if.write_address.addr) is
                    when IFR_OFFSET => ifr <= ifr and (not axi_if.write_data.data);
                    when IER_OFFSET => ier <= unpack(axi_if.write_data.data);
                    when EARLY_POWER_CTRL_OFFSET => early_power_ctrl <= unpack(axi_if.write_data.data);
                    when POWER_CTRL_OFFSET => power_ctrl <= unpack(axi_if.write_data.data);
                    when RAIL_PGS_MAX_HOLD_OFFSET => rails_pg_max <= reset_0s;
                    when DEBUG_ENABLES_OFFSET => debug_enables <= unpack(axi_if.write_data.data);
                    when NIC_OVERRIDES_OFFSET => nic_overrides <= unpack(axi_if.write_data.data);
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
            if axi_int_read_ready then
                case to_integer(axi_if.read_address.addr) is
                    when IFR_OFFSET => rdata <= pack(ifr);
                    when IER_OFFSET => rdata <= pack(ier);
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
                    when RAIL_ENABLES_OFFSET => rdata <= pack(rails_en_rdbk);
                    when RAIL_PGS_OFFSET => rdata <= pack(rails_pg_rdbk);
                    when RAIL_PGS_MAX_HOLD_OFFSET => rdata <= pack(rails_pg_max);
                    when SP5_READBACKS_OFFSET => rdata <= pack(sp5_readbacks);
                    when NIC_READBACKS_OFFSET => rdata <= pack(nic_readbacks);
                    when DEBUG_ENABLES_OFFSET => rdata <= pack(debug_enables);
                    when NIC_OVERRIDES_OFFSET => rdata <= pack(nic_overrides);
                    when others => rdata <= (others => '0');
                end case;
            end if;

        end if;
    end process;



end architecture;