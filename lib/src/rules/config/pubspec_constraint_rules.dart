// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

import 'dart:io'
    show Directory, File, FileSystemEntity, FileSystemException, Platform;

import 'package:analyzer/dart/ast/ast.dart';

import '../../config/pubspec_constraint_parser.dart';
import '../../fixes/config/add_resolution_workspace_fix.dart';
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

// =============================================================================
// add_resolution_workspace
// =============================================================================

/// Flags a package in a Dart pub workspace that is missing
/// `resolution: workspace` in its pubspec.yaml.
///
/// Since: v16.0.0-beta.7 | Rule version: v1
///
/// Dart 3.6 introduced pub workspaces so a monorepo can share a single
/// lockfile. A member package that omits `resolution: workspace` falls back
/// to independent resolution — its own lockfile, its own dependency graph —
/// silently defeating the workspace and reintroducing version drift. The
/// detection walks to the nearest ancestor pubspec.yaml (never past it) and
/// checks its `workspace:` list for membership.
///
/// **BAD:**
/// ```yaml
/// # packages/foo/pubspec.yaml (listed in root workspace:)
/// name: foo
/// environment:
///   sdk: ^3.6.0
/// ```
///
/// **GOOD:**
/// ```yaml
/// # packages/foo/pubspec.yaml
/// name: foo
/// environment:
///   sdk: ^3.6.0
/// resolution: workspace
/// ```
///
/// **Quick fix available:** Inserts `resolution: workspace` after the
/// `environment:` block in pubspec.yaml (or at end of file if absent).
class AddResolutionWorkspaceRule extends SaropaLintRule {
  AddResolutionWorkspaceRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.warning;

  @override
  RuleType? get ruleType => RuleType.bug;

  @override
  Set<String> get tags => const {'config', 'pubspec', 'workspace'};

  @override
  RuleCost get cost => RuleCost.low;

  // Offers to insert `resolution: workspace` into the package's pubspec.yaml.
  // Edits the YAML file via addGenericFileEdit (same pattern as
  // RaiseSdkLowerBoundFix) since the diagnostic attaches to a .dart token.
  @override
  List<SaropaFixGenerator> get fixGenerators => [
    ({required CorrectionProducerContext context}) =>
        AddResolutionWorkspaceFix(context: context),
  ];

  /// Dedup set: report at most once per project root.
  static final Set<String> _reportedRoots = {};

  /// Regex to detect a top-level `resolution: workspace` line in a pubspec.
  /// Anchored to column 0 so indented YAML values (inside environment: etc.)
  /// cannot match. Allows trailing whitespace and YAML comments (# ...).
  static final RegExp _resolutionWorkspaceRe = RegExp(
    r'^resolution:\s+workspace\s*(?:#.*)?$',
    multiLine: true,
  );

  static const LintCode _code = LintCode(
    'add_resolution_workspace',
    '[add_resolution_workspace] This package is listed in a pub workspace '
        'but does not declare `resolution: workspace` in its pubspec.yaml. '
        'Without it the package resolves dependencies independently — its own '
        'lockfile, its own version graph — silently defeating the shared '
        'workspace resolution and reintroducing version drift between packages '
        'that are supposed to be locked together. Add `resolution: workspace` '
        'as a top-level key. {v1}',
    correctionMessage:
        'Add `resolution: workspace` as a top-level key in pubspec.yaml.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    // Find this file's project root (nearest pubspec.yaml).
    final root = ProjectContext.findProjectRoot(context.filePath);
    if (root == null) return;
    if (_reportedRoots.contains(root)) return;

    // Only attach to lib/ files to dedup (same pattern as _reportPubspecOnce).
    // Known limitation: bin-only or tool-only workspace members with no lib/
    // directory will never trigger this rule. Fixing requires a different
    // reporting anchor, which is a separate design change for all pubspec rules.
    final path = context.filePath.replaceAll('\\', '/');
    if (!path.contains('/lib/')) return;

    // Check if this package is a listed workspace member.
    final workspaceRoot = ProjectContext.getWorkspaceRoot(root);
    if (workspaceRoot == null) return;

    // Read this package's own pubspec to check for resolution: workspace.
    final pubspecFile = File('$root/pubspec.yaml');
    if (!pubspecFile.existsSync()) return;

    final content = pubspecFile.readAsStringSync();

    // If the pubspec already has `resolution: workspace`, nothing to report.
    if (_resolutionWorkspaceRe.hasMatch(content)) return;

    // Package is a workspace member but missing the resolution declaration.
    _reportedRoots.add(root);
    context.addCompilationUnit((CompilationUnit unit) {
      final token = unit.beginToken;
      if (token.isEof) return;
      reporter.atOffset(offset: token.offset, length: token.length);
    });
  }
}

// =============================================================================
// Flag missing workspace member (inverse of add_resolution_workspace)
// =============================================================================

