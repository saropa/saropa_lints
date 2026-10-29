# BUG: `avoid_parameter_mutation` — flags handler functions whose only job is to fill a mutable `*Draft` accumulator passed in as the first argument

**Status: Open**

Created: 2026-10-29
Rule: `avoid_parameter_mutation`
File: `lib/src/rules/code_quality/code_quality_variables_rules.dart` (class ~501, code ~521, `_mutationByDesignTypeNames` ~745)
Severity: False positive
Rule version: v3 | Since: see rule dartdoc | Updated: see rule dartdoc

---

## Summary

The rule exempts mutation through `List`/`Map` parameters (accumulator/output pattern) and through a fixed list of framework types (`ValueNotifier`, `Sink`, `StreamController`, ...). It still flags field assignment on a parameter that is a project-owned mutable accumulator object, for example `d.importedPhotoBytes = photo;` in a `void photo(VCardContactDraft d, VCardLine l)` parser handler. The draft class exists only to be filled line by line by such handlers; the "caller's data" is the accumulator the caller created for this purpose.

---

## Attribution Evidence

```bash
# Positive — rule IS defined here
grep -rn "'avoid_parameter_mutation'" lib/src/rules/
# lib/src/rules/code_quality/code_quality_variables_rules.dart:521:    'avoid_parameter_mutation',

# Negative — sibling repo (../saropa_drift_advisor) is not checked out on this machine, so the
# negative grep cannot be run. The diagnostic text below is byte-identical to the LintCode
# message in this repo, plus the `{vN}` suffix, which is the attribution evidence.
```

**Emitter registration:** `lib/src/rules/code_quality/code_quality_variables_rules.dart:521`; registered at `lib/saropa_lints.dart:664` (`AvoidParameterMutationRule.new`)
**Rule class:** `AvoidParameterMutationRule` (`code_quality_variables_rules.dart:501`)
**Diagnostic `source` / `owner` as seen in Problems panel:** `source: saropa_lints`, `owner: saropaLintsLsp`

---

## Reproducer

Compiles standalone (plain Dart). Mirrors
`/Users/craighathaway/Documents/src/contacts/lib/database/file_backup/import/vcard_import_identity_handlers.dart:16-90` (`VCardImportIdentityHandlers`) and the draft class `VCardContactDraft` in `vcard_import_draft.dart`.

```dart
import 'dart:typed_data';

/// Mutable accumulator filled by one handler call per vCard line.
class VCardContactDraft {
  Uint8List? importedPhotoBytes;
  String? saropaUuidFromPayload;
  String? saropaUuidFromUid;
  bool isBusinessImported = false;
}

class VCardLine {
  const VCardLine(this.op, this.value);
  final String op;
  final String value;
}

abstract final class VCardImportIdentityHandlers {
  static void photo(VCardContactDraft d, VCardLine l) {
    d.importedPhotoBytes = Uint8List(0); // LINT — but should NOT lint (false positive)
  }

  static void saropaProfile(VCardContactDraft d, VCardLine l) {
    d.saropaUuidFromPayload = l.value; // LINT — same
  }

  static void uid(VCardContactDraft d, VCardLine l) {
    d.saropaUuidFromUid ??= l.value; // LINT — same
  }

  static void kind(VCardContactDraft d, VCardLine l) {
    d.isBusinessImported = true; // LINT — same
  }
}

void main() {
  final VCardContactDraft draft = VCardContactDraft();
  VCardImportIdentityHandlers.kind(draft, const VCardLine('KIND', 'org'));
}
```

**Frequency:** Always, for each field assignment on the first parameter of every handler.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic: the object is a purpose-built output accumulator, the same intent as `results.add(x)` on a `List` parameter, which the rule already exempts. |
| **Actual** | `[avoid_parameter_mutation] Parameter object is being mutated. This modifies the caller's data. {v3}` at `vcard_import_identity_handlers.dart` 24:7-24:35, 47:7-47:37, 64:5-64:71, 73:7-73:39, 87:7-87:34 |

---

## AST Context

