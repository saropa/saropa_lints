/**
 * "Explain Baseline" outside the CLI: what the manifest contributes, and what the
 * command shows for each way a run can start and end. `dart` is never spawned.
 */
import '../vibrancy/register-vscode-mock';

import * as assert from 'node:assert';
import * as fs from 'node:fs';
import * as os from 'node:os';
import * as path from 'node:path';
import * as sinon from 'sinon';
import * as vscode from 'vscode';
import { messageMock, resetMocks } from '../vibrancy/vscode-mock';
import { registerBaselineExplainCommand, resolveExplainHost } from '../../baselineExplainCommand';
import * as setup from '../../setup';
import { catalogEntryByCommand } from '../../views/commandCatalogRegistry';

const COMMAND = 'saropaLints.explainBaseline';
/** Compiled to out-test/test/views, three levels below the extension folder. */
const EXTENSION = path.resolve(__dirname, '../../..');
const readJson = (rel: string) => JSON.parse(fs.readFileSync(path.join(EXTENSION, rel), 'utf-8'));

describe('explain baseline: manifest and catalog', () => {
  const contributes = readJson('package.json').contributes;

  it('declares the command once with a localized title', () => {
    const declared = contributes.commands.filter((c: { command: string }) => c.command === COMMAND);
    assert.strictEqual(declared.length, 1);
    assert.strictEqual(declared[0].title, '%command.explainBaseline.title%');
    assert.strictEqual(declared[0].enablement, 'saropaLints.isDartProject');
  });

  it('is in the editor and Explorer menus only, for .dart files only', () => {
    const entries: Array<[string, string]> = [];
    for (const [menu, items] of Object.entries(contributes.menus)) {
      for (const item of items as Array<{ command?: string; when?: string }>) {
        if (item.command === COMMAND) entries.push([menu, item.when ?? '']);
      }
    }
    const when = 'resourceExtname == .dart && saropaLints.isDartProject';
    assert.deepStrictEqual(entries.sort(), [
      ['editor/context', when],
      ['explorer/context', when],
    ]);
  });

  // Read only: the locale files are generated and checked by their own suite.
  it('has the title key in every manifest language file', () => {
    const files = fs.readdirSync(EXTENSION).filter((f) => /^package\.nls(\.[\w-]+)?\.json$/.test(f));
    assert.ok(files.includes('package.nls.json'));
    for (const file of files) {
      assert.ok(readJson(file)['command.explainBaseline.title'], file);
    }
  });

  it('has every runtime string the source asks for', () => {
    const source = fs.readFileSync(path.join(EXTENSION, 'src/baselineExplainCommand.ts'), 'utf-8');
    const keys = [...source.matchAll(/l10n\('(baselineExplain\.[\w.]+)'/g)].map((m) => m[1]);
    assert.ok(keys.length >= 6, `found only ${keys.length} keys`);
    const catalog = readJson('src/i18n/locales/en.json');
    for (const key of keys) {
      // Walks the nested catalog one dotted segment at a time.
      const value = key.split('.').reduce((node, part) => node?.[part], catalog);
      assert.strictEqual(typeof value, 'string', key);
    }
  });

  it('is listed in the command catalog and registered at activation', () => {
    assert.strictEqual(catalogEntryByCommand.get(COMMAND)?.category, 'Analysis');
    const activation = fs.readFileSync(path.join(EXTENSION, 'src/extension.ts'), 'utf-8');
    assert.ok(activation.includes('context.subscriptions.push(registerBaselineExplainCommand())'));
  });
});

describe('explain baseline: running the command', () => {
  type RunResult = { ok: boolean; stderr: string; stdout: string; cancelled: boolean };
  const OK: RunResult = { ok: true, stderr: '', stdout: '', cancelled: false };
  // The mock `window` lacks these two members; they are added per test.
  const win = vscode.window as unknown as Record<string, unknown>;

  let root: string;
  let file: string;
  let run: sinon.SinonStub;
  let status: string[];
  let registration: vscode.Disposable;

  /** Runs the command as a menu does (with a file) or as the palette does (without). */
  const invoke = (clicked?: string) =>
    vscode.commands.executeCommand(
      COMMAND,
      clicked ? ({ fsPath: clicked, scheme: 'file' } as vscode.Uri) : undefined,
    ) as Promise<void>;
  const setActive = (fsPath: string) => {
    win.activeTextEditor = { document: { uri: { fsPath, scheme: 'file' } } };
  };

  beforeEach(() => {
    resetMocks();
    root = fs.mkdtempSync(path.join(os.tmpdir(), 'saropa-explain-run-'));
    fs.writeFileSync(
      path.join(root, 'pubspec.yaml'),
      'name: app\ndev_dependencies:\n  saropa_lints: any\n',
    );
    file = path.join(root, 'lib', 'a.dart');
    run = sinon.stub(setup, 'runInWorkspaceAsync').resolves(OK);
    status = [];
    win.setStatusBarMessage = (text: string) => status.push(text);
    registration = registerBaselineExplainCommand();
  });
  afterEach(() => {
    registration.dispose();
    sinon.restore();
    delete win.activeTextEditor;
    delete win.setStatusBarMessage;
    fs.rmSync(root, { recursive: true, force: true });
  });

  /** Asserts the "pick a Dart file" message and that nothing ran. */
  const assertNoFile = () => {
    assert.strictEqual(run.callCount, 0);
    assert.deepStrictEqual(messageMock.infos, ['Open or select a Dart file to explain its baseline.']);
  };

  it('says to open a Dart file when none is active', async () => {
    await invoke();
    assertNoFile();
  });

  it('says the same when the active file is not Dart', async () => {
    setActive(path.join(root, 'pubspec.yaml'));
    await invoke();
    assertNoFile();
  });

  it('runs on the active file, from its package, and stays quiet on success', async () => {
    setActive(file);
    await invoke();
    assert.strictEqual(run.callCount, 1);
    const [cwd, command, args, options] = run.firstCall.args;
    assert.strictEqual(cwd, root);
    assert.strictEqual(command, 'dart');
    assert.strictEqual(args.at(-1), file);
    assert.strictEqual(options.shell, false);
    assert.ok(options.token, 'Cancel button is not wired');
    assert.deepStrictEqual([...messageMock.infos, ...messageMock.errors], []);
  });

  it('reports a package without saropa_lints and does not run', async () => {
    fs.writeFileSync(path.join(root, 'pubspec.yaml'), 'name: app\n');
    await invoke(file);
    assert.strictEqual(run.callCount, 0);
    assert.strictEqual(messageMock.errors.length, 1);
  });

  it('shows the first stderr line when the run fails', async () => {
    run.resolves({ ...OK, ok: false, stderr: 'ERROR: file not found: x\nmore' });
    await invoke(file);
    assert.deepStrictEqual(messageMock.errors, [
      'Could not explain the baseline: ERROR: file not found: x',
    ]);
  });

  it('shows no error after Cancel', async () => {
    run.resolves({ ok: false, stderr: 'Cancelled by user.', stdout: '', cancelled: true });
    await invoke(file);
    assert.deepStrictEqual(messageMock.errors, []);
  });

  it('refuses a second run while one is in flight, then allows the next', async () => {
    let finish: (result: RunResult) => void = () => {};
    run.onFirstCall().returns(new Promise<RunResult>((resolve) => (finish = resolve)));
    const first = invoke(file);
    try {
      await invoke(file);
      assert.strictEqual(run.callCount, 1);
      assert.deepStrictEqual(status, ['A baseline report is already running.']);
    } finally {
      // The guard is module state: a failed assertion must not leave it held.
      finish(OK);
    }
    await first;
    await invoke(file);
    assert.strictEqual(run.callCount, 2);
  });

  it('releases the busy guard when the run throws', async () => {
    run.onFirstCall().rejects(new Error('spawn UNKNOWN'));
    await assert.rejects(invoke(file), /spawn UNKNOWN/);
    await invoke(file);
    assert.strictEqual(run.callCount, 2);
  });

  // A monorepo opened above its packages: the host sits two folders down.
  it('hosts a nested example from the enclosing package that has the dependency', () => {
    const pkg = path.join(root, 'ws', 'packages', 'a');
    fs.mkdirSync(path.join(pkg, 'example', 'lib'), { recursive: true });
    fs.writeFileSync(path.join(pkg, 'pubspec.yaml'), 'name: a\ndev_dependencies:\n  saropa_lints: any\n');
    fs.writeFileSync(path.join(pkg, 'example', 'pubspec.yaml'), 'name: example\n');
    const nested = path.join(pkg, 'example', 'lib', 'b.dart');
    assert.strictEqual(resolveExplainHost(nested, [path.join(root, 'ws')]), pkg);
  });
});
