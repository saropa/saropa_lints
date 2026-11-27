"""Hand-written translations for the "Explain Baseline" command and the
suppression-total line on the Rule Packs strip.

Written by an agent without any MT engine; no native-speaker review. Merged into
dictionaries.py with the same setdefault rule as the other manual modules, so a
regeneration reproduces the shipped values instead of machine-translating them.
"""

from __future__ import annotations

from typing import Dict

# English sources, in the column order of _ROWS. Spelled once here so a typo
# cannot split one source across locales.
_SOURCES = (
    "Total suppressed in export: {total}",
    "Explaining the baseline for {file}…",
    "A baseline report is already running.",
    "Open or select a Dart file to explain its baseline.",
    "No package that depends on saropa_lints was found for this file.",
    "Could not explain the baseline: {message}",
    "Saropa Lints: Explain Baseline for This File",
    "Dart could only be started through the Windows shell here, and this file path contains a character the shell cannot pass safely (% ! \" ^ or a line break). Rename the file or folder, then try again.",
)

# One row per locale, columns in _SOURCES order.
_ROWS: Dict[str, tuple] = {
    "ar": (
        "إجمالي العناصر المكتومة في التصدير: {total}",
        "جارٍ شرح خط الأساس للملف {file}…",
        "تقرير خط الأساس قيد التشغيل بالفعل.",
        "افتح أو حدد ملف Dart لشرح خط الأساس الخاص به.",
        "لم يُعثر لهذا الملف على حزمة تعتمد على saropa_lints.",
        "تعذر شرح خط الأساس: {message}",
        "Saropa Lints: شرح خط الأساس لهذا الملف",
        "تعذر تشغيل Dart هنا إلا عبر واجهة أوامر Windows، ويحتوي مسار هذا الملف على حرف لا يمكن لواجهة الأوامر تمريره بأمان (% ! \" ^ أو فاصل أسطر). أعد تسمية الملف أو المجلد ثم حاول مرة أخرى.",
    ),
    "bn": (
        "এক্সপোর্টে মোট দমন করা: {total}",
        "{file}-এর বেসলাইন ব্যাখ্যা করা হচ্ছে…",
        "একটি বেসলাইন রিপোর্ট ইতিমধ্যেই চলছে।",
        "বেসলাইন ব্যাখ্যা করতে একটি Dart ফাইল খুলুন বা নির্বাচন করুন।",
        "এই ফাইলের জন্য saropa_lints-এর উপর নির্ভরশীল কোনো প্যাকেজ পাওয়া যায়নি।",
        "বেসলাইন ব্যাখ্যা করা যায়নি: {message}",
        "Saropa Lints: এই ফাইলের বেসলাইন ব্যাখ্যা করুন",
        "এখানে Dart শুধু Windows শেলের মাধ্যমে চালু করা যায়, এবং এই ফাইল পাথে এমন একটি অক্ষর আছে যা শেল নিরাপদে পাঠাতে পারে না (% ! \" ^ বা লাইন ব্রেক)। ফাইল বা ফোল্ডারের নাম পরিবর্তন করে আবার চেষ্টা করুন।",
    ),
    "de": (
        "Im Export insgesamt unterdrückt: {total}",
        "Baseline für {file} wird erklärt…",
        "Ein Baseline-Bericht läuft bereits.",
        "Öffnen oder wählen Sie eine Dart-Datei, um ihre Baseline zu erklären.",
        "Für diese Datei wurde kein Paket gefunden, das von saropa_lints abhängt.",
        "Die Baseline konnte nicht erklärt werden: {message}",
        "Saropa Lints: Baseline für diese Datei erklären",
        "Dart konnte hier nur über die Windows-Shell gestartet werden, und dieser Dateipfad enthält ein Zeichen, das die Shell nicht sicher weitergeben kann (% ! \" ^ oder Zeilenumbruch). Benennen Sie die Datei oder den Ordner um und versuchen Sie es erneut.",
    ),
    "es": (
        "Total suprimido en la exportación: {total}",
        "Explicando la línea base de {file}…",
        "Ya se está ejecutando un informe de línea base.",
        "Abra o seleccione un archivo Dart para explicar su línea base.",
        "No se encontró para este archivo ningún paquete que dependa de saropa_lints.",
        "No se pudo explicar la línea base: {message}",
        "Saropa Lints: Explicar la línea base de este archivo",
        "Aquí Dart solo se podía iniciar a través del shell de Windows, y la ruta de este archivo contiene un carácter que el shell no puede transmitir de forma segura (% ! \" ^ o un salto de línea). Cambie el nombre del archivo o la carpeta e inténtelo de nuevo.",
    ),
    "fa": (
        "مجموع موارد سرکوب‌شده در خروجی: {total}",
        "در حال توضیح خط مبنای {file}…",
        "یک گزارش خط مبنا از قبل در حال اجرا است.",
        "برای توضیح خط مبنا، یک فایل Dart را باز یا انتخاب کنید.",
        "برای این فایل هیچ بسته‌ای که به saropa_lints وابسته باشد پیدا نشد.",
        "توضیح خط مبنا ممکن نشد: {message}",
        "Saropa Lints: توضیح خط مبنای این فایل",
        "در اینجا Dart فقط از طریق پوسته Windows قابل اجرا بود و مسیر این فایل نویسه‌ای دارد که پوسته نمی‌تواند آن را با امنیت منتقل کند (% ! \" ^ یا شکست خط). نام فایل یا پوشه را تغییر دهید و دوباره تلاش کنید.",
    ),
    "fil": (
        "Kabuuang na-suppress sa export: {total}",
        "Ipinapaliwanag ang baseline para sa {file}…",
        "May tumatakbo nang ulat ng baseline.",
        "Magbukas o pumili ng Dart file para ipaliwanag ang baseline nito.",
        "Walang nakitang package na umaasa sa saropa_lints para sa file na ito.",
        "Hindi maipaliwanag ang baseline: {message}",
        "Saropa Lints: Ipaliwanag ang Baseline para sa File na Ito",
        "Dito, masisimulan lang ang Dart sa pamamagitan ng Windows shell, at may character ang path ng file na ito na hindi ligtas na maipapasa ng shell (% ! \" ^ o line break). Palitan ang pangalan ng file o folder, pagkatapos ay subukang muli.",
    ),
    "fr": (
        "Total supprimé dans l'export : {total}",
        "Explication de la ligne de base de {file}…",
        "Un rapport de ligne de base est déjà en cours.",
        "Ouvrez ou sélectionnez un fichier Dart pour expliquer sa ligne de base.",
        "Aucun package dépendant de saropa_lints n'a été trouvé pour ce fichier.",
        "Impossible d'expliquer la ligne de base : {message}",
        "Saropa Lints: Expliquer la ligne de base de ce fichier",
        "Ici, Dart ne pouvait être lancé que via le shell Windows, et le chemin de ce fichier contient un caractère que le shell ne peut pas transmettre sans risque (% ! \" ^ ou un saut de ligne). Renommez le fichier ou le dossier, puis réessayez.",
    ),
    "he": (
        "סך הכול מושתקים בייצוא: {total}",
        "מסביר את קו הבסיס עבור {file}…",
        "דוח קו בסיס כבר רץ.",
        "פתחו או בחרו קובץ Dart כדי להסביר את קו הבסיס שלו.",
        "לא נמצאה עבור קובץ זה חבילה התלויה ב-saropa_lints.",
        "לא ניתן להסביר את קו הבסיס: {message}",
        "Saropa Lints: הסבר את קו הבסיס של קובץ זה",
        "כאן ניתן היה להפעיל את Dart רק דרך מעטפת Windows, ונתיב הקובץ מכיל תו שהמעטפת אינה יכולה להעביר בבטחה (% ! \" ^ או מעבר שורה). שנה את שם הקובץ או התיקייה ונסה שוב.",
    ),
    "hi": (
        "एक्सपोर्ट में कुल दबाए गए: {total}",
        "{file} की बेसलाइन समझाई जा रही है…",
        "एक बेसलाइन रिपोर्ट पहले से चल रही है।",
        "बेसलाइन समझने के लिए कोई Dart फ़ाइल खोलें या चुनें।",
        "इस फ़ाइल के लिए saropa_lints पर निर्भर कोई पैकेज नहीं मिला।",
        "बेसलाइन समझाई नहीं जा सकी: {message}",
        "Saropa Lints: इस फ़ाइल की बेसलाइन समझाएँ",
        "यहाँ Dart केवल Windows शेल के ज़रिए शुरू किया जा सकता था, और इस फ़ाइल पथ में ऐसा वर्ण है जिसे शेल सुरक्षित रूप से आगे नहीं भेज सकता (% ! \" ^ या पंक्ति विराम)। फ़ाइल या फ़ोल्डर का नाम बदलें, फिर दोबारा प्रयास करें।",
    ),
    "id": (
        "Total yang disembunyikan dalam ekspor: {total}",
        "Menjelaskan baseline untuk {file}…",
        "Laporan baseline sedang berjalan.",
        "Buka atau pilih file Dart untuk menjelaskan baseline-nya.",
        "Tidak ditemukan paket yang bergantung pada saropa_lints untuk file ini.",
        "Tidak dapat menjelaskan baseline: {message}",
        "Saropa Lints: Jelaskan Baseline untuk File Ini",
        "Di sini Dart hanya dapat dijalankan melalui shell Windows, dan jalur file ini berisi karakter yang tidak dapat diteruskan shell dengan aman (% ! \" ^ atau jeda baris). Ganti nama file atau folder, lalu coba lagi.",
    ),
    "it": (
        "Totale soppressi nell'esportazione: {total}",
        "Spiegazione della baseline di {file}…",
        "Un report della baseline è già in esecuzione.",
        "Apri o seleziona un file Dart per spiegarne la baseline.",
        "Nessun pacchetto che dipende da saropa_lints trovato per questo file.",
        "Impossibile spiegare la baseline: {message}",
        "Saropa Lints: Spiega la baseline di questo file",
        "Qui Dart poteva essere avviato solo tramite la shell di Windows e il percorso di questo file contiene un carattere che la shell non può passare in sicurezza (% ! \" ^ o un'interruzione di riga). Rinomina il file o la cartella, quindi riprova.",
    ),
    "ja": (
        "エクスポート内の抑制の合計: {total}",
        "{file} のベースラインを説明しています…",
        "ベースラインのレポートはすでに実行中です。",
        "ベースラインを説明するには、Dart ファイルを開くか選択してください。",
        "このファイルに対して、saropa_lints に依存するパッケージが見つかりませんでした。",
        "ベースラインを説明できませんでした: {message}",
        "Saropa Lints: このファイルのベースラインを説明",
        "この環境では Dart を Windows シェル経由でしか起動できませんが、このファイルパスにはシェルで安全に渡せない文字（% ! \" ^ または改行）が含まれています。ファイル名またはフォルダー名を変更してから、もう一度お試しください。",
    ),
    "ko": (
        "내보내기에서 억제된 총 수: {total}",
        "{file}의 기준선을 설명하는 중…",
        "기준선 보고서가 이미 실행 중입니다.",
        "기준선 설명을 보려면 Dart 파일을 열거나 선택하세요.",
        "이 파일에 대해 saropa_lints에 의존하는 패키지를 찾지 못했습니다.",
        "기준선을 설명할 수 없습니다: {message}",
        "Saropa Lints: 이 파일의 기준선 설명",
        "이 환경에서는 Windows 셸을 통해서만 Dart를 시작할 수 있는데, 이 파일 경로에 셸이 안전하게 전달할 수 없는 문자(% ! \" ^ 또는 줄 바꿈)가 있습니다. 파일 또는 폴더 이름을 바꾼 후 다시 시도하세요.",
    ),
    "nl": (
        "Totaal onderdrukt in de export: {total}",
        "Baseline voor {file} wordt uitgelegd…",
        "Er wordt al een baselinerapport uitgevoerd.",
        "Open of selecteer een Dart-bestand om de baseline ervan uit te leggen.",
        "Voor dit bestand is geen pakket gevonden dat van saropa_lints afhankelijk is.",
        "Kan de baseline niet uitleggen: {message}",
        "Saropa Lints: Baseline voor dit bestand uitleggen",
        "Dart kon hier alleen via de Windows-shell worden gestart, en dit bestandspad bevat een teken dat de shell niet veilig kan doorgeven (% ! \" ^ of een regeleinde). Wijzig de naam van het bestand of de map en probeer het opnieuw.",
    ),
    "pl": (
        "Łącznie wyciszonych w eksporcie: {total}",
        "Objaśnianie linii bazowej dla {file}…",
        "Raport linii bazowej jest już uruchomiony.",
        "Otwórz lub zaznacz plik Dart, aby objaśnić jego linię bazową.",
        "Nie znaleziono dla tego pliku pakietu zależnego od saropa_lints.",
        "Nie udało się objaśnić linii bazowej: {message}",
        "Saropa Lints: Objaśnij linię bazową tego pliku",
        "Tutaj Dart można było uruchomić tylko przez powłokę systemu Windows, a ścieżka tego pliku zawiera znak, którego powłoka nie może bezpiecznie przekazać (% ! \" ^ lub podział wiersza). Zmień nazwę pliku lub folderu i spróbuj ponownie.",
    ),
    "pt": (
        "Total suprimido na exportação: {total}",
        "Explicando a linha de base de {file}…",
        "Um relatório de linha de base já está em execução.",
        "Abra ou selecione um arquivo Dart para explicar sua linha de base.",
        "Nenhum pacote que dependa de saropa_lints foi encontrado para este arquivo.",
        "Não foi possível explicar a linha de base: {message}",
        "Saropa Lints: Explicar a linha de base deste arquivo",
        "Aqui o Dart só podia ser iniciado pelo shell do Windows, e o caminho deste arquivo contém um caractere que o shell não consegue transmitir com segurança (% ! \" ^ ou uma quebra de linha). Renomeie o arquivo ou a pasta e tente novamente.",
    ),
    "ru": (
        "Всего подавлено в экспорте: {total}",
        "Объяснение базовой линии для {file}…",
        "Отчёт по базовой линии уже выполняется.",
        "Откройте или выберите файл Dart, чтобы объяснить его базовую линию.",
        "Для этого файла не найден пакет, зависящий от saropa_lints.",
        "Не удалось объяснить базовую линию: {message}",
        "Saropa Lints: Объяснить базовую линию этого файла",
        "Здесь Dart можно было запустить только через оболочку Windows, а путь к этому файлу содержит символ, который оболочка не может безопасно передать (% ! \" ^ или перенос строки). Переименуйте файл или папку и повторите попытку.",
    ),
    "sw": (
        "Jumla ya vilivyonyamazishwa katika usafirishaji: {total}",
        "Inaeleza msingi wa {file}…",
        "Ripoti ya msingi tayari inaendeshwa.",
        "Fungua au chagua faili ya Dart ili kueleza msingi wake.",
        "Hakuna kifurushi kinachotegemea saropa_lints kilichopatikana kwa faili hii.",
        "Imeshindwa kueleza msingi: {message}",
        "Saropa Lints: Eleza Msingi wa Faili Hii",
        "Hapa Dart ingeweza kuanzishwa tu kupitia shell ya Windows, na njia ya faili hii ina herufi ambayo shell haiwezi kuipitisha kwa usalama (% ! \" ^ au mkato wa mstari). Badilisha jina la faili au folda, kisha ujaribu tena.",
    ),
    "th": (
        "จำนวนที่ถูกระงับทั้งหมดในการส่งออก: {total}",
        "กำลังอธิบายเบสไลน์ของ {file}…",
        "รายงานเบสไลน์กำลังทำงานอยู่แล้ว",
        "เปิดหรือเลือกไฟล์ Dart เพื่ออธิบายเบสไลน์ของไฟล์",
        "ไม่พบแพ็กเกจที่ใช้ saropa_lints สำหรับไฟล์นี้",
        "อธิบายเบสไลน์ไม่ได้: {message}",
        "Saropa Lints: อธิบายเบสไลน์ของไฟล์นี้",
        "ที่นี่เริ่ม Dart ได้ผ่านเชลล์ของ Windows เท่านั้น และพาธของไฟล์นี้มีอักขระที่เชลล์ส่งต่ออย่างปลอดภัยไม่ได้ (% ! \" ^ หรือการขึ้นบรรทัดใหม่) เปลี่ยนชื่อไฟล์หรือโฟลเดอร์ แล้วลองอีกครั้ง",
    ),
    "tr": (
        "Dışa aktarımda toplam bastırılan: {total}",
        "{file} için temel çizgi açıklanıyor…",
        "Bir temel çizgi raporu zaten çalışıyor.",
        "Temel çizgisini açıklamak için bir Dart dosyası açın veya seçin.",
        "Bu dosya için saropa_lints'e bağımlı bir paket bulunamadı.",
        "Temel çizgi açıklanamadı: {message}",
        "Saropa Lints: Bu Dosyanın Temel Çizgisini Açıkla",
        "Burada Dart yalnızca Windows kabuğu üzerinden başlatılabildi ve bu dosya yolu, kabuğun güvenle aktaramayacağı bir karakter içeriyor (% ! \" ^ veya satır sonu). Dosyayı veya klasörü yeniden adlandırıp tekrar deneyin.",
    ),
    "uk": (
        "Усього приглушено в експорті: {total}",
        "Пояснення базової лінії для {file}…",
        "Звіт щодо базової лінії вже виконується.",
        "Відкрийте або виберіть файл Dart, щоб пояснити його базову лінію.",
        "Для цього файлу не знайдено пакета, що залежить від saropa_lints.",
        "Не вдалося пояснити базову лінію: {message}",
        "Saropa Lints: Пояснити базову лінію цього файлу",
        "Тут Dart можна було запустити лише через оболонку Windows, а шлях до цього файлу містить символ, який оболонка не може безпечно передати (% ! \" ^ або розрив рядка). Перейменуйте файл чи папку та спробуйте ще раз.",
    ),
    "ur": (
        "برآمد میں کل دبائے گئے: {total}",
        "{file} کی بیس لائن کی وضاحت کی جا رہی ہے…",
        "بیس لائن رپورٹ پہلے ہی چل رہی ہے۔",
        "بیس لائن کی وضاحت کے لیے کوئی Dart فائل کھولیں یا منتخب کریں۔",
        "اس فائل کے لیے saropa_lints پر منحصر کوئی پیکیج نہیں ملا۔",
        "بیس لائن کی وضاحت نہیں ہو سکی: {message}",
        "Saropa Lints: اس فائل کی بیس لائن کی وضاحت کریں",
        "یہاں Dart صرف Windows شیل کے ذریعے شروع کیا جا سکتا تھا، اور اس فائل کے پاتھ میں ایسا حرف ہے جسے شیل محفوظ طریقے سے آگے نہیں بھیج سکتا (% ! \" ^ یا لائن بریک)۔ فائل یا فولڈر کا نام بدلیں، پھر دوبارہ کوشش کریں۔",
    ),
    "vi": (
        "Tổng số bị ẩn trong bản xuất: {total}",
        "Đang giải thích đường cơ sở của {file}…",
        "Một báo cáo đường cơ sở đang chạy.",
        "Mở hoặc chọn một tệp Dart để giải thích đường cơ sở của tệp.",
        "Không tìm thấy gói nào phụ thuộc vào saropa_lints cho tệp này.",
        "Không thể giải thích đường cơ sở: {message}",
        "Saropa Lints: Giải thích đường cơ sở của tệp này",
        "Ở đây chỉ có thể khởi chạy Dart qua shell của Windows, và đường dẫn tệp này chứa ký tự mà shell không thể truyền đi an toàn (% ! \" ^ hoặc ngắt dòng). Đổi tên tệp hoặc thư mục rồi thử lại.",
    ),
    "zh": (
        "导出中被抑制的总数：{total}",
        "正在解释 {file} 的基线…",
        "已有基线报告正在运行。",
        "请打开或选择一个 Dart 文件以解释其基线。",
        "未找到适用于此文件且依赖 saropa_lints 的包。",
        "无法解释基线：{message}",
        "Saropa Lints: 解释此文件的基线",
        "此处只能通过 Windows shell 启动 Dart，而此文件路径包含 shell 无法安全传递的字符（% ! \" ^ 或换行符）。请重命名文件或文件夹，然后重试。",
    ),
}


def build() -> Dict[str, Dict[str, str]]:
    """Return the translations as locale -> {English source: translation}."""
    out: Dict[str, Dict[str, str]] = {}
    for locale, row in _ROWS.items():
        # A short row would silently leave the last strings in English.
        if len(row) != len(_SOURCES):
            raise ValueError(f"{locale}: {len(row)} values for {len(_SOURCES)} sources")
        out[locale] = dict(zip(_SOURCES, row))
    return out
