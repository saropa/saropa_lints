// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

/// Performance lint rules for Flutter/Dart applications.
///
/// These rules help identify patterns that can cause performance issues
/// such as unnecessary rebuilds, expensive operations in hot paths,
/// and inefficient resource usage.
library;

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/ast/visitor.dart';

import '../async_context_utils.dart';
import '../saropa_lint_rule.dart';

/// Warns when AnimatedList or AnimatedGrid items don't have keys.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v5
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
class RequireKeysInAnimatedListsRule extends SaropaLintRule {
  RequireKeysInAnimatedListsRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'require_keys_in_animated_lists',
    '[require_keys_in_animated_lists] Without keys, AnimatedList animations '
        'target wrong items after insert/remove operations. {v5}',
    correctionMessage:
        'Add a Key to the returned widget for correct animations.',
    severity: DiagnosticSeverity.ERROR,
  );

  static const Set<String> _animatedListWidgets = <String>{
    'AnimatedList',
    'AnimatedGrid',
    'SliverAnimatedList',
    'SliverAnimatedGrid',
  };

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
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

  void _checkBuilderForKey(
    FunctionBody body,
    SaropaDiagnosticReporter reporter,
  ) {
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
    SaropaDiagnosticReporter reporter,
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
        reporter.atNode(reportNode);
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
/// Since: v1.7.2 | Updated: v4.13.0 | Rule version: v2
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
class AvoidExpensiveBuildRule extends SaropaLintRule {
  AvoidExpensiveBuildRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'avoid_expensive_build',
    '[avoid_expensive_build] Expensive operations in build() run on every '
        'frame, causing jank and dropped frames during animations. {v2}',
    correctionMessage:
        'Move expensive operations to initState, didChangeDependencies, or cache the result.',
    severity: DiagnosticSeverity.WARNING,
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
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodDeclaration((MethodDeclaration node) {
      if (node.name.lexeme != 'build') return;

      // Check if this is a widget build method
      final ClassDeclaration? classDecl = node
          .thisOrAncestorOfType<ClassDeclaration>();
      if (classDecl == null) return;

      final ExtendsClause? extendsClause = classDecl.extendsClause;
      if (extendsClause == null) return;

      final String superName = extendsClause.superclass.name.lexeme;
      if (!superName.contains('State') && !superName.contains('Widget')) {
        return;
      }

      // Check for expensive operations in the build method
      node.body.visitChildren(
        _ExpensiveOperationVisitor(reporter, code, _expensiveOperations),
      );
    });
  }
}

class _ExpensiveOperationVisitor extends RecursiveAstVisitor<void> {
  _ExpensiveOperationVisitor(this.reporter, this.code, this.expensiveOps);

  final SaropaDiagnosticReporter reporter;
  final LintCode code;
  final Set<String> expensiveOps;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (expensiveOps.contains(node.methodName.name)) {
      reporter.atNode(node);
    }
    super.visitMethodInvocation(node);
  }

  @override
  void visitFunctionExpressionInvocation(FunctionExpressionInvocation node) {
    final Expression function = node.function;
    if (function is SimpleIdentifier && expensiveOps.contains(function.name)) {
      reporter.atNode(node);
    }
    super.visitFunctionExpressionInvocation(node);
  }
}

/// Warns when synchronous file I/O is used instead of async.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v4
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
class AvoidSynchronousFileIoRule extends SaropaLintRule {
  AvoidSynchronousFileIoRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'avoid_synchronous_file_io',
    '[avoid_synchronous_file_io] Synchronous file I/O blocks the main '
        'thread, causing UI freezes and dropped frames during disk access. {v4}',
    correctionMessage: 'Use async file operations to avoid blocking the UI.',
    severity: DiagnosticSeverity.WARNING,
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
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      if (_syncMethods.contains(node.methodName.name)) {
        reporter.atNode(node);
      }
    });
  }
}

/// Warns when compute() should be used for heavy work.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v5
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
class PreferComputeForHeavyWorkRule extends SaropaLintRule {
  PreferComputeForHeavyWorkRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'prefer_compute_for_heavy_work',
    '[prefer_compute_for_heavy_work] Heavy computation such as encryption, compression, or parsing runs synchronously on the main UI thread. This blocks the rendering pipeline, freezing animations, dropping frames, and making the app unresponsive to touch input for the duration of the operation. On lower-end devices, this delay is especially pronounced and triggers ANR warnings on Android. {v5}',
    correctionMessage:
        'Move heavy work to a separate isolate using compute() or Isolate.run(). This keeps the UI responsive and prevents dropped frames or slow user interactions, especially on lower-end devices.',
    severity: DiagnosticSeverity.INFO,
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
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
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
              if (parentMethod == 'compute' ||
                  parentMethod == 'run' ||
                  parentMethod == 'spawn') {
                insideIsolate = true;
                break;
              }
            }
            current = current.parent;
          }

          if (!insideIsolate) {
            reporter.atNode(node);
          }
          return;
        }
      }
    });
  }
}

/// Warns when objects are created inside hot loops.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v5
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
class AvoidObjectCreationInHotLoopsRule extends SaropaLintRule {
  AvoidObjectCreationInHotLoopsRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'avoid_object_creation_in_hot_loops',
    '[avoid_object_creation_in_hot_loops] Creating objects inside hot loops triggers frequent garbage collection pauses that freeze the UI thread. Each allocation adds GC pressure proportionally to iteration count, causing visible jank, dropped frames during animations, and degraded scrolling performance on lower-end devices. {v5}',
    correctionMessage:
        'Move object creation outside the loop body and reuse instances across iterations. For collections, preallocate with a known capacity to minimize allocation overhead.',
    severity: DiagnosticSeverity.WARNING,
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
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addForStatement((ForStatement node) {
      _checkBodyForCreation(node.body, reporter);
    });

    context.addForElement((ForElement node) {
      // For elements in list comprehensions
      if (node.body is InstanceCreationExpression) {
        final InstanceCreationExpression creation =
            node.body as InstanceCreationExpression;
        _checkCreation(creation, reporter);
      }
    });

    context.addWhileStatement((WhileStatement node) {
      _checkBodyForCreation(node.body, reporter);
    });

    context.addDoStatement((DoStatement node) {
      _checkBodyForCreation(node.body, reporter);
    });
  }

  void _checkBodyForCreation(
    Statement body,
    SaropaDiagnosticReporter reporter,
  ) {
    body.visitChildren(_CreationInLoopVisitor(reporter, code, _expensiveTypes));
  }

  void _checkCreation(
    InstanceCreationExpression creation,
    SaropaDiagnosticReporter reporter,
  ) {
    final String? typeName = creation.constructorName.type.element?.name;
    if (typeName != null && _expensiveTypes.contains(typeName)) {
      reporter.atNode(creation);
    }
  }
}

class _CreationInLoopVisitor extends RecursiveAstVisitor<void> {
  _CreationInLoopVisitor(this.reporter, this.code, this.expensiveTypes);

  final SaropaDiagnosticReporter reporter;
  final LintCode code;
  final Set<String> expensiveTypes;

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    final String? typeName = node.constructorName.type.element?.name;
    if (typeName != null && expensiveTypes.contains(typeName)) {
      reporter.atNode(node);
    }
    super.visitInstanceCreationExpression(node);
  }
}

/// Warns when an expensive getter is called multiple times.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v5
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
class PreferCachedGetterRule extends SaropaLintRule {
  PreferCachedGetterRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'prefer_cached_getter',
    '[prefer_cached_getter] Repeated getter calls recompute expensive values '
        'each time, wasting CPU cycles when caching would suffice. {v5}',
    correctionMessage:
        'Store the getter result in a local variable if called multiple times.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodDeclaration((MethodDeclaration node) {
      // Analyze the method body for repeated getter calls
      final Map<String, List<AstNode>> getterCalls = <String, List<AstNode>>{};

      node.body.visitChildren(_GetterCallCollector(getterCalls));

      for (final MapEntry<String, List<AstNode>> entry in getterCalls.entries) {
        if (entry.value.length > 1) {
          // Heuristic: skip reporting if getter is an Isar/single-subscription stream
          final String getterSource = entry.key;
          if (_isSingleSubscriptionStream(getterSource)) {
            continue;
          }
          reporter.atNode(entry.value[1], code);
        }
      }
    });
  }

  bool _isSingleSubscriptionStream(String getterSource) {
    // Heuristic: skip if getter name contains 'isar', 'stream', or matches known Isar stream patterns
    final lower = getterSource.toLowerCase();
    if (lower.contains('isar') && lower.contains('stream')) return true;
    // Add more patterns as needed
    return false;
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
/// Since: v1.7.2 | Updated: v4.13.0 | Rule version: v2
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
class AvoidExcessiveWidgetDepthRule extends SaropaLintRule {
  AvoidExcessiveWidgetDepthRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    'avoid_excessive_widget_depth',
    '[avoid_excessive_widget_depth] Deep widget nesting rebuilds entire '
        'subtree on changes, hurting performance and making code hard to maintain. {v2}',
    correctionMessage:
        'Extract nested widgets into separate widget classes for better performance.',
    severity: DiagnosticSeverity.WARNING,
  );

  static const int _maxDepth = 10;

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodDeclaration((MethodDeclaration node) {
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
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v5
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
class RequireItemExtentForLargeListsRule extends SaropaLintRule {
  RequireItemExtentForLargeListsRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'require_item_extent_for_large_lists',
    '[require_item_extent_for_large_lists] ListView with many items but no itemExtent forces Flutter to lay out every child widget to calculate scroll extent. This causes expensive initial rendering, prevents efficient jump-to-index operations, and degrades scroll bar accuracy, resulting in slow list initialization and janky scrolling. {v5}',
    correctionMessage:
        'Add itemExtent for fixed-height items or prototypeItem for consistent sizes to enable O(1) scroll position calculations and smoother scrolling performance.',
    severity: DiagnosticSeverity.INFO,
  );

  static const int _largeListThreshold = 100;

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
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

/// Warns when images should be precached for smooth display.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v5
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
class PreferImagePrecacheRule extends SaropaLintRule {
  PreferImagePrecacheRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'prefer_image_precache',
    '[prefer_image_precache] Large images without precaching cause visible '
        'loading delays and layout shifts when they appear on screen. {v5}',
    correctionMessage:
        'Use precacheImage() in didChangeDependencies for smoother UX.',
    severity: DiagnosticSeverity.INFO,
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
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      final String? constructorName = node.constructorName.type.element?.name;
      if (constructorName != 'Image') return;

      final String? namedConstructor = node.constructorName.name?.name;
      if (namedConstructor != 'asset' && namedConstructor != 'network') return;

      // Check if in build method
      final MethodDeclaration? method = node
          .thisOrAncestorOfType<MethodDeclaration>();
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
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v5
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
class AvoidControllerInBuildRule extends SaropaLintRule {
  AvoidControllerInBuildRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'avoid_controller_in_build',
    '[avoid_controller_in_build] Creating controllers (e.g., TextEditingController, AnimationController) inside the build() method causes a new instance to be created on every rebuild. This leads to memory leaks, lost state, and degraded performance, as old controllers are never disposed. {v5}',
    correctionMessage:
        'Always create controllers as class fields in your State class and dispose of them in the dispose() method to prevent leaks and ensure proper resource management.',
    severity: DiagnosticSeverity.WARNING,
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
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodDeclaration((MethodDeclaration node) {
      if (node.name.lexeme != 'build') return;

      node.body.visitChildren(
        _ControllerCreationVisitor(reporter, code, _controllerTypes),
      );
    });
  }
}

class _ControllerCreationVisitor extends RecursiveAstVisitor<void> {
  _ControllerCreationVisitor(this.reporter, this.code, this.controllerTypes);

  final SaropaDiagnosticReporter reporter;
  final LintCode code;
  final Set<String> controllerTypes;

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    final String? typeName = node.constructorName.type.element?.name;
    if (typeName != null && controllerTypes.contains(typeName)) {
      reporter.atNode(node);
    }
    super.visitInstanceCreationExpression(node);
  }
}

/// Warns when setState is called during build.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v6
///
/// Alias: avoid_set_state_in_build, setstate_in_build, no_setstate_in_build
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
class AvoidSetStateInBuildRule extends SaropaLintRule {
  AvoidSetStateInBuildRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    'avoid_setstate_in_build',
    '[avoid_setstate_in_build] Calling setState inside the build() method causes the widget to rebuild recursively, leading to stack overflows, app crashes, and unpredictable UI behavior. This makes your app unstable and difficult to debug. Always trigger state changes outside build(). {v6}',
    correctionMessage:
        'Move setState calls to event handlers or use WidgetsBinding.instance.addPostFrameCallback to schedule state changes after build completes.',
    severity: DiagnosticSeverity.ERROR,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodDeclaration((MethodDeclaration node) {
      if (node.name.lexeme != 'build') return;

      node.body.visitChildren(_SetStateVisitor(reporter, code));
    });
  }
}

class _SetStateVisitor extends RecursiveAstVisitor<void> {
  _SetStateVisitor(this.reporter, this.code);

  final SaropaDiagnosticReporter reporter;
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

      reporter.atNode(node);
    }
    super.visitMethodInvocation(node);
  }
}

