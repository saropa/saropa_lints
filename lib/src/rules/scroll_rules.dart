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

  static const LintCode _code = LintCode(
    name: 'avoid_shrinkwrap_in_scrollview',
    problemMessage: 'shrinkWrap: true in scrollable disables virtualization.',
    correctionMessage:
        'Use CustomScrollView with slivers, or add NeverScrollableScrollPhysics.',
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

      // Check for ListView, GridView, etc.
      if (!_scrollableTypes.contains(typeName)) return;

      // Check for shrinkWrap: true
      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression && arg.name.label.name == 'shrinkWrap') {
          final Expression value = arg.expression;
          if (value is BooleanLiteral && value.value) {
            // Check if inside another scrollable
            if (_isInsideScrollable(node)) {
              reporter.atNode(arg, code);
            }
          }
        }
      }
    });
  }

  static const Set<String> _scrollableTypes = <String>{
    'ListView',
    'GridView',
    'SingleChildScrollView',
    'CustomScrollView',
  };

  bool _isInsideScrollable(AstNode node) {
    AstNode? current = node.parent;
    while (current != null) {
      if (current is InstanceCreationExpression) {
        final String typeName = current.constructorName.type.name2.lexeme;
        if (_scrollableTypes.contains(typeName) ||
            typeName == 'Column' ||
            typeName == 'Row') {
          // Check if this scrollable is inside another scrollable
          AstNode? parent = current.parent;
          while (parent != null) {
            if (parent is InstanceCreationExpression) {
              final String parentType =
                  parent.constructorName.type.name2.lexeme;
              if (_scrollableTypes.contains(parentType)) {
                return true;
              }
            }
            parent = parent.parent;
          }
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

  static const LintCode _code = LintCode(
    name: 'avoid_nested_scrollables_conflict',
    problemMessage:
        'Nested scrollable without explicit physics causes gesture conflicts.',
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
    context.registry
        .addInstanceCreationExpression((InstanceCreationExpression node) {
      final String typeName = node.constructorName.type.name2.lexeme;

      if (!_scrollableTypes.contains(typeName)) return;

      // Check if this is inside another scrollable
      if (!_isInsideScrollable(node)) return;

      // Check if physics is specified
      bool hasPhysics = false;
      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression && arg.name.label.name == 'physics') {
          hasPhysics = true;
          break;
        }
      }

      if (!hasPhysics) {
        reporter.atNode(node.constructorName, code);
      }
    });
  }

  bool _isInsideScrollable(AstNode node) {
    AstNode? current = node.parent;
    while (current != null) {
      if (current is InstanceCreationExpression) {
        final String typeName = current.constructorName.type.name2.lexeme;
        if (_scrollableTypes.contains(typeName)) {
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
/// ListView(children: [...]) builds all children immediately.
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

  static const LintCode _code = LintCode(
    name: 'avoid_listview_children_for_large_lists',
    problemMessage:
        'ListView with many children loads all items. Use ListView.builder.',
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

  static const LintCode _code = LintCode(
    name: 'avoid_excessive_bottom_nav_items',
    problemMessage: 'BottomNavigationBar with more than 5 items crowds the UI.',
    correctionMessage:
        'Limit to 5 items or use a navigation drawer for additional options.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  static const int _maxItems = 5;

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry
        .addInstanceCreationExpression((InstanceCreationExpression node) {
      final String typeName = node.constructorName.type.name2.lexeme;

      if (typeName != 'BottomNavigationBar' && typeName != 'NavigationBar') {
        return;
      }

      // Check for items argument
      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression &&
            (arg.name.label.name == 'items' ||
                arg.name.label.name == 'destinations')) {
          final Expression value = arg.expression;
          if (value is ListLiteral && value.elements.length > _maxItems) {
            reporter.atNode(arg, code);
          }
        }
      }
    });
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

  static const LintCode _code = LintCode(
    name: 'require_tab_controller_length_sync',
    problemMessage:
        'TabController length must match TabBar/TabBarView children count.',
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

  static const LintCode _code = LintCode(
    name: 'avoid_refresh_without_await',
    problemMessage:
        'RefreshIndicator onRefresh should return Future for proper timing.',
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

  static const LintCode _code = LintCode(
    name: 'avoid_multiple_autofocus',
    problemMessage:
        'Multiple widgets with autofocus: true causes unpredictable behavior.',
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
