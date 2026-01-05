// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

/// Performance lint rules for Flutter/Dart applications.
///
/// These rules help identify patterns that can cause performance issues
/// such as unnecessary rebuilds, expensive operations in hot paths,
/// and inefficient resource usage.
library;

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart' show DiagnosticSeverity;
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

/// Warns when AnimatedList or AnimatedGrid items don't have keys.
///
/// Without keys, Flutter cannot efficiently track which items have
/// changed, leading to incorrect animations and poor performance.
///
/// **BAD:**
/// ```dart
/// AnimatedList(
///   itemBuilder: (context, index, animation) {
///     return SlideTransition(
///       position: animation,
///       child: ListTile(title: Text(items[index])),
///     );
///   },
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// AnimatedList(
///   itemBuilder: (context, index, animation) {
///     return SlideTransition(
///       key: ValueKey(items[index].id),
///       position: animation,
///       child: ListTile(title: Text(items[index])),
///     );
///   },
/// )
/// ```
class RequireKeysInAnimatedListsRule extends DartLintRule {
  const RequireKeysInAnimatedListsRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'require_keys_in_animated_lists',
    problemMessage: 'AnimatedList/AnimatedGrid items should have keys.',
    correctionMessage: 'Add a Key to the returned widget for correct animations.',
    errorSeverity: DiagnosticSeverity.ERROR,
  );

  static const Set<String> _animatedListWidgets = <String>{
    'AnimatedList',
    'AnimatedGrid',
    'SliverAnimatedList',
    'SliverAnimatedGrid',
  };

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
      if (!_animatedListWidgets.contains(constructorName)) return;

      // Find itemBuilder argument
      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression && arg.name.label.name == 'itemBuilder') {
          final Expression builderExpr = arg.expression;
          if (builderExpr is FunctionExpression) {
            _checkBuilderForKey(builderExpr.body, reporter);
          }
        }
      }
    });
  }

  void _checkBuilderForKey(FunctionBody body, DiagnosticReporter reporter) {
    // Find the returned widget
    if (body is ExpressionFunctionBody) {
      _checkExpressionForKey(body.expression, reporter, body);
    } else if (body is BlockFunctionBody) {
      body.block.visitChildren(
        _ReturnVisitor((Expression expr) {
          _checkExpressionForKey(expr, reporter, body);
        }),
      );
    }
  }

  void _checkExpressionForKey(
    Expression expr,
    DiagnosticReporter reporter,
    AstNode reportNode,
  ) {
    if (expr is InstanceCreationExpression) {
      final bool hasKey = expr.argumentList.arguments.any((Expression arg) {
        if (arg is NamedExpression) {
          return arg.name.label.name == 'key';
        }
        return false;
      });

      if (!hasKey) {
        reporter.atNode(reportNode, code);
      }
    }
  }
}

class _ReturnVisitor extends RecursiveAstVisitor<void> {
  _ReturnVisitor(this.onReturn);

  final void Function(Expression) onReturn;

  @override
  void visitReturnStatement(ReturnStatement node) {
    final Expression? expr = node.expression;
    if (expr != null) {
      onReturn(expr);
    }
    super.visitReturnStatement(node);
  }
}

/// Warns when expensive operations are performed in build methods.
///
/// Operations like JSON parsing, file I/O, or complex calculations
/// should not be done in build() as it's called frequently.
///
/// **BAD:**
/// ```dart
/// Widget build(BuildContext context) {
///   final data = jsonDecode(jsonString);
///   return Text(data['name']);
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// late final data = jsonDecode(jsonString); // In initState or outside build
///
/// Widget build(BuildContext context) {
///   return Text(data['name']);
/// }
/// ```
class AvoidExpensiveBuildRule extends DartLintRule {
  const AvoidExpensiveBuildRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_expensive_build',
    problemMessage: 'Expensive operation in build method.',
    correctionMessage:
        'Move expensive operations to initState, didChangeDependencies, or cache the result.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  static const Set<String> _expensiveOperations = <String>{
    'jsonDecode',
    'jsonEncode',
    'parse',
    'tryParse',
    'readAsString',
    'readAsBytes',
    'readAsLines',
    'readAsBytesSync',
    'readAsStringSync',
    'compute',
    'sort',
    'where',
    'map',
    'fold',
    'reduce',
  };

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodDeclaration((MethodDeclaration node) {
      if (node.name.lexeme != 'build') return;

      // Check if this is a widget build method
      final ClassDeclaration? classDecl = node.thisOrAncestorOfType<ClassDeclaration>();
      if (classDecl == null) return;

      final ExtendsClause? extendsClause = classDecl.extendsClause;
      if (extendsClause == null) return;

      final String superName = extendsClause.superclass.name.lexeme;
      if (!superName.contains('State') && !superName.contains('Widget')) {
        return;
      }

      // Check for expensive operations in the build method
      node.body.visitChildren(
        _ExpensiveOperationVisitor(
          reporter,
          code,
          _expensiveOperations,
        ),
      );
    });
  }
}

