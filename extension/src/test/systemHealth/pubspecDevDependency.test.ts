import * as assert from 'assert';

import { addDevDependency } from '../../pubspecDevDependency';

/**
 * The pubspec edit turning CI on makes, and the extension's Enable makes.
 * Each case is a shape that produced invalid YAML or a duplicate entry
 * before this was extracted and tested.
 */

const add = (content: string): string | undefined => addDevDependency(content, 'saropa_lints', '^16.2.1');

describe('addDevDependency', () => {
  it('inserts first under an existing dev_dependencies', () => {
    assert.strictEqual(
      add('name: a\n\ndev_dependencies:\n  test: ^1.0.0\n'),
      'name: a\n\ndev_dependencies:\n  saropa_lints: ^16.2.1\n  test: ^1.0.0\n',
    );
  });

  it('finds dev_dependencies with a trailing comment instead of adding a duplicate key', () => {
    assert.strictEqual(
      add('name: a\ndev_dependencies: # tools\n  test: ^1.0.0\n'),
      'name: a\ndev_dependencies: # tools\n  saropa_lints: ^16.2.1\n  test: ^1.0.0\n',
    );
  });

  it('matches the indentation the section already uses', () => {
    assert.strictEqual(
      add('dev_dependencies:\n    test: ^1.0.0\n'),
      'dev_dependencies:\n    saropa_lints: ^16.2.1\n    test: ^1.0.0\n',
    );
  });

  it('looks past comments and blank lines for that indentation', () => {
    assert.strictEqual(
      add('dev_dependencies:\n\n  # lint\n    test: ^1.0.0\n'),
      'dev_dependencies:\n    saropa_lints: ^16.2.1\n\n  # lint\n    test: ^1.0.0\n',
    );
  });

  it('recognises an existing entry at any indentation, in either section', () => {
    assert.strictEqual(add('dev_dependencies:\n    saropa_lints: ^16.0.0\n'), undefined);
    assert.strictEqual(add('dependencies:\n  saropa_lints:\n    path: ../\n'), undefined);
  });

  it('is not fooled by a similarly named package or a mention elsewhere', () => {
    const out = add('# saropa_lints: later\ndev_dependencies:\n  saropa_lints_extra: ^1.0.0\n');
    assert.ok(out?.includes('\n  saropa_lints: ^16.2.1\n'));
  });

  it('appends a section when there is none, keeping the final newline', () => {
    assert.strictEqual(
      add('name: a\ndependencies:\n  http: ^1.0.0\n'),
      'name: a\ndependencies:\n  http: ^1.0.0\n\ndev_dependencies:\n  saropa_lints: ^16.2.1\n',
    );
  });

  it('appends without inventing a final newline the file did not have', () => {
    assert.strictEqual(add('name: a'), 'name: a\n\ndev_dependencies:\n  saropa_lints: ^16.2.1');
  });

  it('turns an empty flow map into a block', () => {
    assert.strictEqual(
      add('dev_dependencies: {}\n'),
      'dev_dependencies:\n  saropa_lints: ^16.2.1\n',
    );
  });

  it('keeps CRLF line endings', () => {
    assert.strictEqual(
      add('name: a\r\ndev_dependencies:\r\n  test: ^1.0.0\r\n'),
      'name: a\r\ndev_dependencies:\r\n  saropa_lints: ^16.2.1\r\n  test: ^1.0.0\r\n',
    );
  });
});
