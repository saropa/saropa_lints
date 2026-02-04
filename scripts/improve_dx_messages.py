#!/usr/bin/env python3
"""Auto-improve DX message quality for lint rules.

Reads DartDoc comments to expand short messages, fix vague language,
and add missing consequences. Always runs analysis first, then
prompts to apply changes interactively.

Usage:
    python scripts/improve_dx_messages.py           # Analyze + prompt
    python scripts/improve_dx_messages.py --apply   # Apply without prompt (CI)

Version:   1.0
Author:    Saropa
Copyright: (c) 2025-2026 Saropa

Changelog:
    1.0 - Colored output, saropa logo, interactive apply prompt.
          Integrated shared _utils.py module.
    0.1 - Initial version with plain output and --apply flag.

Run from project root directory.
"""

from __future__ import annotations

import re
import sys
from dataclasses import dataclass, field
from datetime import datetime
from pathlib import Path

# Allow running as `python scripts/improve_dx_messages.py`
_scripts_parent = str(Path(__file__).resolve().parent.parent)
if _scripts_parent not in sys.path:
    sys.path.insert(0, _scripts_parent)

SCRIPT_VERSION = "1.0"

from scripts.modules._utils import (  # noqa: E402
    Color,
    enable_ansi_support,
    get_project_dir,
    get_rules_dir,
    print_colored,
    print_header,
    print_info,
    print_section,
    print_stat,
    print_stat_bar,
    print_success,
    print_warning,
    show_saropa_logo,
)

# ─────────────────────────────────────────────────────────────────
# Paths and thresholds
# ─────────────────────────────────────────────────────────────────

PROJECT_ROOT = get_project_dir()
RULES_DIR = get_rules_dir()
REPORTS_DIR = PROJECT_ROOT / "reports"

# Must match _audit_dx.py thresholds
MIN_PROBLEM = {
    "critical": 180, "high": 180, "medium": 150,
    "low": 100, "opinionated": 100,
}
MIN_CORRECTION = {
    "critical": 100, "high": 80, "medium": 80,
    "low": 80, "opinionated": 80,
}

# ─────────────────────────────────────────────────────────────────
# Regex patterns (from _audit_dx.py)
# ─────────────────────────────────────────────────────────────────

CLASS_RE = re.compile(r"class\s+\w+\s+extends\s+\w+LintRule")
IMPACT_RE = re.compile(r"LintImpact get impact => LintImpact\.(\w+);")
LINTCODE_RE = re.compile(
    r"static const (?:LintCode )?_code\w*\s*=\s*LintCode\(\s*"
    r"name:\s*'([a-z0-9_]+)',\s*"
    r"problemMessage:\s*"
    r"(?:'((?:[^'\\]|\\.)*)'|\"((?:[^\"\\]|\\.)*)\"),\s*"
    r"(?:correctionMessage:\s*"
    r"(?:'((?:[^'\\]|\\.)*)'|\"((?:[^\"\\]|\\.)*)\"),?\s*)?"
    r"[^)]*\);",
    re.DOTALL,
)

# ─────────────────────────────────────────────────────────────────
# Vague language
# ─────────────────────────────────────────────────────────────────

VAGUE_CHECKS = [
    ("should be", "Vague 'should be'"),
    ("should have", "Vague 'should have'"),
    ("consider ", "Vague 'consider'"),
    ("may want to", "Vague 'may want'"),
    ("might cause", "Vague 'might'"),
    ("could lead to", "Vague 'could'"),
    ("is not recommended", "Passive 'not recommended'"),
    ("prefer to", "Vague 'prefer to'"),
    ("it is better", "Vague 'better'"),
    ("for better", "Vague 'better'"),
    ("best practice", "Vague 'best practice'"),
    ("not ideal", "Vague 'not ideal'"),
    ("suboptimal", "Vague 'suboptimal'"),
]

VAGUE_FIXES: list[tuple[str, str]] = [
    # "Consider [verb]ing" → direct command (only gerund forms)
    (r"(?i)\. Consider using\b", ". Use"),
    (r"(?i)\. Consider adding\b", ". Add"),
    (r"(?i)\. Consider wrapping\b", ". Wrap"),
    (r"(?i)\. Consider replacing\b", ". Replace"),
    (r"(?i)\. Consider moving\b", ". Move"),
    (r"(?i)\. Consider extracting\b", ". Extract"),
    (r"(?i)\. Consider grouping\b", ". Group"),
    (r"(?i)\. Consider breaking\b", ". Break"),
    (r"(?i)\. Consider splitting\b", ". Split"),
    (r"(?i)\bConsider using\b", "Use"),
    (r"(?i)\bConsider adding\b", "Add"),
    (r"(?i)\bConsider wrapping\b", "Wrap"),
    (r"(?i)\bConsider replacing\b", "Replace"),
    (r"(?i)\bConsider moving\b", "Move"),
    (r"(?i)\bConsider extracting\b", "Extract"),
    (r"(?i)\bConsider grouping\b", "Group"),
    (r"(?i)\bConsider breaking\b", "Break"),
    (r"(?i)\bConsider splitting\b", "Split"),
    # "Consider [noun]" → "Prefer [noun]" (safe for noun phrases)
    (r"(?i)\bConsider\b", "Prefer"),
    # "should be/have" → "must be/have" (always grammatical)
    (r"(?i)\bshould be\b", "must be"),
    (r"(?i)\bshould have\b", "must have"),
    (r"(?i)\bshould not\b", "must not"),
    # Other vague patterns
    (r"(?i)\bfor better\b", "to improve"),
    (r"(?i)\bit is better to\b", ""),
    (r"(?i)\bbest practice\b", "established convention"),
    (r"(?i)\bnot ideal\b", "problematic"),
    (r"(?i)\bsuboptimal\b", "inefficient"),
]

