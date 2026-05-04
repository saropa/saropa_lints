// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';

import '../../native/saropa_fix.dart';

/// Quick fix: Insert `r` prefix in front of a non-raw string literal so that
/// escaped backslashes (e.g. `\\d` in a regex) become a single backslash.
///
/// Matches `PreferRawStringsRule`. The rule reports at the
/// [SimpleStringLiteral] node; the fix inserts `r` at the literal's offset
/// (immediately before the opening quote), turning `'\\d+'` into `r'\\d+'`.
class PreferRawStringsFix extends SaropaFixProducer {
  PreferRawStringsFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.preferRawStrings',
    50,
    'Convert to raw string',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final AstNode? node = coveringNode;
    if (node == null) return;

    // The diagnostic reports at SimpleStringLiteral; covering node may be the
    // literal itself or a parent expression. Walk up to find the literal.
    final SimpleStringLiteral? literal = node is SimpleStringLiteral
        ? node
        : node.thisOrAncestorOfType<SimpleStringLiteral>();
    if (literal == null) return;
    // Already raw — defensive: the rule should have skipped this case.
    if (literal.isRaw) return;

    await builder.addDartFileEdit(file, (b) {
      b.addSimpleInsertion(literal.offset, 'r');
    });
  }
}
