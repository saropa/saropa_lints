// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

/// local_auth package lint rules (always-on, 3.x correct usage).
///
/// Enforce the biometric-auth contract: check the result, guard exceptions,
/// confirm device capability, handle lockout, and require biometric-only in
/// sensitive flows. The 3.0 migration rules (AuthenticationOptions removal,
/// stickyAuth rename, PlatformException→LocalAuthException) live with the
/// version-gated migration-pack workstream, not here.
library;

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

import '../../import_utils.dart';
import '../../native/saropa_fix.dart';
import '../../saropa_lint_rule.dart';

/// The local_auth facade type whose `authenticate` the call rules key on.
const String _localAuthType = 'LocalAuthentication';

/// Naming tokens that mark a security-sensitive context for the biometric-only
/// heuristic (matched against the enclosing method/class element NAME, not
/// source text). Inherently fragile — the rule is pedantic-tier + INFO.
const Set<String> _sensitiveTokens = <String>{
  'secure',
  'payment',
  'sensitive',
  'confirm',
  'verify',
  'biometric',
};

/// Catch-clause exception types that DO cover a LocalAuthException.
const Set<String> _coveringCatchTypes = <String>{
  'LocalAuthException',
  'Object',
  'Exception',
  'dynamic',
};

/// True when [node] is `<LocalAuthentication>.authenticate(...)` (resolved
/// receiver type). Combined with [fileImportsPackage] this avoids matching an
/// unrelated `authenticate()` (e.g. an auth service) in the same file.
bool _isAuthenticateCall(MethodInvocation node) {
  if (node.methodName.name != 'authenticate') return false;
  return node.realTarget?.staticType?.element?.name == _localAuthType;
}

/// True when any descendant of [root] is a LocalAuthentication.authenticate call.
bool _containsAuthenticate(AstNode root) {
  final _AuthScan scan = _AuthScan();
  root.accept(scan);
  return scan.authCalls.isNotEmpty;
}

class _AuthScan extends RecursiveAstVisitor<void> {
  final List<MethodInvocation> authCalls = <MethodInvocation>[];

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (_isAuthenticateCall(node)) authCalls.add(node);
    super.visitMethodInvocation(node);
  }
}

bool _referencesIdentifier(AstNode root, Set<String> names) {
  final _IdentifierScan scan = _IdentifierScan(names);
  root.accept(scan);
  return scan.found;
}

class _IdentifierScan extends GeneralizingAstVisitor<void> {
  _IdentifierScan(this.names);
  final Set<String> names;
  bool found = false;

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    if (names.contains(node.name)) found = true;
    super.visitSimpleIdentifier(node);
  }
}

Expression? _namedArgValue(MethodInvocation node, String name) {
  for (final Expression arg in node.argumentList.arguments) {
    if (arg is NamedExpression && arg.name.label.name == name) {
      return arg.expression;
    }
  }
  return null;
}

// =============================================================================
// local_auth_unchecked_result
// =============================================================================

/// Flags a discarded `await auth.authenticate(...)`.
///
/// Since: v4.16.0 | Rule version: v1
///
/// `authenticate()` returns `false` when the user cancels; discarding the result
/// as a bare statement lets the code proceed as if authentication succeeded.
///
/// **BAD:**
/// ```dart
/// await auth.authenticate(localizedReason: 'Unlock');
/// openVault();
/// ```
///
/// **GOOD:**
/// ```dart
/// if (await auth.authenticate(localizedReason: 'Unlock')) openVault();
/// ```
class LocalAuthUncheckedResultRule extends SaropaLintRule {
  LocalAuthUncheckedResultRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.warning;

  @override
  RuleType? get ruleType => RuleType.bug;

  @override
  Set<String> get tags => const {'packages'};

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<String>? get requiredPatterns => const <String>{'authenticate'};

  @override
  OwaspMapping get owasp => const OwaspMapping(
    mobile: <OwaspMobile>{OwaspMobile.m3},
  );

