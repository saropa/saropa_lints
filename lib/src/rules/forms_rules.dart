// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

/// Forms and input validation lint rules for Flutter applications.
///
/// These rules help identify common form handling issues including missing
/// form keys, incorrect validation modes, and keyboard type mismatches.
library;

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart'
    show AnalysisError, DiagnosticSeverity;
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../saropa_lint_rule.dart';

// =============================================================================
// Shared Constants
// =============================================================================

/// Common text field widget types.
const Set<String> _textFieldTypes = <String>{
  'TextField',
  'TextFormField',
};

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

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'prefer_autovalidate_on_interaction',
    problemMessage:
        '[prefer_autovalidate_on_interaction] AutovalidateMode.always triggers form validation on every keystroke and widget rebuild. This causes visible input lag as validators run continuously, fires excessive error messages before the user finishes typing, and degrades the user experience with distracting red error text that appears immediately on empty fields.',
    correctionMessage:
        'Use AutovalidateMode.onUserInteraction to defer validation until the user interacts with the field, reducing input lag and preventing premature error display.',
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

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'require_keyboard_type',
    problemMessage:
        '[require_keyboard_type] Text field label suggests email or phone input but no keyboardType is specified. Without TextInputType.emailAddress or TextInputType.phone, users see a generic text keyboard lacking the @ key, .com shortcut, or numeric layout. This causes input errors, slows data entry, and hurts accessibility for users who rely on specialized keyboard layouts.',
    correctionMessage:
        'Add keyboardType: TextInputType.emailAddress for email fields or TextInputType.phone for phone number fields to show the appropriate keyboard layout.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  // cspell:ignore emailaddress
  static const Set<String> _emailPatterns = <String>{
    'email',
    'e-mail',
    'e_mail',
    'emailaddress',
  };

  // cspell:ignore phonenumber
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

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'require_text_overflow_in_row',
    problemMessage:
        '[require_text_overflow_in_row] Text child element inside a Row build tree has no overflow handling. When text content exceeds the available width, Flutter renders yellow and black diagonal overflow stripes that break the visual layout. Users see unreadable, clipped content with an ugly error indicator instead of gracefully truncated or wrapped text.',
    correctionMessage:
        'Add overflow: TextOverflow.ellipsis to the Text widget, or wrap it in an Expanded or Flexible widget to constrain its width within the Row layout.',
    errorSeverity: DiagnosticSeverity.WARNING,
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

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'require_secure_keyboard',
    problemMessage:
        '[require_secure_keyboard] Password field detected without obscureText: true. The password is displayed as plain text on screen, exposing credentials to shoulder surfing attacks in public spaces. Nearby observers can read the password directly from the display, compromising user account security and violating OWASP M1 credential protection guidelines.',
    correctionMessage:
        'Add obscureText: true to the TextField or TextFormField to mask password characters and protect user credentials from visual exposure on screen.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  // cspell:ignore passwort contraseña
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

/// Warns when form validation error messages lack context.
///
/// Generic error messages like "Invalid input" or "Required field" are
/// unhelpful. Include the field name and what's expected.
///
/// **BAD:**
/// ```dart
/// TextFormField(
///   validator: (value) {
///     if (value?.isEmpty ?? true) return 'Required';
///     if (!isValidEmail(value!)) return 'Invalid input';
///   },
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// TextFormField(
///   validator: (value) {
///     if (value?.isEmpty ?? true) return 'Email is required';
///     if (!isValidEmail(value!)) return 'Please enter a valid email address';
///   },
/// )
/// ```
class RequireErrorMessageContextRule extends SaropaLintRule {
  const RequireErrorMessageContextRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'require_error_message_context',
    problemMessage:
        '[require_error_message_context] Form validation returns a generic error message without explaining what the user did wrong or how to fix it. Vague messages like "Invalid" or "Required" frustrate users, increase form abandonment rates, and fail accessibility standards that require specific, actionable error feedback to help users correct their input.',
    correctionMessage:
        'Replace generic messages with field-specific guidance: use "Email address format is invalid" instead of "Invalid" or "Phone number is required" instead of "Required".',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  /// Generic error messages that lack context
  static const Set<String> _genericMessages = <String>{
    'required',
    'invalid',
    'invalid input',
    'invalid value',
    'error',
    'not valid',
    'wrong',
    'incorrect',
    'bad input',
    'please fix',
    'check input',
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
      final String? typeName = node.constructorName.type.element?.name;
      if (typeName != 'TextFormField') return;

      // Find validator argument
      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression && arg.name.label.name == 'validator') {
          final String validatorSource = arg.expression.toSource();

          // Check for return statements with string literals
          // Simple pattern: check for short generic messages
          for (final String generic in _genericMessages) {
            // Look for patterns like: return 'Required';
            final RegExp pattern = RegExp(
              "return ['\"]$generic['\"];?",
              caseSensitive: false,
            );
            if (pattern.hasMatch(validatorSource)) {
              reporter.atNode(arg.name, code);
              return;
            }
          }
        }
      }
    });
  }
}

// ============================================================================
// Batch 12: Additional Forms Rules
// ============================================================================

