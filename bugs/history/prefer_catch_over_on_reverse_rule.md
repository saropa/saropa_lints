# Bug: `prefer_catch_over_on` — Rule is backwards

## Summary

The rule `prefer_catch_over_on` currently flags **all** typed `on` clauses and recommends bare `catch`. This is wrong. The rule should be **reversed**: only flag `on Object catch` (which is pointless), and leave specific `on` clauses like `on FormatException catch` alone.

## Current (incorrect) behavior

The rule fires on any `on Type catch (e, stackTrace)` clause, including specific types:

```dart
// FLAGGED — but this is CORRECT code
} on FormatException catch (e, stackTrace) {
  debugPrint('decode failed: $e\n$stackTrace');
  return null;
}
```

Current message: *"Typed 'on' clauses add complexity and risk missing unexpected exception types. A bare catch ensures no failure goes unhandled."*

This advice is dangerously wrong for specific exception types. Catching `FormatException` specifically is intentional — the developer knows exactly which failure mode they're handling.

## What the rule SHOULD do

Only flag `on Object catch` — because `on Object catch (e, stackTrace)` is **functionally identical** to `catch (e, stackTrace)`:

- Both catch everything
- Both give `e` a static type of `Object`
- The `on Object` adds visual noise for zero benefit
- It looks like a type filter but filters nothing

```dart
// BAD — on Object is equivalent to bare catch, just noisier
} on Object catch (e, stackTrace) {

// GOOD — bare catch, same behavior, clearer intent
} catch (e, stackTrace) {

// GOOD — specific type, intentional filtering, keep as-is
} on FormatException catch (e, stackTrace) {
```

## Reversed rule description

**Name:** `prefer_catch_over_on` (keep the name)

**New message:**

> `on Object catch` is equivalent to a bare `catch` — both catch everything with the same static type for the exception variable. Remove the redundant `on Object` clause. Note: specific `on` clauses like `on FormatException catch` are correct and should not be changed.

## Quick fix

**Trigger:** `on Object catch (`

**Replacement:** `catch (`

Only match `on Object catch`, not `on FormatException catch` or any other specific type.

## Flutter precedent

The Flutter framework source code uses:
- `catch (e, stackTrace)` for catch-all handlers
- `on SpecificException catch (e)` for targeted handling

This is standard Dart/Flutter idiom. The current rule contradicts it.
