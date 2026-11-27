"""Hand-written replacements for machine translations that leaked the MT prompt,
ran far past the English source, or looped a word or phrase.

Found by the 2026-11-27 audit: Qwen echoed its own instructions ("Strict rules:
1. Return ONLY the translated string...") into 46+ values, NLLB looped short
labels ("Linea Linea Linea Linea") and long Swahili sentences, and a few values
kept only the prompt with no translation at all. Each entry is written from the
full English source, keeping {placeholders}, code spans, links, markdown and the
brand "Saropa" exactly.

Keyed locale -> {English source: translation}. Folded into _REPAIRS in
manual_translations_gaps.py, so these win over GAPS and over the MT cache (the
generator consults the dictionary before the cache). Unverified by native
speakers.
"""

from __future__ import annotations

from typing import Dict

# Long English sources are spelled once here and referenced by alias below, so each
# literal lives in one place (and a typo fails the alias lookup, not silently).
TRIAGE = "Rules grouped by priority — errors, volume bands, and stylistic. Each group shows **estimated score impact**.\n\nUse **Manage Rule Packs** to enable or disable rules and rule packs; changes write to YAML and re-run analysis.\n\n[Open Manage Rule Packs](command:saropaLints.openConfigDashboard)"
CROSS_FILE = "Run project-wide checks that single-file analysis cannot do: unused files, circular dependencies, import stats, feature dependencies, dead imports, unused symbols, unused l10n keys, duplicate blocks, snapshot JSON, graph export, and HTML report.\n\n[Find Unused Files](command:saropaLints.crossFile.unusedFiles) · [Generate Cross-File HTML Report](command:saropaLints.crossFile.report)"
OPEN_SIGNALS = "Regex patterns (matched against the whole document, multiline) that mean the document still reads as open work. Matched with the 'm' flag; an invalid pattern is skipped."
ARCHIVE_GLOB = "Glob pattern for the workspace's closed/archive doc directory. A matching file is checked for open-work signals."
SCAN_DIRS = "Directories to scan on startup (relative to the project root). Only used when Workspace Scan is enabled. Adjust this to match your project structure — e.g. add 'src' or remove 'test' if test files are not relevant."
WORKSPACE_SCAN = "Scan the entire workspace on startup so diagnostics appear project-wide in the Problems panel, not just for files you open. Disable this for very large projects where the initial scan takes too long."
LSP_DESC = "Separate language server — publishes diagnostics to the Problems panel for open and workspace files. Toggling writes the saropaLints.lspServer.enabled setting."
ANALYZER_REC = "Recommended: OFF while LSP Server is on. Turn ON (with LSP OFF) if a rule stops firing under LSP."
NAV_LINKS = "Routing and deep-link handling — auto_route, go_router, app_links, url_launcher, and webview."
STORAGE = "Local databases and key-value stores — Drift, Hive, Isar, sqflite, shared_preferences."
TIER_CAP = "Caps which tiers run at analysis time, independent of which rules are explicitly enabled. Leave as None to use the extension's Tier setting."
MONITOR_WHY = "Large projects routinely leak analysis servers. You'll now see it before your machine slows down."
WIDGET_STYLE = "Flutter widget choices — SizedBox.square, center over align, spacing over SizedBox, and avoiding shrinkWrap in scrolls. Flutter projects only."
LINK_NOTE = "Scan on save on/off lives in the sidebar's status row; the analysis tier lives on the Tier tab — both do more than a plain setting write, so they are not duplicated here."
SAME_AS_TREE = "Same grouping as the Triage activity-bar tree: filter Issues, or disable/enable rules in `analysis_options_custom.yaml`. Large groups may ask for confirmation."
PROTECTED = "Core source folders (lib/, lib/src/, bin/) are never recommended for exclusion."
LEGACY_KEY = "saropaLints.scanOnSave.enabled has no effect — scan-on-save is controlled entirely by saropaLints.enabled. Remove the unused key from your settings."
BASELINE_HINT = "A baseline suppresses the project's EXISTING violations so only newly-introduced findings surface afterward."
WATCHER_REC = "Recommended excludes not yet in files.watcherExclude"
DISCOVER_RULES = "Configure which of the 2,350+ rules run and at what severity."
OFFER_RENAMES = "saropa_lints: your project uses {route} at {installed}. {offered} is available and works with your Dart {dart}. Renamed rules will be checked after the upgrade. Migrate?"
FORMATTING = "Blank-line placement, trailing commas, and literal and comment style. Can be noisy — many files may need edits."
ENGINE_BODY = "The engine that produces your diagnostics is no longer the in-process Analyzer Plugin — it is now a standalone LSP server, on by default for every project. This is beta software, and its behavior is still changing between releases. If a rule you rely on stops firing, fires differently, or a quick fix disappears, this is the most likely cause. The Analyzer Plugin still exists and can be restored in one click."
SHED_LEVEL3 = "Memory pressure: {count} rules shed (all non-essential non-ERROR)"
REPORTS_INTRO = "One-click CLI reports that previously required a terminal. Each Run button streams the tool's live output below its card and saves a copy under reports/.saropa_lints/reports-tab/."
RULE_COUNT_STRIP = "{total} lint rules currently ship in this version (essential {essential} · recommended {recommended} · professional {professional} · comprehensive {comprehensive} · pedantic {pedantic} · {stylistic} opt-in stylistic)"
HERO_SUBTITLE = "This release changes the default diagnostic engine. Read this before you keep working — it affects what you'll see in the Problems panel."
MONITOR_BODY = "The extension now monitors system RAM, every Dart analysis server, Flutter daemon, and background process — not just its own. A Dev Tool Budget indicator warns when dev tools exceed a configurable share of RAM, and orphaned processes from crashed sessions are detected at startup."
OPINIONATED = "Assorted style choices — concise names, exhaustive enums, guard clauses, positive conditions, and more. Many rules; can be noisy."
BANNED_USAGE = "Flags a specific identifier (a function, class, or member name) anywhere it appears in the project, with a custom reason shown in the diagnostic."
HEAP_NONE = "Your machine has {totalGb} of memory. The Dart analysis server has no memory ceiling, so it can grow until the machine slows down or starts swapping. Recommended cap: {recommendedGb}."
FULL_REPORT = "Export the exhaustive feature-usage report (every scanned package, every mined changelog feature) as an HTML/Markdown/JSON file and open it."
PLUGIN_OFF = "Saropa Lints is on, but in-editor diagnostics are off: the analyzer plugin was turned off from this extension and never restored, so issues only appear after a scan. Restore live in-editor diagnostics, or keep scan-on-save only?"
ACCEPTED_ISSUES = "Accepted findings: {stale} stale and {invalid} invalid, out of {count} entries. See the Problems panel."
FAST_DONE = "Fast scan complete: {files} files, {issues} issue(s) in {seconds}s. A type-aware scan can find more, but takes about {minutes} min and {memory} of memory."
SETUP_PROMPT = "Saropa Lints detected a Dart project without saropa_lints configured. Set up now for 2350+ lint rules."
PLATFORM_UNSUPPORTED = "Machine Health is not available on this platform — process queries support Windows, macOS and Linux."
LANE_LIGHT = "Only ~200 error/warning rules run in-editor"
CHECK_UPDATES = "Saropa Lints: Check for Package Updates Now"
EXPORT_OWASP = "Saropa Lints: Export OWASP Compliance Report"
OPEN_DART_PROJECT = "Saropa Lints: open a Dart project first."
BASELINE_FAILED = "Saropa Lints: could not create baseline. {details}"
CONFIG_WRITE_FAILED = "Saropa Lints: config write failed. {details}"
CONFIG_UPDATED = "Saropa Lints config updated (tier: {tier})."
ENABLED_PACKS = "Saropa Lints: enabled {count} recommended pack(s)."
COULD_NOT_SUPPRESS = "Could not suppress '{flag}' in {file}: {error}"

