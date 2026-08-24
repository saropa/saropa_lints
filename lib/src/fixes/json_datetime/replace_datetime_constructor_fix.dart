// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/source/source_range.dart';

import '../../native/saropa_fix.dart';

/// Quick fix: Replace DateTime constructor with DateTime.tryParse.
///
/// Produces `DateTime.tryParse('$year-$month-$day')` from
/// `DateTime(year, month, day)`. Bails out when any argument contains
/// syntax that would break inside a string interpolation (quotes,
/// braces, await, ternary, cascade).
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

    // analyzer 13: ArgumentList.arguments is NodeList<Argument>. DateTime()
    // constructor args are always positional, so each Argument is an
    // Expression directly (never a NamedArgument) — cast is safe here.
    for (final Argument arg in args) {
      if (!_isSafeForInterpolation(arg as Expression)) return;
    }

    final bool isUtc = creation.constructorName.name?.name == 'utc';
    final List<String> parts = <String>[];
    for (final Argument arg in args) {
      parts.add(arg.toSource());
    }

    while (parts.length < 3) {
      parts.add('1');
    }

    final StringBuffer iso = StringBuffer("'");
    iso.write(_pad(parts[0]));
    iso.write('-');
    iso.write(_pad(parts[1]));
    iso.write('-');
    iso.write(_pad(parts[2]));

    if (parts.length > 3) {
      iso.write('T');
      iso.write(_pad(parts[3]));
      iso.write(':');
      iso.write(parts.length > 4 ? _pad(parts[4]) : '00');
      iso.write(':');
      iso.write(parts.length > 5 ? _pad(parts[5]) : '00');

      if (parts.length > 6) {
        final String ms = parts[6];
        final String us = parts.length > 7 ? parts[7] : '0';
        iso.write('.');
        iso.write(_pad3(ms));
        iso.write(_pad3(us));
      }
    }
    if (isUtc) iso.write('Z');
    iso.write("'");

    final String replacement = 'DateTime.tryParse($iso)';

    await builder.addDartFileEdit(file, (builder) {
      builder.addSimpleReplacement(
        SourceRange(creation.offset, creation.length),
        replacement,
      );
    });
  }

  static bool _isSafeForInterpolation(Expression arg) {
    if (arg is IntegerLiteral) return true;
    if (arg is SimpleIdentifier) return true;
    if (arg is PrefixedIdentifier) return true;
    if (arg is PropertyAccess) {
      final src = arg.toSource();
      return !src.contains("'") && !src.contains('"') && !src.contains('}');
    }
    if (arg is ParenthesizedExpression) {
      return _isSafeForInterpolation(arg.expression);
    }
    return false;
  }

  /// Wraps expression in `\${expr}` if not a simple identifier,
  /// or returns `\$name` for plain identifiers.
  /// Integer literals are returned as-is (already padded by caller).
  static String _pad(String expr) {
    if (_isIntLiteral(expr)) return expr;
    if (_isSimpleIdentifier(expr)) {
      return '\$$expr';
    }
    return '\${$expr}';
  }

  static String _pad3(String expr) {
    if (_isIntLiteral(expr)) {
      return expr.padLeft(3, '0');
    }
    if (_isSimpleIdentifier(expr)) {
      return '\$$expr';
    }
    return '\${$expr}';
  }

  static bool _isIntLiteral(String s) {
    if (s.isEmpty) return false;
    for (int i = 0; i < s.length; i++) {
      if (!_isDigit(s.codeUnitAt(i))) return false;
    }
    return true;
  }

  static bool _isSimpleIdentifier(String s) {
    if (s.isEmpty) return false;
    final int first = s.codeUnitAt(0);
    if (!_isLetter(first) && first != 0x5F) return false;
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
