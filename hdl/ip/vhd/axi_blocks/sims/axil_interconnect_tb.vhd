-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library vunit_lib;
    context vunit_lib.com_context;
    context vunit_lib.vunit_context;
    context vunit_lib.vc_context;
use vunit_lib.axi_lite_master_pkg.all;

use work.axil_common_pkg.all;
use work.axil_interconnect_sim_pkg.all;

entity axil_interconnect_tb is
    generic (
        runner_cfg : string
    );
end entity;

architecture tb of axil_interconnect_tb is

begin

    th: entity work.axil_interconnect_th;

    -- Note: external names are broken in the GHDL llvm backend
    -- (https://github.com/ghdl/ghdl/issues/2610) so this sim is nvc only.
    bench: process
        alias clk is <<signal .axil_interconnect_tb.th.clk : std_logic>>;
        alias reset is <<signal .axil_interconnect_tb.th.reset : std_logic>>;
        alias reset_force is <<signal .axil_interconnect_tb.th.reset_force : std_logic>>;

        alias man_mode is <<signal .axil_interconnect_tb.th.man_mode : std_logic>>;
        alias man_awvalid is <<signal .axil_interconnect_tb.th.man_awvalid : std_logic>>;
        alias man_awaddr is
            <<signal .axil_interconnect_tb.th.man_awaddr : std_logic_vector(INITIATOR_ADDR_WIDTH - 1 downto 0)>>;
        alias man_wvalid is <<signal .axil_interconnect_tb.th.man_wvalid : std_logic>>;
        alias man_wdata is <<signal .axil_interconnect_tb.th.man_wdata : std_logic_vector(31 downto 0)>>;
        alias man_wstrb is <<signal .axil_interconnect_tb.th.man_wstrb : std_logic_vector(3 downto 0)>>;
        alias man_bready is <<signal .axil_interconnect_tb.th.man_bready : std_logic>>;
        alias man_arvalid is <<signal .axil_interconnect_tb.th.man_arvalid : std_logic>>;
        alias man_araddr is
            <<signal .axil_interconnect_tb.th.man_araddr : std_logic_vector(INITIATOR_ADDR_WIDTH - 1 downto 0)>>;
        alias man_rready is <<signal .axil_interconnect_tb.th.man_rready : std_logic>>;

        alias init_awready is <<signal .axil_interconnect_tb.th.init_awready : std_logic>>;
        alias init_bvalid is <<signal .axil_interconnect_tb.th.init_bvalid : std_logic>>;
        alias init_bresp is <<signal .axil_interconnect_tb.th.init_bresp : std_logic_vector(1 downto 0)>>;
        alias init_rvalid is <<signal .axil_interconnect_tb.th.init_rvalid : std_logic>>;
        alias init_rdata is <<signal .axil_interconnect_tb.th.init_rdata : std_logic_vector(31 downto 0)>>;
        alias init_rresp is <<signal .axil_interconnect_tb.th.init_rresp : std_logic_vector(1 downto 0)>>;

        alias init_aw_hs is <<signal .axil_interconnect_tb.th.init_aw_hs : integer>>;
        alias init_b_hs is <<signal .axil_interconnect_tb.th.init_b_hs : integer>>;
        alias init_ar_hs is <<signal .axil_interconnect_tb.th.init_ar_hs : integer>>;
        alias init_r_hs is <<signal .axil_interconnect_tb.th.init_r_hs : integer>>;
        alias resp_aw_hs is <<signal .axil_interconnect_tb.th.resp_aw_hs : integer>>;
        alias resp_ar_hs is <<signal .axil_interconnect_tb.th.resp_ar_hs : integer>>;

        -- generous enough that a working fabric never hits it, short enough that
        -- a wedged one fails instead of running the watchdog out
        constant TXN_TIMEOUT : time := 5 us;

        variable rdata : std_logic_vector(31 downto 0);
        variable lat0 : integer;
        variable lat1 : integer;
        variable lat2 : integer;

        -- Every accepted write must produce exactly one B, every accepted read
        -- exactly one R, and (for mapped addresses) exactly one responder side
        -- address handshake. A duplicated write shows up as resp_aw_hs running
        -- ahead of init_aw_hs even when the data lands correctly.
        procedure check_handshake_accounting (
            signal net : inout network_t;
            constant mapped_only : boolean
        ) is
        begin
            -- writes are only queued by write_axi_lite, so let the bus
            -- functional model drain before counting anything
            wait_until_idle(net, bus_handle);
            check_equal(init_aw_hs, init_b_hs, "write address and write response handshakes disagree");
            check_equal(init_ar_hs, init_r_hs, "read address and read data handshakes disagree");
            if mapped_only then
                check_equal(resp_aw_hs, init_aw_hs, "responder saw a different number of writes than the initiator issued");
                check_equal(resp_ar_hs, init_ar_hs, "responder saw a different number of reads than the initiator issued");
            end if;
        end procedure;

        procedure clear_manual is
        begin
            man_awvalid <= '0';
            man_wvalid  <= '0';
            man_bready  <= '0';
            man_arvalid <= '0';
            man_rready  <= '0';
            wait until rising_edge(clk);
            man_mode <= '0';
            wait until rising_edge(clk);
        end procedure;

        -- Drive one write straight at the fabric, emulating the FMC target:
        -- AWVALID goes up first and WVALID only follows once the write data FIFO
        -- has something in it.
        procedure manual_write (
            constant addr        : in std_logic_vector;
            constant data        : in std_logic_vector(31 downto 0);
            constant aw_lead     : in integer;
            constant expect_resp : in std_logic_vector(1 downto 0)
        ) is
        begin
            man_mode    <= '1';
            man_awaddr  <= addr;
            man_wdata   <= data;
            man_wstrb   <= "1111";
            man_bready  <= '1';
            man_awvalid <= '1';
            man_wvalid  <= '0';

            -- While the initiator has only presented AW, the fabric must not
            -- accept the write. If it does, the FMC clears AWVALID early and
            -- then re-raises it, which is what wedges the bus.
            for i in 1 to aw_lead loop
                wait until rising_edge(clk);
                check_equal(init_awready, '0', "fabric asserted AWREADY before WVALID was presented");
            end loop;

            man_wvalid <= '1';
            wait until rising_edge(clk) and init_bvalid = '1' for TXN_TIMEOUT;
            check_equal(init_bvalid, '1', "timed out waiting for the write response");
            check_equal(init_bresp, expect_resp, "unexpected write response");
            wait until rising_edge(clk);
            man_awvalid <= '0';
            man_wvalid  <= '0';
            wait until rising_edge(clk);
        end procedure;

        procedure manual_read (
            constant addr        : in std_logic_vector;
            variable data        : out std_logic_vector(31 downto 0);
            constant expect_resp : in std_logic_vector(1 downto 0)
        ) is
        begin
            man_mode    <= '1';
            man_araddr  <= addr;
            man_rready  <= '1';
            man_arvalid <= '1';
            wait until rising_edge(clk) and init_rvalid = '1' for TXN_TIMEOUT;
            check_equal(init_rvalid, '1', "timed out waiting for read data");
            data := init_rdata;
            check_equal(init_rresp, expect_resp, "unexpected read response");
            wait until rising_edge(clk);
            man_arvalid <= '0';
            man_rready  <= '0';
            wait until rising_edge(clk);
        end procedure;

        --! Like manual_read, but also reports how many clocks the fabric took to
        --! answer, so the testbench can show the configured stages are really in
        --! the path rather than being generated away.
        procedure manual_read_timed (
            constant addr : in std_logic_vector;
            variable data : out std_logic_vector(31 downto 0);
            variable cycles : out integer
        ) is
            variable count : integer := 0;
        begin
            man_mode    <= '1';
            man_araddr  <= addr;
            man_rready  <= '1';
            man_arvalid <= '1';
            loop
                wait until rising_edge(clk);
                exit when init_rvalid = '1';
                count := count + 1;
                if count > 100 then
                    check(false, "timed out waiting for read data");
                    exit;
                end if;
            end loop;
            data   := init_rdata;
            cycles := count;
            man_arvalid <= '0';
            man_rready  <= '0';
            wait until rising_edge(clk);
        end procedure;

    begin
        test_runner_setup(runner, runner_cfg);
        wait until reset = '0';
        wait for 500 ns;

        while test_suite loop
            if run("write_read_each_responder") then
                for idx in config_array'range loop
                    write_axi_lite(net, bus_handle, ba(idx, 16#00#), x"C0DE0000" or w32(idx * 16));
                    write_axi_lite(net, bus_handle, ba(idx, 16#08#), x"FEED0000" or w32(idx * 16));
                end loop;
                -- read back after all the writes, so a fabric that leaks a write
                -- into the wrong responder is caught rather than masked
                for idx in config_array'range loop
                    check_axi_lite(net, bus_handle, ba(idx, 16#00#), axi_resp_okay,
                                   x"C0DE0000" or w32(idx * 16), "responder 0x00 readback");
                    check_axi_lite(net, bus_handle, ba(idx, 16#08#), axi_resp_okay,
                                   x"FEED0000" or w32(idx * 16), "responder 0x08 readback");
                end loop;
                check_handshake_accounting(net, mapped_only => true);

            elsif run("back_to_back_same_responder") then
                -- run the burst against every responder in turn, so token and
                -- payload reuse is covered at each configured pipe depth
                for idx in config_array'range loop
                    for word in 0 to 7 loop
                        write_axi_lite(net, bus_handle, ba(idx, 4 * word),
                                       x"A5A50000" or w32(16 * idx + word));
                    end loop;
                    for word in 0 to 7 loop
                        check_axi_lite(net, bus_handle, ba(idx, 4 * word), axi_resp_okay,
                                       x"A5A50000" or w32(16 * idx + word), "back to back readback");
                    end loop;
                end loop;
                check_handshake_accounting(net, mapped_only => true);

            elsif run("back_to_back_alternating") then
                -- alternate between the fastest and the slowest responder with no
                -- idle time in between
                for word in 0 to 7 loop
                    write_axi_lite(net, bus_handle, ba(SRAM_A_IDX, 4 * word), x"11110000" or w32(word));
                    write_axi_lite(net, bus_handle, ba(SLOW_IDX, 4 * word), x"22220000" or w32(word));
                end loop;
                for word in 0 to 7 loop
                    check_axi_lite(net, bus_handle, ba(SRAM_A_IDX, 4 * word), axi_resp_okay,
                                   x"11110000" or w32(word), "sram_a readback");
                    check_axi_lite(net, bus_handle, ba(SLOW_IDX, 4 * word), axi_resp_okay,
                                   x"22220000" or w32(word), "slow readback");
                end loop;
                check_handshake_accounting(net, mapped_only => true);

            elsif run("read_after_write_same_addr") then
                for idx in config_array'range loop
                    write_axi_lite(net, bus_handle, ba(idx, 16#10#), x"5A5A1234");
                    check_axi_lite(net, bus_handle, ba(idx, 16#10#), axi_resp_okay, x"5A5A1234",
                                   "read immediately after write");
                    write_axi_lite(net, bus_handle, ba(idx, 16#10#), x"A5A54321");
                    check_axi_lite(net, bus_handle, ba(idx, 16#10#), axi_resp_okay, x"A5A54321",
                                   "read immediately after overwrite");
                end loop;
                check_handshake_accounting(net, mapped_only => true);

            elsif run("unmapped_slverr") then
                -- the gap between the 8 bit responders and the wide one, the top
                -- of that gap, and an address past every responder
                write_axi_lite(net, bus_handle, ba(16#000300#), x"DEADDEAD", axi_resp_slverr);
                check_axi_lite(net, bus_handle, ba(16#000300#), axi_resp_slverr, x"DEADBEEF",
                               "unmapped read at 0x300");
                write_axi_lite(net, bus_handle, ba(16#007FFC#), x"DEADDEAD", axi_resp_slverr);
                check_axi_lite(net, bus_handle, ba(16#007FFC#), axi_resp_slverr, x"DEADBEEF",
                               "unmapped read at 0x7FFC");
                write_axi_lite(net, bus_handle, ba(16#010000#), x"DEADDEAD", axi_resp_slverr);
                check_axi_lite(net, bus_handle, ba(16#010000#), axi_resp_slverr, x"DEADBEEF",
                               "unmapped read at 0x10000");
                -- an unmapped access must not have disturbed a mapped one
                write_axi_lite(net, bus_handle, ba(SRAM_A_IDX, 16#04#), x"600D600D");
                check_axi_lite(net, bus_handle, ba(SRAM_A_IDX, 16#04#), axi_resp_okay, x"600D600D",
                               "mapped access after unmapped");
                check_handshake_accounting(net, mapped_only => false);

            elsif run("boundary_addresses") then
                -- first and last word of each mapped region, which is where an
                -- equality based decode and a magnitude compare could disagree
                write_axi_lite(net, bus_handle, ba(SRAM_A_IDX, 16#00#), x"00000001");
                write_axi_lite(net, bus_handle, ba(SRAM_A_IDX, 16#FC#), x"000000FC");
                write_axi_lite(net, bus_handle, ba(SRAM_B_IDX, 16#00#), x"00000100");
                write_axi_lite(net, bus_handle, ba(SRAM_B_IDX, 16#FC#), x"000001FC");
                write_axi_lite(net, bus_handle, ba(WIDE_IDX, 16#0000#), x"00008000");
                write_axi_lite(net, bus_handle, ba(WIDE_IDX, 16#0FFC#), x"00008FFC");

                -- 0x00 and 0xFC land in different words of sram_a, and sram_b's
                -- 0x100 must not have aliased on top of sram_a's 0x00
                check_axi_lite(net, bus_handle, ba(SRAM_A_IDX, 16#00#), axi_resp_okay, x"00000001",
                               "sram_a low boundary");
                check_axi_lite(net, bus_handle, ba(SRAM_A_IDX, 16#FC#), axi_resp_okay, x"000000FC",
                               "sram_a high boundary");
                check_axi_lite(net, bus_handle, ba(SRAM_B_IDX, 16#00#), axi_resp_okay, x"00000100",
                               "sram_b low boundary");
                check_axi_lite(net, bus_handle, ba(SRAM_B_IDX, 16#FC#), axi_resp_okay, x"000001FC",
                               "sram_b high boundary");
                check_axi_lite(net, bus_handle, ba(WIDE_IDX, 16#0000#), axi_resp_okay, x"00008000",
                               "wide low boundary");
                check_axi_lite(net, bus_handle, ba(WIDE_IDX, 16#0FFC#), axi_resp_okay, x"00008FFC",
                               "wide high boundary");
                check_handshake_accounting(net, mapped_only => true);

            elsif run("glitchy_aw_initiator") then
                manual_write(ba(SRAM_A_IDX, 16#10#), x"6060BEEF", 6, OKAY);
                clear_manual;
                check_axi_lite(net, bus_handle, ba(SRAM_A_IDX, 16#10#), axi_resp_okay, x"6060BEEF",
                               "readback after an AW leading write");
                check_handshake_accounting(net, mapped_only => true);

            elsif run("glitchy_aw_unmapped") then
                -- the catch-all responder is the one that used to assert AWREADY
                -- with no regard for WVALID
                manual_write(ba(16#000300#), x"6060BEEF", 6, SLVERR);
                clear_manual;
                check_axi_lite(net, bus_handle, ba(16#000300#), axi_resp_slverr, x"DEADBEEF",
                               "unmapped read after an AW leading write");
                check_handshake_accounting(net, mapped_only => false);

            elsif run("stuck_awvalid") then
                -- seed a known value in sram_a that the stuck write must not
                -- be able to shadow. write_axi_lite only queues the write, so
                -- wait for the bus functional model to actually retire it
                -- before taking the bus over by hand.
                write_axi_lite(net, bus_handle, ba(SRAM_A_IDX, 16#04#), x"600DF00D");
                wait_until_idle(net, bus_handle);

                man_mode    <= '1';
                man_awaddr  <= ba(SRAM_B_IDX, 16#00#);
                man_wdata   <= x"11112222";
                man_wstrb   <= "1111";
                man_bready  <= '1';
                man_awvalid <= '1';
                man_wvalid  <= '1';
                wait until rising_edge(clk) and init_bvalid = '1' for TXN_TIMEOUT;
                check_equal(init_bvalid, '1', "timed out waiting for the write response");
                wait until rising_edge(clk);

                -- the FMC only clears AWVALID on an AWREADY it happened to
                -- observe, so it can still be asserted here. The fabric has to
                -- tear the transaction down anyway and decode the next one.
                man_wvalid <= '0';
                man_bready <= '0';
                manual_read(ba(SRAM_A_IDX, 16#04#), rdata, OKAY);
                check_equal(rdata, std_logic_vector'(x"600DF00D"),
                            "read decoded against a stale write address");
                clear_manual;
                check_handshake_accounting(net, mapped_only => true);

            elsif run("pipe_latency") then
                -- sram_a has no pipe, sram_b has one stage and the wide responder
                -- two, so the answer must arrive strictly later each time
                write_axi_lite(net, bus_handle, ba(SRAM_A_IDX, 16#00#), x"00000011");
                write_axi_lite(net, bus_handle, ba(SRAM_B_IDX, 16#00#), x"00000022");
                write_axi_lite(net, bus_handle, ba(WIDE_IDX, 16#00#), x"00000033");
                wait_until_idle(net, bus_handle);

                manual_read_timed(ba(SRAM_A_IDX, 16#00#), rdata, lat0);
                check_equal(rdata, std_logic_vector'(x"00000011"), "unpiped readback");
                manual_read_timed(ba(SRAM_B_IDX, 16#00#), rdata, lat1);
                check_equal(rdata, std_logic_vector'(x"00000022"), "one stage readback");
                manual_read_timed(ba(WIDE_IDX, 16#00#), rdata, lat2);
                check_equal(rdata, std_logic_vector'(x"00000033"), "two stage readback");
                info("read latency in clocks: 0 stages=" & to_string(lat0) &
                     " 1 stage=" & to_string(lat1) & " 2 stages=" & to_string(lat2));
                check(lat1 > lat0, "the one stage pipe added no latency");
                check(lat2 > lat1, "the two stage pipe added no latency over one stage");
                clear_manual;
                check_handshake_accounting(net, mapped_only => true);

            elsif run("reset_mid_transaction") then
                -- kick off a read at the slow responder and reset while it is in
                -- flight, then confirm the fabric comes back clean
                man_mode    <= '1';
                man_araddr  <= ba(SLOW_IDX, 16#00#);
                man_rready  <= '1';
                man_arvalid <= '1';
                wait for 40 ns;
                reset_force <= '1';
                wait for 40 ns;
                man_arvalid <= '0';
                man_rready  <= '0';
                wait for 40 ns;
                reset_force <= '0';
                wait until reset = '0';
                wait for 200 ns;
                man_mode <= '0';
                wait for 200 ns;

                write_axi_lite(net, bus_handle, ba(SLOW_IDX, 16#00#), x"AF7E8E5E");
                check_axi_lite(net, bus_handle, ba(SLOW_IDX, 16#00#), axi_resp_okay, x"AF7E8E5E",
                               "slow responder after a mid transaction reset");
                write_axi_lite(net, bus_handle, ba(SRAM_A_IDX, 16#00#), x"C1EA4000");
                check_axi_lite(net, bus_handle, ba(SRAM_A_IDX, 16#00#), axi_resp_okay, x"C1EA4000",
                               "sram_a after a mid transaction reset");
                check_handshake_accounting(net, mapped_only => true);
            end if;
        end loop;

        wait for 2 us;
        test_runner_cleanup(runner);
        wait;
    end process;

    test_runner_watchdog(runner, 10 ms);

end tb;
