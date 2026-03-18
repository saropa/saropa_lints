// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/source/source_range.dart';

import '../../native/saropa_fix.dart';

/// Quick fix: Sort arguments alphabetically
class SortArgumentsFix extends SaropaFixProducer {
  SortArgumentsFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.sortArgumentsFix',
    50,
    'Sort arguments alphabetically',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final node = coveringNode;
    if (node == null) return;

    final target = node is ArgumentList
        ? node
        : node.thisOrAncestorOfType<ArgumentList>();
    if (target == null) return;

    // Separate positional and named arguments
    final positional = <Expression>[];
    final named = <NamedExpression>[];
    for (final arg in target.arguments) {
      if (arg is NamedExpression) {
        named.add(arg);
      } else {
        positional.add(arg);
      }
    }

    if (named.length < 2) return;

    // Sort named arguments alphabetically by name
    final sortedNamed = List<NamedExpression>.from(named)
      ..sort((a, b) => a.name.label.name.compareTo(b.name.label.name));

    // Build replacement argument list
    final parts = <String>[
      ...positional.map((e) => e.toSource()),
      ...sortedNamed.map((e) => e.toSource()),
    ];
    final replacement = '(${parts.join(', ')})';

    await builder.addDartFileEdit(file, (builder) {
      builder.addSimpleReplacement(
        SourceRange(target.offset, target.length),
        replacement,
      );
    });
  }
}
