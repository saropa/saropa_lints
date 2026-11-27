/**
 * Command-level tests for the accepted-findings checks that used to be manual:
 * the messages and markers of "Check Accepted Findings", accepting a finding
 * (duplicate entry, one list per package) and "Migrate Renamed Rules". The
 * commands run for real against temp folders; only the CLI spawn, the pickers
 * and the diff view are stubbed. Message text is asserted against en.json, so
 * a reworded or missing key fails here.
 */
import '../vibrancy/register-vscode-mock';

import * as assert from 'node:assert';
import * as fs from 'node:fs';
import * as os from 'node:os';
import * as path from 'node:path';
import * as vscode from 'vscode';
import * as diffProvider from '../../analysisOptimizer/analyzerExcludeDiffProvider';
import { registerAcceptedFindingsCommands } from '../../accepted-findings-commands';
import type { AcceptedCheckList, AcceptedCheckResult } from '../../acceptedFindingsModel';
import { runMigrateRuleNames } from '../../ruleMigration/migrateController';
import * as setup from '../../setup';
import {
  informationMessageMockQueue,
  inputBoxMockQueue,
  messageMock,
  mockWorkspaceFolders,
  resetMocks,
} from '../vibrancy/vscode-mock';

/* eslint-disable @typescript-eslint/no-explicit-any -- stubbing module exports and mock members. */
const win = vscode.window as any;
const ws = vscode.workspace as any;

/** Restores every member replaced by [stub], newest first. */
const restores: (() => void)[] = [];

function stub(target: any, key: string, value: unknown): void {
  const had = Object.prototype.hasOwnProperty.call(target, key);
  const previous = target[key];
  target[key] = value;
  restores.push(() => {
    if (had) target[key] = previous;
    else delete target[key];
  });
}

let tmp: string;
let opened: string[];

/** Writes [text] at [relative] under the temp workspace, creating folders. */
function write(relative: string, text: string): string {
  const file = path.join(tmp, relative);
  fs.mkdirSync(path.dirname(file), { recursive: true });
  fs.writeFileSync(file, text, 'utf-8');
  return file;
}

const read = (relative: string): string => fs.readFileSync(path.join(tmp, relative), 'utf-8');

/** A package that lists saropa_lints, so it can host the CLI. */
function pubspec(dir: string): void {
  write(path.join(dir, 'pubspec.yaml'), 'name: p\ndev_dependencies:\n  saropa_lints: any\n');
}

beforeEach(() => {
  resetMocks();
  tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'saropa-checklist-'));
  opened = [];
  mockWorkspaceFolders.value = [{ uri: { fsPath: tmp } }];
  stub(win, 'showTextDocument', async (uri: { fsPath: string }) => void opened.push(uri.fsPath));
  stub(ws, 'asRelativePath', (f: string) => path.relative(tmp, f).split(path.sep).join('/'));
  stub(ws, 'onDidChangeTextDocument', () => ({ dispose: () => { /* no-op */ } }));
});

afterEach(() => {
  while (restores.length > 0) restores.pop()?.();
  resetMocks();
  fs.rmSync(tmp, { recursive: true, force: true });
});

/** One list as the CLI's JSON reports it, with [stale] stale entries of [entries]. */
function checkList(name: string, entries: number, stale: number, invalid = 0): AcceptedCheckList {
  return {
    listPath: path.join(tmp, name, 'saropa_accepted.yaml'),
    projectRoot: path.join(tmp, name),
    entries: Array.from({ length: entries }, (_, i) => ({
      rule: 'avoid_catch_all',
      file: i < stale ? 'lib/gone.dart' : 'lib/a.dart',
      kind: null,
      reason: 'r',
      line: 3 + i * 3,
      state: i < stale ? ('staleFileMissing' as const) : ('active' as const),
      hiddenCount: i < stale ? 0 : 1,
    })),
    problems: Array.from({ length: invalid }, () => ({ line: 12, message: 'Missing reason.' })),
    summary: {
      entryCount: entries,
      active: entries - stale,
      stale,
      notChecked: 0,
      problemCount: invalid,
      hiddenTotal: entries - stale,
    },
  };
}

/**
 * Registers the commands and makes the CLI spawn write [lists] to the JSON
 * path it is given. Exit 1 with empty stderr is what the CLI does for stale or
 * invalid entries. Returns the diagnostic collection and the spawn count.
 */
