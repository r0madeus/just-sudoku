# Android: cihazda deneme ve yayın

## Test APK'sını telefona kurmak

1. APK dosyasını telefona aktar (e-posta, Drive, USB…).
2. Dosyaya dokun. Android "bilinmeyen kaynaklardan yükleme" izni isterse, APK'yı açtığın uygulamaya (Dosyalar, Chrome…) bu izni ver.
3. Daha önce farklı bir anahtarla imzalanmış bir sürüm kuruluysa önce onu kaldır.

Test APK'ları bir test anahtarıyla imzalıdır; Play Store'a yüklenemez.

- `JustSudoku-test-release.apk`: yayın modunda derlenmiş sürüm. Hız ve pil gerçek sürüme yakındır.
- `JustSudoku-debug.apk`: hata ayıklama sürümü. Çökme olursa `adb logcat` ile ayrıntılı kayıt verir.

## Cihazda kontrol listesi

Bir sorun görürsen telefonun modelini, Android sürümünü ve ne yaptığında olduğunu not al.

**Açılış ve boyut**
- [ ] Açılışta beyaz/siyah bir parlama olmadan koyu ekrandan menüye geçiliyor.
- [ ] Butonlar parmakla rahat basılıyor; yanlış tuşa basma olmuyor.
- [ ] Yazılar rahat okunuyor (çok küçük ya da çok büyük değil).
- [ ] Tahta ekrana sığıyor; sayı tuşları ve alt çubuk kesilmiyor.

**Ekran kenarları**
- [ ] Üstteki geri butonu, başlık ve saat çentiğin (kamera deliğinin) altında kalmıyor.
- [ ] Alttaki butonlar, hareketle gezinme çubuğuyla çakışmıyor.

**Geri tuşu / geri hareketi**
- [ ] Bir pencere açıkken geri: pencere kapanıyor.
- [ ] Ayarlar, Geçmiş, İstatistikler, Kayıtlı Oyunlar'da geri: menüye dönülüyor.
- [ ] Oyundayken geri: oyundan çıkış (kaydedilerek) menüye.
- [ ] Menüde geri: uygulama kapanıyor.

**Arka plana alma ve kayıt**
- [ ] Oyun ortasında ana ekrana dön, birkaç dakika sonra geri gel: oyun duraklatılmış olarak aynı yerde, süre beklerken işlememiş.
- [ ] Oyun ortasında uygulamayı son uygulamalardan tamamen kapat, yeniden aç: oyun "Devam Et" ile kaldığı yerden sürüyor.
- [ ] Telefon kilitlenip açıldığında oyun bozulmuyor.

**Ses, titreşim, ayarlar**
- [ ] Sesler ve titreşim ayarlardan açılıp kapanıyor ve gerçekten etkili oluyor.
- [ ] Sesler yumuşak ve tıklamasız; hızlı art arda rakam girince sesler gecikmeden üst üste çalıyor; bulmaca bitince çan sesi animasyonu takılmadan çalıyor.
- [ ] Tema ve dil değişince her ekran hemen güncelleniyor.
- [ ] Ayarlar → Yazı Boyutu "Çok Büyük" seçilince yazılar her ekranda büyüyor, hiçbir yazı kesilmiyor ya da üst üste binmiyor.
- [ ] Bulmaca paylaşma / dışa aktarma panoya kopyalıyor, İçe Aktar ile geri açılabiliyor.
- [ ] Ayarlar → Veriler → Yedekle → Dosya olarak kaydet: sistemin dosya seçicisi açılıyor, yedek seçilen klasöre (ör. İndirilenler, Drive) kaydediliyor.
- [ ] Birkaç oyun daha oyna, sonra Geri yükle → Dosya aç ile aynı yedeği seç: geçmiş, istatistikler ve ayarlar yedekteki hâline dönüyor; yarım kalan oyun da.
- [ ] Panoya kopyala / Panodan yapıştır ile de aynısı oluyor.
- [ ] Ana menüde Günün Sudokusu'nun yanındaki takvim düğmesi arşivi açıyor; geçmiş bir güne dokununca o günün bulmacası açılıyor, yarıda bırakılınca takvimde "Başlandı" görünüyor, bitince "Sonradan çözüldü" oluyor ve seri değişmiyor.
- [ ] Oyundayken Duraklat → Ayarlar'dan geri yükleyip geri çıkınca menüye dönülüyor, eski oyun yedeğin üstüne kaydedilmiyor.