/// Warns when string concatenation is used inside loops.
///
/// Since: v1.3.0 | Updated: v4.13.0 | Rule version: v3
///
/// String concatenation with + creates new String objects each iteration.
/// Use StringBuffer for building strings in loops.
///
/// Example of **bad** code:
/// ```dart
/// String result = '';
/// for (final item in items) {
///   result = result + item.name;  // Creates new String each time
/// }
/// ```
///
/// Example of **good** code:
/// ```dart
/// final buffer = StringBuffer();
/// for (final item in items) {
///   buffer.write(item.name);
/// }
/// final result = buffer.toString();
/// ```
class AvoidStringConcatenationLoopRule extends SaropaLintRule {
  AvoidStringConcatenationLoopRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'avoid_string_concatenation_loop',
    '[avoid_string_concatenation_loop] Each += creates new String object, '
        'causing O(n²) memory allocations in loops. {v3}',
    correctionMessage: 'Use StringBuffer for building strings in loops.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addBinaryExpression((BinaryExpression node) {
      // Check for string + operator
      if (node.operator.type != TokenType.PLUS) return;

      // Check if we're inside a loop
      if (!_isInsideLoop(node)) return;

      // Check if operands look like strings
      final String source = node.toSource();
      if (_looksLikeStringOperation(source)) {
        reporter.atNode(node);
      }
    });

    context.addAssignmentExpression((AssignmentExpression node) {
      // Check for += operator
      if (node.operator.type != TokenType.PLUS_EQ) return;

      // Check if we're inside a loop
      if (!_isInsideLoop(node)) return;

      // Check if it looks like a string operation
      final String leftSource = node.leftHandSide.toSource();
      if (_looksLikeStringVariable(leftSource)) {
        reporter.atNode(node);
      }
    });
  }

  bool _isInsideLoop(AstNode node) {
    AstNode? current = node.parent;
    while (current != null) {
      if (current is ForStatement ||
          current is ForElement ||
          current is WhileStatement ||
          current is DoStatement ||
          current is ForEachParts) {
        return true;
      }
      // Check for .forEach, .map, etc.
      if (current is MethodInvocation) {
        final String name = current.methodName.name;
        if (name == 'forEach' || name == 'map' || name == 'reduce') {
          return true;
        }
      }
      current = current.parent;
    }
    return false;
  }

  bool _looksLikeStringOperation(String source) {
    return source.contains("'") ||
        source.contains('"') ||
        source.toLowerCase().contains('string') ||
        source.contains('name') ||
        source.contains('text') ||
        source.contains('message');
  }

  bool _looksLikeStringVariable(String name) {
    final String lower = name.toLowerCase();
    return lower.contains('string') ||
        lower.contains('text') ||
        lower.contains('result') ||
        lower.contains('output') ||
        lower.contains('buffer') ||
        lower.contains('message');
  }
}

/// Warns when scroll listener is added in build method.
///
/// Since: v1.7.2 | Updated: v4.13.0 | Rule version: v2
///
/// Adding listeners in build() causes multiple subscriptions on every rebuild,
/// leading to memory leaks and performance issues.
///
/// **BAD:**
/// ```dart
/// Widget build(BuildContext context) {
///   scrollController.addListener(() {
///     print('Scrolled!');
///   });
///   return ListView(controller: scrollController);
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// @override
/// void initState() {
///   super.initState();
///   scrollController.addListener(_onScroll);
/// }
///
/// void _onScroll() { print('Scrolled!'); }
///
/// Widget build(BuildContext context) {
///   return ListView(controller: scrollController);
/// }
/// ```
class AvoidScrollListenerInBuildRule extends SaropaLintRule {
  AvoidScrollListenerInBuildRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'avoid_scroll_listener_in_build',
    '[avoid_scroll_listener_in_build] Scroll listener registered in build() accumulates duplicate subscriptions on every widget rebuild. Each rebuild adds another listener that is never removed, causing memory leaks, duplicate callback executions, and progressively degrading scroll performance as listeners compound over the widget lifecycle. {v2}',
    correctionMessage:
        'Register the scroll listener once in initState() and remove it in dispose() to prevent listener accumulation across widget rebuilds.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodDeclaration((MethodDeclaration node) {
      if (node.name.lexeme != 'build') return;

      node.body.visitChildren(_AddListenerVisitor(reporter, code));
    });
  }
}

class _AddListenerVisitor extends RecursiveAstVisitor<void> {
  _AddListenerVisitor(this.reporter, this.code);

  final SaropaDiagnosticReporter reporter;
  final LintCode code;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final String methodName = node.methodName.name;
    if (methodName == 'addListener' || methodName == 'addStatusListener') {
      reporter.atNode(node);
    }
    super.visitMethodInvocation(node);
  }
}

/// Warns when ValueListenableBuilder could simplify state management.
///
/// Since: v1.7.2 | Updated: v4.13.0 | Rule version: v3
///
/// For single values that need to trigger rebuilds, ValueListenableBuilder
/// is more efficient than StatefulWidget + setState.
///
/// **BAD:**
/// ```dart
/// class _MyState extends State<MyWidget> {
///   int _counter = 0;
///
///   Widget build(BuildContext context) {
///     return Text('$_counter');
///   }
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// final _counter = ValueNotifier<int>(0);
///
/// Widget build(BuildContext context) {
///   return ValueListenableBuilder<int>(
///     valueListenable: _counter,
///     builder: (context, value, child) => Text('$value'),
///   );
/// }
/// ```
class PreferValueListenableBuilderRule extends SaropaLintRule {
  PreferValueListenableBuilderRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'prefer_value_listenable_builder',
    '[prefer_value_listenable_builder] Simple single-value state managed with setState causes the entire widget subtree to rebuild on every change. ValueListenableBuilder isolates rebuilds to only the affected subtree, significantly reducing unnecessary widget tree comparisons, improving frame rendering performance, and lowering battery consumption. {v3}',
    correctionMessage:
        'Replace setState with a ValueNotifier field and wrap the dependent UI in ValueListenableBuilder to isolate rebuilds to only the affected subtree.',
    severity: DiagnosticSeverity.INFO,
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

      final NamedType superclass = extendsClause.superclass;
      if (superclass.name.lexeme != 'State') return;
      if (superclass.typeArguments == null) return;

      // Count non-final fields (state)
      int stateFieldCount = 0;
      int setStateCallCount = 0;

      for (final ClassMember member in node.members) {
        if (member is FieldDeclaration) {
          if (!member.isStatic && !member.fields.isFinal) {
            stateFieldCount++;
          }
        }
        if (member is MethodDeclaration) {
          member.body.visitChildren(
            _SetStateCounterVisitor(() => setStateCallCount++),
          );
        }
      }

      // Suggest ValueListenableBuilder if state is very simple
      // (1 field with few setState calls)
      if (stateFieldCount == 1 &&
          setStateCallCount >= 1 &&
          setStateCallCount <= 3) {
        reporter.atToken(node.name, code);
      }
    });
  }
}

class _SetStateCounterVisitor extends RecursiveAstVisitor<void> {
  _SetStateCounterVisitor(this.onSetState);

  final void Function() onSetState;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.methodName.name == 'setState') {
      onSetState();
    }
    super.visitMethodInvocation(node);
  }
}

/// Warns when GlobalKey is overused or misused.
///
/// Since: v1.7.2 | Updated: v4.13.0 | Rule version: v2
///
/// GlobalKeys are expensive - they persist across rebuilds and maintain
/// global state. Only use them when absolutely necessary (Form validation,
/// accessing state from outside, etc.).
///
/// **BAD:**
/// ```dart
/// // Using GlobalKey for styling or simple references
/// final _containerKey = GlobalKey();
/// final _textKey = GlobalKey();
/// final _buttonKey = GlobalKey();
/// ```
///
/// **GOOD:**
/// ```dart
/// // Only use GlobalKey when needed
/// final _formKey = GlobalKey<FormState>();
///
/// // Use ObjectKey or ValueKey for list items
/// ListView.builder(
///   itemBuilder: (_, i) => ListTile(key: ValueKey(items[i].id)),
/// )
/// ```
class AvoidGlobalKeyMisuseRule extends SaropaLintRule {
  AvoidGlobalKeyMisuseRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'avoid_global_key_misuse',
    '[avoid_global_key_misuse] Multiple GlobalKey instances in a single class indicate overuse of an expensive mechanism. Each GlobalKey prevents Flutter from efficiently diffing the widget tree, forces cross-tree reference tracking, and can cause unexpected widget reparenting that corrupts state and degrades rendering performance. {v2}',
    correctionMessage:
        'Use ValueKey or ObjectKey for list item identification. Reserve GlobalKey only for Form validation, accessing widget state, or navigator operations.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addClassDeclaration((ClassDeclaration node) {
      // Count GlobalKey fields
      final List<VariableDeclaration> globalKeyFields = <VariableDeclaration>[];

      for (final ClassMember member in node.members) {
        if (member is FieldDeclaration) {
          for (final VariableDeclaration variable in member.fields.variables) {
            final String? typeName = member.fields.type?.toSource();
            if (typeName != null && typeName.contains('GlobalKey')) {
              globalKeyFields.add(variable);
            }
            // Also check initializer
            final Expression? init = variable.initializer;
            if (init is InstanceCreationExpression) {
              final String initType = init.constructorName.type.name.lexeme;
              if (initType == 'GlobalKey') {
                if (!globalKeyFields.contains(variable)) {
                  globalKeyFields.add(variable);
                }
              }
            }
          }
        }
      }

      // Warn if more than 2 GlobalKeys (likely overuse)
      if (globalKeyFields.length > 2) {
        reporter.atToken(node.name, code);
      }
    });
  }
}

