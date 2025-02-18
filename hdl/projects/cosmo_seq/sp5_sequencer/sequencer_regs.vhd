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

        power_ctrl : out power_ctrl_type;
        -- from a1/a0 blocks
        seq_api_status : in seq_api_status_type;
        seq_raw_status : in seq_raw_status_type;
        -- from nic block
        nic_api_status : in nic_api_status_type;
        nic_raw_status : in nic_raw_status_type;
        rails_en_rdbk : in rails_type;
        rails_pg_rdbk : in rails_type;


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

    signal rails_pg_max : rails_type;
   
    signal axi_int_read_ready : std_logic;
    signal awready : std_logic;
    signal bvalid : std_logic;
    alias bready is axi_if.write_response.ready;
    signal arready : std_logic;
    signal rvalid : std_logic;
    signal rdata : std_logic_vector(31 downto 0);

begin

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

           
        elsif rising_edge(clk) then
            if axi_if.write_data.ready then
                case to_integer(axi_if.write_address.addr) is
                    when IFR_OFFSET => ifr <= ifr and (not axi_if.write_data.data);
                    when IER_OFFSET => ier <= unpack(axi_if.write_data.data);
                    when POWER_CTRL_OFFSET => power_ctrl <= unpack(axi_if.write_data.data);
                    when RAIL_PGS_MAX_HOLD_OFFSET => rails_pg_max <= reset_0s;
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
                    when others => rdata <= (others => '0');
                end case;
            end if;

        end if;
    end process;



end architecture;