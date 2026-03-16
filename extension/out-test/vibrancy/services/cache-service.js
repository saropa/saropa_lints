"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.CacheService = void 0;
const DEFAULT_TTL_MS = 24 * 60 * 60 * 1000;
const KEY_PREFIX = 'spv.';
class CacheService {
    _state;
    _ttlMs;
    constructor(_state, _ttlMs = DEFAULT_TTL_MS) {
        this._state = _state;
        this._ttlMs = _ttlMs;
    }
    get(key) {
        const entry = this._state.get(KEY_PREFIX + key);
        if (!entry) {
            return null;
        }
        if (Date.now() - entry.timestamp > this._ttlMs) {
            return null;
        }
        return entry.data;
    }
    async set(key, data) {
        const entry = { data, timestamp: Date.now() };
        await this._state.update(KEY_PREFIX + key, entry);
    }
    async clear() {
        for (const key of this._state.keys()) {
            if (key.startsWith(KEY_PREFIX)) {
                await this._state.update(key, undefined);
            }
        }
    }
}
exports.CacheService = CacheService;
//# sourceMappingURL=cache-service.js.map