// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart'
    show AnalysisError, DiagnosticSeverity;
import 'package:analyzer/source/source_range.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../saropa_lint_rule.dart';

/// Warns when `context` is used inside `initState` or `dispose` methods.
///
/// Using `context` in these lifecycle methods is an anti-pattern because
/// the widget may not be fully mounted (in `initState`) or may already be
/// unmounted (in `dispose`). This can lead to runtime errors or unexpected
/// behavior.
///
/// **Safe patterns (not reported):**
/// - `context` usage inside `addPostFrameCallback` callbacks (runs after mount)
/// - `context` usage inside `Future.microtask` or similar deferred callbacks
///
/// Example of **bad** code:
/// ```dart
/// @override
/// void initState() {
///   super.initState();
///   final theme = Theme.of(context); // BAD: widget may not be mounted
/// }
///
/// @override
/// void dispose() {
///   Navigator.of(context).pop(); // BAD: widget may be unmounted
///   super.dispose();
/// }
/// ```
///
/// Example of **good** code:
/// ```dart
/// @override
/// void initState() {
///   super.initState();
///   WidgetsBinding.instance.addPostFrameCallback((_) {
///     final theme = Theme.of(context); // OK: runs after mount
///   });
/// }
/// ```
class AvoidContextInInitStateDisposeRule extends SaropaLintRule {
  const AvoidContextInInitStateDisposeRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_context_in_initstate_dispose',
    problemMessage: "Avoid using 'context' in initState or dispose. "
        'The widget may not be mounted.',
    correctionMessage:
        'Use WidgetsBinding.instance.addPostFrameCallback to defer '
        'context access until after the widget is mounted.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodDeclaration((MethodDeclaration node) {
      final String methodName = node.name.lexeme;

      // Only check initState and dispose methods
      if (methodName != 'initState' && methodName != 'dispose') {
        return;
      }

      // Check if this is in a State class (has @override annotation typically)
      final FunctionBody body = node.body;
      if (body is EmptyFunctionBody) {
        return;
      }

      // Visit the method body to find context usages
      final _ContextUsageVisitor visitor = _ContextUsageVisitor(methodName);
      body.accept(visitor);

      // Report each unsafe context usage
      for (final SimpleIdentifier contextNode in visitor.unsafeContextUsages) {
        reporter.atNode(contextNode, code);
      }
    });
  }
}

/// Visitor that finds unsafe `context` usages in initState/dispose methods.
///
/// It tracks when we're inside safe callback regions (like addPostFrameCallback)
/// and only reports context usages that are outside these safe regions.
class _ContextUsageVisitor extends RecursiveAstVisitor<void> {
  _ContextUsageVisitor(this.methodName);

  final String methodName;
  final List<SimpleIdentifier> unsafeContextUsages = <SimpleIdentifier>[];

  /// Depth of safe callback nesting (addPostFrameCallback, Future.microtask, etc.)
  int _safeCallbackDepth = 0;

  /// Names of methods/functions that make context usage safe
  /// (they defer execution until after the widget is mounted)
  static const Set<String> _safeCallbackMethods = <String>{
    'addPostFrameCallback',
    'scheduleFrameCallback',
    'microtask', // Future.microtask
    'scheduleMicrotask',
    'Future', // Future(() => ...) or Future.delayed
    'Timer', // Timer or Timer.run
    'run', // Timer.run
    'delayed', // Future.delayed
  };

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    // Check if this is a 'context' identifier
    if (node.name == 'context' && _safeCallbackDepth == 0) {
      // Make sure it's actually accessing BuildContext, not a parameter named context
      // in a callback. We check by seeing if it's the left side of a property access
      // or used as an argument.
      if (!_isContextParameter(node)) {
        unsafeContextUsages.add(node);
      }
    }
    super.visitSimpleIdentifier(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final String methodName = node.methodName.name;

    // Check if this is a safe callback method
    final bool isSafeCallback = _safeCallbackMethods.contains(methodName);

    if (isSafeCallback) {
      // Visit the target (e.g., WidgetsBinding.instance) outside safe context
      node.target?.accept(this);
      node.typeArguments?.accept(this);

      // Visit arguments inside safe context
      _safeCallbackDepth++;
      node.argumentList.accept(this);
      _safeCallbackDepth--;
    } else {
      super.visitMethodInvocation(node);
    }
  }

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    final String constructorName = node.constructorName.type.name.lexeme;

    // Check for Future(...) or Timer(...) constructors
    if (constructorName == 'Future' || constructorName == 'Timer') {
      // Visit type arguments outside safe context
      node.constructorName.accept(this);

      // Visit arguments inside safe context
      _safeCallbackDepth++;
      node.argumentList.accept(this);
      _safeCallbackDepth--;
    } else {
      super.visitInstanceCreationExpression(node);
    }
  }

  /// Check if this 'context' identifier is a parameter declaration
  /// (like in a callback: `(context) => ...`)
  bool _isContextParameter(SimpleIdentifier node) {
    final AstNode? parent = node.parent;

    // Check if it's a simple formal parameter
    if (parent is SimpleFormalParameter) {
      return true;
    }

    // Check if it's a declared identifier in a function expression
    if (parent is DeclaredIdentifier) {
      return true;
    }

    return false;
  }
}

/// Warns when an empty setState callback is used.
///
/// Example of **bad** code:
/// ```dart
/// setState(() {});
/// ```
///
/// Example of **good** code:
/// ```dart
/// setState(() {
///   _value = newValue;
/// });
/// ```
class AvoidEmptySetStateRule extends SaropaLintRule {
  const AvoidEmptySetStateRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_empty_setstate',
    problemMessage: 'Empty setState callback has no effect.',
    correctionMessage: 'Add state changes or remove the setState call.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name != 'setState') return;

      final NodeList<Expression> args = node.argumentList.arguments;
      if (args.isEmpty) return;

      final Expression callback = args.first;
      if (callback is FunctionExpression) {
        final FunctionBody body = callback.body;
        if (body is BlockFunctionBody && body.block.statements.isEmpty) {
          reporter.atNode(node, code);
        }
      }
    });
  }
}

/// Warns when Expanded with empty child is used instead of Spacer.
///
/// `Spacer()` is clearer and more semantic than `Expanded(child: SizedBox())`.
///
/// Example of **bad** code:
/// ```dart
/// Row(
///   children: [
///     Text('Start'),
///     Expanded(child: SizedBox()),  // Use Spacer instead
///     Text('End'),
///   ],
/// )
/// ```
///
/// Example of **good** code:
/// ```dart
/// Row(
///   children: [
///     Text('Start'),
///     Spacer(),
///     Text('End'),
///   ],
/// )
/// ```
class AvoidExpandedAsSpacerRule extends SaropaLintRule {
  const AvoidExpandedAsSpacerRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_expanded_as_spacer',
    problemMessage: 'Use Spacer() instead of Expanded with empty child.',
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

  static const LintCode _code = LintCode(
    name: 'avoid_flexible_outside_flex',
    problemMessage: 'Flexible/Expanded used outside of Row, Column, or Flex.',
    correctionMessage:
        'Flexible and Expanded only work inside Row, Column, or Flex widgets.',
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
class AvoidIncorrectImageOpacityRule extends SaropaLintRule {
  const AvoidIncorrectImageOpacityRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_incorrect_image_opacity',
    problemMessage:
        'Image wrapped in Opacity. Use Image color property instead.',
    correctionMessage:
        'Use Image.color with colorBlendMode for better performance.',
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
      if (typeName != 'Opacity') return;

      // Find the child argument
      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression && arg.name.label.name == 'child') {
          final Expression childExpr = arg.expression;
          if (_isImageWidget(childExpr)) {
            reporter.atNode(node, code);
            return;
          }
        }
      }
    });
  }

  bool _isImageWidget(Expression expr) {
    if (expr is InstanceCreationExpression) {
      final String typeName = expr.constructorName.type.name.lexeme;
      return typeName == 'Image';
    }
    if (expr is MethodInvocation) {
      final Expression? target = expr.target;
      if (target is SimpleIdentifier && target.name == 'Image') {
        return true;
      }
    }
    return false;
  }
}

/// Warns when BuildContext is used in a late field initializer.
///
/// Late field initializers run at first access, not during construction,
/// so the context may be invalid or from a different widget lifecycle.
///
/// ### Example
///
/// #### BAD:
/// ```dart
/// class _MyWidgetState extends State<MyWidget> {
///   late final theme = Theme.of(context);
///   late final media = MediaQuery.of(context);
/// }
/// ```
///
/// #### GOOD:
/// ```dart
/// class _MyWidgetState extends State<MyWidget> {
///   ThemeData? _theme;
///
///   @override
///   void didChangeDependencies() {
///     super.didChangeDependencies();
///     _theme = Theme.of(context);
///   }
/// }
/// ```
class AvoidLateContextRule extends SaropaLintRule {
  const AvoidLateContextRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_late_context',
    problemMessage: 'Avoid using BuildContext in late field initializers.',
    correctionMessage:
        'Initialize in didChangeDependencies() or build() instead.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addFieldDeclaration((FieldDeclaration node) {
      // Only check late fields
      if (!node.fields.isLate) return;

      // Check if we're in a State class
      final AstNode? parent = node.parent;
      if (parent is! ClassDeclaration) return;

      final ExtendsClause? extendsClause = parent.extendsClause;
      if (extendsClause == null) return;

      final String superclass = extendsClause.superclass.name.lexeme;
      if (superclass != 'State') return;

      // Check each variable's initializer
      for (final VariableDeclaration variable in node.fields.variables) {
        final Expression? initializer = variable.initializer;
        if (initializer != null && _usesContext(initializer)) {
          reporter.atNode(variable, code);
        }
      }
    });
  }

  bool _usesContext(Expression expr) {
    // Check for direct 'context' usage
    if (expr is SimpleIdentifier && expr.name == 'context') {
      return true;
    }

    // Check for method calls like Theme.of(context)
    if (expr is MethodInvocation) {
      // Check arguments
      for (final Expression arg in expr.argumentList.arguments) {
        if (_usesContext(arg)) return true;
      }
      // Check target
      final Expression? target = expr.target;
      if (target != null && _usesContext(target)) return true;
    }

    // Check property access
    if (expr is PrefixedIdentifier) {
      if (_usesContext(expr.prefix)) return true;
    }

    if (expr is PropertyAccess) {
      final Expression? target = expr.target;
      if (target != null && _usesContext(target)) return true;
    }

    return false;
  }
}

/// Warns when a widget has a "padding" parameter that is used as margin.
///
/// This occurs when a widget accepts a `padding` parameter but uses it
/// to wrap the return value with a `Padding` widget or `.withPadding()` extension,
/// which is semantically margin behavior.
///
/// Example of **bad** code:
/// ```dart
/// class MyWidget extends StatelessWidget {
///   final EdgeInsets? padding;
///
///   @override
///   Widget build(BuildContext context) {
///     return Padding(
///       padding: padding ?? EdgeInsets.zero,
///       child: Container(),
///     );  // Using "padding" parameter as margin!
///   }
/// }
/// ```
///
/// Example of **good** code:
/// ```dart
/// class MyWidget extends StatelessWidget {
///   final EdgeInsets? margin;  // Renamed to "margin"
///
///   @override
///   Widget build(BuildContext context) {
///     return Padding(
///       padding: margin ?? EdgeInsets.zero,
///       child: Container(),
///     );
///   }
/// }
/// ```
class AvoidMisnamedPaddingRule extends SaropaLintRule {
  const AvoidMisnamedPaddingRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_misnamed_padding',
    problemMessage: 'Parameter named "padding" is used as margin '
        '(via Padding widget or .withPadding()).',
    correctionMessage: 'Consider renaming to "margin" to reflect actual usage.',
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
class AvoidMissingImageAltRule extends SaropaLintRule {
  const AvoidMissingImageAltRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_missing_image_alt',
    problemMessage: 'Image is missing semanticLabel for accessibility.',
    correctionMessage: 'Add semanticLabel parameter for screen reader support.',
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
      if (typeName != 'Image') return;

      _checkForSemanticLabel(node, reporter);
    });

    context.registry.addMethodInvocation((MethodInvocation node) {
      final Expression? target = node.target;
      if (target is! SimpleIdentifier) return;
      if (target.name != 'Image') return;

      // Check for Image.asset, Image.network, etc.
      final String methodName = node.methodName.name;
      if (<String>['asset', 'network', 'file', 'memory'].contains(methodName)) {
        _checkForSemanticLabelInMethod(node, reporter);
      }
    });
  }

  void _checkForSemanticLabel(
      InstanceCreationExpression node, SaropaDiagnosticReporter reporter) {
    final bool hasSemanticLabel = node.argumentList.arguments.any(
      (Expression arg) =>
          arg is NamedExpression && arg.name.label.name == 'semanticLabel',
    );

    if (!hasSemanticLabel) {
      reporter.atNode(node, code);
    }
  }

  void _checkForSemanticLabelInMethod(
      MethodInvocation node, SaropaDiagnosticReporter reporter) {
    final bool hasSemanticLabel = node.argumentList.arguments.any(
      (Expression arg) =>
          arg is NamedExpression && arg.name.label.name == 'semanticLabel',
    );

    if (!hasSemanticLabel) {
      reporter.atNode(node, code);
    }
  }
}

/// Warns when `mounted` is referenced inside setState callback.
///
/// Checking `mounted` inside setState is an anti-pattern because
/// setState should not be called if not mounted.
///
/// Example of **bad** code:
/// ```dart
/// setState(() {
///   if (mounted) {  // Wrong place to check
///     _value = newValue;
///   }
/// });
/// ```
///
/// Example of **good** code:
/// ```dart
/// if (!mounted) return;
/// setState(() {
///   _value = newValue;
/// });
/// ```
class AvoidMountedInSetStateRule extends SaropaLintRule {
  const AvoidMountedInSetStateRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_mounted_in_setstate',
    problemMessage: 'Avoid checking mounted inside setState callback.',
    correctionMessage: 'Check mounted before calling setState instead.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name != 'setState') return;

      final ArgumentList args = node.argumentList;
      if (args.arguments.isEmpty) return;

      final Expression firstArg = args.arguments.first;

      // Check if the callback contains 'mounted' reference
      final _MountedVisitor visitor = _MountedVisitor();
      firstArg.accept(visitor);

      for (final SimpleIdentifier mountedRef in visitor.mountedReferences) {
        reporter.atNode(mountedRef, code);
      }
    });
  }
}

class _MountedVisitor extends RecursiveAstVisitor<void> {
  final List<SimpleIdentifier> mountedReferences = <SimpleIdentifier>[];

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    if (node.name == 'mounted') {
      mountedReferences.add(node);
    }
    super.visitSimpleIdentifier(node);
  }
}

/// Warns when a method returns a Widget.
///
/// Methods that return widgets can cause unnecessary rebuilds. Consider
/// extracting to a separate widget class.
class AvoidReturningWidgetsRule extends SaropaLintRule {
  const AvoidReturningWidgetsRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_returning_widgets',
    problemMessage: 'Avoid methods that return widgets.',
    correctionMessage: 'Extract to a separate Widget class.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodDeclaration((MethodDeclaration node) {
      // Skip build method
      if (node.name.lexeme == 'build') return;

      // Check return type
      final TypeAnnotation? returnType = node.returnType;
      if (returnType is NamedType) {
        final String typeName = returnType.name.lexeme;
        if (typeName == 'Widget' || typeName.endsWith('Widget')) {
          reporter.atToken(node.name, code);
        }
      }
    });
  }
}

/// Warns when shrinkWrap is used in nested scrollable lists.
///
/// Using shrinkWrap: true in nested scrollables can cause performance issues
/// as it forces the list to calculate the size of all children.
class AvoidShrinkWrapInListsRule extends SaropaLintRule {
  const AvoidShrinkWrapInListsRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_shrink_wrap_in_lists',
    problemMessage: "Avoid 'shrinkWrap: true' in nested scrollables.",
    correctionMessage: 'Use a fixed height or Expanded instead.',
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

  static const LintCode _code = LintCode(
    name: 'avoid_single_child_column_row',
    problemMessage: 'Column/Row with single child is unnecessary.',
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
            // Only flag if there's exactly one non-spread element
            // Spread operators can expand to multiple children at runtime
            int nonSpreadCount = 0;
            bool hasSpread = false;

            for (final CollectionElement element in value.elements) {
              if (element is SpreadElement) {
                hasSpread = true;
              } else {
                nonSpreadCount++;
              }
            }

            // Only report if: single non-spread element AND no spreads
            if (nonSpreadCount == 1 && !hasSpread) {
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
class AvoidStateConstructorsRule extends SaropaLintRule {
  const AvoidStateConstructorsRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_state_constructors',
    problemMessage: 'State class should not have constructor body.',
    correctionMessage: 'Use initState() for initialization instead.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
      // Check if extends State
      final ExtendsClause? extendsClause = node.extendsClause;
      if (extendsClause == null) return;

      final String superclassName = extendsClause.superclass.name.lexeme;
      if (superclassName != 'State') return;

      // Check constructors for bodies
      for (final ClassMember member in node.members) {
        if (member is ConstructorDeclaration) {
          final FunctionBody body = member.body;
          if (body is BlockFunctionBody && body.block.statements.isNotEmpty) {
            reporter.atNode(member, code);
          }
        }
      }
    });
  }
}

/// Warns when a StatelessWidget has initialized fields.
///
/// Example of **bad** code:
/// ```dart
/// class MyWidget extends StatelessWidget {
///   final List<int> items = [];  // Initialized in StatelessWidget
/// }
/// ```
///
/// Example of **good** code:
/// ```dart
/// class MyWidget extends StatelessWidget {
///   final List<int> items;
///   const MyWidget({required this.items});
/// }
/// ```
class AvoidStatelessWidgetInitializedFieldsRule extends SaropaLintRule {
  const AvoidStatelessWidgetInitializedFieldsRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_stateless_widget_initialized_fields',
    problemMessage: 'StatelessWidget should not have initialized fields.',
    correctionMessage: 'Pass values through the constructor instead.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
      // Check if extends StatelessWidget
      final ExtendsClause? extendsClause = node.extendsClause;
      if (extendsClause == null) return;

      final String superclassName = extendsClause.superclass.name.lexeme;
      if (superclassName != 'StatelessWidget') return;

      // Check for initialized fields
      for (final ClassMember member in node.members) {
        if (member is FieldDeclaration) {
          for (final VariableDeclaration variable in member.fields.variables) {
            if (variable.initializer != null) {
              // Skip static fields
              if (member.isStatic) continue;
              reporter.atNode(variable, code);
            }
          }
        }
      }
    });
  }
}

/// Warns when GestureDetector has no gesture callbacks defined.
///
/// ### Example
///
/// #### BAD:
/// ```dart
/// GestureDetector(
///   child: Text('Hello'),
/// )
/// ```
///
/// #### GOOD:
/// ```dart
/// GestureDetector(
///   onTap: () => print('tapped'),
///   child: Text('Hello'),
/// )
/// ```
class AvoidUnnecessaryGestureDetectorRule extends SaropaLintRule {
  const AvoidUnnecessaryGestureDetectorRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_unnecessary_gesture_detector',
    problemMessage: 'GestureDetector has no gesture callbacks defined.',
    correctionMessage:
        'Add gesture callbacks or remove the GestureDetector wrapper.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  static const Set<String> _gestureCallbacks = <String>{
    'onTap',
    'onTapDown',
    'onTapUp',
    'onTapCancel',
    'onSecondaryTap',
    'onSecondaryTapDown',
    'onSecondaryTapUp',
    'onSecondaryTapCancel',
    'onTertiaryTapDown',
    'onTertiaryTapUp',
    'onTertiaryTapCancel',
    'onDoubleTap',
    'onDoubleTapDown',
    'onDoubleTapCancel',
    'onLongPress',
    'onLongPressStart',
    'onLongPressMoveUpdate',
    'onLongPressUp',
    'onLongPressEnd',
    'onSecondaryLongPress',
    'onSecondaryLongPressStart',
    'onSecondaryLongPressMoveUpdate',
    'onSecondaryLongPressUp',
    'onSecondaryLongPressEnd',
    'onTertiaryLongPress',
    'onTertiaryLongPressStart',
    'onTertiaryLongPressMoveUpdate',
    'onTertiaryLongPressUp',
    'onTertiaryLongPressEnd',
    'onVerticalDragDown',
    'onVerticalDragStart',
    'onVerticalDragUpdate',
    'onVerticalDragEnd',
    'onVerticalDragCancel',
    'onHorizontalDragDown',
    'onHorizontalDragStart',
    'onHorizontalDragUpdate',
    'onHorizontalDragEnd',
    'onHorizontalDragCancel',
    'onForcePressStart',
    'onForcePressPeak',
    'onForcePressUpdate',
    'onForcePressEnd',
    'onPanDown',
    'onPanStart',
    'onPanUpdate',
    'onPanEnd',
    'onPanCancel',
    'onScaleStart',
    'onScaleUpdate',
    'onScaleEnd',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry
        .addInstanceCreationExpression((InstanceCreationExpression node) {
      final String constructorName = node.constructorName.type.name.lexeme;
      if (constructorName != 'GestureDetector') return;

      // Check if any gesture callback is defined
      bool hasGestureCallback = false;
      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression) {
          final String paramName = arg.name.label.name;
          if (_gestureCallbacks.contains(paramName)) {
            // Check if it's not null
            final Expression value = arg.expression;
            if (value is! NullLiteral) {
              hasGestureCallback = true;
              break;
            }
          }
        }
      }

      if (!hasGestureCallback) {
        reporter.atNode(node.constructorName, code);
      }
    });
  }
}

/// Warns when setState is called in initState, dispose, or build.
///
/// Calling setState during widget lifecycle methods can cause issues.
///
/// Example of **bad** code:
/// ```dart
/// @override
/// void initState() {
///   super.initState();
///   setState(() {});  // Wrong - causes issues
/// }
/// ```
///
/// Example of **good** code:
/// ```dart
/// @override
/// void initState() {
///   super.initState();
///   // Update state directly in initState, no setState needed
/// }
/// ```
class AvoidUnnecessarySetStateRule extends SaropaLintRule {
  const AvoidUnnecessarySetStateRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_unnecessary_setstate',
    problemMessage: 'setState called in lifecycle method where not needed.',
    correctionMessage:
        'In initState/dispose, modify state directly without setState.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  static const Set<String> _lifecycleMethods = <String>{
    'initState',
    'dispose',
    'didChangeDependencies',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodDeclaration((MethodDeclaration node) {
      final String methodName = node.name.lexeme;
      if (!_lifecycleMethods.contains(methodName)) return;

      // Check if in a State class
      final AstNode? parent = node.parent;
      if (parent is! ClassDeclaration) return;

      final ExtendsClause? extendsClause = parent.extendsClause;
      if (extendsClause == null) return;
      if (extendsClause.superclass.element?.name != 'State') return;

      // Find setState calls in this method
      node.body.visitChildren(
        _SetStateCallFinder((MethodInvocation setStateCall) {
          reporter.atNode(setStateCall, code);
        }),
      );
    });
  }
}

class _SetStateCallFinder extends RecursiveAstVisitor<void> {
  _SetStateCallFinder(this.onFound);
  final void Function(MethodInvocation) onFound;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.methodName.name == 'setState') {
      onFound(node);
    }
    super.visitMethodInvocation(node);
  }
}

/// Warns when a StatefulWidget could be a StatelessWidget.
///
/// If a State class never calls setState and has no mutable state,
/// it should probably be a StatelessWidget.
///
/// Example of **bad** code:
/// ```dart
/// class MyWidget extends StatefulWidget {
///   @override
///   State<MyWidget> createState() => _MyWidgetState();
/// }
/// class _MyWidgetState extends State<MyWidget> {
///   @override
///   Widget build(BuildContext context) => Text('Hello');
/// }
/// ```
///
/// Example of **good** code:
/// ```dart
/// class MyWidget extends StatelessWidget {
///   @override
///   Widget build(BuildContext context) => Text('Hello');
/// }
/// ```
class AvoidUnnecessaryStatefulWidgetsRule extends SaropaLintRule {
  const AvoidUnnecessaryStatefulWidgetsRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_unnecessary_stateful_widgets',
    problemMessage: 'StatefulWidget may be unnecessary.',
    correctionMessage:
        'Consider using StatelessWidget if no mutable state is needed.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
      // Check if this is a State class
      final ExtendsClause? extendsClause = node.extendsClause;
      if (extendsClause == null) return;
      if (extendsClause.superclass.element?.name != 'State') return;

      // Check for setState calls
      bool hasSetState = false;
      bool hasMutableFields = false;

      for (final ClassMember member in node.members) {
        // Check for non-final instance fields
        if (member is FieldDeclaration && !member.isStatic) {
          if (!member.fields.isFinal && !member.fields.isConst) {
            hasMutableFields = true;
          }
        }

        // Check for setState in any method
        if (member is MethodDeclaration) {
          member.body.visitChildren(
            _SetStatePresenceChecker((bool found) {
              if (found) hasSetState = true;
            }),
          );
        }
      }

      // If no setState and no mutable fields, probably unnecessary
      if (!hasSetState && !hasMutableFields) {
        reporter.atNode(node, code);
      }
    });
  }
}

class _SetStatePresenceChecker extends RecursiveAstVisitor<void> {
  _SetStatePresenceChecker(this.onResult);
  final void Function(bool) onResult;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.methodName.name == 'setState') {
      onResult(true);
    }
    super.visitMethodInvocation(node);
  }
}

/// Warns when anonymous functions are used in listener methods.
class AvoidUnremovableCallbacksInListenersRule extends SaropaLintRule {
  const AvoidUnremovableCallbacksInListenersRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_unremovable_callbacks_in_listeners',
    problemMessage: 'Anonymous function cannot be removed from listener.',
    correctionMessage:
        'Use a named function or store reference to remove later.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  static const List<String> _listenerMethods = <String>[
    'addListener',
    'addPostFrameCallback',
    'addPersistentFrameCallback',
    'addTimingsCallback',
  ];

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      if (!_listenerMethods.contains(node.methodName.name)) return;

      final ArgumentList args = node.argumentList;
      if (args.arguments.isEmpty) return;

      final Expression firstArg = args.arguments.first;
      if (firstArg is FunctionExpression) {
        reporter.atNode(firstArg, code);
      }
    });
  }
}

