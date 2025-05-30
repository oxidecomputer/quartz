-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2025 Oxide Computer Company

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

use work.pca9506_pkg.all;
use work.pca9506_regs_pkg.all;

entity pca9506_regs is
    generic(DEBUG : string := "FALSE");
    port (
        clk : in std_logic;
        reset : in std_logic;

        -- i2c control interface
        cmd_ptr : in cmd_t;
        write_strobe: in std_logic;
        read_strobe: in std_logic;
        data_in: in std_logic_vector(7 downto 0);
        data_out: out std_logic_vector(7 downto 0);

        -- axi interface
        -- GHDL/yosys based toolchains
        -- write address channel
        awvalid : in std_logic;
        awready : out std_logic;
        awaddr : in std_logic_vector(7 downto 0) ;
        -- write data channel
        wvalid : in std_logic;
        wready : out std_logic;
        wdata : in std_logic_vector(31 downto 0);
        wstrb : in std_logic_vector(3 downto 0); -- un-used
        -- write response channel
        bvalid : out std_logic;
        bready : in std_logic;
        bresp : out std_logic_vector(1 downto 0);
        -- read address channel
        arvalid : in std_logic;
        arready : out std_logic;
        araddr : in std_logic_vector(7 downto 0);
        -- read data channel
        rvalid : out std_logic;
        rready : in std_logic;
        rdata : out std_logic_vector(31 downto 0);
        rresp : out std_logic_vector(1 downto 0);

        -- io interface
        output_disable: in std_logic;
        inband_reset : in std_logic; -- inband reset, can be used to reset the I/O expander
        io : in pca9506_pin_t;
        io_oe : out pca9506_pin_t;
        io_o : out pca9506_pin_t;
        int_n : out std_logic


    );
end entity;

architecture rtl of pca9506_regs is
    attribute MARK_DEBUG : string;

    signal ip0_reg : io_type;
    signal ip1_reg : io_type;
    signal ip2_reg : io_type;
    signal ip3_reg : io_type;
    signal ip4_reg : io_type;

    signal ip0_reg_irq_at_last_read : io_type;
    signal ip1_reg_irq_at_last_read : io_type;
    signal ip2_reg_irq_at_last_read : io_type;
    signal ip3_reg_irq_at_last_read : io_type;
    signal ip4_reg_irq_at_last_read : io_type;

    -- We have to monitor each input port for changes independently
    signal int_pend : std_logic_vector(4 downto 0);

    signal op0_reg : io_type;
    signal op1_reg : io_type;
    signal op2_reg : io_type;
    signal op3_reg : io_type;
    signal op4_reg : io_type;

    signal pi0_reg : io_type;
    signal pi1_reg : io_type;
    signal pi2_reg : io_type;
    signal pi3_reg : io_type;
    signal pi4_reg : io_type;

    signal ioc0_reg : io_type;
    signal ioc1_reg : io_type;
    signal ioc2_reg : io_type;
    signal ioc3_reg : io_type;
    signal ioc4_reg : io_type;

    signal msk0_reg : io_type;
    signal msk1_reg : io_type;
    signal msk2_reg : io_type;
    signal msk3_reg : io_type;
    signal msk4_reg : io_type;
    signal active_read : std_logic;
    signal active_write : std_logic;
    attribute MARK_DEBUG of active_read : signal is DEBUG;
    attribute MARK_DEBUG of active_write : signal is DEBUG;

