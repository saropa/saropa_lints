// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

/// Scroll and list-related rules for Flutter applications.
///
/// These rules detect performance anti-patterns and common mistakes
/// related to scrollable widgets and lists.
library;

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

import '../saropa_lint_rule.dart';

/// Warns when shrinkWrap: true is used inside a ScrollView.
///
/// Since: v1.7.9 | Updated: v4.13.0 | Rule version: v6
///
/// Using shrinkWrap: true in a ListView inside another scrollable
/// disables virtualization, causing all items to be built immediately.
///
/// **BAD:**
/// ```dart
/// SingleChildScrollView(
///   child: Column(
///     children: [
///       ListView(
///         shrinkWrap: true, // Disables virtualization!
///         children: items,
///       ),
///     ],
///   ),
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// CustomScrollView(
///   slivers: [
///     SliverList(delegate: SliverChildListDelegate(items)),
///   ],
/// )
/// ```
class AvoidShrinkWrapInScrollViewRule extends SaropaLintRule {
  AvoidShrinkWrapInScrollViewRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'avoid_shrinkwrap_in_scrollview',
    '[avoid_shrinkwrap_in_scrollview] shrinkWrap: true on a scrollable list disables virtualization, forcing Flutter to lay out and render every child widget immediately regardless of visibility. This causes severe jank, high memory usage, and slow initial rendering for lists with more than a few dozen items, degrading the user experience. {v6}',
    correctionMessage:
        'Use CustomScrollView with SliverList for nested scrollables, or add NeverScrollableScrollPhysics() and let the parent scrollable manage scrolling behavior.',
    severity: DiagnosticSeverity.WARNING,
  );

  static const Set<String> _scrollableTypes = <String>{
    'ListView',
    'GridView',
    'SingleChildScrollView',
    'CustomScrollView',
  };

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    // Look for shrinkWrap: true arguments directly
    context.addNamedExpression((NamedExpression node) {
      if (node.name.label.name != 'shrinkWrap') return;

      final Expression value = node.expression;
      if (value is! BooleanLiteral || !value.value) return;

      // Check if this shrinkWrap is on a scrollable widget
      final AstNode? scrollableWidget = _findParentScrollable(node);
      if (scrollableWidget == null) return;

      // Skip if the scrollable has NeverScrollableScrollPhysics
      // Check the siblings of shrinkWrap for physics argument
      if (_hasNeverScrollablePhysicsInSiblings(node)) return;

      // Check if that scrollable is inside another scrollable
      if (_isInsideScrollable(scrollableWidget)) {
        reporter.atNode(node);
      }
    });
  }

  /// Check if sibling arguments include physics: NeverScrollableScrollPhysics()
  bool _hasNeverScrollablePhysicsInSiblings(NamedExpression shrinkWrapNode) {
    final AstNode? argumentList = shrinkWrapNode.parent;
    if (argumentList is! ArgumentList) return false;

    for (final Expression arg in argumentList.arguments) {
      if (arg is NamedExpression && arg.name.label.name == 'physics') {
        final Expression physicsValue = arg.expression;
        if (physicsValue is InstanceCreationExpression) {
          final String typeName =
              physicsValue.constructorName.type.name2.lexeme;
          if (typeName == 'NeverScrollableScrollPhysics') {
            return true;
          }
        }
      }
    }
    return false;
  }

  /// Find the parent scrollable widget (ListView, GridView, etc.)
  AstNode? _findParentScrollable(AstNode node) {
    AstNode? current = node.parent;
    while (current != null) {
      if (current is InstanceCreationExpression) {
        final String? typeName =
            current.constructorName.type.element?.name ?? _getTypeName(current);
        if (typeName != null && _scrollableTypes.contains(typeName)) {
          return current;
        }
      } else if (current is MethodInvocation) {
        // Handle implicit constructor calls
        final String methodName = current.methodName.name;
        if (_scrollableTypes.contains(methodName)) {
          return current;
        }
      }
      current = current.parent;
    }
    return null;
  }

  String? _getTypeName(InstanceCreationExpression node) {
    return node.constructorName.type.name2.lexeme;
  }

  bool _isInsideScrollable(AstNode node) {
    AstNode? current = node.parent;
    while (current != null) {
      if (current is InstanceCreationExpression) {
        final String? typeName =
            current.constructorName.type.element?.name ?? _getTypeName(current);
        if (typeName != null && _scrollableTypes.contains(typeName)) {
          return true;
        }
      } else if (current is MethodInvocation) {
        final String methodName = current.methodName.name;
        if (_scrollableTypes.contains(methodName)) {
          return true;
        }
      }
      current = current.parent;
    }
    return false;
  }
}

/// Warns when nested scrollables don't have explicit physics.
///
/// Since: v1.7.9 | Updated: v4.13.0 | Rule version: v3
///
/// Nested scrollable widgets cause gesture conflicts. The inner
/// scrollable should have NeverScrollableScrollPhysics to let the
/// outer one handle scrolling.
///
/// **BAD:**
/// ```dart
/// SingleChildScrollView(
///   child: ListView(...), // Conflicts with parent!
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// SingleChildScrollView(
///   child: ListView(
///     physics: NeverScrollableScrollPhysics(),
///     shrinkWrap: true,
///     ...
///   ),
/// )
/// ```
class AvoidNestedScrollablesConflictRule extends SaropaLintRule {
  AvoidNestedScrollablesConflictRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'avoid_nested_scrollables_conflict',
    '[avoid_nested_scrollables_conflict] Nested scrollable without explicit physics causes gesture conflicts. Nested scrollable widgets cause gesture conflicts. The inner scrollable must have NeverScrollableScrollPhysics to let the outer one handle scrolling. {v3}',
    correctionMessage:
        'Add physics: NeverScrollableScrollPhysics() to inner scrollable. Verify the change works correctly with existing tests and add coverage for the new behavior.',
    severity: DiagnosticSeverity.WARNING,
  );

  static const Set<String> _scrollableTypes = <String>{
    'ListView',
    'GridView',
    'SingleChildScrollView',
    'CustomScrollView',
    'PageView',
  };

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodDeclaration((MethodDeclaration node) {
      if (node.name.lexeme != 'build') return;
      node.body.visitChildren(
        _NestedScrollableVisitor(reporter, code, _scrollableTypes),
      );
    });
  }
}

