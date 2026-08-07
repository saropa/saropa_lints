import 'dart:io';

import 'package:test/test.dart';

/// Integrity test: every rule file that accesses resolved-type APIs must
/// declare `usesTypeResolution => true` so balanced memory mode can skip
/// them on unchanged files. Missing the override means the optimization
/// won't apply to that rule (performance bug, not a correctness bug).
void main() {
  test('rule files using resolved-type APIs have usesTypeResolution', () {
    final ruleDir = Directory('lib/src/rules');
    final resolvedTypePatterns = RegExp(
      r'\.(staticType|allSupertypes|thisType|resolvedType'
      r'|declaredElement|staticElement)\b',
    );

    final missing = <String>[];
    for (final file in ruleDir.listSync(recursive: true)) {
      if (file is! File || !file.path.endsWith('.dart')) continue;
      final content = file.readAsStringSync();
      if (!resolvedTypePatterns.hasMatch(content)) continue;
      if (!content.contains('usesTypeResolution => true')) {
        final relative = file.path.replaceAll('\\', '/');
        missing.add(relative);
      }
    }

    expect(
      missing,
      isEmpty,
      reason: 'These rule files use resolved-type APIs but lack '
          '`@override bool get usesTypeResolution => true;`:\n'
          '${missing.join('\n')}',
    );
  });
}
