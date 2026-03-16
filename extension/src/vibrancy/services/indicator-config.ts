import * as vscode from 'vscode';
import { VibrancyCategory } from '../types';

export interface IndicatorConfig {
    readonly vibrant: string;
    readonly quiet: string;
    readonly legacyLocked: string;
    readonly endOfLife: string;
    readonly updateAvailable: string;
    readonly prerelease: string;
    readonly warning: string;
    readonly error: string;
    readonly unused: string;
    readonly suppressed: string;
    readonly upToDate: string;
}

export type IndicatorStyle = 'emoji' | 'text' | 'both' | 'none';

const DEFAULT_INDICATORS: IndicatorConfig = {
    vibrant: '🟢',
    quiet: '🟡',
    legacyLocked: '🟠',
    endOfLife: '🔴',
    updateAvailable: '⬆',
    prerelease: '🧪',
    warning: '⚠',
    error: '🚨',
    unused: '👻',
    suppressed: '🔇',
    upToDate: '✓',
};

const CATEGORY_TEXT: Record<VibrancyCategory, string> = {
    'vibrant': 'Vibrant',
    'quiet': 'Quiet',
    'legacy-locked': 'Legacy',
    'end-of-life': 'EOL',
};

let cachedConfig: IndicatorConfig | null = null;
let cachedStyle: IndicatorStyle | null = null;

/** Load indicator configuration from settings. */
export function loadIndicatorConfig(): IndicatorConfig {
    if (cachedConfig) { return cachedConfig; }

    const config = vscode.workspace.getConfiguration('saropaLints.packageVibrancy');
    const userIndicators = config.get<Partial<IndicatorConfig>>('indicators', {});

    cachedConfig = { ...DEFAULT_INDICATORS, ...userIndicators };
    return cachedConfig;
}

/** Load indicator style from settings. */
export function loadIndicatorStyle(): IndicatorStyle {
    if (cachedStyle) { return cachedStyle; }

    const config = vscode.workspace.getConfiguration('saropaLints.packageVibrancy');
    const style = config.get<string>('indicatorStyle', 'emoji');

    if (style === 'text' || style === 'both' || style === 'none') {
        cachedStyle = style;
    } else {
        cachedStyle = 'emoji';
    }
    return cachedStyle;
}

/** Clear cached configuration (call on config change). */
export function clearIndicatorCache(): void {
    cachedConfig = null;
    cachedStyle = null;
}

/** Get the emoji for a vibrancy category. */
export function getCategoryIndicator(category: VibrancyCategory): string {
    const config = loadIndicatorConfig();
    const style = loadIndicatorStyle();

    const emoji = getCategoryEmoji(category, config);
    const text = CATEGORY_TEXT[category];

    switch (style) {
        case 'emoji': return emoji;
        case 'text': return text;
        case 'both': return emoji ? `${emoji} ${text}` : text;
        case 'none': return '';
    }
}

function getCategoryEmoji(category: VibrancyCategory, config: IndicatorConfig): string {
    switch (category) {
        case 'vibrant': return config.vibrant;
        case 'quiet': return config.quiet;
        case 'legacy-locked': return config.legacyLocked;
        case 'end-of-life': return config.endOfLife;
    }
}

/** Get a specific indicator by key. */
export function getIndicator(key: keyof IndicatorConfig): string {
    const config = loadIndicatorConfig();
    return config[key];
}

/** Format a status indicator with optional label. */
export function formatIndicator(
    key: keyof IndicatorConfig,
    label?: string,
): string {
    const style = loadIndicatorStyle();
    const emoji = getIndicator(key);

    switch (style) {
        case 'emoji': return emoji;
        case 'text': return label ?? '';
        case 'both': return emoji && label ? `${emoji} ${label}` : (emoji || label || '');
        case 'none': return '';
    }
}
