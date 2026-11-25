# Priprema predaje prema uputama (9.2):
#   1. flutter clean + build Windows aplikacije (Release) i Android APK-a (Release)
#   2. pravi release\fit-build-<datum>.zip sa strukturom iz uputa:
#        mobile\build\app\outputs\flutter-apk\app-release.apk
#        desktop\build\windows\x64\runner\Release\
#   3. pravi .env-tajne.zip (zasticen lozinkom, AES-256) umjesto .env fajla
#
#   powershell -File scripts\make-release.ps1 -SecretsPassword "<lozinka>"
#
# Preduslovi: Flutter, Visual Studio (C++), Android SDK, 7-Zip.
# GitHub Release se objavljuje rucno (vidi README): prvo kao draft, pa objava kao immutable release.

param(
    [Parameter(Mandatory = $true)][string]$SecretsPassword,
    [string]$WindowsApiUrl = 'http://localhost:5028',
    [string]$AndroidApiUrl = 'http://10.0.2.2:5028'
)

$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$env:Path = [Environment]::GetEnvironmentVariable('Path', 'User') + ';' + [Environment]::GetEnvironmentVariable('Path', 'Machine')

$sevenZip = 'C:\Program Files\7-Zip\7z.exe'
if (-not (Test-Path $sevenZip)) { throw '7-Zip nije instaliran (potreban za .env-tajne.zip).' }
if (-not (Test-Path "$root\.env")) { throw 'Nedostaje .env u korijenu projekta.' }

$out = "$root\release"
$staging = "$out\staging"
Remove-Item $out -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Path "$staging\desktop\build\windows\x64\runner\Release" -Force | Out-Null
New-Item -ItemType Directory -Path "$staging\mobile\build\app\outputs\flutter-apk" -Force | Out-Null

Write-Host '1/4 Windows aplikacija (flutter clean + Release)'
Push-Location "$root\desktop"
flutter clean
if ($LASTEXITCODE -ne 0) { throw 'flutter clean (desktop) nije uspio.' }
flutter pub get
flutter build windows --release --dart-define=API_BASE_URL=$WindowsApiUrl
if ($LASTEXITCODE -ne 0) { throw 'Izgradnja Windows aplikacije nije uspjela.' }
Pop-Location
Copy-Item "$root\desktop\build\windows\x64\runner\Release\*" "$staging\desktop\build\windows\x64\runner\Release" -Recurse

Write-Host '2/4 Android APK (flutter clean + Release)'
Push-Location "$root\mobile"
flutter clean
if ($LASTEXITCODE -ne 0) { throw 'flutter clean (mobile) nije uspio.' }
flutter pub get
flutter build apk --release --dart-define=API_BASE_URL=$AndroidApiUrl
if ($LASTEXITCODE -ne 0) { throw 'Izgradnja APK-a nije uspjela.' }
Pop-Location
Copy-Item "$root\mobile\build\app\outputs\flutter-apk\app-release.apk" "$staging\mobile\build\app\outputs\flutter-apk\app-release.apk"

Write-Host '3/4 ZIP za GitHub Release'
$zip = "$out\fit-build-$(Get-Date -Format 'yyyy-MM-dd').zip"
# 7-Zip upisuje putanje s kosom crtom (standardni ZIP); Compress-Archive u PowerShell 5.1 upisuje obrnutu kosu crtu.
Push-Location $staging
& $sevenZip a -tzip -mx=9 $zip desktop mobile | Out-Null
$zipExit = $LASTEXITCODE
Pop-Location
if ($zipExit -ne 0) { throw 'Izrada ZIP-a nije uspjela.' }
Remove-Item $staging -Recurse -Force

Write-Host '4/4 .env-tajne.zip'
$secrets = "$root\.env-tajne.zip"
Remove-Item $secrets -ErrorAction SilentlyContinue
& $sevenZip a -tzip -mem=AES256 "-p$SecretsPassword" $secrets "$root\.env" | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'Izrada .env-tajne.zip nije uspjela.' }

Write-Host ''
Get-ChildItem $out, $secrets | Select-Object Name, @{n = 'MB'; e = { [math]::Round($_.Length / 1MB, 1) } } | Format-Table -AutoSize
Write-Host "Gotovo. Release ZIP: $zip"
