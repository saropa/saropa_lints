// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

/// MethodChannel instrumentation rules.
///
/// Ensures that classes calling MethodChannel invoke-methods are annotated
/// to document their instrumentation status.
library;

import 'package:analyzer/dart/ast/ast.dart';

import '../../saropa_lint_rule.dart';

// =============================================================================
// require_method_channel_instrumented
// =============================================================================

/// Flags classes that call `MethodChannel.invokeMethod`,
/// `invokeListMethod`, or `invokeMapMethod` without a
/// `@MethodChannelInstrumented` annotation on the enclosing class.
///
/// Since: v14.3.9 | Rule version: v1
///
/// MethodChannel calls cross the Dart-to-native boundary via Binder IPC.
/// Slow calls block the Dart isolate and cause dropped frames. Annotating
/// every class that makes these calls forces developers to document whether
/// the call is instrumented (wrapped in timing/logging) or intentionally
/// unwrapped (trivial or off-main-thread).
///
/// **BAD:**
/// ```dart
/// class ContactsService {
///   final channel = MethodChannel('contacts');
///   Future<List<String>> getAll() => channel.invokeListMethod('getAll');
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// @MethodChannelInstrumented('all calls wrapped with noteIfSlow')
/// class ContactsService {
///   final channel = MethodChannel('contacts');
///   Future<List<String>> getAll() => channel.invokeListMethod('getAll');
/// }
/// ```
///
/// **Quick fix available:** Adds `@MethodChannelInstrumented` annotation
/// above the class declaration.
class RequireMethodChannelInstrumentedRule extends SaropaLintRule {
  RequireMethodChannelInstrumentedRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.info;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'flutter', 'platform', 'performance'};

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<String>? get requiredPatterns => const {'invokeMethod'};

  @override
  bool get requiresClassDeclaration => true;

  static const _invokeNames = {
    'invokeMethod',
    'invokeListMethod',
    'invokeMapMethod',
  };

  static const _annotationName = 'MethodChannelInstrumented';

  static const LintCode _code = LintCode(
    'require_method_channel_instrumented',
    '[require_method_channel_instrumented] Class calls MethodChannel '
        'invoke-methods without a @MethodChannelInstrumented annotation. '
        'MethodChannel calls cross the Dart-to-native boundary and can block '
        'the UI isolate, causing dropped frames. Annotating the class forces '
        'explicit documentation of whether each call site is instrumented with '
        'timing/logging or intentionally left unwrapped because the work is '
        'trivial or off the main thread. {v1}',
    correctionMessage:
        'Add @MethodChannelInstrumented above the class declaration '
        'documenting the instrumentation rationale.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  List<SaropaFixGenerator> get fixGenerators => [
    ({required CorrectionProducerContext context}) =>
        AddMethodChannelInstrumentedFix(context: context),
  ];

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      if (!_invokeNames.contains(node.methodName.name)) return;

      final classDecl =
          node.thisOrAncestorOfType<ClassDeclaration>();
      if (classDecl == null) return;

      final hasAnnotation = classDecl.metadata.any(
        (a) => a.name.name == _annotationName,
      );
      if (hasAnnotation) return;

      reporter.atNode(node.methodName);
    });
  }
}

// =============================================================================
// Quick fix: AddMethodChannelInstrumentedFix
// =============================================================================

/// Inserts `@MethodChannelInstrumented('TODO: document instrumentation
/// rationale')` above the enclosing class declaration.
class AddMethodChannelInstrumentedFix extends SaropaFixProducer {
  AddMethodChannelInstrumentedFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.addMethodChannelInstrumented',
    50,
    "Add @MethodChannelInstrumented annotation",
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final node = coveringNode;
    if (node == null) return;

    final classDecl = node.thisOrAncestorOfType<ClassDeclaration>();
    if (classDecl == null) return;

    final indent = getLineIndent(classDecl);

    await builder.addDartFileEdit(file, (builder) {
      builder.addSimpleInsertion(
        classDecl.offset,
        "$indent@MethodChannelInstrumented("
        "'TODO: document instrumentation rationale')\n",
      );
    });
  }
}
