// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

/// Sign in with Apple lint rules.
///
/// These rules catch common integration mistakes with the
/// `sign_in_with_apple` package: missing error handling, unhandled user
/// cancellation, skipped availability checks, unsafe nullable-field usage,
/// and discarded credential-state results.
///
/// Dropped: `apple_sign_in_missing_nonce` — already covered by the existing
/// `require_apple_signin_nonce` rule in `package_specific_rules.dart`.
library;

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

import '../../import_utils.dart';
import '../../saropa_lint_rule.dart';

// =============================================================================
// Shared helpers
// =============================================================================

/// Returns `true` when the file that contains [node] imports the
/// `sign_in_with_apple` package.
bool _importsSiwa(AstNode node) =>
    fileImportsPackage(node, PackageImports.signInWithApple);

/// Returns `true` when [node] is enclosed by a [TryStatement] within the same
/// function body, AND at least one catch clause catches a broad type
/// (`Exception`, `Object`) or the named SIWA exception type.
///
/// Syntactic check: the clause's exception type name must be one of the
/// accepted names — no element resolution needed under the scan CLI.
bool _isInsideTryCatch(AstNode node) {
  AstNode? current = node.parent;
  while (current != null) {
    if (current is TryStatement) {
      for (final clause in current.catchClauses) {
        final TypeAnnotation? exType = clause.exceptionType;

        // Bare `catch` (no type annotation) covers everything.
        if (exType == null) return true;

        // NamedType carries the exception class name.
        if (exType is NamedType) {
          final String typeName = exType.name.lexeme;
          if (typeName == 'SignInWithAppleAuthorizationException' ||
              typeName == 'Exception' ||
              typeName == 'Object') {
            return true;
          }
        }
      }
    }
    // Stop at the function boundary — don't look outside the calling function.
    if (current is FunctionBody) break;
    current = current.parent;
  }
  return false;
}

/// Names of `AuthorizationCredentialAppleID` nullable fields that Apple only
/// populates on the first authorization.
const Set<String> _firstAuthOnlyFields = <String>{
  'givenName',
  'familyName',
  'email',
};

// =============================================================================
// apple_sign_in_unhandled_authorization_exception
// =============================================================================

/// Flags `getAppleIDCredential` calls that are not enclosed in a try/catch.
///
/// Since: v4.17.0 | Rule version: v1
///
/// `SignInWithApple.getAppleIDCredential` throws
/// `SignInWithAppleAuthorizationException` on every authorization failure,
/// including the common case where the user taps Cancel. A call outside a
/// try/catch propagates the exception uncaught, crashing the app on any
/// sign-in failure path. This is the most frequently filed issue in the
/// package's issue tracker (issues #110, #130, #186, #214).
///
/// **BAD:**
/// ```dart
/// final credential = await SignInWithApple.getAppleIDCredential(
///   scopes: [AppleIDAuthorizationScopes.email],
/// );
/// ```
///
/// **GOOD:**
/// ```dart
/// try {
///   final credential = await SignInWithApple.getAppleIDCredential(
///     scopes: [AppleIDAuthorizationScopes.email],
///   );
/// } on SignInWithAppleAuthorizationException catch (e) {
///   // handle failure
/// }
/// ```
class AppleSignInUnhandledAuthorizationExceptionRule extends SaropaLintRule {
  AppleSignInUnhandledAuthorizationExceptionRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.warning;

  @override
  RuleType? get ruleType => RuleType.bug;

  @override
  Set<String> get tags => const {'packages'};

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<String>? get requiredPatterns => const <String>{'getAppleIDCredential'};

  static const LintCode _code = LintCode(
    'apple_sign_in_unhandled_authorization_exception',
    '[apple_sign_in_unhandled_authorization_exception] '
        'SignInWithApple.getAppleIDCredential is called outside a try/catch that '
        'handles SignInWithAppleAuthorizationException. This method throws on every '
        'authorization failure, including the very common user-cancel case '
        '(AuthorizationErrorCode.canceled). An uncaught exception crashes the app '
        'on any sign-in failure path. Wrap the call in a try/catch that at minimum '
        'catches SignInWithAppleAuthorizationException (or Exception / Object). '
        'See package issues #110, #130, #186, #214 for context. {v1}',
    correctionMessage:
        'Wrap the getAppleIDCredential call in a try/catch block that handles '
        'SignInWithAppleAuthorizationException.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name != 'getAppleIDCredential') return;
      if (!_importsSiwa(node)) return;

      // Syntactic target check: caller must be `SignInWithApple`.
      final Expression? target = node.target;
      if (target is! SimpleIdentifier || target.name != 'SignInWithApple') {
        return;
      }

      if (_isInsideTryCatch(node)) return;

      reporter.atNode(node.methodName);
    });
  }
}

