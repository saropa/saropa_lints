import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/element.dart';

import '../../saropa_lint_rule.dart';

/// Flags a method tear-off (`final callback = someVar.method;`) whose
/// receiver is a non-`final` local variable, field, or parameter.
///
/// Since: v14.4.0 | Updated: v14.4.0 | Rule version: v2
///
/// A tear-off captures the *object* the receiver holds at the moment the
/// tear-off is taken, not a live reference to "whatever the receiver holds
/// now". If the receiver is later reassigned, code that reads the receiver
/// directly sees the new value, but a stored tear-off silently keeps
/// calling the method on the OLD object — it looks like a live binding but
/// is not one. This is a common source of stale-callback bugs in
/// controller/notifier patterns where a field is swapped out (hot-reload,
/// re-initialization, dependency injection re-wiring) after a tear-off was
/// already handed to a listener.
///
/// This rule is flow-insensitive: it flags based on the receiver's
/// declared mutability (`final` vs not) at the tear-off site, not on
/// whether the receiver is provably never reassigned again afterward.
/// A non-`final` receiver that happens to never be reassigned again is
/// still flagged — narrowing that away would require full data-flow
/// analysis, which is out of scope for this check.
///
/// A tear-off is only in scope when it is actually STORED somewhere it
/// outlives the current expression: a variable/field initializer, a plain
/// or compound (`??=`) assignment, a constructor initializer-list
/// assignment, a `return`/arrow-body expression, or an element of a
/// list/set/map/record literal. A tear-off used only as a one-shot call
/// argument (`list.forEach(mutableVar.method)`) is deliberately excluded —
/// it is never retained past the call, so it carries no staleness risk.
///
/// Out of scope for v1 (documented, not silently missed): chained
/// receivers (`obj.field.method`) and a tear-off passed as a named
/// argument to a call that itself retains it beyond one shot (e.g. a
/// constructor argument stored into a field elsewhere) — both would
/// require walking further up the call graph than a single-node check
/// supports.
///
/// **BAD:**
/// ```dart
/// class Controller {
///   Handler handler = Handler();
///   late final VoidCallback onTap = handler.handleTap; // tear-off from mutable field
///
///   void swapHandler(Handler next) {
///     handler = next; // onTap still calls the OLD handler's handleTap
///   }
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// class Controller {
///   final Handler handler = Handler(); // final receiver, tear-off is safe
///   late final VoidCallback onTap = handler.handleTap;
/// }
/// ```
///
/// **GOOD:** a receiver reached through a hand-written getter is never
/// flagged. The rule cannot see through an arbitrary getter body to decide
/// whether it returns a stable object, so per its "skip when uncertain"
/// doctrine it stays silent — this is the mainstream private-field +
/// public-getter encapsulation idiom and flagging it was a false positive.
/// ```dart
/// class Controller {
///   final Handler _handler = Handler();
///   Handler get handler => _handler; // read-only getter, no setter
///   late final VoidCallback onTap = handler.handleTap; // not flagged
/// }
/// ```
class MutableTearoffRule extends SaropaLintRule {
  MutableTearoffRule() : super(code: _code);

  /// A stored tear-off from a mutable receiver silently goes stale on
  /// reassignment — a real correctness bug, not merely a style nit.
  @override
  LintImpact get impact => LintImpact.warning;

  @override
  RuleType? get ruleType => RuleType.bug;

  @override
  Set<String> get tags => const {'correctness'};

  // Requires resolving the receiver's declaration element and the torn-off
  // member's element to distinguish a method tear-off from a plain field/
  // getter read, so this cannot be trivial/low cost.
  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'mutable_tearoff',
    '[mutable_tearoff] This method tear-off is taken from a non-final '
        'receiver, so it captures the object the receiver holds right now, '
        'not a live reference that tracks future reassignments. If the '
        'receiver is reassigned later, this stored tear-off keeps silently '
        'calling the method on the old object while the rest of the code '
        'reads the receiver directly and sees the new value — a stale-'
        'callback bug that is easy to introduce and hard to notice, '
        'especially in controller/notifier patterns where a field is '
        'swapped out after the tear-off was already handed to a listener. '
        '{v2}',
    correctionMessage:
        'Make the receiver final so the tear-off is guaranteed to stay '
        'bound to the same object, or replace the stored tear-off with a '
        'wrapper closure (`() => receiver.method()`) that re-reads the '
        'receiver on every call.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addPrefixedIdentifier((PrefixedIdentifier node) {
      // Only a tear-off that is actually STORED (assigned to a variable or
      // field, or reassigned to an existing one) is a staleness risk. A
      // tear-off passed directly as a one-shot call argument (e.g.
      // `list.forEach(mutableVar.method)`) is not retained past the call,
      // so it is deliberately out of scope (see proposal's "Alternatives
      // Considered").
      if (!_isStored(node)) return;

      // Resolve the torn-off member. Conservative: if resolution fails,
      // skip rather than guess (false-positive doctrine).
      final Element? memberElement = node.identifier.element;
      if (memberElement == null) return;

      // Only a genuine METHOD tear-off is in scope. A field or getter read
      // (`handler.onTapCallback`) re-reads the receiver's current field
      // value on every access — the receiver itself is what may be stale,
      // which is a different (and already-covered-elsewhere) concern.
      if (memberElement is! MethodElement) return;

      // Resolve the receiver. Conservative skip on unresolved elements —
      // this also naturally excludes import prefixes (`math.min`), which
      // resolve to a PrefixElement, not a variable/field/parameter.
      final Element? receiverElement = node.prefix.element;
      if (receiverElement == null) return;

      if (!_isMutableReceiver(receiverElement)) return;