# ─────────────────────────────────────────────────────────────────
# Consequence indicators (from _audit_dx.py)
# ─────────────────────────────────────────────────────────────────

CONSEQUENCE_WORDS = frozenset([
    "leak", "memory", "gc", "garbage", "retain", "hold",
    "crash", "error", "exception", "fail", "throw", "break",
    "invalid", "corrupt", "undefined",
    "slow", "performance", "expensive", "overhead", "block",
    "hang", "freeze", "jank", "stutter",
    "waste", "drain", "battery", "bandwidth", "resource",
    "expose", "vulnerable", "security", "attack", "inject", "breach",
    "stale", "inconsistent", "race", "deadlock", "lost",
    "user", "screen reader", "accessibility", "colorblind",
])

# ─────────────────────────────────────────────────────────────────
# Category-specific consequences (keyed by rule file stem)
# ─────────────────────────────────────────────────────────────────

CONSEQUENCES: dict[str, str] = {
    "security": (
        "This creates a security vulnerability that attackers can "
        "exploit to compromise user data or application integrity."
    ),
    "performance": (
        "This introduces unnecessary computational overhead that "
        "degrades responsiveness and increases battery drain on mobile."
    ),
    "accessibility": (
        "This creates barriers for users with disabilities who rely "
        "on assistive technologies such as screen readers or voice nav."
    ),
    "memory_management": (
        "Unreleased memory grows over time, increasing garbage "
        "collection pressure and risking out-of-memory crashes."
    ),
    "disposal": (
        "Failing to release this resource causes memory leaks and "
        "prevents the system from reclaiming native resources."
    ),
    "animation": (
        "This causes animation frame drops and visual stuttering "
        "that degrade the user experience on lower-end devices."
    ),
    "navigation": (
        "This causes navigation state inconsistencies that can "
        "leave users stuck or lose their navigation history."
    ),
    "async": (
        "This introduces concurrency issues that can cause race "
        "conditions, stale data, or unhandled async errors."
    ),
    "lifecycle": (
        "This violates the widget lifecycle contract, risking "
        "state errors, null references, or silent data loss."
    ),
    "widget_lifecycle": (
        "This violates the widget lifecycle, risking "
        "setState-after-dispose errors or silent state corruption."
    ),
    "build_method": (
        "This increases build() cost, causing unnecessary widget "
        "rebuilds that degrade scroll performance."
    ),
    "error_handling": (
        "Swallowed or mishandled errors hide failures, making bugs "
        "harder to diagnose and potentially corrupting state."
    ),
    "state_management": (
        "This causes state synchronization issues where the UI "
        "displays stale or incorrect data to the user."
    ),
    "test": (
        "This reduces test maintainability and makes it harder to "
        "identify which behavior failed when tests break."
    ),
    "testing_best_practices": (
        "This weakens test quality, making failures harder to "
        "diagnose and reducing confidence in the test suite."
    ),
    "widget_layout": (
        "This layout configuration can trigger RenderFlex overflow "
        "errors or unexpected visual behavior at runtime."
    ),
    "widget_patterns": (
        "This widget pattern increases complexity and makes the "
        "widget tree harder to maintain and debug."
    ),
    "collection": (
        "This collection operation has unexpected behavior or "
        "performance characteristics that can cause subtle bugs."
    ),
    "api_network": (
        "This network pattern wastes bandwidth and server resources, "
        "increasing latency and data costs for users."
    ),
    "connectivity": (
        "This can cause the app to hang or behave unpredictably "
        "when network conditions change."
    ),
    "forms": (
        "This form handling issue can cause data loss, validation "
        "bypasses, or a confusing submission experience."
    ),
    "type_safety": (
        "This weakens type safety, allowing errors to reach runtime "
        "where they crash instead of being caught at compile time."
    ),
    "internationalization": (
        "This prevents proper localization, causing text to display "
        "incorrectly for users in non-English locales."
    ),
    "debug": (
        "This debug artifact executes in production, potentially "
        "exposing internal state or degrading performance."
    ),
    "context": (
        "Using BuildContext after an async gap can cause a "
        "deactivated-widget-ancestor error that crashes the app."
    ),
    "control_flow": (
        "This control flow pattern increases the risk of logic "
        "errors and makes the code harder to follow."
    ),
    "dialog_snackbar": (
        "This can cause poor UX through unexpected dismissal, "
        "dialog stacking, or inaccessibility."
    ),
    "image": (
        "This image handling causes excessive memory usage, "
        "visual artifacts, or slow load times."
    ),
    "scroll": (
        "This scroll configuration can cause janky scrolling, "
        "incorrect positions, or layout overflow errors."
    ),
    "crypto": (
        "This weakens data protection and may not meet "
        "industry security standards."
    ),
    "money": (
        "This monetary calculation can produce rounding errors "
        "that accumulate, causing financial discrepancies."
    ),
    "exception": (
        "This exception handling can cause information loss "
        "or unintended control flow behavior."
    ),
    "class_constructor": (
        "This class design reduces clarity and can lead to "
        "incorrect object initialization."
    ),
    "code_quality": (
        "This pattern reduces maintainability and increases "
        "the likelihood of bugs during future changes."
    ),
    "complexity": (
        "This excessive complexity makes the code harder "
        "to understand, test, and maintain."
    ),
    "unnecessary_code": (
        "This unnecessary code increases cognitive load "
        "without providing functional benefit."
    ),
    "dependency_injection": (
        "This DI pattern reduces testability and creates "
        "tight coupling between components."
    ),
    "documentation": (
        "Missing documentation makes the API harder to use "
        "correctly and increases onboarding time."
    ),
    "file_handling": (
        "This file handling can cause data corruption, "
        "resource leaks, or permission errors."
    ),
    "config": (
        "This configuration issue can cause unexpected "
        "behavior across environments or platforms."
    ),
    "platform": (
        "This platform issue can cause crashes or degraded "
        "behavior on certain devices or OS versions."
    ),
    "naming_style": (
        "This naming violation reduces readability and makes "
        "the codebase harder for teams to navigate."
    ),
    "theming": (
        "This theming issue causes visual inconsistencies "
        "and makes the design system harder to maintain."
    ),
    "db_yield": (
        "This database or stream pattern can cause data "
        "consistency issues or resource exhaustion."
    ),
    "equality": (
        "This equality comparison can produce unexpected "
        "results due to incorrect operator usage."
    ),
    "permission": (
        "This permission handling can cause crashes or "
        "confusing error states when permissions are denied."
    ),
    "resource_management": (
        "This can cause resource exhaustion, performance "
        "degradation, or application instability."
    ),
    "record_pattern": (
        "This pattern matching usage can cause unexpected "
        "behavior or miss important type information."
    ),
    "return": (
        "This return pattern causes unexpected control flow "
        "and makes function behavior harder to predict."
    ),
    "structure": (
        "This structural issue reduces code organization "
        "and makes the codebase harder to navigate."
    ),
    "type": (
        "This type usage can cause unexpected runtime behavior "
        "or weaken static analysis effectiveness."
    ),
    "formatting": (
        "This formatting inconsistency reduces readability "
        "and makes code review diffs harder to parse."
    ),
    "numeric_literal": (
        "This numeric literal usage can cause precision errors "
        "or make the intended value unclear."
    ),
    "notification": (
        "This notification pattern can cause duplicate "
        "notifications or missed messages."
    ),
    "iap": (
        "This in-app purchase pattern can cause transaction "
        "failures or revenue loss."
    ),
    "media": (
        "This media handling can cause playback failures "
        "or excessive memory usage."
    ),
    "bluetooth_hardware": (
        "This hardware interaction can cause connection "
        "failures or excessive battery drain."
    ),
    "freezed": (
        "This Freezed pattern can cause incorrect "
        "immutability or code generation failures."
    ),
    "json_datetime": (
        "This JSON or DateTime handling can cause parsing "
        "errors or timezone-related bugs."
    ),
}