// =============================================================================
// apple_sign_in_unhandled_cancel
// =============================================================================

/// Flags a catch for `SignInWithAppleAuthorizationException` that never
/// references `AuthorizationErrorCode.canceled`.
///
/// Since: v4.17.0 | Rule version: v1
///
/// When the user dismisses the Apple sign-in sheet, the OS fires
/// `AuthorizationErrorCode.canceled`. Apps that catch
/// `SignInWithAppleAuthorizationException` generically without branching on
/// `.code == AuthorizationErrorCode.canceled` treat a deliberate user dismiss
/// as an error, typically showing an error dialog or disabling the sign-in
/// button — poor UX that the Apple developer forums repeatedly flag as a
/// common integration mistake (issues #186, #162).
///
/// **BAD:**
/// ```dart
/// try {
///   final credential = await SignInWithApple.getAppleIDCredential(scopes: []);
/// } on SignInWithAppleAuthorizationException catch (e) {
///   showErrorDialog(e.message); // treats cancel as an error
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// } on SignInWithAppleAuthorizationException catch (e) {
///   if (e.code == AuthorizationErrorCode.canceled) return; // silent dismiss
///   showErrorDialog(e.message);
/// }
/// ```
class AppleSignInUnhandledCancelRule extends SaropaLintRule {
  AppleSignInUnhandledCancelRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.warning;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'packages'};

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<String>? get requiredPatterns => const <String>{
    'SignInWithAppleAuthorizationException',
  };

  static const LintCode _code = LintCode(
    'apple_sign_in_unhandled_cancel',
    '[apple_sign_in_unhandled_cancel] '
        'A catch clause for SignInWithAppleAuthorizationException does not '
        'reference AuthorizationErrorCode.canceled. AuthorizationErrorCode.canceled '
        'fires when the user dismisses the Apple sign-in sheet. Without a branch '
        'on this code the catch treats a deliberate user dismiss as an error, '
        'producing misleading error UI on a benign action. Add a check for '
        'e.code == AuthorizationErrorCode.canceled and handle it silently or with '
        'a neutral message. Apple developer forums and issues #186 and #162 '
        'identify this as one of the most common sign-in integration mistakes. '
        '{v1}',
    correctionMessage:
        'Check e.code == AuthorizationErrorCode.canceled inside the catch body '
        'and return or show a neutral message instead of an error.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addTryStatement((TryStatement node) {
      if (!_importsSiwa(node)) return;

      // Only flag try statements that actually call getAppleIDCredential. An AST
      // scan (not a source-substring match) avoids matching the name in a comment
      // or an unrelated identifier — the string_contains false-positive class.
      final _InvocationNameFinder credFinder = _InvocationNameFinder(
        'getAppleIDCredential',
      );
      node.body.accept(credFinder);
      if (!credFinder.found) return;

      for (final clause in node.catchClauses) {
        final TypeAnnotation? exType = clause.exceptionType;

        // Only flag catch clauses that explicitly name the SIWA exception.
        if (exType is! NamedType) continue;
        if (exType.name.lexeme != 'SignInWithAppleAuthorizationException') {
          continue;
        }

        // Does the clause body reference AuthorizationErrorCode.canceled (as a
        // PrefixedIdentifier or PropertyAccess)? AST scan, not substring search.
        final _EnumValueRefFinder canceledFinder = _EnumValueRefFinder(
          enumName: 'AuthorizationErrorCode',
          valueName: 'canceled',
        );
        clause.body.accept(canceledFinder);
        if (!canceledFinder.found) {
          reporter.atNode(clause);
        }
      }
    });
  }
}

/// Finds a `MethodInvocation` by method name anywhere in a subtree.
class _InvocationNameFinder extends RecursiveAstVisitor<void> {
  _InvocationNameFinder(this.name);
  final String name;
  bool found = false;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.methodName.name == name) found = true;
    super.visitMethodInvocation(node);
  }
}

