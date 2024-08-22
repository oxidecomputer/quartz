-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2024 Oxide Computer Company

--! This block provides an FMC target interface from the STM32H7's
--! local bus, crosses clock domains into the FPGA's core logic
--! clock domain, and issues AXI transactions.
--! figures 115 and 116

-- ES0491 FMC Errata:
-- Dummy read cycles inserted when reading synchronous memories
-- Description
-- When performing a burst read access from a synchronous memory, two dummy read accesses are performed at
-- the end of the burst cycle whatever the type of burst access.
-- The extra data values read are not used by the FMC and there is no functional failure.
-- Workaround
-- None

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.numeric_std_unsigned.all;
use work.stm32h7_fmc_target_pkg.all;
use work.axil26x32_pkg.all;

entity stm32h7_fmc_target is
    port (
        -- Interface to the STM32H7's FMC periph
        chip_reset : in    std_logic;
        --! fmc_clk from STM32's clock generator
        fmc_clk : in    std_logic;
        --! non-multiplexed upper address bits from STM32
        a : in    std_logic_vector(24 downto 16);
        --! multiplexed lower address bits/databits to/from STM32
        addr_data_in : in    std_logic_vector(15 downto 0);
        data_out     : out   std_logic_vector(15 downto 0);
        data_out_en  : out   std_logic;
        --! active-low chip selects
        ne : in    std_logic_vector(3 downto 0);
        --! active-low output enable
        noe : in    std_logic;
        --! active-low write enable
        nwe : in    std_logic;
        --! active-low address latch for address phase
        nl : in    std_logic;
        --! active-low pipelined wait to STM32, asserted 1 cycle before stall
        nwait : out   std_logic;
        -- FPGA interface
        aclk    : in    std_logic;
        aresetn : in    std_logic;
        -- AXI requester interface
        axi_if : view axil_controller
    );
end entity;

architecture rtl of stm32h7_fmc_target is

    attribute mark_debug : string;

    type fmc_state_type is (
        idle,
        addr_delay,
        addr_delay1,
        read_setup,
        read_word0_setup_delay,
        read_word0,
        read_word1_setup_delay,
        read_word1,
        write_setup,
        write_wait_delay,
        write_word0,
        write_word1,
        timeout_cleanup
    );

    type   axi_state_type is (
        idle,
        axi_read_init,
        axi_read_wait,
        axi_write_init,
        axi_write_wait
    );
    signal fmc_state : fmc_state_type;
    attribute mark_debug of fmc_state : signal is "TRUE";
    signal axi_state : axi_state_type;
    signal txn       : txn_type;
    attribute mark_debug of txn       : signal is "TRUE";

    signal axi_fifo_rd_path_rdata  : std_logic_vector(31 downto 0);
    signal axi_fifo_rd_path_rd_ack : std_logic;
    signal axi_fifo_rd_path_rempty : std_logic;

    signal axi_fifo_wr_path_rdata  : std_logic_vector(31 downto 0);
    signal axi_fifo_wr_path_rempty : std_logic;

    signal axi_fifo_txn_path_write  : std_logic;
    signal axi_fifo_txn_path_rdata  : std_logic_vector(31 downto 0);
    signal axi_fifo_txn_path_rd_ack : std_logic;
    signal axi_fifo_txn_path_rempty : std_logic;
    signal axi_fifo_txn_path_wfull  : std_logic;

    signal axi_addr               : unsigned(31 downto 0);
    signal axi_fifo_wr_path_wdata : std_logic_vector(31 downto 0);
    signal axi_fifo_wr_path_write : std_logic;
    signal txn_stored             : boolean;

    alias awready is axi_if.write_address.ready;
    alias wready  is axi_if.write_data.ready;
    alias bvalid  is axi_if.write_response.valid;
    alias arready is axi_if.read_address.ready;
    alias rvalid  is axi_if.read_data.valid;
    alias rdata   is axi_if.read_data.data;

    signal awvalid : std_logic;
    signal awaddr  : std_logic_vector(25 downto 0);
    signal wvalid  : std_logic;
    signal wdata   : std_logic_vector(31 downto 0);
    signal bready  : std_logic;
    signal arvalid : std_logic;
    signal araddr  : std_logic_vector(25 downto 0);
    signal rready  : std_logic;

    signal int_toggle : std_logic;

