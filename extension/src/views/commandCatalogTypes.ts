/**
 * Shared types for the command catalog: the category enumeration and the
 * per-command entry shape. Extracted so the entry data files
 * (commandCatalogEntries*.ts) and the registry composer
 * (commandCatalogRegistry.ts) can both depend on the types without a cycle.
 */

/** Categories that group commands in the catalog UI. */
export type CatalogCategory =
  | 'Setup & Configuration'
  | 'Analysis'
  | 'Violations & Filtering'
  | 'Rules & Fixes'
  | 'Reporting & Export'
  | 'Security Posture'
  | 'Code Health'
  | 'Package Vibrancy'
  | 'Package Vibrancy — Filters'
  | 'Package Vibrancy — Updates'
  | 'Package Vibrancy — Registries'
  | 'TODOs & Hacks'
  | 'Drift Advisor'
  | 'Views & Navigation';

export interface CatalogEntry {
  /** VS Code command ID, e.g. 'saropaLints.runAnalysis'. */
  command: string;

  /** Human-readable title shown in the catalog. */
  title: string;

  /** One-liner explaining what this does and when to use it. */
  description: string;

  /** Category for grouping in the catalog. */
  category: CatalogCategory;

  /** Codicon name (without the `$()` wrapper), e.g. 'play'. */
  icon: string;

  /**
   * When true the command is internal-only (triggered programmatically or
   * from context menus) and should appear dimmed in the catalog with a note
   * that it is not meant to be invoked directly.
   */
  internal?: boolean;
}
