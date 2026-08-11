#!/usr/bin/env python3
"""VibeLife icin kod uzerinden ogrenme ders kitabi DOCX uretici."""
from __future__ import annotations

import html
import subprocess
from dataclasses import dataclass
from datetime import date
from pathlib import Path
from typing import Iterable

from docx import Document
from docx.enum.section import WD_SECTION
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.oxml import OxmlElement
from docx.oxml.ns import qn
from docx.shared import Inches, Pt, RGBColor


ROOT = Path(__file__).resolve().parent.parent
DOCS = ROOT / "docs"
DOCX_OUT = DOCS / "VibeLife_Ders_Kitabi_Cilt_1.docx"
HTML_OUT = DOCS / "VibeLife_Ders_Kitabi_Cilt_1.html"
PDF_OUT = DOCS / "VibeLife_Ders_Kitabi_Cilt_1.pdf"


BLUE = RGBColor(46, 116, 181)
DARK_BLUE = RGBColor(31, 77, 120)
MUTED = RGBColor(90, 90, 90)
INK = RGBColor(25, 25, 25)
CODE_BG = "F4F6F9"
CALLOUT_BG = "E8EEF5"


@dataclass(frozen=True)
class Snippet:
    path: str
    start: int
    end: int
    title: str
    note: str


@dataclass(frozen=True)
class Chapter:
    title: str
    why: str
    goals: tuple[str, ...]
    snippets: tuple[Snippet, ...]
    explanations: tuple[tuple[str, str], ...]
    exercises: tuple[str, ...]


def set_run_font(run, name: str = "Calibri", size: float | None = None,
                 color: RGBColor | None = None, bold: bool | None = None,
                 italic: bool | None = None) -> None:
    run.font.name = name
    run._element.rPr.rFonts.set(qn("w:ascii"), name)
    run._element.rPr.rFonts.set(qn("w:hAnsi"), name)
    if size is not None:
        run.font.size = Pt(size)
    if color is not None:
        run.font.color.rgb = color
    if bold is not None:
        run.bold = bold
    if italic is not None:
        run.italic = italic


def shade_paragraph(paragraph, fill: str) -> None:
    p_pr = paragraph._p.get_or_add_pPr()
    shd = p_pr.find(qn("w:shd"))
    if shd is None:
        shd = OxmlElement("w:shd")
        p_pr.append(shd)
    shd.set(qn("w:fill"), fill)


def set_cell_shading(cell, fill: str) -> None:
    tc_pr = cell._tc.get_or_add_tcPr()
    shd = tc_pr.find(qn("w:shd"))
    if shd is None:
        shd = OxmlElement("w:shd")
        tc_pr.append(shd)
    shd.set(qn("w:fill"), fill)


def set_cell_margins(cell, top: int = 100, start: int = 140,
                     bottom: int = 100, end: int = 140) -> None:
    tc = cell._tc
    tc_pr = tc.get_or_add_tcPr()
    tc_mar = tc_pr.first_child_found_in("w:tcMar")
    if tc_mar is None:
        tc_mar = OxmlElement("w:tcMar")
        tc_pr.append(tc_mar)
    for m, v in {"top": top, "start": start, "bottom": bottom, "end": end}.items():
        node = tc_mar.find(qn(f"w:{m}"))
        if node is None:
            node = OxmlElement(f"w:{m}")
            tc_mar.append(node)
        node.set(qn("w:w"), str(v))
        node.set(qn("w:type"), "dxa")


def paragraph_border_bottom(paragraph, color: str = "D9E2F3", size: str = "8") -> None:
    p_pr = paragraph._p.get_or_add_pPr()
    p_bdr = p_pr.find(qn("w:pBdr"))
    if p_bdr is None:
        p_bdr = OxmlElement("w:pBdr")
        p_pr.append(p_bdr)
    bottom = p_bdr.find(qn("w:bottom"))
    if bottom is None:
        bottom = OxmlElement("w:bottom")
        p_bdr.append(bottom)
    bottom.set(qn("w:val"), "single")
    bottom.set(qn("w:sz"), size)
    bottom.set(qn("w:space"), "1")
    bottom.set(qn("w:color"), color)


def configure_document(doc: Document) -> None:
    section = doc.sections[0]
    section.top_margin = Inches(1)
    section.bottom_margin = Inches(1)
    section.left_margin = Inches(1)
    section.right_margin = Inches(1)
    section.header_distance = Inches(0.492)
    section.footer_distance = Inches(0.492)

    styles = doc.styles
    normal = styles["Normal"]
    normal.font.name = "Calibri"
    normal._element.rPr.rFonts.set(qn("w:ascii"), "Calibri")
    normal._element.rPr.rFonts.set(qn("w:hAnsi"), "Calibri")
    normal.font.size = Pt(11)
    normal.paragraph_format.space_after = Pt(6)
    normal.paragraph_format.line_spacing = 1.25

    for name, size, color, before, after in [
        ("Heading 1", 16, BLUE, 18, 10),
        ("Heading 2", 13, BLUE, 14, 7),
        ("Heading 3", 12, DARK_BLUE, 10, 5),
    ]:
        style = styles[name]
        style.font.name = "Calibri"
        style._element.rPr.rFonts.set(qn("w:ascii"), "Calibri")
        style._element.rPr.rFonts.set(qn("w:hAnsi"), "Calibri")
        style.font.size = Pt(size)
        style.font.color.rgb = color
        style.font.bold = True
        style.paragraph_format.space_before = Pt(before)
        style.paragraph_format.space_after = Pt(after)
        style.paragraph_format.line_spacing = 1.25

    if "CodeBlock" not in styles:
        code = styles.add_style("CodeBlock", 1)
        code.font.name = "Consolas"
        code._element.rPr.rFonts.set(qn("w:ascii"), "Consolas")
        code._element.rPr.rFonts.set(qn("w:hAnsi"), "Consolas")
        code.font.size = Pt(7.6)
        code.font.color.rgb = RGBColor(35, 35, 35)
        code.paragraph_format.space_before = Pt(0)
        code.paragraph_format.space_after = Pt(0)
        code.paragraph_format.line_spacing = 1.0
        code.paragraph_format.left_indent = Inches(0.05)
        code.paragraph_format.right_indent = Inches(0.05)

    header = section.header.paragraphs[0]
    header.text = "VibeLife Ders Kitabi - Cilt 1"
    header.alignment = WD_ALIGN_PARAGRAPH.RIGHT
    set_run_font(header.runs[0], size=9, color=MUTED)

    footer = section.footer.paragraphs[0]
    footer.text = "Kod uzerinden yazilim ogrenme rehberi"
    footer.alignment = WD_ALIGN_PARAGRAPH.CENTER
    set_run_font(footer.runs[0], size=9, color=MUTED)


