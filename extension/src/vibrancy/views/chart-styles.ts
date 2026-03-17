/** CSS for size distribution charts in the vibrancy report webview. */
export function getChartStyles(): string {
    return `
        .chart-section {
            margin: 20px 0;
            --chart-color-0: hsl(210, 65%, 55%);
            --chart-color-1: hsl(175, 55%, 45%);
            --chart-color-2: hsl(145, 55%, 45%);
            --chart-color-3: hsl(80, 55%, 50%);
            --chart-color-4: hsl(40, 70%, 55%);
            --chart-color-5: hsl(20, 65%, 55%);
            --chart-color-6: hsl(0, 60%, 55%);
            --chart-color-7: hsl(330, 55%, 55%);
            --chart-color-8: hsl(270, 50%, 60%);
            --chart-color-9: var(--vscode-descriptionForeground);
        }
        .chart-section h2 {
            font-size: 1.1em;
            margin-bottom: 12px;
            opacity: 0.9;
        }
        .chart-container {
            display: flex;
            gap: 24px;
            align-items: flex-start;
        }
        .bar-chart-panel { flex: 3; min-width: 0; }
        .donut-chart-panel {
            flex: 2;
            display: flex;
            justify-content: center;
            align-items: center;
        }

        /* Bar chart */
        .bar-chart {
            display: flex;
            flex-direction: column;
            gap: 6px;
        }
        .bar-row {
            display: flex;
            align-items: center;
            gap: 8px;
            cursor: pointer;
            padding: 2px 4px;
            border-radius: 3px;
            transition: background 0.15s ease;
        }
        .bar-row:hover,
        .bar-row.highlighted {
            background: var(--vscode-list-hoverBackground);
        }
        .bar-row.dimmed { opacity: 0.3; }
        .bar-label {
            width: 120px;
            min-width: 120px;
            font-size: 0.85em;
            overflow: hidden;
            text-overflow: ellipsis;
            white-space: nowrap;
            text-align: right;
            color: var(--vscode-foreground);
        }
        .bar-track {
            flex: 1;
            height: 18px;
            background: var(--vscode-editor-inactiveSelectionBackground);
            border-radius: 3px;
            overflow: hidden;
        }
        .bar-fill {
            height: 100%;
            border-radius: 3px;
            animation: bar-grow 0.6s ease-out forwards;
        }
        .bar-value {
            width: 110px;
            min-width: 110px;
            font-size: 0.8em;
            color: var(--vscode-descriptionForeground);
            white-space: nowrap;
        }
        /* var() in keyframes requires Chromium; safe for VS Code webview. */
        @keyframes bar-grow {
            from { width: 0; }
            to { width: var(--bar-pct); }
        }

        /* Bar colors */
        .bar-color-0 { background: var(--chart-color-0); }
        .bar-color-1 { background: var(--chart-color-1); }
        .bar-color-2 { background: var(--chart-color-2); }
        .bar-color-3 { background: var(--chart-color-3); }
        .bar-color-4 { background: var(--chart-color-4); }
        .bar-color-5 { background: var(--chart-color-5); }
        .bar-color-6 { background: var(--chart-color-6); }
        .bar-color-7 { background: var(--chart-color-7); }
        .bar-color-8 { background: var(--chart-color-8); }
        .bar-color-9 { background: var(--chart-color-9); }

        /* Donut chart */
        .donut-chart { max-width: 200px; max-height: 200px; }
        .donut-segment {
            cursor: pointer;
            transition: stroke-dasharray 0.8s ease-out, opacity 0.15s ease;
        }
        .donut-segment:hover {
            opacity: 0.8;
            filter: brightness(1.15);
        }
        .donut-segment.dimmed { opacity: 0.3; }
        .donut-color-0 { stroke: var(--chart-color-0); }
        .donut-color-1 { stroke: var(--chart-color-1); }
        .donut-color-2 { stroke: var(--chart-color-2); }
        .donut-color-3 { stroke: var(--chart-color-3); }
        .donut-color-4 { stroke: var(--chart-color-4); }
        .donut-color-5 { stroke: var(--chart-color-5); }
        .donut-color-6 { stroke: var(--chart-color-6); }
        .donut-color-7 { stroke: var(--chart-color-7); }
        .donut-color-8 { stroke: var(--chart-color-8); }
        .donut-color-9 { stroke: var(--chart-color-9); }

        /* Tooltip */
        .chart-tooltip {
            position: fixed;
            padding: 6px 10px;
            background: var(--vscode-editorHoverWidget-background,
                var(--vscode-editor-background));
            border: 1px solid var(--vscode-editorHoverWidget-border,
                var(--vscode-widget-border));
            border-radius: 4px;
            font-size: 0.85em;
            color: var(--vscode-editorHoverWidget-foreground,
                var(--vscode-foreground));
            pointer-events: none;
            opacity: 0;
            transition: opacity 0.15s ease;
            z-index: 100;
            white-space: nowrap;
            box-shadow: 0 2px 8px rgba(0, 0, 0, 0.2);
        }
        .chart-tooltip.visible { opacity: 1; }

        /* Responsive: stack vertically on narrow viewports */
        @media (max-width: 600px) {
            .chart-container { flex-direction: column; }
        }
    `;
}
