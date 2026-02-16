#!/usr/bin/env python3
"""Migrate saropa_lints rule files from custom_lint to native analyzer plugin.

Handles mechanical transformations:
1. Remove custom_lint_builder import
2. Transform LintCode constructors (named → positional params, errorSeverity → severity)
3. Remove const from rule constructors (AnalysisRule can't be const)
4. Change runWithReporter signature (drop resolver param, CustomLintContext → SaropaContext)
5. Replace resolver.xxx usages with context.xxx equivalents
6. Change context.registry.addXxx → context.addXxx
7. Change reporter.atNode(node, code) → reporter.atNode(node)
8. Remove getFixes() overrides, customFixes overrides, and DartFix classes
9. Clean up unused imports
"""

import re
import sys
from pathlib import Path


def migrate_file(filepath: str) -> tuple[int, list[str]]:
    """Migrate a single file. Returns (change_count, warnings)."""
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    original = content
    warnings = []
    changes = 0

    # =========================================================================
    # 1. Remove custom_lint_builder import
    # =========================================================================
    old = content
    content = re.sub(
        r"import 'package:custom_lint_builder/custom_lint_builder\.dart';\n",
        '',
        content,
    )
    if content != old:
        changes += 1

    # =========================================================================
    # 2. Transform LintCode constructors: named → positional for name/message
    # =========================================================================

    # Step 2a: Change errorSeverity → severity
    old = content
    content = content.replace('errorSeverity:', 'severity:')
    if content != old:
        changes += 1

    # Step 2b: Remove 'name:' prefix (make positional)
    # Pattern: name: 'rule_name', → 'rule_name',
    old = content
    content = re.sub(
        r"(\s+)name:\s*'([^']*)',",
        r"\1'\2',",
        content,
    )
    if content != old:
        changes += 1

    # Step 2c: Remove 'problemMessage:' prefix (make positional)
    # This handles both single-line and start of multi-line, with ' or " quotes
    old = content
    content = re.sub(
        r"(\s+)problemMessage:\s*\n?\s*(['\"])",
        r"\1\2",
        content,
    )
    if content != old:
        changes += 1

    # =========================================================================
    # 3. Remove const from rule constructors
    # =========================================================================
    # AnalysisRule has `late DiagnosticReporter _reporter` → can't be const.
    # Pattern: const MyRule() : super(code: _code);
    old = content
    content = re.sub(
        r'(\s+)const (\w+)\(\)\s*:\s*super\(code:\s*_code\)',
        r'\1\2() : super(code: _code)',
        content,
    )
    if content != old:
        changes += 1

    # =========================================================================
    # 4. Transform runWithReporter signature
    # =========================================================================
    # Remove CustomLintResolver parameter line
    old = content
    content = re.sub(
        r'\s*CustomLintResolver\s+\w+,\s*\n',
        '\n',
        content,
    )
    if content != old:
        changes += 1

    # Change CustomLintContext → SaropaContext
    old = content
    content = content.replace('CustomLintContext context', 'SaropaContext context')
    if content != old:
        changes += 1

    # =========================================================================
    # 5. Replace resolver.xxx usages with context.xxx equivalents
    # =========================================================================
    old = content

    # resolver.source.fullName → context.filePath
    content = content.replace('resolver.source.fullName', 'context.filePath')

    # resolver.source.uri.path → context.filePath
    content = content.replace('resolver.source.uri.path', 'context.filePath')

    # resolver.source.contents.data → context.fileContent
    content = content.replace('resolver.source.contents.data', 'context.fileContent')

    # resolver.path → context.filePath
    # Be careful not to match 'resolver.path' inside a string or comment
    content = re.sub(r'\bresolver\.path\b', 'context.filePath', content)

    # resolver.lineInfo → context.lineInfo
    content = content.replace('resolver.lineInfo', 'context.lineInfo')

    if content != old:
        changes += 1

    # =========================================================================
    # 6. Change context.registry.addXxx → context.addXxx
    # =========================================================================
    # Handle multi-line: context.registry\n    .addXxx → context\n    .addXxx
    old = content
    content = re.sub(r'context\.registry\s*\.add', 'context.add', content)
    if content != old:
        changes += 1

    # =========================================================================
    # 7. Change reporter.atNode(node, code) → reporter.atNode(node)
    # =========================================================================
    old = content
    # Handle reporter.atNode(node, code) and reporter.atNode(node, _code)
    content = re.sub(
        r'reporter\.atNode\((\w+),\s*_?code\)',
        r'reporter.atNode(\1)',
        content,
    )
    if content != old:
        changes += 1

    # Handle reporter.atToken(token, code)
    old = content
    content = re.sub(
        r'reporter\.atToken\((\w+),\s*_?code\)',
        r'reporter.atToken(\1)',
        content,
    )
    if content != old:
        changes += 1

    # =========================================================================
    # 8. Remove getFixes() overrides (single and multi-line)
    # =========================================================================
    old = content
    content = re.sub(
        r'\s*@override\s*\n\s*List<Fix>\s+getFixes\(\)\s*=>[\s\S]*?;\s*\n',
        '\n',
        content,
    )
    if content != old:
        changes += 1

    # =========================================================================
    # 9. Remove customFixes overrides
    # =========================================================================
    old = content
    content = re.sub(
        r'\s*@override\s*\n\s*List<Fix>\s+get\s+customFixes\s*=>[\s\S]*?;\s*\n',
        '\n',
        content,
    )
    if content != old:
        changes += 1

    # =========================================================================
    # 10. Remove DartFix classes (entire class blocks)
    # =========================================================================
    old = content
    while True:
        match = re.search(
            r'\nclass\s+_\w+Fix\s+extends\s+DartFix\s*\{',
            content,
        )
        if not match:
            break
        start = match.start()
        # Find matching closing brace
        depth = 0
        pos = match.end() - 1  # Start at the opening brace
        while pos < len(content):
            if content[pos] == '{':
                depth += 1
            elif content[pos] == '}':
                depth -= 1
                if depth == 0:
                    content = content[:start] + content[pos + 1:]
                    break
            pos += 1
        else:
            warnings.append(
                f"Could not find closing brace for DartFix class at {start}"
            )
            break
    if content != old:
        changes += 1

    # =========================================================================
    # 11. Remove unused imports
    # =========================================================================
    # Remove AnalysisError import if no longer used (outside import lines)
    if 'AnalysisError' not in re.sub(r"^import .*$", "", content, flags=re.MULTILINE):
        old = content
        content = re.sub(
            r"import 'package:analyzer/error/error\.dart'\s*show[^;]*AnalysisError[^;]*;\n",
            '',
            content,
        )
        if content != old:
            changes += 1

    # Remove SourceRange import if no longer used
    if content.count('SourceRange') <= 1:
        old = content
        content = re.sub(
            r"import 'package:analyzer/source/source_range\.dart';\n",
            '',
            content,
        )
        if content != old:
            changes += 1

    # =========================================================================
    # 12. Clean up show lists referencing removed types
    # =========================================================================
    old = content
    content = re.sub(r',?\s*AddIgnoreCommentFix', '', content)
    content = re.sub(r',?\s*AddIgnoreForFileFix', '', content)
    content = re.sub(r',?\s*WrapInTryCatchFix', '', content)
    if content != old:
        changes += 1

    # =========================================================================
    # 13. Remove _findContainingStatement helper methods (fix-only)
    # =========================================================================
    old = content
    content = re.sub(
        r'\n\s*AstNode\?\s+_findContainingStatement\(AstNode[^}]*\}\s*\n\s*return null;\s*\n\s*\}',
        '',
        content,
        flags=re.DOTALL,
    )
    if content != old:
        changes += 1

    # =========================================================================
    # 14. Clean up extra blank lines
    # =========================================================================
    content = re.sub(r'\n{4,}', '\n\n\n', content)

    if content != original:
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(content)

    return changes, warnings


def main():
    root = Path(__file__).parent.parent
    rules_dir = root / 'lib' / 'src' / 'rules'

    if not rules_dir.exists():
        print(f"ERROR: {rules_dir} not found")
        sys.exit(1)

    total_changes = 0
    all_warnings = []

    # Process all Dart files in rules directory
    files = sorted(rules_dir.glob('**/*.dart'))
    print(f"Found {len(files)} files to process")

    for filepath in files:
        if filepath.name == 'all_rules.dart':
            continue  # Skip barrel file

        count, warnings = migrate_file(str(filepath))
        if count > 0:
            print(f"  {filepath.name}: {count} changes")
        if warnings:
            for w in warnings:
                print(f"    WARNING: {w}")
            all_warnings.extend(warnings)
        total_changes += count

    print(f"\nTotal: {total_changes} changes across {len(files)} files")
    if all_warnings:
        print(f"Warnings: {len(all_warnings)}")


if __name__ == '__main__':
    main()