def read_lines(path: str) -> list[str]:
    return (ROOT / path).read_text(encoding="utf-8").splitlines()


def add_title_page(doc: Document) -> None:
    p = doc.add_paragraph()
    p.paragraph_format.space_before = Pt(70)
    p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    r = p.add_run("VibeLife Ders Kitabi")
    set_run_font(r, size=28, color=RGBColor(0, 0, 0), bold=True)

    p = doc.add_paragraph()
    p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    r = p.add_run("Cilt 1: Kod okuma sirasi, temel dosyalar ve calisma yontemi")
    set_run_font(r, size=14, color=MUTED)

    p = doc.add_paragraph()
    p.paragraph_format.space_before = Pt(18)
    p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    r = p.add_run("Flutter + Dart + Firebase uygulamasini kendi kodlari uzerinden ogrenme rehberi")
    set_run_font(r, size=11.5, color=MUTED, italic=True)

    p = doc.add_paragraph()
    p.paragraph_format.space_before = Pt(70)
    p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    r = p.add_run(f"Olusturulma tarihi: {date.today().strftime('%d.%m.%Y')}")
    set_run_font(r, size=10.5, color=MUTED)

    p = doc.add_paragraph()
    p.paragraph_format.space_before = Pt(18)
    p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    r = p.add_run("Not: Bu cilt, projedeki binlerce satiri tek tek ezberletmek yerine kodu okumayi ogretir. Sonraki ciltler ayni sablonla buyutulebilir.")
    set_run_font(r, size=10.5, color=DARK_BLUE)
    doc.add_page_break()


def add_callout(doc: Document, title: str, body: str) -> None:
    table = doc.add_table(rows=1, cols=1)
    table.autofit = False
    table.columns[0].width = Inches(6.35)
    cell = table.cell(0, 0)
    set_cell_shading(cell, CALLOUT_BG)
    set_cell_margins(cell)
    p = cell.paragraphs[0]
    p.paragraph_format.space_after = Pt(3)
    r = p.add_run(title)
    set_run_font(r, size=10.5, bold=True, color=DARK_BLUE)
    p = cell.add_paragraph(body)
    p.paragraph_format.space_after = Pt(0)
    for run in p.runs:
        set_run_font(run, size=10.3, color=INK)


def add_bullets(doc: Document, items: Iterable[str]) -> None:
    for item in items:
        p = doc.add_paragraph(style="List Bullet")
        p.paragraph_format.space_after = Pt(4)
        p.add_run(item)


def add_numbered(doc: Document, items: Iterable[str]) -> None:
    for item in items:
        p = doc.add_paragraph(style="List Number")
        p.paragraph_format.space_after = Pt(4)
        p.add_run(item)


def add_key_value_table(doc: Document, rows: list[tuple[str, str]]) -> None:
    table = doc.add_table(rows=1, cols=2)
    table.style = "Table Grid"
    table.autofit = False
    table.columns[0].width = Inches(1.55)
    table.columns[1].width = Inches(4.75)
    hdr = table.rows[0].cells
    hdr[0].text = "Kavram"
    hdr[1].text = "Bu projede nasil okunur?"
    for cell in hdr:
        set_cell_shading(cell, "F2F4F7")
        set_cell_margins(cell)
        for p in cell.paragraphs:
            for r in p.runs:
                set_run_font(r, bold=True)
    for key, val in rows:
        cells = table.add_row().cells
        cells[0].text = key
        cells[1].text = val
        for cell in cells:
            set_cell_margins(cell)


def add_code_block(doc: Document, path: str, start: int, end: int) -> None:
    lines = read_lines(path)
    selected = lines[start - 1:end]
    for offset, line in enumerate(selected, start=start):
        p = doc.add_paragraph(style="CodeBlock")
        shade_paragraph(p, CODE_BG)
        r = p.add_run(f"{offset:>4} | {line}")
        set_run_font(r, name="Consolas", size=7.6, color=RGBColor(35, 35, 35))


def add_snippet(doc: Document, snippet: Snippet) -> None:
    h = doc.add_paragraph(style="Heading 3")
    h.add_run(f"{snippet.title} - {snippet.path}:{snippet.start}-{snippet.end}")
    p = doc.add_paragraph(snippet.note)
    p.paragraph_format.space_after = Pt(5)
    add_code_block(doc, snippet.path, snippet.start, snippet.end)


def add_explanation_pairs(doc: Document, pairs: tuple[tuple[str, str], ...]) -> None:
    if not pairs:
        return
    doc.add_paragraph("Kod okurken dikkat et:", style="Heading 3")
    for key, value in pairs:
        p = doc.add_paragraph()
        p.paragraph_format.space_after = Pt(4)
        r = p.add_run(f"{key}: ")
        set_run_font(r, bold=True, color=DARK_BLUE)
        p.add_run(value)


def add_chapter(doc: Document, index: int, chapter: Chapter) -> None:
    doc.add_paragraph(f"{index}. {chapter.title}", style="Heading 1")
    add_callout(doc, "Bu bolumun amaci", chapter.why)
    doc.add_paragraph("Bu bolumde sunlari ogren:", style="Heading 3")
    add_bullets(doc, chapter.goals)
    for snippet in chapter.snippets:
        add_snippet(doc, snippet)
    add_explanation_pairs(doc, chapter.explanations)
    if chapter.exercises:
        doc.add_paragraph("Mini alistirma", style="Heading 3")
        add_numbered(doc, chapter.exercises)