  static const LintCode _code = LintCode(
    'local_auth_unchecked_result',
    '[local_auth_unchecked_result] The boolean result of LocalAuthentication.authenticate() is discarded (the await is a bare statement). authenticate() returns false when the user cancels and true only on success; ignoring it lets the code proceed as if authentication passed, defeating the biometric gate. Assign the result and branch on it. {v1}',
    correctionMessage:
        'Branch on the result: if (await auth.authenticate(localizedReason: ...)) { /* proceed */ }.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      if (!_isAuthenticateCall(node)) return;
      if (!fileImportsPackage(node, PackageImports.localAuth)) return;

      final AstNode? awaitNode = node.parent;
      if (awaitNode is! AwaitExpression) return;
      if (awaitNode.parent is! ExpressionStatement) return;

      reporter.atNode(node.methodName);
    });
  }
}

// =============================================================================
// local_auth_missing_capability_check
// =============================================================================

/// Flags `authenticate()` with no `canCheckBiometrics`/`isDeviceSupported()`
/// in the file.
///
/// Since: v4.16.0 | Rule version: v1
///
/// Authenticating on a device with no enrolled credential throws
/// `noCredentialsSet`; the docs recommend gating on `isDeviceSupported()`. INFO:
/// the check may live in a shared service (false positive).
///
/// **BAD:**
/// ```dart
/// await auth.authenticate(localizedReason: 'Unlock'); // no capability check
/// ```
///
/// **GOOD:**
/// ```dart
/// if (await auth.isDeviceSupported()) {
///   await auth.authenticate(localizedReason: 'Unlock');
/// }
/// ```
class LocalAuthMissingCapabilityCheckRule extends SaropaLintRule {
  LocalAuthMissingCapabilityCheckRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.info;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'packages'};

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<String>? get requiredPatterns => const <String>{'authenticate'};

  @override
  OwaspMapping get owasp => const OwaspMapping(
    mobile: <OwaspMobile>{OwaspMobile.m3},
  );

  static const LintCode _code = LintCode(
    'local_auth_missing_capability_check',
    '[local_auth_missing_capability_check] This file calls LocalAuthentication.authenticate() but never reads canCheckBiometrics or calls isDeviceSupported(). On a device with no enrolled biometric and no device credential, authenticate() throws noCredentialsSet; the official guidance is to gate the call on a capability check. Reported at INFO because the check may legitimately live in a shared service. {v1}',
    correctionMessage:
        'Guard authenticate() with canCheckBiometrics or isDeviceSupported() before presenting the auth UI.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addCompilationUnit((CompilationUnit unit) {
      if (!fileImportsPackage(unit, PackageImports.localAuth)) return;

      final _AuthScan scan = _AuthScan();
      unit.accept(scan);
      if (scan.authCalls.isEmpty) return;

      if (_referencesIdentifier(unit, const <String>{
        'canCheckBiometrics',
        'isDeviceSupported',
      })) {
        return;
      }

      reporter.atNode(scan.authCalls.first.methodName);
    });
  }
}

// =============================================================================
// local_auth_unhandled_exception
// =============================================================================

/// Flags `authenticate()` not wrapped in a try/catch covering
/// `LocalAuthException`.
///
/// Since: v4.16.0 | Rule version: v1
///
/// `authenticate()` throws `LocalAuthException` for 14 failure codes; an
/// unwrapped call propagates uncaught and crashes the app.
///
/// **BAD:**
/// ```dart
/// final ok = await auth.authenticate(localizedReason: 'Unlock');
/// ```
///
/// **GOOD:**
/// ```dart
/// try {
///   final ok = await auth.authenticate(localizedReason: 'Unlock');
/// } on LocalAuthException catch (e) { handle(e); }
/// ```
class LocalAuthUnhandledExceptionRule extends SaropaLintRule {
  LocalAuthUnhandledExceptionRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.warning;

  @override
  RuleType? get ruleType => RuleType.bug;

