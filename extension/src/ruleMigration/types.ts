/** Shared types for the rule-rename migration (no vscode import). */

/** One registry entry; `new` is null when the rule was removed. */
export interface RenameEntry {
  old: string;
  new: string | null;
  since: string;
  note?: string;
}

/** old name -> final new name (null = removed). Chains are already collapsed. */
export type RenameMap = ReadonlyMap<string, string | null>;

/** Something a rewriter noticed but did not (or could not) change silently. */
export interface Finding {
  /** bareName: old name without `saropa_lints/` in an ignore comment, left alone. clash: old and new keys both present. */
  kind: 'bareName' | 'clash';
  name: string;
  /** 1-based line of the finding. */
  line: number;
}

export interface RewriteResult {
  text: string;
  /** Renames plus removals applied. */
  hits: number;
  findings: Finding[];
}
