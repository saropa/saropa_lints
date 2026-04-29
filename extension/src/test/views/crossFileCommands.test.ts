import '../vibrancy/register-vscode-mock';

import * as assert from 'node:assert';
import * as path from 'node:path';
import * as sinon from 'sinon';
import * as vscode from 'vscode';
import * as fs from 'node:fs';
import * as os from 'node:os';

import { registerCrossFileCommands } from '../../cross-file-commands';
import * as projectRoot from '../../projectRoot';
import * as pubspecReader from '../../pubspecReader';
import * as setup from '../../setup';
import { messageMock, resetMocks, envMock } from '../vibrancy/vscode-mock';

/** Cross-file analyzer commands: registration, workspace root, and setup hooks (mocked). */

function makeContext(): vscode.ExtensionContext {
  return { subscriptions: [] } as unknown as vscode.ExtensionContext;
}

describe('cross-file commands', () => {
  let sandbox: sinon.SinonSandbox;

  beforeEach(() => {
    sandbox = sinon.createSandbox();
    resetMocks();
    registerCrossFileCommands(makeContext());
    sandbox.stub(projectRoot, 'getProjectRoot').returns('/repo');
    sandbox.stub(pubspecReader, 'hasSaropaLintsDep').returns(true);
    sandbox.stub(setup, 'getSharedOutputChannel').returns({
      show: () => undefined,
    } as unknown as vscode.OutputChannel);
  });

  afterEach(() => {
    sandbox.restore();
  });

  it('runs unused-files via cross_file with json output', async () => {
    (vscode.window as unknown as { setStatusBarMessage: (...args: unknown[]) => void }).setStatusBarMessage = () => undefined;
    const runStub = sandbox.stub(setup, 'runInWorkspace').returns({
      ok: true,
      stdout: JSON.stringify({ unusedFiles: ['lib/a.dart'] }),
      stderr: '',
    });

    await vscode.commands.executeCommand('saropaLints.crossFile.unusedFiles');

    assert.strictEqual(runStub.callCount, 1);
    assert.deepStrictEqual(runStub.firstCall.args, [
      '/repo',
      'dart',
      ['run', 'saropa_lints:cross_file', '--path', '/repo', '--output', 'json', 'unused-files'],
      true,
    ]);
  });

  it('runs unused-l10n via cross_file with json output', async () => {
    (vscode.window as unknown as { setStatusBarMessage: (...args: unknown[]) => void }).setStatusBarMessage = () => undefined;
    const runStub = sandbox.stub(setup, 'runInWorkspace').returns({
      ok: true,
      stdout: JSON.stringify({ unusedL10nKeys: ['oldGreeting'], arbPaths: ['lib/l10n/app_en.arb'] }),
      stderr: '',
    });

    await vscode.commands.executeCommand('saropaLints.crossFile.unusedL10n');

    assert.strictEqual(runStub.callCount, 1);
    assert.deepStrictEqual(runStub.firstCall.args, [
      '/repo',
      'dart',
      ['run', 'saropa_lints:cross_file', '--path', '/repo', '--output', 'json', 'unused-l10n'],
      true,
    ]);
  });

  it('runs duplicates via cross_file with json output', async () => {
    (vscode.window as unknown as { setStatusBarMessage: (...args: unknown[]) => void }).setStatusBarMessage = () => undefined;
    const runStub = sandbox.stub(setup, 'runInWorkspace').returns({
      ok: true,
      stdout: JSON.stringify({
        duplicateBlocks: [{ lineCount: 3, occurrences: [{ path: 'lib/a.dart', startLine: 1 }] }],
      }),
      stderr: '',
    });

    await vscode.commands.executeCommand('saropaLints.crossFile.duplicates');

    assert.strictEqual(runStub.callCount, 1);
    assert.deepStrictEqual(runStub.firstCall.args, [
      '/repo',
      'dart',
      ['run', 'saropa_lints:cross_file', '--path', '/repo', '--output', 'json', 'duplicates'],
      true,
    ]);
  });

  it('opens generated snapshot json for snapshot command', async () => {
    const root = fs.mkdtempSync(path.join(os.tmpdir(), 'saropa-crossfile-'));
    (projectRoot.getProjectRoot as sinon.SinonStub).returns(root);
    const outPath = path.join(root, 'reports', '.saropa_lints', 'cross_file_snapshot.json');
    fs.mkdirSync(path.dirname(outPath), { recursive: true });
    fs.writeFileSync(outPath, '{}', 'utf8');

    const runStub = sandbox.stub(setup, 'runInWorkspace').returns({
      ok: true,
      stdout: '',
      stderr: '',
    });
    const openDocStub = sandbox.stub(vscode.workspace, 'openTextDocument').resolves({} as vscode.TextDocument);
    const showDocStub = sandbox.stub(vscode.window, 'showTextDocument').resolves({} as vscode.TextEditor);

    await vscode.commands.executeCommand('saropaLints.crossFile.snapshot');

    assert.strictEqual(runStub.callCount, 1);
    const args = runStub.firstCall.args[2] as string[];
    assert.ok(args.includes('snapshot'));
    assert.ok(args.includes('--snapshot-out'));
    assert.ok(openDocStub.calledOnce);
    assert.ok(showDocStub.calledOnce);
  });

  it('runs dead-imports via cross_file with json output', async () => {
    (vscode.window as unknown as { setStatusBarMessage: (...args: unknown[]) => void }).setStatusBarMessage = () => undefined;
    const runStub = sandbox.stub(setup, 'runInWorkspace').returns({
      ok: true,
      stdout: JSON.stringify({ deadImports: { 'lib/a.dart': ['b.dart'] } }),
      stderr: '',
    });

    await vscode.commands.executeCommand('saropaLints.crossFile.deadImports');

    assert.strictEqual(runStub.callCount, 1);
    assert.deepStrictEqual(runStub.firstCall.args, [
      '/repo',
      'dart',
      ['run', 'saropa_lints:cross_file', '--path', '/repo', '--output', 'json', 'dead-imports'],
      true,
    ]);
  });

  it('shows error when workspace root is missing', async () => {
    (projectRoot.getProjectRoot as sinon.SinonStub).returns(undefined);

    await vscode.commands.executeCommand('saropaLints.crossFile.importStats');

    assert.ok(messageMock.errors.some((msg) => msg.includes('no Dart/Flutter workspace found')));
  });

  it('shows error when saropa_lints dependency is missing', async () => {
    (pubspecReader.hasSaropaLintsDep as sinon.SinonStub).returns(false);

    await vscode.commands.executeCommand('saropaLints.crossFile.circularDeps');

    assert.ok(messageMock.errors.some((msg) => msg.includes('add saropa_lints to pubspec.yaml')));
  });

  it('opens generated dot file for graph command', async () => {
    const root = fs.mkdtempSync(path.join(os.tmpdir(), 'saropa-crossfile-'));
    (projectRoot.getProjectRoot as sinon.SinonStub).returns(root);
    const outputDir = path.join(root, 'reports', '.saropa_lints', 'cross_file');
    fs.mkdirSync(outputDir, { recursive: true });
    fs.writeFileSync(path.join(outputDir, 'import_graph.dot'), 'digraph {}', 'utf8');

    const runStub = sandbox.stub(setup, 'runInWorkspace').returns({
      ok: true,
      stdout: '',
      stderr: '',
    });
    const openDocStub = sandbox.stub(vscode.workspace, 'openTextDocument').resolves({} as vscode.TextDocument);
    const showDocStub = sandbox.stub(vscode.window, 'showTextDocument').resolves({} as vscode.TextEditor);

    await vscode.commands.executeCommand('saropaLints.crossFile.graph');

    assert.strictEqual(runStub.callCount, 1);
    const args = runStub.firstCall.args[2] as string[];
    assert.ok(args.includes('graph'));
    assert.ok(openDocStub.calledOnce);
    assert.ok(showDocStub.calledOnce);
  });

  it('offers browser open for HTML report', async () => {
    const root = fs.mkdtempSync(path.join(os.tmpdir(), 'saropa-crossfile-'));
    (projectRoot.getProjectRoot as sinon.SinonStub).returns(root);
    const outputDir = path.join(root, 'reports', '.saropa_lints', 'cross_file');
    fs.mkdirSync(outputDir, { recursive: true });
    fs.writeFileSync(path.join(outputDir, 'index.html'), '<html></html>', 'utf8');

    sandbox.stub(setup, 'runInWorkspace').returns({
      ok: true,
      stdout: '',
      stderr: '',
    });
    sandbox.stub(vscode.window, 'showInformationMessage').resolves('Open in Browser' as unknown as undefined);

    await vscode.commands.executeCommand('saropaLints.crossFile.report');

    assert.ok(envMock.openedUrls.some((url) => url.endsWith(path.join('reports', '.saropa_lints', 'cross_file', 'index.html'))));
  });

  it('surfaces command failure from stderr', async () => {
    sandbox.stub(setup, 'runInWorkspace').returns({
      ok: false,
      stdout: '',
      stderr: 'dart: command not found',
    });

    await vscode.commands.executeCommand('saropaLints.crossFile.unusedFiles');

    assert.ok(messageMock.errors.some((msg) => msg.includes('command not found')));
  });
});
