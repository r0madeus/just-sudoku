# Game Design Document

## 1. Proje Özeti

### Çalışma adı

Just Sudoku

Nihai ürün adı daha sonra belirlenecektir.

### Tür

Klasik mantık bulmacası / Sudoku

### Temel platformlar

- Android
    
- PC/Desktop
    

Gelecekte Web, iOS/macOS ve diğer platformlara açılabilecek şekilde tasarlanacaktır.

### Dağıtım modeli

- Tamamen ücretsiz
    
- Açık kaynak
    
- GPLv3
    
- Reklamsız
    
- Hesapsız
    
- Cloud sync olmadan
    
- Analytics/telemetry olmadan
    
- Çevrimdışı
    

### Temel ürün fikri

Uygulama, yalnızca klasik 9×9 Sudoku'ya odaklanan, modern ve premium görünümlü, hafif, hızlı ve tamamen cihaz üzerinde çalışan bir Sudoku deneyimi sunacaktır.

Ürünün temel amacı çok sayıda özellik sunmak değil, Sudoku oynama deneyiminin kendisini mümkün olduğunca kaliteli hale getirmektir.

Uygulama kullanıcıyı zorunlu olarak sisteme bağlamaz, reklam göstermez, kullanıcı verilerini dışarı göndermez ve Sudoku oynamak için internete ihtiyaç duymaz.

---

# 2. Tasarım İlkeleri

Ürünün bütün kararları aşağıdaki temel prensiplere dayanır.

### 2.1 Sudoku önceliklidir

Arayüz ve özellikler Sudoku'nun önüne geçmemelidir.

### 2.2 Sadelik

Ana ekran ve oyun ekranı sade tutulmalıdır. Ayrıntılı özellikler isteyen kullanıcı için mevcut olmalı, ancak temel deneyimi kalabalıklaştırmamalıdır.

### 2.3 Hız

Uygulama açılışı, Sudoku üretimi, oyun kaydetme ve ekran geçişleri mümkün olduğunca anında hissedilmelidir.

### 2.4 Offline-first değil, offline-only

Sudoku oynama değil, mümkün olduğu ölçüde uygulamanın tamamı internetten bağımsız olmalıdır.

### 2.5 Kullanıcı verisinin sahipliği

Oyunlar, istatistikler ve kayıtlar kullanıcının cihazında tutulur. Kullanıcı isterse kayıtlarını dışarı aktarabilir ve başka cihaza aktarabilir.

### 2.6 Platform bağımsızlığı

Android ve PC farklı platformlar olsa da aynı ürünün farklı yüzleri gibi davranmalıdır.

### 2.7 Özelleştirme

Kullanıcı tema, renk, font, animasyon ve bazı oyun yardım özelliklerini kendi tercihine göre değiştirebilmelidir.

---

# 3. Oyunun Kapsamı

Uygulama yalnızca klasik Sudoku destekler.

## Desteklenen puzzle

- 9×9
    
- 9 blok
    
- Her satırda 1–9
    
- Her sütunda 1–9
    
- Her 3×3 blokta 1–9
    
- Her puzzle tek çözüme sahip
    

## Kapsam dışı

- 6×6 Sudoku
    
- 4×4 Sudoku
    
- Killer Sudoku
    
- Diagonal Sudoku
    
- Samurai Sudoku
    
- Diğer Sudoku varyasyonları
    
- Multiplayer
    
- Online leaderboard
    
- Cloud save
    
- XP
    
- Player level
    
- Character/progression sistemi
    

Bu ürün klasik Sudoku konusunda derinleşir; kapsamı farklı puzzle türleriyle genişletmez.

---

# 4. Ana Oyun Döngüsü

Temel kullanıcı akışı:

**Uygulamayı aç → mevcut oyuna devam et veya yeni oyun başlat → difficulty seç → preview → Sudoku oyna → kaydet/devam et → tamamla → sonuç → detaylı rapor veya tekrar oyna**

Kullanıcı isterse tamamlanmış veya eski bir Sudoku'yu tekrar oynayabilir.

---

# 5. Ana Menü

Ana menünün temel seçenekleri:

### Continue

Son aktif oyunu açar.

### New Game

Yeni difficulty seçimi açılır ve yeni Sudoku oluşturulur.

### Load Game

Aktif oyunlar arasından seçim yapılmasını sağlar.

### Daily Sudoku

Günün Medium Sudoku'suna erişim.

### History

Geçmiş oyunları görüntüleme.

### Statistics

Temel ve ayrıntılı performans istatistikleri.

### Settings

Oyun, görünüm, ses, input ve diğer tercihler.

Ana menünün görsel ağırlığı Continue ve New Game üzerinde olacaktır.

---

# 6. Uygulama Açılışı

Varsayılan davranış:

**Son aktif oyunu doğrudan aç.**

Son aktif oyun yoksa ana menü açılır.

Ayarlar üzerinden kullanıcı:

**Open last game automatically**

seçeneğini kapatabilir.

Bu durumda uygulama her açılışta ana menüyü gösterir.

---

# 7. Yeni Oyun

New Game seçildiğinde difficulty tekrar sorulur:

- Easy
    
- Medium
    
- Hard
    
- Expert
    