/// Flags a workspace root pubspec that has subdirectories containing
/// `pubspec.yaml` files not listed in the root's `workspace:` list.
///
/// This is the root-side companion to [AddResolutionWorkspaceRule] (member-side).
/// A package that exists on disk but isn't listed in the workspace root's
/// `workspace:` list resolves independently — its own lockfile, its own
/// dependency graph — silently defeating the shared workspace for that package.
///
/// Since: v16.0.0-beta.7 | Rule version: v1
///
/// **BAD:**
/// ```yaml
/// # pubspec.yaml (workspace root)
/// name: my_monorepo
/// workspace:
///   - packages/foo
///   # packages/bar exists on disk with a pubspec.yaml but isn't listed
/// ```
///
/// **GOOD:**
/// ```yaml
/// # pubspec.yaml (workspace root)
/// name: my_monorepo
/// workspace:
///   - packages/foo
///   - packages/bar
/// ```
class FlagMissingWorkspaceMemberRule extends SaropaLintRule {
  FlagMissingWorkspaceMemberRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.info;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'config', 'pubspec', 'workspace'};

  @override
  RuleCost get cost => RuleCost.medium;

  /// Dedup set: report at most once per workspace root directory.
  static final Set<String> _reportedRoots = {};

  /// Maximum depth to scan for subdirectory pubspec.yaml files.
  /// Typical workspace layouts use 1-2 levels (packages/foo, apps/bar).
  /// Deeper scans risk hitting generated directories and slow analysis.
  static const int _maxScanDepth = 3;

  static const LintCode _code = LintCode(
    'flag_missing_workspace_member',
    '[flag_missing_workspace_member] This workspace root has subdirectories '
        'containing pubspec.yaml files that are not listed in the workspace: '
        'list. Unlisted packages resolve independently — their own lockfile, '
        'their own version graph — silently defeating the shared workspace '
        'resolution. Add the missing package paths to the workspace: list, or '
        'move non-member packages outside the workspace root. {v1}',
    correctionMessage:
        'Add the missing package directory to the workspace: list in '
        'pubspec.yaml.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    // Find this file's project root.
    final root = ProjectContext.findProjectRoot(context.filePath);
    if (root == null) return;
    if (_reportedRoots.contains(root)) return;

    // Only attach to lib/ files (same dedup pattern as other pubspec rules).
    final path = context.filePath.replaceAll('\\', '/');
    if (!path.contains('/lib/')) return;

    // Check if this project root IS a workspace root (has workspace: key).
    final members = ProjectContext.getWorkspaceMembers(root);
    if (members.isEmpty) return;

    // Build a normalized set of listed members for O(1) lookup.
    final normalizedMembers = <String>{};
    for (final entry in members) {
      var clean = entry.replaceAll('\\', '/');
      if (clean.startsWith('./')) clean = clean.substring(2);
      if (clean.endsWith('/')) clean = clean.substring(0, clean.length - 1);
      if (Platform.isWindows) clean = clean.toLowerCase();
      normalizedMembers.add(clean);
    }

    // Scan subdirectories (bounded depth) for pubspec.yaml files not listed.
    final rootDir = Directory(root);
    final missing = <String>[];
    _scanForUnlistedPackages(
      rootDir,
      root,
      normalizedMembers,
      missing,
      0,
    );

    if (missing.isEmpty) return;

    // At least one unlisted package found — report on the first lib/ token.
    _reportedRoots.add(root);
    context.addCompilationUnit((CompilationUnit unit) {
      final token = unit.beginToken;
      if (token.isEof) return;
      reporter.atOffset(offset: token.offset, length: token.length);
    });
  }

  /// Recursively scans [dir] for subdirectories containing pubspec.yaml that
  /// are not in [listedMembers]. Stops at [_maxScanDepth] and skips
  /// already-listed member directories (their children like example/ are
  /// intentionally not workspace members).
  void _scanForUnlistedPackages(
    Directory dir,
    String workspaceRoot,
    Set<String> listedMembers,
    List<String> missing,
    int depth,
  ) {
    if (depth >= _maxScanDepth) return;

    // List immediate children only (not recursive).
    List<FileSystemEntity> children;
    try {
      children = dir.listSync(followLinks: false);
    } on FileSystemException {
      // Permission denied, symlink loop, etc. — skip silently.
      return;
    }

    for (final child in children) {
      if (child is! Directory) continue;

      // Skip hidden directories (., .dart_tool, .git) and build output.
      final name = child.path.replaceAll('\\', '/').split('/').last;
      if (name.startsWith('.') || name == 'build') continue;

      // Compute relative path from workspace root to this directory.
      var relative = child.path
          .replaceAll('\\', '/')
          .substring(workspaceRoot.replaceAll('\\', '/').length + 1);
      if (relative.endsWith('/')) {
        relative = relative.substring(0, relative.length - 1);
      }
      final comparePath = Platform.isWindows
          ? relative.toLowerCase()
          : relative;

      // If this directory has a pubspec.yaml and isn't listed, it's missing.
      final hasPubspec = File('${child.path}/pubspec.yaml').existsSync();
      if (hasPubspec && !listedMembers.contains(comparePath)) {
        missing.add(relative);
        // Don't recurse into unlisted packages — their children aren't
        // workspace candidates either.
        continue;
      }

      // If this directory IS a listed member, skip recursion — its children
      // (like example/) are intentionally not workspace members.
      if (listedMembers.contains(comparePath)) continue;

      // Directory has no pubspec and isn't a listed member — recurse to find
      // packages nested inside container directories (packages/, apps/).
      _scanForUnlistedPackages(
        child,
        workspaceRoot,
        listedMembers,
        missing,
        depth + 1,
      );
    }
  }
}
