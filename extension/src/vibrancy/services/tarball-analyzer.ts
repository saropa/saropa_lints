/**
 * Tarball analyzer: downloads a published package's `.tar.gz` archive, walks
 * the entries, and produces the size-and-shape facts the rest of the vibrancy
 * module needs to talk about "what does this package actually cost / how
 * healthy is it" rather than "how big is the gzipped source bundle".
 *
 * Why this exists: pub.dev's public API exposes archive Content-Length (a
 * gzipped tarball that includes `example/`, `test/`, `tool/`, `doc/`, fixture
 * media, etc.) but no per-file listing. That single number was driving
 * bloat ratings, per-app size budgets, comparison rankings, and the hover
 * "size" line — and it over-reports by 100×+ for any package that ships
 * sample media or a demo server (audioplayers was ~500× off — see
 * plans/history/2026.05/2026.05.13/infra_vibrancy_bloat_uses_tarball_size_not_runtime.md).
 *
 * What the analyzer extracts in one pass:
 *   - `codeSizeBytes`     — bytes that actually reach a compiled Flutter app
 *                            (`lib/**` + `flutter.assets:` declared in the
 *                            package's own pubspec).
 *   - `folderBreakdown`   — bytes per top-level folder, so the hover can show
 *                            the asymmetry ("21.7 MB on disk · 99% example/").
 *   - `maintainerQuality` — presence of `example/`, `test/`, `tool/`, `doc/`
 *                            with non-trivial content, surfaced as positive
 *                            health-score components (NOT bloat penalties).
 *   - `archiveSizeBytes`  — the uncompressed sum from the tarball, used as a
 *                            sanity-check secondary on the hover.
 *
 * Why the inline tar parser: POSIX ustar tar is a 512-byte-header format
 * trivial to walk without a dependency. Adding `tar` from npm would pull in
 * a transitive tree we don't need for a one-function decoder. The parser is
 * tolerant of malformed entries (skips and continues) so a single bad header
 * never breaks the scan.
 *
 * Caching: results key on the package archive URL (which already encodes
 * `<name>@<version>`) and live in the workspace cache alongside other pub.dev
 * lookups. A package version's tarball never changes, so a long TTL is safe.
 */
import { gunzipSync } from 'zlib';
import { CacheService } from './cache-service';
import { ScanLogger } from './scan-logger';
import { fetchWithRetry } from './fetch-retry';
import type { FolderBreakdown, MaintainerQualityFlags } from '../types';

/** Result of analyzing a package's tarball. */
export interface TarballAnalysis {
    /** Sum of uncompressed entry sizes in the tarball (informational). */
    readonly archiveUncompressedBytes: number;
    /**
     * Bytes shipped to a built Flutter app: `lib/**` plus assets declared in
     * the package's own pubspec under `flutter.assets:`. Native plugin
     * binaries from platform sub-packages (`<name>_android`, etc.) are NOT
     * rolled in here — those packages are analyzed separately and surface as
     * transitive contributions.
     */
    readonly codeSizeBytes: number;
    readonly folderBreakdown: FolderBreakdown;
    readonly maintainerQuality: MaintainerQualityFlags;
}

/**
 * Hard cap on tarball download size. Beyond this we bail out rather than
 * stream and parse — protects users on metered or slow networks from a
 * single oversized package (sample media, demo servers) stalling the scan.
 * 64 MB is a deliberate ceiling: real Flutter packages we want to assess
 * sit well below 50 MB even when they ship demos.
 */
const MAX_TARBALL_BYTES = 64 * 1024 * 1024;

/** 512-byte POSIX tar header block. Documented so the parser reads as data, not magic. */
const TAR_BLOCK_SIZE = 512;

/** Filename field length in a ustar header — names longer than 100 chars use the prefix slot. */
const TAR_NAME_LEN = 100;

/** Octal-encoded size field offset inside a 512-byte ustar header. */
const TAR_SIZE_OFFSET = 124;

/** Octal-encoded size field length (11 octal digits + null terminator). */
const TAR_SIZE_LEN = 12;

/** Prefix field offset for path names > 100 chars (POSIX ustar extension). */
const TAR_PREFIX_OFFSET = 345;

/** Prefix field length. */
const TAR_PREFIX_LEN = 155;

/** Type flag offset (0/'0' = regular file, '5' = directory, etc.). */
const TAR_TYPEFLAG_OFFSET = 156;

