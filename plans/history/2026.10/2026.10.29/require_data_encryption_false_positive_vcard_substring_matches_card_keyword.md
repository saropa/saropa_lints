# BUG: `require_data_encryption` — keyword `card` matches inside the identifier `makeVCardFileName()` (vCard file export)

**Status: Fixed**

Created: 2026-10-29
Rule: `require_data_encryption`
File: `lib/src/rules/security/security_auth_storage_rules.dart` (class ~1338, code ~1370, `_sensitiveKeywords` ~1378, loop ~1585)
Severity: False positive
Rule version: v7 | Since: see rule dartdoc | Updated: see rule dartdoc

---

## Summary

The rule scans the lowercased source text of the argument list of any call named `write`/`put`/`insert`/`setString`/`writeAsString`/`writeAsBytes` for sensitive keywords using a plain `String.contains`. The keyword `card` (credit card) matches inside `makevcardfilename`, so a vCard (`.vcf`) contacts export is reported as writing unencrypted credit-card data.

---

## Attribution Evidence

```bash
# Positive — rule IS defined here
grep -rn "'require_data_encryption'" lib/src/rules/
# lib/src/rules/security/security_auth_storage_rules.dart:1370:    'require_data_encryption',

# Negative — sibling repo (../saropa_drift_advisor) is not checked out on this machine, so the
# negative grep cannot be run. The diagnostic text below is byte-identical to the LintCode
# message in this repo, plus the `{vN}` suffix, which is the attribution evidence.
```

**Emitter registration:** `lib/src/rules/security/security_auth_storage_rules.dart:1370`; registered at `lib/saropa_lints.dart:1386` (`RequireDataEncryptionRule.new`)
**Rule class:** `RequireDataEncryptionRule` (`security_auth_storage_rules.dart:1338`)
**Diagnostic `source` / `owner` as seen in Problems panel:** `source: saropa_lints`, `owner: saropaLintsLsp`

---

## Reproducer

Compiles standalone (plain Dart). Shape copied from
`/Users/craighathaway/Documents/src/contacts/lib/database/file_backup/backup_vcard_export_utils.dart:49-53` and `:93-97`.

```dart
import 'dart:io' as io;

class BackupVCardStreamWriter {
  static Future<(io.File, int)?> write({
    required io.Directory folder,
    required String fileName,
    required List<String> contacts,
  }) async => null;
}

String makeVCardFileName({String suffix = ''}) => 'contacts$suffix.vcf';

Future<void> export(io.Directory folder, List<String> contacts) async {
  final (io.File, int)? written = await BackupVCardStreamWriter.write( // LINT — but should NOT lint (false positive)
    folder: folder,
    fileName: makeVCardFileName(),
    contacts: contacts,
  );
  print(written);
}

void main() {}
```

**Frequency:** Always, for any `write`/`put`/`insert` call whose arguments contain an identifier with `card` as a substring (`vCard`, `cardinality`, `discard`, `scorecard`, `postcard`).

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic. The arguments are a folder, a file name and a list of contacts. No credential, payment card or secret is written. |
| **Actual** | `[require_data_encryption] Unencrypted sensitive data exposes credentials to attackers via device access or backup extraction. {v7}` at `backup_vcard_export_utils.dart` 49:45 through the end of the call (multi-line, ends col 8), and again at 93:45 |

---

## AST Context

```
ClassDeclaration (BackupVCardExportUtils)
  └─ MethodDeclaration (static Future<io.File?> exportContactsToVCard)
      └─ BlockFunctionBody → Block → TryStatement → Block
          └─ VariableDeclarationStatement
              └─ VariableDeclaration (written)
                  └─ AwaitExpression
                      └─ MethodInvocation (BackupVCardStreamWriter.write)  ← reporter.atNode(node)
                          └─ ArgumentList (folder: folder, fileName: makeVCardFileName(), contacts: contacts)
```

---

## Root Cause

`security_auth_storage_rules.dart` `runWithReporter` (~1511-1600):

1. `methodName == 'write'` passes the method filter (~1517).
2. The target `BackupVCardStreamWriter` has no `secure`/`encrypt`/`encryptedbox` word (~1525).
3. `argsSource = node.argumentList.toSource().toLowerCase()` = `(folder: folder, filename: makevcardfilename(), contacts: contacts)` (~1532).
4. None of the encryption signals or search-index patterns match, so the fall-through loop runs (~1585):

```dart
for (final String keyword in _sensitiveKeywords) {
  if (scannedArgsSource.contains(keyword)) {     // 'card'.contains in 'makevcardfilename' -> true
    reporter.atNode(node);
    return;
  }
}
```

`_sensitiveKeywords` (~1378) contains `'card'` and `'bank'`, `'credit'`, `'secret'`. These are matched as raw substrings on the lowercased text. The rule already uses word-boundary or look-behind patterns for `pin`, `token` and `auth` (`_pinKeywordPattern`, `_tokenKeywordPattern`, `_authKeywordPattern`) because of this exact class of problem; the plain-substring keywords were not given the same treatment.

---

## Why the code is correct

The call streams the user's own contacts into a `.vcf` export file in a folder the user chose. The file name is built by `makeVCardFileName()`. `vCard` is the contact-file format name, not a payment card. The export is the user's own data going to a place they selected; app-level encryption of the export would make the file unusable by other contact apps, which is the purpose of vCard.

---

## Affected Locations (contacts app)

Line numbers as reported by the diagnostics:

| File | Line:col |
|---|---|
| `/Users/craighathaway/Documents/src/contacts/lib/database/file_backup/backup_vcard_export_utils.dart` | 49:45 (in `exportContactsToVCard`), 93:45 (in `exportContactsSubsetToVCard`) |

---

## Suggested Fix

Stop matching `card` as a bare substring. Match it with the same style as `_pinKeywordPattern`: `RegExp(r'(?<![a-z])(credit|debit|payment|bank)?card(?![a-z])')`, or require an adjacent qualifier (`creditcard`, `cardnumber`, `card_number`, `cardholder`, `cvv`). Also add `vcard` to the context-exclusion list next to `_argumentSearchIndexContextPatterns` (strip `\bv?card(?:s|file\w*)?\b` occurrences of `vcard` before the keyword loop). Review the other plain-substring keywords (`bank`, `ssn`, `secret`, `credit`) for the same embedded-word problem (`ssn` in `classname`, `bank` in `bankruptcy` are not issues here but share the mechanism).

---

## Fixture Gap

1. `file.writeAsString(cardNumber)` — expect LINT (unchanged)
2. `prefs.setString('credit_card', v)` — expect LINT (unchanged)
3. `writer.write(folder: f, fileName: makeVCardFileName(), contacts: c)` — expect NO lint (new)
4. `prefs.setString('discardedItems', v)` — expect NO lint (new)
5. `prefs.setString('scorecard', v)` — expect NO lint (new)

---

## Environment

- saropa_lints version: 17.0.1-beta.2
- Dart SDK version: 3.13.7 (stable) (Thu Oct 22 14:28:57 2026 -0700) on "macos_arm64"
- custom_lint version: not used (diagnostic delivered by the `saropaLintsLsp` owner in VS Code, `source: saropa_lints`)
- Triggering project/file: `/Users/craighathaway/Documents/src/contacts` (Flutter app `saropa`); files listed under Affected Locations
