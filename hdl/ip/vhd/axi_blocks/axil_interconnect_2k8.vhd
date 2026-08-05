-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.numeric_std_unsigned.all;

use work.axil_common_pkg.all;
use work.axilite_if_2k8_pkg.all;

-- This is a somewhat naive implementation of an parameterized AXI-lite interconnect.
-- It is intended to be function as an MVP implementation allowing for basic multi-responder
-- usecases. It is not currently a full cross-bar implementation, but may grow to be one in the future.
-- This is the VHDL 2k8 version which does not use interface views.
--
-- Only one transaction, read or write, is in flight at a time: a registered
-- decode stage selects a responder, the transaction runs to completion, and then
-- the fabric is torn down and re-armed. Everything downstream of here relies on
-- that, so it is worth stating plainly.

entity axil_interconnect_2k8 is
    generic (
        initiator_addr_width : integer;
        config_array : axil_responder_cfg_array_t
    );
    port (
        -- Clock and reset
        clk : in std_logic;
        reset : in std_logic;

        -- Responder I/F to the main initiator, which is a *target* interface
        initiator_write_address_addr : in std_logic_vector(initiator_addr_width - 1 downto 0);
        initiator_write_address_valid : in std_logic;
        initiator_write_address_ready : out std_logic;

        initiator_write_data_data : in std_logic_vector(31 downto 0);
        initiator_write_data_strb : in std_logic_vector(3 downto 0);
        initiator_write_data_ready : out std_logic;
        initiator_write_data_valid : in std_logic;

        initiator_write_response_valid : out std_logic;
        initiator_write_response_resp : out std_logic_vector(1 downto 0);
        initiator_write_response_ready : in std_logic;

        initiator_read_address_addr : in std_logic_vector(initiator_addr_width - 1 downto 0);
        initiator_read_address_ready : out std_logic;
        initiator_read_address_valid : in std_logic;

        initiator_read_data_valid : out std_logic;
        initiator_read_data_ready : in std_logic;
        initiator_read_data_resp : out std_logic_vector(1 downto 0);
        initiator_read_data_data : out std_logic_vector(31 downto 0);

        -- Initiator I/Fs to the responder blocks, which is a *controller* interface
        --responders : view (axil8x32_pkg.axil_controller) of axil8x32_pkg.axil_array_t(config_array'range)
        responders_write_address_valid : out std_logic_vector(config_array'range);
        responders_write_address_ready : in std_logic_vector(config_array'range);
        responders_write_address_addr : out tgt_addr32_t(config_array'range);

        responders_write_data_valid : out std_logic_vector(config_array'range);
        responders_write_data_ready : in std_logic_vector(config_array'range);
        responders_write_data_data: out tgt_dat32_t(config_array'range);
        responders_write_data_strb: out tgt_strb_t(config_array'range);

        responders_write_response_ready : out std_logic_vector(config_array'range);
        responders_write_response_resp : in tgt_resp_t(config_array'range);
        responders_write_response_valid : in std_logic_vector(config_array'range);

        responders_read_address_valid : out std_logic_vector(config_array'range);
        responders_read_address_addr : out tgt_addr32_t(config_array'range);
        responders_read_address_ready : in std_logic_vector(config_array'range);

        responders_read_data_ready : out std_logic_vector(config_array'range);
        responders_read_data_resp : in tgt_resp_t(config_array'range);
        responders_read_data_valid : in std_logic_vector(config_array'range);
        responders_read_data_data : in tgt_dat32_t(config_array'range)

    );
end entity;

architecture rtl of axil_interconnect_2k8 is

    constant ZERO32 : std_logic_vector(31 downto 0) := (others => '0');

    signal wr_addr32 : std_logic_vector(31 downto 0);
    signal rd_addr32 : std_logic_vector(31 downto 0);
    signal wr_hit : std_logic_vector(config_array'range);
    signal rd_hit : std_logic_vector(config_array'range);

    -- Registered select. One bit per responder, at most one set, plus a separate
    -- bit for the catch-all error responder. Keeping this one-hot rather than an
    -- integer index means the return path is a flat AND-OR tree instead of an
    -- integer-to-one-hot decode buried in combinational logic.
    signal sel_onehot : std_logic_vector(config_array'range);
    signal sel_default : std_logic;
    signal sel_is_write : std_logic;
    signal in_txn : boolean;

    -- A write request is only a request once both AW and W are on the bus, which
    -- is the condition every responder applies before asserting AWREADY (see
    -- axil_target_txn). Decoding on AWVALID alone is what let the FMC target's
    -- spurious AWVALID re-assert issue a second write.
    signal wr_req : std_logic;
    signal rd_req : std_logic;

    -- Set when a transaction completes with its request still asserted, and held
    -- until the initiator drops it. Initiators here deassert VALID a cycle after
    -- the handshake, so without this a stale request re-arms the fabric and a
    -- duplicate transaction goes out behind the initiator's back.
    signal wr_hold : std_logic;
    signal rd_hold : std_logic;

    signal write_done : std_logic;
    signal read_done : std_logic;

    -- Fabric side of each responder's optional pipeline. With pipe_stages = 0
    -- these are wired straight through to the responder ports.
    signal mux_write_address_valid : std_logic_vector(config_array'range);
    signal mux_write_address_ready : std_logic_vector(config_array'range);
    signal mux_write_address_addr : tgt_addr32_t(config_array'range);
    signal mux_write_data_valid : std_logic_vector(config_array'range);
    signal mux_write_data_ready : std_logic_vector(config_array'range);
    signal mux_write_data_data : tgt_dat32_t(config_array'range);
    signal mux_write_data_strb : tgt_strb_t(config_array'range);
    signal mux_write_response_valid : std_logic_vector(config_array'range);
    signal mux_write_response_ready : std_logic_vector(config_array'range);
    signal mux_write_response_resp : tgt_resp_t(config_array'range);
    signal mux_read_address_valid : std_logic_vector(config_array'range);
    signal mux_read_address_ready : std_logic_vector(config_array'range);
    signal mux_read_address_addr : tgt_addr32_t(config_array'range);
    signal mux_read_data_valid : std_logic_vector(config_array'range);
    signal mux_read_data_ready : std_logic_vector(config_array'range);
    signal mux_read_data_data : tgt_dat32_t(config_array'range);
    signal mux_read_data_resp : tgt_resp_t(config_array'range);

begin

    assert config_array'low = 0
        report "config_array must be indexed from 0"
        severity failure;
    assert bases_aligned(config_array)
        report "every responder base address must be aligned to its own addr_span_bits"
        severity failure;
    assert ranges_disjoint(config_array)
        report "responder address ranges must not overlap"
        severity failure;
    assert bases_reachable(config_array, initiator_addr_width)
        report "a responder base address is outside the initiator's address space"
        severity failure;

    wr_addr32 <= resize(initiator_write_address_addr, 32);
    rd_addr32 <= resize(initiator_read_address_addr, 32);

    wr_req <= initiator_write_address_valid and initiator_write_data_valid;
    rd_req <= initiator_read_address_valid;

    write_done <= '1' when initiator_write_response_valid = '1' and initiator_write_response_ready = '1' else
                 '0';
    read_done <= '1' when initiator_read_data_valid = '1' and initiator_read_data_ready = '1' else
                '0';

    -- Address decode. Spans are powers of two and bases are aligned to their own
    -- span (asserted above), so "inside the range" is just "the bits above the
    -- span match the base". The masked-off low bits fold away in synthesis,
    -- leaving an equality compare on the upper bits rather than the pair of
    -- magnitude compares, and their carry chains, this used to build. Comparing
    -- over the full 32 bits matters: a narrow initiator must not match a base
    -- that it cannot actually address, and the extra bits are constant zeros.
    hit_gen: for i in config_array'range generate
        constant span : natural := config_array(i).addr_span_bits;
    begin

        wr_hit(i) <= '1' when ((wr_addr32 xor config_array(i).base_addr) and not span_mask(span)) = ZERO32 else
                     '0';
        rd_hit(i) <= '1' when ((rd_addr32 xor config_array(i).base_addr) and not span_mask(span)) = ZERO32 else
                     '0';

    end generate;

    -- Stall the transaction for one cycle while the responder is selected, then
    -- hold that selection until the transaction completes.
    decode: process(clk, reset)
    begin
        if reset = '1' then
            sel_onehot <= (others => '0');
            sel_default <= '0';
            sel_is_write <= '0';
            in_txn <= false;
            wr_hold <= '0';
            rd_hold <= '0';
        elsif rising_edge(clk) then
            -- Per channel re-arm guard, tracked independently so a permanently
            -- asserted AWVALID cannot block reads.
            if write_done = '1' then
                wr_hold <= wr_req;
            elsif wr_hold = '1' and wr_req = '0' then
                wr_hold <= '0';
            end if;

            if read_done = '1' then
                rd_hold <= rd_req;
            elsif rd_hold = '1' and rd_req = '0' then
                rd_hold <= '0';
            end if;

            -- Teardown takes priority over arming. An initiator that leaves
            -- AWVALID asserted past the end of its write must not be able to
            -- pin the fabric to the previous selection.
            if write_done = '1' or read_done = '1' then
                sel_onehot <= (others => '0');
                sel_default <= '0';
                sel_is_write <= '0';
                in_txn <= false;
            elsif not in_txn then
                if wr_req = '1' and wr_hold = '0' then
                    sel_onehot <= wr_hit;
                    sel_default <= not (or wr_hit);
                    sel_is_write <= '1';
                    in_txn <= true;
                elsif rd_req = '1' and rd_hold = '0' then
                    sel_onehot <= rd_hit;
                    sel_default <= not (or rd_hit);
                    sel_is_write <= '0';
                    in_txn <= true;
                end if;
            end if;
        end if;
    end process;

    -- Return path: a one-hot AND-OR mux of the selected responder, or the
    -- catch-all error responder when nothing matched.
    ret_mux: process(all)
        variable awready : std_logic;
        variable wready : std_logic;
        variable bvalid : std_logic;
        variable bresp : std_logic_vector(1 downto 0);
        variable arready : std_logic;
        variable rvalid : std_logic;
        variable rresp : std_logic_vector(1 downto 0);
        variable rdata : std_logic_vector(31 downto 0);
    begin
        awready := '0';
        wready := '0';
        bvalid := '0';
        bresp := SLVERR;
        arready := '0';
        rvalid := '0';
        rresp := SLVERR;
        rdata := (others => '0');

        for i in config_array'range loop
            if sel_onehot(i) = '1' then
                awready := mux_write_address_ready(i);
                wready := mux_write_data_ready(i);
                bvalid := mux_write_response_valid(i);
                bresp := mux_write_response_resp(i);
                arready := mux_read_address_ready(i);
                rvalid := mux_read_data_valid(i);
                rresp := mux_read_data_resp(i);
                rdata := mux_read_data_data(i);
            end if;
        end loop;

        if sel_default = '1' then
            -- Nothing decoded, so answer immediately with an error rather than
            -- hanging the bus. Only the channel that was actually decoded is
            -- answered, so an unmapped read cannot hand an AWREADY to a write
            -- that has not presented its data yet.
            if sel_is_write = '1' then
                awready := '1';
                wready := '1';
                bvalid := '1';
                bresp := SLVERR;
            else
                arready := '1';
                rvalid := '1';
                rresp := SLVERR;
                rdata := X"DEADBEEF";
            end if;
        end if;

        initiator_write_address_ready <= awready;
        initiator_write_data_ready <= wready;
        initiator_write_response_valid <= bvalid;
        initiator_write_response_resp <= bresp;
        initiator_read_address_ready <= arready;
        initiator_read_data_valid <= rvalid;
        initiator_read_data_resp <= rresp;
        initiator_read_data_data <= rdata;
    end process;

    -- Forward path. The payload is broadcast to every responder, masked to that
    -- responder's own span, and only the selected responder sees a valid. The
    -- masked-off address bits are hard constant zeros, so the fabric side of
    -- each responder's address bus collapses to span real wires.
    --
    -- Each responder then optionally goes through axil_pipe, which inserts
    -- config_array(i).pipe_stages register stages in each direction so a
    -- responder that sits a long way from the fabric does not have to be reached
    -- and answered within one clock period. pipe_stages = 0 is a pass-through and
    -- costs nothing.
    resp_gen: for i in config_array'range generate
        constant span : natural := config_array(i).addr_span_bits;
    begin

        mux_write_address_addr(i) <= wr_addr32 and span_mask(span);
        mux_read_address_addr(i) <= rd_addr32 and span_mask(span);
        mux_write_data_data(i) <= initiator_write_data_data;
        mux_write_data_strb(i) <= initiator_write_data_strb;

        mux_write_address_valid(i) <= initiator_write_address_valid and sel_onehot(i);
        mux_write_data_valid(i) <= initiator_write_data_valid and sel_onehot(i);
        mux_write_response_ready(i) <= initiator_write_response_ready and sel_onehot(i);
        mux_read_address_valid(i) <= initiator_read_address_valid and sel_onehot(i);
        mux_read_data_ready(i) <= initiator_read_data_ready and sel_onehot(i);

        axil_pipe_inst: entity work.axil_pipe
         generic map (
            stages => config_array(i).pipe_stages,
            addr_width => span
        )
         port map (
            clk => clk,
            reset => reset,
            sink_awaddr => mux_write_address_addr(i),
            sink_awvalid => mux_write_address_valid(i),
            sink_awready => mux_write_address_ready(i),
            sink_wdata => mux_write_data_data(i),
            sink_wstrb => mux_write_data_strb(i),
            sink_wvalid => mux_write_data_valid(i),
            sink_wready => mux_write_data_ready(i),
            sink_bvalid => mux_write_response_valid(i),
            sink_bresp => mux_write_response_resp(i),
            sink_bready => mux_write_response_ready(i),
            sink_araddr => mux_read_address_addr(i),
            sink_arvalid => mux_read_address_valid(i),
            sink_arready => mux_read_address_ready(i),
            sink_rvalid => mux_read_data_valid(i),
            sink_rdata => mux_read_data_data(i),
            sink_rresp => mux_read_data_resp(i),
            sink_rready => mux_read_data_ready(i),
            source_awaddr => responders_write_address_addr(i),
            source_awvalid => responders_write_address_valid(i),
            source_awready => responders_write_address_ready(i),
            source_wdata => responders_write_data_data(i),
            source_wstrb => responders_write_data_strb(i),
            source_wvalid => responders_write_data_valid(i),
            source_wready => responders_write_data_ready(i),
            source_bvalid => responders_write_response_valid(i),
            source_bresp => responders_write_response_resp(i),
            source_bready => responders_write_response_ready(i),
            source_araddr => responders_read_address_addr(i),
            source_arvalid => responders_read_address_valid(i),
            source_arready => responders_read_address_ready(i),
            source_rvalid => responders_read_data_valid(i),
            source_rdata => responders_read_data_data(i),
            source_rresp => responders_read_data_resp(i),
            source_rready => responders_read_data_ready(i)
        );

    end generate;

end rtl;
