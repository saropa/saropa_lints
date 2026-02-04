// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/error/error.dart'
    show AnalysisError, DiagnosticSeverity;
import 'package:analyzer/source/source_range.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../saropa_lint_rule.dart';

class AvoidExpandedAsSpacerRule extends SaropaLintRule {
  const AvoidExpandedAsSpacerRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    name: 'avoid_expanded_as_spacer',
    problemMessage:
        '[avoid_expanded_as_spacer] Use Spacer() instead of Expanded with empty child.',
    correctionMessage:
        'Replace Expanded(child: SizedBox/Container()) with Spacer().',
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
                reporter.atNode(node, code);
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
  const AvoidFlexibleOutsideFlexRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    name: 'avoid_flexible_outside_flex',
    problemMessage:
        '[avoid_flexible_outside_flex] The Flexible or Expanded widget is being used outside of a Row, Column, or Flex parent. This breaks layout expectations and can cause runtime errors or unexpected UI behavior, as Flexible/Expanded are only designed to work within Flex-based widgets. Using them elsewhere will not provide the intended flexible sizing and may result in layout exceptions.',
    correctionMessage:
        'Wrap Flexible or Expanded widgets only inside Row, Column, or Flex parents. Refactor your widget tree so that Flexible/Expanded are direct children of a Flex-based widget, ensuring proper layout behavior and avoiding runtime errors. See Flutter documentation on Flex widgets for correct usage patterns.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  static const Set<String> _flexibleWidgets = <String>{'Flexible', 'Expanded'};
  static const Set<String> _flexWidgets = <String>{'Row', 'Column', 'Flex'};

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addInstanceCreationExpression((
      InstanceCreationExpression node,
    ) {
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
          reporter.atNode(node, code);
          return;
        }
        current = current.parent;
      }

      // Reached top without finding Flex parent
      reporter.atNode(node, code);
    });
  }
}

/// Warns when an Image widget is wrapped in Opacity instead of using Image.color.
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

class AvoidMisnamedPaddingRule extends SaropaLintRule {
  const AvoidMisnamedPaddingRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    name: 'avoid_misnamed_padding',
    problemMessage:
        '[avoid_misnamed_padding] A parameter or field named "padding" is being used to provide margin (spacing outside a widget) rather than actual padding (spacing inside a widget). This can confuse maintainers and lead to incorrect UI adjustments, as padding and margin serve distinct layout purposes in Flutter.',
    correctionMessage:
        'Rename the parameter or field to "margin" if it is used to control space outside the widget, or refactor the code to use it for true padding (space inside the widget). Ensure naming accurately reflects the widget’s layout intent to improve code clarity and maintainability. See Flutter layout documentation for guidance.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
      // Check if class extends StatelessWidget or StatefulWidget
      if (!_isWidgetClass(node)) {
        return;
      }

      // Find "padding" fields
      final List<FieldDeclaration> paddingFields = <FieldDeclaration>[];
      for (final ClassMember member in node.members) {
        if (member is FieldDeclaration) {
          for (final VariableDeclaration variable in member.fields.variables) {
            if (variable.name.lexeme == 'padding') {
              paddingFields.add(member);
            }
          }
        }
      }

      if (paddingFields.isEmpty) {
        return;
      }

      // Check build method for misuse patterns
      for (final ClassMember member in node.members) {
        if (member is MethodDeclaration && member.name.lexeme == 'build') {
          final _PaddingMisuseVisitor visitor = _PaddingMisuseVisitor();
          member.accept(visitor);

          if (visitor.hasMisuse) {
            // Report on the padding field declaration
            for (final FieldDeclaration paddingField in paddingFields) {
              reporter.atNode(paddingField.fields, code);
            }
          }
        }
      }
    });
  }

  /// Check if a class extends a Widget class
  bool _isWidgetClass(ClassDeclaration node) {
    final ExtendsClause? extendsClause = node.extendsClause;
    if (extendsClause == null) {
      return false;
    }

    final String superclassName = extendsClause.superclass.name.lexeme;
    return superclassName == 'StatelessWidget' ||
        superclassName == 'StatefulWidget' ||
        superclassName.endsWith('Widget');
  }
}

/// Visitor that detects if "padding" parameter is used as margin
class _PaddingMisuseVisitor extends RecursiveAstVisitor<void> {
  bool hasMisuse = false;

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    // Check for: Padding(padding: padding, ...)
    final String constructorName = node.constructorName.type.name.lexeme;
    if (constructorName == 'Padding') {
      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression && arg.name.label.name == 'padding') {
          final String valueSource = arg.expression.toSource();
          // Check if it references the "padding" field
          if (valueSource == 'padding' ||
              valueSource.startsWith('padding ') ||
              valueSource.startsWith('padding?') ||
              valueSource.contains('widget.padding')) {
            hasMisuse = true;
          }
        }
      }
    }
    super.visitInstanceCreationExpression(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    // Check for: .withPadding(padding)
    if (node.methodName.name == 'withPadding') {
      for (final Expression arg in node.argumentList.arguments) {
        final String argSource = arg.toSource();
        if (argSource == 'padding' ||
            argSource.startsWith('padding ') ||
            argSource.contains('widget.padding')) {
          hasMisuse = true;
        }
      }
    }
    super.visitMethodInvocation(node);
  }
}

/// Warns when Image widget is missing semanticLabel (alt text).
///
/// Example of **bad** code:
/// ```dart
/// Image.asset('logo.png')  // No semantic label
/// ```
///
/// Example of **good** code:
/// ```dart
/// Image.asset(
///   'logo.png',
///   semanticLabel: 'Company logo',
/// )
/// ```

class AvoidShrinkWrapInListsRule extends SaropaLintRule {
  const AvoidShrinkWrapInListsRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_shrink_wrap_in_lists',
    problemMessage:
        "[avoid_shrink_wrap_in_lists] Using 'shrinkWrap: true' inside a nested scrollable (such as a ListView within another scrollable) can cause significant performance issues. It forces the inner list to compute the size of all its children, leading to poor scroll performance and increased memory usage, especially with large or dynamic lists.",
    correctionMessage:
        'Avoid using shrinkWrap: true in nested scrollables. Instead, provide a fixed height for the inner list using SizedBox, or use Expanded/Flexible within a Flex parent. This ensures efficient rendering and smooth scrolling. See Flutter documentation for guidance on nested scrollables and performance best practices.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  static const Set<String> _scrollableWidgets = <String>{
    'ListView',
    'GridView',
    'CustomScrollView',
    'SingleChildScrollView',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry
        .addInstanceCreationExpression((InstanceCreationExpression node) {
      final String? constructorName = node.constructorName.type.element?.name;
      if (constructorName == null) return;

      if (!_scrollableWidgets.contains(constructorName)) return;

      // Check for shrinkWrap: true
      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression &&
            arg.name.label.name == 'shrinkWrap' &&
            arg.expression is BooleanLiteral &&
            (arg.expression as BooleanLiteral).value) {
          // Check if inside another scrollable
          AstNode? parent = node.parent;
          while (parent != null) {
            if (parent is InstanceCreationExpression) {
              final String? parentConstructor =
                  parent.constructorName.type.element?.name;
              if (parentConstructor != null &&
                  _scrollableWidgets.contains(parentConstructor)) {
                reporter.atNode(arg, code);
                return;
              }
            }
            parent = parent.parent;
          }
        }
      }
    });
  }
}

/// Warns when a Column or Row has only a single child.
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
  const AvoidSingleChildColumnRowRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    name: 'avoid_single_child_column_row',
    problemMessage:
        '[avoid_single_child_column_row] Column/Row with single child is unnecessary.',
    correctionMessage: 'Use the child directly or Align/Center for alignment.',
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

class AvoidWrappingInPaddingRule extends SaropaLintRule {
  const AvoidWrappingInPaddingRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    name: 'avoid_wrapping_in_padding',
    problemMessage:
        '[avoid_wrapping_in_padding] Widget has its own padding property, avoid wrapping in Padding.',
    correctionMessage: 'Use the padding property of the child widget instead.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  static const Set<String> _widgetsWithPadding = <String>{
    'Container',
    'Card',
    'ListTile',
    'GridTile',
    'Chip',
    'ActionChip',
    'ChoiceChip',
    'FilterChip',
    'InputChip',
    'ElevatedButton',
    'TextButton',
    'OutlinedButton',
    'IconButton',
    'FloatingActionButton',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry
        .addInstanceCreationExpression((InstanceCreationExpression node) {
      final String typeName = node.constructorName.type.name.lexeme;
      if (typeName != 'Padding') return;

      // Find the child argument
      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression && arg.name.label.name == 'child') {
          final Expression childExpr = arg.expression;
          if (childExpr is InstanceCreationExpression) {
            final String childType = childExpr.constructorName.type.name.lexeme;
            if (_widgetsWithPadding.contains(childType)) {
              reporter.atNode(node, code);
            }
          }
        }
      }
    });
  }
}

/// Warns when RenderObject setters don't check for equality.
///
/// RenderObject property setters should check if the new value equals
/// the old value before updating and marking needs layout/paint.
///
/// Example of **bad** code:
/// ```dart
/// set color(Color value) {
///   _color = value;
///   markNeedsPaint();
/// }
/// ```
///
/// Example of **good** code:
/// ```dart
/// set color(Color value) {
///   if (_color == value) return;
///   _color = value;
///   markNeedsPaint();
/// }
/// ```

class CheckForEqualsInRenderObjectSettersRule extends SaropaLintRule {
  const CheckForEqualsInRenderObjectSettersRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'check_for_equals_in_render_object_setters',
    problemMessage:
        '[check_for_equals_in_render_object_setters] RenderObject setter should check equality before updating.',
    correctionMessage:
        'Add equality check: if (_field == value) return; before assignment.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
      // Check if this class extends RenderObject or similar
      final ExtendsClause? extendsClause = node.extendsClause;
      if (extendsClause == null) return;

      final String? superName = extendsClause.superclass.element?.name;
      if (superName == null) return;

      // Common RenderObject subclasses
      if (!superName.startsWith('Render') && superName != 'RenderObject') {
        return;
      }

      // Check each setter
      for (final ClassMember member in node.members) {
        if (member is MethodDeclaration && member.isSetter) {
          _checkSetter(member, reporter);
        }
      }
    });
  }

  void _checkSetter(
      MethodDeclaration setter, SaropaDiagnosticReporter reporter) {
    final FunctionBody body = setter.body;

    // Check if setter has markNeeds* call
    bool hasMarkNeeds = false;
    bool hasEqualityCheck = false;

    body.visitChildren(
      _RenderObjectSetterVisitor(
        onMarkNeeds: () => hasMarkNeeds = true,
        onEqualityCheck: () => hasEqualityCheck = true,
      ),
    );

    // If it has markNeeds but no equality check, warn
    if (hasMarkNeeds && !hasEqualityCheck) {
      reporter.atNode(setter, code);
    }
  }
}

class _RenderObjectSetterVisitor extends RecursiveAstVisitor<void> {
  _RenderObjectSetterVisitor({
    required this.onMarkNeeds,
    required this.onEqualityCheck,
  });

  final void Function() onMarkNeeds;
  final void Function() onEqualityCheck;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final String name = node.methodName.name;
    if (name.startsWith('markNeeds')) {
      onMarkNeeds();
    }
    super.visitMethodInvocation(node);
  }

  @override
  void visitIfStatement(IfStatement node) {
    // Check for equality comparison in condition
    final Expression condition = node.expression;
    if (condition is BinaryExpression) {
      if (condition.operator.type == TokenType.EQ_EQ) {
        onEqualityCheck();
      }
    }
    super.visitIfStatement(node);
  }
}

/// Warns when updateRenderObject doesn't update all properties set in createRenderObject.
///
/// When a RenderObjectWidget creates a RenderObject with properties, the
/// updateRenderObject method should update all those same properties.
///
/// Example of **bad** code:
/// ```dart
/// class MyWidget extends LeafRenderObjectWidget {
///   final Color color;
///   final double size;
///
///   @override
///   RenderObject createRenderObject(BuildContext context) {
///     return MyRenderObject()
///       ..color = color
///       ..size = size;
///   }
///
///   @override
///   void updateRenderObject(BuildContext context, MyRenderObject renderObject) {
///     renderObject.color = color;  // Missing size update!
///   }
/// }
/// ```
///
/// Example of **good** code:
/// ```dart
/// class MyWidget extends LeafRenderObjectWidget {
///   final Color color;
///   final double size;
///
///   @override
///   RenderObject createRenderObject(BuildContext context) {
///     return MyRenderObject()
///       ..color = color
///       ..size = size;
///   }
///
///   @override
///   void updateRenderObject(BuildContext context, MyRenderObject renderObject) {
///     renderObject
///       ..color = color
///       ..size = size;
///   }
/// }
/// ```

class ConsistentUpdateRenderObjectRule extends SaropaLintRule {
  const ConsistentUpdateRenderObjectRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    name: 'consistent_update_render_object',
    problemMessage:
        '[consistent_update_render_object] updateRenderObject may be missing property updates from createRenderObject.',
    correctionMessage:
        'Ensure all properties set in createRenderObject are also updated in updateRenderObject.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  static const Set<String> _renderObjectWidgetBases = <String>{
    'LeafRenderObjectWidget',
    'SingleChildRenderObjectWidget',
    'MultiChildRenderObjectWidget',
    'RenderObjectWidget',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
      // Check if this is a RenderObjectWidget subclass
      final ExtendsClause? extendsClause = node.extendsClause;
      if (extendsClause == null) return;

      final String? superName = extendsClause.superclass.element?.name;
      if (superName == null || !_renderObjectWidgetBases.contains(superName)) {
        return;
      }

      // Find createRenderObject and updateRenderObject methods
      MethodDeclaration? createMethod;
      MethodDeclaration? updateMethod;

      for (final ClassMember member in node.members) {
        if (member is MethodDeclaration) {
          if (member.name.lexeme == 'createRenderObject') {
            createMethod = member;
          } else if (member.name.lexeme == 'updateRenderObject') {
            updateMethod = member;
          }
        }
      }

      // If no createRenderObject, nothing to check
      if (createMethod == null) return;

      // Collect properties set in createRenderObject
      final Set<String> createProperties = <String>{};
      createMethod.body.visitChildren(
        _PropertyAssignmentFinder((String name) {
          createProperties.add(name);
        }),
      );

      // If no properties set, nothing to check
      if (createProperties.isEmpty) return;

      // If updateRenderObject is missing, warn
      if (updateMethod == null) {
        reporter.atNode(node, code);
        return;
      }

      // Collect properties set in updateRenderObject
      final Set<String> updateProperties = <String>{};
      updateMethod.body.visitChildren(
        _PropertyAssignmentFinder((String name) {
          updateProperties.add(name);
        }),
      );

      // Check if any createRenderObject properties are missing in updateRenderObject
      final Set<String> missingProperties =
          createProperties.difference(updateProperties);
      if (missingProperties.isNotEmpty) {
        reporter.atNode(updateMethod, code);
      }
    });
  }
}

class _PropertyAssignmentFinder extends RecursiveAstVisitor<void> {
  _PropertyAssignmentFinder(this.onProperty);
  final void Function(String) onProperty;

  @override
  void visitAssignmentExpression(AssignmentExpression node) {
    // Look for property assignments like renderObject.color = value
    // or cascades like ..color = value
    final Expression leftSide = node.leftHandSide;
    if (leftSide is PrefixedIdentifier) {
      onProperty(leftSide.identifier.name);
    } else if (leftSide is PropertyAccess) {
      onProperty(leftSide.propertyName.name);
    }
    super.visitAssignmentExpression(node);
  }
}

/// Warns when non-const BorderRadius constructors are used.
///
/// Example of **bad** code:
/// ```dart
/// BorderRadius.circular(8)  // Not const
/// ```
///
/// Example of **good** code:
/// ```dart
/// const BorderRadius.all(Radius.circular(8))
/// ```

class PreferConstBorderRadiusRule extends SaropaLintRule {
  const PreferConstBorderRadiusRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    name: 'prefer_const_border_radius',
    problemMessage:
        '[prefer_const_border_radius] Prefer const BorderRadius.all for constant border radius.',
    correctionMessage:
        'Use const BorderRadius.all(Radius.circular(x)) instead.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      // Check for BorderRadius.circular
      final Expression? target = node.target;
      if (target is! SimpleIdentifier) return;
      if (target.name != 'BorderRadius') return;
      if (node.methodName.name != 'circular') return;

      // Check if it's already in a const context
      AstNode? current = node.parent;
      while (current != null) {
        if (current is InstanceCreationExpression && current.isConst) {
          return; // Already const
        }
        if (current is VariableDeclaration) {
          final AstNode? parent = current.parent;
          if (parent is VariableDeclarationList && parent.isConst) {
            return; // Variable is const
          }
        }
        current = current.parent;
      }

      reporter.atNode(node, code);
    });
  }
}

/// Warns when incorrect EdgeInsets constructor is used.
///
/// Suggests using more specific constructors when appropriate.
///
/// Example of **bad** code:
/// ```dart
/// EdgeInsets.fromLTRB(8, 8, 8, 8)  // Use .all instead
/// EdgeInsets.only(left: 8, right: 8)  // Use .symmetric instead
/// ```
///
/// Example of **good** code:
/// ```dart
/// EdgeInsets.all(8)
/// EdgeInsets.symmetric(horizontal: 8)
/// ```

class PreferCorrectEdgeInsetsConstructorRule extends SaropaLintRule {
  const PreferCorrectEdgeInsetsConstructorRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'prefer_correct_edge_insets_constructor',
    problemMessage:
        '[prefer_correct_edge_insets_constructor] Consider using a more specific EdgeInsets constructor.',
    correctionMessage:
        'Use .all() for equal values or .symmetric() for symmetric values.',
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
      final String typeName = node.constructorName.type.name.lexeme;
      if (typeName != 'EdgeInsets') return;

      final String? constructorName = node.constructorName.name?.name;

      if (constructorName == 'fromLTRB') {
        _checkFromLTRB(node, reporter);
      } else if (constructorName == 'only') {
        _checkOnly(node, reporter);
      }
    });
  }

  void _checkFromLTRB(
      InstanceCreationExpression node, SaropaDiagnosticReporter reporter) {
    final NodeList<Expression> args = node.argumentList.arguments;
    if (args.length != 4) return;

    // Get all values as strings
    final List<String> values =
        args.map((Expression e) => e.toSource()).toList();

    // Check if all values are the same (could use .all)
    if (values.toSet().length == 1) {
      reporter.atNode(node, code);
    }
    // Check if left==right and top==bottom (could use .symmetric)
    else if (values[0] == values[2] && values[1] == values[3]) {
      reporter.atNode(node, code);
    }
  }

  void _checkOnly(
      InstanceCreationExpression node, SaropaDiagnosticReporter reporter) {
    final NodeList<Expression> args = node.argumentList.arguments;

    // Extract named arguments
    String? left, right, top, bottom;
    for (final Expression arg in args) {
      if (arg is NamedExpression) {
        final String name = arg.name.label.name;
        final String value = arg.expression.toSource();
        switch (name) {
          case 'left':
            left = value;
          case 'right':
            right = value;
          case 'top':
            top = value;
          case 'bottom':
            bottom = value;
        }
      }
    }

    // Check if all present values are the same (could use .all)
    final List<String?> presentValues = <String?>[left, right, top, bottom]
        .where((String? v) => v != null)
        .toList();
    if (presentValues.length == 4 && presentValues.toSet().length == 1) {
      reporter.atNode(node, code);
    }
    // Check for symmetric patterns
    else if (left != null &&
        right != null &&
        left == right &&
        top == null &&
        bottom == null) {
      reporter.atNode(node, code);
    } else if (top != null &&
        bottom != null &&
        top == bottom &&
        left == null &&
        right == null) {
      reporter.atNode(node, code);
    }
  }
}