class _ExpensiveOperationVisitor extends RecursiveAstVisitor<void> {
  _ExpensiveOperationVisitor(this.reporter, this.code, this.expensiveOps);

  final DiagnosticReporter reporter;
  final LintCode code;
  final Set<String> expensiveOps;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (expensiveOps.contains(node.methodName.name)) {
      reporter.atNode(node, code);
    }
    super.visitMethodInvocation(node);
  }

  @override
  void visitFunctionExpressionInvocation(FunctionExpressionInvocation node) {
    final Expression function = node.function;
    if (function is SimpleIdentifier && expensiveOps.contains(function.name)) {
      reporter.atNode(node, code);
    }
    super.visitFunctionExpressionInvocation(node);
  }
}

/// Warns when child widgets could be const but aren't.
///
/// Const widgets are cached by Flutter and don't rebuild unnecessarily.
///
/// **BAD:**
/// ```dart
/// children: [
///   Icon(Icons.star),
///   SizedBox(width: 8),
///   Text('Rating'),
/// ]
/// ```
///
/// **GOOD:**
/// ```dart
/// children: const [
///   Icon(Icons.star),
///   SizedBox(width: 8),
///   Text('Rating'),
/// ]
/// ```
class PreferConstChildWidgetsRule extends DartLintRule {
  const PreferConstChildWidgetsRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'prefer_const_child_widgets',
    problemMessage: 'Child widgets could be const.',
    correctionMessage: 'Add const to the list literal to prevent unnecessary rebuilds.',
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

      // Check if in a widget context (children, actions, etc.)
      final AstNode? parent = node.parent;
      if (parent is! NamedExpression) return;

      final String argName = parent.name.label.name;
      if (argName != 'children' && argName != 'actions' && argName != 'tabs') {
        return;
      }

      // Check if all elements are potentially const-able
      final bool allConst = node.elements.every(_isConstableExpression);
      if (allConst && node.elements.isNotEmpty) {
        reporter.atNode(node, code);
      }
    });
  }

  bool _isConstableExpression(CollectionElement element) {
    if (element is! Expression) return false;

    if (element is InstanceCreationExpression) {
      // Check if already const
      if (element.isConst) return true;

      // Check if constructor could be const by looking at the type
      // We can't easily determine if constructor is const without resolved element,
      // so we check common Flutter widgets that are typically const-able
      final String? typeName = element.constructorName.type.element?.name;
      if (typeName == null) return false;

      // Common const-able widgets
      const Set<String> constableWidgets = <String>{
        'Icon',
        'SizedBox',
        'Text',
        'Padding',
        'Center',
        'Align',
        'Spacer',
        'Divider',
        'VerticalDivider',
      };

      if (!constableWidgets.contains(typeName)) return false;

      // Check if all arguments are const-able
      return element.argumentList.arguments.every(_isConstArgument);
    }

    if (element is Literal) return true;
    if (element is PrefixedIdentifier) {
      // Like Icons.star - typically const
      return true;
    }

    return false;
  }

  bool _isConstArgument(Expression arg) {
    if (arg is Literal) return true;
    if (arg is NamedExpression) return _isConstArgument(arg.expression);
    if (arg is PrefixedIdentifier) {
      // Like Icons.star
      return true; // Simplified - assume static const
    }
    if (arg is InstanceCreationExpression) {
      // Nested widget - recursively check
      return arg.isConst;
    }
    return false;
  }
}

