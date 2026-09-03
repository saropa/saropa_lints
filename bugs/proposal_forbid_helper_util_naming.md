# PROPOSAL: Forbid Generic `Helper`/`Util`/`Utils`/`Manager` Naming

**Status: Open**

Created: 2026-09-02
Type: New rule
Related rules: none

---

## Summary

Add `forbid_helper_util_naming` to flag classes, files, or top-level function libraries named with generic catch-all suffixes (`*Helper`, `*Util`, `*Utils`, `*Manager`) that convey no information about actual responsibility.

**Closes gap:** `ripplearc_linter` `forbid_helper_util_naming`. Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md` "ripplearc_linter" gaps section.

---

## Motivation

`Helper`/`Util`/`Manager` classes are a well-known anti-pattern magnet: because the name carries no responsibility signal, they accumulate unrelated static methods over time and become a dumping ground, defeating single-responsibility design. Flagging the naming pattern at creation time is cheap and forces the author to name the class for what it actually does.

---

## Detection / Behavior

### Should flag (bad code)

```dart
class StringHelper { // LINT — generic "Helper" suffix conveys no responsibility; name for what it actually does
  static String truncate(String s, int max) => s.length > max ? s.substring(0, max) : s;
}

class DataManager { // LINT — generic "Manager" suffix
  void save() {}
}
```

### Should pass (good code)

```dart
class StringTruncator { // OK — name describes the single responsibility
  static String truncate(String s, int max) => s.length > max ? s.substring(0, max) : s;
}

class UserSessionRepository { // OK — specific, describes what is managed and how
  void save() {}
}
```

---

## Proposed Tier

Tier: Comprehensive
Justification: naming-convention style rule with real false-positive risk against established Flutter/Dart ecosystem naming (`WidgetsFlutterBinding`-adjacent patterns, third-party API mirroring); placed at deep-review tier, not Essential/Recommended.

---

## Edge Cases

1. **Class name required to match an external API/interface it implements (e.g. implementing a `platform_interface` package's `XManager` contract)** — should pass; flag only new project-authored class names, or provide an allowlist/ignore mechanism for interop cases.
2. **`WidgetsBindingObserver`, `NavigatorObserver`, and other Flutter SDK-mandated names containing "Manager"-adjacent words** — should pass; only match the configured suffix list on project-authored classes, not SDK-required overrides.
3. **File named `string_utils.dart` containing well-scoped, cohesive utility functions (not a dumping ground)** — needs discussion; the rule targets the naming signal itself as a preventive convention, so it will flag even a currently-well-organized file — this is intentional (prevention, not just detection of existing sprawl).
4. **Test helper files (`test_helpers.dart`) which are an established, accepted Dart community convention** — should pass; exempt `test/` directory files, or files matching `*_test_helpers.dart`/`*_test_util.dart`, from this rule since the convention is different in test code.

---

## Alternatives Considered

- **Detect via static-method count/dumping-ground behavior instead of naming** — rejected; behavior-based detection requires the class to already be a problem before flagging, defeating the preventive value of a pure naming-convention rule. Name-based detection catches the anti-pattern at its origin.

---

## Decision

---

## Implementation Notes

Configurable banned-suffix list (default: `Helper`, `Util`, `Utils`, `Manager`) matching saropa's existing config patterns (e.g. `banned_identifier_usage`-style configurability); exempt `test/` directory.

---

## Commits