/// Warns when Form widget doesn't have a GlobalKey.
///
/// Alias: require_form_global_key
///
/// Forms without GlobalKey can't call validate() or save(). The FormState
/// is inaccessible without a key.
///
/// **BAD:**
/// ```dart
/// Form(
///   child: TextFormField(...),
/// )
/// // Can't call form.currentState!.validate()
/// ```
///
/// **GOOD:**
/// ```dart
/// final _formKey = GlobalKey<FormState>();
///
/// Form(
///   key: _formKey,
///   child: TextFormField(...),
/// )
/// // _formKey.currentState!.validate()
/// ```
class RequireFormKeyRule extends SaropaLintRule {
  const RequireFormKeyRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'require_form_key',
    problemMessage:
        '[require_form_key] Without GlobalKey, validate() and save() calls '
        'fail because FormState cannot be accessed.',
    correctionMessage:
        'Add key: _formKey where _formKey = GlobalKey<FormState>()',
    errorSeverity: DiagnosticSeverity.WARNING,
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
      final String typeName = node.constructorName.type.name.lexeme;
      if (typeName != 'Form') return;

      // Check if key argument exists
      bool hasKey = false;
      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression && arg.name.label.name == 'key') {
          hasKey = true;
          break;
        }
      }

      if (!hasKey) {
        reporter.atNode(node.constructorName, code);
      }
    });
  }
}

/// Warns when complex validation logic is in build method.
///
/// Complex validation (regex, API calls) in validator runs on every
/// keystroke. Debounce or validate on submit only.
///
/// **BAD:**
/// ```dart
/// Widget build(BuildContext context) {
///   return TextFormField(
///     validator: (value) async {
///       final isAvailable = await checkUsernameAvailability(value!);
///       return isAvailable ? null : 'Username taken';
///     },
///   );
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// // Use async validation on submit
/// void _onSubmit() async {
///   if (_formKey.currentState!.validate()) {
///     final isAvailable = await checkUsernameAvailability(_username);
///     if (!isAvailable) {
///       _showError('Username taken');
///       return;
///     }
///     // proceed...
///   }
/// }
/// ```
class AvoidValidationInBuildRule extends SaropaLintRule {
  const AvoidValidationInBuildRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_validation_in_build',
    problemMessage:
        '[avoid_validation_in_build] Complex or async validation running inside build() executes on every keystroke and widget rebuild. This causes visible input lag as network calls fire per character, floods the backend API with excessive requests, degrades performance with unnecessary widget rebuilds, and frustrates users who see delayed responses while typing in form fields.',
    correctionMessage:
        'Move complex validation logic to the form onSubmit handler, or use a debounce mechanism to delay validation until the user pauses typing for a set interval.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodDeclaration((MethodDeclaration node) {
      if (node.name.lexeme != 'build') return;

      node.body.visitChildren(_ValidatorVisitor(reporter, code));
    });
  }
}

class _ValidatorVisitor extends RecursiveAstVisitor<void> {
  _ValidatorVisitor(this.reporter, this.code);

  final SaropaDiagnosticReporter reporter;
  final LintCode code;

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    // Check for validator argument in TextFormField
    for (final Expression arg in node.argumentList.arguments) {
      if (arg is NamedExpression && arg.name.label.name == 'validator') {
        final String source = arg.expression.toSource();
        // Check for async or expensive patterns
        if (source.contains('async') ||
            source.contains('await') ||
            source.contains('http') ||
            source.contains('dio') ||
            source.contains('.get(') ||
            source.contains('.post(')) {
          reporter.atNode(arg.name, code);
        }
      }
    }
    super.visitInstanceCreationExpression(node);
  }
}

/// Warns when submit buttons don't show loading state during submission.
///
/// Submit buttons should disable during submission and show loading
/// indicator. Prevents double-submit and shows progress.
///
/// **BAD:**
/// ```dart
/// ElevatedButton(
///   onPressed: () async {
///     await submitForm();
///   },
///   child: Text('Submit'),
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// ElevatedButton(
///   onPressed: _isLoading ? null : () async {
///     setState(() => _isLoading = true);
///     await submitForm();
///     setState(() => _isLoading = false);
///   },
///   child: _isLoading ? CircularProgressIndicator() : Text('Submit'),
/// )
/// ```
class RequireSubmitButtonStateRule extends SaropaLintRule {
  const RequireSubmitButtonStateRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'require_submit_button_state',
    problemMessage:
        '[require_submit_button_state] Submit button with an async onPressed handler lacks a loading state guard. Without disabling the button during submission, users can tap repeatedly and trigger duplicate network connection requests, duplicate database writes, and duplicate payment transactions. Each extra tap fires another async operation, wasting server memory and bandwidth while producing confusing duplicate entries.',
    correctionMessage:
        'Add a boolean loading state flag and set onPressed: _isLoading ? null : _submit to disable the button during async submission.',
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
      final String typeName = node.constructorName.type.name.lexeme;
      if (!typeName.contains('Button')) return;

      // Find onPressed argument
      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression && arg.name.label.name == 'onPressed') {
          final String source = arg.expression.toSource();
          // Check for async without loading state
          if (source.contains('async') &&
              !source.contains('Loading') &&
              !source.contains('loading') &&
              !source.contains('isLoading') &&
              !source.contains('_loading')) {
            reporter.atNode(arg.name, code);
          }
        }
      }
    });
  }
}

