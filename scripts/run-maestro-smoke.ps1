param(
    [string]$DeviceId = "",
    [switch]$SkipBuild
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$flowPath = Join-Path $projectRoot "maestro\smoke.yaml"
$apkPath = Join-Path $projectRoot "build\app\outputs\flutter-apk\app-debug.apk"

function Find-Maestro {
    $candidates = New-Object System.Collections.Generic.List[string]

    if ($env:MAESTRO_BIN) {
        $candidates.Add($env:MAESTRO_BIN)
    }

    $pathCommand = Get-Command maestro -ErrorAction SilentlyContinue
    if ($pathCommand) {
        $candidates.Add($pathCommand.Source)
    }

    $candidates.Add("C:\maestro\bin\maestro.bat")

    foreach ($candidate in $candidates) {
        if ($candidate -and (Test-Path -LiteralPath $candidate)) {
            return (Resolve-Path -LiteralPath $candidate).Path
        }
    }

    throw "Maestro bulunamadi. C:\maestro\bin\maestro.bat yolunu veya MAESTRO_BIN ortam degiskenini kontrol et."
}

function Select-AndroidDevice([string]$RequestedDeviceId) {
    if ($RequestedDeviceId) {
        return $RequestedDeviceId
    }

    $adbCommand = Get-Command adb -ErrorAction SilentlyContinue
    if ($adbCommand) {
        $adbDeviceIds = @(
            adb devices | ForEach-Object {
                if ($_ -match "^(\S+)\s+device(\s|$)") {
                    $Matches[1]
                }
            }
        )

        if ($adbDeviceIds.Count -eq 1) {
            return $adbDeviceIds[0]
        }

        if ($adbDeviceIds.Count -gt 1) {
            $ids = $adbDeviceIds -join ", "
            throw "Birden fazla Android cihaz bulundu: $ids. Komutu -DeviceId <cihaz_id> ile calistir."
        }
    }

    $devicesJson = flutter devices --machine | Out-String
    $parsedDevices = $devicesJson | ConvertFrom-Json
    $androidDevices = New-Object System.Collections.Generic.List[object]

    foreach ($device in $parsedDevices) {
        $targetPlatform = ""
        if ($device.PSObject.Properties.Name -contains "targetPlatform") {
            $targetPlatform = [string]$device.targetPlatform
        }

        $platformType = ""
        if ($device.PSObject.Properties.Name -contains "platformType") {
            $platformType = [string]$device.platformType
        }

        if ($platformType -eq "android" -or $targetPlatform -like "android-*") {
            $androidDevices.Add($device)
        }
    }

    if ($androidDevices.Count -eq 0) {
        throw "Android cihaz bulunamadi. Telefonun/emulatorun acik oldugunu ve adb ile gorundugunu kontrol et."
    }

    if ($androidDevices.Count -gt 1) {
        $ids = ($androidDevices | ForEach-Object { $_.id }) -join ", "
        throw "Birden fazla Android cihaz bulundu: $ids. Komutu -DeviceId <cihaz_id> ile calistir."
    }

    return $androidDevices[0].id
}
if (-not (Test-Path -LiteralPath $flowPath)) {
    throw "Maestro smoke testi bulunamadi: $flowPath"
}

$env:MAESTRO_CLI_NO_ANALYTICS = "1"
$maestro = Find-Maestro
$androidDeviceId = Select-AndroidDevice $DeviceId

Push-Location $projectRoot
try {
    Write-Host "Android cihaz: $androidDeviceId"
    Write-Host "Maestro: $maestro"

    flutter pub get

    if (-not $SkipBuild) {
        flutter build apk --debug
    }

    if (-not (Test-Path -LiteralPath $apkPath)) {
        throw "Debug APK bulunamadi: $apkPath"
    }

    flutter install -d $androidDeviceId --use-application-binary $apkPath
    & $maestro test $flowPath
} finally {
    Pop-Location
}