Mevcut aktif oyun otomatik olarak kaydedilir.

Kullanıcıdan "mevcut oyunu kaydetmek ister misin?" gibi gereksiz bir onay istenmez.

Yeni Sudoku mümkün olduğunca anında oluşturulur.

---

# 8. Puzzle Kimliği ve Seed Sistemi

Her Sudoku deterministic bir seed'e sahip olacaktır.

Örneğin:

**Seed: 8472915632**

Seed kullanıcı tarafından görülebilir ve kopyalanabilir.

Aynı seed:

**aynı algoritma + aynı seed = aynı Sudoku**

sonucunu üretmelidir.

Bu sayede:

- Puzzle paylaşılabilir.
    
- Başka cihazda tekrar oluşturulabilir.
    
- Android ve PC aynı Sudoku'yu oluşturabilir.
    
- Puzzle dosyanın tamamını taşımak yerine seed ile paylaşılabilir.
    
- Daily Sudoku internet olmadan üretilebilir.
    

## Seed'in tekrar kullanımı

Normal **New Game** sistemi daha önce kullanılmış bir seed'i tekrar üretmez.

Buna karşılık:

- Replay
    
- Master it again
    
- Seed import
    
- Daily Sudoku
    

eski puzzle'ların tekrar açılmasına izin verebilir.

Böylece "aynı puzzle'ın yanlışlıkla yeniden üretilmesi" ile "kullanıcının eski puzzle'ı tekrar oynaması" birbirinden ayrılır.

---

# 9. Sudoku Üretimi

Sudoku runtime'da üretilecektir.

Temel üretim mantığı:

1. Geçerli bir tam Sudoku oluştur.
    
2. Sayıları kontrollü biçimde kaldır.
    
3. Her önemli değişiklikten sonra puzzle'ın hâlâ tek çözümlü olup olmadığını kontrol et.
    
4. Difficulty analizini gerçekleştir.
    
5. Validator kontrollerini yap.
    
6. Hedeflenen difficulty aralığındaysa puzzle'ı kabul et.
    
7. Aksi halde üretime devam et.
    

Üretilen puzzle doğrudan kullanıcıya verilmeden önce kalite kontrolden geçer.

## Simetri

Generator özel olarak simetri aramaz.

Bir puzzle doğal olarak simetrik şekilde oluşursa simetrik olarak kalır.

Simetri oluşturmak için ayrıca bir optimizasyon yapılmaz.

---

# 10. Sudoku Solver

Solver, uygulamanın merkezindeki sistemlerden biridir.

Aynı solver aşağıdaki sistemleri besleyecektir:

- Difficulty analizi
    
- Hint
    
- Step-by-step solution
    
- Full solution
    
- Generator kalite kontrolü
    
- Puzzle preview
    
- Puzzle validator
    

## İnsan çözüm teknikleri

Solver aşağıdaki teknik gruplarını destekleyecektir.

### Temel

- Naked Single
    
- Hidden Single
    

### Orta

- Locked Candidates
    
- Naked Pair
    
- Hidden Pair
    
- Naked Triple
    
- Hidden Triple
    

### İleri

- X-Wing
    
- Swordfish
    
- XY-Wing
    
- XYZ-Wing
    
- Simple Coloring
    
- Desteklenen ilgili chain teknikleri
    

Solver gerektiğinde search/backtracking kullanabilir.

Ancak backtracking, puzzle difficulty'sini belirleyen ana ölçüt değildir.

Bir Sudoku'nun bilgisayar tarafından brute force ile çözülebilmesi onu otomatik olarak Expert yapmaz.

---

# 11. Difficulty Sistemi

Kullanıcı yalnızca dört seviye görür:

**Easy**  
**Medium**  
**Hard**  
**Expert**

Bunların arkasında daha hassas bir Difficulty Score bulunacaktır.

## Difficulty Score'u oluşturan faktörler

### Teknik zorluk

Bulmacada gereken tekniklerin seviyesi.

### Çözüm adımı sayısı

Bulmacayı mantıksal olarak tamamlamak için gereken toplam adım.

### Çözüm karmaşıklığı

Adayların durumu, tekniklerin birbirine bağlanması ve çözüm sırasında gereken takip düzeyi.

Bu üç faktör birlikte değerlendirilir.

Başlangıç balancing modeli olarak teknik zorluk en yüksek ağırlığa sahip olacak; adım sayısı ve genel çözüm karmaşıklığı bunu tamamlayacaktır. Gerçek eşikler, çok sayıda oluşturulmuş puzzle üzerinde test edilerek kalibre edilir.

## Easy

Temel teknikler ağırlıklıdır.

Oyuncunun Sudoku mantığının temelini kullanarak çözebileceği bulmacalar.

## Medium

Temel tekniklere ek olarak orta seviyeli teknikler görülür.

Daily Sudoku bu kategoride olacaktır.

## Hard

Daha yoğun aday yönetimi ve orta/ileri teknikler gerektirebilir.

## Expert

Tek bir kategori olarak kalır ancak geniş Difficulty Score aralığı vardır.

Bu nedenle iki Expert Sudoku birbirinin tamamen aynı zorlukta olmak zorunda değildir.

