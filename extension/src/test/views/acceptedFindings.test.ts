/**
 * Tests for the accepted-findings list surface: the pure model (check JSON
 * parsing and merging, Problems markers, nearest-package lookup, rule detection, path relativizing, entry YAML and
 * append) and the "Accept <rule> in this file…" lightbulb provider.
 *
 * Positive cases come first in each block so a helper that silently returns
 * an empty result cannot pass on the rejection cases alone.
 */
import '../vibrancy/register-vscode-mock';

import * as assert from 'node:assert';
import * as path from 'node:path';
import * as vscode from 'vscode';

import { AcceptFindingCodeActionProvider } from '../../accepted-findings-commands';
import {
  appendEntry,
  buildEntryYaml,
  findPackageRoot,
  hasEntry,
  markersFromCheck,
  mergeCheckResults,
  parseAcceptedCheckJson,
  projectRelativePath,
  saropaRuleOf,
  type AcceptedCheckList,
  type AcceptedCheckResult,
} from '../../acceptedFindingsModel';
import { DiagnosticSeverity } from '../vibrancy/vscode-mock';

const entry = { rule: 'avoid_print_in_release', file: 'lib/a.dart', kind: 'accepted' as const, reason: 'CLI: tool output # kept' };

/** One list with one entry of each state and one problem. */
function sampleList(listPath = '/repo/saropa_accepted.yaml'): AcceptedCheckList {
  return {
    listPath,
    projectRoot: path.dirname(listPath),
    entries: [
      { rule: 'r1', file: 'a.dart', kind: null, reason: 'x', line: 3, state: 'active', hiddenCount: 2 },
      { rule: 'r2', file: 'gone.dart', kind: null, reason: 'x', line: 7, state: 'staleFileMissing', hiddenCount: 0 },
      { rule: 'r3', file: 'b.dart', kind: null, reason: 'x', line: 10, state: 'staleNoFinding', hiddenCount: 0 },
      { rule: 'r4', file: 'c.dart', kind: null, reason: 'x', line: 13, state: 'notChecked', hiddenCount: 0 },
    ],
    problems: [{ line: 16, message: 'Missing or empty `reason`.' }],
    summary: { entryCount: 4, active: 1, stale: 2, notChecked: 1, problemCount: 1, hiddenTotal: 2 },
  };
}

/** A version 2 check result holding [lists], with summed totals. */
function sampleCheck(lists: AcceptedCheckList[] = [sampleList()]): AcceptedCheckResult {
  return mergeCheckResults([{ version: 2, lists, summary: { listCount: 0, entryCount: 0, active: 0, stale: 0, notChecked: 0, problemCount: 0, hiddenTotal: 0 } }]);
}

describe('acceptedFindingsModel', () => {
  it('parses the check JSON and rejects other shapes', () => {
    const parsed = parseAcceptedCheckJson(JSON.stringify(sampleCheck()));
    assert.strictEqual(parsed?.lists[0].entries.length, 4);
    // No lists under the target is a valid, empty result.
    assert.deepStrictEqual(parseAcceptedCheckJson(JSON.stringify(sampleCheck([])))?.lists, []);
    assert.strictEqual(parseAcceptedCheckJson('{"version":1}'), null);
    // Version 1 single-list shape, and a list missing its arrays.
    assert.strictEqual(parseAcceptedCheckJson(JSON.stringify(sampleList())), null);
    assert.strictEqual(parseAcceptedCheckJson('{"version":2,"lists":[{"listPath":"/a"}],"summary":{}}'), null);
    assert.strictEqual(parseAcceptedCheckJson('not json'), null);
  });

  it('marks stale entries as warnings and problems as errors, 0-based', () => {
    const markers = markersFromCheck(sampleList());
    assert.deepStrictEqual(
      markers.map((m) => [m.kind, m.severity, m.line]),
      [
        ['staleFileMissing', 'warning', 6],
        ['staleNoFinding', 'warning', 9],
        ['invalid', 'error', 15],
      ],
    );
  });

  it('merges runs, summing totals and keeping a shared list once', () => {
    const a = sampleList('/repo/saropa_accepted.yaml');
    const b = sampleList('/repo/example/saropa_accepted.yaml');
    const merged = mergeCheckResults([sampleCheck([a, b]), sampleCheck([a])]);
    assert.deepStrictEqual(merged.lists.map((l) => l.listPath), [a.listPath, b.listPath]);
    assert.strictEqual(merged.summary.listCount, 2);
    assert.strictEqual(merged.summary.stale, 4);
    assert.strictEqual(merged.summary.problemCount, 2);
  });

  it('finds the nearest package root, nested first', () => {
    const outer = path.resolve('/repo');
    const nested = path.join(outer, 'example');
    const pubspecs = new Set([path.join(outer, 'pubspec.yaml'), path.join(nested, 'pubspec.yaml')]);
    const exists = (p: string): boolean => pubspecs.has(p);
    assert.strictEqual(findPackageRoot(path.join(nested, 'lib', 'a.dart'), exists), nested);
    assert.strictEqual(findPackageRoot(path.join(outer, 'lib', 'src', 'b.dart'), exists), outer);
    // No pubspec.yaml anywhere above: no list applies.
    assert.strictEqual(findPackageRoot(path.resolve('/elsewhere/a.dart'), exists), undefined);
  });

  it('detects saropa rules by the [rule] message prefix only', () => {
    assert.strictEqual(saropaRuleOf('[avoid_x] Bad thing.', 'avoid_x'), 'avoid_x');
    assert.strictEqual(saropaRuleOf('[avoid_x] Bad.', { value: 'avoid_x', target: {} }), 'avoid_x');
    // SDK lint: same code, no prefix.
    assert.strictEqual(saropaRuleOf('Avoid print calls.', 'avoid_print'), undefined);
    assert.strictEqual(saropaRuleOf('[other] x', 'avoid_x'), undefined);
    assert.strictEqual(saropaRuleOf('[x] y', undefined), undefined);
  });

  it('relativizes inside the root and refuses outside paths', () => {
    const root = path.resolve('/repo');
    assert.strictEqual(projectRelativePath(root, path.join(root, 'lib', 'a.dart')), 'lib/a.dart');
    assert.strictEqual(projectRelativePath(root, path.resolve('/elsewhere/a.dart')), undefined);
    assert.strictEqual(projectRelativePath(root, root), undefined);
  });

  it('quotes file and reason so YAML-special characters stay literal', () => {
    const yaml = buildEntryYaml(entry);
    assert.ok(yaml.includes('reason: "CLI: tool output # kept"'));
    assert.ok(yaml.startsWith('  - rule: avoid_print_in_release\n'));
  });

  it('creates a new list with version header', () => {
    const text = appendEntry(undefined, entry);
    assert.ok(text?.includes('version: 1\naccepted:\n  - rule: avoid_print_in_release'));
  });

  it('appends under an existing block list, matching its indent', () => {
    const zeroIndent = 'version: 1\naccepted:\n- rule: a\n  file: b.dart\n  reason: r\n';
    const out = appendEntry(zeroIndent, entry);
    assert.ok(out?.endsWith('- rule: avoid_print_in_release\n  file: "lib/a.dart"\n  kind: accepted\n  reason: "CLI: tool output # kept"\n'));
    // No `accepted:` key yet: one is added.
    assert.ok(appendEntry('version: 1\n', entry)?.includes('version: 1\naccepted:\n  - rule:'));
  });

  it('refuses layouts it cannot extend without rewriting', () => {
    assert.strictEqual(appendEntry('accepted: []\n', entry), null);
    assert.strictEqual(appendEntry('accepted:\n  - rule: a\nversion: 1\n', entry), null);
  });
});

