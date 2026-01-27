"""DX (Developer Experience) message quality audit.

Provides the ``RuleMessage`` data class with built-in DX scoring,
message extraction from rule source files, DX report printing, and
report export to Markdown.

Version:   3.0
Author:    Saropa
Copyright: (c) 2025-2026 Saropa
"""

from __future__ import annotations

import re
from datetime import datetime
from pathlib import Path

from scripts.modules._utils import (
    Color,
    print_colored,
    print_info,
    print_subheader,
)

# cspell:ignore refreshindicator searchdelegate didchangedependencies initstate


# =============================================================================
# DATA CLASS
# =============================================================================


class RuleMessage:
    """A rule's problem message with DX quality metadata."""

    def __init__(
        self,
        name: str,
        impact: str,
        problem_message: str,
        correction_message: str,
        file_path: Path,
    ):
        self.name = name
        self.impact = impact
        self.problem_message = problem_message
        self.correction_message = correction_message
        self.file_path = file_path
        self.dx_issues: list[str] = []
        self.dx_score: int = 100

    def audit_dx(self) -> None:
        """Audit this message against DX quality criteria.

        Scoring: start at 100, deduct for issues.
        See inline comments for each check and its penalty.
        """
        msg = self.problem_message.lower()
        content = re.sub(r"^\[[a-z0-9_]+\]\s*", "", self.problem_message)

        # --- Vague language (-20, skip for low-impact) ---
        # Low-impact rules are advisory by nature, so suggestive
        # phrasing like "consider" is appropriate and not penalised.
        if self.impact != "low":
            vague_patterns = [
                ("should be", "Vague 'should be' - state consequence"),
                ("should have", "Vague 'should have' - state consequence"),
                ("consider ", "Vague 'consider' - be direct"),
                ("may want to", "Vague 'may want' - be direct"),
                ("might cause", "Vague 'might' - state definite consequence"),
                ("could lead to", "Vague 'could' - state definite consequence"),
                ("is not recommended", "Passive 'not recommended' - say why"),
                ("prefer to", "Vague 'prefer to' - explain why"),
                ("it is better", "Vague 'better' - quantify the benefit"),
                ("for better", "Vague 'better' - quantify the benefit"),
                ("best practice", "Vague 'best practice' - explain the risk"),
                ("not ideal", "Vague 'not ideal' - state consequence"),
                ("suboptimal", "Vague 'suboptimal' - state consequence"),
            ]
            for pattern, issue in vague_patterns:
                if pattern in msg:
                    self.dx_issues.append(issue)
                    self.dx_score -= 20
                    break

        # --- Consequence check (-30 for critical/high) ---
        consequence_indicators = [
            "leak", "memory", "gc", "garbage", "retain", "hold",
            "crash", "error", "exception", "fail", "throw", "break",
            "invalid", "corrupt", "undefined",
            "slow", "performance", "expensive", "overhead", "block",
            "hang", "freeze", "jank", "stutter",
            "waste", "drain", "battery", "bandwidth", "resource",
            "expose", "vulnerable", "security", "attack", "inject",
            "breach",
            "stale", "inconsistent", "race", "deadlock", "lost",
            "user", "screen reader", "accessibility", "colorblind",
        ]
        has_consequence = any(w in msg for w in consequence_indicators)
        if not has_consequence and self.impact in ("critical", "high"):
            self.dx_issues.append("Missing consequence (why it matters)")
            self.dx_score -= 30

        # --- Specific type check (-15 for generic terms) ---
        if self.impact in ("critical", "high"):
            if "controller" in msg:
                specific = [
                    "animation", "text", "scroll", "page", "tab",
                    "video", "audio", "media", "stream", "timer",
                    "socket", "websocket", "navigation", "focus",
                    "draggable", "refreshindicator", "searchdelegate",
                ]
                if not any(t in msg for t in specific):
                    self.dx_issues.append(
                        "Generic 'controller' - specify type"
                    )
                    self.dx_score -= 15

            if (
                "widget" in msg
                and "stateful" not in msg
                and "stateless" not in msg
            ):
                if not any(
                    w in msg for w in ["build", "tree", "parent", "child"]
                ):
                    self.dx_issues.append("Generic 'widget' - add context")
                    self.dx_score -= 10

            if "resource" in msg and not any(
                r in msg
                for r in [
                    "file", "socket", "stream", "connection", "database",
                    "memory", "handle", "port", "channel",
                ]
            ):
                self.dx_issues.append("Generic 'resource' - specify type")
                self.dx_score -= 10

        # --- Avoid prefix (-10) ---
        if (
            "] Avoid" in self.problem_message
            or "] avoid" in self.problem_message
        ):
            self.dx_issues.append("Starts with 'Avoid' - state detected")
            self.dx_score -= 10

        # --- Message length (-25/-15) ---
        if len(content) < 180 and self.impact in ("critical", "high"):
            self.dx_issues.append(
                f"Too short ({len(content)} chars) - min 180"
            )
            self.dx_score -= 25
        elif len(content) < 150 and self.impact == "medium":
            self.dx_issues.append(
                f"Very short ({len(content)} chars) - min 150"
            )
            self.dx_score -= 15

        # --- Correction message length (-10/-5) ---
        corr_len = (
            len(self.correction_message.strip())
            if self.correction_message
            else 0
        )
        if self.impact == "critical":
            if corr_len < 100:
                self.dx_issues.append(
                    f"Correction too short ({corr_len} chars) - min 100"
                )
                self.dx_score -= 10
        else:
            if 0 < corr_len < 80:
                self.dx_issues.append(
                    f"Correction too short ({corr_len} chars) - min 80"
                )
                self.dx_score -= 5

        # --- AI copilot compat (-15/-10) ---
        if self.impact in ("critical", "high"):
            if "dispose" in self.name and "dispose" not in msg:
                self.dx_issues.append("Disposal rule missing 'dispose'")
                self.dx_score -= 15

            method_keywords = [
                "build", "initstate", "didchangedependencies",
            ]
            if any(k in self.name for k in method_keywords):
                if not any(k in msg for k in method_keywords):
                    self.dx_issues.append("Method rule should name method")
                    self.dx_score -= 10

        # --- Passive voice (-10) ---
        passive_patterns = [
            "is required", "are required", "must be used",
            "needs to be", "has to be",
        ]
        if any(p in msg for p in passive_patterns):
            self.dx_issues.append("Passive voice - use active")
            self.dx_score -= 10

        # --- Bonus: Standards reference (+10) ---
        standards = [
            "owasp", "wcag", "material", "guideline",
            "m1", "m2", "m3", "m4", "m5", "m6", "m7", "m8", "m9", "m10",
            "a01", "a02", "a03", "a04", "a05", "2.4", "1.4",
        ]
        if any(s in msg for s in standards):
            self.dx_score = min(100, self.dx_score + 10)

        # --- Bonus: Specific error message (+5) ---
        if "'" in self.problem_message and "error" in msg:
            self.dx_score = min(100, self.dx_score + 5)

        self.dx_score = max(0, self.dx_score)


