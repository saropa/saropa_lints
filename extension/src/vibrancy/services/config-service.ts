/** * Module overview (comment coverage pass). * comment-coverage: module overview (batch). * * Vibrancy UI experiment: scoring, providers, and webview assets. */
import * as vscode from 'vscode';
import { ScoringWeights } from '../scoring/vibrancy-calculator';

// Typed reads of `saropaLints.packageVibrancy` workspace settings.
/**
 * Centralized configuration service.
 * Provides typed access to all extension settings.
 */

const SECTION = 'saropaLints.packageVibrancy';

function getConfig(): vscode.WorkspaceConfiguration {
    return vscode.workspace.getConfiguration(SECTION);
}

// --- GitHub & API Settings ---

export function getGithubToken(): string {
    return getConfig().get<string>('githubToken', '');
}

export function getCacheTtlHours(): number {
    return getConfig().get<number>('cacheTtlHours', 24);
}

// --- Scan Settings ---

export function getScanOnOpen(): boolean {
    return getConfig().get<boolean>('scanOnOpen', true);
}

/**
 * Master switch for the startup skip-gate.  Any non-zero value enables
 * the optimisation: on restart, if pubspec.lock and the scan-config
 * fingerprint are unchanged, the cached results are rehydrated INSTANTLY
 * with no foreground scan — regardless of how long ago the scan ran,
 * because an unchanged lock guarantees unchanged results.  Freshness is
 * kept up via a separate silent background refresh
 * (see `getBackgroundRefreshStalenessHours`).
 *
 * The numeric value is retained for backward compatibility with the old
 * "skip TTL" knob, but only its sign matters now: 0 means "never skip —
 * always run the full startup scan", restoring the legacy behaviour for
 * users who explicitly disable the optimisation.
 */
export function getStartupScanSkipTtlMinutes(): number {
    return getConfig().get<number>('startupScanSkipTtlMinutes', 60);
}

/**
 * When the startup skip-gate rehydrates cached results, trigger a silent
 * background refresh (no progress notification) if the cached data is
 * older than this many hours.  This keeps pub.dev / GitHub numbers
 * drifting up to date over days when the user never runs `pub get`, while
 * never blocking them with the foreground scan.  Set to 0 to disable the
 * background refresh entirely (rehydrate-only; data refreshes only on a
 * real pubspec.lock change or a manual rescan).
 *
 * The per-package API cache (`cacheTtlHours`, default 24h) means a refresh
 * that runs soon after its window opens is mostly cache hits and cheap.
 */
export function getBackgroundRefreshStalenessHours(): number {
    return getConfig().get<number>('backgroundRefreshStalenessHours', 24);
}

/**
 * Number of packages analysed concurrently during a scan.  The scan is
 * network-bound (each package fans out to pub.dev + GitHub + a tarball
 * download), so higher concurrency cuts wall-clock time on cold scans.
 * Capped to keep within GitHub's unauthenticated rate window and to avoid
 * hammering pub.dev; raise only when a GitHub token is configured.
 */
export function getScanConcurrency(): number {
    const raw = getConfig().get<number>('scanConcurrency', 6);
    // Clamp defensively: 0/negative would stall the scan, absurdly high
    // values risk rate-limit bans rather than speed.
    if (!Number.isFinite(raw) || raw < 1) { return 1; }
    return Math.min(raw, 16);
}

/**
 * When the startup scan is skipped (cached results were rehydrated), show
 * a brief status-bar indicator so the user knows why no progress
 * notification appeared. Without this flag, rehydrate stays silent.
 */
export function getShowStartupScanSkipStatusBar(): boolean {
    return getConfig().get<boolean>('showStartupScanSkipStatusBar', false);
}

export function getIncludeDevDependencies(): boolean {
    return getConfig().get<boolean>('includeDevDependencies', true);
}

export function getIncludeOverriddenPackages(): boolean {
    return getConfig().get<boolean>('includeOverriddenPackages', true);
}

export function getVersionGapEnabled(): boolean {
    return getConfig().get<boolean>('enableVersionGap', false);
}

export function getAllowlist(): readonly string[] {
    return getConfig().get<string[]>('allowlist', []);
}

export function getAllowlistSet(): Set<string> {
    return new Set(getAllowlist());
}

export function getRepoOverrides(): Record<string, string> {
    return getConfig().get<Record<string, string>>('repoOverrides', {});
}

/**
 * Filesystem paths to sibling repos to compare for cross-project version drift
 * (the same package pinned at a different major elsewhere). Empty by default —
 * the scanner has no other way to discover related repos on disk.
 */
export function getSiblingRepoPaths(): readonly string[] {
    return getConfig().get<string[]>('siblingRepoPaths', []);
}

// --- Scoring Weights ---