class _NestedScrollableVisitor extends RecursiveAstVisitor<void> {
  _NestedScrollableVisitor(this.reporter, this.code, this.scrollableTypes);

  final SaropaDiagnosticReporter reporter;
  final LintCode code;
  final Set<String> scrollableTypes;

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    _checkScrollable(
      node,
      node.constructorName.type.name2.lexeme,
      node.argumentList,
    );
    super.visitInstanceCreationExpression(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    // Handle implicit constructor calls
    _checkScrollable(node, node.methodName.name, node.argumentList);
    super.visitMethodInvocation(node);
  }

  void _checkScrollable(AstNode node, String typeName, ArgumentList args) {
    if (!scrollableTypes.contains(typeName)) return;

    // Check if inside another scrollable
    if (!_isInsideScrollable(node)) return;

    // Check if physics is specified
    bool hasPhysics = false;
    for (final Expression arg in args.arguments) {
      if (arg is NamedExpression && arg.name.label.name == 'physics') {
        hasPhysics = true;
        break;
      }
    }

    if (!hasPhysics) {
      reporter.atNode(node);
    }
  }

  bool _isInsideScrollable(AstNode node) {
    AstNode? current = node.parent;
    while (current != null) {
      if (current is InstanceCreationExpression) {
        final String typeName = current.constructorName.type.name2.lexeme;
        if (scrollableTypes.contains(typeName)) {
          return true;
        }
      } else if (current is MethodInvocation) {
        if (scrollableTypes.contains(current.methodName.name)) {
          return true;
        }
      }
      current = current.parent;
    }
    return false;
  }
}

/// Warns when ListView uses children property with many items.
///
/// Since: v1.7.9 | Updated: v4.13.0 | Rule version: v2
///
/// `ListView(children: [...])` builds all children immediately.
/// For lists with more than 20 items, use ListView.builder for
/// better performance through virtualization.
///
/// **BAD:**
/// ```dart
/// ListView(
///   children: List.generate(100, (i) => ListTile(title: Text('$i'))),
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// ListView.builder(
///   itemCount: 100,
///   itemBuilder: (context, i) => ListTile(title: Text('$i')),
/// )
/// ```
class AvoidListViewChildrenForLargeListsRule extends SaropaLintRule {
  AvoidListViewChildrenForLargeListsRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'avoid_listview_children_for_large_lists',
    '[avoid_listview_children_for_large_lists] ListView with many children loads all items. Use ListView.builder. ListView(children: [..]) builds all children immediately. For lists with more than 20 items, use ListView.builder to improve performance through virtualization. {v2}',
    correctionMessage:
        'Replace ListView(children: [..]) with ListView.builder to improve performance. Verify the change works correctly with existing tests and add coverage for the new behavior.',
    severity: DiagnosticSeverity.WARNING,
  );

  static const int _maxChildrenCount = 20;

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      final String typeName = node.constructorName.type.name2.lexeme;

      if (typeName != 'ListView' && typeName != 'GridView') return;

      // Check if using default constructor (not .builder, .separated, etc.)
      final String? constructorName = node.constructorName.name?.name;
      if (constructorName != null) {
        return; // Using named constructor
      }

      // Check for children argument
      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression && arg.name.label.name == 'children') {
          final Expression value = arg.expression;
          if (value is ListLiteral &&
              value.elements.length > _maxChildrenCount) {
            reporter.atNode(node.constructorName, code);
          }
        }
      }
    });
  }
}

/// Warns when BottomNavigationBar has more than 5 items.
///
/// Since: v1.7.9 | Updated: v4.13.0 | Rule version: v3
///
/// More than 5 bottom navigation items crowds the UI and makes
/// tap targets too small for comfortable use.
///
/// **BAD:**
/// ```dart
/// BottomNavigationBar(
///   items: [item1, item2, item3, item4, item5, item6], // Too many!
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// BottomNavigationBar(
///   items: [item1, item2, item3, item4, item5], // Max 5
/// )
/// // Or use a Drawer for additional navigation
/// ```
class AvoidExcessiveBottomNavItemsRule extends SaropaLintRule {
  AvoidExcessiveBottomNavItemsRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'avoid_excessive_bottom_nav_items',
    '[avoid_excessive_bottom_nav_items] BottomNavigationBar with more than 5 items crowds the UI. More than 5 bottom navigation items crowds the UI and makes tap targets too small for comfortable use. {v3}',
    correctionMessage:
        'Limit to 5 items or use a navigation drawer for additional options. Verify the change works correctly with existing tests and add coverage for the new behavior.',
    severity: DiagnosticSeverity.INFO,
  );

  static const int _maxItems = 5;

  static const Set<String> _navTypes = <String>{
    'BottomNavigationBar',
    'NavigationBar',
  };

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    // Look for items/destinations arguments directly
    context.addNamedExpression((NamedExpression node) {
      final String argName = node.name.label.name;
      if (argName != 'items' && argName != 'destinations') return;

      // Check if the value is a list with too many items
      final Expression value = node.expression;
      if (value is! ListLiteral || value.elements.length <= _maxItems) return;

      // Check if this is on a nav bar widget
      if (_isOnNavBar(node)) {
        reporter.atNode(node);
      }
    });
  }

  bool _isOnNavBar(AstNode node) {
    AstNode? current = node.parent;
    while (current != null) {
      if (current is InstanceCreationExpression) {
        final String typeName = current.constructorName.type.name2.lexeme;
        if (_navTypes.contains(typeName)) return true;
      } else if (current is MethodInvocation) {
        if (_navTypes.contains(current.methodName.name)) return true;
      }
      current = current.parent;
    }
    return false;
  }
}

