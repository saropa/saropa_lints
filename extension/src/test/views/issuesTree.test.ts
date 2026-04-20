/**
 * Tests for the expand-all behavior in IssuesTreeProvider.
 * Verifies that programmatic navigation expands the tree and
 * that non-expand mutations clear the override.
 */
import '../vibrancy/register-vscode-mock';

import * as assert from 'node:assert';
import * as sinon from 'sinon';
import { TreeItemCollapsibleState } from '../vibrancy/vscode-mock-classes';

// Stub modules that issuesTree transitively imports before loading it.
// projectRoot's getProjectRoot is called in getTreeItem and many methods.
import * as projectRoot from '../../projectRoot';
import * as suppressionsStore from '../../suppressionsStore';
import * as violationsReader from '../../violationsReader';
import * as pathUtils from '../../pathUtils';

import { IssuesTreeProvider, type IssueTreeNode } from '../../views/issuesTree';
import { clearTestConfig, setTestConfig } from '../vibrancy/vscode-mock';

/** Minimal Memento mock matching vscode.Memento. */
class MockMemento {
  private readonly store = new Map<string, unknown>();
  get<T>(key: string, defaultValue?: T): T | undefined {
    return this.store.has(key) ? (this.store.get(key) as T) : defaultValue;
  }
  async update(key: string, value: unknown): Promise<void> {
    this.store.set(key, value);
  }
  keys(): readonly string[] {
    return [...this.store.keys()];
  }
  setKeysForSync(): void { /* no-op */ }
}

function makeSeverityNode(severity = 'warning', count = 5): IssueTreeNode {
  return { kind: 'severity', severity, count };
}

function makeFolderNode(): IssueTreeNode {
  return { kind: 'folder', severity: 'warning', pathPrefix: '', segmentName: 'lib', count: 3 };
}

describe('IssuesTreeProvider expand-all', () => {
  let provider: IssuesTreeProvider;

  beforeEach(() => {
    // Stub getProjectRoot to return a fake path so getTreeItem doesn't blow up.
    sinon.stub(projectRoot, 'getProjectRoot').returns('/fake/root');
    // Stub loadSuppressions so the constructor doesn't fail.
    sinon.stub(suppressionsStore, 'loadSuppressions').returns({
      hiddenFolders: [],
      hiddenFiles: [],
      hiddenRules: [],
      hiddenRuleInFile: {},
      hiddenSeverities: [],
      hiddenImpacts: [],
    });

    provider = new IssuesTreeProvider(new MockMemento() as any);
  });

  afterEach(() => {
    sinon.restore();
  });

  it('defaults to Collapsed for severity nodes', () => {
    const item = provider.getTreeItem(makeSeverityNode());
    assert.strictEqual(item.collapsibleState, TreeItemCollapsibleState.Collapsed);
  });

  it('defaults to Collapsed for folder nodes', () => {
    const item = provider.getTreeItem(makeFolderNode());
    assert.strictEqual(item.collapsibleState, TreeItemCollapsibleState.Collapsed);
  });

  it('returns Expanded after expandAll()', () => {
    provider.expandAll();
    const item = provider.getTreeItem(makeSeverityNode());
    assert.strictEqual(item.collapsibleState, TreeItemCollapsibleState.Expanded);
  });

  it('returns Expanded for folder nodes after expandAll()', () => {
    provider.expandAll();
    const item = provider.getTreeItem(makeFolderNode());
    assert.strictEqual(item.collapsibleState, TreeItemCollapsibleState.Expanded);
  });

  it('clears expand override after refresh()', () => {
    provider.expandAll();
    provider.refresh();
    const item = provider.getTreeItem(makeSeverityNode());
    assert.strictEqual(item.collapsibleState, TreeItemCollapsibleState.Collapsed);
  });

  it('clears expand override on setTextFilter (non-expand mutation)', () => {
    provider.expandAll();
    provider.setTextFilter('something');
    const item = provider.getTreeItem(makeSeverityNode());
    assert.strictEqual(
      item.collapsibleState,
      TreeItemCollapsibleState.Collapsed,
      'filter change should clear the expand-all override',
    );
  });

  it('clears expand override on setSeverityFilter', () => {
    provider.expandAll();
    provider.setSeverityFilter(new Set(['error']));
    const item = provider.getTreeItem(makeSeverityNode('error', 2));
    assert.strictEqual(item.collapsibleState, TreeItemCollapsibleState.Collapsed);
  });

  it('clears expand override on setImpactFilter', () => {
    provider.expandAll();
    provider.setImpactFilter(new Set(['critical']));
    const item = provider.getTreeItem(makeSeverityNode());
    assert.strictEqual(item.collapsibleState, TreeItemCollapsibleState.Collapsed);
  });

  it('clears expand override on clearFilters', () => {
    provider.expandAll();
    provider.clearFilters();
    const item = provider.getTreeItem(makeSeverityNode());
    assert.strictEqual(item.collapsibleState, TreeItemCollapsibleState.Collapsed);
  });

  it('re-expands when expandAll is called after filter change', () => {
    // Simulates the focus command pattern: filter → expandAll.
    provider.clearFilters();
    provider.expandAll();
    const item = provider.getTreeItem(makeSeverityNode());
    assert.strictEqual(item.collapsibleState, TreeItemCollapsibleState.Expanded);
  });
});

