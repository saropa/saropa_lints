"""Find duplicated or suspicious text in LintCode problemMessage/correctionMessage.

Used by the publish script's pre-publish audit (Step 1) as an informational
check. Run standalone: python -m scripts.modules._duplicated_messages

Version:   1.0
Author:    Saropa
Copyright: (c) 2025-2026 Saropa
"""

from __future__ import annotations

import re
import sys
from dataclasses import dataclass, field
from pathlib import Path

from scripts.modules._utils import (
    Color,
    get_project_dir,
    print_colored,
    print_header,
    print_info,
    print_subheader,
)

VERIFY_PHRASE = (
    "Verify the change works correctly with existing tests "
    "and add coverage for the new behavior"
)

# (line_no, field_name, full_message, parts)
_MessageEntry = tuple[int, str, str, list[str]]


def extract_message_strings(content: str) -> list[_MessageEntry]:
    """Extract (line_no, field, full_message, parts) for problemMessage and correctionMessage."""
    results: list[_MessageEntry] = []
    pattern = re.compile(
        r"(problemMessage|correctionMessage)\s*:\s*\n\s*"
        r"((?:'[^']*'(?:\s*\n\s*'[^']*')*))",
        re.MULTILINE,
    )
    for m in pattern.finditer(content):
        field = m.group(1)
        raw = m.group(2)
        line_no = content[: m.start()].count("\n") + 1
        parts = re.findall(r"'([^']*)'", raw)
        full = "".join(parts)
        results.append((line_no, field, full, parts))
    return results


@dataclass
class DuplicatedMessagesResult:
    """Result of scanning rule files for duplicated/suspicious message text."""

    verify_twice: list[tuple[str, int, str, str]] = field(default_factory=list)
    dup_inline: list[tuple[str, int, str, str]] = field(default_factory=list)
    dup_multiline: list[tuple[str, int, str, str, str]] = field(default_factory=list)
    missing_space: list[tuple[str, int]] = field(default_factory=list)

    @property
    def has_issues(self) -> bool:
        return bool(
            self.verify_twice
            or self.dup_inline
            or self.dup_multiline
            or self.missing_space
        )

    def total_count(self) -> int:
        return (
            len(self.verify_twice)
            + len(self.dup_inline)
            + len(self.dup_multiline)
            + len(self.missing_space)
        )


def find_duplicated_messages(rules_dir: Path) -> DuplicatedMessagesResult:
    """Scan all rule Dart files for message duplications and suspicious patterns."""
    result = DuplicatedMessagesResult()
    seen_inline: set[tuple[str, int]] = set()

    for path in sorted(rules_dir.rglob("*.dart")):
        if path.name == "all_rules.dart":
            continue
        text = path.read_text(encoding="utf-8")
        rel = path.relative_to(rules_dir)
        rel_str = str(rel)

        for line_no, field, full, parts in extract_message_strings(text):
            if full.count(VERIFY_PHRASE) >= 2:
                result.verify_twice.append(
                    (rel_str, line_no, field, full[:120] + "...")
                )

            for length in (80, 60, 40):
                found = False
                for i in range(len(full) - length):
                    sub = full[i : i + length]
                    if full.count(sub) >= 2 and " " in sub:
                        key = (rel_str, line_no)
                        if key not in seen_inline:
                            seen_inline.add(key)
                            result.dup_inline.append(
                                (rel_str, line_no, field, sub[:60] + "...")
                            )
                        found = True
                        break
                if found:
                    break

            if len(parts) >= 2:
                first = parts[0].strip()
                second = parts[1].strip()
                if len(second) >= 15 and (second in first or first in second):
                    result.dup_multiline.append(
                        (rel_str, line_no, field, first[:50], second[:50])
                    )
                if first.endswith("behavior.") and second.startswith("Disable"):
                    result.missing_space.append((rel_str, line_no))

    return result


def print_duplicated_messages_report(
    result: DuplicatedMessagesResult,
    *,
    verbose: bool = True,
) -> None:
    """Print a human-readable report of duplicated/suspicious messages."""
    if not result.has_issues:
        print_info("No duplicated or suspicious LintCode message text found.")
        return

    print_subheader("Duplicated / suspicious message text")
    if result.verify_twice:
        print_colored(
            "  VERIFY_PHRASE appears twice in one message:",
            Color.YELLOW,
        )
        for rel, line_no, field, snippet in result.verify_twice[:15]:
            print_colored(f"    {rel}:{line_no} ({field})", Color.DIM)
        if len(result.verify_twice) > 15:
            print_colored(
                f"    ... and {len(result.verify_twice) - 15} more",
                Color.DIM,
            )

    if result.dup_multiline:
        print_colored(
            "  Multiline: second part duplicates first (or vice versa):",
            Color.YELLOW,
        )
        for item in result.dup_multiline[:10]:
            rel, line_no, field, first, second = item
            print_colored(f"    {rel}:{line_no} ({field})", Color.DIM)
        if len(result.dup_multiline) > 10:
            print_colored(
                f"    ... and {len(result.dup_multiline) - 10} more",
                Color.DIM,
            )

    if result.missing_space:
        print_colored(
            "  Missing space (behavior.'Disable):",
            Color.YELLOW,
        )
        for rel, line_no in result.missing_space[:10]:
            print_colored(f"    {rel}:{line_no}", Color.DIM)
        if len(result.missing_space) > 10:
            print_colored(
                f"    ... and {len(result.missing_space) - 10} more",
                Color.DIM,
            )

    if verbose and result.dup_inline:
        print_colored(
            "  Inline repeated phrase (40+ chars):",
            Color.YELLOW,
        )
        for rel, line_no, field, snippet in result.dup_inline[:10]:
            print_colored(f"    {rel}:{line_no} ({field}) ... {snippet}", Color.DIM)
        if len(result.dup_inline) > 10:
            print_colored(
                f"    ... and {len(result.dup_inline) - 10} more",
                Color.DIM,
            )


def main() -> int:
    """Standalone entry point. Returns 0 if no issues, 1 if issues found."""
    try:
        sys.stdout.reconfigure(encoding="utf-8")  # type: ignore[attr-defined]
    except (AttributeError, OSError):
        pass
    project_dir = get_project_dir()
    rules_dir = project_dir / "lib" / "src" / "rules"
    if not rules_dir.exists():
        print_colored("Rules directory not found.", Color.RED)
        return 1
    print_header("Duplicated LintCode messages")
    result = find_duplicated_messages(rules_dir)
    print_duplicated_messages_report(result, verbose=True)
    return 1 if result.has_issues else 0


if __name__ == "__main__":
    raise SystemExit(main())
