# Implementable only in plugin/extension

Candidates that **could** be implemented as rules or fixes, but only with additional plugin or extension capabilities (e.g. analyzer plugin API, multi-file refactor, or extension-driven flow). They refer to user-facing Dart/Flutter API or patterns in user code.

## Why they are here

- The change is about **user code** (deprecations, “prefer X over Y” in app/library code).
- Implementing it as a lint or quick fix may require:
  - New or extended analyzer plugin APIs
  - Multi-file or cross-library refactors
  - Extension UI or commands to drive the migration

So they are “not viable” with the **current** plugin/extension surface but are in scope once that surface is extended.

## Count

**77** migration-candidate files. These are user-facing API deprecations or “prefer X over Y” patterns that could be implemented as rules or fixes with extended plugin/extension support.