describe('IssuesTreeProvider self-contained element children', () => {
  let readViolationsStub: sinon.SinonStub;

  beforeEach(() => {
    clearTestConfig();
    setTestConfig('saropaLints', 'violationsGroupBy', 'severity');
    sinon.stub(projectRoot, 'getProjectRoot').returns('/fake/root');
    sinon.stub(suppressionsStore, 'loadSuppressions').returns({
      hiddenFolders: [],
      hiddenFiles: [],
      hiddenRules: [],
      hiddenRuleInFile: {},
      hiddenSeverities: [],
      hiddenImpacts: [],
    });
    readViolationsStub = sinon.stub(violationsReader, 'readViolations');
  });

  afterEach(() => {
    sinon.restore();
    clearTestConfig();
  });

  // --- FileItem children ---

  it('file node returns violation children from embedded data', async () => {
    // readViolations returns data — normal path
    readViolationsStub.returns({
      violations: [
        { file: 'lib/a.dart', line: 10, rule: 'r1', message: 'msg1', severity: 'warning' },
        { file: 'lib/a.dart', line: 5, rule: 'r2', message: 'msg2', severity: 'warning' },
      ],
      summary: { totalViolations: 2 },
    });
    const provider = new IssuesTreeProvider(new MockMemento() as any);
    const fileNode: IssueTreeNode = {
      kind: 'file',
      severity: 'warning',
      filePath: 'lib/a.dart',
      violations: [
        { file: 'lib/a.dart', line: 10, rule: 'r1', message: 'msg1', severity: 'warning' },
        { file: 'lib/a.dart', line: 5, rule: 'r2', message: 'msg2', severity: 'warning' },
      ],
    };
    const children = await provider.getChildren(fileNode);
    assert.strictEqual(children.length, 2);
    assert.strictEqual(children[0].kind, 'violation');
    assert.strictEqual(children[1].kind, 'violation');
    // Sorted by line — line 5 before line 10
    const v0 = children[0] as IssueTreeNode & { kind: 'violation'; violation: { line: number } };
    const v1 = children[1] as IssueTreeNode & { kind: 'violation'; violation: { line: number } };
    assert.strictEqual(v0.violation.line, 5);
    assert.strictEqual(v1.violation.line, 10);
  });

  it('file node returns children even when violations.json is unavailable (fix: write lock during scan)', async () => {
    // Simulate violations.json being temporarily unreadable — the bug
    // that caused file items to expand to nothing.
    readViolationsStub.returns(null);
    const provider = new IssuesTreeProvider(new MockMemento() as any);
    const fileNode: IssueTreeNode = {
      kind: 'file',
      severity: 'warning',
      filePath: 'lib/a.dart',
      violations: [
        { file: 'lib/a.dart', line: 1, rule: 'r1', message: 'msg', severity: 'warning' },
      ],
    };
    const children = await provider.getChildren(fileNode);
    // Before fix: returned [] because readViolations(null) hit early return.
    // After fix: uses element.violations directly — no disk read needed.
    assert.strictEqual(children.length, 1, 'file node must resolve from embedded data, not disk');
    assert.strictEqual(children[0].kind, 'violation');
  });

  // --- GroupItem children ---

  it('group node returns file children from embedded violations', async () => {
    readViolationsStub.returns({
      violations: [
        { file: 'lib/a.dart', line: 1, rule: 'r1', message: 'm', severity: 'warning', impact: 'high' },
        { file: 'lib/b.dart', line: 2, rule: 'r2', message: 'm', severity: 'warning', impact: 'high' },
      ],
      summary: { totalViolations: 2 },
    });
    const provider = new IssuesTreeProvider(new MockMemento() as any);
    const groupNode: IssueTreeNode = {
      kind: 'group',
      mode: 'impact',
      groupKey: 'high',
      label: 'High',
      count: 2,
      violations: [
        { file: 'lib/a.dart', line: 1, rule: 'r1', message: 'm', severity: 'warning', impact: 'high' },
        { file: 'lib/b.dart', line: 2, rule: 'r2', message: 'm', severity: 'warning', impact: 'high' },
      ],
    };
    const children = await provider.getChildren(groupNode);
    assert.strictEqual(children.length, 2);
    // buildFileItems groups by file — both should be 'file' kind
    assert.ok(children.every(c => c.kind === 'file'));
  });

  it('group node returns file children even when violations.json is unavailable', async () => {
    readViolationsStub.returns(null);
    const provider = new IssuesTreeProvider(new MockMemento() as any);
    const groupNode: IssueTreeNode = {
      kind: 'group',
      mode: 'impact',
      groupKey: 'high',
      label: 'High',
      count: 1,
      violations: [
        { file: 'lib/a.dart', line: 1, rule: 'r1', message: 'm', severity: 'warning', impact: 'high' },
      ],
    };
    const children = await provider.getChildren(groupNode);
    // Before fix: returned [] because readViolations(null) hit early return.
    // After fix: uses element.violations directly.
    assert.strictEqual(children.length, 1, 'group node must resolve from embedded data, not disk');
    assert.strictEqual(children[0].kind, 'file');
  });

  // --- Overflow behavior ---

  it('file node respects page size and adds overflow item', async () => {
    readViolationsStub.returns(null);
    setTestConfig('saropaLints', 'issuesPageSize', 1);
    const provider = new IssuesTreeProvider(new MockMemento() as any);
    const fileNode: IssueTreeNode = {
      kind: 'file',
      severity: 'warning',
      filePath: 'lib/a.dart',
      violations: [
        { file: 'lib/a.dart', line: 1, rule: 'r1', message: 'msg1', severity: 'warning' },
        { file: 'lib/a.dart', line: 2, rule: 'r2', message: 'msg2', severity: 'warning' },
        { file: 'lib/a.dart', line: 3, rule: 'r3', message: 'msg3', severity: 'warning' },
      ],
    };
    const children = await provider.getChildren(fileNode);
    // Page size 1 → 1 violation + 1 overflow ("and 2 more…")
    assert.strictEqual(children.length, 2);
    assert.strictEqual(children[0].kind, 'violation');
    assert.strictEqual(children[1].kind, 'overflow');
  });
});

