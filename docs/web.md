# Tarayıcı sürümü

Oyun tarayıcıda oynanır (<https://r0madeus.github.io/just-sudoku/>) ve uygulama gibi kurulup çevrimdışı çalışır. Tek iş parçacıklı dışa aktarılır, yani özel başlık isteyen bir sunucu gerekmez: herhangi bir statik barındırma yeter.

## Küçültülmüş motor

(Dört platformun ortak çerçevesi: [engine.md](engine.md).)

Resmi web şablonunun `index.wasm` dosyası 37,7 MB'tır (gzip'le 9,6 MB); sayfa açılırken ilk indirilen budur. Küçültülmüşünki 23,3 MB, gzip'le 5,8 MB (ölçüm: GitHub'daki ilk çalıştırma; her çalıştırmanın özetinde güncel değerler yazar). Android'deki gibi (bkz. [android.md](android.md#küçültülmüş-motor-daha-küçük-apk)) `engine/custom.py` ile yalnızca oyunun kullandıklarıyla derlenmiş bir şablon kullanılır: 3D, fizik, navigasyon, XR ve kullanılmayan modüller yok.

Her şey `.github/workflows/web.yml` içinde:

1. **Şablon:** Godot 4.7 kaynağı, sabitlenmiş Emscripten (`EMSCRIPTEN_VERSION`, Godot'nun kendi web derlemelerinin sürümü) ve `scons platform=web target=template_release threads=no arch=wasm32 profile=engine/custom.py` ile derlenir. Sonuç, profilin özetine göre önbelleğe alınır: yalnızca `engine/custom.py`, Godot sürümü, Emscripten sürümü ya da `TEMPLATE_REVISION` değişince yeniden derlenir (ilk seferde yirmi dakika kadar sürer).
2. **Karşılaştırma:** oyun önce resmi şablonla (yalnızca ölçmek için), sonra küçültülmüş şablonla dışa aktarılır; çalıştırmanın özetinde iki `index.wasm`'ın boyutu (ham ve gzip) yan yana görünür. Küçültülmüş olan daha küçük değilse iş kırmızı olur.
3. **Başlatma denemesi:** `tools/web_smoke.js` sonucu Chrome'da açar; yükleme ekranı gitmeli, tuval çizilmeli, betik hatası olmamalı. Başlangıç görüntüsü çalıştırmanın *Artifacts* bölümünde (`web-start`).
4. **Yayın:** `main`'e gönderimde sonuç GitHub Pages'e çıkar; aynı derleme itch.io'ya yüklenebilecek bir zip olarak da saklanır.

`export_presets.cfg` içindeki Web ön ayarı resmi şablonu kullanmaya devam eder; yalnızca CI, derleme sırasında ön ayarın `custom_template/release` satırını kendi şablonuna çevirir. Böylece Godot düzenleyicisinde *Run* ya da elle dışa aktarma ek kurulum gerektirmez.

## Kendin denemek

```sh
# Emscripten 4.0.11 kurulu olmalı (emsdk)
git clone --depth 1 --branch 4.7-stable https://github.com/godotengine/godot
cd godot
scons platform=web target=template_release threads=no arch=wasm32 profile=<oyun>/engine/custom.py
# bin/godot.web.template_release.wasm32.nothreads.zip dosyasını Proje → Dışa Aktar → Web → Custom Template → Release alanına ver
```

Sonra `node tools/web_smoke.js build/web` (Playwright ve Chrome gerekir; `PW_EXECUTABLE` ile bir Chromium dosyası da verilebilir) açılışı dener.

## Not

Yeni bir özellik eklerken `tests/test_engine_profile.gd` küçültülmüş motorda olmayan bir sınıf kullanılırsa uyarır. Tarayıcı dosya yedeği `JavaScriptBridge` kullanır; profil JavaScript eval'ı kapatmaz ve test bunu da denetler.
