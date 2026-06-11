// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

/// geocoding package lint rules.
///
/// Catch the documented geocoding footguns: empty-result crashes, missing
/// exception handling, the v3 locale API, the concurrent-locale race, the
/// Android isPresent() gate, and per-keystroke geocoding from a text field.
library;

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

import '../../import_utils.dart';
import '../../saropa_lint_rule.dart';

/// The two geocoding lookup functions (top-level, return Future<List<...>>).
const Set<String> _geocodingLookups = <String>{
  'locationFromAddress',
  'placemarkFromCoordinates',
};

/// True when [node] is a bare top-level geocoding lookup call. The null receiver
/// ensures it is the package function, not `someObject.locationFromAddress`;
/// combined with [fileImportsPackage] this is the type-safe gate.
bool _isGeocodingLookup(MethodInvocation node) =>
    node.target == null && _geocodingLookups.contains(node.methodName.name);

/// True when [node] is a bare top-level call named [name].
bool _isTopLevelCall(MethodInvocation node, String name) =>
    node.target == null && node.methodName.name == name;

FunctionBody? _enclosingMemberBody(AstNode node) {
  AstNode? current = node.parent;
  while (current != null) {
    if (current is MethodDeclaration) return current.body;
    if (current is FunctionDeclaration) {
      return current.functionExpression.body;
    }
    if (current is ConstructorDeclaration) return current.body;
    current = current.parent;
  }
  return null;
}

/// True when [body] contains a bare top-level call named [name].
bool _bodyHasTopLevelCall(AstNode body, String name) {
  final _CallScan scan = _CallScan({name});
  body.accept(scan);
  return scan.matched;
}

class _CallScan extends RecursiveAstVisitor<void> {
  _CallScan(this.names);
  final Set<String> names;
  bool matched = false;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.target == null && names.contains(node.methodName.name)) {
      matched = true;
    }
    super.visitMethodInvocation(node);
  }
}

bool _referencesIdentifier(AstNode root, Set<String> names) {
  final _IdScan scan = _IdScan(names);
  root.accept(scan);
  return scan.found;
}

class _IdScan extends GeneralizingAstVisitor<void> {
  _IdScan(this.names);
  final Set<String> names;
  bool found = false;

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    if (names.contains(node.name)) found = true;
    super.visitSimpleIdentifier(node);
  }
}

/// Nearest enclosing try-statement within the current function body.
TryStatement? _enclosingTry(AstNode node) {
  AstNode? current = node.parent;
  while (current != null) {
    if (current is TryStatement) return current;
    if (current is FunctionBody) return null;
    current = current.parent;
  }
  return null;
}

/// True when a catch clause names [typeName].
bool _catchesType(TryStatement tryStmt, String typeName) {
  return tryStmt.catchClauses.any((CatchClause clause) {
    final TypeAnnotation? type = clause.exceptionType;
    return type is NamedType && type.name.lexeme == typeName;
  });
}

/// True when a catch clause covers everything (bare catch / Object / Exception).
bool _catchesBroadly(TryStatement tryStmt) {
  return tryStmt.catchClauses.any((CatchClause clause) {
    final TypeAnnotation? type = clause.exceptionType;
    if (type == null) return true;
    if (type is NamedType) {
      const Set<String> broad = <String>{'Object', 'Exception', 'dynamic'};
      return broad.contains(type.name.lexeme);
    }
    return false;
  });
}

// =============================================================================
// geocoding_unchecked_first
// =============================================================================

/// Flags `.first`/`.last` on a geocoding result without an emptiness guard.
///
/// Since: v4.16.0 | Rule version: v1
///
/// `locationFromAddress`/`placemarkFromCoordinates` return an empty list when
/// the geocoder finds nothing; `.first` then throws StateError. Use
/// `firstOrNull` (package:collection) or guard with `isNotEmpty`.
///
/// **BAD:**
/// ```dart
/// final loc = (await locationFromAddress(q)).first;
/// ```
///
/// **GOOD:**
/// ```dart
/// final results = await locationFromAddress(q);
/// if (results.isEmpty) return;
/// final loc = results.first;
/// ```
class GeocodingUncheckedFirstRule extends SaropaLintRule {
  GeocodingUncheckedFirstRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.error;

