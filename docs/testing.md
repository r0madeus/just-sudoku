# Testler

## Çalıştırmak

```
GODOT=/godot/yolu tools/run_tests.sh
```

Her `tests/test_*.gd` dosyası dörder dörder, **her biri kendi boş kayıt klasöründe** (`user://`) çalışır. Böylece hiçbir test, başka bir testin ya da önceki bir çalıştırmanın bıraktığı verilere yaslanamaz. Süre ölçen testler (dosyanın başında `## RUN ALONE` satırı olanlar) diğerleri bittikten sonra tek tek çalışır; yanlarında çalışan başka testler ölçümlerini bozmasın diye. Başarısız testlerin kırılan kontrolleri çıktıda listelenir. Tek bir test: `godot --path . -s tests/test_xxx.gd`. Başarısızlıkta çıkış kodu 1'dir.

## Testlerin gerçekten bir şey yakaladığını denetlemek

```
GODOT=/godot/yolu python3 tools/mutation_audit.py          # hepsi (~40 dk)
GODOT=/godot/yolu python3 tools/mutation_audit.py M05 M14  # seçilenler
```

Her "mutasyon", oyunun koduna bilerek küçük bir hata koyar (ör. "hatalar puanı düşürmesin"), tüm testleri çalıştırır ve kodu geri yükler. En az bir test kırılırsa hata **yakalanmıştır**; hiçbiri kırılmazsa o davranışı koruyan test yoktur. Kod değişip bir mutasyonun metni artık bulunamazsa araç bunu `STALE` olarak bildirir; listeyi güncel tutmak gerekir.

Yeni bir özellik ya da hata düzeltmesi testiyle gelir. Testi yazdıktan sonra, koruduğu davranışı bilerek bozup testin kırıldığını görmek, testin işe yaradığının kanıtıdır.

## Son denetim

| | Yakalandı | Kaçtı |
|---|---|---|
| Denetimden önce | 18 / 24 | 6 |
| Denetimden sonra | **25 / 25** | 0 |
| Bulmaca bankası ve çözücü düzeltmeleriyle | 28 / 28 | 0 |
| Giriş modlarıyla (çoklu seçim, önce rakam, renkler) | 32 / 32 | 0 |
| Yedekleme ve geri yüklemeyle | 36 / 36 | 0 |
| Günün Sudokusu arşiviyle | 39 / 39 | 0 |
| Teknikler rehberiyle (örnekler ve alıştırma) | **41 / 41** | 0 |

Kaçanlar: hataların ve hatasız çözümün puana etkisi, duraklatılmış oyunda hamle yapılabilmesi, istatistiklerde en iyi süre, Günün Sudokusu'nun çözülünce işaretlenmesi, ipucunun doğru rakamı koyması. Hepsi `tests/test_rules_and_records.gd` ile korunuyor. Ayrıca:

- Testleri boş kayıt klasörlerinde çalıştırmak **iki gerçek hata** ortaya çıkardı: yeni kurulumda ayarlar kaydedilmiyordu; kayıtlı oyun yokken küçük telefonda Kayıtlı Oyunlar ekranı taşıyordu.
- "Aynı rakamları vurgula" kontrolü, kullandığı bulmacada ilk hücre boş olduğu için hiç çalışmıyordu; artık dolu bir hücre seçiyor.
- Uzman bulmacaların kılık değiştirilmiş hâllerini denetlemek çözücüde iki hata ortaya çıkardı: Swordfish yalnızca satırlarda aranıyordu ve XYZ-Wing aynı iki kanadı kabul edip yanlış eleme yapabiliyordu. İkisi de düzeltildi; M26 ve M27 bunları, M28 ise mantıkla çözülemeyen bir bulmacanın bir seviyeye yerleştirilmemesini koruyor.
- Bulmaca üretim hızı testinin sınırı, bu makinede ölçülen değerin tam üstündeydi ve rastgele kırılıyordu (bir mutasyonu yanlışlıkla "yakalandı" gösterdi). Sınırlar ölçülen değerin ~1,75 katına çekildi: gerçek bir yavaşlamayı yakalar, meşgul bir makineyi değil.
