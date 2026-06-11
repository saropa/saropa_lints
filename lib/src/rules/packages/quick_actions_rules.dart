// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

/// quick_actions package lint rules.
///
/// Enforce the QuickActions initialization contract and valid ShortcutItem
/// construction so app shortcuts deliver their cold-start callbacks and render
/// correctly in the OS launcher menu.
library;

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

import '../../fixes/common/replace_node_fix.dart';
import '../../import_utils.dart';
import '../../saropa_lint_rule.dart';

/// quick_actions type whose receivers the initialization rules key on.
const String _quickActionsType = 'QuickActions';

/// quick_actions constructor the ShortcutItem-argument rules key on.
const String _shortcutItemType = 'ShortcutItem';

/// True when [target]'s resolved static type is the quick_actions
/// `QuickActions` class. Combined with [fileImportsPackage] this is the
/// type-safe receiver gate — never a bare-name match on the variable.
bool _isQuickActionsReceiver(Expression? target) =>
    target?.staticType?.element?.name == _quickActionsType;

/// Returns the value expression of the named argument [name] on an
/// `InstanceCreationExpression`, or null when the argument is absent.
Expression? _namedArg(InstanceCreationExpression node, String name) {
  for (final Expression arg in node.argumentList.arguments) {
    if (arg is NamedExpression && arg.name.label.name == name) {
      return arg.expression;
    }
  }
  return null;
}

/// Resolves the enclosing member body (method, top-level function, or
/// constructor) for [node]. Returning the OUTERMOST member body — not the
/// nearest closure — is load-bearing: it lets the ordering check see an
/// `initialize(...)` call that wraps `setShortcutItems` inside a `.then(...)`
/// callback, which lives in a nested function body of the same member.
FunctionBody? _enclosingMemberBody(AstNode node) {
  AstNode? current = node.parent;
  while (current != null) {
    if (current is MethodDeclaration) return current.body;
    if (current is FunctionDeclaration) {
      return current.functionExpression.body;
    }
    if (current is ConstructorDeclaration) return current.body;
    current = current.parent;
  }
  return null;
}

/// True for files under a `test/` directory or named `*_test.dart` — used to
/// suppress the class-scoped contract rule in tests that register shortcuts
/// without exercising the cold-start path.
bool _isTestFilePath(String path) {
  final String normalized = path.replaceAll('\\', '/');
  return normalized.endsWith('_test.dart') || normalized.contains('/test/');
}

/// Collects every [MethodInvocation] in a subtree. Shared by the two
/// initialization-contract rules so in-method ordering and class-wide presence
/// checks use identical traversal.
class _InvocationCollector extends RecursiveAstVisitor<void> {
  final List<MethodInvocation> invocations = <MethodInvocation>[];

  @override
  void visitMethodInvocation(MethodInvocation node) {
    invocations.add(node);
    super.visitMethodInvocation(node);
  }
}

// =============================================================================
// quick_actions_set_before_initialize
// =============================================================================

/// Flags `setShortcutItems(...)` invoked before `initialize(...)` on a
/// `QuickActions` instance within the same member.
///
/// Since: v4.16.0 | Rule version: v1
///
/// `initialize(handler)` opens the platform channel that delivers the
/// cold-start action. If `setShortcutItems` runs first, the OS shortcut list is
/// populated while the handler channel is still closed, so a cold-start tap is
/// silently discarded — the app opens but takes no action.
///
/// **BAD:**
/// ```dart
/// final qa = QuickActions();
/// qa.setShortcutItems(items); // handler not registered yet
/// qa.initialize(handler);
/// ```
///
/// **GOOD:**
/// ```dart
/// final qa = QuickActions();
/// await qa.initialize(handler);
/// await qa.setShortcutItems(items);
/// // or: qa.initialize(handler).then((_) => qa.setShortcutItems(items));
/// ```
class QuickActionsSetBeforeInitializeRule extends SaropaLintRule {
  QuickActionsSetBeforeInitializeRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.warning;

  @override
  RuleType? get ruleType => RuleType.bug;

  @override
  Set<String> get tags => const {'packages'};

  @override
  RuleCost get cost => RuleCost.low;

  // Perf: only walk members in files that actually call setShortcutItems.
  @override
  Set<String>? get requiredPatterns => const <String>{'setShortcutItems'};

  static const LintCode _code = LintCode(
    'quick_actions_set_before_initialize',
    '[quick_actions_set_before_initialize] QuickActions.setShortcutItems() is called before QuickActions.initialize() in the same member. initialize() opens the platform channel that delivers the cold-start action; if the OS launches the app from a shortcut tap before the handler is registered, the launch intent is silently discarded and the shortcut appears to do nothing. {v1}',
    correctionMessage:
        'Call initialize(handler) and let it complete before setShortcutItems(...) — await it first, or chain via initialize(handler).then((_) => setShortcutItems(...)).',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name != 'setShortcutItems') return;
      if (!fileImportsPackage(node, PackageImports.quickActions)) return;
      if (!_isQuickActionsReceiver(node.realTarget)) return;

      final FunctionBody? body = _enclosingMemberBody(node);
      if (body == null) return;

