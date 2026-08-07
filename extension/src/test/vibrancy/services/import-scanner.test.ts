/**
 * Module overview (comment coverage pass).
 * comment-coverage: module overview (batch).
 *
 * Extension Jest tests: validates commands, webviews, parsers, and state against VS Code APIs (often with local mocks).
 */

import * as assert from 'assert';
import * as vscode from 'vscode';
import {
    scanDartImports,
    scanDartImportsDetailed,
    activePackageNames,
    activeFileUsages,
    hasActiveReExport,
    collectSymbolOccurrences,
    DartSource,
    PackageUsage,
} from '../../../vibrancy/services/import-scanner';

function makeUri(path: string): vscode.Uri {
    return vscode.Uri.file(path) as vscode.Uri;
}

function encode(text: string): Uint8Array {
    return new TextEncoder().encode(text);
}

// Shared setup/teardown for tests that mock vscode.workspace
function stubWorkspace() {
    const originalFindFiles = vscode.workspace.findFiles;
    const originalReadFile = vscode.workspace.fs.readFile;
    return {
        restore() {
            (vscode.workspace as any).findFiles = originalFindFiles;
            (vscode.workspace as any).fs.readFile = originalReadFile;
        },
    };
}

describe('scanDartImports', () => {
    let env: ReturnType<typeof stubWorkspace>;
    beforeEach(() => { env = stubWorkspace(); });
    afterEach(() => env.restore());

    it('should detect standard package imports', async () => {
        const files = [makeUri('/proj/lib/main.dart')];
        (vscode.workspace as any).findFiles = async () => files;
        (vscode.workspace as any).fs.readFile = async () =>
            encode("import 'package:http/http.dart';");

        const result = await scanDartImports(makeUri('/proj'));
        assert.ok(result.has('http'));
        assert.strictEqual(result.size, 1);
    });

    it('should detect sub-path imports (e.g. html/dom.dart)', async () => {
        const files = [makeUri('/proj/lib/parser.dart')];
        (vscode.workspace as any).findFiles = async () => files;
        (vscode.workspace as any).fs.readFile = async () =>
            encode("import 'package:html/dom.dart';");

        const result = await scanDartImports(makeUri('/proj'));
        assert.ok(result.has('html'), 'sub-path import html/dom.dart must detect package html');
        assert.strictEqual(result.size, 1);
    });

    it('should detect imports with show/hide', async () => {
        const files = [makeUri('/proj/lib/main.dart')];
        (vscode.workspace as any).findFiles = async () => files;
        (vscode.workspace as any).fs.readFile = async () =>
            encode("import 'package:bloc/bloc.dart' show Bloc;");

        const result = await scanDartImports(makeUri('/proj'));
        assert.ok(result.has('bloc'));
    });

    it('should detect double-quoted imports', async () => {
        const files = [makeUri('/proj/lib/main.dart')];
        (vscode.workspace as any).findFiles = async () => files;
        (vscode.workspace as any).fs.readFile = async () =>
            encode('import "package:provider/provider.dart";');

        const result = await scanDartImports(makeUri('/proj'));
        assert.ok(result.has('provider'));
    });

    it('should ignore relative imports', async () => {
        const files = [makeUri('/proj/lib/main.dart')];
        (vscode.workspace as any).findFiles = async () => files;
        (vscode.workspace as any).fs.readFile = async () =>
            encode("import '../models/user.dart';");

        const result = await scanDartImports(makeUri('/proj'));
        assert.strictEqual(result.size, 0);
    });

    it('should ignore dart: SDK imports', async () => {
        const files = [makeUri('/proj/lib/main.dart')];
        (vscode.workspace as any).findFiles = async () => files;
        (vscode.workspace as any).fs.readFile = async () =>
            encode("import 'dart:core';");

        const result = await scanDartImports(makeUri('/proj'));
        assert.strictEqual(result.size, 0);
    });

    it('should return empty set for empty project', async () => {
        (vscode.workspace as any).findFiles = async () => [];

        const result = await scanDartImports(makeUri('/proj'));
        assert.strictEqual(result.size, 0);
    });

    it('should deduplicate imports across files', async () => {
        const files = [
            makeUri('/proj/lib/a.dart'),
            makeUri('/proj/lib/b.dart'),
        ];
        (vscode.workspace as any).findFiles = async () => files;
        let callCount = 0;
        (vscode.workspace as any).fs.readFile = async () => {
            callCount++;
            return encode("import 'package:http/http.dart';");
        };

        const result = await scanDartImports(makeUri('/proj'));
        assert.strictEqual(result.size, 1);
        assert.strictEqual(callCount, 2);
    });

    it('should detect export directives as usage', async () => {
        const files = [makeUri('/proj/lib/native/fix.dart')];
        (vscode.workspace as any).findFiles = async () => files;
        (vscode.workspace as any).fs.readFile = async () =>
            encode("export 'package:analyzer_plugin/utilities/fixes/fixes.dart' show FixKind;");

        const result = await scanDartImports(makeUri('/proj'));
        assert.ok(result.has('analyzer_plugin'));
        assert.strictEqual(result.size, 1);
    });

    it('should detect mixed imports and exports', async () => {
        const files = [makeUri('/proj/lib/main.dart')];
        (vscode.workspace as any).findFiles = async () => files;
        (vscode.workspace as any).fs.readFile = async () =>
            encode(
                "import 'package:http/http.dart';\n"
                + "export 'package:provider/provider.dart';",
            );

        const result = await scanDartImports(makeUri('/proj'));
        assert.strictEqual(result.size, 2);
        assert.ok(result.has('http'));
        assert.ok(result.has('provider'));
    });

    it('should collect multiple packages from one file', async () => {
        const files = [makeUri('/proj/lib/main.dart')];
        (vscode.workspace as any).findFiles = async () => files;
        (vscode.workspace as any).fs.readFile = async () =>
            encode(
                "import 'package:http/http.dart';\n"
                + "import 'package:bloc/bloc.dart';\n"
                + "import 'package:provider/provider.dart';",
            );

        const result = await scanDartImports(makeUri('/proj'));
        assert.strictEqual(result.size, 3);
        assert.ok(result.has('http'));
        assert.ok(result.has('bloc'));
        assert.ok(result.has('provider'));
    });

    it('should NOT include commented-only packages in active set', async () => {
        const files = [makeUri('/proj/lib/main.dart')];
        (vscode.workspace as any).findFiles = async () => files;
        (vscode.workspace as any).fs.readFile = async () =>
            encode(
                "// import 'package:old_pkg/old_pkg.dart';\n"
                + "import 'package:http/http.dart';",
            );

        const result = await scanDartImports(makeUri('/proj'));
        assert.strictEqual(result.size, 1);
        assert.ok(result.has('http'));
        assert.ok(!result.has('old_pkg'), 'commented-out import must not appear in active set');
    });
});

