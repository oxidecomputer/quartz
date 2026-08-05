-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.axil_common_pkg.all;

-- Configurable pipeline stages between the interconnect fabric and one
-- responder, so a responder that is physically far from the fabric does not have
-- to be reached and answered inside a single clock period.
--
-- The fabric admits one transaction, read or write, at a time. That means this
-- does not have to be five independent AXI channel register slices: the whole
-- transaction serializes into one request bundle going out and one response
-- bundle coming back, which is roughly a third of the flops a pair of full
-- register slices would cost, with a single token chain instead of five sets of
-- valid/ready control.
--
-- Each payload stage advances only behind its own token, so every stage holds
-- what it was given until the next transaction pushes through it. That is what
-- keeps the far end of the chain stable across a multi-cycle handshake, and it is
-- why no separate capture register is needed at either end. Gating the whole
-- chain on the OR of all the tokens instead would clobber the last stage on the
-- cycle the token reached it.
--
-- The single-outstanding-transaction property of the fabric is load bearing here:
-- it is what makes it safe for a stage to hold its payload indefinitely, and what
-- guarantees a new request cannot enter the chain while a response is still on
-- its way back.
--
-- Round trip latency is 2 * stages cycles plus a handful of fixed handshake
-- cycles. stages = 0 is a plain pass-through and costs nothing.

entity axil_pipe is
    generic (
        --! Register stages inserted in *each* direction
        stages : natural;
        --! Address bits this responder actually decodes
        addr_width : natural
    );
    port (
        clk : in std_logic;
        reset : in std_logic;

        -- Fabric facing side, a *target* interface
        sink_awaddr : in std_logic_vector(31 downto 0);
        sink_awvalid : in std_logic;
        sink_awready : out std_logic;

        sink_wdata : in std_logic_vector(31 downto 0);
        sink_wstrb : in std_logic_vector(3 downto 0);
        sink_wvalid : in std_logic;
        sink_wready : out std_logic;

        sink_bvalid : out std_logic;
        sink_bresp : out std_logic_vector(1 downto 0);
        sink_bready : in std_logic;

        sink_araddr : in std_logic_vector(31 downto 0);
        sink_arvalid : in std_logic;
        sink_arready : out std_logic;

        sink_rvalid : out std_logic;
        sink_rdata : out std_logic_vector(31 downto 0);
        sink_rresp : out std_logic_vector(1 downto 0);
        sink_rready : in std_logic;

        -- Responder facing side, a *controller* interface
        source_awaddr : out std_logic_vector(31 downto 0);
        source_awvalid : out std_logic;
        source_awready : in std_logic;

        source_wdata : out std_logic_vector(31 downto 0);
        source_wstrb : out std_logic_vector(3 downto 0);
        source_wvalid : out std_logic;
        source_wready : in std_logic;

        source_bvalid : in std_logic;
        source_bresp : in std_logic_vector(1 downto 0);
        source_bready : out std_logic;

        source_araddr : out std_logic_vector(31 downto 0);
        source_arvalid : out std_logic;
        source_arready : in std_logic;

        source_rvalid : in std_logic;
        source_rdata : in std_logic_vector(31 downto 0);
        source_rresp : in std_logic_vector(1 downto 0);
        source_rready : out std_logic
    );
end entity;

architecture rtl of axil_pipe is

