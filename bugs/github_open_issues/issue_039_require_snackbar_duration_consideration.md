# Require Snackbar Duration Consideration

**GitHub:** [https://github.com/saropa/saropa_lints/issues/39](https://github.com/saropa/saropa_lints/issues/39)

**Opened:** 2026-01-23T14:01:41Z

---

## Detail

### Problem  
Important messages in SnackBars need longer duration to ensure users have time to read them. Not specifying duration for important content can result in missed information.

### Why This Is Complex  
- **Pattern detection:** Requires analyzing SnackBar usage and message importance.
- **UI diversity:** Duration may be set in various ways or omitted.
- **False positives:** Some messages may intentionally be brief.

### Desired Outcome  
- Detect SnackBar without explicit duration for important content.
- Warn about potential missed messages.
- Suggest best practices for setting appropriate durations.

### References  
- See ROADMAP.md section: "require_snackbar_duration_consideration"
