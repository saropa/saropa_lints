/// Builds a nested folder tree (ECharts treemap format) from the flat folder
/// rollups, so the size map drills DOWN by folder instead of showing a flat list
/// of files. Folder count is bounded (far fewer than files), so this stays
/// memory-cheap — the aggregate-first, drill-down design from the scaling plan.
library;

import 'health_model.dart';

/// Converts folder rollups into a single nested `{name, value, children}` tree
/// rooted at `.`. A folder's own (direct) lines become a synthetic `(files)`
/// leaf so nothing is lost when it also has subfolders.
Map<String, Object?> buildFolderTree(List<FolderHealth> folders) {
  final byPath = {for (final f in folders) f.path: f};
  final childrenOf = <String, List<String>>{};
  for (final f in folders) {
    if (f.path == '.') continue;
    childrenOf.putIfAbsent(_parent(f.path), () => []).add(f.path);
  }
  return _node('.', byPath, childrenOf);
}

Map<String, Object?> _node(
  String path,
  Map<String, FolderHealth> byPath,
  Map<String, List<String>> childrenOf,
) {
  final folder = byPath[path];
  final loc = folder?.loc ?? 0;
  final kids = [...?childrenOf[path]]
    ..sort((a, b) => (byPath[b]?.loc ?? 0).compareTo(byPath[a]?.loc ?? 0));
  final childNodes = [for (final c in kids) _node(c, byPath, childrenOf)];
  final childLoc = kids.fold<int>(0, (sum, c) => sum + (byPath[c]?.loc ?? 0));
  final directLoc = (loc - childLoc).clamp(0, loc);

  final node = <String, Object?>{
    'name': path == '.' ? '(root)' : _last(path),
    'value': loc,
  };
  final children = <Map<String, Object?>>[...childNodes];
  // Keep the folder's own files visible alongside its subfolders.
  if (directLoc > 0 && childNodes.isNotEmpty) {
    children.add({'name': '(files)', 'value': directLoc});
  }
  if (children.isNotEmpty) node['children'] = children;
  return node;
}

String _parent(String path) {
  final idx = path.lastIndexOf('/');
  return idx < 0 ? '.' : path.substring(0, idx);
}

String _last(String path) {
  final idx = path.lastIndexOf('/');
  return idx < 0 ? path : path.substring(idx + 1);
}
