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
import 'package:analyzer/dart/ast/visitor.dart';

import 'analyzer_compat.dart';

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

/// Project wrappers around the framework openers (`showDialogCommon`,
/// `showAppBottomSheet`, `_showPickerMenu`). Apps rarely call `showDialog`
/// directly, so an exact-name list alone misses most real dialogs.
final RegExp _overlayWrapperName = RegExp(
  r'^_?show[A-Za-z0-9]*(?:Dialog|BottomSheet|Popup|Menu)[A-Za-z0-9]*$',
);

/// True when [node] sits in a private widget (or its `State`) that this file
/// only ever constructs inside a dialog, popup, menu or bottom sheet.
///
/// Why: [isInsideTransientOverlay] stops at the enclosing member, so a dialog
/// body extracted into its own widget class looked like a full screen. Only
/// private classes qualify, because every construction site of a public one
/// cannot be seen from a single file. A file with `part` directives is
/// skipped for the same reason.
bool isHostedOnlyInOverlay(AstNode node) {
  final ClassDeclaration? owner = node.thisOrAncestorOfType<ClassDeclaration>();
  final AstNode root = node.root;
  if (owner == null || root is! CompilationUnit) return false;
  if (root.directives.any((d) => d is PartDirective || d is PartOfDirective)) {
    return false;
  }

  final String widgetName = _hostWidgetName(owner);
  if (!widgetName.startsWith('_')) return false;

  final _UsageCollector usages = _UsageCollector(widgetName);
  root.accept(usages);

  // No visible construction proves nothing, so the lint stays. One use
  // outside an overlay means the list can also appear on a normal screen.
  return usages.sites.isNotEmpty && usages.sites.every(_isOverlayContent);
}

/// The widget [owner] renders for: `X` for `class _S extends State<X>` (and
/// `ConsumerState<X>`), otherwise the class itself.
String _hostWidgetName(ClassDeclaration owner) {
  final NamedType? superclass = owner.extendsClause?.superclass;
  if (superclass != null && superclass.name.lexeme.endsWith('State')) {
    final List<TypeAnnotation>? types = superclass.typeArguments?.arguments;
    if (types != null && types.length == 1) {
      final TypeAnnotation widget = types.first;
      if (widget is NamedType) return widget.name.lexeme;
    }
  }
  return owner.nameToken.lexeme;
}

/// True when the construction [site] is an argument (at any depth) of an
/// overlay widget or an overlay-opening call within the same member.
bool _isOverlayContent(AstNode site) {
  AstNode? current = site.parent;
  while (current != null) {
    final String? name = widgetCallName(current);
    if (name != null && _overlayWidgets.contains(name)) return true;
    if (current is MethodInvocation) {
      final String method = current.methodName.name;
      if (_overlayOpeners.contains(method) ||
          _overlayWrapperName.hasMatch(method)) {
        return true;
      }
    }
    if (current is MethodDeclaration || current is FunctionDeclaration) break;
    current = current.parent;
  }
  return false;
}

/// Collects every expression that constructs or references class [name], in
/// both resolved and unresolved AST shapes. Type annotations (`State<X>`) are
/// deliberately not usages.
class _UsageCollector extends RecursiveAstVisitor<void> {
  _UsageCollector(this.name);

  final String name;
  final List<AstNode> sites = <AstNode>[];

  /// Doc references (`[_X.field]`) parse as identifiers but build nothing;
  /// counting them would read documentation as a use outside the dialog.
  @override
  void visitComment(Comment node) {}

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    if (node.constructorName.type.name.lexeme == name) sites.add(node);
    super.visitInstanceCreationExpression(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    // Unresolved `_X()` has no target; `_X.named()` has `_X` as its target.
    final Expression? target = node.target;
    final bool bare = target == null && node.methodName.name == name;
    final bool named = target is SimpleIdentifier && target.name == name;
    if (bare || named) sites.add(node);
    super.visitMethodInvocation(node);
  }

  @override
  void visitPrefixedIdentifier(PrefixedIdentifier node) {
    // Tear-off (`_X.new`) or static access: the widget can escape from here.
    if (node.prefix.name == name) sites.add(node);
    super.visitPrefixedIdentifier(node);
  }

