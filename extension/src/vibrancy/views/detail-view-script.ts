/** JavaScript for the package detail view interactivity. */
export function getDetailScript(): string {
    return `
(function() {
    const vscode = acquireVsCodeApi();

    document.querySelectorAll('.section-header').forEach(header => {
        header.addEventListener('click', () => {
            const section = header.closest('section');
            const expanded = section.dataset.expanded === 'true';
            section.dataset.expanded = expanded ? 'false' : 'true';
        });
    });

    document.querySelectorAll('.action-btn').forEach(btn => {
        btn.addEventListener('click', () => {
            const action = btn.dataset.action;
            const packageName = btn.dataset.package;
            vscode.postMessage({ type: action, package: packageName });
        });
    });

    document.querySelectorAll('a[data-url]').forEach(link => {
        link.addEventListener('click', (e) => {
            e.preventDefault();
            const url = link.dataset.url;
            vscode.postMessage({ type: 'openUrl', url: url });
        });
    });
})();
`;
}
