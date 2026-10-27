# Changelog

All notable changes to Just Sudoku. Türkçesi aşağıda / Turkish below each version.

## [1.2.1] - 2026-10-27

A steadier toolbar, smoother tabs, and a few touches of motion.

- Fixed: the game's toolbar jumped between labelled buttons (Undo, Redo, Hint) and icons only each time notes were turned on or off on a phone. It now keeps one look.
- Fill notes is a switch: with every empty cell noted it shows as on, and pressing it again takes the notes off (Undo brings them back).
- When all nine of a digit are placed, its cells and its key blink three times, so it is plain that digit is done.
- Tabs (the solution viewer, the difficulty choice) slide a highlight to the chosen one and the content fades in, instead of switching at once.
- Settings: the *Glass effects* switch slides like the others; the drop-downs and the Customize Theme button are one width; the GitHub, pencil and calendar icons are sharper.

**Türkçe**
- Düzeltildi: telefonda notlar açılıp kapanınca oyunun alt çubuğu etiketli (Geri al, Yinele, İpucu) ve yalnızca ikonlu görünüm arasında sıçrıyordu. Artık tek görünümde kalıyor.
- Notları doldur bir anahtar: tüm boş hücrelerde not varken açık görünür, tekrar basınca notları siler (Geri al geri getirir).
- Bir rakamın dokuzu da yerleşince o rakamın hücreleri ve tuşu üç kez yanıp sönüyor; rakamın bittiği belli oluyor.
- Sekmeler (çözüm penceresi, zorluk seçimi) seçilene kayan bir vurgu gösteriyor, içerik yumuşakça beliriyor; artık bir anda değişmiyor.
- Ayarlar: *Cam efektleri* anahtarı diğerleri gibi kayıyor; açılır listeler ve Temayı özelleştir düğmesi aynı genişlikte; GitHub, kalem ve takvim simgeleri daha keskin.

## [1.2.0] - 2026-10-26

Linux, switches that slide, and a safer browser version.

- New: Just Sudoku for Linux, as an AppImage and a tar.gz, built and started by CI on every change.
- Settings: on/off switches that slide instead of check boxes; a *Glass effects* setting (off draws the cards flat, lighter on an older phone); a link to the project page in the corner.
- Browser: back up to a file and restore from one, and a note on first visit that progress stays in the browser.
- Look: round on/off buttons for notes and colours in the game's toolbar, with no stray outline around the pencil; the two cards under the Daily Sudoku line up on a wide window.
- README and store texts: new pictures and a short list of the latest changes.
- The development add-on and some old capture scripts are gone from the project; the game itself is unchanged by that.

**Türkçe**
- Yeni: Linux için Just Sudoku; AppImage ve tar.gz olarak, her değişiklikte CI tarafından derlenip başlatılarak denenir.
- Ayarlar: onay kutuları yerine kayan aç/kapa anahtarları; *Cam efektleri* ayarı (kapalıyken kartlar düz çizilir, eski telefonda daha hafif); köşede proje sayfasına bağlantı.
- Tarayıcı: yedeği dosyaya alma ve dosyadan geri yükleme; ilk açılışta ilerlemenin tarayıcıda saklandığını söyleyen bir not.
- Görünüm: oyun araç çubuğunda notlar ve renkler için yuvarlak aç/kapa düğmeleri, kalemin çevresinde artık kötü çizgi yok; geniş pencerede Günün Sudokusu satırındaki iki kart hizalı.
- README ve mağaza metinleri: yeni görseller ve son değişikliklerin kısa listesi.
- Geliştirme eklentisi ve bazı eski yakalama betikleri projeden çıkarıldı; oyunun kendisi bundan etkilenmez.

## [1.1.0] - 2026-10-26

Plainer wording, and polish for the browser and wide windows.

- Wording: a saved game says how much of it is "complete" (not "filled"), in the resume card and the saved games list. In Turkish "tamamlandı" instead of "dolu" and "İlerleme".
- The Daily Sudoku card is its name alone; the line under it shows only when there is a streak.
- The browser version's loading screen shows the game's name in its own typeface, with the blue square, above a thin progress line, instead of a bare progress bar.
- The solution viewer has one Close button (the X), not two.
- On a wide window a single saved game or history entry spans the width, its buttons at the far edge, instead of sitting in half of it.
- Screenshots in the README and the stores show the new look, including the black AMOLED theme.