def chapters() -> list[Chapter]:
    return [
        Chapter(
            title="Projenin kimligi: pubspec.yaml",
            why="Bir Flutter projesinde hangi paketlerin kullanildigini ve uygulamanin hangi varliklari yukledigini once buradan anlarsin.",
            goals=(
                "Flutter projesinin paket mantigini okumak.",
                "Firebase, Lottie ve SharedPreferences paketlerinin gorevini ayirt etmek.",
                "assets bolumunun uygulamadaki animasyon ve avatarlarla iliskisini gormek.",
            ),
            snippets=(
                Snippet("pubspec.yaml", 1, 73, "Paketler ve varliklar", "Bu dosya kod degil YAML formatidir. Girintiler anlamlidir; bir satirin hangi bolume ait oldugunu bosluklar belirler."),
            ),
            explanations=(
                ("dependencies", "Uygulama calisirken gereken paketlerdir. Firebase paketleri giris, veritabani ve guvenlik icin kullanilir."),
                ("dev_dependencies", "Sadece gelistirme ve test sirasinda gereken paketlerdir."),
                ("assets", "Flutter'in uygulama icine gomdugu dosyalardir. Bu projede robot animasyonlari ve avatarlar buradan gelir."),
            ),
            exercises=(
                "firebase_auth satirini bul ve bu paketin hangi dosyalarda import edildigini ara.",
                "assets/animations klasorundeki dosyalar ile robot_lottie_view.dart arasindaki baglantiyi not et.",
            ),
        ),
        Chapter(
            title="Uygulamanin baslangici: main.dart",
            why="main.dart uygulamanin kapisidir. Firebase baslatilir, tema yuklenir, kullanici giris yapmis mi diye bakilir ve dogru sayfaya yonlendirilir.",
            goals=(
                "main() fonksiyonunun neden async oldugunu anlamak.",
                "runApp, MaterialApp, StatelessWidget ve StatefulWidget farkini okumak.",
                "StreamBuilder ve FutureBuilder ile auth akisini takip etmek.",
            ),
            snippets=(
                Snippet("lib/main.dart", 1, 45, "Importlar, main() ve MaterialApp", "Ilk kisim uygulamanin hangi paketlere baglandigini ve ilk ekrana nasil ulastigini gosterir."),
                Snippet("lib/main.dart", 47, 124, "AuthControlPage", "Bu bolum kullanicinin giris durumuna gore login, e-posta dogrulama veya feed sayfasina karar verir."),
            ),
            explanations=(
                ("import", "Baska dosyadaki sinif ve fonksiyonlari bu dosyada kullanmak icin iceri alir."),
                ("late final", "Deger sonradan atanacak ama atandiktan sonra degismeyecek demektir."),
                ("async / await", "Firebase ve yerel depolama gibi bekleme gerektiren islemleri sirali ve okunabilir yapar."),
                ("StreamBuilder", "Auth durumu degistikce ekrani yeniden kurar. Kullanici giris yaparsa stream yeni User degeri verir."),
                ("FutureBuilder", "Bir defalik asenkron karar bekler: e-posta dogrulamasi, profil tamamlandi mi gibi."),
                ("?", "Degerin null olabilecegini soyler. Ornek: String? _sonUid."),
                ("!", "Kod yazari burada null olmadigindan emin oldugunu soyluyor. Yanlis kullanilirsa hata uretir."),
            ),
            exercises=(
                "main.dart icinde FirebaseAuth.instance gecen satirlari isaretle.",
                "VibeHomePage ne zaman donuyor, FeedPage ne zaman donuyor kendi cumlenle yaz.",
                "AuthControlPage'i bir trafik polisi gibi dusun: hangi kosulda hangi ekrana gonderiyor?",
            ),
        ),
        Chapter(
            title="Firebase baslatma ve guvenlik",
            why="Firebase uygulamanin kimlik, veritabani, crash raporu ve App Check tarafini tasir. Bu dosya uygulama acilirken once calisir.",
            goals=(
                "Firebase.initializeApp ne zaman calisir anlamak.",
                "Crashlytics ve App Check'in neden web disinda kosullu calistigini gormek.",
                "switch-case yapisini ve platform kontrolunu okumak.",
            ),
            snippets=(
                Snippet("lib/firebase_bootstrap.dart", 1, 60, "Firebase bootstrap", "Bu dosya main.dart icinden cagrilir ve Firebase servislerini hazirlar."),
            ),
            explanations=(
                ("kIsWeb", "Kodun web platformunda calisip calismadigini soyler."),
                ("defaultTargetPlatform", "Android, iOS, macOS gibi platforma gore farkli ayar yapmaya yarar."),
                ("try / catch", "Hata olursa uygulamanin tamamen cokmesini engelleyip hatayi kontrollu yakalar."),
            ),
            exercises=(
                "App Check debug modda hangi provider'i kullaniyor bul.",
                "Crashlytics hangi platformlarda aktif ediliyor not et.",
            ),
        ),
        Chapter(
            title="Kucuk dosyalardan Dart ogrenme",
            why="Buyuk ekran dosyalarindan once kucuk yardimci dosyalarla Dart dilinin temel isaretlerini ve class mantigini ogrenmek daha rahattir.",
            goals=(
                "enum, class, getter, final ve static kavramlarini okumak.",
                "SharedPreferences ile cihaz icine kucuk bilgi kaydetmeyi anlamak.",
                "Snackbar gibi ortak bir UI yardimcisinin nasil tasarlandigini gormek.",
            ),
            snippets=(
                Snippet("lib/theme_controller.dart", 1, 47, "Tema kontrolu", "Tema tercihi hafizada tutulur ve degisince ekranlara haber verilir."),
                Snippet("lib/vibe_snackbar.dart", 1, 92, "Ortak snackbar", "Uygulamanin hata, uyari, bilgi ve basari mesajlari tek yerden stillendirilir."),
                Snippet("lib/utils/tarih_saat.dart", 1, 13, "Tarih formatlama", "Firestore Timestamp degerini ekranda okunur metne ceviren kucuk ve temiz fonksiyon."),
            ),
            explanations=(
                ("enum", "Sinirli sayida sabit secenek tanimlar. Ornek: VibeMesajTipi.hata veya VibeAppearance.dark."),
                ("ChangeNotifier", "Bir deger degistiginde onu dinleyen widget'lara haber vermek icin kullanilir."),
                ("get", "Fonksiyon gibi hesaplanan ama alan gibi okunan degerdir. Ornek: themeMode."),
                ("switch", "Bir degere gore farkli kod bloklari calistirir."),
                ("BuildContext", "Widget'in ekrandaki yerini ve tema/navigator gibi cevre bilgilerini tasir."),
            ),
            exercises=(
                "VibeMesajTipi enumuna yeni bir tip eklense switch icinde neden yeni case gerekir?",
                "theme_controller.dart icinde notifyListeners hangi durumlarda cagiriliyor bul.",
            ),
        ),
        Chapter(
            title="Ana kabuk ve alt sekmeler: feed_page.dart",
            why="Kullanici giris yaptiktan sonra uygulamanin ana haritasi bu dosyada kurulur. Feed, kesfet, yeni gonderi, bildirim ve profil sekmeleri buradan acilir.",
            goals=(
                "StatefulWidget'in yasam dongusunu okumak.",
                "initState, dispose ve didChangeAppLifecycleState ne is yapar anlamak.",
                "IndexedStack ve BottomNavigationBar ile sayfa degistirmeyi takip etmek.",
            ),
            snippets=(
                Snippet("lib/feed_page.dart", 1, 95, "Sekme sistemi ve yasam dongusu", "Bu kisim hangi sekmede hangi sayfanin acilacagini ve ilk acilista hangi servislerin calistigini gosterir."),
                Snippet("lib/feed_page.dart", 97, 168, "Robot senkronu ve surum notu", "Uygulama acilinca veya on plana gelince robot ve gorev senkronizasyonu yapilir."),
                Snippet("lib/feed_page.dart", 178, 257, "Alt navigasyon", "BottomNavigationBar kullanicinin sekmeler arasinda gezmesini saglar; bildirim sekmesinde okunmamis sayac vardir."),
            ),
            explanations=(
                ("initState", "Sayfa ilk olustugunda bir kez calisir."),
                ("dispose", "Sayfa kapanirken timer gibi kaynaklari temizler."),
                ("Timer.periodic", "Belirli araliklarla ayni islemi tekrar eder."),
                ("IndexedStack", "Secili sekmeyi gosterirken diger acilmis sekmeleri bellekte tutar."),
                ("setState", "State icindeki deger degisti, ekrani yeniden ciz demektir."),
            ),
            exercises=(
                "_secilenIndeks degeri 0 iken hangi sayfa gorunur?",
                "Yeni gonderi paylasildiktan sonra neden _sekmeyeGit(0) cagriliyor?",
            ),
        ),
        Chapter(
            title="Gonderi paylasma akisi",
            why="Bir butona basildiginda UI, Firebase Auth, Firestore batch, sosyal servis, robot servisi ve gorev sistemi birlikte calisir. Bu bolum uygulamanin en ogretici akislarindan biridir.",
            goals=(
                "Form verisini okumak ve bosluk kontrolu yapmak.",
                "Firestore batch ile birden fazla yazmayi birlikte yapmak.",
                "try/catch/finally ile yukleniyor durumunu dogru kapatmak.",
            ),
            snippets=(
                Snippet("lib/newpost_page.dart", 1, 40, "Sayfa ve controller", "TextEditingController kullanicinin yazdigi metni okur; isLoading buton durumunu kontrol eder."),
                Snippet("lib/newpost_page.dart", 42, 164, "gonderiPaylas fonksiyonu", "Gonderi paylasmanin ana is akisi: kontrol, Firestore yazma, puan, mention, gorev, robot aksiyonu."),
            ),
            explanations=(
                ("TextEditingController", "TextField icindeki metni kod tarafindan okumaya ve temizlemeye yarar."),
                ("trim()", "Metnin basindaki ve sonundaki bosluklari siler."),
                ("batch.set / batch.update", "Birden fazla Firestore islemini tek commit ile yapar."),
                ("FieldValue.increment", "Sayaclari mevcut degerin ustune ekleyerek artirir."),
                ("finally", "Islem basarili da olsa hata da olsa calisir; loading kapatmak icin idealdir."),
            ),
            exercises=(
                "Kullanici null ise neden Firestore'a hic gidilmiyor?",
                "Post olusturulurken posts koleksiyonuna hangi alanlar yaziliyor tek tek listele.",
                "RobotServis.sosyalAksiyon satiri silinse oyun mekaniginde ne eksilir?",
            ),
        ),
        Chapter(
            title="Sosyal servis katmani",
            why="UI dosyalari Firestore detaylarini her yerde tekrar etmek yerine SosyalServis ve alt servisleri kullanir. Bu, kodun daha okunabilir ve toparli kalmasini saglar.",
            goals=(
                "Facade desenini bu projedeki haliyle gormek.",
                "SosyalCore icindeki ortak hiz limiti ve engel kontrolunu anlamak.",
                "Begeni, yorum, takip ve mesaj fonksiyonlarinin tek kapidan gecmesini okumak.",
            ),
            snippets=(
                Snippet("lib/sosyal/sosyal_core.dart", 1, 90, "Ortak yardimcilar ve hiz limiti", "Sosyal aksiyonlar icin ortak Firestore ornegi, limitler ve rate-limit kontrolu burada bulunur."),
                Snippet("lib/sosyal_servis.dart", 1, 60, "Facade baslangici", "SosyalServis UI tarafina tek bir sinif gibi gorunur; gercekte isi alt servislere dagitir."),
                Snippet("lib/sosyal_servis.dart", 431, 524, "Begeni, yorum ve mesaj cephesi", "Post kartlari ve mesaj ekranlari bu metotlari cagirarak alt servislerle konusur."),
            ),
            explanations=(
                ("static", "Siniftan nesne olusturmadan metodu cagirabilirsin: SosyalServis.takipEt(...) gibi."),
                ("=>", "Tek satirlik fonksiyon govdesidir. Soldaki cagriyi sagdaki metoda iletir."),
                ("required", "Bu named argument verilmeden fonksiyon cagrilamaz demektir."),
                ("Map<String, dynamic>", "Anahtari String olan, degeri farkli tiplerde olabilen veri sozlugudur; Firestore verisi genelde boyle okunur."),
            ),
            exercises=(
                "SosyalServis.begeniDegistir hangi alt servise gidiyor bul.",
                "SosyalCore.gonderiPaylasimHizLimitiKontrol kac milisaniye bekletiyor?",
            ),
        ),
        Chapter(
            title="Robot sistemi",
            why="Robot servisi uygulamanin oyunlastirma beynidir. Enerji, mutluluk, uyku, seviye atlama ve sosyal aksiyon maliyetleri burada hesaplanir.",
            goals=(
                "Model sinifi ile servis sinifi farkini gormek.",
                "Getter, sabitler, clamp ve parse mantigini anlamak.",
                "Transaction ile robot verisinin nasil guncellendigini okumaya baslamak.",
            ),
            snippets=(
                Snippet("lib/robot_servis.dart", 1, 180, "Robot model ve temel kurallar", "RobotDurum veri modelidir; RobotServis ise bu model uzerinde kurallari uygular."),
                Snippet("lib/robot_servis.dart", 189, 248, "Etkilesim enerji maliyeti", "Gonderi, yorum ve begeni gibi aksiyonlar robot enerjisini tuketir; enerji yoksa aksiyon engellenir."),
                Snippet("lib/robot_servis.dart", 512, 690, "Senkron, gelistir, uyut ve sosyal aksiyon", "Firebase transaction bolumleri burada yogunlasir; bu parcayi ikinci okumada daha detayli incele."),
                Snippet("lib/widgets/robot_durum_bari.dart", 1, 64, "Robot durum cubugu widget'i", "Robot servisinden gelen enerji ve mutluluk degerleri ekranda bu widget ile cubuga donusur."),
            ),
            explanations=(
                ("model", "Veriyi tutan siniftir. RobotDurum sadece robotun anlik alanlarini tasir."),
                ("servis", "Is kurallarini calistiran siniftir. RobotServis seviye, enerji ve uyku hesabini yapar."),
                ("clamp", "Degeri belirli aralikta tutar. Enerji ve mutluluk 0-100 disina cikmasin diye kullanilir."),
                ("transaction", "Firestore'da once oku, sonra okudugun degerlere gore guvenli yaz demektir."),
            ),
            exercises=(
                "Gonderi, yorum ve begeni enerji maliyetlerini bul.",
                "Robot odasi hangi seviyede aciliyor?",
                "RobotDurum icindeki final alanlari neden sonradan degistirilmiyor?",
            ),
        ),
        Chapter(
            title="Firestore kurallarini okuma",
            why="Uygulamanin gercek guvenligi sadece UI tarafinda degil Firestore rules dosyasindadir. Bu dosya kim neyi okuyabilir, yazabilir ve silebilir sorusunu cevaplar.",
            goals=(
                "rules dosyasinda function ve match kavramlarini anlamak.",
                "isSignedIn, isOwner, canReadPostData gibi yardimci kurallari okumak.",
                "users ve posts koleksiyonlarinin izinlerini takip etmek.",
            ),
            snippets=(
                Snippet("firestore.rules", 1, 120, "Kimlik ve gorunurluk yardimcilari", "Bu fonksiyonlar alttaki allow kurallarinda tekrar tekrar kullanilir."),
                Snippet("firestore.rules", 638, 760, "users ve posts izinleri", "Kullanici ve gonderi koleksiyonlarinda okuma/yazma izinleri burada tanimlanir."),
            ),
            explanations=(
                ("request.auth", "Istek yapan kullanicinin oturum bilgisidir."),
                ("resource.data", "Veritabaninda zaten duran mevcut belgenin verisidir."),
                ("request.resource.data", "Yazma isleminden sonra belgenin alacagi yeni veridir."),
                ("allow read/create/update/delete", "Okuma, olusturma, guncelleme ve silme izinlerini ayri ayri belirler."),
                ("exists / get", "Firestore icinde baska belge var mi veya verisi ne diye kontrol eder."),
            ),
            exercises=(
                "posts icin allow create hangi fonksiyona baglanmis bul.",
                "Gizli hesap postlarini kimin okuyabilecegini canReadPostData uzerinden acikla.",
            ),
        ),
    ]


