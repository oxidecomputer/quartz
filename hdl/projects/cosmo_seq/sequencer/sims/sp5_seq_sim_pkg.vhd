
-- This package contains types and helper functions for building testbenches
-- around the espi protocol. Functions and procedures in this block are "generic"
-- in that they can be used for testing the espi block by either the qspi VC or
-- via the in-band registers and FIFO interface.
-- These pieces are used to build the payload shifted over the espi VC or out
-- the debug FIFOs.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.numeric_std_unsigned.all;

library vunit_lib;
    context vunit_lib.vunit_context;
    context vunit_lib.com_context;
    context vunit_lib.vc_context;

use work.sequencer_regs_pkg.all;
use work.rail_model_msg_pkg.all;
use work.nic_model_msg_pkg;

package sp5_seq_sim_pkg is

    -- AXI-Lite bus handle for the axi master in the testbench
    constant bus_handle : bus_master_t := new_bus(data_length => 32,
    address_length => 8);

    -- Poll for a specific sequencer state
    procedure poll_for_seq_state (
        signal net           : inout network_t;
        constant target_state : in    seq_api_status_a0_sm;
        constant poll_interval : in    time := 10 us
    );
    -- Poll for a specific nic seq state
    procedure poll_for_nic_state (
        signal net           : inout network_t;
        constant target_state : in    nic_api_status_nic_sm;
        constant poll_interval : in    time := 10 us
    );

    -- Run a complete MAPO fault injection test for a specific rail
    procedure test_mapo_fault_injection (
        signal net           : inout network_t;
        constant rail_actor  : in    actor_t;
        constant rail_name   : in    string
    );

    -- Run a complete NIC MAPO fault injection test for a specific rail
    procedure test_nic_rail_mapo_fault_injection (
        signal net           : inout network_t;
        constant nic_actor   : in    actor_t;
        constant rail_name   : in    string
    );

    -- Bring the board to A0 and the NIC all the way to DONE.
    procedure power_up_to_nic_done (
        signal net : inout network_t
    );

    -- debug_enables.a0hp_inhibit, for either kind of NIC. Each of these is a
    -- whole test case.
    procedure test_a0hp_inhibit_holds_nic_off (
        signal net : inout network_t
    );
    procedure test_a0hp_inhibit_powers_nic_down (
        signal net : inout network_t
    );
    procedure test_a0hp_inhibit_masks_perst_restart (
        signal net : inout network_t;
        signal sp5_perst_l : out std_logic
    );

    -- Drop one Versal rail (a rail_model of its own, unlike the T6's rails
    -- which sit behind nic_model) once the Versal is up and check the NIC
    -- MAPO path, including that the flag can be cleared afterwards.
    procedure test_versal_rail_mapo_fault_injection (
        signal net          : inout network_t;
        constant rail_actor : in    actor_t;
        constant rail_name  : in    string
    );

    -- debug_enables.ignore_sp5 turns MAPOs off for power testing: the fault is
    -- recorded in mapo_suppressed, but nothing powers down and no MAPO
    -- interrupt is raised (hubris would act on one). These run a whole test
    -- case each, for either kind of NIC.
    procedure check_states (
        signal net : inout network_t;
        constant seq_expected : in seq_api_status_a0_sm;
        constant nic_expected : in nic_api_status_nic_sm;
        constant msg : in string
    );
    procedure set_ignore_sp5 (
        signal net : inout network_t;
        constant ignore : in boolean
    );
    -- Everything still up and enabled as it was before the fault, no MAPO
    -- interrupt, and mapo_suppressed showing what would have MAPO'd.
    procedure check_stayed_up (
        signal net : inout network_t;
        constant enables_before : in std_logic_vector(31 downto 0);
        constant a0_suppressed : in std_logic;
        constant nic_suppressed : in std_logic;
        constant msg : in string
    );
    -- Drop a rail that has a rail_model of its own (an A0 rail, or a Versal
    -- rail) with ignore_sp5 set, then bring it back and clear the record.
    procedure test_ignore_sp5_rail_fault (
        signal net : inout network_t;
        constant rail_actor : in actor_t;
        constant rail_name : in string;
        constant is_nic_rail : in boolean
    );
    -- The same for a T6 rail, which sits behind nic_model
    procedure test_ignore_sp5_t6_rail_fault (
        signal net : inout network_t;
        constant nic_actor : in actor_t;
        constant rail_name : in string
    );
    -- Losing the fans' hotswaps, A0's upstream
    procedure test_ignore_sp5_upstream_loss (
        signal net : inout network_t
    );
    -- nic_test_mapo is suppressed too
    procedure test_ignore_sp5_test_mapo (
        signal net : inout network_t
    );
    -- Clearing ignore_sp5 with the fault still there MAPOs straight away
    procedure test_ignore_sp5_cleared_mid_fault (
        signal net : inout network_t;
        constant rail_actor : in actor_t
    );

