// Türkçe yasal metin içerikleri (uygulama + web hosting ile uyumlu).
// NOT: Hukuki tavsiye değildir. Avukat incelemesi önerilir.
// Geliştirici notları (kullanıcıya gösterilmez):
// - Ticaret şirketi yok / yakın vadede planlanmıyor; metinler buna göre yazıldı.
// - VERBİS yükümlülüğü faaliyet/muafiyete göre ayrı değerlendirilsin.
// - Firebase DPA ve md. 9 aktarım aracını hukuki dosyada sakla.
class YasalIcerik {
  YasalIcerik._();

  static const guncellemeTarihi = '22 Ekim 2026';
  static const surum = '1.0.0';
  static const uygulamaAdi = 'MyVibel';

  /// Marka adı. Ticaret şirketi yoktur; tüzel kişi unvanı yayımlanmaz.
  static const veriSorumlusu = 'MyVibel';

  static const gizlilikBaslik = '$uygulamaAdi Gizlilik Politikası';

  static const gizlilikMetni = '''
İşbu Gizlilik Politikası, $uygulamaAdi mobil uygulaması ile aynı hizmete bağlı https://myvibel.com web arayüzünü («Hizmet») kullanan kişilerin kişisel verilerinin hangi kapsamda işlendiğini düzenler. Politika, Hizmetin fiilen çalışan sürümüne göredir. Kullanım Koşulları ve KVKK Aydınlatma Metni ile birlikte okunur. Çelişki halinde, kişisel veriye ilişkin konuda KVKK Aydınlatma Metni ve emredici mevzuat esas alınır.

1. Veri sorumlusu
Veri sorumlusu, «$veriSorumlusu» markası altında Hizmeti işleten gerçek kişidir. Hizmet bir ticaret şirketi, dernek veya başka bir tüzel kişilik bünyesinde sunulmamaktadır. Bu nedenle ticaret unvanı, MERSİS numarası veya vergi kimlik numarası yayımlanmaz.
6698 sayılı Kanun’un 10. maddesinin aradığı kimlik ve iletişim bilgisi için başvuru kanalı destek@myvibel.com adresidir. Aynı başvuru, uygulama içi Profil → Destek ve Geri Bildirim formu üzerinden, konu olarak KVKK başvurusu seçilerek de yapılır ve https://myvibel.com/kvkk.html adresinden yönlendirilir. Usulüne uygun bir başvuruda veya yetkili merciin isteminde, tebligata elverişli kimlik ve adres bilgisi ayrıca bildirilir. Ev adresi yayımlanmaz.

2. Kapsam ve tanımlar
«Kullanıcı», hesap oluşturan veya Hizmeti kullanan gerçek kişidir. «İçerik», kullanıcının Hizmete yüklediği metin, yorum, beğeni, alıntı ve benzeri kayıtlardır. «Vibel», kullanıcının hesap içindeki sanal karakteridir. Politika, Hizmeti ziyaret eden ve hesap açmayan kişilerin teknik olarak işlenen verilerini de, ilgili olduğu ölçüde kapsar.

3. İşlenen kişisel veriler
Aşağıdakiler, Hizmetin mevcut sürümünde fiilen işlenen verilerdir.

3.1. Hesap
Ad ve soyad, kullanıcı adı, e-posta adresi, beyan edilen doğum tarihi, isteğe bağlı olarak Google hesabından gelen profil görseli adresi veya uygulama içi avatar anahtarı. E-posta ve doğum tarihi herkese açık profil belgesinde tutulmaz; kullanıcıya özel hesap kaydında saklanır. Kullanıcı adı ile girişin çalışması için e-posta, kullanıcı adı kaydında da bulunabilir. Bu sürümde cihazdan fotoğraf veya video dosyası yüklenmez ve Firebase Storage kullanılmaz.

3.2. İçerik ve sosyal işlem
Gönderi metni, yorum, beğeni, alıntı kaydı ve anlık görüntüsü, etiket, bahsetme ve çözümlenen kullanıcı kimlikleri, takip ve takip isteği kayıtları, herkese açık veya gizli hesap tercihi.

3.3. Mesajlaşma
On sekiz yaşını doldurmuş hesaplar arasındaki mesaj metinleri, iletilen gönderi kayıtları ve sohbet üst verisi (katılımcılar, son mesaj özeti, sessize alma ve gizleme). On beş ile on yedi yaş arasındaki hesaplarda mesaj kutusu sunulmaz.

3.4. Vibel
Karakterin adı ve rengi, seviye, gelişim puanı, sanal vil birimi, belirli seviyeden sonra tokluk, enerji, mutluluk, uyku ve ilgili zaman damgaları, haftalık görev sayaçları. Bunlar oyun kaydıdır; sağlık verisi olarak işlenmez.

3.5. Güvenlik, destek ve moderasyon
Kimlik doğrulama oturumu; Google veya Apple ile giriş seçildiyse ilgili sağlayıcının oturum kimliği; App Check ve mobil Crashlytics tanı kayıtları; destek talebinin konusu, metni, kullanıcı kimliği ve durumu; şikayet ve engelleme kayıtları; hesap silinirken isteğe bağlı bırakılan geri bildirim. Destek kaydına uygulama sürümü yazılabilir.

3.6. Reklam ve çerez
On sekiz yaşını doldurmuş hesaplarda, Android akışında Google AdMob ve giriş yapılmış web akışında Google AdSense bir reklam isteği oluşturabilir. Bu istek kapsamında Google; IP adresi, tarayıcı veya cihaz bilgisi, çerez ve Android’de reklam kimliği gibi teknik verileri kendi şartlarına göre işleyebilir. MyVibel bu verileri kendi veritabanında reklam profili olarak saklamaz. Ayrı bir rıza yönetim ekranı bu sürümde yoktur. On sekiz yaşını doldurmamış hesaplarda reklam gösterilmez. Firebase Analytics ve pazarlama e-postası yoktur. Uzak anlık bildirim (FCM) cihaz belirteci saklanmaz; Vibel hatırlatmaları cihazda yerel olarak planlanır.

4. Amaçlar ve hukuki sebepler
Kayıttaki onay kutusu, Kullanım Koşulları ile bu politikanın okunduğunun kabulüdür. Bu kabul, her işleme için 6698 sayılı Kanun anlamında açık rıza değildir.

• Sözleşmenin kurulması ve ifası: hesap, profil, akış, keşfet, bildirim kaydı, on sekiz yaş üstü mesajlaşma ve Vibel mekanikleri.
• Hukuki yükümlülük: yaş grubuna göre kısıt, saklama ve yetkili merci taleplerinin yerine getirilmesi.
• Meşru menfaat: güvenliğin sağlanması, spam ve kötüye kullanımın önlenmesi, şikayet incelemesi, hizmetin ayakta tutulması ve hata tanısı. Bu menfaat, ilgili kişinin temel hak ve özgürlüklerine üstün gelmez.
• Açık rıza: bu sürümde MyVibel tarafından ayrıca alınan bir reklam rızası yoktur. Kişiselleştirilmiş reklam profillemesi MyVibel tarafından yürütülmez. Google’ın kendi reklam kontrolleri, kullanıcının cihaz ve Google hesap ayarlarına tabidir.

5. Özel nitelikli veri
Irk, sağlık, biyometrik veri, din, sendika veya ceza mahkûmiyeti gibi özel nitelikli veriler bilinçli olarak toplanmaz. Doğum tarihi yalnızca yaş grubunu belirlemek için işlenir. Kullanıcının içerik veya mesajına kendi isteğiyle yazdığı hassas bilgi, Hizmetin o içeriği yayımlaması veya iletmesi kapsamında ve kullanıcının kendi fiiliyle sınırlı kalır.

6. İçerik ve özel mesaj
Yayımlanan içerik, hesabın gizli olup olmamasına ve takip ilişkisine göre diğer kullanıcılarca görülebilir. Şikayet veya moderasyon incelemesinde içerik gizlenebilir veya kaldırılabilir. Hesap silindiğinde kullanıcının kendi gönderi ve yorumları silme akışına alınır. Başka kullanıcıların içeriklerinde kalan alıntı görüntüsü ile kopyalanmış ad veya avatar, teknik olarak kendiliğinden silinmeyebilir.
Özel mesajlar, Hizmetin sunulması için Cloud Firestore’da tutulur. Mesajların sürekli insan tarafından okunduğu bir ürün özelliği yoktur. Erişim; barındırma, güvenlik, kötüye kullanım şüphesi, kullanıcı şikayeti ve kanunen zorunlu hallerle sınırlıdır.

7. Aktarılan taraflar
Kişisel veriler satılmaz ve reklam havuzu olarak üçüncü kişilere devredilmez. Hizmetin işlemesi için veriler şu altyapı sağlayıcılarına, her biri kendi hizmetinin gerektirdiği ölçüde aktarılabilir:
• Google Firebase: kimlik doğrulama, Cloud Firestore, App Check
• Firebase Crashlytics: yalnızca mobil uygulama; web arayüzünde başlatılmaz
• Google veya Apple: kullanıcı o giriş yöntemini seçerse
• Google AdMob: on sekiz yaş üstü Android akışı
• Google AdSense: on sekiz yaş üstü ve giriş yapılmış web akışı
Bu taraflar, veri işleyen veya bağımsız veri sorumlusu sıfatını kendi hizmet şartlarına göre taşır. MyVibel, Google’ın reklam ilgisini kendi adına profillemez.

8. Yurt dışına aktarım
Firebase ve Google hizmetleri veriyi Türkiye dışında barındırabilir. Aktarım, sözleşmenin ifası ve Hizmetin teknik olarak sunulması için zorunludur. Güvence, Google’ın yürürlükteki veri işleme şartlarıdır. Standart sözleşme veya Kurul izni gibi aracın somut metni, usulüne uygun talep üzerine ve elde bulunduğu ölçüde açıklanır. Aktarım aracının bir örneği kamuya bu metinle birlikte eklenmemiştir.

9. Saklama ve silme
Hesap açık olduğu sürece veriler, Hizmetin sunulması için gerekli süre boyunca saklanır. Profil → Ayarlar → Hesabı Sil ile kimlik doğrulama hesabı, profil, kullanıcı adı kaydı, kullanıcının gönderileri, beğenileri, silinebilen yorumları, katıldığı sohbetler, takip ve engel kayıtları ile ilgili şikayet ve destek kayıtları silinmeye çalışılır. Bir adım hata verirse silme diğer adımlarla sürer. İşlem geri alınamaz.
Silme sonrasında kalabilecek kayıtlar: hesap silme geri bildirimi; başkalarının içeriğindeki alıntı görüntüsü; teknik artık kayıt; Crashlytics’te daha önce oluşmuş hata kaydı; cihazda kalan yerel tercih.
Destek, KVKK ve şikayet kayıtları ile hesap silme geri bildirimi, kapanıştan veya oluşumdan itibaren en geç yirmi dört ay içinde silinir veya kimlikten arındırılır. Üçüncü tarafın kendi saklama süresi bu süreye tabi olmayabilir. Ayrı bir anonimleştirme yazılımı yoktur.

10. Çocuklar ve yaş
Hizmet, on beş yaşını doldurmamış kişilere yönelik değildir ve bu kişilere sunulmaz. Doğum tarihi kullanıcı beyanıdır. Tarih seçici ve sunucu kontrolü on beş yaş altını reddeder. Bu kontrol, nüfus kaydı veya e-Devlet doğrulaması değildir. Beyanı on beş yaş altı olan mevcut hesap girişte kilitlenir.
On beş ile on yedi yaş arasındaki hesap kısıtlıdır. Ayrıntı: https://myvibel.com/cocuk-guvenligi.html
On sekiz yaşın dolduğu hesap, tam özellikli hesaba geçer. Yaş veya hesap kararına itiraz, Destek formundaki «Yaş / hesap itirazı» ile yapılır ve otomatik sonuçlanmaz. Yaş sınırı, Kanun’dan doğan diğer yükümlülükleri kaldırmaz.

11. Çerezler
Yasal sayfalarda analitik çerez kullanılmaz. Oturumun sürmesi için tarayıcı, Firebase Authentication’ın işlevsel çerez veya yerel kaydını tutabilir. Şifre sıfırlama sayfası bu amaçla Firebase betiğini yükler. Giriş yapılmış web akışında AdSense, reklam çerezi yerleştirebilir. Ana sayfadaki AdSense doğrulama betiği, reklam birimi göstermese de Google alanına istek yapabilir. Uygulama içi web görünümü aynı Firebase projesini kullanır.

12. Güvenlik
Erişim, kimlik doğrulama ve veritabanı kuralları ile sınırlandırılır. Hiçbir elektronik sistemin mutlak güvenli olduğu taahhüt edilmez. İhlal şüphesi, mevzuatın gerektirdiği ölçüde ilgili kişiye ve Kişisel Verileri Koruma Kurulu’na bildirilir.

13. Haklar ve başvuru
Kanun’un 11. maddesindeki haklar KVKK Aydınlatma Metni’nde sayılmıştır: https://myvibel.com/kvkk.html
Başvuru, destek formu ile yapılır. Kimliğin doğrulanması istenebilir. Başvuru, talebin veri sorumlusuna ulaşmasından itibaren en geç otuz gün içinde sonuçlandırılır. İşlemin ayrıca bir maliyeti doğması halinde, Kurul’un tarifesindeki ücret istenebilir. Başvurunun reddi, süresinde cevap verilmemesi veya cevabın yetersiz görülmesi halinde ilgili kişi, Kişisel Verileri Koruma Kurulu’na şikâyet hakkını kullanabilir.
Yaş grubuna göre özelliğin açılıp kapanması, beyan edilen doğum tarihine dayalı bir kuraldır. Bu kural aleyhe hukuki sonuç doğurduğunda itiraz, aynı destek formu ile yapılır.

14. Değişiklik
Politika güncellenebilir. Önemli değişiklik, uygulama içi duyuru veya bu sayfanın yeni sürümü ile duyurulur. Yürürlükteki sürüm: $surum, $guncellemeTarihi. Hizmeti kullanmaya devam etmek, güncel metnin okunduğu anlamına gelir. Emredici hükümler, metindeki değişiklikle daraltılamaz.
''';