def add_intro(doc: Document) -> None:
    doc.add_paragraph("Bu kitabi nasil calisacaksin?", style="Heading 1")
    add_callout(
        doc,
        "Calisma mantigi",
        "Kodlari roman gibi bastan sona okumaya calisma. Her bolumde once amaci oku, sonra kod parcasi uzerinde isaretleri ve kelimeleri tek tek takip et. Takildigin satiri AI'ye 20-30 satirlik kucuk parcayla sor.",
    )
    doc.add_paragraph("Onerilen sira", style="Heading 2")
    add_numbered(
        doc,
        [
            "pubspec.yaml ile projenin paketlerini tanima.",
            "main.dart ile uygulamanin nasil basladigini ogrenme.",
            "firebase_bootstrap.dart ile Firebase baslatma mantigini anlama.",
            "theme_controller.dart, vibe_snackbar.dart ve tarih_saat.dart gibi kucuk dosyalarla Dart dilini pekistirme.",
            "feed_page.dart ile ana sekme sistemini takip etme.",
            "newpost_page.dart ile bir kullanici aksiyonunun Firestore'a nasil yazildigini gorme.",
            "sosyal_servis.dart ve sosyal_core.dart ile servis katmanini okuma.",
            "robot_servis.dart ile is kurali ve oyun mekanigini cozme.",
            "firestore.rules ile guvenlik mantigini ayri bir katman olarak okuma.",
        ],
    )

    doc.add_paragraph("Kod sembolleri sozlugu", style="Heading 2")
    add_key_value_table(
        doc,
        [
            (";", "Dart'ta cumle sonudur. Cogu kod satiri noktalı virgulle biter."),
            (".", "Bir nesnenin icindeki ozellige veya metoda erisir. FirebaseAuth.instance.currentUser gibi."),
            ("()", "Fonksiyon veya constructor cagrisi yapar. runApp(...) gibi."),
            ("{}", "Kod blogu, class govdesi veya named argument grubu olabilir; bulundugu yere gore okunur."),
            ("[]", "Liste veya koleksiyon erisimi icin kullanilir. data['puan'] gibi map erisimi de olabilir."),
            ("<>", "Generic tip belirtir. Future<Widget> gelecekte Widget donecek demektir."),
            ("?", "Null olabilir anlamina gelir. String? degeri bazen bos olabilir."),
            ("!", "Null degil varsayimi yapar. Dikkatli okunmasi gerekir."),
            ("=>", "Tek satirlik fonksiyon govdesidir; soldaki fonksiyon sagdaki ifadeyi dondurur."),
            ("async", "Fonksiyon icinde await kullanilabilecegini ve Future donecegini gosterir."),
            ("await", "Asenkron islemin bitmesini bekler."),
            ("final", "Degisken bir kez atanir, sonra degismez."),
            ("const", "Derleme zamaninda sabit deger veya sabit widget olusturur."),
            ("required", "Named argument'in zorunlu oldugunu soyler."),
            ("override", "Ust siniftan gelen metodu burada yeniden yaziyoruz demektir."),
        ],
    )

    doc.add_paragraph("Buyuk dosyalara girmeden once", style="Heading 2")
    add_bullets(
        doc,
        [
            "profile_page.dart, messages_page.dart ve user_profile_page.dart dosyalarini en sona birak.",
            "Her okumada sadece 20-30 satir al. Daha fazlasi yeni baslayan icin gereksiz yuk olur.",
            "Bir fonksiyonu okurken once girislerini, sonra kontrolleri, sonra Firebase yazmalarini, en sonda UI mesajlarini ayir.",
            "Anlamadigin sembol icin once bu sayfadaki sozluge bak; sonra ayni sembolun baska dosyada nasil kullanildigini ara.",
        ],
    )


