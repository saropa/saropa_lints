"""Second batch of hand-written translations: single/few-locale gaps from the
2026-11-21 audit (everything not covered by manual_translations.py).

Same contract as manual_translations.py: merged via setdefault, unverified by
native speakers. Keyed locale -> {English source: translation}.
"""

from __future__ import annotations

from typing import Dict

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
_THFLUTTER = "Flutter widget choices — SizedBox.square, center over align, spacing over SizedBox, and avoiding shrinkWrap in scrolls. Flutter projects only."
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
        "Rule pack: {packs}": "Rule pack: {packs}", "Saropa Lints: Off": "Saropa Lints: Naka-off",
        "Saropa Lints: Status Menu": "Saropa Lints: Menu ng Status",
        _WRITES_PKG: "Magsusulat ito ng bagong Dart package sa ilalim ng workspace mo (pubspec.yaml, lib/main.dart, README): isang custom_lint plugin na nagrerehistro sa Saropa at nag-iiwan ng mga hook para sa sarili mong mga rule.\n\nGamitin lang ito kung nagpapadala ka ng mga custom analyzer rule kasama ng Saropa. Puwedeng laktawan ito ng mga karaniwang proyektong Saropa lang—isang plugin entry lang bawat context ang pinapayagan ng analyzer.\n\nSusunod: pumili ng folder na relatibo sa workspace. Kung umiiral na ang folder, tatanungin ka bago may ma-overwrite.",
        "Extension host": "Extension host", "Lint score": "Lint score",
        "Migrate renamed rules": "Ilipat ang mga pinalitang-pangalang rule",
        "Orphaned scan daemons": "Mga naulilang scan daemon", "Overwrite": "I-overwrite",
        "Rule pack: {packs} (+{count} more)": "Rule pack: {packs} (+{count} pa)",
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


def build() -> Dict[str, Dict[str, str]]:
    """Return the gap translations (locale -> {source: translation})."""
    return GAPS
