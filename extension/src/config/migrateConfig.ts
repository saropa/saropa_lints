/**
 * Migrates `log_level`, `lane`, `memory_mode`, and `rule_packs` from the
 * legacy `plugins > saropa_lints:` block in `analysis_options.yaml` to
 * top-level keys in `analysis_options_custom.yaml`.
 *
 * Eliminates false `unsupported_option` warnings from the Dart SDK's
 * plugin-block validator, which hardcodes allowed keys.
 *
 * Surfaced in the sidebar (Config > Migrate config keys), the command palette
 * (`Saropa Lints: Migrate Config Keys`), and the CLI
 * (`dart run saropa_lints migrate-config`).
 */
import * as fs from 'node:fs';
import * as path from 'node:path';
import * as vscode from 'vscode';
import { parseLaneFromPluginBlock } from './laneConfig';
import { parseRulePacksEnabled, removeLegacyRulePacksFromMainFile, writeRulePacksEnabled } from '../rulePacks/rulePackYaml';

/** Keys that were moved from the plugin block to the custom file. */
const MIGRATE_KEYS = ['log_level', 'lane', 'memory_mode'] as const;

/** Counts leading whitespace (spaces and tabs). */
function leadingWhitespace(value: string): number {
  let count = 0;
  while (count < value.length && (value[count] === ' ' || value[count] === '\t')) count++;
  return count;
}

/**
 * Reads a scalar value from `plugins > saropa_lints:` block.
 * Mirrors Dart's `parseScalarFromPluginBlock` for the specific migrate keys.
 */
function parseScalarFromPluginBlock(content: string, key: string): string | undefined {
  const lines = content.replace(/\r\n/g, '\n').replace(/\r/g, '\n').split('\n');
  for (let i = 0; i < lines.length; i++) {
    const trimmed = lines[i].replace(/\s+$/, '');
    if (!/^\s+saropa_lints:\s*(#.*)?$/.test(trimmed)) continue;
    const baseIndent = leadingWhitespace(lines[i]);
    for (let j = i + 1; j < lines.length; j++) {
      const inner = lines[j];
      const t = inner.replace(/^\s+/, '');
      if (t.length === 0 || t.startsWith('#')) continue;
      const ind = leadingWhitespace(inner);
      if (ind <= baseIndent) break;
      const re = new RegExp(`^\\s*${key}:\\s*([^\\s#]+)`);
      const m = re.exec(inner);
      if (m) {
        const v = m[1]?.trim();
        if (!v) continue;
        return v.replace(/^['"]|['"]$/g, '').toLowerCase();
      }
    }
  }
  return undefined;
}

/** Result of a migration attempt. */
export interface MigrateResult {
  /** Keys that were successfully moved. */
  moved: string[];
  /** Keys that were already in the custom file (skipped). */
  skipped: string[];
  /** True when --dry-run was used (no files were modified). */
  dryRun?: boolean;
  /** Error message if the operation failed entirely. */
  error?: string;
}

/**
 * Runs the migration: reads legacy keys from the plugin block, adds them
 * to the custom file, removes them from the main file.
 *
 * Pass `dryRun: true` to preview changes without modifying any files.
 */
export function migrateConfigKeys(root: string, { dryRun = false } = {}): MigrateResult {
  const mainPath = path.join(root, 'analysis_options.yaml');
  if (!fs.existsSync(mainPath)) {
    return { moved: [], skipped: [], error: 'analysis_options.yaml not found' };
  }

  const mainContent = fs.readFileSync(mainPath, 'utf8');
  const customPath = path.join(root, 'analysis_options_custom.yaml');

  // Find which keys exist in the old plugin block.
  const found = new Map<string, string>();
  for (const key of MIGRATE_KEYS) {
    const value = parseScalarFromPluginBlock(mainContent, key);
    if (value !== undefined) {
      found.set(key, value);
    }
  }

  if (found.size === 0) {
    return { moved: [], skipped: [] };
  }

  // Read or create the custom file.
  let customContent = '';
  try {
    customContent = fs.readFileSync(customPath, 'utf8');
  } catch {
    // File doesn't exist yet — will create.
  }

  const moved: string[] = [];
  const skipped: string[] = [];

  for (const [key, value] of found) {
    // Skip if already present as a top-level key in the custom file.
    if (new RegExp(`^${key}:\\s`, 'm').test(customContent)) {
      skipped.push(key);
      continue;
    }
    // Append the key.
    if (customContent.length > 0 && !customContent.endsWith('\n')) {
      customContent += '\n';
    }
    customContent += `${key}: ${value}\n`;
    moved.push(key);
  }

  // Write the custom file with the scalar keys (only if any were added).
  const scalarKeysChanged = moved.length > 0;
  if (scalarKeysChanged && !dryRun) {
    fs.writeFileSync(customPath, customContent, 'utf8');
  }

  // Remove ALL found scalar keys from the main file's plugin block — even
  // skipped ones — so the unsupported_option warning is eliminated.
  if (found.size > 0 && !dryRun) {
    let updatedMain = mainContent;
    for (const key of found.keys()) {
      updatedMain = updatedMain.replace(
        new RegExp(`^[ \\t]+${key}:\\s+[^\\n]*\\n`, 'm'),
        '',
      );
    }
    if (updatedMain !== mainContent) {
      fs.writeFileSync(mainPath, updatedMain, 'utf8');
    }
  }

  // Migrate rule_packs (nested block) from the plugin block to custom file.
  const rulePackIds = parseRulePacksEnabled(mainContent);
  if (rulePackIds.length > 0) {
    // Check if rule_packs already exists in the custom file.
    const latestCustom = fs.existsSync(customPath)
      ? fs.readFileSync(customPath, 'utf8')
      : '';
    if (/^rule_packs:\s/m.test(latestCustom)) {
      skipped.push('rule_packs');
    } else {
      // writeRulePacksEnabled writes to custom file and cleans up main file.
      if (!dryRun) {
        writeRulePacksEnabled(root, rulePackIds);
      }
      moved.push('rule_packs');
    }
    // Even if rule_packs was skipped (already in custom file), clean up the
    // legacy block from the main file to stop the warning.
    if (!moved.includes('rule_packs') && !dryRun) {
      // removeLegacyRulePacksFromMainFile is called by writeRulePacksEnabled
      // when it runs; only need manual cleanup for the skip path.
      removeLegacyRulePacksFromMainFile(root);
    }
  }

  return { moved, skipped, dryRun: dryRun || undefined };
}

/**
 * VS Code command handler for `saropaLints.migrateConfig`.
 * Shows a progress toast and reports results.
 */
export async function runMigrateConfig(root: string | undefined): Promise<void> {
  if (!root) {
    void vscode.window.showWarningMessage(
      'No Dart project root found. Open a project with analysis_options.yaml first.',
    );
    return;
  }

  const result = migrateConfigKeys(root);

  if (result.error) {
    void vscode.window.showErrorMessage(`Config migration failed: ${result.error}`);
    return;
  }

  if (result.moved.length === 0 && result.skipped.length === 0) {
    void vscode.window.showInformationMessage(
      'Nothing to migrate — no legacy config keys found under plugins > saropa_lints:',
    );
    return;
  }

  if (result.moved.length === 0) {
    void vscode.window.showInformationMessage(
      `All keys already migrated (${result.skipped.join(', ')}).`,
    );
    return;
  }

  void vscode.window.showInformationMessage(
    `Migrated ${result.moved.join(', ')} to analysis_options_custom.yaml. ` +
    `The unsupported_option warnings will no longer appear.`,
  );
}
