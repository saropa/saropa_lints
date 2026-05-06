# `require_clipboard_paste_validation` — false positive: rule fires on a generic clipboard-paste menu helper that hands the pasted string to a `ValueChanged<String?>` callback whose downstream consumer is responsible for any validation

**Status:** Fixed (pending release) — Fix 1 from this report applied.

Resolution: When the clipboard text's containing block contains a callback dispatch — `someCallback.call(text)` on a function-typed target, or `(callback)(text)` parsed as a `FunctionExpressionInvocation` — the rule no longer reports. The helper's lack of semantic context to validate against now propagates to the rule's decision: it skips the report and lets the caller's validation boundary stand. Fix 2 (sink-based detection) remains the long-term shape and is not yet implemented.

Filed: 2026-04-26
Rule: `require_clipboard_paste_validation`
File: `lib/src/rules/security/security_auth_storage_rules.dart` (RequireClipboardPasteValidationRule, ~line 2298)
Severity: False positive (locality-of-validation analysis)
Rule version: v2 | Severity in code: WARNING | Impact: medium

---

## Summary

The rule message claims that using clipboard data without validation "creates a security vulnerability that attackers can exploit to compromise user data or application integrity". For specific consumers — SQL queries, eval contexts, deserializing JSON into typed models, executing shell commands — that framing is correct. For the overwhelmingly common case of *pasting a string into a text field* (or a tel-URL launcher, or another OS-mediated flow that has its own validation), there is no security boundary at the paste site. Any "validation" the rule expects would be cargo-cult string sanitization that does nothing the downstream consumer doesn't already do.

The rule cannot tell the difference because it inspects only the paste site, not the consumer's behavior. A reusable paste helper that *delegates* validation to a `ValueChanged<String?>` callback — by definition not knowing what the consumer will do with the string — has no place to put validation that would be correct for every caller.

---

## Attribution Evidence

```bash
$ grep -rn "'require_clipboard_paste_validation'" lib/src/rules/
# (run in saropa_lints checkout — confirm the rule lives here)
```

Diagnostic source: `dart` (saropa_lints native plugin). To be confirmed during investigation.

---

## Reproducer

Consumer project: `D:\src\contacts`. Site: `lib/components/primitive/menu/clipboard_copy_paste_menu.dart:22`.

```dart
extension ClipboardPaste on Widget {
  Widget withClipboardPaste({
    required BuildContext context,
    required ValueChanged<String?> callback,        // ← caller decides what to do with the text
    String? copyValue,
  }) {
    try {
      return CommonInkWell(
        onLongPress: () async {
          final ClipboardData? clipboardData = await Clipboard.getData('text/plain');  // LINT — but should NOT lint here
          final String? clipboardText = clipboardData?.text;

          if (clipboardText.isNullOrEmpty && copyValue.isNullOrEmpty) return;

          // … shows a small popup menu with Copy / Paste options …
          //   - Paste calls: callback.call(clipboardText)
          //   - Copy calls: ClipboardUtils.clipboardCopy(copyValue)

          await showMenu(
            context: context.mounted ? context : appGlobalContext,
            position: position,
            items: <PopupMenuEntry<dynamic>>[
              if (copyValue.isNotNullOrEmpty)
                CommonPopupMenuItem(
                  text: l10n.actionContactCopy,
                  options: const CommonPopupMenuOptions(iconCommon: ThemeCommonIcon.Copy),
                  onPressed: () => ClipboardUtils.clipboardCopy(copyValue),
                ),
              if (clipboardText.isNotNullOrEmpty)
                CommonPopupMenuItem(
                  text: l10n.actionPaste,
                  options: const CommonPopupMenuOptions(iconCommon: ThemeCommonIcon.Paste),
                  onPressed: () => callback.call(clipboardText),  // ← validation is the caller's job
                ),
            ],
          );
        },
        child: this,
      );
    } on Object catch (...) { ... }
  }
}
```

