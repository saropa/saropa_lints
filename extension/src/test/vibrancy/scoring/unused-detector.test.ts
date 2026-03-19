import * as assert from 'node:assert';
import { detectUnused } from '../../../vibrancy/scoring/unused-detector';

describe('unused-detector', () => {
    describe('detectUnused', () => {
        it('should return empty when all deps are imported', () => {
            const declared = ['http', 'provider', 'intl'];
            const imported = new Set(['http', 'provider', 'intl']);
            assert.deepStrictEqual(detectUnused(declared, imported), []);
        });

        it('should flag deps with no matching import', () => {
            const declared = ['http', 'provider', 'intl'];
            const imported = new Set(['http']);
            const result = detectUnused(declared, imported);
            assert.deepStrictEqual(result, ['provider', 'intl']);
        });

        it('should return empty for empty declared list', () => {
            assert.deepStrictEqual(detectUnused([], new Set(['http'])), []);
        });

        it('should flag all deps when no imports exist', () => {
            const declared = ['http', 'provider'];
            const result = detectUnused(declared, new Set());
            assert.deepStrictEqual(result, ['http', 'provider']);
        });

        it('should skip flutter SDK packages', () => {
            const declared = ['flutter', 'flutter_test', 'flutter_localizations'];
            const result = detectUnused(declared, new Set());
            assert.deepStrictEqual(result, []);
        });

        it('should skip flutter_web_plugins and flutter_driver', () => {
            const declared = ['flutter_web_plugins', 'flutter_driver'];
            const result = detectUnused(declared, new Set());
            assert.deepStrictEqual(result, []);
        });

        it('should skip platform plugin packages', () => {
            const declared = [
                'url_launcher_android', 'url_launcher_ios',
                'url_launcher_web', 'url_launcher_windows',
                'url_launcher_macos', 'url_launcher_linux',
                'url_launcher_platform_interface',
            ];
            const result = detectUnused(declared, new Set());
            assert.deepStrictEqual(result, []);
        });

        it('should skip non-standard platform plugins when parent is imported', () => {
            const declared = [
                'google_maps_flutter_ios_sdk10',
                'webview_flutter_wkwebview',
                'path_provider_foundation',
                'camera_android_camerax',
                'video_player_avfoundation',
            ];
            const imported = new Set([
                'google_maps_flutter',
                'webview_flutter',
                'path_provider',
                'camera',
                'video_player',
            ]);
            const result = detectUnused(declared, imported);
            assert.deepStrictEqual(result, []);
        });

        it('should still flag packages with similar prefix but no imported parent', () => {
            const declared = ['google_maps_flutter_ios_sdk10'];
            const imported = new Set<string>();  // parent NOT imported
            const result = detectUnused(declared, imported);
            assert.deepStrictEqual(result, ['google_maps_flutter_ios_sdk10']);
        });

        it('should document a prefix-collision false negative (http_parser)', () => {
            const declared = ['http_parser'];
            const imported = new Set(['http']);
            const result = detectUnused(declared, imported);
            assert.deepStrictEqual(result, []);
        });

        it('should flag non-platform packages that end with similar suffixes', () => {
            const declared = ['my_android_utils'];
            const result = detectUnused(declared, new Set());
            assert.deepStrictEqual(result, ['my_android_utils']);
        });

        it('should not flag SDK packages even when imported', () => {
            const declared = ['flutter', 'http'];
            const imported = new Set(['http']);
            const result = detectUnused(declared, imported);
            assert.deepStrictEqual(result, []);
        });
    });
});
