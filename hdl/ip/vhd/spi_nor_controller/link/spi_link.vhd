-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.numeric_std_unsigned.all;
use work.spi_nor_pkg.all;

entity spi_link is
    generic (
        -- Where to sample read data, in half-clk steps after the sclk rising
        -- edge. The round trip (clk to sclk pin, flash tCLQV, data back to the
        -- pin, pin to flop) does not scale with sclk, so at higher rates the
        -- sample point has to be placed deliberately rather than left at
        -- whatever the edge detector happens to produce. 2 reproduces the
        -- original one-clk-after-the-edge behaviour.
        rx_sample_taps : natural range 0 to 4 := 2
    );
    port (
        clk   : in    std_logic;
        reset : in    std_logic;
        -- system interface
        req_io_mode  : in    io_mode;
        divisor      : in    unsigned(15 downto 0);
        in_tx_phases : in    boolean;
        in_rx_phases : in    boolean;
        -- Lanes to stop driving early, ahead of a controller-to-flash
        -- turnaround, so the two ends are never enabled at once
        release_lanes : in    std_logic_vector(3 downto 0);
        rx_byte      : out   std_logic_vector(7 downto 0);
        rx_byte_done : out   boolean;
        tx_byte      : in    std_logic_vector(7 downto 0);
        -- Asserted the cycle before the edge on which a new tx byte is
        -- consumed. The transaction manager uses this both to advance its phase
        -- and to present the next byte, so that the byte and the sclk edge that
        -- launches it move together.
        tx_byte_req : out   boolean;
        sclk_redge  : out   boolean;
        sclk_fedge  : out   boolean;

        -- qspi interface
        cs_n  : in    std_logic;
        -- sclk as the internal logic sees it, for the transaction manager's
        -- phase counting
        sclk : out   std_logic;
        -- sclk for the pin only, so it can live in the IOB. See spi_clk_gen.
        sclk_pin : out   std_logic;
        io    : in    std_logic_vector(3 downto 0);
        io_o  : out   std_logic_vector(3 downto 0);
        io_oe : out   std_logic_vector(3 downto 0)
    );
end entity;

architecture rtl of spi_link is

    attribute mark_debug : string;

    constant SENTINEL_AT_TOP : std_logic_vector(8 downto 0) := "100000000";

    -- rx_sample_taps counts half-clks, but a capture flop only lets us pick a
    -- source (rising or falling phase) and how many whole clks later to use it.
    -- Odd taps come from the falling-edge capture, and the whole-clk part of
    -- the delay is the number of pipeline stages the sample pulse walks.
    constant SAMPLE_DELAY : natural := (rx_sample_taps + 1) / 2;
    constant SAMPLE_ON_NEG : boolean := (rx_sample_taps mod 2) = 1;

    signal tx_reg        : std_logic_vector(8 downto 0);
    signal rx_reg        : std_logic_vector(8 downto 0);
    attribute mark_debug of tx_reg        : signal is "TRUE";
    attribute mark_debug of rx_reg        : signal is "TRUE";
    signal sclk_last     : std_logic;
    signal sclk_int      : std_logic;
    signal sclk_fall_now : boolean;
    signal shift_amt     : integer range 1 to 4;
    signal csn_last      : std_logic;
    signal cur_io_mode   : io_mode;
    signal dbg_sclk_cnts : unsigned(31 downto 0);
    attribute mark_debug of dbg_sclk_cnts : signal is "TRUE";

    -- Dedicated input capture. These are the only loads on the io port pins,
    -- which is what makes the pin-to-flop delay bound in the XDC meaningful.
    signal io_cap_p : std_logic_vector(3 downto 0);
    signal io_cap_n : std_logic_vector(3 downto 0);
    signal io_n_q   : std_logic_vector(3 downto 0);
    signal io_tap   : std_logic_vector(3 downto 0);

    -- Sample pulse pipeline. Stage 0 is combinational and fires on the clk edge
    -- immediately after the sclk rising edge; each further stage is one clk
    -- later.
    signal sample_pipe : std_logic_vector(2 downto 0);
    signal sample_now  : boolean;

    -- Resolve the shifter into the four io lanes for the current mode. Lane 3
    -- carries the most significant bit in quad, lane 1 in dual, and lanes 1/3
    -- have to sit high otherwise so the part doesn't see a HOLD request.
    function io_out_bits (
        reg  : std_logic_vector(8 downto 0);
        mode : io_mode
    ) return std_logic_vector is
    begin
        case mode is
            when QUAD =>
                return reg(8 downto 5);
            when DUAL =>
                return '1' & reg(7) & reg(8) & reg(7);
            when SINGLE =>
                return '1' & reg(7) & '1' & reg(8);
        end case;
    end function;

    function shift_amt_of (
        mode : io_mode
    ) return integer is
    begin
        case mode is
            when QUAD =>
                return 4;
            when DUAL =>
                return 2;
            when SINGLE =>
                return 1;
        end case;
    end function;

