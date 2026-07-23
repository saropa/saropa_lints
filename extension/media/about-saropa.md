# About Saropa

**Built for Resilience. Designed for Peace of Mind.**

Established in 2010, **Saropa Pty Limited** is a technology firm rooted in the high-stakes worlds of financial services and online security. We don't just build apps; we build digital safeguards. Our philosophy is simple: technology should cut through the noise, manage risk automatically, and—above all—never lose your data.

From developer extensions that "just work" to a crisis management platform trusted by over 100,000 users, Saropa creates software for those who value reliability over hype.

---

## 📱 Mission

The core mission of **Saropa Contacts** focuses on safety, connectivity, and digital readiness. Because the company operates both as an intelligent address book app and a broader crisis-preparedness platform, they express their mission in two tightly connected ways:

*   **For the Saropa Contacts App:**
    > "Our mission is to make sure the right information is always at hand, for everyone."
*   **For the Saropa Safety Network & Platform:**
    > "To reduce the impact of crises everywhere."

---

<!-- cspell:ignore siropa -->

### The Philosophy Behind the Mission

Saropa was founded by a team with a background in financial technology and online security who noticed how unprepared people often are when disaster strikes. They believe that a standard address book should do far more than just store a passive list of names and numbers.

To bring their mission to life, they build their tools around a few core pillars:

*   **Crisis-Grade Reliability:** Ensuring that when it matters most, you can find the exact people or local emergency services you need (offering offline access to emergency numbers across 195+ countries).
*   **Data Quality & Accessibility:** Providing automated audits to clean up duplicate contacts, fill in missing information, and map out your network so your data is actually functional in an emergency.
*   **Privacy-First Transparency:** Ensuring your personal network data remains yours, kept securely on your device by default rather than being sold or heavily monetized.

> **What's in a Name?**
> The word **Saropa** (or *siropa*) refers to a ceremonial robe or sash presented by leaders of the Sikh community to individuals who have done extraordinary good deeds. The company chose this name to reflect its mandate to aid communities worldwide with disaster readiness and recovery.

---

## 📱 Consumer Applications

_Harnessing enterprise-grade security for personal connection and crisis management._

### Saropa Contacts

**The superpower your address book is missing.**

Standard contacts apps store data; Saropa helps you use it. It is an "Intelligent Address Book" that transforms your static list into a dynamic guide for your personal and professional life.

- **Smart Features:**
  - **Business Card Mode:** Instantly hides personal contacts to show only professional connections.
  - **Crisis Ready:** Access to 252+ medical tips, a condition finder, and global emergency numbers for 195+ countries.
  - **Digital Safeguard:** Biometric locking for sensitive contacts and automatic business detection.
