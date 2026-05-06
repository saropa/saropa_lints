# Avoid GetIt Unregistered Access Across Files

**GitHub:** [https://github.com/saropa/saropa_lints/issues/7](https://github.com/saropa/saropa_lints/issues/7)

**Opened:** 2026-01-23T13:34:38Z

**Resolved in:** N/A — Deferred (ROADMAP.md Part 2: Cross-file; registrations and accesses in separate files). Issue closed.

---

## Detail

### Problem  
Using `GetIt.I<T>()` to access types that have not been registered can cause runtime errors and crashes. Registration and access often occur in different files, making it difficult to ensure all accessed types are properly registered.

### Why This Is Complex  
- **Cross-file analysis:** Registrations and accesses are often in separate files or modules.
- **Dynamic registration:** Types may be registered conditionally or at runtime.
- **Type resolution:** The tool must resolve generic types and aliases.
- **Performance:** Efficiently tracking all registrations and accesses in large codebases is challenging.

### Desired Outcome  
- Analyze all `GetIt` registrations and accesses across the codebase.
- Report diagnostics for any access to unregistered types.
- Suggest registering missing types or refactoring code to avoid unregistered access.

### References  
- See ROADMAP.md section: "avoid_getit_unregistered_access"
