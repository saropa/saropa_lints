// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/error.dart' show DiagnosticSeverity;
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../async_context_utils.dart';
import '../saropa_lint_rule.dart';

// =============================================================================
// v4.1.7 Rules - Performance Best Practices
// =============================================================================

/// Warns when widget types change conditionally, destroying Elements.
///
/// Returning the same widget type with same key reuses Elements. Changing
/// widget types or keys destroys Elements, losing state and causing expensive
/// rebuilds.
///
/// **BAD:**
/// ```dart
/// Widget build(BuildContext context) {
///   if (isLoading) {
///     return CircularProgressIndicator(); // Type A
///   }
///   return MyContent(); // Type B - Element destroyed on toggle!
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// Widget build(BuildContext context) {
///   return Stack(children: [
///     MyContent(),
///     if (isLoading) CircularProgressIndicator(),
///   ]);
/// }
/// ```
class PreferElementRebuildRule extends SaropaLintRule {
  const PreferElementRebuildRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    name: 'prefer_element_rebuild',
    problemMessage:
        '[prefer_element_rebuild] Conditional return of different widget types destroys Elements.',
    correctionMessage:
        'Use Stack, Visibility, or AnimatedSwitcher to preserve Element state.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodDeclaration((MethodDeclaration node) {
      if (node.name.lexeme != 'build') return;

      final FunctionBody? body = node.body;
      if (body == null) return;

      // Collect all return statements in the build method
      final List<ReturnStatement> returns = <ReturnStatement>[];
      _collectReturnStatements(body, returns);

      if (returns.length < 2) return;

      // Check if returns are in different branches of conditionals
      final Set<String> returnTypes = <String>{};
      for (final ReturnStatement ret in returns) {
        final Expression? expr = ret.expression;
        if (expr is InstanceCreationExpression) {
          returnTypes.add(expr.constructorName.type.name2.lexeme);
        } else if (expr is MethodInvocation) {
          returnTypes.add(expr.methodName.name);
        }
      }

      // If different widget types are returned, warn
      if (returnTypes.length > 1) {
        reporter.atNode(node, code);
      }
    });
  }

  void _collectReturnStatements(AstNode node, List<ReturnStatement> returns) {
    if (node is ReturnStatement) {
      returns.add(node);
    }
    for (final AstNode child in node.childEntities.whereType<AstNode>()) {
      _collectReturnStatements(child, returns);
    }
  }
}

/// Warns when heavy computation is done on the main isolate.
///
/// Heavy computation on main isolate blocks UI (16ms budget per frame).
/// Use `compute()` or `Isolate.run()` for JSON parsing, image processing,
/// or data transforms.
///
/// **BAD:**
/// ```dart
/// Future<List<User>> parseUsers(String json) async {
///   return jsonDecode(json); // Blocks main thread for large JSON!
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// Future<List<User>> parseUsers(String json) async {
///   return compute(_parseJson, json);
/// }
///
/// List<User> _parseJson(String json) => jsonDecode(json);
/// ```
class RequireIsolateForHeavyRule extends SaropaLintRule {
  const RequireIsolateForHeavyRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'require_isolate_for_heavy',
    problemMessage:
        '[require_isolate_for_heavy] Heavy computation blocks the main thread, causing UI jank and dropped frames.',
    correctionMessage:
        'Use compute(_parse, data) or Isolate.run(() => _parse(data)) to run in background.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  static const Set<String> _heavyOperations = {
    'jsonDecode',
    'jsonEncode',
    'parse', // Often heavy for large data
    'decompress',
    'compress',
    'encrypt',
    'decrypt',
    'hash',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;
      if (!_heavyOperations.contains(methodName)) return;

      // Check if already inside compute() or Isolate.run()
      if (isInsideIsolate(node)) return;

      // Check if in async context (likely handling network response)
      if (isInAsyncContext(node)) {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when Dart Finalizers are misused.
///
/// Dart Finalizers run non-deterministically and add GC overhead.
/// Prefer explicit dispose() methods. Finalizers are only for native
/// resource cleanup as a safety net.
///
/// **BAD:**
/// ```dart
/// class MyResource {
///   static final Finalizer<MyResource> _finalizer =
///       Finalizer((r) => r._cleanup());
///
///   MyResource() {
///     _finalizer.attach(this, this);
///   }
///
///   void _cleanup() => print('Cleaned up'); // Non-deterministic!
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// class MyResource {
///   void dispose() {
///     _cleanup(); // Explicit, deterministic
///   }
/// }
/// ```
class AvoidFinalizerMisuseRule extends SaropaLintRule {
  const AvoidFinalizerMisuseRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'avoid_finalizer_misuse',
    problemMessage:
        '[avoid_finalizer_misuse] Finalizer used for non-native resources. Prefer explicit dispose().',
    correctionMessage:
        'Use dispose() pattern for deterministic cleanup. Finalizers are only for native FFI resources.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addFieldDeclaration((FieldDeclaration node) {
      for (final VariableDeclaration variable in node.fields.variables) {
        final Expression? initializer = variable.initializer;
        if (initializer == null) continue;

        final String initSource = initializer.toSource();
        if (initSource.contains('Finalizer<') ||
            initSource.contains('Finalizer(')) {
          // Check if this class also has dispose() - if so, it's OK
          final ClassDeclaration? classDecl = _findParentClass(node);
          if (classDecl != null && !_hasDisposeMethod(classDecl)) {
            reporter.atNode(variable, code);
          }
        }
      }
    });
  }

  ClassDeclaration? _findParentClass(AstNode node) {
    AstNode? current = node.parent;
    while (current != null) {
      if (current is ClassDeclaration) return current;
      current = current.parent;
    }
    return null;
  }

  bool _hasDisposeMethod(ClassDeclaration classDecl) {
    for (final ClassMember member in classDecl.members) {
      if (member is MethodDeclaration && member.name.lexeme == 'dispose') {
        return true;
      }
    }
    return false;
  }
}

/// Warns when jsonDecode is called on main thread without isolate.
///
/// `[HEURISTIC]` - Detects jsonDecode without compute/isolate wrapper.
///
/// `jsonDecode()` for large payloads (>100KB) blocks the main thread.
/// Use `compute()` to parse JSON in a background isolate.
///
/// **BAD:**
/// ```dart
/// Future<List<Item>> fetchItems() async {
///   final response = await http.get(url);
///   return jsonDecode(response.body); // Blocks UI!
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// Future<List<Item>> fetchItems() async {
///   final response = await http.get(url);
///   return compute(jsonDecode, response.body);
/// }
/// ```
class AvoidJsonInMainRule extends SaropaLintRule {
  const AvoidJsonInMainRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'avoid_json_in_main',
    problemMessage:
        '[avoid_json_in_main] jsonDecode on main thread blocks UI for large payloads (100KB+).',
    correctionMessage:
        'Use compute(jsonDecode, data) or Isolate.run(() => jsonDecode(data)).',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name != 'jsonDecode') return;

      // Check if already inside compute() or Isolate.run()
      if (isInsideIsolate(node)) return;

      // Check if in async context (likely handling network response)
      if (isInAsyncContext(node)) {
        reporter.atNode(node, code);
      }
    });
  }
}
