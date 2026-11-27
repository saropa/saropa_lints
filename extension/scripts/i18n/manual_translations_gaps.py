"""Second batch of hand-written translations: single/few-locale gaps from the
2026-11-21 audit (everything not covered by manual_translations.py).

Same contract as manual_translations.py: merged via setdefault, unverified by
native speakers. Keyed locale -> {English source: translation}.
"""

from __future__ import annotations

from typing import Dict

# Repairs for MT prompt leaks, overlong values and looped words live in their own
# module (this one would pass 600 lines); WIDGET_STYLE is shared so the English
# source is spelled once.
from manual_translations_mt_leaks import LEAK_REPAIRS, WIDGET_STYLE
# Invented-sentence and nonsense-label repairs; JSON data, folded in below.
from manual_translations_followups import load as _load_followups  # noqa: E402
from manual_translations_invented import load as _load_invented

# Long English sources are spelled once here and referenced by alias below, so each
# literal lives in one place (and a typo fails the alias lookup, not silently).
_NEWEST = "saropa_lints {newest} needs a newer Dart SDK than this project has ({dart}). Keep ^{chosen}, or upgrade Flutter to use {newest}."
_PLUGIN_ROUTE_PROJECT = "This project uses the plugin route: saropa_lints is set as a plugin in analysis_options.yaml. You get editor diagnostics only. The command line commands (dart run saropa_lints:init, scan, baseline) need saropa_lints in pubspec.yaml."
_PLUGIN_ROUTE_NEEDS = "The plugin route in analysis_options.yaml needs a newer Dart SDK than this project has, so the editor cannot load the plugin."
_WRITES_PKG = "This writes a new Dart package under your workspace (pubspec.yaml, lib/main.dart, README): one custom_lint plugin that registers Saropa and leaves hooks for your own rules.\n\nOnly use this when you ship custom analyzer rules together with Saropa. Normal Saropa-only projects can skip it—the analyzer allows a single plugin entry per context.\n\nNext: pick a workspace-relative folder. If that folder already exists, you are asked before anything is overwritten."
_PARTLY = "Partly off: the analyzer plugin is off in analysis_options.yaml while the setting is on."
_PARTLY_CLICK = _PARTLY + " Click to fix (turns both on)."
_NO_VERSION = "No saropa_lints version can be installed as a dependency because {package} requires an older analyzer. The plugin route still works."
_RW_WORKFLOW = "Reads and writes .github/workflows/saropa-lints.yml in your working tree to enable or disable the bundled GitHub Actions workflow. This reflects the file on your current branch — the default branch's copy is what actually gates pull requests, and the two can drift apart. Toggling never runs or deletes the workflow; you still review and commit the change yourself."
_LSP_FAIL = "LSP Server: failed to start (see the error message and the Saropa Lints LSP output channel)."
_CHECKING = "Checking which saropa_lints version this project can use..."
_COULD_NOT = "Could not check which saropa_lints version this project can use because the Dart tooling did not run ({detail}). Make sure dart or flutter is on your PATH and you are online, then re-check."
_WATCHER = "Files and folders VS Code's file watcher should ignore. Counts come from the workspace hazard scan; use List to see the paths, then exclude them from the warning that scan shows."
_RECOMMENDED = "Recommended: LSP Server ON (default, beta), Scan on Save ON, Live Analysis OFF (LSP already covers live diagnostics; both on may show duplicates), GitHub Actions CI ON only if you want pull requests gated. If a rule stops firing under LSP, turn Live Analysis ON and LSP Server OFF."
_META = "saropa_lints {newest} needs a newer meta package than your Flutter SDK pins ({pin}). Keep ^{chosen}, or upgrade Flutter to use {newest}."
_PATH_WRITTEN = "{path} has been written in your working tree. Nothing runs in CI until it is on {base}. These commands put it on a new branch called {branch} and open a pull request for review — run them yourself, or press the button and Saropa Lints will run exactly these."
_MAJOR = "Saropa Lints {label}: {from} → {to}. This is a major version and may need config changes — see the changelog."
_UNCOMMITTED = "pubspec.yaml already had uncommitted edits of yours. A commit takes whole files, so publishing from here would push those edits too. Commit or stash them, then run the commands above yourself."
_NESTED = "{folders} contains {count} nested Dart package root(s) that git ignores. Each is analyzed as a separate context and can bloat the analysis server's memory."
_THLANE = "Analysis lane set to {lane}. Restarting the Dart analysis server to apply it."
_THFLUTTER = WIDGET_STYLE
_KOSTYLE = "How returns, conditionals, and loops are written — immediate return, for-in, getter vs method, and similar shorthands."
_SWIMPACT = "Identical output to Severity Report — impact_report is the pre-2026-06-05 name, kept only so existing scripts and muscle memory keep working."
_SWREENABLE = "Re-enable this rule — removes the override in analysis_options_custom.yaml. Run analysis again to see the change take effect."
_SWSORTS = "Sorts members, parameters, fields, and map keys for predictable layout. Very noisy on existing code — best on new code or small repos."
_SWCANCEL = "The version change was cancelled. pubspec.yaml and analysis_options.yaml were restored to their previous content."
_SWNOFIRE = "This rule hasn't fired anywhere in your workspace yet, so there's no specific problem or fix to show. Run analysis to see it in context, or check its rule pack below for what it looks for."
_SWDISABLED = "This rule is currently disabled, so it won't appear in analysis results. Re-enable it above and run analysis to see what it catches."
_SWRAM = "Warn when free physical RAM across the whole machine falls below this percentage."
_SWPACK = "When **on** (default), offer once per workspace to enable a semver-gated migration rule pack (e.g. Dio 5.x, Bloc 8.x, Riverpod 2.x/3.x, go_router 6.x) when your resolved `pubspec.lock` version matches the pack's gate but the pack is not enabled. The offer reappears after a `pub upgrade` brings a new pack into range. Turn **off** to silence these upgrade-pack offers."
_SWSCAN = "saropaLints.scanOnSave.enabled has no effect — scan-on-save is controlled entirely by saropaLints.enabled. Remove the unused key from your settings."
_SWLOCAL = "saropa_lints comes from a local path or git source, so the extension shows facts only and changes nothing."
_TREXCL = "Suggest excluding folders that need no analysis (platform folders, build output, docs, worktrees) from dart.analysisExcludedFolders, and flag exclusions that exist only in analysis_options.yaml. Large analyzed file counts slow quick fixes and raise analysis-server memory."