  @override
  Set<String> get tags => const {'packages'};

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<String>? get requiredPatterns => const <String>{'authenticate'};

  @override
  OwaspMapping get owasp => const OwaspMapping(
    mobile: <OwaspMobile>{OwaspMobile.m3},
  );

  static const LintCode _code = LintCode(
    'local_auth_unhandled_exception',
    '[local_auth_unhandled_exception] LocalAuthentication.authenticate() is not wrapped in a try/catch that covers LocalAuthException. authenticate() throws LocalAuthException for 14 distinct failure codes (lockout, no hardware, system-canceled, ...) — only a plain user cancel returns false. An unguarded call propagates the exception and crashes the app. {v1}',
    correctionMessage:
        'Wrap the call in try { ... } on LocalAuthException catch (e) { ... } and surface the failure to the user.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      if (!_isAuthenticateCall(node)) return;
      if (!fileImportsPackage(node, PackageImports.localAuth)) return;

      // Find the nearest enclosing try whose body contains this call.
      final TryStatement? tryStmt = _enclosingTry(node);
      if (tryStmt == null) {
        reporter.atNode(node.methodName);
        return;
      }

      final bool covered = tryStmt.catchClauses.any((CatchClause clause) {
        final TypeAnnotation? type = clause.exceptionType;
        if (type == null) return true; // bare catch (e) covers everything
        if (type is NamedType) {
          return _coveringCatchTypes.contains(type.name.lexeme);
        }
        return false;
      });
      if (!covered) reporter.atNode(node.methodName);
    });
  }

  TryStatement? _enclosingTry(AstNode node) {
    AstNode? current = node.parent;
    while (current != null) {
      if (current is TryStatement) return current;
      // Stop at the function boundary — a try in an outer function does not
      // protect this call site within the framework's static view.
      if (current is FunctionBody) return null;
      current = current.parent;
    }
    return null;
  }
}

// =============================================================================
// local_auth_missing_lockout_handling
// =============================================================================

/// Flags a `LocalAuthException` catch that ignores the lockout codes.
///
/// Since: v4.16.0 | Rule version: v1
///
/// `temporaryLockout`/`biometricLockout` need distinct UI (wait / use another
/// credential); a generic catch that ignores them strands the user. INFO.
///
/// **BAD:**
/// ```dart
/// } on LocalAuthException catch (e) { showError('Auth failed'); }
/// ```
///
/// **GOOD:**
/// ```dart
/// } on LocalAuthException catch (e) {
///   if (e.code == LocalAuthExceptionCode.biometricLockout) showLockout();
/// }
/// ```
class LocalAuthMissingLockoutHandlingRule extends SaropaLintRule {
  LocalAuthMissingLockoutHandlingRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.info;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'packages'};

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<String>? get requiredPatterns => const <String>{'authenticate'};

  static const LintCode _code = LintCode(
    'local_auth_missing_lockout_handling',
    '[local_auth_missing_lockout_handling] A LocalAuthException catch around an authenticate() call never branches on temporaryLockout or biometricLockout. These lockout codes need distinct handling — the user must wait or switch to a device credential — and a generic "auth failed" path strands them on the auth screen with no recovery. Reported at INFO: handling all failures identically is coarser UX, not a crash. {v1}',
    correctionMessage:
        'Branch on e.code == LocalAuthExceptionCode.temporaryLockout / .biometricLockout to guide the user to recovery.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addTryStatement((TryStatement node) {
      if (!fileImportsPackage(node, PackageImports.localAuth)) return;
      if (!_containsAuthenticate(node.body)) return;

      for (final CatchClause clause in node.catchClauses) {
        final TypeAnnotation? type = clause.exceptionType;
        if (type is! NamedType) continue;
        if (type.name.lexeme != 'LocalAuthException') continue;

        if (!_referencesIdentifier(clause.body, const <String>{
          'temporaryLockout',
          'biometricLockout',
        })) {
          reporter.atNode(clause);
        }
      }
    });
  }
}

