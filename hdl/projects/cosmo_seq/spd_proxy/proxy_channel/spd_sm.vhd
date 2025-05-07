-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2025 Oxide Computer Company

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.numeric_std_unsigned.all;

use work.i2c_common_pkg.all;
use work.axi_st8_pkg;

entity spd_sm is
    generic(
        NUM_DIMMS_ON_BUS : natural := 6
    );
    port(
        clk         : in std_logic;
        reset       : in std_logic;

        fetch_spd_info  : in std_logic;
        spd_present : out std_logic_vector(NUM_DIMMS_ON_BUS - 1 downto 0);
        -- some handshaking with the i2c controller
        -- and arbitration
        arb_grant : in std_logic;
        arb_req   : out std_logic;

        i2c_bus_arb_lost : in std_logic;  -- big CPU stomped on us
        spd_rom_addr : out std_logic_vector(9 downto 0);

        -- I2C command interface
        i2c_ctrlr_status    : in txn_status_t;
        i2c_command         : out cmd_t;
        i2c_command_valid   : out std_logic;
        i2c_tx_st_if        : view axi_st8_pkg.axi_st_source;
    );




end entity;

architecture rtl of spd_sm is
    -- Going to read 1024bytes/DIMM in 128byte chunks
    constant PAGE_SEL_ADDR : std_logic_vector(7 downto 0) := 8x"0b";
    constant  PAGE_MAX : natural := 7;
    constant SPD_BASE_ADDR : std_logic_vector(6 downto 0) := 7x"50";
    constant MAX_DIMM_NUM : natural := NUM_DIMMS_ON_BUS - 1;

    type   spd_state_t is (
        IDLE,
        REQUEST_GRANT,
        SET_PAGE, -- Going to set 0 to 8 so that we get 1024bytes
        READ_SPD_PAGE, --Read 128 bytes. TBD interruptions?
        DONE
    );

    type reg_t is record
        state : spd_state_t;
        i2c_addr : std_logic_vector(6 downto 0);
        dimm_idx : natural range 0 to MAX_DIMM_NUM;
        hub_page_idx : unsigned(2 downto 0);
        spd_addr : unsigned(9 downto 0);
        cmd_valid : std_logic;
        arb_req : std_logic;
        pend : std_logic;
        present : std_logic_vector(NUM_DIMMS_ON_BUS - 1 downto 0);

    end record;
    constant rec_reset : reg_t := (
        state => IDLE,
        i2c_addr => (others => '0'),
        dimm_idx => 0,
        hub_page_idx => (others => '0'),
        spd_addr => (others => '0'),
        cmd_valid => '0',
        arb_req => '0',
        pend => '0',
        present => (others => '0')
    );

    signal r, rin : reg_t;
    signal i2c_req_success : std_logic;
    signal i2c_no_device : std_logic;
    signal i2c_aborted : std_logic;
