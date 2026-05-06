ref:
[{
	"resource": "/D:/src/contacts/lib/components/contact_focus/contact_focus_mode_dialog.dart",
	"owner": "_generated_diagnostic_collection_name_#2",
	"code": "avoid_empty_setstate",
	"severity": 4,
	"message": "[avoid_empty_setstate] Empty setState callback has no effect.\nAdd state changes or remove the setState call.",
	"source": "dart",
	"startLineNumber": 122,
	"startColumn": 20,
	"endLineNumber": 122,
	"endColumn": 35,
	"modelVersionId": 10,
	"origin": "extHost1"
}]

## Bug: Incorrect severity and misleading message

### Problem

The message "Empty setState callback has no effect" is factually wrong. An empty `setState(() {})` **does** trigger a rebuild by calling `markNeedsBuild()` on the element. The callback being empty does not prevent the rebuild.

This is a common and valid Flutter pattern, especially after async operations:

``` dart
_activeTargetName = await loadFocusModeTargetName(
  mode: _currentMode,
  targetId: targetId,
);

if (mounted) setState(() {});
```

Here `_activeTargetName` is mutated before the `setState` call. The empty callback is intentional — the rebuild is the desired effect.

### Severity

Currently reported as a **warning** (severity 4). This should be **INFO** at most, or promoted to a higher configurable tier. Empty `setState` is not a bug and not always a code smell — it is a deliberate pattern when state fields are modified outside the callback (e.g. after an async gap with a `mounted` check).

### Suggested fix

1. Change severity from WARNING to INFO.
2. Reword the message. Current message is misleading:
   - Current: "Empty setState callback has no effect."
   - Suggested: "setState callback is empty — state was likely modified before this call. Consider moving the assignment inside the callback for clarity, or suppress if intentional."
3. Consider not flagging when preceded by a `mounted` check, since that pattern (`if (mounted) setState(() {})`) is idiomatic after async operations.
