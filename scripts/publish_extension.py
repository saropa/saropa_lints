#!/usr/bin/env python3
"""
Package and optionally publish the Saropa Lints VS Code extension.

Usage:
    python scripts/publish_extension.py              # Package .vsix only
    python scripts/publish_extension.py --publish   # Package + publish (vsce + ovsx if OVSX_PAT set)

Requires:
    - Node/npm in PATH
    - For publish: vsce login (VS Code Marketplace), OVSX_PAT env (Open VSX)
"""

from __future__ import annotations

import argparse
import os
import subprocess
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
EXTENSION_DIR = REPO_ROOT / "extension"


def run(cmd: list[str], cwd: Path) -> subprocess.CompletedProcess:
    return subprocess.run(cmd, cwd=str(cwd), capture_output=True, text=True, shell=True)


def main() -> int:
    ap = argparse.ArgumentParser(description="Package/publish Saropa Lints VS Code extension")
    ap.add_argument("--publish", action="store_true", help="Publish to Marketplace and Open VSX (if PAT set)")
    args = ap.parse_args()

    if not EXTENSION_DIR.is_dir():
        print("Extension directory not found:", EXTENSION_DIR, file=sys.stderr)
        return 1

    print("Compiling extension...")
    r = run(["npm", "run", "compile"], EXTENSION_DIR)
    if r.returncode != 0:
        print(r.stderr or r.stdout, file=sys.stderr)
        return 1

    print("Packaging .vsix...")
    r = run(["npx", "@vscode/vsce", "package", "--no-dependencies"], EXTENSION_DIR)
    if r.returncode != 0:
        print(r.stderr or r.stdout, file=sys.stderr)
        return 1

    vsix = next(EXTENSION_DIR.glob("*.vsix"), None)
    if not vsix:
        print("No .vsix produced", file=sys.stderr)
        return 1
    print("Packaged:", vsix.name)

    if args.publish:
        print("Publishing to VS Code Marketplace...")
        r = run(["npx", "@vscode/vsce", "publish", "--packagePath", str(vsix)], EXTENSION_DIR)
        if r.returncode != 0:
            print(r.stderr or r.stdout, file=sys.stderr)
            return 1
        print("Published to Marketplace.")

        ovsx_pat = os.environ.get("OVSX_PAT", "").strip()
        if ovsx_pat:
            print("Publishing to Open VSX...")
            r = run(["npx", "ovsx", "publish", str(vsix), "-p", ovsx_pat], EXTENSION_DIR)
            if r.returncode != 0:
                print(r.stderr or r.stdout, file=sys.stderr)
                return 1
            print("Published to Open VSX.")
        else:
            print("OVSX_PAT not set; skipping Open VSX. Set OVSX_PAT to publish to Cursor/VSCodium.")

    return 0


if __name__ == "__main__":
    sys.exit(main())
