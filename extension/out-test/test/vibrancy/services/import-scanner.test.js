"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
const assert = __importStar(require("assert"));
const vscode = __importStar(require("vscode"));
const import_scanner_1 = require("../../../vibrancy/services/import-scanner");
function makeUri(path) {
    return vscode.Uri.file(path);
}
function encode(text) {
    return new TextEncoder().encode(text);
}
describe('scanDartImports', () => {
    const originalFindFiles = vscode.workspace.findFiles;
    const originalReadFile = vscode.workspace.fs.readFile;
    afterEach(() => {
        vscode.workspace.findFiles = originalFindFiles;
        vscode.workspace.fs.readFile = originalReadFile;
    });
    it('should detect standard package imports', async () => {
        const files = [makeUri('/proj/lib/main.dart')];
        vscode.workspace.findFiles = async () => files;
        vscode.workspace.fs.readFile = async () => encode("import 'package:http/http.dart';");
        const result = await (0, import_scanner_1.scanDartImports)(makeUri('/proj'));
        assert.ok(result.has('http'));
        assert.strictEqual(result.size, 1);
    });
    it('should detect imports with show/hide', async () => {
        const files = [makeUri('/proj/lib/main.dart')];
        vscode.workspace.findFiles = async () => files;
        vscode.workspace.fs.readFile = async () => encode("import 'package:bloc/bloc.dart' show Bloc;");
        const result = await (0, import_scanner_1.scanDartImports)(makeUri('/proj'));
        assert.ok(result.has('bloc'));
    });
    it('should detect double-quoted imports', async () => {
        const files = [makeUri('/proj/lib/main.dart')];
        vscode.workspace.findFiles = async () => files;
        vscode.workspace.fs.readFile = async () => encode('import "package:provider/provider.dart";');
        const result = await (0, import_scanner_1.scanDartImports)(makeUri('/proj'));
        assert.ok(result.has('provider'));
    });
    it('should ignore relative imports', async () => {
        const files = [makeUri('/proj/lib/main.dart')];
        vscode.workspace.findFiles = async () => files;
        vscode.workspace.fs.readFile = async () => encode("import '../models/user.dart';");
        const result = await (0, import_scanner_1.scanDartImports)(makeUri('/proj'));
        assert.strictEqual(result.size, 0);
    });
    it('should ignore dart: SDK imports', async () => {
        const files = [makeUri('/proj/lib/main.dart')];
        vscode.workspace.findFiles = async () => files;
        vscode.workspace.fs.readFile = async () => encode("import 'dart:core';");
        const result = await (0, import_scanner_1.scanDartImports)(makeUri('/proj'));
        assert.strictEqual(result.size, 0);
    });
    it('should return empty set for empty project', async () => {
        vscode.workspace.findFiles = async () => [];
        const result = await (0, import_scanner_1.scanDartImports)(makeUri('/proj'));
        assert.strictEqual(result.size, 0);
    });
    it('should deduplicate imports across files', async () => {
        const files = [
            makeUri('/proj/lib/a.dart'),
            makeUri('/proj/lib/b.dart'),
        ];
        vscode.workspace.findFiles = async () => files;
        let callCount = 0;
        vscode.workspace.fs.readFile = async () => {
            callCount++;
            return encode("import 'package:http/http.dart';");
        };
        const result = await (0, import_scanner_1.scanDartImports)(makeUri('/proj'));
        assert.strictEqual(result.size, 1);
        assert.strictEqual(callCount, 2);
    });
    it('should collect multiple packages from one file', async () => {
        const files = [makeUri('/proj/lib/main.dart')];
        vscode.workspace.findFiles = async () => files;
        vscode.workspace.fs.readFile = async () => encode("import 'package:http/http.dart';\n"
            + "import 'package:bloc/bloc.dart';\n"
            + "import 'package:provider/provider.dart';");
        const result = await (0, import_scanner_1.scanDartImports)(makeUri('/proj'));
        assert.strictEqual(result.size, 3);
        assert.ok(result.has('http'));
        assert.ok(result.has('bloc'));
        assert.ok(result.has('provider'));
    });
});
//# sourceMappingURL=import-scanner.test.js.map