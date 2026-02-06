#!/usr/bin/env python3
"""
Convert cobble BUILD files to Buck2 BUCK files for BSV projects.

This script parses Python-based cobble BUILD files and generates equivalent
Starlark-based BUCK files for Buck2.

Usage:
    python build_to_buck_converter.py <build_file> [--output <buck_file>] [--dry-run]
"""

import ast
import argparse
import sys
from pathlib import Path
from typing import List, Dict, Any, Optional


class BuildToBuckConverter:
    """Convert cobble BUILD files to Buck2 BUCK format."""

    # Mapping from cobble rules to Buck2 rules
    RULE_MAPPING = {
        'bluespec_library': 'bsv_library',
        'bluespec_verilog': 'bsv_verilog',
        'bluespec_sim': 'bsv_sim',
        'bluesim_binary': 'bsv_bluesim_binary',
        'bluesim_tests': 'bsv_bluesim_tests',
        'rdl': 'rdl_file',
        'bsv_fpga_version': None,  # Skip for now, needs custom handling
        'yosys_design': None,  # Skip, out of scope for BSV
        'c_binary': None,  # Skip, out of scope for BSV
    }

    # Attribute mappings (cobble → Buck2)
    ATTR_MAPPING = {
        'sources': 'srcs',  # cobble uses 'sources', Buck2 uses 'srcs'
        'suite': 'top',  # bluesim_tests uses 'suite', Buck2 uses 'top'
    }

    def __init__(self):
        self.load_statements = set()
        self.targets = []
        self.skipped_rules = []

    def parse_build_file(self, build_path: Path) -> None:
        """Parse a cobble BUILD file."""
        with open(build_path, 'r') as f:
            content = f.read()

        try:
            tree = ast.parse(content, filename=str(build_path))
            self._visit_tree(tree)
        except SyntaxError as e:
            print(f"Error parsing {build_path}: {e}", file=sys.stderr)
            raise

    def _visit_tree(self, tree: ast.Module) -> None:
        """Visit AST nodes and extract rule calls."""
        for node in ast.walk(tree):
            if isinstance(node, ast.Call) and isinstance(node.func, ast.Name):
                rule_name = node.func.id
                if rule_name in self.RULE_MAPPING:
                    self._process_rule_call(rule_name, node)

    def _process_rule_call(self, rule_name: str, call_node: ast.Call) -> None:
        """Process a cobble rule call and convert to Buck2 format."""
        buck_rule = self.RULE_MAPPING[rule_name]

        if buck_rule is None:
            self.skipped_rules.append(rule_name)
            return

        # Extract target name (first positional argument)
        if not call_node.args:
            print(f"Warning: Rule {rule_name} has no name argument", file=sys.stderr)
            return

        target_name = self._extract_string_value(call_node.args[0])
        if not target_name:
            print(f"Warning: Could not extract target name for {rule_name}", file=sys.stderr)
            return

        # Extract keyword arguments
        kwargs = {}
        for keyword in call_node.keywords:
            attr_name = keyword.arg
            attr_value = self._extract_value(keyword.value)

            # Map attribute names (but not 'suite' for bsv_bluesim_tests macro)
            if attr_name in self.ATTR_MAPPING:
                # bsv_bluesim_tests macro keeps 'suite' parameter
                if not (buck_rule == 'bsv_bluesim_tests' and attr_name == 'suite'):
                    attr_name = self.ATTR_MAPPING[attr_name]

            kwargs[attr_name] = attr_value

        # Add load statement
        if buck_rule == 'rdl_file':
            self.load_statements.add('load("//tools:rdl.bzl", "rdl_file")')
        else:
            self.load_statements.add(f'load("//tools:bsv.bzl", "{buck_rule}")')

        # Convert rule-specific attributes
        if buck_rule == 'rdl_file':
            kwargs = self._convert_rdl_attrs(kwargs)
        elif buck_rule in ['bsv_verilog', 'bsv_sim']:
            kwargs = self._convert_verilog_sim_attrs(kwargs)
        elif buck_rule == 'bsv_bluesim_binary':
            kwargs = self._convert_binary_attrs(kwargs)
        elif buck_rule == 'bsv_bluesim_tests':
            kwargs = self._convert_tests_attrs(kwargs)

        # Convert dependencies
        if 'deps' in kwargs:
            kwargs['deps'] = self._convert_deps(kwargs['deps'])

        # Store target
        self.targets.append({
            'name': target_name,
            'rule': buck_rule,
            'attrs': kwargs,
        })

    def _extract_value(self, node: ast.AST) -> Any:
        """Extract a Python value from an AST node."""
        if isinstance(node, ast.Constant):
            return node.value
        elif isinstance(node, ast.Str):  # Python 3.7 compatibility
            return node.s
        elif isinstance(node, ast.List):
            return [self._extract_value(elt) for elt in node.elts]
        elif isinstance(node, ast.Dict):
            return {
                self._extract_value(k): self._extract_value(v)
                for k, v in zip(node.keys, node.values)
            }
        elif isinstance(node, ast.Name):
            # Variable reference (e.g., ROOT, env names)
            return f"<{node.id}>"  # Placeholder for manual review
        elif isinstance(node, ast.BinOp):
            # String concatenation or arithmetic
            return "<expression>"  # Placeholder for manual review
        else:
            return None

    def _extract_string_value(self, node: ast.AST) -> Optional[str]:
        """Extract a string value from an AST node."""
        val = self._extract_value(node)
        return val if isinstance(val, str) else None

    def _convert_deps(self, deps: List[str]) -> List[str]:
        """Convert cobble dependency paths to Buck2 format."""
        converted = []
        for dep in deps:
            if not isinstance(dep, str):
                continue

            # Handle output references (e.g., ':target#output.bsv')
            if '#' in dep:
                # In Buck2, we reference the target directly, not specific outputs
                base_dep = dep.split('#')[0]
                converted.append(base_dep)
            else:
                # Dependencies stay mostly the same
                # cobble: '//hdl/ip/bsv:Library' or ':LocalTarget'
                # Buck2: same format
                converted.append(dep)

        return converted

    def _convert_rdl_attrs(self, attrs: Dict[str, Any]) -> Dict[str, Any]:
        """Convert RDL rule attributes."""
        # cobble uses 'sources' with a list, Buck2 uses 'src' with a single file
        if 'srcs' in attrs and isinstance(attrs['srcs'], list) and len(attrs['srcs']) == 1:
            attrs['src'] = attrs['srcs'][0]
            del attrs['srcs']

        # Remove 'deps' if empty (Buck2 makes it optional)
        if 'deps' in attrs and not attrs['deps']:
            del attrs['deps']

        return attrs

    def _convert_verilog_sim_attrs(self, attrs: Dict[str, Any]) -> Dict[str, Any]:
        """Convert verilog/sim rule attributes."""
        # Remove 'env' attribute (Buck2 doesn't use explicit environments)
        attrs.pop('env', None)

        # Remove 'using' and 'local' (Buck2 uses bsc_flags directly)
        if 'using' in attrs or 'local' in attrs:
            # Extract bsc_flags if present
            bsc_flags = []
            if 'using' in attrs and isinstance(attrs['using'], dict):
                bsc_flags.extend(attrs['using'].get('bsc_flags', []))
            if 'local' in attrs and isinstance(attrs['local'], dict):
                bsc_flags.extend(attrs['local'].get('bsc_flags', []))

            if bsc_flags:
                attrs['bsc_flags'] = bsc_flags

            attrs.pop('using', None)
            attrs.pop('local', None)

        return attrs

    def _convert_binary_attrs(self, attrs: Dict[str, Any]) -> Dict[str, Any]:
        """Convert bluesim_binary attributes."""
        # Remove 'env'
        attrs.pop('env', None)

        # Convert 'top' reference from ':target#module' to ':target'
        if 'top' in attrs and isinstance(attrs['top'], str) and '#' in attrs['top']:
            attrs['top'] = attrs['top'].split('#')[0]

        # Add 'entry_point' from module name if not present
        # This is a heuristic - may need manual adjustment
        if 'entry_point' not in attrs and 'top' in attrs:
            # Extract module name from top reference if possible
            # Format is typically ':sim_target#moduleName'
            pass  # Requires manual specification

        attrs.pop('extra', None)  # Remove cobble-specific extras

        return attrs

    def _convert_tests_attrs(self, attrs: Dict[str, Any]) -> Dict[str, Any]:
        """Convert bluesim_tests attributes."""
        # Remove 'env'
        attrs.pop('env', None)

        return attrs

    def generate_buck_file(self) -> str:
        """Generate Buck2 BUCK file content."""
        lines = []

        # Add load statements
        load_stmts = sorted(self.load_statements)
        if load_stmts:
            lines.extend(load_stmts)
            lines.append('')

        # Check for RDL-generated BSV references and add warning
        has_rdl_refs = False
        for target in self.targets:
            if 'srcs' in target['attrs']:
                srcs = target['attrs']['srcs']
                if isinstance(srcs, list):
                    for src in srcs:
                        if isinstance(src, str) and '#' in src and src.endswith('.bsv'):
                            has_rdl_refs = True
                            break

        if has_rdl_refs:
            lines.append("# ⚠️  WARNING: RDL-generated BSV package references detected!")
            lines.append("# Buck2 cannot currently import RDL-generated BSV packages using ':target#file.bsv' syntax.")
            lines.append("# Affected targets will fail to build. Use cobble for RDL-dependent builds, or see")
            lines.append("# docs/BSV_MIGRATION_STATUS.md for workarounds.")
            lines.append("")

        # Add targets
        for target in self.targets:
            lines.append(f"# {target['rule']}")
            lines.append(f"{target['rule']}(")
            lines.append(f'    name = "{target["name"]}",')

            # Add attributes
            for attr_name, attr_value in target['attrs'].items():
                lines.append(self._format_attribute(attr_name, attr_value))

            lines.append(")")
            lines.append("")

        # Add warnings about skipped rules
        if self.skipped_rules:
            lines.append("# WARNING: The following cobble rules were skipped:")
            for rule in set(self.skipped_rules):
                lines.append(f"# - {rule}")
            lines.append("")

        return '\n'.join(lines)

    def _format_attribute(self, name: str, value: Any, indent: int = 4) -> str:
        """Format an attribute for Buck2 Starlark syntax."""
        prefix = ' ' * indent

        if isinstance(value, str):
            return f'{prefix}{name} = "{value}",'
        elif isinstance(value, list):
            if not value:
                return f'{prefix}{name} = [],'
            elif len(value) == 1:
                return f'{prefix}{name} = ["{value[0]}"],'
            else:
                lines = [f'{prefix}{name} = [']
                for item in value:
                    if isinstance(item, str):
                        lines.append(f'{prefix}    "{item}",')
                    else:
                        lines.append(f'{prefix}    {item},')
                lines.append(f'{prefix}],')
                return '\n'.join(lines)
        elif isinstance(value, dict):
            lines = [f'{prefix}{name} = {{']
            for k, v in value.items():
                if isinstance(v, str):
                    lines.append(f'{prefix}    "{k}": "{v}",')
                else:
                    lines.append(f'{prefix}    "{k}": {v},')
            lines.append(f'{prefix}}},')
            return '\n'.join(lines)
        elif isinstance(value, bool):
            return f'{prefix}{name} = {str(value)},  '
        elif isinstance(value, int):
            return f'{prefix}{name} = {value},'
        else:
            return f'{prefix}{name} = {repr(value)},'