/// Warns when `setState()` is called without a `mounted` check.
///
/// Calling `setState()` after a widget has been unmounted (e.g., after an
/// async operation completes) can cause errors. Always check `mounted` before
/// calling `setState()` in async contexts.
///
/// **Safe patterns (not reported):**
/// - `mounted ? setState(() { ... }) : null`
/// - `if (mounted) { setState(() { ... }); }`
/// - `if (!mounted) return; setState(...)`
/// - Inside a `_setStateSafe` wrapper method
///
/// Example of **bad** code:
/// ```dart
/// Future<void> loadData() async {
///   final data = await fetchData();
///   setState(() {  // BAD: widget may be unmounted
///     _data = data;
///   });
/// }
/// ```
///
/// Example of **good** code:
/// ```dart
/// Future<void> loadData() async {
///   final data = await fetchData();
///   if (mounted) {
///     setState(() {
///       _data = data;
///     });
///   }
/// }
/// ```
class AvoidUnsafeSetStateRule extends SaropaLintRule {
  const AvoidUnsafeSetStateRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_unsafe_setstate',
    problemMessage: 'setState() called without a mounted check.',
    correctionMessage:
        'Wrap in `if (mounted)` or use `mounted ? setState(...) : null`.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name != 'setState') {
        return;
      }

      // Check if this setState is safe
      if (_isSafeSetState(node)) {
        return;
      }

      reporter.atNode(node, code);
    });
  }

  /// Check if this setState call is properly guarded
  bool _isSafeSetState(MethodInvocation node) {
    AstNode? current = node.parent;

    while (current != null) {
      // Check for ternary: mounted ? setState(...) : ...
      if (current is ConditionalExpression) {
        if (_isMountedCheck(current.condition)) {
          return true;
        }
      }

      // Check for if statement: if (mounted) { setState(...) }
      if (current is IfStatement) {
        if (_isMountedCheck(current.expression)) {
          return true;
        }
      }

      // Check for block with early return: if (!mounted) return;
      if (current is Block) {
        if (_hasEarlyMountedReturn(current, node)) {
          return true;
        }
      }

      // Check if we're inside a _setStateSafe method definition
      if (current is MethodDeclaration) {
        final String methodName = current.name.lexeme;
        if (methodName == '_setStateSafe' || methodName == 'setStateSafe') {
          return true;
        }
      }

      // Check if we're inside a call to _setStateSafe
      if (current is MethodInvocation) {
        final String methodName = current.methodName.name;
        if (methodName == '_setStateSafe' || methodName == 'setStateSafe') {
          return true;
        }
      }

      current = current.parent;
    }

    return false;
  }

  /// Check if an expression is a mounted check
  bool _isMountedCheck(Expression condition) {
    final String source = condition.toSource();

    // Direct mounted check
    if (source == 'mounted') {
      return true;
    }

    // mounted == true or mounted != false
    if (source.contains('mounted')) {
      return true;
    }

    return false;
  }

  /// Check if a block has an early return guarded by !mounted before this node
  bool _hasEarlyMountedReturn(Block block, AstNode targetNode) {
    for (final Statement statement in block.statements) {
      // If we've reached the target node, stop looking
      if (_containsNode(statement, targetNode)) {
        break;
      }

      // Look for: if (!mounted) return;
      if (statement is IfStatement) {
        final String condition = statement.expression.toSource();
        if (condition == '!mounted' || condition == 'mounted == false') {
          final Statement thenStatement = statement.thenStatement;
          if (thenStatement is Block) {
            if (thenStatement.statements.isNotEmpty &&
                thenStatement.statements.first is ReturnStatement) {
              return true;
            }
          } else if (thenStatement is ReturnStatement) {
            return true;
          }
        }
      }
    }
    return false;
  }

  /// Check if a node contains another node
  bool _containsNode(AstNode container, AstNode target) {
    if (container == target) {
      return true;
    }

    bool found = false;
    container.visitChildren(
      _NodeFinder(target, (bool result) {
        found = result;
      }),
    );

    return found;
  }
}

/// Helper visitor to find if a node exists within another node
class _NodeFinder extends GeneralizingAstVisitor<void> {
  _NodeFinder(this.target, this.onFound);

  final AstNode target;
  final void Function(bool) onFound;

  @override
  void visitNode(AstNode node) {
    if (node == target) {
      onFound(true);
      return;
    }
    super.visitNode(node);
  }
}

/// Warns when a widget that has its own padding property is wrapped in Padding.
///
/// Example of **bad** code:
/// ```dart
/// Padding(
///   padding: EdgeInsets.all(8),
///   child: Container(...),  // Container has padding property
/// )
/// ```
///
/// Example of **good** code:
/// ```dart
/// Container(
///   padding: EdgeInsets.all(8),
///   ...
/// )
/// ```
class AvoidWrappingInPaddingRule extends SaropaLintRule {
  const AvoidWrappingInPaddingRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_wrapping_in_padding',
    problemMessage:
        'Widget has its own padding property, avoid wrapping in Padding.',
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
        'RenderObject setter should check equality before updating.',
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

  static const LintCode _code = LintCode(
    name: 'consistent_update_render_object',
    problemMessage:
        'updateRenderObject may be missing property updates from createRenderObject.',
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

  static const LintCode _code = LintCode(
    name: 'prefer_const_border_radius',
    problemMessage: 'Prefer const BorderRadius.all for constant border radius.',
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
    problemMessage: 'Consider using a more specific EdgeInsets constructor.',
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
class PreferDefineHeroTagRule extends SaropaLintRule {
  const PreferDefineHeroTagRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'prefer_define_hero_tag',
    problemMessage: 'Hero widget should have an explicit tag.',
    correctionMessage: 'Add a tag parameter to the Hero widget.',
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
      if (typeName != 'Hero') return;

      // Check if tag is defined
      final bool hasTag = node.argumentList.arguments.any(
        (Expression arg) =>
            arg is NamedExpression && arg.name.label.name == 'tag',
      );

      if (!hasTag) {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when inline callbacks could be extracted to methods.
///
/// Long inline callbacks can make code harder to read. Consider extracting
/// them to named methods for better readability and testability.
class PreferExtractingCallbacksRule extends SaropaLintRule {
  const PreferExtractingCallbacksRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'prefer_extracting_callbacks',
    problemMessage: 'Consider extracting this callback to a method.',
    correctionMessage: 'Extract long callbacks to named methods.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addFunctionExpression((FunctionExpression node) {
      // Only check callbacks passed as arguments
      final AstNode? parent = node.parent;
      if (parent is! NamedExpression && parent is! ArgumentList) return;

      // Check callback length
      final FunctionBody body = node.body;
      if (body is BlockFunctionBody) {
        final int lineCount = body.block.statements.length;
        if (lineCount > 5) {
          reporter.atNode(node, code);
        }
      }
    });
  }
}

/// Warns when a file contains multiple public widget classes.
///
/// Each public widget should generally be in its own file for better
/// organization and maintainability.
class PreferSingleWidgetPerFileRule extends SaropaLintRule {
  const PreferSingleWidgetPerFileRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'prefer_single_widget_per_file',
    problemMessage: 'File contains multiple public widget classes.',
    correctionMessage: 'Move each public widget to its own file.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addCompilationUnit((CompilationUnit node) {
      final List<ClassDeclaration> publicWidgets = <ClassDeclaration>[];

      for (final CompilationUnitMember member in node.declarations) {
        if (member is ClassDeclaration) {
          // Check if public (not starting with _)
          if (member.name.lexeme.startsWith('_')) continue;

          // Check if extends Widget
          final ExtendsClause? extendsClause = member.extendsClause;
          if (extendsClause != null) {
            final String superclass = extendsClause.superclass.name.lexeme;
            if (superclass.endsWith('Widget') ||
                superclass == 'StatelessWidget' ||
                superclass == 'StatefulWidget') {
              publicWidgets.add(member);
            }
          }
        }
      }

      // Report if more than one public widget
      if (publicWidgets.length > 1) {
        for (int i = 1; i < publicWidgets.length; i++) {
          reporter.atNode(publicWidgets[i], code);
        }
      }
    });
  }
}

/// Warns when a Sliver widget class doesn't have 'Sliver' prefix.
///
/// Sliver widgets should be named with 'Sliver' prefix for clarity.
///
/// Example of **bad** code:
/// ```dart
/// class MyList extends SliverChildDelegate {}
/// class CustomGrid extends SliverGridDelegate {}
/// ```
///
/// Example of **good** code:
/// ```dart
/// class SliverMyList extends SliverChildDelegate {}
/// class SliverCustomGrid extends SliverGridDelegate {}
/// ```
class PreferSliverPrefixRule extends SaropaLintRule {
  const PreferSliverPrefixRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'prefer_sliver_prefix',
    problemMessage: 'Sliver widget class should have "Sliver" prefix.',
    correctionMessage: 'Rename the class to start with "Sliver".',
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
class PreferTextRichRule extends SaropaLintRule {
  const PreferTextRichRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'prefer_text_rich',
    problemMessage: 'Prefer Text.rich over RichText widget.',
    correctionMessage:
        'Use Text.rich(TextSpan(...)) instead of RichText(text: TextSpan(...)).',
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
      if (typeName == 'RichText') {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when using Column inside SingleChildScrollView instead of ListView.
///
/// Example of **bad** code:
/// ```dart
/// SingleChildScrollView(
///   child: Column(
///     children: widgets,
///   ),
/// )
/// ```
///
/// Example of **good** code:
/// ```dart
/// ListView(
///   children: widgets,
/// )
/// ```
class PreferUsingListViewRule extends SaropaLintRule {
  const PreferUsingListViewRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'prefer_using_list_view',
    problemMessage:
        'Column inside SingleChildScrollView. Consider using ListView.',
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
class PreferWidgetPrivateMembersRule extends SaropaLintRule {
  const PreferWidgetPrivateMembersRule() : super(code: _codeField);

  static const LintCode _codeField = LintCode(
    name: 'prefer_widget_private_members',
    problemMessage: 'Widget field should be final.',
    correctionMessage: 'Make the field final or private.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  static const LintCode _codeMethod = LintCode(
    name: 'prefer_widget_private_members',
    problemMessage:
        'Consider making this helper method private in Widget class.',
    correctionMessage: 'Prefix with underscore to make private.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  static const Set<String> _widgetBaseClasses = <String>{
    'StatelessWidget',
    'StatefulWidget',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
      // Check if it's a Widget class
      final ExtendsClause? extendsClause = node.extendsClause;
      if (extendsClause == null) return;

      final String superclass = extendsClause.superclass.name.lexeme;
      if (!_widgetBaseClasses.contains(superclass)) return;

      for (final ClassMember member in node.members) {
        // Check for non-final public fields
        if (member is FieldDeclaration) {
          if (member.isStatic) continue;
          final VariableDeclarationList fields = member.fields;
          if (!fields.isFinal) {
            for (final VariableDeclaration variable in fields.variables) {
              final String name = variable.name.lexeme;
              if (!name.startsWith('_')) {
                reporter.atNode(variable, _codeField);
              }
            }
          }
        }

        // Check for public non-override methods (not build, not createState)
        if (member is MethodDeclaration) {
          if (member.isStatic) continue;
          if (member.isGetter || member.isSetter) continue;

          final String methodName = member.name.lexeme;

          // Skip framework methods
          if (methodName == 'build' ||
              methodName == 'createState' ||
              methodName == 'createElement' ||
              methodName == 'debugFillProperties' ||
              methodName == 'toString') {
            continue;
          }

          // Skip overrides
          bool isOverride = false;
          for (final Annotation annotation in member.metadata) {
            if (annotation.name.name == 'override') {
              isOverride = true;
              break;
            }
          }
          if (isOverride) continue;

          // Warn on public methods
          if (!methodName.startsWith('_')) {
            reporter.atNode(member, _codeMethod);
          }
        }
      }
    });
  }
}

/// Warns when a State class has disposable fields that are not properly disposed.
///
/// StatefulWidget State classes should dispose of controllers, subscriptions,
/// and other disposable resources in their dispose() method to prevent memory leaks.
///
/// **Disposable types checked:**
/// - Controllers: TextEditingController, AnimationController, ScrollController,
///   TabController, PageController, FocusNode, etc.
/// - Streams: StreamSubscription, StreamController
/// - Others: Timer, ChangeNotifier, ValueNotifier
///
/// Example of **bad** code:
/// ```dart
/// class _MyWidgetState extends State<MyWidget> {
///   late TextEditingController _controller;
///
///   @override
///   void initState() {
///     super.initState();
///     _controller = TextEditingController();
///   }
///   // Missing dispose() - memory leak!
/// }
/// ```
///
/// Example of **good** code:
/// ```dart
/// class _MyWidgetState extends State<MyWidget> {
///   late TextEditingController _controller;
///
///   @override
///   void initState() {
///     super.initState();
///     _controller = TextEditingController();
///   }
///
///   @override
///   void dispose() {
///     _controller.dispose();
///     super.dispose();
///   }
/// }
/// ```
class RequireDisposeRule extends SaropaLintRule {
  const RequireDisposeRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'require_dispose',
    problemMessage: 'Disposable field may not be properly disposed.',
    correctionMessage: 'Add a dispose() method that disposes this field, '
        'or ensure the existing dispose() method handles it.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  /// Map of disposable type names to their disposal method.
  /// NOTE: Timer and StreamSubscription are handled by RequireTimerCancellationRule.
  static const Map<String, String> _disposableTypes = <String, String>{
    // Flutter Framework - Controllers (dispose)
    'TextEditingController': 'dispose',
    'AnimationController': 'dispose',
    'ScrollController': 'dispose',
    'TabController': 'dispose',
    'PageController': 'dispose',
    'TransformationController': 'dispose',
    'MaterialStatesController': 'dispose',
    'SearchController': 'dispose',
    'UndoHistoryController': 'dispose',
    'DraggableScrollableController': 'dispose',
    'MenuController': 'dispose',
    'OverlayPortalController': 'dispose',
    'RestorableTextEditingController': 'dispose',
    // Flutter Framework - Focus (dispose)
    'FocusNode': 'dispose',
    'FocusScopeNode': 'dispose',
    // Flutter Framework - Notifiers (dispose)
    'ChangeNotifier': 'dispose',
    'ValueNotifier': 'dispose',
    // Streams (close)
    'StreamController': 'close',
    // Common Packages (dispose)
    'CameraController': 'dispose',
    'VideoPlayerController': 'dispose',
    'AudioPlayer': 'dispose',
    'WebViewController': 'dispose',
    // State Management (close)
    'Bloc': 'close',
    'Cubit': 'close',
    'ProviderSubscription': 'close',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
      // Check if this is a State class
      if (!_isStateClass(node)) {
        return;
      }

      // Find all disposable fields
      final List<_DisposableField> disposableFields = <_DisposableField>[];
      for (final ClassMember member in node.members) {
        if (member is FieldDeclaration) {
          final _DisposableField? field = _getDisposableField(member);
          if (field != null) {
            disposableFields.add(field);
          }
        }
      }

      if (disposableFields.isEmpty) {
        return;
      }

      // Find the dispose method and collect all method bodies
      MethodDeclaration? disposeMethod;
      final Map<String, String> methodBodies = <String, String>{};

      for (final ClassMember member in node.members) {
        if (member is MethodDeclaration) {
          final String methodName = member.name.lexeme;
          methodBodies[methodName] = member.body.toSource();
          if (methodName == 'dispose') {
            disposeMethod = member;
          }
        }
      }

      // Get the dispose method body and expand helper method calls
      String disposeBody = '';
      if (disposeMethod != null) {
        disposeBody = _expandMethodCalls(
          disposeMethod.body.toSource(),
          methodBodies,
        );
      }

      // Check each disposable field
      for (final _DisposableField field in disposableFields) {
        if (disposeMethod == null) {
          // No dispose method at all
          reporter.atNode(field.declaration.fields, code);
        } else if (!_isFieldDisposed(field, disposeBody)) {
          // Dispose method exists but doesn't dispose this field
          reporter.atNode(field.declaration.fields, code);
        }
      }
    });
  }

  /// Expand helper method calls in the body to include their implementations.
  /// This allows detecting disposal patterns like `_cancelTimer()` that
  /// internally call `_timer?.cancel()`.
  String _expandMethodCalls(
    String body,
    Map<String, String> methodBodies, {
    int depth = 0,
  }) {
    // Prevent infinite recursion
    if (depth > 3) {
      return body;
    }

    final StringBuffer expanded = StringBuffer(body);

    // Find method calls to private methods (starting with _)
    final RegExp methodCallPattern = RegExp(r'_(\w+)\s*\(');
    for (final RegExpMatch match in methodCallPattern.allMatches(body)) {
      final String methodName = '_${match.group(1)}';
      final String? methodBody = methodBodies[methodName];
      if (methodBody != null) {
        // Recursively expand nested helper calls
        final String expandedMethodBody = _expandMethodCalls(
          methodBody,
          methodBodies,
          depth: depth + 1,
        );
        expanded.write(' $expandedMethodBody');
      }
    }

    return expanded.toString();
  }

  /// Check if a class extends `State<T>`
  bool _isStateClass(ClassDeclaration node) {
    final ExtendsClause? extendsClause = node.extendsClause;
    if (extendsClause == null) {
      return false;
    }

    final String superclassName = extendsClause.superclass.name.lexeme;
    return superclassName == 'State';
  }

  /// Extract disposable field info from a field declaration
  _DisposableField? _getDisposableField(FieldDeclaration node) {
    final TypeAnnotation? type = node.fields.type;
    if (type == null) {
      return null;
    }

    String typeName = '';
    if (type is NamedType) {
      typeName = type.name.lexeme;
    }

    if (!_disposableTypes.containsKey(typeName)) {
      return null;
    }

    // Get the field name
    if (node.fields.variables.isEmpty) {
      return null;
    }

    final String fieldName = node.fields.variables.first.name.lexeme;
    final String disposeMethod = _disposableTypes[typeName]!;

    return _DisposableField(
      name: fieldName,
      typeName: typeName,
      disposeMethod: disposeMethod,
      declaration: node,
    );
  }

  /// Check if a field is properly disposed in the dispose body
  bool _isFieldDisposed(_DisposableField field, String disposeBody) {
    final String name = field.name;
    final String method = field.disposeMethod;

    // Common disposal patterns
    final List<String> patterns = <String>[
      '$name.$method(',
      '$name?.$method(',
      '$name..$method(',
      '$name.${method}Safe(',
      '$name?.${method}Safe(',
      '$name..${method}Safe(',
    ];

    for (final String pattern in patterns) {
      if (disposeBody.contains(pattern)) {
        return true;
      }
    }

    return false;
  }
}

/// Helper class to track disposable field information
class _DisposableField {
  const _DisposableField({
    required this.name,
    required this.typeName,
    required this.disposeMethod,
    required this.declaration,
  });

  final String name;
  final String typeName;
  final String disposeMethod;
  final FieldDeclaration declaration;
}

/// Requires Timer and StreamSubscription fields to be cancelled in dispose().
///
/// Timers and stream subscriptions that aren't cancelled will continue running
/// after the widget is disposed, causing:
/// - Crashes if they call setState on a disposed widget
/// - Memory leaks from retained references
/// - Wasted CPU cycles
///
/// Example of **bad** code:
/// ```dart
/// class _MyState extends State<MyWidget> {
///   Timer? _timer;
///
///   @override
///   void initState() {
///     super.initState();
///     _timer = Timer.periodic(Duration(seconds: 1), (_) {
///       setState(() => _count++);  // 💥 Crashes after dispose!
///     });
///   }
///
///   @override
///   void dispose() {
///     // Missing: _timer?.cancel();
///     super.dispose();
///   }
/// }
/// ```
///
/// Example of **good** code:
/// ```dart
/// class _MyState extends State<MyWidget> {
///   Timer? _timer;
///
///   @override
///   void dispose() {
///     _timer?.cancel();
///     _timer = null;
///     super.dispose();
///   }
/// }
/// ```
class RequireTimerCancellationRule extends SaropaLintRule {
  const RequireTimerCancellationRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'require_timer_cancellation',
    problemMessage:
        'Timer or StreamSubscription must be cancelled in dispose().',
    correctionMessage:
        'Add cancel() in dispose() to prevent crashes and memory leaks. '
        'Uncancelled timers continue firing after widget disposal.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  /// Types that require cancel() to be called
  static const Map<String, String> _cancellableTypes = <String, String>{
    'Timer': 'cancel',
    'StreamSubscription': 'cancel',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
      // Only check State classes
      if (!_isStateClass(node)) {
        return;
      }

      // Find all cancellable fields
      final List<_CancellableField> cancellableFields = <_CancellableField>[];
      for (final ClassMember member in node.members) {
        if (member is FieldDeclaration) {
          final _CancellableField? field = _getCancellableField(member);
          if (field != null) {
            cancellableFields.add(field);
          }
        }
      }

      if (cancellableFields.isEmpty) {
        return;
      }

      // Collect all method bodies for helper method expansion
      MethodDeclaration? disposeMethod;
      final Map<String, String> methodBodies = <String, String>{};

      for (final ClassMember member in node.members) {
        if (member is MethodDeclaration) {
          final String methodName = member.name.lexeme;
          methodBodies[methodName] = member.body.toSource();
          if (methodName == 'dispose') {
            disposeMethod = member;
          }
        }
      }

      // Expand dispose body to include helper methods
      String disposeBody = '';
      if (disposeMethod != null) {
        disposeBody = _expandMethodCalls(
          disposeMethod.body.toSource(),
          methodBodies,
        );
      }

      // Check each cancellable field
      for (final _CancellableField field in cancellableFields) {
        if (disposeMethod == null) {
          reporter.atNode(field.declaration.fields, code);
        } else if (!_isFieldCancelled(field, disposeBody)) {
          reporter.atNode(field.declaration.fields, code);
        }
      }
    });
  }

  /// Check if a class extends `State<T>`
  bool _isStateClass(ClassDeclaration node) {
    final ExtendsClause? extendsClause = node.extendsClause;
    if (extendsClause == null) {
      return false;
    }
    return extendsClause.superclass.name.lexeme == 'State';
  }

  /// Extract cancellable field info from a field declaration
  _CancellableField? _getCancellableField(FieldDeclaration node) {
    final TypeAnnotation? type = node.fields.type;
    if (type == null) {
      return null;
    }

    String typeName = '';
    if (type is NamedType) {
      typeName = type.name.lexeme;
    }

    if (!_cancellableTypes.containsKey(typeName)) {
      return null;
    }

    if (node.fields.variables.isEmpty) {
      return null;
    }

    final String fieldName = node.fields.variables.first.name.lexeme;

    return _CancellableField(
      name: fieldName,
      typeName: typeName,
      declaration: node,
    );
  }

  /// Expand helper method calls to include their implementations
  String _expandMethodCalls(
    String body,
    Map<String, String> methodBodies, {
    int depth = 0,
  }) {
    if (depth > 3) {
      return body;
    }

    final StringBuffer expanded = StringBuffer(body);
    final RegExp methodCallPattern = RegExp(r'_(\w+)\s*\(');

    for (final RegExpMatch match in methodCallPattern.allMatches(body)) {
      final String methodName = '_${match.group(1)}';
      final String? methodBody = methodBodies[methodName];
      if (methodBody != null) {
        final String expandedMethodBody = _expandMethodCalls(
          methodBody,
          methodBodies,
          depth: depth + 1,
        );
        expanded.write(' $expandedMethodBody');
      }
    }

    return expanded.toString();
  }

  /// Check if a field is properly cancelled
  bool _isFieldCancelled(_CancellableField field, String disposeBody) {
    final String name = field.name;

    // Common cancellation patterns
    final List<String> patterns = <String>[
      '$name.cancel(',
      '$name?.cancel(',
      '$name..cancel(',
      '$name.cancelSafe(',
      '$name?.cancelSafe(',
      '$name..cancelSafe(',
    ];

    for (final String pattern in patterns) {
      if (disposeBody.contains(pattern)) {
        return true;
      }
    }

    return false;
  }
}

/// Helper class to track cancellable field information
class _CancellableField {
  const _CancellableField({
    required this.name,
    required this.typeName,
    required this.declaration,
  });

  final String name;
  final String typeName;
  final FieldDeclaration declaration;
}

/// Suggests nullifying nullable disposable fields after disposal.
///
/// When a nullable disposable field (Timer?, StreamSubscription?, etc.) is
/// disposed/cancelled, it's good practice to also set it to null. This:
/// - Helps garbage collection
/// - Prevents accidental reuse of disposed resources
/// - Makes it clear the resource has been cleaned up
///
/// Example of **bad** code:
/// ```dart
/// void _cancelTimer() {
///   _timer?.cancel();
///   // Missing: _timer = null;
/// }
/// ```
///
/// Example of **good** code:
/// ```dart
/// void _cancelTimer() {
///   _timer?.cancel();
///   _timer = null;
/// }
/// ```
class NullifyAfterDisposeRule extends SaropaLintRule {
  const NullifyAfterDisposeRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'nullify_after_dispose',
    problemMessage:
        'Nullable disposable field should be set to null after disposal.',
    correctionMessage:
        'Add `fieldName = null;` after disposing to help garbage collection '
        'and prevent accidental reuse.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  /// Map of disposable type names to their disposal method
  static const Map<String, String> _disposableTypes = <String, String>{
    'Timer': 'cancel',
    'StreamSubscription': 'cancel',
    'StreamController': 'close',
    'AnimationController': 'dispose',
    'TextEditingController': 'dispose',
    'ScrollController': 'dispose',
    'TabController': 'dispose',
    'PageController': 'dispose',
    'FocusNode': 'dispose',
    'ChangeNotifier': 'dispose',
    'ValueNotifier': 'dispose',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;

      // Check if this is a disposal method call
      final String? disposedType = _getDisposedType(methodName);
      if (disposedType == null) {
        return;
      }

      // Get the target (e.g., _timer in _timer?.cancel())
      final Expression? target = node.realTarget;
      if (target is! SimpleIdentifier) {
        return;
      }

      final String fieldName = target.name;

      // Check if this is a nullable call (?.cancel or ?.dispose)
      // We only suggest nullification for nullable fields
      final AstNode? parent = node.parent;
      if (parent is! ExpressionStatement) {
        return;
      }

      // Find the containing block to check for nullification
      final Block? containingBlock = _findContainingBlock(node);
      if (containingBlock == null) {
        return;
      }

      // Check if the field is nullified after this statement
      if (_isNullifiedAfter(containingBlock, parent, fieldName)) {
        return;
      }

      // Report the issue
      reporter.atNode(node, code);
    });
  }

  /// Get the type being disposed based on the method name
  String? _getDisposedType(String methodName) {
    // Check both regular and Safe versions
    final String baseMethod = methodName.endsWith('Safe')
        ? methodName.replaceAll('Safe', '')
        : methodName;

    for (final MapEntry<String, String> entry in _disposableTypes.entries) {
      if (entry.value == baseMethod) {
        return entry.key;
      }
    }
    return null;
  }

  /// Find the containing block statement
  Block? _findContainingBlock(AstNode node) {
    AstNode? current = node.parent;
    while (current != null) {
      if (current is Block) {
        return current;
      }
      current = current.parent;
    }
    return null;
  }

  /// Check if the field is set to null after the given statement
  bool _isNullifiedAfter(
    Block block,
    ExpressionStatement disposeStatement,
    String fieldName,
  ) {
    bool foundDisposeStatement = false;

    for (final Statement statement in block.statements) {
      if (statement == disposeStatement) {
        foundDisposeStatement = true;
        continue;
      }

      if (!foundDisposeStatement) {
        continue;
      }

      // Look for assignment to null: fieldName = null
      if (statement is ExpressionStatement) {
        final Expression expression = statement.expression;
        if (expression is AssignmentExpression) {
          final Expression leftSide = expression.leftHandSide;
          final Expression rightSide = expression.rightHandSide;

          if (leftSide is SimpleIdentifier &&
              leftSide.name == fieldName &&
              rightSide is NullLiteral) {
            return true;
          }
        }
      }
    }

    return false;
  }
}

