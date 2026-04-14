import * as vscode from 'vscode';

const PUB_DEV_URL = 'https://pub.dev';
const SECRET_KEY_PREFIX = 'saropaLints.packageVibrancy.registry.';

/** Configuration for a private registry. */
export interface RegistryConfig {
    readonly url: string;
    readonly name: string;
    readonly packages: readonly string[];
}


/**
 * Service for managing private registry authentication.
 * Tokens are stored securely in VS Code's SecretStorage.
 */
export class RegistryService implements vscode.Disposable {
    private readonly disposables: vscode.Disposable[] = [];
    private hostedDepsCache: Map<string, string> = new Map();

    constructor(
        private readonly secretStorage: vscode.SecretStorage,
    ) { }

    dispose(): void {
        this.disposables.forEach(d => d.dispose());
    }

    /**
     * Get the registry URL for a package.
     * Priority: pubspec hosted URL > configured registry > pub.dev
     */
    getRegistryForPackage(
        packageName: string,
        pubspecContent?: string,
    ): string {
        if (pubspecContent) {
            this.parseHostedDeps(pubspecContent);
        }

        const hostedUrl = this.hostedDepsCache.get(packageName);
        if (hostedUrl) {
            return hostedUrl;
        }

        const configuredUrl = this.getConfiguredRegistry(packageName);
        if (configuredUrl) {
            return configuredUrl;
        }

        return PUB_DEV_URL;
    }

    /**
     * Check if a registry URL is the default pub.dev.
     */
    isPubDev(registryUrl: string): boolean {
        return registryUrl === PUB_DEV_URL;
    }

    /**
     * Get authentication token for a registry.
     */
    async getToken(registryUrl: string): Promise<string | null> {
        if (this.isPubDev(registryUrl)) {
            return null;
        }
        const key = SECRET_KEY_PREFIX + registryUrl;
        const token = await this.secretStorage.get(key);
        return token ?? null;
    }

    /**
     * Store authentication token for a registry.
     * @throws Error if URL is not HTTPS
     */
    async setToken(registryUrl: string, token: string): Promise<void> {
        this.validateRegistryUrl(registryUrl);
        const key = SECRET_KEY_PREFIX + registryUrl;
        await this.secretStorage.store(key, token);
    }

    /**
     * Remove authentication token for a registry.
     */
    async removeToken(registryUrl: string): Promise<void> {
        const key = SECRET_KEY_PREFIX + registryUrl;
        await this.secretStorage.delete(key);
    }

    /**
     * Get all configured registries with their auth status.
     */
    async listRegistries(): Promise<Array<RegistryConfig & { hasToken: boolean }>> {
        const config = vscode.workspace.getConfiguration('saropaLints.packageVibrancy');
        const registries = config.get<Record<string, { name?: string; packages?: string[] }>>('registries', {});

        const entries = Object.entries(registries);
        const tokenChecks = await Promise.all(
            entries.map(([url]) => this.getToken(url)),
        );

        return entries.map(([url, settings], index) => ({
            url,
            name: settings.name ?? new URL(url).hostname,
            packages: settings.packages ?? [],
            hasToken: tokenChecks[index] !== null,
        }));
    }

    /**
     * Add or update a registry configuration in settings.
     */
    async addRegistryConfig(url: string, name: string): Promise<void> {
        this.validateRegistryUrl(url);

        const config = vscode.workspace.getConfiguration('saropaLints.packageVibrancy');
        const registries = { ...config.get<Record<string, unknown>>('registries', {}) };

        registries[url] = {
            name,
            packages: [],
        };

        await config.update('registries', registries, vscode.ConfigurationTarget.Global);
    }

    /**
     * Remove a registry configuration from settings.
     */
    async removeRegistryConfig(url: string): Promise<void> {
        const config = vscode.workspace.getConfiguration('saropaLints.packageVibrancy');
        const registries = { ...config.get<Record<string, unknown>>('registries', {}) };

        delete registries[url];

        await config.update('registries', registries, vscode.ConfigurationTarget.Global);
    }

    /**
     * Clear the hosted dependencies cache.
     */
    clearCache(): void {
        this.hostedDepsCache.clear();
    }

    /**
     * Update cache with hosted dependencies from pubspec content.
     */
    updateHostedDepsFromPubspec(pubspecContent: string): void {
        this.parseHostedDeps(pubspecContent);
    }

