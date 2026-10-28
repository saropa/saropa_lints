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

/** Strip a trailing comment (outside quotes) and surrounding quotes/whitespace. */
function cleanScalar(value: string): string {
  let v = value.trim();
  const quoted = v.match(/^(["'])(.*?)\1/);
  if (quoted) return quoted[2].trim();
  const hash = v.search(/\s#/);
  if (hash >= 0) v = v.slice(0, hash);
  if (v.startsWith('#')) return '';
  return v.trim();
}

function toResult(value: string): ConfiguredPluginVersion | null {
  const raw = cleanScalar(value);
  if (!raw) return null;
  return { raw, isRange: !EXACT_VERSION.test(raw) };
}

/**
 * Extract the `version:` under `plugins: saropa_lints:` from analysis_options
 * content. Also accepts the shorthand `saropa_lints: ^1.2.3`.
 * Returns null for missing content, no plugins block, or no version.
 */
export function readConfiguredPluginVersion(
  content: string | null | undefined,
): ConfiguredPluginVersion | null {
  if (!content) return null;
  const lines = content.split(/\r?\n/);

  let i = 0;
  while (i < lines.length && !/^plugins\s*:\s*(#.*)?$/.test(lines[i])) i++;
  if (i >= lines.length) return null;

  let pluginIndent = -1;
  for (i++; i < lines.length; i++) {
    const line = lines[i];
    if (!line.trim() || line.trim().startsWith('#')) continue;
    const indent = indentOf(line);
    if (indent === 0) return null; // left the plugins block

    if (pluginIndent < 0) pluginIndent = indent;
    if (indent !== pluginIndent) continue;

    const m = line.trim().match(/^["']?saropa_lints["']?\s*:\s*(.*)$/);
    if (!m) continue;

    const inline = m[1].trim();
    if (inline && !inline.startsWith('#')) return toResult(inline);

    for (let j = i + 1; j < lines.length; j++) {
      const child = lines[j];
      if (!child.trim() || child.trim().startsWith('#')) continue;
      if (indentOf(child) <= pluginIndent) return null;
      const v = child.trim().match(/^version\s*:\s*(.*)$/);
      if (v) return toResult(v[1]);
    }
    return null;
  }
  return null;
}