/// Warns when TabController length doesn't match TabBar children count.
///
/// Since: v1.7.9 | Updated: v4.13.0 | Rule version: v2
///
/// TabController length must exactly match the number of tabs.
/// Mismatches cause runtime errors.
///
/// **BAD:**
/// ```dart
/// TabController(length: 3, vsync: this);
/// TabBar(tabs: [tab1, tab2]); // Only 2 tabs!
/// ```
///
/// **GOOD:**
/// ```dart
/// TabController(length: 2, vsync: this);
/// TabBar(tabs: [tab1, tab2]);
/// ```
class RequireTabControllerLengthSyncRule extends SaropaLintRule {
  RequireTabControllerLengthSyncRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'require_tab_controller_length_sync',
    '[require_tab_controller_length_sync] TabController length mismatch '
        'throws RangeError when switching tabs, crashing the app. {v2}',
    correctionMessage: 'Ensure TabController length equals the number of tabs.',
    severity: DiagnosticSeverity.ERROR,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addClassDeclaration((ClassDeclaration node) {
      // Check if extends State<T>
      final ExtendsClause? extendsClause = node.extendsClause;
      if (extendsClause == null) return;

      final String superName = extendsClause.superclass.name.lexeme;
      if (superName != 'State') return;

      // Find TabController initialization
      int? controllerLength;
      int? tabBarTabCount;
      int? tabBarViewChildCount;

      final String classSource = node.toSource();

      // Look for TabController(length: N)
      final RegExp controllerPattern = RegExp(
        r'TabController\s*\(\s*length\s*:\s*(\d+)',
      );
      final Match? controllerMatch = controllerPattern.firstMatch(classSource);
      if (controllerMatch != null) {
        controllerLength = int.tryParse(controllerMatch.group(1) ?? '');
      }

      // Look for TabBar(tabs: [...])
      final RegExp tabBarPattern = RegExp(
        r'TabBar\s*\([^)]*tabs\s*:\s*\[([^\]]*)\]',
      );
      final Match? tabBarMatch = tabBarPattern.firstMatch(classSource);
      if (tabBarMatch != null) {
        // Count commas + 1 for number of items
        final String tabsContent = tabBarMatch.group(1) ?? '';
        if (tabsContent.trim().isNotEmpty) {
          tabBarTabCount = tabsContent
              .split(',')
              .where((s) => s.trim().isNotEmpty)
              .length;
        } else {
          tabBarTabCount = 0;
        }
      }

      // Look for TabBarView(children: [...])
      final RegExp tabBarViewPattern = RegExp(
        r'TabBarView\s*\([^)]*children\s*:\s*\[([^\]]*)\]',
      );
      final Match? tabBarViewMatch = tabBarViewPattern.firstMatch(classSource);
      if (tabBarViewMatch != null) {
        final String childrenContent = tabBarViewMatch.group(1) ?? '';
        if (childrenContent.trim().isNotEmpty) {
          tabBarViewChildCount = childrenContent
              .split(',')
              .where((s) => s.trim().isNotEmpty)
              .length;
        } else {
          tabBarViewChildCount = 0;
        }
      }

      // Check for mismatches
      if (controllerLength != null) {
        if (tabBarTabCount != null && controllerLength != tabBarTabCount) {
          reporter.atNode(node);
        }
        if (tabBarViewChildCount != null &&
            controllerLength != tabBarViewChildCount) {
          reporter.atNode(node);
        }
      }
    });
  }
}

/// Warns when RefreshIndicator onRefresh doesn't return Future.
///
/// Since: v1.7.9 | Updated: v4.13.0 | Rule version: v4
///
/// RefreshIndicator needs the onRefresh callback to return a Future
/// so it knows when to stop showing the loading indicator.
///
/// **BAD:**
/// ```dart
/// RefreshIndicator(
///   onRefresh: () {
///     loadData(); // Returns void!
///   },
///   child: ListView(...),
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// RefreshIndicator(
///   onRefresh: () async {
///     await loadData();
///   },
///   child: ListView(...),
/// )
/// ```
class AvoidRefreshWithoutAwaitRule extends SaropaLintRule {
  AvoidRefreshWithoutAwaitRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'avoid_refresh_without_await',
    '[avoid_refresh_without_await] RefreshIndicator onRefresh callback must return a Future that completes when data loading finishes. Without awaiting async operations, the refresh spinner dismisses immediately while data is still loading, leaving users confused about whether the refresh succeeded or failed and showing stale content. {v4}',
    correctionMessage:
        'Make the onRefresh callback async and await all asynchronous data-fetching operations so the refresh indicator stays visible until loading completes.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      final String typeName = node.constructorName.type.name2.lexeme;

      if (typeName != 'RefreshIndicator') return;

