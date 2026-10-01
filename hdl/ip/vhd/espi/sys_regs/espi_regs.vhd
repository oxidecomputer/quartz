-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.

-- SP-accessible registers for the eSPI block

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.numeric_std_unsigned.all;
use work.espi_regs_pkg.all;
use work.espi_spec_regs_view_pkg.all;
use work.espi_spec_regs_pkg;
use work.qspi_link_layer_pkg.all;
use work.sp5_post_code_pkg.all;
use work.axil15x32_pkg.all;
use work.calc_pkg.log2ceil;

entity espi_regs is
    generic (
        -- An instance that only ever serves the flash channel never sees a
        -- post code, so it can leave the 4k entry buffer out; reads of it
        -- then return zero.
        POST_CODE_BUFFER_ENABLED : boolean := true
    );
    port (
        clk   : in    std_logic;
        reset : in    std_logic;
        -- axi interface
        axi_if : view axil_target;
        post_code      : in std_logic_vector(31 downto 0);
        post_code_valid : in std_logic;
        espi_reset : in std_logic;
        -- runtime half of the SAFS write permission, see espi_target_top
        flash_write_enable : out std_logic;
        stuff_fifo : out std_logic;
        stuff_wds : out std_logic_vector(15 downto 0);
        -- read-only view of eSPI spec registers
        spec_regs_view : view spec_regs_sink;
        -- debug interface
        dbg_chan : view dbg_regs_if;
        to_host_tx_fifo_usedwds : in std_logic_vector(12 downto 0);
        ipcc_to_host_byte_cntr : in std_logic_vector(31 downto 0);
        live_espi_status : in std_logic_vector(15 downto 0);
        last_resp_status : in std_logic_vector(15 downto 0);
        host_to_sp_fifo_usedwds : in std_logic_vector(12 downto 0);
        oob_free_saw_full : in std_logic
    );
end entity;

architecture rtl of espi_regs is

    signal   rdata              : std_logic_vector(31 downto 0);
    signal   control_reg        : control_type;
    signal   status_reg         : status_type;
    signal   fifo_status_reg    : fifo_status_type;
    signal   flags_reg          : flags_type;
    signal   resp_fifo_ack      : std_logic;
    signal active_read        : std_logic;
    signal active_write       : std_logic;
    signal last_post_code_reg : last_post_code_type;
    signal post_code_count_reg : post_code_count_type;
    signal stuff_count       : ipcc_dummy_fill_count_type;
    signal stuff_enable      : ipcc_dummy_fill_en_type;
    signal oob_free_saw_full_reg : oob_free_saw_full_type;
    signal last_resp_status_reg : espi_status_type;
    signal live_status_reg : espi_status_type;
    signal post_code_monitor_reg : post_code_monitor_type;
    constant BUFFER_ENTRIES : integer := 4096;
    constant BUFFER_ADDR_WIDTH : integer := log2ceil(BUFFER_ENTRIES);
    signal pc_buf_waddr : std_logic_vector(BUFFER_ADDR_WIDTH - 1 downto 0);
    signal pc_buf_raddr : std_logic_vector(BUFFER_ADDR_WIDTH - 1 downto 0);
    signal post_code_buffer_rdata : std_logic_vector(31 downto 0);
    -- The read in flight is of the buffer, so answer from its output
    -- register rather than rdata
    signal pc_buf_read : std_logic;

