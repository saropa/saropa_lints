part of 'project_context.dart';

class CachedSymbolInfo {
  const CachedSymbolInfo({
    required this.name,
    required this.kind,
    this.typeName,
    this.isStatic = false,
    this.isPrivate = false,
    this.isAsync = false,
    this.returnType,
    this.parameterCount,
    this.declaringClass,
  });

  final String name;
  final SymbolKind kind;
  final String? typeName;
  final bool isStatic;
  final bool isPrivate;
  final bool isAsync;
  final String? returnType;
  final int? parameterCount;
  final String? declaringClass;
}

/// Kind of symbol.
enum SymbolKind {
  classDecl,
  methodDecl,
  functionDecl,
  variableDecl,
  fieldDecl,
  parameterDecl,
  enumDecl,
  mixinDecl,
  extensionDecl,
  typedefDecl,
  constructorDecl,
}

/// Caches semantic information about symbols in files.
///
/// Usage:
/// ```dart
/// // Cache a symbol
/// SemanticTokenCache.cacheSymbol(
///   filePath,
///   offset,
///   CachedSymbolInfo(name: 'myMethod', kind: SymbolKind.methodDecl, ...),
/// );
///
/// // Look up a symbol
/// final info = SemanticTokenCache.getSymbol(filePath, offset);
/// if (info?.kind == SymbolKind.methodDecl && info.isAsync) {
///   // Handle async method
/// }
/// ```
class SemanticTokenCache {
  SemanticTokenCache._();

  // Map of file path -> map of offset -> symbol info
  static final Map<String, Map<int, CachedSymbolInfo>> _symbols = {};

  // Map of file path -> map of name -> list of offsets (for name lookups)
  static final Map<String, Map<String, List<int>>> _nameIndex = {};

  // Map of file path -> content hash (for invalidation)
  static final Map<String, int> _contentHashes = {};

  /// Cache a symbol at a specific offset.
  static void cacheSymbol(String filePath, int offset, CachedSymbolInfo info) {
    _symbols.putIfAbsent(filePath, () => {})[offset] = info;

    // Also index by name for fast lookups
    _nameIndex
        .putIfAbsent(filePath, () => {})
        .putIfAbsent(info.name, () => [])
        .add(offset);
  }

  /// Get symbol info at a specific offset.
  static CachedSymbolInfo? getSymbol(String filePath, int offset) {
    return _symbols[filePath]?[offset];
  }

  /// Get all symbols with a specific name in a file.
  static List<CachedSymbolInfo> getSymbolsByName(String filePath, String name) {
    final offsets = _nameIndex[filePath]?[name];
    if (offsets == null) return [];

    final fileSymbols = _symbols[filePath];
    if (fileSymbols == null) return [];

    return offsets
        .map((o) => fileSymbols[o])
        .whereType<CachedSymbolInfo>()
        .toList();
  }

  /// Get all symbols of a specific kind in a file.
  static List<CachedSymbolInfo> getSymbolsByKind(
    String filePath,
    SymbolKind kind,
  ) {
    final fileSymbols = _symbols[filePath];
    if (fileSymbols == null) return [];

    return fileSymbols.values.where((s) => s.kind == kind).toList();
  }

  /// Check if we have cached symbols for a file with matching content.
  static bool hasCachedSymbols(String filePath, String content) {
    return _contentHashes[filePath] == content.hashCode &&
        _symbols.containsKey(filePath);
  }

  /// Mark that symbols have been cached for a specific content version.
  static void markCached(String filePath, String content) {
    _contentHashes[filePath] = content.hashCode;
  }

  /// Invalidate cache for a file.
  static void invalidate(String filePath) {
    _symbols.remove(filePath);
    _nameIndex.remove(filePath);
    _contentHashes.remove(filePath);
  }

  /// Clear all caches.
  static void clearCache() {
    _symbols.clear();
    _nameIndex.clear();
    _contentHashes.clear();
  }

  /// Get statistics.
  static Map<String, dynamic> getStats() {
    var totalSymbols = 0;
    for (final symbols in _symbols.values) {
      totalSymbols += symbols.length;
    }

    return {'cachedFiles': _symbols.length, 'totalSymbols': totalSymbols};
  }
}

// =============================================================================
// COMPILATION UNIT DERIVED DATA CACHE (Performance Optimization)
// =============================================================================
//
// Caches expensive AST traversal results that multiple rules query.
// Instead of each rule traversing the AST to find "all method names" or
// "all class hierarchies", we compute once and cache.
// =============================================================================

/// Cached derived data from a compilation unit.
class CompilationUnitDerivedData {
  CompilationUnitDerivedData();

  /// All class names declared in the file.
  final Set<String> classNames = {};

  /// All method names declared in the file.
  final Set<String> methodNames = {};

  /// All function names declared in the file.
  final Set<String> functionNames = {};

  /// All variable names declared in the file.
  final Set<String> variableNames = {};

  /// All field names declared in the file.
  final Set<String> fieldNames = {};

  /// All import URIs in the file.
  final Set<String> importUris = {};

  /// All export URIs in the file.
  final Set<String> exportUris = {};

  /// Whether file has main() function.
  bool hasMainFunction = false;

  /// Whether file has Flutter widgets.
  bool hasWidgets = false;