/// Warns when forms don't unfocus after submission.
///
/// Forms should unfocus (FocusScope.of(context).unfocus()) on submit.
/// Keyboard staying open after submit feels broken.
///
/// **BAD:**
/// ```dart
/// void _onSubmit() {
///   if (_formKey.currentState!.validate()) {
///     // Submit without closing keyboard
///     _doSubmit();
///   }
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// void _onSubmit() {
///   FocusScope.of(context).unfocus(); // Close keyboard first
///   if (_formKey.currentState!.validate()) {
///     _doSubmit();
///   }
/// }
/// ```
class AvoidFormWithoutUnfocusRule extends SaropaLintRule {
  const AvoidFormWithoutUnfocusRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_form_without_unfocus',
    problemMessage:
        '[avoid_form_without_unfocus] Form submission handler does not call unfocus() before processing. The on-screen keyboard stays open after submission, blocking the success message, navigation, or dialog that confirms the action to the user. This creates a confusing experience where users cannot see feedback and may repeatedly tap the submit button.',
    correctionMessage:
        'Add FocusScope.of(context).unfocus() at the beginning of the submit handler to dismiss the keyboard before showing any success feedback or navigation.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodDeclaration((MethodDeclaration node) {
      final String name = node.name.lexeme.toLowerCase();
      // Look for submit-related methods
      if (!name.contains('submit') &&
          !name.contains('save') &&
          !name.contains('send')) {
        return;
      }

      final String bodySource = node.body.toSource();

      // Check if it validates a form but doesn't unfocus
      if (bodySource.contains('.validate()') &&
          !bodySource.contains('unfocus') &&
          !bodySource.contains('FocusManager') &&
          !bodySource.contains('FocusScope')) {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when long forms don't use state restoration.
///
/// Long forms should survive app backgrounding. Use RestorationMixin
/// or persist draft state to avoid losing user input.
///
/// **BAD:**
/// ```dart
/// class _FormState extends State<MyForm> {
///   String? _name;
///   String? _email;
///   String? _address;
///   String? _phone;
///   // 5+ fields without restoration = data loss risk
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// class _FormState extends State<MyForm> with RestorationMixin {
///   final RestorableTextEditingController _name = RestorableTextEditingController();
///   // Or persist drafts to SharedPreferences
/// }
/// ```
class RequireFormRestorationRule extends SaropaLintRule {
  const RequireFormRestorationRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'require_form_restoration',
    problemMessage:
        '[require_form_restoration] Form with 5+ TextEditingController fields lacks RestorationMixin. When the operating system kills the app in the background to reclaim memory, all user input is permanently lost. Users who spent time filling out a lengthy form return to find every field empty and must re-enter all data from scratch.',
    correctionMessage:
        'Add RestorationMixin to the State class and use RestorableTextEditingController fields, or persist draft state to SharedPreferences to prevent data loss.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
      // Check if extends State
      final ExtendsClause? extendsClause = node.extendsClause;
      if (extendsClause == null) return;

      final String superName = extendsClause.superclass.name.lexeme;
      if (superName != 'State') return;

      // Check if has RestorationMixin
      final WithClause? withClause = node.withClause;
      if (withClause != null) {
        for (final NamedType mixin in withClause.mixinTypes) {
          if (mixin.name.lexeme == 'RestorationMixin') return;
        }
      }

      // Count form-related fields (TextEditingController only)
      int controllerCount = 0;
      bool hasForm = false;

      for (final ClassMember member in node.members) {
        if (member is FieldDeclaration) {
          final String? typeName = member.fields.type?.toSource();
          if (typeName != null && typeName.contains('TextEditingController')) {
            controllerCount += member.fields.variables.length;
          }
        }
        // Check if class has Form in build method
        if (member is MethodDeclaration && member.name.lexeme == 'build') {
          final String source = member.body.toSource();
          if (source.contains('Form(')) {
            hasForm = true;
          }
        }
      }

      // Warn if 5+ controllers without restoration (and has a Form)
      if (controllerCount >= 5 && hasForm) {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when forms clear input on validation error.
///
/// Clearing fields when validation fails forces users to re-enter
/// everything. Preserve input and highlight errors.
///
/// **BAD:**
/// ```dart
/// void _onSubmit() {
///   if (!_formKey.currentState!.validate()) {
///     _nameController.clear(); // User loses input!
///     return;
///   }
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// void _onSubmit() {
///   if (!_formKey.currentState!.validate()) {
///     // Keep input, just show errors
///     return;
///   }
/// }
/// ```
class AvoidClearingFormOnErrorRule extends SaropaLintRule {
  const AvoidClearingFormOnErrorRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_clearing_form_on_error',
    problemMessage:
        '[avoid_clearing_form_on_error] Form fields are cleared when validation fails, destroying all user input. Users lose their partially-correct data and must re-enter everything from scratch. This frustrating pattern increases form abandonment, wastes user time, and creates a hostile experience that drives users away from completing the form submission.',
    correctionMessage:
        'Preserve all form field values when validation fails. Only highlight the specific fields with errors and show inline error messages to guide the user in correcting their input.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addIfStatement((IfStatement node) {
      final String condition = node.expression.toSource();

      // Check for !validate() or validate() == false
      final bool isValidationFailure =
          (condition.contains('!') && condition.contains('validate()')) ||
              condition.contains('validate() == false') ||
              condition.contains('validate()==false');

      if (isValidationFailure) {
        // Check if body contains .clear()
        final String thenSource = node.thenStatement.toSource();
        if (thenSource.contains('.clear()')) {
          reporter.atNode(node, code);
        }
      }
    });
  }
}

/// Warns when TextFormField has neither controller nor onSaved.
///
/// TextFormField without controller loses value on rebuild. Either
/// use controller or onSaved, but be consistent.
///
/// **BAD:**
/// ```dart
/// TextFormField(
///   decoration: InputDecoration(labelText: 'Name'),
///   // No controller or onSaved - value lost on rebuild!
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// TextFormField(
///   controller: _nameController,
///   decoration: InputDecoration(labelText: 'Name'),
/// )
/// // Or
/// TextFormField(
///   onSaved: (value) => _name = value,
///   decoration: InputDecoration(labelText: 'Name'),
/// )
/// ```
class RequireFormFieldControllerRule extends SaropaLintRule {
  const RequireFormFieldControllerRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'require_form_field_controller',
    problemMessage:
        '[require_form_field_controller] TextFormField has no controller, onSaved, or initialValue. When the parent StatefulWidget triggers a rebuild via setState(), the field value is silently discarded because there is no mechanism to persist or retrieve the user input. This causes typed data to vanish unpredictably and forces users to re-enter their input repeatedly.',
    correctionMessage:
        'Add controller: _controller to persist the value, or onSaved: (value) => _field = value to capture input on form save.',
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
      final String typeName = node.constructorName.type.name.lexeme;
      if (typeName != 'TextFormField') return;

