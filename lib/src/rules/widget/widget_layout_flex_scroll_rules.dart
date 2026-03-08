// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/type.dart';

import '../../saropa_lint_rule.dart';

class AvoidExpandedAsSpacerRule extends SaropaLintRule {
  AvoidExpandedAsSpacerRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    'avoid_expanded_as_spacer',
    '[avoid_expanded_as_spacer] Use Spacer() instead of Expanded with empty child. This layout configuration can trigger RenderFlex overflow errors or unexpected visual behavior at runtime. {v6}',
    correctionMessage:
        'Replace Expanded(child: SizedBox/Container()) with Spacer(). Test on multiple screen sizes to verify the layout adapts correctly.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      final String constructorName = node.constructorName.type.name.lexeme;
      if (constructorName != 'Expanded') return;

      // Find the child argument
      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression && arg.name.label.name == 'child') {
          final Expression childExpr = arg.expression;

          // Check if child is SizedBox() or Container() with no meaningful content
          if (childExpr is InstanceCreationExpression) {
            final String childType = childExpr.constructorName.type.name.lexeme;
            if (childType == 'SizedBox' || childType == 'Container') {
              // Check if it has no child argument (empty)
              final bool hasChild = childExpr.argumentList.arguments.any(
                (Expression e) =>
                    e is NamedExpression && e.name.label.name == 'child',
              );
              if (!hasChild) {
                reporter.atNode(node);
              }
            }
          }
        }
      }
    });
  }
}

/// Warns when Flexible or Expanded is used outside of a Flex widget.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v6
///
/// Flexible and Expanded widgets only work inside Row, Column, or Flex.
/// Using them elsewhere has no effect and indicates a bug.
///
/// Example of **bad** code:
/// ```dart
/// Stack(
///   children: [
///     Expanded(child: Text('Hello')),  // Expanded does nothing here
///   ],
/// )
/// ```
///
/// Example of **good** code:
/// ```dart
/// Column(
///   children: [
///     Expanded(child: Text('Hello')),  // Correct usage
///   ],
/// )
/// ```
class AvoidFlexibleOutsideFlexRule extends SaropaLintRule {
  AvoidFlexibleOutsideFlexRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    'avoid_flexible_outside_flex',
    '[avoid_flexible_outside_flex] The Flexible or Expanded widget is being used outside of a Row, Column, or Flex parent. This breaks layout expectations and can cause runtime errors or unexpected UI behavior, as Flexible/Expanded are only designed to work within Flex-based widgets. Using them elsewhere will not provide the intended flexible sizing and may result in layout exceptions. {v6}',
    correctionMessage:
        'Wrap Flexible or Expanded widgets only inside Row, Column, or Flex parents. Refactor your widget tree so that Flexible/Expanded are direct children of a Flex-based widget, ensuring proper layout behavior and avoiding runtime errors. See Flutter documentation on Flex widgets for correct usage patterns.',
    severity: DiagnosticSeverity.WARNING,
  );

  static const Set<String> _flexibleWidgets = <String>{'Flexible', 'Expanded'};
  static const Set<String> _flexWidgets = <String>{'Row', 'Column', 'Flex'};

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      final String? constructorName = node.constructorName.type.element?.name;
      if (constructorName == null ||
          !_flexibleWidgets.contains(constructorName)) {
        return;
      }

      // Walk up the tree to find the parent widget
      AstNode? current = node.parent;
      while (current != null) {
        if (current is InstanceCreationExpression) {
          final String? parentName = current.constructorName.type.element?.name;
          if (parentName != null && _flexWidgets.contains(parentName)) {
            return; // Found valid Flex parent
          }
          // Found another widget that's not a Flex, warn
          reporter.atNode(node);
          return;
        }
        current = current.parent;
      }

      // Reached top without finding Flex parent
      reporter.atNode(node);
    });
  }
}

/// Warns when an Image widget is wrapped in Opacity instead of using Image.color.
///
/// Since: v1.7.2 | Updated: v4.13.0 | Rule version: v2
///
/// Example of **bad** code:
/// ```dart
/// Opacity(
///   opacity: 0.5,
///   child: Image.asset('icon.png'),
/// )
/// ```
///
/// Example of **good** code:
/// ```dart
/// Image.asset(
///   'icon.png',
///   color: Colors.white.withOpacity(0.5),
///   colorBlendMode: BlendMode.modulate,
/// )
/// ```
class AvoidShrinkWrapInListsRule extends SaropaLintRule {
  AvoidShrinkWrapInListsRule() : super(code: _code);

  static const LintCode _code = LintCode(
    'avoid_shrink_wrap_in_lists',
    "[avoid_shrink_wrap_in_lists] Using 'shrinkWrap: true' inside a nested scrollable (such as a ListView within another scrollable) can cause significant performance issues. It forces the inner list to compute the size of all its children, leading to poor scroll performance and increased memory usage, especially with large or dynamic lists. {v4}",
    correctionMessage:
        'Avoid using shrinkWrap: true in nested scrollables. Instead, provide a fixed height for the inner list using SizedBox, or use Expanded/Flexible within a Flex parent. This ensures efficient rendering and smooth scrolling. See Flutter documentation for guidance on nested scrollables and performance best practices.',
    severity: DiagnosticSeverity.WARNING,
  );

  static const Set<String> _scrollableWidgets = <String>{
    'ListView',
    'GridView',
    'CustomScrollView',
    'SingleChildScrollView',
  };

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      final String? constructorName = node.constructorName.type.element?.name;
      if (constructorName == null) return;

      if (!_scrollableWidgets.contains(constructorName)) return;

      // Check for shrinkWrap: true
      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression && arg.name.label.name == 'shrinkWrap') {
          final expr = arg.expression;
          if (expr is BooleanLiteral && expr.value) {
            // Check if inside another scrollable
            AstNode? parent = node.parent;
            while (parent != null) {
              if (parent is InstanceCreationExpression) {
                final String? parentConstructor =
                    parent.constructorName.type.element?.name;
                if (parentConstructor != null &&
                    _scrollableWidgets.contains(parentConstructor)) {
                  reporter.atNode(arg);
                  return;
                }
              }
              parent = parent.parent;
            }
          }
        }
      }
    });
  }
}

/// Warns when a Column or Row has only a single child.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v5
///
/// Example of **bad** code:
/// ```dart
/// Column(children: [Text('Hello')])
/// ```
///
/// Example of **good** code:
/// ```dart
/// Text('Hello')  // or use Align/Center if alignment needed
/// ```
class AvoidSingleChildColumnRowRule extends SaropaLintRule {
  AvoidSingleChildColumnRowRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    'avoid_single_child_column_row',
    '[avoid_single_child_column_row] Column/Row with single child is unnecessary. A Column or Row has only a single child. This layout configuration can trigger RenderFlex overflow errors or unexpected visual behavior at runtime. {v5}',
    correctionMessage:
        'Use the child directly or Align/Center for alignment. Test on multiple screen sizes to verify the layout adapts correctly.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      final String constructorName = node.constructorName.type.name.lexeme;
      if (constructorName != 'Column' && constructorName != 'Row') return;

      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression && arg.name.label.name == 'children') {
          final Expression value = arg.expression;
          if (value is ListLiteral) {
            // Only flag if there's exactly one static element and no
            // dynamic elements. Spreads, collection-if, and collection-for
            // can all produce varying child counts at runtime.
            int staticCount = 0;
            bool hasDynamicElement = false;

            for (final CollectionElement element in value.elements) {
              if (element is SpreadElement ||
                  element is IfElement ||
                  element is ForElement) {
                hasDynamicElement = true;
              } else {
                staticCount++;
              }
            }

            // Only report if: single static element AND no dynamic elements
            if (staticCount == 1 && !hasDynamicElement) {
              reporter.atNode(node.constructorName, code);
            }
          }
        }
      }
    });
  }
}

