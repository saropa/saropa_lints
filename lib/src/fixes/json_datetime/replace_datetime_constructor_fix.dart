// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/source/source_range.dart';

import '../../native/saropa_fix.dart';

/// Quick fix: Replace DateTime constructor with DateTime.tryParse.
class ReplaceDateTimeConstructorFix extends SaropaFixProducer {
  ReplaceDateTimeConstructorFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.replaceDateTimeConstructor',
    50,
    'Replace with DateTime.tryParse()',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final node = coveringNode;
    if (node == null) return;

    final creation = node is InstanceCreationExpression
        ? node
        : node.thisOrAncestorOfType<InstanceCreationExpression>();
    if (creation == null) return;

    final args = creation.argumentList.arguments;
    if (args.isEmpty) return;

    final bool isUtc =
        creation.constructorName.name?.name == 'utc';
    final List<String> parts = <String>[];
    for (final Expression arg in args) {
      parts.add(arg.toSource());
    }

    // Pad to at least year, month, day for a valid ISO string.
    while (parts.length < 3) {
      parts.add(parts.length == 1 ? '1' : '1');
    }

    final String year = parts[0];
    final String month = parts[1];
    final String day = parts[2];

    final StringBuffer iso = StringBuffer();
    iso.write("'\$${_brace(year)}-\$${_brace(month)}-\$${_brace(day)}");
    if (parts.length > 3) {
      iso.write('T\$${_brace(parts[3])}');
      if (parts.length > 4) {
        iso.write(':\$${_brace(parts[4])}');
      }
      if (parts.length > 5) {
        iso.write(':\$${_brace(parts[5])}');
      }
    }
    if (isUtc) iso.write('Z');
    iso.write("'");

    final String replacement =
        'DateTime.tryParse($iso)';

    await builder.addDartFileEdit(file, (builder) {
      builder.addSimpleReplacement(
        SourceRange(creation.offset, creation.length),
        replacement,
      );
    });
  }

  static String _brace(String expr) {
    if (_isSimpleIdentifier(expr)) return expr;
    return '{$expr}';
  }

  static bool _isSimpleIdentifier(String s) {
    if (s.isEmpty) return false;
    if (!_isLetter(s.codeUnitAt(0)) && s.codeUnitAt(0) != 0x5F) return false;
    for (int i = 1; i < s.length; i++) {
      final int c = s.codeUnitAt(i);
      if (!_isLetter(c) && !_isDigit(c) && c != 0x5F) return false;
    }
    return true;
  }

  static bool _isLetter(int c) =>
      (c >= 0x41 && c <= 0x5A) || (c >= 0x61 && c <= 0x7A);

  static bool _isDigit(int c) => c >= 0x30 && c <= 0x39;
}