/** Cache key for the tarball analysis. Keyed on archiveUrl which encodes name@version. */
function cacheKeyFor(archiveUrl: string): string {
    /* Stable digest of the URL — keeps cache keys short while remaining
       unique per package@version. Same hash style as pub-dev-api.ts uses
       for registry-URL cache prefixes. */
    let hash = 0;
    for (let i = 0; i < archiveUrl.length; i++) {
        const c = archiveUrl.charCodeAt(i);
        hash = ((hash << 5) - hash) + c;
        hash = hash & hash;
    }
    return `pub.tarball.${Math.abs(hash).toString(36)}`;
}

/**
 * Download + analyze a package tarball. Returns null on any error
 * (network failure, oversized archive, gunzip failure, tar parse failure)
 * so callers can gracefully fall back to "size unknown" rather than
 * propagate an exception that would break the scan for one bad package.
 */
export async function analyzeTarball(
    archiveUrl: string,
    cache?: CacheService,
    logger?: ScanLogger,
): Promise<TarballAnalysis | null> {
    const key = cacheKeyFor(archiveUrl);
    const cached = cache?.get<TarballAnalysis>(key);
    if (cached) {
        logger?.cacheHit(key);
        return cached;
    }
    logger?.cacheMiss(key);

    try {
        logger?.apiRequest('GET', archiveUrl);
        const t0 = Date.now();
        const resp = await fetchWithRetry(archiveUrl, undefined, logger);
        logger?.apiResponse(resp.status, resp.statusText, Date.now() - t0);
        if (!resp.ok) { return null; }

        /* Content-Length is the gzipped size; we still cap the download to
           protect against missing/lying headers. arrayBuffer reads the full
           body — acceptable here because we cache aggressively (one fetch
           per package@version, ever) and the MAX_TARBALL_BYTES gate keeps
           memory bounded. */
        const contentLength = parseInt(resp.headers.get('Content-Length') ?? '', 10);
        if (Number.isFinite(contentLength) && contentLength > MAX_TARBALL_BYTES) {
            logger?.info(`Skipping tarball analysis: ${archiveUrl} exceeds ${MAX_TARBALL_BYTES} bytes`);
            return null;
        }

        const arrayBuf = await resp.arrayBuffer();
        if (arrayBuf.byteLength > MAX_TARBALL_BYTES) {
            return null;
        }

        const gzBuf = Buffer.from(arrayBuf);
        /* `gunzipSync` returns the uncompressed tar stream. We accept the
           synchronous cost (we already awaited the body above; CPU work
           here is bounded by MAX_TARBALL_BYTES decompressed). */
        const tarBuf = gunzipSync(gzBuf);

        const analysis = analyzeTarBuffer(tarBuf);
        await cache?.set(key, analysis);
        return analysis;
    } catch (err) {
        /* Any failure (network, gunzip, malformed tar, pubspec parse) is
           swallowed here so one bad package never poisons the scan. We log
           so the user can see why a particular package has no code-size
           data, but we never throw. */
        logger?.info(`Tarball analysis failed for ${archiveUrl}: ${err instanceof Error ? err.message : 'unknown'}`);
        return null;
    }
}

/**
 * Walk a tar buffer, summing per-folder bytes, deciding maintainer-quality
 * flags, and parsing the package's own pubspec for `flutter.assets:` so
 * declared assets contribute to `codeSizeBytes` but example/test fixture
 * media do not.
 *
 * Exported (vs `private`) so the unit test can feed it a synthetic tar
 * buffer without touching the network — see tarball-analyzer.test.ts.
 */
