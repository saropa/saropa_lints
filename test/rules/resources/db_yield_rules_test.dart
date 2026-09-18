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
// ignore: implementation_imports
import 'package:analyzer/src/string_source.dart';
import 'package:analyzer/workspace/workspace.dart';
import 'package:path/path.dart' as p;
import 'package:saropa_lints/saropa_lints.dart';
// ignore: implementation_imports
import 'package:saropa_lints/src/scan/capturing_registry.dart';
// ignore: implementation_imports
import 'package:saropa_lints/src/scan/scan_walker.dart';
import 'package:test/test.dart';
import '../../helpers/fixture_discovery.dart';
import '../../support/resolved_rule_harness.dart';
import '../../support/safe_delete.dart';

/// Tests for 3 Database Yield lint rules.
///
/// Test fixtures: example/lib/db_yield/*

/// Runs [rule] against [code] inside a synthetic project rooted at
/// [projectDir] (which must already contain a `pubspec.yaml`), with full
/// analyzer resolution. This mirrors `runRuleResolved` from
/// `resolved_rule_harness.dart`, but targets an arbitrary project root
/// instead of the fixed `example/lib` package — needed here to fabricate a
/// project whose `pubspec.yaml` declares a Flutter dependency, since
/// `RequireYieldAfterDbWriteRule`/`SuggestYieldAfterDbReadRule` gate on
/// `ProjectContext.getProjectInfo(...).isFlutterProject`, and the repo's own
/// `example`/`example_packages` packages are deliberately pure-Dart (see
/// their pubspec.yaml — no `flutter:` dependency), so they can never
/// exercise the "is a Flutter project" branch of that gate.
Future<List<HarnessDiagnostic>> _runRuleResolvedInProject(
  SaropaLintRule rule,
  String code,
  Directory projectDir, {
  String fileStem = 'fixture',
}) async {
  final provider = PhysicalResourceProvider.INSTANCE;
  final libDir = Directory(p.join(projectDir.path, 'lib'))
    ..createSync(recursive: true);
  final file = File(p.join(libDir.path, '$fileStem.dart'));
  file.writeAsStringSync(code);
  final path = file.absolute.path;

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
  final context = _GateTestRuleContext(
    unit: ctxUnit,
    typeProvider: result.typeProvider,
    typeSystem: result.typeSystem,
    library: result.libraryElement,
  );

  final registry = CapturingRuleVisitorRegistry();
  // ignore: avoid_context_across_async
  rule.registerNodeProcessors(registry, context);
  rule.reporter = reporter;

  final visitors = registry.capturedVisitors.cast<AstVisitor<void>>();
  if (visitors.isNotEmpty) {
    result.unit.accept(ScanWalker(visitors));
  }
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
}