/// Warns when complex animations don't use RepaintBoundary.
///
/// Since: v1.7.2 | Updated: v4.13.0 | Rule version: v2
///
/// RepaintBoundary isolates paint operations, preventing expensive
/// repaints from affecting the entire widget tree.
///
/// **BAD:**
/// ```dart
/// Stack(
///   children: [
///     AnimatedBuilder(
///       animation: _controller,
///       builder: (_, __) => Transform.rotate(
///         angle: _controller.value * 2 * pi,
///         child: ComplexWidget(),
///       ),
///     ),
///     StaticContent(),
///   ],
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// Stack(
///   children: [
///     RepaintBoundary(
///       child: AnimatedBuilder(
///         animation: _controller,
///         builder: (_, __) => Transform.rotate(
///           angle: _controller.value * 2 * pi,
///           child: ComplexWidget(),
///         ),
///       ),
///     ),
///     StaticContent(),
///   ],
/// )
/// ```
class RequireRepaintBoundaryRule extends SaropaLintRule {
  RequireRepaintBoundaryRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'require_repaint_boundary',
    '[require_repaint_boundary] When animating complex widgets without a RepaintBoundary, the entire widget subtree is repainted on every frame, causing jank, dropped frames, and high CPU/GPU usage. This degrades performance, especially in lists or nested animations. {v2}',
    correctionMessage:
        'Wrap the animated widget or subtree with a RepaintBoundary to isolate repaints and improve performance.',
    severity: DiagnosticSeverity.INFO,
  );

  static const Set<String> _animatedWidgets = <String>{
    'AnimatedBuilder',
    'AnimatedWidget',
    'Transform',
    'RotationTransition',
    'ScaleTransition',
    'SlideTransition',
    'FadeTransition',
    'AnimatedOpacity',
    'AnimatedRotation',
    'AnimatedScale',
    'AnimatedSlide',
  };

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      final String? typeName = node.constructorName.type.element?.name;
      if (typeName == null || !_animatedWidgets.contains(typeName)) return;

      // Check if wrapped in RepaintBoundary
      AstNode? current = node.parent;
      int depth = 0;
      bool hasRepaintBoundary = false;

      while (current != null && depth < 5) {
        if (current is InstanceCreationExpression) {
          final String? parentType = current.constructorName.type.element?.name;
          if (parentType == 'RepaintBoundary') {
            hasRepaintBoundary = true;
            break;
          }
        }
        current = current.parent;
        depth++;
      }

      // Only report if inside Stack or complex layout (where isolation matters)
      if (!hasRepaintBoundary) {
        AstNode? parent = node.parent;
        while (parent != null) {
          if (parent is InstanceCreationExpression) {
            final String? parentType =
                parent.constructorName.type.element?.name;
            if (parentType == 'Stack' ||
                parentType == 'CustomMultiChildLayout') {
              reporter.atNode(node.constructorName, code);
              return;
            }
          }
          parent = parent.parent;
        }
      }
    });
  }
}

/// Warns when TextSpan is created in build method.
///
/// Since: v1.7.0 | Updated: v4.13.0 | Rule version: v4
///
/// TextSpan objects created in build() cannot be cached by Flutter's
/// rendering pipeline, causing unnecessary text layout calculations.
///
/// **BAD:**
/// ```dart
/// Widget build(BuildContext context) {
///   return RichText(
///     text: TextSpan(
///       children: [
///         TextSpan(text: 'Hello ', style: TextStyle(color: Colors.black)),
///         TextSpan(text: 'World', style: TextStyle(color: Colors.blue)),
///       ],
///     ),
///   );
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// // Cache as static const or class field
/// static const _textSpan = TextSpan(
///   children: [
///     TextSpan(text: 'Hello ', style: TextStyle(color: Colors.black)),
///     TextSpan(text: 'World', style: TextStyle(color: Colors.blue)),
///   ],
/// );
///
/// Widget build(BuildContext context) {
///   return RichText(text: _textSpan);
/// }
/// ```
class AvoidTextSpanInBuildRule extends SaropaLintRule {
  AvoidTextSpanInBuildRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'avoid_text_span_in_build',
    '[avoid_text_span_in_build] TextSpan recreated inside the build() method forces the Flutter rendering pipeline to recalculate expensive text layout metrics on every widget rebuild. This includes glyph positioning, line breaking, and paragraph layout. The repeated computation causes visible jank during scrolling and animations, especially for RichText with multiple styled spans. {v4}',
    correctionMessage:
        'Cache TextSpan as a final field or extract to a method that returns cached spans.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodDeclaration((MethodDeclaration node) {
      if (node.name.lexeme != 'build') return;

      node.body.visitChildren(_TextSpanVisitor(reporter, code));
    });
  }
}

class _TextSpanVisitor extends RecursiveAstVisitor<void> {
  _TextSpanVisitor(this.reporter, this.code);

  final SaropaDiagnosticReporter reporter;
  final LintCode code;

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    final String typeName = node.constructorName.type.name.lexeme;
    if (typeName == 'TextSpan') {
      // Check if it's a const creation (which is fine)
      if (!node.isConst) {
        // Check if it has children (complex TextSpan worth caching)
        final bool hasChildren = node.argumentList.arguments.any((
          Expression arg,
        ) {
          if (arg is NamedExpression) {
            return arg.name.label.name == 'children';
          }
          return false;
        });

        if (hasChildren) {
          reporter.atNode(node.constructorName, code);
        }
      }
    }
    super.visitInstanceCreationExpression(node);
  }
}

/// Warns when List.from() or toList() copies large collections.
///
/// Since: v1.3.0 | Updated: v4.13.0 | Rule version: v3
///
/// These methods copy all elements to a new list, which is expensive
/// for large collections. Consider using lazy operations instead.
///
/// Example of **bad** code:
/// ```dart
/// final copy = List.from(largeList);
/// final filtered = largeList.where((e) => e > 0).toList();
/// ```
///
/// Example of **good** code:
/// ```dart
/// // Use Iterable operations lazily
/// final filtered = largeList.where((e) => e > 0);
/// // Or document the intentional copy
/// final copy = List<int>.of(largeList); // Explicit copy
/// ```
class AvoidLargeListCopyRule extends SaropaLintRule {
  AvoidLargeListCopyRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'avoid_large_list_copy',
    '[avoid_large_list_copy] List.from() and toList() allocate a new list and copy every element, doubling memory consumption for the duration of the operation. For large collections, this triggers garbage collection pauses that freeze the UI and degrade scrolling performance. The unnecessary allocation pressure accumulates rapidly in loops or frequently called methods. {v3}',
    correctionMessage:
        'Use lazy Iterable operations (like map, where, or take) instead of copying large lists, unless a full copy is required. If you must copy, document why to help maintainers understand the performance tradeoff.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    // Check for List.from()
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      final String typeName = node.constructorName.type.name.lexeme;
      if (typeName != 'List') return;

      final SimpleIdentifier? constructorName = node.constructorName.name;
      if (constructorName?.name == 'from') {
        reporter.atNode(node.constructorName, code);
      }
    });

    // Check for .toList() after filtering operations
    context.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name != 'toList') return;

      // Check if called on a chain of operations
      final Expression? target = node.target;
      if (target is MethodInvocation) {
        final String methodName = target.methodName.name;
        // Warn if copying after filter/map operations
        if (methodName == 'where' ||
            methodName == 'map' ||
            methodName == 'expand' ||
            methodName == 'take' ||
            methodName == 'skip') {
          reporter.atNode(node.methodName, code);
        }
      }
    });
  }
}

// ============================================================================
// Batch 11: Additional Performance Rules
// ============================================================================

/// Warns when widgets that could be const are not declared as const.
///
/// Since: v2.7.0 | Updated: v4.13.0 | Rule version: v4
///
/// Widgets that can be const are created once and reused. Without const,
/// Flutter creates new instances on every parent rebuild.
///
/// **BAD:**
/// ```dart
/// Container(
///   child: Text('Hello'), // Could be const
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// Container(
///   child: const Text('Hello'),
/// )
/// ```
class PreferConstWidgetsRule extends SaropaLintRule {
  PreferConstWidgetsRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    'prefer_const_widgets',
    '[prefer_const_widgets] Widget constructor could use const but is recreated on every build() call. Non-const widgets force Flutter to allocate new instances, compare entire subtrees, and perform unnecessary rebuilds. This wastes CPU cycles and battery, degrading frame rendering performance especially in frequently rebuilt parent widgets. {v4}',
    correctionMessage:
        'Add the const keyword to the widget constructor call to enable compile-time canonicalization and skip unnecessary widget tree comparisons during rebuilds.',
    severity: DiagnosticSeverity.INFO,
  );

  static const Set<String> _simpleWidgets = <String>{
    'Text',
    'Icon',
    'SizedBox',
    'Spacer',
    'Divider',
    'Placeholder',
  };

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      if (node.isConst) return; // Already const

      final String typeName = node.constructorName.type.name.lexeme;
      if (!_simpleWidgets.contains(typeName)) return;

      // Check if all arguments are literals or const
      bool canBeConst = true;
      for (final Expression arg in node.argumentList.arguments) {
        final Expression expr = arg is NamedExpression ? arg.expression : arg;
        if (expr is! Literal && !_isConstExpression(expr)) {
          canBeConst = false;
          break;
        }
      }

      if (canBeConst) {
        reporter.atNode(node.constructorName, code);
      }
    });
  }

  bool _isConstExpression(Expression expr) {
    if (expr is Literal) return true;
    if (expr is InstanceCreationExpression) return expr.isConst;
    if (expr is PrefixedIdentifier) return true; // Enum values, etc.
    if (expr is SimpleIdentifier) {
      // Check for known constants
      final String name = expr.name;
      return name == name.toUpperCase() || // SCREAMING_CASE constants
          name.startsWith('k'); // kConstant convention
    }
    return false;
  }
}

/// Warns when expensive computations are performed in build method.
///
/// Since: v1.7.2 | Updated: v4.13.0 | Rule version: v2
///
/// build() is called frequently (60fps during animations). Sorting,
/// filtering, or complex calculations here cause frame drops.
///
/// **BAD:**
/// ```dart
/// Widget build(BuildContext context) {
///   final sorted = items.toList()..sort(); // Sorts every rebuild!
///   return ListView(children: sorted.map((e) => Text(e)).toList());
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// List<String>? _sortedItems;
///
/// Widget build(BuildContext context) {
///   _sortedItems ??= items.toList()..sort();
///   return ListView(children: _sortedItems!.map((e) => Text(e)).toList());
/// }
/// ```
class AvoidExpensiveComputationInBuildRule extends SaropaLintRule {
  AvoidExpensiveComputationInBuildRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'avoid_expensive_computation_in_build',
    '[avoid_expensive_computation_in_build] Expensive computation detected inside build() method. Build runs on every frame during animations and on every state change, so heavy operations here cause jank, dropped frames, and sluggish UI responsiveness. Users will experience visible stuttering especially during transitions and scrolling. {v2}',
    correctionMessage:
        'Cache the computation result in a field, compute it in initState() or didChangeDependencies(), or use memoization to avoid repeated expensive work.',
    severity: DiagnosticSeverity.WARNING,
  );

  static const Set<String> _expensiveMethods = <String>{
    'sort',
    'shuffle',
    'reversed',
    'reduce',
    'fold',
    'join',
  };

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodDeclaration((MethodDeclaration node) {
      if (node.name.lexeme != 'build') return;

      node.body.visitChildren(_ExpensiveMethodVisitor(reporter, code));
    });
  }
}

class _ExpensiveMethodVisitor extends RecursiveAstVisitor<void> {
  _ExpensiveMethodVisitor(this.reporter, this.code);

  final SaropaDiagnosticReporter reporter;
  final LintCode code;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (AvoidExpensiveComputationInBuildRule._expensiveMethods.contains(
      node.methodName.name,
    )) {
      reporter.atNode(node);
    }
    super.visitMethodInvocation(node);
  }
}

