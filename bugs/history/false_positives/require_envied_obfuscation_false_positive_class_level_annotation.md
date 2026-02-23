# Bug Report: `require_envied_obfuscation` — False Positive on Class-Level `@Envied` When All Fields Already Obfuscated

## Diagnostic Reference

```json
[{
  "resource": "/D:/src/contacts/lib/env/env.dart",
  "owner": "_generated_diagnostic_collection_name_#2",
  "code": "require_envied_obfuscation",
  "severity": 4,
  "message": "[require_envied_obfuscation] Envied environment variable generated without obfuscation stores secrets as plaintext string constants in the compiled binary. Attackers can extract API keys, database URLs, and authentication tokens using basic reverse engineering tools, enabling unauthorized access to your backend services and third-party APIs. {v2}\nAdd obfuscate: true to the @Envied annotation or individual @EnviedField annotations to encode secrets at compile time and prevent plaintext extraction.",
  "source": "dart",
  "startLineNumber": 10,
  "startColumn": 1,
  "endLineNumber": 10,
  "endColumn": 22,
  "modelVersionId": 1,
  "origin": "extHost1"
}]
```

---

## Summary

The `require_envied_obfuscation` rule flags the class-level `@Envied(path: '.env')` annotation because it lacks `obfuscate: true`. However, every `@EnviedField` in the class already specifies `obfuscate: true` individually (or is explicitly suppressed with `// ignore:require_envied_obfuscation` for non-secret fields). The rule treats `@Envied` and `@EnviedField` identically — checking each annotation in isolation — without recognizing that obfuscation is already fully handled at the field level, making the class-level warning redundant and misleading.

---

## The False Positive Scenario

### Triggering Code

`lib/env/env.dart` — a class where every secret field already has `obfuscate: true`:

```dart
@Envied(path: '.env')                    // <-- FLAGGED (line 10)
abstract class EncryptedEnv {
  @EnviedField(varName: 'assetImportPassword', obfuscate: true)
  static final String assetImportPassword = _EncryptedEnv.assetImportPassword;

  @EnviedField(varName: 'facebookAppID', obfuscate: true)
  static final String facebookAppID = _EncryptedEnv.facebookAppID;

  @EnviedField(varName: 'youTubeDataAPIv3Key', obfuscate: true)
  static final String youTubeDataAPIv3Key = _EncryptedEnv.youTubeDataAPIv3Key;

  // ... 20+ more fields, ALL with obfuscate: true ...

  // not a secret
  // ignore:require_envied_obfuscation
  @EnviedField(varName: 'envVersion', obfuscate: false)
  static const int envVersion = _EncryptedEnv.envVersion;

  // not a secret ... is it?
  // ignore:require_envied_obfuscation
  @EnviedField(varName: 'googleCloudProjectNumber', obfuscate: false)
  static const int googleCloudProjectNumber = _EncryptedEnv.googleCloudProjectNumber;
}
```

The class has 24 `@EnviedField` annotations:
- **22 fields** have `obfuscate: true` — all secrets are already protected
- **2 fields** have `obfuscate: false` with an explicit `// ignore:require_envied_obfuscation` — these are non-secret integer values (`envVersion`, `googleCloudProjectNumber`)

Every field is individually accounted for. The class-level `@Envied` annotation does not control obfuscation for any unhandled field — yet the rule fires on it anyway.

---

## Root Cause Analysis

The rule implementation in `package_specific_rules.dart` (lines 1169-1221, class `RequireEnviedObfuscationRule`) registers a single callback for **all annotations**:

```dart
context.registry.addAnnotation((Annotation node) {
  final String name = node.name.name;
  if (name != 'Envied' && name != 'EnviedField') return;

  final ArgumentList? args = node.arguments;
  if (args == null) {
    reporter.atNode(node, code);
    return;
  }

  final bool hasObfuscate = args.arguments.any((Expression arg) {
    if (arg is NamedExpression) {
      if (arg.name.label.name == 'obfuscate') {
        return arg.expression.toSource() == 'true';
      }
    }
    return false;
  });

  if (!hasObfuscate) {
    reporter.atNode(node, code);
  }
});
```

### The problem

The rule treats `@Envied` and `@EnviedField` **identically**. It checks each annotation in complete isolation:

1. Sees `@Envied(path: '.env')` — no `obfuscate: true` found → **fires warning**
2. Sees `@EnviedField(varName: 'assetImportPassword', obfuscate: true)` — found → no warning
3. ... and so on for each field

There is **no cross-annotation logic**. The rule does not:
- Distinguish class-level `@Envied` from field-level `@EnviedField`
- Check whether sibling `@EnviedField` annotations in the same class already specify `obfuscate: true`
- Recognize that field-level obfuscation makes class-level obfuscation redundant

### How the envied package actually works

In the `envied` package, `@Envied(obfuscate: true)` sets a **default** that individual `@EnviedField` annotations can override. The relationship is:

| Class-Level | Field-Level | Effective Obfuscation |
|---|---|---|
| `obfuscate: true` | (not specified) | **true** (inherited) |
| `obfuscate: true` | `obfuscate: false` | **false** (field overrides) |
| (not specified) | `obfuscate: true` | **true** (field explicit) |
| (not specified) | (not specified) | **false** (default) |

The class-level `obfuscate` is a convenience default — it is **not required** when every field already specifies its own `obfuscate` value. The lint rule does not account for this inheritance model.

---

## Why This Is a False Positive

1. **Security goal is already met**: Every secret field explicitly sets `obfuscate: true`. The compiled binary will contain XOR-encoded values, not plaintext. Adding `obfuscate: true` to `@Envied` changes nothing about the generated code.

2. **Adding class-level `obfuscate: true` would be misleading**: The class contains two intentionally-unobfuscated fields (`envVersion`, `googleCloudProjectNumber`). Setting `@Envied(obfuscate: true)` would imply all fields are obfuscated by default, but two fields explicitly override that — creating a confusing mismatch between the class-level declaration and the actual per-field behavior.

3. **No "fix" satisfies the rule without redundancy**: The rule requires `obfuscate: true` on every `@Envied` and every `@EnviedField` annotation. But the envied package's inheritance model means specifying both is always redundant for fields that already declare `obfuscate: true`.

---

## Suggested Fixes

### Option A: Skip `@Envied` When All Fields Are Explicitly Handled (Recommended)

When the rule encounters a class-level `@Envied` annotation, check whether every `@EnviedField` in the same class already specifies `obfuscate: true` (or is suppressed via `// ignore`). If all fields are accounted for, do not fire on the class-level annotation.

```dart
// Pseudocode for the enhanced logic
context.registry.addAnnotation((Annotation node) {
  final String name = node.name.name;
  if (name != 'Envied' && name != 'EnviedField') return;

  // For class-level @Envied, check if all fields handle obfuscation themselves
  if (name == 'Envied') {
    final ClassDeclaration? classDecl = node.parent?.parent as ClassDeclaration?;
    if (classDecl != null && _allFieldsHandleObfuscation(classDecl)) {
      return; // All fields are individually accounted for — no warning needed
    }
  }

  // Existing per-annotation check
  if (!_hasObfuscateTrue(node)) {
    reporter.atNode(node, code);
  }
});
```

### Option B: Only Check `@EnviedField`, Ignore `@Envied`

Since `@Envied(obfuscate: true)` is just a convenience default and does not add security beyond what field-level annotations provide, the rule could simply skip class-level `@Envied` annotations entirely and only enforce obfuscation on `@EnviedField`.

```dart
if (name != 'EnviedField') return; // Only check field-level annotations
```

This is simpler but loses the ability to catch classes where `@Envied(obfuscate: true)` is set but individual fields are missing the annotation entirely (relying on inheritance).

### Option C: Check `@Envied` Only When Fields Lack Explicit Obfuscation

A middle ground — fire on `@Envied` only if at least one `@EnviedField` in the class does **not** specify `obfuscate: true`:

```dart
if (name == 'Envied') {
  final ClassDeclaration? classDecl = node.parent?.parent as ClassDeclaration?;
  if (classDecl != null) {
    final bool anyFieldMissingObfuscate = _hasFieldWithoutObfuscate(classDecl);
    if (!anyFieldMissingObfuscate) return; // All fields explicit — skip class-level check
  }
}
```

This preserves the rule's value for classes that rely on inheritance while eliminating the false positive for classes that are explicit at the field level.

---

## Missing Test Coverage

The current fixture (`require_envied_obfuscation_fixture.dart`) only tests:

- **BAD**: `@Envied()` with `@EnviedField()` — neither specifies obfuscation
- **GOOD**: `@Envied(obfuscate: true)` with `@EnviedField(obfuscate: true)` — both specified

There are **no tests** for the scenario where:
- `@Envied` lacks `obfuscate: true` but every `@EnviedField` already specifies `obfuscate: true`
- `@Envied` lacks `obfuscate: true` and some fields use `obfuscate: false` with `// ignore`

Suggested additions:

```dart
// GOOD: Should NOT trigger require_envied_obfuscation on class-level annotation
// because all fields individually specify obfuscate: true
@Envied(path: '.env')
abstract class _goodAllFieldsExplicitlyObfuscated {
  @EnviedField(varName: 'apiKey', obfuscate: true)
  static final String apiKey = __goodAllFieldsExplicitlyObfuscated.apiKey;

  @EnviedField(varName: 'dbUrl', obfuscate: true)
  static final String dbUrl = __goodAllFieldsExplicitlyObfuscated.dbUrl;
}

// GOOD: Mixed obfuscation — all fields explicit, non-secrets suppressed
@Envied(path: '.env')
abstract class _goodMixedFieldObfuscation {
  @EnviedField(varName: 'secretKey', obfuscate: true)
  static final String secretKey = __goodMixedFieldObfuscation.secretKey;

  // not a secret
  // ignore:require_envied_obfuscation
  @EnviedField(varName: 'appVersion', obfuscate: false)
  static const int appVersion = __goodMixedFieldObfuscation.appVersion;
}

// BAD: Should trigger — no obfuscation anywhere
// expect_lint: require_envied_obfuscation
@Envied()
abstract class _badNoObfuscationAnywhere {
  // expect_lint: require_envied_obfuscation
  @EnviedField()
  static const String apiKey = __badNoObfuscationAnywhere.apiKey;
}

// BAD: Should trigger on @Envied — some fields rely on inheritance
// expect_lint: require_envied_obfuscation
@Envied()
abstract class _badSomeFieldsMissing {
  @EnviedField(obfuscate: true)
  static final String secretKey = __badSomeFieldsMissing.secretKey;

  // This field has no obfuscate specified — would inherit from @Envied if set
  // expect_lint: require_envied_obfuscation
  @EnviedField()
  static const String unprotectedKey = __badSomeFieldsMissing.unprotectedKey;
}
```

---

## Patterns That Should Be Recognized as Safe

| Annotation | Fields Status | Currently Flagged | Should Be Flagged |
|---|---|---|---|
| `@Envied(path: '.env')` | All fields have `obfuscate: true` | **Yes** | **No** — redundant |
| `@Envied(path: '.env')` | All fields explicit (`true` or suppressed `false`) | **Yes** | **No** — fully accounted for |
| `@Envied()` | Some fields lack `obfuscate` entirely | Yes | **Yes** — fields rely on inheritance |
| `@Envied()` | No fields specify `obfuscate` | Yes | **Yes** — nothing is obfuscated |
| `@Envied(obfuscate: true)` | All fields have `obfuscate: true` | No | No — redundant but harmless |

---

## Current Workaround

Add an ignore comment above the `@Envied` annotation:

```dart
// all fields already specify obfuscate individually
// ignore:require_envied_obfuscation
@Envied(path: '.env')
abstract class EncryptedEnv {
```

This is undesirable because:
- It suppresses a security rule, which may mask future issues if new fields are added without `obfuscate: true`
- It adds noise to a file that is already correctly handling obfuscation
- It signals to code reviewers that something might be wrong when nothing is

---

## Affected Files

| File | Line(s) | What |
|---|---|---|
| `lib/src/rules/packages/package_specific_rules.dart` | 1169-1221 | `RequireEnviedObfuscationRule` — no cross-annotation logic between `@Envied` and `@EnviedField` |
| `example_packages/lib/packages/require_envied_obfuscation_fixture.dart` | — | Test fixture — no coverage for "all fields explicit" scenario |

## Priority

**Medium** — The rule fires a security warning on a class that already has full per-field obfuscation coverage. The false positive is confusing because the lint message warns about "plaintext string constants in the compiled binary" when the binary actually contains XOR-encoded values. The fix requires adding class-level context awareness to the annotation visitor, which is a moderate implementation change. The workaround (`// ignore`) is functional but undesirable for a security-sensitive rule.
