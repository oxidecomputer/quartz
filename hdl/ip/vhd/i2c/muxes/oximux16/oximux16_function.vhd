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
use work.oximux16_regs_pkg.all;


entity oximux16_function is
    generic(
        -- i2c address of the mux
        i2c_addr : std_logic_vector(6 downto 0) := 7x"70"
    );
    port(
        clk : in std_logic;
        reset : in std_logic;
        mux_reset: in std_logic;
        mux0_sel : out std_logic_vector(1 downto 0);
        mux1_sel : out std_logic_vector(1 downto 0);
        mux2_sel : out std_logic_vector(1 downto 0);
        mux3_sel : out std_logic_vector(1 downto 0);
        mux4_sel : out std_logic_vector(1 downto 0);
        mux_is_active : out std_logic;
        allowed_to_enable : in std_logic;
        start_condition : in std_logic;
        stop_condition : in std_logic;
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


architecture rtl of oximux16_function is
    function is_valid(
        reg0_pend : control0_type;
        data : std_logic_vector(7 downto 0);
        enable_allowed : std_logic) return boolean is
        variable unrolled_reg : std_logic_vector(15 downto 0);
        variable cnt_ones : integer range 0 to 16 := 0;
    begin
        -- allow only writes of 0 even when we're not allowed to enable
        if enable_allowed = '0' and (data /= 0 or std_logic_vector'(pack(reg0_pend)) /= 0) then
            return false;
        end if;
        unrolled_reg := data & std_logic_vector'(pack(reg0_pend));
        for i in 0 to 15 loop
           if unrolled_reg(i) = '1' then
               cnt_ones := cnt_ones + 1;
           end if;
        end loop;
         
        if cnt_ones > 1 then
            return false; -- we only allow 1-hot writes to the control registers
        end if;    
        if data(7) = '1' then
            return false; -- we don't allow writes to the reserved bit
        end if;
        return true;
    end function;

    function is_valid_write(hdr : i2c_header) return boolean is
    begin
        return hdr.valid = '1' and  hdr.read_write_n = '0';
    end function;

    signal control0_reg : control0_type;
    signal control0_reg_pend : control0_type;
    signal control1_reg : control1_type;
    signal control1_reg_pend : control1_type;
    signal in_ack_phase_last : std_logic;
    signal is_our_transaction : std_logic;
    signal wr_addr : std_logic;
    signal rd_addr : std_logic;
    type mux_sel_t is array (0 to 4) of std_logic_vector(1 downto 0);
    signal mux_sel : mux_sel_t;
    signal valid_write_pending : std_logic := '0';
begin

    inst_ready <= '1';  -- never block writes
    resp_valid <= '1'; -- never block reads
    resp_data <= pack(control0_reg) when rd_addr = '0' else pack(control1_reg);  -- Only one register to read so hand it back always

    mux0_sel <= mux_sel(0);
    mux1_sel <= mux_sel(1);
    mux2_sel <= mux_sel(2);
    mux3_sel <= mux_sel(3);
    mux4_sel <= mux_sel(4);

    -- pointer control
    process(clk, reset)
    begin
        if reset then
            wr_addr <= '0';
            rd_addr <= '0';
        elsif rising_edge(clk) then
            if mux_reset then
                wr_addr <= '0';
                rd_addr <= '0';
            elsif mux_reset = '1' or start_condition = '1' or stop_condition = '1' then
                wr_addr <= '0';
                rd_addr <= '0';
            else
                if inst_valid = '1' and inst_ready = '1' 
                    and is_our_transaction = '1' then
                    -- toggle the address pointer
                        wr_addr <= not wr_addr;
                end if;
                if resp_valid = '1' and resp_ready = '1' 
                    and is_our_transaction = '1' then
                        -- toggle the address pointer
                        rd_addr <= not rd_addr;
                end if;
            end if;

        end if;
    end process;

    -- register block
    process(clk, reset)
    begin
        if reset then
            control0_reg <= rec_reset;
            control0_reg_pend <= rec_reset;
            control1_reg <= rec_reset;
            control1_reg_pend <= rec_reset;
            valid_write_pending <= '0';
            mux_sel <= (others => (others => '1')); -- all muxes off
            

        elsif rising_edge(clk) then
            if mux_reset then
                control0_reg <= rec_reset;
                control0_reg_pend <= rec_reset;
                control1_reg <= rec_reset;
                control1_reg_pend <= rec_reset;
            elsif inst_valid = '1' and inst_ready = '1' 
                    and is_valid_write(txn_header)
                    and is_our_transaction = '1' then
                
                if wr_addr = '0' then
                    -- write to control0 register
                    -- we accept anything here but will check on the next write
                    control0_reg_pend <= unpack(inst_data);
                else
                    -- write to control1 register
                    if is_valid(control0_reg_pend, inst_data, allowed_to_enable) then
                        control1_reg_pend <= unpack(inst_data);
                        valid_write_pending <= '1';
                    end if;
                end if;
            elsif stop_condition = '1'  and valid_write_pending = '1' then
                -- commit the pending writes to the registers
                control0_reg <= control0_reg_pend;
                control1_reg <= control1_reg_pend;
                valid_write_pending <= '0';
            end if;

            -- register outputs to prevent any glitching since these control
            -- external mux lines.
            -- select decode, note that this is a bit strange and un-intuitive since
            -- A, B, C are not in any binary counting order.  Ask TI why this is the case :D
            -- (see the TMUX131 datasheet for more info)
            -- CHB enabled results from sel = 00
            -- CHC enabled results from sel = 01
            -- CHA enabled results from sel = 10
            mux_sel(0) <=   "10" when control0_reg.mux0_chA = '1' else -- MUX0 A
                            "00" when control0_reg.mux0_chB = '1' else -- MUX0 B
                            "01" when control0_reg.mux0_chC = '1' else -- MUX0 C
                            "11";
            mux_sel(1) <=   "10" when control0_reg.mux1_chA = '1' else -- MUX1 A
                            "00" when control0_reg.mux1_chB = '1' else -- MUX1 B
                            "01" when control0_reg.mux1_chC = '1' else -- MUX1 C
                            "11";
            mux_sel(2) <=   "10" when control0_reg.mux2_chA = '1' else -- MUX2 A
                            "00" when control0_reg.mux2_chB = '1' else -- MUX2 B
                            "01" when control1_reg.mux2_chC = '1' else -- MUX2 C
                            "11";
            mux_sel(3) <=   "10" when control1_reg.mux3_chA = '1' else -- MUX3 A
                            "00" when control1_reg.mux3_chB = '1' else -- MUX3 B
                            "01" when control1_reg.mux3_chC = '1' else -- MUX3 C
                            "11";
            mux_sel(4) <=   "10" when control1_reg.mux4_chA = '1' else -- MUX4 A
                            "00" when control1_reg.mux4_chB = '1' else -- MUX4 B
                            "01" when control1_reg.mux4_chC = '1' else -- MUX4 C
                            "11";
            -- we don't support channel 15 since it doesn't map out to TMUX131s nicely
        end if;
    end process;

    mux_is_active <= (or std_logic_vector'(pack(control0_reg))) or (or std_logic_vector'(pack(control1_reg)));

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
            elsif inst_valid = '1' and inst_ready = '1' and wr_addr = '0' and is_our_transaction = '1' then
                 ack_next <= '1';
            elsif inst_valid = '1' and inst_ready = '1' and wr_addr = '1' and is_valid(control0_reg_pend, inst_data, allowed_to_enable) and is_our_transaction = '1' then
                ack_next <= '1';
            -- Ack on the address byte when we're in the start of a transaction and we're being addressed
            elsif txn_header.tgt_addr = i2c_addr and txn_header.valid = '1' and  is_our_transaction = '0' then
                is_our_transaction <= '1';
                ack_next <= '1';
            end if;
    
        end if;
    end process;
    

end rtl;