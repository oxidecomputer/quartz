-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.numeric_std_unsigned.all;

library vunit_lib;
    context vunit_lib.vunit_context;
    context vunit_lib.com_context;
    context vunit_lib.vc_context;
use work.spi_nor_regs_pkg.all;
use work.spi_nor_pkg.all;
use work.spi_nor_target_vc_pkg.all;

package spi_nor_tb_pkg is

    constant bus_handle : bus_master_t := new_bus(data_length => 32,
                                                  address_length => 26);

    procedure write_instr (
        signal net : inout network_t;
        data       : std_logic_vector
    );

    procedure write_dummy (
        signal net : inout network_t;
        data       : integer
    );

    procedure write_addr (
        signal net : inout network_t;
        data       : std_logic_vector
    );

    procedure write_data (
        signal net : inout network_t;
        data       : std_logic_vector
    );

    procedure write_data_size (
        signal net : inout network_t;
        data       : integer
    );

    procedure clear_fifos (
        signal net : inout network_t
    );

    -- Wait for a transaction to start and then finish. Polling only for "not
    -- busy" races the start of the transaction: writing Instr queues the go
    -- strobe, and a register read issued straight afterwards can easily land
    -- before cs_n has fallen.
    procedure wait_txn_done (
        signal net : inout network_t
    );

    procedure read_rx_word (
        signal net   : inout network_t;
        variable data : out std_logic_vector(31 downto 0)
    );

    -- Pop count bytes out of the RX FIFO and check them against the pattern the
    -- flash model was preloaded with. This is what makes the rx sample point
    -- observable: a sample taken outside the part's valid window shifts in 'X'
    -- or a neighbouring bit, and lands here as a mismatch.
    procedure check_read_pattern (
        signal net      : inout network_t;
        constant addr   : natural;
        constant count  : natural
    );

    -- Checked scenarios, shared by the testbenches so the same coverage can be
    -- run at more than one sclk rate without duplicating it.

    procedure check_jedec_id (
        signal net : inout network_t
    );

    -- opcode picks single / dual / quad and 3 or 4 byte addressing; dummies must
    -- match what the part expects for that opcode.
    procedure check_flash_read (
        signal net       : inout network_t;
        constant opcode  : std_logic_vector(7 downto 0);
        constant dummies : natural;
        constant addr    : natural;
        constant count   : natural
    );

    procedure check_program_readback (
        signal net       : inout network_t;
        constant flash   : actor_t;
        constant addr    : natural
    );

    -- Two reads issued with no software delay between them, which is what the
    -- eSPI reader does when it chains page reads.
    procedure check_back_to_back_reads (
        signal net      : inout network_t;
        constant addr_a : natural;
        constant addr_b : natural;
        constant count  : natural
    );

end package;

