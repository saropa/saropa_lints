import * as vscode from 'vscode';
import { VibrancyResult } from '../types';
import { generateSbom, serializeSbom, SbomMetadata } from './sbom-generator';
import { resolveReportFolder, formatTimestamp } from './report-utils';

/** Export SBOM to a timestamped file in the report/ directory. */
export async function exportSbomReport(
    results: readonly VibrancyResult[],
    extensionVersion: string,
): Promise<string | null> {
    const folder = await resolveReportFolder();
    if (!folder) { return null; }

    const meta = await readProjectMeta(extensionVersion);
    const bom = generateSbom(results, meta);
    const content = serializeSbom(bom);

    const timestamp = formatTimestamp(new Date());
    const uri = vscode.Uri.joinPath(
        folder, `${timestamp}_sbom.cdx.json`,
    );
    await vscode.workspace.fs.writeFile(uri, Buffer.from(content, 'utf-8'));
    return uri.fsPath;
}

async function readProjectMeta(
    extensionVersion: string,
): Promise<SbomMetadata> {
    const files = await vscode.workspace.findFiles(
        '**/pubspec.yaml', '**/.*/**', 1,
    );
    if (files.length === 0) {
        return {
            projectName: 'unknown',
            projectVersion: '0.0.0',
            extensionVersion,
        };
    }
    const bytes = await vscode.workspace.fs.readFile(files[0]);
    const text = Buffer.from(bytes).toString('utf-8');
    return {
        projectName: extractYamlField(text, 'name') ?? 'unknown',
        projectVersion: extractYamlField(text, 'version') ?? '0.0.0',
        extensionVersion,
    };
}

function extractYamlField(text: string, field: string): string | null {
    const re = new RegExp(`^${field}:\\s*(.+)$`, 'm');
    const match = re.exec(text);
    if (!match) { return null; }
    return match[1].trim().replace(/^(['"])(.+)\1$/, '$2');
}