/// Warns when Hero widget is used without defining heroTag.
///
/// **Stylistic rule (opt-in only).** Naming convention with no performance or correctness impact.
///
/// Example of **bad** code:
/// ```dart
/// Hero(
///   child: Image.asset('image.png'),
/// )  // Missing heroTag
/// ```
///
/// Example of **good** code:
/// ```dart
/// Hero(
///   tag: 'my-hero-tag',
///   child: Image.asset('image.png'),
/// )
/// ```

class PreferSliverPrefixRule extends SaropaLintRule {
  const PreferSliverPrefixRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.opinionated;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    name: 'prefer_sliver_prefix',
    problemMessage:
        '[prefer_sliver_prefix] Prefixing sliver widget class names with Sliver is a naming convention. It does not affect widget behavior or performance. Enable via the stylistic tier.',
    correctionMessage:
        'Rename the class to start with "Sliver" (e.g., SliverHeader instead of Header) to communicate its sliver layout protocol.',
    errorSeverity: DiagnosticSeverity.INFO,
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
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
      final String className = node.name.lexeme;

      // Skip if already has Sliver prefix
      if (className.startsWith('Sliver')) return;

      // Check extends clause
      final ExtendsClause? extendsClause = node.extendsClause;
      if (extendsClause != null) {
        final String superclass = extendsClause.superclass.name.lexeme;
        if (_sliverBaseClasses.contains(superclass) ||
            superclass.startsWith('Sliver')) {
          reporter.atNode(node, code);
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
            reporter.atNode(node, code);
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
            reporter.atNode(node, code);
            return;
          }
        }
      }
    });
  }
}

/// Warns when RichText is used instead of Text.rich.
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
  const PreferUsingListViewRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'prefer_using_list_view',
    problemMessage:
        '[prefer_using_list_view] Column inside SingleChildScrollView. Consider using ListView.',
    correctionMessage:
        'Use ListView for better performance with scrollable lists.',
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
      final String typeName = node.constructorName.type.name.lexeme;
      if (typeName != 'SingleChildScrollView') return;

      // Find the child argument
      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression && arg.name.label.name == 'child') {
          final Expression childExpr = arg.expression;
          if (_isColumnOrRow(childExpr)) {
            reporter.atNode(node, code);
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

class AvoidBorderAllRule extends SaropaLintRule {
  const AvoidBorderAllRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    name: 'avoid_border_all',
    problemMessage:
        '[avoid_border_all] Prefer Border.fromBorderSide for const borders.',
    correctionMessage:
        'Use const Border.fromBorderSide(BorderSide(...)) instead.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      // Check for Border.all
      final Expression? target = node.target;
      if (target is! SimpleIdentifier) return;
      if (target.name != 'Border') return;
      if (node.methodName.name != 'all') return;

      reporter.atNode(node, code);
    });
  }
}

// =============================================================================
// FUTURE RULES
// =============================================================================

/// Future rule: avoid-deeply-nested-widgets
/// Warns when widget tree nesting exceeds a reasonable depth.
///
/// Deep nesting makes code hard to read and maintain. Extract subtrees
/// into separate widgets for better readability.
///
/// Example of **bad** code:
/// ```dart
/// return Container(
///   child: Padding(
///     child: Column(
///       children: [
///         Row(
///           children: [
///             Expanded(
///               child: Card(
///                 child: ListTile(
///                   title: Text('...'),  // Too deep!
///                 ),
///               ),
///             ),
///           ],
///         ),
///       ],
///     ),
///   ),
/// );
/// ```

class AvoidDeeplyNestedWidgetsRule extends SaropaLintRule {
  const AvoidDeeplyNestedWidgetsRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    name: 'avoid_deeply_nested_widgets',
    problemMessage:
        '[avoid_deeply_nested_widgets] Widget tree is too deeply nested.',
    correctionMessage:
        'Extract subtrees into separate widgets to improve readability.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  static const int _maxDepth = 8;

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodDeclaration((MethodDeclaration node) {
      if (node.name.lexeme != 'build') return;

      // Find nested widget depth
      final _WidgetDepthVisitor visitor =
          _WidgetDepthVisitor(_maxDepth, reporter, code);
      node.body.accept(visitor);
    });
  }
}

class _WidgetDepthVisitor extends RecursiveAstVisitor<void> {
  _WidgetDepthVisitor(this.maxDepth, this.reporter, this.code);

  final int maxDepth;
  final SaropaDiagnosticReporter reporter;
  final LintCode code;
  int _currentDepth = 0;
  bool _reported = false;

  // Cached patterns for performance - avoids 19 string comparisons per widget
  static const Set<String> _exactWidgetNames = <String>{
    'Text',
    'Icon',
    'Image',
  };

  static final RegExp _widgetSuffixPattern = RegExp(
    r'(Widget|Button|Text|Container|Card|Row|Column|Padding|Center|'
    r'Expanded|Flexible|SizedBox|Scaffold|AppBar|ListView|GridView|Stack)$',
  );

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    // Check if this looks like a widget (PascalCase name)
    final String typeName = node.constructorName.type.name.lexeme;
    if (_looksLikeWidget(typeName)) {
      _currentDepth++;

      if (_currentDepth > maxDepth && !_reported) {
        reporter.atNode(node, code);
        _reported = true;
      }

      super.visitInstanceCreationExpression(node);
      _currentDepth--;
    } else {
      super.visitInstanceCreationExpression(node);
    }
  }

  bool _looksLikeWidget(String name) {
    // O(1) lookup for exact matches, then single regex check for suffixes
    return _exactWidgetNames.contains(name) ||
        _widgetSuffixPattern.hasMatch(name);
  }
}

/// Warns when AnimationController is created without proper disposal.
///
/// Alias: require_animation_controller_dispose
///
/// Example of **bad** code:
/// ```dart
/// late AnimationController _controller;
/// @override
/// void initState() {
///   _controller = AnimationController(vsync: this);
/// }
/// // Missing dispose!
/// ```
///
/// Example of **good** code:
/// ```dart
/// late AnimationController _controller;
/// @override
/// void initState() {
///   _controller = AnimationController(vsync: this);
/// }
/// @override
/// void dispose() {
///   _controller.dispose();
///   super.dispose();
/// }
/// ```

class PreferConstWidgetsInListsRule extends SaropaLintRule {
  const PreferConstWidgetsInListsRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'prefer_const_widgets_in_lists',
    problemMessage:
        '[prefer_const_widgets_in_lists] Widget list recreated on every rebuild. If elements are constant, the entire list can be const.',
    correctionMessage: 'Add const keyword: const [Text("a"), Text("b")].',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addListLiteral((ListLiteral node) {
      // Skip if already explicitly const
      if (node.constKeyword != null) return;

      // Skip if implicitly const (const declaration, enum, etc.)
      if (_isInConstContext(node)) return;

      // Skip if the list element type is not a Widget subclass
      if (!_isWidgetListType(node)) return;

      // Check if all elements are potentially const widgets
      bool allPotentiallyConst = true;
      bool hasWidgets = false;

      for (final CollectionElement element in node.elements) {
        if (element is InstanceCreationExpression) {
          hasWidgets = true;
          // Check if it's already marked const
          if (element.keyword?.type != Keyword.CONST) {
            // Check if constructor could be const
            if (!_couldBeConst(element)) {
              allPotentiallyConst = false;
              break;
            }
          }
        } else if (element is! SpreadElement) {
          allPotentiallyConst = false;
          break;
        }
      }

      if (hasWidgets && allPotentiallyConst && node.elements.isNotEmpty) {
        reporter.atNode(node, code);
      }
    });
  }

  /// Check if the list's element type is a Widget subclass.
  bool _isWidgetListType(ListLiteral node) {
    final TypeArgumentList? typeArgs = node.typeArguments;
    if (typeArgs != null && typeArgs.arguments.isNotEmpty) {
      final DartType? listElementType = typeArgs.arguments.first.type;
      if (listElementType != null) {
        return _isWidgetType(listElementType);
      }
    }

    // No explicit type argument — check first element's static type
    for (final CollectionElement element in node.elements) {
      if (element is InstanceCreationExpression) {
        final DartType? type = element.staticType;
        if (type != null) return _isWidgetType(type);
      }
    }

    return false;
  }

  /// Returns true if [type] is or extends Widget from Flutter.
  bool _isWidgetType(DartType type) {
    if (type is! InterfaceType) return false;
    for (InterfaceType? t = type; t != null;) {
      if (t.element.name == 'Widget' &&
          t.element.library.identifier.startsWith('package:flutter/')) {
        return true;
      }
      t = t.element.supertype;
    }
    return false;
  }

  /// Check if a node is within a const context (const declaration,
  /// const constructor, enum body, annotation, or const collection).
  bool _isInConstContext(AstNode node) {
    AstNode? current = node.parent;
    while (current != null) {
      if (current is VariableDeclarationList && current.isConst) {
        return true;
      }
      if (current is InstanceCreationExpression && current.isConst) {
        return true;
      }
      if (current is EnumDeclaration) return true;
      if (current is Annotation) return true;
      if (current is ListLiteral && current.constKeyword != null) {
        return true;
      }
      if (current is SetOrMapLiteral && current.constKeyword != null) {
        return true;
      }
      current = current.parent;
    }
    return false;
  }

  bool _couldBeConst(InstanceCreationExpression node) {
    for (final Expression arg in node.argumentList.arguments) {
      if (arg is NamedExpression) {
        if (!_isConstExpression(arg.expression)) return false;
      } else if (!_isConstExpression(arg)) {
        return false;
      }
    }
    return true;
  }

  bool _isConstExpression(Expression expr) {
    return expr is IntegerLiteral ||
        expr is DoubleLiteral ||
        expr is StringLiteral ||
        expr is BooleanLiteral ||
        expr is NullLiteral ||
        expr is SymbolLiteral ||
        (expr is InstanceCreationExpression &&
            expr.keyword?.type == Keyword.CONST);
  }
}

/// Future rule: avoid-scaffold-messenger-of-context
/// Warns when using ScaffoldMessenger.of(context) directly instead of storing it.
///
/// Example of **bad** code:
/// ```dart
/// onPressed: () async {
///   await someAsyncWork();
///   ScaffoldMessenger.of(context).showSnackBar(...);
/// }
/// ```
///
/// Example of **good** code:
/// ```dart
/// onPressed: () async {
///   final messenger = ScaffoldMessenger.of(context);
///   await someAsyncWork();
///   messenger.showSnackBar(...);
/// }
/// ```

class AvoidListViewWithoutItemExtentRule extends SaropaLintRule {
  const AvoidListViewWithoutItemExtentRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_listview_without_item_extent',
    problemMessage:
        '[avoid_listview_without_item_extent] ListView.builder should specify itemExtent for better scroll performance.',
    correctionMessage: 'Add itemExtent or prototypeItem parameter.',
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
  const PreferSliverListDelegateRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    name: 'prefer_sliver_list_delegate',
    problemMessage:
        '[prefer_sliver_list_delegate] Use SliverChildBuilderDelegate for better performance with large lists.',
    correctionMessage:
        'Replace SliverChildListDelegate with SliverChildBuilderDelegate.',
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
      final String typeName = node.constructorName.type.name.lexeme;

      if (typeName == 'SliverChildListDelegate') {
        // Check if the list has many items
        final NodeList<Expression> args = node.argumentList.arguments;
        if (args.isNotEmpty && args.first is ListLiteral) {
          final ListLiteral list = args.first as ListLiteral;
          if (list.elements.length > 10) {
            reporter.atNode(node.constructorName, code);
          }
        }
      }
    });
  }
}

/// Future rule: avoid-layout-builder-in-build
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

class AvoidLayoutBuilderMisuseRule extends SaropaLintRule {
  const AvoidLayoutBuilderMisuseRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    name: 'avoid_layout_builder_misuse',
    problemMessage:
        '[avoid_layout_builder_misuse] LayoutBuilder should use constraints in its builder.',
    correctionMessage:
        'Ensure the builder actually uses the constraints parameter.',
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
      final String typeName = node.constructorName.type.name.lexeme;

      if (typeName == 'LayoutBuilder') {
        for (final Expression arg in node.argumentList.arguments) {
          if (arg is NamedExpression && arg.name.label.name == 'builder') {
            final Expression builderExpr = arg.expression;
            if (builderExpr is FunctionExpression) {
              final FormalParameterList? params = builderExpr.parameters;
              if (params != null && params.parameters.length >= 2) {
                final String? constraintsName =
                    params.parameters[1].name?.lexeme;
                if (constraintsName != null &&
                    !constraintsName.startsWith('_')) {
                  // Check if constraints is used in body
                  final Set<String> usedIds = <String>{};
                  builderExpr.body
                      .visitChildren(_SimpleIdentifierCollector(usedIds));
                  if (!usedIds.contains(constraintsName)) {
                    reporter.atNode(node.constructorName, code);
                  }
                }
              }
            }
          }
        }
      }
    });
  }
}

class _SimpleIdentifierCollector extends RecursiveAstVisitor<void> {
  _SimpleIdentifierCollector(this.identifiers);
  final Set<String> identifiers;

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    identifiers.add(node.name);
    super.visitSimpleIdentifier(node);
  }
}

/// Future rule: avoid-repainting-boundary-misuse
/// Warns when RepaintBoundary is used around static content.
///
/// Example of **bad** code:
/// ```dart
/// RepaintBoundary(
///   child: const Text('Static text'),  // No benefit for static content
/// )
/// ```
///
/// Example of **good** code:
/// ```dart
/// RepaintBoundary(
///   child: AnimatedWidget(),  // Isolates frequently changing content
/// )
/// ```

class AvoidRepaintBoundaryMisuseRule extends SaropaLintRule {
  const AvoidRepaintBoundaryMisuseRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    name: 'avoid_repaint_boundary_misuse',
    problemMessage:
        '[avoid_repaint_boundary_misuse] RepaintBoundary around const/static content provides no benefit.',
    correctionMessage: 'Use RepaintBoundary for frequently repainting content.',
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
      final String typeName = node.constructorName.type.name.lexeme;

      if (typeName == 'RepaintBoundary') {
        for (final Expression arg in node.argumentList.arguments) {
          if (arg is NamedExpression && arg.name.label.name == 'child') {
            final Expression child = arg.expression;
            // Check if child is const
            if (child is InstanceCreationExpression &&
                child.keyword?.type == Keyword.CONST) {
              reporter.atNode(node.constructorName, code);
            }
          }
        }
      }
    });
  }
}

/// Future rule: avoid-singlechildscrollview-with-column
/// Warns when SingleChildScrollView wraps a Column with Expanded children.
///
/// Alias: avoid_single_child_scroll_view_list
///
/// Example of **bad** code:
/// ```dart
/// SingleChildScrollView(
///   child: Column(
///     children: [
///       Expanded(child: Container()),  // Expanded won't work!
///     ],
///   ),
/// )
/// ```
///
/// Example of **good** code:
/// ```dart
/// ListView(
///   children: [...],
/// )
/// ```

class AvoidSingleChildScrollViewWithColumnRule extends SaropaLintRule {
  const AvoidSingleChildScrollViewWithColumnRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  // cspell:ignore singlechildscrollview
  static const LintCode _code = LintCode(
    name: 'avoid_singlechildscrollview_with_column',
    problemMessage:
        '[avoid_singlechildscrollview_with_column] SingleChildScrollView with Column may cause layout issues.',
    correctionMessage:
        'Consider using ListView instead, or remove Expanded/Flexible children.',
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

class AvoidGestureDetectorInScrollViewRule extends SaropaLintRule {
  const AvoidGestureDetectorInScrollViewRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    name: 'avoid_gesture_detector_in_scrollview',
    problemMessage:
        '[avoid_gesture_detector_in_scrollview] GestureDetector around scrollable can cause gesture conflicts.',
    correctionMessage:
        'Move GestureDetector to individual items inside the scrollable.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  static const Set<String> _scrollableWidgets = <String>{
    'ListView',
    'GridView',
    'SingleChildScrollView',
    'CustomScrollView',
    'PageView',
    'NestedScrollView',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry
        .addInstanceCreationExpression((InstanceCreationExpression node) {
      final String typeName = node.constructorName.type.name.lexeme;

      if (typeName == 'GestureDetector' || typeName == 'InkWell') {
        for (final Expression arg in node.argumentList.arguments) {
          if (arg is NamedExpression && arg.name.label.name == 'child') {
            final Expression child = arg.expression;
            if (child is InstanceCreationExpression) {
              final String childType = child.constructorName.type.name.lexeme;
              if (_scrollableWidgets.contains(childType)) {
                reporter.atNode(node.constructorName, code);
              }
            }
          }
        }
      }
    });
  }
}

/// Future rule: avoid-stateful-widget-in-list
/// Warns when StatefulWidget is created inline in a list builder.
///
/// Example of **bad** code:
/// ```dart
/// ListView.builder(
///   itemBuilder: (context, index) => StatefulWidget(),  // Creates new instance each rebuild
/// )
/// ```
///
/// Example of **good** code:
/// ```dart
/// ListView.builder(
///   itemBuilder: (context, index) => StatelessWidget(key: ValueKey(index)),
/// )
/// ```

class PreferOpacityWidgetRule extends SaropaLintRule {
  const PreferOpacityWidgetRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    name: 'prefer_opacity_widget',
    problemMessage:
        '[prefer_opacity_widget] Consider using Opacity widget for complex child widgets.',
    correctionMessage:
        'Opacity widget can optimize rendering of transparent content.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name == 'withOpacity' ||
          node.methodName.name == 'withAlpha') {
        // Check if this is part of a color argument to a container-like widget
        final AstNode? parent = node.parent;
        if (parent is NamedExpression && parent.name.label.name == 'color') {
          final AstNode? grandparent = parent.parent?.parent;
          if (grandparent is InstanceCreationExpression) {
            final String typeName =
                grandparent.constructorName.type.name.lexeme;
            if (typeName == 'Container' || typeName == 'DecoratedBox') {
              // Check if it has a child that might be expensive
              for (final Expression arg in grandparent.argumentList.arguments) {
                if (arg is NamedExpression && arg.name.label.name == 'child') {
                  reporter.atNode(node, code);
                  break;
                }
              }
            }
          }
        }
      }
    });
  }
}

