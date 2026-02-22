// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/source/source_range.dart';

import '../../import_utils.dart';
import '../../native/saropa_fix.dart';

/// Quick fix: Sort imports alphabetically within each group.
class SortImportsFix extends SaropaFixProducer {
  SortImportsFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.sortImportsFix',
    50,
    'Sort imports alphabetically',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final node = coveringNode;
    if (node == null) return;

    final unit = node is CompilationUnit
        ? node
        : node.thisOrAncestorOfType<CompilationUnit>();
    if (unit == null) return;

    final imports = unit.directives.whereType<ImportDirective>().toList();
    if (imports.length < 2) return;

    // Bail out if there are comments between imports that would be lost.
    final content = unitResult.content;
    final blockStart = imports.first.offset;
    final blockEnd = imports.last.end;
    if (_hasNonImportComments(content, imports, blockStart, blockEnd)) {
      return;
    }

    // Classify and sort each group alphabetically by URI.
    final groups = <int, List<ImportDirective>>{};
    for (final imp in imports) {
      final group = ImportGroup.classify(imp);
      groups.putIfAbsent(group, () => []).add(imp);
    }
    for (final group in groups.values) {
      group.sort((a, b) {
        final uriA = a.uri.stringValue ?? '';
        final uriB = b.uri.stringValue ?? '';
        return uriA.compareTo(uriB);
      });
    }

    final replacement = _buildSortedBlock(groups);

    await builder.addDartFileEdit(file, (builder) {
      builder.addSimpleReplacement(
        SourceRange(blockStart, blockEnd - blockStart),
        replacement,
      );
    });
  }

  /// Returns true if the import block contains comment lines between imports
  /// (excluding blank lines and the import statements themselves).
  static bool _hasNonImportComments(
    String content,
    List<ImportDirective> imports,
    int blockStart,
    int blockEnd,
  ) {
    for (var i = 0; i < imports.length - 1; i++) {
      final gapStart = imports[i].end;
      final gapEnd = imports[i + 1].offset;
      if (ImportGroup.hasCommentsBetween(content, gapStart, gapEnd)) {
        return true;
      }
    }
    return false;
  }

  static String _buildSortedBlock(Map<int, List<ImportDirective>> groups) {
    final buffer = StringBuffer();
    var firstGroup = true;
    for (final groupId in [
      ImportGroup.dart,
      ImportGroup.package,
      ImportGroup.relative,
    ]) {
      final group = groups[groupId];
      if (group == null || group.isEmpty) continue;
      if (!firstGroup) buffer.write('\n\n'); // blank line between groups
      firstGroup = false;
      for (var i = 0; i < group.length; i++) {
        if (i > 0) buffer.write('\n');
        buffer.write(group[i].toSource());
      }
    }
    return buffer.toString();
  }
}