**Türkçe**
- Metin: kayıtlı oyun, ne kadarının "tamamlandığını" söylüyor (son oyun kartında ve kayıtlı oyunlar listesinde); "dolu" ve "İlerleme" yerine "tamamlandı".
- Günün Sudokusu kartında yalnızca isim var; altındaki satır sadece seri varken görünüyor.
- Tarayıcı sürümünün yükleme ekranı, çıplak ilerleme çubuğu yerine oyunun adını kendi yazı tipiyle, mavi kareyle ve altında ince bir ilerleme çizgisiyle gösteriyor.
- Çözüm penceresinde iki yerine tek Kapat düğmesi (X) var.
- Geniş pencerede tek başına kalan kayıtlı oyun ya da geçmiş satırı, yarısına sıkışmak yerine tüm genişliği kaplıyor, düğmeleri kartın ucunda.
- README ve mağaza ekran görüntüleri yeni görünümü, siyah AMOLED temasını da, gösteriyor.

## [1.0.3] - 2026-10-26

Digit entry fixed, a truly black AMOLED theme, and the game outside the phone.

- Fixed: on a touch screen a tap on a digit key put the digit in and took it out again, so nothing seemed to happen. A tap is now one press.
- AMOLED is black now: no glow over the page, and the glass cards over it are plain dark surfaces (which also costs less to draw).
- Notes is a pencil icon instead of a word; the filled button shows that notes are on.
- The Colours button says what it is for the first time it is used: cells can be marked with colours, only for you, without changing the puzzle.
- The filled blue buttons no longer have a ring with a speckled fringe around their edge.
- New: the game runs in a browser (it can be installed as an app and works offline), and a Windows version comes with each release.

**Türkçe**
- Düzeltildi: dokunmatik ekranda sayı tuşuna basınca sayı girilip hemen siliniyordu, yani hiçbir şey olmuyor gibiydi. Bir dokunuş artık tek basış.
- AMOLED artık siyah: sayfanın üstünde parıltı yok, üzerindeki cam kartlar düz koyu yüzey (çizmesi de daha ucuz).
- Notlar yazı yerine kalem ikonu; dolu düğme notların açık olduğunu gösteriyor.
- Renkler düğmesi ilk kullanımda ne işe yaradığını anlatıyor: hücreler renklerle işaretlenebilir, sadece senin için, bulmacayı değiştirmez.
- Dolgulu mavi düğmelerin kenarında artık benekli saçaklı halka yok.
- Yeni: oyun tarayıcıda çalışıyor (uygulama olarak yüklenebilir, çevrimdışı da çalışır) ve her sürümle bir Windows sürümü geliyor.

## [1.0.2] - 2026-10-25

More fixes from phones, and a new look for the home screen.

- A new name on the home screen: "Just Sudoku" in DM Serif Display, ending in a small blue square like the lit cell of the icon. The tagline and the rule under it are gone.
- Tapping the last-game card on the home screen grows its board into the game, and leaving the game shrinks it back into the card. The Continue button and the Daily Sudoku keep the slide.
- The home screen no longer looks stretched off the right edge for a moment at start or when coming back to the app.
- Continue lines up with New Game and Saved Games.
- Screens slide in from the side (from the left going back); the small animations on cells, number keys and dialogs are long enough to be seen.
- A Settings row no longer changes when a scroll starts on its text: it toggles when the finger is lifted on it. The check boxes are smaller.
- The icon fits launchers that do not mask it: a rounded tile instead of a hard square.
- If the display changes right after start, Settings shows what the app saw, to report a layout that looks wrong.

**Türkçe**
- Ana ekranda yeni başlık: DM Serif Display ile "Just Sudoku", sonunda simgedeki ışıklı hücre gibi küçük mavi bir kare. Slogan ve altındaki çizgi kalktı.
- Ana ekrandaki son oyun kartına dokununca kartın tahtası oyuna büyüyor; oyundan çıkınca küçülüp karta giriyor. Devam Et ve Günün Sudokusu yandan kaymayı koruyor.
- Ana ekran, açılışta ve uygulamaya dönünce bir an sağa taşmış görünmüyor.
- Devam Et, Yeni Oyun ve Kayıtlı Oyunlar ile aynı hizada.
- Ekranlar yandan kayarak geliyor (geri dönerken soldan); hücre, sayı tuşu ve pencere animasyonları görülecek kadar uzun.
- Ayarlar'da yazısının üstünden başlayan kaydırma artık ayarı değiştirmiyor; parmak satırın üstünde kalkınca değişiyor. Onay kutuları küçüldü.
- Simge, kesmeyen başlatıcılarda keskin kare yerine yuvarlak karo olarak görünüyor.
- Ekran ölçüsü açılıştan hemen sonra değişirse Ayarlar bunu gösteriyor; yanlış görünen bir düzeni bildirmek için.

