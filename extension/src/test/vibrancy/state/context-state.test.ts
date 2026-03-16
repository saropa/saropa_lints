import * as assert from 'assert';
import * as vscode from 'vscode';
import { ContextState } from '../../../vibrancy/state/context-state';

describe('ContextState', () => {
    const testKey = 'test.contextState';
    let executedCommands: { id: string; args: any[] }[] = [];

    beforeEach(() => {
        executedCommands = [];
        (vscode.commands as any).executeCommand = async (id: string, ...args: any[]) => {
            executedCommands.push({ id, args });
        };
    });

    describe('constructor', () => {
        it('should set initial value', () => {
            const state = new ContextState(testKey, true);
            assert.strictEqual(state.value, true);
        });

        it('should sync initial value to context', () => {
            new ContextState(testKey, 'initial');
            assert.strictEqual(executedCommands.length, 1);
            assert.strictEqual(executedCommands[0].id, 'setContext');
            assert.deepStrictEqual(executedCommands[0].args, [testKey, 'initial']);
        });

        it('should handle null default value', () => {
            const state = new ContextState<string | null>(testKey, null);
            assert.strictEqual(state.value, null);
        });

        it('should handle number default value', () => {
            const state = new ContextState(testKey, 42);
            assert.strictEqual(state.value, 42);
        });
    });

    describe('value setter', () => {
        it('should update value and sync to context', () => {
            const state = new ContextState(testKey, false);
            executedCommands = [];

            state.value = true;

            assert.strictEqual(state.value, true);
            assert.strictEqual(executedCommands.length, 1);
            assert.deepStrictEqual(executedCommands[0].args, [testKey, true]);
        });

        it('should not sync when value unchanged', () => {
            const state = new ContextState(testKey, 'same');
            executedCommands = [];

            state.value = 'same';

            assert.strictEqual(executedCommands.length, 0);
        });

        it('should sync when changing from null to value', () => {
            const state = new ContextState<string | null>(testKey, null);
            executedCommands = [];

            state.value = 'notNull';

            assert.strictEqual(executedCommands.length, 1);
            assert.deepStrictEqual(executedCommands[0].args, [testKey, 'notNull']);
        });

        it('should sync when changing from value to null', () => {
            const state = new ContextState<string | null>(testKey, 'hasValue');
            executedCommands = [];

            state.value = null;

            assert.strictEqual(executedCommands.length, 1);
            assert.deepStrictEqual(executedCommands[0].args, [testKey, null]);
        });
    });

    describe('sync', () => {
        it('should force sync current value', () => {
            const state = new ContextState(testKey, 'value');
            executedCommands = [];

            state.sync();

            assert.strictEqual(executedCommands.length, 1);
            assert.deepStrictEqual(executedCommands[0].args, [testKey, 'value']);
        });
    });

    describe('reset', () => {
        it('should set new value and sync', () => {
            const state = new ContextState(testKey, 'old');
            executedCommands = [];

            state.reset('new');

            assert.strictEqual(state.value, 'new');
            assert.strictEqual(executedCommands.length, 1);
            assert.deepStrictEqual(executedCommands[0].args, [testKey, 'new']);
        });

        it('should sync even when reset to same value', () => {
            const state = new ContextState(testKey, 'same');
            executedCommands = [];

            state.reset('same');

            assert.strictEqual(executedCommands.length, 1);
        });
    });
});