GAPS: Dict[str, Dict[str, str]] = {
    "ar": {
        _MAJOR: "Saropa Lints {label}: {from} → {to}. هذا إصدار رئيسي وقد يتطلب تغييرات في الإعدادات — راجع سجل التغييرات.",
        "Show more": "عرض المزيد",
        _UNCOMMITTED: "يحتوي pubspec.yaml أصلًا على تعديلاتك غير المودَعة. يشمل الإيداع الملفات كاملة، لذا فإن النشر من هنا سيدفع تلك التعديلات أيضًا. أودِعها أو احفظها مؤقتًا (stash) ثم شغّل الأوامر أعلاه بنفسك.",
        _NEWEST: "يحتاج saropa_lints {newest} إلى Dart SDK أحدث مما يملكه هذا المشروع ({dart}). أبقِ على ^{chosen}، أو حدّث Flutter لاستخدام {newest}.",
    },
    "bn": {
        _LSP_FAIL: "LSP সার্ভার: চালু করা যায়নি (ত্রুটির বার্তা এবং Saropa Lints LSP আউটপুট চ্যানেল দেখুন)।",
        _CHECKING: "এই প্রকল্প কোন saropa_lints সংস্করণ ব্যবহার করতে পারে তা যাচাই করা হচ্ছে...",
        _COULD_NOT: "Dart টুলিং চালু না হওয়ায় ({detail}) এই প্রকল্প কোন saropa_lints সংস্করণ ব্যবহার করতে পারে তা যাচাই করা যায়নি। নিশ্চিত করুন dart বা flutter আপনার PATH-এ আছে এবং আপনি অনলাইনে আছেন, তারপর আবার যাচাই করুন।",
        _WATCHER: "VS Code-এর ফাইল ওয়াচারের যে ফাইল ও ফোল্ডার উপেক্ষা করা উচিত। সংখ্যাগুলো ওয়ার্কস্পেস হ্যাজার্ড স্ক্যান থেকে আসে; পথগুলো দেখতে List ব্যবহার করুন, তারপর স্ক্যানের সতর্কতা থেকে সেগুলো বাদ দিন।",
        _RECOMMENDED: "প্রস্তাবিত: LSP Server চালু (ডিফল্ট, বিটা), Scan on Save চালু, Live Analysis বন্ধ (LSP ইতিমধ্যে লাইভ ডায়াগনস্টিক কভার করে; দুটি চালু থাকলে ডুপ্লিকেট দেখা যেতে পারে), পুল রিকোয়েস্ট গেট করতে চাইলেই কেবল GitHub Actions CI চালু। LSP-তে কোনো রুল কাজ না করলে Live Analysis চালু এবং LSP Server বন্ধ করুন।",
        _META: "saropa_lints {newest}-এর জন্য আপনার Flutter SDK যে meta প্যাকেজ পিন করেছে ({pin}) তার চেয়ে নতুন সংস্করণ দরকার। ^{chosen} রাখুন, অথবা {newest} ব্যবহার করতে Flutter আপগ্রেড করুন।",
        _PATH_WRITTEN: "{path} আপনার ওয়ার্কিং ট্রিতে লেখা হয়েছে। এটি {base}-এ না আসা পর্যন্ত CI-তে কিছু চলবে না। এই কমান্ডগুলো এটিকে {branch} নামের নতুন ব্রাঞ্চে রাখে এবং রিভিউয়ের জন্য একটি পুল রিকোয়েস্ট খোলে — নিজে চালান, অথবা বোতামে চাপ দিন, Saropa Lints ঠিক এগুলোই চালাবে।",
        "{pubspec} in pubspec.yaml and {plugin} in analysis_options.yaml": "pubspec.yaml-এ {pubspec} এবং analysis_options.yaml-এ {plugin}",
    },
    "de": {
        "Tier: {tier}": "Stufe: {tier}", "Route": "Route", "Tier": "Stufe",
        "Breaks": "Inkompatibilitäten", "(unnamed folder)": "(unbenannter Ordner)",
        "{total} findings": "{total} Befunde",
        "Saropa Lints: Sync Plugin Version to pubspec.lock": "Saropa Lints: Plugin-Version mit pubspec.lock synchronisieren",
    },
    "es": {"Breaks": "Incompatibles", "No change possible": "No es posible ningún cambio"},
    "fa": {
        _NEWEST: "saropa_lints {newest} به Dart SDK جدیدتری نیاز دارد از آنچه این پروژه دارد ({dart}). ^{chosen} را نگه دارید یا Flutter را برای استفاده از {newest} ارتقا دهید.",
        _NESTED: "{folders} شامل {count} ریشهٔ بستهٔ Dart تودرتو است که git آن‌ها را نادیده می‌گیرد. هر کدام به‌عنوان زمینهٔ جداگانه تحلیل می‌شود و می‌تواند حافظهٔ سرور تحلیل را متورم کند.",
    },
    "fil": {
        "Tier: {tier}": "Antas: {tier}", "Tier": "Antas", "Route": "Ruta",
        "Preview diff": "I-preview ang diff", "Restart {name}": "I-restart ang {name}",
        "Rule pack: {packs}": "Pakete ng rule: {packs}", "Saropa Lints: Off": "Saropa Lints: Naka-off",
        "Saropa Lints: Status Menu": "Saropa Lints: Menu ng Status",
        _WRITES_PKG: "Magsusulat ito ng bagong Dart package sa ilalim ng workspace mo (pubspec.yaml, lib/main.dart, README): isang custom_lint plugin na nagrerehistro sa Saropa at nag-iiwan ng mga hook para sa sarili mong mga rule.\n\nGamitin lang ito kung nagpapadala ka ng mga custom analyzer rule kasama ng Saropa. Puwedeng laktawan ito ng mga karaniwang proyektong Saropa lang—isang plugin entry lang bawat context ang pinapayagan ng analyzer.\n\nSusunod: pumili ng folder na relatibo sa workspace. Kung umiiral na ang folder, tatanungin ka bago may ma-overwrite.",
        "Extension host": "Extension host", "Lint score": "Lint score",
        "Migrate renamed rules": "Ilipat ang mga pinalitang-pangalang rule",
        "Orphaned scan daemons": "Mga naulilang scan daemon", "Overwrite": "I-overwrite",
        "Rule pack: {packs} (+{count} more)": "Pakete ng rule: {packs} (+{count} pa)",
        "Rule rename: {file}": "Pagpapalit ng pangalan ng rule: {file}",
        "Analyzer Exclusions": "Mga Hindi Isasama ng Analyzer", "Apply {gb}": "Ilapat ang {gb}",
        "List": "Ilista", "Master switch: enabling…": "Master switch: ino-on…", "Memory": "Memorya",
        "Migrate": "Ilipat", "Plugin version out of sync": "Hindi tugma ang bersyon ng plugin",
        "RSS trend (last ~30 min)": "Trend ng RSS (huling ~30 min)",
        "Saropa Lints: Migrate Renamed Rules": "Saropa Lints: Ilipat ang mga Pinalitang-Pangalang Rule",
    },
    "fr": {"Route": "Route", "breaks": "ruptures", "{name} ({constraint}) via {chain}": "{name} ({constraint}) via {chain}", "{total} findings": "{total} résultats"},
    "he": {
        _NO_VERSION: "לא ניתן להתקין אף גרסה של saropa_lints כתלות כי {package} דורשת analyzer ישן יותר. מסלול התוסף (plugin) עדיין עובד.",
        _RW_WORKFLOW: "קורא וכותב את .github/workflows/saropa-lints.yml בעץ העבודה שלך כדי להפעיל או לכבות את תהליך העבודה המצורף של GitHub Actions. זה משקף את הקובץ בענף הנוכחי שלך — העותק בענף ברירת המחדל הוא זה שבפועל חוסם בקשות משיכה, ושניהם עשויים להיפרד. החלפת המצב אף פעם לא מריצה או מוחקת את תהליך העבודה; עדיין עליך לבדוק ולבצע commit לשינוי בעצמך.",
        _NEWEST: "saropa_lints {newest} דורש Dart SDK חדש יותר ממה שיש לפרויקט הזה ({dart}). השאירו ^{chosen}, או שדרגו את Flutter כדי להשתמש ב-{newest}.",
        "saropa_lints {version} requires a newer Dart SDK than {dart}.": "saropa_lints {version} דורש Dart SDK חדש יותר מ-{dart}.",
        "saropa_lints: plugin needs newer Dart": "saropa_lints: התוסף דורש Dart חדש יותר",
        # Hand-written replacements for MT output that leaked Arabic/kana characters and
        # gibberish into Hebrew. Curated entries win over the MT cache, so a later gaps or
        # upgrade run cannot restore the corrupted text. Terms follow the rest of he.json:
        # "ממצאים מתקבלים" (accepted findings), "רשומה" (entry), "עקיפה" (override).
        "Check accepted findings failed: {message}": "בדיקת הממצאים המתקבלים נכשלה: {message}",
        "This file is not inside a Dart package (no pubspec.yaml above it), so it cannot be added to saropa_accepted.yaml.": "הקובץ הזה אינו נמצא בתוך חבילת Dart (אין מעליו pubspec.yaml), ולכן לא ניתן להוסיף אותו ל-saropa_accepted.yaml.",
        "Stale entry: {file} no longer exists, so this entry for {rule} hides nothing.": "רשומה מיושנת: {file} כבר לא קיים, ולכן הרשומה הזו עבור {rule} אינה מסתירה דבר.",
        "Stale entry: {rule} found nothing in {file}. Remove the entry if the code was fixed.": "רשומה מיושנת: {rule} לא מצא דבר ב-{file}. הסר את הרשומה אם הקוד תוקן.",
        "Accepted: the finding is real and the code stays as it is": "מאושר: הממצא אמיתי והקוד נשאר כפי שהוא",
        "Suppress (override is intentional)": "השתק (העקיפה מכוונת)",
        # Multilingual picker label: only "Language" is localized; the other languages'
        # words stay as in the source. MT had appended a stray "השפה / הלשון" tail.
        "Saropa Lints: Language / Langue / Sprache / 言語 / 语言": "Saropa Lints: שפה / Langue / Sprache / 言語 / 语言",
    },
    "hi": {
        _LSP_FAIL: "LSP सर्वर: शुरू नहीं हो सका (त्रुटि संदेश और Saropa Lints LSP आउटपुट चैनल देखें)।",
        "Locked saropa_lints": "लॉक किया गया saropa_lints",
        _PARTLY: "आंशिक रूप से बंद: सेटिंग चालू है जबकि analysis_options.yaml में analyzer प्लगइन बंद है।",
        _PARTLY_CLICK: "आंशिक रूप से बंद: सेटिंग चालू है जबकि analysis_options.yaml में analyzer प्लगइन बंद है। ठीक करने के लिए क्लिक करें (दोनों चालू हो जाएँगे)।",
        _PLUGIN_ROUTE_PROJECT: "यह प्रोजेक्ट प्लगइन रूट का उपयोग करता है: saropa_lints को analysis_options.yaml में प्लगइन के रूप में सेट किया गया है। आपको केवल एडिटर डायग्नोस्टिक्स मिलते हैं। कमांड-लाइन कमांड (dart run saropa_lints:init, scan, baseline) के लिए pubspec.yaml में saropa_lints होना ज़रूरी है।",
    },
    "id": {
        "Tier: {tier}": "Tingkat: {tier}", "Tier": "Tingkat", "breaks": "perubahan yang merusak",
        "{name} ({constraint}) via {chain}": "{name} ({constraint}) melalui {chain}",
        _NEWEST: "saropa_lints {newest} membutuhkan Dart SDK yang lebih baru daripada yang dimiliki proyek ini ({dart}). Pertahankan ^{chosen}, atau tingkatkan Flutter untuk memakai {newest}.",
        "Restart {name}": "Mulai ulang {name}", "Rule pack: {packs}": "Paket aturan: {packs}",
        "Saropa Lints: Status Menu": "Saropa Lints: Menu Status",
        "Locked saropa_lints": "saropa_lints terkunci", "Overwrite": "Timpa", "Repository": "Repositori",
        "Rule rename: {file}": "Penggantian nama aturan: {file}",
        _PLUGIN_ROUTE_PROJECT: "Proyek ini memakai jalur plugin: saropa_lints diatur sebagai plugin di analysis_options.yaml. Anda hanya mendapat diagnostik editor. Perintah baris perintah (dart run saropa_lints:init, scan, baseline) membutuhkan saropa_lints di pubspec.yaml.",
    },
    "it": {
        "Route": "Percorso", "Breaks": "Incompatibilità", "breaks": "incompatibilità",
        "{name} ({constraint}) via {chain}": "{name} ({constraint}) tramite {chain}",
        "— fix: {version}": "— correzione: {version}",
        "Dependency in pubspec.yaml": "Dipendenza in pubspec.yaml",
        "Migrating renamed rules": "Migrazione delle regole rinominate", "package": "pacchetto",
        "saropa_lints: pubspec {pubspec} + plugin {plugin} (disagree)": "saropa_lints: pubspec {pubspec} + plugin {plugin} (discordanti)",
    },
    "ko": {
        _KOSTYLE: "return, 조건문, 반복문을 작성하는 방식 — 즉시 반환, for-in, getter 대 메서드 및 유사한 축약형.",
        "Saropa Lints: Could not update pubspec.yaml — saropa_lints entry not found.": "Saropa Lints: pubspec.yaml을 업데이트할 수 없습니다 — saropa_lints 항목을 찾을 수 없습니다.",
        "Saropa Lints: Off": "Saropa Lints: 꺼짐", "Saropa Lints: On": "Saropa Lints: 켜짐",
        "dart run saropa_lints:init, scan and baseline need saropa_lints in pubspec.yaml.": "dart run saropa_lints:init, scan, baseline을 사용하려면 pubspec.yaml에 saropa_lints가 있어야 합니다.",
        "none running": "실행 중인 항목 없음",
        "{pubspec} in pubspec.yaml and {plugin} in analysis_options.yaml": "pubspec.yaml의 {pubspec}와 analysis_options.yaml의 {plugin}",
    },
    "nl": {
        "Tier: {tier}": "Niveau: {tier}", "Tier": "Niveau", "Route": "Route", "Breaks": "Breuken", "breaks": "breuken",
        "{name} ({constraint}) via {chain}": "{name} ({constraint}) via {chain}",
        "— fix: {version}": "— oplossing: {version}",
        "Cross-file snapshot failed: {message}": "Snapshot over meerdere bestanden mislukt: {message}",
        "Install route": "Installatieroute", "Kill All {name}": "Alle {name} beëindigen",
        "Lint score": "Lintscore", "Open pull request": "Pull request openen",
        "Saropa Lints: Status Menu": "Saropa Lints: Statusmenu",
        "{name} logo": "Logo van {name}", "{packageName} logo": "Logo van {packageName}",
        "Bulk update failed: {error}": "Bulkupdate mislukt: {error}", "Dependents": "Afhankelijke pakketten",
        "Machine RAM": "Machinegeheugen (RAM)", "Open workflow": "Workflow openen", "Project": "Project",
        "Review workspace issues": "Problemen in werkruimte bekijken",
    },
    "pl": {
        "Restart {name}": "Uruchom ponownie {name}", "Scanning the workspace...": "Skanowanie obszaru roboczego...",
        "Tier": "Poziom", "Tier: {tier}": "Poziom: {tier}", "{count} PRs": "{count} PR-ów",
    },
    "pt": {
        "Tier: {tier}": "Nível: {tier}", "Tier": "Nível",
        "{name} ({constraint}) via {chain}": "{name} ({constraint}) via {chain}",
        _NEWEST: "O saropa_lints {newest} precisa de um Dart SDK mais novo do que o deste projeto ({dart}). Mantenha ^{chosen} ou atualize o Flutter para usar o {newest}.",
        "{count} PRs": "{count} PRs", "Preview diff": "Pré-visualizar diff",
        _PLUGIN_ROUTE_NEEDS: "A rota de plugin em analysis_options.yaml precisa de um Dart SDK mais novo do que o deste projeto, então o editor não consegue carregar o plugin.",
        "— fix: {version}": "— correção: {version}",
    },
    "ru": {"saropa_lints: local source": "saropa_lints: локальный источник", "{count} PRs": "{count} PR"},
    "sw": {
        "Tier: {tier}": "Daraja: {tier}", "Tier": "Daraja", "Route": "Njia", "breaks": "inavunja",
        "{name} ({constraint}) via {chain}": "{name} ({constraint}) kupitia {chain}",
        "{count} PRs": "PR {count}", "Preview diff": "Hakiki diff", "Restart {name}": "Anzisha upya {name}",
        "Rule pack: {packs}": "Kifurushi cha kanuni: {packs}", "Saropa Lints: Off": "Saropa Lints: Imezimwa",
        "saropa_lints: local source": "saropa_lints: chanzo cha ndani",
        "Dependency in pubspec.yaml": "Tegemezi katika pubspec.yaml", "Install route": "Njia ya usakinishaji",
        "Migrate renamed rules": "Hamisha kanuni zilizobadilishwa majina",
        "No change possible": "Hakuna mabadiliko yanayowezekana", "Open pull request": "Fungua pull request",
        "Rule pack: {packs} (+{count} more)": "Kifurushi cha kanuni: {packs} (+{count} zaidi)",
        "Author": "Mwandishi",
        _SWIMPACT: "Matokeo yanayofanana na Severity Report — impact_report ni jina la kabla ya 2026-06-05, linalobaki ili hati zilizopo na mazoea yaendelee kufanya kazi.",
        "No renamed rules need migrating.": "Hakuna kanuni zilizobadilishwa majina zinazohitaji kuhamishwa.",
        _SWREENABLE: "Washa upya kanuni hii — huondoa ubatilishaji katika analysis_options_custom.yaml. Endesha uchanganuzi tena ili kuona mabadiliko yakitekelezwa.",
        _SWSCAN: "saropaLints.scanOnSave.enabled haina athari — uchanganuzi wakati wa kuhifadhi unadhibitiwa kabisa na saropaLints.enabled. Ondoa ufunguo huo usiotumika kwenye mipangilio yako.",
        _SWLOCAL: "saropa_lints inatoka kwenye njia ya ndani au chanzo cha git, kwa hivyo kiendelezi kinaonyesha ukweli tu na hakibadilishi chochote.",
        _SWSORTS: "Hupanga washiriki, vigezo, sehemu, na funguo za ramani kwa mpangilio unaotabirika. Ina kelele nyingi kwenye msimbo uliopo — bora kwa msimbo mpya au hazina ndogo.",
        _SWCANCEL: "Mabadiliko ya toleo yalighairiwa. pubspec.yaml na analysis_options.yaml zilirejeshwa kwenye maudhui yake ya awali.",
        _SWNOFIRE: "Kanuni hii haijawahi kuwaka popote kwenye nafasi yako ya kazi bado, kwa hivyo hakuna tatizo au suluhisho maalum la kuonyesha. Endesha uchanganuzi kuiona katika muktadha, au angalia kifurushi chake cha kanuni hapa chini kuona inachotafuta.",
        _SWDISABLED: "Kanuni hii imezimwa sasa, kwa hivyo haitaonekana kwenye matokeo ya uchanganuzi. Iwashe tena hapo juu na uendeshe uchanganuzi kuona inachokamata.",
        "Type": "Aina",
        _SWRAM: "Onya wakati RAM halisi iliyo huru kwenye mashine nzima inaposhuka chini ya asilimia hii.",
        _SWPACK: "Ikiwa **imewashwa** (chaguo-msingi), hutoa ofa mara moja kwa kila nafasi ya kazi ya kuwasha kifurushi cha kanuni za uhamishaji kinachodhibitiwa na semver (k.m. Dio 5.x, Bloc 8.x, Riverpod 2.x/3.x, go_router 6.x) wakati toleo lako la `pubspec.lock` linalingana na kigezo cha kifurushi lakini kifurushi hakijawashwa. Ofa huonekana tena baada ya `pub upgrade` kuleta kifurushi kipya kwenye masafa. **Zima** ili kunyamazisha ofa hizi za vifurushi vya kuboresha.",
        "— (unverified)": "— (haijathibitishwa)",
        _WRITES_PKG: "Hii huandika kifurushi kipya cha Dart ndani ya nafasi yako ya kazi (pubspec.yaml, lib/main.dart, README): programu-jalizi moja ya custom_lint inayosajili Saropa na kuacha vishikio kwa kanuni zako mwenyewe.\n\nItumie tu unaposafirisha kanuni maalum za analyzer pamoja na Saropa. Miradi ya kawaida ya Saropa pekee inaweza kuruka hatua hii—analyzer inaruhusu ingizo moja la programu-jalizi kwa kila muktadha.\n\nInayofuata: chagua folda iliyo jamaa na nafasi ya kazi. Folda hiyo ikiwepo tayari, utaulizwa kabla ya chochote kuandikwa juu yake.",
    },
    "th": {
        _THLANE: "ตั้งเลนการวิเคราะห์เป็น {lane} แล้ว กำลังรีสตาร์ตเซิร์ฟเวอร์วิเคราะห์ Dart เพื่อใช้ค่านี้",
        _THFLUTTER: "ตัวเลือกวิดเจ็ตของ Flutter — SizedBox.square, center แทน align, spacing แทน SizedBox และหลีกเลี่ยง shrinkWrap ในรายการเลื่อน สำหรับโปรเจกต์ Flutter เท่านั้น",
    },
    "tr": {
        "breaks": "uyumsuzluklar", "{name} ({constraint}) via {chain}": "{name} ({constraint}) — {chain} üzerinden",
        "Cross-file snapshot failed: {message}": "Dosyalar arası anlık görüntü başarısız: {message}",
        "Kill All {name}": "Tüm {name} süreçlerini sonlandır", "Orphaned scan daemons": "Sahipsiz tarama arka plan süreçleri",
        _TREXCL: "Analiz gerektirmeyen klasörlerin (platform klasörleri, derleme çıktısı, dokümanlar, worktree'ler) dart.analysisExcludedFolders dışında bırakılmasını önerir ve yalnızca analysis_options.yaml içinde bulunan dışlamaları işaretler. Analiz edilen dosya sayısının fazla olması hızlı düzeltmeleri yavaşlatır ve analiz sunucusunun belleğini artırır.",
        "{pkg} {to} needs {dep} {range}; Flutter pins {dep} {pinned}": "{pkg} {to} için {dep} {range} gerekir; Flutter {dep} {pinned} sürümüne sabitler",
    },
    "uk": {"{count} PRs": "{count} PR"},
    "ur": {
        "Preview diff": "diff کا پیش منظر",
        _PLUGIN_ROUTE_NEEDS: "analysis_options.yaml میں پلگ اِن روٹ کو اس پروجیکٹ کے مقابلے میں نئے Dart SDK کی ضرورت ہے، اس لیے ایڈیٹر پلگ اِن لوڈ نہیں کر سکتا۔",
        _WRITES_PKG: "یہ آپ کے ورک اسپیس کے اندر ایک نیا Dart پیکیج لکھتا ہے (pubspec.yaml، lib/main.dart، README): ایک custom_lint پلگ اِن جو Saropa کو رجسٹر کرتا ہے اور آپ کے اپنے رولز کے لیے ہُکس چھوڑتا ہے۔\n\nاسے صرف تب استعمال کریں جب آپ Saropa کے ساتھ حسبِ ضرورت analyzer رولز شپ کریں۔ عام صرف-Saropa پروجیکٹس اسے چھوڑ سکتے ہیں—analyzer ہر کانٹیکسٹ میں صرف ایک پلگ اِن اندراج کی اجازت دیتا ہے۔\n\nاگلا مرحلہ: ورک اسپیس سے متعلق ایک فولڈر منتخب کریں۔ اگر وہ فولڈر پہلے سے موجود ہو تو کچھ بھی اوور رائٹ ہونے سے پہلے آپ سے پوچھا جائے گا۔",
    },
    "vi": {
        "Tier: {tier}": "Cấp: {tier}", "Tier": "Cấp", "Route": "Lộ trình", "breaks": "thay đổi phá vỡ",
        "saropa_lints: local source": "saropa_lints: nguồn cục bộ", "Extension host": "Máy chủ tiện ích mở rộng",
        "Kill All {name}": "Dừng tất cả {name}", "{name} logo": "Logo {name}", "{packageName} logo": "Logo {packageName}",
    },
}