def main():
    parser = argparse.ArgumentParser(
        description='Convert cobble BUILD files to Buck2 BUCK format'
    )
    parser.add_argument(
        'build_file',
        type=Path,
        help='Path to cobble BUILD file'
    )
    parser.add_argument(
        '--output', '-o',
        type=Path,
        help='Output BUCK file path (default: same directory as BUILD, named BUCK)'
    )
    parser.add_argument(
        '--dry-run',
        action='store_true',
        help='Print output to stdout instead of writing to file'
    )

    args = parser.parse_args()

    if not args.build_file.exists():
        print(f"Error: BUILD file not found: {args.build_file}", file=sys.stderr)
        sys.exit(1)

    # Determine output path
    if args.output:
        output_path = args.output
    else:
        output_path = args.build_file.parent / 'BUCK'

    # Convert
    converter = BuildToBuckConverter()
    try:
        converter.parse_build_file(args.build_file)
        buck_content = converter.generate_buck_file()

        if args.dry_run:
            print(buck_content)
        else:
            with open(output_path, 'w') as f:
                f.write(buck_content)
            print(f"Converted {args.build_file} → {output_path}")
            if converter.skipped_rules:
                print(f"Warning: Skipped {len(set(converter.skipped_rules))} rule types")

    except Exception as e:
        print(f"Error during conversion: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == '__main__':
    main()
