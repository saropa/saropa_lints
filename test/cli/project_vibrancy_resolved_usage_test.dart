/// Tests for the **element-resolved usage** pass that refines the project
/// vibrancy `usageCount` and `unused` flag (source plan
/// `plans/PLAN_vibrancy_usage_collector_element_resolution.md`, Phases 1-2).
///
/// Phase 1 proves attribution is now semantic, not name-string: two same-named
/// private functions in different files get their OWN caller counts instead of
/// sharing one inflated bucket. Phase 2 proves runtime-invoked entry points
/// (`main`, `@pragma('vm:entry-point')`, framework `@override`s) are never
/// flagged `unused` even with zero static callers, while a plain orphan still is.
///
/// Each scenario seeds a real on-disk package under `Directory.systemTemp` so
/// the analyzer can build a resolved element model (the name-based fallback
/// would defeat the point of the assertions).
library;

import 'dart:io';

import 'package:saropa_lints/src/cli/project_vibrancy.dart';
import 'package:test/test.dart';

void main() {
  group('project vibrancy resolved usage', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('pv_resolved_');
      // A minimal pubspec roots the temp tree as a package so the analyzer
      // forms a clean analysis context over it.
      File('${tempDir.path}/pubspec.yaml').writeAsStringSync('''
name: pv_resolved_fixture
environment:
  sdk: ^3.0.0
''');
      Directory('${tempDir.path}/lib').createSync(recursive: true);
    });

    tearDown(() {
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    });

    ProjectVibrancyFunctionResult? rowFor(
      ProjectVibrancyReport report,
      String name,
      String fileEndsWith,
    ) {
      for (final fn in report.functions) {
        if (fn.name == name && fn.file.endsWith(fileEndsWith)) return fn;
      }
      return null;
    }

    test('attributes callers per declaration, not per name '
        '(same-named privates in different files)', () async {
      // `_shared` exists in both files. In a.dart it is called once (by
      // `publicA`); in b.dart it is never called. Name-based counting rolls
      // both into one bucket and reads both as used — the bug. Resolved
      // counting must give a.dart's `_shared` 1 and b.dart's `_shared` 0.
      File('${tempDir.path}/lib/a.dart').writeAsStringSync('''
int _shared() => 1;

int publicA() => _shared();
''');
      File('${tempDir.path}/lib/b.dart').writeAsStringSync('''
int _shared() => 1;

int publicB() => 2;
''');

      final report = await runProjectVibrancy(
        ProjectVibrancyOptions(projectPath: tempDir.path),
      );

      final sharedA = rowFor(report, '_shared', 'a.dart');
      final sharedB = rowFor(report, '_shared', 'b.dart');
      expect(sharedA, isNotNull, reason: 'a.dart _shared row missing');
      expect(sharedB, isNotNull, reason: 'b.dart _shared row missing');
      // The headline assertion: distinct, correct per-declaration counts.
      expect(sharedA!.usageCount, 1);
      expect(sharedB!.usageCount, 0);
      // And the zero-caller one is the orphan, not the called one.
      expect(sharedB.flags, contains('unused'));
      expect(sharedA.flags, isNot(contains('unused')));
    });

    test('does not count a function self-reference (recursion)', () async {
      // `_recurse` calls only itself; with no external caller it must read as
      // unused (the count excludes references inside its own body).
      File('${tempDir.path}/lib/r.dart').writeAsStringSync('''
int _recurse(int n) => n <= 0 ? 0 : _recurse(n - 1);
''');

      final report = await runProjectVibrancy(
        ProjectVibrancyOptions(projectPath: tempDir.path),
      );

      final recurse = rowFor(report, '_recurse', 'r.dart');
      expect(recurse, isNotNull);
      expect(recurse!.usageCount, 0);
      expect(recurse.flags, contains('unused'));
    });

    test(
      'entry points with zero static callers are not flagged unused',
      () async {
        // `toString` overrides an external (dart:core `Object`) member — the
        // plan's framework-override case. It is reached via the supertype, never
        // by a static reference to this declaration, so a zero static-caller
        // count must NOT read as `unused`.
        File('${tempDir.path}/lib/entry.dart').writeAsStringSync('''
class Widget {
  @override
  String toString() => 'Widget';
}

@pragma('vm:entry-point')
void nativeHook() {}

void main() {}

void _orphan() {}
''');

        final report = await runProjectVibrancy(
          ProjectVibrancyOptions(projectPath: tempDir.path),
        );

        final overridden = rowFor(report, 'toString', 'entry.dart');
        expect(overridden, isNotNull);
        expect(overridden!.usageCount, 0);
        expect(overridden.flags, isNot(contains('unused')));

        // Native/AOT entry point and top-level main: protected despite 0 refs.
        final nativeHook = rowFor(report, 'nativeHook', 'entry.dart');
        final mainFn = rowFor(report, 'main', 'entry.dart');
        expect(nativeHook, isNotNull);
        expect(nativeHook!.flags, isNot(contains('unused')));
        expect(mainFn, isNotNull);
        expect(mainFn!.flags, isNot(contains('unused')));

        // A plain private helper with no caller is still a real orphan.
        final orphan = rowFor(report, '_orphan', 'entry.dart');
        expect(orphan, isNotNull);
        expect(orphan!.usageCount, 0);
        expect(orphan.flags, contains('unused'));
      },
    );
  });
}
