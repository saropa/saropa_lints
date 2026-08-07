import 'package:saropa_lints/src/config/memory_mode.dart';
import 'package:saropa_lints/src/project_context.dart' show FileContentCache;
import 'package:test/test.dart';

void main() {
  group('MemoryModeConfig', () {
    setUp(MemoryModeConfig.resetForTest);

    test('defaults to balanced', () {
      expect(MemoryModeConfig.mode, MemoryMode.balanced);
      expect(MemoryModeConfig.isBalanced, isTrue);
      expect(MemoryModeConfig.shouldApplyBalancedFiltering, isTrue);
    });

    test('full mode disables filtering', () {
      MemoryModeConfig.mode = MemoryMode.full;
      expect(MemoryModeConfig.isBalanced, isFalse);
      expect(MemoryModeConfig.shouldApplyBalancedFiltering, isFalse);
    });

    test('markCli disables filtering even in balanced mode', () {
      MemoryModeConfig.markCli();
      expect(MemoryModeConfig.isBalanced, isTrue);
      expect(MemoryModeConfig.shouldApplyBalancedFiltering, isFalse);
    });

    test('resetForTest clears CLI flag', () {
      MemoryModeConfig.mode = MemoryMode.full;
      MemoryModeConfig.markCli();
      MemoryModeConfig.resetForTest();
      expect(MemoryModeConfig.mode, MemoryMode.balanced);
      expect(MemoryModeConfig.shouldApplyBalancedFiltering, isTrue);
    });
  });

  group('FileContentCache pass/revoke lifecycle', () {
    setUp(FileContentCache.clearCache);

    test('new file reports changed', () {
      expect(FileContentCache.hasChanged('/a.dart', 'content'), isTrue);
    });

    test('same content reports unchanged', () {
      FileContentCache.hasChanged('/a.dart', 'content');
      expect(FileContentCache.hasChanged('/a.dart', 'content'), isFalse);
    });

    test('modified content reports changed', () {
      FileContentCache.hasChanged('/a.dart', 'v1');
      expect(FileContentCache.hasChanged('/a.dart', 'v2'), isTrue);
    });

    test('recordRulePassed + rulePreviouslyPassed round-trip', () {
      FileContentCache.hasChanged('/a.dart', 'content');
      FileContentCache.recordRulePassed('/a.dart', 'my_rule');
      expect(
        FileContentCache.rulePreviouslyPassed('/a.dart', 'my_rule'),
        isTrue,
      );
    });

    test('revokeRulePassed clears a recorded pass', () {
      FileContentCache.hasChanged('/a.dart', 'content');
      FileContentCache.recordRulePassed('/a.dart', 'my_rule');
      FileContentCache.revokeRulePassed('/a.dart', 'my_rule');
      expect(
        FileContentCache.rulePreviouslyPassed('/a.dart', 'my_rule'),
        isFalse,
      );
    });

    test('file change clears all passed rules for that file', () {
      FileContentCache.hasChanged('/a.dart', 'v1');
      FileContentCache.recordRulePassed('/a.dart', 'rule_a');
      FileContentCache.recordRulePassed('/a.dart', 'rule_b');

      FileContentCache.hasChanged('/a.dart', 'v2');

      expect(
        FileContentCache.rulePreviouslyPassed('/a.dart', 'rule_a'),
        isFalse,
      );
      expect(
        FileContentCache.rulePreviouslyPassed('/a.dart', 'rule_b'),
        isFalse,
      );
    });

    test('invalidate clears file from all caches', () {
      FileContentCache.hasChanged('/a.dart', 'content');
      FileContentCache.recordRulePassed('/a.dart', 'my_rule');
      FileContentCache.invalidate('/a.dart');

      expect(FileContentCache.hasChanged('/a.dart', 'content'), isTrue);
      expect(
        FileContentCache.rulePreviouslyPassed('/a.dart', 'my_rule'),
        isFalse,
      );
    });
  });
}
