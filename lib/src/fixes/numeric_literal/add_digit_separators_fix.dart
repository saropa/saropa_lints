// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/source/source_range.dart';

import '../../native/saropa_fix.dart';

/// Quick fix: Add digit separators
class AddDigitSeparatorsFix extends SaropaFixProducer {
  AddDigitSeparatorsFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.addDigitSeparatorsFix',
    50,
    'Add digit separators',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final node = coveringNode;
    if (node == null) return;

    final target = node is IntegerLiteral
        ? node
        : node.thisOrAncestorOfType<IntegerLiteral>();
    if (target == null) return;

    final source = target.literal.lexeme;
    final replacement = _addSeparators(source);
    if (replacement == source) return;

    await builder.addDartFileEdit(file, (builder) {
      builder.addSimpleReplacement(
        SourceRange(target.offset, target.length),
        replacement,
      );
    });
  }

  static String _addSeparators(String literal) {
    if (literal.startsWith('0x') || literal.startsWith('0X')) {
      final hex = literal.substring(2).replaceAll('_', '');
      return '0x${_groupDigits(hex, 4)}';
    }
    return _groupDigits(literal.replaceAll('_', ''), 3);
  }

  static String _groupDigits(String digits, int groupSize) {
    final buf = StringBuffer();
    var count = 0;
    for (var i = digits.length - 1; i >= 0; i--) {
      if (count > 0 && count % groupSize == 0) buf.write('_');
      buf.write(digits[i]);
      count++;
    }
    return buf.toString().split('').reversed.join();
  }
}
