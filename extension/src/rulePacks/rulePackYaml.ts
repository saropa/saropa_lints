/**
 * Read/write `rule_packs.enabled` in analysis_options_custom.yaml (canonical)
 * with deprecation fallback to the old plugin-block location in
 * analysis_options.yaml.
 */

import * as fs from 'node:fs';
import * as path from 'node:path';

/**
 * Pattern matching a top-level `rule_packs:` block in the custom file.
 * Only matches indented children (at least one leading space) so it cannot
 * eat into the next section's unindented comments or headers.
 */
const TOP_LEVEL_RULE_PACK_BLOCK =
  /^rule_packs:\s*\n(?:\s+\S[^\n]*\n)*/m;

/** Pattern matching an indented `rule_packs:` block inside the plugin block. */
const PLUGIN_RULE_PACK_BLOCK =
  /^\s{4}rule_packs:\s*\n\s{6}enabled:\s*\n(?:\s{8}-\s+["']?\w+["']?\s*(?:#.*)?\n|\s{8}#.*\n|\s*\n)+/m;
const LEGACY_MIGRATION_PACK_BLOCK =
  /^\s{4}migration_packs:\s*\n\s{6}enabled:\s*\n(?:\s{8}-\s+["']?\w+["']?\s*(?:#.*)?\n|\s{8}#.*\n|\s*\n)+/m;

export function readAnalysisOptionsPath(workspaceRoot: string): string {
  return path.join(workspaceRoot, 'analysis_options.yaml');
}

/** Path to the custom overrides file. */
function customFilePath(workspaceRoot: string): string {
  return path.join(workspaceRoot, 'analysis_options_custom.yaml');
}

/**
 * Returns enabled pack ids, reading from the custom file first (canonical),
 * falling back to the old plugin-block location in analysis_options.yaml.
 */
export function readRulePacksEnabled(workspaceRoot: string): string[] {
  // Try the custom file first (new canonical location).
  const cp = customFilePath(workspaceRoot);
  if (fs.existsSync(cp)) {
    try {
      const content = fs.readFileSync(cp, 'utf-8');
      // If the custom file contains a `rule_packs:` key at all (even with an
      // empty enabled list), treat it as canonical — don't fall back to the
      // legacy plugin-block location, which could resurrect stale pack ids.
      if (/^rule_packs:\s/m.test(content)) {
        return parseRulePacksEnabled(content);
      }
    } catch {
      // Fall through to legacy location.
    }
  }
  // Fallback: old plugin-block location in analysis_options.yaml.
  const p = readAnalysisOptionsPath(workspaceRoot);
  if (!fs.existsSync(p)) return [];
  try {
    const content = fs.readFileSync(p, 'utf-8');
    return parseRulePacksEnabled(content);
  } catch {
    return [];
  }
}

export function parseRulePacksEnabled(content: string): string[] {
  const normalized = content.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  const primary = parseEnabledListForKey(normalized, 'rule_packs');
  if (primary.length > 0) return primary;
  return parseEnabledListForKey(normalized, 'migration_packs');
}

function parseEnabledListForKey(content: string, key: string): string[] {
  const lines = content.split('\n');
  const keyPattern = new RegExp(`^\\s*${escapeRegex(key)}:\\s*(?:#.*)?$`);
  const enabledPattern = /^\s*enabled:\s*(?:#.*)?$/;
  const itemPattern = /^\s*-\s*["']?([A-Za-z0-9_]+)["']?\s*(?:#.*)?$/;

  for (let i = 0; i < lines.length; i += 1) {
    const line = lines[i];
    if (!keyPattern.test(line)) continue;
    const keyIndent = leadingSpaces(line);

    let enabledIndex = -1;
    let enabledIndent = -1;
    for (let j = i + 1; j < lines.length; j += 1) {
      const next = lines[j];
      const trimmed = next.trim();
      if (trimmed.length === 0 || trimmed.startsWith('#')) continue;
      const indent = leadingSpaces(next);
      if (indent <= keyIndent) break;
      if (enabledPattern.test(next)) {
        enabledIndex = j;
        enabledIndent = indent;
      }
      break;
    }
    if (enabledIndex < 0) continue;

    const ids: string[] = [];
    for (let k = enabledIndex + 1; k < lines.length; k += 1) {
      const row = lines[k];
      const trimmed = row.trim();
      if (trimmed.length === 0 || trimmed.startsWith('#')) continue;
      const indent = leadingSpaces(row);
      if (indent <= enabledIndent) break;
      const match = row.match(itemPattern);
      if (match?.[1]) ids.push(match[1]);
    }
    return ids;
  }
  return [];
}

function leadingSpaces(value: string): number {
  let count = 0;
  while (count < value.length && value.charCodeAt(count) === 32) {
    count += 1;
  }
  return count;
}

function escapeRegex(value: string): string {
  return value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

/**
 * Writes rule_packs to analysis_options_custom.yaml (top-level key).
 *
 * Removes any legacy block from analysis_options.yaml if present.
 */
export function writeRulePacksEnabled(workspaceRoot: string, packIds: readonly string[]): boolean {
  const cp = customFilePath(workspaceRoot);
  try {
    let content = fs.existsSync(cp) ? fs.readFileSync(cp, 'utf-8') : '';

    // Build the new top-level block.
    const block = packIds.length === 0
      ? ''
      : `rule_packs:\n  enabled:\n${packIds.map((id) => `    - ${id}`).join('\n')}\n`;

    if (TOP_LEVEL_RULE_PACK_BLOCK.test(content)) {
      // Replace existing block in custom file.
      if (packIds.length === 0) {
        content = content.replace(TOP_LEVEL_RULE_PACK_BLOCK, '');
      } else {
        content = content.replace(TOP_LEVEL_RULE_PACK_BLOCK, block);
      }
    } else if (packIds.length > 0) {
      // Append to custom file — before platforms section if present.
      const platformMatch = /^(?:# PLATFORM SETTINGS|platforms:)/m.exec(content);
      if (platformMatch) {
        content = content.slice(0, platformMatch.index) + block + '\n' + content.slice(platformMatch.index);
      } else {
        // Append at end.
        if (content.length > 0 && !content.endsWith('\n')) content += '\n';
        content += block;
      }
    }

    // Remove commented-out template lines that a live block replaces.
    // Stops at the first blank line so it cannot eat into the next section.
    if (packIds.length > 0) {
      content = content.replace(/^# RULE PACKS\n(?:#[^\n]*\n)*(?:\n)?/m, '');
    }

    fs.writeFileSync(cp, content, 'utf-8');

    // Clean up legacy block from analysis_options.yaml if present.
    removeLegacyRulePacksFromMainFile(workspaceRoot);

    return true;
  } catch {
    return false;
  }
}

/**
 * Removes the legacy `rule_packs:` / `migration_packs:` block from the
 * plugin section in analysis_options.yaml (cleanup after migration).
 */
export function removeLegacyRulePacksFromMainFile(workspaceRoot: string): void {
  const p = readAnalysisOptionsPath(workspaceRoot);
  if (!fs.existsSync(p)) return;
  try {
    let content = fs.readFileSync(p, 'utf-8');
    let changed = false;
    if (PLUGIN_RULE_PACK_BLOCK.test(content)) {
      content = content.replace(PLUGIN_RULE_PACK_BLOCK, '');
      changed = true;
    }
    if (LEGACY_MIGRATION_PACK_BLOCK.test(content)) {
      content = content.replace(LEGACY_MIGRATION_PACK_BLOCK, '');
      changed = true;
    }
    if (changed) {
      fs.writeFileSync(p, content, 'utf-8');
    }
  } catch {
    // Best-effort cleanup — don't fail the write.
  }
}