      bool hasController = false;
      bool hasOnSaved = false;
      bool hasInitialValue = false;

      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression) {
          final String name = arg.name.label.name;
          if (name == 'controller') hasController = true;
          if (name == 'onSaved') hasOnSaved = true;
          if (name == 'initialValue') hasInitialValue = true;
        }
      }

      // Warn if no way to persist/access value
      if (!hasController && !hasOnSaved && !hasInitialValue) {
        reporter.atNode(node.constructorName, code);
      }
    });
  }
}

/// Warns when Form is used inside AlertDialog or SimpleDialog.
///
/// Forms in dialogs can lose state when dialog rebuilds. Consider
/// using a separate StatefulWidget for the form content.
///
/// **BAD:**
/// ```dart
/// showDialog(
///   builder: (context) => AlertDialog(
///     content: Form(
///       child: TextFormField(), // State lost on dialog rebuild!
///     ),
///   ),
/// );
/// ```
///
/// **GOOD:**
/// ```dart
/// showDialog(
///   builder: (context) => AlertDialog(
///     content: _FormContent(), // Separate StatefulWidget
///   ),
/// );
///
/// class _FormContent extends StatefulWidget { ... }
/// ```
class AvoidFormInAlertDialogRule extends SaropaLintRule {
  const AvoidFormInAlertDialogRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'avoid_form_in_alert_dialog',
    problemMessage:
        '[avoid_form_in_alert_dialog] Form placed directly inside AlertDialog loses all field values, validation state, and user input when the dialog rebuilds due to a parent setState() or keyboard appearance. Because the dialog builder creates a new Form on each build call, there is no StatefulWidget to preserve form state across rebuilds, producing a frustrating experience where typed data disappears.',
    correctionMessage:
        'Extract the form content into a dedicated StatefulWidget class and use that as the dialog content to preserve form state reliably.',
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
      final String typeName = node.constructorName.type.name.lexeme;
      if (typeName != 'AlertDialog' && typeName != 'SimpleDialog') return;

      // Check if content contains Form
      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression && arg.name.label.name == 'content') {
          final String contentSource = arg.expression.toSource();
          if (contentSource.contains('Form(')) {
            reporter.atNode(arg.name, code);
          }
        }
      }
    });
  }
}

/// Warns when TextField or TextFormField lacks textInputAction parameter.
///
/// The textInputAction parameter controls the keyboard action button
/// (e.g., Next, Done). This improves form navigation and UX.
///
/// **BAD:**
/// ```dart
/// TextField(
///   controller: _controller,
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// TextField(
///   controller: _controller,
///   textInputAction: TextInputAction.next,
/// )
/// ```
class RequireKeyboardActionTypeRule extends SaropaLintRule {
  const RequireKeyboardActionTypeRule() : super(code: _code);

  /// Minor improvement. Track for later review.
  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'require_keyboard_action_type',
    problemMessage:
        '[require_keyboard_action_type] Text field must have textInputAction to improve UX. The textInputAction parameter controls the keyboard action button (e.g., Next, Done). This improves form navigation and UX.',
    correctionMessage:
        'Add textInputAction: TextInputAction.next or TextInputAction.done. Verify the change works correctly with existing tests and add coverage for the new behavior.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  static const Set<String> _textFieldTypes = <String>{
    'TextField',
    'TextFormField',
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
      final String typeName = node.constructorName.type.name.lexeme;
      if (!_textFieldTypes.contains(typeName)) return;