_STYLISTIC = (
    "This deviates from established coding conventions, "
    "reducing consistency and readability across the codebase."
)
for _k in [
    "stylistic", "stylistic_control_flow",
    "stylistic_whitespace_constructor", "stylistic_error_testing",
    "stylistic_null_collection", "stylistic_widget",
    "stylistic_additional", "stylistic_rules",
]:
    CONSEQUENCES[_k] = _STYLISTIC

DEFAULT_CONSEQUENCE = (
    "This pattern increases maintenance cost and the "
    "likelihood of introducing bugs during future changes."
)

# Correction suffixes for expanding short corrections
CORRECTION_SUFFIXES: dict[str, str] = {
    "security": (
        "Audit similar patterns across the codebase "
        "to ensure consistent security practices."
    ),
    "performance": (
        "Profile the affected code path to confirm "
        "the improvement under realistic workloads."
    ),
    "accessibility": (
        "Test with VoiceOver (iOS) and TalkBack (Android) "
        "to verify the change improves accessibility."
    ),
    "test": (
        "Update related tests to reflect the new structure "
        "and verify they still pass."
    ),
    "testing_best_practices": (
        "Run the full test suite to confirm the refactored "
        "tests maintain equivalent coverage."
    ),
    "memory_management": (
        "Use the DevTools memory profiler to verify "
        "the leak is resolved after the fix."
    ),
    "disposal": (
        "Verify disposal in a test that creates and "
        "destroys the widget or resource."
    ),
    "animation": (
        "Test on a low-end device to confirm smooth "
        "rendering after the fix."
    ),
    "widget_layout": (
        "Test on multiple screen sizes to verify "
        "the layout adapts correctly."
    ),
    "build_method": (
        "Use DevTools widget inspector to verify "
        "that rebuild counts decrease."
    ),
    "state_management": (
        "Verify the state updates correctly across "
        "all affected screens and edge cases."
    ),
    "navigation": (
        "Test the full navigation flow including "
        "back button and deep links."
    ),
    "error_handling": (
        "Add unit tests for error paths to ensure "
        "proper handling and user-facing messaging."
    ),
    "api_network": (
        "Test with slow and interrupted connections "
        "to verify network resilience."
    ),
}

