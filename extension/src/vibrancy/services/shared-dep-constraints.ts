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

/**
 * Read one package's declared constraints (name -> constraint range).
 * `error` is set when the read/parse threw, so callers can tell a failure
 * from a pubspec that genuinely declares no constraints.
 */
async function readConstraints(
    pubspecUri: vscode.Uri,
): Promise<{ constraints: Map<string, string>; error: string | null }> {
    try {
        const bytes = await vscode.workspace.fs.readFile(pubspecUri);
        const content = Buffer.from(bytes).toString('utf8');
        const parsed = parsePubspecYaml(content);
        return { constraints: new Map(Object.entries(parsed.constraints)), error: null };
    } catch (err) {
        // A package without a readable pubspec (SDK, unusual source) simply
        // contributes no constraints; the detector falls back to other
        // candidates rather than failing the whole scan.
        return { constraints: new Map(), error: String(err) };
    }
}

/**
 * Build constraint index for `candidateNames` by reading their pubspecs from
 * the local pub cache. Packages that cannot be resolved or read are skipped.
 */
export async function buildConstraintIndex(
    workspaceRoot: vscode.Uri,
    candidateNames: ReadonlySet<string>,
    // Optional sink for skipped candidates. A silent skip made a needed override
    // read as stale with no trace of why (unresolved path vs. empty pubspec).
    onSkip?: (name: string, reason: string, isEvidenceGap: boolean) => void,
): Promise<ConstraintIndex> {
    const index = new Map<string, ReadonlyMap<string, string>>();
    if (candidateNames.size === 0) { return index; }

    const paths = await resolvePackagePaths(workspaceRoot);
    const reads = [...candidateNames].map(async name => {
        const info = paths.get(name);
        if (!info) {
            onSkip?.(name, 'not found in .dart_tool/package_config.json', true);
            return;
        }
        const pubspecUri = vscode.Uri.joinPath(info.rootUri, 'pubspec.yaml');
        const { constraints, error } = await readConstraints(pubspecUri);
        if (constraints.size > 0) {
            index.set(name, constraints);
        } else if (error) {
            onSkip?.(name, `read failed for ${pubspecUri.fsPath}: ${error}`, true);
        } else {
            // Legitimately empty (only SDK/path deps); not an evidence gap for
            // callers that distinguish, but still logged for traceability.
            onSkip?.(name, `no constraints declared in ${pubspecUri.fsPath}`, false);
        }
    });
    await Promise.all(reads);
    return index;
}
