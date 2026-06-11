/**
 * Pure, proactive config-suggestion detection (no `vscode`, no I/O side effects
 * beyond reading the project's pubspec / analysis_options).
 *
 * Unlike the violation-driven {@link SuggestionsTreeProvider} (which returns
 * nothing until `dart analyze` has produced violations.json and only surfaces a
 * pack when ≥2 related rules cluster), this module answers a different question:
 * "given only the project's dependency + config files, what config action is the
 * user not seeing?" It is what powers the badge + dedicated Suggestions view, so
 * the otherwise-invisible `init` step and unused-but-applicable rule packs become
 * visible without running anything first.
 *
 * Returns STRUCTURED data, not display strings — the tree provider localizes each
 * item through `l10n()`. Keeping strings out of this module makes it unit-testable
 * without the i18n runtime and keeps every user-facing label in the catalog.
 */

import * as fs from 'node:fs';
import * as path from 'node:path';

import { hasSaropaLintsDep } from '../pubspecReader';
import {
  RULE_PACK_DEFINITIONS,
  isPackDetected,
  type RulePackDefinition,
} from '../rulePacks/rulePackDefinitions';
import {
  readAnalysisOptionsPath,
  readRulePacksEnabled,
} from '../rulePacks/rulePackYaml';

/** Discriminator for how a suggestion should be rendered and acted on. */
export type ConfigSuggestionKind = 'init-missing' | 'pack-available';

/** One actionable config suggestion. Display strings are built by the provider. */
export interface ConfigSuggestion {
  readonly kind: ConfigSuggestionKind;
  /** Stable identity for de-dup / test assertions (e.g. the pack id). */
  readonly id: string;
  /** Pack id when [kind] is 'pack-available' (the argument for enable). */
  readonly packId?: string;
  /** Human pack label when [kind] is 'pack-available'. */
  readonly packLabel?: string;
  /** Rule count the pack would add (for the item description). */
  readonly ruleCount?: number;
}

/** Reads pubspec.yaml content, or '' when absent/unreadable. */
function readPubspecContent(root: string): string {
  const p = path.join(root, 'pubspec.yaml');
  try {
    return fs.existsSync(p) ? fs.readFileSync(p, 'utf-8') : '';
  } catch {
    return '';
  }
}

/**
 * True when analysis_options.yaml exists AND wires up the saropa_lints plugin.
 *
 * A bare pubspec dependency on saropa_lints does not configure the analyzer —
 * the `plugins: saropa_lints:` (or legacy top-level `saropa_lints:`) block does.
 * We treat a missing block as "init never run", which is the exact gap behind
 * "init is a hidden command I never see".
 */
function hasSaropaLintsConfigured(root: string): boolean {
  const p = readAnalysisOptionsPath(root);
  if (!fs.existsSync(p)) return false;
  try {
    const content = fs.readFileSync(p, 'utf-8');
    // Match the plugin key as a mapping entry (indented), not a substring of a
    // comment or path, so a commented-out reference does not read as configured.
    return /^\s+saropa_lints:\s*(?:#.*)?$/m.test(content);
  } catch {
    return false;
  }
}

/**
 * A pack is only proactively suggestable when its applicability is verifiable
 * from the pubspec alone. {@link isPackDetected} fully resolves sdkGate packs,
 * but cannot check a `dependencyGate` semver lower bound — so a version-migration
 * pack (dio_5, bloc_8, …) would be suggested even on the old major. Those are
 * already handled by the dedicated upgrade-pack nudge, so we exclude
 * dependencyGate packs here to avoid double-surfacing and false positives.
 */
function isProactivelySuggestable(
  def: RulePackDefinition,
  pubspecContent: string,
): boolean {
  if (def.dependencyGate) return false;
  return isPackDetected(def, pubspecContent);
}

/**
 * Computes the proactive config suggestions for [root].
 *
 * Order: init-missing first (it gates everything else — without a plugin block
 * no rule runs), then applicable-but-disabled packs sorted by label for stable
 * display and test output.
 *
 * Returns [] when saropa_lints is not even a dependency (nothing to suggest) so
 * the badge stays hidden in unrelated projects.
 */
export function computeConfigSuggestions(root: string): ConfigSuggestion[] {
  if (!hasSaropaLintsDep(root)) return [];

  const suggestions: ConfigSuggestion[] = [];

  // Surfacing the hidden init step is the whole point — list it first.
  if (!hasSaropaLintsConfigured(root)) {
    suggestions.push({ kind: 'init-missing', id: 'init-missing' });
    // When unconfigured there are no enabled packs to compare against; the only
    // actionable step is to run init, so stop here rather than also listing
    // every applicable pack (which init itself will offer to enable).
    return suggestions;
  }

  const pubspecContent = readPubspecContent(root);
  const enabled = new Set(readRulePacksEnabled(root));

  const available = RULE_PACK_DEFINITIONS.filter(
    (def) => !enabled.has(def.id) && isProactivelySuggestable(def, pubspecContent),
  ).sort((a, b) => a.label.localeCompare(b.label));

  for (const def of available) {
    suggestions.push({
      kind: 'pack-available',
      id: def.id,
      packId: def.id,
      packLabel: def.label,
      ruleCount: def.ruleCodes.length,
    });
  }

  return suggestions;
}

/** Count without building the array twice (used for the view badge). */
export function countConfigSuggestions(root: string): number {
  return computeConfigSuggestions(root).length;
}
