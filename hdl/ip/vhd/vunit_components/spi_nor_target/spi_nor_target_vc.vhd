-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Winbond W25Q-family QSPI NOR flash target model.
--
-- This exists to answer two questions the previous "pull the bus to 'H' and
-- eyeball the waveform" harness could not:
--
--  1) does the controller sample read data at the right point, and
--  2) does it meet the flash's AC timing at the sclk rate we want to run.
--
-- So read data is driven with a real tCLQV output delay and is only held until
-- tCLQX after the falling edge, going to 'X' in between. A controller that
-- samples outside the valid window therefore shifts in 'X' and fails the
-- testbench's data check rather than quietly producing a plausible waveform.
-- MOSI setup/hold and the chip-select timing are checked directly.
--
-- Bit ordering follows the datasheet: on multi-bit transfers the highest
-- numbered IO carries the most significant bit of each group.

library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

library vunit_lib;
    context vunit_lib.vunit_context;
    context vunit_lib.com_context;

use work.spi_nor_target_vc_pkg.all;

entity spi_nor_target_vc is
    generic (
        actor_name : string := "spi_nor_target";
        -- W25Q01JV AC characteristics. The read data path delays are the
        -- interesting ones; they are what bounds the controller's usable
        -- sample window.
        t_clqv : time := 6 ns;    -- clock low to output valid (max)
        t_clqx : time := 1.5 ns;  -- output hold after clock low (min)
        t_dvch : time := 2 ns;    -- data in setup to clock high
        t_chdx : time := 3 ns;    -- data in hold after clock high
        t_slch : time := 5 ns;    -- cs low to first clock high
        t_shsl : time := 30 ns;   -- cs high time between transactions
        -- Winbond manufacturer id, W25Q01JV device id
        jedec_id  : std_logic_vector(23 downto 0) := x"EF4021";
        unique_id : std_logic_vector(63 downto 0) := x"0123456789ABCDEF"
    );
    port (
        cs_n : in    std_logic;
        sclk : in    std_logic;
        -- Resolved bus as seen by the part
        io : in    std_logic_vector(3 downto 0);
        -- Model's contribution to the bus, resolved externally so that
        -- contention with the controller is visible
        io_o  : out   std_logic_vector(3 downto 0) := (others => '0');
        io_oe : out   std_logic_vector(3 downto 0) := (others => '0')
    );
end entity;

