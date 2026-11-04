# Google kayit dongusu - adb UI test
# powershell -ExecutionPolicy Bypass -File maestro\google-kayit-dongu.ps1
param(
    [string]$Device = "VG55GULZ7LQSIV6T",
    [string]$GoogleEmail = "s96695632@gmail.com",
    # adb input text ! karakterini bozar; sadece alfanumerik kullan
    [string]$Sifre = "TestSila26a"
)

$ErrorActionPreference = "Continue"
$Root = Split-Path -Parent $PSScriptRoot
Set-Location $Root
$KullaniciAdi = "sla" + (Get-Random -Minimum 1000 -Maximum 9999)
$AdSoyad = "SilaTest"
$Log = New-Object System.Collections.Generic.List[string]
function L([string]$m) { $Log.Add($m) | Out-Null; Write-Host $m }

function Dump-Ui {
    $tmp = Join-Path $env:TEMP "mv_ui.xml"
    cmd /c "adb -s $Device shell uiautomator dump /sdcard/mv_ui.xml >nul 2>&1"
    cmd /c "adb -s $Device pull /sdcard/mv_ui.xml `"$tmp`" >nul 2>&1"
    if (-not (Test-Path $tmp)) { return "" }
    return [System.IO.File]::ReadAllText($tmp)
}

function Find-Center([string]$xml, [string]$needle) {
    if ([string]::IsNullOrEmpty($xml)) { return $null }
    $esc = [regex]::Escape($needle)
    foreach ($rx in @(
        ('content-desc="([^"]*' + $esc + '[^"]*)"[^>]*bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"'),
        ('text="([^"]*' + $esc + '[^"]*)"[^>]*bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"'),
        ('bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"[^>]*(?:content-desc|text)="([^"]*' + $esc + '[^"]*)"')
    )) {
        $m = [regex]::Match($xml, $rx, 'IgnoreCase')
        if ($m.Success) {
            if ($rx.StartsWith('bounds')) {
                return @{ x = [int](([int]$m.Groups[1].Value+[int]$m.Groups[3].Value)/2); y = [int](([int]$m.Groups[2].Value+[int]$m.Groups[4].Value)/2); label = $m.Groups[5].Value }
            }
            return @{ x = [int](([int]$m.Groups[2].Value+[int]$m.Groups[4].Value)/2); y = [int](([int]$m.Groups[3].Value+[int]$m.Groups[5].Value)/2); label = $m.Groups[1].Value }
        }
    }
    return $null
}

# Exact attribute match — avoids tapping "İstersen atla." when looking for "Atla"
function Find-Exact([string]$xml, [string]$exact) {
    if ([string]::IsNullOrEmpty($xml)) { return $null }
    $esc = [regex]::Escape($exact)
    foreach ($rx in @(
        ('(?:content-desc|text)="' + $esc + '"[^>]*bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"'),
        ('bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"[^>]*(?:content-desc|text)="' + $esc + '"')
    )) {
        $m = [regex]::Match($xml, $rx)
        if ($m.Success) {
            return @{
                x = [int](([int]$m.Groups[1].Value + [int]$m.Groups[3].Value) / 2)
                y = [int](([int]$m.Groups[2].Value + [int]$m.Groups[4].Value) / 2)
                label = $exact
            }
        }
    }
    return $null
}

function Tap([int]$x,[int]$y) { cmd /c "adb -s $Device shell input tap $x $y >nul 2>&1" }
function TapN([string]$n,[int]$tries=8) {
    for ($i=0;$i -lt $tries;$i++) {
        $b = Find-Center (Dump-Ui) $n
        if ($b) { L ("TAP " + $b.label + " @" + $b.x + "," + $b.y); Tap $b.x $b.y; return $true }
        Start-Sleep -Seconds 1
    }
    return $false
}
function TapExact([string]$exact,[int]$tries=8) {
    for ($i=0;$i -lt $tries;$i++) {
        $b = Find-Exact (Dump-Ui) $exact
        if ($b) { L ("TAPExact " + $b.label + " @" + $b.x + "," + $b.y); Tap $b.x $b.y; return $true }
        Start-Sleep -Seconds 1
    }
    return $false
}
function Has([string]$n) { return (Dump-Ui).ToLowerInvariant().Contains($n.ToLowerInvariant()) }
function HasExact([string]$exact) {
    $xml = Dump-Ui
    return $null -ne (Find-Exact $xml $exact)
}
function WaitN([string]$n,[int]$sec=25) {
    $end = (Get-Date).AddSeconds($sec)
    while ((Get-Date) -lt $end) { if (Has $n) { return $true }; Start-Sleep -Seconds 1 }
    return $false
}
function EnsureAppForeground {
    $fg = cmd /c "adb -s $Device shell dumpsys window 2>nul | findstr mCurrentFocus"
    if ([string]::IsNullOrWhiteSpace($fg)) { return }
    if ($fg -notmatch 'com\.myvibel\.app') {
        # Sadece onek plana al — activity'yi yeniden yaratma (form state kaybolmasin)
        L "WARN app foreground disi; onek plana"
        cmd /c "adb -s $Device shell monkey -p com.myvibel.app -c android.intent.category.LAUNCHER 1 >nul 2>&1"
        Start-Sleep 2
    }
}
function Screen {
    EnsureAppForeground
    $xml = Dump-Ui
    if ($xml -match 'Profilini tamamla') { return 'profil' }
    if ($xml -match 'ifre belirle' -or $xml -match 'Sifre belirle' -or $xml -match 'Şifre belirle') { return 'sifre' }
    if ($xml -match 'Alt menü Ana' -or $xml -match 'Alt menü Profil') { return 'feed' }
    if ($xml -match 'Google ile devam et' -or $xml -match 'Giriş Yap') { return 'login' }
    if ($xml -match 'Google ile kayıt') { return 'register' }
    return 'other'
}
function Launch {
    cmd /c "adb -s $Device shell am force-stop com.myvibel.app >nul 2>&1"
    Start-Sleep 1
    cmd /c "adb -s $Device shell monkey -p com.myvibel.app -c android.intent.category.LAUNCHER 1 >nul 2>&1"
    # Splash / AuthGate icin login veya profil beklenir
    $end = (Get-Date).AddSeconds(35)
    while ((Get-Date) -lt $end) {
        $s = Screen
        if ($s -in @('login','register','profil','sifre','feed')) {
            L ("Acilis ekran=" + $s)
            return $s
        }
        Start-Sleep 1
    }
    L ("Acilis TIMEOUT ekran=" + (Screen))
    return (Screen)
}
# $Mode: 'login' (profil/sifre/feed) | 'reauth' (silme Google onayi — dialoga donus)
function PickGoogle([string]$Mode = 'login') {
    L ("Google hesap sec mode=" + $Mode)
    if (-not (TapN $GoogleEmail 15)) {
        if (-not (TapN "s96695632" 8)) {
            # Bazen hesap zaten secili / tek hesap Continue bekler
            $xml = Dump-Ui
            if ($xml -match 'text="Devam"' -or $xml -match 'content-desc="Devam"') {
                [void](TapExact "Devam" 3)
            } elseif ($xml -match 'text="Continue"') {
                [void](TapExact "Continue" 3)
            } else {
                L "FAIL hesap secilemedi"
                return $false
            }
        }
    }
    Start-Sleep 2
    # Sadece Google hesap secici "Devam/Continue" — uygulama DEVAM ET'ye basma
    $xml = Dump-Ui
    if ($xml -match 'Choose an account' -or $xml -match 'Hesap seç' -or $xml -match 'hesabın' -or $xml -match 'Sign in' -or $xml -match 'hesabını') {
        if ($xml -match 'text="Devam"' -or $xml -match 'content-desc="Devam"') { [void](TapExact "Devam" 2) }
        elseif ($xml -match 'text="Continue"') { [void](TapExact "Continue" 2) }
    }
    if (Has "İzin ver") { [void](TapN "İzin ver" 2) }
    if (Has "Allow") { [void](TapN "Allow" 2) }
    # Firebase/Google islenmesini bekle
    $end = (Get-Date).AddSeconds(35)
    while ((Get-Date) -lt $end) {
        $xml2 = Dump-Ui
        $pickerOpen = ($xml2 -match 'Choose an account' -or $xml2 -match 'Hesap seç' -or $xml2 -match 'hesabını seç' -or $xml2 -match 'Sign in to')
        if ($Mode -eq 'reauth') {
            # Silme diyaloğuna dönüş: şifre alanı veya onay alındı
            if (-not $pickerOpen -and (
                $xml2 -match 'ifreni gir' -or $xml2 -match 'onay' -or
                $xml2 -match 'geri al' -or $xml2 -match 'Google ile onayla' -or
                $xml2 -match 'Hesab'
            )) {
                $fg = cmd /c "adb -s $Device shell dumpsys window | findstr mCurrentFocus"
                if ($fg -match 'com\.myvibel\.app') {
                    L "Reauth Google OK (dialog)"
                    return $true
                }
            }
            if ($xml2 -match $GoogleEmail -and $pickerOpen) {
                [void](TapN $GoogleEmail 2)
            }
            Start-Sleep 1
            continue
        }
        $s = Screen
        if ($s -in @('profil','sifre','feed')) { L ("Sonrasi ekran: " + $s); return $true }
        if ($s -eq 'login') {
            Start-Sleep 2
            $s2 = Screen
            if ($s2 -eq 'login') { Start-Sleep 2; continue }
        }
        if ($xml2 -match $GoogleEmail -and ($xml2 -match 'Choose an account' -or $xml2 -match 'Hesap')) {
            [void](TapN $GoogleEmail 2)
        }
        Start-Sleep 1
    }
    L ("TIMEOUT ekran=" + (Screen) + " mode=" + $Mode)
    # Reauth: picker kapandiysa yine basarili say
    if ($Mode -eq 'reauth') {
        $fg = cmd /c "adb -s $Device shell dumpsys window | findstr mCurrentFocus"
        if ($fg -match 'com\.myvibel\.app') { L "Reauth TIMEOUT ama app foreground — OK"; return $true }
    }
    return $false
}
function GoogleLoginButton {
    if (-not (TapN "Google ile devam et" 6)) { return (TapN "Google ile" 4) }
    return $true
}
function TapCheckBoxOnly {
    for ($try = 0; $try -lt 8; $try++) {
        $xml = Dump-Ui
        # Once checked, done
        if ($xml -match 'class="android.widget.CheckBox"[^>]*checked="true"' -or
            $xml -match 'checked="true"[^>]*class="android.widget.CheckBox"') {
            L "Checkbox OK"
            return $true
        }
        $cb = [regex]::Match($xml, 'class="android.widget.CheckBox"[^>]*bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"')
        if (-not $cb.Success) {
            $cb = [regex]::Match($xml, 'bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"[^>]*class="android.widget.CheckBox"')
        }
        if (-not $cb.Success) {
            $cb = [regex]::Match($xml, 'checkable="true"[^>]*checked="false"[^>]*bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"')
        }
        if (-not $cb.Success) {
            $cb = [regex]::Match($xml, 'bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"[^>]*checkable="true"[^>]*checked="false"')
        }
        if ($cb.Success) {
            # Sol kutu: metin linklerine basmamak icin sol kenar + 24px
            $x = [int]$cb.Groups[1].Value + 24
            $y = [int](([int]$cb.Groups[2].Value + [int]$cb.Groups[4].Value) / 2)
            L ("TAP checkbox @$x,$y")
            Tap $x $y
            Start-Sleep 1
            continue
        }
        # Checkbox scroll disinda — formu asagi kaydir (pinli DEVAM'a carpma)
        L "Checkbox yok, scroll"
        cmd /c "adb -s $Device shell input swipe 540 1400 540 700 280 >nul 2>&1"
        Start-Sleep -Milliseconds 500
    }
    L "WARN checkbox bulunamadi"
    return $false
}
function Get-ScreenSize {
    $out = cmd /c "adb -s $Device shell wm size"
    if ($out -match '(\d+)x(\d+)') {
        return @{ w = [int]$Matches[1]; h = [int]$Matches[2] }
    }
    return @{ w = 1080; h = 2400 }
}
function TapDevamEt {
    # Pinli bottom DEVAM ET — Semantics "Google profilini kaydet" oncelikli
    $title = Find-Center (Dump-Ui) "Profilini tamamla"
    if ($title) { Tap $title.x $title.y; Start-Sleep -Milliseconds 300 }
    $size = Get-ScreenSize
    for ($round = 0; $round -lt 6; $round++) {
        $xml = Dump-Ui
        foreach ($label in @("Google profilini kaydet", "DEVAM ET", "Devam Et")) {
            $b = Find-Exact $xml $label
            if (-not $b) { $b = Find-Center $xml $label }
            if ($b -and $b.y -le ($size.h - 80)) {
                L ("TAP devam " + $b.label + " @" + $b.x + "," + $b.y)
                Tap $b.x $b.y
                return $true
            }
        }
        # Genis ElevatedButton (pinli alt bar)
        $btns = [regex]::Matches($xml, 'class="android.widget.Button"[^>]*bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"')
        if ($btns.Count -eq 0) {
            $btns = [regex]::Matches($xml, 'bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"[^>]*class="android.widget.Button"')
        }
        $bestBtn = $null; $bestW = 0
        foreach ($m in $btns) {
            $x1=[int]$m.Groups[1].Value; $y1=[int]$m.Groups[2].Value
            $x2=[int]$m.Groups[3].Value; $y2=[int]$m.Groups[4].Value
            $w = $x2 - $x1; $h = $y2 - $y1
            $cy = [int](($y1+$y2)/2)
            if ($w -gt 400 -and $h -gt 50 -and $cy -gt ($size.h * 0.55) -and $cy -lt ($size.h - 80) -and $w -gt $bestW) {
                $bestW = $w
                $bestBtn = @{ x = [int](($x1+$x2)/2); y = $cy }
            }
        }
        if ($bestBtn) {
            L ("TAP devam wide-button @" + $bestBtn.x + "," + $bestBtn.y)
            Tap $bestBtn.x $bestBtn.y
            return $true
        }
        Start-Sleep -Milliseconds 400
    }
    # Pinli bar: ekran altindan guvenli yukseklik (gesture bar ustu)
    $fx = [int]($size.w / 2)
    $fy = [int]($size.h - 280)
    if ($fy -lt 1500) { $fy = [int]($size.h * 0.78) }
    L ("TAP devam pinned-fallback @$fx,$fy (screen=$($size.w)x$($size.h))")
    Tap $fx $fy
    return $true
}
function FillProfile {
    L ("Profil doldur @" + $KullaniciAdi)
    if (-not (WaitN "Profilini tamamla" 20)) {
        $s = Screen
        L ("Profil formu yok, ekran=" + $s)
        return $s
    }
    $xml = Dump-Ui
    $edits = [regex]::Matches($xml, 'class="android.widget.EditText"[^>]*bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"')
    if ($edits.Count -eq 0) {
        $edits = [regex]::Matches($xml, 'bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"[^>]*class="android.widget.EditText"')
    }
    L ("EditText=" + $edits.Count)
    function FillAt([int]$i,[string]$t) {
        if ($i -ge $edits.Count) { return }
        $g=$edits[$i].Groups
        $x=[int](([int]$g[1].Value+[int]$g[3].Value)/2)
        $y=[int](([int]$g[2].Value+[int]$g[4].Value)/2)
        Tap $x $y
        Start-Sleep -Milliseconds 300
        1..40 | ForEach-Object { cmd /c "adb -s $Device shell input keyevent KEYCODE_DEL >nul 2>&1" }
        cmd /c "adb -s $Device shell input text $t >nul 2>&1"
        Start-Sleep -Milliseconds 300
    }
    FillAt 0 $AdSoyad
    FillAt 1 $KullaniciAdi
    if ($edits.Count -ge 4) { FillAt 2 $Sifre; FillAt 3 $Sifre }

    if (TapN "tarihini" 3) {
        Start-Sleep 1
        if (-not (TapExact "Tamam" 4)) { [void](TapExact "OK" 2) }
    }
    # Checkbox: sadece CheckBox / checkable kutu — metin linklerine ASLA basma
    [void](TapCheckBoxOnly)
    Start-Sleep 1
    # Checkbox scroll sonrasi pinli buton hala gorunur olmali
    if (-not (TapDevamEt)) {
        L "DEVAM ET tap fail — feed gecisi bekleniyor"
    }

    $end = (Get-Date).AddSeconds(90)
    while ((Get-Date) -lt $end) {
        $s = Screen
        if ($s -eq 'feed') { L "Kayit OK -> Feed"; return 'feed' }
        if ($s -eq 'sifre') { L "Sifre belirle ekrani"; return 'sifre' }
        EnsureAppForeground
        $xmlWait = Dump-Ui
        if ($xmlWait -match $GoogleEmail -and $xmlWait -notmatch 'Alt menü' -and (
            $xmlWait -match 'Hesap seç' -or $xmlWait -match 'Choose an account' -or
            $xmlWait -match 'hesabını seç' -or $xmlWait -match 'Google ile oturum'
        )) {
            [void](PickGoogle)
        }
        # Hâlâ profildeyse DEVAM'i tekrar dene
        if ($s -eq 'profil') {
            $b = Find-Exact $xmlWait "Google profilini kaydet"
            if (-not $b) { $b = Find-Center $xmlWait "Google profilini kaydet" }
            if (-not $b) { $b = Find-Exact $xmlWait "DEVAM ET" }
            if ($b -and $b.y -le 2200) {
                L ("RETRY devam @" + $b.x + "," + $b.y)
                Tap $b.x $b.y
            }
        }
        Start-Sleep 1
    }
    L ("Kayit timeout ekran=" + (Screen))
    return (Screen)
}
function DoLogout {
    L "Cikis"
    if (-not (TapN "Alt menü Profil" 6)) { [void](TapN "Profil" 4) }
    Start-Sleep 2
    if (-not (TapN "Çıkış Yap" 5)) {
        if (TapN "Ayarlar" 4) {
            Start-Sleep 1
            if (-not (TapN "Çıkış Yap" 4)) { L "FAIL cikis yok"; return $false }
        } else { L "FAIL ayarlar yok"; return $false }
    }
    Start-Sleep 3
    if (WaitN "Google ile devam et" 20) { L "Cikis OK"; return $true }
    if (WaitN "Giriş Yap" 8) { L "Cikis OK"; return $true }
    L ("FAIL cikis sonrasi=" + (Screen)); return $false
}
function AssertFeedAfterGoogle {
    L "Ayni hesapla tekrar Google"
    if (-not (GoogleLoginButton)) { L "FAIL google btn"; return $false }
    Start-Sleep 2
    if (-not (PickGoogle)) { L "FAIL pick"; return $false }
    Start-Sleep 3
    $s = Screen
    L ("Tekrar giris ekran=" + $s)
    if ($s -eq 'profil') { L "BUG: tekrar kayit/profil istedi"; return $false }
    if ($s -eq 'feed') { L "OK: Feed (giris)"; return $true }
    if ($s -eq 'sifre') { L "UYARI: sifre belirle (profil var sifre eksik)"; return $false }
    L "BUG: beklenmeyen ekran"; return $false
}
function IsLoginScreen([string]$xml) {
    if ([string]::IsNullOrEmpty($xml)) { return $false }
    # Dialog aciksa login degil
    if ($xml -match 'Neden ayr' -or $xml -match 'Bir sorun var' -or $xml -match 'ifreni gir' -or $xml -match 'Google ile onayla') {
        return $false
    }
    if ($xml -match 'Google ile devam et') { return $true }
    if ($xml -match 'Gir.?[sşŞ] Yap' -or $xml -match 'Hesab.?na gir') { return $true }
    return $false
}
function TapHesabiSilConfirm([string]$xml) {
    # Baslik (ustte) degil, action butonu (en alt / en sag) — y > 1100 tercih
    $rxList = @(
        '(?:text|content-desc)="Hesab[^"]*Sil"[^>]*bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"',
        'bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"[^>]*(?:text|content-desc)="Hesab[^"]*Sil"'
    )
    $cands = @()
    foreach ($rx in $rxList) {
        foreach ($m in [regex]::Matches($xml, $rx)) {
            $x = [int](([int]$m.Groups[1].Value + [int]$m.Groups[3].Value) / 2)
            $y = [int](([int]$m.Groups[2].Value + [int]$m.Groups[4].Value) / 2)
            $cands += @{ x = $x; y = $y }
        }
    }
    if ($cands.Count -gt 0) {
        $best = $cands | Sort-Object { $_.y } -Descending | Select-Object -First 1
        if ($best.y -ge 900) {
            L ("TAP HesabiSilConfirm @" + $best.x + "," + $best.y)
            Tap $best.x $best.y
            return $true
        }
        L ("SKIP HesabiSil baslik gibi y=" + $best.y)
    }
    # Fallback: Vazgeç'in sagindaki kirmizi aksiyon (dialog actions)
    $vaz = Find-Exact $xml "Vazgeç"
    if (-not $vaz) { $vaz = Find-Center $xml "Vazgeç" }
    if ($vaz) {
        $tx = [Math]::Min(1000, $vaz.x + 280)
        $ty = $vaz.y
        L ("TAP HesabiSil via Vazgeç sag @$tx,$ty")
        Tap $tx $ty
        return $true
    }
    return $false
}
function DeleteAcc {
    L "Hesap sil"
    if (-not (TapN "Alt menü Profil" 5)) { [void](TapN "Profil" 3) }
    Start-Sleep 2
    if (-not (TapN "Ayarlar" 5)) { L "FAIL ayarlar"; return $false }
    Start-Sleep 1
    cmd /c "adb -s $Device shell input swipe 540 1800 540 900 300 >nul 2>&1"
    Start-Sleep 1
    # Ayarlar listesindeki "Hesabı Sil" — genelde altta
    $menuXml = Dump-Ui
    if (-not (TapHesabiSilConfirm $menuXml)) {
        if (-not (TapN "Hesabı Sil" 5)) { L "FAIL hesabi sil menu"; return $false }
    }
    Start-Sleep 2

    $nedenSecildi = $false
    $sorunAtlandi = $false
    $sifreYazildi = $false
    $googleOk = $false
    $end = (Get-Date).AddSeconds(150)
    while ((Get-Date) -lt $end) {
        EnsureAppForeground
        $xml = Dump-Ui

        if (IsLoginScreen $xml) {
            L "Silindi OK"
            return $true
        }

        if (($xml -match 'Google ile onayla') -and -not $googleOk) {
            $go = TapExact "Google ile onayla" 3
            if (-not $go) { $go = TapN "Google ile onayla" 2 }
            if ($go) {
                Start-Sleep 2
                [void](PickGoogle -Mode 'reauth')
                $googleOk = $true
                Start-Sleep 3
                continue
            }
        }

        # Adim 0: neden — Diğer'e ASLA basma
        if (-not $nedenSecildi -and ($xml -match 'Neden ayr' -or $xml -match 'ayr.?liyorsun' -or $xml -match 'ayrılıyorsun')) {
            $picked = $false
            if (TapExact "Uygulamayı yeterince kullanmıyorum" 3) {
                $picked = $true
            } else {
                foreach ($n in @(
                    'Uygulamayı yeterince kullanmıyorum',
                    'Vibel bakımı yorucu geldi',
                    'Arkadaşlarımı burada bulamadım',
                    'Gizlilik endişem var',
                    'Başka bir hesap açacağım'
                )) {
                    $b = Find-Center $xml $n
                    if ($b -and $b.label -notmatch 'Diğer') {
                        L ("TAP " + $b.label + " @" + $b.x + "," + $b.y)
                        Tap $b.x $b.y
                        $picked = $true
                        break
                    }
                }
            }
            if ($picked) {
                $nedenSecildi = $true
                Start-Sleep 1
                if (-not (TapExact "Devam" 4)) { [void](TapN "Devam" 2) }
                Start-Sleep 1
                continue
            }
        }

        # Adim 1: sorun — exact "Atla" (hint "İstersen atla." ASLA)
        if (-not $sorunAtlandi -and ($xml -match 'Bir sorun var' -or $xml -match 'Sorununu yaz' -or $xml -match 'sorun varsa')) {
            if (TapExact "Atla" 4) {
                $sorunAtlandi = $true
                Start-Sleep 1
                continue
            }
            L "WARN Atla butonu yok, Devam deneniyor"
            if (TapExact "Devam" 2) {
                $sorunAtlandi = $true
                Start-Sleep 1
                continue
            }
        }

        $sifreAdimi = ($xml -match 'ifreni gir' -or $xml -match 'onay.?n al' -or ($googleOk -and $xml -match 'EditText' -and $xml -match 'Hesab'))
        if ($sifreAdimi -and -not $sifreYazildi) {
            $edits = [regex]::Matches($xml, 'class="android.widget.EditText"[^>]*bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"')
            if ($edits.Count -eq 0) {
                $edits = [regex]::Matches($xml, 'bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"[^>]*class="android.widget.EditText"')
            }
            if ($edits.Count -ge 1) {
                $g = $edits[0].Groups
                $x = [int](([int]$g[1].Value + [int]$g[3].Value) / 2)
                $y = [int](([int]$g[2].Value + [int]$g[4].Value) / 2)
                Tap $x $y
                Start-Sleep -Milliseconds 400
                1..40 | ForEach-Object { cmd /c "adb -s $Device shell input keyevent 67 >nul 2>&1" }
                cmd /c "adb -s $Device shell input text $Sifre >nul 2>&1"
                L ("Sifre yazildi: " + $Sifre)
                $sifreYazildi = $true
                Start-Sleep 1
                $xml = Dump-Ui
            }
            [void](TapHesabiSilConfirm $xml)
            Start-Sleep 5
            if (IsLoginScreen (Dump-Ui)) { L "Silindi OK"; return $true }
            continue
        }

        if ($sifreYazildi) {
            $sifreYazildi = $false
        }
        Start-Sleep 1
    }
    L ("Silme belirsiz=" + (Screen)); return $false
}

# ---- TUR ----
function OneCycle([string]$tag) {
    L "===== $tag ====="
    $script:KullaniciAdi = "sla" + (Get-Random -Minimum 1000 -Maximum 9999)
    $acilis = Launch
    if ($acilis -eq 'feed') {
        L "$tag zaten feed (onceki oturum)"
    } elseif ($acilis -eq 'profil' -or $acilis -eq 'sifre') {
        L "$tag yarim google oturumu - profil tamamla"
    } else {
        if (-not (GoogleLoginButton)) { throw "google btn" }
        Start-Sleep 2
        if (-not (PickGoogle)) { throw "google pick" }
    }
    if ((Screen) -eq 'feed') {
        L "$tag kayit/giris OK (feed)"
    } else {
        $r = FillProfile
        if ($r -eq 'feed') {
            L "$tag kayit/giris OK"
        } elseif ($r -eq 'profil') {
            throw "$tag profilde kaldi"
        } else {
            if ((Screen) -ne 'feed') { throw "$tag beklenen feed degil: $r / $(Screen)" }
        }
    }
    if (-not (DoLogout)) { throw "$tag cikis fail" }
    $ok = AssertFeedAfterGoogle
    L "$tag ikinci_giris_feed=$ok"
    if (-not $ok) { throw "$tag ikinci giris FAIL" }
    if (-not (DeleteAcc)) { throw "$tag silme FAIL" }
    return $true
}

adb -s $Device logcat -c | Out-Null
L ("user=" + $KullaniciAdi + " sifre=" + $Sifre)
try {
    OneCycle "TUR1"
    OneCycle "TUR2"
    L "========== BASARILI =========="
    $Log | Set-Content (Join-Path $PSScriptRoot "google-test-sonuc.log") -Encoding UTF8
    exit 0
} catch {
    L ("HATA: " + $_)
    L ("ekran=" + (Screen))
    adb -s $Device logcat -d -t 100 *:E FirebaseAuth:V flutter:V GoogleSignIn:V | Select-Object -Last 40 | ForEach-Object { L ("LOG " + $_) }
    $Log | Set-Content (Join-Path $PSScriptRoot "google-test-sonuc.log") -Encoding UTF8
    exit 1
}