end package;

package body sp5_seq_sim_pkg is

    procedure poll_for_seq_state (
        signal net           : inout network_t;
        constant target_state : in    seq_api_status_a0_sm;
        constant poll_interval : in    time := 10 us
    ) is
        variable read_data : std_logic_vector(31 downto 0);
        variable seq_state : seq_api_status_a0_sm;
    begin
        loop
            wait for poll_interval;
            read_bus(net, bus_handle, To_StdLogicVector(SEQ_API_STATUS_OFFSET, bus_handle.p_address_length), read_data);
            seq_state := encode(read_data(7 downto 0));
            exit when seq_state = target_state;
        end loop;
    end procedure;

     procedure poll_for_nic_state (
        signal net           : inout network_t;
        constant target_state : in    nic_api_status_nic_sm;
        constant poll_interval : in    time := 10 us
    ) is
        variable read_data : std_logic_vector(31 downto 0);
        variable nic_state : nic_api_status_nic_sm;
    begin
        loop
            wait for poll_interval;
            read_bus(net, bus_handle, To_StdLogicVector(NIC_API_STATUS_OFFSET, bus_handle.p_address_length), read_data);
            nic_state := encode(read_data(7 downto 0));
            exit when nic_state = target_state;
        end loop;
    end procedure;

    procedure test_mapo_fault_injection (
        signal net           : inout network_t;
        constant rail_actor  : in    actor_t;
        constant rail_name   : in    string
    ) is
        variable read_data : std_logic_vector(31 downto 0);
        variable seq_state : seq_api_status_a0_sm;
    begin
        -- Start normal power up sequence
        info("Starting normal A0 power sequence");
        write_bus(net, bus_handle, To_StdLogicVector(POWER_CTRL_OFFSET, bus_handle.p_address_length), POWER_CTRL_A0_EN_MASK);

        -- Poll for sequence to complete (wait for DONE state)
        poll_for_seq_state(net, DONE);

        -- Verify we're in DONE state
        read_bus(net, bus_handle, To_StdLogicVector(SEQ_API_STATUS_OFFSET, bus_handle.p_address_length), read_data);
        seq_state := encode(read_data(7 downto 0));
        info("A0 state after power up: " & to_hstring(read_data(7 downto 0)));
        check_equal(seq_state = DONE, true, "Expected sequencer to be in DONE state");

        -- Inject fault by disabling power-good on the specified rail
        info("Injecting fault on " & rail_name & " rail");
        disable_power_good(net, rail_actor);

        -- Wait for fault detection
        wait for 100 us;

        -- Check IFR register for A0MAPO bit
        read_bus(net, bus_handle, To_StdLogicVector(IFR_OFFSET, bus_handle.p_address_length), read_data);
        info("IFR register after fault: " & to_hstring(read_data));
        check_equal((read_data and IFR_A0MAPO_MASK) /= x"00000000", true, "Expected A0MAPO bit to be set in IFR");

        -- Check that sequencer returned to IDLE state
        read_bus(net, bus_handle, To_StdLogicVector(SEQ_API_STATUS_OFFSET, bus_handle.p_address_length), read_data);
        seq_state := encode(read_data(7 downto 0));
        info("A0 state after MAPO: " & to_hstring(read_data(7 downto 0)));
        check_equal(seq_state = IDLE, true, "Expected sequencer to return to IDLE state after MAPO");

        -- Re-enable power-good for cleanup
        enable_power_good(net, rail_actor);

        info("MAPO fault injection test completed successfully for " & rail_name);
    end procedure;


    procedure test_nic_rail_mapo_fault_injection (
        signal net           : inout network_t;
        constant nic_actor   : in    actor_t;
        constant rail_name   : in    string
    ) is
        variable read_data : std_logic_vector(31 downto 0);
        variable seq_state : seq_api_status_a0_sm;
        variable nic_state : nic_api_status_nic_sm;
    begin
        -- Start normal power up sequence
        info("Starting normal A0 power sequence");
        write_bus(net, bus_handle, To_StdLogicVector(POWER_CTRL_OFFSET, bus_handle.p_address_length), POWER_CTRL_A0_EN_MASK);

        -- Poll for A0 sequence to complete (wait for DONE state)
        poll_for_seq_state(net, DONE);

        -- Verify we're in A0 DONE state
        read_bus(net, bus_handle, To_StdLogicVector(SEQ_API_STATUS_OFFSET, bus_handle.p_address_length), read_data);
        seq_state := encode(read_data(7 downto 0));
        info("A0 state after power up: " & to_hstring(read_data(7 downto 0)));
        check_equal(seq_state = DONE, true, "Expected A0 sequencer to be in DONE state");

        -- Wait for NIC to power up and enable fault monitoring
        info("Waiting for NIC to be fully monitored");
        -- Poll for A0 sequence to complete (wait for DONE state)
        poll_for_nic_state(net, DONE);

    
        read_bus(net, bus_handle, To_StdLogicVector(NIC_API_STATUS_OFFSET, bus_handle.p_address_length), read_data);
        info("NIC state: " & to_hstring(read_data(7 downto 0)));

        -- Inject fault by disabling specific NIC rail
        info("Injecting NIC fault on rail: " & rail_name);
        nic_model_msg_pkg.disable_power_good(net => net, actor => nic_actor, rail_name => rail_name);

        -- Wait for fault detection
        wait for 100 us;

        -- Check IFR register for NICMAPO bit
        read_bus(net, bus_handle, To_StdLogicVector(IFR_OFFSET, bus_handle.p_address_length), read_data);
        info("IFR register after NIC fault on " & rail_name & ": " & to_hstring(read_data));
        check_equal((read_data and IFR_NICMAPO_MASK) /= x"00000000", true,
                    "Expected NICMAPO bit to be set in IFR for rail: " & rail_name);

        -- Check that nic sequencer returned to IDLE state
        read_bus(net, bus_handle, To_StdLogicVector(NIC_API_STATUS_OFFSET, bus_handle.p_address_length), read_data);
        nic_state := encode(read_data(7 downto 0));
        info("NIC state after NIC MAPO on " & rail_name & ": " & to_hstring(read_data(7 downto 0)));
        check_equal(nic_state = IDLE, true, "Expected nic sequencer to return to IDLE state after NIC MAPO on " & rail_name);

        -- Check that IRF register for NICMAPO can clear
        info("Clear NICMAPO bit in IFR");
        write_bus(net, bus_handle, To_StdLogicVector(IFR_OFFSET, bus_handle.p_address_length), IFR_NICMAPO_MASK);  -- writing a 1 to the bit should clear it
        
        read_bus(net, bus_handle, To_StdLogicVector(IFR_OFFSET, bus_handle.p_address_length), read_data);
        info("IFR register after NIC fault cleared " & rail_name & ": " & to_hstring(read_data));
        check_equal((read_data and IFR_NICMAPO_MASK) = x"00000000", true,
                    "Expected NICMAPO bit to be clear after clearing IFR. testing rail: " & rail_name);
        
        -- Re-enable power-good for cleanup
        nic_model_msg_pkg.enable_power_good(net => net, actor => nic_actor, rail_name => rail_name);

        

        info("NIC MAPO fault injection test completed successfully for rail: " & rail_name);
    end procedure;

    procedure power_up_to_nic_done (
        signal net : inout network_t
    ) is
        variable read_data : std_logic_vector(31 downto 0);
        variable seq_state : seq_api_status_a0_sm;
        variable nic_state : nic_api_status_nic_sm;
    begin
        write_bus(net, bus_handle,
                  To_StdLogicVector(POWER_CTRL_OFFSET, bus_handle.p_address_length),
                  POWER_CTRL_A0_EN_MASK);
        poll_for_seq_state(net, DONE);
        read_bus(net, bus_handle,
                 To_StdLogicVector(SEQ_API_STATUS_OFFSET, bus_handle.p_address_length),
                 read_data);
        seq_state := encode(read_data(7 downto 0));
        check_equal(seq_state = DONE, true, "Expected A0 sequencer to be in DONE state");

        poll_for_nic_state(net, DONE);
        read_bus(net, bus_handle,
                 To_StdLogicVector(NIC_API_STATUS_OFFSET, bus_handle.p_address_length),
                 read_data);
        nic_state := encode(read_data(7 downto 0));
        check_equal(nic_state = DONE, true, "Expected NIC sequencer to be in DONE state");
    end procedure;

    procedure set_a0hp_inhibit (
        signal net : inout network_t;
        constant inhibit : in boolean
    ) is
        variable wdata : std_logic_vector(31 downto 0) := (others => '0');
    begin
        if inhibit then
            wdata := DEBUG_ENABLES_A0HP_INHIBIT_MASK;
        end if;
        write_bus(net, bus_handle,
                  To_StdLogicVector(DEBUG_ENABLES_OFFSET, bus_handle.p_address_length),
                  wdata);
    end procedure;

    procedure check_states (
        signal net : inout network_t;
        constant seq_expected : in seq_api_status_a0_sm;
        constant nic_expected : in nic_api_status_nic_sm;
        constant msg : in string
    ) is
        variable read_data : std_logic_vector(31 downto 0);
        variable seq_state : seq_api_status_a0_sm;
        variable nic_state : nic_api_status_nic_sm;
    begin
        read_bus(net, bus_handle,
                 To_StdLogicVector(SEQ_API_STATUS_OFFSET, bus_handle.p_address_length),
                 read_data);
        seq_state := encode(read_data(7 downto 0));
        check_equal(seq_state = seq_expected, true, "A0 sequencer state: " & msg);
        read_bus(net, bus_handle,
                 To_StdLogicVector(NIC_API_STATUS_OFFSET, bus_handle.p_address_length),
                 read_data);
        nic_state := encode(read_data(7 downto 0));
        check_equal(nic_state = nic_expected, true, "NIC sequencer state: " & msg);
    end procedure;

    procedure check_no_nic_mapo (
        signal net : inout network_t;
        constant msg : in string
    ) is
        variable read_data : std_logic_vector(31 downto 0);
    begin
        read_bus(net, bus_handle,
                 To_StdLogicVector(IFR_OFFSET, bus_handle.p_address_length), read_data);
        check_equal((read_data and IFR_NICMAPO_MASK) = x"00000000", true,
                    "Expected no NICMAPO: " & msg);
    end procedure;

    procedure test_a0hp_inhibit_holds_nic_off (
        signal net : inout network_t
    ) is
    begin
        set_a0hp_inhibit(net, true);
        write_bus(net, bus_handle,
                  To_StdLogicVector(POWER_CTRL_OFFSET, bus_handle.p_address_length),
                  POWER_CTRL_A0_EN_MASK);
        poll_for_seq_state(net, DONE);
        -- Long enough for either NIC to have come all the way up
        wait for 500 us;
        check_states(net, DONE, IDLE, "A0 up and A0HP held off");
        check_no_nic_mapo(net, "holding A0HP off is not a fault");

        -- Letting go with a0_en still set is what starts A0HP
        set_a0hp_inhibit(net, false);
        poll_for_nic_state(net, DONE);
        check_states(net, DONE, DONE, "A0HP up once released");
    end procedure;

    procedure test_a0hp_inhibit_powers_nic_down (
        signal net : inout network_t
    ) is
    begin
        power_up_to_nic_done(net);
        set_a0hp_inhibit(net, true);
        poll_for_nic_state(net, IDLE);
        wait for 100 us;
        check_states(net, DONE, IDLE, "A0 stays up when A0HP is taken down");
        check_no_nic_mapo(net, "taking A0HP down is not a fault");
    end procedure;

    procedure test_a0hp_inhibit_masks_perst_restart (
        signal net : inout network_t;
        signal sp5_perst_l : out std_logic
    ) is
    begin
        power_up_to_nic_done(net);
        write_bus(net, bus_handle,
                  To_StdLogicVector(NIC_OVERRIDES_OFFSET, bus_handle.p_address_length),
                  NIC_OVERRIDES_NIC_TEST_MAPO_MASK);
        poll_for_nic_state(net, IDLE);

        -- Faulted, and the SP5 asks for the slot again: held off
        set_a0hp_inhibit(net, true);
        wait for 10 us;
        sp5_perst_l <= '0';
        wait for 10 us;
        sp5_perst_l <= '1';
        wait for 500 us;
        check_states(net, DONE, IDLE, "PERST restart masked by the inhibit");

        -- Letting go with a0_en still set is an enable of its own, so the
        -- NIC comes back without the SP5 having to ask again.
        set_a0hp_inhibit(net, false);
        poll_for_nic_state(net, DONE);
        check_states(net, DONE, DONE, "A0HP back up once released");
    end procedure;

    procedure test_versal_rail_mapo_fault_injection (
        signal net          : inout network_t;
        constant rail_actor : in    actor_t;
        constant rail_name  : in    string
    ) is
        variable read_data : std_logic_vector(31 downto 0);
        variable nic_state : nic_api_status_nic_sm;
    begin
        power_up_to_nic_done(net);

        info("Injecting Versal fault on rail: " & rail_name);
        disable_power_good(net, rail_actor);
        wait for 100 us;

        read_bus(net, bus_handle,
                 To_StdLogicVector(IFR_OFFSET, bus_handle.p_address_length), read_data);
        check_equal((read_data and IFR_NICMAPO_MASK) /= x"00000000", true,
                    "Expected NICMAPO bit to be set in IFR for rail: " & rail_name);

        read_bus(net, bus_handle,
                 To_StdLogicVector(NIC_API_STATUS_OFFSET, bus_handle.p_address_length),
                 read_data);
        nic_state := encode(read_data(7 downto 0));
        check_equal(nic_state = IDLE, true,
                    "Expected NIC sequencer to return to IDLE after MAPO on " & rail_name);

        info("Clearing NICMAPO bit in IFR");
        write_bus(net, bus_handle,
                  To_StdLogicVector(IFR_OFFSET, bus_handle.p_address_length),
                  IFR_NICMAPO_MASK);
        read_bus(net, bus_handle,
                 To_StdLogicVector(IFR_OFFSET, bus_handle.p_address_length), read_data);
        check_equal((read_data and IFR_NICMAPO_MASK) = x"00000000", true,
                    "Expected NICMAPO bit to clear for rail: " & rail_name);

        enable_power_good(net, rail_actor);
    end procedure;

    procedure set_ignore_sp5 (
        signal net : inout network_t;
        constant ignore : in boolean
    ) is
        variable wdata : std_logic_vector(31 downto 0) := (others => '0');
    begin
        if ignore then
            wdata := DEBUG_ENABLES_IGNORE_SP5_MASK;
        end if;
        write_bus(net, bus_handle,
                  To_StdLogicVector(DEBUG_ENABLES_OFFSET, bus_handle.p_address_length),
                  wdata);
    end procedure;

    procedure check_stayed_up (
        signal net : inout network_t;
        constant enables_before : in std_logic_vector(31 downto 0);
        constant a0_suppressed : in std_logic;
        constant nic_suppressed : in std_logic;
        constant msg : in string
    ) is
        variable read_data : std_logic_vector(31 downto 0);
        variable suppressed : mapo_suppressed_type;
    begin
        check_states(net, DONE, DONE, msg);
        read_bus(net, bus_handle,
                 To_StdLogicVector(RAIL_ENABLES_OFFSET, bus_handle.p_address_length), read_data);
        check_equal(read_data, enables_before, "Expected every rail still enabled: " & msg);
        read_bus(net, bus_handle,
                 To_StdLogicVector(IFR_OFFSET, bus_handle.p_address_length), read_data);
        check_equal((read_data and (IFR_A0MAPO_MASK or IFR_NICMAPO_MASK)) = x"00000000", true,
                    "Expected no MAPO interrupt: " & msg);
        read_bus(net, bus_handle,
                 To_StdLogicVector(MAPO_SUPPRESSED_OFFSET, bus_handle.p_address_length), read_data);
        suppressed := unpack(read_data);
        check_equal(suppressed.a0, a0_suppressed, "mapo_suppressed.a0: " & msg);
        check_equal(suppressed.nic, nic_suppressed, "mapo_suppressed.nic: " & msg);
    end procedure;

    -- Write clears the record, and nothing comes back once the fault has gone
    procedure check_suppressed_clears (
        signal net : inout network_t;
        constant msg : in string
    ) is
        variable read_data : std_logic_vector(31 downto 0);
    begin
        write_bus(net, bus_handle,
                  To_StdLogicVector(MAPO_SUPPRESSED_OFFSET, bus_handle.p_address_length),
                  x"00000000");
        wait for 10 us;
        read_bus(net, bus_handle,
                 To_StdLogicVector(MAPO_SUPPRESSED_OFFSET, bus_handle.p_address_length), read_data);
        check_equal(read_data, std_logic_vector'(x"00000000"), "Expected mapo_suppressed cleared: " & msg);
    end procedure;

    -- Up to DONE with ignore_sp5 set, returning the rail enables as they stand
    procedure power_up_ignoring_sp5 (
        signal net : inout network_t;
        variable enables : out std_logic_vector(31 downto 0)
    ) is
    begin
        set_ignore_sp5(net, true);
        power_up_to_nic_done(net);
        read_bus(net, bus_handle,
                 To_StdLogicVector(RAIL_ENABLES_OFFSET, bus_handle.p_address_length), enables);
    end procedure;

    procedure test_ignore_sp5_rail_fault (
        signal net : inout network_t;
        constant rail_actor : in actor_t;
        constant rail_name : in string;
        constant is_nic_rail : in boolean
    ) is
        variable enables : std_logic_vector(31 downto 0);
        variable a0_bit : std_logic := '1';
        variable nic_bit : std_logic := '0';
    begin
        if is_nic_rail then
            a0_bit := '0';
            nic_bit := '1';
        end if;
        power_up_ignoring_sp5(net, enables);
        info("Dropping " & rail_name & " with ignore_sp5 set");
        disable_power_good(net, rail_actor);
        wait for 100 us;
        check_stayed_up(net, enables, a0_bit, nic_bit, rail_name & " out");
        enable_power_good(net, rail_actor);
        wait for 100 us;
        check_stayed_up(net, enables, a0_bit, nic_bit, rail_name & " back");
        check_suppressed_clears(net, rail_name);
    end procedure;

    procedure test_ignore_sp5_t6_rail_fault (
        signal net : inout network_t;
        constant nic_actor : in actor_t;
        constant rail_name : in string
    ) is
        variable enables : std_logic_vector(31 downto 0);
    begin
        power_up_ignoring_sp5(net, enables);
        info("Dropping " & rail_name & " with ignore_sp5 set");
        nic_model_msg_pkg.disable_power_good(net => net, actor => nic_actor, rail_name => rail_name);
        wait for 100 us;
        check_stayed_up(net, enables, '0', '1', rail_name & " out");
        nic_model_msg_pkg.enable_power_good(net => net, actor => nic_actor, rail_name => rail_name);
        wait for 100 us;
        check_stayed_up(net, enables, '0', '1', rail_name & " back");
        check_suppressed_clears(net, rail_name);
    end procedure;

    procedure test_ignore_sp5_upstream_loss (
        signal net : inout network_t
    ) is
        variable enables : std_logic_vector(31 downto 0);
    begin
        power_up_ignoring_sp5(net, enables);
        info("Masking the east fan hotswap's power good with ignore_sp5 set");
        write_bus(net, bus_handle,
                  To_StdLogicVector(SP5_SEQ_TEST_MASK_OFFSET, bus_handle.p_address_length),
                  SP5_SEQ_TEST_MASK_FAN_HSC_EAST_PG_MASK);
        wait for 100 us;
        -- A0 never leaving DONE keeps the NIC's upstream good, so only A0
        -- would have MAPO'd
        check_stayed_up(net, enables, '1', '0', "fan hotswap out");
        write_bus(net, bus_handle,
                  To_StdLogicVector(SP5_SEQ_TEST_MASK_OFFSET, bus_handle.p_address_length),
                  x"00000000");
        wait for 100 us;
        check_suppressed_clears(net, "fan hotswap");
    end procedure;

    procedure test_ignore_sp5_test_mapo (
        signal net : inout network_t
    ) is
        variable enables : std_logic_vector(31 downto 0);
    begin
        power_up_ignoring_sp5(net, enables);
        write_bus(net, bus_handle,
                  To_StdLogicVector(NIC_OVERRIDES_OFFSET, bus_handle.p_address_length),
                  NIC_OVERRIDES_NIC_TEST_MAPO_MASK);
        wait for 100 us;
        check_stayed_up(net, enables, '0', '1', "nic_test_mapo");
        check_suppressed_clears(net, "nic_test_mapo");
    end procedure;

    procedure test_ignore_sp5_cleared_mid_fault (
        signal net : inout network_t;
        constant rail_actor : in actor_t
    ) is
        variable enables : std_logic_vector(31 downto 0);
        variable read_data : std_logic_vector(31 downto 0);
    begin
        power_up_ignoring_sp5(net, enables);
        disable_power_good(net, rail_actor);
        wait for 100 us;
        check_stayed_up(net, enables, '1', '0', "rail out, ignore_sp5 set");

        set_ignore_sp5(net, false);
        wait for 100 us;
        read_bus(net, bus_handle,
                 To_StdLogicVector(IFR_OFFSET, bus_handle.p_address_length), read_data);
        check_equal((read_data and IFR_A0MAPO_MASK) /= x"00000000", true,
                    "Expected an A0MAPO once ignore_sp5 is cleared");
        check_states(net, IDLE, IDLE, "after clearing ignore_sp5 mid-fault");
        enable_power_good(net, rail_actor);
    end procedure;

end package body;