/// Warns when synchronous file I/O is used instead of async.
///
/// Synchronous file operations block the UI thread and cause jank.
///
/// **BAD:**
/// ```dart
/// final content = File('data.txt').readAsStringSync();
/// ```
///
/// **GOOD:**
/// ```dart
/// final content = await File('data.txt').readAsString();
/// ```
class AvoidSynchronousFileIoRule extends DartLintRule {
  const AvoidSynchronousFileIoRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_synchronous_file_io',
    problemMessage: 'Avoid synchronous file I/O operations.',
    correctionMessage: 'Use async file operations to avoid blocking the UI.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  static const Set<String> _syncMethods = <String>{
    'readAsStringSync',
    'readAsBytesSync',
    'readAsLinesSync',
    'writeAsStringSync',
    'writeAsBytesSync',
    'existsSync',
    'createSync',
    'deleteSync',
    'copySync',
    'renameSync',
    'statSync',
    'listSync',
  };

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      if (_syncMethods.contains(node.methodName.name)) {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when compute() should be used for heavy work.
///
/// Operations taking more than 16ms block the UI thread.
/// Use compute() or Isolate for heavy processing.
///
/// **BAD:**
/// ```dart
/// final result = heavyCalculation(data); // In main isolate
/// ```
///
/// **GOOD:**
/// ```dart
/// final result = await compute(heavyCalculation, data);
/// ```
class PreferComputeForHeavyWorkRule extends DartLintRule {
  const PreferComputeForHeavyWorkRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'prefer_compute_for_heavy_work',
    problemMessage: 'Heavy computation should use compute() or Isolate.',
    correctionMessage: 'Move heavy work to a separate isolate using compute() or Isolate.run().',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  static const Set<String> _heavyOperations = <String>{
    'encrypt',
    'decrypt',
    'compress',
    'decompress',
    'encode',
    'decode',
    'hash',
    'parseJson',
    'parseXml',
    'processImage',
    'resizeImage',
    'convertImage',
  };

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name.toLowerCase();

      // Check if method name suggests heavy work
      for (final String pattern in _heavyOperations) {
        if (methodName.contains(pattern.toLowerCase())) {
          // Check if already inside compute or isolate
          AstNode? current = node.parent;
          bool insideIsolate = false;

          while (current != null) {
            if (current is MethodInvocation) {
              final String parentMethod = current.methodName.name;
              if (parentMethod == 'compute' || parentMethod == 'run' || parentMethod == 'spawn') {
                insideIsolate = true;
                break;
              }
            }
            current = current.parent;
          }

          if (!insideIsolate) {
            reporter.atNode(node, code);
          }
          return;
        }
      }
    });
  }
}

/// Warns when objects are created inside hot loops.
///
/// Creating objects in frequently-executed loops causes GC pressure.
///
/// **BAD:**
/// ```dart
/// for (final item in items) {
///   final formatter = DateFormat('yyyy-MM-dd');
///   print(formatter.format(item.date));
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// final formatter = DateFormat('yyyy-MM-dd');
/// for (final item in items) {
///   print(formatter.format(item.date));
/// }
/// ```
class AvoidObjectCreationInHotLoopsRule extends DartLintRule {
  const AvoidObjectCreationInHotLoopsRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_object_creation_in_hot_loops',
    problemMessage: 'Object creation inside loop causes GC pressure.',
    correctionMessage: 'Move object creation outside the loop.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  static const Set<String> _expensiveTypes = <String>{
    'DateFormat',
    'NumberFormat',
    'RegExp',
    'JsonEncoder',
    'JsonDecoder',
    'Utf8Encoder',
    'Utf8Decoder',
    'HttpClient',
  };

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addForStatement((ForStatement node) {
      _checkBodyForCreation(node.body, reporter);
    });

    context.registry.addForElement((ForElement node) {
      // For elements in list comprehensions
      if (node.body is InstanceCreationExpression) {
        final InstanceCreationExpression creation = node.body as InstanceCreationExpression;
        _checkCreation(creation, reporter);
      }
    });

    context.registry.addWhileStatement((WhileStatement node) {
      _checkBodyForCreation(node.body, reporter);
    });

    context.registry.addDoStatement((DoStatement node) {
      _checkBodyForCreation(node.body, reporter);
    });
  }

  void _checkBodyForCreation(Statement body, DiagnosticReporter reporter) {
    body.visitChildren(_CreationInLoopVisitor(reporter, code, _expensiveTypes));
  }

  void _checkCreation(
    InstanceCreationExpression creation,
    DiagnosticReporter reporter,
  ) {
    final String? typeName = creation.constructorName.type.element?.name;
    if (typeName != null && _expensiveTypes.contains(typeName)) {
      reporter.atNode(creation, code);
    }
  }
}

