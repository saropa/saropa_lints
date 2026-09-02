import 'dart:io';

import 'package:test/test.dart';

/// Resolved-type API patterns that force the analyzer's lazy cross-library
/// element resolution. Any rule using these MUST declare
/// `usesTypeResolution => true` so balanced mode can skip it on unchanged
/// files. Conversely, rules declaring the flag without using any of these
/// waste a light-lane slot by routing to the scan daemon unnecessarily.
/// Includes modern element-model APIs (`formalParameters`,
/// `hasDefaultValue`, `defaultValueCode`) that replaced the older
/// `staticElement` call chain but still require full resolution.
/// Matches resolved-type API calls. Includes `NamedType.element` via
/// `.superclass.element` and `.constructorName.type.element` — both
/// access the same type-resolution API through different AST paths.
final _resolvedTypePatterns = RegExp(
  r'\.(staticType|allSupertypes|thisType|resolvedType'
  r'|declaredElement|staticElement|enclosingElement'
  r'|formalParameters|hasDefaultValue|defaultValueCode)\b'
  r'|\.superclass\.element\b'
  r'|\.constructorName\.type\.element\b',
);

/// Matches `.library` access on elements — a resolved-type trigger — but
/// excludes string literals like `'dart.library.io'` and doc-comment
/// references. Only bare `.library` after an identifier or closing paren
/// counts as an element model access.
final _libraryAccessPattern = RegExp(r'(?<=[a-zA-Z)\]])\.library\b');

/// True if [content] contains any resolved-type API call outside of
/// comments and string literals. Uses a heuristic (regex, not AST) —
/// sufficient for integrity enforcement but may miss edge cases.
bool _usesResolvedTypeApis(String content) {
  // Strip single-line comments and doc comments to avoid matching
  // patterns like `// uses .staticType to check...` in prose.
  final stripped = content.replaceAll(RegExp(r'///.*|//.*'), '');
  return _resolvedTypePatterns.hasMatch(stripped) ||
      _libraryAccessPattern.hasMatch(stripped);
}

/// Integrity tests for `usesTypeResolution` correctness in rule files.
/// Both directions are tested:
/// 1. Files using resolved APIs must declare the flag (missing = perf bug)
/// 2. Files declaring the flag must use resolved APIs (false claim = wasted
///    light-lane capacity, forces rule into the scan daemon unnecessarily)
void main() {
  test('rule files using resolved-type APIs have usesTypeResolution', () {
    final ruleDir = Directory('lib/src/rules');
    // Only rule class files are relevant — utility files (helpers, mixins,
    // detection utils) are consumed by rules that declare the flag themselves.
    final ruleClassPattern = RegExp(
      r'class\s+\w+\s+extends\s+(?:Saropa|Dart)LintRule',
    );
    final missing = <String>[];

    for (final file in ruleDir.listSync(recursive: true)) {
      if (file is! File || !file.path.endsWith('.dart')) continue;
      final content = file.readAsStringSync();
      // Skip non-rule files (utilities, mixins, detection helpers).
      if (!ruleClassPattern.hasMatch(content)) continue;
      if (!_usesResolvedTypeApis(content)) continue;
      if (!content.contains('usesTypeResolution => true')) {
        missing.add(file.path.replaceAll('\\', '/'));
      }
    }

    expect(
      missing,
      isEmpty,
      reason:
          'These rule files use resolved-type APIs but lack '
          '`@override bool get usesTypeResolution => true;`:\n'
          '${missing.join('\n')}',
    );
  });

  test(
    'rule files declaring usesTypeResolution actually use resolved-type APIs',
    () {
      // Inverse check: files that declare `usesTypeResolution => true` but
      // contain NO resolved-type API access are false claims. These rules
      // are unnecessarily excluded from the light lane, forcing them into
      // the scan daemon and consuming memory that syntactic-only execution
      // would avoid. See Phase 5 research in PLAN_analyzer_memory_monitor.md.
      final ruleDir = Directory('lib/src/rules');
      final ruleClassPattern = RegExp(
        r'class\s+\w+\s+extends\s+(?:Saropa|Dart)LintRule',
      );
      // Files that delegate resolved-type API calls to an imported helper.
      // The helper uses the API, not the rule file itself, so the regex
      // won't find it — but the flag is still correct.
      const indirectUsageAllowlist = {
        'lib/src/rules/core/compound_performance_rules.dart',
      };
      final falseClaims = <String>[];

      for (final file in ruleDir.listSync(recursive: true)) {
        if (file is! File || !file.path.endsWith('.dart')) continue;
        final content = file.readAsStringSync();
        // Skip non-rule files.
        if (!ruleClassPattern.hasMatch(content)) continue;
        // Only check files that declare the flag.
        if (!content.contains('usesTypeResolution => true')) continue;
        // If the file genuinely uses resolved-type APIs, it's correct.
        if (_usesResolvedTypeApis(content)) continue;
        final normalized = file.path.replaceAll('\\', '/');
        // Skip files that use resolved APIs indirectly via imported helpers.
        if (indirectUsageAllowlist.contains(normalized)) continue;
        falseClaims.add(normalized);
      }

      expect(
        falseClaims,
        isEmpty,
        reason:
            'These rule files declare `usesTypeResolution => true` but '
            'contain no resolved-type API calls (.staticType, .library, '
            '.allSupertypes, etc.). Remove the false declaration to move '
            'these rules into the light lane:\n'
            '${falseClaims.join('\n')}',
      );
    },
    // Phase 5 audit complete: 180 false claims flipped across 9 files.
    // This test now guards against regressions.
  );
}
