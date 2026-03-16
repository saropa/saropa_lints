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
const assert = __importStar(require("assert"));
const detail_view_provider_1 = require("../../../vibrancy/views/detail-view-provider");
const vscode = __importStar(require("vscode"));
function makeResult(name, score, category = 'vibrant') {
    return {
        package: { name, version: '1.0.0', constraint: '^1.0.0', source: 'hosted', isDirect: true, section: 'dependencies' },
        pubDev: null,
        github: null,
        knownIssue: null,
        score,
        category,
        resolutionVelocity: 50,
        engagementLevel: 40,
        popularity: 30,
        publisherTrust: 0,
        updateInfo: null,
        archiveSizeBytes: null,
        bloatRating: null,
        license: null,
        drift: null,
        isUnused: false,
        platforms: null,
        verifiedPublisher: false,
        wasmReady: null,
        blocker: null,
        upgradeBlockStatus: 'up-to-date',
        transitiveInfo: null,
        alternatives: [],
        latestPrerelease: null,
        prereleaseTag: null,
        vulnerabilities: [],
    };
}
describe('DetailViewProvider', () => {
    it('should export correct view ID', () => {
        assert.strictEqual(detail_view_provider_1.DETAIL_VIEW_ID, 'saropaLints.packageVibrancy.details');
    });
    it('should create provider with extension URI', () => {
        const mockUri = vscode.Uri.parse('file:///test');
        const provider = new detail_view_provider_1.DetailViewProvider(mockUri);
        assert.ok(provider);
    });
    it('should return null for current result initially', () => {
        const mockUri = vscode.Uri.parse('file:///test');
        const provider = new detail_view_provider_1.DetailViewProvider(mockUri);
        assert.strictEqual(provider.getCurrentResult(), null);
    });
    it('should update current result on update()', () => {
        const mockUri = vscode.Uri.parse('file:///test');
        const provider = new detail_view_provider_1.DetailViewProvider(mockUri);
        const result = makeResult('http', 80);
        provider.update(result);
        assert.strictEqual(provider.getCurrentResult(), result);
    });
    it('should clear current result on clear()', () => {
        const mockUri = vscode.Uri.parse('file:///test');
        const provider = new detail_view_provider_1.DetailViewProvider(mockUri);
        const result = makeResult('http', 80);
        provider.update(result);
        assert.strictEqual(provider.getCurrentResult(), result);
        provider.clear();
        assert.strictEqual(provider.getCurrentResult(), null);
    });
    it('should handle multiple update calls', () => {
        const mockUri = vscode.Uri.parse('file:///test');
        const provider = new detail_view_provider_1.DetailViewProvider(mockUri);
        const result1 = makeResult('http', 80);
        const result2 = makeResult('bloc', 60);
        provider.update(result1);
        assert.strictEqual(provider.getCurrentResult()?.package.name, 'http');
        provider.update(result2);
        assert.strictEqual(provider.getCurrentResult()?.package.name, 'bloc');
    });
    it('should implement WebviewViewProvider interface', () => {
        const mockUri = vscode.Uri.parse('file:///test');
        const provider = new detail_view_provider_1.DetailViewProvider(mockUri);
        assert.ok(typeof provider.resolveWebviewView === 'function');
        assert.ok(typeof provider.update === 'function');
        assert.ok(typeof provider.clear === 'function');
        assert.ok(typeof provider.focus === 'function');
    });
});
//# sourceMappingURL=detail-view-provider.test.js.map