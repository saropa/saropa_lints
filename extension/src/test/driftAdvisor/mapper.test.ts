/**
 * Regression tests for the Drift Advisor location mapper.
 *
 * These pin the two load-bearing properties from
 * `plans/history/2026.09/2026.09.05/infra_drift_poll_opens_every_dart_file_triggers_full_project_scan.md`, both of which are
 * about what the mapper must NOT do rather than about the line numbers it returns:
 *
 *  1. It must never call `vscode.workspace.openTextDocument`. That call fires
 *     `onDidOpenTextDocument`, which the scan-on-save controller reads as "the user opened a
 *     file" and answers with a full-project resolved lint scan. Doing that once per Dart file
 *     per 30-second poll is what drove two dart.exe processes to 22 GB and 13 GB of commit
 *     memory and crashed VS Code.
 *  2. A second `mapIssuesToLocations` call (i.e. the next poll) must not re-walk the workspace,
 *     including when the previous poll failed to resolve the table — the negative result has to
 *     be cached too, or an unknown table re-walks forever.
 *
 * The vscode mock is registered first so the mapper's `import * as vscode` resolves to it.
 */
import '../vibrancy/register-vscode-mock';
import * as assert from 'node:assert';
import * as vscodeMock from '../vibrancy/vscode-mock';
import {
  mapIssuesToLocations,
  resetTableLocationCache,
  disposeTableLocationWatcher,
} from '../../driftAdvisor/mapper';
import type { DriftIssueRaw } from '../../driftAdvisor/types';

/** Source of a fake Drift table, used as the content of every stubbed file read. */
const USERS_TABLE_SOURCE = [
  "import 'package:drift/drift.dart';",
  '',
  'class Users extends Table {',
  '  IntColumn get userId => integer()();',
  '}',
].join('\n');

/** Minimal raw issue; only `table`/`column` matter to the mapper. */
function issue(table: string, column: string | null = null): DriftIssueRaw {
  return {
    source: 'index-suggestion',
    severity: 'warning',
    table,
    column,
    message: 'test issue',
  } as DriftIssueRaw;
}

/**
 * Install workspace stubs and return the counters the assertions read.
 *
 * `openTextDocument` is replaced with a throwing stub rather than a counter alone so that a
 * regression fails loudly at the call site as well as in the assertion.
 */
function stubWorkspace(fileContents: string): {
  counts: { findFiles: number; readFile: number; openTextDocument: number };
} {
  const counts = { findFiles: 0, readFile: 0, openTextDocument: 0 };
  vscodeMock.mockWorkspaceFolders.value = [{ uri: { fsPath: '/ws' } }];
  vscodeMock.workspace.findFiles = async () => {
    counts.findFiles++;
    return [vscodeMock.Uri.file('/ws/lib/tables.dart')];
  };
  vscodeMock.workspace.fs.readFile = async () => {
    counts.readFile++;
    return new TextEncoder().encode(fileContents);
  };
  vscodeMock.workspace.openTextDocument = async () => {
    counts.openTextDocument++;
    throw new Error('mapper must not call openTextDocument (fires onDidOpenTextDocument)');
  };
  return { counts };
}