architecture model of spi_nor_target_vc is

    -- Opcodes this model understands. Anything else is logged and treated as a
    -- no-operand command.
    constant OP_WRITE_ENABLE         : std_logic_vector(7 downto 0) := x"06";
    constant OP_WRITE_DISABLE        : std_logic_vector(7 downto 0) := x"04";
    constant OP_READ_STATUS_1        : std_logic_vector(7 downto 0) := x"05";
    constant OP_READ_STATUS_2        : std_logic_vector(7 downto 0) := x"35";
    constant OP_READ_STATUS_3        : std_logic_vector(7 downto 0) := x"15";
    constant OP_WRITE_STATUS_1       : std_logic_vector(7 downto 0) := x"01";
    constant OP_WRITE_STATUS_2       : std_logic_vector(7 downto 0) := x"31";
    constant OP_WRITE_STATUS_3       : std_logic_vector(7 downto 0) := x"11";
    constant OP_READ_DATA            : std_logic_vector(7 downto 0) := x"03";
    constant OP_READ_DATA_4B         : std_logic_vector(7 downto 0) := x"13";
    constant OP_FAST_READ            : std_logic_vector(7 downto 0) := x"0B";
    constant OP_FAST_READ_4B         : std_logic_vector(7 downto 0) := x"0C";
    constant OP_FAST_READ_DUAL       : std_logic_vector(7 downto 0) := x"3B";
    constant OP_FAST_READ_DUAL_4B    : std_logic_vector(7 downto 0) := x"3C";
    constant OP_FAST_READ_QUAD       : std_logic_vector(7 downto 0) := x"6B";
    constant OP_FAST_READ_QUAD_4B    : std_logic_vector(7 downto 0) := x"6C";
    constant OP_PAGE_PROGRAM         : std_logic_vector(7 downto 0) := x"02";
    constant OP_PAGE_PROGRAM_4B      : std_logic_vector(7 downto 0) := x"12";
    constant OP_QUAD_PAGE_PROGRAM    : std_logic_vector(7 downto 0) := x"32";
    constant OP_QUAD_PAGE_PROGRAM_4B : std_logic_vector(7 downto 0) := x"34";
    constant OP_SECTOR_ERASE         : std_logic_vector(7 downto 0) := x"20";
    constant OP_SECTOR_ERASE_4B      : std_logic_vector(7 downto 0) := x"21";
    constant OP_BLOCK_ERASE_32K      : std_logic_vector(7 downto 0) := x"52";
    constant OP_BLOCK_ERASE_64K      : std_logic_vector(7 downto 0) := x"D8";
    constant OP_BLOCK_ERASE_64K_4B   : std_logic_vector(7 downto 0) := x"DC";
    constant OP_READ_JEDEC_ID        : std_logic_vector(7 downto 0) := x"9F";
    constant OP_READ_UNIQUE_ID       : std_logic_vector(7 downto 0) := x"4B";
    constant OP_DIE_SELECT           : std_logic_vector(7 downto 0) := x"C2";

    constant SECTOR_BYTES  : natural := 16#1000#;
    constant BLOCK32_BYTES : natural := 16#8000#;
    constant BLOCK64_BYTES : natural := 16#10000#;
    constant PAGE_BYTES    : natural := 256;

    type phase_t is (ph_cmd, ph_addr, ph_dummy, ph_rd, ph_wr, ph_done);

    -- Where read data comes from for the current opcode
    type src_t is (src_mem, src_jedec, src_status, src_uid);

    shared variable mem : flash_mem_t;

    signal clqv : time := t_clqv;

    -- Snapshot of the bits sampled at the last input clock edge, published so
    -- the hold checker can look at them tCHDX later.
    signal sample_evt   : std_logic                    := '0';
    signal sampled_data : std_logic_vector(3 downto 0) := (others => '0');
    signal sampled_lane : std_logic_vector(3 downto 0) := (others => '0');

    signal dbg_phase  : phase_t                      := ph_cmd;
    signal dbg_opcode : std_logic_vector(7 downto 0) := (others => '0');

    constant vc_logger : logger_t := get_logger("work:spi_nor_target_vc");

