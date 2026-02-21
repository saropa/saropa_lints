"""
Generates detailed migration report files from high-confidence lint candidates.

Fetches PR details via `gh api` for additional context, then writes
individual report files to the specified output directory.

Usage:
    python scripts/_generate_migration_reports.py [--batch N] [--batch-size M]

    --batch N       Only generate batch N (1-indexed). Default: all batches.
    --batch-size M  Items per batch. Default: 25.
"""

import json
import os
import re
import subprocess
import sys
import time
from typing import Dict, Optional

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
ITEMS_FILE = os.path.join(BASE_DIR, "_high_confidence_items.json")
OUTPUT_DIR = os.path.join(os.path.dirname(BASE_DIR), "bugs")
PR_CACHE_FILE = os.path.join(BASE_DIR, "_pr_details_cache.json")

PREFIX = "migration-candidate"

# Rate limit: GitHub API allows 5000/hour for authenticated users
GH_API_DELAY = 0.3  # seconds between requests


def load_items():
    with open(ITEMS_FILE, "r", encoding="utf-8") as f:
        return json.load(f)


def load_pr_cache() -> Dict:
    if os.path.exists(PR_CACHE_FILE):
        with open(PR_CACHE_FILE, "r", encoding="utf-8") as f:
            return json.load(f)
    return {}


def save_pr_cache(cache: Dict):
    with open(PR_CACHE_FILE, "w", encoding="utf-8") as f:
        json.dump(cache, f, indent=2, ensure_ascii=False)


def fetch_pr_details(pr_url: str, cache: Dict) -> Optional[Dict]:
    """Fetch PR title, body, and labels from GitHub API."""
    if not pr_url:
        return None

    if pr_url in cache:
        return cache[pr_url]

    # Parse owner/repo/number from URL
    match = re.search(
        r'github\.com/([^/]+)/([^/]+)/pull/(\d+)', pr_url,
    )
    if not match:
        return None

    owner, repo, number = match.groups()
    api_path = f"repos/{owner}/{repo}/pulls/{number}"

    try:
        result = subprocess.run(
            [
                "gh", "api", api_path,
                "--jq",
                '{title: .title, body: .body, '
                'labels: [.labels[].name], '
                'state: .state, merged: .merged, '
                'user: .user.login}',
            ],
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="replace",
            timeout=15,
        )
        if result.returncode == 0 and result.stdout.strip():
            details = json.loads(result.stdout.strip())
            # Truncate body to 2000 chars
            if details.get("body"):
                details["body"] = details["body"][:2000]
            cache[pr_url] = details
            time.sleep(GH_API_DELAY)
            return details
    except (subprocess.TimeoutExpired, json.JSONDecodeError, Exception) as e:
        print(f"  Warning: Failed to fetch {api_path}: {e}")

    return None


def sanitize_filename(text: str) -> str:
    """Create a safe filename from text."""
    # Remove markdown, URLs, PR numbers, author refs
    cleaned = re.sub(r'\[?\d+\]?\(https?://[^)]+\)', '', text)
    cleaned = re.sub(r'https?://\S+', '', cleaned)
    cleaned = re.sub(r'by @\w+\S*', '', cleaned)
    cleaned = re.sub(r'[`*_#\[\]()]', '', cleaned)
    cleaned = re.sub(r'\*\s*', '', cleaned)
    # Remove leading bullet/star
    cleaned = re.sub(r'^\s*[\*\-]\s*', '', cleaned)
    # Remove tag prefixes like [Material], [web], etc.
    cleaned = re.sub(r'^\[[\w\s\-]+\]\s*', '', cleaned)
    # Convert to snake_case-ish
    cleaned = cleaned.strip().lower()
    cleaned = re.sub(r'[^a-z0-9]+', '_', cleaned)
    cleaned = re.sub(r'_+', '_', cleaned).strip('_')
    # Limit length
    return cleaned[:60]


def extract_api_names(text: str) -> list:
    """Extract API/class names from text."""
    names = []
    # Backtick content
    for m in re.finditer(r'`([^`]+)`', text):
        names.append(m.group(1))
    # CamelCase identifiers
    for m in re.finditer(r'\b([A-Z][a-z]\w+(?:\.[a-z]\w+)?)\b', text):
        name = m.group(1)
        if name not in ('Dart', 'Flutter', 'Google', 'GitHub',
                        'Material', 'Cupertino', 'Windows', 'Linux',
                        'Android', 'Chrome', 'Safari', 'Firefox'):
            names.append(name)
    return list(dict.fromkeys(names))  # deduplicate, preserve order


