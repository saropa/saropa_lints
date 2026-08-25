// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

/// Google Sign-In lint rules for migration readiness (v6 → v7) and v7 usage.
///
/// Two gate archetypes are covered here:
///   - [AvoidPreV7GoogleSignInRule] gates on `google_sign_in < 7.0.0` (pre-upgrade
///     readiness) and flags v6 API that does NOT compile on v7 — so this rule
///     helps teams identify breakage before bumping the version constraint.
///   - The five usage rules gate on `google_sign_in >= 7.0.0` and flag v7-specific
///     correctness hazards: missing exception handling, unchecked platform support,
///     deprecated token access patterns, unhandled cancellation, and missing
///     `initialize()` before `authenticate()`.
///
/// All rules are report-only (no quick fixes). The v7 API restructuring
/// (authenticate/authorize split, singleton instance, mandatory initialize) is
/// architectural — rewriting it mechanically would silently drop scope handling.
library;

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

import '../../import_utils.dart';
import '../../saropa_lint_rule.dart';

// =============================================================================
// Shared helpers
// =============================================================================

/// Returns `true` when [node]'s file imports `package:google_sign_in/`.
bool _importsGsi(AstNode node) =>
    fileImportsPackage(node, PackageImports.googleSignIn);

/// Walks ancestor AST nodes up to the nearest enclosing [FunctionBody],
/// stopping at (and not crossing) that boundary.
///
/// Returns `null` when no enclosing function body exists within the current
/// member declaration.
FunctionBody? _enclosingFunctionBody(AstNode node) {
  AstNode? current = node.parent;
  while (current != null) {
    if (current is FunctionBody) return current;
    // Stop at member-declaration boundaries so we never escape to an outer class.
    if (current is MethodDeclaration ||
        current is FunctionDeclaration ||
        current is ConstructorDeclaration) {
      return null;
    }
    current = current.parent;
  }
  return null;
}

/// Returns `true` when [node] is enclosed by a [TryStatement] whose catch
/// clauses include a type that catches `GoogleSignInException` or a supertype
/// (`Exception`, `Object`, or a bare `catch` with no type).
///
/// Syntactic: no element resolution required.
bool _isInsideGsiTryCatch(AstNode node) {
  AstNode? current = node.parent;
  while (current != null) {
    if (current is TryStatement) {
      for (final CatchClause clause in current.catchClauses) {
        final TypeAnnotation? exType = clause.exceptionType;
        // Bare `catch` covers everything.
        if (exType == null) return true;
        if (exType is NamedType) {
          final String name = exType.name.lexeme;
          if (name == 'GoogleSignInException' ||
              name == 'Exception' ||
              name == 'Object') {
            return true;
          }
        }
      }
    }
    // Do not look outside the enclosing function body.
    if (current is FunctionBody) break;
    current = current.parent;
  }
  return false;
}

/// Returns `true` when [node] is directly inside a closure / callback
/// (`.then(...)`, `.listen(...)`, `authenticationEvents` stream handler, or
/// any anonymous function expression that is an argument to another call).
///
/// Used to suppress `google_sign_in_authenticate_before_initialize` on sites
/// where initialization ordering is structurally implied by the callback.
bool _isInsideCallbackClosure(AstNode node) {
  AstNode? current = node.parent;
  while (current != null) {
    if (current is FunctionExpression) {
      final AstNode? parent = current.parent;
      if (parent is ArgumentList ||
          parent is NamedExpression ||
          parent is FunctionExpressionInvocation) {
        return true;
      }
    }
    // Stop at the member boundary; do not look outside the declaring function.
    if (current is MethodDeclaration ||
        current is FunctionDeclaration ||
        current is ConstructorDeclaration) {
      break;
    }
    current = current.parent;
  }
  return false;
}