/// Warns when widgets are created inside loops in build method.
///
/// Since: v1.7.2 | Updated: v4.13.0 | Rule version: v3
///
/// Creating widgets inside loops (.map()) in build creates new instances
/// every rebuild. Extract to a method or use ListView.builder.
///
/// **BAD:**
/// ```dart
/// Widget build(BuildContext context) {
///   return Column(
///     children: items.map((item) => ItemWidget(item)).toList(),
///   );
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// Widget build(BuildContext context) {
///   return ListView.builder(
///     itemCount: items.length,
///     itemBuilder: (context, index) => ItemWidget(items[index]),
///   );
/// }
/// ```
class AvoidWidgetCreationInLoopRule extends SaropaLintRule {
  AvoidWidgetCreationInLoopRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    'avoid_widget_creation_in_loop',
    '[avoid_widget_creation_in_loop] Widgets created in .map() or a loop are all instantiated eagerly on every rebuild, including those currently off-screen. This causes jank, high memory usage, and slow rendering for long lists because Flutter allocates and lays out every item upfront instead of lazily constructing only visible items. {v3}',
    correctionMessage:
        'Use ListView.builder or SliverList.builder for lazy construction that only creates widgets as they scroll into view, reducing memory usage and improving performance.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodDeclaration((MethodDeclaration node) {
      if (node.name.lexeme != 'build') return;

      node.body.visitChildren(_MapWidgetVisitor(reporter, code));
    });
  }
}

class _MapWidgetVisitor extends RecursiveAstVisitor<void> {
  _MapWidgetVisitor(this.reporter, this.code);

  final SaropaDiagnosticReporter reporter;
  final LintCode code;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.methodName.name == 'map') {
      // Check if the argument creates widgets
      for (final Expression arg in node.argumentList.arguments) {
        if (arg is FunctionExpression) {
          final String bodySource = arg.body.toSource();
          // Simple heuristic: uppercase first letter suggests widget
          if (RegExp(r'\b[A-Z][a-zA-Z]+\(').hasMatch(bodySource)) {
            reporter.atNode(node.methodName, code);
          }
        }
      }
    }
    super.visitMethodInvocation(node);
  }
}

/// Warns when Theme.of or MediaQuery.of is called multiple times in build.
///
/// Since: v1.7.2 | Updated: v4.13.0 | Rule version: v3
///
/// These methods traverse the widget tree. Call once and store in a
/// local variable, or use specific methods like MediaQuery.sizeOf().
///
/// **BAD:**
/// ```dart
/// Widget build(BuildContext context) {
///   return Container(
///     color: Theme.of(context).primaryColor,
///     child: Text(
///       'Hello',
///       style: Theme.of(context).textTheme.bodyLarge, // Second call!
///     ),
///   );
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// Widget build(BuildContext context) {
///   final theme = Theme.of(context);
///   return Container(
///     color: theme.primaryColor,
///     child: Text('Hello', style: theme.textTheme.bodyLarge),
///   );
/// }
/// ```
class AvoidCallingOfInBuildRule extends SaropaLintRule {
  AvoidCallingOfInBuildRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'avoid_calling_of_in_build',
    '[avoid_calling_of_in_build] Multiple .of(context) lookups walk the InheritedWidget ancestor chain on every rebuild call. Each lookup traverses the widget tree upward, adding cumulative overhead that slows frame rendering. This is especially costly when called multiple times in a single build method for the same provider type. {v3}',
    correctionMessage:
        'Cache the lookup result in a local variable at the top of build(): final theme = Theme.of(context); then reference the variable throughout the method.',
    severity: DiagnosticSeverity.INFO,
  );

  static const Set<String> _ofMethods = <String>{
    'Theme',
    'MediaQuery',
    'Navigator',
    'Scaffold',
    'DefaultTextStyle',
  };

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodDeclaration((MethodDeclaration node) {
      if (node.name.lexeme != 'build') return;

      final Map<String, int> ofCallCounts = <String, int>{};
      final List<MethodInvocation> duplicateCalls = <MethodInvocation>[];

      node.body.visitChildren(
        _OfCallVisitor((MethodInvocation call) {
          final Expression? target = call.target;
          if (target is SimpleIdentifier) {
            final String typeName = target.name;
            ofCallCounts[typeName] = (ofCallCounts[typeName] ?? 0) + 1;
            if (ofCallCounts[typeName]! > 1) {
              duplicateCalls.add(call);
            }
          }
        }),
      );

      for (final MethodInvocation call in duplicateCalls) {
        reporter.atNode(call);
      }
    });
  }
}

class _OfCallVisitor extends RecursiveAstVisitor<void> {
  _OfCallVisitor(this.onOfCall);

  final void Function(MethodInvocation) onOfCall;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.methodName.name == 'of') {
      final Expression? target = node.target;
      if (target is SimpleIdentifier &&
          AvoidCallingOfInBuildRule._ofMethods.contains(target.name)) {
        onOfCall(node);
      }
    }
    super.visitMethodInvocation(node);
  }
}

/// Warns when image cache is not managed in apps with many images.
///
/// Since: v1.7.0 | Updated: v4.13.0 | Rule version: v3
///
/// Flutter's ImageCache grows unbounded by default. Large images
/// accumulate in memory. Call imageCache.clear() when appropriate.
///
/// **BAD:**
/// ```dart
/// // Loading many images without cache management
/// for (final url in imageUrls) {
///   Image.network(url);
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// // Clear cache when navigating away from image-heavy screens
/// @override
/// void dispose() {
///   imageCache.clear();
///   super.dispose();
/// }
/// ```
class RequireImageCacheManagementRule extends SaropaLintRule {
  RequireImageCacheManagementRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'require_image_cache_management',
    '[require_image_cache_management] Loading many images without cache management causes unbounded memory growth. The default ImageCache retains decoded images indefinitely, and without explicit eviction, memory usage climbs until the OS kills the app. Users on devices with limited RAM will experience crashes and degraded multitasking. {v3}',
    correctionMessage:
        'Call PaintingBinding.instance.imageCache.evict(url) in dispose() or set imageCache.maximumSize to limit retained images and prevent unbounded memory growth.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addClassDeclaration((ClassDeclaration node) {
      int imageCount = 0;
      bool hasImageCacheClear = false;

      for (final ClassMember member in node.members) {
        final String source = member.toSource();
        if (source.contains('Image.network') ||
            source.contains('Image.asset') ||
            source.contains('CachedNetworkImage')) {
          imageCount++;
        }
        if (source.contains('imageCache.clear') ||
            source.contains('imageCache.evict')) {
          hasImageCacheClear = true;
        }
      }

      // Warn if loading 5+ images without cache management
      if (imageCount >= 5 && !hasImageCacheClear) {
        reporter.atNode(node);
      }
    });
  }
}

/// Warns when memory-intensive operations are detected.
///
/// Since: v1.7.2 | Updated: v4.13.0 | Rule version: v2
///
/// Allocating large lists, loading full images into memory, or string
/// concatenation in loops can cause out-of-memory crashes.
///
/// **BAD:**
/// ```dart
/// String result = '';
/// for (final item in items) {
///   result += item.toString(); // O(n²) string allocation!
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// final buffer = StringBuffer();
/// for (final item in items) {
///   buffer.write(item.toString());
/// }
/// final result = buffer.toString();
/// ```
class AvoidMemoryIntensiveOperationsRule extends SaropaLintRule {
  AvoidMemoryIntensiveOperationsRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'avoid_memory_intensive_operations',
    '[avoid_memory_intensive_operations] String concatenation using += inside a loop creates a new String object on every iteration, resulting in O(n squared) memory allocations. Each iteration copies the entire accumulated string, causing excessive garbage collection pressure, UI thread pauses, and visible jank in animations or scrolling. {v2}',
    correctionMessage:
        'Use StringBuffer to build strings incrementally inside loops. StringBuffer.write() appends in-place without creating intermediate String copies, reducing allocation to O(n).',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addForStatement((ForStatement node) {
      node.body.visitChildren(_StringConcatVisitor(reporter, code));
    });

    context.addForElement((ForElement node) {
      node.body.visitChildren(_StringConcatVisitor(reporter, code));
    });

    context.addWhileStatement((WhileStatement node) {
      node.body.visitChildren(_StringConcatVisitor(reporter, code));
    });
  }
}

class _StringConcatVisitor extends RecursiveAstVisitor<void> {
  _StringConcatVisitor(this.reporter, this.code);

  final SaropaDiagnosticReporter reporter;
  final LintCode code;

  @override
  void visitAssignmentExpression(AssignmentExpression node) {
    // Check for += with strings
    if (node.operator.type == TokenType.PLUS_EQ) {
      final Expression left = node.leftHandSide;
      if (left is SimpleIdentifier) {
        // Simple heuristic - variable names suggesting strings
        final String name = left.name.toLowerCase();
        if (name.contains('str') ||
            name.contains('text') ||
            name.contains('result') ||
            name.contains('output')) {
          reporter.atNode(node);
        }
      }
    }
    super.visitAssignmentExpression(node);
  }
}

/// Warns when closures capture widget references causing memory leaks.
///
/// Since: v1.7.2 | Updated: v4.13.0 | Rule version: v3
///
/// Closures capture their enclosing scope. A closure referencing `this`
/// in a callback keeps the entire widget alive even after disposal.
///
/// **BAD:**
/// ```dart
/// void initState() {
///   someStream.listen((data) {
///     setState(() => _data = data); // Captures State
///   });
///   super.initState();
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// StreamSubscription? _subscription;
///
/// void initState() {
///   _subscription = someStream.listen((data) {
///     if (mounted) setState(() => _data = data);
///   });
///   super.initState();
/// }
///
/// void dispose() {
///   _subscription?.cancel();
///   super.dispose();
/// }
/// ```
class AvoidClosureMemoryLeakRule extends SaropaLintRule {
  AvoidClosureMemoryLeakRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'avoid_closure_memory_leak',
    '[avoid_closure_memory_leak] Closure capturing setState retains a strong reference to the State object, preventing garbage collection after the widget is disposed. The entire parent widget subtree leaks memory, and calling setState on an unmounted widget throws a framework error that crashes the app during subsequent navigation. {v3}',
    correctionMessage:
        'Store the subscription in a field, cancel it in dispose(), and add a mounted check before calling setState to prevent leaks and post-disposal crashes.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodDeclaration((MethodDeclaration node) {
      if (node.name.lexeme != 'initState') return;

      // Check for stream.listen with setState inside
      node.body.visitChildren(_StreamListenVisitor(reporter, code));
    });
  }
}

class _StreamListenVisitor extends RecursiveAstVisitor<void> {
  _StreamListenVisitor(this.reporter, this.code);

  final SaropaDiagnosticReporter reporter;
  final LintCode code;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.methodName.name == 'listen') {
      // Check if callback has setState without mounted check
      for (final Expression arg in node.argumentList.arguments) {
        if (arg is FunctionExpression) {
          final String bodySource = arg.body.toSource();
          if (bodySource.contains('setState') &&
              !bodySource.contains('mounted')) {
            reporter.atNode(node);
          }
        }
      }
    }
    super.visitMethodInvocation(node);
  }
}

/// Warns when widgets could be static const for better performance.
///
/// Since: v1.7.0 | Updated: v4.13.0 | Rule version: v3
///
/// `static const` widgets are created once at compile time. Instance
/// widgets are recreated on every parent rebuild.
///
/// **BAD:**
/// ```dart
/// class MyWidget extends StatelessWidget {
///   final divider = const Divider(); // Created per instance
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// class MyWidget extends StatelessWidget {
///   static const divider = Divider(); // Created once at compile time
/// }
/// ```
class PreferStaticConstWidgetsRule extends SaropaLintRule {
  PreferStaticConstWidgetsRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    'prefer_static_const_widgets',
    '[prefer_static_const_widgets] Non-static const field is created per '
        'instance instead of sharing single compile-time object. {v3}',
    correctionMessage: 'Add static modifier: static const widget = Widget();',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addFieldDeclaration((FieldDeclaration node) {
      if (node.isStatic) return; // Already static

      // Check for const widget fields
      if (node.fields.isConst) {
        for (final VariableDeclaration variable in node.fields.variables) {
          final Expression? initializer = variable.initializer;
          if (initializer is InstanceCreationExpression &&
              initializer.isConst) {
            reporter.atNode(variable);
          }
        }
      }
    });
  }
}