describe('scanDartImportsDetailed', () => {
    let env: ReturnType<typeof stubWorkspace>;
    beforeEach(() => { env = stubWorkspace(); });
    afterEach(() => env.restore());

    it('should return file paths and line numbers for active imports', async () => {
        const files = [makeUri('/proj/lib/main.dart')];
        (vscode.workspace as any).findFiles = async () => files;
        (vscode.workspace as any).fs.readFile = async () =>
            encode(
                "import 'dart:core';\n"
                + "import 'package:http/http.dart';\n"
                + "\n"
                + "import 'package:bloc/bloc.dart';",
            );

        const result = await scanDartImportsDetailed(makeUri('/proj'));
        const httpUsages = result.get('http');
        assert.ok(httpUsages);
        assert.strictEqual(httpUsages.length, 1);
        assert.strictEqual(httpUsages[0].line, 2);
        assert.ok(httpUsages[0].filePath.includes('main.dart'));
        assert.strictEqual(httpUsages[0].isCommented, false);

        const blocUsages = result.get('bloc');
        assert.ok(blocUsages);
        assert.strictEqual(blocUsages[0].line, 4);
    });

    it('should detect commented-out imports with isCommented flag', async () => {
        const files = [makeUri('/proj/lib/main.dart')];
        (vscode.workspace as any).findFiles = async () => files;
        (vscode.workspace as any).fs.readFile = async () =>
            encode(
                "import 'package:http/http.dart';\n"
                + "// import 'package:old_pkg/old_pkg.dart';",
            );

        const result = await scanDartImportsDetailed(makeUri('/proj'));
        const oldPkgUsages = result.get('old_pkg');
        assert.ok(oldPkgUsages, 'commented-out import should appear in detailed map');
        assert.strictEqual(oldPkgUsages.length, 1);
        assert.strictEqual(oldPkgUsages[0].isCommented, true);
        assert.strictEqual(oldPkgUsages[0].line, 2);
    });

    it('should track usages across multiple files', async () => {
        const files = [
            makeUri('/proj/lib/a.dart'),
            makeUri('/proj/lib/b.dart'),
        ];
        (vscode.workspace as any).findFiles = async () => files;
        (vscode.workspace as any).fs.readFile = async (uri: vscode.Uri) => {
            if (uri.fsPath.includes('a.dart')) {
                return encode("import 'package:http/http.dart';");
            }
            return encode("import 'package:http/src/client.dart';");
        };

        const result = await scanDartImportsDetailed(makeUri('/proj'));
        const httpUsages = result.get('http');
        assert.ok(httpUsages);
        assert.strictEqual(httpUsages.length, 2, 'should have usages from both files');
    });

    it('should handle both active and commented imports of same package', async () => {
        const files = [makeUri('/proj/lib/main.dart')];
        (vscode.workspace as any).findFiles = async () => files;
        (vscode.workspace as any).fs.readFile = async () =>
            encode(
                "import 'package:http/http.dart';\n"
                + "// import 'package:http/retry.dart';",
            );

        const result = await scanDartImportsDetailed(makeUri('/proj'));
        const httpUsages = result.get('http');
        assert.ok(httpUsages);
        assert.strictEqual(httpUsages.length, 2);
        assert.strictEqual(httpUsages[0].isCommented, false);
        assert.strictEqual(httpUsages[1].isCommented, true);
    });

    it('should return empty map for empty project', async () => {
        (vscode.workspace as any).findFiles = async () => [];

        const result = await scanDartImportsDetailed(makeUri('/proj'));
        assert.strictEqual(result.size, 0);
    });

    it('should mark export directives with isExport=true', async () => {
        // Re-exports are part of the library's public API surface; the
        // scanner must distinguish them from regular imports so downstream
        // classification (single-use card, replacement complexity) doesn't
        // suggest removing a package that callers depend on transitively.
        const files = [makeUri('/proj/lib/api.dart')];
        (vscode.workspace as any).findFiles = async () => files;
        (vscode.workspace as any).fs.readFile = async () =>
            encode(
                "import 'package:meta/meta.dart';\n"
                + "export 'package:public_pkg/public_pkg.dart';",
            );

        const result = await scanDartImportsDetailed(makeUri('/proj'));
        const meta = result.get('meta');
        const publicPkg = result.get('public_pkg');
        assert.strictEqual(meta?.[0].isExport, false, 'plain import is not an export');
        assert.strictEqual(publicPkg?.[0].isExport, true, 'export directive sets isExport=true');
    });

    it('should mark commented-out export directives with isExport=true', async () => {
        const files = [makeUri('/proj/lib/api.dart')];
        (vscode.workspace as any).findFiles = async () => files;
        (vscode.workspace as any).fs.readFile = async () =>
            encode("// export 'package:old_api/old_api.dart';");

        const result = await scanDartImportsDetailed(makeUri('/proj'));
        const usages = result.get('old_api');
        assert.strictEqual(usages?.[0].isCommented, true);
        assert.strictEqual(usages?.[0].isExport, true);
    });

    it('should merge import and export of the same package in the same file into one usage', async () => {
        // Regression: the References column previously double-counted files
        // like share_utils.dart that both import share_plus for internal use
        // AND export a subset of its symbols as part of the library's public
        // API. The scanner now produces ONE usage per (filePath, isCommented)
        // with `importLine` and `exportLine` both populated, so
        // activeFileUsages(...).length = 1 (the file count) while the
        // directive-level detail is preserved in the new line fields.
        const files = [makeUri('/proj/lib/utils/system/share_utils.dart')];
        (vscode.workspace as any).findFiles = async () => files;
        (vscode.workspace as any).fs.readFile = async () =>
            encode(
                "export 'package:share_plus/share_plus.dart' show XFile;\n"
                + "import 'package:other/other.dart';\n"
                + "\n"
                + "// some comment\n"
                + "import 'package:share_plus/share_plus.dart';",
            );

        const result = await scanDartImportsDetailed(makeUri('/proj'));
        const sharePlus = result.get('share_plus');
        assert.ok(sharePlus, 'share_plus should be in usage map');
        assert.strictEqual(sharePlus.length, 1, 'import+export of same pkg in one file is 1 usage');
        assert.strictEqual(sharePlus[0].exportLine, 1);
        assert.strictEqual(sharePlus[0].importLine, 5);
        assert.strictEqual(sharePlus[0].isExport, true, 'isExport derived from exportLine');
        assert.strictEqual(sharePlus[0].line, 1, 'primary line prefers exportLine');
        assert.strictEqual(sharePlus[0].isCommented, false);
    });

    it('should keep active and commented entries separate when dedup-merging', async () => {
        // A file with an active import + a commented-out export of the same
        // package produces two entries — one per isCommented bucket — so the
        // "active files" count still excludes the dead directive.
        const files = [makeUri('/proj/lib/legacy.dart')];
        (vscode.workspace as any).findFiles = async () => files;
        (vscode.workspace as any).fs.readFile = async () =>
            encode(
                "import 'package:http/http.dart';\n"
                + "// export 'package:http/http.dart';",
            );

        const result = await scanDartImportsDetailed(makeUri('/proj'));
        const http = result.get('http');
        assert.ok(http);
        assert.strictEqual(http.length, 2);
        const active = http.find(u => !u.isCommented);
        const commented = http.find(u => u.isCommented);
        assert.strictEqual(active?.importLine, 1);
        assert.strictEqual(active?.exportLine, null);
        assert.strictEqual(commented?.exportLine, 2);
        assert.strictEqual(commented?.importLine, null);
    });
});