/// Finds a reference to `<enumName>.<valueName>` (PrefixedIdentifier) or any
/// property access ending in `.<valueName>` anywhere in a subtree.
class _EnumValueRefFinder extends RecursiveAstVisitor<void> {
  _EnumValueRefFinder({required this.enumName, required this.valueName});
  final String enumName;
  final String valueName;
  bool found = false;

  @override
  void visitPrefixedIdentifier(PrefixedIdentifier node) {
    if (node.prefix.name == enumName && node.identifier.name == valueName) {
      found = true;
    }
    super.visitPrefixedIdentifier(node);
  }

  @override
  void visitPropertyAccess(PropertyAccess node) {
    if (node.propertyName.name == valueName) found = true;
    super.visitPropertyAccess(node);
  }
}

// =============================================================================
// apple_sign_in_unchecked_availability
// =============================================================================

/// Flags `getAppleIDCredential` in files that never call `isAvailable()`.
///
/// Since: v4.17.0 | Rule version: v1
///
/// `SignInWithApple.isAvailable()` returns `false` on platforms or OS versions
/// that do not support Sign in with Apple (pre-iOS 13, pre-macOS 10.15, and
/// some Android configurations). Calling `getAppleIDCredential` on an
/// unsupported platform throws `SignInWithAppleNotSupportedException`. The
/// package documentation recommends guarding the sign-in button and the
/// credential call behind `isAvailable()`. This rule is INFO because the
/// availability check may live in a parent widget or a separate service file.
///
/// **BAD:**
/// ```dart
/// // No isAvailable() guard anywhere in this file
/// final credential = await SignInWithApple.getAppleIDCredential(scopes: []);
/// ```
///
/// **GOOD:**
/// ```dart
/// if (!await SignInWithApple.isAvailable()) return;
/// final credential = await SignInWithApple.getAppleIDCredential(scopes: []);
/// ```
class AppleSignInUncheckedAvailabilityRule extends SaropaLintRule {
  AppleSignInUncheckedAvailabilityRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.info;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'packages'};

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<String>? get requiredPatterns => const <String>{'getAppleIDCredential'};

  static const LintCode _code = LintCode(
    'apple_sign_in_unchecked_availability',
    '[apple_sign_in_unchecked_availability] '
        'SignInWithApple.getAppleIDCredential is called but no '
        'SignInWithApple.isAvailable() call appears in this file. On platforms or '
        'OS versions that do not support Sign in with Apple (pre-iOS 13, pre-macOS '
        '10.15, some Android configs) this throws SignInWithAppleNotSupportedException. '
        'Guard the credential call (and the sign-in button) behind '
        'isAvailable(). This is INFO because the availability check may exist in '
        'a parent widget or a separate routing layer. {v1}',
    correctionMessage:
        'Call SignInWithApple.isAvailable() before showing the sign-in button '
        'and before calling getAppleIDCredential.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    // Collect every getAppleIDCredential call found during traversal and a
    // flag indicating whether any isAvailable() call was also found.
    // Both callbacks share these mutable variables via closure.
    // Reporting happens inside the callbacks rather than after traversal so
    // that both traversal orderings (isAvailable before / after credential
    // call) are handled correctly: when isAvailable is seen first the flag is
    // already set when the credential candidate is encountered, suppressing it
    // immediately; when the credential call appears first it is marked pending
    // and then cleared when isAvailable is encountered later.
    final List<MethodInvocation> pending = <MethodInvocation>[];
    bool foundIsAvailable = false;

    context.addMethodInvocation((MethodInvocation node) {
      final String name = node.methodName.name;

      if (name == 'isAvailable') {
        if (!_importsSiwa(node)) return;
        final Expression? target = node.target;
        if (target is! SimpleIdentifier || target.name != 'SignInWithApple') {
          return;
        }
        // Mark found and clear any candidates collected before this point.
        foundIsAvailable = true;
        pending.clear();
        return;
      }

      if (name == 'getAppleIDCredential') {
        if (!_importsSiwa(node)) return;
        final Expression? target = node.target;
        if (target is! SimpleIdentifier || target.name != 'SignInWithApple') {
          return;
        }
        // If isAvailable was already encountered earlier in source order,
        // report nothing; otherwise keep this as a candidate.
        if (!foundIsAvailable) {
          pending.add(node);
        }
      }
    });

    // Report any candidates for which no isAvailable() was found anywhere in
    // the file (isAvailable after the last credential call clears pending).
    for (final node in pending) {
      reporter.atNode(node.methodName);
    }
  }
}