function arrangeCheck(lists: AcceptedCheckList[]): { diags: any; runs: string[][] } {
  const runs: string[][] = [];
  stub(setup, 'runInWorkspaceAsync', async (_cwd: string, _cmd: string, args: string[]) => {
    runs.push(args);
    const sum = (k: 'entryCount' | 'stale' | 'problemCount'): number =>
      lists.reduce((n, l) => n + l.summary[k], 0);
    const result = {
      version: 2,
      lists,
      summary: { listCount: lists.length, entryCount: sum('entryCount'), stale: sum('stale'), problemCount: sum('problemCount') },
    } as unknown as AcceptedCheckResult;
    fs.writeFileSync(args[args.indexOf('--json-file-path') + 1], JSON.stringify(result));
    return { ok: sum('stale') + sum('problemCount') === 0, stderr: '', cancelled: false };
  });
  const diags = registerAcceptedFindingsCommands({ subscriptions: [] } as unknown as vscode.ExtensionContext);
  return { diags, runs };
}

const runCheck = (): Thenable<unknown> => vscode.commands.executeCommand('saropaLints.checkAcceptedFindings');

describe('Check Accepted Findings command', () => {
  beforeEach(() => pubspec('.'));

  it('says no list exists when the CLI finds none', async () => {
    const { runs } = arrangeCheck([]);
    await runCheck();
    assert.deepStrictEqual(messageMock.infos, [
      'No saropa_accepted.yaml found in any package of the workspace. Use "Accept in this file" on a finding to start one.',
    ]);
    assert.ok(runs[0].includes('--check-accepted'));
  });

  it('reports a clean list with its entry count and no markers', async () => {
    const list = checkList('main', 1, 0);
    const { diags } = arrangeCheck([list]);
    await runCheck();
    assert.deepStrictEqual(messageMock.infos, ['Accepted findings: 1 entries checked, none stale or invalid.']);
    assert.deepStrictEqual(diags.get(vscode.Uri.file(list.listPath)), []);
  });

  it('does not count entries the CLI could not check', async () => {
    const list = checkList('main', 3, 0);
    list.summary.notChecked = 2;
    arrangeCheck([list]);
    await runCheck();
    assert.deepStrictEqual(messageMock.infos, ['Accepted findings: 1 entries checked, none stale or invalid.']);
  });

  it('warns with stale and invalid counts, marks the lines, and opens the list', async () => {
    const list = checkList('main', 3, 2, 1);
    const warnings: string[] = [];
    // The user clicks "Open List".
    stub(win, 'showWarningMessage', async (msg: string, action: string) => {
      warnings.push(msg);
      return action;
    });
    const { diags } = arrangeCheck([list]);
    await runCheck();
    assert.deepStrictEqual(warnings, [
      'Accepted findings: 2 stale and 1 invalid, out of 3 entries. See the Problems panel.',
    ]);
    const markers = diags.get(vscode.Uri.file(list.listPath));
    assert.deepStrictEqual(
      markers.map((m: vscode.Diagnostic) => [m.range.start.line + 1, m.severity]),
      [
        [3, vscode.DiagnosticSeverity.Warning],
        [6, vscode.DiagnosticSeverity.Warning],
        [12, vscode.DiagnosticSeverity.Error],
      ],
    );
    assert.deepStrictEqual(opened, [list.listPath]);
  });

  it('totals several lists, marks each, and opens one that has a warning', async () => {
    const clean = checkList('a_clean', 1, 0);
    const stale = ['main', 'main/example', 'plugin_only', 'second'].map((n) => checkList(n, 1, 1));
    const warnings: string[] = [];
    stub(win, 'showWarningMessage', async (msg: string, action: string) => {
      warnings.push(msg);
      return action;
    });
    const { diags } = arrangeCheck([clean, ...stale]);
    await runCheck();
    assert.deepStrictEqual(warnings, [
      'Accepted findings: 4 stale and 0 invalid, out of 5 entries. See the Problems panel.',
    ]);
    for (const l of stale) assert.strictEqual(diags.get(vscode.Uri.file(l.listPath)).length, 1);
    // Never the clean list, although it comes first.
    assert.deepStrictEqual(opened, [stale[0].listPath]);
  });
});

/** Runs "Accept in this file" on [relative] with a kind and reason chosen. */
async function accept(relative: string): Promise<void> {
  registerAcceptedFindingsCommands({ subscriptions: [] } as unknown as vscode.ExtensionContext);
  stub(win, 'showQuickPick', async () => ({ value: 'accepted' }));
  inputBoxMockQueue.push('  reviewed  ');
  await vscode.commands.executeCommand(
    'saropaLints.acceptFindingInFile',
    vscode.Uri.file(path.join(tmp, relative)),
    'avoid_catch_all',
  );
}

