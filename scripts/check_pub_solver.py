#!/usr/bin/env python3
"""Pub solver test for plans/PLAN_analyzer_12_to_13_14_upgrade.md section 12 items 2-3.

Creates scratch projects and asserts how `dart pub` resolves saropa_lints:
  1. analyzer held at 12: `dart pub add saropa_lints` resolves to a 16.x release.
  2. analyzer held at 12: `saropa_lints: ^16.7.0` resolves and stays on 16.x.
  3. analyzer held at 12: `saropa_lints: ^17.0.0` fails with a solver message.
  4. meta pinned to 1.18.0: `saropa_lints: ^16.7.0` resolves.

Needs network and `dart` on PATH. Exit 0 if all assertions hold.
Check 3 only holds while no 17.x is published; after the major ships, update
it to expect a clear failure for the held-at-12 project (not a resolve).
Usage: python3 scripts/check_pub_solver.py
"""
import re
import subprocess
import sys
import tempfile
from pathlib import Path

HEADER = "name: scratch\nenvironment:\n  sdk: '>=3.9.0 <4.0.0'\n"


def run(cmd, cwd):
    return subprocess.run(cmd, cwd=cwd, capture_output=True, text=True, timeout=300)


def lock_version(proj, pkg):
    lock = proj / "pubspec.lock"
    if not lock.exists():
        return None
    m = re.search(rf'^  {pkg}:\n(?:    .*\n)*?    version: "([^"]+)"',
                  lock.read_text(), re.M)
    return m.group(1) if m else None


def project(root, name, body):
    d = root / name
    d.mkdir()
    (d / "pubspec.yaml").write_text(HEADER + body)
    return d


def main():
    failures = []

    def check(label, ok, detail=""):
        print(f"{'PASS' if ok else 'FAIL'}: {label} {detail}")
        if not ok:
            failures.append(label)

    with tempfile.TemporaryDirectory() as t:
        root = Path(t)
        held = "dependencies:\n  analyzer: ^12.1.0\n"

        p = project(root, "add", held)
        r = run(["dart", "pub", "add", "saropa_lints"], p)
        v = lock_version(p, "saropa_lints")
        check("pub add resolves to 16.x with analyzer 12",
              r.returncode == 0 and bool(v) and v.startswith("16."), f"(got {v})")

        p = project(root, "caret16", held + "  saropa_lints: ^16.7.0\n")
        r = run(["dart", "pub", "get"], p)
        v = lock_version(p, "saropa_lints")
        check("^16.7.0 stays on 16.x",
              r.returncode == 0 and bool(v) and v.startswith("16."), f"(got {v})")

        p = project(root, "caret17", held + "  saropa_lints: ^17.0.0\n")
        r = run(["dart", "pub", "get"], p)
        out = r.stdout + r.stderr
        check("^17 fails with solver message",
              r.returncode != 0 and "saropa_lints" in out)

        p = project(root, "meta", "dependencies:\n  meta: 1.18.0\n  saropa_lints: ^16.7.0\n")
        r = run(["dart", "pub", "get"], p)
        v = lock_version(p, "saropa_lints")
        check("meta 1.18.0 resolves 16.x",
              r.returncode == 0 and bool(v) and v.startswith("16."), f"(got {v})")

    print("FAILED: " + ", ".join(failures) if failures else "all solver checks passed")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
