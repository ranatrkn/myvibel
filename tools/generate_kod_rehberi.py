#!/usr/bin/env python3
"""VibeLife lib/ kod rehberi HTML + PDF üretici."""
from __future__ import annotations

import re
import subprocess
import sys
from datetime import date
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
LIB = ROOT / "lib"
DOCS = ROOT / "docs"
HTML_OUT = DOCS / "VibeLife_Kod_Rehberi.html"
PDF_OUT = DOCS / "VibeLife_Kod_Rehberi.pdf"

SKIP = {"firebase_options.dart"}

# Dosya amaçları (Türkçe)
PURPOSES: dict[str, str] = {
    "main.dart": "Uygulama giriş noktası; Firebase, tema ve oturum yönlendirmesi.",
    "app_theme.dart": "Açık/koyu tema renkleri, ThemeExtension ve MaterialApp ThemeData.",
    "theme_controller.dart": "Koyu/açık tema tercihini SharedPreferences ile saklar.",
    "error_messages.dart": "Hataları Türkçe, internet-dostu mesaja çevirir.",
    "vibe_snackbar.dart": "Tipe göre stillendirilmiş floating snackbar.",
    "puan_animasyon.dart": "Puan kazanım/kaybı için overlay animasyonu.",
    "etiket_navigasyon.dart": "Hashtag tıklamasında EtiketSayfasi'na yönlendirir.",
    "utils/tarih_saat.dart": "Firestore Timestamp → gg.aa.yyyy ss:dd metni.",
    "sosyal_servis.dart": "Tüm sosyal alt servislerin tek cephe (facade) sınıfı.",
    "sosyal/sosyal_core.dart": "Ortak Firestore yardımcıları, hız limiti, engel kontrolü.",
    "sosyal/etiket_servis.dart": "Hashtag normalizasyonu, arama, bahsetme çözümleme.",
    "sosyal/takip_servis.dart": "Takip/takipçi, gizli hesap istekleri, liderlik, görünürlük.",
    "sosyal/begeni_yorum_servis.dart": "Beğeni toggle, yorum ekleme, gönderi silme.",
    "sosyal/mesaj_servis.dart": "DM sohbetleri, mesaj gönderme, okundu/gizle/sessiz.",
    "sosyal/engel_servis.dart": "Engelleme, şikayet, kullanıcı adı güncelleme, gizlilik.",
    "sosyal/bildirim_servis.dart": "Bildirim CRUD ve okunmamış sayacı.",
    "robot_servis.dart": "Robot enerji, mutluluk, uyku, seviye ve sosyal etkileşim engeli.",
    "haftalik_gorev_servis.dart": "Günlük/haftalık görev sistemi (TR saati, Firestore).",
    "hesap_sil_servis.dart": "Hesap silme; Firestore + Auth tam temizlik.",
    "feed_page.dart": "Alt menülü ana kabuk (feed, keşfet, yeni, bildirim, profil).",
    "feed/feed_content.dart": "Ana feed; Takip/Keşfet sekmeleri, sonsuz kaydırma.",
    "profile_page.dart": "Kendi profilim; robot, gönderiler, beğeniler, ayarlar.",
    "user_profile_page.dart": "Başka kullanıcının profili; takip, engel, mesaj.",
    "messages_page.dart": "Sohbet listesi ve birebir mesajlaşma ekranı.",
    "notifications_page.dart": "Sosyal bildirimler; takip isteği kabul/red.",
    "login_page.dart": "E-posta/şifre giriş ekranı.",
    "register_page.dart": "Kayıt formu; Auth + users + usernames + robot.",
    "explore_page.dart": "Kullanıcı/etiket arama, öneriler, takip butonları.",
    "newpost_page.dart": "Yeni gönderi paylaşım formu.",
    "robot_page.dart": "Robot odası; geliştir, uyut, uyandır, görev kartı.",
    "leaderboard_page.dart": "Haftalık görev liderlik tablosu.",
    "follow_list_page.dart": "Takipçi / takip edilen sekmeli liste.",
    "etiket_sayfasi.dart": "Belirli hashtag'e ait gönderi listesi.",
    "legal_pages.dart": "Gizlilik, KVKK, SSS, changelog, iletişim sayfaları.",
    "widgets/post_card.dart": "Gönderi kartı; beğeni, yorum, ilet, şikayet, engel.",
    "widgets/yorum_paneli.dart": "Gönderi yorumları bottom sheet.",
    "widgets/hashtag_metin.dart": "#hashtag ve @bahsetme tıklanabilir metin.",
    "widgets/bahsetme_metin_alani.dart": "@ önerili metin alanı.",
    "widgets/bahsetme_yardimci.dart": "@ sorgu parse ve metne ekleme yardımcıları.",
    "widgets/gonderi_ilet_paneli.dart": "Gönderiyi DM ile iletme bottom sheet.",
    "widgets/vibe_avatar.dart": "Emoji avatar seçenekleri ve CircleAvatar.",
    "widgets/vibe_gradient_scaffold.dart": "Gradyan arka planlı ortak Scaffold.",
    "widgets/robot_lottie_view.dart": "Seviye/duruma göre Lottie robot animasyonu.",
    "widgets/robot_durum_bari.dart": "Enerji/mutluluk yüzde çubuğu.",
    "widgets/haftalik_gorev_karti.dart": "Günün görevleri UI kartı.",
    "widgets/theme_mode_segment.dart": "Koyu/açık tema segment kontrolü.",
}