// =============================================================================
// apple_sign_in_null_identity_token
// =============================================================================

/// Flags `identityToken` (String?) assigned to a non-nullable `String`
/// variable without null handling.
///
/// Since: v4.17.0 | Rule version: v1
///
/// **OWASP:** [M3:Insecure Authentication] — skipping server validation of the
/// identity token defeats the authentication flow entirely.
///
/// `AuthorizationCredentialAppleID.identityToken` is typed `String?`. The
/// token is the artifact the server must validate; if it is null the server
/// call will silently fail or skip verification. Code that assigns
/// `credential.identityToken` directly into a `String` (non-nullable) variable
/// is a type error in sound Dart and will crash at runtime when Apple does not
/// include the token. This rule does not flag `!`-unwrap (covered by the
/// existing `avoid_null_assertion` rule) — only direct assignment to
/// `String`-typed left-hand sides and passing to `String`-typed named arguments.
///
/// **BAD:**
/// ```dart
/// String token = credential.identityToken; // String? → String, crash risk
/// ```
///
/// **GOOD:**
/// ```dart
/// final token = credential.identityToken;
/// if (token == null) return;
/// ```
class AppleSignInNullIdentityTokenRule extends SaropaLintRule {
  AppleSignInNullIdentityTokenRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.warning;

  @override
  RuleType? get ruleType => RuleType.vulnerability;

  @override
  Set<String> get tags => const {'packages'};

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<String>? get requiredPatterns => const <String>{'identityToken'};

  static const LintCode _code = LintCode(
    'apple_sign_in_null_identity_token',
    '[apple_sign_in_null_identity_token] '
        'credential.identityToken (String?) is assigned to a non-nullable String '
        'variable without null handling. identityToken is the JWT that the server '
        'must validate to verify the sign-in; Apple may return null in edge cases. '
        'Assigning String? to String without a null guard is a sound-Dart type '
        'error and will crash at runtime if the token is absent. Use String? '
        'and add a null check, or short-circuit on null before server validation. '
        'OWASP M3:Insecure Authentication — skipping token validation defeats '
        'the authentication flow entirely. {v1}',
    correctionMessage:
        'Declare the receiving variable as String? and add an explicit null '
        'check before using the token, or use the null-coalescing operator.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    // Detect: String <varName> = <expr>.identityToken;
    // Syntactic approach: look for VariableDeclaration whose initializer ends
    // with .identityToken or identityToken access, where the declared type is
    // the bare name 'String' (non-nullable).
    context.addVariableDeclaration((VariableDeclaration node) {
      if (!_importsSiwa(node)) return;

      final Expression? init = node.initializer;
      if (init == null) return;

      if (!_isIdentityTokenAccess(init)) return;

      // Walk up to the VariableDeclarationList to check the declared type.
      final AstNode? list = node.parent;
      if (list is! VariableDeclarationList) return;

      final TypeAnnotation? type = list.type;
      if (type == null) return; // inferred — may be String? safely

      // Only flag when the type is the bare name 'String' (non-nullable).
      if (_isNonNullableStringType(type)) {
        reporter.atNode(node);
      }
    });

    // Detect: someString = credential.identityToken (assignment expression).
    context.addAssignmentExpression((AssignmentExpression node) {
      if (!_importsSiwa(node)) return;

      if (!_isIdentityTokenAccess(node.rightHandSide)) return;

      // The static type of the left side would require element resolution.
      // Use the syntactic type annotation from the nearest variable declaration.
      final TypeAnnotation? type = _lhsTypeAnnotation(node.leftHandSide);
      if (type == null) return;

      if (_isNonNullableStringType(type)) {
        reporter.atNode(node.rightHandSide);
      }
    });
  }