      // Check for onRefresh argument
      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression && arg.name.label.name == 'onRefresh') {
          final Expression value = arg.expression;
          if (value is FunctionExpression) {
            // Check if it's async
            final bool isAsync = value.body.isAsynchronous;
            if (!isAsync) {
              reporter.atNode(arg);
            }
          }
        }
      }
    });
  }
}

/// Warns when multiple widgets have autofocus: true.
///
/// Since: v1.7.9 | Updated: v4.13.0 | Rule version: v2
///
/// Only one widget can have autofocus at a time. Multiple autofocus
/// widgets cause unpredictable focus behavior.
///
/// Alias: autofocus
///
/// **BAD:**
/// ```dart
/// Column(
///   children: [
///     TextField(autofocus: true),
///     TextField(autofocus: true), // Which one gets focus?
///   ],
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// Column(
///   children: [
///     TextField(autofocus: true),
///     TextField(), // No autofocus
///   ],
/// )
/// ```
class AvoidMultipleAutofocusRule extends SaropaLintRule {
  AvoidMultipleAutofocusRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'avoid_multiple_autofocus',
    '[avoid_multiple_autofocus] Multiple widgets with autofocus: true causes unpredictable behavior. Only one widget can have autofocus at a time. Multiple autofocus widgets cause unpredictable focus behavior. {v2}',
    correctionMessage:
        'Only one widget must have autofocus: true. Verify the change works correctly with existing tests and add coverage for the new behavior.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodDeclaration((MethodDeclaration node) {
      if (node.name.lexeme != 'build') return;

      final String? returnType = node.returnType?.toSource();
      if (returnType != 'Widget') return;

      // Count autofocus: true occurrences
      final List<AstNode> autofocusNodes = <AstNode>[];
      node.body.visitChildren(_AutofocusVisitor(autofocusNodes));

      // Report all but the first one
      if (autofocusNodes.length > 1) {
        for (int i = 1; i < autofocusNodes.length; i++) {
          reporter.atNode(autofocusNodes[i], code);
        }
      }
    });
  }
}

class _AutofocusVisitor extends RecursiveAstVisitor<void> {
  _AutofocusVisitor(this.autofocusNodes);

  final List<AstNode> autofocusNodes;

  @override
  void visitNamedExpression(NamedExpression node) {
    if (node.name.label.name == 'autofocus') {
      final Expression value = node.expression;
      if (value is BooleanLiteral && value.value) {
        autofocusNodes.add(node);
      }
    }
    super.visitNamedExpression(node);
  }
}

/// Warns when ListView/GridView doesn't have RefreshIndicator.
///
/// Since: v2.0.0 | Updated: v4.13.0 | Rule version: v3
///
/// Pull-to-refresh is a standard mobile UX pattern. Lists with
/// dynamic content should support manual refresh.
///
/// **BAD:**
/// ```dart
/// ListView.builder(
///   itemCount: items.length,
///   itemBuilder: (ctx, i) => ListTile(title: Text(items[i])),
/// );
/// ```
///
/// **GOOD:**
/// ```dart
/// RefreshIndicator(
///   onRefresh: () => fetchItems(),
///   child: ListView.builder(
///     itemCount: items.length,
///     itemBuilder: (ctx, i) => ListTile(title: Text(items[i])),
///   ),
/// );
/// ```
class RequireRefreshIndicatorOnListsRule extends SaropaLintRule {
  RequireRefreshIndicatorOnListsRule() : super(code: _code);

  /// UX improvement - standard mobile pattern.
  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'require_refresh_indicator_on_lists',
    '[require_refresh_indicator_on_lists] ListView without RefreshIndicator. Users can\'t pull to refresh. Pull-to-refresh is a standard mobile UX pattern. Lists with dynamic content should support manual refresh. {v3}',
    correctionMessage:
        'Wrap with RefreshIndicator for pull-to-refresh support. Verify the change works correctly with existing tests and add coverage for the new behavior.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((node) {
      final typeName = node.constructorName.type.name.lexeme;

      if (!typeName.contains('ListView') && !typeName.contains('GridView')) {
        return;
      }

      // Check if already wrapped in RefreshIndicator
      AstNode? current = node.parent;
      while (current != null) {
        if (current is InstanceCreationExpression) {
          final parentType = current.constructorName.type.name.lexeme;
          if (parentType == 'RefreshIndicator') {
            return;
          }
        }
        // Stop at method boundary
        if (current is MethodDeclaration) {
          break;
        }
        current = current.parent;
      }

      // Check method/class for RefreshIndicator
      current = node.parent;
      while (current != null) {
        if (current is MethodDeclaration) {
          final methodSource = current.toSource();
          if (methodSource.contains('RefreshIndicator')) {
            return;
          }
          break;
        }
        current = current.parent;
      }

      reporter.atNode(node.constructorName, code);
    });
  }
}

