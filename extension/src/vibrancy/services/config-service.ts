import * as vscode from 'vscode';
import { ScoringWeights } from '../scoring/vibrancy-calculator';

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
 * Minutes within which a previously completed scan is considered fresh
 * enough to skip a startup re-scan (provided pubspec.lock and the
 * scan-config fingerprint are unchanged).
 *
 * Returning 0 means "never skip — always run the startup scan", matching
 * the old behaviour for users who explicitly disable this optimisation.
 */
export function getStartupScanSkipTtlMinutes(): number {
    return getConfig().get<number>('startupScanSkipTtlMinutes', 60);
}

/**
 * When the startup scan is skipped (cached results were rehydrated), show
 * a brief status-bar indicator so the user knows why no progress
 * notification appeared. Off by default — silent rehydrate is the point.
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
