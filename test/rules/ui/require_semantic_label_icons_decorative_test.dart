import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:saropa_lints/src/rules/ui/accessibility_rules.dart';
import 'package:test/test.dart';

/// Behavioral tests for the decorative-icon guard of
/// `require_semantic_label_icons`. Uses parseString (no resolution) because
/// the guard is purely syntactic; `const` forces InstanceCreationExpression.
void main() {
  group('RequireSemanticLabelIconsRule.isDecorativeBesideTextLabel', () {
    test('ButtonSegment icon beside label: Text is decorative', () {
      expect(
        _decorative(
          "const ButtonSegment(value: 0, label: Text('Focus'), "
          'icon: Icon(Icons.center_focus_strong))',
        ),
        isTrue,
      );
    });

    test('FilledButton.icon icon beside label: Text is decorative', () {
      expect(
        _decorative(
          "FilledButton.icon(onPressed: () {}, icon: const Icon(Icons.add), "
          "label: const Text('Continue'))",
        ),
        isTrue,
      );
    });

    test('InputDecoration prefixIcon beside labelText is decorative', () {
      expect(
        _decorative(
          "const InputDecoration(labelText: 'Link', "
          'prefixIcon: Icon(Icons.link))',
        ),
        isTrue,
      );
    });

    // Positive cases: the rule must still fire.
    test('standalone icon in a Row still needs a label', () {
      expect(_decorative('const Row(children: [Icon(Icons.add)])'), isFalse);
    });

    test('icon slot without any text label still needs a label', () {
      expect(
        _decorative(
          'IconButton(onPressed: () {}, icon: const Icon(Icons.add))',
        ),
        isFalse,
      );
    });

    test('null labelText does not count as a label', () {
      expect(
        _decorative(
          'const InputDecoration(labelText: null, '
          'prefixIcon: Icon(Icons.link))',
        ),
        isFalse,
      );
    });
  });
}

/// Parses `void f() { <expr>; }` and evaluates the guard on the first `Icon`
/// instance creation found.
bool _decorative(String expr) {
  final unit = parseString(
    content: 'void f() { $expr; }',
    featureSet: FeatureSet.latestLanguageVersion(),
    throwIfDiagnostics: false,
  ).unit;
  final finder = _IconFinder();
  unit.accept(finder);
  final icon = finder.icon;
  if (icon == null) fail('No Icon node found in: $expr');
  return RequireSemanticLabelIconsRule.isDecorativeBesideTextLabel(icon);
}

/// Finds the first `Icon(...)` in either AST shape (const -> creation,
/// otherwise MethodInvocation).
class _IconFinder extends RecursiveAstVisitor<void> {
  AstNode? icon;

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    if (icon == null && node.constructorName.type.name.lexeme == 'Icon') {
      icon = node;
    }
    super.visitInstanceCreationExpression(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (icon == null && node.target == null && node.methodName.name == 'Icon') {
      icon = node;
    }
    super.visitMethodInvocation(node);
  }
}
