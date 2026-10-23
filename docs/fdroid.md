# F-Droid'e başvuru

F-Droid her uygulamayı kaynak koddan kendi sunucusunda derler; hazır ikili dosya kabul etmez. Just Sudoku için bu, Godot'nun hem dışa aktarma şablonunu hem de dışa aktarmayı yapan editörü kaynaktan derlemek demek. Tarif taslağı: [fdroid/io.github.r0madeus.justsudoku.yml](fdroid/io.github.r0madeus.justsudoku.yml).

**Bu tarif bir taslaktır.** F-Droid'in derleme ortamında denenmedi; başvurudan sonra F-Droid gönüllüleri genellikle birkaç düzeltme ister. Godot oyunları F-Droid'de var, ama her biri biraz farklı derleniyor.

## Hazır olanlar

- **Mağaza metinleri ve görseller:** `fastlane/metadata/android/` altında İngilizce (`en-US`) ve Türkçe (`tr-TR`). F-Droid bunları depodan kendisi okur:
  - başlık,
  - kısa ve uzun açıklama,
  - simge,
  - ekran görüntüleri,
  - sürüm notları.
- **Lisans ve kaynak:** GPL-3.0 lisansı, açık kaynak kod.
- **İzinler ve izleme:** İnternet izni yok; reklam, izleme ve kapalı kaynak kütüphane yok. F-Droid'in "anti-feature" listesinde işaretlenecek bir şey olmamalı.
- **Ön koşul:** Sürüm etiketi (`v1.0.0`). Tarif bu etiketi derler, bu yüzden önce [ilk sürüm](release.md) yayınlanmalı.

## Senin yapacakların

1. [gitlab.com](https://gitlab.com) üzerinde bir hesap aç.
2. [fdroiddata](https://gitlab.com/fdroid/fdroiddata) deposunu kendi hesabına çatalla (*Fork*).
3. Çatalında `metadata/io.github.r0madeus.justsudoku.yml` adıyla yeni bir dosya oluştur ve [taslağın](fdroid/io.github.r0madeus.justsudoku.yml) içeriğini yapıştır.
4. Bir *Merge Request* aç. Açıklamaya şunu yazabilirsin:

   > New app: Just Sudoku, a calm offline Sudoku (Godot 4.7, GPL-3.0). The engine's export template and the editor are built from source with the project's slim build profile (engine/custom.py). No internet permission, no ads, no tracking.

5. F-Droid'in otomatik derlemesi (CI) ve gönüllülerin yorumları gelecek. İstenen düzeltmeleri bana getir, birlikte yaparız.

## Dikkat

- **Ayrı imza:** F-Droid sürümü F-Droid'in anahtarıyla imzalanır. GitHub'dan kurulan sürümün üstüne güncellenemez; önce biri kaldırılmalı. Kaldırmadan önce Ayarlar → Veriler → Yedekle ile veriler yedeklenmeli.
- **Sürüm kodu:** Her yeni sürümde `export_presets.cfg` içindeki `version/code` artırılmalı. Tarifteki `UpdateCheckMode: Tags` sayesinde F-Droid yeni etiketleri kendisi bulur.