/// Warns when shrinkWrap: true is used in scrollables (expensive operation).
///
/// Since: v2.3.7 | Updated: v4.13.0 | Rule version: v5
///
/// Using shrinkWrap: true forces the scrollable to calculate the size of all
/// its children immediately, disabling virtualization and causing performance
/// issues with large lists.
///
/// **BAD:**
/// ```dart
/// ListView(
///   shrinkWrap: true, // Forces all children to be built
///   children: items,
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// ListView.builder(
///   itemCount: items.length,
///   itemBuilder: (context, i) => items[i],
/// )
/// // Or use a SliverList in a CustomScrollView
/// ```
class AvoidShrinkWrapExpensiveRule extends SaropaLintRule {
  AvoidShrinkWrapExpensiveRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'avoid_shrink_wrap_expensive',
    '[avoid_shrink_wrap_expensive] shrinkWrap: true disables list virtualization, forcing Flutter to measure and lay out every item upfront instead of lazily building only visible items. For lists with many children, this causes slow initial rendering, high memory consumption, and jank during scrolling as the framework processes the entire list eagerly. {v5}',
    correctionMessage:
        'Use a fixed-height parent container, replace with CustomScrollView and Slivers, or reconsider the layout to avoid disabling list virtualization.',
    severity: DiagnosticSeverity.WARNING,
  );

  static const Set<String> _scrollableTypes = <String>{
    'ListView',
    'GridView',
    'SingleChildScrollView',
  };

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addNamedExpression((NamedExpression node) {
      if (node.name.label.name != 'shrinkWrap') return;

      final Expression value = node.expression;
      if (value is! BooleanLiteral || !value.value) return;

      // Check if this shrinkWrap is on a scrollable widget
      final scrollableNode = _findScrollableWidget(node);
      if (scrollableNode == null) return;

      // Skip if NeverScrollableScrollPhysics is used - this is intentional
      // for nested non-scrolling lists inside another scrollable
      if (_hasNeverScrollablePhysics(scrollableNode)) return;

      reporter.atNode(node);
    });
  }

  /// Finds the scrollable widget containing this shrinkWrap argument.
  AstNode? _findScrollableWidget(AstNode node) {
    AstNode? current = node.parent;
    while (current != null) {
      if (current is InstanceCreationExpression) {
        final String typeName = current.constructorName.type.name2.lexeme;
        if (_scrollableTypes.contains(typeName)) return current;
      } else if (current is MethodInvocation) {
        if (_scrollableTypes.contains(current.methodName.name)) return current;
      }
      // Stop at widget boundary (another widget or method declaration)
      if (current is MethodDeclaration) break;
      current = current.parent;
    }
    return null;
  }

  /// Checks if the scrollable widget has physics: NeverScrollableScrollPhysics.
  bool _hasNeverScrollablePhysics(AstNode scrollableNode) {
    ArgumentList? argList;

    if (scrollableNode is InstanceCreationExpression) {
      argList = scrollableNode.argumentList;
    } else if (scrollableNode is MethodInvocation) {
      argList = scrollableNode.argumentList;
    }

    if (argList == null) return false;

    for (final arg in argList.arguments) {
      if (arg is NamedExpression && arg.name.label.name == 'physics') {
        final source = arg.expression.toSource().toLowerCase();
        if (source.contains('neverscrollablescrollphysics')) {
          return true;
        }
      }
    }
    return false;
  }
}

/// Warns when ListView with uniform items doesn't specify itemExtent.
///
/// Since: v2.3.7 | Updated: v4.13.0 | Rule version: v3
///
/// When all items have the same height, specifying itemExtent improves
/// scroll performance by avoiding per-item layout calculations.
///
/// **BAD:**
/// ```dart
/// ListView.builder(
///   itemCount: 100,
///   itemBuilder: (context, i) => ListTile(...), // All same height
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// ListView.builder(
///   itemCount: 100,
///   itemExtent: 56.0, // Standard ListTile height
///   itemBuilder: (context, i) => ListTile(...),
/// )
/// ```
class PreferItemExtentRule extends SaropaLintRule {
  PreferItemExtentRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'prefer_item_extent',
    '[prefer_item_extent] ListView without itemExtent recalculates layout on every scroll. When all items have the same height, specifying itemExtent improves scroll performance by avoiding per-item layout calculations. {v3}',
    correctionMessage:
        'Add itemExtent parameter if all items have the same height. Verify the change works correctly with existing tests and add coverage for the new behavior.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      final String typeName = node.constructorName.type.name2.lexeme;

      if (typeName != 'ListView') return;

      // Check if using builder constructor
      final String? constructorName = node.constructorName.name?.name;
      if (constructorName != 'builder' && constructorName != 'separated') {
        return;
      }

      // Check if itemExtent or prototypeItem is already specified
      bool hasItemExtent = false;
      bool hasPrototypeItem = false;

      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression) {
          final String argName = arg.name.label.name;
          if (argName == 'itemExtent') hasItemExtent = true;
          if (argName == 'prototypeItem') hasPrototypeItem = true;
        }
      }

      if (!hasItemExtent && !hasPrototypeItem) {
        reporter.atNode(node.constructorName, code);
      }
    });
  }
}

/// Warns when ListView doesn't use prototypeItem for consistent sizing.
///
/// Since: v2.3.7 | Updated: v4.13.0 | Rule version: v3
///
/// prototypeItem allows Flutter to determine item sizes from a single
/// prototype widget, which is more efficient than calculating each item.
///
/// **BAD:**
/// ```dart
/// ListView.builder(
///   itemCount: items.length,
///   itemBuilder: (context, i) => MyCard(items[i]),
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// ListView.builder(
///   itemCount: items.length,
///   prototypeItem: MyCard(items.first), // For consistent sizing
///   itemBuilder: (context, i) => MyCard(items[i]),
/// )
/// ```
class PreferPrototypeItemRule extends SaropaLintRule {
  PreferPrototypeItemRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'prefer_prototype_item',
    '[prefer_prototype_item] ListView.builder without prototypeItem measures each child separately. prototypeItem allows Flutter to determine item sizes from a single prototype widget, which is more efficient than calculating each item. {v3}',
    correctionMessage:
        'Add prototypeItem parameter if items have consistent dimensions. Verify the change works correctly with existing tests and add coverage for the new behavior.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      final String typeName = node.constructorName.type.name2.lexeme;

