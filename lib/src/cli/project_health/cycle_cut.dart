/// Cycle-cut suggestions: for each circular import cycle, recommend the single
/// edge to remove. Heuristic = the Stable-Dependencies-Principle violation: the
/// edge where a more-depended-on (stable) file imports a less-depended-on
/// (volatile) one. Cutting/inverting that edge (e.g. extract a shared interface)
/// is the usual fix.
library;

import 'package:path/path.dart' as p;

import '../../project_context.dart';

/// A suggested fix for one cycle.
class CycleCut {
  const CycleCut({required this.cycle, required this.from, required this.to});

  /// The cycle's files (project-relative posix), in order.
  final List<String> cycle;

  /// The edge to remove: [from] should stop importing [to].
  final String from;
  final String to;

  Map<String, Object?> toJson() => {'cycle': cycle, 'from': from, 'to': to};
}

/// Pure cut-selection: picks, per cycle, the edge maximizing
/// `fanIn(from) - fanIn(to)` (stable depending on volatile). [fanIn] and
/// [toRel] are injected so this is testable without the global import graph.
List<CycleCut> suggestCycleCuts(
  List<List<String>> cycles, {
  required int Function(String) fanIn,
  required String Function(String) toRel,
}) {
  final seen = <String>{};
  final cuts = <CycleCut>[];
  for (final cycle in cycles) {
    if (cycle.length < 2) continue;
    final key = (List.of(cycle)..sort()).join('|'); // dedup rotations/dupes
    if (!seen.add(key)) continue;

    var bestScore = -1 << 30;
    var bestIdx = 0;
    for (var i = 0; i < cycle.length; i++) {
      final score = fanIn(cycle[i]) - fanIn(cycle[(i + 1) % cycle.length]);
      if (score > bestScore) {
        bestScore = score;
        bestIdx = i;
      }
    }
    cuts.add(
      CycleCut(
        cycle: [for (final node in cycle) toRel(node)],
        from: toRel(cycle[bestIdx]),
        to: toRel(cycle[(bestIdx + 1) % cycle.length]),
      ),
    );
  }
  return cuts;
}

/// Wires [suggestCycleCuts] to the (already-built) import graph and project root.
List<CycleCut> cycleCutsFromGraph(
  List<List<String>> cyclesAbs,
  String projectPath,
) => suggestCycleCuts(
  cyclesAbs,
  fanIn: (abs) => ImportGraphCache.getImporters(abs).length,
  toRel: (abs) {
    final normalized = abs.replaceAll('\\', '/');
    return p.isAbsolute(normalized)
        ? p.relative(normalized, from: projectPath).replaceAll('\\', '/')
        : normalized;
  },
);
