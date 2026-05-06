# Require Loading Timeout (Too Complex for Generic Detection)

**GitHub:** [https://github.com/saropa/saropa_lints/issues/9](https://github.com/saropa/saropa_lints/issues/9)

**Opened:** 2026-01-23T13:44:33Z

**Resolved in:** N/A — Not viable for generic detection (ROADMAP.md Part 2: pattern ambiguity; package-specific rules may be considered). Issue closed.

---

## Detail

### Problem  
Infinite loading states can cause users to abandon the app, but detecting generic "loading" states that never resolve is not feasible with static analysis alone. Package-specific implementations (e.g., dio timeout) are required for reliable detection.

### Why This Is Complex  
- **Pattern ambiguity:** "Loading" can be implemented in many ways, with no standard pattern.
- **Package-specific logic:** Timeouts are often handled by third-party libraries or custom code.
- **State tracking:** Static analysis cannot reliably determine if a loading state will always resolve.
- **False positives:** Overly broad detection would flag many legitimate loading patterns.

### Desired Outcome  
- Document the limitation: generic detection of infinite loading states is not feasible.
- Consider package-specific rules for popular libraries (e.g., dio, http).
- Encourage developers to implement explicit timeouts in loading logic.

### References  
- See ROADMAP.md section: "require_loading_timeout"
