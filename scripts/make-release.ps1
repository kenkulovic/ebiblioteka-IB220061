# Priprema predaje:
#   1. gradi Windows aplikaciju (Release) i Android APK (Release)
#   2. pravi release\eBiblioteka-IB220061-<verzija>.zip (APK + Windows Release folder)
#   3. pravi .env-tajne.zip (zasticen lozinkom, AES-256) umjesto .env fajla
#
#   powershell -File scripts\make-release.ps1 -SecretsPassword "<lozinka>"
#
# Preduslovi: Flutter, Visual Studio (C++), Android SDK, 7-Zip.
# GitHub Release se objavljuje rucno (vidi README): ZIP iz foldera release\ se dodaje kao neizmjenjiv (immutable) release.

param(
    [Parameter(Mandatory = $true)][string]$SecretsPassword,
    [string]$Version = '1.0.0',
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
New-Item -ItemType Directory -Path "$staging\desktop" -Force | Out-Null
New-Item -ItemType Directory -Path "$staging\mobile" -Force | Out-Null

Write-Host '1/4 Windows aplikacija (Release)'
Push-Location "$root\desktop"
flutter build windows --release --dart-define=API_BASE_URL=$WindowsApiUrl
if ($LASTEXITCODE -ne 0) { throw 'Izgradnja Windows aplikacije nije uspjela.' }
Pop-Location
Copy-Item "$root\desktop\build\windows\x64\runner\Release\*" "$staging\desktop" -Recurse

Write-Host '2/4 Android APK (Release)'
Push-Location "$root\mobile"
flutter build apk --release --dart-define=API_BASE_URL=$AndroidApiUrl
if ($LASTEXITCODE -ne 0) { throw 'Izgradnja APK-a nije uspjela.' }
Pop-Location
Copy-Item "$root\mobile\build\app\outputs\flutter-apk\app-release.apk" "$staging\mobile\eBiblioteka.apk"

@"
eBiblioteka $Version (IB220061)

desktop\ebiblioteka_desktop.exe   Desktop aplikacija za bibliotekare (Windows). Adresa API-ja: $WindowsApiUrl
mobile\eBiblioteka.apk            Mobilna aplikacija za clanove (Android). Adresa API-ja: $AndroidApiUrl
                                  (10.0.2.2 je racunar gledano iz Android emulatora)

Backend se pokrece iz izvornog koda: docker compose up -d --build (vidi README.md u repozitoriju).
Korisnici za testiranje (lozinka za sve: test): desktop (administrator), mobile, maja, adnan, amra, emir, tarik, sara.
"@ | Set-Content "$staging\PROCITAJ.txt" -Encoding utf8

Write-Host '3/4 ZIP za GitHub Release'
$zip = "$out\eBiblioteka-IB220061-v$Version.zip"
Compress-Archive -Path "$staging\*" -DestinationPath $zip -CompressionLevel Optimal
Remove-Item $staging -Recurse -Force

Write-Host '4/4 .env-tajne.zip'
$secrets = "$root\.env-tajne.zip"
Remove-Item $secrets -ErrorAction SilentlyContinue
& $sevenZip a -tzip -mem=AES256 "-p$SecretsPassword" $secrets "$root\.env" | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'Izrada .env-tajne.zip nije uspjela.' }

Write-Host ''
Get-ChildItem $out, $secrets | Select-Object Name, @{n = 'MB'; e = { [math]::Round($_.Length / 1MB, 1) } } | Format-Table -AutoSize
Write-Host "Gotovo. Release ZIP: $zip"
