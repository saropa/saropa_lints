/**
 * Tests **import-scanner** symbol-usage helpers: `collectImportsFromSources`
 * (pure import map from pre-read sources) and `collectSymbolUsage` (which
 * changelog API names appear in project source). These drive the "already
 * adopted vs unused" distinction that turns an up-to-date package into a needle.
 */
// Must precede any import that transitively pulls in 'vscode' (import-scanner
// does), so the module resolves to the local mock instead of failing.
import '../register-vscode-mock';
import * as assert from 'assert';
import {
    collectSymbolUsage,
    collectImportsFromSources,
    DartSource,
} from '../../../vibrancy/services/import-scanner';

function src(path: string, text: string): DartSource {
    return { path, text };
}

describe('symbol-usage', () => {
    describe('collectSymbolUsage', () => {
        it('returns empty when there are no candidates', () => {
            const used = collectSymbolUsage(
                [src('lib/a.dart', 'final x = ReelText();')],
                new Set<string>(),
            );
            assert.strictEqual(used.size, 0);
        });

        it('finds a used symbol and omits an unused one', () => {
            const sources = [src('lib/a.dart', 'final x = ReelText("hi");')];
            const used = collectSymbolUsage(
                sources, new Set(['ReelText', 'WidgetSpan']),
            );
            assert.ok(used.has('ReelText'));
            assert.ok(!used.has('WidgetSpan'));
        });

        it('does not match a symbol that is a substring of an identifier', () => {
            const sources = [src('lib/a.dart', 'final x = ReelTextController();')];
            const used = collectSymbolUsage(sources, new Set(['ReelText']));
            // "ReelText" is a prefix of "ReelTextController" — word boundary
            // must prevent a false positive.
            assert.ok(!used.has('ReelText'));
        });

        it('matches dotted member access in preference to the bare owner', () => {
            const sources = [src('lib/a.dart', 'x.then(ReelText.rich);')];
            const used = collectSymbolUsage(
                sources, new Set(['ReelText', 'ReelText.rich']),
            );
            assert.ok(used.has('ReelText.rich'));
        });

        it('scans across multiple files', () => {
            const sources = [
                src('lib/a.dart', 'final a = ReelText();'),
                src('lib/b.dart', 'final b = WidgetSpan();'),
            ];
            const used = collectSymbolUsage(
                sources, new Set(['ReelText', 'WidgetSpan']),
            );
            assert.strictEqual(used.size, 2);
        });
    });

    describe('collectImportsFromSources', () => {
        it('maps a package import to its file', () => {
            const sources = [src(
                'lib/a.dart',
                "import 'package:reel_text/reel_text.dart';\nvoid main() {}",
            )];
            const map = collectImportsFromSources(sources);
            const usages = map.get('reel_text');
            assert.ok(usages && usages.length === 1);
            assert.strictEqual(usages![0].filePath, 'lib/a.dart');
        });
    });
});
