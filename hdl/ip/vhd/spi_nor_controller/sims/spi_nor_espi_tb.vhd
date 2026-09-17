-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.numeric_std_unsigned.all;

library vunit_lib;
    context vunit_lib.com_context;
    context vunit_lib.vunit_context;
    context vunit_lib.vc_context;
use work.spi_nor_tb_pkg.all;
use work.spi_nor_pkg.all;
use work.spi_nor_regs_pkg.all;
use work.spi_nor_target_vc_pkg.all;

entity spi_nor_espi_tb is
    generic (
        runner_cfg : string
    );
end entity;

architecture tb of spi_nor_espi_tb is
begin

    th: entity work.spi_nor_espi_th;

    bench: process
        alias reset is <<signal th.reset : std_logic>>;
        alias clk is <<signal th.clk : std_logic>>;
        alias cmd_wdata is <<signal th.cmd_wdata : std_logic_vector(31 downto 0)>>;
        alias cmd_write is <<signal th.cmd_write : std_logic>>;
        alias payload_wdata is <<signal th.payload_wdata : std_logic_vector(7 downto 0)>>;
        alias payload_write is <<signal th.payload_write : std_logic>>;
        alias data_rdata is <<signal th.data_rdata : std_logic_vector(7 downto 0)>>;
        alias data_rdack is <<signal th.data_rdack : std_logic>>;
        alias data_rempty is <<signal th.data_rempty : std_logic>>;
        constant flash : actor_t := find("spi_nor_target");

        -- Request kinds, as flash_channel_pkg.to_kind_bits encodes them in
        -- the top nibble of the length word
        constant kind_read : std_logic_vector(3 downto 0) := x"0";
        constant kind_write : std_logic_vector(3 downto 0) := x"1";
        constant kind_erase : std_logic_vector(3 downto 0) := x"2";
        constant erase_4k : natural := 1;
        constant erase_32k : natural := 2;
        constant erase_64k : natural := 3;

        variable data : std_logic_vector(7 downto 0);

        -- Two-word command, the way the flash channel issues one
        procedure put_cmd(constant addr : natural; constant kind : std_logic_vector(3 downto 0); constant len : natural) is
        begin
            wait until rising_edge(clk);
            cmd_wdata <= std_logic_vector(to_unsigned(addr, 32));
            cmd_write <= '1';
            wait until rising_edge(clk);
            cmd_wdata <= kind & std_logic_vector(to_unsigned(len, 28));
            wait until rising_edge(clk);
            cmd_write <= '0';
        end procedure;

        procedure put_payload(constant addr : natural; constant len : natural) is
        begin
            wait until rising_edge(clk);
            for i in 0 to len - 1 loop
                payload_wdata <= pattern_byte(addr + i);
                payload_write <= '1';
                wait until rising_edge(clk);
            end loop;
            payload_write <= '0';
        end procedure;

        procedure get_byte(variable b : out std_logic_vector(7 downto 0)) is
        begin
            loop
                wait until rising_edge(clk);
                exit when data_rempty = '0';
            end loop;
            b := data_rdata;
            data_rdack <= '1';
            wait until rising_edge(clk);
            data_rdack <= '0';
        end procedure;

        -- Writes and erases report one status byte, zero for success
        procedure check_status(constant expected : std_logic_vector(7 downto 0); constant msg : string) is
            variable b : std_logic_vector(7 downto 0);
        begin
            get_byte(b);
            check_equal(b, expected, msg);
        end procedure;

        procedure check_flash_range(constant addr : natural; constant len : natural; constant erased : boolean; constant msg : string) is
            variable b : std_logic_vector(7 downto 0);
        begin
            for i in 0 to len - 1 loop
                read_flash_byte(net, flash, addr + i, b);
                if erased then
                    check_equal(b, std_logic_vector'(x"FF"), msg & " @" & to_hstring(to_unsigned(addr + i, 32)));
                else
                    check_equal(b, pattern_byte(addr + i), msg & " @" & to_hstring(to_unsigned(addr + i, 32)));
                end if;
            end loop;
        end procedure;

    begin
        test_runner_setup(runner, runner_cfg);
        wait until reset = '0';
        wait for 500 ns;
        -- The eSPI client only runs while the SP5 owns the flash
        write_bus(net, bus_handle, To_StdLogicVector(SPICR_OFFSET + 16#100#, bus_handle.p_address_length),
                  SPICR_SP5_OWNS_FLASH_MASK);
        wait_until_idle(net, bus_handle);

        while test_suite loop
            if run("espi_read") then
                fill_pattern(net, flash);
                put_cmd(16#1000#, kind_read, 300);
                for i in 0 to 299 loop
                    get_byte(data);
                    check_equal(data, pattern_byte(16#1000# + i), "read byte " & integer'image(i));
                end loop;
            elsif run("espi_write_then_read_back") then
                -- window starts erased
                put_payload(16#1000#, 64);
                put_cmd(16#1000#, kind_write, 64);
                check_status(x"00", "write status");
                check_flash_range(16#0FF0#, 16, true, "before write");
                check_flash_range(16#1000#, 64, false, "written");
                check_flash_range(16#1040#, 16, true, "after write");
                -- and it comes back through the read path too
                put_cmd(16#1000#, kind_read, 64);
                for i in 0 to 63 loop
                    get_byte(data);
                    check_equal(data, pattern_byte(16#1000# + i), "read back byte " & integer'image(i));
                end loop;
            elsif run("espi_write_crosses_page") then
                -- A page program wraps inside its page on the part, so the
                -- client has to split this into two programs itself
                put_payload(16#10F0#, 64);
                put_cmd(16#10F0#, kind_write, 64);
                check_status(x"00", "write status");
                check_flash_range(16#1000#, 16, true, "start of first page untouched");
                check_flash_range(16#10F0#, 64, false, "written across the boundary");
                check_flash_range(16#1130#, 16, true, "after write");
            elsif run("espi_write_max_payload_run") then
                -- Back to back writes of the channel's largest payload, as a
                -- host streaming an image would issue them
                for n in 0 to 7 loop
                    put_payload(16#2000# + n * 64, 64);
                    put_cmd(16#2000# + n * 64, kind_write, 64);
                    check_status(x"00", "write " & integer'image(n) & " status");
                end loop;
                check_flash_range(16#2000#, 512, false, "streamed");
            elsif run("espi_erase_4k") then
                fill_pattern(net, flash);
                put_cmd(16#2000#, kind_erase, erase_4k);
                check_status(x"00", "erase status");
                check_flash_range(16#1FF0#, 16, false, "before sector");
                check_flash_range(16#2000#, 16, true, "start of sector");
                check_flash_range(16#2FF0#, 16, true, "end of sector");
                check_flash_range(16#3000#, 16, false, "after sector");
            elsif run("espi_erase_64k") then
                fill_pattern(net, flash);
                put_cmd(16#0000#, kind_erase, erase_64k);
                check_status(x"00", "erase status");
                check_flash_range(16#0000#, 16, true, "start of block");
                check_flash_range(16#FFF0#, 16, true, "end of block");
            elsif run("espi_erase_unsupported_size") then
                fill_pattern(net, flash);
                put_cmd(16#2000#, kind_erase, erase_32k);
                check_status(x"01", "unsupported erase status");
                check_flash_range(16#2000#, 16, false, "untouched");
                -- the client is still alive afterwards
                put_cmd(16#2000#, kind_read, 4);
                for i in 0 to 3 loop
                    get_byte(data);
                    check_equal(data, pattern_byte(16#2000# + i), "read after refusal " & integer'image(i));
                end loop;
            end if;
        end loop;

        wait for 2 us;
        test_runner_cleanup(runner);
        wait;
    end process;

    test_runner_watchdog(runner, 20 ms);
end tb;
