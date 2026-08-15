import * as fs from 'fs';
import * as path from 'path';

/**
 * Reads the project's configured lint tier from `analysis_options.yaml`
 * (`plugins.saropa_lints.runtime_tier` / `saropa_tier`).
 *
 * `analysis_options.yaml` is the source of truth for tier — the VS Code
 * `saropaLints.tier` setting and the daemon `--tier` launch flag must defer
 * to this, not the other way around. Prior drift among those independent
 * copies (VS Code setting said `professional`, the yaml said `essential`
 * after an accidental regeneration, git had `recommended`) caused a real
 * incident in a user's live project — see
 * `docs/handover/20260815_1500_progress_bar_fix_and_contacts_recovery.md`.
 * Mirrors the regex-based block scan in
 * `lib/src/config/runtime_tier_cap.dart`'s `parseSaropaTierFromPluginBlock`
 * so both sides agree on what counts as "configured".
 */
export function readTierFromAnalysisOptionsYaml(root: string): string | null {
  const filePath = path.join(root, 'analysis_options.yaml');
  if (!fs.existsSync(filePath)) return null;
  let content: string;
  try {
    content = fs.readFileSync(filePath, 'utf8');
  } catch {
    return null;
  }
  return parseTierFromPluginBlock(content);
}

const VALID_TIERS = new Set(['essential', 'recommended', 'professional', 'comprehensive', 'pedantic']);

function leadingSpaces(value: string): number {
  let count = 0;
  while (count < value.length && value[count] === ' ') count++;
  return count;
}

function stripYamlScalarQuotes(raw: string): string {
  if (raw.length < 2) return raw;
  const first = raw[0];
  const last = raw[raw.length - 1];
  if ((first === "'" && last === "'") || (first === '"' && last === '"')) {
    return raw.slice(1, -1);
  }
  return raw;
}

/** `runtime_tier` / `saropa_tier` under `plugins.saropa_lints`. */
function parseTierFromPluginBlock(content: string): string | null {
  const lines = content.replace(/\r\n/g, '\n').replace(/\r/g, '\n').split('\n');
  for (let i = 0; i < lines.length; i++) {
    const trimmed = lines[i].replace(/\s+$/, '');
    if (!/^\s+saropa_lints:\s*(#.*)?$/.test(trimmed)) continue;
    const baseIndent = leadingSpaces(lines[i]);
    for (let j = i + 1; j < lines.length; j++) {
      const inner = lines[j];
      const t = inner.replace(/^\s+/, '');
      if (t.length === 0 || t.startsWith('#')) continue;
      const ind = leadingSpaces(inner);
      if (ind <= baseIndent) break;
      const m = /^\s*(runtime_tier|saropa_tier):\s*([^\s#]+)/.exec(inner);
      if (m) {
        const v = m[2]?.trim();
        if (!v) continue;
        const label = stripYamlScalarQuotes(v).toLowerCase();
        return VALID_TIERS.has(label) ? label : null;
      }
    }
  }
  return null;
}