def rel_path(p: Path) -> str:
    return p.relative_to(LIB).as_posix()


def read_file(p: Path) -> str:
    return p.read_text(encoding="utf-8")


def file_header_comment(text: str) -> str | None:
    for line in text.splitlines():
        s = line.strip()
        if s.startswith("//") and not s.startswith("///"):
            return s.lstrip("/ ").strip()
        if s and not s.startswith("import") and not s.startswith("export"):
            break
    return None


def extract_comment_map(text: str) -> dict[str, str]:
    """Kaynak dosyadaki // yorumlarını metot/alan adına eşler."""
    desc: dict[str, str] = {}
    lines = text.splitlines()
    for i, line in enumerate(lines):
        s = line.strip()
        if s.startswith("//") and not s.startswith("///"):
            comment = re.sub(r"^//+\s*", "", s).strip()
            if not comment or len(comment) < 3:
                continue
            for j in range(i + 1, min(i + 5, len(lines))):
                nxt = lines[j].strip()
                if not nxt or nxt.startswith("//"):
                    continue
                m = re.search(
                    r"(?:static\s+)?(?:Future<[^>]+>|Stream<[^>]+>|void|bool|int|String|Widget|\w+)\s+(\w+)\s*[\(<]",
                    nxt,
                )
                if m:
                    desc.setdefault(m.group(1), comment)
                break
        inline = re.search(r"\b(\w+)\s*[=;].*//\s*(.+)$", line)
        if inline:
            desc.setdefault(inline.group(1), inline.group(2).strip())
    return desc


def method_li(name: str, desc_map: dict[str, str]) -> str:
    d = desc_map.get(name, "")
    if d:
        return f"<li><code>{esc(name)}()</code> — {esc(d)}</li>"
    return f"<li><code>{esc(name)}()</code></li>"