/// Warns when setState is called after an async gap without mounted check.
///
/// Example of **bad** code:
/// ```dart
/// Future<void> loadData() async {
///   final data = await fetchData();
///   setState(() { _data = data; });  // May call on unmounted widget
/// }
/// ```
///
/// Example of **good** code:
/// ```dart
/// Future<void> loadData() async {
///   final data = await fetchData();
///   if (mounted) {
///     setState(() { _data = data; });
///   }
/// }
/// ```
class UseSetStateSynchronouslyRule extends SaropaLintRule {
  const UseSetStateSynchronouslyRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'use_setstate_synchronously',
    problemMessage: 'setState called after async gap without mounted check.',
    correctionMessage: 'Check mounted before calling setState after await.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodDeclaration((MethodDeclaration node) {
      // Only check async methods
      if (node.body is! BlockFunctionBody) return;
      final BlockFunctionBody body = node.body as BlockFunctionBody;
      if (!body.isAsynchronous) return;

      // Track if we've seen an await
      bool seenAwait = false;

      for (final Statement stmt in body.block.statements) {
        // Check for await expressions
        if (_containsAwait(stmt)) {
          seenAwait = true;
        }

        // After await, check for setState without mounted check
        if (seenAwait && _containsSetStateWithoutMountedCheck(stmt)) {
          _reportSetStateInStatement(stmt, reporter);
        }
      }
    });
  }

  bool _containsAwait(AstNode node) {
    bool found = false;
    node.visitChildren(
      _AwaitFinder((AwaitExpression _) {
        found = true;
      }),
    );
    return found;
  }

  bool _containsSetStateWithoutMountedCheck(Statement stmt) {
    // If it's an if statement checking mounted, it's fine
    if (stmt is IfStatement) {
      if (_checksMounted(stmt.expression)) {
        return false;
      }
    }

    // Check for setState calls
    return _containsSetState(stmt);
  }

  bool _checksMounted(Expression expr) {
    if (expr is SimpleIdentifier && expr.name == 'mounted') {
      return true;
    }
    if (expr is PrefixedIdentifier && expr.identifier.name == 'mounted') {
      return true;
    }
    return false;
  }

  bool _containsSetState(AstNode node) {
    bool found = false;
    node.visitChildren(
      _SetStateFinderBatch11((MethodInvocation _) {
        found = true;
      }),
    );
    return found;
  }

  void _reportSetStateInStatement(
      Statement stmt, SaropaDiagnosticReporter reporter) {
    stmt.visitChildren(
      _SetStateFinderBatch11((MethodInvocation node) {
        reporter.atNode(node, code);
      }),
    );
  }
}

class _AwaitFinder extends RecursiveAstVisitor<void> {
  _AwaitFinder(this.onFound);

  final void Function(AwaitExpression) onFound;

  @override
  void visitAwaitExpression(AwaitExpression node) {
    onFound(node);
    super.visitAwaitExpression(node);
  }
}

class _SetStateFinderBatch11 extends RecursiveAstVisitor<void> {
  _SetStateFinderBatch11(this.onFound);
  final void Function(MethodInvocation) onFound;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.methodName.name == 'setState') {
      onFound(node);
    }
    super.visitMethodInvocation(node);
  }
}

/// Warns when a listener is added but never removed.
///
/// Listeners that are not removed can cause memory leaks and unexpected
/// behavior after the widget is disposed.
///
/// Example of **bad** code:
/// ```dart
/// @override
/// void initState() {
///   super.initState();
///   controller.addListener(_onChanged);  // Never removed!
/// }
/// ```
///
/// Example of **good** code:
/// ```dart
/// @override
/// void initState() {
///   super.initState();
///   controller.addListener(_onChanged);
/// }
///
/// @override
/// void dispose() {
///   controller.removeListener(_onChanged);
///   super.dispose();
/// }
/// ```
class AlwaysRemoveListenerRule extends SaropaLintRule {
  const AlwaysRemoveListenerRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'always_remove_listener',
    problemMessage: 'Listener added but may not be removed.',
    correctionMessage: 'Ensure the listener is removed in dispose() '
        'to prevent memory leaks.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
      // Only check State classes
      final ExtendsClause? extendsClause = node.extendsClause;
      if (extendsClause == null) return;

      final NamedType superclass = extendsClause.superclass;
      final String? superName = superclass.element?.name;
      if (superName != 'State') return;

      // Find initState and dispose methods
      MethodDeclaration? initStateMethod;
      MethodDeclaration? disposeMethod;

      for (final ClassMember member in node.members) {
        if (member is MethodDeclaration) {
          final String name = member.name.lexeme;
          if (name == 'initState') {
            initStateMethod = member;
          } else if (name == 'dispose') {
            disposeMethod = member;
          }
        }
      }

      if (initStateMethod == null) return;

      // Find all addListener calls in initState
      final List<_ListenerInfo> addedListeners = <_ListenerInfo>[];
      final FunctionBody initBody = initStateMethod.body;
      initBody.visitChildren(
        _AddListenerFinder((String target, String callback, AstNode srcNode) {
          addedListeners.add(_ListenerInfo(target, callback, srcNode));
        }),
      );

      if (addedListeners.isEmpty) return;

      // Find all removeListener calls in dispose
      final List<_ListenerInfo> removedListeners = <_ListenerInfo>[];
      final FunctionBody? disposeBody = disposeMethod?.body;
      if (disposeBody != null) {
        disposeBody.visitChildren(
          _RemoveListenerFinder((String target, String callback) {
            removedListeners.add(_ListenerInfo(target, callback, null));
          }),
        );
      }

      // Check if each added listener has a corresponding remove
      for (final _ListenerInfo added in addedListeners) {
        final bool hasRemove = removedListeners.any(
          (_ListenerInfo removed) =>
              removed.target == added.target &&
              removed.callback == added.callback,
        );
        if (!hasRemove && added.node != null) {
          reporter.atNode(added.node!, code);
        }
      }
    });
  }
}

class _ListenerInfo {
  _ListenerInfo(this.target, this.callback, this.node);
  final String target;
  final String callback;
  final AstNode? node;
}

class _AddListenerFinder extends RecursiveAstVisitor<void> {
  _AddListenerFinder(this.onFound);
  final void Function(String target, String callback, AstNode node) onFound;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.methodName.name == 'addListener') {
      final String target = node.realTarget?.toSource() ?? '';
      final NodeList<Expression> args = node.argumentList.arguments;
      if (args.isNotEmpty) {
        final String callback = args.first.toSource();
        onFound(target, callback, node);
      }
    }
    super.visitMethodInvocation(node);
  }
}

class _RemoveListenerFinder extends RecursiveAstVisitor<void> {
  _RemoveListenerFinder(this.onFound);
  final void Function(String target, String callback) onFound;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.methodName.name == 'removeListener') {
      final String target = node.realTarget?.toSource() ?? '';
      final NodeList<Expression> args = node.argumentList.arguments;
      if (args.isNotEmpty) {
        final String callback = args.first.toSource();
        onFound(target, callback);
      }
    }
    super.visitMethodInvocation(node);
  }
}

/// Warns when Border.all is used instead of const Border.fromBorderSide.
///
/// `Border.all` cannot be const, but `Border.fromBorderSide` can be.
///
/// Example of **bad** code:
/// ```dart
/// Border.all(color: Colors.red, width: 2)
/// ```
///
/// Example of **good** code:
/// ```dart
/// const Border.fromBorderSide(BorderSide(color: Colors.red, width: 2))
/// ```
class AvoidBorderAllRule extends SaropaLintRule {
  const AvoidBorderAllRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_border_all',
    problemMessage: 'Prefer Border.fromBorderSide for const borders.',
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

  static const LintCode _code = LintCode(
    name: 'avoid_deeply_nested_widgets',
    problemMessage: 'Widget tree is too deeply nested.',
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
    // Common widget suffixes
    return name.endsWith('Widget') ||
        name.endsWith('Button') ||
        name.endsWith('Text') ||
        name.endsWith('Container') ||
        name.endsWith('Card') ||
        name.endsWith('Row') ||
        name.endsWith('Column') ||
        name.endsWith('Padding') ||
        name.endsWith('Center') ||
        name.endsWith('Expanded') ||
        name.endsWith('Flexible') ||
        name.endsWith('SizedBox') ||
        name.endsWith('Scaffold') ||
        name.endsWith('AppBar') ||
        name.endsWith('ListView') ||
        name.endsWith('GridView') ||
        name.endsWith('Stack') ||
        name == 'Text' ||
        name == 'Icon' ||
        name == 'Image';
  }
}

/// Future rule: require-animation-disposal
/// Warns when AnimationController is created without proper disposal.
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
class RequireAnimationDisposalRule extends SaropaLintRule {
  const RequireAnimationDisposalRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'require_animation_disposal',
    problemMessage: 'AnimationController should be disposed.',
    correctionMessage: 'Add _controller.dispose() in the dispose() method.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
      // Only check State classes - StatelessWidgets receive controllers
      // as parameters and don't own them (parent disposes)
      if (!_isStateClass(node)) {
        return;
      }

      // Find AnimationController fields
      final Set<String> animationControllerFields = <String>{};

      for (final ClassMember member in node.members) {
        if (member is FieldDeclaration) {
          final TypeAnnotation? type = member.fields.type;
          if (type is NamedType && type.name.lexeme == 'AnimationController') {
            for (final VariableDeclaration variable
                in member.fields.variables) {
              animationControllerFields.add(variable.name.lexeme);
            }
          }
        }
      }

      if (animationControllerFields.isEmpty) return;

      // Check if dispose method exists and disposes all controllers
      bool hasDisposeMethod = false;
      final Set<String> disposedFields = <String>{};

      for (final ClassMember member in node.members) {
        if (member is MethodDeclaration && member.name.lexeme == 'dispose') {
          hasDisposeMethod = true;
          member.body.accept(
            _DisposeCallFinder((String fieldName) {
              disposedFields.add(fieldName);
            }),
          );
        }
      }

      // Report undisposed animation controllers
      for (final String fieldName in animationControllerFields) {
        if (!hasDisposeMethod || !disposedFields.contains(fieldName)) {
          // Report at the field declaration
          for (final ClassMember member in node.members) {
            if (member is FieldDeclaration) {
              for (final VariableDeclaration variable
                  in member.fields.variables) {
                if (variable.name.lexeme == fieldName) {
                  reporter.atNode(variable, code);
                }
              }
            }
          }
        }
      }
    });
  }

  /// Check if a class extends `State<T>`
  bool _isStateClass(ClassDeclaration node) {
    final ExtendsClause? extendsClause = node.extendsClause;
    if (extendsClause == null) {
      return false;
    }

    final String superclassName = extendsClause.superclass.name.lexeme;
    return superclassName == 'State';
  }
}

class _DisposeCallFinder extends RecursiveAstVisitor<void> {
  _DisposeCallFinder(this.onFound);
  final void Function(String) onFound;

  static const Set<String> _disposeMethodNames = <String>{
    'dispose',
    'disposeSafe',
  };

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (_disposeMethodNames.contains(node.methodName.name)) {
      final Expression? target = node.realTarget;
      if (target is SimpleIdentifier) {
        onFound(target.name);
      }
    }
    super.visitMethodInvocation(node);
  }
}

/// Future rule: avoid-uncontrolled-text-field
/// Warns when TextField is used without a controller.
///
/// Example of **bad** code:
/// ```dart
/// TextField(
///   onChanged: (value) { },
/// )
/// ```
///
/// Example of **good** code:
/// ```dart
/// TextField(
///   controller: _textController,
///   onChanged: (value) { },
/// )
/// ```
class AvoidUncontrolledTextFieldRule extends SaropaLintRule {
  const AvoidUncontrolledTextFieldRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_uncontrolled_text_field',
    problemMessage:
        'TextField should have a controller for proper state management.',
    correctionMessage: 'Add a TextEditingController to the TextField.',
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
      if (typeName != 'TextField' && typeName != 'TextFormField') return;

      // Check if controller argument is provided
      final ArgumentList args = node.argumentList;
      bool hasController = false;

      for (final Expression arg in args.arguments) {
        if (arg is NamedExpression && arg.name.label.name == 'controller') {
          hasController = true;
          break;
        }
      }

      if (!hasController) {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Future rule: avoid-hardcoded-asset-paths
/// Warns when asset paths are hardcoded as string literals.
///
/// Example of **bad** code:
/// ```dart
/// Image.asset('assets/images/logo.png')
/// ```
///
/// Example of **good** code:
/// ```dart
/// Image.asset(Assets.images.logo)  // Using generated assets class
/// ```
class AvoidHardcodedAssetPathsRule extends SaropaLintRule {
  const AvoidHardcodedAssetPathsRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_hardcoded_asset_paths',
    problemMessage: 'Asset path should not be hardcoded.',
    correctionMessage:
        'Use a constants class or generated assets for asset paths.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      // Check for Image.asset, AssetImage, etc.
      final String methodName = node.methodName.name;
      if (methodName != 'asset' && methodName != 'file') return;

      final Expression? target = node.target;
      if (target is! SimpleIdentifier) return;
      if (target.name != 'Image' && target.name != 'AssetImage') return;

      final ArgumentList args = node.argumentList;
      if (args.arguments.isEmpty) return;

      final Expression firstArg = args.arguments.first;
      if (firstArg is StringLiteral) {
        final String? path = firstArg.stringValue;
        if (path != null &&
            (path.contains('assets/') || path.contains('images/'))) {
          reporter.atNode(firstArg, code);
        }
      }
    });

    // Also check for AssetImage constructor
    context.registry
        .addInstanceCreationExpression((InstanceCreationExpression node) {
      final String typeName = node.constructorName.type.name.lexeme;
      if (typeName != 'AssetImage') return;

      final ArgumentList args = node.argumentList;
      if (args.arguments.isEmpty) return;

      final Expression firstArg = args.arguments.first;
      if (firstArg is StringLiteral) {
        final String? path = firstArg.stringValue;
        if (path != null &&
            (path.contains('assets/') || path.contains('images/'))) {
          reporter.atNode(firstArg, code);
        }
      }
    });
  }
}

/// Future rule: avoid-print-in-production
/// Warns when print() is used outside of debug/test code.
///
/// Example of **bad** code:
/// ```dart
/// void handleError(Object error) {
///   print('Error: $error');  // Use proper logging
/// }
/// ```
///
/// Example of **good** code:
/// ```dart
/// void handleError(Object error) {
///   logger.error('Error: $error');
/// }
/// ```
///
/// **Quick fix available:** Comments out the print statement.
class AvoidPrintInProductionRule extends SaropaLintRule {
  const AvoidPrintInProductionRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_print_in_production',
    problemMessage: 'Avoid using print() in production code.',
    correctionMessage: 'Use a proper logging framework instead.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    // Skip test files
    final String path = resolver.path;
    if (path.contains('_test.dart') || path.contains('/test/')) return;

    context.registry.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name != 'print') return;

      // Check if it's the top-level print function
      if (node.target == null) {
        reporter.atNode(node, code);
      }
    });
  }

  @override
  List<Fix> getFixes() => <Fix>[_CommentOutPrintFix()];
}

class _CommentOutPrintFix extends DartFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name != 'print') return;
      if (node.target != null) return;
      if (!node.sourceRange.intersects(analysisError.sourceRange)) return;

      // Find the statement containing this invocation
      final AstNode? statement = _findContainingStatement(node);
      if (statement == null) return;

      final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
        message: 'Comment out print statement',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        // Comment out the statement to preserve developer intent history
        final String originalCode = statement.toSource();
        builder.addSimpleReplacement(
          SourceRange(statement.offset, statement.length),
          '// $originalCode',
        );
      });
    });
  }

  AstNode? _findContainingStatement(AstNode node) {
    AstNode? current = node;
    while (current != null) {
      if (current is ExpressionStatement) {
        return current;
      }
      current = current.parent;
    }
    return null;
  }
}

/// Future rule: avoid-catching-generic-exception
/// Warns when catching Exception or Object too broadly.
///
/// Example of **bad** code:
/// ```dart
/// try {
///   doSomething();
/// } catch (e) {  // Catches everything
///   print(e);
/// }
/// ```
///
/// Example of **good** code:
/// ```dart
/// try {
///   doSomething();
/// } on FormatException catch (e) {
///   // Handle specific exception
/// }
/// ```
class AvoidCatchingGenericExceptionRule extends SaropaLintRule {
  const AvoidCatchingGenericExceptionRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_catching_generic_exception',
    problemMessage: 'Avoid catching generic exceptions.',
    correctionMessage: 'Catch specific exception types instead.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addCatchClause((CatchClause node) {
      final TypeAnnotation? exceptionType = node.exceptionType;

      // Catch without type catches everything
      if (exceptionType == null) {
        reporter.atNode(node, code);
        return;
      }

      // Check for generic types
      if (exceptionType is NamedType) {
        final String typeName = exceptionType.name.lexeme;
        if (typeName == 'Exception' ||
            typeName == 'Object' ||
            typeName == 'dynamic') {
          reporter.atNode(exceptionType, code);
        }
      }
    });
  }
}

/// Future rule: avoid-service-locator-overuse
/// Warns when GetIt.I or similar service locator calls are scattered throughout.
///
/// Example of **bad** code:
/// ```dart
/// class MyWidget extends StatelessWidget {
///   @override
///   Widget build(BuildContext context) {
///     final service = GetIt.I<MyService>();  // Scattered DI
///     return Text(service.value);
///   }
/// }
/// ```
///
/// Example of **good** code:
/// ```dart
/// class MyWidget extends StatelessWidget {
///   final MyService service;
///   const MyWidget({required this.service});
///   // Constructor injection
/// }
/// ```
class AvoidServiceLocatorOveruseRule extends SaropaLintRule {
  const AvoidServiceLocatorOveruseRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_service_locator_overuse',
    problemMessage:
        'Service locator call in widget. Prefer constructor injection.',
    correctionMessage: 'Pass dependencies through the constructor instead.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodDeclaration((MethodDeclaration node) {
      // Only check build methods
      if (node.name.lexeme != 'build') return;

      // Find GetIt calls in build method
      node.body.accept(
        _ServiceLocatorFinder((MethodInvocation call) {
          reporter.atNode(call, code);
        }),
      );
    });
  }
}

class _ServiceLocatorFinder extends RecursiveAstVisitor<void> {
  _ServiceLocatorFinder(this.onFound);
  final void Function(MethodInvocation) onFound;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    // Check for GetIt.I<T>() or GetIt.instance<T>() or locator<T>()
    final Expression? target = node.target;

    if (target is SimpleIdentifier) {
      if (target.name == 'GetIt' ||
          target.name == 'locator' ||
          target.name == 'sl') {
        onFound(node);
      }
    } else if (target is PrefixedIdentifier) {
      if (target.identifier.name == 'I' ||
          target.identifier.name == 'instance') {
        if (target.prefix.name == 'GetIt') {
          onFound(node);
        }
      }
    }

    super.visitMethodInvocation(node);
  }
}

/// Future rule: prefer-utc-datetimes
/// Warns when DateTime.now() is used where UTC might be more appropriate.
///
/// Example of code that might need UTC:
/// ```dart
/// final timestamp = DateTime.now();  // Consider DateTime.now().toUtc()
/// ```
class PreferUtcDateTimesRule extends SaropaLintRule {
  const PreferUtcDateTimesRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'prefer_utc_datetimes',
    problemMessage: 'Consider using UTC DateTime for storage/transmission.',
    correctionMessage:
        'Use DateTime.now().toUtc() or DateTime.utc() for timestamps.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name != 'now') return;

      final Expression? target = node.target;
      if (target is! SimpleIdentifier) return;
      if (target.name != 'DateTime') return;

      // Check if it's being stored or transmitted (in an assignment or json context)
      final AstNode? parent = node.parent;
      if (parent is VariableDeclaration) {
        final String varName = parent.name.lexeme.toLowerCase();
        // Warn for names that suggest storage/transmission
        if (varName.contains('timestamp') ||
            varName.contains('created') ||
            varName.contains('updated') ||
            varName.contains('saved')) {
          reporter.atNode(node, code);
        }
      }
    });
  }
}

/// Future rule: avoid-regex-in-loop
/// Warns when RegExp is created inside a loop.
///
/// Example of **bad** code:
/// ```dart
/// for (final item in items) {
///   final regex = RegExp(r'\d+');  // Created every iteration
///   if (regex.hasMatch(item)) { }
/// }
/// ```
///
/// Example of **good** code:
/// ```dart
/// final regex = RegExp(r'\d+');  // Created once
/// for (final item in items) {
///   if (regex.hasMatch(item)) { }
/// }
/// ```
class AvoidRegexInLoopRule extends SaropaLintRule {
  const AvoidRegexInLoopRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_regex_in_loop',
    problemMessage:
        'RegExp created inside loop. Move it outside for efficiency.',
    correctionMessage: 'Create the RegExp once outside the loop.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addForStatement((ForStatement node) {
      node.body.accept(
        _RegExpCreationFinder((InstanceCreationExpression expr) {
          reporter.atNode(expr, code);
        }),
      );
    });

    context.registry.addWhileStatement((WhileStatement node) {
      node.body.accept(
        _RegExpCreationFinder((InstanceCreationExpression expr) {
          reporter.atNode(expr, code);
        }),
      );
    });

    context.registry.addDoStatement((DoStatement node) {
      node.body.accept(
        _RegExpCreationFinder((InstanceCreationExpression expr) {
          reporter.atNode(expr, code);
        }),
      );
    });
  }
}

class _RegExpCreationFinder extends RecursiveAstVisitor<void> {
  _RegExpCreationFinder(this.onFound);
  final void Function(InstanceCreationExpression) onFound;

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    final String typeName = node.constructorName.type.name.lexeme;
    if (typeName == 'RegExp') {
      onFound(node);
    }
    super.visitInstanceCreationExpression(node);
  }
}

/// Future rule: prefer-getter-over-method
/// Warns when a method with no parameters just returns a value.
///
/// Example of **bad** code:
/// ```dart
/// String getName() => _name;
/// int getCount() { return _count; }
/// ```
///
/// Example of **good** code:
/// ```dart
/// String get name => _name;
/// int get count => _count;
/// ```
class PreferGetterOverMethodRule extends SaropaLintRule {
  const PreferGetterOverMethodRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'prefer_getter_over_method',
    problemMessage: 'Use a getter instead of a method that returns a value.',
    correctionMessage: 'Convert to a getter: get name => _name;',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodDeclaration((MethodDeclaration node) {
      // Skip getters, setters, operators
      if (node.isGetter || node.isSetter || node.isOperator) return;

      // Skip methods with parameters
      final FormalParameterList? params = node.parameters;
      if (params == null) return;
      if (params.parameters.isNotEmpty) return;

      // Skip async methods
      if (node.body.isAsynchronous) return;

      // Skip void return type
      final TypeAnnotation? returnType = node.returnType;
      if (returnType is NamedType && returnType.name.lexeme == 'void') return;

      // Check if body is a simple expression return
      final FunctionBody body = node.body;
      if (body is ExpressionFunctionBody) {
        // Simple expression body - likely should be a getter
        final String name = node.name.lexeme;
        // Skip methods starting with common action prefixes
        if (!name.startsWith('get') &&
            !name.startsWith('fetch') &&
            !name.startsWith('load') &&
            !name.startsWith('create') &&
            !name.startsWith('build') &&
            !name.startsWith('compute') &&
            !name.startsWith('calculate')) {
          return;
        }
        reporter.atToken(node.name, code);
      } else if (body is BlockFunctionBody) {
        // Check if it's a single return statement
        final Block block = body.block;
        if (block.statements.length == 1) {
          final Statement stmt = block.statements.first;
          if (stmt is ReturnStatement && stmt.expression != null) {
            final String name = node.name.lexeme;
            if (name.startsWith('get') && name.length > 3) {
              reporter.atToken(node.name, code);
            }
          }
        }
      }
    });
  }
}

/// Future rule: avoid-unused-parameters-in-callbacks
/// Warns when callback parameters are declared but not used.
///
/// Example of **bad** code:
/// ```dart
/// onTap: (value) {
///   print('tapped');
/// }
/// ```
///
/// Example of **good** code:
/// ```dart
/// onTap: (_) {
///   print('tapped');
/// }
/// ```
class AvoidUnusedCallbackParametersRule extends SaropaLintRule {
  const AvoidUnusedCallbackParametersRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_unused_callback_parameters',
    problemMessage: 'Callback parameter is declared but not used.',
    correctionMessage: 'Use underscore (_) for unused parameters.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addFunctionExpression((FunctionExpression node) {
      final NodeList<FormalParameter>? parameters = node.parameters?.parameters;
      if (parameters == null || parameters.isEmpty) return;

