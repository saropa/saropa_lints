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

    it('asks both the retrofit and greenfield questions', () => {
        const out = buildAiPromptBundle({
            ...BASE, fileUsages: [usage('lib/welcome.dart', 408)],
        })!;
        assert.ok(out.includes('Retrofit'));
        assert.ok(out.includes('Greenfield'));
    });

    it('surfaces a deprecated API in use with its call sites', () => {
        const empty = mineOpportunities([
            { version: '1.0.1', body: '- Fixed a crash.' },
        ]);
        const out = buildAiPromptBundle({
            ...BASE,
            opportunities: empty,
            fileUsages: [usage('lib/welcome.dart', 408)],
            deprecatedInUse: [{
                apiName: 'ReelText.legacy',
                bulletText: 'ReelText.legacy is deprecated, use ReelText.rich',
                version: '0.3.0',
                usages: [{
                    filePath: 'lib/welcome.dart', line: 12, column: 5,
                    snippet: 'ReelText.legacy(text)',
                }],
            }],
        })!;
        assert.ok(out.includes('Deprecated APIs this project calls'));
        assert.ok(out.includes('ReelText.legacy'));
        assert.ok(out.includes('lib/welcome.dart:12'));
        assert.ok(out.includes('confirm the replacement'));
    });

    it('omits the deprecation task line when nothing deprecated is in use', () => {
        const out = buildAiPromptBundle({
            ...BASE, fileUsages: [usage('lib/welcome.dart', 408)],
        })!;
        assert.ok(!out.includes('confirm the replacement'));
    });

    it('surfaces package health including vulnerabilities and license', () => {
        const out = buildAiPromptBundle({
            ...BASE,
            fileUsages: [usage('lib/welcome.dart', 408)],
            health: {
                score: 42, category: 'outdated', license: 'GPL-3.0',
                pubPoints: 90, vulnerabilityCount: 2,
                worstVulnerabilitySeverity: 'high',
                knownIssueStatus: 'discontinued',
                knownIssueReplacement: 'reel_text_next',
            },
        })!;
        assert.ok(out.includes('Package health'));
        assert.ok(out.includes('outdated (score 42/100)'));
        assert.ok(out.includes('License: GPL-3.0'));
        assert.ok(out.includes('SECURITY: 2 known vulnerabilities, worst severity high'));
        assert.ok(out.includes('discontinued'));
        assert.ok(out.includes('reel_text_next'));
    });

    it('surfaces flagged upstream GitHub issues', () => {
        const out = buildAiPromptBundle({
            ...BASE,
            fileUsages: [usage('lib/welcome.dart', 408)],
            flaggedIssues: [{
                number: 42, title: 'Crashes on rebuild',
                url: 'https://github.com/x/y/issues/42',
                matchedSignals: ['crash'], commentCount: 12,
            }],
        })!;
        assert.ok(out.includes('Upstream issues flagged as high-signal'));
        assert.ok(out.includes('#42 "Crashes on rebuild"'));
        assert.ok(out.includes('12 comments'));
    });

    it('surfaces a dual-dependency risk with its via-package constraint', () => {
        const out = buildAiPromptBundle({
            ...BASE,
            fileUsages: [usage('lib/welcome.dart', 408)],
            dualDependency: {
                packageName: 'reel_text',
                directConstraint: '^0.2.0',
                sources: [{ viaPackage: 'reel_widgets', viaConstraint: '^0.1.9' }],
            },
        })!;
        assert.ok(out.includes('Dual dependency risk'));
        assert.ok(out.includes('Direct: reel_text ^0.2.0'));
        assert.ok(out.includes('also required by `reel_widgets` ^0.1.9'));
        assert.ok(out.includes('type identity'));
    });

    it('is not null when only a dual-dependency risk exists with no adoptable opportunities', () => {
        const empty = mineOpportunities([
            { version: '1.0.1', body: '- Fixed a crash.' },
        ]);
        const out = buildAiPromptBundle({
            ...BASE,
            opportunities: empty,
            fileUsages: [usage('lib/welcome.dart', 408)],
            dualDependency: {
                packageName: 'reel_text',
                directConstraint: '^0.2.0',
                sources: [{ viaPackage: 'reel_widgets', viaConstraint: null }],
            },
        });
        assert.ok(out !== null);
        assert.ok(out!.includes('Dual dependency risk'));
    });

    it('surfaces a possible local reimplementation match', () => {
        const out = buildAiPromptBundle({
            ...BASE,
            fileUsages: [usage('lib/welcome.dart', 408)],
            localReimplementations: [{
                name: 'retryWithBackoff',
                kind: 'function',
                filePath: 'lib/utils/retry_utils.dart',
                line: 12,
            }],
        })!;
        assert.ok(out.includes('Possible local reimplementation'));
        assert.ok(out.includes('`retryWithBackoff` (function) at lib/utils/retry_utils.dart:12'));
        assert.ok(out.includes('name match is not a signature match'));
    });

    it('is not null when only a local reimplementation match exists with no adoptable opportunities', () => {
        const empty = mineOpportunities([
            { version: '1.0.1', body: '- Fixed a crash.' },
        ]);
        const out = buildAiPromptBundle({
            ...BASE,
            opportunities: empty,
            fileUsages: [usage('lib/welcome.dart', 408)],
            localReimplementations: [{
                name: 'isListNullOrEmpty',
                kind: 'extensionMember',
                filePath: 'lib/extensions/list_ext.dart',
                line: 5,
            }],
        });
        assert.ok(out !== null);
        assert.ok(out!.includes('Possible local reimplementation'));
    });

    it('is not null when only a vulnerability exists with no adoptable opportunities', () => {
        const empty = mineOpportunities([
            { version: '1.0.1', body: '- Fixed a crash.' },
        ]);
        const out = buildAiPromptBundle({
            ...BASE,
            opportunities: empty,
            fileUsages: [usage('lib/welcome.dart', 408)],
            health: {
                score: 20, category: 'abandoned', license: null,
                pubPoints: 10, vulnerabilityCount: 1,
                worstVulnerabilitySeverity: 'critical',
                knownIssueStatus: null, knownIssueReplacement: null,
            },
        });
        assert.ok(out !== null);
        assert.ok(out!.includes('SECURITY'));
    });
});