/// Warns when a State class has a constructor body.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v6
///
/// Example of **bad** code:
/// ```dart
/// class _MyWidgetState extends State<MyWidget> {
///   _MyWidgetState() {
///     // initialization code
///   }
/// }
/// ```
///
/// Example of **good** code:
/// ```dart
/// class _MyWidgetState extends State<MyWidget> {
///   @override
///   void initState() {
///     super.initState();
///     // initialization code
///   }
/// }
/// ```
class PreferSliverPrefixRule extends SaropaLintRule {
  PreferSliverPrefixRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.opinionated;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  @override
  String get exampleBad =>
      'class Header extends SliverPersistentHeaderDelegate {\n'
      '  // missing Sliver prefix\n'
      '}';

  @override
  String get exampleGood =>
      'class SliverHeader extends SliverPersistentHeaderDelegate {\n'
      '  // clear sliver intent\n'
      '}';

  static const LintCode _code = LintCode(
    'prefer_sliver_prefix',
    '[prefer_sliver_prefix] Prefixing sliver widget class names with Sliver is a naming convention. It does not affect widget behavior or performance. Enable via the stylistic tier. {v5}',
    correctionMessage:
        'Rename the class to start with "Sliver" (e.g., SliverHeader instead of Header) to communicate its sliver layout protocol.',
    severity: DiagnosticSeverity.INFO,
  );

  static const Set<String> _sliverBaseClasses = <String>{
    'SliverChildDelegate',
    'SliverChildBuilderDelegate',
    'SliverChildListDelegate',
    'SliverGridDelegate',
    'SliverGridDelegateWithFixedCrossAxisCount',
    'SliverGridDelegateWithMaxCrossAxisExtent',
    'SliverPersistentHeaderDelegate',
    'SliverMultiBoxAdaptorWidget',
    'RenderSliver',
    'RenderSliverBoxChildManager',
  };

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addClassDeclaration((ClassDeclaration node) {
      final String className = node.name.lexeme;

      // Skip if already has Sliver prefix
      if (className.startsWith('Sliver')) return;

      // Check extends clause
      final ExtendsClause? extendsClause = node.extendsClause;
      if (extendsClause != null) {
        final String superclass = extendsClause.superclass.name.lexeme;
        if (_sliverBaseClasses.contains(superclass) ||
            superclass.startsWith('Sliver')) {
          reporter.atNode(node);
          return;
        }
      }

      // Check implements clause
      final ImplementsClause? implementsClause = node.implementsClause;
      if (implementsClause != null) {
        for (final NamedType interface in implementsClause.interfaces) {
          final String interfaceName = interface.name.lexeme;
          if (_sliverBaseClasses.contains(interfaceName) ||
              interfaceName.startsWith('Sliver')) {
            reporter.atNode(node);
            return;
          }
        }
      }

      // Check with clause (mixins)
      final WithClause? withClause = node.withClause;
      if (withClause != null) {
        for (final NamedType mixin in withClause.mixinTypes) {
          final String mixinName = mixin.name.lexeme;
          if (_sliverBaseClasses.contains(mixinName) ||
              mixinName.startsWith('Sliver')) {
            reporter.atNode(node);
            return;
          }
        }
      }
    });
  }
}

/// Warns when RichText is used instead of Text.rich.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v6
///
/// Example of **bad** code:
/// ```dart
/// RichText(
///   text: TextSpan(text: 'Hello'),
/// )
/// ```
///
/// Example of **good** code:
/// ```dart
/// Text.rich(
///   TextSpan(text: 'Hello'),
/// )
/// ```
class PreferUsingListViewRule extends SaropaLintRule {
  PreferUsingListViewRule() : super(code: _code);

  static const LintCode _code = LintCode(
    'prefer_using_list_view',
    '[prefer_using_list_view] Column inside SingleChildScrollView. A "Column" is being used inside a "SingleChildScrollView" Flutter to pre-render the entire list, bypassing "Lazy Loading" optimizations. This layout configuration can also trigger RenderFlex overflow errors or unexpected visual behavior at runtime. {v6}',
    correctionMessage:
        'Refactor this layout into a single "ListView" to leverage viewport-based optimizations and memory management. To maintain the layout logic of a "Column" with a "spacing" property, use the "ListView.separated" constructor; this allows you to define a "separatorBuilder" that injects consistent spacing only between elements, effectively replacing manual "SizedBox" additions or the "spacing" attribute. Ensure the new "ListView" is wrapped in a "Flexible" or "Expanded" widget if it resides within a "Flex" container to avoid unbounded height errors. This transition ensures that off-screen items are lazily loaded and disposed of, preventing "RenderFlex" overflows and significantly improving scrolling performance on resource-constrained devices.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      final String typeName = node.constructorName.type.name.lexeme;
      if (typeName != 'SingleChildScrollView') return;

      // Find the child argument
      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression && arg.name.label.name == 'child') {
          final Expression childExpr = arg.expression;
          if (_isColumnOrRow(childExpr)) {
            reporter.atNode(node);
            return;
          }
        }
      }
    });
  }

  bool _isColumnOrRow(Expression expr) {
    if (expr is InstanceCreationExpression) {
      final String typeName = expr.constructorName.type.name.lexeme;
      return typeName == 'Column';
    }
    return false;
  }
}

/// Warns when Widget class has public non-final fields or public methods
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v6
///
/// that could be private.
///
/// ### Example
///
/// #### BAD:
/// ```dart
/// class MyWidget extends StatelessWidget {
///   String title;  // Should be final
///   void helper() {}  // Should be private
/// }
/// ```
///
/// #### GOOD:
/// ```dart
/// class MyWidget extends StatelessWidget {
///   final String title;
///   void _helper() {}
/// }
/// ```
class AvoidListViewWithoutItemExtentRule extends SaropaLintRule {
  AvoidListViewWithoutItemExtentRule() : super(code: _code);

  static const LintCode _code = LintCode(
    'avoid_listview_without_item_extent',
    '[avoid_listview_without_item_extent] ListView.builder should specify itemExtent to improve scroll performance. This layout configuration can trigger RenderFlex overflow errors or unexpected visual behavior at runtime. {v5}',
    correctionMessage:
        'Add itemExtent or prototypeItem parameter. Test on multiple screen sizes to verify the layout adapts correctly.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      final String typeName = node.constructorName.type.name.lexeme;
      final String? constructorName = node.constructorName.name?.name;

      if (typeName == 'ListView' && constructorName == 'builder') {
        bool hasItemExtent = false;
        bool hasPrototypeItem = false;

        for (final Expression arg in node.argumentList.arguments) {
          if (arg is NamedExpression) {
            final String name = arg.name.label.name;
            if (name == 'itemExtent') hasItemExtent = true;
            if (name == 'prototypeItem') hasPrototypeItem = true;
          }
        }

        if (!hasItemExtent && !hasPrototypeItem) {
          reporter.atNode(node.constructorName, code);
        }
      }
    });
  }
}

/// Future rule: avoid-mediaquery-in-build
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v6
///
/// Warns when MediaQuery.of is called directly in build method.
///
/// Example of **bad** code:
/// ```dart
/// Widget build(BuildContext context) {
///   final width = MediaQuery.of(context).size.width;  // Rebuilds on any MediaQuery change
///   return Container(width: width);
/// }
/// ```
///
/// Example of **good** code:
/// ```dart
/// Widget build(BuildContext context) {
///   final width = MediaQuery.sizeOf(context).width;  // Only rebuilds on size change
///   return Container(width: width);
/// }
/// ```
class PreferSliverListDelegateRule extends SaropaLintRule {
  PreferSliverListDelegateRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    'prefer_sliver_list_delegate',
    '[prefer_sliver_list_delegate] Use SliverChildBuilderDelegate to improve performance with large lists. This layout configuration can trigger RenderFlex overflow errors or unexpected visual behavior at runtime. {v6}',
    correctionMessage:
        'Replace SliverChildListDelegate with SliverChildBuilderDelegate. Test on multiple screen sizes to verify the layout adapts correctly.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      final String typeName = node.constructorName.type.name.lexeme;