      // Get all identifiers used in the body
      final Set<String> usedIdentifiers = <String>{};
      node.body.visitChildren(_IdentifierCollector(usedIdentifiers));

      for (final FormalParameter param in parameters) {
        final String? name = param.name?.lexeme;
        if (name == null || name.startsWith('_')) continue;

        if (!usedIdentifiers.contains(name)) {
          reporter.atToken(param.name!, code);
        }
      }
    });
  }
}

class _IdentifierCollector extends RecursiveAstVisitor<void> {
  _IdentifierCollector(this.identifiers);
  final Set<String> identifiers;

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    identifiers.add(node.name);
    super.visitSimpleIdentifier(node);
  }
}

/// Future rule: prefer-const-widgets-in-lists
/// Warns when widget literals in lists could be const.
///
/// Example of **bad** code:
/// ```dart
/// children: [
///   SizedBox(height: 8),
///   Divider(),
/// ]
/// ```
///
/// Example of **good** code:
/// ```dart
/// children: const [
///   SizedBox(height: 8),
///   Divider(),
/// ]
/// ```
class PreferConstWidgetsInListsRule extends SaropaLintRule {
  const PreferConstWidgetsInListsRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'prefer_const_widgets_in_lists',
    problemMessage: 'Widget list could be const.',
    correctionMessage: 'Add const keyword to the list literal.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addListLiteral((ListLiteral node) {
      // Skip if already const
      if (node.constKeyword != null) return;

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

  bool _couldBeConst(InstanceCreationExpression node) {
    // Simplified check - in reality would need semantic analysis
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
class AvoidScaffoldMessengerAfterAwaitRule extends SaropaLintRule {
  const AvoidScaffoldMessengerAfterAwaitRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_scaffold_messenger_after_await',
    problemMessage:
        'Using ScaffoldMessenger.of(context) after await may use an invalid context.',
    correctionMessage: 'Store ScaffoldMessenger.of(context) before the await.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addBlockFunctionBody((BlockFunctionBody node) {
      // Check if function is async
      if (node.keyword?.keyword != Keyword.ASYNC) return;

      bool hasAwait = false;
      for (final Statement statement in node.block.statements) {
        // Check for await expressions
        if (_containsAwait(statement)) {
          hasAwait = true;
        }

        // If we've seen an await, check for ScaffoldMessenger.of(context)
        if (hasAwait && _containsScaffoldMessengerOf(statement)) {
          // Find and report the specific usage
          statement.visitChildren(
            _ScaffoldMessengerFinderNew((MethodInvocation invocation) {
              reporter.atNode(invocation, code);
            }),
          );
        }
      }
    });
  }

  bool _containsAwait(AstNode node) {
    bool found = false;
    node.visitChildren(_AwaitFinder((_) => found = true));
    return found;
  }

  bool _containsScaffoldMessengerOf(AstNode node) {
    bool found = false;
    node.visitChildren(_ScaffoldMessengerFinderNew((_) => found = true));
    return found;
  }
}

class _ScaffoldMessengerFinderNew extends RecursiveAstVisitor<void> {
  _ScaffoldMessengerFinderNew(this.onFound);
  final void Function(MethodInvocation) onFound;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final Expression? target = node.target;
    if (target is SimpleIdentifier &&
        target.name == 'ScaffoldMessenger' &&
        node.methodName.name == 'of') {
      onFound(node);
    }
    super.visitMethodInvocation(node);
  }
}

/// Future rule: avoid-build-context-in-providers
/// Warns when BuildContext is stored in providers or state managers.
///
/// Example of **bad** code:
/// ```dart
/// class MyProvider extends ChangeNotifier {
///   late BuildContext _context;
///   void setContext(BuildContext context) => _context = context;
/// }
/// ```
///
/// Example of **good** code:
/// ```dart
/// // Use callbacks or pass context only when needed
/// class MyProvider extends ChangeNotifier {
///   void showMessage(BuildContext context, String msg) {...}
/// }
/// ```
class AvoidBuildContextInProvidersRule extends SaropaLintRule {
  const AvoidBuildContextInProvidersRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_build_context_in_providers',
    problemMessage: 'Storing BuildContext in providers can cause memory leaks.',
    correctionMessage:
        'Pass BuildContext as a method parameter when needed instead.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
      // Check if class is a provider (extends ChangeNotifier, etc.)
      final ExtendsClause? extendsClause = node.extendsClause;
      if (extendsClause == null) return;

      final String superclass = extendsClause.superclass.name.lexeme;
      if (!_isProviderClass(superclass)) return;

      // Check for BuildContext fields
      for (final ClassMember member in node.members) {
        if (member is FieldDeclaration) {
          for (final VariableDeclaration field in member.fields.variables) {
            final TypeAnnotation? type = member.fields.type;
            if (type is NamedType && type.name.lexeme == 'BuildContext') {
              reporter.atToken(field.name, code);
            }
          }
        }
      }
    });
  }

  bool _isProviderClass(String name) {
    return name == 'ChangeNotifier' ||
        name == 'ValueNotifier' ||
        name == 'StateNotifier' ||
        name == 'Notifier' ||
        name == 'AsyncNotifier' ||
        name.endsWith('Provider') ||
        name.endsWith('Notifier');
  }
}

/// Future rule: prefer-semantic-widget-names
/// Warns when widgets use generic names like Container instead of semantic alternatives.
///
/// Example of **bad** code:
/// ```dart
/// Container(
///   decoration: BoxDecoration(color: Colors.red),
///   child: child,
/// )
/// ```
///
/// Example of **good** code:
/// ```dart
/// DecoratedBox(
///   decoration: BoxDecoration(color: Colors.red),
///   child: child,
/// )
/// ```
class PreferSemanticWidgetNamesRule extends SaropaLintRule {
  const PreferSemanticWidgetNamesRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'prefer_semantic_widget_names',
    problemMessage: 'Consider using a more semantic widget.',
    correctionMessage:
        'Replace Container with a more specific widget like DecoratedBox, SizedBox, etc.',
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

      if (typeName == 'Container') {
        // Check what properties are used
        final Set<String> usedProps = <String>{};
        for (final Expression arg in node.argumentList.arguments) {
          if (arg is NamedExpression) {
            usedProps.add(arg.name.label.name);
          }
        }

        // Suggest alternatives based on usage
        if (usedProps.length == 1) {
          if (usedProps.contains('decoration')) {
            reporter.atNode(node.constructorName, code);
          } else if (usedProps.contains('width') ||
              usedProps.contains('height')) {
            reporter.atNode(node.constructorName, code);
          } else if (usedProps.contains('padding')) {
            reporter.atNode(node.constructorName, code);
          } else if (usedProps.contains('alignment')) {
            reporter.atNode(node.constructorName, code);
          }
        } else if (usedProps.length == 2 &&
            usedProps.contains('width') &&
            usedProps.contains('height')) {
          reporter.atNode(node.constructorName, code);
        }
      }
    });
  }
}

/// Future rule: avoid-text-scale-factor
/// Warns when using deprecated textScaleFactor instead of textScaler.
///
/// Example of **bad** code:
/// ```dart
/// MediaQuery.textScaleFactorOf(context);
/// MediaQuery.of(context).textScaleFactor;
/// ```
///
/// Example of **good** code:
/// ```dart
/// MediaQuery.textScalerOf(context);
/// MediaQuery.of(context).textScaler;
/// ```
class AvoidTextScaleFactorRule extends SaropaLintRule {
  const AvoidTextScaleFactorRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_text_scale_factor',
    problemMessage: 'textScaleFactor is deprecated.',
    correctionMessage: 'Use textScaler instead of textScaleFactor.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    // Check for textScaleFactorOf method calls
    context.registry.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name == 'textScaleFactorOf') {
        reporter.atNode(node.methodName, code);
      }
    });

    // Check for .textScaleFactor property access
    context.registry.addPropertyAccess((PropertyAccess node) {
      if (node.propertyName.name == 'textScaleFactor') {
        reporter.atNode(node.propertyName, code);
      }
    });
  }
}

/// Future rule: prefer-widget-state-mixin
/// Warns when State class doesn't use WidgetStateMixin for better state management.
///
/// Example of **bad** code:
/// ```dart
/// class _MyWidgetState extends State<MyWidget> {
///   bool _isHovered = false;
///   bool _isPressed = false;
/// }
/// ```
///
/// Example of **good** code:
/// ```dart
/// class _MyWidgetState extends State<MyWidget> with WidgetStateMixin<MyWidget> {
///   // Use WidgetState for hover, pressed, etc.
/// }
/// ```
class PreferWidgetStateMixinRule extends SaropaLintRule {
  const PreferWidgetStateMixinRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'prefer_widget_state_mixin',
    problemMessage: 'Consider using WidgetStateMixin for interaction states.',
    correctionMessage:
        'Use WidgetStateMixin to manage hover, pressed, and focus states.',
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

      final String superclass = extendsClause.superclass.name.lexeme;
      if (superclass != 'State') return;

      // Check if already using WidgetStateMixin
      final WithClause? withClause = node.withClause;
      if (withClause != null) {
        for (final NamedType mixin in withClause.mixinTypes) {
          if (mixin.name.lexeme.contains('WidgetStateMixin')) {
            return;
          }
        }
      }

      // Check for manual state tracking fields
      int stateFields = 0;
      for (final ClassMember member in node.members) {
        if (member is FieldDeclaration) {
          for (final VariableDeclaration field in member.fields.variables) {
            final String name = field.name.lexeme;
            if (name.contains('Hover') ||
                name.contains('hover') ||
                name.contains('Press') ||
                name.contains('press') ||
                name.contains('Focus') ||
                name.contains('focus') ||
                name == '_isHovered' ||
                name == '_isPressed' ||
                name == '_isFocused') {
              stateFields++;
            }
          }
        }
      }

      if (stateFields >= 2) {
        reporter.atToken(node.name, code);
      }
    });
  }
}

/// Future rule: avoid-image-without-cache-headers
/// Warns when Image.network is used without cacheWidth/cacheHeight.
///
/// Example of **bad** code:
/// ```dart
/// Image.network('https://example.com/image.png')
/// ```
///
/// Example of **good** code:
/// ```dart
/// Image.network(
///   'https://example.com/image.png',
///   cacheWidth: 200,
///   cacheHeight: 200,
/// )
/// ```
class AvoidImageWithoutCacheRule extends SaropaLintRule {
  const AvoidImageWithoutCacheRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_image_without_cache',
    problemMessage:
        'Image.network should specify cacheWidth/cacheHeight for memory efficiency.',
    correctionMessage: 'Add cacheWidth and/or cacheHeight parameters.',
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

      if (typeName == 'Image' && constructorName == 'network') {
        // Check for cacheWidth/cacheHeight
        bool hasCacheWidth = false;
        bool hasCacheHeight = false;

        for (final Expression arg in node.argumentList.arguments) {
          if (arg is NamedExpression) {
            final String name = arg.name.label.name;
            if (name == 'cacheWidth') hasCacheWidth = true;
            if (name == 'cacheHeight') hasCacheHeight = true;
          }
        }

        if (!hasCacheWidth && !hasCacheHeight) {
          reporter.atNode(node.constructorName, code);
        }
      }
    });
  }
}

/// Future rule: prefer-split-widget-const
/// Warns when large widget trees should be split into const widgets.
///
/// Example of **bad** code:
/// ```dart
/// Column(
///   children: [
///     Text('Title'),
///     Text('Subtitle'),
///     Icon(Icons.star),
///   ],
/// )
/// ```
///
/// Example of **good** code:
/// ```dart
/// const _TitleSection();
/// // or extract to const widget
/// ```
class PreferSplitWidgetConstRule extends SaropaLintRule {
  const PreferSplitWidgetConstRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'prefer_split_widget_const',
    problemMessage:
        'Large widget subtree could be extracted to a const widget.',
    correctionMessage:
        'Extract this subtree to a separate const widget for better performance.',
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

      // Check common container widgets
      if (typeName == 'Column' || typeName == 'Row' || typeName == 'Stack') {
        // Count nested widgets
        int widgetCount = 0;
        node.visitChildren(_WidgetCounter((int count) => widgetCount = count));

        // If more than 5 nested widgets, suggest splitting
        if (widgetCount > 5) {
          reporter.atNode(node.constructorName, code);
        }
      }
    });
  }
}

class _WidgetCounter extends RecursiveAstVisitor<void> {
  _WidgetCounter(this.onCount);
  final void Function(int) onCount;
  int _count = 0;

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    _count++;
    onCount(_count);
    super.visitInstanceCreationExpression(node);
  }
}

/// Future rule: avoid-navigator-push-without-route-name
/// Warns when Navigator.push is used without a route name.
///
/// Example of **bad** code:
/// ```dart
/// Navigator.push(
///   context,
///   MaterialPageRoute(builder: (_) => NextPage()),
/// );
/// ```
///
/// Example of **good** code:
/// ```dart
/// Navigator.pushNamed(context, '/next');
/// // or use go_router/auto_route
/// ```
class AvoidNavigatorPushWithoutRouteNameRule extends SaropaLintRule {
  const AvoidNavigatorPushWithoutRouteNameRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_navigator_push_without_route_name',
    problemMessage: 'Prefer named routes for better navigation management.',
    correctionMessage: 'Use Navigator.pushNamed or a routing package.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      final Expression? target = node.target;
      if (target is SimpleIdentifier && target.name == 'Navigator') {
        final String methodName = node.methodName.name;
        if (methodName == 'push' ||
            methodName == 'pushReplacement' ||
            methodName == 'pushAndRemoveUntil') {
          reporter.atNode(node.methodName, code);
        }
      }
    });
  }
}

/// Future rule: avoid-duplicate-keys-in-widget-list
/// Warns when widgets in a list have duplicate keys.
///
/// Example of **bad** code:
/// ```dart
/// [
///   Container(key: Key('item')),
///   Container(key: Key('item')),  // Duplicate key
/// ]
/// ```
///
/// Example of **good** code:
/// ```dart
/// [
///   Container(key: Key('item1')),
///   Container(key: Key('item2')),
/// ]
/// ```
class AvoidDuplicateWidgetKeysRule extends SaropaLintRule {
  const AvoidDuplicateWidgetKeysRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_duplicate_widget_keys',
    problemMessage: 'Duplicate widget keys found in list.',
    correctionMessage: 'Ensure each widget in a list has a unique key.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addListLiteral((ListLiteral node) {
      final Map<String, List<AstNode>> keyValues = <String, List<AstNode>>{};

      for (final CollectionElement element in node.elements) {
        if (element is InstanceCreationExpression) {
          // Find key argument
          for (final Expression arg in element.argumentList.arguments) {
            if (arg is NamedExpression && arg.name.label.name == 'key') {
              final String? keyString = _extractKeyString(arg.expression);
              if (keyString != null) {
                keyValues.putIfAbsent(keyString, () => <AstNode>[]).add(arg);
              }
            }
          }
        }
      }

      // Report duplicates
      for (final List<AstNode> nodes in keyValues.values) {
        if (nodes.length > 1) {
          for (final AstNode keyNode in nodes) {
            reporter.atNode(keyNode, code);
          }
        }
      }
    });
  }

  String? _extractKeyString(Expression expr) {
    if (expr is InstanceCreationExpression) {
      final NodeList<Expression> args = expr.argumentList.arguments;
      if (args.isNotEmpty && args.first is StringLiteral) {
        return (args.first as StringLiteral).stringValue;
      }
    } else if (expr is MethodInvocation && expr.methodName.name == 'ValueKey') {
      final NodeList<Expression> args = expr.argumentList.arguments;
      if (args.isNotEmpty && args.first is StringLiteral) {
        return (args.first as StringLiteral).stringValue;
      }
    }
    return null;
  }
}

/// Future rule: prefer-safe-area-consumer
/// Warns when SafeArea is used without considering when it's unnecessary.
///
/// Example of **bad** code:
/// ```dart
/// Scaffold(
///   body: SafeArea(  // Scaffold already handles safe area
///     child: ListView(...),
///   ),
/// )
/// ```
///
/// Example of **good** code:
/// ```dart
/// Scaffold(
///   body: ListView(...),  // Scaffold handles safe area via appBar, bottomNavigationBar
/// )
/// ```
class PreferSafeAreaConsumerRule extends SaropaLintRule {
  const PreferSafeAreaConsumerRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'prefer_safe_area_consumer',
    problemMessage:
        'SafeArea may be redundant when used directly inside Scaffold body.',
    correctionMessage:
        'Scaffold already handles safe areas via its appBar and bottomNavigationBar properties.',
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

      if (typeName == 'Scaffold') {
        // Check body argument
        for (final Expression arg in node.argumentList.arguments) {
          if (arg is NamedExpression && arg.name.label.name == 'body') {
            if (arg.expression is InstanceCreationExpression) {
              final InstanceCreationExpression bodyExpr =
                  arg.expression as InstanceCreationExpression;
              if (bodyExpr.constructorName.type.name.lexeme == 'SafeArea') {
                reporter.atNode(bodyExpr.constructorName, code);
              }
            }
          }
        }
      }
    });
  }
}

/// Future rule: avoid-unrestricted-text-field-length
/// Warns when TextField doesn't have maxLength set.
///
/// Example of **bad** code:
/// ```dart
/// TextField(controller: _controller)
/// ```
///
/// Example of **good** code:
/// ```dart
/// TextField(
///   controller: _controller,
///   maxLength: 500,
/// )
/// ```
class AvoidUnrestrictedTextFieldLengthRule extends SaropaLintRule {
  const AvoidUnrestrictedTextFieldLengthRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_unrestricted_text_field_length',
    problemMessage:
        'TextField should have maxLength to prevent excessive input.',
    correctionMessage: 'Add maxLength parameter to limit input length.',
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

      if (typeName == 'TextField' || typeName == 'TextFormField') {
        bool hasMaxLength = false;

        for (final Expression arg in node.argumentList.arguments) {
          if (arg is NamedExpression && arg.name.label.name == 'maxLength') {
            hasMaxLength = true;
            break;
          }
        }

        if (!hasMaxLength) {
          reporter.atNode(node.constructorName, code);
        }
      }
    });
  }
}

/// Future rule: prefer-scaffold-messenger-maybeof
/// Warns when ScaffoldMessenger.of is used instead of maybeOf.
///
/// Example of **bad** code:
/// ```dart
/// ScaffoldMessenger.of(context).showSnackBar(...);
/// ```
///
/// Example of **good** code:
/// ```dart
/// ScaffoldMessenger.maybeOf(context)?.showSnackBar(...);
/// ```
class PreferScaffoldMessengerMaybeOfRule extends SaropaLintRule {
  const PreferScaffoldMessengerMaybeOfRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'prefer_scaffold_messenger_maybeof',
    problemMessage:
        'Consider using ScaffoldMessenger.maybeOf for safer access.',
    correctionMessage:
        'Use maybeOf to handle cases where ScaffoldMessenger might not be available.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      final Expression? target = node.target;
      if (target is SimpleIdentifier &&
          target.name == 'ScaffoldMessenger' &&
          node.methodName.name == 'of') {
        reporter.atNode(node.methodName, code);
      }
    });
  }
}

/// Future rule: avoid-form-without-key
/// Warns when Form widget doesn't have a GlobalKey.
///
/// Example of **bad** code:
/// ```dart
/// Form(
///   child: Column(...),
/// )
/// ```
///
/// Example of **good** code:
/// ```dart
/// Form(
///   key: _formKey,
///   child: Column(...),
/// )
/// ```
class AvoidFormWithoutKeyRule extends SaropaLintRule {
  const AvoidFormWithoutKeyRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_form_without_key',
    problemMessage: 'Form widget should have a GlobalKey for validation.',
    correctionMessage: 'Add a GlobalKey<FormState> to the Form widget.',
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

      if (typeName == 'Form') {
        bool hasKey = false;

        for (final Expression arg in node.argumentList.arguments) {
          if (arg is NamedExpression && arg.name.label.name == 'key') {
            hasKey = true;
            break;
          }
        }

        if (!hasKey) {
          reporter.atNode(node.constructorName, code);
        }
      }
    });
  }
}

/// Future rule: avoid-listview-without-item-extent
/// Warns when ListView doesn't specify itemExtent for better performance.
///
/// Example of **bad** code:
/// ```dart
/// ListView.builder(
///   itemBuilder: (context, index) => ListTile(...),
/// )
/// ```
///
/// Example of **good** code:
/// ```dart
/// ListView.builder(
///   itemExtent: 72.0,
///   itemBuilder: (context, index) => ListTile(...),
/// )
/// ```
class AvoidListViewWithoutItemExtentRule extends SaropaLintRule {
  const AvoidListViewWithoutItemExtentRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_listview_without_item_extent',
    problemMessage:
        'ListView.builder should specify itemExtent for better scroll performance.',
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
class AvoidMediaQueryInBuildRule extends SaropaLintRule {
  const AvoidMediaQueryInBuildRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_mediaquery_in_build',
    problemMessage: 'Use specific MediaQuery methods instead of MediaQuery.of.',
    correctionMessage:
        'Use MediaQuery.sizeOf, MediaQuery.paddingOf, etc. for better performance.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      final Expression? target = node.target;
      if (target is SimpleIdentifier &&
          target.name == 'MediaQuery' &&
          node.methodName.name == 'of') {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Future rule: prefer-sliver-list-delegate
/// Warns when SliverList uses children instead of delegate for large lists.
///
/// Example of **bad** code:
/// ```dart
/// SliverList(
///   delegate: SliverChildListDelegate([...100 items...]),
/// )
/// ```
///
/// Example of **good** code:
/// ```dart
/// SliverList(
///   delegate: SliverChildBuilderDelegate(
///     (context, index) => Item(items[index]),
///     childCount: items.length,
///   ),
/// )
/// ```
class PreferSliverListDelegateRule extends SaropaLintRule {
  const PreferSliverListDelegateRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'prefer_sliver_list_delegate',
    problemMessage:
        'Use SliverChildBuilderDelegate for better performance with large lists.',
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

  static const LintCode _code = LintCode(
    name: 'avoid_layout_builder_misuse',
    problemMessage: 'LayoutBuilder should use constraints in its builder.',
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

  static const LintCode _code = LintCode(
    name: 'avoid_repaint_boundary_misuse',
    problemMessage:
        'RepaintBoundary around const/static content provides no benefit.',
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

  // cspell: ignore singlechildscrollview
  static const LintCode _code = LintCode(
    name: 'avoid_singlechildscrollview_with_column',
    problemMessage:
        'SingleChildScrollView with Column may cause layout issues.',
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
class PreferCachedNetworkImageRule extends SaropaLintRule {
  const PreferCachedNetworkImageRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'prefer_cached_network_image',
    problemMessage: 'Consider using CachedNetworkImage for better caching.',
    correctionMessage: 'Replace Image.network with CachedNetworkImage package.',
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

      if (typeName == 'Image' && constructorName == 'network') {
        reporter.atNode(node.constructorName, code);
      }
    });
  }
}

/// Future rule: avoid-gesture-detector-in-scrollview
/// Warns when GestureDetector is used around a scrollable widget.
///
/// Example of **bad** code:
/// ```dart
/// GestureDetector(
///   onTap: () {},
///   child: ListView(...),  // Conflicts with scroll gestures
/// )
/// ```
///
/// Example of **good** code:
/// ```dart
/// ListView(
///   children: [
///     GestureDetector(onTap: () {}, child: ListItem()),
///   ],
/// )
/// ```
class AvoidGestureDetectorInScrollViewRule extends SaropaLintRule {
  const AvoidGestureDetectorInScrollViewRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_gesture_detector_in_scrollview',
    problemMessage:
        'GestureDetector around scrollable can cause gesture conflicts.',
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
class AvoidStatefulWidgetInListRule extends SaropaLintRule {
  const AvoidStatefulWidgetInListRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_stateful_widget_in_list',
    problemMessage:
        'Creating StatefulWidget in list builder can cause state loss.',
    correctionMessage: 'Use keys or consider StatelessWidget for list items.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    // This would need type resolution to check if widget extends StatefulWidget
    // For now, we'll check for common patterns
    context.registry.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name != 'builder') return;

      final Expression? target = node.target;
      if (target is! SimpleIdentifier) return;
      if (target.name != 'ListView' && target.name != 'GridView') return;

      // Check itemBuilder argument
      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression && arg.name.label.name == 'itemBuilder') {
          // Check if builder creates widgets without keys
          final Expression builderExpr = arg.expression;
          if (builderExpr is FunctionExpression) {
            final FunctionBody body = builderExpr.body;
            if (body is ExpressionFunctionBody) {
              final Expression expr = body.expression;
              if (expr is InstanceCreationExpression) {
                // Check if key is provided
                bool hasKey = false;
                for (final Expression argExpr in expr.argumentList.arguments) {
                  if (argExpr is NamedExpression &&
                      argExpr.name.label.name == 'key') {
                    hasKey = true;
                    break;
                  }
                }
                if (!hasKey) {
                  // Warn for any widget without key in list builder
                  reporter.atNode(expr.constructorName, code);
                }
              }
            }
          }
        }
      }
    });
  }
}

/// Future rule: prefer-opacity-over-color-alpha
/// Warns when Color.withAlpha/withOpacity is used instead of Opacity widget.
///
/// Example of **bad** code:
/// ```dart
/// Container(
///   color: Colors.red.withOpacity(0.5),
///   child: ExpensiveWidget(),  // Still fully rendered
/// )
/// ```
///
/// Example of **good** code:
/// ```dart
/// Opacity(
///   opacity: 0.5,
///   child: Container(
///     color: Colors.red,
///     child: ExpensiveWidget(),
///   ),
/// )
/// // Or better, use AnimatedOpacity for animations
/// ```
class PreferOpacityWidgetRule extends SaropaLintRule {
  const PreferOpacityWidgetRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'prefer_opacity_widget',
    problemMessage: 'Consider using Opacity widget for complex child widgets.',
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
class AvoidInheritedWidgetInInitStateRule extends SaropaLintRule {
  const AvoidInheritedWidgetInInitStateRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_inherited_widget_in_initstate',
    problemMessage: 'Avoid accessing InheritedWidget in initState.',
    correctionMessage: 'Use didChangeDependencies instead.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  static const Set<String> _inheritedWidgetMethods = <String>{
    'of',
    'maybeOf',
    'dependOnInheritedWidgetOfExactType',
  };

