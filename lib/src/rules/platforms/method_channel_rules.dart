// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

/// MethodChannel instrumentation rules.
///
/// Ensures that classes calling MethodChannel invoke-methods are annotated
/// to document their instrumentation status, and that each call site is
/// wrapped in a timing/logging helper.
library;

import 'package:analyzer/dart/ast/ast.dart';

import '../../saropa_lint_rule.dart';

/// Method names on MethodChannel that cross the Dart-to-native boundary.
const _invokeNames = {'invokeMethod', 'invokeListMethod', 'invokeMapMethod'};

const _annotationName = 'MethodChannelInstrumented';

/// Whether [annotation] matches [_annotationName], handling both bare
/// (`@MethodChannelInstrumented`) and prefixed (`@lib.MethodChannelInstrumented`)
/// imports.
bool _hasInstrumentedAnnotation(Annotation annotation) {
  final name = annotation.name;
  if (name is PrefixedIdentifier) {
    return name.identifier.name == _annotationName;
  }
  return name.name == _annotationName;
}

/// Returns the enclosing named declaration (class, mixin, or extension type)
/// that can carry annotations, or null if the node is top-level / in an
/// anonymous context.
ClassDeclaration? _enclosingAnnotatableClass(AstNode node) {
  return node.thisOrAncestorOfType<ClassDeclaration>();
}

// =============================================================================
// require_method_channel_instrumented
// =============================================================================

/// Flags classes that call `MethodChannel.invokeMethod`,
/// `invokeListMethod`, or `invokeMapMethod` without a
/// `@MethodChannelInstrumented` annotation on the enclosing class.
///
/// Since: v14.3.9 | Rule version: v2
///
/// MethodChannel calls cross the Dart-to-native boundary via Binder IPC.
/// Slow calls block the Dart isolate and cause dropped frames. Annotating
/// every class that makes these calls forces developers to document whether
/// the call is instrumented (wrapped in timing/logging) or intentionally
/// unwrapped (trivial or off-main-thread).
///
/// Reports one diagnostic per class (on the first invoke-method found),
/// not one per call site, to avoid noisy repeated squiggles.
///
/// Handles both bare and prefixed annotation imports
/// (`@MethodChannelInstrumented` and `@lib.MethodChannelInstrumented`).
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

  static const LintCode _code = LintCode(
    'require_method_channel_instrumented',
    '[require_method_channel_instrumented] Class calls MethodChannel '
        'invoke-methods without a @MethodChannelInstrumented annotation. '
        'MethodChannel calls cross the Dart-to-native boundary and can block '
        'the UI isolate, causing dropped frames. Annotating the class forces '
        'explicit documentation of whether each call site is instrumented with '
        'timing/logging or intentionally left unwrapped because the work is '
        'trivial or off the main thread. {v2}',
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
    // Track which classes already reported to emit one diagnostic per class.
    final reported = <int>{};

    context.addMethodInvocation((MethodInvocation node) {
      if (!_invokeNames.contains(node.methodName.name)) return;

      final classDecl = _enclosingAnnotatableClass(node);
      if (classDecl == null) return;

      if (reported.contains(classDecl.offset)) return;

      final hasAnnotation = classDecl.metadata.any(_hasInstrumentedAnnotation);
      if (hasAnnotation) return;

      reported.add(classDecl.offset);
      reporter.atNode(node.methodName);
    });
  }
}

// =============================================================================
// prefer_method_channel_note_if_slow
// =============================================================================

/// Flags `invokeMethod` / `invokeListMethod` / `invokeMapMethod` calls
/// inside an `@MethodChannelInstrumented` class that are NOT wrapped in a
/// `noteIfSlow` (or equivalent timing helper) call.
///
/// Since: v14.3.9 | Rule version: v1
///
/// Once a class carries `@MethodChannelInstrumented`, every invoke-method
/// call should be wrapped in `noteIfSlow(() => channel.invokeMethod(...))`
/// so that slow round-trips are measured and logged. A bare `invokeMethod`
/// in an annotated class defeats the purpose of the annotation.
///
/// **BAD:**
/// ```dart
/// @MethodChannelInstrumented('all calls instrumented')
/// class PaymentService {
///   final channel = MethodChannel('payments');
///   Future<void> charge() => channel.invokeMethod('charge');
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// @MethodChannelInstrumented('all calls instrumented')
/// class PaymentService {
///   final channel = MethodChannel('payments');
///   Future<void> charge() => noteIfSlow('charge', () => channel.invokeMethod('charge'));
/// }
/// ```
class PreferMethodChannelNoteIfSlowRule extends SaropaLintRule {
  PreferMethodChannelNoteIfSlowRule() : super(code: _code);

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

  @override
  List<String> get relatedRules => const [
    'require_method_channel_instrumented',
  ];

  static const _timingHelpers = {
    'noteIfSlow',
    'measureAsync',
    'timeAsync',
    'trackLatency',
  };

  static const LintCode _code = LintCode(
    'prefer_method_channel_note_if_slow',
    '[prefer_method_channel_note_if_slow] MethodChannel invoke-method call '
        'in an @MethodChannelInstrumented class is not wrapped in a timing '
        'helper (noteIfSlow or equivalent). Unwrapped calls bypass the '
        'instrumentation the annotation promises, so slow native round-trips '
        'go unmeasured and frame drops go undetected in debug builds. {v1}',
    correctionMessage:
        'Wrap the call in noteIfSlow(() => channel.invokeMethod(...)) '
        'or an equivalent timing helper.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      if (!_invokeNames.contains(node.methodName.name)) return;

      final classDecl = _enclosingAnnotatableClass(node);
      if (classDecl == null) return;

      final hasAnnotation = classDecl.metadata.any(_hasInstrumentedAnnotation);
      if (!hasAnnotation) return;

      if (_isInsideTimingHelper(node)) return;

      reporter.atNode(node.methodName);
    });
  }

  /// Walks ancestors to check if this invoke call is nested inside a call
  /// to a known timing helper (e.g. `noteIfSlow('label', () => ...)`).
  static bool _isInsideTimingHelper(MethodInvocation node) {
    AstNode? current = node.parent;
    while (current != null && current is! ClassDeclaration) {
      if (current is MethodInvocation &&
          _timingHelpers.contains(current.methodName.name)) {
        return true;
      }
      // The invoke call is typically inside a closure argument:
      //   noteIfSlow('label', () => channel.invokeMethod(...))
      // Walk through FunctionExpression, ExpressionFunctionBody, etc.
      if (current is FunctionExpression) {
        final funcParent = current.parent;
        if (funcParent is ArgumentList) {
          final callParent = funcParent.parent;
          if (callParent is MethodInvocation &&
              _timingHelpers.contains(callParent.methodName.name)) {
            return true;
          }
        }
      }
      current = current.parent;
    }
    return false;
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
        "$indent@$_annotationName("
        "'TODO: document instrumentation rationale')\n",
      );
    });
  }
}
