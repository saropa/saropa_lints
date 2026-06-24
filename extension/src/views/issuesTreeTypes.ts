/**
 * Node types for the Issues tree (severity -> folder -> file -> violation, plus
 * generic group / overflow / placeholder rows). Extracted so the provider class
 * (issuesTree.ts) and the command layer (issuesTreeCommands.ts) share one
 * definition instead of one importing internals from the other.
 */

import { Violation } from '../violationsReader';
import type { GroupByMode } from './issuesTreeGrouping';

/** Discriminated union for all node types in the Issues tree. */
export type IssueTreeNode =
    | SeverityItem
    | FolderItem
    | FileItem
    | ViolationItem
    | OverflowItem
    | PlaceholderItem
    | GroupItem;

/**
 * D10: Generic group header for non-severity grouping modes.
 * Used by impact, rule, and owasp modes. Children are FileItem[]
 * sub-grouped from the violations list.
 */
export interface GroupItem {
  kind: 'group';
  /** Snapshot of groupBy mode at creation time — prevents stale icon if mode changes between render cycles. */
  mode: GroupByMode;
  /** The raw key used for sorting and deduplication (e.g. 'critical', 'm1', rule name). */
  groupKey: string;
  /** Human-readable label shown in the tree (may be title-cased). */
  label: string;
  /** Total violations in this group. */
  count: number;
  /** All violations belonging to this group — sub-grouped by file when expanded. */
  violations: Violation[];
}

export interface SeverityItem {
  kind: 'severity';
  severity: string;
  count: number;
}

export interface FolderItem {
  kind: 'folder';
  severity: string;
  pathPrefix: string;
  segmentName: string;
  count: number;
}

export interface FileItem {
  kind: 'file';
  severity: string;
  filePath: string;
  violations: Violation[];
}

export interface ViolationItem {
  kind: 'violation';
  violation: Violation;
}

export interface OverflowItem {
  kind: 'overflow';
  filePath: string;
  severity: string;
  count: number;
}

export interface PlaceholderItem {
  kind: 'placeholder';
  id: 'loading' | 'no-data' | 'no-match';
  label: string;
  description?: string;
  command?: string;
}