# =============================================================================
# EXTRACTION
# =============================================================================


def extract_rule_messages(rules_dir: Path) -> list[RuleMessage]:
    """Extract all rule messages with their impact levels.

    Uses class-scoped searching to correctly associate each LintCode
    definition with the impact getter from the same class.

    Previous approach searched backward from each ``_code`` definition
    for the nearest ``LintImpact`` getter. This usually worked because
    the impact getter appears before ``_code`` within a class. However,
    it could cross into a previous class when:

      - The ``_code`` field used a variant name (``_codeField``,
        ``_codeMethod``) that the old regex didn't match, causing
        the search to skip to the next class's ``_code`` and find
        the wrong impact.
      - A class had no impact getter (defaults to medium), but the
        backward search found a previous class's impact instead.

    The fix: find class boundaries first, extract impact and LintCode
    definitions within each class body independently. This mirrors
    the approach in ``get_owasp_coverage()``.

    NOTE: ``_code\\w*`` matches variant field names like ``_codeField``
    and ``_codeMethod`` (e.g. PreferWidgetPrivateMembersRule). Rules
    with multiple LintCode variants sharing the same ``name:`` value
    produce one entry per variant — each message is audited separately.
    """
    messages: list[RuleMessage] = []

    class_pattern = re.compile(
        r"class\s+\w+\s+extends\s+\w+LintRule"
    )
    # NOTE: _code\w* matches _code, _codeField, _codeMethod, etc.
    lint_code_pattern = re.compile(
        r"static const (?:LintCode )?_code\w*\s*=\s*LintCode\(\s*"
        r"name:\s*'([a-z0-9_]+)',\s*"
        r"problemMessage:\s*"
        r"(?:'([^']*)'|\"([^\"]*)\"),\s*"
        r"(?:correctionMessage:\s*(?:'([^']*)'|\"([^\"]*)\"),?\s*)?"
        r"[^)]*\);",
        re.DOTALL,
    )
    impact_pattern = re.compile(
        r"LintImpact get impact => LintImpact\.(\w+);"
    )

    for dart_file in sorted(rules_dir.glob("*.dart")):
        if dart_file.name == "all_rules.dart":
            continue
        content = dart_file.read_text(encoding="utf-8")

        # Find class boundaries
        class_starts = [m.start() for m in class_pattern.finditer(content)]

        for idx, start in enumerate(class_starts):
            end = (
                class_starts[idx + 1]
                if idx + 1 < len(class_starts)
                else len(content)
            )
            class_body = content[start:end]

            # Find impact for this class (default to medium)
            impact_match = impact_pattern.search(class_body)
            impact = impact_match.group(1) if impact_match else "medium"

            # Find all LintCode definitions in this class
            for match in lint_code_pattern.finditer(class_body):
                name = match.group(1)
                problem_msg = match.group(2) or match.group(3) or ""
                correction_msg = match.group(4) or match.group(5) or ""

                rule_msg = RuleMessage(
                    name=name,
                    impact=impact,
                    problem_message=problem_msg,
                    correction_message=correction_msg,
                    file_path=dart_file,
                )
                rule_msg.audit_dx()
                messages.append(rule_msg)

    return messages


