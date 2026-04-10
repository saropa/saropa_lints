# Detect Provider Circular Dependencies Across Files

**GitHub:** [https://github.com/saropa/saropa_lints/issues/2](https://github.com/saropa/saropa_lints/issues/2)

**Opened:** 2026-01-23T13:30:12Z

**Resolved in:** N/A — Deferred (ROADMAP.md Part 2: Cross-file analysis required; would need provider-dependency graph infrastructure). Issue closed.

---

## Detail

### Problem  
Provider-based state management can introduce circular dependencies when Provider A depends on Provider B (in another file), and B depends on A. These cycles can cause runtime errors, stack overflows, and subtle bugs that are hard to trace.

### Why This Is Complex  
- **Cross-file analysis:** Providers are often defined and referenced in different files, requiring a global dependency graph.
- **Type resolution:** Providers may be referenced indirectly, via generics, typedefs, or through multiple layers of abstraction.
- **Dynamic registration:** Providers can be registered or composed dynamically, making static analysis challenging.
- **Performance:** Efficiently analyzing all provider relationships in large codebases is non-trivial.

### Desired Outcome  
- Extend the `ImportGraphCache` to track Provider dependencies across files.
- Detect and report cycles in the provider dependency graph, even if the cycle spans multiple files.
- Provide clear diagnostics: show the cycle path and suggest how to break the cycle.

### References  
- See ROADMAP.md section: "avoid_provider_circular_dependency"
- Related infrastructure: `ImportGraphCache`
