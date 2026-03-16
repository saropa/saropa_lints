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
const vscode_mock_1 = require("../vscode-mock");
const registry_service_1 = require("../../../vibrancy/services/registry-service");
describe('RegistryService', () => {
    let secretStorage;
    let service;
    beforeEach(() => {
        secretStorage = new vscode_mock_1.MockSecretStorage();
        service = new registry_service_1.RegistryService(secretStorage);
    });
    afterEach(() => {
        service.dispose();
    });
    describe('getRegistryForPackage', () => {
        it('should default to pub.dev for unknown packages', () => {
            const result = service.getRegistryForPackage('some_package');
            assert.strictEqual(result, 'https://pub.dev');
        });
        it('should detect hosted URL from pubspec.yaml', () => {
            const pubspec = `
dependencies:
  my_private_pkg:
    hosted:
      url: https://pub.internal.company.com
    version: ^1.0.0
  public_pkg: ^2.0.0
`;
            const result = service.getRegistryForPackage('my_private_pkg', pubspec);
            assert.strictEqual(result, 'https://pub.internal.company.com');
        });
        it('should return pub.dev for packages without hosted URL', () => {
            const pubspec = `
dependencies:
  my_private_pkg:
    hosted:
      url: https://pub.internal.company.com
    version: ^1.0.0
  public_pkg: ^2.0.0
`;
            const result = service.getRegistryForPackage('public_pkg', pubspec);
            assert.strictEqual(result, 'https://pub.dev');
        });
        it('should cache hosted dependencies', () => {
            const pubspec = `
dependencies:
  private_a:
    hosted:
      url: https://pub.example.com
    version: ^1.0.0
`;
            service.getRegistryForPackage('private_a', pubspec);
            const result = service.getRegistryForPackage('private_a');
            assert.strictEqual(result, 'https://pub.example.com');
        });
    });
    describe('isPubDev', () => {
        it('should return true for pub.dev', () => {
            assert.strictEqual(service.isPubDev('https://pub.dev'), true);
        });
        it('should return false for other URLs', () => {
            assert.strictEqual(service.isPubDev('https://pub.internal.com'), false);
        });
    });
    describe('token management', () => {
        it('should return null for pub.dev tokens', async () => {
            await service.setToken('https://other.com', 'test-token');
            const token = await service.getToken('https://pub.dev');
            assert.strictEqual(token, null);
        });
        it('should store and retrieve tokens', async () => {
            await service.setToken('https://pub.internal.com', 'my-secret-token');
            const token = await service.getToken('https://pub.internal.com');
            assert.strictEqual(token, 'my-secret-token');
        });
        it('should return null for unknown registries', async () => {
            const token = await service.getToken('https://unknown.com');
            assert.strictEqual(token, null);
        });
        it('should remove tokens', async () => {
            await service.setToken('https://pub.internal.com', 'my-token');
            await service.removeToken('https://pub.internal.com');
            const token = await service.getToken('https://pub.internal.com');
            assert.strictEqual(token, null);
        });
        it('should reject non-HTTPS URLs', async () => {
            await assert.rejects(() => service.setToken('http://insecure.com', 'token'), /must use HTTPS/);
        });
        it('should reject invalid URLs', async () => {
            await assert.rejects(() => service.setToken('not-a-url', 'token'), /Invalid registry URL/);
        });
    });
    describe('clearCache', () => {
        it('should clear hosted deps cache', () => {
            const pubspec = `
dependencies:
  private_pkg:
    hosted:
      url: https://private.example.com
    version: ^1.0.0
`;
            service.getRegistryForPackage('private_pkg', pubspec);
            assert.strictEqual(service.getRegistryForPackage('private_pkg'), 'https://private.example.com');
            service.clearCache();
            assert.strictEqual(service.getRegistryForPackage('private_pkg'), 'https://pub.dev');
        });
    });
    describe('getHostedDependencies', () => {
        it('should return all detected hosted deps', () => {
            const pubspec = `
dependencies:
  pkg_a:
    hosted:
      url: https://registry-a.com
    version: ^1.0.0
  pkg_b:
    hosted:
      url: https://registry-b.com
    version: ^2.0.0
  public_pkg: ^3.0.0
`;
            service.updateHostedDepsFromPubspec(pubspec);
            const hosted = service.getHostedDependencies();
            assert.strictEqual(hosted.size, 2);
            assert.strictEqual(hosted.get('pkg_a'), 'https://registry-a.com');
            assert.strictEqual(hosted.get('pkg_b'), 'https://registry-b.com');
        });
    });
    describe('hosted URL parsing edge cases', () => {
        it('should handle quoted URLs', () => {
            const pubspec = `
dependencies:
  my_pkg:
    hosted:
      url: "https://quoted.example.com"
    version: ^1.0.0
`;
            const result = service.getRegistryForPackage('my_pkg', pubspec);
            assert.strictEqual(result, 'https://quoted.example.com');
        });
        it('should handle single-quoted URLs', () => {
            const pubspec = `
dependencies:
  my_pkg:
    hosted:
      url: 'https://single-quoted.example.com'
    version: ^1.0.0
`;
            const result = service.getRegistryForPackage('my_pkg', pubspec);
            assert.strictEqual(result, 'https://single-quoted.example.com');
        });
        it('should handle dev_dependencies section', () => {
            const pubspec = `
dev_dependencies:
  test_pkg:
    hosted:
      url: https://dev-registry.example.com
    version: ^1.0.0
`;
            const result = service.getRegistryForPackage('test_pkg', pubspec);
            assert.strictEqual(result, 'https://dev-registry.example.com');
        });
        it('should not match packages in other sections', () => {
            const pubspec = `
name: my_app
version: 1.0.0

dependency_overrides:
  override_pkg:
    path: ../local

dependencies:
  real_pkg: ^1.0.0
`;
            const result = service.getRegistryForPackage('real_pkg', pubspec);
            assert.strictEqual(result, 'https://pub.dev');
        });
    });
});
//# sourceMappingURL=registry-service.test.js.map