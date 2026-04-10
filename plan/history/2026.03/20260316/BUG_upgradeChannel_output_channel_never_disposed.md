# Bug: `upgradeChannel` output channel never disposed

**Status:** Fixed
**Component:** VS Code extension — Package Vibrancy upgrade planner
**Severity:** Low — minor resource leak, no user-visible impact
**Origin:** Pre-existing in saropa-package-vibrancy (carried over during merge)

## Problem

The `upgradeChannel` output channel in `extension/src/vibrancy/extension-activation.ts` is created lazily on first use but is **never disposed** when the extension deactivates. This is a minor resource leak — the output channel remains allocated until VS Code closes.

## Relevant code

**Creation (extension-activation.ts, ~line 734):**

```typescript
let upgradeChannel: vscode.OutputChannel | null = null;

async function planAndExecuteUpgrades(): Promise<void> {
    // ...
    if (!upgradeChannel) {
        upgradeChannel = vscode.window.createOutputChannel(
            'Saropa: Upgrade Plan',
        );
    }
    upgradeChannel.clear();
    // ...
}
```

**Deactivation (extension-activation.ts) — no disposal:**

The exported `stopFreshnessWatcher()` function (called from `extension.ts` `deactivate()`) only stops the freshness watcher interval. It does not dispose `upgradeChannel`.

## Fix

Dispose the output channel during deactivation. Either:

### Option A: Dispose in stopFreshnessWatcher

```typescript
export function stopFreshnessWatcher(): void {
    if (freshnessInterval) {
        clearInterval(freshnessInterval);
        freshnessInterval = null;
    }
    if (upgradeChannel) {
        upgradeChannel.dispose();
        upgradeChannel = null;
    }
}
```

### Option B: Push to subscriptions during creation

Register the channel as a disposable when it's created, so VS Code disposes it automatically:

```typescript
if (!upgradeChannel) {
    upgradeChannel = vscode.window.createOutputChannel('Saropa: Upgrade Plan');
    context.subscriptions.push(upgradeChannel);
}
```

This requires passing `context` to `planAndExecuteUpgrades` or capturing it during activation.

## Impact

Minimal. VS Code output channels are lightweight and the OS reclaims resources on process exit. This is a code hygiene issue rather than a functional bug. In long-running VS Code sessions where the extension is activated/deactivated multiple times (rare), each cycle would leak one output channel.