begin

    sclk         <= sclk_int;
    shift_amt    <= shift_amt_of(cur_io_mode);
    rx_byte_done <= rx_reg(rx_reg'high) = '1';
    rx_byte      <= rx_reg(7 downto 0);

    clk_edge: process(clk, reset)
    begin
        if reset then
            sclk_last <= '0';
            dbg_sclk_cnts <= (others => '0');
        elsif rising_edge(clk) then
            sclk_last <= sclk_int;
            -- This is a simple sclk counter that is used for debugging
            -- purposes. I can be tricky to figure out where in the
            -- transaction you are, when using the ila, so this counter
            -- provides a way to know how many sclk cycles have passed
            -- on this chip-select cycle.
            if cs_n = '0' and sclk_redge then
                dbg_sclk_cnts <= dbg_sclk_cnts + 1;
            elsif cs_n = '1' then
                dbg_sclk_cnts <= (others => '0');
            end if;
        end if;
    end process;

    sclk_redge <= sclk_int = '1' and sclk_last = '0';
    sclk_fedge <= sclk_int = '0' and sclk_last = '1';

    -- spi clock gen block
    clk_gen: entity work.spi_clk_gen
        port map (
            clk           => clk,
            reset         => reset,
            divisor       => divisor,
            enable        => in_tx_phases or in_rx_phases,
            sclk          => sclk_int,
            sclk_pin      => sclk_pin,
            sclk_fall_now => sclk_fall_now
        );

    -- This is the main "output" serializer. The internal
    -- register is 9 bits wide using a sentinel value in the
    -- LSB so that we don't need bit counters here.
    -- We know we're done with a byte when the MSB is '1'
    -- and all the other bits are '0' b/c we've shifted the
    -- sentinel up 8x
    --
    -- Both the shifter and the io_o output register move on the same clk edge
    -- that drives the sclk falling edge, so mosi and sclk leave the FPGA
    -- together and the only skew left for the flash's setup time to absorb is
    -- the IOB and routing difference between the pins. Doing this a cycle later
    -- off an edge detector, as this used to, spends a whole clk period of the
    -- half-period budget and caps sclk at clk/4.
    serializer: process(clk, reset)
        variable cs_n_assert_edge : boolean := false;
        variable nxt_tx_reg       : std_logic_vector(8 downto 0);
        variable nxt_mode         : io_mode;
    begin
        if reset then
            tx_reg <= (others => '0');
            csn_last <= '1';
            cur_io_mode <= single;
            io_o <= (others => '1');
        elsif rising_edge(clk) then
            csn_last <= cs_n;
            cs_n_assert_edge := cs_n = '0' and csn_last = '1';

            -- The io mode only changes on a byte boundary, which is also when
            -- the shifter reloads, so the mode that applies to the bits going
            -- out at this edge is the one selected here.
            nxt_mode := cur_io_mode;
            if (cs_n = '0' and sclk_fall_now) or cs_n = '1' then
                nxt_mode := req_io_mode;
            end if;
            cur_io_mode <= nxt_mode;

            nxt_tx_reg := tx_reg;

            if cs_n_assert_edge then
                -- as the controller here, we need to pre-load data before the first
                -- clock
                nxt_tx_reg := tx_byte & '1';
            elsif in_tx_phases and sclk_fall_now then
                if shift_left(tx_reg, shift_amt) = SENTINEL_AT_TOP then
                    -- tx_register is "empty" load a new one
                    -- and the sentinel value
                    nxt_tx_reg := tx_byte & '1';
                else
                    nxt_tx_reg := shift_left(tx_reg, shift_amt);
                end if;
            elsif not in_tx_phases then
                nxt_tx_reg := (others => '0');
            end if;

            tx_reg <= nxt_tx_reg;
            io_o   <= io_out_bits(nxt_tx_reg, nxt_mode);
        end if;
    end process;

    -- Flag the reload a cycle ahead of the edge that consumes the byte so the
    -- transaction manager can present the right one. This is the same condition
    -- the serializer uses above, just not yet registered.
    tx_byte_req <= in_tx_phases and sclk_fall_now and
                   shift_left(tx_reg, shift_amt) = SENTINEL_AT_TOP;

    -- Based on state and qspi mode, deal with the tri-state controls
    -- of the spi pins
    -- Note this tracks req_io_mode, not the byte-aligned cur_io_mode. The
    -- latched mode is deliberately held until a falling edge so a byte is never
    -- split across two widths, but that leaves it reading `single` for the first
    -- cycles of a dual/quad read -- long enough to re-enable io3 for HOLD
    -- avoidance just as the part starts driving it. Direction has no reason to
    -- wait for a byte boundary, so it follows the transaction directly.
    oe_control: process(clk, reset)
        variable oe : std_logic_vector(3 downto 0);
    begin
        if reset then
            io_oe <= (others => '0');
        elsif rising_edge(clk) then
            if in_tx_phases then
                case req_io_mode is
                    when single =>
                        -- data going out 0 port, but need 3 port to be high so
                        -- chip doesn't see a HOLD operation
                        oe := (0 => '1', 3 => '1', others => '0');
                    when dual =>
                        -- data going out 0 port, but need 3 port to be high so
                        -- chip doesn't see a HOLD operation
                        oe := (1 downto 0 => '1', 3 => '1', others => '0');
                    when quad =>
                        oe := (others => '1');
                end case;
            else  -- rx only in all rx phases
                case req_io_mode is
                    when single =>
                        -- data coming in 1 port, but need 3 port to be high so
                        -- chip doesn't see a HOLD operation
                        oe := (3 => '1', others => '0');
                    when dual =>
                        -- data coming in 0, 1 ports, but need 3 port to be high so
                        -- chip doesn't see a HOLD operation
                        oe := ( 3 => '1', others => '0');
                    when quad =>
                        -- data coming in all ports, no outputs
                        oe := (others => '0');
                end case;
            end if;

            io_oe <= oe and not release_lanes;
        end if;
    end process;

    -- Input capture. Two flops, one per clk phase, so the sample point can be
    -- placed on a half-clk grid without needing a faster clock.
    capture_p: process(clk)
    begin
        if rising_edge(clk) then
            io_cap_p <= io;
            io_n_q   <= io_cap_n;
        end if;
    end process;

    capture_n: process(clk)
    begin
        if falling_edge(clk) then
            io_cap_n <= io;
        end if;
    end process;

    io_tap <= io_n_q when SAMPLE_ON_NEG else io_cap_p;

    -- Walk the sample pulse out to the requested whole-clk delay.
    --
    -- in_rx_phases is sampled here, when the pulse is injected, rather than
    -- where it is consumed. The phase advances on the clk edge right after the
    -- sclk edge, so a pulse still in the pipeline would otherwise be validated
    -- against a phase that has already moved on: the last dummy clock's pulse
    -- lands once rdata is active and steals a sample, shifting every subsequent
    -- byte by one group.
    sample_pipe(0) <= '1' when sclk_redge and in_rx_phases else '0';

    sample_pipeline: process(clk, reset)
    begin
        if reset then
            sample_pipe(2 downto 1) <= (others => '0');
        elsif rising_edge(clk) then
            sample_pipe(1) <= sample_pipe(0);
            sample_pipe(2) <= sample_pipe(1);
        end if;
    end process;

    sample_now <= sample_pipe(SAMPLE_DELAY) = '1';

    -- This is the main "input" deserializer. The internal
    -- register is 9 bits wide using a sentinel value in the
    -- LSB so that we don't need bit counters here.
    -- We know we're done shifting when the MSB is '1'
    -- This bit can also function as the valid flag
    deserializer: process(clk, reset)
    begin
        if reset then
            -- Uses a 9 bit shift register with a sentinel
            -- value of 1 in the lsb. We're done shifting when
            -- this bit makes it to the msb (ie we've shifted in
            -- a byte)
            rx_reg <= (rx_reg'low => '1', others => '0');
        elsif rising_edge(clk) then
            -- Do the sample/shift when requested and flag the
            -- valid bytes once we have them. sample_now is already qualified
            -- by in_rx_phases at the point the pulse was generated.
            if sample_now then
                -- Shift data by amount depending on mode
                rx_reg       <= shift_left(rx_reg, shift_amt);
                -- Sample new data into vacated locations
                if cur_io_mode = SINGLE then
                    rx_reg(0)    <= io_tap(1);
                elsif cur_io_mode = DUAL then
                    rx_reg(0)    <= io_tap(0);
                    rx_reg(1)    <= io_tap(1);
                elsif cur_io_mode = QUAD then
                    rx_reg(0) <= io_tap(0);
                    rx_reg(1) <= io_tap(1);
                    rx_reg(2) <= io_tap(2);
                    rx_reg(3) <= io_tap(3);
                end if;
            elsif not in_rx_phases or rx_reg(rx_reg'high) = '1' then
                -- Reset shifter to sentinel value when we become
                -- de-selected, or once we've strobed the valid
                rx_reg <= (rx_reg'low => '1', others => '0');
            end if;
        end if;
    end process;

end rtl;
