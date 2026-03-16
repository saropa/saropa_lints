const MARKETPLACE_URL =
    'https://marketplace.visualstudio.com/items?itemName=saropa.saropa-package-vibrancy';
const GITHUB_URL =
    'https://github.com/saropa/saropa-package-vibrancy';

/** Build the full HTML for the About panel. */
export function buildAboutHtml(version: string): string {
    const sections = [
        getPackageInfoHtml(version),
        getAboutSaropaHtml(),
        getConsumerAppsHtml(),
        getDeveloperEcosystemHtml(),
        getConnectHtml(),
        getCompanyProfileHtml(),
    ].join('\n<hr>\n');

    return `<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta http-equiv="Content-Security-Policy"
        content="default-src 'none'; style-src 'unsafe-inline';">
    <style>${ABOUT_STYLES}</style>
</head>
<body>${sections}</body>
</html>`;
}

function getPackageInfoHtml(version: string): string {
    return `
    <h1>Saropa Package Vibrancy</h1>
    <p class="version">v${version}</p>
    <p class="tagline">Analyze Flutter/Dart dependency health and community vibrancy.</p>
    <ul class="links">
        <li><a href="${MARKETPLACE_URL}">VS Code Marketplace</a></li>
        <li><a href="${GITHUB_URL}">GitHub Repository</a></li>
    </ul>`;
}

function getAboutSaropaHtml(): string {
    return `
    <h2>About Saropa</h2>
    <p><strong>Built for Resilience. Designed for Peace of Mind.</strong></p>
    <p>Established in 2010, <strong>Saropa Pty Limited</strong> is a technology
    firm rooted in the high-stakes worlds of financial services and online
    security. We don&rsquo;t just build apps; we build digital safeguards.
    Our philosophy is simple: technology should cut through the noise, manage
    risk automatically, and&mdash;above all&mdash;never lose your data.</p>
    <p>From developer extensions that &ldquo;just work&rdquo; to a crisis
    management platform trusted by over 50,000 users, Saropa creates software
    for those who value reliability over hype.</p>`;
}

function getConsumerAppsHtml(): string {
    return `
    <h2>Consumer Applications</h2>
    ${getContactsHtml()}
    ${getKyktoHtml()}`;
}

function getContactsHtml(): string {
    return `<div class="card">
        <h3><a href="https://saropa.com/">Saropa Contacts</a></h3>
        <p class="subtitle">The superpower your address book is missing.</p>
        <ul>
            <li><strong>Business Card Mode:</strong> Instantly hides personal contacts to show only professional connections.</li>
            <li><strong>Crisis Ready:</strong> 252+ medical tips, condition finder, and emergency numbers for 195+ countries.</li>
            <li><strong>Digital Safeguard:</strong> Biometric locking for sensitive contacts and automatic business detection.</li>
        </ul>
        <p class="meta">iOS, Android, Web &middot; 50,000+ Downloads &middot; &#9733; 4.8/5</p>
    </div>`;
}

function getKyktoHtml(): string {
    return `<div class="card">
        <h3><a href="https://kykto.com">Kykto</a></h3>
        <p class="subtitle">Writing solves problems.</p>
        <ul>
            <li><strong>Zero-friction capture:</strong> One tap to add a kyk. No folders, no tags, no dates.</li>
            <li><strong>24-hour decay:</strong> Every kyk moves to the vault after 24 hours. Fresh start, every day.</li>
            <li><strong>Export tray:</strong> Route kyks to calendar, messages, email, or clipboard.</li>
            <li><strong>Snooze:</strong> Long-press to grant one extra 24-hour cycle. Max 3 active.</li>
        </ul>
        <p class="meta">Android, iOS, Windows, macOS, Linux</p>
    </div>`;
}

function getDeveloperEcosystemHtml(): string {
    return `
    <h2>Developer Ecosystem</h2>
    ${getPackagesTableHtml()}
    ${getExtensionsListHtml()}`;
}

function getPackagesTableHtml(): string {
    return `<h3>Dart &amp; Flutter Packages</h3>
    <table>
        <tr>
            <td><a href="https://pub.dev/packages/saropa_lints">saropa_lints</a></td>
            <td>1,700+ custom rules. Catches memory leaks, security vulnerabilities (OWASP Top 10), and runtime crashes.</td>
        </tr>
        <tr>
            <td><a href="https://pub.dev/packages/saropa_dart_utils">saropa_dart_utils</a></td>
            <td>280+ production-hardened extension methods for Strings, Dates, and Lists.</td>
        </tr>
        <tr>
            <td><a href="https://pub.dev/packages/saropa_drift_viewer">saropa_drift_viewer</a></td>
            <td>Debug-only SQLite/Drift inspector with web UI, CSV export, and read-only SQL runner.</td>
        </tr>
    </table>`;
}