Expert, solver'ın desteklediği ileri tekniklerin kullanılabildiği seviyedir.

---

# 12. Generator Kalite Kontrolü

Her puzzle aşağıdaki kriterlerden geçmelidir:

- Geçerli 9×9 Sudoku olması
    
- Tam olarak tek çözümünün bulunması
    
- Hedef difficulty aralığına girmesi
    
- Beklenen çözüm teknikleriyle çözülebilmesi
    
- Beklenmeyen aşırı teknik gerektirmemesi
    
- Solver tarafından tutarlı şekilde çözülebilmesi
    
- Validator kontrollerinden geçmesi
    

Başarısız puzzle kullanıcıya gösterilmez.

Generator yeni bir puzzle üretir.

---

# 13. Puzzle Preview

Yeni oyun başlamadan önce kısa preview gösterilir.

Örnek:

**Hard**

**Estimated: ~14 min**

**Techniques**

Hidden Pair · Naked Triple · X-Wing

Preview'da yalnızca en çok kullanılan üç teknik gösterilir.

Uzun teknik listeleri gösterilmez.

Tahmini süre:

- Başlangıçta difficulty'ye göre genel tahmin.
    
- Kullanıcının yeterli oyun geçmişi oluşunca kişiselleştirilmiş tahmin.
    

Kişiselleştirme, yeterince veri biriktikten sonra devreye girer; küçük veri setlerinde tahminlerin aşırı dalgalanması engellenir.

---

# 14. Oyun Ekranı

Oyun ekranının ana unsurları:

- Sudoku grid
    
- Timer
    
- Pause
    
- Undo
    
- Redo
    
- Hint
    
- Seed
    
- Numpad / input controls
    

Mobilde numpad ekranın alt bölümünde bulunur.

Desktop'ta grid merkezde, klavye desteği aktif olacak şekilde tasarlanır.

---

# 15. Hücre Seçimi ve Highlight

Bir hücre seçildiğinde:

- Seçili hücre belirgin şekilde vurgulanır.
    
- Aynı satır/sütun/box ilişkileri görsel olarak desteklenebilir.
    
- Grid'deki aynı sayılar da vurgulanır.
    

Aynı sayının bütün örneklerinin vurgulanması oyunun temel görsel davranışlarından biridir.

Highlight sistemi abartılı olmamalıdır; grid'in okunabilirliğini bozmamalıdır.

---

# 16. Mobil Input

Mobil temel model:

**Tap → Smart Numpad**

Oyuncu önce hücreyi seçer.

Ardından numpad üzerinden sayı seçer.

Smart Numpad, seçilen hücreye yerleştirilmesi mümkün olmayan sayıları pasif hale getirir.

Örneğin:

`1 2 3 4 5 6 7 8 9`

arasından yalnızca geçerli adaylar aktif görünür.

Kullanıcı her girişten önce hücreye tekrar dokunabilir.

Otomatik olarak başka hücreye geçilmez.

Bu nedenle kullanıcı istemediği halde grid üzerinde hareket ettirilmez.

---

# 17. Notes Sistemi

İki çalışma modu vardır:

**Number**

**Notes**

Aynı numpad iki modda da kullanılabilir.

Number modunda sayı yerleştirilir.

Notes modunda seçilen hücreye aday eklenir veya çıkarılır.

## Smart Candidates

Seçilen hücre için mümkün olan adaylar gösterilebilir.

Bu sistem kullanıcının manuel olarak yazdığı notlardan ayrı tutulur.

## Auto-remove Notes

Bir sayı yerleştirildiğinde, ilgili hücrelerdeki aynı aday notlarının otomatik silinmesi ayarlanabilir.

Kullanıcı bunu Settings üzerinden açabilir veya kapatabilir.

---

# 18. Hata ve Conflict Sistemi

Conflict ve mistake aynı genel hata sisteminin parçasıdır.

## Conflict

Örneğin aynı satırda iki adet 5 bulunması.

Bu durum anında tespit edilir.

- Görsel olarak kırmızı gösterilir.
    
- Mistake olarak sayılır.
    

## Wrong Value

Bir oyuncu Sudoku'nun gerçek çözümünde 7 olması gereken yere 5 yazdı ancak bu 5 başka hiçbir kuralı ihlal etmiyor.

Bu durum anında kırmızı hata olarak gösterilmez.

Grid tamamlandığında Check kullanılabilir.

## Check

Bütün hücreler doldurulduğunda:

**Check**

butonu ortaya çıkar.

Check:

- Doğru hücreleri değiştirmez.
    
- Yanlış hücreleri kırmızı işaretler.
    
- Yanlış cevapları otomatik düzeltmez.
    

Yanlış cevapların mistake sayılması Check ile gerçekleşir.

Aynı yanlış state tekrar tekrar Check edildiğinde aynı hatanın gereksiz şekilde tekrar sayılması engellenir.

---

# 19. Mistake Ayarı

Hata gösterimi ayarlardan açılıp kapatılabilir.

Bu ayar görsel davranışı değiştirir; oyunun gerçek state'ini bozmaz.

Örneğin kullanıcı hata göstergesini kapatsa bile uygulama doğru/yanlış durumu içsel olarak bilir ve tamamlanma kontrolünde kullanabilir.

