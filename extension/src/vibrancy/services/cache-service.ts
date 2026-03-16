import * as vscode from 'vscode';
import { CacheEntry } from '../types';

const DEFAULT_TTL_MS = 24 * 60 * 60 * 1000;
const KEY_PREFIX = 'spv.';

export class CacheService {
    constructor(
        private readonly _state: vscode.Memento,
        private readonly _ttlMs: number = DEFAULT_TTL_MS,
    ) {}

    get<T>(key: string): T | null {
        const entry = this._state.get<CacheEntry<T>>(KEY_PREFIX + key);
        if (!entry) { return null; }
        if (Date.now() - entry.timestamp > this._ttlMs) { return null; }
        return entry.data;
    }

    async set<T>(key: string, data: T): Promise<void> {
        const entry: CacheEntry<T> = { data, timestamp: Date.now() };
        await this._state.update(KEY_PREFIX + key, entry);
    }

    async clear(): Promise<void> {
        for (const key of this._state.keys()) {
            if (key.startsWith(KEY_PREFIX)) {
                await this._state.update(key, undefined);
            }
        }
    }
}