begin
    
    arb_req <= r.arb_req;
    spd_rom_addr <= std_logic_vector(r.spd_addr);
    spd_present <= r.present;
    i2c_tx_st_if.data <= std_logic_vector(resize(r.hub_page_idx, 8));
    i2c_tx_st_if.valid <= '1' when r.state = SET_PAGE else '0';

    i2c_command <=
        ( 
            op => WRITE,
            addr => r.i2c_addr,
            reg => PAGE_SEL_ADDR,
            len => "00000001" -- 1 byte payload
        ) when r.state = SET_PAGE else
            -- We only read starting at 0x80 and can only do 128bytes at a time
            -- before changing the page.
        ( 
            op => RANDOM_READ,
            addr => r.i2c_addr,
            reg => "1" & std_logic_vector(r.spd_addr(6 downto 0)),
            len => 8x"80" -- 128 byte payload
        );
    i2c_command_valid <= r.cmd_valid;
    
    -- Find out who's there (set to SPD and verify ack)
    -- Read whole SPD
    -- Count NACKs per dimm for error reporting
    -- Move to next device, repeat
    i2c_req_success <= '1' when i2c_ctrlr_status.code_valid = '1' and i2c_ctrlr_status.code = SUCCESS else '0';
    i2c_no_device <= '1' when i2c_ctrlr_status.code_valid = '1' and i2c_ctrlr_status.code = NACK_BUS_ADDR else '0';
    i2c_aborted <= '1' when i2c_ctrlr_status.code_valid = '1' and i2c_ctrlr_status.code = ABORTED else '0';
    sm: process(all)
        variable v : reg_t;
    begin
        v := r;

        case r.state is
            when IDLE =>
                -- start at the first dimm
                v.hub_page_idx := (others => '0');
                v.spd_addr := (others => '0');
                v.dimm_idx := 0;
                v.i2c_addr := SPD_BASE_ADDR or To_StdLogicVector(r.dimm_idx, 7);
                v.present := (others => '0');
               if fetch_spd_info = '1' then
                    v.state := REQUEST_GRANT;
                else
                    v.state := IDLE;
                end if;
            
            when REQUEST_GRANT =>
                v.arb_req := '1';
                if arb_grant = '1' then
                    v.state := SET_PAGE;  -- Doubles as check for present
                end if;

            when SET_PAGE =>
                if r.cmd_valid and i2c_ctrlr_status.busy then
                    v.cmd_valid := '0';
                    v.pend := '0';
                elsif r.cmd_valid = '0' and i2c_ctrlr_status.busy = '0' then
                    v.cmd_valid := '1';
                    v.pend := '1';
                end if;
                -- We can get a response, in which case we can move on,
                -- or we can get a NACK, which means nothing is there
                -- or we can lose i2c arbitration due to SP5 trying
                -- to access the bus at the same time. We retry this case
                if i2c_req_success = '1' and r.pend = '0' then
                    -- Success, move on to set page
                    v.state := READ_SPD_PAGE;
                    v.present(r.dimm_idx) := '1';
                elsif i2c_no_device = '1' and r.pend = '0' then
                    -- NACK, move to next dimm
                    if r.dimm_idx < MAX_DIMM_NUM then
                        -- We are done with this dimm, move to next dimm
                        v.dimm_idx := v.dimm_idx + 1;
                        v.i2c_addr := SPD_BASE_ADDR or To_StdLogicVector(v.dimm_idx, 7);
                        v.state := SET_PAGE;
                        v.hub_page_idx := (others => '0');
                    else
                        -- We are done with all dimms, move to done
                        v.state := DONE;
                    end if;
                elsif i2c_aborted = '1' and r.pend = '0' then
                    -- stay-here and re-issue the command
                end if;
               
            when READ_SPD_PAGE =>
                 if r.cmd_valid and i2c_ctrlr_status.busy then
                    v.cmd_valid := '0';
                    v.pend := '0';
                elsif r.cmd_valid = '0' and i2c_ctrlr_status.busy = '0' then
                    v.cmd_valid := '1';
                    v.pend := '1';
                end if;
                -- We can get a response, in which case we can move on,
                -- or we can get a NACK, which means nothing is there
                -- or we can lose i2c arbitration due to SP5 trying
                -- to access the bus at the same time. We retry this case
                if i2c_req_success = '1' and r.pend = '0' then
                    -- Success, move on to set page or next dimm
                    if r.hub_page_idx = PAGE_MAX and r.dimm_idx < MAX_DIMM_NUM then
                        -- We are done with this dimm, move to next dimm
                        v.dimm_idx := v.dimm_idx + 1;
                        v.i2c_addr := SPD_BASE_ADDR or To_StdLogicVector(v.dimm_idx, 7);
                        v.state := SET_PAGE;
                        v.hub_page_idx := (others => '0');
                    elsif r.dimm_idx = MAX_DIMM_NUM and r.hub_page_idx = PAGE_MAX then
                        -- We are done with all dimms, move to done
                        v.state := DONE;
                    else
                        -- Move to next page
                        v.hub_page_idx := v.hub_page_idx + 1;
                        v.state := SET_PAGE;
                    end if;
                elsif i2c_no_device = '1'  and r.pend = '0' then
                    -- NACK, move to next dimm. This shouldn't really happen
                    -- since we should have skipped missing dimms
                    v.dimm_idx := v.dimm_idx + 1;
                    v.i2c_addr := SPD_BASE_ADDR or To_StdLogicVector(v.dimm_idx, 7);
                    v.state := SET_PAGE;
                    v.hub_page_idx := (others => '0');
                 elsif i2c_aborted = '1' and v.pend = '0' then
                    v.cmd_valid := '1';  -- Do we need to delay?
                    -- stay-here and re-issue the command
                end if;
              
            when DONE =>
                v.arb_req := '0';
                if fetch_spd_info then
                    v.state := REQUEST_GRANT;
                    v.hub_page_idx := (others => '0');
                    v.spd_addr := (others => '0');
                    v.dimm_idx := 0;
                    v.i2c_addr := SPD_BASE_ADDR or To_StdLogicVector(r.dimm_idx, 7);
                end if;

        end case;

        rin <= v;
    end process;

    reg: process(clk, reset)
    begin
        if reset then
            r <= rec_reset;
        elsif rising_edge(clk) then
            r <= rin;
        end if;

    end process;

end rtl;