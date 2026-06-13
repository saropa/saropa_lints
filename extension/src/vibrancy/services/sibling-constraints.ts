/**
 * Reads dependency constraints from configured sibling-repo pubspecs so
 * cross-project drift detection can compare majors across projects.
 *
 * The scanner only sees one workspace; to learn that a sibling repo is on a
 * newer major of a shared package, that sibling's pubspec.yaml must be read
 * directly. Paths come from the `siblingRepoPaths` setting — an explicit,
 * user-provided input, since the scanner has no other way to discover related
 * repos on disk.
 */

import * as vscode from 'vscode';
import { parsePubspecYaml } from './pubspec-parser';
import { SiblingConstraints } from '../scoring/cross-project-drift-detector';

/** Label a sibling repo by its directory name (the last path segment). */
function repoLabel(repoPath: string): string {
    const normalized = repoPath.replace(/[\\/]+$/, '');
    const segments = normalized.split(/[\\/]/);
    return segments[segments.length - 1] || normalized;
}

/** Read one sibling's pubspec constraints; empty map if unreadable. */
async function readOne(repoPath: string): Promise<Map<string, string>> {
    try {
        const uri = vscode.Uri.joinPath(vscode.Uri.file(repoPath), 'pubspec.yaml');
        const bytes = await vscode.workspace.fs.readFile(uri);
        const parsed = parsePubspecYaml(Buffer.from(bytes).toString('utf8'));
        return new Map(Object.entries(parsed.constraints));
    } catch {
        // A path that isn't a Dart project (or doesn't exist) simply
        // contributes no constraints rather than failing the scan.
        return new Map();
    }
}

/**
 * Build the sibling-constraint index from the configured repo paths. Paths
 * with no readable pubspec are skipped. Returns repo label -> (package ->
 * constraint).
 */
export async function readSiblingConstraints(
    repoPaths: readonly string[],
): Promise<SiblingConstraints> {
    const index = new Map<string, ReadonlyMap<string, string>>();
    if (repoPaths.length === 0) { return index; }

    const reads = repoPaths.map(async path => {
        const constraints = await readOne(path);
        if (constraints.size > 0) { index.set(repoLabel(path), constraints); }
    });
    await Promise.all(reads);
    return index;
}