package body spi_nor_tb_pkg is

    procedure write_instr (
        signal net : inout network_t;
        data       : std_logic_vector
    ) is
    begin
        write_bus(net, bus_handle, To_StdLogicVector(INSTR_OFFSET + 16#100#, bus_handle.p_address_length), resize(data, 32));
    end;

    procedure write_addr (
        signal net : inout network_t;
        data       : std_logic_vector
    ) is
    begin
        write_bus(net, bus_handle, To_StdLogicVector(ADDR_OFFSET + 16#100#, bus_handle.p_address_length), resize(data, 32));
    end;

    procedure write_dummy (
        signal net : inout network_t;
        data       : integer
    ) is
    begin
        write_bus(net, bus_handle, To_StdLogicVector(DUMMYCYCLES_OFFSET + 16#100#, bus_handle.p_address_length), To_StdLogicVector(data, 32));
    end;

    procedure write_data_size (
        signal net : inout network_t;
        data       : integer
    ) is
    begin
        write_bus(net, bus_handle, To_StdLogicVector(DATABYTES_OFFSET + 16#100#, bus_handle.p_address_length), To_StdLogicVector(data, 32));
    end;

    procedure write_data (
        signal net : inout network_t;
        data       : std_logic_vector
    ) is
    begin
        write_bus(net, bus_handle, To_StdLogicVector(TX_FIFO_WDATA_OFFSET + 16#100#, bus_handle.p_address_length), resize(data, 32));
    end;

    procedure clear_fifos (
        signal net : inout network_t
    ) is
    begin
        write_bus(net, bus_handle, To_StdLogicVector(SPICR_OFFSET + 16#100#, bus_handle.p_address_length),
                  SPICR_RX_FIFO_RESET_MASK or SPICR_TX_FIFO_RESET_MASK);

        -- The self-clearing reset bits produce a single-cycle pulse into the XPM
        -- dual-clock FIFOs, which want their reset held longer than that and are
        -- unusable for a number of cycles afterwards. Software gets away with it
        -- because consecutive register accesses are far apart; a testbench
        -- issuing back-to-back writes does not, and the FIFO data is dropped.
        wait for 1 us;
    end;

    procedure wait_txn_done (
        signal net : inout network_t
    ) is

        variable status  : std_logic_vector(31 downto 0);
        variable started : boolean := false;

    begin
        -- Wait for cs_n to fall. A register read takes several clocks and cs_n
        -- asserts a handful of clocks after the go strobe, so this always
        -- catches even the shortest transaction.
        for i in 0 to 63 loop
            read_bus(net, bus_handle, To_StdLogicVector(SPISR_OFFSET + 16#100#, bus_handle.p_address_length), status);
            if (status and SPISR_BUSY_MASK) /= (status'range => '0') then
                started := true;
                exit;
            end if;
        end loop;

        check_true(started, "transaction never became busy");

        loop
            read_bus(net, bus_handle, To_StdLogicVector(SPISR_OFFSET + 16#100#, bus_handle.p_address_length), status);
            exit when (status and SPISR_BUSY_MASK) = (status'range => '0');
        end loop;
    end;

    procedure read_rx_word (
        signal net   : inout network_t;
        variable data : out std_logic_vector(31 downto 0)
    ) is

        variable status : std_logic_vector(31 downto 0);

    begin
        -- The RX FIFO is a dual-clock FIFO and the last partial word is only
        -- pushed when cs_n rises, so a word can still be in flight when busy
        -- clears. Wait for it to show up rather than reading a stale register.
        loop
            read_bus(net, bus_handle, To_StdLogicVector(SPISR_OFFSET + 16#100#, bus_handle.p_address_length), status);
            exit when (status and SPISR_RX_EMPTY_MASK) = (status'range => '0');
        end loop;

        read_bus(net, bus_handle, To_StdLogicVector(RX_FIFO_RDATA_OFFSET + 16#100#, bus_handle.p_address_length), data);
    end;

    procedure check_read_pattern (
        signal net      : inout network_t;
        constant addr   : natural;
        constant count  : natural
    ) is

        variable word : std_logic_vector(31 downto 0);
        variable got  : std_logic_vector(7 downto 0);

    begin
        for i in 0 to count - 1 loop
            -- The width adaptor packs bytes little-endian into each word, so a
            -- fresh word is popped every fourth byte.
            if i mod 4 = 0 then
                read_rx_word(net, word);
            end if;

            got := word(8 * (i mod 4) + 7 downto 8 * (i mod 4));
            check_equal(got, pattern_byte(addr + i),
                        "flash read data mismatch at offset " & to_string(i) &
                        " (flash address " & to_string(addr + i) & ")");
        end loop;
    end;

    procedure check_jedec_id (
        signal net : inout network_t
    ) is

        variable word : std_logic_vector(31 downto 0);

    begin
        clear_fifos(net);
        write_data_size(net, 3);
        write_dummy(net, 0);
        write_instr(net, READ_JEDEC_ID_OP);
        wait_txn_done(net);
        read_rx_word(net, word);
        -- Winbond mfr id, W25Q01JV device id, lsb-packed by the width adaptor
        check_equal(word(23 downto 0), std_logic_vector'(x"2140EF"),
                    "unexpected JEDEC id");
    end;

    procedure check_flash_read (
        signal net       : inout network_t;
        constant opcode  : std_logic_vector(7 downto 0);
        constant dummies : natural;
        constant addr    : natural;
        constant count   : natural
    ) is
    begin
        clear_fifos(net);
        write_dummy(net, dummies);
        write_data_size(net, count);
        write_addr(net, To_StdLogicVector(addr, 32));
        write_instr(net, opcode);
        wait_txn_done(net);
        check_read_pattern(net, addr, count);
    end;

    procedure check_program_readback (
        signal net       : inout network_t;
        constant flash   : actor_t;
        constant addr    : natural
    ) is

        variable got : std_logic_vector(7 downto 0);

    begin
        clear_fifos(net);
        -- NOR can only clear bits, so start from erased
        erase_flash(net, flash, addr, 16#1000#);
        write_data(net, x"03020100");
        write_data(net, x"07060504");
        write_dummy(net, 0);
        write_data_size(net, 8);
        write_addr(net, To_StdLogicVector(addr, 32));
        write_instr(net, PAGE_PROGRAM_4BYTE_OP);
        wait_txn_done(net);

        for i in 0 to 7 loop
            read_flash_byte(net, flash, addr + i, got);
            check_equal(got, std_logic_vector(to_unsigned(i, 8)),
                        "programmed byte mismatch at offset " & to_string(i));
        end loop;
    end;

    procedure check_back_to_back_reads (
        signal net      : inout network_t;
        constant addr_a : natural;
        constant addr_b : natural;
        constant count  : natural
    ) is
    begin
        check_flash_read(net, FAST_READ_4BYTE_QUAD_OP, 8, addr_a, count);
        -- No delay here on purpose: the flash needs a minimum cs_n high time
        -- and the model enforces it.
        check_flash_read(net, FAST_READ_4BYTE_QUAD_OP, 8, addr_b, count);
    end;

end package body;
