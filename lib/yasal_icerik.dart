// Türkçe yasal metin içerikleri (uygulama + web hosting ile uyumlu).
// NOT: Hukuki tavsiye değildir. Avukat incelemesi önerilir.
// Geliştirici notları (kullanıcıya gösterilmez):
// - Ticaret şirketi yok / yakın vadede planlanmıyor; metinler buna göre yazıldı.
// - VERBİS yükümlülüğü faaliyet/muafiyete göre ayrı değerlendirilsin.
// - Firebase DPA ve md. 9 aktarım aracını hukuki dosyada sakla.
class YasalIcerik {
  YasalIcerik._();

  static const guncellemeTarihi = '8 Kasım 2026';
  static const surum = '1.0.0';
  static const uygulamaAdi = 'MyVibel';

  /// Marka adı. Ticaret şirketi yoktur; tüzel kişi unvanı yayımlanmaz.
  static const veriSorumlusu = 'MyVibel';

  /// Hizmeti işleten gerçek kişi (KVKK md. 10 kimlik bilgisi).
  static const veriSorumlusuAdi = 'Rana Rümeysa Türkan';

  /// Her metnin başında gösterilen «Kısaca» özeti; bağlayıcı olan tam metindir.
  static const ozetNotu =
      'Bu özet kolaylık içindir; bağlayıcı olan aşağıdaki tam metindir.';

  static const gizlilikOzet = <String>[
    'Hesabın için adını, kullanıcı adını, e-postanı ve doğum tarihini; paylaştığın gönderi, yorum, beğeni ve mesajları işliyoruz.',
    'E-postan ve doğum tarihin profilinde görünmez.',
    'Verilerin satılmaz. Hizmetin çalışması için Google’ın Firebase altyapısında saklanır; sunucular yurt dışında olabilir.',
    'Reklam yalnızca 18 yaş üstü kullanıcılara Google aracılığıyla gösterilir. 18 yaşından küçüklere reklam gösterilmez.',
    'Özel mesajlarını kimse sürekli okumaz; yalnızca şikayet, güvenlik veya kanuni zorunluluk halinde bakılabilir.',
    'Hesabını istediğin zaman Profil → Ayarlar → Hesabı Sil ile silebilirsin.',
    'Veri sorumlusu $veriSorumlusuAdi’dır. Soruların ve KVKK başvuruların için: destek@myvibel.com',
  ];

  static const kvkkOzet = <String>[
    'Bu metin, KVKK’nın zorunlu tuttuğu bilgilendirmedir. Veri sorumlusu $veriSorumlusuAdi’dır.',
    'Verilerin; hesabını açmak, Hizmeti çalıştırmak, güvenliği sağlamak ve şikayetleri incelemek için işlenir.',
    'Hukuki sebepler: sözleşme, kanuni yükümlülük ve meşru menfaat.',
    'Verilerin Google altyapısına aktarılır (yurt dışı olabilir); satılmaz.',
    'Verilerine ne olduğunu öğrenme, düzeltilmesini ve silinmesini isteme hakkın var.',
    'Başvuru: destek@myvibel.com veya uygulamadaki Destek formu (konu: KVKK). En geç 30 gün içinde cevap verilir.',
  ];

  static const kosullarOzet = <String>[
    'MyVibel 15 yaş ve üzeri içindir; 15–17 yaşındaki hesaplar kısıtlıdır.',
    'Hakaret, taciz, nefret söylemi, müstehcen içerik, spam ve sahte hesap yasaktır.',
    'Paylaştığın içerik senindir; MyVibel onu yalnızca Hizmeti çalıştırmak için kullanır.',
    'Kurallara uymayan içerik kaldırılabilir, hesap kısıtlanabilir veya kapatılabilir; itiraz edebilirsin.',
    'Vil ve Vibel puanları sanal oyun öğesidir; gerçek para değildir.',
    'Hizmet ücretsizdir ve olduğu gibi sunulur; kesintisiz çalışacağı garanti edilmez.',
    'Hesabını istediğin zaman silebilirsin.',
  ];

  static const cocukOzet = <String>[
    '15 yaşından küçükler MyVibel’i kullanamaz.',
    '15–17 yaşındaki hesaplar her zaman gizlidir; mesajlaşma, reklam ve kişi önerisi kapalıdır.',
    'Yetişkin kullanıcılar 15–17 yaşındaki bir kullanıcıya özel mesaj gönderemez.',
    'Ebeveynler cihazda günlük süre sınırı (varsayılan 90 dakika) ve PIN belirleyebilir.',
    'Kimlik numarası veya kimlik fotoğrafı istenmez; yaş, kayıtta seçilen doğum tarihine göre belirlenir.',
    'Kararlara Destek formundan itiraz edilebilir; itirazları bir kişi inceler.',
  ];