/// Warns when dependOnInheritedWidgetOfExactType is called in initState.
///
/// **Performance benefit:** Container internally creates DecoratedBox, ConstrainedBox, and other widgets. SizedBox is a single lightweight widget with fewer allocations.
///
/// Example of **bad** code:
/// ```dart
/// @override
/// void initState() {
///   super.initState();
///   final theme = Theme.of(context); // BAD
/// }
/// ```
///
/// Example of **good** code:
/// ```dart
/// @override
/// void didChangeDependencies() {
///   super.didChangeDependencies();
///   final theme = Theme.of(context); // OK
/// }
/// ```

class PreferSizedBoxForWhitespaceRule extends SaropaLintRule {
  const PreferSizedBoxForWhitespaceRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    name: 'prefer_sized_box_for_whitespace',
    problemMessage:
        '[prefer_sized_box_for_whitespace] Container creates unnecessary intermediate widgets (DecoratedBox, ConstrainedBox) when used only for whitespace. SizedBox is a single lightweight widget with fewer allocations and faster layout.',
    correctionMessage:
        'SizedBox is more efficient for spacing. Use SizedBox(width:) or SizedBox(height:).',
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
      final String typeName = node.constructorName.type.name.lexeme;
      if (typeName != 'Container') return;

      final NodeList<Expression> args = node.argumentList.arguments;
      if (args.isEmpty) return;

      // Check if Container only has width/height arguments (and optionally key)
      bool hasWidth = false;
      bool hasHeight = false;
      bool hasOtherArgs = false;

      for (final Expression arg in args) {
        if (arg is NamedExpression) {
          final String name = arg.name.label.name;
          if (name == 'width') {
            hasWidth = true;
          } else if (name == 'height') {
            hasHeight = true;
          } else if (name == 'key') {
            // key is fine
          } else {
            hasOtherArgs = true;
          }
        } else {
          // Positional argument means child
          hasOtherArgs = true;
        }
      }

      // Warn if Container only has width/height and no other properties
      if ((hasWidth || hasHeight) && !hasOtherArgs) {
        reporter.atNode(node, code);
      }
    });
  }

  @override
  List<Fix> getFixes() => <Fix>[_ReplaceContainerWithSizedBoxFix()];
}

class _ReplaceContainerWithSizedBoxFix extends DartFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    context.registry
        .addInstanceCreationExpression((InstanceCreationExpression node) {
      if (!node.sourceRange.intersects(analysisError.sourceRange)) return;

      final String typeName = node.constructorName.type.name.lexeme;
      if (typeName != 'Container') return;

      // Extract width and height values
      String? widthValue;
      String? heightValue;
      String? keyValue;

      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression) {
          final String name = arg.name.label.name;
          if (name == 'width') {
            widthValue = arg.expression.toSource();
          } else if (name == 'height') {
            heightValue = arg.expression.toSource();
          } else if (name == 'key') {
            keyValue = arg.expression.toSource();
          }
        }
      }

      // Determine if we should use const
      final bool hasConst =
          node.keyword?.lexeme == 'const' || _isInConstContext(node);
      final String constPrefix = hasConst ? 'const ' : '';

      // Build replacement
      final StringBuffer replacement = StringBuffer();
      replacement.write('${constPrefix}SizedBox(');

      final List<String> args = <String>[];
      if (keyValue != null) args.add('key: $keyValue');
      if (widthValue != null) args.add('width: $widthValue');
      if (heightValue != null) args.add('height: $heightValue');
      replacement.write(args.join(', '));
      replacement.write(')');

      final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
        message: 'Replace with SizedBox',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        builder.addSimpleReplacement(
          node.sourceRange,
          replacement.toString(),
        );
      });
    });
  }

  bool _isInConstContext(AstNode node) {
    AstNode? current = node.parent;
    while (current != null) {
      if (current is ListLiteral && current.constKeyword != null) return true;
      if (current is SetOrMapLiteral && current.constKeyword != null) {
        return true;
      }
      if (current is InstanceCreationExpression &&
          current.keyword?.lexeme == 'const') {
        return true;
      }
      current = current.parent;
    }
    return false;
  }
}

/// Warns when Scaffold widgets are nested inside other Scaffolds.
///
/// Nested Scaffolds can cause layout issues, unexpected behavior with
/// drawers, snackbars, and other Scaffold features.
///
/// Example of **bad** code:
/// ```dart
/// Scaffold(
///   body: Scaffold(  // Nested Scaffold
///     appBar: AppBar(),
///     body: Container(),
///   ),
/// )
/// ```
///
/// Example of **good** code:
/// ```dart
/// Scaffold(
///   appBar: AppBar(),
///   body: CustomScrollView(...),
/// )
/// ```

class AvoidNestedScaffoldsRule extends SaropaLintRule {
  const AvoidNestedScaffoldsRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    name: 'avoid_nested_scaffolds',
    problemMessage:
        '[avoid_nested_scaffolds] Nested Scaffold widget detected inside another Scaffold. This creates duplicate app bars, floating action buttons, and bottom navigation, leading to broken layout, gesture conflicts, and a confusing user experience.',
    correctionMessage:
        'Remove the inner Scaffold and use its body content directly. Share app bars and bottom navigation from the outer Scaffold.',
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
      final String typeName = node.constructorName.type.name.lexeme;
      if (typeName != 'Scaffold') return;

      // Check if any parent is also a Scaffold
      if (_hasScaffoldAncestor(node)) {
        reporter.atNode(node.constructorName, code);
      }
    });
  }

  bool _hasScaffoldAncestor(AstNode node) {
    AstNode? current = node.parent;
    while (current != null) {
      if (current is InstanceCreationExpression) {
        final String typeName = current.constructorName.type.name.lexeme;
        if (typeName == 'Scaffold') {
          return true;
        }
      }
      current = current.parent;
    }
    return false;
  }
}

/// Warns when multiple MaterialApp widgets exist in the widget tree.
///
/// Having multiple MaterialApp widgets can cause routing issues,
/// theme inconsistencies, and memory problems. There should be only
/// one MaterialApp at the root of your application.
///
/// Example of **bad** code:
/// ```dart
/// MaterialApp(
///   home: MaterialApp(  // Multiple MaterialApp!
///     home: MyHomePage(),
///   ),
/// )
/// ```
///
/// Example of **good** code:
/// ```dart
/// MaterialApp(
///   home: MyHomePage(),
/// )
/// ```

class PreferListViewBuilderRule extends SaropaLintRule {
  const PreferListViewBuilderRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    name: 'prefer_listview_builder',
    problemMessage:
        '[prefer_listview_builder] Use ListView.builder for better performance.',
    correctionMessage: 'Replace ListView(children:) with ListView.builder.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  static const int _childThreshold = 10;

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry
        .addInstanceCreationExpression((InstanceCreationExpression node) {
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

class AvoidSizedBoxExpandRule extends SaropaLintRule {
  const AvoidSizedBoxExpandRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_sized_box_expand',
    problemMessage:
        '[avoid_sized_box_expand] SizedBox.expand() fills all available space unconditionally, causing unpredictable layout overflow in constrained parents. '
        'Inside a Column, Row, or other flex widget without explicit constraints, expand() can trigger unbounded height/width errors or silently push sibling widgets off-screen.',
    correctionMessage:
        'Use SizedBox with explicit width and height values for predictable sizing, or use Expanded/Flexible inside flex widgets to share space proportionally. '
        'If you need to fill available space, use LayoutBuilder to measure constraints before deciding dimensions.',
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
      final String typeName = node.constructorName.type.name.lexeme;
      if (typeName != 'SizedBox') return;

      if (node.constructorName.name?.name == 'expand') {
        reporter.atNode(node.constructorName, code);
      }
    });
  }
}

/// Warns when long Text could be SelectableText.
///
/// Long text that users might want to copy should use SelectableText.
///
/// Example of **bad** code:
/// ```dart
/// Text('Very long paragraph that users might want to copy...')
/// ```
///
/// Example of **good** code:
/// ```dart
/// SelectableText('Very long paragraph...')
/// ```

/// **Stylistic rule (opt-in only).** No performance or correctness benefit.
///
/// Warns when Row or Column children alternate between content widgets and
/// identical spacer widgets (SizedBox or Spacer), suggesting the `spacing`
/// parameter instead.
///
/// Modern Flutter's Row and Column support a `spacing` parameter that adds
/// uniform space between children automatically, eliminating manual spacers.
///
/// Only flags when the children follow an alternating pattern:
/// `[content, spacer, content, spacer, content, ...]` where all spacers are
/// identical (same type and same size value).
///
/// ### Example
///
/// #### BAD:
/// ```dart
/// Column(
///   children: [
///     Text('Hello'),
///     SizedBox(height: 8),
///     Text('World'),
///     SizedBox(height: 8),
///     Text('!'),
///   ],
/// )
/// ```
///
/// #### GOOD:
/// ```dart
/// Column(
///   spacing: 8,
///   children: [
///     Text('Hello'),
///     Text('World'),
///     Text('!'),
///   ],
/// )
/// ```
class PreferSpacingOverSizedBoxRule extends SaropaLintRule {
  const PreferSpacingOverSizedBoxRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.opinionated;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    name: 'prefer_spacing_over_sizedbox',
    problemMessage:
        '[prefer_spacing_over_sizedbox] Using SizedBox for gaps instead of the spacing parameter is a stylistic API choice. Both achieve the same layout with no performance difference. Enable via the stylistic tier.',
    correctionMessage: 'Remove spacer children and add spacing: <value> to the '
        'Row/Column constructor.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  static const Set<String> _flexWidgets = <String>{'Row', 'Column'};

  @override
  List<Fix> getFixes() => <Fix>[_PreferSpacingOverSizedBoxFix()];

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry
        .addInstanceCreationExpression((InstanceCreationExpression node) {
      final String typeName = node.constructorName.type.name.lexeme;
      if (!_flexWidgets.contains(typeName)) return;

      if (_hasSpacingParam(node) || !_hasAlternatingSpacers(node, typeName)) {
        return;
      }

      reporter.atNode(node.constructorName, code);
    });
  }

  static bool _hasSpacingParam(InstanceCreationExpression node) {
    for (final Expression arg in node.argumentList.arguments) {
      if (arg is NamedExpression && arg.name.label.name == 'spacing') {
        return true;
      }
    }
    return false;
  }

  /// Checks if children follow [content, spacer, content, spacer, ...] pattern
  /// with all spacers being identical.
  static bool _hasAlternatingSpacers(
    InstanceCreationExpression node,
    String typeName,
  ) {
    final ListLiteral? childrenList = _getChildrenList(node);
    if (childrenList == null) return false;

    final List<CollectionElement> elements = childrenList.elements;

    // Need at least 3 elements: content, spacer, content
    if (elements.length < 3 || elements.length.isEven) return false;

    String? spacerSource;

    for (int i = 0; i < elements.length; i++) {
      final CollectionElement element = elements[i];

      // Spread elements break the pattern
      if (element is! Expression) return false;

      if (i.isOdd) {
        // Odd-indexed: must be a spacer
        final String? source = _getSpacerSource(element, typeName);
        if (source == null) return false;

        if (spacerSource == null) {
          spacerSource = source;
        } else if (spacerSource != source) {
          return false; // Different spacers
        }
      } else {
        // Even-indexed: must NOT be a spacer
        if (_getSpacerSource(element, typeName) != null) return false;
      }
    }

    return spacerSource != null;
  }

  static ListLiteral? _getChildrenList(InstanceCreationExpression node) {
    for (final Expression arg in node.argumentList.arguments) {
      if (arg is NamedExpression && arg.name.label.name == 'children') {
        final Expression value = arg.expression;
        if (value is ListLiteral) return value;
      }
    }
    return null;
  }

  /// Returns the source text of a spacer expression for comparison,
  /// or null if the expression is not a spacer.
  static String? _getSpacerSource(Expression expr, String parentType) {
    if (expr is! InstanceCreationExpression) return null;

    final String name = expr.constructorName.type.name.lexeme;

    if (name == 'Spacer') {
      // Spacer() with no arguments or only default flex
      return expr.toSource();
    }

    if (name == 'SizedBox') {
      // Must not have a child
      bool hasChild = false;
      bool hasRelevantDimension = false;

      final String expectedArg = parentType == 'Column' ? 'height' : 'width';

      for (final Expression arg in expr.argumentList.arguments) {
        if (arg is NamedExpression) {
          if (arg.name.label.name == 'child') {
            hasChild = true;
          } else if (arg.name.label.name == expectedArg) {
            hasRelevantDimension = true;
          }
        }
      }

      if (hasChild || !hasRelevantDimension) return null;

      return expr.toSource();
    }

    return null;
  }

  /// Extracts the spacing value source text from a spacer expression.
  static String? _getSpacingValue(Expression expr, String parentType) {
    if (expr is! InstanceCreationExpression) return null;

    final String name = expr.constructorName.type.name.lexeme;
    if (name != 'SizedBox') return null;

    final String expectedArg = parentType == 'Column' ? 'height' : 'width';

    for (final Expression arg in expr.argumentList.arguments) {
      if (arg is NamedExpression && arg.name.label.name == expectedArg) {
        return arg.expression.toSource();
      }
    }
    return null;
  }
}

class _PreferSpacingOverSizedBoxFix extends DartFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    context.registry
        .addInstanceCreationExpression((InstanceCreationExpression node) {
      if (!analysisError.sourceRange.intersects(node.sourceRange)) return;

      final String typeName = node.constructorName.type.name.lexeme;
      if (!PreferSpacingOverSizedBoxRule._flexWidgets.contains(typeName)) {
        return;
      }

      final ListLiteral? childrenList =
          PreferSpacingOverSizedBoxRule._getChildrenList(node);
      if (childrenList == null) return;

      final List<CollectionElement> elements = childrenList.elements;
      if (elements.length < 3) return;

      // Get spacing value from first spacer (index 1)
      final Expression firstSpacer = elements[1] as Expression;
      final String? spacingValue =
          PreferSpacingOverSizedBoxRule._getSpacingValue(
        firstSpacer,
        typeName,
      );

      // Only auto-fix SizedBox spacers where we can extract the value
      if (spacingValue == null) return;

      final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
        message: 'Use spacing: $spacingValue parameter',
        priority: 80,
      );

      changeBuilder.addDartFileEdit((builder) {
        // Add spacing parameter after the constructor name
        builder.addSimpleInsertion(
          node.constructorName.end,
          '(spacing: $spacingValue,',
        );

        // Remove the opening paren that was already there
        builder.addDeletion(
          SourceRange(node.argumentList.offset, 1),
        );

        // Remove spacer children (odd-indexed elements)
        for (int i = elements.length - 2; i >= 1; i -= 2) {
          final int start = _getRemovalStart(elements, i);
          final int end = _getRemovalEnd(elements, i);
          builder.addDeletion(SourceRange(start, end - start));
        }
      });
    });
  }

  /// Gets the start offset for removing a spacer, including leading comma
  /// and whitespace.
  int _getRemovalStart(List<CollectionElement> elements, int index) {
    // Remove from end of previous element (after the comma)
    final CollectionElement prev = elements[index - 1];
    return prev.end;
  }

  /// Gets the end offset for removing a spacer, including trailing comma.
  int _getRemovalEnd(List<CollectionElement> elements, int index) {
    final CollectionElement next = elements[index + 1];
    return next.offset;
  }
}

/// Warns when Material 2 is explicitly enabled via useMaterial3: false.
///
/// Material 3 is the default since Flutter 3.16. Explicitly disabling it
/// prevents access to M3 features and may cause issues in future Flutter
/// versions.
///
/// ### Example
///
/// #### BAD:
/// ```dart
/// ThemeData(
///   useMaterial3: false,  // Explicitly disabling M3
/// )
/// ```
///
/// #### GOOD:
/// ```dart
/// ThemeData(
///   // M3 is default, no need to specify
/// )
///
/// ThemeData(
///   useMaterial3: true,  // Explicitly enabling is fine
/// )
/// ```

class AvoidNestedScrollablesRule extends SaropaLintRule {
  const AvoidNestedScrollablesRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    name: 'avoid_nested_scrollables',
    problemMessage:
        '[avoid_nested_scrollables] Nested scrollable widgets can cause scroll conflicts.',
    correctionMessage:
        'Use NestedScrollView, or add shrinkWrap: true and NeverScrollableScrollPhysics().',
    errorSeverity: DiagnosticSeverity.WARNING,
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
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addInstanceCreationExpression((
      InstanceCreationExpression node,
    ) {
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

class AvoidHardcodedLayoutValuesRule extends SaropaLintRule {
  const AvoidHardcodedLayoutValuesRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    name: 'avoid_hardcoded_layout_values',
    problemMessage:
        '[avoid_hardcoded_layout_values] Hardcoded numeric value in layout widget prevents responsive adaptation across screen sizes and text scales. '
        'Fixed pixel values that look correct on one device may cause overflow, clipping, or wasted space on devices with different screen densities, orientations, or accessibility font size settings.',
    correctionMessage:
        'Extract layout values to named constants in a spacing/dimension system (e.g., AppSpacing.medium, AppDimensions.buttonHeight) or use MediaQuery-based calculations for responsive sizing. '
        'Named constants centralize layout decisions and enable consistent updates across the entire app.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  /// Layout widgets where we check for hardcoded values
  static const Set<String> _layoutWidgets = <String>{
    'SizedBox',
    'Container',
    'Padding',
    'Margin',
    'ConstrainedBox',
    'LimitedBox',
    'FractionallySizedBox',
    'AspectRatio',
  };

  /// Properties that commonly use numeric layout values
  static const Set<String> _layoutProperties = <String>{
    'width',
    'height',
    'padding',
    'margin',
    'constraints',
    'minWidth',
    'maxWidth',
    'minHeight',
    'maxHeight',
  };

  /// Small values that are commonly acceptable (0, 1, 2)
  static const Set<int> _acceptableValues = <int>{0, 1, 2};

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addInstanceCreationExpression((
      InstanceCreationExpression node,
    ) {
      final String typeName = node.constructorName.type.name.lexeme;
      if (!_layoutWidgets.contains(typeName)) return;

      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression) {
          final String argName = arg.name.label.name;
          if (_layoutProperties.contains(argName)) {
            _checkForHardcodedValue(arg.expression, reporter);
          }
        }
      }
    });

    // Also check EdgeInsets constructors
    context.registry.addInstanceCreationExpression((
      InstanceCreationExpression node,
    ) {
      final String typeName = node.constructorName.type.name.lexeme;
      if (typeName != 'EdgeInsets') return;

      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression) {
          _checkForHardcodedValue(arg.expression, reporter);
        } else {
          _checkForHardcodedValue(arg, reporter);
        }
      }
    });
  }

  void _checkForHardcodedValue(
      Expression expr, SaropaDiagnosticReporter reporter) {
    if (expr is IntegerLiteral) {
      final int? value = expr.value;
      if (value != null && !_acceptableValues.contains(value) && value > 4) {
        reporter.atNode(expr, code);
      }
    } else if (expr is DoubleLiteral) {
      final double value = expr.value;
      if (value > 4.0 && value != value.roundToDouble()) {
        reporter.atNode(expr, code);
      } else if (value > 4.0) {
        reporter.atNode(expr, code);
      }
    }
  }
}

