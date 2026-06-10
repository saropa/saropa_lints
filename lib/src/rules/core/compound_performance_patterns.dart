/// Canonical table of compound (context-aware) Flutter performance patterns —
/// an expensive widget made costly by a parent that re-runs it every frame or
/// every scrolled item.
///
/// This is the SINGLE SOURCE OF TRUTH shared by two consumers, so the knowledge
/// "Opacity inside AnimatedBuilder is bad" lives in exactly one place:
/// - the lint rules in `compound_performance_rules.dart` report these as
///   editor diagnostics (one rule per widget/parent grouping);
/// - the Project Health `perf_gravity.dart` scanner sums [CompoundPerfPattern.weight]
///   per feature into a dashboard "gravity" score.
///
/// The two consumers differ only in what they do with a match (diagnose vs.
/// score); the detection facts — which widgets, which parents, the AST walk —
/// are defined here once.
library;

import 'package:analyzer/dart/ast/ast.dart';

/// Scrollable widgets that lazily build/scroll their children, so any per-child
/// offscreen-layer or filter cost recurs on every visible item as it scrolls.
const Set<String> kScrollableWidgets = <String>{
  'ListView',
  'GridView',
  'CustomScrollView',
  'PageView',
};

/// Widgets that rebuild their `builder` subtree on every animation frame.
const Set<String> kAnimatedRebuilders = <String>{'AnimatedBuilder'};

/// One "expensive widget inside a costly parent" pattern plus its gravity weight.
///
/// [weight] is a relative severity used only for the dashboard gravity score; it
/// is NOT a frame-time measurement. Higher = worse. The lint rules ignore the
/// weight (a diagnostic is binary) and use only [widget] / [parents].
class CompoundPerfPattern {
  const CompoundPerfPattern({
    required this.widget,
    required this.parents,
    required this.weight,
  });

  /// Type name of the costly child widget (e.g. `Opacity`).
  final String widget;

  /// Ancestor widget types that make [widget] a per-frame / per-item hazard.
  final Set<String> parents;

  /// Relative severity (dashboard scoring only). See class doc.
  final int weight;
}

/// The canonical pattern set, ordered worst-first so a first-match scan attributes
/// the heaviest applicable weight when a widget could match more than one parent.
const List<CompoundPerfPattern> kCompoundPerfPatterns = <CompoundPerfPattern>[
  CompoundPerfPattern(
    widget: 'BackdropFilter',
    parents: kScrollableWidgets,
    weight: 100,
  ),
  CompoundPerfPattern(
    widget: 'ShaderMask',
    parents: kScrollableWidgets,
    weight: 87,
  ),
  CompoundPerfPattern(
    widget: 'ImageFiltered',
    parents: kScrollableWidgets,
    weight: 87,
  ),
  CompoundPerfPattern(
    widget: 'ClipPath',
    parents: kAnimatedRebuilders,
    weight: 62,
  ),
  CompoundPerfPattern(
    widget: 'Opacity',
    parents: kAnimatedRebuilders,
    weight: 50,
  ),
  CompoundPerfPattern(
    widget: 'Opacity',
    parents: kScrollableWidgets,
    weight: 50,
  ),
  CompoundPerfPattern(
    widget: 'ColorFiltered',
    parents: kScrollableWidgets,
    weight: 50,
  ),
];

/// Simple type name of a widget construction, resolving the element name when
/// available (IDE / `dart analyze`) and falling back to the syntactic identifier
/// when the tree is unresolved (`parseString` — the scan and health CLIs). Without
/// the fallback the detectors would silently no-op under those CLIs.
String? widgetConstructionName(InstanceCreationExpression node) =>
    node.constructorName.type.element?.name ??
    node.constructorName.type.name.lexeme;

/// Walks ancestors of [node] for a widget whose type is in [parentTypes];
/// returns the matched type name, or null if none is found.
///
/// Handles both AST forms a parent widget takes: an [InstanceCreationExpression]
/// (`ListView(...)`, named constructors like `ListView.builder(...)` in resolved
/// trees) and a target-less [MethodInvocation] (the same calls in an unresolved
/// tree). Checking both makes detection identical in the IDE and the CLIs.
String? enclosingWidgetOfType(AstNode node, Set<String> parentTypes) {
  AstNode? current = node.parent;
  while (current != null) {
    if (current is InstanceCreationExpression) {
      final String? name = widgetConstructionName(current);
      if (name != null && parentTypes.contains(name)) {
        return name;
      }
    } else if (current is MethodInvocation) {
      final Expression? target = current.target;
      // `ListView.builder(...)` — the scrollable is the target identifier.
      if (target is SimpleIdentifier && parentTypes.contains(target.name)) {
        return target.name;
      }
      // `ListView(...)` parsed without resolution — the method name is the type.
      if (parentTypes.contains(current.methodName.name)) {
        return current.methodName.name;
      }
    }
    current = current.parent;
  }
  return null;
}
