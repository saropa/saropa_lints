import 'dart:io';

import 'package:saropa_lints/src/project_context.dart';

/// Exports the import graph in DOT format for Graphviz visualization.
///
/// Usage:
/// ```
/// dart run saropa_lints:cross_file graph --output-dir reports/
/// # then: dot -Tsvg reports/import_graph.dot -o reports/import_graph.svg
/// ```
///
/// The output is a directed graph where each node is a Dart file and each
/// edge represents an import relationship (importer → imported).
///
/// When [includedPaths] is provided, only those file paths are emitted as
/// nodes. Edges are restricted to pairs where both endpoints are included.
/// When null, all files from [ImportGraphCache] are used.
void exportDotGraph({
  required String projectPath,
  required String outputPath,
  Set<String>? includedPaths,
}) {
  // Use the provided set (already exclude-filtered by the caller) or fall
  // back to the full graph when no filter is active.
  final allPaths = (includedPaths ?? ImportGraphCache.getFilePaths())
      .toList()
    ..sort();
  final root = projectPath.replaceAll('\\', '/');

  final buf = StringBuffer();
  buf.writeln('digraph imports {');
  buf.writeln('  rankdir=LR;');
  buf.writeln('  node [shape=box, fontname="monospace", fontsize=10];');
  buf.writeln('  edge [color="#666666"];');
  buf.writeln();

  // Build a stable node-id map so DOT identifiers stay short and valid.
  final nodeIds = <String, String>{};
  var counter = 0;
  for (final path in allPaths) {
    nodeIds[path] = 'n${counter++}';
  }

  // Emit node labels (relative paths for readability).
  for (final path in allPaths) {
    final label = _relativize(path, root);
    buf.writeln('  ${nodeIds[path]} [label="${_escape(label)}"];');
  }
  buf.writeln();

  // Emit edges: each import becomes an edge from importer → imported.
  for (final path in allPaths) {
    final imports = ImportGraphCache.getImports(path);
    final fromId = nodeIds[path]!;
    for (final imp in imports) {
      final toId = nodeIds[imp];
      // Only emit edges to files in the graph (skip dart:, package: etc.)
      if (toId != null) {
        buf.writeln('  $fromId -> $toId;');
      }
    }
  }

  buf.writeln('}');

  final file = File(outputPath);
  // Ensure parent directory exists before writing.
  final parent = file.parent;
  if (!parent.existsSync()) {
    parent.createSync(recursive: true);
  }
  file.writeAsStringSync(buf.toString());
}

/// Returns [path] relative to [root], or [path] unchanged if it doesn't
/// start with [root].
String _relativize(String path, String root) {
  final normalized = path.replaceAll('\\', '/');
  if (normalized.startsWith(root)) {
    return normalized.substring(root.length).replaceFirst(RegExp('^/'), '');
  }
  return normalized;
}

/// Escapes characters that are special in DOT label strings.
String _escape(String s) {
  return s.replaceAll('\\', '\\\\').replaceAll('"', '\\"');
}