class _CreationInLoopVisitor extends RecursiveAstVisitor<void> {
  _CreationInLoopVisitor(this.reporter, this.code, this.expensiveTypes);

  final DiagnosticReporter reporter;
  final LintCode code;
  final Set<String> expensiveTypes;

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    final String? typeName = node.constructorName.type.element?.name;
    if (typeName != null && expensiveTypes.contains(typeName)) {
      reporter.atNode(node, code);
    }
    super.visitInstanceCreationExpression(node);
  }
}

/// Warns when an expensive getter is called multiple times.
///
/// Getters that perform computation should be cached.
///
/// **BAD:**
/// ```dart
/// if (widget.expensiveCalculation > 0) {
///   return Text('${widget.expensiveCalculation}');
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// final result = widget.expensiveCalculation;
/// if (result > 0) {
///   return Text('$result');
/// }
/// ```
class PreferCachedGetterRule extends DartLintRule {
  const PreferCachedGetterRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'prefer_cached_getter',
    problemMessage: 'Getter called multiple times - consider caching.',
    correctionMessage: 'Store the getter result in a local variable if called multiple times.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodDeclaration((MethodDeclaration node) {
      // Analyze the method body for repeated getter calls
      final Map<String, List<AstNode>> getterCalls = <String, List<AstNode>>{};

      node.body.visitChildren(_GetterCallCollector(getterCalls));

      // Report getters called more than once
      for (final MapEntry<String, List<AstNode>> entry in getterCalls.entries) {
        if (entry.value.length > 1) {
          // Report on the second occurrence
          reporter.atNode(entry.value[1], code);
        }
      }
    });
  }
}

class _GetterCallCollector extends RecursiveAstVisitor<void> {
  _GetterCallCollector(this.getterCalls);

  final Map<String, List<AstNode>> getterCalls;

  @override
  void visitPrefixedIdentifier(PrefixedIdentifier node) {
    // Track calls like widget.someGetter
    final String key = node.toSource();
    getterCalls.putIfAbsent(key, () => <AstNode>[]).add(node);
    super.visitPrefixedIdentifier(node);
  }

  @override
  void visitPropertyAccess(PropertyAccess node) {
    final String key = node.toSource();
    getterCalls.putIfAbsent(key, () => <AstNode>[]).add(node);
    super.visitPropertyAccess(node);
  }
}

/// Warns when widget tree depth is excessive.
///
/// Very deep widget trees can cause performance issues and
/// are hard to maintain.
///
/// **BAD:**
/// ```dart
/// Container(
///   child: Padding(
///     child: Column(
///       children: [
///         Row(
///           children: [
///             Expanded(
///               child: Container(
///                 child: Text('Too deep!'),
///               ),
///             ),
///           ],
///         ),
///       ],
///     ),
///   ),
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// // Extract into separate widgets
/// MyContentWidget()
/// ```
class AvoidExcessiveWidgetDepthRule extends DartLintRule {
  const AvoidExcessiveWidgetDepthRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_excessive_widget_depth',
    problemMessage: 'Widget tree is too deep.',
    correctionMessage:
        'Extract nested widgets into separate widget classes for better performance.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  static const int _maxDepth = 10;

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodDeclaration((MethodDeclaration node) {
      if (node.name.lexeme != 'build') return;

      int maxFound = 0;
      AstNode? deepestNode;

      node.body.visitChildren(
        _DepthVisitor((int depth, AstNode foundNode) {
          if (depth > maxFound) {
            maxFound = depth;
            deepestNode = foundNode;
          }
        }),
      );

      if (maxFound > _maxDepth && deepestNode != null) {
        reporter.atNode(deepestNode!, code);
      }
    });
  }
}

class _DepthVisitor extends RecursiveAstVisitor<void> {
  _DepthVisitor(this.onDepth, [this.currentDepth = 0]);

  final void Function(int, AstNode) onDepth;
  final int currentDepth;

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    final int newDepth = currentDepth + 1;
    onDepth(newDepth, node);