describe('IssuesTreeProvider permanent help row', () => {
  let readViolationsStub: sinon.SinonStub;

  beforeEach(() => {
    clearTestConfig();
    setTestConfig('saropaLints', 'violationsGroupBy', 'severity');
    sinon.stub(projectRoot, 'getProjectRoot').returns('/fake/root');
    sinon.stub(suppressionsStore, 'loadSuppressions').returns({
      hiddenFolders: [],
      hiddenFiles: [],
      hiddenRules: [],
      hiddenRuleInFile: {},
      hiddenSeverities: [],
      hiddenImpacts: [],
    });
    readViolationsStub = sinon.stub(violationsReader, 'readViolations');
  });

  afterEach(() => {
    sinon.restore();
    clearTestConfig();
  });

  it('prepends kind "help" before severity groups when violations exist (after: stable entry point)', async () => {
    readViolationsStub.returns({
      violations: [
        { file: 'lib/a.dart', line: 1, rule: 'r1', message: 'm', severity: 'warning' },
      ],
      summary: { totalViolations: 1 },
    });
    const provider = new IssuesTreeProvider(new MockMemento() as any);
    const root = await provider.getChildren();
    assert.ok(root.length >= 2, 'expected help row + at least one severity group');
    assert.strictEqual(root[0].kind, 'help');
    assert.strictEqual(root[1].kind, 'severity');
  });

  it('prepends kind "help" before the empty-state placeholder when there are zero violations', async () => {
    readViolationsStub.returns({
      violations: [],
      summary: { totalViolations: 0 },
    });
    const provider = new IssuesTreeProvider(new MockMemento() as any);
    const root = await provider.getChildren();
    assert.strictEqual(root.length, 2);
    assert.strictEqual(root[0].kind, 'help');
    assert.strictEqual((root[1] as IssueTreeNode & { kind: string }).kind, 'placeholder');
  });

  it('getTreeItem(help) wires openHelpHub', () => {
    readViolationsStub.returns(null);
    const provider = new IssuesTreeProvider(new MockMemento() as any);
    const item = provider.getTreeItem({ kind: 'help' });
    assert.strictEqual(item.command?.command, 'saropaLints.openHelpHub');
  });

  it('getChildren(help) returns no children', async () => {
    readViolationsStub.returns({
      violations: [{ file: 'lib/a.dart', line: 1, rule: 'r', message: 'm', severity: 'error' }],
      summary: { totalViolations: 1 },
    });
    const provider = new IssuesTreeProvider(new MockMemento() as any);
    const nested = await provider.getChildren({ kind: 'help' });
    assert.deepStrictEqual(nested, []);
  });
});

