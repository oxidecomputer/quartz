import pytest

def test_oxide_reg(target):
    """Test the base FPGA register reports 0x1de as expected"""
    a = target.read32(0x60000000)
    print(f"0x0: {a:#x}")
    assert a == 0x1de


def test_scratch_pad(target):
    """Read-write scribble test in scratchpad register"""
    addr = 0x60000008
    expected = 0x0
    target.write32(addr, expected)
    a = target.read32(addr)
    print(f"0x0: {a:#x}")
    assert a == expected
    expected = 0xabadbeef
    target.write32(addr, expected)
    a = target.read32(addr)
    print(f"0x0: {a:#x}")
    assert a == expected
    # cleanup - reset scratchpad to 0's
    target.write32(0x60000008, 0x0)

pytest.main([__file__])