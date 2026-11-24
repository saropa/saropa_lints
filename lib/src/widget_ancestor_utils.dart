/// Syntactic helpers shared by widget rules that need to know WHERE a widget
/// sits (marker tap target, dialog/popup, non-scrolling list).
///
/// Everything here is name-based on the AST so it behaves identically on
/// resolved analyzer runs (`InstanceCreationExpression`) and on the
/// unresolved `scan` CLI / unit-test harness (`MethodInvocation` for bare
/// `Foo(...)` calls). One home for these literals keeps the rules that share
/// them (focus, hover, cursor, refresh, scroll-controller) in agreement.
library;

import 'package:analyzer/dart/ast/ast.dart';

/// Returns the widget/constructor name for [node] in either AST shape, or
/// null when [node] is neither a constructor call nor a method-style call.
///
/// Why both shapes: before resolution `Foo(...)` parses as a
/// [MethodInvocation]; after resolution it is an [InstanceCreationExpression].
String? widgetCallName(AstNode node) {
  if (node is InstanceCreationExpression) {
    return node.constructorName.type.name.lexeme;
  }
  if (node is MethodInvocation) {
    final Expression? target = node.target;
    // `Foo.named(...)` unresolved: the class is the target identifier.
    // Review fix: only a type-shaped target (UpperCamel) with a lowercase
    // method is a named constructor; `marker.copy(...)` or `helper.build()`
    // are ordinary calls and must not be read as widgets.
    if (target is SimpleIdentifier) {
      final String t = target.name;
      final bool typeShaped =
          t.isNotEmpty &&
          t[0] == t[0].toUpperCase() &&
          t[0] != t[0].toLowerCase();
      return typeShaped ? t : null;
    }
    if (target == null) return node.methodName.name;
  }
  return null;
}

/// Argument list of a constructor call or method-style call, else null.
ArgumentList? widgetArguments(AstNode node) {
  if (node is InstanceCreationExpression) return node.argumentList;
  if (node is MethodInvocation) return node.argumentList;
  return null;
}

/// Widgets whose subtree is a map marker (flutter_map `Marker`). Markers are
/// positioned tap targets on a touch map: no hover, focus or cursor chrome.
const Set<String> _markerWidgets = <String>{'Marker', 'AnimatedMarker'};

/// True when [node] is a tap target inside a map marker, or inside a
/// `Semantics(button: true, ...)` wrapper that already exposes the button
/// role.
///
/// Why: hover/focus/cursor lints exist for pointer-driven button chrome.
/// A marker tap target has none by design, and a parent Semantics button
/// already supplies the accessible role, so those lints are false positives.
bool isMarkerOrSemanticButtonTapTarget(AstNode node) {
  AstNode? current = node.parent;
  while (current != null) {
    final String? name = widgetCallName(current);
    if (name != null && _markerWidgets.contains(name)) return true;
    if (name == 'Semantics') {
      final ArgumentList? args = widgetArguments(current);
      if (args != null && _hasTrueNamedArg(args, 'button')) return true;
    }
    // Stop at the enclosing member: ancestors beyond it are unrelated code.
    if (current is MethodDeclaration || current is FunctionDeclaration) break;
    current = current.parent;
  }
  return false;
}

/// True when [args] contains `<name>: true`.
bool _hasTrueNamedArg(ArgumentList args, String name) {
  for (final Argument arg in args.arguments) {
    if (arg is NamedArgument && arg.name.lexeme == name) {
      final Expression value = arg.argumentExpression;
      return value is BooleanLiteral && value.value;
    }
  }
  return false;
}

/// True when the scrollable call's `physics:` argument is
/// `NeverScrollableScrollPhysics` (const/new/bare, any AST shape).
///
/// Why: such a list cannot scroll, so refresh/controller concerns do not
/// apply to it; the enclosing widget owns scrolling.
bool hasNeverScrollablePhysics(ArgumentList args) {
  for (final Argument arg in args.arguments) {
    if (arg is NamedArgument && arg.name.lexeme == 'physics') {
      final Expression value = arg.argumentExpression;
      final String? name = widgetCallName(value);
      if (name == 'NeverScrollableScrollPhysics') return true;
    }
  }
  return false;
}

/// Widgets that host a transient overlay (dialog, popup, sheet) whose list
/// content is local UI state, not a remote data feed.
const Set<String> _overlayWidgets = <String>{
  'AlertDialog',
  'Dialog',
  'SimpleDialog',
  'CupertinoAlertDialog',
  'CupertinoActionSheet',
  'PopupMenuButton',
  'BottomSheet',
  'DropdownButton',
  'DropdownMenu',
};

/// Calls that open a transient overlay; lists built in their builder belong
/// to the overlay.
const Set<String> _overlayOpeners = <String>{
  'showDialog',
  'showAdaptiveDialog',
  'showGeneralDialog',
  'showCupertinoDialog',
  'showModalBottomSheet',
  'showBottomSheet',
  'showMenu',
  'showCupertinoModalPopup',
};

/// True when [node] is built inside a dialog, popup, menu or bottom sheet.
///
/// Why: a list of local toggles in a dialog has nothing to pull-to-refresh
/// and no scroll position worth tracking.
bool isInsideTransientOverlay(AstNode node) {
  AstNode? current = node.parent;
  while (current != null) {
    final String? name = widgetCallName(current);
    if (name != null && _overlayWidgets.contains(name)) return true;
    if (current is MethodInvocation &&
        _overlayOpeners.contains(current.methodName.name)) {
      return true;
    }
    if (current is MethodDeclaration || current is FunctionDeclaration) break;
    current = current.parent;
  }
  return false;
}
