-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Simulation-only 1000BASE-X / SGMII transmit-conformance monitor. Attach it to
-- a PCS tx_code stream in a test harness; every checked property failing fails
-- the VUnit test. It exists because a partner with a hard Clause-36 PCS rejects
-- streams our own (deliberately permissive) soft PCS RX accepts, so loopback
-- testbenches alone cannot catch these bugs. Checked per code group, against
-- the golden encode tables in helper_8b10b_pkg (never hand-rolled 8b10b):
--
--   * legal D/K code for the tracked running disparity (disparity violations
--     and invalid patterns reported distinctly);
--   * ordered-set position parity: K28.5 and /S/ only at even positions -- /S/
--     replaces the idle comma, it does not follow it;
--   * idle set structure (K28.5 + D5.6/D16.2) and config set structure
--     (K28.5 + D21.5/D2.2 + two config bytes), never truncated;
--   * every idle ordered set leaves the running disparity at RD- (a correct
--     /I1//I2/ choice restores RD- within one set from either entry disparity);
--   * end of packet: /T/ then /R/, plus a second /R/ exactly when /T/ fell on
--     an odd position, so idle always resumes on an even boundary.
--
-- The monitor re-acquires (waits for a comma) after an invalid code group so a
-- single failure does not cascade into hundreds of follow-on reports.

library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

library vunit_lib;
    context vunit_lib.vunit_context;

use work.helper_8b10b_pkg.all;

entity sgmii_conformance_mon is
    generic (
        name : string := "sgmii_conf_mon"
    );
    port (
        clk        : in    std_logic;
        reset      : in    std_logic;
        code       : in    std_logic_vector(9 downto 0);
        code_valid : in    std_logic
    );
end entity;

architecture mon of sgmii_conformance_mon is

    type sym_kind_t is (SYM_DATA, SYM_COMMA, SYM_S, SYM_T, SYM_R, SYM_V, SYM_OTHER_K, SYM_NONE);

    type class_t is record
        found  : boolean;
        kind   : sym_kind_t;
        byte   : std_logic_vector(7 downto 0);
        rd_out : std_logic;
    end record;

    -- Reverse lookup by brute force against the encode tables: a code group is
    -- legal at running disparity `rd` iff some D or K byte encodes to it.
    function classify (
        cg : std_logic_vector(9 downto 0);
        rd : std_logic
    ) return class_t is
        type k_arr_t is array (natural range <>) of std_logic_vector(7 downto 0);
        constant KS : k_arr_t := (K28_5, K27_7, K29_7, K23_7, K30_7,
                                  K28_0, K28_1, K28_2, K28_3, K28_4, K28_6, K28_7);
        variable e : encoded_8b10b_t;
        variable r : class_t := (found => false, kind => SYM_NONE,
                                 byte => (others => '0'), rd_out => rd);
    begin
        for d in 0 to 255 loop
            e := encode_data(std_logic_vector(to_unsigned(d, 8)), rd);
            if e.data = cg then
                r.found  := true;
                r.kind   := SYM_DATA;
                r.byte   := std_logic_vector(to_unsigned(d, 8));
                r.rd_out := e.disparity;
                return r;
            end if;
        end loop;
        for i in KS'range loop
            e := encode_k(KS(i), rd);
            if e.data = cg then
                r.found  := true;
                r.byte   := KS(i);
                r.rd_out := e.disparity;
                case KS(i) is
                    when K28_5  => r.kind := SYM_COMMA;
                    when K27_7  => r.kind := SYM_S;
                    when K29_7  => r.kind := SYM_T;
                    when K23_7  => r.kind := SYM_R;
                    when K30_7  => r.kind := SYM_V;
                    when others => r.kind := SYM_OTHER_K;
                end case;
                return r;
            end if;
        end loop;
        return r;
    end function;

    -- second code groups of idle / config ordered sets
    constant D5_6  : std_logic_vector(7 downto 0) := x"C5";
    constant D16_2 : std_logic_vector(7 downto 0) := x"50";
    constant D21_5 : std_logic_vector(7 downto 0) := x"B5";
    constant D2_2  : std_logic_vector(7 downto 0) := x"42";

    type mon_state_t is (M_UNLOCK, M_SET2, M_CFG3, M_CFG4, M_BOUND, M_FRAME, M_R1, M_R2);

begin

    monitor: process (clk) is
        variable c      : class_t;
        variable c_alt  : class_t;
        variable st     : mon_state_t := M_UNLOCK;
        variable rd     : std_logic   := '0';
        variable even   : boolean     := false;
        variable t_even : boolean     := false;
    begin
        if rising_edge(clk) then
            if reset = '1' then
                st := M_UNLOCK;
            elsif code_valid = '1' then
                if st = M_UNLOCK then
                    -- acquire: the first comma fixes both the running disparity
                    -- (each K28.5 variant is legal at exactly one) and parity
                    c := classify(code, '0');
                    if not (c.found and c.kind = SYM_COMMA) then
                        c := classify(code, '1');
                    end if;
                    if c.found and c.kind = SYM_COMMA then
                        rd   := c.rd_out;
                        even := true;
                        st   := M_SET2;
                    end if;
                else
                    even := not even;
                    c    := classify(code, rd);
                    if not c.found then
                        c_alt := classify(code, not rd);
                        if c_alt.found then
                            check_failed(name & ": running disparity violation on 0x"
                                         & to_hstring(code));
                            c := c_alt;   -- adopt and keep following the stream
                        else
                            check_failed(name & ": invalid code group 0x"
                                         & to_hstring(code));
                            st := M_UNLOCK;
                        end if;
                    end if;

                    if c.found then
                        rd := c.rd_out;
                        case st is
                            when M_SET2 =>
                                -- odd position: second code group of an ordered set
                                case c.kind is
                                    when SYM_DATA =>
                                        if c.byte = D5_6 or c.byte = D16_2 then
                                            check(rd = '0', name & ": idle ordered set left RD+ "
                                                  & "(wrong /I1//I2/ selection)");
                                            st := M_BOUND;
                                        elsif c.byte = D21_5 or c.byte = D2_2 then
                                            st := M_CFG3;
                                        else
                                            check_failed(name & ": illegal code group after comma: D 0x"
                                                         & to_hstring(c.byte));
                                            st := M_BOUND;
                                        end if;
                                    when SYM_S =>
                                        check_failed(name & ": /S/ at odd position "
                                                     & "(must replace the idle comma)");
                                        st := M_FRAME;   -- follow the frame anyway
                                    when SYM_COMMA =>
                                        check_failed(name & ": comma at odd position");
                                        even := true;    -- resync parity to this comma
                                        st   := M_SET2;
                                    when others =>
                                        check_failed(name & ": unexpected K code after comma");
                                        st := M_BOUND;
                                end case;

                            when M_CFG3 =>
                                check(c.kind = SYM_DATA,
                                      name & ": config ordered set truncated (expected config low byte)");
                                st := M_CFG4;

                            when M_CFG4 =>
                                check(c.kind = SYM_DATA,
                                      name & ": config ordered set truncated (expected config high byte)");
                                st := M_BOUND;

                            when M_BOUND =>
                                -- even position: an ordered set (or frame) starts here
                                case c.kind is
                                    when SYM_COMMA =>
                                        check(even, name & ": comma at odd position");
                                        st := M_SET2;
                                    when SYM_S =>
                                        check(even, name & ": /S/ at odd position");
                                        st := M_FRAME;
                                    when others =>
                                        check_failed(name & ": expected K28.5 or /S/ at ordered-set "
                                                     & "boundary, got 0x" & to_hstring(code));
                                        st := M_UNLOCK;
                                end case;

                            when M_FRAME =>
                                case c.kind is
                                    when SYM_DATA | SYM_V =>
                                        null;
                                    when SYM_T =>
                                        t_even := even;
                                        st     := M_R1;
                                    when others =>
                                        check_failed(name & ": illegal code group inside frame: 0x"
                                                     & to_hstring(code));
                                        st := M_UNLOCK;
                                end case;

                            when M_R1 =>
                                check(c.kind = SYM_R, name & ": /T/ must be followed by /R/");
                                if c.kind /= SYM_R then
                                    st := M_UNLOCK;
                                elsif t_even then
                                    st := M_BOUND;   -- /T/ even, /R/ odd: EPD complete
                                else
                                    st := M_R2;      -- /T/ odd: /T/R/R/ required
                                end if;

                            when M_R2 =>
                                check(c.kind = SYM_R,
                                      name & ": /T/ at odd position requires /T/R/R/ (second /R/ missing)");
                                if c.kind = SYM_R then
                                    st := M_BOUND;
                                else
                                    st := M_UNLOCK;
                                end if;

                            when M_UNLOCK =>
                                null;   -- handled before the case
                        end case;
                    end if;
                end if;
            end if;
        end if;
    end process;

end architecture;
