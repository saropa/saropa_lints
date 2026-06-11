// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

/// local_auth package lint rules.
///
/// Always-on (3.x correct usage): enforce the biometric-auth contract — check
/// the result, guard exceptions, confirm device capability, handle lockout, and
/// require biometric-only in sensitive flows.
///
/// Version-gated (pre-upgrade, local_auth < 3.0): detect removed/renamed
/// symbols so codebases on 2.x know exactly what to migrate before upgrading.
/// The 4 migration rules at the bottom of this file belong to pack
/// `local_auth_3` (gate `local_auth < 3.0.0`) — see
/// `plans/plan_local_auth_migration_pack.md`.
library;

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

import '../../fixes/common/replace_node_fix.dart';
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
  OwaspMapping get owasp =>
      const OwaspMapping(mobile: <OwaspMobile>{OwaspMobile.m3});

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
  OwaspMapping get owasp =>
      const OwaspMapping(mobile: <OwaspMobile>{OwaspMobile.m3});

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
  OwaspMapping get owasp =>
      const OwaspMapping(mobile: <OwaspMobile>{OwaspMobile.m3});

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

// =============================================================================
// local_auth_deprecated_options_class  (migration — local_auth_3 pack, < 3.0.0)
// =============================================================================

/// Flags construction of `AuthenticationOptions`, which was removed in 3.0.
///
/// Since: v4.17.0 | Rule version: v1 | Pack: local_auth_3 (gate: < 3.0.0)
///
/// `AuthenticationOptions` was the parameter object passed to `authenticate()`
/// in local_auth 2.x. In 3.0 the class was removed entirely; its fields
/// (`biometricOnly`, `sensitiveTransaction`, `stickyAuth`/
/// `persistAcrossBackgrounding`) were promoted to direct named parameters on
/// `authenticate()`, while `useErrorDialogs` was dropped with no replacement.
/// Any 2.x code that constructs `AuthenticationOptions(…)` will fail to compile
/// after the upgrade. This rule fires pre-upgrade so the migration work surfaces
/// at lint time rather than at upgrade time.
///
/// **BAD:**
/// ```dart
/// final options = AuthenticationOptions(biometricOnly: true);
/// await auth.authenticate(localizedReason: 'Pay', options: options);
/// ```
///
/// **GOOD:**
/// ```dart
/// await auth.authenticate(
///   localizedReason: 'Pay',
///   biometricOnly: true,
/// );
/// ```
class LocalAuthDeprecatedOptionsClassRule extends SaropaLintRule {
  LocalAuthDeprecatedOptionsClassRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.warning;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'packages'};

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'local_auth_deprecated_options_class',
    '[local_auth_deprecated_options_class] AuthenticationOptions is constructed here, but the class was removed in local_auth 3.0. Its fields (biometricOnly, sensitiveTransaction, stickyAuth) were promoted to direct named parameters on authenticate(); useErrorDialogs was removed entirely. Continuing to use AuthenticationOptions will cause a compile error after upgrading. Inline each field as a named argument on authenticate() instead, and build your own error UI to replace useErrorDialogs. {v1}',
    correctionMessage:
        'Remove AuthenticationOptions(...) and pass its fields (biometricOnly:, sensitiveTransaction:, persistAcrossBackgrounding:) directly to authenticate(). Handle useErrorDialogs cases with your own error UI.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      if (!fileImportsPackage(node, PackageImports.localAuth)) return;

      // Match on the constructor name; AuthenticationOptions resolves from
      // package:local_auth_platform_interface, but is re-exported through the
      // local_auth facade, so the import check on PackageImports.localAuth is
      // the right gate.
      if (node.constructorName.type.name.lexeme != 'AuthenticationOptions') {
        return;
      }

      reporter.atNode(node.constructorName);
    });
  }
}

// =============================================================================
// local_auth_use_error_dialogs_removed  (migration — local_auth_3 pack, < 3.0.0)
// =============================================================================

