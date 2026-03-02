// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/source/source_range.dart';

import '../../native/saropa_fix.dart';

/// Quick fix: Remove unnecessary enum prefix (MyEnum.value → value).
class RemoveUnnecessaryEnumPrefixFix extends SaropaFixProducer {
  RemoveUnnecessaryEnumPrefixFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.removeUnnecessaryEnumPrefixFix',
    50,
    'Remove enum prefix',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final node = coveringNode;
    if (node == null) return;

    final prefixed = node is PrefixedIdentifier
        ? node
        : node.thisOrAncestorOfType<PrefixedIdentifier>();
    if (prefixed == null) return;

    final identifierSource = prefixed.identifier.toSource();
    await builder.addDartFileEdit(file, (builder) {
      builder.addSimpleReplacement(
        SourceRange(prefixed.offset, prefixed.length),
        identifierSource,
      );
    });
  }
}
