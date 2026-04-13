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

    describe('getGroupKey logic', () => {
        // Mirror the getGroupKey function from pubspec-sorter.ts
        function getGroupKey(name: string, allNames: Set<string>): string {
            const parts = name.split('_');
            for (let i = 1; i < parts.length; i++) {
                const prefix = parts.slice(0, i).join('_');
                if (allNames.has(prefix) && prefix !== name) {
                    return prefix;
                }
            }
            return name;
        }

        it('should group drift_flutter with drift', () => {
            const names = new Set(['drift', 'drift_flutter', 'http']);
            assert.strictEqual(getGroupKey('drift_flutter', names), 'drift');
        });

        it('should group drift_dev with drift', () => {
            const names = new Set(['drift', 'drift_dev', 'http']);
            assert.strictEqual(getGroupKey('drift_dev', names), 'drift');
        });

        it('should return name itself when no prefix match', () => {
            const names = new Set(['http', 'provider', 'dio']);
            assert.strictEqual(getGroupKey('http', names), 'http');
        });

        it('should not group with itself', () => {
            const names = new Set(['drift']);
            assert.strictEqual(getGroupKey('drift', names), 'drift');
        });

        it('should not group unrelated packages', () => {
            const names = new Set(['http', 'http_parser', 'provider']);
            // http_parser groups with http
            assert.strictEqual(getGroupKey('http_parser', names), 'http');
            // provider is standalone
            assert.strictEqual(getGroupKey('provider', names), 'provider');
        });

        it('should find shortest prefix match', () => {
            // If both 'a' and 'a_b' exist, 'a_b_c' groups with 'a' (shortest)
            const names = new Set(['a', 'a_b', 'a_b_c']);
            assert.strictEqual(getGroupKey('a_b_c', names), 'a');
        });
    });

    describe('buildSortedLines blank-line insertion', () => {
        // Mirror the buildSortedLines + getGroupKey logic from pubspec-sorter.ts
        // to verify before/after blank-line behavior
        interface Entry { name: string; lines: string[]; isSdk: boolean }

        function getGroupKey(name: string, allNames: Set<string>): string {
            const parts = name.split('_');
            for (let i = 1; i < parts.length; i++) {
                const prefix = parts.slice(0, i).join('_');
                if (allNames.has(prefix) && prefix !== name) {
                    return prefix;
                }
            }
            return name;
        }

        function buildSortedLines(entries: Entry[], sdkFirst: boolean): string[] {
            if (entries.length === 0) { return []; }
            const nonSdkNames = new Set(
                entries.filter(e => !e.isSdk).map(e => e.name),
            );
            const result: string[] = [...entries[0].lines];
            for (let i = 1; i < entries.length; i++) {
                const prev = entries[i - 1];
                const curr = entries[i];
                let needsBlankLine: boolean;
                if (sdkFirst && prev.isSdk !== curr.isSdk) {
                    needsBlankLine = true;
                } else if (prev.isSdk && curr.isSdk) {
                    needsBlankLine = false;
                } else {
                    const prevKey = getGroupKey(prev.name, nonSdkNames);
                    const currKey = getGroupKey(curr.name, nonSdkNames);
                    needsBlankLine = prevKey !== currKey;
                }
                if (needsBlankLine) { result.push(''); }
                result.push(...curr.lines);
            }
            return result;
        }

        function makeEntry(name: string, isSdk = false): Entry {
            return { name, lines: [`  ${name}: ^1.0.0`], isSdk };
        }

        it('should insert blank lines between unrelated packages', () => {
            const entries = [
                makeEntry('dio'),
                makeEntry('http'),
                makeEntry('provider'),
            ];
            const lines = buildSortedLines(entries, true);
            assert.deepStrictEqual(lines, [
                '  dio: ^1.0.0',
                '',
                '  http: ^1.0.0',
                '',
                '  provider: ^1.0.0',
            ]);
        });

        it('should NOT insert blank line between grouped packages', () => {
            const entries = [
                makeEntry('drift'),
                makeEntry('drift_dev'),
                makeEntry('drift_flutter'),
            ];
            const lines = buildSortedLines(entries, true);
            // All drift_* packages share group key 'drift' — no separators
            assert.deepStrictEqual(lines, [
                '  drift: ^1.0.0',
                '  drift_dev: ^1.0.0',
                '  drift_flutter: ^1.0.0',
            ]);
        });

        it('should separate SDK from non-SDK with blank line', () => {
            const entries = [
                makeEntry('flutter', true),
                makeEntry('flutter_test', true),
                makeEntry('dio'),
                makeEntry('http'),
            ];
            const lines = buildSortedLines(entries, true);
            assert.deepStrictEqual(lines, [
                '  flutter: ^1.0.0',
                '  flutter_test: ^1.0.0',
                '',
                '  dio: ^1.0.0',
                '',
                '  http: ^1.0.0',
            ]);
        });

        it('should mix grouped and ungrouped correctly', () => {
            const entries = [
                makeEntry('drift'),
                makeEntry('drift_flutter'),
                makeEntry('http'),
                makeEntry('intl'),
            ];
            const lines = buildSortedLines(entries, true);
            assert.deepStrictEqual(lines, [
                '  drift: ^1.0.0',
                '  drift_flutter: ^1.0.0',
                '',
                '  http: ^1.0.0',
                '',
                '  intl: ^1.0.0',
            ]);
        });

        it('should return empty array for empty input', () => {
            assert.deepStrictEqual(buildSortedLines([], true), []);
        });

        it('should return single entry without blank lines', () => {
            const lines = buildSortedLines([makeEntry('http')], true);
            assert.deepStrictEqual(lines, ['  http: ^1.0.0']);
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