      final _InvocationCollector collector = _InvocationCollector();
      body.accept(collector);

      // A preceding initialize() on a QuickActions receiver (lower source
      // offset) satisfies the contract — including the
      // initialize(...).then((_) => setShortcutItems(...)) chain, where the
      // initialize call textually precedes the nested callback.
      final bool hasPrecedingInitialize = collector.invocations.any(
        (MethodInvocation inv) =>
            inv.methodName.name == 'initialize' &&
            _isQuickActionsReceiver(inv.realTarget) &&
            inv.offset < node.offset,
      );
      if (hasPrecedingInitialize) return;

      reporter.atNode(node);
    });
  }
}

// =============================================================================
// quick_actions_missing_initialize
// =============================================================================

/// Flags a class that calls `setShortcutItems(...)` on a `QuickActions`
/// instance but never calls `initialize(...)` anywhere in the class.
///
/// Since: v4.16.0 | Rule version: v1
///
/// Shortcuts appear in the launcher but, with no handler registered, a
/// cold-start tap opens the app to its default screen and the action is lost.
///
/// **BAD:**
/// ```dart
/// class _HomeState extends State<Home> {
///   final qa = QuickActions();
///   void setup() => qa.setShortcutItems(items); // no initialize anywhere
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// class _HomeState extends State<Home> {
///   final qa = QuickActions();
///   void setup() {
///     qa.initialize(_onShortcut);
///     qa.setShortcutItems(items);
///   }
/// }
/// ```
class QuickActionsMissingInitializeRule extends SaropaLintRule {
  QuickActionsMissingInitializeRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.warning;

  @override
  RuleType? get ruleType => RuleType.bug;

  @override
  Set<String> get tags => const {'packages'};

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<String>? get requiredPatterns => const <String>{'setShortcutItems'};

  static const LintCode _code = LintCode(
    'quick_actions_missing_initialize',
    '[quick_actions_missing_initialize] This class calls QuickActions.setShortcutItems() but never calls QuickActions.initialize(). Without a registered handler the shortcuts appear in the launcher, but a cold-start tap opens the app to its default screen and the intended action is silently dropped because the platform callback channel was never opened. {v1}',
    correctionMessage:
        'Call initialize(handler) early in the lifecycle (e.g. initState) of the same class that registers shortcuts, so cold-start taps are delivered to your handler.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addClassDeclaration((ClassDeclaration node) {
      if (!fileImportsPackage(node, PackageImports.quickActions)) return;
      // Tests often register shortcuts without exercising the cold-start path.
      if (_isTestFilePath(context.filePath)) return;

      final _InvocationCollector collector = _InvocationCollector();
      node.accept(collector);

      final List<MethodInvocation> setCalls = collector.invocations
          .where(
            (MethodInvocation inv) =>
                inv.methodName.name == 'setShortcutItems' &&
                _isQuickActionsReceiver(inv.realTarget),
          )
          .toList();
      if (setCalls.isEmpty) return;

      final bool hasInitialize = collector.invocations.any(
        (MethodInvocation inv) =>
            inv.methodName.name == 'initialize' &&
            _isQuickActionsReceiver(inv.realTarget),
      );
      if (hasInitialize) return;

      for (final MethodInvocation call in setCalls) {
        reporter.atNode(call);
      }
    });
  }
}

// =============================================================================
// quick_actions_empty_shortcut_type
// =============================================================================

/// Flags `ShortcutItem(type: '')` — an empty-string `type`.
///
/// Since: v4.16.0 | Rule version: v1
///
/// `type` is the identifier delivered to the `QuickActionHandler` callback. An
/// empty string means the callback receives `""`, which virtually no switch or
/// if-chain matches, so the cold-start tap silently does nothing.
///
/// **BAD:**
/// ```dart
/// ShortcutItem(type: '', localizedTitle: 'Search');
/// ```
///
/// **GOOD:**
/// ```dart
/// ShortcutItem(type: 'search', localizedTitle: 'Search');
/// ```
class QuickActionsEmptyShortcutTypeRule extends SaropaLintRule {
  QuickActionsEmptyShortcutTypeRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.warning;

  @override
  RuleType? get ruleType => RuleType.bug;

  @override
  Set<String> get tags => const {'packages'};

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<String>? get requiredPatterns => const <String>{_shortcutItemType};

  static const LintCode _code = LintCode(
    'quick_actions_empty_shortcut_type',
    '[quick_actions_empty_shortcut_type] ShortcutItem is constructed with an empty type string. The type value is delivered verbatim to the QuickActionHandler callback; an empty string matches no switch or if branch in a normal handler, so the shortcut launches the app but executes no action. The type should be a unique, non-empty identifier. {v1}',
    correctionMessage:
        'Give the ShortcutItem a unique, non-empty type that your handler branches on, e.g. type: "search".',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  List<SaropaFixGenerator> get fixGenerators => [
    ({required CorrectionProducerContext context}) =>
        _QuickActionsPlaceholderTypeFix(context: context),
  ];

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      if (node.constructorName.type.name.lexeme != _shortcutItemType) return;
      if (!fileImportsPackage(node, PackageImports.quickActions)) return;

      final Expression? typeArg = _namedArg(node, 'type');
      if (typeArg is! StringLiteral) return;
      // Only flag an explicitly empty literal; variables / interpolations
      // (stringValue == null) are out of scope.
      if (typeArg.stringValue?.isNotEmpty ?? true) return;

      reporter.atNode(typeArg);
    });
  }
}

