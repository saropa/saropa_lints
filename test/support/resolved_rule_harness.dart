// ignore_for_file: depend_on_referenced_packages, implementation_imports
//
// Resolved-analyzer test oracle: runs ONE SaropaLintRule against an inline
// fixture with FULL type/element resolution, and returns the diagnostics it
// reports (rule name + line).
//
// Why this exists: the rule test suite previously only pinned rule metadata,
// checked fixture files exist, and *counted* `// expect_lint:` strings — none
// of which executes a rule. That let detection false-positives/negatives ship
// undetected. This harness closes that gap for any rule whose detection needs
// dart:core / dart:async / meta resolution.
//
// Resolution scope: fixtures are written under `example/lib/` so they inherit
// the example package's resolved config (dart SDK + meta + crypto). The example
// package does NOT depend on Flutter, so `Widget`/`State`/`Semantics` and other
// Flutter types resolve to InvalidType here — a correctly written type-based
// rule must treat unresolved types conservatively (not flag), which this
// harness still verifies (GOOD stays silent). Flutter-typed positive assertions
// need a Flutter-resolved fixture package and are out of scope for this oracle.
library;

import 'dart:async';
import 'dart:io';

import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart' show AstVisitor;
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type_provider.dart';
import 'package:analyzer/dart/element/type_system.dart';
import 'package:analyzer/error/listener.dart';
import 'package:analyzer/file_system/overlay_file_system.dart';
import 'package:analyzer/file_system/physical_file_system.dart';
import 'package:analyzer/src/string_source.dart';
import 'package:analyzer/workspace/workspace.dart';
import 'package:path/path.dart' as p;
import 'package:saropa_lints/saropa_lints.dart';
import 'package:saropa_lints/src/scan/capturing_registry.dart';
import 'package:saropa_lints/src/scan/scan_walker.dart';

/// A single diagnostic reported by a rule during a harness run.
class HarnessDiagnostic {
  HarnessDiagnostic({
    required this.ruleName,
    required this.line,
    required this.message,
  });

  /// The rule code (e.g. `avoid_expensive_build`).
  final String ruleName;

  /// 1-based line number of the diagnostic within the fixture source.
  final int line;

  /// The rendered problem message (no trailing URL).
  final String message;

  @override
  String toString() => '$ruleName:$line';
}

/// One long-lived analysis setup per project root (per isolate). Re-creating an
/// [AnalysisContextCollection] per call re-links dart:core/async/meta each time
/// and exhausts memory over hundreds of tests, so it is built once and reused.
class _HarnessEnv {
  _HarnessEnv(this.overlay, this.collection);
  final OverlayResourceProvider overlay;
  final AnalysisContextCollection collection;

  /// Tail of the per-env call chain; serializes overlapping calls so the
  /// driver never sees concurrent edits (InconsistentAnalysisException).
  Future<void> lock = Future<void>.value();
}

_HarnessEnv _newEnv(String libDir) {
  final overlay = OverlayResourceProvider(PhysicalResourceProvider.INSTANCE);
  return _HarnessEnv(
    overlay,
    AnalysisContextCollection(
      includedPaths: [libDir],
      resourceProvider: overlay,
    ),
  );
}

final Map<String, _HarnessEnv> _envs = {};
int _fixtureCounter = 0;

/// Runs [rule] against [code] with full resolution and returns the diagnostics
/// it reports. The fixture exists only as an in-memory overlay at a unique
/// virtual path under `example/lib/__rule_harness__/` (so it inherits the
/// example package's resolved config); nothing is written to disk.
///
/// Pass [projectRoot] to use `<projectRoot>/lib/` instead, for rules that read
/// project files next to the pubspec (for example `ios/Runner/Info.plist`);
/// those real files are still read through the physical provider. Such a
/// fixture resolves against the SDK only, so it must not import packages.
///
/// The default example/lib collection is cached and never disposed per call; a
/// [projectRoot] collection is one-off and disposed after the call. A
/// failed SDK / `package:meta` load throws instead of silently yielding an
/// empty diagnostic set that looks like "rule reported nothing".
Future<List<HarnessDiagnostic>> runRuleResolved(
  SaropaLintRule rule,
  String code, {
  String fileStem = 'fixture',
  Directory? projectRoot,
}) async {
  final libDir = projectRoot == null
      ? p.normalize(p.absolute(p.join('example', 'lib')))
      : p.normalize(p.absolute(p.join(projectRoot.path, 'lib')));
  final cached = projectRoot == null;
  // The context root must exist on disk even though the fixture is an overlay.
  if (!cached) Directory(libDir).createSync(recursive: true);
  final env = cached
      ? _envs.putIfAbsent(libDir, () => _newEnv(libDir))
      : _newEnv(libDir);
  final prev = env.lock;
  final done = Completer<void>();
  env.lock = done.future;
  try {
    await prev;
    return await _runLocked(env, libDir, rule, code, fileStem);
  } finally {
    done.complete();
    if (!cached) await env.collection.dispose();
  }
}

