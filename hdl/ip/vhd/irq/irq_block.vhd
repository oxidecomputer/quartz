-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2026 Oxide Computer Company

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity irq_block is
    generic (
        IRQ_OUT_ACTIVE_HIGH : boolean;
        NUM_IRQS : natural
    );
    port (
        clk : in std_logic;
        reset : in std_logic;
        -- raw  IRQ, can be level or edge sensitive.
        -- if level, upstack code will need to clear the driving bit to prevent repeated interrupts.
        -- and just clearing the flag here will not be sufficient.
        irq_in : in std_logic_vector(NUM_IRQS - 1 downto 0);
        irq_en : in std_logic_vector(NUM_IRQS - 1 downto 0);
        level_edge_n : in std_logic_vector(NUM_IRQS - 1 downto 0);  -- 1 for level sensitive, 0 for edge sensitive
        irq_out : out std_logic_vector(NUM_IRQS - 1 downto 0);
        irq_clear : in std_logic_vector(NUM_IRQS - 1 downto 0);
        irq_force : in std_logic_vector(NUM_IRQS - 1 downto 0);
        irq_pin : out std_logic
        
    );
end entity;

architecture rtl of irq_block is
    constant IS_EDGE_SENSITIVE : std_logic := '0';
    constant IS_LEVEL_SENSITIVE : std_logic := '1';
    signal irq_in_last : std_logic_vector(irq_in'range);
    signal irq_reg : std_logic_vector(irq_in'range);
    
begin
    

    -- Register/latch the incoming IRQs.
    
    process(clk, reset)
        variable irq_redge : std_logic_vector(irq_in'range);
        variable irq_pin_int : std_logic;
    begin
        if reset then
            irq_out <= (others => '0');
            irq_reg <= (others => '0');
            irq_in_last <= (others => '0');
            irq_pin <= '0';
        elsif rising_edge(clk) then
            irq_redge := (irq_in and not irq_in_last);
            irq_in_last <= irq_in; -- this will support edge detection for edge sensitive IRQs.

            -- We need to properly handle the case where we're clearing the IRQ and
            -- it is set the 
            for i in irq_in'range loop
                -- Deal with rising edge or force first. These take precedence over any
                -- clearing of the IRQ so we don't miss one.
                if irq_redge(i) or irq_force(i) then
                    irq_reg(i) <= '1';
                elsif irq_clear(i) then
                    irq_reg(i) <= '0';
                end if;

                -- now deal with level vs edge sensitivity. If it's level sensitive, then we just need to mirror the input
                if level_edge_n(i) = IS_EDGE_SENSITIVE then
                    irq_out(i) <= irq_reg(i);
                else
                    irq_out(i) <= irq_in(i);
                end if;
            end loop;

            -- make the output pin registered since it could go chip-external
            -- this is an OR reduction
            irq_pin_int := or (irq_out and irq_en);
            if IRQ_OUT_ACTIVE_HIGH then
                irq_pin <= irq_pin_int;
            else
                irq_pin <= not irq_pin_int;
            end if;
                
        end if;
    end process;

end architecture;