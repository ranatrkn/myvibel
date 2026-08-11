# VibeLife Uygulama ve Kod Dokumani

Bu belge, yazilim bilgisi sinirli bir kullanicinin da uygulamayi anlayabilmesi icin hazirlanmistir. Iki ana hedefi vardir:

1. Uygulamanin ne yaptigini, hangi ekranlarin ne ise yaradigini aciklamak
2. Kodun hangi dosyalarda nasil calistigini, hangi servislerin hangi sorumlulugu aldigini anlatmak

---

## 1) Uygulamaya Genel Bakis

VibeLife, sosyal etkilesim odakli bir mobil uygulamadir. Kullanici:

- Kayit olur / giris yapar
- Gonderi paylasir, begenir, yorum yapar
- Diger kullanicilari takip eder
- Mesajlasir
- Bildirim alir
- Kendi robotunu gelistirir

Robot sistemi, uygulamanin "oyunlastirma" katmanidir. Sosyal hareketler robotu etkiler:

- Enerji
- Mutluluk
- Seviye
- Gelisim puani

Bu mekanik, kullanicinin uygulama ici davranisini daha canli ve takip edilir hale getirir.

---

## 2) Teknoloji Ozeti

- Flutter (UI)
- Firebase Auth (kimlik dogrulama)
- Cloud Firestore (veri tabani)
- Lottie (animasyonlar)
- SharedPreferences (cihaz ici kucuk ayarlar)

Ana giris dosyasi:

- `lib/main.dart`

Ana domain servisleri:

- `lib/robot_servis.dart`
- `lib/sosyal_servis.dart`
- `lib/hesap_sil_servis.dart`

Guvenlik kurallari:

- `firestore.rules`

---

## 3) Uygulama Aklisi (Kullanici Gozuyle)

### 3.1 Giris/Kayit

- `login_page.dart`: e-posta + sifre ile giris
- `register_page.dart`: yeni hesap olusturma
- Kayitta gizlilik/KVKK onayi zorunlu
- Kayit sonrasi dogrulama e-postasi gonderimi denenir

### 3.2 Ana Gezinme

`feed_page.dart` altindaki tab mantigi:

1. Ana akis
2. Kesfet
3. Yeni gonderi
4. Bildirimler
5. Profil

### 3.3 Profil

- Profil duzenleme
- Hesap gizli/acik degistirme
- Takip/takipci listesi
- Engellenenler
- Sifre sifirlama
- Yasal sayfalar
- Surum notlari
- Iletisim
- Hesap silme / cikis

### 3.4 Robot Odasi

- Robot gorseli (seviyeye ve ruh haline gore)
- Enerji/mutluluk barlari
- Gelistir butonu
- Uyku/uyandirma butonu

---

## 4) Robot Sistemi (Detayli Isleyis)

Robot sistemi `lib/robot_servis.dart` dosyasinda merkezi olarak yonetilir.

### 4.1 Temel Alanlar

Robot veri modeli:

- isim
- seviye
- gelisimPuani
- enerji (0-100)
- mutluluk (0-100)
- uykuBitisMs
- sonUygulamaMs
- sonEtkilesimMs
- sonMutlulukTickMs
- sonEnerjiDususMs

### 4.2 Gelisim

- Gelistirme maliyeti puanla odenir
- Gelisim puani birikir
- Esigi gecince seviye atlanir
- Seviye odulleri tetiklenir

Ilgili metot:

- `RobotServis.gelistir(uid)`

### 4.3 Uyku

Kurallar:

- Enerji belirli seviyenin ustundeyse robot tekrar uyuyamaz
- Uyku suresi 4 saat
- Uyku boyunca enerji dakika bazli dolar
- Uygun kosulda erken uyandirma vardir

Ilgili metotlar:

- `RobotServis.uyuYap(uid)`
- `RobotServis.uyandir(uid)`
- `RobotServis.uyuyorMu(robot)`

### 4.4 Mutluluk Dususu

Iki farkli zaman kuralina gore dakika bazli hesaplanir:

- Uygulama disinda gecen sure (daha hizli dusus)
- Uygulama acik ama etkilesimsiz sure (daha yavas dusus)

Onemli:

- Mutluluk, robot uyurken de duser (istenen davranis bu yonde)

### 4.5 Enerji Kilidi

Enerji sifira indiginde sosyal etkilesimler engellenir:

- gonderi
- yorum
- begeni
- robot gelistirme gibi aksiyonlar

Bu kontrol:

- `RobotServis.etkilesimEngelliyseAt(...)`

ile merkezi hale getirilmistir.

### 4.6 Gorsel Durum

`RobotGorselDurum`:

- normal
- mutlu
- uzgun
- uyku

Ek kural:

