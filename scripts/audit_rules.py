#!/usr/bin/env python3
"""
Audit implemented lint rules against ROADMAP.md entries.

This script identifies:
  - Rules in ROADMAP.md that are already implemented (as rules or aliases)
  - Near-matches that may indicate naming inconsistencies

Version:   1.0
Author:    Saropa
Copyright: (c) 2025-2026 Saropa

Usage:
    python scripts/audit_rules.py
"""

from __future__ import annotations

import os
import re
import sys
from datetime import datetime
from enum import Enum
from pathlib import Path


SCRIPT_VERSION = "1.0"


# =============================================================================
# COLOR AND PRINTING
# =============================================================================
# NOTE: These utilities are duplicated across scripts. Consider extracting to
# scripts/utils.py if adding more scripts that need colored output.

class Color(Enum):
    """ANSI color codes."""
    GREEN = "\033[92m"
    YELLOW = "\033[93m"
    RED = "\033[91m"
    CYAN = "\033[96m"
    MAGENTA = "\033[95m"
    WHITE = "\033[97m"
    RESET = "\033[0m"
    DIM = "\033[2m"
    BOLD = "\033[1m"


def enable_ansi_support() -> None:
    """Enable ANSI escape sequence support on Windows (CMD and PowerShell)."""
    if sys.platform == "win32":
        try:
            import ctypes
            from ctypes import wintypes
            kernel32 = ctypes.windll.kernel32
            STD_OUTPUT_HANDLE = -11
            ENABLE_VIRTUAL_TERMINAL_PROCESSING = 0x0004
            handle = kernel32.GetStdHandle(STD_OUTPUT_HANDLE)
            mode = wintypes.DWORD()
            kernel32.GetConsoleMode(handle, ctypes.byref(mode))
            kernel32.SetConsoleMode(
                handle, mode.value | ENABLE_VIRTUAL_TERMINAL_PROCESSING
            )
        except Exception:
            pass

        if "TERM" not in os.environ:
            os.environ["TERM"] = "xterm-256color"

        # Set UTF-8 encoding for stdout
        try:
            sys.stdout.reconfigure(encoding='utf-8')  # type: ignore[attr-defined]
        except (AttributeError, OSError):
            pass


# cspell: disable
def show_saropa_logo() -> None:
    """Display the Saropa 'S' logo in ASCII art."""
    logo = """
\033[38;5;208m                               ....\033[0m
\033[38;5;208m                       `-+shdmNMMMMNmdhs+-\033[0m
\033[38;5;209m                    -odMMMNyo/-..````.++:+o+/-\033[0m
\033[38;5;215m                 `/dMMMMMM/`          ``````````\033[0m
\033[38;5;220m                `dMMMMMMMMNdhhhdddmmmNmmddhs+-\033[0m
\033[38;5;226m                /MMMMMMMMMMMMMMMMMMMMMMMMMMMMMNh/\033[0m
\033[38;5;190m              . :sdmNNNNMMMMMNNNMMMMMMMMMMMMMMMMm+\033[0m
\033[38;5;154m              o     `..~~~::~+==+~:/+sdNMMMMMMMMMMMo\033[0m
\033[38;5;118m              m                        .+NMMMMMMMMMN\033[0m
\033[38;5;123m              m+                         :MMMMMMMMMm\033[0m
\033[38;5;87m              /N:                        :MMMMMMMMM/\033[0m
\033[38;5;51m               oNs.                    `+NMMMMMMMMo\033[0m
\033[38;5;45m                :dNy/.              ./smMMMMMMMMm:\033[0m
\033[38;5;39m                 `/dMNmhyso+++oosydNNMMMMMMMMMd/\033[0m
\033[38;5;33m                    .odMMMMMMMMMMMMMMMMMMMMdo-\033[0m
\033[38;5;57m                       `-+shdNNMMMMNNdhs+-\033[0m
\033[38;5;57m                               ````\033[0m
"""
    print(logo)
    current_year = datetime.now().year
    copyright_year = f"2024-{current_year}" if current_year > 2024 else "2024"
    print(f"\033[38;5;195m(c) {copyright_year} Saropa. All rights reserved.\033[0m")
    print("\033[38;5;117mhttps://saropa.com\033[0m")
    print()
# cspell: enable


def print_colored(message: str, color: Color) -> None:
    """Print a message with ANSI color codes."""
    print(f"{color.value}{message}{Color.RESET.value}")


def print_header(text: str) -> None:
    """Print a section header."""
    print()
    print_colored("=" * 70, Color.CYAN)
    print_colored(f"  {text}", Color.CYAN)
    print_colored("=" * 70, Color.CYAN)
    print()


def print_subheader(text: str) -> None:
    """Print a subsection header."""
    print()
    print_colored(f"--- {text} ---", Color.YELLOW)
    print()


def print_success(message: str) -> None:
    """Print a success message."""
    print_colored(f"[OK] {message}", Color.GREEN)


