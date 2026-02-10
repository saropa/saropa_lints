#!/usr/bin/env python3
"""Run custom_lint on all example sub-packages.

Usage:
    python scripts/run_custom_lint_all.py          # Run all packages
    python scripts/run_custom_lint_all.py widgets   # Run specific package
    python scripts/run_custom_lint_all.py --list     # List available packages
"""

import subprocess
import sys
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parent.parent

PACKAGES = [
    "example",
    "example_core",
    "example_async",
    "example_widgets",
    "example_style",
    "example_packages",
    "example_platforms",
]


def run_package(name: str) -> bool:
    """Run dart pub get + dart run custom_lint for a package."""
    pkg_dir = PROJECT_ROOT / name
    if not (pkg_dir / "pubspec.yaml").exists():
        print(f"  SKIP: {name}/ (no pubspec.yaml)")
        return True

    print(f"\n{'=' * 60}")
    print(f"  {name}/")
    print(f"{'=' * 60}")

    result = subprocess.run(
        ["dart", "pub", "get"],
        cwd=pkg_dir,
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        print(f"  ERROR: dart pub get failed in {name}/")
        print(result.stderr)
        return False

    result = subprocess.run(
        ["dart", "run", "custom_lint"],
        cwd=pkg_dir,
    )
    return result.returncode == 0


def main() -> int:
    args = sys.argv[1:]

    if "--list" in args:
        print("Available packages:")
        for pkg in PACKAGES:
            exists = (PROJECT_ROOT / pkg / "pubspec.yaml").exists()
            status = "OK" if exists else "MISSING"
            print(f"  {pkg}/ [{status}]")
        return 0

    if args and args[0] != "--list":
        # Run specific package(s)
        targets = []
        for arg in args:
            name = arg if arg.startswith("example") else f"example_{arg}"
            if name in PACKAGES:
                targets.append(name)
            else:
                print(f"Unknown package: {arg}")
                print(f"Available: {', '.join(PACKAGES)}")
                return 1
    else:
        targets = PACKAGES

    print(f"Running custom_lint on {len(targets)} package(s)...")

    failed = []
    for pkg in targets:
        if not run_package(pkg):
            failed.append(pkg)

    print(f"\n{'=' * 60}")
    if failed:
        print(f"FAILED: {', '.join(failed)}")
        return 1
    print(f"All {len(targets)} package(s) passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
