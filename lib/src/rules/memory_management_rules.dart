// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

/// Memory management lint rules for Flutter/Dart applications.
///
/// These rules help identify memory leaks, excessive memory usage,
/// and improper resource management that can degrade app performance.
library;

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/error.dart' show DiagnosticSeverity;
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

/// Warns when large objects are stored in widget state.
///
/// Large data structures in State classes can cause memory issues,
/// especially if they're not properly cleaned up. Consider using
/// external state management or streaming data instead.
///
/// **BAD:**
/// ```dart
/// class _MyWidgetState extends State<MyWidget> {
///   List<LargeDataModel> allItems = []; // May grow unbounded
///   Map<String, Uint8List> imageCache = {}; // Large binary data
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// class _MyWidgetState extends State<MyWidget> {
///   // Use pagination or streaming
///   late final ScrollController _controller;
///   // Or use external cache with LRU eviction
/// }
/// ```
class AvoidLargeObjectsInStateRule extends DartLintRule {
  const AvoidLargeObjectsInStateRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_large_objects_in_state',
    problemMessage: 'Large data structures in State may cause memory issues.',
    correctionMessage: 'Consider pagination, streaming, or external state management.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  static const Set<String> _largeTypePatterns = <String>{
    'List<',
    'Map<',
    'Set<',
    'Uint8List',
    'ByteData',
    'ByteBuffer',
  };

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
      // Check if this is a State class
      final ExtendsClause? extendsClause = node.extendsClause;
      if (extendsClause == null) return;

      final String superName = extendsClause.superclass.toSource();
      if (!superName.startsWith('State<')) return;

      // Check fields for large collection types
      for (final ClassMember member in node.members) {
        if (member is FieldDeclaration) {
          final TypeAnnotation? type = member.fields.type;
          if (type == null) continue;

          final String typeSource = type.toSource();
          for (final String pattern in _largeTypePatterns) {
            if (typeSource.contains(pattern)) {
              // Check if it's unbounded (no clear size limit)
              final String fieldSource = member.toSource();
              if (!fieldSource.contains('// bounded') &&
                  !fieldSource.contains('maxSize') &&
                  !fieldSource.contains('limit')) {
                reporter.atNode(member, code);
                break;
              }
            }
          }
        }
      }
    });
  }
}

/// Warns when image memory is not properly managed.
///
/// Images consume significant memory. Without proper lifecycle management,
/// they can cause out-of-memory errors, especially on lower-end devices.
///
/// **BAD:**
/// ```dart
/// class _GalleryState extends State<Gallery> {
///   final List<ui.Image> loadedImages = []; // Never disposed
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// class _GalleryState extends State<Gallery> {
///   final List<ui.Image> loadedImages = [];
///
///   @override
///   void dispose() {
///     for (final image in loadedImages) {
///       image.dispose();
///     }
///     super.dispose();
///   }
/// }
/// ```
class RequireImageDisposalRule extends DartLintRule {
  const RequireImageDisposalRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'require_image_disposal',
    problemMessage: 'ui.Image objects must be disposed to free memory.',
    correctionMessage: 'Call image.dispose() in the dispose() method.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
      // Check if this is a State class
      final ExtendsClause? extendsClause = node.extendsClause;
      if (extendsClause == null) return;

      final String superName = extendsClause.superclass.toSource();
      if (!superName.startsWith('State<')) return;

      // Find ui.Image fields
      bool hasUiImageField = false;
      bool hasDisposeCall = false;

      for (final ClassMember member in node.members) {
        if (member is FieldDeclaration) {
          final String fieldSource = member.toSource();
          if (fieldSource.contains('ui.Image') ||
              fieldSource.contains('Image ') && fieldSource.contains('dart:ui')) {
            hasUiImageField = true;
          }
        }

        if (member is MethodDeclaration && member.name.lexeme == 'dispose') {
          final String disposeSource = member.body.toSource();
          if (disposeSource.contains('.dispose()')) {
            hasDisposeCall = true;
          }
        }
      }