def add_big_files_map(doc: Document) -> None:
    doc.add_paragraph("Büyük dosyalar icin okuma haritasi", style="Heading 1")
    add_callout(
        doc,
        "Neden bu bolum var?",
        "Projede bazi dosyalar cok uzun. Bu dosyalari satir satir okumadan once hangi parcaya ne zaman bakacagini bilmek gerekir.",
    )
    rows = [
        ("profile_page.dart", "Kendi profil ekranin. Ayarlar, hesap silme, robot ismi, profil duzenleme ve kullanici gonderileri burada. En sona birak."),
        ("messages_page.dart", "Sohbet listesi ve birebir mesajlasma. StreamBuilder, local okundu bilgisi ve Firestore chat yapisini ogrendikten sonra oku."),
        ("user_profile_page.dart", "Baska kullanicinin profili. Takip, engel, mesaj ve gizli hesap davranisini anlamak icin takip_servis sonrasinda oku."),
        ("feed/feed_content.dart", "Ana akis sorgulari ve listeleme. Firestore query, pagination ve PostCard yapisini ogrendikten sonra oku."),
        ("notifications_page.dart", "Bildirim listesi ve takip istegi aksiyonlari. BildirimServis ve TakipServis mantigindan sonra oku."),
    ]
    add_key_value_table(doc, rows)

    doc.add_paragraph("AI'ye sorarken kullanacagin hazir kalip", style="Heading 2")
    add_code_prompt = [
        "Ben yazilimi VibeLife projesi uzerinden ogreniyorum.",
        "Asagidaki kodu Dart/Flutter bilmeyen birine anlatir gibi acikla.",
        "Her satirdaki kelimeleri, noktalari, parantezleri, ? ve ! isaretlerini tek tek anlat.",
        "Once kodun genel amacini, sonra satir satir ne yaptigini, sonra da 5 alistirma sorusu ver.",
    ]
    for line in add_code_prompt:
        p = doc.add_paragraph(style="CodeBlock")
        shade_paragraph(p, CODE_BG)
        p.add_run(line)