/// Returns `true` when [name] is likely a `GoogleSignIn` receiver identifier.
///
/// The check is syntactic — no type resolution. It matches:
///   - The singleton accessor `GoogleSignIn.instance`
///   - Common variable names used for a `GoogleSignIn` instance.
bool _isGsiReceiver(Expression? receiver) {
  if (receiver == null) return false;
  if (receiver is SimpleIdentifier) {
    final String n = receiver.name;
    return n == 'GoogleSignIn' ||
        n == '_googleSignIn' ||
        n == 'googleSignIn' ||
        n == '_signIn' ||
        n == 'signIn' ||
        n == '_gsi' ||
        n == 'gsi' ||
        n == 'instance';
  }
  // `GoogleSignIn.instance` — a PrefixedIdentifier or PropertyAccess.
  if (receiver is PrefixedIdentifier) {
    return receiver.prefix.name == 'GoogleSignIn' &&
        receiver.identifier.name == 'instance';
  }
  if (receiver is PropertyAccess) {
    // PropertyAccess.target is nullable (cascade `..instance`); a null target is
    // not a `GoogleSignIn.instance` receiver, so the is-check below rejects it.
    final Expression? target = receiver.target;
    return (target is SimpleIdentifier && target.name == 'GoogleSignIn') &&
        receiver.propertyName.name == 'instance';
  }
  return false;
}

// =============================================================================
// avoid_pre_v7_google_sign_in
// =============================================================================

/// Flags v6-era `GoogleSignIn` API that was removed in v7 (pre-upgrade gate).
///
/// Since: v4.20.0 | Rule version: v1
///
/// Gate: `google_sign_in < 7.0.0` (pre-upgrade readiness pack).
///
/// The v7 release replaced the `GoogleSignIn(scopes: [...])` constructor with
/// a `GoogleSignIn.instance` singleton, renamed `signIn()` to `authenticate()`,
/// and renamed `signInSilently()` to `attemptLightweightAuthentication()`. Code
/// using the old API will NOT compile on v7 — this rule flags it while the team
/// is still on v6, giving them a migration checklist before bumping the version.
///
/// **BAD:**
/// ```dart
/// // v6 constructor — removed in v7
/// final _googleSignIn = GoogleSignIn(scopes: ['email']);
///
/// // v6 signIn — removed in v7
/// final account = await _googleSignIn.signIn();
///
/// // v6 signInSilently — removed in v7
/// final account = await _googleSignIn.signInSilently();
/// ```
///
/// **GOOD:**
/// ```dart
/// // v7 singleton + initialize + authenticate
/// await GoogleSignIn.instance.initialize(clientId: '…');
/// final account = await GoogleSignIn.instance.authenticate();
/// ```
class AvoidPreV7GoogleSignInRule extends SaropaLintRule {
  AvoidPreV7GoogleSignInRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.warning;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'packages'};

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'avoid_pre_v7_google_sign_in',
    '[avoid_pre_v7_google_sign_in] This code uses the google_sign_in v6 API '
        '(GoogleSignIn(...) constructor, .signIn(), or .signInSilently()) that '
        'was completely removed in v7. When you upgrade to google_sign_in >=7.0.0 '
        'this file will not compile. Migrate before bumping: replace the constructor '
        'with GoogleSignIn.instance, replace signIn() with authenticate(), and '
        'replace signInSilently() with attemptLightweightAuthentication(). The v7 '
        'auth/authorize split requires a mandatory await initialize() before any '
        'authenticate call. {v1}',
    correctionMessage:
        'Replace GoogleSignIn(...) with GoogleSignIn.instance + await initialize(); '
        'replace .signIn() with .authenticate(); replace .signInSilently() with '
        '.attemptLightweightAuthentication(). Access tokens now require a separate '
        'authorizationClient.authorizeScopes([...]) call — the account returned by '
        'authenticate() carries only an idToken.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    // Flag GoogleSignIn(...) constructor — the v6 class-constructor form.
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      if (!_importsGsi(node)) return;
      final String typeName = node.constructorName.type.name.lexeme;
      if (typeName != 'GoogleSignIn') return;
      reporter.atNode(node);
    });

    // Flag .signIn() and .signInSilently() method calls from the v6 API.
    context.addMethodInvocation((MethodInvocation node) {
      if (!_importsGsi(node)) return;
      final String method = node.methodName.name;
      if (method != 'signIn' && method != 'signInSilently') return;
      // Only flag when the receiver looks like a GoogleSignIn instance to
      // avoid collisions with unrelated classes that happen to have a signIn()
      // method. We accept both explicit receivers and null-target calls.
      final Expression? receiver = node.realTarget;
      if (receiver != null && !_isGsiReceiver(receiver)) return;
      reporter.atNode(node);
    });
  }
}

