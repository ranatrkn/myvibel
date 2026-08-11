# -*- coding: utf-8 -*-
"""VibeLife proje tanitimi PDF + ekran gorselleri uretici."""

from __future__ import annotations

from datetime import date
from pathlib import Path

from fpdf import FPDF
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
DOCS = ROOT / "docs"
SHOTS = DOCS / "screenshots"
OUTPUT = DOCS / "VibeLife_Proje_Tanitimi.pdf"
FONT_REG = Path(r"C:\Windows\Fonts\arial.ttf")
FONT_BOLD = Path(r"C:\Windows\Fonts\arialbd.ttf")

# VibeLife koyu tema renkleri
BG = (26, 0, 46)
GRAD_TOP = (40, 0, 0)
GRAD_BOTTOM = (15, 0, 38)
CARD = (30, 10, 50)
CARD_BORDER = (80, 40, 100)
TEXT = (255, 255, 255)
MUTED = (180, 170, 190)
ACCENT = (255, 82, 82)
BTN = (120, 0, 0)
GREEN = (76, 175, 80)

W, H = 390, 844


def _font(size: int, bold: bool = False) -> ImageFont.FreeTypeFont:
    path = FONT_BOLD if bold else FONT_REG
    return ImageFont.truetype(str(path), size=size)


def _gradient_bg(draw: ImageDraw.ImageDraw, img: Image.Image):
    for y in range(H):
        t = y / H
        r = int(GRAD_TOP[0] * (1 - t) + GRAD_BOTTOM[0] * t)
        g = int(GRAD_TOP[1] * (1 - t) + GRAD_BOTTOM[1] * t)
        b = int(GRAD_TOP[2] * (1 - t) + GRAD_BOTTOM[2] * t)
        draw.line([(0, y), (W, y)], fill=(r, g, b))


def _phone_frame() -> Image.Image:
    img = Image.new("RGB", (W, H), BG)
    draw = ImageDraw.Draw(img)
    _gradient_bg(draw, img)
    return img