Mistake limiti yoktur.

Kaç hata yapılırsa yapılsın oyun devam eder.

---

# 20. Undo / Redo

Undo ve Redo sınırsızdır.

Oyuncu:

- Sayı girişlerini
    
- Not değişikliklerini
    
- Diğer geri alınabilir oyun hareketlerini
    

geri alabilir.

Undo/Redo oyun state'inin bir parçasıdır ve save ile birlikte korunur.

Oyuncu uygulamadan çıkıp daha sonra devam ettiğinde ilgili hareket geçmişi mümkün olduğunca korunur.

---

# 21. Hint Sistemi

Hint rastgele bir hücre seçmez.

Solver'ın mevcut oyun state'i için bulduğu **bir sonraki mantıksal adımı** kullanır.

Örneğin:

`R4C7 = 8`

Hint bunu doğrudan yerleştirir.

Hint kullanılan her oyun:

- hint count
    
- history
    
- statistics
    
- performance score
    

içerisinde takip edilir.

---

# 22. Solution Sistemi

İki çözüm yöntemi vardır.

### Full Solution

Bulmacanın tamamının çözümü gösterilir.

### Step-by-step Solution

Çözüm adımları tek tek izlenebilir.

Her adım:

- Hücre
    
- Değer
    
- Kullanılan teknik
    
- Tekniğin neden işe yaradığı
    

bilgilerini içerebilir.

Örneğin:

**R4C7 → 8**

**Hidden Single**

Ardından ilgili açıklama gösterilebilir.

Oyuncu çözüm adımları arasında ileri ve geri hareket edebilir.

---

# 23. Pause

Pause yapıldığında:

- Sudoku grid'i gizlenir.
    
- Timer durur.
    
- Oyun state'i korunur.
    

Devam edildiğinde oyuncu kaldığı yerden devam eder.

Pause performans puanını cezalandırmaz.

---

# 24. Timer

Timer yukarı doğru ilerleyen kronometredir.

Timer:

- Oyunu başarısız yapmaz.
    
- Hata oluşturmaz.
    
- Puzzle'ı kilitlemez.
    
- Yalnızca istatistik ve performance score için kullanılır.
    

Pause durumunda durur.

---

# 25. Performance Score

Her tamamlanan oyun için 0–100 arası normalize edilmiş bir Performance Score oluşturulur.

Score şu oyun davranışlarını birlikte değerlendirir:

- Puzzle difficulty
    
- Çözüm süresi
    
- Mistake sayısı
    
- Hint kullanımı
    
- Undo/Redo kullanımı
    
- Gerekli diğer oyuncu davranışları
    

Score'un amacı rekabetçi bir leaderboard oluşturmak değildir.

Ana amaçlar:

1. Kullanıcının kendi performansını değerlendirebilmesi.
    
2. Aynı puzzle'ı tekrar oynadığında gelişimini görebilmesi.
    
3. Gelecekte achievement sisteminin kullanılabilmesi.
    

Score oyun sırasında kullanıcıyı kısıtlamaz.

Score formülü kullanıcıya teknik detaylarıyla gösterilmez.

---

# 26. Replay ve Master it again

Tamamlanmış bir puzzle tekrar oynanabilir.

## Replay

History'de oyun:

**Replay**

olarak işaretlenir.

Yeni çözüm sonucu ayrı olarak kaydedilir.

## Master it again

Aynı puzzle tamamen sıfırlanır.

Eski sonuç korunur.

Yeni çözüm yeni bir history kaydı oluşturur ve bunun aynı puzzle'ın tekrar oynanması olduğu gösterilir.

## Best Performance

Aynı puzzle'ın sonuçları arasında en yüksek performans ayrıca gösterilebilir.

Örneğin:

**Best: 94**

**Current Replay: 91**

Replay olmak yeni skorun geçersiz olduğu anlamına gelmez.

---

# 27. Save Sistemi

Uygulama içinde oyunlar lokal bir veritabanında tutulur.

Kullanıcı:

- sınırsız aktif oyun
    
- tamamlanmış oyunlar
    
- replay sonuçları
    
- statistics
    
- oyun state'leri
    

ile çalışabilir.

Kullanıcı tarafından dışarı aktarılabilen save dosyası ayrı bir format olacaktır.

---

# 28. Save İçeriği

Bir save şunları korur:

- Puzzle seed
    
- Difficulty
    
- Puzzle bilgisi
    
- Mevcut grid
    
- Notlar
    
- Timer
    
- Mistakes
    
- Hint count
    
- Move history
    
- Gerekli snapshot bilgileri
    
- Performance bilgileri
    
- Replay bilgileri
    
- Save format version
    

---

# 29. Save Yapısı

Save sistemi:

**Snapshot + Move Log**

mantığı üzerine kurulacaktır.

Snapshot mevcut oyunun güvenli bir görüntüsüdür.

Move Log snapshot'tan sonraki hareketleri tutar.

Bu yapı:

- Undo/Redo
    
- Crash recovery
    
- Save import/export
    
- Oyun geçmişi
    
- Veri kurtarma
    

için ortak temel oluşturur.

Save formatı versiyonlanacaktır.

