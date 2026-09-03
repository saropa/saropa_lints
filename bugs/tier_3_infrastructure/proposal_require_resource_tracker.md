# PROPOSAL: Require Resource Tracker

**Status: Open**

Created: 2026-09-02

## Summary

Flags a resource acquisition (of a project-configured tracked type) that isn't registered with the project's designated resource tracker/registry, which other code relies on to verify all acquired resources are eventually released.

## Existing Coverage

`lib/src/rules/resources/resource_management_rules.dart` has many rules requiring specific resource types be closed/disposed in the same scope where they were acquired (`RequireFileCloseInFinallyRule`, `RequireHttpClientCloseRule`, `RequireWebSocketCloseRule`, and others). Those catch a missing `close()`/`dispose()` local to one file. `require_resource_tracker` is a project-configured, generic check for resource types NOT covered by a dedicated close-in-scope rule — it verifies registration with a central tracker instead of a per-type close call.

## Motivation

Projects with custom resource types (native handles, platform channels, third-party SDK sessions) often build a central tracker to catch leaks in debug builds or tests. A resource acquired but never registered defeats that safety net silently, since the tracker can only report what it was told about.

## Cross-File Requirement

Cannot be implemented as a per-file analyzer rule — needs to know whether the acquisition site's resource type/handle is registered against the project's designated tracker/registry class, whose registration API typically lives in a different file from the acquisition call site; a per-file visitor cannot confirm registration happened elsewhere. Build as a `dart run saropa_lints:cross_file` check rather than a `custom_lint` visitor. See `plans/cross_file_cli_design.md`.

## Detection / Behavior

Fires when a call to a configured "acquire" method has no matching call to the tracker's "register" method with the same variable/handle before the enclosing scope ends.

#### BAD:
```dart
final session = NativeSdk.openSession(); // never registered with ResourceTracker
```

#### GOOD:
```dart
final session = NativeSdk.openSession();
ResourceTracker.instance.register(session, onRelease: session.close);
```

## Quick Fix

Insert a `ResourceTracker.instance.register(...)` call after the acquisition, using the configured tracker class/method name from project settings.

## Alternatives Considered

Hardcoding a specific tracker class name was considered and rejected — the tracker class/method must be configurable per project, since it is a project-authored abstraction rather than a package API.