/// Suggests IgnorePointer when AbsorbPointer may not be needed.
///
/// - **AbsorbPointer**: Absorbs events and prevents them from reaching
///   widgets behind it. Use when you need to block underlying interactions.
/// - **IgnorePointer**: Lets events pass through completely. Use when you
///   just want to disable this widget's interaction.
///
/// Choose based on whether you need to block underlying widgets.
///
/// **Use AbsorbPointer when:**
/// ```dart
/// // Overlay that should block clicks on background
/// AbsorbPointer(
///   absorbing: isOverlayVisible,
///   child: OverlayContent(),
/// )
/// ```
///
/// **Use IgnorePointer when:**
/// ```dart
/// // Disabled widget that shouldn't block background clicks
/// IgnorePointer(
///   ignoring: isDisabled,
///   child: MyWidget(),
/// )
/// ```

class PreferIgnorePointerRule extends SaropaLintRule {
  const PreferIgnorePointerRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    name: 'prefer_ignore_pointer',
    problemMessage:
        '[prefer_ignore_pointer] AbsorbPointer blocks underlying widgets - is IgnorePointer better?',
    correctionMessage:
        'Use IgnorePointer if you don\'t need to block background interactions.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addInstanceCreationExpression((
      InstanceCreationExpression node,
    ) {
      final String typeName = node.constructorName.type.name.lexeme;
      if (typeName == 'AbsorbPointer') {
        reporter.atNode(node.constructorName, code);
      }
    });
  }
}

/// Warns when GestureDetector is used without specifying HitTestBehavior.
///
/// Without explicit behavior, gesture detection may not work as expected,
/// especially with overlapping widgets or transparent areas.
///
/// **BAD:**
/// ```dart
/// GestureDetector(
///   onTap: () => print('tapped'),
///   child: Container(color: Colors.transparent),
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// GestureDetector(
///   behavior: HitTestBehavior.opaque,
///   onTap: () => print('tapped'),
///   child: Container(color: Colors.transparent),
/// )
/// ```

class PreferPageStorageKeyRule extends SaropaLintRule {
  const PreferPageStorageKeyRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    name: 'prefer_page_storage_key',
    problemMessage:
        '[prefer_page_storage_key] Consider using PageStorageKey to preserve scroll position.',
    correctionMessage:
        'Add key: PageStorageKey("unique_key") to the scrollable.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  static const Set<String> _scrollableWidgets = <String>{
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
    context.registry.addInstanceCreationExpression((
      InstanceCreationExpression node,
    ) {
      final String typeName = node.constructorName.type.name.lexeme;
      if (!_scrollableWidgets.contains(typeName)) return;

      bool hasPageStorageKey = false;

      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression && arg.name.label.name == 'key') {
          final String keySource = arg.expression.toSource();
          if (keySource.contains('PageStorageKey')) {
            hasPageStorageKey = true;
          }
        }
      }

      // Only warn if no PageStorageKey
      if (!hasPageStorageKey) {
        reporter.atNode(node.constructorName, code);
      }
    });
  }
}

/// Suggests RefreshIndicator for lists that appear to show remote data.
///
/// Pull-to-refresh is expected for lists showing fetchable content.
/// This rule only triggers when the list name suggests remote data.
///
/// **BAD:**
/// ```dart
/// Widget build(BuildContext context) {
///   return ListView.builder(
///     itemBuilder: (context, index) => ListTile(title: Text(posts[index])),
///     itemCount: posts.length,  // "posts" suggests remote data
///   );
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// RefreshIndicator(
///   onRefresh: () => fetchPosts(),
///   child: ListView.builder(
///     itemBuilder: (context, index) => ListTile(title: Text(posts[index])),
///     itemCount: posts.length,
///   ),
/// )
/// ```

class RequireScrollPhysicsRule extends SaropaLintRule {
  const RequireScrollPhysicsRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    name: 'require_scroll_physics',
    problemMessage:
        '[require_scroll_physics] Scrollable widget should specify scroll physics.',
    correctionMessage:
        'Add physics: BouncingScrollPhysics() or ClampingScrollPhysics().',
    errorSeverity: DiagnosticSeverity.INFO,
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
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addInstanceCreationExpression((
      InstanceCreationExpression node,
    ) {
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
  const PreferSliverListRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    name: 'prefer_sliver_list',
    problemMessage:
        '[prefer_sliver_list] Use SliverList instead of ListView inside CustomScrollView.',
    correctionMessage:
        'Replace ListView with SliverList for proper sliver composition.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addInstanceCreationExpression((
      InstanceCreationExpression node,
    ) {
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
  const PreferKeepAliveRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    name: 'prefer_keep_alive',
    problemMessage:
        '[prefer_keep_alive] Consider using AutomaticKeepAliveClientMixin to preserve state.',
    correctionMessage:
        'Add "with AutomaticKeepAliveClientMixin" to preserve state in tabs.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
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

      // Check if this State builds a scrollable that might need keep alive
      final String classSource = node.toSource();
      if (classSource.contains('ListView') ||
          classSource.contains('GridView') ||
          classSource.contains('CustomScrollView')) {
        // Check if inside a tab-like context (has TabBar reference)
        if (classSource.contains('Tab') || classSource.contains('Page')) {
          reporter.atToken(node.name, code);
        }
      }
    });
  }
}

/// Warns when Text widgets are not wrapped with DefaultTextStyle.
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
  const PreferWrapOverOverflowRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    name: 'prefer_wrap_over_overflow',
    problemMessage:
        '[prefer_wrap_over_overflow] Row with many children may overflow - consider using Wrap.',
    correctionMessage: 'Replace Row with Wrap for automatic wrapping.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addInstanceCreationExpression((
      InstanceCreationExpression node,
    ) {
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
  const AvoidLayoutBuilderInScrollableRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    name: 'avoid_layout_builder_in_scrollable',
    problemMessage:
        '[avoid_layout_builder_in_scrollable] LayoutBuilder inside scrollable causes performance issues.',
    correctionMessage: 'Move LayoutBuilder outside the scrollable widget.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  static const Set<String> _scrollableWidgets = <String>{
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
    context.registry.addInstanceCreationExpression((
      InstanceCreationExpression node,
    ) {
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

class PreferIntrinsicDimensionsRule extends SaropaLintRule {
  const PreferIntrinsicDimensionsRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    name: 'prefer_intrinsic_dimensions',
    problemMessage:
        '[prefer_intrinsic_dimensions] Consider using IntrinsicWidth/Height for content-based sizing.',
    correctionMessage: 'Wrap with IntrinsicWidth or IntrinsicHeight.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addInstanceCreationExpression((
      InstanceCreationExpression node,
    ) {
      final String typeName = node.constructorName.type.name.lexeme;
      if (typeName != 'Column') return;

      // Check for CrossAxisAlignment.stretch without IntrinsicWidth parent
      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression &&
            arg.name.label.name == 'crossAxisAlignment') {
          final String value = arg.expression.toSource();
          if (value.contains('stretch')) {
            // Check if already wrapped in IntrinsicWidth
            AstNode? current = node.parent;
            while (current != null) {
              if (current is InstanceCreationExpression) {
                final String parentType =
                    current.constructorName.type.name.lexeme;
                if (parentType == 'IntrinsicWidth') {
                  return; // Already properly wrapped
                }
              }
              current = current.parent;
            }
            reporter.atNode(node.constructorName, code);
          }
        }
      }
    });
  }
}

/// Warns when keyboard shortcuts don't use the Actions/Shortcuts system.
///
/// The Actions/Shortcuts system provides better accessibility and
/// consistency across platforms.
///
/// **BAD:**
/// ```dart
/// RawKeyboardListener(
///   onKey: (event) {
///     if (event.isKeyPressed(LogicalKeyboardKey.enter)) {
///       submit();
///     }
///   },
///   child: Form(...),
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// Shortcuts(
///   shortcuts: {
///     LogicalKeySet(LogicalKeyboardKey.enter): SubmitIntent(),
///   },
///   child: Actions(
///     actions: {SubmitIntent: SubmitAction()},
///     child: Form(...),
///   ),
/// )
/// ```

class AvoidUnboundedConstraintsRule extends SaropaLintRule {
  const AvoidUnboundedConstraintsRule() : super(code: _code);

  /// Crash path — Expanded/Flexible in unbounded scroll axis throws
  /// RenderFlex overflow. Even 10+ violations need immediate attention.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    name: 'avoid_unbounded_constraints',
    problemMessage:
        '[avoid_unbounded_constraints] Column/Row in SingleChildScrollView may have unbounded constraints.',
    correctionMessage:
        'Wrap with ConstrainedBox or avoid Expanded/Flexible children.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addInstanceCreationExpression((
      InstanceCreationExpression node,
    ) {
      final String typeName = node.constructorName.type.name.lexeme;
      if (typeName != 'Column' && typeName != 'Row') return;

      final _ScrollAncestorInfo? scrollInfo = _findScrollAncestor(node);
      if (scrollInfo == null || scrollInfo.hasConstrainedBox) return;

      // Only flag when axes match: Column in vertical scroll,
      // Row in horizontal scroll. Cross-axis is always bounded.
      final bool isVerticalScroll = !scrollInfo.isHorizontalScroll;
      if ((typeName == 'Column') != isVerticalScroll) return;

      if (_hasDirectExpandedOrFlexible(node)) {
        reporter.atNode(node.constructorName, code);
      }
    });
  }

  /// Walks ancestors to find SingleChildScrollView and any constraint
  /// widgets between the node and the scroll view.
  static _ScrollAncestorInfo? _findScrollAncestor(AstNode node) {
    AstNode? current = node.parent;
    bool hasConstrainedBox = false;

    while (current != null) {
      if (current is InstanceCreationExpression) {
        final String parentType = current.constructorName.type.name.lexeme;
        if (parentType == 'SingleChildScrollView') {
          return _ScrollAncestorInfo(
            isHorizontalScroll: _hasHorizontalScrollDirection(current),
            hasConstrainedBox: hasConstrainedBox,
          );
        }
        if (parentType == 'ConstrainedBox' ||
            parentType == 'SizedBox' ||
            parentType == 'Container') {
          hasConstrainedBox = true;
        }
      }
      current = current.parent;
    }
    return null;
  }

  /// Whether SingleChildScrollView has scrollDirection: Axis.horizontal.
  static bool _hasHorizontalScrollDirection(
    InstanceCreationExpression node,
  ) {
    for (final Expression arg in node.argumentList.arguments) {
      if (arg is NamedExpression && arg.name.label.name == 'scrollDirection') {
        return arg.expression.toSource().contains('horizontal');
      }
    }
    return false;
  }

  /// Checks only direct children for Expanded/Flexible, not nested
  /// descendants which have their own constraint context.
  static bool _hasDirectExpandedOrFlexible(
    InstanceCreationExpression node,
  ) {
    for (final Expression arg in node.argumentList.arguments) {
      if (arg is NamedExpression && arg.name.label.name == 'children') {
        final Expression childrenExpr = arg.expression;
        if (childrenExpr is ListLiteral) {
          return _elementsContainExpandedFlexible(childrenExpr.elements);
        }
        // Non-literal children list — fall back to string check
        final String source = childrenExpr.toSource();
        return source.contains('Expanded') || source.contains('Flexible');
      }
    }
    return false;
  }

  /// Checks top-level list elements (including if-branches) for
  /// Expanded/Flexible, without descending into nested widget trees.
  static bool _elementsContainExpandedFlexible(
    NodeList<CollectionElement> elements,
  ) {
    for (final CollectionElement element in elements) {
      if (_isExpandedOrFlexible(element)) return true;
      if (element is IfElement) {
        if (_isExpandedOrFlexible(element.thenElement)) return true;
        final CollectionElement? elseElement = element.elseElement;
        if (elseElement != null && _isExpandedOrFlexible(elseElement)) {
          return true;
        }
      }
    }
    return false;
  }

  /// Whether an element is an Expanded or Flexible constructor call.
  static bool _isExpandedOrFlexible(CollectionElement element) {
    if (element is! InstanceCreationExpression) return false;
    final String name = element.constructorName.type.name.lexeme;
    return name == 'Expanded' || name == 'Flexible';
  }
}

/// Info about a SingleChildScrollView ancestor.
class _ScrollAncestorInfo {
  const _ScrollAncestorInfo({
    required this.isHorizontalScroll,
    required this.hasConstrainedBox,
  });

  final bool isHorizontalScroll;
  final bool hasConstrainedBox;
}

// ============================================================================
// BATCH 3 - MORE WIDGET RULES FROM ROADMAP
// ============================================================================

/// Warns when percentage-based sizing uses hardcoded calculations.
///
/// FractionallySizedBox is cleaner for percentage-based layouts.
///
/// **BAD:**
/// ```dart
/// Container(
///   width: MediaQuery.of(context).size.width * 0.5,
///   child: MyWidget(),
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// FractionallySizedBox(
///   widthFactor: 0.5,
///   child: MyWidget(),
/// )
/// ```

class PreferFractionalSizingRule extends SaropaLintRule {
  const PreferFractionalSizingRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    name: 'prefer_fractional_sizing',
    problemMessage:
        '[prefer_fractional_sizing] Use FractionallySizedBox for percentage-based sizing.',
    correctionMessage:
        'Replace MediaQuery.size multiplication with FractionallySizedBox.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addBinaryExpression((BinaryExpression node) {
      // Check for multiplication with a fraction
      if (node.operator.lexeme != '*') return;

      final String leftSource = node.leftOperand.toSource();
      final String rightSource = node.rightOperand.toSource();

      // Check for MediaQuery.of(context).size.width * 0.x pattern
      if (!((leftSource.contains('MediaQuery') &&
              leftSource.contains('.size.')) ||
          (rightSource.contains('MediaQuery') &&
              rightSource.contains('.size.')))) {
        return;
      }

      // Check if multiplying by a fraction (0 < value < 1)
      if (!_isFractionalLiteral(node.rightOperand) &&
          !_isFractionalLiteral(node.leftOperand)) {
        return;
      }

      // Skip collection contexts (list literal, .add(), etc.) where
      // FractionallySizedBox won't work due to potentially unbounded
      // parent constraints (e.g. inside a horizontal ScrollView).
      if (_isInsideCollectionContext(node)) return;

      reporter.atNode(node, code);
    });
  }

  /// Returns true if [expr] is a double literal between 0 and 1 exclusive.
  static bool _isFractionalLiteral(Expression expr) {
    if (expr is! DoubleLiteral) return false;
    return expr.value > 0 && expr.value < 1;
  }

  /// Returns true if [node] is inside a collection-building context
  /// where FractionallySizedBox cannot reliably replace MediaQuery-based
  /// sizing due to potentially unbounded parent constraints.
  static bool _isInsideCollectionContext(AstNode node) {
    AstNode? current = node.parent;
    while (current != null) {
      if (current is ListLiteral) return true;
      if (current is MethodInvocation) {
        final String name = current.methodName.name;
        if (name == 'add' || name == 'insert') return true;
      }
      if (current is FunctionBody) break;
      current = current.parent;
    }
    return false;
  }
}

/// Warns when UnconstrainedBox is used improperly causing overflow.
///
/// UnconstrainedBox removes constraints which can cause overflow.
///
/// **BAD:**
/// ```dart
/// SizedBox(
///   width: 100,
///   child: UnconstrainedBox(
///     child: Image.asset('wide_image.png'), // May overflow!
///   ),
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// SizedBox(
///   width: 100,
///   child: FittedBox(
///     fit: BoxFit.contain,
///     child: Image.asset('wide_image.png'),
///   ),
/// )
/// ```

class AvoidUnconstrainedBoxMisuseRule extends SaropaLintRule {
  const AvoidUnconstrainedBoxMisuseRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_unconstrained_box_misuse',
    problemMessage:
        '[avoid_unconstrained_box_misuse] UnconstrainedBox in constrained parent may cause overflow.',
    correctionMessage: 'Consider using FittedBox or OverflowBox instead.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addInstanceCreationExpression((
      InstanceCreationExpression node,
    ) {
      final String typeName = node.constructorName.type.name.lexeme;
      if (typeName != 'UnconstrainedBox') return;

      // Check if inside a constraining widget
      AstNode? current = node.parent;
      while (current != null) {
        if (current is InstanceCreationExpression) {
          final String parentType = current.constructorName.type.name.lexeme;
          if (parentType == 'SizedBox' ||
              parentType == 'Container' ||
              parentType == 'ConstrainedBox' ||
              parentType == 'LimitedBox') {
            reporter.atNode(node.constructorName, code);
            return;
          }
        }
        current = current.parent;
      }
    });
  }
}

/// Warns when FutureBuilder/StreamBuilder doesn't handle errors.
///
/// Async builders should handle error states for robustness.
///
/// **BAD:**
/// ```dart
/// FutureBuilder<User>(
///   future: fetchUser(),
///   builder: (context, snapshot) {
///     if (snapshot.hasData) return UserWidget(snapshot.data!);
///     return CircularProgressIndicator();
///   },
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// FutureBuilder<User>(
///   future: fetchUser(),
///   builder: (context, snapshot) {
///     if (snapshot.hasError) return ErrorWidget(snapshot.error!);
///     if (snapshot.hasData) return UserWidget(snapshot.data!);
///     return CircularProgressIndicator();
///   },
/// )
/// ```

class PreferSliverAppBarRule extends SaropaLintRule {
  const PreferSliverAppBarRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    name: 'prefer_sliver_app_bar',
    problemMessage:
        '[prefer_sliver_app_bar] Use SliverAppBar inside CustomScrollView, not AppBar.',
    correctionMessage: 'Replace AppBar with SliverAppBar for scroll effects.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addInstanceCreationExpression((
      InstanceCreationExpression node,
    ) {
      final String typeName = node.constructorName.type.name.lexeme;
      if (typeName != 'AppBar') return;

      // Check if inside CustomScrollView
      AstNode? current = node.parent;
      while (current != null) {
        if (current is InstanceCreationExpression) {
          final String parentType = current.constructorName.type.name.lexeme;
          if (parentType == 'CustomScrollView' ||
              parentType == 'NestedScrollView') {
            reporter.atNode(node.constructorName, code);
            return;
          }
        }
        current = current.parent;
      }
    });
  }
}

/// Warns when Opacity is used for animations instead of AnimatedOpacity.
///
/// AnimatedOpacity is more performant for opacity animations.
///
/// **BAD:**
/// ```dart
/// Opacity(
///   opacity: _isVisible ? 1.0 : 0.0,
///   child: MyWidget(),
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// AnimatedOpacity(
///   opacity: _isVisible ? 1.0 : 0.0,
///   duration: Duration(milliseconds: 300),
///   child: MyWidget(),
/// )
/// ```

class AvoidOpacityMisuseRule extends SaropaLintRule {
  const AvoidOpacityMisuseRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    name: 'avoid_opacity_misuse',
    problemMessage:
        '[avoid_opacity_misuse] Use AnimatedOpacity for opacity animations.',
    correctionMessage:
        'Replace Opacity with AnimatedOpacity for smoother animations.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addInstanceCreationExpression((
      InstanceCreationExpression node,
    ) {
      final String typeName = node.constructorName.type.name.lexeme;
      if (typeName != 'Opacity') return;

      // Check if opacity uses a conditional (suggests animation)
      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression && arg.name.label.name == 'opacity') {
          final String opacitySource = arg.expression.toSource();
          // Check for ternary or variable (not literal)
          if (opacitySource.contains('?') ||
              opacitySource.contains('_') ||
              (arg.expression is! DoubleLiteral &&
                  arg.expression is! IntegerLiteral)) {
            reporter.atNode(node.constructorName, code);
          }
        }
      }
    });
  }
}