/// Quick fix for [QuickActionsEmptyShortcutTypeRule]: replace the empty `type`
/// literal with a visible placeholder so the defect surfaces at runtime without
/// breaking compilation.
class _QuickActionsPlaceholderTypeFix extends ReplaceNodeFix {
  _QuickActionsPlaceholderTypeFix({required super.context});

  @override
  FixKind get fixKind => FixKind(
    'saropa.fix.quickActionsPlaceholderType',
    80,
    'Replace empty type with placeholder',
  );

  @override
  String computeReplacement(AstNode node) => "'action_placeholder'";
}

// =============================================================================
// quick_actions_empty_localized_title
// =============================================================================

/// Flags `ShortcutItem(localizedTitle: '')` — an empty-string title.
///
/// Since: v4.16.0 | Rule version: v1
///
/// `localizedTitle` is the user-visible label the OS shows in the shortcut
/// menu. An empty string renders a blank or suppressed entry.
///
/// **BAD:**
/// ```dart
/// ShortcutItem(type: 'search', localizedTitle: '');
/// ```
///
/// **GOOD:**
/// ```dart
/// ShortcutItem(type: 'search', localizedTitle: 'Search');
/// ```
class QuickActionsEmptyLocalizedTitleRule extends SaropaLintRule {
  QuickActionsEmptyLocalizedTitleRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.warning;

  @override
  RuleType? get ruleType => RuleType.bug;

  @override
  Set<String> get tags => const {'packages'};

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<String>? get requiredPatterns => const <String>{_shortcutItemType};

  static const LintCode _code = LintCode(
    'quick_actions_empty_localized_title',
    '[quick_actions_empty_localized_title] ShortcutItem is constructed with an empty localizedTitle string. localizedTitle is the user-visible label the OS renders in the app-shortcut menu; an empty value produces a blank or suppressed entry, a UX defect that never surfaces as a compile error because the field is only required to be present, not non-empty. {v1}',
    correctionMessage:
        'Provide a non-empty, localized label for localizedTitle so the shortcut renders a readable entry in the launcher menu.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      if (node.constructorName.type.name.lexeme != _shortcutItemType) return;
      if (!fileImportsPackage(node, PackageImports.quickActions)) return;

      final Expression? titleArg = _namedArg(node, 'localizedTitle');
      if (titleArg is! StringLiteral) return;
      if (titleArg.stringValue?.isNotEmpty ?? true) return;

      reporter.atNode(titleArg);
    });
  }
}

// =============================================================================
// quick_actions_flutter_asset_icon
// =============================================================================

/// Flags `ShortcutItem(icon: 'assets/...')` — a Flutter asset path where a
/// native resource name is required.
///
/// Since: v4.16.0 | Rule version: v1
///
/// `ShortcutItem.icon` expects a NATIVE asset name (an `xcassets` entry on iOS,
/// a `drawable` resource on Android), not a Flutter `assets/` bundle path. The
/// native shortcut renderer has no access to the Flutter asset bundle, so the
/// shortcut shows no icon.
///
/// **BAD:**
/// ```dart
/// ShortcutItem(type: 'search', localizedTitle: 'Search', icon: 'assets/icons/search.png');
/// ```
///
/// **GOOD:**
/// ```dart
/// ShortcutItem(type: 'search', localizedTitle: 'Search', icon: 'ic_search');
/// ```
class QuickActionsFlutterAssetIconRule extends SaropaLintRule {
  QuickActionsFlutterAssetIconRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.warning;

  @override
  RuleType? get ruleType => RuleType.bug;

  @override
  Set<String> get tags => const {'packages'};

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<String>? get requiredPatterns => const <String>{_shortcutItemType};

  static const LintCode _code = LintCode(
    'quick_actions_flutter_asset_icon',
    '[quick_actions_flutter_asset_icon] ShortcutItem.icon is set to a Flutter asset path (starts with assets/). The icon field expects a native resource name — an xcassets entry on iOS or a drawable resource on Android — because the OS shortcut renderer cannot read the Flutter asset bundle. A Flutter path produces a shortcut with no icon at runtime. {v1}',
    correctionMessage:
        'Use the native resource name (Android drawable name or iOS xcassets name), not a Flutter assets/ path, for ShortcutItem.icon.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      if (node.constructorName.type.name.lexeme != _shortcutItemType) return;
      if (!fileImportsPackage(node, PackageImports.quickActions)) return;

      final Expression? iconArg = _namedArg(node, 'icon');
      if (iconArg is! StringLiteral) return;
      final String? value = iconArg.stringValue;
      if (value == null || !value.startsWith('assets/')) return;

      reporter.atNode(iconArg);
    });
  }
}