      if (typeName != 'ListView') return;

      // Check if using builder constructor
      final String? constructorName = node.constructorName.name?.name;
      if (constructorName != 'builder') return;

      // Check if prototypeItem or itemExtent is already specified
      bool hasPrototypeItem = false;
      bool hasItemExtent = false;

      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression) {
          final String argName = arg.name.label.name;
          if (argName == 'prototypeItem') hasPrototypeItem = true;
          if (argName == 'itemExtent') hasItemExtent = true;
        }
      }

      if (!hasPrototypeItem && !hasItemExtent) {
        reporter.atNode(node.constructorName, code);
      }
    });
  }
}

/// Warns when ReorderableListView items don't have keys.
///
/// Since: v2.3.7 | Updated: v4.13.0 | Rule version: v3
///
/// ReorderableListView requires each item to have a unique key to properly
/// track items during reordering. Without keys, reordering will not work
/// correctly and may cause visual glitches or data corruption.
///
/// **BAD:**
/// ```dart
/// ReorderableListView(
///   children: items.map((item) => ListTile(
///     title: Text(item.name), // Missing key!
///   )).toList(),
///   onReorder: (old, new) => ...,
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// ReorderableListView(
///   children: items.map((item) => ListTile(
///     key: ValueKey(item.id),
///     title: Text(item.name),
///   )).toList(),
///   onReorder: (old, new) => ...,
/// )
/// ```
class RequireKeyForReorderableRule extends SaropaLintRule {
  RequireKeyForReorderableRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'require_key_for_reorderable',
    '[require_key_for_reorderable] Without unique keys, reordering fails '
        'silently or shows wrong items after drag-and-drop. {v3}',
    correctionMessage: 'Add a key parameter (e.g., ValueKey) to each item.',
    severity: DiagnosticSeverity.ERROR,
  );

  static const Set<String> _reorderableTypes = <String>{
    'ReorderableListView',
    'ReorderableList',
  };

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      final String typeName = node.constructorName.type.name2.lexeme;

      if (!_reorderableTypes.contains(typeName)) return;

      // Check for children argument or itemBuilder
      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression) {
          final String argName = arg.name.label.name;

          if (argName == 'children') {
            _checkChildrenForKeys(arg.expression, reporter);
          } else if (argName == 'itemBuilder') {
            _checkItemBuilderForKeys(arg.expression, reporter);
          }
        }
      }
    });
  }

  void _checkChildrenForKeys(
    Expression childrenExpr,
    SaropaDiagnosticReporter reporter,
  ) {
    if (childrenExpr is ListLiteral) {
      for (final CollectionElement element in childrenExpr.elements) {
        if (element is InstanceCreationExpression) {
          if (!_hasKeyArgument(element.argumentList)) {
            reporter.atNode(element);
          }
        }
      }
    } else if (childrenExpr is MethodInvocation) {
      // Check for .map(...).toList() pattern
      if (childrenExpr.methodName.name == 'toList') {
        final Expression? target = childrenExpr.target;
        if (target is MethodInvocation && target.methodName.name == 'map') {
          _checkMapCallback(target, reporter);
        }
      } else if (childrenExpr.methodName.name == 'map') {
        _checkMapCallback(childrenExpr, reporter);
      }
    }
  }

  void _checkMapCallback(
    MethodInvocation mapInvocation,
    SaropaDiagnosticReporter reporter,
  ) {
    if (mapInvocation.argumentList.arguments.isNotEmpty) {
      final Expression callback = mapInvocation.argumentList.arguments.first;
      if (callback is FunctionExpression) {
        _checkBuilderBodyForKey(callback.body, reporter);
      }
    }
  }

  void _checkItemBuilderForKeys(
    Expression builderExpr,
    SaropaDiagnosticReporter reporter,
  ) {
    if (builderExpr is FunctionExpression) {
      _checkBuilderBodyForKey(builderExpr.body, reporter);
    }
  }

  void _checkBuilderBodyForKey(
    FunctionBody body,
    SaropaDiagnosticReporter reporter,
  ) {
    if (body is ExpressionFunctionBody) {
      final Expression expr = body.expression;
      if (expr is InstanceCreationExpression) {
        if (!_hasKeyArgument(expr.argumentList)) {
          reporter.atNode(expr);
        }
      }
    } else if (body is BlockFunctionBody) {
      body.block.visitChildren(_ReturnKeyVisitor(reporter, code));
    }
  }

  bool _hasKeyArgument(ArgumentList args) {
    for (final Expression arg in args.arguments) {
      if (arg is NamedExpression && arg.name.label.name == 'key') {
        return true;
      }
    }
    return false;
  }
}

class _ReturnKeyVisitor extends RecursiveAstVisitor<void> {
  _ReturnKeyVisitor(this.reporter, this.code);

  final SaropaDiagnosticReporter reporter;
  final LintCode code;

  @override
  void visitReturnStatement(ReturnStatement node) {
    final Expression? expr = node.expression;
    if (expr is InstanceCreationExpression) {
      bool hasKey = false;
      for (final Expression arg in expr.argumentList.arguments) {
        if (arg is NamedExpression && arg.name.label.name == 'key') {
          hasKey = true;
          break;
        }
      }
      if (!hasKey) {
        reporter.atNode(expr);
      }
    }
    super.visitReturnStatement(node);
  }
}