      // Check for textInputAction parameter
      bool hasTextInputAction = false;
      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression &&
            arg.name.label.name == 'textInputAction') {
          hasTextInputAction = true;
          break;
        }
      }

      if (!hasTextInputAction) {
        reporter.atNode(node.constructorName, code);
      }
    });
  }
}

/// Warns when scroll views lack keyboardDismissBehavior parameter.
///
/// ScrollViews containing text fields should specify how the keyboard
/// dismisses when the user scrolls. This provides better UX for forms
/// in scrollable content.
///
/// **BAD:**
/// ```dart
/// ListView(
///   children: [TextField(), TextField()],
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// ListView(
///   keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
///   children: [TextField(), TextField()],
/// )
/// ```
class RequireKeyboardDismissOnScrollRule extends SaropaLintRule {
  const RequireKeyboardDismissOnScrollRule() : super(code: _code);

  /// Minor improvement. Track for later review.
  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'require_keyboard_dismiss_on_scroll',
    problemMessage:
        '[require_keyboard_dismiss_on_scroll] Scroll view must have keyboardDismissBehavior for form UX. ScrollViews containing text fields should specify how the keyboard dismisses when the user scrolls. This provides better UX for forms in scrollable content.',
    correctionMessage:
        'Add keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag. Verify the change works correctly with existing tests and add coverage for the new behavior.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  static const Set<String> _scrollViewTypes = <String>{
    'ListView',
    'CustomScrollView',
    'SingleChildScrollView',
    'GridView',
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
      final String typeName = node.constructorName.type.name.lexeme;
      if (!_scrollViewTypes.contains(typeName)) return;

      // Check for keyboardDismissBehavior parameter
      bool hasKeyboardDismissBehavior = false;
      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression &&
            arg.name.label.name == 'keyboardDismissBehavior') {
          hasKeyboardDismissBehavior = true;
          break;
        }
      }

      if (!hasKeyboardDismissBehavior) {
        reporter.atNode(node.constructorName, code);
      }
    });
  }
}

/// Warns when TextField at bottom of screen doesn't handle keyboard overlap.
///
/// When keyboard appears, TextFields at the bottom can be hidden.
/// Use viewInsets or resizeToAvoidBottomInset to handle this.
///
/// **Quick fix available:** Adds a comment for manual keyboard handling.
///
/// **BAD:**
/// ```dart
/// Scaffold(
///   body: Column(
///     children: [
///       Spacer(),
///       TextField(), // Hidden when keyboard shows
///     ],
///   ),
/// );
/// ```
///
/// **GOOD:**
/// ```dart
/// Scaffold(
///   resizeToAvoidBottomInset: true,
///   body: SingleChildScrollView(
///     child: Column(
///       children: [
///         Spacer(),
///         TextField(),
///       ],
///     ),
///   ),
/// );
/// ```
///
/// **ALSO GOOD:**
/// ```dart
/// Padding(
///   padding: EdgeInsets.only(
///     bottom: MediaQuery.of(context).viewInsets.bottom,
///   ),
///   child: TextField(),
/// );
/// ```
class AvoidKeyboardOverlapRule extends SaropaLintRule {
  const AvoidKeyboardOverlapRule() : super(code: _code);

  /// UX issue - form fields hidden by keyboard.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'avoid_keyboard_overlap',
    problemMessage:
        '[avoid_keyboard_overlap] TextField may be hidden behind the soft keyboard when no viewInsets handling is detected. Users cannot see what they are typing, leading to input errors, frustration, and accessibility failures on devices where the keyboard covers a large portion of the screen.',
    correctionMessage:
        'Wrap the form content in a SingleChildScrollView, or use MediaQuery.viewInsets.bottom to add padding that keeps the focused TextField visible.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addInstanceCreationExpression((node) {
      final typeName = node.constructorName.type.name.lexeme;

      if (typeName != 'TextField' && typeName != 'TextFormField') {
        return;
      }

      // Check if inside a Column with positioning at bottom
      AstNode? current = node.parent;
      bool inColumn = false;
      bool hasScrollParent = false;

      while (current != null) {
        if (current is InstanceCreationExpression) {
          final parentType = current.constructorName.type.name.lexeme;

          if (parentType == 'Column') {
            inColumn = true;
          }
          if (parentType == 'SingleChildScrollView' ||
              parentType == 'ListView' ||
              parentType == 'CustomScrollView') {
            hasScrollParent = true;
          }
          // Skip containers that handle keyboard overlap themselves.
          // - Dialog/AlertDialog: Flutter pushes dialogs above keyboard
          // - BottomSheet: Typically resizes or scrolls with keyboard
          // NOTE: We intentionally do NOT skip ExpansionTile here.
          // ExpansionTiles are collapsible sections that can appear anywhere
          // in a screen. The PARENT screen must handle viewInsets - the linter
          // should still warn so developers fix the parent, not suppress here.
          if (parentType.contains('Dialog') ||
              parentType.contains('BottomSheet')) {
            return;
          }
        }
        // Check if the enclosing CLASS has 'Dialog' in its name.
        // This handles widgets designed for dialog use, e.g., _DialogContent,
        // _DialogOrganizationAdd, where the class itself is dialog content.
        if (current is ClassDeclaration) {
          final className = current.name.lexeme;
          if (className.toLowerCase().contains('dialog')) {
            return;
          }
        }
        if (current is MethodDeclaration) {
          break;
        }
        current = current.parent;
      }

