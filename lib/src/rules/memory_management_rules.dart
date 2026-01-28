// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

/// Memory management lint rules for Flutter/Dart applications.
///
/// These rules help identify memory leaks, excessive memory usage,
/// and improper resource management that can degrade app performance.
library;

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/error.dart'
    show AnalysisError, DiagnosticSeverity;
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../saropa_lint_rule.dart';

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
class AvoidLargeObjectsInStateRule extends SaropaLintRule {
  const AvoidLargeObjectsInStateRule() : super(code: _code);

  /// Large unbounded data in state can cause OOM errors.
  /// Review for potential memory issues.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_large_objects_in_state',
    problemMessage:
        '[avoid_large_objects_in_state] Unbounded List, Map, Set, or ByteData field declared in a State class grows without limit as data accumulates. Without pagination or size constraints, this allocates excessive memory that degrades scroll performance, increases garbage collection pressure, and eventually crashes the app with an out-of-memory error on devices with limited RAM.',
    correctionMessage:
        'Use pagination to load data in fixed-size chunks, stream results lazily from the data source, or move large collections to external state management with disposal and lifecycle control.',
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
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
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
class RequireImageDisposalRule extends SaropaLintRule {
  const RequireImageDisposalRule() : super(code: _code);

  /// Undisposed images leak native memory and cause OOM crashes.
  /// Each occurrence is a memory leak.
  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'require_image_disposal',
    problemMessage:
        'Failing to dispose of images or image streams can lead to memory leaks, increased memory usage, and eventual app crashes, especially in image-heavy applications. This is critical for apps that load or manipulate images dynamically. See https://docs.flutter.dev/perf/memory#images.',
    correctionMessage:
        'Dispose of images and image streams when they are no longer needed to free memory and maintain app performance. See https://docs.flutter.dev/perf/memory#images for best practices.',
    errorSeverity: DiagnosticSeverity.WARNING,
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

      final String superName = extendsClause.superclass.toSource();
      if (!superName.startsWith('State<')) return;

      // Find ui.Image fields
      bool hasUiImageField = false;
      bool hasDisposeCall = false;

