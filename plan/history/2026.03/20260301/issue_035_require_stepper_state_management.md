# Require Stepper State Management

**GitHub:** [https://github.com/saropa/saropa_lints/issues/35](https://github.com/saropa/saropa_lints/issues/35)

**Opened:** 2026-01-23T14:01:14Z

**Resolved in:** v4.14.5 — rule `require_stepper_state_management` implemented; GitHub issue closed as completed.

---

## Detail

### Problem  
Stepper widgets should handle back navigation and preserve form state across steps. Without proper state management, users may lose data or experience confusing navigation.

### Why This Is Complex  
- **Pattern detection:** Requires analyzing Stepper usage and state management logic.
- **UI diversity:** State may be managed in various ways (local, global, provider, etc.).
- **False positives:** Some steppers may intentionally reset state.

### Desired Outcome  
- Detect Stepper without preserving form state across steps.
- Warn about potential data loss or navigation issues.
- Suggest best practices for stepper state management.

### References  
- See ROADMAP.md section: "require_stepper_state_management"
