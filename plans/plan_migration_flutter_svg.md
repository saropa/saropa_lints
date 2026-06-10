# Plan: `flutter_svg_2` migration pack

**Status:** ready to implement. **Value: HIGH** — `color` / `colorBlendMode` are
**deprecated and still compile** on 2.x (later fully removed), so the lint is the
only nudge while they linger. **Gate type:** post-upgrade cleanup.
**Gate:** `flutter_svg >= 2.0.0`. **Driving app:** Saropa Contacts ships
`flutter_svg: ^2.3.0` (8 `SvgPicture` sites; none use deprecated `color:` —
already clean, pack serves the general user base).

## 1. The migration (verified)

`flutter_svg` 2.0.0 deprecated the `color` and `colorBlendMode` parameters on
`SvgPicture.*` constructors in favor of a single `colorFilter`.

```dart
// Old (deprecated, still compiles on 2.x)
SvgPicture.asset('icon.svg', color: Colors.red, colorBlendMode: BlendMode.srcIn)

// New
SvgPicture.asset('icon.svg',
    colorFilter: const ColorFilter.mode(Colors.red, BlendMode.srcIn))
```

`colorBlendMode` defaulted to `BlendMode.srcIn`, so a `color:`-only call maps to
`ColorFilter.mode(<color>, BlendMode.srcIn)`.

## 2. Rule (`lib/src/rules/packages/flutter_svg_rules.dart`, new file)

Single rule `prefer_svg_color_filter`.

**Detection (type-safe):** match an `InstanceCreationExpression` / named
constructor invocation whose static type is `SvgPicture` from
`package:flutter_svg`, that passes a `color:` and/or `colorBlendMode:` named
argument. Type-check via the constructor element's library URI — do NOT match any
widget carrying a `color:` arg (`Icon`, `Text`, `Container` all have one). This is
the primary false-positive trap.

**Fix (mechanical):** remove `color:` (+ `colorBlendMode:` if present), insert
`colorFilter: ColorFilter.mode(<colorExpr>, <blendExpr or BlendMode.srcIn>)`.
Preserve `const` when both operands are const. If `color:` is a nullable/dynamic
expression the rewriter cannot prove non-null, emit report-only (a null `color`
meant "no filter", but `ColorFilter.mode(null, ...)` is invalid) — name this in
the correctionMessage.

## 3. Wiring (recipe steps 2–6)

- `kRulePackDependencyGates`: `'flutter_svg_2': RulePackDependencyGate(dependency: 'flutter_svg', constraint: '>=2.0.0')`
- generator: `'flutter_svg_2': {'flutter_svg'}` + title `'flutter_svg 2.x'`
- `kRelocatedRulePackCodes`: `'prefer_svg_color_filter': (fromPack: 'flutter_svg', toPack: 'flutter_svg_2')`
- Regenerate (twice) + `dart format`.

## 4. Tests

- `test/config/rule_packs_flutter_svg_test.dart`: gate passes 2.0.0 / 2.3.0, fails
  1.x / absent; ownership; merge override.
- `test/rules/packages/flutter_svg_rules_test.dart`: `SvgPicture.asset(color:)`
  triggers; `colorFilter:` form does not; `Icon(color:)` / `Container(color:)` do
  NOT trigger (FP guard); fix maps `color`+`colorBlendMode` → `ColorFilter.mode`,
  and `color`-only → `ColorFilter.mode(c, BlendMode.srcIn)`; nullable `color` →
  report-only.

## 5. Verify

`dart run tool/rule_pack_audit.dart` exit 0 (flutter_svg_2=1); tests pass;
`dart analyze --fatal-infos` clean. Confirm FP guard against `Icon`/`Container`
with the scan CLI on a mixed fixture.

## Sources

- [flutter_svg changelog](https://pub.dev/packages/flutter_svg/changelog)
- [Issue #828: migration guide for deprecated `color`](https://github.com/dnfield/flutter_svg/issues/828)
- [Issue #856: color in SvgPicture](https://github.com/dnfield/flutter_svg/issues/856)