DEFAULT_CORRECTION_SUFFIX = (
    "Verify the change works correctly with existing "
    "tests and add coverage for the new behavior."
)

# Stop words for redundancy detection
STOP_WORDS = frozenset([
    "a", "an", "the", "is", "are", "was", "were", "be", "been",
    "have", "has", "had", "do", "does", "did", "will", "would",
    "could", "should", "may", "might", "must", "can", "to", "of",
    "in", "for", "on", "with", "at", "by", "from", "as", "into",
    "through", "during", "before", "after", "then", "when", "all",
    "each", "every", "some", "no", "not", "only", "so", "than",
    "too", "very", "this", "that", "and", "but", "or", "if",
])


# ═════════════════════════════════════════════════════════════════
# EXTRACTION
# ═════════════════════════════════════════════════════════════════


def extract_dartdoc(content: str, class_start: int) -> dict:
    """Extract DartDoc description and context before a class."""
    lines = content[:class_start].rstrip().split("\n")

    doc_lines: list[str] = []
    found = False
    for line in reversed(lines):
        stripped = line.strip()
        if stripped.startswith("///"):
            text = stripped[3:].lstrip() if len(stripped) > 3 else ""
            doc_lines.insert(0, text)
            found = True
        elif found:
            break
        elif stripped in ("", "}"):
            continue
        else:
            break

    # Join into paragraphs, stopping at examples.
    # Track code blocks to skip their content (not just fences).
    paragraphs: list[str] = []
    current: list[str] = []
    in_code_block = False

    for line in doc_lines:
        # Toggle code block state on fences
        if line.startswith("```"):
            in_code_block = not in_code_block
            continue
        # Skip everything inside code blocks
        if in_code_block:
            continue
        # Stop at example sections (case-insensitive)
        if re.search(r"\*\*(?:BAD|GOOD|bad|good)", line):
            break
        if line.startswith("Alias:") or line.startswith("**OWASP"):
            continue
        # Filter out markdown headings (### Example, #### BAD)
        if line.startswith("#"):
            continue
        # Filter out internal annotations and dev notes
        if "[HEURISTIC]" in line or "[EXPERIMENTAL]" in line:
            continue
        if re.match(
            r"^(?:Future rule:|TODO:|FIXME:|NOTE:|HACK:|XXX:)", line,
        ):
            continue
        # Filter out example labels
        if re.match(r"^(?:Example|BAD|GOOD|Bad|Good)\b", line):
            continue
        if not line:
            if current:
                paragraphs.append(" ".join(current))
                current = []
        else:
            current.append(line)

    if current:
        paragraphs.append(" ".join(current))

    desc = paragraphs[0] if paragraphs else ""
    ctx = paragraphs[1:]
    return {
        "description": desc,
        "context": ctx,
        "context_text": " ".join(ctx),
    }


# Words too generic to use for DartDoc relevance matching.
_FILLER_WORDS = frozenset({
    "avoid", "prefer", "require", "use", "no", "in", "for", "with",
    "of", "should", "must", "the", "a", "an", "is", "are", "has",
    "have", "not", "be", "do", "does", "did", "to", "on", "at",
    "by", "from", "as", "or", "and", "but", "if", "when", "that",
    "this", "it", "all", "any", "each", "single", "over",
})


def _dartdoc_matches_rule(rule_name: str, dartdoc: dict) -> bool:  # cspell:ignore dartdoc
    """Heuristic: does the DartDoc plausibly describe this rule?

    Returns False when the DartDoc description shares zero meaningful
    words with the rule name, indicating a misattributed DartDoc
    block in the source file (e.g., DartDoc for rule A placed
    above the class for rule B).
    """
    desc = dartdoc.get("description", "")
    if not desc:
        return True  # No DartDoc to mismatch

    name_parts = set(rule_name.lower().split("_")) - _FILLER_WORDS
    if not name_parts:
        return True  # Can't determine, assume OK

    desc_lower = desc.lower()
    return any(part in desc_lower for part in name_parts)


def extract_impact_comment(class_body: str) -> str:
    """Extract /// comment lines above the impact getter.

    Filters out terse internal annotations that are not suitable
    for user-facing messages (e.g., "Style/consistency. Large counts
    acceptable in legacy code.").
    """
    match = re.search(
        r"((?:\s*///[^\n]*\n)+)\s*@override\s*\n\s*LintImpact get impact",
        class_body,
    )
    if not match:
        return ""
    lines = [
        ln.strip()[3:].strip()
        for ln in match.group(1).split("\n")
        if ln.strip().startswith("///")
    ]
    text = " ".join(lines)
    # Skip short internal annotations (not user-facing quality)
    if len(text) < 80:
        return ""
    return text


