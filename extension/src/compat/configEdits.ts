/**
 * Pure text edits that apply a version recommendation to a project's
 * pubspec.yaml and analysis_options.yaml. No I/O: callers read the files,
 * preview the result (analyzerExcludeDiffProvider), then write it.
 *
 * Rules: pubspec constraint is '^' + version; the plugin `version:` is the
 * exact version, never a range; line endings and every untouched line stay
 * byte-identical; a disabled/commented-out plugins block is left alone; a
 * saropa_lints plugin entry with no `version:` line gets one.
 */
import { applyPubspecConstraint } from '../upgrade-checker';
import { findPluginsBlock } from '../setup';

export interface ConfigFiles {
  pubspec?: string;
  analysisOptions?: string;
}

export interface Recommendation {
  /** Version for the pubspec dependency; written as '^' + version. */
  constraint?: string;
  /** Exact version for `plugins: saropa_lints: version:`. */
  pluginVersion?: string;
}

const bare = (v: string): string => v.trim().replace(/^[\^=v\s]+/, '');

/** Lines keep their own terminator, so untouched lines round-trip exactly. */
function splitKeepEol(content: string): string[] {
  return content.match(/[^\n]*\n|[^\n]+$/g) ?? [];
}

function stripEol(line: string): string {
  return line.replace(/\r?\n$/, '');
}

function eolOf(line: string): string {
  return /\r\n$/.test(line) ? '\r\n' : /\n$/.test(line) ? '\n' : '';
}

function applyPluginVersion(content: string, version: string): string {
  const lines = splitKeepEol(content);
  const block = findPluginsBlock(lines.map(stripEol));
  if (!block) return content;

  const entry = lines.findIndex(
    (l, i) => i > block.start && i < block.end && /^  saropa_lints:\s*$/.test(stripEol(l)),
  );
  if (entry === -1) return content;

  // Entry body: following lines indented deeper than 2, plus blank/comment lines.
  let end = entry + 1;
  while (end < block.end) {
    const t = stripEol(lines[end]);
    if (t.trim() === '' || /^\s*#/.test(t) || /^ {3,}\S/.test(t)) end++;
    else break;
  }

  for (let i = entry + 1; i < end; i++) {
    const m = /^(\s+version:\s*)(["']?)[^"'#\s]*\2(.*)$/.exec(stripEol(lines[i]));
    if (m) {
      lines[i] = `${m[1]}${m[2]}${version}${m[2]}${m[3]}${eolOf(lines[i])}`;
      return lines.join('');
    }
  }

  // No version line: insert as first child, matching existing child indent.
  const child = lines
    .slice(entry + 1, end)
    .map((l) => /^( {3,})\S/.exec(stripEol(l)))
    .find((m) => m !== null);
  const indent = child ? child[1] : '    ';
  let eol = eolOf(lines[entry]);
  if (eol === '') {
    // The entry was the unterminated last line; give it a terminator.
    eol = content.includes('\r\n') ? '\r\n' : '\n';
    lines[entry] += eol;
  }
  lines.splice(entry + 1, 0, `${indent}version: "${version}"${eol}`);
  return lines.join('');
}

export function applyRecommendation(files: ConfigFiles, rec: Recommendation): ConfigFiles {
  const out: ConfigFiles = { ...files };
  if (files.pubspec !== undefined && rec.constraint) {
    out.pubspec = applyPubspecConstraint(files.pubspec, bare(rec.constraint)) ?? files.pubspec;
  }
  if (files.analysisOptions !== undefined && rec.pluginVersion) {
    out.analysisOptions = applyPluginVersion(files.analysisOptions, bare(rec.pluginVersion));
  }
  return out;
}