  static const kvkkBaslik = 'KVKK Aydınlatma Metni';

  static const kvkkMetni = '''
6698 sayılı Kişisel Verilerin Korunması Kanunu’nun 10. maddesi uyarınca, veri sorumlusunun aydınlatma yükümlülüğü kapsamında aşağıdaki hususlar bildirilir. İşbu metin, Gizlilik Politikası ile birlikte uygulanır. Çelişki halinde emredici kanun hükmü esas alınır.

1. Veri sorumlusunun kimliği
Veri sorumlusu, «$veriSorumlusu» markası ile Hizmeti işleten gerçek kişidir. Ticaret şirketi yoktur. Kamuya açık başvuru adresi destek@myvibel.com adresidir. Ev adresi yayımlanmaz.
Başvuru mercii: destek@myvibel.com, uygulama içi Profil → Destek ve Geri Bildirim (konu: KVKK) ve https://myvibel.com/kvkk.html . Usulüne uygun başvuruda tebligata elverişli kimlik ve adres ayrıca verilir.

2. İşlenen kişisel veriler
Kimlik (ad, soyad, kullanıcı adı, beyan edilen doğum tarihi), iletişim (e-posta), profil görseli adresi veya avatar anahtarı, işlem güvenliği kayıtları (oturum, App Check, mobil Crashlytics), kullanıcı içeriği (gönderi, yorum, beğeni, alıntı, etiket, bahsetme, takip), on sekiz yaş üstü mesajlar, şikayet ve engel kayıtları, destek talepleri, Vibel oyun kaydı ve isteğe bağlı hesap silme geri bildirimi. Fotoğraf veya video dosyası yüklenmez. Ayrıntılı döküm Gizlilik Politikası’ndadır.

3. Amaç
Üyeliğin kurulması ve Hizmetin ifası; sosyal akış, keşfet, bildirim ve Vibel mekaniklerinin işletilmesi; bilgi güvenliği, moderasyon ve kötüye kullanımın önlenmesi; başvuru ve şikayetlerin sonuçlandırılması; hatanın giderilmesi ve Hizmetin sürekliliği; on sekiz yaş üstü hesaplarda reklamın Google aracılığıyla gösterilmesi.

4. Hukuki sebep
Kanun’un 5. maddesi: bir sözleşmenin kurulması veya ifası için gerekli olması; veri sorumlusunun hukuki yükümlülüğü; ilgili kişinin temel hak ve özgürlüklerine zarar vermemek kaydıyla meşru menfaat. Kullanım koşullarının kabulü, her işleme için açık rıza değildir. Bu sürümde ayrıca bir reklam rızası alınmamaktadır. On sekiz yaş altı hesapta reklam gösterilmez. Özel nitelikli veri bilinçli olarak işlenmez; bu nedenle Kanun’un 6. maddesine dayalı bir açık rıza alınmaz.

5. Aktarım
Veriler, Hizmetin barındırılması için Google Firebase’e; seçilen giriş yöntemine göre Google veya Apple’a; on sekiz yaş üstü reklam için Google AdMob veya AdSense’e aktarılabilir. Aktarım yurt dışında gerçekleşebilir. Amaç, Hizmetin ifasıdır. Güvence, ilgili sağlayıcının veri işleme şartlarıdır. Aktarılan tarafın kimliği ve güvencenin somut metni, Kanun’un 11. maddesi kapsamındaki taleple ve elde bulunduğu ölçüde açıklanır.

6. Toplama yöntemi
Veriler elektronik ortamda, kayıt ve giriş formları, seçilen kimlik sağlayıcısı, uygulama içi işlemler, destek ve şikayet formları ile güvenlik ve hata kayıtları yoluyla toplanır. Tamamen otomatik bir karar, beyan edilen doğum tarihine göre yaş grubu kuralıdır. Bu kurala itiraz destek formundan yapılır.

7. Saklama
Veri, hesabın açık olduğu süre ve işleme amacının gerektirdiği süre boyunca saklanır. Hesap silme akışı Gizlilik Politikası’nda tarif edilmiştir. Destek, KVKK, şikayet ve hesap silme geri bildirimi en geç yirmi dört ay içinde silinir veya kimlikten arındırılır. Zamanaşımı veya devam eden bir uyuşmazlık varsa, ilgili kayıt o süreçle sınırlı olarak daha uzun tutulabilir.

8. İlgili kişinin hakları
Kanun’un 11. maddesi uyarınca ilgili kişi;
• kişisel verisinin işlenip işlenmediğini öğrenme,
• işlenmişse buna ilişkin bilgi talep etme,
• işlenme amacını ve amaca uygun kullanılıp kullanılmadığını öğrenme,
• yurt içinde veya yurt dışında aktarıldığı üçüncü kişileri bilme,
• eksik veya yanlış işlenmişse düzeltilmesini isteme,
• Kanun’un 7. maddesinde öngörülen şartlar çerçevesinde silinmesini veya yok edilmesini isteme,
• düzeltme ve silmenin aktarıldığı üçüncü kişilere bildirilmesini isteme,
• münhasıran otomatik sistemler vasıtasıyla aleyhe bir sonucun ortaya çıkmasına itiraz etme,
• kanuna aykırı işleme sebebiyle zarara uğraması halinde zararın giderilmesini talep etme
haklarına sahiptir.

9. Başvurunun usulü
Başvuru Türkçe yapılır ve kimliği ortaya koyar. Destek formu yeterlidir. Veri sorumlusu, talebi en geç otuz gün içinde sonuçlandırır. Başvurunun ayrıca bir maliyet gerektirmesi halinde Kurul tarifesi uygulanabilir. Başvurunun reddi, süresinde cevap verilmemesi veya cevabın yetersiz bulunması halinde ilgili kişi, cevabı öğrendiği tarihten itibaren otuz ve her hâlde başvuru tarihinden itibaren altmış gün içinde Kişisel Verileri Koruma Kurulu’na şikâyette bulunabilir.

10. Yürürlük
Metin, uygulama içinde ve https://myvibel.com/kvkk.html adresinde yayımlanır. Sürüm $surum, $guncellemeTarihi.
''';