      if (typeName == 'SliverChildListDelegate') {
        // Check if the list has many items
        final NodeList<Expression> args = node.argumentList.arguments;
        if (args.isNotEmpty) {
          final first = args.first;
          if (first is ListLiteral && first.elements.length > 10) {
            reporter.atNode(node.constructorName, code);
          }
        }
      }
    });
  }
}

/// Future rule: avoid-layout-builder-in-build
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v6
///
/// Warns when LayoutBuilder is used inefficiently.
///
/// Example of **bad** code:
/// ```dart
/// LayoutBuilder(
///   builder: (context, constraints) {
///     return ExpensiveWidget();  // Rebuilds on every layout
///   },
/// )
/// ```
///
/// Example of **good** code:
/// ```dart
/// LayoutBuilder(
///   builder: (context, constraints) {
///     return constraints.maxWidth > 600
///         ? const WideLayout()
///         : const NarrowLayout();
///   },
/// )
/// ```
class AvoidSingleChildScrollViewWithColumnRule extends SaropaLintRule {
  AvoidSingleChildScrollViewWithColumnRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  // cspell:ignore singlechildscrollview
  static const LintCode _code = LintCode(
    'avoid_singlechildscrollview_with_column',
    '[avoid_singlechildscrollview_with_column] SingleChildScrollView with Column may cause layout issues. SingleChildScrollView wraps a Column with Expanded children. This layout configuration can trigger RenderFlex overflow errors or unexpected visual behavior at runtime. {v6}',
    correctionMessage:
        'Use ListView instead, or remove Expanded/Flexible children. Test on multiple screen sizes to verify the layout adapts correctly.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      final String typeName = node.constructorName.type.name.lexeme;

      if (typeName == 'SingleChildScrollView') {
        for (final Expression arg in node.argumentList.arguments) {
          if (arg is NamedExpression && arg.name.label.name == 'child') {
            final Expression child = arg.expression;
            if (child is InstanceCreationExpression) {
              final String childType = child.constructorName.type.name.lexeme;
              if (childType == 'Column' || childType == 'Row') {
                // Check for Expanded/Flexible children
                if (_hasFlexibleChildren(child)) {
                  reporter.atNode(node.constructorName, code);
                }
              }
            }
          }
        }
      }
    });
  }

  bool _hasFlexibleChildren(InstanceCreationExpression node) {
    for (final Expression arg in node.argumentList.arguments) {
      if (arg is NamedExpression && arg.name.label.name == 'children') {
        final Expression childrenExpr = arg.expression;
        if (childrenExpr is ListLiteral) {
          for (final CollectionElement element in childrenExpr.elements) {
            if (element is InstanceCreationExpression) {
              final String name = element.constructorName.type.name.lexeme;
              if (name == 'Expanded' || name == 'Flexible') {
                return true;
              }
            }
          }
        }
      }
    }
    return false;
  }
}

/// Future rule: prefer-cached-network-image
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v6
///
/// Warns when Image.network is used instead of CachedNetworkImage.
///
/// Example of **bad** code:
/// ```dart
/// Image.network('https://example.com/image.png')
/// ```
///
/// Example of **good** code:
/// ```dart
/// CachedNetworkImage(imageUrl: 'https://example.com/image.png')
/// ```
class PreferListViewBuilderRule extends SaropaLintRule {
  PreferListViewBuilderRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    'prefer_listview_builder',
    '[prefer_listview_builder] Use ListView.builder to improve performance. This layout configuration can trigger RenderFlex overflow errors or unexpected visual behavior at runtime. {v3}',
    correctionMessage:
        'Replace ListView(children:) with ListView.builder. Test on multiple screen sizes to verify the layout adapts correctly.',
    severity: DiagnosticSeverity.WARNING,
  );

  static const int _childThreshold = 10;

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      final String typeName = node.constructorName.type.name.lexeme;
      if (typeName != 'ListView') return;
      if (node.constructorName.name != null) return; // Skip named constructors

      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression && arg.name.label.name == 'children') {
          final Expression childrenExpr = arg.expression;

          if (childrenExpr is MethodInvocation &&
              childrenExpr.methodName.name == 'generate') {
            reporter.atNode(node.constructorName, code);
            return;
          }

          if (childrenExpr is ListLiteral &&
              childrenExpr.elements.length >= _childThreshold) {
            reporter.atNode(node.constructorName, code);
            return;
          }
        }
      }
    });
  }
}

/// Warns when Opacity widget is animated instead of FadeTransition.
///
/// Since: v1.3.0 | Updated: v4.13.0 | Rule version: v3
///
/// Alias: avoid_opacity_widget_animation
///
/// Animating Opacity causes rebuilds. FadeTransition is more performant.
///
/// Example of **bad** code:
/// ```dart
/// AnimatedBuilder(
///   builder: (ctx, child) => Opacity(opacity: _ctrl.value, child: child),
/// )
/// ```
///
/// Example of **good** code:
/// ```dart
/// FadeTransition(opacity: _ctrl, child: child)
/// ```
class AvoidNestedScrollablesRule extends SaropaLintRule {
  AvoidNestedScrollablesRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    'avoid_nested_scrollables',
    '[avoid_nested_scrollables] Nested scrollable widgets can cause scroll conflicts. This layout configuration can trigger RenderFlex overflow errors or unexpected visual behavior at runtime. {v2}',
    correctionMessage:
        'Use NestedScrollView, or add shrinkWrap: true and NeverScrollableScrollPhysics().',
    severity: DiagnosticSeverity.WARNING,
  );

  static const Set<String> _scrollableWidgets = <String>{
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
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      final String typeName = node.constructorName.type.name.lexeme;
      if (!_scrollableWidgets.contains(typeName)) return;

      // Check if this scrollable has shrinkWrap + NeverScrollableScrollPhysics
      bool hasShrinkWrap = false;
      bool hasNeverScrollPhysics = false;

      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression) {
          final String argName = arg.name.label.name;
          if (argName == 'shrinkWrap') {
            final String value = arg.expression.toSource();
            if (value == 'true') hasShrinkWrap = true;
          }
          if (argName == 'physics') {
            final String value = arg.expression.toSource();
            if (value.contains('NeverScrollableScrollPhysics')) {
              hasNeverScrollPhysics = true;
            }
          }
        }
      }

      // If properly configured, it's fine
      if (hasShrinkWrap && hasNeverScrollPhysics) return;

      // Check if inside another scrollable
      AstNode? current = node.parent;
      while (current != null) {
        if (current is InstanceCreationExpression) {
          final String parentType = current.constructorName.type.name.lexeme;
          if (_scrollableWidgets.contains(parentType) &&
              parentType != 'NestedScrollView') {
            reporter.atNode(node.constructorName, code);
            return;
          }
          // NestedScrollView is the proper solution
          if (parentType == 'NestedScrollView') {
            return;
          }
        }
        current = current.parent;
      }
    });
  }
}

// ============================================================================
// NEW RULES FROM ROADMAP
// ============================================================================

