#!/bin/bash
# BSV Build System Performance Benchmark
# Compares cobble vs Buck2 build times for BSV projects
#
# Usage: ./tools/bsv_benchmark.sh [target]
# Example: ./tools/bsv_benchmark.sh //hdl/ip/bsv:Countdown

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default target if not specified
TARGET="${1:-//hdl/ip/bsv:Countdown}"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}BSV Build System Performance Benchmark${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo "Target: $TARGET"
echo "Date: $(date)"
echo ""

# Function to run timed command
time_command() {
    local label="$1"
    shift
    echo -e "${YELLOW}Running: $label${NC}" >&2
    START=$(date +%s.%N)
    "$@" > /dev/null 2>&1
    END=$(date +%s.%N)
    ELAPSED=$(echo "$END - $START" | bc)
    echo -e "${GREEN}Time: ${ELAPSED}s${NC}" >&2
    echo "$ELAPSED"
}

# Check if cobble is available
COBBLE_AVAILABLE=false
if [ -d "build" ] && [ -f "build/cobble" ]; then
    COBBLE_AVAILABLE=true
fi

echo -e "${BLUE}=== Buck2 Benchmarks ===${NC}"
echo ""

# Buck2: Clean build
echo -e "${YELLOW}1. Buck2 Clean Build${NC}"
buck2 clean > /dev/null 2>&1
BUCK2_CLEAN=$(time_command "Buck2 clean build" buck2 build "$TARGET")
echo ""

# Buck2: Null build (no changes)
echo -e "${YELLOW}2. Buck2 Null Build (no changes)${NC}"
BUCK2_NULL=$(time_command "Buck2 null build" buck2 build "$TARGET")
echo ""

# Buck2: Incremental build (touch one file)
echo -e "${YELLOW}3. Buck2 Incremental Build (touch one file)${NC}"
# Extract the package path from target
PACKAGE_PATH=$(echo "$TARGET" | sed 's|//||' | sed 's|:.*||')
# Find first .bsv file in the package
BSV_FILE=$(find "$PACKAGE_PATH" -maxdepth 1 -name "*.bsv" | head -1)
if [ -n "$BSV_FILE" ]; then
    touch "$BSV_FILE"
    BUCK2_INCREMENTAL=$(time_command "Buck2 incremental build" buck2 build "$TARGET")
    echo ""
else
    echo "Warning: No .bsv files found for incremental test"
    BUCK2_INCREMENTAL="N/A"
fi

# Cobble benchmarks if available
if [ "$COBBLE_AVAILABLE" = true ]; then
    echo -e "${BLUE}=== Cobble Benchmarks ===${NC}"
    echo ""

    # Cobble: Clean build
    echo -e "${YELLOW}4. Cobble Clean Build${NC}"
    (cd build && ./cobble clean > /dev/null 2>&1)
    COBBLE_CLEAN=$(time_command "Cobble clean build" sh -c "cd build && ./cobble build '$TARGET'")
    echo ""

    # Cobble: Null build
    echo -e "${YELLOW}5. Cobble Null Build (no changes)${NC}"
    COBBLE_NULL=$(time_command "Cobble null build" sh -c "cd build && ./cobble build '$TARGET'")
    echo ""

    # Cobble: Incremental build
    if [ -n "$BSV_FILE" ]; then
        echo -e "${YELLOW}6. Cobble Incremental Build (touch one file)${NC}"
        touch "$BSV_FILE"
        COBBLE_INCREMENTAL=$(time_command "Cobble incremental build" sh -c "cd build && ./cobble build '$TARGET'")
        echo ""
    else
        COBBLE_INCREMENTAL="N/A"
    fi
fi

# Summary
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Summary${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

printf "%-25s %10s %10s %10s\n" "Build Type" "Buck2" "Cobble" "Speedup"
printf "%-25s %10s %10s %10s\n" "----------" "-----" "------" "-------"

if [ "$COBBLE_AVAILABLE" = true ]; then
    # Clean build comparison
    CLEAN_SPEEDUP=$(echo "scale=2; $COBBLE_CLEAN / $BUCK2_CLEAN" | bc)
    printf "%-25s %9.3fs %9.3fs %9.2fx\n" "Clean Build" "$BUCK2_CLEAN" "$COBBLE_CLEAN" "$CLEAN_SPEEDUP"

    # Null build comparison
    NULL_SPEEDUP=$(echo "scale=2; $COBBLE_NULL / $BUCK2_NULL" | bc)
    printf "%-25s %9.3fs %9.3fs %9.2fx\n" "Null Build" "$BUCK2_NULL" "$COBBLE_NULL" "$NULL_SPEEDUP"

    # Incremental build comparison
    if [ "$BUCK2_INCREMENTAL" != "N/A" ] && [ "$COBBLE_INCREMENTAL" != "N/A" ]; then
        INCR_SPEEDUP=$(echo "scale=2; $COBBLE_INCREMENTAL / $BUCK2_INCREMENTAL" | bc)
        printf "%-25s %9.3fs %9.3fs %9.2fx\n" "Incremental Build" "$BUCK2_INCREMENTAL" "$COBBLE_INCREMENTAL" "$INCR_SPEEDUP"
    fi
else
    # Buck2 only
    printf "%-25s %9.3fs %10s %10s\n" "Clean Build" "$BUCK2_CLEAN" "N/A" "N/A"
    printf "%-25s %9.3fs %10s %10s\n" "Null Build" "$BUCK2_NULL" "N/A" "N/A"
    if [ "$BUCK2_INCREMENTAL" != "N/A" ]; then
        printf "%-25s %9.3fs %10s %10s\n" "Incremental Build" "$BUCK2_INCREMENTAL" "N/A" "N/A"
    fi
    echo ""
    echo -e "${YELLOW}Note: Cobble not available (build/ directory not found)${NC}"
fi

echo ""
echo -e "${BLUE}========================================${NC}"

# Interpretation
echo ""
echo -e "${GREEN}Key Findings:${NC}"
if [ "$COBBLE_AVAILABLE" = true ]; then
    echo "- Clean builds should be similar (inherent bsc compilation time)"
    if (( $(echo "$NULL_SPEEDUP > 3" | bc -l) )); then
        echo "- Buck2 null builds are ${NULL_SPEEDUP}x faster (caching working well)"
    fi
    if [ "$BUCK2_INCREMENTAL" != "N/A" ] && [ "$COBBLE_INCREMENTAL" != "N/A" ]; then
        if (( $(echo "$INCR_SPEEDUP > 2" | bc -l) )); then
            echo "- Buck2 incremental builds are ${INCR_SPEEDUP}x faster (smart rebuilds)"
        fi
    fi
else
    echo "- Buck2 null build: ${BUCK2_NULL}s (should be <1s with good caching)"
    if [ "$BUCK2_INCREMENTAL" != "N/A" ]; then
        echo "- Buck2 incremental build: ${BUCK2_INCREMENTAL}s (only changed modules)"
    fi
fi

echo ""
echo -e "${BLUE}Run this benchmark on different targets:${NC}"
echo "  ./tools/bsv_benchmark.sh //hdl/ip/bsv:Countdown"
echo "  ./tools/bsv_benchmark.sh //hdl/ip/bsv/I2C:I2CCore"
echo "  ./tools/bsv_benchmark.sh //hdl/ip/bsv/ignition:Controller"
