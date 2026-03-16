"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.matchFamily = matchFamily;
/** Known package families where major version alignment matters.
 * Only include product families whose packages are actually version-coupled
 * (e.g. riverpod/hooks_riverpod, bloc/flutter_bloc). Do NOT include families
 * with independent version tracks — Firebase (firebase_core v4, firebase_messaging
 * v16) and Google (google_fonts, google_sign_in) each manage versions independently. */
const FAMILIES = {
    riverpod: {
        label: 'Riverpod',
        pattern: /^(riverpod|flutter_riverpod|hooks_riverpod)$/,
    },
    bloc: {
        label: 'Bloc',
        pattern: /^(bloc|flutter_bloc|hydrated_bloc|replay_bloc)$/,
    },
    freezed: {
        label: 'Freezed',
        pattern: /^(freezed|freezed_annotation|json_serializable)$/,
    },
    drift: {
        label: 'Drift',
        pattern: /^(drift|drift_dev|drift_postgres)$/,
    },
};
/** Match a package name to a known family. */
function matchFamily(name) {
    for (const [id, def] of Object.entries(FAMILIES)) {
        if (def.pattern.test(name)) {
            return { id, label: def.label };
        }
    }
    return null;
}
//# sourceMappingURL=package-families.js.map