/**
 * Adds a dev dependency to pubspec.yaml text, without a YAML library and
 * without a `vscode` import, so every shape below is unit-tested.
 *
 * Line-based on purpose: a YAML round trip would reformat the user's file and
 * drop their comments, and this edit is published in a pull request that
 * someone reviews line by line. The rules that keep it valid YAML:
 *
 * - the new entry takes the indentation the existing entries already use
 *   (two spaces is common, four is not rare), since a mismatched sibling is a
 *   parse error;
 * - `dev_dependencies:` is found with or without a trailing comment, since a
 *   second `dev_dependencies:` key is a duplicate pub rejects;
 * - an existing entry is recognised at any indentation, in `dependencies` or
 *   `dev_dependencies`, so it is never declared twice;
 * - line endings (CRLF) and the final newline are kept as they were.
 */

/** Top-level sections whose children are package names. */
const DEPENDENCY_SECTIONS = new Set(['dependencies', 'dev_dependencies']);

/**
 * `content` with `name: version` added under `dev_dependencies`, or undefined
 * when `name` is already a dependency and there is nothing to add.
 */
export function addDevDependency(content: string, name: string, version: string): string | undefined {
  const eol = content.includes('\r\n') ? '\r\n' : '\n';
  const lines = content.split(eol);
  const isTopLevelKey = (line: string): boolean => /^[^\s#]/.test(line);
  const topLevelName = (line: string): string | undefined => /^([A-Za-z_][\w-]*)\s*:/.exec(line)?.[1];

  // Already declared, under either section, at whatever indentation.
  let section: string | undefined;
  for (const line of lines) {
    if (isTopLevelKey(line)) {
      section = topLevelName(line);
      continue;
    }
    if (section && DEPENDENCY_SECTIONS.has(section) && new RegExp(`^\\s+${name}\\s*:`).test(line)) {
      return undefined;
    }
  }

  const headerAt = lines.findIndex((l) => /^dev_dependencies\s*:\s*(\{\s*\})?\s*(#.*)?$/.test(l));
  if (headerAt === -1) {
    // Append a new section, keeping a final newline if the file had one.
    const trailingEmpty = lines.length > 0 && lines[lines.length - 1] === '';
    const body = trailingEmpty ? lines.slice(0, -1) : lines;
    const block = ['dev_dependencies:', `  ${name}: ${version}`];
    const separated = body.length > 0 && body[body.length - 1].trim() !== '' ? ['', ...block] : block;
    return [...body, ...separated, ...(trailingEmpty ? [''] : [])].join(eol);
  }

  // `dev_dependencies: {}` is an empty flow map; it becomes a block map.
  if (/\{\s*\}/.test(lines[headerAt])) {
    lines[headerAt] = lines[headerAt].replace(/\s*\{\s*\}/, '');
  }

  // Indentation of the section's existing entries, or two spaces for none.
  let indent = '  ';
  for (let i = headerAt + 1; i < lines.length; i++) {
    const line = lines[i];
    if (isTopLevelKey(line)) break;
    if (/^\s*(#.*)?$/.test(line)) continue;
    indent = /^[ ]*/.exec(line)![0] || indent;
    break;
  }

  lines.splice(headerAt + 1, 0, `${indent}${name}: ${version}`);
  return lines.join(eol);
}