# ═════════════════════════════════════════════════════════════════
# AUDIT (simplified from _audit_dx.py)
# ═════════════════════════════════════════════════════════════════


def audit_message(
    impact: str,
    problem_msg: str,
    correction_msg: str,
) -> list[str]:
    """Return list of DX issues. Empty means the rule passes."""
    issues: list[str] = []
    msg_lower = problem_msg.lower()
    content = re.sub(r"^\[[a-z0-9_]+\]\s*", "", problem_msg)

    # Vague language (skip for low impact)
    if impact not in ("low", "opinionated"):
        for pattern, issue in VAGUE_CHECKS:
            if pattern in msg_lower:
                issues.append(issue)
                break

    # cspell:ignore clen
    # Problem message length
    clen = len(content)
    min_len = MIN_PROBLEM.get(impact, 150)
    if clen < min_len:
        issues.append(f"Short problem ({clen}/{min_len} chars)")

    # Correction message length
    corr_len = len(correction_msg.strip()) if correction_msg else 0
    min_corr = MIN_CORRECTION.get(impact, 80)
    if impact == "critical" and corr_len < min_corr:
        issues.append(f"Short correction ({corr_len}/{min_corr} chars)")
    elif impact != "critical" and 0 < corr_len < min_corr:
        issues.append(f"Short correction ({corr_len}/{min_corr} chars)")

    # Missing consequence (critical/high only)
    if impact in ("critical", "high"):
        if not any(w in msg_lower for w in CONSEQUENCE_WORDS):
            issues.append("Missing consequence")

    return issues


# ═════════════════════════════════════════════════════════════════
# IMPROVEMENT LOGIC
# ═════════════════════════════════════════════════════════════════


def is_redundant(new_text: str, existing: str) -> bool:
    """True if the new text is already substantially present.

    Checks both word overlap (>50% of significant words) and
    substring containment to prevent double-appending on re-runs.
    """
    new_lower = new_text.lower().strip()
    existing_lower = existing.lower()

    # Exact or near-exact substring already present
    if new_lower in existing_lower:
        return True

    new_words = set(new_lower.split()) - STOP_WORDS
    if not new_words:
        return True
    existing_words = set(existing_lower.split()) - STOP_WORDS
    overlap = len(new_words & existing_words) / len(new_words)
    return overlap > 0.5


def _strip_markdown(text: str) -> str:
    """Strip inline markdown formatting from text.

    Removes bold (**text**), italic (*text*), inline code (`text`),
    and heading markers (### ).
    """
    # Bold: **text** → text
    text = re.sub(r"\*\*([^*]+)\*\*", r"\1", text)
    # Italic: *text* → text (but not ** which is bold)
    text = re.sub(r"(?<!\*)\*([^*]+)\*(?!\*)", r"\1", text)
    # Inline code: `text` → text
    text = re.sub(r"`([^`]+)`", r"\1", text)
    # Heading markers: ### text → text
    text = re.sub(r"^#{1,6}\s+", "", text)
    return text


def escape_for_dart(text: str) -> str:
    """Strip markdown and escape text for a Dart single-quoted string."""
    text = _strip_markdown(text)
    return (
        text.replace("\\", "\\\\")
        .replace("'", "\\'")
        .replace("$", "\\$")
    )


def fix_vague(text: str) -> str:
    """Apply vague language fixes and clean up."""
    result = text
    for pattern, replacement in VAGUE_FIXES:
        result = re.sub(pattern, replacement, result)
    # Clean up double spaces or leading/trailing dots
    result = re.sub(r"  +", " ", result)
    result = re.sub(r"\.\s*\.", ".", result)
    return result.strip()


def _append_sentence(base: str, addition: str) -> str:
    """Append a sentence, ensuring proper punctuation."""
    base = base.rstrip()
    if base and not base.endswith((".","!","?")):
        base += "."
    addition = addition.strip()
    if not addition:
        return base
    return f"{base} {addition}"


def improve_problem(
    rule_name: str,
    msg: str,
    dartdoc: dict,
    impact: str,
    impact_comment: str,
    category: str,
) -> tuple[str, list[str]]:
    """Improve a problem message. Returns (new_msg, sources_used)."""
    prefix_match = re.match(r"^(\[[a-z0-9_]+\]\s*)", msg)
    prefix = prefix_match.group(1) if prefix_match else ""
    content = msg[len(prefix):]
    sources: list[str] = []
    min_len = MIN_PROBLEM.get(impact, 150)

    # Step 1: Append DartDoc context sentences
    if len(content) < min_len and dartdoc["context"]:
        for ctx_sentence in dartdoc["context"]:
            escaped = escape_for_dart(ctx_sentence)
            if not is_redundant(escaped, content):
                content = _append_sentence(content, escaped)
                sources.append("dartdoc-context")
            if len(content) >= min_len:
                break

    # Step 2: Append impact comment
    if len(content) < min_len and impact_comment:
        escaped = escape_for_dart(impact_comment)
        if not is_redundant(escaped, content):
            content = _append_sentence(content, escaped)
            sources.append("impact-comment")

    # Step 3: Append DartDoc description (if different from message)
    if len(content) < min_len and dartdoc["description"]:
        desc = dartdoc["description"]
        # Strip common prefixes like "Warns when..."
        desc_clean = re.sub(
            r"^(?:Warns?\s+when\s+|Detects?\s+when\s+|Flags?\s+when\s+)",
            "", desc, flags=re.IGNORECASE,
        )
        # Capitalize first letter after prefix stripping
        if desc_clean and desc_clean[0].islower():
            desc_clean = desc_clean[0].upper() + desc_clean[1:]
        if desc_clean and not is_redundant(desc_clean, content):
            escaped = escape_for_dart(desc_clean)
            content = _append_sentence(content, escaped)
            sources.append("dartdoc-desc")

    # Step 4: Append category consequence
    if len(content) < min_len:
        consequence = CONSEQUENCES.get(category, DEFAULT_CONSEQUENCE)
        if not is_redundant(consequence, content):
            content = _append_sentence(content, consequence)
            sources.append("category")

    # Step 5: Fix vague language LAST (catches vague words from
    # DartDoc context that was appended above)
    fixed = fix_vague(content)
    if fixed != content:
        content = fixed
        sources.append("vague-fix")

    # Ensure ends with period
    content = content.rstrip()
    if content and not content.endswith((".", "!", "?")):
        content += "."

    return prefix + content, sources


