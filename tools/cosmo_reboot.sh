#!/bin/bash

# Script to poke a 32-bit value to a specific address using humility hiffy
humility hiffy -c FmcDemo.poke32 -a addr=0xc0000628,value=0x04030201

# Loop to test memory detection after reboot
iteration=1
while true; do
    echo "=== Iteration $iteration ==="

    # Set sequencer to A0 state
    echo "Setting sequencer to A0 state..."
    humility hiffy -c Sequencer.set_state -a state=A0

    # Poll until system is booted (wait for magic value at 0xc0008020)
    echo "Polling for boot completion..."
    poll_count=0
    max_polls=500
    while true; do
        peek_output=$(humility hiffy -c FmcDemo.peek32 -a addr=0xc0008020 2>&1)
        # Extract just the line with peek32() in it
        peek_line=$(echo "$peek_output" | grep "peek32()")
        # Print output on same line with carriage return
        echo -ne "\r$peek_line (poll $poll_count/$max_polls)"
        if echo "$peek_output" | grep -qE "0xee010218|0xee010216"; then
            echo -e "\nBoot detected (boot code found)"
            break
        fi
        ((poll_count++))
        if [ "$poll_count" -ge "$max_polls" ]; then
            echo -e "\nERROR: Boot timeout after $max_polls polling attempts ($(($max_polls * 2)) seconds)"
            exit 1
        fi
        sleep 2
    done

    # Check installed memory
    echo "Checking installed memory..."
    memory_output=$(ssh cosmo-w prtconf | grep -i memory)
    echo "$memory_output"

    # Extract memory value (looking for pattern like "192512 Megabytes")
    memory_mb=$(echo "$memory_output" | grep -oP '\d+(?= Megabytes)')

    if [ -n "$memory_mb" ]; then
        # Convert to GB for comparison (192GB = ~192000-193000 MB)
        if [ "$memory_mb" -gt 190000 ] && [ "$memory_mb" -lt 195000 ]; then
            echo "Memory detected correctly: ${memory_mb}MB (close to 192GB)"
            echo "Rebooting and trying again..."
            humility hiffy -c Sequencer.set_state -a state=A2
            sleep 1
            ((iteration++))
            continue
        else
            echo "FAILURE: Incorrect memory detected: ${memory_mb}MB"
            echo "Results after $iteration iteration(s):"
            echo "$memory_output"
            exit 1
        fi
    else
        echo "ERROR: Could not parse memory output"
        echo "Raw output: $memory_output"
        exit 1
    fi
done
