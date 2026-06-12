/**
 * Read/write `plugins.saropa_lints.rule_packs.enabled` in analysis_options.yaml.
 */

import * as fs from 'node:fs';
import * as path from 'node:path';

const RULE_PACK_BLOCK =
  /^\s{4}rule_packs:\s*\n\s{6}enabled:\s*\n(?:\s{8}-\s+["']?\w+["']?\s*(?:#.*)?\n|\s{8}#.*\n|\s*\n)+/m;
const LEGACY_MIGRATION_PACK_BLOCK =
  /^\s{4}migration_packs:\s*\n\s{6}enabled:\s*\n(?:\s{8}-\s+["']?\w+["']?\s*(?:#.*)?\n|\s{8}#.*\n|\s*\n)+/m;

export function readAnalysisOptionsPath(workspaceRoot: string): string {
  return path.join(workspaceRoot, 'analysis_options.yaml');
}

/** Returns enabled pack ids from analysis_options.yaml, or [] if missing/invalid. */
export function readRulePacksEnabled(workspaceRoot: string): string[] {
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

/** Writes rule_packs block; creates file only if saropa_lints block exists. */
export function writeRulePacksEnabled(workspaceRoot: string, packIds: readonly string[]): boolean {
  const p = readAnalysisOptionsPath(workspaceRoot);
  if (!fs.existsSync(p)) {
    return false;
  }
  try {
    let content = fs.readFileSync(p, 'utf-8');
    // Normalize to canonical key on write: remove legacy alias block if present.
    if (LEGACY_MIGRATION_PACK_BLOCK.test(content)) {
      content = content.replace(LEGACY_MIGRATION_PACK_BLOCK, '');
    }
    const blockBody =
      packIds.length === 0
        ? ''
        : `    rule_packs:\n      enabled:\n${packIds.map((id) => `        - ${id}`).join('\n')}\n`;

    if (RULE_PACK_BLOCK.test(content)) {
      if (packIds.length === 0) {
        content = content.replace(RULE_PACK_BLOCK, '');
      } else {
        content = content.replace(RULE_PACK_BLOCK, blockBody);
      }
    } else if (packIds.length > 0) {
      const inserted = insertRulePacksAfterVersion(content, blockBody);
      if (inserted === null) {
        return false;
      }
      content = inserted;
    }

    fs.writeFileSync(p, content, 'utf-8');
    return true;
  } catch {
    return false;
  }
}

function insertRulePacksAfterVersion(content: string, blockBody: string): string | null {
  // Preferred anchor: insert immediately after the `version:` pin, which is
  // where `dart run saropa_lints:init` places the plugin config for consumer
  // projects, so the rule_packs block lands at the top of that mapping.
  const versioned = /(saropa_lints:\s*\n\s*version:\s*[^\n]+\n)/.exec(content);
  if (versioned) {
    return content.replace(versioned[0], `${versioned[0]}${blockBody}`);
  }
  // Fallback: some configs intentionally omit the version pin — notably the
  // saropa_lints package's own dev analysis_options.yaml, which loads the
  // plugin from workspace source rather than a pub.dev version. Without this
  // branch the write returns null and the user sees "could not write
  // analysis_options.yaml (rule_packs)." Anchor on the `saropa_lints:` mapping
  // key and insert the block as its first child (4-space body under the
  // 2-space key). The `#`-prefixed `saropa_lints:init` comment lines cannot
  // match: they require `saropa_lints:` at the line's leading indent followed
  // by end-of-line, not `:init`.
  const pluginKey = /^[ \t]*saropa_lints:[ \t]*\n/m.exec(content);
  if (!pluginKey) return null;
  return content.replace(pluginKey[0], `${pluginKey[0]}${blockBody}`);
}
