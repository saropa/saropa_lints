# Require Refresh Completion Feedback (Too Complex for Generic Detection)

**GitHub:** [https://github.com/saropa/saropa_lints/issues/11](https://github.com/saropa/saropa_lints/issues/11)

**Opened:** 2026-01-23T13:44:49Z

---

## Detail

### Problem  
When a user triggers a refresh, the UI should provide visible feedback upon completion. However, detecting whether a refresh provides feedback is too abstract for static analysis, as "feedback" can take many forms.

### Why This Is Complex  
- **Feedback ambiguity:** Feedback may be a UI change, animation, or message, implemented in countless ways.
- **State tracking:** Static analysis cannot determine if a refresh action results in visible feedback.
- **Pattern diversity:** No standard method for refresh feedback across projects.
- **False positives:** Generic detection would flag many valid implementations.

### Desired Outcome  
- Document the limitation: generic detection of refresh feedback is not feasible.
- Encourage developers to provide explicit feedback in refresh logic.
- Consider rules for specific UI frameworks or patterns.

### References  
- See ROADMAP.md section: "require_refresh_completion_feedback"
