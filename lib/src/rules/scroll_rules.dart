// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

/// Scroll and list-related rules for Flutter applications.
///
/// These rules detect performance anti-patterns and common mistakes
/// related to scrollable widgets and lists.
library;

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart' show DiagnosticSeverity;
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../saropa_lint_rule.dart';

/// Warns when shrinkWrap: true is used inside a ScrollView.
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
  const AvoidShrinkWrapInScrollViewRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_shrinkwrap_in_scrollview',
    problemMessage:
        '[avoid_shrinkwrap_in_scrollview] shrinkWrap: true disables virtualization. This forces all items to render immediately, causing jank and high memory usage with large lists.',
    correctionMessage:
        'Use CustomScrollView with slivers, or add NeverScrollableScrollPhysics.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  static const Set<String> _scrollableTypes = <String>{
    'ListView',
    'GridView',
    'SingleChildScrollView',
    'CustomScrollView',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    // Look for shrinkWrap: true arguments directly
    context.registry.addNamedExpression((NamedExpression node) {
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
        reporter.atNode(node, code);
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
  const AvoidNestedScrollablesConflictRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_nested_scrollables_conflict',
    problemMessage:
        '[avoid_nested_scrollables_conflict] Nested scrollable without explicit physics causes gesture conflicts.',
    correctionMessage:
        'Add physics: NeverScrollableScrollPhysics() to inner scrollable.',
    errorSeverity: DiagnosticSeverity.WARNING,
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
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodDeclaration((MethodDeclaration node) {
      if (node.name.lexeme != 'build') return;
      node.body.visitChildren(
          _NestedScrollableVisitor(reporter, code, _scrollableTypes));
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
        node, node.constructorName.type.name2.lexeme, node.argumentList);
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
      reporter.atNode(node, code);
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
  const AvoidListViewChildrenForLargeListsRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'avoid_listview_children_for_large_lists',
    problemMessage:
        '[avoid_listview_children_for_large_lists] ListView with many children loads all items. Use ListView.builder.',
    correctionMessage:
        'Replace ListView(children: [...]) with ListView.builder for better performance.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  static const int _maxChildrenCount = 20;

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry
        .addInstanceCreationExpression((InstanceCreationExpression node) {
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
  const AvoidExcessiveBottomNavItemsRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_excessive_bottom_nav_items',
    problemMessage:
        '[avoid_excessive_bottom_nav_items] BottomNavigationBar with more than 5 items crowds the UI.',
    correctionMessage:
        'Limit to 5 items or use a navigation drawer for additional options.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  static const int _maxItems = 5;

  static const Set<String> _navTypes = <String>{
    'BottomNavigationBar',
    'NavigationBar',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    // Look for items/destinations arguments directly
    context.registry.addNamedExpression((NamedExpression node) {
      final String argName = node.name.label.name;
      if (argName != 'items' && argName != 'destinations') return;

      // Check if the value is a list with too many items
      final Expression value = node.expression;
      if (value is! ListLiteral || value.elements.length <= _maxItems) return;

      // Check if this is on a nav bar widget
      if (_isOnNavBar(node)) {
        reporter.atNode(node, code);
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
  const RequireTabControllerLengthSyncRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'require_tab_controller_length_sync',
    problemMessage:
        '[require_tab_controller_length_sync] TabController length mismatch '
        'throws RangeError when switching tabs, crashing the app.',
    correctionMessage: 'Ensure TabController length equals the number of tabs.',
    errorSeverity: DiagnosticSeverity.ERROR,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
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
      final RegExp controllerPattern =
          RegExp(r'TabController\s*\(\s*length\s*:\s*(\d+)');
      final Match? controllerMatch = controllerPattern.firstMatch(classSource);
      if (controllerMatch != null) {
        controllerLength = int.tryParse(controllerMatch.group(1) ?? '');
      }

      // Look for TabBar(tabs: [...])
      final RegExp tabBarPattern =
          RegExp(r'TabBar\s*\([^)]*tabs\s*:\s*\[([^\]]*)\]');
      final Match? tabBarMatch = tabBarPattern.firstMatch(classSource);
      if (tabBarMatch != null) {
        // Count commas + 1 for number of items
        final String tabsContent = tabBarMatch.group(1) ?? '';
        if (tabsContent.trim().isNotEmpty) {
          tabBarTabCount =
              tabsContent.split(',').where((s) => s.trim().isNotEmpty).length;
        } else {
          tabBarTabCount = 0;
        }
      }

      // Look for TabBarView(children: [...])
      final RegExp tabBarViewPattern =
          RegExp(r'TabBarView\s*\([^)]*children\s*:\s*\[([^\]]*)\]');
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
          reporter.atNode(node, code);
        }
        if (tabBarViewChildCount != null &&
            controllerLength != tabBarViewChildCount) {
          reporter.atNode(node, code);
        }
      }
    });
  }
}

/// Warns when RefreshIndicator onRefresh doesn't return Future.
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
  const AvoidRefreshWithoutAwaitRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'avoid_refresh_without_await',
    problemMessage:
        '[avoid_refresh_without_await] RefreshIndicator onRefresh must return Future. Without await, the spinner dismisses immediately while data is still loading, confusing users.',
    correctionMessage: 'Make onRefresh async and await async operations.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry
        .addInstanceCreationExpression((InstanceCreationExpression node) {
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
              reporter.atNode(arg, code);
            }
          }
        }
      }
    });
  }
}

