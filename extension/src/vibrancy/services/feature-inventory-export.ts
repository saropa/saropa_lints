/**
 * Export the consolidated Package Opportunities report.
 *
 * Orchestration only — the measurement (`collectSymbolOccurrences`), the
 * consolidation (`buildFeatureInventory`), and the rendering
 * (`feature-inventory-html` / `-markdown`) are pure modules this glues to the
 * filesystem. Writes the same timestamped-triplet shape as `report-exporter`,
 * into the same `reports/` folder, so the two exports sit side by side.
 *
 * The symbol occurrence scan runs HERE rather than inside every package scan.
 * The scan already walks project sources for the adopted-yes/no ranking, and
 * adding an unconditional second pass would tax every rescan for a report most
 * users export rarely. Re-reading sources on demand keeps that cost with the
 * feature that needs it.
 */

import * as vscode from 'vscode';
import { VibrancyResult } from '../types';
import {
    readDartSources,
    collectSymbolOccurrences,
} from './import-scanner';
import { buildFeatureInventory } from './feature-inventory-model';
import { FeatureInventoryReport } from './feature-inventory-types';
import { buildFeatureInventoryHtml } from '../views/feature-inventory-html';
import { buildFeatureInventoryMarkdown } from '../views/feature-inventory-markdown';
import { resolveReportFolder, formatTimestamp } from './report-utils';

/** Absolute paths written, newest-first in open priority (HTML leads). */
export interface FeatureInventoryExport {
    readonly htmlPath: string;
    readonly markdownPath: string;
    readonly jsonPath: string;
    /**
     * Byte size of the HTML artifact. Reported so a workspace whose report has
     * grown past what a browser opens comfortably finds out from the tool
     * rather than from a hung tab.
     */
    readonly htmlBytes: number;
}

/**
 * Size past which the HTML is worth warning about. A browser will still open a
 * larger file, but expand-all and text filtering stop feeling instant, and at
 * that point the JSON artifact is the better input for an AI review anyway.
 */
export const HTML_SIZE_WARNING_BYTES = 8 * 1024 * 1024;

/**
 * Build and write the report. Returns `null` when no `reports/` folder could be
 * resolved (no workspace), so the caller surfaces one message rather than
 * writing a report nobody can find.
 */
export async function exportFeatureInventory(
    results: readonly VibrancyResult[],
    workspaceRoot: vscode.Uri,
    meta: { extensionVersion: string },
): Promise<FeatureInventoryExport | null> {
    const folder = await resolveReportFolder();
    if (!folder) { return null; }

    const report = await buildReport(results, workspaceRoot, meta);
    const stamp = formatTimestamp(new Date());

    const htmlContent = buildFeatureInventoryHtml(report);
    const html = await write(
        folder, `${stamp}_saropa_opportunities.html`, htmlContent,
    );
    const markdown = await write(
        folder, `${stamp}_saropa_opportunities.md`,
        buildFeatureInventoryMarkdown(report),
    );
    // JSON carries the model verbatim and untruncated — the renderers cap usage
    // lists for readability, this is the copy an AI can consume in full.
    const json = await write(
        folder, `${stamp}_saropa_opportunities.json`,
        JSON.stringify(report, null, 2),
    );

    return {
        htmlPath: html,
        markdownPath: markdown,
        jsonPath: json,
        htmlBytes: Buffer.byteLength(htmlContent, 'utf-8'),
    };
}

/**
 * Measure symbol usage across project source, then consolidate it with the
 * scan results into the report model.
 *
 * Candidates are every API name mined from every package's changelog — the same
 * set the adoption ranking builds during a scan, rebuilt here because the scan
 * does not retain it.
 */
async function buildReport(
    results: readonly VibrancyResult[],
    workspaceRoot: vscode.Uri,
    meta: { extensionVersion: string },
): Promise<FeatureInventoryReport> {
    const candidates = new Set<string>();
    for (const r of results) {
        for (const name of r.opportunities?.apiNames ?? []) {
            candidates.add(name);
        }
    }

    const sources = await readDartSources(workspaceRoot);
    const occurrences = collectSymbolOccurrences(sources, candidates);

    return buildFeatureInventory(results, occurrences, {
        generatedAt: new Date().toISOString(),
        extensionVersion: meta.extensionVersion,
    });
}

/** Write one artifact and return its absolute path. */
async function write(
    folder: vscode.Uri, fileName: string, content: string,
): Promise<string> {
    const uri = vscode.Uri.joinPath(folder, fileName);
    await vscode.workspace.fs.writeFile(uri, Buffer.from(content, 'utf-8'));
    return uri.fsPath;
}
