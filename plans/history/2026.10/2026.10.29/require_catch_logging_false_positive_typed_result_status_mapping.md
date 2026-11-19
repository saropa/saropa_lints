# BUG: `require_catch_logging` - `on Object { return const <Result>(<failure status>); }` that maps an expected failure to a typed result

**Status: Fixed** (2026-10-29: a lone `return Foo(...)` in a catch is exempt; reproduced with resolved scan before, verified after)

Supersedes: the earlier version of this file (same path, revised 2026-10-29 with the evidence sections below); the older fixed report `/Users/craighathaway/src/saropa_lints/plans/history/2026.09/2026.09.05/require_catch_logging_false_positive_intentional_fallback.md` covered a different pattern (fallback values with comments); finding still fires on 17.0.1-beta.4 in the reporter's project. Unlike the other reports in this series, beta.4 SOURCE does report this location (no exemption exists), so this one does not depend on the stale-export question.

Created: 2026-10-29
Rule: `require_catch_logging`
File: `lib/src/rules/security/security_network_input_rules.dart` (class 4545, code 4574, handler `runWithReporter` ~4624, `_isExceptionUsedMeaningfully` ~4689)
Severity: False positive
Rule version: v2 | Since: see rule dartdoc | Updated: see rule dartdoc

---

## Summary

A catch clause that never names the exception and returns a `const` typed failure value (`BackupDecryptResult(BackupDecryptStatus.authenticationFailed)`) is reported as a swallowed exception. The failure is expected (wrong key or modified file) and is reported to the caller as a typed status. Nothing is lost; the caller decides how to present it. Logging is also unwanted: the function runs inside an isolate (`Isolate.run`) and a wrong key is routine.

---

## Version Caveat (read first)

The reporter states these diagnostics still fire on saropa_lints 17.0.1-beta.4. The files on disk show the diagnostics were exported BEFORE the project resolved to beta.4:

| Evidence | Value |
|---|---|
| `bugs/issues.json` (the diagnostics export) modified | Oct 29 2026 19:53:44 |
| `pubspec.yaml` modified (dependency changed to `saropa_lints: ^17.0.1-beta.4`) | Oct 29 2026 19:56:29 |
| `pubspec.lock` and `.dart_tool/package_config.json` modified (first resolve to beta.4) | Oct 29 2026 19:57:50 |
| `pubspec.lock` at git HEAD (0a20d04ed2) | saropa_lints `17.0.0`, analyzer `14.6.0` |
| `pubspec.lock` in working tree | saropa_lints `17.0.1-beta.4`, analyzer `14.7.0` |
| `.dart_tool/package_config.json` | `saropa_lints` rootUri `file:///Users/craighathaway/.pub-cache/hosted/pub.dev/saropa_lints-17.0.1-beta.4` |
| `analysis_options.yaml` lines 1170-1173 | plugin block is commented out under "saropa_lints integration turned OFF by the VS Code extension", its commented `version:` is `"17.0.0"` |
| `owner` of every diagnostic | `saropaLintsLsp` (the VS Code extension `saropa.saropa-lints-17.0.13` language server, `dist/extension.js` contains the string) |

Consequence: the engine that produced `issues.json` is not proven to be beta.4. The exemption code for each rule below was checked per release tag with `git show <tag>:<file> | grep -c <marker>`:

| Rule fix marker | beta.2 | beta.3 | beta.4 |
|---|---|---|---|
| `NeverType` in `code_quality_avoid_rules.dart` (avoid_ignoring_return_values) | 0 | 1 | 1 |
| `_isAccumulatorTypeName` in `code_quality_variables_rules.dart` (avoid_parameter_mutation) | 0 | 2 | 2 |
| `isDeclaredInsideNearestLoop` in `performance_rules.dart` (string concat rules) | 0 | 3 | 3 |
| `_isGuardedByShortCircuit` in `collection_rules.dart` (avoid_unsafe_collection_methods) | 0 | 2 | 2 |

