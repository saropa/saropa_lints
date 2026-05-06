# Bug: prefer_const_constructor_declarations suggests const when initializers are not const-capable

**Rule:** `prefer_const_constructor_declarations`  
**Status:** Open  
**Reporter:** radiance_vector_game

---

## Summary

The rule reports "Constructor could be const. Class has only final fields; add const to the constructor declaration" on constructors whose **initializer list** uses non-constant expressions (e.g. method calls, non-const constructor calls, `super` with a non-const argument). Adding `const` to such constructors causes a compile error. The rule appears to check only that the class has only final fields, without verifying that the initializer expressions are constant.

## Expected behavior

Do not report when any initializer in the constructor is not a constant expression, including:
- Invocation of a non-const method (e.g. `_encode(table)`, `getDefaultExecutor()`).
- Invocation of a non-const constructor (e.g. `_TableStorage(tables.cardTypes)`).
- `super(...)` with any non-const argument (e.g. `super(executor ?? getDefaultExecutor())`).

## Actual behavior

### 1. string_overrides_data.dart – _TableStorage (lines 75–77)

```dart
class _TableStorage extends Equatable {
  _TableStorage(StringOverrideTable table)
      : _encoded = _encode(table),
        _hashCode = _encode(table).hashCode;
  // ...
}
```

`_encode(table)` is a static method call; not const. Adding `const` yields: "Const constructor can't have a non-const initializer for '_encoded'."

### 2. string_overrides_data.dart – MergedStringOverrides (lines 155–158)

```dart
class MergedStringOverrides extends Equatable {
  MergedStringOverrides({required _MergedStringOverridesInput tables})
      : _cardTypes = _TableStorage(tables.cardTypes),
        _cardRarities = _TableStorage(tables.cardRarities),
        // ...
}
```

`_TableStorage(...)` is not a const constructor. Adding `const` would require all those to be const, which they are not.

### 3. app_database.dart – AppDatabase (lines 35–36)

```dart
final class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
      : super(executor ?? getDefaultExecutor());
  // ...
}
```

`super(executor ?? getDefaultExecutor())` is not const. Adding `const` yields a compile error.

## Suggested fix

When determining whether a constructor "could be const", in addition to "class has only final fields", require that every initializer list entry (including super arguments) is a constant expression. Do not report when any initializer is:
- A call to a non-const method or constructor,
- A non-const `super(...)` argument,
- Or any other non-const expression.

## Environment

- saropa_lints: 6.2.2
- Dart SDK: ^3.11.0
