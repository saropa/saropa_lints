part of 'project_context.dart';

class ImportNode {
  ImportNode(this.filePath);

  final String filePath;
  final Set<String> imports = {};
  final Set<String> exports = {};
  final Set<String> importedBy = {}; // Reverse graph

  /// Check if this file transitively imports another.
  bool transitivelyImports(String target) {
    final visited = <String>{};
    return _transitivelyImportsHelper(target, visited);
  }

  bool _transitivelyImportsHelper(String target, Set<String> visited) {
    if (visited.contains(filePath)) return false;
    visited.add(filePath);

    if (imports.contains(target)) return true;

    for (final imp in imports) {
      final node = ImportGraphCache.getNode(imp);
      if (node != null && node._transitivelyImportsHelper(target, visited)) {
        return true;
      }
    }
    return false;
  }
}

/// Caches import graph for efficient dependency queries.
///
/// Usage:
/// ```dart
/// // Build graph from project files
/// ImportGraphCache.buildFromDirectory(projectRoot);
///
/// // Query dependencies
/// final node = ImportGraphCache.getNode(filePath);
/// if (node?.imports.contains('package:flutter/material.dart')) {
///   // File imports Flutter
/// }
///
/// // Check transitive dependencies
/// if (ImportGraphCache.hasTransitiveImport(fileA, fileB)) {
///   // fileA transitively imports fileB
/// }
/// ```
class ImportGraphCache {
  ImportGraphCache._();

  // Map of file path -> import node
  static final Map<String, ImportNode> _graph = {};

  // Track if graph is built
  static bool _isBuilt = false;
  static String? _projectRoot;

  /// Build import graph from a project directory.
  static Future<void> buildFromDirectory(String projectRoot) {
    if (_isBuilt && _projectRoot == projectRoot) return Future.value();

    _graph.clear();
    _projectRoot = projectRoot;

    // Find all Dart files (projectRoot is configured project root, not user input)
    final libDir = Directory(p.join(projectRoot, 'lib'));
    if (!libDir.existsSync()) {
      _isBuilt = true;
      return Future.value();
    }

    _scanDirectory(libDir);
    _buildReverseGraph();
    _isBuilt = true;
    return Future.value();
  }

  /// Scan a directory for Dart files and parse their imports.
  static void _scanDirectory(Directory dir) {
    try {
      final entities = dir.listSync(recursive: true);
      for (final entity in entities) {
        if (entity is File && entity.path.endsWith('.dart')) {
          _parseImports(entity.path);
        }
      }
    } on OSError catch (e, st) {
      developer.log(
        'import graph scan failed',
        name: 'saropa_lints',
        error: e,
        stackTrace: st,
      );
      // Ignore errors during scanning
    }
  }

  /// Parse imports from a single file.
  static void _parseImports(String filePath) {
    try {
      // Normalize so graph keys match _resolveImport output (forward slashes); needed on Windows.
      filePath = p.normalize(filePath).replaceAll('\\', '/');
      final file = File(filePath);
      if (!file.existsSync()) return;

      final content = file.readAsStringSync();
      final node = ImportNode(filePath);

      // Parse imports and exports with simple regex
      final importPattern = RegExp(r'''import\s+['"]([^'"]+)['"]''');
      final exportPattern = RegExp(r'''export\s+['"]([^'"]+)['"]''');

      for (final match in importPattern.allMatches(content)) {
        final import = match.group(1);
        if (import != null) {
          node.imports.add(_resolveImport(import, filePath));
        }
      }

      for (final match in exportPattern.allMatches(content)) {
        final export = match.group(1);
        if (export != null) {
          node.exports.add(_resolveImport(export, filePath));
        }
      }

      _graph[filePath] = node;
    } on IOException catch (e, st) {
      developer.log(
        '_parseImports read failed',
        name: 'saropa_lints',
        error: e,
        stackTrace: st,
      );
      // Ignore read errors
    } on FormatException catch (e, st) {
      developer.log(
        '_parseImports parse failed',
        name: 'saropa_lints',
        error: e,
        stackTrace: st,
      );
      // Ignore parse errors
    }
  }