# ---------------------------------------------------------------------------
# Hand repairs (2026-11-26): values the MT gap-fill left identical to English,
# with damaged tokens (dropped links/code spans, placeholder loops), or with MT
# tails. Written by hand from the English source, no MT engine involved; not
# reviewed by native speakers. Kept apart from GAPS so build() can let them win
# over a GAPS entry for the same source.
# ---------------------------------------------------------------------------
_PLUGIN = "saropa_lints: plugin route {version}"
_BOTH = "saropa_lints: pubspec + plugin {version}"
_PICK = "Saropa Lints: Language / Langue / Sprache / 言語 / 语言"
_PINNED = "When **on**, pubspec validation prefers exact version pins (`1.2.3`) and flags caret ranges (`^1.2.3`). When **off** (default), it prefers caret syntax and flags bare versions — matching `dart pub add` behavior. Only one mode is active at a time."
_TIMEOUT = "How long (in seconds) one scan-on-save run may take before it is abandoned and its `dart` process killed. The default of **180** covers the slowest legitimate run measured for this feature: a full 200-file batch at ~3 files/s plus a cold `dart run` compile. Values below **30** or above **1800** are clamped — a shorter timeout kills healthy first runs, and a longer one reinstates the hang this limit exists to prevent."
_HEALTH = "Your project's quality at a glance: a **0–100 score** in the status bar and Overview view.\n\nGreen (80+), yellow (50–79), red (<50). Errors penalize heavily.\n\n[Run analysis](command:saropaLints.runAnalysis) · [Set up project](command:saropaLints.enable)"
_ISSUES = "Findings in the **Findings Dashboard** editor tab, grouped by severity and file. **Error Lens-style** annotations show warnings at the end of each line.\n\nFilter by text, severity, impact, or rule. Right-click to suppress noise.\n\n[Run Analysis](command:saropaLints.runAnalysis)"
_TRENDS = "**File Risk** ranks files by violation density — riskiest first.\n\nThe Status panel shows score progression over time. Regression alerts and milestone celebrations keep you on track.\n\n[Show Status panel](command:saropaLints.status.focus)"
_TODOS = "Find every `TODO`, `HACK`, and `FIXME` comment across the workspace. Group by tag type or folder, and click to jump to the source.\n\n[Refresh TODOs & Hacks](command:saropaLints.todosAndHacks.refresh)"
_CATALOG = "115+ commands organized by category with search. Find analysis, security, package health, and reporting commands in one place.\n\n[Browse All Commands](command:saropaLints.showCommandCatalog)"
_DROPPED = "Saropa Lints skipped {count} files that were opened by another tool rather than by you. Save a file to scan it."
_CLEAN = "Accepted findings: {count} entries checked, none stale or invalid."