describe('Accept in this file command', () => {
  beforeEach(() => pubspec('main'));

  it('does not add a second entry beside a max entry; warns and opens the list', async () => {
    const list = 'version: 1\naccepted:\n  - rule: avoid_catch_all\n    file: lib/a.dart\n    max: 1\n    reason: one is fine\n';
    const listPath = write('main/saropa_accepted.yaml', list);
    await accept('main/lib/a.dart');
    assert.deepStrictEqual(messageMock.warnings, [
      'saropa_accepted.yaml already has an entry for avoid_catch_all in lib/a.dart. If the entry has a max count, raise it by hand.',
    ]);
    assert.strictEqual(read('main/saropa_accepted.yaml'), list);
    assert.deepStrictEqual(opened, [listPath]);
    assert.deepStrictEqual(messageMock.infos, []);
  });

  it('writes a new list for a nested package and leaves the outer list alone', async () => {
    const outer = 'version: 1\naccepted:\n';
    write('main/saropa_accepted.yaml', outer);
    pubspec('main/example');
    await accept('main/example/lib/c.dart');
    const nested = read('main/example/saropa_accepted.yaml');
    assert.ok(nested.includes('file: "lib/c.dart"'), nested);
    assert.ok(nested.includes('reason: "reviewed"'), nested);
    assert.strictEqual(read('main/saropa_accepted.yaml'), outer);
    assert.deepStrictEqual(messageMock.infos, [
      'Added avoid_catch_all in lib/c.dart to main/example/saropa_accepted.yaml. Findings already shown clear when the file is analyzed again.',
    ]);
  });

  it('writes the list beside a package one level below the workspace folder', async () => {
    pubspec('second/app');
    await accept('second/app/lib/d.dart');
    assert.ok(read('second/app/saropa_accepted.yaml').includes('file: "lib/d.dart"'));
    assert.ok(!fs.existsSync(path.join(tmp, 'second', 'saropa_accepted.yaml')));
  });
});

describe('Migrate Renamed Rules command', () => {
  const OLD = 'version: 1\naccepted:\n  - rule: deprecated_new_in_comment_reference\n    file: lib/a.dart\n    reason: rename check\n';

  /** A project whose installed saropa_lints is this repository, so the real registry applies. */
  function arrange(): string {
    const repo = path.resolve(__dirname, '../../../..');
    const version = /^version:\s*(\S+)/m.exec(fs.readFileSync(path.join(repo, 'pubspec.yaml'), 'utf-8'))?.[1];
    pubspec('.');
    write('pubspec.lock', `packages:\n  saropa_lints:\n    dependency: "direct dev"\n    source: path\n    version: "${version}"\n`);
    const rootUri = `file:///${repo.replace(/\\/g, '/').replace(/^\//, '')}`;
    write('.dart_tool/package_config.json', JSON.stringify({ packages: [{ name: 'saropa_lints', rootUri }] }));
    const list = write('saropa_accepted.yaml', OLD);
    stub(ws, 'findFiles', async (pattern: { pattern: string }) =>
      pattern.pattern === '**/saropa_accepted.yaml' ? [vscode.Uri.file(list)] : []);
    stub(diffProvider, 'showAnalyzerExcludeDiff', async () => { /* the diff view is visual */ });
    return list;
  }

  it('offers the list file, rewrites the renamed rule on Apply, and reports the counts', async () => {
    arrange();
    let title = '';
    let initialized = 0;
    // Keep the pre-ticked file and click OK.
    stub(win, 'showQuickPick', async (items: unknown[], options: { title: string }) => {
      title = options.title;
      return items;
    });
    vscode.commands.registerCommand('saropaLints.initializeConfig', () => void initialized++);
    informationMessageMockQueue.push('Apply');
    await runMigrateRuleNames();
    assert.strictEqual(title, 'Migrate renamed rules');
    assert.strictEqual(
      read('saropa_accepted.yaml'),
      OLD.replace('deprecated_new_in_comment_reference', 'deprecated_new_in_comment_reference_extended'),
    );
    assert.strictEqual(messageMock.infos.at(-1), 'Updated 1 rule reference(s) in 1 file(s): saropa_accepted.yaml.');
    assert.strictEqual(initialized, 1);
  });

  it('writes nothing when the confirmation is dismissed', async () => {
    arrange();
    stub(win, 'showQuickPick', async (items: unknown[]) => items);
    await runMigrateRuleNames();
    assert.strictEqual(read('saropa_accepted.yaml'), OLD);
  });
});
