// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

/// flutter_keyboard_visibility package lint rules.
///
/// Ensures KeyboardVisibilityController subscriptions are canceled in dispose()
/// so callbacks do not fire on disposed widgets and leak memory.
library;

import 'package:analyzer/dart/ast/ast.dart';

import '../../saropa_lint_rule.dart';

/// Warns when KeyboardVisibilityController is not disposed.
///
/// Since: v2.2.0 | Updated: v4.13.0 | Rule version: v2
///
/// Alias: dispose_keyboard_visibility, keyboard_visibility_leak
///
/// KeyboardVisibilityController listeners must be canceled to prevent
/// memory leaks and callbacks to disposed widgets.
///
/// **BAD:**
/// ```dart
/// class _MyState extends State<MyWidget> {
///   late KeyboardVisibilityController _keyboardController;
///
///   @override
///   void initState() {
///     super.initState();
///     _keyboardController = KeyboardVisibilityController();
///     _keyboardController.onChange.listen((visible) {});
///   }
///   // Missing dispose!
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// class _MyState extends State<MyWidget> {
///   late KeyboardVisibilityController _keyboardController;
///   StreamSubscription? _subscription;
///
///   @override
///   void initState() {
///     super.initState();
///     _keyboardController = KeyboardVisibilityController();
///     _subscription = _keyboardController.onChange.listen((visible) {});
///   }
///
///   @override
///   void dispose() {
///     _subscription?.cancel();
///     super.dispose();
///   }
/// }
/// ```
class RequireKeyboardVisibilityDisposeRule extends SaropaLintRule {
  RequireKeyboardVisibilityDisposeRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.warning;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'packages'};

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    'require_keyboard_visibility_dispose',
    '[require_keyboard_visibility_dispose] A KeyboardVisibilityController '
        'subscription that is never canceled keeps firing visibility callbacks '
        'after the widget is disposed, so setState runs on an unmounted State '
        'and throws, while the retained listener leaks the widget and the '
        'subtree it closes over. {v2}',
    correctionMessage: 'Store and cancel the stream subscription in dispose().',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    // Local regex so closure can reference it (analyzer scope).
    final disposeCancelPattern = RegExp(r'[?.]\s*cancel\s*\(');
    context.addClassDeclaration((ClassDeclaration node) {
      final ExtendsClause? extendsClause = node.extendsClause;
      if (extendsClause == null) return;

      final String superName = extendsClause.superclass.name.lexeme;
      if (superName != 'State') return;

      // Check for KeyboardVisibilityController usage
      final String classSource = node.toSource();
      if (!RegExp(r'\bKeyboardVisibilityController\b').hasMatch(classSource)) {
        return;
      }

      // Check for proper cleanup patterns in dispose
      MethodDeclaration? disposeMethod;
      for (final ClassMember member in node.bodyMembers) {
        if (member is MethodDeclaration && member.name.lexeme == 'dispose') {
          disposeMethod = member;
          break;
        }
      }

      final bool hasCleanup =
          disposeMethod != null &&
          (disposeCancelPattern.hasMatch(disposeMethod.body.toSource()) ||
              RegExp(
                r'\bdispose\s*\(\s*\)',
              ).hasMatch(disposeMethod.body.toSource()));

      if (!hasCleanup && RegExp(r'\.listen\s*\(').hasMatch(classSource)) {
        final keyboardControllerPattern = RegExp(
          r'\bKeyboardVisibilityController\b',
        );
        for (final ClassMember member in node.bodyMembers) {
          if (member is FieldDeclaration) {
            final String fieldSource = member.toSource();
            if (keyboardControllerPattern.hasMatch(fieldSource)) {
              reporter.atNode(member);
              return;
            }
          }
        }
      }
    });
  }
}