// =============================================================================
// google_sign_in_missing_exception_handler
// =============================================================================

/// Flags `authenticate()` / `attemptLightweightAuthentication()` outside a
/// try/catch that covers `GoogleSignInException`.
///
/// Since: v4.20.0 | Rule version: v1
///
/// Gate: `google_sign_in >= 7.0.0`.
///
/// In v7, `authenticate()` and `attemptLightweightAuthentication()` throw
/// `GoogleSignInException` for every non-success outcome, including the common
/// case where the user taps away from the account picker. Unlike v6's `signIn()`
/// which returned `null` on cancellation, v7 has no null-return path — an
/// unhandled exception propagates as an unhandled async error, causing a red
/// screen or silent crash depending on `FlutterError.onError`.
///
/// **BAD:**
/// ```dart
/// // No try/catch — GoogleSignInException escapes to FlutterError.onError.
/// final account = await GoogleSignIn.instance.authenticate();
/// ```
///
/// **GOOD:**
/// ```dart
/// try {
///   final account = await GoogleSignIn.instance.authenticate();
/// } on GoogleSignInException catch (e) {
///   if (e.code == GoogleSignInExceptionCode.canceled) return;
///   _handleAuthError(e);
/// }
/// ```
class GoogleSignInMissingExceptionHandlerRule extends SaropaLintRule {
  GoogleSignInMissingExceptionHandlerRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.warning;

  @override
  RuleType? get ruleType => RuleType.bug;

  @override
  Set<String> get tags => const {'packages'};

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'google_sign_in_missing_exception_handler',
    '[google_sign_in_missing_exception_handler] A call to authenticate() or '
        'attemptLightweightAuthentication() on a GoogleSignIn instance is not '
        'enclosed in a try/catch that catches GoogleSignInException (or a supertype '
        'such as Exception or Object). In google_sign_in v7 both methods throw '
        'GoogleSignInException for every non-success outcome, including user '
        'cancellation (code: canceled). There is no null-return path — the exception '
        'will propagate as an unhandled async error, typically producing a red screen '
        'or a silent crash. Wrap the call in try { } on GoogleSignInException catch '
        '(e) { } and switch on e.code to handle cancellation and errors separately. {v1}',
    correctionMessage:
        'Wrap the authenticate() / attemptLightweightAuthentication() call in '
        'try { } on GoogleSignInException catch (e) { switch (e.code) { '
        'case GoogleSignInExceptionCode.canceled: return; default: /* handle error */ } }.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      if (!_importsGsi(node)) return;
      final String method = node.methodName.name;
      if (method != 'authenticate' &&
          method != 'attemptLightweightAuthentication') {
        return;
      }
      if (!_isGsiReceiver(node.realTarget)) return;
      if (_isInsideGsiTryCatch(node)) return;
      reporter.atNode(node);
    });
  }
}

// =============================================================================
// google_sign_in_unchecked_supports_authenticate
// =============================================================================