  /// Resolve a relative import to absolute path.
  static String _resolveImport(String import, String fromFile) {
    if (import.startsWith('package:') || import.startsWith('dart:')) {
      return import;
    }
    final fromDir = File(fromFile).parent.path;
    final resolved = p.normalize(p.join(fromDir, import));
    return resolved.replaceAll('\\', '/');
  }

  /// Build reverse graph (importedBy relationships).
  static void _buildReverseGraph() {
    for (final node in _graph.values) {
      for (final imp in node.imports) {
        final target = _graph[imp];
        if (target != null) {
          target.importedBy.add(node.filePath);
        }
      }
    }
  }

  /// Get import node for a file.
  static ImportNode? getNode(String filePath) {
    return _graph[filePath];
  }

  /// Check if fileA transitively imports fileB.
  static bool hasTransitiveImport(String fileA, String fileB) {
    final node = _graph[fileA];
    if (node == null) return false;
    return node.transitivelyImports(fileB);
  }

  /// Get all files that import a specific file.
  static Set<String> getImporters(String filePath) {
    return _graph[filePath]?.importedBy ?? {};
  }

  /// Get all files that a specific file imports.
  static Set<String> getImports(String filePath) {
    return _graph[filePath]?.imports ?? {};
  }

  /// Check if the graph contains a specific file.
  static bool hasFile(String filePath) {
    return _graph.containsKey(filePath);
  }

  /// All file paths currently in the graph.
  static Set<String> getFilePaths() {
    return _graph.keys.toSet();
  }

  /// Detect circular imports involving a file.
  static List<List<String>> detectCircularImports(String filePath) {
    final cycles = <List<String>>[];
    final node = _graph[filePath];
    if (node == null) return cycles;

    final path = <String>[filePath];
    final visited = <String>{filePath};

    _detectCycles(node, path, visited, cycles);
    return cycles;
  }

  static void _detectCycles(
    ImportNode node,
    List<String> path,
    Set<String> visited,
    List<List<String>> cycles,
  ) {
    final pathFirst = path.firstOrNull;
    for (final imp in node.imports) {
      if (pathFirst != null && imp == pathFirst) {
        // Found a cycle back to start
        cycles.add([...path, imp]);
        continue;
      }

      if (visited.contains(imp)) continue;

      final nextNode = _graph[imp];
      if (nextNode != null) {
        visited.add(imp);
        path.add(imp);
        _detectCycles(nextNode, path, visited, cycles);
        path.removeLast();
      }
    }
  }

  /// Invalidate cache for a file (e.g., when file changes).
  static void invalidate(String filePath) {
    final node = _graph.remove(filePath);
    if (node != null) {
      // Remove from reverse graph
      for (final imp in node.imports) {
        _graph[imp]?.importedBy.remove(filePath);
      }
    }
  }

  /// Clear entire cache.
  static void clearCache() {
    _graph.clear();
    _isBuilt = false;
    _projectRoot = null;
  }

  /// Get statistics about the import graph.
  static Map<String, dynamic> getStats() {
    var totalImports = 0;
    var maxImports = 0;
    String? fileWithMostImports;

    for (final entry in _graph.entries) {
      final count = entry.value.imports.length;
      totalImports += count;
      if (count > maxImports) {
        maxImports = count;
        fileWithMostImports = entry.key;
      }
    }

    return {
      'isBuilt': _isBuilt,
      'projectRoot': _projectRoot,
      'fileCount': _graph.length,
      'totalImports': totalImports,
      'avgImportsPerFile': _graph.isEmpty ? 0 : totalImports / _graph.length,
      'maxImports': maxImports,
      'fileWithMostImports': fileWithMostImports,
    };
  }
}

// =============================================================================
// SOURCE LOCATION CACHE (Performance Optimization)
// =============================================================================
//
// Caches offset-to-line/column calculations to avoid repeated computation.
// Computing line numbers from offsets requires scanning the content, which
// is O(n) per lookup. Caching makes subsequent lookups O(1).
// =============================================================================

/// Cached source location (line and column).
class SourceLocation {
  const SourceLocation(this.line, this.column);

  final int line;
  final int column;

  @override
  String toString() => '$line:$column';
}

