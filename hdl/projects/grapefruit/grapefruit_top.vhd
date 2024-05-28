library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity grapefruit_top is
    port (
        clk   : in    std_logic;
        reset_l : in    std_logic;

        ledn : out   std_logic
    );
end entity;

architecture rtl of grapefruit_top is

    signal counter : unsigned(31 downto 0);

begin

    tst : process (clk, reset_l)
    begin
        if reset_l = '0' then
            counter <= (others => '0');
        elsif rising_edge(clk) then
            counter <= counter + 1;
        end if;
    end process;

    ledn <= not counter(26);

end rtl;
