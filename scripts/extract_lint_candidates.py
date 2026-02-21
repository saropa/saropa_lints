"""
Scans scraped release notes (Flutter SDK, Dart SDK, Dart-Code) to extract
lint rule candidates — deprecations, new features, new parameters, breaking
changes, and performance improvements that could be detected by static analysis.

Usage:
    python scripts/extract_lint_candidates.py

Output:
    scripts/lint_candidates_report.md
"""

import os
import re
from datetime import datetime
from typing import Dict, List, Tuple

# --- Configuration ---
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
OUTPUT_FILE = os.path.join(BASE_DIR, "lint_candidates_report.md")

SOURCES = {
    "Flutter SDK": os.path.join(BASE_DIR, "flutter_sdk_exports", "versions"),
    "Dart SDK": os.path.join(BASE_DIR, "dart_sdk_exports", "versions"),
    "Dart-Code": os.path.join(BASE_DIR, "dart_code_exports", "versions"),
}

# --- Candidate Categories ---
# Each category has: (label, keywords_regex, description)
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
            r'(?:widget|class|method|function|mixin|extension|enum|typedef|property|getter|setter|field|API|parameter|argument|option|flag|feature|syntax|keyword|annotation|modifier|operator))',
            re.IGNORECASE,
        ),
        "New capability — lint can detect verbose pattern and suggest the new API",
    ),
    (
        "New Parameter / Option",
        re.compile(
            r'(?:(?:new|added?|introduc(?:ed?|ing))\s+(?:an?\s+)?'
            r'(?:optional|named|required|positional)?\s*'
            r'(?:param(?:eter)?|arg(?:ument)?|option|flag|field|property|setting|config))',
            re.IGNORECASE,
        ),
        "New parameter — lint can suggest using the new option for better behavior",
    ),
    (
        "Performance Improvement",
        re.compile(
            r'(?:(?:improv|optimiz|faster|reduc(?:ed?|ing)|speed up|'
            r'more efficient|eliminat(?:ed?|ing)\s+(?:unnecessary|redundant))|'
            r'lazy\s+(?:load|init)|cache[ds]?\s)',
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


def extract_version_from_filename(filename: str) -> str:
    """Extract version string from filename like 'flutter-3.41.0.md'."""
    match = re.search(r'[\d][\d.]+[\d]', filename)
    if match:
        return match.group(0)
    # Dart-Code style: v3-128
    match = re.search(r'v\d+-\d+', filename)
    return match.group(0) if match else filename


def scan_file(filepath: str) -> List[Tuple[str, str, str]]:
    """
    Scan a single version file for lint rule candidates.
    Returns list of (category, matched_line, context).
    """
    with open(filepath, "r", encoding="utf-8") as f:
        lines = f.readlines()

    matches = []
    seen_lines = set()

    for i, line in enumerate(lines):
        stripped = line.strip()
        if not stripped or stripped.startswith('#'):
            continue

        for category_name, pattern, _ in CATEGORIES:
            if pattern.search(stripped):
                # Dedup: same line can match multiple categories, that's OK
                # But skip exact duplicate (same category + same line)
                key = (category_name, stripped)
                if key in seen_lines:
                    continue
                seen_lines.add(key)

                # Grab 1 line of context after for more detail
                context = ""
                if i + 1 < len(lines):
                    next_line = lines[i + 1].strip()
                    if next_line and not next_line.startswith('#'):
                        context = next_line

                matches.append((category_name, stripped, context))

    return matches


def scan_all_sources() -> Dict[str, Dict[str, List[Tuple[str, str, str]]]]:
    """
    Scan all source directories.
    Returns: {source_name: {version: [(category, line, context), ...]}}
    """
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
            matches = scan_file(filepath)

            if matches:
                source_results[version] = matches

        if source_results:
            results[source_name] = source_results

    return results


def write_report(results: Dict[str, Dict[str, List[Tuple[str, str, str]]]]):
    """Write the filtered candidates report."""
    timestamp = datetime.now().strftime('%Y-%m-%d %H:%M:%S')

    # Count totals
    total_candidates = 0
    category_counts: Dict[str, int] = {}
    for source_data in results.values():
        for version_matches in source_data.values():
            for cat, _, _ in version_matches:
                total_candidates += 1
                category_counts[cat] = category_counts.get(cat, 0) + 1

    with open(OUTPUT_FILE, "w", encoding="utf-8") as f:
        f.write("# Lint Rule Candidates Report\n\n")
        f.write(f"Generated on: {timestamp}\n")
        f.write(f"Total candidates: {total_candidates}\n\n")

        # Summary table
        f.write("## Summary by Category\n\n")
        f.write("| Category | Count | Description |\n")
        f.write("|----------|-------|-------------|\n")
        for cat_name, _, cat_desc in CATEGORIES:
            count = category_counts.get(cat_name, 0)
            if count:
                f.write(f"| {cat_name} | {count} | {cat_desc} |\n")
        f.write("\n---\n\n")

        # Per-source, per-version breakdown
        for source_name, source_data in results.items():
            f.write(f"## {source_name}\n\n")

            # Sort versions descending
            sorted_versions = sorted(
                source_data.keys(),
                key=lambda v: tuple(int(n) for n in re.findall(r'\d+', v)),
                reverse=True,
            )

            for version in sorted_versions:
                matches = source_data[version]
                f.write(f"### {version}\n\n")

                # Group by category
                by_cat: Dict[str, List[Tuple[str, str]]] = {}
                for cat, line, context in matches:
                    by_cat.setdefault(cat, []).append((line, context))

                for cat_name, _, _ in CATEGORIES:
                    if cat_name not in by_cat:
                        continue
                    f.write(f"**{cat_name}** ({len(by_cat[cat_name])})\n\n")
                    for line, context in by_cat[cat_name]:
                        f.write(f"- {line}\n")
                        if context:
                            f.write(f"  - _{context}_\n")
                    f.write("\n")

                f.write("---\n\n")

    print(f"Report written to: {OUTPUT_FILE}")
    print(f"Total candidates: {total_candidates}")
    for cat_name, _, _ in CATEGORIES:
        count = category_counts.get(cat_name, 0)
        if count:
            print(f"  {cat_name}: {count}")


if __name__ == "__main__":
    results = scan_all_sources()
    write_report(results)
