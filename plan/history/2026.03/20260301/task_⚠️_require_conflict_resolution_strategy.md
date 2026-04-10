# Task: `require_conflict_resolution_strategy`

## Summary
- **Rule Name**: `require_conflict_resolution_strategy`
- **Tier**: Professional
- **Severity**: WARNING
- **Status**: Planned
- **Source**: ROADMAP.md §1.13 Offline-First & Sync Rules

## Problem Statement

Offline-first apps allow users to make changes without internet connectivity. When the device reconnects, those local changes must be synced to the server. If another client (or the server) has also modified the same data, there is a conflict. Without a defined conflict resolution strategy, the app will either silently overwrite remote changes (last-write-wins without explicit intent) or crash with an unhandled conflict error.

The three main strategies are:
1. **Last-Write-Wins (LWW)**: The most recent timestamp wins — simplest but loses data
2. **Merge**: Three-way merge of base, local, and remote — most complex but data-preserving
3. **User Prompt**: Show a conflict dialog and let the user decide — most user-friendly for documents

Not having ANY strategy is the bug this rule targets.

## Description (from ROADMAP)

> Offline edits that conflict with server need resolution: last-write-wins, merge, or user prompt. Define strategy upfront.

## Trigger Conditions

This rule fires when:
1. Project uses an offline-first pattern (detected by use of Hive, Isar, sqflite, Drift, OR a sync package like `firebase_firestore`, `supabase`, `amplify_datastore`)
2. The codebase has sync-related code (methods named `sync`, `upload`, `push`, `pull`, `reconcile`)
3. None of these sync methods contain conflict-resolution patterns (no comparison of timestamps, no `createdAt`/`updatedAt` comparison, no conflict UI, no merge logic)

**Note**: This is a HIGH heuristic rule. It may belong in ROADMAP_DEFERRED due to cross-method analysis requirements.

## Implementation Approach

### Package + Pattern Detection

```dart
// Phase 1: Look for sync methods that do simple overwrites
context.registry.addMethodDeclaration((node) {
  if (!_isSyncMethod(node)) return;
  if (_hasConflictResolution(node)) return;
  reporter.atNode(node, code);
});
```

`_isSyncMethod`: check if method name contains `sync`, `push`, `upload`, `reconcile`.
`_hasConflictResolution`: look inside the method body for:
- Comparisons involving `updatedAt`, `createdAt`, `modifiedAt`, `version`, `revision`
- `conflict` variable names
- UI calls that could show a conflict dialog
- Merge function calls

## Code Examples

### Bad (Should trigger)
```dart
// Simple overwrite without conflict check
Future<void> syncToServer(Item localItem) async {
  await api.put('/items/${localItem.id}', localItem.toJson());
  // ← trigger: no conflict check, blindly overwrites
}

// Fetch + overwrite
Future<void> pullFromServer() async {
  final remote = await api.get('/items');
  await box.putAll(remote.items);  // ← trigger: no conflict resolution
}
```

### Good (Should NOT trigger)
```dart
// Last-write-wins with explicit timestamp comparison ✓
Future<void> syncToServer(Item localItem) async {
  final remoteItem = await api.get('/items/${localItem.id}');
  if (localItem.updatedAt.isAfter(remoteItem.updatedAt)) {
    await api.put('/items/${localItem.id}', localItem.toJson());
  }
}

// Conflict UI ✓
Future<void> syncWithConflictUI(Item local, Item remote) async {
  if (local.version != remote.version) {
    final choice = await showConflictDialog(local, remote);
    await api.put('/items/${local.id}', choice.toJson());
  }
}
```

## Edge Cases & False Positives

| Scenario | Expected Behavior | Notes |
|---|---|---|
| App is not offline-first (always requires connectivity) | **Suppress** | Hard to detect static connectivity requirement |
| App uses Amplify DataStore (handles conflicts automatically) | **Suppress** | `ProjectContext.usesPackage('amplify_datastore')` |
| App uses Firestore (offline support built-in with conflict handling) | **Suppress** | Firestore uses server-wins by default |
| One-directional sync (server to client only) | **Suppress** — read-only sync can't conflict | Hard to detect directionality |
| Test file with sync mock | **Suppress** | |
| `sync` method that is clearly part of UI animation (not data sync) | **False positive** — name collision | Check for database/network calls inside method |

## Unit Tests

### Violations
1. Method named `syncToServer` that calls `api.put(...)` without timestamp comparison → 1 lint
2. Method named `pullFromServer` that calls `box.putAll(...)` without conflict check → 1 lint

### Non-Violations
1. Same method with `updatedAt` comparison → no lint
2. Project uses `amplify_datastore` → no lint
3. Test file → no lint

## Quick Fix

No automated fix — strategy choice is architectural.

```
correctionMessage: 'Define a conflict resolution strategy: compare timestamps (last-write-wins), implement three-way merge, or show a conflict dialog to the user.'
```

## Notes & Issues

1. **LIKELY CANDIDATE FOR ROADMAP_DEFERRED** — detecting conflict resolution (or lack thereof) across method calls requires deep understanding of sync logic that is beyond simple AST patterns. The heuristic based on timestamp field names is fragile.
2. **Firestore and Amplify DataStore** have built-in conflict resolution that should suppress this rule. Project detection is key.
3. **The rule is most useful as a documentation reminder** rather than a code detector — it reminds teams to think about conflict resolution before writing sync code.