  @override
  RuleType? get ruleType => RuleType.bug;

  @override
  Set<String> get tags => const {'packages'};

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'geocoding_unchecked_first',
    '[geocoding_unchecked_first] .first/.last is taken directly on the awaited result of locationFromAddress / placemarkFromCoordinates. These return an empty List when the platform geocoder finds no match (common on simulators, in unmapped areas, or after rate-limiting), and .first/.last on an empty list throws StateError: No element. This is the most common geocoding crash. {v1}',
    correctionMessage:
        'Store the result, guard with isEmpty/isNotEmpty, or use firstOrNull (package:collection) with a fallback.',
    severity: DiagnosticSeverity.ERROR,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    // Narrow to the direct-await form (the generic avoid_unsafe_collection_methods
    // rule covers stored-then-accessed lists); this adds the geocoding-specific
    // empty-result message and ERROR severity.
    void check(String property, Expression? target) {
      if (property != 'first' && property != 'last') return;
      Expression? receiver = target;
      if (receiver is ParenthesizedExpression) receiver = receiver.expression;
      if (receiver is! AwaitExpression) return;
      final Expression inner = receiver.expression;
      if (inner is! MethodInvocation || !_isGeocodingLookup(inner)) return;
      if (!fileImportsPackage(inner, PackageImports.geocoding)) return;
      reporter.atNode(inner.methodName);
    }

    context.addPropertyAccess((PropertyAccess node) {
      check(node.propertyName.name, node.realTarget);
    });
  }
}

// =============================================================================
// geocoding_missing_exception_handler
// =============================================================================

/// Flags a geocoding call not wrapped in a try/catch.
///
/// Since: v4.16.0 | Rule version: v1
///
/// The platform geocoder throws `PlatformException` (network / not-found) and
/// `NoResultFoundException`; an unwrapped call propagates uncaught.
///
/// **BAD:**
/// ```dart
/// final r = await locationFromAddress(q);
/// ```
///
/// **GOOD:**
/// ```dart
/// try {
///   final r = await locationFromAddress(q);
/// } on PlatformException { ... } on NoResultFoundException { ... }
/// ```
class GeocodingMissingExceptionHandlerRule extends SaropaLintRule {
  GeocodingMissingExceptionHandlerRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.warning;

  @override
  RuleType? get ruleType => RuleType.bug;

  @override
  Set<String> get tags => const {'packages'};

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<String>? get requiredPatterns =>
      const <String>{'locationFromAddress', 'placemarkFromCoordinates'};

  static const LintCode _code = LintCode(
    'geocoding_missing_exception_handler',
    '[geocoding_missing_exception_handler] A geocoding lookup (locationFromAddress / placemarkFromCoordinates) is not wrapped in a try/catch that handles its failures. The platform geocoder throws PlatformException for network (IO_ERROR) and not-found errors, and NoResultFoundException when there is no match; an unhandled call propagates uncaught and crashes or silently drops the operation. {v1}',
    correctionMessage:
        'Wrap the call in try { ... } on PlatformException { ... } on NoResultFoundException { ... }.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      if (!_isGeocodingLookup(node)) return;
      if (!fileImportsPackage(node, PackageImports.geocoding)) return;

      final TryStatement? tryStmt = _enclosingTry(node);
      if (tryStmt == null) {
        reporter.atNode(node.methodName);
        return;
      }
      final bool handled =
          _catchesBroadly(tryStmt) ||
          _catchesType(tryStmt, 'PlatformException') ||
          _catchesType(tryStmt, 'NoResultFoundException');
      if (!handled) reporter.atNode(node.methodName);
    });
  }
}

// =============================================================================
// geocoding_prefer_no_result_found_catch
// =============================================================================

