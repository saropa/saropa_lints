import * as vscode from 'vscode';
import {
    parsePubspecYaml, parseDependencyOverrides,
} from '../services/pubspec-parser';
import { fetchPackageInfo } from '../services/pub-dev-api';
import { getLatestResults } from '../extension-activation';
import { findPubspecYaml } from '../services/pubspec-editor';
import { buildAnnotationEdits } from './annotate-packages';
import {
    SectionHeaderEdit,
    buildSectionHeaderEdits, buildSubSectionHeaderEdits, buildOverrideMarkerEdit,
} from './annotate-headers';

const SDK_PACKAGES = new Set([
    'flutter', 'flutter_test', 'flutter_localizations',
    'flutter_web_plugins', 'flutter_driver',
]);

const FETCH_CONCURRENCY = 3;

let annotateInProgress = false;

/** Register the annotate-pubspec command. */
export function registerAnnotateCommand(
    context: vscode.ExtensionContext,
): void {
    context.subscriptions.push(
        vscode.commands.registerCommand(
            'saropaLints.packageVibrancy.annotatePubspec',
            () => annotatePubspec(),
        ),
    );
}

/** Add description comments above each dependency in pubspec.yaml. */
async function annotatePubspec(): Promise<void> {
    if (annotateInProgress) {
        vscode.window.showWarningMessage('Annotation already in progress');
        return;
    }
    annotateInProgress = true;
    try {
        await annotatePubspecInner();
    } finally {
        annotateInProgress = false;
    }
}

/** Return the active editor's URI if it's a pubspec.yaml, else find the root one. */
async function resolveTargetPubspec(): Promise<vscode.Uri | null> {
    const active = vscode.window.activeTextEditor?.document;
    if (active && active.fileName.endsWith('pubspec.yaml')) {
        return active.uri;
    }
    return findPubspecYaml();
}

async function annotatePubspecInner(): Promise<void> {
    const yamlUri = await resolveTargetPubspec();
    if (!yamlUri) {
        vscode.window.showWarningMessage('No pubspec.yaml found in workspace');
        return;
    }

    const doc = await vscode.workspace.openTextDocument(yamlUri);
    const content = doc.getText();
    const { directDeps, devDeps } = parsePubspecYaml(content);
    const overrides = parseDependencyOverrides(content);
    const allDeps = [...directDeps, ...devDeps]
        .filter(n => !SDK_PACKAGES.has(n));

    if (allDeps.length === 0) {
        vscode.window.showInformationMessage('No dependencies to annotate');
        return;
    }

    const descriptions = await fetchDescriptions(allDeps);
    const edits = buildAnnotationEdits(doc, allDeps, descriptions);

    const config = vscode.workspace.getConfiguration('saropaLints.packageVibrancy');
    const insertSectionHeaders = config.get<boolean>(
        'annotateSectionHeaders',
        true,
    );

    const allSectionEdits: SectionHeaderEdit[] = [];
    if (insertSectionHeaders) {
        allSectionEdits.push(...buildSectionHeaderEdits(doc));
        allSectionEdits.push(...buildSubSectionHeaderEdits(doc));
        const overrideMarker = buildOverrideMarkerEdit(
            doc, directDeps, overrides,
        );
        if (overrideMarker) {
            allSectionEdits.push(overrideMarker);
        }
    }

    if (edits.length === 0 && allSectionEdits.length === 0) { return; }

    const wsEdit = new vscode.WorkspaceEdit();

    for (const edit of allSectionEdits) {
        if (edit.deleteRange) {
            wsEdit.delete(yamlUri, edit.deleteRange);
        }
        wsEdit.insert(yamlUri, edit.insertPos, edit.text);
    }

    for (const edit of edits) {
        for (const delRange of edit.deleteRanges) {
            wsEdit.delete(yamlUri, delRange);
        }
        wsEdit.insert(yamlUri, edit.insertPos, edit.text);
    }

    const applied = await vscode.workspace.applyEdit(wsEdit);
    if (!applied) {
        vscode.window.showErrorMessage('Failed to apply annotations to pubspec.yaml');
        return;
    }
    await doc.save();

    const basename = yamlUri.fsPath.split(/[\\/]/).slice(-2).join('/');
    const parts: string[] = [];
    if (edits.length > 0) {
        parts.push(`${edits.length} dependencies`);
    }
    if (allSectionEdits.length > 0) {
        parts.push(`${allSectionEdits.length} section headers`);
    }
    vscode.window.showInformationMessage(
        `Annotated ${parts.join(' and ')} in ${basename}`,
    );
}

/** Fetch descriptions from cached scan results or pub.dev API. */
async function fetchDescriptions(
    names: string[],
): Promise<Map<string, string>> {
    const map = new Map<string, string>();
    const missing: string[] = [];

    for (const r of getLatestResults()) {
        if (r.pubDev?.description) {
            map.set(r.package.name, r.pubDev.description);
        }
    }

    for (const name of names) {
        if (!map.has(name)) { missing.push(name); }
    }
    if (missing.length === 0) { return map; }

    await vscode.window.withProgress(
        {
            location: vscode.ProgressLocation.Notification,
            title: 'Fetching package descriptions...',
        },
        async (progress) => {
            let completed = 0;
            let cursor = 0;
            async function next(): Promise<void> {
                while (cursor < missing.length) {
                    const name = missing[cursor++];
                    progress.report({
                        message: `${name} (${++completed}/${missing.length})`,
                    });
                    const info = await fetchPackageInfo(name);
                    if (info?.description) {
                        map.set(name, info.description);
                    }
                }
            }
            const workers = Array.from(
                { length: Math.min(FETCH_CONCURRENCY, missing.length) },
                () => next(),
            );
            await Promise.all(workers);
        },
    );

    return map;
}