/// Warns when hardcoded numeric values are used in layout widgets.
///
/// Since: v1.4.2 | Updated: v4.13.0 | Rule version: v6
///
/// Magic numbers in layout make responsive design difficult and
/// reduce code maintainability.
///
/// **BAD:**
/// ```dart
/// SizedBox(width: 100, height: 50);
/// Padding(padding: EdgeInsets.all(16));
/// Container(margin: EdgeInsets.only(left: 24));
/// ```
///
/// **GOOD:**
/// ```dart
/// SizedBox(width: AppDimensions.buttonWidth);
/// Padding(padding: EdgeInsets.all(AppSpacing.medium));
/// Container(margin: EdgeInsets.only(left: context.spacing.large));
/// ```
class RequireScrollPhysicsRule extends SaropaLintRule {
  RequireScrollPhysicsRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    'require_scroll_physics',
    '[require_scroll_physics] Scrollable widget should specify scroll physics. This layout configuration can trigger RenderFlex overflow errors or unexpected visual behavior at runtime. {v5}',
    correctionMessage:
        'Add physics: BouncingScrollPhysics() or ClampingScrollPhysics(). Test on multiple screen sizes to verify the layout adapts correctly.',
    severity: DiagnosticSeverity.INFO,
  );

  static const Set<String> _scrollableWidgets = <String>{
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
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      final String typeName = node.constructorName.type.name.lexeme;
      if (!_scrollableWidgets.contains(typeName)) return;

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
}

/// Warns when ListView is used inside CustomScrollView instead of SliverList.
///
/// Since: v1.4.2 | Updated: v4.13.0 | Rule version: v6
///
/// Using ListView inside CustomScrollView creates nested scrollables.
/// Use SliverList for proper sliver composition.
///
/// **BAD:**
/// ```dart
/// CustomScrollView(
///   slivers: [
///     SliverAppBar(...),
///     SliverToBoxAdapter(child: ListView(...)), // Wrong!
///   ],
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// CustomScrollView(
///   slivers: [
///     SliverAppBar(...),
///     SliverList(delegate: SliverChildBuilderDelegate(...)),
///   ],
/// )
/// ```
class PreferSliverListRule extends SaropaLintRule {
  PreferSliverListRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    'prefer_sliver_list',
    '[prefer_sliver_list] Use SliverList instead of ListView inside CustomScrollView. Using ListView inside CustomScrollView creates nested scrollables. Use SliverList for proper sliver composition. {v6}',
    correctionMessage:
        'Replace ListView with SliverList for proper sliver composition. Test on multiple screen sizes to verify the layout adapts correctly.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      final String typeName = node.constructorName.type.name.lexeme;
      if (typeName != 'ListView' && typeName != 'GridView') return;

      // Check if inside CustomScrollView
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

/// Warns when StatefulWidget doesn't use AutomaticKeepAliveClientMixin
///
/// Since: v1.4.2 | Updated: v4.13.0 | Rule version: v5
///
/// for preserving state in TabView/PageView.
///
/// Without AutomaticKeepAliveClientMixin, tab content is rebuilt when
/// switching tabs, losing scroll position and state.
///
/// **BAD:**
/// ```dart
/// class _TabContentState extends State<TabContent> {
///   @override
///   Widget build(BuildContext context) => ListView(...);
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// class _TabContentState extends State<TabContent>
///     with AutomaticKeepAliveClientMixin {
///   @override
///   bool get wantKeepAlive => true;
///
///   @override
///   Widget build(BuildContext context) {
///     super.build(context);
///     return ListView(...);
///   }
/// }
/// ```
class PreferKeepAliveRule extends SaropaLintRule {
  PreferKeepAliveRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    'prefer_keep_alive',
    '[prefer_keep_alive] Use AutomaticKeepAliveClientMixin to preserve state. Without AutomaticKeepAliveClientMixin, tab content is rebuilt when switching tabs, losing scroll position and state. {v5}',
    correctionMessage:
        'Add "with AutomaticKeepAliveClientMixin" to preserve state in tabs. Test on multiple screen sizes to verify the layout adapts correctly.',
    severity: DiagnosticSeverity.INFO,
  );

  static final RegExp _tabPageViewPattern = RegExp(
    r'\b(TabBarView|PageView)\b',
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addClassDeclaration((ClassDeclaration node) {
      // Check if it's a State class
      final ExtendsClause? extendsClause = node.extendsClause;
      if (extendsClause == null) return;

      final String superclassName = extendsClause.superclass.name.lexeme;
      if (superclassName != 'State') return;

      // Check if already has AutomaticKeepAliveClientMixin
      final WithClause? withClause = node.withClause;
      if (withClause != null) {
        for (final NamedType mixin in withClause.mixinTypes) {
          if (mixin.name.lexeme == 'AutomaticKeepAliveClientMixin') {
            return; // Already has the mixin
          }
        }
      }

      // Check if this State builds a scrollable inside a tabbed/paged context.
      // Use word boundary so we match TabBarView/PageView as tokens, not
      // substrings (e.g. avoids matching "Tab" in HomeTab.icon).
      final String classSource = node.toSource();
      if (classSource.contains('ListView') ||
          classSource.contains('GridView') ||
          classSource.contains('CustomScrollView')) {
        if (_tabPageViewPattern.hasMatch(classSource)) {
          reporter.atToken(node.name, code);
        }
      }
    });
  }
}

/// Warns when Text widgets are not wrapped with DefaultTextStyle.
///
/// Since: v1.4.2 | Updated: v4.13.0 | Rule version: v5
///
/// DefaultTextStyle provides consistent typography without repeating styles.
///
/// **BAD:**
/// ```dart
/// Column(
///   children: [
///     Text('Title', style: TextStyle(fontSize: 24)),
///     Text('Subtitle', style: TextStyle(fontSize: 24)),
///   ],
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// DefaultTextStyle(
///   style: TextStyle(fontSize: 24),
///   child: Column(
///     children: [Text('Title'), Text('Subtitle')],
///   ),
/// )
/// ```
class PreferWrapOverOverflowRule extends SaropaLintRule {
  PreferWrapOverOverflowRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    'prefer_wrap_over_overflow',
    '[prefer_wrap_over_overflow] Row with many children may overflow - Use Wrap. DefaultTextStyle provides consistent typography without repeating styles. Text widgets are not wrapped with DefaultTextStyle. {v5}',
    correctionMessage:
        'Replace Row with Wrap for automatic wrapping. Test on multiple screen sizes to verify the layout adapts correctly.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      final String typeName = node.constructorName.type.name.lexeme;
      if (typeName != 'Row') return;

      // Count children
      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression && arg.name.label.name == 'children') {
          final Expression childrenExpr = arg.expression;
          if (childrenExpr is ListLiteral) {
            // If row has many small widgets, suggest Wrap
            if (childrenExpr.elements.length >= 5) {
              // Check if children are small widgets like Chip, Icon, etc.
              bool hasSmallWidgets = childrenExpr.elements.any((element) {
                if (element is InstanceCreationExpression) {
                  final String childType =
                      element.constructorName.type.name.lexeme;
                  return childType == 'Chip' ||
                      childType == 'Icon' ||
                      childType == 'Tag' ||
                      childType == 'Badge';
                }
                return false;
              });

              if (hasSmallWidgets) {
                reporter.atNode(node.constructorName, code);
              }
            }
          }
        }
      }
    });
  }
}