def improve_correction(
    correction: str,
    impact: str,
    category: str,
) -> tuple[str, list[str]]:
    """Improve a correction message. Returns (new_msg, sources_used).

    Only uses correction-specific suffixes (testing/verification
    advice), never DartDoc context which describes the problem.
    """
    if not correction:
        return correction, []

    content = correction
    sources: list[str] = []

    # Step 1: Fix vague language in corrections too
    fixed = fix_vague(content)
    if fixed != content:
        content = fixed
        sources.append("vague-fix")

    # Step 2: Check length (after vague fix may have shortened text)
    min_len = MIN_CORRECTION.get(impact, 80)
    if len(content.strip()) >= min_len:
        return content, sources

    # Step 3: Append category-specific correction suffix
    suffix = CORRECTION_SUFFIXES.get(
        category, DEFAULT_CORRECTION_SUFFIX,
    )
    if not is_redundant(suffix, content):
        content = _append_sentence(content, suffix)
        sources.append("correction-suffix")

    # Ensure ends with period
    content = content.rstrip()
    if content and not content.endswith((".", "!", "?")):
        content += "."

    return content, sources


# ═════════════════════════════════════════════════════════════════
# FILE PROCESSING
# ═════════════════════════════════════════════════════════════════


def _file_category(filename: str) -> str:
    """Map rule filename to category key."""
    return filename.replace("_rules.dart", "").replace(".dart", "")


def extract_rules_from_file(
    dart_file: Path,
) -> list[dict]:
    """Extract all rules from a single file with their context."""
    content = dart_file.read_text(encoding="utf-8")
    class_starts = [m.start() for m in CLASS_RE.finditer(content)]
    rules: list[dict] = []

    for idx, start in enumerate(class_starts):
        end = (
            class_starts[idx + 1]
            if idx + 1 < len(class_starts)
            else len(content)
        )
        class_body = content[start:end]

        impact_m = IMPACT_RE.search(class_body)
        impact = impact_m.group(1) if impact_m else "medium"

        for code_m in LINTCODE_RE.finditer(class_body):
            name = code_m.group(1)
            problem = code_m.group(2) or code_m.group(3) or ""
            correction = code_m.group(4) or code_m.group(5) or ""

            issues = audit_message(impact, problem, correction)
            if not issues:
                continue

            dartdoc = extract_dartdoc(content, start)
            if not _dartdoc_matches_rule(name, dartdoc):
                dartdoc = {
                    "description": "",
                    "context": [],
                    "context_text": "",
                }
            impact_comment = extract_impact_comment(class_body)

            rules.append({
                "name": name,
                "impact": impact,
                "issues": issues,
                "problem": problem,
                "correction": correction,
                "dartdoc": dartdoc,
                "impact_comment": impact_comment,
                "class_start": start,
                "class_end": end,
            })

    return rules


def apply_to_content(
    content: str,
    improvements: list[dict],
) -> str:
    """Apply message improvements to file content.

    Processes from last class to first to preserve positions.
    """
    # Sort by class_start descending
    sorted_imps = sorted(
        improvements, key=lambda x: x["class_start"], reverse=True,
    )

    for imp in sorted_imps:
        start = imp["class_start"]
        end = imp["class_end"]
        class_body = content[start:end]

        old_p = imp["old_problem"]
        new_p = imp["new_problem"]
        old_c = imp["old_correction"]
        new_c = imp["new_correction"]

        if new_p != old_p:
            # Determine quote style
            if f"'{old_p}'" in class_body:
                class_body = class_body.replace(
                    f"'{old_p}'", f"'{new_p}'", 1,
                )
            elif f'"{old_p}"' in class_body:
                class_body = class_body.replace(
                    f'"{old_p}"', f'"{new_p}"', 1,
                )

        if new_c != old_c and old_c:
            if f"'{old_c}'" in class_body:
                class_body = class_body.replace(
                    f"'{old_c}'", f"'{new_c}'", 1,
                )
            elif f'"{old_c}"' in class_body:
                class_body = class_body.replace(
                    f'"{old_c}"', f'"{new_c}"', 1,
                )

        content = content[:start] + class_body + content[end:]

    return content


