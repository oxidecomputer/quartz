import pytest

import speeker.udp_if as udp_if
import hdl.projects.grapefruit.integration.drivers as drivers


@pytest.fixture
def target():
    """Build a basic UDP target from mem peek/poking"""
    target_ip = "fe80::c1d:76ff:fea8:34f5"
    port = 11114
    ifname = "eno1"
    return udp_if.UDPMem(target_ip, ifname, port)

@pytest.fixture
def espi_block(target):
    """Take the basic target and apply to espi and enable debug mode"""
    espi_bl = drivers.espi_dbg.OxideEspiDebug(target)
    espi_bl.enable_debug_mode()
    return drivers.espi_dbg.OxideEspiDebug(target)