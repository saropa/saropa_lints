import * as assert from 'assert';

describe('pubspec-sorter', () => {
    describe('SDK_PACKAGES detection', () => {
        const SDK_PACKAGES = new Set([
            'flutter', 'flutter_test', 'flutter_localizations', 'flutter_web_plugins',
        ]);

        it('should recognize flutter as SDK package', () => {
            assert.ok(SDK_PACKAGES.has('flutter'));
        });

        it('should recognize flutter_test as SDK package', () => {
            assert.ok(SDK_PACKAGES.has('flutter_test'));
        });

        it('should not recognize http as SDK package', () => {
            assert.ok(!SDK_PACKAGES.has('http'));
        });
    });

    describe('sorting logic', () => {
        interface Entry { name: string; isSdk: boolean }

        function sortEntries(entries: Entry[], sdkFirst: boolean): Entry[] {
            return [...entries].sort((a, b) => {
                if (sdkFirst) {
                    if (a.isSdk && !b.isSdk) { return -1; }
                    if (!a.isSdk && b.isSdk) { return 1; }
                }
                return a.name.toLowerCase().localeCompare(b.name.toLowerCase());
            });
        }

        it('should sort alphabetically', () => {
            const entries: Entry[] = [
                { name: 'provider', isSdk: false },
                { name: 'http', isSdk: false },
                { name: 'dio', isSdk: false },
            ];
            const sorted = sortEntries(entries, false);
            assert.deepStrictEqual(
                sorted.map(e => e.name),
                ['dio', 'http', 'provider'],
            );
        });

        it('should keep SDK packages first when sdkFirst is true', () => {
            const entries: Entry[] = [
                { name: 'provider', isSdk: false },
                { name: 'flutter', isSdk: true },
                { name: 'dio', isSdk: false },
            ];
            const sorted = sortEntries(entries, true);
            assert.deepStrictEqual(
                sorted.map(e => e.name),
                ['flutter', 'dio', 'provider'],
            );
        });

        it('should sort SDK packages among themselves when sdkFirst is true', () => {
            const entries: Entry[] = [
                { name: 'flutter_test', isSdk: true },
                { name: 'flutter', isSdk: true },
                { name: 'http', isSdk: false },
            ];
            const sorted = sortEntries(entries, true);
            assert.deepStrictEqual(
                sorted.map(e => e.name),
                ['flutter', 'flutter_test', 'http'],
            );
        });

        it('should be case-insensitive', () => {
            const entries: Entry[] = [
                { name: 'Provider', isSdk: false },
                { name: 'http', isSdk: false },
                { name: 'Dio', isSdk: false },
            ];
            const sorted = sortEntries(entries, false);
            assert.deepStrictEqual(
                sorted.map(e => e.name),
                ['Dio', 'http', 'Provider'],
            );
        });
    });
});
