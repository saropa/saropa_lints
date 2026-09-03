# PROPOSAL: Avoid Banned Api

**Status: Open**

Created: 2026-09-02

## Summary

Flags calls to any API (method, constructor, or property) that appears on a project-configurable denylist, letting teams enforce security/compliance bans (e.g. deprecated crypto, disallowed telemetry SDKs, forbidden reflection APIs) at lint time.

## Motivation

Security and compliance teams often need to ban specific APIs project-wide — a weak hashing function, an unvetted third-party SDK call, a platform API disallowed by an internal policy, or an API tied to a past incident. Without tooling, these bans live in wiki pages or code review checklists and are routinely missed, especially by new contributors or generated code. A configurable denylist turns tribal knowledge into an enforced, versioned rule that fires the moment a banned call is introduced, before it reaches review.

## Detection / Behavior

The rule reads a project-configurable list (e.g. `banned_apis:` in `analysis_options_custom.yaml`, entries as `Type.method` or `package:pkg/path.dart#symbol`) and reports any matching method invocation, constructor call, or property access found in the analyzed unit. No list means the rule is a no-op.

```dart
// analysis_options_custom.yaml:
// banned_apis:
//   - 'md5.convert'   # weak hash, banned by policy PCI-DSS-4.1

// Bad:
import 'package:crypto/crypto.dart';
final digest = md5.convert(bytes); // LINT: md5.convert is banned by project policy

// Good:
import 'package:crypto/crypto.dart';
final digest = sha256.convert(bytes);
```

## Security Mapping

OWASP Mobile M10: Insufficient Cryptography / Extraneous Functionality (banned-API lists most commonly enforce weak-crypto and unvetted-dependency bans; the rule itself is a general-purpose compliance gate mapped case-by-case by the configured entries).

## Quick Fix

None — the rule reports a project-specific policy violation; the replacement API is context-dependent and must be chosen by the developer. The correction message may suggest a configured "preferred alternative" string per banned entry, but no automatic code change is made.

## Alternatives Considered

Hardcoding a fixed denylist in the rule itself was considered and rejected — bans vary per project and per compliance regime, so the list must be project-configurable rather than baked into the package. A narrower "banned imports only" scope was also considered but rejected as insufficient, since many bans target specific methods/constructors on otherwise-allowed types (e.g. `md5.convert` vs. the whole `crypto` package).