begin

    axi_if.write_address.valid  <= awvalid;
    axi_if.write_address.addr   <= awaddr;
    axi_if.write_data.valid     <= wvalid;
    axi_if.write_data.strb      <= (others => '1');
    axi_if.write_data.data      <= wdata;
    axi_if.write_response.ready <= bready;
    axi_if.read_address.valid   <= arvalid;
    axi_if.read_address.addr    <= araddr;
    axi_if.read_data.ready      <= rready;

    -- State machine dealing with fmc interface
    fmc_if_sm: process(fmc_clk, chip_reset)
        variable chip_selected : boolean;
    begin
        if chip_reset then
            data_out <= (others => '0');
            data_out_en <= '0'; -- release bus
            nwait <= '0';
            txn <= ('0', (others => '0'));
            axi_fifo_wr_path_wdata  <= (others => '0');
            axi_fifo_rd_path_rd_ack <= '0';
            axi_fifo_txn_path_write <= '0';
            axi_fifo_wr_path_write  <= '0';
            txn_stored              <= false;
            int_toggle              <= '0';
        elsif rising_edge(fmc_clk) then
            -- some variable naming for more legibility
            chip_selected := ne(0) = '0';

            -- single-cycle flags, unconditionally cleared
            axi_fifo_rd_path_rd_ack <= '0';
            axi_fifo_txn_path_write <= '0';
            axi_fifo_wr_path_write <= '0';
            case fmc_state is
                when idle =>
                    nwait <= '0';
                    data_out_en <= '0'; -- release bus
                    -- Look for a starting transition
                    -- ( chip sel and address latch)
                    if chip_selected and nl = '0' then
                        -- Bus outputs right-shifted so we shift left here to
                        -- recover byte addrs
                        txn.addr <= unsigned(a & addr_data_in & "0");
                        txn.read_not_write <= nwe;

                        fmc_state <= addr_delay;
                    end if;
                when addr_delay =>
                    -- We get here after latching the address
                    -- We'll delay for an additional cycle
                    -- so that the next cycle will be checking
                    fmc_state <= addr_delay1;
                when addr_delay1 =>
                    -- We need to immediately stall the bus at this point if we have a full txn fifo
                    -- other stall conditions will be checked in the read/write setup phase
                    -- since the conditions differ
                    if axi_fifo_txn_path_wfull then
                        nwait <= '0';
                    end if;
                    if txn.read_not_write = '1' then
                        fmc_state <= read_setup;
                        -- For reads, we unconditionally wait here since we have to
                        -- do an axi transaction to even fetch the first data to return
                        -- which takes more than 1 cycle :)
                        nwait <= '0';
                    else
                        fmc_state <= write_setup;
                    end if;
                when read_setup =>
                    -- TODO: need a wait timeout mech here, we're potentially stalling
                    -- the SP's bus here!

                    -- We need to issue this transaction 1x to the txn fifo
                    if not chip_selected then
                        fmc_state <= idle;
                    else
                        -- We're going to be doing a read here we must be waited already
                        -- We need to immediately stall the bus at this point if we have a full txn fifo
                        -- not that transactions are processed in order so any writes pending
                        -- will necessarily happen first. This is important since the writes could
                        -- have side-effects that affect the reads
                        if not txn_stored and axi_fifo_txn_path_wfull = '0' then
                            -- Store the transaction, set the stored flag so we don't
                            -- do it again while we wait
                            axi_fifo_txn_path_write <= '1';
                            txn_stored              <= true;
                        end if;
                        -- Wait is held here until we've done the AXI transaction
                        -- to fetch the data and have the data back in the fifo
                        if not axi_fifo_rd_path_rempty then
                            -- Register the data
                            -- apply the data to the bus
                            -- take away the wait
                            data_out    <= axi_fifo_rd_path_rdata(15 downto 0);
                            -- noe should always be active here, but this provides a safety net
                            -- in case there is a bus-desync of some kind, we don't want to cross-drive with
                            -- the sp
                            data_out_en <= '1' and (not noe);
                            fmc_state <= read_word0_setup_delay;
                        end if;
                    end if;
                when read_word0_setup_delay =>
                    nwait       <= '1';
                    fmc_state <= read_word0;
                when read_word0 =>
                    nwait       <= '0';
                    txn_stored <= false;
                    data_out  <= axi_fifo_rd_path_rdata(31 downto 16);
                    if not chip_selected then
                        fmc_state <= idle;
                        data_out_en <= '0'; -- release bus
                        axi_fifo_rd_path_rd_ack <= '1'; -- clear the read word
                    else  -- not done, move to next word
                        fmc_state <= read_word1_setup_delay;
                    end if;
                when read_word1_setup_delay =>
                    nwait       <= '1';
                    fmc_state <= read_word1;
                when read_word1 =>
                    -- TODO: if we want to allow shorter transactions
                    -- we'd need to do the right thing here, which would
                    -- be termingating early, and doing the read anyway.
                    -- we can only do 32bit wide reads on the AXI side
                    -- so care should be excersized by the user if there
                    -- are read side-effects on the addresses next to this
                    -- read since we'd be doing a 32bit axi read in this case
                    -- and dropping the latter part on the floor since it wasn't
                    -- requested.

                    -- normal case: pop the rdata fifo since we're done with it
                    axi_fifo_rd_path_rd_ack <= '1';
                    fmc_state               <= idle;
                    nwait                   <= '0';
                    data_out_en <= '0'; -- release bus
                when write_setup =>
                    if not chip_selected then
                        fmc_state <= idle;
                    else
                        if not txn_stored and axi_fifo_txn_path_wfull = '0' then
                            -- Store the transaction, set the stored flag so we don't
                            -- do it again while we wait
                            axi_fifo_txn_path_write <= '1';
                            txn_stored              <= true;
                            nwait                   <= '1';
                            -- no waits needed until the fifo fills up
                            fmc_state                           <= write_wait_delay;
                        end if;
                    end if;
                when write_wait_delay =>
                    fmc_state                           <= write_word0;
                when write_word0 =>
                    axi_fifo_wr_path_wdata(15 downto 0) <= addr_data_in;
                    txn_stored                           <= false;
                    fmc_state                            <= write_word1;
                when write_word1 =>
                    axi_fifo_wr_path_wdata(31 downto 16) <= addr_data_in;
                    axi_fifo_wr_path_write <= '1';
                    nwait <= '0';
                    fmc_state              <= idle;
                    -- We need to immediately stall the bus at this point if we have a full txn fifo
                    -- other stall conditions will be checked in the write setup phase
                    -- since the conditions differ
                    if axi_fifo_txn_path_wfull then
                    end if;
                when timeout_cleanup =>
                    null;
            end case;
        end if;
    end process;

    -- transaction fifo from FMC to AXI interface
    txn_dcfifo_dut: entity work.dcfifo_xpm
        generic map (

            fifo_write_depth => 16,
            data_width       => 32,
            showahead_mode   => true
        )
        port map (
            -- Write interface ()
            wclk => fmc_clk,
            -- Reset interface, sync to write clock domain
            reset    => chip_reset,
            write_en => axi_fifo_txn_path_write,
            wdata    => encode(txn),
            wfull    => axi_fifo_txn_path_wfull,
            wusedwds => open,
            -- Read interface
            rclk     => aclk,
            rdata    => axi_fifo_txn_path_rdata,
            rdreq    => axi_fifo_txn_path_rd_ack,
            rempty   => axi_fifo_txn_path_rempty,
            rusedwds => open
        );

    -- Read-data path from AXI to FMC interface
    rdata_dcfifo_dut: entity work.dcfifo_xpm
        generic map (

            fifo_write_depth => 16,
            data_width       => 32,
            showahead_mode   => true
        )
        port map (
            -- Write interface ()
            wclk => aclk,
            -- Reset interface, sync to write clock domain
            reset    => not aresetn,
            write_en => rready and rvalid,
            wdata    => rdata,
            wfull    => open,
            wusedwds => open,
            -- Read interface
            rclk     => fmc_clk,
            rdata    => axi_fifo_rd_path_rdata,
            rdreq    => axi_fifo_rd_path_rd_ack,
            rempty   => axi_fifo_rd_path_rempty,
            rusedwds => open
        );

    -- Write-data path from FMC to AXI interface
    wdata_dcfifo_dut: entity work.dcfifo_xpm
        generic map (

            fifo_write_depth => 16,
            data_width       => 32,
            showahead_mode   => true
        )
        port map (
            -- Write interface ()
            wclk => fmc_clk,
            -- Reset interface, sync to write clock domain
            reset    => chip_reset,
            write_en => axi_fifo_wr_path_write,
            wdata    => axi_fifo_wr_path_wdata,
            wfull    => open,
            wusedwds => open,
            -- Read interface
            rclk     => aclk,
            rdata    => axi_fifo_wr_path_rdata,
            rdreq    => wvalid and wready,
            rempty   => axi_fifo_wr_path_rempty,
            rusedwds => open
        );

    -- State machine dealing with AXI interface
    axi_sm: process(aclk, aresetn)
        variable cur_txn : txn_type;
    begin
        if not aresetn then
            axi_addr                 <= (others => '0');
            axi_state                <= idle;
            rready                   <= '0';
            arvalid                  <= '0';
            bready                   <= '0';
            awvalid                  <= '0';
            wvalid                   <= '0';
            axi_fifo_txn_path_rd_ack <= '0';
        elsif rising_edge(aclk) then
            -- unconditionally clear single-cycle flags
            axi_fifo_txn_path_rd_ack <= '0';
            case axi_state is
                when idle =>
                    if not axi_fifo_txn_path_rempty then
                        axi_fifo_txn_path_rd_ack <= '1';
                        cur_txn                  := decode(axi_fifo_txn_path_rdata);
                        axi_addr                 <= resize(cur_txn.addr, axi_addr'length);
                        if cur_txn.read_not_write then
                            axi_state <= axi_read_init;
                        else
                            axi_state <= axi_write_init;
                        end if;
                    end if;
                when axi_read_init =>
                    -- APPLY READ ADDR channel and allow read responses
                    rready    <= '1';
                    arvalid   <= '1';
                    axi_state <= axi_read_wait;
                when axi_read_wait =>
                    if rready and rvalid then
                        rready    <= '0';
                        axi_state <= idle;
                    end if;
                    if arready and arvalid then
                        arvalid <= '0';
                    end if;
                when axi_write_init =>
                    awvalid <= '1';
                    if not axi_fifo_wr_path_rempty then
                        wvalid    <= '1';
                        axi_state <= axi_write_wait;
                    end if;
                    if awready and awvalid then
                        awvalid <= '0';
                    end if;
                    bready <= '1';
                when axi_write_wait =>
                    if awready and awvalid then
                        awvalid <= '0';
                    end if;
                    if wready and wvalid then
                        wvalid <= '0';
                    end if;
                    if bvalid then
                        axi_state <= idle;
                        bready <= '0';
                    end if;
            end case;
        end if;
    end process;

    -- no fancy concurrency here, so just point at the same register
    awaddr <= std_logic_vector(axi_addr(25 downto 0));
    araddr <= std_logic_vector(axi_addr(25 downto 0));
    wdata  <= axi_fifo_wr_path_rdata;

end rtl;
