/**
 * I2: Read/write rule overrides in analysis_options_custom.yaml.
 * Modifies only the RULE OVERRIDES section; other sections are untouched.
 */

import * as fs from 'fs';
import * as path from 'path';

const CUSTOM_FILENAME = 'analysis_options_custom.yaml';
const OVERRIDES_MARKER = '# RULE OVERRIDES';

const OVERRIDES_SECTION_HEADER = `
# ${'\u2500'.repeat(77)}
# RULE OVERRIDES
# ${'\u2500'.repeat(77)}
# FORMAT: rule_name: true/false
# Add your custom rule overrides below:

`;

/** Regex to match a rule entry: `rule_name: true` or `rule_name: false`. */
function ruleEntryPattern(ruleName: string): RegExp {
  return new RegExp(`^(\\s*${ruleName}:\\s*)(true|false)`, 'm');
}

/** Read rule overrides from the RULE OVERRIDES section. */
export function readRuleOverrides(root: string): Map<string, boolean> {
  const filePath = path.join(root, CUSTOM_FILENAME);
  const overrides = new Map<string, boolean>();
  if (!fs.existsSync(filePath)) return overrides;

  const content = fs.readFileSync(filePath, 'utf-8');
  const markerIdx = content.indexOf(OVERRIDES_MARKER);
  if (markerIdx < 0) return overrides;

  // Only parse lines after the marker to avoid matching platform/package entries.
  const section = content.slice(markerIdx);
  const entryPattern = /^\s*([\w_]+):\s*(true|false)/gm;
  let match: RegExpExecArray | null;
  while ((match = entryPattern.exec(section)) !== null) {
    overrides.set(match[1], match[2] === 'true');
  }
  return overrides;
}

/** Count rules explicitly set to false in overrides. */
export function countDisabledOverrides(root: string): number {
  let count = 0;
  for (const enabled of readRuleOverrides(root).values()) {
    if (!enabled) count += 1;
  }
  return count;
}

export interface RuleOverride {
  rule: string;
  enabled: boolean;
}

/**
 * Write rule overrides to the RULE OVERRIDES section.
 * Updates existing entries within the overrides section in-place;
 * appends new entries at end of file. Does not modify stylistic or other sections.
 */
export function writeRuleOverrides(root: string, overrides: RuleOverride[]): void {
  if (overrides.length === 0) return;

  const filePath = path.join(root, CUSTOM_FILENAME);
  let content = fs.existsSync(filePath) ? fs.readFileSync(filePath, 'utf-8') : '';

  // Ensure the RULE OVERRIDES section exists.
  if (!content.includes(OVERRIDES_MARKER)) {
    content = content.trimEnd() + '\n' + OVERRIDES_SECTION_HEADER;
  }

  const markerIdx = content.indexOf(OVERRIDES_MARKER);
  const before = content.slice(0, markerIdx);
  let after = content.slice(markerIdx);

  for (const { rule, enabled } of overrides) {
    const pattern = ruleEntryPattern(rule);
    const value = enabled ? 'true' : 'false';
    if (pattern.test(after)) {
      // Update existing entry within the overrides section.
      after = after.replace(pattern, `$1${value}`);
    } else {
      // Append new entry at end of overrides section (end of file).
      after = after.trimEnd() + `\n${rule}: ${value}\n`;
    }
  }

  fs.writeFileSync(filePath, before + after, 'utf-8');
}

/**
 * Remove rule overrides (revert to tier default).
 * Only removes entries in the RULE OVERRIDES section to avoid modifying
 * stylistic or other sections that use the same key: value format.
 */
export function removeRuleOverrides(root: string, ruleNames: string[]): void {
  if (ruleNames.length === 0) return;

  const filePath = path.join(root, CUSTOM_FILENAME);
  if (!fs.existsSync(filePath)) return;

  const content = fs.readFileSync(filePath, 'utf-8');
  const markerIdx = content.indexOf(OVERRIDES_MARKER);
  if (markerIdx < 0) return; // No overrides section — nothing to remove.

  // Only modify lines after the RULE OVERRIDES marker.
  const before = content.slice(0, markerIdx);
  let after = content.slice(markerIdx);
  for (const rule of ruleNames) {
    const linePattern = new RegExp(`^\\s*${rule}:\\s*(true|false).*\\n?`, 'm');
    after = after.replace(linePattern, '');
  }
  fs.writeFileSync(filePath, before + after, 'utf-8');
}
