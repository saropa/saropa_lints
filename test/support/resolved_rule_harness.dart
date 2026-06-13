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

/// Runs [rule] against [code] with full resolution and returns the diagnostics
/// it reports. The fixture is written to a UNIQUE temp subdirectory under
/// `example/lib/` (so it inherits the example package's resolved config) and
/// removed afterward.
///
/// A unique per-call directory (via `createTempSync`) is required because
/// `dart test` runs test files concurrently in separate isolates: a single
/// shared fixture path would let one isolate's cleanup delete another's
/// in-flight fixture, producing flaky empty results.
Future<List<HarnessDiagnostic>> runRuleResolved(
  SaropaLintRule rule,
  String code, {
  String fileStem = 'fixture',
}) async {
  final provider = PhysicalResourceProvider.INSTANCE;
  final exampleLib = p.normalize(p.absolute(p.join('example', 'lib')));
  final base = Directory(p.join(exampleLib, '__rule_harness__'))
    ..createSync(recursive: true);
  // OS-level unique subdir name avoids collisions across concurrent isolates.
  final dir = base.createTempSync('h');

  final file = File(p.join(dir.path, '$fileStem.dart'));
  file.writeAsStringSync(code);
  final path = file.absolute.path;

  try {
    final collection = AnalysisContextCollection(
      includedPaths: [path],
      resourceProvider: provider,
    );
    final session = collection.contextFor(path).currentSession;
    final result = await session.getResolvedUnit(path);
    if (result is! ResolvedUnitResult) {
      throw StateError('Fixture failed to resolve: $result');
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
    if (dir.existsSync()) {
      dir.deleteSync(recursive: true);
    }
  }
}

/// Convenience: the set of distinct rule codes reported for [code].
Future<Set<String>> reportedRuleCodes(SaropaLintRule rule, String code) async {
  final diags = await runRuleResolved(rule, code);
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
