/**
 * Ensures TODOs & Hacks default configuration stays aligned between code and `package.json`,
 * and that Markdown is not part of the default scan set (docs would false-positive as "TODOs").
 */

import * as assert from 'node:assert';
import * as fs from 'node:fs';
import * as path from 'node:path';
import {
  DEFAULT_TODOS_AND_HACKS_EXCLUDE_GLOBS,
  DEFAULT_TODOS_AND_HACKS_INCLUDE_GLOBS,
  DEFAULT_TODOS_AND_HACKS_TAGS,
} from '../../views/todosAndHacksDefaults';

describe('todosAndHacks defaults', () => {
  it('does not include Markdown in default include globs (avoid doc/prose noise)', () => {
    assert.ok(
      !DEFAULT_TODOS_AND_HACKS_INCLUDE_GLOBS.includes('**/*.md'),
      'Default scan should be code/config only; add **/*.md via settings if needed',
    );
  });

  it('matches package.json contributed defaults for todosAndHacks', () => {
    const pkgPath = path.join(__dirname, '..', '..', '..', 'package.json');
    const raw = fs.readFileSync(pkgPath, 'utf8');
    const pkg = JSON.parse(raw) as {
      contributes: {
        configuration: Array<{ properties?: Record<string, { default?: unknown }> }>;
      };
    };
    const props: Record<string, { default?: unknown }> = {};
    for (const section of pkg.contributes.configuration) {
      if (section.properties) {
        Object.assign(props, section.properties);
      }
    }

    assert.deepStrictEqual(
      props['saropaLints.todosAndHacks.tags'].default,
      [...DEFAULT_TODOS_AND_HACKS_TAGS],
    );
    assert.deepStrictEqual(
      props['saropaLints.todosAndHacks.includeGlobs'].default,
      [...DEFAULT_TODOS_AND_HACKS_INCLUDE_GLOBS],
    );
    assert.deepStrictEqual(
      props['saropaLints.todosAndHacks.excludeGlobs'].default,
      [...DEFAULT_TODOS_AND_HACKS_EXCLUDE_GLOBS],
    );
    assert.strictEqual(
      props['saropaLints.todosAndHacks.workspaceScanEnabled'].default,
      false,
      'Workspace TODO scan must stay opt-in (resource-intensive)',
    );
  });
});