def _pick(word: str) -> str:
    """Language-picker title with only the "Language" slot localized.

    The title is deliberately multilingual so any user can find the picker; MT
    translated or transliterated the other languages' words and appended tails,
    so every repaired locale is built from the same template instead.
    """
    return f"Saropa Lints: {word} / Langue / Sprache / 言語 / 语言"


# Install-route status labels: the owner ruled they get real translations (not
# an allowlist). "pubspec" and "saropa_lints" stay verbatim as file/package
# names; "plugin" uses the word each locale already uses for the analyzer plugin.
_ROUTE_LABELS: Dict[str, tuple] = {
    "ar": ("مسار الإضافة", "pubspec + الإضافة"),
    "bn": ("প্লাগইন রুট", "pubspec + প্লাগইন"),
    "de": ("Plugin-Route", "pubspec + Plugin"),
    "es": ("ruta del plugin", "pubspec y plugin"),
    "fa": ("مسیر پلاگین", "pubspec + پلاگین"),
    "fil": ("ruta ng plugin", "pubspec at plugin"),
    "fr": ("route du plugin", "pubspec et plugin"),
    "he": ("מסלול התוסף", "pubspec + תוסף"),
    "hi": ("प्लगइन रूट", "pubspec + प्लगइन"),
    "id": ("jalur plugin", "pubspec dan plugin"),
    "it": ("route del plugin", "pubspec e plugin"),
    "ja": ("プラグインルート", "pubspec + プラグイン"),
    "ko": ("플러그인 라우트", "pubspec + 플러그인"),
    "nl": ("pluginroute", "pubspec en plugin"),
    "pl": ("ścieżka wtyczki", "pubspec + wtyczka"),
    "pt": ("rota do plugin", "pubspec e plugin"),
    "ru": ("маршрут плагина", "pubspec + плагин"),
    "sw": ("njia ya programu-jalizi", "pubspec + programu-jalizi"),
    "th": ("เส้นทางปลั๊กอิน", "pubspec + ปลั๊กอิน"),
    "tr": ("eklenti yolu", "pubspec + eklenti"),
    "uk": ("маршрут плагіна", "pubspec + плагін"),
    "ur": ("پلگ اِن روٹ", "pubspec + پلگ اِن"),
    "vi": ("lộ trình plugin", "pubspec và plugin"),
    "zh": ("插件路由", "pubspec + 插件"),
}

