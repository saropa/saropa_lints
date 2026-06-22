// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

/// Cross-platform dependency-compatibility rules.
///
/// Warns when a project imports a Flutter plugin that has no native
/// implementation for a platform the project builds for. Backed by the
/// hand-verified [PluginPlatformSupport] knowledge base.
library;

import 'package:analyzer/dart/ast/ast.dart';

import '../../platform_support_utils.dart';
import '../../saropa_lint_rule.dart';

// =============================================================================
// avoid_platform_incompatible_dependency
// =============================================================================

/// Flags a plugin import when the project targets a platform the plugin does
/// not implement.
///
/// Since: v14.1.0 | Rule version: v1
///
/// A Flutter plugin compiles into every target because its Dart API is
/// platform-agnostic; only the native implementation is platform-specific. So
/// importing `sqflite` (no web implementation) into a project with a `web/`
/// directory builds cleanly and then throws `MissingPluginException` /
/// `UnsupportedError` the first time the plugin is called on web. The compiler
/// never warns — the failure only shows up at runtime, on the one platform the
/// developer probably did not test. This rule surfaces that gap statically.
///
/// **Detection is conservative by design.** It fires only when (a) the imported
/// package is in the verified [PluginPlatformSupport] list, (b) the project has
/// the matching `flutter create` platform directory, and (c) the import is not
/// a conditional import (`if (dart.library.X)`), which is the supported way to
/// supply a platform-specific alternative. Unknown packages never fire.
///
/// **Bad** (project has a `web/` directory):
/// ```dart
/// import 'package:sqflite/sqflite.dart'; // no web implementation
/// ```
///
/// **Good:**
/// ```dart
/// // Conditional import supplies a web-safe alternative.
/// import 'package:sqflite/sqflite.dart'
///     if (dart.library.html) 'package:my_app/db_web_stub.dart';
/// ```
class AvoidPlatformIncompatibleDependencyRule extends SaropaLintRule {
  AvoidPlatformIncompatibleDependencyRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.warning;

  @override
  RuleType? get ruleType => RuleType.bug;

  @override
  Set<String> get tags => const {'flutter', 'platform'};

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'avoid_platform_incompatible_dependency',
    '[avoid_platform_incompatible_dependency] This package has no native '
        'implementation for at least one platform this project builds for (web, '
        'Windows, macOS, or Linux), so calling into it throws '
        'MissingPluginException or UnsupportedError at runtime on that platform '
        'even though the build succeeds. Users on the unsupported platform hit a '
        'crash the compiler never warned about. {v1}',
    correctionMessage:
        'Guard the import with a conditional import '
        '(import ... if (dart.library.html) ...), gate the calls behind a '
        'platform check, or switch to a package that covers all of your target '
        'platforms. Confirm support on the package pub.dev page.',
    // Config-compatibility heuristic against a curated list, not a guaranteed
    // crash in every code path: WARNING, not ERROR.
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    // Plugin platform support is only meaningful for Flutter projects; pure
    // Dart packages have no platform directories and the knowledge base tracks
    // Flutter plugins.
    final projectInfo = ProjectContext.getProjectInfo(context.filePath);
    if (projectInfo == null || !projectInfo.isFlutterProject) return;

    context.addImportDirective((ImportDirective node) {
      final String? uri = node.uri.stringValue;
      if (uri == null) return;

      // A conditional import is the sanctioned escape hatch — it supplies a
      // platform-specific replacement, so the unsupported platform never loads
      // the native plugin. Skip it.
      if (node.configurations.isNotEmpty) return;

      final String? packageName = PluginPlatformSupport.packageNameFromUri(uri);
      if (packageName == null) return;

      final Set<String> unsupported =
          PluginPlatformSupport.unsupportedPlatforms(packageName);
      if (unsupported.isEmpty) return;

      // Fire only when the project actually builds for a platform the package
      // cannot serve. Intersecting the package's unsupported set with the
      // project's real targets is what keeps this from warning about, say, a
      // web gap on an Android-only app.
      for (final String platformId in unsupported) {
        if (ProjectContext.targetsPlatform(context.filePath, platformId)) {
          reporter.atNode(node);
          return;
        }
      }
    });
  }
}
