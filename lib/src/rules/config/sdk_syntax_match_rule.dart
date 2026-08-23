// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

import 'dart:io' show File;

import 'package:analyzer/dart/ast/ast.dart';

import '../../config/pubspec_constraint_parser.dart';
import '../../fixes/config/raise_sdk_lower_bound_fix.dart';
import '../../saropa_lint_rule.dart';

// =============================================================================
// Dart syntax feature → minimum SDK version mapping
// =============================================================================
//
// Each entry maps a language feature to the Dart release that introduced it.
// The rule compares these against the SDK lower bound declared in pubspec.yaml.
// Update this table when new Dart releases add syntax-level features.

/// Minimum SDK version for records, patterns, class modifiers, switch
/// expressions, if-case, and guard clauses (Dart 3.0).
const SemverParts _dart30 = SemverParts(3, 0, 0);

/// Minimum SDK version for extension types (Dart 3.3).
const SemverParts _dart33 = SemverParts(3, 3, 0);

/// Minimum SDK version for digit separators in numeric literals (Dart 3.6).
const SemverParts _dart36 = SemverParts(3, 6, 0);

// 3.4 (wildcard variables) and 3.13 (primary constructors, experimental) are
// not detectable via AST node type alone — the syntax is identical to older
// Dart, only the semantics changed. Skipped until analyzer exposes them.

/// Returns true when [required] is strictly newer than [bound].
bool _requiresHigherSdk(SemverParts required, SemverParts bound) {
  if (required.major != bound.major) return required.major > bound.major;
  if (required.minor != bound.minor) return required.minor > bound.minor;
  return required.patch > bound.patch;
}

// =============================================================================
// require_sdk_syntax_match
// =============================================================================

/// Flags Dart syntax features that require a newer SDK than the lower bound
/// declared in `pubspec.yaml`.
///
/// Since: v15.3.0 | Rule version: v1
///
/// AI code generators ignore SDK constraints and emit syntax for the latest
/// Dart version regardless of the project's declared minimum. The code
/// compiles on the developer's machine (running a newer SDK) but fails for
/// users or CI environments at the declared minimum version.
///
/// **BAD:**
/// ```yaml
/// # pubspec.yaml: sdk: ">=2.19.0 <4.0.0"
/// ```
/// ```dart
/// // Uses records (requires Dart 3.0)
/// (int, String) getPair() => (1, 'a');
/// ```
///
/// **GOOD:**
/// ```yaml
/// # pubspec.yaml: sdk: ">=3.0.0 <4.0.0"
/// ```
/// ```dart
/// (int, String) getPair() => (1, 'a');
/// ```
class RequireSdkSyntaxMatchRule extends SaropaLintRule {
  RequireSdkSyntaxMatchRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.warning;

  @override
  RuleType? get ruleType => RuleType.bug;

  @override
  Set<String> get tags => const {'config', 'pubspec', 'sdk'};

  @override
  RuleCost get cost => RuleCost.low;

  // Offers to raise the SDK lower bound in pubspec.yaml to match the
  // syntax feature that triggered the diagnostic.
  @override
  List<SaropaFixGenerator> get fixGenerators => [
    ({required CorrectionProducerContext context}) =>
        RaiseSdkLowerBoundFix(context: context),
  ];

  // Test files may use a different SDK constraint via test/pubspec.yaml,
  // so this rule only runs on production code.
  @override
  TestRelevance get testRelevance => TestRelevance.never;

  // Cache the parsed SDK lower bound per project root to avoid re-reading
  // pubspec.yaml on every file. The map persists for the analysis session.
  static final Map<String, SemverParts?> _sdkLowerBounds = {};

  static const LintCode _code = LintCode(
    'require_sdk_syntax_match',
    '[require_sdk_syntax_match] This syntax requires a newer Dart SDK than '
        'the lower bound declared in pubspec.yaml. The code compiles on the '
        "developer's SDK but will fail on the declared minimum version. AI "
        'code generators routinely emit syntax for the latest Dart version, '
        'ignoring the project constraint. Either raise the SDK lower bound in '
        'pubspec.yaml or rewrite the code to avoid version-gated syntax. {v1}',
    correctionMessage:
        'Raise the SDK lower bound in pubspec.yaml to match the syntax used, '
        'or rewrite the code to avoid this feature.',
    severity: DiagnosticSeverity.WARNING,
  );

  /// Reads and caches the SDK lower bound for the project containing [filePath].
  SemverParts? _getLowerBound(String filePath) {
    final root = ProjectContext.findProjectRoot(filePath);
    if (root == null) return null;

    // putIfAbsent avoids re-reading on every file in the same project.
    return _sdkLowerBounds.putIfAbsent(root, () {
      final pubspec = File('$root/pubspec.yaml');
      if (!pubspec.existsSync()) return null;
      final parsed = parsePubspecConstraints(pubspec.readAsStringSync());
      return parsed.sdkConstraint?.lower;
    });
  }

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    final bound = _getLowerBound(context.filePath);
    // No parseable lower bound — nothing to compare against.
    if (bound == null) return;

    // --- Dart 3.0 features: records, patterns, class modifiers, switch exprs.
    if (_requiresHigherSdk(_dart30, bound)) {
      // Record type annotations (e.g. `(int, String)` in a type position).
      context.addRecordTypeAnnotation((node) => reporter.atNode(node));

      // Record literals (e.g. `(1, 'a')`).
      context.addRecordLiteral((node) => reporter.atNode(node));

      // Switch expressions (e.g. `switch (x) { ... => ... }`).
      context.addSwitchExpression((node) => reporter.atNode(node));

      // Pattern variable declarations (e.g. `var (a, b) = pair;`).
      context.addPatternVariableDeclaration((node) => reporter.atNode(node));

      // Pattern assignments (e.g. `(a, b) = pair;`).
      context.addPatternAssignment((node) => reporter.atNode(node));

      // Switch pattern cases (e.g. `case MyClass(:final field):`).
      context.addSwitchPatternCase((node) => reporter.atNode(node));

      // Dart 3.0 class modifiers: sealed, base, interface, final.
      // `final class` is a parse error before 3.0, so ClassDeclaration.finalKeyword
      // is null when analyzing pre-3.0 code — no false-positive risk from `final`
      // on variables. The `else if` chain is correct because Dart forbids combining
      // two of sealed/base/interface/final on the same class.
      context.addClassDeclaration((ClassDeclaration node) {
        if (node.sealedKeyword != null) {
          reporter.atToken(node.sealedKeyword!);
        } else if (node.baseKeyword != null) {
          reporter.atToken(node.baseKeyword!);
        } else if (node.interfaceKeyword != null) {
          reporter.atToken(node.interfaceKeyword!);
        } else if (node.finalKeyword != null) {
          reporter.atToken(node.finalKeyword!);
        }
      });
    }

    // --- Dart 3.3: extension types.
    if (_requiresHigherSdk(_dart33, bound)) {
      context.addExtensionTypeDeclaration((node) => reporter.atNode(node));
    }

    // --- Dart 3.6: digit separators in numeric literals (e.g. 1_000_000).
    if (_requiresHigherSdk(_dart36, bound)) {
      // An underscore in the token lexeme means the literal uses separators.
      context.addIntegerLiteral((IntegerLiteral node) {
        if (node.literal.lexeme.contains('_')) reporter.atNode(node);
      });
      context.addDoubleLiteral((DoubleLiteral node) {
        if (node.literal.lexeme.contains('_')) reporter.atNode(node);
      });
    }
  }
}
