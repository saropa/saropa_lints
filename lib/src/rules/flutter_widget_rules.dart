// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart' show DiagnosticSeverity;
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

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
class AvoidContextInInitStateDisposeRule extends DartLintRule {
  const AvoidContextInInitStateDisposeRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_context_in_initstate_dispose',
    problemMessage: "Avoid using 'context' in initState or dispose. "
        'The widget may not be mounted.',
    correctionMessage: 'Use WidgetsBinding.instance.addPostFrameCallback to defer '
        'context access until after the widget is mounted.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
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
class AvoidEmptySetStateRule extends DartLintRule {
  const AvoidEmptySetStateRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_empty_setstate',
    problemMessage: 'Empty setState callback has no effect.',
    correctionMessage: 'Add state changes or remove the setState call.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
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
class AvoidExpandedAsSpacerRule extends DartLintRule {
  const AvoidExpandedAsSpacerRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_expanded_as_spacer',
    problemMessage: 'Use Spacer() instead of Expanded with empty child.',
    correctionMessage: 'Replace Expanded(child: SizedBox/Container()) with Spacer().',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addInstanceCreationExpression((InstanceCreationExpression node) {
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
                (Expression e) => e is NamedExpression && e.name.label.name == 'child',
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
class AvoidFlexibleOutsideFlexRule extends DartLintRule {
  const AvoidFlexibleOutsideFlexRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_flexible_outside_flex',
    problemMessage: 'Flexible/Expanded used outside of Row, Column, or Flex.',
    correctionMessage: 'Flexible and Expanded only work inside Row, Column, or Flex widgets.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  static const Set<String> _flexibleWidgets = <String>{'Flexible', 'Expanded'};
  static const Set<String> _flexWidgets = <String>{'Row', 'Column', 'Flex'};

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addInstanceCreationExpression((
      InstanceCreationExpression node,
    ) {
      final String? constructorName = node.constructorName.type.element?.name;
      if (constructorName == null || !_flexibleWidgets.contains(constructorName)) {
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
class AvoidIncorrectImageOpacityRule extends DartLintRule {
  const AvoidIncorrectImageOpacityRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_incorrect_image_opacity',
    problemMessage: 'Image wrapped in Opacity. Use Image color property instead.',
    correctionMessage: 'Use Image.color with colorBlendMode for better performance.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addInstanceCreationExpression((InstanceCreationExpression node) {
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
class AvoidLateContextRule extends DartLintRule {
  const AvoidLateContextRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_late_context',
    problemMessage: 'Avoid using BuildContext in late field initializers.',
    correctionMessage: 'Initialize in didChangeDependencies() or build() instead.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
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
class AvoidMisnamedPaddingRule extends DartLintRule {
  const AvoidMisnamedPaddingRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_misnamed_padding',
    problemMessage: 'Parameter named "padding" is used as margin '
        '(via Padding widget or .withPadding()).',
    correctionMessage: 'Consider renaming to "margin" to reflect actual usage.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
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
class AvoidMissingImageAltRule extends DartLintRule {
  const AvoidMissingImageAltRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_missing_image_alt',
    problemMessage: 'Image is missing semanticLabel for accessibility.',
    correctionMessage: 'Add semanticLabel parameter for screen reader support.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addInstanceCreationExpression((InstanceCreationExpression node) {
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

  void _checkForSemanticLabel(InstanceCreationExpression node, DiagnosticReporter reporter) {
    final bool hasSemanticLabel = node.argumentList.arguments.any(
      (Expression arg) => arg is NamedExpression && arg.name.label.name == 'semanticLabel',
    );

    if (!hasSemanticLabel) {
      reporter.atNode(node, code);
    }
  }

  void _checkForSemanticLabelInMethod(MethodInvocation node, DiagnosticReporter reporter) {
    final bool hasSemanticLabel = node.argumentList.arguments.any(
      (Expression arg) => arg is NamedExpression && arg.name.label.name == 'semanticLabel',
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
class AvoidMountedInSetStateRule extends DartLintRule {
  const AvoidMountedInSetStateRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_mounted_in_setstate',
    problemMessage: 'Avoid checking mounted inside setState callback.',
    correctionMessage: 'Check mounted before calling setState instead.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
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
class AvoidReturningWidgetsRule extends DartLintRule {
  const AvoidReturningWidgetsRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_returning_widgets',
    problemMessage: 'Avoid methods that return widgets.',
    correctionMessage: 'Extract to a separate Widget class.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
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
class AvoidShrinkWrapInListsRule extends DartLintRule {
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
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addInstanceCreationExpression((InstanceCreationExpression node) {
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
              final String? parentConstructor = parent.constructorName.type.element?.name;
              if (parentConstructor != null && _scrollableWidgets.contains(parentConstructor)) {
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
class AvoidSingleChildColumnRowRule extends DartLintRule {
  const AvoidSingleChildColumnRowRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_single_child_column_row',
    problemMessage: 'Column/Row with single child is unnecessary.',
    correctionMessage: 'Use the child directly or Align/Center for alignment.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addInstanceCreationExpression((InstanceCreationExpression node) {
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
class AvoidStateConstructorsRule extends DartLintRule {
  const AvoidStateConstructorsRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_state_constructors',
    problemMessage: 'State class should not have constructor body.',
    correctionMessage: 'Use initState() for initialization instead.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
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
class AvoidStatelessWidgetInitializedFieldsRule extends DartLintRule {
  const AvoidStatelessWidgetInitializedFieldsRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_stateless_widget_initialized_fields',
    problemMessage: 'StatelessWidget should not have initialized fields.',
    correctionMessage: 'Pass values through the constructor instead.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
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
class AvoidUnnecessaryGestureDetectorRule extends DartLintRule {
  const AvoidUnnecessaryGestureDetectorRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_unnecessary_gesture_detector',
    problemMessage: 'GestureDetector has no gesture callbacks defined.',
    correctionMessage: 'Add gesture callbacks or remove the GestureDetector wrapper.',
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
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addInstanceCreationExpression((InstanceCreationExpression node) {
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
class AvoidUnnecessarySetStateRule extends DartLintRule {
  const AvoidUnnecessarySetStateRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_unnecessary_setstate',
    problemMessage: 'setState called in lifecycle method where not needed.',
    correctionMessage: 'In initState/dispose, modify state directly without setState.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  static const Set<String> _lifecycleMethods = <String>{
    'initState',
    'dispose',
    'didChangeDependencies',
  };

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
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
class AvoidUnnecessaryStatefulWidgetsRule extends DartLintRule {
  const AvoidUnnecessaryStatefulWidgetsRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_unnecessary_stateful_widgets',
    problemMessage: 'StatefulWidget may be unnecessary.',
    correctionMessage: 'Consider using StatelessWidget if no mutable state is needed.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
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
class AvoidUnremovableCallbacksInListenersRule extends DartLintRule {
  const AvoidUnremovableCallbacksInListenersRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_unremovable_callbacks_in_listeners',
    problemMessage: 'Anonymous function cannot be removed from listener.',
    correctionMessage: 'Use a named function or store reference to remove later.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  static const List<String> _listenerMethods = <String>[
    'addListener',
    'addPostFrameCallback',
    'addPersistentFrameCallback',
    'addTimingsCallback',
  ];

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
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
class AvoidUnsafeSetStateRule extends DartLintRule {
  const AvoidUnsafeSetStateRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_unsafe_setstate',
    problemMessage: 'setState() called without a mounted check.',
    correctionMessage: 'Wrap in `if (mounted)` or use `mounted ? setState(...) : null`.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
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
class AvoidWrappingInPaddingRule extends DartLintRule {
  const AvoidWrappingInPaddingRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_wrapping_in_padding',
    problemMessage: 'Widget has its own padding property, avoid wrapping in Padding.',
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
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addInstanceCreationExpression((InstanceCreationExpression node) {
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
class CheckForEqualsInRenderObjectSettersRule extends DartLintRule {
  const CheckForEqualsInRenderObjectSettersRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'check_for_equals_in_render_object_setters',
    problemMessage: 'RenderObject setter should check equality before updating.',
    correctionMessage: 'Add equality check: if (_field == value) return; before assignment.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
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

  void _checkSetter(MethodDeclaration setter, DiagnosticReporter reporter) {
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
class ConsistentUpdateRenderObjectRule extends DartLintRule {
  const ConsistentUpdateRenderObjectRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'consistent_update_render_object',
    problemMessage: 'updateRenderObject may be missing property updates from createRenderObject.',
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
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
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
      final Set<String> missingProperties = createProperties.difference(updateProperties);
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
class PreferConstBorderRadiusRule extends DartLintRule {
  const PreferConstBorderRadiusRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'prefer_const_border_radius',
    problemMessage: 'Prefer const BorderRadius.all for constant border radius.',
    correctionMessage: 'Use const BorderRadius.all(Radius.circular(x)) instead.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
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
class PreferCorrectEdgeInsetsConstructorRule extends DartLintRule {
  const PreferCorrectEdgeInsetsConstructorRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'prefer_correct_edge_insets_constructor',
    problemMessage: 'Consider using a more specific EdgeInsets constructor.',
    correctionMessage: 'Use .all() for equal values or .symmetric() for symmetric values.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addInstanceCreationExpression((InstanceCreationExpression node) {
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

  void _checkFromLTRB(InstanceCreationExpression node, DiagnosticReporter reporter) {
    final NodeList<Expression> args = node.argumentList.arguments;
    if (args.length != 4) return;

    // Get all values as strings
    final List<String> values = args.map((Expression e) => e.toSource()).toList();

    // Check if all values are the same (could use .all)
    if (values.toSet().length == 1) {
      reporter.atNode(node, code);
    }
    // Check if left==right and top==bottom (could use .symmetric)
    else if (values[0] == values[2] && values[1] == values[3]) {
      reporter.atNode(node, code);
    }
  }

  void _checkOnly(InstanceCreationExpression node, DiagnosticReporter reporter) {
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
    final List<String?> presentValues =
        <String?>[left, right, top, bottom].where((String? v) => v != null).toList();
    if (presentValues.length == 4 && presentValues.toSet().length == 1) {
      reporter.atNode(node, code);
    }
    // Check for symmetric patterns
    else if (left != null && right != null && left == right && top == null && bottom == null) {
      reporter.atNode(node, code);
    } else if (top != null && bottom != null && top == bottom && left == null && right == null) {
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
class PreferDefineHeroTagRule extends DartLintRule {
  const PreferDefineHeroTagRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'prefer_define_hero_tag',
    problemMessage: 'Hero widget should have an explicit tag.',
    correctionMessage: 'Add a tag parameter to the Hero widget.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addInstanceCreationExpression((InstanceCreationExpression node) {
      final String typeName = node.constructorName.type.name.lexeme;
      if (typeName != 'Hero') return;

      // Check if tag is defined
      final bool hasTag = node.argumentList.arguments.any(
        (Expression arg) => arg is NamedExpression && arg.name.label.name == 'tag',
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
class PreferExtractingCallbacksRule extends DartLintRule {
  const PreferExtractingCallbacksRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'prefer_extracting_callbacks',
    problemMessage: 'Consider extracting this callback to a method.',
    correctionMessage: 'Extract long callbacks to named methods.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
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
class PreferSingleWidgetPerFileRule extends DartLintRule {
  const PreferSingleWidgetPerFileRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'prefer_single_widget_per_file',
    problemMessage: 'File contains multiple public widget classes.',
    correctionMessage: 'Move each public widget to its own file.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
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
class PreferSliverPrefixRule extends DartLintRule {
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
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
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
        if (_sliverBaseClasses.contains(superclass) || superclass.startsWith('Sliver')) {
          reporter.atNode(node, code);
          return;
        }
      }

      // Check implements clause
      final ImplementsClause? implementsClause = node.implementsClause;
      if (implementsClause != null) {
        for (final NamedType interface in implementsClause.interfaces) {
          final String interfaceName = interface.name.lexeme;
          if (_sliverBaseClasses.contains(interfaceName) || interfaceName.startsWith('Sliver')) {
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
          if (_sliverBaseClasses.contains(mixinName) || mixinName.startsWith('Sliver')) {
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
class PreferTextRichRule extends DartLintRule {
  const PreferTextRichRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'prefer_text_rich',
    problemMessage: 'Prefer Text.rich over RichText widget.',
    correctionMessage: 'Use Text.rich(TextSpan(...)) instead of RichText(text: TextSpan(...)).',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addInstanceCreationExpression((InstanceCreationExpression node) {
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
class PreferUsingListViewRule extends DartLintRule {
  const PreferUsingListViewRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'prefer_using_list_view',
    problemMessage: 'Column inside SingleChildScrollView. Consider using ListView.',
    correctionMessage: 'Use ListView for better performance with scrollable lists.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addInstanceCreationExpression((InstanceCreationExpression node) {
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
class PreferWidgetPrivateMembersRule extends DartLintRule {
  const PreferWidgetPrivateMembersRule() : super(code: _codeField);

  static const LintCode _codeField = LintCode(
    name: 'prefer_widget_private_members',
    problemMessage: 'Widget field should be final.',
    correctionMessage: 'Make the field final or private.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  static const LintCode _codeMethod = LintCode(
    name: 'prefer_widget_private_members',
    problemMessage: 'Consider making this helper method private in Widget class.',
    correctionMessage: 'Prefix with underscore to make private.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  static const Set<String> _widgetBaseClasses = <String>{
    'StatelessWidget',
    'StatefulWidget',
  };

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
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
class RequireDisposeRule extends DartLintRule {
  const RequireDisposeRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'require_dispose',
    problemMessage: 'Disposable field may not be properly disposed.',
    correctionMessage: 'Add a dispose() method that disposes this field, '
        'or ensure the existing dispose() method handles it.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  /// Map of disposable type names to their disposal method
  static const Map<String, String> _disposableTypes = <String, String>{
    // Flutter Framework - Controllers
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
    // Flutter Framework - Focus
    'FocusNode': 'dispose',
    'FocusScopeNode': 'dispose',
    // Flutter Framework - Notifiers
    'ChangeNotifier': 'dispose',
    'ValueNotifier': 'dispose',
    // Dart Core
    'StreamSubscription': 'cancel',
    'StreamController': 'close',
    'Timer': 'cancel',
    // Common Packages
    'CameraController': 'dispose',
    'VideoPlayerController': 'dispose',
    'AudioPlayer': 'dispose',
    'WebViewController': 'dispose',
    'Bloc': 'close',
    'Cubit': 'close',
    // Riverpod
    'ProviderSubscription': 'close',
  };

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
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

      // Find the dispose method
      MethodDeclaration? disposeMethod;
      for (final ClassMember member in node.members) {
        if (member is MethodDeclaration && member.name.lexeme == 'dispose') {
          disposeMethod = member;
          break;
        }
      }

      // Get the dispose method body as string for checking
      String disposeBody = '';
      if (disposeMethod != null) {
        disposeBody = disposeMethod.body.toSource();
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
      '${name}Safe(',
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
class UseSetStateSynchronouslyRule extends DartLintRule {
  const UseSetStateSynchronouslyRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'use_setstate_synchronously',
    problemMessage: 'setState called after async gap without mounted check.',
    correctionMessage: 'Check mounted before calling setState after await.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
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

  void _reportSetStateInStatement(Statement stmt, DiagnosticReporter reporter) {
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
class AlwaysRemoveListenerRule extends DartLintRule {
  const AlwaysRemoveListenerRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'always_remove_listener',
    problemMessage: 'Listener added but may not be removed.',
    correctionMessage: 'Ensure the listener is removed in dispose() '
        'to prevent memory leaks.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
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
              removed.target == added.target && removed.callback == added.callback,
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
class AvoidBorderAllRule extends DartLintRule {
  const AvoidBorderAllRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_border_all',
    problemMessage: 'Prefer Border.fromBorderSide for const borders.',
    correctionMessage: 'Use const Border.fromBorderSide(BorderSide(...)) instead.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
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
class AvoidDeeplyNestedWidgetsRule extends DartLintRule {
  const AvoidDeeplyNestedWidgetsRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_deeply_nested_widgets',
    problemMessage: 'Widget tree is too deeply nested.',
    correctionMessage: 'Extract subtrees into separate widgets to improve readability.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  static const int _maxDepth = 8;

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodDeclaration((MethodDeclaration node) {
      if (node.name.lexeme != 'build') return;

      // Find nested widget depth
      final _WidgetDepthVisitor visitor = _WidgetDepthVisitor(_maxDepth, reporter, code);
      node.body.accept(visitor);
    });
  }
}

class _WidgetDepthVisitor extends RecursiveAstVisitor<void> {
  _WidgetDepthVisitor(this.maxDepth, this.reporter, this.code);

  final int maxDepth;
  final DiagnosticReporter reporter;
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
class RequireAnimationDisposalRule extends DartLintRule {
  const RequireAnimationDisposalRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'require_animation_disposal',
    problemMessage: 'AnimationController should be disposed.',
    correctionMessage: 'Add _controller.dispose() in the dispose() method.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
      // Find AnimationController fields
      final Set<String> animationControllerFields = <String>{};

      for (final ClassMember member in node.members) {
        if (member is FieldDeclaration) {
          final TypeAnnotation? type = member.fields.type;
          if (type is NamedType && type.name.lexeme == 'AnimationController') {
            for (final VariableDeclaration variable in member.fields.variables) {
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
              for (final VariableDeclaration variable in member.fields.variables) {
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

class _DisposeCallFinder extends RecursiveAstVisitor<void> {
  _DisposeCallFinder(this.onFound);
  final void Function(String) onFound;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.methodName.name == 'dispose') {
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
class AvoidUncontrolledTextFieldRule extends DartLintRule {
  const AvoidUncontrolledTextFieldRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_uncontrolled_text_field',
    problemMessage: 'TextField should have a controller for proper state management.',
    correctionMessage: 'Add a TextEditingController to the TextField.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addInstanceCreationExpression((InstanceCreationExpression node) {
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
class AvoidHardcodedAssetPathsRule extends DartLintRule {
  const AvoidHardcodedAssetPathsRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_hardcoded_asset_paths',
    problemMessage: 'Asset path should not be hardcoded.',
    correctionMessage: 'Use a constants class or generated assets for asset paths.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
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
        if (path != null && (path.contains('assets/') || path.contains('images/'))) {
          reporter.atNode(firstArg, code);
        }
      }
    });

    // Also check for AssetImage constructor
    context.registry.addInstanceCreationExpression((InstanceCreationExpression node) {
      final String typeName = node.constructorName.type.name.lexeme;
      if (typeName != 'AssetImage') return;

      final ArgumentList args = node.argumentList;
      if (args.arguments.isEmpty) return;

      final Expression firstArg = args.arguments.first;
      if (firstArg is StringLiteral) {
        final String? path = firstArg.stringValue;
        if (path != null && (path.contains('assets/') || path.contains('images/'))) {
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
class AvoidPrintInProductionRule extends DartLintRule {
  const AvoidPrintInProductionRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_print_in_production',
    problemMessage: 'Avoid using print() in production code.',
    correctionMessage: 'Use a proper logging framework instead.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
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
class AvoidCatchingGenericExceptionRule extends DartLintRule {
  const AvoidCatchingGenericExceptionRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_catching_generic_exception',
    problemMessage: 'Avoid catching generic exceptions.',
    correctionMessage: 'Catch specific exception types instead.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
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
        if (typeName == 'Exception' || typeName == 'Object' || typeName == 'dynamic') {
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
class AvoidServiceLocatorOveruseRule extends DartLintRule {
  const AvoidServiceLocatorOveruseRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_service_locator_overuse',
    problemMessage: 'Service locator call in widget. Prefer constructor injection.',
    correctionMessage: 'Pass dependencies through the constructor instead.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
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
      if (target.name == 'GetIt' || target.name == 'locator' || target.name == 'sl') {
        onFound(node);
      }
    } else if (target is PrefixedIdentifier) {
      if (target.identifier.name == 'I' || target.identifier.name == 'instance') {
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
class PreferUtcDateTimesRule extends DartLintRule {
  const PreferUtcDateTimesRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'prefer_utc_datetimes',
    problemMessage: 'Consider using UTC DateTime for storage/transmission.',
    correctionMessage: 'Use DateTime.now().toUtc() or DateTime.utc() for timestamps.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
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
class AvoidRegexInLoopRule extends DartLintRule {
  const AvoidRegexInLoopRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_regex_in_loop',
    problemMessage: 'RegExp created inside loop. Move it outside for efficiency.',
    correctionMessage: 'Create the RegExp once outside the loop.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
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
class PreferGetterOverMethodRule extends DartLintRule {
  const PreferGetterOverMethodRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'prefer_getter_over_method',
    problemMessage: 'Use a getter instead of a method that returns a value.',
    correctionMessage: 'Convert to a getter: get name => _name;',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
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
class AvoidUnusedCallbackParametersRule extends DartLintRule {
  const AvoidUnusedCallbackParametersRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_unused_callback_parameters',
    problemMessage: 'Callback parameter is declared but not used.',
    correctionMessage: 'Use underscore (_) for unused parameters.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
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
class PreferConstWidgetsInListsRule extends DartLintRule {
  const PreferConstWidgetsInListsRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'prefer_const_widgets_in_lists',
    problemMessage: 'Widget list could be const.',
    correctionMessage: 'Add const keyword to the list literal.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
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
        (expr is InstanceCreationExpression && expr.keyword?.type == Keyword.CONST);
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
class AvoidScaffoldMessengerAfterAwaitRule extends DartLintRule {
  const AvoidScaffoldMessengerAfterAwaitRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_scaffold_messenger_after_await',
    problemMessage: 'Using ScaffoldMessenger.of(context) after await may use an invalid context.',
    correctionMessage: 'Store ScaffoldMessenger.of(context) before the await.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
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
class AvoidBuildContextInProvidersRule extends DartLintRule {
  const AvoidBuildContextInProvidersRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_build_context_in_providers',
    problemMessage: 'Storing BuildContext in providers can cause memory leaks.',
    correctionMessage: 'Pass BuildContext as a method parameter when needed instead.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
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
class PreferSemanticWidgetNamesRule extends DartLintRule {
  const PreferSemanticWidgetNamesRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'prefer_semantic_widget_names',
    problemMessage: 'Consider using a more semantic widget.',
    correctionMessage:
        'Replace Container with a more specific widget like DecoratedBox, SizedBox, etc.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addInstanceCreationExpression((InstanceCreationExpression node) {
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
          } else if (usedProps.contains('width') || usedProps.contains('height')) {
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
class AvoidTextScaleFactorRule extends DartLintRule {
  const AvoidTextScaleFactorRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_text_scale_factor',
    problemMessage: 'textScaleFactor is deprecated.',
    correctionMessage: 'Use textScaler instead of textScaleFactor.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
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
class PreferWidgetStateMixinRule extends DartLintRule {
  const PreferWidgetStateMixinRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'prefer_widget_state_mixin',
    problemMessage: 'Consider using WidgetStateMixin for interaction states.',
    correctionMessage: 'Use WidgetStateMixin to manage hover, pressed, and focus states.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
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
class AvoidImageWithoutCacheRule extends DartLintRule {
  const AvoidImageWithoutCacheRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_image_without_cache',
    problemMessage: 'Image.network should specify cacheWidth/cacheHeight for memory efficiency.',
    correctionMessage: 'Add cacheWidth and/or cacheHeight parameters.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addInstanceCreationExpression((InstanceCreationExpression node) {
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
class PreferSplitWidgetConstRule extends DartLintRule {
  const PreferSplitWidgetConstRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'prefer_split_widget_const',
    problemMessage: 'Large widget subtree could be extracted to a const widget.',
    correctionMessage: 'Extract this subtree to a separate const widget for better performance.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addInstanceCreationExpression((InstanceCreationExpression node) {
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
class AvoidNavigatorPushWithoutRouteNameRule extends DartLintRule {
  const AvoidNavigatorPushWithoutRouteNameRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_navigator_push_without_route_name',
    problemMessage: 'Prefer named routes for better navigation management.',
    correctionMessage: 'Use Navigator.pushNamed or a routing package.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
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
class AvoidDuplicateWidgetKeysRule extends DartLintRule {
  const AvoidDuplicateWidgetKeysRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_duplicate_widget_keys',
    problemMessage: 'Duplicate widget keys found in list.',
    correctionMessage: 'Ensure each widget in a list has a unique key.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
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
class PreferSafeAreaConsumerRule extends DartLintRule {
  const PreferSafeAreaConsumerRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'prefer_safe_area_consumer',
    problemMessage: 'SafeArea may be redundant when used directly inside Scaffold body.',
    correctionMessage:
        'Scaffold already handles safe areas via its appBar and bottomNavigationBar properties.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addInstanceCreationExpression((InstanceCreationExpression node) {
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
class AvoidUnrestrictedTextFieldLengthRule extends DartLintRule {
  const AvoidUnrestrictedTextFieldLengthRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_unrestricted_text_field_length',
    problemMessage: 'TextField should have maxLength to prevent excessive input.',
    correctionMessage: 'Add maxLength parameter to limit input length.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addInstanceCreationExpression((InstanceCreationExpression node) {
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
class PreferScaffoldMessengerMaybeOfRule extends DartLintRule {
  const PreferScaffoldMessengerMaybeOfRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'prefer_scaffold_messenger_maybeof',
    problemMessage: 'Consider using ScaffoldMessenger.maybeOf for safer access.',
    correctionMessage:
        'Use maybeOf to handle cases where ScaffoldMessenger might not be available.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
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
class AvoidFormWithoutKeyRule extends DartLintRule {
  const AvoidFormWithoutKeyRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_form_without_key',
    problemMessage: 'Form widget should have a GlobalKey for validation.',
    correctionMessage: 'Add a GlobalKey<FormState> to the Form widget.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addInstanceCreationExpression((InstanceCreationExpression node) {
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
class AvoidListViewWithoutItemExtentRule extends DartLintRule {
  const AvoidListViewWithoutItemExtentRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_listview_without_item_extent',
    problemMessage: 'ListView.builder should specify itemExtent for better scroll performance.',
    correctionMessage: 'Add itemExtent or prototypeItem parameter.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addInstanceCreationExpression((InstanceCreationExpression node) {
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
class AvoidMediaQueryInBuildRule extends DartLintRule {
  const AvoidMediaQueryInBuildRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_mediaquery_in_build',
    problemMessage: 'Use specific MediaQuery methods instead of MediaQuery.of.',
    correctionMessage: 'Use MediaQuery.sizeOf, MediaQuery.paddingOf, etc. for better performance.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
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
class PreferSliverListDelegateRule extends DartLintRule {
  const PreferSliverListDelegateRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'prefer_sliver_list_delegate',
    problemMessage: 'Use SliverChildBuilderDelegate for better performance with large lists.',
    correctionMessage: 'Replace SliverChildListDelegate with SliverChildBuilderDelegate.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addInstanceCreationExpression((InstanceCreationExpression node) {
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
class AvoidLayoutBuilderMisuseRule extends DartLintRule {
  const AvoidLayoutBuilderMisuseRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_layout_builder_misuse',
    problemMessage: 'LayoutBuilder should use constraints in its builder.',
    correctionMessage: 'Ensure the builder actually uses the constraints parameter.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addInstanceCreationExpression((InstanceCreationExpression node) {
      final String typeName = node.constructorName.type.name.lexeme;

      if (typeName == 'LayoutBuilder') {
        for (final Expression arg in node.argumentList.arguments) {
          if (arg is NamedExpression && arg.name.label.name == 'builder') {
            final Expression builderExpr = arg.expression;
            if (builderExpr is FunctionExpression) {
              final FormalParameterList? params = builderExpr.parameters;
              if (params != null && params.parameters.length >= 2) {
                final String? constraintsName = params.parameters[1].name?.lexeme;
                if (constraintsName != null && !constraintsName.startsWith('_')) {
                  // Check if constraints is used in body
                  final Set<String> usedIds = <String>{};
                  builderExpr.body.visitChildren(_SimpleIdentifierCollector(usedIds));
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
class AvoidRepaintBoundaryMisuseRule extends DartLintRule {
  const AvoidRepaintBoundaryMisuseRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_repaint_boundary_misuse',
    problemMessage: 'RepaintBoundary around const/static content provides no benefit.',
    correctionMessage: 'Use RepaintBoundary for frequently repainting content.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addInstanceCreationExpression((InstanceCreationExpression node) {
      final String typeName = node.constructorName.type.name.lexeme;

      if (typeName == 'RepaintBoundary') {
        for (final Expression arg in node.argumentList.arguments) {
          if (arg is NamedExpression && arg.name.label.name == 'child') {
            final Expression child = arg.expression;
            // Check if child is const
            if (child is InstanceCreationExpression && child.keyword?.type == Keyword.CONST) {
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
class AvoidSingleChildScrollViewWithColumnRule extends DartLintRule {
  const AvoidSingleChildScrollViewWithColumnRule() : super(code: _code);

  // cspell: ignore singlechildscrollview
  static const LintCode _code = LintCode(
    name: 'avoid_singlechildscrollview_with_column',
    problemMessage: 'SingleChildScrollView with Column may cause layout issues.',
    correctionMessage: 'Consider using ListView instead, or remove Expanded/Flexible children.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addInstanceCreationExpression((InstanceCreationExpression node) {
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
class PreferCachedNetworkImageRule extends DartLintRule {
  const PreferCachedNetworkImageRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'prefer_cached_network_image',
    problemMessage: 'Consider using CachedNetworkImage for better caching.',
    correctionMessage: 'Replace Image.network with CachedNetworkImage package.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addInstanceCreationExpression((InstanceCreationExpression node) {
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
class AvoidGestureDetectorInScrollViewRule extends DartLintRule {
  const AvoidGestureDetectorInScrollViewRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_gesture_detector_in_scrollview',
    problemMessage: 'GestureDetector around scrollable can cause gesture conflicts.',
    correctionMessage: 'Move GestureDetector to individual items inside the scrollable.',
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
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addInstanceCreationExpression((InstanceCreationExpression node) {
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
class AvoidStatefulWidgetInListRule extends DartLintRule {
  const AvoidStatefulWidgetInListRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_stateful_widget_in_list',
    problemMessage: 'Creating StatefulWidget in list builder can cause state loss.',
    correctionMessage: 'Use keys or consider StatelessWidget for list items.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
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
                  if (argExpr is NamedExpression && argExpr.name.label.name == 'key') {
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
class PreferOpacityWidgetRule extends DartLintRule {
  const PreferOpacityWidgetRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'prefer_opacity_widget',
    problemMessage: 'Consider using Opacity widget for complex child widgets.',
    correctionMessage: 'Opacity widget can optimize rendering of transparent content.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name == 'withOpacity' || node.methodName.name == 'withAlpha') {
        // Check if this is part of a color argument to a container-like widget
        final AstNode? parent = node.parent;
        if (parent is NamedExpression && parent.name.label.name == 'color') {
          final AstNode? grandparent = parent.parent?.parent;
          if (grandparent is InstanceCreationExpression) {
            final String typeName = grandparent.constructorName.type.name.lexeme;
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
class AvoidInheritedWidgetInInitStateRule extends DartLintRule {
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
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
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

  final DiagnosticReporter reporter;
  final LintCode code;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    super.visitMethodInvocation(node);

    final String methodName = node.methodName.name;
    if (!AvoidInheritedWidgetInInitStateRule._inheritedWidgetMethods.contains(methodName)) {
      return;
    }

    // Check if target is a common inherited widget
    final Expression? target = node.target;
    if (target is SimpleIdentifier) {
      if (AvoidInheritedWidgetInInitStateRule._commonInheritedWidgets.contains(target.name)) {
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
class AvoidRecursiveWidgetCallsRule extends DartLintRule {
  const AvoidRecursiveWidgetCallsRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_recursive_widget_calls',
    problemMessage: 'Widget creates instance of itself, causing infinite recursion.',
    correctionMessage: 'Remove the recursive widget instantiation.',
    errorSeverity: DiagnosticSeverity.ERROR,
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
      final String className = node.name.lexeme;

      // Check if it's a widget class
      final ExtendsClause? extendsClause = node.extendsClause;
      if (extendsClause == null) return;

      final String superclassName = extendsClause.superclass.name.lexeme;
      if (superclassName != 'StatelessWidget' && superclassName != 'StatefulWidget') {
        return;
      }

      // Find build method
      for (final ClassMember member in node.members) {
        if (member is MethodDeclaration && member.name.lexeme == 'build') {
          // Check for self-instantiation in build
          member.body.accept(_RecursiveWidgetVisitor(className, reporter, code));
        }
      }
    });
  }
}

class _RecursiveWidgetVisitor extends RecursiveAstVisitor<void> {
  _RecursiveWidgetVisitor(this.className, this.reporter, this.code);

  final String className;
  final DiagnosticReporter reporter;
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
class AvoidUndisposedInstancesRule extends DartLintRule {
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
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
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

      for (final ClassMember member in node.members) {
        if (member is FieldDeclaration) {
          for (final VariableDeclaration variable in member.fields.variables) {
            final String fieldName = variable.name.lexeme;
            final Expression? initializer = variable.initializer;

            // Check if field is a disposable type
            if (initializer is InstanceCreationExpression) {
              final String typeName = initializer.constructorName.type.name.lexeme;
              if (_disposableTypes.contains(typeName)) {
                disposableFields.add(fieldName);
              }
            }

            // Check type annotation
            final TypeAnnotation? typeAnnotation = member.fields.type;
            if (typeAnnotation is NamedType) {
              if (_disposableTypes.contains(typeAnnotation.name.lexeme)) {
                disposableFields.add(fieldName);
              }
            }
          }
        }

        // Find dispose method and track what's disposed
        if (member is MethodDeclaration && member.name.lexeme == 'dispose') {
          member.body.accept(_DisposeVisitor(disposedFields));
        }
      }

      // Report undisposed fields
      for (final String fieldName in disposableFields) {
        if (!disposedFields.contains(fieldName)) {
          // Find the field declaration to report on
          for (final ClassMember member in node.members) {
            if (member is FieldDeclaration) {
              for (final VariableDeclaration variable in member.fields.variables) {
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
  _DisposeVisitor(this.disposedFields);

  final Set<String> disposedFields;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    super.visitMethodInvocation(node);

    if (node.methodName.name == 'dispose' || node.methodName.name == 'cancel') {
      final Expression? target = node.target;
      if (target is SimpleIdentifier) {
        disposedFields.add(target.name);
      }
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
class AvoidUnnecessaryOverridesInStateRule extends DartLintRule {
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
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
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
                  if (expr.target is SuperExpression && expr.methodName.name == methodName) {
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
class DisposeFieldsRule extends DartLintRule {
  const DisposeFieldsRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'dispose_fields',
    problemMessage: 'Field requires disposal but dispose method is missing or incomplete.',
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
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
      // Check if it's a State class
      final ExtendsClause? extendsClause = node.extendsClause;
      if (extendsClause == null) return;

      final String superclassName = extendsClause.superclass.name.lexeme;
      if (superclassName != 'State') return;

      // Find disposable fields
      final List<VariableDeclaration> disposableFields = <VariableDeclaration>[];
      bool hasDisposeMethod = false;

      for (final ClassMember member in node.members) {
        if (member is FieldDeclaration) {
          for (final VariableDeclaration variable in member.fields.variables) {
            final Expression? initializer = variable.initializer;
            if (initializer is InstanceCreationExpression) {
              final String typeName = initializer.constructorName.type.name.lexeme;
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
class PassExistingFutureToFutureBuilderRule extends DartLintRule {
  const PassExistingFutureToFutureBuilderRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'pass_existing_future_to_future_builder',
    problemMessage: 'Creating new Future in FutureBuilder causes rebuilds.',
    correctionMessage: 'Store the Future in a field and pass it to the builder.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addInstanceCreationExpression((InstanceCreationExpression node) {
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
class PassExistingStreamToStreamBuilderRule extends DartLintRule {
  const PassExistingStreamToStreamBuilderRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'pass_existing_stream_to_stream_builder',
    problemMessage: 'Creating new Stream in StreamBuilder causes rebuilds.',
    correctionMessage: 'Store the Stream in a field and pass it to the builder.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addInstanceCreationExpression((InstanceCreationExpression node) {
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
