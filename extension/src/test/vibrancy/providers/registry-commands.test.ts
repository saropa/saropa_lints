import * as assert from 'assert';
import * as sinon from 'sinon';
import { MockSecretStorage } from '../vscode-mock';
import { RegistryService } from '../../../vibrancy/services/registry-service';

describe('Registry Commands', () => {
    let secretStorage: MockSecretStorage;
    let service: RegistryService;

    beforeEach(() => {
        secretStorage = new MockSecretStorage();
        service = new RegistryService(secretStorage as any);
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
            await assert.rejects(
                () => service.setToken('http://insecure.example.com', 'token'),
                /must use HTTPS/,
            );
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
            await assert.rejects(
                () => service.setToken('not-a-url', 'token'),
                /Invalid registry URL/,
            );
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
