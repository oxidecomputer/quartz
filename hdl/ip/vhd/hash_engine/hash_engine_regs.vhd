-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.numeric_std_unsigned.all;

use work.axil8x32_pkg.all;
use work.hash_engine_regs_pkg.all;

-- AXI-Lite register block for the hashing engine. The RDL tooling only
-- generates types and constants, so all the behaviour lives here: this follows
-- the same shape as spi_nor_regs.
entity hash_engine_regs is
    port (
        clk   : in    std_logic;
        reset : in    std_logic;

        -- axi interface
        axi_if : view axil_target;

        -- Control strobes. CONTROL.start and CONTROL.abort are self clearing, so
        -- they leave here as single cycle pulses rather than as a register.
        start_strobe : out   std_logic;
        abort_strobe : out   std_logic;

        -- Configuration, sampled by the feeder when it accepts a start
        cfg        : out   config_type;
        prepend    : out   prepend_type;
        flash_addr : out   flash_addr_type;
        msg_length : out   length_type;

        -- Status back from the engine
        status   : in    status_type;
        progress : in    progress_type;
        -- Bit 7 downto 0 is hash byte 0, so DIGESTn is digest(32n+31 downto 32n)
        digest   : in    std_logic_vector(255 downto 0);

        -- Software data FIFO push port
        wdata_fifo_wdata : out   std_logic_vector(31 downto 0);
        wdata_fifo_write : out   std_logic
    );
end entity;

architecture rtl of hash_engine_regs is

    signal rdata        : std_logic_vector(31 downto 0);
    signal active_read  : std_logic;
    signal active_write : std_logic;

begin

    axil_target_txn_inst: entity work.axil_target_txn
        port map (
            clk          => clk,
            reset        => reset,
            arvalid      => axi_if.read_address.valid,
            arready      => axi_if.read_address.ready,
            awvalid      => axi_if.write_address.valid,
            awready      => axi_if.write_address.ready,
            wvalid       => axi_if.write_data.valid,
            wready       => axi_if.write_data.ready,
            bvalid       => axi_if.write_response.valid,
            bready       => axi_if.write_response.ready,
            bresp        => axi_if.write_response.resp,
            rvalid       => axi_if.read_data.valid,
            rready       => axi_if.read_data.ready,
            rresp        => axi_if.read_data.resp,
            active_read  => active_read,
            active_write => active_write
        );

    axi_if.read_data.data <= rdata;

    -- The FIFO push is a decoded write strobe rather than a stored register. The
    -- FIFO itself drops the write when full, and STATUS.wfifo_full is how software
    -- is expected to avoid that.
    wdata_fifo_wdata <= axi_if.write_data.data;
    wdata_fifo_write <= '1' when active_write = '1' and
                                 to_integer(axi_if.write_address.addr) = WDATA_OFFSET else '0';

-- vsg_off
write_logic: process(clk, reset)
begin
    if reset then
        cfg <= rec_reset;
        prepend <= rec_reset;
        flash_addr <= rec_reset;
        msg_length <= rec_reset;
        start_strobe <= '0';
        abort_strobe <= '0';
    elsif rising_edge(clk) then
        -- CONTROL bits are self clearing
        start_strobe <= '0';
        abort_strobe <= '0';
        if active_write then
            case to_integer(axi_if.write_address.addr) is
                when CONTROL_OFFSET =>
                    start_strobe <= axi_if.write_data.data(0);
                    abort_strobe <= axi_if.write_data.data(1);
                when CONFIG_OFFSET => cfg <= unpack(axi_if.write_data.data);
                when PREPEND_OFFSET => prepend <= unpack(axi_if.write_data.data);
                when FLASH_ADDR_OFFSET => flash_addr <= unpack(axi_if.write_data.data);
                when LENGTH_OFFSET => msg_length <= unpack(axi_if.write_data.data);
                when others => null;
            end case;
        end if;
    end if;
end process;

read_logic: process(clk, reset)
begin
    if reset then
        rdata <= (others => '0');
    elsif rising_edge(clk) then
        if active_read then
            case to_integer(axi_if.read_address.addr) is
                -- CONTROL always reads zero: both its bits self clear.
                when CONTROL_OFFSET => rdata <= (others => '0');
                when CONFIG_OFFSET => rdata <= pack(cfg);
                when PREPEND_OFFSET => rdata <= pack(prepend);
                when FLASH_ADDR_OFFSET => rdata <= pack(flash_addr);
                when LENGTH_OFFSET => rdata <= pack(msg_length);
                when STATUS_OFFSET => rdata <= pack(status);
                -- WDATA is write only, the read side of the FIFO belongs to the feeder.
                when WDATA_OFFSET => rdata <= (others => '0');
                when PROGRESS_OFFSET => rdata <= pack(progress);
                when DIGEST0_OFFSET => rdata <= digest(31 downto 0);
                when DIGEST1_OFFSET => rdata <= digest(63 downto 32);
                when DIGEST2_OFFSET => rdata <= digest(95 downto 64);
                when DIGEST3_OFFSET => rdata <= digest(127 downto 96);
                when DIGEST4_OFFSET => rdata <= digest(159 downto 128);
                when DIGEST5_OFFSET => rdata <= digest(191 downto 160);
                when DIGEST6_OFFSET => rdata <= digest(223 downto 192);
                when DIGEST7_OFFSET => rdata <= digest(255 downto 224);
                when others => rdata <= (others => '0');
            end case;
        end if;
    end if;
end process;
-- vsg_on

end rtl;