begin

    -- MOSI hold check. The main process publishes what it sampled and on which
    -- lanes; tCHDX later those lanes must still be holding the same value.
    hold_check : process is

        variable lanes : std_logic_vector(3 downto 0);
        variable data  : std_logic_vector(3 downto 0);

    begin
        wait on sample_evt;
        lanes := sampled_lane;
        data  := sampled_data;
        wait for t_chdx;

        for i in lanes'range loop
            if lanes(i) = '1' and cs_n = '0' then
                if io(i) /= data(i) then
                    error(vc_logger, "Input hold (tCHDX) violated on io(" & to_string(i) &
                                     "): sampled " & to_string(data(i)) &
                                     " but bus is now " & to_string(io(i)));
                end if;
            end if;
        end loop;
    end process;

    -- Main protocol engine. Everything lives in one process so that the
    -- rising-edge sampling and the falling-edge output presentation share
    -- state with no inter-process delta delay.
    proto : process (sclk, cs_n) is

        variable phase      : phase_t                      := ph_cmd;
        variable bit_cnt    : natural                      := 0;
        variable in_shifter : std_logic_vector(7 downto 0) := (others => '0');
        variable opcode     : std_logic_vector(7 downto 0) := (others => '0');
        variable addr       : unsigned(31 downto 0)        := (others => '0');
        variable addr_left  : natural                      := 0;
        variable dummy_left : natural                      := 0;
        variable in_width   : natural                      := 1;
        variable out_width  : natural                      := 1;
        variable out_src    : src_t                        := src_mem;
        variable rd_idx     : natural                      := 0;
        variable wr_idx     : natural                      := 0;
        variable out_shift  : std_logic_vector(7 downto 0) := (others => '0');
        variable out_left   : natural                      := 0;
        variable status     : std_logic_vector(7 downto 0) := x"00";
        variable erase_len  : natural                      := 0;
        variable do_erase   : boolean                      := false;
        -- Set when the host clocks the part in a way that makes the instruction
        -- invalid. The real part discards such a command silently, so anything
        -- it would have done has to be suppressed too or the model is more
        -- forgiving than the hardware and the testbench proves nothing.
        variable cmd_invalid : boolean := false;
        variable modelled    : boolean := true;
        variable cs_fall_at : time                         := 0 ps;
        variable cs_rise_at : time                         := 0 ps;
        variable first_clk  : boolean                      := true;
        variable t_invalid  : time                         := t_clqx;

        -- The window is far smaller than the real part, so translate a flash
        -- address into an index the backing store understands. Anything past
        -- the window reads as erased.
        impure function mem_addr (a : unsigned) return natural is
        begin
            if a < flash_window_bytes then
                return to_integer(a);
            else
                return flash_window_bytes;
            end if;
        end function;

        -- Lanes the controller is expected to be driving in the current phase
        impure function in_lanes return std_logic_vector is
        begin
            case in_width is
                when 4 =>
                    return "1111";
                when 2 =>
                    return "0011";
                when others =>
                    return "0001";
            end case;
        end function;

        -- Setup check, split out so every call site uses a literal index and
        -- the attribute prefix stays a static signal name.
        procedure check_setup (constant idx : natural; constant since : time) is
        begin
            if since < t_dvch then
                error(vc_logger, "Input setup (tDVCH) violated on io(" & to_string(idx) &
                                 "): last changed " & to_string(since) & " before sclk");
            end if;
        end procedure;

        -- Next byte the part would present, from whichever source the current
        -- opcode selected
        impure function next_out_byte return std_logic_vector is

            variable b : std_logic_vector(7 downto 0);
            variable k : natural;

        begin
            case out_src is
                when src_jedec =>
                    -- 3 id bytes, repeating for as long as the host clocks
                    k := rd_idx mod 3;
                    b := jedec_id(23 - 8 * k downto 16 - 8 * k);
                when src_status =>
                    b := status;
                when src_uid =>
                    if rd_idx < 8 then
                        b := unique_id(63 - 8 * rd_idx downto 56 - 8 * rd_idx);
                    else
                        b := x"FF";
                    end if;
                when src_mem =>
                    b := mem.get(mem_addr(addr + rd_idx));
            end case;

            rd_idx := rd_idx + 1;
            return b;
        end function;

        -- Decode the opcode into the phase sequence and bus widths
        procedure decode is
        begin
            in_width   := 1;
            out_width  := 1;
            out_src    := src_mem;
            rd_idx     := 0;
            wr_idx     := 0;
            addr       := (others => '0');
            addr_left  := 0;
            dummy_left := 0;
            do_erase   := false;
            erase_len  := 0;

            case opcode is
                when OP_READ_JEDEC_ID =>
                    out_src := src_jedec;
                    phase   := ph_rd;
                when OP_READ_UNIQUE_ID =>
                    out_src    := src_uid;
                    dummy_left := 32;
                    phase      := ph_dummy;
                when OP_READ_STATUS_1 | OP_READ_STATUS_2 | OP_READ_STATUS_3 =>
                    out_src := src_status;
                    phase   := ph_rd;
                when OP_WRITE_STATUS_1 | OP_WRITE_STATUS_2 | OP_WRITE_STATUS_3 =>
                    phase := ph_wr;
                when OP_WRITE_ENABLE =>
                    status := status or x"02";
                    phase  := ph_done;
                when OP_WRITE_DISABLE =>
                    status := status and x"FD";
                    phase  := ph_done;
                when OP_DIE_SELECT =>
                    phase := ph_wr;
                when OP_READ_DATA =>
                    addr_left := 3;
                    phase     := ph_addr;
                when OP_READ_DATA_4B =>
                    addr_left := 4;
                    phase     := ph_addr;
                when OP_FAST_READ =>
                    addr_left  := 3;
                    dummy_left := 8;
                    phase      := ph_addr;
                when OP_FAST_READ_4B =>
                    addr_left  := 4;
                    dummy_left := 8;
                    phase      := ph_addr;
                when OP_FAST_READ_DUAL =>
                    addr_left  := 3;
                    dummy_left := 8;
                    out_width  := 2;
                    phase      := ph_addr;
                when OP_FAST_READ_DUAL_4B =>
                    addr_left  := 4;
                    dummy_left := 8;
                    out_width  := 2;
                    phase      := ph_addr;
                when OP_FAST_READ_QUAD =>
                    addr_left  := 3;
                    dummy_left := 8;
                    out_width  := 4;
                    phase      := ph_addr;
                when OP_FAST_READ_QUAD_4B =>
                    addr_left  := 4;
                    dummy_left := 8;
                    out_width  := 4;
                    phase      := ph_addr;
                when OP_PAGE_PROGRAM =>
                    addr_left := 3;
                    phase     := ph_addr;
                when OP_PAGE_PROGRAM_4B =>
                    addr_left := 4;
                    phase     := ph_addr;
                when OP_QUAD_PAGE_PROGRAM =>
                    addr_left := 3;
                    phase     := ph_addr;
                when OP_QUAD_PAGE_PROGRAM_4B =>
                    addr_left := 4;
                    phase     := ph_addr;
                when OP_SECTOR_ERASE =>
                    addr_left := 3;
                    erase_len := SECTOR_BYTES;
                    phase     := ph_addr;
                when OP_SECTOR_ERASE_4B =>
                    addr_left := 4;
                    erase_len := SECTOR_BYTES;
                    phase     := ph_addr;
                when OP_BLOCK_ERASE_32K =>
                    addr_left := 3;
                    erase_len := BLOCK32_BYTES;
                    phase     := ph_addr;
                when OP_BLOCK_ERASE_64K =>
                    addr_left := 3;
                    erase_len := BLOCK64_BYTES;
                    phase     := ph_addr;
                when OP_BLOCK_ERASE_64K_4B =>
                    addr_left := 4;
                    erase_len := BLOCK64_BYTES;
                    phase     := ph_addr;
                when others =>
                    info(vc_logger, "Unmodelled opcode 0x" & to_hstring(opcode) &
                                    ", treating as no-operand");
                    -- Don't police the clock count for something we can't decode
                    modelled := false;
                    phase    := ph_done;
            end case;
        end procedure;

        -- What follows the address phase for this opcode
        procedure after_addr is
        begin
            if dummy_left > 0 then
                phase := ph_dummy;
            elsif erase_len > 0 then
                do_erase := true;
                phase    := ph_done;
            elsif opcode = OP_READ_DATA or opcode = OP_READ_DATA_4B then
                phase := ph_rd;
            elsif opcode = OP_PAGE_PROGRAM or opcode = OP_PAGE_PROGRAM_4B then
                phase := ph_wr;
            elsif opcode = OP_QUAD_PAGE_PROGRAM or opcode = OP_QUAD_PAGE_PROGRAM_4B then
                in_width := 4;
                phase    := ph_wr;
            else
                phase := ph_done;
            end if;
        end procedure;

        -- Programs wrap within the 256 byte page rather than running on
        procedure program_byte (constant data : std_logic_vector(7 downto 0)) is

            variable page_base : unsigned(31 downto 0);
            variable offset    : natural;

        begin
            page_base := addr(31 downto 8) & x"00";
            offset    := (to_integer(addr(7 downto 0)) + wr_idx) mod PAGE_BYTES;
            mem.set(mem_addr(page_base + offset), data);
            wr_idx := wr_idx + 1;
        end procedure;

    begin
        if cs_n /= '0' then
            if cs_n = '1' and cs_n'event then
                cs_rise_at := now;

                -- The part latches an instruction only if cs_n rises on a byte
                -- boundary. Trailing clocks that leave a partial byte make the
                -- whole command invalid, and it is discarded without any
                -- indication -- an erase simply does not happen.
                if bit_cnt /= 0 then
                    cmd_invalid := true;
                    error(vc_logger, "cs_n rose " & to_string(bit_cnt) &
                                     " bits into a byte, instruction 0x" &
                                     to_hstring(opcode) & " is discarded");
                end if;
            end if;

            -- Deselected: finish any pending erase, then reset per-transaction
            -- state. Erases are modelled as instantaneous on deselect.
            if do_erase then
                if not cmd_invalid then
                    mem.erase((mem_addr(addr) / erase_len) * erase_len, erase_len);
                end if;
                do_erase := false;
            end if;

            cmd_invalid := false;
            modelled    := true;
            phase      := ph_cmd;
            bit_cnt    := 0;
            in_width   := 1;
            out_width  := 1;
            out_left   := 0;
            first_clk  := true;
            in_shifter := (others => '0');
            io_oe      <= (others => '0');
            io_o       <= (others => '0');
        else
            if cs_n = '0' and cs_n'event then
                cs_fall_at := now;

                -- tSHSL: the part needs the select to stay high for a while
                -- between transactions. Back to back page reads are the case
                -- that trips this.
                if cs_rise_at > 0 ps and now - cs_rise_at < t_shsl then
                    error(vc_logger, "cs_n high time (tSHSL) violated: " &
                                     to_string(now - cs_rise_at) & " < " & to_string(t_shsl));
                end if;
            end if;

            if rising_edge(sclk) then
                if first_clk then
                    first_clk := false;
                    if now - cs_fall_at < t_slch then
                        error(vc_logger, "cs_n to first sclk (tSLCH) violated: " &
                                         to_string(now - cs_fall_at) & " < " & to_string(t_slch));
                    end if;
                end if;

                case phase is
                    when ph_cmd | ph_addr | ph_wr =>
                        -- Setup check on the lanes the controller owns, then
                        -- shift the group in. Highest lane is the msb.
                        check_setup(0, io(0)'last_event);
                        if in_width >= 2 then
                            check_setup(1, io(1)'last_event);
                        end if;
                        if in_width = 4 then
                            check_setup(2, io(2)'last_event);
                            check_setup(3, io(3)'last_event);
                        end if;

                        sampled_data <= io;
                        sampled_lane <= in_lanes;
                        sample_evt   <= not sample_evt;

                        if in_width = 4 then
                            in_shifter := in_shifter(3 downto 0) & io(3) & io(2) & io(1) & io(0);
                        elsif in_width = 2 then
                            in_shifter := in_shifter(5 downto 0) & io(1) & io(0);
                        else
                            in_shifter := in_shifter(6 downto 0) & io(0);
                        end if;
                        bit_cnt := bit_cnt + in_width;

                        if bit_cnt = 8 then
                            bit_cnt := 0;

                            case phase is
                                when ph_cmd =>
                                    opcode := in_shifter;
                                    decode;
                                when ph_addr =>
                                    addr      := addr(23 downto 0) & unsigned(in_shifter);
                                    addr_left := addr_left - 1;
                                    if addr_left = 0 then
                                        after_addr;
                                    end if;
                                when ph_wr =>
                                    if opcode = OP_DIE_SELECT or
                                       opcode = OP_WRITE_STATUS_1 or
                                       opcode = OP_WRITE_STATUS_2 or
                                       opcode = OP_WRITE_STATUS_3 then
                                        status := in_shifter;
                                    else
                                        program_byte(in_shifter);
                                    end if;
                                when others =>
                                    null;
                            end case;
                        end if;

                    when ph_dummy =>
                        dummy_left := dummy_left - 1;
                        if dummy_left = 0 then
                            -- Data starts on the next falling edge
                            phase    := ph_rd;
                            out_left := 0;
                        end if;

                    when ph_rd =>
                        null;

                    when ph_done =>
                        -- The instruction and its operands are complete, so the
                        -- host should have raised cs_n by now. Clocking on makes
                        -- the command invalid: an erase or a write enable that
                        -- gets trailing clocks is thrown away, which shows up
                        -- much later as "the sector did not erase".
                        if modelled and not cmd_invalid then
                            cmd_invalid := true;
                            error(vc_logger, "sclk continued after instruction 0x" &
                                             to_hstring(opcode) &
                                             " completed, command is discarded");
                        end if;
                end case;
            elsif falling_edge(sclk) then
                if phase = ph_rd then
                    if out_left = 0 then
                        out_shift := next_out_byte;
                        out_left  := 8;
                    end if;

                    -- Hold the previous value until tCLQX, go invalid, then
                    -- present the new group at tCLQV. The invalid gap is what
                    -- makes the controller's sample point matter.
                    t_invalid := t_clqx;
                    if t_invalid >= clqv then
                        t_invalid := clqv / 2;
                    end if;

                    case out_width is
                        when 4 =>
                            io_o <= "XXXX" after t_invalid,
                                    out_shift(7 downto 4) after clqv;
                            io_oe     <= "1111" after t_invalid;
                            out_shift := out_shift(3 downto 0) & x"F";
                            out_left  := out_left - 4;
                        when 2 =>
                            io_o(1 downto 0) <= "XX" after t_invalid,
                                                out_shift(7 downto 6) after clqv;
                            io_oe     <= "0011" after t_invalid;
                            out_shift := out_shift(5 downto 0) & "11";
                            out_left  := out_left - 2;
                        when others =>
                            io_o(1) <= 'X' after t_invalid,
                                       out_shift(7) after clqv;
                            io_oe     <= "0010" after t_invalid;
                            out_shift := out_shift(6 downto 0) & '1';
                            out_left  := out_left - 1;
                    end case;
                else
                    io_oe <= (others => '0');
                end if;
            end if;
        end if;

        dbg_phase  <= phase;
        dbg_opcode <= opcode;
    end process;

    -- Backdoor access to the memory array for preload and readback
    msg_handler : process is

        variable self        : actor_t;
        variable msg_type    : msg_type_t;
        variable request_msg : msg_t;
        variable reply_msg   : msg_t;
        variable addr        : natural;
        variable len         : natural;
        variable data        : std_logic_vector(7 downto 0);

    begin
        self := new_actor(actor_name);

        loop
            receive(net, self, request_msg);
            msg_type  := message_type(request_msg);
            reply_msg := new_msg;

            if msg_type = flash_fill_pattern_msg then
                mem.fill_pattern;
            elsif msg_type = flash_write_byte_msg then
                addr := pop(request_msg);
                data := pop(request_msg);
                -- Backdoor writes are absolute, not and-ed like a real program
                mem.erase(addr, 1);
                mem.set(addr, data);
            elsif msg_type = flash_read_byte_msg then
                addr := pop(request_msg);
                push(reply_msg, mem.get(addr));
            elsif msg_type = flash_erase_msg then
                addr := pop(request_msg);
                len  := pop(request_msg);
                mem.erase(addr, len);
            elsif msg_type = flash_set_clqv_msg then
                len  := pop(request_msg);
                clqv <= len * 1 ps;
                info(vc_logger, "tCLQV set to " & to_string(len * 1 ps));
            else
                unexpected_msg_type(msg_type);
            end if;

            reply(net, request_msg, reply_msg);
        end loop;
    end process;

end model;