/// Warns when dispose pattern is not followed for resource classes.
///
/// Since: v1.7.0 | Updated: v4.13.0 | Rule version: v4
///
/// Objects holding resources (streams, controllers, subscriptions)
/// must be disposed. Undisposed resources leak memory and cause crashes.
///
/// **BAD:**
/// ```dart
/// class MyManager {
///   final _controller = StreamController<int>();
///   // Missing close!
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// class MyManager {
///   final _controller = StreamController<int>();
///
///   void dispose() {
///     _controller.close();
///   }
/// }
/// ```
class RequireDisposePatternRule extends SaropaLintRule {
  RequireDisposePatternRule() : super(code: _code);

  static const LintCode _code = LintCode(
    'require_dispose_pattern',
    '[require_dispose_pattern] Class has StreamController, AnimationController, or other disposable fields but no cleanup method. These controllers leak memory and can crash when accessed after disposal. {v4}',
    correctionMessage:
        'Add dispose() or close() method to clean up resources. Profile the affected code path to confirm the improvement under realistic workloads.',
    severity: DiagnosticSeverity.WARNING,
  );

  static const Set<String> _disposableTypes = <String>{
    'StreamController',
    'AnimationController',
    'TextEditingController',
    'ScrollController',
    'TabController',
    'FocusNode',
    'Timer',
  };

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addClassDeclaration((ClassDeclaration node) {
      // Skip widget and State classes:
      // - State classes are handled by other lifecycle rules
      // - StatefulWidget/StatelessWidget are immutable and receive
      //   controllers as constructor params (they don't own them)
      final ExtendsClause? extendsClause = node.extendsClause;
      if (extendsClause != null) {
        final String superName = extendsClause.superclass.name.lexeme;
        if (superName == 'State' ||
            superName == 'StatefulWidget' ||
            superName == 'StatelessWidget') {
          return;
        }
      }

      bool hasDisposable = false;
      bool hasDisposeMethod = false;

      for (final ClassMember member in node.members) {
        if (member is FieldDeclaration) {
          final String? typeName = member.fields.type?.toSource();
          if (typeName != null) {
            for (final String disposable in _disposableTypes) {
              if (typeName.contains(disposable)) {
                hasDisposable = true;
                break;
              }
            }
          }
        }
        if (member is MethodDeclaration) {
          final String name = member.name.lexeme;
          if (name == 'dispose' || name == 'close') {
            hasDisposeMethod = true;
          }
        }
      }

      if (hasDisposable && !hasDisposeMethod) {
        reporter.atNode(node);
      }
    });
  }
}

// ============================================================================
// Batch 17: Additional Performance Rules
// ============================================================================

/// Warns when list is grown dynamically instead of preallocated.
///
/// Since: v4.13.0 | Rule version: v1
///
/// Growing a list dynamically with add() in a loop causes multiple
/// reallocations. Preallocate with List.filled() or List.generate().
///
/// **BAD:**
/// ```dart
/// final List<int> squares = [];
/// for (int i = 0; i < 10000; i++) {
///   squares.add(i * i); // Multiple reallocations!
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// final List<int> squares = List.generate(10000, (i) => i * i);
/// // Or:
/// final List<int> squares = List.filled(10000, 0);
/// for (int i = 0; i < 10000; i++) {
///   squares[i] = i * i;
/// }
/// ```
class RequireListPreallocateRule extends SaropaLintRule {
  RequireListPreallocateRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'require_list_preallocate',
    '[require_list_preallocate] Using List.add() inside a loop without preallocating the list causes repeated memory reallocations (O(n^2) time), which slows down your app and wastes resources. This is especially problematic for large lists or performance-critical code. {v1}',
    correctionMessage:
        'Preallocate the list with List.generate(), List.filled(), or use growable: false and set an initial size to avoid repeated reallocations.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name != 'add') return;

      // Check if inside a loop
      if (!_isInsideLoop(node)) return;

      // Check if target looks like a list variable
      final Expression? target = node.target;
      if (target is! SimpleIdentifier) return;

      // Heuristic: Check if the list was declared empty
      // We look for patterns like `final list = <Type>[]` or `List<T>()`
      AstNode? current = node.parent;
      while (current != null) {
        if (current is FunctionBody || current is MethodDeclaration) {
          break;
        }
        current = current.parent;
      }

      if (current == null) return;

      // Search for the variable declaration
      final String listName = target.name;
      final _EmptyListFinder finder = _EmptyListFinder(listName);
      current.visitChildren(finder);

      if (finder.foundEmptyList) {
        reporter.atNode(node);
      }
    });
  }

  bool _isInsideLoop(AstNode node) {
    AstNode? current = node.parent;
    while (current != null) {
      if (current is ForStatement ||
          current is ForElement ||
          current is WhileStatement ||
          current is DoStatement) {
        return true;
      }
      // Check for .forEach, .map, etc.
      if (current is MethodInvocation) {
        final String name = current.methodName.name;
        if (name == 'forEach') {
          return true;
        }
      }
      current = current.parent;
    }
    return false;
  }
}

class _EmptyListFinder extends RecursiveAstVisitor<void> {
  _EmptyListFinder(this.targetName);

  final String targetName;
  bool foundEmptyList = false;

  @override
  void visitVariableDeclaration(VariableDeclaration node) {
    if (node.name.lexeme != targetName) {
      super.visitVariableDeclaration(node);
      return;
    }

    final Expression? init = node.initializer;
    if (init == null) {
      super.visitVariableDeclaration(node);
      return;
    }

    final String initSource = init.toSource();
    // Check for empty list patterns: [], <Type>[], List(), List<T>()
    if (initSource == '[]' ||
        initSource.endsWith('[]') ||
        initSource == 'List()' ||
        RegExp(r'List<\w+>\(\)').hasMatch(initSource)) {
      foundEmptyList = true;
    }

    super.visitVariableDeclaration(node);
  }
}

/// Suggests using if/return instead of ternary for expensive widgets.
///
/// Since: v4.13.0 | Rule version: v1
///
/// While ternary expressions only return one branch, complex widget
/// constructors in both branches can make the code harder to read.
/// Consider using early return for cleaner code with expensive widgets.
///
/// **OK but verbose:**
/// ```dart
/// Widget build(context) {
///   return isLoading
///     ? CircularProgressIndicator()
///     : ListView.builder(...); // Complex widget in ternary
/// }
/// ```
///
/// **Better - cleaner with early return:**
/// ```dart
/// Widget build(context) {
///   if (isLoading) return CircularProgressIndicator();
///   return ListView.builder(...);
/// }
/// ```
class PreferBuilderForConditionalRule extends SaropaLintRule {
  PreferBuilderForConditionalRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'prefer_builder_for_conditional',
    '[prefer_builder_for_conditional] Complex widget in ternary conditional. Prefer if/return for readability. This introduces unnecessary computational overhead that degrades responsiveness and increases battery drain on mobile. {v1}',
    correctionMessage:
        'Use if/return pattern for cleaner code: if (cond) return A(); return B();. Profile the affected code path to confirm the improvement under realistic workloads.',
    severity: DiagnosticSeverity.INFO,
  );

  /// Widget types that are expensive to create
  static const Set<String> _expensiveWidgets = <String>{
    'ListView',
    'GridView',
    'DataTable',
    'CustomScrollView',
    'PageView',
    'TabBarView',
    'ExpansionPanelList',
    'Stepper',
    'ReorderableListView',
  };

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addConditionalExpression((ConditionalExpression node) {
      // Check if inside a build method
      final MethodDeclaration? method = node
          .thisOrAncestorOfType<MethodDeclaration>();
      if (method == null || method.name.lexeme != 'build') return;

      // Check thenExpression and elseExpression for expensive widgets
      _checkExpressionForExpensiveWidget(node.thenExpression, reporter);
      _checkExpressionForExpensiveWidget(node.elseExpression, reporter);
    });
  }

  void _checkExpressionForExpensiveWidget(
    Expression expr,
    SaropaDiagnosticReporter reporter,
  ) {
    if (expr is InstanceCreationExpression) {
      final String typeName = expr.constructorName.type.name.lexeme;
      if (_expensiveWidgets.contains(typeName)) {
        // Check if already wrapped in Builder
        final AstNode? parent = expr.parent;
        if (parent is NamedExpression && parent.name.label.name == 'builder') {
          return; // Already using Builder pattern
        }
        reporter.atNode(expr.constructorName, code);
      }
    }
  }
}

/// Warns when widgets in lists don't have consistent key strategy.
///
/// Since: v4.13.0 | Rule version: v1
///
/// Keys help Flutter efficiently update widget trees. Without keys or with
/// inconsistent keys, Flutter may rebuild more than necessary.
///
/// **BAD:**
/// ```dart
/// ListView.builder(
///   itemBuilder: (context, index) {
///     // Sometimes uses key, sometimes doesn't
///     if (items[index].important) {
///       return ImportantItem(key: ValueKey(items[index].id));
///     }
///     return NormalItem(); // No key!
///   },
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// ListView.builder(
///   itemBuilder: (context, index) {
///     final item = items[index];
///     return item.important
///       ? ImportantItem(key: ValueKey(item.id), item: item)
///       : NormalItem(key: ValueKey(item.id), item: item);
///   },
/// )
/// ```
class RequireWidgetKeyStrategyRule extends SaropaLintRule {
  RequireWidgetKeyStrategyRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    'require_widget_key_strategy',
    '[require_widget_key_strategy] Inconsistent key usage in itemBuilder - some returns have keys, others do not. Keys help Flutter efficiently update widget trees. Without keys or with inconsistent keys, Flutter may rebuild more than necessary. {v1}',
    correctionMessage:
        'Apply consistent key strategy: either all items have keys or none do. Profile the affected code path to confirm the improvement under realistic workloads.',
    severity: DiagnosticSeverity.INFO,
  );

  /// Widget types that use itemBuilder pattern
  static const Set<String> _builderWidgets = <String>{
    'ListView',
    'GridView',
    'SliverList',
    'SliverGrid',
  };

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      final String typeName = node.constructorName.type.name.lexeme;
      if (!_builderWidgets.contains(typeName)) return;

      // Find itemBuilder argument
      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression && arg.name.label.name == 'itemBuilder') {
          final Expression builderExpr = arg.expression;
          if (builderExpr is FunctionExpression) {
            _checkBuilderForConsistentKeys(
              builderExpr.body,
              reporter,
              node.constructorName,
            );
          }
        }
      }
    });
  }

  void _checkBuilderForConsistentKeys(
    FunctionBody body,
    SaropaDiagnosticReporter reporter,
    AstNode reportNode,
  ) {
    // Collect all return statements and check for key consistency
    final _KeyConsistencyVisitor visitor = _KeyConsistencyVisitor();
    body.visitChildren(visitor);

    // If we have mixed key usage, report
    if (visitor.hasKeyedReturn && visitor.hasUnkeyedReturn) {
      reporter.atNode(reportNode);
    }
  }
}

class _KeyConsistencyVisitor extends RecursiveAstVisitor<void> {
  bool hasKeyedReturn = false;
  bool hasUnkeyedReturn = false;

  @override
  void visitReturnStatement(ReturnStatement node) {
    final Expression? expr = node.expression;
    if (expr is InstanceCreationExpression) {
      final bool hasKey = expr.argumentList.arguments.any((Expression arg) {
        if (arg is NamedExpression) {
          return arg.name.label.name == 'key';
        }
        return false;
      });

      if (hasKey) {
        hasKeyedReturn = true;
      } else {
        hasUnkeyedReturn = true;
      }
    }
    super.visitReturnStatement(node);
  }
}

// =============================================================================
// Platform-Specific Rules
// =============================================================================