def add_afterword(doc: Document) -> None:
    doc.add_paragraph("Sonraki cilt onerisi", style="Heading 1")
    doc.add_paragraph(
        "Bu PDF Cilt 1 olarak temel okuma sirani ve ana akislari kurar. Bir sonraki PDF icin en dogru konu Cilt 2: Giriş-Kayıt ve Profil olacaktır. O ciltte login_page.dart, register_page.dart, kayit_servis.dart ve profile_page.dart daha uzun ve satir satir islenebilir."
    )
    doc.add_paragraph(
        "Ucuncu cilt ise Sosyal Sistem olabilir: takip, begeni, yorum, bildirim, mesajlasma ve gizli hesap kurallari birlikte okunur."
    )


def esc(value: str) -> str:
    return html.escape(value, quote=True)


def html_code_block(path: str, start: int, end: int) -> str:
    lines = read_lines(path)
    selected = lines[start - 1:end]
    body = "\n".join(
        f"{line_no:>4} | {line}"
        for line_no, line in enumerate(selected, start=start)
    )
    return f"<pre><code>{esc(body)}</code></pre>"


def html_bullets(items: Iterable[str]) -> str:
    return "<ul>" + "".join(f"<li>{esc(item)}</li>" for item in items) + "</ul>"


def html_numbered(items: Iterable[str]) -> str:
    return "<ol>" + "".join(f"<li>{esc(item)}</li>" for item in items) + "</ol>"


def html_key_value_table(rows: list[tuple[str, str]]) -> str:
    out = [
        "<table>",
        "<thead><tr><th>Kavram</th><th>Bu projede nasil okunur?</th></tr></thead>",
        "<tbody>",
    ]
    for key, val in rows:
        out.append(f"<tr><td><code>{esc(key)}</code></td><td>{esc(val)}</td></tr>")
    out.append("</tbody></table>")
    return "\n".join(out)