The pub-cache copy `~/.pub-cache/hosted/pub.dev/saropa_lints-17.0.1-beta.4/lib` is identical to `/Users/craighathaway/src/saropa_lints/lib` (`diff -rq` lists only three extra untracked paths in the repo: `lib/src/cli/project_health/reports`, `lib/src/reports`, `lib/src/rules/visitor_import_patch.txt`).

**What was NOT verified:** which rule engine and version produced the export. No scan, analyze or test was run for this report (the reporter's machine is memory-limited and the owner forbade it). The "Root Cause" section below states, per location, whether the beta.4 SOURCE would report it.


For this rule no exemption marker exists in any release (the handler has no code path that allows a catch without a referenced exception to pass), so the Version Caveat does not weaken this report.

---

## Attribution Evidence

```bash
grep -rn "'require_catch_logging'" lib/src/rules/
# lib/src/rules/security/security_network_input_rules.dart:4574:    'require_catch_logging',
```

**Emitter registration:** `lib/src/rules/security/security_network_input_rules.dart:4574`
**Rule class:** `RequireCatchLoggingRule` - registered in `lib/saropa_lints.dart:1862`
**Diagnostic `source` / `owner` as seen in Problems panel:** `saropa_lints` / `saropaLintsLsp`
Negative grep not needed: the code name occurs only in this repository's `lib/src/rules/`.

---

## Diagnostics From The Reporter's Project (exact JSON from `bugs/issues.json`)

1 entry:

- `lib/database/file_backup/encryption/backup_crypto_codec.dart` 181:7 to 185:6

```json
{
  "resource": "/Users/craighathaway/Documents/src/contacts/lib/database/file_backup/encryption/backup_crypto_codec.dart",
  "owner": "saropaLintsLsp",
  "code": "require_catch_logging",
  "severity": 4,
  "message": "[require_catch_logging] Catch block swallows the exception without logging or rethrowing. Security-relevant errors such as authentication failures, permission violations, and data corruption go completely undetected. This prevents incident response, makes debugging production issues impossible, and hides potential attack activity. {v2}",
  "source": "saropa_lints",
  "startLineNumber": 181,
  "startColumn": 7,
  "endLineNumber": 185,
  "endColumn": 6,
  "origin": "extHost1"
}
```

---

## Real Code At HEAD (`git show HEAD:lib/database/file_backup/encryption/backup_crypto_codec.dart`, file unmodified in the working tree)

### Import list (verbatim)

```dart
  1  import 'dart:convert';
  2  import 'dart:io' as io;
  3  import 'dart:isolate';
  4  import 'dart:typed_data';
  6  import 'package:encrypter_plus/encrypter_plus.dart' as encrypt;
```

### Enclosing declarations (verbatim, real line numbers)

`BackupDecryptStatus` and `BackupDecryptResult` (lines 8-41):

```dart
 8  // Docs: docs/deferred/security/PLAN_BACKUP_ADVANCED.md, docs/blocked/ENCRYPTION_EXPORT_COMPLIANCE.md
 9  /// Result of decrypting an encrypted backup file.
10  enum BackupDecryptStatus {
11    /// Decrypted and decompressed.
12    ok,
13  
14    /// The file is shorter than the header plus nonce plus tag.
15    truncated,
16  
17    /// The version byte is newer than this app understands.
18    unsupportedVersion,
19  
20    /// The authentication tag did not match: wrong key, a changed header
21    /// byte, or a changed body byte.
22    authenticationFailed,
23  }
24  
25  /// Parsed clear-text header of an encrypted backup file.
26  class BackupEncryptionHeader {
27    const BackupEncryptionHeader({required this.version, required this.keyId});
28  
29    final int version;
30  
31    /// 16 random bytes, lower-case hex (32 chars). Names the key
32    /// `backup_key_<keyId>` in the phone key store.
33    final String keyId;
34  }
35  
36  class BackupDecryptResult {
37    const BackupDecryptResult(this.status, [this.text]);
38  
39    final BackupDecryptStatus status;
40    final String? text;
41  }
```

`decryptToText` (async wrapper, lines 114-117) and the flagged method `decryptToTextSync` (lines 154-186; the flagged catch clause is 181:7-185:6):

```dart
114    static Future<BackupDecryptResult> decryptToText({
115      required Uint8List fileBytes,
116      required Uint8List keyBytes,
117    }) => Isolate.run(() => decryptToTextSync(fileBytes: fileBytes, keyBytes: keyBytes));
```

```dart
153    /// Synchronous form of [decryptToText].
154    static BackupDecryptResult decryptToTextSync({
155      required Uint8List fileBytes,
156      required Uint8List keyBytes,
157    }) {
158      if (fileBytes.length < minimumFileLength) {
159        return const BackupDecryptResult(BackupDecryptStatus.truncated);
160      }
161      if (fileBytes[8] != currentVersion) {
162        return const BackupDecryptResult(BackupDecryptStatus.unsupportedVersion);
163      }
164      try {
165        final Uint8List header = Uint8List.sublistView(fileBytes, 0, headerLength);
166        final encrypt.IV iv = encrypt.IV(
167          Uint8List.sublistView(fileBytes, headerLength, headerLength + nonceLength),
168        );
169        final encrypt.Encrypted sealed = encrypt.Encrypted(
170          Uint8List.sublistView(fileBytes, headerLength + nonceLength),
171        );
172        final Uint8List gzipped = _aes(keyBytes).decrypt(
173          sealed,
174          iv: iv,
175          associatedData: header,
176        );
177        return BackupDecryptResult(
178          BackupDecryptStatus.ok,
179          utf8.decode(io.gzip.decode(gzipped)),
180        );
181      } on Object {
182        // pointycastle throws InvalidCipherTextException when the GCM tag
183        // does not match. The cause is never reported to the user as corruption.
184        return const BackupDecryptResult(BackupDecryptStatus.authenticationFailed);
185      }
186    }
```

### Declarations of every non-SDK type/function involved

| Symbol | Declared in | Signature |
|---|---|---|
| `BackupDecryptResult` | `lib/database/file_backup/encryption/backup_crypto_codec.dart` lines 36-41 | `class BackupDecryptResult { const BackupDecryptResult(this.status, [this.text]); final BackupDecryptStatus status; final String? text; }` |
| `BackupDecryptStatus` | same file lines 9-21 | `enum BackupDecryptStatus { ok, truncated, unsupportedVersion, authenticationFailed }` |
| `encrypt.AES`, `encrypt.IV`, `encrypt.Encrypted`, `encrypt.Key` | `package:encrypter_plus/encrypter_plus.dart` 5.1.0 (import line 6, prefix `encrypt`) | `AES.decrypt` is `Uint8List decrypt(Encrypted encrypted, {IV? iv, Uint8List? associatedData})` (`algorithm.dart` line 9, `algorithms/aes.dart` line 50); it throws pointycastle `InvalidCipherTextException` on a GCM tag mismatch |
| `io.gzip.decode` | SDK `dart:io` | `List<int> decode(List<int> bytes)` |
| `utf8.decode` | SDK `dart:convert` | `String decode(List<int> codeUnits, ...)` |

No logging helper exists in this file (it has no import of `debug.dart`): the file is a pure codec that runs in an isolate.

---

## Resolved Static Types

- Catch clause: `on Object` with NO exception parameter and no stack parameter (`CatchClause.exceptionParameter == null`, `exceptionType` = `Object`).
- Body: one `ReturnStatement` whose expression is a `const` `InstanceCreationExpression` of `BackupDecryptResult`; its static type is `BackupDecryptResult` (non-nullable), the declared return type of `decryptToTextSync`.
- Argument: `BackupDecryptStatus.authenticationFailed` (enum constant, type `BackupDecryptStatus`).

---

## Project Settings That Affect The Rule

Reporter project: `/Users/craighathaway/Documents/src/contacts` (git HEAD `0a20d04ed2`; the flagged files are unmodified in the working tree, so line numbers equal `git show HEAD:<path>`).

- `pubspec.yaml` (working tree) `environment`: `sdk: ">=3.13.0 <4.0.0"` (line 31), `flutter: ">=3.47.7"` (line 32). Installed Dart: `3.13.7 (stable) macos_arm64`.
- `pubspec.yaml` line 732 (working tree): `saropa_lints: ^17.0.1-beta.4` in `dev_dependencies`. At HEAD line 733: `saropa_lints: ^17.0.0`.
- `custom_lint`: not a dependency (only commented text at `pubspec.yaml` lines 713-714). `analyzer`: not declared directly, comment at lines 722-724; resolved transitively. `docs/guides/tooling/TOOLING.md` line 13: "saropa_lints is a native `analysis_server_plugin`, not custom_lint."
- `pubspec.lock` (working tree): `saropa_lints 17.0.1-beta.4` (sha256 `a59924e4e1c2d0102618a43057e3b153933c848954acb0416cc4a056003330a7`), `analyzer 14.7.0`, `_fe_analyzer_shared 111.0.0`, `analysis_server_plugin 0.3.26`.
- `saropa_lints` own constraint: `analyzer: ">=13.0.0 <15.0.0"` (`/Users/craighathaway/src/saropa_lints/pubspec.yaml` line 99), sdk `>=3.11.0 <4.0.0`.
- `analysis_options_custom.yaml` lines 131 and 133: `saropa_tier: recommended`, `runtime_tier: recommended`. `lint_baseline.yaml` lists `// ignore:` directives only (header lines 1-8); it has no entry for any file named in this report. No `// ignore` is used or proposed.
- `analysis_options.yaml`: the `plugins: saropa_lints:` block is commented out (lines 1170-1173 and following); the per-rule lines below are inside that commented block, so they are the generated defaults, not live config.
- `require_catch_logging`: `analysis_options.yaml` line 740 (`require_catch_logging: true  # [WARNING] ... {v2}`, commented block) and line 1392; `analysis_options_custom.yaml` has no override line (tier default applies)
- `lint_baseline.yaml` section `saropa_lints/require_catch_logging:` (line 4016, count 11) lists other files (isolate-based `compute` helpers with rationales such as "compute isolate; null signals parse failure to UI isolate"); `backup_crypto_codec.dart` is not in it.

---

## Reproducer

Mirrors the real method: same `static` method, same `if` early returns, same `try` body, same `on Object Ellipsis` catch with the same comment and `return const BackupDecryptResult(...)`. Third-party calls are replaced by stand-ins that keep the types (`Uint8List` returned by `decrypt`). Nothing was removed from the catch clause. Not compiled or run by me (no analyze allowed).

```dart
import 'dart:convert';
import 'dart:io' as io;
import 'dart:typed_data';

enum BackupDecryptStatus { ok, truncated, unsupportedVersion, authenticationFailed }

class BackupDecryptResult {
  const BackupDecryptResult(this.status, [this.text]);

  final BackupDecryptStatus status;
  final String? text;
}

// Stand-ins for package:encrypter_plus (same member signatures).
class IV {
  IV(Uint8List bytes);
}

class Encrypted {
  Encrypted(Uint8List bytes);
}

class AES {
  Uint8List decrypt(Encrypted encrypted, {IV? iv, Uint8List? associatedData}) =>
      throw StateError('GCM tag mismatch');
}

class BackupCryptoCodec {
  static const int minimumFileLength = 16;
  static const int currentVersion = 1;
  static const int headerLength = 25;
  static const int nonceLength = 12;

  static AES _aes(Uint8List keyBytes) => AES();

  /// Synchronous form of [decryptToText].
  static BackupDecryptResult decryptToTextSync({
    required Uint8List fileBytes,
    required Uint8List keyBytes,
  }) {
    if (fileBytes.length < minimumFileLength) {
      return const BackupDecryptResult(BackupDecryptStatus.truncated);
    }
    if (fileBytes[8] != currentVersion) {
      return const BackupDecryptResult(BackupDecryptStatus.unsupportedVersion);
    }
    try {
      final Uint8List header = Uint8List.sublistView(fileBytes, 0, headerLength);
      final IV iv = IV(
        Uint8List.sublistView(fileBytes, headerLength, headerLength + nonceLength),
      );
      final Encrypted sealed = Encrypted(
        Uint8List.sublistView(fileBytes, headerLength + nonceLength),
      );
      final Uint8List gzipped = _aes(keyBytes).decrypt(
        sealed,
        iv: iv,
        associatedData: header,
      );
      return BackupDecryptResult(
        BackupDecryptStatus.ok,
        utf8.decode(io.gzip.decode(gzipped)),
      );
    } on Object {
      // pointycastle throws InvalidCipherTextException when the GCM tag
      // does not match. The cause is never reported to the user as corruption.
      return const BackupDecryptResult(BackupDecryptStatus.authenticationFailed);
    }
  }
}

void main() {
  print(BackupCryptoCodec.decryptToTextSync(fileBytes: Uint8List(64)..[8] = 1, keyBytes: Uint8List(32)).status);
}
```

---

## AST Context

```
ClassDeclaration (BackupCryptoCodec)
  MethodDeclaration decryptToTextSync (static, returns BackupDecryptResult)
    BlockFunctionBody > Block
      TryStatement
        CatchClause  [181:7-185:6]  <- reporter.atNode(node)
          onKeyword, exceptionType: NamedType Object, exceptionParameter: null
          Block
            ReturnStatement
              InstanceCreationExpression (const BackupDecryptResult)
```

---

## Root Cause (traced in `lib/src/rules/security/security_network_input_rules.dart`)

`context.addCatchClause` handler in `RequireCatchLoggingRule.runWithReporter` (class line 4545; handler ~4624-4680):

1. `body.statements.isEmpty`: false (one `return`).
2. `bodySource = body.toSource().toLowerCase()` = `{ return const backupdecryptresult(backupdecryptstatus.authenticationfailed); }`. The comment inside the block is NOT part of `toSource()`.
3. `hasLogging`: `_loggingBodyPatterns` (built from `_loggingPatterns`, lines ~4590-4612: `log`, `logger`, `print`, `debugprint`, `developer.log`, `console`, `error`, `warning`, `severe`, `info`, `debug`, `trace`, `analytics`, `crashlytics`, `sentry`, `bugsnag`, `firebase`, `recorderror`, `record_error`, `reporterror`, `report_error`, `stderr`) are plain SUBSTRING regexes. None occurs in the lowered body text above, so `hasLogging` = false. (Substring matching is also why a body that merely contains a word like `catalog` or `information` passes; unrelated to this report.)
4. `hasRethrow`: `\brethrow\b` / `\bthrow\b` not in the body: false.
5. `exceptionParam = node.exceptionParameter` = null, so `_isExceptionUsedMeaningfully` returns false at its first line (`if (exceptionParam == null) return false;`, ~line 4689).
6. `if (exceptionUsed && catchHandlesViaControlFlow(body)) return;` - the `return` exemption is unreachable because `exceptionUsed` is false (comment at ~4650-4661 explains the "C1 fix": a returning catch that ignores the exception is the pattern the rule exists for).
7. `if (exceptionUsed) return;` no. Line ~4675: `reporter.atNode(node)` fires at the whole catch clause.

Exact firing condition: the catch has no referenced exception, no logging/rethrow keyword substring, and a non-empty body. A body that converts the failure into a typed value is indistinguishable, in the rule's text model, from `return null;`.

Verdict for beta.4 source: **reported by beta.4 source** at 181:7-185:6. Matches the export.

Not verified: nothing about this location depends on the engine version; no exemption for typed-result returns exists in beta.2, beta.3 or beta.4 (the rule file has no `NamedType`/`InstanceCreationExpression`/return-type inspection).

---

## How To Reproduce In The Reporter's Project

1. `cd /Users/craighathaway/Documents/src/contacts`. The saropa_lints dependency is live in the working tree (`pubspec.yaml` line 732) but the `plugins:` block in `analysis_options.yaml` is commented out (lines 1170+), so the IDE shows nothing until the VS Code "Lint integration" toggle is turned On (`docs/guides/tooling/TOOLING.md` lines 13-15). Run `flutter pub get` (lock must show `saropa_lints 17.0.1-beta.4`), then restart the Dart analysis server so no 17.0.0 process is left running.
2. Open the file at line 181 and read the Problems panel. Expected text: `[require_catch_logging] Catch block swallows the exception without logging or rethrowing. ... {v2}`.
3. Headless scan, scoped to the file(s) (command form from `docs/guides/tooling/TOOLING.md` line 209 and `bin/scan.dart` help lines 748-973; the default scan is a SYNTACTIC parse where `staticType` is null, so type-based rules need `--resolve`; `--tier` overrides the commented-out config):

```bash
dart run saropa_lints scan . --tier recommended --resolve --format json --files lib/database/file_backup/encryption/backup_crypto_codec.dart
```

   Expected: one diagnostic at 181:7-185:6.
4. Compare with the diagnostics listed in "Diagnostics From The Reporter's Project". If the scan reports none of the locations marked "not reported by beta.4 source" below, the export was produced by an older engine (see Version Caveat) and the exemption in the rule works; only the locations marked "reported by beta.4 source" are open bugs.

---

## Suggested Fix

In the `addCatchClause` handler, after the rethrow check and before `reporter.atNode(node)`, return when the catch body is exactly one `ReturnStatement` whose expression is an `InstanceCreationExpression` (any `const`/`new` creation of a non-collection class) and the enclosing function's declared return type is neither `void`, `bool`, nor a nullable/`Null` type. This keeps `return null;`, `return false;`, `return <literal>;`, `return [];` linted and exempts typed-result mapping. A narrower variant: also require the constructed class name to end in `Result`, `Status`, `Failure` or `Outcome`.

## Fixture Gap

The fixture `example/lib/security/require_catch_logging_fixture.dart` should include:

1. `try { f(); } on Object { }` - expect LINT.
2. `try { f(); } on Object { return null; }` (function returns `Foo?`) - expect LINT.
3. `try { f(); } on Object { return false; }` - expect LINT.
4. `try { f(); } on Object { return const BackupDecryptResult(BackupDecryptStatus.authenticationFailed); }` in a function returning `BackupDecryptResult` - expect NO lint.
5. Same with a non-`const` constructor call and a named argument - expect NO lint.
6. `try { f(); } on Object { cleanup(); return const Result(Status.failed); }` (two statements) - decide; the narrow fix would still lint it (expect LINT unless the rule is widened).

---

## Environment

- saropa_lints (rule source examined): 17.0.1-beta.4 at `/Users/craighathaway/src/saropa_lints` commit `72e3cdd5` ("Release v17.0.1-beta.4"); identical `lib/` in `~/.pub-cache/hosted/pub.dev/saropa_lints-17.0.1-beta.4`.
- saropa_lints in the reporter's `pubspec.lock`: 17.0.1-beta.4 (resolved 19:57:50, after the diagnostics export at 19:53:44).
- Dart SDK: 3.13.7 (stable) macos_arm64; analyzer 14.7.0; custom_lint: not used.
- Triggering project: `/Users/craighathaway/Documents/src/contacts`, VS Code extension `saropa.saropa-lints-17.0.13`.