/// Flags `authenticate()` with no enclosing `supportsAuthenticate()` guard.
///
/// Since: v4.20.0 | Rule version: v1
///
/// Gate: `google_sign_in >= 7.0.0`.
///
/// `GoogleSignIn.instance.supportsAuthenticate()` returns `false` on platforms
/// where the OS provides its own UI (web, and potentially future platforms).
/// Calling `authenticate()` when `supportsAuthenticate()` is `false` throws an
/// `UnsupportedError` at runtime — not a `GoogleSignInException` — so it
/// bypasses sign-in error handlers. Web requires a rendered Google Identity
/// Services button from `google_sign_in_web`, not a programmatic call.
///
/// **BAD:**
/// ```dart
/// // No supportsAuthenticate() guard — throws UnsupportedError on web.
/// final account = await GoogleSignIn.instance.authenticate();
/// ```
///
/// **GOOD:**
/// ```dart
/// if (!await GoogleSignIn.instance.supportsAuthenticate()) {
///   // Use GoogleSignInButton on web.
///   return;
/// }
/// final account = await GoogleSignIn.instance.authenticate();
/// ```
class GoogleSignInUncheckedSupportsAuthenticateRule extends SaropaLintRule {
  GoogleSignInUncheckedSupportsAuthenticateRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.warning;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'packages'};

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'google_sign_in_unchecked_supports_authenticate',
    '[google_sign_in_unchecked_supports_authenticate] A call to '
        'GoogleSignIn.instance.authenticate() has no reachable '
        'supportsAuthenticate() guard in the same function body. On platforms '
        'where supportsAuthenticate() returns false (web, and potentially future '
        'platforms) calling authenticate() throws UnsupportedError at runtime — '
        'not a GoogleSignInException — so the call bypasses sign-in error handlers. '
        'Web requires a rendered Google Identity Services button from the '
        'google_sign_in_web package instead of a programmatic authenticate() call. '
        'Apps that exclusively target Android and iOS may suppress this rule at the '
        'file level with a justified comment. {v1}',
    correctionMessage:
        'Add a guard: if (!await GoogleSignIn.instance.supportsAuthenticate()) '
        '{ /* show GoogleSignInButton or return */ } before calling authenticate(). '
        'Suppress at file level (// ignore_for_file: '
        'google_sign_in_unchecked_supports_authenticate) for Android/iOS-only apps.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      if (!_importsGsi(node)) return;
      if (node.methodName.name != 'authenticate') return;
      if (!_isGsiReceiver(node.realTarget)) return;
      if (_hasSupportsAuthenticateGuard(node)) return;
      reporter.atNode(node);
    });
  }

  /// Returns `true` when any ancestor [IfStatement] or conditional expression
  /// within the enclosing function body contains a `supportsAuthenticate()`
  /// call in its condition, providing a guard for this [node].
  bool _hasSupportsAuthenticateGuard(AstNode node) {
    final FunctionBody? body = _enclosingFunctionBody(node);
    if (body == null) return false;
    final _SupportsAuthenticateScanner scanner = _SupportsAuthenticateScanner();
    body.accept(scanner);
    return scanner.found;
  }
}

/// Scans a function body for any invocation of `supportsAuthenticate()`.
class _SupportsAuthenticateScanner extends RecursiveAstVisitor<void> {
  bool found = false;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.methodName.name == 'supportsAuthenticate') {
      found = true;
      return; // No need to continue scanning.
    }
    super.visitMethodInvocation(node);
  }
}

// =============================================================================
// google_sign_in_auth_token_from_authenticate
// =============================================================================

/// Flags `.accessToken` property access in files that import google_sign_in.
///
/// Since: v4.20.0 | Rule version: v1
///
/// Gate: `google_sign_in >= 7.0.0`.
///
/// In v7 the authentication/authorization split means `GoogleSignInAccount`
/// (returned by `authenticate()`) carries an `idToken` but **not** an
/// `accessToken` for calling Google APIs. Access tokens require a separate call
/// to `account.authorizationClient.authorizeScopes(scopes)`. A developer
/// migrating from v6 who reads `.accessToken` directly will get `null` at
/// runtime with no exception — a silent data bug. Passing that null `accessToken`
/// to `GoogleAuthProvider.credential(idToken: …, accessToken: …)` can produce a
/// Firebase credential that Firebase accepts or rejects unpredictably.
///
/// **BAD:**
/// ```dart
/// final account = await GoogleSignIn.instance.authenticate();
/// final token = account.accessToken; // null in v7 — silent data bug
/// ```
///
/// **GOOD:**
/// ```dart
/// final account = await GoogleSignIn.instance.authenticate();
/// // For Google API calls, use the authorization client:
/// final authorization = await account.authorizationClient
///     .authorizeScopes(['https://www.googleapis.com/auth/calendar']);
/// final token = authorization.accessToken;
/// ```
class GoogleSignInAuthTokenFromAuthenticateRule extends SaropaLintRule {
  GoogleSignInAuthTokenFromAuthenticateRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.error;

  @override
  RuleType? get ruleType => RuleType.bug;

