import pytest

from hdl.projects.grapefruit.integration.drivers.espi_dbg import EspiResponse, EspiCmd, accept_code


def test_get_status(espi_block):
    resp = espi_block.get_status()
    assert resp.crc_ok
    assert resp.response == accept_code

def test_ok_when_not_enforcing_bad_crcs(espi_block):
    espi_block.gen_invalid_crc = True
    resp = espi_block.get_status()
    assert resp.crc_ok
    assert resp.response == accept_code

# Reset value of GENERAL_CAPABILITIES: flash, OOB, virtual wire and peripheral
# channels supported (bits 3:0), everything else zero. In particular the
# advertised support fields are zero -- single I/O at 20MHz -- because they are
# driven by the link_caps register, which defaults to that.
DEFAULT_CAPS = 0x0000_000F

CAP_REG_OFFSET = 0x8
IO_MODE_SUPPORT_SHIFT = 24
OP_FREQ_SUPPORT_SHIFT = 16


def test_get_capabilities(espi_block):
    cap_reg_offset = 0x8
    expected_caps = DEFAULT_CAPS
    resp = espi_block.get_config(cap_reg_offset)
    assert resp.crc_ok
    assert resp.response == accept_code
    assert resp.get_32bit_payload() == expected_caps

def test_set_capabilities(espi_block):
    cap_reg_offset = 0x8
    # Get current value, verify ok
    resp = espi_block.get_config(cap_reg_offset)
    assert resp.crc_ok
    assert resp.response == accept_code
    cur_cap = resp.get_32bit_payload()
    # Bitwise OR in the crc enable and send checking response
    new_cap = cur_cap | (1 << 31)
    resp = espi_block.set_config(cap_reg_offset, new_cap)
    assert resp.crc_ok
    assert resp.response == accept_code
    # Read back new value and verify it took
    resp = espi_block.get_config(cap_reg_offset)
    assert resp.crc_ok
    assert resp.response == accept_code
    assert resp.get_32bit_payload() == cur_cap | (1 << 31)

    # Return back to default mode
    espi_block.set_crc_enforcement(False)

def test_enable_crc_enforcement(espi_block):
    espi_block.set_crc_enforcement(True)
    # Read back new value and verify it took
    cap_reg_offset = 0x8
    resp = espi_block.get_config(cap_reg_offset)
    assert resp.crc_ok
    assert resp.response == accept_code
    print(f"en: {resp.get_32bit_payload():#x}")
    assert resp.get_32bit_payload() & (1 << 31) == (1 << 31)
    # Turn it off
    espi_block.set_crc_enforcement(False)
    resp = espi_block.get_config(cap_reg_offset)
    assert resp.crc_ok
    assert resp.response == accept_code
    print(f"0x0: {resp.get_32bit_payload():#x}")
    assert resp.get_32bit_payload() & (1 << 31) == 0

def test_bad_crc_ignored(espi_block):
    # Enable crc enforcement
    espi_block.set_crc_enforcement(True)
    # Generate a bad crc while trying to clear
    # CRC enforcement
    # We expect no response from the CRC error
    # and the original crc enforcement should still
    # be there
    cap_reg_offset = 0x8
    cmd = EspiCmd(gen_invalid_crc=True)
    cmd.build_get_config(0x8)
    # Check that we have empty response queue
    assert espi_block.resp_wds_avail() == 0
    # send command and should still have empty response queue
    # Since it was ignored
    espi_block.send_cmd(cmd)
    print(espi_block.resp_wds_avail())
    assert espi_block.resp_wds_avail() == 0

    # Reset crc enforcement
    espi_block.set_crc_enforcement(False)

def test_flash_read(espi_block, spi_nor_block):
    # read known data pattern in flash from offset 0
    # via spi_nor_block
    # flip mux to espi
    # do an espi read of the same data
    # verify the same
    # flip mux back to spi control
    pass


pytest.main(["-rx", __file__])

def test_link_caps_defaults_to_single_20mhz(espi_block):
    """Unwritten, the block must look exactly as it did before the register existed."""
    assert espi_block.get_link_caps() == 0
    resp = espi_block.get_config(CAP_REG_OFFSET)
    assert resp.crc_ok
    assert resp.response == accept_code
    assert resp.get_32bit_payload() == DEFAULT_CAPS


def test_link_caps_advertises_io_mode(espi_block):
    """Widening the advertised I/O mode reaches GENERAL_CAPABILITIES."""
    espi_block.set_link_caps(io_mode_support=3, op_freq_support=0)
    resp = espi_block.get_config(CAP_REG_OFFSET)
    assert resp.crc_ok
    caps = resp.get_32bit_payload()
    assert (caps >> IO_MODE_SUPPORT_SHIFT) & 0x3 == 3
    # Restore, so ordering between tests cannot matter.
    espi_block.set_link_caps(io_mode_support=0, op_freq_support=0)


def test_max_freq_generic_caps_the_advertised_frequency(espi_block):
    """The build's ceiling wins over what software asks for.

    Grapefruit is built with max_freq_mhz = 20 because its SCLK pin is not clock
    capable and it carries no eSPI timing constraints. Asking for 66MHz here must
    therefore still advertise 20MHz -- the generic is the backstop that stops
    software talking a build into a frequency its timing does not close at.
    """
    espi_block.set_link_caps(io_mode_support=3, op_freq_support=4)
    # The register itself holds what was written...
    assert (espi_block.get_link_caps() >> OP_FREQ_SUPPORT_SHIFT) & 0x7 == 4
    # ...but what the host is told is clamped by the generic.
    resp = espi_block.get_config(CAP_REG_OFFSET)
    assert resp.crc_ok
    caps = resp.get_32bit_payload()
    assert (caps >> OP_FREQ_SUPPORT_SHIFT) & 0x7 == 0, "grapefruit must not advertise above 20MHz"
    espi_block.set_link_caps(io_mode_support=0, op_freq_support=0)


def test_link_caps_survives_espi_reset(espi_block):
    """An eSPI reset clears the capability register at the start of every boot.

    The advertised support belongs to the SP rather than the host, so it has to
    survive -- otherwise the link would drop to single/20MHz permanently after the
    first reset.
    """
    espi_block.set_link_caps(io_mode_support=3, op_freq_support=0)
    espi_block.espi_reset()
    resp = espi_block.get_config(CAP_REG_OFFSET)
    assert resp.crc_ok
    caps = resp.get_32bit_payload()
    assert (caps >> IO_MODE_SUPPORT_SHIFT) & 0x3 == 3, "advertised support must survive eSPI reset"
    espi_block.set_link_caps(io_mode_support=0, op_freq_support=0)
