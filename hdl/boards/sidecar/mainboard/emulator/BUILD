# -*- python -*- vim:syntax=python:

bluespec_library('SidecarMainboardEmulator',
    sources = [
        'SidecarMainboardEmulator.bsv',
    ],
    deps = [
        '//hdl:PowerRail',
        '//hdl/boards/sidecar/mainboard:SidecarMainboardControllerTop',
        '//hdl/ignition:Target',
        '//hdl/ignition:Transceiver',
        'cobalt//hdl:BitSampling',
        'cobalt//hdl:SerialIO',
        'cobalt//hdl:Strobe',
        'cobalt//hdl/interfaces:ECP5',
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
        'cobalt//vnd/bluespec:Verilog.v#Verilog.v',
        '../../../../../vnd/cobalt/hdl/interfaces/ECP5PLL.v', # Hack
    ],
    deps = [
        ':mkSidecarMainboardEmulatorOnEcp5Evn',
        'cobalt//vnd/bluespec:Verilog.v',
    ])

nextpnr_ecp5_bitstream('sidecar_mainboard_emulator_ecp5_evn',
    env = 'sidecar_mainboard_emulator_ecp5_evn',
    design = ':sidecar_mainboard_emulator_epc5_evn_top#sidecar_mainboard_emulator_epc5_evn_top.json',
    deps = [
        ':sidecar_mainboard_emulator_epc5_evn_top',
    ])
