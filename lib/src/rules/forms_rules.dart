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

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

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

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

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

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

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

  static const LintCode _code = LintCode(
    name: 'require_error_message_context',
    problemMessage:
        'Validation error message is too generic. Include field name and expected format.',
    correctionMessage:
        'Replace with descriptive message: "Email must be valid" instead of "Invalid".',
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

  static const LintCode _code = LintCode(
    name: 'require_form_key',
    problemMessage: 'Form should have a GlobalKey to access FormState.',
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

  static const LintCode _code = LintCode(
    name: 'avoid_validation_in_build',
    problemMessage:
        'Complex/async validation in validator runs on every keystroke.',
    correctionMessage: 'Move complex validation to onSubmit or use debouncing.',
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

  static const LintCode _code = LintCode(
    name: 'require_submit_button_state',
    problemMessage:
        'Async submit button should show loading state and disable during submission.',
    correctionMessage:
        'Add loading state: onPressed: _isLoading ? null : _submit',
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

  static const LintCode _code = LintCode(
    name: 'avoid_form_without_unfocus',
    problemMessage:
        'Form submission should close keyboard with FocusScope.unfocus().',
    correctionMessage:
        'Add FocusScope.of(context).unfocus() at start of submit handler.',
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

  static const LintCode _code = LintCode(
    name: 'require_form_restoration',
    problemMessage:
        'Form with 5+ fields should use RestorationMixin to survive backgrounding.',
    correctionMessage:
        'Add RestorationMixin or persist draft state to prevent data loss.',
    errorSeverity: DiagnosticSeverity.INFO,
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

  static const LintCode _code = LintCode(
    name: 'avoid_clearing_form_on_error',
    problemMessage:
        'Clearing form fields on validation error loses user input.',
    correctionMessage:
        'Preserve input when validation fails; only highlight errors.',
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

  static const LintCode _code = LintCode(
    name: 'require_form_field_controller',
    problemMessage:
        'TextFormField without controller or onSaved loses value on rebuild.',
    correctionMessage:
        'Add controller: _controller or onSaved: (value) => _field = value',
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

  static const LintCode _code = LintCode(
    name: 'avoid_form_in_alert_dialog',
    problemMessage:
        'Form in AlertDialog may lose state on rebuild. Use separate StatefulWidget.',
    correctionMessage:
        'Extract form to a StatefulWidget class for reliable state management.',
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