/// Minimal [RuleContext], copied from `resolved_rule_harness.dart`'s private
/// `_ResolvedRuleContext` (not exported — this test needs its own instance
/// to drive [_runRuleResolvedInProject]).
class _GateTestRuleContext implements RuleContext {
  _GateTestRuleContext({
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

void main() {
  group('Database Yield Rules - Rule Instantiation', () {
    test('RequireYieldAfterDbWriteRule', () {
      final rule = RequireYieldAfterDbWriteRule();
      expect(rule.code.lowerCaseName, 'require_yield_after_db_write');
      expect(
        rule.code.problemMessage,
        contains('[require_yield_after_db_write]'),
      );
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
    test('SuggestYieldAfterDbReadRule', () {
      final rule = SuggestYieldAfterDbReadRule();
      expect(rule.code.lowerCaseName, 'suggest_yield_after_db_read');
      expect(
        rule.code.problemMessage,
        contains('[suggest_yield_after_db_read]'),
      );
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
    test('AvoidReturnAwaitDbRule', () {
      final rule = AvoidReturnAwaitDbRule();
      expect(rule.code.lowerCaseName, 'avoid_return_await_db');
      expect(rule.code.problemMessage, contains('[avoid_return_await_db]'));
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
  });

  group('Database Yield Rules - Fixture Verification', () {
    final fixtureDir = Directory('example/lib/db_yield');
    final fixtures = discoverFixtures(fixtureDir);
    test('fixture directory exists and is not empty', () {
      expect(fixtureDir.existsSync(), isTrue);

      expect(fixtures, isNotEmpty);
    });

    for (final fixture in fixtures) {
      test('$fixture fixture exists', () {
        final file = File('example/lib/db_yield/${fixture}_fixture.dart');

        expect(file.existsSync(), isTrue);
      });
    }
  });

  // Regression coverage for:
  // - bugs/require_yield_after_db_write_false_positive_one_shot_file_io_non_flutter_server.md
  // - bugs/suggest_yield_after_db_read_false_positive_one_shot_file_io_non_flutter_server.md
  //
  // Root cause: neither rule checked whether the enclosing package actually
  // depends on Flutter before firing, even though the entire threat model
  // ("blocking the UI thread", `DelayUtils.yieldToUI()`) is Flutter-specific.
  // Both rules now gate on `ProjectContext.getProjectInfo(...).isFlutterProject`.
  group('Database Yield Rules - Flutter-context gate', () {
    // Reduced from the false-positive reports' reproducers
    // (saropa_drift_advisor's SnapshotStore, a pure dart:io server with no
    // Flutter dependency).
    const String oneShotWriteCode = '''
import 'dart:io';

Future<void> save(String path, String json) async {
  final File tmp = File('\$path.tmp');
  await tmp.parent.create(recursive: true);
  await tmp.writeAsString(json, flush: true);
  await tmp.rename(path);
}
''';

    const String oneShotReadCode = '''
import 'dart:io';

Future<List<Object?>> load(String path) async {
  final File file = File(path);
  final String raw = await file.readAsString();
  if (raw.trim().isEmpty) return <Object?>[];
  return <Object?>[raw];
}
''';

    group('non-Flutter package (example/lib has no flutter dependency)', () {
      test('require_yield_after_db_write does NOT fire on a one-shot '
          'atomic-save write with no UI thread to protect', () async {
        final codes = await reportedRuleCodes(
          RequireYieldAfterDbWriteRule(),
          oneShotWriteCode,
        );
        expect(codes, isEmpty);
      });

      test('suggest_yield_after_db_read does NOT fire on a one-shot startup '
          'read with no UI thread to protect', () async {
        final codes = await reportedRuleCodes(
          SuggestYieldAfterDbReadRule(),
          oneShotReadCode,
        );
        expect(codes, isEmpty);
      });
    });

    group('Flutter package (true positives are preserved)', () {
      const String flutterPubspec = '''
name: flutter_app
environment:
  sdk: ">=3.0.0 <4.0.0"
  flutter: "3.13.0"
dependencies:
  flutter:
    sdk: flutter
''';

      late Directory projectDir;

      setUp(() {
        ProjectContext.clearCache();
        projectDir = Directory.systemTemp.createTempSync(
          'saropa_db_yield_gate_',
        );
        File(
          p.join(projectDir.path, 'pubspec.yaml'),
        ).writeAsStringSync(flutterPubspec);
      });

      tearDown(() => safeDeleteDir(projectDir));

      test('require_yield_after_db_write still fires on a one-shot write '
          'when the package depends on Flutter', () async {
        final diags = await _runRuleResolvedInProject(
          RequireYieldAfterDbWriteRule(),
          oneShotWriteCode,
          projectDir,
        );
        expect(
          diags.map((d) => d.ruleName),
          contains('require_yield_after_db_write'),
        );
      });

      test('suggest_yield_after_db_read still fires on a one-shot read '
          'when the package depends on Flutter', () async {
        final diags = await _runRuleResolvedInProject(
          SuggestYieldAfterDbReadRule(),
          oneShotReadCode,
          projectDir,
        );
        expect(
          diags.map((d) => d.ruleName),
          contains('suggest_yield_after_db_read'),
        );
      });
    });
  });
}
