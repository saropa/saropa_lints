/**
 * Extension tests for stale-ignore commands: argv passed to
 * `dart run saropa_lints:scan`, exit-code semantics for find vs fix (their
 * success/failure exit codes differ — see stale-ignore-commands.ts), workspace
 * root / dependency guards, and diagnostic publishing.
 *
 * VS Code APIs and `runInWorkspaceAsync` are stubbed; asserts lock the CLI
 * argument shape and the exit-code interpretation.
 */
import '../vibrancy/register-vscode-mock';

import * as assert from 'node:assert';
import * as path from 'node:path';
import * as sinon from 'sinon';
import * as vscode from 'vscode';
import * as fs from 'node:fs';
import * as os from 'node:os';

import { registerStaleIgnoreCommands } from '../../stale-ignore-commands';
import * as projectRoot from '../../projectRoot';
import * as pubspecReader from '../../pubspecReader';
import * as setup from '../../setup';
import { messageMock, resetMocks } from '../vibrancy/vscode-mock';

/** Minimal [vscode.ExtensionContext] for command registration (subscriptions only). */
function makeContext(): vscode.ExtensionContext {
  return { subscriptions: [] } as unknown as vscode.ExtensionContext;
}

describe('stale-ignore commands', () => {
  let sandbox: sinon.SinonSandbox;
  let root: string;

  beforeEach(() => {
    sandbox = sinon.createSandbox();
    resetMocks();
    registerStaleIgnoreCommands(makeContext());
    root = fs.mkdtempSync(path.join(os.tmpdir(), 'saropa-staleignores-'));
    sandbox.stub(projectRoot, 'getProjectRoot').returns(root);
    sandbox.stub(pubspecReader, 'hasSaropaLintsDep').returns(true);
    sandbox.stub(setup, 'getSharedOutputChannel').returns({
      show: () => undefined,
    } as unknown as vscode.OutputChannel);
  });

  afterEach(() => {
    sandbox.restore();
    fs.rmSync(root, { recursive: true, force: true });
  });

  it('runs find-stale-ignores with the exact CLI argument shape', async () => {
    const jsonPath = path.join(root, 'reports', '.saropa_lints', 'stale_ignores.json');
    const runStub = sandbox.stub(setup, 'runInWorkspaceAsync').callsFake(async () => {
      // Simulate the CLI writing its JSON output file before resolving.
      fs.mkdirSync(path.dirname(jsonPath), { recursive: true });
      fs.writeFileSync(
        jsonPath,
        JSON.stringify({ version: 1, staleIgnores: [], summary: { totalCount: 0, byFile: {}, byRule: {} } }),
        'utf8',
      );
      return { ok: true, stdout: '', stderr: '', cancelled: false };
    });

    await vscode.commands.executeCommand('saropaLints.findStaleIgnores');

    assert.strictEqual(runStub.callCount, 1);
    const [calledRoot, command, args] = runStub.firstCall.args as [string, string, string[]];
    assert.strictEqual(calledRoot, root);
    assert.strictEqual(command, 'dart');
    assert.deepStrictEqual(args, [
      'run',
      'saropa_lints:scan',
      root,
      '--find-stale-ignores',
      '--format',
      'json',
      '--json-file-path',
      jsonPath,
      '-q',
    ]);
  });

  it('shows "none found" when find-stale-ignores reports zero results', async () => {
    const jsonPath = path.join(root, 'reports', '.saropa_lints', 'stale_ignores.json');
    sandbox.stub(setup, 'runInWorkspaceAsync').callsFake(async () => {
      fs.mkdirSync(path.dirname(jsonPath), { recursive: true });
      fs.writeFileSync(
        jsonPath,
        JSON.stringify({ version: 1, staleIgnores: [], summary: { totalCount: 0, byFile: {}, byRule: {} } }),
        'utf8',
      );
      return { ok: true, stdout: '', stderr: '', cancelled: false };
    });

    await vscode.commands.executeCommand('saropaLints.findStaleIgnores');

    assert.ok(messageMock.infos.some((msg) => msg.includes('No stale ignore comments found')));
  });

  it('publishes a warning for a genuine find-stale-ignores failure', async () => {
    sandbox.stub(setup, 'runInWorkspaceAsync').resolves({
      ok: false,
      stdout: '',
      stderr: 'Unhandled exception: bad state',
      cancelled: false,
    });

    await vscode.commands.executeCommand('saropaLints.findStaleIgnores');

    assert.ok(messageMock.errors.some((msg) => msg.includes('bad state')));
  });

  it('treats exit 1 with no stderr as findings, not a find-stale-ignores failure', async () => {
    // The CLI exits 1 when stale ignores ARE found — this is expected, not
    // an error. See isExpectedNonZeroExit in stale-ignore-commands.ts.
    const jsonPath = path.join(root, 'reports', '.saropa_lints', 'stale_ignores.json');
    sandbox.stub(setup, 'runInWorkspaceAsync').callsFake(async () => {
      fs.mkdirSync(path.dirname(jsonPath), { recursive: true });
      fs.writeFileSync(
        jsonPath,
        JSON.stringify({
          version: 1,
          staleIgnores: [
            {
              filePath: path.join(root, 'lib', 'a.dart'),
              commentLine: 5,
              targetLine: 5,
              ruleName: 'avoid_print',
              commentText: '// ignore: avoid_print',
            },
          ],
          summary: { totalCount: 1, byFile: { [path.join(root, 'lib', 'a.dart')]: 1 }, byRule: { avoid_print: 1 } },
        }),
        'utf8',
      );
      return { ok: false, stdout: '', stderr: '', cancelled: false };
    });

    await vscode.commands.executeCommand('saropaLints.findStaleIgnores');

    assert.ok(messageMock.warnings.some((msg) => msg.includes('1 stale ignore')));
    assert.strictEqual(messageMock.errors.length, 0);
  });

  it('runs fix-stale-ignores with the exact CLI argument shape after confirmation', async () => {
    sandbox.stub(vscode.window, 'showWarningMessage').resolves('Remove stale ignores' as unknown as undefined);
    const runStub = sandbox.stub(setup, 'runInWorkspaceAsync').resolves({
      ok: true,
      stdout: 'Fixed 1 stale ignore(s) in 1 file(s)',
      stderr: '',
      cancelled: false,
    });

    await vscode.commands.executeCommand('saropaLints.fixStaleIgnores');

    assert.strictEqual(runStub.callCount, 1);
    const [calledRoot, command, args] = runStub.firstCall.args as [string, string, string[]];
    assert.strictEqual(calledRoot, root);
    assert.strictEqual(command, 'dart');
    assert.deepStrictEqual(args, ['run', 'saropa_lints:scan', root, '--fix-stale-ignores']);
  });

  it('does not run fix-stale-ignores when the user declines confirmation', async () => {
    sandbox.stub(vscode.window, 'showWarningMessage').resolves(undefined);
    const runStub = sandbox.stub(setup, 'runInWorkspaceAsync').resolves({
      ok: true,
      stdout: '',
      stderr: '',
      cancelled: false,
    });

    await vscode.commands.executeCommand('saropaLints.fixStaleIgnores');

    assert.strictEqual(runStub.callCount, 0);
  });

  it('treats exit 1 on fix-stale-ignores as a genuine failure even with empty stderr', async () => {
    // Unlike find, fix ONLY exits 1 for a real failure (stale ignores
    // detected but no files could be modified) — bin/scan.dart:547-552
    // prints that failure to stdout, not stderr. A prior bug here reused
    // find's isExpectedNonZeroExit and swallowed this as a false success.
    sandbox.stub(vscode.window, 'showWarningMessage').resolves('Remove stale ignores' as unknown as undefined);
    sandbox.stub(setup, 'runInWorkspaceAsync').resolves({
      ok: false,
      stdout: 'Detected 1 stale ignore(s) but no files were modified.',
      stderr: '',
      cancelled: false,
    });

    await vscode.commands.executeCommand('saropaLints.fixStaleIgnores');

    assert.ok(messageMock.errors.some((msg) => msg.includes('no files were modified')));
    assert.ok(!messageMock.infos.some((msg) => msg.includes('removed')));
  });

  it('shows error when workspace root is missing', async () => {
    (projectRoot.getProjectRoot as sinon.SinonStub).returns(undefined);

    await vscode.commands.executeCommand('saropaLints.findStaleIgnores');

    assert.ok(messageMock.errors.some((msg) => msg.includes('No Dart/Flutter workspace found')));
  });

  it('shows error when saropa_lints dependency is missing', async () => {
    (pubspecReader.hasSaropaLintsDep as sinon.SinonStub).returns(false);

    await vscode.commands.executeCommand('saropaLints.findStaleIgnores');

    assert.ok(messageMock.errors.some((msg) => msg.includes('Add saropa_lints to pubspec.yaml')));
  });
});
