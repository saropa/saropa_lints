// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

import 'dart:io' show File;

import 'package:analyzer/dart/ast/ast.dart';

import '../../config/pubspec_constraint_parser.dart';
import '../../saropa_lint_rule.dart';

// =============================================================================
// Pubspec version-constraint hygiene rules
// =============================================================================
//
// These five rules review the version ranges in pubspec.yaml — the SDK bound
// and each dependency's lower/upper bounds. `custom_lint` analyzes .dart files,
// not .yaml, so (like the other pubspec rules in config_rules.dart) they read
// pubspec.yaml from disk and attach the diagnostic to the top of a lib/ Dart
// file, reporting at most once per project root.
//
// Audience matters: applications (`publish_to: none`) want tight constraints to
// keep the team on current versions; published packages want wide constraints
// for consumer compatibility. The `*_in_app` / `*_app_*` rules fire only for
// applications so they never push a published package toward over-tight bounds.

/// Reads and parses the project pubspec once per root, then reports via
/// [hasViolation]. Reporting is gated to lib/ files and deduplicated per root
/// because the diagnostic can only land on a Dart file, not on pubspec.yaml.
void _reportPubspecOnce(
  SaropaDiagnosticReporter reporter,
  SaropaContext context,
  Set<String> reportedRoots,
  bool Function(ParsedPubspec) hasViolation,
) {
  final root = ProjectContext.findProjectRoot(context.filePath);
  if (root == null) return;
  if (reportedRoots.contains(root)) return;

  // Only attach to source files; avoids reporting from test/ or example/ trees.
  final path = context.filePath.replaceAll('\\', '/');
  if (!path.contains('/lib/')) return;

  final pubspec = File('$root/pubspec.yaml');
  if (!pubspec.existsSync()) return;

  final parsed = parsePubspecConstraints(pubspec.readAsStringSync());
  if (!hasViolation(parsed)) return;

  reportedRoots.add(root);
  context.addCompilationUnit((CompilationUnit unit) {
    final token = unit.beginToken;
    if (token.isEof) return;
    reporter.atOffset(offset: token.offset, length: token.length);
  });
}

// =============================================================================
// require_sdk_upper_bound
// =============================================================================

/// Warns when the Dart SDK constraint has a lower bound but no upper bound.
///
/// Since: v14.1.0 | Rule version: v1
///
/// An open-ended SDK constraint lets `pub get` resolve against an untested
/// future major SDK, which can silently change language semantics.
///
/// **BAD:**
/// ```yaml
/// environment:
///   sdk: ">=3.0.0"
/// ```
///
/// **GOOD:**
/// ```yaml
/// environment:
///   sdk: ">=3.0.0 <4.0.0"
/// ```
class RequireSdkUpperBoundRule extends SaropaLintRule {
  RequireSdkUpperBoundRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.warning;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'config', 'pubspec'};

  @override
  RuleCost get cost => RuleCost.low;

  static final Set<String> _reportedRoots = {};

  static const LintCode _code = LintCode(
    'require_sdk_upper_bound',
    '[require_sdk_upper_bound] The Dart SDK constraint in pubspec.yaml has a '
        'lower bound but no upper bound, so pub get will resolve against '
        'unreleased future major SDKs that have never been tested against this '
        'code. A breaking SDK major can change language semantics or remove '
        'APIs you depend on without any warning at resolve time. Pin an upper '
        'bound such as <4.0.0 so moving to a new SDK major is a deliberate, '
        'reviewed change. {v1}',
    correctionMessage:
        'Add an upper bound to the SDK constraint, e.g. ">=3.0.0 <4.0.0".',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    _reportPubspecOnce(reporter, context, _reportedRoots, (parsed) {
      final sdk = parsed.sdkConstraint;
      if (sdk == null) return false;
      return sdk.hasLower && !sdk.hasUpper;
    });
  }
}

// =============================================================================
// avoid_unbounded_dependency
// =============================================================================

/// Warns when a dependency is declared with `any` or no version constraint.
///
/// Since: v14.1.0 | Rule version: v1
///
/// An unbounded dependency resolves to any published version, including
/// breaking majors released after this code was written.
///
/// **BAD:**
/// ```yaml
/// dependencies:
///   http: any
/// ```
///
/// **GOOD:**
/// ```yaml
/// dependencies:
///   http: ^1.2.0
/// ```
class AvoidUnboundedDependencyRule extends SaropaLintRule {
  AvoidUnboundedDependencyRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.warning;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'config', 'pubspec'};

  @override
  RuleCost get cost => RuleCost.low;

  static final Set<String> _reportedRoots = {};

  static const LintCode _code = LintCode(
    'avoid_unbounded_dependency',
    '[avoid_unbounded_dependency] A dependency is declared with "any" or no '
        'version constraint, so the solver may resolve it to any published '
        'version including breaking majors released after this code was '
        'written. An unbounded dependency makes builds non-reproducible and '
        'can pull in an incompatible API without warning. Specify a caret or '
        'bounded range (for example ^1.2.3) that matches the version you have '
        'actually tested against. {v1}',
    correctionMessage:
        'Replace "any" with a bounded constraint, e.g. ^1.2.3 or '
        '">=1.2.3 <2.0.0".',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    _reportPubspecOnce(reporter, context, _reportedRoots, (parsed) {
      return parsed.dependencies.any((dep) => dep.constraint.isAny);
    });
  }
}