/// Warns when long lists have addAutomaticKeepAlives enabled (default).
///
/// Since: v2.3.7 | Updated: v4.13.0 | Rule version: v3
///
/// addAutomaticKeepAlives: true (the default) keeps list items alive in
/// memory even when scrolled off-screen. For long lists, this can cause
/// excessive memory usage. Set it to false for better memory efficiency.
///
/// **BAD:**
/// ```dart
/// ListView.builder(
///   itemCount: 1000, // Long list with automatic keep-alives
///   itemBuilder: (context, i) => ExpensiveWidget(items[i]),
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// ListView.builder(
///   itemCount: 1000,
///   addAutomaticKeepAlives: false, // Better memory usage
///   itemBuilder: (context, i) => ExpensiveWidget(items[i]),
/// )
/// ```
class RequireAddAutomaticKeepAlivesOffRule extends SaropaLintRule {
  RequireAddAutomaticKeepAlivesOffRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'require_add_automatic_keep_alives_off',
    '[require_add_automatic_keep_alives_off] Long lists with addAutomaticKeepAlives: true (default) can cause memory issues. addAutomaticKeepAlives: true (the default) keeps list items alive in memory even when scrolled off-screen. For long lists, this can cause excessive memory usage. Set it to false to improve memory efficiency. {v3}',
    correctionMessage:
        'Add addAutomaticKeepAlives: false to improve memory efficiency. Verify the change works correctly with existing tests and add coverage for the new behavior.',
    severity: DiagnosticSeverity.INFO,
  );

  static const Set<String> _listTypes = <String>{'ListView', 'GridView'};

  /// Threshold for considering a list "long"
  static const int _longListThreshold = 50;

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      final String typeName = node.constructorName.type.name2.lexeme;

      if (!_listTypes.contains(typeName)) return;

      // Check if using builder constructor (implies potentially large list)
      final String? constructorName = node.constructorName.name?.name;
      if (constructorName != 'builder') return;

      // Check arguments
      bool hasAddAutomaticKeepAlives = false;
      int? itemCount;

      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression) {
          final String argName = arg.name.label.name;
          if (argName == 'addAutomaticKeepAlives') {
            hasAddAutomaticKeepAlives = true;
          } else if (argName == 'itemCount') {
            final Expression countExpr = arg.expression;
            if (countExpr is IntegerLiteral) {
              itemCount = countExpr.value;
            }
          }
        }
      }

      // Only warn if itemCount is known and large, or if using builder pattern
      // (which typically implies dynamic/large lists)
      if (!hasAddAutomaticKeepAlives) {
        if (itemCount != null && itemCount >= _longListThreshold) {
          reporter.atNode(node.constructorName, code);
        }
      }
    });
  }
}

// =============================================================================
// QUICK FIXES
// =============================================================================

// =============================================================================
// prefer_sliverfillremaining_for_empty
// =============================================================================

/// Warns when empty state widgets in CustomScrollView are not wrapped in
/// SliverFillRemaining.
///
/// Since: v4.15.0 | Rule version: v1
///
/// When displaying empty state content (Center, "no items", "empty") inside
/// a CustomScrollView, you must wrap it in SliverFillRemaining so it fills
/// the remaining viewport space. Using SliverToBoxAdapter for empty states
/// results in the message sitting at the top of the scroll area rather than
/// being vertically centered.
///
/// **BAD:**
/// ```dart
/// CustomScrollView(
///   slivers: [
///     SliverToBoxAdapter(child: Center(child: Text('No items'))),
///   ],
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// CustomScrollView(
///   slivers: [
///     SliverFillRemaining(child: Center(child: Text('No items'))),
///   ],
/// )
/// ```
class PreferSliverFillRemainingForEmptyRule extends SaropaLintRule {
  PreferSliverFillRemainingForEmptyRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'prefer_sliverfillremaining_for_empty',
    '[prefer_sliverfillremaining_for_empty] Empty state widget in '
        'CustomScrollView uses SliverToBoxAdapter instead of '
        'SliverFillRemaining. The empty state content will sit at the top '
        'of the scroll area rather than being centered in the viewport. '
        'SliverFillRemaining expands to fill remaining space, giving a '
        'proper centered empty state experience. {v1}',
    correctionMessage:
        'Wrap empty state content in SliverFillRemaining instead of '
        'SliverToBoxAdapter for proper vertical centering.',
    severity: DiagnosticSeverity.INFO,
  );

  /// Keywords in child content that suggest an empty state.
  static const Set<String> _emptyStateIndicators = <String>{
    'empty',
    'no items',
    'no results',
    'nothing',
    'no data',
    'not found',
  };

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      final String typeName = node.constructorName.type.name.lexeme;
      if (typeName != 'SliverToBoxAdapter') return;

      // Check if child contains empty state indicators
      final String childSource = node.toSource().toLowerCase();

      bool hasEmptyIndicator = false;
      for (final String indicator in _emptyStateIndicators) {
        if (childSource.contains(indicator)) {
          hasEmptyIndicator = true;
          break;
        }
      }

      // Also check for Center wrapping text (common empty state)
      if (!hasEmptyIndicator) {
        if (childSource.contains('center(') && childSource.contains('text(')) {
          // Only flag if inside a CustomScrollView slivers list
          AstNode? current = node.parent;
          while (current != null) {
            if (current is InstanceCreationExpression) {
              final String parentType =
                  current.constructorName.type.name.lexeme;
              if (parentType == 'CustomScrollView') {
                hasEmptyIndicator = true;
                break;
              }
            }
            current = current.parent;
          }
        }
      }

      if (!hasEmptyIndicator) return;

      // Verify it's inside a CustomScrollView
      AstNode? current = node.parent;
      while (current != null) {
        if (current is InstanceCreationExpression) {
          final String parentType = current.constructorName.type.name.lexeme;
          if (parentType == 'CustomScrollView') {
            reporter.atNode(node.constructorName, code);
            return;
          }
        }
        current = current.parent;
      }
    });
  }
}