  static const gizlilikBaslik = '$uygulamaAdi Gizlilik Politikası';

  static const gizlilikMetni = '''
Bu Gizlilik Politikası, $uygulamaAdi uygulamasını ve aynı hizmetin web sürümü olan https://myvibel.com adresini («Hizmet») kullananların kişisel verilerinin nasıl işlendiğini anlatır. Metin, Hizmetin bugün çalışan sürümünü anlatır ve Kullanım Koşulları ile KVKK Aydınlatma Metni ile birlikte geçerlidir. Kişisel verilerle ilgili bir çelişki olursa KVKK Aydınlatma Metni ve kanunun zorunlu hükümleri esas alınır.

1. Veri sorumlusu
Veri sorumlusu $veriSorumlusuAdi’dır. Hizmet, «$veriSorumlusu» adıyla bu gerçek kişi tarafından işletilir. Hizmetin arkasında bir şirket, dernek veya başka bir tüzel kişi yoktur; bu yüzden ticaret unvanı, MERSİS veya vergi numarası yayımlanmaz.
İletişim ve KVKK başvuruları için adres: destek@myvibel.com. Başvuru, uygulamada Profil → Destek ve Geri Bildirim formundan konu olarak KVKK başvurusu seçilerek de yapılabilir (ayrıntı: https://myvibel.com/kvkk.html). Usulüne uygun bir başvuruda veya yetkili bir resmi kurum istediğinde, resmi yazışmaya uygun adres bilgisi ayrıca verilir. Ev adresi yayımlanmaz.

2. Kapsam ve tanımlar
«Kullanıcı»: hesap açan veya Hizmeti kullanan kişi. «İçerik»: kullanıcının paylaştığı metin, yorum, beğeni, alıntı ve benzeri kayıtlar. «Vibel»: hesaptaki sanal karakter. Bu politika, hesap açmadan siteyi ziyaret edenlerin teknik olarak işlenen verilerini de kapsar.

3. Hangi verileri işliyoruz
Aşağıdakiler, Hizmetin bugünkü sürümünde gerçekten işlenen verilerdir.

3.1. Hesap
Ad soyad, kullanıcı adı, e-posta, kayıtta beyan edilen doğum tarihi; Google ile girişte Google profil fotoğrafının adresi veya uygulamada seçilen avatar. E-posta ve doğum tarihi herkese açık profilde görünmez; yalnızca kullanıcıya özel hesap kaydında tutulur. Kullanıcı adıyla giriş yapılabilmesi için e-posta, kullanıcı adı kaydında da bulunabilir. Bu sürümde cihazdan fotoğraf veya video yüklenmez ve Firebase Storage kullanılmaz.

3.2. İçerik ve sosyal işlemler
Gönderi metni, yorum, beğeni, alıntılar ve alıntılanan gönderinin bir kopyası, etiketler, bahsetmeler (@) ve bahsedilen kullanıcıların kimlikleri, takip ve takip istekleri, hesabın açık veya gizli olma tercihi.

3.3. Mesajlaşma
18 yaşını doldurmuş kullanıcılar arasındaki mesajlar, iletilen gönderiler ve sohbet bilgileri (katılımcılar, son mesaj özeti, sessize alma ve gizleme). 15–17 yaşındaki hesaplarda mesajlaşma yoktur.

3.4. Vibel
Karakterin adı ve rengi, seviyesi, gelişim puanı, vil (sanal birim); ilerleyen seviyelerde tokluk, enerji, mutluluk ve uyku bilgileri ile zamanları, haftalık görev sayaçları. Bunlar oyun kaydıdır, sağlık verisi değildir.

3.5. Güvenlik, destek ve moderasyon
Oturum bilgisi; Google veya Apple ile giriş yapıldıysa o hizmetin oturum kimliği; App Check kayıtları ve (yalnızca mobil uygulamada) Crashlytics hata kayıtları; destek taleplerinin konusu, metni, kullanıcı kimliği ve durumu; şikayet ve engelleme kayıtları; hesap silinirken isteğe bağlı bırakılan geri bildirim. Destek kaydına uygulama sürümü de yazılabilir.

3.6. Reklam ve çerezler
Reklam yalnızca 18 yaşını doldurmuş kullanıcılara gösterilir: Android uygulamasında Google AdMob ile, web sitesinde ise giriş yapılmış akışta Google AdSense ile. Google’ın reklam kodu yalnızca bu durumda yüklenir; tanıtım sayfasında, giriş ekranında ve yasal sayfalarda yüklenmez. Reklam gösterilirken Google; IP adresi, tarayıcı veya cihaz bilgisi, çerez ve Android’de reklam kimliği gibi teknik verileri kendi kurallarına göre işleyebilir. MyVibel bu verileri kendi veritabanında saklamaz ve reklam profili çıkarmaz. Bu sürümde ayrı bir reklam onayı ekranı yoktur. 18 yaşından küçük hesaplara reklam gösterilmez. Firebase Analytics kullanılmaz ve pazarlama e-postası gönderilmez. Uzaktan bildirim (FCM) için cihaz kimliği saklanmaz; Vibel hatırlatmaları cihazın kendisinde planlanır.

4. Verileri neden ve hangi hukuki sebeple işliyoruz
Kayıttaki onay kutusu, Kullanım Koşulları ile bu politikanın okunduğunu gösterir. Bu onay, KVKK anlamında her işlem için verilmiş bir açık rıza değildir.
• Sözleşmenin kurulması ve yerine getirilmesi: hesap, profil, akış, keşfet, bildirimler, 18 yaş üstü mesajlaşma ve Vibel özellikleri.
• Kanuni yükümlülük: yaşa göre kısıtlamalar, kayıtların saklanması ve resmi kurumların taleplerinin karşılanması.
• Meşru menfaat: güvenlik, spam ve kötüye kullanımın önlenmesi, şikayetlerin incelenmesi, Hizmetin çalışır tutulması ve hataların giderilmesi. Bu menfaat, kişinin temel hak ve özgürlüklerinin önüne geçmez.
• Açık rıza: bu sürümde MyVibel ayrıca reklam onayı almaz ve kişiselleştirilmiş reklam profili çıkarmaz. Google’ın reklam tercihleri, kullanıcının kendi cihaz ve Google hesabı ayarlarından yönetilir.

5. Hassas (özel nitelikli) veriler
Irk, sağlık, biyometrik veri, din, sendika üyeliği veya ceza mahkûmiyeti gibi hassas veriler bilerek toplanmaz. Doğum tarihi yalnızca yaş grubunu belirlemek için kullanılır. Kullanıcı bir gönderiye veya mesaja kendi isteğiyle hassas bir bilgi yazarsa, bu bilgi yalnızca o içeriğin yayımlanması veya iletilmesi için işlenir.

6. İçerikler ve özel mesajlar
Paylaşılan içeriği kimlerin görebileceği, hesabın gizli olup olmamasına ve takip ilişkisine bağlıdır. Şikayet veya moderasyon incelemesi sonucunda içerik gizlenebilir veya kaldırılabilir. Hesap silindiğinde kullanıcının kendi gönderileri ve yorumları silinir; ancak başka kullanıcıların gönderilerinde kalan alıntılar ve oralara kopyalanmış ad veya avatar kendiliğinden silinmeyebilir.
Özel mesajlar, Hizmetin çalışması için Cloud Firestore veritabanında saklanır. Mesajları sürekli okuyan bir kişi veya özellik yoktur. Mesajlara yalnızca barındırma, güvenlik, kötüye kullanım şüphesi, kullanıcı şikayeti veya kanuni zorunluluk hallerinde erişilir.

7. Veriler kimlerle paylaşılır
Kişisel veriler satılmaz ve reklam amacıyla başkalarına verilmez. Hizmetin çalışması için veriler, yalnızca gerektiği kadarıyla şu hizmet sağlayıcılara aktarılabilir:
• Google Firebase: giriş, veritabanı (Cloud Firestore), App Check
• Firebase Crashlytics: yalnızca mobil uygulama; web sitesinde kullanılmaz
• Google veya Apple: kullanıcı o giriş yöntemini seçerse
• Google AdMob: 18 yaş üstü, Android uygulaması
• Google AdSense: 18 yaş üstü, giriş yapılmış web akışı
Bu sağlayıcılar, kendi hizmet şartlarına göre veri işleyen veya bağımsız veri sorumlusu sayılır. MyVibel, Google adına reklam profili çıkarmaz.

8. Yurt dışına aktarım
Firebase ve diğer Google hizmetleri verileri Türkiye dışındaki sunucularda saklayabilir. Bu aktarım, sözleşmenin yerine getirilmesi ve Hizmetin teknik olarak çalışması için zorunludur. Güvence olarak Google’ın geçerli veri işleme şartları esas alınır. Standart sözleşme veya Kurul izni gibi aktarım belgesinin metni, usulüne uygun talep edilirse ve elde bulunduğu ölçüde paylaşılır; bu metne ayrıca eklenmemiştir.

9. Saklama ve silme
Hesap açık olduğu sürece veriler, Hizmetin sunulması için gerektiği kadar saklanır. Profil → Ayarlar → Hesabı Sil ile şunlar silinir: giriş hesabı, profil, kullanıcı adı kaydı, gönderiler, beğeniler, silinebilen yorumlar, katılınan sohbetler, takip ve engel kayıtları, ilgili şikayet ve destek kayıtları. Bir adım hata verirse diğer adımlar yine de çalışır. Silme geri alınamaz.
Silmeden sonra kalabilecekler: hesap silme geri bildirimi, başkalarının gönderilerindeki alıntılar, teknik artık kayıtlar, Crashlytics’te daha önce oluşmuş hata kayıtları ve cihazda kalan yerel ayarlar.
Destek, KVKK ve şikayet kayıtları ile hesap silme geri bildirimi, kapandıktan veya oluşturulduktan sonra en geç 24 ay içinde silinir ya da kimlikle ilişkisi kaldırılır. Üçüncü taraf hizmetlerin kendi saklama süreleri farklı olabilir. Ayrı bir anonimleştirme yazılımı kullanılmaz.

10. Çocuklar ve yaş
Hizmet 15 yaşından küçükler için değildir ve onlara sunulmaz. Doğum tarihi kullanıcının kendi beyanıdır. Kayıttaki tarih seçici ve sunucu kontrolü 15 yaş altını reddeder; bu kontrol nüfus kaydı veya e-Devlet doğrulaması değildir. Beyan edilen yaşı 15’ten küçük olan mevcut hesaplar girişte kilitlenir.
15–17 yaşındaki hesaplar kısıtlıdır. Ayrıntı: https://myvibel.com/cocuk-guvenligi.html
18 yaşını dolduran hesap tam özellikli hesaba geçer. Yaş veya hesap kararına itiraz, Destek formundaki «Yaş / hesap itirazı» ile yapılır; otomatik sonuçlanmaz, bir kişi inceler. Yaş sınırı, kanundan doğan diğer yükümlülükleri ortadan kaldırmaz.

11. Çerezler
Yasal sayfalarda ve tanıtım sayfasında analitik veya reklam çerezi kullanılmaz. Oturumun açık kalması için tarayıcı, Firebase Authentication’ın gerekli çerez veya yerel kayıtlarını tutabilir; şifre sıfırlama sayfası bunun için Firebase kodunu yükler. Giriş yapılmış 18 yaş üstü web akışında AdSense reklam çerezi yerleştirebilir. Tanıtım sayfasındaki Google doğrulama etiketi tek satırlık bir bilgidir; kod çalıştırmaz ve Google’a istek göndermez. Uygulama içindeki web görünümü de aynı Firebase projesini kullanır.

12. Güvenlik
Verilere erişim, giriş sistemi ve veritabanı kurallarıyla sınırlandırılır. Hiçbir elektronik sistem tamamen güvenli değildir. Bir veri ihlali şüphesinde, kanunun gerektirdiği ölçüde ilgili kişilere ve Kişisel Verileri Koruma Kurulu’na bildirim yapılır.

13. Haklar ve başvuru
KVKK’nın 11. maddesindeki haklar KVKK Aydınlatma Metni’nde sayılmıştır: https://myvibel.com/kvkk.html
Başvuru destek formuyla yapılır; kimlik doğrulaması istenebilir. Başvuru, bize ulaştıktan sonra en geç 30 gün içinde sonuçlandırılır. İşlem ayrıca bir maliyet gerektirirse Kurul’un belirlediği ücret istenebilir. Başvuru reddedilirse, süresinde cevap verilmezse veya cevap yetersiz bulunursa Kişisel Verileri Koruma Kurulu’na şikâyette bulunulabilir.
Hangi özelliklerin açık olacağı, beyan edilen doğum tarihine göre otomatik belirlenir. Bu kural kişinin aleyhine bir sonuç doğurursa aynı destek formundan itiraz edilebilir.

14. Değişiklikler
Politika güncellenebilir. Önemli değişiklikler uygulama içi duyuru veya bu sayfanın yeni sürümüyle duyurulur. Geçerli sürüm: $surum, $guncellemeTarihi. Hizmeti kullanmaya devam etmek, güncel metnin okunduğu anlamına gelir. Kanunun zorunlu hükümleri, metindeki değişikliklerle daraltılamaz.
''';

