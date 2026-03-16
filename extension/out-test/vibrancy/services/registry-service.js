"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
exports.RegistryService = void 0;
exports.buildRegistryHeaders = buildRegistryHeaders;
exports.buildPackageApiUrl = buildPackageApiUrl;
exports.buildMetricsApiUrl = buildMetricsApiUrl;
exports.buildPublisherApiUrl = buildPublisherApiUrl;
const vscode = __importStar(require("vscode"));
const PUB_DEV_URL = 'https://pub.dev';
const SECRET_KEY_PREFIX = 'saropaLints.packageVibrancy.registry.';
/**
 * Service for managing private registry authentication.
 * Tokens are stored securely in VS Code's SecretStorage.
 */
class RegistryService {
    secretStorage;
    disposables = [];
    hostedDepsCache = new Map();
    constructor(secretStorage) {
        this.secretStorage = secretStorage;
    }
    dispose() {
        this.disposables.forEach(d => d.dispose());
    }
    /**
     * Get the registry URL for a package.
     * Priority: pubspec hosted URL > configured registry > pub.dev
     */
    getRegistryForPackage(packageName, pubspecContent) {
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
    isPubDev(registryUrl) {
        return registryUrl === PUB_DEV_URL;
    }
    /**
     * Get authentication token for a registry.
     */
    async getToken(registryUrl) {
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
    async setToken(registryUrl, token) {
        this.validateRegistryUrl(registryUrl);
        const key = SECRET_KEY_PREFIX + registryUrl;
        await this.secretStorage.store(key, token);
    }
    /**
     * Remove authentication token for a registry.
     */
    async removeToken(registryUrl) {
        const key = SECRET_KEY_PREFIX + registryUrl;
        await this.secretStorage.delete(key);
    }
    /**
     * Get all configured registries with their auth status.
     */
    async listRegistries() {
        const config = vscode.workspace.getConfiguration('saropaLints.packageVibrancy');
        const registries = config.get('registries', {});
        const entries = Object.entries(registries);
        const tokenChecks = await Promise.all(entries.map(([url]) => this.getToken(url)));
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
    async addRegistryConfig(url, name) {
        this.validateRegistryUrl(url);
        const config = vscode.workspace.getConfiguration('saropaLints.packageVibrancy');
        const registries = { ...config.get('registries', {}) };
        registries[url] = {
            name,
            packages: [],
        };
        await config.update('registries', registries, vscode.ConfigurationTarget.Global);
    }
    /**
     * Remove a registry configuration from settings.
     */
    async removeRegistryConfig(url) {
        const config = vscode.workspace.getConfiguration('saropaLints.packageVibrancy');
        const registries = { ...config.get('registries', {}) };
        delete registries[url];
        await config.update('registries', registries, vscode.ConfigurationTarget.Global);
    }
    /**
     * Clear the hosted dependencies cache.
     */
    clearCache() {
        this.hostedDepsCache.clear();
    }
    /**
     * Update cache with hosted dependencies from pubspec content.
     */
    updateHostedDepsFromPubspec(pubspecContent) {
        this.parseHostedDeps(pubspecContent);
    }
    /**
     * Get all hosted dependencies detected in the current pubspec.
     */
    getHostedDependencies() {
        return this.hostedDepsCache;
    }
    validateRegistryUrl(url) {
        try {
            const parsed = new URL(url);
            if (parsed.protocol !== 'https:') {
                throw new Error('Registry URL must use HTTPS');
            }
        }
        catch (e) {
            if (e instanceof Error && e.message.includes('HTTPS')) {
                throw e;
            }
            throw new Error(`Invalid registry URL: ${url}`);
        }
    }
    getConfiguredRegistry(packageName) {
        const config = vscode.workspace.getConfiguration('saropaLints.packageVibrancy');
        const registries = config.get('registries', {});
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
    parseHostedDeps(content) {
        const lines = content.split('\n');
        let inDepsSection = false;
        let currentPackage = null;
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
            if (!inDepsSection) {
                continue;
            }
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
exports.RegistryService = RegistryService;
/**
 * Build request headers for a registry, including auth token if available.
 */
async function buildRegistryHeaders(registryUrl, registryService) {
    const headers = {};
    const token = await registryService.getToken(registryUrl);
    if (token) {
        headers['Authorization'] = `Bearer ${token}`;
    }
    return headers;
}
/**
 * Build an API URL for a package on a given registry.
 */
function buildApiUrl(registryUrl, packageName, suffix = '') {
    const base = registryUrl.replace(/\/$/, '');
    return `${base}/api/packages/${packageName}${suffix}`;
}
/** Build the package info API URL. */
function buildPackageApiUrl(registryUrl, packageName) {
    return buildApiUrl(registryUrl, packageName);
}
/** Build the metrics API URL. */
function buildMetricsApiUrl(registryUrl, packageName) {
    return buildApiUrl(registryUrl, packageName, '/metrics');
}
/** Build the publisher API URL. */
function buildPublisherApiUrl(registryUrl, packageName) {
    return buildApiUrl(registryUrl, packageName, '/publisher');
}
//# sourceMappingURL=registry-service.js.map