      for (final ClassMember member in node.members) {
        if (member is FieldDeclaration) {
          final String fieldSource = member.toSource();
          if (fieldSource.contains('ui.Image') ||
              fieldSource.contains('Image ') &&
                  fieldSource.contains('dart:ui')) {
            hasUiImageField = true;
          }
        }

        if (member is MethodDeclaration && member.name.lexeme == 'dispose') {
          final String disposeSource = member.body.toSource();
          // Check for dispose (including *Safe extension variants)
          if (disposeSource.contains('.dispose()') ||
              disposeSource.contains('.disposeSafe(')) {
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
class AvoidCapturingThisInCallbacksRule extends SaropaLintRule {
  const AvoidCapturingThisInCallbacksRule() : super(code: _code);

  /// Captured references prevent garbage collection and leak memory.
  /// Review long-lived callbacks for proper lifecycle management.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'avoid_capturing_this_in_callbacks',
    problemMessage:
        '[avoid_capturing_this_in_callbacks] Closure callback captures a reference to the entire enclosing object instance via implicit this. This prevents garbage collection of the object and all its fields for as long as the callback exists. Long-lived callbacks such as stream listeners, timers, or global event handlers create memory leaks that accumulate over the app session lifetime.',
    correctionMessage:
        'Extract only the specific values needed into local variables before the closure, or use a static method reference that does not capture the enclosing object instance.',
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
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
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
class RequireCacheEvictionPolicyRule extends SaropaLintRule {
  const RequireCacheEvictionPolicyRule() : super(code: _code);

  /// Unbounded caches grow indefinitely and cause OOM errors.
  /// Each occurrence is a potential memory leak.
  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'require_cache_eviction_policy',
    problemMessage:
        '[require_cache_eviction_policy] Unbounded cache consumes memory until '
        'app crashes with OutOfMemoryError after extended use.',
    correctionMessage: 'Implement LRU eviction, TTL, or max size limit.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
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
class PreferWeakReferencesForCacheRule extends SaropaLintRule {
  const PreferWeakReferencesForCacheRule() : super(code: _code);

  /// Strong references in caches prevent GC under memory pressure.
  /// Consider for memory-sensitive applications.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'prefer_weak_references_for_cache',
    problemMessage:
        '[prefer_weak_references_for_cache] Strong cache references prevent garbage collection under memory pressure.',
    correctionMessage:
        'WeakReference allows garbage collection under memory pressure.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
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
          if (typeSource.contains('Map<') &&
              !typeSource.contains('WeakReference')) {
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
class AvoidExpandoCircularReferencesRule extends SaropaLintRule {
  const AvoidExpandoCircularReferencesRule() : super(code: _code);

  /// Circular references in Expando prevent garbage collection.
  /// Each occurrence is a memory leak.
  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_expando_circular_references',
    problemMessage:
        '[avoid_expando_circular_references] Creating a circular reference by storing a reference to an Expando key inside its own value prevents Dart’s garbage collector from reclaiming memory, resulting in memory leaks. This subtle bug can cause your app’s memory usage to grow over time, degrade performance, and eventually lead to crashes or out-of-memory errors, especially in long-running or data-intensive applications. Such leaks are difficult to detect and debug, making it critical to avoid circular references when using Expando for metadata or caching.',
    correctionMessage:
        'Never store a reference to the Expando key (such as an object or identifier) inside the value associated with that key. Refactor your code to ensure Expando values do not reference their own keys, breaking any potential cycles. Regularly review and test code that uses Expando for memory safety, and use memory profiling tools to detect leaks in production.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addIndexExpression((IndexExpression node) {
      // Check for Expando assignment pattern: expando[key] = value
      final Expression? target = node.target;
      if (target == null) return;

      // Check if target is likely an Expando
      final String targetSource = target.toSource().toLowerCase();
      if (!targetSource.contains('expando') &&
          !targetSource.contains('_meta')) {
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
class AvoidLargeIsolateCommunicationRule extends SaropaLintRule {
  const AvoidLargeIsolateCommunicationRule() : super(code: _code);

  /// Large isolate copies cause temporary memory spikes.
  /// Performance issue, not a memory leak.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'avoid_large_isolate_communication',
    problemMessage:
        '[avoid_large_isolate_communication] Sending large objects between isolates is expensive.',
    correctionMessage: 'Use TransferableTypedData or process data in chunks.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
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
          if (targetSource.contains('port') ||
              targetSource.contains('sendport')) {
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

// =============================================================================
// Caching Best Practices (from v4.1.7)
// =============================================================================

/// Warns when cache implementations lack expiration logic.
///
/// `[HEURISTIC]` - Detects cache-like classes without TTL/expiration.
///
/// Caches without TTL serve stale data indefinitely. Implement expiration
/// to ensure data freshness.
///
/// **BAD:**
/// ```dart
/// class UserCache {
///   final Map<String, User> _cache = {};
///
///   User? get(String id) => _cache[id];
///   void set(String id, User user) => _cache[id] = user;
///   // No expiration - data stays forever!
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// class UserCache {
///   final Map<String, CacheEntry<User>> _cache = {};
///   final Duration ttl = Duration(minutes: 5);
///
///   User? get(String id) {
///     final entry = _cache[id];
///     if (entry == null || entry.isExpired) return null;
///     return entry.value;
///   }
/// }
/// ```
class RequireCacheExpirationRule extends SaropaLintRule {
  const RequireCacheExpirationRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'require_cache_expiration',
    problemMessage:
        '[require_cache_expiration] Cache implementation lacks expiration logic.',
    correctionMessage:
        'Add TTL/expiration to prevent serving stale data indefinitely.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
      final String className = node.name.lexeme.toLowerCase();

      // Only check cache-related classes
      if (!className.contains('cache') && !className.contains('memo')) {
        return;
      }

      final String classSource = node.toSource().toLowerCase();

      // Check for expiration-related patterns
      final bool hasExpiration = classSource.contains('expire') ||
          classSource.contains('ttl') ||
          classSource.contains('duration') ||
          classSource.contains('timestamp') ||
          classSource.contains('isvalid') ||
          classSource.contains('isstale');

      // Check for Map used as cache storage
      final bool hasMapCache = classSource.contains('map<');

      if (hasMapCache && !hasExpiration) {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when caches can grow without bounds.
///
/// `[HEURISTIC]` - Detects Map-based caches without size limits.
///
/// Caches without size limits cause out-of-memory errors.
/// Implement LRU eviction or size limits.
///
/// **Detection:**
/// - Class name contains "cache" or "memo"
/// - Class has Map field declarations (not just `toMap()` return types)
/// - No size-limiting patterns detected (maxSize, capacity, limit, evict, lru)
///
/// **Exclusions:**
/// - Database models with `@collection` (Isar), `@HiveType` (Hive),
///   or `@Entity` (Floor) annotations - these use disk storage with
///   external cleanup, not in-memory Map caching.
/// - Maps with enum keys - inherently bounded by the number of enum values.
/// - Immutable caches with no mutation methods (add, put, set, index assignment).
///
/// **BAD:**
/// ```dart
/// class ImageCache {
///   final Map<String, Uint8List> _cache = {}; // Grows forever!
///
///   void cache(String url, Uint8List data) {
///     _cache[url] = data; // No limit!
///   }
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// class ImageCache {
///   final LinkedHashMap<String, Uint8List> _cache = LinkedHashMap();
///   static const int maxSize = 100;
///
///   void cache(String url, Uint8List data) {
///     if (_cache.length >= maxSize) {
///       _cache.remove(_cache.keys.first); // LRU eviction
///     }
///     _cache[url] = data;
///   }
/// }
/// ```
///
/// **Quick fix available:** Adds a `static const int maxSize = 100;` field.
/// You'll need to manually add eviction logic in mutation methods.
class AvoidUnboundedCacheGrowthRule extends SaropaLintRule {
  const AvoidUnboundedCacheGrowthRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  /// Pattern to detect "limit" as a word boundary (not in "Uint8List").
  static final RegExp _limitPattern = RegExp(
    r'(?:^|[^a-z])limit(?:[^a-z]|$)|'
    r'[a-z]limit\b|'
    r'\blimit[A-Z]',
    caseSensitive: false,
  );

  /// Pattern to detect mutation method signatures.
  static final RegExp _mutationMethodPattern = RegExp(
    r'void\s+(add|put|set|cache|store|save|insert)\s*\(',
    caseSensitive: false,
  );

  /// Pattern to extract Map key type.
  static final RegExp _mapKeyPattern = RegExp(r'Map<(\w+),');

  static const LintCode _code = LintCode(
    name: 'avoid_unbounded_cache_growth',
    problemMessage:
        '[avoid_unbounded_cache_growth] Map or collection used as a cache has no maximum size constraint. Without eviction logic, the cache grows indefinitely as new entries are added, consuming increasing amounts of device memory. This eventually exhausts available RAM and crashes the app with an out-of-memory error, particularly on mobile devices with limited memory resources.',
    correctionMessage:
        'Implement a bounded cache with a maximum entry count and LRU (Least Recently Used) eviction policy, or use a cache library that manages size limits automatically.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
      final String className = node.name.lexeme.toLowerCase();

      // Only check cache-related classes
      if (!className.contains('cache') && !className.contains('memo')) {
        return;
      }

      final String classSource = node.toSource().toLowerCase();

      // Skip database models - they use disk storage, not memory caches
      // Isar uses @collection, Hive uses @HiveType, Floor uses @Entity
      if (classSource.contains('@collection') ||
          classSource.contains('@hivetype') ||
          classSource.contains('@entity')) {
        return;
      }

      // Check for size limiting patterns
      // Note: Use word boundaries to avoid false matches (e.g., Uint8List contains 'limit')
      // Note: Don't use 'bounded' - it matches 'unbounded' in expect_lint comments
      final bool hasSizeLimit = classSource.contains('maxsize') ||
          classSource.contains('max_size') ||
          classSource.contains('capacity') ||
          _hasLimitPattern(classSource) ||
          classSource.contains('.remove(') ||
          classSource.contains('evict') ||
          classSource.contains('lru');

      // Check for Map field declarations (not method return types)
      final bool hasMapCacheField = _hasMapCacheField(node);

      if (!hasMapCacheField || hasSizeLimit) {
        return;
      }

      // Skip if all map fields use enum keys - inherently bounded
      if (_allMapFieldsHaveEnumKeys(node)) {
        return;
      }

      // Skip if no mutation methods exist - immutable cache can't grow
      if (!_hasMutationPatterns(classSource)) {
        return;
      }

      reporter.atNode(node, code);
    });
  }

  /// Checks for "limit" as a word boundary pattern to avoid false matches
  /// like "Uint8List" which contains "limit" as a substring.
  bool _hasLimitPattern(String source) => _limitPattern.hasMatch(source);

  /// Checks if the class has a Map field that appears to be cache storage.
  /// Excludes toMap/fromMap serialization methods.
  bool _hasMapCacheField(ClassDeclaration node) {
    for (final ClassMember member in node.members) {
      if (member is FieldDeclaration) {
        final String fieldSource = member.toSource().toLowerCase();
        // Check for Map field declarations
        if (fieldSource.contains('map<') || fieldSource.contains('= {}')) {
          return true;
        }
      }
    }
    return false;
  }

  /// Checks if all Map fields in the class use enum keys.
  /// Enum-keyed maps are inherently bounded by the number of enum values.
  bool _allMapFieldsHaveEnumKeys(ClassDeclaration node) {
    bool hasMapField = false;

    for (final ClassMember member in node.members) {
      if (member is FieldDeclaration) {
        final String fieldSource = member.toSource();

        // Check for Map type declaration
        final Match? match = _mapKeyPattern.firstMatch(fieldSource);

        if (match != null) {
          hasMapField = true;
          final String keyType = match.group(1)!;

          // Check for common enum naming conventions
          // Also check for exact known enum types that might not follow convention
          if (!_isLikelyEnumType(keyType)) {
            return false; // Found a non-enum keyed map
          }
        }

        // Also check for empty map literal without type annotation: = {}
        // These are unbounded by default
        if (fieldSource.contains('= {}') && !fieldSource.contains('Map<')) {
          return false;
        }
      }
    }

    return hasMapField;
  }

  /// Checks if a type name is likely an enum based on naming conventions.
  bool _isLikelyEnumType(String typeName) {
    // Common enum naming conventions
    const List<String> enumSuffixes = <String>[
      'Enum',
      'Type',
      'Kind',
      'Mode',
      'Status',
      'State',
      'Category',
      'Level',
    ];

    for (final String suffix in enumSuffixes) {
      if (typeName.endsWith(suffix)) {
        return true;
      }
    }

    // Unbounded key types that definitely aren't enums
    const List<String> unboundedTypes = <String>[
      'String',
      'int',
      'double',
      'num',
      'dynamic',
      'Object',
    ];

    // If it's a known unbounded type, it's not an enum
    if (unboundedTypes.contains(typeName)) {
      return false;
    }

    // For other types, we can't be sure - assume not enum to be safe
    return false;
  }

  /// Checks if the class source contains patterns that indicate map mutation.
  /// Uses simple string matching on the lowercase class source.
  bool _hasMutationPatterns(String classSource) {
    // Check for index assignment: _cache[key] = value or ??=
    if (classSource.contains('[') &&
        (classSource.contains('] =') || classSource.contains('] ??='))) {
      return true;
    }

    // Check for addAll, putIfAbsent calls
    if (classSource.contains('.addall(') ||
        classSource.contains('.putifabsent(')) {
      return true;
    }

    // Check for update method: _cache.update(key, ...)
    if (classSource.contains('.update(')) {
      return true;
    }

    // Check for common mutation method patterns in method signatures
    // void add(, void put(, void set(, void cache(, etc.
    return _mutationMethodPattern.hasMatch(classSource);
  }

  @override
  List<Fix> getFixes() => <Fix>[_AvoidUnboundedCacheGrowthFix()];
}

/// Quick fix that adds a maxSize constant to the cache class.
class _AvoidUnboundedCacheGrowthFix extends DartFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
      if (!analysisError.sourceRange.intersects(node.sourceRange)) return;

      // Find the first field declaration to insert after
      FieldDeclaration? firstField;
      for (final ClassMember member in node.members) {
        if (member is FieldDeclaration) {
          firstField = member;
          break;
        }
      }

      if (firstField == null) return;

      final changeBuilder = reporter.createChangeBuilder(
        message: 'Add maxSize limit (100 entries)',
        priority: 80,
      );

      changeBuilder.addDartFileEdit((builder) {
        // Insert maxSize constant after the first field
        builder.addSimpleInsertion(
          firstField!.end,
          '\n  static const int maxSize = 100;',
        );
      });
    });
  }
}

/// Warns when cache keys may not be unique.
///
/// Cache keys must be deterministic. Using objects without stable
/// hashCode/equality as cache keys causes missed cache hits.
///
/// **BAD:**
/// ```dart
/// class RequestCache {
///   final Map<Request, Response> _cache = {}; // Request hashCode changes!
///
///   Response? get(Request request) => _cache[request];
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// class RequestCache {
///   final Map<String, Response> _cache = {};
///
///   String _makeKey(Request r) => '${r.method}:${r.url}:${r.body.hashCode}';
///
///   Response? get(Request request) => _cache[_makeKey(request)];
/// }
/// ```
class RequireCacheKeyUniquenessRule extends SaropaLintRule {
  const RequireCacheKeyUniquenessRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'require_cache_key_uniqueness',
    problemMessage:
        '[require_cache_key_uniqueness] Cache key type may have unstable hashCode.',
    correctionMessage:
        'Use String, int, or objects with stable hashCode/equality as cache keys.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  // Types that are safe as cache keys
  static const Set<String> _safeKeyTypes = {
    'String',
    'int',
    'double',
    'bool',
    'num',
    'Symbol',
    'Type',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addFieldDeclaration((FieldDeclaration node) {
      for (final VariableDeclaration variable in node.fields.variables) {
        final String fieldName = variable.name.lexeme.toLowerCase();

        // Only check cache-related fields
        if (!fieldName.contains('cache') && !fieldName.contains('memo')) {
          continue;
        }

        // Check the type annotation
        final TypeAnnotation? type = node.fields.type;
        if (type == null) continue;

        final String typeSource = type.toSource();

        // Check if it's a Map with non-primitive key
        if (typeSource.startsWith('Map<')) {
          // Extract key type
          final RegExp keyPattern = RegExp(r'Map<(\w+),');
          final Match? match = keyPattern.firstMatch(typeSource);
          if (match != null) {
            final String keyType = match.group(1)!;
            if (!_safeKeyTypes.contains(keyType)) {
              reporter.atNode(variable, code);
            }
          }
        }
      }
    });
  }
}