- Uzgun animasyonun seviye kosulu vardir (dusuk seviyede fallback gorsel)

---

## 5) Sosyal Sistem (Detayli)

Ana dosya:

- `lib/sosyal_servis.dart`

### 5.1 Gonderi

- Yeni gonderi olusturma: `newpost_page.dart`
- Post sayaclari ve puan guncellemesi batch/transaction ile
- Etiket ve mention cozumlemesi

### 5.2 Begeni

- Like/unlike transaction ile yapilir
- Post sayaci + skor + kullanici sayaci etkilenir
- Robot mutlulugu/enerjisi sosyal aksiyonla etkilenir

### 5.3 Yorum

- Yorum ekleme transaction ile
- Yorum sayaci + skor + puan etkisi
- Mention varsa bildirim uretilir

### 5.4 Takip

Desteklenen durumlar:

- Acik hesap: direkt takip
- Gizli hesap: takip istegi
- Istek kabul/red

Ilgili alt koleksiyonlar:

- `followers`
- `following`
- `followRequests`
- `followRewarded`

---

## 6) Gizli Hesap Mantigi

UI katmaninda gizleme vardir, ama asil guvenlik server rules tarafinda olmalidir.

Bu projede:

- Gizli hesap gonderilerine server-side okuma kosulu eklidir
- Takip/takipci listelerine okuma erisimi sikilastirilmistir
- Takip iliskisi olusumu request/follower/following tutarliligina baglanmistir

Not:

Gizlilik davranisinin gercek guvenligi, her zaman `firestore.rules` ile belirlenir.

---

## 7) Mesajlasma ve Bildirim

### 7.1 Mesajlasma

- `chats/{chatId}`
- `chats/{chatId}/messages/{messageId}`

Kurallar:

- Yalnizca sohbet katilimcilari okuyabilir/yazabilir
- Mesaj tipleri kontrol edilir (text / post_forward)

### 7.2 Bildirim

- Kullanici bazli `notifications` alt koleksiyonu
- Follow, like, comment, mention, message gibi eventler
- Okunmamis sayaclari UI'da badge olarak gosterilir

---

## 8) Profil ve Ayarlar Alani

Dosya:

- `lib/profile_page.dart`

Ozellikler:

- Profil bilgisi guncelleme
- Kullanici adi degisimi ve `usernames` koleksiyonu tutarliligi
- Hesap gizliligi degistirme ve postlara yayma
- Yasal sayfalara erisim
- Hesap silme

UI notu:

- Ayarlar paneli cok kalabalik oldugunda tasma olmamasi icin kaydirilabilir yapiya alinmistir.

---

## 9) Yasal Sayfalar ve Bilgilendirme

Dosya:

- `lib/legal_pages.dart`

Sayfalar:

- Gizlilik politikasi
- KVKK aydinlatma
- Yardim / SSS
- Surum notlari
- Iletisim ve geri bildirim

Sabitler:

- `VibeLegal.privacyPolicyUrl`
- `VibeLegal.supportEmail`
- `VibeLegal.appVersionLabel`

---

## 10) Hata Yonetimi ve Snackbar Standarti

Merkezi snackbar:

- `lib/vibe_snackbar.dart`

Merkezi internet-hata donusumu:

- `lib/error_messages.dart`

Hedef:

- Teknik stack trace gostermeden
- Kullanici dostu, tek tip mesajlar vermek

Ornek internet mesaji:

- "internet baglantisi yok"

---

## 11) Firestore Veri Modeli (Ozet)

Ana koleksiyonlar:

- `users`
- `posts`
- `reports`
- `chats`
- `usernames`

`users/{uid}` icinde:

- temel profil alanlari
- puan/sayaclar
- robot objesi
- alt koleksiyonlar (followers/following/notifications vb.)

`posts/{postId}` icinde:

- metin
- owner bilgisi
- sayaclar (`begeniSayisi`, `yorumSayisi`, `skor`)
- gizlilik/moderasyon alanlari
- alt koleksiyonlar (`likes`, `comments`)

---

## 12) Firestore Rules (Guvenlik Mimarisi)

Dosya:

- `firestore.rules`

Uygulanan temel prensipler:

1. Kimliksiz kullaniciya kritik okuma/yazma yok
2. Kullanici sadece kendi kaydini belirli alanlarda guncelleyebilir
3. Moderator yetkileri acik ayrilmistir
4. Post, yorum, begeni sayaclari rastgele degil, islemle uyumlu degisim kosuluna baglanir
5. Gizli hesap postlari/takip grafi server tarafinda korunur

Son guvenlik sertlestirmesi kapsaminda:

- social graph read kosullari daraltildi
- post counter update kurallari sertlestirildi
- owner score update akisina "islem kaniti" alanlari eklendi
- release signing yapisi iyilestirildi