/// Warns when FileImage is used for bundled assets instead of AssetImage.
///
/// Since: v1.4.2 | Updated: v4.13.0 | Rule version: v6
///
/// AssetImage is optimized for bundled assets and handles resolution properly.
///
/// **BAD:**
/// ```dart
/// Image(image: FileImage(File('assets/logo.png')))
/// ```
///
/// **GOOD:**
/// ```dart
/// Image(image: AssetImage('assets/logo.png'))
/// // Or simply:
/// Image.asset('assets/logo.png')
/// ```
class AvoidLayoutBuilderInScrollableRule extends SaropaLintRule {
  AvoidLayoutBuilderInScrollableRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    'avoid_layout_builder_in_scrollable',
    '[avoid_layout_builder_in_scrollable] LayoutBuilder inside scrollable causes performance issues. This layout configuration can trigger RenderFlex overflow errors or unexpected visual behavior at runtime. {v6}',
    correctionMessage:
        'Move LayoutBuilder outside the scrollable widget. Test on multiple screen sizes to verify the layout adapts correctly.',
    severity: DiagnosticSeverity.WARNING,
  );

  static const Set<String> _scrollableWidgets = <String>{
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
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      final String typeName = node.constructorName.type.name.lexeme;
      if (typeName != 'LayoutBuilder') return;

      // Check if inside a scrollable
      AstNode? current = node.parent;
      while (current != null) {
        if (current is InstanceCreationExpression) {
          final String parentType = current.constructorName.type.name.lexeme;
          if (_scrollableWidgets.contains(parentType)) {
            reporter.atNode(node.constructorName, code);
            return;
          }
        }
        current = current.parent;
      }
    });
  }
}

/// Warns when IntrinsicWidth/Height could improve layout.
///
/// Since: v1.4.2 | Updated: v4.13.0 | Rule version: v5
///
/// IntrinsicWidth/Height can help with sizing widgets to their content.
///
/// **BAD:**
/// ```dart
/// Row(
///   children: [
///     Expanded(child: TextField()),
///     ElevatedButton(child: Text('Submit')),
///   ],
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// IntrinsicWidth(
///   child: Column(
///     crossAxisAlignment: CrossAxisAlignment.stretch,
///     children: [...],
///   ),
/// )
/// ```
class RequireScrollControllerRule extends SaropaLintRule {
  RequireScrollControllerRule() : super(code: _code);

  static const LintCode _code = LintCode(
    'require_scroll_controller',
    '[require_scroll_controller] Add ScrollController for scroll tracking. ScrollController is needed for infinite scroll and scroll position tracking. Scrollable lists must have a ScrollController. {v3}',
    correctionMessage:
        'Add controller: _scrollController for infinite scroll. Test on multiple screen sizes to verify the layout adapts correctly.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      final String typeName = node.constructorName.type.name.lexeme;
      final String? constructorName = node.constructorName.name?.name;

      // Only check ListView.builder for paginated content
      if (typeName != 'ListView' || constructorName != 'builder') return;

      bool hasController = false;
      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression && arg.name.label.name == 'controller') {
          hasController = true;
          break;
        }
      }

      if (!hasController) {
        reporter.atNode(node.constructorName, code);
      }
    });
  }
}

/// Warns when Positioned is used instead of PositionedDirectional.
///
/// Since: v1.4.2 | Updated: v4.13.0 | Rule version: v3
///
/// PositionedDirectional respects text direction for RTL languages.
///
/// **BAD:**
/// ```dart
/// Stack(
///   children: [
///     Positioned(left: 10, child: Icon(Icons.arrow_back)),
///   ],
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// Stack(
///   children: [
///     PositionedDirectional(start: 10, child: Icon(Icons.arrow_back)),
///   ],
/// )
/// ```
class AvoidShrinkWrapInScrollRule extends SaropaLintRule {
  AvoidShrinkWrapInScrollRule() : super(code: _code);

  /// Stylistic preference. Large counts are acceptable.
  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  @override
  String get exampleBad => 'ListView(\n'
      '  shrinkWrap: true, // O(n) layout cost\n'
      '  children: items,\n'
      ')';

  @override
  String get exampleGood => 'CustomScrollView(\n'
      '  slivers: [SliverList(delegate: ...)],\n'
      ')';

  static const LintCode _code = LintCode(
    'avoid_shrink_wrap_in_scroll',
    '[avoid_shrink_wrap_in_scroll] shrinkWrap: true causes O(n) layout cost and defeats lazy loading. shrinkWrap: true causes O(n) layout cost and defeats lazy loading. However, shrinkWrap is sometimes required (e.g. ListView inside a Column) and is safe when paired with NeverScrollableScrollPhysics and a small bounded itemCount. This is a stylistic preference for Slivers over shrinkWrap — see avoid_shrinkwrap_in_scrollview for the context-aware rule that targets the genuinely dangerous nested-scrollable case. {v6}',
    correctionMessage:
        'Use CustomScrollView with Slivers for efficient lazy loading. If this ListView is inside a Column/Row with a small bounded itemCount and NeverScrollableScrollPhysics, shrinkWrap: true is acceptable.',
    severity: DiagnosticSeverity.INFO,
  );

  static const Set<String> _scrollableWidgets = <String>{
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
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      final String typeName = node.constructorName.type.name.lexeme;

      // Only check scrollable widgets
      if (!_scrollableWidgets.contains(typeName)) return;

      // Check for shrinkWrap: true
      bool hasShrinkWrapTrue = false;
      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression && arg.name.label.name == 'shrinkWrap') {
          final String value = arg.expression.toSource();
          if (value == 'true') {
            hasShrinkWrapTrue = true;
            break;
          }
        }
      }

      if (hasShrinkWrapTrue) {
        reporter.atNode(node.constructorName, code);
      }
    });
  }
}

/// Warns when widget nesting exceeds 15 levels in a build method.
///
/// Since: v1.4.3 | Updated: v4.13.0 | Rule version: v5
///
/// Deeply nested widget trees are hard to read, maintain, and debug.
/// They often indicate a need to extract widgets into separate components.
///
/// **BAD:**
/// ```dart
/// Widget build(BuildContext context) {
///   return A(child: B(child: C(child: D(child: E(child: F(child: G(
///     child: H(child: I(child: J(child: K(child: L(child: M(child: N(
///       child: O(child: P()), // 16 levels deep!
///     ))))))))))))));
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// Widget build(BuildContext context) {
///   return A(
///     child: B(
///       child: _buildContent(),
///     ),
///   );
/// }
///
/// Widget _buildContent() {
///   return C(child: D(child: E()));
/// }
/// ```
class RequirePhysicsForNestedScrollRule extends SaropaLintRule {
  RequirePhysicsForNestedScrollRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    'require_physics_for_nested_scroll',
    '[require_physics_for_nested_scroll] Nested scrollable widget lacks NeverScrollableScrollPhysics, causing competing scroll gestures between parent and child. This produces unpredictable scroll behavior, jank, and a confusing user experience where swipes affect the wrong scrollable. {v3}',
    correctionMessage:
        'Add physics: NeverScrollableScrollPhysics() to the inner scrollable so only the parent scrollable responds to user gestures.',
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
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      final typeName = node.constructorName.type.name.lexeme;
      if (!_scrollableTypes.contains(typeName)) return;

      // Check if has physics parameter
      bool hasPhysics = false;
      for (final arg in node.argumentList.arguments) {
        if (arg is NamedExpression && arg.name.label.name == 'physics') {
          hasPhysics = true;
          break;
        }
      }

      if (hasPhysics) return;

      // Check if inside another scrollable
      AstNode? current = node.parent;
      int depth = 0;
      const maxDepth = 30;

      while (current != null && depth < maxDepth) {
        if (current is InstanceCreationExpression) {
          final parentType = current.constructorName.type.name.lexeme;
          if (_scrollableTypes.contains(parentType)) {
            reporter.atNode(node.constructorName, code);
            return;
          }
        }
        current = current.parent;
        depth++;
      }
    });
  }
}