    // Continue with increased depth for child arguments
    for (final Expression arg in node.argumentList.arguments) {
      if (arg is NamedExpression && arg.name.label.name == 'child') {
        arg.expression.visitChildren(_DepthVisitor(onDepth, newDepth));
      } else if (arg is NamedExpression && arg.name.label.name == 'children') {
        arg.expression.visitChildren(_DepthVisitor(onDepth, newDepth));
      }
    }
  }
}

/// Warns when large lists don't specify itemExtent.
///
/// For lists with many items, specifying itemExtent improves
/// scrolling performance significantly.
///
/// **BAD:**
/// ```dart
/// ListView.builder(
///   itemCount: 10000,
///   itemBuilder: (context, index) => ListTile(...),
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// ListView.builder(
///   itemCount: 10000,
///   itemExtent: 56.0, // Fixed height
///   itemBuilder: (context, index) => ListTile(...),
/// )
/// ```
class RequireItemExtentForLargeListsRule extends DartLintRule {
  const RequireItemExtentForLargeListsRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'require_item_extent_for_large_lists',
    problemMessage: 'Large list should specify itemExtent for performance.',
    correctionMessage: 'Add itemExtent or prototypeItem for better scrolling performance.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  static const int _largeListThreshold = 100;

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
      if (constructorName != 'ListView') return;

      // Check if it's a builder constructor
      final String? namedConstructor = node.constructorName.name?.name;
      if (namedConstructor != 'builder' && namedConstructor != 'separated') {
        return;
      }

      bool hasItemExtent = false;
      bool hasPrototypeItem = false;
      int? itemCount;

      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression) {
          final String name = arg.name.label.name;
          if (name == 'itemExtent' || name == 'itemExtentBuilder') {
            hasItemExtent = true;
          }
          if (name == 'prototypeItem') {
            hasPrototypeItem = true;
          }
          if (name == 'itemCount' && arg.expression is IntegerLiteral) {
            itemCount = (arg.expression as IntegerLiteral).value;
          }
        }
      }

      if (!hasItemExtent &&
          !hasPrototypeItem &&
          itemCount != null &&
          itemCount > _largeListThreshold) {
        reporter.atNode(node.constructorName, code);
      }
    });
  }
}

/// Warns when Image.network is called without cacheWidth/cacheHeight.
///
/// Without cache dimensions, images are decoded at full resolution
/// even if displayed smaller, wasting memory.
///
/// **BAD:**
/// ```dart
/// Image.network(url)
/// ```
///
/// **GOOD:**
/// ```dart
/// Image.network(
///   url,
///   cacheWidth: 200,
///   cacheHeight: 200,
/// )
/// ```
class RequireImageCacheDimensionsRule extends DartLintRule {
  const RequireImageCacheDimensionsRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'require_image_cache_dimensions',
    problemMessage: 'Network image should specify cache dimensions.',
    correctionMessage: 'Add cacheWidth/cacheHeight to reduce memory usage.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

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
      if (constructorName != 'Image') return;

      final String? namedConstructor = node.constructorName.name?.name;
      if (namedConstructor != 'network') return;

      final bool hasCacheDimensions = node.argumentList.arguments.any((Expression arg) {
        if (arg is NamedExpression) {
          final String name = arg.name.label.name;
          return name == 'cacheWidth' || name == 'cacheHeight';
        }
        return false;
      });

      if (!hasCacheDimensions) {
        reporter.atNode(node.constructorName, code);
      }
    });
  }
}

/// Warns when images should be precached for smooth display.
///
/// Large images displayed immediately after navigation can cause
/// visible loading delays. Use precacheImage for critical images.
///
/// **BAD:**
/// ```dart
/// // In build method
/// Image.asset('assets/hero_image.png')
/// ```
///
/// **GOOD:**
/// ```dart
/// // In didChangeDependencies
/// precacheImage(AssetImage('assets/hero_image.png'), context);
///
/// // In build
/// Image.asset('assets/hero_image.png')
/// ```
class PreferImagePrecacheRule extends DartLintRule {
  const PreferImagePrecacheRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'prefer_image_precache',
    problemMessage: 'Consider precaching large or hero images.',
    correctionMessage: 'Use precacheImage() in didChangeDependencies for smoother UX.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  static const Set<String> _heroIndicators = <String>{
    'hero',
    'banner',
    'cover',
    'splash',
    'background',
    'header',
  };

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
      if (constructorName != 'Image') return;

      final String? namedConstructor = node.constructorName.name?.name;
      if (namedConstructor != 'asset' && namedConstructor != 'network') return;

      // Check if in build method
      final MethodDeclaration? method = node.thisOrAncestorOfType<MethodDeclaration>();
      if (method == null || method.name.lexeme != 'build') return;

      // Check if image name suggests it's a hero/important image
      if (node.argumentList.arguments.isEmpty) return;

      final Expression firstArg = node.argumentList.arguments.first;
      final String argSource = firstArg.toSource().toLowerCase();

      for (final String indicator in _heroIndicators) {
        if (argSource.contains(indicator)) {
          reporter.atNode(node.constructorName, code);
          return;
        }
      }
    });
  }
}

