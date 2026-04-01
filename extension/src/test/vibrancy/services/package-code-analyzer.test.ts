import * as assert from 'assert';
import * as vscode from 'vscode';
import {
    classifyLines,
    classifyReplacement,
    resolvePackagePaths,
    analyzePackageCode,
    PackageCodeMetrics,
} from '../../../vibrancy/services/package-code-analyzer';

function makeUri(path: string): vscode.Uri {
    return vscode.Uri.file(path) as vscode.Uri;
}

function encode(text: string): Uint8Array {
    return new TextEncoder().encode(text);
}

describe('classifyLines', () => {
    it('should count pure code lines', () => {
        const result = classifyLines(
            'var x = 1;\nvar y = 2;\nvar z = 3;',
        );
        assert.strictEqual(result.code, 3);
        assert.strictEqual(result.comment, 0);
    });

    it('should count single-line comments', () => {
        const result = classifyLines(
            '// comment one\n/// dartdoc\nvar x = 1;',
        );
        assert.strictEqual(result.code, 1);
        assert.strictEqual(result.comment, 2);
    });

    it('should skip blank lines', () => {
        const result = classifyLines(
            'var x = 1;\n\n\n  \nvar y = 2;',
        );
        assert.strictEqual(result.code, 2);
        assert.strictEqual(result.comment, 0);
    });

    it('should handle block comments', () => {
        const result = classifyLines(
            '/*\n * Block comment\n * continues\n */\nvar x = 1;',
        );
        assert.strictEqual(result.code, 1);
        assert.strictEqual(result.comment, 4);
    });

    it('should handle single-line block comments', () => {
        const result = classifyLines(
            '/* single line block */\nvar x = 1;',
        );
        assert.strictEqual(result.code, 1);
        assert.strictEqual(result.comment, 1);
    });

    it('should count trailing comments as code', () => {
        const result = classifyLines(
            'var x = 1; // inline comment',
        );
        assert.strictEqual(result.code, 1);
        assert.strictEqual(result.comment, 0);
    });

    it('should handle empty input', () => {
        const result = classifyLines('');
        assert.strictEqual(result.code, 0);
        assert.strictEqual(result.comment, 0);
    });

    it('should handle code with mid-line block comment start', () => {
        // Block comment opens mid-line but doesn't close — next line is comment
        const result = classifyLines(
            'var x = 1; /* start\n still comment\n */ var y = 2;',
        );
        // Line 1: code (has var x before /*)
        // Line 2: comment (inside block)
        // Line 3: comment (closing block, even though code follows on same line after */)
        assert.strictEqual(result.code, 1);
        assert.strictEqual(result.comment, 2);
    });

    it('should handle mixed comments and code', () => {
        const result = classifyLines([
            '/// Dartdoc for class.',
            '///',
            '/// Example:',
            '/// ```dart',
            '/// final x = 1;',
            '/// ```',
            'class Foo {',
            '  // private field',
            '  final int _x;',
            '',
            '  Foo(this._x);',
            '}',
        ].join('\n'));
        assert.strictEqual(result.code, 4);     // class, final, Foo, }
        assert.strictEqual(result.comment, 7);   // 6 dartdoc + 1 inline
    });

    it('should handle file with only comments', () => {
        const result = classifyLines(
            '// just comments\n/// and dartdoc\n/* and blocks */',
        );
        assert.strictEqual(result.code, 0);
        assert.strictEqual(result.comment, 3);
    });
});