/// Warns when Stack children are not wrapped in Positioned or Align.
///
/// Since: v2.3.10 | Updated: v4.13.0 | Rule version: v2
///
/// Non-first Stack children without explicit positioning use the Stack's
/// default alignment, which may produce unexpected overlap. The first child
/// is skipped because it typically defines the Stack's base size.
///
/// Common fill widgets (Container, SizedBox, DecoratedBox) are exempt
/// because they are frequently used as full-size overlays.
///
/// **BAD:**
/// ```dart
/// Stack(
///   children: [
///     Container(color: Colors.red),
///     Text('Overlay'), // Positioned at topStart by default
///   ],
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// Stack(
///   children: [
///     Container(color: Colors.red),
///     Positioned(bottom: 10, child: Text('Overlay')),
///   ],
/// )
/// ```
class AvoidExpandedOutsideFlexRule extends SaropaLintRule {
  AvoidExpandedOutsideFlexRule() : super(code: _code);

  /// Expanded/Flexible outside Flex causes runtime crash.
  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    'avoid_expanded_outside_flex',
    '[avoid_expanded_outside_flex] Expanded, Flexible, and Spacer set '
        'FlexParentData on their child, which only RenderFlex (Row, Column, '
        'Flex) can read during layout. Placing them inside any other parent '
        '— Stack, Center, Padding, LimitedBox, SizedBox, etc. — throws an '
        'unrecoverable "Incorrect use of ParentDataWidget" FlutterError at '
        'runtime. This also happens indirectly when a widget\'s build() '
        'returns Expanded and the widget is later wrapped by a non-Flex '
        'container, breaking the Flex→Expanded parent chain. {v7}',
    correctionMessage:
        'Move Expanded/Flexible/Spacer so it is a direct child of Row, '
        'Column, or Flex. If a reusable widget needs to expand, remove '
        'Expanded from its build() method and let the caller wrap it at '
        'the call site where the Flex parent is visible.',
    severity: DiagnosticSeverity.ERROR,
  );

  static const Set<String> _flexTypes = <String>{'Row', 'Column', 'Flex'};

  static const Set<String> _flexChildTypes = <String>{
    'Expanded',
    'Flexible',
    'Spacer',
  };

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      final String typeName = node.constructorName.type.name.lexeme;
      if (!_flexChildTypes.contains(typeName)) return;

      // Walk up to find parent widget
      AstNode? current = node.parent;
      bool foundFlexParent = false;
      bool assignedToVariable = false;
      bool passedThroughWidget = false;
      int depth = 0;

      while (current != null && depth < 20) {
        // If Expanded/Flexible is assigned to a variable, we can't track where
        // it's used - assume the developer will place it in a Flex widget.
        // Common pattern: final Widget x = condition ? Expanded(...) : Flexible(...);
        if (current is VariableDeclaration) {
          assignedToVariable = true;
          break;
        }

        // Trust Expanded in return statements of helper methods (not build).
        // Pattern: List<Widget> _buildChildren() => [Expanded(child: ...)];
        // These are typically used as children of Flex widgets at the call site.
        if (current is ReturnStatement) {
          final method = current.thisOrAncestorOfType<MethodDeclaration>();
          if (method != null && method.name.lexeme != 'build') {
            assignedToVariable = true;
            break;
          }
        }

        // Trust Expanded inside collection-building patterns like List.generate
        // or .map() - these almost always build children for Flex widgets.
        if (current is MethodInvocation) {
          final methodName = current.methodName.name;
          if (methodName == 'generate' || methodName == 'map') {
            assignedToVariable = true;
            break;
          }
        }

        // Trust Expanded returned from callbacks of collection builders
        // and named-parameter callbacks (e.g. builder: (ctx) => Expanded(...)).
        if (current is FunctionExpression) {
          final feParent = current.parent;

          // Named-parameter callbacks — placement depends on the call site.
          if (feParent is NamedExpression) {
            assignedToVariable = true;
            break;
          }

          // Positional args in .generate() / .map().
          if (feParent is ArgumentList) {
            final grandparent = feParent.parent;
            if (grandparent is MethodInvocation) {
              final methodName = grandparent.methodName.name;
              if (methodName == 'generate' || methodName == 'map') {
                assignedToVariable = true;
                break;
              }
            }
          }
        }

        if (current is InstanceCreationExpression) {
          passedThroughWidget = true;
          final String parentType = current.constructorName.type.name.lexeme;
          if (_flexTypes.contains(parentType)) {
            foundFlexParent = true;
            break;
          }
          // If we find a non-flex container, it might be wrong
          if (_isNonFlexContainer(parentType)) {
            break;
          }
        }
        // Stop at method/function boundaries.
        // Trust non-build methods and standalone functions — these
        // are helper methods that typically build children for Flex
        // widgets at the call site.
        // For build() with no intermediate widget wrapper,
        // prefer_expanded_at_call_site provides specific guidance.
        if (current is MethodDeclaration) {
          if (current.name.lexeme != 'build') {
            assignedToVariable = true;
          } else if (!passedThroughWidget) {
            assignedToVariable = true;
          }
          break;
        }
        if (current is FunctionDeclaration) {
          assignedToVariable = true;
          break;
        }
        current = current.parent;
        depth++;
      }

      // Only report if not inside a Flex AND not assigned to a variable
      if (!foundFlexParent && !assignedToVariable) {
        reporter.atNode(node.constructorName, code);
      }
    });
  }

  bool _isNonFlexContainer(String name) {
    return name == 'Stack' ||
        name == 'ListView' ||
        name == 'GridView' ||
        name == 'CustomScrollView';
  }
}

/// Warns when a widget's build() method returns Expanded/Flexible/Spacer.
///
/// Since: v3.0.0 | Updated: v4.13.0 | Rule version: v4
///
/// Alias: expanded_in_build, flexible_in_build
///
/// Returning Expanded/Flexible/Spacer from build() couples the widget to Flex
/// parents. If the widget is later wrapped (e.g., with Padding), it will crash
/// at runtime with a ParentDataWidget error.
/// Better design: let the caller add Expanded where needed.
///
/// **BAD:**
/// ```dart
/// class _MyWidget extends StatelessWidget {
///   Widget build(BuildContext context) => Expanded(
///     child: Column(children: [...]),
///   );
/// }
/// // Risk: Row(children: [_MyWidget().withPadding(...)]) crashes!
/// ```
///
/// **GOOD:**
/// ```dart
/// class _MyWidget extends StatelessWidget {
///   Widget build(BuildContext context) => Column(
///     mainAxisSize: MainAxisSize.min,
///     children: [...],
///   );
/// }
/// // Caller controls: Row(children: [Expanded(child: _MyWidget())])
/// ```
///
/// **Quick fix available:** Unwraps Expanded/Flexible and returns the child
/// directly. Not available for Spacer (no child to extract).
///
/// ## When to Ignore
///
/// Use `// ignore: prefer_expanded_at_call_site` if the widget is intentionally
/// designed to always be a direct Flex child and will never be wrapped.
class PreferExpandedAtCallSiteRule extends SaropaLintRule {
  PreferExpandedAtCallSiteRule() : super(code: _code);

  /// Expanded/Flexible/Spacer in build() causes runtime crash if misused.
  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => <FileType>{FileType.widget};

  static const LintCode _code = LintCode(
    'prefer_expanded_at_call_site',
    '[prefer_expanded_at_call_site] Expanded/Flexible/Spacer returned from build() forces flex layout on all callers, breaking reuse in non-flex contexts. '
        'If this widget is placed inside a Stack, SingleChildScrollView, or any non-flex parent, the Expanded wrapper triggers a runtime ParentDataWidget error and crashes the app. {v4}',
    correctionMessage:
        'Return the child widget directly and let the caller wrap with Expanded or Flexible as needed. '
        'This keeps the widget reusable in any layout context (Row, Column, Stack, etc.) and follows the principle of letting the parent control how its children are sized and positioned.',
    severity: DiagnosticSeverity.ERROR,
  );

