// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

/// Forms and input validation lint rules for Flutter applications.
///
/// These rules help identify common form handling issues including missing
/// form keys, incorrect validation modes, and keyboard type mismatches.
library;

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/error.dart'
    show AnalysisError, DiagnosticSeverity;
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../saropa_lint_rule.dart';

/// Warns when AutovalidateMode.always is used.
///
/// AutovalidateMode.always validates on every keystroke, which shows
/// error messages immediately before the user finishes typing. This is
/// a poor UX. Use onUserInteraction instead.
///
/// **BAD:**
/// ```dart
/// Form(
///   autovalidateMode: AutovalidateMode.always,
///   child: TextFormField(),
/// )
/// // Shows "Invalid email" while user is still typing
/// ```
///
/// **GOOD:**
/// ```dart
/// Form(
///   autovalidateMode: AutovalidateMode.onUserInteraction,
///   child: TextFormField(),
/// )
/// // Validates when user moves to next field
/// ```
class PreferAutovalidateOnInteractionRule extends SaropaLintRule {
  const PreferAutovalidateOnInteractionRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'prefer_autovalidate_on_interaction',
    problemMessage:
        'AutovalidateMode.always validates every keystroke. Poor UX.',
    correctionMessage:
        'Use AutovalidateMode.onUserInteraction for better user experience.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addPrefixedIdentifier((PrefixedIdentifier node) {
      if (node.prefix.name == 'AutovalidateMode' &&
          node.identifier.name == 'always') {
        reporter.atNode(node, code);
      }
    });
  }

  @override
  List<Fix> getFixes() => <Fix>[_ChangeToOnUserInteractionFix()];
}

class _ChangeToOnUserInteractionFix extends DartFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    context.registry.addPrefixedIdentifier((PrefixedIdentifier node) {
      if (!node.sourceRange.intersects(analysisError.sourceRange)) return;

      final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
        message: 'Change to onUserInteraction',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        builder.addSimpleReplacement(
          node.sourceRange,
          'AutovalidateMode.onUserInteraction',
        );
      });
    });
  }
}

/// Warns when email or phone fields use the wrong keyboard type.
///
/// Using the correct keyboardType improves UX by showing relevant keys.
/// Email fields should show @ and .com, phone fields should show numbers.
///
/// **BAD:**
/// ```dart
/// TextFormField(
///   decoration: InputDecoration(labelText: 'Email'),
///   // Uses default text keyboard without @ key
/// )
/// TextFormField(
///   decoration: InputDecoration(labelText: 'Phone'),
///   // Uses default text keyboard, not number pad
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// TextFormField(
///   decoration: InputDecoration(labelText: 'Email'),
///   keyboardType: TextInputType.emailAddress,
/// )
/// TextFormField(
///   decoration: InputDecoration(labelText: 'Phone'),
///   keyboardType: TextInputType.phone,
/// )
/// ```
class RequireKeyboardTypeRule extends SaropaLintRule {
  const RequireKeyboardTypeRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'require_keyboard_type',
    problemMessage:
        'Text field appears to be email/phone but lacks appropriate keyboardType.',
    correctionMessage:
        'Add keyboardType: TextInputType.emailAddress or TextInputType.phone.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  static const Set<String> _emailPatterns = <String>{
    'email',
    'e-mail',
    'e_mail',
    'emailaddress',
  };

  static const Set<String> _phonePatterns = <String>{
    'phone',
    'telephone',
    'mobile',
    'cell',
    'phonenumber',
    'phone_number',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addInstanceCreationExpression((
      InstanceCreationExpression node,
    ) {
      final String? constructorName = node.constructorName.type.element?.name;
      if (constructorName != 'TextFormField' &&
          constructorName != 'TextField') {
        return;
      }

      String? labelText;
      String? hintText;
      bool hasKeyboardType = false;

      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression) {
          final String name = arg.name.label.name;

          if (name == 'keyboardType') {
            hasKeyboardType = true;
          }

          if (name == 'decoration') {
            // Extract label/hint from InputDecoration
            final Expression decorationExpr = arg.expression;
            if (decorationExpr is InstanceCreationExpression) {
              for (final Expression decorArg
                  in decorationExpr.argumentList.arguments) {
                if (decorArg is NamedExpression) {
                  final String decorName = decorArg.name.label.name;
                  if (decorName == 'labelText') {
                    final Expression labelExpr = decorArg.expression;
                    if (labelExpr is SimpleStringLiteral) {
                      labelText = labelExpr.value.toLowerCase();
                    }
                  }
                  if (decorName == 'hintText') {
                    final Expression hintExpr = decorArg.expression;
                    if (hintExpr is SimpleStringLiteral) {
                      hintText = hintExpr.value.toLowerCase();
                    }
                  }
                }
              }
            }
          }
        }
      }

      if (hasKeyboardType) return;

      final String combined = '${labelText ?? ''} ${hintText ?? ''}';

      bool isEmailField =
          _emailPatterns.any((String p) => combined.contains(p));
      bool isPhoneField =
          _phonePatterns.any((String p) => combined.contains(p));

      if (isEmailField || isPhoneField) {
        reporter.atNode(node.constructorName, code);
      }
    });
  }
}