  @override
  void visitConstructorReference(ConstructorReference node) {
    // Resolved form of a constructor tear-off.
    if (node.constructorName.type.name.lexeme == name) sites.add(node);
    super.visitConstructorReference(node);
  }
}

/// True when the `itemCount:` in [args] is the length of a list that is
/// compile-time constant in this file (optionally plus or minus a header
/// offset).
///
/// Why: a constant list cannot change at runtime, so pull-to-refresh has
/// nothing to reload. Fields, parameters and `final` lists built at runtime
/// do not qualify: they can hold fetched data, which is what the rule targets.
bool isConstBackedList(ArgumentList args) {
  for (final Argument arg in args.arguments) {
    if (arg is! NamedArgument || arg.name.lexeme != 'itemCount') continue;
    Expression count = arg.argumentExpression;
    // `rows.length + 1` adds a fixed header/footer row to the same data.
    if (count is BinaryExpression && count.rightOperand is IntegerLiteral) {
      count = count.leftOperand;
    }
    if (count is PrefixedIdentifier && count.identifier.name == 'length') {
      return _isConstVariable(args, count.prefix.name);
    }
    // `Class.field.length` for a static const declared in this file.
    if (count is PropertyAccess && count.propertyName.name == 'length') {
      final Expression? target = count.target;
      if (target is PrefixedIdentifier) {
        return _isConstStaticField(args, target);
      }
    }
  }
  return false;
}

/// True when [name], looked up lexically from [from], is a constant variable.
/// The nearest declaration wins, so a parameter or local that shadows a
/// top-level constant is not mistaken for it.
bool _isConstVariable(AstNode from, String name) {
  AstNode? current = from.parent;
  while (current != null) {
    final FormalParameterList? parameters = switch (current) {
      FunctionExpression() => current.parameters,
      MethodDeclaration() => current.parameters,
      ConstructorDeclaration() => current.parameters,
      _ => null,
    };
    if (parameters != null &&
        parameters.parameters.any((p) => p.name?.lexeme == name)) {
      return false;
    }

    final List<VariableDeclarationList> lists = switch (current) {
      Block() => [
        for (final Statement s in current.statements)
          if (s is VariableDeclarationStatement) s.variables,
      ],
      ClassDeclaration() => [
        for (final ClassMember m in current.bodyMembers)
          if (m is FieldDeclaration) m.fields,
      ],
      CompilationUnit() => [
        for (final CompilationUnitMember m in current.declarations)
          if (m is TopLevelVariableDeclaration) m.variables,
      ],
      _ => const <VariableDeclarationList>[],
    };
    final bool? isConst = _constnessIn(lists, name);
    if (isConst != null) return isConst;

    current = current.parent;
  }
  // Declared elsewhere (import, superclass): unknown, so keep the lint.
  return false;
}

/// True when [access] (`Class.field`) names a constant static field of a
/// class declared in the same file as [from].
bool _isConstStaticField(AstNode from, PrefixedIdentifier access) {
  final AstNode root = from.root;
  if (root is! CompilationUnit) return false;
  for (final CompilationUnitMember member in root.declarations) {
    if (member is! ClassDeclaration) continue;
    if (member.nameToken.lexeme != access.prefix.name) continue;
    final List<VariableDeclarationList> statics = [
      for (final ClassMember m in member.bodyMembers)
        if (m is FieldDeclaration && m.isStatic) m.fields,
    ];
    return _constnessIn(statics, access.identifier.name) ?? false;
  }
  return false;
}

/// Constness of the variable [name] within [lists]; null when not declared.
/// `final x = const [...]` counts: neither the binding nor the list can change.
bool? _constnessIn(List<VariableDeclarationList> lists, String name) {
  for (final VariableDeclarationList list in lists) {
    for (final VariableDeclaration variable in list.variables) {
      if (variable.name.lexeme != name) continue;
      final Expression? value = variable.initializer;
      final bool constLiteral =
          value is TypedLiteral && value.constKeyword != null;
      return list.isConst || (list.isFinal && constLiteral);
    }
  }
  return null;
}