  static const kullanimKosullariBaslik = 'Kullanım Koşulları';

  static const kullanimKosullariMetni = '''
İşbu Kullanım Koşulları, $uygulamaAdi Hizmetini indiren, kayıt olan veya kullanan kişi ile Hizmeti işleten gerçek kişi arasında kurulur. Kayıt sırasında onay kutusu, işbu koşulların okunup kabul edildiği anlamına gelir. Koşullar, kişisel verilerin işlenmesine ilişkin aydınlatmanın yerini tutmaz. Tüketici sıfatını haiz kullanıcı bakımından 6502 sayılı Kanun’un emredici hükümleri saklıdır.

1. Hizmet tanımı
$uygulamaAdi; sosyal paylaşım (metin gönderi, yorum, beğeni, alıntı), mesajlaşma, keşfet, bildirim kayıtları ve Vibel karakteriyle oyunlaştırma sunan bir platformdur. Mevcut sürümde kullanıcıdan fotoğraf/video yükleme özelliği yoktur.

2. Hesap oluşturma ve güvenlik
• Kayıt için doğru bilgi vermek sizin sorumluluğunuzdadır.
• Şifrenizi gizli tutmalısınız; hesabınızdaki faaliyetlerden öncelikle siz sorumlusunuz.
• E-posta ile kayıtta doğrulama süreci uygulanabilir; Google veya Apple ile girişte ilgili hesap bağlanır ve gerekirse şifre belirlemeniz istenebilir.
• Hesabınızı başkasına kullandırmayın; yetkisiz erişim şüphesinde destek formundan bildirin.

3. Yaş sınırı
15 yaşını doldurmadıysanız MyVibel’i kullanmamalısınız. Kayıt sırasında doğum tarihi beyanı ve tarih seçici ile 15 yaş kontrolü yapılır; bu resmi kimlik veya e-Devlet doğrulaması değildir.
15–17 yaşındaki hesaplar gizli tutulur; mesaj kutusu, akış reklamı, kullanıcı önerisi ve otomatik sonsuz kaydırma kapalıdır. Ebeveyn günlük süre sınırı (varsayılan 90 dk) ve PIN cihaz üzerindedir. Bu kısıtlar 18 yaşında kalkar. Ayrıntı: https://myvibel.com/cocuk-guvenligi.html
Yaş / hesap kararına Destek formundan itiraz edilebilir.

4. Kullanıcı içeriği ve yasaklı davranışlar
Aşağıdakiler yasaktır:
• Yasa dışı içerik
• Hakaret, taciz, tehdit, stalking
• Nefret söylemi, ayrımcılık
• Cinsel / müstehcen veya istismara yönelik içerik
• Spam, yanıltıcı etkileşim, otomatik kötüye kullanım
• Telif veya sınai mülkiyet ihlali
• Başkasının kişisel verisini izinsiz paylaşma
• Sahte hesap, kimlik taklidi, başkasını temsil etme
• Güvenlik açıklarını istismar etme, hizmeti bozma

5. İçerik lisansı (fikri mülkiyet — kullanıcı tarafı)
• Paylaştığınız içeriğin mülkiyeti sizdedir; MyVibel içeriğinizin mülkiyetini devralmaz.
• Hizmeti sunabilmek için bize; münhasır olmayan, ücretsiz, dünya çapında, hizmetin işletilmesi için gerekli kapsamda (barındırma, iletme, görüntüleme, teknik kopyalama, önbellekleme, moderasyon amacıyla inceleme) sınırlı bir kullanım lisansı verirsiniz.
• Bu lisans, hesabınızı sildiğinizde veya içeriği kaldırdığınızda, teknik yedekler ve yasal zorunluluklar saklı kalmak üzere, hizmetin sunulması ihtiyacıyla sınırlı şekilde sona erer / uygulanmaz hale gelir.

6. Platform fikri mülkiyeti
Uygulama tasarımı, marka, yazılım ve MyVibel’a ait görseller $veriSorumlusu’a aittir. İzinsiz kopyalama, tersine mühendislik veya marka kullanımı yasaktır.

7. Moderasyon, şikayet ve yaptırım
• Gönderi / kullanıcı / yorum için «Şikayet Et» ve engelleme özellikleri vardır.
• İnceleme sonucunda içerik gizlenebilir veya kaldırılabilir; hesap uyarılabilir, kısıtlanabilir veya kapatılabilir.
• Acil güvenlik veya ağır ihlallerde önceden bildirim yapılmadan işlem yapılabilir.
• İtiraz / açıklama için Destek ve Geri Bildirim formunu kullanabilirsiniz; bu otomatik bir geri alma garantisi vermez.

8. Özel mesajlar
Mesajlaşma özelliği 18 yaşını doldurmuş kullanıcılar içindir. 15–17 yaşındaki hesaplarda mesaj kutusu sunulmaz. Spam, taciz veya yasa dışı içerik için şikayet / engelleme kullanılabilir. Hesap silindiğinde ilgili sohbetler silme akışına dahil edilebilir (karşı tarafın erişimi de etkilenebilir).

9. Vibel, vil ve sanal öğeler
• Vil, seviye, tokluk, enerji, gelişim puanı ve benzeri unsurlar sanal oyun mekanikleridir; gerçek para birimi değildir, nakde çevrilemez ve (mevcut sürümde) satılamaz / devredilemez.
• Kurallar ve maliyetler güncellemelerle değişebilir.
• İleride gerçek paralı satın alma eklenirse koşullar ayrıca güncellenir; bu sürüm böyle bir ödemeyi kapsamaz.

10. Gizlilik
Kişisel veriler «Gizlilik Politikası» ve «KVKK Aydınlatma Metni» kapsamında işlenir. Koşulları kabul etmek, KVKK’daki her işleme için ayrı açık rıza vermek anlamına gelmez. KVKK başvuruları https://myvibel.com/kvkk.html üzerinden yapılır.

11. Hizmet değişiklikleri
Özellikler güncellenebilir, geçici durdurulabilir veya sonlandırılabilir. Önemli değişiklikler duyurulmaya çalışılır; acil güvenlik güncellemeleri derhal uygulanabilir.

12. Hesap silme
Profil → Ayarlar → Hesabı Sil. İşlem geri alınamaz. Silme; Auth hesabı ve kodda tanımlı ilişkili Firestore verilerini hedefler. Bazı denormalize / geri bildirim / teknik kayıtlara ilişkin sınırlar Gizlilik Politikası’nda açıklanır.

13. Fikri hak ihlali bildirimi
Eser sahibi veya yetkili temsilcisi, ihlal iddiasını destek formu ile bildirir. Bildirimde eser, ihlal edilen kayıt ve iletişim bilgisi bulunur. Yeterli bildirim üzerine içerik erişime kapatılabilir. Karşı bildirim halinde içerik, mevzuatın izin verdiği çerçevede yeniden açılabilir. Kötüniyetli bildirim, bildirenin sorumluluğundadır.

14. Askıya alma ve fesih
Hizmeti işleten, koşulların ihlali, güvenlik riski veya yasal zorunluluk halinde hesabı uyararak veya ağır ihlalde uyarmadan kısıtlayabilir, içeriği kaldırabilir veya hesabı kapatabilir. Kullanıcı, hesabını Profil → Ayarlar → Hesabı Sil ile her zaman ve gerekçe göstermeksizin kapatabilir. Kapanış geri alınmaz. Fesih, doğmuş yükümlülükleri ve saklanması kanun gereği süren kayıtları ortadan kaldırmaz.

15. Sorumluluk
Hizmet, mevcut haliyle sunulur. Kesintisiz, hatasız veya belirli bir amaca tam uygunluk taahhüt edilmez. Kullanıcılar arasındaki uyuşmazlık, öncelikle tarafların kendi uyuşmazlığıdır. Yasa dışı içerikten içeriği oluşturan kullanıcı sorumludur.
Hizmeti işletenin kusurundan doğan zararda, zorunlu hukukun izin verdiği ölçüde ve tüketici işlemi bakımından emredici hükümler saklı kalmak üzere, sorumluluk ilgili kullanıcının son on iki ayda Hizmet için fiilen ödediği bedelle sınırlıdır. Hizmet bu sürümde bedelsizdir. Kast ve ağır kusur ile bedensel zarar bu sınırın dışındadır.

16. Kullanıcının tazmin yükümlülüğü
Kullanıcı, kendi içeriği, hesabının üçüncü kişiye kullandırılması veya koşulların ihlali nedeniyle Hizmeti işletene yönelen üçüncü kişi taleplerini, emredici hukuk saklı kalmak üzere, karşılamayı kabul eder.

17. Mücbir sebep
Doğal afet, savaş, yaygın altyapı kesintisi, sağlayıcı kesintisi veya kamu tasarrufu gibi makul kontrol dışındaki olaylarda ifa, olay süresince askıda kalır.

18. Devir
Kullanıcı, hesabı veya işbu sözleşmeden doğan haklarını devredemez. Hizmeti işleten, Hizmetin devamı için sözleşmedeki konumunu bir gerçek veya tüzel kişiye devredebilir; kişisel veriler bakımından aydınlatma güncellenir.

19. Bölünebilirlik ve feragat
Bir hükmün geçersizliği, diğer hükümleri geçersiz kılmaz. Hakkın kullanılmaması, haktan feragat değildir.

20. Uygulanacak hukuk ve uyuşmazlık
Uyuşmazlıkta Türkiye Cumhuriyeti hukuku uygulanır. Tüketici, yerleşim yerindeki tüketici mahkemesi ve tüketici hakem heyetine başvurabilir. Tüketici sıfatı bulunmayan uyuşmazlıklarda İstanbul mahkemeleri ve icra daireleri yetkilidir.

21. Bildirim ve bütünlük
Bildirimler destek@myvibel.com adresi, uygulama içi destek formu ve yayımlanan yasal sayfalar üzerinden yapılır. İşbu koşullar, Gizlilik Politikası ve KVKK Aydınlatma Metni, Hizmete ilişkin kullanıcı ile kurulmuş yazılı düzenlemenin tamamıdır. Önceki sözlü vaatler geçersizdir.
Güncelleme: $guncellemeTarihi. Sürüm $surum.
''';