  static const Set<String> _commonInheritedWidgets = <String>{
    'Theme',
    'MediaQuery',
    'Navigator',
    'Scaffold',
    'DefaultTextStyle',
    'Localizations',
    'Provider',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodDeclaration((MethodDeclaration node) {
      if (node.name.lexeme != 'initState') return;

      // Visit the method body to find inherited widget access
      node.body.accept(_InheritedWidgetVisitor(reporter, code));
    });
  }
}

class _InheritedWidgetVisitor extends RecursiveAstVisitor<void> {
  _InheritedWidgetVisitor(this.reporter, this.code);

  final SaropaDiagnosticReporter reporter;
  final LintCode code;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    super.visitMethodInvocation(node);

    final String methodName = node.methodName.name;
    if (!AvoidInheritedWidgetInInitStateRule._inheritedWidgetMethods
        .contains(methodName)) {
      return;
    }

    // Check if target is a common inherited widget
    final Expression? target = node.target;
    if (target is SimpleIdentifier) {
      if (AvoidInheritedWidgetInInitStateRule._commonInheritedWidgets
          .contains(target.name)) {
        reporter.atNode(node, code);
      }
    }
  }
}

/// Warns when a widget references itself in its build method.
///
/// Example of **bad** code:
/// ```dart
/// class MyWidget extends StatelessWidget {
///   @override
///   Widget build(BuildContext context) {
///     return MyWidget(); // Infinite recursion
///   }
/// }
/// ```
class AvoidRecursiveWidgetCallsRule extends SaropaLintRule {
  const AvoidRecursiveWidgetCallsRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_recursive_widget_calls',
    problemMessage:
        'Widget creates instance of itself, causing infinite recursion.',
    correctionMessage: 'Remove the recursive widget instantiation.',
    errorSeverity: DiagnosticSeverity.ERROR,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
      final String className = node.name.lexeme;

      // Check if it's a widget class
      final ExtendsClause? extendsClause = node.extendsClause;
      if (extendsClause == null) return;

      final String superclassName = extendsClause.superclass.name.lexeme;
      if (superclassName != 'StatelessWidget' &&
          superclassName != 'StatefulWidget') {
        return;
      }

      // Find build method
      for (final ClassMember member in node.members) {
        if (member is MethodDeclaration && member.name.lexeme == 'build') {
          // Check for self-instantiation in build
          member.body
              .accept(_RecursiveWidgetVisitor(className, reporter, code));
        }
      }
    });
  }
}

class _RecursiveWidgetVisitor extends RecursiveAstVisitor<void> {
  _RecursiveWidgetVisitor(this.className, this.reporter, this.code);

  final String className;
  final SaropaDiagnosticReporter reporter;
  final LintCode code;

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    super.visitInstanceCreationExpression(node);

    final String typeName = node.constructorName.type.name.lexeme;
    if (typeName == className) {
      reporter.atNode(node, code);
    }
  }
}

/// Warns when disposable instances are created but not disposed.
///
/// Example of **bad** code:
/// ```dart
/// class MyWidget extends StatefulWidget {
///   @override
///   _MyWidgetState createState() => _MyWidgetState();
/// }
///
/// class _MyWidgetState extends State<MyWidget> {
///   late final controller = TextEditingController(); // Not disposed
/// }
/// ```
class AvoidUndisposedInstancesRule extends SaropaLintRule {
  const AvoidUndisposedInstancesRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_undisposed_instances',
    problemMessage: 'Disposable instance may not be properly disposed.',
    correctionMessage: 'Call dispose() in the dispose method.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  static const Set<String> _disposableTypes = <String>{
    'TextEditingController',
    'AnimationController',
    'ScrollController',
    'PageController',
    'TabController',
    'FocusNode',
    'StreamController',
    'StreamSubscription',
    'Timer',
  };

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

      // Find disposable fields
      final Set<String> disposableFields = <String>{};
      final Set<String> disposedFields = <String>{};

      // Collect all method bodies for helper method analysis
      final Map<String, FunctionBody?> methodBodies = <String, FunctionBody?>{};

      for (final ClassMember member in node.members) {
        if (member is FieldDeclaration) {
          for (final VariableDeclaration variable in member.fields.variables) {
            final String fieldName = variable.name.lexeme;
            final Expression? initializer = variable.initializer;

            // Check if field is a disposable type
            if (initializer is InstanceCreationExpression) {
              final String typeName =
                  initializer.constructorName.type.name.lexeme;
              if (_disposableTypes.contains(typeName)) {
                disposableFields.add(fieldName);
              }
            }

            // Check type annotation (handles nullable types like Timer?)
            final TypeAnnotation? typeAnnotation = member.fields.type;
            if (typeAnnotation is NamedType) {
              if (_disposableTypes.contains(typeAnnotation.name2.lexeme)) {
                disposableFields.add(fieldName);
              }
            }
          }
        }

        // Collect all method bodies
        if (member is MethodDeclaration) {
          methodBodies[member.name.lexeme] = member.body;
        }
      }

      // Find dispose method and track what's disposed (including helper methods)
      final FunctionBody? disposeBody = methodBodies['dispose'];
      if (disposeBody != null) {
        final _DisposeVisitor visitor = _DisposeVisitor(
          disposedFields: disposedFields,
          methodBodies: methodBodies,
        );
        disposeBody.accept(visitor);
      }

      // Report undisposed fields
      for (final String fieldName in disposableFields) {
        if (!disposedFields.contains(fieldName)) {
          // Find the field declaration to report on
          for (final ClassMember member in node.members) {
            if (member is FieldDeclaration) {
              for (final VariableDeclaration variable
                  in member.fields.variables) {
                if (variable.name.lexeme == fieldName) {
                  reporter.atNode(variable, code);
                }
              }
            }
          }
        }
      }
    });
  }
}

class _DisposeVisitor extends RecursiveAstVisitor<void> {
  _DisposeVisitor({
    required this.disposedFields,
    required this.methodBodies,
    Set<String>? visitedMethods,
  }) : _visitedMethods = visitedMethods ?? <String>{};

  final Set<String> disposedFields;
  final Map<String, FunctionBody?> methodBodies;
  final Set<String> _visitedMethods;

  static const Set<String> _disposeMethodNames = <String>{
    'dispose',
    'disposeSafe',
    'cancel',
    'cancelSafe',
    'close',
    'closeSafe',
  };

  @override
  void visitMethodInvocation(MethodInvocation node) {
    super.visitMethodInvocation(node);

    final String methodName = node.methodName.name;

    // Check if this is a disposal method call on a field
    if (_disposeMethodNames.contains(methodName)) {
      final Expression? target = node.target;
      _extractFieldName(target);
    }

    // Check if this is a call to a helper method within the same class
    // (no target means it's a call to a method in the same class)
    if (node.target == null && !_visitedMethods.contains(methodName)) {
      final FunctionBody? helperBody = methodBodies[methodName];
      if (helperBody != null) {
        _visitedMethods.add(methodName);
        // Visit the helper method body to find disposals there
        helperBody.accept(
          _DisposeVisitor(
            disposedFields: disposedFields,
            methodBodies: methodBodies,
            visitedMethods: _visitedMethods,
          ),
        );
      }
    }
  }

  /// Extracts the field name from various target expression types.
  void _extractFieldName(Expression? target) {
    if (target == null) return;

    // Handle simple field access: _controller.dispose() or _timer?.cancel()
    if (target is SimpleIdentifier) {
      disposedFields.add(target.name);
    }
    // Handle prefixed access: this._controller.dispose()
    else if (target is PrefixedIdentifier) {
      disposedFields.add(target.identifier.name);
    }
    // Handle property access: this._controller.dispose() (alternate AST)
    else if (target is PropertyAccess) {
      disposedFields.add(target.propertyName.name);
    }
    // Handle parenthesized expressions: (_controller).dispose()
    else if (target is ParenthesizedExpression) {
      _extractFieldName(target.expression);
    }
    // Handle cascade: _controller..dispose()
    else if (target is CascadeExpression) {
      _extractFieldName(target.target);
    }
  }
}

/// Warns when State class has unnecessary overrides.
///
/// Example of **bad** code:
/// ```dart
/// class _MyState extends State<MyWidget> {
///   @override
///   void initState() {
///     super.initState(); // Only calls super
///   }
/// }
/// ```
class AvoidUnnecessaryOverridesInStateRule extends SaropaLintRule {
  const AvoidUnnecessaryOverridesInStateRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_unnecessary_overrides_in_state',
    problemMessage: 'Override only calls super with no additional logic.',
    correctionMessage: 'Remove the unnecessary override.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  static const Set<String> _lifecycleMethods = <String>{
    'initState',
    'dispose',
    'didChangeDependencies',
    'didUpdateWidget',
    'deactivate',
    'activate',
  };

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

      for (final ClassMember member in node.members) {
        if (member is MethodDeclaration) {
          final String methodName = member.name.lexeme;
          if (!_lifecycleMethods.contains(methodName)) continue;

          // Check if body only contains super call
          final FunctionBody body = member.body;
          if (body is BlockFunctionBody) {
            final Block block = body.block;
            if (block.statements.length == 1) {
              final Statement stmt = block.statements.first;
              if (stmt is ExpressionStatement) {
                final Expression expr = stmt.expression;
                if (expr is MethodInvocation) {
                  if (expr.target is SuperExpression &&
                      expr.methodName.name == methodName) {
                    reporter.atNode(member, code);
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

/// Warns when fields that need disposal are not disposed.
///
/// Example of **bad** code:
/// ```dart
/// class _MyState extends State<MyWidget> {
///   final _controller = TextEditingController();
///   // Missing dispose() override
/// }
/// ```
class DisposeFieldsRule extends SaropaLintRule {
  const DisposeFieldsRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'dispose_fields',
    problemMessage:
        'Field requires disposal but dispose method is missing or incomplete.',
    correctionMessage: 'Add dispose method and call dispose on this field.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  static const Set<String> _disposableTypes = <String>{
    'TextEditingController',
    'AnimationController',
    'ScrollController',
    'PageController',
    'TabController',
    'FocusNode',
    'StreamController',
  };

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

      // Find disposable fields
      final List<VariableDeclaration> disposableFields =
          <VariableDeclaration>[];
      bool hasDisposeMethod = false;

      for (final ClassMember member in node.members) {
        if (member is FieldDeclaration) {
          for (final VariableDeclaration variable in member.fields.variables) {
            final Expression? initializer = variable.initializer;
            if (initializer is InstanceCreationExpression) {
              final String typeName =
                  initializer.constructorName.type.name.lexeme;
              if (_disposableTypes.contains(typeName)) {
                disposableFields.add(variable);
              }
            }
          }
        }

        if (member is MethodDeclaration && member.name.lexeme == 'dispose') {
          hasDisposeMethod = true;
        }
      }

      // Report if there are disposable fields but no dispose method
      if (disposableFields.isNotEmpty && !hasDisposeMethod) {
        for (final VariableDeclaration field in disposableFields) {
          reporter.atNode(field, code);
        }
      }
    });
  }
}

/// Warns when a new Future is created inside FutureBuilder.
///
/// Example of **bad** code:
/// ```dart
/// FutureBuilder(
///   future: fetchData(), // Creates new future on every build
///   builder: (context, snapshot) => ...,
/// )
/// ```
///
/// Example of **good** code:
/// ```dart
/// late final Future<Data> _dataFuture = fetchData();
///
/// FutureBuilder(
///   future: _dataFuture,
///   builder: (context, snapshot) => ...,
/// )
/// ```
class PassExistingFutureToFutureBuilderRule extends SaropaLintRule {
  const PassExistingFutureToFutureBuilderRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'pass_existing_future_to_future_builder',
    problemMessage: 'Creating new Future in FutureBuilder causes rebuilds.',
    correctionMessage:
        'Store the Future in a field and pass it to the builder.',
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
      if (typeName != 'FutureBuilder') return;

      // Check future argument
      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression && arg.name.label.name == 'future') {
          final Expression value = arg.expression;

          // Warn if future is a method invocation (creating new future)
          if (value is MethodInvocation) {
            reporter.atNode(value, code);
          }

          // Warn if future is a function expression
          if (value is FunctionExpression) {
            reporter.atNode(value, code);
          }
        }
      }
    });
  }
}

/// Warns when a new Stream is created inside StreamBuilder.
///
/// Example of **bad** code:
/// ```dart
/// StreamBuilder(
///   stream: getDataStream(), // Creates new stream on every build
///   builder: (context, snapshot) => ...,
/// )
/// ```
///
/// Example of **good** code:
/// ```dart
/// late final Stream<Data> _dataStream = getDataStream();
///
/// StreamBuilder(
///   stream: _dataStream,
///   builder: (context, snapshot) => ...,
/// )
/// ```
class PassExistingStreamToStreamBuilderRule extends SaropaLintRule {
  const PassExistingStreamToStreamBuilderRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'pass_existing_stream_to_stream_builder',
    problemMessage: 'Creating new Stream in StreamBuilder causes rebuilds.',
    correctionMessage:
        'Store the Stream in a field and pass it to the builder.',
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
      if (typeName != 'StreamBuilder') return;

      // Check stream argument
      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression && arg.name.label.name == 'stream') {
          final Expression value = arg.expression;

          // Warn if stream is a method invocation (creating new stream)
          if (value is MethodInvocation) {
            reporter.atNode(value, code);
          }

          // Warn if stream is a function expression
          if (value is FunctionExpression) {
            reporter.atNode(value, code);
          }
        }
      }
    });
  }
}

/// Warns when Text widget is created with an empty string.
///
/// Empty Text widgets consume resources without displaying anything.
/// Use SizedBox.shrink() or remove the widget entirely.
///
/// Example of **bad** code:
/// ```dart
/// Text('')
/// Text("")
/// Text('', style: TextStyle())
/// ```
///
/// Example of **good** code:
/// ```dart
/// SizedBox.shrink()
/// // Or simply remove the widget
/// if (text.isNotEmpty) Text(text)
/// ```
class AvoidEmptyTextWidgetsRule extends SaropaLintRule {
  const AvoidEmptyTextWidgetsRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_empty_text_widgets',
    problemMessage: 'Avoid using Text widget with empty string.',
    correctionMessage:
        'Use SizedBox.shrink() or remove the widget if no text is needed.',
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
      if (typeName != 'Text') return;

      final NodeList<Expression> args = node.argumentList.arguments;
      if (args.isEmpty) return;

      // First argument should be the text string
      final Expression firstArg = args.first;
      if (firstArg is NamedExpression) return; // Skip if no positional arg

      // Check for empty string literal
      if (firstArg is SimpleStringLiteral && firstArg.value.isEmpty) {
        reporter.atNode(node, code);
      } else if (firstArg is StringInterpolation &&
          firstArg.elements.length == 1 &&
          firstArg.elements.first is InterpolationString) {
        final InterpolationString str =
            firstArg.elements.first as InterpolationString;
        if (str.value.isEmpty) {
          reporter.atNode(node, code);
        }
      }
    });
  }

  @override
  List<Fix> getFixes() => <Fix>[_ReplaceEmptyTextWithSizedBoxFix()];
}

class _ReplaceEmptyTextWithSizedBoxFix extends DartFix {
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
      if (typeName != 'Text') return;

      final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
        message: 'Replace with SizedBox.shrink()',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        builder.addSimpleReplacement(
          node.sourceRange,
          'const SizedBox.shrink()',
        );
      });
    });
  }
}

/// Warns when FontWeight is specified using numeric w-values instead of named constants.
///
/// While FontWeight supports w100-w900 numeric values, using named constants
/// like FontWeight.normal or FontWeight.bold is more readable.
///
/// Example of **bad** code:
/// ```dart
/// TextStyle(fontWeight: FontWeight.w400)
/// TextStyle(fontWeight: FontWeight.w700)
/// ```
///
/// Example of **good** code:
/// ```dart
/// TextStyle(fontWeight: FontWeight.normal)  // w400
/// TextStyle(fontWeight: FontWeight.bold)    // w700
/// ```
class AvoidFontWeightAsNumberRule extends SaropaLintRule {
  const AvoidFontWeightAsNumberRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_font_weight_as_number',
    problemMessage: 'Use named FontWeight constants instead of numeric values.',
    correctionMessage:
        'Replace FontWeight.w400 with FontWeight.normal, w700 with FontWeight.bold, etc.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  /// Mapping of numeric values to named constants
  static const Map<String, String> _weightMapping = <String, String>{
    'w400': 'normal',
    'w700': 'bold',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addPrefixedIdentifier((PrefixedIdentifier node) {
      if (node.prefix.name != 'FontWeight') return;

      final String identifier = node.identifier.name;
      if (_weightMapping.containsKey(identifier)) {
        reporter.atNode(node, code);
      }
    });
  }

  @override
  List<Fix> getFixes() => <Fix>[_ReplaceFontWeightNumberFix()];
}

class _ReplaceFontWeightNumberFix extends DartFix {
  static const Map<String, String> _weightMapping = <String, String>{
    'w400': 'normal',
    'w700': 'bold',
  };

  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    context.registry.addPrefixedIdentifier((PrefixedIdentifier node) {
      if (!node.sourceRange.intersects(analysisError.sourceRange)) return;
      if (node.prefix.name != 'FontWeight') return;

      final String identifier = node.identifier.name;
      final String? replacement = _weightMapping[identifier];
      if (replacement == null) return;

      final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
        message: 'Replace with FontWeight.$replacement',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        builder.addSimpleReplacement(
          node.sourceRange,
          'FontWeight.$replacement',
        );
      });
    });
  }
}

/// Warns when Container is used only for whitespace/spacing.
///
/// SizedBox is more efficient than Container when you only need to add
/// spacing. Container has additional overhead from decoration handling.
///
/// Example of **bad** code:
/// ```dart
/// Container(width: 16)
/// Container(height: 8)
/// Container(width: 10, height: 10)
/// ```
///
/// Example of **good** code:
/// ```dart
/// SizedBox(width: 16)
/// SizedBox(height: 8)
/// SizedBox.square(dimension: 10)
/// ```
class PreferSizedBoxForWhitespaceRule extends SaropaLintRule {
  const PreferSizedBoxForWhitespaceRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'prefer_sized_box_for_whitespace',
    problemMessage: 'Use SizedBox instead of Container for whitespace.',
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

  static const LintCode _code = LintCode(
    name: 'avoid_nested_scaffolds',
    problemMessage: 'Avoid nesting Scaffold widgets inside other Scaffolds.',
    correctionMessage:
        'Remove the inner Scaffold and use its content directly.',
    errorSeverity: DiagnosticSeverity.ERROR,
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
class AvoidMultipleMaterialAppsRule extends SaropaLintRule {
  const AvoidMultipleMaterialAppsRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_multiple_material_apps',
    problemMessage: 'Multiple MaterialApp widgets detected in widget tree.',
    correctionMessage:
        'Use only one MaterialApp at the root of your application.',
    errorSeverity: DiagnosticSeverity.ERROR,
  );

  static const Set<String> _appWidgets = <String>{
    'MaterialApp',
    'CupertinoApp',
    'WidgetsApp',
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
      if (!_appWidgets.contains(typeName)) return;

      // Check if any parent is also an App widget
      if (_hasAppAncestor(node)) {
        reporter.atNode(node.constructorName, code);
      }
    });
  }

  bool _hasAppAncestor(AstNode node) {
    AstNode? current = node.parent;
    while (current != null) {
      if (current is InstanceCreationExpression) {
        final String typeName = current.constructorName.type.name.lexeme;
        if (_appWidgets.contains(typeName)) {
          return true;
        }
      }
      current = current.parent;
    }
    return false;
  }
}

/// Warns when deprecated RawKeyboardListener is used.
///
/// RawKeyboardListener is deprecated. Use KeyboardListener or Focus widget
/// with onKeyEvent instead.
///
/// Example of **bad** code:
/// ```dart
/// RawKeyboardListener(
///   focusNode: _focusNode,
///   onKey: (event) { },
///   child: child,
/// )
/// ```
///
/// Example of **good** code:
/// ```dart
/// KeyboardListener(
///   focusNode: _focusNode,
///   onKeyEvent: (event) { },
///   child: child,
/// )
/// ```
class AvoidRawKeyboardListenerRule extends SaropaLintRule {
  const AvoidRawKeyboardListenerRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_raw_keyboard_listener',
    problemMessage:
        'RawKeyboardListener is deprecated. Use KeyboardListener instead.',
    correctionMessage:
        'Replace RawKeyboardListener with KeyboardListener or Focus.',
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
      if (typeName == 'RawKeyboardListener') {
        reporter.atNode(node.constructorName, code);
      }
    });
  }

  @override
  List<Fix> getFixes() => <Fix>[_ReplaceRawKeyboardListenerFix()];
}

class _ReplaceRawKeyboardListenerFix extends DartFix {
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
      if (typeName != 'RawKeyboardListener') return;

      final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
        message: 'Replace with KeyboardListener',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        builder.addSimpleReplacement(
          node.constructorName.type.sourceRange,
          'KeyboardListener',
        );
      });
    });
  }
}

/// Warns when ImageRepeat is used on Image widgets.
///
/// ImageRepeat is rarely needed and often indicates a design issue.
/// Consider using a pattern image or tiled background instead.
///
/// Example of **bad** code:
/// ```dart
/// Image.asset(
///   'image.png',
///   repeat: ImageRepeat.repeat,
/// )
/// ```
///
/// Example of **good** code:
/// ```dart
/// Image.asset('image.png')
/// ```
class AvoidImageRepeatRule extends SaropaLintRule {
  const AvoidImageRepeatRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_image_repeat',
    problemMessage:
        'ImageRepeat is rarely needed and may indicate a design issue.',
    correctionMessage: 'Consider removing repeat or using a pattern approach.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addPrefixedIdentifier((PrefixedIdentifier node) {
      if (node.prefix.name == 'ImageRepeat' &&
          node.identifier.name != 'noRepeat') {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when Icon widget has explicit size override.
///
/// Instead of overriding icon size on individual Icon widgets,
/// use IconTheme to set consistent sizing.
///
/// Example of **bad** code:
/// ```dart
/// Icon(Icons.home, size: 24)
/// ```
///
/// Example of **good** code:
/// ```dart
/// IconTheme(
///   data: IconThemeData(size: 24),
///   child: Icon(Icons.home),
/// )
/// ```
class AvoidIconSizeOverrideRule extends SaropaLintRule {
  const AvoidIconSizeOverrideRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_icon_size_override',
    problemMessage: 'Avoid overriding icon size directly. Use IconTheme.',
    correctionMessage: 'Wrap icons in IconTheme for consistent sizing.',
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
      if (typeName != 'Icon') return;

      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression && arg.name.label.name == 'size') {
          reporter.atNode(arg, code);
          return;
        }
      }
    });
  }
}

/// Warns when GestureDetector is used with only onTap.
///
/// For simple tap interactions with Material design feedback,
/// InkWell provides better UX with ripple effects.
///
/// Example of **bad** code:
/// ```dart
/// GestureDetector(
///   onTap: () { },
///   child: MyWidget(),
/// )
/// ```
///
/// Example of **good** code:
/// ```dart
/// InkWell(
///   onTap: () { },
///   child: MyWidget(),
/// )
/// ```
class PreferInkwellOverGestureRule extends SaropaLintRule {
  const PreferInkwellOverGestureRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'prefer_inkwell_over_gesture',
    problemMessage: 'Use InkWell instead of GestureDetector for tap feedback.',
    correctionMessage:
        'Replace GestureDetector with InkWell for ripple effect.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  static const Set<String> _simpleGestures = <String>{
    'onTap',
    'onTapDown',
    'onTapUp',
    'onTapCancel',
    'onDoubleTap',
    'onLongPress',
  };

  static const Set<String> _complexGestures = <String>{
    'onPanStart',
    'onPanUpdate',
    'onPanEnd',
    'onScaleStart',
    'onScaleUpdate',
    'onScaleEnd',
    'onHorizontalDragStart',
    'onHorizontalDragUpdate',
    'onVerticalDragStart',
    'onVerticalDragUpdate',
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
      if (typeName != 'GestureDetector') return;

      bool hasSimple = false;
      bool hasComplex = false;

      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression) {
          final String name = arg.name.label.name;
          if (_simpleGestures.contains(name)) hasSimple = true;
          if (_complexGestures.contains(name)) hasComplex = true;
        }
      }

      if (hasSimple && !hasComplex) {
        reporter.atNode(node.constructorName, code);
      }
    });
  }

  @override
  List<Fix> getFixes() => <Fix>[_ReplaceGestureWithInkWellFix()];
}

class _ReplaceGestureWithInkWellFix extends DartFix {
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
      if (typeName != 'GestureDetector') return;

      final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
        message: 'Replace with InkWell',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        builder.addSimpleReplacement(
          node.constructorName.type.sourceRange,
          'InkWell',
        );
      });
    });
  }
}

/// Warns when FittedBox contains a Text widget.
///
/// FittedBox scales its child to fit, which can cause text to become
/// unreadable or distorted. Use maxLines and overflow instead.
///
/// Example of **bad** code:
/// ```dart
/// FittedBox(child: Text('Long text'))
/// ```
///
/// Example of **good** code:
/// ```dart
/// Text('Long text', maxLines: 2, overflow: TextOverflow.ellipsis)
/// ```
class AvoidFittedBoxForTextRule extends SaropaLintRule {
  const AvoidFittedBoxForTextRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_fitted_box_for_text',
    problemMessage: 'Avoid using FittedBox to scale Text widgets.',
    correctionMessage: 'Use maxLines and overflow for text handling.',
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
      if (typeName != 'FittedBox') return;

      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression && arg.name.label.name == 'child') {
          if (_isTextWidget(arg.expression)) {
            reporter.atNode(node.constructorName, code);
            return;
          }
        }
      }
    });
  }

  bool _isTextWidget(Expression expr) {
    if (expr is InstanceCreationExpression) {
      final String name = expr.constructorName.type.name.lexeme;
      return name == 'Text' || name == 'RichText' || name == 'SelectableText';
    }
    return false;
  }
}

