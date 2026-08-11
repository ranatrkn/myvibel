# -*- coding: utf-8 -*-
"""VibeLife ozellik yol haritasi PDF uretici."""

from datetime import date
from pathlib import Path

from fpdf import FPDF

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "docs" / "VibeLife_Ozellik_Yol_Haritasi.pdf"
FONT_REG = Path(r"C:\Windows\Fonts\arial.ttf")
FONT_BOLD = Path(r"C:\Windows\Fonts\arialbd.ttf")


class VibePdf(FPDF):
    def footer(self):
        self.set_y(-15)
        self.set_font("Arial", size=9)
        self.set_text_color(120, 120, 120)
        self.cell(0, 10, f"Sayfa {self.page_no()}/{{nb}}", align="C")


def section_title(pdf: VibePdf, text: str):
    pdf.ln(4)
    pdf.set_font("Arial", "B", 14)
    pdf.set_text_color(30, 30, 30)
    pdf.multi_cell(0, 8, text)
    pdf.ln(1)


def sub_title(pdf: VibePdf, text: str):
    pdf.ln(2)
    pdf.set_font("Arial", "B", 11)
    pdf.set_text_color(50, 50, 50)
    pdf.multi_cell(0, 6, text)
    pdf.ln(1)


def body(pdf: VibePdf, text: str):
    pdf.set_x(pdf.l_margin)
    pdf.set_font("Arial", size=10)
    pdf.set_text_color(20, 20, 20)
    pdf.multi_cell(0, 5.5, text)
    pdf.ln(1)


def bullet(pdf: VibePdf, text: str):
    pdf.set_x(pdf.l_margin)
    pdf.set_font("Arial", size=10)
    pdf.set_text_color(20, 20, 20)
    pdf.multi_cell(0, 5.5, f"- {text}")


def feature_block(
    pdf: VibePdf,
    name: str,
    summary: str,
    benefit: str,
    implementation: str,
    files: str,
    effort: str,
    firebase_impact: str,
):
    sub_title(pdf, name)
    body(pdf, f"Ozet: {summary}")
    body(pdf, f"Kullaniciya deger: {benefit}")
    body(pdf, f"Nasil yapilir: {implementation}")
    body(pdf, f"Ilgili dosyalar: {files}")
    body(pdf, f"Tahmini efor: {effort}")
    body(pdf, f"Firebase etkisi: {firebase_impact}")
    pdf.ln(1)


def cost_block(
    pdf: VibePdf,
    name: str,
    summary: str,
    why_costly: str,
    spark: str,
    blaze_cost: str,
    monthly_example: str,
    recommendation: str,
):
    sub_title(pdf, name)
    body(pdf, f"Ozet: {summary}")
    body(pdf, f"Neden maliyetli: {why_costly}")
    body(pdf, f"Spark (ucretsiz) planda: {spark}")
    body(pdf, f"Blaze / ek maliyet: {blaze_cost}")
    body(pdf, f"Ornek aylik maliyet (kucuk-orta olcek): {monthly_example}")
    body(pdf, f"Oneri: {recommendation}")
    pdf.ln(1)


