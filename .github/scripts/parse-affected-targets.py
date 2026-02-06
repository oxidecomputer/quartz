#!/usr/bin/env python3
"""Parse buck2-change-detector output and generate target lists for CI"""

import json
import subprocess
import sys
from pathlib import Path
from collections import defaultdict
from typing import Dict, List, Set, Tuple


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

    # Bitstreams via cquery
    # Note: ice40_bitstream and ecp5_bitstream match both VHDL and BSV targets
    # (bsv_nextpnr_ice40_bitstream/bsv_nextpnr_ecp5_bitstream are subtypes)
    ice40_output = run_command([
        'buck2', 'cquery',
        'kind("ice40_bitstream", //hdl/projects/...)'
    ])
    ecp5_output = run_command([
        'buck2', 'cquery',
        'kind("ecp5_bitstream", //hdl/projects/...)'
    ])
    vivado_output = run_command([
        'buck2', 'cquery',
        'kind("vivado_bitstream", //hdl/projects/...)'
    ])

    targets['ice40_bitstreams'] = [normalize_target(t) for t in ice40_output.split('\n') if t]
    targets['ecp5_bitstreams'] = [normalize_target(t) for t in ecp5_output.split('\n') if t]
    targets['vivado_bitstreams'] = [normalize_target(t) for t in vivado_output.split('\n') if t]

    return targets


def normalize_target(target: str) -> str:
    """Normalize Buck2 target by stripping root// prefix and platform suffix"""
    # Remove platform suffix like (prelude//platforms:default#...)
    if '(' in target:
        target = target.split('(')[0].strip()

    # Strip root// prefix to normalize to //
    if target.startswith('root//'):
        target = '//' + target[6:]

    return target


def extract_target(buck2_run_cmd: str) -> str:
    """Extract target from 'buck2 run //path:target' or 'buck2 run root//path:target' command"""
    parts = buck2_run_cmd.split()
    for part in parts:
        if part.startswith('root//'):
            # Strip root// prefix to normalize to //
            return '//' + part[6:].split()[0]
        elif part.startswith('//'):
            return part.split()[0]  # Strip any args
    return ""


def parse_btd_output(btd_json_path: str) -> Set[str]:
    """Parse btd JSON and return set of affected targets"""

    with open(btd_json_path, 'r') as f:
        btd_data = json.load(f)

    affected = set()

    # BTD format: array of {"target": "root//path:name", "type": "...", ...}
    if isinstance(btd_data, list):
        for entry in btd_data:
            target = entry.get('target', '')
            if target:
                # Strip 'root//' prefix if present
                if target.startswith('root//'):
                    target = '//' + target[6:]
                affected.add(target)
    # Legacy format: {"targets": [{"target": "//path:name", ...}, ...]}
    elif 'targets' in btd_data:
        for entry in btd_data['targets']:
            target = entry.get('target', '')
            if target:
                affected.add(target)

    return affected


