/**
 * Tests [parsePinIntents]: extracting do-not-upgrade / do-not-use intent from
 * pubspec comment blocks so a deliberately-frozen dependency is distinguished
 * from a neglected one. Modeled on the real home_widget / syncfusion pins.
 */
import * as assert from 'assert';
import { parsePinIntents } from '../../../vibrancy/services/pin-intent-parser';

describe('pin-intent-parser', () => {
    it('detects a do-not-upgrade hold from the preceding comment block', () => {
        const content = [
            'dependencies:',
            '  # DO NOT BUMP home_widget TO 0.9.2 — breaks the Android build.',
            '  home_widget: ^0.9.2',
        ].join('\n');

        const intents = parsePinIntents(content);
        const intent = intents.get('home_widget');
        assert.ok(intent);
        assert.strictEqual(intent!.kind, 'do-not-upgrade');
        assert.ok(intent!.reason.includes('DO NOT BUMP home_widget'));
    });

    it('detects a do-not-use package', () => {
        const content = [
            'dependencies:',
            '  # COMMERCIAL PACKAGE - DO NOT USE',
            '  syncfusion_flutter_gauges: ^23.2.7',
        ].join('\n');

        const intent = parsePinIntents(content).get('syncfusion_flutter_gauges');
        assert.ok(intent);
        assert.strictEqual(intent!.kind, 'do-not-use');
    });

    it('reads a trailing inline ignore marker as intent', () => {
        const content = [
            'dependencies:',
            '  home_widget: ^0.9.2 # saropa_lints:ignore prefer_caret_version_syntax',
        ].join('\n');

        const intent = parsePinIntents(content).get('home_widget');
        assert.ok(intent);
        assert.strictEqual(intent!.kind, 'do-not-upgrade');
    });

    it('does not attach an intent to a dep below a blank line', () => {
        const content = [
            'dependencies:',
            '  # DO NOT BUMP this one.',
            '',
            '  http: ^1.6.0',
        ].join('\n');

        assert.strictEqual(parsePinIntents(content).get('http'), undefined);
    });

    it('returns nothing for ordinary documented deps', () => {
        const content = [
            'dependencies:',
            '  # A composable, Future-based library for making HTTP requests.',
            '  # https://pub.dev/packages/http/changelog',
            '  http: ^1.6.0',
        ].join('\n');

        assert.strictEqual(parsePinIntents(content).get('http'), undefined);
    });

    it('binds the intent to the next dep, not one further down', () => {
        const content = [
            'dependencies:',
            '  # NEVER upgrade foo.',
            '  foo: ^1.0.0',
            '  bar: ^2.0.0',
        ].join('\n');

        const intents = parsePinIntents(content);
        assert.ok(intents.get('foo'));
        assert.strictEqual(intents.get('bar'), undefined);
    });
});