def render_intro_html() -> str:
    symbols = [
        (";", "Dart'ta cumle sonudur. Cogu kod satiri noktalı virgulle biter."),
        (".", "Bir nesnenin icindeki ozellige veya metoda erisir. FirebaseAuth.instance.currentUser gibi."),
        ("()", "Fonksiyon veya constructor cagrisi yapar. runApp(...) gibi."),
        ("{}", "Kod blogu, class govdesi veya named argument grubu olabilir; bulundugu yere gore okunur."),
        ("[]", "Liste veya koleksiyon erisimi icin kullanilir. data['puan'] gibi map erisimi de olabilir."),
        ("<>", "Generic tip belirtir. Future<Widget> gelecekte Widget donecek demektir."),
        ("?", "Null olabilir anlamina gelir. String? degeri bazen bos olabilir."),
        ("!", "Null degil varsayimi yapar. Dikkatli okunmasi gerekir."),
        ("=>", "Tek satirlik fonksiyon govdesidir; soldaki fonksiyon sagdaki ifadeyi dondurur."),
        ("async", "Fonksiyon icinde await kullanilabilecegini ve Future donecegini gosterir."),
        ("await", "Asenkron islemin bitmesini bekler."),
        ("final", "Degisken bir kez atanir, sonra degismez."),
        ("const", "Derleme zamaninda sabit deger veya sabit widget olusturur."),
        ("required", "Named argument'in zorunlu oldugunu soyler."),
        ("override", "Ust siniftan gelen metodu burada yeniden yaziyoruz demektir."),
    ]
    order = [
        "pubspec.yaml ile projenin paketlerini tanima.",
        "main.dart ile uygulamanin nasil basladigini ogrenme.",
        "firebase_bootstrap.dart ile Firebase baslatma mantigini anlama.",
        "theme_controller.dart, vibe_snackbar.dart ve tarih_saat.dart gibi kucuk dosyalarla Dart dilini pekistirme.",
        "feed_page.dart ile ana sekme sistemini takip etme.",
        "newpost_page.dart ile bir kullanici aksiyonunun Firestore'a nasil yazildigini gorme.",
        "sosyal_servis.dart ve sosyal_core.dart ile servis katmanini okuma.",
        "robot_servis.dart ile is kurali ve oyun mekanigini cozme.",
        "firestore.rules ile guvenlik mantigini ayri bir katman olarak okuma.",
    ]
    before_big = [
        "profile_page.dart, messages_page.dart ve user_profile_page.dart dosyalarini en sona birak.",
        "Her okumada sadece 20-30 satir al. Daha fazlasi yeni baslayan icin gereksiz yuk olur.",
        "Bir fonksiyonu okurken once girislerini, sonra kontrolleri, sonra Firebase yazmalarini, en sonda UI mesajlarini ayir.",
        "Anlamadigin sembol icin once bu sayfadaki sozluge bak; sonra ayni sembolun baska dosyada nasil kullanildigini ara.",
    ]
    return f"""
    <section>
      <h1>Bu kitabi nasil calisacaksin?</h1>
      <div class="callout"><strong>Calisma mantigi</strong><br>
      Kodlari roman gibi bastan sona okumaya calisma. Her bolumde once amaci oku, sonra kod parcasi uzerinde isaretleri ve kelimeleri tek tek takip et. Takildigin satiri AI'ye 20-30 satirlik kucuk parcayla sor.</div>
      <h2>Onerilen sira</h2>
      {html_numbered(order)}
      <h2>Kod sembolleri sozlugu</h2>
      {html_key_value_table(symbols)}
      <h2>Buyuk dosyalara girmeden once</h2>
      {html_bullets(before_big)}
    </section>
    """


def render_chapter_html(index: int, chapter: Chapter) -> str:
    parts = [
        f'<section class="chapter" id="ch-{index}">',
        f"<h1>{index}. {esc(chapter.title)}</h1>",
        f'<div class="callout"><strong>Bu bolumun amaci</strong><br>{esc(chapter.why)}</div>',
        "<h2>Bu bolumde sunlari ogren</h2>",
        html_bullets(chapter.goals),
    ]
    for snippet in chapter.snippets:
        parts.append(
            f"<h3>{esc(snippet.title)} <span>{esc(snippet.path)}:{snippet.start}-{snippet.end}</span></h3>"
        )
        parts.append(f"<p>{esc(snippet.note)}</p>")
        parts.append(html_code_block(snippet.path, snippet.start, snippet.end))
    if chapter.explanations:
        parts.append("<h2>Kod okurken dikkat et</h2>")
        for key, value in chapter.explanations:
            parts.append(f'<p class="explain"><strong>{esc(key)}:</strong> {esc(value)}</p>')
    if chapter.exercises:
        parts.append("<h2>Mini alistirma</h2>")
        parts.append(html_numbered(chapter.exercises))
    parts.append("</section>")
    return "\n".join(parts)


def render_big_files_html() -> str:
    rows = [
        ("profile_page.dart", "Kendi profil ekranin. Ayarlar, hesap silme, robot ismi, profil duzenleme ve kullanici gonderileri burada. En sona birak."),
        ("messages_page.dart", "Sohbet listesi ve birebir mesajlasma. StreamBuilder, local okundu bilgisi ve Firestore chat yapisini ogrendikten sonra oku."),
        ("user_profile_page.dart", "Baska kullanicinin profili. Takip, engel, mesaj ve gizli hesap davranisini anlamak icin takip_servis sonrasinda oku."),
        ("feed/feed_content.dart", "Ana akis sorgulari ve listeleme. Firestore query, pagination ve PostCard yapisini ogrendikten sonra oku."),
        ("notifications_page.dart", "Bildirim listesi ve takip istegi aksiyonlari. BildirimServis ve TakipServis mantigindan sonra oku."),
    ]
    prompt = "\n".join(
        [
            "Ben yazilimi VibeLife projesi uzerinden ogreniyorum.",
            "Asagidaki kodu Dart/Flutter bilmeyen birine anlatir gibi acikla.",
            "Her satirdaki kelimeleri, noktalari, parantezleri, ? ve ! isaretlerini tek tek anlat.",
            "Once kodun genel amacini, sonra satir satir ne yaptigini, sonra da 5 alistirma sorusu ver.",
        ]
    )
    return f"""
    <section>
      <h1>Büyük dosyalar icin okuma haritasi</h1>
      <div class="callout"><strong>Neden bu bolum var?</strong><br>
      Projede bazi dosyalar cok uzun. Bu dosyalari satir satir okumadan once hangi parcaya ne zaman bakacagini bilmek gerekir.</div>
      {html_key_value_table(rows)}
      <h2>AI'ye sorarken kullanacagin hazir kalip</h2>
      <pre><code>{esc(prompt)}</code></pre>
      <h1>Sonraki cilt onerisi</h1>
      <p>Bu PDF Cilt 1 olarak temel okuma sirani ve ana akislari kurar. Bir sonraki PDF icin en dogru konu Cilt 2: Giris-Kayit ve Profil olacaktir. O ciltte login_page.dart, register_page.dart, kayit_servis.dart ve profile_page.dart daha uzun ve satir satir islenebilir.</p>
      <p>Ucuncu cilt ise Sosyal Sistem olabilir: takip, begeni, yorum, bildirim, mesajlasma ve gizli hesap kurallari birlikte okunur.</p>
    </section>
    """