# Short labels: NLLB looped the word ("Linea Linea Linea Linea") or appended an
# invented sentence ("PR PR PR is een soort van PR."). Each value is the single
# label the UI shows. "PR", "id" and "dev" stay Latin where the locale's other UI
# already writes them that way.
LEAK_REPAIRS: Dict[str, Dict[str, str]] = {
    "ar": {
        MONITOR_WHY: "كثيرًا ما تترك المشاريع الكبيرة خوادم تحليل يتيمة تعمل. سترى ذلك الآن قبل أن يتباطأ جهازك.",
        "Line": "السطر",
        LEGACY_KEY: "ليس للإعداد saropaLints.scanOnSave.enabled أي تأثير — يتحكم saropaLints.enabled وحده في الفحص عند الحفظ. احذف المفتاح غير المستخدم من إعداداتك.",
        STORAGE: "قواعد البيانات المحلية ومخازن المفتاح والقيمة — Drift، Hive، Isar، sqflite، shared_preferences.",
        TIER_CAP: "يحدّد المستويات التي تعمل وقت التحليل، بصرف النظر عن القواعد المفعّلة صراحةً. اتركه على «لا شيء» لاستخدام إعداد Tier في الإضافة.",
        BASELINE_HINT: "يكتم خط الأساس المخالفات الموجودة مسبقًا في المشروع، فلا تظهر بعد ذلك إلا النتائج الجديدة.",
        WATCHER_REC: "استثناءات موصى بها غير موجودة بعد في files.watcherExclude",
        LINK_NOTE: "يوجد تشغيل الفحص عند الحفظ وإيقافه في صف الحالة بالشريط الجانبي، ويوجد مستوى التحليل في علامة التبويب Tier — كلاهما يفعل أكثر من مجرد كتابة إعداد، لذا لا يتكرران هنا.",
        "Info": "معلومات",
        "menu": "قائمة",
        "Event": "الحدث",
        "in-process, not separately measurable": "داخل العملية، لا يمكن قياسه بشكل منفصل",
        LSP_DESC: "خادم لغة منفصل — ينشر التشخيصات في لوحة المشكلات للملفات المفتوحة وملفات مساحة العمل. يؤدي التبديل إلى كتابة الإعداد saropaLints.lspServer.enabled.",
        LANE_LIGHT: "لا تعمل في المحرر إلا ~200 قاعدة من نوع خطأ/تحذير",
        CROSS_FILE: "شغّل فحوصات على مستوى المشروع لا يستطيع تحليل الملف الواحد إجراءها: الملفات غير المستخدمة، والتبعيات الدائرية، وإحصاءات الاستيراد، وتبعيات الميزات، والاستيرادات الميتة، والرموز غير المستخدمة، ومفاتيح l10n غير المستخدمة، والكتل المكررة، ولقطة JSON، وتصدير الرسم البياني، وتقرير HTML.\n\n[البحث عن الملفات غير المستخدمة](command:saropaLints.crossFile.unusedFiles) · [إنشاء تقرير HTML عبر الملفات](command:saropaLints.crossFile.report)",
        WORKSPACE_SCAN: "افحص مساحة العمل بالكامل عند بدء التشغيل حتى تظهر التشخيصات للمشروع كله في لوحة المشكلات، وليس فقط للملفات التي تفتحها. عطّل هذا في المشاريع الكبيرة جدًا التي يستغرق فيها الفحص الأولي وقتًا طويلًا.",
        SCAN_DIRS: "المجلدات التي تُفحص عند بدء التشغيل (نسبةً إلى جذر المشروع). تُستخدم فقط عند تفعيل Workspace Scan. عدّلها لتطابق بنية مشروعك — مثلًا أضف 'src' أو احذف 'test' إذا لم تكن ملفات الاختبار ذات صلة.",
    },
    "bn": {
        "PR": "PR",
        "id": "আইডি",
        # Follows a count ("3 বার" = "3 times"), so the leading space stays.
        " run": " বার",
        "complex": "জটিল",
        "No": "না",
        "Author": "লেখক",
        "note": "নোট",
    },
    "de": {
        DISCOVER_RULES: "Legen Sie fest, welche der 2.350+ Regeln laufen und mit welchem Schweregrad.",
        TIER_CAP: "Begrenzt, welche Tiers zur Analysezeit laufen, unabhängig davon, welche Regeln ausdrücklich aktiviert sind. Lassen Sie „Keine“ stehen, um die Tier-Einstellung der Erweiterung zu verwenden.",
        "Title": "Titel",
        "More": "Mehr",
        "On": "An",
        SAME_AS_TREE: "Gleiche Gruppierung wie im Triage-Baum der Aktivitätsleiste: Probleme filtern oder Regeln in `analysis_options_custom.yaml` deaktivieren/aktivieren. Bei großen Gruppen kann eine Bestätigung abgefragt werden.",
        "id": "ID",
        # " run" / " runs" follow a count ("3 runs"), so the leading space stays.
        " run": " Ausführung",
        " runs": " Ausführungen",
        "No": "Nein",
        "more": "mehr",
        TRIAGE: "Regeln nach Priorität gruppiert — Fehler, Mengenbereiche und Stilregeln. Jede Gruppe zeigt die **geschätzte Auswirkung auf den Score**.\n\nMit **Regelsets verwalten** aktivieren oder deaktivieren Sie Regeln und Regelsets; Änderungen werden in YAML geschrieben und die Analyse wird neu gestartet.\n\n[Regelsets verwalten öffnen](command:saropaLints.openConfigDashboard)",
        SCAN_DIRS: "Verzeichnisse, die beim Start gescannt werden (relativ zum Projektstamm). Wird nur verwendet, wenn Workspace Scan aktiviert ist. Passen Sie dies an Ihre Projektstruktur an — z. B. 'src' hinzufügen oder 'test' entfernen, wenn Testdateien nicht relevant sind.",
    },
    "es": {
        "PR": "PR",
        "Author": "Autor",
        "More": "Más",
        "Help": "Ayuda",
        "connected": "conectado",
        "Off": "Desactivado",
        "more": "más",
        # The brand shield failed and NLLB inserted an invented sentence after "Saropa Lints:".
        OPEN_DART_PROJECT: "Saropa Lints: abra primero un proyecto Dart.",
        CHECK_UPDATES: "Saropa Lints: Buscar actualizaciones de paquetes ahora",
        EXPORT_OWASP: "Saropa Lints: Exportar informe de cumplimiento OWASP",
    },
    "fa": {
        "Line": "خط",
        "Report": "گزارش",
        "PR": "PR",
        "Type": "نوع",
        "Title": "عنوان",
        "More": "بیشتر",
        "active": "فعال",
        "title": "عنوان",
        "id": "شناسه",
        "Yes": "بله",
        "more": "بیشتر",
    },
    "fil": {
        "No": "Hindi",
        BASELINE_FAILED: "Saropa Lints: hindi magawa ang baseline. {details}",
        CONFIG_WRITE_FAILED: "Saropa Lints: nabigo ang pagsulat ng config. {details}",
        CONFIG_UPDATED: "Na-update ang config ng Saropa Lints (tier: {tier}).",
        "Continue": "Magpatuloy",
        ENABLED_PACKS: "Saropa Lints: pinagana ang {count} inirerekomendang pack.",
    },
    "fr": {
        MONITOR_WHY: "Les grands projets laissent souvent des serveurs d'analyse orphelins en mémoire. Vous le verrez désormais avant que votre machine ne ralentisse.",
        WIDGET_STYLE: "Choix de widgets Flutter — SizedBox.square, center plutôt qu'align, spacing plutôt que SizedBox, et éviter shrinkWrap dans les défilements. Projets Flutter uniquement.",
        LINK_NOTE: "L'activation de l'analyse à l'enregistrement se trouve dans la ligne d'état de la barre latérale ; le niveau d'analyse se trouve dans l'onglet Tier — les deux font plus qu'écrire un simple paramètre, ils ne sont donc pas dupliqués ici.",
        LSP_DESC: "Serveur de langage distinct — publie les diagnostics dans le panneau Problèmes pour les fichiers ouverts et ceux de l'espace de travail. Le basculement écrit le paramètre saropaLints.lspServer.enabled.",
        PROTECTED: "Les dossiers sources principaux (lib/, lib/src/, bin/) ne sont jamais recommandés pour l'exclusion.",
        OFFER_RENAMES: "saropa_lints : votre projet utilise {route} en {installed}. {offered} est disponible et fonctionne avec votre Dart {dart}. Les règles renommées seront vérifiées après la mise à niveau. Migrer ?",
        OPEN_SIGNALS: "Motifs regex (appliqués à l'ensemble du document, en mode multiligne) indiquant que le document décrit encore un travail en cours. Ils sont évalués avec l'indicateur 'm' ; un motif invalide est ignoré.",
    },
    "he": {
        "PR": "PR",
        "dev": "dev",
        "id": "מזהה",
        "more": "עוד",
    },
    "hi": {
        "Enable breaking only ({count})": "केवल ब्रेकिंग सक्षम करें ({count})",
        "PR": "PR",
        "id": "आईडी",
        "Line": "पंक्ति",
        "Message": "संदेश",
        "Version": "संस्करण",
        "Title": "शीर्षक",
        "Info": "जानकारी",
        "System": "सिस्टम",
        "note": "नोट",
        "Stable": "स्थिर",
        "Distribution": "वितरण",
        "Category": "श्रेणी",
        "Engine": "इंजन",
        "complex": "जटिल",
        "Author": "लेखक",
        TRIAGE: "प्राथमिकता के अनुसार समूहित नियम — त्रुटियाँ, वॉल्यूम बैंड और शैलीगत। हर समूह **अनुमानित स्कोर प्रभाव** दिखाता है।\n\nनियमों और नियम पैक को सक्षम या अक्षम करने के लिए **नियम पैक व्यवस्थापन** का उपयोग करें; बदलाव YAML में लिखे जाते हैं और विश्लेषण फिर से चलता है।\n\n[नियम पैक व्यवस्थापन खोलें](command:saropaLints.openConfigDashboard)",
    },
    "id": {
        "Impact": "Dampak",
        "Line": "Baris",
        "Message": "Pesan",
        "Version": "Versi",
        "Score": "Skor",
        "Title": "Judul",
        "connected": "terhubung",
        "title": "judul",
        "id": "id",
        "Frequent": "Sering",
        "Functions": "Fungsi",
        "Function": "Fungsi",
        "Yes": "Ya",
        "No": "Tidak",
        "Dimensions": "Dimensi",
        "package": "paket",
    },
    "it": {
        MONITOR_WHY: "I progetti grandi lasciano spesso server di analisi orfani in esecuzione. Ora lo vedrai prima che il computer rallenti.",
        "Line": "Riga",
        "Version": "Versione",
        WIDGET_STYLE: "Scelte di widget Flutter — SizedBox.square, center al posto di align, spacing al posto di SizedBox ed evitare shrinkWrap negli scroll. Solo progetti Flutter.",
        STORAGE: "Database locali e archivi chiave-valore — Drift, Hive, Isar, sqflite, shared_preferences.",
        NAV_LINKS: "Routing e gestione dei deep link — auto_route, go_router, app_links, url_launcher e webview.",
        TIER_CAP: "Limita quali livelli vengono eseguiti durante l'analisi, indipendentemente dalle regole abilitate esplicitamente. Lascia «Nessuno» per usare l'impostazione Tier dell'estensione.",
        "All": "Tutti",
        "PR": "PR",
        "Title": "Titolo",
        "Errors": "Errori",
        "More": "Altro",
        "note": "nota",
        "On": "Attivo",
        "Copy": "Copia",
        "categories": "categorie",
        "title": "titolo",
        "Function": "Funzione",
        "Yes": "Sì",
        "No": "No",
        LSP_DESC: "Server di linguaggio separato — pubblica la diagnostica nel pannello Problemi per i file aperti e per quelli dell'area di lavoro. L'attivazione o disattivazione scrive l'impostazione saropaLints.lspServer.enabled.",
        ANALYZER_REC: "Consigliato: DISATTIVATO mentre il server LSP è attivo. ATTIVALO (con LSP DISATTIVATO) se una regola smette di attivarsi con LSP.",
        "more": "altro",
        # The brand shield failed and NLLB inserted an invented sentence after "Saropa Lints:".
        BASELINE_FAILED: "Saropa Lints: impossibile creare la baseline. {details}",
        CONFIG_WRITE_FAILED: "Saropa Lints: scrittura della configurazione non riuscita. {details}",
        "Continue": "Continua",
        "files": "file",
    },
    "ja": {
        "dev": "dev",
        "id": "ID",
        "Yes": "はい",
    },
    "ko": {
        "System": "시스템",
        "On": "켜짐",
        "Updates": "업데이트",
        "Platforms": "플랫폼",
        "Continue": "계속",
        TRIAGE: "우선순위별로 묶인 규칙 — 오류, 발생량 구간, 스타일. 각 그룹에 **예상 점수 영향**이 표시됩니다.\n\n**룰 팩 관리**에서 규칙과 룰 팩을 켜거나 끌 수 있습니다. 변경 사항은 YAML에 기록되고 분석이 다시 실행됩니다.\n\n[룰 팩 관리 열기](command:saropaLints.openConfigDashboard)",
    },
    "nl": {
        "Documentation": "Documentatie",
        FORMATTING: "Plaatsing van lege regels, afsluitende komma's en de stijl van literals en commentaar. Kan veel meldingen geven — veel bestanden hebben mogelijk aanpassingen nodig.",
        "PR": "PR",
        # "Type" would match English exactly and fail the parity check; "Soort" is the Dutch label.
        "Type": "Soort",
        "Title": "Titel",
        "Author": "Auteur",
        "More": "Meer",
        "Save": "Opslaan",
        "title": "titel",
        "id": "id",
        " run": " uitvoering",
        "No": "Nee",
        LSP_DESC: "Aparte taalserver — publiceert diagnostiek in het paneel Problemen voor geopende bestanden en werkruimtebestanden. Omschakelen schrijft de instelling saropaLints.lspServer.enabled.",
        "more": "meer",
        PROTECTED: "Kernbronmappen (lib/, lib/src/, bin/) worden nooit aanbevolen voor uitsluiting.",
        OPEN_SIGNALS: "Regex-patronen (toegepast op het hele document, multiline) die aangeven dat het document nog als openstaand werk leest. Ze worden toegepast met de vlag 'm'; een ongeldig patroon wordt overgeslagen.",
        TRIAGE: "Regels gegroepeerd op prioriteit — fouten, volumebanden en stijl. Elke groep toont de **geschatte impact op de score**.\n\nGebruik **Beheer Regelpakketten** om regels en regelpakketten in of uit te schakelen; wijzigingen worden naar YAML geschreven en de analyse wordt opnieuw uitgevoerd.\n\n[Beheer Regelpakketten openen](command:saropaLints.openConfigDashboard)",
        CROSS_FILE: "Voer projectbrede controles uit die analyse per bestand niet kan doen: ongebruikte bestanden, circulaire afhankelijkheden, importstatistieken, feature-afhankelijkheden, dode imports, ongebruikte symbolen, ongebruikte l10n-sleutels, dubbele blokken, snapshot-JSON, grafiekexport en HTML-rapport.\n\n[Ongebruikte bestanden vinden](command:saropaLints.crossFile.unusedFiles) · [Cross-File HTML-rapport genereren](command:saropaLints.crossFile.report)",
    },
    "pl": {
        ENGINE_BODY: "Silnik, który generuje Twoją diagnostykę, nie jest już wtyczką Analyzer Plugin działającą w procesie — to teraz samodzielny serwer LSP, domyślnie włączony w każdym projekcie. To oprogramowanie w wersji beta, a jego działanie wciąż zmienia się między wydaniami. Jeśli reguła, na której polegasz, przestanie się uruchamiać, zacznie działać inaczej albo zniknie szybka poprawka, to najbardziej prawdopodobna przyczyna. Analyzer Plugin nadal istnieje i można go przywrócić jednym kliknięciem.",
        NAV_LINKS: "Routing i obsługa linków głębokich — auto_route, go_router, app_links, url_launcher i webview.",
        TIER_CAP: "Ogranicza, które poziomy działają podczas analizy, niezależnie od tego, które reguły są jawnie włączone. Pozostaw „Brak”, aby użyć ustawienia Tier rozszerzenia.",
        "Count": "Liczba",
        "Review": "Przegląd",
        "Type": "Typ",
        SHED_LEVEL3: "Presja pamięci: wyłączono {count} reguł (wszystkie niepodstawowe poza ERROR)",
        "dev": "dev",
        "Functions": "Funkcje",
        REPORTS_INTRO: "Raporty CLI uruchamiane jednym kliknięciem, które wcześniej wymagały terminala. Każdy przycisk Uruchom pokazuje na żywo wynik narzędzia pod jego kartą i zapisuje kopię w reports/.saropa_lints/reports-tab/.",
        "No": "Nie",
        OPEN_SIGNALS: "Wzorce regex (dopasowywane do całego dokumentu, w trybie wielowierszowym) oznaczające, że dokument nadal opisuje otwartą pracę. Dopasowywane z flagą 'm'; nieprawidłowy wzorzec jest pomijany.",
    },
    "pt": {
        "Line": "Linha",
        WIDGET_STYLE: "Escolhas de widgets Flutter — SizedBox.square, center em vez de align, spacing em vez de SizedBox e evitar shrinkWrap em rolagens. Apenas projetos Flutter.",
        NAV_LINKS: "Roteamento e tratamento de deep links — auto_route, go_router, app_links, url_launcher e webview.",
        "Remove": "Remover",
        "All": "Todos",
        "Issues": "Problemas",
        "PR": "PR",
        "Title": "Título",
        "More": "Mais",
        SAME_AS_TREE: "Mesmo agrupamento da árvore Triage na barra de atividades: filtre Problemas ou desative/ative regras em `analysis_options_custom.yaml`. Grupos grandes podem pedir confirmação.",
        "id": "id",
        "No": "Não",
        "more": "mais",
        "Continue": "Continuar",
        # NLLB appended an invented sentence about a molecule after {error}.
        COULD_NOT_SUPPRESS: "Não foi possível suprimir '{flag}' em {file}: {error}",
    },
    "ru": {
        "Line": "Строка",
        NAV_LINKS: "Маршрутизация и обработка глубоких ссылок — auto_route, go_router, app_links, url_launcher и webview.",
        "PR": "PR",
        "More": "Ещё",
        "Help": "Справка",
        "id": "ID",
        "No": "Нет",
        LSP_DESC: "Отдельный языковой сервер — публикует диагностику на панели «Проблемы» для открытых файлов и файлов рабочей области. Переключение записывает параметр saropaLints.lspServer.enabled.",
        OPEN_SIGNALS: "Шаблоны регулярных выражений (применяются ко всему документу в многострочном режиме), означающие, что документ всё ещё описывает незавершённую работу. Применяются с флагом 'm'; недопустимый шаблон пропускается.",
        TRIAGE: "Правила, сгруппированные по приоритету — ошибки, диапазоны по количеству и стилистические. Для каждой группы показано **расчётное влияние на оценку**.\n\nВ разделе **Управление наборами правил** можно включать и отключать правила и наборы правил; изменения записываются в YAML, и анализ запускается заново.\n\n[Открыть «Управление наборами правил»](command:saropaLints.openConfigDashboard)",
    },
    "sw": {
        # Several Swahili values looped one phrase dozens of times ("kwa kipindi kwa kipindi ...").
        HERO_SUBTITLE: "Toleo hili linabadilisha injini chaguomsingi ya uchunguzi. Soma hili kabla ya kuendelea kufanya kazi — linaathiri kile utakachoona kwenye paneli ya Problems.",
        MONITOR_BODY: "Kiendelezi sasa kinafuatilia RAM ya mfumo, kila seva ya uchambuzi ya Dart, daemon ya Flutter na mchakato wa chinichini — si wake tu. Kiashiria cha Dev Tool Budget kinaonya zana za uundaji zinapozidi sehemu ya RAM inayoweza kusanidiwa, na michakato iliyoachwa na vipindi vilivyoanguka hugunduliwa wakati wa kuanza.",
        "Message": "Ujumbe",
        "Update": "Sasisho",
        "All": "Zote",
        "PR": "PR",
        HEAP_NONE: "Kompyuta yako ina kumbukumbu ya {totalGb}. Seva ya uchambuzi ya Dart haina kikomo cha kumbukumbu, kwa hiyo inaweza kukua hadi kompyuta ipunguze kasi au ianze kutumia swap. Kikomo kinachopendekezwa: {recommendedGb}.",
        "Kill Orphans": "Komesha Michakato Yatima",
        "Errors": "Makosa",
        "Hide": "Ficha",
        "On": "Imewashwa",
        FULL_REPORT: "Hamisha ripoti kamili ya matumizi ya vipengele (kila kifurushi kilichochanganuliwa, kila kipengele kilichotolewa kwenye changelog) kama faili ya HTML/Markdown/JSON na uifungue.",
        "Copy": "Nakili",
        "+example": "+mfano",
        "commands": "amri",
        "id": "id",
        "complex": "changamani",
        "Yes": "Ndiyo",
        PLUGIN_OFF: "Saropa Lints imewashwa, lakini uchunguzi ndani ya kihariri umezimwa: programu-jalizi ya analyzer ilizimwa kutoka kiendelezi hiki na haikurejeshwa, kwa hiyo matatizo huonekana tu baada ya uchanganuzi. Rejesha uchunguzi wa moja kwa moja ndani ya kihariri, au endelea na uchanganuzi wakati wa kuhifadhi pekee?",
        ACCEPTED_ISSUES: "Matokeo yaliyokubaliwa: {stale} yamepitwa na wakati na {invalid} si sahihi, kati ya maingizo {count}. Angalia paneli ya Problems.",
        FAST_DONE: "Uchanganuzi wa haraka umekamilika: faili {files}, matatizo {issues} kwa sekunde {seconds}. Uchanganuzi unaozingatia aina unaweza kupata zaidi, lakini huchukua takriban dakika {minutes} na kumbukumbu ya {memory}.",
        BANNED_USAGE: "Huweka alama kwenye kitambulisho mahususi (jina la function, class au member) popote kinapoonekana katika mradi, pamoja na sababu maalum inayoonyeshwa katika ujumbe wa uchunguzi.",
        OPINIONATED: "Machaguo mbalimbali ya mtindo — majina mafupi, enums kamili, guard clauses, masharti chanya na mengineyo. Sheria nyingi; zinaweza kuleta kelele nyingi.",
        # Tier names stay as the config identifiers users type in analysis_options.yaml.
        RULE_COUNT_STRIP: "Sheria {total} za lint zinakuja na toleo hili (essential {essential} · recommended {recommended} · professional {professional} · comprehensive {comprehensive} · pedantic {pedantic} · {stylistic} za mtindo za hiari)",
        OPEN_SIGNALS: "Mifumo ya regex (inayolinganishwa na hati nzima, kwa mistari mingi) inayoonyesha kuwa hati bado inaeleza kazi ambayo haijakamilika. Inalinganishwa kwa bendera ya 'm'; mfumo usio sahihi unarukwa.",
    },
    "th": {
        NAV_LINKS: "การกำหนดเส้นทางและการจัดการดีปลิงก์ — auto_route, go_router, app_links, url_launcher และ webview",
        "PR": "PR",
        "dev": "dev",
        "id": "ID",
        SETUP_PROMPT: "Saropa Lints ตรวจพบโปรเจกต์ Dart ที่ยังไม่ได้กำหนดค่า saropa_lints ตั้งค่าตอนนี้เพื่อใช้กฎ lint 2350+ ข้อ",
        LANE_LIGHT: "เฉพาะกฎระดับข้อผิดพลาด/คำเตือน ~200 ข้อเท่านั้นที่ทำงานในเอดิเตอร์",
    },
    "tr": {
        "Clear": "Temizle",
        "Count": "Sayı",
        "All": "Tümü",
        "PR": "PR",
        "Info": "Bilgi",
        "Vibrant": "Canlı",
        "id": "id",
        "Frequent": "Sık kullanılan",
        " runs": " çalıştırma",
        "Yes": "Evet",
        "No": "Hayır",
        LSP_DESC: "Ayrı dil sunucusu — açık dosyalar ve çalışma alanı dosyaları için tanılamaları Sorunlar paneline yayınlar. Açıp kapatmak saropaLints.lspServer.enabled ayarını yazar.",
        OPEN_SIGNALS: "Belgenin hâlâ açık bir iş olarak okunduğunu gösteren regex desenleri (tüm belgeye, çok satırlı modda uygulanır). 'm' bayrağıyla eşleştirilir; geçersiz bir desen atlanır.",
    },
    "uk": {
        "None": "Немає",
        "PR": "PR",
        "Later": "Пізніше",
        "More": "Більше",
        "Help": "Довідка",
        "Frequent": "Часті",
        "Yes": "Так",
        "No": "Ні",
        ARCHIVE_GLOB: "Glob-шаблон для каталогу закритих або архівних документів робочої області. Відповідний файл перевіряється на ознаки незавершеної роботи.",
        OPEN_SIGNALS: "Шаблони регулярних виразів (застосовуються до всього документа в багаторядковому режимі), які означають, що документ досі описує незавершену роботу. Застосовуються з прапорцем 'm'; недійсний шаблон пропускається.",
        TRIAGE: "Правила, згруповані за пріоритетом — помилки, діапазони за кількістю та стилістичні. Для кожної групи показано **орієнтовний вплив на оцінку**.\n\nУ розділі **Управління пакетами правил** можна вмикати й вимикати правила та пакети правил; зміни записуються в YAML, і аналіз запускається знову.\n\n[Відкрити «Управління пакетами правил»](command:saropaLints.openConfigDashboard)",
    },
    "ur": {
        "Line": "لائن",
        "Report": "رپورٹ",
        "PR": "PR",
        "Title": "عنوان",
        PLATFORM_UNSUPPORTED: "مشین ہیلتھ اس پلیٹ فارم پر دستیاب نہیں ہے — پروسیس کوئریز Windows، macOS اور Linux کو سپورٹ کرتی ہیں۔",
        "just now": "ابھی",
        "Off": "آف",
        "Own": "اپنا",
        "id": "آئی ڈی",
    },
    "vi": {
        NAV_LINKS: "Định tuyến và xử lý liên kết sâu — auto_route, go_router, app_links, url_launcher và webview.",
        "Count": "Số lượng",
        "Likes": "Lượt thích",
        "All": "Tất cả",
        "PR": "PR",
        "Enable": "Bật",
        "More": "Thêm",
        "Mix": "Cơ cấu",
        "On": "Bật",
        "Copy": "Sao chép",
        "Save": "Lưu",
        "id": "id",
        " run": " lần chạy",
        " runs": " lần chạy",
        "Engine": "Công cụ",
        ANALYZER_REC: "Khuyến nghị: TẮT khi LSP Server đang bật. BẬT lên (với LSP TẮT) nếu một quy tắc ngừng kích hoạt dưới LSP.",
        "Dependency and plugin": "Phụ thuộc và plugin",
    },
    "zh": {
        TRIAGE: "规则按优先级分组 — 错误、数量区间和风格类。每个分组显示**预估分数影响**。\n\n使用**管理规则包**启用或禁用规则和规则包；更改会写入 YAML 并重新运行分析。\n\n[打开管理规则包](command:saropaLints.openConfigDashboard)",
    },
}