/// Warns when desktop app lacks menu bar.
///
/// Since: v2.0.0 | Updated: v4.13.0 | Rule version: v4
///
/// Desktop apps should have a menu bar for keyboard shortcuts and
/// standard desktop interactions.
///
/// **BAD:**
/// ```dart
/// MaterialApp(
///   home: Scaffold(...),
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// MaterialApp(
///   builder: (context, child) => PlatformMenuBar(
///     menus: [...],
///     child: child!,
///   ),
///   home: Scaffold(...),
/// )
/// ```
class RequireMenuBarForDesktopRule extends SaropaLintRule {
  RequireMenuBarForDesktopRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'require_menu_bar_for_desktop',
    '[require_menu_bar_for_desktop] Desktop app without PlatformMenuBar lacks standard keyboard shortcuts. Desktop apps must have a menu bar for keyboard shortcuts and standard desktop interactions. {v4}',
    correctionMessage:
        'Add PlatformMenuBar for standard desktop experience. Profile the affected code path to confirm the improvement under realistic workloads.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    bool hasPlatformMenuBar = false;
    InstanceCreationExpression? materialApp;

    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      final String typeName = node.constructorName.type.name.lexeme;

      if (typeName == 'PlatformMenuBar' || typeName == 'MenuBar') {
        hasPlatformMenuBar = true;
      }

      if (typeName == 'MaterialApp' || typeName == 'CupertinoApp') {
        materialApp = node;
      }
    });

    context.addPostRunCallback(() {
      // Only report for desktop platforms
      final String path = context.filePath;
      if (path.contains('_desktop') ||
          path.contains('_macos') ||
          path.contains('_windows') ||
          path.contains('_linux')) {
        if (materialApp != null && !hasPlatformMenuBar) {
          reporter.atNode(materialApp!.constructorName, code);
        }
      }
    });
  }
}

/// Warns when desktop app lacks window close confirmation.
///
/// Since: v2.0.0 | Updated: v4.13.0 | Rule version: v3
///
/// Desktop apps with unsaved data should confirm before closing to
/// prevent data loss.
///
/// **BAD:**
/// ```dart
/// void main() {
///   runApp(MyApp());
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// void main() {
///   WidgetsBinding.instance.addObserver(AppLifecycleObserver());
///   runApp(MyApp());
/// }
///
/// class AppLifecycleObserver extends WidgetsBindingObserver {
///   @override
///   Future<bool> didRequestAppExit() async {
///     if (hasUnsavedChanges) {
///       return showSaveDialog();
///     }
///     return true;
///   }
/// }
/// ```
class RequireWindowCloseConfirmationRule extends SaropaLintRule {
  RequireWindowCloseConfirmationRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'require_window_close_confirmation',
    '[require_window_close_confirmation] Desktop app should handle window close confirmation. Desktop apps with unsaved data should confirm before closing to prevent data loss. This introduces unnecessary computational overhead that degrades responsiveness and increases battery drain on mobile. {v3}',
    correctionMessage:
        'Implement didRequestAppExit for save confirmation. Profile the affected code path to confirm the improvement under realistic workloads.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    // Only check desktop-specific files
    final String path = context.filePath;
    if (!path.contains('_desktop') &&
        !path.contains('_macos') &&
        !path.contains('_windows') &&
        !path.contains('_linux') &&
        !path.contains('/macos/') &&
        !path.contains('/windows/') &&
        !path.contains('/linux/')) {
      return;
    }

    bool hasAppExitHandler = false;
    ClassDeclaration? observerClass;

    context.addMethodDeclaration((MethodDeclaration node) {
      if (node.name.lexeme == 'didRequestAppExit') {
        hasAppExitHandler = true;
      }
    });

    context.addClassDeclaration((ClassDeclaration node) {
      final ExtendsClause? extendsClause = node.extendsClause;
      if (extendsClause != null) {
        final String superName = extendsClause.superclass.name2.lexeme;
        if (superName == 'WidgetsBindingObserver') {
          observerClass = node;
        }
      }
    });

    context.addPostRunCallback(() {
      if (observerClass != null && !hasAppExitHandler) {
        reporter.atNode(observerClass!, code);
      }
    });
  }
}

/// Warns when custom file dialog is used instead of native on desktop.
///
/// Since: v2.0.0 | Updated: v4.13.0 | Rule version: v2
///
/// Desktop platforms have native file dialogs that users expect.
/// Using custom dialogs creates inconsistent UX.
///
/// **BAD:**
/// ```dart
/// showDialog(
///   context: context,
///   builder: (context) => CustomFilePicker(),
/// );
/// ```
///
/// **GOOD:**
/// ```dart
/// final result = await FilePicker.platform.pickFiles();
/// // Or use file_selector package for desktop-native experience
/// ```
class PreferNativeFileDialogsRule extends SaropaLintRule {
  PreferNativeFileDialogsRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'prefer_native_file_dialogs',
    '[prefer_native_file_dialogs] Use native file dialogs on desktop. Desktop platforms have native file dialogs that users expect. Using custom dialogs creates inconsistent UX. {v2}',
    correctionMessage:
        'Use file_picker or file_selector for native experience. Profile the affected code path to confirm the improvement under realistic workloads.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name != 'showDialog') return;

      // Check if dialog is for file selection
      final ArgumentList args = node.argumentList;
      for (final Expression arg in args.arguments) {
        if (arg is NamedExpression && arg.name.label.name == 'builder') {
          final String builderSource = arg.expression.toSource();
          if (builderSource.contains('File') &&
              (builderSource.contains('Picker') ||
                  builderSource.contains('Selector') ||
                  builderSource.contains('Browser'))) {
            reporter.atNode(node);
          }
        }
      }
    });
  }
}

/// Warns when same InheritedWidget is accessed multiple times in a method.
///
/// Since: v2.1.0 | Updated: v4.13.0 | Rule version: v2
///
/// Multiple .of(context) calls for the same type trigger redundant lookups.
/// Cache the result in a local variable for better performance.
///
/// **BAD:**
/// ```dart
/// Widget build(BuildContext context) {
///   return Column(
///     children: [
///       Text(Theme.of(context).textTheme.bodyLarge),
///       Icon(color: Theme.of(context).colorScheme.primary),
///       Container(color: Theme.of(context).scaffoldBackgroundColor),
///     ],
///   );
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// Widget build(BuildContext context) {
///   final theme = Theme.of(context);
///   return Column(
///     children: [
///       Text(theme.textTheme.bodyLarge),
///       Icon(color: theme.colorScheme.primary),
///       Container(color: theme.scaffoldBackgroundColor),
///     ],
///   );
/// }
/// ```
class PreferInheritedWidgetCacheRule extends SaropaLintRule {
  PreferInheritedWidgetCacheRule() : super(code: _code);

  /// Performance improvement - reduces widget tree lookups.
  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    'prefer_inherited_widget_cache',
    '[prefer_inherited_widget_cache] Multiple .of(context) calls for same type. Cache in local variable. Multiple .of(context) calls for the same type trigger redundant lookups. Cache the result in a local variable to improve performance. {v2}',
    correctionMessage:
        'Extract to: final theme = Theme.of(context); then use theme. Profile the affected code path to confirm the improvement under realistic workloads.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodDeclaration((node) {
      // Only check build methods (most common case)
      if (node.name.lexeme != 'build') {
        return;
      }

      final methodSource = node.toSource();

      // Count .of(context) calls for common types
      final patterns = [
        'Theme.of(context)',
        'MediaQuery.of(context)',
        'Navigator.of(context)',
        'Scaffold.of(context)',
        'DefaultTextStyle.of(context)',
      ];

      for (final pattern in patterns) {
        // Count occurrences
        int count = 0;
        int index = 0;
        while ((index = methodSource.indexOf(pattern, index)) != -1) {
          count++;
          index += pattern.length;
        }

        if (count >= 3) {
          // Report on the method name
          reporter.atNode(node);
          return;
        }
      }
    });
  }
}

/// Warns when MediaQuery.of is used inside ListView item builder.
///
/// Since: v2.1.0 | Updated: v4.13.0 | Rule version: v2
///
/// MediaQuery.of in list item builders causes rebuilds on every scroll.
/// Use LayoutBuilder or pass dimensions from parent for better performance.
///
/// **BAD:**
/// ```dart
/// ListView.builder(
///   itemBuilder: (context, index) {
///     final width = MediaQuery.of(context).size.width;
///     return SizedBox(width: width * 0.8);
///   },
/// );
/// ```
///
/// **GOOD:**
/// ```dart
/// LayoutBuilder(
///   builder: (context, constraints) {
///     return ListView.builder(
///       itemBuilder: (context, index) {
///         return SizedBox(width: constraints.maxWidth * 0.8);
///       },
///     );
///   },
/// );
/// ```
class PreferLayoutBuilderOverMediaQueryRule extends SaropaLintRule {
  PreferLayoutBuilderOverMediaQueryRule() : super(code: _code);

  /// Performance issue in scrolling lists.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'prefer_layout_builder_over_media_query',
    '[prefer_layout_builder_over_media_query] MediaQuery.of in list item builder. Causes unnecessary rebuilds. MediaQuery.of in list item builders causes rebuilds on every scroll. Use LayoutBuilder or pass dimensions from parent to improve performance. {v2}',
    correctionMessage:
        'Use LayoutBuilder above the list or pass dimensions from parent. Profile the affected code path to confirm the improvement under realistic workloads.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((node) {
      // Check for MediaQuery.of
      final target = node.target;
      if (target is! SimpleIdentifier || target.name != 'MediaQuery') {
        return;
      }

      if (node.methodName.name != 'of') {
        return;
      }

      // Check if we're inside a list item builder
      AstNode? current = node.parent;
      bool inItemBuilder = false;

      while (current != null) {
        if (current is NamedExpression) {
          final paramName = current.name.label.name;
          if (paramName == 'itemBuilder' ||
              paramName == 'separatorBuilder' ||
              paramName == 'delegate') {
            inItemBuilder = true;
            break;
          }
        }
        // Stop at method/function boundary
        if (current is MethodDeclaration || current is FunctionDeclaration) {
          break;
        }
        current = current.parent;
      }

      if (inItemBuilder) {
        reporter.atNode(node);
      }
    });
  }
}

// =============================================================================
// NEW RULES v2.3.11
// =============================================================================

/// Warns when database operations are performed on the main UI thread.
///
/// Since: v2.3.11 | Updated: v4.13.0 | Rule version: v2
///
/// Alias: db_ui_thread, blocking_database, database_main_thread
///
/// Database operations like Hive, sqflite, or Isar can block the UI thread
/// causing jank. Use isolates or async properly for large operations.
///
/// **BAD:**
/// ```dart
/// Widget build(BuildContext context) {
///   final users = box.values.toList(); // Blocking in build!
///   return ListView.builder(...);
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// Future<void> initState() {
///   super.initState();
///   _loadUsers();
/// }
///
/// Future<void> _loadUsers() async {
///   final users = await compute(loadUsersFromBox, null);
///   setState(() => _users = users);
/// }
/// ```
class AvoidBlockingDatabaseUiRule extends SaropaLintRule {
  AvoidBlockingDatabaseUiRule() : super(code: _code);

  /// Database ops in build cause UI jank.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.bloc};

  static const LintCode _code = LintCode(
    'avoid_blocking_database_ui',
    '[avoid_blocking_database_ui] Database operation executed in build() or on the main UI thread blocks rendering until the query completes. Users experience frozen screens, unresponsive touch input, and dropped animation frames. Long-running queries can trigger ANR dialogs on Android and watchdog termination on iOS. {v2}',
    correctionMessage:
        'Move database operations to initState(), a FutureBuilder, or StreamBuilder so queries run asynchronously without blocking the UI rendering pipeline.',
    severity: DiagnosticSeverity.WARNING,
  );