- **Platform:** iOS, Android, Web
- **Trust:** 100,000+ Downloads | ★ 4.8/5 Rating
- **Link:** [saropa.com](https://saropa.com/)

---

### Kykto
<!-- cspell:ignore kyks -->

**Writing solves problems.**

Kykto is built on the idea that simply writing a kyk down is often all the organizing you need. Getting a task out of your head and onto a screen is the plan in itself. Every item you enter stays for exactly 24 hours. During that day, you can send it to your calendar, text it to someone, or just let it sit. If you don't take action, Kykto clears it away automatically — so you always wake up to a fresh, manageable screen.

- **Smart Features:**
  - **Zero-friction capture:** One tap to add a kyk. No folders, no tags, no dates.
  - **24-hour decay:** Every kyk moves to the vault after 24 hours. Fresh start, every day.
  - **Export tray:** Route kyks to calendar, messages, email, or clipboard.
  - **Snooze:** Long-press to grant one extra 24-hour cycle. Max 3 active.
- **Platform:** Android, iOS, Windows, macOS, Linux (mobile and desktop)
- **Package:** saropa_kykto (Flutter)
- **Link:** [kykto.com](https://kykto.com)

---

## 🛠️ Developer Ecosystem

_Production-hardened tools for VS Code, Dart, and Flutter._

### Dart & Flutter Packages

| Package                                                                   | Description                                                                                                                                                                                                                                                                                                                                                                                                                                                              |
| :------------------------------------------------------------------------ | :--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **[saropa_dart_utils](https://pub.dev/packages/saropa_dart_utils)**       | **The "Swiss Army" Library.** 280+ production-hardened extension methods for Strings, Dates, Lists, async, and HTTP. Includes single-pass HTML5 entity decoding (278 named entities), a unified async-action typedef, double-complete-safe barriers, and zero `dart:io` dependency — safe to use in pure-Dart and web contexts.                                                                                              |
| **[saropa_drift_advisor](https://pub.dev/packages/saropa_drift_advisor)** | **Debug-only SQLite/Drift inspector with companion VS Code extension.** Exposes your database as JSON and a web UI for tables, schema, CSV export, snapshot/diff, and a read-only SQL runner. Includes **Query Replay DVR** (record SQL during debug sessions and step through a timeline), a **Visual Query Builder** with multi-table joins, and **natural-language-to-SQL** that lands generated queries in the notebook, query builder, dashboards, or snippets. |
| **[saropa_lints](https://pub.dev/packages/saropa_lints)**                 | **2134 Custom Rules + 254 Quick Fixes.** Catch memory leaks, security vulnerabilities (mapped to OWASP Top 10), and runtime crashes that standard linters miss. Now bundles **Package Vibrancy** dependency-health scoring (Pub.dev + GitHub APIs categorize packages as Vibrant, Quiet, Legacy-Locked, or End of Life) — replacing the standalone `saropa_package_validator` — alongside Findings and Code Health dashboards in the companion VS Code extension.       |

### VS Code Extensions

- **[Saropa Drift Viewer](https://marketplace.visualstudio.com/items?itemName=Saropa.drift-viewer)**
  - _SQLite/Drift at a glance:_ Inspect tables, run read-only SQL, export schema or data, compare snapshots, plus **Query Replay DVR**, **Visual Query Builder** (multi-table joins), and **NL-to-SQL** that routes generated queries into the notebook, dashboards, or saved snippets.
- **[Saropa Lints](https://marketplace.visualstudio.com/items?itemName=saropa.saropa-lints)** (also on [Open VSX](https://open-vsx.org/extension/saropa/saropa-lints))
  - _Companion to the saropa_lints package:_ ships the **Findings Dashboard**, **Code Health Dashboard**, and **Package Vibrancy** scoring for Flutter/Dart projects. Surfaces all 2134 rules in the sidebar and exports `reports/.saropa_lints/violations.json` for CI.
- **[Saropa Log Capture](https://marketplace.visualstudio.com/items?itemName=Saropa.saropa-log-capture)**
  - _The Debugger's Safety Net:_ Automatically saves all Debug Console output to persistent log files. The log viewer ships with a read-only severity gutter, dedicated expand/collapse controls, dedup-fold pills, and within-line text selection. No setup required—hit F5 and your logs are safe.
- **[Saropa Workspace](https://marketplace.visualstudio.com/items?itemName=saropa.saropa-workspace)**
  - _File and script shortcuts:_ Pin any file as a favorite—single-click opens it, double-click runs it. Pins are project-scoped (shareable via the repo) or global, with a per-pin command prefix, CLI args, working directory, and environment. Seeds auto-pins and imports existing favorites.
- **[Saropa Suite](https://marketplace.visualstudio.com/items?itemName=saropa.saropa-suite)**
  - _One-click install_ for the full Saropa developer toolkit: Log Capture + Drift Advisor + Lints. Cross-extension integrations: bug reports embed lint findings, OWASP executive summaries, and project health scores; debug sessions carry query performance and schema context; right-click any SQL line in your logs to "Open in Drift Advisor."

---

## 🌐 Connect With Us

| Channel                                                         | Focus                                                                            |
| :-------------------------------------------------------------- | :------------------------------------------------------------------------------- |
| **[GitHub](https://github.com/saropa)**                         | Open source projects, issue tracking, and technical discussions.                 |
| **[Medium](https://saropa-contacts.medium.com/)**               | Articles on the "Architecture of Connection," social values, and resilient tech. |
| **[Bluesky](https://bsky.app/profile/saropa.com)**              | Real-time updates and community news.                                            |
| **[LinkedIn](https://www.linkedin.com/company/saropa-pty-ltd)** | Corporate milestones and professional networking.                                |

---

## 🏛️ Company Profile

- **Legal Name:** Saropa Pty Limited
- **Founded:** 2010
- **Core Domains:** Financial Technology, Mobile & Web Applications
- **Headquarters:** Victoria, Australia
- **Website:** [saropa.com](https://saropa.com/)
