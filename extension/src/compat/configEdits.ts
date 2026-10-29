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
import { findPluginEntry, splitScalar } from '../analysisOptionsVersion';

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
  const e = findPluginEntry(lines.map(stripEol));
  if (!e) return content;

  if (e.valueLine >= 0) {
    const parts = splitScalar(stripEol(lines[e.valueLine]), e.valueKey);
    if (!parts) return content;
    lines[e.valueLine] = `${parts.prefix}${parts.quote}${version}${parts.quote}${parts.suffix}${eolOf(lines[e.valueLine])}`;
    return lines.join('');
  }

  // No version line: insert as first child, matching existing child indent.
  const indent = ' '.repeat(e.childIndent ?? e.entryIndent + 2);
  let eol = eolOf(lines[e.entry]);
  if (eol === '') {
    // The entry was the unterminated last line; give it a terminator.
    eol = content.includes('\r\n') ? '\r\n' : '\n';
    lines[e.entry] += eol;
  }
  lines.splice(e.entry + 1, 0, `${indent}version: "${version}"${eol}`);
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
