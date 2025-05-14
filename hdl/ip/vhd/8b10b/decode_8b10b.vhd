-- Adapted by Oxide from Verilog code by Chuck Benz,
-- with the following license from https://asics.chuckbenz.com/decode.v:
-- Chuck Benz, Hollis, NH   Copyright (c)2002
--
-- The information and description contained herein is the
-- property of Chuck Benz.
--
-- Permission is granted for any reuse of this information
-- and description as long as this copyright notice is
-- preserved.  Modifications may be made as long as this
-- notice is preserved.

-- per Widmer and Franaszek

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity decode_8b10b is
    port(
        datain   : in  std_logic_vector(9 downto 0);
        dispin   : in  std_logic;

        dataout  : out std_logic_vector(8 downto 0);
        dispout  : out std_logic;

        code_err : out std_logic;
        disp_err : out std_logic
    );
end decode_8b10b;

architecture rtl of decode_8b10b is
    alias ai is datain(0);
    alias bi is datain(1);
    alias ci is datain(2);
    alias di is datain(3);
    alias ei is datain(4);
    alias ii is datain(5);
    alias fi is datain(6);
    alias gi is datain(7);
    alias hi is datain(8);
    alias ji is datain(9);

    signal aeqb : std_logic;
    signal ceqd : std_logic;
    signal p22  : std_logic;
    signal p13  : std_logic;
    signal p31  : std_logic;

    signal p40 : std_logic;
    signal p04 : std_logic;

    signal disp6a  : std_logic;
    signal disp6a2 : std_logic;
    signal disp6a0 : std_logic;

    signal disp6b : std_logic;

    -- The 5B/6B decoding special cases where ABCDE != abcde

    signal p22bceeqi   : std_logic;
    signal p22bncneeqi : std_logic;
    signal p13in       : std_logic;
    signal p31i        : std_logic;
    signal p13dei      : std_logic;
    signal p22aceeqi   : std_logic;
    signal p22ancneeqi : std_logic;
    signal p13en       : std_logic;
    signal anbnenin    : std_logic;
    signal abei        : std_logic;
    signal cndnenin    : std_logic;

    signal compa : std_logic;
    signal compb : std_logic;
    signal compc : std_logic;
    signal compd : std_logic;
    signal compe : std_logic;

    alias ao is dataout(0);
    alias bo is dataout(1);
    alias co is dataout(2);
    alias d_o is dataout(3);
    alias eo is dataout(4);
    alias fo is dataout(5);
    alias go is dataout(6);
    alias ho is dataout(7);
    alias ko is dataout(8);

    signal feqg    : std_logic;
    signal heqj    : std_logic;
    signal fghj22  : std_logic;
    signal fghjp13 : std_logic;
    signal fghjp31 : std_logic;
   
    signal k28p : std_logic;

    signal disp6p : std_logic;
    signal disp6n : std_logic;
    signal disp4p : std_logic;
    signal disp4n : std_logic;

    signal ei_eq_ii : std_logic;