  static const Set<String> _flexChildTypes = <String>{
    'Expanded',
    'Flexible',
    'Spacer',
  };
  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodDeclaration((MethodDeclaration node) {
      // Only check build() methods
      if (node.name.lexeme != 'build') return;

      // Check all return expressions in the method
      _checkReturnExpressions(node, reporter);
    });
  }

  /// Checks all return expressions in a method for Expanded/Flexible.
  void _checkReturnExpressions(
    MethodDeclaration node,
    SaropaDiagnosticReporter reporter,
  ) {
    final FunctionBody body = node.body;

    // Expression body: Widget build(context) => Expanded(...);
    if (body is ExpressionFunctionBody) {
      _checkExpression(body.expression, reporter);
      return;
    }

    // Block body: check ALL return statements
    if (body is BlockFunctionBody) {
      _visitStatements(body.block.statements, reporter);
    }
  }

  /// Recursively visits statements to find all return statements.
  void _visitStatements(
    NodeList<Statement> statements,
    SaropaDiagnosticReporter reporter,
  ) {
    for (final Statement statement in statements) {
      if (statement is ReturnStatement && statement.expression != null) {
        _checkExpression(statement.expression!, reporter);
      } else if (statement is IfStatement) {
        // Check both branches of if statements
        final thenStmt = statement.thenStatement;
        final elseStmt = statement.elseStatement;
        if (thenStmt is Block) {
          _visitStatements(thenStmt.statements, reporter);
        } else if (thenStmt is ReturnStatement && thenStmt.expression != null) {
          _checkExpression(thenStmt.expression!, reporter);
        }
        if (elseStmt is Block) {
          _visitStatements(elseStmt.statements, reporter);
        } else if (elseStmt is ReturnStatement && elseStmt.expression != null) {
          _checkExpression(elseStmt.expression!, reporter);
        }
      }
    }
  }

  /// Checks an expression for direct Expanded/Flexible usage.
  void _checkExpression(Expression expr, SaropaDiagnosticReporter reporter) {
    // Direct Expanded/Flexible construction
    if (expr is InstanceCreationExpression) {
      final String typeName = expr.constructorName.type.name.lexeme;
      if (_flexChildTypes.contains(typeName)) {
        reporter.atNode(expr.constructorName, code);
      }
    }
    // Conditional: return cond ? Expanded(...) : Other(...)
    else if (expr is ConditionalExpression) {
      _checkExpression(expr.thenExpression, reporter);
      _checkExpression(expr.elseExpression, reporter);
    }
  }
}

/// Quick fix for prefer_expanded_at_call_site.
///
/// Unwraps the Expanded/Flexible and returns the child directly.
/// For Spacer (no child argument), no fix is offered.

// =============================================================================
// NEW RULES v2.3.11
// =============================================================================

// cspell:ignore itembuilder

/// Warns when ListView.builder itemBuilder may access index out of bounds.
///
/// Since: v2.3.11 | Updated: v4.13.0 | Rule version: v6
///
/// Alias: builder_bounds, itembuilder_bounds, list_index_check
///
/// When itemCount is based on a variable that might change, accessing
/// the underlying list directly in itemBuilder can cause index out of bounds.
///
/// **BAD:**
/// ```dart
/// ListView.builder(
///   itemCount: items.length,
///   itemBuilder: (context, index) {
///     return Text(items[index].name); // items might change!
///   },
/// );
/// ```
///
/// **GOOD:**
/// ```dart
/// ListView.builder(
///   itemCount: items.length,
///   itemBuilder: (context, index) {
///     if (index >= items.length) return SizedBox.shrink();
///     return Text(items[index].name);
///   },
/// );
/// ```
///
/// **Note:** When using multiple lists of the same length in itemBuilder, ensure
/// each list access has a visible bounds check, or use an ignore comment if
/// you've ensured the lists are synchronized. The lint cannot detect cross-method
/// relationships like `List.generate(otherList.length, ...)`.
// =========================================================================
// Shared helper: Widget ancestor walking
// =========================================================================

enum _AncestorResult { found, wrongParent, indeterminate, notFound }

_AncestorResult _findWidgetAncestor(
  AstNode startNode, {
  required Set<String> targetParents,
  Set<String> stopAt = const <String>{},
  bool checkSuperTypes = false,
  int maxDepth = 20,
}) {
  AstNode? current = startNode.parent;
  int depth = 0;
  bool passedThroughWidget = false;

  while (current != null && depth < maxDepth) {
    if (current is VariableDeclaration) return _AncestorResult.indeterminate;
    if (current is AssignmentExpression) return _AncestorResult.indeterminate;
    if (current is ReturnStatement) {
      final method = current.thisOrAncestorOfType<MethodDeclaration>();
      if (method != null && method.name.lexeme != 'build') {
        return _AncestorResult.indeterminate;
      }
    }
    if (current is MethodInvocation) {
      final name = current.methodName.name;
      if (name == 'generate' || name == 'map') {
        return _AncestorResult.indeterminate;
      }
    }
    if (current is FunctionExpression) {
      final feParent = current.parent;
      if (feParent is NamedExpression) return _AncestorResult.indeterminate;
      if (feParent is ArgumentList) {
        final grandparent = feParent.parent;
        if (grandparent is MethodInvocation) {
          final name = grandparent.methodName.name;
          if (name == 'generate' || name == 'map') {
            return _AncestorResult.indeterminate;
          }
        }
      }
    }
    if (current is InstanceCreationExpression) {
      final String parentType = current.constructorName.type.name.lexeme;
      if (targetParents.contains(parentType)) return _AncestorResult.found;
      if (stopAt.contains(parentType)) return _AncestorResult.wrongParent;
      if (checkSuperTypes) {
        if (_isSubtypeOfAny(current.staticType, targetParents)) {
          return _AncestorResult.found;
        }
      }
      passedThroughWidget = true;
    }
    if (current is MethodDeclaration) {
      if (current.name.lexeme != 'build') {
        return _AncestorResult.indeterminate;
      }
      if (!passedThroughWidget) return _AncestorResult.indeterminate;
      break;
    }
    if (current is FunctionDeclaration) return _AncestorResult.indeterminate;
    current = current.parent;
    depth++;
  }
  return _AncestorResult.notFound;
}

bool _isSubtypeOfAny(DartType? type, Set<String> targetNames) {
  if (type is! InterfaceType) return false;
  for (final InterfaceType supertype in type.allSupertypes) {
    if (targetNames.contains(supertype.element.name)) return true;
  }
  return false;
}

const Set<String> _constraintWrappers = <String>{
  'Expanded',
  'Flexible',
  'SizedBox',
  'ConstrainedBox',
  'LimitedBox',
};

class AvoidSpacerInWrapRule extends SaropaLintRule {
  AvoidSpacerInWrapRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    'avoid_spacer_in_wrap',
    '[avoid_spacer_in_wrap] Spacer/Expanded inside Wrap causes a '
        'flex paradox crash. Wrap does not support flex-based sizing. {v3}',
    correctionMessage: 'Use SizedBox or Padding for spacing inside Wrap.',
    severity: DiagnosticSeverity.ERROR,
  );

  static const Set<String> _triggerWidgets = <String>{
    'Spacer',
    'Expanded',
    'Flexible',
  };

  static const Set<String> _validFlexParents = <String>{
    'Row',
    'Column',
    'Flex',
  };

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      final String typeName = node.constructorName.type.name.lexeme;
      if (!_triggerWidgets.contains(typeName)) return;

      // Walk up: if we find Wrap before Row/Column/Flex, it's a violation.
      final result = _findWidgetAncestor(
        node,
        targetParents: _validFlexParents,
        stopAt: const <String>{'Wrap'},
      );

      if (result == _AncestorResult.wrongParent) {
        reporter.atNode(node.constructorName, code);
      }
    });
  }
}

