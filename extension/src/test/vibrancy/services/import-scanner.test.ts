import * as assert from 'assert';
import * as vscode from 'vscode';
import {
    scanDartImports,
    scanDartImportsDetailed,
    activePackageNames,
    activeFileUsages,
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