İleride veri yapısı değişse bile eski save dosyalarının yeni uygulama sürümlerine taşınabilmesi hedeflenir.

---

# 30. Crash Recovery

Uygulama her hamleyi kalıcı hale getirecek şekilde tasarlanır.

Buna ek olarak son **3 güvenli state** korunur.

Uygulama bir save yazma işlemi sırasında kapanır veya çökme yaşarsa son bozulmamış state kullanılabilir.

Normal kullanıcı deneyiminde bu sistem görünmez.

Uygulama yeniden açıldığında:

**son aktif oyunun mümkün olan en son güvenli hali**

otomatik olarak açılır.

---

# 31. Import / Export

Oyuncu iki şekilde Sudoku aktarabilir.

### Seed Import

Kullanıcı seed girer.

Uygulama ilgili Sudoku'yu oluşturur.

### Save Import

Kullanıcı save dosyasını içe aktarır.

Oyun:

- grid
    
- notlar
    
- süre
    
- hata
    
- hint
    
- history bilgileri
    

ile birlikte geri getirilebilir.

Import edilen save'in geçerliliği kontrol edilir.

---

# 32. History

History bütün oynanmış oyunları tutar.

Ana history görünümü sade tutulacaktır.

## Temel filtreler

### Status

- Active
    
- Completed
    
- Replay
    

### Difficulty

- All
    
- Easy
    
- Medium
    
- Hard
    
- Expert
    

### Sorting

- Newest
    
- Oldest
    
- Fastest
    
- Best Score
    

Veri modelinin ileride daha ayrıntılı filtreleri desteklemesi planlanır; ancak ilk UI gelişmiş filtrelerle kalabalıklaştırılmaz.

---

# 33. Statistics

İstatistik sistemi iki seviyelidir.

## Ana görünüm

Sadece önemli bilgileri gösterir:

- Completed Games
    
- Current Daily Streak
    
- Average Time
    
- Best Performance
    
- Completion Rate
    

## Detailed Statistics

Ayrıntılı ekranda:

- Difficulty bazında çözüm süreleri
    
- Difficulty bazında hata ortalaması
    
- Hint kullanımı
    
- Ortalama performance score
    
- En iyi score'lar
    
- Daily performansı
    
- Replay performansı
    
- Completion davranışları
    
- Tarihsel değişim
    

gibi bilgiler bulunabilir.

Ana arayüz sade kalırken merak eden kullanıcı ayrıntıya ulaşabilir.

---

# 34. Daily Sudoku

Her gün bir adet Daily Sudoku bulunur.

Difficulty:

**Medium**

Daily puzzle, kullanıcının lokal takvim gününe göre belirlenir.

Aynı takvim günündeki kullanıcılar aynı Daily puzzle'ı oynar.

Daily seed deterministic olduğu için server gerekmez.

Daily:

- Offline çalışır.
    
- Geçmiş tarihler için yeniden üretilebilir.
    
- Tamamlanma durumu lokal olarak saklanır.
    

---

# 35. Daily Streak

Daily Sudoku çözülürse gün tamamlanır.

Arka arkaya tamamlanan günler:

**Current Streak**

olarak tutulur.

Ayrıca:

**Longest Streak**

saklanabilir.

Daily Sudoku'nun açılması streak'i ilerletmez.

Puzzle'ın tamamlanması gerekir.

---

# 36. Gameification

Gameification hafif olacaktır.

Temel sistemler:

- Performance Score
    
- Daily Streak
    
- Statistics
    
- Best Performance
    

## Player progression yok

- XP yok.
    
- Level yok.
    
- Character progression yok.
    
- Skill tree yok.
    

## Achievements

Achievement sistemi temel oyun deneyiminden sonra eklenebilir.

Örneğin:

- İlk Sudoku
    
- 10 Sudoku
    
- İlk Expert
    
- Uzun Daily streak
    
- Belirli performance score
    

Ancak achievement sistemi ilk MVP'nin ana odağı değildir.

---

# 37. Görsel Tasarım

Ürün genel olarak:

**Premium Puzzle App**

gibi görünmelidir.

## Grid

- Modern
    
- Temiz
    
- Okunabilir
    
- Gereksiz süslemelerden uzak
    
- Güçlü hiyerarşi
    
- Parmakla kullanım için yeterli hücre boyutu
    
- Desktop için yeterince büyük
    

Grid görsel olarak uygulamanın merkezidir.

---

# 38. Tema Sistemi

Hazır temalar bulunur.

Minimum hazır tema seti:

- Light
    
- Dark
    
- AMOLED
    

Bunlara ek birkaç uygulama teması eklenebilir.

## Custom Theme

Kullanıcı kendi renklerini seçebilir.

Özelleştirilebilir temel alanlar:

- Background
    
- Grid
    
- Cell
    
- Selected Cell
    
- Primary Text
    
- Secondary Text
    
- Accent
    
- Error
    
- Notes
    

Tema editörü güçlü ama karmaşık olmamalıdır.

---

# 39. Font

Uygulamaya birkaç font ailesi gömülecektir.

Başlangıç önerisi:

### Modern Sans

Varsayılan.

### Rounded Sans

Daha yumuşak ve oyun odaklı.

### Classic Serif

Daha geleneksel/premium görünüm.