/// Warns when widgets don't specify clipBehavior for performance.
///
/// Explicit clipBehavior helps optimize rendering.
///
/// **BAD:**
/// ```dart
/// Stack(
///   children: [OverflowingWidget()],
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// Stack(
///   clipBehavior: Clip.none, // Intentionally allow overflow
///   children: [OverflowingWidget()],
/// )
/// ```

class PreferClipBehaviorRule extends SaropaLintRule {
  const PreferClipBehaviorRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    name: 'prefer_clip_behavior',
    problemMessage:
        '[prefer_clip_behavior] Consider specifying clipBehavior for performance.',
    correctionMessage: 'Add clipBehavior: Clip.none or Clip.hardEdge.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  static const Set<String> _clippableWidgets = <String>{
    'Stack',
    'Container',
    'ClipRect',
    'ClipRRect',
    'ClipOval',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addInstanceCreationExpression((
      InstanceCreationExpression node,
    ) {
      final String typeName = node.constructorName.type.name.lexeme;
      if (!_clippableWidgets.contains(typeName)) return;

      bool hasClipBehavior = false;
      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression && arg.name.label.name == 'clipBehavior') {
          hasClipBehavior = true;
          break;
        }
      }

      if (!hasClipBehavior) {
        reporter.atNode(node.constructorName, code);
      }
    });
  }
}

/// Warns when scrollable lists should have a ScrollController.
///
/// ScrollController is needed for infinite scroll and scroll position tracking.
///
/// **BAD:**
/// ```dart
/// ListView.builder(
///   itemBuilder: (context, index) => ListTile(),
///   itemCount: items.length,
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// ListView.builder(
///   controller: _scrollController,
///   itemBuilder: (context, index) => ListTile(),
///   itemCount: items.length,
/// )
/// ```

class RequireScrollControllerRule extends SaropaLintRule {
  const RequireScrollControllerRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'require_scroll_controller',
    problemMessage:
        '[require_scroll_controller] Consider adding ScrollController for scroll tracking.',
    correctionMessage: 'Add controller: _scrollController for infinite scroll.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addInstanceCreationExpression((
      InstanceCreationExpression node,
    ) {
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

class PreferPositionedDirectionalRule extends SaropaLintRule {
  const PreferPositionedDirectionalRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    name: 'prefer_positioned_directional',
    problemMessage:
        '[prefer_positioned_directional] Use PositionedDirectional for RTL support.',
    correctionMessage: 'Replace Positioned with PositionedDirectional.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addInstanceCreationExpression((
      InstanceCreationExpression node,
    ) {
      final String typeName = node.constructorName.type.name.lexeme;
      if (typeName != 'Positioned') return;

      // Check if using left/right (not top/bottom only)
      bool usesLeftRight = false;
      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression) {
          final String argName = arg.name.label.name;
          if (argName == 'left' || argName == 'right') {
            usesLeftRight = true;
            break;
          }
        }
      }

      if (usesLeftRight) {
        reporter.atNode(node.constructorName, code);
      }
    });
  }
}

/// Warns when shrinkWrap: true is used on scrollable widgets.
///
/// shrinkWrap: true causes O(n) layout cost and defeats lazy loading.
/// However, shrinkWrap is sometimes required (e.g. ListView inside a Column)
/// and is safe when paired with NeverScrollableScrollPhysics and a small
/// bounded itemCount. This is a stylistic preference for Slivers over
/// shrinkWrap — see `avoid_shrinkwrap_in_scrollview` for the context-aware
/// rule that targets the genuinely dangerous nested-scrollable case.
///
/// **BAD:**
/// ```dart
/// ListView.builder(
///   shrinkWrap: true,
///   itemBuilder: (context, index) => ListTile(title: Text('$index')),
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// CustomScrollView(
///   slivers: [
///     SliverList(
///       delegate: SliverChildBuilderDelegate(
///         (context, index) => ListTile(title: Text('$index')),
///       ),
///     ),
///   ],
/// )
/// ```

class AvoidShrinkWrapInScrollRule extends SaropaLintRule {
  const AvoidShrinkWrapInScrollRule() : super(code: _code);

  /// Stylistic preference. Large counts are acceptable.
  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    name: 'avoid_shrink_wrap_in_scroll',
    problemMessage:
        '[avoid_shrink_wrap_in_scroll] shrinkWrap: true causes O(n) layout cost and defeats lazy loading.',
    correctionMessage:
        'Use CustomScrollView with Slivers for efficient lazy loading. If this ListView is inside a Column/Row with a small bounded itemCount and NeverScrollableScrollPhysics, shrinkWrap: true is acceptable.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  static const Set<String> _scrollableWidgets = <String>{
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
    context.registry.addInstanceCreationExpression((
      InstanceCreationExpression node,
    ) {
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

class AvoidDeepWidgetNestingRule extends SaropaLintRule {
  const AvoidDeepWidgetNestingRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    name: 'avoid_deep_widget_nesting',
    problemMessage:
        '[avoid_deep_widget_nesting] Widget tree exceeds 15 levels of nesting.',
    correctionMessage:
        'Extract nested widgets into separate methods or widget classes '
        'for better readability and maintainability.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  static const int _maxDepth = 15;

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodDeclaration((MethodDeclaration node) {
      // Only check build methods
      if (node.name.lexeme != 'build') return;

      // Visit the body to find deep nesting (uses existing _WidgetDepthVisitor)
      final _WidgetDepthVisitor visitor =
          _WidgetDepthVisitor(_maxDepth, reporter, code);
      node.body.accept(visitor);
    });
  }
}

/// Warns when Scaffold body content may overlap device notches or system UI.
///
/// Modern phones have notches, rounded corners, and system UI overlays.
/// Content should be wrapped in SafeArea to avoid being obscured.
///
/// **BAD:**
/// ```dart
/// Scaffold(
///   body: Column(
///     children: [
///       Text('Title'), // May be hidden under notch!
///     ],
///   ),
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// Scaffold(
///   body: SafeArea(
///     child: Column(
///       children: [
///         Text('Title'),
///       ],
///     ),
///   ),
/// )
/// ```
///
/// **Also OK (AppBar handles top safe area):**
/// ```dart
/// Scaffold(
///   appBar: AppBar(title: Text('Title')),
///   body: Content(),
/// )
/// ```
///
/// **Also OK (intentionally extends behind system UI):**
/// ```dart
/// Scaffold(
///   extendBody: true, // Intentional: content extends behind nav bar
///   extendBodyBehindAppBar: true, // Intentional: content behind app bar
///   body: FullScreenImage(),
/// )
/// ```

class PreferSafeAreaAwareRule extends SaropaLintRule {
  const PreferSafeAreaAwareRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    name: 'prefer_safe_area_aware',
    problemMessage:
        '[prefer_safe_area_aware] Content may overlap device notch or system UI.',
    correctionMessage:
        'Wrap body content in SafeArea, or use AppBar which handles it '
        'automatically.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addInstanceCreationExpression((
      InstanceCreationExpression node,
    ) {
      final String typeName = node.constructorName.type.name.lexeme;
      if (typeName != 'Scaffold') return;

      // Check for properties that affect safe area handling
      bool hasAppBar = false;
      bool hasExtendBody = false;
      bool hasExtendBehindAppBar = false;
      Expression? bodyExpr;

      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression) {
          final String name = arg.name.label.name;
          if (name == 'appBar') {
            hasAppBar = true;
          }
          if (name == 'body') {
            bodyExpr = arg.expression;
          }
          // extendBody/extendBodyBehindAppBar mean developer intentionally
          // wants content to extend behind system UI (e.g., fullscreen images)
          if (name == 'extendBody') {
            final String value = arg.expression.toSource();
            if (value == 'true') hasExtendBody = true;
          }
          if (name == 'extendBodyBehindAppBar') {
            final String value = arg.expression.toSource();
            if (value == 'true') hasExtendBehindAppBar = true;
          }
        }
      }

      // If has AppBar, it handles the top safe area
      if (hasAppBar) return;

      // If intentionally extending behind system UI, skip
      if (hasExtendBody || hasExtendBehindAppBar) return;

      // If no body, nothing to check
      if (bodyExpr == null) return;

      // Check if body is SafeArea or its child is SafeArea
      if (bodyExpr is InstanceCreationExpression) {
        final String bodyType = bodyExpr.constructorName.type.name.lexeme;

        // Direct SafeArea wrapper is OK
        if (bodyType == 'SafeArea') return;

        // Check common wrapper patterns that handle their own layout
        if (bodyType == 'Builder' ||
            bodyType == 'LayoutBuilder' ||
            bodyType == 'MediaQuery' ||
            bodyType == 'CustomScrollView' ||
            bodyType == 'NestedScrollView') {
          // These often handle safe area internally or via slivers
          return;
        }
      }

      reporter.atNode(node.constructorName, code);
    });
  }
}

/// Warns when SizedBox or Container uses fixed pixel dimensions.
///
/// Fixed pixel dimensions break on different screen sizes. Use responsive
/// sizing with Flexible, Expanded, FractionallySizedBox, or constraints.
///
/// **BAD:**
/// ```dart
/// SizedBox(width: 300, height: 400);
/// Container(width: 500, height: 600);
/// ```
///
/// **GOOD:**
/// ```dart
/// FractionallySizedBox(widthFactor: 0.8, child: content);
/// LayoutBuilder(
///   builder: (context, constraints) => SizedBox(
///     width: constraints.maxWidth * 0.5,
///   ),
/// );
/// Expanded(child: content);
/// ```

class AvoidFixedDimensionsRule extends SaropaLintRule {
  const AvoidFixedDimensionsRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    name: 'avoid_fixed_dimensions',
    problemMessage:
        '[avoid_fixed_dimensions] Fixed pixel dimensions may not work on all screen sizes.',
    correctionMessage:
        'Use responsive sizing (Flexible, Expanded, FractionallySizedBox, or LayoutBuilder).',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  /// Threshold above which fixed dimensions are considered problematic.
  /// Small fixed sizes (icons, spacing) are usually intentional.
  static const double _threshold = 200.0;

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addInstanceCreationExpression((
      InstanceCreationExpression node,
    ) {
      final String? typeName = node.constructorName.type.element?.name;
      if (typeName != 'SizedBox' && typeName != 'Container') return;

      double? width;
      double? height;

      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression) {
          final String name = arg.name.label.name;
          final Expression value = arg.expression;

          if (name == 'width' && value is IntegerLiteral) {
            width = value.value?.toDouble();
          } else if (name == 'width' && value is DoubleLiteral) {
            width = value.value;
          } else if (name == 'height' && value is IntegerLiteral) {
            height = value.value?.toDouble();
          } else if (name == 'height' && value is DoubleLiteral) {
            height = value.value;
          }
        }
      }

      // Only flag if dimensions exceed threshold
      final bool widthTooLarge = width != null && width > _threshold;
      final bool heightTooLarge = height != null && height > _threshold;

      if (widthTooLarge || heightTooLarge) {
        reporter.atNode(node.constructorName, code);
      }
    });
  }
}

/// Warns when hardcoded Color values are used instead of theme colors.
///
/// Hardcoded colors break theming (light/dark mode) and make style changes
/// difficult. Use colorScheme colors from the theme.
///
/// **BAD:**
/// ```dart
/// Container(
///   color: Color(0xFF2196F3), // Hardcoded color
/// )
/// Icon(Icons.home, color: Colors.blue) // Material color constant
/// ```
///
/// **GOOD:**
/// ```dart
/// Container(
///   color: Theme.of(context).colorScheme.primary,
/// )
/// Icon(Icons.home, color: Theme.of(context).colorScheme.onSurface)
/// ```

class AvoidAbsorbPointerMisuseRule extends SaropaLintRule {
  const AvoidAbsorbPointerMisuseRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    name: 'avoid_absorb_pointer_misuse',
    problemMessage:
        '[avoid_absorb_pointer_misuse] AbsorbPointer blocks ALL touch events. Consider IgnorePointer instead.',
    correctionMessage:
        'IgnorePointer lets events pass through; AbsorbPointer stops them completely.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addInstanceCreationExpression((
      InstanceCreationExpression node,
    ) {
      final String typeName = node.constructorName.type.name.lexeme;
      if (typeName != 'AbsorbPointer') return;

      reporter.atNode(node.constructorName, code);
    });
  }
}

/// Warns when Theme.of(context).brightness is used instead of colorScheme.
///
/// Checking brightness manually to pick colors is error-prone and ignores
/// the theme system. Use colorScheme which already provides appropriate
/// colors for the current theme.
///
/// **BAD:**
/// ```dart
/// final isDark = Theme.of(context).brightness == Brightness.dark;
/// final textColor = isDark ? Colors.white : Colors.black;
/// ```
///
/// **GOOD:**
/// ```dart
/// final textColor = Theme.of(context).colorScheme.onSurface;
/// // Or for background:
/// final bgColor = Theme.of(context).colorScheme.surface;
/// ```

class RequireOverflowBoxRationaleRule extends SaropaLintRule {
  const RequireOverflowBoxRationaleRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    name: 'require_overflow_box_rationale',
    problemMessage:
        '[require_overflow_box_rationale] OverflowBox used without comment explaining why overflow is needed.',
    correctionMessage:
        'Add a comment above OverflowBox explaining the intentional overflow.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addInstanceCreationExpression((
      InstanceCreationExpression node,
    ) {
      final String typeName = node.constructorName.type.name.lexeme;

      if (typeName != 'OverflowBox' && typeName != 'SizedOverflowBox') {
        return;
      }

      // Check if there's a comment in the preceding lines
      final Token? precedingToken = node.beginToken.previous;
      if (precedingToken != null) {
        // Check for comments attached to the token
        Token? commentToken = precedingToken;
        while (commentToken != null) {
          if (commentToken.precedingComments != null) {
            // Has a comment, so this is acceptable
            return;
          }
          // Check a few tokens back for comments
          if (commentToken.offset < node.offset - 200) break;
          commentToken = commentToken.previous;
        }
      }

      // Also check if the node itself has preceding comments
      if (node.beginToken.precedingComments != null) {
        return;
      }

      reporter.atNode(node.constructorName, code);
    });
  }

  @override
  List<Fix> getFixes() => <Fix>[_AddOverflowBoxCommentFix()];
}

class _AddOverflowBoxCommentFix extends DartFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    context.registry.addInstanceCreationExpression((
      InstanceCreationExpression node,
    ) {
      if (!node.sourceRange.intersects(analysisError.sourceRange)) return;

      final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
        message: 'Add HACK comment explaining overflow',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        builder.addSimpleInsertion(
          node.offset,
          '// HACK: Explain why OverflowBox is needed here\n',
        );
      });
    });
  }
}

/// Warns when Image widgets don't have sizing constraints.
///
/// Images without sizing constraints cause layout shifts when they load.
/// Always constrain images with explicit dimensions, AspectRatio, or
/// a parent Expanded/Flexible/SizedBox.
///
/// **BAD:**
/// ```dart
/// Image.network('https://example.com/image.jpg')
/// ```
///
/// **GOOD:**
/// ```dart
/// Image.network(
///   'https://example.com/image.jpg',
///   width: 200,
///   height: 150,
/// )
/// // Or:
/// SizedBox(
///   width: 200,
///   height: 150,
///   child: Image.network('https://example.com/image.jpg'),
/// )
/// ```

class AvoidUnconstrainedImagesRule extends SaropaLintRule {
  const AvoidUnconstrainedImagesRule() : super(code: _code);

  /// Layout shifts affect user experience and CLS scores.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    name: 'avoid_unconstrained_images',
    problemMessage:
        '[avoid_unconstrained_images] Image without sizing constraints causes layout shifts on load.',
    correctionMessage:
        'Add width/height, wrap in SizedBox, or use AspectRatio parent.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  static const Set<String> _imageTypes = <String>{
    'Image',
  };

  static const Set<String> _imageFactories = <String>{
    'network',
    'asset',
    'file',
    'memory',
  };

  static const Set<String> _constrainingParents = <String>{
    'SizedBox',
    'Container',
    'AspectRatio',
    'FractionallySizedBox',
    'ConstrainedBox',
    'LimitedBox',
    'FittedBox',
    'Expanded',
    'Flexible',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addInstanceCreationExpression((
      InstanceCreationExpression node,
    ) {
      final String typeName = node.constructorName.type.name.lexeme;

      if (!_imageTypes.contains(typeName)) return;

      // Check for factory constructors like Image.network
      final String? constructorName = node.constructorName.name?.name;
      if (constructorName != null &&
          !_imageFactories.contains(constructorName)) {
        return;
      }

      // Check if width and height are specified
      bool hasWidth = false;
      bool hasHeight = false;

      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression) {
          final String name = arg.name.label.name;
          if (name == 'width') hasWidth = true;
          if (name == 'height') hasHeight = true;
        }
      }

      // If both dimensions specified, it's constrained
      if (hasWidth && hasHeight) return;

      // Check if parent is a constraining widget
      if (_hasConstrainingParent(node)) return;

      reporter.atNode(node.constructorName, code);
    });

    // Also check Image.network(), Image.asset() etc via method invocation
    context.registry.addMethodInvocation((MethodInvocation node) {
      final Expression? target = node.target;
      if (target is! SimpleIdentifier) return;
      if (target.name != 'Image') return;

      final String methodName = node.methodName.name;
      if (!_imageFactories.contains(methodName)) return;

      // Check for width/height arguments
      bool hasWidth = false;
      bool hasHeight = false;

      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression) {
          final String name = arg.name.label.name;
          if (name == 'width') hasWidth = true;
          if (name == 'height') hasHeight = true;
        }
      }

      if (hasWidth && hasHeight) return;

      // Check for constraining parent
      if (_hasConstrainingParent(node)) return;

      reporter.atNode(node, code);
    });
  }

  bool _hasConstrainingParent(AstNode node) {
    AstNode? current = node.parent;
    int depth = 0;

    while (current != null && depth < 5) {
      if (current is InstanceCreationExpression) {
        final String parentType = current.constructorName.type.name.lexeme;
        if (_constrainingParents.contains(parentType)) {
          return true;
        }
      }
      if (current is NamedExpression) {
        // Check if this is inside a 'child' argument of a constraining widget
        final String paramName = current.name.label.name;
        if (paramName == 'child') {
          final AstNode? grandParent = current.parent?.parent;
          if (grandParent is InstanceCreationExpression) {
            final String gpType = grandParent.constructorName.type.name.lexeme;
            if (_constrainingParents.contains(gpType)) {
              return true;
            }
          }
        }
      }
      current = current.parent;
      depth++;
    }
    return false;
  }
}