// =============================================================================
// local_auth_biometric_only_sensitive
// =============================================================================

/// Flags `authenticate()` without `biometricOnly: true` in a sensitive context.
///
/// Since: v4.16.0 | Rule version: v1 | Pedantic (naming heuristic)
///
/// In high-security flows, allowing PIN/pattern fallback (the default) defeats
/// the biometric requirement. The "sensitive" signal is the enclosing method /
/// class NAME — a deliberately fragile heuristic, hence pedantic + INFO.
///
/// **BAD:**
/// ```dart
/// Future<void> confirmPayment() async {
///   await auth.authenticate(localizedReason: 'Confirm'); // no biometricOnly
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// await auth.authenticate(localizedReason: 'Confirm', biometricOnly: true);
/// ```
class LocalAuthBiometricOnlySensitiveRule extends SaropaLintRule {
  LocalAuthBiometricOnlySensitiveRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.info;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'packages'};

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<String>? get requiredPatterns => const <String>{'authenticate'};

  static const LintCode _code = LintCode(
    'local_auth_biometric_only_sensitive',
    '[local_auth_biometric_only_sensitive] authenticate() is called without biometricOnly: true inside a method or class whose name signals a security-sensitive flow (secure/payment/sensitive/confirm/verify/biometric). The default allows PIN/pattern fallback, which defeats a biometric requirement for high-value actions. This is a naming-heuristic nudge (pedantic, INFO) — suppress with a verified // ignore: if fallback is intended. {v1}',
    correctionMessage:
        'Pass biometricOnly: true to require a biometric (no device-credential fallback) for this sensitive action.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  List<SaropaFixGenerator> get fixGenerators => [
    ({required CorrectionProducerContext context}) =>
        _AddBiometricOnlyFix(context: context),
  ];

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      if (!_isAuthenticateCall(node)) return;
      if (!fileImportsPackage(node, PackageImports.localAuth)) return;

      // Already biometric-only — nothing to flag.
      final Expression? bioOnly = _namedArgValue(node, 'biometricOnly');
      if (bioOnly is BooleanLiteral && bioOnly.value == true) return;
      if (bioOnly != null) return; // explicitly set to something — respect it

      if (!_inSensitiveContext(node)) return;
      reporter.atNode(node.methodName);
    });
  }

  bool _inSensitiveContext(AstNode node) {
    AstNode? current = node.parent;
    while (current != null) {
      if (current is MethodDeclaration &&
          _nameSignalsSensitive(current.name.lexeme)) {
        return true;
      }
      if (current is FunctionDeclaration &&
          _nameSignalsSensitive(current.name.lexeme)) {
        return true;
      }
      if (current is ClassDeclaration) {
        final String? className = current.declaredFragment?.element.name;
        return className != null && _nameSignalsSensitive(className);
      }
      current = current.parent;
    }
    return false;
  }

  bool _nameSignalsSensitive(String name) {
    final String lower = name.toLowerCase();
    return _sensitiveTokens.any((String token) => lower.contains(token));
  }
}

/// Quick fix: append `biometricOnly: true` to the authenticate call.
class _AddBiometricOnlyFix extends SaropaFixProducer {
  _AddBiometricOnlyFix({required super.context});

  @override
  FixKind get fixKind =>
      FixKind('saropa.fix.addBiometricOnly', 80, 'Add biometricOnly: true');

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final AstNode? node = coveringNode;
    final MethodInvocation? invocation = node
        ?.thisOrAncestorOfType<MethodInvocation>();
    if (invocation == null) return;
    final args = invocation.argumentList.arguments;
    if (args.isEmpty) return;
    // Already present — do nothing.
    final bool hasBioOnly = args.any(
      (Expression a) =>
          a is NamedExpression && a.name.label.name == 'biometricOnly',
    );
    if (hasBioOnly) return;
    final int offset = args.last.end;
    await builder.addDartFileEdit(file, (b) {
      b.addSimpleInsertion(offset, ', biometricOnly: true');
    });
  }
}