Future<List<HarnessDiagnostic>> _runLocked(
  _HarnessEnv env,
  String libDir,
  SaropaLintRule rule,
  String code,
  String fileStem,
) async {
  final provider = env.overlay;
  // Unique per call within this isolate; pid distinguishes concurrent isolates
  // (harmless here since overlays are in-memory, but keeps paths distinct).
  final path = p.join(
    libDir,
    '__rule_harness__',
    'h${pid}_${_fixtureCounter++}',
    '$fileStem.dart',
  );

  final actx = env.collection.contextFor(path);
  try {
    provider.setOverlay(
      path,
      content: code,
      modificationStamp: DateTime.now().microsecondsSinceEpoch,
    );
    final session = actx.currentSession;
    final result = await session.getResolvedUnit(path);
    if (result is! ResolvedUnitResult) {
      throw StateError('Fixture failed to resolve: $result');
    }
    // Flutter imports legitimately fail to resolve (see header); a missing
    // dart: library or package:meta means the SDK/package config did not load.
    final loadFailures = [
      for (final d in result.diagnostics)
        if (d.diagnosticCode.lowerCaseName == 'uri_does_not_exist' &&
            RegExp(
              r"'(dart:|package:meta/)",
            ).hasMatch(d.problemMessage.messageText(includeUrl: false)))
          d.problemMessage.messageText(includeUrl: false),
    ];
    if (loadFailures.isNotEmpty) {
      throw StateError(
        'Analysis environment failed to load (SDK/package config): '
        '${loadFailures.join('; ')}',
      );
    }

    final listener = RecordingDiagnosticListener();
    final reporter = DiagnosticReporter(
      listener,
      StringSource(result.content, path),
    );
    final ctxUnit = RuleContextUnit(
      file: provider.getFile(path),
      content: result.content,
      diagnosticReporter: reporter,
      unit: result.unit,
    );
    final context = _ResolvedRuleContext(
      unit: ctxUnit,
      typeProvider: result.typeProvider,
      typeSystem: result.typeSystem,
      library: result.libraryElement,
    );

    final registry = CapturingRuleVisitorRegistry();
    // Verified false positive: `context` is `_ResolvedRuleContext` (this
    // file's own test-harness context, defined below), not Flutter's
    // BuildContext. The scan CLI's default syntactic pass has no type
    // information to distinguish that from the identifier name alone.
    // ignore: avoid_context_across_async
    rule.registerNodeProcessors(registry, context);
    rule.reporter = reporter;

    final visitors = registry.capturedVisitors.cast<AstVisitor<void>>();
    if (visitors.isNotEmpty) {
      result.unit.accept(ScanWalker(visitors));
    }
    // Rules that aggregate across a unit (e.g. duplicate detection) report from
    // an afterLibrary callback, not a node visitor — flush them too.
    for (final callback in registry.afterLibraryCallbacks) {
      callback();
    }

    return [
      for (final d in listener.diagnostics)
        HarnessDiagnostic(
          ruleName: d.diagnosticCode.lowerCaseName,
          line: result.unit.lineInfo.getLocation(d.offset).lineNumber,
          message: d.problemMessage.messageText(includeUrl: false),
        ),
    ];
  } finally {
    provider.removeOverlay(path);
    actx.changeFile(path);
    await actx.applyPendingFileChanges();
  }
}

/// Convenience: the set of distinct rule codes reported for [code].
Future<Set<String>> reportedRuleCodes(
  SaropaLintRule rule,
  String code, {
  Directory? projectRoot,
}) async {
  final diags = await runRuleResolved(rule, code, projectRoot: projectRoot);
  return diags.map((d) => d.ruleName).toSet();
}

/// [RuleContext] backed by a fully resolved unit. Mirrors the scan command's
/// `ScanRuleContext` but supplies real [typeProvider]/[typeSystem]/
/// [libraryElement] instead of throwing. [isFeatureEnabled] returns false to
/// match the scan context's conservative default (feature-gated detection is
/// not exercised by this oracle).
class _ResolvedRuleContext implements RuleContext {
  _ResolvedRuleContext({
    required RuleContextUnit unit,
    required TypeProvider typeProvider,
    required TypeSystem typeSystem,
    required LibraryElement library,
  }) : _unit = unit,
       _typeProvider = typeProvider,
       _typeSystem = typeSystem,
       _library = library,
       currentUnit = unit;

  final RuleContextUnit _unit;
  final TypeProvider _typeProvider;
  final TypeSystem _typeSystem;
  final LibraryElement _library;

  @override
  RuleContextUnit? currentUnit;

  @override
  List<RuleContextUnit> get allUnits => [_unit];

  @override
  RuleContextUnit get definingUnit => _unit;

  @override
  bool get isInLibDir {
    final path = _unit.file.path.replaceAll('\\', '/');
    return path.contains('/lib/');
  }

  @override
  bool get isInTestDirectory {
    final path = _unit.file.path.replaceAll('\\', '/');
    return path.contains('/test/');
  }

  @override
  LibraryElement? get libraryElement => _library;

  @override
  WorkspacePackage? get package => null;

  @override
  TypeProvider get typeProvider => _typeProvider;

  @override
  TypeSystem get typeSystem => _typeSystem;

  @override
  bool isFeatureEnabled(Feature feature) => false;
}
