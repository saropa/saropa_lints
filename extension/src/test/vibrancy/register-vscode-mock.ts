/**
 * Registers the vscode mock module so that source files importing 'vscode'
 * resolve to the local mock instead. Must be imported before any source module
 * that transitively depends on vscode.
 *
 * Usage: add `import './register-vscode-mock';` as the FIRST import in your test file.
 */
import Module from 'module';

const originalResolve = (Module as any)._resolveFilename;
(Module as any)._resolveFilename = function (
    request: string,
    parent: any,
    ...rest: any[]
) {
    if (request === 'vscode') {
        // Redirect to the local vscode mock, resolved relative to this file
        return require.resolve('./vscode-mock');
    }
    return originalResolve.call(this, request, parent, ...rest);
};