  static const kvkkBaslik = 'KVKK Aydınlatma Metni';

  static const kvkkMetni = '''
Bu metin, 6698 sayılı Kişisel Verilerin Korunması Kanunu’nun (KVKK) 10. maddesi gereğince, kişisel verilerinin nasıl işlendiği konusunda seni bilgilendirmek için hazırlanmıştır. Gizlilik Politikası ile birlikte geçerlidir. Bir çelişki olursa kanunun zorunlu hükümleri esas alınır.

1. Veri sorumlusu
Veri sorumlusu, Hizmeti «$veriSorumlusu» adıyla işleten gerçek kişi $veriSorumlusuAdi’dır; şirket yoktur. Herkese açık başvuru adresi destek@myvibel.com’dur. Ev adresi yayımlanmaz.
Başvuru yolları: destek@myvibel.com, uygulamada Profil → Destek ve Geri Bildirim (konu: KVKK) ve https://myvibel.com/kvkk.html. Usulüne uygun bir başvuruda, resmi yazışmaya uygun adres bilgisi ayrıca verilir.

2. Hangi veriler işleniyor
Kimlik (ad, soyad, kullanıcı adı, beyan edilen doğum tarihi), iletişim (e-posta), profil fotoğrafı adresi veya avatar, işlem güvenliği kayıtları (oturum, App Check, mobil uygulamada Crashlytics), kullanıcı içeriği (gönderi, yorum, beğeni, alıntı, etiket, bahsetme, takip), 18 yaş üstü kullanıcıların mesajları, şikayet ve engel kayıtları, destek talepleri, Vibel oyun kaydı ve isteğe bağlı hesap silme geri bildirimi. Fotoğraf veya video yüklenmez. Ayrıntılı liste Gizlilik Politikası’ndadır.

3. Hangi amaçlarla
Üyeliğin açılması ve Hizmetin sunulması; sosyal akış, keşfet, bildirim ve Vibel özelliklerinin çalışması; bilgi güvenliği, moderasyon ve kötüye kullanımın önlenmesi; başvuru ve şikayetlerin sonuçlandırılması; hataların giderilmesi ve Hizmetin sürekliliği; 18 yaş üstü hesaplarda Google aracılığıyla reklam gösterilmesi.

4. Hukuki sebepler
KVKK’nın 5. maddesindeki şu sebepler: bir sözleşmenin kurulması veya yerine getirilmesi için gerekli olması, veri sorumlusunun kanuni yükümlülüğü ve temel hak ve özgürlüklere zarar vermemek kaydıyla meşru menfaat. Kullanım Koşullarını kabul etmek, her işlem için açık rıza vermek anlamına gelmez. Bu sürümde ayrıca reklam onayı alınmaz. 18 yaşından küçük hesaplara reklam gösterilmez. Hassas (özel nitelikli) veri bilerek işlenmediği için KVKK’nın 6. maddesine göre açık rıza da alınmaz.

5. Kimlere aktarılıyor
Veriler; Hizmetin barındırılması için Google Firebase’e, seçilen giriş yöntemine göre Google veya Apple’a, 18 yaş üstü reklam için Google AdMob veya AdSense’e aktarılabilir. Bu aktarım yurt dışında olabilir. Amaç Hizmetin sunulmasıdır; güvence, ilgili sağlayıcının veri işleme şartlarıdır. Aktarılan tarafların kimliği ve güvence belgesinin metni, KVKK’nın 11. maddesine göre talep edilirse ve elde bulunduğu ölçüde paylaşılır.

6. Veriler nasıl toplanıyor
Veriler elektronik ortamda; kayıt ve giriş formları, seçilen giriş hizmeti (Google veya Apple), uygulama içi işlemler, destek ve şikayet formları ile güvenlik ve hata kayıtları yoluyla toplanır. Tamamen otomatik verilen tek karar, beyan edilen doğum tarihine göre yaş grubunun belirlenmesidir. Bu karara destek formundan itiraz edilebilir.

7. Ne kadar süre saklanıyor
Veriler, hesap açık olduğu ve işleme amacı gerektirdiği sürece saklanır. Hesap silme Gizlilik Politikası’nda anlatılmıştır. Destek, KVKK ve şikayet kayıtları ile hesap silme geri bildirimi en geç 24 ay içinde silinir veya kimlikle ilişkisi kaldırılır. Zamanaşımı süresi veya devam eden bir uyuşmazlık varsa ilgili kayıt, yalnızca o süreç için daha uzun tutulabilir.

8. Hakların
KVKK’nın 11. maddesine göre şu haklara sahipsin:
• kişisel verilerinin işlenip işlenmediğini öğrenme,
• işlendiyse bununla ilgili bilgi isteme,
• hangi amaçla işlendiğini ve bu amaca uygun kullanılıp kullanılmadığını öğrenme,
• yurt içinde veya yurt dışında aktarıldığı üçüncü kişileri bilme,
• eksik veya yanlış işlendiyse düzeltilmesini isteme,
• KVKK’nın 7. maddesindeki şartlarla silinmesini veya yok edilmesini isteme,
• düzeltme ve silme işlemlerinin, verilerin aktarıldığı üçüncü kişilere bildirilmesini isteme,
• yalnızca otomatik sistemlerle yapılan analiz sonucunda aleyhine bir sonuç çıkmasına itiraz etme,
• kanuna aykırı işleme nedeniyle zarara uğrarsan zararının giderilmesini isteme.

9. Nasıl başvurulur
Başvuru Türkçe yapılır ve kim olduğunu belirtmelidir; destek formu yeterlidir. Başvurun en geç 30 gün içinde sonuçlandırılır. İşlem ayrıca bir maliyet gerektirirse Kurul’un belirlediği ücret istenebilir. Başvurun reddedilirse, süresinde cevap verilmezse veya cevabı yetersiz bulursan; cevabı öğrendiğin tarihten itibaren 30 gün, her durumda başvuru tarihinden itibaren 60 gün içinde Kişisel Verileri Koruma Kurulu’na şikâyette bulunabilirsin.

10. Yürürlük
Bu metin uygulamada ve https://myvibel.com/kvkk.html adresinde yayımlanır. Sürüm $surum, $guncellemeTarihi.
''';

