// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/source/source_range.dart';

import '../../native/saropa_fix.dart';
import '../../rule_name_utils.dart' as rule_names;
import '../../tiers.dart' as tiers;

/// Quick fix: Add saropa_lints/ prefix to bare rule names in ignore comments.
class RequireIgnoreCommentPluginPrefixFix extends SaropaFixProducer {
  RequireIgnoreCommentPluginPrefixFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.requireIgnoreCommentPluginPrefixFix',
    50,
    'Add saropa_lints/ prefix',
  );

  @override
  FixKind get fixKind => _fixKind;

  static final Set<String> _allSaropaRuleNames = tiers.getAllDefinedRules();

  static const _prefix = 'saropa_lints/';

  static const List<String> _ignorePrefixes = <String>[
    '// ignore:',
    '// ignore_for_file:',
  ];

  static final _ruleNamePattern = RegExp(r'[\w-]+');

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final content = unitResult.content;
    if (content.isEmpty) return;

    // diagnosticOffset/Length is the exact `// ignore: ...` comment token
    // range reported by the rule (reporter.atToken(comment)) — using it
    // directly, rather than coveringNode's AST-node span, guarantees the
    // slice contains only this one comment even when other ignore comments
    // sit nearby in the file.
    final start = diagnosticOffset;
    final len = diagnosticLength;
    List<int>? insertions;
    if (start != null && len != null && len > 0) {
      insertions = _findInsertionsInSlice(
        content,
        start,
        (start + len).clamp(0, content.length),
      );
    }
    insertions ??= _findFirstBareLineInsertions(content);

    if (insertions == null || insertions.isEmpty) return;

    await builder.addDartFileEdit(file, (b) {
      for (final offset in insertions!.reversed) {
        b.addSimpleInsertion(offset, _prefix);
      }
    });
  }

  static List<int>? _findInsertionsInSlice(String content, int start, int end) {
    if (start >= end || start < 0) return null;
    final slice = content.substring(start, end);
    return _extractInsertions(slice, start);
  }

  static List<int>? _findFirstBareLineInsertions(String content) {
    final lines = content.split('\n');
    var offset = 0;
    for (final line in lines) {
      final trimmed = line.trimLeft();
      if (trimmed.startsWith('//') && !trimmed.startsWith('///')) {
        final result = _extractInsertions(trimmed, offset + line.indexOf('//'));
        if (result != null) return result;
      }
      offset += line.length + 1;
    }
    return null;
  }

  static List<int>? _extractInsertions(String text, int baseOffset) {
    for (final prefix in _ignorePrefixes) {
      final idx = text.indexOf(prefix);
      if (idx < 0) continue;
      // Skip if this is inside a doc comment (/// ...) or not at line start.
      if (idx > 0) {
        final before = text.substring(0, idx);
        final lastNewline = before.lastIndexOf('\n');
        final lineStart = lastNewline >= 0
            ? before.substring(lastNewline + 1)
            : before;
        if (lineStart.trimLeft().isNotEmpty) continue;
      }

      final ruleListStart = idx + prefix.length;
      final ruleList = text.substring(ruleListStart);
      final trailingComment = ruleList.indexOf('--');
      final effective = trailingComment >= 0
          ? ruleList.substring(0, trailingComment)
          : ruleList;

      final insertions = <int>[];
      for (final m in _ruleNamePattern.allMatches(effective)) {
        final name = m.group(0);
        if (name == null || name.isEmpty) continue;
        if (name == 'saropa_lints') continue;

        final nameStart = ruleListStart + m.start;
        if (nameStart >= _prefix.length &&
            text.substring(nameStart - _prefix.length, nameStart) == _prefix) {
          continue;
        }

        final bare = name.replaceAll('-', '_');
        if (_allSaropaRuleNames.contains(bare)) {
          insertions.add(baseOffset + ruleListStart + m.start);
        }
      }
      // Found the ignore-comment line the diagnostic targets — return its
      // insertions even when empty. An empty result means every name in
      // this comment is already prefixed (the "prefixed but unregistered
      // rule name" diagnostic case, which this fix cannot correct — it only
      // knows how to ADD a missing prefix, not rename a typo). Returning []
      // here (not null) stops compute() from falling back to
      // _findFirstBareLineInsertions and silently "fixing" an unrelated
      // bare-name comment elsewhere in the file.
      return insertions;
    }
    return null;
  }
}

/// Quick fix: Replace an unregistered saropa_lints/ rule name with the
/// closest registered match (Levenshtein distance). Only offered when
/// a close match exists — otherwise no fix is proposed.
class ReplaceUnknownPrefixedRuleNameFix extends SaropaFixProducer {
  ReplaceUnknownPrefixedRuleNameFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.replaceUnknownPrefixedRuleNameFix',
    50,
    'Replace with closest registered rule name',
  );

  @override
  FixKind get fixKind => _fixKind;

  static const _prefix = 'saropa_lints/';

  static const List<String> _ignorePrefixes = <String>[
    '// ignore:',
    '// ignore_for_file:',
  ];

  static final _ruleNamePattern = RegExp(r'[\w-]+');

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final content = unitResult.content;
    if (content.isEmpty) return;

    final start = diagnosticOffset;
    final len = diagnosticLength;
    if (start == null || len == null || len <= 0) return;

    final end = (start + len).clamp(0, content.length);
    final slice = content.substring(start, end);

    // Find the first prefixed-but-unknown rule name and its replacement.
    final replacement = _findReplacement(slice, start);
    if (replacement == null) return;

    await builder.addDartFileEdit(file, (b) {
      b.addSimpleReplacement(
        SourceRange(replacement.offset, replacement.length),
        replacement.newName,
      );
    });
  }

  /// Scans [text] for a `saropa_lints/<unknown>` name whose suffix is not
  /// registered, and returns the replacement if a close match exists.
  static _Replacement? _findReplacement(String text, int baseOffset) {
    for (final prefix in _ignorePrefixes) {
      final idx = text.indexOf(prefix);
      if (idx < 0) continue;

      final ruleListStart = idx + prefix.length;
      final ruleList = text.substring(ruleListStart);
      final trailingComment = ruleList.indexOf('--');
      final effective = trailingComment >= 0
          ? ruleList.substring(0, trailingComment)
          : ruleList;

      // Walk rule names in the comma-separated list.
      for (final m in _ruleNamePattern.allMatches(effective)) {
        final name = m.group(0);
        if (name == null || name.isEmpty) continue;
        if (name == 'saropa_lints') continue;

        // Only process names that are preceded by the saropa_lints/ prefix.
        final nameStart = ruleListStart + m.start;
        if (nameStart < _prefix.length) continue;
        if (text.substring(nameStart - _prefix.length, nameStart) != _prefix) {
          continue;
        }

        // Check if suffix is unknown.
        final bare = name.replaceAll('-', '_');
        if (rule_names.allSaropaRuleNames.contains(bare)) continue;

        // Find the closest registered name.
        final suggestion = rule_names.closestRuleName(bare);
        if (suggestion == null) continue;

        // Return replacement: the suffix portion after saropa_lints/.
        return _Replacement(
          offset: baseOffset + nameStart,
          length: name.length,
          newName: suggestion,
        );
      }
    }
    return null;
  }
}

/// A text replacement: replace [length] chars at [offset] with [newName].
class _Replacement {
  const _Replacement({
    required this.offset,
    required this.length,
    required this.newName,
  });

  final int offset;
  final int length;
  final String newName;
}