def categorize_for_lint(item: Dict) -> Dict:
    """Determine what kind of lint rule this could become."""
    text = item["text"].lower()
    category = item["category"]

    lint_info = {
        "rule_type": "",
        "detection_strategy": "",
        "fix_strategy": "",
        "ast_nodes": [],
        "difficulty": "medium",
    }

    if category == "Deprecation":
        lint_info["rule_type"] = "deprecation_migration"
        lint_info["detection_strategy"] = (
            "Detect usage of the deprecated API via AST method/property "
            "invocation nodes"
        )
        lint_info["fix_strategy"] = (
            "Replace with the recommended alternative API"
        )
        lint_info["ast_nodes"] = [
            "MethodInvocation", "PropertyAccess",
            "PrefixedIdentifier", "SimpleIdentifier",
        ]
    elif category == "Breaking Change":
        lint_info["rule_type"] = "breaking_change_migration"
        lint_info["detection_strategy"] = (
            "Detect usage of removed/changed API signatures"
        )
        lint_info["fix_strategy"] = (
            "Replace with the new API signature or pattern"
        )
        lint_info["ast_nodes"] = [
            "MethodInvocation", "InstanceCreationExpression",
        ]
    elif category == "New Feature / API":
        lint_info["rule_type"] = "prefer_new_api"
        lint_info["detection_strategy"] = (
            "Detect verbose/old pattern that could use the new API"
        )
        lint_info["fix_strategy"] = (
            "Suggest using the new, more concise API"
        )
        lint_info["ast_nodes"] = ["MethodInvocation", "ExpressionStatement"]
    elif category == "New Parameter / Option":
        lint_info["rule_type"] = "prefer_new_parameter"
        lint_info["detection_strategy"] = (
            "Detect API calls missing the new parameter"
        )
        lint_info["fix_strategy"] = (
            "Suggest adding the new parameter for better behavior"
        )
        lint_info["ast_nodes"] = [
            "MethodInvocation", "InstanceCreationExpression",
            "ArgumentList",
        ]
    elif category == "Performance Improvement":
        lint_info["rule_type"] = "prefer_performant_api"
        lint_info["detection_strategy"] = (
            "Detect the slower old pattern"
        )
        lint_info["fix_strategy"] = (
            "Replace with the faster/more efficient alternative"
        )
        lint_info["ast_nodes"] = ["MethodInvocation"]
    elif category == "Replacement / Migration":
        lint_info["rule_type"] = "prefer_replacement"
        lint_info["detection_strategy"] = (
            "Detect old pattern and suggest the replacement"
        )
        lint_info["fix_strategy"] = (
            "Replace old API/pattern with the new recommended approach"
        )
        lint_info["ast_nodes"] = [
            "MethodInvocation", "PropertyAccess",
            "SimpleIdentifier",
        ]

    # Estimate difficulty
    if any(w in text for w in ("simple", "rename", "parameter")):
        lint_info["difficulty"] = "easy"
    elif any(w in text for w in ("pattern", "refactor", "architecture")):
        lint_info["difficulty"] = "hard"

    return lint_info