def build_pdf():
    pdf = VibePdf()
    pdf.alias_nb_pages()
    pdf.set_margins(15, 15, 15)
    pdf.set_auto_page_break(auto=True, margin=18)
    pdf.add_font("Arial", "", str(FONT_REG))
    pdf.add_font("Arial", "B", str(FONT_BOLD))

    # Kapak
    pdf.add_page()
    pdf.set_font("Arial", "B", 22)
    pdf.set_text_color(25, 25, 25)
    pdf.ln(30)
    pdf.multi_cell(0, 12, "VibeLife Uygulama\nOzellik Yol Haritasi")
    pdf.ln(8)
    pdf.set_font("Arial", size=12)
    pdf.set_text_color(80, 80, 80)
    pdf.multi_cell(
        0,
        7,
        f"Hazirlama tarihi: {date.today().strftime('%d.%m.%Y')}\n"
        "Proje: vibe-life-app (Flutter + Firebase)\n"
        "Plan hedefi: Spark (ucretsiz) ile maksimum deger",
    )
    pdf.ln(10)
    body(
        pdf,
        "Bu dokuman, VibeLife sosyal uygulamasina eklenebilecek ozellikleri oncelik, "
        "teknik uygulama adimlari ve Firebase maliyet etkisine gore detaylandirir. "
        "Ucretsiz ve dusuk maliyetli ozellikler once; maliyetli ozellikler dokumanin "
        "sonunda tahmini tutarlarla birlikte yer alir.",
    )

    # 1. Mevcut durum
    pdf.add_page()
    section_title(pdf, "1. Mevcut Durum Ozeti")
    body(
        pdf,
        "VibeLife su anda email/sifre ile giris, global metin feed'i, profil, takip "
        "sistemi (gizli hesap + takip istegi), begeni/yorum, DM, uygulama ici bildirimler, "
        "sikayet/moderasyon paneli ve robot + puan gamification sistemine sahiptir.",
    )
    sub_title(pdf, "Ana teknik yapı")
    bullet(pdf, "UI: Flutter sayfalari (feed_page, profile_page, explore_page, messages_page vb.)")
    bullet(pdf, "Is mantigi: lib/sosyal_servis.dart (Firestore transaction/batch islemleri)")
    bullet(pdf, "Guvenlik: firestore.rules (Spark planda ucretsiz)")
    bullet(pdf, "Veri: users, posts, chats, reports, usernames koleksiyonlari")
    sub_title(pdf, "Tamamlanmamis / yari kalmis alanlar")
    bullet(pdf, "aramaSkoru alani var ama artirilmiyor; Kesfet onerileri etkisiz")
    bullet(pdf, "Robot enerji/mutluluk/aclik kayitta yaziliyor ama UI'da kullanilmiyor")
    bullet(pdf, "Feed tum gonderileri cekiyor; takip bazli feed yok")
    bullet(pdf, "DM gelince bildirim olusmuyor")
    bullet(pdf, "Medya/fotograf yukleme yok (photoUrl alani hazir)")
    bullet(pdf, "Push bildirim (FCM arka plan) yok; uygulama acikken bildirim var")

    # 2. Ucretsiz ozellikler - Faz 1
    pdf.add_page()
    section_title(pdf, "2. Ucretsiz / Dusuk Maliyetli Ozellikler (Oncelikli)")
    body(
        pdf,
        "Asagidaki ozellikler Spark (ucretsiz Firebase) planinda, Cloud Functions "
        "olmadan mevcut mimariyle uygulanabilir. Tahmini efor kucuk ekip / tek "
        "gelistirici icindir.",
    )
    sub_title(pdf, "FAZ 1 — Hizli kazanımlar (1–3 gun)")

    feature_block(
        pdf,
        "2.1 Takip Ettiklerim Feed Sekmesi",
        "Feed'e 'Tumu' ve 'Takip' sekmeleri eklenir. Takip sekmesi sadece takip edilen "
        "kullanicilarin ve kendi gonderilerinin gorunmesini saglar.",
        "Kullanici gercek bir sosyal akis hisseder; global feed kaosunu azaltir.",
        "feed_page.dart icinde mevcut _takipEdilenIdler seti kullanilir. _sonrakiPostlariYukle "
        "sonrasi client-side filtre uygulanir. Gizli hesap ve engel filtreleri korunur.",
        "lib/feed_page.dart, lib/sosyal_servis.dart",
        "4–8 saat",
        "Ek Firestore okumasi yok; ayni sorgu, daha iyi filtre. Ucretsiz.",
    )
    feature_block(
        pdf,
        "2.2 DM Bildirimi (Uygulama Ici)",
        "Yeni mesaj geldiginde hedef kullanicinin notifications alt koleksiyonuna kayit acilir.",
        "Mesajlar kacirilmaz; bildirimler sekmesinden DM'e gidilir.",
        "sosyal_servis.dart mesajGonder icinde bildirimEkle(tip: 'message') cagrilir. "
        "notifications_page.dart yeni tip icin ikon ve yonlendirme ekler.",
        "lib/sosyal_servis.dart, lib/notifications_page.dart",
        "2–4 saat",
        "Her mesaj = 1 yazma. Gunluk 20K yazma kotasi icinde kalinmali. Ucretsiz.",
    )
    feature_block(
        pdf,
        "2.3 Gunluk Giris / Streak (Seri)",
        "Kullanici her gun uygulamaya girdiginde streak artar ve bonus puan verilir.",
        "Her gun geri donus oranini artirir; robot/puan sistemini destekler.",
        "users/{uid}/checkIns/{YYYY-MM-DD} dokumani transaction ile olusturulur. "
        "Ayni gun tekrar giris puan vermez. Profilde streak rozeti gosterilir.",
        "lib/main.dart veya feed_page.dart, lib/profile_page.dart, lib/sosyal_servis.dart",
        "6–10 saat",
        "Kullanici basina gunde 1 okuma + 1 yazma. Ucretsiz.",
    )
    feature_block(
        pdf,
        "2.4 Puan Liderlik Tablosu",
        "En yuksek puanli 25 kullanici listelenir.",
        "Rekabet ve robot gelistirme motivasyonu saglar.",
        "Yeni sayfa: orderBy('puan', descending: true).limit(25). "
        "Explore veya profilden link verilir.",
        "Yeni lib/leaderboard_page.dart, lib/feed_page.dart",
        "4–6 saat",
        "Sayfa acilisinda 25 okuma. Nadiren acilirsa ucretsiz kalir.",
    )
    feature_block(
        pdf,
        "2.5 aramaSkoru Artisi (Kesfet Onerileri)",
        "Profil goruntulendikce populerlik skoru artar; Kesfet onerileri anlam kazanir.",
        "Yeni kullanicilar aktif profilleri kesfeder.",
        "UserProfilePage acilisinda debounce (or. 24 saatte bir) ile "
        "FieldValue.increment(1) cagrilir. firestore.rules'ta aramaSkoru sadece "
        "baskasinin profiline increment ile guncellenebilir kurali eklenir.",
        "lib/user_profile_page.dart, firestore.rules",
        "3–5 saat",
        "Profil basina seyrek 1 yazma. Ucretsiz.",
    )

    # Faz 2
    pdf.add_page()
    sub_title(pdf, "FAZ 2 — VibeLife'i farklilastiran ozellikler (3–7 gun)")

    feature_block(
        pdf,
        "2.6 Robot Bakim Dongusu (Tamagotchi)",
        "enerji, mutluluk, aclik alanlari gonderi/begeni/yorum/giris ile guncellenir.",
        "Uygulamanin imza deneyimi guclenir; robot sadece animasyon olmaktan cikar.",
        "Post +mutluluk, yorum +enerji, 24 saat giris yok +aclik dusus. "
        "profile_page _robotKarti altinda cubuk gostergeler. Transaction ile guncelleme.",
        "lib/profile_page.dart, lib/sosyal_servis.dart, lib/newpost_page.dart",
        "2–3 gun",
        "Etkilesim basina birkaç yazma. Orta kullanimda ucretsiz.",
    )
    feature_block(
        pdf,
        "2.7 Gunluk Gorevler (Quests)",
        "Gunluk gorevler: '1 gonderi paylas', '3 begeni yap', '1 kisi takip et'.",
        "Oyunlasma derinligi; puan kazanma yollarini cesitlendirir.",
        "users/{uid}/dailyQuests/{tarih} dokumani; gorev tamamlaninca puan transaction.",
        "lib/profile_page.dart veya yeni quests_page.dart",
        "2–4 gun",
        "Kullanici basina gunde birkac okuma/yazma. Ucretsiz.",
    )
    feature_block(
        pdf,
        "2.8 Trend / Hot Vibes",
        "Son 24 saatin en populer gonderileri Kesfet'te gosterilir.",
        "Icerik kesfi artar; dusuk takipci sayili kullanicilar gorunur olur.",
        "posts sorgusu son 24 saat + client-side _feedPuani siralamasi veya "
        "skor alanina gore limit(50).",
        "lib/explore_page.dart, lib/feed_page.dart (_feedPuani mantigi)",
        "1–2 gun",
        "50–200 okuma / sayfa acilisi. Orta olcekte ucretsiz.",
    )
    feature_block(
        pdf,
        "2.9 Kaydedilen Gonderiler",
        "Kullanici gonderileri daha sonra okumak icin kaydeder.",
        "Begeni ile karistirilmayan 'sonra oku' deneyimi.",
        "likedPosts modelinin aynisi: users/{uid}/savedPosts/{postId}. "
        "Profilde ucuncu sekme.",
        "lib/sosyal_servis.dart, lib/profile_page.dart, firestore.rules",
        "1–2 gun",
        "Kaydet basina 1 yazma. Ucretsiz.",
    )
    feature_block(
        pdf,
        "2.10 Hashtag (#vibe) Destegi",
        "Gonderi metnindeki #etiketler parse edilir ve aranabilir olur.",
        "Konu bazli kesif; topluluk olusumu.",
        "newpost_page paylasirken tags: ['vibe'] array kaydeder. "
        "Explore'de arrayContains sorgusu.",
        "lib/newpost_page.dart, lib/explore_page.dart, firestore.rules",
        "2–3 gun",
        "Hashtag basina ek okuma. Index gerekebilir (ucretsiz).",
    )
    feature_block(
        pdf,
        "2.11 Gonderi Detay Sayfasi",
        "Tek gonderi tam ekran acilir; bildirimden veya paylasimdan erisim.",
        "Derin link ve paylasim altyapisi.",
        "notifications_page.dart _BildirimPostSayfasi yeniden kullanilir veya "
        "post_detail_page.dart olusturulur.",
        "lib/notifications_page.dart, yeni post_detail_page.dart",
        "4–8 saat",
        "1 gonderi + yorum okumasi. Ucretsiz.",
    )
    feature_block(
        pdf,
        "2.12 Profil Istatistik Kartlari",
        "Gonderi sayisi, takipci, takip, toplam puan kart olarak gosterilir.",
        "Profil daha bilgilendirici ve profesyonel gorunur.",
        "Veri zaten users dokumaninda; user_profile_page ve profile_page UI guncellemesi.",
        "lib/profile_page.dart, lib/user_profile_page.dart",
        "3–5 saat",
        "Ek okuma yok. Ucretsiz.",
    )

    # Faz 3
    pdf.add_page()
    sub_title(pdf, "FAZ 3 — Orta efor, Spark icinde kalabilir")

    feature_block(
        pdf,
        "2.13 Profil Fotografi Yukleme",
        "Emoji avatar yaninda istege bagli fotograf yukleme.",
        "Kisisellestirme artar; sosyal guven hissi.",
        "firebase_storage + image_picker eklenir. avatars/{uid}.jpg yuklenir, "
        "photoUrl guncellenir. vibe_avatar.dart zaten network destekliyor.",
        "pubspec.yaml, lib/profile_page.dart, storage.rules",
        "2–4 gun",
        "Storage: 5 GB ucretsiz (Spark). Kucuk avatarlar icin yeterli.",
    )
    feature_block(
        pdf,
        "2.14 Kayit Sonrasi Onerilen Takipler",
        "Yeni kullaniciya populer profiller onerilir.",
        "Cold start problemi azalir; ilk gun etkilesim artar.",
        "Register sonrasi onboarding sayfasi; aramaSkoru yuksek 10 kullanici listesi.",
        "lib/register_page.dart, yeni onboarding_page.dart",
        "1–2 gun",
        "10–25 okuma / yeni kullanici. Ucretsiz.",
    )
    feature_block(
        pdf,
        "2.15 Bildirim Filtreleme ve Toplu Okundu",
        "Bildirimler tipine gore filtrelenir (begeni, takip, mesaj).",
        "Bildirim kalabaligi azalir.",
        "notifications_page.dart TabBar veya chip filtreleri.",
        "lib/notifications_page.dart",
        "4–6 saat",
        "Client-side filtre; ek maliyet yok.",
    )
    feature_block(
        pdf,
        "2.16 Mesajlasma: Yaziyor / Son Gorulme",
        "Karsidaki yaziyor gostergesi ve son gorulme zamani.",
        "Modern DM deneyimi.",
        "chats dokumanina typingBy ve lastSeenBy alanlari (lastSeenBy kismen var).",
        "lib/messages_page.dart, lib/sosyal_servis.dart",
        "1–2 gun",
        "Gercek zamanli dinleme ile ek okuma; dikkatli kullanilmali.",
    )

    # 3. Uygulama rehberi
    pdf.add_page()
    section_title(pdf, "3. Ozellik Ekleme Rehberi (Teknik Akis)")
    body(pdf, "Her yeni ozellik icin asagidaki sirayi izleyin:")
    bullet(pdf, "1. SosyalServis'e Firestore metodu ekleyin (transaction/batch tercih)")
    bullet(pdf, "2. UI sayfasi veya widget olusturun; mevcut tema (VibeAppTheme) kullanin")
    bullet(pdf, "3. firestore.rules dosyasina gerekli izinleri ekleyin")
    bullet(pdf, "4. Firebase Console'dan Rules yayinlayin")
    bullet(pdf, "5. Sorgu hatasi alirsaniz composite index olusturun (ucretsiz)")
    bullet(pdf, "6. Gercek cihazda permission-denied ve kota testleri yapin")
    sub_title(pdf, "Onerilen uygulama sirasi")
    body(
        pdf,
        "1) Takip feed  →  2) DM bildirimi  →  3) Gunluk streak  →  "
        "4) Robot gorevleri  →  5) Kaydedilen gonderiler  →  6) Hashtag  →  "
        "7) Profil fotografi",
    )

    # 4. Spark limitleri
    pdf.add_page()
    section_title(pdf, "4. Spark (Ucretsiz) Plan Limitleri — Referans")
    body(
        pdf,
        "Asagidaki limitler asildiginda ucretsiz planda hizmet durabilir veya "
        "Blaze planina gecis gerekir. Kaynak: firebase.google.com/pricing (2025–2026).",
    )
    bullet(pdf, "Firestore okuma: 50.000 / gun")
    bullet(pdf, "Firestore yazma: 20.000 / gun")
    bullet(pdf, "Firestore silme: 20.000 / gun")
    bullet(pdf, "Firestore depolama: 1 GiB")
    bullet(pdf, "Cloud Storage: 5 GB (gunluk indirme limitleri uygulanir)")
    bullet(pdf, "Cloud Functions: Spark'ta pratikte kullanilamaz / Blaze gerekir")
    bullet(pdf, "FCM (Push): Firebase tarafinda ucretsiz; sunucu tarafli gonderim Functions gerektirir")
    body(
        pdf,
        "Not: 1 aktif kullanici gunluk ortalama 100–300 okuma yaparsa, yaklasik "
        "150–500 gunluk aktif kullaniciya kadar Spark yeterli olabilir. Kotaya yakin "
        "Firebase Console > Usage ekranindan takip edin.",
    )

    # 5. Maliyetli ozellikler
    pdf.add_page()
    section_title(pdf, "5. Maliyetli Ozellikler (En Sona Birakilmali)")
    body(
        pdf,
        "Bu bolumdeki ozellikler ya Blaze (odeme yontemi baglantisi) gerektirir ya da "
        "kullanici/veri arttikca Firestore, Storage veya ucuncu parti servis maliyeti "
        "uretir. Tutarlar tahminidir; USD cinsindendir. "
        "1 USD ≈ 35–40 TL (Mayis 2026 civari) olarak dusunebilirsiniz.",
    )

    cost_block(
        pdf,
        "5.1 Push Bildirim (Arka Plan — FCM + Cloud Functions)",
        "Uygulama kapaliyken bile bildirim gitmesi.",
        "Guvenli sunucu tarafli bildirim gonderimi icin Cloud Functions zorunludur. "
        "Functions yalnizca Blaze planinda calisir (aylik sabit ucret yok, kullandigin kadar ode).",
        "Spark: Push sunucu tarafli calismaz. Client-only FCM sinirli.",
        "Blaze: Functions 2M cagri/ay ucretsiz, sonrasi ~$0,40 / 1 milyon cagri. "
        "FCM gonderimi Firebase'de ucretsiz.",
        "100–500 aktif kullanici, gunde ~500 bildirim: ~$0–2/ay (genelde ucretsiz kotada). "
        "5.000+ kullanici: ~$5–25/ay.",
        "Erken asamada uygulama ici bildirim yeterli; buyuyunce Blaze + Functions ekleyin.",
    )
    cost_block(
        pdf,
        "5.2 Cloud Functions ile Sunucu Guvenligi",
        "Puan/begeni/sikayet sayaclarinin sunucuda dogrulanmasi.",
        "Client-side kurallar tam guvenlik saglamaz; Functions ile her islem sunucuda yapilir.",
        "Spark: Kullanilamaz.",
        "Blaze: Dusuk trafikte $0–5/ay; yuksek trafikte okuma/yazma + Functions birlikte artar.",
        "Ornek 1.000 islem/gun: ~$0–3/ay. 50.000 islem/gun: ~$15–40/ay.",
        "Spark rules ile devam; kritik ekonomik deger yoksa ertelemek mantikli.",
    )
    cost_block(
        pdf,
        "5.3 Fan-Out Feed (userFeed/{uid}/items)",
        "Her gonderi tum takipcilere ayri dokuman olarak yazilir.",
        "Her paylasim N takipci kadar yazma uretir; populer hesaplarda maliyet patlar.",
        "Spark: 20K yazma/gun kotasi hizla biter.",
        "Blaze: 100K yazma ≈ $0,06 (yazma basi $0,18/100K degil — $0,06/100K yazma). "
        "10K takipcili bir gonderi = 10K yazma ≈ $0,006 + okuma maliyeti.",
        "1 populer kullanici gunluk 5 gonderi, 5.000 takipci: ~75.000 yazma/ay ≈ $5–15/ay sadece yazma.",
        "Kucuk olcekte client-side filtre (Takip sekmesi) tercih edin.",
    )
    cost_block(
        pdf,
        "5.4 Gelismis Arama (Algolia / Typesense / Elastic)",
        "Kullanici ve gonderi icin hizli tam metin arama.",
        "Firestore where/arrayContains kucuk olcek icin yeterli; 500+ kullanicida client-side arama yetersiz.",
        "Spark: Ucuncu parti arama yok.",
        "Algolia: Ucretsiz tier ~10K arama/ay; Build plan ~$35/ay; daha yuksek kullanim $100+/ay.",
        "500 DAU, gunde 5 arama: ucretsiz tier yeter. 5.000 DAU: ~$35–100/ay.",
        "Once client-side aramaSkoru + limit(500); buyuyunce Algolia veya benzeri.",
    )
    cost_block(
        pdf,
        "5.5 Video / Hikaye (Story) Icerik",
        "Kisa video yukleme ve oynatma.",
        "Depolama, bant genisligi ve isleme maliyeti metin gonderiden 10–100x fazladir.",
        "Spark Storage 5 GB: birkac yuz kisa video ile dolar.",
        "Blaze Storage: ~$0,026/GB/ay depolama + ~$0,12/GB indirme. "
        "1000 video izlenmesi (5 MB/video): ~5 GB transfer ≈ $0,60/ay + depolama.",
        "Orta kullanim (100 aktif icerik uretici): ~$10–50/ay. Buyuk olcek: $100+/ay.",
        "Metin + emoji avatar ile devam; video ancak gelir modeli varken.",
    )
    cost_block(
        pdf,
        "5.6 Kotasiz Global Feed Taramasi (Olceklenmemis Sorgu)",
        "Tum posts koleksiyonunu surekli okuyup client-side filtreleme.",
        "Kullanici arttikca gunluk okuma 50K limitini asar; uygulama yavaslar veya durur.",
        "Spark: 50K okuma/gun — yaklasik 150–500 aktif kullanicida risk.",
        "Blaze: 100K okuma ≈ $0,06. 1M okuma/gun ≈ $0,18/gun ≈ $5,4/ay.",
        "10.000 DAU, kullanici basina 200 okuma/gun = 2M okuma/gun ≈ $108/ay sadece feed.",
        "Takip feed, sayfalama, raporNedeniyleGizli filtresi ve index optimizasyonu sart.",
    )
    cost_block(
        pdf,
        "5.7 Telefon ile Giris (SMS OTP)",
        "Firebase Phone Authentication.",
        "SMS basina ucret; sahte kayit riski yuksek.",
        "Spark: Sinirli ucretsiz SMS (bolgeye gore degisir).",
        "Blaze: ABD ~$0,01–0,06/dogrulama; Turkiye fiyatlari degisken, ~$0,02–0,10/SMS.",
        "100 kayit/ay: ~$2–10/ay. 1.000 kayit/ay: ~$20–100/ay.",
        "Email/sifre ile devam; telefon opsiyonel ve sonra eklenmeli.",
    )
    cost_block(
        pdf,
        "5.8 Blaze Planina Gecis (Genel)",
        "Odeme yontemi baglama; kotayi asinca otomatik ucret.",
        "Bazi servisler (Functions) icin zorunlu; kotada kalirsaniz $0 olabilir.",
        "Spark: $0/ay, odeme yontemi gerekmez.",
        "Blaze: Sabit aylik ucret yok. Sadece asim ucreti. $300 ucretsiz kredi (ilk kez uygunluk).",
        "Sadece ucretsiz ozelliklerle: $0/ay. Push + Functions + orta olcek: ~$5–30/ay tipik.",
        "Butce yoksa Spark'ta kalin; Blaze'i ancak gelir veya ciddi buyume olunca acin.",
    )

    # 6. Ozet tablo
    pdf.add_page()
    section_title(pdf, "6. Ozet — Oncelik Matrisi")
    sub_title(pdf, "Once yap (ucretsiz, yuksek etki)")
    bullet(pdf, "Takip Ettiklerim feed sekmesi")
    bullet(pdf, "DM uygulama ici bildirimi")
    bullet(pdf, "Gunluk streak + liderlik tablosu")
    bullet(pdf, "Robot gorevleri ve bakim dongusu")
    bullet(pdf, "Kaydedilen gonderiler + hashtag")
    sub_title(pdf, "Sonra yap (orta efor, hala Spark)")
    bullet(pdf, "Profil fotografi (Storage 5 GB icinde)")
    bullet(pdf, "Kayit sonrasi onboarding takip onerileri")
    bullet(pdf, "Gonderi detay ve profil istatistikleri")
    sub_title(pdf, "En son / maliyetli")
    bullet(pdf, "Push bildirim (Functions): ~$0–25/ay")
    bullet(pdf, "Fan-out feed: kotasi asim riski yuksek")
    bullet(pdf, "Gelismis arama (Algolia): ~$0–100+/ay")
    bullet(pdf, "Video/hikaye: ~$10–100+/ay")
    bullet(pdf, "Telefon OTP: ~$2–100/ay kullanima gore")
    body(
        pdf,
        "Sonuc: VibeLife icin en mantikli strateji, Spark planda Faz 1–2 ozelliklerini "
        "tamamlamak ve kullanici sayisi / gelir arttiginda maliyetli ozelliklere gecmektir.",
    )

    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    pdf.output(str(OUTPUT))
    return OUTPUT


if __name__ == "__main__":
    path = build_pdf()
    print(f"PDF olusturuldu: {path}")
