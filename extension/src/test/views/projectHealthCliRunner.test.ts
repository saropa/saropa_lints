/**
 * Unit tests for `projectHealthCliRunner.ts` (WP1 — Project Map's
 * `--progress` streaming spawn). Covers only the two pure, testable seams:
 * the argv builder (`buildProjectHealthArgs`) and the NDJSON event parser
 * (`tryParseHealthProgressEvent`). The spawn function itself
 * (`runProjectHealthScan`) is a `child_process`-driven integration path with
 * no existing test harness in this repo (same as the previous inline
 * `runScan` it replaces) — it was instead verified by actually running
 * `bin/project_health.dart --progress` against a real temp directory (see
 * the WP1 finish report).
 *
 * `devCliRoot.ts` (imported transitively for `killProcessTree`) imports
 * 'vscode' for real at runtime, so the vscode mock must be registered first —
 * same requirement as `projectMapReports.test.ts`.
 */
import '../vibrancy/register-vscode-mock';

import * as assert from 'node:assert';
import {
  buildProjectHealthArgs,
  tryParseHealthProgressEvent,
} from '../../views/projectHealthCliRunner';

describe('projectHealthCliRunner buildProjectHealthArgs', () => {
  it('omits --progress/--control when not streaming (buffered/CI callers unchanged)', () => {
    const args = buildProjectHealthArgs('/proj', '/proj/out', false, undefined);
    assert.ok(!args.includes('--progress'));
    assert.ok(!args.includes('--control'));
    assert.ok(args.includes('--path'));
    assert.ok(args.includes('/proj'));
    assert.ok(args.includes('--output-dir'));
  });

  it('adds --progress and --control <path> when streaming with a control file', () => {
    const args = buildProjectHealthArgs('/proj', '/proj/out', true, '/tmp/control.txt');
    assert.ok(args.includes('--progress'));
    const controlIdx = args.indexOf('--control');
    assert.ok(controlIdx >= 0);
    assert.strictEqual(args[controlIdx + 1], '/tmp/control.txt');
  });

  it('adds --progress without --control when streaming but no control file was allocated', () => {
    // createControlFile() can fail (unwritable temp dir) — the scan should
    // still get live progress even without pause/cancel-via-file.
    const args = buildProjectHealthArgs('/proj', '/proj/out', true, undefined);
    assert.ok(args.includes('--progress'));
    assert.ok(!args.includes('--control'));
  });

  it('always requests the html report format project_health --format html renders from', () => {
    const args = buildProjectHealthArgs('/proj', '/proj/out', false, undefined);
    const formatIdx = args.indexOf('--format');
    assert.strictEqual(args[formatIdx + 1], 'html');
  });
});

describe('projectHealthCliRunner tryParseHealthProgressEvent', () => {
  it('parses a well-formed NDJSON event line', () => {
    const event = tryParseHealthProgressEvent(
      '{"event":"tick","phase":"size","done":5,"total":10,"file":"lib/a.dart"}',
    );
    assert.deepStrictEqual(event, {
      event: 'tick',
      phase: 'size',
      done: 5,
      total: 10,
      file: 'lib/a.dart',
    });
  });

  it('rejects lines that are not JSON objects (real stderr text, e.g. a stack trace)', () => {
    assert.strictEqual(
      tryParseHealthProgressEvent('Unhandled exception: FileSystemException'),
      undefined,
    );
  });

  it('rejects a JSON object with no string "event" field', () => {
    assert.strictEqual(tryParseHealthProgressEvent('{"total":10}'), undefined);
  });

  it('rejects malformed JSON without throwing', () => {
    assert.strictEqual(tryParseHealthProgressEvent('{"event":'), undefined);
  });
});
