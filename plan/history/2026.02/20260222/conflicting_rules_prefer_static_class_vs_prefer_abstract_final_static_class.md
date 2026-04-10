# RESOLVED — Conflicting Rules: prefer_static_class vs prefer_abstract_final_static_class

**Fixed in**: v5.0.0-beta.16 (rule version v6)
**Resolution**: `prefer_static_class` now skips classes with a private constructor, deferring to `prefer_abstract_final_static_class` which handles that case. The rules are now complementary instead of contradictory.

---

# Conflicting Rules: prefer_static_class vs prefer_abstract_final_static_class

## Problem

Two rules detected the same code pattern — a class containing only static members with a private constructor — and produced contradictory recommendations:
- `prefer_abstract_final_static_class`: "Use `abstract final class`" (keep the class)
- `prefer_static_class`: "Replace with top-level functions" (remove the class)

## Fix Applied

In `PreferStaticClassRule`, private constructors are now tracked. When a class has a private constructor, the rule defers to `prefer_abstract_final_static_class`:

```dart
if (hasStaticMember && !hasNonStaticMember && !hasPrivateConstructor) {
  reporter.atToken(node.name, code);
}
```

The rules are now complementary:
- **No private constructor** → `prefer_static_class` fires
- **Has private constructor** → only `prefer_abstract_final_static_class` fires
