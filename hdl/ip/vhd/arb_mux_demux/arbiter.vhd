-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2024 Oxide Computer Company

-- Note: Documentation can be rendered in VSCode using the TerosHDL
-- plugin: https://terostechnology.github.io/terosHDLdoc/
--! A simple request arbiter that can do priority or round-robbin arbitration
--! Built generically using unconstrained arrays.
--! In Priority mode, the LSB (0) gets the highest priority.
--! In round-robbin mode, the LSB gets the priority only when there was not a grant in the previous
--! cycle and two requests occur simultaneously.
--! A goal is to do this in a single cycle, without having to scan the request bits so that
--! this scales well with increasing vectors.
--! This arbiter uses the fact that <number> AND <two's complement of number> gives
--! you a vector with the lowest (right-most) bit of <number> set

library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;
use work.arbiter_pkg.arbiter_mode;

entity arbiter is
    generic (

        --! Using arbiter_pkg.arbiter_mode enum, choose
        --! arbiter type
        mode : arbiter_mode
    );
    port (
        clk   : in    std_logic;
        reset : in    std_logic;
        --! Request vector blocks requesting arbitration must
        --! assert their request until grant has been asserted
        --! grant remains until request is de-asserted.
        requests : in    std_logic_vector;
        --! This block asserts grant signals, and holds them
        --! until the the associated request signal drops.
        grants : out   std_logic_vector
    );
end entity;

architecture rtl of arbiter is

    constant zeros                : unsigned(requests'range) := (others => '0');
    signal   requests_int         : unsigned(requests'range);
    signal   requests_masked_twos : unsigned(requests'range);
    signal   requests_masked      : unsigned(requests'range);
    signal   requests_last        : unsigned(requests'range);
    signal   grants_int           : unsigned(requests'range);
    signal   grants_last          : unsigned(requests'range);
    signal   grants_mask          : unsigned(requests'range);
    signal   req_vec_f_edge       : unsigned(requests'range);
    signal   req_f_edge           : std_logic;

begin

    requests_int <= unsigned(requests);

    round_robin_mode : if mode = ROUND_ROBIN generate
        -- This uses a grant-masking scheme to generate round-robin grant behavior.
        -- We want to mask off the previous granted channel and any lower bits
        -- so the upper bits get a round-robin chance.
        grants_mask <= not (grants_last or (grants_last - 1));

        -- Mask the requests based on the current grant mask, unless we have no active requests or grants, in
        -- which case, pass the unmasked vector through
        requests_masked <= requests_int and grants_mask when (requests_int and grants_mask) /= 0 else
                           requests_int;
    else generate
        -- In priority mode, we needn't mask grants since the priority encoder takes over
        -- and we will allow multiple grants to the same requester to the exclusion of others
        -- given the desired priority.
        grants_mask     <= (others => '0');
        requests_masked <= requests_int;
    end generate;

    -- Build two's complement, remember basic boolean math? 2's complement = (not <dat>) + 1
    requests_masked_twos <= (not requests_masked) + 1;

    fedge_detects : for i in requests_int'range generate
        req_vec_f_edge(i) <= '1' when requests_int(i) = '0' and requests_last(i) = '1' else
                             '0';
    end generate;

    -- Unary OR reduction, active when any bit is active
    req_f_edge <= or req_vec_f_edge;

    the_arbiter : process (clk)
    begin
        if reset then
            grants_int    <= zeros;
            grants_last   <= (others => '0');
            requests_last <= (others => '0');
        elsif rising_edge(clk) then
            -- Store history for edge detector
            requests_last <= requests_int;
            -- To determine a grant, we take the currently active requests vector,
            -- which is masked by the allowable requests in round-robbin mode, and then
            -- bitwise AND that with it's two's complement
            -- to get 1 bit active as our active grant.
            grants_int <= requests_masked and requests_masked_twos;
            if req_f_edge then
                -- Note: we expect requesters of this to hold request high until they both have the grant,
                -- and are finished with their current transaction. This means that falling edges of
                -- requests cause arbitration updates and we save the current grant for use in round-robin
                -- arbitration next time.
                grants_last <= grants_int;
            end if;
        end if;
    end process;

    grants <= std_logic_vector(grants_int);

end rtl;
