/**
 * Tests for the POSIX (macOS/Linux) `ps` process-query path added for
 * `plans/history/2026.09/2026.09.19/infra_system_health_monitor_windows_only_no_macos_analysis_server_warning.md`.
 *
 * The System Health monitor was Windows-only because every data source shelled
 * out to `powershell.exe`/`Get-CimInstance`. These tests pin the pure parsers
 * that replace that path on darwin/linux, fed with hand-built fixture strings
 * shaped like real `ps -axww -o pid=,ppid=,rss=,lstart=,command=` output
 * (captured format verified on macOS 26.6.2, Apple silicon) — no `execFile`
 * involved, so nothing here depends on the actual process table.
 */
import '../vibrancy/register-vscode-mock';

import * as assert from 'node:assert';
import {
  classifyProcess,
  parsePsDartProcesses,
  parsePsLstart,
  parsePsProcessLine,
  parsePsSingleProcess,
  ProcessCategory,
} from '../../systemHealth/processQuery';

describe('parsePsProcessLine', () => {
  it('splits pid/ppid/rss/lstart/command from a real-shaped ps row', () => {
    const line =
      '63120 63046   2704 Fri Sep 18 23:55:38 2026     /Users/craighathaway/flutter/bin/cache/dart-sdk/bin/dartvm --packages=.dart_tool/package_config.json';
    const parsed = parsePsProcessLine(line);
    assert.ok(parsed);
    assert.strictEqual(parsed?.pid, 63120);
    assert.strictEqual(parsed?.ppid, 63046);
    assert.strictEqual(parsed?.rssKb, 2704);
    assert.strictEqual(parsed?.lstart, 'Fri Sep 18 23:55:38 2026');
    assert.strictEqual(
      parsed?.command,
      '/Users/craighathaway/flutter/bin/cache/dart-sdk/bin/dartvm --packages=.dart_tool/package_config.json',
    );
  });

  it('handles a single-digit day padded with a double space', () => {
    // ps right-justifies the day-of-month within a fixed 24-char lstart field.
    const line = '1     0  15136 Fri Sep  8 21:38:25 2026     /sbin/launchd';
    const parsed = parsePsProcessLine(line);
    assert.ok(parsed);
    assert.strictEqual(parsed?.lstart, 'Fri Sep  8 21:38:25 2026');
  });

  it('returns undefined for an unparseable line', () => {
    assert.strictEqual(parsePsProcessLine('not a ps line at all'), undefined);
    assert.strictEqual(parsePsProcessLine(''), undefined);
  });
});

describe('parsePsLstart', () => {
  it('converts an lstart string to ISO-8601', () => {
    const iso = parsePsLstart('Thu Sep 18 10:15:02 2026');
    assert.strictEqual(iso, new Date('Thu Sep 18 10:15:02 2026').toISOString());
    // Sanity: the resulting string round-trips through Date.parse, which is
    // exactly what parseCimDate's fallback path relies on.
    assert.strictEqual(Number.isNaN(Date.parse(iso)), false);
  });

  it('normalizes a double-spaced single-digit day', () => {
    const iso = parsePsLstart('Fri Sep  8 21:38:25 2026');
    assert.strictEqual(iso, new Date('Fri Sep 8 21:38:25 2026').toISOString());
  });

  it('returns empty string for unparseable input', () => {
    assert.strictEqual(parsePsLstart('garbage'), '');
  });
});