def print_warning(message: str) -> None:
    """Print a warning message."""
    print_colored(f"[!] {message}", Color.YELLOW)


def print_stat(label: str, value: int | str, color: Color = Color.WHITE) -> None:
    """Print a statistic with label."""
    print(f"  {Color.DIM.value}{label}:{Color.RESET.value} "
          f"{color.value}{value}{Color.RESET.value}")


# =============================================================================
# RULE EXTRACTION
# =============================================================================

def get_implemented_rules(rules_dir: Path) -> tuple[set[str], set[str]]:
    """Extract rule names and aliases from Dart files.

    Returns:
        Tuple of (rule_names, aliases)
    """
    rules: set[str] = set()
    aliases: set[str] = set()

    name_pattern = re.compile(r"name:\s*'([a-z_]+)'")
    # Match: /// Alias: name1, name2, name3
    alias_pattern = re.compile(r"///\s*Alias:\s*([a-z_,\s]+)")

    for dart_file in rules_dir.glob("*.dart"):
        content = dart_file.read_text(encoding="utf-8")
        rules.update(name_pattern.findall(content))

        # Extract aliases
        for match in alias_pattern.findall(content):
            for alias in match.split(","):
                alias = alias.strip()
                if alias:
                    aliases.add(alias)

    return rules, aliases


def get_roadmap_rules(roadmap_path: Path) -> set[str]:
    """Extract rule names from ROADMAP.md table entries."""
    rules: set[str] = set()
    pattern = re.compile(r"^\|\s*`([a-z_]+)`\s*\|", re.MULTILINE)

    content = roadmap_path.read_text(encoding="utf-8")
    rules.update(pattern.findall(content))

    return rules


# =============================================================================
# MAIN
# =============================================================================

def main() -> int:
    """Main entry point."""
    enable_ansi_support()
    show_saropa_logo()
    print_header("SAROPA LINTS RULE AUDIT")

    script_dir = Path(__file__).parent
    project_root = script_dir.parent
    rules_dir = project_root / "lib" / "src" / "rules"
    roadmap_path = project_root / "ROADMAP.md"

    # Extract rules
    print_subheader("Extracting Rules")
    rules, aliases = get_implemented_rules(rules_dir)
    implemented = rules | aliases
    roadmap = get_roadmap_rules(roadmap_path)

    # Print statistics
    print_stat("Implemented rules", len(rules), Color.GREEN)
    print_stat("Documented aliases", len(aliases), Color.CYAN)
    print_stat("ROADMAP entries", len(roadmap), Color.YELLOW)
    print()

    # Find exact matches (implemented or aliased AND in roadmap)
    duplicates = implemented & roadmap

    if duplicates:
        print_subheader(f"Rules to Remove from ROADMAP ({len(duplicates)})")
        print_warning("These rules are already implemented or aliased:")
        print()
        for rule in sorted(duplicates):
            source = "alias" if rule in aliases else "rule"
            color = Color.CYAN if source == "alias" else Color.GREEN
            print(f"    {color.value}{rule}{Color.RESET.value}"
                  f"  {Color.DIM.value}({source}){Color.RESET.value}")
    else:
        print_subheader("Duplicates Check")
        print_success("No duplicates found - ROADMAP is clean!")

    # Find close matches using common naming variations:
    # - Underscore differences (avoid_set_state vs avoid_setstate)
    # - Singular/plural differences (method vs methods)
    remaining = roadmap - duplicates
    near_matches: list[tuple[str, str]] = []

    for roadmap_rule in sorted(remaining):
        for impl_rule in implemented:
            if (roadmap_rule.replace("_", "") == impl_rule.replace("_", "") or
                roadmap_rule + "s" == impl_rule or
                roadmap_rule == impl_rule + "s"):
                near_matches.append((roadmap_rule, impl_rule))
                break  # Found match, skip remaining impl_rules

    if near_matches:
        print_subheader(f"Possible Near-Matches ({len(near_matches)})")
        print_warning("These may need aliases added:")
        print()
        for roadmap_rule, impl_rule in near_matches:
            print(f"    {Color.YELLOW.value}{roadmap_rule}{Color.RESET.value}"
                  f"  {Color.DIM.value}→{Color.RESET.value}  "
                  f"{Color.GREEN.value}{impl_rule}{Color.RESET.value}")

    # Summary
    print_header("SUMMARY")
    total_coverage = len(rules) + len(aliases)
    print_stat("Total rule coverage", total_coverage, Color.GREEN)
    print_stat("Remaining ROADMAP items", len(remaining), Color.YELLOW)

    if duplicates:
        print()
        print_colored(
            f"  Action: Remove {len(duplicates)} entries from ROADMAP.md",
            Color.RED
        )
        return 1  # Indicate duplicates found

    print()
    print_success("All clear!")
    return 0


if __name__ == "__main__":
    sys.exit(main())
