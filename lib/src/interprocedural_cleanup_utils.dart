// ignore_for_file: depend_on_referenced_packages

/// Interprocedural (cross-method) cleanup tracking for leak / disposal rules.
///
/// Single-method scanning produces a false positive whenever cleanup is moved
/// out of `dispose()` (or whatever method owns teardown) into a helper — the
/// classic extract-method refactor:
///
/// ```dart
/// void dispose() {
///   _teardown();          // a same-method scan never sees the close below
///   super.dispose();
/// }
/// void _teardown() {
///   _socket.close();
/// }
/// ```
///
/// The helpers here follow *same-class* method calls so the cleanup is found
/// where it actually lives. This replaces the prior heuristic of treating any
/// receiver-less private call inside `dispose()` as teardown, which was wrong in
/// both directions: it mis-suppressed a genuine leak when the helper did NOT
/// clean up, and it was too imprecise to justify ERROR severity. Resolving the
/// helper and checking its body removes both failure modes.
library;

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

import 'analyzer_compat.dart';

/// [start] plus every method of [classNode] transitively reachable from it by a
/// *same-class* method invocation — a receiver-less call (`_teardown()`) or a
/// `this.`-prefixed call (`this._teardown()`) whose name is declared directly on
/// [classNode].
///
/// AST-only by design: callees are resolved by matching the invoked name against
/// the class's own method declarations. That is sound for the same-class case (a
/// class cannot legally declare two methods with one name) and needs no element
/// model, so it works in the fast single-file analysis path that custom_lint
/// runs. Calls through a field / getter receiver (`helper.close()`) or to
/// inherited / mixed-in methods are intentionally NOT followed — only methods
/// declared on this class body, because only those can be read from the same
/// AST without resolution.
///
/// Cycle-safe (each method is visited at most once) and bounded by the class's
/// own method count, so mutually-recursive helpers terminate rather than loop.
List<MethodDeclaration> reachableSameClassMethods(
  MethodDeclaration start,
  ClassDeclaration classNode,
) {
  // Index the class's methods by name so a resolved call can find its callee
  // without a second pass over the members.
  final Map<String, MethodDeclaration> methodsByName =
      <String, MethodDeclaration>{};
  for (final ClassMember member in classNode.bodyMembers) {
    if (member is MethodDeclaration) {
      methodsByName[member.name.lexeme] = member;
    }
  }

  final List<MethodDeclaration> reached = <MethodDeclaration>[];
  final Set<String> visited = <String>{};
  // Work list rather than recursion: a deep helper chain must not overflow the
  // stack, and the visited set guarantees termination on cycles.
  final List<MethodDeclaration> pending = <MethodDeclaration>[start];

  while (pending.isNotEmpty) {
    final MethodDeclaration current = pending.removeLast();
    if (!visited.add(current.name.lexeme)) continue;
    reached.add(current);

    final _SameClassCallCollector collector = _SameClassCallCollector(
      methodsByName.keys,
    );
    current.body.accept(collector);

    for (final String calledName in collector.calledNames) {
      final MethodDeclaration? callee = methodsByName[calledName];
      if (callee != null && !visited.contains(calledName)) {
        pending.add(callee);
      }
    }
  }

  return reached;
}

/// True when [predicate] holds for [start]'s body or the body of any same-class
/// method reachable from it (see [reachableSameClassMethods]).
///
/// Use this to make an absence-of-cleanup rule follow teardown into a helper:
/// pass the method that should own cleanup (usually `dispose()`) as [start] and
/// a predicate that recognizes the cleanup call.
bool anyReachableBody(
  MethodDeclaration start,
  ClassDeclaration classNode,
  bool Function(FunctionBody body) predicate,
) {
  for (final MethodDeclaration method in reachableSameClassMethods(
    start,
    classNode,
  )) {
    if (predicate(method.body)) return true;
  }
  return false;
}

/// Collects the names of same-class methods invoked within a body: a
/// receiver-less call (`_teardown()`) or a `this.`-prefixed call
/// (`this._teardown()`) whose name is one of the class's own methods.
///
/// A call through any other receiver (`helper.run()`, `widget.foo()`) is not a
/// same-class dispatch and is deliberately ignored — following it would need the
/// element model and could leave the current class entirely.
class _SameClassCallCollector extends RecursiveAstVisitor<void> {
  _SameClassCallCollector(Iterable<String> classMethodNames)
    : _classMethodNames = classMethodNames.toSet();

  final Set<String> _classMethodNames;
  final Set<String> calledNames = <String>{};

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final Expression? target = node.target;
    final bool sameClassReceiver = target == null || target is ThisExpression;
    if (sameClassReceiver && _classMethodNames.contains(node.methodName.name)) {
      calledNames.add(node.methodName.name);
    }
    // Recurse so calls nested in arguments, closures, and control flow are seen.
    super.visitMethodInvocation(node);
  }
}