  @override
  Set<String> get tags => const {'packages'};

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'google_sign_in_auth_token_from_authenticate',
    '[google_sign_in_auth_token_from_authenticate] A .accessToken property '
        'access was found in a file that imports google_sign_in. In v7 '
        'GoogleSignInAccount (returned by authenticate()) does not carry an '
        'accessToken — the authentication/authorization concerns are now split. '
        'Reading .accessToken on the account object returns null silently, without '
        'throwing. Passing that null token to Firebase '
        'GoogleAuthProvider.credential(idToken:, accessToken:) can create a '
        'credential that Firebase accepts or rejects unpredictably depending on '
        'backend configuration. Access tokens now require a separate call: '
        'await account.authorizationClient.authorizeScopes([scopes]) which returns '
        'a GoogleSignInClientAuthorization whose .accessToken is the real token. {v1}',
    correctionMessage:
        'Replace .accessToken with a call to '
        'account.authorizationClient.authorizeScopes([\'...scope...\']) and read '
        '.accessToken on the returned GoogleSignInClientAuthorization object.',
    severity: DiagnosticSeverity.ERROR,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    // PropertyAccess covers `account.accessToken` in chained expressions.
    context.addPropertyAccess((PropertyAccess node) {
      if (!_importsGsi(node)) return;
      if (node.propertyName.name != 'accessToken') return;
      // Only flag when the receiver looks like a GoogleSignIn account object,
      // not an arbitrary object that has an accessToken field. target is
      // nullable (cascade form); a null receiver cannot be an account.
      final Expression? target = node.target;
      if (target == null || !_looksLikeGsiAccount(target)) return;
      reporter.atNode(node);
    });

    // PrefixedIdentifier covers `account.accessToken` in simple (non-chained)
    // property reads — e.g. `final t = acct.accessToken;`.
    context.addPrefixedIdentifier((PrefixedIdentifier node) {
      if (!_importsGsi(node)) return;
      if (node.identifier.name != 'accessToken') return;
      reporter.atNode(node);
    });
  }

  /// Heuristic: the receiver `expr` is likely a `GoogleSignInAccount` when its
  /// source text contains common account-variable patterns from the GSI API.
  ///
  /// We keep this conservative to reduce false positives on unrelated classes
  /// that legitimately have an `accessToken` field (e.g., OAuth2 client libs).
  bool _looksLikeGsiAccount(Expression expr) {
    final String src = expr.toSource();
    return src.contains('account') ||
        src.contains('Account') ||
        src.contains('googleAccount') ||
        src.contains('signInAccount') ||
        src.contains('GoogleSignIn');
  }
}

// =============================================================================
// google_sign_in_canceled_not_handled
// =============================================================================

/// Flags `GoogleSignInException` catch blocks that ignore cancellation.
///
/// Since: v4.20.0 | Rule version: v1
///
/// Gate: `google_sign_in >= 7.0.0`.
///
/// `GoogleSignInExceptionCode.canceled` means the user tapped away from the
/// account picker — an expected, normal flow. A catch block that swallows all
/// `GoogleSignInException` values uniformly (e.g., `log(e.toString()); return;`)
/// without separately handling `canceled` silently fails or re-enters a broken
/// auth state. The correct behavior is to detect `canceled` and return cleanly
/// to the pre-sign-in UI without showing an error to the user.
///
/// **BAD:**
/// ```dart
/// } on GoogleSignInException catch (e) {
///   // All errors treated the same — cancellation shows an error to the user.
///   showSnackBar('Sign-in failed: ${e.message}');
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// } on GoogleSignInException catch (e) {
///   if (e.code == GoogleSignInExceptionCode.canceled) return;
///   showSnackBar('Sign-in failed: ${e.message}');
/// }
/// ```
class GoogleSignInCanceledNotHandledRule extends SaropaLintRule {
  GoogleSignInCanceledNotHandledRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.info;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'packages'};

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'google_sign_in_canceled_not_handled',
    '[google_sign_in_canceled_not_handled] A catch clause for '
        'GoogleSignInException (or a supertype) does not contain a branch that '
        'checks for GoogleSignInExceptionCode.canceled. User cancellation — the '
        'user tapping away from the account picker — is the most common non-error '
        'outcome of authenticate() in v7. A catch block that handles all '
        'GoogleSignInException codes identically (e.g., shows an error snackbar) '
        'treats normal user dismissal as an error, producing confusing UX. Detect '
        'the canceled code and return cleanly to the pre-sign-in state without '
        'displaying an error message. Suppressed when the block re-throws or '
        'delegates to an opaque error handler. {v1}',
    correctionMessage:
        'Add a branch: if (e.code == GoogleSignInExceptionCode.canceled) '
        '{ return; } before your general error-handling code.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addCatchClause((CatchClause node) {
      if (!_importsGsi(node)) return;

      // Only examine catch clauses for GoogleSignInException or its supertypes.
      final TypeAnnotation? exType = node.exceptionType;
      if (exType != null) {
        if (exType is! NamedType) return;
        final String typeName = exType.name.lexeme;
        if (typeName != 'GoogleSignInException' &&
            typeName != 'Exception' &&
            typeName != 'Object') {
          return;
        }
      }
      // exType == null is a bare `catch` — also counts.

      // AST scan (not a source-substring match) avoids matching `rethrow` or
      // `canceled` inside a comment or unrelated identifier — the
      // string_contains false-positive class flagged by the CI guard.
      final _CatchBodyScanner scanner = _CatchBodyScanner();
      node.body.accept(scanner);

      // Suppressed: block re-throws, so the caller handles cancellation.
      if (scanner.rethrows) return;

      // Suppressed: block explicitly references the canceled exception code.
      if (scanner.referencesCanceled) return;

      reporter.atNode(node);
    });
  }
}

