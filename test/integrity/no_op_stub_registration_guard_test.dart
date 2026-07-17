import 'dart:io';

import 'package:test/test.dart';

/// Guards against re-introducing calls to the three no-op registration stubs on
/// `SaropaContext` (`lib/src/native/saropa_context.dart`).
///
/// `addPostRunCallback`, `addFunctionBody`, and `addFormalParameter` exist only
/// so rules ported from the retired v4 plugin still compile. They accept a
/// callback and silently discard it, so any rule that reports inside one never
/// fires — for any user, with no error. Fourteen rules were dead this way until
/// 2026-07-16 (see
/// `bugs/dead_rules_from_noop_stub_registrations.md`). This test fails the build
/// if a rule reaches for one again, forcing the author to the real methods:
/// `addCompilationUnit` (aggregate-then-report), `addBlockFunctionBody` /
/// `addExpressionFunctionBody`, and `addSimpleFormalParameter` /
/// `addDefaultFormalParameter`.
void main() {
  // Match a METHOD CALL on the stub (dot + name + open paren), e.g.
  // `context.addPostRunCallback(`. The leading `\.` keeps the prose mentions in
  // the explanatory comments (`// The v4 addPostRunCallback ...`) and the stub
  // DEFINITIONS themselves (`void addPostRunCallback(...)`, no dot) from
  // tripping the guard. `addFormalParameterList(` and `addBlockFunctionBody(`
  // are real methods and do not match these exact names.
  final stubCallPatterns = <String, RegExp>{
    'addPostRunCallback': RegExp(r'\.\s*addPostRunCallback\s*\('),
    'addFunctionBody': RegExp(r'\.\s*addFunctionBody\s*\('),
    'addFormalParameter': RegExp(r'\.\s*addFormalParameter\s*\('),
  };

  test('no rule calls a no-op registration stub', () {
    final offenders = <String>[];

    for (final entity in Directory('lib/src/rules').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;

      final normalizedPath = entity.path.replaceAll('\\', '/');
      final content = entity.readAsStringSync();

      stubCallPatterns.forEach((String method, RegExp pattern) {
        for (final match in pattern.allMatches(content)) {
          final line = '\n'.allMatches(content.substring(0, match.start)).length + 1;
          offenders.add('$normalizedPath:$line — .$method(');
        }
      });
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'Found ${offenders.length} call(s) to a no-op registration stub. '
          'These silently discard their callback so the rule never fires. '
          'Use addCompilationUnit (aggregate-then-report), addBlockFunctionBody '
          '/ addExpressionFunctionBody, or addSimpleFormalParameter / '
          'addDefaultFormalParameter instead.\n${offenders.join('\n')}',
    );
  });
}