  /// True when [expr] is a property access or prefixed identifier whose
  /// field name is `identityToken`.
  bool _isIdentityTokenAccess(Expression expr) {
    if (expr is PropertyAccess) {
      return expr.propertyName.name == 'identityToken';
    }
    if (expr is PrefixedIdentifier) {
      return expr.identifier.name == 'identityToken';
    }
    return false;
  }

  /// True when [type] is the bare non-nullable `String` annotation.
  bool _isNonNullableStringType(TypeAnnotation type) {
    if (type is! NamedType) return false;
    if (type.name.lexeme != 'String') return false;
    // A question mark suffix makes it nullable — do not flag.
    return type.question == null;
  }

  /// Attempts to find the explicit type annotation for the left-hand side of
  /// an assignment, by walking up to the enclosing VariableDeclarationList.
  TypeAnnotation? _lhsTypeAnnotation(Expression lhs) {
    if (lhs is! SimpleIdentifier) return null;
    // Walk up to find the matching VariableDeclaration.
    AstNode? current = lhs.parent;
    while (current != null) {
      if (current is VariableDeclaration) {
        final AstNode? list = current.parent;
        if (list is VariableDeclarationList) return list.type;
        return null;
      }
      if (current is FunctionBody) return null;
      current = current.parent;
    }
    return null;
  }
}

// =============================================================================
// apple_sign_in_relying_on_name_email
// =============================================================================

/// Flags `givenName`, `familyName`, or `email` assigned to non-nullable
/// `String` variables without null handling.
///
/// Since: v4.17.0 | Rule version: v1
///
/// Apple only returns `givenName`, `familyName`, and `email` in
/// `AuthorizationCredentialAppleID` on the **first** authorization. On every
/// subsequent sign-in (which is every sign-in after initial setup) these fields
/// are `null`. Code that assigns them to `String` (non-nullable) variables
/// without null guards will crash for all returning users. The data MUST be
/// persisted to the app's own backend on first sign-in and read from there on
/// subsequent sign-ins. See package issue #172 and many duplicates.
///
/// This rule does NOT flag `?.`, `??`, or null-checked accesses — only direct
/// assignment to a non-nullable `String` type. The `!`-unwrap path is already
/// covered by `avoid_null_assertion`.
///
/// **BAD:**
/// ```dart
/// String name = credential.givenName;   // null on every sign-in after first
/// String mail = credential.email;       // same
/// ```
///
/// **GOOD:**
/// ```dart
/// final name = credential.givenName ?? storedName;
/// final mail = credential.email; // kept as String?
/// ```
class AppleSignInRelyingOnNameEmailRule extends SaropaLintRule {
  AppleSignInRelyingOnNameEmailRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.warning;

  @override
  RuleType? get ruleType => RuleType.bug;

  @override
  Set<String> get tags => const {'packages'};

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<String>? get requiredPatterns => const <String>{
    'givenName',
    'familyName',
    'email',
  };

  static const LintCode _code = LintCode(
    'apple_sign_in_relying_on_name_email',
    '[apple_sign_in_relying_on_name_email] '
        'credential.givenName, .familyName, or .email (all String?) is assigned '
        'to a non-nullable String variable without null handling. Apple only returns '
        'these fields on the very first authorization. On all subsequent sign-ins '
        'they are null, causing a crash or silent blank name for every returning '
        'user. Persist these values to your backend on first sign-in and read from '
        'there on subsequent sign-ins. Keep the variable typed String? and add a '
        'null guard, or fall back to a stored value with ??. See issue #172 for '
        'many real-world reports of this bug. {v1}',
    correctionMessage:
        'Declare the receiving variable as String? or use ?? to fall back to a '
        'stored value. Do not rely on Apple returning name or email on repeat '
        'sign-ins.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    // Detect: String <varName> = <expr>.<field>; where <field> is in the set.
    context.addVariableDeclaration((VariableDeclaration node) {
      if (!_importsSiwa(node)) return;

      final Expression? init = node.initializer;
      if (init == null) return;

      if (!_isFirstAuthOnlyAccess(init)) return;

      final AstNode? list = node.parent;
      if (list is! VariableDeclarationList) return;

      final TypeAnnotation? type = list.type;
      if (type == null) return;

      if (_isNonNullableStringType(type)) {
        reporter.atNode(node);
      }
    });

    // Detect: someString = credential.<field> (assignment expression).
    context.addAssignmentExpression((AssignmentExpression node) {
      if (!_importsSiwa(node)) return;

      if (!_isFirstAuthOnlyAccess(node.rightHandSide)) return;

      final TypeAnnotation? type = _lhsTypeAnnotation(node.leftHandSide);
      if (type == null) return;

      if (_isNonNullableStringType(type)) {
        reporter.atNode(node.rightHandSide);
      }
    });
  }

