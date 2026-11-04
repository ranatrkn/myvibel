# MyVibel Flutter web derlemesi + yasal sayfalar + Firebase Hosting.
param(
  [switch]$SkipBuild
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
Set-Location $root

$webRoot = Join-Path $root 'build\web'
$appDir  = Join-Path $webRoot 'app'
$staging = Join-Path $root 'build\web-staging'

if (-not $SkipBuild) {
  Write-Host 'Flutter web derleniyor (/app/)...'
  # Onceki hosting layout kalintisi flutter ciktisini ic ice sokmasin.
  if (Test-Path $webRoot) {
    Remove-Item $webRoot -Recurse -Force
  }
  flutter build web --release --base-href=/app/
}

if (-not (Test-Path $webRoot)) {
  throw "build/web bulunamadi. Once flutter build web calistir."
}

# Flutter ciktisi kokte main.dart.js; hosting layout'ta app/main.dart.js olur.
$flutterRootJs = Join-Path $webRoot 'main.dart.js'
$alreadyHosted = Test-Path (Join-Path $appDir 'main.dart.js')

if (-not (Test-Path $flutterRootJs) -and $alreadyHosted) {
  Write-Host 'build/web zaten hosting duzeninde; yasal sayfalar guncellenecek.'
} else {
  if (-not (Test-Path $flutterRootJs)) {
    throw "Flutter ciktisi bulunamadi (build/web/main.dart.js yok)."
  }

  if (Test-Path $staging) {
    Remove-Item $staging -Recurse -Force
  }
  # Onceki deploy'dan kalan app/ (eski derleme) yeni ciktinin icine tasinmasin;
  # yoksa asagidaki app/app duzeltmesi eski derlemeyi yayinlar.
  if (Test-Path $appDir) {
    Remove-Item $appDir -Recurse -Force
  }
  Move-Item $webRoot $staging -Force

  New-Item -ItemType Directory -Path $webRoot -Force | Out-Null
  New-Item -ItemType Directory -Path $appDir -Force | Out-Null
  Move-Item (Join-Path $staging '*') $appDir -Force
  Remove-Item $staging -Recurse -Force
}

# Ic ice app/app temizligi (eski hatali deploy)
while (Test-Path (Join-Path $appDir 'app\main.dart.js')) {
  Write-Host 'Ic ice app/app duzeltiliyor...'
  $nested = Join-Path $appDir 'app'
  $tmp = Join-Path $root 'build\web-app-flatten'
  if (Test-Path $tmp) { Remove-Item $tmp -Recurse -Force }
  Move-Item $nested $tmp -Force
  Remove-Item $appDir -Recurse -Force
  Move-Item $tmp $appDir -Force
}

# Kok landing + yasal sayfalar + SEO
Copy-Item (Join-Path $root 'hosting\public\root-index.html') (Join-Path $webRoot 'index.html') -Force
Write-Host 'Kok landing: / (SEO) + CTA /app/'

$seo = @('robots.txt', 'sitemap.xml', 'site-common.css', 'ads.txt', 'favicon.png', 'favicon.ico')
foreach ($file in $seo) {
  $src = Join-Path $root "hosting\public\$file"
  if (-not (Test-Path $src)) {
    throw "SEO/statik dosya bulunamadi: $src"
  }
  Copy-Item $src (Join-Path $webRoot $file) -Force
  Write-Host "Kopyalandi: $file"
}

Get-ChildItem (Join-Path $root 'hosting\public') -Filter 'google*.html' | ForEach-Object {
  Copy-Item $_.FullName (Join-Path $webRoot $_.Name) -Force
  Write-Host "Kopyalandi: $($_.Name)"
}

foreach ($lang in @('tr', 'en')) {
  $langDir = Join-Path $webRoot $lang
  New-Item -ItemType Directory -Path $langDir -Force | Out-Null
  Copy-Item (Join-Path $root "hosting\public\$lang\index.html") (Join-Path $langDir 'index.html') -Force
  Write-Host "Kopyalandi: $lang/index.html"
}

$legal = @('privacy.html', 'kvkk.html', 'terms.html', 'reset-password.html', 'cocuk-guvenligi.html')
foreach ($file in $legal) {
  $src = Join-Path $root "hosting\public\$file"
  if (-not (Test-Path $src)) {
    throw "Yasal dosya bulunamadi: $src"
  }
  Copy-Item $src (Join-Path $webRoot $file) -Force
  Write-Host "Kopyalandi: $file"
}

# index.html cache-bust satirini dogrula
$appIndex = Join-Path $appDir 'index.html'
if (-not (Test-Path $appIndex)) {
  throw "app/index.html yok"
}
if (-not (Select-String -Path $appIndex -Pattern 'entrypointUrl' -Quiet)) {
  Write-Host 'UYARI: app/index.html entrypointUrl icermiyor (web/index.html guncel mi?)'
}

Write-Host 'Firebase Hosting yayinlaniyor...'
firebase deploy --only hosting --project myvibel-app

Write-Host 'Tamam: https://myvibel.com/'
Write-Host 'Uygulama: https://myvibel.com/app/'