# =============================================================================
# PRINT
# =============================================================================


def print_dx_audit_report(
    messages: list[RuleMessage], show_all: bool = False
) -> int:
    """Print DX audit report. Returns count of rules needing improvement."""
    all_by_impact: dict[str, list[RuleMessage]] = {
        "critical": [], "high": [], "medium": [], "low": [],
    }
    needs_work_by_impact: dict[str, list[RuleMessage]] = {
        "critical": [], "high": [], "medium": [], "low": [],
    }

    for m in messages:
        if m.impact in all_by_impact:
            all_by_impact[m.impact].append(m)
            if m.dx_issues:
                needs_work_by_impact[m.impact].append(m)

    needs_work = [
        m
        for m in messages
        if m.impact in ("critical", "high") and m.dx_issues
    ]
    impact_priority = {"critical": 0, "high": 1}
    needs_work.sort(
        key=lambda m: (impact_priority.get(m.impact, 99), m.dx_score)
    )

    total_needs_work = sum(len(v) for v in needs_work_by_impact.values())
    print_subheader(f"DX Message Quality ({total_needs_work} total issues)")

    impact_colors = {
        "critical": Color.RED,
        "high": Color.YELLOW,
        "medium": Color.WHITE,
        "low": Color.DIM,
    }

    for impact in ["critical", "high", "medium", "low"]:
        total = len(all_by_impact[impact])
        issues = len(needs_work_by_impact[impact])
        passing = total - issues
        pct = (passing / total * 100) if total > 0 else 100
        color = impact_colors[impact]
        pct_color = (
            Color.GREEN
            if pct >= 80
            else Color.YELLOW
            if pct >= 50
            else Color.RED
        )
        print(
            f"    {color.value}{impact.capitalize():<10}{Color.RESET.value} "
            f"{passing:>3}/{total:<3} passing  "
            f"{pct_color.value}({pct:>5.1f}%){Color.RESET.value}"
        )

    limit = 25 if not show_all else len(needs_work)
    shown = needs_work[:limit]

    if shown:
        print()
        print_colored("    Worst offenders (critical/high):", Color.DIM)
        for m in shown:
            if m.impact == "critical":
                impact_color = Color.RED
            elif m.impact == "high":
                impact_color = Color.YELLOW
            else:
                impact_color = Color.WHITE
            issue_preview = m.dx_issues[0] if m.dx_issues else ""
            print(
                f"      {impact_color.value}{m.dx_score:>3}"
                f"{Color.RESET.value} "
                f"{m.name:<40} "
                f"{Color.DIM.value}{issue_preview[:30]}{Color.RESET.value}"
            )

        if len(needs_work) > limit:
            print()
            print_info(
                f"{len(needs_work) - limit} more in report "
                f"(--dx-all to show all)"
            )

    return len(needs_work)