describe('classifyReplacement', () => {
    const baseMetrics: PackageCodeMetrics = {
        libCodeLines: 0,
        libCommentLines: 0,
        libFileCount: 0,
        exampleCodeLines: 0,
        hasNativeCode: false,
        nativePlatforms: [],
    };

    it('should classify trivial (< 100 LOC)', () => {
        const result = classifyReplacement({
            ...baseMetrics, libCodeLines: 25, libFileCount: 2,
        });
        assert.strictEqual(result.level, 'trivial');
        assert.ok(result.summary.includes('25'));
        assert.ok(result.summary.includes('inline'));
    });

    it('should classify small (100-499 LOC)', () => {
        const result = classifyReplacement({
            ...baseMetrics, libCodeLines: 300, libFileCount: 5,
        });
        assert.strictEqual(result.level, 'small');
        assert.ok(result.summary.includes('300'));
    });

    it('should classify moderate (500-1999 LOC)', () => {
        const result = classifyReplacement({
            ...baseMetrics, libCodeLines: 1000, libFileCount: 10,
        });
        assert.strictEqual(result.level, 'moderate');
    });

    it('should classify large (2000+ LOC)', () => {
        const result = classifyReplacement({
            ...baseMetrics, libCodeLines: 5000, libFileCount: 40,
        });
        assert.strictEqual(result.level, 'large');
        assert.ok(result.summary.includes('5,000'));
    });

    it('should classify native regardless of LOC', () => {
        const result = classifyReplacement({
            ...baseMetrics,
            libCodeLines: 10,
            libFileCount: 1,
            hasNativeCode: true,
            nativePlatforms: ['ios', 'android'],
        });
        assert.strictEqual(result.level, 'native');
        assert.ok(result.summary.includes('native'));
        assert.ok(result.summary.includes('ios'));
    });

    it('should classify zero LOC as trivial', () => {
        const result = classifyReplacement(baseMetrics);
        assert.strictEqual(result.level, 'trivial');
    });

    it('should handle boundary at 100', () => {
        const at99 = classifyReplacement({
            ...baseMetrics, libCodeLines: 99, libFileCount: 1,
        });
        const at100 = classifyReplacement({
            ...baseMetrics, libCodeLines: 100, libFileCount: 1,
        });
        assert.strictEqual(at99.level, 'trivial');
        assert.strictEqual(at100.level, 'small');
    });

    it('should handle boundary at 500', () => {
        const at499 = classifyReplacement({
            ...baseMetrics, libCodeLines: 499, libFileCount: 1,
        });
        const at500 = classifyReplacement({
            ...baseMetrics, libCodeLines: 500, libFileCount: 1,
        });
        assert.strictEqual(at499.level, 'small');
        assert.strictEqual(at500.level, 'moderate');
    });

    it('should handle boundary at 2000', () => {
        const at1999 = classifyReplacement({
            ...baseMetrics, libCodeLines: 1999, libFileCount: 1,
        });
        const at2000 = classifyReplacement({
            ...baseMetrics, libCodeLines: 2000, libFileCount: 1,
        });
        assert.strictEqual(at1999.level, 'moderate');
        assert.strictEqual(at2000.level, 'large');
    });

    it('should format singular file count', () => {
        const result = classifyReplacement({
            ...baseMetrics, libCodeLines: 25, libFileCount: 1,
        });
        assert.ok(result.summary.includes('1 file'));
        assert.ok(!result.summary.includes('1 files'));
    });
});

