// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/source/source_range.dart';

import '../../import_utils.dart';
import '../../native/saropa_fix.dart';

/// Quick fix: Add `///` section headers between import groups.
class AddImportGroupCommentsFix extends SaropaFixProducer {
  AddImportGroupCommentsFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.addImportGroupCommentsFix',
    50,
    'Add import group section headers',
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
    if (imports.isEmpty) return;

    // Bail out if there are comments between imports that would be lost.
    final content = unitResult.content;
    final blockStart = imports.first.offset;
    final blockEnd = imports.last.end;
    if (_hasNonGroupComments(content, imports, blockStart, blockEnd)) {
      return;
    }

    // Classify imports into groups.
    final groups = <int, List<ImportDirective>>{};
    for (final imp in imports) {
      final group = ImportGroup.classify(imp);
      groups.putIfAbsent(group, () => []).add(imp);
    }

    final replacement = _buildGroupedBlock(groups);

    await builder.addDartFileEdit(file, (builder) {
      builder.addSimpleReplacement(
        SourceRange(blockStart, blockEnd - blockStart),
        replacement,
      );
    });
  }

  /// Returns true if the import block contains non-header comment lines
  /// between imports that would be lost during replacement.
  static bool _hasNonGroupComments(
    String content,
    List<ImportDirective> imports,
    int blockStart,
    int blockEnd,
  ) {
    for (var i = 0; i < imports.length - 1; i++) {
      final gapStart = imports[i].end;
      final gapEnd = imports[i + 1].offset;
      final segment = content.substring(gapStart, gapEnd);
      for (final line in segment.split('\n')) {
        final trimmed = line.trim();
        // Skip blank lines and known group headers.
        if (trimmed.isEmpty) continue;
        if (ImportGroup.headers.values.contains(trimmed)) continue;
        // Any other comment line is a non-header comment.
        if (trimmed.startsWith('//') || trimmed.startsWith('/*')) {
          return true;
        }
      }
    }
    return false;
  }

  static String _buildGroupedBlock(Map<int, List<ImportDirective>> groups) {
    final buffer = StringBuffer();
    var firstGroup = true;
    for (final groupId in [
      ImportGroup.dart,
      ImportGroup.package,
      ImportGroup.relative,
    ]) {
      final group = groups[groupId];
      if (group == null || group.isEmpty) continue;
      if (!firstGroup) buffer.write('\n\n');
      firstGroup = false;
      buffer.write(ImportGroup.headers[groupId]!);
      for (final imp in group) {
        buffer.write('\n');
        buffer.write(imp.toSource());
      }
    }
    return buffer.toString();
  }
}
