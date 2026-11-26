/// Detects whether an expression actually references a function parameter.
///
/// Used by `avoid_path_traversal` and `require_file_path_sanitization` to
/// decide whether a parameter reaches a `File` / `Directory` path. Both rules
/// once matched the parameter's name against source text, which reported
/// `appDir.path` for an unused parameter named `path`.
library;

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';

/// Returns true if [expression] contains a real reference to [parameter].
///
/// These callers are security rules, so the test is deliberately lenient about
/// what counts as a reference: any use of the parameter (bare, receiver of a
/// member, call argument, index target) matches. Only identifiers that cannot
/// be the parameter are rejected: member names, shadowing locals, and text that
/// is not an identifier at all (string literal content).
bool expressionReferencesParameter(
  AstNode expression,
  FormalParameter parameter,
) {
  final String name = parameter.name?.lexeme ?? '';
  // An unnamed parameter cannot be referenced.
  if (name.isEmpty) return false;

  final _ParameterReferenceFinder finder = _ParameterReferenceFinder(
    name,
    parameter.declaredFragment?.element,
  );
  expression.accept(finder);
  return finder.isFound;
}

/// Walks an expression looking for an identifier that refers to one parameter.
class _ParameterReferenceFinder extends RecursiveAstVisitor<void> {
  _ParameterReferenceFinder(this._name, this._element);

  final String _name;

  /// Null when the unit is unresolved (syntactic scan).
  final Element? _element;

  bool isFound = false;

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    if (node.name != _name || _isMemberName(node)) return;

    // Element identity rejects a shadowing local. An identifier that has no
    // element (unresolved code) is still treated as the parameter, so missing
    // type information never silences a real traversal risk.
    final Element? referenced = node.element;
    if (referenced == null || _element == null || referenced == _element) {
      isFound = true;
    }
  }

  /// True when [node] names a member of some other object (`dir.path`,
  /// `this.path`, `box.path()`). Checked structurally because a member on a
  /// dynamic receiver has no element to compare.
  bool _isMemberName(SimpleIdentifier node) {
    final AstNode? parent = node.parent;
    if (parent is PropertyAccess) return parent.propertyName == node;
    if (parent is PrefixedIdentifier) return parent.identifier == node;
    // A target-less call (`path()`) can be a function-typed parameter, so only
    // a call with a receiver is a member name.
    return parent is MethodInvocation &&
        parent.methodName == node &&
        parent.realTarget != null;
  }
}
