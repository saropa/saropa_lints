import * as assert from 'assert';
import * as vscode from 'vscode';
import { scanDartImports } from '../../../vibrancy/services/import-scanner';

function makeUri(path: string): vscode.Uri {
    return vscode.Uri.file(path) as vscode.Uri;
}

function encode(text: string): Uint8Array {
    return new TextEncoder().encode(text);
}

describe('scanDartImports', () => {
    const originalFindFiles = vscode.workspace.findFiles;
    const originalReadFile = vscode.workspace.fs.readFile;

    afterEach(() => {
        (vscode.workspace as any).findFiles = originalFindFiles;
        (vscode.workspace as any).fs.readFile = originalReadFile;
    });

    it('should detect standard package imports', async () => {
        const files = [makeUri('/proj/lib/main.dart')];
        (vscode.workspace as any).findFiles = async () => files;
        (vscode.workspace as any).fs.readFile = async () =>
            encode("import 'package:http/http.dart';");

        const result = await scanDartImports(makeUri('/proj'));
        assert.ok(result.has('http'));
        assert.strictEqual(result.size, 1);
    });

    it('should detect imports with show/hide', async () => {
        const files = [makeUri('/proj/lib/main.dart')];
        (vscode.workspace as any).findFiles = async () => files;
        (vscode.workspace as any).fs.readFile = async () =>
            encode("import 'package:bloc/bloc.dart' show Bloc;");

        const result = await scanDartImports(makeUri('/proj'));
        assert.ok(result.has('bloc'));
    });

    it('should detect double-quoted imports', async () => {
        const files = [makeUri('/proj/lib/main.dart')];
        (vscode.workspace as any).findFiles = async () => files;
        (vscode.workspace as any).fs.readFile = async () =>
            encode('import "package:provider/provider.dart";');

        const result = await scanDartImports(makeUri('/proj'));
        assert.ok(result.has('provider'));
    });

    it('should ignore relative imports', async () => {
        const files = [makeUri('/proj/lib/main.dart')];
        (vscode.workspace as any).findFiles = async () => files;
        (vscode.workspace as any).fs.readFile = async () =>
            encode("import '../models/user.dart';");

        const result = await scanDartImports(makeUri('/proj'));
        assert.strictEqual(result.size, 0);
    });

    it('should ignore dart: SDK imports', async () => {
        const files = [makeUri('/proj/lib/main.dart')];
        (vscode.workspace as any).findFiles = async () => files;
        (vscode.workspace as any).fs.readFile = async () =>
            encode("import 'dart:core';");

        const result = await scanDartImports(makeUri('/proj'));
        assert.strictEqual(result.size, 0);
    });

    it('should return empty set for empty project', async () => {
        (vscode.workspace as any).findFiles = async () => [];

        const result = await scanDartImports(makeUri('/proj'));
        assert.strictEqual(result.size, 0);
    });

    it('should deduplicate imports across files', async () => {
        const files = [
            makeUri('/proj/lib/a.dart'),
            makeUri('/proj/lib/b.dart'),
        ];
        (vscode.workspace as any).findFiles = async () => files;
        let callCount = 0;
        (vscode.workspace as any).fs.readFile = async () => {
            callCount++;
            return encode("import 'package:http/http.dart';");
        };

        const result = await scanDartImports(makeUri('/proj'));
        assert.strictEqual(result.size, 1);
        assert.strictEqual(callCount, 2);
    });

    it('should collect multiple packages from one file', async () => {
        const files = [makeUri('/proj/lib/main.dart')];
        (vscode.workspace as any).findFiles = async () => files;
        (vscode.workspace as any).fs.readFile = async () =>
            encode(
                "import 'package:http/http.dart';\n"
                + "import 'package:bloc/bloc.dart';\n"
                + "import 'package:provider/provider.dart';",
            );

        const result = await scanDartImports(makeUri('/proj'));
        assert.strictEqual(result.size, 3);
        assert.ok(result.has('http'));
        assert.ok(result.has('bloc'));
        assert.ok(result.has('provider'));
    });
});