def build_html() -> None:
    ch = chapters()
    toc = "\n".join(
        f'<li><a href="#ch-{i}">{esc(chapter.title)}</a></li>'
        for i, chapter in enumerate(ch, start=1)
    )
    body = [
        """
        <section class="cover">
          <h1>VibeLife Ders Kitabi</h1>
          <p class="subtitle">Cilt 1: Kod okuma sirasi, temel dosyalar ve calisma yontemi</p>
          <p>Flutter + Dart + Firebase uygulamasini kendi kodlari uzerinden ogrenme rehberi</p>
          <p class="date">Olusturulma tarihi: {today}</p>
        </section>
        """.format(today=date.today().strftime("%d.%m.%Y")),
        f"<section class='toc'><h1>Icindekiler</h1><ol>{toc}<li>Buyuk dosyalar icin okuma haritasi</li></ol></section>",
        render_intro_html(),
    ]
    body.extend(render_chapter_html(i, chapter) for i, chapter in enumerate(ch, start=1))
    body.append(render_big_files_html())
    css = """
    @page { size: Letter; margin: 0.72in 0.72in 0.78in 0.72in; }
    * { box-sizing: border-box; }
    body { font-family: Calibri, Arial, sans-serif; color: #191919; font-size: 11pt; line-height: 1.34; margin: 0; }
    section { break-after: auto; margin-bottom: 18px; }
    .cover { min-height: 9.2in; display: flex; flex-direction: column; justify-content: center; align-items: center; text-align: center; break-after: page; }
    .cover h1 { font-size: 32pt; color: #000; margin: 0 0 10px; }
    .cover .subtitle { font-size: 15pt; color: #555; margin: 0 0 18px; }
    .cover .date { margin-top: 70px; color: #666; }
    .toc { break-after: page; }
    h1 { color: #2E74B5; font-size: 18pt; margin: 22px 0 10px; break-after: avoid; }
    h2 { color: #2E74B5; font-size: 13.5pt; margin: 18px 0 7px; break-after: avoid; }
    h3 { color: #1F4D78; font-size: 11.5pt; margin: 15px 0 5px; break-after: avoid; }
    h3 span { color: #666; font-size: 9.5pt; font-weight: normal; }
    p { margin: 0 0 7px; }
    ul, ol { margin-top: 4px; margin-bottom: 10px; padding-left: 25px; }
    li { margin: 0 0 4px; }
    a { color: #2E74B5; text-decoration: none; }
    .callout { background: #E8EEF5; border-left: 4px solid #2E74B5; padding: 9px 11px; margin: 8px 0 12px; break-inside: avoid; }
    .explain { margin-bottom: 5px; }
    table { border-collapse: collapse; width: 100%; margin: 8px 0 12px; break-inside: avoid; }
    th, td { border: 1px solid #C9D3DF; padding: 7px 8px; vertical-align: top; }
    th { background: #F2F4F7; color: #1F4D78; text-align: left; }
    code { font-family: Consolas, 'Courier New', monospace; font-size: 8.2pt; }
    pre { background: #F4F6F9; border: 1px solid #D9E2F3; padding: 8px 9px; margin: 6px 0 12px; white-space: pre-wrap; overflow-wrap: anywhere; break-inside: auto; line-height: 1.16; }
    pre code { font-size: 7.3pt; }
    .chapter { break-before: page; }
    """
    html_text = f"<!doctype html><html lang='tr'><head><meta charset='utf-8'><title>VibeLife Ders Kitabi Cilt 1</title><style>{css}</style></head><body>{''.join(body)}</body></html>"
    HTML_OUT.write_text(html_text, encoding="utf-8")


def edge_path() -> Path | None:
    candidates = [
        Path(r"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"),
        Path(r"C:\Program Files\Microsoft\Edge\Application\msedge.exe"),
    ]
    for candidate in candidates:
        if candidate.exists():
            return candidate
    return None


def html_to_pdf() -> bool:
    edge = edge_path()
    if edge is None:
        return False
    if PDF_OUT.exists():
        PDF_OUT.unlink()
    cmd = [
        str(edge),
        "--headless",
        "--disable-gpu",
        "--no-pdf-header-footer",
        f"--print-to-pdf={PDF_OUT.resolve()}",
        HTML_OUT.resolve().as_uri(),
    ]
    subprocess.run(cmd, check=True, capture_output=True, timeout=120)
    return PDF_OUT.exists() and PDF_OUT.stat().st_size > 0


def build() -> None:
    DOCS.mkdir(parents=True, exist_ok=True)
    doc = Document()
    configure_document(doc)
    add_title_page(doc)
    add_intro(doc)
    for i, chapter in enumerate(chapters(), start=1):
        add_chapter(doc, i, chapter)
        if i in {2, 5, 7}:
            doc.add_page_break()
    add_big_files_map(doc)
    add_afterword(doc)
    doc.save(DOCX_OUT)
    build_html()
    pdf_ok = html_to_pdf()
    print(DOCX_OUT)
    print(HTML_OUT)
    if pdf_ok:
        print(PDF_OUT)
    else:
        print("PDF olusturulamadi: Microsoft Edge bulunamadi.")


if __name__ == "__main__":
    build()
