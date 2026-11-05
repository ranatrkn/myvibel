// yasal_icerik.dart → hosting/public privacy|kvkk|terms.html
const fs = require('fs');
const path = require('path');

const src = fs.readFileSync(path.join(__dirname, '../lib/yasal_icerik.dart'), 'utf8');

function dartConst(name) {
  const m = src.match(new RegExp(`static const ${name} = '''([\\s\\S]*?)'''`));
  if (!m) throw new Error('missing ' + name);
  let t = m[1];
  const surum = src.match(/static const surum = '([^']+)'/)[1];
  const tarih = src.match(/static const guncellemeTarihi = '([^']+)'/)[1];
  const app = src.match(/static const uygulamaAdi = '([^']+)'/)[1];
  const vs = src.match(/static const veriSorumlusu = '([^']+)'/)[1];
  return t
    .replaceAll('$surum', surum)
    .replaceAll('$guncellemeTarihi', tarih)
    .replaceAll('$uygulamaAdi', app)
    .replaceAll('$veriSorumlusu', vs)
    .replace(/^\n/, '')
    .replace(/\n$/, '');
}

function esc(s) {
  return s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
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
  <div class="content">${esc(opts.content)}</div>
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

const surum = src.match(/static const surum = '([^']+)'/)[1];
const tarih = src.match(/static const guncellemeTarihi = '([^']+)'/)[1];
const giz = dartConst('gizlilikMetni');
const kvkk = dartConst('kvkkMetni');
const terms = dartConst('kullanimKosullariMetni');

write('privacy.html', {
  title: 'MyVibel Gizlilik Politikası',
  h1: 'MyVibel Gizlilik Politikası',
  meta: `Son güncelleme: ${tarih} · Sürüm ${surum}`,
  content: giz,
  topLinks:
    '<a href="/kvkk.html">KVKK</a>\n      <a href="/terms.html">Koşullar</a>\n      <a href="/cocuk-guvenligi.html">Çocuk güvenliği</a>',
  footer:
    '<a href="kvkk.html">KVKK Aydınlatma Metni</a> · <a href="terms.html">Kullanım Koşulları</a> · <a href="cocuk-guvenligi.html">Çocuk güvenliği</a>',
});

write('kvkk.html', {
  title: 'MyVibel KVKK Aydınlatma Metni',
  h1: 'KVKK Aydınlatma Metni',
  meta: `6698 sayılı Kişisel Verilerin Korunması Kanunu · Son güncelleme: ${tarih} · Sürüm ${surum}`,
  content: kvkk,
  topLinks:
    '<a href="/privacy.html">Gizlilik</a>\n      <a href="/terms.html">Koşullar</a>\n      <a href="/cocuk-guvenligi.html">Çocuk güvenliği</a>',
  footer:
    '<a href="privacy.html">Gizlilik Politikası</a> · <a href="terms.html">Kullanım Koşulları</a> · <a href="cocuk-guvenligi.html">Çocuk güvenliği</a>',
});

write('terms.html', {
  title: 'MyVibel Kullanım Koşulları',
  h1: 'Kullanım Koşulları',
  meta: `Son güncelleme: ${tarih} · Sürüm ${surum}`,
  content: terms,
  topLinks:
    '<a href="/privacy.html">Gizlilik</a>\n      <a href="/kvkk.html">KVKK</a>\n      <a href="/cocuk-guvenligi.html">Çocuk güvenliği</a>',
  footer:
    '<a href="privacy.html">Gizlilik Politikası</a> · <a href="kvkk.html">KVKK Aydınlatma Metni</a> · <a href="cocuk-guvenligi.html">Çocuk güvenliği</a>',
});

const cocuk = dartConst('cocukGuvenligiMetni');
write('cocuk-guvenligi.html', {
  title: 'MyVibel Çocuk güvenliği',
  h1: 'Çocuklara özgü hizmet ve yaş tedbirleri',
  meta: `Son güncelleme: ${tarih} · Sürüm ${surum}`,
  content: cocuk,
  topLinks:
    '<a href="/privacy.html">Gizlilik</a>\n      <a href="/kvkk.html">KVKK</a>\n      <a href="/terms.html">Koşullar</a>',
  footer:
    '<a href="privacy.html">Gizlilik Politikası</a> · <a href="kvkk.html">KVKK Aydınlatma Metni</a> · <a href="terms.html">Kullanım Koşulları</a>',
});
