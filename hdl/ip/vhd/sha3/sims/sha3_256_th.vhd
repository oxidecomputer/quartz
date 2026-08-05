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

use work.axi_st8_pkg;
use work.basic_stream_pkg.all;
use work.keccak_pkg.all;

-- Both buffering configurations run side by side off the same test vectors, so
-- they cannot silently diverge. They get separate stream sources because their
-- backpressure differs by design: the single-buffered core stalls for each
-- permutation and the double-buffered one does not.
entity sha3_256_th is
    generic (
        CLK_PER_NS : positive := 8;
        SRC_SINGLE : basic_source_t;
        SRC_DOUBLE : basic_source_t
    );
end entity;

architecture th of sha3_256_th is

    constant CLK_PER_TIME : time := CLK_PER_NS * 1 ns;

    signal clk   : std_logic := '0';
    signal reset : std_logic := '1';

    signal init_gpio : std_logic_vector(0 downto 0);
    signal init      : std_logic;

    signal msg_single : axi_st8_pkg.axi_st_pkt_t;
    signal msg_double : axi_st8_pkg.axi_st_pkt_t;

    signal digest_single : digest_t;
    signal digest_double : digest_t;
    signal dv_single     : std_logic;
    signal dv_double     : std_logic;
    signal busy_single   : std_logic;
    signal busy_double   : std_logic;

begin

    clk   <= not clk after CLK_PER_TIME / 2;
    reset <= '0' after 200 ns;

    init <= init_gpio(0);

    init_gpios: entity work.sim_gpio
        generic map (
            out_num_bits => 1,
            in_num_bits  => 1,
            actor_name   => "init_gpio"
        )
        port map (
            clk      => clk,
            gpio_out => init_gpio
        );

    dut_single: entity work.sha3_256
        generic map (
            DOUBLE_BUFFER => false
        )
        port map (
            clk          => clk,
            reset        => reset,
            init         => init,
            busy         => busy_single,
            msg_if       => msg_single,
            digest       => digest_single,
            digest_valid => dv_single
        );

    dut_double: entity work.sha3_256
        generic map (
            DOUBLE_BUFFER => true
        )
        port map (
            clk          => clk,
            reset        => reset,
            init         => init,
            busy         => busy_double,
            msg_if       => msg_double,
            digest       => digest_double,
            digest_valid => dv_double
        );

    src_single_vc: entity work.basic_pkt_source
        generic map (
            SOURCE => SRC_SINGLE
        )
        port map (
            clk   => clk,
            ready => msg_single.ready,
            valid => msg_single.valid,
            last  => msg_single.last,
            data  => msg_single.data
        );

    src_double_vc: entity work.basic_pkt_source
        generic map (
            SOURCE => SRC_DOUBLE
        )
        port map (
            clk   => clk,
            ready => msg_double.ready,
            valid => msg_double.valid,
            last  => msg_double.last,
            data  => msg_double.data
        );

end th;
