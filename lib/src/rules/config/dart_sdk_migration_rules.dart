// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

import 'dart:io' show File;

import 'package:analyzer/dart/ast/ast.dart';
import 'package:meta/meta.dart' show visibleForTesting;

import '../../config/pubspec_constraint_parser.dart';
import '../../saropa_lint_rule.dart';

// =============================================================================
// Dart SDK 3.13+ migration rules
// =============================================================================
//
// Rules that flag code patterns eligible for modernization when the project's
// Dart SDK lower bound is high enough to support the newer syntax.

// -----------------------------------------------------------------------------
// SDK constraint cache — shared across all rules in this file.
// Key: project root path. Value: (pubspec.yaml mtime, parsed lower bound).
// Keyed by mtime (mirroring lib/src/config/pubspec_lock_resolver.dart) so a
// live SDK-constraint bump in pubspec.yaml — e.g. a user raising the lower
// bound specifically to start using primary constructors — is picked up on
// the next analysis pass instead of requiring a full plugin/IDE restart.
// -----------------------------------------------------------------------------

final Map<String, (int mtime, SemverParts? lower)> _sdkLowerCache = {};

/// Clears the cached SDK lower bound (e.g. after tests mutate pubspec.yaml).
void clearDartSdkMigrationCacheForTests() {
  _sdkLowerCache.clear();
}

/// Returns the Dart SDK lower bound for the project containing [filePath].
/// Returns null when no pubspec.yaml is found or the constraint is unparseable.
SemverParts? _dartSdkLower(String filePath) {
  final root = ProjectContext.findProjectRoot(filePath);
  if (root == null) return null;

  final pubspec = File('$root/pubspec.yaml');
  if (!pubspec.existsSync()) return null;
  final mtime = pubspec.lastModifiedSync().millisecondsSinceEpoch;

  final cached = _sdkLowerCache[root];
  if (cached != null && cached.$1 == mtime) return cached.$2;

  final parsed = parsePubspecConstraints(pubspec.readAsStringSync());
  final lower = parsed.sdkConstraint?.lower;
  _sdkLowerCache[root] = (mtime, lower);
  return lower;
}

/// True when the parsed lower bound is >= [major].[minor].[patch].
///
/// `@visibleForTesting` so boundary cases (e.g. 3.12.9 vs 3.13.0) can be
/// pinned directly without round-tripping through a pubspec.yaml on disk.
@visibleForTesting
bool sdkIsAtLeast(SemverParts? lower, int major, int minor, [int patch = 0]) {
  if (lower == null) return false;
  if (lower.major != major) return lower.major > major;
  if (lower.minor != minor) return lower.minor > minor;
  return lower.patch >= patch;
}

// =============================================================================
// prefer_primary_constructor
// =============================================================================

/// Flags classes that could use Dart 3.13+ primary constructor syntax.
///
/// Since: v15.3.0 | Rule version: v1
///
/// AI code generators consistently produce verbose traditional constructor +
/// field declaration boilerplate even when the target SDK supports primary
/// constructors. This rule identifies simple classes eligible for the compact
/// `class Foo(final Type field);` form, reducing visual noise and making the
/// class shape immediately apparent.
///
/// The rule only fires when the project's SDK lower bound is >=3.13.0.
///
/// ### Example
///
/// #### BAD:
/// ```dart
/// class UserProfile {
///   const UserProfile({
///     required this.id,
///     required this.displayName,
///   });
///
///   final String id;
///   final String displayName;
/// }
/// ```
///
/// #### GOOD:
/// ```dart
/// class UserProfile(final String id, final String displayName);
/// ```
class PreferPrimaryConstructorRule extends SaropaLintRule {
  PreferPrimaryConstructorRule() : super(code: _code);

  /// Modernization advisory — projects on older SDKs won't see this fire.
  @override
  LintImpact get impact => LintImpact.info;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'dart-core', 'migration', 'sdk'};

  /// Medium cost: reads pubspec (cached) and iterates class members/fields.
  @override
  RuleCost get cost => RuleCost.medium;

  /// Purely syntactic: only inspects AST shape (extends/with/mixin keywords,
  /// constructor body/initializers, field-formal params) — never a resolved
  /// type, element, or supertype, so resolution is not required.
  @override
  bool get usesTypeResolution => false;

  /// Only relevant for files that declare classes.
  @override
  bool get requiresClassDeclaration => true;

  static const LintCode _code = LintCode(
    'prefer_primary_constructor',
    '[prefer_primary_constructor] This class is eligible for Dart 3.13+ '
        'primary constructor syntax. The class has a single unnamed generative '
        'constructor whose parameters are all field formals (this.x), all '
        'instance fields are final, and the constructor has no body or '
        'initializer list. Rewriting as a primary constructor removes '
        'boilerplate and makes the class shape immediately visible in the '
        'declaration line. {v1}',
    correctionMessage:
        'Rewrite as: class ClassName(final Type field, ...) or '
        'class ClassName({required final Type field, ...});',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    // Gate on SDK version first — skip all analysis if project is <3.13.
    final sdkLower = _dartSdkLower(context.filePath);
    if (!sdkIsAtLeast(sdkLower, 3, 13)) return;

    context.addClassDeclaration((ClassDeclaration node) {
      if (!isPrimaryConstructorEligible(node)) return;
      // Report on the class name token for clear IDE highlighting.
      reporter.atToken(node.nameToken, code);
    });
  }
}