/// Flags a `PlatformException` catch around geocoding with no
/// `NoResultFoundException` clause.
///
/// Since: v4.16.0 | Rule version: v1
///
/// geocoding 2.x added `NoResultFoundException` for the no-results path; code
/// catching only `PlatformException` misses it. INFO.
///
/// **BAD:**
/// ```dart
/// try { await locationFromAddress(q); } on PlatformException { ... }
/// ```
///
/// **GOOD:**
/// ```dart
/// try { await locationFromAddress(q); }
/// on NoResultFoundException { ... } on PlatformException { ... }
/// ```
class GeocodingPreferNoResultFoundCatchRule extends SaropaLintRule {
  GeocodingPreferNoResultFoundCatchRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.info;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'packages'};

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<String>? get requiredPatterns => const <String>{'PlatformException'};

  static const LintCode _code = LintCode(
    'geocoding_prefer_no_result_found_catch',
    '[geocoding_prefer_no_result_found_catch] A try/catch around a geocoding lookup catches PlatformException but not NoResultFoundException. Since geocoding 2.x the no-results case surfaces as NoResultFoundException, not PlatformException, so the no-match path falls through uncaught. Add a NoResultFoundException clause to handle empty results distinctly. {v1}',
    correctionMessage:
        'Add an `on NoResultFoundException` catch clause to handle the no-results case separately from PlatformException.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addTryStatement((TryStatement node) {
      if (!fileImportsPackage(node, PackageImports.geocoding)) return;
      if (!_bodyHasGeocodingLookup(node.body)) return;

      if (!_catchesType(node, 'PlatformException')) return;
      if (_catchesType(node, 'NoResultFoundException')) return;

      // Report at the PlatformException clause (a Token can't be a report node).
      for (final CatchClause clause in node.catchClauses) {
        final TypeAnnotation? type = clause.exceptionType;
        if (type is NamedType && type.name.lexeme == 'PlatformException') {
          reporter.atNode(clause);
          return;
        }
      }
    });
  }

  bool _bodyHasGeocodingLookup(AstNode body) {
    final _CallScan scan = _CallScan(_geocodingLookups);
    body.accept(scan);
    return scan.matched;
  }
}

// =============================================================================
// geocoding_locale_set_before_call
// =============================================================================

/// Flags a geocoding call with no `setLocaleIdentifier` in the same member.
///
/// Since: v4.16.0 | Rule version: v1
///
/// geocoding 3.0 removed the per-call `localeIdentifier`; locale is set once via
/// `setLocaleIdentifier`. INFO — single-locale apps legitimately never call it.
///
/// **BAD:**
/// ```dart
/// final r = await locationFromAddress(q); // no setLocaleIdentifier
/// ```
///
/// **GOOD:**
/// ```dart
/// await setLocaleIdentifier('fr');
/// final r = await locationFromAddress(q);
/// ```
class GeocodingLocaleSetBeforeCallRule extends SaropaLintRule {
  GeocodingLocaleSetBeforeCallRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.info;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'packages'};

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<String>? get requiredPatterns =>
      const <String>{'locationFromAddress', 'placemarkFromCoordinates'};

  static const LintCode _code = LintCode(
    'geocoding_locale_set_before_call',
    '[geocoding_locale_set_before_call] A geocoding lookup runs with no setLocaleIdentifier call in the same member. Since geocoding 3.0 the per-call localeIdentifier parameter was removed; without setLocaleIdentifier the geocoder returns results in the device system locale, which may not match the app language — a silent localization regression. Reported at INFO because single-locale apps legitimately never set it. {v1}',
    correctionMessage:
        'Call setLocaleIdentifier(<app locale>) before the geocoding lookup if your app localizes geocoder results.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      if (!_isGeocodingLookup(node)) return;
      if (!fileImportsPackage(node, PackageImports.geocoding)) return;

      final FunctionBody? body = _enclosingMemberBody(node);
      if (body == null) return;
      if (_bodyHasTopLevelCall(body, 'setLocaleIdentifier')) return;

      reporter.atNode(node.methodName);
    });
  }
}

// =============================================================================
// geocoding_concurrent_locale_race
// =============================================================================

