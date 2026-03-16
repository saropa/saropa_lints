import * as assert from 'assert';

describe('Extension', () => {
    it('should export activate and deactivate', () => {
        const ext = require('../extension');
        assert.strictEqual(typeof ext.activate, 'function');
        assert.strictEqual(typeof ext.deactivate, 'function');
    });
});
