/// Tests the nested folder-tree builder for the drill-down treemap.
import 'package:saropa_lints/src/cli/project_health/folder_tree.dart';
import 'package:saropa_lints/src/cli/project_health/health_aggregator.dart';
import 'package:saropa_lints/src/cli/project_health/health_model.dart';
import 'package:test/test.dart';

FileHealth _f(String path, int loc) => FileHealth(
  path: path,
  bytes: loc * 10,
  loc: loc,
  codeLoc: loc,
  commentLoc: 0,
  blankLoc: 0,
);

void main() {
  test('nests folders and preserves a folder\'s own files as a (files) leaf', () {
    final agg = HealthAggregator()
      ..add(_f('lib/a.dart', 100)) // directly in lib
      ..add(_f('lib/src/b.dart', 200)); // in lib/src
    final tree = buildFolderTree(agg.folders());

    expect(tree['name'], '(root)');
    expect(tree['value'], 300);
    final libNode = (tree['children']! as List)
        .cast<Map<String, Object?>>()
        .firstWhere((n) => n['name'] == 'lib');
    expect(libNode['value'], 300);
    final libChildren = (libNode['children']! as List)
        .cast<Map<String, Object?>>();
    // lib has subfolder src (200) AND its own a.dart (100) as a "(files)" leaf.
    expect(
      libChildren.any((n) => n['name'] == 'src' && n['value'] == 200),
      isTrue,
    );
    expect(
      libChildren.any((n) => n['name'] == '(files)' && n['value'] == 100),
      isTrue,
    );
  });

  test('empty project yields a root with no children', () {
    final tree = buildFolderTree(HealthAggregator().folders());
    expect(tree['name'], '(root)');
    expect(tree.containsKey('children'), isFalse);
  });
}
