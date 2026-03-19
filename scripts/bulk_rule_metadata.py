#!/usr/bin/env python3
"""
Bulk-add ruleType and tags to SaropaLintRule classes by folder.
Run from repo root: python scripts/bulk_rule_metadata.py
Skips files that already contain 'get ruleType =>' (idempotent).
"""
from pathlib import Path
import re

RULES_DIR = Path("lib/src/rules")

# Order matters: first matching path wins. More specific paths first.
# (path_contains_any, rule_type, tags)
PATH_MAPPING = [
    # Security (vulnerability by default; securityHotspot can be refined later)
    (["security/"], "RuleType.vulnerability", {"security"}),
    (["platforms/ios_ui_security"], "RuleType.vulnerability", {"security", "flutter"}),
    # Disposal/leaks = bug
    (["architecture/disposal"], "RuleType.bug", {"disposal", "reliability", "flutter"}),
    # Accessibility
    (["ui/accessibility"], "RuleType.codeSmell", {"accessibility", "a11y", "flutter"}),
    # Stylistic = code smell, convention
    (["stylistic/"], "RuleType.codeSmell", {"convention"}),
    # Code quality
    (["code_quality/"], "RuleType.codeSmell", {"maintainability"}),
    # Flow (error handling, control flow, etc.)
    (["flow/"], "RuleType.codeSmell", {"reliability"}),
    # Architecture (non-disposal)
    (["architecture/"], "RuleType.codeSmell", {"architecture"}),
    # Core (async, performance, naming, etc.)
    (["core/"], "RuleType.codeSmell", {"dart-core"}),
    # Data
    (["data/"], "RuleType.codeSmell", {"reliability", "type-safety"}),
    # Widget / UI
    (["widget/"], "RuleType.codeSmell", {"flutter", "ui"}),
    (["ui/"], "RuleType.codeSmell", {"flutter", "ui"}),
    # Testing
    (["testing/"], "RuleType.codeSmell", {"testing"}),
    # Platforms (non-security)
    (["platforms/"], "RuleType.codeSmell", {"flutter", "platform"}),
    # Packages (third-party)
    (["packages/"], "RuleType.codeSmell", {"packages"}),
    # Network
    (["network/"], "RuleType.codeSmell", {"network"}),
    # Resources
    (["resources/"], "RuleType.codeSmell", {"resources"}),
    # Config
    (["config/"], "RuleType.codeSmell", {"config"}),
    # Media
    (["media/"], "RuleType.codeSmell", {"media"}),
    # Commerce (IAP can be security-sensitive but treat as codeSmell for bulk)
    (["commerce/"], "RuleType.codeSmell", {"commerce"}),
    # Hardware
    (["hardware/"], "RuleType.codeSmell", {"hardware"}),
    # Codegen
    (["codegen/"], "RuleType.codeSmell", {"codegen"}),
]

# Match @override, then newline/whitespace, then LintImpact get impact => ...
IMPACT_PATTERN = re.compile(
    r"(  @override\s+  LintImpact get impact => LintImpact\.(?:critical|high|medium|low|opinionated);)"
)


def get_metadata_for_path(relpath: str) -> tuple[str, set[str]]:
    relpath = relpath.replace("\\", "/")
    for parts, rule_type, tags in PATH_MAPPING:
        if any(p in relpath for p in parts):
            return rule_type, tags
    return "RuleType.codeSmell", {"convention"}  # fallback


def format_tags(tags: set[str]) -> str:
    return "const {" + ", ".join(repr(t) for t in sorted(tags)) + "}"


def process_file(path: Path, rule_type: str, tags: set[str]) -> bool:
    content = path.read_text(encoding="utf-8")
    if "get ruleType =>" in content:
        return False  # already has metadata
    if "LintImpact get impact =>" not in content:
        return False  # no impact override (uses default)
    tags_str = format_tags(tags)
    insertion = (
        f"\n\n  @override\n  RuleType? get ruleType => {rule_type};\n\n  @override\n  Set<String> get tags => {tags_str};"
    )
    new_content = IMPACT_PATTERN.sub(r"\1" + insertion, content)
    if new_content == content:
        return False
    path.write_text(new_content, encoding="utf-8")
    return True


def main() -> None:
    root = Path(__file__).resolve().parent.parent
    rules_dir = root / RULES_DIR
    if not rules_dir.is_dir():
        print(f"Not found: {rules_dir}")
        return
    updated = 0
    skipped = 0
    for f in sorted(rules_dir.rglob("*_rules.dart")):
        if f.name == "all_rules.dart":
            continue
        relpath = str(f.relative_to(rules_dir))
        rule_type, tags = get_metadata_for_path(relpath)
        if process_file(f, rule_type, tags):
            updated += 1
            print(f"Updated: {relpath}")
        else:
            skipped += 1
    print(f"\nDone. Updated: {updated}, skipped (no change or already has metadata): {skipped}")


if __name__ == "__main__":
    main()