  /// Database access patterns to detect.
  static const Set<String> _databaseMethods = <String>{
    'values',
    'keys',
    'toList',
    'toMap',
    'query',
    'rawQuery',
    'getAll',
    'getSync',
    'getAllSync',
    'findSync',
    'findAllSync',
  };

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;
      if (!_databaseMethods.contains(methodName)) return;

      // Check if inside build method
      AstNode? current = node.parent;
      while (current != null) {
        if (current is MethodDeclaration && current.name.lexeme == 'build') {
          reporter.atNode(node);
          return;
        }
        current = current.parent;
      }
    });
  }
}

/// Warns when arithmetic operations are performed on double for money.
///
/// Since: v2.3.11 | Updated: v4.13.0 | Rule version: v3
///
/// Alias: money_double, decimal_money, float_currency
///
/// HEURISTIC: Floating point arithmetic causes rounding errors in money
/// calculations. Use int (cents) or a Decimal/Money package.
///
/// **BAD:**
/// ```dart
/// double total = price * quantity; // 0.1 + 0.2 != 0.3
/// double discount = amount * 0.15; // Rounding errors compound
/// ```
///
/// **GOOD:**
/// ```dart
/// int totalCents = priceCents * quantity;
/// Decimal total = Decimal.parse('10.00') * quantity;
/// ```
class AvoidMoneyArithmeticOnDoubleRule extends SaropaLintRule {
  AvoidMoneyArithmeticOnDoubleRule() : super(code: _code);

  /// Money rounding errors can cause accounting discrepancies.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'avoid_money_arithmetic_on_double',
    '[avoid_money_arithmetic_on_double] Floating point arithmetic on double values introduces rounding errors in financial calculations. For example, 0.1 + 0.2 yields 0.30000000000000004 instead of 0.3. This causes users to see incorrect totals, be charged wrong amounts, and produces accounting discrepancies that compound over multiple transactions and are difficult to trace. {v3}',
    correctionMessage:
        'Use int for cents, Decimal package, or money package for financial calculations.',
    severity: DiagnosticSeverity.WARNING,
  );

  /// Variable names that suggest money values.
  static const Set<String> _moneyPatterns = <String>{
    'price',
    'cost',
    'amount',
    'total',
    'subtotal',
    'tax',
    'discount',
    'balance',
    'payment',
    'fee',
    'rate',
    'salary',
    'wage',
    'revenue',
    'profit',
    'expense',
    'budget',
    'invoice',
  };

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addBinaryExpression((BinaryExpression node) {
      final String op = node.operator.lexeme;
      // Check arithmetic operators
      if (op != '+' && op != '-' && op != '*' && op != '/') return;

      // Check if either operand looks like money
      bool isMoney = false;

      if (node.leftOperand is SimpleIdentifier) {
        final String name = (node.leftOperand as SimpleIdentifier).name
            .toLowerCase();
        isMoney = _moneyPatterns.any((pattern) => name.contains(pattern));
      }

      if (!isMoney && node.rightOperand is SimpleIdentifier) {
        final String name = (node.rightOperand as SimpleIdentifier).name
            .toLowerCase();
        isMoney = _moneyPatterns.any((pattern) => name.contains(pattern));
      }

      if (!isMoney) return;

      // Check if any operand is a double
      final String? leftType = node.leftOperand.staticType?.element?.name;
      final String? rightType = node.rightOperand.staticType?.element?.name;

      if (leftType == 'double' || rightType == 'double') {
        reporter.atNode(node);
      }
    });
  }
}

/// Warns when scroll listeners are registered in build method.
///
/// Since: v2.3.11 | Updated: v4.13.0 | Rule version: v3
///
/// Alias: scroll_listener_build, scroll_handler_build
///
/// Adding scroll listeners in build() causes them to be added multiple
/// times, leading to duplicate callbacks and memory leaks.
///
/// **BAD:**
/// ```dart
/// Widget build(BuildContext context) {
///   _scrollController.addListener(() => print('scrolling'));
///   return ListView(controller: _scrollController);
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// void initState() {
///   super.initState();
///   _scrollController.addListener(_onScroll);
/// }
///
/// void dispose() {
///   _scrollController.removeListener(_onScroll);
///   super.dispose();
/// }
/// ```
class AvoidRebuildOnScrollRule extends SaropaLintRule {
  AvoidRebuildOnScrollRule() : super(code: _code);

  /// Listeners added in build leak and duplicate on every rebuild.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'avoid_rebuild_on_scroll',
    '[avoid_rebuild_on_scroll] Scroll listener registered inside build() is re-added on every widget rebuild without removing the previous one. Duplicate listeners accumulate over time, firing multiple callbacks per scroll event, causing memory leaks, compounding performance degradation, and eventually crashes from excessive callback execution. {v3}',
    correctionMessage:
        'Register the scroll listener once in initState() and remove it in dispose() to prevent listener accumulation and ensure proper cleanup on widget destruction.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name != 'addListener') return;

      // Check if target is a scroll-related controller
      final Expression? target = node.target;
      if (target == null) return;

      final String targetSource = target.toSource().toLowerCase();
      if (!targetSource.contains('scroll') &&
          !targetSource.contains('controller')) {
        return;
      }

      // Check if inside build method
      AstNode? current = node.parent;
      while (current != null) {
        if (current is MethodDeclaration && current.name.lexeme == 'build') {
          reporter.atNode(node);
          return;
        }
        current = current.parent;
      }
    });
  }
}

// =============================================================================
// avoid_animation_in_large_list
// =============================================================================

/// Warns when animations are used inside list item builders.
///
/// Since: v4.2.0 | Updated: v4.13.0 | Rule version: v2
///
/// Alias: list_item_animation, listview_animation
///
/// Animations inside ListView.builder cause performance issues because
/// they run even for off-screen items and can cause jank during scrolling.
///
/// **BAD:**
/// ```dart
/// ListView.builder(
///   itemCount: 1000,
///   itemBuilder: (context, index) {
///     return FadeInAnimation( // 1000 animations!
///       child: ListTile(title: Text(items[index].name)),
///     );
///   },
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// // Option 1: Use AnimatedList for add/remove animations
/// AnimatedList(
///   itemBuilder: (context, index, animation) {
///     return SizeTransition(
///       sizeFactor: animation,
///       child: ListTile(title: Text(items[index].name)),
///     );
///   },
/// )
///
/// // Option 2: Animate only visible items
/// ListView.builder(
///   itemBuilder: (context, index) {
///     return VisibilityDetector(
///       onVisibilityChanged: (info) {
///         if (info.visibleFraction > 0.5) startAnimation();
///       },
///       child: ListTile(...),
///     );
///   },
/// )
/// ```
class AvoidAnimationInLargeListRule extends SaropaLintRule {
  AvoidAnimationInLargeListRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    'avoid_animation_in_large_list',
    '[avoid_animation_in_large_list] Animation widget inside ListView builder. '
        'All items run animations even when off-screen, causing performance issues. {v2}',
    correctionMessage:
        'Use AnimatedList for enter/exit animations, or animate only visible items.',
    severity: DiagnosticSeverity.WARNING,
  );

  static const Set<String> _animationWidgets = <String>{
    'AnimatedContainer',
    'AnimatedOpacity',
    'AnimatedPositioned',
    'AnimatedPadding',
    'AnimatedAlign',
    'AnimatedScale',
    'AnimatedRotation',
    'AnimatedSlide',
    'FadeTransition',
    'ScaleTransition',
    'SlideTransition',
    'RotationTransition',
    'TweenAnimationBuilder',
    'Lottie',
    'Hero',
  };

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      // Check if this is ListView.builder or similar
      final Expression? target = node.target;
      if (target is! SimpleIdentifier) return;

      final String targetName = target.name;
      if (targetName != 'ListView' &&
          targetName != 'GridView' &&
          targetName != 'CustomScrollView') {
        return;
      }

      final String methodName = node.methodName.name;
      if (methodName != 'builder' && methodName != 'separated') return;

      // Check itemBuilder for animation widgets
      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression) {
          final String paramName = arg.name.label.name;
          if (paramName == 'itemBuilder') {
            final String builderSource = arg.expression.toSource();

            for (final String animWidget in _animationWidgets) {
              if (builderSource.contains(animWidget)) {
                reporter.atNode(node);
                return;
              }
            }
          }
        }
      }
    });
  }
}

// =============================================================================
// prefer_lazy_loading_images
// =============================================================================

/// Warns when images are loaded without lazy loading in scrollable views.
///
/// Since: v4.2.0 | Updated: v4.13.0 | Rule version: v2
///
/// Alias: lazy_load_images, image_preload
///
/// Loading all images immediately in a scrollable list wastes bandwidth and
/// memory. Use lazy loading to fetch images only when they become visible.
///
/// **BAD:**
/// ```dart
/// ListView.builder(
///   itemBuilder: (context, index) {
///     return Image.network(imageUrls[index]); // Loads all images immediately
///   },
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// ListView.builder(
///   itemBuilder: (context, index) {
///     return CachedNetworkImage(
///       imageUrl: imageUrls[index],
///       placeholder: (context, url) => CircularProgressIndicator(),
///       errorWidget: (context, url, error) => Icon(Icons.error),
///     );
///   },
/// )
///
/// // Or use FadeInImage for built-in placeholder support
/// FadeInImage.memoryNetwork(
///   placeholder: kTransparentImage,
///   image: imageUrls[index],
/// )
/// ```
class PreferLazyLoadingImagesRule extends SaropaLintRule {
  PreferLazyLoadingImagesRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    'prefer_lazy_loading_images',
    '[prefer_lazy_loading_images] Image.network in ListView builder without '
        'lazy loading. All images load immediately, wasting bandwidth and memory. {v2}',
    correctionMessage:
        'Use CachedNetworkImage or FadeInImage for lazy loading with placeholders.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      // Check for Image.network inside itemBuilder
      if (node.methodName.name != 'network') return;

      final Expression? target = node.target;
      if (target is! SimpleIdentifier || target.name != 'Image') return;

      // Check if inside an itemBuilder
      bool isInsideBuilder = false;
      AstNode? current = node.parent;

      while (current != null) {
        if (current is NamedExpression) {
          final String paramName = current.name.label.name;
          if (paramName == 'itemBuilder' ||
              paramName == 'builder' ||
              paramName == 'separatorBuilder') {
            isInsideBuilder = true;
            break;
          }
        }
        if (current is FunctionDeclaration || current is MethodDeclaration) {
          break;
        }
        current = current.parent;
      }

      if (isInsideBuilder) {
        reporter.atNode(node);
      }
    });
  }
}

// =============================================================================
// Performance Best Practices (from v4.1.7)
// =============================================================================

/// Warns when widget types change conditionally, destroying Elements.
///
/// Since: v4.1.8 | Updated: v4.13.0 | Rule version: v2
///
/// Returning the same widget type with same key reuses Elements. Changing
/// widget types or keys destroys Elements, losing state and causing expensive
/// rebuilds.
///
/// **BAD:**
/// ```dart
/// Widget build(BuildContext context) {
///   if (isLoading) {
///     return CircularProgressIndicator(); // Type A
///   }
///   return MyContent(); // Type B - Element destroyed on toggle!
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// Widget build(BuildContext context) {
///   return Stack(children: [
///     MyContent(),
///     if (isLoading) CircularProgressIndicator(),
///   ]);
/// }
/// ```
class PreferElementRebuildRule extends SaropaLintRule {
  PreferElementRebuildRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    'prefer_element_rebuild',
    '[prefer_element_rebuild] Conditional return of different widget types destroys Elements. Returning the same widget type with same key reuses Elements. Changing widget types or keys destroys Elements, losing state and causing expensive rebuilds. {v2}',
    correctionMessage:
        'Use Stack, Visibility, or AnimatedSwitcher to preserve Element state. Profile the affected code path to confirm the improvement under realistic workloads.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodDeclaration((MethodDeclaration node) {
      if (node.name.lexeme != 'build') return;

