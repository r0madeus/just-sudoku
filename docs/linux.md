# Linux sürümü

Oyun Linux'ta (64-bit) üç biçimde dağıtılır. Üçü de aynı dışa aktarılmış dosyadan (`JustSudoku.x86_64`, veri içinde) yapılır ve her sürüme [Releases](https://github.com/r0madeus/just-sudoku/releases) sayfasında, SHA-256 özetiyle birlikte eklenir.

| Dosya | Kime | Nasıl |
|---|---|---|
| `JustSudoku-<sürüm>-x86_64.AppImage` | çoğu dağıtımda tek dosya | `chmod +x` yap, çalıştır (FUSE yoksa `APPIMAGE_EXTRACT_AND_RUN=1`) |
| `JustSudoku-<sürüm>-linux-x86_64.tar.gz` | kurulum istemeyenler | aç, `./JustSudoku` |
| `JustSudoku-<sürüm>.flatpak` | Flatpak kullananlar | `flatpak install --user JustSudoku-<sürüm>.flatpak` |

Oyun OpenGL (GL Compatibility) ile çizer, Vulkan gerekmez. Kayıtlar `~/.local/share/godot/app_userdata/Just Sudoku` altında durur (Flatpak'ta uygulamanın kendi izole klasöründe).

## Nasıl yapılıyor

Her şey `.github/workflows/linux.yml` içinde; her pull request'te ve her `v*` etiketinde çalışır.

1. **Dışa aktarma:** Godot düzenleyicisi ve yalnızca 64-bit Linux şablonu indirilir, `Linux` ön ayarıyla dışa aktarılır (`export_presets.cfg`).
2. **Denetim:** `desktop-file-validate` (menü girdisi) ve `appstreamcli validate` (mağaza açıklaması) çalışır.
3. **Başlatma denemesi:** dışa aktarılan oyun sanal ekranda birkaç yüz kare çalışıp kendiliğinden kapanır (`--quit-after`); betik hatası ya da çökme varsa iş kırmızı olur. Aynısı AppImage ve tar.gz için de yapılır.
4. **Paketleme:** `tools/build_linux_packages.sh` tar.gz ve AppImage'ı yapar. AppImage için `appimagetool` (sabitlenmiş sürüm, özeti denetlenerek) indirilip çalıştırılır.
5. **Flatpak:** `packaging/linux/flatpak/io.github.r0madeus.JustSudoku.yml` ile `flatpak-builder` derler, `flatpak build-bundle` paketi yapar; kurulup başlatılması bilgi amaçlı denenir (CI kapsayıcısında Flatpak kum havuzu her zaman ekran alamaz).
6. **Yayın:** etiket gönderildiyse dosyalar o sürüme eklenir.

Paketleme dosyaları `packaging/linux/` altında: `.desktop` (menü girdisi), `.metainfo.xml` (AppStream: mağaza sayfası, ekran görüntüleri, sürüm notları), simgeler. Klasörde `.gdignore` var, yani Godot onları oyunun parçası saymaz.

## Yerelde denemek

```sh
godot --headless --export-release Linux build/linux/JustSudoku.x86_64   # Linux şablonu kurulu olmalı
xvfb-run -a build/linux/JustSudoku.x86_64 --rendering-driver opengl3 --quit-after 300
tools/build_linux_packages.sh build/linux/JustSudoku.x86_64 1.1.0 build/linux-dist --no-appimage
```

`--no-appimage` yalnızca tar.gz yapar; AppImage adımı `appimagetool`'u indirip çalıştırır.

## Her sürümde güncellenecekler

- `packaging/linux/io.github.r0madeus.JustSudoku.metainfo.xml` içindeki `<releases>` listesine yeni sürüm (tarih, kısa not) eklenir. `tests/test_linux_packaging.gd` bunun güncel sürümü içerdiğini ve tarihin CHANGELOG'la aynı olduğunu kontrol eder; eklenmezse test kırılır.

## Flathub'a göndermek

Flatpak paketi yukarıdaki bağımsız `.flatpak` olarak zaten kullanılabilir. [Flathub](https://flathub.org)'da yazılım merkezlerinde görünmesi için ayrıca:

1. Flathub'ın yeni uygulama başvurusu yapılır (`flathub/flathub` deposuna PR; yönergeler: <https://docs.flathub.org/docs/for-app-authors/submission>). Uygulama kimliği `io.github.r0madeus.JustSudoku`, GitHub hesabıyla doğrulanır.
2. Flathub'a gidecek tarif, buradakinden iki yönden ayrılır: oyunu yerel dosyadan değil, sürümün `tar.gz` dosyasından (`type: archive`, `url:` ve `sha256:`) alır; ve inceleyiciler ikili dosyanın kaynaktan derlenmesini isteyebilir. Bu durumda tarif, Godot'un resmi ikili dosyalarını (sabit özetle) indirip oyunu kendisi dışa aktarır. Bu iki değişiklik başvuru sırasında yapılır.
3. İnceleme günler sürebilir ve değişiklik istenebilir; onaylanınca yeni sürümler Flathub'ın kendi deposundaki tarife sürüm/özet güncellenerek yayınlanır.

## Bilinen sınırlar

- Yalnızca x86_64. ARM Linux (ör. Raspberry Pi) için ayrı şablon gerekir.
- Pencere simgesinin görev çubuğunda uygulamayla eşleşmesi masaüstü ortamına bağlı (Wayland'da uygulama kimliği); sorun görülürse başlatıcıdaki `StartupWMClass` ayarlanır.
