// yasal_icerik.dart → hosting/public privacy|kvkk|terms|cocuk-guvenligi.html
const fs = require('fs');
const path = require('path');

const src = fs.readFileSync(path.join(__dirname, '../lib/yasal_icerik.dart'), 'utf8');

const surum = src.match(/static const surum = '([^']+)'/)[1];
const tarih = src.match(/static const guncellemeTarihi = '([^']+)'/)[1];
const app = src.match(/static const uygulamaAdi = '([^']+)'/)[1];
const vs = src.match(/static const veriSorumlusu = '([^']+)'/)[1];
const vsAdi = src.match(/static const veriSorumlusuAdi = '([^']+)'/)[1];
const ozetNotu = src.match(/static const ozetNotu =\s*'([^']+)'/)[1];

function degiskenleriDoldur(t) {
  return t
    .replaceAll('$surum', surum)
    .replaceAll('$guncellemeTarihi', tarih)
    .replaceAll('$uygulamaAdi', app)
    .replaceAll('$veriSorumlusuAdi', vsAdi)
    .replaceAll('$veriSorumlusu', vs);
}

function dartConst(name) {
  const m = src.match(new RegExp(`static const ${name} = '''([\\s\\S]*?)'''`));
  if (!m) throw new Error('missing ' + name);
  return degiskenleriDoldur(m[1]).replace(/^\n/, '').replace(/\n$/, '');
}

function dartListe(name) {
  const m = src.match(new RegExp(`static const ${name} = <String>\\[([\\s\\S]*?)\\];`));
  if (!m) throw new Error('missing ' + name);
  return [...m[1].matchAll(/'([^']*)'/g)].map((x) => degiskenleriDoldur(x[1]));
}

function esc(s) {
  return s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
}

function baglantila(s) {
  return esc(s)
    .replace(/https:\/\/myvibel\.com\/[\w./-]*[\w/]/g, (u) => `<a href="${u}">${u}</a>`)
    .replace(/destek@myvibel\.com/g, '<a href="mailto:destek@myvibel.com">destek@myvibel.com</a>');
}

// Düz metni başlık, paragraf ve madde listesine çevirir.
function yapilandir(metin) {
  const out = [];
  let liste = null;
  const listeyiKapat = () => {
    if (liste) out.push(`<ul>\n${liste.join('\n')}\n</ul>`);
    liste = null;
  };
  for (const satir of metin.split('\n')) {
    const t = satir.trim();
    if (!t) { listeyiKapat(); continue; }
    if (t.startsWith('• ')) {
      (liste ??= []).push(`<li>${baglantila(t.slice(2))}</li>`);
      continue;
    }
    listeyiKapat();
    const alt = t.match(/^(\d+\.\d+)\. (.{1,80})$/);
    const ana = t.match(/^(\d+)\. (.{1,80})$/);
    if (alt && !alt[2].endsWith('.')) out.push(`<h3>${esc(t)}</h3>`);
    else if (ana && !ana[2].endsWith('.')) out.push(`<h2>${esc(t)}</h2>`);
    else out.push(`<p>${baglantila(t)}</p>`);
  }
  listeyiKapat();
  return out.join('\n');
}

function ozetKutusu(maddeler) {
  return `<section class="ozet" aria-label="Kısaca">
  <h2>Kısaca</h2>
  <ul>
${maddeler.map((m) => `    <li>${baglantila(m)}</li>`).join('\n')}
  </ul>
  <p class="ozet-not">${esc(ozetNotu)}</p>
  </section>`;
}

function write(file, opts) {
  const html = `<!DOCTYPE html>
<html lang="tr">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>${opts.title}</title>
  <link rel="stylesheet" href="/site-common.css">
  <link rel="icon" type="image/png" href="/app/favicon.png">
</head>
<body>
  <header class="site-top">
    <a href="/">MyVibel</a>
    <div class="links">
      <a href="/app/">Uygulama</a>
      ${opts.topLinks}
    </div>
  </header>
  <div class="wrap">
  <h1>${opts.h1}</h1>
  <p class="meta">${opts.meta}</p>
  ${ozetKutusu(opts.ozet)}
  <div class="belge">
${yapilandir(opts.content)}
  </div>
  <nav>
    ${opts.footer}
  </nav>
  </div>
</body>
</html>
`;
  fs.writeFileSync(path.join(__dirname, '../hosting/public', file), html, 'utf8');
  console.log('wrote', file);
}

write('privacy.html', {
  title: 'MyVibel Gizlilik Politikası',
  h1: 'MyVibel Gizlilik Politikası',
  meta: `Son güncelleme: ${tarih} · Sürüm ${surum}`,
  ozet: dartListe('gizlilikOzet'),
  content: dartConst('gizlilikMetni'),
  topLinks:
    '<a href="/kvkk.html">KVKK</a>\n      <a href="/terms.html">Koşullar</a>\n      <a href="/cocuk-guvenligi.html">Çocuk güvenliği</a>',
  footer:
    '<a href="kvkk.html">KVKK Aydınlatma Metni</a> · <a href="terms.html">Kullanım Koşulları</a> · <a href="cocuk-guvenligi.html">Çocuk güvenliği</a>',
});

write('kvkk.html', {
  title: 'MyVibel KVKK Aydınlatma Metni',
  h1: 'KVKK Aydınlatma Metni',
  meta: `6698 sayılı Kişisel Verilerin Korunması Kanunu · Son güncelleme: ${tarih} · Sürüm ${surum}`,
  ozet: dartListe('kvkkOzet'),
  content: dartConst('kvkkMetni'),
  topLinks:
    '<a href="/privacy.html">Gizlilik</a>\n      <a href="/terms.html">Koşullar</a>\n      <a href="/cocuk-guvenligi.html">Çocuk güvenliği</a>',
  footer:
    '<a href="privacy.html">Gizlilik Politikası</a> · <a href="terms.html">Kullanım Koşulları</a> · <a href="cocuk-guvenligi.html">Çocuk güvenliği</a>',
});

write('terms.html', {
  title: 'MyVibel Kullanım Koşulları',
  h1: 'Kullanım Koşulları',
  meta: `Son güncelleme: ${tarih} · Sürüm ${surum}`,
  ozet: dartListe('kosullarOzet'),
  content: dartConst('kullanimKosullariMetni'),
  topLinks:
    '<a href="/privacy.html">Gizlilik</a>\n      <a href="/kvkk.html">KVKK</a>\n      <a href="/cocuk-guvenligi.html">Çocuk güvenliği</a>',
  footer:
    '<a href="privacy.html">Gizlilik Politikası</a> · <a href="kvkk.html">KVKK Aydınlatma Metni</a> · <a href="cocuk-guvenligi.html">Çocuk güvenliği</a>',
});

write('cocuk-guvenligi.html', {
  title: 'MyVibel Çocuk güvenliği',
  h1: 'Çocuklara özgü hizmet ve yaş tedbirleri',
  meta: `Son güncelleme: ${tarih} · Sürüm ${surum}`,
  ozet: dartListe('cocukOzet'),
  content: dartConst('cocukGuvenligiMetni'),
  topLinks:
    '<a href="/privacy.html">Gizlilik</a>\n      <a href="/kvkk.html">KVKK</a>\n      <a href="/terms.html">Koşullar</a>',
  footer:
    '<a href="privacy.html">Gizlilik Politikası</a> · <a href="kvkk.html">KVKK Aydınlatma Metni</a> · <a href="terms.html">Kullanım Koşulları</a>',
});
