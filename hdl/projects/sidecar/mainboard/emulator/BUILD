# -*- python -*- vim:syntax=python:

bluespec_library('SidecarMainboardEmulator',
    sources = [
        'SidecarMainboardEmulator.bsv',
    ],
    deps = [
        '//hdl/ip/bsv:BitSampling',
        '//hdl/ip/bsv:PowerRail',
        '//hdl/ip/bsv:SerialIO',
        '//hdl/ip/bsv:Strobe',
        '//hdl/ip/bsv/ignition:Target',
        '//hdl/ip/bsv/ignition:Transceiver',
        '//hdl/ip/bsv/interfaces:ECP5',
        '//hdl/projects/sidecar/mainboard:SidecarMainboardControllerTop',
    ])

bluespec_verilog('mkSidecarMainboardEmulatorOnEcp5Evn',
    top = 'SidecarMainboardEmulator.bsv',
    modules = [
        'mkSidecarMainboardEmulatorOnEcp5Evn',
    ],
    deps = [
        ':SidecarMainboardEmulator',
    ])

yosys_design('sidecar_mainboard_emulator_epc5_evn_top',
    top_module = 'mkSidecarMainboardEmulatorOnEcp5Evn',
    sources = [
        ':mkSidecarMainboardEmulatorOnEcp5Evn#mkSidecarMainboardEmulatorOnEcp5Evn',
        '//vnd/bluespec:Verilog.v#Verilog.v',
        '../../../../ip/bsv/interfaces/ECP5PLL.v', # This is a hack, we should improve this
    ],
    deps = [
        ':mkSidecarMainboardEmulatorOnEcp5Evn',
        '//vnd/bluespec:Verilog.v',
    ])

nextpnr_ecp5_bitstream('sidecar_mainboard_emulator_ecp5_evn',
    env = 'sidecar_mainboard_emulator_ecp5_evn',
    design = ':sidecar_mainboard_emulator_epc5_evn_top#sidecar_mainboard_emulator_epc5_evn_top.json',
    deps = [
        ':sidecar_mainboard_emulator_epc5_evn_top',
    ])