describe('resolvePackagePaths', () => {
    const originalReadFile = vscode.workspace.fs.readFile;

    afterEach(() => {
        (vscode.workspace as any).fs.readFile = originalReadFile;
    });

    it('should parse valid package_config.json', async () => {
        const config = JSON.stringify({
            configVersion: 2,
            packages: [
                {
                    name: 'http',
                    rootUri: 'file:///C:/Users/test/.pub-cache/hosted/pub.dev/http-1.2.0',
                    packageUri: 'lib/',
                },
                {
                    name: 'path',
                    rootUri: 'file:///C:/Users/test/.pub-cache/hosted/pub.dev/path-1.9.0',
                    packageUri: 'lib/',
                },
            ],
        });
        (vscode.workspace as any).fs.readFile = async () => encode(config);

        const result = await resolvePackagePaths(makeUri('/proj'));
        assert.strictEqual(result.size, 2);
        assert.ok(result.has('http'));
        assert.ok(result.has('path'));
    });

    it('should return empty map when file is missing', async () => {
        (vscode.workspace as any).fs.readFile = async () => {
            throw new Error('ENOENT');
        };

        const result = await resolvePackagePaths(makeUri('/proj'));
        assert.strictEqual(result.size, 0);
    });

    it('should return empty map for invalid JSON', async () => {
        (vscode.workspace as any).fs.readFile = async () =>
            encode('not valid json');

        const result = await resolvePackagePaths(makeUri('/proj'));
        assert.strictEqual(result.size, 0);
    });

    it('should skip packages with missing name or rootUri', async () => {
        const config = JSON.stringify({
            configVersion: 2,
            packages: [
                { name: 'good', rootUri: 'file:///cache/good-1.0.0' },
                { name: 'no_uri' },
                { rootUri: 'file:///cache/no_name-1.0.0' },
            ],
        });
        (vscode.workspace as any).fs.readFile = async () => encode(config);

        const result = await resolvePackagePaths(makeUri('/proj'));
        assert.strictEqual(result.size, 1);
        assert.ok(result.has('good'));
    });
});

describe('analyzePackageCode', () => {
    const originalFindFiles = vscode.workspace.findFiles;
    const originalReadFile = vscode.workspace.fs.readFile;
    const originalStat = vscode.workspace.fs.stat;

    afterEach(() => {
        (vscode.workspace as any).findFiles = originalFindFiles;
        (vscode.workspace as any).fs.readFile = originalReadFile;
        (vscode.workspace as any).fs.stat = originalStat;
    });

    it('should count code and comment lines in lib/', async () => {
        // Stub stat to succeed for lib/ and fail for example/
        (vscode.workspace as any).fs.stat = async (uri: vscode.Uri) => {
            if (uri.path.endsWith('/lib') || uri.path.endsWith('/lib/')) {
                return { type: vscode.FileType.Directory };
            }
            // native platform dirs + example/ should not exist
            throw new Error('ENOENT');
        };

        const libFile = makeUri('/cache/pkg/lib/src/main.dart');
        (vscode.workspace as any).findFiles = async (pattern: vscode.RelativePattern) => {
            if (pattern.baseUri.path.endsWith('/lib')) {
                return [libFile];
            }
            return [];
        };

        (vscode.workspace as any).fs.readFile = async () =>
            encode('/// Dartdoc\nclass Foo {\n  final int x;\n}\n');

        const result = await analyzePackageCode(makeUri('/cache/pkg'));
        assert.strictEqual(result.libCodeLines, 3);    // class, final, }
        assert.strictEqual(result.libCommentLines, 1);  // dartdoc
        assert.strictEqual(result.libFileCount, 1);
        assert.strictEqual(result.exampleCodeLines, 0);
        assert.strictEqual(result.hasNativeCode, false);
    });

    it('should detect native platforms', async () => {
        (vscode.workspace as any).fs.stat = async (uri: vscode.Uri) => {
            const path = uri.path;
            if (path.endsWith('/lib') || path.endsWith('/ios') || path.endsWith('/android')) {
                return { type: vscode.FileType.Directory };
            }
            throw new Error('ENOENT');
        };

        (vscode.workspace as any).findFiles = async () => [];
        (vscode.workspace as any).fs.readFile = async () => encode('');

        const result = await analyzePackageCode(makeUri('/cache/pkg'));
        assert.strictEqual(result.hasNativeCode, true);
        assert.deepStrictEqual([...result.nativePlatforms].sort(), ['android', 'ios']);
    });

    it('should handle empty package (no lib/)', async () => {
        (vscode.workspace as any).fs.stat = async () => {
            throw new Error('ENOENT');
        };
        (vscode.workspace as any).findFiles = async () => [];

        const result = await analyzePackageCode(makeUri('/cache/pkg'));
        assert.strictEqual(result.libCodeLines, 0);
        assert.strictEqual(result.libFileCount, 0);
        assert.strictEqual(result.hasNativeCode, false);
    });
});
