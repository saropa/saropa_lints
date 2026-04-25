import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:saropa_lints/src/rules/ui/internationalization_rules.dart';
import 'package:test/test.dart';

/// Behavioral tests for [RequireIntlPluralRulesRule] plural-word detection.
///
/// Regression: regex over full method text could span `'; … '` and treat
/// `(hour == …)` as containing the word `hour` from the `hours?` pattern.
void main() {
  group('RequireIntlPluralRulesRule string-literal plural scan', () {
    test('12h hour wheel literals do not contain plural indicator words', () {
      expect(
        _literalScan(r"""
String _formatHourWheel(int hour) {
  if (hour == 0) return '12\nAM';
  if (hour == 12) return '12\nPM';
  if (hour == 1) return '1\nAM';
  final isPM = hour > 11;
  final display = hour > 12 ? hour - 12 : hour;
  return '$display\n${isPM ? 'PM' : 'AM'}';
}
"""),
        isFalse,
      );
    });

    test('manual item/count returns still match plural indicator words', () {
      expect(
        _literalScan(r"""
String _getMessage(int count) {
  if (count == 0) return 'No items';
  if (count == 1) return '1 item';
  return '$count items';
}
"""),
        isTrue,
      );
    });
  });
}

bool _literalScan(String source) {
  final result = parseString(
    content: source,
    featureSet: FeatureSet.latestLanguageVersion(),
    throwIfDiagnostics: false,
  );
  FunctionDeclaration? func;
  result.unit.accept(_FindFirstFunctionVisitor((f) => func = f));
  expect(
    func,
    isNotNull,
    reason: 'fixture must declare one top-level function',
  );
  return RequireIntlPluralRulesRule.stringLiteralsSuggestManualPlural(
    func!.functionExpression.body,
  );
}

class _FindFirstFunctionVisitor extends RecursiveAstVisitor<void> {
  _FindFirstFunctionVisitor(this._onFound);

  final void Function(FunctionDeclaration f) _onFound;

  @override
  void visitFunctionDeclaration(FunctionDeclaration node) {
    _onFound(node);
  }
}