def parse_dart(text: str) -> dict:
    enums: list[dict] = []
    classes: list[dict] = []
    top_funcs: list[str] = []
    exports: list[str] = []
    imports: list[str] = []

    for line in text.splitlines():
        s = line.strip()
        if s.startswith("import "):
            m = re.search(r"'([^']+)'", s)
            if m:
                imports.append(m.group(1))
        if s.startswith("export "):
            m = re.search(r"'([^']+)'", s)
            if m:
                exports.append(m.group(1))

    for m in re.finditer(
        r"enum\s+(\w+)\s*\{([^}]*)\}", text, re.DOTALL
    ):
        name = m.group(1)
        body = m.group(2)
        values = [v.strip().split("(")[0].strip() for v in body.split(",") if v.strip()]
        enums.append({"name": name, "values": values})

    class_pattern = re.compile(
        r"(?:^|\n)\s*(?:abstract\s+)?class\s+(\w+)(?:\s+extends|\s+with|\s+implements|\s*\{)",
        re.MULTILINE,
    )
    for m in class_pattern.finditer(text):
        cname = m.group(1)
        start = m.start()
        snippet = text[start : start + 400]
        kind = "class"
        if "StatefulWidget" in snippet:
            kind = "StatefulWidget"
        elif "StatelessWidget" in snippet:
            kind = "StatelessWidget"
        elif "ChangeNotifier" in snippet:
            kind = "ChangeNotifier"
        elif "ThemeExtension" in snippet:
            kind = "ThemeExtension"
        elif "InheritedNotifier" in snippet:
            kind = "InheritedNotifier"

        methods: list[str] = []
        static_methods: list[str] = []
        fields: list[str] = []

        # Sınıf gövdesini kabaca bul
        brace = text.find("{", m.end() - 1)
        if brace == -1:
            classes.append({"name": cname, "kind": kind, "methods": [], "static": [], "fields": []})
            continue
        depth = 0
        end = brace
        for i in range(brace, len(text)):
            if text[i] == "{":
                depth += 1
            elif text[i] == "}":
                depth -= 1
                if depth == 0:
                    end = i
                    break
        body = text[brace + 1 : end]

        for fm in re.finditer(
            r"^\s*(?:static\s+)?(?:Future<[^>]+>|Stream<[^>]+>|void|bool|int|String|List<[^>]+>|Map<[^>]+>|Widget|Set<[^>]+>|\w+)\s+(\w+)\s*\(",
            body,
            re.MULTILINE,
        ):
            fname = fm.group(1)
            line_start = body.rfind("\n", 0, fm.start()) + 1
            line = body[line_start : body.find("\n", fm.start())]
            if "static " in line:
                if fname not in static_methods:
                    static_methods.append(fname)
            else:
                if fname not in methods and not fname.startswith("_") or fname.startswith("_"):
                    if fname not in methods:
                        methods.append(fname)

        for fm in re.finditer(
            r"^\s*(?:static\s+)?(?:final|late final|late|const)\s+[\w<>,\s?]+\s+(\w+)",
            body,
            re.MULTILINE,
        ):
            fields.append(fm.group(1))

        classes.append(
            {
                "name": cname,
                "kind": kind,
                "methods": sorted(set(methods)),
                "static": sorted(set(static_methods)),
                "fields": sorted(set(fields))[:20],
            }
        )

    for m in re.finditer(
        r"^(\w+)\s+(\w+)\s*\([^)]*\)\s*(?:async\s*)?\{",
        text,
        re.MULTILINE,
    ):
        if m.group(1) not in ("class", "enum", "typedef", "extension", "if", "for", "while", "switch"):
            top_funcs.append(m.group(2))

    return {
        "enums": enums,
        "classes": classes,
        "top_funcs": sorted(set(top_funcs)),
        "exports": exports,
        "imports": imports,
        "comments": extract_comment_map(text),
    }


def esc(s: str) -> str:
    return (
        s.replace("&", "&amp;")
        .replace("<", "&lt;")
        .replace(">", "&gt;")
        .replace('"', "&quot;")
    )