## [1.0.1] - 2026-10-23

Fixes from the first days on phones.

- Lists scroll like a phone's: the content follows the finger and glides after a flick. A scroll that starts on a checkbox, a dropdown or the game card no longer ticks or opens it.
- Dropdowns open the app's own sheet, with finger-sized rows, instead of a desktop-style menu.
- Language and theme have a System choice, the default, which follows the phone and picks up changes when you come back to the app.
- Faster start: the menu no longer waits for every other screen to load.
- Coming back to the app no longer leaves the menu or the game running off the right edge.
- The pause button no longer shows "play" in a running game after leaving through the pause menu.
- The solution dialog keeps its size between steps and between its two views.
- Settings shows "Language" or "Dil", not both.
- Number pad digits go in as the finger lands.
- A new icon that fits every launcher shape, with a clean themed icon on Android 13+.

**Türkçe**
- Listeler telefondaki gibi kayıyor; onay kutusu, açılır liste ya da kartın üstünden başlayan kaydırma artık onları işaretlemiyor veya açmıyor.
- Açılır listeler uygulamanın kendi penceresinde açılıyor.
- Dil ve temada varsayılan "Sistem" seçeneği: telefonu takip ediyor, uygulamaya dönünce değişikliği alıyor.
- Daha hızlı açılış; uygulamaya dönünce menünün ve oyunun sağa taşması düzeltildi.
- Duraklat simgesi, çözüm penceresinin boyutu ve "Dil" başlığı düzeltildi; sayı tuşları dokunur dokunmaz çalışıyor.
- Her başlatıcı şekline uyan yeni simge.

## [1.0.0] - 2026-10-23

The first release.

**Puzzles**
- Four levels (Easy, Medium, Hard, Expert), rated by the techniques a puzzle needs, from Naked Single to X-Wing, Swordfish, XYZ-Wing, Simple Coloring and XY-Chain. Every puzzle has one solution and can be solved by logic alone, so a hint can always explain the next step.
- New puzzles open at once: Medium, Hard and Expert come from a graded bank, each shown in a new disguise (digits relabelled, rows and columns shuffled) with its difficulty unchanged.
- Daily Sudoku, the same puzzle for everyone each day, with a streak, and a calendar of the last year to play the days you missed. Only days solved on the day count for the streak.
- Replay a past puzzle; share one as a number or an 81-character code, and import others.

**Solving**
- Notes, with Fill notes, automatic note removal and optional smart candidates.
- Pick the cell first or the digit first; drag over several cells to note a digit in all of them; mark cells with nine colours.
- Undo and redo, a number pad that dims impossible digits, clash highlighting, Check, or wrong digits shown right away.
- Three-step hints (where to look, which technique, the move itself) and a step-by-step solution.
- A Techniques guide: every technique explained on a real position, with Show the move and a practice puzzle.

**Progress**
- A score out of 100 for each solve, compared with your best and your average; history, statistics per level and 13 quiet achievements.
- Unfinished games are saved as you play; several can be kept side by side.
- Back up everything (history, statistics, achievements, saved games, settings) to a file or the clipboard, and restore it on another device.

**For everyone**
- Five themes plus your own colours, three typefaces, text size, wrong digits marked by shape as well as colour, WCAG AA contrast in every built-in theme.
- Turkish and English; phone and tablet layouts.
- Quiet sounds made in code: a marimba note for each digit, bells when a row, column or box is done.
- No ads, no account, no internet permission, no data collected.

**Türkçe**
- İlk sürüm. Dört seviye; yalnızca mantıkla çözülebilen, tek çözümlü bulmacalar; Günün Sudokusu, serisi ve bir yıllık arşiv takvimi.
- Önce hücre ya da önce rakam ile giriş, çoklu seçim, hücre renkleri, notlar, geri al/yinele, üç adımlı ipucu, Teknikler rehberi ve alıştırma.
- Puan, geçmiş, istatistikler, 13 başarım; tüm verinin yedeklenip geri yüklenmesi.
- Beş tema ve kendi renklerin, üç yazı tipi, erişilebilirlik ayarları, Türkçe ve İngilizce, sakin sesler.
- Reklam, hesap, internet izni yok; hiçbir veri toplanmıyor.