describe('hasActiveReExport', () => {
    it('returns true when at least one active usage is an export', () => {
        const usages: PackageUsage[] = [
            { filePath: 'lib/internal.dart', line: 1, isCommented: false, isExport: false },
            { filePath: 'lib/api.dart', line: 5, isCommented: false, isExport: true },
        ];
        assert.strictEqual(hasActiveReExport(usages), true);
    });

    it('returns false when all exports are commented out', () => {
        // A commented-out re-export isn't actually exposing anything — it's
        // dead code. The active-only filter is what protects the user from
        // removing a stale comment and accidentally classifying the package
        // as non-removable.
        const usages: PackageUsage[] = [
            { filePath: 'lib/api.dart', line: 1, isCommented: true, isExport: true },
        ];
        assert.strictEqual(hasActiveReExport(usages), false);
    });

    it('returns false when there are only imports', () => {
        const usages: PackageUsage[] = [
            { filePath: 'lib/a.dart', line: 1, isCommented: false, isExport: false },
        ];
        assert.strictEqual(hasActiveReExport(usages), false);
    });

    it('returns false for empty usages', () => {
        assert.strictEqual(hasActiveReExport([]), false);
    });
});

describe('activePackageNames', () => {
    it('should include packages with at least one active import', () => {
        const map = new Map<string, PackageUsage[]>([
            ['http', [{ filePath: 'lib/a.dart', line: 1, isCommented: false }]],
            ['old_pkg', [{ filePath: 'lib/a.dart', line: 2, isCommented: true }]],
        ]);
        const names = activePackageNames(map);
        assert.ok(names.has('http'));
        assert.ok(!names.has('old_pkg'), 'package with only commented imports should be excluded');
    });

    it('should include package with mixed active and commented imports', () => {
        const map = new Map<string, PackageUsage[]>([
            ['http', [
                { filePath: 'lib/a.dart', line: 1, isCommented: true },
                { filePath: 'lib/b.dart', line: 5, isCommented: false },
            ]],
        ]);
        const names = activePackageNames(map);
        assert.ok(names.has('http'));
    });

    it('should return empty set for empty map', () => {
        const names = activePackageNames(new Map());
        assert.strictEqual(names.size, 0);
    });
});