// =============================================================================
// require_dependency_lower_bound
// =============================================================================

/// Warns when a dependency constraint has an upper bound but no lower bound.
///
/// Since: v14.1.0 | Rule version: v1
///
/// An upper-only constraint lets the solver pick an arbitrarily old version
/// that predates APIs this code relies on.
///
/// **BAD:**
/// ```yaml
/// dependencies:
///   http: "<2.0.0"
/// ```
///
/// **GOOD:**
/// ```yaml
/// dependencies:
///   http: ">=1.2.0 <2.0.0"
/// ```
class RequireDependencyLowerBoundRule extends SaropaLintRule {
  RequireDependencyLowerBoundRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.info;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'config', 'pubspec'};

  @override
  RuleCost get cost => RuleCost.low;

  static final Set<String> _reportedRoots = {};

  static const LintCode _code = LintCode(
    'require_dependency_lower_bound',
    '[require_dependency_lower_bound] A dependency constraint specifies only an '
        'upper bound and no lower bound, so the solver may resolve an '
        'arbitrarily old version that predates APIs this code relies on. A '
        'clean-machine build can silently pick an ancient release and then '
        'fail in confusing ways far from the real cause. Add a lower bound '
        '(for example ">=1.2.0 <2.0.0") so the minimum supported version is '
        'explicit. {v1}',
    correctionMessage:
        'Add a lower bound to the constraint, e.g. ">=1.2.0 <2.0.0".',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    _reportPubspecOnce(reporter, context, _reportedRoots, (parsed) {
      return parsed.dependencies.any(
        (dep) => dep.constraint.hasUpper && !dep.constraint.hasLower,
      );
    });
  }
}

// =============================================================================
// prefer_caret_constraint_in_app
// =============================================================================

/// Warns when an application dependency uses a range equivalent to a caret.
///
/// Since: v14.1.0 | Rule version: v1
///
/// Applies only to applications (`publish_to: none`). A range like
/// `>=1.2.3 <2.0.0` means exactly `^1.2.3` but is longer and noisier.
///
/// **BAD (app):**
/// ```yaml
/// dependencies:
///   http: ">=1.2.3 <2.0.0"
/// ```
///
/// **GOOD (app):**
/// ```yaml
/// dependencies:
///   http: ^1.2.3
/// ```
class PreferCaretConstraintInAppRule extends SaropaLintRule {
  PreferCaretConstraintInAppRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.info;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'config', 'pubspec'};

  @override
  RuleCost get cost => RuleCost.low;

  static final Set<String> _reportedRoots = {};

  static const LintCode _code = LintCode(
    'prefer_caret_constraint_in_app',
    '[prefer_caret_constraint_in_app] An application dependency uses an '
        'explicit range that is exactly equivalent to a caret constraint, for '
        'example ">=1.2.3 <2.0.0". In an application a caret (^1.2.3) is '
        'shorter, conveys the same allowed range, and is the form dart pub add '
        'writes, so the verbose range adds noise without adding precision. '
        'Published packages are exempt because they sometimes need the '
        'explicit form; this rule targets apps only. {v1}',
    correctionMessage:
        'Replace the caret-equivalent range with the caret form, e.g. ^1.2.3.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    _reportPubspecOnce(reporter, context, _reportedRoots, (parsed) {
      if (!parsed.isApp) return false;
      return parsed.dependencies.any(
        (dep) => dep.constraint.isCaretEquivalentRange,
      );
    });
  }
}

// =============================================================================
// avoid_overly_wide_app_constraint
// =============================================================================

/// Warns when an application dependency spans two or more major versions.
///
/// Since: v14.1.0 | Rule version: v1
///
/// Applies only to applications (`publish_to: none`). A range like
/// `>=1.0.0 <4.0.0` lets each machine resolve a different major, so the team
/// drifts apart and bugs become irreproducible.
///
/// **BAD (app):**
/// ```yaml
/// dependencies:
///   http: ">=1.0.0 <4.0.0"
/// ```
///
/// **GOOD (app):**
/// ```yaml
/// dependencies:
///   http: ^3.0.0
/// ```
class AvoidOverlyWideAppConstraintRule extends SaropaLintRule {
  AvoidOverlyWideAppConstraintRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.info;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'config', 'pubspec'};

  @override
  RuleCost get cost => RuleCost.low;

  static final Set<String> _reportedRoots = {};

  static const LintCode _code = LintCode(
    'avoid_overly_wide_app_constraint',
    '[avoid_overly_wide_app_constraint] An application dependency allows a '
        'version range spanning two or more major versions, for example '
        '">=1.0.0 <4.0.0". A wide range lets each developer machine resolve to '
        'a different, possibly stale major, so the team drifts apart and bugs '
        'become irreproducible. Applications should tighten the lower bound to '
        'the major they ship and test against; the widest-range advice applies '
        'to published packages, not apps. {v1}',
    correctionMessage:
        'Tighten the range to the major you ship, e.g. ^3.0.0 instead of '
        '">=1.0.0 <4.0.0".',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    _reportPubspecOnce(reporter, context, _reportedRoots, (parsed) {
      if (!parsed.isApp) return false;
      return parsed.dependencies.any((dep) {
        final span = dep.constraint.majorSpan;
        return span != null && span >= 2;
      });
    });
  }
}