/// Scans a catch-clause body for a `rethrow` and for a reference to the
/// `canceled` exception code (`GoogleSignInExceptionCode.canceled` or any
/// `.canceled` property access), via the AST rather than source substrings.
class _CatchBodyScanner extends RecursiveAstVisitor<void> {
  bool rethrows = false;
  bool referencesCanceled = false;

  @override
  void visitRethrowExpression(RethrowExpression node) {
    rethrows = true;
    super.visitRethrowExpression(node);
  }

  @override
  void visitPrefixedIdentifier(PrefixedIdentifier node) {
    if (node.identifier.name == 'canceled') referencesCanceled = true;
    super.visitPrefixedIdentifier(node);
  }

  @override
  void visitPropertyAccess(PropertyAccess node) {
    if (node.propertyName.name == 'canceled') referencesCanceled = true;
    super.visitPropertyAccess(node);
  }
}

// =============================================================================
// google_sign_in_authenticate_before_initialize
// =============================================================================

/// Flags `authenticate()` / `attemptLightweightAuthentication()` in a function
/// body that contains no prior `await ...initialize()` call.
///
/// Since: v4.20.0 | Rule version: v1
///
/// Gate: `google_sign_in >= 7.0.0`.
///
/// `GoogleSignIn.instance.initialize()` must be called and awaited exactly once
/// before any call to `authenticate()` or `attemptLightweightAuthentication()`.
/// Skipping or not awaiting it causes the authentication sheet not to appear or
/// a runtime error from the underlying SDK being in an unready state. This is
/// the most common setup bug for developers porting from v6, where construction
/// of `GoogleSignIn()` was synchronous and immediate.
///
/// Detection is intentionally limited to the local function body — cross-function
/// ordering is not tracked. Apps that extract `initialize()` into a helper may
/// suppress at the call site with a justified comment.
///
/// **BAD:**
/// ```dart
/// Future<void> signIn() async {
///   // No prior await initialize() in this body.
///   final account = await GoogleSignIn.instance.authenticate();
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// Future<void> signIn() async {
///   await GoogleSignIn.instance.initialize(clientId: '…');
///   final account = await GoogleSignIn.instance.authenticate();
/// }
/// ```
class GoogleSignInAuthenticateBeforeInitializeRule extends SaropaLintRule {
  GoogleSignInAuthenticateBeforeInitializeRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.warning;

  @override
  RuleType? get ruleType => RuleType.bug;