/// Caches line/column lookups for file offsets.
///
/// Usage:
/// ```dart
/// // Get location from offset
/// final loc = SourceLocationCache.getLocation(filePath, content, offset);
/// print('Line ${loc.line}, column ${loc.column}');
///
/// // Or compute line starts once, then lookup many offsets
/// SourceLocationCache.computeLineStarts(filePath, content);
/// final loc1 = SourceLocationCache.getLocation(filePath, content, offset1);
/// final loc2 = SourceLocationCache.getLocation(filePath, content, offset2);
/// ```
class SourceLocationCache {
  SourceLocationCache._();

  // Map of file path -> list of line start offsets
  static final Map<String, List<int>> _lineStarts = {};

  // Map of file path -> content hash (for invalidation)
  static final Map<String, int> _contentHashes = {};

  /// Compute and cache line starts for a file.
  static void computeLineStarts(String filePath, String content) {
    final hash = content.hashCode;
    if (_contentHashes[filePath] == hash && _lineStarts.containsKey(filePath)) {
      return; // Already computed for this content
    }

    final starts = <int>[0]; // Line 1 starts at offset 0
    for (var i = 0; i < content.length; i++) {
      if (content[i] == '\n') {
        starts.add(i + 1); // Next line starts after newline
      }
    }

    _lineStarts[filePath] = starts;
    _contentHashes[filePath] = hash;
  }

  /// Get source location for an offset.
  static SourceLocation getLocation(
    String filePath,
    String content,
    int offset,
  ) {
    // Ensure line starts are computed
    if (!_lineStarts.containsKey(filePath) ||
        _contentHashes[filePath] != content.hashCode) {
      computeLineStarts(filePath, content);
    }

    final starts = _lineStarts[filePath];
    if (starts == null || starts.isEmpty) {
      return SourceLocation(1, 1);
    }

    // Binary search for the line containing this offset
    var low = 0;
    var high = starts.length - 1;

    while (low < high) {
      final mid = (low + high + 1) ~/ 2;
      if (starts[mid] <= offset) {
        low = mid;
      } else {
        high = mid - 1;
      }
    }

    final line = low + 1; // Lines are 1-indexed
    final column = offset - starts[low] + 1; // Columns are 1-indexed

    return SourceLocation(line, column);
  }

  /// Get line number for an offset (1-indexed).
  static int getLine(String filePath, String content, int offset) {
    return getLocation(filePath, content, offset).line;
  }

  /// Get column number for an offset (1-indexed).
  static int getColumn(String filePath, String content, int offset) {
    return getLocation(filePath, content, offset).column;
  }

  /// Get offset for a line/column pair.
  static int? getOffset(String filePath, String content, int line, int column) {
    if (!_lineStarts.containsKey(filePath) ||
        _contentHashes[filePath] != content.hashCode) {
      computeLineStarts(filePath, content);
    }

    final starts = _lineStarts[filePath];
    if (starts == null || line < 1 || line > starts.length) return null;

    final lineStart = starts[line - 1];
    return lineStart + column - 1;
  }

  /// Get the line content for a specific line number.
  static String? getLineContent(String filePath, String content, int line) {
    if (!_lineStarts.containsKey(filePath) ||
        _contentHashes[filePath] != content.hashCode) {
      computeLineStarts(filePath, content);
    }

    final starts = _lineStarts[filePath];
    if (starts == null || line < 1 || line > starts.length) return null;

    final start = starts[line - 1];
    final end = line < starts.length ? starts[line] - 1 : content.length;

    return content.slice(start, end);
  }

  /// Invalidate cache for a file.
  static void invalidate(String filePath) {
    _lineStarts.remove(filePath);
    _contentHashes.remove(filePath);
  }

  /// Clear all caches.
  static void clearCache() {
    _lineStarts.clear();
    _contentHashes.clear();
  }

  /// Get statistics.
  static Map<String, dynamic> getStats() {
    return {
      'cachedFiles': _lineStarts.length,
      'totalLines': _lineStarts.values.fold<int>(0, (sum, l) => sum + l.length),
    };
  }
}

// =============================================================================
// SEMANTIC TOKEN CACHE (Performance Optimization)
// =============================================================================
//
// Caches resolved type information and symbol metadata across rules.
// Type resolution is expensive; caching it allows multiple rules
// to share the same resolved information.
// =============================================================================

/// Cached information about a symbol (class, method, variable, etc.).