// =========================================================================
// Rule: avoid_scrollable_in_intrinsic
// =========================================================================

/// Warns when a scrollable widget is placed inside `IntrinsicHeight` or
///
/// Since: v4.9.14 | Updated: v4.13.0 | Rule version: v2
///
/// `IntrinsicWidth`.
///
/// `IntrinsicHeight`/`IntrinsicWidth` require children to report their
/// "natural" size. Scrollable widgets have no natural size (they are
/// potentially infinite), causing a geometry loop crash.
///
/// **BAD:**
/// ```dart
/// IntrinsicHeight(child: ListView(...)) // Crash!
/// ```
///
/// **GOOD:**
/// ```dart
/// SizedBox(height: 200, child: ListView(...))
/// ```
class AvoidScrollableInIntrinsicRule extends SaropaLintRule {
  AvoidScrollableInIntrinsicRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    'avoid_scrollable_in_intrinsic',
    '[avoid_scrollable_in_intrinsic] Scrollable widget inside '
        'IntrinsicHeight/IntrinsicWidth causes a geometry loop crash. '
        'Scrollables have no natural size. {v2}',
    correctionMessage: 'Use SizedBox with explicit dimensions instead of '
        'IntrinsicHeight/IntrinsicWidth around scrollable widgets.',
    severity: DiagnosticSeverity.ERROR,
  );

  static const Set<String> _scrollableTypes = <String>{
    'ListView',
    'GridView',
    'CustomScrollView',
    'SingleChildScrollView',
    'PageView',
  };

  static const Set<String> _intrinsicTypes = <String>{
    'IntrinsicHeight',
    'IntrinsicWidth',
  };

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      final String typeName = node.constructorName.type.name.lexeme;
      if (!_scrollableTypes.contains(typeName)) return;

      final result = _findWidgetAncestor(node, targetParents: _intrinsicTypes);

      // Here, finding the target parent means BAD (scrollable inside intrinsic).
      if (result == _AncestorResult.found) {
        reporter.atNode(node.constructorName, code);
      }
    });
  }
}

// =========================================================================
// Rule: require_baseline_text_baseline
// =========================================================================

/// Warns when `Row` or `Column` uses `CrossAxisAlignment.baseline`
///
/// Since: v4.9.14 | Updated: v4.13.0 | Rule version: v2
///
/// without specifying the `textBaseline` property.
///
/// Flutter requires a `textBaseline` value to know whether to use
/// alphabetic or ideographic baseline alignment. Omitting it causes
/// an assertion failure at runtime.
///
/// **BAD:**
/// ```dart
/// Row(
///   crossAxisAlignment: CrossAxisAlignment.baseline,
///   children: [Text('a'), Text('b')],
/// ) // Assertion failure!
/// ```
///
/// **GOOD:**
/// ```dart
/// Row(
///   crossAxisAlignment: CrossAxisAlignment.baseline,
///   textBaseline: TextBaseline.alphabetic,
///   children: [Text('a'), Text('b')],
/// )
/// ```
class AvoidUnboundedListviewInColumnRule extends SaropaLintRule {
  AvoidUnboundedListviewInColumnRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    'avoid_unbounded_listview_in_column',
    '[avoid_unbounded_listview_in_column] Scrollable widget inside '
        'a Column without Expanded/Flexible causes an unbounded '
        'constraints crash. {v3}',
    correctionMessage:
        'Wrap the scrollable widget in Expanded or Flexible, or use '
        'shrinkWrap: true (with performance cost).',
    severity: DiagnosticSeverity.ERROR,
  );

  static const Set<String> _scrollableTypes = <String>{
    'ListView',
    'GridView',
    'CustomScrollView',
  };

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      final String typeName = node.constructorName.type.name.lexeme;
      if (!_scrollableTypes.contains(typeName)) return;

      // If shrinkWrap: true is set, the scrollable has bounded height.
      if (_hasShrinkWrap(node)) return;

      // Walk up checking for Column, skipping constraint wrappers.
      AstNode? current = node.parent;
      bool wrappedInConstraint = false;
      int depth = 0;

      while (current != null && depth < 20) {
        if (current is VariableDeclaration) return;
        if (current is MethodDeclaration) {
          if (current.name.lexeme != 'build') return;
          break;
        }
        if (current is FunctionDeclaration) return;

        // Stop at callback boundaries — the callback's return value
        // is placed by the receiving widget, not by the widget's own
        // ancestors. Skip 'builder' which is the standard Flutter
        // pass-through pattern (Builder, LayoutBuilder, etc.).
        if (current is FunctionExpression) {
          final feParent = current.parent;
          if (feParent is NamedExpression) {
            final paramName = feParent.name.label.name;
            if (paramName != 'builder') {
              final argList = feParent.parent;
              if (argList is ArgumentList &&
                  argList.parent is InstanceCreationExpression) {
                return;
              }
            }
          }
        }

        if (current is InstanceCreationExpression) {
          final String parentType = current.constructorName.type.name.lexeme;
          if (_constraintWrappers.contains(parentType)) {
            wrappedInConstraint = true;
          }
          if (parentType == 'Column') {
            if (!wrappedInConstraint) {
              reporter.atNode(node.constructorName, code);
            }
            return;
          }
          // Stop at other scroll containers -- different issue.
          if (parentType == 'Row' || parentType == 'Flex') return;
        }

        current = current.parent;
        depth++;
      }
    });
  }

  static bool _hasShrinkWrap(InstanceCreationExpression node) {
    for (final Expression arg in node.argumentList.arguments) {
      if (arg is NamedExpression && arg.name.label.name == 'shrinkWrap') {
        final String value = arg.expression.toSource();
        if (value == 'true') return true;
      }
    }
    return false;
  }
}

// =========================================================================
// Rule: avoid_textfield_in_row
// =========================================================================

/// Warns when `TextField` or `TextFormField` is placed inside a `Row`
///
/// Since: v4.9.14 | Updated: v4.13.0 | Rule version: v3
///
/// without width constraints.
///
/// `TextField` tries to expand to fill its parent's width. `Row` provides
/// unbounded width to its children. This causes an unbounded width crash.
///
/// **BAD:**
/// ```dart
/// Row(children: [Icon(Icons.search), TextField()]) // Crash!
/// ```
///
/// **GOOD:**
/// ```dart
/// Row(children: [Icon(Icons.search), Expanded(child: TextField())])
/// ```
class PreferFlexForComplexLayoutRule extends SaropaLintRule {
  PreferFlexForComplexLayoutRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'prefer_flex_for_complex_layout',
    '[prefer_flex_for_complex_layout] Prefer Row/Column (Flex) with '
        'Expanded/Flexible for complex layouts instead of deep nesting.',
    correctionMessage:
        'Use Flex, Expanded, and Flexible for predictable layout behavior.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {}
}

// =============================================================================
// prefer_find_child_index_callback
// =============================================================================

/// Prefer findChildIndexCallback in ListView.builder for stable indices.
class PreferFindChildIndexCallbackRule extends SaropaLintRule {
  PreferFindChildIndexCallbackRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'prefer_find_child_index_callback',
    '[prefer_find_child_index_callback] Use findChildIndexCallback in '
        'ListView.builder when item order can change (e.g. reordering) for '
        'correct scroll-to-index behavior.',
    correctionMessage: 'Add findChildIndexCallback when list order is dynamic.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {}
}

// =========================================================================
// Shared quick fix: Wrap in Expanded
// =========================================================================

/// Shared quick fix that wraps a widget in `Expanded(child: ...)`.
