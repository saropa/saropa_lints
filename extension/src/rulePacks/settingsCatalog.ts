/**
 * Schema-driven catalog of `saropaLints.*` extension settings for the Rules & Tiers dashboard's
 * "Automation" and "Extension" tabs (Phase 4, PLAN_extension_ui_redesign.md §2.2 / §3 "every
 * `saropaLints.*` setting outside the vibrancy/health/todo/drift groups gets a control").
 *
 * WHY schema-driven instead of a hand-maintained list: a hand-listed catalog is exactly the kind
 * of thing this dashboard exists to stop happening — Phase 4 was commissioned because 8
 * `analysis_options_custom.yaml` keys and dozens of `saropaLints.*` settings had drifted invisible
 * over time. A static per-setting list would just move that drift risk from "no UI" to "UI that
 * silently stops tracking new settings." Instead, {@link buildSettingsCatalog} reads
 * `contributes.configuration` directly from the installed extension's manifest (the SAME source
 * `npm run verify-nls-keys` and VS Code's own Settings UI read) every time the dashboard renders,
 * so a setting added to `package.json` appears here with ZERO code changes in this file.
 *
 * Exclusions are the only hand-maintained part, and they are intentionally small and structural
 * (a key PREFIX, not a per-setting entry): `packageVibrancy.*` (Packages dashboard owns it —
 * PLAN §2.2 Phase 5), `projectVibrancy.*` (Code Health dashboard's own Settings tab), plus
 * `todosAndHacks.*` and `driftAdvisor.*` (out of this phase's scope). `saropaLints.enabled` and
 * `saropaLints.tier` are excluded by exact key — both already have dedicated, behaviorally-rich
 * controls elsewhere (sidebar "Lint integration" row; Tier tab's radio control) that do more than
 * a plain `workspace.getConfiguration().update()` (toggling `enabled` also comments out the
 * analyzer plugin block; setting `tier` offers a re-analysis prompt) — routing them through this
 * generic grid too would silently bypass that behavior from a second control that looks identical
 * but is not.
 */

import * as vscode from 'vscode';
import * as fs from 'node:fs';
import * as path from 'node:path';

/** Manifest package id, used to fetch the resolved (still `%key%`-templated) `packageJSON`. */
const EXTENSION_ID = 'saropa.saropa-lints';

/** Key prefixes owned by another dashboard or out of this phase's scope — see header comment. */
const EXCLUDED_PREFIXES = ['packageVibrancy.', 'projectVibrancy.', 'todosAndHacks.', 'driftAdvisor.'];

/** Exact keys with a dedicated, behaviorally-richer control elsewhere — see header comment. */
const EXCLUDED_EXACT_KEYS = new Set(['enabled', 'tier']);

/** One settings-grid row, derived at render time from a `contributes.configuration` property. */
export interface SettingCatalogEntry {
  /** Suffix after `saropaLints.`, e.g. `runAnalysisAfterConfigChange`. */
  key: string;
  /** Control kind the grid renders, derived from the manifest's JSON-schema `type`/`enum`. */
  kind: 'boolean' | 'number' | 'select' | 'stringArray' | 'text';
  /** Options for `kind: 'select'` (from the manifest's `enum`). */
  options?: readonly string[];
  /** Humanized display label, derived from the dotted key (see {@link humanizeSettingKey}). Not
   * routed through `l10n()`/en.json: it is a mechanical transform of the manifest key itself
   * (never independently authored text), so there is nothing here for a translator to translate
   * that is not already represented by the key — same rationale VS Code's own Settings UI uses
   * for its auto-generated setting titles, which are not localized per-setting either. */
  label: string;
  /** Manifest description (resolved from `package.nls.json`), used as the row's tooltip. */
  description: string;
  /** Which tab renders this row. Every setting defaults to `automation`; `uiLanguage` is the one
   * `extension`-track exception (an extension-wide display preference, not an analyzer behavior). */
  tab: 'automation' | 'extension';
}

/** Minimal shape of one `contributes.configuration.properties` entry this module cares about. */
interface ManifestConfigProperty {
  type?: string | string[];
  enum?: string[];
  default?: unknown;
  description?: string;
  markdownDescription?: string;
}

/** Turns a dotted setting key into the flat identifier used for DOM ids (`a.b` -> `a_b`). */
export function flatSettingKey(key: string): string {
  return key.replace(/\./g, '_');
}

