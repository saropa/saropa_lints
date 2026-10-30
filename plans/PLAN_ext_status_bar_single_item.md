# Plan: extension status bar → one item

## Problem
Up to 4 Saropa status bar items show at once (seen with 2 workspace folders: contacts + saropa_lints):
1. Switch item (`switchStatusBarItem`, extension.ts ~1183): "Saropa Lints: Off / Partly off".
2. Score item (`statusBarItem`, extension.ts ~1178): "Saropa Lints: Off" / "V9/10". Duplicates item 1 when Off.
3. Health item: "Saropa: disabled / ready" (source to locate).
4. Route item (`startupController.ts` ~80): "saropa_lints: pubspec 17.0.1"; or memory/workspace-issue item (`memoryStatusBarItem`, "1 workspace issue(s)").

## Decision (owner, 2026-10-29)
One item. Text = switch state + score, e.g. "Saropa Lints: On · V9/10". Warning background when Off / Partly off / issues. Route, health, workspace issues and memory move into the tooltip (and click menu where a command exists). Recommended option chosen.

## Status
Dispatched to implementer.