  /// Whether file has async code.
  bool hasAsyncCode = false;

  /// Whether file has tests.
  bool hasTests = false;

  /// Class inheritance map (class name -> superclass name).
  final Map<String, String?> classInheritance = {};

  /// Class mixins map (class name -> list of mixin names).
  final Map<String, List<String>> classMixins = {};

  /// Class interfaces map (class name -> list of interface names).
  final Map<String, List<String>> classInterfaces = {};
}

/// Caches derived data from compilation units.
///
/// Usage:
/// ```dart
/// // Get or create derived data for a file
/// final data = CompilationUnitCache.getOrCreate(filePath, content);
///
/// // Check if file declares a specific class
/// if (data.classNames.contains('MyWidget')) {
///   // Handle
/// }
///
/// // Check class inheritance
/// if (data.classInheritance['MyWidget'] == 'StatelessWidget') {
///   // It's a stateless widget
/// }
/// ```
class CompilationUnitCache {
  CompilationUnitCache._();

  // Map of file path -> derived data
  static final Map<String, CompilationUnitDerivedData> _cache = {};

  // Map of file path -> content hash (for invalidation)
  static final Map<String, int> _contentHashes = {};

  /// Get cached data for a file, or create empty data if not cached.
  static CompilationUnitDerivedData getOrCreate(
    String filePath,
    String content,
  ) {
    final hash = content.hashCode;
    final cached = _cache[filePath];
    if (_contentHashes[filePath] == hash && cached != null) {
      return cached;
    }

    // Create new data
    final data = CompilationUnitDerivedData();
    _cache[filePath] = data;
    _contentHashes[filePath] = hash;

    // Pre-populate with basic content analysis
    _analyzeContent(content, data);

    return data;
  }

  /// Quick content analysis to populate basic data.
  static void _analyzeContent(String content, CompilationUnitDerivedData data) {
    // Check for widgets
    data.hasWidgets =
        content.contains('extends StatelessWidget') ||
        content.contains('extends StatefulWidget') ||
        content.contains('extends State<');

    // Check for async
    data.hasAsyncCode =
        content.contains('async') || content.contains('Future<');

    // Check for tests
    data.hasTests =
        content.contains('@Test') ||
        content.contains('void main()') && content.contains('test(');

    // Check for main function
    data.hasMainFunction = RegExp(r'void\s+main\s*\(').hasMatch(content);

    // Extract imports
    final importPattern = RegExp(r'''import\s+['"]([^'"]+)['"]''');
    for (final match in importPattern.allMatches(content)) {
      final uri = match.group(1);
      if (uri != null) data.importUris.add(uri);
    }

    // Extract exports
    final exportPattern = RegExp(r'''export\s+['"]([^'"]+)['"]''');
    for (final match in exportPattern.allMatches(content)) {
      final uri = match.group(1);
      if (uri != null) data.exportUris.add(uri);
    }

    // Extract class names (simple pattern)
    final classPattern = RegExp(r'class\s+(\w+)');
    for (final match in classPattern.allMatches(content)) {
      final name = match.group(1);
      if (name != null) data.classNames.add(name);
    }

    // Extract function names (simple pattern)
    final funcPattern = RegExp(r'^\s*\w+\s+(\w+)\s*\(', multiLine: true);
    for (final match in funcPattern.allMatches(content)) {
      final name = match.group(1);
      if (name != null && name != 'if' && name != 'for' && name != 'while') {
        data.functionNames.add(name);
      }
    }
  }

  /// Get cached data for a file (returns null if not cached).
  static CompilationUnitDerivedData? get(String filePath) {
    return _cache[filePath];
  }

  /// Check if data is cached and current for a file.
  static bool isCached(String filePath, String content) {
    return _contentHashes[filePath] == content.hashCode &&
        _cache.containsKey(filePath);
  }

  /// Update derived data after AST analysis.
  static void update(String filePath, CompilationUnitDerivedData data) {
    _cache[filePath] = data;
  }

  /// Invalidate cache for a file.
  static void invalidate(String filePath) {
    _cache.remove(filePath);
    _contentHashes.remove(filePath);
  }

  /// Clear all caches.
  static void clearCache() {
    _cache.clear();
    _contentHashes.clear();
  }

  /// Get statistics.
  static Map<String, dynamic> getStats() {
    var totalClasses = 0;
    var totalMethods = 0;
    for (final data in _cache.values) {
      totalClasses += data.classNames.length;
      totalMethods += data.methodNames.length;
    }

    return {
      'cachedFiles': _cache.length,
      'totalClasses': totalClasses,
      'totalMethods': totalMethods,
    };
  }
}

// =============================================================================
// THROTTLED ANALYSIS FOR IDE (Performance Optimization)
// =============================================================================
//
// Throttles analysis requests during rapid typing to reduce CPU usage.
// When a user is actively typing, we delay analysis until they pause.
// This prevents the analyzer from running on every keystroke.
// =============================================================================

/// Throttles analysis during rapid editing.
///
/// Usage:
/// ```dart
/// // Before starting analysis
/// if (!ThrottledAnalysis.shouldAnalyze(filePath)) {
///   return; // Skip - user is still typing
/// }
///
/// // Record that file was modified
/// ThrottledAnalysis.recordEdit(filePath);
/// ```