export function getScoringWeights(): ScoringWeights {
    const config = getConfig();
    return {
        resolutionVelocity: config.get<number>('weights.resolutionVelocity', 0.5),
        engagementLevel: config.get<number>('weights.engagementLevel', 0.4),
        popularity: config.get<number>('weights.popularity', 0.1),
    };
}

export function getPublisherTrustBonus(): number {
    return getConfig().get<number>('publisherTrustBonus', 15);
}

// --- UI Settings ---

export function getEnableCodeLens(): boolean {
    return getConfig().get<boolean>('enableCodeLens', true);
}

export function getEnableAdoptionGate(): boolean {
    return getConfig().get<boolean>('enableAdoptionGate', true);
}

export function getCodeLensDetail(): 'minimal' | 'standard' | 'full' {
    return getConfig().get<'minimal' | 'standard' | 'full'>('codeLensDetail', 'standard');
}

export function getTreeGrouping(): 'none' | 'section' | 'category' {
    return getConfig().get<'none' | 'section' | 'category'>('treeGrouping', 'none');
}

// --- Diagnostic Settings ---

export type EndOfLifeDiagnosticMode = 'none' | 'hint' | 'smart';

export function getEndOfLifeDiagnostics(): EndOfLifeDiagnosticMode {
    return getConfig().get<EndOfLifeDiagnosticMode>('endOfLifeDiagnostics', 'none');
}

/** How many vibrancy issues to show as inline diagnostics in pubspec.yaml. */
export type InlineDiagnosticsMode = 'critical' | 'all' | 'none';

export function getInlineDiagnosticsMode(): InlineDiagnosticsMode {
    return getConfig().get<InlineDiagnosticsMode>('inlineDiagnostics', 'critical');
}

// --- Suppression Settings ---

export function getSuppressedPackages(): readonly string[] {
    return getConfig().get<string[]>('suppressedPackages', []);
}

export async function addSuppressedPackage(packageName: string): Promise<void> {
    const config = getConfig();
    const current = config.get<string[]>('suppressedPackages', []);
    if (current.includes(packageName)) { return; }
    await config.update(
        'suppressedPackages',
        [...current, packageName],
        vscode.ConfigurationTarget.Workspace,
    );
}

export async function removeSuppressedPackage(packageName: string): Promise<void> {
    const config = getConfig();
    const current = config.get<string[]>('suppressedPackages', []);
    await config.update(
        'suppressedPackages',
        current.filter(n => n !== packageName),
        vscode.ConfigurationTarget.Workspace,
    );
}

export async function addSuppressedPackages(packageNames: string[]): Promise<number> {
    const config = getConfig();
    const current = new Set(config.get<string[]>('suppressedPackages', []));
    const toAdd = packageNames.filter(name => !current.has(name));
    if (toAdd.length === 0) { return 0; }
    await config.update(
        'suppressedPackages',
        [...current, ...toAdd],
        vscode.ConfigurationTarget.Workspace,
    );
    return toAdd.length;
}

export async function clearSuppressedPackages(): Promise<number> {
    const config = getConfig();
    const current = config.get<string[]>('suppressedPackages', []);
    const count = current.length;
    if (count === 0) { return 0; }
    await config.update(
        'suppressedPackages',
        [],
        vscode.ConfigurationTarget.Workspace,
    );
    return count;
}

export function getSuppressedSet(): Set<string> {
    return new Set(getSuppressedPackages());
}

// --- Notification Settings ---

export function getShowLockDiffNotifications(): boolean {
    return getConfig().get<boolean>('showLockDiffNotifications', true);
}

// --- Freshness Watch Settings ---

export function getFreshnessWatchEnabled(): boolean {
    return getConfig().get<boolean>('freshnessWatch.enabled', false);
}

export function getFreshnessWatchIntervalHours(): number {
    return getConfig().get<number>('freshnessWatch.intervalHours', 4);
}

export function getFreshnessWatchFilter(): 'all' | 'unhealthy' | 'custom' {
    return getConfig().get<'all' | 'unhealthy' | 'custom'>('freshnessWatch.filter', 'all');
}

export function getFreshnessWatchCustomPackages(): readonly string[] {
    return getConfig().get<string[]>('freshnessWatch.customPackages', []);
}

// --- Annotation Settings ---

export function getAnnotationWithSectionHeaders(): boolean {
    return getConfig().get<boolean>('annotateWithSectionHeaders', false);
}

// --- Vulnerability Scan Settings ---

import { VulnSeverity } from '../types';

export function getVulnScanEnabled(): boolean {
    return getConfig().get<boolean>('enableVulnScan', true);
}

export function getVulnSeverityThreshold(): VulnSeverity {
    return getConfig().get<VulnSeverity>('vulnSeverityThreshold', 'low');
}

export function getGitHubAdvisoryEnabled(): boolean {
    return getConfig().get<boolean>('enableGitHubAdvisory', true);
}