/// Flags `AuthenticationOptions(useErrorDialogs: …)` — the field was removed in
/// 3.0, requiring the caller to build its own error UI.
///
/// Since: v4.17.0 | Rule version: v1 | Pack: local_auth_3 (gate: < 3.0.0)
///
/// In local_auth 2.x, `useErrorDialogs: false` suppressed the platform's
/// built-in error dialog, offloading error handling to the app. In 3.0 the
/// field is gone along with the whole `AuthenticationOptions` class — the
/// platform no longer shows built-in dialogs at all, so every 3.x caller must
/// implement its own error UI. The fix is non-trivial (a UI architecture
/// decision), so this rule is report-only. ERROR severity because this is a
/// guaranteed compile break on 3.x — it cannot be silently ignored.
///
/// **BAD:**
/// ```dart
/// AuthenticationOptions(useErrorDialogs: false, biometricOnly: true)
/// ```
///
/// **GOOD (3.x):**
/// ```dart
/// // Build your own error UI in the LocalAuthException catch handler.
/// await auth.authenticate(localizedReason: 'Unlock', biometricOnly: true);
/// ```
class LocalAuthUseErrorDialogsRemovedRule extends SaropaLintRule {
  LocalAuthUseErrorDialogsRemovedRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.error;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'packages'};

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'local_auth_use_error_dialogs_removed',
    '[local_auth_use_error_dialogs_removed] The useErrorDialogs field of AuthenticationOptions was removed in local_auth 3.0. The platform no longer shows built-in error dialogs; every caller must build its own error UI inside the LocalAuthException catch handler. Keeping this field will cause a compile error after upgrading. No mechanical replacement exists — plan a UI implementation to surface authentication failure messages to the user before migrating. {v1}',
    correctionMessage:
        'Remove useErrorDialogs from AuthenticationOptions and implement your own error UI in the on LocalAuthException catch block.',
    severity: DiagnosticSeverity.ERROR,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      if (!fileImportsPackage(node, PackageImports.localAuth)) return;
      if (node.constructorName.type.name.lexeme != 'AuthenticationOptions') {
        return;
      }

      // Locate the useErrorDialogs named argument and flag only it, giving the
      // developer a precise call-out on the removed field rather than the whole
      // constructor site (which local_auth_deprecated_options_class already covers).
      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression &&
            arg.name.label.name == 'useErrorDialogs') {
          reporter.atNode(arg.name);
          return;
        }
      }
    });
  }
}

// =============================================================================
// local_auth_sticky_auth_renamed  (migration — local_auth_3 pack, < 3.0.0)
// =============================================================================

/// Flags `stickyAuth:` named arguments — renamed to `persistAcrossBackgrounding`
/// in local_auth 3.0 — and offers a mechanical rename fix.
///
/// Since: v4.17.0 | Rule version: v1 | Pack: local_auth_3 (gate: < 3.0.0)
///
/// `AuthenticationOptions.stickyAuth` kept the auth dialog alive when the app
/// moved to background and returned. In 3.0 the parameter was renamed to
/// `persistAcrossBackgrounding` and promoted to a direct named parameter on
/// `authenticate()` (the `AuthenticationOptions` wrapper is gone). The rename is
/// a one-for-one semantic substitution; the fix is safe to apply mechanically.
///
/// **BAD:**
/// ```dart
/// AuthenticationOptions(stickyAuth: true, biometricOnly: true)
/// ```
///
/// **GOOD:**
/// ```dart
/// await auth.authenticate(
///   localizedReason: 'Unlock',
///   persistAcrossBackgrounding: true,
///   biometricOnly: true,
/// );
/// ```
class LocalAuthStickyAuthRenamedRule extends SaropaLintRule {
  LocalAuthStickyAuthRenamedRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.warning;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'packages'};

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'local_auth_sticky_auth_renamed',
    '[local_auth_sticky_auth_renamed] The stickyAuth parameter of AuthenticationOptions was renamed to persistAcrossBackgrounding in local_auth 3.0. The parameter is also promoted to a direct named argument on authenticate() — AuthenticationOptions itself was removed. Using stickyAuth: will cause a compile error after upgrading. The rename is a one-for-one semantic substitution with no behavior change; apply the quick fix to rename it now. {v1}',
    correctionMessage:
        'Rename stickyAuth: to persistAcrossBackgrounding: and promote it as a direct named argument on authenticate().',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  List<SaropaFixGenerator> get fixGenerators => [
    ({required CorrectionProducerContext context}) =>
        _RenameStickyAuthFix(context: context),
  ];

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      if (!fileImportsPackage(node, PackageImports.localAuth)) return;
      if (node.constructorName.type.name.lexeme != 'AuthenticationOptions') {
        return;
      }

      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression && arg.name.label.name == 'stickyAuth') {
          // Report on the label only so the squiggle is precise.
          reporter.atNode(arg.name);
          return;
        }
      }
    });
  }
}

/// Quick fix: rename the `stickyAuth:` label to `persistAcrossBackgrounding:`.
///
/// The fix targets the label token only — the value expression is unchanged,
/// which is safe because the parameter semantics are identical.
class _RenameStickyAuthFix extends ReplaceNodeFix {
  _RenameStickyAuthFix({required super.context});