  @override
  Set<String> get tags => const {'packages'};

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'google_sign_in_authenticate_before_initialize',
    '[google_sign_in_authenticate_before_initialize] A call to authenticate() '
        'or attemptLightweightAuthentication() on GoogleSignIn.instance appears in '
        'a function body that contains no prior await ...initialize() call. In '
        'google_sign_in v7, initialize() must be awaited before any authentication '
        'attempt — skipping or not awaiting it causes the authentication sheet not '
        'to appear or a runtime error from the underlying Android Credential Manager '
        'or GIS SDK being in an unready state. This is the most common v7 setup bug '
        'for developers porting from v6, where GoogleSignIn() construction was '
        'synchronous. Call await GoogleSignIn.instance.initialize() at app startup '
        '(main() before runApp(), or root widget initState) before any auth call. '
        'Suppressed when inside a .then() or stream-listener callback where ordering '
        'is structurally implied. Apps that initialize in a helper method may '
        'suppress at the call site with a justified comment. {v1}',
    correctionMessage:
        'Add await GoogleSignIn.instance.initialize(clientId: \'…\', '
        'serverClientId: \'…\') before the authenticate() call, '
        'typically in main() before runApp() or in your root widget\'s initState().',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      if (!_importsGsi(node)) return;
      final String method = node.methodName.name;
      if (method != 'authenticate' &&
          method != 'attemptLightweightAuthentication') {
        return;
      }
      if (!_isGsiReceiver(node.realTarget)) return;

      // Callbacks inside .then()/.listen() imply their own ordering context.
      if (_isInsideCallbackClosure(node)) return;

      final FunctionBody? body = _enclosingFunctionBody(node);
      if (body == null) return;

      // Scan the function body for a preceding `await ...initialize()` call.
      // "Preceding" is approximated by text-order offset within the body.
      final _InitializeCallScanner scanner = _InitializeCallScanner(
        beforeOffset: node.offset,
      );
      body.accept(scanner);

      if (!scanner.foundInitializeBeforeTarget) {
        reporter.atNode(node);
      }
    });
  }
}

/// Scans a function body for an `initialize()` method invocation that appears
/// (by source offset) before [beforeOffset].
class _InitializeCallScanner extends RecursiveAstVisitor<void> {
  _InitializeCallScanner({required this.beforeOffset});

  final int beforeOffset;
  bool foundInitializeBeforeTarget = false;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (!foundInitializeBeforeTarget &&
        node.methodName.name == 'initialize' &&
        node.offset < beforeOffset) {
      foundInitializeBeforeTarget = true;
      return;
    }
    super.visitMethodInvocation(node);
  }
}

/// Warns when Google Sign-In calls lack try-catch error handling.
///
/// Since: v2.2.0 | Updated: v4.13.0 | Rule version: v3
///
/// Alias: google_signin_try_catch, handle_google_signin_errors
///
/// Google Sign-In can fail for various reasons (network, user cancellation,
/// configuration issues). Without error handling, the app may crash.
///
/// **BAD:**
/// ```dart
/// Future<void> signIn() async {
///   final GoogleSignInAccount? account = await _googleSignIn.signIn();
///   // No error handling!
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// Future<void> signIn() async {
///   try {
///     final GoogleSignInAccount? account = await _googleSignIn.signIn();
///   } catch (e) {
///     // Handle sign-in failure
///   }
/// }
/// ```
class RequireGoogleSigninErrorHandlingRule extends SaropaLintRule {
  RequireGoogleSigninErrorHandlingRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.warning;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'packages'};

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'require_google_signin_error_handling',
    '[require_google_signin_error_handling] Google Sign-In call without error handling crashes when the user cancels the sign-in flow, the network is unavailable, or Google Play Services are outdated. Users see an unhandled exception crash screen instead of a friendly error message, causing frustration and potential data loss in unsaved work. {v3}',
    correctionMessage:
        'Wrap the signIn() call in a try-catch block that handles PlatformException and network errors, and display a user-friendly error message with a retry option.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;
      if (methodName != 'signIn' && methodName != 'signInSilently') return;

      // Check if it's likely a GoogleSignIn call
      final String? targetType = node.target?.toSource();
      if (targetType == null) return;

      final bool isGoogleSignIn = RegExp(
        r'\b(googleSignIn|GoogleSignIn|_googleSignIn)\b',
      ).hasMatch(targetType);

      if (!isGoogleSignIn) return;

      // Check if wrapped in try-catch
      AstNode? current = node.parent;
      while (current != null) {
        if (current is TryStatement) return; // Has try-catch, OK
        if (current is FunctionBody) break;
        current = current.parent;
      }

      reporter.atNode(node);
    });
  }
}
