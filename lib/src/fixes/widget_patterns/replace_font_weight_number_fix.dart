// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/source/source_range.dart';

import '../../native/saropa_fix.dart';

/// Quick fix: Replace numeric FontWeight with named constant.
class ReplaceFontWeightNumberFix extends SaropaFixProducer {
  ReplaceFontWeightNumberFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.replaceFontWeightNumber',
    50,
    'Replace with FontWeight constant',
  );

  static const _weightMap = {
    '100': 'w100',
    '200': 'w200',
    '300': 'w300',
    '400': 'w400',
    '500': 'w500',
    '600': 'w600',
    '700': 'w700',
    '800': 'w800',
    '900': 'w900',
  };

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

    final name = prefixed.identifier.name;
    final replacement = _weightMap[name];
    if (replacement == null) return;

    await builder.addDartFileEdit(file, (builder) {
      builder.addSimpleReplacement(
        SourceRange(prefixed.offset, prefixed.length),
        'FontWeight.$replacement',
      );
    });
  }
}