/// Flags `setLocaleIdentifier` inside a loop.
///
/// Since: v4.16.0 | Rule version: v1
///
/// `setLocaleIdentifier` mutates global geocoder state; setting it per-iteration
/// while lookups run can let one locale bleed into another (Baseflow #198).
///
/// **BAD:**
/// ```dart
/// for (final c in coords) {
///   await setLocaleIdentifier(c.locale);
///   await placemarkFromCoordinates(c.lat, c.lng);
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// await setLocaleIdentifier(locale);
/// for (final c in coords) { await placemarkFromCoordinates(c.lat, c.lng); }
/// ```
class GeocodingConcurrentLocaleRaceRule extends SaropaLintRule {
  GeocodingConcurrentLocaleRaceRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.warning;

  @override
  RuleType? get ruleType => RuleType.bug;

  @override
  Set<String> get tags => const {'packages'};

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<String>? get requiredPatterns => const <String>{'setLocaleIdentifier'};

  static const LintCode _code = LintCode(
    'geocoding_concurrent_locale_race',
    '[geocoding_concurrent_locale_race] setLocaleIdentifier is called inside a loop. setLocaleIdentifier mutates global geocoder state on both iOS and Android; setting it per-iteration while geocoding lookups run risks one iteration\'s locale bleeding into another\'s results (a documented race). If the locale does not change, hoist the call above the loop; if it does, serialize the lookups. {v1}',
    correctionMessage:
        'Hoist setLocaleIdentifier above the loop when the locale is constant, or serialize the geocoding calls when it varies.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      if (!_isTopLevelCall(node, 'setLocaleIdentifier')) return;
      if (!fileImportsPackage(node, PackageImports.geocoding)) return;
      if (!_insideLoop(node)) return;

      reporter.atNode(node.methodName);
    });
  }

  bool _insideLoop(AstNode node) {
    AstNode? current = node.parent;
    while (current != null) {
      if (current is ForStatement ||
          current is WhileStatement ||
          current is DoStatement) {
        return true;
      }
      if (current is FunctionBody) return false;
      current = current.parent;
    }
    return false;
  }
}

// =============================================================================
// geocoding_missing_is_present_check
// =============================================================================

/// Flags a geocoding call with no `isPresent()` in the same member.
///
/// Since: v4.16.0 | Rule version: v1
///
/// `isPresent()` is false on Android devices without the geocoder backend
/// (de-Googled / older); calling geocoding there always throws. INFO.
///
/// **BAD:**
/// ```dart
/// final r = await locationFromAddress(q); // no isPresent() gate
/// ```
///
/// **GOOD:**
/// ```dart
/// if (await isPresent()) { final r = await locationFromAddress(q); }
/// ```
class GeocodingMissingIsPresentCheckRule extends SaropaLintRule {
  GeocodingMissingIsPresentCheckRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.info;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'packages'};

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<String>? get requiredPatterns =>
      const <String>{'locationFromAddress', 'placemarkFromCoordinates'};

  static const LintCode _code = LintCode(
    'geocoding_missing_is_present_check',
    '[geocoding_missing_is_present_check] A geocoding lookup runs with no isPresent() check in the same member. isPresent() returns false on Android devices that lack the geocoder backend (de-Googled or older devices), where every geocoding call throws. Gating on isPresent() lets the app degrade gracefully instead of crashing. Reported at INFO — the check may live in an outer scope. {v1}',
    correctionMessage:
        'Gate the geocoding call on isPresent() and provide a fallback when the geocoder is unavailable.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      if (!_isGeocodingLookup(node)) return;
      if (!fileImportsPackage(node, PackageImports.geocoding)) return;

      final FunctionBody? body = _enclosingMemberBody(node);
      if (body == null) return;
      if (_bodyHasTopLevelCall(body, 'isPresent')) return;

      reporter.atNode(node.methodName);
    });
  }
}

// =============================================================================
// geocoding_call_in_text_field_listener
// =============================================================================