  static const kullanimKosullariBaslik = 'Kullanım Koşulları';

  static const kullanimKosullariMetni = '''
Bu Kullanım Koşulları, $uygulamaAdi’i indiren, kayıt olan veya kullanan sen ile Hizmeti işleten $veriSorumlusuAdi («Hizmeti işleten») arasındaki kuralları belirler. Kayıt sırasında onay kutusunu işaretlemek, bu koşulları okuyup kabul ettiğin anlamına gelir. Kişisel verilerinin nasıl işlendiği ayrıca Gizlilik Politikası ve KVKK Aydınlatma Metni’nde anlatılır. Tüketici olarak 6502 sayılı Tüketicinin Korunması Hakkında Kanun’dan doğan hakların saklıdır.

1. Hizmet nedir
$uygulamaAdi; metin gönderi, yorum, beğeni ve alıntı ile sosyal paylaşım, mesajlaşma, keşfet, bildirimler ve Vibel karakteriyle oyunlaştırma sunan bir platformdur. Bu sürümde fotoğraf veya video yükleme özelliği yoktur.

2. Hesap ve güvenlik
• Kayıtta doğru bilgi vermekten sen sorumlusun.
• Şifreni gizli tut; hesabında yapılanlardan öncelikle sen sorumlusun.
• E-posta ile kayıtta e-posta doğrulaması istenebilir. Google veya Apple ile girişte o hesap bağlanır ve gerekirse şifre belirlemen istenebilir.
• Hesabını başkasına kullandırma. Hesabına izinsiz girildiğinden şüphelenirsen destek formundan bildir.

3. Yaş sınırı
15 yaşını doldurmadıysan $uygulamaAdi’i kullanamazsın. Kayıtta doğum tarihin sorulur ve 15 yaş kontrolü yapılır; bu, resmi kimlik veya e-Devlet doğrulaması değildir.
15–17 yaşındaki hesaplar gizlidir; mesajlaşma, akış reklamı, kişi önerisi ve otomatik sonsuz kaydırma kapalıdır. Cihazda ebeveyn için günlük süre sınırı (varsayılan 90 dakika) ve PIN vardır. Bu kısıtlar 18 yaşında kalkar. Ayrıntı: https://myvibel.com/cocuk-guvenligi.html
Yaş veya hesap kararına destek formundan itiraz edebilirsin.

4. Yasak olanlar
Şunlar yasaktır:
• Yasa dışı içerik
• Hakaret, taciz, tehdit, ısrarlı takip
• Nefret söylemi, ayrımcılık
• Cinsel, müstehcen veya istismar içeren içerik
• Spam, sahte etkileşim, otomatik araçlarla kötüye kullanım
• Telif hakkı veya marka ihlali
• Başkasının kişisel bilgilerini izinsiz paylaşmak
• Sahte hesap açmak, başkası gibi davranmak
• Güvenlik açıklarını kullanmak, Hizmeti bozmaya çalışmak

5. Paylaştığın içerik
• Paylaştığın içerik senindir; $uygulamaAdi içeriğinin sahibi olmaz.
• Hizmetin çalışabilmesi için $uygulamaAdi’e içeriğini barındırma, iletme, gösterme, teknik olarak kopyalama, önbelleğe alma ve moderasyon için inceleme izni verirsin. Bu izin ücretsizdir, yalnızca $uygulamaAdi’e özel değildir (münhasır değildir), dünya genelinde geçerlidir ve yalnızca Hizmetin çalışması için gereken kadardır.
• Hesabını sildiğinde veya içeriği kaldırdığında bu izin de sona erer; teknik yedekler ve kanuni zorunluluklar saklıdır.

6. $uygulamaAdi’in hakları
Uygulamanın tasarımı, markası, yazılımı ve $uygulamaAdi’e ait görseller $veriSorumlusuAdi’a aittir. İzinsiz kopyalanamaz, tersine mühendislik yapılamaz, marka izinsiz kullanılamaz.

7. Moderasyon, şikayet ve yaptırımlar
• Gönderi, yorum ve kullanıcılar için «Şikayet Et» ve engelleme özellikleri vardır.
• İnceleme sonucunda içerik gizlenebilir veya kaldırılabilir; hesap uyarılabilir, kısıtlanabilir veya kapatılabilir.
• Acil güvenlik durumlarında veya ağır ihlallerde önceden haber vermeden işlem yapılabilir.
• İtiraz veya açıklama için Destek ve Geri Bildirim formunu kullanabilirsin; itiraz, kararın otomatik olarak geri alınacağı anlamına gelmez.

8. Özel mesajlar
Mesajlaşma 18 yaşını doldurmuş kullanıcılar içindir; 15–17 yaşındaki hesaplarda yoktur. Spam, taciz veya yasa dışı mesajlar için şikayet ve engelleme kullanabilirsin. Hesabını sildiğinde sohbetlerin de silinebilir; bu, karşı tarafın o sohbete erişimini de etkileyebilir.

9. Vibel, vil ve sanal öğeler
• Vil, seviye, tokluk, enerji, gelişim puanı ve benzerleri sanal oyun öğeleridir. Gerçek para değildir, nakde çevrilemez; bu sürümde satılamaz ve başkasına devredilemez.
• Kurallar ve bedeller güncellemelerle değişebilir.
• İleride gerçek parayla satın alma eklenirse bu koşullar ayrıca güncellenir; bu sürümde böyle bir ödeme yoktur.

10. Gizlilik
Kişisel verilerin Gizlilik Politikası ve KVKK Aydınlatma Metni’ne göre işlenir. Bu koşulları kabul etmek, KVKK kapsamındaki her işlem için ayrıca açık rıza vermek anlamına gelmez. KVKK başvuruları için: https://myvibel.com/kvkk.html

11. Hizmetteki değişiklikler
Özellikler güncellenebilir, geçici olarak durdurulabilir veya kaldırılabilir. Önemli değişiklikler önceden duyurulmaya çalışılır; acil güvenlik güncellemeleri hemen uygulanabilir.

12. Hesap silme
Profil → Ayarlar → Hesabı Sil. Silme geri alınamaz. Giriş hesabın ve ona bağlı veritabanı kayıtların silinir. Silinmeyebilecek bazı kayıtlar (ör. başkalarının gönderilerindeki alıntılar, geri bildirimler, teknik kayıtlar) Gizlilik Politikası’nda açıklanmıştır.

13. Telif hakkı ihlali bildirimi
Bir eserin sahibi veya yetkili temsilcisi, ihlal iddiasını destek formuyla bildirebilir. Bildirimde eser, ihlal edilen içerik ve iletişim bilgisi yer almalıdır. Yeterli bir bildirim üzerine içerik erişime kapatılabilir. İçeriği paylaşan karşı bildirimde bulunursa içerik, kanunun izin verdiği ölçüde yeniden açılabilir. Kötü niyetli bildirimin sorumluluğu bildirene aittir.

14. Hesabın askıya alınması ve kapatılması
Hizmeti işleten; koşulların ihlali, güvenlik riski veya kanuni zorunluluk halinde hesabını uyararak, ağır ihlallerde uyarmadan kısıtlayabilir, içeriği kaldırabilir veya hesabı kapatabilir. Sen de hesabını Profil → Ayarlar → Hesabı Sil ile istediğin zaman, gerekçe göstermeden kapatabilirsin. Kapatılan hesap geri açılmaz. Hesabın kapanması, o ana kadar doğmuş yükümlülükleri ve kanunen saklanması gereken kayıtları ortadan kaldırmaz.

15. Sorumluluk
Hizmet «olduğu gibi» sunulur; kesintisiz, hatasız veya her amaca uygun olacağı garanti edilmez. Kullanıcılar arasındaki anlaşmazlıklar öncelikle o kullanıcılar arasındadır. Yasa dışı bir içerikten, onu paylaşan kullanıcı sorumludur.
Hizmeti işletenin kusurundan doğan bir zararda sorumluluk, kanunun izin verdiği ölçüde ve tüketici hakların saklı kalmak üzere, son 12 ayda Hizmet için ödediğin tutarla sınırlıdır. Hizmet bu sürümde ücretsizdir. Kasıt, ağır kusur ve bedensel zarar bu sınırın dışındadır.

16. Senin sorumluluğun
Kendi içeriğin, hesabını başkasına kullandırman veya bu koşulları ihlal etmen nedeniyle Hizmeti işletene karşı üçüncü kişilerden gelen talepleri, kanunun zorunlu hükümleri saklı kalmak üzere karşılamayı kabul edersin.

17. Mücbir sebep
Doğal afet, savaş, yaygın altyapı veya sağlayıcı kesintisi, resmi kararlar gibi makul kontrol dışındaki olaylarda, olay sürdüğü müddetçe yükümlülükler askıya alınır.

18. Devir
Hesabını veya bu koşullardan doğan haklarını başkasına devredemezsin. Hizmeti işleten, Hizmetin devamı için bu sözleşmedeki yerini bir kişiye veya şirkete devredebilir; bu durumda kişisel verilerle ilgili bilgilendirme güncellenir.

19. Geçersiz maddeler
Bir maddenin geçersiz olması diğer maddeleri geçersiz kılmaz. Bir hakkın kullanılmamış olması, o haktan vazgeçildiği anlamına gelmez.

20. Uygulanacak hukuk ve anlaşmazlıklar
Anlaşmazlıklarda Türkiye Cumhuriyeti hukuku uygulanır. Tüketici olarak yerleşim yerindeki tüketici mahkemesine veya tüketici hakem heyetine başvurabilirsin. Tüketici sayılmayan anlaşmazlıklarda İstanbul mahkemeleri ve icra daireleri yetkilidir.

21. Bildirimler ve bütünlük
Bildirimler destek@myvibel.com adresi, uygulama içi destek formu ve yayımlanan yasal sayfalar üzerinden yapılır. Bu koşullar, Gizlilik Politikası ve KVKK Aydınlatma Metni, Hizmetle ilgili seninle yapılan anlaşmanın tamamıdır. Önceki sözlü vaatler geçersizdir.
Güncelleme: $guncellemeTarihi. Sürüm $surum.
''';