def generate_report(
    index: int, item: Dict, pr_details: Optional[Dict],
) -> str:
    """Generate a detailed migration report for one item."""
    api_names = extract_api_names(item["text"])
    lint_info = categorize_for_lint(item)

    # Clean up the PR text
    clean_text = re.sub(r'^\*\s*', '', item["text"]).strip()

    lines = []
    lines.append(f"# Migration Candidate #{index:03d}")
    lines.append("")
    lines.append(f"**Source:** {item['source']} {item['version']}")
    lines.append(f"**Category:** {item['category']}")
    lines.append(f"**Relevance Score:** {item['score']}")
    lines.append(f"**Detected APIs:** {', '.join(api_names) or 'N/A'}")
    lines.append("")
    lines.append("---")
    lines.append("")

    # Original entry
    lines.append("## Release Note Entry")
    lines.append("")
    lines.append(f"> {clean_text}")
    if item.get("context"):
        lines.append(f">")
        lines.append(f"> Context: {item['context']}")
    lines.append("")

    if item.get("pr_url"):
        lines.append(f"**PR:** {item['pr_url']}")
        lines.append("")

    # PR details if available
    if pr_details:
        lines.append("## PR Details")
        lines.append("")
        if pr_details.get("title"):
            lines.append(f"**Title:** {pr_details['title']}")
        if pr_details.get("user"):
            lines.append(f"**Author:** @{pr_details['user']}")
        if pr_details.get("state"):
            state = pr_details["state"]
            if pr_details.get("merged"):
                state = "merged"
            lines.append(f"**Status:** {state}")
        if pr_details.get("labels"):
            lines.append(
                f"**Labels:** {', '.join(pr_details['labels'])}"
            )
        lines.append("")
        if pr_details.get("body"):
            body = pr_details["body"].strip()
            # Truncate at 1500 chars for report
            if len(body) > 1500:
                body = body[:1500] + "\n\n[... truncated]"
            lines.append("### Description")
            lines.append("")
            lines.append(body)
            lines.append("")

    # Migration analysis
    lines.append("---")
    lines.append("")
    lines.append("## Migration Analysis")
    lines.append("")

    # What changed
    lines.append("### What Changed")
    lines.append("")
    if item["category"] == "Deprecation":
        lines.append(
            "An API has been deprecated. Users still using the old API "
            "should migrate to the recommended replacement."
        )
    elif item["category"] == "Breaking Change":
        lines.append(
            "An API has been removed or its signature changed. "
            "Code using the old API will fail to compile."
        )
    elif item["category"] == "Replacement / Migration":
        lines.append(
            "A better pattern or API is now available. The old approach "
            "still works but the new one is preferred."
        )
    elif item["category"] == "New Feature / API":
        lines.append(
            "A new API has been introduced that simplifies a common "
            "pattern. Users can benefit from adopting it."
        )
    elif item["category"] == "New Parameter / Option":
        lines.append(
            "A new parameter has been added that provides better "
            "behavior or additional control."
        )
    elif item["category"] == "Performance Improvement":
        lines.append(
            "A performance optimization is available. The old pattern "
            "works but is slower."
        )
    lines.append("")

    # APIs involved
    if api_names:
        lines.append("### APIs Involved")
        lines.append("")
        for name in api_names:
            lines.append(f"- `{name}`")
        lines.append("")

    # Lint rule proposal
    lines.append("---")
    lines.append("")
    lines.append("## Proposed Lint Rule")
    lines.append("")
    lines.append(f"**Rule Type:** `{lint_info['rule_type']}`")
    lines.append(f"**Estimated Difficulty:** {lint_info['difficulty']}")
    lines.append("")

    lines.append("### Detection Strategy")
    lines.append("")
    lines.append(lint_info["detection_strategy"])
    lines.append("")
    if lint_info["ast_nodes"]:
        lines.append("**Relevant AST nodes:**")
        for node in lint_info["ast_nodes"]:
            lines.append(f"- `{node}`")
        lines.append("")

    lines.append("### Fix Strategy")
    lines.append("")
    lines.append(lint_info["fix_strategy"])
    lines.append("")

    # Implementation checklist
    lines.append("---")
    lines.append("")
    lines.append("## Implementation Checklist")
    lines.append("")
    lines.append("- [ ] Verify the API change in Flutter/Dart SDK source")
    lines.append("- [ ] Determine minimum SDK version requirement")
    lines.append("- [ ] Write detection logic (AST visitor)")
    lines.append("- [ ] Write quick-fix replacement")
    lines.append("- [ ] Create test fixture with bad/good examples")
    lines.append("- [ ] Add unit tests")
    lines.append("- [ ] Register rule in `all_rules.dart`")
    lines.append("- [ ] Add to tier in `tiers.dart`")
    lines.append("- [ ] Update ROADMAP.md")
    lines.append("- [ ] Update CHANGELOG.md")
    lines.append("")

    # Status
    lines.append("---")
    lines.append("")
    lines.append("**Status:** Not started")
    lines.append(
        f"**Generated:** From {item['source']} "
        f"v{item['version']} release notes"
    )
    lines.append("")

    return "\n".join(lines)


def main():
    import argparse
    parser = argparse.ArgumentParser()
    parser.add_argument("--batch", type=int, default=0)
    parser.add_argument("--batch-size", type=int, default=25)
    args = parser.parse_args()

    items = load_items()
    pr_cache = load_pr_cache()

    os.makedirs(OUTPUT_DIR, exist_ok=True)

    total = len(items)
    batch_size = args.batch_size

    if args.batch > 0:
        start = (args.batch - 1) * batch_size
        end = min(start + batch_size, total)
        batches = [(start, end)]
    else:
        batches = []
        for start in range(0, total, batch_size):
            end = min(start + batch_size, total)
            batches.append((start, end))

    files_written = 0

    for batch_start, batch_end in batches:
        print(f"\n=== Batch: items {batch_start+1}-{batch_end} "
              f"of {total} ===\n")

        for i in range(batch_start, batch_end):
            item = items[i]
            index = i + 1  # 1-indexed

            # Fetch PR details
            pr_details = None
            if item.get("pr_url"):
                pr_details = fetch_pr_details(item["pr_url"], pr_cache)

            # Generate filename
            slug = sanitize_filename(item["text"])
            filename = f"{PREFIX}-{index:03d}-{slug}.md"
            filepath = os.path.join(OUTPUT_DIR, filename)

            # Generate report
            report = generate_report(index, item, pr_details)

            with open(filepath, "w", encoding="utf-8") as f:
                f.write(report)

            files_written += 1
            short_text = item["text"][:70].replace("\n", " ")
            pr_status = "+ PR" if pr_details else "- no PR"
            print(f"  [{index:3d}/{total}] {pr_status} {filename}")

        # Save cache after each batch
        save_pr_cache(pr_cache)
        print(f"\n  Cache saved ({len(pr_cache)} PRs cached)")

    print(f"\n=== Done: {files_written} files written to {OUTPUT_DIR} ===")


if __name__ == "__main__":
    main()
