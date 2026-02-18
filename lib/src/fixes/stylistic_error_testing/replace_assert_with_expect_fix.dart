// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/source/source_range.dart';

import '../../native/saropa_fix.dart';

/// Quick fix: Replace with expect()
class ReplaceAssertWithExpectFix extends SaropaFixProducer {
  ReplaceAssertWithExpectFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.replaceAssertWithExpectFix',
    50,
    'Replace with expect()',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final node = coveringNode;
    if (node == null) return;

    final target = node is AssertStatement
        ? node
        : node.thisOrAncestorOfType<AssertStatement>();
    if (target == null) return;

    // Replace assert(condition) with expect(condition, isTrue)
    final condition = target.condition;
    final condSource = condition.toSource();

    await builder.addDartFileEdit(file, (builder) {
      builder.addSimpleReplacement(
        SourceRange(target.offset, target.length),
        'expect($condSource, isTrue);',
      );
    });
  }
}