      if (!inColumn) {
        return;
      }

      if (hasScrollParent) {
        return;
      }

      // Check the ENTIRE FILE for various dialog-related patterns.
      // Static analysis can't follow widget composition at runtime, so we check
      // if ANY code in the same file suggests dialog usage.
      current = node.parent;
      while (current != null) {
        if (current is CompilationUnit) {
          final fileSource = current.toSource().toLowerCase();

          // cspell:ignore viewinsets resizetobottominset ensurevisible
          // Skip if file handles viewInsets, resize behavior, or Scrollable.ensureVisible
          if (fileSource.contains('viewinsets') ||
              fileSource.contains('resizetobottominset') ||
              fileSource.contains('ensurevisible')) {
            return;
          }

          // cspell:ignore showdialog showdialogcommon
          // Skip if file contains showDialog calls - widgets in such files
          // are likely designed as dialog content. This handles cases where
          // a widget class is defined alongside its showDialog wrapper function.
          if (fileSource.contains('showdialog') ||
              fileSource.contains('showdialogcommon')) {
            return;
          }

          break;
        }
        current = current.parent;
      }

      // Also skip if file path contains 'dialog' - files in dialog/ folders
      // or with 'dialog' in name are likely dialog components.
      final filePath = resolver.path.toLowerCase();
      if (filePath.contains('dialog')) {
        return;
      }

      reporter.atNode(node.constructorName, code);
    });
  }

  @override
  List<Fix> getFixes() => <Fix>[_AddKeyboardHandlingCommentFix()];
}

class _AddKeyboardHandlingCommentFix extends DartFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    context.registry.addInstanceCreationExpression((node) {
      final typeName = node.constructorName.type.name.lexeme;
      if (typeName != 'TextField' && typeName != 'TextFormField') return;
      if (!node.sourceRange.intersects(analysisError.sourceRange)) return;

      final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
        message: 'Add keyboard handling comment',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        builder.addSimpleInsertion(
          node.offset,
          '// HACK: Wrap parent in SingleChildScrollView or use MediaQuery.viewInsets\n              ',
        );
      });
    });
  }
}

/// Warns when Form widget doesn't have autovalidateMode parameter.
///
/// Forms should specify how validation is triggered for consistent UX.
/// The autovalidateMode parameter controls when the form fields validate.
///
/// **BAD:**
/// ```dart
/// Form(
///   key: _formKey,
///   child: TextFormField(...),
/// )
/// // Uses default AutovalidateMode.disabled - no automatic validation
/// ```
///
/// **GOOD:**
/// ```dart
/// Form(
///   key: _formKey,
///   autovalidateMode: AutovalidateMode.onUserInteraction,
///   child: TextFormField(...),
/// )
/// // Validates when user interacts with fields
/// ```
class RequireFormAutoValidateModeRule extends SaropaLintRule {
  const RequireFormAutoValidateModeRule() : super(code: _code);

  /// Minor improvement. Track for later review.
  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'require_form_auto_validate_mode',
    problemMessage:
        '[require_form_auto_validate_mode] Form should specify autovalidateMode for consistent UX. Forms should specify how validation is triggered for consistent UX. The autovalidateMode parameter controls when the form fields validate.',
    correctionMessage:
        'Add autovalidateMode: AutovalidateMode.onUserInteraction. Verify the change works correctly with existing tests and add coverage for the new behavior.',
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
      final String typeName = node.constructorName.type.name.lexeme;
      if (typeName != 'Form') return;

      // Check if autovalidateMode argument exists
      bool hasAutovalidateMode = false;
      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression &&
            arg.name.label.name == 'autovalidateMode') {
          hasAutovalidateMode = true;
          break;
        }
      }

      if (!hasAutovalidateMode) {
        reporter.atNode(node.constructorName, code);
      }
    });
  }

  @override
  List<Fix> getFixes() => <Fix>[_AddAutoValidateModeFix()];
}

class _AddAutoValidateModeFix extends DartFix {
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
        message: 'Add autovalidateMode: AutovalidateMode.onUserInteraction',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        final ArgumentList args = node.argumentList;
        if (args.arguments.isEmpty) {
          builder.addSimpleInsertion(
            args.leftParenthesis.end,
            'autovalidateMode: AutovalidateMode.onUserInteraction',
          );
        } else {
          builder.addSimpleInsertion(
            args.arguments.last.end,
            ', autovalidateMode: AutovalidateMode.onUserInteraction',
          );
        }
      });
    });
  }
}

/// Warns when TextField or TextFormField lacks autofillHints parameter.
///
/// The autofillHints parameter enables system autofill to help users complete
/// forms faster. This improves UX especially for common fields like email,
/// password, name, and address.
///
/// **BAD:**
/// ```dart
/// TextFormField(
///   decoration: InputDecoration(labelText: 'Email'),
/// )
/// // User must type email manually
/// ```
///
/// **GOOD:**
/// ```dart
/// TextFormField(
///   decoration: InputDecoration(labelText: 'Email'),
///   autofillHints: [AutofillHints.email],
/// )
/// // System can suggest saved email addresses
/// ```
class RequireAutofillHintsRule extends SaropaLintRule {
  const RequireAutofillHintsRule() : super(code: _code);

