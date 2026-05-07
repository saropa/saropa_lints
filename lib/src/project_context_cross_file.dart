// Module overview (comment coverage pass).
// comment-coverage: module overview (batch).
//
// Core saropa_lints library implementation (utilities, context, or rules support).
//
// Saropa custom lints: rules register in `lib/src/rules/all_rules.dart`
// and tiers in `lib/src/tiers.dart` where applicable; see
// `plans/COMMENT_COVERAGE_PLAN.md`.

part of 'project_context.dart';

/// Optional data from `dart run saropa_lints:cross_file snapshot` (JSON on disk).
/// Reloads when the snapshot file’s modification time changes.
class CrossFileSnapshotData {
  CrossFileSnapshotData._(this._map);
  final Map<String, dynamic> _map;

  List<String> get unusedFiles =>
      List<String>.from(_map['unusedFiles'] as List? ?? const []);

  List<List<String>> get circularDependencies {
    final raw = _map['circularDependencies'] as List?;
    if (raw == null) return const [];
    return raw
        .map((e) => List<String>.from(e as List? ?? const []))
        .toList(growable: false);
  }

  Map<String, List<String>> get deadImports {
    final raw = _map['deadImports'] as Map?;
    if (raw == null) return const {};
    return raw.map(
      (k, v) =>
          MapEntry(k.toString(), List<String>.from(v as List? ?? const [])),
    );
  }

  bool isUnusedFilePath(String absolutePath) {
    final norm = p.normalize(absolutePath).replaceAll('\\', '/');
    for (final u in unusedFiles) {
      if (norm.endsWith(u.replaceAll('\\', '/'))) return true;
    }
    return false;
  }
}

String? _crossFileSnapKey;
CrossFileSnapshotData? _crossFileSnap;

void clearCrossFileSnapshotCache() {
  _crossFileSnapKey = null;
  _crossFileSnap = null;
}

CrossFileSnapshotData? loadCrossFileSnapshot(String? projectRoot) {
  if (projectRoot == null || projectRoot.isEmpty) return null;
  final path = p.join(
    projectRoot,
    'reports',
    '.saropa_lints',
    'cross_file_snapshot.json',
  );
  final f = File(path);
  if (!f.existsSync()) return null;
  final key = '${f.path}|${f.lastModifiedSync().millisecondsSinceEpoch}';
  if (_crossFileSnapKey == key && _crossFileSnap != null) {
    return _crossFileSnap;
  }
  try {
    final Object? raw = jsonDecode(f.readAsStringSync());
    if (raw is! Map<String, dynamic>) return null;
    final m = raw;
    if ((m['version'] as num?)?.toInt() != crossFileSnapshotFormatVersion) {
      return null;
    }
    _crossFileSnapKey = key;
    _crossFileSnap = CrossFileSnapshotData._(m);
    return _crossFileSnap;
  } on FormatException catch (e, st) {
    developer.log(
      'cross_file snapshot: invalid JSON',
      error: e,
      stackTrace: st,
    );
    return null;
  } on Object catch (e, st) {
    developer.log('cross_file snapshot: load failed', error: e, stackTrace: st);
    return null;
  }
}
