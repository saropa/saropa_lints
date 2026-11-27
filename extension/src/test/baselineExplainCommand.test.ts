/** Target resolution and argument building for the "Explain Baseline" command. */
import './vibrancy/register-vscode-mock';

import * as assert from 'node:assert';
import * as fs from 'node:fs';
import * as os from 'node:os';
import * as path from 'node:path';
import type * as vscode from 'vscode';
import {
  buildExplainArgs,
  explainFailureMessage,
  quoteForShell,
  resolveExplainHost,
  resolveExplainTarget,
} from '../baselineExplainCommand';

/** Minimal Uri stand-in: the resolver reads only these two fields. */
const uri = (fsPath: string, scheme = 'file') => ({ fsPath, scheme }) as vscode.Uri;

describe('baseline explain command', () => {
  it('prefers the clicked file, then the active editor', () => {
    assert.strictEqual(resolveExplainTarget(uri('/a.dart'), uri('/b.dart')), '/a.dart');
    assert.strictEqual(resolveExplainTarget(undefined, uri('/b.dart')), '/b.dart');
  });

  it('has no target without a Dart file on disk', () => {
    assert.strictEqual(resolveExplainTarget(undefined, undefined), undefined);
    assert.strictEqual(resolveExplainTarget(undefined, uri('/pubspec.yaml')), undefined);
    assert.strictEqual(resolveExplainTarget(undefined, uri('/a.dart', 'untitled')), undefined);
  });

  it('passes a path with spaces and metacharacters as one unchanged argument', () => {
    const file = '/my app/lib/a & b.dart';
    const { args } = buildExplainArgs(file, 'linux');
    assert.deepStrictEqual(args, ['run', 'saropa_lints:baseline', '--dry-run', '--explain', file]);
  });

  it('quotes the shell-fallback arguments', () => {
    const { shellArgs } = buildExplainArgs('C:\\my app\\a&b.dart', 'win32');
    assert.strictEqual(shellArgs?.[4], '"C:\\my app\\a&b.dart"');
    assert.strictEqual(quoteForShell("/it's $(x).dart", 'linux'), "'/it'\\''s $(x).dart'");
  });

  it('refuses the shell fallback for a path cmd.exe would expand', () => {
    assert.strictEqual(buildExplainArgs('C:\\%TEMP%\\a.dart', 'win32').shellArgs, null);
  });

  // Hostile file names: each of these characters is still live inside cmd.exe
  // double quotes (or in a batch wrapper), so the shell retry must be refused.
  it('refuses the shell fallback for every cmd.exe-live character', () => {
    for (const name of ['a!x!.dart', 'a"&calc&".dart', 'a^b.dart', 'a\r\ncalc.dart']) {
      assert.strictEqual(buildExplainArgs(`C:\\p\\${name}`, 'win32').shellArgs, null, name);
    }
  });

  it('names the path as the cause when the shell fallback was refused', () => {
    const { shellArgs } = buildExplainArgs('C:\\p\\a^b.dart', 'win32');
    const text = explainFailureMessage('spawn dart ENOENT', shellArgs, 'win32');
    assert.ok(text.includes('% ! " ^'), text);
    assert.ok(!text.includes('ENOENT'), text);
  });

  it('keeps the CLI error when the path was not the cause', () => {
    // A quotable path: ENOENT then means something else, so it is passed on.
    const { shellArgs } = buildExplainArgs('C:\\p\\a.dart', 'win32');
    assert.ok(explainFailureMessage('spawn dart ENOENT', shellArgs, 'win32').includes('ENOENT'));
    // A refused path whose run started and failed on its own keeps that error.
    assert.ok(explainFailureMessage('Bad state: boom', null, 'win32').includes('boom'));
  });

  it('keeps cmd.exe operators literal inside quotes', () => {
    assert.strictEqual(quoteForShell('C:\\p\\a|b>c<d(e).dart', 'win32'), '"C:\\p\\a|b>c<d(e).dart"');
    // A trailing backslash is doubled so it cannot escape the closing quote.
    assert.strictEqual(quoteForShell('C:\\my dir\\', 'win32'), '"C:\\my dir\\\\"');
  });

  it('refuses NUL on POSIX', () => {
    assert.strictEqual(quoteForShell('/a\u0000b.dart', 'linux'), null);
  });

  describe('host package', () => {
    let root: string;
    // Creates a file (and its folders) under the temporary workspace.
    const write = (rel: string, text: string) => {
      const full = path.join(root, rel);
      fs.mkdirSync(path.dirname(full), { recursive: true });
      fs.writeFileSync(full, text);
    };
    beforeEach(() => {
      root = fs.mkdtempSync(path.join(os.tmpdir(), 'saropa-explain-'));
    });
    afterEach(() => fs.rmSync(root, { recursive: true, force: true }));

    it('uses the workspace package when the nearest one lacks the dependency', () => {
      write('pubspec.yaml', 'name: app\ndev_dependencies:\n  saropa_lints: any\n');
      write('example/pubspec.yaml', 'name: example\n');
      const file = path.join(root, 'example', 'lib', 'a.dart');
      assert.strictEqual(resolveExplainHost(file, [root]), root);
    });

    it('finds nothing when no package depends on saropa_lints', () => {
      write('pubspec.yaml', 'name: app\n');
      assert.strictEqual(resolveExplainHost(path.join(root, 'lib', 'a.dart'), [root]), undefined);
    });
  });
});