describe('Drift Advisor mapper', () => {
  beforeEach(() => {
    // Each test starts cold: no cached file list, no cached table locations, no watcher.
    disposeTableLocationWatcher();
  });

  afterEach(() => {
    disposeTableLocationWatcher();
    resetTableLocationCache();
  });

  it('resolves a table without ever opening a text document', async () => {
    const { counts } = stubWorkspace(USERS_TABLE_SOURCE);
    const mapped = await mapIssuesToLocations([issue('users')]);
    assert.strictEqual(counts.openTextDocument, 0, 'openTextDocument must never be called');
    assert.ok(counts.readFile > 0, 'file content must come from workspace.fs.readFile');
    assert.strictEqual(mapped[0].uri?.fsPath, '/ws/lib/tables.dart');
    // 0-based line of `class Users extends Table {` in USERS_TABLE_SOURCE.
    assert.strictEqual(mapped[0].line, 2);
  });

  it('resolves a column to its getter line, still without opening a document', async () => {
    const { counts } = stubWorkspace(USERS_TABLE_SOURCE);
    const mapped = await mapIssuesToLocations([issue('users', 'user_id')]);
    assert.strictEqual(counts.openTextDocument, 0);
    // 0-based line of `IntColumn get userId => integer()();`.
    assert.strictEqual(mapped[0].line, 3);
  });

  it('does not re-walk the workspace on a second call (the next poll)', async () => {
    const { counts } = stubWorkspace(USERS_TABLE_SOURCE);
    await mapIssuesToLocations([issue('users')]);
    const findFilesAfterFirst = counts.findFiles;
    assert.strictEqual(findFilesAfterFirst, 1, 'first call performs exactly one walk');
    await mapIssuesToLocations([issue('users')]);
    assert.strictEqual(
      counts.findFiles,
      findFilesAfterFirst,
      'a warm cache must cost zero filesystem walks',
    );
  });

  it('caches negative results so an unknown table does not re-walk every poll', async () => {
    const { counts } = stubWorkspace(USERS_TABLE_SOURCE);
    const first = await mapIssuesToLocations([issue('ghost_table')]);
    assert.strictEqual(first[0].uri, undefined, 'unknown table resolves to nothing');
    const walksAfterFirst = counts.findFiles;
    const readsAfterFirst = counts.readFile;
    await mapIssuesToLocations([issue('ghost_table')]);
    assert.strictEqual(counts.findFiles, walksAfterFirst, 'no second walk for a cached negative');
    assert.strictEqual(counts.readFile, readsAfterFirst, 'no second read for a cached negative');
  });

  it('does not cache a negative produced with no workspace folders', async () => {
    // "Could not search" is not "searched and found nothing". With no folder open, findDartFiles
    // returns before it can arm the file watcher, so nothing would ever invalidate a cached
    // negative — the table would stay unresolvable for the whole session even after a folder
    // appeared, permanently breaking navigation.
    const { counts } = stubWorkspace(USERS_TABLE_SOURCE);
    vscodeMock.mockWorkspaceFolders.value = undefined;
    const cold = await mapIssuesToLocations([issue('users')]);
    assert.strictEqual(cold[0].uri, undefined, 'nothing resolves without a workspace folder');
    assert.strictEqual(counts.findFiles, 0, 'no walk is even attempted without a folder');
    // The folder now appears, exactly as it does when a workspace finishes loading.
    vscodeMock.mockWorkspaceFolders.value = [{ uri: { fsPath: '/ws' } }];
    const warm = await mapIssuesToLocations([issue('users')]);
    assert.strictEqual(
      warm[0].uri?.fsPath,
      '/ws/lib/tables.dart',
      'the table must resolve once a folder exists — the earlier negative must not be cached',
    );
  });

  it('does not cache a negative produced from an empty file list', async () => {
    // Same distinction one layer down: a walk that yielded no candidate files examined nothing,
    // so its "not found" is not a real answer and must not be remembered.
    const { counts } = stubWorkspace(USERS_TABLE_SOURCE);
    const withFiles = vscodeMock.workspace.findFiles;
    vscodeMock.workspace.findFiles = async () => {
      counts.findFiles++;
      return [];
    };
    const cold = await mapIssuesToLocations([issue('users')]);
    assert.strictEqual(cold[0].uri, undefined);
    // The walk now returns the file it missed before (e.g. the file was just created).
    vscodeMock.workspace.findFiles = withFiles;
    resetTableLocationCache();
    const warm = await mapIssuesToLocations([issue('users')]);
    assert.strictEqual(warm[0].uri?.fsPath, '/ws/lib/tables.dart');
  });

  it('reads the table file once when several issues share one table', async () => {
    const { counts } = stubWorkspace(USERS_TABLE_SOURCE);
    // Warm the table location first, so the reads counted below are only the column lookups and
    // not the walk that located the class.
    await mapIssuesToLocations([issue('users')]);
    const readsBefore = counts.readFile;
    const mapped = await mapIssuesToLocations([issue('users', 'user_id'), issue('users', 'name')]);
    assert.strictEqual(
      counts.readFile - readsBefore,
      1,
      'two issues on one table must share a single file read',
    );
    assert.strictEqual(mapped[0].line, 3, 'userId getter line');
    assert.strictEqual(mapped[1].line, 2, 'unknown column falls back to the table class line');
  });

  it('discards a walk whose cache was invalidated while it was in flight', async () => {
    // Simulates the watcher firing mid-walk: the walk must not write its now-stale list back
    // over the invalidation, so the next call has to walk again.
    const { counts } = stubWorkspace(USERS_TABLE_SOURCE);
    const uncontestedFindFiles = vscodeMock.workspace.findFiles;
    vscodeMock.workspace.findFiles = async (...args: unknown[]) => {
      const files = await (uncontestedFindFiles as (...a: unknown[]) => Promise<unknown[]>)(...args);
      // The invalidation lands after findFiles resolved but before the result is published.
      resetTableLocationCache();
      return files;
    };
    await mapIssuesToLocations([issue('users')]);
    vscodeMock.workspace.findFiles = uncontestedFindFiles;
    const walksAfterFirst = counts.findFiles;
    await mapIssuesToLocations([issue('users')]);
    assert.strictEqual(
      counts.findFiles,
      walksAfterFirst + 1,
      'a walk invalidated mid-flight must not be cached',
    );
  });

  it('re-walks after resetTableLocationCache (what the file watcher triggers)', async () => {
    const { counts } = stubWorkspace(USERS_TABLE_SOURCE);
    await mapIssuesToLocations([issue('users')]);
    resetTableLocationCache();
    await mapIssuesToLocations([issue('users')]);
    assert.strictEqual(counts.findFiles, 2, 'invalidation must force a fresh walk');
  });
});
