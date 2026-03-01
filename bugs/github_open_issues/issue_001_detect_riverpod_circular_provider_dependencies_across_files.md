# Detect Riverpod Circular Provider Dependencies Across Files

**GitHub:** [https://github.com/saropa/saropa_lints/issues/1](https://github.com/saropa/saropa_lints/issues/1)

**Opened:** 2026-01-23T13:27:44Z

---

## Detail

**Issue Title:**  
Detect Riverpod Circular Provider Dependencies Across Files

**Issue Detail:**  
### Problem  
Riverpod providers can depend on each other across multiple files, creating the risk of circular dependencies. These cycles can cause runtime errors, unpredictable state, and are difficult to debugâ€”especially in large codebases where providers are scattered across many files.

### Why This Is Complex  
- **Cross-file analysis required:** Detecting cycles means building a dependency graph that spans all provider definitions, not just within a single file.
- **Dynamic references:** Providers may be referenced via `ref.watch()` or `ref.read()` in various locations, including inside functions, classes, or even conditionally.
- **Type resolution:** The tool must resolve provider types and their relationships, which may involve generics, typedefs, or indirect references.
- **Performance:** Analyzing the entire dependency graph efficiently, especially in large projects, is non-trivial.

### Desired Outcome  
- Build or extend the existing `ImportGraphCache` infrastructure to also track Riverpod provider dependencies.
- Detect and report any cycles in the provider dependency graph, even if the cycle spans multiple files.
- Provide actionable diagnostics: show the cycle path and suggest refactoring to break the cycle.

### References  
- See ROADMAP.md section: "avoid_riverpod_circular_provider"
- Related infrastructure: `ImportGraphCache`