  /// True when [expr] accesses one of the first-auth-only nullable fields.
  bool _isFirstAuthOnlyAccess(Expression expr) {
    String? fieldName;
    if (expr is PropertyAccess) {
      fieldName = expr.propertyName.name;
    } else if (expr is PrefixedIdentifier) {
      fieldName = expr.identifier.name;
    }
    return fieldName != null && _firstAuthOnlyFields.contains(fieldName);
  }

  /// True when [type] is the bare non-nullable `String` annotation.
  bool _isNonNullableStringType(TypeAnnotation type) {
    if (type is! NamedType) return false;
    if (type.name.lexeme != 'String') return false;
    return type.question == null;
  }

  /// Attempts to find the explicit type annotation for the left-hand side of
  /// an assignment, by walking up to the enclosing VariableDeclarationList.
  TypeAnnotation? _lhsTypeAnnotation(Expression lhs) {
    if (lhs is! SimpleIdentifier) return null;
    AstNode? current = lhs.parent;
    while (current != null) {
      if (current is VariableDeclaration) {
        final AstNode? list = current.parent;
        if (list is VariableDeclarationList) return list.type;
        return null;
      }
      if (current is FunctionBody) return null;
      current = current.parent;
    }
    return null;
  }
}

// =============================================================================
// apple_sign_in_unchecked_credential_state
// =============================================================================

/// Flags `await SignInWithApple.getCredentialState(...)` used as a bare
/// statement (result discarded).
///
/// Since: v4.17.0 | Rule version: v1
///
/// `SignInWithApple.getCredentialState(userIdentifier)` returns
/// `CredentialState.revoked` when Apple has revoked authorization (user signed
/// out via Settings → Apple ID → Apps Using Apple ID → Remove). Apps that do
/// not react to `revoked` or `notFound` keep the user session open after the
/// user explicitly revoked access. Discarding the return value means the result
/// is never acted on, defeating the purpose of the call.
///
/// **BAD:**
/// ```dart
/// await SignInWithApple.getCredentialState(userId); // result discarded
/// ```
///
/// **GOOD:**
/// ```dart
/// final state = await SignInWithApple.getCredentialState(userId);
/// if (state == CredentialState.revoked) signOut();
/// ```
class AppleSignInUncheckedCredentialStateRule extends SaropaLintRule {
  AppleSignInUncheckedCredentialStateRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.warning;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'packages'};

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<String>? get requiredPatterns => const <String>{'getCredentialState'};

  static const LintCode _code = LintCode(
    'apple_sign_in_unchecked_credential_state',
    '[apple_sign_in_unchecked_credential_state] '
        'The return value of SignInWithApple.getCredentialState is discarded. '
        'getCredentialState returns CredentialState.revoked when Apple has revoked '
        'authorization (the user removed the app via Settings → Apple ID → Apps). '
        'Discarding the result means revocation is never detected, keeping the user '
        'session open after they explicitly signed out. Assign the result and handle '
        'CredentialState.revoked (sign out) and CredentialState.notFound '
        '(treat as revoked). Apple documentation specifies this check must happen '
        'at every app launch. {v1}',
    correctionMessage:
        'Assign the return value of getCredentialState and branch on '
        'CredentialState.revoked to sign the user out.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addExpressionStatement((ExpressionStatement node) {
      if (!_importsSiwa(node)) return;

      // The expression must be `await <methodInvocation>`.
      final Expression expr = node.expression;
      if (expr is! AwaitExpression) return;

      final Expression operand = expr.expression;
      if (operand is! MethodInvocation) return;
      if (operand.methodName.name != 'getCredentialState') return;

      // Syntactic target check: must be `SignInWithApple.getCredentialState`.
      final Expression? target = operand.target;
      if (target is! SimpleIdentifier || target.name != 'SignInWithApple') {
        return;
      }

      reporter.atNode(operand.methodName);
    });
  }
}
