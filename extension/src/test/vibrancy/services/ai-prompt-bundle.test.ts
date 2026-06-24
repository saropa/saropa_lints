/**
 * Tests **ai-prompt-bundle**: assembly of the "Copy for AI" prompt that hands an
 * AI the classified changelog delta plus the project's call sites. Verifies the
 * header, the opportunity lines with API names, the usage section (populated,
 * empty, and truncated), and the null-when-nothing-to-adopt contract.
 */
import * as assert from 'assert';
import { buildAiPromptBundle } from '../../../vibrancy/services/ai-prompt-bundle';
import { mineOpportunities } from '../../../vibrancy/services/changelog-opportunities';
import { ChangelogEntry } from '../../../vibrancy/types';
import { PackageUsage } from '../../../vibrancy/services/import-scanner';

const ENTRIES: ChangelogEntry[] = [
    {
        version: '0.3.0',
        body: [
            '- Added WidgetSpan support to `ReelText.rich`.',
            '- Fixed RTL alignment.',
        ].join('\n'),
    },
];

function usage(filePath: string, importLine: number): PackageUsage {
    return {
        filePath, isCommented: false, line: importLine,
        importLine, exportLine: null, isExport: false,
    };
}

const BASE = {
    packageName: 'reel_text',
    currentVersion: '0.2.0',
    latestVersion: '0.3.0',
    opportunities: mineOpportunities(ENTRIES),
};

describe('ai-prompt-bundle', () => {
    it('returns null when there are no opportunities', () => {
        const empty = mineOpportunities([
            { version: '1.0.1', body: '- Fixed a crash.' },
        ]);
        const result = buildAiPromptBundle({
            ...BASE, opportunities: empty, fileUsages: [usage('lib/a.dart', 1)],
        });
        assert.strictEqual(result, null);
    });

    it('includes the version delta header', () => {
        const out = buildAiPromptBundle({
            ...BASE, fileUsages: [usage('lib/welcome.dart', 408)],
        })!;
        assert.ok(out.includes('`reel_text` from 0.2.0 → 0.3.0'));
    });

    it('lists the opportunity with its category and API name', () => {
        const out = buildAiPromptBundle({
            ...BASE, fileUsages: [usage('lib/welcome.dart', 408)],
        })!;
        assert.ok(out.includes('[added] Added WidgetSpan support'));
        assert.ok(out.includes('API: ReelText.rich'));
    });

    it('excludes Fixed bullets from the prompt', () => {
        const out = buildAiPromptBundle({
            ...BASE, fileUsages: [usage('lib/welcome.dart', 408)],
        })!;
        assert.ok(!out.includes('RTL alignment'));
    });

    it('lists call sites as file:line', () => {
        const out = buildAiPromptBundle({
            ...BASE, fileUsages: [usage('lib/welcome.dart', 408)],
        })!;
        assert.ok(out.includes('lib/welcome.dart:408'));
    });

    it('states when the package is not imported anywhere', () => {
        const out = buildAiPromptBundle({ ...BASE, fileUsages: [] })!;
        assert.ok(out.includes('Not imported in any scanned source file'));
    });

    it('discloses truncation past the file cap', () => {
        const many: PackageUsage[] = [];
        for (let i = 0; i < 40; i++) {
            many.push(usage(`lib/file_${i}.dart`, i + 1));
        }
        const out = buildAiPromptBundle({ ...BASE, fileUsages: many })!;
        assert.ok(out.includes('and 15 more files'), 'missing truncation note');
        assert.ok(out.includes('40 files'), 'missing true total count');
    });

    it('reframes the header for an up-to-date package (no version bump)', () => {
        const out = buildAiPromptBundle({
            ...BASE,
            currentVersion: '0.3.0',
            latestVersion: '0.3.0',
            fileUsages: [usage('lib/welcome.dart', 408)],
        })!;
        const header = out.split('\n')[0];
        assert.ok(header.includes('already on the latest version'));
        assert.ok(!header.includes('→'), 'header should not show an upgrade arrow');
    });

    it('includes the read-the-real-API task discipline', () => {
        const out = buildAiPromptBundle({
            ...BASE, fileUsages: [usage('lib/welcome.dart', 408)],
        })!;
        assert.ok(out.includes('Read the real'));
        assert.ok(out.toLowerCase().includes('no fit'));
    });
});
