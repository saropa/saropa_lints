#!/usr/bin/env python3
"""
Check a proposed rule name against the core Dart/Flutter analyzer lint
namespace before any implementation work begins.

The publish audit's Check 8 (scripts/modules/_tier_integrity.py) blocks a
release when an implemented rule name collides with a core Dart/Flutter
lint. That gate has now caught the same mistake three times in three days
(2026-09-02 batch, 2026-09-03, 2026-09-04) — always at publish time, after
the rule, its tests, and its fixture were already written. This script lets
a rule author check the name for free, in one second, before writing any
code, so a collision means renaming a string in a proposal doc instead of
renaming files across lib/, test/, and example/.

Usage:
    python scripts/check_rule_name.py <proposed_name> [<proposed_name> ...]

Exit code 0 if every name is clear, 1 if any collides.

Version:   1.0
Author:    Saropa
Copyright: (c) 2026 Saropa
"""

from __future__ import annotations

import sys
from pathlib import Path

# CORE_DART_LINT_NAMES is the single source of truth for the core lint
# namespace; imported rather than duplicated so this check can never drift
# from the same gate that runs at publish time. Mirrors publish.py's
# sys.path setup so `scripts.modules._tier_integrity`'s own absolute
# imports resolve when this script is run directly.
_scripts_parent = str(Path(__file__).resolve().parent.parent)
if _scripts_parent not in sys.path:
    sys.path.insert(0, _scripts_parent)
from scripts.modules._tier_integrity import CORE_DART_LINT_NAMES  # noqa: E402


def main() -> None:
    """Entry point."""
    if len(sys.argv) < 2:
        print(f"Usage: {sys.argv[0]} <proposed_rule_name> [<proposed_rule_name> ...]")
        sys.exit(1)

    proposed_names = sys.argv[1:]
    any_collision = False

    for name in proposed_names:
        if name in CORE_DART_LINT_NAMES:
            any_collision = True
            print(
                f"  COLLISION  {name!r} is a core Dart/Flutter analyzer lint "
                f"name — do not implement a saropa_lints rule under this "
                f"exact name. Pick a different name, or if the rule is "
                f"intentionally an enhanced version of the core lint, use "
                f"the project's semantic-suffix convention "
                f"(e.g. {name}_extended, {name}_strict, {name}_with_fix)."
            )
        else:
            print(f"  clear      {name!r} does not collide with a core lint name.")

    if any_collision:
        sys.exit(1)


if __name__ == "__main__":
    main()
