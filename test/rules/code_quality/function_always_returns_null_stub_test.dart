// ignore_for_file: depend_on_referenced_packages, implementation_imports
//
// End-to-end regression test for
// bugs/function_always_returns_null_false_positive_conditional_import_web_stub.md:
// FunctionAlwaysReturnsNullRule must not flag a static getter whose body is a
// bare `null` literal when the enclosing file is the web/stub branch of a
// `dart.library.io` conditional import — that IS the stub's contract, not a
// code smell. Unlike [runRuleResolved] (which writes a single fixture file),
// this test builds an isolated temp package with a real stub/io file pair so
// [isConditionalImportStubTarget] has a sibling to detect.
library;

import 'dart:io';

import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart' show AstVisitor;
import 'package:analyzer/dart/element/type_provider.dart';
import 'package:analyzer/dart/element/type_system.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/error/listener.dart';
import 'package:analyzer/file_system/physical_file_system.dart';
import 'package:analyzer/src/string_source.dart';
import 'package:analyzer/workspace/workspace.dart';
import 'package:path/path.dart' as p;
import 'package:saropa_lints/saropa_lints.dart';
import 'package:saropa_lints/src/scan/capturing_registry.dart';
import 'package:saropa_lints/src/scan/scan_walker.dart';
import 'package:test/test.dart';

import '../../support/safe_delete.dart';

/// Resolves [filePath] (already written to disk under an isolated temp
/// package) and returns the `function_always_returns_null` diagnostics
/// [FunctionAlwaysReturnsNullRule] reports for it.
Future<List<String>> _reportedLines(String filePath) async {
  final provider = PhysicalResourceProvider.INSTANCE;
  final collection = AnalysisContextCollection(
    includedPaths: [filePath],
    resourceProvider: provider,
  );
  final session = collection.contextFor(filePath).currentSession;
  final result = await session.getResolvedUnit(filePath);
  if (result is! ResolvedUnitResult) {
    throw StateError('Fixture failed to resolve: $result');
  }

  final listener = RecordingDiagnosticListener();
  final reporter = DiagnosticReporter(
    listener,
    StringSource(result.content, filePath),
  );
  final ctxUnit = RuleContextUnit(
    file: provider.getFile(filePath),
    content: result.content,
    diagnosticReporter: reporter,
    unit: result.unit,
  );
  final context = _StubTestRuleContext(
    unit: ctxUnit,
    typeProvider: result.typeProvider,
    typeSystem: result.typeSystem,
    library: result.libraryElement,
  );

  final rule = FunctionAlwaysReturnsNullRule();
  final registry = CapturingRuleVisitorRegistry();
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
      if (d.diagnosticCode.lowerCaseName == 'function_always_returns_null')
        'line ${result.unit.lineInfo.getLocation(d.offset).lineNumber}',
  ];
}

void main() {
  group('FunctionAlwaysReturnsNullRule — conditional import stub', () {
    test(
      'does NOT flag a static getter with a null-only body in the stub half '
      'of a dart.library.io conditional import (drift_debug_server_stub.dart shape)',
      () async {
        final dir = Directory.systemTemp.createTempSync(
          'saropa_far_null_stub_',
        );
        try {
          final libDir = Directory(p.join(dir.path, 'lib'))
            ..createSync(recursive: true);
          File(p.join(dir.path, 'pubspec.yaml')).writeAsStringSync('''
name: test_package
environment:
  sdk: ">=3.0.0 <4.0.0"
''');

          final stubPath = p.join(libDir.path, 'drift_debug_server_stub.dart');
          File(stubPath).writeAsStringSync('''
class DriftDebugServer {
  /// Stub: always returns null (server not running on web).
  static int? get port => null;

  /// Stub: always returns null (server not running on web).
  static bool? get changeDetectionEnabled => null;

  /// Stub: always returns null (server not running on web).
  static bool? get monitoringEnabled => null;
}
''');
          File(
            p.join(libDir.path, 'drift_debug_server_io.dart'),
          ).writeAsStringSync('''
class _LiveServer {
  int? port = 1234;
  bool? changeDetectionEnabled = true;
  bool? monitoringEnabled = true;
}

class DriftDebugServer {
  static _LiveServer? _instance;
  static int? get port => _instance?.port;
  static bool? get changeDetectionEnabled =>
      _instance?.changeDetectionEnabled;
  static bool? get monitoringEnabled => _instance?.monitoringEnabled;
}
''');
          File(
            p.join(libDir.path, 'drift_debug_server.dart'),
          ).writeAsStringSync('''
export 'drift_debug_server_stub.dart'
    if (dart.library.io) 'drift_debug_server_io.dart';
''');

          final lines = await _reportedLines(stubPath);
          expect(
            lines,
            isEmpty,
            reason:
                'stub members mirror the io implementation\'s contract; '
                'returning null is intentional, not a code smell',
          );
        } finally {
          safeDeleteDir(dir);
        }
      },
    );

    test(
      'still flags a static getter with a null-only body OUTSIDE a '
      'conditional import stub pair (no over-broad static exemption)',
      () async {
        final dir = Directory.systemTemp.createTempSync(
          'saropa_far_null_nostub_',
        );
        try {
          final libDir = Directory(p.join(dir.path, 'lib'))
            ..createSync(recursive: true);
          File(p.join(dir.path, 'pubspec.yaml')).writeAsStringSync('''
name: test_package
environment:
  sdk: ">=3.0.0 <4.0.0"
''');

          final lonePath = p.join(libDir.path, 'lonely_helper.dart');
          File(lonePath).writeAsStringSync('''
class Helper {
  static int? get value => null;
}
''');

          final lines = await _reportedLines(lonePath);
          expect(lines, ['line 2']);
        } finally {
          safeDeleteDir(dir);
        }
      },
    );
  });
}

/// Minimal [RuleContext] backed by a fully resolved unit, mirroring
/// `test/support/resolved_rule_harness.dart`'s `_ResolvedRuleContext`.
class _StubTestRuleContext implements RuleContext {
  _StubTestRuleContext({
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