describe('hasEntry', () => {
  const list = [
    'version: 1',
    'accepted:',
    '  - rule: avoid_x',
    '    file: "lib/a.dart"',
    '    reason: "moved from file: lib/b.dart"',
    '    max: 2',
    "  - {rule: 'avoid_y', file: ./lib/c.dart, reason: r}",
    '  # - rule: avoid_z',
    '  #   file: lib/a.dart',
  ].join('\r\n');

  it('finds block and flow entries, with or without a max', () => {
    assert.strictEqual(hasEntry(list, 'avoid_x', 'lib/a.dart'), true);
    assert.strictEqual(hasEntry(list, 'avoid_y', 'lib/c.dart'), true);
  });

  it('ignores other files, commented entries and text inside a reason', () => {
    assert.strictEqual(hasEntry(list, 'avoid_x', 'lib/b.dart'), false);
    assert.strictEqual(hasEntry(list, 'avoid_z', 'lib/a.dart'), false);
    assert.strictEqual(hasEntry('', 'avoid_x', 'lib/a.dart'), false);
  });
});

describe('AcceptFindingCodeActionProvider', () => {
  const uri = vscode.Uri.file('/repo/lib/a.dart');
  const range = new vscode.Range(1, 0, 1, 5);

  /** Builds a diagnostic with the given message and code. */
  function diag(message: string, code: string): vscode.Diagnostic {
    const d = new vscode.Diagnostic(range, message, DiagnosticSeverity.Warning as unknown as vscode.DiagnosticSeverity);
    d.code = code;
    return d;
  }

  it('offers one action per saropa rule, never preferred', () => {
    const provider = new AcceptFindingCodeActionProvider();
    const a = diag('[avoid_x] One.', 'avoid_x');
    const b = diag('[avoid_x] Two.', 'avoid_x');
    const sdk = diag('Avoid print.', 'avoid_print');
    const actions = provider.provideCodeActions(
      { uri } as vscode.TextDocument,
      range,
      { diagnostics: [a, b, sdk] } as unknown as vscode.CodeActionContext,
    );
    assert.strictEqual(actions.length, 1);
    assert.strictEqual(actions[0].command?.command, 'saropaLints.acceptFindingInFile');
    assert.deepStrictEqual(actions[0].command?.arguments, [uri, 'avoid_x']);
    assert.deepStrictEqual(actions[0].diagnostics, [a, b]);
    assert.notStrictEqual(actions[0].isPreferred, true);
  });

  it('offers nothing for non-saropa diagnostics', () => {
    const provider = new AcceptFindingCodeActionProvider();
    const actions = provider.provideCodeActions(
      { uri } as vscode.TextDocument,
      range,
      { diagnostics: [diag('Avoid print.', 'avoid_print')] } as unknown as vscode.CodeActionContext,
    );
    assert.strictEqual(actions.length, 0);
  });
});
