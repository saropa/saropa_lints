// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/source/source_range.dart';

import '../../native/saropa_fix.dart';

/// Quick fix: Convert to double quotes
class PreferDoubleQuotesFix extends SaropaFixProducer {
  PreferDoubleQuotesFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.preferDoubleQuotesFix',
    4000,
    'Convert to double quotes',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final node = coveringNode;
    if (node == null) return;

    // Convert single-quoted string to double-quoted
    final source = node.toSource();
    if (!source.startsWith("'")) return;

    // Extract value and check for double quotes
    final value = source.substring(1, source.length - 1);
    if (value.contains('"')) return;

    await builder.addDartFileEdit(file, (builder) {
      builder.addSimpleReplacement(
        SourceRange(node.offset, node.length),
        '"$value"',
      );
    });
  }
}