Kullanıcı bu fontlardan birini seçebilir.

Harici font import ilk sürümde bulunmaz.

---

# 40. Animasyon

Animasyonlar hafif olacaktır.

Kullanılabileceği alanlar:

- Hücre seçimi
    
- Sayı yerleşimi
    
- Küçük UI geçişleri
    
- Hata vurgusu
    
- Puzzle tamamlanması
    

Animasyonların amacı görsel kaliteyi artırmaktır; Sudoku çözme hızını yavaşlatmak değildir.

Ayar:

**Animations: On / Off**

şeklinde olacaktır.

---

# 41. Ses

Küçük UI sesleri bulunacaktır.

Örneğin:

- Sayı girme
    
- Silme
    
- Hata
    
- Buton etkileşimi
    
- Sudoku tamamlama
    

Tek ana ayar:

**UI Sounds: On / Off**

Ekstra karmaşık ses sistemi bulunmaz.

---

# 42. Desktop Kontrolleri

PC'de temel mouse + keyboard hibrit deneyim bulunur.

Temel klavye davranışları:

- `1–9` → sayı
    
- `Delete / Backspace` → sil
    
- `Arrow Keys` → hücre hareketi
    
- `Ctrl + Z` → Undo
    
- `Ctrl + Shift + Z` → Redo
    
- `N` → Notes mode
    
- `Esc` → ilgili ekran/menüden çıkış
    

Bu davranışların ileride özelleştirilebilmesi için mimari açık tutulur.

Sadece mouse ile oynama ve gelişmiş klavye özelleştirme ilk aşamanın önceliği değildir.

---

# 43. Tablet ve Responsive Tasarım

Tablet desteklenecektir.

Grid ve kontroller ekran boyutuna göre ölçeklenebilir.

Mobilde dikey kullanım temel alınır.

Landscape desteklenebilir ancak ilk sürümde ana tasarım önceliği değildir.

UI'nın küçük bir telefon ekranından büyük desktop ekranına kadar aynı tasarım dili içinde ölçeklenmesi hedeflenir.

---

# 44. Localization

Uygulama i18n mimarisiyle tasarlanır.

Arayüz yalnızca Türkçe veya İngilizceye sabitlenmez.

İleride istenilen diller eklenebilir.

## Sudoku rakamları

Grid üzerindeki 1–9 değerleri varsayılan olarak standart uluslararası numeraller olacaktır.

## UI sayıları

İstatistiklerde:

- sayı ayraçları
    
- ondalık biçimleri
    
- tarih
    
- saat
    
- süre gösterimi
    

kullanıcının locale ayarına göre biçimlendirilir.

Böylece Sudoku grid'i evrensel ve tanıdık kalırken UI doğal şekilde yerelleştirilebilir.

---

# 45. Veri Gizliliği

Uygulama:

- Kullanıcı hesabı istemez.
    
- Network hizmetine ihtiyaç duymaz.
    
- Cloud sync kullanmaz.
    
- Analytics kullanmaz.
    
- Telemetry kullanmaz.
    
- Kullanıcı oyun verisini sunucuya göndermez.
    

Mümkün olan platformlarda ağ erişimi için gereksiz izinlerden kaçınılacaktır.

Temel ilke:

**Uygulama çalışmak için internete ihtiyaç duymaz ve kullanıcı verisi cihaz dışına çıkmaz.**

---

# 46. Platform Mimarisi

Uygulama cross-platform framework ile geliştirilecektir.

Mümkün olan maksimum ortak kod kullanılacaktır.

Özellikle şu sistemler ortak tutulacaktır:

- Sudoku model
    
- Generator
    
- Solver
    
- Difficulty
    
- Validator
    
- Seed
    
- Daily Sudoku
    
- Game state
    
- Save
    
- Statistics
    
- Performance score
    
- History
    
- Settings
    
- Localization
    

UI da mümkün olduğunca ortak tutulacaktır.

Platforma özel kod yalnızca gerektiğinde kullanılacaktır.

Bu yapı sayesinde aynı seed'in Android ve PC'de aynı puzzle üretmesi güvence altına alınabilir.

---

# 47. Teknik Mimari İlkeleri

Uygulama mantıksal olarak şu katmanlara ayrılır:

### Sudoku Core

Puzzle, solver, generator, difficulty ve validator.

### Game Core

Game state, move history, hint, scoring, timer ve replay.

### Data Layer

Local database, save/import/export, recovery.

### Presentation Layer

UI, themes, fonts, animations, input.

### Platform Layer

Android, desktop ve gelecekteki diğer platformlara özgü entegrasyon.

Bu ayrım sayesinde UI değişse bile Sudoku motorunun yeniden yazılması gerekmez.

---

# 48. Local Data Model

Ana kavramlar:

### Puzzle

- Seed
    
- Difficulty
    
- Solution
    
- Difficulty data
    
- Technique data
    

### Game

- Puzzle reference
    
- Current grid
    
- Notes
    
- Timer
    
- Mistakes
    
- Hints
    
- Move history
    
- Current state
    
- Replay state
    
- Score
    

### History

Tamamlanmış oyunların sonuçları.

### Settings

Kullanıcının tüm tercihleri.

### Statistics