      final FunctionBody? body = node.body;
      if (body == null) return;

      // Collect all return statements in the build method
      final List<ReturnStatement> returns = <ReturnStatement>[];
      _collectReturnStatementsForElement(body, returns);

      if (returns.length < 2) return;

      // Check if returns are in different branches of conditionals
      final Set<String> returnTypes = <String>{};
      for (final ReturnStatement ret in returns) {
        final Expression? expr = ret.expression;
        if (expr is InstanceCreationExpression) {
          returnTypes.add(expr.constructorName.type.name2.lexeme);
        } else if (expr is MethodInvocation) {
          returnTypes.add(expr.methodName.name);
        }
      }

      // If different widget types are returned, warn
      if (returnTypes.length > 1) {
        reporter.atNode(node);
      }
    });
  }

  void _collectReturnStatementsForElement(
    AstNode node,
    List<ReturnStatement> returns,
  ) {
    if (node is ReturnStatement) {
      returns.add(node);
    }
    for (final AstNode child in node.childEntities.whereType<AstNode>()) {
      _collectReturnStatementsForElement(child, returns);
    }
  }
}

/// Warns when heavy computation is done on the main isolate.
///
/// Since: v4.1.8 | Updated: v4.13.0 | Rule version: v2
///
/// Heavy computation on main isolate blocks UI (16ms budget per frame).
/// Use `compute()` or `Isolate.run()` for JSON parsing, image processing,
/// or data transforms.
///
/// **BAD:**
/// ```dart
/// Future<List<User>> parseUsers(String json) async {
///   return jsonDecode(json); // Blocks main thread for large JSON!
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// Future<List<User>> parseUsers(String json) async {
///   return compute(_parseJson, json);
/// }
///
/// List<User> _parseJson(String json) => jsonDecode(json);
/// ```
class RequireIsolateForHeavyRule extends SaropaLintRule {
  RequireIsolateForHeavyRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'require_isolate_for_heavy',
    '[require_isolate_for_heavy] Heavy computation such as JSON decoding, image processing, or data parsing runs on the main thread, blocking the UI event loop. This prevents frame rendering, freezes animations, and makes the app unresponsive to user input. On lower-end devices, operations exceeding 16ms per frame cause visible stutter and dropped frames that degrade the user experience. {v2}',
    correctionMessage:
        'Use compute(_parse, data) or Isolate.run(() => _parse(data)) to run in background.',
    severity: DiagnosticSeverity.WARNING,
  );

  static const Set<String> _heavyOperations = {
    'jsonDecode',
    'jsonEncode',
    'parse', // Often heavy for large data
    'decompress',
    'compress',
    'encrypt',
    'decrypt',
    'hash',
  };

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;
      if (!_heavyOperations.contains(methodName)) return;

      // Check if already inside compute() or Isolate.run()
      if (isInsideIsolate(node)) return;

      // Check if in async context (likely handling network response)
      if (isInAsyncContext(node)) {
        reporter.atNode(node);
      }
    });
  }
}

/// Warns when Dart Finalizers are misused.
///
/// Since: v4.1.8 | Updated: v4.13.0 | Rule version: v2
///
/// Dart Finalizers run non-deterministically and add GC overhead.
/// Prefer explicit dispose() methods. Finalizers are only for native
/// resource cleanup as a safety net.
///
/// **BAD:**
/// ```dart
/// class MyResource {
///   static final Finalizer<MyResource> _finalizer =
///       Finalizer((r) => r._cleanup());
///
///   MyResource() {
///     _finalizer.attach(this, this);
///   }
///
///   void _cleanup() => print('Cleaned up'); // Non-deterministic!
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// class MyResource {
///   void dispose() {
///     _cleanup(); // Explicit, deterministic
///   }
/// }
/// ```
class AvoidFinalizerMisuseRule extends SaropaLintRule {
  AvoidFinalizerMisuseRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'avoid_finalizer_misuse',
    '[avoid_finalizer_misuse] Finalizer used for non-native resources. Prefer explicit dispose(). Dart Finalizers run non-deterministically and add GC overhead. Prefer explicit dispose() methods. Finalizers are only for native resource cleanup as a safety net. {v2}',
    correctionMessage:
        'Use dispose() pattern for deterministic cleanup. Finalizers are only for native FFI resources.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addFieldDeclaration((FieldDeclaration node) {
      for (final VariableDeclaration variable in node.fields.variables) {
        final Expression? initializer = variable.initializer;
        if (initializer == null) continue;

        final String initSource = initializer.toSource();
        if (initSource.contains('Finalizer<') ||
            initSource.contains('Finalizer(')) {
          // Check if this class also has dispose() - if so, it's OK
          final ClassDeclaration? classDecl = _findParentClassForFinalizer(
            node,
          );
          if (classDecl != null && !_hasDisposeMethodForFinalizer(classDecl)) {
            reporter.atNode(variable);
          }
        }
      }
    });
  }

  ClassDeclaration? _findParentClassForFinalizer(AstNode node) {
    AstNode? current = node.parent;
    while (current != null) {
      if (current is ClassDeclaration) return current;
      current = current.parent;
    }
    return null;
  }

  bool _hasDisposeMethodForFinalizer(ClassDeclaration classDecl) {
    for (final ClassMember member in classDecl.members) {
      if (member is MethodDeclaration && member.name.lexeme == 'dispose') {
        return true;
      }
    }
    return false;
  }
}

/// Warns when jsonDecode is called on main thread without isolate.
///
/// Since: v4.1.8 | Updated: v4.13.0 | Rule version: v2
///
/// `[HEURISTIC]` - Detects jsonDecode without compute/isolate wrapper.
///
/// `jsonDecode()` for large payloads (>100KB) blocks the main thread.
/// Use `compute()` to parse JSON in a background isolate.
///
/// **BAD:**
/// ```dart
/// Future<List<Item>> fetchItems() async {
///   final response = await http.get(url);
///   return jsonDecode(response.body); // Blocks UI!
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// Future<List<Item>> fetchItems() async {
///   final response = await http.get(url);
///   return compute(jsonDecode, response.body);
/// }
/// ```
class AvoidJsonInMainRule extends SaropaLintRule {
  AvoidJsonInMainRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'avoid_json_in_main',
    '[avoid_json_in_main] jsonDecode on main thread blocks UI for large payloads (100KB+). jsonDecode() for large payloads (>100KB) blocks the main thread. Use compute() to parse JSON in a background isolate. {v2}',
    correctionMessage:
        'Use compute(jsonDecode, data) or Isolate.run(() => jsonDecode(data)). Profile the affected code path to confirm the improvement under realistic workloads.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name != 'jsonDecode') return;

      // Check if already inside compute() or Isolate.run()
      if (isInsideIsolate(node)) return;

      // Check if in async context (likely handling network response)
      if (isInAsyncContext(node)) {
        reporter.atNode(node);
      }
    });
  }
}

/// Warns when synchronous I/O methods are called on the main isolate.
///
/// Since: v4.14.0 | Rule version: v1
///
/// `[HEURISTIC]` - Detects `*Sync()` method calls outside compute/Isolate.run.
///
/// Synchronous I/O (readAsStringSync, writeAsStringSync, etc.) blocks the main
/// isolate, freezing the UI and causing jank or ANR errors on mobile platforms.
///
/// **BAD:**
/// ```dart
/// void loadConfig() {
///   final content = File('config.json').readAsStringSync(); // Blocks UI!
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// Future<void> loadConfig() async {
///   final content = await File('config.json').readAsString();
/// }
/// ```
///
/// GitHub: https://github.com/saropa/saropa_lints/issues/17
class AvoidBlockingMainThreadRule extends SaropaLintRule {
  AvoidBlockingMainThreadRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'avoid_blocking_main_thread',
    '[avoid_blocking_main_thread] Synchronous I/O blocks the main isolate, '
        'freezing the UI and causing jank or ANR (Application Not Responding) '
        'errors on mobile platforms. Even brief blocking degrades perceived '
        'performance and user experience significantly. {v1}',
    correctionMessage:
        'Use the async equivalent (e.g., readAsString instead of '
        'readAsStringSync) or offload heavy work to an isolate with '
        'compute() or Isolate.run().',
    severity: DiagnosticSeverity.WARNING,
  );

  /// Synchronous I/O methods that block the main thread.
  static const Set<String> _syncMethods = <String>{
    'readAsStringSync',
    'readAsBytesSync',
    'readAsLinesSync',
    'writeAsStringSync',
    'writeAsBytesSync',
    'createSync',
    'deleteSync',
    'existsSync',
    'copySync',
    'renameSync',
    'listSync',
    'createTempSync',
    'mkdirSync',
    'statSync',
    'resolveSymbolicLinksSync',
    'openSync',
  };

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      if (!_syncMethods.contains(node.methodName.name)) return;

      // Skip if inside compute() or Isolate.run()
      if (isInsideIsolate(node)) return;

      reporter.atNode(node);
    });
  }
}

// =============================================================================
// avoid_full_sync_on_every_launch
// =============================================================================

/// Warns when bulk data fetching is performed inside initState.
///
/// Since: v4.15.0 | Rule version: v1
///
/// Downloading an entire dataset on every app launch is slow, expensive,
/// and wastes bandwidth. Use delta sync with timestamps or change feeds
/// instead. Move bulk fetches to a background sync mechanism that only
/// downloads what has changed since the last sync.
///
/// **BAD:**
/// ```dart
/// @override
/// void initState() {
///   super.initState();
///   database.getAll(); // Fetches everything on every launch
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// @override
/// void initState() {
///   super.initState();
///   syncService.syncSince(lastSyncTimestamp); // Delta sync
/// }
/// ```
class AvoidFullSyncOnEveryLaunchRule extends SaropaLintRule {
  AvoidFullSyncOnEveryLaunchRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    'avoid_full_sync_on_every_launch',
    '[avoid_full_sync_on_every_launch] Bulk data fetch detected in '
        'initState. Downloading the entire dataset on every launch is slow '
        'and wastes bandwidth. This causes unnecessary network traffic and '
        'increases startup time, especially on slow connections. Use delta '
        'sync with timestamps or change feeds to only fetch what changed '
        'since the last sync. {v1}',
    correctionMessage:
        'Replace bulk fetch with delta sync using timestamps or change feeds.',
    severity: DiagnosticSeverity.WARNING,
  );

  /// Method names that suggest bulk data fetching.
  static const Set<String> _bulkFetchMethods = <String>{
    'getAll',
    'fetchAll',
    'findAll',
    'listAll',
    'queryAll',
    'loadAll',
    'readAll',
    'syncAll',
    'downloadAll',
    'getAllDocuments',
    'getAllRecords',
    'getAllItems',
    'getAllUsers',
  };

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodDeclaration((MethodDeclaration node) {
      // Only check initState methods
      if (node.name.lexeme != 'initState') return;

      // Visit the body for bulk fetch calls
      final FunctionBody body = node.body;
      if (body is! BlockFunctionBody) return;

      _checkForBulkFetch(body.block, reporter);
    });
  }

  void _checkForBulkFetch(Block block, SaropaDiagnosticReporter reporter) {
    for (final Statement stmt in block.statements) {
      _visitForBulkFetch(stmt, reporter);
    }
  }

  void _visitForBulkFetch(AstNode node, SaropaDiagnosticReporter reporter) {
    if (node is MethodInvocation) {
      final String name = node.methodName.name;
      if (_bulkFetchMethods.contains(name)) {
        reporter.atNode(node);
        return;
      }
    }

    for (final AstNode child in node.childEntities.whereType<AstNode>()) {
      // Don't descend into nested function declarations
      if (child is FunctionExpression || child is FunctionDeclaration) continue;
      _visitForBulkFetch(child, reporter);
    }
  }
}
