-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2025 Oxide Computer Company

-- This block provides the logic and control register for the i2c mux
-- as well as the response logic for interfacing with the i2c_target_phy block

-- Write sequence:
-- START TGT_ADDR_BYTE TGT_ACK CTRL_REG_BYTE TGT_ACK/NACK STOP

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.numeric_std_unsigned.all;

use work.i2c_base_types_pkg.all;
use work.i2c_mux_regs_pkg.all;


entity pca9545ish_function is
    generic(
        -- i2c address of the mux
        i2c_addr : std_logic_vector(6 downto 0) := 7x"70"
    );
    port(
        clk : in std_logic;
        reset : in std_logic;
        mux_reset: in std_logic;
        mux_sel : out std_logic_vector(1 downto 0);
        allowed_to_enable : in std_logic;
        -- instruction interface
        inst_data : in std_logic_vector(7 downto 0);
        inst_valid : in std_logic;
        inst_ready : out std_logic;
        in_ack_phase: in std_logic;
        ack_next : out std_logic;
        txn_header : in i2c_header;
        -- response interface
        resp_data : out std_logic_vector(7 downto 0);
        resp_valid : out std_logic;
        resp_ready : in std_logic
    );


end entity;


architecture rtl of pca9545ish_function is
    function is_valid(
        data : std_logic_vector(7 downto 0);
        allowed_to_enable : std_logic) return boolean is
    begin
        -- allow only writes of 0 even when we're not allowed to enable
        if allowed_to_enable = '0' and data /= 0 then
            return false;
        end if;
        -- only allow clear and one-hot bits 0-2
        case data is
            when "00000000" => return true;
            when "00000001" => return true;
            when "00000010" => return true;
            when "00000100" => return true;
            when others => return false;
        end case;
    end function;

    function is_valid_write(hdr : i2c_header) return boolean is
    begin
        return hdr.valid = '1' and  hdr.read_write_n = '0';
    end function;

    signal control_reg : control_type;
    signal in_ack_phase_last : std_logic;
    signal is_our_transaction : std_logic;
begin

    inst_ready <= '1';  -- never block writes
    resp_valid <= '1'; -- never block reads
    resp_data <= pack(control_reg);  -- Only one register to read so hand it back always

    -- register block
    process(clk, reset)
    begin
        if reset then
            control_reg <= rec_reset;
            mux_sel <= "11";

        elsif rising_edge(clk) then
            if mux_reset then
                control_reg <= rec_reset;
            elsif inst_valid = '1' and inst_ready = '1' 
                    and is_valid(inst_data, allowed_to_enable) 
                    and is_valid_write(txn_header)
                    and is_our_transaction = '1' then
                control_reg <= unpack(inst_data);
            end if;

            -- register outputs to prevent any glitching since these control
            -- external mux lines.
            -- select decode, note that this is a bit strange and un-intuitive since
            -- A, B, C are not in any binary counting order.  Ask TI why this is the case :D
            -- (see the TMUX131 datasheet for more info)
            -- CHB enabled results from sel = 00
            -- CHC enabled results from sel = 01
            -- CHA enabled results from sel = 10
            mux_sel <=  "00" when control_reg.b1 = '1' else
                        "01" when control_reg.b2 = '1' else
                        "10" when control_reg.b0 = '1' else
                        "11";
        end if;
    end process;

    ack_logic: process(clk, reset)
    begin
        if reset then
            ack_next <= '0';
            in_ack_phase_last <= '0';
            is_our_transaction <= '0';
        elsif rising_edge(clk) then
            in_ack_phase_last <= in_ack_phase;
            if txn_header.valid = '0' then
                is_our_transaction <= '0';
            end if;

            -- We've finished the ack, clear the ack-next flag
            if in_ack_phase_last = '1' and in_ack_phase = '0' then
                ack_next <= '0';
            -- Ack on valid data when we're in the middle of a transaction (and we're being addressed)
            elsif inst_valid = '1' and inst_ready = '1' and is_valid(inst_data, allowed_to_enable) and is_our_transaction = '1' then
                ack_next <= '1';
            -- Ack on the address byte when we're in the start of a transaction and we're being addressed
            elsif txn_header.tgt_addr = i2c_addr and txn_header.valid = '1' and  is_our_transaction = '0' then
                is_our_transaction <= '1';
                ack_next <= '1';
            end if;
    
        end if;
    end process;
    

end rtl;