begin

    axil_target_txn_inst: entity work.axil_target_txn
    generic map(
        DEBUG => DEBUG 
    )
    port map(
       clk => clk,
       reset => reset,
       arvalid => arvalid,
       arready => arready,
       awvalid => awvalid,
       awready =>awready,
       wvalid => wvalid,
       wready => wready,
       bvalid => bvalid,
       bready => bready,
       bresp => bresp,
       rvalid => rvalid,
       rready => rready,
       rresp => rresp,
       active_read => active_read,
       active_write => active_write
   );


    -- assign register outputs to output pins unconditionally
    io_o(0) <= pack(op0_reg);
    io_o(1) <= pack(op1_reg);
    io_o(2) <= pack(op2_reg);
    io_o(3) <= pack(op3_reg);
    io_o(4) <= pack(op4_reg);

    -- register the output enables since they might have
    -- some logic associated with them
    output_pins_reg: process(clk, reset)
    begin
        if reset then
            io_oe <= (others => (others =>'0'));
        elsif rising_edge(clk) then
            if output_disable = '1' then
                io_oe <= (others => (others =>'0'));
            else
                -- ioc bit = 0 means output, so invert here
                io_oe(0) <= not pack(ioc0_reg);
                io_oe(1) <= not pack(ioc1_reg);
                io_oe(2) <= not pack(ioc2_reg);
                io_oe(3) <= not pack(ioc3_reg);
                io_oe(4) <= not pack(ioc4_reg);
            end if;

        end if;
    end process;

    interrupt_logic: process(clk, reset)
    begin
        if reset then
            int_n <= '1';
            int_pend <= (others => '0');

        elsif rising_edge(clk) then
            -- each register gets its own pending interrupt bit
            -- here.  These will clear once the corresponding register
            -- is read, or the input state returns to the previously read state
            int_pend(0) <= get_irq_pend(ip0_reg, ip0_reg_irq_at_last_read, msk0_reg);
            int_pend(1) <= get_irq_pend(ip1_reg, ip1_reg_irq_at_last_read, msk1_reg);
            int_pend(2) <= get_irq_pend(ip2_reg, ip2_reg_irq_at_last_read, msk2_reg);
            int_pend(3) <= get_irq_pend(ip3_reg, ip3_reg_irq_at_last_read, msk3_reg);
            int_pend(4) <= get_irq_pend(ip4_reg, ip4_reg_irq_at_last_read, msk4_reg);
            
            int_n <= '1' when int_pend = 0 else '0';
        end if;
    end process;

    


    i2c_write_regs: process(clk, reset)
    begin 

        if reset then
            ip0_reg  <= reset_0s;
            ip1_reg  <= reset_0s;
            ip2_reg  <= reset_0s;
            ip3_reg  <= reset_0s;
            ip4_reg  <= reset_0s;
            op0_reg  <= reset_0s;
            op1_reg  <= reset_0s;
            op2_reg  <= reset_0s;
            op3_reg  <= reset_0s;
            op4_reg  <= reset_0s;
            pi0_reg  <= reset_0s;
            pi1_reg  <= reset_0s;
            pi2_reg  <= reset_0s;
            pi3_reg  <= reset_0s;
            pi4_reg  <= reset_0s;
            ioc0_reg <= reset_1s;
            ioc1_reg <= reset_1s;
            ioc2_reg <= reset_1s;
            ioc3_reg <= reset_1s;
            ioc4_reg <= reset_1s;  
            msk0_reg <= reset_1s;
            msk1_reg <= reset_1s;
            msk2_reg <= reset_1s;
            msk3_reg <= reset_1s;
            msk4_reg <= reset_1s;

        elsif rising_edge(clk) then
            -- deal with inputs, these either read the input pin or show the 
            -- current output value depending on whether this is and input or output 
            ip0_reg <= pi_reads_inputs_or_outputs(unpack(io(0)), op0_reg, ioc0_reg);
            ip1_reg <= pi_reads_inputs_or_outputs(unpack(io(1)), op1_reg, ioc1_reg);
            ip2_reg <= pi_reads_inputs_or_outputs(unpack(io(2)), op2_reg, ioc2_reg);
            ip3_reg <= pi_reads_inputs_or_outputs(unpack(io(3)), op3_reg, ioc3_reg);
            ip4_reg <= pi_reads_inputs_or_outputs(unpack(io(4)), op4_reg, ioc4_reg);
            -- deal with registers that are writeable by the
            -- i2c system

            if write_strobe = '1' then
                case to_integer(cmd_ptr.pointer) is
                    -- IP registers don't accept writes
                    when I2C_OP0_OFFSET =>
                        op0_reg <= unpack(data_in);
                    when I2C_OP1_OFFSET =>
                        op1_reg <= unpack(data_in);
                    when I2C_OP2_OFFSET =>
                        op2_reg <= unpack(data_in);
                    when I2C_OP3_OFFSET =>
                        op3_reg <= unpack(data_in);
                    when I2C_OP4_OFFSET =>
                        op4_reg <= unpack(data_in);

                    when I2C_PI0_OFFSET =>
                        pi0_reg <= unpack(data_in);
                    when I2C_PI1_OFFSET =>
                        pi1_reg <= unpack(data_in);
                    when I2C_PI2_OFFSET =>
                        pi2_reg <= unpack(data_in);
                    when I2C_PI3_OFFSET =>
                        pi3_reg <= unpack(data_in);
                    when I2C_PI4_OFFSET =>
                        pi4_reg <= unpack(data_in);

                    when I2C_IOC0_OFFSET =>
                        ioc0_reg <= unpack(data_in);
                    when I2C_IOC1_OFFSET =>
                        ioc1_reg <= unpack(data_in);
                    when I2C_IOC2_OFFSET =>
                        ioc2_reg <= unpack(data_in);
                    when I2C_IOC3_OFFSET =>
                        ioc3_reg <= unpack(data_in);
                    when I2C_IOC4_OFFSET =>
                        ioc4_reg <= unpack(data_in);

                    when I2C_MSK0_OFFSET =>
                        msk0_reg <= unpack(data_in);
                    when I2C_MSK1_OFFSET =>
                        msk1_reg <= unpack(data_in);
                    when I2C_MSK2_OFFSET =>
                        msk2_reg <= unpack(data_in);
                    when I2C_MSK3_OFFSET =>
                        msk3_reg <= unpack(data_in);
                    when I2C_MSK4_OFFSET =>
                        msk4_reg <= unpack(data_in);

                    when others =>
                        null;
                end case;
            end if;

            if inband_reset then
                ip0_reg  <= reset_0s;
                ip1_reg  <= reset_0s;
                ip2_reg  <= reset_0s;
                ip3_reg  <= reset_0s;
                ip4_reg  <= reset_0s;
                op0_reg  <= reset_0s;
                op1_reg  <= reset_0s;
                op2_reg  <= reset_0s;
                op3_reg  <= reset_0s;
                op4_reg  <= reset_0s;
                pi0_reg  <= reset_0s;
                pi1_reg  <= reset_0s;
                pi2_reg  <= reset_0s;
                pi3_reg  <= reset_0s;
                pi4_reg  <= reset_0s;
                ioc0_reg <= reset_1s;
                ioc1_reg <= reset_1s;
                ioc2_reg <= reset_1s;
                ioc3_reg <= reset_1s;
                ioc4_reg <= reset_1s;  
                msk0_reg <= reset_1s;
                msk1_reg <= reset_1s;
                msk2_reg <= reset_1s;
                msk3_reg <= reset_1s;
                msk4_reg <= reset_1s;
            end if;

        end if;

    end process;

    i2c_read_regs: process(clk, reset)
    begin
        if reset then
            data_out <= (others => '0');
            ip0_reg_irq_at_last_read <= reset_0s;
            ip1_reg_irq_at_last_read <= reset_0s;
            ip2_reg_irq_at_last_read <= reset_0s;
            ip3_reg_irq_at_last_read <= reset_0s;
            ip4_reg_irq_at_last_read <= reset_0s;

        elsif rising_edge(clk) then

            -- no need to gate on writes
            -- here so always assign output
            -- but deal with read-strobe for side-effects:
            -- we have to keep track of the last-read 
            -- register state for interrupt generation.
            case to_integer(cmd_ptr.pointer) is
                when I2C_IP0_OFFSET =>
                    -- deal with inversion, but only for the read
                    -- interface, the irq detection stuff deals
                    -- with the raw values (non-inverted)
                    data_out <= pack(ip0_reg xor pi0_reg);
                    if read_strobe then
                        ip0_reg_irq_at_last_read <= ip0_reg;
                    end if;
                when I2C_IP1_OFFSET =>
                    data_out <= pack(ip1_reg xor pi1_reg);
                    if read_strobe then
                        ip1_reg_irq_at_last_read <= ip1_reg;
                    end if;
                when I2C_IP2_OFFSET =>
                    data_out <= pack(ip2_reg xor pi2_reg);
                    if read_strobe then
                        ip2_reg_irq_at_last_read <= ip2_reg;
                    end if;
                when I2C_IP3_OFFSET =>
                    data_out <= pack(ip3_reg xor pi3_reg);
                    if read_strobe then
                        ip3_reg_irq_at_last_read <= ip3_reg;
                    end if;
                when I2C_IP4_OFFSET =>
                    data_out <= pack(ip4_reg xor pi4_reg);
                    if read_strobe then
                        ip4_reg_irq_at_last_read <= ip4_reg;
                    end if;

                when I2C_OP0_OFFSET =>
                    data_out <= pack(op0_reg);
                when I2C_OP1_OFFSET =>
                    data_out <= pack(op1_reg);
                when I2C_OP2_OFFSET =>
                    data_out <= pack(op2_reg);
                when I2C_OP3_OFFSET =>
                    data_out <= pack(op3_reg);
                when I2C_OP4_OFFSET =>
                    data_out <= pack(op4_reg);

                when I2C_PI0_OFFSET =>
                    data_out <= pack(pi0_reg);
                when I2C_PI1_OFFSET =>
                    data_out <= pack(pi1_reg);
                when I2C_PI2_OFFSET =>
                    data_out <= pack(pi2_reg);
                when I2C_PI3_OFFSET =>
                    data_out <= pack(pi3_reg);
                when I2C_PI4_OFFSET =>
                    data_out <= pack(pi4_reg);

                when I2C_IOC0_OFFSET =>
                    data_out <= pack(ioc0_reg);
                when I2C_IOC1_OFFSET =>
                    data_out <= pack(ioc1_reg);
                when I2C_IOC2_OFFSET =>
                    data_out <= pack(ioc2_reg);
                when I2C_IOC3_OFFSET =>
                    data_out <= pack(ioc3_reg);
                when I2C_IOC4_OFFSET =>
                    data_out <= pack(ioc4_reg);

                when I2C_MSK0_OFFSET =>
                    data_out <= pack(msk0_reg);
                when I2C_MSK1_OFFSET =>
                    data_out <= pack(msk1_reg);
                when I2C_MSK2_OFFSET =>
                    data_out <= pack(msk2_reg);
                when I2C_MSK3_OFFSET =>
                    data_out <= pack(msk3_reg);
                when I2C_MSK4_OFFSET =>
                    data_out <= pack(msk4_reg);

                when others =>
                    data_out <= (others => '0');
            end case;

        end if;
    end process;


    axi_read_logic: process(clk, reset)
    begin
        if reset then
            rdata <= (others => '0');
        elsif rising_edge(clk) then
            if active_read then
                -- byte addresses so we need to shift down
                case to_integer(araddr) is
                    when I2C_IP0_OFFSET * 4 => rdata <= X"000000" & pack(ip0_reg xor pi0_reg);
                    when I2C_IP1_OFFSET * 4 => rdata <= X"000000" & pack(ip1_reg xor pi1_reg);
                    when I2C_IP2_OFFSET * 4 => rdata <= X"000000" & pack(ip2_reg xor pi2_reg);
                    when I2C_IP3_OFFSET * 4 => rdata <= X"000000" & pack(ip3_reg xor pi3_reg);
                    when I2C_IP4_OFFSET * 4 => rdata <= X"000000" & pack(ip4_reg xor pi4_reg);
                    when I2C_OP0_OFFSET * 4 => rdata <= X"000000" & pack(op0_reg);
                    when I2C_OP1_OFFSET * 4 => rdata <= X"000000" & pack(op1_reg);
                    when I2C_OP2_OFFSET * 4 => rdata <= X"000000" & pack(op2_reg);
                    when I2C_OP3_OFFSET * 4 => rdata <= X"000000" & pack(op3_reg);
                    when I2C_OP4_OFFSET * 4 => rdata <= X"000000" & pack(op4_reg);
                    when I2C_PI0_OFFSET * 4 => rdata <= X"000000" & pack(pi0_reg);
                    when I2C_PI1_OFFSET * 4 => rdata <= X"000000" & pack(pi1_reg);
                    when I2C_PI2_OFFSET * 4 => rdata <= X"000000" & pack(pi2_reg);
                    when I2C_PI3_OFFSET * 4 => rdata <= X"000000" & pack(pi3_reg);
                    when I2C_PI4_OFFSET * 4 => rdata <= X"000000" & pack(pi4_reg);
                    when I2C_IOC0_OFFSET * 4 => rdata <=  X"000000" & pack(ioc0_reg);
                    when I2C_IOC1_OFFSET * 4 => rdata <=  X"000000" & pack(ioc1_reg);
                    when I2C_IOC2_OFFSET * 4 => rdata <=  X"000000" & pack(ioc2_reg);
                    when I2C_IOC3_OFFSET * 4 => rdata <=  X"000000" & pack(ioc3_reg);
                    when I2C_IOC4_OFFSET * 4 => rdata <=  X"000000" & pack(ioc4_reg);
                    when I2C_MSK0_OFFSET * 4 => rdata <=  int_pend(0) & 23x"0" & pack(msk0_reg);
                    when I2C_MSK1_OFFSET * 4 => rdata <=  int_pend(1) & 23x"0" & pack(msk1_reg);
                    when I2C_MSK2_OFFSET * 4 => rdata <=  int_pend(2) & 23x"0" & pack(msk2_reg);
                    when I2C_MSK3_OFFSET * 4 => rdata <=  int_pend(3) & 23x"0" & pack(msk3_reg);
                    when I2C_MSK4_OFFSET * 4 => rdata <=  int_pend(4) & 23x"0" & pack(msk4_reg);
                    when others =>
                        rdata <= (others => '0');
                end case;
            end if;
        end if;
    end process;

end rtl;