  static const cocukGuvenligiBaslik = 'Çocuklara özgü hizmet ve yaş tedbirleri';

  static const cocukGuvenligiMetni = '''
İşbu metin, 5651 sayılı Kanun ve 10 Ekim 2026 tarihli yaş doğrulama düzenlemesi çerçevesinde, Hizmetin çocuk ve ergen hesaplarına uyguladığı tedbirleri bağlayıcı şekilde açıklar. Yaş, kayıtta beyan edilen doğum tarihine göre belirlenir. e-Devlet yaş belirteci, uygulamanın teknik kılavuzu yayımlanıncaya kadar kullanılmaz. Kimlik numarası toplanmaz.

1. Kimler kullanabilir
15 yaşını doldurmamış kişilere hizmet sunulmaz. Kayıt tarih seçicisi ve sunucu kontrolü 15 yaş altını reddeder. Beyanı 15 altı olan mevcut hesap girişte kilitlenir; Destek formundan itiraz edilebilir.

2. 15–17 yaş (kısıtlı hesap)
• Hesap gizlidir; açık hesaba çevrilemez.
• Özel mesaj kutusu kapalıdır (18 yaşında açılır).
• Akışta reklam gösterilmez.
• Kullanıcı önerisi ve @bahsetme kişi önerisi sunulmaz.
• Akış otomatik sonsuz kaydırılmaz; «Daha fazla göster» ile ilerlenir.
• Android’de ekran görüntüsü / kayıt zorlaştırılır.
• Canlı yayın, rehber eşleştirme ve konum paylaşımı yoktur (ürün zaten bunları sunmaz).
• Gerçek paralı satın alma yoktur; bu nedenle harcama onayı gerekmez.

3. Ebeveyn araçları
Cihaz üzerinde günlük kullanım süresi (varsayılan 90 dakika) ve isteğe bağlı ebeveyn PIN’i vardır. PIN ile süre değiştirilebilir veya günlük limit dolduğunda ek süre açılabilir. Bu araçlar çocuğun tüm konuşmalarını okuma hakkı vermez.

4. İtiraz
Yaş doğrulama, hesap kilidi, süre sınırı veya kısıtlı hesaba itiraz: Profil → Destek ve Geri Bildirim → «Yaş / hesap itirazı». Başvuru ücretsizdir; otomatik ret ile kapanmaz, insan inceler.

5. e-Devlet
Resmî yaş doğrulama belirteci, kılavuz yayımlanınca eklenecektir. Bu sürümde T.C. kimlik numarası, nüfus cüzdanı görüntüsü veya veli kimliği toplanmaz.

6. Çocuğa yönelik içerik ve bildirim
Çocuğun cinsel istismarına, çocuğun cinsel görüntüsüne veya çocuğu hedef alan tacize ilişkin içerik yasaktır. Tespit veya şikayet halinde içerik derhal erişime kapatılır, hesap kapatılabilir ve mevzuatın zorunlu kıldığı mercilere bildirim yapılır. On beş ile on yedi yaş arasındaki hesapta özel mesaj kapalı olduğundan, yetişkin kullanıcı bu hesapla özel yazışma başlatamaz.

7. Verinin sınırlanması
Kısıtlı hesapta reklam kimliği oluşturulmaz ve reklam isteği gönderilmez. Kişi önerisi ve bahsetme önerisi üretilmez. Ebeveyn PIN’i ve süre sayacı cihazda tutulur; veliye çocuğun gönderi veya etkileşim dökümü sunan bir izleme paneli yoktur.

Güncelleme: $guncellemeTarihi. Sürüm $surum.
''';