describe('collectSymbolOccurrences', () => {
    function src(path: string, text: string): DartSource {
        return { path, text };
    }

    it('aggregates counts and locations across multiple files', () => {
        const sources = [
            src('lib/a.dart', 'final t = ReelText();\nReelText other;'),
            src('lib/b.dart', '// note\nvar x = ReelText();'),
        ];
        const result = collectSymbolOccurrences(sources, new Set(['ReelText']));
        const hits = result.get('ReelText');
        assert.ok(hits);
        assert.strictEqual(hits.length, 3);
        assert.deepStrictEqual(
            hits.map(h => `${h.filePath}:${h.line}`),
            ['lib/a.dart:1', 'lib/a.dart:2', 'lib/b.dart:2'],
        );
    });

    it('records the dotted member rather than its bare owner', () => {
        // Longest-first alternation: `ReelText.rich` must win, otherwise the
        // report credits the owner class for a member that is never called.
        const sources = [src('lib/a.dart', 'ReelText.rich(spans);')];
        const result = collectSymbolOccurrences(
            sources, new Set(['ReelText', 'ReelText.rich']),
        );
        assert.strictEqual(result.get('ReelText.rich')?.length, 1);
        assert.strictEqual(result.get('ReelText'), undefined);
    });

    it('excludes import and export directive lines, commented or not', () => {
        // A `show` clause names the symbol without using it; counting it would
        // report adoption for a package that is merely imported.
        const sources = [src('lib/a.dart', [
            "import 'package:reel/reel.dart' show ReelText;",
            "export 'package:reel/reel.dart' show ReelText;",
            "// import 'package:reel/reel.dart' show ReelText;",
            "// export 'package:reel/reel.dart' show ReelText;",
            '  final w = ReelText();',
        ].join('\n'))];
        const result = collectSymbolOccurrences(sources, new Set(['ReelText']));
        const hits = result.get('ReelText');
        assert.strictEqual(hits?.length, 1, 'only the real call site counts');
        assert.strictEqual(hits?.[0].line, 5);
    });

    it('excludes wrapped show clauses on directive continuation lines', () => {
        // dart format wraps a long `show` clause onto its own line, which does
        // not itself start with `import` — matching only the opening line would
        // count every wrapped symbol as a usage.
        const sources = [src('lib/a.dart', [
            "import 'package:reel/reel.dart'",
            '    show ReelText, ReelTextController;',
            '',
            '  final w = ReelText();',
        ].join('\n'))];
        const result = collectSymbolOccurrences(
            sources, new Set(['ReelText', 'ReelTextController']),
        );
        assert.strictEqual(
            result.get('ReelText')?.length, 1, 'only the real call site counts',
        );
        assert.strictEqual(result.get('ReelText')?.[0].line, 4);
        assert.strictEqual(
            result.get('ReelTextController'), undefined,
            'a symbol only ever named in a wrapped show clause is unused',
        );
    });

    it('stops skipping at a blank line when a directive never terminates', () => {
        // Malformed source must not let a missing semicolon swallow the file.
        const sources = [src('lib/a.dart', [
            "import 'package:reel/reel.dart'",
            '',
            '  final w = ReelText();',
        ].join('\n'))];
        const result = collectSymbolOccurrences(sources, new Set(['ReelText']));
        assert.strictEqual(result.get('ReelText')?.length, 1);
        assert.strictEqual(result.get('ReelText')?.[0].line, 3);
    });

    it('ignores a semicolon inside a directive line comment', () => {
        // The `;` belongs to prose, so the wrapped show clause below it is
        // still part of the directive and must not count as usage.
        const sources = [src('lib/a.dart', [
            "import 'package:reel/reel.dart' // keep; drop later",
            '    show ReelText;',
            '  final w = ReelText();',
        ].join('\n'))];
        const result = collectSymbolOccurrences(sources, new Set(['ReelText']));
        assert.strictEqual(result.get('ReelText')?.length, 1);
        assert.strictEqual(result.get('ReelText')?.[0].line, 3);
    });

    it('counts a member name used off an unrelated owner', () => {
        // `.` is a boundary: a candidate that is a member name is a hit even
        // when the owner is not itself a candidate.
        const sources = [src('lib/a.dart', 'final v = config.rich;')];
        const result = collectSymbolOccurrences(sources, new Set(['rich']));
        assert.strictEqual(result.get('rich')?.length, 1);
        assert.strictEqual(result.get('rich')?.[0].column, 18);
    });

    it('excludes symbols across the directive shapes dart format emits', () => {
        // Each shape below is one dart format produces for a long directive.
        // A miss on any of them counts a `show`/`hide` name as adoption.
        const sources = [src('lib/a.dart', [
            "import 'package:reel/reel.dart'",
            '    show ReelText',
            '    hide ReelBox;',
            "import 'package:reel/two.dart' as two",
            '    show ReelText;',
            "export 'package:reel/reel.dart'",
            '    show ReelBox;',
            "import 'package:reel/three.dart' deferred as three",
            '    show ReelText;',
            '  final w = ReelText();',
        ].join('\n'))];
        const result = collectSymbolOccurrences(
            sources, new Set(['ReelText', 'ReelBox']),
        );
        assert.strictEqual(result.get('ReelText')?.length, 1);
        assert.strictEqual(result.get('ReelText')?.[0].line, 10);
        assert.strictEqual(
            result.get('ReelBox'), undefined,
            'a name only ever hidden or re-exported is not a usage',
        );
    });

    it('returns correct counts with a large candidate set', () => {
        // Correctness at scale only. A wall-clock assertion was tried and
        // removed: the alternation implementation this replaced cleared the
        // same 5000-candidate corpus in single-digit milliseconds, so any
        // threshold loose enough not to flake also passes for the old code and
        // pins nothing.
        const big = new Set<string>(['ReelText']);
        for (let i = 0; i < 5000; i++) { big.add(`Sym${i}Name`); }
        const line = '  final w = ReelText(child: Text("x"), key: key);';
        const sources = [src('lib/a.dart', Array(2000).fill(line).join('\n'))];
        const result = collectSymbolOccurrences(sources, big);
        assert.strictEqual(result.get('ReelText')?.length, 2000);
        assert.strictEqual(result.size, 1, 'no phantom hits from the filler set');
    });

    it('omits zero-match candidates instead of mapping them to empty arrays', () => {
        const sources = [src('lib/a.dart', 'ReelText();')];
        const result = collectSymbolOccurrences(
            sources, new Set(['ReelText', 'NeverUsed']),
        );
        assert.strictEqual(result.size, 1);
        assert.strictEqual(result.has('NeverUsed'), false);
    });

    it('returns an empty map for an empty candidate set', () => {
        const sources = [src('lib/a.dart', 'ReelText();')];
        const result = collectSymbolOccurrences(sources, new Set<string>());
        assert.strictEqual(result.size, 0);
    });

    it('does NOT stop early once every candidate has been seen', () => {
        // collectSymbolUsage breaks out of the file loop the moment every
        // candidate has a hit. This function must not: file 3's occurrences
        // are still part of the count even though files 1-2 already covered
        // the whole candidate set.
        const sources = [
            src('lib/one.dart', 'ReelText();'),
            src('lib/two.dart', 'runWhile();'),
            src('lib/three.dart', 'ReelText();\nrunWhile();'),
        ];
        const result = collectSymbolOccurrences(
            sources, new Set(['ReelText', 'runWhile']),
        );
        assert.strictEqual(result.get('ReelText')?.length, 2);
        assert.strictEqual(result.get('runWhile')?.length, 2);
        assert.strictEqual(result.get('ReelText')?.[1].filePath, 'lib/three.dart');
        assert.strictEqual(result.get('runWhile')?.[1].filePath, 'lib/three.dart');
    });

    it('reports 1-based line and column', () => {
        const sources = [src('lib/a.dart', 'line one\n  final w = ReelText();')];
        const hits = collectSymbolOccurrences(sources, new Set(['ReelText']))
            .get('ReelText');
        assert.strictEqual(hits?.[0].line, 2);
        // 'ReelText' starts at index 12 of "  final w = ReelText();" -> column 13.
        assert.strictEqual(hits?.[0].column, 13);
    });

    it('trims the snippet and caps it at 200 characters', () => {
        const long = `    ReelText(${'a'.repeat(400)});   `;
        const hits = collectSymbolOccurrences(
            [src('lib/a.dart', long)], new Set(['ReelText']),
        ).get('ReelText');
        assert.strictEqual(hits?.[0].snippet.length, 200);
        assert.ok(hits?.[0].snippet.startsWith('ReelText('), 'leading space trimmed');
    });

    it('returns an empty map when there are no sources', () => {
        const result = collectSymbolOccurrences([], new Set(['ReelText']));
        assert.strictEqual(result.size, 0);
    });
});

describe('activeFileUsages', () => {
    it('should filter out commented usages', () => {
        const usages: PackageUsage[] = [
            { filePath: 'lib/a.dart', line: 1, isCommented: false },
            { filePath: 'lib/b.dart', line: 2, isCommented: true },
            { filePath: 'lib/c.dart', line: 3, isCommented: false },
        ];
        const active = activeFileUsages(usages);
        assert.strictEqual(active.length, 2);
        assert.ok(active.every(u => !u.isCommented));
    });

    it('should return empty array when all are commented', () => {
        const usages: PackageUsage[] = [
            { filePath: 'lib/a.dart', line: 1, isCommented: true },
        ];
        const active = activeFileUsages(usages);
        assert.strictEqual(active.length, 0);
    });

    it('should return all when none are commented', () => {
        const usages: PackageUsage[] = [
            { filePath: 'lib/a.dart', line: 1, isCommented: false },
        ];
        const active = activeFileUsages(usages);
        assert.strictEqual(active.length, 1);
    });

    it('should return empty array for empty input', () => {
        assert.strictEqual(activeFileUsages([]).length, 0);
    });
});
