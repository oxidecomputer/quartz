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
        alias espi_owns_flash_hw is <<signal th.espi_owns_flash_hw : std_logic>>;
        alias espi_flush is <<signal th.espi_flush : std_logic>>;
        alias espi_flush_busy is <<signal th.espi_flush_busy : std_logic>>;
        alias hash_cmd_wdata is <<signal th.hash_cmd_wdata : std_logic_vector(31 downto 0)>>;
        alias hash_cmd_write is <<signal th.hash_cmd_write : std_logic>>;
        alias hash_data_rdata is <<signal th.hash_data_rdata : std_logic_vector(7 downto 0)>>;
        alias hash_data_rdack is <<signal th.hash_data_rdack : std_logic>>;
        alias hash_data_rempty is <<signal th.hash_data_rempty : std_logic>>;
        alias hash_bytes is <<signal th.hash_bytes : natural>>;
        constant flash : actor_t := find("spi_nor_target");

        -- Request kinds, as flash_channel_pkg.to_kind_bits encodes them in
        -- the top nibble of the length word
        constant kind_read : std_logic_vector(3 downto 0) := x"0";
        constant kind_write : std_logic_vector(3 downto 0) := x"1";
        constant kind_erase : std_logic_vector(3 downto 0) := x"2";
        -- SAFS (target attached) erase size codes, which are not the MAFS ones
        constant erase_4k : natural := 0;
        constant erase_32k : natural := 1;
        constant erase_64k : natural := 2;

        variable data : std_logic_vector(7 downto 0);
        variable spisr : std_logic_vector(31 downto 0);

        -- How long a byte that is owed may take to show up. A read that has
        -- been granted the engine delivers one in well under a microsecond,
        -- and the worst wait behind someone else's chunk is tens of them, so
        -- this only expires when the client has been left stranded, which is
        -- reported here rather than by the watchdog.
        constant byte_timeout : time := 500 us;

        procedure set_spicr(constant value : std_logic_vector(31 downto 0)) is
        begin
            write_bus(net, bus_handle, To_StdLogicVector(SPICR_OFFSET + 16#100#, bus_handle.p_address_length),
                      value);
            wait_until_idle(net, bus_handle);
        end procedure;


        -- Ask for a flush for as long as given, then wait for the controller
        -- to say it has finished. A write in flight is allowed its whole
        -- program time; nothing else comes close to the bound.
        procedure flush(constant width : time) is
        begin
            wait until rising_edge(clk);
            espi_flush <= '1';
            wait for width;
            wait until rising_edge(clk);
            espi_flush <= '0';
            wait until rising_edge(clk);
            if espi_flush_busy = '1' then
                wait until espi_flush_busy = '0' for 5 ms;
            end if;
            check_equal(espi_flush_busy, '0', "Expected the flush to finish");
        end procedure;

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

        -- A hash client command: raw address, then a byte count
        procedure put_hash_cmd(constant addr : natural; constant len : natural) is
        begin
            wait until rising_edge(clk);
            hash_cmd_wdata <= std_logic_vector(to_unsigned(addr, 32));
            hash_cmd_write <= '1';
            wait until rising_edge(clk);
            hash_cmd_wdata <= std_logic_vector(to_unsigned(len, 32));
            wait until rising_edge(clk);
            hash_cmd_write <= '0';
        end procedure;

        procedure get_hash_byte(variable b : out std_logic_vector(7 downto 0)) is
            constant deadline : time := now + byte_timeout;
        begin
            loop
                wait until rising_edge(clk);
                exit when hash_data_rempty = '0';
                if now > deadline then
                    check_failed("get_hash_byte: no byte within " & time'image(byte_timeout));
                    exit;
                end if;
            end loop;
            b := hash_data_rdata;
            hash_data_rdack <= '1';
            wait until rising_edge(clk);
            hash_data_rdack <= '0';
        end procedure;

        procedure get_byte(variable b : out std_logic_vector(7 downto 0)) is
            constant deadline : time := now + byte_timeout;
        begin
            loop
                wait until rising_edge(clk);
                exit when data_rempty = '0';
                if now > deadline then
                    check_failed("get_byte: no byte within " & time'image(byte_timeout));
                    exit;
                end if;
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
                -- and not a byte more: a read over a page is several flash
                -- transactions, and anything left over would lead the next
                -- read's data
                wait for 5 us;
                check_equal(data_rempty, '1', "Expected nothing left over after the read");
            elsif run("hash_waits_for_an_espi_read_in_flight") then
                -- A hash asked for part way through a multi-chunk eSPI read
                -- gets the bus only between transactions: the read comes
                -- through whole, and the hash runs after it. A read the host
                -- queued meanwhile is served between the hash's chunks, not
                -- after it.
                fill_pattern(net, flash);
                put_cmd(16#1000#, kind_read, 1000);
                for i in 0 to 99 loop
                    get_byte(data);
                    check_equal(data, pattern_byte(16#1000# + i), "read byte " & integer'image(i));
                end loop;
                put_hash_cmd(16#8000#, 600);
                put_cmd(16#3000#, kind_read, 40);
                for i in 100 to 999 loop
                    get_byte(data);
                    check_equal(data, pattern_byte(16#1000# + i), "read byte " & integer'image(i));
                end loop;
                check_equal(hash_bytes, 0, "Expected no hash bytes before the read finished");
                for i in 0 to 39 loop
                    get_byte(data);
                    check_equal(data, pattern_byte(16#3000# + i), "queued read byte " & integer'image(i));
                end loop;
                check(hash_bytes < 600, "Expected the queued read served before the hash finished");
                for i in 0 to 599 loop
                    get_hash_byte(data);
                    check_equal(data, pattern_byte(16#8000# + i), "hash byte " & integer'image(i));
                end loop;
            elsif run("espi_read_served_between_hash_chunks") then
                -- A read that arrives while a hash runs waits only for the
                -- chunk in flight, and the hash picks up where it left off.
                -- A second hash afterwards shows the parking leaves nothing
                -- behind.
                fill_pattern(net, flash);
                put_hash_cmd(16#4000#, 1500);
                wait until hash_bytes >= 256;
                put_cmd(16#3000#, kind_read, 64);
                for i in 0 to 63 loop
                    get_byte(data);
                    check_equal(data, pattern_byte(16#3000# + i), "read byte " & integer'image(i));
                end loop;
                check(hash_bytes < 1500, "Expected the read served before the hash finished");
                for i in 0 to 1499 loop
                    get_hash_byte(data);
                    check_equal(data, pattern_byte(16#4000# + i), "hash byte " & integer'image(i));
                end loop;
                put_hash_cmd(16#5000#, 300);
                for i in 0 to 299 loop
                    get_hash_byte(data);
                    check_equal(data, pattern_byte(16#5000# + i), "second hash byte " & integer'image(i));
                end loop;
            elsif run("hash_runs_between_back_to_back_espi_reads") then
                fill_pattern(net, flash);
                put_hash_cmd(16#6000#, 600);
                put_cmd(16#1000#, kind_read, 128);
                put_cmd(16#1080#, kind_read, 128);
                put_cmd(16#1100#, kind_read, 128);
                for i in 0 to 383 loop
                    get_byte(data);
                    check_equal(data, pattern_byte(16#1000# + i), "read byte " & integer'image(i));
                end loop;
                for i in 0 to 599 loop
                    get_hash_byte(data);
                    check_equal(data, pattern_byte(16#6000# + i), "hash byte " & integer'image(i));
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
            elsif run("hw_grant_alone_serves_espi") then
                -- Without either grant a request waits, untouched
                write_bus(net, bus_handle, To_StdLogicVector(SPICR_OFFSET + 16#100#, bus_handle.p_address_length),
                          x"00000000");
                wait_until_idle(net, bus_handle);
                fill_pattern(net, flash);
                put_cmd(16#3000#, kind_read, 8);
                wait for 20 us;
                check_equal(data_rempty, '1', "Expected no data without a grant");
                read_bus(net, bus_handle, To_StdLogicVector(SPISR_OFFSET + 16#100#, bus_handle.p_address_length), spisr);
                check_equal((spisr and SPISR_ESPI_OWNS_FLASH_MASK) = x"00000000", true,
                            "Expected SPISR to report the eSPI path not owning the flash");
                -- The hardware grant on its own is enough, with SPICR left clear
                espi_owns_flash_hw <= '1';
                for i in 0 to 7 loop
                    get_byte(data);
                    check_equal(data, pattern_byte(16#3000# + i), "read byte " & integer'image(i));
                end loop;
                read_bus(net, bus_handle, To_StdLogicVector(SPISR_OFFSET + 16#100#, bus_handle.p_address_length), spisr);
                check_equal((spisr and SPISR_ESPI_OWNS_FLASH_MASK) /= x"00000000", true,
                            "Expected SPISR to report the eSPI path owning the flash");

            elsif run("owner_change_waits_for_the_transaction") then
                -- Dropping the grant part way through a read must not split it
                write_bus(net, bus_handle, To_StdLogicVector(SPICR_OFFSET + 16#100#, bus_handle.p_address_length),
                          x"00000000");
                wait_until_idle(net, bus_handle);
                espi_owns_flash_hw <= '1';
                fill_pattern(net, flash);
                put_cmd(16#4000#, kind_read, 200);
                get_byte(data);
                check_equal(data, pattern_byte(16#4000#), "read byte 0");
                espi_owns_flash_hw <= '0';
                for i in 1 to 199 loop
                    get_byte(data);
                    check_equal(data, pattern_byte(16#4000# + i), "read byte " & integer'image(i));
                end loop;
                wait for 2 us;
                read_bus(net, bus_handle, To_StdLogicVector(SPISR_OFFSET + 16#100#, bus_handle.p_address_length), spisr);
                check_equal((spisr and SPISR_ESPI_OWNS_FLASH_MASK) = x"00000000", true,
                            "Expected ownership to go back once the read was over");

            elsif run("sp_register_path_after_grant_withdrawn") then
                -- The metro workflow: the host has the flash through the
                -- hardware grant, then the SP takes the mux by hand (which
                -- withdraws the grant) and programs and reads the part over
                -- its registers, with SPICR.sp5_owns_flash left clear.
                write_bus(net, bus_handle, To_StdLogicVector(SPICR_OFFSET + 16#100#, bus_handle.p_address_length),
                          x"00000000");
                wait_until_idle(net, bus_handle);
                fill_pattern(net, flash);
                espi_owns_flash_hw <= '1';
                put_cmd(16#5000#, kind_read, 4);
                for i in 0 to 3 loop
                    get_byte(data);
                    check_equal(data, pattern_byte(16#5000# + i), "host read byte " & integer'image(i));
                end loop;
                espi_owns_flash_hw <= '0';
                wait for 1 us;
                read_bus(net, bus_handle, To_StdLogicVector(SPISR_OFFSET + 16#100#, bus_handle.p_address_length), spisr);
                check_equal((spisr and SPISR_ESPI_OWNS_FLASH_MASK) = x"00000000", true,
                            "Expected the register path to own the flash once the grant is gone");
                check_jedec_id(net);
                check_flash_read(net, READ_DATA_4BYTE_OP, 0, 16#5000#, 16);
                check_program_readback(net, flash, 16#6000#);
                -- and handing it back works too
                espi_owns_flash_hw <= '1';
                put_cmd(16#5010#, kind_read, 4);
                for i in 0 to 3 loop
                    get_byte(data);
                    check_equal(data, pattern_byte(16#5010# + i), "host read again byte " & integer'image(i));
                end loop;

            elsif run("hash_runs_with_a_host_read_pending_and_the_sp_owning") then
                -- The host has asked for a read while the SP holds the
                -- flash, so the read sits in the command queue and stays
                -- there. A hash asked for now must not queue behind it:
                -- nothing is going to serve that read until the SP hands
                -- the flash over, which it does only after it has measured.
                set_spicr(x"00000000");
                fill_pattern(net, flash);
                put_cmd(16#3000#, kind_read, 8);
                wait for 5 us;
                put_hash_cmd(16#8000#, 600);
                for i in 0 to 599 loop
                    get_hash_byte(data);
                    check_equal(data, pattern_byte(16#8000# + i), "hash byte " & integer'image(i));
                end loop;
                check_equal(data_rempty, '1', "Expected the host's read left alone while the SP owns the flash");
                -- and the host gets its read once it is given the flash
                set_spicr(SPICR_SP5_OWNS_FLASH_MASK);
                for i in 0 to 7 loop
                    get_byte(data);
                    check_equal(data, pattern_byte(16#3000# + i), "pending read byte " & integer'image(i));
                end loop;

            elsif run("host_read_arriving_mid_hash_with_the_sp_owning") then
                -- The same, with the hash already under way: stepping aside
                -- between chunks for a read nobody will serve would park the
                -- hash for good.
                set_spicr(x"00000000");
                fill_pattern(net, flash);
                put_hash_cmd(16#4000#, 1500);
                wait until hash_bytes >= 256;
                put_cmd(16#3000#, kind_read, 64);
                for i in 0 to 1499 loop
                    get_hash_byte(data);
                    check_equal(data, pattern_byte(16#4000# + i), "hash byte " & integer'image(i));
                end loop;
                check_equal(data_rempty, '1', "Expected the host's read left alone while the SP owns the flash");
                set_spicr(SPICR_SP5_OWNS_FLASH_MASK);
                for i in 0 to 63 loop
                    get_byte(data);
                    check_equal(data, pattern_byte(16#3000# + i), "pending read byte " & integer'image(i));
                end loop;
                -- with the host owning again a hash still shares with it
                put_hash_cmd(16#5000#, 300);
                for i in 0 to 299 loop
                    get_hash_byte(data);
                    check_equal(data, pattern_byte(16#5000# + i), "second hash byte " & integer'image(i));
                end loop;

            elsif run("owner_withdrawn_as_a_command_arrives") then
                -- The flash is taken from the host around the moment one of
                -- its commands lands, at every alignment of the two. The
                -- command is either served or left queued, and in both
                -- cases comes out whole once the host has the flash back.
                -- What must not happen is the client taking the command on
                -- the very edge it loses the engine: its go is then muxed
                -- out, it never returns to idle, and since ownership only
                -- moves while it is idle the flash can never be handed back.
                set_spicr(x"00000000");
                fill_pattern(net, flash);
                for drop_at in 0 to 15 loop
                    espi_owns_flash_hw <= '1';
                    wait for 2 us;
                    wait until rising_edge(clk);
                    for cycle in 0 to 15 loop
                        if cycle = drop_at then
                            espi_owns_flash_hw <= '0';
                        end if;
                        if cycle = 4 then
                            cmd_wdata <= std_logic_vector(to_unsigned(16#2000# + 16 * drop_at, 32));
                            cmd_write <= '1';
                        elsif cycle = 5 then
                            cmd_wdata <= kind_read & std_logic_vector(to_unsigned(4, 28));
                        elsif cycle = 6 then
                            cmd_write <= '0';
                        end if;
                        wait until rising_edge(clk);
                    end loop;
                    wait for 20 us;
                    espi_owns_flash_hw <= '1';
                    for i in 0 to 3 loop
                        get_byte(data);
                        check_equal(data, pattern_byte(16#2000# + 16 * drop_at + i),
                                    "grant dropped at cycle " & integer'image(drop_at) & ", byte " & integer'image(i));
                    end loop;
                    wait for 2 us;
                    check_equal(data_rempty, '1', "Expected nothing left over, grant dropped at cycle " & integer'image(drop_at));
                    -- the SP's own path has to work in between as well
                    espi_owns_flash_hw <= '0';
                    wait for 1 us;
                    check_jedec_id(net);
                end loop;

            elsif run("flush_drops_a_command_the_sp_never_served") then
                -- The host asked for a read while the SP held the flash and
                -- then went away. The flush that follows takes the command
                -- out of the queue without the eSPI path ever owning the
                -- flash, so it is not what the host is handed first when it
                -- next boots.
                set_spicr(x"00000000");
                fill_pattern(net, flash);
                put_cmd(16#3000#, kind_read, 8);
                wait for 5 us;
                flush(1 us);
                set_spicr(SPICR_SP5_OWNS_FLASH_MASK);
                wait for 50 us;
                check_equal(data_rempty, '1', "Expected the flushed read never to run");
                put_cmd(16#4000#, kind_read, 8);
                for i in 0 to 7 loop
                    get_byte(data);
                    check_equal(data, pattern_byte(16#4000# + i), "read after the flush, byte " & integer'image(i));
                end loop;

            elsif run("flush_drops_a_deep_queue_on_a_short_request") then
                -- The request is a few cycles long, the queue much deeper;
                -- the controller has to keep draining after it, and say so.
                set_spicr(x"00000000");
                fill_pattern(net, flash);
                for i in 0 to 19 loop
                    put_cmd(16#3000# + 16 * i, kind_read, 8);
                end loop;
                put_payload(16#7000#, 600);
                flush(40 ns);
                set_spicr(SPICR_SP5_OWNS_FLASH_MASK);
                wait for 50 us;
                check_equal(data_rempty, '1', "Expected none of the flushed reads to run");
                -- a stale payload byte would lead this write's own
                put_payload(16#5000#, 16);
                put_cmd(16#5000#, kind_write, 16);
                check_status(x"00", "write after the flush");
                check_flash_range(16#5000#, 16, false, "written after the flush");

            elsif run("flush_during_a_read") then
                -- A read in flight is not reported any further and stops at
                -- the end of its chunk. The bytes already handed over are
                -- the reader's to throw away, as the flash channel does.
                fill_pattern(net, flash);
                put_cmd(16#1000#, kind_read, 1000);
                for i in 0 to 9 loop
                    get_byte(data);
                    check_equal(data, pattern_byte(16#1000# + i), "read byte " & integer'image(i));
                end loop;
                flush(1 us);
                wait for 1 us;
                while data_rempty = '0' loop
                    get_byte(data);
                end loop;
                -- long enough for the other three chunks, had they been run
                wait for 200 us;
                check_equal(data_rempty, '1', "Expected nothing more from the flushed read");
                put_cmd(16#2000#, kind_read, 300);
                for i in 0 to 299 loop
                    get_byte(data);
                    check_equal(data, pattern_byte(16#2000# + i), "read after the flush, byte " & integer'image(i));
                end loop;

            elsif run("flush_lets_a_write_in_flight_finish") then
                -- A program that has started has to complete on the part,
                -- with the payload it was promised; only its status goes
                -- unreported.
                put_payload(16#6000#, 300);
                put_cmd(16#6000#, kind_write, 300);
                wait for 20 us;
                flush(1 us);
                wait for 1 us;
                check_equal(data_rempty, '1', "Expected no status from a flushed write");
                check_flash_range(16#6000#, 300, false, "written through the flush");
                fill_pattern(net, flash);
                put_cmd(16#2000#, kind_read, 4);
                for i in 0 to 3 loop
                    get_byte(data);
                    check_equal(data, pattern_byte(16#2000# + i), "read after the flush, byte " & integer'image(i));
                end loop;

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