/// Warns when multiple widgets have autofocus: true.
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
  const AvoidMultipleAutofocusRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_multiple_autofocus',
    problemMessage:
        '[avoid_multiple_autofocus] Multiple widgets with autofocus: true causes unpredictable behavior.',
    correctionMessage: 'Only one widget should have autofocus: true.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodDeclaration((MethodDeclaration node) {
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
  const RequireRefreshIndicatorOnListsRule() : super(code: _code);

  /// UX improvement - standard mobile pattern.
  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'require_refresh_indicator_on_lists',
    problemMessage:
        '[require_refresh_indicator_on_lists] ListView without RefreshIndicator. Users can\'t pull to refresh.',
    correctionMessage:
        'Wrap with RefreshIndicator for pull-to-refresh support.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addInstanceCreationExpression((node) {
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
  const AvoidShrinkWrapExpensiveRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_shrink_wrap_expensive',
    problemMessage:
        '[avoid_shrink_wrap_expensive] shrinkWrap: true disables virtualization and can cause performance issues.',
    correctionMessage:
        'Use a fixed-height container, Slivers, or reconsider the layout.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  static const Set<String> _scrollableTypes = <String>{
    'ListView',
    'GridView',
    'SingleChildScrollView',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addNamedExpression((NamedExpression node) {
      if (node.name.label.name != 'shrinkWrap') return;

      final Expression value = node.expression;
      if (value is! BooleanLiteral || !value.value) return;

      // Check if this shrinkWrap is on a scrollable widget
      final scrollableNode = _findScrollableWidget(node);
      if (scrollableNode == null) return;

      // Skip if NeverScrollableScrollPhysics is used - this is intentional
      // for nested non-scrolling lists inside another scrollable
      if (_hasNeverScrollablePhysics(scrollableNode)) return;

      reporter.atNode(node, code);
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
  const PreferItemExtentRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'prefer_item_extent',
    problemMessage:
        '[prefer_item_extent] ListView with uniform items should specify itemExtent for better performance.',
    correctionMessage:
        'Add itemExtent parameter if all items have the same height.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry
        .addInstanceCreationExpression((InstanceCreationExpression node) {
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
  const PreferPrototypeItemRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'prefer_prototype_item',
    problemMessage:
        '[prefer_prototype_item] Consider using prototypeItem for ListView with consistent item sizes.',
    correctionMessage:
        'Add prototypeItem parameter if items have consistent dimensions.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry
        .addInstanceCreationExpression((InstanceCreationExpression node) {
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
  const RequireKeyForReorderableRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'require_key_for_reorderable',
    problemMessage:
        '[require_key_for_reorderable] Without unique keys, reordering fails '
        'silently or shows wrong items after drag-and-drop.',
    correctionMessage: 'Add a key parameter (e.g., ValueKey) to each item.',
    errorSeverity: DiagnosticSeverity.ERROR,
  );

  static const Set<String> _reorderableTypes = <String>{
    'ReorderableListView',
    'ReorderableList',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry
        .addInstanceCreationExpression((InstanceCreationExpression node) {
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
      Expression childrenExpr, SaropaDiagnosticReporter reporter) {
    if (childrenExpr is ListLiteral) {
      for (final CollectionElement element in childrenExpr.elements) {
        if (element is InstanceCreationExpression) {
          if (!_hasKeyArgument(element.argumentList)) {
            reporter.atNode(element, code);
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
      MethodInvocation mapInvocation, SaropaDiagnosticReporter reporter) {
    if (mapInvocation.argumentList.arguments.isNotEmpty) {
      final Expression callback = mapInvocation.argumentList.arguments.first;
      if (callback is FunctionExpression) {
        _checkBuilderBodyForKey(callback.body, reporter);
      }
    }
  }

  void _checkItemBuilderForKeys(
      Expression builderExpr, SaropaDiagnosticReporter reporter) {
    if (builderExpr is FunctionExpression) {
      _checkBuilderBodyForKey(builderExpr.body, reporter);
    }
  }

  void _checkBuilderBodyForKey(
      FunctionBody body, SaropaDiagnosticReporter reporter) {
    if (body is ExpressionFunctionBody) {
      final Expression expr = body.expression;
      if (expr is InstanceCreationExpression) {
        if (!_hasKeyArgument(expr.argumentList)) {
          reporter.atNode(expr, code);
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
        reporter.atNode(expr, code);
      }
    }
    super.visitReturnStatement(node);
  }
}

/// Warns when long lists have addAutomaticKeepAlives enabled (default).
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
  const RequireAddAutomaticKeepAlivesOffRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'require_add_automatic_keep_alives_off',
    problemMessage:
        '[require_add_automatic_keep_alives_off] Long lists with addAutomaticKeepAlives: true (default) can cause memory issues.',
    correctionMessage:
        'Add addAutomaticKeepAlives: false for better memory efficiency.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  static const Set<String> _listTypes = <String>{
    'ListView',
    'GridView',
  };

  /// Threshold for considering a list "long"
  static const int _longListThreshold = 50;

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry
        .addInstanceCreationExpression((InstanceCreationExpression node) {
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