  static const cocukGuvenligiBaslik = 'Çocuklara özgü hizmet ve yaş tedbirleri';

  static const cocukGuvenligiMetni = '''
Bu metin, 5651 sayılı Kanun ve 10 Ekim 2026 tarihli yaş doğrulama düzenlemesi kapsamında, Hizmetin çocuk ve genç kullanıcılar için uyguladığı önlemleri bağlayıcı olarak açıklar. Yaş, kayıtta beyan edilen doğum tarihine göre belirlenir. e-Devlet yaş doğrulaması, teknik kılavuzu yayımlanana kadar kullanılmaz. Kimlik numarası istenmez.

1. Kimler kullanabilir
15 yaşından küçüklere Hizmet sunulmaz. Kayıttaki tarih seçici ve sunucu kontrolü 15 yaş altını reddeder. Beyan edilen yaşı 15’ten küçük olan mevcut hesaplar girişte kilitlenir; destek formundan itiraz edilebilir.

2. 15–17 yaş (kısıtlı hesap)
• Hesap gizlidir ve herkese açık yapılamaz.
• Özel mesajlaşma kapalıdır (18 yaşında açılır).
• Akışta reklam gösterilmez.
• Kişi önerisi ve @bahsetme için kişi önerisi sunulmaz.
• Akış otomatik olarak sonsuz kaymaz; «Daha fazla göster» ile ilerlenir.
• Android’de ekran görüntüsü ve ekran kaydı zorlaştırılır.
• Canlı yayın, rehberden kişi bulma ve konum paylaşımı yoktur (bu özellikler hiç sunulmuyor).
• Gerçek parayla satın alma yoktur; bu yüzden harcama onayı gerekmez.

3. Ebeveyn araçları
Cihazda günlük kullanım süresi sınırı (varsayılan 90 dakika) ve isteğe bağlı ebeveyn PIN’i vardır. PIN ile süre değiştirilebilir veya günlük süre dolduğunda ek süre verilebilir. Bu araçlar, ebeveyne çocuğun yazışmalarını okuma imkânı vermez.

4. İtiraz
Yaş, hesap kilidi, süre sınırı veya kısıtlı hesapla ilgili itiraz: Profil → Destek ve Geri Bildirim → «Yaş / hesap itirazı». İtiraz ücretsizdir; otomatik olarak reddedilmez, bir kişi inceler.

5. e-Devlet
Resmi yaş doğrulaması, kılavuzu yayımlandığında eklenecektir. Bu sürümde T.C. kimlik numarası, kimlik kartı fotoğrafı veya veli kimliği istenmez.

6. Çocuklara yönelik zararlı içerik
Çocukların cinsel istismarı, çocukların cinsel görüntüleri veya çocukları hedef alan taciz içeren her türlü içerik yasaktır. Böyle bir içerik tespit edilir veya şikayet edilirse hemen erişime kapatılır, hesap kapatılabilir ve kanunun zorunlu kıldığı resmi kurumlara bildirilir. 15–17 yaşındaki hesaplarda özel mesaj kapalı olduğu için yetişkin bir kullanıcı bu hesaplara özel mesaj gönderemez.

7. Toplanan verilerin sınırlanması
Kısıtlı hesaplarda reklam kimliği oluşturulmaz ve reklam isteği gönderilmez. Kişi ve bahsetme önerisi üretilmez. Ebeveyn PIN’i ve süre sayacı yalnızca cihazda tutulur; ebeveyne çocuğun gönderilerini veya etkileşimlerini gösteren bir izleme paneli yoktur.

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