# =============================================================================
# REPORT EXPORT
# =============================================================================


def export_dx_report(
    messages: list[RuleMessage], output_dir: Path
) -> Path:
    """Export DX audit report to timestamped markdown file."""
    needs_work = [
        m
        for m in messages
        if m.impact in ("critical", "high") and m.dx_issues
    ]
    impact_order = {"critical": 0, "high": 1, "medium": 2, "low": 3}
    needs_work.sort(
        key=lambda m: (m.dx_score, impact_order.get(m.impact, 4))
    )

    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    output_path = output_dir / f"{timestamp}_dx_audit.md"

    by_file: dict[str, list[RuleMessage]] = {}
    for m in needs_work:
        file_key = m.file_path.name
        by_file.setdefault(file_key, []).append(m)

    lines: list[str] = []
    lines.append("# DX Message Quality Audit Report")
    lines.append("")
    lines.append(
        f"Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}"
    )
    lines.append("")
    lines.append("## Summary")
    lines.append("")
    critical_count = sum(1 for m in needs_work if m.impact == "critical")
    high_count = sum(1 for m in needs_work if m.impact == "high")
    lines.append(f"- **Total rules needing work:** {len(needs_work)}")
    lines.append(f"- **Critical impact:** {critical_count}")
    lines.append(f"- **High impact:** {high_count}")
    lines.append(f"- **Files affected:** {len(by_file)}")
    lines.append("")

    # Worst offenders
    worst = [m for m in needs_work if m.dx_score < 50]
    if worst:
        lines.append("## Priority: Worst Offenders (Score < 50)")
        lines.append("")
        lines.append(
            "| Rule | Impact | Score | Issues | Current Message |"
        )
        lines.append("|------|--------|-------|--------|-----------------|")
        for m in worst[:30]:
            issues = ", ".join(m.dx_issues[:2])
            msg_preview = m.problem_message[:60].replace("|", "\\|")
            if len(m.problem_message) > 60:
                msg_preview += "..."
            lines.append(
                f"| `{m.name}` | {m.impact} | {m.dx_score} "
                f"| {issues} | {msg_preview} |"
            )
        lines.append("")

    # By-file breakdown
    lines.append("## Rules by File")
    lines.append("")
    for file_name in sorted(by_file.keys()):
        file_rules = by_file[file_name]
        lines.append(f"### {file_name} ({len(file_rules)} rules)")
        lines.append("")
        lines.append("| Rule | Score | Issues |")
        lines.append("|------|-------|--------|")
        for m in file_rules:
            issues = ", ".join(m.dx_issues[:2])
            lines.append(f"| `{m.name}` | {m.dx_score} | {issues} |")
        lines.append("")

    output_path.write_text("\n".join(lines), encoding="utf-8")
    return output_path
