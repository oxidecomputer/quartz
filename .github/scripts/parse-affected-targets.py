#!/usr/bin/env python3
"""Parse buck2-change-detector output and generate target lists for CI"""

import json
import subprocess
import sys
from pathlib import Path
from typing import Dict, List, Set


def run_command(cmd: List[str]) -> str:
    """Run command and return stdout"""
    result = subprocess.run(cmd, capture_output=True, text=True, check=False)
    return result.stdout.strip() if result.returncode == 0 else ""


def get_all_targets() -> Dict[str, List[str]]:
    """Discover all test and bitstream targets using BXL and cquery"""

    targets = {}

    # VUnit tests via BXL
    vunit_output = run_command(['buck2', 'bxl', '//tools/vunit-sims.bxl:vunit_sim_gen'])
    targets['vunit_tests'] = [
        extract_target(line)
        for line in vunit_output.split('\n')
        if line.startswith('buck2 run')
    ]

    # BSV tests via BXL
    bsv_output = run_command(['buck2', 'bxl', '//tools/bsv-tests.bxl:bsv_test_gen'])
    targets['bsv_tests'] = [
        extract_target(line)
        for line in bsv_output.split('\n')
        if line.startswith('buck2 run')
    ]

    # BSV bitstreams via cquery
    ice40_output = run_command([
        'buck2', 'cquery',
        'kind("bsv_nextpnr_ice40_bitstream", //hdl/projects/...)'
    ])
    ecp5_output = run_command([
        'buck2', 'cquery',
        'kind("bsv_nextpnr_ecp5_bitstream", //hdl/projects/...)'
    ])

    targets['ice40_bitstreams'] = [t for t in ice40_output.split('\n') if t]
    targets['ecp5_bitstreams'] = [t for t in ecp5_output.split('\n') if t]

    # VHDL bitstreams (specific projects)
    targets['vivado_bitstreams'] = [
        '//hdl/projects/grapefruit:grapefruit',
        '//hdl/projects/cosmo_seq:cosmo_seq',
        '//hdl/projects/cosmo_hp:cosmo_hp',
        '//hdl/projects/cosmo_ignition:cosmo_ignition',
        '//hdl/projects/cosmo_ignition:cosmo_ignition_a',
    ]

    return targets


def extract_target(buck2_run_cmd: str) -> str:
    """Extract target from 'buck2 run //path:target' command"""
    parts = buck2_run_cmd.split()
    for part in parts:
        if part.startswith('//'):
            return part.split()[0]  # Strip any args
    return ""


def parse_btd_output(btd_json_path: str) -> Set[str]:
    """Parse btd JSON and return set of affected targets"""

    with open(btd_json_path, 'r') as f:
        btd_data = json.load(f)

    affected = set()

    # BTD format: {"targets": [{"target": "//path:name", "depth": 0}, ...]}
    if 'targets' in btd_data:
        for entry in btd_data['targets']:
            target = entry.get('target', '')
            if target:
                affected.add(target)

    return affected


def filter_affected(all_targets: Dict[str, List[str]], affected: Set[str]) -> Dict[str, List[str]]:
    """Filter target lists to only include affected targets"""

    filtered = {}
    for category, targets in all_targets.items():
        filtered[category] = [t for t in targets if t in affected]

    return filtered


def generate_matrix_json(targets: List[str]) -> str:
    """Generate GitHub Actions matrix JSON"""
    return json.dumps({'target': targets if targets else []})


def main():
    if len(sys.argv) < 3:
        print(f"Usage: {sys.argv[0]} <btd_output.json> <output_dir>", file=sys.stderr)
        sys.exit(1)

    btd_json = sys.argv[1]
    output_dir = Path(sys.argv[2])
    output_dir.mkdir(parents=True, exist_ok=True)

    # Get all targets from BXL/cquery
    print("Discovering all targets...", file=sys.stderr)
    all_targets = get_all_targets()

    # Parse BTD output for affected targets
    print("Parsing BTD output...", file=sys.stderr)
    affected_targets = parse_btd_output(btd_json)

    # Filter to affected only
    affected_by_category = filter_affected(all_targets, affected_targets)

    # Generate matrix JSONs for GitHub Actions
    matrices = {
        'vunit_matrix': generate_matrix_json(affected_by_category['vunit_tests']),
        'bsv_test_matrix': generate_matrix_json(affected_by_category['bsv_tests']),
        'ice40_matrix': generate_matrix_json(affected_by_category['ice40_bitstreams']),
        'ecp5_matrix': generate_matrix_json(affected_by_category['ecp5_bitstreams']),
        'vivado_matrix': generate_matrix_json(affected_by_category['vivado_bitstreams']),
    }

    # Write matrices to files
    for name, matrix_json in matrices.items():
        output_file = output_dir / f"{name}.json"
        with open(output_file, 'w') as f:
            f.write(matrix_json)

    # Write summary
    summary = {
        'total_affected': len(affected_targets),
        'vunit_tests': len(affected_by_category['vunit_tests']),
        'bsv_tests': len(affected_by_category['bsv_tests']),
        'ice40_bitstreams': len(affected_by_category['ice40_bitstreams']),
        'ecp5_bitstreams': len(affected_by_category['ecp5_bitstreams']),
        'vivado_bitstreams': len(affected_by_category['vivado_bitstreams']),
    }

    with open(output_dir / 'summary.json', 'w') as f:
        json.dump(summary, f, indent=2)

    print("\nAffected targets summary:")
    for key, value in summary.items():
        print(f"  {key}: {value}")


if __name__ == '__main__':
    main()
