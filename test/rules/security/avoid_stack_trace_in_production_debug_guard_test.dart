// Regression tests for avoid_stack_trace_in_production's debug-guard
// detector, covering indirection through a local variable and a zero-arg
// helper function, and recognition of the Dart-VM-native
// `bool.fromEnvironment('dart.vm.product')` guard.
//
// See bugs/avoid_stack_trace_in_production_false_positive_indirect_debug_guard.md
// (moved to plans/history/2026.09/2026.09.18/ once closed).
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
// ignore: implementation_imports
import 'package:analyzer/src/string_source.dart';
import 'package:analyzer/workspace/workspace.dart';
import 'package:path/path.dart' as p;
import 'package:saropa_lints/src/rules/security/security_network_input_rules.dart';
import 'package:saropa_lints/src/saropa_lint_rule.dart';
// ignore: implementation_imports
import 'package:saropa_lints/src/scan/capturing_registry.dart';
// ignore: implementation_imports
import 'package:saropa_lints/src/scan/scan_walker.dart';
import 'package:test/test.dart';

import '../../support/resolved_rule_harness.dart';
import '../../support/safe_delete.dart';

/// Runs [rule] against [code] inside a synthetic project that has a real
/// `package:flutter/foundation.dart` to resolve against, so
/// `kDebugMode`/`kProfileMode`/`kReleaseMode` resolve to their ACTUAL
/// declaring library (`package:flutter/src/foundation/constants.dart`),
/// not just a name. Mirrors `_runRuleResolvedInProject` in
/// `test/rules/resources/db_yield_rules_test.dart`, but that harness only
/// needs a `pubspec.yaml` (its rules gate on the pubspec text, never
/// resolving `package:flutter/...`); this one additionally fabricates a
/// minimal `flutter` package on disk and a `.dart_tool/package_config.json`
/// pointing the `flutter` package name at it, so the import actually
/// resolves. The fake package mirrors the real SDK's shape exactly:
/// `foundation.dart` re-exports `src/foundation/constants.dart`, which is
/// where the constants are truly DECLARED — this is what let the
/// `foundation.dart`-only version of `_isBuildModeConstant` slip through
/// review: `element.library.uri` reports the declaring library, not the
/// importing one.
Future<List<HarnessDiagnostic>> _runRuleResolvedWithFakeFlutter(
  SaropaLintRule rule,
  String code, {
  String fileStem = 'fixture',
}) async {
  final provider = PhysicalResourceProvider.INSTANCE;
  final Directory projectDir = Directory.systemTemp.createTempSync(
    'saropa_fake_flutter_',
  );
  try {
    final Directory libDir = Directory(p.join(projectDir.path, 'lib'))
      ..createSync(recursive: true);
    final Directory flutterPkgDir = Directory(
      p.join(projectDir.path, '_fake_flutter_pkg'),
    )..createSync(recursive: true);
    final Directory flutterLibDir = Directory(p.join(flutterPkgDir.path, 'lib'))
      ..createSync(recursive: true);
    final Directory foundationSrcDir = Directory(
      p.join(flutterLibDir.path, 'src', 'foundation'),
    )..createSync(recursive: true);

    File(
      p.join(flutterLibDir.path, 'foundation.dart'),
    ).writeAsStringSync("export 'src/foundation/constants.dart';\n");
    File(p.join(foundationSrcDir.path, 'constants.dart')).writeAsStringSync('''
const bool kReleaseMode = bool.fromEnvironment('dart.vm.product');
const bool kProfileMode = bool.fromEnvironment('dart.vm.profile');
const bool kDebugMode = !kReleaseMode && !kProfileMode;
''');

    final Directory dartToolDir = Directory(
      p.join(projectDir.path, '.dart_tool'),
    )..createSync(recursive: true);
    final String rootUri = p.toUri('${projectDir.path}/').toString();
    final String flutterUri = p.toUri('${flutterPkgDir.path}/').toString();
    File(p.join(dartToolDir.path, 'package_config.json')).writeAsStringSync('''
{
  "configVersion": 2,
  "packages": [
    {"name": "fake_flutter_app", "rootUri": "$rootUri", "packageUri": "lib/"},
    {"name": "flutter", "rootUri": "$flutterUri", "packageUri": "lib/"}
  ],
  "generator": "avoid_stack_trace_in_production_debug_guard_test"
}
''');

    final File file = File(p.join(libDir.path, '$fileStem.dart'));
    file.writeAsStringSync(code);
    final String path = file.absolute.path;

    final AnalysisContextCollection collection = AnalysisContextCollection(
      includedPaths: [path],
      resourceProvider: provider,
    );
    final session = collection.contextFor(path).currentSession;
    final result = await session.getResolvedUnit(path);
    if (result is! ResolvedUnitResult) {
      throw StateError('Fixture failed to resolve: $result');
    }
    if (result.diagnostics.isNotEmpty) {
      throw StateError(
        'Fixture has analysis errors (fake flutter package setup is '
        'likely broken): ${result.diagnostics}',
      );
    }

    final RecordingDiagnosticListener listener = RecordingDiagnosticListener();
    final DiagnosticReporter reporter = DiagnosticReporter(
      listener,
      StringSource(result.content, path),
    );
    final RuleContextUnit ctxUnit = RuleContextUnit(
      file: provider.getFile(path),
      content: result.content,
      diagnosticReporter: reporter,
      unit: result.unit,
    );
    final _FakeFlutterRuleContext context = _FakeFlutterRuleContext(
      unit: ctxUnit,
      typeProvider: result.typeProvider,
      typeSystem: result.typeSystem,
      library: result.libraryElement,
    );

    final CapturingRuleVisitorRegistry registry =
        CapturingRuleVisitorRegistry();
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
  } finally {
    safeDeleteDir(projectDir);
  }
}

