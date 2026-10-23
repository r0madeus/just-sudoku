# Just Sudoku

**Sakin, odaklı bir Sudoku: reklam yok, hesap yok, internet yok, hiçbir veri toplanmıyor. Ücretsiz ve açık kaynak.**

[![Tests](https://github.com/r0madeus/just-sudoku/actions/workflows/tests.yml/badge.svg)](https://github.com/r0madeus/just-sudoku/actions/workflows/tests.yml)
[![Android APK](https://github.com/r0madeus/just-sudoku/actions/workflows/android.yml/badge.svg)](https://github.com/r0madeus/just-sudoku/actions/workflows/android.yml)
[![Lisans: GPL v3](https://img.shields.io/badge/lisans-GPLv3-blue.svg)](LICENSE)

[English](README.md)

<p>
  <img src="docs/screenshots/tr_menu.png" width="200" alt="Ana menü">
  <img src="docs/screenshots/tr_game.png" width="200" alt="Notlar ve işaretlenmiş yanlış rakamla süren bir oyun">
  <img src="docs/screenshots/tr_result.png" width="200" alt="Bulmaca çözüldü, yeni başarımlar">
  <img src="docs/screenshots/tr_statistics.png" width="200" alt="İstatistikler">
</p>

## Özellikler

**Bulmacalar**
- Dört seviye (Kolay, Orta, Zor, Uzman). Seviye, bulmacayı çözmek için gereken tekniklere göre belirleniyor: Açık Tekli'den X-Wing, Swordfish, XYZ-Wing, Basit Boyama ve XY-Zinciri'ne kadar. Her bulmacanın tek bir çözümü var ve tahmin gerektirmeden, yalnızca mantıkla çözülebiliyor; bu yüzden ipucu her adımı açıklayabiliyor.
- Yeni bulmaca anında açılıyor. Orta, Zor ve Uzman bulmacalar önceden derecelendirilmiş bir bankadan geliyor; her biri farklı bir kılıkta gösteriliyor (rakamlar yeniden adlandırılıyor, satır ve sütunlar karıştırılıyor), zorluğu ise aynen korunuyor.
- **Günün Sudokusu:** Her gün herkes için aynı bulmaca, seriyle birlikte. Takvimde son bir yılın bulmacaları duruyor: kaçırdığın günleri istediğin zaman oyna (seriye yalnızca gününde çözülenler sayılır).
- Geçmişteki bir bulmacayı yeniden çözebilir, bir sayı ya da 81 karakterlik bir kodla paylaşabilir, başkasınınkini içe aktarabilirsin.

**Çözerken**
- Notlar: *Notları doldur*, notların otomatik silinmesi ve isteğe bağlı akıllı adaylar.
- Geri al ve yinele. Seçili hücreye girmeyen rakamları soluklaştıran tuş takımı. Çakışan rakamların vurgulanması.
- Rakam girme biçimi senin: önce hücreyi ya da önce rakamı seç, birkaç hücrenin üzerinden sürükleyip hepsine aynı anda not al, hücreleri dokuz renkle işaretle.
- Üç adımlı ipucu: önce nereye bakacağın, sonra hangi teknik, en son hamlenin kendisi. Takıldığında adım adım çözüm gösterimi.
- Tahtayı kontrol et ya da yanlış rakamlar girildiği anda gösterilsin.

**İlerleme**
- Her çözüme 100 üzerinden puan (süre, hata, ipucu). Her seviyedeki rekorun ve ortalamanla karşılaştırma.
- Filtrelenebilir geçmiş, seviye bazında istatistikler ve 13 sade başarım.
- Yarım kalan oyunlar sen oynarken kaydediliyor; birden fazla oyun yan yana tutulabiliyor.
- Her şeyi (geçmiş, istatistikler, başarımlar, kayıtlı oyunlar, ayarlar) bir dosyaya ya da panoya yedekleyip yeni telefonunda geri yükleyebilirsin.

**Herkes için**
- Beş tema (Koyu, AMOLED, Açık, Sepya, Orman) ve kendi renklerin; üç yazı tipi.
- **Erişilebilirlik:**
  - Yazı boyutu ayarı.
  - Renk körü oyuncular için yanlış rakamlar renkle birlikte şekille de işaretleniyor.
  - Bütün yerleşik temalarda yazılar WCAG AA kontrast seviyesini karşılıyor.
- Türkçe ve İngilizce.
- Telefon ve tablet düzenleri; yatay tablette yan yana düzenler.

<p>
  <img src="docs/screenshots/tr_game_light.png" width="200" alt="Açık tema">
  <img src="docs/screenshots/tr_settings.png" width="200" alt="Ayarlar">
</p>
<img src="docs/screenshots/tr_tablet_statistics.jpg" width="620" alt="Yatay tablette istatistikler">

## Gizlilik

Just Sudoku titreşim dışında hiçbir izin istemiyor.
- İnternet izni hiç yok; bu yüzden hiçbir yere bir şey gönderemez. Reklam, analiz aracı ya da hesap yok.
- Oyunların, geçmişin ve ayarların cihazında kalıyor; Android yedeklemesi de kapalı.
- Başka bir cihaza geçerken Ayarlar → Veriler'den her şeyi yedekleyip orada geri yüklemen yeterli. Tek bir oyunu da dışa aktarıp içe aktarabilirsin.

## İndirme

Sürüm 0.1.0; henüz bir uygulama mağazasında değil.

- **Test APK'sı (Android 7.0 ve üstü, 64-bit ARM):**
  - [Android APK (slim engine)](https://github.com/r0madeus/just-sudoku/actions/workflows/android.yml) sayfasında son başarılı çalıştırmayı aç.
  - *Artifacts* bölümünden `JustSudoku-slim-apk` dosyasını indir. Bunun için GitHub'a giriş yapmış olman gerekiyor.
  - Test anahtarıyla imzalı: kurup denemek içindir, Play Store'a yüklenemez.
- Telefona kurulumu ve denenecekler listesi: [docs/android.md](docs/android.md).

## Kaynak koddan derleme

1. [Godot 4.7](https://godotengine.org/download/archive/) indir. Standart sürüm yeterli; proje Compatibility çiziciyi kullanıyor.
2. `project.godot` dosyasını Godot'da açıp *Çalıştır*'a bas. Linux, Windows ve macOS'ta da çalışır, geliştirirken işe yarar.
3. Android için *Proje → Dışa Aktar → Android* yolunu izle. Kurulum ve imzalama [docs/android.md](docs/android.md) dosyasında.

Android sürümü, yalnızca oyunun ihtiyaç duyduklarıyla derlenmiş bir Godot şablonu kullanıyor ([engine/custom.py](engine/custom.py)). İçinde 3D, fizik, Vulkan ve kullanılmayan modüller yok; bu sayede APK 28,2 MB'tan 14,5 MB'a iniyor. Şablonu ve APK'yı GitHub otomatik derliyor. Kendin derlemek istersen yol [docs/android.md](docs/android.md#küçültülmüş-motor-daha-küçük-apk) dosyasında.

## Testler

```
GODOT=/godot/yolu tools/run_tests.sh
```

46 test dosyasının hepsini dörder dörder, her birini kendi boş kayıt klasöründe çalıştırıyor (bir dakikadan kısa). Testler her PR'da da çalışıyor.

Ayrıntılar [docs/testing.md](docs/testing.md) dosyasında. Orada `tools/mutation_audit.py` aracı da anlatılıyor: oyunun 36 davranışını tek tek bilerek bozup testlerin bunu yakalayıp yakalamadığını kontrol ediyor. Şu an 36'nın 36'sı yakalanıyor.

## Proje yapısı

| Klasör | İçinde ne var |
|---|---|
| `scripts/core/` | Sudoku'nun kendisi: tahta, çözücü, üretici, zorluk ölçümü |
| `scripts/gameplay/` | Süren oyun: hamleler, ipuçları, geri alma, süre, puan |
| `scripts/data/` | Kayıtlı oyunlar, geçmiş, istatistikler, Günün Sudokusu, başarımlar |
| `scripts/services/` | Tema, yazı tipleri, çeviriler, yerleşim, ses, paylaşım |
| `scenes/` | Ekranlar ve arayüz bileşenleri (kodla kuruluyor) |
| `assets/` | Yazı tipleri, simgeler, uygulama simgesi |
| `tests/` | Test dosyaları |
| `engine/` | Android için küçültülmüş Godot derleme profili |
| `tools/` | Test çalıştırıcı, mutasyon denetimi, README ekran görüntüleri |
| `docs/` | Android, testler ve bu ekran görüntüleri |

Oyun tasarım belgesi `Just Sudoku GDD.md` dosyasında. `addons/godot_mcp/` geliştirme sırasında kullanılan bir editör eklentisi, oyunun parçası değil.

## Katkı

Hata bildirimleri ve PR'lar memnuniyetle karşılanır. Lütfen oyunu oyun yapan şeylere sadık kal: sakin, çevrimdışı, reklamsız ve takipsiz.
- Her değişiklik testleriyle gelsin ve tüm testler geçsin.
- Yeni yazılar hem Türkçe hem İngilizce eklensin.

## Lisans

Just Sudoku, [GNU Genel Kamu Lisansı v3.0](LICENSE) altında özgür yazılımdır.

Kullandıkları:
- [Godot Engine](https://godotengine.org) (MIT)
- [Inter](https://rsms.me/inter/), [Nunito](https://github.com/googlefonts/nunito), [Source Serif 4](https://github.com/adobe-fonts/source-serif) ve [IBM Plex Mono](https://github.com/IBM/plex) yazı tipleri, SIL Open Font License ile ([assets/fonts/licenses](assets/fonts/licenses))
- [Lucide](https://lucide.dev) simgeleri (ISC, [assets/icons/LICENSE-lucide.txt](assets/icons/LICENSE-lucide.txt))