begin
    fifo_status_reg.cmd_used_wds <= dbg_chan.wstatus.usedwds;
    fifo_status_reg.resp_used_wds <= dbg_chan.rdstatus.usedwds;
    status_reg.busy <= dbg_chan.busy;
    flags_reg.alert <= dbg_chan.alert_pending;
    oob_free_saw_full_reg.saw_full <= oob_free_saw_full;
    last_resp_status_reg <= unpack(X"0000" & last_resp_status);
    live_status_reg <= unpack(X"0000" & live_espi_status);

    axi_if.read_data.data <= post_code_buffer_rdata when pc_buf_read = '1' else rdata;

    stuff_wds <= stuff_count.count(15 downto 0);
    stuff_fifo <= stuff_enable.en;

    axil_target_txn_inst: entity work.axil_target_txn
     port map(
        clk => clk,
        reset => reset,
        arvalid => axi_if.read_address.valid,
        arready => axi_if.read_address.ready,
        awvalid => axi_if.write_address.valid,
        awready => axi_if.write_address.ready,
        wvalid => axi_if.write_data.valid,
        wready => axi_if.write_data.ready,
        bvalid => axi_if.write_response.valid,
        bready => axi_if.write_response.ready,
        bresp => axi_if.write_response.resp,
        rvalid => axi_if.read_data.valid,
        rready => axi_if.read_data.ready,
        rresp => axi_if.read_data.resp,
        active_read => active_read,
        active_write => active_write
    );

    write_logic: process(clk, reset)
    begin
        if reset then
            control_reg <= rec_reset;
            last_post_code_reg <= rec_reset;
            post_code_count_reg <= rec_reset;
            post_code_monitor_reg <= rec_reset;
            pc_buf_waddr <= (others => '0');
            stuff_count <= rec_reset;
            stuff_enable <= rec_reset;
        elsif rising_edge(clk) then
            control_reg.cmd_fifo_reset <= '0';  -- self clearing
            control_reg.cmd_size_fifo_reset <= '0';  -- self clearing
            control_reg.resp_fifo_reset <= '0';  -- self clearing
            control_reg.espi_reset <= '0';  -- self clearing
            if  axi_if.write_address.ready then
                case to_integer(axi_if.write_address.addr) is
                    when CONTROL_OFFSET => control_reg <= unpack(axi_if.write_data.data);
                    when IPCC_DUMMY_FILL_COUNT_OFFSET => stuff_count <= unpack(axi_if.write_data.data);
                    when IPCC_DUMMY_FILL_EN_OFFSET => stuff_enable <= unpack(axi_if.write_data.data);
                    when others => null;
                end case;
            end if;
            if espi_reset then
                last_post_code_reg <= rec_reset;
                post_code_count_reg <= rec_reset;
                post_code_monitor_reg <= rec_reset;
                pc_buf_waddr <= (others => '0');
            elsif post_code_valid then
               last_post_code_reg <= unpack(post_code);
               post_code_count_reg <= unpack(post_code_count_reg.count + 1);
               post_code_monitor_reg <= post_code_monitor_reg or decode_post_code_monitor(post_code);
               pc_buf_waddr <= pc_buf_waddr + 1;
            end if;
        end if;
    end process;

    -- The buffer is 128kb, which in distributed RAM was 3.6k LUTRAMs per
    -- instance, enough to starve the placer on a part that also carries the
    -- DIMM caches. In block RAM the read is registered, so the buffer is
    -- answered one cycle after the AXI read is accepted, which is exactly
    -- when rvalid rises: the read enable is the accept, so the output holds
    -- for as long as the master takes to collect it.
    pc_buf: if POST_CODE_BUFFER_ENABLED generate
        type pc_mem_t is array (0 to BUFFER_ENTRIES - 1) of std_logic_vector(31 downto 0);
        signal pc_mem : pc_mem_t;
        attribute ram_style : string;
        attribute ram_style of pc_mem : signal is "block";
    begin
        pc_mem_write: process(clk)
        begin
            if rising_edge(clk) then
                if post_code_valid then
                    pc_mem(to_integer(pc_buf_waddr)) <= post_code;
                end if;
            end if;
        end process;

        pc_mem_read: process(clk)
        begin
            if rising_edge(clk) then
                if active_read then
                    post_code_buffer_rdata <= pc_mem(to_integer(pc_buf_raddr));
                end if;
            end if;
        end process;
    else generate
        post_code_buffer_rdata <= (others => '0');
    end generate;

    -- Axi here are byte_addresses and we need to convert to word addresses for the dpr.
    pc_buf_raddr <= resize(shift_right(axi_if.read_address.addr - POST_CODE_BUFFER_OFFSET, 2), pc_buf_raddr'length);

    dbg_chan.wr.data <= axi_if.write_data.data;
    dbg_chan.wr.write <= '1' when axi_if.write_address.ready = '1' and to_integer(axi_if.write_address.addr) = CMD_FIFO_WDATA_OFFSET else '0';
    dbg_chan.size.data <= axi_if.write_data.data;
    dbg_chan.size.write <= '1' when axi_if.write_address.ready = '1' and to_integer(axi_if.write_address.addr) = CMD_SIZE_FIFO_WDATA_OFFSET else '0';

    dbg_chan.rd.rdack <= '1' when axi_if.read_data.ready = '1' and axi_if.read_data.valid = '1' and resp_fifo_ack = '1' else '0';
    dbg_chan.espi_reset <= control_reg.espi_reset;
    flash_write_enable <= control_reg.flash_write_enable;

    read_logic: process(clk, reset)
    begin
        if reset then
            rdata <= (others => '0');
            resp_fifo_ack <= '0';
            pc_buf_read <= '0';
        elsif rising_edge(clk) then
            resp_fifo_ack <= '0';
            if active_read then
                pc_buf_read <= '0';
                case to_integer(axi_if.read_address.addr) is
                    when FLAGS_OFFSET => rdata <= pack(flags_reg);
                    when CONTROL_OFFSET => rdata <= pack(control_reg);
                    when STATUS_OFFSET => rdata <= pack(status_reg);
                    when FIFO_STATUS_OFFSET => rdata <= pack(fifo_status_reg);
                    when RESP_FIFO_RDATA_OFFSET => 
                        rdata <= dbg_chan.rd.data;
                        resp_fifo_ack <= '1';
                    when LAST_POST_CODE_OFFSET => rdata <= pack(last_post_code_reg);
                    when POST_CODE_COUNT_OFFSET => rdata <= pack(post_code_count_reg);
                    when POST_CODE_MONITOR_OFFSET => rdata <= pack(post_code_monitor_reg);
                    when IPCC_TO_HOST_USEDWDS_OFFSET =>
                        rdata <= resize(to_host_tx_fifo_usedwds, rdata'length);
                    when IPCC_TO_HOST_BYTE_CNTR_OFFSET =>
                        rdata <= ipcc_to_host_byte_cntr;
                    when IPCC_DUMMY_FILL_COUNT_OFFSET =>
                        rdata <= pack(stuff_count);
                    when IPCC_DUMMY_FILL_EN_OFFSET =>
                        rdata <= pack(stuff_enable);
                    when LIVE_ESPI_STATUS_OFFSET =>
                        rdata <= pack(live_status_reg);
                    when LAST_RESP_STATUS_OFFSET =>
                        rdata <= pack(last_resp_status_reg);
                    when IPCC_HOST_TO_SP_USEDWDS_OFFSET =>
                        rdata <= resize(host_to_sp_fifo_usedwds, rdata'length);
                    when OOB_FREE_SAW_FULL_OFFSET =>
                        rdata <= pack(oob_free_saw_full_reg);
                    -- Read-only eSPI spec registers (base 0x0080)
                    when SPEC_REGS_DEVICE_ID_OFFSET =>
                        rdata <= espi_spec_regs_pkg.pack(spec_regs_view.device_id);
                    when SPEC_REGS_GENERAL_CAPABILITIES_OFFSET =>
                        rdata <= espi_spec_regs_pkg.pack(spec_regs_view.general_capabilities);
                    when SPEC_REGS_CH0_CAPABILITIES_OFFSET =>
                        rdata <= espi_spec_regs_pkg.pack(spec_regs_view.ch0_capabilities);
                    when SPEC_REGS_CH1_CAPABILITIES_OFFSET =>
                        rdata <= espi_spec_regs_pkg.pack(spec_regs_view.ch1_capabilities);
                    when SPEC_REGS_CH2_CAPABILITIES_OFFSET =>
                        rdata <= espi_spec_regs_pkg.pack(spec_regs_view.ch2_capabilities);
                    when SPEC_REGS_CH3_CAPABILITIES_OFFSET =>
                        rdata <= espi_spec_regs_pkg.pack(spec_regs_view.ch3_capabilities);
                    when SPEC_REGS_CH3_CAPABILITIES2_OFFSET =>
                        rdata <= espi_spec_regs_pkg.pack(spec_regs_view.ch3_capabilities2);
                    when POST_CODE_BUFFER_MEM_RANGE =>
                        pc_buf_read <= '1';
                    when others =>
                        rdata <= (others => '0');
                end case;
            end if;
        end if;
    end process;

    dbg_chan.enabled <= control_reg.dbg_mode_en;

end rtl;