/// Warns when ScrollController is created in build method.
///
/// Controllers created in build will be recreated on every rebuild,
/// losing scroll position and causing memory leaks.
///
/// **BAD:**
/// ```dart
/// Widget build(BuildContext context) {
///   final controller = ScrollController();
///   return ListView(controller: controller);
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// late final ScrollController _controller = ScrollController();
///
/// Widget build(BuildContext context) {
///   return ListView(controller: _controller);
/// }
/// ```
class AvoidControllerInBuildRule extends DartLintRule {
  const AvoidControllerInBuildRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_controller_in_build',
    problemMessage: 'Controller should not be created in build method.',
    correctionMessage: 'Create controllers as class fields and dispose them properly.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  static const Set<String> _controllerTypes = <String>{
    'ScrollController',
    'PageController',
    'TabController',
    'TextEditingController',
    'AnimationController',
    'FocusNode',
    'StreamController',
  };

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodDeclaration((MethodDeclaration node) {
      if (node.name.lexeme != 'build') return;

      node.body.visitChildren(
        _ControllerCreationVisitor(
          reporter,
          code,
          _controllerTypes,
        ),
      );
    });
  }
}

class _ControllerCreationVisitor extends RecursiveAstVisitor<void> {
  _ControllerCreationVisitor(this.reporter, this.code, this.controllerTypes);

  final DiagnosticReporter reporter;
  final LintCode code;
  final Set<String> controllerTypes;

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    final String? typeName = node.constructorName.type.element?.name;
    if (typeName != null && controllerTypes.contains(typeName)) {
      reporter.atNode(node, code);
    }
    super.visitInstanceCreationExpression(node);
  }
}

/// Warns when setState is called during build.
///
/// Calling setState during build causes infinite rebuild loops.
///
/// **BAD:**
/// ```dart
/// Widget build(BuildContext context) {
///   if (condition) {
///     setState(() { /* ... */ }); // Causes infinite loop!
///   }
///   return Container();
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// Widget build(BuildContext context) {
///   if (condition) {
///     WidgetsBinding.instance.addPostFrameCallback((_) {
///       setState(() { /* ... */ });
///     });
///   }
///   return Container();
/// }
/// ```
class AvoidSetStateInBuildRule extends DartLintRule {
  const AvoidSetStateInBuildRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_setstate_in_build',
    problemMessage: 'setState should not be called in build method.',
    correctionMessage: 'Use addPostFrameCallback or move state changes to event handlers.',
    errorSeverity: DiagnosticSeverity.ERROR,
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodDeclaration((MethodDeclaration node) {
      if (node.name.lexeme != 'build') return;

      node.body.visitChildren(_SetStateVisitor(reporter, code));
    });
  }
}

class _SetStateVisitor extends RecursiveAstVisitor<void> {
  _SetStateVisitor(this.reporter, this.code);

  final DiagnosticReporter reporter;
  final LintCode code;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.methodName.name == 'setState') {
      // Check if inside a callback that's okay (like addPostFrameCallback)
      AstNode? current = node.parent;
      while (current != null) {
        if (current is MethodInvocation) {
          final String name = current.methodName.name;
          if (name == 'addPostFrameCallback' ||
              name == 'scheduleMicrotask' ||
              name == 'then' ||
              name == 'Future') {
            // Inside async callback, okay
            return;
          }
        }
        if (current is FunctionExpression) {
          // Check if this function is passed to an async method
          final AstNode? funcParent = current.parent;
          if (funcParent is ArgumentList) {
            return; // Likely a callback, don't report
          }
        }
        current = current.parent;
      }

      reporter.atNode(node, code);
    }
    super.visitMethodInvocation(node);
  }
}