The single user of this extension (per the file's own comment) is `lib/views/phone_dialer/phone_dial_pad.dart` — a phone-number text field. The dialer's own input handling validates the pasted value (it's a phone-number field with its own keyboard / sanitization). There is no SQL, no eval, no deserialization, no shell exec. The "vulnerability" framing does not apply.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | Rule should not fire when the clipboard text is handed to a generic callback typed `ValueChanged<String?>` — the helper has no semantic context to validate against. Downstream validation is the consumer's responsibility. Alternative: rule fires only when the pasted string is used as a query argument, parsed as JSON, passed to `Uri.parse`, etc. — i.e., enters a context with a known security boundary. |
| **Actual** | `[require_clipboard_paste_validation]` fires on every `Clipboard.getData(...)` call regardless of how the result is used. |

---

## AST Context

```
MethodInvocation (Clipboard.getData)                         ← reported here
  └─ Argument: 'text/plain'

(later, inside a closure)
ExpressionStatement
  └─ MethodInvocation (callback.call)                          ← consumer is opaque
      └─ Argument: clipboardText (variable)
```

The rule has no way to inspect what `callback` does — `ValueChanged<String?>` is a type alias, not a sink with a known security profile.

---

## Root Cause

### Flaw A: detection is at the *source* of clipboard data, not at any *sink*

A useful security rule would track the clipboard string from `Clipboard.getData(...)` to its consumption site and report only when the consumption is a recognized sink (e.g., `db.query(... arg: clipboardText)`, `Uri.parse(clipboardText)`, `jsonDecode(clipboardText)`, `Process.run(... arg: clipboardText)`). Reporting at the source produces a false positive on every UI-only paste flow.

### Flaw B: rule message overstates the risk for the typical case

"Creates a security vulnerability that attackers can exploit to compromise user data or application integrity" is appropriate when the pasted data flows into a security boundary. For pasting into a text field or showing the value back to the user, no such vulnerability exists — the OS clipboard is already user-controlled, and round-tripping the string through a UI element introduces no escalation.

---

## Suggested Fix

Two layered options:

### Fix 1 — Exempt callbacks of generic types

When the clipboard value is passed to a `ValueChanged<String?>`, `void Function(String?)`, `void Function(String)`, or similar generic-string-handler callback, do not report. Detection: walk forward from the `Clipboard.getData` site, find the consumer; if the consumer is a generic callback invocation, exempt.

This closes the FP on every paste-into-text-field flow.

### Fix 2 — Sink-based detection

Replace source-site detection with sink-site detection. The set of recognized sinks would include:
- `Uri.parse` / `Uri.tryParse`
- `int.parse` / `double.parse` (where pasted text is treated as numeric)
- `jsonDecode`
- `Process.run` / `Process.start` argument lists
- Database query argument lists

Only fire when the clipboard string flows into one of these sinks without an intervening validation call (a regex match, length check, allowlist check). This is significantly more accurate and less noisy.

Fix 1 is the immediate close. Fix 2 is the right long-term shape.

---

## Fixture Gap

The fixture should include:

1. **`final s = await Clipboard.getData('text/plain'); db.query(... arg: s.text)` — expect LINT (genuine sink without validation)
2. **`final s = await Clipboard.getData('text/plain'); textController.text = s?.text ?? '';`** — expect NO lint (UI sink, OS-mediated paste)
3. **`final s = await Clipboard.getData('text/plain'); callback(s?.text);` where callback is `ValueChanged<String?>`** — expect NO lint *(currently false positive)*
4. **`final s = await Clipboard.getData('text/plain'); jsonDecode(s?.text ?? '{}');`** — expect LINT
5. **`final s = await Clipboard.getData('text/plain'); if (RegExp(r'^[\d ]+$').hasMatch(s?.text ?? '')) { ... }`** — expect NO lint (validation present)

---

## Downstream

Tracked in `contacts/`. `// ignore: require_clipboard_paste_validation` added at `lib/components/primitive/menu/clipboard_copy_paste_menu.dart:22` once this bug exists. The single consumer (phone dialer) has its own input validation; the helper itself does not own a validation boundary.

---

## Environment

- saropa_lints version: 12.5.1+
- Dart SDK: 3.9.x
- Triggering project: `d:/src/contacts`
- Platform: Windows 11
