# Integracijski test mobilne aplikacije na Android emulatoru protiv pravog sistema.
#
# Priprema okruzenje (baza u pocetnom stanju, API, Worker, Mailpit, lazni PayPal), pokrene test
# na emulatoru, a na kraju ugasi procese i vrati bazu u pocetno (demo) stanje.
#
# Preduslovi: Docker Desktop, pokrenut Android emulator, Python (za lazni PayPal).
#   powershell -File scripts\run-mobile-tests.ps1

$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
Set-Location $root

$env:Path = [Environment]::GetEnvironmentVariable('Path', 'User') + ';' + [Environment]::GetEnvironmentVariable('Path', 'Machine')

function Read-EnvValue([string]$name) {
    ((Get-Content "$root\.env" | Where-Object { $_ -like "$name=*" }) -replace "^$name=", '').Trim()
}

$dbPassword = Read-EnvValue 'DB_PASSWORD'
$apiUrl = 'http://localhost:5028'

function Invoke-Sql([string]$query) {
    docker exec ebiblioteka-db /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P $dbPassword -C -I -d 220061 -h -1 -Q $query | Out-Null
}

function Stop-Port([int]$port) {
    Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue |
        ForEach-Object { Stop-Process -Id $_.OwningProcess -Force -ErrorAction SilentlyContinue }
}

function Stop-Local {
    Stop-Port 5028
    Stop-Port 5099
    Get-Process 'eBiblioteka.Api', 'eBiblioteka.Worker' -ErrorAction SilentlyContinue | Stop-Process -Force
    Get-CimInstance Win32_Process -Filter "Name='dotnet.exe'" |
        Where-Object { $_.CommandLine -like '*eBiblioteka.Api*' -or $_.CommandLine -like '*eBiblioteka.Worker*' } |
        ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
}

function Reset-DemoData {
    # Brise aktivnost i probne korisnike; pri sljedecem startu API ponovo ubacuje pocetne podatke.
    Invoke-Sql @"
DELETE FROM BookSimilarities; DELETE FROM Payments; DELETE FROM Fines; DELETE FROM Reviews; DELETE FROM Loans;
DELETE FROM ReservationStatusHistory; DELETE FROM Reservations; DELETE FROM Notifications;
DELETE FROM AspNetUserRoles WHERE UserId IN (SELECT Id FROM AspNetUsers WHERE UserName LIKE 'testni%');
DELETE FROM AspNetUsers WHERE UserName LIKE 'testni%';
UPDATE AspNetUsers SET LockoutEnd = NULL, AccessFailedCount = 0, IsBlocked = 0, BlockReason = NULL;
"@
}

function Wait-Api {
    for ($i = 0; $i -lt 60; $i++) {
        try {
            Invoke-WebRequest -Uri "$apiUrl/api/auth/login" -Method Post -ContentType 'application/json' -Body '{}' -UseBasicParsing -ErrorAction Stop | Out-Null
        } catch {
            if ($_.Exception.Response) { return }
        }
        Start-Sleep -Seconds 2
    }
    throw 'API se nije pokrenuo.'
}

function Start-Api {
    $env:PAYPAL_CLIENT_ID = 'mockid'
    $env:PAYPAL_CLIENT_SECRET = 'mocksecret'
    $env:PAYPAL_BASE_URL = 'http://127.0.0.1:5099'
    Start-Process dotnet -ArgumentList 'run', '--no-build', '--launch-profile', 'http' `
        -WorkingDirectory "$root\src\eBiblioteka.Api" -WindowStyle Hidden
    Wait-Api
}

try {
    Write-Host '1. Priprema: infrastruktura i ciscenje'
    Stop-Local
    docker compose stop api worker | Out-Null
    docker compose up -d db rabbitmq mailpit | Out-Null
    Reset-DemoData

    Write-Host '2. Lazni PayPal, API (sa seedom) i Worker'
    dotnet build "$root\src" | Out-Null
    # Iz emulatora je racunar dostupan kao 10.0.2.2, pa se stranica za odobrenje nudi pod tom adresom.
    $env:FAKE_PAYPAL_PUBLIC_URL = 'http://10.0.2.2:5099'
    Start-Process python -ArgumentList "$root\scripts\fake_paypal.py" -WindowStyle Hidden
    Start-Sleep -Seconds 2
    Start-Api
    Start-Process dotnet -ArgumentList 'run', '--no-build' -WorkingDirectory "$root\src\eBiblioteka.Worker" -WindowStyle Hidden
    Start-Sleep -Seconds 5
    Invoke-RestMethod -Method Delete -Uri 'http://localhost:8025/api/v1/messages' | Out-Null

    Write-Host '3. Test na emulatoru'
    $match = [regex]::Match((flutter devices | Out-String), '(emulator-\d+)')
    if (-not $match.Success) { throw 'Nije pronadjen pokrenut Android emulator.' }
    $device = $match.Groups[1].Value

    # Ugasen ekran emulatora zaustavlja iscrtavanje, pa test visi: emulator se budi i drzi budnim.
    $adb = "$env:LOCALAPPDATA\Android\sdk\platform-tools\adb.exe"
    & $adb -s $device shell input keyevent KEYCODE_WAKEUP | Out-Null
    & $adb -s $device shell wm dismiss-keyguard | Out-Null
    & $adb -s $device shell svc power stayon true | Out-Null

    Set-Location "$root\mobile"
    flutter test integration_test/app_test.dart -d $device --dart-define=API_BASE_URL=http://10.0.2.2:5028
    $exit = $LASTEXITCODE
}
finally {
    Set-Location $root
    Write-Host '4. Ciscenje: gasenje procesa i povratak baze u demo stanje'
    Stop-Local
    Reset-DemoData
    $env:PAYPAL_CLIENT_ID = $null; $env:PAYPAL_CLIENT_SECRET = $null; $env:PAYPAL_BASE_URL = $null
    # Kratko pokretanje API-ja ponovo ubacuje demo podatke (seed), zatim se gasi.
    Start-Process dotnet -ArgumentList 'run', '--no-build', '--launch-profile', 'http' `
        -WorkingDirectory "$root\src\eBiblioteka.Api" -WindowStyle Hidden
    try { Wait-Api; Start-Sleep -Seconds 4 } catch { }
    Stop-Local
}

exit $exit
