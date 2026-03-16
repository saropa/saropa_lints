import * as vscode from 'vscode';
import { parsePubspecYaml, parsePubspecLock } from './services/pubspec-parser';
import { analyzePackage } from './scan-orchestrator';
import { detectDartVersion, detectFlutterVersion } from './services/sdk-detector';
import { PackageDependency, VibrancyResult } from './types';
import { ScoringWeights } from './scoring/vibrancy-calculator';
import { ReportMetadata } from './services/report-exporter';
import { CacheService } from './services/cache-service';
import { ScanLogger } from './services/scan-logger';
import { FlutterRelease } from './services/flutter-releases';
import {
    getGithubToken, getAllowlistSet, getScoringWeights,
    getRepoOverrides, getPublisherTrustBonus, getIncludeDevDependencies,
    getIncludeOverriddenPackages,
} from './services/config-service';

export interface ScanConfig {
    readonly token: string;
    readonly allowSet: Set<string>;
    readonly weights: ScoringWeights;
    readonly repoOverrides: Record<string, string>;
    readonly publisherTrustBonus: number;
    readonly logger?: ScanLogger;
    readonly flutterReleases?: readonly FlutterRelease[];
}

export function readScanConfig(): ScanConfig {
    return {
        token: getGithubToken(),
        allowSet: getAllowlistSet(),
        weights: getScoringWeights(),
        repoOverrides: getRepoOverrides(),
        publisherTrustBonus: getPublisherTrustBonus(),
    };
}

const CONCURRENCY = 3;

export async function scanPackages(
    deps: PackageDependency[],
    cache: CacheService,
    scanConfig: ScanConfig,
    progress: vscode.Progress<{ message?: string; increment?: number }>,
): Promise<VibrancyResult[]> {
    const results: VibrancyResult[] = new Array(deps.length);
    let completed = 0;
    let cursor = 0;

    async function next(): Promise<void> {
        while (cursor < deps.length) {
            const idx = cursor++;
            const dep = deps[idx];
            scanConfig.logger?.info(`[${idx + 1}/${deps.length}] ${dep.name}`);
            results[idx] = await analyzePackage(dep, {
                cache, logger: scanConfig.logger,
                githubToken: scanConfig.token || undefined,
                weights: scanConfig.weights,
                repoOverrides: scanConfig.repoOverrides,
                publisherTrustBonus: scanConfig.publisherTrustBonus,
                flutterReleases: scanConfig.flutterReleases,
            });
            completed++;
            progress.report({
                message: `${dep.name} (${completed}/${deps.length})`,
                increment: 100 / deps.length,
            });
        }
    }

    const workers = Array.from(
        { length: Math.min(CONCURRENCY, deps.length) },
        () => next(),
    );
    await Promise.all(workers);
    return results;
}

export async function buildScanMeta(startTime: number): Promise<ReportMetadata> {
    const [flutterVer, dartVer] = await Promise.all([
        detectFlutterVersion(), detectDartVersion(),
    ]);
    return {
        flutterVersion: flutterVer,
        dartVersion: dartVer,
        executionTimeMs: Date.now() - startTime,
    };
}

export interface ParsedDeps {
    readonly deps: PackageDependency[];
    readonly yamlUri: vscode.Uri;
    readonly yamlContent: string;
}

/** Check if a dependency source should be included in the scan. */
function isScannableSource(source: string, includeOverridden: boolean): boolean {
    if (source === 'hosted') { return true; }
    if (includeOverridden && (source === 'path' || source === 'git')) { return true; }
    return false;
}

/**
 * Find pubspec.yaml + pubspec.lock, preferring workspace root.
 * Falls back to recursive search for monorepo / nested project layouts.
 */
async function findPubspecPair(): Promise<{ yaml: vscode.Uri; lock: vscode.Uri } | null> {
    const folders = vscode.workspace.workspaceFolders;
    if (folders) {
        for (const folder of folders) {
            const yaml = vscode.Uri.joinPath(folder.uri, 'pubspec.yaml');
            const lock = vscode.Uri.joinPath(folder.uri, 'pubspec.lock');
            try {
                await Promise.all([
                    vscode.workspace.fs.stat(yaml),
                    vscode.workspace.fs.stat(lock),
                ]);
                return { yaml, lock };
            } catch {
                continue;
            }
        }
    }

    const [yamlFiles, lockFiles] = await Promise.all([
        vscode.workspace.findFiles('**/pubspec.yaml', '**/.*/**', 1),
        vscode.workspace.findFiles('**/pubspec.lock', '**/.*/**', 1),
    ]);
    if (yamlFiles.length === 0 || lockFiles.length === 0) { return null; }
    return { yaml: yamlFiles[0], lock: lockFiles[0] };
}

export async function findAndParseDeps(): Promise<ParsedDeps | null> {
    const pair = await findPubspecPair();
    if (!pair) { return null; }

    const [yamlBytes, lockBytes] = await Promise.all([
        vscode.workspace.fs.readFile(pair.yaml),
        vscode.workspace.fs.readFile(pair.lock),
    ]);

    const yamlContent = Buffer.from(yamlBytes).toString('utf8');
    const lockContent = Buffer.from(lockBytes).toString('utf8');

    const includeDevDeps = getIncludeDevDependencies();
    const includeOverridden = getIncludeOverriddenPackages();

    const { directDeps, devDeps, constraints } = parsePubspecYaml(yamlContent);
    const effectiveDevDeps = includeDevDeps ? devDeps : [];
    const deps = parsePubspecLock(lockContent, directDeps, constraints, effectiveDevDeps)
        .filter(d => d.isDirect && isScannableSource(d.source, includeOverridden));

    return { deps, yamlUri: pair.yaml, yamlContent };
}