/// Checks all eligibility conditions for `prefer_primary_constructor` from
/// the proposal. Purely syntactic — never touches a resolved type — so it can
/// be exercised directly against an unresolved `parseString` AST in tests.
///
/// Top-level (not a method) and `@visibleForTesting` so behavior tests can
/// verify detection logic without depending on the SDK-gate/pubspec plumbing
/// in [PreferPrimaryConstructorRule.runWithReporter], which requires a real
/// project root with SDK >=3.13.0 that the shared `example/` fixture package
/// does not have.
@visibleForTesting
bool isPrimaryConstructorEligible(ClassDeclaration node) {
  // Rule 6: not a mixin class.
  if (node.mixinKeyword != null) return false;

  // Rule 5: does not extend anything other than Object.
  if (node.extendsClause != null) return false;

  // Rule 7: no `with` clause.
  if (node.withClause != null) return false;

  // Gather constructors and fields from class members.
  final constructors = <ConstructorDeclaration>[];
  final instanceFields = <String, FieldDeclaration>{};
  bool hasFieldWithInitializer = false;

  for (final ClassMember member in node.bodyMembers) {
    if (member is ConstructorDeclaration) {
      constructors.add(member);
    } else if (member is FieldDeclaration && !member.isStatic) {
      // Rule 4: all instance fields must be final.
      if (!member.fields.isFinal) return false;
      // `late final` has no equivalent in primary-constructor syntax — the
      // implicit field can't be declared late, so a rewrite would silently
      // change initialization timing. Excluded even though it is "final".
      if (member.fields.isLate) return false;
      // A field carrying its own annotation (e.g. @JsonKey()) has no
      // established placement on a primary-constructor parameter yet —
      // excluded to avoid suggesting a rewrite that loses the annotation.
      if (member.metadata.isNotEmpty) return false;
      // Track each field name → declaration for coverage check.
      for (final variable in member.fields.variables) {
        instanceFields[variable.name.lexeme] = member;
        // Fields with inline initializers can't migrate to primary ctor.
        if (variable.initializer != null) {
          hasFieldWithInitializer = true;
        }
      }
    }
  }

  // Must have at least one instance field — empty classes don't benefit.
  if (instanceFields.isEmpty) return false;

  // Fields with inline initializers are not expressible in primary ctors.
  if (hasFieldWithInitializer) return false;

  // Rule 8 & 9: no factory constructors, no named constructors.
  // Rule 1: exactly one unnamed generative constructor.
  ConstructorDeclaration? unnamedCtor;
  for (final ctor in constructors) {
    if (ctor.factoryKeyword != null) return false; // Rule 8
    if (ctor.name != null) return false; // Rule 9: named constructor
    if (unnamedCtor != null) return false; // More than one unnamed
    unnamedCtor = ctor;
  }

  // Must have exactly one constructor.
  if (unnamedCtor == null) return false;

  // Rule 2: constructor body is empty (no body, no initializer list).
  if (unnamedCtor.body is! EmptyFunctionBody) return false;
  if (unnamedCtor.initializers.isNotEmpty) return false;

  // Rule 3: ALL constructor parameters must be field formals (this.x).
  // Also collect the field names referenced to check coverage.
  final params = unnamedCtor.parameters.parameters;
  if (params.isEmpty) return false;
  final coveredFields = <String>{};

  for (final FormalParameter param in params) {
    // Unwrap DefaultFormalParameter to get the actual parameter.
    final actual = param is DefaultFormalParameter ? param.parameter : param;
    if (actual is! FieldFormalParameter) return false;
    // Same rationale as field annotations above — annotated constructor
    // parameters (e.g. @Default()) have no established primary-ctor form.
    if (actual.metadata.isNotEmpty) return false;
    coveredFields.add(actual.name.lexeme);
  }

  // Rule 10 (additional): all instance fields must be covered by the ctor.
  if (coveredFields.length != instanceFields.length) return false;
  for (final fieldName in instanceFields.keys) {
    if (!coveredFields.contains(fieldName)) return false;
  }

  return true;
}