      reporter.atNode(node);
    });
  }

  /// True when [node] is retained past the current statement/expression —
  /// a variable/field initializer (`final x = ...`, including field
  /// declarations, which share the same [VariableDeclaration] shape), an
  /// assignment to an existing variable/field (`x = ...` or `x ??= ...`,
  /// both parse as [AssignmentExpression] regardless of operator), a
  /// constructor initializer-list assignment (`C() : x = handler.method;`),
  /// a value handed back to the caller (`return handler.method;` or the
  /// arrow-bodied equivalent), or an element of a collection/record literal
  /// (`[handler.method]`, `{k: handler.method}`, `(handler.method,)`) —
  /// all of these keep the tear-off alive at least as long as the
  /// container that holds it, which is the same staleness risk a direct
  /// assignment carries.
  bool _isStored(PrefixedIdentifier node) {
    final AstNode? parent = node.parent;

    if (parent is VariableDeclaration && parent.initializer == node) {
      return true;
    }
    if (parent is AssignmentExpression && parent.rightHandSide == node) {
      return true;
    }
    if (parent is ConstructorFieldInitializer && parent.expression == node) {
      // `Controller() : onTap = handler.handleTap;` — stores the tear-off
      // into a field via the initializer list, same risk as a field
      // initializer or plain assignment.
      return true;
    }
    if (parent is ReturnStatement && parent.expression == node) {
      // `return handler.handleTap;` hands the tear-off to the caller,
      // which is free to store it — the staleness risk moves with it.
      return true;
    }
    if (parent is ExpressionFunctionBody && parent.expression == node) {
      // `VoidCallback getCallback() => handler.handleTap;` — the
      // arrow-bodied equivalent of a return statement.
      return true;
    }
    if (parent is ListLiteral || parent is SetOrMapLiteral) {
      // A direct element of `[...]` or `{...}` (set form) — retained as
      // long as the collection itself.
      return true;
    }
    if (parent is MapLiteralEntry &&
        (parent.value == node || parent.key == node)) {
      // Either side of `key: value` in a map literal. The KEY side matters
      // too: `{handler.handleTap: 'label'}` retains the tear-off for the
      // life of the map exactly as the value side does (and, being a key,
      // it is additionally hashed by identity — a stale tear-off there
      // silently fails lookups). Checking only `parent.value` missed it.
      return true;
    }
    if (parent is RecordLiteral) {
      // Positional record field: `(handler.handleTap,)`.
      return true;
    }
    if (parent is NamedExpression &&
        parent.expression == node &&
        parent.parent is RecordLiteral) {
      // Named record field: `(named: handler.handleTap,)`. Deliberately
      // NOT true for a named expression whose parent is an argument list
      // (`fn(named: handler.handleTap)`) — that shape is a call argument,
      // out of scope per the "Alternatives Considered" one-shot exclusion,
      // unless the call itself is not one-shot (already out of scope for
      // v1; see the rule's dartdoc "Known limitation").
      return true;
    }

    return false;
  }

  /// True when [element] is a local variable, field, or parameter that is
  /// NOT `final`/`const` — i.e. its binding can change after the tear-off
  /// is taken. Any other element kind (top-level function, import prefix,
  /// class/type, unresolved) is conservatively treated as not mutable so
  /// the rule never guesses.
  ///
  /// An unqualified (or `this.`-qualified) field reference resolves to its
  /// SYNTHETIC getter, not directly to a [FieldElement] — so a
  /// variable-induced [PropertyAccessorElement] (analyzer 12's split
  /// element model) is unwrapped to the underlying
  /// [PropertyInducingElement], which is where `isFinal` actually lives.
  /// A NON-synthetic (hand-written) getter is
  /// deliberately NOT unwrapped and never treated as mutable; see the
  /// inline comment on that branch for why unwrapping it produced a false
  /// positive on every read-only getter.
  bool _isMutableReceiver(Element element) {
    if (element is LocalVariableElement) {
      return !element.isFinal && !element.isConst;
    }
    if (element is FormalParameterElement) {
      // Dart parameters are mutable by default unless declared `final`.
      return !element.isFinal;
    }
    if (element is FieldElement) {
      return !element.isFinal && !element.isConst;
    }
    if (element is PropertyAccessorElement) {
      // ONLY a SYNTHETIC (variable-induced) accessor may be unwrapped.
      // `isOriginVariable` is analyzer 12's spelling for "this accessor was
      // induced by a real FieldElement / TopLevelVariableElement" — note
      // `Element.isSynthetic` no longer exists in this element model, so
      // the origin flags are the supported way to ask. When it is true,
      // `element.variable` is that genuine variable and its
      // `isFinal`/`isConst` describe the actual declaration — exactly the
      // mutability this rule cares about.
      //
      // Any other origin is NOT unwrappable. The important case is
      // `isOriginDeclaration` — a hand-written getter
      // (`Handler get handler => _handler;`). There the relationship is
      // inverted: the ACCESSOR is real and `element.variable` is a
      // synthetic PropertyInducingElement standing in for it, whose
      // `isFinal` is ALWAYS false no matter what the getter body returns.
      // Unwrapping it therefore reported every read-only getter as a
      // "mutable receiver" — a confirmed false positive on the mainstream
      // private-field + public-getter encapsulation idiom:
      //
      //   final Handler _handler = Handler();   // truly final
      //   Handler get handler => _handler;      // read-only getter
      //   late final VoidCallback onTap = handler.handleTap; // was flagged
      //
      // The rule cannot know whether an arbitrary getter body returns a
      // stable object without whole-body data-flow analysis, so per this
      // rule's own "skip when uncertain" doctrine a real getter falls
      // through to the conservative `false` below and is never flagged.
      if (!element.isOriginVariable) return false;

      final PropertyInducingElement variable = element.variable;
      return !variable.isFinal && !variable.isConst;
    }
    return false;
  }
}
