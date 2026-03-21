/**
 * Read/write `plugins.saropa_lints.rule_packs.enabled` in analysis_options.yaml.
 */

import * as fs from 'node:fs';
import * as path from 'node:path';

const RULE_PACK_BLOCK = /^\s{4}rule_packs:\s*\n\s{6}enabled:\s*\n(?:\s{8}-\s+\w+\s*\n)+/m;

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
  const m = normalized.match(
    /rule_packs:\s*\n\s*enabled:\s*\n((?:\s+-\s+\w+\s*\n)+)/m,
  );
  if (!m || m.length < 2) return [];
  const block = m[1];
  const ids: string[] = [];
  const re = /-\s+(\w+)/g;
  let x: RegExpExecArray | null;
  while ((x = re.exec(block)) !== null) {
    ids.push(x[1]);
  }
  return ids;
}

/** Writes rule_packs block; creates file only if saropa_lints block exists. */
export function writeRulePacksEnabled(workspaceRoot: string, packIds: readonly string[]): boolean {
  const p = readAnalysisOptionsPath(workspaceRoot);
  if (!fs.existsSync(p)) {
    return false;
  }
  try {
    let content = fs.readFileSync(p, 'utf-8');
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
  const m = /(saropa_lints:\s*\n\s*version:\s*[^\n]+\n)/.exec(content);
  if (!m) return null;
  return content.replace(m[0], `${m[1]}${blockBody}`);
}
