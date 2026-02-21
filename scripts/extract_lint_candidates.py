"""
Scans scraped release notes (Flutter SDK, Dart SDK, Dart-Code) to extract
lint rule candidates — deprecations, new features, new parameters, breaking
changes, and performance improvements that could be detected by static analysis.

Excludes items already handled by `dart fix` (loaded from dart_fix_pairs.txt).
Filters noise (reverts, CI, docs-only, engine internals) and scores relevance.

Usage:
    python scripts/extract_lint_candidates.py

Output:
    scripts/lint_candidates_report.md
"""

import os
import re
from collections import defaultdict
from datetime import datetime
from typing import Dict, List, Set, Tuple

# --- Configuration ---
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_DIR = os.path.dirname(BASE_DIR)
REPORTS_DIR = os.path.join(PROJECT_DIR, "reports")
OUTPUT_FILE = os.path.join(REPORTS_DIR, "lint_candidates_report.md")
DART_FIX_PAIRS_FILE = os.path.join(BASE_DIR, "dart_fix_pairs.txt")

SOURCES = {
    "Flutter SDK": os.path.join(REPORTS_DIR, "flutter_sdk_exports", "versions"),
    "Dart SDK": os.path.join(REPORTS_DIR, "dart_sdk_exports", "versions"),
    "Dart-Code": os.path.join(REPORTS_DIR, "dart_code_exports", "versions"),
}

# --- Candidate Categories ---
CATEGORIES = [
    (
        "Deprecation",
        re.compile(
            r'(?:deprecat(?:ed?|ion|ing)|@deprecated|will be removed|'
            r'no longer supported|sunset(?:ted|ting)?)',
            re.IGNORECASE,
        ),
        "Old API deprecated — lint can detect usage and suggest replacement",
    ),
    (
        "Breaking Change",
        re.compile(
            r'(?:breaking\s*change|removed|no longer (?:accept|allow|support)|'
            r'renamed?\s+(?:to|from)|changed? (?:the )?(?:type|signature|return)|'
            r'migration required)',
            re.IGNORECASE,
        ),
        "API changed/removed — lint can detect old pattern and flag it",
    ),
    (
        "New Feature / API",
        re.compile(
            r'(?:(?:new|added?|introduc(?:ed?|ing))\s+(?:a\s+)?'
            r'(?:widget|class|method|function|mixin|extension|enum|typedef|'
            r'property|getter|setter|field|API|parameter|argument|option|'
            r'flag|feature|syntax|keyword|annotation|modifier|operator))',
            re.IGNORECASE,
        ),
        "New capability — lint can detect verbose pattern and suggest the new API",
    ),
    (
        "New Parameter / Option",
        re.compile(
            r'(?:(?:new|added?|introduc(?:ed?|ing))\s+(?:an?\s+)?'
            r'(?:optional|named|required|positional)?\s*'
            r'(?:param(?:eter)?|arg(?:ument)?|option|flag|field|property|'
            r'setting|config))',
            re.IGNORECASE,
        ),
        "New parameter — lint can suggest using the new option for better behavior",
    ),
    (
        # Tightened: require actual perf keywords, not just "improve"
        "Performance Improvement",
        re.compile(
            r'(?:optimiz\w+|faster|speed\s*up|more efficient|'
            r'eliminat(?:ed?|ing)\s+(?:unnecessary|redundant)|'
            r'reduc\w+\s+(?:alloc|latenc|jank|overhead|rebuild|'
            r'memory|startup|load)|'
            r'lazy\s+(?:load|init)|'
            r'improve\w*\s+(?:\w+\s+)?(?:performance|speed|latency|'
            r'frame\s*rate|fps|render|startup|jank))',
            re.IGNORECASE,
        ),
        "Performance gain — lint can detect the slower old pattern",
    ),
    (
        "Replacement / Migration",
        re.compile(
            r'(?:(?:replac|migrat|supersed|instead\s+(?:of|use)|'
            r'prefer\s+(?:using)?|use\s+\S+\s+instead|'
            r'switch(?:ed)?\s+(?:to|from)|moved?\s+to)\b)',
            re.IGNORECASE,
        ),
        "Pattern replacement — lint can detect old pattern and suggest new one",
    ),
]


