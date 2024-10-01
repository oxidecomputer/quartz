import pytest

import speeker.udp_if as udp_if
import hdl.projects.grapefruit.integration.drivers.espi_dbg as espi_dbg
import hdl.projects.grapefruit.integration.drivers.spi_nor as spi_nor


@pytest.fixture
def target():
    """Build a basic UDP target from mem peek/poking"""
    target_ip = "fe80::0c1d:62ff:fee0:308f"
    port = 11114
    ifname = "eno1"
    return udp_if.UDPMem(target_ip, ifname, port)

@pytest.fixture
def espi_block(target):
    """Take the basic target and apply to espi and enable debug mode"""
    espi_bl = espi_dbg.OxideEspiDebug(target)
    espi_bl.enable_debug_mode()
    return espi_bl

@pytest.fixture
def spi_nor_block(target):
    """Take the basic target and apply to espi and enable debug mode"""
    spi_nor_bl = spi_nor.OxideSpiNorDebug(target)
    return spi_nor_bl