    /**
     * Get all hosted dependencies detected in the current pubspec.
     */
    getHostedDependencies(): ReadonlyMap<string, string> {
        return this.hostedDepsCache;
    }

    private validateRegistryUrl(url: string): void {
        try {
            const parsed = new URL(url);
            if (parsed.protocol !== 'https:') {
                throw new Error('Registry URL must use HTTPS');
            }
        } catch (e) {
            if (e instanceof Error && e.message.includes('HTTPS')) {
                throw e;
            }
            throw new Error(`Invalid registry URL: ${url}`);
        }
    }

    private getConfiguredRegistry(packageName: string): string | null {
        const config = vscode.workspace.getConfiguration('saropaLints.packageVibrancy');
        const registries = config.get<Record<string, { packages?: string[] }>>('registries', {});

        for (const [url, settings] of Object.entries(registries)) {
            if (settings.packages?.includes(packageName)) {
                return url;
            }
        }

        return null;
    }

    /**
     * Parse pubspec.yaml content to extract hosted dependency URLs.
     * Handles the format:
     * ```yaml
     * dependencies:
     *   my_private_pkg:
     *     hosted:
     *       url: https://pub.example.com
     *     version: ^1.0.0
     * ```
     */
    private parseHostedDeps(content: string): void {
        const lines = content.split('\n');
        let inDepsSection = false;
        let currentPackage: string | null = null;
        let inHostedBlock = false;

        for (const rawLine of lines) {
            const line = rawLine.trimEnd();

            if (/^dependencies\s*:/.test(line) || /^dev_dependencies\s*:/.test(line)) {
                inDepsSection = true;
                currentPackage = null;
                inHostedBlock = false;
                continue;
            }

            if (inDepsSection && /^\S/.test(line) && !line.startsWith(' ')) {
                if (!/^dependencies\s*:/.test(line) && !/^dev_dependencies\s*:/.test(line)) {
                    inDepsSection = false;
                    currentPackage = null;
                    inHostedBlock = false;
                    continue;
                }
            }

            if (!inDepsSection) { continue; }

            const packageMatch = line.match(/^  (\w[\w_-]*):\s*$/);
            if (packageMatch) {
                currentPackage = packageMatch[1];
                inHostedBlock = false;
                continue;
            }

            const packageWithValueMatch = line.match(/^  (\w[\w_-]*):\s*\S/);
            if (packageWithValueMatch) {
                currentPackage = null;
                inHostedBlock = false;
                continue;
            }

            if (currentPackage && /^\s{4}hosted\s*:\s*$/.test(line)) {
                inHostedBlock = true;
                continue;
            }

            if (currentPackage && inHostedBlock) {
                const urlMatch = line.match(/^\s{6}url\s*:\s*["']?([^"'\s]+)["']?\s*$/);
                if (urlMatch) {
                    this.hostedDepsCache.set(currentPackage, urlMatch[1]);
                    inHostedBlock = false;
                    currentPackage = null;
                }
            }
        }
    }
}

/**
 * Build request headers for a registry, including auth token if available.
 */
export async function buildRegistryHeaders(
    registryUrl: string,
    registryService: RegistryService,
): Promise<Record<string, string>> {
    const headers: Record<string, string> = {};

    const token = await registryService.getToken(registryUrl);
    if (token) {
        headers['Authorization'] = `Bearer ${token}`;
    }

    return headers;
}

/**
 * Build an API URL for a package on a given registry.
 */
function buildApiUrl(
    registryUrl: string,
    packageName: string,
    suffix = '',
): string {
    const base = registryUrl.replace(/\/$/, '');
    return `${base}/api/packages/${packageName}${suffix}`;
}

/** Build the package info API URL. */
export function buildPackageApiUrl(registryUrl: string, packageName: string): string {
    return buildApiUrl(registryUrl, packageName);
}

/** Build the metrics API URL. */
export function buildMetricsApiUrl(registryUrl: string, packageName: string): string {
    return buildApiUrl(registryUrl, packageName, '/metrics');
}

/** Build the publisher API URL. */
export function buildPublisherApiUrl(registryUrl: string, packageName: string): string {
    return buildApiUrl(registryUrl, packageName, '/publisher');
}

/** Build the score API URL (likes, granted points). */
export function buildScoreApiUrl(registryUrl: string, packageName: string): string {
    return buildApiUrl(registryUrl, packageName, '/score');
}