/// Warns when ListView is used with many children instead of ListView.builder.
///
/// ListView with children list builds all items at once.
/// Use ListView.builder for lazy loading with large lists.
///
/// Example of **bad** code:
/// ```dart
/// ListView(children: List.generate(100, (i) => ListTile()))
/// ```
///
/// Example of **good** code:
/// ```dart
/// ListView.builder(itemCount: 100, itemBuilder: (ctx, i) => ListTile())
/// ```
class PreferListViewBuilderRule extends SaropaLintRule {
  const PreferListViewBuilderRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'prefer_listview_builder',
    problemMessage: 'Use ListView.builder for better performance.',
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
class AvoidOpacityAnimationRule extends SaropaLintRule {
  const AvoidOpacityAnimationRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_opacity_animation',
    problemMessage: 'Use FadeTransition instead of animating Opacity.',
    correctionMessage: 'FadeTransition is more performant for animations.',
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
      if (typeName != 'Opacity') return;

      if (_isInsideAnimationBuilder(node)) {
        reporter.atNode(node.constructorName, code);
      }
    });
  }

  bool _isInsideAnimationBuilder(AstNode node) {
    AstNode? current = node.parent;
    int depth = 0;

    while (current != null && depth < 10) {
      if (current is InstanceCreationExpression) {
        final String name = current.constructorName.type.name.lexeme;
        if (name == 'AnimatedBuilder' || name == 'TweenAnimationBuilder') {
          return true;
        }
      }
      current = current.parent;
      depth++;
    }
    return false;
  }

  @override
  List<Fix> getFixes() => <Fix>[_ReplaceOpacityWithFadeTransitionFix()];
}

class _ReplaceOpacityWithFadeTransitionFix extends DartFix {
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

      final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
        message: 'Replace with FadeTransition',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        builder.addSimpleReplacement(
          node.constructorName.type.sourceRange,
          'FadeTransition',
        );
      });
    });
  }
}

/// Warns when SizedBox.expand() is used.
///
/// SizedBox.expand() fills all available space which can cause layout issues.
///
/// Example of **bad** code:
/// ```dart
/// SizedBox.expand(child: MyWidget())
/// ```
///
/// Example of **good** code:
/// ```dart
/// SizedBox(width: double.infinity, height: 200, child: MyWidget())
/// ```
class AvoidSizedBoxExpandRule extends SaropaLintRule {
  const AvoidSizedBoxExpandRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_sized_box_expand',
    problemMessage: 'Avoid SizedBox.expand() as it fills all available space.',
    correctionMessage: 'Use explicit width/height for predictable layouts.',
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
class PreferSelectableTextRule extends SaropaLintRule {
  const PreferSelectableTextRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'prefer_selectable_text',
    problemMessage: 'Consider using SelectableText for long content.',
    correctionMessage: 'SelectableText allows users to copy text.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  static const int _minLength = 100;

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry
        .addInstanceCreationExpression((InstanceCreationExpression node) {
      final String typeName = node.constructorName.type.name.lexeme;
      if (typeName != 'Text') return;

      final NodeList<Expression> args = node.argumentList.arguments;
      if (args.isEmpty) return;

      final Expression firstArg = args.first;
      if (firstArg is NamedExpression) return;

      if (firstArg is SimpleStringLiteral &&
          firstArg.value.length >= _minLength) {
        reporter.atNode(node.constructorName, code);
      }
    });
  }

  @override
  List<Fix> getFixes() => <Fix>[_ReplaceTextWithSelectableFix()];
}

class _ReplaceTextWithSelectableFix extends DartFix {
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

      final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
        message: 'Replace with SelectableText',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        builder.addSimpleReplacement(
          node.constructorName.type.sourceRange,
          'SelectableText',
        );
      });
    });
  }
}

/// Warns when Row/Column uses SizedBox for spacing instead of spacing param.
///
/// Flutter 3.10+ introduced spacing parameter for Row, Column, Wrap, and Flex.
///
/// Example of **bad** code:
/// ```dart
/// Column(children: [Text('A'), SizedBox(height: 8), Text('B')])
/// ```
///
/// Example of **good** code:
/// ```dart
/// Column(spacing: 8, children: [Text('A'), Text('B')])
/// ```
class PreferSpacingOverSizedBoxRule extends SaropaLintRule {
  const PreferSpacingOverSizedBoxRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'prefer_spacing_over_sizedbox',
    problemMessage: 'Use spacing parameter instead of SizedBox for spacing.',
    correctionMessage: 'Row/Column support spacing since Flutter 3.10.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  static const Set<String> _flexWidgets = <String>{'Row', 'Column', 'Wrap'};

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

      bool hasSpacing = false;
      Expression? childrenArg;

      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression) {
          if (arg.name.label.name == 'spacing') hasSpacing = true;
          if (arg.name.label.name == 'children') childrenArg = arg.expression;
        }
      }

      if (hasSpacing || childrenArg == null) return;

      if (childrenArg is ListLiteral) {
        final List<CollectionElement> elements = childrenArg.elements;
        if (elements.length < 3) return;

        int sizedBoxCount = 0;
        double? consistentSize;
        bool isConsistent = true;

        for (final CollectionElement element in elements) {
          if (element is Expression) {
            final double? size = _getSizedBoxSize(element, typeName);
            if (size != null) {
              sizedBoxCount++;
              if (consistentSize == null) {
                consistentSize = size;
              } else if (consistentSize != size) {
                isConsistent = false;
              }
            }
          }
        }

        if (sizedBoxCount >= 2 && isConsistent) {
          reporter.atNode(node.constructorName, code);
        }
      }
    });
  }

  double? _getSizedBoxSize(Expression expr, String parentType) {
    if (expr is! InstanceCreationExpression) return null;

    final String name = expr.constructorName.type.name.lexeme;
    if (name != 'SizedBox') return null;

    final String expectedArg = parentType == 'Column' ? 'height' : 'width';

    for (final Expression arg in expr.argumentList.arguments) {
      if (arg is NamedExpression) {
        if (arg.name.label.name == 'child') {
          return null; // Has child, not spacer
        }
        if (arg.name.label.name == expectedArg) {
          final Expression valueExpr = arg.expression;
          if (valueExpr is IntegerLiteral) {
            return valueExpr.value?.toDouble();
          } else if (valueExpr is DoubleLiteral) {
            return valueExpr.value;
          }
        }
      }
    }
    return null;
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
class AvoidMaterial2FallbackRule extends SaropaLintRule {
  const AvoidMaterial2FallbackRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_material2_fallback',
    problemMessage: 'Avoid explicitly disabling Material 3.',
    correctionMessage:
        'Remove useMaterial3: false or set to true. M3 is the default since Flutter 3.16.',
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
      if (typeName != 'ThemeData') return;

      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression) {
          if (arg.name.label.name == 'useMaterial3') {
            final Expression valueExpr = arg.expression;
            if (valueExpr is BooleanLiteral && !valueExpr.value) {
              reporter.atNode(arg, code);
            }
          }
        }
      }
    });
  }

  @override
  List<Fix> getFixes() => <Fix>[_RemoveMaterial2FallbackFix()];
}

class _RemoveMaterial2FallbackFix extends DartFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    context.registry.addNamedExpression((NamedExpression node) {
      if (!node.sourceRange.intersects(analysisError.sourceRange)) return;
      if (node.name.label.name != 'useMaterial3') return;

      final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
        message: 'Remove useMaterial3: false',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        // Find and remove the argument including trailing comma if present
        int startOffset = node.offset;
        int endOffset = node.end;

        // Check for trailing comma
        final AstNode? parent = node.parent;
        if (parent is ArgumentList) {
          final int index = parent.arguments.indexOf(node);
          if (index >= 0) {
            // Check if there's a comma after this argument
            final String source =
                resolver.source.contents.data.substring(endOffset);
            final Match? commaMatch = RegExp(r'^\s*,').firstMatch(source);
            if (commaMatch != null) {
              endOffset += commaMatch.end;
            }
          }
        }

        builder.addDeletion(SourceRange(startOffset, endOffset - startOffset));
      });
    });
  }
}

/// Warns when using OverlayEntry instead of the declarative OverlayPortal.
///
/// OverlayPortal (Flutter 3.10+) provides a declarative API for overlays
/// that integrates better with the widget tree and InheritedWidgets.
///
/// ### Example
///
/// #### BAD:
/// ```dart
/// late OverlayEntry _overlayEntry;
///
/// void showOverlay() {
///   _overlayEntry = OverlayEntry(
///     builder: (context) => MyOverlayWidget(),
///   );
///   Overlay.of(context).insert(_overlayEntry);
/// }
/// ```
///
/// #### GOOD:
/// ```dart
/// final _controller = OverlayPortalController();
///
/// OverlayPortal(
///   controller: _controller,
///   overlayChildBuilder: (context) => MyOverlayWidget(),
///   child: MyWidget(),
/// )
/// ```
class PreferOverlayPortalRule extends SaropaLintRule {
  const PreferOverlayPortalRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'prefer_overlay_portal',
    problemMessage: 'Consider using OverlayPortal instead of OverlayEntry.',
    correctionMessage:
        'OverlayPortal provides a declarative API that integrates '
        'with InheritedWidgets (Flutter 3.10+).',
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
      if (typeName == 'OverlayEntry') {
        reporter.atNode(node.constructorName, code);
      }
    });
  }
}

/// Warns when using third-party carousel packages instead of CarouselView.
///
/// CarouselView (Flutter 3.24+) is a built-in Material 3 carousel widget
/// that provides standard carousel behavior without external dependencies.
///
/// ### Example
///
/// #### BAD:
/// ```dart
/// import 'package:carousel_slider/carousel_slider.dart';
///
/// CarouselSlider(
///   items: items,
///   options: CarouselOptions(),
/// )
/// ```
///
/// #### GOOD:
/// ```dart
/// CarouselView(
///   itemExtent: 300,
///   children: items,
/// )
/// ```
class PreferCarouselViewRule extends SaropaLintRule {
  const PreferCarouselViewRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'prefer_carousel_view',
    problemMessage:
        'Consider using built-in CarouselView instead of third-party carousel.',
    correctionMessage:
        'CarouselView is available in Flutter 3.24+ and provides '
        'standard M3 carousel behavior.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  /// Known third-party carousel packages and their main widgets
  static const Set<String> _carouselWidgets = <String>{
    'CarouselSlider',
    'PagedCarousel',
    'Carousel',
    'FlutterCarousel',
  };

  static const Set<String> _carouselPackages = <String>{
    'carousel_slider',
    'flutter_carousel_slider',
    'flutter_carousel_widget',
    'card_swiper',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    // Check for carousel widget constructors
    context.registry
        .addInstanceCreationExpression((InstanceCreationExpression node) {
      final String typeName = node.constructorName.type.name.lexeme;
      if (_carouselWidgets.contains(typeName)) {
        reporter.atNode(node.constructorName, code);
      }
    });

    // Check for carousel package imports
    context.registry.addImportDirective((ImportDirective node) {
      final String? uri = node.uri.stringValue;
      if (uri == null) return;

      for (final String pkg in _carouselPackages) {
        if (uri.startsWith('package:$pkg/')) {
          reporter.atNode(node, code);
          return;
        }
      }
    });
  }
}

/// Warns when using showSearch/SearchDelegate instead of SearchAnchor.
///
/// SearchAnchor (Flutter 3.10+) is the Material 3 search component that
/// provides a modern, declarative search UI pattern.
///
/// ### Example
///
/// #### BAD:
/// ```dart
/// IconButton(
///   icon: Icon(Icons.search),
///   onPressed: () {
///     showSearch(
///       context: context,
///       delegate: MySearchDelegate(),
///     );
///   },
/// )
/// ```
///
/// #### GOOD:
/// ```dart
/// SearchAnchor(
///   builder: (context, controller) {
///     return IconButton(
///       icon: Icon(Icons.search),
///       onPressed: () => controller.openView(),
///     );
///   },
///   suggestionsBuilder: (context, controller) {
///     return [/* suggestions */];
///   },
/// )
/// ```
class PreferSearchAnchorRule extends SaropaLintRule {
  const PreferSearchAnchorRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'prefer_search_anchor',
    problemMessage:
        'Consider using SearchAnchor instead of showSearch/SearchDelegate.',
    correctionMessage: 'SearchAnchor provides a modern M3 search pattern '
        '(Flutter 3.10+).',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    // Check for showSearch() calls
    context.registry.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name == 'showSearch') {
        reporter.atNode(node, code);
      }
    });

    // Check for SearchDelegate subclasses
    context.registry.addClassDeclaration((ClassDeclaration node) {
      final ExtendsClause? extendsClause = node.extendsClause;
      if (extendsClause != null) {
        final String superName = extendsClause.superclass.name.lexeme;
        if (superName == 'SearchDelegate') {
          reporter.atNode(extendsClause, code);
        }
      }
    });
  }
}

/// Warns when using GestureDetector for tap-outside-to-dismiss patterns.
///
/// TapRegion (Flutter 3.10+) provides a cleaner API for detecting taps
/// outside a widget, commonly used for dismissing popups, dropdowns, etc.
///
/// ### Example
///
/// #### BAD:
/// ```dart
/// Stack(
///   children: [
///     GestureDetector(
///       onTap: () => Navigator.pop(context),
///       child: Container(color: Colors.black54),
///     ),
///     Center(child: MyPopup()),
///   ],
/// )
/// ```
///
/// #### GOOD:
/// ```dart
/// TapRegion(
///   onTapOutside: (_) => Navigator.pop(context),
///   child: MyPopup(),
/// )
/// ```
class PreferTapRegionForDismissRule extends SaropaLintRule {
  const PreferTapRegionForDismissRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'prefer_tap_region_for_dismiss',
    problemMessage:
        'Consider using TapRegion for tap-outside-to-dismiss patterns.',
    correctionMessage:
        'TapRegion provides onTapOutside callback (Flutter 3.10+).',
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
      if (typeName != 'GestureDetector') return;

      // Check if this looks like a dismiss pattern
      bool hasOnTap = false;
      bool hasDismissPattern = false;

      bool looksLikeBarrier = false;

      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression) {
          final String argName = arg.name.label.name;

          // Look for onTap callback
          if (argName == 'onTap') {
            hasOnTap = true;

            // Check if the callback contains dismiss-like calls
            final Expression callback = arg.expression;
            final String callbackSource = callback.toSource().toLowerCase();
            if (callbackSource.contains('pop') ||
                callbackSource.contains('dismiss') ||
                callbackSource.contains('close') ||
                callbackSource.contains('hide')) {
              hasDismissPattern = true;
            }
          }

          // Check for barrier-like child (transparent/semi-transparent container)
          if (argName == 'child') {
            final Expression childExpr = arg.expression;
            if (childExpr is InstanceCreationExpression) {
              final String childName =
                  childExpr.constructorName.type.name.lexeme;
              // Container/ColoredBox with color often indicates barrier
              if (childName == 'Container' || childName == 'ColoredBox') {
                for (final Expression childArg
                    in childExpr.argumentList.arguments) {
                  if (childArg is NamedExpression &&
                      childArg.name.label.name == 'color') {
                    // Has a color, likely a barrier
                    looksLikeBarrier = true;
                  }
                }
              }
            }
          }
        }
      }

      // Report if it's onTap with dismiss pattern, or onTap with barrier-like child
      if (hasOnTap && (hasDismissPattern || looksLikeBarrier)) {
        reporter.atNode(node.constructorName, code);
      }
    });
  }
}

/// Warns when Text widgets with dynamic content lack overflow handling.
///
/// Text displaying dynamic content (variables, user input) can overflow
/// unexpectedly. Adding `overflow` or `maxLines` ensures graceful handling.
///
/// Only flags Text widgets that:
/// - Use variable interpolation or non-literal strings
/// - Are inside Expanded, Flexible, or constrained containers
///
/// **BAD:**
/// ```dart
/// Text(userName) // Dynamic content may overflow
/// Text('$firstName $lastName') // Interpolated string
/// Expanded(child: Text(description)) // Constrained width
/// ```
///
/// **GOOD:**
/// ```dart
/// Text(userName, overflow: TextOverflow.ellipsis, maxLines: 1)
/// Text('OK') // Static short text is fine
/// Text('Submit', maxLines: 1) // Has maxLines
/// ```
class RequireTextOverflowHandlingRule extends SaropaLintRule {
  const RequireTextOverflowHandlingRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'require_text_overflow_handling',
    problemMessage:
        'Text with dynamic content should have overflow handling to prevent layout issues.',
    correctionMessage:
        'Add overflow: TextOverflow.ellipsis and/or maxLines: 1 parameter.',
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
      final String constructorName = node.constructorName.type.name.lexeme;
      if (constructorName != 'Text') return;

      // Check for overflow handling
      bool hasOverflow = false;
      bool hasMaxLines = false;
      bool hasSoftWrap = false;

      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression) {
          final String argName = arg.name.label.name;
          if (argName == 'overflow') hasOverflow = true;
          if (argName == 'maxLines') hasMaxLines = true;
          if (argName == 'softWrap') hasSoftWrap = true;
        }
      }

      // Already has overflow handling
      if (hasOverflow || hasMaxLines || hasSoftWrap) return;

      // Check if text content is dynamic (not a simple string literal)
      final NodeList<Expression> args = node.argumentList.arguments;
      if (args.isEmpty) return;

      final Expression firstArg = args.first;

      // Skip if it's a short static string (likely a label/button text)
      if (firstArg is SimpleStringLiteral) {
        final String value = firstArg.value;
        // Skip short strings (e.g., buttons, labels) - unlikely to overflow
        if (value.length <= 30 && !value.contains('\n')) return;
      }

      // Skip simple string literals without interpolation
      if (firstArg is SimpleStringLiteral) return;

      // Flag dynamic content: variables, interpolations, method calls
      if (firstArg is StringInterpolation ||
          firstArg is SimpleIdentifier ||
          firstArg is PrefixedIdentifier ||
          firstArg is MethodInvocation ||
          firstArg is PropertyAccess ||
          firstArg is IndexExpression ||
          firstArg is ConditionalExpression ||
          firstArg is BinaryExpression) {
        reporter.atNode(node.constructorName, code);
      }
    });
  }

  @override
  List<Fix> getFixes() => <Fix>[_AddTextOverflowFix()];
}

class _AddTextOverflowFix extends DartFix {
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
      if (node.constructorName.type.name.lexeme != 'Text') return;

      final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
        message: 'Add overflow: TextOverflow.ellipsis, maxLines: 1',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        // Find position before closing parenthesis
        final int insertOffset = node.argumentList.rightParenthesis.offset;
        final String comma = node.argumentList.arguments.isEmpty ? '' : ', ';
        builder.addSimpleInsertion(
          insertOffset,
          '${comma}overflow: TextOverflow.ellipsis, maxLines: 1',
        );
      });
    });
  }
}

/// Requires Image.network to have an errorBuilder for handling load failures.
///
/// Network images can fail to load due to connectivity issues, invalid URLs,
/// or server errors. Without an errorBuilder, users see broken image icons.
///
/// **BAD:**
/// ```dart
/// Image.network('https://example.com/image.png')
/// ```
///
/// **GOOD:**
/// ```dart
/// Image.network(
///   'https://example.com/image.png',
///   errorBuilder: (context, error, stackTrace) => Icon(Icons.error),
/// )
/// ```
class RequireImageErrorBuilderRule extends SaropaLintRule {
  const RequireImageErrorBuilderRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'require_image_error_builder',
    problemMessage: 'Network image should have an errorBuilder.',
    correctionMessage:
        'Add errorBuilder to handle image loading failures gracefully.',
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
      final String? constructorName = node.constructorName.name?.name;

      // Check for Image.network
      if (typeName != 'Image') return;
      if (constructorName != 'network') return;

      bool hasErrorBuilder = false;

      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression && arg.name.label.name == 'errorBuilder') {
          hasErrorBuilder = true;
          break;
        }
      }

      if (!hasErrorBuilder) {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Requires network images to specify width and height for layout stability.
///
/// Network images without dimensions cause layout shifts (CLS) when they load,
/// leading to poor user experience. Specifying dimensions reserves space
/// before the image loads.
///
/// Only applies to:
/// - `Image.network()`
/// - `CachedNetworkImage()`
///
/// Does NOT flag:
/// - `Image.asset()` - dimensions are typically known at build time
/// - Images with `fit` parameter - usually sized by parent container
/// - Images inside `SizedBox`, `Container` with dimensions
///
/// **BAD:**
/// ```dart
/// Image.network('https://example.com/image.png')
/// CachedNetworkImage(imageUrl: url)
/// ```
///
/// **GOOD:**
/// ```dart
/// Image.network(
///   'https://example.com/image.png',
///   width: 200,
///   height: 150,
/// )
/// SizedBox(
///   width: 200,
///   height: 150,
///   child: Image.network(url, fit: BoxFit.cover),
/// )
/// ```
class RequireImageDimensionsRule extends SaropaLintRule {
  const RequireImageDimensionsRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'require_image_dimensions',
    problemMessage:
        'Network image should specify width and height to prevent layout shifts.',
    correctionMessage:
        'Add width and height, or wrap in SizedBox with dimensions.',
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

      // Only check network images
      bool isNetworkImage = false;
      if (typeName == 'Image' && constructorName == 'network') {
        isNetworkImage = true;
      }
      if (typeName == 'CachedNetworkImage') {
        isNetworkImage = true;
      }

      if (!isNetworkImage) return;

      bool hasWidth = false;
      bool hasHeight = false;
      bool hasFit = false;

      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression) {
          final String argName = arg.name.label.name;
          if (argName == 'width') hasWidth = true;
          if (argName == 'height') hasHeight = true;
          if (argName == 'fit') hasFit = true;
        }
      }

      // Allow if BoxFit is specified (usually means parent provides dimensions)
      if (hasFit) return;

      // Allow if has at least one dimension (aspect ratio can determine other)
      if (hasWidth || hasHeight) return;

      // Check if parent is a sizing widget (SizedBox, Container with size)
      if (_hasParentWithDimensions(node)) return;

      reporter.atNode(node.constructorName, code);
    });
  }

  /// Checks if an ancestor provides dimensions (SizedBox, Container, etc.)
  bool _hasParentWithDimensions(AstNode node) {
    AstNode? current = node.parent;
    int depth = 0;
    const int maxDepth = 5; // Don't look too far up

    while (current != null && depth < maxDepth) {
      if (current is InstanceCreationExpression) {
        final String parentType = current.constructorName.type.name.lexeme;

        // SizedBox, Container, ConstrainedBox typically provide dimensions
        if (parentType == 'SizedBox' ||
            parentType == 'Container' ||
            parentType == 'ConstrainedBox' ||
            parentType == 'AspectRatio') {
          // Check if the parent has width/height
          for (final Expression arg in current.argumentList.arguments) {
            if (arg is NamedExpression) {
              final String argName = arg.name.label.name;
              if (argName == 'width' ||
                  argName == 'height' ||
                  argName == 'constraints' ||
                  argName == 'aspectRatio') {
                return true;
              }
            }
          }
        }

        // Expanded/Flexible in Row/Column will provide constraints
        if (parentType == 'Expanded' || parentType == 'Flexible') {
          return true;
        }
      }
      current = current.parent;
      depth++;
    }
    return false;
  }
}

/// Requires network images to have a placeholder or loadingBuilder.
///
/// Without a placeholder, users see nothing while images load,
/// leading to poor perceived performance.
///
/// **BAD:**
/// ```dart
/// Image.network('https://example.com/image.png')
/// ```
///
/// **GOOD:**
/// ```dart
/// Image.network(
///   'https://example.com/image.png',
///   loadingBuilder: (context, child, progress) =>
///       progress == null ? child : CircularProgressIndicator(),
/// )
/// // Or with CachedNetworkImage:
/// CachedNetworkImage(
///   imageUrl: url,
///   placeholder: (context, url) => CircularProgressIndicator(),
/// )
/// ```
class RequirePlaceholderForNetworkRule extends SaropaLintRule {
  const RequirePlaceholderForNetworkRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'require_placeholder_for_network',
    problemMessage:
        'Network image should have a placeholder or loadingBuilder.',
    correctionMessage:
        'Add loadingBuilder or placeholder to show feedback during loading.',
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

      // Check for Image.network
      bool isNetworkImage = false;
      if (typeName == 'Image' && constructorName == 'network') {
        isNetworkImage = true;
      }
      if (typeName == 'CachedNetworkImage') {
        isNetworkImage = true;
      }

      if (!isNetworkImage) return;

