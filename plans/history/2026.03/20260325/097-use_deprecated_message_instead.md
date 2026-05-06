# Plan #097

**Source:** Dart SDK 3.0.0
**Category:** Deprecation
**Relevance Score:** 9
**Detected APIs:** Deprecated.message, Use

---

## Release Note Entry

> Use [`Deprecated.message`][] instead.
>
> Context: - Removed the deprecated [`CastError`][] error.

---

## Migration Analysis

### What Changed

An API has been deprecated. Users still using the old API should migrate to the recommended replacement.

### APIs Involved

- `Deprecated.message`
- `Use`

---

## Proposed Lint Rule

**Rule Type:** `deprecation_migration`
**Estimated Difficulty:** medium

### Detection Strategy

Detect usage of the deprecated API via AST method/property invocation nodes

**Relevant AST nodes:**
- `MethodInvocation`
- `PropertyAccess`
- `PrefixedIdentifier`
- `SimpleIdentifier`

### Fix Strategy

Replace with the recommended alternative API

---

## Implementation Checklist

Already covered by Plan #112 (`avoid_deprecated_expires_getter`).

---

**Status:** Duplicate of #112
**Generated:** From Dart SDK v3.0.0 release notes