  @override
  FixKind get fixKind => FixKind(
    'saropa.fix.renameStickyAuth',
    80,
    'Rename stickyAuth: to persistAcrossBackgrounding:',
  );

  @override
  AstNode? findTargetNode(AstNode node) {
    // The diagnostic is reported on the Label node (e.g. `stickyAuth:`).
    // Walk up to the NamedExpression so the replacement covers the full label
    // including the colon, then return only the Label portion for replacement.
    if (node is Label) return node;
    // coveringNode may be the SimpleIdentifier inside the label — step up.
    final AstNode? parent = node.parent;
    if (parent is Label) return parent;
    return node;
  }

  @override
  String computeReplacement(AstNode node) => 'persistAcrossBackgrounding:';
}

// =============================================================================
// local_auth_platform_exception_catch  (migration — local_auth_3 pack, < 3.0.0)
// =============================================================================

/// Flags `on PlatformException` catch clauses around `authenticate()` calls —
/// now dead code because 3.0 throws `LocalAuthException`, not `PlatformException`.
///
/// Since: v4.17.0 | Rule version: v1 | Pack: local_auth_3 (gate: < 3.0.0)
///
/// local_auth 2.x threw `PlatformException` on authentication failure; many apps
/// have catch clauses like `on PlatformException catch (e)` wrapping their
/// `authenticate()` call. In 3.0, `authenticate()` throws `LocalAuthException`
/// instead; the `PlatformException` branch is now unreachable — failures bypass
/// it silently and the app never surfaces them. The fix replaces the caught type
/// with `LocalAuthException` (a one-for-one substitution).
///
/// Only fires when the same try body contains an `authenticate()` call on a
/// `LocalAuthentication` receiver, to avoid flagging `PlatformException` catches
/// that guard unrelated plugin calls in the same block.
///
/// **BAD:**
/// ```dart
/// try {
///   final ok = await auth.authenticate(localizedReason: 'Unlock');
/// } on PlatformException catch (e) { handle(e); } // dead in 3.0
/// ```
///
/// **GOOD:**
/// ```dart
/// try {
///   final ok = await auth.authenticate(localizedReason: 'Unlock');
/// } on LocalAuthException catch (e) { handle(e); }
/// ```
class LocalAuthPlatformExceptionCatchRule extends SaropaLintRule {
  LocalAuthPlatformExceptionCatchRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.warning;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'packages'};

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'local_auth_platform_exception_catch',
    '[local_auth_platform_exception_catch] A catch clause catches PlatformException around a LocalAuthentication.authenticate() call, but local_auth 3.0 throws LocalAuthException instead of PlatformException. This catch branch is unreachable on 3.x — authentication failures bypass it silently, leaving the app with no error handling. Replace the caught type with LocalAuthException. Only fires when the try body contains an authenticate() call so legitimate PlatformException catches for other plugin calls are not flagged. {v1}',
    correctionMessage:
        'Replace on PlatformException with on LocalAuthException. Ensure package:local_auth/local_auth.dart is imported so LocalAuthException resolves.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  List<SaropaFixGenerator> get fixGenerators => [
    ({required CorrectionProducerContext context}) =>
        _ReplacePlatformExceptionFix(context: context),
  ];

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addTryStatement((TryStatement node) {
      if (!fileImportsPackage(node, PackageImports.localAuth)) return;

      // Only flag when the try body actually contains an authenticate() call so
      // PlatformException catches for other plugin calls in the same block are
      // not touched.
      if (!_containsAuthenticate(node.body)) return;

      for (final CatchClause clause in node.catchClauses) {
        final TypeAnnotation? type = clause.exceptionType;
        if (type is! NamedType) continue;
        if (type.name.lexeme != 'PlatformException') continue;

        // Report on the type annotation so the squiggle lands precisely on the
        // caught type name — the fix replaces only that token.
        reporter.atNode(type);
      }
    });
  }
}

/// Quick fix: replace `PlatformException` with `LocalAuthException` in the
/// caught type annotation.
class _ReplacePlatformExceptionFix extends ReplaceNodeFix {
  _ReplacePlatformExceptionFix({required super.context});

  @override
  FixKind get fixKind => FixKind(
    'saropa.fix.replacePlatformExceptionWithLocalAuthException',
    80,
    'Replace PlatformException with LocalAuthException',
  );

  @override
  String computeReplacement(AstNode node) => 'LocalAuthException';
}