      bool hasPlaceholder = false;

      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression) {
          final String argName = arg.name.label.name;
          if (argName == 'loadingBuilder' ||
              argName == 'placeholder' ||
              argName == 'progressIndicatorBuilder') {
            hasPlaceholder = true;
            break;
          }
        }
      }

      if (!hasPlaceholder) {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Requires ScrollController fields to be disposed in State classes.
///
/// ScrollController allocates native resources and listeners that must be
/// released by calling dispose(). Failing to do so causes memory leaks.
///
/// **BAD:**
/// ```dart
/// class _MyState extends State<MyWidget> {
///   final _scrollController = ScrollController();
///   // Missing dispose - MEMORY LEAK!
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// class _MyState extends State<MyWidget> {
///   final _scrollController = ScrollController();
///
///   @override
///   void dispose() {
///     _scrollController.dispose();
///     super.dispose();
///   }
/// }
/// ```
class RequireScrollControllerDisposeRule extends SaropaLintRule {
  const RequireScrollControllerDisposeRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'require_scroll_controller_dispose',
    problemMessage:
        'ScrollController is not disposed. This causes memory leaks.',
    correctionMessage:
        'Add _controller.dispose() in the dispose() method before super.dispose().',
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

      final NamedType superclass = extendsClause.superclass;
      final String superName = superclass.name.lexeme;

      // Must be exactly "State" with type argument (State<MyWidget>)
      if (superName != 'State') return;
      if (superclass.typeArguments == null) return;

      // Find ScrollController fields (including late fields)
      final List<String> controllerNames = <String>[];
      for (final ClassMember member in node.members) {
        if (member is FieldDeclaration) {
          for (final VariableDeclaration variable in member.fields.variables) {
            final String? typeName = member.fields.type?.toSource();
            if (typeName != null && typeName.contains('ScrollController')) {
              controllerNames.add(variable.name.lexeme);
              continue;
            }
            // Check initializer for inferred types
            final Expression? initializer = variable.initializer;
            if (initializer is InstanceCreationExpression) {
              final String initType =
                  initializer.constructorName.type.name.lexeme;
              if (initType == 'ScrollController') {
                if (!controllerNames.contains(variable.name.lexeme)) {
                  controllerNames.add(variable.name.lexeme);
                }
              }
            }
          }
        }
      }

      if (controllerNames.isEmpty) return;

      // Find dispose method body
      String? disposeBody;
      for (final ClassMember member in node.members) {
        if (member is MethodDeclaration && member.name.lexeme == 'dispose') {
          disposeBody = member.body.toSource();
          break;
        }
      }

      // Check if each controller is disposed
      for (final String name in controllerNames) {
        // Direct disposal patterns
        final bool isDirectlyDisposed = disposeBody != null &&
            (disposeBody.contains('$name.dispose(') ||
                disposeBody.contains('$name?.dispose(') ||
                disposeBody.contains('$name.disposeSafe(') ||
                disposeBody.contains('$name?.disposeSafe(') ||
                disposeBody.contains('$name..dispose('));

        // Iteration-based disposal for List<ScrollController> or
        // Map<..., ScrollController>
        // Patterns like: "for (... in _name) { ...dispose()" or
        // "for (... in _name.values) { ...dispose()"
        final bool isIterationDisposed = disposeBody != null &&
            (disposeBody.contains('in $name)') ||
                disposeBody.contains('in $name.values)')) &&
            disposeBody.contains('.dispose()');

        final bool isDisposed = isDirectlyDisposed || isIterationDisposed;

        if (!isDisposed) {
          // Find and report the field declaration
          for (final ClassMember member in node.members) {
            if (member is FieldDeclaration) {
              for (final VariableDeclaration variable
                  in member.fields.variables) {
                if (variable.name.lexeme == name) {
                  reporter.atNode(variable, code);
                }
              }
            }
          }
        }
      }
    });
  }

  @override
  List<Fix> getFixes() => <Fix>[_AddScrollControllerDisposeFix()];
}

class _AddScrollControllerDisposeFix extends DartFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    context.registry.addVariableDeclaration((VariableDeclaration node) {
      if (!node.sourceRange.intersects(analysisError.sourceRange)) return;

      final String fieldName = node.name.lexeme;

      // Find the containing class
      AstNode? current = node.parent;
      while (current != null && current is! ClassDeclaration) {
        current = current.parent;
      }
      if (current is! ClassDeclaration) return;

      final ClassDeclaration classNode = current;

      // Find existing dispose method
      MethodDeclaration? disposeMethod;
      for (final ClassMember member in classNode.members) {
        if (member is MethodDeclaration && member.name.lexeme == 'dispose') {
          disposeMethod = member;
          break;
        }
      }

      if (disposeMethod != null) {
        // Insert dispose call before super.dispose()
        final String bodySource = disposeMethod.body.toSource();
        final int superDisposeIndex = bodySource.indexOf('super.dispose()');

        if (superDisposeIndex != -1) {
          // Find the actual offset in the file
          final int bodyOffset = disposeMethod.body.offset;
          final int insertOffset = bodyOffset + superDisposeIndex;

          final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
            message: 'Add $fieldName.dispose()',
            priority: 1,
          );

          changeBuilder.addDartFileEdit((builder) {
            builder.addSimpleInsertion(
              insertOffset,
              '$fieldName.dispose();\n    ',
            );
          });
        }
      } else {
        // Create new dispose method after the last field or constructor
        int insertOffset = classNode.rightBracket.offset;

        // Try to find a good insertion point (after fields/constructors)
        for (final ClassMember member in classNode.members) {
          if (member is FieldDeclaration || member is ConstructorDeclaration) {
            insertOffset = member.end;
          }
        }

        final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
          message: 'Add dispose() method with $fieldName.dispose()',
          priority: 1,
        );

        changeBuilder.addDartFileEdit((builder) {
          builder.addSimpleInsertion(
            insertOffset,
            '\n\n  @override\n  void dispose() {\n    $fieldName.dispose();\n    super.dispose();\n  }',
          );
        });
      }
    });
  }
}

/// Requires FocusNode fields to be disposed in State classes.
///
/// FocusNode allocates focus tree resources that must be released by calling
/// dispose(). Failing to do so causes memory leaks and focus management issues.
///
/// **BAD:**
/// ```dart
/// class _MyState extends State<MyWidget> {
///   final _focusNode = FocusNode();
///   // Missing dispose - MEMORY LEAK!
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// class _MyState extends State<MyWidget> {
///   final _focusNode = FocusNode();
///
///   @override
///   void dispose() {
///     _focusNode.dispose();
///     super.dispose();
///   }
/// }
/// ```
class RequireFocusNodeDisposeRule extends SaropaLintRule {
  const RequireFocusNodeDisposeRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'require_focus_node_dispose',
    problemMessage: 'FocusNode is not disposed. This causes memory leaks.',
    correctionMessage:
        'Add _focusNode.dispose() in the dispose() method before super.dispose().',
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

      final NamedType superclass = extendsClause.superclass;
      final String superName = superclass.name.lexeme;

      // Must be exactly "State" with type argument (State<MyWidget>)
      if (superName != 'State') return;
      if (superclass.typeArguments == null) return;

      // Find FocusNode fields (including late fields)
      final List<String> nodeNames = <String>[];
      for (final ClassMember member in node.members) {
        if (member is FieldDeclaration) {
          for (final VariableDeclaration variable in member.fields.variables) {
            final String? typeName = member.fields.type?.toSource();
            if (typeName != null &&
                (typeName.contains('FocusNode') ||
                    typeName.contains('FocusScopeNode'))) {
              nodeNames.add(variable.name.lexeme);
              continue;
            }
            // Check initializer for inferred types
            final Expression? initializer = variable.initializer;
            if (initializer is InstanceCreationExpression) {
              final String initType =
                  initializer.constructorName.type.name.lexeme;
              if (initType == 'FocusNode' || initType == 'FocusScopeNode') {
                if (!nodeNames.contains(variable.name.lexeme)) {
                  nodeNames.add(variable.name.lexeme);
                }
              }
            }
          }
        }
      }

      if (nodeNames.isEmpty) return;

      // Find dispose method body
      String? disposeBody;
      for (final ClassMember member in node.members) {
        if (member is MethodDeclaration && member.name.lexeme == 'dispose') {
          disposeBody = member.body.toSource();
          break;
        }
      }

      // Check if each node is disposed
      for (final String name in nodeNames) {
        // Direct disposal patterns
        final bool isDirectlyDisposed = disposeBody != null &&
            (disposeBody.contains('$name.dispose(') ||
                disposeBody.contains('$name?.dispose(') ||
                disposeBody.contains('$name.disposeSafe(') ||
                disposeBody.contains('$name?.disposeSafe(') ||
                disposeBody.contains('$name..dispose('));

        // Iteration-based disposal for List<FocusNode> or Map<..., FocusNode>
        // Patterns like: "for (... in _name) { ...dispose()" or
        // "for (... in _name.values) { ...dispose()"
        final bool isIterationDisposed = disposeBody != null &&
            (disposeBody.contains('in $name)') ||
                disposeBody.contains('in $name.values)')) &&
            disposeBody.contains('.dispose()');

        final bool isDisposed = isDirectlyDisposed || isIterationDisposed;

        if (!isDisposed) {
          // Find and report the field declaration
          for (final ClassMember member in node.members) {
            if (member is FieldDeclaration) {
              for (final VariableDeclaration variable
                  in member.fields.variables) {
                if (variable.name.lexeme == name) {
                  reporter.atNode(variable, code);
                }
              }
            }
          }
        }
      }
    });
  }

  @override
  List<Fix> getFixes() => <Fix>[_AddFocusNodeDisposeFix()];
}

class _AddFocusNodeDisposeFix extends DartFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    context.registry.addVariableDeclaration((VariableDeclaration node) {
      if (!node.sourceRange.intersects(analysisError.sourceRange)) return;

      final String fieldName = node.name.lexeme;

      // Find the containing class
      AstNode? current = node.parent;
      while (current != null && current is! ClassDeclaration) {
        current = current.parent;
      }
      if (current is! ClassDeclaration) return;

      final ClassDeclaration classNode = current;

      // Find existing dispose method
      MethodDeclaration? disposeMethod;
      for (final ClassMember member in classNode.members) {
        if (member is MethodDeclaration && member.name.lexeme == 'dispose') {
          disposeMethod = member;
          break;
        }
      }

      if (disposeMethod != null) {
        // Insert dispose call before super.dispose()
        final String bodySource = disposeMethod.body.toSource();
        final int superDisposeIndex = bodySource.indexOf('super.dispose()');

        if (superDisposeIndex != -1) {
          // Find the actual offset in the file
          final int bodyOffset = disposeMethod.body.offset;
          final int insertOffset = bodyOffset + superDisposeIndex;

          final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
            message: 'Add $fieldName.dispose()',
            priority: 1,
          );

          changeBuilder.addDartFileEdit((builder) {
            builder.addSimpleInsertion(
              insertOffset,
              '$fieldName.dispose();\n    ',
            );
          });
        }
      } else {
        // Create new dispose method after the last field or constructor
        int insertOffset = classNode.rightBracket.offset;

        // Try to find a good insertion point (after fields/constructors)
        for (final ClassMember member in classNode.members) {
          if (member is FieldDeclaration || member is ConstructorDeclaration) {
            insertOffset = member.end;
          }
        }

        final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
          message: 'Add dispose() method with $fieldName.dispose()',
          priority: 1,
        );

        changeBuilder.addDartFileEdit((builder) {
          builder.addSimpleInsertion(
            insertOffset,
            '\n\n  @override\n  void dispose() {\n    $fieldName.dispose();\n    super.dispose();\n  }',
          );
        });
      }
    });
  }
}

/// Suggests using Theme.textTheme instead of hardcoded TextStyle.
///
/// Hardcoded text styles make it difficult to maintain consistent
/// typography and support theming/dark mode.
///
/// **BAD:**
/// ```dart
/// Text(
///   'Hello',
///   style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// Text(
///   'Hello',
///   style: Theme.of(context).textTheme.headlineLarge,
/// )
/// ```
class PreferTextThemeRule extends SaropaLintRule {
  const PreferTextThemeRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'prefer_text_theme',
    problemMessage:
        'Consider using Theme.textTheme instead of hardcoded TextStyle.',
    correctionMessage:
        'Use Theme.of(context).textTheme.* for consistent typography.',
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
      if (typeName != 'TextStyle') return;

      // Check if inside a Text widget's style argument
      AstNode? current = node.parent;
      while (current != null) {
        if (current is NamedExpression && current.name.label.name == 'style') {
          // Check if parent is Text widget
          final AstNode? namedParent = current.parent;
          if (namedParent is ArgumentList) {
            final AstNode? argListParent = namedParent.parent;
            if (argListParent is InstanceCreationExpression) {
              final String parentType =
                  argListParent.constructorName.type.name.lexeme;
              if (parentType == 'Text' || parentType == 'RichText') {
                reporter.atNode(node, code);
                return;
              }
            }
          }
        }
        current = current.parent;
      }
    });
  }
}

/// Warns when scrollable widgets are nested without NestedScrollView.
///
/// Nested scrollables (ListView inside ListView) cause gestures to be
/// ambiguous and can lead to poor scroll performance and UX issues.
///
/// **BAD:**
/// ```dart
/// ListView(
///   children: [
///     ListView.builder(...), // Nested scrollable!
///   ],
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// NestedScrollView(
///   headerSliverBuilder: (context, innerBoxIsScrolled) => [
///     SliverAppBar(...),
///   ],
///   body: ListView.builder(...),
/// )
/// // Or use shrinkWrap + NeverScrollableScrollPhysics for inner list
/// ```
class AvoidNestedScrollablesRule extends SaropaLintRule {
  const AvoidNestedScrollablesRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_nested_scrollables',
    problemMessage: 'Nested scrollable widgets can cause scroll conflicts.',
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

  static const LintCode _code = LintCode(
    name: 'avoid_hardcoded_layout_values',
    problemMessage: 'Avoid hardcoded numeric values in layout widgets.',
    correctionMessage:
        'Extract magic numbers to named constants or use a spacing system.',
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

  static const LintCode _code = LintCode(
    name: 'prefer_ignore_pointer',
    problemMessage:
        'AbsorbPointer blocks underlying widgets - is IgnorePointer better?',
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
class AvoidGestureWithoutBehaviorRule extends SaropaLintRule {
  const AvoidGestureWithoutBehaviorRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_gesture_without_behavior',
    problemMessage: 'GestureDetector should specify HitTestBehavior.',
    correctionMessage:
        'Add behavior: HitTestBehavior.opaque (or translucent/deferToChild).',
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
      if (typeName != 'GestureDetector') return;

      // Check if behavior is specified
      bool hasBehavior = false;
      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression && arg.name.label.name == 'behavior') {
          hasBehavior = true;
          break;
        }
      }

      if (!hasBehavior) {
        reporter.atNode(node.constructorName, code);
      }
    });
  }
}

/// Warns when buttons don't prevent double-tap submissions.
///
/// Double-tapping a submit button can cause duplicate API calls,
/// payments, or other unintended side effects.
///
/// **BAD:**
/// ```dart
/// ElevatedButton(
///   onPressed: () => submitForm(),
///   child: Text('Submit'),
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// ElevatedButton(
///   onPressed: isSubmitting ? null : () => submitForm(),
///   child: isSubmitting ? CircularProgressIndicator() : Text('Submit'),
/// )
/// ```
class AvoidDoubleTapSubmitRule extends SaropaLintRule {
  const AvoidDoubleTapSubmitRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_double_tap_submit',
    problemMessage: 'Button may allow double-tap submissions.',
    correctionMessage:
        'Disable the button during submission or use a debounce mechanism.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  static const Set<String> _buttonWidgets = <String>{
    'ElevatedButton',
    'TextButton',
    'OutlinedButton',
    'FilledButton',
  };

  static const Set<String> _submitKeywords = <String>{
    'submit',
    'save',
    'send',
    'pay',
    'purchase',
    'confirm',
    'order',
    'checkout',
    'register',
    'signup',
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
      if (!_buttonWidgets.contains(typeName)) return;

      String? childText;
      Expression? onPressedExpr;

      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression) {
          final String argName = arg.name.label.name;
          if (argName == 'child') {
            childText = arg.expression.toSource().toLowerCase();
          }
          if (argName == 'onPressed') {
            onPressedExpr = arg.expression;
          }
        }
      }

      // Check if this looks like a submit button
      if (childText == null) return;
      bool isSubmitButton = _submitKeywords.any(
        (String keyword) => childText!.contains(keyword),
      );
      if (!isSubmitButton) return;

      // Check if onPressed has any conditional logic
      if (onPressedExpr == null) return;
      final String onPressedSource = onPressedExpr.toSource();

      // If it's a simple function without null check, warn
      if (!onPressedSource.contains('?') &&
          !onPressedSource.contains('null') &&
          !onPressedSource.contains('isLoading') &&
          !onPressedSource.contains('isSubmitting') &&
          !onPressedSource.contains('_loading') &&
          !onPressedSource.contains('_submitting')) {
        reporter.atNode(node.constructorName, code);
      }
    });
  }
}

/// Warns when buttons on web don't have mouse cursor configured.
///
/// On web platforms, buttons should show appropriate cursors to
/// indicate interactivity.
///
/// **BAD:**
/// ```dart
/// InkWell(
///   onTap: () => doSomething(),
///   child: Text('Click me'),
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// InkWell(
///   onTap: () => doSomething(),
///   mouseCursor: SystemMouseCursors.click,
///   child: Text('Click me'),
/// )
/// ```
class PreferCursorForButtonsRule extends SaropaLintRule {
  const PreferCursorForButtonsRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'prefer_cursor_for_buttons',
    problemMessage: 'Interactive widget should specify mouse cursor for web.',
    correctionMessage:
        'Add mouseCursor: SystemMouseCursors.click (or similar).',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  static const Set<String> _interactiveWidgets = <String>{
    'InkWell',
    'GestureDetector',
    'InkResponse',
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
      if (!_interactiveWidgets.contains(typeName)) return;

      bool hasOnTap = false;
      bool hasMouseCursor = false;

      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression) {
          final String argName = arg.name.label.name;
          if (argName == 'onTap' || argName == 'onPressed') {
            hasOnTap = true;
          }
          if (argName == 'mouseCursor') {
            hasMouseCursor = true;
          }
        }
      }

      if (hasOnTap && !hasMouseCursor) {
        reporter.atNode(node.constructorName, code);
      }
    });
  }
}

/// Warns when interactive widgets don't handle hover state.
///
/// On web and desktop, hover states provide important visual feedback.
///
/// **BAD:**
/// ```dart
/// InkWell(
///   onTap: () => doSomething(),
///   child: MyButton(),
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// InkWell(
///   onTap: () => doSomething(),
///   onHover: (hovering) => setState(() => _isHovered = hovering),
///   child: MyButton(isHovered: _isHovered),
/// )
/// ```
class RequireHoverStatesRule extends SaropaLintRule {
  const RequireHoverStatesRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'require_hover_states',
    problemMessage:
        'Interactive widget should handle hover state for web/desktop.',
    correctionMessage: 'Add onHover callback for visual feedback.',
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
      // Only check InkWell and MouseRegion
      if (typeName != 'InkWell' && typeName != 'GestureDetector') return;

      bool hasOnTap = false;
      bool hasHoverHandling = false;

      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression) {
          final String argName = arg.name.label.name;
          if (argName == 'onTap' || argName == 'onPressed') {
            hasOnTap = true;
          }
          if (argName == 'onHover' ||
              argName == 'hoverColor' ||
              argName == 'highlightColor') {
            hasHoverHandling = true;
          }
        }
      }

      if (hasOnTap && !hasHoverHandling) {
        reporter.atNode(node.constructorName, code);
      }
    });
  }
}

/// Warns when buttons don't have a loading state for async operations.
///
/// Users should see visual feedback when an async operation is in progress.
///
/// **BAD:**
/// ```dart
/// ElevatedButton(
///   onPressed: () async {
///     await api.submit(data);
///   },
///   child: Text('Submit'),
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// ElevatedButton(
///   onPressed: isLoading ? null : () async {
///     setState(() => isLoading = true);
///     await api.submit(data);
///     setState(() => isLoading = false);
///   },
///   child: isLoading ? CircularProgressIndicator() : Text('Submit'),
/// )
/// ```
class RequireButtonLoadingStateRule extends SaropaLintRule {
  const RequireButtonLoadingStateRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'require_button_loading_state',
    problemMessage: 'Async button should show loading state.',
    correctionMessage:
        'Disable button and show loading indicator during async operations.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  static const Set<String> _buttonWidgets = <String>{
    'ElevatedButton',
    'TextButton',
    'OutlinedButton',
    'FilledButton',
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
      if (!_buttonWidgets.contains(typeName)) return;

      Expression? onPressedExpr;
      Expression? childExpr;

      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression) {
          final String argName = arg.name.label.name;
          if (argName == 'onPressed') {
            onPressedExpr = arg.expression;
          }
          if (argName == 'child') {
            childExpr = arg.expression;
          }
        }
      }

      if (onPressedExpr == null) return;
      final String onPressedSource = onPressedExpr.toSource();

      // Check if the callback is async
      bool isAsync = onPressedSource.contains('async') ||
          onPressedSource.contains('await');

      if (!isAsync) return;

      // Check if there's loading state handling
      bool hasLoadingState = onPressedSource.contains('isLoading') ||
          onPressedSource.contains('_loading') ||
          onPressedSource.contains('loading') ||
          onPressedSource.contains('isSubmitting') ||
          onPressedSource.contains('_submitting');

      // Check if child shows loading indicator
      String childSource = childExpr?.toSource() ?? '';
      bool hasLoadingIndicator =
          childSource.contains('CircularProgressIndicator') ||
              childSource.contains('Loading') ||
              childSource.contains('isLoading') ||
              childSource.contains('?');

      if (!hasLoadingState && !hasLoadingIndicator) {
        reporter.atNode(node.constructorName, code);
      }
    });
  }
}

/// Warns when hardcoded TextStyle values are used instead of theme.
///
/// Hardcoded text styles make it difficult to maintain consistent
/// typography across the app.
///
/// **BAD:**
/// ```dart
/// Text(
///   'Hello',
///   style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// Text(
///   'Hello',
///   style: Theme.of(context).textTheme.bodyLarge,
/// )
/// ```
class AvoidHardcodedTextStylesRule extends SaropaLintRule {
  const AvoidHardcodedTextStylesRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_hardcoded_text_styles',
    problemMessage: 'Avoid inline TextStyle with hardcoded values.',
    correctionMessage:
        'Use Theme.of(context).textTheme or define styles in a central location.',
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
      if (typeName != 'TextStyle') return;

      // Check if this TextStyle is used inline in a Text widget style argument
      final AstNode? parent = node.parent;
      if (parent is NamedExpression && parent.name.label.name == 'style') {
        final AstNode? grandparent = parent.parent?.parent;
        if (grandparent is InstanceCreationExpression) {
          final String parentType =
              grandparent.constructorName.type.name.lexeme;
          if (parentType == 'Text' ||
              parentType == 'RichText' ||
              parentType == 'DefaultTextStyle') {
            // Check for hardcoded values
            bool hasHardcodedValues = false;
            for (final Expression arg in node.argumentList.arguments) {
              if (arg is NamedExpression) {
                final String argName = arg.name.label.name;
                if (argName == 'fontSize' || argName == 'fontWeight') {
                  // Check if value is a literal
                  if (arg.expression is IntegerLiteral ||
                      arg.expression is DoubleLiteral) {
                    hasHardcodedValues = true;
                    break;
                  }
                }
              }
            }

            if (hasHardcodedValues) {
              reporter.atNode(node.constructorName, code);
            }
          }
        }
      }
    });
  }
}

/// Warns when PageStorageKey is not used for scroll position preservation.
///
/// Without PageStorageKey, scroll positions are lost when navigating
/// between screens.
///
/// **BAD:**
/// ```dart
/// ListView.builder(
///   itemBuilder: (context, index) => ListTile(),
///   itemCount: 100,
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// ListView.builder(
///   key: PageStorageKey('my_list'),
///   itemBuilder: (context, index) => ListTile(),
///   itemCount: 100,
/// )
/// ```
class PreferPageStorageKeyRule extends SaropaLintRule {
  const PreferPageStorageKeyRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'prefer_page_storage_key',
    problemMessage:
        'Consider using PageStorageKey to preserve scroll position.',
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
class RequireRefreshIndicatorRule extends SaropaLintRule {
  const RequireRefreshIndicatorRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'require_refresh_indicator',
    problemMessage:
        'List showing remote data should have RefreshIndicator for pull-to-refresh.',
    correctionMessage:
        'Wrap with RefreshIndicator(onRefresh: () => fetch(), child: ...).',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  /// Words suggesting remote/fetchable data
  static const Set<String> _remoteDataIndicators = <String>{
    'posts',
    'items',
    'messages',
    'notifications',
    'feeds',
    'articles',
    'users',
    'comments',
    'data',
    'results',
    'list',
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
      final String? constructorName = node.constructorName.name?.name;

      // Only check ListView.builder which typically shows dynamic content
      if (typeName != 'ListView' || constructorName != 'builder') return;

      // Check if already wrapped in RefreshIndicator
      AstNode? current = node.parent;
      while (current != null) {
        if (current is InstanceCreationExpression) {
          final String parentType = current.constructorName.type.name.lexeme;
          if (parentType == 'RefreshIndicator') {
            return; // Already has RefreshIndicator
          }
        }
        current = current.parent;
      }

      // Only warn if the source suggests remote data
      final String nodeSource = node.toSource().toLowerCase();
      final bool suggestsRemoteData = _remoteDataIndicators.any(
        (indicator) => nodeSource.contains(indicator),
      );

      if (suggestsRemoteData) {
        reporter.atNode(node.constructorName, code);
      }
    });
  }
}

/// Warns when scrollable widgets don't specify scroll physics.
///
/// Explicit scroll physics ensures consistent behavior across platforms.
///
/// **BAD:**
/// ```dart
/// ListView.builder(
///   itemBuilder: (context, index) => ListTile(),
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// ListView.builder(
///   physics: const BouncingScrollPhysics(),
///   itemBuilder: (context, index) => ListTile(),
/// )
/// ```
class RequireScrollPhysicsRule extends SaropaLintRule {
  const RequireScrollPhysicsRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'require_scroll_physics',
    problemMessage: 'Scrollable widget should specify scroll physics.',
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

