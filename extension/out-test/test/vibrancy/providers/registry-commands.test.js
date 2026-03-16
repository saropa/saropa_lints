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
const sinon = __importStar(require("sinon"));
const vscode_mock_1 = require("../vscode-mock");
const registry_service_1 = require("../../../vibrancy/services/registry-service");
describe('Registry Commands', () => {
    let secretStorage;
    let service;
    beforeEach(() => {
        secretStorage = new vscode_mock_1.MockSecretStorage();
        service = new registry_service_1.RegistryService(secretStorage);
    });
    afterEach(() => {
        service.dispose();
        sinon.restore();
    });
    describe('Token management', () => {
        it('should store and retrieve tokens', async () => {
            await service.setToken('https://pub.example.com', 'test-token');
            const token = await service.getToken('https://pub.example.com');
            assert.strictEqual(token, 'test-token');
        });
        it('should remove tokens', async () => {
            await service.setToken('https://pub.example.com', 'test-token');
            await service.removeToken('https://pub.example.com');
            const token = await service.getToken('https://pub.example.com');
            assert.strictEqual(token, null);
        });
        it('should update token for existing registry', async () => {
            await service.setToken('https://pub.example.com', 'old-token');
            await service.setToken('https://pub.example.com', 'new-token');
            const token = await service.getToken('https://pub.example.com');
            assert.strictEqual(token, 'new-token');
        });
        it('should reject HTTP URLs for security', async () => {
            await assert.rejects(() => service.setToken('http://insecure.example.com', 'token'), /must use HTTPS/);
        });
        it('should handle multiple registries independently', async () => {
            await service.setToken('https://registry-a.com', 'token-a');
            await service.setToken('https://registry-b.com', 'token-b');
            assert.strictEqual(await service.getToken('https://registry-a.com'), 'token-a');
            assert.strictEqual(await service.getToken('https://registry-b.com'), 'token-b');
            await service.removeToken('https://registry-a.com');
            assert.strictEqual(await service.getToken('https://registry-a.com'), null);
            assert.strictEqual(await service.getToken('https://registry-b.com'), 'token-b');
        });
    });
    describe('Registry URL validation', () => {
        it('should accept valid HTTPS URLs', async () => {
            await service.setToken('https://valid.example.com', 'token');
            assert.strictEqual(await service.getToken('https://valid.example.com'), 'token');
        });
        it('should accept HTTPS URLs with ports', async () => {
            await service.setToken('https://valid.example.com:8443', 'token');
            assert.strictEqual(await service.getToken('https://valid.example.com:8443'), 'token');
        });
        it('should accept HTTPS URLs with paths', async () => {
            await service.setToken('https://valid.example.com/pub', 'token');
            assert.strictEqual(await service.getToken('https://valid.example.com/pub'), 'token');
        });
        it('should reject invalid URLs', async () => {
            await assert.rejects(() => service.setToken('not-a-url', 'token'), /Invalid registry URL/);
        });
    });
    describe('pub.dev handling', () => {
        it('should never return token for pub.dev', async () => {
            const token = await service.getToken('https://pub.dev');
            assert.strictEqual(token, null);
        });
        it('should identify pub.dev correctly', () => {
            assert.strictEqual(service.isPubDev('https://pub.dev'), true);
            assert.strictEqual(service.isPubDev('https://other.com'), false);
        });
    });
});
//# sourceMappingURL=registry-commands.test.js.map