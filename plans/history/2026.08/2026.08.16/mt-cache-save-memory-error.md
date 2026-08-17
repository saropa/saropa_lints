# MT Cache Save MemoryError Crash Fix

The i18n machine-translation cache (`mt_fallback.py`) crashed with `MemoryError` during `save_mt_cache()` when the cache dict grew large enough that `json.dumps()` on the entire dict exceeded available memory. The crash occurred mid-run after translations were complete but before the cache was persisted, losing the session's work.

## Finish Report (2026-08-16)

### Root Cause

`save_mt_cache()` and `save_provenance()` both called `json.dumps(entire_dict)`, which builds the complete JSON string in memory before writing to disk. The MT cache grows by `(number_of_locales × number_of_strings)` entries. At scale (100k+ entries with full Unicode translations), the serialised string exceeded Python's memory allocation limit.

### Fix

A shared `_stream_dict_to_json(target, data)` helper replaces the duplicated serialisation logic in both functions. The helper:

1. **Streams entries** — each `json.dumps()` call serialises a single short string (one cache key or one translation value), keeping peak memory at O(1) regardless of dict size.
2. **Atomic writes** — writes to a `tempfile.mkstemp` temp file in the same directory, then calls `os.replace()` to atomically swap the old file. A crash mid-write leaves the previous cache intact. The `except BaseException` guard cleans up the temp file on any failure, including `KeyboardInterrupt`.
3. **Empty-dict safety** — an empty dict produces `{\n}\n`, which `json.loads` parses correctly as `{}`. Verified with Python 3.14.

### Verification

Round-trip correctness confirmed for both empty and non-empty dicts via `json.loads` on the streaming writer's output format. Implicit end-to-end validation occurs on every translation run that reads back the cache.

### Files Changed

- `extension/scripts/i18n/mt_fallback.py` — extracted `_stream_dict_to_json()` with atomic temp-file writes; `save_mt_cache()` and `save_provenance()` are now one-line delegates.
- `CHANGELOG.md` — maintenance entry for the fix.