  /// Minor improvement. Track for later review.
  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'require_autofill_hints',
    problemMessage:
        '[require_autofill_hints] Form field must have autofillHints to improve user experience. The autofillHints parameter enables system autofill to help users complete forms faster. This improves UX especially for common fields like email, password, name, and address.',
    correctionMessage:
        'Add autofillHints: [AutofillHints.email] or appropriate hint. Verify the change works correctly with existing tests and add coverage for the new behavior.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  static const Set<String> _textFieldTypes = <String>{
    'TextField',
    'TextFormField',
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
      final String typeName = node.constructorName.type.name.lexeme;
      if (!_textFieldTypes.contains(typeName)) return;

      // Check for autofillHints parameter
      bool hasAutofillHints = false;
      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression && arg.name.label.name == 'autofillHints') {
          hasAutofillHints = true;
          break;
        }
      }

      if (!hasAutofillHints) {
        reporter.atNode(node.constructorName, code);
      }
    });
  }
}

/// Warns when form fields lack onFieldSubmitted handler.
///
/// The onFieldSubmitted callback is triggered when the user presses the
/// keyboard action button (e.g., Done, Next). This should be used to move
/// focus to the next field or submit the form for better UX.
///
/// **BAD:**
/// ```dart
/// TextFormField(
///   decoration: InputDecoration(labelText: 'Email'),
///   textInputAction: TextInputAction.next,
/// )
/// // Pressing "Next" does nothing
/// ```
///
/// **GOOD:**
/// ```dart
/// TextFormField(
///   decoration: InputDecoration(labelText: 'Email'),
///   textInputAction: TextInputAction.next,
///   onFieldSubmitted: (_) => _passwordFocusNode.requestFocus(),
/// )
/// // Pressing "Next" moves focus to password field
/// ```
class PreferOnFieldSubmittedRule extends SaropaLintRule {
  const PreferOnFieldSubmittedRule() : super(code: _code);

  /// Minor improvement. Track for later review.
  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'prefer_on_field_submitted',
    problemMessage:
        '[prefer_on_field_submitted] Form field must have onFieldSubmitted to handle keyboard action. This callback fires when the user presses the keyboard action button (e.g., Done, Next). Add it to move focus to the next field or submit the form for a smooth keyboard-driven workflow.',
    correctionMessage:
        'Add onFieldSubmitted: (_) => nextFocusNode.requestFocus() or submit. Verify the change works correctly with existing tests and add coverage for the new behavior.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  static const Set<String> _textFieldTypes = <String>{
    'TextField',
    'TextFormField',
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
      final String typeName = node.constructorName.type.name.lexeme;
      if (!_textFieldTypes.contains(typeName)) return;

      // Check for onFieldSubmitted or onSubmitted parameter
      bool hasOnSubmitted = false;
      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression) {
          final String name = arg.name.label.name;
          if (name == 'onFieldSubmitted' || name == 'onSubmitted') {
            hasOnSubmitted = true;
            break;
          }
        }
      }

      if (!hasOnSubmitted) {
        reporter.atNode(node.constructorName, code);
      }
    });
  }
}

/// Warns when TextField is missing keyboardType.
///
/// Alias: keyboard_type, text_input_type
///
/// Setting the appropriate keyboardType improves user experience by showing
/// the right keyboard layout for the expected input.
///
/// **BAD:**
/// ```dart
/// TextField(
///   controller: _emailController,
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// TextField(
///   controller: _emailController,
///   keyboardType: TextInputType.emailAddress,
/// )
/// ```
class RequireTextInputTypeRule extends SaropaLintRule {
  const RequireTextInputTypeRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'require_text_input_type',
    problemMessage:
        '[require_text_input_type] TextField without keyboardType. Users may see wrong keyboard. Setting the appropriate keyboardType improves user experience by showing the right keyboard layout for the expected input.',
    correctionMessage:
        'Add keyboardType parameter for appropriate keyboard layout. Verify the change works correctly with existing tests and add coverage for the new behavior.',
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
      if (!_textFieldTypes.contains(node.typeName)) return;

      if (!node.hasNamedParameter('keyboardType')) {
        reporter.atNode(node.constructorName, code);
      }
    });
  }
}

/// Warns when TextField is missing textInputAction.
///
/// Alias: input_action, keyboard_action
///
/// Setting textInputAction helps users navigate forms efficiently with
/// the keyboard action button (Done, Next, Search, etc.).
///
/// **BAD:**
/// ```dart
/// TextField(
///   controller: _nameController,
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// TextField(
///   controller: _nameController,
///   textInputAction: TextInputAction.next,
/// )
/// ```
class PreferTextInputActionRule extends SaropaLintRule {
  const PreferTextInputActionRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'prefer_text_input_action',
    problemMessage:
        '[prefer_text_input_action] TextField without textInputAction. Keyboard action button unclear. Setting textInputAction helps users navigate forms efficiently with the keyboard action button (Done, Next, Search, etc.).',
    correctionMessage:
        'Add textInputAction (e.g., TextInputAction.next or .done). Verify the change works correctly with existing tests and add coverage for the new behavior.',
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
      if (!_textFieldTypes.contains(node.typeName)) return;