def build_html(files: list[Path]) -> str:
    today = date.today().strftime("%d.%m.%Y")
    sections: dict[str, list[Path]] = {
        "Giriş ve Altyapı": [],
        "Sosyal Servis Katmanı": [],
        "Oyun ve Görev Servisleri": [],
        "Ana Navigasyon ve Feed": [],
        "Profil ve Sosyal Sayfalar": [],
        "Kimlik Doğrulama ve Diğer Sayfalar": [],
        "Widget Bileşenleri": [],
    }

    for f in files:
        rel = rel_path(f)
        if rel.startswith("sosyal/") or rel == "sosyal_servis.dart":
            sections["Sosyal Servis Katmanı"].append(f)
        elif rel in ("robot_servis.dart", "haftalik_gorev_servis.dart", "hesap_sil_servis.dart"):
            sections["Oyun ve Görev Servisleri"].append(f)
        elif rel in ("feed_page.dart", "feed/feed_content.dart"):
            sections["Ana Navigasyon ve Feed"].append(f)
        elif rel in ("profile_page.dart", "user_profile_page.dart", "messages_page.dart", "notifications_page.dart"):
            sections["Profil ve Sosyal Sayfalar"].append(f)
        elif rel.startswith("widgets/"):
            sections["Widget Bileşenleri"].append(f)
        elif rel in (
            "main.dart", "app_theme.dart", "theme_controller.dart", "error_messages.dart",
            "vibe_snackbar.dart", "puan_animasyon.dart", "etiket_navigasyon.dart", "utils/tarih_saat.dart",
        ):
            sections["Giriş ve Altyapı"].append(f)
        else:
            sections["Kimlik Doğrulama ve Diğer Sayfalar"].append(f)

    toc = []
    body_parts = []

    body_parts.append(f"""
    <div class="cover">
      <h1>VibeLife Kod Rehberi</h1>
      <p class="subtitle">lib/ klasörü — dosya ve kod envanteri</p>
      <p class="meta">Oluşturulma: {today} · Toplam {len(files)} dosya</p>
    </div>
    """)

    body_parts.append("""
    <div class="section intro">
      <h2>Genel Bakış</h2>
      <p>Bu belge VibeLife Flutter uygulamasının <code>lib/</code> klasöründeki tüm Dart dosyalarını,
      içerdikleri sınıfları, metotları ve işlevlerini açıklar.</p>
      <h3>Mimari Katmanlar</h3>
      <table>
        <tr><th>Katman</th><th>Açıklama</th><th>Dosya örnekleri</th></tr>
        <tr><td>Facade</td><td>UI tek noktadan sosyal API çağırır</td><td>sosyal_servis.dart</td></tr>
        <tr><td>Sosyal modül</td><td>Takip, beğeni, mesaj, engel, etiket</td><td>sosyal/*.dart</td></tr>
        <tr><td>Oyun</td><td>Robot ve günlük görevler</td><td>robot_servis, haftalik_gorev_servis</td></tr>
        <tr><td>Sayfalar</td><td>Ekranlar (StatefulWidget)</td><td>feed_page, profile_page</td></tr>
        <tr><td>Widget</td><td>Yeniden kullanılabilir parçalar</td><td>widgets/*.dart</td></tr>
      </table>
      <h3>Firestore Ana Koleksiyonlar</h3>
      <ul>
        <li><b>users</b> — kullanıcı profili, robot, görev, bildirim alt koleksiyonları</li>
        <li><b>posts</b> — gönderiler; likes, comments alt koleksiyonları</li>
        <li><b>chats</b> — DM sohbetleri ve mesajlar</li>
        <li><b>usernames</b> — kullanıcı adı → uid eşlemesi</li>
        <li><b>reports</b> — şikayet kayıtları</li>
      </ul>
    </div>
    """)

    sec_id = 0
    for sec_name, sec_files in sections.items():
        if not sec_files:
            continue
        sec_id += 1
        sid = f"sec-{sec_id}"
        toc.append(f'<li><a href="#{sid}">{esc(sec_name)}</a><ul>')
        body_parts.append(f'<div class="section" id="{sid}"><h2>{esc(sec_name)}</h2>')

        for f in sorted(sec_files, key=lambda x: rel_path(x)):
            rel = rel_path(f)
            text = read_file(f)
            parsed = parse_dart(text)
            fid = rel.replace("/", "-").replace(".", "-")
            toc.append(f'<li><a href="#{fid}">{esc(rel)}</a></li>')

            header = file_header_comment(text)
            purpose = PURPOSES.get(rel, header or "Uygulama bileşeni.")

            body_parts.append(f'<div class="file" id="{fid}">')
            body_parts.append(f'<h3>📄 lib/{esc(rel)}</h3>')
            body_parts.append(f'<p class="purpose"><b>Amaç:</b> {esc(purpose)}</p>')
            if header and header != purpose:
                body_parts.append(f'<p class="note"><b>Dosya yorumu:</b> {esc(header)}</p>')

            if parsed["exports"]:
                body_parts.append("<p><b>Export:</b> " + ", ".join(f"<code>{esc(e)}</code>" for e in parsed["exports"]) + "</p>")

            if parsed["enums"]:
                body_parts.append("<h4>Enum'lar</h4><ul>")
                for e in parsed["enums"]:
                    vals = ", ".join(e["values"])
                    body_parts.append(f'<li><code>{esc(e["name"])}</code> → {esc(vals)}</li>')
                body_parts.append("</ul>")

            if parsed["top_funcs"]:
                cm = parsed["comments"]
                body_parts.append("<h4>Üst seviye fonksiyonlar</h4><ul>")
                for fn in parsed["top_funcs"]:
                    body_parts.append(method_li(fn, cm))
                body_parts.append("</ul>")

            if parsed["classes"]:
                body_parts.append("<h4>Sınıflar</h4>")
                cm = parsed["comments"]
                for c in parsed["classes"]:
                    body_parts.append(f'<div class="class"><p><code>{esc(c["name"])}</code> <span class="badge">{esc(c["kind"])}</span></p>')
                    if c["fields"]:
                        parts = []
                        for x in c["fields"]:
                            d = cm.get(x, "")
                            if d:
                                parts.append(f"<code>{esc(x)}</code> ({esc(d)})")
                            else:
                                parts.append(f"<code>{esc(x)}</code>")
                        body_parts.append("<p><b>Alanlar:</b> " + ", ".join(parts) + "</p>")
                    if c["static"]:
                        body_parts.append("<p><b>Static metotlar:</b></p><ul>")
                        for sm in c["static"]:
                            body_parts.append(method_li(sm, cm))
                        body_parts.append("</ul>")
                    if c["methods"]:
                        show = c["methods"][:40]
                        extra = len(c["methods"]) - 40
                        body_parts.append("<p><b>Metotlar:</b></p><ul>")
                        for mm in show:
                            body_parts.append(method_li(mm, cm))
                        if extra > 0:
                            body_parts.append(f"<li><i>… ve {extra} metot daha</i></li>")
                        body_parts.append("</ul>")
                    body_parts.append("</div>")

            lines = len(text.splitlines())
            body_parts.append(f'<p class="meta-line">Satır sayısı: {lines}</p>')
            body_parts.append("</div>")

        toc.append("</ul></li>")
        body_parts.append("</div>")

    toc_html = "<ol>" + "".join(toc) + "</ol>"

    return f"""<!DOCTYPE html>
<html lang="tr">
<head>
<meta charset="UTF-8"/>
<title>VibeLife Kod Rehberi</title>
<style>
  @page {{ margin: 18mm 15mm; }}
  body {{ font-family: 'Segoe UI', Arial, sans-serif; font-size: 11pt; line-height: 1.45; color: #1a1a1a; max-width: 900px; margin: 0 auto; padding: 20px; }}
  .cover {{ text-align: center; padding: 60px 20px 40px; page-break-after: always; }}
  .cover h1 {{ font-size: 28pt; color: #c62828; margin-bottom: 8px; }}
  .subtitle {{ font-size: 14pt; color: #555; }}
  .meta {{ color: #888; margin-top: 24px; }}
  h2 {{ color: #c62828; border-bottom: 2px solid #ffcdd2; padding-bottom: 6px; margin-top: 32px; page-break-after: avoid; }}
  h3 {{ color: #333; margin-top: 24px; page-break-after: avoid; }}
  h4 {{ color: #555; margin: 12px 0 6px; font-size: 11pt; }}
  .file {{ border: 1px solid #e0e0e0; border-radius: 8px; padding: 14px 16px; margin: 16px 0; page-break-inside: avoid; background: #fafafa; }}
  .purpose {{ background: #fff3e0; padding: 8px 12px; border-radius: 6px; border-left: 4px solid #ff9800; }}
  .note {{ color: #666; font-size: 10pt; }}
  .class {{ margin: 8px 0 8px 12px; padding: 8px; background: #fff; border-radius: 4px; }}
  .badge {{ background: #e3f2fd; color: #1565c0; padding: 2px 8px; border-radius: 10px; font-size: 9pt; }}
  code {{ background: #f5f5f5; padding: 1px 5px; border-radius: 3px; font-size: 10pt; }}
  table {{ border-collapse: collapse; width: 100%; margin: 12px 0; }}
  th, td {{ border: 1px solid #ddd; padding: 8px; text-align: left; }}
  th {{ background: #f5f5f5; }}
  ul {{ margin: 6px 0; padding-left: 22px; }}
  li {{ margin: 3px 0; }}
  .toc {{ page-break-after: always; }}
  .toc ol {{ line-height: 1.8; }}
  .meta-line {{ font-size: 9pt; color: #999; margin-top: 8px; }}
  a {{ color: #c62828; text-decoration: none; }}
</style>
</head>
<body>
<div class="toc">
  <h2>İçindekiler</h2>
  {toc_html}
</div>
{"".join(body_parts)}
</body>
</html>"""


def html_to_pdf(html_path: Path, pdf_path: Path) -> bool:
    edge = Path(r"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe")
    if not edge.exists():
        edge = Path(r"C:\Program Files\Microsoft\Edge\Application\msedge.exe")
    if not edge.exists():
        return False
    url = html_path.resolve().as_uri()
    cmd = [
        str(edge),
        "--headless",
        "--disable-gpu",
        "--no-pdf-header-footer",
        f"--print-to-pdf={pdf_path.resolve()}",
        url,
    ]
    subprocess.run(cmd, check=True, capture_output=True, timeout=60)
    return pdf_path.exists()


def main() -> int:
    DOCS.mkdir(parents=True, exist_ok=True)
    files = sorted(
        p for p in LIB.rglob("*.dart") if p.name not in SKIP
    )
    html = build_html(files)
    HTML_OUT.write_text(html, encoding="utf-8")
    print(f"HTML: {HTML_OUT}")

    if html_to_pdf(HTML_OUT, PDF_OUT):
        print(f"PDF:  {PDF_OUT}")
    else:
        print("PDF oluşturulamadı. HTML dosyasını tarayıcıdan yazdır → PDF olarak kaydet.", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
