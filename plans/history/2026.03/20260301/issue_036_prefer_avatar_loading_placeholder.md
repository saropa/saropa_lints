# Prefer Avatar Loading Placeholder

**GitHub:** [https://github.com/saropa/saropa_lints/issues/36](https://github.com/saropa/saropa_lints/issues/36)

**Opened:** 2026-01-23T14:01:21Z

**Resolved in:** Already implemented — same as #27: `prefer_avatar_loading_placeholder`. Issue closed.

---

## Detail

### Problem  
When loading avatars, a placeholder should be shown until the image is loaded. Not providing a placeholder can result in a poor user experience with empty or flickering UI.

### Why This Is Complex  
- **Pattern detection:** Requires analyzing CircleAvatar or similar widgets for placeholder usage.
- **UI diversity:** Placeholders may be implemented in various ways.
- **False positives:** Some apps may intentionally not use placeholders.

### Desired Outcome  
- Detect CircleAvatar without placeholder during load.
- Warn about potential UI issues.
- Suggest best practices for avatar loading placeholders.

### References  
- See ROADMAP.md section: "prefer_avatar_loading_placeholder"
