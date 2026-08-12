-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library vunit_lib;
    context vunit_lib.vunit_context;
    context vunit_lib.com_context;
    context vunit_lib.vc_context;

use work.axil_common_pkg.all;
use work.axilite_if_2k8_pkg.all;
use work.axil_interconnect_sim_pkg.all;

entity axil_interconnect_th is
end entity;

architecture th of axil_interconnect_th is

    signal clk       : std_logic := '0';
    signal reset     : std_logic;
    signal reset_por : std_logic := '1';
    -- testbench driven, so a reset can be injected mid transaction
    signal reset_force : std_logic := '0';

    -- The bus functional model drives these
    signal bfm_awvalid : std_logic;
    signal bfm_awaddr  : std_logic_vector(INITIATOR_ADDR_WIDTH - 1 downto 0);
    signal bfm_wvalid  : std_logic;
    signal bfm_wdata   : std_logic_vector(31 downto 0);
    signal bfm_wstrb   : std_logic_vector(3 downto 0);
    signal bfm_bready  : std_logic;
    signal bfm_arvalid : std_logic;
    signal bfm_araddr  : std_logic_vector(INITIATOR_ADDR_WIDTH - 1 downto 0);
    signal bfm_rready  : std_logic;

    -- The testbench drives these directly when man_mode is set, so it can
    -- reproduce initiator handshake patterns the BFM never generates (notably
    -- the FMC target's habit of raising AWVALID well before WVALID, and
    -- re-raising it after an AWREADY pulse).
    signal man_mode    : std_logic := '0';
    signal man_awvalid : std_logic := '0';
    signal man_awaddr  : std_logic_vector(INITIATOR_ADDR_WIDTH - 1 downto 0) := (others => '0');
    signal man_wvalid  : std_logic := '0';
    signal man_wdata   : std_logic_vector(31 downto 0) := (others => '0');
    signal man_wstrb   : std_logic_vector(3 downto 0) := "1111";
    signal man_bready  : std_logic := '0';
    signal man_arvalid : std_logic := '0';
    signal man_araddr  : std_logic_vector(INITIATOR_ADDR_WIDTH - 1 downto 0) := (others => '0');
    signal man_rready  : std_logic := '0';

    -- initiator side of the fabric
    signal init_awvalid : std_logic;
    signal init_awready : std_logic;
    signal init_awaddr  : std_logic_vector(INITIATOR_ADDR_WIDTH - 1 downto 0);
    signal init_wvalid  : std_logic;
    signal init_wready  : std_logic;
    signal init_wdata   : std_logic_vector(31 downto 0);
    signal init_wstrb   : std_logic_vector(3 downto 0);
    signal init_bvalid  : std_logic;
    signal init_bready  : std_logic;
    signal init_bresp   : std_logic_vector(1 downto 0);
    signal init_arvalid : std_logic;
    signal init_arready : std_logic;
    signal init_araddr  : std_logic_vector(INITIATOR_ADDR_WIDTH - 1 downto 0);
    signal init_rvalid  : std_logic;
    signal init_rready  : std_logic;
    signal init_rdata   : std_logic_vector(31 downto 0);
    signal init_rresp   : std_logic_vector(1 downto 0);

    -- responder side of the fabric
    signal responders_write_address_valid  : std_logic_vector(config_array'range);
    signal responders_write_address_ready  : std_logic_vector(config_array'range);
    signal responders_write_address_addr   : tgt_addr32_t(config_array'range);
    signal responders_write_data_valid     : std_logic_vector(config_array'range);
    signal responders_write_data_ready     : std_logic_vector(config_array'range);
    signal responders_write_data_data      : tgt_dat32_t(config_array'range);
    signal responders_write_data_strb      : tgt_strb_t(config_array'range);
    signal responders_write_response_ready : std_logic_vector(config_array'range);
    signal responders_write_response_resp  : tgt_resp_t(config_array'range);
    signal responders_write_response_valid : std_logic_vector(config_array'range);
    signal responders_read_address_valid   : std_logic_vector(config_array'range);
    signal responders_read_address_addr    : tgt_addr32_t(config_array'range);
    signal responders_read_address_ready   : std_logic_vector(config_array'range);
    signal responders_read_data_ready      : std_logic_vector(config_array'range);
    signal responders_read_data_resp       : tgt_resp_t(config_array'range);
    signal responders_read_data_valid      : std_logic_vector(config_array'range);
    signal responders_read_data_data       : tgt_dat32_t(config_array'range);

    -- handshake accounting, checked by the testbench
    signal init_aw_hs : integer := 0;
    signal init_b_hs  : integer := 0;
    signal init_ar_hs : integer := 0;
    signal init_r_hs  : integer := 0;
    signal resp_aw_hs : integer := 0;
    signal resp_ar_hs : integer := 0;

begin

    -- 125 MHz, matching the fabric clock in cosmo_seq and grapefruit
    clk       <= not clk after 4 ns;
    reset_por <= '0' after 200 ns;
    reset     <= reset_por or reset_force;

    axi_lite_master_inst: entity vunit_lib.axi_lite_master
        generic map (
            bus_handle => bus_handle
        )
        port map (
            aclk    => clk,
            arready => init_arready,
            arvalid => bfm_arvalid,
            araddr  => bfm_araddr,
            rready  => bfm_rready,
            rvalid  => init_rvalid,
            rdata   => init_rdata,
            rresp   => init_rresp,
            awready => init_awready,
            awvalid => bfm_awvalid,
            awaddr  => bfm_awaddr,
            wready  => init_wready,
            wvalid  => bfm_wvalid,
            wdata   => bfm_wdata,
            wstrb   => bfm_wstrb,
            bvalid  => init_bvalid,
            bready  => bfm_bready,
            bresp   => init_bresp
        );

    init_awvalid <= man_awvalid when man_mode = '1' else bfm_awvalid;
    init_awaddr  <= man_awaddr when man_mode = '1' else bfm_awaddr;
    init_wvalid  <= man_wvalid when man_mode = '1' else bfm_wvalid;
    init_wdata   <= man_wdata when man_mode = '1' else bfm_wdata;
    init_wstrb   <= man_wstrb when man_mode = '1' else bfm_wstrb;
    init_bready  <= man_bready when man_mode = '1' else bfm_bready;
    init_arvalid <= man_arvalid when man_mode = '1' else bfm_arvalid;
    init_araddr  <= man_araddr when man_mode = '1' else bfm_araddr;
    init_rready  <= man_rready when man_mode = '1' else bfm_rready;

    dut: entity work.axil_interconnect_2k8
        generic map (
            initiator_addr_width => INITIATOR_ADDR_WIDTH,
            config_array         => config_array
        )
        port map (
            clk                             => clk,
            reset                           => reset,
            initiator_write_address_addr    => init_awaddr,
            initiator_write_address_valid   => init_awvalid,
            initiator_write_address_ready   => init_awready,
            initiator_write_data_data       => init_wdata,
            initiator_write_data_strb       => init_wstrb,
            initiator_write_data_ready      => init_wready,
            initiator_write_data_valid      => init_wvalid,
            initiator_write_response_valid  => init_bvalid,
            initiator_write_response_resp   => init_bresp,
            initiator_write_response_ready  => init_bready,
            initiator_read_address_addr     => init_araddr,
            initiator_read_address_ready    => init_arready,
            initiator_read_address_valid    => init_arvalid,
            initiator_read_data_valid       => init_rvalid,
            initiator_read_data_ready       => init_rready,
            initiator_read_data_resp        => init_rresp,
            initiator_read_data_data        => init_rdata,
            responders_write_address_valid  => responders_write_address_valid,
            responders_write_address_ready  => responders_write_address_ready,
            responders_write_address_addr   => responders_write_address_addr,
            responders_write_data_valid     => responders_write_data_valid,
            responders_write_data_ready     => responders_write_data_ready,
            responders_write_data_data      => responders_write_data_data,
            responders_write_data_strb      => responders_write_data_strb,
            responders_write_response_ready => responders_write_response_ready,
            responders_read_address_valid   => responders_read_address_valid,
            responders_read_address_addr    => responders_read_address_addr,
            responders_read_data_ready      => responders_read_data_ready,
            responders_write_response_resp  => responders_write_response_resp,
            responders_write_response_valid => responders_write_response_valid,
            responders_read_address_ready   => responders_read_address_ready,
            responders_read_data_resp       => responders_read_data_resp,
            responders_read_data_valid      => responders_read_data_valid,
            responders_read_data_data       => responders_read_data_data
        );

    sram_a: entity work.axil_sram_responder
        generic map (
            addr_width => 8
        )
        port map (
            clk     => clk,
            reset   => reset,
            awvalid => responders_write_address_valid(SRAM_A_IDX),
            awready => responders_write_address_ready(SRAM_A_IDX),
            awaddr  => responders_write_address_addr(SRAM_A_IDX)(7 downto 0),
            wvalid  => responders_write_data_valid(SRAM_A_IDX),
            wready  => responders_write_data_ready(SRAM_A_IDX),
            wdata   => responders_write_data_data(SRAM_A_IDX),
            wstrb   => responders_write_data_strb(SRAM_A_IDX),
            bvalid  => responders_write_response_valid(SRAM_A_IDX),
            bready  => responders_write_response_ready(SRAM_A_IDX),
            bresp   => responders_write_response_resp(SRAM_A_IDX),
            arvalid => responders_read_address_valid(SRAM_A_IDX),
            arready => responders_read_address_ready(SRAM_A_IDX),
            araddr  => responders_read_address_addr(SRAM_A_IDX)(7 downto 0),
            rvalid  => responders_read_data_valid(SRAM_A_IDX),
            rready  => responders_read_data_ready(SRAM_A_IDX),
            rdata   => responders_read_data_data(SRAM_A_IDX),
            rresp   => responders_read_data_resp(SRAM_A_IDX)
        );

    sram_b: entity work.axil_sram_responder
        generic map (
            addr_width => 8
        )
        port map (
            clk     => clk,
            reset   => reset,
            awvalid => responders_write_address_valid(SRAM_B_IDX),
            awready => responders_write_address_ready(SRAM_B_IDX),
            awaddr  => responders_write_address_addr(SRAM_B_IDX)(7 downto 0),
            wvalid  => responders_write_data_valid(SRAM_B_IDX),
            wready  => responders_write_data_ready(SRAM_B_IDX),
            wdata   => responders_write_data_data(SRAM_B_IDX),
            wstrb   => responders_write_data_strb(SRAM_B_IDX),
            bvalid  => responders_write_response_valid(SRAM_B_IDX),
            bready  => responders_write_response_ready(SRAM_B_IDX),
            bresp   => responders_write_response_resp(SRAM_B_IDX),
            arvalid => responders_read_address_valid(SRAM_B_IDX),
            arready => responders_read_address_ready(SRAM_B_IDX),
            araddr  => responders_read_address_addr(SRAM_B_IDX)(7 downto 0),
            rvalid  => responders_read_data_valid(SRAM_B_IDX),
            rready  => responders_read_data_ready(SRAM_B_IDX),
            rdata   => responders_read_data_data(SRAM_B_IDX),
            rresp   => responders_read_data_resp(SRAM_B_IDX)
        );

    slow: entity work.axil_slow_responder
        generic map (
            addr_width => 8,
            seed       => x"5A"
        )
        port map (
            clk     => clk,
            reset   => reset,
            awvalid => responders_write_address_valid(SLOW_IDX),
            awready => responders_write_address_ready(SLOW_IDX),
            awaddr  => responders_write_address_addr(SLOW_IDX)(7 downto 0),
            wvalid  => responders_write_data_valid(SLOW_IDX),
            wready  => responders_write_data_ready(SLOW_IDX),
            wdata   => responders_write_data_data(SLOW_IDX),
            wstrb   => responders_write_data_strb(SLOW_IDX),
            bvalid  => responders_write_response_valid(SLOW_IDX),
            bready  => responders_write_response_ready(SLOW_IDX),
            bresp   => responders_write_response_resp(SLOW_IDX),
            arvalid => responders_read_address_valid(SLOW_IDX),
            arready => responders_read_address_ready(SLOW_IDX),
            araddr  => responders_read_address_addr(SLOW_IDX)(7 downto 0),
            rvalid  => responders_read_data_valid(SLOW_IDX),
            rready  => responders_read_data_ready(SLOW_IDX),
            rdata   => responders_read_data_data(SLOW_IDX),
            rresp   => responders_read_data_resp(SLOW_IDX)
        );

    wide: entity work.axil_sram_responder
        generic map (
            addr_width => 15
        )
        port map (
            clk     => clk,
            reset   => reset,
            awvalid => responders_write_address_valid(WIDE_IDX),
            awready => responders_write_address_ready(WIDE_IDX),
            awaddr  => responders_write_address_addr(WIDE_IDX)(14 downto 0),
            wvalid  => responders_write_data_valid(WIDE_IDX),
            wready  => responders_write_data_ready(WIDE_IDX),
            wdata   => responders_write_data_data(WIDE_IDX),
            wstrb   => responders_write_data_strb(WIDE_IDX),
            bvalid  => responders_write_response_valid(WIDE_IDX),
            bready  => responders_write_response_ready(WIDE_IDX),
            bresp   => responders_write_response_resp(WIDE_IDX),
            arvalid => responders_read_address_valid(WIDE_IDX),
            arready => responders_read_address_ready(WIDE_IDX),
            araddr  => responders_read_address_addr(WIDE_IDX)(14 downto 0),
            rvalid  => responders_read_data_valid(WIDE_IDX),
            rready  => responders_read_data_ready(WIDE_IDX),
            rdata   => responders_read_data_data(WIDE_IDX),
            rresp   => responders_read_data_resp(WIDE_IDX)
        );

    -- Handshake accounting. The testbench compares these at the end of every
    -- test: one initiator write must produce exactly one responder-side AW
    -- handshake, so a fabric or pipeline stage that issues a duplicate write
    -- shows up here even when the data happens to land correctly.
    counters: process(clk, reset)
    begin
        if reset = '1' then
            init_aw_hs <= 0;
            init_b_hs  <= 0;
            init_ar_hs <= 0;
            init_r_hs  <= 0;
            resp_aw_hs <= 0;
            resp_ar_hs <= 0;
        elsif rising_edge(clk) then
            if init_awvalid = '1' and init_awready = '1' then
                init_aw_hs <= init_aw_hs + 1;
            end if;
            if init_bvalid = '1' and init_bready = '1' then
                init_b_hs <= init_b_hs + 1;
            end if;
            if init_arvalid = '1' and init_arready = '1' then
                init_ar_hs <= init_ar_hs + 1;
            end if;
            if init_rvalid = '1' and init_rready = '1' then
                init_r_hs <= init_r_hs + 1;
            end if;
            for i in config_array'range loop
                if responders_write_address_valid(i) = '1' and responders_write_address_ready(i) = '1' then
                    resp_aw_hs <= resp_aw_hs + 1;
                end if;
                if responders_read_address_valid(i) = '1' and responders_read_address_ready(i) = '1' then
                    resp_ar_hs <= resp_ar_hs + 1;
                end if;
            end loop;
        end if;
    end process;

    -- AXI payload stability: while a VALID is asserted without its READY, the
    -- payload it carries must not change.
    stability: process(clk)
        variable prev_awaddr : std_logic_vector(init_awaddr'range);
        variable prev_araddr : std_logic_vector(init_araddr'range);
        variable prev_rdata  : std_logic_vector(init_rdata'range);
        variable had_aw      : boolean := false;
        variable had_ar      : boolean := false;
        variable had_r       : boolean := false;
    begin
        if rising_edge(clk) then
            if reset = '0' and man_mode = '0' then
                if had_aw and init_awvalid = '1' then
                    check_equal(init_awaddr, prev_awaddr, "AWADDR changed while AWVALID was stalled");
                end if;
                if had_ar and init_arvalid = '1' then
                    check_equal(init_araddr, prev_araddr, "ARADDR changed while ARVALID was stalled");
                end if;
                if had_r and init_rvalid = '1' then
                    check_equal(init_rdata, prev_rdata, "RDATA changed while RVALID was stalled");
                end if;
            end if;

            had_aw      := init_awvalid = '1' and init_awready = '0';
            prev_awaddr := init_awaddr;
            had_ar      := init_arvalid = '1' and init_arready = '0';
            prev_araddr := init_araddr;
            had_r       := init_rvalid = '1' and init_rready = '0';
            prev_rdata  := init_rdata;
        end if;
    end process;

end th;