def process_all() -> list[dict]:
    """Process all rule files. Returns list of file-level changes."""
    all_changes: list[dict] = []

    dart_files = sorted(RULES_DIR.glob("**/*.dart"))
    for dart_file in dart_files:
        if dart_file.name == "all_rules.dart":
            continue

        rules = extract_rules_from_file(dart_file)
        if not rules:
            continue

        category = _file_category(dart_file.name)
        improvements: list[dict] = []

        for rule in rules:
            new_problem, p_sources = improve_problem(
                rule["name"],
                rule["problem"],
                rule["dartdoc"],
                rule["impact"],
                rule["impact_comment"],
                category,
            )
            new_correction, c_sources = improve_correction(
                rule["correction"],
                rule["impact"],
                category,
            )

            changed = (
                new_problem != rule["problem"]
                or new_correction != rule["correction"]
            )
            if not changed:
                continue

            # Re-audit improved messages
            new_issues = audit_message(
                rule["impact"], new_problem, new_correction,
            )

            improvements.append({
                "name": rule["name"],
                "impact": rule["impact"],
                "old_issues": rule["issues"],
                "old_problem": rule["problem"],
                "new_problem": new_problem,
                "old_correction": rule["correction"],
                "new_correction": new_correction,
                "p_sources": p_sources,
                "c_sources": c_sources,
                "new_issues": new_issues,
                "class_start": rule["class_start"],
                "class_end": rule["class_end"],
            })

        if improvements:
            content = dart_file.read_text(encoding="utf-8")
            new_content = apply_to_content(content, improvements)
            all_changes.append({
                "file": dart_file,
                "improvements": improvements,
                "new_content": new_content,
            })

    return all_changes


# ═════════════════════════════════════════════════════════════════
# REPORT
# ═════════════════════════════════════════════════════════════════


def _msg_len(msg: str) -> int:
    """Length of message content, excluding [rule_name] prefix."""
    return len(re.sub(r"^\[[a-z0-9_]+\]\s*", "", msg))


def write_report(
    all_changes: list[dict],
    applied: bool,
) -> Path:
    """Write a detailed markdown report of all changes."""
    REPORTS_DIR.mkdir(exist_ok=True)
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    path = REPORTS_DIR / f"{timestamp}_dx_message_improvements.md"

    total_rules = sum(len(c["improvements"]) for c in all_changes)
    total_fixed = sum(
        1 for c in all_changes
        for imp in c["improvements"]
        if not imp["new_issues"]
    )
    total_partial = total_rules - total_fixed

    lines: list[str] = []
    lines.append("# DX Message Improvement Report")
    lines.append("")
    lines.append(
        f"Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}"
    )
    lines.append(f"Mode: {'Applied' if applied else 'Dry run'}")
    lines.append("")
    lines.append("## Summary")
    lines.append("")
    lines.append(f"- **Rules improved:** {total_rules}")
    lines.append(f"- **Fully fixed:** {total_fixed}")
    lines.append(f"- **Partially fixed:** {total_partial}")
    lines.append(f"- **Files affected:** {len(all_changes)}")
    lines.append("")

    if total_partial > 0:
        lines.append("## Still Needs Manual Attention")
        lines.append("")
        lines.append("| Rule | Impact | Remaining Issues |")
        lines.append("|------|--------|------------------|")
        for change in all_changes:
            for imp in change["improvements"]:
                if imp["new_issues"]:
                    issues_str = ", ".join(imp["new_issues"])
                    lines.append(
                        f"| `{imp['name']}` | {imp['impact']} "
                        f"| {issues_str} |"
                    )
        lines.append("")

    # Per-file details
    lines.append("## Changes by File")
    lines.append("")

    for change in all_changes:
        fname = change["file"].name
        count = len(change["improvements"])
        lines.append(f"### {fname} ({count} rules)")
        lines.append("")

        for imp in change["improvements"]:
            status = "FIXED" if not imp["new_issues"] else "PARTIAL"
            lines.append(f"#### `{imp['name']}` [{status}]")
            lines.append("")
            lines.append(f"- **Impact:** {imp['impact']}")
            lines.append(
                f"- **Issues:** {', '.join(imp['old_issues'])}"
            )
            sources = set(imp["p_sources"] + imp["c_sources"])
            lines.append(
                f"- **Sources:** {', '.join(sources) or 'none'}"
            )

            # Problem message diff (full text, never truncated)
            old_p = imp["old_problem"]
            new_p = imp["new_problem"]
            if new_p != old_p:
                lines.append("")
                lines.append(
                    f"**Problem** ({_msg_len(old_p)} "
                    f"-> {_msg_len(new_p)} chars):"
                )
                lines.append(f"- Before: {old_p}")
                lines.append(f"- After: {new_p}")

            # Correction message diff (full text, never truncated)
            old_c = imp["old_correction"]
            new_c = imp["new_correction"]
            if new_c != old_c:
                lines.append("")
                lines.append(
                    f"**Correction** ({len(old_c)} "
                    f"-> {len(new_c)} chars):"
                )
                lines.append(f"- Before: {old_c}")
                lines.append(f"- After: {new_c}")

            if imp["new_issues"]:
                lines.append("")
                lines.append(
                    f"**Remaining:** {', '.join(imp['new_issues'])}"
                )
            lines.append("")
            lines.append("---")
            lines.append("")

    path.write_text("\n".join(lines), encoding="utf-8")
    return path


