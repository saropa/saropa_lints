"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
exports.loadIndicatorConfig = loadIndicatorConfig;
exports.loadIndicatorStyle = loadIndicatorStyle;
exports.clearIndicatorCache = clearIndicatorCache;
exports.getCategoryIndicator = getCategoryIndicator;
exports.getIndicator = getIndicator;
exports.formatIndicator = formatIndicator;
const vscode = __importStar(require("vscode"));
const DEFAULT_INDICATORS = {
    vibrant: '🟢',
    quiet: '🟡',
    legacyLocked: '🟠',
    stale: '🟠',
    endOfLife: '🔴',
    updateAvailable: '⬆',
    prerelease: '🧪',
    warning: '⚠',
    error: '🚨',
    unused: '👻',
    suppressed: '🔇',
    upToDate: '✓',
};
const CATEGORY_TEXT = {
    'vibrant': 'Vibrant',
    'quiet': 'Quiet',
    'legacy-locked': 'Legacy',
    'stale': 'Stale',
    'end-of-life': 'EOL',
};
let cachedConfig = null;
let cachedStyle = null;
/** Load indicator configuration from settings. */
function loadIndicatorConfig() {
    if (cachedConfig) {
        return cachedConfig;
    }
    const config = vscode.workspace.getConfiguration('saropaLints.packageVibrancy');
    const userIndicators = config.get('indicators', {});
    cachedConfig = { ...DEFAULT_INDICATORS, ...userIndicators };
    return cachedConfig;
}
/** Load indicator style from settings. */
function loadIndicatorStyle() {
    if (cachedStyle) {
        return cachedStyle;
    }
    const config = vscode.workspace.getConfiguration('saropaLints.packageVibrancy');
    const style = config.get('indicatorStyle', 'emoji');
    if (style === 'text' || style === 'both' || style === 'none') {
        cachedStyle = style;
    }
    else {
        cachedStyle = 'emoji';
    }
    return cachedStyle;
}
/** Clear cached configuration (call on config change). */
function clearIndicatorCache() {
    cachedConfig = null;
    cachedStyle = null;
}
/** Get the emoji for a vibrancy category. */
function getCategoryIndicator(category) {
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
function getCategoryEmoji(category, config) {
    switch (category) {
        case 'vibrant': return config.vibrant;
        case 'quiet': return config.quiet;
        case 'legacy-locked': return config.legacyLocked;
        case 'stale': return config.stale;
        case 'end-of-life': return config.endOfLife;
    }
}
/** Get a specific indicator by key. */
function getIndicator(key) {
    const config = loadIndicatorConfig();
    return config[key];
}
/** Format a status indicator with optional label. */
function formatIndicator(key, label) {
    const style = loadIndicatorStyle();
    const emoji = getIndicator(key);
    switch (style) {
        case 'emoji': return emoji;
        case 'text': return label ?? '';
        case 'both': return emoji && label ? `${emoji} ${label}` : (emoji || label || '');
        case 'none': return '';
    }
}
//# sourceMappingURL=indicator-config.js.map