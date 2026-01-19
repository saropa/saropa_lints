// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/error.dart' show DiagnosticSeverity;
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../saropa_lint_rule.dart';

// =============================================================================
// v4.1.7 Rules - Caching Best Practices
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
class AvoidUnboundedCacheGrowthRule extends SaropaLintRule {
  const AvoidUnboundedCacheGrowthRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_unbounded_cache_growth',
    problemMessage:
        '[avoid_unbounded_cache_growth] Cache without size limit grows indefinitely. This will eventually exhaust device memory and crash the app with an out-of-memory error.',
    correctionMessage:
        'Add size limit with LRU eviction or use a bounded cache implementation.',
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

      // Check for size limiting patterns
      final bool hasSizeLimit = classSource.contains('maxsize') ||
          classSource.contains('max_size') ||
          classSource.contains('capacity') ||
          classSource.contains('limit') ||
          classSource.contains('.remove(') ||
          classSource.contains('evict') ||
          classSource.contains('lru');

      // Check for Map used as cache storage
      final bool hasMapCache =
          classSource.contains('map<') || classSource.contains('= {}');

      if (hasMapCache && !hasSizeLimit) {
        reporter.atNode(node, code);
      }
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