      if (hasUiImageField && !hasDisposeCall) {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when closures capture more context than needed.
///
/// Closures that capture `this` or large objects can prevent garbage
/// collection and cause memory leaks, especially in long-lived callbacks.
///
/// **BAD:**
/// ```dart
/// class _MyWidgetState extends State<MyWidget> {
///   late Timer _timer;
///
///   void initState() {
///     super.initState();
///     _timer = Timer.periodic(Duration(seconds: 1), (_) {
///       setState(() {}); // Captures entire State object
///     });
///   }
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// class _MyWidgetState extends State<MyWidget> {
///   late Timer _timer;
///
///   void initState() {
///     super.initState();
///     _timer = Timer.periodic(Duration(seconds: 1), _onTick);
///   }
///
///   void _onTick(Timer timer) {
///     if (mounted) setState(() {});
///   }
///
///   void dispose() {
///     _timer.cancel();
///     super.dispose();
///   }
/// }
/// ```
class AvoidCapturingThisInCallbacksRule extends DartLintRule {
  const AvoidCapturingThisInCallbacksRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_capturing_this_in_callbacks',
    problemMessage: 'Callback may capture entire object, preventing garbage collection.',
    correctionMessage: 'Use method reference or extract only needed values.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  static const Set<String> _longLivedCallbacks = <String>{
    'Timer.periodic',
    'Stream.listen',
    'addListener',
    'addPostFrameCallback',
    'Future.delayed',
  };

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      final String fullCall = node.toSource();

      bool isLongLivedCallback = false;
      for (final String pattern in _longLivedCallbacks) {
        if (fullCall.contains(pattern)) {
          isLongLivedCallback = true;
          break;
        }
      }

      if (!isLongLivedCallback) return;

      // Check if any argument is an inline function that uses setState or this
      for (final Expression arg in node.argumentList.arguments) {
        if (arg is FunctionExpression) {
          final String funcSource = arg.toSource();
          if (funcSource.contains('setState') ||
              funcSource.contains('this.') ||
              funcSource.contains('widget.')) {
            reporter.atNode(arg, code);
            return;
          }
        }
      }
    });
  }
}

/// Warns when caches lack eviction policies.
///
/// Unbounded caches grow indefinitely and cause out-of-memory errors.
/// Always implement eviction (LRU, TTL, max size) for caches.
///
/// **BAD:**
/// ```dart
/// class ImageCache {
///   final Map<String, Uint8List> _cache = {}; // Grows forever
///
///   void add(String key, Uint8List data) {
///     _cache[key] = data;
///   }
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// class ImageCache {
///   final _cache = LinkedHashMap<String, Uint8List>();
///   static const int _maxSize = 100;
///
///   void add(String key, Uint8List data) {
///     if (_cache.length >= _maxSize) {
///       _cache.remove(_cache.keys.first); // LRU eviction
///     }
///     _cache[key] = data;
///   }
/// }
/// ```
class RequireCacheEvictionPolicyRule extends DartLintRule {
  const RequireCacheEvictionPolicyRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'require_cache_eviction_policy',
    problemMessage: 'Cache lacks eviction policy and may grow unbounded.',
    correctionMessage: 'Implement LRU eviction, TTL, or max size limit.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
      final String className = node.name.lexeme.toLowerCase();

      // Only check classes that appear to be caches
      if (!className.contains('cache') && !className.contains('pool')) {
        return;
      }

      final String classSource = node.toSource();

      // Check for eviction patterns
      final bool hasEviction = classSource.contains('remove(') ||
          classSource.contains('clear(') ||
          classSource.contains('maxSize') ||
          classSource.contains('_maxSize') ||
          classSource.contains('maxEntries') ||
          classSource.contains('maxAge') ||
          classSource.contains('ttl') ||
          classSource.contains('expire') ||
          classSource.contains('evict') ||
          classSource.contains('lru') ||
          classSource.contains('LRU');

      if (!hasEviction) {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when WeakReference should be used for cached references.
///
/// Strong references to large objects prevent garbage collection.
/// Use WeakReference for caches that should yield to memory pressure.
///
/// **BAD:**
/// ```dart
/// class WidgetCache {
///   final Map<String, Widget> _widgets = {}; // Strong references
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// class WidgetCache {
///   final Map<String, WeakReference<Widget>> _widgets = {};
///
///   Widget? get(String key) => _widgets[key]?.target;
/// }
/// ```
class PreferWeakReferencesForCacheRule extends DartLintRule {
  const PreferWeakReferencesForCacheRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'prefer_weak_references_for_cache',
    problemMessage: 'Consider using WeakReference for cache entries.',
    correctionMessage: 'WeakReference allows garbage collection under memory pressure.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
      final String className = node.name.lexeme.toLowerCase();

      // Only check classes that appear to be caches
      if (!className.contains('cache')) return;

      // Check for Map fields without WeakReference
      for (final ClassMember member in node.members) {
        if (member is FieldDeclaration) {
          final TypeAnnotation? type = member.fields.type;
          if (type == null) continue;

          final String typeSource = type.toSource();

          // Check for Map that doesn't use WeakReference
          if (typeSource.contains('Map<') && !typeSource.contains('WeakReference')) {
            reporter.atNode(member, code);
          }
        }
      }
    });
  }
}