begin

    pipe_gen: if stages > 0 generate

        -- request bundle: is_write & addr & wdata & wstrb
        constant STRB_LO : natural := 0;
        constant STRB_HI : natural := 3;
        constant DATA_LO : natural := 4;
        constant DATA_HI : natural := 35;
        constant ADDR_LO : natural := 36;
        constant ADDR_HI : natural := 36 + addr_width - 1;
        constant IS_WRITE : natural := ADDR_HI + 1;
        constant REQ_W : natural := IS_WRITE + 1;

        -- response bundle: rdata & resp
        constant RESP_LO : natural := 0;
        constant RESP_HI : natural := 1;
        constant RDATA_LO : natural := 2;
        constant RDATA_HI : natural := 33;
        constant RSP_W : natural := RDATA_HI + 1;

        constant LAST : natural := stages - 1;

        type req_sr_t is array (0 to stages - 1) of std_logic_vector(REQ_W - 1 downto 0);
        type rsp_sr_t is array (0 to stages - 1) of std_logic_vector(RSP_W - 1 downto 0);

        -- deliberately not reset: only the tokens need to come up clean, and
        -- leaving the payload chain resetless lets Vivado map it to SRLs
        signal req_sr : req_sr_t;
        signal rsp_sr : rsp_sr_t;

        signal fwd_tok : std_logic_vector(stages - 1 downto 0);
        signal ret_tok : std_logic_vector(stages - 1 downto 0);

        type sink_state_t is (armed, wait_rsp, respond, request_gap);

        signal sink_state : sink_state_t;
        signal sink_is_write : std_logic;
        --! registered one-shot, so AW and W always handshake in the same cycle
        --! and AWREADY never depends combinationally on AWVALID
        signal sink_wr_ack : std_logic;
        signal sink_rd_ack : std_logic;
        signal sink_resp_valid : std_logic;

        type source_state_t is (idle, issue);

        signal source_state : source_state_t;
        signal src_is_write : std_logic;
        signal src_awvalid : std_logic;
        signal src_wvalid : std_logic;
        signal src_arvalid : std_logic;
        signal src_bready : std_logic;
        signal src_rready : std_logic;
        signal src_aw_done : std_logic;
        signal src_w_done : std_logic;
        signal src_b_done : std_logic;
        signal src_ar_done : std_logic;
        signal src_r_done : std_logic;

    begin

        sink_awready <= sink_wr_ack;
        sink_wready <= sink_wr_ack;
        sink_arready <= sink_rd_ack;
        sink_bvalid <= sink_resp_valid and sink_is_write;
        sink_rvalid <= sink_resp_valid and not sink_is_write;
        sink_bresp <= rsp_sr(LAST)(RESP_HI downto RESP_LO);
        sink_rresp <= rsp_sr(LAST)(RESP_HI downto RESP_LO);
        sink_rdata <= rsp_sr(LAST)(RDATA_HI downto RDATA_LO);

        source_awvalid <= src_awvalid;
        source_wvalid <= src_wvalid;
        source_arvalid <= src_arvalid;
        source_bready <= src_bready;
        source_rready <= src_rready;
        source_wdata <= req_sr(LAST)(DATA_HI downto DATA_LO);
        source_wstrb <= req_sr(LAST)(STRB_HI downto STRB_LO);
        -- the fabric already masked the address to this responder's span, so the
        -- bits above it are constant zeros
        source_awaddr <= (31 downto addr_width => '0') & req_sr(LAST)(ADDR_HI downto ADDR_LO);
        source_araddr <= (31 downto addr_width => '0') & req_sr(LAST)(ADDR_HI downto ADDR_LO);

        -- Outbound: accept a transaction from the fabric, walk it down to the
        -- responder, and present the response that comes back.
        fwd: process(clk, reset)
        begin
            if reset = '1' then
                sink_state <= armed;
                sink_is_write <= '0';
                sink_wr_ack <= '0';
                sink_rd_ack <= '0';
                sink_resp_valid <= '0';
                fwd_tok <= (others => '0');
            elsif rising_edge(clk) then
                sink_wr_ack <= '0';
                sink_rd_ack <= '0';

                for j in stages - 1 downto 1 loop
                    fwd_tok(j) <= fwd_tok(j - 1);
                    if fwd_tok(j - 1) = '1' then
                        req_sr(j) <= req_sr(j - 1);
                    end if;
                end loop;
                fwd_tok(0) <= '0';

                case sink_state is
                    when armed =>
                        -- A write is only taken once AW and W are both present,
                        -- which is what every responder in the tree requires
                        -- before asserting AWREADY. WDATA has to be captured
                        -- here: the FMC target's write data FIFO pops on the W
                        -- handshake, so it is not valid afterwards.
                        if sink_awvalid = '1' and sink_wvalid = '1' then
                            req_sr(0)(IS_WRITE) <= '1';
                            req_sr(0)(ADDR_HI downto ADDR_LO) <= sink_awaddr(addr_width - 1 downto 0);
                            req_sr(0)(DATA_HI downto DATA_LO) <= sink_wdata;
                            req_sr(0)(STRB_HI downto STRB_LO) <= sink_wstrb;
                            fwd_tok(0) <= '1';
                            sink_wr_ack <= '1';
                            sink_is_write <= '1';
                            sink_state <= wait_rsp;
                        elsif sink_arvalid = '1' then
                            req_sr(0)(IS_WRITE) <= '0';
                            req_sr(0)(ADDR_HI downto ADDR_LO) <= sink_araddr(addr_width - 1 downto 0);
                            fwd_tok(0) <= '1';
                            sink_rd_ack <= '1';
                            sink_is_write <= '0';
                            sink_state <= wait_rsp;
                        end if;

                    when wait_rsp =>
                        if ret_tok(LAST) = '1' then
                            sink_resp_valid <= '1';
                            sink_state <= respond;
                        end if;

                    when respond =>
                        if (sink_is_write = '1' and sink_bready = '1') or
                           (sink_is_write = '0' and sink_rready = '1') then
                            sink_resp_valid <= '0';
                            sink_state <= request_gap;
                        end if;

                    when request_gap =>
                        -- Do not re-arm until the request that just completed is
                        -- off the bus. Initiators here deassert VALID a cycle
                        -- after the handshake, so without this a stale request
                        -- would be issued a second time.
                        if (sink_is_write = '1' and not (sink_awvalid = '1' and sink_wvalid = '1')) or
                           (sink_is_write = '0' and sink_arvalid = '0') then
                            sink_state <= armed;
                        end if;

                end case;
            end if;
        end process;

        -- Inbound: run the transaction against the responder and walk the
        -- response back up. AW and W are tracked separately because responders
        -- are allowed to accept them independently, and the handshakes are all
        -- sampled in one state because axil_target_txn presents BVALID as a
        -- single cycle pulse when BREADY is already asserted and ARREADY
        -- combinationally, so a dedicated wait-for-response state would miss
        -- them.
        ret: process(clk, reset)
            variable aw_done : std_logic;
            variable w_done : std_logic;
            variable b_done : std_logic;
            variable ar_done : std_logic;
            variable r_done : std_logic;
        begin
            if reset = '1' then
                source_state <= idle;
                src_is_write <= '0';
                src_awvalid <= '0';
                src_wvalid <= '0';
                src_arvalid <= '0';
                src_bready <= '0';
                src_rready <= '0';
                src_aw_done <= '0';
                src_w_done <= '0';
                src_b_done <= '0';
                src_ar_done <= '0';
                src_r_done <= '0';
                ret_tok <= (others => '0');
            elsif rising_edge(clk) then
                for j in stages - 1 downto 1 loop
                    ret_tok(j) <= ret_tok(j - 1);
                    if ret_tok(j - 1) = '1' then
                        rsp_sr(j) <= rsp_sr(j - 1);
                    end if;
                end loop;
                ret_tok(0) <= '0';

                case source_state is
                    when idle =>
                        if fwd_tok(LAST) = '1' then
                            src_is_write <= req_sr(LAST)(IS_WRITE);
                            if req_sr(LAST)(IS_WRITE) = '1' then
                                src_awvalid <= '1';
                                src_wvalid <= '1';
                                src_bready <= '1';
                            else
                                src_arvalid <= '1';
                                src_rready <= '1';
                            end if;
                            src_aw_done <= '0';
                            src_w_done <= '0';
                            src_b_done <= '0';
                            src_ar_done <= '0';
                            src_r_done <= '0';
                            source_state <= issue;
                        end if;

                    when issue =>
                        aw_done := src_aw_done;
                        w_done := src_w_done;
                        b_done := src_b_done;
                        ar_done := src_ar_done;
                        r_done := src_r_done;

                        if src_awvalid = '1' and source_awready = '1' then
                            src_awvalid <= '0';
                            aw_done := '1';
                        end if;
                        if src_wvalid = '1' and source_wready = '1' then
                            src_wvalid <= '0';
                            w_done := '1';
                        end if;
                        if source_bvalid = '1' and src_bready = '1' then
                            b_done := '1';
                            rsp_sr(0)(RESP_HI downto RESP_LO) <= source_bresp;
                        end if;
                        if src_arvalid = '1' and source_arready = '1' then
                            src_arvalid <= '0';
                            ar_done := '1';
                        end if;
                        if source_rvalid = '1' and src_rready = '1' then
                            r_done := '1';
                            rsp_sr(0)(RDATA_HI downto RDATA_LO) <= source_rdata;
                            rsp_sr(0)(RESP_HI downto RESP_LO) <= source_rresp;
                        end if;

                        src_aw_done <= aw_done;
                        src_w_done <= w_done;
                        src_b_done <= b_done;
                        src_ar_done <= ar_done;
                        src_r_done <= r_done;

                        if (src_is_write = '1' and aw_done = '1' and w_done = '1' and b_done = '1') or
                           (src_is_write = '0' and ar_done = '1' and r_done = '1') then
                            ret_tok(0) <= '1';
                            src_bready <= '0';
                            src_rready <= '0';
                            source_state <= idle;
                        end if;

                end case;
            end if;
        end process;

    else generate

        sink_awready <= source_awready;
        sink_wready <= source_wready;
        sink_bvalid <= source_bvalid;
        sink_bresp <= source_bresp;
        sink_arready <= source_arready;
        sink_rvalid <= source_rvalid;
        sink_rdata <= source_rdata;
        sink_rresp <= source_rresp;

        source_awaddr <= sink_awaddr;
        source_awvalid <= sink_awvalid;
        source_wdata <= sink_wdata;
        source_wstrb <= sink_wstrb;
        source_wvalid <= sink_wvalid;
        source_bready <= sink_bready;
        source_araddr <= sink_araddr;
        source_arvalid <= sink_arvalid;
        source_rready <= sink_rready;

    end generate;

end rtl;