/// Warns when Text widget lacks overflow handling inside Row.
///
/// Text without overflow handling can cause layout overflow errors when
/// the text is longer than available space. Always specify overflow
/// behavior for dynamic text content in horizontal layouts.
///
/// **BAD:**
/// ```dart
/// Row(
///   children: [
///     Text(userName), // Can overflow if name is long!
///   ],
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// Row(
///   children: [
///     Expanded(
///       child: Text(
///         userName,
///         overflow: TextOverflow.ellipsis,
///       ),
///     ),
///   ],
/// )
/// ```
class RequireTextOverflowInRowRule extends SaropaLintRule {
  const RequireTextOverflowInRowRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'require_text_overflow_in_row',
    problemMessage:
        'Text in Row without overflow handling may cause overflow error.',
    correctionMessage:
        'Add overflow: TextOverflow.ellipsis or wrap in Expanded/Flexible.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addInstanceCreationExpression((
      InstanceCreationExpression node,
    ) {
      final String? constructorName = node.constructorName.type.element?.name;
      if (constructorName != 'Text') return;

      // Check if Text has overflow specified
      bool hasOverflow = false;
      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression && arg.name.label.name == 'overflow') {
          hasOverflow = true;
          break;
        }
      }

      if (hasOverflow) return;

      // Check if inside a Row (where overflow is common)
      AstNode? current = node.parent;
      bool isInRow = false;
      bool hasExpandedOrFlexible = false;

      while (current != null) {
        if (current is InstanceCreationExpression) {
          final String? name = current.constructorName.type.element?.name;
          if (name == 'Row') {
            isInRow = true;
          }
          if (name == 'Expanded' || name == 'Flexible') {
            hasExpandedOrFlexible = true;
          }
        }
        current = current.parent;
      }

      // Only report if in Row without Expanded/Flexible wrapping
      if (isInRow && !hasExpandedOrFlexible) {
        reporter.atNode(node.constructorName, code);
      }
    });
  }
}

/// Warns when password field doesn't use obscureText.
///
/// Password fields should obscure input to prevent shoulder surfing.
/// Not using obscureText exposes passwords on screen.
///
/// **BAD:**
/// ```dart
/// TextFormField(
///   decoration: InputDecoration(labelText: 'Password'),
///   // Password visible on screen!
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// TextFormField(
///   decoration: InputDecoration(labelText: 'Password'),
///   obscureText: true,
/// )
/// ```
class RequireSecureKeyboardRule extends SaropaLintRule {
  const RequireSecureKeyboardRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'require_secure_keyboard',
    problemMessage: 'Password field should use obscureText: true.',
    correctionMessage: 'Add obscureText: true to hide password input.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  static const Set<String> _passwordPatterns = <String>{
    'password',
    'passwd',
    'passwort',
    'contraseña',
    'mot de passe',
    'secret',
    'pin',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addInstanceCreationExpression((
      InstanceCreationExpression node,
    ) {
      final String? constructorName = node.constructorName.type.element?.name;
      if (constructorName != 'TextFormField' &&
          constructorName != 'TextField') {
        return;
      }

      String? labelText;
      String? hintText;
      bool hasObscureText = false;

      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression) {
          final String name = arg.name.label.name;

          if (name == 'obscureText') {
            hasObscureText = true;
          }

          if (name == 'decoration') {
            final Expression decorationExpr = arg.expression;
            if (decorationExpr is InstanceCreationExpression) {
              for (final Expression decorArg
                  in decorationExpr.argumentList.arguments) {
                if (decorArg is NamedExpression) {
                  final String decorName = decorArg.name.label.name;
                  if (decorName == 'labelText') {
                    final Expression labelExpr = decorArg.expression;
                    if (labelExpr is SimpleStringLiteral) {
                      labelText = labelExpr.value.toLowerCase();
                    }
                  }
                  if (decorName == 'hintText') {
                    final Expression hintExpr = decorArg.expression;
                    if (hintExpr is SimpleStringLiteral) {
                      hintText = hintExpr.value.toLowerCase();
                    }
                  }
                }
              }
            }
          }
        }
      }

      if (hasObscureText) return;

      final String combined = '${labelText ?? ''} ${hintText ?? ''}';

      bool isPasswordField =
          _passwordPatterns.any((String p) => combined.contains(p));

      if (isPasswordField) {
        reporter.atNode(node.constructorName, code);
      }
    });
  }

  @override
  List<Fix> getFixes() => <Fix>[_AddObscureTextFix()];
}

class _AddObscureTextFix extends DartFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    context.registry.addInstanceCreationExpression((
      InstanceCreationExpression node,
    ) {
      if (!node.sourceRange.intersects(analysisError.sourceRange)) return;

      final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
        message: 'Add obscureText: true',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        final ArgumentList args = node.argumentList;
        if (args.arguments.isEmpty) {
          builder.addSimpleInsertion(
            args.leftParenthesis.end,
            'obscureText: true',
          );
        } else {
          builder.addSimpleInsertion(
            args.arguments.last.end,
            ', obscureText: true',
          );
        }
      });
    });
  }
}