/// Warns when Expando is used without understanding its memory implications.
///
/// Expando keeps weak references to keys but strong references to values.
/// This can cause memory leaks if values reference keys.
///
/// **BAD:**
/// ```dart
/// final _metadata = Expando<Map<String, dynamic>>();
///
/// void attachMetadata(Widget widget) {
///   _metadata[widget] = {
///     'widget': widget, // Circular reference!
///   };
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// final _metadata = Expando<WidgetMetadata>();
///
/// void attachMetadata(Widget widget) {
///   _metadata[widget] = WidgetMetadata(
///     createdAt: DateTime.now(),
///   ); // No reference back to widget
/// }
/// ```
class AvoidExpandoCircularReferencesRule extends DartLintRule {
  const AvoidExpandoCircularReferencesRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_expando_circular_references',
    problemMessage: 'Expando value may reference its key, causing memory leak.',
    correctionMessage: 'Ensure Expando values do not hold references to their keys.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addIndexExpression((IndexExpression node) {
      // Check for Expando assignment pattern: expando[key] = value
      final Expression? target = node.target;
      if (target == null) return;

      // Check if target is likely an Expando
      final String targetSource = target.toSource().toLowerCase();
      if (!targetSource.contains('expando') && !targetSource.contains('_meta')) {
        return;
      }

      // Check if this is an assignment
      final AstNode? parent = node.parent;
      if (parent is! AssignmentExpression) return;

      final Expression rightSide = parent.rightHandSide;
      final String valueSource = rightSide.toSource();
      final String keySource = node.index.toSource();

      // Check if value contains reference to key
      if (valueSource.contains(keySource)) {
        reporter.atNode(parent, code);
      }
    });
  }
}

/// Warns when isolate communication sends large objects.
///
/// Sending large objects between isolates requires copying, which is
/// expensive. Use SendPort with TransferableTypedData for large data.
///
/// **BAD:**
/// ```dart
/// await compute(processData, largeList); // Copies entire list
/// isolatePort.send(hugeByteArray); // Expensive copy
/// ```
///
/// **GOOD:**
/// ```dart
/// // Use TransferableTypedData for byte arrays
/// final transferable = TransferableTypedData.fromList([bytes]);
/// isolatePort.send(transferable);
///
/// // Or process in chunks
/// for (final chunk in largeList.chunked(1000)) {
///   await compute(processChunk, chunk);
/// }
/// ```
class AvoidLargeIsolateCommunicationRule extends DartLintRule {
  const AvoidLargeIsolateCommunicationRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_large_isolate_communication',
    problemMessage: 'Sending large objects between isolates is expensive.',
    correctionMessage: 'Use TransferableTypedData or process data in chunks.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;

      // Check for compute() calls
      if (methodName == 'compute') {
        final NodeList<Expression> args = node.argumentList.arguments;
        if (args.length >= 2) {
          final String argSource = args[1].toSource().toLowerCase();

          // Check if passing large collections
          if (argSource.contains('list') ||
              argSource.contains('map') ||
              argSource.contains('set') ||
              argSource.contains('bytes') ||
              argSource.contains('data')) {
            reporter.atNode(node, code);
          }
        }
      }

      // Check for SendPort.send() calls
      if (methodName == 'send') {
        final Expression? target = node.target;
        if (target != null) {
          final String targetSource = target.toSource().toLowerCase();
          if (targetSource.contains('port') || targetSource.contains('sendport')) {
            final NodeList<Expression> args = node.argumentList.arguments;
            if (args.isNotEmpty) {
              final String argSource = args.first.toSource().toLowerCase();
              if (argSource.contains('list') ||
                  argSource.contains('bytes') ||
                  argSource.contains('data')) {
                reporter.atNode(node, code);
              }
            }
          }
        }
      }
    });
  }
}
