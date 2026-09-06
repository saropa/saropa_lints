// ignore_for_file: depend_on_referenced_packages, implementation_imports
//
// Syntactic-analyzer test oracle: runs ONE SaropaLintRule against inline
// source with NO type resolution -- exactly the AST shape the default
// `saropa_lints scan` (used by "scan on save") produces, and mirrors
// `ScanRunner._scanSingleFile` in lib/src/scan/scan_runner.dart.
//
// Why this exists, and why it is NOT the same as resolved_rule_harness.dart:
// a bare `Identifier.identifier(args)` call (no `new`/`const`) is genuinely
// ambiguous until the receiver is resolved to either a static method or a
// named/factory constructor. `parseString` (this harness) always keeps it as
// a `MethodInvocation` -- resolution (the other harness, via
// `AnalysisContextCollection`) rewrites it to `InstanceCreationExpression`
// once `Identifier.identifier` resolves to a real constructor, e.g.
// `Timer.periodic` (a factory constructor in dart:async). A rule written
// against `context.addMethodInvocation` for a `ClassName.namedConstructor`
// pattern -- as `AvoidIosBatteryDrainPatternsRule` is for `Timer.periodic`
// -- therefore only ever fires on the SYNTACTIC pass. Using the resolved
// harness against such a rule silently tests nothing (empty diagnostics
// regardless of the rule's own logic), which is why this harness exists
// alongside it rather than folding into it.
library;

import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart' show AstVisitor;
import 'package:analyzer/error/listener.dart';
import 'package:analyzer/file_system/physical_file_system.dart';
import 'package:analyzer/src/string_source.dart';
import 'package:path/path.dart' as p;
import 'package:saropa_lints/saropa_lints.dart';
import 'package:saropa_lints/src/scan/capturing_registry.dart';
import 'package:saropa_lints/src/scan/scan_rule_context.dart';
import 'package:saropa_lints/src/scan/scan_walker.dart';

/// A single diagnostic reported by a rule during a syntactic harness run.
class SyntacticDiagnostic {
  SyntacticDiagnostic({required this.ruleName, required this.line});

  /// The rule code (e.g. `avoid_ios_battery_drain_patterns`).
  final String ruleName;

  /// 1-based line number of the diagnostic within the fixture source.
  final int line;

  @override
  String toString() => '$ruleName:$line';
}

/// Runs [rule] against [code] with NO type resolution (a plain
/// `parseString` pass, exactly like the default `saropa_lints scan`) and
/// returns the diagnostics it reports.
///
/// [pathHint] is embedded in the fake file path so path-based gates
/// (`skipExampleFiles`, `isCliBinScript`, etc.) can be exercised deliberately
/// by a caller that needs to; the default keeps the file safely inside a
/// `lib/` directory, which is what most rules expect.
List<SyntacticDiagnostic> runRuleSyntactic(
  SaropaLintRule rule,
  String code, {
  String pathHint = 'lib/fixture.dart',
}) {
  final provider = PhysicalResourceProvider.INSTANCE;
  // A fake absolute path is sufficient: the syntactic pass never touches
  // the filesystem for resolution, only for the rule's own path-string gates.
  final path = p.normalize(p.absolute(pathHint));
  final file = provider.getFile(path);

  final unit = parseString(
    content: code,
    path: path,
    featureSet: FeatureSet.latestLanguageVersion(),
    throwIfDiagnostics: false,
  ).unit;

  final listener = RecordingDiagnosticListener();
  final reporter = DiagnosticReporter(listener, StringSource(code, path));
  final ctxUnit = RuleContextUnit(
    file: file,
    content: code,
    diagnosticReporter: reporter,
    unit: unit,
  );
  final context = ScanRuleContext(definingUnit: ctxUnit);

  final registry = CapturingRuleVisitorRegistry();
  rule.registerNodeProcessors(registry, context);
  rule.reporter = reporter;

  final visitors = registry.capturedVisitors.cast<AstVisitor<void>>();
  if (visitors.isNotEmpty) {
    unit.accept(ScanWalker(visitors));
  }
  for (final callback in registry.afterLibraryCallbacks) {
    callback();
  }

  return [
    for (final d in listener.diagnostics)
      SyntacticDiagnostic(
        ruleName: d.diagnosticCode.lowerCaseName,
        line: unit.lineInfo.getLocation(d.offset).lineNumber,
      ),
  ];
}

/// Convenience: the set of distinct rule codes reported for [code].
Set<String> reportedRuleCodesSyntactic(
  SaropaLintRule rule,
  String code, {
  String pathHint = 'lib/fixture.dart',
}) {
  final diags = runRuleSyntactic(rule, code, pathHint: pathHint);
  return diags.map((d) => d.ruleName).toSet();
}
