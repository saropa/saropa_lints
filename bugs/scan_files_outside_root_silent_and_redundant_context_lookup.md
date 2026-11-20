# scan --files: out-of-root files skipped silently; redundant contextFor lookup

**Status: Open**
**Component:** `lib/src/scan/scan_runner.dart`

## Problem

1. Files passed to `scan --files` that lie outside the analysis context root are skipped with only a stderr line. The scan still exits 0, so CI can pass having scanned nothing.
2. `contextFor` is probed per file, then called again in `_scanSingleFileResolved`. The second lookup is redundant, and only `StateError` is caught.

## Expected

1. Exit non-zero (or at least a distinct, documented code) when any requested file was skipped for being outside the root, or when zero files were scanned.
2. Resolve the context once per file and pass it through.

## Decision

Pending.
