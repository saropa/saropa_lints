/// Tests `saropa_lints:scan_daemon` startup parsing ([parseScanDaemonArgs])
/// and the adaptive RSS recycle-ceiling policy ([resolveRssCeilingMb]).
///
/// Pure in-memory tests: the daemon binary itself only adds the exit-2
/// policy and stderr printing around these functions, so parser coverage
/// here pins the whole startup contract without spawning a process (a
/// daemon spawn costs a full analyzer warmup, ~1 minute on a real project).
library;

import 'package:saropa_lints/src/scan/scan_daemon_args.dart';
import 'package:test/test.dart';

void main() {
  group('parseScanDaemonArgs', () {
    test('positional project root with defaults', () {
      final result = parseScanDaemonArgs(<String>['D:/src/app']);
      expect(result, isA<ScanDaemonParseOk>());
      final options = (result as ScanDaemonParseOk).options;
      expect(options.projectRoot, 'D:/src/app');
      expect(options.tier, isNull);
      expect(options.maxRssMb, defaultMaxRssMb);
    });

    test('--tier with value parses', () {
      final result = parseScanDaemonArgs(<String>[
        'D:/src/app',
        '--tier',
        'recommended',
      ]);
      expect(result, isA<ScanDaemonParseOk>());
      expect((result as ScanDaemonParseOk).options.tier, 'recommended');
    });

    test('--max-rss-mb with value parses', () {
      final result = parseScanDaemonArgs(<String>[
        'D:/src/app',
        '--max-rss-mb',
        '6144',
      ]);
      expect(result, isA<ScanDaemonParseOk>());
      expect((result as ScanDaemonParseOk).options.maxRssMb, 6144);
    });

    test('flags may precede the positional', () {
      // The extension builds the argv programmatically; ordering must not
      // matter for correctness.
      final result = parseScanDaemonArgs(<String>[
        '--tier',
        'essential',
        'D:/src/app',
      ]);
      expect(result, isA<ScanDaemonParseOk>());
      final options = (result as ScanDaemonParseOk).options;
      expect(options.projectRoot, 'D:/src/app');
      expect(options.tier, 'essential');
    });

    test('--tier with no value is invalid', () {
      final result = parseScanDaemonArgs(<String>['D:/src/app', '--tier']);
      expect(result, isA<ScanDaemonParseInvalid>());
      expect(
        (result as ScanDaemonParseInvalid).message,
        contains('--tier requires a value'),
      );
    });

    test('--max-rss-mb with no value is invalid', () {
      final result = parseScanDaemonArgs(<String>[
        'D:/src/app',
        '--max-rss-mb',
      ]);
      expect(result, isA<ScanDaemonParseInvalid>());
      expect(
        (result as ScanDaemonParseInvalid).message,
        contains('--max-rss-mb requires a value'),
      );
    });

    test('--max-rss-mb rejects non-integer, zero, and negative values', () {
      // Zero/negative would recycle the daemon after every request forever;
      // all three shapes must fail parsing, not silently fall back.
      for (final bad in ['abc', '0', '-100', '4.5']) {
        final result = parseScanDaemonArgs(<String>[
          'D:/src/app',
          '--max-rss-mb',
          bad,
        ]);
        expect(result, isA<ScanDaemonParseInvalid>(), reason: bad);
        expect(
          (result as ScanDaemonParseInvalid).message,
          contains('positive integer'),
          reason: bad,
        );
      }
    });

    test('unknown flag is invalid', () {
      final result = parseScanDaemonArgs(<String>['D:/src/app', '--bogus']);
      expect(result, isA<ScanDaemonParseInvalid>());
      expect(
        (result as ScanDaemonParseInvalid).message,
        contains('Unknown flag: --bogus'),
      );
    });

    test('missing project root is invalid', () {
      final result = parseScanDaemonArgs(<String>[]);
      expect(result, isA<ScanDaemonParseInvalid>());
      expect(
        (result as ScanDaemonParseInvalid).message,
        contains('projectRoot'),
      );
    });

    test('extra positionals: first wins', () {
      // The protocol takes exactly one root; extras are ignored rather than
      // fatal so a caller quoting bug degrades gracefully.
      final result = parseScanDaemonArgs(<String>['a', 'b']);
      expect(result, isA<ScanDaemonParseOk>());
      expect((result as ScanDaemonParseOk).options.projectRoot, 'a');
    });
  });

  group('resolveRssCeilingMb', () {
    test('small prewarm keeps the configured ceiling', () {
      // 500 × 1.5 = 750 < 4096: the configured bound still governs.
      expect(
        resolveRssCeilingMb(configuredMb: 4096, postPrewarmRssMb: 500),
        4096,
      );
    });

    test('large prewarm raises the ceiling by the margin factor', () {
      // The measured contacts case: prewarm ~3650 MB nearly exhausts the
      // 4096 default; the adaptive ceiling must grant proportional headroom.
      expect(
        resolveRssCeilingMb(configuredMb: 4096, postPrewarmRssMb: 3650),
        (3650 * rssPrewarmMarginFactor).round(),
      );
    });

    test('unreadable RSS falls back to the configured ceiling', () {
      expect(
        resolveRssCeilingMb(configuredMb: 4096, postPrewarmRssMb: null),
        4096,
      );
      expect(
        resolveRssCeilingMb(configuredMb: 4096, postPrewarmRssMb: 0),
        4096,
      );
    });

    test('explicit high configured ceiling wins over the adaptive value', () {
      // A user who passed --max-rss-mb 16384 keeps it even when prewarm
      // is modest: max() never lowers the configured value.
      expect(
        resolveRssCeilingMb(configuredMb: 16384, postPrewarmRssMb: 3650),
        16384,
      );
    });
  });
}
