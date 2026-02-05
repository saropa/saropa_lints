
import 'package:saropa_lints/src/saropa_lint_rule.dart';

class Violation {
  Violation({
    required this.file,
    required this.line,
    required this.column,
    required this.rule,
    required this.message,
    this.impact,
  });

  final String file;
  final int line;
  final int column;
  final String rule;
  final String message;
  final LintImpact? impact;

  @override
  String toString() => '$file:$line:$column - $rule - $message';
}