_REPAIRS: Dict[str, Dict[str, str]] = {
    "ar": {_PICK: _pick("اللغة")},
    "bn": {_PICK: _pick("ভাষা")},
    "es": {_PICK: _pick("Idioma")},
    "fa": {
        # MT dropped every code span; **on**/**off** stay literal as in sibling fa settings.
        _PINNED: "وقتی **on** باشد، اعتبارسنجی pubspec نسخه‌های دقیق ثابت (`1.2.3`) را ترجیح می‌دهد و بازه‌های caret (`^1.2.3`) را علامت‌گذاری می‌کند. وقتی **off** باشد (پیش‌فرض)، نحو caret را ترجیح می‌دهد و نسخه‌های بدون پیشوند را علامت‌گذاری می‌کند — مطابق رفتار `dart pub add`. در هر زمان فقط یک حالت فعال است.",
    },
    "fil": {
        _PICK: _pick("Wika"),
        "❓ Unverified": "❓ Hindi pa na-verify",
        "incomplete data": "kulang na datos",
        # MT lost the `dart` code span and said "fastest" where the source says "slowest".
        _TIMEOUT: "Gaano katagal (sa segundo) maaaring tumakbo ang isang scan-on-save bago ito iwanan at patayin ang proseso nitong `dart`. Ang default na **180** ay sumasaklaw sa pinakamabagal na lehitimong takbo na nasukat para sa feature na ito: isang buong batch na 200 file sa ~3 file/s at isang cold `dart run` compile. Ang mga value na mas mababa sa **30** o mas mataas sa **1800** ay inilalapit sa hangganan — pinapatay ng mas maikling timeout ang malulusog na unang takbo, at ibinabalik naman ng mas mahaba ang pagkabitin na pinipigilan ng limitasyong ito.",
    },
    # fr, ja and zh: the source already names the language in that locale's own
    # word (Langue, 言語, 语言), so the title stays exactly as in English (the key
    # is allowlisted in english_allowed.json, like de).
    "fr": {_PICK: _PICK},
    "ja": {_PICK: _PICK},
    "zh": {
        _PICK: _PICK,
        # MT merged the paragraphs and dropped the command link.
        _ISSUES: "在 **发现仪表板** 编辑器标签页中查看发现的问题，按严重程度和文件分组。**Error Lens 风格** 的注释会在每行末尾显示警告。\n\n按文本、严重程度、影响或规则筛选。右键单击可屏蔽干扰项。\n\n[运行分析](command:saropaLints.runAnalysis)",
        _CATALOG: "115+ 条命令按类别组织并支持搜索。在一处找到分析、安全、包健康和报告命令。\n\n[浏览所有命令](command:saropaLints.showCommandCatalog)",
    },
    "he": {
        # Review of the older accepted-findings strings: MT used "מציאויות", "תוצאות",
        # "painel" and "אור לילך" (lilac light) for the same concepts. Unified on the
        # terms of the earlier repair: "ממצאים מתקבלים", "רשומה", "קבל".
        "Checking accepted findings…": "בודק ממצאים מתקבלים…",
        "The scan output could not be read.": "לא ניתן היה לקרוא את פלט הסריקה.",
        "No Dart/Flutter workspace found. Open a project with pubspec.yaml first.": "לא נמצאה סביבת עבודה של Dart/Flutter. פתח תחילה פרויקט עם pubspec.yaml.",
        "Add saropa_lints to pubspec.yaml before using accepted findings.": "הוסף את saropa_lints ל-pubspec.yaml לפני השימוש בממצאים מתקבלים.",
        "Use the light bulb on a Saropa Lints finding in a Dart file to accept it.": "השתמש בסמל הנורה של ממצא Saropa Lints בקובץ Dart כדי לקבל אותו.",
        "Could not update saropa_accepted.yaml: {message}": "לא ניתן לעדכן את saropa_accepted.yaml: {message}",
        "saropa_accepted.yaml has a layout that cannot be extended automatically. Add the entry by hand.": "המבנה של saropa_accepted.yaml אינו מאפשר הוספה אוטומטית. הוסף את הרשומה ידנית.",
        "saropa_accepted.yaml already has an entry for {rule} in {file}. If the entry has a max count, raise it by hand.": "ב-saropa_accepted.yaml כבר קיימת רשומה עבור {rule} ב-{file}. אם לרשומה יש מספר מרבי (max), הגדל אותו ידנית.",
        "An accepted-findings check is already running.": "בדיקת ממצאים מתקבלים כבר פועלת.",
        'No saropa_accepted.yaml found in any package of the workspace. Use "Accept in this file" on a finding to start one.': 'לא נמצא saropa_accepted.yaml באף חבילה בסביבת העבודה. השתמש ב-"קבל בקובץ זה" על ממצא כדי ליצור קובץ כזה.',
        _CLEAN: "ממצאים מתקבלים: נבדקו {count} רשומות, אף אחת אינה מיושנת או לא תקינה.",
        "Accepted findings: {stale} stale and {invalid} invalid, out of {count} entries. See the Problems panel.": "ממצאים מתקבלים: {stale} מיושנות ו-{invalid} לא תקינות, מתוך {count} רשומות. ראה את חלונית הבעיות (Problems).",
        "Added {rule} in {file} to {list}. Findings already shown clear when the file is analyzed again.": "{rule} ב-{file} נוסף ל-{list}. ממצאים שכבר מוצגים ייעלמו כשהקובץ ינותח שוב.",
        "Open List": "פתח רשימה",
        "Invalid entry, hides nothing: {message}": "רשומה לא תקינה, אינה מסתירה דבר: {message}",
        "Why is this finding accepted?": "מדוע הממצא הזה מתקבל?",
        "False positive: the rule is wrong here": "חיובי שגוי: הכלל שגוי כאן",
        "Reason for accepting {rule} in {file}": "הסיבה לקבלת {rule} ב-{file}",
        "Required. Saved in saropa_accepted.yaml for reviewers.": "חובה. נשמר ב-saropa_accepted.yaml עבור הסוקרים.",
        "Accept {rule} in this file…": "קבל את {rule} בקובץ זה…",
        "{count} accepted": "{count} מתקבלים",
        "Saropa Lints: Check Accepted Findings": "Saropa Lints: בדוק ממצאים מתקבלים",
    },
    "hi": {_PICK: _pick("भाषा")},
    "id": {_PICK: _pick("Bahasa")},
    "ko": {_PICK: _pick("언어")},
    "nl": {_PICK: _pick("Taal")},
    "ru": {
        _PICK: _pick("Язык"),
        # MT kept only the first paragraph and dropped both command links.
        _HEALTH: "Качество вашего проекта с первого взгляда: **оценка 0–100** в строке состояния и в представлении «Обзор».\n\nЗелёный (80+), жёлтый (50–79), красный (<50). Ошибки сильно снижают оценку.\n\n[Запустить анализ](command:saropaLints.runAnalysis) · [Настроить проект](command:saropaLints.enable)",
    },
    "sw": {
        _PICK: _pick("Lugha"),
        "❓ Unverified": "❓ Haijathibitishwa",
        _CLEAN: "Matokeo yaliyokubaliwa: maingizo {count} yamekaguliwa, hakuna lililopitwa na wakati wala lisilo sahihi.",
        # Both walkthrough steps were truncated, gibberish MT with the command link dropped.
        _TRENDS: "**File Risk** hupanga faili kwa msongamano wa ukiukaji — zenye hatari kubwa zaidi kwanza.\n\nPaneli ya Status inaonyesha maendeleo ya alama kwa muda. Arifa za kurudi nyuma na sherehe za hatua muhimu hukusaidia kubaki kwenye mstari.\n\n[Onyesha paneli ya Status](command:saropaLints.status.focus)",
        _TODOS: "Tafuta kila maoni ya `TODO`, `HACK` na `FIXME` katika nafasi nzima ya kazi. Panga kwa aina ya lebo au folda, na ubofye ili kuruka hadi kwenye chanzo.\n\n[Onyesha upya TODOs & Hacks](command:saropaLints.todosAndHacks.refresh)",
    },
    "th": {
        _PICK: _pick("ภาษา"),
        "{count} override(s) could not be verified; the scan was incomplete.": "ไม่สามารถตรวจสอบการแทนที่ {count} รายการได้ เนื่องจากการสแกนไม่สมบูรณ์",
    },
    "tr": {
        _PICK: _pick("Dil"),
        "Suppress (override is intentional)": "Bastır (geçersiz kılma kasıtlı)",
        # MT kept only the first sentence and dropped the command link.
        _TRENDS: "**Dosya Riski** dosyaları ihlal yoğunluğuna göre sıralar — en riskli olanlar önce.\n\nDurum paneli puanın zaman içindeki gelişimini gösterir. Gerileme uyarıları ve dönüm noktası kutlamaları yolunuzdan sapmamanızı sağlar.\n\n[Durum panelini göster](command:saropaLints.status.focus)",
    },
    "ur": {
        _PICK: _pick("زبان"),
        # MT looped "ایک" hundreds of times and appended an English note.
        _DROPPED: "Saropa Lints نے {count} فائلیں چھوڑ دیں جو آپ کے بجائے کسی دوسرے ٹول نے کھولی تھیں۔ کسی فائل کو اسکین کرنے کے لیے اسے محفوظ کریں۔",
        # MT dropped every code span; **آن**/**آف** match sibling ur settings.
        _PINNED: "جب **آن** ہو، تو pubspec کی توثیق عین ورژن پِنز (`1.2.3`) کو ترجیح دیتی ہے اور caret رینجز (`^1.2.3`) کی نشاندہی کرتی ہے۔ جب **آف** ہو (ڈیفالٹ)، تو یہ caret نحو کو ترجیح دیتی ہے اور بغیر سابقے والے ورژنز کی نشاندہی کرتی ہے — `dart pub add` کے رویے کے مطابق۔ ایک وقت میں صرف ایک موڈ فعال ہوتا ہے۔",
    },
    "vi": {_PICK: _pick("Ngôn ngữ")},
}

