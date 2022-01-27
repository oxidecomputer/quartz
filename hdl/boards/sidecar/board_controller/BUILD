# -*- python -*- vim:syntax=python:
bluespec_library('RegCommon',
    sources = [
        '../../gimlet/sequencer/RegCommon.bsv',
    ])

bluespec_library('SpiDecode',
    sources = [
        '../../gimlet/sequencer/SpiDecode.bsv',
    ],
    deps = [
        ':RegCommon',
    ])

bluespec_library('SidecarSeqRegs',
    sources = [
        'SidecarSeqRegs.bsv',
    ],
    deps = [
        ':RegCommon',
    ])

bluespec_library('Tofino2PowerCtrlSync',
    sources = [
        'Tofino2PowerCtrl/Tofino2PowerCtrlSync.bsv'
    ],
    deps = [
        ':SidecarCtrlTopPhysIfs',
        'cobalt//hdl:SyncBits',
    ])

bluespec_library('Tofino2PowerCtrl',
    sources = [
        'Tofino2PowerCtrl/Tofino2PowerCtrl.bsv'
    ],
    deps = [
        ':Tofino2PowerCtrlSync',
        ':SidecarSeqRegs',
    ])

bluespec_library('SidecarCtrlTopPhysIfs',
    sources = [
        'SidecarCtrlTopPhysIfs.bsv',
    ])

bluespec_library('SidecarCtrlTopIOWrapper',
    sources = [
        'SidecarCtrlTopIOWrapper.bsv',
    ],
    deps = [
        ':Tofino2PowerCtrl',
        ':Tofino2PowerCtrlSync',
        ':SidecarCtrlTopPhysIfs',
        ':SpiDecode',
        ':SidecarCtrlRegs',
        ':SidecarSeqRegs',
        'cobalt//hdl:Strobe',
        'cobalt//hdl/interfaces:UART',
    ])

bluespec_sim('tofino2_power_ctrl_top',
    top = 'Tofino2PowerCtrl/Tofino2PowerCtrlTest.bsv',
    modules = [
        'mkTofino2PowerCtrlTestTop'
    ],
    deps = [
        ':Tofino2PowerCtrl',
        'cobalt//hdl:TestUtils',
    ])

bluesim_binary('tofino2_power_ctrl_test',
    env = 'cobalt//bluesim_default',
    top = ':tofino2_power_ctrl_top#mkTofino2PowerCtrlTestTop',
    deps = [
        ':tofino2_power_ctrl_top',
    ])

bluespec_library('SidecarCtrlRegs',
    sources = [
        'SidecarCtrlRegs.bsv',
    ],
    deps = [
        ':SidecarSeqRegs',
        ':RegCommon',
        'cobalt//hdl/examples:Blinky',
    ])

bluespec_library('SidecarCtrlTop',
    sources = [
        'SidecarCtrlTop.bsv',
    ],
    deps = [
        ':SidecarCtrlTopIOWrapper',
    ])

# Bitfile target
bluespec_verilog('SidecarCtrlTopV',
    top = 'SidecarCtrlTop.bsv',
    modules = [
        'mkSidecarCtrlTop',
    ],
    deps = [
        ':SidecarCtrlTop',
    ])

yosys_design('sidecar_controller_top',
    top_module = 'mkSidecarCtrlTop',
    sources = [
        ':SidecarCtrlTopV#mkSidecarCtrlTop',
        'cobalt//vnd/bluespec:Verilog.v#Verilog.v',
    ],
    deps = [
        ':SidecarCtrlTopV',
        'cobalt//vnd/bluespec:Verilog.v',
    ])

nextpnr_ecp5_bitstream('sidecar_controller',
    env = 'sidecar_board_controller',
    design = ':sidecar_controller_top#sidecar_controller_top.json',
    deps = [
        ':sidecar_controller_top',
    ])