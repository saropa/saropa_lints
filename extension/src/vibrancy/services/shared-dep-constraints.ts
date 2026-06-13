/**
 * Builds the version-constraint index that diamond-conflict detection needs.
 *
 * `dart pub deps --json` exposes the resolved graph but NOT the per-edge
 * version constraints, so to learn that (say) `saropa_lints` caps
 * `analyzer <13` we read each candidate package's own pubspec.yaml from the
 * resolved pub cache. Only the packages the caller flags as candidate
 * constrainers are read, so I/O stays bounded to the contested subgraph rather
 * than every transitive package.
 */

import * as vscode from 'vscode';
import { resolvePackagePaths } from './package-code-analyzer';
import { parsePubspecYaml } from './pubspec-parser';
import { ConstraintIndex } from '../scoring/shared-dep-conflict-detector';

/** Read one package's declared constraints (name -> constraint range). */
async function readConstraints(
    pubspecUri: vscode.Uri,
): Promise<Map<string, string>> {
    try {
        const bytes = await vscode.workspace.fs.readFile(pubspecUri);
        const content = Buffer.from(bytes).toString('utf8');
        const parsed = parsePubspecYaml(content);
        return new Map(Object.entries(parsed.constraints));
    } catch {
        // A package without a readable pubspec (SDK, unusual source) simply
        // contributes no constraints; the detector falls back to other
        // candidates rather than failing the whole scan.
        return new Map();
    }
}

/**
 * Build constraint index for `candidateNames` by reading their pubspecs from
 * the local pub cache. Packages that cannot be resolved or read are skipped.
 */
export async function buildConstraintIndex(
    workspaceRoot: vscode.Uri,
    candidateNames: ReadonlySet<string>,
): Promise<ConstraintIndex> {
    const index = new Map<string, ReadonlyMap<string, string>>();
    if (candidateNames.size === 0) { return index; }

    const paths = await resolvePackagePaths(workspaceRoot);
    const reads = [...candidateNames].map(async name => {
        const info = paths.get(name);
        if (!info) { return; }
        const pubspecUri = vscode.Uri.joinPath(info.rootUri, 'pubspec.yaml');
        const constraints = await readConstraints(pubspecUri);
        if (constraints.size > 0) { index.set(name, constraints); }
    });
    await Promise.all(reads);
    return index;
}