describe('parsePsDartProcesses', () => {
  // Realistic darwin `ps -axww -o pid=,ppid=,rss=,lstart=,command=` sample:
  // the analysis server (~6.7 GB, matches the bug report's reproducer),
  // an AOT frontend compiler, flutter_tester, and non-dart noise that must
  // be excluded — including a path that contains "dart" as a directory
  // name, which a naive substring match on the full command line would
  // wrongly include.
  const sample = [
    '  1432     1 7025664 Fri Sep 18 09:12:03 2026     /Users/craig/flutter/bin/cache/dart-sdk/bin/dart language-server --protocol=lsp --client-id=VS-Code --old_gen_heap_size=6144',
    ' 20044  1432   184320 Fri Sep 18 09:12:10 2026     /Users/craig/flutter/bin/cache/dart-sdk/bin/dartaotruntime /Users/craig/flutter/bin/cache/artifacts/engine/darwin-x64/frontend_server_aot.dart.snapshot --sdk-root=/Users/craig/flutter/bin/cache/artifacts',
    ' 20099  1432    98304 Fri Sep 18 09:13:41 2026     /Users/craig/flutter/bin/cache/artifacts/engine/darwin-x64/flutter_tester --disable-vm-service /Users/craig/proj/.dart_tool/flutter_test_config.dart',
    '   500     1    2048 Fri Sep 18 09:00:00 2026     /Users/craig/dart-tools/node --some-flag',
    '   501     1    1024 Fri Sep 18 09:00:00 2026     /usr/sbin/cupsd',
  ].join('\n');

  it('parses pids, ppids, and bytes for every dart-family process', () => {
    const procs = parsePsDartProcesses(sample);
    assert.deepStrictEqual(
      procs.map((p) => p.processId),
      [1432, 20044, 20099],
    );
    assert.deepStrictEqual(
      procs.map((p) => p.parentProcessId),
      // The analysis server's parent is launchd (pid 1); the other two are its children.
      [1, 1432, 1432],
    );
  });

  it('converts RSS from KB to bytes', () => {
    const [analysisServer, frontend, tester] = parsePsDartProcesses(sample);
    assert.strictEqual(analysisServer.workingSetSize, 7025664 * 1024);
    assert.strictEqual(frontend.workingSetSize, 184320 * 1024);
    assert.strictEqual(tester.workingSetSize, 98304 * 1024);
  });

  it('produces ISO creation dates parseable by Date.parse', () => {
    const [analysisServer] = parsePsDartProcesses(sample);
    assert.strictEqual(
      analysisServer.creationDate,
      new Date('Fri Sep 18 09:12:03 2026').toISOString(),
    );
    assert.strictEqual(Number.isNaN(Date.parse(analysisServer.creationDate)), false);
  });

  it('excludes non-dart processes, including a path that merely contains "dart"', () => {
    const procs = parsePsDartProcesses(sample);
    assert.ok(!procs.some((p) => p.processId === 500), 'a /dart-tools/node path must not match');
    assert.ok(!procs.some((p) => p.processId === 501), 'unrelated system processes must not match');
  });

  it('classifies the analysis server as AnalysisServer with the heap-capped label', () => {
    const [analysisServer] = parsePsDartProcesses(sample);
    const classification = classifyProcess(analysisServer);
    assert.strictEqual(classification.category, ProcessCategory.AnalysisServer);
    assert.strictEqual(classification.label, 'analysis server');
  });

  it('classifies the AOT frontend compiler and flutter_tester as Other', () => {
    const [, frontend, tester] = parsePsDartProcesses(sample);
    assert.strictEqual(classifyProcess(frontend).category, ProcessCategory.Other);
    assert.strictEqual(classifyProcess(frontend).label, 'frontend compiler');
    assert.strictEqual(classifyProcess(tester).category, ProcessCategory.Other);
  });

  it('ignores blank lines', () => {
    assert.deepStrictEqual(parsePsDartProcesses('\n\n'), []);
  });
});

describe('parsePsSingleProcess', () => {
  it('parses a found process from `ps -o pid=,lstart= -p <pid>` output', () => {
    const stdout = '    1 Fri Sep 18 21:38:25 2026\n';
    const parsed = parsePsSingleProcess(stdout);
    assert.ok(parsed);
    assert.strictEqual(parsed?.processId, 1);
    assert.strictEqual(parsed?.creationDate, new Date('Fri Sep 18 21:38:25 2026').toISOString());
  });

  it('returns undefined for empty output (process not found)', () => {
    assert.strictEqual(parsePsSingleProcess(''), undefined);
    assert.strictEqual(parsePsSingleProcess('\n'), undefined);
  });

  it('returns undefined for unparseable output', () => {
    assert.strictEqual(parsePsSingleProcess('not a process line'), undefined);
  });
});
