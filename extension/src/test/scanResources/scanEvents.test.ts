import * as assert from 'node:assert';
import { SCAN_EVENT_PREFIX, parseScanEventLine, splitLines } from '../../scanResources/scanEvents';

const line = (o: unknown): string => `${SCAN_EVENT_PREFIX}${JSON.stringify(o)}`;

describe('parseScanEventLine', () => {
  it('parses start and progress', () => {
    const s = parseScanEventLine(line({ event: 'start', files: 10, workers: 3, maxMemoryMb: 900, reserveMb: 512 }));
    assert.deepStrictEqual(s, { event: 'start', files: 10, workers: 3, maxMemoryMb: 900, reserveMb: 512 });
    const p = parseScanEventLine(
      line({ event: 'progress', done: 5, total: 10, workers: 3, allowed: 2, rssMb: 120, availableMb: null, elapsedMs: 1500 }),
    );
    assert.strictEqual(p?.event, 'progress');
    if (p?.event === 'progress') {
      assert.strictEqual(p.availableMb, null);
      assert.strictEqual(p.allowed, 2);
    }
  });
  it('parses throttle, slow, skipped and abort', () => {
    assert.strictEqual(
      parseScanEventLine(line({ event: 'throttle', from: 4, to: 1, level: 'critical', reason: 'low' }))?.event,
      'throttle',
    );
    assert.deepStrictEqual(parseScanEventLine(line({ event: 'slow', file: 'a.dart', ms: 9000 })), {
      event: 'slow',
      file: 'a.dart',
      ms: 9000,
    });
    assert.strictEqual(parseScanEventLine(line({ event: 'skipped', file: 'b.dart', reason: 'timed out' }))?.event, 'skipped');
    assert.strictEqual(parseScanEventLine(line({ event: 'abort', reason: 'budget' }))?.event, 'abort');
  });
  it('parses the summary defensively', () => {
    const s = parseScanEventLine(
      line({
        event: 'summary',
        filesTotal: 10,
        filesScanned: 9,
        aborted: true,
        abortReason: 'budget',
        slowFiles: [{ file: 'x.dart', ms: 5000 }, 'junk', null],
        skippedFiles: ['y.dart', 3],
      }),
    );
    assert.strictEqual(s?.event, 'summary');
    if (s?.event === 'summary') {
      assert.strictEqual(s.aborted, true);
      assert.deepStrictEqual(s.slowFiles, [{ file: 'x.dart', ms: 5000 }]);
      assert.deepStrictEqual(s.skippedFiles, ['y.dart']);
      assert.strictEqual(s.minAvailableMb, null);
    }
  });
  it('ignores human text, malformed JSON and unknown events', () => {
    assert.strictEqual(parseScanEventLine('Loaded 1059 rules'), undefined);
    assert.strictEqual(parseScanEventLine(`${SCAN_EVENT_PREFIX}{oops`), undefined);
    assert.strictEqual(parseScanEventLine(line({ event: 'future' })), undefined);
    assert.strictEqual(parseScanEventLine(`${SCAN_EVENT_PREFIX}42`), undefined);
  });
  it('finds the marker mid-line (progress bars use \\r)', () => {
    const e = parseScanEventLine(`  Files: 10${line({ event: 'abort', reason: 'r' })}`);
    assert.strictEqual(e?.event, 'abort');
  });
});

describe('splitLines', () => {
  it('splits on \\n, \\r\\n and bare \\r, keeping the partial tail', () => {
    const { lines, rest } = splitLines('a\nb\r\nc\rd');
    assert.deepStrictEqual(lines, ['a', 'b', 'c']);
    assert.strictEqual(rest, 'd');
  });
});
