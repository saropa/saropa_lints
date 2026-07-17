import 'dart:io';

/// Discovers fixture rule names from [dir] by scanning for `*_fixture.dart`
/// files and stripping the suffix.
///
/// Returns an empty sorted list when [dir] does not exist, so the caller's
/// guard test (`expect(dir.existsSync(), isTrue)`) fails with a clear
/// assertion message instead of a [FileSystemException] aborting the entire
/// test group during setup.
List<String> discoverFixtures(Directory dir) {
  if (!dir.existsSync()) return <String>[];

  return (dir
        .listSync()
        .whereType<File>()
        .map((f) => f.uri.pathSegments.last)
        .where((name) => name.endsWith('_fixture.dart'))
        .map((name) => name.replaceAll('_fixture.dart', ''))
        .toList())
    ..sort();
}