  static const LintCode _code = LintCode(
    name: 'prefer_sliver_list',
    problemMessage:
        'Use SliverList instead of ListView inside CustomScrollView.',
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

  static const LintCode _code = LintCode(
    name: 'prefer_keep_alive',
    problemMessage:
        'Consider using AutomaticKeepAliveClientMixin to preserve state.',
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
class RequireDefaultTextStyleRule extends SaropaLintRule {
  const RequireDefaultTextStyleRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'require_default_text_style',
    problemMessage:
        'Multiple Text widgets with same style - use DefaultTextStyle.',
    correctionMessage: 'Wrap with DefaultTextStyle to share common styles.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addListLiteral((ListLiteral node) {
      // Count Text widgets with explicit styles in this list
      int textWithStyleCount = 0;
      String? firstStyleSource;

      for (final CollectionElement element in node.elements) {
        if (element is InstanceCreationExpression) {
          final String typeName = element.constructorName.type.name.lexeme;
          if (typeName == 'Text') {
            for (final Expression arg in element.argumentList.arguments) {
              if (arg is NamedExpression && arg.name.label.name == 'style') {
                final String styleSource = arg.expression.toSource();
                if (firstStyleSource == null) {
                  firstStyleSource = styleSource;
                  textWithStyleCount++;
                } else if (styleSource == firstStyleSource) {
                  textWithStyleCount++;
                }
              }
            }
          }
        }
      }

      // If 3+ Text widgets have the same style, suggest DefaultTextStyle
      if (textWithStyleCount >= 3) {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when Row/Column with overflow could use Wrap instead.
///
/// Wrap automatically moves overflowing children to the next line.
///
/// **BAD:**
/// ```dart
/// Row(
///   children: [Chip(...), Chip(...), Chip(...), Chip(...)], // May overflow
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// Wrap(
///   spacing: 8,
///   children: [Chip(...), Chip(...), Chip(...), Chip(...)],
/// )
/// ```
class PreferWrapOverOverflowRule extends SaropaLintRule {
  const PreferWrapOverOverflowRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'prefer_wrap_over_overflow',
    problemMessage:
        'Row with many children may overflow - consider using Wrap.',
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
class PreferAssetImageForLocalRule extends SaropaLintRule {
  const PreferAssetImageForLocalRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'prefer_asset_image_for_local',
    problemMessage: 'Use AssetImage for bundled assets, not FileImage.',
    correctionMessage: 'Replace FileImage with AssetImage or Image.asset().',
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
      if (typeName != 'FileImage') return;

      // Check if the file path looks like an asset path
      if (node.argumentList.arguments.isNotEmpty) {
        final String argSource = node.argumentList.arguments.first.toSource();
        if (argSource.contains('assets/') || argSource.contains('asset')) {
          reporter.atNode(node.constructorName, code);
        }
      }
    });
  }
}

/// Warns when background images don't use BoxFit.cover.
///
/// BoxFit.cover ensures the image fills the container without distortion.
///
/// **BAD:**
/// ```dart
/// Container(
///   decoration: BoxDecoration(
///     image: DecorationImage(image: AssetImage('bg.png')),
///   ),
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// Container(
///   decoration: BoxDecoration(
///     image: DecorationImage(
///       image: AssetImage('bg.png'),
///       fit: BoxFit.cover,
///     ),
///   ),
/// )
/// ```
class PreferFitCoverForBackgroundRule extends SaropaLintRule {
  const PreferFitCoverForBackgroundRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'prefer_fit_cover_for_background',
    problemMessage: 'Background images should use BoxFit.cover.',
    correctionMessage: 'Add fit: BoxFit.cover to DecorationImage.',
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
      if (typeName != 'DecorationImage') return;

      bool hasFit = false;
      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression && arg.name.label.name == 'fit') {
          hasFit = true;
          break;
        }
      }

      if (!hasFit) {
        reporter.atNode(node.constructorName, code);
      }
    });
  }
}

/// Warns when buttons with conditional onPressed don't customize disabled style.
///
/// While Flutter buttons have default disabled styling, custom styles
/// provide better UX consistency across your app's design system.
///
/// Note: This rule suggests customization, not requirement. The default
/// disabled styling is functional but may not match your design.
///
/// **BAD:**
/// ```dart
/// ElevatedButton(
///   onPressed: canSubmit ? submit : null,
///   child: Text('Submit'),
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// ElevatedButton(
///   onPressed: canSubmit ? submit : null,
///   style: ElevatedButton.styleFrom(
///     disabledBackgroundColor: Colors.grey.shade300,
///   ),
///   child: Text('Submit'),
/// )
/// ```
class RequireDisabledStateRule extends SaropaLintRule {
  const RequireDisabledStateRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'require_disabled_state',
    problemMessage:
        'Consider customizing disabled style for design consistency.',
    correctionMessage:
        'Add style with disabledBackgroundColor/disabledForegroundColor.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  static const Set<String> _buttonWidgets = <String>{
    'ElevatedButton',
    'TextButton',
    'OutlinedButton',
    'FilledButton',
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
      if (!_buttonWidgets.contains(typeName)) return;

      bool hasConditionalOnPressed = false;
      bool hasStyleHandling = false;

      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression) {
          final String argName = arg.name.label.name;

          if (argName == 'onPressed') {
            final String source = arg.expression.toSource();
            // Check for conditional pattern: condition ? fn : null
            if (source.contains('?') && source.contains('null')) {
              hasConditionalOnPressed = true;
            }
          }

          if (argName == 'style') {
            hasStyleHandling = true;
          }
        }
      }

      if (hasConditionalOnPressed && !hasStyleHandling) {
        reporter.atNode(node.constructorName, code);
      }
    });
  }
}

/// Warns when Draggable doesn't have feedback widget.
///
/// Feedback provides visual indication during drag operations.
///
/// **BAD:**
/// ```dart
/// Draggable(
///   data: item,
///   child: ItemWidget(item),
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// Draggable(
///   data: item,
///   feedback: Material(child: ItemWidget(item)),
///   child: ItemWidget(item),
/// )
/// ```
class RequireDragFeedbackRule extends SaropaLintRule {
  const RequireDragFeedbackRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'require_drag_feedback',
    problemMessage: 'Draggable should have feedback widget.',
    correctionMessage: 'Add feedback: Widget to show during drag.',
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
      if (typeName != 'Draggable' && typeName != 'LongPressDraggable') return;

      bool hasFeedback = false;
      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression && arg.name.label.name == 'feedback') {
          hasFeedback = true;
          break;
        }
      }

      if (!hasFeedback) {
        reporter.atNode(node.constructorName, code);
      }
    });
  }
}

/// Warns when GestureDetector widgets are nested, causing gesture conflicts.
///
/// Nested GestureDetectors can cause unexpected behavior as gestures
/// compete with each other.
///
/// **BAD:**
/// ```dart
/// GestureDetector(
///   onTap: handleOuterTap,
///   child: GestureDetector(
///     onTap: handleInnerTap, // Conflicts with outer!
///     child: Content(),
///   ),
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// GestureDetector(
///   onTap: handleTap,
///   child: Content(),
/// )
/// ```
class AvoidGestureConflictRule extends SaropaLintRule {
  const AvoidGestureConflictRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_gesture_conflict',
    problemMessage:
        'Nested GestureDetector widgets may cause gesture conflicts.',
    correctionMessage: 'Consolidate gesture handling or use behavior property.',
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
      if (typeName != 'GestureDetector' && typeName != 'InkWell') return;

      // Check if inside another GestureDetector
      AstNode? current = node.parent;
      int depth = 0;
      while (current != null && depth < 20) {
        if (current is InstanceCreationExpression) {
          final String parentType = current.constructorName.type.name.lexeme;
          if (parentType == 'GestureDetector' || parentType == 'InkWell') {
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

/// Warns when large images are loaded without size constraints.
///
/// Loading large images without constraints wastes memory.
///
/// **BAD:**
/// ```dart
/// Image.asset('large_photo.png') // Could be 4000x3000 pixels!
/// ```
///
/// **GOOD:**
/// ```dart
/// Image.asset(
///   'large_photo.png',
///   width: 300,
///   height: 200,
///   cacheWidth: 300,
/// )
/// ```
class AvoidLargeImagesInMemoryRule extends SaropaLintRule {
  const AvoidLargeImagesInMemoryRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_large_images_in_memory',
    problemMessage: 'Image should specify size constraints to save memory.',
    correctionMessage:
        'Add width/height and cacheWidth/cacheHeight parameters.',
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

      // Check Image.asset and Image.network
      if (typeName != 'Image') return;
      if (constructorName != 'asset' && constructorName != 'network') return;

      bool hasWidth = false;
      bool hasHeight = false;
      bool hasCacheWidth = false;

      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression) {
          final String argName = arg.name.label.name;
          if (argName == 'width') hasWidth = true;
          if (argName == 'height') hasHeight = true;
          if (argName == 'cacheWidth' || argName == 'cacheHeight') {
            hasCacheWidth = true;
          }
        }
      }

      // Warn if no size constraints at all
      if (!hasWidth && !hasHeight && !hasCacheWidth) {
        reporter.atNode(node.constructorName, code);
      }
    });
  }
}

/// Warns when LayoutBuilder is used inside a scrollable widget.
///
/// LayoutBuilder in a scrollable can cause performance issues as
/// it rebuilds on every scroll.
///
/// **BAD:**
/// ```dart
/// ListView(
///   children: [
///     LayoutBuilder(builder: (context, constraints) => ...),
///   ],
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// LayoutBuilder(
///   builder: (context, constraints) => ListView(
///     children: [...],
///   ),
/// )
/// ```
class AvoidLayoutBuilderInScrollableRule extends SaropaLintRule {
  const AvoidLayoutBuilderInScrollableRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_layout_builder_in_scrollable',
    problemMessage:
        'LayoutBuilder inside scrollable causes performance issues.',
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

  static const LintCode _code = LintCode(
    name: 'prefer_intrinsic_dimensions',
    problemMessage:
        'Consider using IntrinsicWidth/Height for content-based sizing.',
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
class PreferActionsAndShortcutsRule extends SaropaLintRule {
  const PreferActionsAndShortcutsRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'prefer_actions_and_shortcuts',
    problemMessage:
        'Use Actions/Shortcuts system instead of RawKeyboardListener.',
    correctionMessage: 'Replace with Shortcuts and Actions widgets.',
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
      if (typeName == 'RawKeyboardListener' || typeName == 'KeyboardListener') {
        reporter.atNode(node.constructorName, code);
      }
    });
  }
}

/// Warns when GestureDetector doesn't handle long press for context menus.
///
/// Long press is a common pattern for showing context menus on mobile.
///
/// **BAD:**
/// ```dart
/// GestureDetector(
///   onTap: () => selectItem(),
///   child: ListTile(...),
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// GestureDetector(
///   onTap: () => selectItem(),
///   onLongPress: () => showContextMenu(),
///   child: ListTile(...),
/// )
/// ```
class RequireLongPressCallbackRule extends SaropaLintRule {
  const RequireLongPressCallbackRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'require_long_press_callback',
    problemMessage: 'Consider adding onLongPress for context menu.',
    correctionMessage: 'Add onLongPress callback for additional actions.',
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
      if (typeName != 'GestureDetector' && typeName != 'InkWell') return;

      bool hasOnTap = false;
      bool hasOnLongPress = false;

      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression) {
          final String argName = arg.name.label.name;
          if (argName == 'onTap') hasOnTap = true;
          if (argName == 'onLongPress') hasOnLongPress = true;
        }
      }

      // Only suggest if has onTap but no onLongPress, and is on a list item
      if (hasOnTap && !hasOnLongPress) {
        // Check if child is a list-like item
        for (final Expression arg in node.argumentList.arguments) {
          if (arg is NamedExpression && arg.name.label.name == 'child') {
            final String childSource = arg.expression.toSource();
            if (childSource.contains('ListTile') ||
                childSource.contains('Card') ||
                childSource.contains('Item')) {
              reporter.atNode(node.constructorName, code);
            }
          }
        }
      }
    });
  }
}

/// Warns when findChildIndexCallback is called in build method.
///
/// Creating a new callback in build causes unnecessary rebuilds.
///
/// **BAD:**
/// ```dart
/// ListView.builder(
///   findChildIndexCallback: (key) => items.indexWhere(...),
///   itemBuilder: ...,
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// // Define callback outside build or use memoization
/// final _findChildIndex = (Key key) => ...;
///
/// ListView.builder(
///   findChildIndexCallback: _findChildIndex,
///   itemBuilder: ...,
/// )
/// ```
class AvoidFindChildInBuildRule extends SaropaLintRule {
  const AvoidFindChildInBuildRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_find_child_in_build',
    problemMessage: 'findChildIndexCallback should not be created in build.',
    correctionMessage: 'Extract callback to a field or use memoization.',
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
      if (typeName != 'ListView' && typeName != 'GridView') return;

      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression &&
            arg.name.label.name == 'findChildIndexCallback') {
          // Check if it's a lambda defined inline
          if (arg.expression is FunctionExpression) {
            // Check if we're in a build method
            AstNode? current = node.parent;
            while (current != null) {
              if (current is MethodDeclaration &&
                  current.name.lexeme == 'build') {
                reporter.atNode(arg, code);
                return;
              }
              current = current.parent;
            }
          }
        }
      }
    });
  }
}

/// Warns when Column/Row is used inside SingleChildScrollView without constraints.
///
/// Without proper constraints, Column/Row may have unbounded height/width.
///
/// **BAD:**
/// ```dart
/// SingleChildScrollView(
///   child: Column(
///     children: [Expanded(child: Container())], // Expanded won't work!
///   ),
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// SingleChildScrollView(
///   child: ConstrainedBox(
///     constraints: BoxConstraints(minHeight: viewportHeight),
///     child: Column(children: [...]),
///   ),
/// )
/// ```
class AvoidUnboundedConstraintsRule extends SaropaLintRule {
  const AvoidUnboundedConstraintsRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_unbounded_constraints',
    problemMessage:
        'Column/Row in SingleChildScrollView may have unbounded constraints.',
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

      // Check if inside SingleChildScrollView
      AstNode? current = node.parent;
      bool insideSingleChildScrollView = false;
      bool hasConstrainedBox = false;

      while (current != null) {
        if (current is InstanceCreationExpression) {
          final String parentType = current.constructorName.type.name.lexeme;
          if (parentType == 'SingleChildScrollView') {
            insideSingleChildScrollView = true;
          }
          if (parentType == 'ConstrainedBox' ||
              parentType == 'SizedBox' ||
              parentType == 'Container') {
            hasConstrainedBox = true;
          }
        }
        current = current.parent;
      }

      if (insideSingleChildScrollView && !hasConstrainedBox) {
        // Check if has Expanded/Flexible children
        for (final Expression arg in node.argumentList.arguments) {
          if (arg is NamedExpression && arg.name.label.name == 'children') {
            final String childrenSource = arg.expression.toSource();
            if (childrenSource.contains('Expanded') ||
                childrenSource.contains('Flexible')) {
              reporter.atNode(node.constructorName, code);
              return;
            }
          }
        }
      }
    });
  }
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

  static const LintCode _code = LintCode(
    name: 'prefer_fractional_sizing',
    problemMessage: 'Use FractionallySizedBox for percentage-based sizing.',
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
      if ((leftSource.contains('MediaQuery') &&
              leftSource.contains('.size.')) ||
          (rightSource.contains('MediaQuery') &&
              rightSource.contains('.size.'))) {
        // Check if multiplying by a fraction
        if (node.rightOperand is DoubleLiteral) {
          final double value = (node.rightOperand as DoubleLiteral).value;
          if (value > 0 && value < 1) {
            reporter.atNode(node, code);
          }
        }
        if (node.leftOperand is DoubleLiteral) {
          final double value = (node.leftOperand as DoubleLiteral).value;
          if (value > 0 && value < 1) {
            reporter.atNode(node, code);
          }
        }
      }
    });
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
        'UnconstrainedBox in constrained parent may cause overflow.',
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
class RequireErrorWidgetRule extends SaropaLintRule {
  const RequireErrorWidgetRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'require_error_widget',
    problemMessage: 'FutureBuilder/StreamBuilder should handle error state.',
    correctionMessage: 'Add error handling: if (snapshot.hasError) ...',
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
      if (typeName != 'FutureBuilder' && typeName != 'StreamBuilder') return;

      // Find the builder argument
      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression && arg.name.label.name == 'builder') {
          final String builderSource = arg.expression.toSource();

          // Check if it handles errors
          if (!builderSource.contains('hasError') &&
              !builderSource.contains('.error')) {
            reporter.atNode(node.constructorName, code);
          }
          return;
        }
      }
    });
  }
}

/// Warns when AppBar is used inside CustomScrollView instead of SliverAppBar.
///
/// SliverAppBar enables collapsing/expanding behavior in scroll views.
///
/// **BAD:**
/// ```dart
/// CustomScrollView(
///   slivers: [
///     SliverToBoxAdapter(child: AppBar(title: Text('Title'))),
///     SliverList(...),
///   ],
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// CustomScrollView(
///   slivers: [
///     SliverAppBar(title: Text('Title'), floating: true),
///     SliverList(...),
///   ],
/// )
/// ```
class PreferSliverAppBarRule extends SaropaLintRule {
  const PreferSliverAppBarRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'prefer_sliver_app_bar',
    problemMessage: 'Use SliverAppBar inside CustomScrollView, not AppBar.',
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

  static const LintCode _code = LintCode(
    name: 'avoid_opacity_misuse',
    problemMessage: 'Use AnimatedOpacity for opacity animations.',
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

  static const LintCode _code = LintCode(
    name: 'prefer_clip_behavior',
    problemMessage: 'Consider specifying clipBehavior for performance.',
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
    problemMessage: 'Consider adding ScrollController for scroll tracking.',
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

  static const LintCode _code = LintCode(
    name: 'prefer_positioned_directional',
    problemMessage: 'Use PositionedDirectional for RTL support.',
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

/// Warns when Stack children may cause overflow without positioning.
///
/// Stack children without Positioned/Align may not layout as expected.
///
/// **BAD:**
/// ```dart
/// Stack(
///   children: [
///     Container(color: Colors.red),
///     Text('Overlay'), // May be positioned unexpectedly
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
class AvoidStackOverflowRule extends SaropaLintRule {
  const AvoidStackOverflowRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_stack_overflow',
    problemMessage: 'Stack children should use Positioned or Align.',
    correctionMessage: 'Wrap child with Positioned, Align, or Center.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  static const Set<String> _positioningWidgets = <String>{
    'Positioned',
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

      // Check children
      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression && arg.name.label.name == 'children') {
          final Expression childrenExpr = arg.expression;
          if (childrenExpr is ListLiteral) {
            // Skip if only one child (stack sizing behavior)
            if (childrenExpr.elements.length <= 1) return;

            int unpositionedCount = 0;
            for (final CollectionElement element in childrenExpr.elements) {
              if (element is InstanceCreationExpression) {
                final String childType =
                    element.constructorName.type.name.lexeme;
                if (!_positioningWidgets.contains(childType)) {
                  unpositionedCount++;
                }
              }
            }

            // Warn if multiple unpositioned children
            if (unpositionedCount > 1) {
              reporter.atNode(node.constructorName, code);
            }
          }
        }
      }
    });
  }
}

/// Warns when Form with TextFormField doesn't have validators.
///
/// Forms should validate input for better UX.
///
/// **BAD:**
/// ```dart
/// Form(
///   child: TextFormField(
///     decoration: InputDecoration(labelText: 'Email'),
///   ),
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// Form(
///   child: TextFormField(
///     decoration: InputDecoration(labelText: 'Email'),
///     validator: (value) {
///       if (value?.isEmpty ?? true) return 'Email is required';
///       return null;
///     },
///   ),
/// )
/// ```
class RequireFormValidationRule extends SaropaLintRule {
  const RequireFormValidationRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'require_form_validation',
    problemMessage: 'TextFormField in Form should have a validator.',
    correctionMessage: 'Add validator: (value) => ... to validate input.',
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
      if (typeName != 'TextFormField') return;

      // Check if inside a Form
      bool insideForm = false;
      AstNode? current = node.parent;
      while (current != null) {
        if (current is InstanceCreationExpression) {
          final String parentType = current.constructorName.type.name.lexeme;
          if (parentType == 'Form') {
            insideForm = true;
            break;
          }
        }
        current = current.parent;
      }

      if (!insideForm) return;

      // Check if has validator
      bool hasValidator = false;
      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression && arg.name.label.name == 'validator') {
          hasValidator = true;
          break;
        }
      }

      if (!hasValidator) {
        reporter.atNode(node.constructorName, code);
      }
    });
  }
}

/// Warns when ListView/GridView uses `shrinkWrap: true` inside a scrollable.
///
/// Using `shrinkWrap: true` forces the list to calculate the size of all
/// children at once, which defeats lazy loading and causes O(n) layout cost.
/// This is particularly problematic for large lists.
///
/// **BAD:**
/// ```dart
/// ListView(
///   shrinkWrap: true,
///   children: items.map((item) => ListTile(title: Text(item))).toList(),
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// ListView.builder(
///   itemCount: items.length,
///   itemBuilder: (context, index) => ListTile(title: Text(items[index])),
/// )
/// ```
///
/// **Also OK (for small fixed lists):**
/// ```dart
/// ListView(
///   children: [
///     ListTile(title: Text('Item 1')),
///     ListTile(title: Text('Item 2')),
///   ],
/// )
/// ```
class AvoidShrinkWrapInScrollRule extends SaropaLintRule {
  const AvoidShrinkWrapInScrollRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_shrink_wrap_in_scroll',
    problemMessage:
        'shrinkWrap: true causes O(n) layout cost and defeats lazy loading.',
    correctionMessage:
        'Use ListView.builder with itemCount for lazy loading, or remove '
        'shrinkWrap if not needed.',
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

  static const LintCode _code = LintCode(
    name: 'avoid_deep_widget_nesting',
    problemMessage: 'Widget tree exceeds 15 levels of nesting.',
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

  static const LintCode _code = LintCode(
    name: 'prefer_safe_area_aware',
    problemMessage: 'Content may overlap device notch or system UI.',
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

  static const LintCode _code = LintCode(
    name: 'avoid_fixed_dimensions',
    problemMessage: 'Fixed pixel dimensions may not work on all screen sizes.',
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
class RequireThemeColorFromSchemeRule extends SaropaLintRule {
  const RequireThemeColorFromSchemeRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'require_theme_color_from_scheme',
    problemMessage:
        'Hardcoded color breaks theming. Use Theme.of(context).colorScheme.',
    correctionMessage:
        'Replace with colorScheme.primary, .secondary, .surface, etc.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    // Check for Color(0x...) hardcoded colors
    context.registry.addInstanceCreationExpression((
      InstanceCreationExpression node,
    ) {
      final String typeName = node.constructorName.type.name.lexeme;
      if (typeName != 'Color') return;

      // Skip if in theme definition file
      final String filePath = resolver.source.fullName.toLowerCase();
      if (filePath.contains('theme') || filePath.contains('color')) return;

      // Check for hex literal
      if (node.argumentList.arguments.isNotEmpty) {
        final Expression firstArg = node.argumentList.arguments.first;
        if (firstArg is IntegerLiteral) {
          reporter.atNode(node, code);
        }
      }
    });

    // Check for Colors.* constants
    context.registry.addPrefixedIdentifier((PrefixedIdentifier node) {
      if (node.prefix.name != 'Colors') return;

      // Skip Colors.transparent - commonly used and valid
      if (node.identifier.name == 'transparent') return;

      // Skip if in theme definition
      final String filePath = resolver.source.fullName.toLowerCase();
      if (filePath.contains('theme') || filePath.contains('color')) return;

      // Common colors that should come from theme
      final Set<String> semanticColors = <String>{
        'blue',
        'red',
        'green',
        'orange',
        'purple',
        'grey',
        'black',
        'white',
      };

      final String colorName = node.identifier.name.toLowerCase();
      if (semanticColors.any((String c) => colorName.startsWith(c))) {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when ColorScheme is created manually instead of using fromSeed.
///
/// ColorScheme.fromSeed generates a harmonious, accessible color palette
/// from a single seed color. Manual ColorScheme is error-prone and often
/// has accessibility issues.
///
/// **BAD:**
/// ```dart
/// ColorScheme(
///   primary: Color(0xFF6750A4),
///   onPrimary: Colors.white,
///   secondary: Color(0xFF625B71),
///   // 15+ more colors to define manually...
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// ColorScheme.fromSeed(
///   seedColor: Color(0xFF6750A4),
///   brightness: Brightness.light,
/// )
/// ```
class PreferColorSchemeFromSeedRule extends SaropaLintRule {
  const PreferColorSchemeFromSeedRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'prefer_color_scheme_from_seed',
    problemMessage:
        'Manual ColorScheme is error-prone. Use ColorScheme.fromSeed.',
    correctionMessage:
        'ColorScheme.fromSeed(seedColor: yourPrimary) generates accessible palettes.',
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
      final String? constructorName = node.constructorName.type.element?.name;
      final String? namedConstructor = node.constructorName.name?.name;

      // Only flag default constructor, not fromSeed/fromSwatch
      if (constructorName != 'ColorScheme') return;
      if (namedConstructor != null) return; // fromSeed, light, dark, etc.

      // Check if it has many color arguments (indicating manual definition)
      int colorArgs = 0;
      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression) {
          final String name = arg.name.label.name;
          if (name.startsWith('on') ||
              name == 'primary' ||
              name == 'secondary' ||
              name == 'tertiary' ||
              name == 'surface' ||
              name == 'error' ||
              name == 'background' ||
              name == 'outline') {
            colorArgs++;
          }
        }
      }

      // If defining 4+ colors manually, suggest fromSeed
      if (colorArgs >= 4) {
        reporter.atNode(node.constructorName, code);
      }
    });
  }
}

/// Warns when multiple adjacent Text widgets could use Text.rich or RichText.
///
/// Multiple Text widgets in a Row or Wrap for styled text is inefficient.
/// Use Text.rich with TextSpan children for mixed styling.
///
/// **BAD:**
/// ```dart
/// Row(
///   children: [
///     Text('Hello ', style: TextStyle(fontWeight: FontWeight.bold)),
///     Text('world', style: TextStyle(color: Colors.blue)),
///     Text('!', style: TextStyle(fontSize: 20)),
///   ],
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// Text.rich(
///   TextSpan(
///     children: [
///       TextSpan(text: 'Hello ', style: TextStyle(fontWeight: FontWeight.bold)),
///       TextSpan(text: 'world', style: TextStyle(color: Colors.blue)),
///       TextSpan(text: '!', style: TextStyle(fontSize: 20)),
///     ],
///   ),
/// )
/// ```
class PreferRichTextForComplexRule extends SaropaLintRule {
  const PreferRichTextForComplexRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'prefer_rich_text_for_complex',
    problemMessage:
        'Multiple Text widgets in row could be combined with Text.rich.',
    correctionMessage:
        'Use Text.rich with TextSpan children for better performance and line wrapping.',
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
      final String? typeName = node.constructorName.type.element?.name;
      if (typeName != 'Row' && typeName != 'Wrap') return;

      // Find children argument
      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression && arg.name.label.name == 'children') {
          final Expression childrenExpr = arg.expression;
          if (childrenExpr is ListLiteral) {
            int textWidgetCount = 0;

            for (final CollectionElement element in childrenExpr.elements) {
              if (element is Expression) {
                if (element is InstanceCreationExpression) {
                  final String? childType =
                      element.constructorName.type.element?.name;
                  if (childType == 'Text') {
                    textWidgetCount++;
                  }
                }
              }
            }

            // If 3+ adjacent Text widgets, suggest Text.rich
            if (textWidgetCount >= 3) {
              reporter.atNode(node.constructorName, code);
            }
          }
        }
      }
    });
  }
}
