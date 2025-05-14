-- Adapted by Oxide from Verilog code by Chuck Benz,
-- with the following license from https://asics.chuckbenz.com/encode.v:
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

entity encode_8b10b is
    port(
        datain  : in  std_logic_vector(8 downto 0);
        dispin  : in  std_logic;  -- 0 = neg disp, 1 = pos disp

        dataout : out std_logic_vector(9 downto 0);
        dispout : out std_logic
    );
end encode_8b10b;

architecture rtl of encode_8b10b is
    alias ai is datain(0);
    alias bi is datain(1);
    alias ci is datain(2);
    alias di is datain(3);
    alias ei is datain(4);
    alias fi is datain(5);
    alias gi is datain(6);
    alias hi is datain(7);
    alias ki is datain(8);

    signal ao  : std_logic;
    signal bo  : std_logic;
    signal co  : std_logic;
    signal d_o : std_logic;
    signal eo  : std_logic;
    signal fo  : std_logic;
    signal go  : std_logic;
    signal ho  : std_logic;
    signal io  : std_logic;
    signal jo  : std_logic;

    signal aeqb  : std_logic;
    signal ceqd  : std_logic;
    signal ndos6 : std_logic;
    signal pdos6 : std_logic;
    signal ndos4 : std_logic;
    signal pdos4 : std_logic;

    signal l22 : std_logic;
    signal l40 : std_logic;
    signal l04 : std_logic;
    signal l13 : std_logic;
    signal l31 : std_logic;

    signal nd1s4 : std_logic;
    signal pd1s4 : std_logic;
    signal pd1s6 : std_logic;
    signal nd1s6 : std_logic;
    signal alt7  : std_logic;

    signal alt7partial : std_logic;
    signal illegalk : std_logic;

    signal compls6  : std_logic;
    signal compls4  : std_logic;

    signal disp6 : std_logic;

begin

    aeqb <= (ai and bi) or ((not ai) and (not bi));
    ceqd <= (ci and di) or ((not ci) and (not di));
    l22  <= (ai and bi and (not ci) and (not di)) or 
            (ci and di and (not ai) and (not bi)) or 
            ((not aeqb) and (not ceqd));
    l40  <= ai and bi and ci and di;
    l04  <= (not ai) and (not bi) and (not ci) and (not di);
    l13  <= ((not aeqb) and (not ci) and (not di)) or 
            ((not ceqd) and (not ai) and (not bi));
    l31  <= ((not aeqb) and ci and di) or 
            ((not ceqd) and ai and bi);

    -- the 5b/6b encoding
    ao  <= ai;
    bo  <= (bi and (not l40)) or l04;
    co  <= l04 or ci or (ei and di and (not ci) and (not bi) and (not ai));
    d_o <= di and (not (ai and bi and ci));  -- note: "do" is a reserved word in vhdl
    eo  <= (ei or l13) and (not (ei and di and (not ci) and (not bi) and (not ai)));
    io  <= (l22 and (not ei)) or 
           (ei and (not di) and (not ci) and (not (ai and bi))) or -- D16, D17, D18
           (ei and l40) or 
           (ki and ei and di and ci and (not bi) and (not ai)) or -- K.28
           (ei and (not di) and ci and (not bi) and (not ai));

    -- pds16 indicates cases where d-1 is assumed + to get our encoded value
    pd1s6 <= (ei and di and (not ci) and (not bi) and (not ai)) or ((not ei) and (not l22) and (not l31));
    -- nds16 indicates cases where d-1 is assumed - to get our encoded value
    nd1s6 <= (ki or (ei and (not l22) and (not l13)) or ((not ei) and (not di) and ci and bi and ai));

    -- ndos6 is pds16 cases where d-1 is + yields - disp out - all of them
    ndos6 <= pd1s6;
    -- pdos6 is nds16 cases where d-1 is - yields + disp out - all but one
    pdos6 <= ki or (ei and (not l22) and (not l13));

    -- some Dx.7 and all Kx.7 cases result in run length of 5 case unless
    -- an alternate coding is used (referred to as Dx.A7, normal is Dx.P7)
    -- specifically, D11, D13, D14, D17, D18, D19.
    alt7partial <= (not ei) and di and l31 when dispin = '1' else (ei and (not di) and l13);

    alt7 <= fi and gi and hi and (ki or alt7partial);

    fo <= fi and (not alt7);
    go <= gi or ((not fi) and (not gi) and (not hi));
    ho <= hi;
    jo <= ((not hi) and (gi xor fi)) or alt7;

    -- nd1s4 is cases where d-1 is assumed - to get our encoded value
    nd1s4 <= fi and gi;
    -- pd1s4 is cases where d-1 is assumed + to get our encoded value
    pd1s4 <= ((not fi) and (not gi)) or (ki and ((fi and (not gi)) or ((not fi) and gi)));

    -- ndos4 is pd1s4 cases where d-1 is + yields - disp out - just some
    ndos4 <= ((not fi) and (not gi));
    -- pdos4 is nd1s4 cases where d-1 is - yields + disp out
    pdos4 <= fi and gi and hi;

    -- only legal K codes are K28.0->.7, K23/27/29/30.7
    --  K28.0->7 is ei=di=ci=1,bi=ai=0
    --  K23 is 10111
    --  K27 is 11011
    --  K29 is 11101
    --  K30 is 11110 - so K23/27/29/30 are ei & l31
    -- not used in design but may be fished out for sim??
    illegalk <= ki and
                (ai or bi or (not ci) or (not di) or (not ei)) and -- not K28.0->7
                ((not fi) or (not gi) or (not hi) or (not ei) or (not l31)); -- not K23/27/29/30.7

    -- now determine whether to do the complementing
    -- complement if prev disp is - and pd1s6 is set, or + and nd1s6 is set
    compls6 <= (pd1s6 and (not dispin)) or (nd1s6 and dispin);

    -- disparity out of 5b6b is disp in with pdso6 and ndso6
    -- pds16 indicates cases where d-1 is assumed + to get our encoded value
    -- ndos6 is cases where d-1 is + yields - disp out
    -- nds16 indicates cases where d-1 is assumed - to get our encoded value
    -- pdos6 is cases where d-1 is - yields + disp out
    -- disp toggles in all ndis16 cases, and all but that 1 nds16 case
    disp6 <= dispin xor (ndos6 or pdos6);

    compls4 <= (pd1s4 and (not disp6)) or (nd1s4 and disp6);
    dispout <= disp6 xor (ndos4 or pdos4);

    dataout(9) <= jo xor compls4;
    dataout(8) <= ho xor compls4;
    dataout(7) <= go xor compls4;
    dataout(6) <= fo xor compls4;
    dataout(5) <= io xor compls6;
    dataout(4) <= eo xor compls6;
    dataout(3) <= d_o xor compls6;
    dataout(2) <= co xor compls6;
    dataout(1) <= bo xor compls6;
    dataout(0) <= ao xor compls6;
end rtl;