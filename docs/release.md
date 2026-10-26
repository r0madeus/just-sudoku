# Sürüm yayınlama

Bir sürüm, `v` ile başlayan bir etiketle (ör. `v1.0.0`) yayınlanır. Etiket GitHub'a gönderilince [Android APK](../.github/workflows/android.yml) iş akışı:

1. Etiketin, `export_presets.cfg` içindeki `version/name` ve `project.godot` içindeki `config/version` ile aynı olduğunu ve `CHANGELOG.md` dosyasında o sürümün bölümü bulunduğunu kontrol eder.
2. APK'yı küçültülmüş motorla derler ve **yayın anahtarıyla** imzalar.
3. [Releases](https://github.com/r0madeus/just-sudoku/releases) sayfasında `JustSudoku-1.0.0.apk`, SHA-256 özeti ve CHANGELOG'daki notlarla bir sürüm açar.

Yayın anahtarı yoksa iş akışı imzasız bir şey yayınlamaz, durur.

Aynı etiket [Windows](../.github/workflows/windows.yml) zip'ini ve [Linux](../.github/workflows/linux.yml) paketlerini (tar.gz ve AppImage; bkz. [linux.md](linux.md)) de sürüme ekler. Linux için sürüm başına tek ek iş: `packaging/linux/*.metainfo.xml` içindeki `<releases>` listesine yeni sürümü yazmak (test, eksikse hatırlatır).

## Bir kez yapılacaklar

### 1. Yayın anahtarını oluştur

Anahtar, uygulamanın kimliğidir: Android bir güncellemeyi yalnızca aynı anahtarla imzalanmışsa kabul eder. **Dosya ya da parolası kaybolursa uygulama bir daha güncellenemez.** İki ayrı yerde yedekle (ör. bir USB bellek ve bir parola yöneticisi). Depoya asla ekleme (`.gitignore` `*.keystore` dosyalarını zaten dışarıda bırakıyor).

Windows'ta (Android Studio'nun getirdiği Java ile), PowerShell'de:

```powershell
& "C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe" -genkeypair -v `
  -keystore just-sudoku-release.keystore -alias release `
  -keyalg RSA -keysize 4096 -validity 10000 -storetype PKCS12 `
  -dname "CN=Just Sudoku"
```

Parola sorulur; anahtar deposu ve anahtar için **aynı parolayı** kullan (Godot tek parola alır).

### 2. Anahtarı GitHub'a gizli değer olarak ekle

Önce dosyayı tek satırlık metne çevir:

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("$PWD\just-sudoku-release.keystore")) | Set-Clipboard
```

Sonra deponun **Settings → Secrets and variables → Actions → New repository secret** sayfasında üç değer ekle:

| Ad | Değer |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | Az önce panoya kopyalanan metin |
| `ANDROID_KEYSTORE_ALIAS` | `release` |
| `ANDROID_KEYSTORE_PASSWORD` | Anahtarın parolası |

Bu değerler yalnızca etiketli sürüm derlemesinde kullanılır; PR'lar ve dallar deneme anahtarıyla derlenmeye devam eder.

## Her sürümde

1. `CHANGELOG.md`: yeni sürümün bölümünü yaz (`## [1.1.0] - 2026-11-20` biçiminde); ilk sürümde `Unreleased` yerine günün tarihini yaz.
2. Sürüm numaraları (üçü aynı olmalı, iş akışı kontrol eder):
   - `project.godot` → `config/version="1.1.0"`
   - `export_presets.cfg` → `version/name="1.1.0"` ve `version/code` **bir artır** (Android ve F-Droid aynı kodu ikinci kez kabul etmez).
3. Mağaza notu: `fastlane/metadata/android/en-US/changelogs/<version/code>.txt` ve `tr-TR/changelogs/<version/code>.txt` (en fazla 500 karakter).
4. Testler yeşilken etiketi gönder:

   ```
   git tag v1.1.0
   git push origin v1.1.0
   ```

5. Actions sekmesinde iş akışının bitmesini bekle (şablon önbellekteyse yaklaşık 10 dakika), sonra Releases sayfasındaki APK'yı telefona kurup dene.

## Uygulama simgesi

Simge tek bir çizimden üretilir: `tools/make_launcher_icons.gd`. Rengini ya da şeklini değiştirmek için o dosyayı düzenleyip çalıştır; uyarlanabilir katmanları (`assets/launcher/`), eski 192 px simgeyi, `icon.svg`'yi ve iki mağaza simgesini (512 px) birlikte yazar:

```
godot --headless --path . -s tools/make_launcher_icons.gd
```

`tests/test_release.gd`, simgenin Android'in 66 dp güvenli dairesinin içinde kaldığını, tema simgesinin dolu bir blok olmadığını ve arka planın kanvasın tamamını kaplayan bir kare değil, yuvarlak köşeli bir karo olduğunu kontrol eder. Bazı başlatıcılar uyarlanabilir simgeyi maskelemeden, 108 dp'lik tüm kanvası kare olarak çiziyor; tam kare bir arka plan orada keskin köşeli bir kareye ve ortasında küçük kalmış bir tahtaya dönüşüyordu.

## İmza parmak izi

Kullanıcıların indirdikleri APK'nın gerçekten bu projeden geldiğini doğrulayabilmesi için ilk sürümden sonra anahtarın SHA-256 parmak izini README'ye ekleyebilirsin:

```powershell
& "C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe" -list -v -keystore just-sudoku-release.keystore -alias release
```

## F-Droid

F-Droid uygulamayı kaynaktan kendisi derler ve kendi anahtarıyla imzalar; bu yüzden F-Droid sürümü ile GitHub sürümü birbirinin üstüne güncellenemez (önce biri kaldırılmalı). Başvuru adımları ve tarif taslağı: [docs/fdroid.md](fdroid.md).