export function analyzeTarBuffer(tarBuf: Buffer): TarballAnalysis {
    const entries = parseTarEntries(tarBuf);
    /* Pub.dev tarballs use a top-level wrapper directory like `<name>-<version>/`.
       Strip it once so per-folder bucketing sees normalized paths
       (`lib/foo.dart`, `example/main.dart`). When entries are already
       unwrapped (some test fixtures), the strip is a no-op. */
    const stripped = stripCommonPrefix(entries);

    const pubspec = stripped.find(e => e.path === 'pubspec.yaml');
    const declaredAssetPaths = pubspec
        ? parseFlutterAssetPaths(pubspec.data.toString('utf8'))
        : new Set<string>();

    let archiveUncompressedBytes = 0;
    let libBytes = 0;
    let exampleBytes = 0;
    let testBytes = 0;
    let toolBytes = 0;
    let docBytes = 0;
    let otherBytes = 0;
    let declaredAssetBytes = 0;

    let hasExampleDart = false;
    let hasTestSuiteDart = false;
    let hasToolScript = false;
    let hasDocMarkdown = false;

    for (const entry of stripped) {
        archiveUncompressedBytes += entry.size;
        const folder = topFolder(entry.path);
        switch (folder) {
            case 'lib': libBytes += entry.size; break;
            case 'example':
                exampleBytes += entry.size;
                if (entry.path.endsWith('.dart')) { hasExampleDart = true; }
                break;
            case 'test':
                testBytes += entry.size;
                /* Require `_test.dart` so a `test/` folder with just a
                   placeholder README or a single helper doesn't count as
                   "ships a test suite". Stub coverage is not coverage. */
                if (entry.path.endsWith('_test.dart')) { hasTestSuiteDart = true; }
                break;
            case 'tool':
                toolBytes += entry.size;
                if (
                    entry.path.endsWith('.dart')
                    || entry.path.endsWith('.sh')
                    || entry.path.endsWith('.ps1')
                ) { hasToolScript = true; }
                break;
            case 'doc':
                docBytes += entry.size;
                /* Exclude the auto-generated `doc/api/` Dartdoc dump — its
                   presence is automatic, not a maintainer signal. Require a
                   non-api markdown file for the hasDocs flag. */
                if (
                    entry.path.endsWith('.md')
                    && !entry.path.startsWith('doc/api/')
                ) { hasDocMarkdown = true; }
                break;
            default: otherBytes += entry.size; break;
        }

        if (declaredAssetPaths.size > 0 && pathMatchesDeclaredAsset(entry.path, declaredAssetPaths)) {
            declaredAssetBytes += entry.size;
        }
    }

    return {
        archiveUncompressedBytes,
        /* lib + declared assets is what reaches a built app. We deliberately
           do NOT add native plugin binaries here — those live in separate
           platform sub-packages (audioplayers_android, audioplayers_darwin,
           …) which are analyzed independently as transitive deps and roll
           up via TransitiveInfo. Trying to predict cross-package contents
           here would double-count or miss depending on the package shape. */
        codeSizeBytes: libBytes + declaredAssetBytes,
        folderBreakdown: {
            lib: libBytes,
            example: exampleBytes,
            test: testBytes,
            tool: toolBytes,
            doc: docBytes,
            other: otherBytes,
        },
        maintainerQuality: {
            hasExample: hasExampleDart,
            hasTests: hasTestSuiteDart,
            hasTools: hasToolScript,
            hasDocs: hasDocMarkdown,
        },
    };
}

interface TarEntry {
    readonly path: string;
    readonly size: number;
    readonly data: Buffer;
}

/**
 * Minimal POSIX ustar parser. Reads 512-byte headers, extracts name + size,
 * skips entries we can't classify (size=NaN, type='5' directory), and stops
 * at the first all-zero block. Robust to PAX extension headers (type 'x' or
 * 'g') — we just skip them rather than trying to decode global keyword
 * records, since we only need filenames and sizes.
 *
 * Does NOT support sparse files or GNU long-name extensions; those are rare
 * in pub.dev archives. If they appear, the corresponding entries are skipped
 * via best-effort parsing rather than throwing.
 */
function parseTarEntries(tarBuf: Buffer): TarEntry[] {
    const entries: TarEntry[] = [];
    let offset = 0;
    while (offset + TAR_BLOCK_SIZE <= tarBuf.length) {
        const header = tarBuf.subarray(offset, offset + TAR_BLOCK_SIZE);

        /* All-zero block signals end-of-archive in POSIX tar. We check just
           the first 8 bytes — a real header always has a non-zero
           filename byte 0 (or it's the empty-name end marker). */
        if (header[0] === 0) { break; }

        const name = readCString(header, 0, TAR_NAME_LEN);
        const prefix = readCString(header, TAR_PREFIX_OFFSET, TAR_PREFIX_LEN);
        const path = prefix ? `${prefix}/${name}` : name;

        const sizeStr = readCString(header, TAR_SIZE_OFFSET, TAR_SIZE_LEN).trim();
        const size = parseInt(sizeStr, 8);

        const typeFlag = String.fromCharCode(header[TAR_TYPEFLAG_OFFSET] || 0);

        offset += TAR_BLOCK_SIZE;

        if (!Number.isFinite(size) || size < 0) { continue; }

        /* Data blocks are padded to a 512-byte boundary. */
        const dataPaddedLen = Math.ceil(size / TAR_BLOCK_SIZE) * TAR_BLOCK_SIZE;

        if (path && (typeFlag === '0' || typeFlag === '\0' || typeFlag === '')) {
            /* Regular file. Slice the file data so callers (specifically the
               pubspec.yaml decoder) can read it without re-walking the tar. */
            const data = tarBuf.subarray(offset, Math.min(offset + size, tarBuf.length));
            entries.push({ path, size, data });
        }
        /* For type '5' (dir), 'x'/'g' (PAX), 'L'/'K' (GNU long), etc. we
           still advance past the data blocks. We just don't add an entry. */

        offset += dataPaddedLen;
    }
    return entries;
}