History üzerinden hesaplanabilen kullanıcı performansı.

Mümkün olan yerlerde istatistikler ham oyun verilerinden türetilir; böylece gereksiz duplicate veri tutulmaz.

---

# 49. MVP

İlk sürümde aşağıdaki sistemler bulunmalıdır:

### Core

- 9×9 Sudoku
    
- Unique solution
    
- Runtime generator
    
- Seed
    
- Difficulty
    
- Solver
    
- Validator
    
- Difficulty analyzer
    

### Gameplay

- Easy / Medium / Hard / Expert
    
- Smart numpad
    
- Notes
    
- Smart candidates
    
- Auto-remove notes
    
- Mistakes
    
- Conflict detection
    
- Check
    
- Unlimited Undo/Redo
    
- Hint
    
- Full solution
    
- Step-by-step solution
    
- Timer
    
- Pause
    

### Data

- Multiple active games
    
- History
    
- Local database
    
- Save
    
- Hybrid snapshot + move log
    
- Crash recovery
    
- Import/export
    
- Seed import
    

### Progress / Analysis

- Performance Score
    
- Statistics
    
- Daily Sudoku
    
- Daily streak
    
- Replay
    
- Master it again
    

### Presentation

- Light/Dark/AMOLED
    
- Custom colors
    
- Multiple fonts
    
- Responsive UI
    
- Tablet support
    
- Lightweight animations
    
- Animation toggle
    
- UI sounds
    
- Sound toggle
    
- Localization
    

### Platforms

- Android
    
- PC/Desktop
    

### Product

- Offline
    
- No account
    
- No network dependency
    
- No analytics
    
- No telemetry
    
- GPLv3
    
- Free
    

---

# 50. İlk Sürüm Dışında Bırakılanlar

Bunlar mimariye açık bırakılabilir ancak MVP'nin parçası değildir:

- Achievement sistemi
    
- QR puzzle sharing
    
- Gelişmiş keyboard customization
    
- Gelişmiş history filtreleri
    
- Daha fazla görsel tema paketi
    
- Daha gelişmiş istatistik görselleştirmeleri
    

Aşağıdakiler ise ürün kapsamından tamamen çıkarılmıştır:

- Cloud sync
    
- Online accounts
    
- XP
    
- Player level
    
- Progression system
    
- Multiplayer
    
- Online leaderboard
    
- Farklı Sudoku türleri
    
- Tutorial / eğitim modu
    

---

# 51. Kullanıcı Deneyimi Özeti

Oyuncu uygulamayı açtığında doğrudan kaldığı Sudoku'ya dönebilir.

Yeni oyun başlatmak istediğinde yalnızca difficulty seçer.

Kısa preview'da:

**Difficulty + tahmini süre + en çok kullanılan 3 teknik**

görülür.

Oyuncu Sudoku'yu istediği hızda çözer.

Hata yaparsa oyun onu cezalandırmaz.

İster manuel not kullanır, ister Smart Candidates'tan yararlanır.

Takıldığı zaman Hint kullanabilir.

İsterse çözümün tamamını veya adım adım mantığını inceleyebilir.

Uygulamayı aniden kapatsa bile oyununu kaybetmez.

Sudoku tamamlandığında sade bir sonuç ekranı görür:

**Time  
Mistakes  
Hints  
Performance**

İsterse ayrıntılı rapora girer.

Sonrasında yeni Sudoku'ya geçebilir veya aynı puzzle'ı Master it again ile tekrar deneyebilir.

Bütün bunlar internet bağlantısı olmadan gerçekleşir.

---

# 52. Ürünün Başarı Kriterleri

Ürün başarılı kabul edilmek için öncelikle aşağıdaki hissi sağlamalıdır:

**“Aç, Sudoku'yu seç, oyna. Hiçbir şey önümde durmasın.”**

Teknik olarak:

- Yeni puzzle hızlı açılmalı.
    
- Uygulama açılışı hızlı olmalı.
    
- Oyun state'i güvenilir biçimde korunmalı.
    
- Seed deterministik olmalı.
    
- Aynı seed aynı puzzle'ı üretmeli.
    
- Tüm puzzle'lar tek çözümlü olmalı.
    
- Difficulty tutarlı olmalı.
    
- Hint ile solver aynı mantığı kullanmalı.
    
- Step-by-step çözüm güvenilir olmalı.
    
- Android ve PC'de temel deneyim aynı olmalı.
    
- İnternet olmadan tüm temel özellikler çalışmalı.
    

Görsel olarak:

- Grid ilk bakışta anlaşılmalı.
    
- UI grid'i gölgelememeli.
    
- Animasyonlar ve sesler küçük ama kaliteli hissettirmeli.
    
- Tema sistemi kişiselleştirmeye izin vermeli.
    
- Ana ekran ve istatistik ekranı gereksiz bilgiyle dolmamalı.
    

---

# 53. Ürün Kimliği

Bu uygulama:

**bir Sudoku içerik platformu değil,**

**bir sosyal uygulama değil,**

**bir online servis değil,**

**bir progression oyunu değil.**

Bu uygulama:

**iyi tasarlanmış, hızlı, sade, kişisel ve tamamen offline bir Sudoku aracıdır.**

