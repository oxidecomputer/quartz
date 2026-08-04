-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Message definitions and backing store for the SPI NOR flash target VC.
--
-- The VC models a Winbond W25Q-family QSPI NOR flash closely enough to check
-- both data integrity and the AC timing relationships that bound how fast the
-- controller's sclk can run. The interesting knob for margin testing is
-- set_output_valid_delay(), which walks the modelled tCLQV so a testbench can
-- prove the controller samples correctly across the whole datasheet range
-- rather than just at one nominal value.

library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

library vunit_lib;
    context vunit_lib.vunit_context;
    context vunit_lib.com_context;

package spi_nor_target_vc_pkg is

    -- Size of the modelled memory window. The real part is 1Gbit, which we
    -- have no interest in allocating, so reads outside the window return
    -- erased (0xFF) data and writes outside it are dropped.
    constant flash_window_bytes : natural := 16#10000#;

    -- Deterministic address -> data mapping used by fill_pattern. Multiplying
    -- the low address byte by an odd constant makes this a bijection over any
    -- aligned 256 byte run, so an off-by-one address or a dropped bit always
    -- shows up as a different byte rather than aliasing to the same value.
    function pattern_byte (addr : natural) return std_logic_vector;

    type flash_mem_t is protected

        procedure set (addr : natural; data : std_logic_vector(7 downto 0));
        impure function get (addr : natural) return std_logic_vector;
        procedure erase (addr : natural; len : natural);
        procedure fill_pattern;

    end protected;

    -- Message types
    constant flash_fill_pattern_msg : msg_type_t := new_msg_type("flash_fill_pattern");
    constant flash_write_byte_msg   : msg_type_t := new_msg_type("flash_write_byte");
    constant flash_read_byte_msg    : msg_type_t := new_msg_type("flash_read_byte");
    constant flash_erase_msg        : msg_type_t := new_msg_type("flash_erase");
    constant flash_set_clqv_msg     : msg_type_t := new_msg_type("flash_set_clqv");

    -- Fill the whole modelled window with pattern_byte(addr).
    procedure fill_pattern (
        signal net     : inout network_t;
        constant actor : actor_t
    );

    procedure write_flash_byte (
        signal net     : inout network_t;
        constant actor : actor_t;
        constant addr  : natural;
        constant data  : std_logic_vector(7 downto 0)
    );

    procedure read_flash_byte (
        signal net     : inout network_t;
        constant actor : actor_t;
        constant addr  : natural;
        variable data  : out std_logic_vector(7 downto 0)
    );

    procedure erase_flash (
        signal net     : inout network_t;
        constant actor : actor_t;
        constant addr  : natural;
        constant len   : natural
    );

    -- Override the modelled clock-low-to-output-valid delay (tCLQV). Used to
    -- sweep the controller's rx sample point margin at a fixed sclk rate.
    procedure set_output_valid_delay (
        signal net     : inout network_t;
        constant actor : actor_t;
        constant delay : time
    );

end package;

package body spi_nor_target_vc_pkg is

    function pattern_byte (addr : natural) return std_logic_vector is

        variable a : unsigned(31 downto 0);
        variable v : unsigned(7 downto 0);

    begin
        a := to_unsigned(addr, 32);
        v := resize(a(7 downto 0) * 7, 8) xor
             a(15 downto 8) xor
             resize(a(23 downto 16) * 3, 8) xor
             x"A5";
        return std_logic_vector(v);
    end function;

    type flash_mem_t is protected body

        type mem_arr_t is array (0 to flash_window_bytes - 1) of std_logic_vector(7 downto 0);

        variable mem : mem_arr_t := (others => x"FF");

        procedure set (addr : natural; data : std_logic_vector(7 downto 0)) is
        begin
            if addr < flash_window_bytes then
                -- Real NOR can only clear bits on a program, it cannot set
                -- them. Modelling that catches a missing erase.
                mem(addr) := mem(addr) and data;
            end if;
        end procedure;

        impure function get (addr : natural) return std_logic_vector is
        begin
            if addr < flash_window_bytes then
                return mem(addr);
            else
                return x"FF";
            end if;
        end function;

        procedure erase (addr : natural; len : natural) is
        begin
            for i in addr to addr + len - 1 loop
                if i < flash_window_bytes then
                    mem(i) := x"FF";
                end if;
            end loop;
        end procedure;

        procedure fill_pattern is
        begin
            for i in mem'range loop
                mem(i) := pattern_byte(i);
            end loop;
        end procedure;

    end protected body;

    procedure fill_pattern (
        signal net     : inout network_t;
        constant actor : actor_t
    ) is

        variable request_msg : msg_t := new_msg(flash_fill_pattern_msg);
        variable reply_msg   : msg_t;

    begin
        request(net, actor, request_msg, reply_msg);
        delete(reply_msg);
    end procedure;

    procedure write_flash_byte (
        signal net     : inout network_t;
        constant actor : actor_t;
        constant addr  : natural;
        constant data  : std_logic_vector(7 downto 0)
    ) is

        variable request_msg : msg_t := new_msg(flash_write_byte_msg);
        variable reply_msg   : msg_t;

    begin
        push(request_msg, addr);
        push(request_msg, data);
        request(net, actor, request_msg, reply_msg);
        delete(reply_msg);
    end procedure;

    procedure read_flash_byte (
        signal net     : inout network_t;
        constant actor : actor_t;
        constant addr  : natural;
        variable data  : out std_logic_vector(7 downto 0)
    ) is

        variable request_msg : msg_t := new_msg(flash_read_byte_msg);
        variable reply_msg   : msg_t;

    begin
        push(request_msg, addr);
        request(net, actor, request_msg, reply_msg);
        data := pop(reply_msg);
        delete(reply_msg);
    end procedure;

    procedure erase_flash (
        signal net     : inout network_t;
        constant actor : actor_t;
        constant addr  : natural;
        constant len   : natural
    ) is

        variable request_msg : msg_t := new_msg(flash_erase_msg);
        variable reply_msg   : msg_t;

    begin
        push(request_msg, addr);
        push(request_msg, len);
        request(net, actor, request_msg, reply_msg);
        delete(reply_msg);
    end procedure;

    procedure set_output_valid_delay (
        signal net     : inout network_t;
        constant actor : actor_t;
        constant delay : time
    ) is

        variable request_msg : msg_t := new_msg(flash_set_clqv_msg);
        variable reply_msg   : msg_t;

    begin
        -- Passed as an integer count of ps rather than a time so we don't
        -- depend on queue_pkg's time overloads being present.
        push(request_msg, delay / 1 ps);
        request(net, actor, request_msg, reply_msg);
        delete(reply_msg);
    end procedure;

end package body;