// =============================================================================
// avoid_infinite_scroll_duplicate_requests
// =============================================================================

/// Warns when scroll listeners load data without a loading guard.
///
/// Since: v4.15.0 | Rule version: v1
///
/// Infinite scroll implementations that trigger data loading from a scroll
/// listener without checking an `isLoading` flag will fire multiple
/// simultaneous requests as the user scrolls. This wastes bandwidth,
/// causes duplicate items, and may trigger API rate limits. Always check
/// a loading flag before requesting the next page.
///
/// **BAD:**
/// ```dart
/// _scrollController.addListener(() {
///   if (_scrollController.position.pixels >=
///       _scrollController.position.maxScrollExtent) {
///     loadNextPage();
///   }
/// });
/// ```
///
/// **GOOD:**
/// ```dart
/// _scrollController.addListener(() {
///   if (!_isLoading &&
///       _scrollController.position.pixels >=
///           _scrollController.position.maxScrollExtent) {
///     loadNextPage();
///   }
/// });
/// ```
class AvoidInfiniteScrollDuplicateRequestsRule extends SaropaLintRule {
  AvoidInfiniteScrollDuplicateRequestsRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'avoid_infinite_scroll_duplicate_requests',
    '[avoid_infinite_scroll_duplicate_requests] Scroll listener triggers '
        'data loading without a loading guard. When the user scrolls to the '
        'bottom, this fires multiple simultaneous requests because the '
        'listener fires continuously while at max extent. This wastes '
        'bandwidth, causes duplicate items in the list, and may trigger API '
        'rate limits. Check an isLoading flag before loading. {v1}',
    correctionMessage:
        'Add an isLoading/isFetching guard check before calling the load '
        'function in your scroll listener.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name != 'addListener') return;

      // Check if this is a scroll controller listener
      final String targetSource = node.target?.toSource() ?? '';
      if (!targetSource.contains('scroll') &&
          !targetSource.contains('Scroll') &&
          !targetSource.contains('controller') &&
          !targetSource.contains('Controller')) {
        return;
      }

      // Check callback body for maxScrollExtent without loading guard
      final NodeList<Expression> args = node.argumentList.arguments;
      if (args.isEmpty) return;

      final String callbackSource = args.first.toSource();
      if (!callbackSource.contains('maxScrollExtent')) return;

      // Check for loading guard patterns
      if (callbackSource.contains('isLoading') ||
          callbackSource.contains('_isLoading') ||
          callbackSource.contains('isFetching') ||
          callbackSource.contains('_isFetching') ||
          callbackSource.contains('loading') ||
          callbackSource.contains('hasMore') ||
          callbackSource.contains('_hasMore')) {
        return; // Has loading guard, OK
      }

      reporter.atNode(node);
    });
  }
}

// =============================================================================
// prefer_infinite_scroll_preload
// =============================================================================

/// Warns when infinite scroll triggers loading only at 100% scroll extent.
///
/// Since: v4.15.0 | Rule version: v1
///
/// Loading the next page only when the user reaches the very bottom of the
/// list causes a visible pause while data loads. Preload the next page at
/// 70-80% scroll progress so content is ready before the user reaches the
/// end. This creates a seamless infinite scroll experience.
///
/// **BAD:**
/// ```dart
/// if (position.pixels == position.maxScrollExtent) {
///   loadNextPage();
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// if (position.pixels >= position.maxScrollExtent * 0.8) {
///   loadNextPage();
/// }
/// ```
class PreferInfiniteScrollPreloadRule extends SaropaLintRule {
  PreferInfiniteScrollPreloadRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'prefer_infinite_scroll_preload',
    '[prefer_infinite_scroll_preload] Infinite scroll loads next page '
        'only at 100%% scroll extent. Users see a loading spinner and must '
        'wait for content. Preload the next page at 70-80%% scroll progress '
        'so data arrives before the user reaches the end. This creates a '
        'seamless experience without visible pauses. Use '
        'position.pixels >= position.maxScrollExtent * 0.8 as threshold. {v1}',
    correctionMessage:
        'Trigger loading at 70-80%% scroll extent (e.g., '
        'position.pixels >= position.maxScrollExtent * 0.8) instead of '
        'waiting for the exact bottom.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addBinaryExpression((BinaryExpression node) {
      final String source = node.toSource();

      // Detect exact equality check with maxScrollExtent
      if (!source.contains('maxScrollExtent')) return;

      // Check for == comparison (exact bottom check)
      if (node.operator.lexeme != '==' && node.operator.lexeme != '>=') {
        return;
      }

      // Only flag == (exact match), not >= (which may use threshold)
      if (node.operator.lexeme == '>=') {
        // If using >=, check that it's not multiplied by a threshold
        if (source.contains('*') || source.contains('- ')) {
          return; // Has threshold, OK
        }
        // >= maxScrollExtent without threshold is same as ==
      }

      if (node.operator.lexeme == '==') {
        // pixels == maxScrollExtent — always a problem
      }

      // Verify it's in a scroll listener context
      AstNode? current = node.parent;
      while (current != null) {
        if (current is FunctionBody) {
          final String bodySource = current.toSource();
          if (bodySource.contains('addListener') ||
              bodySource.contains('onNotification') ||
              bodySource.contains('ScrollNotification')) {
            reporter.atNode(node);
            return;
          }
          break;
        }
        current = current.parent;
      }
    });
  }
}
