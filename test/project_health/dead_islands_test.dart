/// Tests for transitive dead-island detection (the case unused_element misses).
import 'package:saropa_lints/src/cli/project_health/dead_islands.dart';
import 'package:test/test.dart';

void main() {
  group('scanDeadIslands', () {
    test(
      'mutually-referencing private functions reachable from nothing are dead',
      () {
        const code = '''
void main() { used(); }
void used() {}
void _a() => _b();
void _b() => _a();
''';
        // _a and _b reference each other (so unused_element sees each as "used")
        // but nothing live reaches them -> both are a dead island.
        expect(scanDeadIslands(code), containsAll(['_a', '_b']));
      },
    );

    test('private reachable from a public root is not flagged', () {
      const code = '''
void publicEntry() => _helper();
void _helper() {}
''';
      expect(scanDeadIslands(code), isEmpty);
    });

    test('private reachable from main is not flagged', () {
      const code = '''
void main() => _boot();
void _boot() {}
''';
      expect(scanDeadIslands(code), isEmpty);
    });
  });
}