# --- Noise Filters ---
# Lines matching these patterns are internal/CI/docs/not user-facing.
NOISE_PATTERNS = [
    # Reverts and relands (duplicates of the original)
    re.compile(r'^\*?\s*Revert[s"]?\s', re.IGNORECASE),
    re.compile(r'^\*?\s*Reland\b', re.IGNORECASE),
    # CI, infrastructure, bots
    re.compile(
        r'(?:autoroll|auto-submit|roller-bot|dependabot|'
        r'bringup|LUCI|buildbot|ci[\s/]cd|presubmit|postsubmit|'
        r'test\s*shard|Roll\s+(?:Dart\s+SDK|Packages|pub\s+packages|'
        r'buildroot|Skia|Fuchsia))',
        re.IGNORECASE,
    ),
    # Build system / toolchain internals
    re.compile(
        r'(?:\.gradle|\.groovy|CMakeLists|\.gn\b|gn\s+flag|'
        r'Podfile|\.podspec|xcconfig|Xcode\s+(?:project|workspace|cache)|'
        r'Makefile|msbuild|Visual\s+Studio\s+build)',
        re.IGNORECASE,
    ),
    # Engine internals (Impeller, Skia, etc.) — not user-facing Dart APIs
    re.compile(
        r'^\*?\s*\[(?:Impeller|skia|skwasm|canvaskit)\]',
        re.IGNORECASE,
    ),
    # Platform-internal code quality (Java/Kotlin/ObjC/Swift test files)
    re.compile(
        r'(?:Improve\s+code\s+quality\s+(?:in\s+)?[`"\']?\w+\.(?:java|kt|m|swift))',
        re.IGNORECASE,
    ),
    # Documentation-only changes
    re.compile(
        r'(?:^\*?\s*(?:Improve|Update|Fix|Clarify|Add)\s+'
        r'(?:the\s+)?(?:documentation|docstring|doc\s*comment|'
        r'dartdoc|javadoc|README|CHANGELOG|CONTRIBUTING))',
        re.IGNORECASE,
    ),
    # Test-only changes
    re.compile(
        r'(?:^\*?\s*(?:Improve|Update|Fix|Add|Cleanup)\s+'
        r'(?:\w+\s+)?(?:unit\s+)?tests?\b)',
        re.IGNORECASE,
    ),
    # Roll / version bump lines
    re.compile(
        r'(?:Roll\s+\w+\s+(?:from|to)\s|'
        r'Bump\s+\w+\s+from\s|version\s+bump)',
        re.IGNORECASE,
    ),
    # Remove lint ignores, suppress warnings (framework internal cleanup)
    re.compile(
        r'(?:Suppress\s+(?:deprecation\s+)?warning|'
        r'Enable\s+deprecated_member_use|'
        r'removed?\s+lint[s]?\b|'
        r'Added?\s+type\s+annotations?\s+and\s+removed?\s+lints?)',
        re.IGNORECASE,
    ),
]


def is_noise(line: str) -> bool:
    """Check if a line is noise (internal, CI, docs, reverts, etc.)."""
    cleaned = strip_markdown(line)
    for pattern in NOISE_PATTERNS:
        if pattern.search(cleaned):
            return True
    return False


# --- Relevance Scoring ---
# Higher score = more likely to be an actionable lint rule candidate.

# Positive signals (user-facing Dart/Flutter API changes)
POSITIVE_SIGNALS = [
    # Backtick code references (likely mentions a specific API)
    (re.compile(r'`[A-Z]\w+\.?\w*`'), 3),
    # Dart/Flutter class names (CamelCase with known prefixes)
    (re.compile(
        r'(?:Widget|State|Context|Theme|Color|Text|Icon|Button|'
        r'Scaffold|AppBar|Navigator|MediaQuery|Material|Cupertino|'
        r'Sliver|Scroll|Animation|Gesture|Form|Input|Dropdown|'
        r'Chip|Switch|Slider|Tab|Dialog|Drawer|BottomSheet|'
        r'SnackBar|Banner|Card|ListTile|DataTable|'
        r'Stream|Future|Isolate|Timer|Duration|'
        r'EdgeInsets|Alignment|BoxDecoration|TextStyle|'
        r'RenderObject|Element|InheritedWidget)(?:\.\w+|\b)',
    ), 2),
    # Explicit old->new pattern
    (re.compile(
        r'(?:use\s+\S+\s+instead|replaced?\s+(?:by|with)|'
        r'in\s+favor\s+of|prefer\s+\S+\s+over)',
        re.IGNORECASE,
    ), 4),
    # Specific API deprecation (not just "cleanup deprecated code")
    (re.compile(
        r'(?:deprecat\w+)\s+[`\'"]?\w+[`\'"]?\s+'
        r'(?:in\s+favor|parameter|method|property|class|widget)',
        re.IGNORECASE,
    ), 3),
    # User-facing: mentions "users", "developers", "apps", "projects"
    (re.compile(
        r'(?:users?\s+(?:should|can|must)|'
        r'app(?:lication)?s?\s+(?:should|can|that)|'
        r'project\w*\s+(?:should|using|that))',
        re.IGNORECASE,
    ), 2),
]

