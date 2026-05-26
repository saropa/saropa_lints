/// Import-coupling metrics (fan-in / fan-out / instability) read from the
/// already-built [ImportGraphCache]. Rides for free on `--deadweight`, which
/// builds the graph — no second traversal. Keys are project-relative posix.
library;

import 'package:path/path.dart' as p;

import '../../project_context.dart';

/// One file's coupling. Instability `I = Ce / (Ca + Ce)` (Robert Martin): 0 =
/// stable (many depend on it, it depends on little), 1 = unstable.
class Coupling {
  const Coupling(this.fanIn, this.fanOut);

  /// Afferent (Ca): how many files import this one.
  final int fanIn;

  /// Efferent (Ce): how many files this one imports.
  final int fanOut;

  double get instability {
    final total = fanIn + fanOut;
    return total == 0 ? 0 : fanOut / total;
  }
}

/// Reads coupling for every file in the (already-built) import graph, keyed by
/// project-relative posix path. Call only after the graph has been built (e.g.
/// after the dead-weight pass).
Map<String, Coupling> couplingFromGraph(String projectPath) {
  final result = <String, Coupling>{};
  for (final abs in ImportGraphCache.getFilePaths()) {
    final fanIn = ImportGraphCache.getImporters(abs).length;
    final fanOut = ImportGraphCache.getImports(abs).length;
    result[_toRel(abs, projectPath)] = Coupling(fanIn, fanOut);
  }
  return result;
}

String _toRel(String path, String projectPath) {
  final normalized = path.replaceAll('\\', '/');
  if (p.isAbsolute(normalized)) {
    return p.relative(normalized, from: projectPath).replaceAll('\\', '/');
  }
  return normalized;
}