function getExtensionsListHtml(): string {
    return `<h3>VS Code Extensions</h3>
    <ul class="extensions">
        <li><a href="https://marketplace.visualstudio.com/items?itemName=saropa.saropa-package-vibrancy">Package Vibrancy</a> &mdash; Dependency health scanner for Flutter projects.</li>
        <li><a href="https://marketplace.visualstudio.com/items?itemName=Saropa.saropa-log-capture">Log Capture</a> &mdash; Auto-saves Debug Console output to persistent log files.</li>
        <li><a href="https://marketplace.visualstudio.com/items?itemName=Saropa.drift-viewer">Drift Viewer</a> &mdash; Inspect SQLite/Drift tables, run SQL, and export data.</li>
        <li><a href="https://marketplace.visualstudio.com/items?itemName=Saropa.saropa-claude-guard">Claude Guard</a> &mdash; Real-time Claude API cost tracking with budget enforcement.</li>
    </ul>`;
}

function getConnectHtml(): string {
    return `
    <h2>Connect With Us</h2>
    <ul class="connect">
        <li><a href="https://github.com/saropa">GitHub</a> &mdash; Open source projects, issue tracking, and technical discussions.</li>
        <li><a href="https://saropa-contacts.medium.com/">Medium</a> &mdash; Articles on resilient tech and the architecture of connection.</li>
        <li><a href="https://bsky.app/profile/saropa.com">Bluesky</a> &mdash; Real-time updates and community news.</li>
        <li><a href="https://www.linkedin.com/company/saropa-pty-ltd">LinkedIn</a> &mdash; Corporate milestones and professional networking.</li>
    </ul>`;
}

function getCompanyProfileHtml(): string {
    return `
    <h2>Company Profile</h2>
    <table class="profile">
        <tr><td>Legal Name</td><td>Saropa Pty Limited</td></tr>
        <tr><td>Founded</td><td>2010</td></tr>
        <tr><td>Core Domains</td><td>Financial Technology, Mobile &amp; Web Applications</td></tr>
        <tr><td>Headquarters</td><td>Victoria, Australia</td></tr>
        <tr><td>Website</td><td><a href="https://saropa.com/">saropa.com</a></td></tr>
    </table>`;
}

const ABOUT_STYLES = `
    body {
        font-family: var(--vscode-font-family);
        color: var(--vscode-foreground);
        background: var(--vscode-editor-background);
        padding: 24px;
        margin: 0;
        max-width: 720px;
    }
    h1 { font-size: 1.4em; margin-bottom: 4px; }
    h2 {
        font-size: 1.2em;
        margin: 0 0 12px;
        padding-bottom: 6px;
        border-bottom: 1px solid var(--vscode-widget-border, #444);
    }
    h3 { font-size: 1.05em; margin: 12px 0 6px; }
    .version { font-size: 1.1em; opacity: 0.7; margin: 0 0 12px; }
    .tagline { margin: 0 0 16px; }
    hr {
        border: none;
        border-top: 1px solid var(--vscode-widget-border, #444);
        margin: 24px 0;
    }
    .links, .extensions, .connect {
        list-style: none; padding: 0; margin: 0;
    }
    .links li, .extensions li, .connect li { margin-bottom: 8px; }
    a {
        color: var(--vscode-textLink-foreground);
        text-decoration: none;
    }
    a:hover { text-decoration: underline; }
    .card {
        border: 1px solid var(--vscode-widget-border, #444);
        border-radius: 6px;
        padding: 12px 16px;
        margin: 10px 0;
    }
    .card h3 { margin: 0 0 4px; }
    .subtitle { opacity: 0.8; margin: 0 0 8px; font-style: italic; }
    .meta { opacity: 0.7; font-size: 0.9em; margin: 8px 0 0; }
    .card ul { padding-left: 20px; margin: 8px 0; }
    .card li { margin-bottom: 4px; }
    table {
        width: 100%;
        border-collapse: collapse;
        margin: 8px 0;
    }
    td {
        padding: 6px 10px;
        border: 1px solid var(--vscode-widget-border, #444);
        vertical-align: top;
    }
    table.profile td:first-child {
        font-weight: bold;
        white-space: nowrap;
        width: 1%;
    }
`;
