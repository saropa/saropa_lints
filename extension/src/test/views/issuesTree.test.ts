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

import { IssuesTreeProvider, type IssueTreeNode } from '../../views/issuesTree';

/** Minimal Memento mock matching vscode.Memento. */
class MockMemento {
  private store = new Map<string, unknown>();
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
  let getProjectRootStub: sinon.SinonStub;
  let loadSuppressionsStub: sinon.SinonStub;

  beforeEach(() => {
    // Stub getProjectRoot to return a fake path so getTreeItem doesn't blow up.
    getProjectRootStub = sinon.stub(projectRoot, 'getProjectRoot').returns('/fake/root');
    // Stub loadSuppressions so the constructor doesn't fail.
    loadSuppressionsStub = sinon.stub(suppressionsStore, 'loadSuppressions').returns({
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
