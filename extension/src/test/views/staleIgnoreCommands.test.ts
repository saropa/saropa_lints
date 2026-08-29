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

import { registerStaleIgnoreCommands, StaleIgnoreCodeActionProvider, perFileJsonPath } from '../../stale-ignore-commands';
import * as projectRoot from '../../projectRoot';
import * as pubspecReader from '../../pubspecReader';
import * as setup from '../../setup';
import { messageMock, resetMocks, DiagnosticSeverity, Diagnostic, MockDiagnosticCollection } from '../vibrancy/vscode-mock';

/** Minimal [vscode.ExtensionContext] for command registration (subscriptions only). */
function makeContext(): vscode.ExtensionContext {
  return { subscriptions: [] } as unknown as vscode.ExtensionContext;
}

describe('stale-ignore commands', () => {
  let sandbox: sinon.SinonSandbox;
  let root: string;
  let diagnosticCollection: MockDiagnosticCollection;

  beforeEach(() => {
    sandbox = sinon.createSandbox();
    resetMocks();
    // registerStaleIgnoreCommands returns the SAME module-level singleton
    // collection on every call (lazily created once) — captured here so
    // tests can assert on its state directly instead of indexing into
    // vscode-mock's createdDiagnosticCollections, which is only populated
    // on the very first call across the whole test run.
    diagnosticCollection = registerStaleIgnoreCommands(makeContext()) as unknown as MockDiagnosticCollection;
    root = fs.mkdtempSync(path.join(os.tmpdir(), 'saropa-staleignores-'));
    sandbox.stub(projectRoot, 'getProjectRoot').returns(root);
    sandbox.stub(pubspecReader, 'hasSaropaLintsDep').returns(true);
    sandbox.stub(setup, 'getSharedOutputChannel').returns({
      show: () => undefined,
    } as unknown as vscode.OutputChannel);
    // Not present on the base mock (see cross-file-commands tests for the
    // same pattern) — only needed by commands that report success via the
    // status bar rather than a toast.
    (vscode.window as unknown as { setStatusBarMessage: (...args: unknown[]) => void }).setStatusBarMessage = () => undefined;
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

  it('surfaces an error instead of a false "none found" when the JSON output is corrupt', async () => {
    // The CLI ALWAYS writes stale_ignores.json on a normal completion (even
    // for zero results), so a read/parse failure means something genuinely
    // broke — not "clean, no findings". A prior version of this handler
    // treated ANY read failure as "no stale ignores found", silently hiding
    // a corrupted-write or permissions failure as a false success.
    sandbox.stub(setup, 'runInWorkspaceAsync').resolves({
      ok: true,
      stdout: '',
      stderr: '',
      cancelled: false,
    });
    // Deliberately do NOT write the JSON file, simulating a corrupted or
    // missing output despite a reported-success exit code.

    await vscode.commands.executeCommand('saropaLints.findStaleIgnores');

    assert.ok(messageMock.errors.some((msg) => msg.includes('Find stale ignores failed')));
    assert.ok(!messageMock.infos.some((msg) => msg.includes('No stale ignore comments found')));
  });

  it('runs fix-stale-ignores-in-file scoped to a single file, then clears that file\'s diagnostics when the refresh scan reports it clean', async () => {
    const fileUri = vscode.Uri.file(path.join(root, 'lib', 'a.dart'));
    const scopedJsonPath = perFileJsonPath(root, fileUri.fsPath);

    // Seed a pre-existing diagnostic on this file, as if an earlier
    // whole-project find had flagged it — the refresh after fix must
    // replace/clear this, not leave it stale.
    diagnosticCollection.set(fileUri, [
      new Diagnostic(new vscode.Range(4, 0, 4, 10), 'stale', DiagnosticSeverity.Warning as unknown as vscode.DiagnosticSeverity),
    ]);

    const runStub = sandbox.stub(setup, 'runInWorkspaceAsync').callsFake(async (_root, _cmd, args) => {
      const argv = args as string[];
      if (argv.includes('--fix-stale-ignores')) {
        return { ok: true, stdout: 'Fixed 1 stale ignore(s) in 1 file(s)', stderr: '', cancelled: false };
      }
      // The refresh find call, scoped to the same file — reports clean.
      fs.mkdirSync(path.dirname(scopedJsonPath), { recursive: true });
      fs.writeFileSync(
        scopedJsonPath,
        JSON.stringify({ version: 1, staleIgnores: [], summary: { totalCount: 0, byFile: {}, byRule: {} } }),
        'utf8',
      );
      return { ok: true, stdout: '', stderr: '', cancelled: false };
    });

    await vscode.commands.executeCommand('saropaLints.fixStaleIgnoresInFile', fileUri);

    assert.strictEqual(runStub.callCount, 2);
    const fixArgs = runStub.firstCall.args[2] as string[];
    assert.deepStrictEqual(fixArgs, ['run', 'saropa_lints:scan', root, '--files', fileUri.fsPath, '--fix-stale-ignores']);
    const findArgs = runStub.secondCall.args[2] as string[];
    assert.deepStrictEqual(findArgs, [
      'run', 'saropa_lints:scan', root, '--files', fileUri.fsPath,
      '--find-stale-ignores', '--format', 'json', '--json-file-path', scopedJsonPath, '-q',
    ]);
    // The stale diagnostic seeded above must be gone — the file is now clean.
    assert.deepStrictEqual(diagnosticCollection.get(fileUri), []);
  });

  it('uses independent JSON output paths for concurrent per-file fixes on different files', () => {
    // Regression guard for a race condition where both per-file refreshes
    // shared one fixed filename (stale_ignores_file.json): a second file's
    // scan could write between the first file's write and read, silently
    // clobbering the first file's diagnostics with the second file's
    // (possibly empty) result. Hashing the file path into the JSON filename
    // gives each file its own output path.
    const fileA = path.join(root, 'lib', 'a.dart');
    const fileB = path.join(root, 'lib', 'b.dart');

    assert.notStrictEqual(perFileJsonPath(root, fileA), perFileJsonPath(root, fileB));
    // Deterministic — same file always maps to the same path (needed so a
    // single fix-then-find round trip for one file reads back its own write).
    assert.strictEqual(perFileJsonPath(root, fileA), perFileJsonPath(root, fileA));
  });

  it('does not run fix-stale-ignores-in-file without a confirmation dialog (single-file blast radius)', async () => {
    const fileUri = vscode.Uri.file(path.join(root, 'lib', 'a.dart'));
    const warnStub = sandbox.stub(vscode.window, 'showWarningMessage');
    sandbox.stub(setup, 'runInWorkspaceAsync').resolves({
      ok: true, stdout: '', stderr: '', cancelled: false,
    });

    await vscode.commands.executeCommand('saropaLints.fixStaleIgnoresInFile', fileUri);

    // Unlike the bulk fix command, the per-file quick fix must not prompt —
    // it's invoked from a lightbulb on a single already-visible diagnostic.
    assert.strictEqual(warnStub.callCount, 0);
  });
});

describe('StaleIgnoreCodeActionProvider', () => {
  it('offers a file-scoped quick fix for a stale-ignore diagnostic', () => {
    const provider = new StaleIgnoreCodeActionProvider();
    const uri = vscode.Uri.file('/repo/lib/a.dart');
    const range = new vscode.Range(4, 0, 4, 20);
    const diag = new vscode.Diagnostic(
      range,
      "Stale ignore: rule 'avoid_print' no longer fires on this line.",
      DiagnosticSeverity.Warning as unknown as vscode.DiagnosticSeverity,
    );
    diag.source = 'Saropa Lints';
    diag.code = 'avoid_print';

    const doc = { uri } as vscode.TextDocument;
    const context = { diagnostics: [diag] } as unknown as vscode.CodeActionContext;

    const actions = provider.provideCodeActions(doc, range, context);

    assert.strictEqual(actions.length, 1);
    assert.strictEqual(actions[0].command?.command, 'saropaLints.fixStaleIgnoresInFile');
    assert.deepStrictEqual(actions[0].command?.arguments, [uri]);
    assert.deepStrictEqual(actions[0].diagnostics, [diag]);
  });

  it('ignores diagnostics from other sources', () => {
    const provider = new StaleIgnoreCodeActionProvider();
    const uri = vscode.Uri.file('/repo/lib/a.dart');
    const range = new vscode.Range(4, 0, 4, 20);
    const diag = new vscode.Diagnostic(range, 'some other lint', DiagnosticSeverity.Warning as unknown as vscode.DiagnosticSeverity);
    diag.source = 'Some Other Linter';

    const doc = { uri } as vscode.TextDocument;
    const context = { diagnostics: [diag] } as unknown as vscode.CodeActionContext;

    const actions = provider.provideCodeActions(doc, range, context);

    assert.strictEqual(actions.length, 0);
  });
});