# Negative signals (less likely to be actionable)
NEGATIVE_SIGNALS = [
    # Internal file references
    (re.compile(r'\.(?:java|kt|swift|m|h|cc|cpp|py|sh|ps1|bat)\b'), -2),
    # Platform-specific internals
    (re.compile(
        r'(?:\[(?:ios|android|web|windows|linux|macos|fuchsia)\]|'
        r'(?:Android|iOS|Windows|Linux|macOS)\s+(?:only|specific|internal)|'
        r'(?:NDK|JNI|ABI|APK|AAR|IPA|XCFramework))',
        re.IGNORECASE,
    ), -1),
    # CI/infra mentions that slipped through
    (re.compile(r'(?:shard|flak[ey]|timeout|bringup|benchmark)', re.I), -2),
    # Engine internals
    (re.compile(r'(?:Impeller|Skia|CanvasKit|DisplayList)\b'), -1),
]


def score_relevance(line: str, category: str) -> int:
    """Score how likely a line represents an actionable lint rule candidate."""
    score = 0

    # Base score by category (some categories are inherently more actionable)
    category_base = {
        "Deprecation": 2,
        "Breaking Change": 1,
        "New Feature / API": 2,
        "New Parameter / Option": 2,
        "Performance Improvement": 1,
        "Replacement / Migration": 3,
    }
    score += category_base.get(category, 0)

    for pattern, points in POSITIVE_SIGNALS:
        if pattern.search(line):
            score += points

    for pattern, points in NEGATIVE_SIGNALS:
        if pattern.search(line):
            score += points  # points are already negative

    return max(score, 0)


# --- Dart Fix Coverage ---

GENERIC_MEMBERS = {
    '(constructor)', 'of', 'copyWith', 'value', 'builder', 'resolve',
    'resolveFrom', 'count', 'custom', 'extent', 'separated', 'light',
    'dark', 'body', 'raw', 'find', 'handler', 'invoke', 'height',
    'insertChildRenderObject', 'moveChildRenderObject',
    'removeChildRenderObject',
}


