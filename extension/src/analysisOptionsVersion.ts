/**
 * Pure parser for the saropa_lints version configured under
 * `plugins: saropa_lints:` in analysis_options.yaml. No vscode/fs
 * dependencies so it is unit-testable in isolation.
 */

export interface ConfiguredPluginVersion {
  /** Version text as written, unquoted and comment-stripped (e.g. `^1.2.3`). */
  raw: string;
  /** True when the value is a constraint (range/operator/any), not an exact version. */
  isRange: boolean;
}

const EXACT_VERSION = /^\d+\.\d+\.\d+(?:[-+][0-9A-Za-z.+-]+)?$/;

function indentOf(line: string): number {
  return line.length - line.trimStart().length;
}

function toResult(value: string): ConfiguredPluginVersion | null {
  const raw = value.trim();
  if (!raw) return null;
  return { raw, isRange: !EXACT_VERSION.test(raw) };
}

/** One `key: value` line split so the value can be read or replaced in place. */
export interface ScalarParts {
  /** Everything before the value (indent, key, colon, spaces). */
  prefix: string;
  /** Quote character around the value, or ''. */
  quote: string;
  /** The value without quotes or trailing comment; '' when absent. */
  value: string;
  /** Everything after the value (spaces and trailing comment). */
  suffix: string;
}

/** Split a `key: value` line (key may be quoted); null when the line is not that key. */
export function splitScalar(line: string, key: string): ScalarParts | null {
  const k = key.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  const re = new RegExp(
    `^(\\s*(?:"${k}"|'${k}'|${k})\\s*:\\s*)(?:(["'])(.*?)\\2|([^"'#\\s][^#]*?))?(\\s*(?:#.*)?)$`,
  );
  const m = re.exec(line);
  if (!m) return null;
  return { prefix: m[1], quote: m[2] ?? '', value: (m[3] ?? m[4] ?? '').trim(), suffix: m[5] };
}

/** Location of the live `plugins: saropa_lints:` entry in analysis_options lines. */
export interface PluginEntry {
  /** Line index of the `saropa_lints:` key. */
  entry: number;
  /** Exclusive end of the entry body. */
  end: number;
  entryIndent: number;
  /** Indent of the entry's first child line, when it has children. */
  childIndent?: number;
  /** True for `saropa_lints: ^1.2.3` (value on the key line). */
  shorthand: boolean;
  /** Line holding the version value, or -1 when there is none. */
  valueLine: number;
  /** Key on valueLine: `saropa_lints` (shorthand) or `version`. */
  valueKey: 'saropa_lints' | 'version';
}

/**
 * Shared parser for the plugin entry: block (`version:` child), shorthand,
 * quoted values, trailing comments. Callers pass lines without terminators.
 * A commented-out or disabled `plugins:` block is not matched.
 */
export function findPluginEntry(lines: string[]): PluginEntry | null {
  let i = lines.findIndex((l) => /^plugins\s*:\s*(#.*)?$/.test(l));
  if (i < 0) return null;

  let pluginIndent = -1;
  for (i++; i < lines.length; i++) {
    const line = lines[i];
    const t = line.trim();
    if (!t || t.startsWith('#')) continue;
    const indent = indentOf(line);
    if (indent === 0) return null; // left the plugins block
    if (pluginIndent < 0) pluginIndent = indent;
    if (indent !== pluginIndent) continue;
    if (!/^["']?saropa_lints["']?\s*:/.test(t)) continue;

    const inline = splitScalar(line, 'saropa_lints');
    if (inline && inline.value) {
      return { entry: i, end: i + 1, entryIndent: indent, shorthand: true, valueLine: i, valueKey: 'saropa_lints' };
    }

    let end = i + 1;
    let childIndent: number | undefined;
    let valueLine = -1;
    for (; end < lines.length; end++) {
      const child = lines[end];
      const ct = child.trim();
      if (!ct || ct.startsWith('#')) continue;
      const ci = indentOf(child);
      if (ci <= indent) break;
      childIndent ??= ci;
      if (valueLine < 0 && ci === childIndent && splitScalar(child, 'version')) valueLine = end;
    }
    return { entry: i, end, entryIndent: indent, childIndent, shorthand: false, valueLine, valueKey: 'version' };
  }
  return null;
}

/**
 * Extract the version under `plugins: saropa_lints:` from analysis_options
 * content (block `version:` or shorthand `saropa_lints: ^1.2.3`).
 * Returns null for missing content, no plugins block, or no version.
 */
export function readConfiguredPluginVersion(
  content: string | null | undefined,
): ConfiguredPluginVersion | null {
  if (!content) return null;
  const lines = content.split(/\r?\n/);
  const e = findPluginEntry(lines);
  if (!e || e.valueLine < 0) return null;
  const parts = splitScalar(lines[e.valueLine], e.valueKey);
  return parts ? toResult(parts.value) : null;
}
