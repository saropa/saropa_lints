/**
 * Loads the bundled rule-metadata catalog (`media/rules_catalog.json`) that ships
 * with the extension.
 *
 * Why this exists. Live analyzer diagnostics carry no per-rule metadata (rule
 * type, lifecycle status, security-review flag, CWE/CERT ids) — they are just
 * file/line/rule/severity/message. Surfaces that need that metadata (the
 * Issues-panel rule-type/status filters and security-hotspot review) used to get
 * it only from the batch `violations.json` export, which goes stale between runs.
 * This catalog supplies the SAME `ruleMetadataByRule` map for EVERY rule, sourced
 * from the analyzer package itself (`dart run saropa_lints:generate_rule_catalog`),
 * so those surfaces can move to the live source without losing their metadata.
 *
 * The catalog is byte-derived from the rule definitions, so it only changes when
 * rules change; it is loaded once per session and cached. A missing or malformed
 * file degrades to an empty catalog (filters fall back to whatever the live
 * violations themselves carry) rather than throwing — the extension must still
 * activate if the asset is somehow absent.
 */

import * as fs from 'node:fs';
import * as path from 'node:path';
import { type RuleMetadataData } from './violationsReader';

/** On-disk catalog shape written by `bin/generate_rule_catalog.dart`. */
interface RuleCatalogFile {
  schemaVersion?: string;
  ruleCount?: number;
  rules?: Record<string, RuleMetadataData>;
}

/** Rule name → metadata map; same type the export's `ruleMetadataByRule` uses. */
export type RuleCatalog = Record<string, RuleMetadataData>;

/** Bundled location relative to the extension root. */
const CATALOG_RELATIVE_PATH = path.join('media', 'rules_catalog.json');

// Cached after first load. `null` means "not loaded yet"; an empty object is a
// valid loaded-but-missing result and is NOT re-read on every call.
let cachedCatalog: RuleCatalog | null = null;

/**
 * Load and cache the catalog from the extension's bundled asset. Call once at
 * activation with `context.extensionUri.fsPath`. Safe to call again — later calls
 * with the same path return the cache. A read/parse failure logs and caches an
 * empty catalog so callers get a stable, non-throwing result.
 */
export function initRuleCatalog(extensionPath: string): RuleCatalog {
  if (cachedCatalog !== null) return cachedCatalog;
  const filePath = path.join(extensionPath, CATALOG_RELATIVE_PATH);
  try {
    const parsed = JSON.parse(fs.readFileSync(filePath, 'utf-8')) as RuleCatalogFile;
    cachedCatalog = parsed.rules ?? {};
  } catch (err) {
    // Degrade to empty rather than failing activation — the metadata filters
    // simply fall back to whatever the live violations carry on their own.
    console.error(`saropa_lints: could not load rule catalog at ${filePath}:`, err);
    cachedCatalog = {};
  }
  return cachedCatalog;
}

/**
 * The loaded catalog, or an empty map if `initRuleCatalog` has not run yet.
 * Production callers read this after activation; unit tests inject their own map
 * directly into the consumers instead of touching the filesystem.
 */
export function getRuleCatalog(): RuleCatalog {
  return cachedCatalog ?? {};
}

/** Test-only: reset the module cache so a test can re-init with a stub path. */
export function resetRuleCatalogForTest(): void {
  cachedCatalog = null;
}
