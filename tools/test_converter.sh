#!/bin/bash
# Test script for BUILD to BUCK converter
# Demonstrates Phase 4: Automated Conversion Tool

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "======================================"
echo "BUILD to BUCK Converter Test Suite"
echo "======================================"
echo ""

# Test 1: Simple library conversion (MDIO)
echo "Test 1: Converting simple library (MDIO)..."
python3 "$SCRIPT_DIR/build_to_buck_converter.py" \
    "$PROJECT_ROOT/hdl/ip/bsv/MDIO/BUILD" \
    --dry-run > /tmp/mdio_buck_test.txt 2>&1
if grep -q "bsv_library" /tmp/mdio_buck_test.txt && \
   grep -q "bsv_bluesim_tests" /tmp/mdio_buck_test.txt; then
    echo "✓ MDIO conversion successful"
else
    echo "✗ MDIO conversion failed"
    cat /tmp/mdio_buck_test.txt
    exit 1
fi
echo ""

# Test 2: Complex library with RDL (I2C)
echo "Test 2: Converting library with RDL (I2C)..."
python3 "$SCRIPT_DIR/build_to_buck_converter.py" \
    "$PROJECT_ROOT/hdl/ip/bsv/I2C/BUILD" \
    --dry-run > /tmp/i2c_buck_test.txt 2>&1
if grep -q "rdl_file" /tmp/i2c_buck_test.txt && \
   grep -q "I2CCoreRegsPkg" /tmp/i2c_buck_test.txt; then
    echo "✓ I2C RDL conversion successful"
else
    echo "✗ I2C conversion failed"
    cat /tmp/i2c_buck_test.txt
    exit 1
fi
echo ""

# Test 3: Check attribute mappings
echo "Test 3: Verifying attribute mappings..."
if grep -q 'srcs = \[' /tmp/mdio_buck_test.txt && \
   ! grep -q 'sources = \[' /tmp/mdio_buck_test.txt; then
    echo "✓ sources → srcs mapping works"
else
    echo "✗ Attribute mapping failed"
    exit 1
fi

if grep -q 'top = "test/MDIOTests.bsv"' /tmp/mdio_buck_test.txt; then
    echo "✓ suite → top mapping works"
else
    echo "✗ suite → top mapping failed"
    exit 1
fi
echo ""

# Test 4: Check dependency conversion
echo "Test 4: Verifying dependency paths..."
if grep -q '"//hdl/ip/bsv:Bidirection"' /tmp/mdio_buck_test.txt && \
   grep -q '":MDIO"' /tmp/mdio_buck_test.txt; then
    echo "✓ Dependency paths preserved correctly"
else
    echo "✗ Dependency conversion failed"
    exit 1
fi
echo ""

# Test 5: Check load statements
echo "Test 5: Verifying load statements..."
if grep -q 'load("//tools:bsv.bzl", "bsv_library")' /tmp/mdio_buck_test.txt && \
   grep -q 'load("//tools:rdl.bzl", "rdl_file")' /tmp/i2c_buck_test.txt; then
    echo "✓ Load statements generated correctly"
else
    echo "✗ Load statement generation failed"
    exit 1
fi
echo ""

# Summary
echo "======================================"
echo "All converter tests passed! ✓"
echo "======================================"
echo ""
echo "Phase 4 (Automated Conversion Tool) Complete"
echo ""
echo "Sample conversions:"
echo "  - MDIO: $(wc -l < /tmp/mdio_buck_test.txt) lines generated"
echo "  - I2C:  $(wc -l < /tmp/i2c_buck_test.txt) lines generated"
echo ""
echo "To convert a BUILD file:"
echo "  python3 tools/build_to_buck_converter.py <BUILD_file> [--dry-run]"
