// ignore_for_file: depend_on_referenced_packages

import '../../native/saropa_fix.dart';
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

    final node = coveringNode;
    List<int>? insertions;
    if (node != null && node.length > 0 && node.length < 200) {
      insertions = _findInsertionsInSlice(
        content,
        node.offset,
        (node.offset + node.length).clamp(0, content.length),
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

  static List<int>? _findInsertionsInSlice(
    String content,
    int start,
    int end,
  ) {
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
        final lineStart =
            lastNewline >= 0 ? before.substring(lastNewline + 1) : before;
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
      if (insertions.isNotEmpty) return insertions;
    }
    return null;
  }
}