/// Warns when `SizedBox(width: X, height: X)` with identical dimensions is used.
///
/// **Stylistic rule (opt-in only).** No performance or correctness benefit.
///
/// Use `SizedBox.square(dimension: X)` for clearer intent when width and height
/// are the same value.
///
/// **BAD:**
/// ```dart
/// SizedBox(width: 50, height: 50)
/// SizedBox(width: size, height: size)
/// ```
///
/// **GOOD:**
/// ```dart
/// SizedBox.square(dimension: 50)
/// SizedBox.square(dimension: size)
/// ```
///
/// **Quick fix available:** Replaces with `SizedBox.square(dimension: X)`.

class PreferSizedBoxSquareRule extends SaropaLintRule {
  const PreferSizedBoxSquareRule() : super(code: _code);

  /// Style preference. Large counts acceptable.
  @override
  LintImpact get impact => LintImpact.opinionated;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    name: 'prefer_sized_box_square',
    problemMessage:
        '[prefer_sized_box_square] Using SizedBox(width: x, height: x) instead of SizedBox.square(dimension: x) is a stylistic choice — same widget at runtime, no performance benefit. Enable via the stylistic tier.',
    correctionMessage:
        'Replace with SizedBox.square(dimension: X) for clearer intent.',
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
      // Only check SizedBox constructors (not SizedBox.square, etc.)
      final ConstructorName constructorName = node.constructorName;
      final String typeName = constructorName.type.name.lexeme;
      if (typeName != 'SizedBox') return;

      // Skip named constructors like SizedBox.square, SizedBox.shrink
      if (constructorName.name != null) return;

      String? widthSource;
      String? heightSource;

      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression) {
          final String name = arg.name.label.name;
          if (name == 'width') {
            widthSource = arg.expression.toSource();
          } else if (name == 'height') {
            heightSource = arg.expression.toSource();
          }
        }
      }

      // Must have both width and height
      if (widthSource == null || heightSource == null) return;

      // Check if they are identical
      if (widthSource == heightSource) {
        reporter.atNode(node, code);
      }
    });
  }

  @override
  List<Fix> getFixes() => <Fix>[_PreferSizedBoxSquareFix()];
}

class _PreferSizedBoxSquareFix extends DartFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    context.registry
        .addInstanceCreationExpression((InstanceCreationExpression node) {
      if (!node.sourceRange.intersects(analysisError.sourceRange)) return;

      final ConstructorName constructorName = node.constructorName;
      final String typeName = constructorName.type.name.lexeme;
      if (typeName != 'SizedBox') return;
      if (constructorName.name != null) return;

      String? dimensionSource;
      String? keySource;

      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression) {
          final String name = arg.name.label.name;
          if (name == 'width') {
            dimensionSource = arg.expression.toSource();
          } else if (name == 'key') {
            keySource = arg.expression.toSource();
          }
        }
      }

      if (dimensionSource == null) return;

      // Check for const context
      final bool hasConst =
          node.keyword?.lexeme == 'const' || _isInConstContext(node);
      final String constPrefix = hasConst ? 'const ' : '';

      // Build replacement
      final StringBuffer replacement = StringBuffer();
      replacement.write('${constPrefix}SizedBox.square(');

      final List<String> args = <String>[];
      if (keySource != null) args.add('key: $keySource');
      args.add('dimension: $dimensionSource');
      replacement.write(args.join(', '));
      replacement.write(')');

      final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
        message: 'Replace with SizedBox.square',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        builder.addSimpleReplacement(
          node.sourceRange,
          replacement.toString(),
        );
      });
    });
  }

  bool _isInConstContext(AstNode node) {
    AstNode? current = node.parent;
    while (current != null) {
      if (current is InstanceCreationExpression &&
          current.keyword?.lexeme == 'const') {
        return true;
      }
      if (current is ListLiteral && current.constKeyword != null) {
        return true;
      }
      if (current is SetOrMapLiteral && current.constKeyword != null) {
        return true;
      }
      current = current.parent;
    }
    return false;
  }
}

/// Warns when `Align(alignment: Alignment.center, ...)` is used.
///
/// **Stylistic rule (opt-in only).** No performance or correctness benefit.
///
/// Use `Center` widget for clearer intent when centering content.
/// `Center` is semantically clearer and slightly more efficient.
///
/// **BAD:**
/// ```dart
/// Align(
///   alignment: Alignment.center,
///   child: Text('Hello'),
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// Center(
///   child: Text('Hello'),
/// )
/// ```
///
/// **Quick fix available:** Replaces with `Center(child: ...)`.

class PreferCenterOverAlignRule extends SaropaLintRule {
  const PreferCenterOverAlignRule() : super(code: _code);

  /// Style preference. Large counts acceptable.
  @override
  LintImpact get impact => LintImpact.opinionated;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    name: 'prefer_center_over_align',
    problemMessage:
        '[prefer_center_over_align] Center is identical to Align(alignment: Alignment.center) at runtime — same class, same behavior. Purely stylistic preference with no performance benefit. Enable via the stylistic tier.',
    correctionMessage: 'Replace with Center(child: ...) for clearer intent.',
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
      final String typeName = node.constructorName.type.name.lexeme;
      if (typeName != 'Align') return;

      // Check if alignment is Alignment.center
      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression) {
          final String name = arg.name.label.name;
          if (name == 'alignment') {
            final String alignmentSource = arg.expression.toSource();
            if (alignmentSource == 'Alignment.center') {
              reporter.atNode(node, code);
              return;
            }
          }
        }
      }
    });
  }

  @override
  List<Fix> getFixes() => <Fix>[_PreferCenterOverAlignFix()];
}

class _PreferCenterOverAlignFix extends DartFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    context.registry
        .addInstanceCreationExpression((InstanceCreationExpression node) {
      if (!node.sourceRange.intersects(analysisError.sourceRange)) return;

      final String typeName = node.constructorName.type.name.lexeme;
      if (typeName != 'Align') return;

      String? childSource;
      String? keySource;
      String? widthFactorSource;
      String? heightFactorSource;

      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression) {
          final String name = arg.name.label.name;
          if (name == 'child') {
            childSource = arg.expression.toSource();
          } else if (name == 'key') {
            keySource = arg.expression.toSource();
          } else if (name == 'widthFactor') {
            widthFactorSource = arg.expression.toSource();
          } else if (name == 'heightFactor') {
            heightFactorSource = arg.expression.toSource();
          }
        }
      }

      // Check for const context
      final bool hasConst =
          node.keyword?.lexeme == 'const' || _isInConstContext(node);
      final String constPrefix = hasConst ? 'const ' : '';

      // Build replacement
      final StringBuffer replacement = StringBuffer();
      replacement.write('${constPrefix}Center(');

      final List<String> args = <String>[];
      if (keySource != null) args.add('key: $keySource');
      if (widthFactorSource != null) {
        args.add('widthFactor: $widthFactorSource');
      }
      if (heightFactorSource != null) {
        args.add('heightFactor: $heightFactorSource');
      }
      if (childSource != null) args.add('child: $childSource');
      replacement.write(args.join(', '));
      replacement.write(')');

      final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
        message: 'Replace with Center',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        builder.addSimpleReplacement(
          node.sourceRange,
          replacement.toString(),
        );
      });
    });
  }

  bool _isInConstContext(AstNode node) {
    AstNode? current = node.parent;
    while (current != null) {
      if (current is InstanceCreationExpression &&
          current.keyword?.lexeme == 'const') {
        return true;
      }
      if (current is ListLiteral && current.constKeyword != null) {
        return true;
      }
      if (current is SetOrMapLiteral && current.constKeyword != null) {
        return true;
      }
      current = current.parent;
    }
    return false;
  }
}

/// Warns when `Container` is used only for alignment.
///
/// **Performance benefit:** Container with only alignment creates unnecessary intermediate widgets. Align is a single-purpose widget with fewer allocations.
///
/// Use `Align` widget when Container is only used for the alignment property.
/// This makes the intent clearer and is more efficient.
///
/// **BAD:**
/// ```dart
/// Container(
///   alignment: Alignment.topLeft,
///   child: Text('Hello'),
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// Align(
///   alignment: Alignment.topLeft,
///   child: Text('Hello'),
/// )
/// ```
///
/// **Quick fix available:** Replaces with `Align(alignment: ..., child: ...)`.

class PreferAlignOverContainerRule extends SaropaLintRule {
  const PreferAlignOverContainerRule() : super(code: _code);

  /// Style preference. Large counts acceptable.
  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    name: 'prefer_align_over_container',
    problemMessage:
        '[prefer_align_over_container] Container with only alignment creates unnecessary intermediate widgets. Align is a single-purpose widget with fewer allocations and faster layout computation.',
    correctionMessage:
        'Replace with Align(alignment: ..., child: ...) for clearer intent.',
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
      final String typeName = node.constructorName.type.name.lexeme;
      if (typeName != 'Container') return;

      bool hasAlignment = false;
      bool hasOtherArgs = false;

      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression) {
          final String name = arg.name.label.name;
          switch (name) {
            case 'alignment':
              hasAlignment = true;
            case 'child':
            case 'key':
              // These are allowed
              break;
            default:
              hasOtherArgs = true;
          }
        } else {
          hasOtherArgs = true;
        }
      }

      // Report if Container only has alignment (+ optional key and child)
      if (hasAlignment && !hasOtherArgs) {
        reporter.atNode(node, code);
      }
    });
  }

  @override
  List<Fix> getFixes() => <Fix>[_PreferAlignOverContainerFix()];
}

class _PreferAlignOverContainerFix extends DartFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    context.registry
        .addInstanceCreationExpression((InstanceCreationExpression node) {
      if (!node.sourceRange.intersects(analysisError.sourceRange)) return;

      final String typeName = node.constructorName.type.name.lexeme;
      if (typeName != 'Container') return;

      String? alignmentSource;
      String? childSource;
      String? keySource;

      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression) {
          final String name = arg.name.label.name;
          if (name == 'alignment') {
            alignmentSource = arg.expression.toSource();
          } else if (name == 'child') {
            childSource = arg.expression.toSource();
          } else if (name == 'key') {
            keySource = arg.expression.toSource();
          }
        }
      }

      if (alignmentSource == null) return;

      // Check for const context
      final bool hasConst =
          node.keyword?.lexeme == 'const' || _isInConstContext(node);
      final String constPrefix = hasConst ? 'const ' : '';

      // Build replacement
      final StringBuffer replacement = StringBuffer();
      replacement.write('${constPrefix}Align(');

      final List<String> args = <String>[];
      if (keySource != null) args.add('key: $keySource');
      args.add('alignment: $alignmentSource');
      if (childSource != null) args.add('child: $childSource');
      replacement.write(args.join(', '));
      replacement.write(')');

      final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
        message: 'Replace with Align',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        builder.addSimpleReplacement(
          node.sourceRange,
          replacement.toString(),
        );
      });
    });
  }

  bool _isInConstContext(AstNode node) {
    AstNode? current = node.parent;
    while (current != null) {
      if (current is InstanceCreationExpression &&
          current.keyword?.lexeme == 'const') {
        return true;
      }
      if (current is ListLiteral && current.constKeyword != null) {
        return true;
      }
      if (current is SetOrMapLiteral && current.constKeyword != null) {
        return true;
      }
      current = current.parent;
    }
    return false;
  }
}

/// Warns when `Container` is used only for padding.
///
/// **Performance benefit:** Container with only padding creates unnecessary intermediate widgets. Padding is a single-purpose widget with fewer allocations.
///
/// Use `Padding` widget when Container is only used for the padding property.
/// This makes the intent clearer and is more efficient.
///
/// **BAD:**
/// ```dart
/// Container(
///   padding: EdgeInsets.all(16),
///   child: Text('Hello'),
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// Padding(
///   padding: EdgeInsets.all(16),
///   child: Text('Hello'),
/// )
/// ```
///
/// **Quick fix available:** Replaces with `Padding(padding: ..., child: ...)`.

class PreferPaddingOverContainerRule extends SaropaLintRule {
  const PreferPaddingOverContainerRule() : super(code: _code);

  /// Style preference. Large counts acceptable.
  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    name: 'prefer_padding_over_container',
    problemMessage:
        '[prefer_padding_over_container] Container with only padding creates unnecessary intermediate widgets (DecoratedBox, ConstrainedBox). Padding is a single-purpose widget with fewer allocations and faster layout.',
    correctionMessage:
        'Replace with Padding(padding: ..., child: ...) for clearer intent.',
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
      final String typeName = node.constructorName.type.name.lexeme;
      if (typeName != 'Container') return;

      bool hasPadding = false;
      bool hasOtherArgs = false;

      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression) {
          final String name = arg.name.label.name;
          switch (name) {
            case 'padding':
              hasPadding = true;
            case 'child':
            case 'key':
              // These are allowed
              break;
            default:
              hasOtherArgs = true;
          }
        } else {
          hasOtherArgs = true;
        }
      }

      // Report if Container only has padding (+ optional key and child)
      if (hasPadding && !hasOtherArgs) {
        reporter.atNode(node, code);
      }
    });
  }

  @override
  List<Fix> getFixes() => <Fix>[_PreferPaddingOverContainerFix()];
}

class _PreferPaddingOverContainerFix extends DartFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    context.registry
        .addInstanceCreationExpression((InstanceCreationExpression node) {
      if (!node.sourceRange.intersects(analysisError.sourceRange)) return;

      final String typeName = node.constructorName.type.name.lexeme;
      if (typeName != 'Container') return;

      String? paddingSource;
      String? childSource;
      String? keySource;

      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression) {
          final String name = arg.name.label.name;
          if (name == 'padding') {
            paddingSource = arg.expression.toSource();
          } else if (name == 'child') {
            childSource = arg.expression.toSource();
          } else if (name == 'key') {
            keySource = arg.expression.toSource();
          }
        }
      }

      if (paddingSource == null) return;

      // Check for const context
      final bool hasConst =
          node.keyword?.lexeme == 'const' || _isInConstContext(node);
      final String constPrefix = hasConst ? 'const ' : '';

      // Build replacement
      final StringBuffer replacement = StringBuffer();
      replacement.write('${constPrefix}Padding(');

      final List<String> args = <String>[];
      if (keySource != null) args.add('key: $keySource');
      args.add('padding: $paddingSource');
      if (childSource != null) args.add('child: $childSource');
      replacement.write(args.join(', '));
      replacement.write(')');

      final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
        message: 'Replace with Padding',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        builder.addSimpleReplacement(
          node.sourceRange,
          replacement.toString(),
        );
      });
    });
  }

  bool _isInConstContext(AstNode node) {
    AstNode? current = node.parent;
    while (current != null) {
      if (current is InstanceCreationExpression &&
          current.keyword?.lexeme == 'const') {
        return true;
      }
      if (current is ListLiteral && current.constKeyword != null) {
        return true;
      }
      if (current is SetOrMapLiteral && current.constKeyword != null) {
        return true;
      }
      current = current.parent;
    }
    return false;
  }
}

/// Warns when `Container` is used only for constraints.
///
/// Use `ConstrainedBox` widget when Container is only used for constraints.
/// This makes the intent clearer and is more efficient.
///
/// **BAD:**
/// ```dart
/// Container(
///   constraints: BoxConstraints(maxWidth: 200),
///   child: Text('Hello'),
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// ConstrainedBox(
///   constraints: BoxConstraints(maxWidth: 200),
///   child: Text('Hello'),
/// )
/// ```
///
/// **Quick fix available:** Replaces with `ConstrainedBox(constraints: ..., child: ...)`.

class PreferConstrainedBoxOverContainerRule extends SaropaLintRule {
  const PreferConstrainedBoxOverContainerRule() : super(code: _code);

  /// Style preference. Large counts acceptable.
  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    name: 'prefer_constrained_box_over_container',
    problemMessage:
        '[prefer_constrained_box_over_container] Container with only constraints should use ConstrainedBox instead.',
    correctionMessage:
        'Replace with ConstrainedBox(constraints: ...) for clearer intent.',
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
      final String typeName = node.constructorName.type.name.lexeme;
      if (typeName != 'Container') return;

      bool hasConstraints = false;
      bool hasOtherArgs = false;

      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression) {
          final String name = arg.name.label.name;
          switch (name) {
            case 'constraints':
              hasConstraints = true;
            case 'child':
            case 'key':
              // These are allowed
              break;
            default:
              hasOtherArgs = true;
          }
        } else {
          hasOtherArgs = true;
        }
      }

      // Report if Container only has constraints (+ optional key and child)
      if (hasConstraints && !hasOtherArgs) {
        reporter.atNode(node, code);
      }
    });
  }

  @override
  List<Fix> getFixes() => <Fix>[_PreferConstrainedBoxOverContainerFix()];
}

class _PreferConstrainedBoxOverContainerFix extends DartFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    context.registry
        .addInstanceCreationExpression((InstanceCreationExpression node) {
      if (!node.sourceRange.intersects(analysisError.sourceRange)) return;

      final String typeName = node.constructorName.type.name.lexeme;
      if (typeName != 'Container') return;

      String? constraintsSource;
      String? childSource;
      String? keySource;

      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression) {
          final String name = arg.name.label.name;
          if (name == 'constraints') {
            constraintsSource = arg.expression.toSource();
          } else if (name == 'child') {
            childSource = arg.expression.toSource();
          } else if (name == 'key') {
            keySource = arg.expression.toSource();
          }
        }
      }

      if (constraintsSource == null) return;

      // Check for const context
      final bool hasConst =
          node.keyword?.lexeme == 'const' || _isInConstContext(node);
      final String constPrefix = hasConst ? 'const ' : '';

      // Build replacement
      final StringBuffer replacement = StringBuffer();
      replacement.write('${constPrefix}ConstrainedBox(');

      final List<String> args = <String>[];
      if (keySource != null) args.add('key: $keySource');
      args.add('constraints: $constraintsSource');
      if (childSource != null) args.add('child: $childSource');
      replacement.write(args.join(', '));
      replacement.write(')');

      final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
        message: 'Replace with ConstrainedBox',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        builder.addSimpleReplacement(
          node.sourceRange,
          replacement.toString(),
        );
      });
    });
  }

  bool _isInConstContext(AstNode node) {
    AstNode? current = node.parent;
    while (current != null) {
      if (current is InstanceCreationExpression &&
          current.keyword?.lexeme == 'const') {
        return true;
      }
      if (current is ListLiteral && current.constKeyword != null) {
        return true;
      }
      if (current is SetOrMapLiteral && current.constKeyword != null) {
        return true;
      }
      current = current.parent;
    }
    return false;
  }
}

/// Warns when Container is used only for a transform.
///
/// When Container only has a transform property, use Transform widget
/// instead for better semantics and performance.
///
/// ### Example
///
/// #### BAD:
/// ```dart
/// Container(
///   transform: Matrix4.rotationZ(0.5),
///   child: Text('Rotated'),
/// )
/// ```
///
/// #### GOOD:
/// ```dart
/// Transform(
///   transform: Matrix4.rotationZ(0.5),
///   child: Text('Rotated'),
/// )
/// ```

class PreferTransformOverContainerRule extends SaropaLintRule {
  const PreferTransformOverContainerRule() : super(code: _code);

  /// Code quality improvement.
  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    name: 'prefer_transform_over_container',
    problemMessage:
        '[prefer_transform_over_container] Container with only transform should be a Transform.',
    correctionMessage: 'Use Transform widget for transform-only containers.',
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
      final String typeName = node.constructorName.type.name.lexeme;
      if (typeName != 'Container') return;