begin

    aeqb <= (ai and bi) or ((not ai) and (not bi));
    ceqd <= (ci and di) or ((not ci) and (not di));
    p22  <= (ai and bi and (not ci) and (not di)) or 
            (ci and di and (not ai) and (not bi)) or 
            ((not aeqb) and (not ceqd));
    p13  <= ((not aeqb) and (not ci) and (not di)) or 
            ((not ceqd) and (not ai) and (not bi));
    p31  <= ((not aeqb) and ci and di) or 
            ((not ceqd) and ai and bi);
    p40  <= (ai and bi and ci and di);
    p04  <= (not ai) and (not bi) and (not ci) and (not di);

    disp6a  <= p31 or (p22 and dispin); -- pos disp if p22 and was pos, or p31.
    disp6a2 <= p31 and dispin; -- disp is ++ after 4 bits
    disp6a0 <= p13 and (not dispin); -- -- disp after 4 bits

    disp6b <= (((ei and ii and (not disp6a0)) or (disp6a and (ei or ii)) or disp6a2 or 
                (ei and ii and di)) and (ei or ii or di));

    -- The 5B/6B decoding special cases where ABCDE (NOT <= '1' when (  abcde
    ei_eq_ii <= '1' when ei = ii else '0';  -- hold this partial for use below

    p22bceeqi   <= p22 and bi and ci and ei_eq_ii;
    p22bncneeqi <= p22 and (not bi) and (not ci) and ei_eq_ii;
    p13in       <= p13 and (not ii);
    p31i        <= p31 and ii;
    p13dei      <= p13 and di and ei and ii;
    p22aceeqi   <= p22 and ai and ci and ei_eq_ii;
    p22ancneeqi <= p22 and (not ai) and (not ci) and ei_eq_ii;
    p13en       <= p13 and (not ei);
    anbnenin    <= (not ai) and (not bi) and (not ei) and (not ii);
    abei        <= ai and bi and ei and ii;
    cndnenin    <= (not ci) and (not di) and (not ei) and (not ii);

    compa <= p22bncneeqi or p31i or p13dei or p22ancneeqi or 
             p13en or abei or cndnenin;
    compb <= p22bceeqi or p31i or p13dei or p22aceeqi or 
             p13en or abei or cndnenin;
    compc <= p22bceeqi or p31i or p13dei or p22ancneeqi or 
             p13en or anbnenin or cndnenin;
    compd <= p22bncneeqi or p31i or p13dei or p22aceeqi or 
             p13en or abei or cndnenin;
    compe <= p22bncneeqi or p13in or p13dei or p22ancneeqi or 
             p13en or anbnenin or cndnenin;

    ao  <= ai xor compa;
    bo  <= bi xor compb;
    co  <= ci xor compc;
    d_o <= di xor compd;
    eo  <= ei xor compe;

    feqg    <= (fi and gi) or ((not fi) and (not gi));
    heqj    <= (hi and ji) or ((not hi) and (not ji));
    fghj22  <= (fi and gi and (not hi) and (not ji)) or 
               ((not fi) and (not gi) and hi and ji) or 
               ((not feqg) and (not heqj));
    fghjp13 <= ((not feqg) and (not hi) and (not ji)) or 
               ((not heqj) and (not fi) and (not gi));
    fghjp31 <= (((not feqg)) and hi and ji) or 
               ((not heqj) and fi and gi);

    dispout <= (fghjp31 or (disp6b and fghj22) or (hi and ji)) and (hi or ji);

    ko <= ((ci and di and ei and ii) or ((not ci) and (not di) and (not ei) and (not ii)) or 
           (p13 and (not ei) and ii and gi and hi and ji) or 
           (p31 and ei and (not ii) and (not gi) and (not hi) and (not ji)));

    -- k28 with positive disp into fghi - .1, .2, .5, and .6 special cases
    k28p <= not (ci or di or ei or ii);
    fo   <= (ji and (not fi) and (hi or (not gi) or k28p)) or 
            (fi and (not ji) and ((not hi) or gi or (not k28p))) or 
            (k28p and gi and hi) or 
            ((not k28p) and (not gi) and (not hi));
    go   <= (ji and (not fi) and (hi or (not gi) or (not k28p))) or 
            (fi and (not ji) and ((not hi) or gi or k28p)) or 
            ((not k28p) and gi and hi) or 
            (k28p and (not gi) and (not hi));
    ho   <= ((ji xor hi) and (not (((not fi) and gi and (not hi) and ji and (not k28p)) or ((not fi) and gi and hi and (not ji) and k28p) or 
                                   (fi and (not gi) and (not hi) and ji and (not k28p)) or (fi and (not gi) and hi and (not ji) and k28p)))) or 
            ((not fi) and gi and hi and ji) or (fi and (not gi) and (not hi) and (not ji));

    disp6p <= (p31 and (ei or ii)) or (p22 and ei and ii);
    disp6n <= (p13 and (not (ei and ii))) or (p22 and (not ei) and (not ii));
    disp4p <= fghjp31;
    disp4n <= fghjp13;

    code_err <= p40 or p04 or (fi and gi and hi and ji) or ((not fi) and (not gi) and (not hi) and (not ji)) or 
                (p13 and (not ei) and (not ii)) or (p31 and ei and ii) or 
                (ei and ii and fi and gi and hi) or ((not ei) and (not ii) and (not fi) and (not gi) and (not hi)) or 
                (ei and (not ii) and gi and hi and ji) or ((not ei) and ii and (not gi) and (not hi) and (not ji)) or 
                ((not p31) and ei and (not ii) and (not gi) and (not hi) and (not ji)) or 
                ((not p13) and (not ei) and ii and gi and hi and ji) or
                (((ei and ii and (not gi) and (not hi) and (not ji)) or 
                  ((not ei) and (not ii) and gi and hi and ji)) and 
                   (not ((ci and di and ei) or ((not ci) and (not di) and (not ei))))) or 
                (disp6p and disp4p) or (disp6n and disp4n) or 
                (ai and bi and ci and (not ei) and (not ii) and (((not fi) and (not gi)) or fghjp13)) or 
                ((not ai) and (not bi) and (not ci) and ei and ii and ((fi and gi) or fghjp31)) or 
                (fi and gi and (not hi) and (not ji) and disp6p) or 
                ((not fi) and (not gi) and hi and ji and disp6n) or 
                (ci and di and ei and ii and (not fi) and (not gi) and (not hi)) or 
                ((not ci) and (not di) and (not ei) and (not ii) and fi and gi and hi);

    -- my disp err fires for any legal codes that violate disparity, may fire for illegal codes
    disp_err <= ((dispin and disp6p) or (disp6n and (not dispin)) or 
                 (dispin and (not disp6n) and fi and gi) or 
                 (dispin and ai and bi and ci) or 
                 (dispin and (not disp6n) and disp4p) or 
                 ((not dispin) and (not disp6p) and (not fi) and (not gi)) or 
                 ((not dispin) and (not ai) and (not bi) and (not ci)) or 
                 ((not dispin) and (not disp6p) and disp4n) or 
                 (disp6p and disp4p) or (disp6n and disp4n));

end rtl;
