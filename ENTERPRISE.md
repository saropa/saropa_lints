# saropa_lints for Enterprise

**[saropa.com](https://saropa.com)** | **[enterprise@saropa.com](mailto:enterprise@saropa.com)**

---

## Why Static Analysis Matters

Static analysis catches bugs **before they reach production**. Industry data shows:

- **30-50% reduction** in production defects ([NIST](https://www.nist.gov/))
- **6-10x cost savings** — fixing bugs in development vs production ([IBM](https://www.ibm.com/))

### What saropa_lints Catches

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

## Adoption for Existing Projects

When enabling comprehensive linting on a legacy codebase, expect thousands of warnings initially. This is normal.

| Project Size | Initial Warnings |
|--------------|------------------|
| Small (10K lines) | 500-2,000 |
| Medium (50K lines) | 2,000-10,000 |
| Large (200K+ lines) | 10,000-50,000+ |

### Recommended Approach

**Phase 1 (Week 1)**: Enable critical rules only — memory leaks, null safety, security
**Phase 2 (Weeks 2-4)**: Add performance and error handling rules
**Phase 3 (Months 2-3)**: Enable documentation, testing, accessibility rules
**Phase 4 (Month 3+)**: Full enablement with team-specific exclusions

---

## Professional Services from Saropa

The open source package is free. For teams that want hands-on help:

| Service | Description |
|---------|-------------|
| **Codebase Assessment** | We analyze your codebase, prioritize findings, and create a remediation roadmap |
| **Remediation** | We fix the issues — you stay focused on features |
| **Custom Rules** | Rules specific to your architecture, patterns, or compliance requirements |
| **Training** | Team workshops on Flutter best practices and lint-driven development |
| **Ongoing Support** | We manage your lint configuration as your codebase evolves |
| **Alpha Access** | Early access to new rules and features before public release |
| **Priority Support** | Direct communication channel with the saropa_lints team |
| **Custom Builds** | Private fork of saropa_lints tailored to your organization's standards |
| **Tailored Lint Sets** | We create a curated lint configuration specific to your tech stack, compliance requirements, and team preferences |
| **Sponsored Rules** | Fund development of new rules that get added to the public package — your organization gets recognition while the community benefits |

### Project Assessments

Not sure where to start? We assess your codebase and deliver a detailed report:

- **Current state analysis** — How many issues, what categories, severity distribution
- **Risk prioritization** — Which issues pose the greatest risk to stability, security, and maintainability
- **Remediation roadmap** — Phased plan to resolve issues without disrupting feature development
- **Estimated effort** — Scope of work if you want us to handle remediation

Assessments are available as a standalone service or as the first step in a larger engagement.

### Sponsor Rules for the Public Package

Organizations can sponsor the development of specific lint rules. Sponsored rules are added to the public saropa_lints package, giving your organization visibility in the open source community while improving code quality for everyone. You choose the rule, we build and maintain it.

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
**Email**: [enterprise@saropa.com](mailto:enterprise@saropa.com)

---

## FAQ

### How long does adoption take?

For a medium-sized codebase, expect 2-4 weeks to resolve critical issues and 2-3 months for full adoption. With our remediation service, we can compress this significantly.

### Will this slow down our developers?

Initially, there may be a 1-2 week adjustment period. After that, development typically accelerates — fewer bugs to investigate, faster code reviews, less production firefighting.

### Can we customize which rules are enabled?

Yes. Every rule can be enabled, disabled, or adjusted. We can help you create a configuration that matches your team's priorities.

### What if we disagree with a rule?

Disable it. Or tell us why — if your argument is good, we'll change the rule or move it to a different tier.

### Do you offer trials?

The package is free and open source. Try it on your codebase. If you want help with adoption or custom rules, contact us.

### Can you build custom rules for our codebase?

Yes. We build rules that enforce your specific patterns — internal API usage, architectural boundaries, naming conventions, deprecated code detection, or any other pattern you want to enforce. Custom rules integrate seamlessly with the existing saropa_lints package.

### Can we get early access to new features?

Yes. Enterprise partners get alpha access to new rules and features before public release. This lets you test changes against your codebase and provide feedback before general availability.

### Can we get a custom build for our organization?

Yes. We can create a private fork of saropa_lints pre-configured for your organization — your tier settings, custom rules, and rule adjustments baked in. Your developers just add the dependency and everything works. We maintain the fork and merge upstream improvements automatically.

### We're using another linter. Can we switch?

Yes. See our migration guides:
- [Migrating from very_good_analysis](https://github.com/saropa/saropa_lints/blob/main/doc/guides/migration_from_vga.md)
- [Migrating from DCM (Dart Code Metrics)](https://github.com/saropa/saropa_lints/blob/main/doc/guides/migration_from_dcm.md)
