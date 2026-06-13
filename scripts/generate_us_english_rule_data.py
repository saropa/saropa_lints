"""Generate the Dart UK->US spelling map consumed by the lint rule.

The `prefer_us_english_spelling` lint rule needs the same British->American
word list that the publish/commit-time audit uses. Rather than maintain two
lists that drift, this script emits a generated Dart file from the single
canonical `UK_TO_US` dictionary in `scripts/modules/_us_spelling.py`.

Run from the repository root:

    py -3 scripts/generate_us_english_rule_data.py

A parity test (`scripts/modules/tests/test_us_spelling.py`) regenerates the
content in memory and fails if the committed Dart file is stale, so a change
to `UK_TO_US` that is not regenerated cannot ship.

Version:   1.0
Author:    Saropa
Copyright: (c) 2026 Saropa
"""

from __future__ import annotations

import sys
from pathlib import Path

_REPO_ROOT = Path(__file__).resolve().parent.parent
if str(_REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(_REPO_ROOT))

from scripts.modules._us_spelling import UK_TO_US  # noqa: E402

# Relative to the repo root. Kept under lib/src/rules/data/ so the rule can
# import it with a short relative path.
_OUTPUT_REL = Path("lib/src/rules/data/uk_to_us_spellings.dart")


def render_dart() -> str:
    """Return the full Dart source for the generated spelling map.

    Keys are emitted lowercase and sorted so the output is deterministic and
    the parity test produces a stable diff. The rule lowercases each scanned
    word before lookup, so only lowercase keys are needed.
    """
    entries = sorted((uk.lower(), us.lower()) for uk, us in UK_TO_US.items())
    lines = [
        "// GENERATED FILE - DO NOT EDIT BY HAND.",
        "//",
        "// Source of truth: scripts/modules/_us_spelling.py (UK_TO_US).",
        "// Regenerate with: py -3 scripts/generate_us_english_rule_data.py",
        "// A parity test fails the build if this file drifts from the source.",
        "//",
        "// Consumed by the prefer_us_english_spelling lint rule. Keys are",
        "// lowercase British spellings; values are the US equivalent.",
        "library;",
        "",
        "/// British -> American spelling map for prefer_us_english_spelling.",
        "const Map<String, String> kUkToUsSpellings = <String, String>{",
    ]
    for uk, us in entries:
        lines.append(f"  '{uk}': '{us}',")
    lines.append("};")
    lines.append("")
    return "\n".join(lines)


def main() -> int:
    output_path = _REPO_ROOT / _OUTPUT_REL
    output_path.parent.mkdir(parents=True, exist_ok=True)
    content = render_dart()
    output_path.write_text(content, encoding="utf-8", newline="\n")
    print(f"Wrote {len(content.splitlines())} lines to {_OUTPUT_REL}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
