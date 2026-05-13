/**
 * Tests for the tar buffer analyzer — drives synthetic in-memory tars so we
 * exercise the per-folder bucketing, maintainer-quality flag rules, and
 * declared-asset code-size logic without any network or pub.dev coupling.
 *
 * The actual `analyzeTarball()` (network + gunzip + tar parse end-to-end)
 * is exercised by integration tests against real pub.dev archives — here we
 * pin the deterministic pure-function half so future changes to bucketing
 * or flag thresholds light up the right test.
 */
import * as assert from 'assert';
import { analyzeTarBuffer } from '../../../vibrancy/services/tarball-analyzer';

/* POSIX ustar tar uses 512-byte header blocks. Building one in code lets
   us assemble fixtures without shelling out to `tar`. */
const BLOCK = 512;
const NAME_OFF = 0;
const NAME_LEN = 100;
const SIZE_OFF = 124;
const SIZE_LEN = 12;
const TYPE_OFF = 156;

function makeTarEntry(path: string, body: string): Buffer {
    const header = Buffer.alloc(BLOCK, 0);
    header.write(path, NAME_OFF, NAME_LEN, 'ascii');
    /* Size is octal-encoded in 11 chars + null. */
    const sizeOctal = body.length.toString(8).padStart(SIZE_LEN - 1, '0');
    header.write(sizeOctal + '\0', SIZE_OFF, SIZE_LEN, 'ascii');
    header.write('0', TYPE_OFF, 1, 'ascii');

    const data = Buffer.from(body, 'utf8');
    const paddedLen = Math.ceil(data.length / BLOCK) * BLOCK;
    const dataBlock = Buffer.alloc(paddedLen, 0);
    data.copy(dataBlock);
    return Buffer.concat([header, dataBlock]);
}

/** Synthetic tarball builder — pubspec.yaml + arbitrary files. */
function makeTar(entries: Record<string, string>): Buffer {
    const blocks: Buffer[] = [];
    for (const [path, body] of Object.entries(entries)) {
        blocks.push(makeTarEntry(path, body));
    }
    /* End-of-archive: two consecutive zero-filled blocks. */
    blocks.push(Buffer.alloc(BLOCK * 2, 0));
    return Buffer.concat(blocks);
}