# ═════════════════════════════════════════════════════════════════
# PUBLIC API (for use by publish_to_pubdev.py)
# ═════════════════════════════════════════════════════════════════


@dataclass
class DxResult:
    """Structured result from a DX analysis run."""

    total: int
    fixed: int
    partial: int
    files_affected: int
    report_path: Path | None
    changes: list[dict] = field(repr=False)


def run_dx_analysis() -> DxResult:
    """Run DX analysis in dry-run mode and return structured results.

    This is the public API for other scripts (e.g. publish_to_pubdev.py)
    to call without triggering interactive prompts or file writes.
    Only the markdown report is written.
    """
    all_changes = process_all()
    total = sum(len(c["improvements"]) for c in all_changes)
    fixed = sum(
        1 for c in all_changes
        for imp in c["improvements"]
        if not imp["new_issues"]
    )
    partial = total - fixed

    report_path = None
    if total > 0:
        report_path = write_report(all_changes, applied=False)

    return DxResult(
        total=total,
        fixed=fixed,
        partial=partial,
        files_affected=len(all_changes),
        report_path=report_path,
        changes=all_changes,
    )


# ═════════════════════════════════════════════════════════════════
# COLORED SUMMARY
# ═════════════════════════════════════════════════════════════════


def _print_colored_summary(all_changes: list[dict]) -> None:
    """Print a colored summary of analysis results."""
    total = sum(len(c["improvements"]) for c in all_changes)
    fixed = sum(
        1 for c in all_changes
        for imp in c["improvements"]
        if not imp["new_issues"]
    )
    partial = total - fixed

    print_section("ANALYSIS RESULTS")

    print_stat("Rules improved", total, Color.CYAN)
    print_stat("Fully fixed", fixed, Color.GREEN)
    review_color = Color.YELLOW if partial > 0 else Color.GREEN
    print_stat("Needs review", partial, review_color)
    print_stat("Files affected", len(all_changes), Color.CYAN)
    print()

    if not all_changes:
        print_success("All DX messages meet quality thresholds.")
        return

    # Per-file breakdown with progress bars
    print_section("CHANGES BY FILE")
    for change in all_changes:
        fname = change["file"].name
        file_total = len(change["improvements"])
        file_fixed = sum(
            1 for imp in change["improvements"]
            if not imp["new_issues"]
        )
        if file_fixed == file_total:
            color = Color.GREEN
        elif file_fixed > 0:
            color = Color.YELLOW
        else:
            color = Color.RED
        print_stat_bar(fname, file_fixed, file_total, color=color)
    print()

    # Rules still needing manual attention
    if partial > 0:
        print_section("NEEDS MANUAL ATTENTION")
        for change in all_changes:
            for imp in change["improvements"]:
                if imp["new_issues"]:
                    issues_str = ", ".join(imp["new_issues"])
                    print_colored(
                        f"    {imp['name']:<40} "
                        f"{imp['impact']:<10} {issues_str}",
                        Color.YELLOW,
                    )
        print()


# ═════════════════════════════════════════════════════════════════
# MAIN
# ═════════════════════════════════════════════════════════════════


def _apply_changes(all_changes: list[dict]) -> None:
    """Write improved content back to source files."""
    for change in all_changes:
        change["file"].write_text(
            change["new_content"], encoding="utf-8",
        )
    print_success(f"Applied changes to {len(all_changes)} file(s).")
    print_info("Run 'dart format .' to fix line lengths.")


def main() -> int:
    """Analyze DX messages and optionally apply fixes."""
    enable_ansi_support()
    show_saropa_logo()

    ci_mode = "--apply" in sys.argv

    print_header(f"DX MESSAGE IMPROVER v{SCRIPT_VERSION}")
    print_info(f"Rules dir: {RULES_DIR}")
    mode_label = "CI (auto-apply)" if ci_mode else "Interactive"
    print_info(f"Mode: {mode_label}")
    print()

    # Step 1: Always run analysis first
    print_info("Analyzing DX messages...")
    result = run_dx_analysis()

    if result.total == 0:
        print_success("All DX messages meet quality thresholds.")
        return 0

    # Step 2: Show colored summary
    _print_colored_summary(result.changes)

    # Step 3: Apply or prompt
    applied = False
    if ci_mode:
        _apply_changes(result.changes)
        applied = True
    else:
        print_colored(
            "  Apply these changes to source files?",
            Color.WHITE,
        )
        response = input("  [y/N] ").strip().lower()
        if response == "y":
            _apply_changes(result.changes)
            applied = True
        else:
            print_warning("No changes applied.")

    # Step 4: Update report if changes were applied
    if applied:
        report_path = write_report(result.changes, applied=True)
    else:
        report_path = result.report_path

    if report_path:
        print_info(f"Report: {report_path.relative_to(PROJECT_ROOT)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