def _status_bar(draw: ImageDraw.ImageDraw, title: str = "VibeLife"):
    draw.rectangle([0, 0, W, 28], fill=(0, 0, 0, 80))
    draw.text((16, 6), "21:30", font=_font(11), fill=TEXT)
    draw.text((W // 2 - 40, 6), title, font=_font(11, True), fill=TEXT)


def _bottom_nav(draw: ImageDraw.ImageDraw, active: int):
    y = H - 62
    draw.rectangle([0, y, W, H], fill=BG)
    icons = ["Ana", "Kesfet", "Yeni", "Bildirim", "Profil"]
    for i, label in enumerate(icons):
        cx = 20 + i * (W - 40) / 4
        color = ACCENT if i == active else MUTED
        draw.ellipse([cx - 8, y + 12, cx + 8, y + 28], outline=color, width=2)
        draw.text((cx - 18, y + 34), label, font=_font(8), fill=color)


def _rounded_card(draw: ImageDraw.ImageDraw, x, y, w, h, fill=CARD):
    draw.rounded_rectangle([x, y, x + w, y + h], radius=20, fill=fill, outline=CARD_BORDER)


def _avatar(draw: ImageDraw.ImageDraw, cx, cy, r=22, color=(156, 39, 176)):
    draw.ellipse([cx - r, cy - r, cx + r, cy + r], fill=color)
    draw.text((cx - 8, cy - 10), "V", font=_font(16, True), fill=TEXT)


def _post_card(draw: ImageDraw.ImageDraw, y: int, user: str, text: str, likes: str, comments: str):
    _rounded_card(draw, 16, y, W - 32, 130)
    _avatar(draw, 38, y + 28)
    draw.text((68, y + 12), user, font=_font(13, True), fill=TEXT)
    draw.text((68, y + 30), "@kullanici", font=_font(10), fill=MUTED)
    draw.text((24, y + 58), text, font=_font(11), fill=TEXT)
    draw.text((24, y + 108), f"Begeni {likes}   Yorum {comments}", font=_font(10), fill=MUTED)


def shot_login() -> Path:
    img = _phone_frame()
    d = ImageDraw.Draw(img)
    _status_bar(d, "")
    d.text((W // 2 - 95, 120), "VibeLife", font=_font(42, True), fill=TEXT)
    d.rounded_rectangle([36, 340, W - 36, 390], radius=25, fill=(26, 10, 40), outline=CARD_BORDER)
    d.text((70, 358), "E-posta", font=_font(13), fill=MUTED)
    d.rounded_rectangle([36, 410, W - 36, 460], radius=25, fill=(26, 10, 40), outline=CARD_BORDER)
    d.text((70, 428), "Sifre", font=_font(13), fill=MUTED)
    d.rounded_rectangle([36, 490, W - 36, 540], radius=25, fill=BTN)
    d.text((W // 2 - 42, 505), "Giris Yap", font=_font(15, True), fill=TEXT)
    d.text((W // 2 - 88, 560), "Hesabin Yok mu? Kayit Ol", font=_font(11), fill=MUTED)
    path = SHOTS / "01_giris.png"
    img.save(path)
    return path


def shot_register() -> Path:
    img = _phone_frame()
    d = ImageDraw.Draw(img)
    _status_bar(d, "Kayit Ol")
    fields = ["Ad Soyad", "Kullanici Adi", "E-posta", "Sifre", "Sifre Tekrar"]
    y = 70
    for field in fields:
        d.rounded_rectangle([28, y, W - 28, y + 46], radius=22, fill=(26, 10, 40), outline=CARD_BORDER)
        d.text((48, y + 14), field, font=_font(12), fill=MUTED)
        y += 58
    d.rounded_rectangle([28, y + 10, W - 28, y + 60], radius=25, fill=BTN)
    d.text((W // 2 - 55, y + 26), "Kayit Ol", font=_font(14, True), fill=TEXT)
    path = SHOTS / "02_kayit.png"
    img.save(path)
    return path


def shot_feed() -> Path:
    img = _phone_frame()
    d = ImageDraw.Draw(img)
    _status_bar(d)
    _rounded_card(d, 16, 44, W - 32, 72)
    d.text((24, 58), "Robotun hazir!", font=_font(12, True), fill=TEXT)
    d.text((24, 78), "Seviye 2  |  120 puan", font=_font(10), fill=MUTED)
    d.ellipse([W - 56, 62, W - 28, 90], fill=ACCENT)
    _post_card(d, 130, "Ayse Yilmaz", "Bugun harika bir vibe!", "24", "5")
    _post_card(d, 275, "Mehmet Demir", "Yeni robotumu gelistirdim", "18", "2")
    _bottom_nav(d, 0)
    path = SHOTS / "03_feed.png"
    img.save(path)
    return path


def shot_explore() -> Path:
    img = _phone_frame()
    d = ImageDraw.Draw(img)
    _status_bar(d)
    d.rounded_rectangle([16, 44, W - 16, 88], radius=25, fill=(26, 10, 40), outline=CARD_BORDER)
    d.text((48, 60), "Kullanici adi veya ad soyad ara...", font=_font(11), fill=MUTED)
    d.text((20, 100), "Onerilen Kullanicilar", font=_font(14, True), fill=TEXT)
    y = 130
    users = [("Zeynep Kaya", "@zeynep"), ("Can Arslan", "@canarslan"), ("Elif Vibe", "@elifv")]
    for ad, nick in users:
        _rounded_card(d, 16, y, W - 32, 72)
        _avatar(d, 38, y + 36, color=(63, 81, 181))
        d.text((68, y + 18), ad, font=_font(12, True), fill=TEXT)
        d.text((68, y + 36), nick, font=_font(10), fill=MUTED)
        d.rounded_rectangle([W - 110, y + 22, W - 28, y + 52], radius=16, fill=BTN)
        d.text((W - 98, y + 30), "Takip Et", font=_font(10, True), fill=TEXT)
        y += 82
    _bottom_nav(d, 1)
    path = SHOTS / "04_kesfet.png"
    img.save(path)
    return path


def shot_new_post() -> Path:
    img = _phone_frame()
    d = ImageDraw.Draw(img)
    _status_bar(d)
    d.text((20, 50), "Yeni Gonderi Olustur", font=_font(20, True), fill=TEXT)
    _rounded_card(d, 16, 100, W - 32, 180)
    d.text((32, 120), "Bugun nasil hissediyorsun?", font=_font(12), fill=MUTED)
    d.text((32, 250), "0 / 280", font=_font(10), fill=MUTED)
    _rounded_card(d, 16, 300, W - 32, 90)
    d.text((32, 318), "Paylasim +10 puan kazandirir", font=_font(11), fill=GREEN)
    d.rounded_rectangle([16, 620, W - 16, 670], radius=25, fill=BTN)
    d.text((W // 2 - 48, 636), "Paylas", font=_font(14, True), fill=TEXT)
    _bottom_nav(d, 2)
    path = SHOTS / "05_yeni_gonderi.png"
    img.save(path)
    return path


def shot_notifications() -> Path:
    img = _phone_frame()
    d = ImageDraw.Draw(img)
    _status_bar(d)
    d.text((20, 50), "Bildirimler", font=_font(20, True), fill=TEXT)
    items = [
        ("Ali seni takip etti", "2 dk"),
        ("Ayse gonderini begendi", "15 dk"),
        ("Can yorum yapti", "1 sa"),
        ("Takip istegi: Elif", "3 sa"),
    ]
    y = 100
    for text, time in items:
        _rounded_card(d, 16, y, W - 32, 68)
        _avatar(d, 38, y + 34)
        d.text((68, y + 18), text, font=_font(11), fill=TEXT)
        d.text((68, y + 38), time, font=_font(9), fill=MUTED)
        if "istegi" in text:
            d.rounded_rectangle([W - 170, y + 22, W - 90, y + 48], radius=12, fill=BTN)
            d.text((W - 158, y + 28), "Kabul", font=_font(9), fill=TEXT)
        y += 78
    _bottom_nav(d, 3)
    path = SHOTS / "06_bildirimler.png"
    img.save(path)
    return path


def shot_profile() -> Path:
    img = _phone_frame()
    d = ImageDraw.Draw(img)
    _status_bar(d)
    d.text((20, 50), "Profil", font=_font(22, True), fill=TEXT)
    _rounded_card(d, 16, 90, W - 32, 110)
    _avatar(d, 50, 130, r=28, color=(233, 30, 99))
    d.text((90, 108), "Vibe Kullanicisi", font=_font(14, True), fill=TEXT)
    d.text((90, 128), "@vibekullanici", font=_font(11), fill=MUTED)
    d.text((90, 148), "120 puan", font=_font(11), fill=ACCENT)
    _rounded_card(d, 16, 215, W - 32, 160)
    d.text((32, 232), "Mini Vibe  |  Seviye 2", font=_font(12, True), fill=TEXT)
    d.rounded_rectangle([32, 260, W - 32, 278], radius=8, fill=(50, 20, 70))
    d.rounded_rectangle([32, 260, 200, 278], radius=8, fill=ACCENT)
    d.text((32, 292), "Robotu gelistir (-20 puan)", font=_font(10), fill=MUTED)
    d.rounded_rectangle([32, 320, W - 32, 355], radius=18, fill=BTN)
    d.text((W // 2 - 55, 332), "Gelistir", font=_font(12, True), fill=TEXT)
    d.text((20, 395), "Gonderilerim  |  Begendiklerim", font=_font(11, True), fill=ACCENT)
    _post_card(d, 430, "Ben", "Ilk gonderim!", "3", "1")
    _bottom_nav(d, 4)
    path = SHOTS / "07_profil.png"
    img.save(path)
    return path


def shot_messages() -> Path:
    img = _phone_frame()
    d = ImageDraw.Draw(img)
    _status_bar(d, "Mesajlar")
    d.text((20, 50), "Sohbetler", font=_font(20, True), fill=TEXT)
    chats = [("Ayse Yilmaz", "Gorusuruz!", "14:20"), ("Mehmet Demir", "Tamamdir", "Dun")]
    y = 100
    for name, msg, time in chats:
        _rounded_card(d, 16, y, W - 32, 72)
        _avatar(d, 38, y + 36)
        d.text((68, y + 16), name, font=_font(12, True), fill=TEXT)
        d.text((68, y + 36), msg, font=_font(10), fill=MUTED)
        d.text((W - 60, y + 16), time, font=_font(9), fill=MUTED)
        d.ellipse([W - 36, y + 40, W - 24, y + 52], fill=ACCENT)
        y += 82
    path = SHOTS / "08_mesajlar.png"
    img.save(path)
    return path


def shot_chat() -> Path:
    img = _phone_frame()
    d = ImageDraw.Draw(img)
    _status_bar(d, "Ayse Yilmaz")
    bubbles = [
        (True, "Selam! Naber?", 620),
        (False, "Iyiyim, sen?", 560),
        (True, "Robotumu seviye 3 yaptim!", 500),
        (False, "Harika!", 450),
    ]
    for mine, text, y in bubbles:
        if mine:
            d.rounded_rectangle([24, y, W * 0.7, y + 44], radius=18, fill=(60, 20, 80))
            d.text((36, y + 12), text, font=_font(11), fill=TEXT)
        else:
            d.rounded_rectangle([W * 0.35, y, W - 24, y + 44], radius=18, fill=BTN)
            d.text((W * 0.35 + 12, y + 12), text, font=_font(11), fill=TEXT)
    d.rounded_rectangle([16, H - 58, W - 16, H - 18], radius=22, fill=(26, 10, 40), outline=CARD_BORDER)
    d.text((32, H - 46), "Mesaj yaz...", font=_font(11), fill=MUTED)
    path = SHOTS / "09_sohbet.png"
    img.save(path)
    return path


def shot_robot_fullscreen() -> Path:
    img = _phone_frame()
    d = ImageDraw.Draw(img)
    d.rectangle([0, 0, W, H], fill=(0, 0, 0, 220))
    d.text((W // 2 - 30, 40), "Kapat", font=_font(12), fill=TEXT)
    d.ellipse([W // 2 - 80, 280, W // 2 + 80, 440], fill=(120, 0, 0))
    d.ellipse([W // 2 - 60, 300, W // 2 + 60, 420], fill=ACCENT)
    d.text((W // 2 - 55, 360), "ROBOT", font=_font(14, True), fill=TEXT)
    d.text((W // 2 - 90, 480), "Tam ekran Lottie animasyon", font=_font(11), fill=MUTED)
    path = SHOTS / "10_robot_tam_ekran.png"
    img.save(path)
    return path


def generate_screenshots() -> list[tuple[str, Path, str]]:
    SHOTS.mkdir(parents=True, exist_ok=True)
    data = [
        ("Giris Ekrani", shot_login(), "E-posta ve sifre ile guvenli giris. Kayit ol linki ile yeni hesap acilir."),
        ("Kayit Ekrani", shot_register(), "Ad soyad, benzersiz kullanici adi ve e-posta ile hesap olusturma."),
        ("Ana Feed", shot_feed(), "Gonderi akisi, robot ozeti, begeni/yorum etkilesimi ve alt navigasyon."),
        ("Kesfet", shot_explore(), "Kullanici arama, onerilen profiller ve hizli takip etme."),
        ("Yeni Gonderi", shot_new_post(), "280 karakter metin gonderisi; paylasimda +10 puan kazanilir."),
        ("Bildirimler", shot_notifications(), "Begeni, yorum, takip ve takip istegi bildirimleri."),
        ("Profil ve Robot", shot_profile(), "Profil bilgileri, robot seviyesi, puan ve gonderi sekmeleri."),
        ("Mesajlar", shot_messages(), "Birebir sohbet listesi ve okunmamis mesaj gostergesi."),
        ("Sohbet", shot_chat(), "Gercek zamanli metin mesajlasma ve okundu bilgisi."),
        ("Robot Tam Ekran", shot_robot_fullscreen(), "Kucuk Lottie robota tiklaninca tam ekran animasyon acilir."),
    ]
    return data


class TanitimPdf(FPDF):
    def footer(self):
        self.set_y(-14)
        self.set_font("Arial", size=9)
        self.set_text_color(120, 120, 120)
        self.cell(0, 8, f"VibeLife Proje Tanitimi  |  Sayfa {self.page_no()}/{{nb}}", align="C")


def _section(pdf: TanitimPdf, title: str):
    pdf.ln(3)
    pdf.set_x(pdf.l_margin)
    pdf.set_font("Arial", "B", 14)
    pdf.set_text_color(30, 30, 30)
    pdf.multi_cell(0, 7, title)
    pdf.ln(1)


def _body(pdf: TanitimPdf, text: str):
    pdf.set_x(pdf.l_margin)
    pdf.set_font("Arial", size=10)
    pdf.set_text_color(25, 25, 25)
    pdf.multi_cell(0, 5.2, text)
    pdf.ln(1)


def _bullet(pdf: TanitimPdf, text: str):
    pdf.set_x(pdf.l_margin)
    pdf.set_font("Arial", size=10)
    pdf.multi_cell(0, 5.2, f"- {text}")


def _screen_page(pdf: TanitimPdf, title: str, image: Path, description: str, details: list[str]):
    pdf.add_page()
    _section(pdf, title)
    usable_w = pdf.w - pdf.l_margin - pdf.r_margin
    img_w = min(usable_w * 0.42, 55)
    img_h = img_w * (H / W)
    x = (pdf.w - img_w) / 2
    pdf.image(str(image), x=x, y=pdf.get_y(), w=img_w, h=img_h)
    pdf.ln(img_h + 4)
    _body(pdf, description)
    for item in details:
        _bullet(pdf, item)


def build_pdf(screens: list[tuple[str, Path, str]]) -> Path:
    pdf = TanitimPdf()
    pdf.alias_nb_pages()
    pdf.set_margins(16, 16, 16)
    pdf.set_auto_page_break(auto=True, margin=16)
    pdf.add_font("Arial", "", str(FONT_REG))
    pdf.add_font("Arial", "B", str(FONT_BOLD))

    # Kapak
    pdf.add_page()
    pdf.set_font("Arial", "B", 26)
    pdf.set_text_color(120, 0, 0)
    pdf.ln(28)
    pdf.cell(0, 14, "VibeLife", align="C", new_x="LMARGIN", new_y="NEXT")
    pdf.set_font("Arial", "B", 18)
    pdf.set_text_color(40, 40, 40)
    pdf.cell(0, 12, "Mobil Sosyal Platform", align="C", new_x="LMARGIN", new_y="NEXT")
    pdf.ln(6)
    pdf.set_font("Arial", size=12)
    pdf.set_text_color(90, 90, 90)
    pdf.cell(0, 8, "Detayli Proje Tanitim Dokumani", align="C", new_x="LMARGIN", new_y="NEXT")
    pdf.cell(0, 8, date.today().strftime("%d.%m.%Y"), align="C", new_x="LMARGIN", new_y="NEXT")
    pdf.ln(14)
    _body(
        pdf,
        "VibeLife; gonderi paylasimi, takip sistemi, mesajlasma, bildirimler ve robot "
        "tabanli oyunlastirma ile kullanicilara sosyal etkilesim ve eglence sunan "
        "capraz platform bir Flutter uygulamasidir. Backend olarak Firebase (Auth + Firestore) "
        "kullanilir. Bu dokuman projenin amacini, mimarisini, ekranlarini ve teknik "
        "ozelliklerini ekran gorselleriyle birlikte aciklar.",
    )

    # 1 Proje ozeti
    pdf.add_page()
    _section(pdf, "1. Proje Ozeti")
    _body(
        pdf,
        "VibeLife, genclik ve sosyal medya kullanan kitleye yonelik, hafif ve hizli bir "
        "mobil deneyim sunmayi hedefler. Metin tabanli gonderiler, profil ozellestirme, "
        "gizli hesap destegi, birebir mesajlasma ve her kullaniciya ozel gelisen bir "
        "robot karakteri uygulamanin temel ayirt edici unsurlaridir.",
    )
    _section(pdf, "1.1 Temel Hedefler")
    _bullet(pdf, "Kullanicilar arasi guvenli sosyal etkilesim saglamak")
    _bullet(pdf, "Gunluk kullanimi tesvik eden puan ve robot gelisim sistemi kurmak")
    _bullet(pdf, "Ucretsiz Firebase altyapisi ile surdurulebilir maliyet hedeflemek")
    _bullet(pdf, "Android, iOS, Web ve Windows platformlarinda tek kod tabani")

    _section(pdf, "1.2 Hedef Kitle")
    _bullet(pdf, "Sosyal medya kullanan 16-35 yas arasi kullanicilar")
    _bullet(pdf, "Oyunlastirma ve dijital avatar seven kullanicilar")
    _bullet(pdf, "Hafif, hizli ve modern arayuz arayan mobil kullanicilar")

    # 2 Ozellikler
    pdf.add_page()
    _section(pdf, "2. Uygulama Ozellikleri")
    features = [
        ("Kimlik Dogrulama", "E-posta/sifre ile kayit ve giris, sifre sifirlama, hesap silme."),
        ("Feed (Ana Sayfa)", "Global gonderi akisi, begeni/yorum, sikayet, engelleme, puan animasyonlari."),
        ("Kesfet", "Kullanici arama, onerilen profiller, takip/takip istegi."),
        ("Gonderi Olusturma", "280 karakter metin; paylasimda +10 puan."),
        ("Profil", "Avatar, ad/kullanici adi duzenleme, gizli hesap, gonderilerim/begendiklerim."),
        ("Robot Sistemi", "Seviye atlama, gelisim puani, Lottie animasyonlar, tam ekran robot."),
        ("Mesajlasma", "1:1 DM, okundu bilgisi, sohbet gizleme."),
        ("Bildirimler", "Begeni, yorum, takip, takip istegi; okunmamis rozet."),
        ("Moderasyon", "Sikayet, otomatik gizleme esigi, moderatör paneli."),
        ("Tema", "Acik/koyu mod destegi."),
    ]
    for name, desc in features:
        _body(pdf, f"{name}: {desc}")

    # 3 Teknoloji
    pdf.add_page()
    _section(pdf, "3. Teknoloji Altyapisi")
    _section(pdf, "3.1 On Yuz (Client)")
    _bullet(pdf, "Flutter 3.3+ (Dart)")
    _bullet(pdf, "Material Design 3, ozel Vibe temasi (app_theme.dart)")
    _bullet(pdf, "Lottie animasyonlar (robot_level_1_4, robot_level_5, seviye_atlama)")
    _bullet(pdf, "SharedPreferences (tema, DM okundu/gizleme durumu)")
    _section(pdf, "3.2 Backend")
    _bullet(pdf, "Firebase Authentication (e-posta/sifre)")
    _bullet(pdf, "Cloud Firestore (NoSQL veritabani)")
    _bullet(pdf, "Firestore Security Rules (firestore.rules)")
    _bullet(pdf, "Proje ID: vibe-life-app")
    _section(pdf, "3.3 Platform Destegi")
    _bullet(pdf, "Android (birincil)")
    _bullet(pdf, "iOS, Web, Windows, macOS yapilandirmasi mevcut")

    # 4 Mimari
    pdf.add_page()
    _section(pdf, "4. Mimari ve Veri Modeli")
    _body(
        pdf,
        "Uygulama katmanli olmayan pratik bir yapi kullanir: UI sayfalari dogrudan "
        "SosyalServis ve Firestore stream'lerine baglanir. Is mantigi lib/sosyal_servis.dart "
        "dosyasinda toplanmistir.",
    )
    _section(pdf, "4.1 Firestore Koleksiyonlari")
    _bullet(pdf, "users/{uid} — profil, puan, robot, gizlilik ayarlari")
    _bullet(pdf, "users/{uid}/following, followers, followRequests — sosyal grafik")
    _bullet(pdf, "users/{uid}/notifications — uygulama ici bildirimler")
    _bullet(pdf, "users/{uid}/blocked, blockedBy — engelleme")
    _bullet(pdf, "users/{uid}/likedPosts — begenilen gonderiler")
    _bullet(pdf, "posts/{id}/likes, comments — icerik ve etkilesim")
    _bullet(pdf, "chats/{uid1_uid2}/messages — birebir mesajlasma")
    _bullet(pdf, "reports/{id} — moderasyon kuyrugu")
    _bullet(pdf, "usernames/{kucukAd} — benzersiz kullanici adi indeksi")
    _section(pdf, "4.2 Navigasyon Yapisi")
    _body(
        pdf,
        "Giris sonrasi FeedPage alt navigasyonu: Ana Sayfa, Kesfet, Yeni Gonderi, "
        "Bildirimler, Profil. Mesajlar feed basligindaki ikondan acilir. Baska kullanici "
        "profilleri UserProfilePage uzerinden goruntulenir.",
    )

    # 5 Gamification
    pdf.add_page()
    _section(pdf, "5. Oyunlastirma (Puan ve Robot)")
    _bullet(pdf, "Gonderi paylas: +10 puan")
    _bullet(pdf, "Begenilen gonderi sahibi: +2 puan (begenen icin)")
    _bullet(pdf, "Yorum yap: +3 puan")
    _bullet(pdf, "Takip et (ilk kez): +5 puan")
    _bullet(pdf, "Robot gelistir: -20 puan, gelisimPuani artar, seviye atlama")
    _bullet(pdf, "Seviye 1-4: robot_level_1_4 Lottie; Seviye 5+: robot_level_5")
    _bullet(pdf, "Robot animasyonuna tiklaninca tam ekran overlay acilir")
    _body(
        pdf,
        "Puan animasyonlari puan_animasyon.dart ile gosterilir. Robot karti profil "
        "sayfasinda yer alir ve kullanicinin uygulamaya duzenli donmesini tesvik eder.",
    )

    # 6 Guvenlik
    pdf.add_page()
    _section(pdf, "6. Guvenlik ve Moderasyon")
    _bullet(pdf, "Firestore Security Rules ile alan bazli yazma kisitlari")
    _bullet(pdf, "isModerator alani yalnizca moderatör tarafindan degistirilebilir")
    _bullet(pdf, "Sikayet sayaci kurallarla dogrulanir (post: 5, yorum: 4 esik)")
    _bullet(pdf, "Engelleme: blocked/blockedBy cift yonlu yapi")
    _bullet(pdf, "Gizli hesap: takipci olmayanlar gonderileri feed'de goremez (client filtre)")
    _bullet(pdf, "Moderatör paneli: rapor inceleme, icerik gizleme, kullanici gizleme")
    _body(
        pdf,
        "Uygulama Spark (ucretsiz) Firebase planinda calisacak sekilde tasarlanmistir. "
        "Sunucu tarafli Cloud Functions kullanilmamaktadir.",
    )

    # 7 Ekranlar
    pdf.add_page()
    _section(pdf, "7. Ekran Goruntuleri ve Aciklamalar")
    _body(
        pdf,
        "Asagida VibeLife'in ana ekranlari yer almaktadir. Gorseller uygulamanin koyu "
        "temasina ve gercek arayuz yapisina uygun olarak olusturulmustur.",
    )

    screen_details = {
        "Giris Ekrani": [
            "Gradient arka plan ve VibeLife marka basligi",
            "Firebase Auth ile e-posta/sifre girisi",
            "Kayit sayfasina gecis linki",
        ],
        "Kayit Ekrani": [
            "Benzersiz kullanici adi kontrolu (usernames koleksiyonu)",
            "Transaction ile atomik kayit",
            "Varsayilan robot ve 0 puan ile baslangic",
        ],
        "Ana Feed": [
            "Robot ozet karti ve mesajlar kisayolu",
            "Gonderi kartlari: avatar, metin, begeni, yorum",
            "Sayfalama ile performans optimizasyonu",
            "Gizli hesap ve engel filtreleri",
        ],
        "Kesfet": [
            "Canli arama (Turkce karakter normalizasyonu)",
            "Onerilen kullanicilar listesi",
            "Satir ici takip et / takipten cik",
        ],
        "Yeni Gonderi": [
            "280 karakter limiti",
            "Batch ile post + puan guncelleme",
            "Paylasim sonrasi ana feed'e donus",
        ],
        "Bildirimler": [
            "Okunmamis bildirim rozeti (bottom nav)",
            "Takip istegi kabul/red butonlari",
            "Bildirimden gonderi detayina gecis",
        ],
        "Profil ve Robot": [
            "Profil duzenleme, avatar secimi (12 emoji avatar)",
            "Robot seviye cubugu ve gelistir butonu",
            "Gonderilerim / Begendiklerim sekmeleri",
            "Ayarlar: gizli hesap, tema, sifre sifirlama, hesap sil",
        ],
        "Mesajlar": [
            "Katilimcilara gore filtrelenmis sohbet listesi",
            "Okunmamis mesaj noktasi",
            "Yeni sohbet baslatma",
        ],
        "Sohbet": [
            "Gercek zamanli mesaj stream'i",
            "lastSeenBy ile goruldu/gonderildi",
            "Kendi mesajini silme (soft delete)",
        ],
        "Robot Tam Ekran": [
            "RobotLottieView tamEkranGoster metodu",
            "Seviye 1-4: robot_level_1_4 animasyonu",
            "Seviye 5+: robot_level_5 animasyonu",
        ],
    }

    for title, image, short_desc in screens:
        _screen_page(pdf, title, image, short_desc, screen_details.get(title, []))

    # 8 Dosya yapisi
    pdf.add_page()
    _section(pdf, "8. Proje Dosya Yapisi (Ozet)")
    files = [
        "lib/main.dart — Uygulama girisi, auth yonlendirme, tema",
        "lib/feed_page.dart — Ana shell, feed, PostCard",
        "lib/explore_page.dart — Kullanici kesfi",
        "lib/newpost_page.dart — Gonderi olusturma",
        "lib/profile_page.dart — Profil, robot, ayarlar, moderasyon",
        "lib/user_profile_page.dart — Baska kullanici profili",
        "lib/messages_page.dart — DM listesi ve sohbet",
        "lib/notifications_page.dart — Bildirimler",
        "lib/sosyal_servis.dart — Tum Firestore islemleri",
        "lib/hesap_sil_servis.dart — Hesap silme temizligi",
        "firestore.rules — Guvenlik kurallari",
        "assets/animations/ — Lottie robot animasyonlari",
    ]
    for f in files:
        _bullet(pdf, f)

    # 9 Sonuc
    pdf.add_page()
    _section(pdf, "9. Sonuc ve Deger Onerisi")
    _body(
        pdf,
        "VibeLife; sosyal ag temeli, mesajlasma, bildirimler ve robot tabanli "
        "oyunlastirmayi tek bir mobil deneyimde birlestiren, Firebase ucretsiz planina "
        "uyumlu, genisletilebilir bir projedir. Mevcut kod tabani yeni ozellikler "
        "(takip feed'i, gunluk gorevler, streak, liderlik tablosu vb.) icin hazir "
        "bir altyapi sunmaktadir.",
    )
    _section(pdf, "9.1 Rakiplerden Farki")
    _bullet(pdf, "Robot karakter ve seviye sistemi ile oyunlastirilmis sosyal deneyim")
    _bullet(pdf, "Turkce arayuz ve yerel kullanici deneyimi")
    _bullet(pdf, "Hafif metin odakli yapi — dusuk bant genisligi")
    _bullet(pdf, "Acik/koyu tema ve modern gradient tasarim")
    _section(pdf, "9.2 Surum Bilgisi")
    _body(pdf, "Surum: 1.0.0+1  |  Platform: Flutter 3.3.3  |  Firebase Proje: vibe-life-app")

    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    pdf.output(str(OUTPUT))
    return OUTPUT


if __name__ == "__main__":
    screens = generate_screenshots()
    path = build_pdf(screens)
    print(f"PDF olusturuldu: {path}")
    print(f"Ekran goruntuleri: {SHOTS}")