/** Read a null-terminated ASCII field out of a tar header. */
function readCString(buf: Buffer, off: number, len: number): string {
    let end = off;
    const max = off + len;
    while (end < max && buf[end] !== 0) { end++; }
    return buf.toString('ascii', off, end);
}

/**
 * Pub.dev tarballs wrap everything in `<name>-<version>/`. Strip the wrapper
 * once so per-folder logic sees `lib/foo.dart` rather than
 * `audioplayers-6.6.0/lib/foo.dart`. If no common prefix exists (rare —
 * malformed archive or synthetic test fixture), entries are returned
 * unmodified.
 */
function stripCommonPrefix(entries: readonly TarEntry[]): TarEntry[] {
    if (entries.length === 0) { return []; }
    const first = entries[0].path;
    const slashIdx = first.indexOf('/');
    if (slashIdx <= 0) { return [...entries]; }
    const prefix = first.slice(0, slashIdx + 1);

    /* Only strip when every entry shares the prefix — protects against
       odd archives that mix wrapped and unwrapped paths. */
    const allShare = entries.every(e => e.path.startsWith(prefix));
    if (!allShare) { return [...entries]; }

    return entries.map(e => ({ ...e, path: e.path.slice(prefix.length) }));
}

/** Top-level folder name, or empty string for root files. */
function topFolder(path: string): string {
    const slash = path.indexOf('/');
    if (slash < 0) { return ''; }
    return path.slice(0, slash);
}

/**
 * Extract paths under `flutter.assets:` from a pubspec.yaml. The pubspec is
 * the package's OWN pubspec (not the consumer's), so the asset list defines
 * what files are bundled at build time and ship with the user's app.
 *
 * Why regex over a full YAML parser: pubspecs are flat, the asset list has a
 * narrow shape (sequence of strings under `flutter > assets`), and we don't
 * want a YAML dependency for one feature. The existing pubspec-parser.ts
 * uses the same line-based approach.
 *
 * Recognized entries:
 *   - File paths:    `- assets/laser.wav`              → exact match.
 *   - Directory entries (trailing slash): `- assets/`  → prefix match for
 *     everything in that directory.
 */
function parseFlutterAssetPaths(pubspecYaml: string): Set<string> {
    const out = new Set<string>();
    const lines = pubspecYaml.split('\n');

    /* Pubspecs nest assets two levels deep:
         flutter:
           assets:
             - path/one
             - path/two/
       We track depth via heading regexes rather than column counts because
       pub allows tab/space mixing. */
    let inFlutter = false;
    let inAssets = false;

    for (const raw of lines) {
        const line = raw.replace(/\r$/, '');
        if (/^flutter\s*:\s*$/.test(line)) { inFlutter = true; inAssets = false; continue; }
        if (inFlutter && /^[A-Za-z]/.test(line)) { inFlutter = false; inAssets = false; continue; }
        if (inFlutter && /^\s+assets\s*:\s*$/.test(line)) { inAssets = true; continue; }
        if (inAssets && /^\s+[A-Za-z]/.test(line)) {
            /* Anything that isn't a list item or further indented under
               `assets:` ends the assets block (e.g. `fonts:` next). */
            inAssets = false;
            continue;
        }
        if (inAssets) {
            const match = line.match(/^\s*-\s+["']?(.+?)["']?\s*$/);
            if (match) {
                const path = match[1].trim();
                if (path) { out.add(path); }
            }
        }
    }
    return out;
}

/**
 * True when `path` is covered by one of the package's declared assets. We
 * treat trailing-slash entries as directory globs (covers everything under
 * that path) and non-trailing-slash entries as exact file matches.
 */
function pathMatchesDeclaredAsset(path: string, declared: ReadonlySet<string>): boolean {
    if (declared.has(path)) { return true; }
    for (const decl of declared) {
        if (decl.endsWith('/') && path.startsWith(decl)) { return true; }
    }
    return false;
}
