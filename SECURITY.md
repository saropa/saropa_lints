# Security Policy

## Supported Versions

We currently support the latest version of saropa_lints published on
[pub.dev](https://pub.dev/packages/saropa_lints). Please always use
the latest version to ensure you have any security patches.

| Version | Supported          |
|---------|--------------------|
| 0.1.x   | :white_check_mark: |
| < 0.1.0 | :x:                |

## Scope

saropa_lints is a static analysis package that runs during development.
It does not:
- Collect or transmit any data
- Execute at runtime in production applications
- Require network access or external services

The package analyzes your source code locally to provide lint warnings
and suggestions.

## Reporting a Vulnerability

If you discover a security vulnerability in saropa_lints, please report
it responsibly.

**For security issues:** Email [security@saropa.com](mailto:security@saropa.com)

**For general bugs:** Open an issue at
[github.com/saropa/saropa_lints/issues](https://github.com/saropa/saropa_lints/issues)

You should expect a response within 48 hours. Please provide:
- A description of the vulnerability
- Steps to reproduce the issue
- Potential impact assessment

We appreciate responsible disclosure and will acknowledge contributors
in our release notes (unless you prefer to remain anonymous).