Oyuncuya sonsuz Sudoku içeriği sağlayan deterministic generator, güçlü çözüm motoru ve güvenilir kayıt sistemi ürünün teknik omurgasını oluşturur.

Görsel tarafta ise premium puzzle app yaklaşımı korunur.

Temel ürün vaadi:

**“Sadece Sudoku. Ama doğru yapılmış.”**
---

# 54. Ton ve Terim Sözlüğü

Arayüzdeki bütün metinler tek bir ses ile konuşur. Yeni bir metin eklerken veya mevcut bir metni değiştirirken bu bölüm esas alınır. Metinlerin tek kaynağı `scripts/services/localization_manager.gd` içindeki `DICTIONARY_EN` ve `DICTIONARY_TR` sözlükleridir.

## 54.1 Ton

- **Sakin ve kısa.** Bir cümle yetiyorsa iki cümle yazılmaz. Teknik açıklama yerine oyuncunun ne yapacağı söylenir.
- **Türkçede "sen" dili.** "Başlat", "dene", "serini koru". "Siz" dili kullanılmaz.
- **Tek dil.** Türkçe metinde parantez içinde İngilizce karşılık verilmez ("Tekrar Oyna (Master it again)" yerine "Yeniden Çöz").
- **Ünlem işareti sadece kutlamada.** Bulmaca çözüldüğünde ve yeni rekorda kullanılır. Bildirimler ve hatalar düz cümledir.
- **Dürüst etiketler.** Düğme ne yapıyorsa onu söyler ("Harika!" değil, "Menüye Dön").
- **Üç nokta tek karakterdir:** `…`

## 54.2 Büyük harf

| Yer | Kural | Örnek |
|---|---|---|
| Ekran ve pencere başlıkları, düğmeler, menü öğeleri | Her Kelimenin İlk Harfi Büyük | Yeni Oyun, Bulmacayı Paylaş |
| Ayar adları, açıklamalar, bildirimler, hata metinleri | Cümle düzeni | Notları otomatik sil |
| Küçük bölüm etiketleri (kart üstü, filtre başlığı) | Metin cümle/başlık düzeninde yazılır; büyük harfe kod çevirir | Genel Bakış → GENEL BAKIŞ |

Metinler sözlükte hiçbir zaman TAMAMEN BÜYÜK HARFLE yazılmaz. Küçük etiketlerde görsel büyük harf `LocalizationManager.upper()` ile uygulanır; Godot'nun `to_upper()` fonksiyonu Türkçe "i" harfini "I" yaptığı için doğrudan kullanılmaz.

## 54.3 Terimler

| Kavram | Türkçe | İngilizce | Kullanılmayan |
|---|---|---|---|
| 9×9 bulmacanın kendisi | bulmaca | puzzle | sudoku tablosu |
| Bir bulmacayı oynama oturumu (kayıtlı olan) | oyun | game | save, slot |
| Bulmacanın kimliği (seed) | bulmaca numarası, "No. 123…" | puzzle number, "No. 123…" | seed (arayüzde) |
| 81 karakterlik bulmaca metni | bulmaca kodu | puzzle code | 81 karakterlik string |
| Başka cihaza taşınan kayıt metni | dışa aktarılmış oyun | exported game | save JSON, save durumu |
| Bulmacada baştan verilen rakamlar | başlangıç rakamları | starting digits | ipucu (clue) |
| Oyuncunun yazdığı küçük rakamlar | not | note | pencil mark, aday notu |
| Hücreye girebilecek rakam (otomatik) | aday | candidate | — |
| 3×3 bölge | kutu | box | blok |
| Satır / sütun / kutu, genel ad | bölge | unit/area | — |
| Kural ihlali (aynı rakam iki kez) | çakışma | conflict | — |
| Çözümle uyuşmayan rakam | yanlış rakam, hata | wrong digit, mistake | — |
| Yardım alma | ipucu | hint | — |
| Puan | skor | score | performans skoru |
| Çözülmüş bulmacayı tekrar oynama | yeniden çöz, tekrar | solve again, replay | master it again |
| Günlük bulmaca | Günün Sudokusu | Daily Sudoku | günlük bulmaca, daily |
| Ardışık günler | seri | streak | — |
| Zorluk seviyeleri | Kolay, Orta, Zor, Uzman | Easy, Medium, Hard, Expert | — |

Çözüm teknikleri Türkçede Türkçe adlarıyla yazılır: Son Hücre, Açık Tekli, Gizli Tekli, Kilitli Adaylar, Açık İkili, Gizli İkili, Açık Üçlü, Gizli Üçlü, Doğrudan Çözüm, İleri Çıkarım. Türkçe karşılığı yerleşmemiş özel adlar olduğu gibi kalır: X-Wing, XY-Wing, XYZ-Wing, Swordfish.

## 54.4 İstisnalar

- **Dil seçimi** iki dilde yazılır ("Dil / Language"), böylece arayüz dilini anlamayan biri de dili değiştirebilir.
- **Paylaşım metni** ("Seed: …", "Kod: …" satırları) makine tarafından da okunur; içe aktarma bu etiketlere göre çalıştığı için değiştirilmez.
- **Uygulama adı** "Just Sudoku" çevrilmez.