def analyze_file_impact(changes_file: str, affected_targets: Set[str]) -> List[Tuple[str, int]]:
    """Analyze which file changes caused the most target impacts using package area heuristics

    Returns list of (filename, affected_count) tuples sorted by impact
    """
    if not Path(changes_file).exists():
        return []

    # Read changed files from changes.txt (format: "M path/to/file" or "A path/to/file")
    changed_files = []
    with open(changes_file, 'r') as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            # Parse "M path/to/file" format
            parts = line.split(' ', 1)
            if len(parts) == 2:
                changed_files.append(parts[1])

    if not changed_files:
        return []

    print(f"  Analyzing impact of {len(changed_files)} changed files...", file=sys.stderr)

    # Track impact per file using sets to avoid double-counting
    file_impact = defaultdict(set)

    # For each changed file, count affected targets in related package areas
    for file_path in changed_files:
        file_dir = str(Path(file_path).parent)
        file_parts = file_path.split('/')

        # Categorize file location
        is_hdl_ip = file_parts[0:2] == ['hdl', 'ip']
        is_project = file_parts[0:2] == ['hdl', 'projects']
        is_tools = file_parts[0] == 'tools'
        is_build_file = file_path.endswith('.bzl') or file_path.startswith('.buck')
        is_prelude = file_parts[0] == 'prelude'

        # Match against affected targets
        for target in affected_targets:
            target_path = target.lstrip('/').split(':')[0]
            target_parts = target_path.split('/')

            matched = False

            # Build system files affect everything
            if is_build_file or is_prelude or is_tools:
                matched = True
            # Files in hdl/ip affect all hdl targets (both ip and projects)
            elif is_hdl_ip and (target_parts[0:2] == ['hdl', 'ip'] or target_parts[0:2] == ['hdl', 'projects']):
                matched = True
            # Project files affect that specific project and related targets
            elif is_project and target_path.startswith(file_dir):
                matched = True
            # Direct directory match
            elif target_path.startswith(file_dir):
                matched = True

            if matched:
                file_impact[file_path].add(target)

    # Convert sets to counts and sort
    result = [(path, len(targets)) for path, targets in file_impact.items()]
    return sorted(result, key=lambda x: x[1], reverse=True)


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
        print(f"Usage: {sys.argv[0]} <btd_output.json> <output_dir> [--fallback]", file=sys.stderr)
        sys.exit(1)

    btd_json = sys.argv[1]
    output_dir = Path(sys.argv[2])
    fallback = '--fallback' in sys.argv
    output_dir.mkdir(parents=True, exist_ok=True)

    # Get all targets from BXL/cquery
    print("Discovering all targets...", file=sys.stderr)
    all_targets = get_all_targets()

    # Parse BTD output for affected targets
    print("Parsing BTD output...", file=sys.stderr)
    affected_targets = parse_btd_output(btd_json)

    # Only fall back to running everything when BTD itself failed
    # (indicated by --fallback); zero targets from a successful BTD
    # run means nothing was affected.
    if fallback:
        print("BTD failed (--fallback) - running all targets", file=sys.stderr)
        affected_by_category = all_targets
        affected_targets = set()
        for targets in all_targets.values():
            affected_targets.update(targets)
    else:
        # Filter to affected only
        affected_by_category = filter_affected(all_targets, affected_targets)

    # Write simulation target lists as simple JSON arrays (not matrix format)
    # These run in a single job that loops over targets
    (output_dir / 'vunit_tests.json').write_text(json.dumps(affected_by_category['vunit_tests']))
    (output_dir / 'bsv_tests.json').write_text(json.dumps(affected_by_category['bsv_tests']))

    # Generate matrix JSONs for bitstream builds (still use matrix jobs)
    matrices = {
        'ice40_matrix': generate_matrix_json(affected_by_category['ice40_bitstreams']),
        'ecp5_matrix': generate_matrix_json(affected_by_category['ecp5_bitstreams']),
        'vivado_matrix': generate_matrix_json(affected_by_category['vivado_bitstreams']),
    }

    # Write bitstream matrices to files
    for name, matrix_json in matrices.items():
        output_file = output_dir / f"{name}.json"
        with open(output_file, 'w') as f:
            f.write(matrix_json)

    # Write summary
    # Calculate tracked vs other targets
    tracked_count = (
        len(affected_by_category['vunit_tests']) +
        len(affected_by_category['bsv_tests']) +
        len(affected_by_category['ice40_bitstreams']) +
        len(affected_by_category['ecp5_bitstreams']) +
        len(affected_by_category['vivado_bitstreams'])
    )
    other_count = len(affected_targets) - tracked_count

    summary = {
        'total_affected': len(affected_targets),
        'vunit_tests': len(affected_by_category['vunit_tests']),
        'bsv_tests': len(affected_by_category['bsv_tests']),
        'ice40_bitstreams': len(affected_by_category['ice40_bitstreams']),
        'ecp5_bitstreams': len(affected_by_category['ecp5_bitstreams']),
        'vivado_bitstreams': len(affected_by_category['vivado_bitstreams']),
        'other_targets': other_count,
    }

    with open(output_dir / 'summary.json', 'w') as f:
        json.dump(summary, f, indent=2)

    print("\nAffected targets summary:")
    for key, value in summary.items():
        print(f"  {key}: {value}")

    print(f"\n  Note: 'other_targets' includes libraries, intermediate build artifacts, etc.")

    # Analyze and display file impact (top 10 files by number of affected targets)
    if len(affected_targets) > 0:
        print("\nTop file changes by impact (targets affected):")
        changes_file = "/tmp/changes.txt"
        file_impacts = analyze_file_impact(changes_file, affected_targets)

        if file_impacts:
            for i, (file_path, count) in enumerate(file_impacts[:10], 1):
                print(f"  {i:2d}. {file_path} ({count} targets)")
        else:
            print("  (No file impact data available)")


if __name__ == '__main__':
    main()
