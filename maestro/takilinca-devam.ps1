# Maestro takilinca tum taramayi kesmez.
# Takilan bolumu yazar, telefonda sen toparlarsin, sonra devam.
#
# Kullanim (proje kokunden):
#   powershell -ExecutionPolicy Bypass -File maestro\takilinca-devam.ps1
# Istege bagli cihaz:
#   powershell -ExecutionPolicy Bypass -File maestro\takilinca-devam.ps1 -Device VG55GULZ7LQSIV6T

param(
    [string]$Device = "",
    [switch]$OtomatikAtla
)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
if (-not (Test-Path (Join-Path $PSScriptRoot "bolumler"))) {
    $Root = $PSScriptRoot
}
$BolumDir = Join-Path $PSScriptRoot "bolumler"
Set-Location $Root

function Get-DeviceId {
    if ($Device) { return $Device }
    $lines = adb devices | Select-String "device$"
    if ($lines.Count -eq 0) {
        throw "Bagli Android cihaz yok. USB acik olsun, ekran kilidi acik olsun."
    }
    return ($lines[0].ToString() -split "\s+")[0]
}

function Get-TakilmaOzeti([string]$log) {
    $satirlar = $log -split "`r?`n"
    $anahtar = $satirlar | Where-Object {
        $_ -match "Element not found|Assertion is false|Unable to find|not visible|FAILED|Tap on"
    }
    if ($anahtar) {
        return ($anahtar | Select-Object -Last 8) -join "`n"
    }
    return (($satirlar | Select-Object -Last 15) -join "`n")
}

$udid = Get-DeviceId
$bolumler = Get-ChildItem -Path $BolumDir -Filter "*.yaml" | Sort-Object Name
$gecen = New-Object System.Collections.Generic.List[string]
$atlanan = New-Object System.Collections.Generic.List[string]
$basarisizTekrar = New-Object System.Collections.Generic.List[string]

Write-Host ""
Write-Host "MyVibel Maestro - takilinca devam"
Write-Host "Cihaz: $udid"
Write-Host "Bolum sayisi: $($bolumler.Count)"
if ($OtomatikAtla) {
    Write-Host "Mod: takilan bolum otomatik atlanir, sonraki bolume gecilir."
} else {
    Write-Host "Takilirsa: telefonda dogru ekrana gec, sonra secim yap."
    Write-Host "  R  = bu bolumu tekrar dene"
    Write-Host "  Enter / S = bu bolumu atla, sonrakine gec"
    Write-Host "  Q  = dur"
}
Write-Host ""

foreach ($dosya in $bolumler) {
    $tekrar = $true
    while ($tekrar) {
        Write-Host "----------------------------------------"
        Write-Host "BOLUM: $($dosya.Name)"
        Write-Host "----------------------------------------"
        $arglar = @(
            "test", $dosya.FullName,
            "--no-reinstall-driver",
            "--udid", $udid,
            "--format", "NOOP"
        )
        $cikti = & maestro @arglar 2>&1 | Out-String
        Write-Host $cikti
        if ($LASTEXITCODE -eq 0) {
            $gecen.Add($dosya.Name) | Out-Null
            $tekrar = $false
            continue
        }

        $ozet = Get-TakilmaOzeti $cikti
        Write-Host ""
        Write-Host "TAKILDI: $($dosya.Name)" -ForegroundColor Yellow
        Write-Host "Maestro sunu yapamadi:"
        Write-Host $ozet
        Write-Host ""

        if ($OtomatikAtla) {
            Write-Host "Otomatik atla: $($dosya.Name) -> sonraki bolum"
            $atlanan.Add($dosya.Name) | Out-Null
            $topar = Join-Path $PSScriptRoot "flows\ana-sayfaya-don.yaml"
            if (Test-Path $topar) {
                Write-Host "Sonraki bolum icin Ana ekrana donuluyor..."
                $toparArg = @(
                    "test", $topar,
                    "--no-reinstall-driver",
                    "--udid", $udid,
                    "--format", "NOOP"
                )
                & maestro @toparArg 2>&1 | Out-Null
            }
            $tekrar = $false
            continue
        }

        Write-Host "Telefonda o ekrana / butona sen gec. Hazir olunca:"
        $secim = Read-Host "R = tekrar, Enter = atla ve devam, Q = dur"

        if ($secim -eq "Q" -or $secim -eq "q") {
            Write-Host "Durduruldu."
            exit 1
        }
        if ($secim -eq "R" -or $secim -eq "r") {
            $basarisizTekrar.Add($dosya.Name) | Out-Null
            continue
        }
        $atlanan.Add($dosya.Name) | Out-Null
        $tekrar = $false
    }
}

Write-Host ""
Write-Host "========== OZET =========="
$gecenListe = $gecen -join ", "
$atlananListe = $atlanan -join ", "
Write-Host "Gecen: $($gecen.Count)  $gecenListe"
Write-Host "Atlanan (takildi, sonra bakilacak): $($atlanan.Count)  $atlananListe"
if ($atlanan.Count -gt 0) {
    Write-Host "Atlananlar uygulamayi bozmaz; sadece o bolum otomatik bitmedi."
}