# Fold the route labels into _REPAIRS so each locale's repairs live in one dict.
for _loc, (_plugin_tr, _both_tr) in _ROUTE_LABELS.items():
    # French keeps its typographic space before the colon, matching the fr
    # "saropa_lints : pubspec {version}" sibling label.
    _sep = " : " if _loc == "fr" else ": "
    _REPAIRS.setdefault(_loc, {}).update({
        _PLUGIN: f"saropa_lints{_sep}{_plugin_tr} {{version}}",
        _BOTH: f"saropa_lints{_sep}{_both_tr} {{version}}",
    })

# Fold the MT-leak repairs in the same way. A source repaired twice would make the
# winner depend on merge order, so an overlap is a hard error, not a silent pick.
for _loc, _entries in LEAK_REPAIRS.items():
    _target = _REPAIRS.setdefault(_loc, {})
    _overlap = sorted(set(_target) & set(_entries))
    if _overlap:
        raise ValueError(f"LEAK_REPAIRS[{_loc!r}] repeats _REPAIRS sources: {_overlap}")
    _target.update(_entries)

# Fold the invented-text and nonsense-label repairs (invented_repairs/*.json) the
# same way and with the same overlap rule: one source, one hand-written value.
for _loc, _entries in _load_invented().items():
    _target = _REPAIRS.setdefault(_loc, {})
    _overlap = sorted(set(_target) & set(_entries))
    if _overlap:
        raise ValueError(f"invented_repairs/{_loc}.json repeats _REPAIRS sources: {_overlap}")
    _target.update(_entries)


# Fold the follow-up repairs (product names, ur letter forms, codicons) with the
# same overlap rule as above.
for _loc, _entries in _load_followups().items():
    _target = _REPAIRS.setdefault(_loc, {})
    _overlap = sorted(set(_target) & set(_entries))
    if _overlap:
        raise ValueError(f"followup_repairs.json repeats _REPAIRS sources: {_overlap}")
    _target.update(_entries)


def build() -> Dict[str, Dict[str, str]]:
    """Return the gap translations (locale -> {source: translation}).

    _REPAIRS overrides GAPS for the same source: a repair replaces a defective
    value, so it must win rather than be dropped by setdefault downstream.
    """
    merged = {loc: dict(entries) for loc, entries in GAPS.items()}
    for loc, entries in _REPAIRS.items():
        merged.setdefault(loc, {}).update(entries)
    return merged