describe('analyzeTarBuffer', () => {
    it('sums lib/** into codeSizeBytes and excludes example/test', () => {
        /* The audioplayers shape from the bug: lib/ is small, example/
           dominates the tarball, test/ is present. codeSizeBytes must
           track lib/ only, not the tarball total. */
        const tar = makeTar({
            'pubspec.yaml': 'name: ap\nversion: 1.0.0\n',
            'lib/audioplayers.dart': 'x'.repeat(40_000),
            'example/main.dart': 'y'.repeat(100),
            'example/assets/big.mp3': 'A'.repeat(21_000_000),
            'test/audio_test.dart': 'z'.repeat(2000),
            'README.md': 'r',
        });
        const r = analyzeTarBuffer(tar);
        assert.strictEqual(r.codeSizeBytes, 40_000);
        assert.strictEqual(r.folderBreakdown.lib, 40_000);
        assert.ok(r.folderBreakdown.example >= 21_000_000);
        assert.strictEqual(r.folderBreakdown.test, 2000);
    });

    it('counts declared flutter.assets toward codeSizeBytes', () => {
        /* When the pubspec declares assets, those WILL ship with the app
           and should count as code. Asset files in example/ that are NOT
           declared should not. */
        const pubspec = `name: foo
version: 1.0.0
flutter:
  assets:
    - assets/icons/star.png
`;
        const tar = makeTar({
            'pubspec.yaml': pubspec,
            'lib/foo.dart': 'L'.repeat(5000),
            'assets/icons/star.png': 'I'.repeat(2000),
            'example/assets/demo.mp3': 'D'.repeat(1_000_000),
        });
        const r = analyzeTarBuffer(tar);
        /* lib (5000) + declared asset (2000) = 7000. */
        assert.strictEqual(r.codeSizeBytes, 7000);
    });

    it('treats trailing-slash flutter.assets entries as directory globs', () => {
        const pubspec = `name: foo
version: 1.0.0
flutter:
  assets:
    - assets/icons/
`;
        const tar = makeTar({
            'pubspec.yaml': pubspec,
            'lib/foo.dart': 'L'.repeat(1000),
            'assets/icons/a.png': 'A'.repeat(500),
            'assets/icons/b.png': 'B'.repeat(700),
            'assets/other/c.png': 'C'.repeat(900),
        });
        const r = analyzeTarBuffer(tar);
        /* 1000 (lib) + 500 + 700 (icons dir) = 2200; the unrelated other/ is excluded. */
        assert.strictEqual(r.codeSizeBytes, 2200);
    });

    it('sets hasExample only when example/ has a .dart file', () => {
        const onlyReadme = makeTar({
            'pubspec.yaml': 'name: x',
            'lib/x.dart': 'a',
            'example/README.md': 'demo notes',
        });
        const withDart = makeTar({
            'pubspec.yaml': 'name: x',
            'lib/x.dart': 'a',
            'example/main.dart': 'void main() {}',
        });
        assert.strictEqual(analyzeTarBuffer(onlyReadme).maintainerQuality.hasExample, false);
        assert.strictEqual(analyzeTarBuffer(withDart).maintainerQuality.hasExample, true);
    });

    it('sets hasTests only when test/ has a _test.dart file', () => {
        const onlyHelper = makeTar({
            'pubspec.yaml': 'name: x',
            'lib/x.dart': 'a',
            'test/helper.dart': 'helper',
        });
        const withTest = makeTar({
            'pubspec.yaml': 'name: x',
            'lib/x.dart': 'a',
            'test/x_test.dart': 'test',
        });
        /* Stub coverage (just a helper, no _test.dart) does NOT earn the
           bonus — empty gestures aren't health signals. */
        assert.strictEqual(analyzeTarBuffer(onlyHelper).maintainerQuality.hasTests, false);
        assert.strictEqual(analyzeTarBuffer(withTest).maintainerQuality.hasTests, true);
    });

    it('sets hasTools for .dart, .sh, or .ps1 in tool/', () => {
        const r = analyzeTarBuffer(makeTar({
            'pubspec.yaml': 'name: x',
            'lib/x.dart': 'a',
            'tool/release.sh': '#!/bin/sh',
        }));
        assert.strictEqual(r.maintainerQuality.hasTools, true);
    });

    it('sets hasDocs for .md outside doc/api/', () => {
        const onlyApiDump = makeTar({
            'pubspec.yaml': 'name: x',
            'lib/x.dart': 'a',
            'doc/api/index.html': '<html/>',
        });
        const withGuide = makeTar({
            'pubspec.yaml': 'name: x',
            'lib/x.dart': 'a',
            'doc/guide.md': '# Guide',
        });
        /* `doc/api/` is the auto-Dartdoc dump — its presence is a build
           artifact, not a maintainer signal. Require a non-api .md. */
        assert.strictEqual(analyzeTarBuffer(onlyApiDump).maintainerQuality.hasDocs, false);
        assert.strictEqual(analyzeTarBuffer(withGuide).maintainerQuality.hasDocs, true);
    });

    it('strips the pub.dev <name>-<version>/ wrapper directory', () => {
        /* Real pub.dev tarballs wrap every entry. The analyzer must strip
           the wrapper before bucketing so lib/ classifies correctly. */
        const tar = makeTar({
            'foo-1.0.0/pubspec.yaml': 'name: foo',
            'foo-1.0.0/lib/foo.dart': 'L'.repeat(1000),
            'foo-1.0.0/test/foo_test.dart': 'T'.repeat(200),
        });
        const r = analyzeTarBuffer(tar);
        assert.strictEqual(r.folderBreakdown.lib, 1000);
        assert.strictEqual(r.folderBreakdown.test, 200);
        assert.strictEqual(r.maintainerQuality.hasTests, true);
    });
});