  static List<({String soru, String cevap})> get sss => const [
        (
          soru: 'Vibel nasıl gelişir?',
          cevap:
              '1–5. seviyede Vibel yumurtadır; gönderi (+10), yorum (+3), beğeni (+2) ve takip (+5) doğrudan gelişim puanı kazandırır. '
              '6. seviyede Vibel odası açılır: etkileşimler artık vil kazandırır, gelişim ise Vibel\'ini besleyerek (+15) sürer. '
              '11. seviyede enerji, uyku (uyanınca +40 gelişim) ve haftalık görevler; 21. seviyede mutluluk açılır.',
        ),
        (
          soru: 'Vil nedir?',
          cevap:
              '6. seviyeden itibaren gönderi (+10), yorum (+3), beğeni (+2) ve takip (+5) ile kazanılan sanal birimdir; gerçek para değildir. '
              'Vibel\'ine yemek (15 vil), karşılıklı takipteki bir arkadaşının Vibel\'ine yemek (20 vil) ve gönderi silmek (3 vil) için harcanır. '
              'Beğeniyi geri almak veya yorumu silmek 2 vil, takipten çıkmak 3 vil düşer.',
        ),
        (
          soru: 'Tokluk ve enerji ne işe yarar?',
          cevap:
              'Tokluk 6. seviyede açılır ve zamanla düşer; Vibel\'ini besleyince artar. Tokluk 3 gün boyunca sıfırda kalırsa Vibel yumurtaya döner. '
              'Enerji 11. seviyede açılır; paylaşım ve etkileşimler enerji harcar, enerji çok düşükse etkileşim kısıtlanır. '
              'Enerji %50 ve altındayken Vibel odasından uyutabilirsin; enerjisi dolunca kendiliğinden uyanır.',
        ),
        (
          soru: 'Gizli hesap ne yapar?',
          cevap:
              'Takipçin olmayan kullanıcılar gönderilerini ve takip listelerini göremez. '
              '15–17 yaşındaki hesaplar gizli kalır.',
        ),
        (
          soru: 'Yaş sınırı nedir?',
          cevap:
              'MyVibel 15 yaş ve üzeri içindir. 15–17 yaşında hesap gizli kalır; '
              'mesaj kutusu, reklam ve kullanıcı önerisi kapalıdır. 18 yaşında tam özellik açılır. '
              'Yaş, kayıtta seçtiğin doğum tarihine göredir; e-Devlet doğrulaması henüz yoktur.',
        ),
        (
          soru: 'Ebeveyn süresi nasıl çalışır?',
          cevap:
              '15–17 yaşında günlük varsayılan 90 dakika vardır. Ayarlar → Ebeveyn kontrolleri ile PIN ve süre belirlenir. '
              'Süre dolunca giriş kilitlenir; PIN ile ek süre açılabilir.',
        ),
        (
          soru: 'Bir gönderiyi nasıl şikayet ederim?',
          cevap:
              'Gönderi kartındaki menüden «Şikayet Et» seçeneğini kullan. '
              'KVKK ve genel destek için destek@myvibel.com adresine yaz veya Profil → Destek ve Geri Bildirim formunu doldur.',
        ),
        (
          soru: 'Hesabımı nasıl silerim?',
          cevap:
              'Profil → Ayarlar → Hesabı Sil. İşlem geri alınamaz; gönderi, mesaj ve profil verilerin silme akışına dahil edilir.',
        ),
      ];

  static const surumNotlari = '''
• Vibel gelişim puanı (gönderi/beğeni/yorum) yazım düzeltmesi
• Web masaüstü sohbet paneli (tam ekran yeni sohbet kapatıldı)
• 1–5 seviyede renk menüsü kapalı; gelişim çubuğu görünür
• Lider 1–2–3 taç ilk açılışta
• KVKK başvurusu kvkk.html yönlendirmesi
• Kullanıcı güncelleme paneli + moderatör sürüm notları
• Yaş sınırı 15+; 15–17 kısıtlı hesap, ebeveyn süresi, itiraz formu
''';

  static const kullaniciGuncellemeNotlari = '''
• Vibel artık paylaşım, beğeni ve yorumla gelişiyor; çubukta puanını görürsün.
• Web’de sohbetler sağ panelde açılır (tam ekran kaplamaz).
• KVKK metni ve başvuru tarayıcıdaki kvkk sayfasındadır.
• Yeni hesaplarda Vibel kısa bir turla uygulamayı tanıtır.
• 15 yaş altı kayıt olamaz; 15–17’de mesaj, reklam ve sonsuz kaydırma kapalıdır.
''';
}