```
ClassDeclaration (VCardImportIdentityHandlers)   // abstract final class
  └─ MethodDeclaration (static void photo)
      └─ FormalParameterList: (VCardContactDraft d, VCardLine l)
      └─ BlockFunctionBody → Block
          └─ IfStatement (decodedPhoto != null)
              └─ Block
                  └─ ExpressionStatement
                      └─ AssignmentExpression (d.importedPhotoBytes = decodedPhoto)  ← reporter.atNode(node)
                          └─ leftHandSide: PrefixedIdentifier (d . importedPhotoBytes)
```

---

## Root Cause

`code_quality_variables_rules.dart`:

1. `_checkFunction` (~560-590) maps each parameter name to its declared type name and visits the body with `_ParameterMutationVisitor`.
2. `visitAssignmentExpression` (~655-690): for `left is PrefixedIdentifier` it calls `_isMutableParameter(prefix.name, prefix.staticType)` and reports.
3. `_isMutableParameter` (~717) returns `false` only when the declared type name is in the fixed `_mutationByDesignTypeNames` set (`ValueNotifier`, `ChangeNotifier`, `Listenable`, `ValueListenable`, `Sink`, `EventSink`, `StreamSink`, `StreamController`) or `_isMutationByDesignType(staticType)` holds. A project-owned class named `*Draft` / `*Builder` / `*Accumulator` is never recognized.
4. The method return type (`void`) and the single-purpose naming are not considered.

---

## Why the code is correct

`VCardContactDraft` is created once per contact by the importer and handed to one handler per vCard line (a dispatch table maps `PHOTO`, `UID`, `KIND`, ... to these static handlers). Each handler sets the field(s) its property owns. The caller reads the finished draft afterwards. A copy-on-write version would allocate a new draft per line and return it through a dispatcher, replacing a simple table of `void Function(Draft, Line)` with a fold. The "caller's data" the rule protects is not at risk because the caller passed the object in to be filled.

---

## Affected Locations (contacts app)

Line numbers as reported by the diagnostics:

| File | Line:col |
|---|---|
| `/Users/craighathaway/Documents/src/contacts/lib/database/file_backup/import/vcard_import_identity_handlers.dart` | 24:7, 47:7, 64:5, 73:7, 87:7 |
| `/Users/craighathaway/Documents/src/contacts/lib/database/file_backup/import/vcard_import_vendor_handlers.dart` | 21:5, 26:5, 30:5, 150:51 (same draft-accumulator handlers: `d.givenNamePhonetic ??= ...`, `d.isBusinessImported = true`) |
| `/Users/craighathaway/Documents/src/contacts/lib/database/file_backup/import/vcard_import_core_handlers.dart` | 27:5, 31:5 (`fn` handler `d.fn = ...`, `n` handler `d.name = ...`; same draft-accumulator handlers) |
| `/Users/craighathaway/Documents/src/contacts/lib/database/drift_middleware/user_data/shared_details_processed_merge.dart` | 66:5 (`_stamp(SaropaBaseModel item)` cascade that stamps the sharer tag on a row the caller passes in to be stamped) |

---

## Suggested Fix

In `_isMutableParameter`, also return `false` when the enclosing function returns `void` AND the parameter's declared type name ends in `Draft`, `Builder`, `Accumulator`, `Collector` or `Buffer` (same declared-name approach as `_mutationByDesignTypeNames`, so it works under the syntax-only scan). Optionally also exempt the first parameter of a `void` static method whose class name ends in `Handlers`.

---

## Fixture Gap

1. `void fill(Person p) { p.name = 'x'; }` — expect LINT (unchanged)
2. `void photo(ContactDraft d, Line l) { d.photo = bytes; }` — expect NO lint (new)
3. `ContactDraft photo(ContactDraft d) { d.photo = bytes; return d; }` — expect LINT (non-void; unchanged)
4. `void fill(List<int> out) { out[0] = 1; }` — expect NO lint (unchanged)
5. `void fill(StringBuilderDraft d) { d..value = 1; }` (cascade) — expect NO lint (new)

---

## Environment

- saropa_lints version: 17.0.1-beta.2
- Dart SDK version: 3.13.7 (stable) (Thu Oct 22 14:28:57 2026 -0700) on "macos_arm64"
- custom_lint version: not used (diagnostic delivered by the `saropaLintsLsp` owner in VS Code, `source: saropa_lints`)
- Triggering project/file: `/Users/craighathaway/Documents/src/contacts` (Flutter app `saropa`); files listed under Affected Locations
