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
exports.registerRegistryCommands = registerRegistryCommands;
const vscode = __importStar(require("vscode"));
/**
 * Register registry authentication commands.
 */
function registerRegistryCommands(context, registryService) {
    context.subscriptions.push(vscode.commands.registerCommand('saropaLints.packageVibrancy.addRegistryAuth', () => addRegistryAuth(registryService)), vscode.commands.registerCommand('saropaLints.packageVibrancy.removeRegistryAuth', () => removeRegistryAuth(registryService)), vscode.commands.registerCommand('saropaLints.packageVibrancy.listRegistries', () => listRegistries(registryService)));
}
async function addRegistryAuth(registryService) {
    const url = await vscode.window.showInputBox({
        title: 'Add Registry Authentication (1/3)',
        prompt: 'Enter the registry URL',
        placeHolder: 'https://pub.internal.company.com',
        validateInput: (value) => {
            if (!value.trim()) {
                return 'URL is required';
            }
            try {
                const parsed = new URL(value);
                if (parsed.protocol !== 'https:') {
                    return 'Registry URL must use HTTPS for security';
                }
            }
            catch {
                return 'Invalid URL format';
            }
            return null;
        },
    });
    if (!url) {
        return;
    }
    const name = await vscode.window.showInputBox({
        title: 'Add Registry Authentication (2/3)',
        prompt: 'Enter a display name for this registry (optional)',
        placeHolder: 'Internal Pub',
        value: new URL(url).hostname,
    });
    if (name === undefined) {
        return;
    }
    const token = await vscode.window.showInputBox({
        title: 'Add Registry Authentication (3/3)',
        prompt: 'Enter the authentication token',
        placeHolder: 'Your API token or access key',
        password: true,
        validateInput: (value) => {
            if (!value.trim()) {
                return 'Token is required';
            }
            return null;
        },
    });
    if (!token) {
        return;
    }
    try {
        await registryService.addRegistryConfig(url, name || new URL(url).hostname);
        await registryService.setToken(url, token);
        const displayName = name || new URL(url).hostname;
        vscode.window.showInformationMessage(`✓ Added authentication for ${displayName}`);
    }
    catch (err) {
        const message = err instanceof Error ? err.message : 'Unknown error';
        vscode.window.showErrorMessage(`Failed to add registry: ${message}`);
    }
}
async function removeRegistryAuth(registryService) {
    const registries = await registryService.listRegistries();
    if (registries.length === 0) {
        vscode.window.showInformationMessage('No configured registries');
        return;
    }
    const items = registries.map(r => ({
        label: `$(${r.hasToken ? 'lock' : 'unlock'}) ${r.name}`,
        description: r.url,
        detail: r.hasToken ? 'Authenticated' : 'No authentication',
    }));
    const selection = await vscode.window.showQuickPick(items, {
        title: 'Remove Registry Authentication',
        placeHolder: 'Select a registry to remove',
    });
    if (!selection) {
        return;
    }
    const selectedUrl = selection.description;
    const selectedName = selection.label.replace(/^\$\([^)]+\)\s*/, '');
    const confirm = await vscode.window.showWarningMessage(`Remove authentication for ${selectedName}?`, { modal: true }, 'Remove');
    if (confirm !== 'Remove') {
        return;
    }
    try {
        await registryService.removeToken(selectedUrl);
        await registryService.removeRegistryConfig(selectedUrl);
        vscode.window.showInformationMessage(`✓ Removed authentication for ${selectedName}`);
    }
    catch (err) {
        const message = err instanceof Error ? err.message : 'Unknown error';
        vscode.window.showErrorMessage(`Failed to remove registry: ${message}`);
    }
}
async function listRegistries(registryService) {
    const registries = await registryService.listRegistries();
    const items = [
        {
            label: '$(globe) pub.dev',
            description: 'https://pub.dev',
            detail: 'Default registry (no authentication required)',
        },
        ...registries.map(r => ({
            label: `$(${r.hasToken ? 'lock' : 'unlock'}) ${r.name}`,
            description: r.url,
            detail: r.hasToken
                ? `Authenticated${r.packages.length > 0 ? ` • ${r.packages.length} package(s)` : ''}`
                : `No authentication${r.packages.length > 0 ? ` • ${r.packages.length} package(s)` : ''}`,
        })),
    ];
    const selection = await vscode.window.showQuickPick(items, {
        title: 'Configured Registries',
        placeHolder: registries.length === 0
            ? 'Only pub.dev is configured. Use "Add Registry Authentication" to add private registries.'
            : 'Select a registry to manage',
    });
    if (!selection || selection.description === 'https://pub.dev') {
        return;
    }
    const actions = [
        { label: '$(trash) Remove authentication', description: 'Delete credentials and configuration' },
        { label: '$(key) Update token', description: 'Replace the authentication token' },
    ];
    const action = await vscode.window.showQuickPick(actions, {
        title: `Manage ${selection.label.replace(/^\$\([^)]+\)\s*/, '')}`,
        placeHolder: 'Select an action',
    });
    if (!action) {
        return;
    }
    const selectedUrl = selection.description;
    if (action.label.includes('Remove')) {
        const selectedName = selection.label.replace(/^\$\([^)]+\)\s*/, '');
        const confirm = await vscode.window.showWarningMessage(`Remove authentication for ${selectedName}?`, { modal: true }, 'Remove');
        if (confirm === 'Remove') {
            try {
                await registryService.removeToken(selectedUrl);
                await registryService.removeRegistryConfig(selectedUrl);
                vscode.window.showInformationMessage(`✓ Removed authentication for ${selectedName}`);
            }
            catch (err) {
                const message = err instanceof Error ? err.message : 'Unknown error';
                vscode.window.showErrorMessage(`Failed to remove registry: ${message}`);
            }
        }
    }
    else if (action.label.includes('Update')) {
        const newToken = await vscode.window.showInputBox({
            title: 'Update Authentication Token',
            prompt: 'Enter the new authentication token',
            password: true,
            validateInput: (value) => {
                if (!value.trim()) {
                    return 'Token is required';
                }
                return null;
            },
        });
        if (newToken) {
            try {
                await registryService.setToken(selectedUrl, newToken);
                vscode.window.showInformationMessage('✓ Token updated');
            }
            catch (err) {
                const message = err instanceof Error ? err.message : 'Unknown error';
                vscode.window.showErrorMessage(`Failed to update token: ${message}`);
            }
        }
    }
}
//# sourceMappingURL=registry-commands.js.map