/// Minimal [RuleContext], copied from `resolved_rule_harness.dart`'s
/// private `_ResolvedRuleContext` (not exported — this test needs its own
/// instance to drive [_runRuleResolvedWithFakeFlutter]).
class _FakeFlutterRuleContext implements RuleContext {
  _FakeFlutterRuleContext({
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
  group('avoid_stack_trace_in_production - debug guard indirection', () {
    test('still fires on an unguarded stack trace print (control)', () async {
      final codes = await reportedRuleCodes(
        AvoidStackTraceInProductionRule(),
        '''
void logError(Object error, StackTrace stack) {
  print(stack);
}
''',
      );
      expect(codes, contains('avoid_stack_trace_in_production'));
    });

    test(
      'does NOT fire when guarded directly by !bool.fromEnvironment(dart.vm.product)',
      () async {
        final codes = await reportedRuleCodes(
          AvoidStackTraceInProductionRule(),
          '''
void logError(Object error, StackTrace stack) {
  if (!bool.fromEnvironment('dart.vm.product')) {
    print(stack);
  }
}
''',
        );
        expect(codes, isEmpty);
      },
    );

    test(
      'does NOT fire when the guard is reached through a local variable',
      () async {
        final codes = await reportedRuleCodes(
          AvoidStackTraceInProductionRule(),
          '''
void logError(Object error, StackTrace stack) {
  final bool includeTrace = !bool.fromEnvironment('dart.vm.product');
  if (includeTrace) {
    print(stack);
  }
}
''',
        );
        expect(codes, isEmpty);
      },
    );

    test(
      'does NOT fire when the guard is reached through a helper function call',
      () async {
        final codes = await reportedRuleCodes(
          AvoidStackTraceInProductionRule(),
          '''
bool isDebug() => !bool.fromEnvironment('dart.vm.product');

void logError(Object error, StackTrace stack) {
  if (isDebug()) {
    print(stack);
  }
}
''',
        );
        expect(codes, isEmpty);
      },
    );

    test('does NOT fire on the two-hop shape from the bug report '
        '(variable initializer combining a flag with a helper call)', () async {
      final codes = await reportedRuleCodes(
        AvoidStackTraceInProductionRule(),
        '''
bool _isDebugEnvironment() =>
    !bool.fromEnvironment('dart.vm.product', defaultValue: false);

void logError(Object error, StackTrace stack, {bool includeStack = true}) {
  final bool includeTrace = includeStack && _isDebugEnvironment();
  if (includeTrace) {
    print(stack);
  }
}
''',
      );
      expect(codes, isEmpty);
    });

    test(
      'still fires when dart.vm.product is checked WITHOUT negation '
      '(guards for production, not debug -- must not be suppressed)',
      () async {
        final codes = await reportedRuleCodes(
          AvoidStackTraceInProductionRule(),
          '''
void logError(Object error, StackTrace stack) {
  final bool isProduction = bool.fromEnvironment('dart.vm.product');
  if (isProduction) {
    print(stack);
  }
}
''',
        );
        expect(codes, contains('avoid_stack_trace_in_production'));
      },
    );
  });

  // Sound-guard-analysis regressions: the old detector treated `&&`/`||`
  // alike and matched a negation-recognized pattern anywhere in the
  // condition's source text (including inside helper bodies/initializers
  // reached by indirection). Each case below looks like a debug guard on
  // the surface but is NOT a sound guard for the then-branch, and must
  // keep firing. Mirrors the fix ported from
  // GuardDebuggerAgainstTestEnvironmentRule (commit 66ac1a95).
  group('avoid_stack_trace_in_production - sound guard analysis (&&/||/!)', () {
    test(
      'still fires on a negated helper call (guarantees production)',
      () async {
        final codes = await reportedRuleCodes(
          AvoidStackTraceInProductionRule(),
          '''
bool isDebug() => !bool.fromEnvironment('dart.vm.product');

void logError(Object error, StackTrace stack) {
  if (!isDebug()) {
    print(stack);
  }
}
''',
        );
        expect(codes, contains('avoid_stack_trace_in_production'));
      },
    );

    test('still fires on || with an unguarded operand '
        '(verbose bypasses the debug check)', () async {
      final codes = await reportedRuleCodes(
        AvoidStackTraceInProductionRule(),
        '''
bool isDebug() => !bool.fromEnvironment('dart.vm.product');

void logError(Object error, StackTrace stack, {bool verbose = false}) {
  if (verbose || isDebug()) {
    print(stack);
  }
}
''',
      );
      expect(codes, contains('avoid_stack_trace_in_production'));
    });

    test('still fires on a variable holding a negated guard '
        '(release is true exactly when NOT debug)', () async {
      final codes = await reportedRuleCodes(
        AvoidStackTraceInProductionRule(),
        '''
bool isDebug() => !bool.fromEnvironment('dart.vm.product');

void logError(Object error, StackTrace stack) {
  final bool release = !isDebug();
  if (release) {
    print(stack);
  }
}
''',
      );
      expect(codes, contains('avoid_stack_trace_in_production'));
    });

    test('still fires on an unmodeled binary operator (!=)', () async {
      final codes = await reportedRuleCodes(
        AvoidStackTraceInProductionRule(),
        '''
bool isDebug() => !bool.fromEnvironment('dart.vm.product');

void logError(Object error, StackTrace stack, {bool x = true}) {
  if (x != isDebug()) {
    print(stack);
  }
}
''',
      );
      expect(codes, contains('avoid_stack_trace_in_production'));
    });

    test('still fires on a variable initializer that is || with an '
        'unguarded operand', () async {
      final codes = await reportedRuleCodes(
        AvoidStackTraceInProductionRule(),
        '''
void logError(Object error, StackTrace stack, {bool verbose = false}) {
  final bool show = verbose || !bool.fromEnvironment('dart.vm.product');
  if (show) {
    print(stack);
  }
}
''',
      );
      expect(codes, contains('avoid_stack_trace_in_production'));
    });

    test(
      'still fires on a helper whose body is a production check '
      '(kDebugMode text appears inside it but not as the whole condition)',
      () async {
        final codes = await reportedRuleCodes(
          AvoidStackTraceInProductionRule(),
          '''
const bool kDebugMode = true;
bool isRelease() =>
    bool.fromEnvironment('dart.vm.product') || !kDebugMode;

void logError(Object error, StackTrace stack) {
  if (isRelease()) {
    print(stack);
  }
}
''',
        );
        expect(codes, contains('avoid_stack_trace_in_production'));
      },
    );

    test(
      'does NOT fire on !kReleaseMode (negation of the release atom)',
      () async {
        final codes = await reportedRuleCodes(
          AvoidStackTraceInProductionRule(),
          '''
const bool kReleaseMode = false;
void logError(Object error, StackTrace stack) {
  if (!kReleaseMode) {
    print(stack);
  }
}
''',
        );
        expect(codes, isEmpty);
      },
    );

    test(
      'does NOT fire on && where only one operand is a debug guard',
      () async {
        final codes = await reportedRuleCodes(
          AvoidStackTraceInProductionRule(),
          '''
bool isDebug() => !bool.fromEnvironment('dart.vm.product');

void logError(Object error, StackTrace stack, {bool includeStack = true}) {
  if (includeStack && isDebug()) {
    print(stack);
  }
}
''',
        );
        expect(codes, isEmpty);
      },
    );
  });

  // Second review pass: two more soundness gaps, both verified by running
  // the harness. (1) The initializer resolver trusted a mutable local's
  // initializer even after the local was reassigned before the `if`. (2)
  // The atom check used `toSource().contains(...)`, so any expression
  // that merely mentioned a recognized name anywhere in its text (e.g. as
  // an argument to an unrelated call) counted as a guard.
  group('avoid_stack_trace_in_production - reassignment and exact atoms', () {
    test('still fires when the local is reassigned after its debug-guard '
        'initializer and before the if', () async {
      final codes = await reportedRuleCodes(
        AvoidStackTraceInProductionRule(),
        '''
bool isDebug() => !bool.fromEnvironment('dart.vm.product');

void logError(Object error, StackTrace stack) {
  var t = isDebug();
  t = true;
  if (t) {
    print(stack);
  }
}
''',
      );
      expect(codes, contains('avoid_stack_trace_in_production'));
    });

    test('still fires when the local is CONDITIONALLY reassigned between '
        'its debug-guard initializer and the if', () async {
      final codes = await reportedRuleCodes(
        AvoidStackTraceInProductionRule(),
        '''
const bool kDebugMode = true;

void logError(Object error, StackTrace stack, {bool v = false}) {
  bool t = kDebugMode;
  if (v) {
    t = true;
  }
  if (t) {
    print(stack);
  }
}
''',
      );
      expect(codes, contains('avoid_stack_trace_in_production'));
    });

    test('does NOT lose the guard when a FINAL local is never reassigned '
        '(control for the reassignment check)', () async {
      final codes = await reportedRuleCodes(
        AvoidStackTraceInProductionRule(),
        '''
const bool kDebugMode = true;

void logError(Object error, StackTrace stack) {
  final bool t = kDebugMode;
  if (t) {
    print(stack);
  }
}
''',
      );
      expect(codes, isEmpty);
    });

    test('still fires when the recognized name is only an ARGUMENT to an '
        'unrelated call, not the condition itself', () async {
      final codes = await reportedRuleCodes(
        AvoidStackTraceInProductionRule(),
        '''
const bool kDebugMode = true;
bool hide(bool b) => !b;

void logError(Object error, StackTrace stack) {
  if (hide(kDebugMode)) {
    print(stack);
  }
}
''',
      );
      expect(codes, contains('avoid_stack_trace_in_production'));
    });

    test('does NOT fire on kDebugMode == true', () async {
      final codes = await reportedRuleCodes(
        AvoidStackTraceInProductionRule(),
        '''
const bool kDebugMode = true;

void logError(Object error, StackTrace stack) {
  if (kDebugMode == true) {
    print(stack);
  }
}
''',
      );
      expect(codes, isEmpty);
    });

    test('does NOT fire on kReleaseMode == false', () async {
      final codes = await reportedRuleCodes(
        AvoidStackTraceInProductionRule(),
        '''
const bool kReleaseMode = false;

void logError(Object error, StackTrace stack) {
  if (kReleaseMode == false) {
    print(stack);
  }
}
''',
      );
      expect(codes, isEmpty);
    });

    test('still fires on kDebugMode != true (negated via !=)', () async {
      final codes = await reportedRuleCodes(
        AvoidStackTraceInProductionRule(),
        '''
const bool kDebugMode = true;

void logError(Object error, StackTrace stack) {
  if (kDebugMode != true) {
    print(stack);
  }
}
''',
      );
      expect(codes, contains('avoid_stack_trace_in_production'));
    });
  });

  // Third review pass (BLOCKER): confirmed against the real Flutter SDK.
  // `kDebugMode`/`kProfileMode`/`kReleaseMode` are DECLARED in
  // `package:flutter/src/foundation/constants.dart` — `foundation.dart`
  // only re-exports them — so `element.library.uri` for a real
  // `import 'package:flutter/foundation.dart'; if (kDebugMode) ...` never
  // equals `package:flutter/foundation.dart` itself. The
  // foundation.dart-only version of `_isBuildModeConstant` therefore
  // flagged the canonical guard in every real Flutter app. These tests
  // resolve against a fake `flutter` package built with the SAME shape
  // (a `foundation.dart` barrel re-exporting `src/foundation/constants.dart`)
  // to reproduce that exact failure mode without depending on an absolute
  // path to a real Flutter checkout.
  group('avoid_stack_trace_in_production - real Flutter foundation import', () {
    test('does NOT fire on kDebugMode guarding print, resolved against a '
        'real package:flutter/foundation.dart import', () async {
      final diags = await _runRuleResolvedWithFakeFlutter(
        AvoidStackTraceInProductionRule(),
        '''
import 'package:flutter/foundation.dart';

void logError(Object error, StackTrace stack) {
  if (kDebugMode) {
    print(stack);
  }
}
''',
      );
      expect(
        diags.map((d) => d.ruleName),
        isNot(contains('avoid_stack_trace_in_production')),
      );
    });

    test('does NOT fire on !kReleaseMode, resolved against a real '
        'package:flutter/foundation.dart import', () async {
      final diags = await _runRuleResolvedWithFakeFlutter(
        AvoidStackTraceInProductionRule(),
        '''
import 'package:flutter/foundation.dart';

void logError(Object error, StackTrace stack) {
  if (!kReleaseMode) {
    print(stack);
  }
}
''',
      );
      expect(
        diags.map((d) => d.ruleName),
        isNot(contains('avoid_stack_trace_in_production')),
      );
    });

    test(
      'does NOT fire on a namespace-qualified foundation.kDebugMode, '
      'resolved against a real package:flutter/foundation.dart import',
      () async {
        final diags = await _runRuleResolvedWithFakeFlutter(
          AvoidStackTraceInProductionRule(),
          '''
import 'package:flutter/foundation.dart' as foundation;

void logError(Object error, StackTrace stack) {
  if (foundation.kDebugMode) {
    print(stack);
  }
}
''',
        );
        expect(
          diags.map((d) => d.ruleName),
          isNot(contains('avoid_stack_trace_in_production')),
        );
      },
    );

    test('still fires on an unguarded print, resolved against a real '
        'package:flutter/foundation.dart import (control)', () async {
      final diags = await _runRuleResolvedWithFakeFlutter(
        AvoidStackTraceInProductionRule(),
        '''
void logError(Object error, StackTrace stack) {
  print(stack);
}
''',
      );
      expect(
        diags.map((d) => d.ruleName),
        contains('avoid_stack_trace_in_production'),
      );
    });
  });

  // Third review pass, point 2: dropped the mutable-local indirection path
  // entirely (only `final`/`const` locals are traced now — see
  // `_findLocalDeclaration`'s doc comment) because a textual "reassigned
  // between declaration and use" scan can't see control flow: a
  // loop-carried reassignment happens AFTER the use on a later iteration,
  // not between the declaration and (the first) use in source order.
  group('avoid_stack_trace_in_production - mutable locals never trusted', () {
    test('still fires when a mutable local is reassigned in a later loop '
        'iteration, after the guarded use earlier in the loop body', () async {
      final codes = await reportedRuleCodes(
        AvoidStackTraceInProductionRule(),
        '''
bool isDebug() => !bool.fromEnvironment('dart.vm.product');

void logError(Object error, StackTrace stack, List<bool> xs) {
  var t = isDebug();
  for (final bool x in xs) {
    if (t) {
      print(stack);
    }
    t = x;
  }
}
''',
      );
      expect(codes, contains('avoid_stack_trace_in_production'));
    });

    test('still fires on a mutable local that is NEVER reassigned at all '
        '(mutable locals are never trusted, regardless)', () async {
      final codes = await reportedRuleCodes(
        AvoidStackTraceInProductionRule(),
        '''
bool isDebug() => !bool.fromEnvironment('dart.vm.product');

void logError(Object error, StackTrace stack) {
  var t = isDebug();
  if (t) {
    print(stack);
  }
}
''',
      );
      expect(codes, contains('avoid_stack_trace_in_production'));
    });
  });

  // Third review pass, point 3: a non-Flutter name match now additionally
  // requires the resolved element (when resolved) to be a top-level
  // `const` — a mutable field of the same name isn't a build-mode guard.
  group('avoid_stack_trace_in_production - non-Flutter atom must be const', () {
    test(
      'still fires when kDebugMode is a mutable top-level variable',
      () async {
        final codes = await reportedRuleCodes(
          AvoidStackTraceInProductionRule(),
          '''
bool kDebugMode = true;

void logError(Object error, StackTrace stack) {
  if (kDebugMode) {
    print(stack);
  }
}
''',
        );
        expect(codes, contains('avoid_stack_trace_in_production'));
      },
    );

    test(
      'still fires when kDebugMode is a mutable static field on a class',
      () async {
        final codes = await reportedRuleCodes(
          AvoidStackTraceInProductionRule(),
          '''
class Flags {
  static bool kDebugMode = true;
}

void logError(Object error, StackTrace stack) {
  if (Flags.kDebugMode) {
    print(stack);
  }
}
''',
        );
        expect(codes, contains('avoid_stack_trace_in_production'));
      },
    );

    test('does NOT fire when kDebugMode is a non-Flutter top-level const '
        "(control — this package's own fixtures rely on this)", () async {
      final codes = await reportedRuleCodes(
        AvoidStackTraceInProductionRule(),
        '''
const bool kDebugMode = true;

void logError(Object error, StackTrace stack) {
  if (kDebugMode) {
    print(stack);
  }
}
''',
      );
      expect(codes, isEmpty);
    });
  });
}
