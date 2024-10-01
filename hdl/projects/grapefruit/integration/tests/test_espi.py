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

def test_get_capabilities(espi_block):
    cap_reg_offset = 0x8
    expected_caps = 0x03040004
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