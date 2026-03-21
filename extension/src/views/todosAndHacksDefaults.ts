/**
 * Default configuration values for the **TODOs & Hacks** tree view (`saropaLints.todosAndHacks.*`).
 *
 * These fallbacks are used when `vscode.workspace.getConfiguration(...).get(key, default)` has no
 * workspace/user value. They **must** stay in sync with `package.json` → `contributes.configuration`
 * → `saropaLints.todosAndHacks.*` defaults so that first-run behavior matches documented settings.
 *
 * Include globs: defaults target source and config files (Dart, YAML, TS, JS). Markdown is not
 * included by default: READMEs and docs often contain task-marker words in prose, which floods the
 * view. Users who want Markdown scanned can add a glob such as `**` + `/*.md` to
 * `saropaLints.todosAndHacks.includeGlobs` (see setting description in package.json).
 *
 * @module views/todosAndHacksDefaults
 */

/** Fallback when `includeGlobs` is unset; must match `package.json` default for the same key. */
export const DEFAULT_TODOS_AND_HACKS_INCLUDE_GLOBS: readonly string[] = [
  '**/*.dart',
  '**/*.yaml',
  '**/*.ts',
  '**/*.js',
];

/** Tags to search for when `tags` is unset; must match `package.json` default. */
export const DEFAULT_TODOS_AND_HACKS_TAGS: readonly string[] = [
  'TODO',
  'FIXME',
  'HACK',
  'XXX',
  'BUG',
];

/** Extra exclude globs when `excludeGlobs` is unset; must match `package.json` default. */
export const DEFAULT_TODOS_AND_HACKS_EXCLUDE_GLOBS: readonly string[] = [
  '**/node_modules/**',
  '**/.dart_tool/**',
  '**/build/**',
  '**/.git/**',
];
