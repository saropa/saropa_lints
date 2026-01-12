# Saropa Lints — Professional Services

**[saropa.com](https://saropa.com)** | **[services@saropa.com](mailto:services@saropa.com)**

---

## Why Static Analysis Matters

Static analysis catches bugs **before they reach production**. Industry data shows:

- **30-50% reduction** in production defects ([NIST](https://www.nist.gov/))
- **6-10x cost savings** — fixing bugs in development vs production ([IBM](https://www.ibm.com/))

### What Saropa Lints Catches

| Category | Examples |
|----------|----------|
| **Crashes** | Null reference errors, memory leaks, resource leaks |
| **Security** | Hardcoded credentials, insecure storage, input validation |
| **Performance** | Unnecessary rebuilds, expensive operations in build methods |
| **Accessibility** | Missing screen reader labels, inadequate touch targets |

---

## Business Value

### For Product Owners

| Metric | Impact |
|--------|--------|
| Bug counts | 30-50% fewer production defects |
| Release velocity | Faster code reviews, less rework |
| Maintenance costs | Consistent code = easier to modify |
| Compliance | WCAG accessibility, security best practices |

### For Development Teams

| Activity | Without Linting | With Linting |
|----------|-----------------|--------------|
| Code review | 45 min (manual style checks) | 15 min (focus on logic) |
| Bug investigation | Hours of debugging | Immediate IDE feedback |
| New developer onboarding | Weeks learning patterns | Days with enforced standards |

---

## Professional Services from Saropa

Different projects have different needs. We offer three core services:

### New Projects

Scoped to your stage:

| Stage | What's included | Best for |
|-------|-----------------|----------|
| **MVP** | Core stability — crashes, security, null safety | Early-stage, validating fast |
| **Production** | Above + performance, error handling, edge cases | Scaling, real users |
| **Enterprise** | Above + accessibility, compliance, documentation | Regulated markets, enterprise sales |

Each is a complete product. You're not buying quality levels — you're matching the scope to the project's needs.

### Upgrade

Existing projects you've built, moving to a higher tier.

Your project succeeded. Now it's growing. We help you upgrade from MVP-tier to Production-tier or Enterprise-tier practices. This is progression, not remediation.

Typical phased approach:
- **Phase 1**: Enable critical rules — memory leaks, null safety, security
- **Phase 2**: Add performance and error handling rules
- **Phase 3**: Enable documentation, testing, accessibility rules
- **Phase 4**: Full enablement with team-specific exclusions

### Audit

Existing code you didn't build — or inherited from previous contractors.

We assess the codebase, produce a prioritized report, and quote remediation separately. The report is the deliverable:

- **Current state analysis** — How many issues, what categories, severity distribution
- **Risk prioritization** — Which issues pose the greatest risk to stability, security, and maintainability
- **Remediation roadmap** — Phased plan to resolve issues without disrupting feature development
- **Estimated effort** — Scope of work if you want us to handle remediation

---

### Additional Services

| Service | Description |
|---------|-------------|
| **Custom Rules** | Rules specific to your architecture, patterns, or compliance requirements |
| **Training** | Team workshops on Flutter best practices and lint-driven development |
| **Ongoing Support** | We manage your lint configuration as your codebase evolves |
| **Alpha Access** | Early access to new rules and features before public release |
| **Priority Support** | Direct communication channel with the Saropa Lints team |
| **Custom Builds** | Private fork of Saropa Lints tailored to your organization's standards |
| **Tailored Lint Sets** | We create a curated lint configuration specific to your tech stack, compliance requirements, and team preferences |
| **Sponsored Rules** | Fund development of new rules that get added to the public package — your organization gets recognition while the community benefits |

### Sponsor Rules for the Public Package

Organizations can sponsor the development of specific lint rules. Sponsored rules are added to the public Saropa Lints package, giving your organization visibility in the open source community while improving code quality for everyone. You choose the rule, we build and maintain it.

### Tailored Lint Sets for Your Organization

Every team has different needs. We create custom lint configurations that match your:

- **Tech stack** — Firebase, GraphQL, specific state management solutions
- **Compliance requirements** — HIPAA, PCI-DSS, GDPR-related patterns
- **Architectural decisions** — Your specific layers, naming conventions, and boundaries
- **Team preferences** — Severity levels, rule selections, and exceptions that fit your workflow

Tailored lint sets can be delivered as a configuration file for the public package or as a private fork with custom rules baked in.

### Why Pay for Services?

- **Time**: Your team stays on feature work while we handle code quality
- **Expertise**: We've seen hundreds of Flutter codebases and know the patterns
- **Custom Rules**: Rules that enforce your specific architectural decisions
- **Prioritization**: We know which warnings matter and which can wait

---

## Contact

**Website**: [saropa.com](https://saropa.com)
**Email**: [services@saropa.com](mailto:services@saropa.com)

---

## FAQ

### How long does adoption take?

For a medium-sized codebase, expect 2-4 weeks to resolve critical issues and 2-3 months for full adoption. With our remediation service, we can compress this significantly.

### Will this slow down our developers?

Initially, there may be a 1-2 week adjustment period. After that, development typically accelerates — fewer bugs to investigate, faster code reviews, less production firefighting.

### Is custom_lint slow with 1400+ rules?

It can be. We've implemented significant performance optimizations in v3.0.0 (tier caching, rule filtering cache, analyzer excludes). For detailed optimization strategies, see our **[Performance Guide](PERFORMANCE.md)**.

**Quick tips:**
- Use `essential` tier locally (~400 rules, 3-5x faster)
- Use `professional` in CI (thorough checking)
- Exclude generated code in `analysis_options.yaml`

### Can we customize which rules are enabled?

Yes. Every rule can be enabled, disabled, or adjusted. We can help you create a configuration that matches your team's priorities.

### What if we disagree with a rule?

Disable it. Or tell us why — if your argument is good, we'll change the rule or move it to a different tier.

### Do you offer trials?

The package is free and open source. Try it on your codebase. If you want help with adoption or custom rules, contact us.

### Can you build custom rules for our codebase?

Yes. We build rules that enforce your specific patterns — internal API usage, architectural boundaries, naming conventions, deprecated code detection, or any other pattern you want to enforce. Custom rules integrate seamlessly with the existing Saropa Lints package.

### Can we get early access to new features?

Yes. Enterprise partners get alpha access to new rules and features before public release. This lets you test changes against your codebase and provide feedback before general availability.

### Can we get a custom build for our organization?

Yes. We can create a private fork of Saropa Lints pre-configured for your organization — your tier settings, custom rules, and rule adjustments baked in. Your developers just add the dependency and everything works. We maintain the fork and merge upstream improvements automatically.

### We're using another linter. Can we switch?

Yes. See our migration guides:
- [Migrating from very_good_analysis](https://github.com/saropa/saropa_lints/blob/main/doc/guides/migration_from_vga.md)
- [Migrating from DCM (Dart Code Metrics)](https://github.com/saropa/saropa_lints/blob/main/doc/guides/migration_from_dcm.md)
