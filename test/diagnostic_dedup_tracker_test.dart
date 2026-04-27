import 'package:saropa_lints/src/saropa_lint_rule.dart'
    show DiagnosticDedupTracker;
import 'package:test/test.dart';

void main() {
  group('DiagnosticDedupTracker', () {
    test('dedups same rule/file/offset', () {
      final tracker = DiagnosticDedupTracker();

      final first = tracker.shouldReport(
        ruleName: 'avoid_print',
        filePath: '/tmp/a.dart',
        offset: 42,
      );
      final second = tracker.shouldReport(
        ruleName: 'avoid_print',
        filePath: '/tmp/a.dart',
        offset: 42,
      );

      expect(first, isTrue);
      expect(second, isFalse);
    });

    test('allows different offsets in same file', () {
      final tracker = DiagnosticDedupTracker();

      final first = tracker.shouldReport(
        ruleName: 'avoid_print',
        filePath: '/tmp/a.dart',
        offset: 10,
      );
      final second = tracker.shouldReport(
        ruleName: 'avoid_print',
        filePath: '/tmp/a.dart',
        offset: 11,
      );

      expect(first, isTrue);
      expect(second, isTrue);
    });

    test('allows same offset across files', () {
      final tracker = DiagnosticDedupTracker();

      final first = tracker.shouldReport(
        ruleName: 'avoid_print',
        filePath: '/tmp/a.dart',
        offset: 10,
      );
      final second = tracker.shouldReport(
        ruleName: 'avoid_print',
        filePath: '/tmp/b.dart',
        offset: 10,
      );

      expect(first, isTrue);
      expect(second, isTrue);
    });

    test('allows same file/offset for different rules', () {
      final tracker = DiagnosticDedupTracker();

      final first = tracker.shouldReport(
        ruleName: 'avoid_print',
        filePath: '/tmp/a.dart',
        offset: 10,
      );
      final second = tracker.shouldReport(
        ruleName: 'avoid_debugger',
        filePath: '/tmp/a.dart',
        offset: 10,
      );

      expect(first, isTrue);
      expect(second, isTrue);
    });
  });
}
