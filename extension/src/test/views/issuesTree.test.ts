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