      if (!node.hasNamedParameter('textInputAction')) {
        reporter.atNode(node.constructorName, code);
      }
    });
  }
}

/// Warns when `GlobalKey<FormState>` is created inside build().
///
/// Alias: form_key_in_build, global_key_in_build
///
/// Creating a GlobalKey inside build() causes a new key on every rebuild,
/// losing form state. GlobalKeys should be created in State fields.
///
/// **BAD:**
/// ```dart
/// Widget build(BuildContext context) {
///   final formKey = GlobalKey<FormState>(); // New key every build!
///   return Form(key: formKey, ...);
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// class _MyState extends State<MyWidget> {
///   final _formKey = GlobalKey<FormState>();
///
///   Widget build(BuildContext context) {
///     return Form(key: _formKey, ...);
///   }
/// }
/// ```
class RequireFormKeyInStatefulWidgetRule extends SaropaLintRule {
  const RequireFormKeyInStatefulWidgetRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    name: 'require_form_key_in_stateful_widget',
    problemMessage:
        '[require_form_key_in_stateful_widget] GlobalKey<FormState> created inside the build() method is re-instantiated on every widget rebuild triggered by setState(). Each rebuild creates a new key, causing the form to lose all current field values, validation state, and user input. This produces a frustrating user experience where typed data disappears unpredictably during state changes.',
    correctionMessage:
        'Declare the GlobalKey<FormState> as a field in the State class rather than inside build(). State class fields persist across rebuilds and preserve form data.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodDeclaration((MethodDeclaration node) {
      // Only check build methods
      if (node.name.lexeme != 'build') return;

      final FunctionBody body = node.body;
      final String bodySource = body.toSource();

      // Check for GlobalKey creation in build
      if (bodySource.contains('GlobalKey<FormState>()') ||
          bodySource.contains('GlobalKey<FormState>(')) {
        reporter.atNode(node, code);
      }
    });
  }
}

// =============================================================================
// prefer_regex_validation
// =============================================================================

/// Warns when form fields use basic validators instead of regex patterns.
///
/// Alias: regex_validator, pattern_validation
///
/// Basic isEmpty checks miss common validation patterns. Use regex for
/// email, phone, URL, and other structured input validation.
///
/// **BAD:**
/// ```dart
/// TextFormField(
///   decoration: InputDecoration(labelText: 'Email'),
///   validator: (value) {
///     if (value == null || value.isEmpty) {
///       return 'Please enter an email';
///     }
///     return null; // Accepts "not an email"!
///   },
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// TextFormField(
///   decoration: InputDecoration(labelText: 'Email'),
///   validator: (value) {
///     if (value == null || value.isEmpty) {
///       return 'Please enter an email';
///     }
///     final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
///     if (!emailRegex.hasMatch(value)) {
///       return 'Please enter a valid email';
///     }
///     return null;
///   },
/// )
///
/// // Or use a validation package
/// import 'package:validators/validators.dart';
/// validator: (value) => isEmail(value) ? null : 'Invalid email',
/// ```
class PreferRegexValidationRule extends SaropaLintRule {
  const PreferRegexValidationRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'prefer_regex_validation',
    problemMessage:
        '[prefer_regex_validation] Form field with basic empty check but label '
        'suggests structured data (email/phone/url). Use regex validation.',
    correctionMessage:
        'Add regex pattern validation for the field type (email, phone, URL, etc.).',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  /// Labels/hints that suggest structured data needing regex validation
  static const Set<String> _structuredDataLabels = <String>{
    'email',
    'e-mail',
    'phone',
    'telephone',
    'mobile',
    'url',
    'website',
    'zip',
    'postal',
    'ssn',
    'credit',
    'card',
    'cvv',
    'cvc',
    'iban',
    'swift',
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
      final String typeName = node.constructorName.type.name.lexeme;

      // Check for form fields
      if (typeName != 'TextFormField' && typeName != 'TextField') return;

      String? labelText;
      String? validatorSource;

      for (final Expression arg in node.argumentList.arguments) {
        if (arg is! NamedExpression) continue;

        final String paramName = arg.name.label.name;

        // Get label/hint text
        if (paramName == 'decoration') {
          final String decorationSource =
              arg.expression.toSource().toLowerCase();
          for (final String label in _structuredDataLabels) {
            if (decorationSource.contains(label)) {
              labelText = label;
              break;
            }
          }
        }

        // Get validator
        if (paramName == 'validator') {
          validatorSource = arg.expression.toSource();
        }
      }

      // If has structured label but validator doesn't use regex
      if (labelText != null && validatorSource != null) {
        if (!validatorSource.contains('RegExp') &&
            !validatorSource.contains('hasMatch') &&
            !validatorSource.contains('isEmail') &&
            !validatorSource.contains('isPhone') &&
            !validatorSource.contains('isURL') &&
            !validatorSource.contains('validate')) {
          reporter.atNode(node.constructorName, code);
        }
      }
    });
  }
}