      final ArgumentList args = node.argumentList;

      bool hasTransform = false;
      bool hasOtherProperties = false;

      for (final Expression arg in args.arguments) {
        if (arg is NamedExpression) {
          final String name = arg.name.label.name;
          if (name == 'transform') {
            hasTransform = true;
          } else if (name != 'child' && name != 'key') {
            // Has other visual properties
            hasOtherProperties = true;
          }
        }
      }

      if (hasTransform && !hasOtherProperties) {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when IconButton lacks a tooltip for accessibility.
///
/// IconButtons should have tooltips for accessibility - they describe
/// the action for screen readers and on long-press for all users.
///
/// ### Example
///
/// #### BAD:
/// ```dart
/// IconButton(
///   icon: Icon(Icons.delete),
///   onPressed: () => deleteItem(),
/// )
/// ```
///
/// #### GOOD:
/// ```dart
/// IconButton(
///   icon: Icon(Icons.delete),
///   onPressed: () => deleteItem(),
///   tooltip: 'Delete item',
/// )
/// ```

class RequirePhysicsForNestedScrollRule extends SaropaLintRule {
  const RequirePhysicsForNestedScrollRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    name: 'require_physics_for_nested_scroll',
    problemMessage:
        '[require_physics_for_nested_scroll] Nested scrollable widget lacks NeverScrollableScrollPhysics, causing competing scroll gestures between parent and child. This produces unpredictable scroll behavior, jank, and a confusing user experience where swipes affect the wrong scrollable.',
    correctionMessage:
        'Add physics: NeverScrollableScrollPhysics() to the inner scrollable so only the parent scrollable responds to user gestures.',
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

class AvoidStackWithoutPositionedRule extends SaropaLintRule {
  const AvoidStackWithoutPositionedRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    name: 'avoid_stack_without_positioned',
    problemMessage:
        '[avoid_stack_without_positioned] Stack child without Positioned. Layout may be unexpected.',
    correctionMessage:
        'Wrap child in Positioned to explicitly control its position.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  static const Set<String> _positionedTypes = <String>{
    'Positioned',
    'AnimatedPositioned',
    'PositionedDirectional',
    'Align',
    'Center',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addInstanceCreationExpression((
      InstanceCreationExpression node,
    ) {
      final String typeName = node.constructorName.type.name.lexeme;
      if (typeName != 'Stack') return;

      // Find children parameter
      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression && arg.name.label.name == 'children') {
          final Expression childrenExpr = arg.expression;
          if (childrenExpr is ListLiteral) {
            // Skip if first child is a background (common pattern)
            final elements = childrenExpr.elements;
            if (elements.length < 2) return;

            // Check non-first children (first is usually background)
            for (int i = 1; i < elements.length; i++) {
              final element = elements[i];
              if (element is Expression) {
                _checkStackChild(element, reporter);
              }
            }
          }
        }
      }
    });
  }

  void _checkStackChild(Expression child, SaropaDiagnosticReporter reporter) {
    String? childType;

    if (child is InstanceCreationExpression) {
      childType = child.constructorName.type.name.lexeme;
    } else {
      return; // Skip complex expressions
    }

    // Skip if it's a positioning widget
    if (_positionedTypes.contains(childType)) return;

    // Skip common fill widgets
    if (childType == 'Expanded' ||
        childType == 'Container' ||
        childType == 'SizedBox' ||
        childType == 'DecoratedBox') {
      return;
    }

    reporter.atNode(child, code);
  }
}

/// Warns when Expanded or Flexible is used outside Row, Column, or Flex.
///
/// Alias: expanded_outside_flex, flexible_parent
///
/// Expanded and Flexible only work inside Flex widgets (Row, Column, Flex).
/// Using them elsewhere causes runtime errors.
///
/// ## Why This Crashes
///
/// Expanded, Flexible, and Spacer work by writing `FlexParentData` onto their
/// child's render object. Only `RenderFlex` — the render object behind Row,
/// Column, and Flex — reads that data during layout. Every other parent render
/// object either ignores or rejects it. When Flutter detects the mismatch it
/// throws an unrecoverable `ParentDataWidget` error that cannot be caught by
/// try-catch.
///
/// The most dangerous variant is when a reusable widget returns Expanded from
/// its `build()` method. The widget appears to work when placed directly in a
/// Row, but the moment anyone wraps it — with Padding, LimitedBox,
/// GestureDetector, or any other widget — the Flex→Expanded parent chain
/// breaks and the app crashes at runtime.
///
/// **BAD - Inside non-Flex container:**
/// ```dart
/// Stack(
///   children: [
///     Expanded(child: Container()), // CRASH!
///   ],
/// )
/// ```
///
/// **BAD - Wrapped by RenderObject widgets:**
/// ```dart
/// class _MyWidget extends StatelessWidget {
///   Widget build(BuildContext context) => Expanded(child: Text('Hi'));
/// }
/// // Usage: Row(children: [Padding(child: _MyWidget())]) // CRASH!
/// // The Padding breaks the Flex→Expanded parent chain.
/// ```
///
/// **GOOD - Direct child of Flex:**
/// ```dart
/// Column(
///   children: [
///     Expanded(child: Container()),
///   ],
/// )
/// ```
///
/// **GOOD - Assigned to variable, used in Flex:**
/// ```dart
/// final content = Expanded(child: Text('Hi'));
/// return Column(children: [content]); // OK - lint trusts variable usage
/// ```
///
/// **GOOD - Helper method returning Expanded:**
/// ```dart
/// List<Widget> _buildChildren() {
///   return [Expanded(child: Text('Hi'))]; // OK - trusts helper methods
/// }
/// Widget build(BuildContext context) => Row(children: _buildChildren());
/// ```
///
/// **GOOD - Collection builders (List.generate, .map):**
/// ```dart
/// Column(
///   children: List.generate(3, (i) => Expanded(child: Text('$i'))), // OK
/// )
/// Row(
///   children: items.map((i) => Expanded(child: Text(i))).toList(), // OK
/// )
/// ```
///
/// ## Trusted Patterns (No False Positives)
///
/// The rule trusts these patterns and does not report them:
/// - **Variable assignment**: `final x = Expanded(...);`
/// - **Helper method returns**: Expanded in return statements of non-build methods
/// - **Collection builders**: Expanded inside `List.generate()` or `.map()` callbacks
///
/// ## When to Ignore
///
/// Use `// ignore: avoid_expanded_outside_flex` if the widget's `build()`
/// returns Expanded and you're certain it's only used as a direct Flex child.
///
/// ## Design Guidance
///
/// Prefer adding Expanded at the **call site** rather than inside widget
/// definitions. This makes the flex behavior explicit and avoids crashes
/// when the widget is wrapped with Padding, GestureDetector, etc.

class AvoidExpandedOutsideFlexRule extends SaropaLintRule {
  const AvoidExpandedOutsideFlexRule() : super(code: _code);

  /// Expanded/Flexible outside Flex causes runtime crash.
  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    name: 'avoid_expanded_outside_flex',
    problemMessage:
        '[avoid_expanded_outside_flex] Expanded, Flexible, and Spacer set '
        'FlexParentData on their child, which only RenderFlex (Row, Column, '
        'Flex) can read during layout. Placing them inside any other parent '
        '— Stack, Center, Padding, LimitedBox, SizedBox, etc. — throws an '
        'unrecoverable "Incorrect use of ParentDataWidget" FlutterError at '
        'runtime. This also happens indirectly when a widget\'s build() '
        'returns Expanded and the widget is later wrapped by a non-Flex '
        'container, breaking the Flex→Expanded parent chain.',
    correctionMessage:
        'Move Expanded/Flexible/Spacer so it is a direct child of Row, '
        'Column, or Flex. If a reusable widget needs to expand, remove '
        'Expanded from its build() method and let the caller wrap it at '
        'the call site where the Flex parent is visible.',
    errorSeverity: DiagnosticSeverity.ERROR,
  );

  static const Set<String> _flexTypes = <String>{
    'Row',
    'Column',
    'Flex',
  };

  static const Set<String> _flexChildTypes = <String>{
    'Expanded',
    'Flexible',
    'Spacer',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addInstanceCreationExpression((
      InstanceCreationExpression node,
    ) {
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
  const PreferExpandedAtCallSiteRule() : super(code: _code);

  /// Expanded/Flexible/Spacer in build() causes runtime crash if misused.
  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => <FileType>{FileType.widget};

  static const LintCode _code = LintCode(
    name: 'prefer_expanded_at_call_site',
    problemMessage:
        '[prefer_expanded_at_call_site] Expanded/Flexible/Spacer returned from build() forces flex layout on all callers, breaking reuse in non-flex contexts. '
        'If this widget is placed inside a Stack, SingleChildScrollView, or any non-flex parent, the Expanded wrapper triggers a runtime ParentDataWidget error and crashes the app.',
    correctionMessage:
        'Return the child widget directly and let the caller wrap with Expanded or Flexible as needed. '
        'This keeps the widget reusable in any layout context (Row, Column, Stack, etc.) and follows the principle of letting the parent control how its children are sized and positioned.',
    errorSeverity: DiagnosticSeverity.ERROR,
  );

  static const Set<String> _flexChildTypes = <String>{
    'Expanded',
    'Flexible',
    'Spacer',
  };

  @override
  List<Fix> getFixes() => <Fix>[_PreferExpandedAtCallSiteFix()];

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodDeclaration((MethodDeclaration node) {
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
class _PreferExpandedAtCallSiteFix extends DartFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    context.registry.addInstanceCreationExpression((
      InstanceCreationExpression node,
    ) {
      if (!analysisError.sourceRange.intersects(
        node.constructorName.sourceRange,
      )) {
        return;
      }

      final Expression? childExpr = _extractChild(node);
      if (childExpr == null) return;

      final String typeName = node.constructorName.type.name.lexeme;
      final changeBuilder = reporter.createChangeBuilder(
        message: 'Unwrap $typeName — return child directly',
        priority: 80,
      );

      changeBuilder.addDartFileEdit((builder) {
        builder.addSimpleReplacement(
          node.sourceRange,
          childExpr.toSource(),
        );
      });
    });
  }

  /// Extracts the `child` argument expression from a constructor call.
  Expression? _extractChild(InstanceCreationExpression node) {
    for (final Expression arg in node.argumentList.arguments) {
      if (arg is NamedExpression && arg.name.label.name == 'child') {
        return arg.expression;
      }
    }
    return null;
  }
}

// =============================================================================
// NEW RULES v2.3.11
// =============================================================================

// cspell:ignore itembuilder

/// Warns when ListView.builder itemBuilder may access index out of bounds.
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

class AvoidBuilderIndexOutOfBoundsRule extends SaropaLintRule {
  const AvoidBuilderIndexOutOfBoundsRule() : super(code: _code);

  /// Index out of bounds crashes the app.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    name: 'avoid_builder_index_out_of_bounds',
    problemMessage:
        '[avoid_builder_index_out_of_bounds] itemBuilder accesses list without bounds check. If the index is out of bounds due to list changes, this will cause runtime exceptions, app crashes, and unpredictable UI behavior. This is a common source of production bugs in dynamic lists and can lead to negative user reviews.',
    correctionMessage:
        'Add bounds check: if (index >= items.length) return a fallback widget or null. Always validate index before accessing list elements in itemBuilder. Add tests for edge cases and dynamic list updates.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  // Matches: items[index], data[i], _list[index], widget.items[index]
  // Captures the list variable name (group 1)
  static final RegExp _indexAccessPattern = RegExp(
    r'(\b[a-zA-Z_][\w.]*)\s*\[\s*(?:index|i)\s*\]',
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addNamedExpression((NamedExpression node) {
      if (node.name.label.name != 'itemBuilder') return;

      final Expression builderExpr = node.expression;
      if (builderExpr is! FunctionExpression) return;

      final FunctionBody body = builderExpr.body;
      final String bodySource = body.toSource();

      // Extract all list variables being accessed with [index] or [i]
      final Iterable<RegExpMatch> matches =
          _indexAccessPattern.allMatches(bodySource);
      if (matches.isEmpty) return;

      // Get unique list names being accessed
      final Set<String> accessedLists = matches
          .map((m) => m.group(1)!)
          .map(_extractListName) // Get base name for property access
          .toSet();

      // Check if itemCount is bound to any accessed list's .length.
      // When itemCount: list.length is set, Flutter guarantees
      // index < list.length, making explicit bounds checks redundant.
      final Set<String> itemCountBoundLists = _getItemCountBoundLists(node);

      // Check if ANY accessed list has a proper bounds check
      for (final String listName in accessedLists) {
        // Skip lists whose bounds are guaranteed by itemCount
        if (itemCountBoundLists.contains(listName)) continue;

        if (!_hasBoundsCheckForList(bodySource, listName)) {
          reporter.atNode(node, code);
          return; // Report once per itemBuilder
        }
      }
    });
  }

  /// Extracts the base list name from property access patterns.
  /// 'widget.items' -> 'items', 'items' -> 'items', '_data' -> '_data'
  String _extractListName(String fullName) {
    final int lastDot = fullName.lastIndexOf('.');
    return lastDot >= 0 ? fullName.substring(lastDot + 1) : fullName;
  }

  /// Checks if there's a bounds check for the specific list variable.
  bool _hasBoundsCheckForList(String bodySource, String listName) {
    // Check for: listName.length with comparison
    // Patterns: index >= list.length, index < list.length, list.length > index
    final bool hasLengthCheck = bodySource.contains('$listName.length') &&
        (bodySource.contains('>=') ||
            bodySource.contains('>') ||
            bodySource.contains('<') ||
            bodySource.contains('<='));

    // Check for: listName.isEmpty or listName.isNotEmpty
    final bool hasEmptyCheck = bodySource.contains('$listName.isEmpty') ||
        bodySource.contains('$listName.isNotEmpty');

    return hasLengthCheck || hasEmptyCheck;
  }

  /// Extracts list names that are bound via itemCount in sibling arguments.
  ///
  /// When `itemCount: contacts.length` is set on the same widget,
  /// Flutter guarantees `0 <= index < contacts.length`, so explicit
  /// bounds checks in `itemBuilder` are redundant for that list.
  Set<String> _getItemCountBoundLists(NamedExpression itemBuilderNode) {
    final AstNode? argumentList = itemBuilderNode.parent;
    if (argumentList is! ArgumentList) return const <String>{};

    for (final Expression arg in argumentList.arguments) {
      if (arg is NamedExpression && arg.name.label.name == 'itemCount') {
        final String countSource = arg.expression.toSource();
        // Match: list.length, widget.list.length, _list.length
        final RegExp lengthPattern = RegExp(r'(\b[a-zA-Z_][\w.]*?)\.length\b');
        final RegExpMatch? match = lengthPattern.firstMatch(countSource);
        if (match != null) {
          return <String>{_extractListName(match.group(1)!)};
        }
        break;
      }
    }

    return const <String>{};
  }

  // No quick fix - bounds checking requires knowing variable names and fallback widgets
}

// =============================================================================
// NEW ROADMAP STAR RULES - Widget Lifecycle Rules
// =============================================================================

/// Warns when WidgetsBinding.instance.addPostFrameCallback is not used properly.
///
/// Use addPostFrameCallback for operations that need to run after the frame
/// is rendered, like showing dialogs or measuring widgets.
///
/// **BAD:**
/// ```dart
/// @override
/// void initState() {
///   super.initState();
///   showDialog(context: context, ...); // Context not ready!
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// @override
/// void initState() {
///   super.initState();
///   WidgetsBinding.instance.addPostFrameCallback((_) {
///     showDialog(context: context, ...);
///   });
/// }
/// ```

class PreferCustomSingleChildLayoutRule extends SaropaLintRule {
  const PreferCustomSingleChildLayoutRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    name: 'prefer_custom_single_child_layout',
    problemMessage:
        '[prefer_custom_single_child_layout] Deeply nested positioning widgets. Consider CustomSingleChildLayout.',
    correctionMessage:
        'Use CustomSingleChildLayout with a delegate for complex single-child positioning.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  static const Set<String> _positioningWidgets = {
    'Positioned',
    'Align',
    'Transform',
    'FractionalTranslation',
    'Padding',
  };

  static const int _nestingThreshold = 3;

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry
        .addInstanceCreationExpression((InstanceCreationExpression node) {
      final String widgetName = node.constructorName.type.name2.lexeme;

      if (!_positioningWidgets.contains(widgetName)) return;

      // Count nesting depth of positioning widgets
      int depth = 1;
      AstNode? current = node.parent;
      while (current != null) {
        if (current is InstanceCreationExpression) {
          final String parentName = current.constructorName.type.name2.lexeme;
          if (_positioningWidgets.contains(parentName)) {
            depth++;
          }
        }
        current = current.parent;
      }

      if (depth >= _nestingThreshold) {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when text operations are done without explicit Locale.
///
/// Some text operations (date formatting, number formatting, sorting)
/// produce incorrect results without explicit Locale.
///
/// **BAD:**
/// ```dart
/// final formatted = NumberFormat.currency().format(amount); // Uses device locale!
/// final date = DateFormat.yMd().format(now); // May vary by device!
/// names.sort(); // String sorting depends on locale!
/// ```
///
/// **GOOD:**
/// ```dart
/// final formatted = NumberFormat.currency(locale: 'en_US').format(amount);
/// final date = DateFormat.yMd('en_US').format(now);
/// names.sort((a, b) => a.compareTo(b)); // Or use explicit collation
/// ```

// =========================================================================
// Shared helper: Widget ancestor walking
// =========================================================================

/// Result of searching for a widget ancestor in the AST.
enum _AncestorResult {
  /// Found the expected parent widget.
  found,

  /// Found a widget that breaks the expected relationship.
  wrongParent,

  /// Hit a boundary (method, variable, callback) -- cannot determine.
  indeterminate,

  /// Reached max depth or top of tree without finding anything.
  notFound,
}

/// Walks up the AST from [startNode] looking for a parent widget whose
/// constructor name is in [targetParents].
///
/// When [checkSuperTypes] is `true`, also matches parent widgets whose type
/// hierarchy includes any of [targetParents] (e.g. a custom widget that
/// extends `Stack` will match `{'Stack'}`).
///
/// Returns [_AncestorResult.found] if a target parent is found.
/// Returns [_AncestorResult.wrongParent] if a widget in [stopAt] is found
/// before any target parent.
/// Returns [_AncestorResult.indeterminate] at method/function/variable
/// boundaries where the widget may be used correctly at the call site.
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
    // Stop at variable declarations -- can't track where value is used.
    if (current is VariableDeclaration) return _AncestorResult.indeterminate;

    // Stop at assignments -- can't track where the variable ends up.
    if (current is AssignmentExpression) return _AncestorResult.indeterminate;

    // Trust return statements in helper methods (not build).
    if (current is ReturnStatement) {
      final method = current.thisOrAncestorOfType<MethodDeclaration>();
      if (method != null && method.name.lexeme != 'build') {
        return _AncestorResult.indeterminate;
      }
    }

    // Trust collection-building patterns (.generate, .map).
    if (current is MethodInvocation) {
      final name = current.methodName.name;
      if (name == 'generate' || name == 'map') {
        return _AncestorResult.indeterminate;
      }
    }

    // Trust callbacks in collection builders and named-parameter callbacks.
    if (current is FunctionExpression) {
      final feParent = current.parent;

      // Named-parameter callbacks (e.g. builder: (ctx) => Positioned(...)).
      // The callback output's placement depends on the call site, not this
      // widget, so we cannot determine the ancestor statically.
      if (feParent is NamedExpression) {
        return _AncestorResult.indeterminate;
      }

      // Positional args in .generate() / .map().
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

    // Check widget constructors.
    if (current is InstanceCreationExpression) {
      final String parentType = current.constructorName.type.name.lexeme;
      if (targetParents.contains(parentType)) return _AncestorResult.found;
      if (stopAt.contains(parentType)) return _AncestorResult.wrongParent;

      // Check if the parent widget is a subclass of any target.
      if (checkSuperTypes) {
        if (_isSubtypeOfAny(current.staticType, targetParents)) {
          return _AncestorResult.found;
        }
      }

      passedThroughWidget = true;
    }

    // Stop at method/function boundaries.
    if (current is MethodDeclaration) {
      if (current.name.lexeme != 'build') {
        return _AncestorResult.indeterminate;
      }
      // In build(): if no intermediate widget constructor was found, the
      // node is the root widget returned from this build method. Its
      // eventual parent depends on how the caller places this widget, so
      // we cannot determine correctness here.
      if (!passedThroughWidget) {
        return _AncestorResult.indeterminate;
      }
      break;
    }
    if (current is FunctionDeclaration) return _AncestorResult.indeterminate;

    current = current.parent;
    depth++;
  }

  return _AncestorResult.notFound;
}

/// Returns `true` when [type] is an [InterfaceType] whose supertype chain
/// contains a type whose name is in [targetNames].
bool _isSubtypeOfAny(DartType? type, Set<String> targetNames) {
  if (type is! InterfaceType) return false;
  for (final InterfaceType supertype in type.allSupertypes) {
    if (targetNames.contains(supertype.element.name)) return true;
  }
  return false;
}

// =========================================================================
// Rule: avoid_table_cell_outside_table
// =========================================================================

/// Warns when `TableCell` is used outside of a `Table` widget.
///
/// `TableCell` is a `ParentDataWidget` that requires a `Table` parent
/// to provide the correct `TableCellParentData`. Using it elsewhere
/// causes a ParentData crash at runtime.
///
/// **BAD:**
/// ```dart
/// Column(children: [TableCell(child: Text('x'))]) // Crash!
/// ```
///
/// **GOOD:**
/// ```dart
/// Table(children: [TableRow(children: [TableCell(child: Text('x'))])])
/// ```
class AvoidTableCellOutsideTableRule extends SaropaLintRule {
  const AvoidTableCellOutsideTableRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    name: 'avoid_table_cell_outside_table',
    problemMessage:
        '[avoid_table_cell_outside_table] TableCell used outside of a '
        'Table widget. This causes a ParentData crash at runtime.',
    correctionMessage:
        'Place TableCell inside a TableRow within a Table widget.',
    errorSeverity: DiagnosticSeverity.ERROR,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addInstanceCreationExpression((
      InstanceCreationExpression node,
    ) {
      final String typeName = node.constructorName.type.name.lexeme;
      if (typeName != 'TableCell') return;

      final result = _findWidgetAncestor(
        node,
        targetParents: const <String>{'Table'},
      );

      if (result == _AncestorResult.found) return;
      if (result == _AncestorResult.indeterminate) return;
      reporter.atNode(node.constructorName, code);
    });
  }
}

// =========================================================================
// Rule: avoid_positioned_outside_stack
// =========================================================================

/// Warns when `Positioned` is used outside of a `Stack` widget.
///
/// `Positioned` is a `ParentDataWidget` that communicates position
/// coordinates to a `Stack` parent. Using it outside a `Stack` (or a
/// subclass of `Stack`) causes a ParentData crash at runtime.
///
/// Recognises `Stack`, `IndexedStack`, and any custom widget that
/// extends `Stack` (e.g. `Indexer` from `package:indexed`).
///
/// **BAD:**
/// ```dart
/// Column(children: [Positioned(top: 10, child: Text('x'))]) // Crash!
/// ```
///
/// **GOOD:**
/// ```dart
/// Stack(children: [Positioned(top: 10, child: Text('x'))])
/// ```
class AvoidPositionedOutsideStackRule extends SaropaLintRule {
  const AvoidPositionedOutsideStackRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    name: 'avoid_positioned_outside_stack',
    problemMessage:
        '[avoid_positioned_outside_stack] Positioned widget used outside '
        'of a Stack. This causes a ParentData crash at runtime.',
    correctionMessage:
        'Place Positioned widgets only inside a Stack or Stack subclass.',
    errorSeverity: DiagnosticSeverity.ERROR,
  );

  static const Set<String> _positionedTypes = <String>{
    'Positioned',
    'AnimatedPositioned',
    'PositionedDirectional',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addInstanceCreationExpression((
      InstanceCreationExpression node,
    ) {
      final String typeName = node.constructorName.type.name.lexeme;
      if (!_positionedTypes.contains(typeName)) return;

      final result = _findWidgetAncestor(
        node,
        targetParents: const <String>{'Stack', 'IndexedStack'},
        checkSuperTypes: true,
      );

      if (result == _AncestorResult.found) return;
      if (result == _AncestorResult.indeterminate) return;
      reporter.atNode(node.constructorName, code);
    });
  }
}

// =========================================================================
// Rule: avoid_spacer_in_wrap
// =========================================================================

/// Warns when `Spacer` or `Expanded` is used inside a `Wrap` widget.
///
/// `Wrap` does not extend `Flex` and does not support flex-based sizing.
/// `Spacer` and `Expanded` require a `Flex` parent (Row/Column/Flex)
/// to calculate their size. Using them inside `Wrap` causes a crash.
///
/// **BAD:**
/// ```dart
/// Wrap(children: [Text('a'), Spacer(), Text('b')]) // Crash!
/// ```
///
/// **GOOD:**
/// ```dart
/// Wrap(children: [Text('a'), SizedBox(width: 8), Text('b')])
/// ```
class AvoidSpacerInWrapRule extends SaropaLintRule {
  const AvoidSpacerInWrapRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    name: 'avoid_spacer_in_wrap',
    problemMessage:
        '[avoid_spacer_in_wrap] Spacer/Expanded inside Wrap causes a '
        'flex paradox crash. Wrap does not support flex-based sizing.',
    correctionMessage: 'Use SizedBox or Padding for spacing inside Wrap.',
    errorSeverity: DiagnosticSeverity.ERROR,
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
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addInstanceCreationExpression((
      InstanceCreationExpression node,
    ) {
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
  const AvoidScrollableInIntrinsicRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    name: 'avoid_scrollable_in_intrinsic',
    problemMessage: '[avoid_scrollable_in_intrinsic] Scrollable widget inside '
        'IntrinsicHeight/IntrinsicWidth causes a geometry loop crash. '
        'Scrollables have no natural size.',
    correctionMessage: 'Use SizedBox with explicit dimensions instead of '
        'IntrinsicHeight/IntrinsicWidth around scrollable widgets.',
    errorSeverity: DiagnosticSeverity.ERROR,
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
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addInstanceCreationExpression((
      InstanceCreationExpression node,
    ) {
      final String typeName = node.constructorName.type.name.lexeme;
      if (!_scrollableTypes.contains(typeName)) return;

      final result = _findWidgetAncestor(
        node,
        targetParents: _intrinsicTypes,
      );

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
class RequireBaselineTextBaselineRule extends SaropaLintRule {
  const RequireBaselineTextBaselineRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    name: 'require_baseline_text_baseline',
    problemMessage:
        '[require_baseline_text_baseline] CrossAxisAlignment.baseline '
        'requires a textBaseline property. Omitting it causes an '
        'assertion failure at runtime.',
    correctionMessage:
        'Add textBaseline: TextBaseline.alphabetic (or .ideographic).',
    errorSeverity: DiagnosticSeverity.ERROR,
  );

  static const Set<String> _targetWidgets = <String>{'Row', 'Column', 'Flex'};

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addInstanceCreationExpression((
      InstanceCreationExpression node,
    ) {
      final String typeName = node.constructorName.type.name.lexeme;
      if (!_targetWidgets.contains(typeName)) return;

      bool hasBaseline = false;
      bool hasTextBaseline = false;

      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression) {
          final String name = arg.name.label.name;
          if (name == 'crossAxisAlignment') {
            final String value = arg.expression.toSource();
            if (value.contains('baseline')) hasBaseline = true;
          }
          if (name == 'textBaseline') hasTextBaseline = true;
        }
      }

      if (hasBaseline && !hasTextBaseline) {
        reporter.atNode(node.constructorName, code);
      }
    });
  }

  @override
  List<Fix> getFixes() => <Fix>[_RequireBaselineTextBaselineFix()];
}

class _RequireBaselineTextBaselineFix extends DartFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    context.registry.addInstanceCreationExpression((
      InstanceCreationExpression node,
    ) {
      if (!analysisError.sourceRange.intersects(node.sourceRange)) return;

      final changeBuilder = reporter.createChangeBuilder(
        message: 'Add textBaseline: TextBaseline.alphabetic',
        priority: 80,
      );

      changeBuilder.addDartFileEdit((builder) {
        // Insert textBaseline parameter after crossAxisAlignment
        for (final Expression arg in node.argumentList.arguments) {
          if (arg is NamedExpression &&
              arg.name.label.name == 'crossAxisAlignment') {
            builder.addSimpleInsertion(
              arg.end,
              ', textBaseline: TextBaseline.alphabetic',
            );
            return;
          }
        }
      });
    });
  }
}

// =========================================================================
// Rule: avoid_unconstrained_dialog_column
// =========================================================================

/// Warns when a `Column` inside an `AlertDialog` or `SimpleDialog` is
/// missing `mainAxisSize: MainAxisSize.min`.
///
/// `Column` defaults to `MainAxisSize.max`, which tries to fill all
/// available vertical space. Inside a dialog, this pushes buttons
/// off-screen and causes overflow.
///
/// **BAD:**
/// ```dart
/// AlertDialog(
///   content: Column(children: [...]), // Overflows!
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// AlertDialog(
///   content: Column(
///     mainAxisSize: MainAxisSize.min,
///     children: [...],
///   ),
/// )
/// ```
class AvoidUnconstrainedDialogColumnRule extends SaropaLintRule {
  const AvoidUnconstrainedDialogColumnRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    name: 'avoid_unconstrained_dialog_column',
    problemMessage:
        '[avoid_unconstrained_dialog_column] Column inside a dialog '
        'without mainAxisSize: MainAxisSize.min can overflow and push '
        'buttons off-screen.',
    correctionMessage: 'Add mainAxisSize: MainAxisSize.min to the Column.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  static const Set<String> _dialogTypes = <String>{
    'AlertDialog',
    'SimpleDialog',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addInstanceCreationExpression((
      InstanceCreationExpression node,
    ) {
      final String typeName = node.constructorName.type.name.lexeme;
      if (typeName != 'Column') return;

      // Check if mainAxisSize: MainAxisSize.min is already set.
      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression && arg.name.label.name == 'mainAxisSize') {
          if (arg.expression.toSource().contains('min')) return;
        }
      }

      // Walk up to find dialog parent.
      final result = _findWidgetAncestor(
        node,
        targetParents: _dialogTypes,
      );

      if (result == _AncestorResult.found) {
        reporter.atNode(node.constructorName, code);
      }
    });
  }

  @override
  List<Fix> getFixes() => <Fix>[_AvoidUnconstrainedDialogColumnFix()];
}

