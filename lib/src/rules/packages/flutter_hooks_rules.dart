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

import '../../saropa_lint_rule.dart';

// =============================================================================
// FLUTTER HOOKS RULES
// =============================================================================

/// Warns when Flutter Hooks are called outside of a build method.
///
/// Since: v2.0.0 | Updated: v4.13.0 | Rule version: v2
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
        'Hooks must only be called from build(). {v2}',
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
/// Since: v2.0.0 | Updated: v4.13.0 | Rule version: v2
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
        'Hooks must be called unconditionally in the same order. {v2}',
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
/// Since: v2.0.0 | Updated: v4.13.0 | Rule version: v2
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
        '[avoid_unnecessary_hook_widgets] HookWidget without any hook calls. Use StatelessWidget instead. If a widget extends HookWidget but doesn\'t call any hook functions, it must be a regular StatelessWidget instead. {v2}',
    correctionMessage:
        'Change to StatelessWidget if no hooks are needed. Verify the change works correctly with existing tests and add coverage for the new behavior.',
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

// =============================================================================
// prefer_use_callback
// =============================================================================

/// Warns when inline closures are used instead of useCallback in HookWidgets.
///
/// Since: v4.15.0 | Rule version: v1
///
/// In a HookWidget, passing an inline anonymous function as a callback
/// (e.g., onPressed: () { ... }) creates a new closure on every build.
/// This defeats hook memoization and causes unnecessary child rebuilds.
/// Use useCallback to memoize callbacks and maintain referential equality.
///
/// **BAD:**
/// ```dart
/// class MyWidget extends HookWidget {
///   Widget build(BuildContext context) {
///     return ElevatedButton(
///       onPressed: () { doSomething(); },
///       child: Text('Click'),
///     );
///   }
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// class MyWidget extends HookWidget {
///   Widget build(BuildContext context) {
///     final onPressed = useCallback(() { doSomething(); }, []);
///     return ElevatedButton(
///       onPressed: onPressed,
///       child: Text('Click'),
///     );
///   }
/// }
/// ```
class PreferUseCallbackRule extends SaropaLintRule {
  const PreferUseCallbackRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'prefer_use_callback',
    problemMessage:
        '[prefer_use_callback] Inline closure passed as callback in a '
        'HookWidget build method. Every rebuild creates a new closure '
        'instance, which breaks referential equality and defeats hook '
        'memoization. Child widgets receiving this callback will rebuild '
        'unnecessarily. Use useCallback to memoize the function and '
        'maintain stable references across rebuilds. {v1}',
    correctionMessage: 'Extract the inline closure into a useCallback hook: '
        'final handler = useCallback(() { ... }, [dependencies]);',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  /// Callback parameter names commonly used in Flutter widgets.
  static const Set<String> _callbackParams = <String>{
    'onPressed',
    'onTap',
    'onChanged',
    'onSubmitted',
    'onSaved',
    'onLongPress',
    'onDoubleTap',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodDeclaration((MethodDeclaration node) {
      if (node.name.lexeme != 'build') return;

      // Check if enclosing class extends HookWidget
      final AstNode? parent = node.parent;
      if (parent is! ClassDeclaration) return;

      final ExtendsClause? extendsClause = parent.extendsClause;
      if (extendsClause == null) return;

      final String superclass = extendsClause.superclass.name2.lexeme;
      if (superclass != 'HookWidget' && superclass != 'HookConsumerWidget') {
        return;
      }

      // Check if useCallback is already used in the body
      final String bodySource = node.body.toSource();
      if (bodySource.contains('useCallback')) return;

      // Look for inline closures in callback parameters
      final _InlineCallbackVisitor visitor = _InlineCallbackVisitor();
      node.body.accept(visitor);

      if (visitor.inlineCallbackNode != null) {
        reporter.atNode(visitor.inlineCallbackNode!, code);
      }
    });
  }
}

class _InlineCallbackVisitor extends RecursiveAstVisitor<void> {
  AstNode? inlineCallbackNode;

  @override
  void visitNamedExpression(NamedExpression node) {
    if (inlineCallbackNode != null) return;

    final String paramName = node.name.label.name;
    if (!PreferUseCallbackRule._callbackParams.contains(paramName)) {
      super.visitNamedExpression(node);
      return;
    }

    // Check if the value is an inline closure
    final Expression value = node.expression;
    if (value is FunctionExpression) {
      inlineCallbackNode = value;
      return;
    }

    super.visitNamedExpression(node);
  }
}
