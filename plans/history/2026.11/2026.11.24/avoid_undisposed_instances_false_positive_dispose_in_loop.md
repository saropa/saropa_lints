# avoid_undisposed_instances flags controllers disposed through a for-in loop

Status: open. Reported from d:/src/jupiter-tablet, lib/providers/jupiter/jupiter_login_form.dart (saropa_lints version per that app's pubspec.lock).

## Symptom

Five `final _x = TextEditingController();` fields are reported "created but no matching dispose() call found", although `dispose()` disposes every one of them by iterating a list literal.

## Minimal sample

```dart
class _S extends State<W> {
  final _name = TextEditingController();
  final _city = TextEditingController();

  @override
  void dispose() {
    for (final c in [_name, _city]) {
      c.removeListener(_cb);
      c.dispose();
    }
    super.dispose();
  }
}
```

## Message

`[avoid_undisposed_instances] Disposable object (e.g., TextEditingController, AnimationController, StreamController) created but no matching dispose() call found.`

## Expected

No report: every field is disposed in `dispose()` via the loop variable.

## Suspected cause

The rule matches `fieldName.dispose()` call targets only; a call on a loop variable bound to a list containing the field is not resolved back to the field.

## Fix

When `dispose()` contains a for-in over a list literal of field identifiers and calls `.dispose()` on the loop variable, count each listed field as disposed.
