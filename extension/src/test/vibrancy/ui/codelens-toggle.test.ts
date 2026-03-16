import * as assert from 'assert';
import { CodeLensToggle } from '../../../vibrancy/ui/codelens-toggle';

describe('CodeLensToggle', () => {
    let toggle: CodeLensToggle;

    beforeEach(() => {
        toggle = new CodeLensToggle();
    });

    afterEach(() => {
        toggle.dispose();
    });

    describe('initial state', () => {
        it('should be enabled by default', () => {
            assert.strictEqual(toggle.isEnabled, true);
        });
    });

    describe('toggle', () => {
        it('should flip state from enabled to disabled', () => {
            toggle.toggle();
            assert.strictEqual(toggle.isEnabled, false);
        });

        it('should flip state from disabled to enabled', () => {
            toggle.toggle();
            toggle.toggle();
            assert.strictEqual(toggle.isEnabled, true);
        });
    });

    describe('show', () => {
        it('should enable when disabled', () => {
            toggle.hide();
            toggle.show();
            assert.strictEqual(toggle.isEnabled, true);
        });

        it('should stay enabled when already enabled', () => {
            toggle.show();
            assert.strictEqual(toggle.isEnabled, true);
        });
    });

    describe('hide', () => {
        it('should disable when enabled', () => {
            toggle.hide();
            assert.strictEqual(toggle.isEnabled, false);
        });

        it('should stay disabled when already disabled', () => {
            toggle.hide();
            toggle.hide();
            assert.strictEqual(toggle.isEnabled, false);
        });
    });

    describe('onDidChange event', () => {
        it('should fire when toggled', (done) => {
            toggle.onDidChange((enabled) => {
                assert.strictEqual(enabled, false);
                done();
            });
            toggle.toggle();
        });

        it('should fire when shown', (done) => {
            toggle.hide();
            toggle.onDidChange((enabled) => {
                assert.strictEqual(enabled, true);
                done();
            });
            toggle.show();
        });

        it('should fire when hidden', (done) => {
            toggle.onDidChange((enabled) => {
                assert.strictEqual(enabled, false);
                done();
            });
            toggle.hide();
        });

        it('should not fire when show called while enabled', () => {
            let fired = false;
            toggle.onDidChange(() => { fired = true; });
            toggle.show();
            assert.strictEqual(fired, false);
        });

        it('should not fire when hide called while disabled', () => {
            toggle.hide();
            let fired = false;
            toggle.onDidChange(() => { fired = true; });
            toggle.hide();
            assert.strictEqual(fired, false);
        });
    });

    describe('dispose', () => {
        it('should be callable multiple times', () => {
            toggle.dispose();
            toggle.dispose();
        });
    });
});