class _AvoidUnconstrainedDialogColumnFix extends DartFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    context.registry.addInstanceCreationExpression((
      InstanceCreationExpression node,
    ) {
      if (!analysisError.sourceRange.intersects(node.sourceRange)) return;
      if (node.constructorName.type.name.lexeme != 'Column') return;

      final changeBuilder = reporter.createChangeBuilder(
        message: 'Add mainAxisSize: MainAxisSize.min',
        priority: 80,
      );

      changeBuilder.addDartFileEdit((builder) {
        // Insert as first named argument after opening parenthesis.
        final int insertOffset = node.argumentList.leftParenthesis.end;
        builder.addSimpleInsertion(
          insertOffset,
          'mainAxisSize: MainAxisSize.min, ',
        );
      });
    });
  }
}

// =========================================================================
// Shared constant: widgets that provide bounded constraints to children
// =========================================================================

/// Widgets that constrain their child's size, preventing unbounded layout.
/// Shared by [AvoidUnboundedListviewInColumnRule] and
/// [AvoidTextfieldInRowRule].
const Set<String> _constraintWrappers = <String>{
  'Expanded',
  'Flexible',
  'SizedBox',
  'ConstrainedBox',
  'LimitedBox',
};

// =========================================================================
// Rule: avoid_unbounded_listview_in_column
// =========================================================================

/// Warns when `ListView`, `GridView`, or `CustomScrollView` is placed
/// inside a `Column` without being wrapped in `Expanded` or `Flexible`.
///
/// `Column` provides unbounded height to its children. Scrollable widgets
/// try to fill infinite height, causing an unbounded constraints crash.
///
/// **BAD:**
/// ```dart
/// Column(children: [Text('header'), ListView(...)]) // Crash!
/// ```
///
/// **GOOD:**
/// ```dart
/// Column(children: [Text('header'), Expanded(child: ListView(...))])
/// ```
class AvoidUnboundedListviewInColumnRule extends SaropaLintRule {
  const AvoidUnboundedListviewInColumnRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    name: 'avoid_unbounded_listview_in_column',
    problemMessage:
        '[avoid_unbounded_listview_in_column] Scrollable widget inside '
        'a Column without Expanded/Flexible causes an unbounded '
        'constraints crash.',
    correctionMessage:
        'Wrap the scrollable widget in Expanded or Flexible, or use '
        'shrinkWrap: true (with performance cost).',
    errorSeverity: DiagnosticSeverity.ERROR,
  );

  static const Set<String> _scrollableTypes = <String>{
    'ListView',
    'GridView',
    'CustomScrollView',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addInstanceCreationExpression((
      InstanceCreationExpression node,
    ) {
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

  @override
  List<Fix> getFixes() => <Fix>[_WrapInExpandedFix('scrollable widget')];

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
class AvoidTextfieldInRowRule extends SaropaLintRule {
  const AvoidTextfieldInRowRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    name: 'avoid_textfield_in_row',
    problemMessage:
        '[avoid_textfield_in_row] TextField/TextFormField inside a Row '
        'without width constraints causes an unbounded width crash.',
    correctionMessage:
        'Wrap the TextField in Expanded, Flexible, or a fixed-width '
        'SizedBox.',
    errorSeverity: DiagnosticSeverity.ERROR,
  );

  static const Set<String> _textFieldTypes = <String>{
    'TextField',
    'TextFormField',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addInstanceCreationExpression((
      InstanceCreationExpression node,
    ) {
      final String typeName = node.constructorName.type.name.lexeme;
      if (!_textFieldTypes.contains(typeName)) return;

      // Walk up checking for Row, skipping constraint wrappers.
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
          if (parentType == 'Row') {
            if (!wrappedInConstraint) {
              reporter.atNode(node.constructorName, code);
            }
            return;
          }
          // Stop at Column/Flex -- different axis, not our concern.
          if (parentType == 'Column' || parentType == 'Flex') return;
        }

        current = current.parent;
        depth++;
      }
    });
  }

  @override
  List<Fix> getFixes() => <Fix>[_WrapInExpandedFix('TextField')];
}

// =========================================================================
// Rule: avoid_fixed_size_in_scaffold_body
// =========================================================================

/// Warns when a `Scaffold` body contains a `Column` with `TextField`
/// descendants but no `SingleChildScrollView` wrapper.
///
/// When the keyboard appears, the `Scaffold` viewport shrinks. If the
/// body is a `Column` with text input fields and no scroll capability,
/// the content overflows (yellow/black stripe error).
///
/// **BAD:**
/// ```dart
/// Scaffold(body: Column(children: [TextField(), TextField()]))
/// ```
///
/// **GOOD:**
/// ```dart
/// Scaffold(body: SingleChildScrollView(child: Column(children: [...])))
/// ```
class AvoidFixedSizeInScaffoldBodyRule extends SaropaLintRule {
  const AvoidFixedSizeInScaffoldBodyRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    name: 'avoid_fixed_size_in_scaffold_body',
    problemMessage:
        '[avoid_fixed_size_in_scaffold_body] Scaffold body has a Column '
        'with text input fields but no ScrollView. The keyboard will '
        'cause overflow.',
    correctionMessage:
        'Wrap the Column in SingleChildScrollView to handle keyboard '
        'resize.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  static const Set<String> _textInputTypes = <String>{
    'TextField',
    'TextFormField',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addInstanceCreationExpression((
      InstanceCreationExpression node,
    ) {
      final String typeName = node.constructorName.type.name.lexeme;
      if (typeName != 'Scaffold') return;

      // Find the 'body' argument.
      for (final Expression arg in node.argumentList.arguments) {
        if (arg is! NamedExpression) continue;
        if (arg.name.label.name != 'body') continue;

        final Expression bodyExpr = arg.expression;
        if (bodyExpr is! InstanceCreationExpression) return;

        final String bodyType = bodyExpr.constructorName.type.name.lexeme;

        // If body is already wrapped in a scroll view, it's fine.
        if (bodyType == 'SingleChildScrollView') return;
        if (bodyType == 'CustomScrollView') return;
        if (bodyType == 'ListView') return;

        // Check if body is a Column containing text input fields.
        if (bodyType == 'Column' && _containsTextInput(bodyExpr)) {
          reporter.atNode(bodyExpr.constructorName, code);
        }
      }
    });
  }

  bool _containsTextInput(InstanceCreationExpression node) {
    final visitor = _TextInputFinder();
    node.visitChildren(visitor);
    return visitor.found;
  }
}

class _TextInputFinder extends RecursiveAstVisitor<void> {
  bool found = false;

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    if (found) return;
    final String typeName = node.constructorName.type.name.lexeme;
    if (AvoidFixedSizeInScaffoldBodyRule._textInputTypes.contains(typeName)) {
      found = true;
      return;
    }
    super.visitInstanceCreationExpression(node);
  }
}

// =========================================================================
// Shared quick fix: Wrap in Expanded
// =========================================================================

/// Shared quick fix that wraps a widget in `Expanded(child: ...)`.
class _WrapInExpandedFix extends DartFix {
  _WrapInExpandedFix(this._widgetDescription);

  final String _widgetDescription;

  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    context.registry.addInstanceCreationExpression((
      InstanceCreationExpression node,
    ) {
      if (!analysisError.sourceRange.intersects(node.sourceRange)) return;

      final changeBuilder = reporter.createChangeBuilder(
        message: 'Wrap $_widgetDescription in Expanded',
        priority: 80,
      );

      changeBuilder.addDartFileEdit((builder) {
        builder.addSimpleInsertion(node.offset, 'Expanded(child: ');
        builder.addSimpleInsertion(node.end, ')');
      });
    });
  }
}
