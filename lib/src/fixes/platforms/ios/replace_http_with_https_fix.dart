// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/source/source_range.dart';

import '../../../native/saropa_fix.dart';

/// Quick fix: Change to HTTPS
class ReplaceHttpWithHttpsFix extends SaropaFixProducer {
  ReplaceHttpWithHttpsFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.replaceHttpWithHttpsFix',
    50,
    'Change to HTTPS',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final node = coveringNode;
    if (node == null) return;

    final target = node is SimpleStringLiteral
        ? node
        : node.thisOrAncestorOfType<SimpleStringLiteral>();
    if (target == null) return;

    final value = target.value;
    if (!value.contains('http://')) return;

    final replaced = value.replaceAll('http://', 'https://');
    await builder.addDartFileEdit(file, (builder) {
      builder.addSimpleReplacement(
        SourceRange(target.offset, target.length),
        "'$replaced'",
      );
    });
  }
}