**Tablet (varsa)**
- [ ] Tablet yan çevrilince ekran dönüyor, oyun tahtası ve tuşlar yan yana diziliyor.
- [ ] Telefon yan çevrilince ekran dikey kalıyor.

**Akıcılık ve pil**
- [ ] Hücreye dokununca seçim ve rakam anında görünüyor.
- [ ] Geçmiş ve Kayıtlı Oyunlar listeleri akıcı kayıyor.
- [ ] Uygulama açık bekletildiğinde telefon ısınmıyor, pil hızlı düşmüyor.

## Play Store için yayın sürümü

Bu adımlar Android SDK'nın (Android Studio ile gelir) kurulu olduğu bir bilgisayarda yapılır.

1. **Yükleme anahtarı oluştur** (bir kez). Bu dosya ve parolası kaybolursa uygulama güncellenemez; güvenli bir yerde yedekle, asla depoya ekleme (`.gitignore` bunu engelliyor):

   ```
   keytool -genkeypair -v -keystore justsudoku-upload.keystore -alias upload \
     -keyalg RSA -keysize 2048 -validity 10000
   ```

2. **Godot'ya tanıt**: *Proje → Dışa Aktar → Android → Keystore → Release* alanlarına dosya yolu, takma ad (`upload`) ve parola. Parolayı ayarlara kaydetmek istemezsen dışa aktarmadan önce ortam değişkenleri kullanılabilir: `GODOT_ANDROID_KEYSTORE_RELEASE_PATH`, `GODOT_ANDROID_KEYSTORE_RELEASE_USER`, `GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD`.

3. **AAB biçimi**: Play Store APK yerine AAB ister. *Proje → Android Derleme Şablonunu Yükle*, sonra dışa aktarma ayarlarında *Gradle Build → Use Gradle Build* açık ve *Export Format* "Export AAB".

4. **Her yayında** *Version → Code* değerini bir artır (Play aynı kodu ikinci kez kabul etmez); *Version → Name* görünen sürümdür (ör. 0.2.0).

5. **Play Console**: Veri güvenliği formunda uygulama hiçbir veri toplamıyor ve paylaşmıyor (hesap yok, internet izni yok, analiz yok). İçerik derecelendirme anketini doldur.

## Bu sürümdeki Android ayarları

- Paket adı `io.github.r0madeus.justsudoku`; en düşük Android 7.0 (API 24), hedef API 36; yalnızca 64-bit ARM (2019 sonrası telefonların neredeyse tamamı).
- Tek izin titreşim. İnternet izni yok; yedekleme kapalı: oyun verisi cihazdan çıkmaz (GDD §45). Cihaz değiştirirken oyunlar İçe/Dışa Aktar ile taşınır.
- Telefonlarda dikey; tabletlerde (kısa kenar 600 dp ve üstü) ekran dönebilir.
- Uyumluluk (OpenGL ES 3) çizicisi: 2D bir oyun için en geniş cihaz desteği; testler de bu çiziciyle yapılıyor.

## Küçültülmüş motor (daha küçük APK)

Resmi Godot şablonu 3D, fizik, Vulkan ve oyunun kullanmadığı onlarca modülü içerir. `engine/custom.py` yalnızca oyunun kullandıklarıyla derlenmiş bir şablon tanımlar: APK 28,2 MB'tan 14,5 MB'a iner (motor kütüphanesi telefonda 71 MB yerine 31 MB yer kaplar).

- **Hazır APK:** GitHub'da *Actions → Android APK (slim engine)* altındaki son başarılı çalıştırmanın *Artifacts* bölümünden `JustSudoku-slim-apk` indirilir. Bir test anahtarıyla imzalıdır: telefona kurup denemek içindir, Play Store'a yüklenmez.
- **Şablonu kendin derlemek:** Godot 4.7 kaynak kodu, Android NDK (`platform/android/detect.py` içindeki sürüm) ve Java 17 ile:
  ```
  scons platform=android target=template_release arch=arm64 swappy=no profile=<oyun>/engine/custom.py
  cd platform/android/java && ./gradlew generateGodotTemplates
  ```
  Çıkan `bin/android_release.apk` dosyasını *Proje → Dışa Aktar → Android → Custom Template → Release* alanına ver.
- Oyun koduna yeni bir özellik eklerken `tests/test_engine_profile.gd` küçültülmüş motorda olmayan bir şey kullanılırsa uyarır. Godot'nun kullanımdan kaldırılmış (deprecated) işlevleri de bu motorda yoktur.