---

## 13) Kod Organizasyonu ve Mimari Yaklasim

Proje pratikte 3 katmanda dusunulebilir:

### 13.1 Sunum Katmani (UI Sayfalari)

Ornek:

- `feed_page.dart`
- `profile_page.dart`
- `robot_page.dart`
- `newpost_page.dart`

Sorumluluk:

- kullanici etkilesimi
- veri gosterimi
- buton/diyalog/snackbar

### 13.2 Is Kurali Katmani (Servisler)

- `sosyal_servis.dart`
- `robot_servis.dart`
- `hesap_sil_servis.dart`

Sorumluluk:

- transaction/batch
- tutarlilik
- kurallar

### 13.3 Altyapi ve Ortak Bilesenler

- `main.dart` (bootstrap)
- `app_theme.dart` / `theme_controller.dart`
- `vibe_snackbar.dart`
- `firestore.rules`

---

## 14) Kritik Dosyalarin Tek Tek Ne Yaptigi

### `lib/main.dart`

- Firebase baslatir
- tema sistemini yukler
- auth state'e gore login/feed yonlendirmesi yapar

### `lib/feed_page.dart`

- alt gezinti
- feed akislari
- robot periyodik senkronizasyonu
- surum notu popup

### `lib/robot_servis.dart`

- robot stateleri
- zaman bazli dusus/artis
- uyku/uyandirma
- gelisim
- sosyal aksiyon etkileri

### `lib/sosyal_servis.dart`

- takip/follow request
- begeni/yorum/post yardimcilari
- mention/etiket islemleri
- bildirim olusturma
- hiz limiti korumalari

### `lib/profile_page.dart`

- profil yonetimi
- ayarlar paneli
- gizlilik ayari
- hesap silme tetigi

### `lib/register_page.dart`

- yeni hesap olusturma
- username rezervasyonu (`usernames`)
- ilk robot ve sayac verisi
- gizlilik/KVKK onay zorunlulugu

### `firestore.rules`

- butun veri guvenligi kurallari
- read/write izin modelinin omurgasi

### `android/app/build.gradle`

- Android derleme ayarlari
- release imzalama (key.properties destekli)

---

## 15) Hesap Silme Aklisi

Dosya:

- `lib/hesap_sil_servis.dart`

Amac:

- Kullanici silindiginde bagli verilerin de tutarli temizlenmesi

Temizlik adimlarina dahil:

- kullanicinin begendigi post iliskileri
- yorumlar
- kendi postlari ve alt koleksiyonlari
- takip/follow request iliskileri
- bildirimler
- username kaydi
- son adimda auth hesabi silme

---

## 16) Test ve Dogrulama Onerisi

Her release oncesi minimum kontrol:

1. Kayit -> e-posta dogrulama mesaji
2. Giris/Logout
3. Gonderi olustur, yorum, begeni
4. Gizli hesapta takip istegi akisi
5. Robot uyku/uyandirma/enerji kilidi
6. Hesap silme e2e testi
7. Firestore rule regression testi

---

## 17) Yayina Cikma (Play Store) Ozet Kontrol

Teknik olarak tamamlanmasi gerekenler:

- Gercek release keystore
- `key.properties` duzgun tanim
- App Check aktivasyonu
- Crashlytics aktivasyonu
- Privacy policy URL (public)
- Data safety form

---

## 18) Sizin Acinizdan Basit Ozet

Yazilim bilmiyor olsaniz bile uygulamayi su sekilde okuyabilirsiniz:

- "Ekranlar" bolumu = kullanici ne gorur
- "Servisler" bolumu = uygulama arkada ne yapar
- "Rules" bolumu = guvenlik kilidi
- "Robot sistemi" bolumu = oyunlastirma kurallari

Bu belgede anlatilan yapinin amaci:

- veriyi guvenli tutmak
- kullanici deneyimini netlestirmek
- uygulamayi buyutmeye uygun hale getirmek

---

## 19) Gelecekte Eklenecek Gelistirme Alanlari

1. Rule unit test otomasyonu
2. Moderasyon panelinde daha guclu audit log
3. Spam/rate limit'in server tarafini daha da arttirma
4. App analytics dashboard
5. Crash raporlarini release surecine baglama

---

## 20) Son Not

Bu dokuman, "uygulamayi kullanma" ve "kodu anlama" ihtiyacini birlikte karsilamak icin yazilmistir. Kod yapisinda isimler Turkce oldugu icin, teknik ekip olmayan kisiler de dosya adlariyla mantigi daha kolay takip edebilir.

Guncel kod tabanina gore bu dosya duzenli aralikla guncellenmelidir.
