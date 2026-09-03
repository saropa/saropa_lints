# Migrating from json_serializable_lints

This guide helps you migrate from [`json_serializable_lints`](https://pub.dev/packages/json_serializable_lints)
(github.com/leithmail/json_serializable_lints_dart) to `saropa_lints`.

## Why Migrate?

| Feature | json_serializable_lints | saropa_lints |
|---------|--------------------------|--------------|
| **Rule count** | 3 rules, all `json_serializable`-codegen-contract focused | 2300+ custom rules |
| **Focus** | `@JsonSerializable()` `fromJson`/`toJson` presence checks | Comprehensive security, accessibility, performance, and Flutter-specific analysis |
| **Configuration** | Flat rule set | 5 progressive tiers + rule packs |

## Quick Migration

### Step 1: Update pubspec.yaml

```yaml
# Before
dev_dependencies:
  json_serializable_lints: ^0.x.x

# After
dev_dependencies:
  saropa_lints: ^2.6.0
```

### Step 2: Update analysis_options.yaml

```yaml
# Before
analyzer:
  plugins:
    - json_serializable_lints

# After
analyzer:
  plugins:
    - saropa_lints
```

Then generate the configuration:

```bash
dart run saropa_lints:init --tier recommended
```

### Step 3: Run the linter

```bash
dart analyze
```

## Rule Mapping

Coverage: 3 rules — 3 TODO (100%)

| json_serializable_lints Rule | Status | Saropa Rule / Action |
|---|---|---|
| `require_json_serializable_from_json` | TODO | TODO — see [proposal](../../../bugs/proposal_json_serializable_enforcement_rules.md) |
| `require_json_serializable_to_json` | TODO | TODO — see [proposal](../../../bugs/proposal_json_serializable_enforcement_rules.md) |
| `require_annotation_from_json` | TODO | TODO — see [proposal](../../../bugs/proposal_json_serializable_enforcement_rules.md) |

All three rules validate the same underlying contract: that `@JsonSerializable()`
classes (and `@RequireFromJson()`-annotated hierarchies) actually implement the
`fromJson`/`toJson` methods the annotation promises to generate, respecting
`createFactory: false`/`createToJson: false` opt-outs. saropa_lints has no equivalent
annotation-contract checker for `json_serializable` codegen today.

## What You Lose

If your team relies on json_serializable_lints to catch missing `fromJson`/`toJson`
implementations before codegen runs, keep it installed alongside saropa_lints until
the gap above is closed — it is a narrow, single-purpose package with no overlap
against saropa_lints' broader rule set, so running both introduces no conflicts.

## Getting Help

- [GitHub Issues](https://github.com/saropa/saropa_lints/issues)
- [Full Documentation](https://pub.dev/packages/saropa_lints)

---

Questions about migrating? Open an issue - we're happy to help.
