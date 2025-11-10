
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
        poll_for_nic_state(net, NIC_RESET);

    
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

        -- Re-enable power-good for cleanup
        nic_model_msg_pkg.enable_power_good(net => net, actor => nic_actor, rail_name => rail_name);

        info("NIC MAPO fault injection test completed successfully for rail: " & rail_name);
    end procedure;

end package body;