/**
 * Regression: clicking an existing-file row in the Violations view did
 * nothing because FileItem only set resourceUri, never the `vscode.open`
 * command. Expectation: when the file exists on disk, getTreeItem('file')
 * attaches a `vscode.open` command; when it doesn't exist (moved/deleted
 * since last analysis), the command must stay unset so we don't surface
 * a "file not found" error to the user.
 */
describe('IssuesTreeProvider file item open-on-click', () => {
  let cachedFileExistsStub: sinon.SinonStub;

  beforeEach(() => {
    sinon.stub(projectRoot, 'getProjectRoot').returns('/fake/root');
    sinon.stub(suppressionsStore, 'loadSuppressions').returns({
      hiddenFolders: [],
      hiddenFiles: [],
      hiddenRules: [],
      hiddenRuleInFile: {},
      hiddenSeverities: [],
      hiddenImpacts: [],
    });
    cachedFileExistsStub = sinon.stub(pathUtils, 'cachedFileExists');
  });

  afterEach(() => {
    sinon.restore();
  });

  it('attaches vscode.open command when file exists on disk', () => {
    cachedFileExistsStub.returns(true);
    const provider = new IssuesTreeProvider(new MockMemento() as any);
    const fileNode: IssueTreeNode = {
      kind: 'file',
      severity: 'warning',
      filePath: 'lib/a.dart',
      violations: [
        { file: 'lib/a.dart', line: 1, rule: 'r', message: 'm', severity: 'warning' },
      ],
    };
    const item = provider.getTreeItem(fileNode);
    // Command must be wired so clicking the row opens the file; previously
    // only resourceUri was set, which meant the click only toggled expand/collapse.
    assert.strictEqual(item.command?.command, 'vscode.open');
    assert.ok(item.command?.arguments && item.command.arguments.length === 1);
  });

  it('omits command when file is missing (moved/deleted since analysis)', () => {
    cachedFileExistsStub.returns(false);
    const provider = new IssuesTreeProvider(new MockMemento() as any);
    const fileNode: IssueTreeNode = {
      kind: 'file',
      severity: 'warning',
      filePath: 'lib/ghost.dart',
      violations: [
        { file: 'lib/ghost.dart', line: 1, rule: 'r', message: 'm', severity: 'warning' },
      ],
    };
    const item = provider.getTreeItem(fileNode);
    // No command — otherwise clicking would surface a confusing
    // "file not found" error. Tooltip explains the stale state instead.
    assert.strictEqual(item.command, undefined);
  });
});
