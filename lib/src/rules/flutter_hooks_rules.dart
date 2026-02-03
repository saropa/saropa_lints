// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

/// Flutter Hooks-specific lint rules for Flutter/Dart applications.
///
/// These rules ensure proper usage of the flutter_hooks package,
/// including hook call ordering, conditional guards, and widget types.
library;

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart' show DiagnosticSeverity;
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../saropa_lint_rule.dart';

// =============================================================================
// FLUTTER HOOKS RULES
// =============================================================================

/// Warns when Flutter Hooks are called outside of a build method.
///
/// Hooks (functions starting with `use`) must be called from within
/// the build method of a HookWidget. Calling them elsewhere violates
/// the rules of hooks and causes runtime errors.
///
/// **BAD:**
/// ```dart
/// class MyWidget extends HookWidget {
///   void initData() {
///     final controller = useTextEditingController(); // Wrong!
///   }
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// class MyWidget extends HookWidget {
///   @override
///   Widget build(BuildContext context) {
///     final controller = useTextEditingController(); // Correct!
///     return TextField(controller: controller);
///   }
/// }
/// ```
class AvoidHooksOutsideBuildRule extends SaropaLintRule {
  const AvoidHooksOutsideBuildRule() : super(code: _code);

  /// Critical - runtime error.
  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'avoid_hooks_outside_build',
    problemMessage:
        '[avoid_hooks_outside_build] Hook function called outside of build method. '
        'Hooks must only be called from build().',
    correctionMessage: 'Move this hook call inside the build() method.',
    errorSeverity: DiagnosticSeverity.ERROR,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;

      // Check if it's a hook function (use + PascalCase, e.g., useState, useEffect)
      if (!_isHookFunction(methodName)) return;

      // Check if we're inside a build method
      if (!_isInsideBuildMethod(node)) {
        reporter.atNode(node, code);
      }
    });
  }

  bool _isInsideBuildMethod(AstNode node) {
    AstNode? current = node.parent;
    while (current != null) {
      if (current is MethodDeclaration) {
        return current.name.lexeme == 'build';
      }
      current = current.parent;
    }
    return false;
  }
}

/// Warns when Flutter Hooks are called inside conditionals.
///
/// Hooks must be called unconditionally in the same order every build.
/// Calling hooks inside if/else, switch, or ternary expressions violates
/// the rules of hooks and causes runtime errors.
///
/// **BAD:**
/// ```dart
/// Widget build(BuildContext context) {
///   if (condition) {
///     final value = useState(0); // Wrong!
///   }
///   return condition ? useCallback() : null; // Wrong!
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// Widget build(BuildContext context) {
///   final value = useState(0); // Called unconditionally
///   if (condition) {
///     value.value = 42; // Use the value conditionally, not the hook
///   }
///   return Container();
/// }
/// ```
class AvoidConditionalHooksRule extends SaropaLintRule {
  const AvoidConditionalHooksRule() : super(code: _code);

  /// Critical - runtime error.
  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'avoid_conditional_hooks',
    problemMessage:
        '[avoid_conditional_hooks] Hook function called conditionally. '
        'Hooks must be called unconditionally in the same order.',
    correctionMessage:
        'Move hook calls outside of conditionals. Use the hook value conditionally instead.',
    errorSeverity: DiagnosticSeverity.ERROR,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;

      // Check if it's a hook function (use + PascalCase, e.g., useState, useEffect)
      if (!_isHookFunction(methodName)) return;

      // Check if inside build method first
      if (!_isInsideBuildMethod(node)) return;

      // Check if inside a conditional
      if (_isInsideConditional(node)) {
        reporter.atNode(node, code);
      }
    });
  }

  bool _isInsideBuildMethod(AstNode node) {
    AstNode? current = node.parent;
    while (current != null) {
      if (current is MethodDeclaration) {
        return current.name.lexeme == 'build';
      }
      current = current.parent;
    }
    return false;
  }

  bool _isInsideConditional(AstNode node) {
    AstNode? current = node.parent;
    while (current != null) {
      // Stop at build method level
      if (current is MethodDeclaration) break;

      // Check for conditionals
      if (current is IfStatement ||
          current is ConditionalExpression ||
          current is SwitchStatement ||
          current is SwitchExpression) {
        return true;
      }

      // Check for loop bodies (hooks shouldn't be in loops either)
      if (current is ForStatement ||
          current is ForEachParts ||
          current is WhileStatement ||
          current is DoStatement) {
        return true;
      }

      current = current.parent;
    }
    return false;
  }
}

/// Warns when a HookWidget doesn't use any hooks.
///
/// If a widget extends HookWidget but doesn't call any hook functions,
/// it should be a regular StatelessWidget instead.
///
/// **BAD:**
/// ```dart
/// class MyWidget extends HookWidget {
///   @override
///   Widget build(BuildContext context) {
///     return Text('No hooks used!'); // Should be StatelessWidget
///   }
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// class MyWidget extends HookWidget {
///   @override
///   Widget build(BuildContext context) {
///     final counter = useState(0); // Using hooks!
///     return Text('${counter.value}');
///   }
/// }
/// ```
class AvoidUnnecessaryHookWidgetsRule extends SaropaLintRule {
  const AvoidUnnecessaryHookWidgetsRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    name: 'avoid_unnecessary_hook_widgets',
    problemMessage:
        '[avoid_unnecessary_hook_widgets] HookWidget without any hook calls. Use StatelessWidget instead.',
    correctionMessage: 'Change to StatelessWidget if no hooks are needed.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
      // Check if class extends HookWidget
      final ExtendsClause? extendsClause = node.extendsClause;
      if (extendsClause == null) return;

      final String superclassName = extendsClause.superclass.name.lexeme;
      if (superclassName != 'HookWidget' &&
          superclassName != 'HookConsumerWidget') {
        return;
      }

      // Find build method
      MethodDeclaration? buildMethod;
      for (final ClassMember member in node.members) {
        if (member is MethodDeclaration && member.name.lexeme == 'build') {
          buildMethod = member;
          break;
        }
      }

      if (buildMethod == null) return;

      // Check if build method contains any hook calls
      final _HookCallVisitor visitor = _HookCallVisitor();
      buildMethod.body.accept(visitor);

      if (!visitor.hasHookCall) {
        reporter.atNode(node, code);
      }
    });
  }
}

// =============================================================================
// HELPER CLASSES
// =============================================================================

class _HookCallVisitor extends RecursiveAstVisitor<void> {
  bool hasHookCall = false;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final String methodName = node.methodName.name;
    // Use the proper hook detection (use + PascalCase)
    if (_isHookFunction(methodName)) {
      hasHookCall = true;
    }
    super.visitMethodInvocation(node);
  }
}

/// Checks if a method name follows the Flutter hooks naming convention.
///
/// Flutter hooks use the pattern `use` + PascalCase identifier:
/// - `useState`, `useEffect`, `useCallback` ✓
/// - `userDOB`, `usefulHelper`, `username` ✗
bool _isHookFunction(String methodName) {
  // Must start with 'use' and have at least one more character
  if (!methodName.startsWith('use')) return false;
  if (methodName.length < 4) return false;

  // The character after 'use' must be uppercase (PascalCase convention)
  // This distinguishes useState from userDOB
  final charAfterUse = methodName[3];
  return charAfterUse == charAfterUse.toUpperCase() &&
      charAfterUse != charAfterUse.toLowerCase();
}
