// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

/// Flame game engine lint rules.
///
/// These rules help ensure Flame games are implemented correctly
/// and perform optimally.
library;

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart' show DiagnosticSeverity;
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../saropa_lint_rule.dart';

/// Warns when Vector2/Vector3 objects are created inside update().
///
/// Creating vectors in update() causes garbage collection churn since
/// update() is called every frame. Cache vectors as fields instead.
///
/// **BAD:**
/// ```dart
/// @override
/// void update(double dt) {
///   position.add(Vector2(10, 20) * dt); // New vector every frame!
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// static final _velocity = Vector2(10, 20);
///
/// @override
/// void update(double dt) {
///   position.add(_velocity * dt);
/// }
/// ```
class AvoidCreatingVectorInUpdateRule extends SaropaLintRule {
  const AvoidCreatingVectorInUpdateRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_creating_vector_in_update',
    problemMessage:
        '[avoid_creating_vector_in_update] Creating Vector in update() causes GC churn every frame.',
    correctionMessage: 'Cache vectors as static final or instance fields.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  static const Set<String> _vectorTypes = <String>{
    'Vector2',
    'Vector3',
    'Vector4',
    'Offset',
    'Size',
    'Rect',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodDeclaration((MethodDeclaration node) {
      // Only check update methods
      if (node.name.lexeme != 'update') return;

      // Visit all nodes in the update method body
      node.body.visitChildren(_VectorVisitor(reporter, code, _vectorTypes));
    });
  }
}

class _VectorVisitor extends RecursiveAstVisitor<void> {
  _VectorVisitor(this.reporter, this.code, this.vectorTypes);

  final SaropaDiagnosticReporter reporter;
  final LintCode code;
  final Set<String> vectorTypes;

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    final String typeName = node.constructorName.type.element?.name ??
        node.constructorName.type.name2.lexeme;

    if (vectorTypes.contains(typeName)) {
      // Skip const vectors - they're properly reused
      if (node.keyword?.lexeme != 'const') {
        reporter.atNode(node, code);
      }
    }
    super.visitInstanceCreationExpression(node);
  }
}

/// Warns when onLoad() is async but doesn't contain any await.
///
/// Making onLoad() async without await adds unnecessary overhead.
/// Remove the async keyword if no awaiting is needed.
///
/// **BAD:**
/// ```dart
/// @override
/// Future<void> onLoad() async {
///   // No await statements
///   add(SpriteComponent());
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// @override
/// void onLoad() {
///   add(SpriteComponent());
/// }
///
/// // Or if actually async:
/// @override
/// Future<void> onLoad() async {
///   final sprite = await loadSprite('player.png');
///   add(SpriteComponent(sprite: sprite));
/// }
/// ```
class AvoidRedundantAsyncOnLoadRule extends SaropaLintRule {
  const AvoidRedundantAsyncOnLoadRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_redundant_async_on_load',
    problemMessage:
        '[avoid_redundant_async_on_load] async onLoad() without await adds unnecessary overhead.',
    correctionMessage: 'Remove async keyword or add await statements.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodDeclaration((MethodDeclaration node) {
      // Only check onLoad methods
      if (node.name.lexeme != 'onLoad') return;

      // Check if method is async
      if (!node.body.isAsynchronous) return;

      // Check if body contains await
      bool hasAwait = false;
      node.body.visitChildren(_AwaitVisitor(onAwait: () {
        hasAwait = true;
      }));

      if (!hasAwait) {
        reporter.atNode(node, code);
      }
    });
  }
}

class _AwaitVisitor extends RecursiveAstVisitor<void> {
  _AwaitVisitor({required this.onAwait});

  final void Function() onAwait;

  @override
  void visitAwaitExpression(AwaitExpression node) {
    onAwait();
    super.visitAwaitExpression(node);
  }
}
