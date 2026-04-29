import 'dart:io';

import 'package:path/path.dart' as p;

/// Two or more occurrences of the same normalized [minLines]-line block.
class DuplicateBlockFinding {
  const DuplicateBlockFinding({
    required this.lineCount,
    required this.occurrences,
  });

  final int lineCount;
  final List<DuplicateOccurrence> occurrences;
}

class DuplicateOccurrence {
  const DuplicateOccurrence({required this.path, required this.startLine});

  final String path;
  final int startLine;
}

String _blockKey(String norm) => '${norm.length}:${norm.hashCode}';

/// Finds duplicate multi-line blocks across Dart files under `lib/` and `test/`.
List<DuplicateBlockFinding> findDuplicateLineBlocks({
  required String projectPath,
  required int minLines,
}) {
  if (minLines < 2) return const [];

  final files = <String, List<String>>{};
  for (final sub in ['lib', 'test']) {
    final dir = p.join(projectPath, sub);
    final d = Directory(dir);
    if (!d.existsSync()) continue;
    for (final e in d.listSync(recursive: true)) {
      if (e is! File || !e.path.endsWith('.dart')) continue;
      final lower = e.path.toLowerCase();
      if (lower.endsWith('.g.dart') || lower.endsWith('.freezed.dart')) {
        continue;
      }
      files[e.path] = e.readAsLinesSync();
    }
  }

  final hashToOcc = <String, List<DuplicateOccurrence>>{};
  for (final entry in files.entries) {
    final path = entry.key;
    final lines = entry.value;
    if (lines.length < minLines) continue;
    for (var i = 0; i <= lines.length - minLines; i++) {
      final slice = lines.sublist(i, i + minLines);
      final norm = slice.map((l) => l.trimRight()).join('\n');
      if (norm.trim().isEmpty) continue;
      final h = _blockKey(norm);
      hashToOcc
          .putIfAbsent(h, () => [])
          .add(DuplicateOccurrence(path: path, startLine: i + 1));
    }
  }

  final findings = <DuplicateBlockFinding>[];
  for (final occ in hashToOcc.values) {
    if (occ.length < 2) continue;
    final distinctFiles = occ.map((o) => o.path).toSet();
    if (distinctFiles.length < 2) continue;
    occ.sort((a, b) {
      final c = a.path.compareTo(b.path);
      if (c != 0) return c;
      return a.startLine.compareTo(b.startLine);
    });
    findings.add(DuplicateBlockFinding(lineCount: minLines, occurrences: occ));
  }
  findings.sort((a, b) => b.occurrences.length.compareTo(a.occurrences.length));
  return findings;
}