/// Flags a geocoding call inside a text-field callback with no debounce.
///
/// Since: v4.16.0 | Rule version: v1
///
/// Geocoding on every keystroke hits the platform rate limit. The enclosing
/// closure must debounce (a Timer / debounce util). Heuristic — an upstream
/// RxDart debounce is not visible here.
///
/// **BAD:**
/// ```dart
/// onChanged: (q) async { await locationFromAddress(q); }
/// ```
///
/// **GOOD:**
/// ```dart
/// onChanged: (q) { _debounce?.cancel(); _debounce = Timer(d, () => geocode(q)); }
/// ```
class GeocodingCallInTextFieldListenerRule extends SaropaLintRule {
  GeocodingCallInTextFieldListenerRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.warning;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'packages'};

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<String>? get requiredPatterns =>
      const <String>{'locationFromAddress', 'placemarkFromCoordinates'};

  static const LintCode _code = LintCode(
    'geocoding_call_in_text_field_listener',
    '[geocoding_call_in_text_field_listener] A geocoding lookup runs directly inside a text-field onChanged / addListener callback with no visible debounce. The platform geocoder is rate-limited; firing a lookup on every keystroke returns IO_ERROR after a few calls or degrades silently. Debounce with a Timer (300-500ms). Heuristic: an upstream RxDart debounceTime is not visible at this site. {v1}',
    correctionMessage:
        'Debounce the input (e.g. a 300-500ms Timer) and geocode only after the user stops typing.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      if (!_isGeocodingLookup(node)) return;
      if (!fileImportsPackage(node, PackageImports.geocoding)) return;

      final FunctionExpression? closure =
          node.thisOrAncestorOfType<FunctionExpression>();
      if (closure == null) return;
      if (!_isTextFieldCallback(closure)) return;

      // A debounce primitive in the closure suppresses the report.
      if (_referencesIdentifier(closure, const <String>{
        'Timer',
        'debounce',
        'Debounce',
        'debounceTime',
      })) {
        return;
      }

      reporter.atNode(node.methodName);
    });
  }

  bool _isTextFieldCallback(FunctionExpression closure) {
    final AstNode? parent = closure.parent;
    // onChanged: (q) { ... }
    if (parent is NamedExpression &&
        (parent.name.label.name == 'onChanged' ||
            parent.name.label.name == 'onFieldSubmitted')) {
      return true;
    }
    // controller.addListener(() { ... })
    if (parent is ArgumentList) {
      final AstNode? call = parent.parent;
      if (call is MethodInvocation && call.methodName.name == 'addListener') {
        return true;
      }
    }
    return false;
  }
}

// =============================================================================
// geocoding_deprecated_locale_param
// =============================================================================

/// Flags the removed `localeIdentifier:` argument on a geocoding call.
///
/// Since: v4.16.0 | Rule version: v1
///
/// geocoding 3.0 removed the per-call `localeIdentifier`; use
/// `setLocaleIdentifier(...)` before the call. (On 3.x+ this is also a compile
/// error; the rule helps 2.x→3.x migration.)
///
/// **BAD:**
/// ```dart
/// await locationFromAddress(q, localeIdentifier: 'fr');
/// ```
///
/// **GOOD:**
/// ```dart
/// await setLocaleIdentifier('fr');
/// await locationFromAddress(q);
/// ```
class GeocodingDeprecatedLocaleParamRule extends SaropaLintRule {
  GeocodingDeprecatedLocaleParamRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.error;

  @override
  RuleType? get ruleType => RuleType.bug;

  @override
  Set<String> get tags => const {'packages'};

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<String>? get requiredPatterns => const <String>{'localeIdentifier'};

  static const LintCode _code = LintCode(
    'geocoding_deprecated_locale_param',
    '[geocoding_deprecated_locale_param] A geocoding lookup passes the localeIdentifier: named argument, which was removed in geocoding 3.0. The locale is now set once via setLocaleIdentifier() before the call. On geocoding 3.x+ this no longer compiles; the rule flags it during a 2.x to 3.x upgrade so the locale handling is migrated rather than silently dropped. {v1}',
    correctionMessage:
        'Remove localeIdentifier: and call setLocaleIdentifier(<value>) before the geocoding lookup.',
    severity: DiagnosticSeverity.ERROR,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      if (!_isGeocodingLookup(node)) return;
      if (!fileImportsPackage(node, PackageImports.geocoding)) return;

      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression &&
            arg.name.label.name == 'localeIdentifier') {
          reporter.atNode(arg);
          return;
        }
      }
    });
  }
}