/**
 * Humanizes a dotted/camelCase setting key into a display label — `systemHealth.pollIntervalSeconds`
 * becomes "System Health: Poll Interval Seconds". Mirrors (loosely) how VS Code's own Settings UI
 * derives an auto-title from a key with no explicit `title`, since none of these settings declare one.
 */
export function humanizeSettingKey(key: string): string {
  return key
    .split('.')
    .map((segment) =>
      segment
        // Split camelCase boundaries ("pollInterval" -> "poll Interval") before title-casing.
        .replace(/([a-z0-9])([A-Z])/g, '$1 $2')
        .replace(/^./, (c) => c.toUpperCase())
        .trim(),
    )
    .join(': ');
}

function isExcluded(key: string): boolean {
  if (EXCLUDED_EXACT_KEYS.has(key)) return true;
  return EXCLUDED_PREFIXES.some((prefix) => key.startsWith(prefix));
}

/** Resolves a manifest `%config.property.X.description%` / `%...markdownDescription%` placeholder against `package.nls.json`. Falls back to the raw string when it is not a placeholder (defensive — every current setting uses one, but a future one might not). */
function resolveNlsPlaceholder(raw: string | undefined, nls: Record<string, string>): string {
  if (!raw) return '';
  const match = /^%(.+)%$/.exec(raw.trim());
  if (!match) return raw;
  return nls[match[1]] ?? raw;
}

/** Loads `package.nls.json` (English manifest strings — see `.claude/rules/i18n.md`) from the running extension's install path. Returns `{}` on any failure so a missing/unreadable file degrades to showing the raw `%key%` placeholder rather than throwing. */
function loadPackageNls(): Record<string, string> {
  const ext = vscode.extensions.getExtension(EXTENSION_ID);
  if (!ext) return {};
  try {
    const raw = fs.readFileSync(path.join(ext.extensionPath, 'package.nls.json'), 'utf-8');
    return JSON.parse(raw) as Record<string, string>;
  } catch {
    return {};
  }
}

function controlKindFor(prop: ManifestConfigProperty): SettingCatalogEntry['kind'] {
  const type = Array.isArray(prop.type) ? prop.type[0] : prop.type;
  if (type === 'boolean') return 'boolean';
  if (type === 'number' || type === 'integer') return 'number';
  if (type === 'array') return 'stringArray';
  if (type === 'string' && Array.isArray(prop.enum) && prop.enum.length > 0) return 'select';
  return 'text';
}

/**
 * Builds the settings catalog fresh from the installed extension's manifest. Cheap enough to call
 * on every render (a JSON object already resident in memory via `vscode.extensions.getExtension`,
 * plus one small `package.nls.json` file read) — no caching needed, and caching would risk serving
 * a stale catalog across an extension update within the same VS Code session.
 */
export function buildSettingsCatalog(): SettingCatalogEntry[] {
  const ext = vscode.extensions.getExtension(EXTENSION_ID);
  const configs: unknown = ext?.packageJSON?.contributes?.configuration;
  const nls = loadPackageNls();
  const blocks: Array<{ properties?: Record<string, ManifestConfigProperty> }> = Array.isArray(configs)
    ? configs
    : configs
      ? [configs as { properties?: Record<string, ManifestConfigProperty> }]
      : [];
  const entries: SettingCatalogEntry[] = [];
  for (const block of blocks) {
    for (const [fullKey, prop] of Object.entries(block.properties ?? {})) {
      if (!fullKey.startsWith('saropaLints.')) continue;
      const key = fullKey.slice('saropaLints.'.length);
      if (isExcluded(key)) continue;
      const description = resolveNlsPlaceholder(prop.description ?? prop.markdownDescription, nls);
      entries.push({
        key,
        kind: controlKindFor(prop),
        options: Array.isArray(prop.enum) ? prop.enum : undefined,
        label: humanizeSettingKey(key),
        description,
        // `uiLanguage` is the sole Extension-tab setting today (see header comment); every other
        // in-scope setting defaults to Automation, so a newly-added setting appears there without
        // needing this file to be touched.
        tab: key === 'uiLanguage' ? 'extension' : 'automation',
      });
    }
  }
  return entries.sort((a, b) => a.key.localeCompare(b.key));
}

/** Looks up a catalog entry by its `saropaLints.<key>` suffix — used to validate untrusted postMessage input before writing config. Rebuilds the catalog on each call (see {@link buildSettingsCatalog}'s doc comment) so a key that has since been removed from the manifest can never be written. */
export function findSettingEntry(key: string): SettingCatalogEntry | undefined {
  return buildSettingsCatalog().find((e) => e.key === key);
}