def load_dart_fix_pairs() -> Tuple[Set[str], Set[str]]:
    """Load Class.member pairs and build a set of distinctive member names.

    Returns (pairs, distinctive_members) where distinctive_members are
    member names unique enough to identify a dart-fix-covered API when
    mentioned alone in release notes (e.g., `withOpacity`).
    """
    pairs: Set[str] = set()
    member_to_classes: Dict[str, Set[str]] = {}

    if not os.path.exists(DART_FIX_PAIRS_FILE):
        return pairs, set()

    with open(DART_FIX_PAIRS_FILE, "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if line and "." in line and not line.startswith("Total:"):
                pairs.add(line)
                class_name, member = line.split(".", 1)
                member_to_classes.setdefault(member, set()).add(class_name)

    distinctive = set()
    for member, classes in member_to_classes.items():
        if member in GENERIC_MEMBERS:
            continue
        if len(member) <= 3:
            continue
        distinctive.add(member)

    return pairs, distinctive


def strip_markdown(text: str) -> str:
    """Remove markdown formatting (backticks, bold, italic) for matching."""
    text = re.sub(r'`([^`]*)`', r'\1', text)  # inline code
    text = re.sub(r'\*\*([^*]*)\*\*', r'\1', text)  # bold
    text = re.sub(r'\*([^*]*)\*', r'\1', text)  # italic
    text = re.sub(r'_([^_]*)_', r'\1', text)  # underscore italic
    return text


def line_mentions_dart_fix_pair(
    line: str,
    pairs: Set[str],
    distinctive_members: Set[str],
) -> bool:
    """Check if a line mentions any Class.member pair from dart fix."""
    cleaned = strip_markdown(line)

    for pair in pairs:
        class_name, member = pair.split(".", 1)
        if member in GENERIC_MEMBERS:
            continue
        if class_name in cleaned and member in cleaned:
            return True

    for member in distinctive_members:
        if member not in cleaned:
            continue

        backtick_pattern = r'`[^`]*' + re.escape(member) + r'[^`]*`'
        if re.search(backtick_pattern, line):
            return True

        dot_pattern = r'\.' + re.escape(member) + r'(?![a-zA-Z])'
        if re.search(dot_pattern, cleaned):
            return True

        deprec_pattern = (
            r'(?:deprecat\w*|removed?)\s+' + re.escape(member)
            + r'(?![a-zA-Z])'
        )
        if re.search(deprec_pattern, cleaned, re.IGNORECASE):
            return True

    return False


# --- Deduplication ---

# Patterns to extract API identifiers from lines
API_EXTRACT_PATTERNS = [
    # `ClassName.member` or `ClassName`
    re.compile(r'`([A-Z]\w+(?:\.\w+)?)`'),
    # ClassName.member without backticks (CamelCase)
    re.compile(r'\b([A-Z][a-z]\w+\.[a-z]\w+)\b'),
    # Standalone CamelCase class names in deprecation context
    re.compile(r'(?:deprecat\w+|remov\w+|replac\w+)\s+`?([A-Z]\w+)`?'),
]


def extract_api_key(line: str) -> str:
    """Extract a normalized API identifier from a line for deduplication."""
    for pattern in API_EXTRACT_PATTERNS:
        match = pattern.search(line)
        if match:
            return match.group(1).lower()
    # Fallback: normalize the line itself (strip PR links, authors, etc.)
    cleaned = re.sub(r'\s+by\s+@\w+.*$', '', line)
    cleaned = re.sub(r'\s*(?:in\s+)?\[?\d+\]?\(?https?://\S+\)?', '', cleaned)
    cleaned = re.sub(r'[*_`#\[\]]', '', cleaned).strip()
    return cleaned.lower()[:80]


def extract_version_from_filename(filename: str) -> str:
    """Extract version string from filename like 'flutter-3.41.0.md'."""
    match = re.search(r'[\d][\d.]+[\d]', filename)
    if match:
        return match.group(0)
    match = re.search(r'v\d+-\d+', filename)
    return match.group(0) if match else filename


# --- Scanning ---

# ScoredMatch = (category, line, context, covered_by_dart_fix, score)
ScoredMatch = Tuple[str, str, str, bool, int]


def scan_file(
    filepath: str,
    dart_fix_pairs: Set[str],
    distinctive_members: Set[str],
) -> List[ScoredMatch]:
    """Scan a version file for lint rule candidates."""
    with open(filepath, "r", encoding="utf-8") as f:
        lines = f.readlines()

    matches = []
    seen_lines: Set[Tuple[str, str]] = set()

    for i, line in enumerate(lines):
        stripped = line.strip()
        if not stripped or stripped.startswith('#'):
            continue

        # Skip noise lines
        if is_noise(stripped):
            continue

        for category_name, pattern, _ in CATEGORIES:
            if pattern.search(stripped):
                key = (category_name, stripped)
                if key in seen_lines:
                    continue
                seen_lines.add(key)

                context = ""
                if i + 1 < len(lines):
                    next_line = lines[i + 1].strip()
                    if next_line and not next_line.startswith('#'):
                        context = next_line

                covered = line_mentions_dart_fix_pair(
                    stripped, dart_fix_pairs, distinctive_members,
                )
                score = score_relevance(stripped, category_name)
                matches.append((
                    category_name, stripped, context, covered, score,
                ))

    return matches


def scan_all_sources(
    dart_fix_pairs: Set[str],
    distinctive_members: Set[str],
) -> Dict[str, Dict[str, List[ScoredMatch]]]:
    """Scan all source directories."""
    results = {}

    for source_name, versions_dir in SOURCES.items():
        if not os.path.isdir(versions_dir):
            continue

        source_results = {}
        for filename in sorted(os.listdir(versions_dir)):
            if not filename.endswith('.md'):
                continue

            filepath = os.path.join(versions_dir, filename)
            version = extract_version_from_filename(filename)
            matches = scan_file(
                filepath, dart_fix_pairs, distinctive_members,
            )

            if matches:
                source_results[version] = matches

        if source_results:
            results[source_name] = source_results

    return results


# --- Deduplication across versions ---

def deduplicate_across_versions(
    results: Dict[str, Dict[str, List[ScoredMatch]]],
) -> Dict[str, Dict[str, List[ScoredMatch]]]:
    """Remove entries that describe the same API change across versions.

    Keeps the entry in the earliest (first-introduced) version.
    """
    # Build a global map: api_key -> (source, version, match_index)
    seen_api_keys: Dict[str, Tuple[str, str]] = {}
    to_remove: Set[Tuple[str, str, int]] = set()

    for source_name, source_data in results.items():
        sorted_versions = sorted(
            source_data.keys(),
            key=lambda v: tuple(int(n) for n in re.findall(r'\d+', v)),
        )

        for version in sorted_versions:
            for idx, (cat, line, ctx, covered, score) in enumerate(
                source_data[version]
            ):
                api_key = f"{cat}:{extract_api_key(line)}"
                if api_key in seen_api_keys:
                    # Duplicate — mark for removal (keep earliest)
                    to_remove.add((source_name, version, idx))
                else:
                    seen_api_keys[api_key] = (source_name, version)

    # Build filtered results
    filtered = {}
    for source_name, source_data in results.items():
        filtered_source = {}
        for version, matches in source_data.items():
            filtered_matches = [
                m for idx, m in enumerate(matches)
                if (source_name, version, idx) not in to_remove
            ]
            if filtered_matches:
                filtered_source[version] = filtered_matches
        if filtered_source:
            filtered[source_name] = filtered_source

    return filtered


# --- Report Writing ---

def write_report(
    results: Dict[str, Dict[str, List[ScoredMatch]]],
    dart_fix_count: int,
    noise_count: int,
    pre_dedup_count: int,
):
    """Write the filtered, scored candidates report."""
    timestamp = datetime.now().strftime('%Y-%m-%d %H:%M:%S')

    actionable = 0
    covered = 0
    cat_actionable: Dict[str, int] = {}
    cat_covered: Dict[str, int] = {}

    for source_data in results.values():
        for version_matches in source_data.values():
            for cat, _, _, is_covered, _ in version_matches:
                if is_covered:
                    covered += 1
                    cat_covered[cat] = cat_covered.get(cat, 0) + 1
                else:
                    actionable += 1
                    cat_actionable[cat] = cat_actionable.get(cat, 0) + 1

    total = actionable + covered

    with open(OUTPUT_FILE, "w", encoding="utf-8") as f:
        f.write("# Lint Rule Candidates Report\n\n")
        f.write(f"Generated on: {timestamp}\n")
        f.write(f"Total candidates: {total} ")
        f.write(f"({actionable} actionable, "
                f"{covered} already handled by dart fix)\n")
        f.write(f"Noise filtered: {noise_count} lines removed "
                f"(reverts, CI, docs, engine internals)\n")
        f.write(f"Deduplicated: {pre_dedup_count - total} "
                f"cross-version duplicates removed\n")
        f.write(f"dart fix coverage: {dart_fix_count} "
                f"Class.member pairs loaded\n\n")

        # Summary table
        f.write("## Summary by Category\n\n")
        f.write("| Category | Actionable | dart fix | Description |\n")
        f.write("|----------|-----------|----------|-------------|\n")
        for cat_name, _, cat_desc in CATEGORIES:
            act = cat_actionable.get(cat_name, 0)
            cov = cat_covered.get(cat_name, 0)
            if act or cov:
                f.write(f"| {cat_name} | {act} | {cov} | {cat_desc} |\n")
        f.write("\n---\n\n")

        # Scoring legend
        f.write("## Relevance Score Guide\n\n")
        f.write("Items are scored by likelihood of being an actionable "
                "lint rule:\n")
        f.write("- Score 5+ = High confidence (specific API, "
                "old→new pattern)\n")
        f.write("- Score 3-4 = Medium confidence (mentions Dart/Flutter "
                "class)\n")
        f.write("- Score 1-2 = Low confidence (may need manual review)\n\n")
        f.write("---\n\n")

        # Actionable candidates sorted by score
        f.write("# Actionable Candidates\n\n")
        f.write("These items are NOT handled by `dart fix` and represent "
                "opportunities for saropa_lints rules.\n\n")

        for source_name, source_data in results.items():
            has_actionable = any(
                not is_covered
                for version_matches in source_data.values()
                for _, _, _, is_covered, _ in version_matches
            )
            if not has_actionable:
                continue

            f.write(f"## {source_name}\n\n")

            sorted_versions = sorted(
                source_data.keys(),
                key=lambda v: tuple(
                    int(n) for n in re.findall(r'\d+', v)
                ),
                reverse=True,
            )

            for version in sorted_versions:
                matches = [
                    m for m in source_data[version] if not m[3]
                ]
                if not matches:
                    continue

                f.write(f"### {version}\n\n")

                by_cat: Dict[str, List[Tuple[str, str, int]]] = {}
                for cat, line, context, _, score in matches:
                    by_cat.setdefault(cat, []).append(
                        (line, context, score)
                    )

                for cat_name, _, _ in CATEGORIES:
                    if cat_name not in by_cat:
                        continue
                    items = sorted(
                        by_cat[cat_name],
                        key=lambda x: x[2],
                        reverse=True,
                    )
                    f.write(
                        f"**{cat_name}** ({len(items)})\n\n"
                    )
                    for line, context, score in items:
                        score_indicator = (
                            "🔴" if score >= 5
                            else "🟡" if score >= 3
                            else "⚪"
                        )
                        f.write(f"- {score_indicator} "
                                f"[{score}] {line}\n")
                        if context:
                            f.write(f"  - _{context}_\n")
                    f.write("\n")

                f.write("---\n\n")

        # Covered section
        if covered:
            f.write("# Already Handled by dart fix\n\n")
            f.write(f"These {covered} items are already covered by "
                    "`dart fix` and should NOT be duplicated.\n\n")

            for source_name, source_data in results.items():
                has_covered = any(
                    is_covered
                    for version_matches in source_data.values()
                    for _, _, _, is_covered, _ in version_matches
                )
                if not has_covered:
                    continue

                f.write(f"## {source_name} (dart fix covered)\n\n")

                sorted_versions = sorted(
                    source_data.keys(),
                    key=lambda v: tuple(
                        int(n) for n in re.findall(r'\d+', v)
                    ),
                    reverse=True,
                )

                for version in sorted_versions:
                    matches = [
                        m for m in source_data[version] if m[3]
                    ]
                    if not matches:
                        continue

                    f.write(f"### {version}\n\n")
                    for _, line, _, _, _ in matches:
                        f.write(f"- ~~{line}~~\n")
                    f.write("\n---\n\n")

    print(f"Report written to: {OUTPUT_FILE}")
    print(f"Total: {total} ({actionable} actionable, "
          f"{covered} dart-fix-covered)")
    print(f"Noise filtered: {noise_count} lines")
    print(f"Deduplicated: {pre_dedup_count - total} entries")
    for cat_name, _, _ in CATEGORIES:
        act = cat_actionable.get(cat_name, 0)
        cov = cat_covered.get(cat_name, 0)
        if act or cov:
            print(f"  {cat_name}: {act} actionable, {cov} dart-fix")


if __name__ == "__main__":
    dart_fix_pairs, distinctive_members = load_dart_fix_pairs()
    print(f"Loaded {len(dart_fix_pairs)} dart fix Class.member pairs")
    print(f"  ({len(distinctive_members)} distinctive member names "
          f"for member-only matching)")

    # Scan with noise counting
    results = scan_all_sources(dart_fix_pairs, distinctive_members)

    # Count pre-dedup totals
    pre_dedup = sum(
        len(matches)
        for source_data in results.values()
        for matches in source_data.values()
    )

    # Count noise (re-scan without noise filter to get the delta)
    noise_count = 0
    for source_name, versions_dir in SOURCES.items():
        if not os.path.isdir(versions_dir):
            continue
        for filename in sorted(os.listdir(versions_dir)):
            if not filename.endswith('.md'):
                continue
            filepath = os.path.join(versions_dir, filename)
            with open(filepath, "r", encoding="utf-8") as f:
                for line in f:
                    stripped = line.strip()
                    if not stripped or stripped.startswith('#'):
                        continue
                    if is_noise(stripped):
                        # Check if any category would have matched
                        for _, pattern, _ in CATEGORIES:
                            if pattern.search(stripped):
                                noise_count += 1
                                break

    print(f"Noise filtered: {noise_count} lines")

    # Deduplicate across versions
    results = deduplicate_across_versions(results)

    post_dedup = sum(
        len(matches)
        for source_data in results.values()
        for matches in source_data.values()
    )
    print(f"After dedup: {post_dedup} "
          f"(removed {pre_dedup - post_dedup} duplicates)")

    write_report(results, len(dart_fix_pairs), noise_count, pre_dedup)
