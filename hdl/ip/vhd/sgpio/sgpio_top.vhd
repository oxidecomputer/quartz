-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2024 Oxide Computer Company

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.numeric_std_unsigned.all;

use work.calc_pkg.all;

entity sgpio_top is
    generic(
        LD_DEFAULT: std_logic_vector(3 downto 0) := x"5";
        GPIO_WIDTH : integer;
        CLK_DIV : integer
    );
    port(
        clk : in std_logic;
        reset : in std_logic;
        -- Parallel interface
        gpio_in : in std_logic_vector(GPIO_WIDTH - 1 downto 0);
        gpio_out : out std_logic_vector(GPIO_WIDTH - 1 downto 0);
        -- output interface
        sclk : out std_logic;
        do : out std_logic;
        di : in std_logic;
        load : out std_logic
    );
end entity;

architecture rtl of sgpio_top is
    signal di_syncd : std_logic;

    -- SGPIO minimum size is 1 ending bit + 4 loads and 5 load low pulses
    constant MIN_BITS : integer := (1 + 4 + 5);
    constant TX_BITS : integer := maximum(GPIO_WIDTH, MIN_BITS);
    constant TX_CNTR_DONE : integer := TX_BITS - 1;

    constant LOAD_WORD : std_logic_vector(TX_BITS - 1 downto 0) := '1' & LD_DEFAULT & resize(x"0", TX_BITS - 5);
    signal bit_counter : std_logic_vector(log2ceil(TX_BITS) - 1 downto 0);
    signal sclk_gen_cntr : std_logic_vector(log2ceil(CLK_DIV) - 1 downto 0);
    signal load_en : std_logic;
    signal load_en_delay : std_logic;
    signal sclk_last : std_logic;
    signal ok_to_decode : std_logic;
    signal in_reg : std_logic_vector(GPIO_WIDTH - 1 downto 0);
    signal in_reg_valid : std_logic;


begin

    -- Gen divided clock
    process(clk, reset)
    begin
        if reset then
            sclk <= '0';
            sclk_last <= '0';
            sclk_gen_cntr <= (others => '0');
        elsif rising_edge(clk) then
            sclk_last <= sclk;
            if sclk_gen_cntr = CLK_DIV - 1 then
                sclk <= not sclk;
                sclk_gen_cntr <= (others => '0');
            else
                sclk_gen_cntr <= sclk_gen_cntr + 1;
            end if;
        end if;
    end process;

    -- sync counter
    process(clk, reset)
         variable sclk_redge : boolean := false;
    begin
        if reset then
            bit_counter <= (others => '0');
            load_en <= '0';
            load_en_delay <= '0';
        elsif rising_edge(clk) then
            sclk_redge := sclk = '1' and sclk_last = '0';
            if sclk_redge then
                load_en_delay <= load_en;
            end if;

            if sclk_redge and bit_counter = TX_CNTR_DONE then
                bit_counter <= (others => '0');
                load_en <= '1';
            elsif sclk_redge then
                bit_counter <= bit_counter + 1;
                load_en <= '0';
            end if;

        end if;
    end process;

    -- input sync
    sync: entity work.meta_sync
     port map(
        async_input => di,
        clk => clk,
        sycnd_output => di_syncd
    );

    -- for expediency, I'm setting this up like the ref platform
    -- where the first load-word bit is actually the *end* of the previous
    -- data. If we should desire to use this in a production system, I'd
    -- like to re-do this to more properly represent how the SGPIO protocol
    -- works, but for right now this is just to get a Ruby Dev system to
    -- power up.

    -- Use the output shift block to shift out the LOAD line, on load_en
    -- where as the acutal DI will use a delayed version of load_en to 
    -- align to the start of the frame.
    -- load shifter
    sgpio_load_shift_out_inst: entity work.sgpio_shift_out
     generic map(
        BIT_COUNT => TX_BITS
    )
     port map(
        clk => clk,
        reset => reset,
        sclk => sclk,
        do => load,
        out_reg => LOAD_WORD,
        out_reg_load_en => load_en
    );
    -- data out shifter
    sgpio_do_shift_out_inst: entity work.sgpio_shift_out
     generic map(
        BIT_COUNT => TX_BITS,
        INIT_VALUE => (others => '0')
    )
     port map(
        clk => clk,
        reset => reset,
        sclk => sclk,
        do => do,
        out_reg => gpio_in,
        out_reg_load_en => load_en_delay -- one clock behind
    );
    -- data in shifter
    sgpio_shift_in_inst: entity work.sgpio_shift_in
     generic map(
        BIT_COUNT => TX_BITS
    )
     port map(
        clk => clk,
        reset => reset,
        sclk => sclk,
        load => load,
        di => di_syncd,
        in_reg => in_reg,
        in_reg_valid => in_reg_valid
    );

    -- mask off rx'd data until we've seen a valid frame
    process(clk, reset)
    variable sclk_fedge : boolean := false;
    begin
        if reset then
            gpio_out <= (others => '0');
            ok_to_decode <= '0';
        elsif rising_edge(clk) then
            sclk_fedge := sclk = '0' and sclk_last = '1';
            if sclk_fedge and in_reg_valid = '1' and ok_to_decode = '1' then
                gpio_out <= in_reg(GPIO_WIDTH - 1 downto 0);
            elsif sclk_fedge and in_reg_valid = '1' then
                ok_to_decode <= '1';
            end if;
        end if;
    end process;


end rtl;